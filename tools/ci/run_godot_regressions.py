#!/usr/bin/env python3
"""Run current Godot regressions, optionally split into deterministic isolated shards."""

import argparse
from collections import Counter
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

import godot_timeout_diagnostics as diagnostics
import godot_process_monitor as process_monitor

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_UNKNOWN_WEIGHT_SECONDS = 5.0

# Approximate weights from the 2026-09-19 Linux CI run. They are scheduling hints,
# not pass/fail thresholds. Unknown tests deliberately receive a conservative
# weight so new fixtures are never omitted and are unlikely to overload one shard.
CASE_WEIGHTS_SECONDS = {
    # Prospective 4LY-003 actual-host development cases; these are scheduling
    # estimates, not actual measured pass/fail thresholds or simulated work.
    "test_physical_flight_teacher_dev_free": 75.0,
    "test_physical_flight_teacher_dev_obstacle": 100.0,
    "test_microscenarios": 54.0,
    # LCB scenario catalogue: 27 installs plus 1/4-worker 30-tick prefixes
    # (32 s on a 2026-10-23 Windows workstation; CI hosts are slower).
    "test_lcb_scenario_catalogue": 60.0,
    # LCB physics contracts: 43 s on the same workstation (dam ladder to t240 at 1/4 workers).
    "test_lcb_physics_contracts": 80.0,
    # LCB-001 pressure reference: 23 s on a 2026-10-24 Windows workstation
    # (1024² gas fixtures at 1/4 workers, two-limb, dam and default goldens).
    "test_lcb_pressure_reference": 45.0,
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


def runtime_paths(platform: str = sys.platform) -> tuple[Path, Path]:
    if platform == "win32":
        return (
            ROOT / "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
            ROOT / "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll",
        )
    if platform.startswith("linux"):
        return (
            ROOT / "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
            ROOT / "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so",
        )
    raise RuntimeError(f"Unsupported Godot regression host platform: {platform}")


@dataclass(frozen=True)
class Case:
    name: str
    flags: tuple[str, ...]
    timeout: int
    weight: float
    requires_display: bool = False


def _weight(name: str) -> float:
    return CASE_WEIGHTS_SECONDS.get(name, DEFAULT_UNKNOWN_WEIGHT_SECONDS)


def discover_cases(root: Path = ROOT) -> list[Case]:
    cases = [
        Case(
            p.stem,
            ("--script", "res://tests/" + p.name),
            # Scored native/Rapier development cases can consume tens of
            # thousands of real 60 Hz ticks. Keep their CI budget finite
            # without falsely classifying slower Windows hosts as faults.
            420 if p.stem in {
                "test_physical_flight_teacher_dev_free",
                "test_physical_flight_teacher_dev_obstacle",
            } else 180,
            _weight(p.stem),
            # Actual-pixel fixtures use this suffix so newly added render tests
            # cannot silently inherit the headless server's no-frame shortcut.
            requires_display=p.stem.endswith("_render"),
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
        "requires_display": case.requires_display,
    }


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def case_command(godot: str, case: Case, platform: str = sys.platform) -> list[str]:
    command = [godot]
    if case.requires_display:
        # Match the project's compatibility renderer. On Linux, Xvfb supplies
        # the display and Mesa supplies software OpenGL in GitHub-hosted CI.
        command += ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy"]
        if platform.startswith("linux"):
            command += ["--display-driver", "x11"]
    else:
        command.append("--headless")
    return [*command, "--path", str(ROOT / "godot"), *case.flags]


def _bounded_file_tail(handle, byte_limit: int) -> tuple[bytes, bool]:
    handle.seek(0, os.SEEK_END)
    size = handle.tell()
    handle.seek(max(0, size - byte_limit))
    return handle.read(byte_limit), size > byte_limit


def _tail(path: Path, lines: int = 60) -> str:
    """Bound the timeout console excerpt without replacing the retained full log."""
    with path.open("rb") as handle:
        data, truncated = _bounded_file_tail(handle, 256 * 1024)
    prefix = "[tail capped at 262144 bytes]\n" if truncated else ""
    return prefix + "\n".join(data.decode("utf-8", errors="replace").splitlines()[-lines:])


def _snapshot_command(command: list[str], *, timeout: int = 12) -> str:
    heading = f"$ {command!r}\n"
    try:
        # File-backed capture avoids unlimited in-memory output and inherited-pipe
        # waits when a timed-out debugger or PowerShell command has descendants.
        with tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
            options = (
                {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP}
                if sys.platform == "win32" else {"start_new_session": True}
            )
            process = subprocess.Popen(command, stdout=stdout, stderr=stderr, **options)
            try:
                process.wait(timeout=timeout)
                status = f"exit={process.returncode}\n"
            except subprocess.TimeoutExpired:
                status = f"SNAPSHOT UNAVAILABLE: TimeoutExpired after {timeout}s\n"
                _kill_process_tree(process, wait_seconds=2)
            out, out_truncated = _bounded_file_tail(stdout, 64000)
            err, err_truncated = _bounded_file_tail(stderr, 16000)
            if out_truncated or err_truncated:
                status += "[snapshot output capped at 64000 stdout / 16000 stderr bytes]\n"
            output = (out + err).decode("utf-8", errors="replace").replace("\r\n", "\n")
            return heading + status + output
    except OSError as error:
        return heading + f"SNAPSHOT UNAVAILABLE: {type(error).__name__}: {error}\n"


def _capture_timeout_snapshot(pid: int, path: Path, log_path: Path, elapsed: float) -> None:
    """Best-effort, bounded and non-fatal: preserve evidence *before* termination."""
    parts = [
        f"PID: {pid}\nElapsed before snapshot: {elapsed:.3f}s\n"
        f"Full test log: {log_path}\nLast 60 lines before termination:\n{_tail(log_path)}\n",
    ]
    if sys.platform == "win32":
        # The official console Godot wrapper owns a kill-on-close job containing
        # its engine child. Capture both wrapper and children before taskkill /T.
        script = (
            "$rootId=" + str(pid) + "; "
            "$procs=Get-CimInstance Win32_Process; "
            "$ids=@($rootId); "
            "for($i=0;$i -lt 5;$i++){"
            "$ids=@($ids + @($procs | Where-Object { $ids -contains $_.ParentProcessId }"
            " | ForEach-Object ProcessId)) | Sort-Object -Unique }; "
            "$procs | Where-Object { $ids -contains $_.ProcessId }"
            " | Format-List ProcessId,ParentProcessId,Name,CommandLine; "
            "foreach($id in $ids){ $p=Get-Process -Id $id -ErrorAction SilentlyContinue; "
            "if($null -eq $p){continue}; "
            "$p | Select-Object Id,ProcessName,CPU,StartTime | Format-List; "
            "try { foreach($thread in $p.Threads){ "
            "$wait='not waiting'; "
            "if($thread.ThreadState -eq [System.Diagnostics.ThreadState]::Wait){ "
            "try {$wait=$thread.WaitReason} catch {$wait='unavailable: '+$_.Exception.Message} }; "
            "[pscustomobject]@{ProcessId=$id;ThreadId=$thread.Id;State=$thread.ThreadState;"
            "WaitReason=$wait;CPU=$thread.TotalProcessorTime} | Format-List "
            "} } catch { Write-Output ('THREAD SNAPSHOT UNAVAILABLE: '+$_.Exception.Message) } }"
        )
        parts.append(_snapshot_command(["powershell", "-NoProfile", "-NonInteractive", "-Command", script]))
        parts.append("Native stack text: unavailable without a preinstalled debugger; process/thread snapshot retained. "
                     "See the separate diagnostic directory for the independent Windows minidump attempt.\n")
    else:
        # run_case starts an owned session, so this includes the engine root and
        # any same-session descendants rather than only the launcher PID.
        parts.append(_snapshot_command([
            "ps", "--forest", "-s", str(pid), "-o", "pid,ppid,pgid,sid,stat,etime,wchan:32,args",
        ]))
        parts.append(_snapshot_command([
            "ps", "-T", "-p", str(pid), "-o", "pid,tid,stat,etime,wchan:32,comm",
        ]))
        # This may fail under Yama ptrace restrictions. Record that refusal;
        # never let evidence collection promote a timeout to a pass.
        if shutil.which("gdb"):
            debugger = ["gdb", "-q", "-n", "-batch", "-p", str(pid),
                        "-ex", "set pagination off", "-ex", "thread apply all bt 12"]
            # GitHub Ubuntu may enable Yama ptrace_scope=1. sudo -n is
            # available on hosted runners; refusal stays explicit evidence.
            if shutil.which("sudo"):
                debugger = ["sudo", "-n", *debugger]
            parts.append(_snapshot_command(debugger))
        else:
            parts.append("Native stack capture: gdb not installed; process wait-channel snapshot retained.\n")
    try:
        path.write_text("\n".join(parts), encoding="utf-8")
    except OSError as error:
        print(f"Cannot write timeout snapshot {path}: {error}", flush=True)


def _kill_process_tree(process: subprocess.Popen, *, wait_seconds: int = 10) -> None:
    if sys.platform == "win32":
        # Windows Godot launches a console wrapper plus an engine child. Its
        # kill-on-close job and taskkill /T cover both processes.
        try:
            killer = subprocess.Popen(
                ["taskkill", "/PID", str(process.pid), "/T", "/F"],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            try:
                killer.wait(timeout=wait_seconds)
            except subprocess.TimeoutExpired:
                killer.kill()
                try:
                    killer.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    print("taskkill did not exit after termination", flush=True)
        except OSError as error:
            print(f"Cannot terminate process tree for PID {process.pid}: {error}", flush=True)
    else:
        try:
            os.killpg(os.getpgid(process.pid), signal.SIGKILL)
        except ProcessLookupError:
            pass
    if process.poll() is None:
        process.kill()
    try:
        process.wait(timeout=wait_seconds)
    except subprocess.TimeoutExpired:
        process.kill()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            print(f"Timed-out Godot PID {process.pid} did not exit after SIGKILL", flush=True)


def run_case(godot: str, case: Case, output_dir: Path, role: str, *,
             env: dict[str, str] | None = None) -> tuple[dict, bool]:
    log_path = output_dir / (case.name + ".log")
    snapshot_path = output_dir / (case.name + ".timeout-diagnostics.txt")
    command = case_command(godot, case)
    print(f"Running {case.name}, timeout {case.timeout}s: {command}", flush=True)
    started = time.perf_counter()
    timed_out = False
    returncode = None
    launch_error = None
    pid = None
    timeout_observed = None
    timeout_diagnostic_error = None
    capture_error = None
    timeout_kind = None
    with log_path.open("w", encoding="utf-8") as log:
        try:
            options = (
                {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP}
                if sys.platform == "win32" else {"start_new_session": True}
            )
            process = subprocess.Popen(
                command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, env=env, **options,
            )
            pid = process.pid
            def observe_timeout(now):
                nonlocal timeout_observed
                timeout_observed = now - started

            try:
                timed_out, timeout_kind, capture_error = process_monitor.wait(
                    process, case.name, case.timeout, started, log_path,
                    output_dir / (case.name + "-diagnostics"),
                    on_timeout=observe_timeout,
                )
                if timed_out:
                    # Snapshot overhead is recorded separately from the time at
                    # which the independent monitor observed the failing limit.
                    log.flush()
                    try:
                        _capture_timeout_snapshot(pid, snapshot_path, log_path, timeout_observed)
                    except Exception as error:
                        timeout_diagnostic_error = f"{type(error).__name__}: {error}"
                        message = f"Timeout evidence unavailable for PID {pid}: {timeout_diagnostic_error}\n"
                        print(message, end="", flush=True)
                        try:
                            snapshot_path.write_text(message, encoding="utf-8")
                        except OSError:
                            pass
                    log.write(f"\nTIMEOUT ({timeout_kind}) after {timeout_observed:.3f}s; case limit {case.timeout}s\n")
                    log.flush()
                else:
                    returncode = process.returncode
            finally:
                # Observation failures and debugger refusal cannot bypass tree
                # cleanup. A timeout always remains a failing result.
                if timed_out or process.poll() is None:
                    _kill_process_tree(process)
        except OSError as error:
            launch_error = str(error)
            log.write(f"\nLAUNCH ERROR: {launch_error}\n")
    elapsed = time.perf_counter() - started
    output = log_path.read_text(encoding="utf-8", errors="replace")
    print(output, end="", flush=True)
    diagnostic_error = "SCRIPT ERROR:" in output or "ERROR:" in output
    skip_messages = [
        line for line in output.splitlines()
        if re.search(r"\bskipped\b|^\s*SKIP\b", line, flags=re.IGNORECASE)
    ]
    failed = timed_out or returncode != 0 or diagnostic_error or bool(skip_messages)
    if timed_out:
        status = "timeout"
    elif returncode != 0 or diagnostic_error:
        status = "failed"
    elif skip_messages:
        status = "skipped"
    else:
        status = "passed"
    record = {
        "name": case.name,
        "role": role,
        "status": status,
        "seconds": round(timeout_observed if timeout_observed is not None else elapsed, 3),
        "diagnostic_seconds": round(elapsed - timeout_observed, 3) if timeout_observed is not None else 0.0,
        "timeout_seconds": case.timeout,
        "timeout_kind": timeout_kind,
        "returncode": returncode,
        "diagnostic_error": diagnostic_error,
        "launch_error": launch_error,
        "capture_error": capture_error,
        "skip_messages": skip_messages,
        "requires_display": case.requires_display,
        "command": command,
        "log": log_path.name,
        "pid": pid,
        "timeout_diagnostics": snapshot_path.name if timed_out and snapshot_path.exists() else None,
        "timeout_diagnostic_error": timeout_diagnostic_error,
        "last_progress": next(
            (line for line in reversed(output.splitlines()) if line.startswith("REGRESSION_PROGRESS ")),
            diagnostics.last_progress(output),
        ),
        "last_heartbeat": diagnostics.last_progress(output),
        "diagnostics": case.name + "-diagnostics" if (output_dir / (case.name + "-diagnostics")).exists() else None,
    }
    if failed:
        print(
            f"{case.name} {status}; elapsed={record['seconds']:.3f}s; exit={returncode}; "
            f"log={log_path}; snapshot={record['timeout_diagnostics']}",
            flush=True,
        )
        if timed_out:
            print("Last 60 log lines:\n" + _tail(log_path), flush=True)
    return record, failed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--shard-count", type=int, default=1)
    parser.add_argument("--shard-index", type=int, default=0)
    parser.add_argument(
        "--keep-going", action="store_true",
        help="Run every assigned case after a test failure; import still fails immediately",
    )
    args = parser.parse_args()

    if args.shard_count < 1:
        parser.error("--shard-count must be at least 1")
    if not 0 <= args.shard_index < args.shard_count:
        parser.error("--shard-index must be in [0, shard-count)")

    args.output.mkdir(parents=True, exist_ok=True)
    runtime, rapier = runtime_paths()
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
        "status": "running",
        "completed": False,
        "results": results,
    }

    # Every isolated shard performs a clean import preflight. In unsharded mode
    # this is the same single import that the legacy runner performed.
    import_case = Case("import", ("--editor", "--quit"), 240, 3.0)
    record, failed = run_case(args.godot, import_case, args.output, "preflight")
    results.append(record)
    write_json(args.output / "timings.json", timing)
    if failed:
        timing["status"] = "failed"
        write_json(args.output / "timings.json", timing)
        return 1

    suite_failed = False
    for case in assigned:
        record, failed = run_case(args.godot, case, args.output, "case")
        results.append(record)
        write_json(args.output / "timings.json", timing)
        if failed:
            suite_failed = True
            if not args.keep_going:
                timing["status"] = "failed"
                timing["completed"] = len(results) == len(assigned) + 1
                write_json(args.output / "timings.json", timing)
                return 1

    timing["status"] = "failed" if suite_failed else "passed"
    timing["completed"] = True
    write_json(args.output / "timings.json", timing)
    print(
        f"{'Failed' if suite_failed else 'Passed'} shard {args.shard_index + 1}/{args.shard_count}: "
        f"import plus {len(assigned)} assigned cases "
        f"({len(cases)} unique suite cases across all shards)",
        flush=True,
    )
    return int(suite_failed)


if __name__ == "__main__":
    raise SystemExit(main())
