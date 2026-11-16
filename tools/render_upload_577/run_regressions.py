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
from health_qualification import run_failure_control
from health_validation_cases import validation_cases


CASES = [
    ("helper-history", "test_material_upload_hybrid.gd", "MATERIAL_UPLOAD_HYBRID ", {}, "helper-history"),
    ("preparation-lifecycle", "test_render_upload_577_preparation_lifecycle.gd", "RENDER_UPLOAD_577_PREPARATION_LIFECYCLE ", {}, "preparation-lifecycle"),
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
    if name == "helper-history":
        verify_helper_history(data)
        return
    paths = {"res://scripts/material_upload_hybrid.gd", "res://shaders/material_upload_copy.gdshader",
             "res://tests/" + script}
    if name == "preparation-lifecycle":
        paths = {"res://scripts/main.gd", "res://scripts/material_upload_hybrid.gd",
                 "res://scripts/material_upload_shader_prepare.gd", "res://scripts/simulation_worker.gd",
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
    elif name == "preparation-lifecycle":
        cases = data.get("cases", [])
        expected = {(2, "hybrid", "native-phased"), (2, "full", "native-phased"),
                    (1, "hybrid", "gdscript-serial-fallback")}
        if (data.get("schema") != "render-upload-577-independent-preparation-lifecycle-v1"
                or data.get("checks") != 123 or len(cases) != 3
                or {(c.get("channels"), c.get("initial_strategy"), c.get("backend")) for c in cases} != expected):
            raise ValueError("Actual Main preparation lifecycle corpus is incomplete or changed")
        for case in cases:
            preparation = case.get("preparation", {})
            observations = case.get("observations", [])
            if (case.get("preparation_runs") != 1 or preparation.get("prepared") is not True
                    or preparation.get("channels") != case["channels"]
                    or preparation.get("temporary_viewport_count") != 3 or preparation.get("readback_count") != 12
                    or case.get("ack") != case.get("final_serial") or case.get("final_serial", 0) <= 0
                    or not observations or any(o.get("unchanged") is not True or o.get("result") is not True
                                              or o.get("accepted_before") != o.get("accepted_after") for o in observations)):
                raise ValueError("Shader preparation changed accepted material/binding identity or failed to complete")


def helper_history_record_labels() -> list[str]:
    labels = []
    for fmt in ("R8", "RG8"):
        labels.extend([fmt + " initial current", fmt + " initial previous"])
        publications = ([f"sparse {i}" for i in range(12)]
                        + [f"dense alternating {i}" for i in range(12)]
                        + [f"sparse reentry {i}" for i in range(9)]
                        + ["full refresh", "generation replacement"]
                        + [f"retained staging {i}" for i in range(42)])
        for publication in publications:
            labels.extend(fmt + " " + publication + suffix for suffix in (" current", " previous", ""))
        labels.append(fmt + " adopted previous")
        labels.extend(fmt + " first publication after adoption" + suffix for suffix in (" current", " previous", ""))
        labels.append(fmt + " adopted source remains immutable")
        for i in range(12):
            labels.extend(fmt + f" staging retirement publication {i}" + suffix for suffix in (" current", " previous", ""))
    return labels


def verify_helper_history(data: dict) -> None:
    """Retain the existing full R8/RG8 publication corpus in both OS gates."""
    records = data.get("records", [])
    if (data.get("schema") != "material-upload-hybrid-correctness-v1"
            or data.get("ok") is not True or data.get("failures") != []
            or data.get("checks") != 1514
            or not isinstance(records, list) or any(not isinstance(record, dict) for record in records)
            or [record.get("case") for record in records] != helper_history_record_labels()):
        raise ValueError("Helper current/previous history corpus is incomplete or changed")
    for record in records:
        readback = record["case"].endswith((" current", " previous", "source remains immutable"))
        if not readback:
            if (set(record) != {"case", "metrics"} or not isinstance(record["metrics"], dict)
                    or record["metrics"].get("mode") not in {"compact_full", "transition_seed", "partial_blit"}):
                raise ValueError("Helper history omitted a valid publication mode")
        elif (set(record) != {"case", "equal", "actual_sha256", "expected_sha256"}
              or record.get("equal") is not True
              or record.get("actual_sha256") != record.get("expected_sha256")
              or re.fullmatch(r"[0-9a-f]{64}", record.get("actual_sha256", "")) is None):
            raise ValueError("Helper current/previous GPU contents differ or lack a digest")
    shader = data.get("context", {}).get("shader", {})
    expected = sha(ROOT / "godot/shaders/material_upload_copy.gdshader")
    if (shader.get("source_bound") is not True or shader.get("source_file_bound") is not True
            or shader.get("source_path") != "res://shaders/material_upload_copy.gdshader"
            or any(shader.get(key) != expected for key in ("source_file_sha256", "source_sha256", "variant_sha256"))):
        raise ValueError("Helper readback shader is not bound to the checked-out copy source")


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
    # Once per OS, retain the real legacy native failure and prove that both
    # collectors refuse it. It is never counted as a successful timing arm.
    if args.cases == "all":
        try:
            negative = run_failure_control(engine, source, output / "native-failure-control",
                                          output.parent / (output.name + "-userdata"), args.rendering_driver, args.timeout)
            report["native_failure_control"] = negative
            if os.name == "nt":
                write(output / "health-validator-cases.json", validation_cases())
                process = execute(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                    str(ROOT / "tools/render_upload_577/Test-Health.ps1"), "-Cases", str(output / "health-validator-cases.json"),
                    "-NegativeReceipt", str(output / "native-failure-control/runtime.json")],
                    os.environ.copy(), output / "powershell-health-validator", 60)
                text = (output / "powershell-health-validator/process.log").read_text(encoding="utf-8", errors="replace")
                marker = "RENDER_UPLOAD_577_HEALTH_VALIDATOR "
                results = [json.loads(line.removeprefix(marker)) for line in text.splitlines() if line.startswith(marker)]
                if (len(results) != 1 or results[0].get("checks") != len(validation_cases()) + 1
                        or not results[0].get("powershell", "").startswith("5.1.")):
                    raise ValueError("Actual Windows PowerShell 5.1 health admission controls did not complete")
                report["powershell_health_validator"] = {"result": results[0], "process": process}
        except Exception as error:
            failures.append("native-health-admission-control")
            report["native_health_control_failure"] = type(error).__name__ + ": " + str(error)
        write(output / "regressions.json", report)
    for strategy in strategies:
        for name, script, marker, additions, profile in cases:
            internal_pair = name == "ack-graphical"
            independent = name in {"helper-history", "queued-history", "main-refusal", "preparation-lifecycle"}
            mounted = name not in {"handoff", "generation", "palette", "vapour", "pending-compaction", "ack-graphical", "helper-history", "queued-history", "main-refusal", "preparation-lifecycle"}
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
                   "scope": "independent actual-Main preparation lifecycle correctness" if name == "preparation-lifecycle" else
                            "independent GPU history/refusal correctness" if independent else
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
