"""Source-bound timing observations with explicit unknowns and comparable cohorts.

This module records observations; it never decides functional acceptance. Raw
Godot/native evidence and their independent correctness readers remain authority.
"""

from datetime import datetime, timezone
import functools
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import subprocess
import time

import execution_policy

SCHEMA = "execution-performance-v1"


def digest(path: Path) -> str | None:
    if not path.is_file():
        return None
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


@functools.lru_cache(maxsize=8)
def source_identity(root: Path) -> dict:
    deadline = time.monotonic() + execution_policy.watchdog_seconds("operation_seconds")
    def git(*args):
        try:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return None
            return subprocess.check_output(["git", "-C", str(root), *args],
                timeout=remaining,
                stderr=subprocess.DEVNULL).decode().strip()
        except (OSError, subprocess.SubprocessError):
            return None
    diff = git("diff", "--binary", "HEAD")
    return {"commit": git("rev-parse", "HEAD"), "tree": git("rev-parse", "HEAD^{tree}"),
            "tracked_delta_sha256": hashlib.sha256(diff.encode()).hexdigest() if diff else None,
            "run_id": os.environ.get("GITHUB_RUN_ID"),
            "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
            "job": os.environ.get("GITHUB_JOB"),
            "runner_name_sha256": hashlib.sha256(os.environ["RUNNER_NAME"].encode()).hexdigest()
                if os.environ.get("RUNNER_NAME") else None}


@functools.lru_cache(maxsize=1)
def host_identity() -> dict:
    cpu = "unknown"
    if Path("/proc/cpuinfo").exists():
        match = re.search(r"^model name\s*:\s*(.+)$", Path("/proc/cpuinfo").read_text(), re.M)
        if match:
            cpu = match[1].strip()
    if platform.system() == "Windows":
        cpu = os.environ.get("PROCESSOR_IDENTIFIER", cpu)
    # A hostname is deliberately not needed for comparisons. Historical external
    # provider data cannot enter the GitHub-hosted cohort by an absent field.
    hosted = os.environ.get("GITHUB_ACTIONS") == "true" and os.environ.get("RUNNER_ENVIRONMENT") == "github-hosted"
    return {"platform": platform.system(), "os": " ".join((platform.system(), platform.release(), platform.version())),
            "architecture": platform.machine(), "cpu_model": cpu,
            "logical_cpu_count": os.cpu_count(),
            "runner_class": "github-hosted" if hosted else "local-or-unknown",
            "runner_environment": os.environ.get("RUNNER_ENVIRONMENT", "unknown"),
            "runner_image": os.environ.get("ImageOS", "unknown"),
            "runner_image_version": os.environ.get("ImageVersion", "unknown"),
            "hardware_cohort": "github-hosted" if hosted else "local-or-unknown"}


def observe_process(pid: int) -> dict:
    """Best available direct-process counters, never mislabeled as a process tree."""
    result = {"scope": "direct_process_only", "available": False}
    try:
        if Path("/proc/self/stat").exists() and int(Path("/proc/self/stat").read_text().split(" ", 1)[0]) != os.getpid():
            return {**result, "reason": "proc_pid_namespace_mismatch"}
        stat = Path(f"/proc/{pid}/stat")
        if stat.is_file():
            fields = stat.read_text().rsplit(")", 1)[1].split()
            clock = os.sysconf("SC_CLK_TCK")
            status = Path(f"/proc/{pid}/status").read_text()
            match = re.search(r"^VmHWM:\s*(\d+)\s+kB", status, re.M)
            result.update(available=True, cpu_seconds=(int(fields[11]) + int(fields[12])) / clock,
                          peak_rss_bytes=int(match[1]) * 1024 if match else None)
    except (OSError, ValueError, IndexError):
        pass
    return result


def _flatten_numbers(value, prefix="", depth=0):
    # Preserve useful named timing/participation counters without retaining
    # arbitrary megabyte per-cell arrays in a compact summary. Original logs keep
    # every record. Arrays supply min/max/count, never invented percentiles.
    if depth > 8 or not isinstance(value, dict):
        return {}
    found = {}
    pattern = re.compile(r"time|elapsed|latency|duration|throughput|tick|step|acknowledg|ready|present|frame|compil|import|recover|worker|physics|rapier|input|snapshot|revision|coalesc|age|cancel|reset|pause|resume|shutdown|construct|callback|first|particip", re.I)
    for key, item in value.items():
        name = prefix + str(key)
        if type(item) in (int, float) and math.isfinite(item) and pattern.search(name):
            found[name] = item
        elif isinstance(item, dict):
            found.update(_flatten_numbers(item, name + ".", depth + 1))
        elif isinstance(item, list) and item and len(item) < 100_000:
            numbers = [x for x in item if type(x) in (int, float) and math.isfinite(x)]
            if len(numbers) == len(item) and pattern.search(name):
                found.update({name + ".count": len(numbers), name + ".min": min(numbers), name + ".max": max(numbers)})
            elif all(isinstance(row, dict) for row in item):
                columns = {}
                for row in item:
                    for key, number in _flatten_numbers(row, name + ".", depth + 1).items():
                        columns.setdefault(key, []).append(number)
                for key, column in columns.items():
                    found.update({key + ".count": len(column), key + ".min": min(column), key + ".max": max(column)})
    return found


def runtime_observations(log: str) -> tuple[dict, dict, dict]:
    renderer = {"backend": "unknown", "driver": "unknown", "compiler": "unknown",
                "shader_source_sha256": None, "shader_variant_sha256": None,
                "variant": "unknown", "cache_state": "unknown"}
    config = {"material_inventory": "unknown", "solver": "unknown", "world": "unknown"}
    phases = {}
    for line in log.splitlines():
        if "OpenGL API" in line or "Vulkan API" in line:
            renderer["driver"] = line.strip()
            renderer["backend"] = "angle" if "ANGLE" in line else ("opengl" if "OpenGL" in line else "vulkan")
        if not re.match(r"^(?:[A-Z0-9_]+[: ]+)?\{", line):
            continue
        try:
            record = json.loads(line[line.index("{"):])
        except (ValueError, TypeError):
            continue
        if not isinstance(record, dict):
            continue
        label = line[:line.index("{")].strip().rstrip(":").replace(" ", "_") or "NATIVE_JSON"
        phases.update(_flatten_numbers(record, label + "."))
        for output, keys in {
            "shader_source_sha256": ("shader_source_sha256", "source_sha256", "source_hash"),
            "shader_variant_sha256": ("shader_variant_sha256", "selected_sha256", "variant_sha256"),
            "variant": ("shader_variant", "variant"),
            "cache_state": ("cache_state",),
        }.items():
            for key in keys:
                if key in record and isinstance(record[key], str):
                    renderer[output] = record[key]
                    break
        for key in config:
            if key in record:
                config[key] = record[key]
    return renderer, config, phases


def record_case(directory: Path, record: dict, log: str, *, root: Path) -> dict:
    renderer, config, phases = runtime_observations(log)
    if not record.get("requires_display"):
        renderer.update(backend="native" if record.get("role") == "native-command" else "headless",
                        driver="not-applicable", compiler="not-applicable",
                        variant="not-applicable", cache_state="not-applicable")
    shader = root / "godot/shaders/material_palette.gdshader"
    if not shader.exists():
        shader = root / "godot/shaders/palette.gdshader"
    renderer["shader_source_sha256"] = renderer["shader_source_sha256"] or digest(shader)
    fixture = root / "godot/tests" / (record["name"] + ".gd")
    definition = digest(fixture) or hashlib.sha256(json.dumps(record.get("command", []), sort_keys=True).encode()).hexdigest()
    config = {**config, "fixture_definition_sha256": definition,
              "material_inventory": digest(root / "native/include/cybersand/material.hpp") or "unknown",
              "solver": config["solver"] if config["solver"] != "unknown" else "fixture-defined",
              "world": config["world"] if config["world"] != "unknown" else "fixture-defined"}
    # A test's content hash is retained separately from its stable cohort name:
    # source changes are precisely what before/after observations compare.
    observation = {"schema": SCHEMA, "recorded_utc": datetime.now(timezone.utc).isoformat(),
        "source": source_identity(root), "host": host_identity(),
        "fixture": record["name"], "fixture_sha256": digest(fixture),
        "test_version": "shared-watchdogs-v1", "phase": record.get("role", "case"),
        "renderer": renderer, "configuration": config,
        "wall_seconds": record.get("seconds", record.get("elapsed_seconds")),
        "result": record.get("status"), "natural_completion": record.get("natural_completion", False),
        "watchdog_reached": bool(record.get("timeout_kind") or record.get("timed_out")),
        "watchdog_seconds": record.get("timeout_seconds"),
        "resources": record.get("resources", {"available": False, "scope": "direct_process_only"}),
        "metrics": phases, "last_progress": record.get("last_progress"),
        "raw_log": record.get("log", "command.log"), "execution_policy": execution_policy.identity()}
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / "performance.jsonl").open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(observation, sort_keys=True, allow_nan=False) + "\n")
    return observation


def cohort(record: dict) -> str:
    host, render = record["host"], record["renderer"]
    identity = {"fixture": record["fixture"], "test_version": record["test_version"],
        "phase": record["phase"], "configuration": record["configuration"],
        "host": {key: host.get(key, "unknown") for key in (
            "platform", "architecture", "cpu_model", "logical_cpu_count", "runner_class", "runner_image", "hardware_cohort")},
        "renderer": {key: render.get(key, "unknown") for key in ("backend", "driver", "compiler", "variant", "cache_state")}}
    return hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()
