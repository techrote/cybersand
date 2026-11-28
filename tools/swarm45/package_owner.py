#!/usr/bin/env python3
"""Stage a Draft/HOLD evaluator using the exact built Windows CLI and adapter."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import zipfile

import runtime_custody as custody
from shared import load


def verify_extracted_zip(archive: Path, directory: Path, manifest: dict) -> None:
    """Bind the actual extracted bytes to the archived evaluator, without Git."""
    with zipfile.ZipFile(archive) as zipped:
        records = {}
        for item in zipped.infolist():
            name = item.filename
            pure = PurePosixPath(name)
            custody.require(not pure.is_absolute() and ".." not in pure.parts and "\\" not in name,
                            "Unsafe evaluator ZIP member")
            if item.is_dir():
                continue
            custody.require(name not in records, "Duplicate evaluator ZIP member")
            records[name] = hashlib.sha256(zipped.read(item)).hexdigest()
    expected = dict(manifest["files_sha256"], **{"candidate-manifest.json": custody.sha(directory / "candidate-manifest.json")})
    custody.require(records == expected, "Extracted evaluator does not match the actual ZIP inventory")
    custody.verify_inventory(directory, records)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--engine-notices", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--vc-runtime", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--readme", default="docs/operations/swarm456-owner-acceptance.md")
    args = parser.parse_args()
    receipt = custody.verify(args.runtime)
    custody.require(receipt["platform"] == "windows", "Evaluator requires the Windows source-built runtime")
    subprocess.run([sys.executable, str(custody.ROOT / "tools/package_explore001_candidate.py"),
                    "--engine", str(args.engine), "--engine-notices", str(args.engine_notices),
                    "--native-candidate", str(args.runtime), "--vc-runtime", str(args.vc_runtime),
                    "--output", str(args.output), "--readme", args.readme], cwd=custody.ROOT, check=True, timeout=240)
    destination = args.output / "godot/tools"
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(args.runtime / receipt["cli"], destination / receipt["cli"])
    shutil.copyfile(args.runtime / custody.NAME, args.output / custody.NAME)
    binding = custody.cli_binding(receipt)
    custody.write_json(destination / "swarm004-runtime.windows.json", binding)
    custody.write_json(destination / "swarm004-runtime.json", binding)
    custody.require(not (destination / "gentek_reciprocal").exists()
                    and not (destination / "swarm004-runtime.linux.json").exists(), "Windows evaluator contains a foreign runtime")
    load("swarm45_launcher_binding", "tools/swarm005/package_owner.py").bind_owner_launcher(args.output)
    comparison = (custody.ROOT / "tools/swarm006/compare_saved_setup.ps1").read_text(encoding="utf-8")
    replacements = {
        '"4e8ff0b01043d9e1bed336559b17e37283094add"': '"' + receipt["source_commit"] + '"',
        '"0db65201955dfe1d8be518feb66de3812d1d2ec8fe70e450e338f007510c60d3"': '"' + binding["sha256"] + '"',
        'godot\\tools\\swarm004-runtime.json': 'godot\\tools\\swarm004-runtime.windows.json',
        "SWARM006 4e8ff0b0 owner package": "unified source-bound owner package",
    }
    for old, new in replacements.items():
        custody.require(old in comparison, "Frozen comparison template changed: " + old)
        comparison = comparison.replace(old, new)
    (args.output / "Compare saved setup.ps1").write_text(comparison, encoding="utf-8-sig", newline="\r\n")
    path = args.output / "candidate-manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    records = custody.inventory(args.output)
    del records[path.name]
    manifest.update(programme="GENTEK-SWARM-006", qualification_programme=custody.QUALIFICATION_PROGRAMME,
                    runtime_programme=custody.PROGRAMME, native_definition_sha256=receipt["native_definition_sha256"],
                    draft_hold=True, owner_visual_acceptance="pending",
                    reciprocal_programme_acceptance=False, reciprocal_cli_sha256=receipt["files"][receipt["cli"]]["sha256"],
                    runtime_manifest_sha256=custody.sha(args.runtime / custody.NAME), files_sha256=records,
                    qualification_receipts="Exact-source and pristine ZIP Windows runs; physical owner acceptance remains separate")
    custody.write_json(path, manifest)
    print(path)


if __name__ == "__main__":
    main()
