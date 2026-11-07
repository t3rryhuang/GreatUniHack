"""Nova Explorer: Manchester (Teen mode game) endpoints.

- POST /explorer/stylist: Remi the stylist turns a short message into an avatar change.
  Input is trimmed and screened for personal details; the LLM may only pick values from
  the catalogue below (the same catalogue as AvatarLook.swift); the reply is length-limited
  and stripped of links. Without an LLM key, keyword rules (the same as StylistRules in the
  app) are used, so the endpoint always works.
- GET /explorer/park and POST /explorer/park/contribute: the shared Community Park total
  on Upstash Redis (store.py). Each player can give 1-3 points a day; players are stored
  only as a salted hash of their id.
"""
from __future__ import annotations

import hashlib
import json
import logging
import os
import re
from datetime import datetime, timezone

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

import llm
import store

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/explorer", tags=["explorer"])

# ---------------------------------------------------------------------------
# Catalogue (keep in sync with Nova/Nova/Models/Explorer/AvatarLook.swift)
# ---------------------------------------------------------------------------

COLOURS = ["purple", "pink", "red", "orange", "yellow", "green", "teal", "blue", "navy", "black", "white", "grey", "brown"]
CATALOGUE: dict[str, list[str]] = {
    "skin": ["tone1", "tone2", "tone3", "tone4", "tone5", "tone6"],
    "hair": ["short", "long", "curly", "bun", "buzz", "afro", "braids"],
    "hairColour": COLOURS,
    "top": ["hoodie", "tshirt", "jacket", "jumper"],
    "topColour": COLOURS,
    "bottomColour": COLOURS,
    "shoes": ["trainers", "boots", "sliders"],
    "shoeColour": COLOURS,
    "accessory": ["none", "glasses", "cap", "beanie", "headphones"],
}

MAX_INPUT = 200
MAX_REPLY = 240
PRIVACY_REPLY = "Let's keep personal details private. Tell me about colours and styles instead!"
HELP_REPLY = "I can change your hair, top, trousers, shoes and accessories. Try 'blue hoodie and curly hair'."

_PII = [
    re.compile(r"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", re.I),
    re.compile(r"(\+?44|0)\s?\d[\d\s]{8,}"),
    re.compile(r"\b[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2}\b", re.I),
    re.compile(r"https?://|www\.", re.I),
]
_BLOCKED = ["kill", "sex", "naked", "drugs", "gun"]


def clean_input(text: str) -> str:
    return (text or "").strip()[:MAX_INPUT]


def has_personal_info(text: str) -> bool:
    return any(p.search(text) for p in _PII)


def clean_reply(text: str) -> str:
    text = re.sub(r"https?://\S+|www\.\S+", "", text or "").strip()
    if len(text) > MAX_REPLY:
        text = text[: MAX_REPLY - 1] + "…"
    return text or "Looking good! Anything else you'd like to change?"


def validate_patch(patch: object) -> dict[str, str]:
    """Keeps only known fields with catalogue values."""
    if not isinstance(patch, dict):
        return {}
    return {k: v for k, v in patch.items() if k in CATALOGUE and isinstance(v, str) and v in CATALOGUE[k]}


def rules_reply(message: str) -> tuple[str, dict[str, str], bool]:
    """Keyword rules, mirroring StylistRules in the app."""
    q = f" {message.lower()} "
    if any(w in q for w in ["looks good", "done", "perfect", "that's it", "thats it", "love it", "i'm happy", "im happy"]):
        return "Love it! Tap 'This is me' when you're ready to explore Manchester.", {}, True
    patch: dict[str, str] = {}

    def colour_before(words: list[str]) -> str | None:
        for c in COLOURS:
            if any(f" {c} {w}" in q or f" {c}-{w}" in q for w in words):
                return c
        return None

    for style in CATALOGUE["hair"]:
        if f" {style}" in q and ("hair" in q or style in ("afro", "braids", "bun", "buzz")):
            patch["hair"] = style
    if "long hair" in q:
        patch["hair"] = "long"
    if "short hair" in q:
        patch["hair"] = "short"
    if c := colour_before(["hair"] + CATALOGUE["hair"]):
        patch["hairColour"] = c
    if "blonde" in q or "blond" in q:
        patch["hairColour"] = "yellow"
    if "ginger" in q:
        patch["hairColour"] = "orange"
    tops = {"hoodie": "hoodie", "t-shirt": "tshirt", "tshirt": "tshirt", "tee": "tshirt", "jacket": "jacket", "coat": "jacket", "jumper": "jumper", "sweater": "jumper"}
    for word, style in tops.items():
        if word in q:
            patch["top"] = style
    if c := colour_before(list(tops) + ["top", "shirt"]):
        patch["topColour"] = c
    if c := colour_before(["trousers", "jeans", "joggers", "shorts", "skirt", "bottoms"]):
        patch["bottomColour"] = c
    shoes = {"trainers": "trainers", "sneakers": "trainers", "boots": "boots", "sliders": "sliders", "sandals": "sliders"}
    for word, style in shoes.items():
        if word in q:
            patch["shoes"] = style
    if c := colour_before(list(shoes) + ["shoes"]):
        patch["shoeColour"] = c
    for item in ["glasses", "cap", "beanie", "headphones"]:
        if item in q:
            patch["accessory"] = item
    if "headphone" in q:
        patch["accessory"] = "headphones"
    if "no hat" in q or "no glasses" in q:
        patch["accessory"] = "none"
    if not patch:
        lone = next((c for c in COLOURS if f" {c} " in q), None)
        if lone:
            patch["topColour"] = lone
    if not patch:
        return HELP_REPLY, {}, False
    return "Done! What do you think? Anything else?", patch, False


STYLIST_SYSTEM = """You are Remi, a friendly stylist character in a game for 16 and 17-year-olds, set in the Nancy Rothwell Building in Manchester.
The player describes how their game character should look. Reply in British English, warm and short (one or two sentences, under 200 characters), reading age 12.
Only talk about the character's look. Never ask for or repeat personal details (names, ages, addresses, schools, contacts). Never discuss anything unsafe.
Choose changes ONLY from this catalogue (field: allowed values):
{catalogue}
Respond with JSON only: {{"reply": "...", "patch": {{field: value, ...}}, "confirm": true|false}}. Use "confirm": true only if the player says they are happy with the look.
Current look: {look}"""


class Turn(BaseModel):
    role: str
    text: str = Field(max_length=400)


class StylistRequest(BaseModel):
    message: str = Field(min_length=1, max_length=500)
    look: dict = {}
    history: list[Turn] = []


@router.post("/stylist")
async def stylist(req: StylistRequest):
    message = clean_input(req.message)
    if has_personal_info(message):
        return {"reply": PRIVACY_REPLY, "patch": {}, "confirm": False, "source": "guard"}
    if any(w in message.lower() for w in _BLOCKED):
        return {"reply": "Let's keep it about style! What colours do you like?", "patch": {}, "confirm": False, "source": "guard"}
    look = validate_patch(req.look)
    if llm.OPENAI_READY:
        try:
            msgs = [{"role": "assistant" if t.role == "assistant" else "user", "content": clean_input(t.text)} for t in req.history[-6:]]
            msgs.append({"role": "user", "content": message})
            while msgs and msgs[0]["role"] != "user":
                msgs.pop(0)
            raw = await llm.claude(msgs, max_tokens=300, system=STYLIST_SYSTEM.format(
                catalogue=json.dumps(CATALOGUE), look=json.dumps(look)))
            data = json.loads(raw[raw.index("{"): raw.rindex("}") + 1])
            reply = clean_reply(str(data.get("reply", "")))
            if has_personal_info(reply):
                reply = "Looking good! Anything else you'd like to change?"
            return {"reply": reply, "patch": validate_patch(data.get("patch")), "confirm": bool(data.get("confirm")), "source": "llm"}
        except Exception:
            logger.exception("stylist LLM failed; using rules")
    reply, patch, confirm = rules_reply(message)
    return {"reply": reply, "patch": patch, "confirm": confirm, "source": "rules"}


# ---------------------------------------------------------------------------
# Community Park
# ---------------------------------------------------------------------------

PARK_TOTAL = "explorer:park:total"
PARK_CONTRIBUTORS = "explorer:park:contributors"
DAILY_CAP = 3
_SALT = os.getenv("EXPLORER_SALT", "nova-explorer")


def _player(user_id: str | None) -> str:
    if not user_id or not user_id.strip():
        raise HTTPException(status_code=401, detail="Missing X-User-Id header")
    return hashlib.sha256(f"{_SALT}:{user_id.strip().lower()}".encode()).hexdigest()[:24]


async def _status() -> dict:
    total = int(await store.get(PARK_TOTAL) or 0)
    contributors = int(await store.get(PARK_CONTRIBUTORS) or 0)
    return {"total": total, "contributors": contributors}


@router.get("/park")
async def park():
    return await _status()


class Contribution(BaseModel):
    points: int = Field(ge=1, le=DAILY_CAP)


@router.post("/park/contribute")
async def contribute(body: Contribution, x_user_id: str | None = Header(None)):
    player = _player(x_user_id)
    day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    today_key = f"explorer:park:day:{day}:{player}"
    given = await store.incrby(today_key, body.points, ttl=2 * 86_400)
    if given > DAILY_CAP:
        await store.incrby(today_key, -body.points)
        raise HTTPException(status_code=429, detail="You've given today's 3 park points. Come back tomorrow!")
    if given == body.points:
        await store.incrby(PARK_CONTRIBUTORS, 1)
    await store.incrby(PARK_TOTAL, body.points)
    return await _status()
