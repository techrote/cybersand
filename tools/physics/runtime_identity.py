"""Selected desktop artifact identity for local physics measurements.

This snapshots configured bytes. It does not attest module loading, a published
runtime or compatibility between a native binary and the current source.
"""
from __future__ import annotations

import configparser
import hashlib
import json
import platform
import shutil
import subprocess
from pathlib import Path


def default_godot() -> Path:
    found = shutil.which("godot") or shutil.which("godot4")
    if found:
        return Path(found)
    if platform.system() == "Windows":
        return Path("C:/Godot47/Godot_v4.7-stable_win64_console.exe")
    return Path("godot")


def materialized_hashes(paths) -> dict[str, str]:
    result = {}
    for supplied in paths:
        path = Path(supplied).resolve(strict=True)
        if not path.is_file():
            raise ValueError(f"Artifact is not a regular file: {path}")
        with path.open("rb") as stream:
            if stream.read(128).startswith(b"version https://git-lfs.github.com/spec/v1"):
                raise ValueError(f"Artifact is an unmaterialized LFS pointer: {path}")
            stream.seek(0)
            result[str(path)] = hashlib.file_digest(stream, "sha256").hexdigest()
    return result


def fresh_output(path: Path) -> Path:
    path = path.resolve()
    path.mkdir(parents=True, exist_ok=False)
    return path


def selected_artifacts(root: Path, godot: Path, *, system=None, machine=None) -> tuple[list[Path], dict]:
    system = system or platform.system()
    machine = machine or platform.machine()
    if system not in {"Linux", "Windows"} or machine.lower() not in {"amd64", "x86_64"}:
        raise ValueError(f"No supported native desktop selection for {system}/{machine}")
    root = root.resolve()
    project = root / "godot"
    engine = Path(godot)
    if not engine.is_file():
        found = shutil.which(str(engine))
        if found:
            engine = Path(found)
    paths = [engine.resolve(strict=True)]
    descriptors = [project / "addons/cybersand_native/cybersand_native.gdextension",
                   project / "addons/godot-rapier2d/godot-rapier2d.gdextension"]
    for descriptor in descriptors:
        config = configparser.ConfigParser(interpolation=None, strict=True)
        with descriptor.open(encoding="utf-8") as stream:
            config.read_file(stream)
        prefix = system.lower()
        debug = config["libraries"][prefix + ".debug.x86_64"].strip('"')
        release = config["libraries"][prefix + ".release.x86_64"].strip('"')
        if debug != release:
            raise ValueError(f"Ambiguous editor/runtime library selection: {descriptor}")
        path = (project / debug[6:] if debug.startswith("res://") else descriptor.parent / debug).resolve()
        if not path.is_relative_to(project):
            raise ValueError(f"Selected extension leaves project: {descriptor}")
        paths.append(path)
    descriptor_hashes = materialized_hashes(descriptors)
    # Refuse missing or pointer-only bytes before starting an engine or fixture.
    materialized_hashes(paths)
    return paths, {"system": system, "machine": machine, "architecture": "x86_64",
                   "selection": "matching debug/release x86_64 GDExtension entries",
                   "descriptors": descriptor_hashes,
                   "scope": "Configured executable/library bytes; not loaded-module or source-to-binary attestation"}


def desktop_runtime(root: Path, godot: Path) -> tuple[list[Path], dict]:
    paths, selection = selected_artifacts(root, godot)
    lock = root / "third_party/godot-runtime.lock.json"
    expected = json.loads(lock.read_text(encoding="utf-8"))["godot_version"]
    probe = subprocess.run([str(paths[0]), "--version"], capture_output=True, text=True, timeout=15, check=True)
    observed = probe.stdout.strip()
    if observed != expected:
        raise ValueError(f"Godot version mismatch: expected {expected}, got {observed!r}")
    selection.update(godot_version=observed, version_command=[str(paths[0]), "--version"],
                     engine_lock=materialized_hashes([lock]))
    return paths, selection


def verify_unchanged(recorded: dict[str, str]) -> dict[str, str]:
    actual = materialized_hashes(recorded)
    if actual != recorded:
        changed = [p for p in recorded if actual.get(p) != recorded[p]]
        raise ValueError("Runtime identity changed during measurement: " + ", ".join(changed))
    return actual
