#!/usr/bin/env python3
"""Build the ordinary pinned extension and retain its actual input/output custody."""
from __future__ import annotations
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SUFFIXES = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_inputs() -> dict[str, str]:
    result = {}
    for directory in ("native/include", "native/src", "godot/native_extension"):
        for path in sorted((ROOT / directory).rglob("*")):
            if path.is_file() and path.suffix in SUFFIXES:
                result[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=("linux", "windows"), required=True)
    parser.add_argument("--ledger", type=Path, required=True)
    args = parser.parse_args()
    args.ledger.parent.mkdir(parents=True, exist_ok=True)
    def git(*parts):
        return subprocess.check_output(["git", *parts], cwd=ROOT, text=True).strip()
    inputs = source_inputs()
    for path, expected in inputs.items():
        committed = subprocess.check_output(["git", "show", "HEAD:" + path], cwd=ROOT)
        if hashlib.sha256(committed.replace(b"\r\n", b"\n")).hexdigest() != expected:
            raise ValueError("Uncommitted native build input: " + path)
    script = "tools/build_native_extension" + ("_windows" if args.platform == "windows" else "") + ".sh"
    runtime = Path(os.environ.get("CYBERSAND_NATIVE_OUTPUT", str(ROOT / "godot/addons/cybersand_native/bin" / (
        "cybersand_native.windows.x86_64.dll" if args.platform == "windows" else "libcybersand_native.linux.x86_64.so")))).resolve()
    cpp_root = Path(os.environ["GODOT_CPP_ROOT"]).resolve()
    library = Path(os.environ.get("GODOT_CPP_LIBRARY", str(cpp_root / "bin" / ("libgodot-cpp." + args.platform + ".template_debug.x86_64.a"))))
    compiler = os.environ.get("WINDOWS_CXX" if args.platform == "windows" else "LINUX_CXX", "g++")
    record = {"schema": "gentek80-native-build-v1", "platform": args.platform,
              "source_commit": git("rev-parse", "HEAD"), "source_tree": git("rev-parse", "HEAD^{tree}"),
              "source_inputs_sha256": inputs, "runtime_path": str(runtime),
              "command": ["bash", script], "build_script_sha256": digest(ROOT / script),
              "godot_cpp_library_sha256": digest(library), "compiler_command": compiler,
              "compiler_version": subprocess.check_output([compiler, "--version"], text=True).strip(),
              "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "returncode": None}
    log = args.ledger.with_suffix(".log")
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run(record["command"], cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    record.update({"returncode": result.returncode, "completed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "log_sha256": digest(log)})
    if result.returncode == 0:
        if source_inputs() != inputs or digest(library) != record["godot_cpp_library_sha256"] or digest(ROOT / script) != record["build_script_sha256"]:
            record["returncode"] = 1
            record["error"] = "Build inputs changed during compilation"
        else:
            record.update({"runtime_sha256": digest(runtime), "runtime_bytes": runtime.stat().st_size})
    args.ledger.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({k: record.get(k) for k in ("source_commit", "platform", "returncode", "runtime_sha256")}))
    return int(record["returncode"])


if __name__ == "__main__":
    sys.exit(main())
