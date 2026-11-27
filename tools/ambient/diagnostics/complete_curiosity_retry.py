#!/usr/bin/env python3
"""Resume only the registered case lacking a report after external SIGKILL.

This recovery does not change the preregistered input files, profile or endpoints.
It validates and copies every original attempt and requires exactly five valid
completed shards and one recorded startup SIGKILL before executing the sixth.
"""
from copy import deepcopy
import argparse
import json
from pathlib import Path
import shutil
import sys

import run_curiosity_contrast as protocol


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--original", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.root = args.root.resolve(); args.original = args.original.resolve()
    args.output = args.output.resolve(); args.godot = args.godot.resolve()
    args.source_sha = protocol.APPLICATION; args.case_timeout = 1800
    sys.path.insert(0, str(args.root/"tools"/"ambient"))
    import run_episodes as runner
    import analyze_episodes as analysis
    repo = Path(__file__).resolve().parents[3]
    external = protocol.external_custody(repo, "31f8ecf8b6d8821740b545e046501f90c86e06f3")
    custody = runner.full_custody(args)
    analysis.require(custody == json.loads((args.original/"custody.json").read_text()), "Original application custody changed")
    analysis.require(external == json.loads((args.original/"external-custody.json").read_text()), "Original protocol changed")
    analysis.require(not args.output.exists(), "Keep every failed attempt; output must be new")
    # Preserve every original byte, including the failed sixth process.
    shutil.copytree(args.original, args.output/"original")
    original = args.output/"original"
    registry = json.loads((original/"registration/report.json").read_text())
    runner.check_terminal(original/"registration/console.log", registry,
        json.loads((original/"registration/execution.json").read_text()), "", args.source_sha, "registry")
    combined_before = json.loads((original/"episodes.json").read_text())
    analysis.validate(combined_before, allow_partial=True, source_root=args.root)
    analysis.require(combined_before["completed_campaigns"] == 5 and not combined_before["complete"],
                     "Recovery is limited to the one missing preregistered case")
    expected = runner.identity_key(registry["source_identity"])
    shards, receipts = [], []
    for saved in combined_before["shard_receipts"]:
        paths = {key: original/saved[key] for key in ("report", "execution_receipt", "console")}
        analysis.require(all(path.resolve().is_relative_to(original) for path in paths.values()), "Original path escapes archive")
        for key, path in paths.items():
            analysis.require(runner.sha(path) == saved[key+"_sha256"], "Original evidence changed: "+key)
        report = json.loads(paths["report"].read_text())
        receipt = json.loads(paths["execution_receipt"].read_text())
        analysis.require(receipt["custody_sha256"] == runner.sha(original/"custody.json") and
                         receipt["console_sha256"] == saved["console_sha256"] and
                         receipt["report_sha256"] == saved["report_sha256"], "Original custody chain differs")
        runner.check_terminal(paths["console"], report, receipt, saved["case_id"], args.source_sha, "full")
        analysis.validate(report, source_root=args.root)
        analysis.require(runner.identity_key(report["source_identity"]) == expected, "Original source/runtime differs")
        analysis.require(report["source_identity"]["external_diagnostic_sha256"] == external["sha256"][protocol.INPUTS[0]],
                         "Original external diagnostic differs")
        shards.append(report)
        retained = deepcopy(saved)
        for key in paths: retained[key] = "original/"+saved[key]
        receipts.append(retained)
    completed = {item["case_id"] for item in receipts}
    missing = [case for case in registry["registration"] if case["id"] not in completed]
    analysis.require(len(missing) == 1 and missing[0]["seed"] == 2909 and missing[0]["arm"] == "high_curiosity",
                     "Only the killed sixth case may be retried")
    item = missing[0]
    failed = original/"shards"/item["id"]
    failure = json.loads((failed/"execution.json").read_text())
    analysis.require(failure["returncode"] == -9 and not (failed/"report.json").exists() and
                     failure["console_sha256"] == runner.sha(failed/"console.log") and
                     failure["custody_sha256"] == runner.sha(original/"custody.json") and
                     failure["source_revision"] == args.source_sha,
                     "Retain and identify the actual external-kill attempt")
    runner.write(args.output/"custody.json", custody)
    runner.write(args.output/"external-custody.json", external)
    runner.SCRIPT = str(repo/protocol.INPUTS[0])
    report, receipt, report_path = runner.run_process(args, "full", item["id"],
        args.output/"retry"/item["id"], runner.sha(args.output/"custody.json"))
    analysis.require(runner.identity_key(report["source_identity"]) == expected and report["registration"] == [item],
                     "Retry source, runtime or authored case differs")
    analysis.require(report["source_identity"]["external_diagnostic_sha256"] == external["sha256"][protocol.INPUTS[0]],
                     "Retry diagnostic differs")
    runner.verify_committed(args.root, report["source_identity"], args.source_sha)
    analysis.validate(report, source_root=args.root)
    shards.append(report)
    receipts.append({"case_id": item["id"], "report": str(report_path.relative_to(args.output)),
        "report_sha256": runner.sha(report_path),
        "execution_receipt": str(report_path.parent.joinpath("execution.json").relative_to(args.output)),
        "execution_receipt_sha256": runner.sha(report_path.parent/"execution.json"),
        "console": str(report_path.parent.joinpath("console.log").relative_to(args.output)),
        "console_sha256": receipt["console_sha256"], "reused": False})
    combined = runner.aggregate(registry, shards, receipts)
    combined.update(mode="shard", qualifies_primary_programme=False,
        supplementary_scope="Six completed preregistered curiosity conditions; one separately retained incomplete SIGKILL attempt.")
    analysis.validate(combined, source_root=args.root)
    analysis.require(runner.full_custody(args) == custody, "Application custody changed")
    analysis.require(protocol.external_custody(repo, external["source_commit"]) == external, "Preregistered input changed")
    runner.write(args.output/"episodes.json", combined)
    result = protocol.compare(combined, analysis)
    result.update(schema="ambient2-curiosity-contrast/v1", source_revision=args.source_sha,
        source_tree=custody["source"]["source_tree"], external_custody=external,
        custody_sha256=runner.sha(args.output/"custody.json"), report_sha256=runner.sha(args.output/"episodes.json"),
        registration_sha256=runner.sha(original/"registration/report.json"),
        actual_supplementary_episodes=6, complete=True, qualifies_primary_programme=False,
        incomplete_attempt={"case_id": item["id"], "returncode": -9,
            "original_execution_receipt_sha256": runner.sha(failed/"execution.json"),
            "progress": "No report or completion marker; actual physical progress is unestablished."},
        recovery_script_sha256=runner.sha(__file__))
    runner.write(args.output/"comparison.json", result)
    print("AMBIENT2_CURIOSITY "+json.dumps({"complete": True, "episodes": 6,
        "incomplete_attempts_retained": 1, "supporting_pairs": result["supporting_pairs"],
        "report": str(args.output/"comparison.json")}), flush=True)


if __name__ == "__main__":
    main()
