#!/usr/bin/env python3
"""Opt-in, source-matched Godot regression gate; NOT a gremlin action adapter.

Runs existing CyberSand tests only. No speculative simulation APIs, user saves,
or alternate physics owner. Does not claim actor-002R tests exist on main.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

SUITES = {
    "accepted": ("test_workbench_actor_composition_session", "test_workbench_actor_equipment_extent",
                 "test_physical_actor_session"),
    "actor-002r": ("test_workbench_actor_configuration", "test_workbench_actor_manipulation",
                   "test_workbench_actor_interaction", "test_workbench_actor_capacity",
                   "test_workbench_actor_topology"),
}


def file_hash(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for part in iter(lambda: f.read(1024 * 1024), b""):
            h.update(part)
    return h.hexdigest()


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--suite", choices=SUITES, required=True)
    p.add_argument("--godot", type=Path, required=True)
    p.add_argument("--project", type=Path, required=True)
    p.add_argument("--native", type=Path, help="Exact runtime native binary, if available")
    p.add_argument("--out", type=Path, required=True, help="New, empty evidence directory")
    p.add_argument("--timeout-seconds", type=int, default=180)
    args = p.parse_args(argv)
    if not 5 <= args.timeout_seconds <= 240:
        p.error("timeout must be 5..240 seconds")
    godot = args.godot.resolve(strict=True)
    project = args.project.resolve(strict=True)
    if not godot.is_file() or not (project / "project.godot").is_file():
        p.error("Godot binary or project.godot not found")
    tests = [project / "tests" / (name + ".gd") for name in SUITES[args.suite]]
    if any(not file.is_file() for file in tests):
        p.error("suite unavailable on this source: " + ", ".join(str(t.name) for t in tests if not t.is_file()))
    repo = project.parent
    rev = subprocess.run(["git", "rev-parse", "HEAD"], cwd=repo,
                         capture_output=True, text=True, timeout=5, check=True).stdout.strip()
    dirty = subprocess.run(["git", "status", "--porcelain", "--untracked-files=no"], cwd=repo,
                           capture_output=True, text=True, timeout=5, check=True).stdout.strip()
    if dirty:
        p.error("tracked source is modified; no source-matched evidence permitted")
    args.out.mkdir(parents=True, exist_ok=False)
    identity = {"source_commit": rev, "godot_sha256": file_hash(godot),
                "native_sha256": file_hash(args.native.resolve(strict=True)) if args.native else None,
                "suite": args.suite}
    sandbox = args.out / "sandbox-user-data"
    for name in ("home", "xdg-data", "xdg-cache", "xdg-config", "appdata", "localappdata"):
        (sandbox / name).mkdir(parents=True)
    env = dict(os.environ)
    env.update({"HOME": str(sandbox / "home"), "XDG_DATA_HOME": str(sandbox / "xdg-data"),
                "XDG_CONFIG_HOME": str(sandbox / "xdg-config"), "XDG_CACHE_HOME": str(sandbox / "xdg-cache"),
                "APPDATA": str(sandbox / "appdata"), "LOCALAPPDATA": str(sandbox / "localappdata"),
                "USERPROFILE": str(sandbox / "home")})
    records = []
    for file in tests:
        cmd = [str(godot), "--headless", "--path", str(project), "--script", "res://tests/" + file.name]
        t0 = time.monotonic()
        try:
            result = subprocess.run(cmd, cwd=project, env=env, capture_output=True, text=True,
                                    errors="replace", timeout=args.timeout_seconds)
            status = "pass" if result.returncode == 0 and "SCRIPT ERROR" not in (result.stdout + result.stderr) else "fail"
            output = result.stdout + "\n[stderr]\n" + result.stderr
            code = result.returncode
        except subprocess.TimeoutExpired as exc:
            status, code = "timeout", None
            output = "TIMEOUT: " + str(exc) + "\n" + str(exc.stdout or b"") + "\n" + str(exc.stderr or b"")
        (args.out / (file.stem + ".log")).write_text(output, encoding="utf-8")
        records.append({"test": file.stem, "status": status, "exit_code": code,
                        "elapsed_seconds": round(time.monotonic() - t0, 3)})
        if status != "pass":
            break  # containment: stop after the first real failure
    summary = {"identity": identity, "tests": records, "passed": len(records) == len(tests) and all(r["status"] == "pass" for r in records),
               "scope": "existing real Godot regression suites only; not GIP-generated action replay"}
    (args.out / "qualification.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary))
    return 0 if summary["passed"] else 2


if __name__ == "__main__":
    sys.exit(main())
