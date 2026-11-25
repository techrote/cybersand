#!/usr/bin/env python3
"""Prepare a source-matched, isolated Windows owner evaluator; never a release.

Reuse the established engine/notices, VC redistributable, recipe staging and
import-sidecar admission. The qualification must have executed this exact head
on Windows. Package source comes from its Git tree, not editor-generated files.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import run_windows_godot_regressions as windows
from package_explore001_candidate import stage_generator_profiles, stage_vc_runtime
from package_wave_flow_candidate import archive_environment, omit_regenerated_imports
from package_workbench_landscape_review import DEPENDENCIES


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def read_json(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "Duplicate JSON identity key: " + key)
            result[key] = value
        return result
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique)


def git(*args, env=None):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], env=env, timeout=120)


NORMAL_CASES = {
    "import", "test_gameplay_recorder", "test_workbench_material_baseline", "test_architectural_generator_ui",
    "test_workbench_generator_discovery", "test_paint_editor_history", "test_paint_editor_history-reopen",
    "test_workbench_canvas", "test_workbench_canvas-reopen", "test_explore001_generated_workbench",
    "test_explore001_generated_workbench-reopen",
    "test_worldgen_workbench", "test_material_lab_experiment", "test_transport_profiles",
    "test_water_feel_controller", "test_art_storage_integrity", "test_art_traffic_integrity",
    "test_art_traffic_panel_safety", "test_art_session_log", "test_art_panel_ui",
}
WINDOWS_FAULT_CASES = {
    ("shared-helper", None, "injected-and-native-boundaries"),
    *((kind, None, "real-writer-fresh-process-reload") for kind in ("ordinary", "generated", "project")),
    *((kind, "locked-target", "real-os-failure") for kind in ("ordinary", "generated", "project")),
    ("helper", "locked-source-with-unlocked-destination", "real-os-failure"),
    ("helper", "process-termination-before-commit", "real-process-termination"),
    ("helper", None, "real-concurrent-processes"),
}
WINDOWS_CAPTURE_CASES = {
    *((kind, None, "real-public-caller") for kind in ("controller", "cli")),
    *((kind, "locked-target", "real-os-failure") for kind in ("controller", "cli")),
}
WINDOWS_PROFILE_CASES = {
    *((kind, fault, evidence) for kind in ("worldgen", "material-lab", "transport", "water")
      for fault, evidence in (("none", "real-public-caller"),
                              ("invalid-input", "public-admission-refusal"),
                              ("locked-target", "real-os-failure"))),
}
WINDOWS_ART_CASES = {
    *((operation, "none") for operation in ("export", "new-event", "append")),
    *((operation, "locked-target") for operation in ("export", "append")),
}


def validate_qualification(qualification, head, tree):
    require(qualification.get("schema") == "ultima-nonpublishing-qualification-v2"
            and qualification.get("status") == "passed" and qualification.get("completed") is True
            and qualification.get("host") == "win32" and qualification.get("changed_inputs") == []
            and qualification.get("errors") == []
            and qualification.get("source_head") == head and qualification.get("source_tree") == tree,
            "A passed exact-head Windows qualification is required")
    cases = qualification.get("cases", [])
    require(len(cases) == len(NORMAL_CASES) and {c.get("name") for c in cases} == NORMAL_CASES,
            "Incomplete or duplicate normal workflow qualification")
    for case in cases:
        require(case.get("status") == "passed" and case.get("returncode") == 0
                and case.get("natural_completion") is True and case.get("skip_messages") == []
                and not any(case.get(key) for key in ("launch_error", "diagnostic_error", "capture_error",
                                                      "timeout_kind", "timeout_diagnostic_error")),
                "Unsuccessful or incomplete normal workflow: " + str(case.get("name")))
    fault = qualification.get("persistence", {})
    require(fault.get("schema") == "workbench-save-qualification-v1" and fault.get("status") == "passed"
            and fault.get("completed") is True and fault.get("platform") == "win32"
            and fault.get("source_head") == head, "Incomplete or mismatched persistence qualification")
    fault_cases = fault.get("cases", [])
    require(len(fault_cases) == len(WINDOWS_FAULT_CASES)
            and {(c.get("kind"), c.get("fault"), c.get("evidence_class")) for c in fault_cases} == WINDOWS_FAULT_CASES,
            "Incomplete or duplicate Windows fault matrix")
    shared = next(c["result"] for c in fault_cases if c["kind"] == "shared-helper")
    require(type(shared.get("checks")) is int and shared["checks"] > 0 and shared.get("failures") == [],
            "Shared transaction assertions did not pass")
    engine = qualification.get("engine", {})
    require(engine.get("version") == windows.GODOT_VERSION and engine.get("archive_sha512") == windows.GODOT_SHA512
            and engine.get("runtime_sha256") == DEPENDENCIES["Godot_v4.7-stable_win64.exe"]
            and engine.get("console_sha256") == DEPENDENCIES["Godot_v4.7-stable_win64_console.exe"]
            and fault.get("engine_version") == engine["version"]
            and fault.get("engine_sha256") == engine["console_sha256"], "Mismatched qualified Windows engine")
    capture = qualification.get("microscenario_capture", {})
    require(capture.get("schema") == "microscenario-capture-qualification-v1"
            and capture.get("status") == "passed" and capture.get("completed") is True
            and capture.get("platform") == "win32" and capture.get("source_head") == head
            and capture.get("engine_version") == engine["version"]
            and capture.get("engine_sha256") == engine["console_sha256"],
            "Incomplete or mismatched MicroScenario capture qualification")
    capture_cases = capture.get("cases", [])
    require(len(capture_cases) == len(WINDOWS_CAPTURE_CASES)
            and {(c.get("kind"), c.get("fault"), c.get("evidence_class")) for c in capture_cases}
            == WINDOWS_CAPTURE_CASES, "Incomplete or duplicate Windows capture fault matrix")
    recorder = qualification.get("recorder_storage", {})
    require(recorder.get("schema") == 1 and recorder.get("status") == "passed"
            and recorder.get("passed") is True and recorder.get("completed") is True
            and recorder.get("platform") == "win32" and recorder.get("source_head") == head
            and recorder.get("engine_version") == engine["version"]
            and recorder.get("engine_sha256") == engine["console_sha256"],
            "Incomplete or mismatched recorder storage qualification")
    recorder_cases = recorder.get("cases", [])
    require(len(recorder_cases) == 2 and {c.get("fault") for c in recorder_cases} == {"none", "locked-manifest"}
            and all(c.get("passed") is True and c.get("exit_code") == 0
                    and c.get("natural_completion") is True and c.get("engine_error_detected") is False
                    for c in recorder_cases), "Incomplete or unsuccessful Windows recorder fault matrix")
    profile = qualification.get("profile_save", {})
    require(profile.get("schema") == "profile-save-qualification-v1" and profile.get("status") == "passed"
            and profile.get("completed") is True and profile.get("platform") == "win32"
            and profile.get("source_head") == head and profile.get("engine_version") == engine["version"]
            and profile.get("engine_sha256") == engine["console_sha256"],
            "Incomplete or mismatched profile save qualification")
    profile_cases = profile.get("cases", [])
    require(len(profile_cases) == len(WINDOWS_PROFILE_CASES)
            and {(c.get("kind"), c.get("fault"), c.get("evidence_class")) for c in profile_cases}
            == WINDOWS_PROFILE_CASES, "Incomplete or duplicate Windows profile fault matrix")
    for case in profile_cases:
        names = ("before", "replacement") if case["fault"] == "none" else ("before", "refusal", "retry")
        require(all(case.get(name, {}).get("exit_code") == 0
                    and case.get(name, {}).get("natural_completion") is True
                    and case.get(name, {}).get("engine_error_detected") is False
                    and case.get(name, {}).get("format_loadable") is True for name in names),
                "Profile matrix child did not finish cleanly")
        before = case["before"]
        replacement = case["replacement"] if case["fault"] == "none" else case["retry"]
        require(before.get("acknowledged") is True and before.get("loaded_value") == 7
                and replacement.get("acknowledged") is True and replacement.get("loaded_value") == 8
                and re.fullmatch(r"[0-9a-f]{64}", str(before.get("sha256", "")))
                and re.fullmatch(r"[0-9a-f]{64}", str(replacement.get("sha256", "")))
                and before["sha256"] != replacement["sha256"]
                and type(before.get("bytes")) is int and before["bytes"] > 0
                and type(replacement.get("bytes")) is int and replacement["bytes"] > 0,
                "Profile matrix does not demonstrate successful compatible replacement")
        if case["fault"] != "none":
            refusal = case["refusal"]
            require(refusal.get("acknowledged") is False and refusal.get("loaded_value") == 7
                    and refusal.get("sha256") == before["sha256"] and refusal.get("bytes") == before["bytes"],
                    "Profile refusal contradicts prior-file preservation")
    art = qualification.get("art_storage", {})
    require(art.get("schema") == 1 and art.get("status") == "passed" and art.get("passed") is True
            and art.get("completed") is True and art.get("platform") == "win32"
            and art.get("source_head") == head and art.get("engine_version") == engine["version"]
            and art.get("engine_sha256") == engine["console_sha256"],
            "Incomplete or mismatched Art storage qualification")
    art_cases = art.get("cases", [])
    require(len(art_cases) == len(WINDOWS_ART_CASES)
            and {(c.get("operation"), c.get("fault")) for c in art_cases} == WINDOWS_ART_CASES
            and all(c.get("passed") is True and c.get("exit_code") == 0
                    and c.get("natural_completion") is True and c.get("engine_error_detected") is False
                    for c in art_cases), "Incomplete or unsuccessful Windows Art storage matrix")


def verify(folder, expected_manifest_sha256):
    folder = folder.resolve(strict=True)
    require(re.fullmatch(r"[0-9a-f]{64}", expected_manifest_sha256)
            and sha(folder / "candidate-manifest.json") == expected_manifest_sha256,
            "Evaluator manifest differs from its independently retained digest")
    record = read_json(folder / "candidate-manifest.json")
    require(record.get("kind") == "ultima-test-only-workbench" and record.get("schema") == 1,
            "Unknown evaluator manifest")
    require(re.fullmatch(r"[0-9a-f]{40}", record.get("source_commit", "")), "Invalid source identity")
    require(re.fullmatch(r"[0-9a-f]{40}", record.get("source_tree", "")), "Invalid source tree")
    files = record.get("files_sha256", {})
    required = {"Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe", "vcruntime140.dll",
                "Godot-LICENSE.txt", "Godot-COPYRIGHT.txt", "Microsoft-Visual-C-Runtime-LICENSE.docx",
                "Microsoft-Visual-Studio-2022-LICENSE.docx", "vc-runtime-provenance.json",
                "LICENSE_STATUS.md", "THIRD_PARTY_NOTICES.md", "Open Workbench.cmd", "READ-ME.md",
                "qualification.json", "godot/project.godot", windows.NATIVE, windows.RAPIER}
    require(required.issubset(files), "Incomplete evaluator payload manifest")
    require(len({name.casefold() for name in files}) == len(files), "Duplicate Windows manifest paths")
    for relative, expected in files.items():
        parts = PurePosixPath(relative)
        require(not parts.is_absolute() and ".." not in parts.parts and "\\" not in relative
                and ":" not in relative and parts.as_posix() == relative
                and all(part and not part.endswith((".", " ")) for part in relative.split("/")),
                "Unsafe manifest path")
        path = folder / relative
        require(path.resolve().is_relative_to(folder) and path.is_file() and not path.is_symlink(),
                "Missing or redirected evaluator file: " + relative)
        require(re.fullmatch(r"[0-9a-f]{64}", expected) and sha(path) == expected,
                "Changed evaluator file: " + relative)
    require(sha(folder / "qualification.json") == record.get("qualification_sha256"),
            "Evaluator qualification digest mismatch")
    qualification = read_json(folder / "qualification.json")
    validate_qualification(qualification, record["source_commit"], record.get("source_tree"))
    return record


def build(args):
    qualification_path = args.qualification.resolve(strict=True)
    qualification = read_json(qualification_path)
    head, tree = (git("rev-parse", value).decode().strip() for value in ("HEAD", "HEAD^{tree}"))
    validate_qualification(qualification, head, tree)
    output, manifest_output = args.output.resolve(), args.manifest.resolve()
    require(not output.exists() and not output.is_relative_to(ROOT), "Evaluator output must be a new external directory")
    require(not manifest_output.exists() and not manifest_output.is_relative_to(output),
            "Retained manifest target must be new and outside the package")
    require(not git("diff", "--name-only", "HEAD", "--", ".", ":!godot/.godot"),
            "Tracked inputs changed after qualification")
    inputs_file = qualification_path.with_name("source-inputs.json")
    require(sha(inputs_file) == qualification["source_inputs_sha256"], "Qualification input map changed")
    inputs = read_json(inputs_file)
    tracked = {p for p in git("ls-files", "-z").decode().split("\0")
               if p and not p.startswith("godot/.godot/")}
    require(set(inputs) == tracked, "Qualification input map is incomplete")
    require(all(windows.content_digest(ROOT, p) == value for p, value in inputs.items()),
            "Working inputs differ from the executed Windows qualification")
    runtime = windows.verify_retained_runtime(ROOT)
    dependencies = args.dependencies.resolve(strict=True)
    for name, digest in DEPENDENCIES.items():
        require(sha(dependencies / name) == digest, "Pinned dependency changed: " + name)
    require(sha(dependencies / "Godot_v4.7-stable_win64.exe") == qualification["engine"]["runtime_sha256"]
            and sha(dependencies / "Godot_v4.7-stable_win64_console.exe") == qualification["engine"]["console_sha256"],
            "Package engine differs from the executed qualification")
    names = ["godot", "examples/worldgen", "third_party/godot-runtime.lock.json",
             "third_party/native-toolchain.lock.json", "third_party/rapier-bvh-build.lock.json",
             "third_party/patches/rapier-0.35.1-cooperative-bvh-join.patch",
             "THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md"]
    payload = git("archive", head, "--", *names, env=archive_environment())
    materialized = {runtime["cybersand_runtime"]["path"], runtime["rapier_runtime"]["path"]}
    output.mkdir(parents=True)
    omitted_platform = []
    with tarfile.open(fileobj=io.BytesIO(payload)) as archive:
        for entry in archive:
            if entry.name.startswith("godot/.godot/") or entry.isdir():
                continue
            require(entry.isfile(), "Refused non-file in source archive: " + entry.name)
            relative = PurePosixPath(entry.name)
            require(not relative.is_absolute() and ".." not in relative.parts, "Unsafe archived path")
            if "/bin/" in entry.name and entry.name not in materialized:
                omitted_platform.append(entry.name)
                continue
            data = archive.extractfile(entry).read()
            if data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
                match = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", data)
                require(match is not None, "Malformed LFS pointer: " + entry.name)
                data = (ROOT / entry.name).read_bytes()
                require(len(data) == int(match[2]) and hashlib.sha256(data).hexdigest() == match[1].decode(),
                        "Unmaterialized or changed package input: " + entry.name)
            target = output / entry.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    profiles = stage_generator_profiles(output)
    omitted_imports = omit_regenerated_imports(output)
    for name in DEPENDENCIES:
        shutil.copyfile(dependencies / name, output / name)
    vc_hash = stage_vc_runtime(dependencies, output)
    launcher = (
        '@echo off\nsetlocal\ncd /d "%~dp0"\n'
        'set "APPDATA=%~dp0userdata\\roaming"\nset "LOCALAPPDATA=%~dp0userdata\\local"\n'
        'set "XDG_DATA_HOME=%~dp0userdata\\roaming"\n'
        f'set "CYBERSAND_SOURCE_REVISION={head}"\n'
        '"%~dp0Godot_v4.7-stable_win64_console.exe" --headless --path "%~dp0godot" --editor --quit\n'
        'if errorlevel 1 (pause & exit /b 1)\n'
        '"%~dp0Godot_v4.7-stable_win64_console.exe" --path "%~dp0godot" %* -- --workbench\n'
        'set "ultima_exit=%errorlevel%"\nif not "%ultima_exit%"=="0" pause\nexit /b %ultima_exit%\n')
    (output / "Open Workbench.cmd").write_text(launcher, encoding="utf-8", newline="\r\n")
    guide = f"""# CyberSand ULTIMA — Draft/HOLD test-only evaluator

Extract the complete artifact into a writable folder and open **Open Workbench.cmd**.
Allow the first Godot import to finish. The ordinary Workbench uses the accepted
native/Rapier binaries and the candidate GDScript at `{head}` (tree `{tree}`).
This is an owner test artifact, not a production release or physical GPU acceptance.

The launcher isolates saves under this folder's `userdata` directory. Use only
disposable names. Do not copy your original saves into the evaluator. No installer,
credentials, provider calls or runtime publishing are part of this package.

1. Confirm the visible Workbench, paint a small floor, undo and redo.
2. Save a disposable named start, replace that same name, close and reopen it.
3. Preview and explicitly install a generator scene; save and reopen its embedded recipe.
4. Exercise Restore start and Flatten using the source-pinned saving manual.
5. Open Art / Direct JSON with a local operation; no paid provider is required.
6. Record Windows/GPU/driver, actual launch options, observations and any failure logs.

Manuals: https://github.com/techrote/cybersand/blob/{head}/docs/README.md
Mission and residual owner checks: https://github.com/techrote/cybersand/pull/783
Save replacement is qualified under tested failures; no power-loss durability claim.
`candidate-manifest.json` binds every original payload file. Generated editor caches
and test saves are outside that original manifest. Keep the repository Draft/HOLD.
"""
    (output / "READ-ME.md").write_text(guide, encoding="utf-8")
    shutil.copyfile(qualification_path, output / "qualification.json")
    record = {"schema":1, "kind":"ultima-test-only-workbench", "purpose":"Draft/HOLD owner evaluation; no release",
              "source_commit":head, "source_tree":tree, "native_runtime":runtime,
              "qualification_sha256":sha(qualification_path), "source_inputs_sha256":sha(inputs_file),
              "engine":qualification["engine"], "vc_runtime_sha256":vc_hash,
              "generator_profiles_sha256":profiles, "regenerated_imports_sha256":omitted_imports,
              "omitted_other_platform_binaries":omitted_platform,
              "files_sha256":{p.relative_to(output).as_posix():sha(p) for p in sorted(output.rglob("*")) if p.is_file()}}
    write(output / "candidate-manifest.json", record)
    verify(output, sha(output / "candidate-manifest.json"))
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(output / "candidate-manifest.json", args.manifest)
    print(json.dumps({"source":head, "files":len(record["files_sha256"]), "manifest_sha256":sha(args.manifest)}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    make = sub.add_parser("build")
    make.add_argument("--dependencies", type=Path, required=True)
    make.add_argument("--qualification", type=Path, required=True)
    make.add_argument("--output", type=Path, required=True)
    make.add_argument("--manifest", type=Path, required=True)
    check = sub.add_parser("verify")
    check.add_argument("package", type=Path)
    check.add_argument("--expected-manifest-sha256", required=True)
    args = parser.parse_args()
    if args.command == "build":
        build(args)
    else:
        print(json.dumps({"verified_source":verify(args.package, args.expected_manifest_sha256)["source_commit"]}))


if __name__ == "__main__":
    main()
