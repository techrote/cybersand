#!/usr/bin/env python3
"""Build one exact-source PUBPRES runtime; never relabel a retained DLL.

The driver may live in the candidate checkout while --source-root is a frozen
reference checkout. The build script and every native input come from that
reference. This receipt belongs to the experiment, not production provenance.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

from process_owner import bounded_process
import dependency_custody

SOURCE_DIRS = ("native/include", "native/src", "godot/native_extension")
SUFFIXES = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}
SCHEMA = "pubpres-playability-native-build-v1"


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def canonical_digest(data: bytes) -> str:
    return hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest()


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=root, text=True, timeout=120).strip()


def committed_inputs(root: Path, source: str) -> dict[str, str]:
    tracked = git(root, "ls-tree", "-r", "--name-only", source, "--", *SOURCE_DIRS).splitlines()
    wanted = sorted(name for name in tracked if Path(name).suffix in SUFFIXES)
    actual = sorted(p.relative_to(root).as_posix() for directory in SOURCE_DIRS
                    for p in (root / directory).rglob("*") if p.is_file() and p.suffix in SUFFIXES)
    if wanted != actual:
        raise ValueError("Native source set differs from the exact commit")
    result = {}
    for name in wanted:
        data = subprocess.check_output(["git", "show", source + ":" + name], cwd=root, timeout=120)
        expected = canonical_digest(data)
        if canonical_digest((root / name).read_bytes()) != expected:
            raise ValueError("Uncommitted native build input: " + name)
        result[name] = expected
    return result


def stamp() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--platform", choices=("linux", "windows"), required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=1800)
    args = parser.parse_args()
    root, output = args.source_root.resolve(), args.output_dir.resolve()
    if len(args.source_sha) != 40 or any(c not in "0123456789abcdef" for c in args.source_sha):
        raise ValueError("A full exact Git SHA is required")
    if git(root, "rev-parse", "HEAD") != args.source_sha:
        raise ValueError("Reference checkout HEAD differs")
    if output.exists():
        raise ValueError("Refusing to replace a previous build or its evidence")
    if args.timeout < 1 or args.timeout > 7200:
        raise ValueError("Build timeout must be within 1..7200 seconds")
    inputs = committed_inputs(root, args.source_sha)
    script = "tools/build_native_extension" + ("_windows" if args.platform == "windows" else "") + ".sh"
    expected_script = subprocess.check_output(["git", "show", args.source_sha + ":" + script], cwd=root, timeout=120)
    if canonical_digest(expected_script) != canonical_digest((root / script).read_bytes()):
        raise ValueError("Build script differs from the exact commit")
    cpp_root = Path(os.environ["GODOT_CPP_ROOT"]).resolve()
    library = Path(os.environ.get("GODOT_CPP_LIBRARY", str(cpp_root / "bin" /
                   f"libgodot-cpp.{args.platform}.template_debug.x86_64.a"))).resolve()
    # Force the exact variable consumed by that source's native shell script.
    # Recording a guessed fallback could attest to a different compiler.
    compiler_key = "WINDOWS_CXX" if args.platform == "windows" else "LINUX_CXX"
    compiler = os.environ[compiler_key]
    runtime_name = "cybersand_native.windows.x86_64.dll" if args.platform == "windows" else "libcybersand_native.linux.x86_64.so"
    record = {
        "schema": SCHEMA, "platform": args.platform, "source_commit": args.source_sha,
        "source_tree": git(root, "rev-parse", "HEAD^{tree}"),
        "source_inputs_sha256": inputs, "build_script": script,
        "build_script_sha256": canonical_digest(expected_script),
        "driver_sha256": canonical_digest(Path(__file__).read_bytes()),
        "driver_inputs_sha256": {name: canonical_digest(Path(__file__).with_name(name).read_bytes())
                                 for name in dependency_custody.DRIVER_FILES},
        "godot_cpp_commit": git(cpp_root, "rev-parse", "HEAD"),
        "godot_cpp_library_sha256": digest(library),
        "compiler_command": compiler,
        "compiler_version": subprocess.check_output([compiler, "--version"], text=True, timeout=30).strip(),
        "toolchain_drift_allowed": os.environ.get("CYBERSAND_ALLOW_TOOLCHAIN_DRIFT", "0") == "1",
        "runtime_file": runtime_name, "started_at": stamp(), "returncode": None,
        "production_runtime_promotion": False,
    }
    output.mkdir(parents=True)
    environment = dict(os.environ, CYBERSAND_NATIVE_OUTPUT=str(output / runtime_name))
    log = output / "build.log"
    try:
        dependency = dependency_custody.capture(cpp_root, library, args.platform, output, Path(__file__).resolve().parents[2])
        record["godot_cpp_dependency_sha256"] = digest(output / dependency_custody.FILES[0])
        with log.open("w", encoding="utf-8") as stream:
            returncode, timed_out = bounded_process(["bash", script], cwd=root,
                env=environment, stdout=stream, timeout=args.timeout)
        record.update(returncode=returncode, timed_out=timed_out)
        if returncode == 0:
            if committed_inputs(root, args.source_sha) != inputs or git(root, "rev-parse", "HEAD") != args.source_sha:
                raise ValueError("Build source changed during compilation")
            if canonical_digest((root / script).read_bytes()) != record["build_script_sha256"]:
                raise ValueError("Build script changed during compilation")
            if digest(library) != record["godot_cpp_library_sha256"]:
                raise ValueError("godot-cpp library changed during compilation")
            if dependency_custody.inputs(cpp_root) != dependency["source_inputs_sha256"]:
                raise ValueError("godot-cpp authored/generated inputs changed during compilation")
            dependency_custody.verify_driver(Path(__file__).parent, record)
            record.update(runtime_sha256=digest(output / runtime_name),
                          runtime_bytes=(output / runtime_name).stat().st_size)
    except Exception as error:
        record.update(returncode=1, error=f"{type(error).__name__}: {error}")
    except BaseException as error:
        record.update(returncode=130, terminal_interruption=f"{type(error).__name__}: {error}")
        raise
    finally:
        record.update(completed_at=stamp(), log_sha256=digest(log) if log.exists() else None)
        (output / "PUBPRES-RUNTIME.json").write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({key: record.get(key) for key in ("source_commit", "platform", "returncode", "runtime_sha256", "error")}))
    return int(record["returncode"])


if __name__ == "__main__":
    sys.exit(main())
