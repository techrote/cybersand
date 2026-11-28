#!/usr/bin/env python3
"""Source-exact staging and identity for optional supplementary observers."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

from execution_contract import ROOT, verify_execution_derivation
from presentation_metrics import PROBE, validate_presentation, validate_cpu_trace

DIRECTORY = "tools/pubpres_final_observers"


def identity(root: Path = ROOT) -> dict:
    root = root.resolve()
    folder = root / DIRECTORY
    names = subprocess.check_output(["git", "-C", str(root), "ls-tree", "-r", "--name-only", "HEAD", "--", DIRECTORY], text=True).splitlines()
    tracked = {name for name in names if Path(name).suffix in (".py", ".gd")}
    actual = {path.relative_to(root).as_posix() for path in folder.iterdir() if path.is_file() and path.suffix in (".py", ".gd")}
    if not tracked or tracked != actual:
        raise ValueError("Supplementary observer source inventory is missing or uncommitted")
    hashes = {}
    for name in sorted(tracked):
        committed = subprocess.check_output(["git", "-C", str(root), "show", "HEAD:" + name])
        live = (root / name).read_bytes()
        if live != committed:
            raise ValueError("Supplementary observer differs from committed bytes: " + name)
        hashes[name] = hashlib.sha256(live).hexdigest()
    return {"schema": "pubpres-final-observer-bundle-v1", "files_sha256": hashes,
            "execution_derivation": verify_execution_derivation(root),
            "scope": "Explicit supplementary Main presentation and whole-process CPU observations; frozen physical gates and production defaults unchanged."}


def stage(project: Path, root: Path = ROOT) -> Path:
    identity(root)
    destination = project / PROBE
    if destination.exists():
        raise ValueError("Supplementary observer would overwrite project source")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / DIRECTORY / "presentation_probe.gd", destination)
    return destination


def validate(receipt: Path, process: dict, project: Path, root: Path = ROOT) -> dict:
    base = json.loads(receipt.read_bytes())
    return {"bundle": identity(root),
            "presentation": validate_presentation(receipt.with_name(receipt.stem + "-presentation.json"), receipt, project),
            "cpu": validate_cpu_trace(receipt.parent / "process-cpu.json", process, base, root)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", required=True)
    parser.parse_args()
    print(json.dumps(identity(), indent=2))
