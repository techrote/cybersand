#!/usr/bin/env python3
"""Execute source-built Workbench tests, including fresh installed layouts.

This runner never supplies model credentials or invokes a cloud provider. The
provider transport regression uses the repository's loopback HTTP fixtures.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from package_explore001_candidate import stage_generator_profiles
import native_candidate_identity

REOPEN_VARS = (
    "WB_GENERATOR_REOPEN", "WB_GENERATOR_EXPECT_MISSING", "PAINT_REOPEN",
    "PAINT_GENERATED_REOPEN", "CYBERSAND_PAINT_HISTORY_REOPEN", "WB_COMBINED_REOPEN",
    "CYBERSAND_WORKBENCH_REOPEN",
)
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def committed_lfs_pins() -> dict:
    """Read canonical pointer blobs even when Git archive smudges LFS data."""
    paths = subprocess.check_output(["git", "lfs", "ls-files", "--name-only", "HEAD"],
                                    cwd=ROOT, text=True).splitlines()
    pins = {}
    for name in paths:
        pointer = subprocess.check_output(["git", "cat-file", "blob", "HEAD:"+name], cwd=ROOT)
        match = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", pointer)
        if match is None:
            raise ValueError(f"Invalid committed LFS pointer: {name}")
        pins[name] = (match[1].decode(), int(match[2]))
    return pins


def verify_lfs_payload(name: str, data: bytes, pins: dict) -> None:
    expected_sha, expected_size = pins[name]
    if hashlib.sha256(data).hexdigest() != expected_sha or len(data) != expected_size:
        raise ValueError(f"Unmaterialized or changed LFS payload: {name}")


def completion(text: str, marker: str) -> dict:
    lines = [line[len(marker):].strip() for line in text.splitlines() if line.startswith(marker + " ")]
    if not lines:
        raise RuntimeError(f"Required completion marker is absent: {marker}")
    tail = lines[-1]
    if tail.startswith("{"):
        result = json.loads(tail)
    else:
        match = re.search(r"checks=(\d+)\s+failures=(\d+)", tail)
        if match is None:
            match = re.search(r"(\d+) checks, (\d+) failures", tail)
        if match is None:
            match = re.search(r"(\d+) assertions; (\d+) failures", tail)
        if match is None:
            raise RuntimeError(f"Malformed completion marker: {marker} {tail}")
        result = {"checks": int(match[1]), "failures": int(match[2])}
    if not isinstance(result.get("checks"), int) or result["checks"] < 1 or result.get("failures") not in (0, []):
        raise RuntimeError(f"Incomplete or failing checks: {marker} {tail}")
    return result


class Runner:
    def __init__(self, args):
        self.args = args
        self.evidence = args.evidence.resolve()
        self.evidence.mkdir(parents=True, exist_ok=True)
        self.results = []
        self.env = dict(os.environ)
        for name in REOPEN_VARS:
            self.env.pop(name, None)
        self.env["XDG_DATA_HOME"] = str(self.evidence / "userdata")
        self.env["APPDATA"] = str(self.evidence / "userdata")
        self.env["WB_ART_EVIDENCE_DIR"] = str(self.evidence / "art-frames")

    def execute(self, label, command, *, env=None, marker=None, timeout=1800, validate=None):
        log = self.evidence / f"{label}.log"
        effective_env = dict(self.env, **(env or {}))
        receipt = {"label": label, "command": command}
        self.results.append(receipt)
        try:
            with log.open("w", encoding="utf-8") as output:
                process = subprocess.run(command, cwd=self.evidence, env=effective_env,
                                         stdout=output, stderr=subprocess.STDOUT, timeout=timeout)
            text = log.read_text(encoding="utf-8", errors="replace")
            receipt["exit_code"] = process.returncode
            if process.returncode or ERRORS.search(text):
                print(text[-14000:])
                raise RuntimeError(f"{label} failed; retained log: {log}")
            if marker:
                receipt["completion"] = completion(text, marker)
            if validate:
                receipt["completion"] = validate()
            receipt["status"] = "passed"
            print(f"PASS {label}: {receipt.get('completion', {})}", flush=True)
            return text
        except Exception as error:
            receipt["status"] = "failed"
            receipt["error"] = str(error)
            raise
        finally:
            (self.evidence / "results.json").write_text(json.dumps(self.results, indent=2)+"\n", encoding="utf-8")

    def godot(self, project, label, script=None, marker=None, *, graphical=False, env=None):
        command = [str(self.args.godot.resolve()), "--audio-driver", "Dummy"]
        if graphical:
            command += ["--rendering-method", "gl_compatibility"]
            if sys.platform == "win32":
                command += ["--rendering-driver", "opengl3_angle"]
            else:
                command += ["--display-driver", "x11"]
        else:
            command.append("--headless")
        command += ["--path", str(project.resolve())]
        if script:
            command += ["--script", f"res://tests/{script}.gd"]
        else:
            command += ["--editor", "--quit"]
        return self.execute(label, command, env=env, marker=marker)


def stage_linux(args):
    """Archive committed source, then install this run's rebuilt Linux runtime."""
    destination = args.output.resolve()
    if destination.exists():
        raise ValueError("Linux install destination must be a new non-Git directory")
    native = "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
    rapier = "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
    commit, tree, source_inputs = native_candidate_identity.source(ROOT)
    subprocess.run(["git", "diff", "--exit-code", "HEAD", "--", "godot/scripts", "godot/tests", "examples/worldgen"],
                   cwd=ROOT, check=True)
    lfs_pins = committed_lfs_pins()
    payload = subprocess.check_output(["git", "archive", "HEAD", "--", "godot", "examples/worldgen"], cwd=ROOT)
    destination.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(payload)) as archive:
        for item in archive:
            if not item.isfile() or item.name.startswith("godot/.godot/"):
                continue
            if "/bin/" in item.name and item.name not in (native, rapier):
                continue
            data = archive.extractfile(item).read()
            if item.name in (native, rapier):
                data = (ROOT / item.name).read_bytes()
                if not data.startswith(b"\x7fELF"):
                    raise ValueError(f"Missing materialized Linux runtime: {item.name}")
                if item.name == rapier:
                    verify_lfs_payload(item.name, data, lfs_pins)
            elif item.name in lfs_pins:
                if data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
                    data = (ROOT / item.name).read_bytes()
                verify_lfs_payload(item.name, data, lfs_pins)
            target = destination / item.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    profiles = stage_generator_profiles(destination)
    # Retained provenance describes the old committed binary, not this rebuild.
    retained = destination / "godot/addons/cybersand_native/runtime-provenance.linux.json"
    if retained.exists():
        retained.rename(retained.with_name("retained-runtime-provenance.linux.reference.json"))
    identity = {
        "source_commit": commit,
        "source_tree": tree,
        "source_inputs": source_inputs,
        "native_sha256": digest(destination / native),
        "generator_profiles_sha256": profiles,
        "files_sha256": {p.relative_to(destination).as_posix(): digest(p) for p in sorted(destination.rglob("*")) if p.is_file()},
    }
    (destination / "qualification-source.json").write_text(json.dumps(identity, indent=2)+"\n", encoding="utf-8")
    print(destination)


def verify_package(package: Path) -> dict:
    windows = (package / "candidate-manifest.json").is_file()
    filename = "candidate-manifest.json" if windows else "qualification-source.json"
    manifest = json.loads((package / filename).read_text(encoding="utf-8"))
    for name, expected in manifest["files_sha256"].items():
        if digest(package / name) != expected:
            raise ValueError(f"Packaged file differs from its identity: {name}")
    if windows:
        provenance = json.loads((package / "source-built-candidate-provenance.json").read_text(encoding="utf-8"))
        native = package / native_candidate_identity.NATIVE
        if (provenance.get("kind") != "source-built-windows-candidate"
                or provenance.get("source_commit") != manifest["source_commit"]
                or provenance.get("source_tree") != manifest["source_tree"]
                or provenance.get("sha256") != digest(native)
                or provenance.get("sha256") != manifest["native_sha256"]
                or provenance.get("size") != native.stat().st_size
                or not native.read_bytes().startswith(b"MZ")):
            raise ValueError("Windows delivered DLL/provenance does not match the package source identity")
        if (package / "godot/addons/cybersand_native/runtime-provenance.json").exists():
            raise ValueError("Windows package still presents retained binary provenance as current")
    else:
        native = package / "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
        if digest(native) != manifest["native_sha256"] or not native.read_bytes().startswith(b"\x7fELF"):
            raise ValueError("Linux delivered runtime differs from the source-build identity")
    commit, tree, inputs = native_candidate_identity.source(ROOT)
    package_inputs = provenance["source_inputs"] if windows else manifest["source_inputs"]
    if commit != manifest["source_commit"] or tree != manifest["source_tree"] or inputs != package_inputs:
        raise ValueError("Installed package does not match the executing qualification source")
    return manifest


def combined_authoring(runner, project, label):
    for workers in (1, 4):
        for phase in ("author", "reopen"):
            case = f"{label}-workers-{workers}-{phase}"
            frames = runner.evidence / f"{case}-frames"
            env = {"WB_COMBINED_WORKERS": str(workers),
                   "WB_COMBINED_REOPEN": "1" if phase == "reopen" else "0",
                   "WB_COMBINED_SCREENSHOTS": str(frames), "WB_COMBINED_REQUIRE_GRAPHICS": "1",
                   "XDG_DATA_HOME": str(runner.evidence / f"{label}-workers-{workers}-userdata"),
                   "APPDATA": str(runner.evidence / f"{label}-workers-{workers}-userdata")}
            text = runner.godot(project, case, "test_workbench_combined_authoring",
                                "WB_COMBINED_AUTHORING", graphical=True, env=env)
            receipt = completion(text, "WB_COMBINED_EVIDENCE")
            if not receipt.get("author_complete" if phase == "author" else "reopen_complete"):
                raise RuntimeError(f"Combined {case} did not complete every required phase")
            if receipt.get("source_identity", {}).get("display") == "headless":
                raise RuntimeError(f"Combined {case} did not run a graphical display")
            required = {"combined-generator-profiles.png"}
            if phase == "author":
                required.update(("combined-generator-preview.png", "combined-agent-and-paint.png",
                                 "combined-authored-saved.png"))
            else:
                required.add("combined-reopened-and-continued.png")
            screenshots = {p.name for p in frames.glob("*.png") if p.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")}
            if not required.issubset(screenshots):
                raise RuntimeError(f"Combined {case} is missing framebuffer evidence: {sorted(required-screenshots)}")


def installed(args):
    runner = Runner(args)
    package = args.package.resolve()
    scratch = args.scratch.resolve()
    if scratch.exists():
        raise ValueError("Installed-validation scratch must be a new directory")
    if any((p / ".git").exists() for p in (scratch, *scratch.parents)):
        raise ValueError("Installed validation must run outside every Git worktree")
    manifest = verify_package(package)
    scratch.mkdir(parents=True)
    inventory = {name: {p.name: digest(p) for p in sorted((package / name).glob("*.json"))}
                 for name in ("examples/worldgen", "godot/authoring/worldgen")}
    if not inventory["examples/worldgen"] or inventory["examples/worldgen"] != inventory["godot/authoring/worldgen"]:
        raise ValueError("Packaged sibling and resource profile inventories must be present and identical")
    if inventory["examples/worldgen"] != manifest["generator_profiles_sha256"]:
        raise ValueError("Installed profiles differ from the packaged generator manifest")
    runner.env["WB_GENERATOR_PROFILE_COUNT"] = str(len(inventory["examples/worldgen"]))
    runner.env["CYBERSAND_SOURCE_REVISION"] = manifest["source_commit"]
    (runner.evidence / "profile-inventory.json").write_text(json.dumps(inventory, indent=2)+"\n", encoding="utf-8")
    for variant in ("complete", "resource-only", "missing-profiles"):
        target = scratch / variant
        shutil.copytree(package, target, ignore=shutil.ignore_patterns(".git", ".godot"))
        if variant != "complete":
            shutil.rmtree(target / "examples/worldgen")
        if variant == "missing-profiles":
            shutil.rmtree(target / "godot/authoring/worldgen")
        project = target / "godot"
        runner.godot(project, f"{variant}-import")
        env = {"WB_GENERATOR_EXPECT_MISSING": "1" if variant == "missing-profiles" else "0"}
        runner.godot(project, f"{variant}-discovery", "test_workbench_generator_discovery", "WB_GENERATOR_DISCOVERY", env=env)
        if variant != "complete":
            continue
        for phase in ("author", "reopen"):
            frames = runner.evidence / f"installed-{phase}-frames"
            env = {"WB_GENERATOR_REOPEN": "1" if phase == "reopen" else "0",
                   "WB_GENERATOR_SCREENSHOTS": str(frames), "WB_GENERATOR_REQUIRE_GRAPHICS": "1"}
            runner.godot(project, f"installed-{phase}", "test_workbench_generator_installed",
                         "WB_GENERATOR_INSTALLED", graphical=True, env=env)
            screenshots = {p.name for p in frames.glob("*.png") if p.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")}
            required = {"generator-profiles.png", "generator-native-preview.png",
                        "generator-reopened.png" if phase == "reopen" else "generator-painted-saved.png"}
            if not required.issubset(screenshots):
                raise RuntimeError(f"Actual graphical {phase} is missing required framebuffer evidence: {sorted(required-screenshots)}")
        if args.combined:
            combined_authoring(runner, project, "installed-combined")


def final_graphical_result(output: Path) -> dict:
    """Require the retained graphical fixture's own complete native evidence."""
    log = (output / "godot.log").read_text(encoding="utf-8", errors="replace")
    if ERRORS.search(log):
        raise RuntimeError("Final graphical fixture contains a script or resource error")
    result = json.loads((output / "smoke-result.json").read_text(encoding="utf-8"))
    checks = result.get("checks")
    if (not isinstance(checks, list) or not checks
            or any(not isinstance(row, dict) or row.get("ok") is not True for row in checks)
            or result.get("failures") != 0
            or not isinstance(result.get("frames"), int) or result["frames"] < 1
            or result.get("native_backend") != "CyberNativeCellWorld"):
        raise RuntimeError("Final graphical fixture lacks successful checks and native completion")
    frames = ("00-blank", "01-incremental", "02-incremental", "03-stopped", "04-after-stop",
              "05-local-followup", "06-world-followup", "07-final")
    for name in [stem+suffix+".png" for stem in frames for suffix in ("", "-canvas")] + ["native-materials.png"]:
        if not (output / name).read_bytes().startswith(b"\x89PNG\r\n\x1a\n"):
            raise RuntimeError("Final graphical fixture lacks an original framebuffer: "+name)
    return {"checks": len(checks), "failures": 0, "frames": result["frames"],
            "native_backend": result["native_backend"], "provider": "scripted loopback HTTP; no inference"}


def regressions(args):
    runner = Runner(args)
    project = args.project.resolve()
    runner.godot(project, "regression-import")
    runner.godot(project, "art-keyless", "test_art_provider", "ART_PROVIDER_KEYLESS")
    runner.godot(project, "art-stored-material", "test_art_stored_material", "ART_STORED_RESULT")
    runner.godot(project, "art-deferred-manual", "test_art_deferred_manual", "ART_DEFERRED_MANUAL")
    runner.godot(project, "art-native", "test_art_batch_native", "ART_STAGE1_RESULT")
    runner.godot(project, "art-native-render", "test_art_batch_native_render", "ART_STAGE1_RESULT", graphical=True)
    runner.execute("art-http-fixtures-graphical", [sys.executable, str(ROOT / "tools/test_art_provider_transport.py"),
                   "--godot", str(args.godot.resolve()), "--project", str(project),
                   "--output", str(runner.evidence / "http-graphical"), "--graphical"])
    final_frames = runner.evidence / "art-final-graphical"
    runner.execute("art-final-graphical-mocked", [sys.executable, str(ROOT / "tools/test_art_final_graphical.py"),
                   "--godot", str(args.godot.resolve()), "--root", str(ROOT), "--output", str(final_frames)],
                   validate=lambda: final_graphical_result(final_frames))
    if not args.paint:
        return
    runner.godot(project, "native-edit-ordering", "test_workbench_edit_ordering", "EDIT_ORDER_RESULT")
    runner.godot(project, "combined-deferred-paint", "test_workbench_deferred_paint", "WB_DEFERRED_PAINT")
    for script, marker in (("shapes", "PAINT_EDITOR_SHAPES"), ("executor", "PAINT_EXECUTOR"), ("recovery", "PAINT_RECOVERY")):
        runner.godot(project, f"paint-{script}", f"test_paint_editor_{script}", marker)
    for workers in (1, 4):
        runner.godot(project, f"paint-native-{workers}", "test_paint_editor_native", "PAINT_EDITOR_NATIVE",
                     env={"PAINT_TEST_WORKERS": str(workers)})
    for phase in ("author", "reopen"):
        runner.godot(project, f"paint-history-{phase}", "test_paint_editor_history", "PAINT_EDITOR_HISTORY",
                     env={"CYBERSAND_PAINT_HISTORY_REOPEN": "1" if phase == "reopen" else "0"})
    for family, marker, flag in (("workbench", "PAINT_EDITOR_WORKBENCH", "PAINT_REOPEN"),
                                ("generated_workbench", "PAINT_EDITOR_GENERATED_WORKBENCH", "PAINT_GENERATED_REOPEN")):
        for phase in ("author", "reopen"):
            runner.godot(project, f"paint-{family}-{phase}", f"test_paint_editor_{family}", marker,
                         graphical=True, env={flag: "1" if phase == "reopen" else "0"})
    runner.godot(project, "existing-workbench-input", "test_workbench_input", "WORKBENCH_INPUT")
    runner.godot(project, "existing-worldgen-planes", "test_worldgen_planes", "GEN-005 plane adapter:")
    runner.godot(project, "existing-worldgen-workbench", "test_worldgen_workbench", "WORLDGEN_WORKBENCH:")
    for phase in ("author", "reopen"):
        runner.godot(project, f"existing-canvas-{phase}", "test_workbench_canvas", "WORKBENCH_CANVAS",
                     env={"CYBERSAND_WORKBENCH_REOPEN": "1" if phase == "reopen" else "0"})
    combined_authoring(runner, project, "source-combined")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="mode", required=True)
    stage = sub.add_parser("stage-linux")
    stage.add_argument("--output", type=Path, required=True)
    stage.set_defaults(run=stage_linux)
    for name, function in (("installed", installed), ("regressions", regressions)):
        command = sub.add_parser(name)
        command.add_argument("--godot", type=Path, required=True)
        command.add_argument("--evidence", type=Path, required=True)
        command.set_defaults(run=function)
        if name == "installed":
            command.add_argument("--package", type=Path, required=True)
            command.add_argument("--scratch", type=Path, required=True)
            command.add_argument("--combined", action="store_true")
        else:
            command.add_argument("--project", type=Path, required=True)
            command.add_argument("--paint", action="store_true")
    args = parser.parse_args()
    outcome = {"mode": args.mode, "status": "running"}
    try:
        args.run(args)
        outcome["status"] = "passed"
    except Exception as error:
        outcome.update(status="failed", error=str(error))
        raise
    finally:
        if hasattr(args, "evidence"):
            args.evidence.mkdir(parents=True, exist_ok=True)
            (args.evidence / "qualification.json").write_text(json.dumps(outcome, indent=2)+"\n", encoding="utf-8")


if __name__ == "__main__":
    main()
