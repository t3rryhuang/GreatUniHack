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
from typing import Literal

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
    # "teen" (16-17) or "adult". Defaults to adult so older clients keep working.
    stage: Literal["teen", "adult"] = "adult"


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

CHAT_TEEN_RULES = """

The user is 16 or 17 and is in Nova's Teen mode. Extra rules:
- Never recommend or suggest credit products, credit cards, loans, overdrafts or buy now pay later. If asked, say you can't recommend them and suggest saving or the app's practice borrowing sandbox instead.
- Focus on saving, bills, first wages and payslips, and their Readiness Score.
- The Readiness Score is not a credit score; never say it creates or changes a credit file.
- Keep answers to 1-3 short, friendly, age-appropriate sentences. No gambling words."""


@router.post("/chat")
async def chat(req: ChatRequest):
    _require_llm()
    msgs = [{"role": "assistant" if t.role == "assistant" else "user", "content": t.content} for t in req.history[-20:]]
    msgs.append({"role": "user", "content": req.message})
    # Claude requires the first message to be from the user.
    while msgs and msgs[0]["role"] != "user":
        msgs.pop(0)
    try:
        system = CHAT_SYSTEM.format(summary=_summary_text(req.summary))
        if req.stage == "teen":
            system += CHAT_TEEN_RULES
        reply = await llm.claude(msgs, max_tokens=300 if req.stage == "teen" else 400, system=system)
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


# Canonical themes keep similar questions on the same cached illustration.
WHAT_IF_THEMES = [
    "coffee-at-home", "eat-out-less", "cook-at-home", "cheaper-rent", "move-house", "cycle-to-work",
    "public-transport", "sell-car", "buy-car", "cancel-subscriptions", "monthly-saving", "emergency-fund",
    "quit-job", "pay-rise", "side-hustle", "part-time-work", "holiday", "big-purchase", "pay-off-debt",
    "nights-out", "gym-membership", "energy-bills", "groceries-budget", "shopping-less", "new-baby",
    "pet", "study-course", "invest", "wedding", "house-deposit",
]

WHAT_IF_ICONS = [
    "cup.and.saucer.fill", "fork.knife", "house.fill", "bicycle", "tram.fill", "car.fill", "tv.fill",
    "banknote.fill", "briefcase.fill", "chart.line.uptrend.xyaxis", "airplane", "bag.fill",
    "creditcard.fill", "wineglass.fill", "figure.run", "bolt.fill", "cart.fill", "graduationcap.fill",
    "pawprint.fill", "heart.fill", "sterlingsign.circle.fill", "gift.fill",
]

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
  "details": "1-2 sentences of practical context, Manchester-specific if relevant",
  "monthlyImpact": number (signed change to their monthly cash flow in £; positive = more money left each month, e.g. quitting a job is minus their income),
  "oneOffCost": number (upfront £ cost to make the change, e.g. a bike or moving costs; 0 if none),
  "breakdown": [up to 3 items {{"label": "short label", "amount": number (£ per month)}} that explain the figure],
  "equivalent": "a short relatable comparison of the yearly effect, e.g. 'About a return flight to Barcelona every 3 months'",
  "theme": "pick the closest from: {themes}. Only invent a new 1-3 word kebab-case theme if none fits",
  "icon": "one of: {icons}",
  "scene": "a short visual scene for an illustration of this change (people, objects, setting). No text, numbers or currency symbols"
}}"""

ILLUSTRATION_STYLE = (
    "Flat vector editorial illustration, {scene}. Friendly, optimistic, minimal, soft shadows, "
    "rounded shapes, purple, lilac and white colour palette with small warm accents, clean background, "
    "British setting. No text, no letters, no numbers, no dollar signs."
)
ILLUSTRATION_MODEL = os.getenv("ILLUSTRATION_MODEL", "runware:100@1")  # FLUX.1 schnell: ~1.5s, fractions of a penny
WHAT_IF_CACHE_TTL = 60 * 60 * 24  # identical question + similar finances → reuse the answer for a day


def _slug(text: str, fallback: str = "money-change") -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", str(text).lower()).strip("-")[:40]
    return slug or fallback


def _projection(s: Summary, monthly_impact: float, one_off: float) -> dict:
    """Savings balance month by month for a year, with and without the change."""
    surplus = s.monthlyIncome - s.avgMonthly
    baseline = [round(max(0.0, s.savings + surplus * m), 2) for m in range(13)]
    scenario = [round(max(0.0, s.savings - one_off + (surplus + monthly_impact) * m), 2) for m in range(13)]
    return {"baseline": baseline, "scenario": scenario}


def _cache_key(question: str, s: Summary) -> str:
    import hashlib

    q = re.sub(r"[^a-z0-9£ ]+", "", question.lower())
    q = re.sub(r"\s+", " ", q).strip()
    # Round figures so small changes in transactions still hit the cache.
    fp = f"{q}|{round(s.avgMonthly, -1)}|{round(s.monthlyIncome, -1)}|{round(s.savings, -2)}"
    fp += "|" + ",".join(f"{c.category}:{round(c.amount, -1)}" for c in s.topCategories[:6])
    return "whatif:v2:" + hashlib.sha1(fp.encode()).hexdigest()


@router.post("/what-if")
async def what_if(req: WhatIfRequest):
    _require_llm()
    import store

    key = _cache_key(req.question, req.summary)
    try:
        cached = await store.get(key)
    except Exception:
        cached = None
    if cached:
        result = json.loads(cached)
        result["question"] = req.question
        result["cached"] = True
        return result

    prompt = WHAT_IF_PROMPT.format(
        question=req.question.strip()[:300], summary=_summary_text(req.summary),
        themes=", ".join(WHAT_IF_THEMES), icons=", ".join(WHAT_IF_ICONS),
    )
    try:
        data = _extract_json(await llm.claude([{"role": "user", "content": prompt}], max_tokens=900))
        theme = _slug(data.get("theme") or "")
        scene = str(data.get("scene") or theme.replace("-", " "))[:300]
        icon = str(data.get("icon") or "")
        monthly = float(data.get("monthlyImpact") or 0)
        one_off = max(0.0, float(data.get("oneOffCost") or 0))
        breakdown = [
            {"label": str(b.get("label", ""))[:40], "amount": round(float(b.get("amount") or 0), 2)}
            for b in (data.get("breakdown") or [])[:3]
            if isinstance(b, dict) and b.get("label")
        ]
        from urllib.parse import quote

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
            "infographic": {
                "theme": theme,
                "icon": icon if icon in WHAT_IF_ICONS else "sterlingsign.circle.fill",
                "equivalent": str(data.get("equivalent") or ""),
                "monthlyImpact": round(monthly, 2),
                "oneOffCost": round(one_off, 2),
                "breakdown": breakdown,
                "projection": _projection(req.summary, monthly, one_off),
                "illustrationPath": f"nova/illustration/{theme}.webp?scene={quote(scene)}",
            },
        }
    except Exception as e:
        logger.exception("what-if failed")
        raise HTTPException(status_code=502, detail=f"What-if failed: {e}")
    try:
        await store.put(key, json.dumps(result), ttl=WHAT_IF_CACHE_TTL)
    except Exception:
        logger.warning("what-if cache write failed", exc_info=True)
    return result


# ---------------------------------------------------------------------------
# Illustrations (Runware FLUX), cached by theme
# ---------------------------------------------------------------------------

async def _generate_illustration(scene: str) -> bytes:
    import base64
    import uuid

    if not llm.RUNWARE_API_KEY:
        raise HTTPException(status_code=503, detail="RUNWARE_API_KEY not set")
    task = {
        "taskType": "imageInference",
        "taskUUID": str(uuid.uuid4()),
        "model": ILLUSTRATION_MODEL,
        "positivePrompt": ILLUSTRATION_STYLE.format(scene=scene),
        "width": 768,
        "height": 512,
        "numberResults": 1,
        "outputType": "base64Data",
        "outputFormat": "WEBP",
    }
    async with httpx.AsyncClient(timeout=60) as client:
        r = await client.post(
            "https://api.runware.ai/v1",
            headers={"Authorization": f"Bearer {llm.RUNWARE_API_KEY}"},
            json=[task],
        )
    body = r.json() if r.headers.get("content-type", "").startswith("application/json") else {}
    if r.status_code != 200 or not body.get("data"):
        raise HTTPException(status_code=502, detail=f"Illustration failed: {str(body.get('errors') or r.text)[:200]}")
    return base64.b64decode(body["data"][0]["imageBase64Data"])


@router.get("/illustration/{theme}.webp")
async def illustration(theme: str, scene: str = ""):
    """Returns the illustration for a theme, generating it once and caching it forever.

    Similar questions map to the same theme, so after the first request the image
    comes straight from Redis (and then from Vercel's CDN via Cache-Control).
    """
    import base64

    import store

    theme = _slug(theme)
    key = f"illus:v1:{theme}"
    headers = {"Cache-Control": "public, max-age=604800, s-maxage=31536000, immutable"}

    cached = await store.get(key)
    if cached:
        return Response(content=base64.b64decode(cached), media_type="image/webp", headers={**headers, "X-Cache": "HIT"})

    # Only one request generates a given theme; others wait briefly for it.
    lock = f"illus:lock:{theme}"
    if not await store.setnx(lock, "1", ttl=45):
        for _ in range(40):
            await asyncio.sleep(0.5)
            cached = await store.get(key)
            if cached:
                return Response(content=base64.b64decode(cached), media_type="image/webp", headers={**headers, "X-Cache": "WAIT"})
    try:
        image = await _generate_illustration(scene.strip()[:300] or theme.replace("-", " "))
        await store.put(key, base64.b64encode(image).decode())
    finally:
        await store.delete(lock)
    return Response(content=image, media_type="image/webp", headers={**headers, "X-Cache": "MISS"})


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
