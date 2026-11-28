#!/usr/bin/env python3
"""Four-shard same-runner stock-vs-tmpfs Godot qualification experiment.

Each runner executes three stock and three RAM trials on fresh independent
copies of the same repository/runtime. All actual test and import invocations
use the repository's existing run_godot_regressions.py harness.

The stock arm is on the runner's regular disk; the RAM arm stages the full
repo and Godot executable under verified /dev/shm tmpfs. It also redirects
HOME, XDG directories, and TMPDIR into that tmpfs. Host OS libraries, the Xvfb
server executable and kernel storage remain outside the controlled worktree.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import sys
import time

SHARDS = (2, 6, 12, 19)
SHARD_COUNT = 24
ORDERS = {2: ("stock", "ram", "ram", "stock", "stock", "ram"),
          6: ("ram", "stock", "stock", "ram", "ram", "stock"),
          12: ("stock", "ram", "ram", "stock", "stock", "ram"),
          19: ("ram", "stock", "stock", "ram", "ram", "stock")}
REQUIRED_MODES = {"stock": 3, "ram": 3}
ENV_KEYS = ("GITHUB_SHA", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT")


def dump_json(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as file:
        json.dump(data, file, indent=2, sort_keys=True)
        file.write("\n")
        file.flush()
        os.fsync(file.fileno())


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run_capture(*args: str, cwd: Path | None = None) -> str:
    return subprocess.check_output(args, cwd=cwd, text=True, timeout=90).strip()


def byte_count(path: Path) -> int:
    return int(run_capture("du", "-sb", str(path)).split()[0])


def mem_available_bytes() -> int:
    for line in Path("/proc/meminfo").read_text().splitlines():
        if line.startswith("MemAvailable:"):
            return int(line.split()[1]) * 1024
    raise RuntimeError("MemAvailable unavailable")


def fs_identity(path: Path) -> dict:
    fs = run_capture("stat", "-f", "-c", "%T", str(path))
    stat = os.statvfs(path)
    return {"type": fs, "available_bytes": stat.f_bavail * stat.f_frsize,
            "total_bytes": stat.f_blocks * stat.f_frsize}


def record_overview() -> dict:
    return {"runner": {"name": os.environ.get("RUNNER_NAME"),
                       "os": os.environ.get("RUNNER_OS"),
                       "image": os.environ.get("ImageVersion"),
                       "cpu_model": next((l.split(":", 1)[1].strip() for l in Path("/proc/cpuinfo").read_text().splitlines() if l.startswith("model name")), "unknown"),
                       "logical_cpus": os.cpu_count()},
            "run": {key.lower(): os.environ.get(key) for key in ENV_KEYS},
            "mem_available_bytes_at_start": mem_available_bytes(),
            "normal_filesystem": fs_identity(Path(os.environ["RUNNER_TEMP"])),
            "ram_filesystem": fs_identity(Path("/dev/shm"))}


def verify_plan(source: Path, shard: int) -> tuple[list[str], dict]:
    command = [sys.executable, "tools/ci/godot_job_plan.py", "--output", "/tmp/ramdisk-ci-four-plan.json"]
    subprocess.run(command, cwd=source, check=True, timeout=120)
    plan = json.loads(Path("/tmp/ramdisk-ci-four-plan.json").read_text())["linux"]
    if plan["shard_count"] != SHARD_COUNT:
        raise RuntimeError(f"Shard planner changed: {plan['shard_count']} != {SHARD_COUNT}")
    cases = [c["name"] for c in plan["shards"][shard]["cases"]]
    if not cases:
        raise RuntimeError("Empty selected shard")
    return cases, plan


def prepare_one(source: Path, godot: Path, base: Path, ram: bool, expected_bytes: int) -> tuple[Path, Path, dict]:
    if base.exists():
        shutil.rmtree(base)
    base.mkdir(parents=True)
    before = fs_identity(base)
    if ram:
        if before["type"] != "tmpfs":
            raise RuntimeError(f"RAM trial not on tmpfs: {before['type']}")
        # Reserve generous space for the clone, import cache, test output and Xvfb.
        required = int(expected_bytes * 1.5) + 1024**3
        if before["available_bytes"] < required or mem_available_bytes() < required:
            raise RuntimeError(f"Insufficient tmpfs/memory (need {required}, have {before['available_bytes']})")
    else:
        if before["type"] == "tmpfs":
            raise RuntimeError("Stock trial unexpectedly resides on tmpfs")
    workspace = base / "workspace"
    subprocess.run(["cp", "-a", str(source), str(workspace)], check=True, timeout=240)
    dest_godot = base / "Godot"
    shutil.copy2(godot, dest_godot)
    dest_godot.chmod(dest_godot.stat().st_mode | 0o111)
    for d in ("tmp", "home", "xdg-cache", "xdg-config", "xdg-data"):
        (base / d).mkdir()
    return workspace, dest_godot, {"filesystem": before["type"], "free_bytes_before": before["available_bytes"], "workspace_bytes_after_copy": byte_count(workspace), "godot_sha256": sha256(dest_godot)}


def parse_trial(result_dir: Path, expected_cases: list[str]) -> dict:
    timing = json.loads((result_dir / "timings.json").read_text())
    results = timing.get("results", [])
    per_case = [x for x in results if x.get("role") == "case"]
    imports = [x for x in results if x.get("name") == "import"]
    names = [x["name"] for x in per_case]
    if names != expected_cases:
        raise RuntimeError(f"Case inventory/order differs: {names} != {expected_cases}")
    if len(imports) != 1 or not timing.get("completed") or timing.get("status") != "passed":
        raise RuntimeError(f"Incomplete/failed run: {timing.get('status')} completed={timing.get('completed')}")
    if any(x.get("status") != "passed" for x in per_case + imports):
        raise RuntimeError("Individual case/import failed")
    return {"case_count": len(per_case), "case_names": names,
            "import_seconds": imports[0].get("seconds"),
            "case_seconds_sum": sum(x.get("seconds", 0) for x in per_case),
            "case_wall_seconds": {x["name"]: x.get("seconds") for x in per_case},
            "source_sha": timing.get("identity", {}).get("source_sha"),
            "runtime_sha256": timing.get("identity", {}).get("cybersand_runtime", {}).get("sha256"),
            "rapier_sha256": timing.get("identity", {}).get("rapier_runtime", {}).get("sha256")}


def perform_trial(source: Path, godot: Path, results_root: Path, shard: int,
                  expected_cases: list[str], mode: str, trial_id: int, occurrence: int,
                  expected_bytes: int, base_identity: dict) -> dict:
    is_ram = mode == "ram"
    suffix = f"{trial_id:02d}-{mode}-{occurrence}"
    dest = results_root / suffix
    dest.mkdir(parents=True)
    root = (Path("/dev/shm") / f"cybersand-ramdisk-{os.environ['GITHUB_RUN_ID']}-{shard}" if is_ram
            else Path(os.environ["RUNNER_TEMP"]) / f"cybersand-stock-{os.environ['GITHUB_RUN_ID']}-{shard}")
    times = {}
    start = time.monotonic()
    summary: dict = {"trial": trial_id, "mode": mode, "occurrence": occurrence,
                     "shard": shard, "source_sha": base_identity["source_sha"], "status": "incomplete"}
    try:
        workspace, binary, staged = prepare_one(source, godot, root, is_ram, expected_bytes)
        times["stage_seconds"] = time.monotonic() - start
        summary.update(staged)
        if run_capture("git", "rev-parse", "HEAD", cwd=workspace) != base_identity["source_sha"]:
            raise RuntimeError("Git source changed in staged worktree")
        if run_capture("git", "rev-parse", "HEAD^{tree}", cwd=workspace) != base_identity["source_tree"]:
            raise RuntimeError("Git tree changed in staged worktree")
        for lib, digest in base_identity["binaries"].items():
            if sha256(workspace / lib) != digest:
                raise RuntimeError("Native/Rapier runtime differed across storage modes: " + lib)
        env = os.environ.copy()
        env.update({"HOME": str(root / "home"), "TMPDIR": str(root / "tmp"),
                    "TMP": str(root / "tmp"), "TEMP": str(root / "tmp"),
                    "XDG_CACHE_HOME": str(root / "xdg-cache"),
                    "XDG_CONFIG_HOME": str(root / "xdg-config"),
                    "XDG_DATA_HOME": str(root / "xdg-data"),
                    "LIBGL_ALWAYS_SOFTWARE": "1", "LP_NUM_THREADS": "2",
                    "GALLIVM_PERF": "nopt", "CYBERSAND_CI_WATCHDOG_SCALE": "1",
                    "CYBERSAND_PRESENTATION_EVIDENCE": str(workspace / "build" / "experiment" / "presentation")})
        output = workspace / "build" / "experiment"
        output.mkdir(parents=True, exist_ok=True)
        # GNU time captures native I/O/CPU/RSS; original child fixtures are unchanged.
        command = ["/usr/bin/time", "-v", "-o", str(root / "gnu-time.txt"),
                   "xvfb-run", "--auto-servernum", "--server-args=-screen 0 1920x1080x24 -nolisten tcp",
                   sys.executable, "tools/ci/run_godot_regressions.py", "--godot", str(binary),
                   "--output", str(output), "--shard-count", str(SHARD_COUNT),
                   "--shard-index", str(shard), "--keep-going"]
        print("START", suffix, "source", base_identity["source_sha"], "fs", staged["filesystem"], flush=True)
        started = time.monotonic()
        with (root / "console.log").open("wb") as log:
            proc = subprocess.run(command, cwd=workspace, env=env, stdout=log, stderr=subprocess.STDOUT,
                                  timeout=3600, check=False)
        times["execution_seconds"] = time.monotonic() - started
        summary["exit_code"] = proc.returncode
        if proc.returncode == 0:
            readback_started = time.monotonic()
            with (root / "readback.log").open("wb") as log:
                verify = subprocess.run([sys.executable, "tools/ci/readback_4ly003_development.py",
                                         "--regression-output", str(output),
                                         "--expect-source-sha", base_identity["source_sha"]],
                                        cwd=workspace, env=env, stdout=log, stderr=subprocess.STDOUT,
                                        timeout=300, check=False)
            times["readback_seconds"] = time.monotonic() - readback_started
            summary["readback_exit_code"] = verify.returncode
        summary["generated_godot_cache_bytes"] = byte_count(workspace / "godot" / ".godot") if (workspace / "godot" / ".godot").exists() else 0
        summary["mem_available_bytes_after_execution"] = mem_available_bytes()
        summary["free_bytes_after_execution"] = fs_identity(root)["available_bytes"]
        # Copy back all original evidence onto the ordinary persistent runner filesystem.
        copy_start = time.monotonic()
        shutil.copytree(output, dest / "original-output")
        shutil.copy2(root / "console.log", dest / "console.log")
        shutil.copy2(root / "gnu-time.txt", dest / "gnu-time.txt")
        if (root / "readback.log").exists():
            shutil.copy2(root / "readback.log", dest / "readback.log")
        times["copyback_seconds"] = time.monotonic() - copy_start
        if proc.returncode != 0:
            raise RuntimeError(f"Original Godot shard failed with exit {proc.returncode}")
        if summary["readback_exit_code"] != 0:
            raise RuntimeError(f"Original 4LY readback failed with exit {summary['readback_exit_code']}")
        measured = parse_trial(output, expected_cases)
        if measured["source_sha"] != base_identity["source_sha"]:
            raise RuntimeError("Runner reported different source")
        for name, lib in (("runtime_sha256", "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"),
                          ("rapier_sha256", "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")):
            if measured[name] != base_identity["binaries"][lib]:
                raise RuntimeError("Runner reported different binary SHA: " + name)
        summary.update(measured)
        summary["status"] = "passed"
    except Exception as exc:
        summary.update(status="failed", error=f"{type(exc).__name__}: {exc}")
    finally:
        summary.update(times)
        summary["total_trial_seconds"] = time.monotonic() - start
        dump_json(dest / "trial.json", summary)
        # Cleanup can fail on resource exhaustion; record it, do not conceal it.
        try:
            shutil.rmtree(root)
        except OSError as exc:
            summary["cleanup_error"] = str(exc)
            summary["status"] = "failed"
            dump_json(dest / "trial.json", summary)
    print("END", suffix, "status", summary["status"], "execution_seconds", summary.get("execution_seconds"), flush=True)
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shard", type=int, choices=SHARDS, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source, godot = args.source.resolve(), args.godot.resolve(strict=True)
    if not (source / ".git").exists():
        raise RuntimeError("Real Git checkout required")
    if not all(os.environ.get(key) for key in ENV_KEYS):
        raise RuntimeError("GitHub source/run/attempt identity missing")
    args.output.mkdir(parents=True, exist_ok=True)
    expected_cases, plan = verify_plan(source, args.shard)
    rel_paths = ("godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
                 "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")
    base_identity = {"source_sha": run_capture("git", "rev-parse", "HEAD", cwd=source),
                     "source_tree": run_capture("git", "rev-parse", "HEAD^{tree}", cwd=source),
                     "binaries": {p: sha256(source / p) for p in rel_paths},
                     "godot_sha256": sha256(godot), "shard_count": SHARD_COUNT,
                     "cases": expected_cases, "host": record_overview(),
                     "source_copy_bytes": byte_count(source),
                     "mode_order": ORDERS[args.shard], "plan_estimated_seconds": plan["shards"][args.shard]["estimated_seconds"]}
    if base_identity["source_sha"] != os.environ["GITHUB_SHA"]:
        raise RuntimeError("Checked-out source does not match workflow SHA")
    if fs_identity(Path("/dev/shm"))["type"] != "tmpfs":
        raise RuntimeError("RAM side requires a real Linux tmpfs")
    dump_json(args.output / "source-and-host.json", base_identity)
    rows = []
    occurrences = {"stock": 0, "ram": 0}
    for i, mode in enumerate(ORDERS[args.shard], 1):
        occurrences[mode] += 1
        row = perform_trial(source, godot, args.output, args.shard, expected_cases, mode,
                            i, occurrences[mode], base_identity["source_copy_bytes"], base_identity)
        rows.append(row)
        with (args.output / "trials.jsonl").open("a", encoding="utf-8") as log:
            log.write(json.dumps(row, sort_keys=True) + "\n")
            log.flush()
            os.fsync(log.fileno())
    summary = {"shard": args.shard, "source": base_identity["source_sha"],
               "trial_count": len(rows), "modes": {}, "trials": rows}
    for mode in ("stock", "ram"):
        matching = [r for r in rows if r["mode"] == mode]
        times = [r["execution_seconds"] for r in matching if r["status"] == "passed"]
        summary["modes"][mode] = {"attempts": len(matching), "passed": len(times),
                                  "median_execution_seconds": statistics.median(times) if len(times) == 3 else None}
    dump_json(args.output / "summary.json", summary)
    return int(any(r["status"] != "passed" for r in rows))


if __name__ == "__main__":
    sys.exit(main())
