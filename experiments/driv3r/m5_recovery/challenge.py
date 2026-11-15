"""M5 DEVELOPMENT-ONLY synthetic forced-recovery benchmark.

A1/A2/A3 below are deterministic *information-policy proxies*, NOT LiquidAI
d1-2B inference or native CyberSand outcomes.  No fake native receipts.
"""
from __future__ import annotations

import argparse
from collections import deque
import hashlib
import json
from pathlib import Path
import random

W, H = 19, 13
START, GOAL = (1, 6), (15, 6)
BUDGET, RECOVERY_LIMIT = 36, 8
DIRS = (("N", 0, -1), ("E", 1, 0), ("S", 0, 1), ("W", -1, 0))
POLICIES = ("astar", "greedy", "random_legal", "a1_proxy",
            "a2_proxy", "a3_proxy", "a2_shifted", "a3_shifted")


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True,
                                    separators=(",", ":"), allow_nan=False).encode()).hexdigest()


def make_case(name):
    if name not in ("forced_culdesac", "switchback_gate",
                    "misleading_plateau", "sealed_negative", "unblocked_control"):
        raise ValueError("Unknown frozen DEVELOPMENT family")
    hard = {(x, y) for x in range(W) for y in range(H)
            if x in (0, W - 1) or y in (0, H - 1)}
    prefix = () if name == "unblocked_control" else tuple((x, 6) for x in range(2, 9))
    if prefix:
        hard.update((x, y) for x in range(2, 9) for y in (5, 7))
        hard.add((9, 6))  # Original painted forward route ends in a true cul-de-sac.
    if name == "switchback_gate":
        hard.update((11, y) for y in range(1, 12) if y != 2)
    elif name == "misleading_plateau":
        hard.update((10, y) for y in range(1, 10) if y != 9)
    elif name == "sealed_negative":
        hard.update((11, y) for y in range(1, 12))
    assert START not in hard and GOAL not in hard
    assert all(p not in hard for p in prefix)
    case = {"id": name, "split": "development", "w": W, "h": H,
            "start": START, "goal": GOAL, "hard": tuple(sorted(hard)),
            "prefix": prefix, "max_decisions": BUDGET,
            "max_recoveries": RECOVERY_LIMIT}
    return case


def legal(case, painted, cursor, history, recoveries):
    """Host-only cardinal new-cell painting; recovery is brush-up and material-preserving."""
    hard = set(case["hard"])
    items = []
    for name, dx, dy in DIRS:
        point = (cursor[0] + dx, cursor[1] + dy)
        if 0 <= point[0] < case["w"] and 0 <= point[1] < case["h"]:
            if point not in hard and point not in painted:
                items.append(("MOVE_" + name, point, "paint"))
    if recoveries < RECOVERY_LIMIT:
        if len(history) > 2 and sum(abs(a - b) for a, b in zip(history[-2], cursor)) == 1:
            items.append(("BACKTRACK", history[-2], "recover"))
        if len(history) > 5 and cursor != case["start"]:
            items.append(("RELOCATE_START", case["start"], "recover"))
    items.append(("STOP", cursor, "stop"))
    return tuple(sorted(items))


def distances(case, painted):
    """Optimal available future empty-cell traversal (not a native transport)."""
    hard = set(case["hard"]) | set(painted)
    goal = case["goal"]
    if goal in hard:
        return {}
    queue = deque([goal])
    dist = {goal: 0}
    while queue:
        x, y = queue.popleft()
        for _, dx, dy in DIRS:
            p = (x + dx, y + dy)
            if p not in hard and p not in dist:
                dist[p] = dist[(x, y)] + 1
                queue.append(p)
    return dist


def remaining(case, painted, point):
    # Point is permitted to be the currently occupied cursor or newly painted destination.
    free = set(painted) - {point}
    return distances(case, free).get(point, 10_000)


def signals(case, point):
    """Static extra-information diagnostics, never permissions or real M1 raster artifacts."""
    x, y = point
    gx, gy = case["goal"]
    # Scalar core deliberately favours a painted cul-de-sac and the misleading upper plateau.
    core = max(0, 65535 - 1900 * (abs(x - gx) + abs(y - gy)))
    if y == 6 and 3 <= x <= 9:
        core = 65535
    if case["id"] == "misleading_plateau" and y < 6:
        core = min(65535, core + 10000)
    # Extra A2 and A3 channels are explicitly richer than the shared A1 core.
    # The following are diagnostic reference signals, not actual d1 observations.
    distance = remaining(case, (), point)
    attraction = max(0, 65535 - 1400 * distance) if distance < 10_000 else 0
    neighbour_hard = sum((x + dx, y + dy) in set(case["hard"])
                         for _, dx, dy in DIRS)
    avoidance = 9000 * neighbour_hard
    geometry = distance
    return core, attraction, avoidance, geometry


def shifted(case, point):
    # Information ablation: spatially shift auxiliary samples without changing core.
    return ((point[0] + 7) % case["w"], (point[1] + 3) % case["h"])


def choose(policy, case, painted, cursor, history, offers, rng):
    if cursor == case["goal"]:
        return "STOP"
    if policy == "random_legal":
        return rng.choice([o[0] for o in offers])
    items = [o for o in offers if o[2] != "stop"]
    if not items:
        return "STOP"
    if policy in ("greedy", "a1_proxy"):
        # Deliberately myopic procedural policy: direct distance and soft scalar.
        forward = [o for o in items if o[2] == "paint"]
        if forward:
            return min(forward, key=lambda o: (
                abs(o[1][0] - case["goal"][0]) +
                abs(o[1][1] - case["goal"][1]) -
                signals(case, o[1])[0] / 15000, o[0]))[0]
        # Without lookahead, wastes recovery budget taking one step back at a time.
        for name in ("BACKTRACK", "RELOCATE_START"):
            if any(o[0] == name for o in items):
                return name
        return "STOP"
    if policy not in ("astar", "a2_proxy", "a3_proxy", "a2_shifted", "a3_shifted"):
        raise ValueError("Unknown policy")
    evaluated = []
    for name, point, kind in items:
        post = set(painted)
        if kind == "paint":
            post.add(point)
        distance = remaining(case, post, point)
        if distance >= 10_000:
            continue
        penalty = 0.0
        if policy != "astar":
            extra_point = shifted(case, point) if policy.endswith("_shifted") else point
            core, attr, avoid, geom = signals(case, extra_point)
            # A2: preference semantics. A3: geometric cost; both receive same core.
            if policy.startswith("a2_"):
                penalty = (65535 - attr) / 16000 + avoid / 14000 - core / 200000
            else:
                penalty = geom / 8 - core / 200000
        evaluated.append((distance + penalty, kind != "paint", name))
    if evaluated:
        return min(evaluated)[-1]
    return "STOP"


def run(case, policy, seed=570):
    """A single synthetic episode; frozen prefix is recorded but does not spend model turns."""
    painted = {case["start"], *case["prefix"]}
    history = [case["start"], *case["prefix"]]
    cursor = history[-1]
    recovery_count = 0
    steps_after_recovery = 0
    events = []
    rng = random.Random(seed)
    initial_material = digest(sorted(painted))
    initial_legal = digest(legal(case, painted, cursor, history, 0))
    for i in range(BUDGET):
        offered = legal(case, painted, cursor, history, recovery_count)
        cid = choose(policy, case, painted, cursor, history, offered, rng)
        allowed = {o[0]: o for o in offered}
        if cid not in allowed:
            raise AssertionError("Policy produced a non-host-legal candidate")
        name, target, kind = allowed[cid]
        prev_material = digest(sorted(painted))
        previous_cursor = cursor
        if kind == "paint":
            assert target not in painted and target not in case["hard"]
            painted.add(target)
            cursor = target
            history.append(target)
            if recovery_count:
                steps_after_recovery += 1
        elif name == "BACKTRACK":
            assert target == history[-2]
            history.pop()
            cursor = target
            recovery_count += 1
        elif name == "RELOCATE_START":
            assert target == case["start"]
            history.append(target)
            cursor = target
            recovery_count += 1
        # STOP is an original policy result, never silently replaced.
        assert (digest(sorted(painted)) == prev_material) == (kind != "paint")
        event = {"i": i, "cursor_before": previous_cursor, "cursor_after": cursor,
                 "choice": cid, "kind": kind, "candidate_catalog_sha256": digest(offered),
                 "material_before_sha256": prev_material,
                 "material_after_sha256": digest(sorted(painted)),
                 "native_receipt": None, "model_identity": None}
        events.append(event)
        if kind == "stop" or cursor == case["goal"]:
            break
    connected = _components(painted) == 1
    score = {
        "schema": "driv3r-m5-synthetic-challenge/1",
        "fixture_id": case["id"], "split": "development",
        "policy": policy, "seed": seed,
        "case_sha256": digest(case), "initial_material_sha256": initial_material,
        "first_legal_catalog_sha256": initial_legal,
        "terminated_at_goal": cursor == case["goal"],
        "stop_reason": "goal" if cursor == case["goal"] else
                       ("selected_STOP" if events and events[-1]["choice"] == "STOP" else "budget"),
        "decisions": len(events), "model_decisions": 0,
        "new_painted_cells": len(painted) - len(case["prefix"]) - 1,
        "recovery_interventions": recovery_count,
        "productive_new_cells_after_recovery": steps_after_recovery,
        "connected_material": connected, "connected_components": _components(painted),
        "final_material_sha256": digest(sorted(painted)),
        "trace_sha256": digest(events),
        "native_qualified": False, "model_qualified": False,
        "events": events,
    }
    return score


def _components(cells):
    unseen = set(cells)
    count = 0
    while unseen:
        count += 1
        queue = [unseen.pop()]
        while queue:
            x, y = queue.pop()
            for _, dx, dy in DIRS:
                nxt = (x + dx, y + dy)
                if nxt in unseen:
                    unseen.remove(nxt)
                    queue.append(nxt)
    return count


def cohort():
    result = {}
    for name in ("forced_culdesac", "switchback_gate", "misleading_plateau",
                 "sealed_negative", "unblocked_control"):
        case = make_case(name)
        result[name] = {policy: run(case, policy) for policy in POLICIES}
        if len({x["initial_material_sha256"] for x in result[name].values()}) != 1:
            raise AssertionError("Non-matched initial material")
        if len({x["first_legal_catalog_sha256"] for x in result[name].values()}) != 1:
            raise AssertionError("Non-matched first legal candidate set")
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    data = cohort()
    compact = {case: {p: {k: r[k] for k in (
        "terminated_at_goal", "stop_reason", "decisions",
        "new_painted_cells", "recovery_interventions",
        "productive_new_cells_after_recovery", "connected_components")}
        for p, r in arms.items()} for case, arms in data.items()}
    output = {"schema": "driv3r-m5-development-report/1",
              "evidence_class": "synthetic_only", "native_qualified": False,
              "model_qualified": False, "original_m4_sha": 
              "ad48cdba21d8b83fe5bb83caed68d4cb0ce1ca1b",
              "cases": compact, "cohort_sha256": digest(data),
              "limitations": [
                  "All eight policies are algorithmic, not actual d1-2B inference.",
                  "Additional A2/A3 proxy signals include stronger geometric information.",
                  "No native PAINT receipts, screen captures or held-out evaluation.",
                  "Development diagnostics do not establish model superiority.",
              ]}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    print(json.dumps(output, sort_keys=True))


if __name__ == "__main__":
    main()
