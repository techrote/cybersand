#!/usr/bin/env python3
"""Execute real Wave/Workbench pixels against the publisher's validated runtime."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
import wave_mt_runtime_publication as publication
# A stacked branch publisher reuses this helper with its own profile; the
# profile mutates the shared engine, so its branch/request/cases apply here.
if os.environ.get("CYBERSAND_PUBLICATION_PROFILE") == "wave_waterwall":
    import wave_waterwall_runtime_publication as _profile  # noqa: F401
elif os.environ.get("CYBERSAND_PUBLICATION_PROFILE") == "wave_waterwall_002":
    import wave_waterwall_002_runtime_publication as _profile  # noqa: F401
elif os.environ.get("CYBERSAND_PUBLICATION_PROFILE") == "wave_water_ramp_003":
    import wave_water_ramp_003_runtime_publication as _profile  # noqa: F401
elif os.environ.get("CYBERSAND_PUBLICATION_PROFILE") == "wave_water_face_004":
    import wave_water_face_004_runtime_publication as _profile  # noqa: F401

CASES = {
    "test_wave_flow_render": ("WAVE_FLOW_RENDER:", "wave-flow-render.json", 4),
    "test_workbench_wave_render": ("WORKBENCH_WAVE_RENDER", "workbench-wave-render.json", 6),
}


def verify_capture(directory: Path, case: str, output: str) -> dict:
    marker, receipt_name, expected_captures = CASES[case]
    matches = re.findall(r"(?m)^" + re.escape(marker) + r" (\{.+\})\s*$", output)
    publication.engine.require(len(matches) == 1, "Missing unique graphical summary: " + case)
    summary = json.loads(matches[0])
    publication.engine.require(isinstance(summary, dict)
                               and type(summary.get("assertions")) is int and summary["assertions"] > 0
                               and type(summary.get("failures")) is int and summary["failures"] == 0
                               and type(summary.get("captures")) is int and summary["captures"] == expected_captures,
                               "Incomplete graphical execution: " + case)
    receipt = json.loads((directory / receipt_name).read_text(encoding="utf-8"))
    publication.engine.require(isinstance(receipt, dict), "Malformed graphical receipt: " + case)
    captures = receipt.get("captures")
    publication.engine.require(isinstance(captures, list) and len(captures) == summary["captures"]
                               and type(receipt.get("failures")) is int and receipt["failures"] == 0
                               and receipt.get("source_commit") == os.environ["GITHUB_SHA"],
                               "Graphical capture receipt differs: " + case)
    screenshots = {}
    for capture in captures:
        publication.engine.require(isinstance(capture, dict), "Malformed graphical capture")
        name = capture.get("screenshot", "")
        publication.engine.require(isinstance(name, str) and Path(name).name == name
                                   and name.endswith(".png") and name not in screenshots,
                                   "Invalid or duplicate graphical capture name")
        path = directory / name
        publication.engine.require(path.is_file() and not path.is_symlink()
                                   and path.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"),
                                   "Missing original graphical capture: " + name)
        screenshots[name] = publication.engine.runner.sha256(path)
    return {"summary": summary, "receipt": receipt_name,
            "receipt_sha256": publication.engine.runner.sha256(directory / receipt_name),
            "screenshots_sha256": screenshots}


def verify_graphical_bundle(bundle: Path, source: str) -> dict:
    """Recheck downloaded raw evidence before any runtime publication."""
    engine = publication.engine
    manifest = engine.verify_bundle(bundle, "linux", source, validated=True)
    headless = json.loads((bundle / "validation.json").read_text(encoding="utf-8"))
    output = bundle / "graphical"
    report = json.loads((output / "qualification.json").read_text(encoding="utf-8"))
    expected = {"schema": "wave-workbench-source-matched-graphical-v1",
                "source_commit": source, "source_tree": manifest["source_tree"],
                "native_sha256": manifest["sha256"], "godot": headless["godot"],
                "rapier_sha256": headless["rapier_sha256"], "status": "passed"}
    engine.require(all(report.get(key) == value for key, value in expected.items()),
                   "Graphical report identity/status differs from the validated runtime")
    records = report.get("cases")
    engine.require(isinstance(records, list) and len(records) == len(CASES)
                   and [record.get("name") for record in records] == list(CASES),
                   "Graphical report lacks the complete ordered case set")
    for record in records:
        name = record["name"]
        log = output / (name + ".log")
        engine.require(record.get("status") == "passed" and record.get("natural_completion") is True
                       and type(record.get("returncode")) is int and record["returncode"] == 0
                       and record.get("requires_display") is True and record.get("skip_messages") == []
                       and record.get("diagnostic_error") is False
                       and record.get("log_sha256") == engine.runner.sha256(log)
                       and report.get("log_sha256", {}).get(log.name) == engine.runner.sha256(log),
                       "Incomplete or changed graphical execution: " + name)
        verified = verify_capture(output / (name + "-artifacts"), name, log.read_text(encoding="utf-8"))
        engine.require(report.get("captures", {}).get(name) == verified,
                       "Graphical capture evidence changed: " + name)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    engine = publication.engine
    engine.require(os.environ.get("GITHUB_SHA") == args.source_sha, "Graphical source differs from workflow source")
    if args.verify_only:
        verify_graphical_bundle(args.bundle, args.source_sha)
        print("Verified complete source-matched Wave and Workbench graphical evidence")
        return 0
    engine.require(sys.platform.startswith("linux") and bool(os.environ.get("DISPLAY")),
                   "Actual Linux rendering display is required")
    engine.require(args.godot is not None, "A pinned Godot executable is required")
    manifest = engine.verify_bundle(args.bundle, "linux", args.source_sha, validated=True)
    runtime = ROOT / engine.RUNTIMES["linux"]
    engine.require(engine.runner.sha256(runtime) == manifest["sha256"],
                   "Rendered runtime differs from validated publisher bytes")
    native_report = json.loads((args.bundle / "validation.json").read_text(encoding="utf-8"))
    version = subprocess.check_output([str(args.godot), "--version"], text=True, timeout=30).strip()
    engine.require(version == engine.GODOT_VERSION
                   and engine.runner.sha256(args.godot) == native_report["godot"]["runtime_sha256"],
                   "Graphical Godot differs from the validated engine")
    output = args.bundle / "graphical"
    output.mkdir(parents=True, exist_ok=False)
    report = {"schema": "wave-workbench-source-matched-graphical-v1",
              "source_commit": args.source_sha, "source_tree": manifest["source_tree"],
              "native_sha256": manifest["sha256"], "godot": native_report["godot"],
              "rapier_sha256": native_report["rapier_sha256"],
              "scope": "actual Linux software-rendered controls and native pixels; no physical GPU acceptance",
              "status": "running", "cases": [], "captures": {}}
    report_path = output / "qualification.json"
    discovered = {case.name: case for case in engine.runner.discover_cases()}
    try:
        for name in CASES:
            engine.require(name in discovered and discovered[name].requires_display,
                           "Graphical regression missing or incorrectly headless: " + name)
            record, failed = engine.runner.run_case(str(args.godot), discovered[name], output, "case")
            report["cases"].append(record)
            engine.require(not failed and record.get("skip_messages") == [],
                           "Graphical regression failed: " + name)
            report["captures"][name] = verify_capture(
                output / (name + "-artifacts"), name, (output / (name + ".log")).read_text(encoding="utf-8"))
            engine.runner.write_json(report_path, report)
        engine.require(engine.runner.sha256(runtime) == manifest["sha256"],
                       "Rendered native runtime changed during execution")
        report["status"] = "passed"
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.SubprocessError) as error:
        report["status"] = "failed"
        report["error"] = str(error)
    report["log_sha256"] = {path.name: engine.runner.sha256(path) for path in output.glob("*.log")}
    engine.runner.write_json(report_path, report)
    if report["status"] == "passed":
        verify_graphical_bundle(args.bundle, args.source_sha)
    print(json.dumps({"status": report["status"], "source_commit": args.source_sha,
                      "cases": len(report["cases"]), "error": report.get("error")}))
    return int(report["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
