"""Deterministic scheduling hints and admission at the hosted safety boundary.

The committed snapshot is optional evidence, never a live service dependency.
Changing estimates cannot change any correctness watchdog or case inventory.
"""

import functools
import hashlib
import math
import os
from pathlib import Path
import statistics
import subprocess
import time

import execution_policy
import execution_telemetry
import performance_history

ROOT = execution_policy.ROOT
PROFILE = ROOT / "tools/ci/godot_scheduling_profile.json"
ALGORITHM = "expected-cost-lpt-v2"
TARGET_CASE_SECONDS = 300
MAX_CASES_PER_SHARD = 16
UNKNOWN_SECONDS = 15.0
ESTIMATE_MARGIN = 1.5


def finite_positive(value) -> bool:
    return type(value) in (int, float) and math.isfinite(value) and value > 0


def execution_seconds(*, hosted: bool = True) -> int:
    values = execution_policy.identity()["watchdogs"]
    parent = values["godot_job_minutes"] * 60
    if hosted and parent > 360 * 60:
        raise ValueError("Scaled Godot job exceeds the GitHub-hosted six-hour limit")
    available = parent - values["godot_setup_seconds"] - values["aggregate_headroom_seconds"]
    if available <= 0:
        raise ValueError("Setup and headroom consume the hosted job")
    return math.floor(available)


def case_allowance(timeout: float, *, readback: bool = True) -> float:
    if not finite_positive(timeout):
        raise ValueError("Case watchdog must be finite and positive")
    return timeout + execution_policy.godot_process_cleanup_seconds() + (
        execution_policy.watchdog_seconds("operation_seconds") if readback else 0)


class ExecutionBudget:
    """Admit a child only when its entire ceiling and final evidence fit.

    A child is never given a shortened timeout. The external job/step watchdog
    remains the ultimate boundary if the harness itself stops making progress.
    """

    def __init__(self, seconds: float | None = None, *, started: float | None = None):
        # Local policy scaling is intentionally supported. Only GitHub-hosted
        # parents have the six-hour service boundary; CI pins scale=1 separately.
        maximum = execution_seconds(hosted=os.environ.get("GITHUB_ACTIONS") == "true")
        self.seconds = maximum if seconds is None else seconds
        if not finite_positive(self.seconds) or self.seconds > maximum:
            raise ValueError("Execution budget must be positive and fit the hosted envelope")
        self.started = time.monotonic() if started is None else started
        self.terminal_reserve = execution_policy.watchdog_seconds("godot_metadata_seconds")

    def remaining(self) -> float:
        return self.seconds - (time.monotonic() - self.started)

    def admission(self, timeout: float, *, readback: bool = True) -> dict:
        needed = case_allowance(timeout, readback=readback) + self.terminal_reserve
        remaining = self.remaining()
        return {"admitted": remaining >= needed, "remaining_seconds": round(remaining, 3),
                "required_seconds": needed, "terminal_reserve_seconds": self.terminal_reserve}

    def metadata(self) -> dict:
        return {"execution_seconds": self.seconds, "terminal_reserve_seconds": self.terminal_reserve,
                "admission": "full-case-watchdog-plus-readback-cleanup-and-terminal-reserve"}


@functools.lru_cache(maxsize=8)
def source_signature(root: Path) -> str:
    """Conservative fixture-dependency identity.

    Any production Godot/native source, asset or dependency pin change invalidates
    history. Each fixture's own bytes are checked separately too. Documentation and
    scheduler edits need not invalidate otherwise comparable execution samples.
    """
    if (root / ".git").exists():
        paths = subprocess.check_output(["git", "-C", str(root), "ls-files", "-z", "--",
            "native/include", "native/src", "third_party", "godot"],
            timeout=execution_policy.watchdog_seconds("operation_seconds")).decode().split("\0")
        files = {root / path for path in paths if path}
    else:
        # Synthetic roots and source archives have no generated checkout state.
        files = {path for directory in ("native/include", "native/src", "third_party", "godot")
                 for path in (root / directory).rglob("*") if path.is_file()}
    files = {path for path in files if ".godot" not in path.relative_to(root).parts
             and "bin" not in path.relative_to(root).parts}
    digest = hashlib.sha256()
    # Path ordering differs between Windows and POSIX. Sort canonical strings.
    for path in sorted(files, key=lambda item: item.relative_to(root).as_posix()):
        digest.update(path.relative_to(root).as_posix().encode() + b"\0")
        content = path.read_bytes()
        if b"\0" not in content:
            content = content.replace(b"\r\n", b"\n")
        digest.update(hashlib.sha256(content).digest())
    return digest.hexdigest()


def load_profile(path: Path = PROFILE) -> dict:
    try:
        result = performance_history.strict_json(path.read_bytes())
        if not isinstance(result, dict) or result.get("schema") != "godot-scheduling-history-v1":
            return {"unavailable": "unsupported_profile"}
        if not isinstance(result.get("observations"), list) or not isinstance(result.get("platform_cohorts"), dict):
            return {"unavailable": "invalid_profile"}
        if performance_history.timestamp(result.get("as_of_utc")) is None:
            return {"unavailable": "invalid_profile_date"}
        return result
    except FileNotFoundError:
        return {"unavailable": "missing_profile"}
    except (OSError, ValueError, TypeError):
        return {"unavailable": "invalid_profile"}


def estimate(name: str, fallback: float, profile: dict, *, root: Path = ROOT) -> tuple[float, str]:
    """Use robust history only when both required platform cohorts qualify.

    A rolling median of >=3 distinct successful runs on each platform prevents a
    single slow infrastructure observation training the planner. Take the larger
    platform estimate so planning and both source-derived reducers are identical.
    Staleness is relative to the committed snapshot date, not wall-clock time.
    """
    if not finite_positive(fallback):
        raise ValueError("Scheduling fallback must be finite and positive")
    if profile.get("unavailable"):
        return fallback, profile["unavailable"]
    as_of = performance_history.timestamp(profile.get("as_of_utc"))
    if as_of is None:
        return fallback, "invalid_profile_date"
    if not profile.get("observations"):
        return fallback, "insufficient_comparable_history"
    cohorts = profile.get("platform_cohorts", {})
    if not isinstance(cohorts, dict) or not isinstance(cohorts.get(name), dict):
        return fallback, "invalid_fixture_cohorts"
    fixture_hash = execution_telemetry.digest(root / "godot/tests" / (name + ".gd"))
    if fixture_hash is None:
        return fallback, "fixture_without_comparable_definition"
    try:
        signature = source_signature(root)
    except (OSError, subprocess.SubprocessError):
        return fallback, "source_identity_unavailable"
    samples = {"Linux": {}, "Windows": {}}
    for row in profile.get("observations", []):
        if not isinstance(row, dict) or row.get("fixture") != name:
            continue
        try:
            if performance_history.comparison_issues(row):
                continue
            platform = row["host"]["platform"]
            recorded = performance_history.timestamp(row.get("recorded_utc"))
            if (platform not in samples or recorded is None or not 0 <= as_of - recorded <= 30 * 86400
                    or row.get("phase") != "case" or row.get("fixture_sha256") != fixture_hash
                    or row.get("source_input_sha256") != signature
                    or execution_telemetry.cohort(row) != cohorts[name].get(platform)):
                continue
            key = performance_history.positive_id(row["source"]["run_id"])
            # Duplicate samples from one run are not independent observations.
            if key in samples[platform]:
                samples[platform][key] = None
            else:
                samples[platform][key] = (recorded, row["wall_seconds"])
        except (KeyError, TypeError, ValueError, OverflowError):
            continue
    estimates = []
    for platform in samples:
        window = sorted(value for value in samples[platform].values() if value is not None)[-10:]
        if len(window) < 3:
            return fallback, "insufficient_comparable_history"
        estimates.append(statistics.median(value[1] for value in window) * ESTIMATE_MARGIN)
    return max(fallback, *estimates), "comparable_rolling_median"


def profile_identity(path: Path = PROFILE) -> dict:
    return {"path": path.name, "sha256": execution_telemetry.digest(path),
            "algorithm": ALGORITHM, "target_case_seconds": TARGET_CASE_SECONDS,
            "max_cases_per_shard": MAX_CASES_PER_SHARD, "unknown_seconds": UNKNOWN_SECONDS,
            "estimate_margin": ESTIMATE_MARGIN}
