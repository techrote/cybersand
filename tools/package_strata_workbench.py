#!/usr/bin/env python3
"""Package the frozen, graphically qualified ordinary Strata Workbench.

Build and verify a portable Windows evaluation; do not publish native libraries,
change retained manifests or promote the Draft implementation. Installed smoke
must execute a freshly extracted copy before the ZIP is delivered.
"""
from __future__ import annotations

import argparse
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/ci"))
import qualify_strata_workbench as qualification
from package_explore001_candidate import verify_vc_runtime, stage_generator_profiles
from package_wave_flow_candidate import archive_environment, omit_regenerated_imports, REGENERATED_RAPIER_IMPORTS
from package_workbench_landscape_review import DEPENDENCIES

require, sha, write_json = qualification.require, qualification.sha, qualification.write_json
MANIFEST = "evaluation-manifest.json"
ARCHIVE_INPUTS = ["godot", "examples/worldgen", "third_party/godot-runtime.lock.json",
                  "third_party/native-toolchain.lock.json", "third_party/rapier-bvh-build.lock.json",
                  "third_party/patches/rapier-0.35.1-cooperative-bvh-join.patch", "THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md"]


def payload(folder: Path) -> dict[str, str]:
    return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob("*"))
            if p.is_file() and p != folder / MANIFEST}



def launcher_text(source: dict) -> str:
    return (
        '@echo off\nsetlocal\ncd /d "%~dp0"\n'
        'set "APPDATA=%~dp0userdata\\roaming"\nset "LOCALAPPDATA=%~dp0userdata\\local"\n'
        'set "XDG_DATA_HOME=%~dp0userdata\\roaming"\n'
        f'set "CYBERSAND_SOURCE_REVISION={source["source_commit"]}"\n'
        '"%~dp0Godot_v4.7-stable_win64_console.exe" --headless --audio-driver Dummy --path "%~dp0godot" --editor --quit\n'
        'if errorlevel 1 (\n  pause\n  exit /b 1\n)\n'
        '"%~dp0Godot_v4.7-stable_win64_console.exe" --path "%~dp0godot" %* -- --workbench\n'
        'set "strata_exit=%errorlevel%"\nif not "%strata_exit%"=="0" pause\nexit /b %strata_exit%\n')


def verify_generator_profiles(folder: Path, record: dict, originals: set[str], names: dict[str, str]) -> None:
    # The established stager copies direct canonical recipes only. Nested
    # architectural styles and schemas remain archived assets, not profiles.
    profiles = {Path(name).name:sha(folder / name) for name in originals
                if Path(name).parent == Path("examples/worldgen") and Path(name).suffix == ".json"}
    require(record.get("generator_profiles_sha256") == profiles and all(
        names.get("godot/authoring/worldgen/" + name) == digest for name,digest in profiles.items()),
        "Portable generator profiles differ from archived source recipes")


def verify(folder: Path, *, pristine: bool = False) -> dict:
    record = json.loads((folder / MANIFEST).read_text(encoding="utf-8"))
    require(record.get("schema") == "strata-workbench-evaluation-v1" and record.get("draft_hold") is True,
            "Wrong Strata evaluator manifest")
    require(set(record.get("qualification_platforms", [])) == {"linux", "win32"}, "Both actual platform campaigns are required")
    source = qualification.identity()
    runtime = qualification.retained_runtime_manifest("win32")
    require(record.get("source_commit") == source["source_commit"] and record.get("source_tree") == source["source_tree"]
            and record.get("runtime") == runtime and record.get("godot_version") == qualification.custody.windows.GODOT_VERSION,
            "Evaluator source, retained runtime or engine identity differs from current source")
    qualification.custody.project_identity(folder / "godot", source, runtime)
    for platform, name in (("linux", "linux"), ("win32", "windows")):
        admitted = qualification.verify_campaign(folder / "qualification" / name, source)
        require(admitted["platform"] == platform, "Embedded campaign platform differs from its package location")
    names = record.get("files_sha256", {})
    require(isinstance(names, dict) and names, "Missing payload manifest")
    for name, digest in names.items():
        require(not Path(name).is_absolute() and ".." not in Path(name).parts and "\\" not in name,
                "Unsafe payload path")
        path = folder / name
        require(path.is_file() and not path.is_symlink() and sha(path) == digest, "Payload changed: " + name)
    required = {"Open Workbench.cmd", "READ-ME.md", "OWNER-EVALUATION.md", "godot/project.godot",
                "godot/scripts/shared_workbench.gd", "vcruntime140.dll", "vc-runtime-provenance.json", *DEPENDENCIES}
    require(required <= set(names), "Evaluator omits required application, launcher, instructions or runtime dependencies")
    archived = set(qualification.custody.git("ls-tree", "-r", "--name-only", "HEAD", "--", *ARCHIVE_INPUTS).decode().splitlines())
    materialized = {runtime[k]["path"] for k in ("cybersand_runtime", "rapier_runtime")}
    omitted = {name:digest for name,digest in REGENERATED_RAPIER_IMPORTS.items() if name in archived}
    require(record.get("regenerated_imports_sha256") == omitted, "Regenerated import omission list differs from reviewed source")
    originals = {name for name in archived if not name.startswith("godot/.godot/") and
                 ("/bin/" not in name or name in materialized) and name not in omitted}
    require(originals <= set(names), "Payload manifest silently omits an archived source asset")
    verify_generator_profiles(folder, record, originals, names)

    require((folder / "Open Workbench.cmd").read_text(encoding="utf-8") == launcher_text(source),
            "Ordinary evaluator launcher differs from the qualified launcher")
    for name, digest in DEPENDENCIES.items():
        require(names.get(name) == digest, "Packaged dependency differs from its pin: " + name)
    vc = verify_vc_runtime(folder)
    require(record.get("vc_runtime_sha256") == vc["files_sha256"]["vcruntime140.dll"] == names["vcruntime140.dll"],
            "Packaged VC runtime receipt differs from its payload")
    if pristine:
        require(payload(folder) == names, "Pristine payload has missing or extra files")
    require(names.get("Godot_v4.7-stable_win64.exe") == qualification.GODOT_GUI_SHA256
            and names.get("Godot_v4.7-stable_win64_console.exe") == qualification.GODOT_SHA256["win32"],
            "Packaged engine is not the official pinned engine")
    for kind in ("cybersand_runtime", "rapier_runtime"):
        item = record["runtime"][kind]
        require(names.get(item["path"]) == item["sha256"], "Packaged runtime identity mismatch")
    return record


def build(args) -> Path:
    source = qualification.identity()
    runtime = qualification.custody.windows.verify_retained_runtime(ROOT)
    reports = [qualification.verify_campaign(path, source) for path in (args.linux, args.windows)]
    require({r["platform"] for r in reports} == {"linux", "win32"}, "Need actual Linux and Windows graphical execution")
    require(args.linux.resolve() != args.windows.resolve(), "Platform campaigns must be independently retained")
    dependencies = args.dependencies.resolve(strict=True)
    for name, digest in DEPENDENCIES.items():
        require(sha(dependencies / name) == digest, "Pinned dependency mismatch: " + name)
    vc = verify_vc_runtime(dependencies)
    output = args.output.resolve()
    require(not output.exists(), "Refusing to overwrite an evaluator")
    output.mkdir(parents=True)
    include = ARCHIVE_INPUTS
    archive = subprocess.check_output(["git", "archive", "HEAD", "--", *include], cwd=ROOT,
                                      env=archive_environment(), timeout=90)
    materialized = {runtime["cybersand_runtime"]["path"], runtime["rapier_runtime"]["path"]}
    with tarfile.open(fileobj=io.BytesIO(archive)) as tree:
        for member in tree:
            if not member.isfile() or member.name.startswith("godot/.godot/"):
                continue
            if "/bin/" in member.name and member.name not in materialized:
                continue
            require(not Path(member.name).is_absolute() and ".." not in Path(member.name).parts, "Unsafe source archive path")
            data = (ROOT / member.name).read_bytes() if member.name in materialized else tree.extractfile(member).read()
            require(not data.startswith(b"version https://git-lfs.github.com/spec/v1\n"), "Unmaterialized package input: " + member.name)
            path = output / member.name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    generator_profiles = stage_generator_profiles(output)
    omitted = omit_regenerated_imports(output)
    for name in [*DEPENDENCIES, "vcruntime140.dll", "vc-runtime-provenance.json"]:
        shutil.copyfile(dependencies / name, output / name)
    launcher = launcher_text(source)
    (output / "Open Workbench.cmd").write_text(launcher, encoding="utf-8", newline="\r\n")
    readme = f"""# CyberSand — Strata Theatre Workbench evaluation

**Draft / HOLD.** Source `{source['source_commit']}`, tree `{source['source_tree']}`.

1. Extract the entire ZIP into a writable folder, then run **Open Workbench.cmd**.
2. Open **Strata Theatre** in the ordinary Workbench. The normal presentation starts unchanged.
3. Scroll to **Open a complete example scene**, choose **Industrial assembly hall**,
   **Science-fiction arcology** or **Organic industrial cavern**, then press **Load selected example…**.
   Loading a scene intentionally replaces the authored start. Toggling presentation does not replace the live play World.
4. Turn layered presentation on. Compare **Stack** with **Flat** inspection and the ordinary disabled view.
5. Select Play, Rear architecture, Effects or Background. Paint or erase the selected plane;
   try visibility, solo, lock, opacity, depth, parallax and haze. Hidden/locked targets reject editing.
   Move or close the floating Strata panel while painting; reopen it from **Strata Theatre** when needed.
6. Pan and zoom, play with ordinary actors, then disable/re-enable Strata. Actors and the live play World should continue.
7. Try per-plane Undo/Redo. Save a named composition, exit completely, reopen and load that name.

The three decorative/effects planes are static native material layouts in this first milestone.
Only Play owns actors, collision and simulation. Visual effects do not transfer real material between planes.
Saved files retain authored material layouts and presentation settings, not exact physical continuation.
Material-history Flatten remains a play-plane operation and does not collapse visual layers.
Saves stay beneath this extracted folder's `userdata` directory.

`evaluation-manifest.json` identifies every shipped payload and the native build separately from application source.
`qualification/linux` and `qualification/windows` retain original actual Godot process, rendering, material-readback,
identity, cost and fresh-process reopen evidence. Hosted Windows/software rendering does not establish physical
Windows 11/NVIDIA appearance, DPI, interaction or performance acceptance. Record those observations in `OWNER-EVALUATION.md`.
"""
    (output / "READ-ME.md").write_text(readme, encoding="utf-8")
    (output / "OWNER-EVALUATION.md").write_text("# Owner evaluation\n\nHardware / GPU / driver / desktop scaling:\n\nScenes inspected:\n\nLayer editing, pan/zoom, visibility/lock, actor play and save/reopen observations:\n\nAppearance and responsiveness issues:\n\nDecision: HOLD / request changes / accept for later merge review\n", encoding="utf-8")
    for platform, origin in (("linux", args.linux), ("windows", args.windows)):
        target = output / "qualification" / platform
        for path in sorted(origin.rglob("*")):
            if path.is_file() and "userdata" not in path.parts and "bootstrap-userdata" not in path.parts:
                dest = target / path.relative_to(origin)
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, dest)
    record = {"schema": "strata-workbench-evaluation-v1", "draft_hold": True,
              "source_commit": source["source_commit"], "source_tree": source["source_tree"],
              "runtime": runtime, "godot_version": qualification.custody.windows.GODOT_VERSION,
              "qualification_platforms": ["linux", "win32"], "generator_profiles_sha256": generator_profiles,
              "regenerated_imports_sha256": omitted, "vc_runtime_sha256": vc["files_sha256"]["vcruntime140.dll"],
              "files_sha256": payload(output)}
    write_json(output / MANIFEST, record)
    verify(output, pristine=True)
    require(qualification.identity() == source, "Source changed during packaging")
    require(qualification.custody.windows.verify_retained_runtime(ROOT) == runtime, "Runtime changed during packaging")
    if args.archive:
        require(not args.archive.exists(), "Refusing to overwrite an evaluation archive")
        args.archive.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(args.archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
            for path in sorted(output.rglob("*")):
                if path.is_file(): zipped.write(path, path.relative_to(output).as_posix())
        args.archive.with_suffix(args.archive.suffix + ".sha256").write_text(sha(args.archive) + "  " + args.archive.name + "\n")
        write_json(args.archive.with_suffix(".manifest.json"), record)
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    make = commands.add_parser("build")
    for flag in ("dependencies", "linux", "windows", "output"):
        make.add_argument("--" + flag, type=Path, required=True)
    make.add_argument("--archive", type=Path)
    check = commands.add_parser("verify")
    check.add_argument("package", type=Path)
    check.add_argument("--pristine", action="store_true")
    args = parser.parse_args()
    if args.command == "build":
        print(build(args))
    else:
        print(json.dumps({"verified": str(args.package), "source_commit": verify(args.package, pristine=args.pristine)["source_commit"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
