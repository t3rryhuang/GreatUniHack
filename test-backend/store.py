"""Tiny key-value store: Upstash Redis over REST, or in-memory for local dev.

Env vars are injected by the Vercel Upstash integration: KV_REST_API_URL /
KV_REST_API_TOKEN (or UPSTASH_REDIS_REST_URL / UPSTASH_REDIS_REST_TOKEN).
"""
from __future__ import annotations

import os
import time

import httpx
from fastapi import HTTPException

_REDIS_URL = os.getenv("KV_REST_API_URL") or os.getenv("UPSTASH_REDIS_REST_URL")
_REDIS_TOKEN = os.getenv("KV_REST_API_TOKEN") or os.getenv("UPSTASH_REDIS_REST_TOKEN")
_memory: dict[str, object] = {}
_expiry: dict[str, float] = {}


def backend() -> str:
    return "upstash" if _REDIS_URL and _REDIS_TOKEN else "memory"


async def _redis(*cmd: str):
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.post(_REDIS_URL, headers={"Authorization": f"Bearer {_REDIS_TOKEN}"}, json=list(cmd))
        r.raise_for_status()
        body = r.json()
        if "error" in body:
            raise HTTPException(status_code=502, detail=f"Storage error: {body['error']}")
        return body.get("result")


def _mem_alive(key: str) -> bool:
    exp = _expiry.get(key)
    if exp is not None and exp < time.time():
        _memory.pop(key, None)
        _expiry.pop(key, None)
        return False
    return key in _memory


async def get(key: str) -> str | None:
    if backend() == "memory":
        return _memory.get(key) if _mem_alive(key) else None  # type: ignore[return-value]
    return await _redis("GET", key)


async def put(key: str, value: str, ttl: int | None = None) -> None:
    if backend() == "memory":
        _memory[key] = value
        if ttl:
            _expiry[key] = time.time() + ttl
        else:
            _expiry.pop(key, None)
        return
    if ttl:
        await _redis("SET", key, value, "EX", str(ttl))
    else:
        await _redis("SET", key, value)


async def setnx(key: str, value: str, ttl: int | None = None) -> bool:
    """Set only if the key doesn't exist. Returns True if it was set."""
    if backend() == "memory":
        if _mem_alive(key):
            return False
        await put(key, value, ttl)
        return True
    cmd = ["SET", key, value, "NX"] + (["EX", str(ttl)] if ttl else [])
    return bool(await _redis(*cmd))


async def delete(key: str) -> None:
    if backend() == "memory":
        _memory.pop(key, None)
        _expiry.pop(key, None)
        return
    await _redis("DEL", key)


async def sadd(key: str, member: str) -> None:
    if backend() == "memory":
        _memory.setdefault(key, set()).add(member)  # type: ignore[union-attr]
        return
    await _redis("SADD", key, member)


async def smembers(key: str) -> list[str]:
    if backend() == "memory":
        return list(_memory.get(key, ()))  # type: ignore[arg-type]
    return await _redis("SMEMBERS", key) or []


async def incrby(key: str, amount: int, ttl: int | None = None) -> int:
    """Atomically adds to an integer counter and returns the new value."""
    if backend() == "memory":
        if not _mem_alive(key):
            _memory.pop(key, None)
        value = int(_memory.get(key, 0)) + amount  # type: ignore[arg-type]
        _memory[key] = str(value)
        if ttl and key not in _expiry:
            _expiry[key] = time.time() + ttl
        return value
    value = int(await _redis("INCRBY", key, str(amount)))
    if ttl:
        await _redis("EXPIRE", key, str(ttl), "NX")
    return value
