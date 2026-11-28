#!/usr/bin/env python3
"""Stage exact platform source bytes outside Git before Godot creates imports.

The pristine source checkout stays subject to the full custody gate. Godot's
generated .gd.uid metadata and import cache belong only to this installed test
layout; no source-cleanliness exception is granted.
"""
from __future__ import annotations

import argparse
import io
from pathlib import Path, PurePosixPath
import tarfile

import runtime_custody as custody
from install_runtime import install
from shared import load, verify_project

generic = load("swarm45_platform_source_stage", "tools/ci/run_workbench_qualification.py")
from package_explore001_candidate import committed_archive

RAPIERS = {
    "windows": "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll",
    "linux": "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so",
}
REPLACED_OR_FOREIGN = {
    "godot/tools/gentek_reciprocal", "godot/tools/gentek_reciprocal.exe",
    "godot/tools/swarm004-runtime.linux.json", "godot/tools/swarm004-runtime.windows.json",
}


def stage(runtime: Path, destination: Path) -> dict:
    runtime, destination = runtime.resolve(), destination.resolve()
    custody.require(not destination.exists() and not destination.is_relative_to(custody.ROOT.resolve()),
                    "Source stage must be a new directory outside the source checkout")
    receipt = custody.verify(runtime)
    platform = receipt["platform"]
    custody.require(platform in RAPIERS, "Source stage requires a source-matched Linux or Windows payload")
    rapier = RAPIERS[platform]
    pins = generic.committed_lfs_pins()
    payload = committed_archive(["godot", "examples/worldgen"], custody.ROOT)
    destination.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(payload)) as archive:
        for item in archive:
            path = PurePosixPath(item.name)
            custody.require(not path.is_absolute() and all(part not in ("", ".", "..") for part in path.parts),
                            "Unsafe committed project archive path")
            if item.isdir():
                continue
            custody.require(item.isfile(), "Project source cannot contain archive symlinks")
            if item.name in REPLACED_OR_FOREIGN or item.name.startswith("godot/.godot/"):
                continue
            if "/bin/" in item.name and item.name != rapier:
                continue
            data = archive.extractfile(item).read()
            if item.name in pins:
                if data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
                    data = (custody.ROOT / item.name).read_bytes()
                generic.verify_lfs_payload(item.name, data, pins)
            target = destination / item.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            target.chmod(item.mode & 0o777)
    custody.require(custody.binary_format(destination / rapier, platform), "Staged Rapier is not materialized " + platform + " x86_64")
    custody.require(install(runtime, destination / "godot") == receipt, "Source runtime changed during staging")
    profiles = generic.stage_generator_profiles(destination)
    # The old committed receipt must not describe the newly installed adapter.
    retained = destination / "godot/addons/cybersand_native" / ("runtime-provenance.linux.json" if platform == "linux" else "runtime-provenance.json")
    if retained.exists():
        retained.rename(retained.with_name("retained-runtime-provenance." + platform + ".reference.json"))
    verify_project(destination / "godot", receipt)
    custody.require(custody.verify(runtime) == receipt, "Source/runtime custody changed during staging")
    record = {"schema": 1, "programme": custody.PROGRAMME, "source_commit": receipt["source_commit"],
              "source_tree": receipt["source_tree"], "platform": platform, "build_context": receipt["build_context"],
              "runtime_manifest_sha256": custody.sha(runtime / custody.NAME), "generator_profiles_sha256": profiles,
              "source_checkout_untouched": True, "files_sha256": custody.inventory(destination)}
    custody.write_json(destination / "source-stage.json", record)
    return record


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = stage(args.runtime, args.output)
    print({"source": result["source_commit"], "project": str(args.output.resolve() / "godot")})


if __name__ == "__main__":
    main()
