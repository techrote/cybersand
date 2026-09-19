#!/usr/bin/env python3
"""Run current Godot regressions, optionally split into deterministic isolated shards."""

import argparse
from collections import Counter
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_UNKNOWN_WEIGHT_SECONDS = 5.0

# Approximate weights from the 2026-09-19 Linux CI run. They are scheduling hints,
# not pass/fail thresholds. Unknown tests deliberately receive a conservative
# weight so new fixtures are never omitted and are unlikely to overload one shard.
CASE_WEIGHTS_SECONDS = {
    "test_microscenarios": 54.0,
    "test_interaction_policy": 37.0,
    "profile_scheduler": 20.0,
    "test_transport_probe": 14.0,
    "test_interaction_async": 13.0,
    "test_web_worker_parity": 11.0,
    "test_cell_world": 10.0,
    "test_worker_benchmark": 4.0,
    "test_microscenario_controllers": 3.0,
    "test_water_feel_controller": 3.0,
    "test_water_feel_integration": 3.0,
    "test_physics_async": 2.5,
    "test_tick_failure_regression": 2.0,
    "scene": 2.0,
    "test_experiment_tower": 1.5,
    "test_web_rapier": 1.5,
    "profile_native_world": 1.0,
}


@dataclass(frozen=True)
class Case:
    name: str
    flags: tuple[str, ...]
    timeout: int
    weight: float


def _weight(name: str) -> float:
    return CASE_WEIGHTS_SECONDS.get(name, DEFAULT_UNKNOWN_WEIGHT_SECONDS)


def discover_cases(root: Path = ROOT) -> list[Case]:
    cases = [
        Case(
            p.stem,
            ("--script", "res://tests/" + p.name),
            180,
            _weight(p.stem),
        )
        for p in sorted((root / "godot/tests").glob("test_*.gd"))
    ]
    cases += [
        Case(
            name,
            ("--script", "res://tests/" + name + ".gd"),
            1200,
            _weight(name),
        )
        for name in ("profile_native_world", "profile_scheduler")
    ]
    cases.append(Case("scene", ("--quit-after", "180"), 180, _weight("scene")))
    names = [case.name for case in cases]
    if len(names) != len(set(names)):
        duplicates = sorted(name for name, count in Counter(names).items() if count > 1)
        raise RuntimeError(f"Duplicate Godot regression case names: {duplicates}")
    return cases


def build_shard_plan(cases: list[Case], shard_count: int) -> tuple[list[list[Case]], list[float]]:
    if shard_count < 1:
        raise ValueError("shard_count must be at least 1")
    if not cases:
        return [[] for _ in range(shard_count)], [0.0] * shard_count

    canonical_order = {case.name: index for index, case in enumerate(cases)}
    shards: list[list[Case]] = [[] for _ in range(shard_count)]
    totals = [0.0] * shard_count

    # Longest-processing-time scheduling gives deterministic, reasonably balanced
    # shards while retaining each case's original relative order within its shard.
    for case in sorted(cases, key=lambda item: (-item.weight, item.name)):
        index = min(range(shard_count), key=lambda i: (totals[i], i))
        shards[index].append(case)
        totals[index] += case.weight

    for shard in shards:
        shard.sort(key=lambda case: canonical_order[case.name])
    validate_shard_plan(cases, shards)
    return shards, totals


def validate_shard_plan(cases: list[Case], shards: list[list[Case]]) -> None:
    expected = Counter(case.name for case in cases)
    actual = Counter(case.name for shard in shards for case in shard)
    if actual != expected:
        missing = sorted((expected - actual).elements())
        extra = sorted((actual - expected).elements())
        raise RuntimeError(f"Invalid shard plan; missing={missing}, extra={extra}")
    duplicates = sorted(name for name, count in actual.items() if count != 1)
    if duplicates:
        raise RuntimeError(f"Cases must appear exactly once across shards: {duplicates}")


def case_dict(case: Case) -> dict:
    return {
        "name": case.name,
        "timeout_seconds": case.timeout,
        "estimated_seconds": case.weight,
        "flags": list(case.flags),
    }


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run_case(godot: str, case: Case, output_dir: Path, role: str) -> tuple[dict, bool]:
    log_path = output_dir / (case.name + ".log")
    command = [godot, "--headless", "--path", str(ROOT / "godot"), *case.flags]
    print(f"Running {case.name}, timeout {case.timeout}s: {command}", flush=True)
    started = time.perf_counter()
    timed_out = False
    returncode = None
    with log_path.open("w", encoding="utf-8") as log:
        try:
            result = subprocess.run(
                command,
                cwd=ROOT,
                stdout=log,
                stderr=subprocess.STDOUT,
                timeout=case.timeout,
            )
            returncode = result.returncode
        except subprocess.TimeoutExpired:
            timed_out = True
            log.write(f"\nTIMEOUT after {case.timeout}s\n")
    elapsed = time.perf_counter() - started
    output = log_path.read_text(encoding="utf-8", errors="replace")
    print(output, end="", flush=True)
    diagnostic_error = "SCRIPT ERROR:" in output or "ERROR:" in output
    failed = timed_out or returncode != 0 or diagnostic_error
    status = "timeout" if timed_out else ("failed" if failed else "passed")
    record = {
        "name": case.name,
        "role": role,
        "status": status,
        "seconds": round(elapsed, 3),
        "timeout_seconds": case.timeout,
        "returncode": returncode,
        "diagnostic_error": diagnostic_error,
        "log": log_path.name,
    }
    if failed:
        print(
            f"{case.name} {status}; exit={returncode}; see {log_path}",
            flush=True,
        )
    return record, failed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--shard-count", type=int, default=1)
    parser.add_argument("--shard-index", type=int, default=0)
    args = parser.parse_args()

    if args.shard_count < 1:
        parser.error("--shard-count must be at least 1")
    if not 0 <= args.shard_index < args.shard_count:
        parser.error("--shard-index must be in [0, shard-count)")

    args.output.mkdir(parents=True, exist_ok=True)
    runtime = ROOT / "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
    rapier = ROOT / "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
    if not runtime.is_file():
        raise RuntimeError(f"Missing CyberSand runtime: {runtime}")
    if not rapier.is_file():
        raise RuntimeError(f"Missing Rapier runtime: {rapier}")

    source_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    godot_version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    identity = {
        "source_sha": source_sha,
        "godot_version": godot_version,
        "cybersand_runtime": {
            "path": str(runtime.relative_to(ROOT)),
            "sha256": sha256(runtime),
        },
        "rapier_runtime": {
            "path": str(rapier.relative_to(ROOT)),
            "sha256": sha256(rapier),
        },
        "shard_count": args.shard_count,
        "shard_index": args.shard_index,
    }
    write_json(args.output / "identity.json", identity)
    (args.output / "identity.txt").write_text(
        source_sha + "\n"
        + identity["cybersand_runtime"]["sha256"] + "  " + identity["cybersand_runtime"]["path"] + "\n"
        + identity["rapier_runtime"]["sha256"] + "  " + identity["rapier_runtime"]["path"] + "\n"
        + godot_version + "\n",
        encoding="utf-8",
    )

    cases = discover_cases()
    shards, totals = build_shard_plan(cases, args.shard_count)
    plan = {
        "shard_count": args.shard_count,
        "default_unknown_weight_seconds": DEFAULT_UNKNOWN_WEIGHT_SECONDS,
        "all_case_count": len(cases),
        "shards": [
            {
                "index": index,
                "estimated_seconds": round(totals[index], 3),
                "cases": [case_dict(case) for case in shard],
            }
            for index, shard in enumerate(shards)
        ],
    }
    write_json(args.output / "shard-plan.json", plan)
    assigned = shards[args.shard_index]
    print(
        f"Shard {args.shard_index + 1}/{args.shard_count}: "
        f"{len(assigned)}/{len(cases)} cases, estimated {totals[args.shard_index]:.1f}s",
        flush=True,
    )
    for index, shard in enumerate(shards):
        print(
            f"  shard {index}: {totals[index]:.1f}s :: "
            + ", ".join(case.name for case in shard),
            flush=True,
        )

    results: list[dict] = []
    timing = {
        "identity": identity,
        "assigned_cases": [case.name for case in assigned],
        "results": results,
    }

    # Every isolated shard performs a clean import preflight. In unsharded mode
    # this is the same single import that the legacy runner performed.
    import_case = Case("import", ("--editor", "--quit"), 240, 3.0)
    record, failed = run_case(args.godot, import_case, args.output, "preflight")
    results.append(record)
    write_json(args.output / "timings.json", timing)
    if failed:
        return 1

    for case in assigned:
        record, failed = run_case(args.godot, case, args.output, "case")
        results.append(record)
        write_json(args.output / "timings.json", timing)
        if failed:
            return 1

    print(
        f"Passed shard {args.shard_index + 1}/{args.shard_count}: "
        f"import plus {len(assigned)} assigned cases "
        f"({len(cases)} unique suite cases across all shards)",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
