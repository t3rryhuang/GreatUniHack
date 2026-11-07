"""Ask Nova: the teen stage adds safety rules; older clients default to adult."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import nova_api  # noqa: E402
from fastapi import FastAPI  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402


def make_client(monkeypatch, captured):
    async def fake_claude(msgs, max_tokens=400, system=""):
        captured["system"] = system
        captured["max_tokens"] = max_tokens
        return "ok"

    monkeypatch.setattr(nova_api.llm, "OPENAI_READY", True, raising=False)
    monkeypatch.setattr(nova_api.llm, "claude", fake_claude)
    app = FastAPI()
    app.include_router(nova_api.router)
    return TestClient(app)


def test_stage_defaults_to_adult(monkeypatch):
    captured = {}
    client = make_client(monkeypatch, captured)
    r = client.post("/nova/chat", json={"message": "hi", "summary": {}})
    assert r.status_code == 200
    assert "Teen mode" not in captured["system"]


def test_teen_stage_adds_rules(monkeypatch):
    captured = {}
    client = make_client(monkeypatch, captured)
    r = client.post("/nova/chat", json={"message": "should I get a credit card?", "summary": {}, "stage": "teen"})
    assert r.status_code == 200
    assert "Never recommend or suggest credit products" in captured["system"]
    assert captured["max_tokens"] == 300


def test_unknown_stage_rejected(monkeypatch):
    client = make_client(monkeypatch, {})
    r = client.post("/nova/chat", json={"message": "hi", "summary": {}, "stage": "child"})
    assert r.status_code == 422
