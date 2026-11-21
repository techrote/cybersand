#!/usr/bin/env python3
"""Run the actual inherited Workbench receipt serializer under pinned Godot.

This bounded unit regression performs editor import and metadata serialization
only. It does not generate or qualify the 80 Genteks or admit a native runtime.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import traceback

import qualify

ROOT = Path(__file__).resolve().parents[2]
INPUTS = (
    "godot/tests/test_architectural_generator.gd",
    "godot/tools/qualify_gentek80_workbench.gd",
    "godot/tools/test_gentek80_workbench_receipt.gd",
    "tools/architecture/qualify.py",
    "tools/architecture/check_gentek80_workbench_receipt.py",
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    if not 1 <= args.timeout <= 1200:
        parser.error("--timeout must be between 1 and 1200 seconds per process")
    engine, output = args.godot.resolve(), args.output.resolve()
    if output.exists() and any(output.iterdir()):
        parser.error("--output must be a new or empty directory; preserve earlier evidence")
    output.mkdir(parents=True, exist_ok=True)
    report = {"schema": "gentek80-workbench-receipt-regression-v1", "status": "failed",
              "scope": "unit-only inherited receipt assembly and JSON serialization; no catalogue generation or runtime admission",
              "generation_executed": False, "runtime_admission": False, "results": []}
    try:
        version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
        if version != qualify.VERSION:
            raise RuntimeError("Godot version pin mismatch: " + version)
        report["godot"] = {"path": str(engine), "sha256": qualify.sha(engine), "version": version}
        before = qualify.source_identity(ROOT / "godot")
        inputs = {name: qualify.sha(ROOT / name) for name in INPUTS}
        report.update(source_identity=before, inputs_sha256=inputs)
        report["uncommitted_input_status"] = subprocess.check_output(
            ["git", "status", "--porcelain", "--untracked-files=all", "--", *INPUTS],
            cwd=ROOT, text=True, timeout=30).splitlines()
        environment = os.environ.copy()
        for name, suffix in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                             ("XDG_CACHE_HOME", "cache"), ("APPDATA", "roaming"), ("LOCALAPPDATA", "local")):
            directory = output / "profile" / suffix
            directory.mkdir(parents=True, exist_ok=True)
            environment[name] = str(directory)
        environment["CYBERSAND_SOURCE_REVISION"] = before["source_commit"]
        base = [str(engine), "--audio-driver", "Dummy", "--headless", "--path", str(ROOT / "godot")]
        results = report["results"]
        results.append(qualify.run("import", [*base, "--editor", "--quit"], environment, output, args.timeout))
        if results[-1]["passed"]:
            result = qualify.run("receipt-serializer", [*base, "--script", "res://tools/test_gentek80_workbench_receipt.gd"],
                                 environment, output, args.timeout,
                                 r"GENTEK80_WORKBENCH_RECEIPT checks=([1-9][0-9]*) failures=0 complete=true")
            completion = result.get("completion", [])
            result["passed"] = (result["passed"] and len(completion) == 1
                                and completion[0].isdecimal() and 13 <= int(completion[0]) <= 1000)
            report["checks"] = int(completion[0]) if len(completion) == 1 and completion[0].isdecimal() else 0
            results.append(result)
        else:
            results.append({"case": "receipt-serializer", "passed": False, "skipped": True,
                            "reason": "Editor import did not pass"})
        after = qualify.source_identity(ROOT / "godot")
        stable = before == after and inputs == {name: qualify.sha(ROOT / name) for name in INPUTS}
        stable = stable and report["godot"]["sha256"] == qualify.sha(engine)
        results.append({"case": "source-stability", "passed": stable})
        report["source_and_runtime_unchanged"] = stable
        if all(result["passed"] for result in results):
            report["status"] = "passed"
    except Exception as error:
        report.update(error=str(error), traceback=traceback.format_exc())
    path = output / "qualification.json"
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": report["status"], "scope": report["scope"],
                      "checks": report.get("checks", 0), "output": str(path), "error": report.get("error")}))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
