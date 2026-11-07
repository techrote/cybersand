#!/usr/bin/env python3
"""Source-matched PressureFlow gas rapid acceptance: no production physics changes.

Uses the immutable 360-configuration planner and Godot scene of PR #493.
The four 10-mode strata are 40 legal configurations, run as B-C-C-B
(two distinct source builds, two independent World reconstructions per build).
This is a screening gate; it NEVER substitutes for the 360x3 full factorial.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import statistics
import subprocess
import sys
import time

from stress_water_factorial import plan, stable_key, read_json, write_json

GROUPS = (
    "b0-f0-s0-j0-c0-n0",  # no ballistic/face/spray; ordinary 64-cell cores
    "b1-f0-s0-j0-c0-n0",  # ballistic alone; ordinary 64-cell cores
    "b1-f1-s1-j0-c0-n0",  # ballistic + face + spray; 64-cell cores
    "b1-f1-s1-j0-c1-n0",  # identical complete effects; 32-cell cores
)
REPEATS = 2
QUICK_GROUPS = ("b1-f1-s1-j0-c0-n0", "b1-f1-s1-j0-c1-n0")
ABBA = {
    ("baseline", 0): 0,
    ("candidate", 0): 1,
    ("candidate", 1): 2,
    ("baseline", 1): 3,
}
HEX40 = re.compile(r"^[a-f0-9]{40}$")
HEX64 = re.compile(r"^[a-f0-9]{64}$")
NATIVE = Path("godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll")
RAPIER = Path("godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll")
FIXTURE = Path("godot/tests/performance/water_factorial_stress.gd")
GENERATOR = Path(__file__).with_name("stress_water_factorial.py")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def selection(rep: int) -> list[dict]:
    if rep not in range(REPEATS):
        raise ValueError("Only two independently reconstructed rapid-screen repetitions")
    original = plan()
    rows = [cfg.copy() for cfg in original if cfg["group"] in GROUPS]
    modes = {cfg["water_mode"] for cfg in original}
    if len(original) != 360 or len(rows) != 40 or len(modes) != 10:
        raise AssertionError("Original #493 configuration universe has changed")
    for group in GROUPS:
        selected = [r for r in rows if r["group"] == group]
        if len(selected) != 10 or {r["water_mode"] for r in selected} != modes:
            raise AssertionError("Missing Water mode in a rapid-screen stratum")
    if len({r["id"] for r in rows}) != len(rows):
        raise AssertionError("Duplicate rapid-screen configuration")
    # The same shuffled order is used for a given repetition on BOTH sources.
    rows.sort(key=lambda r: stable_key(f"pf-gas-acceptance/r{rep}/" + r["id"]))
    for i, row in enumerate(rows):
        row.update(replicate=rep, shard=-2, sequence=i)
    return rows


def selected(rep: int, subset: str) -> list[dict]:
    """Keep the complete 40-case screen intact; quick is the two-core gameplay slice."""
    rows = selection(rep)
    if subset == "full":
        return rows
    if subset not in ("quick", "pfprofile"):
        raise ValueError("Unknown comparison subset: " + subset)
    rows = [r for r in rows if r["group"] in QUICK_GROUPS]
    if subset == "pfprofile":
        # All six PressureFlow modes plus FreeMass/CellularYield controls per core.
        rows = [r for r in rows if r["family"] in
                ("pressure_flow_v1", "freemass_v1", "cellular_yield_v1")]
    expected = 20 if subset == "quick" else 16
    if len(rows) != expected or len({r["id"] for r in rows}) != expected:
        raise AssertionError("Incomplete legal Godot profile subset")
    for i, row in enumerate(rows):
        row["sequence"] = i
    return rows


def check() -> None:
    for rep in range(REPEATS):
        rows = selection(rep)
        assert len(rows) == 40
        for row in rows:
            assert not row["face"] or row["ballistic"]
            assert not row["spray"] or row["ballistic"]
            assert not row["jet"]
            assert not row["normalize"]
        assert {r["id"] for r in rows} == {r["id"] for r in selection(0)}
    assert len(selected(0, "quick")) == 20
    print(json.dumps({
        "schema": "pf-gas-rapid-plan-v1",
        "source_planner": str(GENERATOR),
        "groups": GROUPS,
        "water_modes": sorted({r["water_mode"] for r in selection(0)}),
        "configurations": 40, "repetitions_per_source": REPEATS,
        "trials_per_source": 80, "paired_trials": 160,
        "full_factorial_unchanged": "360 configurations x 3 repetitions per source",
        "run_order": ["baseline-0", "candidate-0", "candidate-1", "baseline-1"],
    }, indent=2))


def hardware() -> dict:
    # Same runner/process environment is required; cross-machine comparisons refuse.
    return {
        "node": platform.node(),
        "system": platform.system(),
        "release": platform.release(),
        "machine": platform.machine(),
        "processor": os.environ.get("PROCESSOR_IDENTIFIER", platform.processor()),
        "logical_cpus": os.cpu_count(),
    }


def build_manifest(path: Path, native: Path) -> dict:
    doc = read_json(path)
    if not isinstance(doc, dict):
        raise ValueError("Native source-build manifest must be a JSON object")
    required = ("source_commit", "source_tree_sha", "native_sha256",
                "compiler", "build_flags", "build_profile", "build_job_url")
    missing = [key for key in required if not isinstance(doc.get(key), str) or not doc[key]]
    if missing:
        raise ValueError("Build manifest missing provenance: " + ", ".join(missing))
    if not HEX40.fullmatch(doc["source_commit"]) or not HEX40.fullmatch(doc["source_tree_sha"]):
        raise ValueError("Source commit/tree must be full Git SHA-1")
    if not HEX64.fullmatch(doc["native_sha256"]):
        raise ValueError("Native binary SHA-256 must be full")
    if sha256(native) != doc["native_sha256"]:
        raise ValueError("Installed Godot native DLL bytes do not match the source-build manifest")
    return doc


def execute(args: argparse.Namespace) -> int:
    if (args.role, args.replicate) not in ABBA:
        raise ValueError("Invalid B-C-C-B slot")
    if ABBA[(args.role, args.replicate)] != args.order_position:
        raise ValueError("Wrong ABBA order position")
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    manifest_path = out / f"manifest-r{args.replicate}.json"
    output_path = out / f"result-r{args.replicate}.json"
    receipt_path = out / f"receipt-r{args.replicate}.json"
    log_path = out / f"godot-r{args.replicate}.log"
    if any(x.exists() for x in (manifest_path, output_path, receipt_path, log_path)):
        raise FileExistsError("Existing run evidence cannot be overwritten")
    native = Path(args.native)
    rapier = Path(args.rapier)
    engine = Path(args.godot).resolve()
    if platform.system() != "Windows":
        raise RuntimeError("Existing #493 fixture requires the Windows prepared host")
    build = build_manifest(Path(args.source_build_manifest), native)
    version = subprocess.check_output(
        [str(engine), "--version"], text=True, timeout=30).strip()
    machine = hardware()
    receipt = {
        "schema": "pf-gas-rapid-receipt-v1",
        "role": args.role, "replicate": args.replicate,
        "order_position": args.order_position,
        "native_build": build,
        "hardware": machine,
        "godot_version": version,
        "godot_sha256": sha256(engine),
        "rapier_sha256": sha256(rapier),
        "native_sha256": sha256(native),
        "fixture_sha256": sha256(FIXTURE),
        "generator_sha256": sha256(GENERATOR),
        "acceptance_runner_sha256": sha256(Path(__file__)),
        "source_revision_harness": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], text=True, timeout=15).strip(),
        "note": "Source-built native DLL required; #493 historical retained DLL is NOT the candidate.",
    }
    # Receipt precedes execution so a crash does not destroy source/runtime identity.
    write_json(receipt_path, receipt)
    cases = selected(args.replicate, args.subset)
    write_json(manifest_path, {
        "schema": "water-factorial-manifest-v1",
        "seed": "pf-gas-rapid-from-493-v1",
        "replicate": args.replicate, "shard": -2,
        "pilot": False, "rapid_acceptance": True, "cases": cases,
    })
    env = dict(os.environ)
    env.update(
        CYBERSAND_FACTORIAL_MANIFEST=str(manifest_path),
        CYBERSAND_FACTORIAL_OUTPUT=str(output_path),
        CYBERSAND_FACTORIAL_WARMUP="30",
        CYBERSAND_FACTORIAL_MEASURE="100",
        GODOT_SILENCE_ROOT_WARNING="1",
    )
    cmd = [str(engine), "--headless", "--path", args.project,
           "--script", "res://tests/performance/water_factorial_stress.gd"]
    started = time.monotonic()
    with log_path.open("w", encoding="utf-8") as log:
        try:
            proc = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT,
                                  env=env, timeout=args.timeout, check=False)
            exit_code = proc.returncode
        except subprocess.TimeoutExpired:
            exit_code = 124
            log.write("\nPF_GAS_ACCEPTANCE_TIMEOUT\n")
    summary = {
        "schema": "pf-gas-rapid-run-summary-v1", "role": args.role,
        "replicate": args.replicate, "order_position": args.order_position,
        "exit_code": exit_code,
        "elapsed_wall_s": round(time.monotonic() - started, 3),
        "expected_cases": len(cases), "recorded_cases": 0,
        "status_counts": {}, "errors": [],
    }
    if output_path.exists():
        try:
            doc = read_json(output_path)
            rows = doc.get("cases", [])
            ids = [row.get("id") for row in rows]
            if doc.get("schema") != "water-factorial-result-v1":
                summary["errors"].append("Wrong result schema")
            if ids != [r["id"] for r in cases]:
                summary["errors"].append("Incomplete, duplicated, or reordered trials")
            if any(row.get("replicate") != args.replicate for row in rows):
                summary["errors"].append("Incorrect repetition")
            summary["recorded_cases"] = len(rows)
            for row in rows:
                status = str(row.get("status", "UNKNOWN"))
                summary["status_counts"][status] = summary["status_counts"].get(status, 0) + 1
            if any(row.get("status") != "PASS" for row in rows):
                summary["errors"].append("Non-PASS trial: preserve all physical failures")
        except (ValueError, TypeError, AttributeError) as exc:
            summary["errors"].append("Unreadable result: " + str(exc))
    else:
        summary["errors"].append("Missing result (logs and receipt retained)")
    if exit_code != 0:
        summary["errors"].append("Godot process returned " + str(exit_code))
    write_json(out / f"summary-r{args.replicate}.json", summary)
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 1 if summary["errors"] else 0


def load_role(root: Path, role: str, subset: str) -> tuple[dict, dict, dict]:
    receipts = {}
    trials = {}
    counts = {}
    for rep in range(REPEATS):
        receipt = read_json(root / f"receipt-r{rep}.json")
        doc = read_json(root / f"result-r{rep}.json")
        if receipt.get("schema") != "pf-gas-rapid-receipt-v1" or receipt.get("role") != role:
            raise ValueError(f"Bad {role} provenance for repetition {rep}")
        if receipt.get("replicate") != rep or receipt.get("order_position") != ABBA[(role, rep)]:
            raise ValueError(f"Invalid ABBA run ordering: {role}/{rep}")
        if doc.get("schema") != "water-factorial-result-v1":
            raise ValueError(f"Bad {role} result schema")
        rows = doc.get("cases", [])
        expected = selected(rep, subset)
        if len(rows) != len(expected):
            raise ValueError(f"{role}/{rep}: expected {len(expected)} trials, found {len(rows)}")
        for i, (row, cfg) in enumerate(zip(rows, expected)):
            key = (row.get("id"), row.get("replicate"))
            if key != (cfg["id"], rep) or key in trials:
                raise ValueError(f"{role}/{rep}: missing/duplicate/out-of-order trial #{i}")
            if row.get("config") != cfg:
                raise ValueError(f"{role}/{rep}: requested configuration not echoed by native host")
            status = str(row.get("status", "UNKNOWN"))
            counts[status] = counts.get(status, 0) + 1
            trials[key] = row
        receipts[rep] = receipt
    return receipts, trials, counts


def compare(args: argparse.Namespace) -> int:
    errors = []
    gaps = []
    a_receipts, a_rows, a_counts = load_role(Path(args.baseline), "baseline", args.subset)
    b_receipts, b_rows, b_counts = load_role(Path(args.candidate), "candidate", args.subset)
    for key in ("hardware", "godot_version", "godot_sha256",
                "rapier_sha256", "fixture_sha256", "generator_sha256",
                "acceptance_runner_sha256", "source_revision_harness"):
        values = {json.dumps(receipt.get(key), sort_keys=True)
                  for receipt in (*a_receipts.values(), *b_receipts.values())}
        if len(values) != 1:
            errors.append("Runtime or runner mismatch: " + key)
    source_ids = {}
    for role, receipts in (("baseline", a_receipts), ("candidate", b_receipts)):
        for key in ("source_commit", "source_tree_sha", "native_sha256",
                    "compiler", "build_flags", "build_profile", "build_job_url"):
            if len({r["native_build"].get(key) for r in receipts.values()}) != 1:
                errors.append(f"{role} inconsistent source-build {key}")
        source_ids[role] = receipts[0]["native_build"]["source_commit"]
    if source_ids["baseline"] == source_ids["candidate"]:
        errors.append("Identical baseline/candidate source commits")
    for key in ("compiler", "build_flags", "build_profile"):
        if a_receipts[0]["native_build"].get(key) != b_receipts[0]["native_build"].get(key):
            errors.append("Unequal build configuration: " + key)
    if set(a_rows) != set(b_rows):
        errors.append("Missing baseline/candidate matched trials")
    if any(k != "PASS" for k in (*a_counts.keys(), *b_counts.keys())):
        errors.append("At least one physical trial failed; preserve and investigate")
    per_config = []
    if not errors:
        for cfg in selected(0, args.subset):
            ident = cfg["id"]
            src = [a_rows[(ident, rep)] for rep in range(REPEATS)]
            dst = [b_rows[(ident, rep)] for rep in range(REPEATS)]
            if any(a["config"] != b["config"] for a, b in zip(src, dst)):
                errors.append("Unmatched physical options in " + ident)
                continue
            def median(rows: list[dict], field: str) -> float:
                vals = [float(r["summary"].get(field, -1)) for r in rows]
                if not all(0 < v < float("inf") for v in vals):
                    raise ValueError(f"Missing positive metric {ident}/{field}")
                return statistics.median(vals)
            metric_fields = ("native_tick_p50_ms", "native_tick_p95_ms",
                             "native_tick_p99_ms", "native_hz",
                             "rapier_step_p50_ms", "rapier_step_p95_ms")
            samples = {}
            for field in metric_fields:
                base = median(src, field)
                candidate = median(dst, field)
                samples[field] = {
                    "baseline": base, "candidate": candidate,
                    "delta": candidate - base,
                    "ratio": candidate / base,
                    "baseline_range": [min(float(x["summary"][field]) for x in src),
                                       max(float(x["summary"][field]) for x in src)],
                    "candidate_range": [min(float(x["summary"][field]) for x in dst),
                                        max(float(x["summary"][field]) for x in dst)],
                }
            per_config.append({"id": ident, "config": cfg,
                               "metrics": samples,
                               "actor_traces_present": all(
                                   bool(r["summary"].get("actor_trace")) for r in src + dst),
                               "spray_ledgers_present": all(
                                   isinstance(r["summary"].get("spray_ledger"), dict)
                                   for r in src + dst)})
    if len(per_config) != len(selected(0, args.subset)):
        errors.append("Incomplete paired statistical distribution")
    # #493 does not expose these data. Missing telemetry blocks final acceptance;
    # do not confuse tick wall time with CPU time, nor async actor motion with lockstep.
    required_fields = ("native_state_hash", "native_quantity_ledger",
                       "gas_stage_cpu_ms", "process_cpu_ms", "active_native_workers")
    for field in required_fields:
        if not all(field in row.get("summary", {}) for row in (*a_rows.values(), *b_rows.values())):
            gaps.append("Required source-matched correctness/CPU telemetry absent: " + field)
    if not all(c.get("actor_traces_present") and c.get("spray_ledgers_present")
               for c in per_config):
        gaps.append("Actor/splash traces incomplete")
    ratios = [c["metrics"]["native_tick_p50_ms"]["ratio"] for c in per_config]
    report = {
        "schema": "pf-gas-rapid-comparison-v1",
        "disposition": "REPAIR" if errors else "NOT_YET_QUALIFIED",
        "scope": "rapid screen only; 360x3 plus gameplay still required",
        "source_commits": source_ids,
        "coverage": {
            "configurations": len(selected(0, args.subset)),
            "baseline_trials": len(a_rows), "candidate_trials": len(b_rows),
            "baseline_statuses": a_counts, "candidate_statuses": b_counts,
            "missing_or_duplicate": bool(set(a_rows) != set(b_rows) or len(a_rows) != 2*len(selected(0, args.subset)) or len(b_rows) != 2*len(selected(0, args.subset))),
        },
        "median_p50_candidate_over_baseline": statistics.median(ratios) if ratios else None,
        "p50_improved_configurations": sum(r < 1 for r in ratios),
        "p50_regressed_configurations": sum(r > 1 for r in ratios),
        "gaps": gaps, "errors": errors, "per_configuration": per_config,
        "note": "Wall duration is not CPU execution time. Two repeats measure only screening variability.",
    }
    write_json(Path(args.output), report)
    print(json.dumps({k: v for k, v in report.items() if k != "per_configuration"},
                     indent=2, sort_keys=True))
    return 1 if errors else (2 if gaps else 0)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("check")
    p = commands.add_parser("execute")
    p.add_argument("--role", choices=("baseline", "candidate"), required=True)
    p.add_argument("--replicate", type=int, choices=(0, 1), required=True)
    p.add_argument("--order-position", type=int, choices=range(4), required=True)
    p.add_argument("--source-build-manifest", required=True)
    p.add_argument("--godot", required=True)
    p.add_argument("--project", default="godot")
    p.add_argument("--native", default=str(NATIVE))
    p.add_argument("--rapier", default=str(RAPIER))
    p.add_argument("--out", required=True)
    p.add_argument("--timeout", type=int, default=3600)
    p.add_argument("--subset", choices=("full","quick","pfprofile"), default="full")
    a = commands.add_parser("compare")
    a.add_argument("--baseline", required=True)
    a.add_argument("--candidate", required=True)
    a.add_argument("--output", required=True)
    a.add_argument("--subset", choices=("full","quick","pfprofile"), default="full")
    args = parser.parse_args()
    if args.command == "check":
        check()
        return 0
    if args.command == "execute":
        return execute(args)
    return compare(args)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, RuntimeError, FileNotFoundError, FileExistsError, AssertionError) as exc:
        print(f"PF_GAS_ACCEPTANCE_ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
