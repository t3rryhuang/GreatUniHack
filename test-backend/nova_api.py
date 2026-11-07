"""JSON endpoints shaped for the Nova iOS app.

The older endpoints in main.py take uploaded statement files and return
markdown. The iOS app already holds the transactions and a computed
`FinancialSummary`, so these endpoints take that JSON and return JSON that
maps 1:1 onto the Swift models.
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
import re
from datetime import date, timedelta

import httpx
from fastapi import APIRouter, File, HTTPException, UploadFile
from fastapi.responses import Response
from pydantic import BaseModel

import llm

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/nova", tags=["nova"])

ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY")
ELEVENLABS_VOICE_ID = os.getenv("ELEVENLABS_VOICE_ID", "21m00Tcm4TlvDq8ikWAM")  # "Rachel", as in the original app
ELEVENLABS_MODEL = os.getenv("ELEVENLABS_MODEL", "eleven_flash_v2_5")
ELEVENLABS_STT_MODEL = os.getenv("ELEVENLABS_STT_MODEL", "scribe_v2")

CATEGORIES = [
    "Coffee", "Groceries", "Dining", "Drinks", "Transport", "Shopping", "Subscriptions",
    "Utilities", "Entertainment", "Rent", "Healthcare", "Education", "Transfer", "Income", "Other",
]


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

class CategoryTotal(BaseModel):
    category: str
    amount: float
    share: float


class Summary(BaseModel):
    totalSpent: float = 0
    avgDaily: float = 0
    avgMonthly: float = 0
    monthlyIncome: float = 0
    savings: float = 0
    savingsRate: float = 0
    runwayMonths: float = 0
    spendingTrend: str = "stable"
    topCategories: list[CategoryTotal] = []
    dataRangeMonths: float = 0


class Txn(BaseModel):
    date: str
    description: str
    amount: float
    category: str


class ChatTurn(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    message: str
    history: list[ChatTurn] = []
    summary: Summary


class SummaryRequest(BaseModel):
    summary: Summary


class WhatIfRequest(BaseModel):
    question: str
    summary: Summary


class WeekAheadRequest(BaseModel):
    transactions: list[Txn]


class TTSRequest(BaseModel):
    text: str


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _summary_text(s: Summary) -> str:
    months = max(1.0, s.dataRangeMonths)
    cats = ", ".join(f"{c.category} £{c.amount / months:,.0f}/month ({c.share * 100:.0f}%)" for c in s.topCategories[:8])
    return (
        f"Average monthly spending £{s.avgMonthly:,.0f}; average daily £{s.avgDaily:,.2f}; "
        f"monthly income £{s.monthlyIncome:,.0f}; savings account balance £{s.savings:,.0f}; "
        f"savings rate {s.savingsRate:.0f}%; runway {s.runwayMonths:.1f} months; spending trend {s.spendingTrend}; "
        f"data covers {s.dataRangeMonths:.1f} months. Top categories: {cats}."
    )


def _extract_json(text: str):
    text = text.strip()
    fence = re.search(r"```(?:json)?\s*(.*?)```", text, re.S)
    if fence:
        text = fence.group(1).strip()
    decoder = json.JSONDecoder()
    for i, ch in enumerate(text):
        if ch in "{[":
            try:
                return decoder.raw_decode(text, i)[0]
            except json.JSONDecodeError:
                continue
    logger.warning("no JSON in model output: %r", text[:300])
    raise ValueError("no JSON in model output")


def _require_llm():
    if not llm.OPENAI_READY:
        raise HTTPException(status_code=503, detail="No LLM provider configured (set RUNWARE_API_KEY).")


# ---------------------------------------------------------------------------
# Chat
# ---------------------------------------------------------------------------

CHAT_SYSTEM = """You are Nova, the friendly money assistant in the NatWest Nova app (Manchester, UK).
Answer using the user's real figures below. Use pounds sterling (£) and British English.
Keep replies to 2-4 short sentences, plain text, no markdown or lists. Never invent transactions.
If asked something unrelated to money, gently steer back to their finances.

User's financial summary: {summary}"""


@router.post("/chat")
async def chat(req: ChatRequest):
    _require_llm()
    msgs = [{"role": "assistant" if t.role == "assistant" else "user", "content": t.content} for t in req.history[-20:]]
    msgs.append({"role": "user", "content": req.message})
    # Claude requires the first message to be from the user.
    while msgs and msgs[0]["role"] != "user":
        msgs.pop(0)
    try:
        reply = await llm.claude(msgs, max_tokens=400, system=CHAT_SYSTEM.format(summary=_summary_text(req.summary)))
    except Exception as e:
        logger.exception("chat failed")
        raise HTTPException(status_code=502, detail=f"Chat failed: {e}")
    return {"reply": reply.strip()}


# ---------------------------------------------------------------------------
# Text to speech (ElevenLabs)
# ---------------------------------------------------------------------------

@router.post("/tts")
async def tts(req: TTSRequest):
    if not ELEVENLABS_API_KEY:
        raise HTTPException(status_code=503, detail="ELEVENLABS_API_KEY not set")
    text = req.text.strip()[:2500]
    if not text:
        raise HTTPException(status_code=400, detail="Empty text")
    async with httpx.AsyncClient(timeout=60) as client:
        r = await client.post(
            f"https://api.elevenlabs.io/v1/text-to-speech/{ELEVENLABS_VOICE_ID}",
            params={"output_format": "mp3_44100_128"},
            headers={"xi-api-key": ELEVENLABS_API_KEY, "accept": "audio/mpeg"},
            json={"text": text, "model_id": ELEVENLABS_MODEL},
        )
    if r.status_code != 200:
        raise HTTPException(status_code=502, detail=f"ElevenLabs error {r.status_code}: {r.text[:200]}")
    return Response(content=r.content, media_type="audio/mpeg")


# ---------------------------------------------------------------------------
# Speech to text (ElevenLabs Scribe)
# ---------------------------------------------------------------------------

MAX_AUDIO_BYTES = 4 * 1024 * 1024  # Vercel's request body limit is ~4.5 MB


@router.post("/transcribe")
async def transcribe(file: UploadFile = File(...)):
    """Transcribe a short voice question recorded in the app (m4a/mp3/wav)."""
    if not ELEVENLABS_API_KEY:
        raise HTTPException(status_code=503, detail="ELEVENLABS_API_KEY not set")
    audio = await file.read()
    if not audio:
        raise HTTPException(status_code=400, detail="Empty audio")
    if len(audio) > MAX_AUDIO_BYTES:
        raise HTTPException(status_code=413, detail="Recording is too long. Keep it under a minute.")
    async with httpx.AsyncClient(timeout=60) as client:
        r = await client.post(
            "https://api.elevenlabs.io/v1/speech-to-text",
            headers={"xi-api-key": ELEVENLABS_API_KEY},
            data={"model_id": ELEVENLABS_STT_MODEL, "language_code": "en", "tag_audio_events": "false"},
            files={"file": (file.filename or "audio.m4a", audio, file.content_type or "audio/mp4")},
        )
    if r.status_code != 200:
        raise HTTPException(status_code=502, detail=f"ElevenLabs error {r.status_code}: {r.text[:200]}")
    return {"text": (r.json().get("text") or "").strip()}


# ---------------------------------------------------------------------------
# Budget tips / runway / what-if
# ---------------------------------------------------------------------------

@router.post("/budget-tips")
async def budget_tips(req: SummaryRequest):
    _require_llm()
    prompt = (
        "You are a UK personal finance coach for someone in Manchester. Based on this summary, give 3 or 4 "
        "concise, specific, actionable tips to save money, each one sentence, referencing their actual £ figures "
        "and local options (Metrolink, Bee Network, UK supermarkets) where relevant.\n\n"
        f"{_summary_text(req.summary)}\n\n"
        'Respond with ONLY a JSON array of strings, e.g. ["tip one", "tip two"].'
    )
    try:
        tips = _extract_json(await llm.gpt([{"role": "user", "content": prompt}], max_tokens=600))
        tips = [str(t).strip() for t in tips if str(t).strip()][:4]
    except Exception as e:
        logger.exception("budget tips failed")
        raise HTTPException(status_code=502, detail=f"Budget tips failed: {e}")
    return {"tips": tips}


@router.post("/runway")
async def runway(req: SummaryRequest):
    s = req.summary
    months = s.savings / s.avgMonthly if s.avgMonthly > 0 else 0.0
    _require_llm()
    prompt = (
        "Estimate how long this person could live on their savings with no income. Their runway at current "
        f"spending is {months:.1f} months. Write 2-3 short sentences in British English with £: state the runway, "
        "then how far it stretches if they cut to essentials (rent, utilities, groceries, transport) using the "
        "category figures, and one practical note. Plain text, no markdown.\n\n" + _summary_text(s)
    )
    try:
        analysis = await llm.gpt([{"role": "user", "content": prompt}], max_tokens=400)
    except Exception as e:
        logger.exception("runway failed")
        raise HTTPException(status_code=502, detail=f"Runway failed: {e}")
    return {"months": round(months, 2), "analysis": analysis.strip()}


WHAT_IF_PROMPT = """You are the "What if?" simulator in a UK banking app (user lives in Manchester).
Question: "{question}"
User summary: {summary}

Estimate the financial effect using their real figures. Respond with ONLY a JSON object:
{{
  "outcome": "one sentence answer with £ amounts",
  "amount": number (main £ figure saved or gained; 0 if not applicable),
  "period": "month" | "year" | "",
  "isPositive": true/false (is the change good for their finances),
  "beforeLabel": "short label", "beforeValue": number,
  "afterLabel": "short label", "afterValue": number,
  "confidence": integer 50-98,
  "details": "1-2 sentences of practical context, Manchester-specific if relevant"
}}"""


@router.post("/what-if")
async def what_if(req: WhatIfRequest):
    _require_llm()
    prompt = WHAT_IF_PROMPT.format(question=req.question.strip()[:300], summary=_summary_text(req.summary))
    try:
        data = _extract_json(await llm.claude([{"role": "user", "content": prompt}], max_tokens=600))
        result = {
            "question": req.question,
            "outcome": str(data["outcome"]),
            "amount": float(data.get("amount") or 0),
            "period": str(data.get("period") or ""),
            "isPositive": bool(data.get("isPositive", True)),
            "beforeLabel": str(data.get("beforeLabel") or "Before"),
            "beforeValue": float(data.get("beforeValue") or 0),
            "afterLabel": str(data.get("afterLabel") or "After"),
            "afterValue": float(data.get("afterValue") or 0),
            "confidence": int(max(0, min(99, int(data.get("confidence") or 70)))),
            "details": str(data.get("details") or ""),
        }
    except Exception as e:
        logger.exception("what-if failed")
        raise HTTPException(status_code=502, detail=f"What-if failed: {e}")
    return result


# ---------------------------------------------------------------------------
# Week ahead: three models predict independently, results are merged
# ---------------------------------------------------------------------------

WEEK_PROMPT = """You predict a UK bank customer's spending for the next 7 days from their history.
Today is {today} ({weekday}). Predict for these dates: {dates}.
Allowed categories: {categories}.
Only predict recurring behaviours clearly supported by the history (same weekday or very frequent).
Give 1-4 items per day. probability is 0-0.95; amount is a typical £ spend.

Recent transactions (date, weekday, description, amount, category):
{history}

Respond with ONLY JSON: {{"days": [{{"date": "YYYY-MM-DD", "items": [{{"category": "Coffee", "title": "Coffee at Pret", "probability": 0.8, "amount": 3.6}}]}}]}}"""


async def _week_from(model: str, prompt: str) -> dict:
    if model == "Claude":
        out = await llm.claude([{"role": "user", "content": prompt}], max_tokens=2500)
    elif model == "Gemini":
        out = await llm.gemini(prompt, max_tokens=2500)
    else:
        out = await llm.gpt([{"role": "user", "content": prompt}], max_tokens=2500)
    return _extract_json(out)


@router.post("/week-ahead")
async def week_ahead(req: WeekAheadRequest):
    _require_llm()
    today = date.today()
    dates = [(today + timedelta(days=i)).isoformat() for i in range(7)]
    cutoff = (today - timedelta(days=60)).isoformat()
    recent = sorted((t for t in req.transactions if t.amount < 0 and t.date[:10] >= cutoff), key=lambda t: t.date)[-400:]
    history = "\n".join(
        f"{t.date[:10]}, {date.fromisoformat(t.date[:10]).strftime('%a')}, {t.description}, £{-t.amount:.2f}, {t.category}"
        for t in recent
    )
    prompt = WEEK_PROMPT.format(
        today=today.isoformat(), weekday=today.strftime("%A"), dates=", ".join(dates),
        categories=", ".join(c for c in CATEGORIES if c not in ("Income", "Transfer")), history=history or "(none)",
    )
    models = ["Claude", "Gemini", "GPT"]
    results = await asyncio.gather(*(_week_from(m, prompt) for m in models), return_exceptions=True)

    # merged[date][category] = {"titles": [...], "probs": [...], "amounts": [...], "models": [...]}
    merged: dict[str, dict[str, dict]] = {d: {} for d in dates}
    ok_models = []
    for model, res in zip(models, results):
        if isinstance(res, Exception):
            logger.warning("week-ahead %s failed: %s", model, res)
            continue
        ok_models.append(model)
        for day in res.get("days", []):
            d = str(day.get("date", ""))[:10]
            if d not in merged:
                continue
            for item in day.get("items", []):
                cat = str(item.get("category", "Other")).strip().title()
                if cat not in CATEGORIES:
                    cat = "Other"
                slot = merged[d].setdefault(cat, {"titles": [], "probs": [], "amounts": [], "models": []})
                if model in slot["models"]:
                    continue
                slot["models"].append(model)
                slot["titles"].append(str(item.get("title") or cat))
                slot["probs"].append(float(item.get("probability") or 0))
                slot["amounts"].append(float(item.get("amount") or 0))
    if not ok_models:
        raise HTTPException(status_code=502, detail="All models failed to predict the week ahead.")

    days = []
    for d in dates:
        items = []
        for cat, slot in merged[d].items():
            n = len(slot["models"])
            # Average across responding models; a model that skipped this item counts as 0.
            prob = sum(slot["probs"]) / len(ok_models)
            if n < 2 and len(ok_models) >= 2:
                prob *= 0.8  # single-model predictions are less trustworthy
            items.append({
                "category": cat,
                "title": slot["titles"][0],
                "probability": round(min(0.95, max(0.0, prob)), 2),
                "amount": round(sum(slot["amounts"]) / n, 2),
                "agreedBy": slot["models"],
            })
        items.sort(key=lambda i: i["probability"], reverse=True)
        days.append({"date": d, "items": [i for i in items if i["probability"] >= 0.15][:4]})
    return {"days": days, "models": ok_models}


# ---------------------------------------------------------------------------
# Weather (Open-Meteo, no key needed)
# ---------------------------------------------------------------------------

def _condition(code: int, temp: float, wind: float) -> str:
    if code in (51, 53, 55, 56, 57):
        return "drizzle"
    if code in (61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99):
        return "rain"
    if code in (71, 73, 75, 77, 85, 86) or temp <= 3:
        return "cold"
    if wind >= 30:
        return "wind"
    if code in (0, 1):
        return "sunny"
    return "cloudy"


IMPACT = {
    "rain": "Rainy days usually mean more Uber trips and food delivery.",
    "drizzle": "Drizzly days usually mean more Uber trips and food delivery.",
    "sunny": "Sunny days usually mean more spending out and about.",
    "cold": "Cold days push up coffee and heating costs.",
    "wind": "A normal day for your spending.",
    "cloudy": "A normal day for your spending.",
}


@router.get("/weather")
async def weather(lat: float = 53.4808, lon: float = -2.2426, city: str = "Manchester"):
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.get(
                "https://api.open-meteo.com/v1/forecast",
                params={"latitude": lat, "longitude": lon, "current": "temperature_2m,weather_code,wind_speed_10m"},
            )
            r.raise_for_status()
            cur = r.json()["current"]
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Weather unavailable: {e}")
    cond = _condition(int(cur["weather_code"]), float(cur["temperature_2m"]), float(cur["wind_speed_10m"]))
    return {
        "city": city,
        "temperatureC": round(float(cur["temperature_2m"])),
        "condition": cond,
        "spendingImpact": IMPACT[cond],
    }
