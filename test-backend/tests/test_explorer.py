"""Nova Explorer: stylist guardrails and the Community Park cap (no keys or Redis needed)."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import explorer  # noqa: E402
import store  # noqa: E402
from fastapi import FastAPI  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(store, "_REDIS_URL", None)
    monkeypatch.setattr(store, "_REDIS_TOKEN", None)
    monkeypatch.setattr(explorer.llm, "OPENAI_READY", False, raising=False)
    store._memory.clear()
    store._expiry.clear()
    app = FastAPI()
    app.include_router(explorer.router)
    return TestClient(app)


# Stylist ------------------------------------------------------------------

def test_rules_change_the_look(client):
    r = client.post("/explorer/stylist", json={"message": "curly black hair and a teal hoodie with glasses"}).json()
    assert r["patch"] == {"hair": "curly", "hairColour": "black", "top": "hoodie", "topColour": "teal", "accessory": "glasses"}
    assert r["source"] == "rules"


def test_personal_details_are_blocked(client):
    for text in ["my email is jo@example.com", "call me on 07700 900123", "I live at M13 9PL", "see www.example.com"]:
        r = client.post("/explorer/stylist", json={"message": text}).json()
        assert r["reply"] == explorer.PRIVACY_REPLY and r["patch"] == {}


def test_unknown_message_gets_help(client):
    r = client.post("/explorer/stylist", json={"message": "what's the weather?"}).json()
    assert r["patch"] == {} and "hair" in r["reply"]


def test_too_long_input_rejected(client):
    assert client.post("/explorer/stylist", json={"message": "x" * 501}).status_code == 422


def test_llm_output_is_validated(client, monkeypatch):
    async def fake_claude(msgs, max_tokens=300, system=""):
        return '{"reply": "Nice! Visit https://evil.example for more", "patch": {"hair": "mohawk", "topColour": "teal", "evil": "x"}, "confirm": false}'

    monkeypatch.setattr(explorer.llm, "OPENAI_READY", True, raising=False)
    monkeypatch.setattr(explorer.llm, "claude", fake_claude)
    r = client.post("/explorer/stylist", json={"message": "teal top please"}).json()
    assert r["patch"] == {"topColour": "teal"}  # unknown field and value dropped
    assert "http" not in r["reply"] and r["source"] == "llm"


def test_llm_failure_falls_back_to_rules(client, monkeypatch):
    async def broken(*args, **kwargs):
        raise RuntimeError("down")

    monkeypatch.setattr(explorer.llm, "OPENAI_READY", True, raising=False)
    monkeypatch.setattr(explorer.llm, "claude", broken)
    r = client.post("/explorer/stylist", json={"message": "blue jacket"}).json()
    assert r["source"] == "rules" and r["patch"] == {"top": "jacket", "topColour": "blue"}


# Community Park ------------------------------------------------------------

def h(user="ana@example.com"):
    return {"X-User-Id": user}


def test_park_total_and_daily_cap(client):
    assert client.get("/explorer/park").json() == {"total": 0, "contributors": 0}
    assert client.post("/explorer/park/contribute", json={"points": 2}, headers=h()).json() == {"total": 2, "contributors": 1}
    assert client.post("/explorer/park/contribute", json={"points": 1}, headers=h()).json()["total"] == 3
    r = client.post("/explorer/park/contribute", json={"points": 1}, headers=h())
    assert r.status_code == 429  # 4th point today
    assert client.get("/explorer/park").json()["total"] == 3
    # Another player can still give, and counts as a new contributor.
    assert client.post("/explorer/park/contribute", json={"points": 3}, headers=h("ben@example.com")).json() == {"total": 6, "contributors": 2}


def test_park_rejects_bad_points_and_missing_user(client):
    assert client.post("/explorer/park/contribute", json={"points": 0}, headers=h()).status_code == 422
    assert client.post("/explorer/park/contribute", json={"points": 10}, headers=h()).status_code == 422
    assert client.post("/explorer/park/contribute", json={"points": 1}).status_code == 401


def test_player_ids_are_hashed():
    assert "ana@example.com" not in explorer._player("ana@example.com")
