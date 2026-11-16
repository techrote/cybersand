#!/usr/bin/env python3
"""Focused production regressions under both publication policies."""
from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path
import sys

from run_campaign import (ROOT, child_environment, engine_identity, execute,
                          retained_runtime_identity, sha, source_identity, verify_runtime_result, write)


CASES = [
    ("queued-history", "test_render_upload_577_queued_history.gd", "RENDER_UPLOAD_577_QUEUED_HISTORY ", {}, "queued-history"),
    ("main-refusal", "test_render_upload_577_refusal.gd", "RENDER_UPLOAD_577_REFUSAL ", {}, "main-refusal"),
    ("ack-graphical", "test_render_upload_577_ack_graphical.gd", "RENDER_UPLOAD_577_ACK ", {}, "ack-graphical"),
    ("pending-compaction", "test_render_pending_compaction.gd", "RENDER_PENDING_COMPACTION:", {}, "pending-compaction"),
    ("handoff", "test_render_patch_handoff_regression.gd", "Render patch handoff regression passed", {}, "handoff"),
    ("generation", "test_render_world_generation.gd", "RENDER_WORLD_GENERATION:", {}, "generation"),
    ("physics", "test_workbench_physics_play.gd", "WORKBENCH_PHYSICS", {}, "physics"),
    ("paint", "test_paint_editor_workbench.gd", "PAINT_EDITOR_WORKBENCH", {}, "paint"),
    ("paint-reopen", "test_paint_editor_workbench.gd", "PAINT_EDITOR_WORKBENCH", {"PAINT_REOPEN": "1"}, "paint"),
    ("flatten", "test_workbench_flatten.gd", "FLATTEN_RESULT", {"FLATTEN_SIDE": "512", "FLATTEN_REQUIRE_GRAPHICS": "1"}, "flatten"),
    ("flatten-reopen", "test_workbench_flatten.gd", "FLATTEN_RESULT", {"FLATTEN_SIDE": "512", "FLATTEN_REQUIRE_GRAPHICS": "1", "FLATTEN_REOPEN": "1"}, "flatten"),
    ("architecture", "test_architectural_generator.gd", "ARCHITECTURE_RESULTS", {"CYBERSAND_ARCHITECTURE_PHASE": "author"}, "architecture"),
    ("architecture-reopen", "test_architectural_generator.gd", "ARCHITECTURE_RESULTS", {"CYBERSAND_ARCHITECTURE_PHASE": "reopen"}, "architecture"),
    ("combined-authoring", "test_workbench_combined_authoring.gd", "WB_COMBINED_EVIDENCE", {"WB_COMBINED_REQUIRE_GRAPHICS": "1", "WB_COMBINED_WORKERS": "1", "WB_COMBINED_SIDE": "512"}, "combined"),
    ("combined-reopen", "test_workbench_combined_authoring.gd", "WB_COMBINED_EVIDENCE", {"WB_COMBINED_REOPEN": "1", "WB_COMBINED_REQUIRE_GRAPHICS": "1", "WB_COMBINED_WORKERS": "1", "WB_COMBINED_SIDE": "512"}, "combined"),
    ("vapour", "test_material_vapour_pipeline_render.gd", "MATERIAL_VAPOUR", {}, "vapour"),
    ("palette", "test_palette_crossfade_render.gd", "PALETTE_CROSSFADE_RENDER_RESULT", {}, "palette"),
]

# Independent source fixture: channels 1/2, 2x2 patches except the complete
# 512-square packet at serial 12. Never derive allowed errors from a receipt.
REFUSAL_ERRORS = tuple(
    f"ERROR: Rejected render snapshot {serial} (6 metadata integers, {cells * channels} payload bytes): {reason}; requesting full refresh"
    for channels in (1, 2)
    for serial, cells, reason in (
        (10, 4, "material upload World generation is stale"),
        (11, 4, "hybrid fallback is waiting for a complete native refresh"),
        (12, 512 * 512, "hybrid fallback refuses stale publication identity"),
        (13, 4, "hybrid fallback is waiting for a complete native refresh"),
    )
)


def verify_independent_result(name: str, script: str, data: dict) -> None:
    paths = {"res://scripts/material_upload_hybrid.gd", "res://shaders/material_upload_copy.gdshader",
             "res://tests/" + script}
    if name == "main-refusal":
        paths.update({"res://scripts/main.gd", "res://scripts/simulation_worker.gd"})
    expected_sources = {p: sha(ROOT / p.replace("res://", "godot/")) for p in paths}
    if data.get("source_files_sha256") != expected_sources:
        raise ValueError("Independent fixture original source bindings differ")
    if name == "queued-history":
        if (data.get("schema") != "render-upload-577-independent-queued-history-v1"
                or data.get("checks") != 4084 or data.get("seed") != 57720261116
                or data.get("dimensions") != [513, 513]
                or set(data.get("modes", {})) != {"compact_full", "partial_blit", "transition_seed"}
                or sum(data["modes"].values()) != 1280):
            raise ValueError("Queued GPU history corpus is incomplete or changed")
    elif name == "main-refusal":
        expected_cases = [{"accepted": 11, "ack": 15, "channels": c, "final_mode": "full_update",
                           "final_serial": 15, "refused": 4} for c in (1, 2)]
        if (data.get("schema") != "render-upload-577-independent-main-refusal-v1"
                or data.get("checks") != 166 or data.get("cases") != expected_cases
                or data.get("expected_error_messages") != [e.removeprefix("ERROR: ") for e in REFUSAL_ERRORS]):
            raise ValueError("Main refusal/recovery corpus or intentional diagnostics differ")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--source-sha")
    parser.add_argument("--allow-dirty", action="store_true")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--cases", default="all")
    parser.add_argument("--strategies", default="full,hybrid")
    parser.add_argument("--rendering-driver", default="opengl3_angle" if os.name == "nt" else "opengl3")
    parser.add_argument("--timeout", type=float, default=1200)
    args = parser.parse_args()
    if args.allow_dirty and (args.source_sha or os.environ.get("GITHUB_ACTIONS") == "true"):
        parser.error("Local-delta checks cannot claim exact source")
    strategies = args.strategies.split(",")
    if not strategies or any(s not in {"full", "hybrid"} for s in strategies):
        parser.error("Unknown strategy")
    wanted = set(args.cases.split(","))
    cases = [case for case in CASES if args.cases == "all" or case[0] in wanted]
    if not cases or (args.cases != "all" and wanted != {case[0] for case in cases}):
        parser.error("Unknown case")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = source_identity(args.source_sha, args.allow_dirty)
    runtime = retained_runtime_identity()
    engine = engine_identity(args.godot)
    report = {"schema": "render-upload-577-regressions-v1", "complete": False,
              "source": source, "runtime": runtime, "engine": engine, "cases": []}
    env = child_environment(output.parent / (output.name + "-userdata"), "import", source["commit"])
    basic = [engine["launcher"]["path"], "--audio-driver", "Dummy", "--path", str(ROOT / "godot")]
    execute([*basic, "--headless", "--editor", "--import", "--quit"], env, output / "import", args.timeout)
    failures = []
    for strategy in strategies:
        for name, script, marker, additions, profile in cases:
            internal_pair = name == "ack-graphical"
            independent = name in {"queued-history", "main-refusal"}
            mounted = name not in {"handoff", "generation", "palette", "vapour", "pending-compaction", "ack-graphical", "queued-history", "main-refusal"}
            if strategy == "hybrid" and not mounted:
                continue
            label = ("independent" if independent else "paired" if internal_pair else strategy) + "-" + name
            env = child_environment(output.parent / (output.name + "-userdata"), strategy + "-" + profile, source["commit"])
            env.update(additions)
            env["CYBERSAND_ARCHITECTURE_OUTPUT"] = str(output / label / "architecture")
            env["FLATTEN_SCREENSHOTS"] = str(output / label / "flatten-captures")
            env["CYBERSAND_TEST_ARTIFACT_DIR"] = str(output / label / "captures")
            row = {"label": label, "strategy": "internal hybrid R8/RG8 corpus" if independent else "internal full/hybrid pair" if internal_pair else strategy,
                   "script": script, "passed": False,
                   "scope": "independent GPU history/refusal correctness" if independent else
                            "native/Main/GPU readback-serialized ACK correctness" if internal_pair else
                            "mounted real Workbench" if mounted else "existing isolated ownership/shader control"}
            print("RENDER_UPLOAD_577_REGRESSION_START", label, flush=True)
            try:
                process = execute([*basic, "--rendering-method", "gl_compatibility", "--rendering-driver",
                                   args.rendering_driver, "--script", "res://tests/" + script,
                                   "--", "--render-upload=" + strategy,
                                   "--output=" + str(output / label / "runtime.json")], env, output / label, args.timeout,
                                   expected_error_lines=REFUSAL_ERRORS if name == "main-refusal" else ())
                text = (output / label / "process.log").read_text(encoding="utf-8", errors="replace")
                if marker not in text:
                    raise ValueError("Required completion marker missing: " + marker)
                if independent:
                    data = json.loads((output / label / "runtime.json").read_text(encoding="utf-8"))
                    row["graphics"] = verify_runtime_result(data, engine, source, process=process,
                        rendering_driver=args.rendering_driver, config=None, frames=None, strategy=None,
                        fixture_sha256=sha(ROOT / "godot/tests" / script))
                    verify_independent_result(name, script, data)
                if internal_pair:
                    data = json.loads((output / label / "runtime.json").read_text(encoding="utf-8"))
                    row["graphics"] = verify_runtime_result(data, engine, source, process=process,
                        rendering_driver=args.rendering_driver, config=None, frames=None, strategy=None)
                    expected = {(s, a) for s in ("full", "hybrid") for a in ("normal", "delayed", "missing")}
                    if ({(c["strategy"], c["ack"]) for c in data["cases"]} != expected
                            or len(data["cases"]) != 6 or data.get("checks", 0) <= 0):
                        raise ValueError("Incomplete graphical ACK strategy/fault pairs")
                    if any(c["history_mismatches"] != 0 or c["accepted_visual_updates"] != c["edits"]
                           for c in data["cases"]):
                        raise ValueError("ACK fault cohort lost material updates or history")
                states = [json.loads(line.partition(" ")[2]) for line in text.splitlines()
                          if line.startswith("RENDER_UPLOAD_STATE ")]
                if strategy == "hybrid" and (not states or any(
                        state.get("active") != "hybrid" or state.get("fallback_reason")
                        or state.get("waiting_for_full_refresh") for state in states)):
                    raise ValueError("Mounted hybrid path was absent, refused, or fell back")
                row.update(passed=True, process=process, upload_states=states)
            except Exception as error:
                row["failure"] = type(error).__name__ + ": " + str(error)
                failures.append(label)
            report["cases"].append(row)
            write(output / "regressions.json", report)
    if source_identity(args.source_sha, args.allow_dirty) != source or retained_runtime_identity() != runtime:
        failures.append("source/runtime drift during qualification")
    report.update(complete=True, passed=not failures, failures=failures)
    write(output / "regressions.json", report)
    print("RENDER_UPLOAD_577_REGRESSIONS", json.dumps({"passed": not failures, "cases": len(report["cases"]), "failures": failures}))
    return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(main())
