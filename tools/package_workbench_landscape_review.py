#!/usr/bin/env python3
"""Package qualified host-claim source with its unchanged, verified Windows DLL.

The native build commit remains the original publication commit. The package
separately records the current host source, real test receipts and map sources.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import zipfile

from qualify_workbench_landscapes import ROOT, MANIFEST, git, load_maps, materialize_maps, require, sha, source_identity, write_json, windows
from package_explore001_candidate import verify_vc_runtime, stage_generator_profiles
from package_wave_flow_candidate import omit_regenerated_imports

DEPENDENCIES = {
    "Godot_v4.7-stable_win64.exe": "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8",
    "Godot_v4.7-stable_win64_console.exe": "d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c",
    "Godot-LICENSE.txt": "b0435e3b3e4e55238f05f4b306f30524a1b2e20147810d436eaa554fa6855c80",
    "Godot-COPYRIGHT.txt": "cb1980c88089573bcacd7221d777c689bb8bbd778799f24c27fca0fe5f774d6d",
    "Microsoft-Visual-C-Runtime-LICENSE.docx": "f1e3d56ceb2ad68aae0711b910375009e651ac5530fa0760f0dea6e81e54fae1",
    "Microsoft-Visual-Studio-2022-LICENSE.docx": "9c0cd52b20db9d081854c75bd1b50c75514b8f8cb09c8cad15e89d90b97b5bf3",
}


def payload_files(folder: Path) -> dict:
    return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob("*"))
            if p.is_file() and p != folder / "evaluation-manifest.json"}


def verify_package(folder: Path) -> dict:
    manifest = json.loads((folder / "evaluation-manifest.json").read_text(encoding="utf-8"))
    require(manifest.get("schema_version") == 1 and manifest.get("kind") == "workbench-host-claims-owner-evaluation",
            "Wrong evaluation manifest")
    # Godot may create caches and user files, but no original input may change.
    for relative, digest in manifest["files_sha256"].items():
        path = folder / relative
        require(path.is_file() and not path.is_symlink() and sha(path) == digest,
                "Original evaluation payload changed: " + relative)
    return manifest


def build(args):
    identity = source_identity()
    runtime = windows.verify_retained_runtime(ROOT)
    qualification = json.loads((args.qualification / "qualification.json").read_text(encoding="utf-8"))
    require(qualification.get("status") == "passed" and qualification.get("input_custody") == "passed"
            and qualification.get("source_commit") == identity["source_commit"]
            and qualification.get("source_tree") == identity["source_tree"] and qualification.get("local_delta") == [],
            "Packaging requires successful exact-source qualification without local changes")
    require(qualification.get("source_inputs_sha256") == identity["source_inputs_sha256"],
            "Qualification inputs differ from the packaging source")
    require(qualification.get("platform") in ("linux", "win32"), "Unknown qualification platform")
    manifest, maps = load_maps(args.manifest)
    require({item["name"] for item in qualification["maps"] if item.get("status") == "passed"} ==
            {item["name"] for item in maps}, "Qualification must cover every selected real map")
    dependencies = args.dependencies.resolve(strict=True)
    for name, digest in DEPENDENCIES.items():
        require(sha(dependencies / name) == digest, "Pinned Windows dependency mismatch: " + name)
    vc = verify_vc_runtime(dependencies)
    output = args.output.resolve()
    require(not output.exists(), "Evaluation output must be a new directory")
    output.mkdir(parents=True)
    names = ["godot", "examples/worldgen", "third_party/godot-runtime.lock.json",
             "third_party/native-toolchain.lock.json", "third_party/rapier-bvh-build.lock.json",
             "third_party/patches/rapier-0.35.1-cooperative-bvh-join.patch", "THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md"]
    environment = dict(os.environ, GIT_LFS_SKIP_SMUDGE="1")
    archive = subprocess.check_output(["git", "-c", "core.autocrlf=false", "-c", "core.eol=lf", "archive", "HEAD", "--", *names],
                                      cwd=ROOT, env=environment, timeout=60)
    materialized = {runtime["cybersand_runtime"]["path"], runtime["rapier_runtime"]["path"]}
    with tarfile.open(fileobj=io.BytesIO(archive)) as source:
        for entry in source:
            if not entry.isfile() or entry.name.startswith("godot/.godot/"):
                continue
            if "/bin/" in entry.name and entry.name not in materialized:
                continue
            data = source.extractfile(entry).read()
            if entry.name in materialized:
                data = (ROOT / entry.name).read_bytes()
            require(not data.startswith(b"version https://git-lfs.github.com/spec/v1\n"),
                    "Unmaterialized required package asset: " + entry.name)
            path = output / entry.name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    profiles = stage_generator_profiles(output)
    omitted = omit_regenerated_imports(output)
    for name in [*DEPENDENCIES, "vcruntime140.dll", "vc-runtime-provenance.json"]:
        shutil.copyfile(dependencies / name, output / name)
    materialize_maps(args.manifest, output / "maps", args.fixture_dir)
    write_json(output / "maps/landscape-manifest.json", manifest)
    highest = max(maps, key=lambda item: item["construction_rectangle_count"])
    saved = output / "userdata/roaming/Godot/app_userdata/Cyber Sand Reference Sandbox/workbench"
    saved.mkdir(parents=True)
    for item in maps:
        shutil.copyfile(output / "maps" / item["fixture_file"], saved / ("setup-" + item["name"] + ".json"))
    shutil.copyfile(output / "maps" / highest["fixture_file"], saved / "setup-my-canvas.json")
    launcher = (
        '@echo off\nsetlocal\ncd /d "%~dp0"\n'
        'set "APPDATA=%~dp0userdata\\roaming"\nset "LOCALAPPDATA=%~dp0userdata\\local"\n'
        'set "XDG_DATA_HOME=%~dp0userdata\\roaming"\n'
        f'set "CYBERSAND_SOURCE_REVISION={identity["source_commit"]}"\n'
        '"%~dp0Godot_v4.7-stable_win64_console.exe" --headless --path "%~dp0godot" --editor --quit\n'
        'if errorlevel 1 (\n  if not "%~1"=="--headless" pause\n  exit /b 1\n)\n'
        '"%~dp0Godot_v4.7-stable_win64_console.exe" --path "%~dp0godot" %* -- --workbench\n'
        'set "workbench_exit=%errorlevel%"\n'
        'if not "%workbench_exit%"=="0" if not "%~1"=="--headless" pause\n'
        'exit /b %workbench_exit%\n')
    (output / "Open Workbench.cmd").write_text(launcher, encoding="utf-8", newline="\r\n")
    table = "\n".join(f"| {item['name']} | {item['title']} | {item['construction_rectangle_count']:,} |" for item in maps)
    readme = f"""# CyberSand — large original landscape evaluation

This is a Draft/HOLD owner evaluation of WORKBENCH-HOST-CLAIMS-001.

1. Extract the complete ZIP into a writable folder.
2. Double-click **Open Workbench.cmd**. Allow the initial local Godot import to finish.
3. In the drawing/Setup controls, keep the name **my-canvas** and click **Load start**.
   This loads **{highest['title']}**, an authored 2048 × 1024 landscape with **{highest['construction_rectangle_count']:,} rectangles**.
4. Select its Midge in **Pilot**, press **P** to play, and use the ordinary Workbench controls.
   Pause before painting or erasing. **Restore start** reconstructs the authored map.
5. **Save start** preserves authored starting cells, actor placement and settings; it does not save the evolved simulation.
   Close the app, launch it again, and use the same name plus **Load start** to reopen.

Other original maps are available by entering their setup name and clicking **Load start**:

| Setup name | Map | Rectangles |
|---|---|---:|
{table}

All supplied map files retain their original committed bytes. `maps/landscape-manifest.json` records their exact source PRs,
commits, counts and hashes. The `my-canvas` alias is a copy of the highest-count selected map.
The launcher keeps saves beneath this extracted folder's `userdata` directory.
Remove the extracted folder to remove this evaluation and its local saves.

Application source: `{identity['source_commit']}`; tree `{identity['source_tree']}`.
Retained native build source: `{runtime['runtime_source_commit']}`; no native source or limits were changed.
The original native and Rapier provenance manifests accompany their exact binaries.
`evaluation-manifest.json` binds package files and qualification source separately from native build identity.
`qualification` contains the actual {qualification['platform']} campaign reports and process logs.
Automated headless physics evidence does not establish physical Windows/NVIDIA gameplay or visual acceptance.
Keep Draft/HOLD until the owner accepts the result; this ZIP performs no merge or installation.
"""
    (output / "READ-ME.md").write_text(readme, encoding="utf-8")
    evidence = output / "qualification"
    evidence.mkdir()
    for path in sorted(args.qualification.rglob("*")):
        relative = path.relative_to(args.qualification)
        if path.is_file() and "userdata" not in relative.parts and "fixtures" not in relative.parts \
                and path.suffix in {".json", ".log"}:
            destination = evidence / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, destination)
    record = {"schema_version": 1, "kind": "workbench-host-claims-owner-evaluation", "purpose": "Draft/HOLD owner evaluation",
              "source_commit": identity["source_commit"], "source_tree": identity["source_tree"],
              "native_runtime": runtime, "godot_version": windows.GODOT_VERSION,
              "vc_runtime_sha256": vc["files_sha256"]["vcruntime140.dll"], "generator_profiles_sha256": profiles,
              "regenerated_imports_sha256": omitted, "default_map": highest["name"],
              "qualification_platform": qualification["platform"], "fixture_manifest_sha256": sha(args.manifest),
              "files_sha256": payload_files(output)}
    write_json(output / "evaluation-manifest.json", record)
    verify_package(output)
    require(source_identity() == identity and windows.verify_retained_runtime(ROOT) == runtime,
            "Source/runtime changed while packaging")
    if args.archive:
        require(not args.archive.exists(), "Refusing to replace an existing evaluation ZIP")
        args.archive.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(args.archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
            for path in sorted(output.rglob("*")):
                if path.is_file():
                    bundle.write(path, path.relative_to(output).as_posix())
        args.archive.with_suffix(args.archive.suffix + ".sha256").write_text(sha(args.archive) + "  " + args.archive.name + "\n")
    print(output / "Open Workbench.cmd")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    make = commands.add_parser("build")
    make.add_argument("--dependencies", type=Path, required=True)
    make.add_argument("--qualification", type=Path, required=True)
    make.add_argument("--manifest", type=Path, default=MANIFEST)
    make.add_argument("--fixture-dir", type=Path, required=True)
    make.add_argument("--output", type=Path, required=True)
    make.add_argument("--archive", type=Path)
    verify = commands.add_parser("verify")
    verify.add_argument("package", type=Path)
    args = parser.parse_args()
    if args.command == "build":
        build(args)
    else:
        print(json.dumps({"verified": str(args.package), "source_commit": verify_package(args.package)["source_commit"]}))


if __name__ == "__main__":
    main()
