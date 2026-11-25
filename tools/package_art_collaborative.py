#!/usr/bin/env python3
"""Package the collaborative Art successor using the qualified Art custody recipe.

The predecessor manifest/launcher/native-runtime/import gates remain in force.
This wrapper requires fresh headless and displayed collaborative receipts at
the exact package source. It never reuses the predecessor application verdict.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
import zipfile

import package_art_workbench_final as retained

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/ci"))
from run_art_collaborative_gates import TESTS, parse_case_output, validate_receipt

PROGRAMME = "ART-WORKBENCH-COLLABORATIVE-002"
GUIDE = "docs/operations/art-workbench-collaborative-evaluation.md"
QUALIFICATION_DIR = "qualification"
PACKAGED_TOOLS = ("tools/package_art_collaborative.py", "tools/ci/run_art_collaborative_gates.py")


def receipt(path: Path, commit: str, tree: str, graphical: bool, check_logs: bool = True) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    validate_receipt(value, commit=commit, tree=tree, platform_name="windows", graphical=graphical)
    if check_logs:
        for case in value["cases"]:
            log = path.parent / case["name"] / "process.log"
            if not log.is_file() or retained.sha(log) != case["log_sha256"]:
                raise ValueError("Complete original case log is missing or changed: " + case["name"])
            original = parse_case_output(log.read_text(encoding="utf-8", errors="replace"), TESTS[case["name"]])
            if original != case["result"]:
                raise ValueError("Original case result differs from qualification receipt: " + case["name"])
    if graphical:
        ui = next(case for case in value["cases"] if case["name"] == "test_art_collaboration_workspace")
        if ui["result"].get("display") in (None, "", "headless"):
            raise ValueError("Displayed collaborative UI did not identify a real display backend")
    return value


def validate_pair(headless: dict, displayed: dict) -> None:
    if headless["runtime"] != displayed["runtime"]:
        raise ValueError("Headless and displayed qualification used different runtime payloads")


def build(args: argparse.Namespace) -> dict:
    source, tree = retained.git("rev-parse", "HEAD"), retained.git("rev-parse", "HEAD^{tree}")
    if args.qualification_source is None:
        raise ValueError("Fresh source qualification decision is required")
    proof = retained.qualification_source(args.qualification_source, source, tree)
    if proof is None or proof.get("mode") != "full_required" or proof.get("reuse") is not False:
        raise ValueError("Collaborative application changes require fresh full qualification")
    headless = receipt(args.headless_receipt, source, tree, False)
    displayed = receipt(args.displayed_receipt, source, tree, True)
    validate_pair(headless, displayed)
    old_guide = retained.GUIDE
    retained.GUIDE = GUIDE
    try:
        identity = retained.build(args)
    finally:
        retained.GUIDE = old_guide
    output = args.output.resolve()
    # Include the exact committed successor recipe and its evidence validator.
    for relative in PACKAGED_TOOLS:
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(__import__("subprocess").check_output(
            ["git", "show", "HEAD:" + relative], cwd=ROOT, timeout=60))
    qualification_dir = output / QUALIFICATION_DIR
    qualification_dir.mkdir()
    for name, value in (("collaborative-headless.json", headless), ("collaborative-displayed.json", displayed)):
        (qualification_dir / name).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    native_paths = [retained.NATIVE, retained.retained.RAPIER]
    for relative in native_paths:
        if headless["runtime"]["payloads"].get(relative) != retained.sha(output / relative):
            raise ValueError("Qualified native/Rapier payload differs from the delivered payload: " + relative)
    if headless["runtime"].get("provenance_sha256") != retained.sha(output / "godot/addons/cybersand_native/runtime-provenance.json"):
        raise ValueError("Qualified native provenance differs from the delivered source record")
    console = output / "Godot_v4.7-stable_win64_console.exe"
    if headless["runtime"]["godot_sha256"] != retained.sha(console):
        raise ValueError("Qualified Godot differs from delivered console engine")
    identity.update(programme=PROGRAMME,
        collaborative_qualification={
            "kind": "fresh source-exact deterministic fixture application",
            "source_commit": source, "source_tree": tree, "model_calls": 0,
            "headless": QUALIFICATION_DIR + "/collaborative-headless.json",
            "displayed": QUALIFICATION_DIR + "/collaborative-displayed.json",
            "required_cases": sorted(TESTS), "predecessor_matrix": "separately required workflow stage",
            "physical_owner_acceptance": "pending",
        },
        principal_guide=GUIDE,
        automatic_model_requests=False,
        status="Draft/HOLD")
    identity["files_sha256"] = {
        path.relative_to(output).as_posix(): retained.sha(path)
        for path in sorted(output.rglob("*"))
        if path.is_file() and path.name != retained.MANIFEST
    }
    (output / retained.MANIFEST).write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    verify(output)
    return identity


def verify(output: Path) -> dict:
    identity = retained.verify(output)
    if identity.get("programme") != PROGRAMME or identity.get("status") != "Draft/HOLD":
        raise ValueError("This is not the collaborative Draft/HOLD evaluator")
    scope = identity.get("collaborative_qualification", {})
    if scope.get("source_commit") != identity["source_commit"] or scope.get("source_tree") != identity["source_tree"]:
        raise ValueError("Collaborative qualification is not source-bound")
    if scope.get("model_calls") != 0 or scope.get("required_cases") != sorted(TESTS):
        raise ValueError("Collaborative qualification scope differs")
    values = []
    for name, graphical in (("headless", False), ("displayed", True)):
        relative = QUALIFICATION_DIR + "/collaborative-" + name + ".json"
        if scope.get(name) != relative or relative not in identity["files_sha256"]:
            raise ValueError("Immutable qualification receipt is absent")
        values.append(receipt(output / relative, identity["source_commit"], identity["source_tree"],
                              graphical, check_logs=False))
    validate_pair(*values)
    for relative in (retained.NATIVE, retained.retained.RAPIER):
        if values[0]["runtime"]["payloads"].get(relative) != retained.sha(output / relative):
            raise ValueError("Delivered runtime differs from application qualification")
    if values[0]["runtime"].get("provenance_sha256") != retained.sha(output / "godot/addons/cybersand_native/runtime-provenance.json"):
        raise ValueError("Delivered native provenance differs from application qualification")
    if values[0]["runtime"]["godot_sha256"] != retained.sha(output / "Godot_v4.7-stable_win64_console.exe"):
        raise ValueError("Delivered Godot differs from application qualification")
    return identity


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build", "verify", "smoke", "zip"])
    parser.add_argument("--engine", type=Path)
    parser.add_argument("--engine-notices", type=Path)
    parser.add_argument("--vc-runtime", type=Path)
    parser.add_argument("--qualification-source", type=Path)
    parser.add_argument("--headless-receipt", type=Path)
    parser.add_argument("--displayed-receipt", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--evidence", type=Path)
    args = parser.parse_args()
    if args.command == "build":
        if not all((args.engine, args.engine_notices, args.vc_runtime, args.qualification_source,
                    args.headless_receipt, args.displayed_receipt)):
            parser.error("build requires engine, notices, VC runtime, source decision and both fresh application receipts")
        build(args)
    elif args.command == "smoke":
        if args.evidence is None:
            parser.error("smoke requires evidence")
        verify(args.output)
        retained.smoke(args)
        verify(args.output)
    elif args.command == "zip":
        identity = verify(args.output)
        destination = args.output.with_suffix(".zip")
        with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for relative in sorted([*identity["files_sha256"], retained.MANIFEST]):
                archive.write(args.output / relative, args.output.name + "/" + relative)
        destination.with_suffix(".zip.sha256").write_text(retained.sha(destination) + "  " + destination.name + "\n")
    else:
        verify(args.output)
    print(json.dumps({"status": "passed", "programme": PROGRAMME, "command": args.command, "output": str(args.output)}))


if __name__ == "__main__":
    main()
