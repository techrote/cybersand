"""PACE004 successor execution identity, separate from its frozen experiment."""
from __future__ import annotations

import ctypes
from contextlib import contextmanager
from functools import wraps
import math
import os
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
import execution_policy as policy
from play_execution_contract import GODOT_KEYS, _same

SCHEMA = "play-pace004-execution-v2"
_OPERATION_DEADLINE: float | None = None


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def usec(key: str) -> int:
    return policy.watchdog_microseconds(key)


def case_seconds(graphical: bool = False) -> int:
    return math.ceil(policy.case_seconds("test_play_pace004_input_tape", graphical))


def operation_remaining() -> float:
    allowance = policy.watchdog_seconds("operation_seconds")
    remaining = allowance if _OPERATION_DEADLINE is None else _OPERATION_DEADLINE - time.monotonic()
    if remaining <= 0:
        raise TimeoutError("PACE004 operation exhausted its shared execution allowance")
    return remaining


@contextmanager
def operation_budget():
    global _OPERATION_DEADLINE
    previous = _OPERATION_DEADLINE
    deadline = time.monotonic() + policy.watchdog_seconds("operation_seconds")
    _OPERATION_DEADLINE = deadline if previous is None else min(previous, deadline)
    try:
        operation_remaining()
        yield
        operation_remaining()
    finally:
        _OPERATION_DEADLINE = previous


def bounded_operation(function):
    @wraps(function)
    def bounded(*args, **kwargs):
        with operation_budget():
            return function(*args, **kwargs)
    return bounded


def case_observation_seconds(graphical: bool = False) -> int:
    return math.ceil(case_seconds(graphical) + policy.godot_process_cleanup_seconds())


def fixture_policy_matches(value: object) -> bool:
    expected = policy.identity()
    return (isinstance(value, dict) and value.get("ok") is True
            and value.get("path") == "res://tests/support/ci_execution_policy.json"
            and value.get("sha256") == expected["sha256"]
            and _same(value.get("schema_version"), expected["schema_version"])
            and _same(value.get("scale"), expected["scale"])
            and isinstance(value.get("watchdogs"), dict)
            and all(_same(value["watchdogs"].get(key), expected["watchdogs"][key]) for key in GODOT_KEYS))


def budgets(cases: int) -> dict:
    require(type(cases) is int and 1 <= cases <= 2, "PACE004 shards contain one or two cases")
    values = policy.identity()["watchdogs"]
    process = case_seconds()
    cleanup = policy.godot_process_cleanup_seconds()
    per_case = process + cleanup + values["operation_seconds"]
    # Source preflight, cached telemetry identity and source postflight each
    # have one shared operation clock. Import receipt collection, final readback
    # and artifact sealing are separate operations; every case also retains its
    # own readback/retirement allowance.
    metadata = 3 * values["operation_seconds"]
    suite = math.ceil(cases * per_case + values["godot_import_seconds"] + cleanup
                      + metadata + 3 * values["operation_seconds"] + values["aggregate_headroom_seconds"])
    dependencies = math.ceil(2 * values["dependency_prepare_seconds"])
    dependency_stage = dependencies + math.ceil(values["operation_seconds"] + values["terminate_grace_seconds"])
    suite_minutes = math.ceil(suite / 60)
    dependency_minutes = math.ceil(dependency_stage / 60)
    readback_minutes = math.ceil((values["operation_seconds"] + values["terminate_grace_seconds"]) / 60)
    # Workflow setup: checkout, Python and Windows Git configuration, 5m each.
    # Artifact upload has its own 10m allowance, outside all test/readback time.
    setup_minutes, artifact_minutes = 15, 10
    sequential_minutes = suite_minutes + dependency_minutes + readback_minutes + setup_minutes + artifact_minutes
    job = max(math.ceil(values["hosted_job_minutes"]),
              math.ceil(sequential_minutes / 10) * 10)
    require(job <= 360, "PACE004 shard budget exceeds hosted job capacity; reduce shard size")
    return {"schema":SCHEMA, "case_count":cases, "case_seconds":process,
            "import_seconds":math.ceil(values["godot_import_seconds"]),
            "process_cleanup_seconds":math.ceil(cleanup),
            "import_readback_seconds":math.ceil(values["operation_seconds"]),
            "case_with_readback_seconds":math.ceil(per_case), "metadata_seconds":math.ceil(metadata),
            "suite_seconds":suite, "suite_minutes":suite_minutes,
            "dependency_seconds_each":math.ceil(values["dependency_prepare_seconds"]),
            "dependency_stage_minutes":dependency_minutes, "readback_minutes":readback_minutes,
            "setup_minutes":setup_minutes, "artifact_minutes":artifact_minutes,
            "sequential_stage_minutes":sequential_minutes,
            "job_minutes":job, "execution_policy":policy.identity()}


def inventory_budgets(shards: int) -> dict:
    require(type(shards) is int and shards > 0, "PACE004 inventory needs every registered shard")
    values = policy.identity()["watchdogs"]
    readback = math.ceil((shards * values["operation_seconds"] + values["aggregate_headroom_seconds"]) / 60)
    # Checkout/Python 10m, original retrieval 60m, required-job gate 5m, upload 10m.
    parent = max(math.ceil(values["hosted_job_minutes"]), math.ceil((readback + 85) / 10) * 10)
    require(parent <= 360, "PACE004 complete inventory exceeds hosted job capacity; split its readback before enlarging policy")
    return {"shards":shards, "readback_minutes":readback, "job_minutes":parent}


def pid_state(pid: int, platform_name: str = sys.platform) -> str:
    """Read-only absence/exit observation. Never kill a PID based on this probe."""
    require(type(pid) is int and pid > 0, "Invalid cleanup PID")
    if platform_name == "win32":
        api = ctypes.WinDLL("kernel32", use_last_error=True)
        api.OpenProcess.argtypes = [ctypes.c_uint32, ctypes.c_int, ctypes.c_uint32]
        api.OpenProcess.restype = ctypes.c_void_p
        api.WaitForSingleObject.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
        api.WaitForSingleObject.restype = ctypes.c_uint32
        api.CloseHandle.argtypes = [ctypes.c_void_p]
        handle = api.OpenProcess(0x100000, False, pid)
        if not handle:
            return "absent" if ctypes.get_last_error() == 87 else "unobserved"
        try:
            waited = api.WaitForSingleObject(handle, 0)
            return "exited" if waited == 0 else "active" if waited == 258 else "unobserved"
        finally:
            api.CloseHandle(handle)
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return "absent"
    except (PermissionError, OSError):
        return "unobserved"
    return "active"


def cleanup_receipt(process: dict, result: dict | None, source: str, nonce: str,
                    fixture_hash: str, probe_hash: str, engine_hash: str, *, inspect=pid_state) -> dict:
    # A failed assertion may still complete a real retirement. A timeout,
    # missing footer or unobserved process cannot authorize the next case.
    result = result or {}
    bound = (result.get("schema") == "play-pace004-v2"
             and result.get("source_revision") == source and result.get("process_nonce") == nonce
             and result.get("fixture_sha256") == fixture_hash and result.get("probe_sha256") == probe_hash
             and result.get("engine_sha256") == engine_hash
             and fixture_policy_matches(result.get("execution_policy")))
    have_pids = all(type(pid) is int and pid > 0
                    for pid in (process.get("pid"), result.get("process_id")))
    pids = sorted({pid for pid in (process.get("pid"), result.get("process_id"))
                   if type(pid) is int and pid > 0})
    observations = [{"pid":pid, "state":inspect(pid)} for pid in pids]
    safe = (bound and process.get("natural_completion") is True
            and type(process.get("returncode")) is int
            and _same(process.get("execution_policy"), policy.identity())
            and result.get("worker_joined") is True and type(result.get("sessions_retired")) is int
            and result["sessions_retired"] == 1 and have_pids
            and all(row["state"] in ("absent", "exited") for row in observations))
    return {"schema":"play-pace004-cleanup-v1", "source_bound_footer":bound,
            "natural_completion":process.get("natural_completion") is True,
            "worker_joined":result.get("worker_joined") is True,
            "sessions_retired":result.get("sessions_retired"), "engine_and_wrapper_pids_present":have_pids,
            "processes":observations,
            "checked_unix_seconds":time.time(), "safe_to_continue":safe,
            "scope":"fixture owner retirement and observed engine/wrapper exit; no invented descendant inventory"}


def verify_cleanup(receipt: dict, process: dict, result: dict, source: str, nonce: str,
                   fixture_hash: str, probe_hash: str, engine_hash: str) -> None:
    states = {row["pid"]:row["state"] for row in receipt.get("processes", [])}
    expected = cleanup_receipt(process, result, source, nonce, fixture_hash, probe_hash, engine_hash,
                               inspect=lambda pid:states.get(pid, "unobserved"))
    expected["checked_unix_seconds"] = receipt.get("checked_unix_seconds")
    require(type(expected["checked_unix_seconds"]) in (int, float)
            and math.isfinite(expected["checked_unix_seconds"])
            and expected["checked_unix_seconds"] > 0 and receipt == expected
            and receipt["safe_to_continue"], "PACE004 cleanup was not source-bound and observed")
