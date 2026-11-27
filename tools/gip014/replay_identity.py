"""Portable semantic replay identity over exact source and shipped game inputs.

Incidental host/Python metadata stays in provenance. Only the four existing
Rapier import-descriptor CRLF normalizations are allowed; all other game input
bytes remain exact. Platform-irrelevant binaries are excluded just as packaging
excludes them. Physical trajectories are not declared cross-platform identical.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re

SCHEMA = "cybersand-goblin-replay-identity-v1"
NORMALIZATION = "existing-four-rapier-import-descriptors-crlf-to-lf"
IMPORT_DESCRIPTORS = frozenset({"addons/godot-rapier2d/Radial2D.svg.import", "addons/godot-rapier2d/icons/Fluid2D.svg.import",
                                "addons/godot-rapier2d/icons/StateManager2D.svg.import", "addons/godot-rapier2d/logo_square_2d.png.import"})
RUNTIME_FILES = {
    "linux": {"addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so", "addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"},
    "windows": {"addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll", "addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"},
}
RECIPROCAL_FILES = {
    "linux": {"tools/gentek_reciprocal", "tools/swarm004-runtime.linux.json"},
    "windows": {"tools/gentek_reciprocal.exe", "tools/swarm004-runtime.windows.json"},
}
AUTHORITY = ("source_commit", "source_tree", "platform", "godot_sha256", "native_sha256", "rapier_sha256")


def platform_game_input(name: str, platform: str) -> bool:
    """Use the same platform payload in source campaign and extracted evaluator."""
    if "/bin/" in name:
        return name in RUNTIME_FILES[platform]
    other_platform = "linux" if platform == "windows" else "windows"
    return name not in RECIPROCAL_FILES[other_platform]


def game_inputs(project: Path, platform: str, names=None) -> dict:
    if platform not in RUNTIME_FILES:
        raise ValueError("Replay identity requires the qualified Linux or Windows platform")
    if names is None:
        names = [p.relative_to(project).as_posix() for p in project.rglob("*") if p.is_file()]
    entries = {}
    for name in sorted(names):
        parts = Path(name).parts
        if ".godot" in parts or "__pycache__" in parts or name.endswith((".tmp", ".log")):
            continue
        if not platform_game_input(name, platform):
            continue
        path = project / name
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(project.resolve()):
            raise ValueError("Replay input is missing, linked or outside the project")
        data = path.read_bytes()
        if name in IMPORT_DESCRIPTORS:
            data = data.replace(b"\r\n", b"\n")
        entries[name] = hashlib.sha256(data).hexdigest()
    if not IMPORT_DESCRIPTORS <= entries.keys() or not RUNTIME_FILES[platform] <= entries.keys():
        raise ValueError("Replay source manifest lacks required game inputs")
    return entries


def build(provenance: dict, project: Path, names=None) -> dict:
    entries = game_inputs(project, provenance["platform"], names)
    encoded = json.dumps(entries, sort_keys=True, separators=(",", ":")).encode()
    return {"schema": SCHEMA, **{k: provenance[k] for k in AUTHORITY},
            "game_sources_sha256": hashlib.sha256(encoded).hexdigest(), "game_source_files": len(entries),
            "import_normalization": NORMALIZATION}


def valid(provenance) -> bool:
    if not isinstance(provenance, dict):
        return False
    identity = provenance.get("replay_identity")
    if not isinstance(identity, dict) or set(identity) != {"schema", *AUTHORITY, "game_sources_sha256", "game_source_files", "import_normalization"}:
        return False
    if identity["schema"] != SCHEMA or identity["platform"] not in RUNTIME_FILES or identity["import_normalization"] != NORMALIZATION:
        return False
    if type(provenance.get("source_dirty")) is not bool or type(identity["game_source_files"]) is not int or not 1 <= identity["game_source_files"] <= 100000:
        return False
    for key in AUTHORITY:
        if identity[key] != provenance.get(key):
            return False
    for key, size in (("source_commit", 40), ("source_tree", 40), ("godot_sha256", 64), ("native_sha256", 64), ("rapier_sha256", 64), ("game_sources_sha256", 64)):
        if not isinstance(identity[key], str) or re.fullmatch("[0-9a-f]{%d}" % size, identity[key]) is None:
            return False
    return True


def same(first, second) -> bool:
    if not isinstance(first, dict) or not isinstance(second, dict):
        return False
    if "replay_identity" in first or "replay_identity" in second:
        return valid(first) and valid(second) and first["replay_identity"] == second["replay_identity"] and first["source_dirty"] == second["source_dirty"]
    return first == second
