#!/usr/bin/env python3
"""Package and exercise a Windows Materials Lab with offline authoring tools.

This is a source-project evaluation build, not an export-template release.
A fresh repository retains compatibility ancestry without checkout credentials.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent / "ci"))
import materials_lab_runtime_publication as publication

engine = publication.engine
ROOT = Path(__file__).resolve().parents[1]
MANIFEST = "materials-lab-evaluation.json"
CONTACT_CASE = "test_material_lab_diagnostics"
CONTACT_DIRECTORY = "graphical-contact"
CONTACT_MANIFEST = "contact-capture-manifest.json"
CONTACT_READBACK = "contact-readback.json"
CONTACT_IMAGE = "09-native-contact-inspector.png"
CONTACT_SOURCES = {
    "materials_lab.tscn", "scripts/material_lab_panel.gd", "scripts/material_lab_experiment.gd",
    "tests/test_material_lab_diagnostics.gd", "native_extension/material_lab_inspection.inc",
    "native_extension/cyber_demo_bridge.hpp",
}
GIT_LOCATION = {"GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR",
                "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_NAMESPACE",
                "GIT_CONFIG", "GIT_CONFIG_COUNT", "GIT_CONFIG_PARAMETERS", "GIT_EXEC_PATH", "GIT_TEMPLATE_DIR"}


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def canonical(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode("utf-8")


def clean_git_environment() -> dict[str, str]:
    result = {key: value for key, value in os.environ.items() if key not in GIT_LOCATION and
              not key.startswith(("GIT_CONFIG_KEY_", "GIT_CONFIG_VALUE_"))}
    result.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull, GIT_LFS_SKIP_SMUDGE="1")
    return result


def git(root: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), *args], env=clean_git_environment(), timeout=300)


def clean_source_repository(root: Path, source: str, destination: Path) -> dict:
    engine.require(not destination.exists(), "Refuse to overwrite a source repository")
    engine.require(git(root, "rev-parse", "HEAD").decode().strip() == source, "Packaging checkout differs from source")
    engine.require(git(root, "rev-parse", "--is-shallow-repository").strip() == b"false", "Complete compatibility history is required")
    with tempfile.TemporaryDirectory(prefix="cybersand-source-history-") as temporary:
        bundle = Path(temporary) / "source.bundle"
        git(root, "bundle", "create", str(bundle), "HEAD")
        identity = {"bundle_sha256": sha(bundle), "bundle_bytes": bundle.stat().st_size,
                    "source_commit": source, "scope": "self-contained HEAD ancestry; no original checkout configuration"}
        subprocess.run(["git", "clone", "--no-checkout", "--template=", "--config", "core.autocrlf=false",
                        str(bundle), str(destination)], env=clean_git_environment(), check=True, timeout=300,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        git(destination, "remote", "remove", "origin")
        git(destination, "config", "--local", "core.autocrlf", "false")
        git(destination, "config", "--local", "core.longpaths", "true")
        shutil.rmtree(destination / ".git/hooks", ignore_errors=True)
        git(destination, "checkout", "--detach", source)
    engine.require(not git(destination, "remote").strip(), "Delivered source must not retain a remote URL")
    engine.require(git(destination, "rev-parse", "HEAD").decode().strip() == source, "Delivered source checkout mismatch")
    engine.require(git(destination, "rev-parse", "--is-shallow-repository").strip() == b"false", "Delivered source history is incomplete")
    return identity


def copy_portable_tree(source: Path, destination: Path, *, ignore=None) -> None:
    engine.require(source.is_dir() and not source.is_symlink(), "Missing real dependency directory: " + str(source))
    for path in source.rglob("*"):
        engine.require(not path.is_symlink(), "Portable dependency contains a symlink: " + str(path))
    shutil.copytree(source, destination, ignore=ignore)


def copy_python(source: Path, destination: Path) -> None:
    engine.require((source / "python.exe").is_file() and (source / "Lib/json").is_dir() and
                   (source / "LICENSE.txt").is_file(), "A complete licensed Windows Python installation is required")
    destination.mkdir(parents=True)
    for path in source.iterdir():
        if path.is_file() and (path.suffix.lower() in {".exe", ".dll"} or path.name == "LICENSE.txt"):
            engine.require(not path.is_symlink(), "Python executable must be a real file")
            shutil.copyfile(path, destination / path.name)
    for name in ("Lib", "DLLs"):
        copy_portable_tree(source / name, destination / name,
                           ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "site-packages", "test", "tests"))


def copy_git(source: Path, destination: Path) -> None:
    engine.require((source / "cmd/git.exe").is_file() and (source / "mingw64/bin/git.exe").is_file() and
                   (source / "LICENSE.txt").is_file(), "A complete licensed Git for Windows installation is required")
    destination.mkdir(parents=True)
    # Built-in Git queries and their distribution helpers/dependencies/notices.
    # Copy no installed etc/ configuration or machine/user shell configuration.
    for name in ("cmd", "mingw64/bin", "mingw64/libexec", "mingw64/share"):
        (destination / name).parent.mkdir(parents=True, exist_ok=True)
        copy_portable_tree(source / name, destination / name)
    shutil.copyfile(source / "LICENSE.txt", destination / "LICENSE.txt")
    if (source / "ReleaseNotes.html").is_file():
        shutil.copyfile(source / "ReleaseNotes.html", destination / "ReleaseNotes.html")


def dependency_environment(package: Path) -> dict[str, str]:
    result = clean_git_environment()
    for key in ("PYTHONHOME", "PYTHONPATH", "PYTHONSTARTUP", "GIT_EXEC_PATH", "GIT_TEMPLATE_DIR"):
        result.pop(key, None)
    system = Path(os.environ.get("SystemRoot", r"C:\Windows"))
    result["PATH"] = os.pathsep.join(str(path) for path in (
        package / "dependencies/python", package / "dependencies/git/cmd",
        package / "dependencies/git/mingw64/bin", package / "dependencies/cxx/bin", system / "System32", system))
    result.update(CYBERSAND_LAB_CXX=str(package / "dependencies/cxx/bin/g++.exe"),
                  PYTHONUTF8="1", PYTHONNOUSERSITE="1")
    return result


def file_map(directory: Path) -> dict[str, str]:
    return {path.relative_to(directory).as_posix(): sha(path) for path in sorted(directory.rglob("*"))
            if path.is_file() and path != directory / MANIFEST}


def verify_package(package: Path) -> dict:
    manifest = publication.read_json(package / MANIFEST)
    engine.require(manifest.get("schema") == "cybersand-materials-lab-evaluation-v1" and
                   manifest.get("platform") == "windows" and manifest.get("runtime_active_candidates") is False,
                   "Unsupported evaluation bundle")
    for path in package.rglob("*"):
        engine.require(not path.is_symlink(), "Evaluation bundle contains a symlink")
    engine.require(manifest.get("files_sha256") == file_map(package), "Evaluation bundle file inventory changed")
    runtime = package / "source" / engine.RUNTIMES["windows"]
    engine.require(sha(runtime) == manifest.get("native_sha256"), "Evaluation runtime differs from its qualification")
    recorded = publication.read_json(package / "source" / engine.MANIFESTS["windows"])
    engine.require(recorded.get("sha256") == manifest["native_sha256"] and
                   recorded.get("source_commit") == manifest.get("source_commit") and
                   recorded.get("status") == "validated-development-runtime", "Evaluation runtime provenance mismatch")
    return manifest


def build(args: argparse.Namespace) -> Path:
    publication.require_platform("windows")
    manifest = publication.verify_materials_bundle(args.bundle, "windows", args.source_sha)
    godot, godot_identity = engine.windows.prepare_godot(args.godot_archive)
    output = args.output.resolve()
    engine.require(not output.exists(), "Evaluation destination already exists; choose a new directory")
    engine.require(not output.is_relative_to(ROOT), "Evaluation bundle must be outside the source checkout")
    for name in ("LICENSE.txt", "COPYRIGHT.txt"):
        engine.require((args.engine_notices / name).is_file(), "Official Godot notices are required: " + name)
    compiler = args.compiler_root / "bin/g++.exe"
    suite = publication.read_json(args.bundle / "catalogue-suite.json")
    engine.require(compiler.is_file() and sha(compiler) == suite["candidate_compiler"]["sha256"],
                   "Packaged compiler differs from the actually tested candidate compiler")
    engine.require(sha(args.python_root / "python.exe") == suite["python"]["sha256"],
                   "Packaged Python differs from the actually tested interpreter")
    engine.require(any(path.is_file() and any(part.lower().startswith(("copying", "license")) for part in path.parts)
                       for path in args.compiler_root.rglob("*")), "Compiler dependency notices are required")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".materials-lab-package-", dir=output.parent) as temporary:
        staging = Path(temporary) / "evaluation"
        staging.mkdir()
        history = clean_source_repository(ROOT, args.source_sha, staging / "source")
        for relative in (engine.RUNTIMES["windows"], engine.MANIFESTS["windows"]):
            shutil.copyfile(args.bundle / Path(relative).name, staging / "source" / relative)
        rapier, rapier_sha = engine.RAPIER["windows"]
        engine.require(sha(ROOT / rapier) == rapier_sha, "Pinned Windows Rapier must be materialized")
        shutil.copyfile(ROOT / rapier, staging / "source" / rapier)
        for path in (godot, godot.with_name("Godot_v4.7-stable_win64.exe")):
            shutil.copyfile(path, staging / path.name)
        for name in ("LICENSE.txt", "COPYRIGHT.txt"):
            shutil.copyfile(args.engine_notices / name, staging / ("Godot-" + name))
        dependencies = staging / "dependencies"
        dependencies.mkdir()
        copy_python(args.python_root, dependencies / "python")
        copy_git(args.git_root, dependencies / "git")
        copy_portable_tree(args.compiler_root, dependencies / "cxx")
        shutil.copytree(args.bundle, staging / "qualification")
        launcher = (
            '@echo off\r\nsetlocal\r\ncd /d "%~dp0"\r\n'
            'set "PYTHONHOME="\r\nset "PYTHONPATH="\r\nset "PYTHONNOUSERSITE=1"\r\nset "PYTHONUTF8=1"\r\n'
            + ''.join('set "' + key + '=\"\r\n' for key in sorted(GIT_LOCATION)) +
            'set "GIT_CONFIG_NOSYSTEM=1"\r\nset "GIT_CONFIG_GLOBAL=NUL"\r\n'
            'set "PATH=%~dp0dependencies\\python;%~dp0dependencies\\git\\cmd;%~dp0dependencies\\git\\mingw64\\bin;%~dp0dependencies\\cxx\\bin;%SystemRoot%\\System32;%SystemRoot%"\r\n'
            'set "CYBERSAND_LAB_CXX=%~dp0dependencies\\cxx\\bin\\g++.exe"\r\n'
            f'set "CYBERSAND_SOURCE_REVISION={args.source_sha}"\r\n'
            '"%~dp0Godot_v4.7-stable_win64_console.exe" --headless --path "%~dp0source\\godot" --editor --quit\r\n'
            'if errorlevel 1 (pause & exit /b 1)\r\n'
            '"%~dp0Godot_v4.7-stable_win64.exe" --rendering-method gl_compatibility --rendering-driver opengl3_angle --path "%~dp0source\\godot" res://materials_lab.tscn\r\n')
        (staging / "Open-Materials-Lab.cmd").write_bytes(launcher.encode("utf-8"))
        (staging / "README.txt").write_text(
            "CyberSand Materials Lab evaluation build\n\n"
            "Extract the whole ZIP into a writable folder, then double-click Open-Materials-Lab.cmd.\n"
            "Included Godot, Python, Git history and C++ support authoring without installing tools.\n"
            "The first launch imports the project. Keep dependencies and source folders together.\n"
            "Candidates run in isolated tests; authored physics is not installed into saved worlds.\n"
            "Controls and examples: source/docs/operations/materials-lab-authoring.md\n"
            "Actual target-OS automated evidence and captures: qualification/\n"
            "This is a project evaluation bundle, not a template-exported production release.\n"
            f"Source: {args.source_sha}\nNative DLL SHA-256: {manifest['sha256']}\n"
            "Licenses/notices: Godot-*.txt, source/THIRD_PARTY_NOTICES.md and dependencies/.\n",
            encoding="utf-8")
        identity = {"schema": "cybersand-materials-lab-evaluation-v1", "platform": "windows",
                    "source_commit": args.source_sha, "source_tree": manifest["source_tree"],
                    "native_sha256": manifest["sha256"], "godot": godot_identity, "source_history": history,
                    "candidate_compiler": suite["candidate_compiler"], "python": suite["python"],
                    "runtime_active_candidates": False, "scope": "source-built evaluation; human acceptance not claimed",
                    "files_sha256": file_map(staging)}
        (staging / MANIFEST).write_bytes(canonical(identity))
        verify_package(staging)
        staging.rename(output)
    return output


@contextmanager
def runner_root(root: Path):
    previous = engine.runner.ROOT
    engine.runner.ROOT = root
    try:
        yield
    finally:
        engine.runner.ROOT = previous


def smoke_cases(evidence: Path) -> list:
    cases = [engine.runner.Case("import", ("--editor", "--quit"), 1200, 1.0)] + [
        engine.runner.Case(name, ("--script", "res://tests/" + name + ".gd"), 1200, 1.0)
        for name in ("test_material_lab_ui", "test_material_lab_world")]
    cases.append(engine.runner.Case(CONTACT_CASE, (
        "--rendering-driver", "opengl3_angle", "--script", "res://tests/" + CONTACT_CASE + ".gd",
        "--", "--capture-output=" + str((evidence / CONTACT_DIRECTORY).resolve())), 1200, 1.0, True))
    return cases


def smoke_evidence_files(evidence: Path) -> dict[str, str]:
    return {path.relative_to(evidence).as_posix(): sha(path) for path in sorted(evidence.rglob("*"))
            if path.is_file() and path != evidence / "package-execution.json"}


def verify_contact_capture(package: Path, evidence: Path, result: dict, identity: dict) -> dict:
    """Admit original graphical/owner evidence from the disposable Windows copy.

    The unit tests exercise this receipt boundary. Only smoke() executes the
    real native/Godot case and can establish packaged graphical acceptance.
    """
    with runner_root(package / "source"):
        expected_command = engine.runner.case_command(
            str(package / "Godot_v4.7-stable_win64_console.exe"), smoke_cases(evidence)[-1], "win32")
    engine.require(result.get("name") == CONTACT_CASE and result.get("status") == "passed" and
                   result.get("returncode") == 0 and result.get("natural_completion") is True and
                   result.get("requires_display") is True and result.get("skip_messages") == [] and
                   not result.get("diagnostic_error") and result.get("launch_error") is None and
                   result.get("capture_error") is None and result.get("command") == expected_command,
                   "Packaged contact case did not naturally complete with its bundled Windows ANGLE command")
    log = evidence / (CONTACT_CASE + ".log")
    engine.require(log.is_file() and result.get("log_sha256") == sha(log), "Packaged contact process log changed")
    markers = re.findall(r"(?m)^MATERIAL_LAB_DIAGNOSTICS: ([1-9][0-9]*) assertions; 0 failures\s*$",
                         log.read_text(encoding="utf-8"))
    engine.require(len(markers) == 1, "Packaged contact output omitted its unique passing assertion marker")
    directory = evidence / CONTACT_DIRECTORY
    for name in (CONTACT_MANIFEST, CONTACT_READBACK, CONTACT_IMAGE):
        path = directory / name
        engine.require(path.is_file() and not path.is_symlink(), "Missing original packaged contact capture: " + name)
    manifest = publication.read_json(directory / CONTACT_MANIFEST)
    engine.require(manifest.get("schema_id") == "cybersand.material-lab.contact-capture" and
                   manifest.get("schema_version") == 1 and manifest.get("platform") == "Windows" and
                   manifest.get("display") == "Windows" and manifest.get("rendering_method") == "gl_compatibility" and
                   isinstance(manifest.get("renderer"), str) and bool(manifest["renderer"].strip()) and
                   manifest.get("failures") == 0 and manifest.get("assertions") == int(markers[0]),
                   "Packaged contact capture does not establish passing Windows graphical execution")
    engine_info = manifest.get("engine", {})
    engine.require(isinstance(engine_info, dict) and engine_info.get("major") == 4 and engine_info.get("minor") == 7 and
                   engine_info.get("patch") == 0 and engine_info.get("status") == "stable" and
                   engine_info.get("build") == "official" and isinstance(engine_info.get("hash"), str) and
                   engine_info["hash"].startswith(engine.GODOT_VERSION.rsplit(".", 1)[-1]),
                   "Packaged contact capture used a different Godot engine")
    image = directory / CONTACT_IMAGE
    with image.open("rb") as stream:
        header = stream.read(24)
    dimensions = [int.from_bytes(header[16:20], "big"), int.from_bytes(header[20:24], "big")]
    engine.require(len(header) == 24 and header[:8] == b"\x89PNG\r\n\x1a\n" and header[12:16] == b"IHDR" and
                   all(value > 0 for value in dimensions) and manifest.get("viewport") == dimensions and
                   manifest.get("image_sha256") == sha(image), "Packaged contact image or viewport changed")
    readback_path = directory / CONTACT_READBACK
    engine.require(manifest.get("readback_sha256") == sha(readback_path), "Packaged contact readback changed")
    sources = manifest.get("source_sha256", {})
    engine.require(isinstance(sources, dict) and set(sources) == CONTACT_SOURCES,
                   "Packaged contact capture omitted its UI/native source inputs")
    original_files = identity.get("files_sha256", {})

    def source_matches(relative: str, digest: str) -> bool:
        if (not isinstance(relative, str) or "\\" in relative or Path(relative).is_absolute() or
                ".." in Path(relative).parts or Path(relative).as_posix() != relative):
            return False
        name = "source/godot/" + relative
        path = package / name
        return path.is_file() and original_files.get(name) == digest == sha(path)

    engine.require(all(source_matches(path, digest) for path, digest in sources.items()),
                   "Packaged contact source differs from the original delivered files")
    for name in ("Godot_v4.7-stable_win64_console.exe", "Godot_v4.7-stable_win64.exe"):
        engine.require((package / name).is_file() and original_files.get(name) == sha(package / name),
                       "Packaged contact Godot executable differs from the original: " + name)
    runtime = package / "source" / engine.RUNTIMES["windows"]
    runtime_path = "res://" + Path(engine.RUNTIMES["windows"]).relative_to("godot").as_posix()
    engine.require(runtime.is_file() and manifest.get("native_library_path") == runtime_path and
                   manifest.get("native_library_sha256") == identity.get("native_sha256") == sha(runtime) and
                   original_files.get("source/" + engine.RUNTIMES["windows"]) == sha(runtime),
                   "Packaged contact runtime differs from its qualified original")
    readback = publication.read_json(readback_path)
    contact, owner = readback.get("contact", {}), readback.get("owner", {})
    engine.require(isinstance(contact, dict) and isinstance(owner, dict) and
                   contact.get("schema_id") == "cybersand.material-lab.contact" and contact.get("schema_version") == 1 and
                   contact.get("ok") is True and contact.get("reaction_executed") is False and
                   contact.get("world_eligibility") == "unresolved" and contact.get("blockers") == [] and
                   owner.get("ok") is True and owner.get("failed") is False and owner.get("platform") == "Windows" and
                   owner.get("backend") == "native-phased" and owner.get("schema_version") == 2 and
                   owner.get("material_lab_schema_version") == 1,
                   "Packaged contact does not retain a successful isolated native owner inspection")
    observed, native, runtime_identity = owner.get("readback", {}), owner.get("native", {}), owner.get("runtime_identity", {})
    engine.require(all(isinstance(value, dict) for value in (observed, native, runtime_identity)) and
                   observed.get("ok") is True and observed.get("backend") == "native World / existing MicroScenario host" and
                   native == observed.get("native") and native.get("tick") == owner.get("completed_tick") ==
                   observed.get("completed_tick") == contact.get("completed_tick") == 0 and
                   owner.get("worker_count") == observed.get("workers") == 1 and
                   isinstance(contact.get("definition_hash"), str) and
                   re.fullmatch(r"[0-9a-f]{64}", contact["definition_hash"]) is not None and
                   contact["definition_hash"] == owner.get("definition_hash") == observed.get("definition_hash"),
                   "Packaged contact and native owner disagree about their definition or completed tick")
    owner_sources = runtime_identity.get("script_sha256", {})
    engine.require(runtime_identity.get("platform") == "Windows" and runtime_identity.get("native_path") == runtime_path and
                   runtime_identity.get("native_sha256") == identity["native_sha256"] and
                   runtime_identity.get("material_lab_experiment_sha256") == sources["scripts/material_lab_experiment.gd"] and
                   isinstance(owner_sources, dict) and
                   {"scripts/microscenario_identity.gd", "scripts/microscenario_host.gd", "scripts/cell_world.gd"}.issubset(owner_sources) and
                   all(source_matches(path, digest) for path, digest in owner_sources.items()),
                   "Packaged native owner source/runtime identity differs from the delivered files")
    for endpoint, material, x, state_a in (("source", 23, 220, 0), ("target", 3, 221, 173)):
        cell = contact.get(endpoint, {})
        engine.require(isinstance(cell, dict) and cell.get("schema_id") == "cybersand.material-lab.cell" and
                       cell.get("schema_version") == 1 and cell.get("ok") is True and cell.get("read_only") is True and
                       cell.get("material") == cell.get("visible_material") == material and
                       cell.get("x") == x and cell.get("y") == 130 and cell.get("state_a") == state_a and
                       cell.get("state_b") == 0 and cell.get("completed_tick") == 0 and
                       cell.get("transient_body_id") == 0 and cell.get("stored_temperature_available") is True and
                       cell.get("stored_temperature_raw") == 200,
                       "Packaged contact lacks its actual stored " + endpoint + " cell values")
    resolver = contact.get("resolver", {})
    engine.require(isinstance(resolver, dict) and resolver.get("ok") is True and resolver.get("matched") is True and
                   resolver.get("selected") is True and resolver.get("outcome") == "selected_reaction" and
                   resolver.get("source") == 23 and resolver.get("target") == 3 and
                   resolver.get("source_product") == resolver.get("target_product") == 24 and
                   resolver.get("probability_roll") == contact.get("supplied_roll") == 0 and
                   resolver.get("probability_threshold") == 255 and
                   resolver.get("probability_numerator") == resolver.get("probability_denominator") == 256,
                   "Packaged contact lacks its native supplied-roll Salt/Water resolver result")
    return {"status": "passed", "platform": "Windows", "display": manifest["display"],
            "renderer": manifest["renderer"], "rendering_method": manifest["rendering_method"],
            "assertions": manifest["assertions"], "native_sha256": identity["native_sha256"],
            "definition_hash": contact["definition_hash"], "completed_tick": contact["completed_tick"],
            "manifest_sha256": sha(directory / CONTACT_MANIFEST),
            "scope": "Actual bundled Windows ANGLE contact inspector and native owner readback; supplied resolver roll is not an executed reaction."}


def smoke(package: Path, evidence: Path) -> dict:
    publication.require_platform("windows")
    identity = verify_package(package)
    engine.require(not evidence.exists() and not evidence.resolve().is_relative_to(package.resolve()),
                   "Smoke evidence must be a fresh directory outside the deliverable")
    evidence.mkdir(parents=True)
    report = {"schema": "materials-lab-package-execution-v1", "source_commit": identity["source_commit"],
              "package_manifest_sha256": sha(package / MANIFEST), "platform": "windows", "completed": False,
              "status": "running", "results": [],
              "scope": "disposable copy using only bundled authoring prerequisites; graphical ANGLE contact inspector and native owner readback"}
    report_path = evidence / "package-execution.json"
    report_path.write_bytes(canonical(report))
    # Spaces deliberately exercise executable/source quoting on actual Windows.
    with tempfile.TemporaryDirectory(prefix="CyberSand Materials Lab ") as temporary:
        candidate = Path(temporary) / "evaluation"
        shutil.copytree(package, candidate)
        environment = dependency_environment(candidate)
        python = candidate / "dependencies/python/python.exe"
        source = candidate / "source"
        compatibility = subprocess.run([str(python), str(source / "tools/material_catalogue/compatibility.py"), "--check"],
                                       cwd=source, env=environment, text=True, capture_output=True, timeout=300)
        (evidence / "compatibility.log").write_bytes((compatibility.stdout + compatibility.stderr).encode("utf-8"))
        engine.require(compatibility.returncode == 0, "Bundled Git/Python could not authenticate compatibility ancestry")
        godot = candidate / "Godot_v4.7-stable_win64_console.exe"
        cases = smoke_cases(evidence)
        with runner_root(source):
            for case in cases:
                result, failed = engine.runner.run_case(str(godot), case, evidence, "packaged", env=environment)
                report["results"].append(result)
                if case.name in engine.CASE_MARKERS:
                    output = (evidence / (case.name + ".log")).read_text(encoding="utf-8")
                    failed = failed or len(re.findall(engine.CASE_MARKERS[case.name], output)) != 1
                if case.name == CONTACT_CASE and not failed:
                    try:
                        report["graphical_contact"] = verify_contact_capture(candidate, evidence, result, identity)
                    except (OSError, ValueError, TypeError, KeyError, RuntimeError) as error:
                        report["graphical_contact"] = {"status": "failed", "error": str(error)}
                        failed = True
                if failed: report["status"] = "failed"
                report["files_sha256"] = smoke_evidence_files(evidence)
                report_path.write_bytes(canonical(report))
                if failed and case.name == "import": break
        engine.require(report["status"] != "failed" and len(report["results"]) == len(cases),
                       "Delivered package failed actual Windows authoring or graphical inspection; original evidence is retained")
    verify_package(package)
    report.update(status="passed", completed=True,
                  files_sha256=smoke_evidence_files(evidence))
    report_path.write_bytes(canonical(report))
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build", "verify", "smoke"])
    parser.add_argument("--source-sha")
    parser.add_argument("--bundle", type=Path)
    parser.add_argument("--godot-archive", type=Path)
    parser.add_argument("--engine-notices", type=Path)
    parser.add_argument("--python-root", type=Path, default=Path(sys.base_prefix))
    parser.add_argument("--git-root", type=Path, default=Path(r"C:\Program Files\Git"))
    parser.add_argument("--compiler-root", type=Path, default=Path(r"C:\mingw64"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--evidence", type=Path)
    args = parser.parse_args()
    if args.command == "build":
        if any(getattr(args, key) is None for key in ("source_sha", "bundle", "godot_archive", "engine_notices")):
            parser.error("Source, qualified runtime bundle, official Godot archive and notices are required")
        print(build(args))
    elif args.command == "verify":
        identity = verify_package(args.output)
        print(json.dumps({"status": "passed", "source_commit": identity["source_commit"],
                          "native_sha256": identity["native_sha256"], "files": len(identity["files_sha256"])}, sort_keys=True))
    else:
        if args.evidence is None: parser.error("Smoke execution needs an external evidence directory")
        print(json.dumps(smoke(args.output, args.evidence), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
