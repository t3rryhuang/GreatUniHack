"""Teen arena fairness: members with very different incomes and the same
behaviour should tie (or nearly tie). Older clients and adult arenas keep working."""

import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import arena  # noqa: E402
import store  # noqa: E402
from fastapi import FastAPI  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402


def member(name, **kw):
    base = {"id": name, "userId": name, "name": name, "currentSpend": 0.0, "currentSavings": 0.0,
            "isEliminated": False, "baselineSpend": None, "personalTarget": None}
    base.update(kw)
    return base


def teen(mode, *members):
    return {"mode": mode, "targetAmount": 0, "teen": True, "members": list(members)}


def order(a):
    return [m["name"] for m in arena._standings(a)]


# ---------------------------------------------------------------------------
# Same behaviour, different money: tie (only the name decides)
# ---------------------------------------------------------------------------

def test_budget_guardian_same_behaviour_ties_across_incomes():
    # Both spend 20% under their own usual spending: £12 of £15, and £80 of £100.
    a = teen("budget_guardian", member("ben", currentSpend=80, baselineSpend=100), member("amy", currentSpend=12, baselineSpend=15))
    standings = arena._standings(a)
    ratios = [(m["baselineSpend"] - m["currentSpend"]) / m["baselineSpend"] for m in standings]
    assert ratios[0] == pytest.approx(ratios[1])
    # A tie is broken by name only, never by who spent fewer pounds.
    assert order(a) == ["amy", "ben"]


def test_budget_guardian_ranks_by_percent_not_lowest_pounds():
    # Rich member spends least in £ but only 5% under; low-income member is 30% under.
    a = teen("budget_guardian", member("rich", currentSpend=95, baselineSpend=100), member("low", currentSpend=14, baselineSpend=20))
    assert order(a) == ["low", "rich"]


def test_savings_sprint_same_progress_ties_across_incomes():
    a = teen("savings_sprint", member("zed", currentSavings=60, personalTarget=120), member("ana", currentSavings=5, personalTarget=10))
    assert order(a) == ["ana", "zed"]  # both 50%: name decides


def test_savings_sprint_first_to_own_target_wins():
    a = teen("savings_sprint",
             member("big", currentSavings=500, personalTarget=600),
             member("small", currentSavings=10, personalTarget=10, targetReachedAt="2026-01-02T00:00:00Z"))
    assert order(a) == ["small", "big"]
    assert arena._can_settle({**a, "status": "active", "endDate": "2099-01-01T00:00:00Z"}) is None


def test_most_improved_teen_tie_ignores_pounds():
    a = teen("most_improved", member("zara", currentSpend=75, baselineSpend=100), member("adam", currentSpend=15, baselineSpend=20))
    assert order(a) == ["adam", "zara"]


def test_missing_personal_figures_rank_last():
    a = teen("budget_guardian", member("none", currentSpend=1), member("has", currentSpend=110, baselineSpend=100))
    assert order(a) == ["has", "none"]


def test_adult_arena_unchanged():
    adult = {"mode": "budget_guardian", "targetAmount": 100,
             "members": [member("a", currentSpend=90, baselineSpend=200), member("b", currentSpend=50, baselineSpend=55)]}
    assert order(adult) == ["b", "a"]  # lowest spend under the shared target, as before


# ---------------------------------------------------------------------------
# API
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


def make(client, mode, teen_flag=True):
    end = (datetime.now(timezone.utc) + timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%SZ")
    body = {"name": "Teen", "mode": mode, "targetAmount": 0, "stakeAmount": 0, "endDate": end}
    if teen_flag is not None:
        body["teen"] = teen_flag
    r = client.post("/arenas", headers=h("amy"), json=body)
    assert r.status_code == 200, r.text
    return r.json()


def test_teen_budget_guardian_api_tie(client):
    a = make(client, "budget_guardian")
    assert a["teen"] is True
    client.post("/arenas/join", headers=h("ben"), json={"code": a["joinCode"]})
    client.post(f"/arenas/{a['id']}/sync", headers=h("amy"), json={"currentSpend": 12, "baselineSpend": 15})
    r = client.post(f"/arenas/{a['id']}/sync", headers=h("ben"), json={"currentSpend": 80, "baselineSpend": 100})
    members = {m["name"]: m for m in r.json()["members"]}
    assert members["Amy"]["exceededAt"] is None and members["Ben"]["exceededAt"] is None

    data = json.loads(store._memory[f"arena:{a['id']}"])
    data["endDate"] = "2020-01-01T00:00:00Z"
    store._memory[f"arena:{a['id']}"] = json.dumps(data)
    s = client.post(f"/arenas/{a['id']}/settle", headers=h("amy")).json()
    assert [m["name"] for m in s["standings"]] == ["Amy", "Ben"]  # tie, name order
    assert s["payout"] == 0


def test_teen_over_own_limit_marks_exceeded(client):
    a = make(client, "budget_guardian")
    r = client.post(f"/arenas/{a['id']}/sync", headers=h("amy"), json={"currentSpend": 20, "baselineSpend": 15})
    assert r.json()["members"][0]["exceededAt"] is not None


def test_teen_savings_sprint_personal_target(client):
    a = make(client, "savings_sprint")
    r = client.post(f"/arenas/{a['id']}/sync", headers=h("amy"), json={"currentSavings": 10, "personalTarget": 10})
    me = r.json()["members"][0]
    assert me["personalTarget"] == 10 and me["targetReachedAt"] is not None


def test_older_client_create_without_teen_flag(client):
    a = make(client, "budget_guardian", teen_flag=None)
    assert a.get("teen") is None
    r = client.post(f"/arenas/{a['id']}/sync", headers=h("amy"), json={"currentSpend": 5})
    assert r.status_code == 200
