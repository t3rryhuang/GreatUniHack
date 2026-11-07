"""Tests for the arena rules and API (in-memory storage, no Redis needed)."""

import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import arena  # noqa: E402
import store  # noqa: E402
from fastapi import FastAPI  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402


def member(name, spend=0.0, baseline=None, savings=0.0, **extra):
    return {"id": name, "userId": name, "name": name, "currentSpend": spend, "currentSavings": savings,
            "isEliminated": False, "baselineSpend": baseline, **extra}


def improved(*members):
    return {"mode": "most_improved", "targetAmount": 0, "members": list(members)}


# ---------------------------------------------------------------------------
# Most Improved ranking
# ---------------------------------------------------------------------------

def test_most_improved_ranks_by_percentage_cut_not_pounds():
    # Bea cuts £40 of £200 (20%); Ali cuts £15 of £50 (30%). Ali wins on %.
    a = improved(member("bea", spend=160, baseline=200), member("ali", spend=35, baseline=50))
    assert [m["name"] for m in arena._standings(a)] == ["ali", "bea"]


def test_most_improved_spending_more_ranks_below_cutting():
    a = improved(member("up", spend=60, baseline=50), member("down", spend=45, baseline=50))
    assert [m["name"] for m in arena._standings(a)] == ["down", "up"]


def test_most_improved_tie_break_lower_spend_then_name():
    # Same 25% cut: lower current spend wins; same spend: alphabetical.
    a = improved(member("big", spend=75, baseline=100), member("small", spend=30, baseline=40))
    assert [m["name"] for m in arena._standings(a)] == ["small", "big"]
    b = improved(member("zoe", spend=30, baseline=40), member("amy", spend=30, baseline=40))
    assert [m["name"] for m in arena._standings(b)] == ["amy", "zoe"]


def test_most_improved_missing_baseline_ranks_last():
    a = improved(
        member("none", spend=10, baseline=None),
        member("zero", spend=5, baseline=0),
        member("has", spend=90, baseline=80),  # spent more, but has a baseline
    )
    assert [m["name"] for m in arena._standings(a)] == ["has", "zero", "none"]


def test_most_improved_member_without_baseline_key_still_ranks():
    # Members stored by an older backend have no baselineSpend key at all.
    old = member("old", spend=10)
    del old["baselineSpend"]
    a = improved(old, member("new", spend=40, baseline=50))
    assert [m["name"] for m in arena._standings(a)] == ["new", "old"]


def test_existing_modes_unchanged():
    bg = {"mode": "budget_guardian", "targetAmount": 100,
          "members": [member("a", spend=90), member("b", spend=50), member("c", spend=120, exceededAt="2026-01-02T00:00:00Z")]}
    assert [m["name"] for m in arena._standings(bg)] == ["b", "a", "c"]
    ss = {"mode": "savings_sprint", "targetAmount": 100,
          "members": [member("a", savings=40), member("b", savings=100, targetReachedAt="2026-01-02T00:00:00Z")]}
    assert [m["name"] for m in arena._standings(ss)] == ["b", "a"]


# ---------------------------------------------------------------------------
# API (in-memory store)
# ---------------------------------------------------------------------------

@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(store, "_REDIS_URL", None)
    monkeypatch.setattr(store, "_REDIS_TOKEN", None)
    store._memory.clear()
    app = FastAPI()
    app.include_router(arena.router)
    return TestClient(app)


def h(user):
    return {"X-User-Id": f"{user}@example.com", "X-User-Name": user.title()}


def create(client, mode="most_improved", stake=0, days=7, target=0):
    end = (datetime.now(timezone.utc) + timedelta(days=days)).strftime("%Y-%m-%dT%H:%M:%SZ")
    r = client.post("/arenas", headers=h("ana"), json={
        "name": "Spend-Off", "mode": mode, "targetAmount": target, "stakeAmount": stake, "endDate": end})
    assert r.status_code == 200, r.text
    return r.json()


def test_most_improved_sync_and_settle(client):
    a = create(client)
    client.post("/arenas/join", headers=h("ben"), json={"code": a["joinCode"]})
    r = client.post(f"/arenas/{a['id']}/sync", headers=h("ana"), json={"currentSpend": 40, "baselineSpend": 80})
    assert r.status_code == 200
    me = next(m for m in r.json()["members"] if m["isCurrentUser"])
    assert me["baselineSpend"] == 80 and me["currentSpend"] == 40
    assert me["exceededAt"] is None  # no spending limit in Most Improved
    client.post(f"/arenas/{a['id']}/sync", headers=h("ben"), json={"currentSpend": 70, "baselineSpend": 80})

    # Not ended yet: settlement waits for the end date.
    assert client.post(f"/arenas/{a['id']}/settle", headers=h("ana")).status_code == 400
    stored = store._memory[f"arena:{a['id']}"]
    import json
    data = json.loads(stored)
    data["endDate"] = "2020-01-01T00:00:00Z"
    store._memory[f"arena:{a['id']}"] = json.dumps(data)

    s = client.post(f"/arenas/{a['id']}/settle", headers=h("ben")).json()
    assert s["winner"]["name"] == "Ana"
    assert s["payout"] == 0  # no stake: points and badges only


def test_older_client_without_baseline_still_syncs(client):
    a = create(client)
    r = client.post(f"/arenas/{a['id']}/sync", headers=h("ana"), json={"currentSpend": 25, "currentSavings": 0})
    assert r.status_code == 200
    me = r.json()["members"][0]
    assert me["currentSpend"] == 25 and me["baselineSpend"] is None


def test_zero_stake_budget_guardian_still_works(client):
    a = create(client, mode="budget_guardian", target=100)
    assert a["stakeAmount"] == 0
    r = client.post(f"/arenas/{a['id']}/sync", headers=h("ana"), json={"currentSpend": 120})
    me = r.json()["members"][0]
    assert me["exceededAt"] is not None
