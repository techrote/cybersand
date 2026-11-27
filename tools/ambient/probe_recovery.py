#!/usr/bin/env python3
"""Source-bound, selected physical reruns of the retained avoidance failure.

This executes ordinary registered Worlds through the full programme's existing
runner. It never qualifies the complete 194-episode programme. Comparison uses
original baseline shards and excludes elapsed performance under local contention.
"""
from __future__ import annotations
import argparse
from copy import deepcopy
import json
from pathlib import Path
import subprocess
import sys
import run_episodes as runner
import analyze_episodes as analysis

SCHEMA = "ambient2-recovery-probe/v1"
ALLOWED_CHANGED_SOURCE = "scripts/ambient/ambient_stateful_modules.gd"
ALLOWED_PROJECT_CHANGES = {ALLOWED_CHANGED_SOURCE, "tests/test_ambient_living_engine.gd"}


def select_cases(registration, requested=()):
    by_id = {item["id"]: item for item in registration}
    analysis.require(len(by_id) == len(registration), "Duplicate registered campaign")
    if requested:
        analysis.require(len(set(requested)) == len(requested), "Duplicate requested case")
        analysis.require(set(requested) <= set(by_id), "Requested case absent from complete registry")
        return [item for item in registration if item["id"] in requested]
    selected = [item for item in registration if item["seed"] in {605, 1701} and (
        (item["group"] == "main" and item["model"] in {"runner", "monowheel"}
         and item["arm"] == "stateful") or
        (item["group"] == "main" and item["model"] == "4ly_trainer" and item["seed"] == 1701
         and item["arm"] == "stateful") or
        (item["group"] == "adverse" and item["layout"] in {"sealed_goal", "blocked_route"}
         and item["arm"] == "stateful"))]
    analysis.require(len(selected) == 9, "Recovery preset must contain five main and four adverse Worlds")
    return selected


def direction_readback(row, begin=0.0, end=30.0):
    """Count final requested heading changes, never label changes or new goals."""
    trace = [s for s in row["trace"] if begin-1e-8 <= s["seconds"] <= end+1e-8]
    analysis.require(bool(trace), "Empty direction readback interval")
    signs = [0 if not s["has_procedural_intent"] or s["intent_pace"] <= .05 else
             1 if s["intent_direction"][0] > .05 else -1
             if s["intent_direction"][0] < -.05 else 0 for s in trace]
    xs = [s["position"][0] for s in trace]
    return {"samples": len(trace), "begin_seconds": trace[0]["seconds"],
            "end_seconds": trace[-1]["seconds"],
            "horizontal_heading_reversals": sum(a*b == -1 for a, b in zip(signs, signs[1:])),
            "x_range_cells": max(xs)-min(xs), "net_x_cells": xs[-1]-xs[0]}


def comparison_sources(old, new):
    for key in ("platform", "godot_executable_sha256", "runtime_sha256"):
        analysis.require(old[key] == new[key], "Comparison runtime differs: "+key)
    changed = sorted(name for name in old["sha256"] if old["sha256"][name] != new["sha256"][name])
    analysis.require(changed == [ALLOWED_CHANGED_SOURCE], "Unexpected physical input changes: "+str(changed))
    return changed


def comparison_projects(old, new):
    before, after = old["loaded_project_sha256"], new["loaded_project_sha256"]
    analysis.require(set(before) == set(after), "Loaded project inventory changed")
    changed = {path for path in before if before[path] != after[path]}
    analysis.require(changed == ALLOWED_PROJECT_CHANGES, "Unexpected complete project changes: "+str(sorted(changed)))
    return sorted(changed)


def baseline_proofs(baseline, baseline_path, selected, output, candidate_custody):
    """Check each original immutable shard, not just its aggregate's claims."""
    parent = baseline_path.resolve().parent
    receipts = {r["case_id"]: r for r in baseline["shard_receipts"]}
    analysis.require(len(receipts) == len(baseline["shard_receipts"]), "Duplicate baseline receipt")
    campaigns = {c["id"]: c for c in baseline["campaigns"]}
    expected_identity = runner.identity_key(baseline["source_identity"])
    custody_path = parent/"custody.json"
    custody_bytes = custody_path.read_bytes()
    custody = json.loads(custody_bytes)
    analysis.require(custody["source"]["source_commit"] == baseline["source_identity"]["source_revision"],
                     "Baseline full custody source differs")
    comparison_projects(custody, candidate_custody)
    (output/"baseline-custody.json").write_bytes(custody_bytes)
    proofs = []
    for item in selected:
        cid = item["id"]
        analysis.require(cid in receipts and cid in campaigns, "Completed original baseline missing: "+cid)
        saved = receipts[cid]
        paths = {}
        for key in ("report", "execution_receipt", "console"):
            path = (parent/saved[key]).resolve()
            analysis.require(path.is_relative_to(parent), "Baseline receipt path escapes evidence")
            analysis.require(runner.sha(path) == saved[key+"_sha256"], "Edited baseline original: "+key)
            paths[key] = path
        report = json.loads(paths["report"].read_text(encoding="utf-8"))
        receipt = json.loads(paths["execution_receipt"].read_text(encoding="utf-8"))
        analysis.require(receipt["custody_sha256"] == runner.sha(custody_path) and
                         receipt["report_sha256"] == saved["report_sha256"] and
                         receipt["console_sha256"] == saved["console_sha256"], "Baseline custody chain differs")
        runner.check_terminal(paths["console"], report, receipt, cid, baseline["source_identity"]["source_revision"], "full")
        analysis.validate(report)
        analysis.require(report["registration"] == [item] and report["campaigns"] == [campaigns[cid]],
                         "Baseline aggregate differs from original shard")
        analysis.require(runner.identity_key(report["source_identity"]) == expected_identity,
                         "Baseline shard identity differs")
        target = output/"baseline-shards"/cid
        target.mkdir(parents=True)
        for key, path in paths.items():
            (target/path.name).write_bytes(path.read_bytes())
        proofs.append({"case_id": cid, "original_hashes": saved,
                       "retained_directory": str(target.relative_to(output))})
    return proofs


def compare_reports(baseline, candidate):
    analysis.validate(baseline, allow_partial=True)
    analysis.validate(candidate)
    changed = comparison_sources(baseline["source_identity"], candidate["source_identity"])
    old_cases = {c["id"]: c for c in baseline["campaigns"]}
    pairs = []
    for case in candidate["campaigns"]:
        analysis.require(case["id"] in old_cases, "Completed baseline case missing: "+case["id"])
        before = old_cases[case["id"]]
        for key in ("initial_materials", "initial_pose_sha256", "geometry", "seed", "seconds", "actor_count"):
            analysis.require(before[key] == case[key], "Unmatched initial condition: "+key)
        old_rows = {r["actor_instance"]: r for r in before["episodes"]}
        for row in case["episodes"]:
            prior = old_rows[row["actor_instance"]]
            for key in ("model", "controller", "profile", "start"):
                analysis.require(prior[key] == row[key], "Unmatched actor input: "+key)
            metrics_before = analysis.episode_metrics(before, prior)
            metrics_after = analysis.episode_metrics(case, row)
            # These are physical/descriptive outcomes, not a universal pass gate.
            keys = ("x_range_cells", "net_displacement_cells", "stable_territory_cells",
                    "stalled_active_fraction", "horizontal_obstruction_intervals",
                    "eight_cell_recoveries_within_five_seconds", "intentions_seconds")
            pairs.append({"case_id": case["id"], "actor_instance": row["actor_instance"],
                "before": {k: metrics_before[k] for k in keys},
                "after": {k: metrics_after[k] for k in keys},
                "directions_before": direction_readback(prior, end=float(case["seconds"])),
                "directions_after": direction_readback(row, end=float(case["seconds"])),
                "original_negative_window_before": direction_readback(prior, 6.5, 8.5),
                "original_negative_window_after": direction_readback(row, 6.5, 8.5)})
    return {"changed_physical_source": changed, "pairs": pairs,
            "interpretation": "Matched original registered cases; new executions are not new independent case identities. "
                "Heading changes are final steering changes, not goal transitions. Recovery counts use the documented "
                "sampled wall-contact proxy and do not attest internal failure learning. Elapsed performance is excluded."}


def selected_report(registry, selected, shards, receipts):
    view = deepcopy(registry)
    view["registration"] = selected
    combined = runner.aggregate(view, shards, receipts)
    combined["mode"] = "shard"
    combined["complete_registration"] = registry["registration"]
    combined["selection_scope"] = "targeted recovery comparison; not the full registered programme"
    return combined


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--root", type=Path, default=runner.ROOT)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--case", action="append", default=[])
    parser.add_argument("--case-timeout", type=int, default=1800)
    args = parser.parse_args()
    args.root = args.root.resolve(); args.godot = args.godot.resolve(); args.output = args.output.resolve()
    args.source_sha = runner.head(args.root)
    analysis.require(args.case_timeout >= 120, "Watchdog must permit native physical execution")
    analysis.require(not args.output.exists(), "Preserve original attempts: choose a new output directory")
    baseline_bytes = args.baseline.read_bytes()
    baseline = json.loads(baseline_bytes)
    analysis.validate(baseline, allow_partial=True)
    custody = runner.full_custody(args)
    args.output.mkdir(parents=True)
    (args.output/"baseline-original.json").write_bytes(baseline_bytes)
    runner.write(args.output/"custody.json", custody)
    custody_sha = runner.sha(args.output/"custody.json")
    registry, registration_receipt, registry_path = runner.run_process(
        args, "registry", "", runner.next_attempt(args.output/"registration"), custody_sha)
    runner.verify_committed(args.root, registry["source_identity"], args.source_sha)
    engine_sha = custody["engine"].get("gui_sha256", custody["engine"]["sha256"])
    analysis.require(registry["source_identity"]["godot_executable_sha256"] == engine_sha,
                     "Observed engine differs from authenticated pin")
    for kind in ("cybersand_runtime", "rapier_runtime"):
        entry = custody["runtime"][kind]
        analysis.require(registry["source_identity"]["runtime_sha256"][entry["path"].removeprefix("godot/")] == entry["sha256"],
                         "Observed retained runtime differs from custody")
    analysis.require(len(registry["registration"]) == 122 and
                     sum(c["actor_count"] for c in registry["registration"]) == 194, "Full registry changed")
    selected = select_cases(registry["registration"], args.case)
    available = {c["id"] for c in baseline["campaigns"]}
    analysis.require(all(c["id"] in available for c in selected), "Baseline lacks selected completed cases")
    comparison_sources(baseline["source_identity"], registry["source_identity"])
    originals = baseline_proofs(baseline, args.baseline, selected, args.output, custody)
    expected = runner.identity_key(registry["source_identity"])
    receipts, shards = [], []
    for item in selected:
        runner.verify_committed(args.root, registry["source_identity"], args.source_sha)
        analysis.require(runner.qualification.engine_identity(args.godot) == custody["engine"], "Engine changed")
        report, receipt, report_path = runner.run_process(
            args, "full", item["id"], runner.next_attempt(args.output/"shards"/item["id"]), custody_sha)
        analysis.require(runner.identity_key(report["source_identity"]) == expected, "Shard source/runtime changed")
        analysis.require(report["registration"] == [item], "Executed case differs from registration")
        analysis.validate(report, source_root=args.root)
        shards.append(report)
        receipt_path = report_path.parent/"execution.json"
        receipts.append({"case_id": item["id"], "report": str(report_path.relative_to(args.output)),
            "report_sha256": runner.sha(report_path), "execution_receipt": str(receipt_path.relative_to(args.output)),
            "execution_receipt_sha256": runner.sha(receipt_path),
            "console": str(report_path.parent.joinpath("console.log").relative_to(args.output)),
            "console_sha256": receipt["console_sha256"], "elapsed_seconds": receipt["elapsed_seconds"], "reused": False})
        combined = selected_report(registry, selected, shards, receipts)
        analysis.validate(combined, allow_partial=True, source_root=args.root)
        runner.write(args.output/"episodes.json", combined)
        print("AMBIENT2_RECOVERY_PROGRESS "+str(len(shards))+"/"+str(len(selected))+" "+item["id"], flush=True)
    analysis.require(runner.full_custody(args) == custody, "Source/runtime changed during probe")
    analysis.validate(combined, source_root=args.root)
    result = compare_reports(baseline, combined)
    result.update(schema=SCHEMA, complete_selected=True, qualifies_full_programme=False,
                  source_revision=args.source_sha, baseline_source=baseline["source_identity"]["source_revision"],
                  source_tree=custody["source"]["source_tree"], baseline_sha256=runner.sha(args.output/"baseline-original.json"),
                  probe_sha256=runner.sha(__file__), custody_sha256=custody_sha,
                  verified_baseline_originals=originals,
                  changed_complete_project_inputs=sorted(ALLOWED_PROJECT_CHANGES),
                  registry_sha256=runner.sha(registry_path), registration_receipt=registration_receipt,
                  selected_case_ids=[c["id"] for c in selected], actual_actor_episodes=combined["completed_actor_episodes"],
                  report_sha256=runner.sha(args.output/"episodes.json"))
    runner.write(args.output/"comparison.json", result)
    print("AMBIENT2_RECOVERY_PROBE "+json.dumps({"source_revision": args.source_sha, "complete_selected": True,
          "qualifies_full_programme": False, "campaigns": len(selected),
          "episodes": combined["completed_actor_episodes"], "report": str(args.output/"comparison.json")}), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, RuntimeError, subprocess.CalledProcessError) as error:
        print("AMBIENT2_RECOVERY_REFUSED: "+str(error), file=sys.stderr)
        raise SystemExit(1)
