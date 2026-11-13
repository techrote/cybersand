#!/usr/bin/env python3
"""Validate thirteen independently hosted camera ABBA cohorts against the original serial campaign.

The primary pass criteria are exact source/engine/apparatus identity, complete
per-scenario ABBA execution, and receipt integrity. Cross-run timing variation
is diagnostic, not by itself a regression gate.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from run_integrated_camera_performance import CASES, reduce_runs

EXPECTED = tuple(row["id"] for row in CASES)
ORDER = "ABBA"
SAMPLES = 180
WARMUP = 32


def ensure(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def read_json(path: Path) -> dict:
    ensure(path.is_file(), f"Missing required evidence: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def identity_pair(report: dict) -> dict:
    ensure(set(report.get("subjects", {})) == {"A", "B"}, "Both application subjects required")
    return {name: report["subjects"][name] for name in ("A", "B")}


def equivalent_provenance(report: dict, serial: dict, label: str) -> None:
    ensure(report.get("schema") == "integrated-camera-abba-v1", f"{label}: schema differs")
    ensure(report.get("complete") is True, f"{label}: incomplete report")
    ensure(report.get("order") == ORDER and report.get("rounds") == 1, f"{label}: not one ABBA round")
    ensure(report.get("samples_per_phase") == SAMPLES, f"{label}: sample count differs")
    ensure(report.get("warmup_per_phase") == WARMUP, f"{label}: warmup differs")
    for key in ("A", "B"):
        lhs, rhs = identity_pair(report)[key], identity_pair(serial)[key]
        for field in ("commit", "tree", "source_manifest_sha256", "native_sha256", "native_size"):
            ensure(lhs[field] == rhs[field], f"{label}: {key} {field} differs from serial")
        ensure(lhs["source_files"] == rhs["source_files"], f"{label}: {key} product sources differ")
    for field in ("runner_sha256", "harness_sha256"):
        ensure(report["apparatus"][field] == serial["apparatus"][field],
               f"{label}: {field} differs from serial")
    ensure(report["engine"]["version"] == serial["engine"]["version"], f"{label}: Godot version differs")
    for kind in ("launcher", "runtime"):
        for field in ("sha256", "size"):
            ensure(report["engine"][kind][field] == serial["engine"][kind][field],
                   f"{label}: actual Godot {kind} {field} differs")


def validate_shard(report: dict, case: dict, serial: dict) -> None:
    name = case["id"]
    equivalent_provenance(report, serial, name)
    ensure(report["cases"] == [case], f"{name}: mutated scenario parameters")
    ensure(len(report["runs"]) == 4, f"{name}: expected exactly four phases")
    ensure(len(report.get("comparisons", [])) == 1, f"{name}: comparison missing")
    ensure(report["comparisons"][0]["case"] == name, f"{name}: wrong comparison")
    for idx, run in enumerate(report["runs"]):
        side = ORDER[idx]
        ensure(run["case"] == name and run["round"] == 0 and run["phase"] == idx,
               f"{name}: phase {idx} mismatch")
        ensure(run["subject"] == side, f"{name}: A/B order corrupted at phase {idx}")
        ensure(run["source_commit"] == report["subjects"][side]["commit"],
               f"{name}: wrong source for phase {idx}")
        receipt = run["data"]
        ensure(receipt.get("ok") is True and not receipt.get("smoke_only"),
               f"{name}: invalid benchmark receipt phase {idx}")
        ensure(len(receipt.get("frames", [])) == SAMPLES,
               f"{name}: truncated measurement phase {idx}")
        process = run["process"]
        ensure(process.get("exit_code") == 0 and not process.get("timed_out"),
               f"{name}: benchmark process failed phase {idx}")
        ensure(not process.get("diagnostic_capture_started"),
               f"{name}: watchdog contaminated phase {idx}")
        ensure(receipt["context"]["engine_sha256"] == report["engine"]["runtime"]["sha256"],
               f"{name}: observed engine hash differs phase {idx}")
        ensure(receipt["context"]["fixture_sha256"] == report["apparatus"]["harness_sha256"],
               f"{name}: observed harness hash differs phase {idx}")
        ensure(process.get("announced_engine_pid") == receipt["context"]["process_id"],
               f"{name}: actual engine PID differs phase {idx}")
    independent = reduce_runs(report["runs"])
    for side in ("A", "B"):
        ensure(independent[0]["subjects"][side]["frames_ms"] ==
               report["comparisons"][0]["subjects"][side]["frames_ms"],
               f"{name}: summary does not reproduce")


def fmt(v: float) -> str:
    return f"{v:+.2f}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shards", required=True, type=Path)
    parser.add_argument("--serial", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--summary", required=True, type=Path)
    args = parser.parse_args()
    serial = read_json(args.serial)
    ensure(serial.get("complete") is True and serial.get("schema") == "integrated-camera-abba-v1",
           "Original serial campaign did not complete")
    ensure(tuple(row["id"] for row in serial["cases"]) == EXPECTED,
           "Original serial campaign has different scenario matrix")
    ensure(len(serial["runs"]) == 52, "Original serial campaign does not contain all 52 phases")
    ensure(len(serial.get("comparisons", [])) == 13, "Original serial comparisons incomplete")
    ensure(serial.get("historical_shader_abba"), "Original historical shader control absent")
    ensure(serial["order"] == ORDER and serial["samples_per_phase"] == SAMPLES and
           serial["warmup_per_phase"] == WARMUP, "Original serial measurement policy differs")
    ensure(len(set(EXPECTED)) == 13, "Expected case IDs must be unique")

    # Artifact action stores each matrix job in a directory named by its artifact.
    reports = list(args.shards.rglob("report.json"))
    ensure(len(reports) == 13, f"Expected 13 complete shard reports; found {len(reports)}")
    by_case = {}
    for path in reports:
        report = read_json(path)
        ensure(len(report.get("cases", [])) == 1, f"Unexpected scenario count: {path}")
        name = report["cases"][0]["id"]
        ensure(name in EXPECTED and name not in by_case, f"Duplicate or unknown shard: {name}")
        by_case[name] = report
    ensure(set(by_case) == set(EXPECTED), "Missing scenario shards: " +
           ", ".join(sorted(set(EXPECTED) - set(by_case))))

    table = []
    for config in CASES:
        case_id = config["id"]
        report = by_case[case_id]
        validate_shard(report, config, serial)
        if case_id == EXPECTED[0]:
            ensure(report.get("historical_shader_abba"), "Historical shader ABBA control missing")
            ensure(len(report["historical_shader_abba"]["data"]["extended_abba"]) == 4,
                   "Incomplete historical shader ABBA control")
        else:
            ensure("historical_shader_abba" not in report, f"{case_id}: unexpected historical control")

        current = report["comparisons"][0]
        original = next(row for row in serial["comparisons"] if row["case"] == case_id)
        for source in (original, current):
            ensure(set(source["subjects"]) == {"A", "B"}, f"{case_id}: missing baseline or candidate")
            for side in ("A", "B"):
                ensure(source["subjects"][side]["frames_ms"]["count"] == 360,
                       f"{case_id}: each A/B side requires two times 180 samples")
        def get(row, side):
            return row["subjects"][side]["frames_ms"]["p50"]
        serial_ratio = original["candidate_minus_baseline"]["p50"]["percent"]
        parallel_ratio = current["candidate_minus_baseline"]["p50"]["percent"]
        table.append({"case": case_id,
                      "serial_baseline_p50_ms": get(original, "A"),
                      "serial_candidate_p50_ms": get(original, "B"),
                      "parallel_baseline_p50_ms": get(current, "A"),
                      "parallel_candidate_p50_ms": get(current, "B"),
                      "serial_candidate_change_pct": serial_ratio,
                      "parallel_candidate_change_pct": parallel_ratio,
                      "delta_of_changes_pp": parallel_ratio - serial_ratio,
                      "runner_host": report["host"]})

    result = {"schema": "native-pixel-parallel-13way-comparison-v1",
              "complete": True, "scenario_count": 13, "benchmark_phase_count": 52,
              "original_serial_report": str(args.serial), "source_commit": serial["subjects"]["B"]["commit"],
              "baseline_commit": serial["subjects"]["A"]["commit"],
              "engine_sha256": serial["engine"]["runtime"]["sha256"],
              "harness_sha256": serial["apparatus"]["harness_sha256"],
              "native_baseline_sha256": serial["subjects"]["A"]["native_sha256"],
              "native_candidate_sha256": serial["subjects"]["B"]["native_sha256"],
              "historical_shader_control": "complete on first shard",
              "cases": table}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    lines = [
        "# Native-pixel 13-way parallel A/B qualification",
        "",
        "**PASS: all 13 independent scenarios, 52 sequential within-scenario ABBA phases, "
        "and separate historical shader control are complete.**",
        "",
        f"Candidate: \`{result['source_commit']}\` · Baseline: \`{result['baseline_commit']}\`",
        "",
        "| Scenario | Serial B/A p50 change | Parallel B/A p50 change | Difference |",
        "|---|---:|---:|---:|",
    ]
    for row in table:
        lines.append(f"| {row['case']} | {fmt(row['serial_candidate_change_pct'])}% | "
                     f"{fmt(row['parallel_candidate_change_pct'])}% | "
                     f"{fmt(row['delta_of_changes_pp'])} pp |")
    lines.extend(["", "All measurements retain 180 frames plus 32 warmup frames per phase, "
                  "one ABBA sequence per same-host scenario, and identical source/runtime/engine/harness hashes.",
                  "Absolute timing variations between GitHub-hosted Windows machines are advisory, not a source-integrity failure.",
                  ""])
    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text("\n".join(lines), encoding="utf-8")
    print("PARALLEL_CAMERA_ABBA_PASS cases=13 phases=52 historical_shader_control=1")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, KeyError, TypeError) as error:
        print(f"PARALLEL_CAMERA_ABBA_FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
