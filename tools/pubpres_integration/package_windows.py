#!/usr/bin/env python3
"""Package the exact integrated Workbench checkout with its accepted Windows runtimes."""

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / "tools"), str(ROOT / "tools/ci")]
from package_explore001_candidate import stage_generator_profiles, stage_vc_runtime, verify_vc_runtime
from run_windows_godot_regressions import GODOT_SHA512, GODOT_VERSION, NATIVE, RAPIER, verify_retained_runtime


TOOLS = "tools/pubpres_integration"
MANIFEST = "PUBPRES-MANIFEST.json"
ACCEPTANCE = "ACCEPTANCE.md"
GUI = "Godot_v4.7-stable_win64.exe"
CONSOLE = "Godot_v4.7-stable_win64_console.exe"
BOOTSTRAP = {"godot/.godot/.gdignore", "godot/.godot/extension_list.cfg", "godot/.godot/global_script_class_cache.cfg"}
PORTABLE = {"Run-Test-It.ps1", "Read-Results.ps1", "Pack-Results.ps1", "campaign.json",
            "Run-Source-Comparison.ps1", "Read-Source-Results.ps1", "Read-Source-Transition.ps1",
            "source_campaign.json", "Verify-Package.ps1", "Test-Source-Results-Replay.ps1"}
REFERENCE_INTEGRATION = "8503ec19e4d620e125dc6df2c5c6571b1256cb92"
NOTICE_HASHES = {
    "LICENSE.txt": "b0435e3b3e4e55238f05f4b306f30524a1b2e20147810d436eaa554fa6855c80",
    "COPYRIGHT.txt": "cb1980c88089573bcacd7221d777c689bb8bbd778799f24c27fca0fe5f774d6d",
}


def need(acceptable, reason):
    if not acceptable:
        raise ValueError(reason)


def digest(path, algorithm="sha256"):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, algorithm).hexdigest()


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, timeout=120).strip()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def safe_name(name):
    path = PurePosixPath(name)
    need(not path.is_absolute() and path.parts and str(path) == name and ".." not in path.parts,
         "Unsafe archive path: " + name)
    for part in path.parts:
        need(not re.search(r'[<>:"|?*\\\x00-\x1f]', part) and not part.endswith((".", " "))
             and not re.fullmatch(r"(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?", part),
             "Windows-incompatible archive path: " + name)
    return path


def source_identity(source, accepted_main):
    need(re.fullmatch(r"[0-9a-f]{40}", source) and git("rev-parse", "HEAD") == source,
         "Supply the exact checked-out integration commit")
    need(re.fullmatch(r"[0-9a-f]{40}", accepted_main), "Supply the full accepted-main commit")
    git("merge-base", "--is-ancestor", accepted_main, source)
    git("diff", "--exit-code", source, "--", "godot", "native", TOOLS, "tools/ci", "examples/worldgen", "third_party")
    for filename in git("ls-files", "--others", "--exclude-standard", "--", "godot", "native", TOOLS).splitlines():
        need(filename.endswith(".uid"), "Untracked package input: " + filename)
    retained = verify_retained_runtime(ROOT)
    native = dict(retained["cybersand_runtime"], source_commit=retained["runtime_source_commit"],
                  build_commit=retained["runtime_build_commit"], source_inputs=len(retained["native_source_inputs"]))
    return {"schema": "pubpres-integration-windows-v1", "source_commit": source,
            "source_tree": git("rev-parse", source + "^{tree}"), "accepted_main": accepted_main,
            "parent": git("rev-parse", source + "^"), "parents": git("rev-list", "--parents", "-1", source).split()[1:],
            "native": native, "rapier": retained["rapier_runtime"], "physical_acceptance": "HOLD"}


def stage_source(destination, identity):
    native = json.loads((ROOT / "godot/addons/cybersand_native/runtime-provenance.json").read_text())
    rapier = json.loads((ROOT / "godot/addons/godot-rapier2d/runtime-provenance.windows.json").read_text())
    paths = {"godot", "examples/worldgen", "LICENSE_STATUS.md", "THIRD_PARTY_NOTICES.md",
             "third_party/godot-runtime.lock.json", "third_party/native-toolchain.lock.json",
             "third_party/rapier-bvh-build.lock.json", f"{TOOLS}/{ACCEPTANCE}",
             *(f"{TOOLS}/{name}" for name in PORTABLE), *native["source_inputs"], *rapier["source_inputs"]}
    with tempfile.TemporaryFile() as body:
        subprocess.run(["git", "archive", "--format=tar", identity["source_commit"], "--", *sorted(paths)],
                       stdout=body, cwd=ROOT, check=True, timeout=150)
        body.seek(0)
        with tarfile.open(fileobj=body) as archive:
            for member in archive:
                if member.isdir():
                    continue
                name = member.name
                need(member.isfile(), "Unexpected archive member: " + name)
                path = safe_name(name)
                if name.startswith("godot/.godot/") and name not in BOOTSTRAP:
                    continue
                if (path.suffix.lower() in {".dll", ".so", ".dylib", ".wasm"} or ".framework/" in name) and name not in {NATIVE, RAPIER}:
                    continue
                target = destination / (ACCEPTANCE if name == f"{TOOLS}/{ACCEPTANCE}" else name)
                target.parent.mkdir(parents=True, exist_ok=True)
                if name in {NATIVE, RAPIER}:
                    shutil.copyfile(ROOT / name, target)
                else:
                    with archive.extractfile(member) as handle, target.open("wb") as out:
                        prefix = handle.read(50)
                        need(not prefix.startswith(b"version https://git-lfs.github.com/spec/v1\n"), "Unmaterialized LFS input: " + name)
                        out.write(prefix)
                        shutil.copyfileobj(handle, out)
    need(all((destination / name).is_file() for name in BOOTSTRAP), "Missing portable Godot bootstrap")
    stage_generator_profiles(destination)


def stage_dependencies(destination, engine_zip, notices, vc):
    need(digest(engine_zip, "sha512") == GODOT_SHA512, "Official Godot archive SHA-512 differs")
    with zipfile.ZipFile(engine_zip) as archive:
        need(archive.testzip() is None, "Godot archive integrity failed")
        for name in (GUI, CONSOLE):
            with archive.open(name) as source, (destination / name).open("wb") as target:
                shutil.copyfileobj(source, target)
    version = subprocess.check_output([str(destination / CONSOLE), "--version"], text=True, timeout=45).strip()
    need(version == GODOT_VERSION, "Packaged Godot version differs: " + version)
    for name, expected in NOTICE_HASHES.items():
        need(digest(notices / name) == expected, "Official Godot notice differs: " + name)
        shutil.copyfile(notices / name, destination / ("Godot-" + name))
    vc_provenance = verify_vc_runtime(vc)
    need(vc_provenance.get("authenticode", {}).get("status") == "Valid", "Microsoft runtime signature receipt missing")
    stage_vc_runtime(vc, destination)
    return {"version": version, "archive_sha512": GODOT_SHA512, "gui_sha256": digest(destination / GUI),
            "console_sha256": digest(destination / CONSOLE)}


def stage_reference(destination, source, name, identity):
    """Retain reference production source; add observers only to run copies."""
    need(re.fullmatch(r"[0-9a-f]{40}", source), "Reference must be an exact commit")
    # Refuse to substitute current binaries if a reference has different inputs.
    paths = ["native/include", "native/src", "godot/native_extension",
             "godot/addons/cybersand_native", "godot/addons/godot-rapier2d",
             "godot/third_party/rapier2d.lock.json", "third_party/native-toolchain.lock.json",
             "third_party/rapier-bvh-build.lock.json", "third_party/godot-runtime.lock.json"]
    git("diff", "--exit-code", source, identity["source_commit"], "--", *paths)
    target_root = destination / "references" / name
    target_root.mkdir(parents=True)
    with tempfile.TemporaryFile() as body:
        subprocess.run(["git", "archive", "--format=tar", source, "--", "godot", "examples/worldgen"],
                       stdout=body, cwd=ROOT, check=True, timeout=150)
        body.seek(0)
        with tarfile.open(fileobj=body) as archive:
            for member in archive:
                if member.isdir():
                    continue
                need(member.isfile(), "Unexpected reference member: " + member.name)
                path = safe_name(member.name)
                if member.name.startswith("godot/.godot/") and member.name not in BOOTSTRAP:
                    continue
                if (path.suffix.lower() in {".dll", ".so", ".dylib", ".wasm"} or ".framework/" in member.name) and member.name not in {NATIVE, RAPIER}:
                    continue
                target = target_root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                if member.name in {NATIVE, RAPIER}:
                    shutil.copyfile(ROOT / member.name, target)
                else:
                    with archive.extractfile(member) as incoming, target.open("wb") as outgoing:
                        prefix = incoming.read(50)
                        need(not prefix.startswith(b"version https://git-lfs.github.com/spec/v1\n"),
                             "Unmaterialized reference LFS input: " + member.name)
                        outgoing.write(prefix)
                        shutil.copyfileobj(incoming, outgoing)
    need(all((target_root / path).is_file() for path in BOOTSTRAP), "Reference bootstrap missing")
    stage_generator_profiles(target_root)
    return {"source_commit": source, "source_tree": git("rev-parse", source + "^{tree}"),
            "project": f"references/{name}/godot", "native": identity["native"],
            "rapier": identity["rapier"], "observer_overlay": "Only in isolated comparison run copies"}


def stage_launchers(destination, source, references):
    campaign = json.loads((destination / TOOLS / "campaign.json").read_text(encoding="utf-8"))
    prefix = '@echo off\nsetlocal\ncd /d "%~dp0"\n'
    launchers = (("Open Workbench.cmd", "B", source, "godot", "Workbench-Project"),
                 ("Open Baseline Workbench.cmd", "B", references["integration"]["source_commit"],
                  references["integration"]["project"], "Workbench-Baseline-Project"),
                 ("Open Accepted Main.cmd", "A", references["main"]["source_commit"],
                  references["main"]["project"], "Workbench-Main-Project"),
                 ("Open Full Control Workbench.cmd", "A", source, "godot", "Workbench-Full-Project"))
    for filename, arm_name, application_source, project, working_project in launchers:
        arm = campaign["arms"][arm_name]
        project = project.replace("/", "\\")
        script = prefix + (
            'set "APPDATA=%~dp0Workbench-Profile"\n'
            'set "LOCALAPPDATA=%~dp0Workbench-Profile"\n'
            f'set "CYBERSAND_SOURCE_REVISION={application_source}"\n'
            f'set "CYBERSAND_SOURCE_SHA={application_source}"\n'
            'set "CYBERSAND_DIAG_FLYER_POSE="\n'
            'set "CYBERSAND_DIAG_RENDER_CADENCE="\n'
            'set "CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS="\n'
            'set "CYBERSAND_DIAG_MATERIAL_HISTORY_TARGETS="\n'
            'set "CYBERSAND_DIAG_MATERIAL_COPY_MODE="\n'
            'set "CYBERSAND_DIAG_COMMON_OBSERVER="\n'
            f'set "CYBERSAND_DIAG_PRESENTATION={arm["presentation"]}"\n'
            f'set "CYBERSAND_DIAG_MATERIAL_TIMING={arm["timing"]}"\n'
            f'set "CYBERSAND_MATERIAL_PUBLICATION={arm["material"]}"\n'
            f'set "CYBERSAND_DIAG_PHYSICS_PUBLICATION={arm["physics"]}"\n'
            f'set "CYBERSAND_DIAG_NATIVE_RENDEZVOUS={arm["rendezvous"]}"\n'
            f'"%SystemRoot%\\System32\\robocopy.exe" "%~dp0{project}" "%~dp0{working_project}" /E /XJ /R:1 /W:1 /NFL /NDL /NJH /NJS /NP\n'
            'if errorlevel 8 exit /b 1\n'
            f'"%~dp0{CONSOLE}" --headless --path "%~dp0{working_project}" --editor --quit\n'
            'if errorlevel 1 exit /b 1\n'
            f'start "" "%~dp0{GUI}" --path "%~dp0{working_project}" %* -- --workbench\n'
        )
        (destination / filename).write_bytes(script.replace("\n", "\r\n").encode())
    for name, script, flags in (("Test It.cmd", "Run-Test-It.ps1", ""),
                                ("Run Diagnostic.cmd", "Run-Test-It.ps1", " -Quick"),
                                ("Quick A-B Test.cmd", "Run-Source-Comparison.ps1", ""),
                                ("Transition A-B Test.cmd", "Run-Source-Comparison.ps1", " -Case transition_2048_w1"),
                                ("Verify Package.cmd", "Verify-Package.ps1", ""),
                                ("Pack Results.cmd", "Pack-Results.ps1", " -All")):
        path = f"{TOOLS}/{script}".replace("/", "\\")
        body = prefix + (f'"%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoLogo -NoProfile '
                         f'-ExecutionPolicy Bypass -File "%~dp0{path}"{flags} %*\nexit /b %errorlevel%\n')
        (destination / name).write_bytes(body.replace("\n", "\r\n").encode())


def file_hashes(folder):
    return {file.relative_to(folder).as_posix(): digest(file) for file in sorted(folder.rglob("*"))
            if file.is_file() and file.relative_to(folder).as_posix() not in {MANIFEST, ACCEPTANCE}}


def verify(folder, source):
    manifest = json.loads((folder / MANIFEST).read_text(encoding="utf-8"))
    need(manifest["schema"] == "pubpres-integration-windows-v1" and manifest["source_commit"] == source,
         "Output package source differs")
    for filename, expected in manifest["files_sha256"].items():
        need(digest(folder / safe_name(filename)) == expected, "Package contents changed: " + filename)
    for key in ("native", "rapier"):
        runtime = manifest[key]
        file = folder / safe_name(runtime["path"])
        need(digest(file) == runtime["sha256"] and file.stat().st_size == runtime["size"], "Runtime identity differs: " + key)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--accepted-main")
    parser.add_argument("--reference-integration", default=REFERENCE_INTEGRATION)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--godot-zip", type=Path)
    parser.add_argument("--notices", type=Path)
    parser.add_argument("--vc", type=Path)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    if args.verify:
        manifest = verify(output, args.source_sha)
        print(f"Verified {len(manifest['files_sha256'])} package files at {args.source_sha}")
        return
    need(os.name == "nt" and all((args.accepted_main, args.archive, args.godot_zip, args.notices, args.vc)),
         "Build on Windows with accepted main, archive, official Godot ZIP, notices, and staged VC runtime")
    archive_path = args.archive.resolve()
    need(not output.exists() and not archive_path.exists() and output not in archive_path.parents,
         "Both output paths must be new, with the ZIP outside the package directory")
    identity = source_identity(args.source_sha, args.accepted_main)
    output.mkdir(parents=True)
    stage_source(output, identity)
    identity["source_references"] = {
        "main": stage_reference(output, args.accepted_main, "main", identity),
        "integration": stage_reference(output, args.reference_integration, "integration", identity),
    }
    identity["engine"] = stage_dependencies(output, args.godot_zip, args.notices, args.vc)
    stage_launchers(output, identity["source_commit"], identity["source_references"])
    identity["acceptance_template_sha256"] = digest(output / ACCEPTANCE)
    identity["files_sha256"] = file_hashes(output)
    write_json(output / MANIFEST, identity)
    verify(output, args.source_sha)
    paths = sorted({*identity["files_sha256"], MANIFEST, ACCEPTANCE})
    need(len(set(name.lower() for name in paths)) == len(paths), "Windows filename collision")
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name in paths:
            archive.write(output / safe_name(name), name)
    with zipfile.ZipFile(archive_path) as archive:
        need(archive.testzip() is None, "Windows evaluation ZIP integrity failed")
    checksum = digest(archive_path)
    archive_path.with_suffix(".zip.sha256").write_text(f"{checksum}  {archive_path.name}\n", encoding="ascii")
    write_json(archive_path.with_suffix(".zip.json"), {"source_commit": args.source_sha,
               "source_tree": identity["source_tree"], "sha256": checksum, "bytes": archive_path.stat().st_size,
               "package_manifest_sha256": digest(output / MANIFEST), "physical_acceptance": "HOLD"})
    print(f"{checksum}  {archive_path}")


if __name__ == "__main__":
    main()
