"""Read-only, independent event-replay audit for M5 SYNTHETIC ONLY.

This audit reads recorded host choices; it does not rerun a policy chooser or
claim CyberSand/native/model receipts.  Geometry metrics are derived from
reconstructed material, never from a policy's claimed success labels.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path

from .challenge import (POLICIES, START, cohort, digest, legal, make_case,
                        _components, DIRS)


def verify(case, outcome):
    if outcome["case_sha256"] != digest(case):
        raise ValueError("Case source changed")
    if outcome.get("native_qualified") or outcome.get("model_qualified") or outcome["model_decisions"]:
        raise ValueError("Synthetic record must not claim native/model qualification")
    painted = {case["start"], *case["prefix"]}
    cursor = case["prefix"][-1] if case["prefix"] else case["start"]
    history = [case["start"], *case["prefix"]]
    recoveries = 0
    new_after_recovery = 0
    first_legal = digest(legal(case, painted, cursor, history, 0))
    if first_legal != outcome["first_legal_catalog_sha256"]:
        raise ValueError("Initial legal catalog mismatch")
    if digest(sorted(painted)) != outcome["initial_material_sha256"]:
        raise ValueError("Initial painted material mismatch")
    if not outcome["events"] or len(outcome["events"]) > case["max_decisions"]:
        raise ValueError("Invalid decision count")
    for i, event in enumerate(outcome["events"]):
        if event["i"] != i or event["cursor_before"] != cursor:
            raise ValueError("Cursor or event index forged")
        if event.get("model_identity") is not None or event.get("native_receipt") is not None:
            raise ValueError("Forged model/native evidence")
        options = legal(case, painted, cursor, history, recoveries)
        if event["candidate_catalog_sha256"] != digest(options):
            raise ValueError("Host legal catalog stale/forged")
        menu = {item[0]: item for item in options}
        if event["choice"] not in menu:
            raise ValueError("Nonlegal choice")
        chosen = menu[event["choice"]]
        name, target, kind = chosen
        if kind != event["kind"] or event["material_before_sha256"] != digest(sorted(painted)):
            raise ValueError("Operation/material source fence wrong")
        if kind == "paint":
            if target in painted or target in case["hard"]:
                raise ValueError("Illegal painted material")
            painted.add(target)
            cursor = target
            history.append(target)
            if recoveries:
                new_after_recovery += 1
        elif name == "BACKTRACK":
            if target != history[-2]:
                raise ValueError("Backtrack escaped visited path")
            history.pop()
            cursor = target
            recoveries += 1
        elif name == "RELOCATE_START":
            if target != case["start"]:
                raise ValueError("Relocate escaped approved branch")
            history.append(target)
            cursor = target
            recoveries += 1
        elif kind != "stop":
            raise ValueError("Unknown operation")
        if cursor != tuple(event["cursor_after"]):
            raise ValueError("Post-action cursor forged")
        if digest(sorted(painted)) != event["material_after_sha256"]:
            raise ValueError("Post-action material forged")
        if kind == "stop" and i != len(outcome["events"]) - 1:
            raise ValueError("Action after STOP")
    if cursor != case["goal"] and len(outcome["events"]) < case["max_decisions"]:
        if outcome["events"][-1]["choice"] != "STOP":
            raise ValueError("Early termination without STOP")
    if digest(outcome["events"]) != outcome["trace_sha256"]:
        raise ValueError("Decision events unexpectedly changed")
    if digest(sorted(painted)) != outcome["final_material_sha256"]:
        raise ValueError("Final material forged")
    if cursor == case["goal"] != outcome["terminated_at_goal"]:
        raise ValueError("Goal label forged")
    if new_after_recovery != outcome["productive_new_cells_after_recovery"]:
        raise ValueError("Recovery productivity forged")
    if recoveries != outcome["recovery_interventions"]:
        raise ValueError("Recovery count forged")
    base = {case["start"], *case["prefix"]}
    fresh = painted - base
    if len(fresh) != outcome["new_painted_cells"] or _components(painted) != outcome["connected_components"]:
        raise ValueError("New-material or connectivity metric forged")
    n_components = _components(painted)
    articulations = [p for p in fresh if _components(painted - {p}) > n_components]
    branch_nodes = sum(
        sum((x + dx, y + dy) in painted for _, dx, dy in DIRS) >= 3
        for x, y in painted
    )
    return {
        "goal_reached_verified": cursor == case["goal"],
        "new_cells_verified": len(fresh),
        "recoveries_verified": recoveries,
        "productive_cells_after_recovery_verified": new_after_recovery,
        "connected_components_verified": n_components,
        "new_single_cell_articulations": len(articulations),
        "new_articulation_fraction": round(len(articulations) / len(fresh), 4) if fresh else None,
        "branch_nodes": branch_nodes,
        "final_material_sha256": digest(sorted(painted)),
    }


def compare_arms(cases):
    audited = {}
    for name, arms in cases.items():
        case = make_case(name)
        verified = {policy: verify(case, data) for policy, data in arms.items()}
        if set(verified) != set(POLICIES):
            raise ValueError("Incomplete policy cohort")
        initial = {(v["initial_material_sha256"], v["first_legal_catalog_sha256"],
                    v["case_sha256"]) for v in arms.values()}
        if len(initial) != 1:
            raise ValueError("Unmatched initial World, legality or case")
        audited[name] = verified
    reachable = [name for name in audited if name != "sealed_negative"]
    rates = {}
    for policy in POLICIES:
        solved = sum(audited[name][policy]["goal_reached_verified"] for name in reachable)
        rates[policy] = {
            "reachable_completed": solved,
            "denominator": len(reachable),
            "development_only": True,
            "new_cell_total": sum(audited[name][policy]["new_cells_verified"] for name in reachable),
            "total_recovery_interventions": sum(audited[name][policy]["recoveries_verified"]
                                                for name in reachable),
            "new_articulation_cells_total": sum(
                audited[name][policy]["new_single_cell_articulations"] for name in reachable),
        }
    return {
        "schema": "driv3r-m5-independent-synthetic-material-audit/1",
        "source_class": "synthetic_only",
        "genuine_model_inference": False,
        "genuine_native_material": False,
        "all_cases": audited,
        "rates": rates,
        "strong_astar_uplift_unproved": True,
        "limits": [
            "Reconstructs source-frozen synthetic event geometry; not Godot replay.",
            "Proxy A2/A3 carry extra hard-mask-derived information.",
            "One-cell paths are often structurally fragile even if connected.",
            "Synthetic results do not establish d1-2B efficacy or aesthetics.",
        ],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = compare_arms(cohort())
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": "SYNTHETIC_REPLAY_PASS",
                      "rates": report["rates"], "report_sha256": digest(report)},
                     sort_keys=True))


if __name__ == "__main__":
    main()
