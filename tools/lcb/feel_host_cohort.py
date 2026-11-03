#!/usr/bin/env python3
"""LCB-FEEL #360 small full desktop-host cohort.

Runs each registered arm in a fresh Godot process through the ordinary desktop
launcher feature, Main, simulation owner, native World, Rapier bridge and (by
default) the windowed renderer. Family order rotates per repeat. Records the
source tree, runtime bytes, Godot binary and machine, then reduces medians per
arm. Timings are observations of this machine, not benchmarks or feel.
"""
from __future__ import annotations

import argparse
import json
import statistics
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import feel_preflight as fp  # noqa: E402

SCHEMA = "lcb-feel-host-cohort-v1"
SCENARIOS = ("lcb.dam.water.freemass.depth-96.v1", "lcb.rest.deep-quiet-pool.v1")
FAMILIES = ("freemass_v1", "cellular_yield_v1", "pressure_flow_v1", "inertial_cellular_v1")
WORKERS = (1, 4)


def arms(repeats: int) -> list[dict]:
    plan = []
    for repeat in range(repeats):
        rotated = FAMILIES[repeat % len(FAMILIES):] + FAMILIES[:repeat % len(FAMILIES)]
        for scenario in SCENARIOS:
            for workers in WORKERS:
                for family in rotated:
                    plan.append({"repeat": repeat, "scenario": scenario, "family": family, "workers": workers,
                                 "arm": f"{scenario}|{family}|w{workers}"})
    return plan


def command_run(arguments: argparse.Namespace) -> int:
    output = Path(arguments.output).resolve()
    (output / "arms").mkdir(parents=True, exist_ok=True)
    (output / "logs").mkdir(parents=True, exist_ok=True)
    label = fp.host_platform()
    runtime = fp.runtime_identity(label)
    source = fp.source_identity()
    if not runtime["source_matched_runtime"]:
        print("STOP: native runtime is not source-matched", file=sys.stderr)
        return 3
    timeout = fp.execution_policy.watchdog_seconds("ordinary_case_seconds")
    manifest = {"schema": SCHEMA, "platform": label, "source": source, "runtime": runtime,
                "godot": fp.godot_identity(arguments.godot), "machine": fp.machine_identity(),
                "headless": arguments.headless, "ticks": arguments.ticks, "repeats": arguments.repeats,
                "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "executions": []}
    for index, arm in enumerate(arms(arguments.repeats)):
        name = fp.safe_name(f"r{arm['repeat']}-{arm['arm']}")
        record = output / "arms" / (name + ".json")
        log = output / "logs" / (name + ".log")
        command = [arguments.godot]
        command += ["--headless"] if arguments.headless else ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy"]
        command += ["--path", str(fp.ROOT / "godot"), "--script", "res://tests/lcb_feel_host_cohort.gd", "--",
                    f"--scenario={arm['scenario']}", f"--family={arm['family']}", f"--workers={arm['workers']}",
                    f"--ticks={arguments.ticks}", f"--output={record.as_posix()}"]
        process = fp.run_process(command, log, timeout)
        manifest["executions"].append({"order": index, **arm, "record": record.relative_to(output).as_posix(),
                                       **process, "record_sha256": fp.sha256_file(record) if record.exists() else None,
                                       "log_sha256": fp.sha256_file(log)})
        print(f"[{index + 1}] {arm['arm']} r{arm['repeat']} exit={process['exit_code']} {process['wall_seconds']:.1f}s", flush=True)
    manifest["finished_utc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    (output / "packet.json").write_bytes((json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8"))
    return 0


def command_reduce(arguments: argparse.Namespace) -> int:
    directory = Path(arguments.packet)
    manifest = json.loads((directory / "packet.json").read_text(encoding="utf-8"))
    if manifest.get("schema") != SCHEMA or not manifest["runtime"]["source_matched_runtime"]:
        print("STOP: wrong schema or unmatched runtime", file=sys.stderr)
        return 1
    if not manifest["source"]["executed_tree_matches_head"] and not arguments.development:
        print("STOP: executed tree had uncommitted source changes", file=sys.stderr)
        return 1
    grouped: dict[str, list[dict]] = {}
    failures = []
    for execution in manifest["executions"]:
        path = directory / execution["record"]
        if execution["exit_code"] != 0 or execution["timed_out"] or not path.exists() \
                or fp.sha256_file(path) != execution["record_sha256"]:
            failures.append({"arm": execution["arm"], "repeat": execution["repeat"], "exit_code": execution["exit_code"],
                             "timed_out": execution["timed_out"]})
            continue
        record = json.loads(path.read_text(encoding="utf-8"))
        if record["applied"]["water_family"] != execution["family"] \
                or record["workers"]["configured_capacity"] != execution["workers"]:
            failures.append({"arm": execution["arm"], "repeat": execution["repeat"], "error": "applied identity mismatch"})
            continue
        grouped.setdefault(execution["arm"], []).append(record)
    rows = []
    for arm, records in sorted(grouped.items()):
        def median(path: tuple[str, ...]) -> float:
            values = []
            for record in records:
                value = record
                for key in path:
                    value = value[key]
                values.append(float(value))
            return statistics.median(values)
        ledger = [record["owner_capture"]["water_ledger"] for record in records]
        rows.append({"arm": arm, "repeats": len(records),
                     "applied_family": records[0]["applied"]["water_family"], "radius": records[0]["applied"]["maximum_rule_radius"],
                     "configured_capacity": records[0]["workers"]["configured_capacity"],
                     "max_observed_claimants": max(record["workers"]["max_observed"] for record in records),
                     "native_ticks_per_second_median": median(("outcome", "native_ticks_per_second")),
                     "censored": sum(1 for record in records if record["outcome"]["censored_by_wall_limit"]),
                     "owner_native_tick_ms_p50_median": median(("owner_capture", "native_timing", "p50_ms")),
                     "owner_native_tick_ms_p95_median": median(("owner_capture", "native_timing", "p95_ms")),
                     "owner_step_ms_p50_median": median(("owner_step_ms", "p50")),
                     "main_frame_ms_p50_median": median(("main_frame_ms", "p50")),
                     "main_frame_ms_p95_median": median(("main_frame_ms", "p95")),
                     "snapshot_age_ms_p50_median": median(("snapshot_age_ms", "p50")),
                     "rapier_step_ms_p95_median": median(("rapier_step_ms", "p95")),
                     "water_conserved_all": all(entry.get("observed_current_integer") == entry.get("initial_integer") for entry in ledger),
                     "simulation_failed": any(record["outcome"]["simulation_failed"] for record in records)})
    summary = {"schema": SCHEMA + "-summary", "platform": manifest["platform"], "source": manifest["source"],
               "runtime": {key: manifest["runtime"][key] for key in ("native_sha256", "rapier_sha256", "source_matched_runtime")},
               "godot": manifest["godot"], "machine": manifest["machine"], "headless": manifest["headless"],
               "ticks": manifest["ticks"], "repeats": manifest["repeats"], "rows": rows, "failures": failures}
    text = json.dumps(summary, indent=2, sort_keys=True) + "\n"
    if arguments.output:
        Path(arguments.output).write_bytes(text.encode("utf-8"))
    for row in rows:
        print(f"{row['arm']:60} cap {row['configured_capacity']} claim {row['max_observed_claimants']} "
              f"tps {row['native_ticks_per_second_median']:.1f} native p50 {row['owner_native_tick_ms_p50_median']:.2f} "
              f"frame p50/p95 {row['main_frame_ms_p50_median']:.2f}/{row['main_frame_ms_p95_median']:.2f} "
              f"age {row['snapshot_age_ms_p50_median']:.1f} water_ok {row['water_conserved_all']}")
    if failures:
        print("FAILURES:", failures, file=sys.stderr)
    return 1 if failures else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    run = commands.add_parser("run")
    run.add_argument("--godot", required=True)
    run.add_argument("--output", required=True)
    run.add_argument("--ticks", type=int, default=600)
    run.add_argument("--repeats", type=int, default=3)
    run.add_argument("--headless", action="store_true")
    run.set_defaults(handler=command_run)
    reduce = commands.add_parser("reduce")
    reduce.add_argument("--packet", required=True)
    reduce.add_argument("--output", default="")
    reduce.add_argument("--development", action="store_true")
    reduce.set_defaults(handler=command_reduce)
    arguments = parser.parse_args(argv)
    return arguments.handler(arguments)


if __name__ == "__main__":
    raise SystemExit(main())
