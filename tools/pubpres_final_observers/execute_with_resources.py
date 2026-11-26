#!/usr/bin/env python3
"""Source-registered runner with additive same-process CPU observations.

No monkeypatch or receipt rewriting. execution_contract.py pins the original
runner and verifies every ownership, cancellation, timeout and result predicate.
"""
from __future__ import annotations
import json
import os
from pathlib import Path
import shutil
import sys
import time
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/pubpres_playability"))
from run_campaign import (OwnedProcess, engine_command, descendant_pids, memory_sample,
                          digest, need, write_json)
from execution_contract import FROZEN_RUNNER_SHA256, verify_execution_derivation
from resource_sampler import process_cpu_sample, summarize_cpu
from process_discovery import discover_application, validate_discovery


def execute_with_resources(engine, args, folder, source_sha, settings, timeout, wrapper=None):
    verify_execution_derivation()
    resource_samples, resource_errors, resource_dropped = [], [], 0
    application_discovery = None
    folder.mkdir(parents=True, exist_ok=True)
    env = {k: v for k, v in os.environ.items() if not k.startswith("CYBERSAND_")}
    profile_variables=("APPDATA","LOCALAPPDATA") if os.name == "nt" else ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME")
    for name in profile_variables:
        path = folder / "profile" / name
        path.mkdir(parents=True, exist_ok=True)
        env[name] = str(path)
    env.update(settings, CYBERSAND_SOURCE_REVISION=source_sha, CYBERSAND_SOURCE_SHA=source_sha)
    env["PUBPRES_DISPLAY_RECEIPT"] = str(folder / "display-owner.json")
    command = engine_command(engine,args,wrapper)
    clock = time.monotonic()
    samples, child_pid = [], None
    timed_out, surviving_children = False, False
    process, failure, exit_code = None, None, None
    with (folder / "stdout.log").open("w") as out, (folder / "stderr.log").open("w") as err:
        try:
            with OwnedProcess(command, stdout=out, stderr=err, env=env) as owner:
                process = owner.process
                if os.name == "nt":child_pid=process.pid
                while process.poll() is None:
                    if time.monotonic() - clock > timeout:
                        timed_out = True
                        owner.close()
                        break
                    try:
                        if child_pid is None:
                            application_discovery = discover_application(process.pid, engine)
                            if application_discovery is not None:
                                child_pid = application_discovery["pid"]
                        if child_pid is not None:
                            samples.append(memory_sample(child_pid, (time.monotonic() - clock) * 1000))
                            if len(resource_samples) >= 4096:
                                resource_dropped += 1
                            else:
                                try:
                                    resource_samples.append(process_cpu_sample(child_pid, (time.monotonic() - clock) * 1000))
                                except (OSError, ValueError) as error:
                                    if len(resource_errors) < 4096:
                                        resource_errors.append({"elapsed_ms": (time.monotonic() - clock) * 1000, "error": str(error),
                                                                "sampler_elapsed_usec": getattr(error,"sampler_elapsed_usec",None)})
                    except (OSError, ValueError):
                        pass
                    time.sleep(0.25)
                exit_code = process.wait(timeout=10)
                surviving_children = owner.close() and not timed_out
        except BaseException as error:
            failure = error
            exit_code = process.returncode if process is not None else None
    result = {"command": command, "source_commit": source_sha, "elapsed_seconds": time.monotonic() - clock, "exit_code": exit_code,
              "timed_out": timed_out, "surviving_children_at_exit": surviving_children,
              "interruption": type(failure).__name__ + ": " + str(failure) if failure else None,
              "wrapper_pid": process.pid if process is not None else None, "observed_application_pid": child_pid,
              "sampled_peak_rss_bytes": max((s["peak_rss_bytes"] for s in samples if s["peak_rss_bytes"] is not None), default=None),
              "memory_scope": "250ms actual Godot process working-set/RSS samples including setup and capture; valid only after receipt PID match. Windows virtual size unavailable; commit reported separately."}
    if wrapper is not None:
        result["display_wrapper_sha256"] = digest(Path(shutil.which(str(wrapper)) or wrapper).resolve())
    if wrapper is not None and Path(wrapper).name == "owned_xvfb.py":
        display_path = folder / "display-owner.json"
        try:
            display = json.loads(display_path.read_text(encoding="utf-8")) if display_path.is_file() else {}
        except (ValueError, OSError) as error:
            display = {}
            result["display_owner_error"] = str(error)
        result["display_owner_sha256"] = digest(display_path) if display_path.is_file() else None
        result["display_owner_verified"] = bool(display.get("schema") == "pubpres-owned-display-v1"
            and display.get("wrapper_pid") == (process.pid if process is not None else None)
            and display.get("server_reaped") is True and display.get("forced_server_kill") is False
            and display.get("server_tree_closed") is True and display.get("unexpected_server_members") is False
            and display.get("server_returncode") in (0, -15)
            and display.get("server_alive_before_requested_shutdown") is True
            and display.get("application_returncode") == 0 and display.get("returncode") == 0
            and display.get("application_timeout") is False and display.get("failure") is None)
    resource_summary = summarize_cpu(resource_samples, expected_pid=child_pid, errors=resource_errors, dropped=resource_dropped)
    result["application_discovery"] = application_discovery
    if os.name != "nt" and resource_summary["complete"]:
        validate_discovery(application_discovery, owner_pid=result["wrapper_pid"], pid=child_pid,
                           creation_identity=resource_summary["creation_identity"], executable=engine)
    resource_trace = {"schema": "pubpres-final-process-cpu-v1", "source_commit": source_sha,
                      "frozen_runner_sha256": FROZEN_RUNNER_SHA256,
                      "runner_sha256": digest(Path(__file__)), "summary": resource_summary,
                      "samples": resource_samples, "errors": resource_errors}
    write_json(folder / "process-cpu.json", resource_trace)
    result["process_cpu"] = {"path": str(folder / "process-cpu.json"),
                             "sha256": digest(folder / "process-cpu.json"), "summary": resource_summary}
    write_json(folder / "process.json", result)
    write_json(folder / "process-memory.json", samples)
    if failure is not None:
        raise failure
    logs = (folder / "stdout.log").read_text() + (folder / "stderr.log").read_text()
    need(not timed_out and not surviving_children and exit_code == 0 and result.get("display_owner_verified", True)
        and not any(x in logs for x in ("SCRIPT ERROR:", "Parse Error:", "Failed to load script", "Failed loading resource:", "Error initializing GLAD", "MakeCurrent failed")), f"Process failed: {folder}")
    return result
