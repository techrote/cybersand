#!/usr/bin/env python3
"""Bounded real Workbench regressions for accepted Paint, Water, Art and actors.

This supplements, and never replaces, the unchanged full native/GDExtension
admission workflows. Each source/extracted layout runs its own target runtime.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys

import runtime_custody as custody
from shared import legacy, package_identity, verify_engine, verify_project

sys.path.insert(0, str(custody.ROOT / "tools/ci"))
from run_workbench_qualification import Runner, completion
from run_flatten_qualification import direct_engine

REQUIRED = (
    "import", "workbench-canvas", "workbench-wave", "paint-workbench-author", "paint-workbench-reopen",
    "paint-generated-author", "paint-generated-reopen", "art-provider", "art-receipt-identity",
    "art-durability", "art-native-render", "art-undo", "actors-session", "actors-native",
    "actors-author", "actors-reopen", "flatten-512x1",
)


def json_marker(text: str, marker: str) -> dict:
    rows = [json.loads(line.removeprefix(marker + " ")) for line in text.splitlines() if line.startswith(marker + " ")]
    custody.require(len(rows) == 1 and isinstance(rows[0], dict), "Missing/duplicate completion: " + marker)
    return rows[0]


def wave_result(text: str, platform: str) -> dict:
    row = json_marker(text, "WORKBENCH_WAVE_RESULT")
    custody.require(row.get("schema") == "workbench-wave-631-v1" and row.get("failures") == 0
                    and legacy.positive_integer(row.get("assertions")) and row.get("real_workbench") is True
                    and legacy.positive_integer(row.get("native_ticks")), "Water fixture did not complete native Workbench progression")
    custody.require(row.get("platform") == {"linux": "Linux", "windows": "Windows"}[platform]
                    and row.get("godot") == "4.7-stable (official)", "Water fixture target/engine changed")
    custody.require(isinstance(row.get("sections"), dict) and bool(row["sections"])
                    and all(value is True for value in row["sections"].values()), "Water fixture skipped a required section")
    return row


def art_session_history_result(text: str) -> dict:
    """Require accepted #727's session-only receipt, never retired restoration evidence."""
    row = json_marker(text, "ART_HISTORY_SESSION_RESULT")
    custody.require(set(row) == {"checks", "failures", "scope"}
                    and type(row.get("checks")) is int and row["checks"] >= 10
                    and row.get("failures") == [] and row.get("scope") == "session-only",
                    "Art history did not complete the accepted session-only audit")
    return row


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--package", type=Path)
    args = parser.parse_args()
    runtime, project, evidence = (p.resolve() for p in (args.runtime, args.project, args.evidence))
    custody.require(not evidence.exists() or not any(evidence.iterdir()), "Regression evidence must be new")
    receipt = custody.verify(runtime)
    platform = "windows" if os.name == "nt" else "linux"
    custody.require(receipt["platform"] == platform, "Regressions must execute on their target OS")
    verify_project(project, receipt)
    verify_engine(args.godot.resolve())
    if args.package:
        package_identity(args.package.resolve(), receipt)
        custody.require(project == args.package.resolve() / "godot" and args.godot.resolve().parent == args.package.resolve(),
                        "Installed regression must run the extracted evaluator's own engine and project")
    runner = Runner(args)
    runner.env.update(CYBERSAND_SOURCE_REVISION=receipt["source_commit"])
    for key in ("FLATTEN_REOPEN", "FLATTEN_OWNER_FAILURE_REOPEN", "CYBERSAND_ACTOR_COMPOSITION_REOPEN",
                "CYBERSAND_SWARM004_CLI", "CYBERSAND_SWARM004_SOURCE", "CYBERSAND_SWARM004_SHA256"):
        runner.env.pop(key, None)
    identity = {"schema": 1, "programme": custody.PROGRAMME, "source_commit": receipt["source_commit"],
                "source_tree": receipt["source_tree"], "platform": platform, "package": bool(args.package),
                "runtime_manifest_sha256": custody.sha(runtime / custody.NAME), "build_context": receipt["build_context"],
                "godot_sha256": custody.sha(args.godot),
                "godot_engine_sha256": custody.sha(direct_engine(args.godot.resolve(), sys.platform)),
                "required_cases": list(REQUIRED), "passed": False,
                "scope": "Bounded accepted-main smoke; unchanged complete admission workflows remain mandatory"}
    try:
        runner.godot(project, "import")
        text = runner.godot(project, "workbench-canvas", "test_workbench_canvas", "WORKBENCH_CANVAS")
        custody.require("skipped" not in text.lower(), "Fresh canvas fixture unexpectedly preserved an existing user map")
        text = runner.godot(project, "workbench-wave", "test_workbench_wave", graphical=True, max_fps=60)
        runner.results[-1]["completion"] = wave_result(text, platform)
        for family, script, marker, flag in (
                ("workbench", "test_paint_editor_workbench", "PAINT_EDITOR_WORKBENCH", "PAINT_REOPEN"),
                ("generated", "test_paint_editor_generated_workbench", "PAINT_EDITOR_GENERATED_WORKBENCH", "PAINT_GENERATED_REOPEN")):
            for phase in ("author", "reopen"):
                value = "1" if phase == "reopen" else "0"
                text = runner.godot(project, "paint-" + family + "-" + phase, script, marker, graphical=True,
                                    env={flag: value, "PAINT_CAPTURE_DIR": str(evidence / ("paint-" + family + "-frames"))})
                row = completion(text, marker)
                custody.require(row.get("reopen") == value and (family != "generated" or row.get("completed") is True),
                                "Paint author/reopen did not complete its requested phase")
        for label, script, marker in (
                ("art-provider", "test_art_provider", "ART_PROVIDER_KEYLESS"),
                ("art-receipt-identity", "test_art_history_receipt_identity", "ART_HISTORY_RECEIPT_IDENTITY_RESULT"),
                ("art-durability", "test_art_history_durability", "ART_HISTORY_SESSION_RESULT"),
                ("art-native-render", "test_art_batch_native_render", "ART_STAGE1_RESULT"),
                ("art-undo", "test_art_undo", "ART_UNDO_RESULT"),
                ("actors-session", "test_workbench_actor_composition_session", "Workbench actor composition session:"),
                ("actors-native", "test_workbench_actor_composition_native", "Workbench actor composition native:")):
            text = runner.godot(project, label, script, marker, graphical=label == "art-native-render")
            if label == "art-durability":
                runner.results[-1]["completion"] = art_session_history_result(text)
        for phase in ("author", "reopen"):
            frames = evidence / ("actors-" + phase + "-frames")
            text = runner.godot(project, "actors-" + phase, "test_workbench_actor_composition", "WB_ACTOR_COMPOSE",
                                graphical=True, max_fps=60, env={
                                    "CYBERSAND_ACTOR_COMPOSITION_REOPEN": "1" if phase == "reopen" else "0",
                                    "CYBERSAND_ACTOR_COMPOSITION_CAPTURE": str(frames),
                                    "CYBERSAND_ACTOR_COMPOSITION_REPORT": str(evidence / ("actors-" + phase + ".json"))})
            row = completion(text, "WB_ACTOR_COMPOSE")
            custody.require(row.get("headless") is False and "SKIP WB_ACTOR_COMPOSE" not in text
                            and row.get("preservation_notes") == [] and bool(row.get("screenshots")),
                            "Actor composition did not complete a fresh graphical transaction")
            for shot in row["screenshots"]:
                custody.require(legacy.original_png(Path(shot["path"])), "Actor framebuffer evidence is missing")
        command = [sys.executable, str(custody.ROOT / "tools/ci/run_flatten_qualification.py"),
                   "--godot", str(args.godot.resolve()), "--project", str(project), "--cases", "512x1",
                   "--evidence", str(evidence / "flatten")]
        if args.package:
            command += ["--package", str(args.package.resolve())]
        runner.execute("flatten-512x1", command, timeout=1200)
        flattened = legacy.read_report(evidence / "flatten/qualification.json")
        custody.require(flattened.get("status") == "passed" and flattened.get("graphical") is True
                        and flattened.get("cases") == [[512, 1]], "Flatten did not complete its bounded graphical and recovery scope")
        custody.require([row["label"] for row in runner.results] == list(REQUIRED)
                        and all(row["status"] == "passed" for row in runner.results), "Accepted-main regression scope is incomplete")
        custody.require(custody.verify(runtime) == receipt, "Runtime changed during regressions")
        verify_project(project, receipt)
        identity["passed"] = True
    finally:
        custody.write_json(evidence / "results.json", runner.results)
        identity.update(results=runner.results, files_sha256=custody.inventory(evidence))
        custody.write_json(evidence / "accepted-main-smokes.json", identity)


if __name__ == "__main__":
    main()
