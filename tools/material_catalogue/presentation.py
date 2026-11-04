#!/usr/bin/env python3
"""Generate the bounded Main display-name table, independently of full shadows.

All catalogue and presentation inputs are validated before any publication.
Only the two fixed output paths are writable; --check never writes. The
generated script contains labels only, with no native or fallback physics data.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

import compiler

ROOT = Path(__file__).resolve().parents[2]
SCHEMA_ID = "cybersand.material-catalogue.presentation"
SCHEMA_VERSION = 1
GENERATOR_VERSION = 1
MANIFEST_VERSION = 1
CATALOGUE = "materials/catalogue/catalogue.json"
PRESENTATION = "materials/catalogue/presentation.json"
GENERATOR = "tools/material_catalogue/presentation.py"
COMPILER = "tools/material_catalogue/compiler.py"
SCRIPT = "godot/scripts/generated/material_ui_names.gd"
MANIFEST = "materials/catalogue/presentation-manifest.json"
CONSUMER = "godot/scripts/main.gd::material_name"
INPUTS = (CATALOGUE, PRESENTATION, GENERATOR, COMPILER)
OUTPUTS = (SCRIPT, MANIFEST)
BUDGETS = {SCRIPT: 16 * 1024, MANIFEST: 32 * 1024}
OVERRIDES = {
    80: "LED white",
    83: "rough oak log",
    113: "galvanised zinc sheet",
    117: "bare iron plate",
    131: "heat-shield tile",
}
# Frozen schema-1 [numeric ID, canonical name] registry, independent of labels.
# Changing an ID/name, admitting ID132 or authoring invalid10 needs new scope.
IDENTITY_SHA256 = "e995175126f5df1dca9a9320bd121e9e8eb3f20acefb5d58d3313c41f524e370"


class PresentationError(ValueError):
    """Invalid source, stale generated output or unsafe publication request."""


def lf(data: bytes) -> bytes:
    return data.replace(b"\r\n", b"\n")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


EXECUTED_TOOLS = {
    GENERATOR: sha(lf(Path(__file__).read_bytes())),
    COMPILER: compiler.GENERATOR_SHA256,
}


def _paths(root: Path) -> None:
    """Refuse aliases before reading/staging and again before publication."""
    for relative in (*INPUTS, *OUTPUTS):
        path = root / relative
        for parent in (path, *path.parents):
            if parent == root:
                break
            if parent.is_symlink():
                raise PresentationError(f"{relative}: symlink aliases are not allowed")
        if path.exists() and not path.is_file():
            raise PresentationError(f"{relative}: expected a regular file")
        if relative in OUTPUTS and path.exists() and path.stat().st_nlink != 1:
            raise PresentationError(f"{relative}: hard-linked outputs are not allowed")
        if relative in INPUTS and not path.is_file():
            raise PresentationError(f"{relative}: required input is missing")


def _capture(root: Path) -> dict[str, bytes]:
    _paths(root)
    inputs = {relative: (root / relative).read_bytes() for relative in INPUTS}
    for relative, expected in EXECUTED_TOOLS.items():
        if sha(lf(inputs[relative])) != expected:
            raise PresentationError(f"{relative}: selected source differs from executing tool")
    return inputs


def _unchanged(root: Path, inputs: dict[str, bytes]) -> None:
    _paths(root)
    for relative, before in inputs.items():
        if (root / relative).read_bytes() != before:
            raise PresentationError(f"{relative}: input changed during presentation generation")


def _overrides(path: Path) -> dict[int, str]:
    # The existing strict parser preserves duplicate keys and JSON pointers;
    # its complete source fingerprint is part of this generator's manifest.
    validator = compiler._Validator(path)
    source = compiler._read_json(path, validator)
    validator.object(source, "", ("schema_id", "schema_version", "overrides"))
    validator.equal(source["schema_id"], SCHEMA_ID, "/schema_id")
    validator.equal(source["schema_version"], SCHEMA_VERSION, "/schema_version")
    rows = validator.array(source["overrides"], "/overrides")
    result: dict[int, str] = {}
    origins: dict[int, str] = {}
    for index, row in enumerate(rows):
        pointer = f"/overrides/{index}"
        validator.object(row, pointer, ("id", "display_name"))
        material_id = validator.integer(row["id"], pointer + "/id", 0, 131)
        if material_id not in OVERRIDES:
            validator.fail(pointer + "/id", "only the five admitted UI exceptions may be authored; invalid10 is reserved")
        if material_id in result:
            validator.fail(pointer + "/id", "duplicate override ID", origins[material_id])
        name = validator.string(row["display_name"], pointer + "/display_name")
        validator.equal(name, OVERRIDES[material_id], pointer + "/display_name")
        result[material_id] = name
        origins[material_id] = pointer + "/id"
    validator.array(rows, "/overrides", len(OVERRIDES))
    if set(result) != set(OVERRIDES):
        validator.fail("/overrides", "all five admitted UI exceptions are required")
    return result


def _fact(relative: str, content: bytes) -> dict:
    return {"path": relative, "lf_bytes": len(lf(content)), "lf_sha256": sha(lf(content))}


def _render(root: Path) -> tuple[dict[str, bytes], dict[str, bytes]]:
    inputs = _capture(root)
    try:
        catalogue = compiler.load_catalogue(root / CATALOGUE, isolated=False)
        overrides = _overrides(root / PRESENTATION)
    except compiler.CatalogueError as error:
        raise PresentationError(str(error)) from error
    _unchanged(root, inputs)
    materials = catalogue["native"]["materials"]
    identities = [[row["id"], row["name"]] for row in materials]
    identity_bytes = json.dumps(identities, ensure_ascii=True, separators=(",", ":")).encode("utf-8")
    if len(materials) != 132 or sha(identity_bytes) != IDENTITY_SHA256:
        raise PresentationError(f"{CATALOGUE}#/native/materials: frozen 132-slot ID/name registry changed")
    if catalogue["native"]["identity"]["reserved_ids"] != [10] or any(
        row["id"] != index or row["valid"] != (index != 10)
        for index, row in enumerate(materials)
    ):
        raise PresentationError(f"{CATALOGUE}#/native: ID10 must remain the only invalid slot")
    names = ["" if row["id"] == 10 else overrides.get(row["id"], row["name"].replace("-", " "))
             for row in materials]
    lines = [
        "# Generated by tools/material_catalogue/presentation.py. Do not edit.",
        "# Labels only: Main.material_name() owns bounds and unknown-ID formatting.",
        "# Reserved ID10 has an empty sentinel; it is never a public display name.",
        "extends RefCounted", "", "const NAMES: Array[String] = [",
        *("\t" + json.dumps(name, ensure_ascii=False) + f", # {index}"
          for index, name in enumerate(names)),
        "]", "",
    ]
    script = "\n".join(lines).encode("utf-8")
    manifest = {
        "schema_id": SCHEMA_ID + ".manifest",
        "schema_version": MANIFEST_VERSION,
        "presentation_schema_version": SCHEMA_VERSION,
        "generator_version": GENERATOR_VERSION,
        "scope": "ui-labels-only",
        "consumer": CONSUMER,
        "allocated_slots": 132,
        "reserved_ids": [10],
        "normalization": "canonical hyphens become spaces; exactly five validated UI exceptions",
        "identity_sha256": IDENTITY_SHA256,
        "labels_sha256": sha(compiler.canonical_json(names)),
        "source_hash_encoding": "UTF-8 with CRLF normalized to LF",
        "inputs": [_fact(path, inputs[path]) for path in (CATALOGUE, PRESENTATION)],
        "tool_sources": [_fact(path, inputs[path]) for path in (GENERATOR, COMPILER)],
        "artifacts": [{"path": SCRIPT, "bytes": len(script), "sha256": sha(script)}],
        "maximum_bytes": BUDGETS,
    }
    outputs = {SCRIPT: script, MANIFEST: compiler.canonical_json(manifest)}
    for relative, content in outputs.items():
        if len(content) > BUDGETS[relative]:
            raise PresentationError(f"{relative}: {len(content)} bytes exceeds {BUDGETS[relative]}-byte budget")
    return outputs, inputs


def render(root: Path = ROOT) -> dict[str, bytes]:
    """Return validated output bytes, without creating or changing any file."""
    return _render(Path(root).resolve())[0]


def check(root: Path = ROOT) -> dict:
    """Fail on missing/stale/invalid output, without repairing or touching it."""
    root = Path(root).resolve()
    outputs, inputs = _render(root)
    for relative, expected in outputs.items():
        path = root / relative
        if not path.exists():
            raise PresentationError(f"{relative}: generated output is missing; run presentation.py")
        if path.read_bytes() != expected:
            raise PresentationError(f"{relative}: generated output is stale or invalid; run presentation.py")
    _unchanged(root, inputs)
    return {"status": "PASS", "schema_id": SCHEMA_ID, "schema_version": SCHEMA_VERSION,
            "consumer": CONSUMER,
            "artifacts": [{"path": path, "bytes": len(content), "sha256": sha(content)}
                          for path, content in sorted(outputs.items())]}


def generate(root: Path = ROOT) -> list[str]:
    """Stage the complete validated set, then atomically replace changed files.

The outputs live in separate directories: each replacement is atomic and a
publication failure restores every already-replaced file. No invalid input can
publish either output. Unchanged outputs retain their inode, bytes and mtime.
"""
    root = Path(root).resolve()
    outputs, inputs = _render(root)
    changed = [path for path, content in outputs.items()
               if not (root / path).exists() or (root / path).read_bytes() != content]
    if not changed:
        return []
    stages: dict[str, Path] = {}
    backups: dict[str, Path] = {}
    replaced: list[str] = []
    created_directories: list[Path] = []
    preserve_backups = False
    try:
        for relative in changed:
            destination = root / relative
            missing = []
            for parent in destination.parents:
                if parent.exists():
                    break
                missing.append(parent)
            for parent in reversed(missing):
                parent.mkdir()
                created_directories.append(parent)
            _paths(root)
            descriptor, temporary = tempfile.mkstemp(prefix=".presentation-stage-", dir=destination.parent)
            stage = stages[relative] = Path(temporary)
            with os.fdopen(descriptor, "wb") as output:
                output.write(outputs[relative])
                output.flush()
                os.fsync(output.fileno())
            stage.chmod(destination.stat().st_mode & 0o777 if destination.exists() else 0o644)
            if destination.exists():
                descriptor, temporary = tempfile.mkstemp(prefix=".presentation-previous-", dir=destination.parent)
                os.close(descriptor)
                backup = backups[relative] = Path(temporary)
                shutil.copy2(destination, backup)
        _unchanged(root, inputs)
        try:
            for relative in changed:
                _unchanged(root, inputs)
                os.replace(stages[relative], root / relative)
                replaced.append(relative)
        except BaseException:
            for relative in reversed(replaced):
                try:
                    if relative in backups:
                        os.replace(backups[relative], root / relative)
                    else:
                        (root / relative).unlink()
                except OSError as error:
                    preserve_backups = True
                    raise PresentationError(
                        "presentation publication rollback failed; retained .presentation-previous-* backups "
                        f"require recovery: {error}") from error
            raise
    finally:
        for path in stages.values():
            path.unlink(missing_ok=True)
        if not preserve_backups:
            for path in backups.values():
                path.unlink(missing_ok=True)
        if len(replaced) != len(changed):
            for path in reversed(created_directories):
                if path.exists() and not any(path.iterdir()):
                    path.rmdir()
    return changed


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT,
                        help="complete source root; input and output paths are fixed")
    parser.add_argument("--check", action="store_true", help="nonwriting output/source-custody validation")
    arguments = parser.parse_args(argv)
    try:
        if arguments.check:
            print(json.dumps(check(arguments.root), indent=2, sort_keys=True))
        else:
            changed = generate(arguments.root)
            print(f"material presentation: {len(changed)} changed artifacts; labels only")
    except (OSError, ValueError, RuntimeError) as error:
        print(f"material presentation: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
