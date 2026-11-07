"""LLM provider clients.

If RUNWARE_API_KEY is set, all three "providers" (Claude, Gemini, GPT) are routed
through Runware's OpenAI- and Anthropic-compatible endpoints with a single key.
Otherwise the native ANTHROPIC_API_KEY / GEMINI_API_KEY / OPENAI_API_KEY are used.
"""
import os

import anthropic
from openai import AsyncOpenAI

RUNWARE_API_KEY = os.getenv("RUNWARE_API_KEY")
RUNWARE_BASE = "https://api.runware.ai"

USE_RUNWARE = bool(RUNWARE_API_KEY)

if USE_RUNWARE:
    CLAUDE_MODEL = os.getenv("CLAUDE_MODEL", "anthropic:claude@haiku-5.5")
    GEMINI_MODEL = os.getenv("GEMINI_MODEL", "google:gemini@3.5-flash-lite")
    GPT_MODEL = os.getenv("GPT_MODEL", "openai:gpt@5.4-mini")
else:
    CLAUDE_MODEL = os.getenv("CLAUDE_MODEL", "claude-haiku-4-5-20251001")
    GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash-lite")
    GPT_MODEL = os.getenv("GPT_MODEL", "gpt-4o-mini")

# "Key present" flags used by main.py guards.
ANTHROPIC_READY = USE_RUNWARE or bool(os.getenv("ANTHROPIC_API_KEY"))
GEMINI_READY = USE_RUNWARE or bool(os.getenv("GEMINI_API_KEY"))
OPENAI_READY = USE_RUNWARE or bool(os.getenv("OPENAI_API_KEY"))


def claude_client() -> anthropic.AsyncAnthropic:
    if USE_RUNWARE:
        return anthropic.AsyncAnthropic(base_url=RUNWARE_BASE, auth_token=RUNWARE_API_KEY, api_key=None)
    return anthropic.AsyncAnthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))


def openai_client() -> AsyncOpenAI:
    if USE_RUNWARE:
        return AsyncOpenAI(base_url=f"{RUNWARE_BASE}/v1", api_key=RUNWARE_API_KEY)
    return AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))


async def gpt(messages: list[dict], max_tokens: int = 1024, temperature: float | None = None) -> str:
    if USE_RUNWARE:
        # GPT-5.x reasoning tokens count against this budget; tiny budgets can return empty text.
        max_tokens = max(max_tokens, 1000)
    kwargs = {"model": GPT_MODEL, "messages": messages, "max_completion_tokens": max_tokens}
    if temperature is not None and not USE_RUNWARE:
        kwargs["temperature"] = temperature
    resp = await openai_client().chat.completions.create(**kwargs)
    return (resp.choices[0].message.content or "").strip()


async def gemini(prompt: str, max_tokens: int = 2048) -> str:
    if USE_RUNWARE:
        resp = await openai_client().chat.completions.create(
            model=GEMINI_MODEL,
            messages=[{"role": "user", "content": prompt}],
            max_completion_tokens=max_tokens,
        )
        return (resp.choices[0].message.content or "").strip()
    from google import genai

    client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
    response = await client.aio.models.generate_content(model=GEMINI_MODEL, contents=prompt)
    return response.text or ""


async def claude(messages: list[dict], max_tokens: int = 1024, system: str | None = None) -> str:
    kwargs = {"model": CLAUDE_MODEL, "max_tokens": max_tokens, "messages": messages}
    if USE_RUNWARE:
        # Newer Claude models think by default, which can use up the whole token budget
        # on short structured tasks. These prompts don't need it.
        kwargs["thinking"] = {"type": "disabled"}
    if system:
        kwargs["system"] = system
    message = await claude_client().messages.create(**kwargs)
    return "".join(b.text for b in message.content if getattr(b, "type", "") == "text")
