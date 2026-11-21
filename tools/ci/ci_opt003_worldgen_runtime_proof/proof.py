#!/usr/bin/env python3
"""Capture fixed-source, cold complete-family evidence; never declare Native qualified."""
import argparse
from datetime import datetime, timezone
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess

from common import (ENVIRONMENT, SOURCES, SUITES, assert_contract_parity, canonical, digest, expected_source,
                    git, proof_identity, require, write)


def host():
    require(os.environ.get("RUNNER_ENVIRONMENT") == "github-hosted" and os.environ.get("GITHUB_ACTIONS") == "true",
            "Proof execution requires GitHub-hosted Actions")
    require(os.environ.get("RUNNER_OS") == "Linux" and os.environ.get("ImageOS") == "ubuntu24",
            "Proof execution requires the Ubuntu 24.04 image")
    for key, expected in ENVIRONMENT.items():
        require(os.environ.get(key) == expected, "Unexpected build environment: " + key)
    require(not os.environ.get("LD_PRELOAD") and not os.environ.get("LD_LIBRARY_PATH"), "Unexpected dynamic loader override")
    tools = {}
    for name in ("gcc-13", "g++-13", "make", "ld"):
        path = Path(shutil.which(name) or "/missing")
        require(path.is_file() and path.samefile("/usr/bin/" + name), "Compiler/tool wrapper is forbidden: " + name)
        version = subprocess.check_output([str(path), "--version"], text=True, timeout=300)
        tools[name] = {"path": str(path.resolve()), "sha256": digest(path.read_bytes()), "version": version}
        if name in ("gcc-13", "g++-13"):
            full_version = subprocess.check_output([str(path), "-dumpfullversion"], text=True, timeout=300).strip()
            require(full_version.startswith("13."), "Only GCC 13 is admitted")
            tools[name]["full_version"] = full_version
            tools[name]["target"] = subprocess.check_output([str(path), "-dumpmachine"], text=True, timeout=300).strip()
    cpu = re.search(r"^model name\s*:\s*(.+)$", Path("/proc/cpuinfo").read_text(), re.M)
    require(cpu is not None, "CPU model absent")
    return {"runner_environment": "github-hosted", "runner_os": "Linux", "image": os.environ["ImageOS"],
            "image_version": os.environ["ImageVersion"], "architecture": platform.machine(),
            "cpu_model": cpu[1], "logical_cpu_count": os.cpu_count(),
            "nproc": int(subprocess.check_output(["nproc"], text=True, timeout=300)),
            "memory_kib": int(re.search(r"^MemTotal:\s+(\d+) kB$", Path("/proc/meminfo").read_text(), re.M)[1]),
            "runner_name_sha256": digest(os.environ["RUNNER_NAME"].encode()),
            "job": os.environ["GITHUB_JOB"], "tools": tools,
            "environment": {key: os.environ[key] for key in ENVIRONMENT}}


def context(repository):
    sha = os.environ["GITHUB_SHA"]
    require(git(repository, "rev-parse", "HEAD").decode().strip() == sha, "Proof checkout/event differs")
    require(not git(repository, "status", "--porcelain").strip(), "Proof controller checkout changed")
    return {"proof": proof_identity(repository, sha), "run_id": int(os.environ["GITHUB_RUN_ID"]),
            "run_attempt": int(os.environ["GITHUB_RUN_ATTEMPT"])}


def snapshot(repository, output, arm, phase):
    source = output / arm / "source"
    with canonical(repository, arm) as verifier:
        identity = verifier.source_identity(source)
        require(identity == expected_source(repository, arm, verifier), "Original source identity differs")
    cold = not (source / "build").exists()
    if phase == "pre":
        require(cold, "Arm was not cold: build directory already exists")
        require(not (output / arm / "pre.json").exists(), "An arm may execute only once")
    data = {"schema": "ci-opt003-worldgen-runtime-snapshot-v1", **context(repository), "arm": arm,
            "source": identity, "source_root": str(source), "host": host(), "cold_build": cold,
            "captured_utc": datetime.now(timezone.utc).isoformat()}
    write(output / arm / (phase + ".json"), data)
    return data


def prepare(repository, output, suite):
    require(not output.exists(), "This pair already has evidence; retries/reuse are forbidden")
    ctx = context(repository)
    machine = host()
    contracts = assert_contract_parity(repository)
    write(output / "proof.json", {"schema": "ci-opt003-worldgen-runtime-pair-v1", **ctx, "suite": suite,
          "scope": "Complete paired worldgen family only; not whole-Native or routine-CI qualification",
          "order": ["baseline", "candidate"], "repetitions": 1, "job_cap_minutes": 360,
          "contracts": contracts, "host": machine})
    for arm, (sha, _) in SOURCES.items():
        destination = output / arm / "source"
        destination.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "-C", str(repository), "worktree", "add", "--detach", str(destination), sha],
                       check=True, timeout=300)
        require(not (destination / "build").exists(), "Prepared source has build outputs")


def capture(repository, output, suite, arm, outcome):
    source = output / arm / "source"
    errors = []
    try:
        snapshot(repository, output, arm, "post")
    except Exception as error:
        errors.append("source/host readback: " + str(error))
    # Invoke the original full-source recorder even on failure, retaining its errors.
    command = ["python3", "tools/ci/verify_native_shards.py", "record", "--suite", suite, "--outcome", outcome,
               "--source-sha", SOURCES[arm][0], "--run-id", os.environ["GITHUB_RUN_ID"],
               "--run-attempt", os.environ["GITHUB_RUN_ATTEMPT"], "--output", "build/native-parallel"]
    try:
        result = subprocess.run(command, cwd=source, env={**os.environ, "GITHUB_SHA": SOURCES[arm][0]},
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
        write(output / arm / "record-command.json", {"command": command, "returncode": result.returncode,
              "output": result.stdout.decode(errors="replace"), "output_sha256": digest(result.stdout)})
        if result.returncode:
            errors.append("Original record_shard refused the evidence")
    except Exception as error:
        errors.append("original recorder: " + str(error))
    binaries = {}
    try:
        for path in sorted((source / "build").glob("*")):
            if path.is_file() and not path.is_symlink():
                with path.open("rb") as stream:
                    is_elf = stream.read(4) == b"\x7fELF"
                if is_elf:
                    binaries[path.relative_to(source).as_posix()] = {"sha256": digest(path.read_bytes()), "bytes": path.stat().st_size}
        write(output / arm / "binary-digests.json", binaries)
    except Exception as error:
        errors.append("binary readback: " + str(error))
    write(output / arm / "capture.json", {"arm": arm, "outcome": outcome, "errors": errors})
    return bool(errors) or outcome != "success"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("prepare", "start", "capture"))
    parser.add_argument("--suite", choices=SUITES, required=True)
    parser.add_argument("--arm", choices=tuple(SOURCES))
    parser.add_argument("--outcome", choices=("success", "failure", "cancelled", "skipped"))
    args = parser.parse_args()
    repository = Path.cwd().resolve()
    output = repository / "build/proof" / args.suite
    if args.operation == "prepare":
        prepare(repository, output, args.suite)
        return 0
    require(args.arm is not None, "Arm required")
    if args.operation == "start":
        snapshot(repository, output, args.arm, "pre")
        return 0
    require(args.outcome is not None, "Original step outcome required")
    return int(capture(repository, output, args.suite, args.arm, args.outcome))


if __name__ == "__main__":
    raise SystemExit(main())
