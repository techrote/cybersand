#!/usr/bin/env python3
"""Assemble a new exact-source PUBPRES playability Windows owner evaluator.

Every M/I/C source supplies its own successful native build receipt and DLL.
Retained production provenance remains historical; it never authenticates a
different freshly built library. This utility does not launch CI or promote a
runtime, branch, PR, publication mode or renderer thread default.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import zipfile

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pubpres_playability_build"))
import dependency_custody

SCHEMA = "pubpres-playability-windows-v2"
COMPLETION_SCHEMA = "pubpres-completion-windows-v1"
LEGACY_MISSION = "PUBPRES-PLAYABILITY-001"
COMPLETION_MISSION = "PUBPRES-COMPLETION-001"
LEGACY_REGISTRATION = "tools/pubpres_playability/campaign.json"
COMPLETION_REGISTRATION = "tools/pubpres_completion/registration.json"
COMPLETION_REFERENCES = {
    "M": {"source_commit": "00cdb02f103265b6dc5224c68283e9a0c8cb449f",
          "source_tree": "06b62d73138028d1f7615b83edc9810491bf6287"},
    "I": {"source_commit": "8503ec19e4d620e125dc6df2c5c6571b1256cb92",
          "source_tree": "ece848ad77c06fafb60d597d87f9f53f7bc211f1"},
    "D": {"source_commit": "d316c281e0abb575eb6302afc12ec44f211460ba",
          "source_tree": "7a57dc0873dd161abe165f3a60e14e64886d04a8"},
}
OWNER_COMMAND = "Open Workbench.cmd"
OWNER_RESULTS_COMMAND = "Collect Results.cmd"
OWNER_RESULTS_COLLECTOR = "tools/pubpres_completion/Collect-PUBPRES-Results.ps1"
OWNER_ACCEPTANCE_SOURCE = "tools/pubpres_completion/ACCEPTANCE.md"
OWNER_ACCEPTANCE = "ACCEPTANCE.md"
MANIFEST = "PUBPRES-PLAYABILITY-MANIFEST.json"
RUNTIME_RECEIPT = "PUBPRES-RUNTIME.json"
NATIVE = "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
RAPIER_RECEIPT = "godot/addons/godot-rapier2d/runtime-provenance.windows.json"
NATIVE_RECEIPT = "godot/addons/cybersand_native/runtime-provenance.json"
GUI = "Godot_v4.7-stable_win64.exe"
CONSOLE = "Godot_v4.7-stable_win64_console.exe"
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
GODOT_SHA512 = ("41645a908eb3181d6f2d1201ed7b6d6f095f6a23aaed8903d5d255277cc8d142814f3e"
                "6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9")
GODOT_EXECUTABLE_SHA256 = {
    GUI: "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8",
    CONSOLE: "d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c",
}
NOTICE_HASHES = {"LICENSE.txt": "b0435e3b3e4e55238f05f4b306f30524a1b2e20147810d436eaa554fa6855c80",
                 "COPYRIGHT.txt": "cb1980c88089573bcacd7221d777c689bb8bbd778799f24c27fca0fe5f774d6d"}
VC_FILES = {"vcruntime140.dll", "Microsoft-Visual-C-Runtime-LICENSE.docx", "Microsoft-Visual-Studio-2022-LICENSE.docx"}
SCOPES = ("native/include", "native/src", "godot/native_extension")
SUFFIXES = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}
BOOTSTRAP = {"godot/.godot/.gdignore", "godot/.godot/extension_list.cfg", "godot/.godot/global_script_class_cache.cfg"}
TOOLS = "tools/pubpres_playability_windows"
BUILD_DRIVER = "tools/pubpres_playability_build/build_runtime.py"
SHA = re.compile(r"[0-9a-f]{64}")
COMMIT = re.compile(r"[0-9a-f]{40}")


def need(value, reason):
    if not value:
        raise ValueError(reason)


def digest(path, algorithm="sha256"):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, algorithm).hexdigest()


def canonical_digest(data):
    return hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest()


def owner_command(candidate):
    need(COMMIT.fullmatch(candidate), "Owner launcher requires the exact candidate source")
    lines = [
        "@echo off",
        "setlocal",
        "set \"adapter=\"",
        'if /i "%~1"=="--hosted-smoke" set "adapter=-RenderingDriver opengl3_angle -QuitAfterReady"',
        '"%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -ExecutionPolicy Bypass '
        '-File "%~dp0tools\\pubpres_playability_windows\\Start-PUBPRES-Playability.ps1" '
        '-PackageRoot "%~dp0." -ExpectedCandidate ' + candidate + ' -Action Open -OwnerProfile %adapter%',
        'set "result=%errorlevel%"',
        'if not "%result%"=="0" if "%adapter%"=="" pause',
        'exit /b %result%',
        "",
    ]
    return "\r\n".join(lines).encode("ascii")


def owner_results_command(candidate):
    need(COMMIT.fullmatch(candidate), "Result collection requires the exact candidate source")
    script = OWNER_RESULTS_COLLECTOR.replace("/", "\\")
    lines = [
        "@echo off",
        "setlocal",
        '"%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -ExecutionPolicy Bypass '
        f'-File "%~dp0{script}" -PackageRoot "%~dp0." -ExpectedCandidate {candidate}',
        'set "result=%errorlevel%"',
        'if /i not "%~1"=="--hosted-smoke" pause',
        'exit /b %result%',
        "",
    ]
    return "\r\n".join(lines).encode("ascii")


def source_features(key):
    experimental = key in ("C", "D")
    return {"reachable_staging_pools": experimental, "wave_column_tiles": False,
            "wave_column_slots": 1, "wave_stage_probe": experimental, "same_frame_continuation": experimental}


def safe_name(name):
    need(isinstance(name, str) and name and len(name) <= 1024, "Invalid payload path")
    path = PurePosixPath(name)
    need(not path.is_absolute() and str(path) == name and ".." not in path.parts, "Unsafe payload path: " + name)
    for part in path.parts:
        need(not re.search(r'[<>:"|?*\\\x00-\x1f]', part) and not part.endswith((".", " "))
             and not re.fullmatch(r"(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?", part),
             "Windows-incompatible payload path: " + name)
    return path


def git(root, *args, binary=False):
    result = subprocess.check_output(["git", "-C", str(root), *args], timeout=150)
    return result if binary else result.decode("utf-8").strip()


def committed(root, source, name):
    safe_name(name)
    return git(root, "show", source + ":" + name, binary=True)


def write_json(path, data):
    Path(path).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def pe_x64(path):
    data = Path(path).read_bytes()
    need(len(data) >= 64 and data[:2] == b"MZ", "Not a Windows PE library/executable: " + str(path))
    offset = struct.unpack_from("<I", data, 0x3c)[0]
    need(offset + 6 <= len(data) and data[offset:offset+6] == b"PE\0\0\x64\x86", "Not Windows x64: " + str(path))


def native_inputs(root, source):
    names = git(root, "ls-tree", "-r", "--name-only", source, "--", *SCOPES).splitlines()
    selected = sorted(name for name in names if PurePosixPath(name).suffix in SUFFIXES)
    need(selected, "Empty native source closure")
    return {name: canonical_digest(committed(root, source, name)) for name in selected}


def verify_runtime(root, source, directory):
    directory = Path(directory)
    record = json.loads((directory / RUNTIME_RECEIPT).read_text(encoding="utf-8"))
    need(record.get("schema") == "pubpres-playability-native-build-v1" and record.get("platform") == "windows",
         "Expected a new PUBPRES Windows native build receipt")
    need(record.get("source_commit") == source and record.get("source_tree") == git(root, "rev-parse", source + "^{tree}"),
         "Runtime source/ancestry differs from this source project")
    need(record.get("returncode") == 0 and record.get("production_runtime_promotion") is False,
         "Native build was incomplete or claims production promotion")
    need(record.get("source_inputs_sha256") == native_inputs(root, source), "Native source closure differs from its own exact source")
    need(record.get("build_script") == "tools/build_native_extension_windows.sh"
         and record.get("build_script_sha256") == canonical_digest(committed(root, source, record["build_script"])),
         "Native build script differs from its source")
    need(record.get("runtime_file") == PurePosixPath(NATIVE).name, "Wrong Windows runtime filename")
    library = directory / record["runtime_file"]
    pe_x64(library)
    need(digest(library) == record.get("runtime_sha256") and library.stat().st_size == record.get("runtime_bytes"),
         "Fresh native DLL differs from build receipt")
    need((directory / "build.log").is_file() and digest(directory / "build.log") == record.get("log_sha256"),
         "Native build log missing or changed")
    need(COMMIT.fullmatch(record.get("godot_cpp_commit", "")) and SHA.fullmatch(record.get("godot_cpp_library_sha256", ""))
         and record.get("compiler_command") and record.get("compiler_version") and record.get("toolchain_drift_allowed") is False,
         "Incomplete or drifted native toolchain identity")
    dependency_custody.verify(directory, record)
    dependency_custody.verify_driver(Path(__file__).resolve().parents[1] / "pubpres_playability_build", record)
    return record


def lfs_bytes(root, source, name, data):
    if not data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
        return data
    match = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", data)
    need(match is not None, "Noncanonical LFS pointer: " + name)
    actual = (root / name).read_bytes()
    need(hashlib.sha256(actual).hexdigest() == match[1].decode() and len(actual) == int(match[2]), "Unmaterialized or changed LFS bytes: " + name)
    return actual


def archive_source(root, source, destination, names):
    with tempfile.TemporaryFile() as stream:
        # Archive export observes Git's working-tree EOL configuration. Old
        # comparison sources lack an explicit .import attribute; canonical LF
        # prevents Godot's legitimate import pass from changing their bytes.
        # Explicit source attributes (including CRLF launchers) still apply.
        subprocess.run(["git", "-c", "core.autocrlf=false", "-c", "core.eol=lf",
                        "-C", str(root), "archive", "--format=tar", source, "--", *sorted(set(names))],
                       check=True, stdout=stream, timeout=180)
        stream.seek(0)
        with tarfile.open(fileobj=stream) as archive:
            seen = set()
            for member in archive:
                if member.isdir():
                    continue
                need(member.isfile(), "Unexpected non-file Git archive member: " + member.name)
                name = member.name
                path = safe_name(name)
                need(name.lower() not in seen, "Windows case-colliding Git paths")
                seen.add(name.lower())
                if name.startswith("godot/.godot/") and name not in BOOTSTRAP:
                    continue
                if name == NATIVE:
                    continue  # Installed only from this source's independently verified build.
                if (path.suffix.lower() in {".dll", ".so", ".dylib", ".wasm", ".pdb"} or ".framework/" in name) and name != RAPIER:
                    continue
                data = lfs_bytes(root, source, name, archive.extractfile(member).read())
                target = destination / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)


def stage_project(root, source, key, runtime_dir, output, mission=LEGACY_MISSION):
    need(COMMIT.fullmatch(source) and git(root, "rev-parse", "HEAD") == source, "Supply the exact checked-out " + key + " source")
    runtime = verify_runtime(root, source, runtime_dir)
    rapier = json.loads(committed(root, source, RAPIER_RECEIPT))
    need(rapier.get("artifact") == RAPIER and rapier.get("source_inputs"), "Missing source-bound retained Rapier receipt")
    for name, expected in rapier["source_inputs"].items():
        need(canonical_digest(committed(root, source, name)) == expected, "Retained Rapier input differs: " + name)
    prefix = "sources/" + key
    target = output / prefix
    target.mkdir(parents=True)
    paths = {"godot", "examples/worldgen", "LICENSE_STATUS.md", "THIRD_PARTY_NOTICES.md",
             "third_party/godot-runtime.lock.json", "third_party/native-toolchain.lock.json",
             *runtime["source_inputs_sha256"], runtime["build_script"], *rapier["source_inputs"]}
    archive_source(root, source, target, paths)
    need(all((target / name).is_file() for name in BOOTSTRAP), "Missing portable project bootstrap: " + key)
    pe_x64(target / RAPIER)
    need(digest(target / RAPIER) == rapier.get("sha256") and (target / RAPIER).stat().st_size == rapier.get("size"),
         "Retained Rapier binary differs from its own source receipt")
    native_target = target / NATIVE
    native_target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(Path(runtime_dir) / runtime["runtime_file"], native_target)
    provenance = target / "provenance"
    provenance.mkdir()
    for name in (RUNTIME_RECEIPT, "build.log", *dependency_custody.FILES):
        shutil.copyfile(Path(runtime_dir) / name, provenance / name)
    # Preserve the original publication under an explicitly historical name.
    # A new diagnostic manifest binds the installed candidate DLL so ordinary
    # host-observation readers never describe its bytes using the old receipt.
    historical = target / NATIVE_RECEIPT
    historical.rename(historical.with_name("retained-runtime-provenance.reference.json"))
    derived = {"schema_version": 1, "status": mission + " experiment; production and owner acceptance HOLD",
               "artifact": NATIVE, "source_commit": source, "source_tree": runtime["source_tree"],
               "sha256": runtime["runtime_sha256"], "size": runtime["runtime_bytes"],
               "source_inputs": runtime["source_inputs_sha256"], "build_commit": source,
               "build_receipt": prefix + "/provenance/" + RUNTIME_RECEIPT,
               "build_receipt_sha256": digest(provenance / RUNTIME_RECEIPT),
               "mapped_module_binding": "unverified; path-file observation alone is not loaded-module proof",
               "production_runtime_promotion": False}
    write_json(historical, derived)
    recipes = sorted((target / "examples/worldgen").glob("*.json"))
    need({"gen007-deepworks.json", "gen007-qualification.json"} <= {p.name for p in recipes}, "Required authoring recipes missing")
    resource_recipes = target / "godot/authoring/worldgen"
    resource_recipes.mkdir(parents=True, exist_ok=True)
    for recipe in recipes:
        need(recipe.stat().st_size <= 1024 * 1024 and isinstance(json.loads(recipe.read_bytes()), dict), "Invalid authoring recipe")
        shutil.copyfile(recipe, resource_recipes / recipe.name)
    return {"source_commit": source, "source_tree": runtime["source_tree"], "parents": git(root, "rev-list", "--parents", "-1", source).split()[1:],
            "root": prefix, "project": prefix + "/godot", "native": {"path": prefix + "/" + NATIVE, "sha256": runtime["runtime_sha256"],
                "bytes": runtime["runtime_bytes"], "receipt": prefix + "/provenance/" + RUNTIME_RECEIPT,
                "receipt_sha256": digest(provenance / RUNTIME_RECEIPT), "source_input_count": len(runtime["source_inputs_sha256"])},
            "rapier": {"path": prefix + "/" + RAPIER, "sha256": rapier["sha256"], "bytes": rapier["size"],
                "receipt": prefix + "/" + RAPIER_RECEIPT},
            "toolchain": {name: runtime[name] for name in ("godot_cpp_commit", "godot_cpp_library_sha256", "godot_cpp_dependency_sha256", "compiler_command", "compiler_version", "toolchain_drift_allowed")},
            "features": source_features(key),
            "source_projection": "Exact committed project and closure; new source-matched DLL/provenance and canonical recipe copies are explicit package additions."}


def stage_dependencies(output, engine_zip, vc, notices):
    need(digest(engine_zip, "sha512") == GODOT_SHA512, "Official Godot Windows archive SHA-512 differs")
    with zipfile.ZipFile(engine_zip) as archive:
        need(archive.testzip() is None, "Godot archive CRC failed")
        for name in (GUI, CONSOLE):
            need(archive.namelist().count(name) == 1, "Missing or duplicate official engine entry")
            (output / name).write_bytes(archive.read(name))
            pe_x64(output / name)
            need(digest(output / name) == GODOT_EXECUTABLE_SHA256[name], "Official engine entry bytes differ")
    version = subprocess.check_output([str(output / CONSOLE), "--version"], text=True, timeout=45).strip()
    need(version == GODOT_VERSION, "Packaged engine version differs")
    for name, expected in NOTICE_HASHES.items():
        need(digest(notices / name) == expected, "Official engine notice differs")
        shutil.copyfile(notices / name, output / ("Godot-" + name))
    record = json.loads((vc / "vc-runtime-provenance.json").read_text(encoding="utf-8-sig"))
    need(record.get("schema") == 1 and set(record.get("files_sha256", {})) == VC_FILES
         and record.get("authenticode", {}).get("status") == "Valid", "Signed VC runtime/licence stage incomplete")
    for name, expected in record["files_sha256"].items():
        need(SHA.fullmatch(expected) and digest(vc / name) == expected, "VC runtime stage changed: " + name)
        shutil.copyfile(vc / name, output / name)
    pe_x64(output / "vcruntime140.dll")
    shutil.copyfile(vc / "vc-runtime-provenance.json", output / "vc-runtime-provenance.json")
    return {"version": version, "archive_sha512": GODOT_SHA512,
            "gui": {"path": GUI, "sha256": digest(output / GUI)},
            "console": {"path": CONSOLE, "sha256": digest(output / CONSOLE)},
            "vc_runtime_sha256": digest(output / "vcruntime140.dll")}


def file_hashes(output):
    need(not output.is_symlink() and not (getattr(output.lstat(), "st_file_attributes", 0) & 0x400),
         "Package root must not be a symbolic link or reparse point")
    result = {}
    for directory, directories, files in os.walk(output, followlinks=False):
        # Check directory links before os.walk can descend into a junction.
        for child in [*directories, *files]:
            path = Path(directory) / child
            need(not path.is_symlink() and not (getattr(path.lstat(), "st_file_attributes", 0) & 0x400),
                 "Symbolic links/reparse points are not permitted in a package")
        for child in files:
            path = Path(directory) / child
            name = path.relative_to(output).as_posix()
            if name not in {MANIFEST, MANIFEST + ".sha256"}:
                safe_name(name)
                result[name] = digest(path)
                need(len(result) <= 30000, "Payload file inventory exceeds its finite allowance")
    return dict(sorted(result.items()))


def verify_registration(output, record, completion):
    registration = COMPLETION_REGISTRATION if completion else LEGACY_REGISTRATION
    need(record["campaign"] == registration, "Owner comparison registration path differs")
    need(digest(output / registration) == record["campaign_sha256"], "Frozen comparison corpus differs")
    campaign = json.loads((output / registration).read_text(encoding="utf-8"))
    if completion:
        need(campaign["schema"] == "pubpres-completion-campaign-v1"
             and campaign["reference_sources"] == COMPLETION_REFERENCES
             and campaign["ordinary_defaults"]["material_publication"] == "full", "Completion reference registration differs")
        for key, expected in COMPLETION_REFERENCES.items():
            need({field: record["sources"][key][field] for field in expected} == expected,
                 "Completion source identity differs: " + key)
        need(campaign["predecessor_registration"]["path"] == LEGACY_REGISTRATION
             and campaign["predecessor_registration"]["sha256"] == "42b0fa3569e3df3cb4f06330c2f24f0c913ef8d1196e494900f59ae1134220ef"
             and digest(output / LEGACY_REGISTRATION) == campaign["predecessor_registration"]["sha256"],
             "Frozen predecessor registration changed")
        need(record["owner_command"] == OWNER_COMMAND and (output / OWNER_COMMAND).read_bytes()
             == owner_command(record["candidate_commit"]), "Owner Windows command differs")
        need(record.get("owner_results_command") == OWNER_RESULTS_COMMAND
             and record.get("owner_results_collector") == OWNER_RESULTS_COLLECTOR
             and record.get("owner_acceptance") == OWNER_ACCEPTANCE
             and {OWNER_RESULTS_COMMAND, OWNER_RESULTS_COLLECTOR, OWNER_ACCEPTANCE, OWNER_ACCEPTANCE_SOURCE} <= set(record["files_sha256"])
             and (output / OWNER_RESULTS_COMMAND).read_bytes() == owner_results_command(record["candidate_commit"])
             and digest(output / OWNER_ACCEPTANCE) == digest(output / OWNER_ACCEPTANCE_SOURCE),
             "Owner acceptance or result collection entrypoint differs")
        need(record["owner_material"] == "full", "Owner material publication default differs")
        campaign = json.loads((output / LEGACY_REGISTRATION).read_text(encoding="utf-8"))
    else:
        need(campaign["source_commits"] == {label: record["sources"][key]["source_commit"]
             for key, label in (("M", "main"), ("I", "integration"))}, "Comparison source registration differs")
    need(campaign["schema"] == "pubpres-playability-campaign-v3", "Frozen apparatus schema differs")
    for name, expected in campaign["overlay_sha256"].items():
        need(digest(output / "sources/C/godot" / safe_name(name)) == expected, "Frozen observer overlay differs")


def verify(output, candidate):
    output = Path(output)
    manifest_path = output / MANIFEST
    record = json.loads(manifest_path.read_text(encoding="utf-8"))
    completion = record.get("schema") == COMPLETION_SCHEMA
    mission = COMPLETION_MISSION if completion else LEGACY_MISSION
    need(record.get("schema") in (SCHEMA, COMPLETION_SCHEMA) and record.get("candidate_commit") == candidate
         and COMMIT.fullmatch(candidate) and record.get("mission", LEGACY_MISSION) == mission, "Package candidate/schema differs")
    need((output / (MANIFEST + ".sha256")).read_text(encoding="ascii") == f"{digest(manifest_path)}  {MANIFEST}\n", "Manifest checksum differs")
    names = record.get("files_sha256", {})
    need(names and len(names) == record.get("file_count") and len(names) <= 30000
         and len({p.lower() for p in names}) == len(names), "Invalid payload inventory")
    observed = file_hashes(output)
    need(set(observed) == set(names), "Package has missing or unexpected files; use pristine payload, not a stale folder")
    for name, expected in names.items():
        safe_name(name)
        need(not (output / name).is_symlink() and SHA.fullmatch(expected) and observed[name] == expected, "Changed package file: " + name)
    need(set(record.get("sources", {})) == ({"M", "I", "D", "C"} if completion else {"M", "I", "C"}),
         "Missing independent source projects")
    toolchains = []
    for key, source in record["sources"].items():
        need(COMMIT.fullmatch(source["source_commit"]) and COMMIT.fullmatch(source["source_tree"]), "Incomplete source identity")
        prefix = "sources/" + key
        need(source["root"] == prefix and source["project"] == prefix + "/godot"
             and source["native"]["path"] == prefix + "/" + NATIVE
             and source["native"]["receipt"] == prefix + "/provenance/" + RUNTIME_RECEIPT
             and source["rapier"]["path"] == prefix + "/" + RAPIER
             and source["rapier"]["receipt"] == prefix + "/" + RAPIER_RECEIPT, "Cross-source runtime path substitution")
        for runtime in (source["native"], source["rapier"]):
            pe_x64(output / safe_name(runtime["path"]))
            need(digest(output / runtime["path"]) == runtime["sha256"] and (output / runtime["path"]).stat().st_size == runtime["bytes"], "Runtime bytes differ")
        need(digest(output / source["native"]["receipt"]) == source["native"]["receipt_sha256"], "Native receipt hash differs")
        native = json.loads((output / source["native"]["receipt"]).read_text(encoding="utf-8"))
        need(native["schema"] == "pubpres-playability-native-build-v1" and native["platform"] == "windows"
             and native["returncode"] == 0 and native["source_commit"] == source["source_commit"] and native["source_tree"] == source["source_tree"]
             and native["runtime_file"] == PurePosixPath(NATIVE).name
             and native["runtime_sha256"] == source["native"]["sha256"] and native["runtime_bytes"] == source["native"]["bytes"]
             and native["production_runtime_promotion"] is False and native["toolchain_drift_allowed"] is False,
             "Cross-source native receipt substitution or unsupported promotion")
        need(len(native["source_inputs_sha256"]) == source["native"]["source_input_count"], "Incomplete native closure count")
        actual_inputs = {path.relative_to(output / prefix).as_posix() for scope in SCOPES
                         for path in (output / prefix / scope).rglob("*") if path.is_file() and path.suffix in SUFFIXES}
        need(actual_inputs and actual_inputs == set(native["source_inputs_sha256"]), "Native source closure set differs")
        for name, expected in native["source_inputs_sha256"].items():
            need(SHA.fullmatch(expected) and canonical_digest((output / prefix / safe_name(name)).read_bytes()) == expected,
                 "Packaged native source differs: " + key + "/" + name)
        need(native["build_script"] == "tools/build_native_extension_windows.sh"
             and canonical_digest((output / prefix / native["build_script"]).read_bytes()) == native["build_script_sha256"], "Packaged build script differs")
        need(digest(output / source["root"] / "provenance/build.log") == native["log_sha256"], "Packaged build log differs")
        need(digest(output / BUILD_DRIVER) == native["driver_sha256"], "Exact native build driver differs")
        dependency = dependency_custody.verify(output / prefix / "provenance", native)
        need(dependency["builder_commit"] == record["candidate_commit"], "Dependency builder does not identify this candidate source")
        dependency_custody.verify_driver((output / BUILD_DRIVER).parent, native)
        actual_toolchain = {name: native[name] for name in ("godot_cpp_commit", "godot_cpp_library_sha256", "godot_cpp_dependency_sha256", "compiler_command", "compiler_version", "toolchain_drift_allowed")}
        need(actual_toolchain == source["toolchain"] and COMMIT.fullmatch(native["godot_cpp_commit"])
             and SHA.fullmatch(native["godot_cpp_library_sha256"]) and native["compiler_command"] and native["compiler_version"],
             "Toolchain receipt is missing or inconsistent")
        rapier = json.loads((output / source["rapier"]["receipt"]).read_text(encoding="utf-8"))
        need(rapier["artifact"] == RAPIER and rapier["sha256"] == source["rapier"]["sha256"] and rapier["size"] == source["rapier"]["bytes"]
             and rapier.get("source_inputs"), "Retained Rapier identity differs")
        for name, expected in rapier["source_inputs"].items():
            need(SHA.fullmatch(expected) and canonical_digest((output / prefix / safe_name(name)).read_bytes()) == expected,
                 "Retained Rapier source differs")
        derived = json.loads((output / prefix / NATIVE_RECEIPT).read_text(encoding="utf-8"))
        need(derived["source_commit"] == source["source_commit"] and derived["sha256"] == native["runtime_sha256"]
             and derived["source_inputs"] == native["source_inputs_sha256"] and derived["build_receipt"] == source["native"]["receipt"]
             and derived["build_receipt_sha256"] == source["native"]["receipt_sha256"] and derived["production_runtime_promotion"] is False,
             "Runtime observation would read stale or misleading provenance")
        need(source["features"] == source_features(key), "Unsupported experimental feature advertisement")
        toolchains.append(source["toolchain"])
    need(all(toolchain == toolchains[0] for toolchain in toolchains), "Comparison runtimes use unmatched toolchains")
    need(record["sources"]["C"]["source_commit"] == candidate and record["physical_acceptance"] == "HOLD"
         and record["production_defaults_changed"] is False
         and record["experimental_defaults"] == {"staging_pools": "eager", "render_thread": "safe", "wave_column_tiles": False, "same_frame_continuation": "off"},
         "Candidate source, defaults or owner hold differs")
    need(record["package_filename"] == "CyberSand-" + mission + "-" + candidate[:12] + "-Windows.zip",
         "Incorrect evaluator filename")
    engine = record["engine"]
    need(engine["version"] == GODOT_VERSION and engine["archive_sha512"] == GODOT_SHA512
         and engine["gui"]["path"] == GUI and engine["console"]["path"] == CONSOLE, "Pinned engine identity differs")
    for entry in (engine["gui"], engine["console"]):
        pe_x64(output / entry["path"])
        need(digest(output / entry["path"]) == entry["sha256"], "Packaged engine differs")
        if completion:
            need(entry["sha256"] == GODOT_EXECUTABLE_SHA256[entry["path"]], "Completion engine bytes differ from pin")
    vc = json.loads((output / "vc-runtime-provenance.json").read_text(encoding="utf-8-sig"))
    need(vc["schema"] == 1 and set(vc["files_sha256"]) == VC_FILES and vc["authenticode"]["status"] == "Valid", "VC runtime provenance differs")
    for name, expected in vc["files_sha256"].items():
        need(digest(output / name) == expected, "VC runtime or license differs")
    need(engine["vc_runtime_sha256"] == digest(output / "vcruntime140.dll"), "VC runtime engine binding differs")
    need(record["owner_launcher"] == TOOLS + "/Start-PUBPRES-Playability.ps1"
         and record["owner_observer"] == TOOLS + "/owner_start.gd", "Owner entrypoint changed")
    verify_registration(output, record, completion)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-sha", required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--mission", choices=(LEGACY_MISSION, COMPLETION_MISSION))
    for key in ("candidate", "main", "integration", "donor"):
        parser.add_argument("--" + key + "-root", type=Path)
        if key != "candidate":
            parser.add_argument("--" + key + "-sha")
        parser.add_argument("--" + key + "-runtime", type=Path)
    parser.add_argument("--godot-zip", type=Path)
    parser.add_argument("--vc-runtime", type=Path)
    parser.add_argument("--notices", type=Path)
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    output = args.output_dir.resolve()
    if args.verify:
        result = verify(output, args.candidate_sha)
        need(args.mission is None or result.get("mission", LEGACY_MISSION) == args.mission,
             "Verified package mission differs")
        print(json.dumps({"verified_files": result["file_count"], "candidate": args.candidate_sha, "physical_acceptance": "HOLD"}))
        return
    need(os.name == "nt", "Build the Windows evaluator on actual Windows; metadata tests can run elsewhere")
    mission = args.mission or LEGACY_MISSION
    completion = mission == COMPLETION_MISSION
    source_order = {"M": "main", "I": "integration", "C": "candidate"}
    if completion:
        source_order["D"] = "donor"
    source_shas = {"C": args.candidate_sha, "M": args.main_sha, "I": args.integration_sha, "D": args.donor_sha}
    need(all(getattr(args, name) for name in ("godot_zip", "vc_runtime", "notices", "archive")),
         "Godot archive, signed VC stage, notices and output archive are required")
    archive_path = args.archive.resolve()
    need(all(getattr(args, label + "_runtime") and getattr(args, label + "_root")
             and source_shas[key] for key, label in source_order.items()), "Supply every independent source/runtime")
    need(completion or not any((args.donor_sha, args.donor_root, args.donor_runtime)),
         "Use the Completion package profile for the independent donor")
    expected_name = "CyberSand-" + mission + "-" + args.candidate_sha[:12] + "-Windows.zip"
    need(COMMIT.fullmatch(args.candidate_sha) and archive_path.name == expected_name, "Use the exact source-bound package filename: " + expected_name)
    need(not output.exists() and not archive_path.exists() and not archive_path.with_suffix(".zip.sha256").exists()
         and not archive_path.with_suffix(".zip.json").exists()
         and output not in archive_path.parents, "Output, ZIP and sidecar must be new; archive stays outside payload")
    root = args.candidate_root.resolve()
    need(canonical_digest(Path(__file__).read_bytes()) == canonical_digest(committed(root, args.candidate_sha, TOOLS + "/package_windows.py")), "Packaging script differs from candidate commit")
    for key, label in source_order.items():
        if key == "C":
            continue
        source = source_shas[key]
        git(root, "merge-base", "--is-ancestor", source, args.candidate_sha)
        if completion:
            need(COMPLETION_REFERENCES[key] == {"source_commit": source,
                 "source_tree": git(getattr(args, label + "_root"), "rev-parse", source + "^{tree}")},
                 "Wrong independent Completion source: " + key)
    output.mkdir(parents=True)
    sources = {}
    for key, label in source_order.items():
        sources[key] = stage_project(getattr(args, label + "_root"), source_shas[key], key,
                                     getattr(args, label + "_runtime"), output, mission)
    packaged_tools = [TOOLS, "tools/pubpres_playability", "tools/pubpres_playability_build"]
    readme = TOOLS + "/README.md"
    if completion:
        readme = "tools/pubpres_completion/README.md"
        packaged_tools.extend((COMPLETION_REGISTRATION, readme, OWNER_ACCEPTANCE_SOURCE, OWNER_RESULTS_COLLECTOR))
        (output / OWNER_COMMAND).write_bytes(owner_command(args.candidate_sha))
        (output / OWNER_RESULTS_COMMAND).write_bytes(owner_results_command(args.candidate_sha))
    archive_source(root, args.candidate_sha, output, packaged_tools)
    engine = stage_dependencies(output, args.godot_zip, args.vc_runtime, args.notices)
    shutil.copyfile(output / readme, output / "READ-ME.md")
    if completion:
        shutil.copyfile(output / OWNER_ACCEPTANCE_SOURCE, output / OWNER_ACCEPTANCE)
    registration = COMPLETION_REGISTRATION if completion else LEGACY_REGISTRATION
    record = {"schema": COMPLETION_SCHEMA if completion else SCHEMA, "mission": mission, "candidate_commit": args.candidate_sha,
              "package_filename": expected_name, "sources": sources, "engine": engine,
              "campaign": registration, "campaign_sha256": digest(output / registration),
              "owner_launcher": TOOLS + "/Start-PUBPRES-Playability.ps1", "owner_observer": TOOLS + "/owner_start.gd",
              "experimental_defaults": {"staging_pools": "eager", "render_thread": "safe", "wave_column_tiles": False, "same_frame_continuation": "off"},
              "physical_acceptance": "HOLD", "production_defaults_changed": False,
              "qualification_scope": "Fresh source-matched Windows evaluator. Hosted software-renderer results and owner physical NVIDIA acceptance are distinct."}
    if completion:
        record["owner_command"] = OWNER_COMMAND
        record["owner_material"] = "full"
        record["owner_results_command"] = OWNER_RESULTS_COMMAND
        record["owner_results_collector"] = OWNER_RESULTS_COLLECTOR
        record["owner_acceptance"] = OWNER_ACCEPTANCE
    record["files_sha256"] = file_hashes(output)
    record["file_count"] = len(record["files_sha256"])
    write_json(output / MANIFEST, record)
    (output / (MANIFEST + ".sha256")).write_text(f"{digest(output / MANIFEST)}  {MANIFEST}\n", encoding="ascii")
    verify(output, args.candidate_sha)
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name in sorted([*record["files_sha256"], MANIFEST, MANIFEST + ".sha256"]):
            archive.write(output / safe_name(name), name)
    with zipfile.ZipFile(archive_path) as archive:
        need(archive.testzip() is None, "Fresh evaluator ZIP integrity failed")
    checksum = digest(archive_path)
    archive_path.with_suffix(".zip.sha256").write_text(f"{checksum}  {archive_path.name}\n", encoding="ascii")
    write_json(archive_path.with_suffix(".zip.json"), {"schema": record["schema"], "mission": mission, "candidate_commit": args.candidate_sha,
               "archive_sha256": checksum, "archive_bytes": archive_path.stat().st_size,
               "manifest_sha256": digest(output / MANIFEST), "physical_acceptance": "HOLD"})
    print(f"{checksum}  {archive_path.name}")


if __name__ == "__main__":
    main()
