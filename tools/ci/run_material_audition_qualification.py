#!/usr/bin/env python3
"""Bind and exercise an exact-source material-audition runtime candidate.

This is an evaluator custody record, not retained-runtime publication.  A build
receipt never implies execution; each process retains its original log, exit
status, source identity, runtime digest and explicit completion marker.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = "material-audition-candidate.json"
VERSION = "4.7.stable.official.5b4e0cb0f"
RUNTIMES = {
    "linux": "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
    "windows": "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
}
# Scene loaders, extension declarations, shaders and every tracked execution
# resource matter just as much as scripts. Bind the custody/package helpers too.
# Runtime libraries are separately verified as executed artifacts/dependencies;
# their platform-specific LFS materialization must not alter source identity.
SOURCE_DIRS = ("native/include", "native/src", "godot", "tools", "examples/worldgen")
SOURCE_EXCLUDES = (":(exclude,glob)godot/addons/**/bin/**",
                   ":(exclude)godot/addons/cybersand_native/runtime-provenance.json",
                   ":(exclude)godot/addons/cybersand_native/retained-runtime-provenance.reference.json")
TEXT_SUFFIXES = {".gd", ".gdshader", ".gdshaderinc", ".godot", ".tscn", ".tres", ".gdextension", ".cfg",
                 ".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp",
                 ".py", ".json", ".yml", ".yaml", ".sh", ".ps1", ".bat", ".cmd", ".md", ".txt", ".svg",
                 ".import", ".mjs", ".patch"}
TEXT_FILENAMES = {".gdignore", "LICENSE", "g++"}
NATIVE_SUFFIXES = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:")
CASES = (
    ("test_material_audition", "MATERIAL_AUDITION_RESULT"),
    ("test_material_audition_authored_scenes", "MAT_AUDITION_AUTHORED_RESULT"),
    ("test_material_audition_profile", "MAT_AUDITION_PROFILE:"),
    ("test_material_audition_ui_contract", "MAT_AUDITION_UI_CONTRACT:"),
    ("test_material_audition_layout", "MAT_AUDITION_LAYOUT:"),
    ("test_material_lab_ui", "MATERIAL_LAB_WORKBENCH_MOUNT:"),
    ("test_material_lab_catalogue", "MATERIAL_LAB_CATALOGUE:"),
    ("test_material_lab_experiment", "MATERIAL_LAB_EXPERIMENT:"),
    ("test_material_lab_diagnostics", "MATERIAL_LAB_DIAGNOSTICS:"),
)


def canonical(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode()


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical(value))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def git(root: Path, *args: str) -> bytes:
    # A read-only custody check must not refresh a relocated .git/index. It
    # also must not inherit a caller's alternate repository/index authority.
    environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    environment.update(GIT_OPTIONAL_LOCKS="0", GIT_CONFIG_NOSYSTEM="1",
                       GIT_CONFIG_GLOBAL=os.devnull, GIT_LFS_SKIP_SMUDGE="1")
    return subprocess.check_output(["git", "-c", "diff.autoRefreshIndex=false", "-C", str(root), *args],
                                   timeout=120, env=environment)


def source_identity(root: Path) -> dict:
    """Require clean tracked implementation and retain its exact input bytes."""
    commit = git(root,"rev-parse","HEAD").decode().strip()
    tree = git(root,"rev-parse","HEAD^{tree}").decode().strip()
    paths_to_check = (*SOURCE_DIRS, "materials", *SOURCE_EXCLUDES)
    git(root, "diff", "--exit-code", "HEAD", "--", *paths_to_check)
    names = git(root, "ls-files", "-z", "--", *paths_to_check).decode().split("\0")
    paths = [name for name in names if name and not name.endswith(".uid")]
    inputs = {}
    for name in sorted(paths):
        content = (root / name).read_bytes()
        if Path(name).suffix in TEXT_SUFFIXES or Path(name).name in TEXT_FILENAMES:
            content = content.replace(b"\r\n", b"\n")
        inputs[name] = hashlib.sha256(content).hexdigest()
    native_inputs = {name: digest for name, digest in inputs.items()
                     if name.startswith(("native/include/", "native/src/", "godot/native_extension/"))
                     and Path(name).suffix in NATIVE_SUFFIXES}
    require(bool(native_inputs),"Missing native candidate inputs")
    # Godot's first editor import creates resource UID sidecars. Admit only the
    # known generated suffixes with a tracked real companion; an orphan sidecar,
    # arbitrary .uid file, untracked script or native input still refuses.
    tracked = set(names)
    def generated_uid(name: str) -> bool:
        return name.endswith((".gd.uid", ".gdshader.uid", ".gdextension.uid")) and name[:-4] in tracked
    untracked = [name for name in git(root, "ls-files", "--others", "--exclude-standard",
                                    "--", *paths_to_check).decode().splitlines()
                 if not generated_uid(name)]
    require(not untracked, "Untracked implementation cannot receive an exact-source receipt: " + ", ".join(untracked))
    return {"source_commit": commit, "source_tree": tree, "native_inputs": native_inputs,
            "execution_inputs": inputs}


def binary_kind(path: Path, target: str) -> bool:
    with path.open("rb") as stream:
        header = stream.read(4)
    return header == b"\x7fELF" if target == "linux" else header[:2] == b"MZ"


def record(root: Path, target: str, runtime: Path, output: Path, toolchain: Path | None = None) -> dict:
    require(target in RUNTIMES, "Unsupported candidate target")
    require(not output.exists(), "A build receipt is immutable; choose a new candidate directory")
    require(binary_kind(runtime, target), "Candidate binary does not match its declared platform")
    identity = source_identity(root)
    output.mkdir(parents=True)
    destination = output / Path(RUNTIMES[target]).name
    shutil.copyfile(runtime, destination)
    manifest = {"schema": "cybersand.material-audition.candidate", "schema_version": 1,
                "platform": target, "artifact": RUNTIMES[target], **identity,
                "native_sha256": sha(destination), "native_bytes": destination.stat().st_size,
                "status": "built-not-executed", "run_id": os.environ.get("GITHUB_RUN_ID", "local"),
                "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT", "local"),
                "toolchain_drift": os.environ.get("CYBERSAND_ALLOW_TOOLCHAIN_DRIFT") == "1"}
    if toolchain is not None:
        shutil.copyfile(toolchain, output / "toolchain.txt")
        manifest["toolchain_sha256"] = sha(output / "toolchain.txt")
    write(output / MANIFEST, manifest)
    return verify(root, output, target)


def verify(root: Path, candidate: Path, target: str | None = None) -> dict:
    manifest = json.loads((candidate / MANIFEST).read_text(encoding="utf-8"))
    require(manifest.get("schema") == "cybersand.material-audition.candidate" and
            manifest.get("schema_version") == 1, "Unsupported material-audition candidate schema")
    selected = manifest.get("platform")
    require(selected in RUNTIMES and (target is None or target == selected), "Candidate platform mismatch")
    require(manifest.get("artifact") == RUNTIMES[selected], "Unexpected candidate artifact path")
    identity = source_identity(root)
    require(all(manifest.get(key) == value for key, value in identity.items()), "Candidate source inputs changed")
    runtime = candidate / Path(RUNTIMES[selected]).name
    require(binary_kind(runtime, selected) and sha(runtime) == manifest.get("native_sha256") and
            runtime.stat().st_size == manifest.get("native_bytes"), "Candidate runtime bytes changed")
    if "toolchain_sha256" in manifest:
        require(sha(candidate / "toolchain.txt") == manifest["toolchain_sha256"], "Candidate toolchain receipt changed")
    return manifest


def completion(output: str, marker: str) -> dict:
    lines = [line[len(marker):].strip() for line in output.splitlines() if line.startswith(marker + " ")]
    require(len(lines) == 1, "Expected one complete result marker: " + marker)
    if lines[0].startswith("{"):
        value = json.loads(lines[0])
    else:
        matched = re.match(r"(\d+) (?:checks|assertions)[;,] (\d+) failures", lines[0])
        require(matched is not None, "Malformed result marker: " + marker)
        value = {"checks": int(matched[1]), "failures": int(matched[2])}
    failure_count = value.get("failures") if isinstance(value, dict) else None
    require(isinstance(value, dict) and type(value.get("checks")) is int and value["checks"] > 0 and
            ((type(failure_count) is int and failure_count == 0) or failure_count == []) and
            value.get("status", "passed") == "passed",
            "Failing or incomplete result marker: " + marker)
    return value


def stop_process(process: subprocess.Popen) -> None:
    if process.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    process.wait(timeout=30)


def run_process(command: list[str], log: Path, environment: dict[str, str], timeout: int,
                marker: str | None = None) -> dict:
    begin = time.monotonic()
    receipt = {"command": command, "timeout_seconds": timeout, "status": "running"}
    process = None
    try:
        with log.open("w", encoding="utf-8") as output:
            process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT,
                                       env=environment, cwd=log.parent, start_new_session=os.name != "nt")
            receipt["process_id"] = process.pid
            receipt["exit_code"] = process.wait(timeout=timeout)
        original = log.read_text(encoding="utf-8", errors="replace")
        require(receipt["exit_code"] == 0 and not ERRORS.search(original), "Process failed: " + str(log))
        if marker:
            receipt["completion"] = completion(original, marker)
        receipt["status"] = "passed"
        return receipt
    except BaseException as error:
        if process is not None:
            stop_process(process)
            receipt["exit_code"] = process.returncode
        receipt.update(status="failed", error=str(error))
        raise
    finally:
        receipt["elapsed_seconds"] = time.monotonic() - begin
        if log.exists():
            receipt["log_sha256"] = sha(log)
        write(log.with_suffix(".receipt.json"), receipt)


def execute(root: Path, candidate: Path, godot: Path, evidence: Path, *, graphical: bool = False,
            project: Path | None = None, inherited_environment: dict[str, str] | None = None,
            include_legacy: bool = True) -> dict:
    root, candidate, evidence = root.resolve(), candidate.resolve(), evidence.resolve()
    target = "windows" if os.name == "nt" else "linux"
    manifest = verify(root, candidate, target)
    require(not evidence.exists(), "Execution evidence is immutable; choose a new directory")
    godot = godot.resolve(strict=True)
    actual_version = subprocess.check_output([str(godot), "--version"], text=True, timeout=30).strip()
    require(actual_version == VERSION, "Qualification requires the exact repository Godot pin")
    project = (project or root / "godot").resolve(strict=True)
    # The caller chooses source checkout or a verified extracted source tree.
    installed_runtime = project / "addons/cybersand_native/bin" / Path(RUNTIMES[target]).name
    require(sha(installed_runtime) == manifest["native_sha256"], "Executed project runtime differs from the candidate")
    evidence.mkdir(parents=True)
    environment = dict(inherited_environment or os.environ)
    environment.update(APPDATA=str(evidence / "userdata"), XDG_DATA_HOME=str(evidence / "userdata"),
                       CYBERSAND_SOURCE_REVISION=manifest["source_commit"],
                       MAT_AUDITION_EVIDENCE_DIR=str(evidence / "frames"),
                       MAT_AUDITION_DEMO_EVIDENCE_DIR=str(evidence / "authored-scenes"))
    for key in ("MATERIAL_LAB_CACHED_ONLY", "MATERIAL_LAB_SKIP_COMPILE"):
        environment.pop(key, None)
    report = {"schema": "cybersand.material-audition.execution", "schema_version": 1,
              "source_commit": manifest["source_commit"], "source_tree": manifest["source_tree"],
              "native_sha256": manifest["native_sha256"], "candidate_sha256": sha(candidate / MANIFEST),
              "platform": target, "platform_detail": platform.platform(), "graphical": graphical,
              "godot_version": actual_version, "godot_sha256": sha(godot), "status": "running", "cases": []}
    prefix = [str(godot), "--audio-driver", "Dummy", "--path", str(project)]
    try:
        report["cases"].append({"name": "import", **run_process(
            prefix + ["--headless", "--editor", "--quit"], evidence / "import.log", environment, 900)})
        cases = CASES if include_legacy else CASES[:1]
        for name, marker in cases:
            args = prefix.copy()
            if graphical and name == "test_material_audition":
                args += ["--rendering-method", "gl_compatibility", "--max-fps", "30"]
                if target == "windows":
                    args += ["--rendering-driver", "opengl3_angle"]
            else:
                args += ["--headless"]
            args += ["--script", "res://tests/" + name + ".gd"]
            if name == "test_material_lab_ui":
                # The existing ordinary Workbench mount is the regression
                # target here. The portable evaluator additionally runs this
                # script's full isolated-authoring path using bundled tools.
                args += ["--", "--workbench-mount-only"]
            report["cases"].append({"name": name, **run_process(
                args, evidence / (name + ".log"), environment, 1200, marker)})
            write(evidence / "execution.json", report)
        verify(root, candidate, target)
        require(sha(installed_runtime) == manifest["native_sha256"], "Runtime changed during qualification")
        report["status"] = "passed"
    except BaseException as error:
        report.update(status="failed", error=str(error))
        raise
    finally:
        report["files_sha256"] = {path.relative_to(evidence).as_posix(): sha(path)
                                   for path in sorted(evidence.rglob("*")) if path.is_file() and
                                   path != evidence / "execution.json" and "userdata" not in path.relative_to(evidence).parts}
        write(evidence / "execution.json", report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("record", "verify", "run"))
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--platform", choices=tuple(RUNTIMES))
    parser.add_argument("--runtime", type=Path)
    parser.add_argument("--toolchain", type=Path)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--audition-only", action="store_true")
    args = parser.parse_args()
    if args.command == "record":
        require(args.platform is not None and args.runtime is not None, "Record requires platform and runtime")
        result = record(args.root, args.platform, args.runtime, args.candidate, args.toolchain)
    elif args.command == "verify":
        result = verify(args.root, args.candidate, args.platform)
    else:
        require(args.godot is not None and args.evidence is not None, "Run requires Godot and evidence")
        result = execute(args.root, args.candidate, args.godot, args.evidence,
                         graphical=args.graphical, include_legacy=not args.audition_only)
    print(json.dumps({"status": result["status"], "source_commit": result["source_commit"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
