"""Bind the reciprocal generator in a Windows evaluator to its source and executable."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from swarm45.runtime_custody import definition_inputs


WINDOWS_CLI = "godot/tools/gentek_reciprocal.exe"
WINDOWS_BINDING = "godot/tools/swarm004-runtime.windows.json"
FOREIGN_PATHS = frozenset({"godot/tools/gentek_reciprocal", "godot/tools/swarm004-runtime.linux.json"})


def committed_binding(source_root: Path) -> bytes:
    return subprocess.check_output(["git", "show", "HEAD:" + WINDOWS_BINDING], cwd=source_root, timeout=60)


def check_executable(path: Path, binding: dict) -> None:
    if (binding.get("platform") != "windows" or binding.get("artifact") != WINDOWS_CLI
            or not path.is_file() or path.is_symlink() or path.stat().st_size != binding.get("bytes")
            or hashlib.sha256(path.read_bytes()).hexdigest() != binding.get("sha256")):
        raise ValueError("Windows reciprocal executable differs from its source binding")


def windows_cli_replacement(source_root: Path) -> dict[str, Path]:
    binding = json.loads(committed_binding(source_root))
    if binding.get("native_definition_inputs_sha256") != definition_inputs(source_root):
        raise ValueError("Windows reciprocal generator definition differs from the packaged source")
    cli = source_root / WINDOWS_CLI
    check_executable(cli, binding)
    return {WINDOWS_CLI: cli}


def verify_package(package_root: Path, source_root: Path) -> None:
    verify_bound_package(package_root, hashlib.sha256(committed_binding(source_root)).hexdigest())


def verify_bound_package(package_root: Path, binding_sha256: str | None) -> None:
    if any((package_root / name).exists() for name in FOREIGN_PATHS):
        raise ValueError("Windows evaluator contains a Linux reciprocal generator or binding")
    packaged = package_root / WINDOWS_BINDING
    if binding_sha256 is None:
        if packaged.exists() or (package_root / WINDOWS_CLI).exists():
            raise ValueError("Reciprocal generator has no admitted source binding")
        return
    if packaged.is_symlink() or not packaged.is_file():
        raise ValueError("Packaged Windows reciprocal binding missing")
    canonical = packaged.read_bytes().replace(b"\r\n", b"\n")
    if hashlib.sha256(canonical).hexdigest() != binding_sha256:
        raise ValueError("Packaged Windows reciprocal binding differs from the committed source")
    check_executable(package_root / WINDOWS_CLI, json.loads(canonical))
