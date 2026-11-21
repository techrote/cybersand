#!/usr/bin/env python3
"""Add the source-matched reciprocal executable to the established owner package."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

import runtime_custody as custody


def bind_owner_launcher(directory: Path) -> None:
    """Owner launch must use the bundled manifest, as pristine qualification does."""
    launcher = directory / "Open Workbench.cmd"
    text = launcher.read_text(encoding="utf-8")
    anchor = 'cd /d "%~dp0"\n'
    if text.count(anchor) != 1:
        raise ValueError("Unexpected owner launcher; refusing an unbound generator environment")
    overrides = "".join(f'set "{name}="\n' for name in (
        "CYBERSAND_SWARM004_CLI", "CYBERSAND_SWARM004_SOURCE", "CYBERSAND_SWARM004_SHA256"))
    launcher.write_text(text.replace(anchor, anchor + overrides), encoding="utf-8", newline="\r\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--engine-notices", type=Path, required=True)
    parser.add_argument("--native-candidate", type=Path, required=True)
    parser.add_argument("--vc-runtime", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    receipt = custody.verify(args.native_candidate)
    subprocess.run([sys.executable, str(custody.ROOT / "tools/package_explore001_candidate.py"),
                    "--engine", str(args.engine), "--engine-notices", str(args.engine_notices),
                    "--native-candidate", str(args.native_candidate), "--vc-runtime", str(args.vc_runtime),
                    "--output", str(args.output), "--readme", "docs/operations/swarm004-workbench-playtest.md"],
                   cwd=custody.ROOT, check=True, timeout=180)
    destination = args.output / "godot/tools"
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(args.native_candidate / custody.CLI, destination / custody.CLI)
    shutil.copyfile(args.native_candidate / custody.NAME, args.output / custody.NAME)
    runtime = {"schema": 1, "programme": "GENTEK-SWARM-005", "draft_hold": True,
               "source": receipt["source_commit"], "sha256": receipt["files"][custody.CLI]["sha256"]}
    (destination / "swarm004-runtime.json").write_text(json.dumps(runtime, indent=2) + "\n", encoding="utf-8")
    bind_owner_launcher(args.output)
    manifest_path = args.output / "candidate-manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest.update({"programme": "GENTEK-SWARM-005", "draft_hold": True,
                     "owner_visual_acceptance": "pending",
                     "qualification_receipts": "separate source and pristine-package automated Windows runs required",
                     "reciprocal_cli_sha256": runtime["sha256"],
                     "files_sha256": {path.relative_to(args.output).as_posix(): custody.native.sha(path)
                                      for path in sorted(args.output.rglob("*"))
                                      if path.is_file() and path != manifest_path}})
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(manifest_path)


if __name__ == "__main__":
    main()
