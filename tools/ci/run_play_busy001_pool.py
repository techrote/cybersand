#!/usr/bin/env python3
"""Build the literal production pool class with a test-only bounded job gate.

No production source is patched. This isolates pool/gate lifetime mechanics;
it does NOT execute World::simulation_tick, Godot, Rapier, or a real stop fence.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
POOL_SHA256 = "6e0b106df73926d94db07ce5c4fea1764f4cc1d883d6a0d1e98c242c6d68a25d"
SOURCE = "native/src/world.cpp"
DRIVER = "native/tests/test_play_busy001_pool.cpp"
GATE = "native/tests/support/play_busy001_barrier.hpp"


def extract_pool(raw: bytes) -> bytes:
    raw = raw.replace(b"\r\n", b"\n")
    start = b"class PersistentWorkerPool final {\n"
    if raw.count(start) != 1:
        raise ValueError("expected one literal production pool class")
    begin = raw.index(start)
    end = raw.find(b"\n};\n", begin)
    if end < 0:
        raise ValueError("missing production pool closing delimiter")
    pool = raw[begin:end + len(b"\n};\n")]
    if hashlib.sha256(pool).hexdigest() != POOL_SHA256:
        raise ValueError("production pool source changed; review and re-pin before testing")
    return pool


def generated_header(pool: bytes) -> bytes:
    includes = ("array", "atomic", "bit", "condition_variable", "cstddef",
                "cstdint", "mutex", "thread", "vector")
    prefix = "#pragma once\n" + "".join(f"#include <{name}>\n" for name in includes)
    prefix += f'#define PLAY_BUSY001_POOL_SHA256 "{POOL_SHA256}"\n'
    return prefix.encode() + b"namespace cybersand::source_probe {\n" + pool + b"\n}\n"


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=20)


def invoke(command: list[str], log: Path, timeout: int, env: dict | None = None) -> None:
    with log.open("wb") as stream:
        try:
            process = subprocess.run(command, cwd=ROOT, stdout=stream,
                                     stderr=subprocess.STDOUT, timeout=timeout, env=env)
        except subprocess.TimeoutExpired:
            stream.write(f"\nAPPARATUS TIMEOUT after {timeout}s; no retry\n".encode())
            raise
    if process.returncode:
        raise RuntimeError(f"command exit {process.returncode}; see {log.name}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", default="g++")
    parser.add_argument("--sanitize", choices=("none", "address-undefined", "thread"), default="none")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--expected-source", help="required exact Git HEAD in hosted/full-checkout mode")
    parser.add_argument("--local-source-excerpt", type=Path,
                        help="explicit non-checkout mode; never a full-World provenance claim")
    args = parser.parse_args()
    output = args.output.resolve(); output.mkdir(parents=True, exist_ok=True)
    receipt = {"schema": "play-busy001a-pool-apparatus-v1", "status": "failed",
               "pool_class_sha256": POOL_SHA256, "platform": platform.platform(),
               "python": sys.version, "compiler": args.compiler, "sanitize": args.sanitize,
               "run_id": os.getenv("GITHUB_RUN_ID"), "run_attempt": os.getenv("GITHUB_RUN_ATTEMPT"),
               "scope": {"production_pool_source_slice": True, "world_tick": False,
                         "godot_main": False, "production_stop_fence": False,
                         "native_busy_host_shutdown_qualified": False}, "errors": []}
    try:
        if args.local_source_excerpt:
            if os.getenv("GITHUB_ACTIONS") or args.expected_source:
                raise ValueError("local excerpt mode is forbidden for hosted/source-qualified execution")
            raw = args.local_source_excerpt.read_bytes()
            receipt["source_mode"] = "local_explicit_excerpt_not_full_checkout"
            receipt["excerpt_path"] = str(args.local_source_excerpt)
        else:
            head = git("rev-parse", "HEAD").decode().strip()
            if not args.expected_source or head != args.expected_source:
                raise ValueError("checkout must match explicit expected source SHA")
            git("diff", "--exit-code", "HEAD", "--", SOURCE, DRIVER, GATE, "tools/ci/run_play_busy001_pool.py")
            raw = git("show", "HEAD:" + SOURCE)
            receipt.update(source_mode="exact_git_checkout", source_sha=head,
                           source_tree=git("rev-parse", "HEAD^{tree}").decode().strip(),
                           source_blob=git("rev-parse", "HEAD:" + SOURCE).decode().strip())
        receipt["source_bytes_sha256"] = hashlib.sha256(raw).hexdigest()
        pool = extract_pool(raw)
        (output / "production-pool-excerpt.txt").write_bytes(pool)
        header = output / "play_busy001_source_pool.hpp"
        header.write_bytes(generated_header(pool))
        receipt["input_sha256"] = {
            path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
            for path in (DRIVER, GATE, "tools/ci/run_play_busy001_pool.py")}
        is_msvc = Path(args.compiler).name.lower() in ("cl", "cl.exe")
        binary = output / ("pool-test.exe" if os.name == "nt" else "pool-test")
        if is_msvc:
            if args.sanitize != "none":
                raise ValueError("this apparatus has no MSVC sanitizer-equivalence claim")
            command = [args.compiler, "/nologo", "/std:c++20", "/W4", "/WX", "/EHsc", "/O2",
                       "/I" + str(output), str(ROOT / DRIVER), "/Fe:" + str(binary),
                       "/Fo:" + str(output / "pool-test.obj")]
        else:
            command = [args.compiler, "-std=c++20", "-Wall", "-Wextra", "-Wconversion", "-Wshadow",
                       "-Wpedantic", "-Werror", "-pthread", "-O1", "-g", "-I" + str(output)]
            if args.sanitize != "none":
                sanitizer = "address,undefined" if args.sanitize == "address-undefined" else "thread"
                command += ["-fno-omit-frame-pointer", "-fsanitize=" + sanitizer]
            command += [str(ROOT / DRIVER), "-o", str(binary)]
        receipt["compile_command"] = command
        identity = subprocess.run([args.compiler] if is_msvc else [args.compiler, "--version"],
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15)
        (output / "compiler.txt").write_bytes(identity.stdout)
        invoke(command, output / "compile.log", 120)
        receipt["binary_sha256"] = hashlib.sha256(binary.read_bytes()).hexdigest()
        env = dict(os.environ)
        env.update(ASAN_OPTIONS="detect_leaks=1:halt_on_error=1", UBSAN_OPTIONS="halt_on_error=1",
                   TSAN_OPTIONS="halt_on_error=1")
        invoke([str(binary)], output / "execution.log", 30, env)
        text = (output / "execution.log").read_text(encoding="utf-8")
        rows = [json.loads(line.split(" ", 1)[1]) for line in text.splitlines()
                if line.startswith("PLAY_BUSY001_POOL_ROW ")]
        summaries = [json.loads(line.split(" ", 1)[1]) for line in text.splitlines()
                     if line.startswith("PLAY_BUSY001_POOL_RESULT ")]
        if len(rows) != 8 or len(summaries) != 1:
            raise ValueError("missing actual pool execution records")
        result = summaries[0]
        if result["failures"] or result["assertions"] != 169 or result["pool_class_sha256"] != POOL_SHA256:
            raise ValueError("actual pool assertion/source mismatch")
        for row in rows:
            if (row["held_at_test_stop"] < 2 or row["participants"] < 2 or row["timed_out"]
                    or not row["first_arrival"] < row["test_stop"] < row["release"] < row["drained"]):
                raise ValueError("positive dispatch lacks observed held-job ordering")
        after = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
                 for path in receipt["input_sha256"]}
        if after != receipt["input_sha256"]:
            raise ValueError("apparatus inputs changed during execution")
        if not args.local_source_excerpt:
            if git("rev-parse", "HEAD").decode().strip() != args.expected_source:
                raise ValueError("source HEAD moved during execution")
            git("diff", "--exit-code", "HEAD", "--", SOURCE, DRIVER, GATE, "tools/ci/run_play_busy001_pool.py")
        receipt.update(status="passed", result=result, dispatches=rows)
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        receipt["errors"].append(f"{type(error).__name__}: {error}")
    receipt["output_sha256"] = {
        path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in output.iterdir()
        if path.is_file() and path.name != "receipt.json"}
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("PLAY_BUSY001A", receipt["status"], *receipt["errors"], flush=True)
    return int(receipt["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
