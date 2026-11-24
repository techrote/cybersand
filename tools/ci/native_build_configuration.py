#!/usr/bin/env python3
"""Invalidate local reusable native objects when their compiler contract changes.

This is invoked only by an ordinary Make recipe, never by Make expansion or
inventory dry-runs. It does not restore a cache or accept previous test results.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile

ENVIRONMENT = ("PATH", "CPATH", "CPLUS_INCLUDE_PATH", "C_INCLUDE_PATH", "LIBRARY_PATH",
               "COMPILER_PATH", "GCC_EXEC_PREFIX", "SOURCE_DATE_EPOCH", "GCC_COMPARE_DEBUG")


def file_identity(path: str) -> dict:
    resolved = Path(path).resolve(strict=True)
    if not resolved.is_file():
        raise ValueError("Compiler component is not a regular file: " + str(resolved))
    return {"path": str(resolved), "sha256": hashlib.sha256(resolved.read_bytes()).hexdigest()}


def configuration(compiler: str, flags: str, inputs: str) -> dict:
    argv = shlex.split(compiler)
    if not argv:
        raise ValueError("Empty C++ compiler")
    programs = {}
    for token in argv:
        resolved = shutil.which(token) if not token.startswith("-") else None
        if resolved is None and Path(token).is_file():
            resolved = token
        if resolved:
            programs[token] = file_identity(resolved)
    if argv[0] not in programs:
        raise ValueError("C++ compiler executable cannot be resolved")

    def query(option: str) -> str:
        result = subprocess.run([*argv, *shlex.split(flags), option], text=True, capture_output=True,
                                check=True, timeout=30)
        value = result.stdout.strip()
        if not value:
            raise ValueError("Empty compiler identity response: " + option)
        return value

    reported = {name: query(name) for name in ("--version", "-dumpmachine", "-dumpfullversion")}
    for name in ("cc1plus", "ld"):
        path = query("-print-prog-name=" + name)
        resolved = shutil.which(path) or path
        programs[name] = file_identity(resolved)
    return {"schema": "cybersand-local-native-build-configuration-v1",
            "compiler": argv, "flags": shlex.split(flags), "programs": programs,
            "reported": reported,
            "inputs": {name: file_identity(name) for name in shlex.split(inputs)},
            "environment": {name: os.environ.get(name, "") for name in ENVIRONMENT}}


def update(output: Path, record: dict) -> bool:
    data = (json.dumps(record, sort_keys=True, indent=2) + "\n").encode()
    if output.is_file() and output.read_bytes() == data:
        return False
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=output.parent, prefix=output.name + ".", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, output)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        changed = update(args.output, configuration(os.environ["CYBERSAND_BUILD_CXX"],
                                                   os.environ["CYBERSAND_BUILD_FLAGS"],
                                                   os.environ["CYBERSAND_BUILD_INPUTS"]))
        print("Local native compiler configuration: " + ("changed" if changed else "unchanged"))
        return 0
    except (KeyError, ValueError, OSError, subprocess.SubprocessError) as error:
        print("Cannot establish local native compiler configuration: " + str(error))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
