#!/usr/bin/env python3
"""Execute one preregistered external curiosity contrast against frozen a725."""
from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import subprocess
import sys

APPLICATION = "a7250e15495667b2fcf564cbed1eaa8dea217c45"
INPUTS = (
    "tools/ambient/diagnostics/curiosity_contrast.gd",
    "tools/ambient/diagnostics/run_curiosity_contrast.py",
    "docs/research/ambient-002/curiosity-preregistration.md",
)


def external_custody(repo, commit):
    result = {}
    for path in INPUTS:
        original = subprocess.check_output(["git", "show", commit+":"+path], cwd=repo)
        actual = (repo/path).read_bytes()
        if actual != original:
            raise ValueError("External preregistered input changed: "+path)
        result[path] = hashlib.sha256(actual).hexdigest()
    return {"source_commit": commit, "sha256": result}


def primary(row):
    trace = row["trace"]
    first = trace[0]
    reference = first["oil"]["nearest"]
    selected = [s for s in trace if 0 <= s["seconds"] < 10.0-1e-8]
    if len(selected) != 100:
        raise ValueError("Primary window is not exactly100 decision samples")
    xs = [s["position"][0] for s in selected]
    initial_distance = abs(xs[0]-reference[0])
    return {
        "window_seconds": [0, 10], "samples": len(selected),
        "initial_observed_oil": reference,
        "investigation_seconds": sum(s["selection"] == "discovery" for s in selected)*.1,
        "horizontal_approach_gain_cells": initial_distance-min(abs(x-reference[0]) for x in xs),
        "initial_horizontal_distance_cells": initial_distance,
        "net_x_cells": xs[-1]-xs[0], "x_range_cells": max(xs)-min(xs),
        "initial_policy_oil": first["policy_oil"],
        "initial_candidates": first["candidates"],
    }


def compare(report, analysis):
    by_seed = {}
    for case in report["campaigns"]:
        by_seed.setdefault(case["seed"], {})[case["arm"]] = case
    analysis.require(set(by_seed) == {605, 1701, 2909}, "Exact preregistered seeds required")
    result = []
    for seed, arms in sorted(by_seed.items()):
        analysis.require(set(arms) == {"low_curiosity", "high_curiosity"}, "Both matched arms required")
        low, high = arms["low_curiosity"], arms["high_curiosity"]
        for key in ("initial_materials", "initial_pose_sha256", "geometry", "model", "seed", "seconds", "actor_count"):
            analysis.require(low[key] == high[key], "Unequal matched initial input: "+key)
        a, b = low["episodes"][0], high["episodes"][0]
        pa, pb = deepcopy(a["profile"]), deepcopy(b["profile"])
        analysis.require(pa["personality"].pop("curiosity") == 0.0 and
                         pb["personality"].pop("curiosity") == 1.0 and pa == pb,
                         "Profiles must differ only in curiosity0 versus1")
        for target in ("oil", "policy_oil"):
            first_a, first_b = a["trace"][0][target], b["trace"][0][target]
            analysis.require(first_a == first_b and first_a["available"] and first_a["present"],
                             "Initial actual Oil coverage is absent or unmatched: "+target)
        left, right = primary(a), primary(b)
        gains = {key: right[key]-left[key] for key in (
            "investigation_seconds", "horizontal_approach_gain_cells", "net_x_cells", "x_range_cells")}
        secondary = {}
        for arm, case, row in (("low", low, a), ("high", high, b)):
            metrics = analysis.episode_metrics(case, row)
            trace = row["trace"]
            inspected = [s for s in trace if s["selection"] == "discovery" and s["phase"] == "inspect"]
            secondary[arm] = {
                "whole_episode_metrics": metrics,
                "inspection_seconds": len(inspected)*.1,
                "first_inspection_seconds": inspected[0]["seconds"] if inspected else None,
                "inspection_samples": [{key: s[key] for key in (
                    "seconds", "position", "goal_target", "policy_oil", "action_move")} for s in inspected],
                "discovery_inactive_reasons": sorted({str(c.get("reason", "")) for s in trace
                    for c in s["candidates"] if c["id"] == "discovery" and not c["active"]}),
                "common_oil_present_samples": sum(s["oil"]["present"] for s in trace),
                "policy_oil_present_samples": sum(s["policy_oil"]["present"] for s in trace),
            }
        result.append({"seed": seed, "low": left, "high": right, "high_minus_low": gains,
            "joint_directional_support": gains["investigation_seconds"] > 0 and
                gains["horizontal_approach_gain_cells"] > 0,
            "secondary": secondary})
    supporting = sum(p["joint_directional_support"] for p in result)
    return {"pairs": result, "supporting_pairs": supporting,
        "predeclared_directional_hypothesis_supported": supporting >= 2,
        "interpretation": "Three matched seed pairs for one authored goal competition; no population significance, "
            "universal curiosity or greater overall exploration claim. Secondary inspection is separate from choice."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--diagnostic-source", required=True)
    args = parser.parse_args()
    args.root = args.root.resolve(); args.godot = args.godot.resolve(); args.output = args.output.resolve()
    args.source_sha = APPLICATION; args.case_timeout = 1800
    repo = Path(__file__).resolve().parents[3]
    external = external_custody(repo, args.diagnostic_source)
    sys.path.insert(0, str(args.root/"tools"/"ambient"))
    import run_episodes as runner
    import analyze_episodes as analysis
    analysis.require(not args.output.exists(), "Preserve originals: output directory must be new")
    custody = runner.full_custody(args)
    args.output.mkdir(parents=True)
    runner.write(args.output/"custody.json", custody)
    runner.write(args.output/"external-custody.json", external)
    custody_sha = runner.sha(args.output/"custody.json")
    # Explicit external script selection only; no application file is changed.
    runner.SCRIPT = str(repo/INPUTS[0])
    registry, registry_receipt, registry_path = runner.run_process(
        args, "registry", "", args.output/"registration", custody_sha)
    runner.verify_committed(args.root, registry["source_identity"], APPLICATION)
    expected = runner.identity_key(registry["source_identity"])
    diagnostic_sha = external["sha256"][INPUTS[0]]
    analysis.require(registry["source_identity"]["external_diagnostic_sha256"] == diagnostic_sha,
                     "Loaded diagnostic differs from committed protocol")
    engine_sha = custody["engine"].get("gui_sha256", custody["engine"]["sha256"])
    analysis.require(expected["godot_executable_sha256"] == engine_sha, "Loaded engine differs from pin")
    for kind in ("cybersand_runtime", "rapier_runtime"):
        entry = custody["runtime"][kind]
        analysis.require(expected["runtime_sha256"][entry["path"].removeprefix("godot/")] == entry["sha256"],
                         "Loaded native/Rapier runtime differs from retained provenance")
    cases = registry["registration"]
    analysis.require(len(cases) == 6 and sum(c["actor_count"] for c in cases) == 6,
                     "Supplement must contain exactly six actual actors")
    shards, receipts = [], []
    for item in cases:
        analysis.require(external_custody(repo, args.diagnostic_source) == external, "Diagnostic changed")
        runner.verify_committed(args.root, registry["source_identity"], APPLICATION)
        report, receipt, report_path = runner.run_process(
            args, "full", item["id"], args.output/"shards"/item["id"], custody_sha)
        analysis.require(runner.identity_key(report["source_identity"]) == expected and
                         report["source_identity"]["external_diagnostic_sha256"] == diagnostic_sha,
                         "Physical source/runtime/diagnostic changed")
        analysis.require(report["registration"] == [item], "Wrong executed supplementary case")
        analysis.validate(report, source_root=args.root)
        shards.append(report)
        receipts.append({"case_id": item["id"], "report": str(report_path.relative_to(args.output)),
            "report_sha256": runner.sha(report_path),
            "execution_receipt": str(report_path.parent.joinpath("execution.json").relative_to(args.output)),
            "execution_receipt_sha256": runner.sha(report_path.parent/"execution.json"),
            "console": str(report_path.parent.joinpath("console.log").relative_to(args.output)),
            "console_sha256": receipt["console_sha256"], "reused": False})
        combined = runner.aggregate(registry, shards, receipts)
        combined["mode"] = "shard"
        combined["qualifies_primary_programme"] = False
        combined["supplementary_scope"] = "Six preregistered curiosity-only physical episodes; excluded from primary194."
        analysis.validate(combined, allow_partial=True, source_root=args.root)
        runner.write(args.output/"episodes.json", combined)
        print("AMBIENT2_CURIOSITY_PROGRESS "+str(len(shards))+"/6 "+item["id"], flush=True)
    analysis.require(runner.full_custody(args) == custody, "Frozen application custody changed during experiment")
    analysis.require(external_custody(repo, args.diagnostic_source) == external, "External input changed")
    analysis.validate(combined, source_root=args.root)
    result = compare(combined, analysis)
    result.update(schema="ambient2-curiosity-contrast/v1", source_revision=APPLICATION,
        source_tree=custody["source"]["source_tree"], external_custody=external,
        custody_sha256=custody_sha, report_sha256=runner.sha(args.output/"episodes.json"),
        registration_sha256=runner.sha(registry_path), registration_receipt=registry_receipt,
        actual_supplementary_episodes=6, complete=True, qualifies_primary_programme=False)
    runner.write(args.output/"comparison.json", result)
    print("AMBIENT2_CURIOSITY "+json.dumps({"complete": True, "episodes": 6,
        "supporting_pairs": result["supporting_pairs"], "report": str(args.output/"comparison.json")}), flush=True)


if __name__ == "__main__":
    main()
