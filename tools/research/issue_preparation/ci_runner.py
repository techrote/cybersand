#!/usr/bin/env python3
"""Collect bounded research/full-checkout evidence; never repairs failed gates.

Invoked by the research-only workflow. Logs/builds remain outside the dated
committed bundle. Every attempted command records its exit code and log digest.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
BRANCH = "refs/heads/codex/research-preparation-2026-09-12"


def main() -> int:
    if os.environ.get("GITHUB_REPOSITORY") != "techrote/cybersand" or os.environ.get("GITHUB_REF") != BRANCH:
        raise SystemExit("This collection job is restricted to its registered research branch.")
    os.chdir(ROOT)
    sha = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    if sha != os.environ.get("GITHUB_SHA"):
        raise SystemExit("Checkout/source identity mismatch")
    out = ROOT / "docs/audits/2026-09-12-research-preparation/runs" / sha
    if out.exists():
        raise SystemExit("Immutable evidence path already exists; use a new source checkpoint")
    data = out / "data"
    logs = ROOT / "validation/local/research-preparation" / sha
    logs.mkdir(parents=True, exist_ok=True)
    data.mkdir(parents=True)
    tools = Path("tools/research/issue_preparation")
    records = []

    def run(name: str, command: list[str], seconds: int, preparation: bool = False) -> int:
        log = logs / f"{name}.txt"
        with log.open("wb") as stream:
            try:
                code = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT,
                                      timeout=seconds, check=False).returncode
            except subprocess.TimeoutExpired:
                stream.write(b"\nEXPLICIT COMMAND TIMEOUT\n")
                code = 124
            except OSError as error:
                stream.write(str(error).encode())
                code = 127
        raw = log.read_bytes()
        records.append({"name": name, "command": command, "timeout_seconds": seconds,
                        "exit_code": code, "status": "passed" if code == 0 else "failed",
                        "required_for_preparation": preparation,
                        "log_sha256": hashlib.sha256(raw).hexdigest(),
                        "log_bytes": len(raw), "output_tail": raw.decode("utf-8", errors="replace")[-4000:]})
        print(f"{name}: exit={code}", flush=True)
        return code

    run("compiler", ["g++-13", "--version"], 15)
    run("research-tests", [sys.executable, "-m", "unittest", "discover", "-s", str(tools), "-p", "test_*.py", "-v"], 60, True)
    run("precompute", [sys.executable, str(tools / "precompute.py"), "--out", str(data)], 120, True)
    repeat = logs / "repeat"
    run("precompute-repeat", [sys.executable, str(tools / "precompute.py"), "--out", str(repeat)], 120, True)
    first = {p.name: p.read_bytes() for p in data.iterdir() if p.is_file()}
    second = {p.name: p.read_bytes() for p in repeat.iterdir() if p.is_file()} if repeat.exists() else {}
    deterministic = bool(first) and first == second
    records.append({"name": "byte-identical-repeat", "exit_code": 0 if deterministic else 1,
                    "status": "passed" if deterministic else "failed", "required_for_preparation": True,
                    "files": len(first)})
    exe = logs / "projection_oracle"
    run("projection-build", ["g++-13", "-std=c++20", "-O2", "-Wall", "-Wextra", "-Werror", "-pedantic",
                             str(tools / "projection_oracle.cpp"), "-o", str(exe)], 60, True)
    run("projection-run", [str(exe)], 15, True)
    expected = data / "projection.csv"
    match = expected.is_file() and expected.read_bytes() == (logs / "projection-run.txt").read_bytes()
    records.append({"name": "cpp-python-projection-parity", "exit_code": 0 if match else 1,
                    "status": "passed" if match else "failed", "required_for_preparation": True})
    run("documentation", [sys.executable, "tools/ci/check_docs.py"], 120)
    run("historical-m11", [sys.executable, "tools/ci/check_m11_consistency.py"], 120)
    run("repository", [sys.executable, "tools/ci/check_repository.py", "--require-materialized"], 180)
    run("validation-contracts", [sys.executable, "-m", "unittest", "discover", "-s", "tools/ci", "-p", "test_validation_contracts.py"], 120)
    run("retrieval-frozen", [sys.executable, "tools/docs/retrieval_eval.py", "--output", str(logs / "retrieval-frozen.json")], 120)
    run("retrieval-challenges", [sys.executable, "tools/docs/retrieval_eval.py", "--queries", "docs/reference/retrieval-challenges.json", "--output", str(logs / "retrieval-challenges.json")], 120)
    run("c-header", ["make", "c-header-check"], 120)
    run("native-build", ["make", "build/tests"], 300)
    run("native-tests", ["./build/tests"], 300)
    run("whitespace", ["git", "diff", "--check", "d39e31f03f2e39b0022d507b79fbee5c2439436d", "HEAD"], 60)
    binaries = {}
    for path in (exe, ROOT / "build/tests"):
        if path.is_file():
            binaries[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    result = {"schema": 1, "source_commit": sha, "repository": "techrote/cybersand",
              "run_id": os.environ.get("GITHUB_RUN_ID"), "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
              "python": platform.python_version(), "platform": platform.platform(), "checks": records,
              "binary_sha256": binaries,
              "preparation_checks_passed": all(r["exit_code"] == 0 for r in records if r["required_for_preparation"]),
              "all_attempted_checks_passed": all(r["exit_code"] == 0 for r in records),
              "not_run": ["Windows", "Godot application", "Web browser", "target GPU", "human Water preference", "ASan", "UBSan", "TSan"],
              "publication_is_not_architecture_acceptance": True}
    (out / "checks.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    (out / "README.md").write_text("# Immutable research run\n\nSource: `" + sha + "`. See [checks](checks.json) for each exit code and [generated summary](data/summary.json).\n\nPublication retains failures too; it is not a claim that every check passed. Raw logs and executables are workflow artifacts, not committed source.\n")
    # Allow the following workflow step to preserve measured failures in Git.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
