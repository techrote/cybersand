#!/usr/bin/env python3
"""Reproduce isolated native tests and the complete failure-retaining research gallery."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def source_inputs():
    paths = sorted(p for p in HERE.iterdir() if p.is_file() and (p.suffix in (".cpp", ".hpp", ".py") or p.name == "Makefile"))
    paths += [ROOT / p for p in (
        "native/src/generation_spatial.cpp",
        "native/include/cybersand/material.hpp",
        "native/include/cybersand/generation_spatial.hpp",
        "native/include/cybersand/generation_numeric.hpp",
    )]
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path, help="Evidence output outside the source repository")
    parser.add_argument("--build", type=Path, default=Path("/tmp/gentek-swarm-build"), help="Parent for a fresh source-fingerprinted build directory per invocation")
    parser.add_argument("--sanitize", action="store_true")
    parser.add_argument("--quick", action="store_true", help="Smaller visual iteration; not the retained full comparison")
    parser.add_argument("--allow-dirty", action="store_true", help="Explicit development-only identity; cannot claim exact clean HEAD")
    args = parser.parse_args()
    out, build = args.out.resolve(), args.build.resolve()
    if out.is_relative_to(ROOT) or build.is_relative_to(ROOT):
        parser.error("Keep generated evidence and binaries outside the repository")
    out.mkdir(parents=True, exist_ok=True)
    if any(out.glob("*.json")):
        parser.error("Use a fresh evidence directory so failed/old cases cannot mix with this source")
    source = git("rev-parse", "HEAD")
    dirty = git("status", "--porcelain")
    if dirty and not args.allow_dirty:
        parser.error("Exact-source qualification requires a clean checkout; --allow-dirty is for visual iteration only")
    inputs = source_inputs()
    source_digest = hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()
    build.mkdir(parents=True, exist_ok=True)
    build = Path(tempfile.mkdtemp(prefix=source_digest[:16] + "-", dir=build))
    identity = source + ("+dirty-" + source_digest[:12] if dirty else "")
    manifest = {
        "programme": "GENTEK-SWARM-001",
        "scope": "unregistered native research; Draft/HOLD; no Workbench or production integration",
        "source_commit": source,
        "execution_identity": identity,
        "clean_source": not bool(dirty),
        "branch": git("branch", "--show-current"),
        "source_inputs": inputs,
        "source_input_fingerprint": source_digest,
        "fresh_build_directory": str(build),
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "platform": platform.platform(),
        "machine": platform.machine(),
        "python": sys.version,
        "compiler": subprocess.check_output([os.environ.get("CXX", "g++"), "--version"], text=True).splitlines()[0],
        "quick": args.quick,
        "leak_sanitizer": "disabled: LeakSanitizer cannot operate under this host's ptrace instrumentation",
        "commands": [],
    }

    def execute(label, command, timeout):
        print(f"[{label}] {' '.join(map(str, command))}", flush=True)
        started = time.monotonic()
        log = out / (label + ".log")
        env = os.environ.copy()
        env["ASAN_OPTIONS"] = "detect_leaks=0:halt_on_error=1"
        env["UBSAN_OPTIONS"] = "halt_on_error=1"
        with log.open("w") as file:
            result = subprocess.run(list(map(str, command)), cwd=ROOT, stdout=file, stderr=subprocess.STDOUT, env=env, timeout=timeout)
        receipt = {"label": label, "argv": list(map(str, command)), "exit_code": result.returncode, "elapsed_seconds": round(time.monotonic() - started, 3), "log": log.name, "log_sha256": hashlib.sha256(log.read_bytes()).hexdigest()}
        manifest["commands"].append(receipt)
        print(f"[{label}] exit={result.returncode} seconds={receipt['elapsed_seconds']}", flush=True)
        if result.returncode:
            raise RuntimeError(f"{label} failed; retained evidence: {log}")

    try:
        execute("build", ["make", "-C", HERE, f"BUILD={build}", "all"], 300)
        execute("native-tests", [build / "test_gentek_swarm"], 180)
        if args.sanitize:
            execute("sanitizer-build", ["make", "-C", HERE, f"BUILD={build}", build / "test_gentek_swarm_sanitized"], 600)
            execute("sanitizer-tests", [build / "test_gentek_swarm_sanitized"], 300)
        command = [build / "gentek_swarm", out, identity]
        if args.quick:
            command.append("quick")
        execute("native-evidence", command, 180)
        execute("gallery", [sys.executable, HERE / "gallery.py", out], 180)
        if git("rev-parse", "HEAD") != source or source_inputs() != inputs:
            raise RuntimeError("Source changed during qualification; outputs retained but not qualified")
        if not dirty and git("status", "--porcelain"):
            raise RuntimeError("Checkout became dirty during exact-source qualification")
        manifest["result"] = "PASS"
    except Exception as error:
        manifest["result"] = "FAIL"
        manifest["error"] = str(error)
        raise
    finally:
        manifest["finished_utc"] = datetime.now(timezone.utc).isoformat()
        manifest["binaries"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in build.glob("*gentek_swarm*") if p.is_file()}
        (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Retained evidence: {out / 'index.html'}", flush=True)


if __name__ == "__main__":
    main()
