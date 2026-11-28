#!/usr/bin/env python3
"""Package committed ambient gameplay with unchanged authenticated Windows runtimes.

The host source, native build identity, actual qualification platform and pending
owner judgement remain separate. This never republishes or relabels a DLL.
"""
from __future__ import annotations

import argparse
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import zipfile

from qualify_ambient import ROOT, CASES, source_identity, require, sha, write_json
from package_workbench_landscape_review import DEPENDENCIES
from package_explore001_candidate import verify_vc_runtime, stage_generator_profiles
from package_wave_flow_candidate import omit_regenerated_imports, REGENERATED_RAPIER_IMPORTS
from qualify_workbench_landscapes import windows, project_identity

GUIDE = "docs/operations/ambient-workbench.md"


def verify_package(folder: Path, pristine: bool = False) -> dict:
    manifest = json.loads((folder / "evaluation-manifest.json").read_text(encoding="utf-8"))
    require(manifest.get("schema_version") == 1 and manifest.get("kind") == "ambient-001-owner-evaluation",
            "Wrong AMBIENT evaluation manifest")
    for relative, digest in manifest["files_sha256"].items():
        require(not Path(relative).is_absolute() and ".." not in Path(relative).parts,
                "Unsafe manifest path")
        path = folder / relative
        require(path.is_file() and not path.is_symlink() and sha(path) == digest,
                "Original evaluation input changed: " + relative)
    expected = set(manifest["files_sha256"]) | {"evaluation-manifest.json"}
    omitted = manifest.get("regenerated_imports_omitted", {})
    require(all(REGENERATED_RAPIER_IMPORTS.get(name) == digest and name.removesuffix(".import") in expected
                for name, digest in omitted.items()), "Unreviewed regenerated import exemption")
    actual = {path.relative_to(folder).as_posix() for path in folder.rglob("*") if path.is_file()}
    if pristine:
        require(actual == expected, "Pristine evaluator contains missing or unexpected files")
    else:
        for relative in actual - expected:
            # Ordinary import metadata and the portable user's authored saves
            # are mutable. An injected executable project script is not.
            allowed = relative.startswith(("godot/.godot/", "userdata/"))
            if relative in omitted: allowed = True
            # Godot generates UID sidecars for both scripts and shaders. Admit
            # only metadata attached to an original, still-hash-checked input.
            if relative.endswith((".gd.uid", ".gdshader.uid")) and relative[:-4] in expected:
                allowed = True
            require(allowed, "Unexpected post-launch evaluator file: " + relative)
    return manifest


def verify_qualification(folder: Path, qualification: dict) -> None:
    records = [("import", qualification.get("import", {}))]
    records += [(row["name"], row) for row in qualification["cases"]]
    for name, row in records:
        require(row.get("status") == "passed" and row.get("exit_code") == 0,
                "Unsuccessful original qualification process: " + name)
        location = folder / name
        log = location / "process.log"
        require(sha(location / "process.json") == row.get("process_sha256"),
                "Original process receipt changed: " + name)
        process = json.loads((location / "process.json").read_text(encoding="utf-8"))
        require(log.is_file() and sha(log) == row.get("log_sha256"),
                "Original qualification log changed: " + name)
        require(all(row.get(key) == value for key, value in process.items()),
                "Original process receipt differs from campaign summary: " + name)
        if "report_sha256" in row:
            require(sha(location / "report.json") == row["report_sha256"],
                    "Original gameplay report changed: " + name)


def verify_graphical(folder: Path, identity: dict) -> dict:
    qualification = json.loads((folder / "qualification.json").read_text(encoding="utf-8"))
    require(qualification.get("status") == "passed" and qualification.get("input_custody") == "passed"
            and qualification.get("headless") is False
            and qualification.get("source_commit") == identity["source_commit"]
            and qualification.get("source_tree") == identity["source_tree"]
            and qualification.get("source_inputs_sha256") == identity["source_inputs_sha256"]
            and qualification.get("local_delta") == [], "Graphical source/custody mismatch")
    verify_qualification(folder, qualification)
    graphical = qualification["graphical"]
    require(sha(folder / "graphical/process.json") == graphical["process"].get("process_sha256"),
            "Graphical original process receipt changed")
    process = json.loads((folder / "graphical/process.json").read_text(encoding="utf-8"))
    require(all(graphical["process"].get(key) == value for key, value in process.items()) and process.get("status") == "passed"
            and sha(folder / "graphical/process.log") == process["log_sha256"],
            "Graphical process receipt/log changed")
    require(sha(folder / "captures/capture-report.json") == graphical["report_sha256"],
            "Graphical capture report changed")
    for name, digest in graphical["images_sha256"].items():
        require(Path(name).name == name and sha(folder / "captures" / name) == digest,
                "Original captured image changed")
    return qualification


def build(args) -> None:
    identity = source_identity()
    runtime = windows.verify_retained_runtime(ROOT)
    qualification = json.loads((args.qualification / "qualification.json").read_text(encoding="utf-8"))
    require(qualification.get("kind") == "ambient-001-qualification" and qualification.get("status") == "passed"
            and qualification.get("input_custody") == "passed" and qualification.get("complete_campaign") is True
            and qualification.get("source_commit") == identity["source_commit"]
            and qualification.get("source_tree") == identity["source_tree"]
            and qualification.get("source_inputs_sha256") == identity["source_inputs_sha256"]
            and qualification.get("local_delta") == [],
            "Packaging requires complete successful exact-source qualification without local changes")
    require({row["name"] for row in qualification["cases"] if row.get("status") == "passed"} ==
            {row[0] for row in CASES}, "Qualification must cover the entire scoped campaign")
    require(qualification.get("platform") in ("linux", "win32"), "Unknown qualification platform")
    verify_qualification(args.qualification, qualification)
    graphical = verify_graphical(args.graphical_qualification, identity) if args.graphical_qualification else None
    dependencies = args.dependencies.resolve(strict=True)
    for name, digest in DEPENDENCIES.items():
        require(sha(dependencies / name) == digest, "Pinned Windows dependency mismatch: " + name)
    vc = verify_vc_runtime(dependencies)
    output = args.output.resolve()
    require(not output.exists(), "Evaluation output must be a new directory")
    output.mkdir(parents=True)
    names = ["godot", "examples/worldgen", "third_party/godot-runtime.lock.json",
             "third_party/native-toolchain.lock.json", "third_party/rapier-bvh-build.lock.json",
             "third_party/patches/rapier-0.35.1-cooperative-bvh-join.patch", "THIRD_PARTY_NOTICES.md",
             "LICENSE_STATUS.md", GUIDE, "docs/systems/ambient-actors.md",
             "docs/research/ambient-001", "docs/systems/workbench-actor-composition.md",
             "docs/systems/physical-actor-rigs.md", "tools/ci/test_ambient_delivery.py"]
    archive = subprocess.check_output(
        ["git", "-c", "core.autocrlf=false", "-c", "core.eol=lf", "archive", "HEAD", "--", *names],
        cwd=ROOT, env=dict(os.environ, GIT_LFS_SKIP_SMUDGE="1"), timeout=60)
    materialized = {runtime["cybersand_runtime"]["path"], runtime["rapier_runtime"]["path"]}
    materialized.add("godot/tools/gentek_reciprocal.exe")
    with tarfile.open(fileobj=io.BytesIO(archive)) as source:
        for entry in source:
            if not entry.isfile() or entry.name.startswith("godot/.godot/"):
                continue
            if entry.name in {"godot/tools/gentek_reciprocal", "godot/tools/swarm004-runtime.linux.json"}:
                continue
            if "/bin/" in entry.name and entry.name not in materialized:
                continue
            require(not Path(entry.name).is_absolute() and ".." not in Path(entry.name).parts,
                    "Unsafe archive entry")
            data = (ROOT / entry.name).read_bytes() if entry.name in materialized else source.extractfile(entry).read()
            require(not data.startswith(b"version https://git-lfs.github.com/spec/v1\n"),
                    "Unmaterialized required asset: " + entry.name)
            path = output / entry.name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    profiles = stage_generator_profiles(output)
    omitted = omit_regenerated_imports(output)
    for name in [*DEPENDENCIES, "vcruntime140.dll", "vc-runtime-provenance.json"]:
        shutil.copyfile(dependencies / name, output / name)
    # The ordinary actor-panel selector supplies all five authored examples.
    # Portable userdata starts empty and stays writable; no owner's saved file
    # is part of the immutable payload manifest. Default launch is blank.
    examples = {}
    for path in sorted((output / "godot/examples/workbench").glob("ambient-*.json")):
        examples[path.name] = sha(path)
    require(len(examples) == 5, "Package must contain all five ordinary authored ambient examples")
    launcher = (
        '@echo off\nsetlocal\ncd /d "%~dp0"\n'
        'set "APPDATA=%~dp0userdata\\roaming"\nset "LOCALAPPDATA=%~dp0userdata\\local"\n'
        'set "XDG_DATA_HOME=%~dp0userdata\\roaming"\n'
        f'set "CYBERSAND_SOURCE_REVISION={identity["source_commit"]}"\n'
        '"%~dp0Godot_v4.7-stable_win64_console.exe" --headless --path "%~dp0godot" --editor --quit\n'
        'if errorlevel 1 (\n  if not "%~1"=="--headless" pause\n  exit /b 1\n)\n'
        '"%~dp0Godot_v4.7-stable_win64_console.exe" --path "%~dp0godot" --rendering-method gl_compatibility --rendering-driver opengl3_angle %* -- --workbench\n'
        'set "ambient_exit=%errorlevel%"\n'
        'if not "%ambient_exit%"=="0" if not "%~1"=="--headless" pause\n'
        'exit /b %ambient_exit%\n')
    (output / "Open Workbench.cmd").write_text(launcher, encoding="utf-8", newline="\r\n")
    qualified_platform = qualification["platform"]
    preface = (
        "# CyberSand — AMBIENT-001 owner evaluation\n\n"
        "**Draft/HOLD. Experimental and opt-in; owner acceptance remains pending.**\n\n"
        "Extract the complete ZIP into a writable folder and double-click **Open Workbench.cmd**. "
        "Allow the first local import to finish. Open **Configuration…**, select **Actors**, choose an **Ambient examples** entry "
        "and click **Load scene**, then **Play**. The ordinary blank start stays passive.\n\n"
        f"Host source: `{identity['source_commit']}`. Native build source: `{runtime['runtime_source_commit']}`. "
        f"The completed automated qualification platform is `{qualified_platform}`. "
        "Neither headless execution nor hosted rendering establishes physical Windows/NVIDIA playfeel.\n\n"
        "The launcher keeps authored saves in this extracted folder's `userdata` directory. "
        "The manifest records exact payload hashes, source identity and retained runtime provenance. "
        "`qualification` contains original case receipts and logs.\n\n"
        "Read the [owner walkthrough](docs/operations/ambient-workbench.md) to build a profile, "
        "paint Oil/Water, edit a timer, pilot an actor and save/reopen. "
        "The [module-authoring contract](docs/systems/ambient-actors.md) explains the extension API.\n")
    (output / "READ-ME.md").write_text(preface, encoding="utf-8")
    evidence = output / "qualification"
    for path in sorted(args.qualification.rglob("*")):
        relative = path.relative_to(args.qualification)
        if path.is_file() and "userdata" not in relative.parts and path.suffix in {".json", ".log"}:
            destination = evidence / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, destination)
    if graphical:
        for path in sorted(args.graphical_qualification.rglob("*")):
            relative = path.relative_to(args.graphical_qualification)
            if path.is_file() and "userdata" not in relative.parts and path.suffix in {".json", ".log", ".png"}:
                destination = evidence / "graphical" / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, destination)
    project_identity(output / "godot", identity, runtime)
    for name, digest in DEPENDENCIES.items():
        require(sha(output / name) == digest, "Copied Windows dependency differs from official pin: " + name)
    require(verify_vc_runtime(output) == vc, "Copied portable VC runtime changed")
    files = {path.relative_to(output).as_posix(): sha(path) for path in sorted(output.rglob("*")) if path.is_file()}
    record = {"schema_version": 1, "kind": "ambient-001-owner-evaluation", "disposition": "Draft/HOLD",
              "source_commit": identity["source_commit"], "source_tree": identity["source_tree"],
              "source_inputs_sha256": identity["source_inputs_sha256"], "runtime": runtime,
              "qualification_platform": qualified_platform,
              "windows_execution_qualified": qualified_platform == "win32", "owner_playfeel_accepted": False,
              "graphical_execution": graphical["graphical"] if graphical else None,
              "qualification_sha256": sha(args.qualification / "qualification.json"),
              "godot_version": "4.7.stable.official.5b4e0cb0f", "dependencies_sha256": DEPENDENCIES,
              "vc_runtime_sha256": vc["files_sha256"]["vcruntime140.dll"],
              "ambient_examples_sha256": examples, "generator_profiles_sha256": profiles,
              "regenerated_imports_omitted": omitted, "files_sha256": files}
    write_json(output / "evaluation-manifest.json", record)
    require(source_identity() == identity and windows.verify_retained_runtime(ROOT) == runtime,
            "Source or retained runtime changed during package construction")
    verify_qualification(args.qualification, qualification)
    if graphical:
        require(verify_graphical(args.graphical_qualification, identity) == graphical,
                "Graphical qualification changed during packaging")
    verify_package(output, pristine=True)
    require(not args.archive.exists(), "Archive must be a new path")
    args.archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        for path in sorted(output.rglob("*")):
            if path.is_file(): bundle.write(path, path.relative_to(output).as_posix())
    with zipfile.ZipFile(args.archive) as bundle:
        require(bundle.testzip() is None, "Evaluation ZIP integrity failure")
    args.archive.with_suffix(args.archive.suffix + ".sha256").write_text(
        sha(args.archive) + "  " + args.archive.name + "\n", encoding="utf-8")
    print(args.archive)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    create = commands.add_parser("build")
    create.add_argument("--dependencies", type=Path, required=True)
    create.add_argument("--qualification", type=Path, required=True)
    create.add_argument("--graphical-qualification", type=Path)
    create.add_argument("--output", type=Path, required=True)
    create.add_argument("--archive", type=Path, required=True)
    verify = commands.add_parser("verify")
    verify.add_argument("folder", type=Path)
    verify.add_argument("--pristine", action="store_true")
    args = parser.parse_args()
    if args.command == "build": build(args)
    else:
        manifest = verify_package(args.folder, pristine=args.pristine)
        print(json.dumps({"verified": True, "source_commit": manifest["source_commit"],
                          "files": len(manifest["files_sha256"])}))


if __name__ == "__main__":
    main()
