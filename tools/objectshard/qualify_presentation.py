#!/usr/bin/env python3
"""Early real-renderer qualification of immutable ObjectShard presentations.

This deliberately uses the committed retained native runtime only to load the
project. The fixtures supply synthetic copied material publications. It does
not qualify new native implementation, physics, or the portable evaluator.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
import execution_policy
import run_godot_regressions as runner
from process_resources import run_observed_case
from qualify_workbench import completion


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--expected-source-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    source = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    if source != args.expected_source_sha:
        raise ValueError("Presentation source is not the requested checkout")
    version = subprocess.check_output([str(args.godot), "--version"], text=True).strip()
    if version != "4.7.stable.official.5b4e0cb0f":
        raise ValueError("Presentation smoke requires the qualified Godot 4.7")
    renderer = "opengl3_angle" if sys.platform == "win32" else "opengl3"
    native_name = "cybersand_native.windows.x86_64.dll" if sys.platform == "win32" else "libcybersand_native.linux.x86_64.so"
    native_path = ROOT / "godot/addons/cybersand_native/bin" / native_name
    provenance = ROOT / "godot/addons/cybersand_native" / ("runtime-provenance.json" if sys.platform == "win32" else "runtime-provenance.linux.json")
    ledger = json.loads(provenance.read_text(encoding="utf-8"))
    report = {"schema": "objectshard-m4-presentation-smoke-v1", "source_commit": source,
              "source_tree": subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], cwd=ROOT, text=True).strip(),
              "status": "incomplete", "cases": [], "failures": [], "renderer": renderer,
              "engine": {"version": version, "sha256": runner.sha256(args.godot)},
              "retained_native": {"build_commit": ledger.get("build_commit"), "sha256": runner.sha256(native_path)},
              "scope": "synthetic immutable publications and actual rendered shader/framebuffer tests only; no new native or physical qualification"}
    env = dict(os.environ, CYBERSAND_SOURCE_REVISION=source)
    cases = [(runner.Case("presentation_import", ("--editor", "--quit"),
              int(execution_policy.watchdog_seconds("godot_import_seconds")), 0), None),
             (runner.Case("test_palette_shader_compile_bounds", ("--script", "res://tests/test_palette_shader_compile_bounds.gd"),
              int(execution_policy.watchdog_seconds("ordinary_case_seconds")), 0), None)]
    for name, schema in (("test_object_shard_m4_overlay_identity", "objectshard-m4-overlay-identity-v1"),
                         ("test_object_shard_m4_material_presentation_render", "objectshard-m4-material-presentation-v1")):
        flags = ("--rendering-driver", renderer, "--script", "res://tests/" + name + ".gd",
                 "--", "--output=" + str(args.output.resolve() / "captures"))
        cases.append((runner.Case(name, flags, int(execution_policy.watchdog_seconds("graphical_case_seconds")), 0, True), schema))
    try:
        for case, schema in cases:
            record, failed = run_observed_case(runner, str(args.godot), case, args.output.resolve(), "objectshard-presentation-only", env=env)
            if schema and not failed:
                try:
                    record["receipt"] = completion(args.output / record["log"], schema)
                except ValueError as exc:
                    record["receipt_error"] = str(exc)
                    failed = True
            report["cases"].append(record)
            if failed:
                report["failures"].append(case.name)
        report["status"] = "passed" if not report["failures"] else "failed"
    finally:
        (args.output / "summary.json").write_text(json.dumps(report, indent=2, sort_keys=True)+"\n", encoding="utf-8")
    print(json.dumps({"status":report["status"],"cases":len(report["cases"]),"failures":report["failures"]}))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
