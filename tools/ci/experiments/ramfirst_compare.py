#!/usr/bin/env python3
"""CI-RAMFIRST-002: same-host, direct-checkout SSD versus noswap tmpfs.

Each host has two independent clean checkouts: stock on the normal runner
filesystem, RAM on tmpfs mounted BEFORE either checkout. There is deliberately
NO SSD->RAM staging, no RAM->SSD evidence copy, and no persistent cache.
Each arm acquires/builds its own pinned dependencies directly on its own
filesystem, then executes three complete original Godot regression shards.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import sys
import time

SELECTED = (2, 6, 12, 19)
COUNT = 24
ORDER = {
    2: ("stock", "ram", "ram", "stock", "stock", "ram"),
    6: ("ram", "stock", "stock", "ram", "ram", "stock"),
    12: ("stock", "ram", "ram", "stock", "stock", "ram"),
    19: ("ram", "stock", "stock", "ram", "ram", "stock"),
}
GODOT_URL = "https://downloads.godotengine.org/?flavor=stable&platform=linux.64&slug=linux.x86_64.zip&version=4.7"
GODOT_SHA = "0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c"
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
CPP_REV = "101ae38034304346a46ea9ea84ae156d3e860496"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
NATIVE = "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
RAPIER_SHA = "566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a"
RUN_FIELDS = ("GITHUB_SHA", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT")


def write_json(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as stream:
        json.dump(data, stream, indent=2, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as reader:
        for buf in iter(lambda: reader.read(1 << 20), b""):
            h.update(buf)
    return h.hexdigest()


def fs_type(path: Path) -> str:
    return subprocess.check_output(["stat", "-f", "-c", "%T", str(path)], text=True, timeout=20).strip()


def bytes_used(path: Path) -> int:
    return int(subprocess.check_output(["du", "-sb", str(path)], text=True, timeout=50).split()[0])


def meminfo() -> dict[str, int]:
    vals = {}
    for line in Path("/proc/meminfo").read_text().splitlines():
        if ":" not in line:
            continue
        key, rest = line.split(":", 1)
        tokens = rest.strip().split()
        if tokens and tokens[0].isdigit():
            vals[key] = int(tokens[0]) * (1024 if len(tokens) > 1 and tokens[1] == "kB" else 1)
    return {x: vals.get(x, 0) for x in ("MemTotal", "MemAvailable", "Shmem", "Cached", "SwapTotal", "SwapFree")}


def host() -> dict:
    cpu = next((x.split(":", 1)[1].strip() for x in Path("/proc/cpuinfo").read_text().splitlines()
                if x.startswith("model name")), "unknown")
    return {"cpu": cpu, "cpus": os.cpu_count(), "image": os.environ.get("ImageVersion"),
            "runner": os.environ.get("RUNNER_NAME"), "run": {x: os.environ[x] for x in RUN_FIELDS},
            "kernel": os.uname().release, "memory": meminfo()}


def checked(command: list[str], repo: Path, env: dict[str, str], log: Path, timeout: int = 3600) -> float:
    log.parent.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    with log.open("wb") as stream:
        r = subprocess.run(command, cwd=repo, env=env, stdout=stream, stderr=subprocess.STDOUT,
                           timeout=timeout, check=False)
    seconds = round(time.monotonic() - start, 3)
    if r.returncode != 0:
        raise RuntimeError(f"Command failed ({r.returncode}) after {seconds}s: {command}; log={log}")
    return seconds


def environment(repo: Path) -> tuple[dict[str, str], Path]:
    scratch = repo / ".ramfirst-working"
    for name in ("home", "tmp", "xdg-cache", "xdg-config", "xdg-data", "pip-cache"):
        (scratch / name).mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update({"HOME": str(scratch / "home"), "TMPDIR": str(scratch / "tmp"),
                "TEMP": str(scratch / "tmp"), "TMP": str(scratch / "tmp"),
                "XDG_CACHE_HOME": str(scratch / "xdg-cache"),
                "XDG_CONFIG_HOME": str(scratch / "xdg-config"),
                "XDG_DATA_HOME": str(scratch / "xdg-data"),
                "PIP_CACHE_DIR": str(scratch / "pip-cache"),
                "LIBGL_ALWAYS_SOFTWARE": "1", "LP_NUM_THREADS": "2",
                "GALLIVM_PERF": "nopt", "CYBERSAND_CI_WATCHDOG_SCALE": "1"})
    return env, scratch


def source_identity(repo: Path) -> dict:
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()
    tree = subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], cwd=repo, text=True).strip()
    if head != os.environ["GITHUB_SHA"]:
        raise RuntimeError("Exact workflow source does not match checkout")
    return {"head": head, "tree": tree, "fs": fs_type(repo),
            "git_bytes": bytes_used(repo / ".git")}


def prepare(mode: str, repo: Path, shard: int) -> dict:
    if fs_type(repo) != ("tmpfs" if mode == "ram" else fs_type(repo)):
        raise RuntimeError("Invalid RAM filesystem")
    if mode == "stock" and fs_type(repo) == "tmpfs":
        raise RuntimeError("Stock checkout unexpectedly on RAM")
    if mode == "ram" and fs_type(repo) != "tmpfs":
        raise RuntimeError("RAM checkout is not tmpfs")
    env, scratch = environment(repo)
    timings: dict[str, float] = {}
    data = {"mode": mode, "shard": shard, "source": source_identity(repo),
            "start_mem": meminfo(), "status": "incomplete", "preparation": timings}
    evidence = repo / "build" / "ramfirst-evidence"
    evidence.mkdir(parents=True, exist_ok=True)
    write_json(evidence / "preparation.json", data)
    try:
        timings["lfs_seconds"] = checked(["git", "lfs", "install", "--local"], repo, env, evidence / "lfs-install.log", 120)
        timings["rapier_fetch_seconds"] = checked(
            ["git", "lfs", "pull", f"--include={RAPIER}", "--exclude="],
            repo, env, evidence / "rapier-fetch.log", 1200)
        if digest(repo / RAPIER) != RAPIER_SHA:
            raise RuntimeError("Pinned Rapier LFS binary hash differs")
        timings["scons_install_seconds"] = checked(
            [sys.executable, "-m", "venv", str(scratch / "scons")],
            repo, env, evidence / "venv.log", 120)
        py = str(scratch / "scons" / "bin" / "python")
        timings["scons_pip_seconds"] = checked(
            [py, "-m", "pip", "install", "--require-hashes", "-r", "tools/requirements-build.txt"],
            repo, env, evidence / "pip.log", 900)
        checked([py, "-c", 'import SCons; assert SCons.__version__ == "4.10.1"'],
                repo, env, evidence / "scons-version.log", 60)
        cpp = scratch / "godot-cpp"
        cpp.mkdir()
        checked(["git", "init", str(cpp)], repo, env, evidence / "cpp-init.log", 60)
        checked(["git", "-C", str(cpp), "remote", "add", "origin", "https://github.com/godotengine/godot-cpp.git"],
                repo, env, evidence / "cpp-remote.log", 60)
        timings["cpp_fetch_seconds"] = checked(
            ["git", "-C", str(cpp), "fetch", "--depth=1", "origin", CPP_REV],
            repo, env, evidence / "cpp-fetch.log", 1200)
        checked(["git", "-C", str(cpp), "checkout", "--detach", "FETCH_HEAD"],
                repo, env, evidence / "cpp-checkout.log", 60)
        if subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=cpp, text=True).strip() != CPP_REV:
            raise RuntimeError("Pinned godot-cpp source differs")
        env.update({"GODOT_CPP_ROOT": str(cpp), "SCONS_PYTHON": py,
                    "SCONS_JOBS": "2", "CYBERSAND_REAL_CXX": "/usr/bin/g++-13",
                    "LINUX_CXX": "/usr/bin/g++-13",
                    "CYBERSAND_NATIVE_OUTPUT": str(scratch / "libcybersand_native.linux.x86_64.so")})
        timings["godotcpp_build_seconds"] = checked(
            ["bash", "tools/build_pinned_godot_cpp.sh", "linux"], repo, env, evidence / "godotcpp-build.log", 1800)
        timings["native_build_seconds"] = checked(
            ["bash", "tools/build_native_extension.sh"], repo, env, evidence / "native-build.log", 1800)
        shutil.copy2(env["CYBERSAND_NATIVE_OUTPUT"], repo / NATIVE)
        timings["runtime_floor_seconds"] = checked(
            ["bash", "tools/check_linux_runtime_floor.sh"], repo, env, evidence / "runtime-floor.log", 180)
        archive = scratch / "godot.zip"
        timings["godot_download_seconds"] = checked(
            ["curl", "--fail", "--location", "--retry", "3", "--retry-all-errors",
             "--retry-delay", "2", "--retry-max-time", "1200",
             "--output", str(archive), GODOT_URL],
            repo, env, evidence / "godot-download.log", 1200)
        if digest(archive) != GODOT_SHA:
            raise RuntimeError("Official Godot binary archive hash differs")
        godot_folder = scratch / "godot"
        godot_folder.mkdir()
        timings["godot_extract_seconds"] = checked(
            ["unzip", "-q", str(archive), "-d", str(godot_folder)],
            repo, env, evidence / "godot-unzip.log", 180)
        binaries = list(godot_folder.glob("Godot*"))
        if len(binaries) != 1:
            raise RuntimeError("Ambiguous Godot executable")
        binary = binaries[0]
        binary.chmod(binary.stat().st_mode | 0o111)
        version = subprocess.check_output([str(binary), "--version"], cwd=repo, env=env, text=True, timeout=60).strip()
        if version != GODOT_VERSION:
            raise RuntimeError("Godot version differs")
        planfile = scratch / "godot-plan.json"
        timings["plan_seconds"] = checked(
            [sys.executable, "tools/ci/godot_job_plan.py", "--output", str(planfile)],
            repo, env, evidence / "plan.log", 120)
        plan = json.loads(planfile.read_text())["linux"]
        if plan["shard_count"] != COUNT:
            raise RuntimeError(f"Original Linux matrix changed (expected {COUNT}, got {plan['shard_count']})")
        cases = [c["name"] for c in plan["shards"][shard]["cases"]]
        if not cases:
            raise RuntimeError("Selected shard has no cases")
        data.update(status="prepared", godot_bin=str(binary), godot_sha256=digest(binary),
                    runtime_sha256=digest(repo / NATIVE), rapier_sha256=digest(repo / RAPIER),
                    case_names=cases, case_count=len(cases), prepared_bytes=bytes_used(scratch),
                    project_bytes=bytes_used(repo / "godot"), end_prepare_mem=meminfo())
    except Exception as err:
        data.update(status="failed", error=f"{type(err).__name__}: {err}")
    data["preparation_seconds"] = sum(timings.values())
    write_json(evidence / "preparation.json", data)
    return data


def one_trial(mode: str, repo: Path, prepared: dict, shard: int, sequence: int, repeat: int) -> dict:
    env, scratch = environment(repo)
    root = repo / "build" / "ramfirst-evidence" / f"trial-{sequence:02d}-{mode}-{repeat}"
    root.mkdir(parents=True, exist_ok=True)
    result = {"mode": mode, "shard": shard, "sequence": sequence,
              "repeat": repeat, "status": "incomplete", "start_mem": meminfo()}
    result["filesystem"] = fs_type(root)
    env["CYBERSAND_PRESENTATION_EVIDENCE"] = str(root / "original" / "presentation")
    original = root / "original"
    original.mkdir()
    try:
        launch = ["/usr/bin/time", "-v", "-o", str(root / "gnu-time.txt"),
                  "xvfb-run", "--auto-servernum",
                  "--server-args=-screen 0 1920x1080x24 -nolisten tcp",
                  sys.executable, "tools/ci/run_godot_regressions.py",
                  "--godot", prepared["godot_bin"], "--output", str(original),
                  "--shard-count", str(COUNT), "--shard-index", str(shard), "--keep-going"]
        result["execution_seconds"] = checked(launch, repo, env, root / "console.log", 3600)
        result["readback_seconds"] = checked(
            [sys.executable, "tools/ci/readback_4ly003_development.py",
             "--regression-output", str(original), "--expect-source-sha", prepared["source"]["head"]],
            repo, env, root / "readback.log", 300)
        timing = json.loads((original / "timings.json").read_text())
        runs = [r for r in timing.get("results", []) if r.get("role") == "case"]
        imports = [r for r in timing.get("results", []) if r.get("name") == "import"]
        if not timing.get("completed") or timing.get("status") != "passed":
            raise RuntimeError("Original Godot shard was incomplete or failed")
        if [r["name"] for r in runs] != prepared["case_names"]:
            raise RuntimeError("Changed/missing/duplicated case inventory")
        if any(r.get("status") != "passed" for r in runs + imports) or len(imports) != 1:
            raise RuntimeError("Individual Godot case or import not passed")
        ident = timing["identity"]
        if (ident["source_sha"] != prepared["source"]["head"]
                or ident["cybersand_runtime"]["sha256"] != prepared["runtime_sha256"]
                or ident["rapier_runtime"]["sha256"] != prepared["rapier_sha256"]):
            raise RuntimeError("Godot evidence source or runtime identity mismatch")
        result.update(status="passed", import_seconds=imports[0]["seconds"],
                      test_seconds=sum(r["seconds"] for r in runs),
                      case_seconds={r["name"]: r["seconds"] for r in runs},
                      completed_cases=len(runs), godot_cache_bytes=(bytes_used(repo / "godot" / ".godot")
                          if (repo / "godot" / ".godot").exists() else 0))
    except Exception as err:
        result.update(status="failed", error=f"{type(err).__name__}: {err}")
    result.update(end_mem=meminfo(), end_fs=fs_type(root))
    write_json(root / "trial.json", result)
    return result


def stats(values: list[float]) -> dict:
    if len(values) != 3 or any(not isinstance(x, (int, float)) or not math.isfinite(x) for x in values):
        return {"count": len(values), "median_seconds": None}
    return {"count": 3, "median_seconds": statistics.median(values),
            "mean_seconds": statistics.mean(values)}


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--shard", type=int, required=True, choices=SELECTED)
    p.add_argument("--stock", type=Path, required=True)
    p.add_argument("--ram", type=Path, required=True)
    p.add_argument("--report", type=Path, required=True)
    args = p.parse_args()
    if any(not os.environ.get(x) for x in RUN_FIELDS):
        raise RuntimeError("GitHub source/run/attempt environment missing")
    stock, ram = args.stock.resolve(), args.ram.resolve()
    if fs_type(stock) == "tmpfs" or fs_type(ram) != "tmpfs":
        raise RuntimeError("One or both directly checked-out worktrees are on the wrong filesystem")
    args.report.mkdir(parents=True, exist_ok=True)
    data = {"schema": "cybersand-ramfirst-four-shards-v2", "shard": args.shard, "host": host(),
            "order": ORDER[args.shard], "arms": {}, "trials": [], "status": "incomplete"}
    write_json(args.report / "summary.json", data)
    # Both checkouts were performed directly by actions/checkout after the first-step mount.
    # Swap preparation order between shards to control OS/CPU warm-up bias.
    arm_paths = {"stock": stock, "ram": ram}
    prep_order = ("stock", "ram") if args.shard in (2, 12) else ("ram", "stock")
    for mode in prep_order:
        data["arms"][mode] = prepare(mode, arm_paths[mode], args.shard)
        write_json(args.report / "summary.json", data)
    a, b = data["arms"]["stock"], data["arms"]["ram"]
    if a["status"] != "prepared" or b["status"] != "prepared":
        data.update(status="failed", error="Source/runtime preparation failed")
        write_json(args.report / "summary.json", data)
        return 1
    if (a["source"]["head"] != b["source"]["head"] or
            a["source"]["tree"] != b["source"]["tree"] or
            a["case_names"] != b["case_names"] or
            a["godot_sha256"] != b["godot_sha256"] or
            a["runtime_sha256"] != b["runtime_sha256"] or
            a["rapier_sha256"] != b["rapier_sha256"]):
        data.update(status="failed", error="Storage modes do not share exact source, cases or binary identities")
        write_json(args.report / "summary.json", data)
        return 1
    counts = {"stock": 0, "ram": 0}
    for i, mode in enumerate(ORDER[args.shard], 1):
        counts[mode] += 1
        trial = one_trial(mode, arm_paths[mode], data["arms"][mode], args.shard, i, counts[mode])
        data["trials"].append(trial)
        write_json(args.report / "summary.json", data)
        print("TRIAL", args.shard, i, mode, trial["status"],
              "execution_sec", trial.get("execution_seconds"), flush=True)
    data["medians"] = {mode: stats([r["execution_seconds"] for r in data["trials"]
                        if r["mode"] == mode and r["status"] == "passed"])
                       for mode in ("stock", "ram")}
    data["status"] = "passed" if len(data["trials"]) == 6 and all(x["status"] == "passed" for x in data["trials"]) else "failed"
    write_json(args.report / "summary.json", data)
    return int(data["status"] != "passed")


if __name__ == "__main__":
    sys.exit(main())
