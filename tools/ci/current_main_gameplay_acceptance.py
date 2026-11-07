#!/usr/bin/env python3
"""Guard and summarize the current-main integrated gameplay acceptance package."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any

BASE_MAIN = "7e2c2fd1aa2759590d63d5dfb53ce9e4c0a76e4b"
SCHEMA = "cybersand-current-main-integrated-gameplay-acceptance-v1"
REQUIRED_PROFILES = ("my-canvas", "bench-canvas", "stress-canvas")
ALLOWED_PREFIXES = (
    ".github/workflows/current-main-gameplay-acceptance.yml",
    "godot/tests/current_main_gameplay_acceptance.gd",
    "tools/ci/current_main_gameplay_acceptance.py",
    "tools/ci/test_current_main_gameplay_acceptance.py",
    "docs/audits/2026-11-06-current-main-integrated-gameplay-acceptance.md",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_source(expected_base: str, output: Path | None = None) -> dict[str, Any]:
    require(expected_base == BASE_MAIN, "Unregistered current-main baseline")
    head = git("rev-parse", "HEAD")
    require(git("merge-base", expected_base, head) == expected_base,
            "Registered main is not an ancestor of the qualification head")
    changed = [line for line in git("diff", "--name-only", expected_base, head).splitlines() if line]
    foreign = [path for path in changed if path not in ALLOWED_PREFIXES]
    require(not foreign, "Qualification branch changed production/unregistered paths: " + ", ".join(foreign))
    require("native/" not in "\n".join(changed), "Native source changed on qualification branch")
    identity = {
        "schema": "cybersand-current-main-acceptance-source-v1",
        "registered_main": expected_base,
        "qualification_head": head,
        "qualification_tree": git("rev-parse", "HEAD^{tree}"),
        "changed_paths": changed,
        "production_source_unchanged": True,
    }
    if output:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(identity, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(identity, indent=2))
    return identity


def stat(row: dict[str, Any], key: str, percentile: str = "p95") -> float:
    value = row.get(key, {})
    if not isinstance(value, dict):
        return 0.0
    try:
        return float(value.get(percentile, 0.0))
    except (TypeError, ValueError):
        return 0.0


def evaluate(data: dict[str, Any]) -> tuple[str, list[str]]:
    problems: list[str] = []
    if data.get("schema") != SCHEMA:
        problems.append("unexpected or missing result schema")
    if data.get("registered_main") != BASE_MAIN:
        problems.append("result does not pin the registered main baseline")
    rows = data.get("profiles")
    if not isinstance(rows, list):
        return "REPAIR", problems + ["profiles are missing"]
    by_name = {str(row.get("name")): row for row in rows if isinstance(row, dict)}
    if tuple(name for name in REQUIRED_PROFILES if name in by_name) != REQUIRED_PROFILES:
        problems.append("one or more required profiles are missing")
    for name in REQUIRED_PROFILES:
        row = by_name.get(name, {})
        if not row:
            continue
        if not bool(row.get("completed")):
            problems.append(f"{name}: workload did not complete")
        if float(row.get("elapsed_wall_ms", 0.0)) < 59000.0:
            problems.append(f"{name}: did not retain approximately 60 seconds of wall-time evidence")
        if int(row.get("completed_native_ticks", 0)) <= 0:
            problems.append(f"{name}: no native progress")
        if int(row.get("completed_rapier_ticks", 0)) <= 0:
            problems.append(f"{name}: no Rapier progress")
        if int(row.get("water_checks", 0)) <= 0 or int(row.get("water_mismatches", 1)) != 0:
            problems.append(f"{name}: exact Water conservation was not continuously observed")
        if not str(row.get("screenshot", "")):
            problems.append(f"{name}: graphical screenshot missing")
        spray = row.get("spray_final", {})
        ledger = spray.get("ledger", {}) if isinstance(spray, dict) else {}
        if int(ledger.get("launched_parcels", 0)) <= 0:
            problems.append(f"{name}: no ballistic parcel transport observed")
        assignment = row.get("water_assignment", {})
        if (str(assignment.get("applied_family", "")) != "pressure_flow_v1"
                or str(assignment.get("applied_variant", "")) != "cached_dormant"):
            problems.append(f"{name}: PressureFlow cached_dormant readback missing")
    impact_profiles = 0
    for row in by_name.values():
        spray = row.get("spray_final", {}) if isinstance(row, dict) else {}
        totals = spray.get("totals", {}) if isinstance(spray, dict) else {}
        if int(totals.get("launched", 0)) + int(totals.get("lifted", 0)) > 0:
            impact_profiles += 1
    if impact_profiles <= 0:
        problems.append("no registered profile observed body-driven impact spray")
    if int(data.get("failures", 0)) != 0:
        problems.append(f"harness recorded {int(data.get('failures', 0))} failed assertions")
    if not bool(data.get("worker_joined")):
        problems.append("exclusive worker did not join on shutdown")
    return ("ACCEPT" if not problems else "REPAIR"), problems


def write_summary(data: dict[str, Any], output: Path, csv_output: Path, qualification_output: Path) -> tuple[str, list[str]]:
    verdict, problems = evaluate(data)
    rows = {str(row.get("name")): row for row in data.get("profiles", []) if isinstance(row, dict)}
    lines = [
        "# CyberSand current-main integrated gameplay acceptance",
        "",
        f"**Verdict: {verdict}**",
        "",
        f"- Registered production main: `{data.get('registered_main', '')}`",
        f"- Executed qualification source: `{data.get('source_revision', '')}`",
        f"- Platform / display: {data.get('platform', '')} / {data.get('display_server', '')}",
        f"- Godot: {data.get('godot', '')}",
        "- Three production-workbench profiles, 60 seconds each.",
        "- Performance distributions are measurements, not pass/fail thresholds.",
        "- Lockstep is not substituted: PR #474 remains a separate non-main source stack.",
        "- Collider extraction is not isolated on this source; terrain-gate timing, hard-packet sizes/revisions and the explicitly non-isolated worker residual are reported instead.",
        "",
        "| Profile | Native Hz | Rapier Hz | frame p95 ms | native p95 ms | snapshot age p95 ms | terrain gate p95 ms | Rapier wait | hard revs | Water mismatches |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    csv_rows = []
    for name in REQUIRED_PROFILES:
        row = rows.get(name, {})
        wait_callbacks = int(row.get("rapier_wait_callbacks", 0))
        callbacks = int(row.get("rapier_callbacks", 0))
        wait = f"{wait_callbacks}/{callbacks}"
        fields = {
            "profile": name,
            "native_hz": float(row.get("completed_native_hz", 0.0)),
            "rapier_hz": float(row.get("completed_rapier_hz", 0.0)),
            "frame_p95_ms": stat(row, "process_interval_ms"),
            "native_p95_ms": stat(row, "native_tick_ms"),
            "snapshot_age_p95_ms": stat(row, "retained_snapshot_age_ms"),
            "terrain_gate_p95_ms": stat(row, "main_workbench_terrain_gate_ms"),
            "rapier_wait_callbacks": wait_callbacks,
            "rapier_callbacks": callbacks,
            "hard_surface_revision_changes": int(row.get("hard_surface_revision_changes", 0)),
            "water_mismatches": int(row.get("water_mismatches", 0)),
            "screenshot": str(row.get("screenshot", "")),
        }
        csv_rows.append(fields)
        lines.append(
            f"| {name} | {fields['native_hz']:.3f} | {fields['rapier_hz']:.3f} | "
            f"{fields['frame_p95_ms']:.3f} | {fields['native_p95_ms']:.3f} | "
            f"{fields['snapshot_age_p95_ms']:.3f} | {fields['terrain_gate_p95_ms']:.3f} | "
            f"{wait} | {fields['hard_surface_revision_changes']} | {fields['water_mismatches']} |"
        )
    lines.extend(["", "## Acceptance findings", ""])
    if problems:
        lines.extend(f"- REPAIR: {problem}" for problem in problems)
    else:
        lines.append("- All registered automated correctness gates passed.")
        lines.append("- This is automated source/runtime acceptance only; human feel and physical input-device acceptance remain open.")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    with csv_output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(csv_rows[0]) if csv_rows else ["profile"])
        writer.writeheader()
        writer.writerows(csv_rows)
    qualification = {
        "schema": "cybersand-current-main-integrated-gameplay-summary-v1",
        "verdict": verdict,
        "problems": problems,
        "registered_main": data.get("registered_main"),
        "qualification_source": data.get("source_revision"),
        "results_sha256": sha256(Path(data["_results_path"])) if data.get("_results_path") else None,
        "profiles": csv_rows,
        "limitations": {
            "human_feel_qualified": False,
            "physical_input_device_qualified": False,
            "lockstep_substituted": False,
            "collider_extraction_isolated": False,
        },
    }
    qualification_output.write_text(json.dumps(qualification, indent=2) + "\n", encoding="utf-8")
    return verdict, problems


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    verify = sub.add_parser("verify-source")
    verify.add_argument("--expected-base", required=True)
    verify.add_argument("--output", type=Path)
    summary = sub.add_parser("summarize")
    summary.add_argument("--input", type=Path, required=True)
    summary.add_argument("--output", type=Path, required=True)
    summary.add_argument("--csv", type=Path, required=True)
    summary.add_argument("--qualification", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "verify-source":
        verify_source(args.expected_base, args.output)
        return 0
    data = json.loads(args.input.read_text(encoding="utf-8"))
    data["_results_path"] = str(args.input)
    verdict, problems = write_summary(data, args.output, args.csv, args.qualification)
    print(json.dumps({"verdict": verdict, "problems": problems}, indent=2))
    return 0 if verdict == "ACCEPT" else 1


if __name__ == "__main__":
    raise SystemExit(main())