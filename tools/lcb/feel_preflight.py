#!/usr/bin/env python3
"""LCB-FEEL #360 admission preflight driver and independent strict reducer.

``run`` executes every registered arm of a registration in its own fresh Godot
process on the current host and writes a raw packet: one receipt per case, one
log per process, and a manifest binding source tree, actual native/Rapier
runtime bytes, Godot executable and machine identity.

``reduce`` independently re-reads one or more packets, rechecks their identity,
decodes every quantity strictly (booleans and floats are never integers), and
evaluates the registered invariants, worker-parity and negative controls. It
exits non-zero on any stop condition. It never relaxes, retries or drops a case.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
import platform
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
import execution_policy  # noqa: E402

PACKET_SCHEMA = "lcb-feel-packet-v1"
SUMMARY_SCHEMA = "lcb-feel-preflight-summary-v1"
RECEIPT_SCHEMA = "lcb-feel-case-receipt-v1"
DEFAULT_REGISTRATION = "godot/tests/fixtures/lcb/feel/lcb.feel.preflight.v1.json"
RUNTIMES = {
    "windows": ("godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
                "godot/addons/cybersand_native/runtime-provenance.json",
                "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"),
    "linux": ("godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
              "godot/addons/cybersand_native/runtime-provenance.linux.json",
              "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"),
}
# Files Godot regenerates on import; never source inputs of this experiment.
GENERATED_DIRTY = re.compile(r"\.(uid|import)$")
SOURCE_SUFFIXES = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}


class StopCondition(Exception):
    pass


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def git(*arguments: str) -> str:
    return subprocess.run(["git", "-C", str(ROOT), *arguments], check=True,
                          capture_output=True, text=True).stdout.strip()


def host_platform() -> str:
    if sys.platform.startswith("win"):
        return "windows"
    if sys.platform.startswith("linux"):
        return "linux"
    raise SystemExit("unsupported host platform " + sys.platform)


def source_identity() -> dict:
    dirty = [line[3:] for line in git("status", "--porcelain", "--untracked-files=all").splitlines() if line]
    material = [path for path in dirty if not GENERATED_DIRTY.search(path)]
    return {"head": git("rev-parse", "HEAD"), "tree": git("rev-parse", "HEAD^{tree}"),
            "branch": git("rev-parse", "--abbrev-ref", "HEAD"),
            "dirty_generated_paths": len(dirty) - len(material), "dirty_source_paths": material,
            "executed_tree_matches_head": not material}


def native_input_paths() -> set[str]:
    return {path.relative_to(ROOT).as_posix()
            for directory in ("native/include", "native/src", "godot/native_extension")
            for path in (ROOT / directory).rglob("*") if path.is_file() and path.suffix in SOURCE_SUFFIXES}


def runtime_identity(label: str) -> dict:
    native, provenance_path, rapier = RUNTIMES[label]
    manifest = json.loads((ROOT / provenance_path).read_text(encoding="utf-8"))
    native_bytes = (ROOT / native).read_bytes()
    stale = sorted(relative for relative, expected in manifest["source_inputs"].items()
                   if not (ROOT / relative).exists()
                   or sha256_bytes((ROOT / relative).read_bytes().replace(b"\r\n", b"\n")) != expected)
    coverage = set(manifest["source_inputs"]) == native_input_paths()
    native_hash = sha256_bytes(native_bytes)
    return {"native_artifact": native, "native_sha256": native_hash, "native_size": len(native_bytes),
            "provenance_path": provenance_path, "provenance_sha256": sha256_file(ROOT / provenance_path),
            "provenance_artifact_sha256": manifest["sha256"], "provenance_build_commit": manifest["build_commit"],
            "provenance_workflow_run": manifest.get("workflow_run", ""),
            "native_matches_provenance": native_hash == manifest["sha256"] and len(native_bytes) == manifest["size"],
            "source_inputs_cover_current_tree": coverage, "stale_source_inputs": stale,
            "source_matched_runtime": native_hash == manifest["sha256"] and coverage and not stale,
            "rapier_artifact": rapier, "rapier_sha256": sha256_file(ROOT / rapier)}


def machine_identity() -> dict:
    info = {"platform": platform.platform(), "machine": platform.machine(), "python": platform.python_version(),
            "logical_cpus": os.cpu_count(), "processor": platform.processor()}
    if sys.platform.startswith("linux"):
        try:
            text = Path("/proc/cpuinfo").read_text(encoding="utf-8", errors="replace")
            model = re.search(r"^model name\s*:\s*(.+)$", text, re.M)
            info["cpu_model"] = model.group(1) if model else ""
            memory = re.search(r"^MemTotal:\s*(\d+) kB", Path("/proc/meminfo").read_text(), re.M)
            info["memory_bytes"] = int(memory.group(1)) * 1024 if memory else None
            info["kernel"] = platform.release()
            info["wsl"] = "microsoft" in platform.release().lower()
        except OSError:
            pass
    elif sys.platform.startswith("win"):
        info["cpu_model"] = os.environ.get("PROCESSOR_IDENTIFIER", "")

        class MemoryStatus(ctypes.Structure):
            _fields_ = [("length", ctypes.c_ulong), ("load", ctypes.c_ulong), ("total", ctypes.c_ulonglong),
                        ("available", ctypes.c_ulonglong), ("page_total", ctypes.c_ulonglong),
                        ("page_available", ctypes.c_ulonglong), ("virtual_total", ctypes.c_ulonglong),
                        ("virtual_available", ctypes.c_ulonglong), ("extended", ctypes.c_ulonglong)]
        status = MemoryStatus()
        status.length = ctypes.sizeof(MemoryStatus)
        if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):
            info["memory_bytes"] = int(status.total)
    return info


def godot_identity(godot: str) -> dict:
    version = subprocess.run([godot, "--version"], capture_output=True, text=True, timeout=120).stdout.strip()
    return {"path_name": Path(godot).name, "sha256": sha256_file(Path(godot)), "version": version.splitlines()[-1] if version else ""}


def case_id(scenario: str, arm: dict, workers: int) -> str:
    return f"{scenario}|{arm['lane']}|{arm['family']}.{arm['variant']}|r{arm['radius']}|w{workers}"


def safe_name(identifier: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", identifier)


def expand(registration: dict) -> list[dict]:
    cases = []
    for scenario in registration["scenarios"]:
        for arm in registration["arms"]:
            for workers in registration["workers"]:
                cases.append({"case_id": case_id(scenario["id"], arm, workers), "scenario": scenario["id"],
                              "workers": workers, **arm})
    return cases


def peak_rss(process: subprocess.Popen) -> int | None:
    if sys.platform.startswith("win"):
        class Counters(ctypes.Structure):
            _fields_ = [("cb", ctypes.c_ulong), ("faults", ctypes.c_ulong), ("peak_working_set", ctypes.c_size_t),
                        ("working_set", ctypes.c_size_t), ("peak_paged_pool", ctypes.c_size_t),
                        ("paged_pool", ctypes.c_size_t), ("peak_nonpaged_pool", ctypes.c_size_t),
                        ("nonpaged_pool", ctypes.c_size_t), ("pagefile", ctypes.c_size_t),
                        ("peak_pagefile", ctypes.c_size_t)]
        counters = Counters()
        counters.cb = ctypes.sizeof(Counters)
        handle = int(process._handle)  # type: ignore[attr-defined]
        if ctypes.windll.psapi.GetProcessMemoryInfo(ctypes.c_void_p(handle), ctypes.byref(counters), counters.cb):
            return int(counters.peak_working_set)
    return None


def run_process(command: list[str], log: Path, timeout: float) -> dict:
    started = time.perf_counter()
    with log.open("wb") as output:
        if sys.platform.startswith("linux"):
            process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT)
            deadline = started + timeout
            while True:
                pid, status, usage = os.wait4(process.pid, os.WNOHANG)
                if pid:
                    process.returncode = os.waitstatus_to_exitcode(status)
                    return {"exit_code": process.returncode, "timed_out": False,
                            "wall_seconds": time.perf_counter() - started, "peak_rss_bytes": usage.ru_maxrss * 1024}
                if time.perf_counter() > deadline:
                    process.kill()
                    process.wait()
                    return {"exit_code": None, "timed_out": True, "wall_seconds": time.perf_counter() - started,
                            "peak_rss_bytes": None}
                time.sleep(0.02)
        process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT)
        try:
            process.wait(timeout=timeout)
            timed_out = False
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            timed_out = True
        rss = peak_rss(process)
        return {"exit_code": None if timed_out else process.returncode, "timed_out": timed_out,
                "wall_seconds": time.perf_counter() - started, "peak_rss_bytes": rss}


def command_run(arguments: argparse.Namespace) -> int:
    label = host_platform()
    registration_path = ROOT / arguments.registration
    registration = json.loads(registration_path.read_text(encoding="utf-8"))
    output = Path(arguments.output).resolve()
    (output / "cases").mkdir(parents=True, exist_ok=True)
    (output / "logs").mkdir(parents=True, exist_ok=True)
    timeout = execution_policy.watchdog_seconds("ordinary_case_seconds")
    source = source_identity()
    runtime = runtime_identity(label)
    if not runtime["source_matched_runtime"] and not arguments.allow_unmatched_runtime:
        print("STOP: native runtime is not source-matched", json.dumps(runtime, indent=2), file=sys.stderr)
        return 3
    res_registration = "res://" + Path(arguments.registration).relative_to("godot").as_posix()
    cases = expand(registration)
    if arguments.only:
        cases = [case for case in cases if re.search(arguments.only, case["case_id"])]
    jobs = [{"kind": "negative", "case_id": "negative-controls"}] + cases
    manifest = {"schema": PACKET_SCHEMA, "platform": label, "registration": arguments.registration,
                "registration_sha256": sha256_file(registration_path), "registration_id": registration["id"],
                "source": source, "runtime": runtime, "godot": godot_identity(arguments.godot),
                "machine": machine_identity(), "watchdog": {"key": "ordinary_case_seconds", "seconds": timeout,
                "policy_id": execution_policy.identity()["policy_id"], "policy_sha256": execution_policy.identity()["sha256"]},
                "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "executions": []}
    for index, job in enumerate(jobs):
        name = safe_name(job["case_id"])
        receipt_path = output / "cases" / (name + ".json")
        log_path = output / "logs" / (name + ".log")
        user = [f"--registration={res_registration}", f"--output={receipt_path.as_posix()}",
                f"--source-sha={source['head']}", f"--case-id={job['case_id']}"]
        if job.get("kind") == "negative":
            user.append("--mode=negative")
        else:
            user += [f"--scenario={job['scenario']}", f"--family={job['family']}", f"--variant={job['variant']}",
                     f"--radius={job['radius']}", f"--workers={job['workers']}", f"--lane={job['lane']}"]
        command = [arguments.godot, "--headless", "--path", str(ROOT / "godot"),
                   "--script", "res://tests/lcb_feel_case.gd", "--", *user]
        if receipt_path.exists():
            receipt_path.unlink()
        process = run_process(command, log_path, timeout)
        record = {"order": index, "case_id": job["case_id"], "receipt": receipt_path.relative_to(output).as_posix(),
                  "log": log_path.relative_to(output).as_posix(), **process,
                  "receipt_sha256": sha256_file(receipt_path) if receipt_path.exists() else None,
                  "log_sha256": sha256_file(log_path)}
        manifest["executions"].append(record)
        print(f"[{index + 1}/{len(jobs)}] {job['case_id']} exit={process['exit_code']} "
              f"{process['wall_seconds']:.1f}s rss={process['peak_rss_bytes']}", flush=True)
    manifest["finished_utc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    (output / "packet.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


# ---------------------------------------------------------------- reduction

def strict_int(value, label: str) -> int:
    if type(value) is not int:
        raise StopCondition(f"{label}: expected integer, got {type(value).__name__} {value!r}")
    return value


def strict_bool(value, label: str) -> bool:
    if type(value) is not bool:
        raise StopCondition(f"{label}: expected boolean, got {value!r}")
    return value


def normalized_water(value: int, maximum: int) -> int:
    """Independent water-normalize-v1 expectation: round at one-half of the maximum."""
    return maximum if 2 * value >= maximum else 0


def percentile(values: list[float], fraction: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, int(-(-fraction * len(ordered) // 1)) - 1))
    return ordered[index]


def evaluate_case(receipt: dict, case: dict, scenario: dict, registration: dict) -> dict:
    """Return per-case findings; raise StopCondition for an invariant breach."""
    label = case["case_id"]
    expected = scenario["expected"]
    if receipt.get("schema") != RECEIPT_SCHEMA or receipt.get("kind") != "arm":
        raise StopCondition(f"{label}: wrong receipt schema/kind")
    if receipt.get("case_id") != label:
        raise StopCondition(f"{label}: receipt case id {receipt.get('case_id')!r} differs")
    if receipt.get("outcome") != "completed":
        raise StopCondition(f"{label}: outcome {receipt.get('outcome')!r}: {receipt.get('error', '')}")
    requested = receipt["requested"]
    for key in ("family", "variant"):
        if requested[key] != case[key]:
            raise StopCondition(f"{label}: requested {key} {requested[key]!r} differs from registration")
    if strict_int(requested["radius"], label + " requested radius") != case["radius"] \
            or strict_int(requested["workers"], label + " requested workers") != case["workers"]:
        raise StopCondition(f"{label}: requested geometry/workers differ from registration")
    if receipt["fixture"]["definition_hash"] != scenario["definition_hash"] or receipt["fixture"]["id"] != scenario["fixture_id"]:
        raise StopCondition(f"{label}: fixture identity differs")
    applied = receipt["applied"]
    material = registration["material"]
    defaults = {entry["material"]: (entry["applied_family"], entry["applied_variant"]) for entry in receipt["default_policy"]}
    seen = set()
    for entry in applied["assignments"]:
        key = strict_int(entry["material"], label + " assignment material")
        seen.add(key)
        actual = (entry["applied_family"], entry["applied_variant"])
        wanted = (case["family"], case["variant"]) if key == material else defaults.get(key)
        if actual != wanted:
            raise StopCondition(f"{label}: material {key} applied {actual}, expected {wanted} (silent fallback or leak)")
    if seen != set(defaults):
        raise StopCondition(f"{label}: applied assignment set differs from the default catalogue")
    if strict_int(applied["maximum_rule_radius"], label + " applied radius") != case["radius"] \
            or strict_int(receipt["construction"]["maximum_rule_radius"], label + " receipt radius") != case["radius"]:
        raise StopCondition(f"{label}: applied radius differs from requested")
    if strict_int(applied["configured_workers"], label + " configured workers") != case["workers"] \
            or strict_int(receipt["construction"]["worker_threads"], label + " receipt workers") != case["workers"]:
        raise StopCondition(f"{label}: configured workers differ from requested")
    if receipt["construction"]["run_intent"] != "controlled":
        raise StopCondition(f"{label}: run intent is not controlled")
    normalization = receipt["construction"]["normalization"]
    if normalization.get("rule") != registration["normalization"]:
        raise StopCondition(f"{label}: normalization rule not applied")
    for key in ("net_delta", "positive_delta", "negative_delta"):
        if strict_int(normalization[key], f"{label} normalization {key}") != expected["normalization_net_delta"]:
            raise StopCondition(f"{label}: normalization {key} {normalization[key]} differs from registration")
    initial_quantity = expected["initial_water_quantity"]
    if strict_int(normalization["water_after"], label + " normalized water") != initial_quantity:
        raise StopCondition(f"{label}: normalized Water {normalization['water_after']} != {initial_quantity}")
    horizon = registration["horizon_ticks"]
    for census_name in ("initial", "final"):
        census = receipt[census_name]
        water = census["water"]
        if strict_int(water["quantity"], f"{label} {census_name} quantity") != initial_quantity:
            raise StopCondition(f"{label}: {census_name} Water {water['quantity']} != {initial_quantity}")
        if strict_int(water["visible"], label) + strict_int(water["overfill"], label) != water["quantity"]:
            raise StopCondition(f"{label}: visible+overfill differs from quantity")
        inventory = census["inventory"]
        if not strict_bool(inventory["complete"], label + " inventory complete"):
            raise StopCondition(f"{label}: {census_name} inventory incomplete")
        counts = {int(key): strict_int(value, label + " count") for key, value in inventory["counts"].items()}
        if sum(counts.values()) != 1024 * 1024:
            raise StopCondition(f"{label}: {census_name} inventory does not cover the World")
        unexpected = sorted(set(counts) - set(expected["allowed_materials"]))
        if unexpected:
            raise StopCondition(f"{label}: {census_name} inventory contains unregistered materials {unexpected}")
        health = census["health"]
        if strict_bool(health["failed"], label) or strict_int(health["tick_failure_count"], label) != 0 or health["last_tick_error"]:
            raise StopCondition(f"{label}: {census_name} World health failure")
        inertial = census["inertial"]
        if case["family"] == "inertial_cellular_v1":
            if not inertial.get("available") or not strict_bool(inertial["complete"], label):
                raise StopCondition(f"{label}: inertial census unavailable or incomplete")
            if strict_int(inertial["negative_vy_cells"], label) != 0:
                raise StopCondition(f"{label}: negative inertial vertical velocity present")
            if strict_int(inertial["inertial_cells"], label) != strict_int(water["water_cells"], label):
                raise StopCondition(f"{label}: inertial cell count differs from Water cells")
        elif inertial.get("available"):
            raise StopCondition(f"{label}: inertial state present on a non-inertial Water arm")
        pressure = census["pressure"]
        if case["family"] == "pressure_flow_v1":
            if not pressure.get("available") or not strict_bool(pressure["gas_ledger_closes"], label):
                raise StopCondition(f"{label}: pressure ledger unavailable or gas ledger does not close")
        elif pressure.get("available"):
            raise StopCondition(f"{label}: pressure state present on a non-pressure Water arm")
    wall_delta = receipt["final"]["inventory"]["counts"].get("1", 0) - receipt["initial"]["inventory"]["counts"].get("1", 0)
    if wall_delta != expected["wall_delta_after_tick_zero_events"]:
        raise StopCondition(f"{label}: Wall changed by {wall_delta}, registered {expected['wall_delta_after_tick_zero_events']}")
    ticks = receipt["ticks"]
    if len(ticks) != horizon or [strict_int(t["tick"], label) for t in ticks] != list(range(1, horizon + 1)):
        raise StopCondition(f"{label}: completed tick sequence differs from horizon {horizon}")
    for tick in ticks:
        if strict_int(tick["water_quantity"], label) != initial_quantity or strict_bool(tick["failed"], label):
            raise StopCondition(f"{label}: tick {tick['tick']} Water {tick['water_quantity']} or failure")
    final_health = receipt["final"]["health"]
    if strict_int(final_health["attempted_tick"], label) != horizon or strict_int(final_health["tick_index"], label) != horizon:
        raise StopCondition(f"{label}: attempted/completed ticks differ from horizon")
    ledger = receipt["host_ledger"]
    if strict_int(ledger["source"], label) != expected["water_sources"] or strict_int(ledger["sink"], label) != expected["water_sinks"]:
        raise StopCondition(f"{label}: explicit Water source/sink differ from registration")
    if not strict_bool(receipt["retirement"]["world_released"], label):
        raise StopCondition(f"{label}: World owner not retired")
    observed = [strict_int(t["worker_threads_observed"], label) for t in ticks]
    if case["workers"] == 1 and max(observed) > 1:
        raise StopCondition(f"{label}: one configured worker but {max(observed)} claimants observed")
    native = [float(t["native_tick_ms"]) for t in ticks]
    host = [strict_int(t["host_advance_us"], label) / 1000.0 for t in ticks]
    jobs = [sum(strict_int(job, label) for job in t["phase_jobs"]) for t in ticks]
    return {
        "case_id": label, "scenario": case["scenario"], "lane": case["lane"], "role": case["role"],
        "family": case["family"], "variant": case["variant"], "radius": case["radius"], "workers": case["workers"],
        "policy_hash": applied["policy_hash"], "construction_receipt": receipt["construction"]["receipt_hash"],
        "physical_state_hash_version": applied["physical_state_hash_version"],
        "initial_physical_hash": receipt["initial"]["physical_state_hash"],
        "final_physical_hash": receipt["final"]["physical_state_hash"],
        "tick_hashes": [t["physical_state_hash"] for t in ticks],
        "water_quantity": initial_quantity, "final_water_cells": receipt["final"]["water"]["water_cells"],
        "final_inventory": receipt["final"]["inventory"]["counts"],
        "inertial": {key: receipt["final"]["inertial"].get(key) for key in
                     ("moving_cells", "nonzero_accumulator_cells", "sum_abs_vx", "sum_vy", "max_abs_vx", "max_vy", "tuple_sha256")}
        if receipt["final"]["inertial"].get("available") else None,
        "pressure": {"ledger": receipt["final"]["pressure"]["ledger"], "gas_ledger": receipt["final"]["pressure"]["gas_ledger"],
                     "compartments": receipt["final"]["pressure"]["compartments"]}
        if receipt["final"]["pressure"].get("available") else None,
        "max_observed_claimants": max(observed), "ticks_with_multiple_claimants": sum(1 for v in observed if v > 1),
        "phase_jobs_first_tick": ticks[0]["phase_jobs"], "phase_jobs_last_tick": ticks[-1]["phase_jobs"],
        "max_phase_jobs_per_tick": max(jobs),
        "parallel_phases_max": max(strict_int(t["scheduler_parallel_phases"], label) for t in ticks),
        "native_tick_ms": {"p50": percentile(native, 0.5), "p95": percentile(native, 0.95), "max": max(native), "sum": sum(native)},
        "host_advance_ms": {"p50": percentile(host, 0.5), "p95": percentile(host, 0.95), "max": max(host)},
        "construction_ms": strict_int(receipt["construction_us"], label) / 1000.0,
        "moved_cells_total": sum(strict_int(t["moved_cells"], label) for t in ticks),
        "chunk_allocations_total": sum(strict_int(t["chunk_allocations"], label) for t in ticks),
        "normalization": {key: normalization[key] for key in ("water_before", "water_after", "positive_delta", "negative_delta", "net_delta")},
    }


def evaluate_negative(receipt: dict) -> list[dict]:
    if receipt.get("schema") != RECEIPT_SCHEMA or receipt.get("kind") != "negative" or receipt.get("outcome") != "completed":
        raise StopCondition("negative controls: wrong schema or incomplete")
    if not strict_bool(receipt["baseline_installed"], "negative baseline"):
        raise StopCondition("negative controls: Current baseline did not install")
    results = []
    controls = {control["id"]: control for control in receipt["controls"]}
    for identifier in ("inertial-water-radius-2", "fractional-without-normalization-cellular_yield_v1",
                       "fractional-without-normalization-inertial_cellular_v1"):
        control = controls.get(identifier)
        if control is None:
            raise StopCondition(f"negative control {identifier} missing")
        if strict_bool(control["accepted"], identifier) or not strict_bool(control["previous_world_retained"], identifier):
            raise StopCondition(f"negative control {identifier}: accepted or did not retain the previous World")
        results.append({"id": identifier, "refused": True, "previous_world_retained": True,
                        "refusal": control.get("refusal") or control.get("error")})
    normalized = controls.get("fractional-with-normalization-cellular_yield_v1")
    if normalized is None or not strict_bool(normalized["accepted"], "normalized fractional"):
        raise StopCondition("negative control: explicit normalization of the fractional fill was refused")
    cells, value, maximum = (strict_int(normalized[key], "normalized fractional") for key in
                             ("cells", "requested_fill_numerator_per_cell", "maximum"))
    expected_after = normalized_water(value, maximum) * cells
    actual = normalized["normalization"]
    expected_positive = max(0, expected_after - value * cells)
    expected_negative = max(0, value * cells - expected_after)
    if (strict_int(actual["water_before"], "norm before"), strict_int(actual["water_after"], "norm after"),
            strict_int(actual["positive_delta"], "norm +"), strict_int(actual["negative_delta"], "norm -")) != \
            (value * cells, expected_after, expected_positive, expected_negative):
        raise StopCondition(f"negative control: normalization deltas {actual} differ from independent expectation")
    results.append({"id": "fractional-with-normalization-cellular_yield_v1", "accepted": True,
                    "independent_expectation": {"water_before": value * cells, "water_after": expected_after,
                                                "positive_delta": expected_positive, "negative_delta": expected_negative}})
    for material in (16, 24):
        control = controls.get(f"pressure-for-material-{material}")
        if control is None or any(strict_bool(entry["accepted"], "pressure offer") for entry in control["offered"]):
            raise StopCondition(f"negative control: pressure admitted for material {material}")
        results.append({"id": control["id"], "refused_or_absent": True, "offered": len(control["offered"])})
    catalogue = controls.get("water-variant-catalogue")
    if catalogue is None:
        raise StopCondition("negative control: Water variant catalogue missing")
    for entry in catalogue["offered"]:
        if entry["variant"] != "reference" and entry["family"] != "pressure_flow_v1":
            raise StopCondition(f"negative control: optimisation variant offered for {entry['family']}")
    results.append({"id": "water-variant-catalogue", "offered": catalogue["offered"]})
    return results


def load_packet(directory: Path, registration_path: Path, development: bool = False) -> dict:
    manifest = json.loads((directory / "packet.json").read_text(encoding="utf-8"))
    if manifest.get("schema") != PACKET_SCHEMA:
        raise StopCondition(f"{directory}: wrong packet schema")
    if manifest["registration_sha256"] != sha256_file(registration_path):
        raise StopCondition(f"{directory}: registration bytes differ from the reduced registration")
    runtime = manifest["runtime"]
    if not runtime["source_matched_runtime"] or not runtime["native_matches_provenance"]:
        raise StopCondition(f"{directory}: executed native runtime was not source-matched")
    if not manifest["source"]["executed_tree_matches_head"] and not development:
        raise StopCondition(f"{directory}: executed tree had uncommitted source changes {manifest['source']['dirty_source_paths']}")
    receipts = {}
    for execution in manifest["executions"]:
        if execution["timed_out"] or execution["exit_code"] != 0:
            raise StopCondition(f"{directory}: {execution['case_id']} process exit {execution['exit_code']} timeout={execution['timed_out']}")
        path = directory / execution["receipt"]
        if sha256_file(path) != execution["receipt_sha256"] or sha256_file(directory / execution["log"]) != execution["log_sha256"]:
            raise StopCondition(f"{directory}: {execution['case_id']} raw file hash differs from manifest")
        receipt = json.loads(path.read_text(encoding="utf-8"))
        if receipt.get("source_sha_argument") != manifest["source"]["head"]:
            raise StopCondition(f"{directory}: {execution['case_id']} executed a different source argument")
        version = receipt.get("godot_version", {})
        if not isinstance(version, dict) or f"{version.get('major')}.{version.get('minor')}." not in manifest["godot"]["version"]                 or str(version.get("hash", ""))[:9] not in manifest["godot"]["version"]:
            raise StopCondition(f"{directory}: {execution['case_id']} Godot version differs from manifest")
        if execution["case_id"] in receipts:
            raise StopCondition(f"{directory}: duplicate execution {execution['case_id']}")
        receipts[execution["case_id"]] = receipt
    return {"manifest": manifest, "receipts": receipts}


def reduce_packets(registration_path: Path, directories: list[Path], development: bool = False) -> dict:
    registration = json.loads(registration_path.read_text(encoding="utf-8"))
    scenarios = {scenario["id"]: scenario for scenario in registration["scenarios"]}
    expected_cases = expand(registration)
    platforms = {}
    for directory in directories:
        packet = load_packet(directory, registration_path, development)
        label = packet["manifest"]["platform"]
        if label in platforms:
            raise StopCondition(f"duplicate platform packet {label}")
        missing = sorted({case["case_id"] for case in expected_cases} - set(packet["receipts"]))
        extra = sorted(set(packet["receipts"]) - {case["case_id"] for case in expected_cases} - {"negative-controls"})
        if missing or extra or "negative-controls" not in packet["receipts"]:
            raise StopCondition(f"{label}: missing {missing}, unregistered {extra}")
        cases = [evaluate_case(packet["receipts"][case["case_id"]], case, scenarios[case["scenario"]], registration)
                 for case in expected_cases]
        by_id = {case["case_id"]: case for case in cases}
        parity = []
        for case in expected_cases:
            if case["workers"] != 1:
                continue
            one = by_id[case["case_id"]]
            for workers in registration["workers"][1:]:
                other = by_id[case_id(case["scenario"], case, workers)]
                fields = ("tick_hashes", "final_physical_hash", "final_inventory", "inertial", "pressure", "final_water_cells")
                differing = [field for field in fields if one[field] != other[field]]
                if differing:
                    raise StopCondition(f"{label}: worker divergence {case['case_id']} vs w{workers}: {differing}")
                parity.append({"arm": one["case_id"].rsplit("|", 1)[0], "workers": [1, workers], "identical": fields,
                               "final_physical_hash": one["final_physical_hash"]})
        platforms[label] = {"identity": {key: packet["manifest"][key] for key in ("source", "runtime", "godot", "machine", "watchdog",
                                                                                   "started_utc", "finished_utc")},
                            "executions": [{key: execution[key] for key in ("order", "case_id", "exit_code", "timed_out",
                                            "wall_seconds", "peak_rss_bytes", "receipt_sha256", "log_sha256")}
                                           for execution in packet["manifest"]["executions"]],
                            "cases": cases, "worker_parity": parity,
                            "negative_controls": evaluate_negative(packet["receipts"]["negative-controls"])}
    cross = []
    if len(platforms) > 1:
        labels = sorted(platforms)
        first = {case["case_id"]: case for case in platforms[labels[0]]["cases"]}
        for other_label in labels[1:]:
            for case in platforms[other_label]["cases"]:
                base = first[case["case_id"]]
                cross.append({"case_id": case["case_id"], "platforms": [labels[0], other_label],
                              "final_physical_hash_equal": base["final_physical_hash"] == case["final_physical_hash"],
                              "tick_hashes_equal": base["tick_hashes"] == case["tick_hashes"]})
    primary = [case for case in expected_cases if case["role"] == "primary"]
    return {"schema": SUMMARY_SCHEMA, "registration": registration["id"],
            "registration_sha256": sha256_file(registration_path),
            "primary_rows_per_platform": len(primary), "platforms": platforms,
            "primary_rows_total": len(primary) * len(platforms),
            "cross_platform_observation": cross,
            "verdict": "DEVELOPMENT_NONQUALIFYING" if development else
            ("ADMITTED" if set(platforms) == set(registration["platforms"]) else "PARTIAL_PLATFORMS")}


def command_reduce(arguments: argparse.Namespace) -> int:
    try:
        summary = reduce_packets(ROOT / arguments.registration, [Path(path) for path in arguments.packet],
                                 arguments.development)
    except StopCondition as error:
        print("STOP:", error, file=sys.stderr)
        return 1
    text = json.dumps(summary, indent=2, sort_keys=True) + "\n"
    if arguments.output:
        Path(arguments.output).write_text(text, encoding="utf-8")
    print(f"{summary['verdict']}: {summary['primary_rows_total']} primary rows on {sorted(summary['platforms'])}")
    for label, value in sorted(summary["platforms"].items()):
        for case in value["cases"]:
            print(f"  {label} {case['case_id']} claimants={case['max_observed_claimants']} "
                  f"jobs={case['max_phase_jobs_per_tick']} tick_p50={case['native_tick_ms']['p50']:.2f}ms hash={case['final_physical_hash']}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    run = commands.add_parser("run")
    run.add_argument("--godot", required=True)
    run.add_argument("--output", required=True)
    run.add_argument("--registration", default=DEFAULT_REGISTRATION)
    run.add_argument("--only", default="", help="regular expression subset for development; never a qualifying packet")
    run.add_argument("--allow-unmatched-runtime", action="store_true", help="development only; reduce refuses the packet")
    run.set_defaults(handler=command_run)
    reduce = commands.add_parser("reduce")
    reduce.add_argument("--registration", default=DEFAULT_REGISTRATION)
    reduce.add_argument("--packet", action="append", required=True)
    reduce.add_argument("--output", default="")
    reduce.add_argument("--development", action="store_true",
                        help="accept an uncommitted executed tree; the verdict is DEVELOPMENT_NONQUALIFYING")
    reduce.set_defaults(handler=command_reduce)
    arguments = parser.parse_args(argv)
    return arguments.handler(arguments)


if __name__ == "__main__":
    raise SystemExit(main())
