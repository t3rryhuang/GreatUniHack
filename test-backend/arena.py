"""Arena API: create, join, sync and settle savings challenges between friends.

Storage is Upstash Redis via its REST API (env vars injected by the Vercel
Upstash integration: KV_REST_API_URL / KV_REST_API_TOKEN, or
UPSTASH_REDIS_REST_URL / UPSTASH_REDIS_REST_TOKEN). Without them an in-memory
store is used, which is fine for local dev but does not persist on Vercel.

Identity: the client sends `X-User-Id` (the account email) and `X-User-Name`.
Stakes and payouts move money in the user's on-device savings account; the
server only records who is in which arena, their progress and the result.
Winner rules are ported from `ArenaRules` in the iOS app.
"""
from __future__ import annotations

import json
import os
import random
import uuid
from datetime import datetime, timezone
from typing import Literal

import httpx
from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

router = APIRouter(prefix="/arenas", tags=["arena"])

Mode = Literal["budget_guardian", "vice_streak", "savings_sprint"]

# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------

_REDIS_URL = os.getenv("KV_REST_API_URL") or os.getenv("UPSTASH_REDIS_REST_URL")
_REDIS_TOKEN = os.getenv("KV_REST_API_TOKEN") or os.getenv("UPSTASH_REDIS_REST_TOKEN")
_memory: dict[str, object] = {}


def storage_backend() -> str:
    return "upstash" if _REDIS_URL and _REDIS_TOKEN else "memory"


async def _redis(*cmd: str):
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.post(_REDIS_URL, headers={"Authorization": f"Bearer {_REDIS_TOKEN}"}, json=list(cmd))
        r.raise_for_status()
        body = r.json()
        if "error" in body:
            raise HTTPException(status_code=502, detail=f"Storage error: {body['error']}")
        return body.get("result")


async def kv_get(key: str) -> str | None:
    if storage_backend() == "memory":
        return _memory.get(key)  # type: ignore[return-value]
    return await _redis("GET", key)


async def kv_set(key: str, value: str) -> None:
    if storage_backend() == "memory":
        _memory[key] = value
        return
    await _redis("SET", key, value)


async def kv_setnx(key: str, value: str) -> bool:
    if storage_backend() == "memory":
        if key in _memory:
            return False
        _memory[key] = value
        return True
    return bool(await _redis("SET", key, value, "NX"))


async def kv_sadd(key: str, member: str) -> None:
    if storage_backend() == "memory":
        _memory.setdefault(key, set()).add(member)  # type: ignore[union-attr]
        return
    await _redis("SADD", key, member)


async def kv_smembers(key: str) -> list[str]:
    if storage_backend() == "memory":
        return list(_memory.get(key, set()))  # type: ignore[arg-type]
    return await _redis("SMEMBERS", key) or []


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _now() -> datetime:
    return datetime.now(timezone.utc).replace(microsecond=0)


def _iso(dt: datetime | None) -> str | None:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if dt else None


def _parse(s: str | None) -> datetime | None:
    if not s:
        return None
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def _uid(user_id: str | None) -> str:
    if not user_id or not user_id.strip():
        raise HTTPException(status_code=401, detail="Missing X-User-Id header")
    return user_id.strip().lower()


async def _load(arena_id: str) -> dict:
    raw = await kv_get(f"arena:{arena_id.lower()}")
    if not raw:
        raise HTTPException(status_code=404, detail="Arena not found")
    return json.loads(raw)


async def _save(arena: dict) -> None:
    await kv_set(f"arena:{arena['id']}", json.dumps(arena))


def _view(arena: dict, user_id: str) -> dict:
    """Arena as the iOS app expects it, with isCurrentUser set for the caller."""
    out = {k: v for k, v in arena.items() if k != "settlement"}
    out["members"] = [
        {**{k: v for k, v in m.items() if k != "userId"}, "isCurrentUser": m["userId"] == user_id}
        for m in arena["members"]
    ]
    return out


def _standings(arena: dict) -> list[dict]:
    target = arena["targetAmount"]
    far = float("inf")
    active = [m for m in arena["members"] if not m.get("isEliminated")]
    mode = arena["mode"]

    def ts(s: str | None) -> float:
        d = _parse(s)
        return d.timestamp() if d else far

    def key(m: dict):
        if mode in ("budget_guardian", "vice_streak"):
            if m["currentSpend"] <= target:
                return (0, m["currentSpend"])
            # Over budget: whoever went over later ranks higher.
            return (1, -ts(m.get("exceededAt")))
        if m["currentSavings"] >= target:
            # Reached the target: first to get there wins.
            return (0, ts(m.get("targetReachedAt")))
        return (1, -m["currentSavings"])

    return sorted(active, key=key) + [m for m in arena["members"] if m.get("isEliminated")]


def _can_settle(arena: dict) -> str | None:
    if arena["status"] == "completed":
        return None
    if len(arena["members"]) < 2:
        return "You need at least 2 members to settle."
    if _parse(arena["endDate"]) <= _now():
        return None
    if arena["mode"] == "savings_sprint" and any(m["currentSavings"] >= arena["targetAmount"] for m in arena["members"]):
        return None
    return "Settlement opens when the arena ends."


def _new_member(user_id: str, name: str) -> dict:
    return {
        "id": str(uuid.uuid4()).upper(),
        "userId": user_id,
        "name": name or user_id.split("@")[0],
        "currentSpend": 0.0,
        "currentSavings": 0.0,
        "isEliminated": False,
        "exceededAt": None,
        "targetReachedAt": None,
        "lastSyncedAt": _iso(_now()),
    }


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

class CreateArena(BaseModel):
    name: str = Field(min_length=1, max_length=60)
    mode: Mode
    targetAmount: float = Field(ge=0)
    stakeAmount: float = Field(ge=0)
    viceCategory: str | None = None
    endDate: str


class JoinArena(BaseModel):
    code: str


class SyncArena(BaseModel):
    currentSpend: float = 0
    currentSavings: float = 0


@router.get("")
async def my_arenas(x_user_id: str | None = Header(None)):
    user = _uid(x_user_id)
    ids = await kv_smembers(f"user:{user}:arenas")
    arenas = []
    for arena_id in ids:
        try:
            arenas.append(_view(await _load(arena_id), user))
        except HTTPException:
            continue
    arenas.sort(key=lambda a: (a["status"] == "completed", a["endDate"]))
    return arenas


@router.post("")
async def create_arena(body: CreateArena, x_user_id: str | None = Header(None), x_user_name: str | None = Header(None)):
    user = _uid(x_user_id)
    if _parse(body.endDate) is None or _parse(body.endDate) <= _now():
        raise HTTPException(status_code=400, detail="End date must be in the future.")
    arena_id = str(uuid.uuid4()).lower()
    for _ in range(20):
        code = f"{random.randint(100_000, 999_999)}"
        if await kv_setnx(f"code:{code}", arena_id):
            break
    else:
        raise HTTPException(status_code=500, detail="Could not allocate a join code")
    arena = {
        "id": arena_id,
        "name": body.name.strip(),
        "mode": body.mode,
        "targetAmount": body.targetAmount,
        "stakeAmount": body.stakeAmount,
        "viceCategory": body.viceCategory if body.mode == "vice_streak" else None,
        "startDate": _iso(_now()),
        "endDate": _iso(_parse(body.endDate)),
        "joinCode": code,
        "status": "pending",
        "members": [_new_member(user, (x_user_name or "").strip())],
        "winnerID": None,
    }
    await _save(arena)
    await kv_sadd(f"user:{user}:arenas", arena_id)
    return _view(arena, user)


async def _by_code(code: str) -> dict:
    arena_id = await kv_get(f"code:{code.strip()}")
    if not arena_id:
        raise HTTPException(status_code=404, detail="We couldn't find an arena with that code.")
    return await _load(arena_id)


@router.get("/code/{code}")
async def preview_arena(code: str, x_user_id: str | None = Header(None)):
    user = _uid(x_user_id)
    arena = await _by_code(code)
    if any(m["userId"] == user for m in arena["members"]):
        raise HTTPException(status_code=409, detail="You're already in this arena.")
    if arena["status"] == "completed":
        raise HTTPException(status_code=410, detail="This arena has already finished.")
    return _view(arena, user)


@router.post("/join")
async def join_arena(body: JoinArena, x_user_id: str | None = Header(None), x_user_name: str | None = Header(None)):
    user = _uid(x_user_id)
    arena = await _by_code(body.code)
    if any(m["userId"] == user for m in arena["members"]):
        raise HTTPException(status_code=409, detail="You're already in this arena.")
    if arena["status"] == "completed":
        raise HTTPException(status_code=410, detail="This arena has already finished.")
    arena["members"].append(_new_member(user, (x_user_name or "").strip()))
    if len(arena["members"]) >= 2:
        arena["status"] = "active"
    await _save(arena)
    await kv_sadd(f"user:{user}:arenas", arena["id"])
    return _view(arena, user)


@router.get("/{arena_id}")
async def get_arena(arena_id: str, x_user_id: str | None = Header(None)):
    user = _uid(x_user_id)
    arena = await _load(arena_id)
    if not any(m["userId"] == user for m in arena["members"]):
        raise HTTPException(status_code=403, detail="You're not in this arena.")
    return _view(arena, user)


@router.post("/{arena_id}/sync")
async def sync_arena(arena_id: str, body: SyncArena, x_user_id: str | None = Header(None)):
    """The caller reports their own progress (computed on-device from their transactions)."""
    user = _uid(x_user_id)
    arena = await _load(arena_id)
    member = next((m for m in arena["members"] if m["userId"] == user), None)
    if member is None:
        raise HTTPException(status_code=403, detail="You're not in this arena.")
    if arena["status"] != "completed":
        now = _iso(_now())
        if arena["mode"] == "vice_streak":
            member["currentSpend"] = round(body.currentSpend, 2)
        else:
            member["currentSpend"] = round(max(member["currentSpend"], body.currentSpend), 2)
        member["currentSavings"] = round(max(member["currentSavings"], body.currentSavings), 2)
        over = arena["mode"] != "savings_sprint" and member["currentSpend"] > arena["targetAmount"]
        if over and not member.get("exceededAt"):
            member["exceededAt"] = now
            if arena["mode"] == "vice_streak":
                member["isEliminated"] = True
        if (
            arena["mode"] == "savings_sprint"
            and member["currentSavings"] >= arena["targetAmount"]
            and not member.get("targetReachedAt")
        ):
            member["targetReachedAt"] = now
        member["lastSyncedAt"] = now
        if arena["status"] == "pending" and len(arena["members"]) >= 2:
            arena["status"] = "active"
        await _save(arena)
    return _view(arena, user)


@router.post("/{arena_id}/settle")
async def settle_arena(arena_id: str, x_user_id: str | None = Header(None)):
    """Settle once. Any member can trigger it; later calls return the stored result."""
    user = _uid(x_user_id)
    arena = await _load(arena_id)
    if not any(m["userId"] == user for m in arena["members"]):
        raise HTTPException(status_code=403, detail="You're not in this arena.")
    if arena["status"] != "completed":
        reason = _can_settle(arena)
        if reason:
            raise HTTPException(status_code=400, detail=reason)
        standings = _standings(arena)
        winner = standings[0] if standings else None
        settled_at = _now()
        arena["status"] = "completed"
        arena["winnerID"] = winner["id"] if winner else None
        arena["settlement"] = {
            "standingIDs": [m["id"] for m in standings],
            "payout": arena["stakeAmount"] * len(arena["members"]),
            "reference": f"NW-ARENA-{arena['joinCode']}-{int(settled_at.timestamp()) % 100_000}",
            "settledAt": _iso(settled_at),
        }
        await _save(arena)
    view = _view(arena, user)
    by_id = {m["id"]: m for m in view["members"]}
    s = arena["settlement"]
    return {
        "arena": view,
        "winner": by_id.get(arena["winnerID"]),
        "standings": [by_id[i] for i in s["standingIDs"] if i in by_id],
        "payout": s["payout"],
        "reference": s["reference"],
        "settledAt": s["settledAt"],
    }
