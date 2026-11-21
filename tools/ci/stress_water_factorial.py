#!/usr/bin/env python3
"""Bounded, exhaustive legal-toggle Water stress matrix and exact-head reporting.

Design: one identical 1024x512 stress-canvas for all 360 legal binary switch
combinations, with 8 real Rapier actors, 30 native-tick warmup and 100 measured
native ticks. Three independent fresh-run repetitions. Full-policy pairs share
the same shard/Windows runner, with order reshuffled between repetitions.
The matrix only enumerates finite on/off options, not continuous tuning ranges.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
import os
from pathlib import Path
import random
import statistics
import subprocess
import sys
import time

SEED = "cybersand-water-factorial-stress-20261107-v1"
SHARDS = 24
REPLICATES = 3
WATER_MODES = [
    ("freemass", "freemass_v1", "reference", False, False),
    ("yield", "cellular_yield_v1", "reference", False, False),
    ("pf-reference-gasoff", "pressure_flow_v1", "reference", False, False),
    ("pf-reference-gason", "pressure_flow_v1", "reference", True, False),
    ("pf-cached-gasoff", "pressure_flow_v1", "cached", False, False),
    ("pf-cached-gason", "pressure_flow_v1", "cached", True, False),
    ("pf-dormant-gasoff", "pressure_flow_v1", "cached_dormant", False, False),
    ("pf-dormant-gason", "pressure_flow_v1", "cached_dormant", True, False),
    ("inertial", "inertial_cellular_v1", "reference", False, False),
    ("inertial-signed", "inertial_cellular_v1", "reference", False, True),
]


def stable_key(value: str) -> int:
    return int(hashlib.sha256((SEED + ":" + value).encode()).hexdigest()[:16], 16)


def plan() -> list[dict]:
    rows: list[dict] = []
    for ballistic in (False, True):
        face_states = (False, True) if ballistic else (False,)
        splash_states = (False, True) if ballistic else (False,)
        jet_states = (False, True) if ballistic else (False,)
        for face, splash, jet in itertools.product(
            face_states, splash_states, jet_states
        ):
            for fine, normalize in itertools.product((False, True), repeat=2):
                group = (
                    f"b{int(ballistic)}-f{int(face)}-s{int(splash)}-"
                    f"j{int(jet)}-c{int(fine)}-n{int(normalize)}"
                )
                for name, family, variant, gas, signed in WATER_MODES:
                    rows.append({
                        "id": f"{name}--{group}",
                        "group": group,
                        "water_mode": name,
                        "family": family,
                        "variant": variant,
                        "gas": gas,
                        "signed": signed,
                        "ballistic": ballistic,
                        "face": face,
                        "spray": splash,
                        "jet": jet,
                        "fine": fine,
                        "normalize": normalize,
                        "rule_radius": 3 if family == "inertial_cellular_v1" else 2,
                    })
    ids = [r["id"] for r in rows]
    if len(rows) != 360 or len(ids) != len(set(ids)):
        raise AssertionError("Expected 360 unique legal finite-switch configurations")
    return rows


def allocations() -> dict[int, list[dict]]:
    all_rows = plan()
    groups = sorted({r["group"] for r in all_rows}, key=lambda g: stable_key("group/" + g))
    shards: dict[int, list[dict]] = {i: [] for i in range(SHARDS)}
    for i, group in enumerate(groups):
        selected = [r for r in all_rows if r["group"] == group]
        if len(selected) != 10:
            raise AssertionError("Each toggle stratum must contain the same 10 Water modes")
        shards[i % SHARDS].extend(selected)
    expected_ids = set(r["id"] for r in all_rows)
    allocated_ids = [r["id"] for rows in shards.values() for r in rows]
    if len(allocated_ids) != 360 or set(allocated_ids) != expected_ids:
        raise AssertionError("Incomplete or duplicated shard allocation")
    return shards


def make_batch(shard: int, rep: int) -> list[dict]:
    rows = [r.copy() for r in allocations()[shard]]
    rows.sort(key=lambda r: stable_key(f"repeat/{rep}/shard/{shard}/" + r["id"]))
    for i, row in enumerate(rows):
        row.update(replicate=rep, shard=shard, sequence=i)
    return rows


def make_pilot() -> list[dict]:
    names = [
        ("freemass", "b0-f0-s0-j0-c0-n0"),
        ("yield", "b1-f1-s1-j0-c0-n0"),
        ("pf-reference-gasoff", "b1-f1-s1-j0-c0-n0"),
        ("pf-cached-gason", "b1-f1-s1-j0-c1-n1"),
        ("pf-dormant-gason", "b1-f1-s1-j0-c0-n0"),
        ("inertial", "b0-f0-s0-j0-c1-n1"),
        ("inertial-signed", "b1-f0-s0-j1-c0-n0"),
    ]
    index = {(r["water_mode"], r["group"]): r for r in plan()}
    rows = []
    for i, (mode, group) in enumerate(names):
        r = index[(mode, group)].copy()
        r.update(replicate=0, shard=-1, sequence=i)
        rows.append(r)
    return rows


def read_json(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run_batches(args: argparse.Namespace) -> int:
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    scenario_sets = [make_pilot()] if args.pilot else [
        make_batch(args.shard, rep) for rep in range(REPLICATES)
    ]
    batch_outputs = []
    errors: list[str] = []
    for rep, scenarios in enumerate(scenario_sets):
        manifest = out / f"manifest-r{rep}.json"
        result = out / f"result-r{rep}.json"
        log = out / f"godot-r{rep}.log"
        write_json(manifest, {
            "schema": "water-factorial-manifest-v1",
            "seed": SEED,
            "replicate": rep,
            "shard": args.shard,
            "pilot": args.pilot,
            "cases": scenarios,
        })
        env = dict(os.environ)
        env.update(
            CYBERSAND_FACTORIAL_MANIFEST=str(manifest),
            CYBERSAND_FACTORIAL_OUTPUT=str(result),
            CYBERSAND_FACTORIAL_WARMUP="30",
            CYBERSAND_FACTORIAL_MEASURE="100",
            GODOT_SILENCE_ROOT_WARNING="1",
        )
        command = [
            str(Path(args.godot).resolve()), "--headless", "--path", args.project,
            "--script", "res://tests/performance/water_factorial_stress.gd",
        ]
        write_json(out / f"command-r{rep}.json", command)
        print(f"START shard={args.shard} rep={rep} cases={len(scenarios)}", flush=True)
        started = time.monotonic()
        with log.open("w", encoding="utf-8") as stream:
            proc = subprocess.Popen(
                command, stdout=stream, stderr=subprocess.STDOUT,
                env=env, text=True,
            )
            try:
                while proc.poll() is None:
                    if time.monotonic() - started > args.batch_timeout:
                        raise TimeoutError(f"Godot batch r{rep} exceeded {args.batch_timeout}s")
                    time.sleep(1)
                    stream.flush()
                    observed = log.read_text(encoding="utf-8", errors="replace")
                    if "SCRIPT ERROR:" in observed or "Failed to load script" in observed:
                        raise RuntimeError(f"GDScript failure: {observed[-2200:]}")
            except BaseException as exc:
                proc.kill()
                proc.wait(timeout=15)
                errors.append(f"rep {rep}: {exc}")
        if proc.returncode:
            errors.append(f"rep {rep}: process exit {proc.returncode}")
        if not result.exists():
            errors.append(f"rep {rep}: missing result.json")
            continue
        try:
            record = read_json(result)
            actual = record.get("cases", [])
            expected = set(c["id"] for c in scenarios)
            seen = [x.get("id", "") for x in actual]
            if len(actual) != len(expected) or set(seen) != expected or len(set(seen)) != len(seen):
                errors.append(f"rep {rep}: incomplete or duplicated results {len(seen)}/{len(expected)}")
            statuses = {}
            for row in actual:
                statuses[row.get("status", "?")] = statuses.get(row.get("status", "?"), 0) + 1
            batch_outputs.append({
                "rep": rep, "statuses": statuses, "results": len(actual),
                "seconds": round(time.monotonic() - started, 2),
            })
            print(f"COMPLETE shard={args.shard} rep={rep} status={statuses}", flush=True)
        except (ValueError, TypeError, AttributeError) as exc:
            errors.append(f"rep {rep}: unreadable results {exc}")
    summary = {
        "schema": "water-factorial-runner-v1",
        "shard": args.shard, "pilot": args.pilot,
        "batches": batch_outputs, "errors": errors,
    }
    write_json(out / "runner-summary.json", summary)
    print("WATER_FACTORIAL_RUNNER " + json.dumps(summary, sort_keys=True), flush=True)
    return 1 if errors else 0


def finite(x: object) -> bool:
    return isinstance(x, (float, int)) and math.isfinite(float(x))


def aggregate(args: argparse.Namespace) -> int:
    root = Path(args.input)
    files = list(root.rglob("result-r*.json"))
    records: list[dict] = []
    errors: list[str] = []
    for filename in files:
        try:
            doc = read_json(filename)
            if doc.get("schema") != "water-factorial-result-v1":
                errors.append(f"bad schema {filename}")
                continue
            if doc.get("pilot"):
                continue
            records.extend(doc.get("cases", []))
        except Exception as exc:
            errors.append(f"{filename}: {exc}")
    expected = {
        (row["id"], rep) for row in plan() for rep in range(REPLICATES)
    }
    actual = [(row.get("id"), row.get("replicate")) for row in records]
    absent = sorted(expected - set(actual))
    duplicate = len(actual) - len(set(actual))
    unexpected = sorted(set(actual) - expected)
    by_status: dict[str, int] = {}
    for row in records:
        key = str(row.get("status", "unknown"))
        by_status[key] = by_status.get(key, 0) + 1
    successful = [row for row in records if row.get("status") == "PASS"]
    groups = {}
    for row in successful:
        groups.setdefault(row["id"], []).append(row)
    medians = {}
    for case_id, series in groups.items():
        samples = [float(r["summary"].get("native_tick_p50_ms", -1)) for r in series]
        rates = [float(r["summary"].get("native_hz", -1)) for r in series]
        if len(series) == REPLICATES and all(finite(x) and x > 0 for x in samples):
            medians[case_id] = {
                "native_tick_p50_ms_median": statistics.median(samples),
                "native_tick_p50_ms_range": [min(samples), max(samples)],
                "native_hz_median": statistics.median(rates),
                "native_hz_range": [min(rates), max(rates)],
            }
    # Exact-factor comparisons, with every non-varied factor held identical.
    conf = {row["id"]: row for row in plan()}
    effects: dict[str, dict] = {}
    for factor in ("gas", "fine", "normalize", "face", "spray", "jet", "signed"):
        pairs = []
        for case_id, cfg in conf.items():
            if not cfg.get(factor):
                next_cfg = cfg.copy()
                next_cfg[factor] = True
                # Water family/domain validity must remain exactly matched.
                match = next((id2 for id2, c2 in conf.items()
                    if all(c2[k] == next_cfg[k] for k in (
                        "family", "variant", "gas", "signed", "ballistic",
                        "face", "spray", "jet", "fine", "normalize"
                    ))), None)
                if match and case_id in medians and match in medians:
                    ref = medians[case_id]["native_tick_p50_ms_median"]
                    new = medians[match]["native_tick_p50_ms_median"]
                    if ref > 0:
                        pairs.append({"control": case_id, "variant": match,
                                      "ratio": new / ref, "difference_ms": new - ref})
        effects[factor] = {
            "n_matched_strata": len(pairs),
            "median_ratio": statistics.median(x["ratio"] for x in pairs) if pairs else None,
            "median_delta_ms": statistics.median(x["difference_ms"] for x in pairs) if pairs else None,
        }
    summary = {
        "schema": "water-factorial-summary-v1",
        "expected_configurations": 360,
        "expected_repeated_trials": len(expected),
        "records": len(records), "unique_records": len(set(actual)),
        "status_counts": by_status,
        "successful_full_repeats": len(medians),
        "missing_count": len(absent), "missing": absent[:60],
        "duplicate_count": duplicate,
        "unexpected": unexpected[:30],
        "errors": errors,
        "effects": effects,
        "per_configuration": medians,
    }
    write_json(Path(args.output), summary)
    print("WATER_FACTORIAL_AGGREGATE " + json.dumps({
        k: v for k, v in summary.items() if k not in ("per_configuration", "missing")
    }, sort_keys=True))
    # Report actual World failures in data, but fail CI for missing coverage or
    # duplicate records, not for an independently confirmed physics refusal.
    return 1 if absent or duplicate or unexpected or errors else 0


def main() -> int:
    parser = argparse.ArgumentParser()
    p = parser.add_subparsers(dest="command", required=True)
    p.add_parser("count")
    r = p.add_parser("execute")
    r.add_argument("--godot", required=True)
    r.add_argument("--project", default="godot")
    r.add_argument("--out", required=True)
    r.add_argument("--shard", type=int, default=0)
    r.add_argument("--pilot", action="store_true")
    r.add_argument("--batch-timeout", type=int, default=650)
    a = p.add_parser("aggregate")
    a.add_argument("--input", required=True)
    a.add_argument("--output", required=True)
    args = parser.parse_args()
    if args.command == "count":
        print(json.dumps({"configurations": len(plan()),
                          "repetitions": REPLICATES,
                          "trials": len(plan()) * REPLICATES,
                          "shards": SHARDS, "water_modes": WATER_MODES,
                          "shard_sizes": {i: len(v) for i, v in allocations().items()},
                          "pilot": make_pilot()}, indent=2))
        return 0
    if args.command == "execute":
        return run_batches(args)
    return aggregate(args)


if __name__ == "__main__":
    raise SystemExit(main())
