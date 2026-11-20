#!/usr/bin/env python3
"""Bounded, exact-source WB-ACTOR-COMPOSE-001 platform qualification.

The ordinary regression runner owns process watchdogs and diagnostic rejection.
This selector adds candidate custody, a focused complete case list, a fresh
process authored-save readback, and optional actual Workbench framebuffer proof.
Its explicit publish command prepares four candidate paths only; it never
commits, pushes, promotes a PR, dispatches inference, or changes accepted main.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

import execution_policy
import native_candidate_identity
import run_godot_regressions as runner

ROOT = Path(__file__).resolve().parents[2]
VERSION = "4.7.stable.official.5b4e0cb0f"
NATIVE = {
    "linux": "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
    "windows": "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
}
PROVENANCE = {
    "linux": "godot/addons/cybersand_native/runtime-provenance.linux.json",
    "windows": "godot/addons/cybersand_native/runtime-provenance.json",
}
RAPIER = {
    "linux": "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so",
    "windows": "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll",
}
CASES = (
    "test_workbench_actor_catalog",
    "test_workbench_actor_composition_session",
    "test_workbench_actor_composition_native",
    "test_workbench_actor_equipment_extent",
    "test_workbench_actor_composition",
    "test_prepared_physical_owner",
    "test_workbench_fleet_session",
    "test_workbench_input",
    "test_workbench_pilot_ui",
    "test_workbench_physics_play",
    "test_workbench_hard_placement",
    "test_workbench_failure_recovery",
    "test_workbench_material_baseline",
    "test_workbench_flatten",
    "test_workbench_combined_authoring",
    "test_paint_editor_generated_workbench",
    "test_paint_editor_workbench",
    "test_material_lab_workbench_integration",
    "test_physical_actor_session",
    "test_physical_actor_effect_cancellation",
    "test_physical_actor_script",
    "test_physical_usable_lifecycle",
    "test_physical_usable_script",
    "test_physical_usables_admission",
)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def source() -> dict:
    commit, tree, inputs = native_candidate_identity.source(ROOT)
    return {"source_commit": commit, "source_tree": tree, "source_inputs": inputs}


def project_inputs() -> dict:
    """Canonical LF source; exclude engine imports and candidate runtime bytes."""
    names = subprocess.check_output([
        "git", "ls-files", "-z", "--", "godot/scripts", "godot/tests", "godot/main.tscn",
        "godot/project.godot", "godot/shaders", "godot/examples", "godot/authoring",
        "godot/third_party", "examples/worldgen",
        "godot/addons/cybersand_native/cybersand_native.gdextension",
        "godot/addons/godot-rapier2d/godot-rapier2d.gdextension",
        "godot/addons/godot-rapier2d/runtime-provenance.linux.json",
        "godot/addons/godot-rapier2d/runtime-provenance.windows.json",
        "tools/ci", "tools/package_explore001_candidate.py", "tools/requirements-build.txt",
        "tools/build_pinned_godot_cpp.sh", "tools/build_native_extension.sh",
        "tools/build_native_extension_windows.sh", "tools/check_linux_runtime_floor.sh",
        "tools/toolchains",
        "materials/catalogue", "tools/material_catalogue", "tools/lcb",
        "docs/reference/liquid-solver-capability-matrix.json",
        "docs/reference/liquid-policy-wire-vectors.json",
        "docs/reference/water-normalization-vectors.json",
        "docs/reference/liquid-run-receipt-vectors.json",
        "docs/operations/workbench-actor-composition.md",
        "third_party", ".github/workflows/workbench-actor-composition.yml",
    ], cwd=ROOT).decode().split("\0")
    result = {}
    for name in sorted(filter(None, names)):
        canonical = subprocess.check_output(["git", "show", "HEAD:" + name], cwd=ROOT)
        actual = (ROOT / name).read_bytes().replace(b"\r\n", b"\n")
        if canonical.replace(b"\r\n", b"\n") != actual:
            raise ValueError("Uncommitted qualification input: " + name)
        result[name] = hashlib.sha256(actual).hexdigest()
    return result


def record(args) -> None:
    binary = args.binary.resolve(strict=True)
    prefix = b"MZ" if args.platform == "windows" else b"\x7fELF"
    if not binary.read_bytes().startswith(prefix):
        raise ValueError("Candidate binary has the wrong platform format")
    args.output.mkdir(parents=True, exist_ok=True)
    destination = args.output / Path(NATIVE[args.platform]).name
    if binary != destination.resolve():
        shutil.copyfile(binary, destination)
    current_source = source()
    build_ledger = None
    if args.build_ledger:
        build_ledger = json.loads(args.build_ledger.read_text(encoding="utf-8"))
        if (build_ledger.get("source_inputs") != current_source["source_inputs"]
                or build_ledger.get("sha256") != digest(destination)
                or build_ledger.get("size") != destination.stat().st_size
                or build_ledger.get("build_succeeded") is not True):
            raise ValueError("Pre-checkpoint build ledger does not match committed native inputs and runtime")
    identity = {
        "schema": 1, "kind": "workbench-actor-native-candidate", "platform": args.platform,
        **current_source, "build_inputs": project_inputs(), "artifact": NATIVE[args.platform],
        "sha256": digest(destination), "size": destination.stat().st_size,
        "toolchain": args.toolchain.read_text(encoding="utf-8") if args.toolchain else "",
        "pre_checkpoint_build_ledger": build_ledger,
        "execution": "not yet qualified; consume target-platform result separately",
    }
    write(args.output / "actor-candidate.json", identity)
    print(json.dumps({key: identity[key] for key in ("platform", "source_commit", "sha256", "size")}))


def candidate(directory: Path, platform: str) -> dict:
    manifest = json.loads((directory / "actor-candidate.json").read_text(encoding="utf-8"))
    expected = source()
    if (manifest.get("schema") != 1 or manifest.get("kind") != "workbench-actor-native-candidate"
            or manifest.get("platform") != platform or manifest.get("artifact") != NATIVE[platform]
            or any(manifest.get(key) != value for key, value in expected.items())
            or manifest.get("build_inputs") != project_inputs()):
        raise ValueError("Candidate source, platform or complete qualification input mismatch")
    binary = directory / Path(NATIVE[platform]).name
    if digest(binary) != manifest.get("sha256") or binary.stat().st_size != manifest.get("size"):
        raise ValueError("Candidate runtime bytes changed")
    return manifest


def install(args) -> None:
    manifest = candidate(args.candidate, args.platform)
    shutil.copyfile(args.candidate / Path(NATIVE[args.platform]).name, ROOT / NATIVE[args.platform])
    print("Installed source-matched candidate", manifest["sha256"])


def publish(args) -> None:
    """Stage only four candidate paths; never commit, push, promote or merge."""
    branch = subprocess.check_output(["git", "branch", "--show-current"], cwd=ROOT, text=True).strip()
    if branch != "feat/workbench-actor-composition-589":
        raise ValueError("Actor runtime staging is confined to its authorized Draft/HOLD branch")
    candidates = {platform: candidate(getattr(args, platform), platform) for platform in NATIVE}
    installed_qualification = None
    if bool(args.windows_installed_report) != bool(args.windows_modules_report):
        raise ValueError("Installed Windows gameplay and module reports must be supplied together")
    if args.windows_installed_report:
        installed = json.loads(args.windows_installed_report.read_text(encoding="utf-8"))
        modules = json.loads(args.windows_modules_report.read_text(encoding="utf-8-sig"))
        required = {"import", "test_workbench_actor_composition",
                    "test_workbench_actor_composition_reopen", "actor_workshop_render"}
        names = {row.get("name") for row in installed.get("results", [])}
        if (installed.get("status") != "passed" or installed.get("completed") is not True
                or installed.get("candidate") != candidates["windows"]
                or not required.issubset(names)
                or installed.get("graphical_capture", {}).get("status") != "passed"
                or not installed.get("installed_package")
                or modules.get("status") != "passed"
                or modules.get("source_commit") != candidates["windows"]["source_commit"]
                or modules.get("source_tree") != candidates["windows"]["source_tree"]
                or modules.get("executable", {}).get("status") != "verified"
                or len(modules.get("modules", [])) != 3
                or any(row.get("status") != "verified" for row in modules.get("modules", []))):
            raise ValueError("Installed Windows package or actual module qualification is incomplete")
        installed_qualification = {
            "status": "passed", "gameplay_report_sha256": digest(args.windows_installed_report),
            "module_report_sha256": digest(args.windows_modules_report),
            "scope": "Fresh non-checkout installation, graphical Save/Load, actual Workbench frames and app-local DLL resolution.",
        }
    prepared = {}
    for platform, manifest in candidates.items():
        path = ROOT / PROVENANCE[platform]
        previous = json.loads(path.read_text(encoding="utf-8"))
        report_path = getattr(args, platform + "_report")
        qualification = {"status": "pending", "platform": platform,
                         "scope": "Source/build custody only; target-platform gameplay and graphical qualification pending."}
        if report_path:
            report = json.loads(report_path.read_text(encoding="utf-8"))
            names = {row.get("name") for row in report.get("results", [])}
            expected = set(CASES) | {"import", "test_workbench_actor_composition_reopen",
                                     "actor_workshop_render", "actor_composition_performance"}
            if (report.get("status") != "passed" or report.get("completed") is not True
                    or report.get("candidate") != manifest or not expected.issubset(names)
                    or report.get("graphical_capture", {}).get("status") != "passed"):
                raise ValueError("Cannot publish a passing runtime claim from incomplete or different-source evidence")
            qualification = {"status": "passed", "platform": platform,
                             "report_sha256": digest(report_path), "cases": sorted(names),
                             "graphical_capture": report.get("graphical_capture", {}),
                             "scope": "Recorded automated coupled gameplay; owner playfeel and full release gates remain separate."}
        prepared[platform] = {
            "schema_version": 1, "kind": "source-matched-workbench-actor-evaluation-candidate",
            "artifact": NATIVE[platform], "sha256": manifest["sha256"], "size": manifest["size"],
            "source_commit": manifest["source_commit"], "build_commit": manifest["source_commit"],
            "source_tree": manifest["source_tree"], "platform": platform + " x86_64",
            "status": "evaluation-candidate-" + qualification["status"],
            "source_input_hash_kind": "sha256-canonical-lf",
            "source_inputs": manifest["source_inputs"], "build_inputs": manifest["build_inputs"],
            "godot_version": VERSION, "godot_cpp_commit": "101ae38034304346a46ea9ea84ae156d3e860496",
            "toolchain": manifest["toolchain"], "pre_checkpoint_build_ledger": manifest.get("pre_checkpoint_build_ledger"),
            "validated_platform": platform + " x86_64; " + qualification["status"],
            "qualification": qualification,
            "installed_package_qualification": installed_qualification if platform == "windows" else None,
            "workflow_run": os.environ.get("GITHUB_RUN_ID", "local-unpublished"),
            "workflow_attempt": os.environ.get("GITHUB_RUN_ATTEMPT", "local-unpublished"),
            "acceptance": "Draft/HOLD evaluation candidate. No merge, production release or owner playfeel acceptance is claimed.",
            "supersedes": {"build_commit": previous.get("build_commit"), "sha256": previous.get("sha256"),
                           "scope": "Previous accepted runtime remains recoverable from Git/LFS history."},
        }
    # Complete source/custody validation for both platforms before staging any
    # tracked byte. These four destinations are the complete mutation surface.
    for platform, manifest in prepared.items():
        binary = ROOT / NATIVE[platform]
        temporary = binary.with_suffix(binary.suffix + ".actor-candidate")
        shutil.copyfile(getattr(args, platform) / binary.name, temporary)
        temporary.replace(binary)
        write(ROOT / PROVENANCE[platform], manifest)
    print(json.dumps({"staged": [NATIVE[p] for p in NATIVE] + [PROVENANCE[p] for p in NATIVE],
                      "source_commit": candidates["linux"]["source_commit"], "state": "Draft/HOLD"}))


def completion(case: runner.Case, receipt: dict, output: Path) -> None:
    """A zero engine exit without reaching the fixture's assertions is failure."""
    log = (output / receipt["log"]).read_text(encoding="utf-8", errors="replace")
    if case.name in ("test_workbench_actor_composition", "test_workbench_actor_composition_reopen"):
        records = [json.loads(line.removeprefix("WB_ACTOR_COMPOSE "))
                   for line in log.splitlines() if line.startswith("WB_ACTOR_COMPOSE ")]
        if len(records) != 1 or records[0].get("failures") != [] or records[0].get("checks", 0) <= 0:
            raise ValueError("Missing complete ordinary Workbench assertion receipt: " + case.name)
        receipt["assertion_receipt"] = records[0]
    elif case.name in ("test_workbench_actor_composition_session", "test_workbench_actor_composition_native"):
        kind = case.name.rsplit("_", 1)[1]
        match = re.search(r"Workbench actor composition " + kind + r": (\d+) checks, (\d+) failures", log)
        if not match or int(match[1]) <= 0 or int(match[2]) != 0:
            raise ValueError("Missing completed actor " + kind + " assertion receipt")
        receipt["assertions"] = int(match[1])
    elif case.name == "test_prepared_physical_owner":
        match = re.search(r"PREPARED_PHYSICAL_OWNER: (\d+) assertions; (\d+) failures", log)
        if not match or int(match[1]) <= 0 or int(match[2]) != 0:
            raise ValueError("Missing completed prepared-owner assertion receipt")
        receipt["assertions"] = int(match[1])
    elif case.name in ("test_workbench_actor_equipment_extent", "test_physical_actor_effect_cancellation"):
        label = ("Workbench actor equipment extent" if case.name.endswith("extent")
                 else "Physical actor effect cancellation")
        match = re.search(re.escape(label) + r": (\d+) checks, (\d+) failures", log)
        if not match or int(match[1]) <= 0 or int(match[2]) != 0:
            raise ValueError("Missing completed material authority assertion receipt: " + label)
        receipt["assertions"] = int(match[1])
    elif case.name == "test_workbench_actor_catalog":
        match = re.search(r"WB_ACTOR_CATALOG checks=(\d+) failures=(\d+) models=(\d+)", log)
        if not match or int(match[1]) <= 0 or int(match[2]) != 0 or int(match[3]) < 50:
            raise ValueError("Missing completed broad actor catalogue assertion receipt")
        receipt.update(assertions=int(match[1]), models=int(match[3]))
    elif case.name == "actor_composition_performance":
        records = [json.loads(line.removeprefix("WB_ACTOR_PERFORMANCE "))
                   for line in log.splitlines() if line.startswith("WB_ACTOR_PERFORMANCE ")]
        if (len(records) != 1 or records[0].get("failures") != []
                or records[0].get("baseline") is not False or len(records[0].get("rows", [])) != 12):
            raise ValueError("Incomplete small/landscape measured Workbench campaign")
        receipt["measurement_receipt"] = records[0]


def verify_package(directory: Path, manifest: dict) -> dict:
    """Qualify the portable bytes, without a development checkout or imports."""
    if (directory / ".git").exists():
        raise ValueError("Installed qualification must run outside a Git checkout")
    package = json.loads((directory / "candidate-manifest.json").read_text(encoding="utf-8"))
    if (package.get("source_commit") != manifest["source_commit"]
            or package.get("source_tree") != manifest["source_tree"]
            or package.get("native_sha256") != manifest["sha256"]):
        raise ValueError("Portable package source/runtime differs from this candidate")
    for name, expected in package["files_sha256"].items():
        path = (directory / name).resolve()
        if not path.is_relative_to(directory) or digest(path) != expected:
            raise ValueError("Portable package payload differs: " + name)
    return package


def campaign_userdata(project_root: Path) -> tempfile.TemporaryDirectory:
    """Keep authoring subprocess output outside both source and installation."""
    directory = tempfile.TemporaryDirectory(prefix="cybersand-actor-qualification-")
    path = Path(directory.name).resolve()
    if path.is_relative_to(ROOT.resolve()) or path.is_relative_to(project_root.resolve()):
        directory.cleanup()
        raise ValueError("Qualification temporary userdata must be outside source and installed package")
    return directory


def test(args) -> int:
    platform = "windows" if sys.platform == "win32" else "linux"
    manifest = candidate(args.candidate, platform)
    project_root = args.package.resolve() if args.package else ROOT
    package = verify_package(project_root, manifest) if args.package else None
    runtime = project_root / NATIVE[platform]
    if digest(runtime) != manifest["sha256"]:
        raise ValueError("Installed runtime is not the declared candidate")
    rapier_provenance = json.loads((ROOT / ("godot/addons/godot-rapier2d/runtime-provenance."
                                                        + platform + ".json")).read_text())
    if digest(project_root / RAPIER[platform]) != rapier_provenance["sha256"]:
        raise ValueError("Rapier does not match the retained cooperative-BVH pin")
    version = subprocess.check_output([str(args.godot), "--version"], text=True, timeout=30).strip()
    if version != VERSION:
        raise ValueError("Godot version differs from the pin: " + version)
    if args.output.exists():
        raise ValueError("Qualification output must be a new directory")
    args.output.mkdir(parents=True)
    before = project_inputs()
    report = {"schema": 1, "status": "running", "platform": platform,
              "candidate": manifest, "godot_version": version,
              "rapier_sha256": digest(project_root / RAPIER[platform]), "results": [],
              "installed_package": package}
    available = {case.name: case for case in runner.discover_cases()}
    requested = args.cases.split(",") if args.cases else (
        ["test_workbench_actor_composition"] if args.package else list(CASES))
    if not requested or len(requested) != len(set(requested)) or any(name not in available for name in requested):
        raise ValueError("Required actor regression is absent or duplicated")
    cases = [runner.Case("import", ("--editor", "--quit"),
                        execution_policy.watchdog_seconds("godot_import_seconds"), 3)]
    for name in requested:
        case = available[name]
        if name == "test_workbench_actor_composition" and args.package:
            case = runner.Case(case.name, case.flags, case.timeout, case.weight, True)
        cases.append(case)
        if name == "test_workbench_actor_composition":
            cases.append(runner.Case(case.name + "_reopen", case.flags, case.timeout,
                                     case.weight, case.requires_display))
    if args.graphical:
        cases.append(runner.Case("actor_workshop_render",
                     ("--script", "res://tests/capture_workbench_actor_workshop.gd"),
                     execution_policy.watchdog_seconds("graphical_case_seconds"), 30, True))
    if args.measure:
        cases.append(runner.Case("actor_composition_performance",
                     ("--script", "res://tests/measure_workbench_actor_composition.gd"),
                     execution_policy.complex_process_seconds(), 120, args.graphical))
    userdata_owner = campaign_userdata(project_root)
    userdata = Path(userdata_owner.name).resolve()
    report["userdata"] = {"execution_directory": str(userdata),
                          "retained_directory": "userdata", "retained": False,
                          "scope": "One external directory shared across the campaign and fresh-process reopen."}
    try:
        env = dict(os.environ)
        env["XDG_DATA_HOME"] = str(userdata)
        env["APPDATA"] = env["XDG_DATA_HOME"]
        env["CYBERSAND_SOURCE_REVISION"] = manifest["source_commit"]
        env["WB_ACTOR_CAPTURE_DIR"] = str((args.output / "frames").resolve())
        env["WB_ACTOR_PERFORMANCE_OUTPUT"] = str((args.output / "performance.json").resolve())
        env["WB_ACTOR_MEASURE_MS"] = "3000"
        env.pop("WB_ACTOR_BASELINE", None)
        env["CYBERSAND_ACTOR_COMPOSITION_NAME"] = "actor-composition-" + manifest["source_commit"][:12]
        env.pop("CYBERSAND_ACTOR_COMPOSITION_REOPEN", None)
        env.pop("CYBERSAND_ACTOR_COMPOSITION_CAPTURE", None)
        # Reuse the established watchdog and diagnostics, changing only the
        # application root when exercising the committed portable installation.
        runner.ROOT = project_root
        for case in cases:
            if platform == "windows" and case.requires_display:
                case = runner.Case(case.name, (*case.flags, "--rendering-driver", "opengl3_angle"),
                                   case.timeout, case.weight, True)
            case_env = dict(env)
            if case.name in ("test_workbench_actor_composition", "test_workbench_actor_composition_reopen"):
                reopen = case.name.endswith("_reopen")
                case_env["CYBERSAND_ACTOR_COMPOSITION_REOPEN"] = "1" if reopen else "0"
                case_env["CYBERSAND_ACTOR_COMPOSITION_REPORT"] = str(
                    (args.output / ("reopen.json" if reopen else "authored.json")).resolve())
                if case.requires_display:
                    case_env["CYBERSAND_ACTOR_COMPOSITION_CAPTURE"] = str(
                        (args.output / ("reopen-frames" if reopen else "authored-frames")).resolve())
            receipt, failed = runner.run_case(str(args.godot.resolve()), case, args.output, "case", env=case_env)
            report["results"].append(receipt)
            write(args.output / "qualification.json", report)
            if failed:
                raise RuntimeError("Required actor qualification failed: " + case.name)
            completion(case, receipt, args.output)
        if project_inputs() != before or digest(runtime) != manifest["sha256"]:
            raise RuntimeError("Qualification inputs changed during execution")
        if args.graphical:
            capture = json.loads((args.output / "frames/workshop.json").read_text())
            if capture.get("status") != "passed" or len(capture.get("images", [])) < 3:
                raise ValueError("Actual Workbench capture receipt is absent/incomplete")
            report["graphical_capture"] = capture
        report.update(status="passed", completed=True, executed_cases=len(cases))
        return 0
    except Exception as error:
        report.update(status="failed", completed=False, error=str(error))
        raise
    finally:
        runner.ROOT = ROOT
        # The process owner has retired the last child before evidence is copied
        # into the checkout. The Materials Lab source-write guard stays intact.
        try:
            shutil.copytree(userdata, args.output / "userdata")
            report["userdata"]["retained"] = True
        except Exception as error:
            report.update(status="failed", completed=False)
            report["userdata"]["retention_error"] = str(error)
            raise
        finally:
            try:
                userdata_owner.cleanup()
                report["userdata"]["temporary_directory_removed"] = True
            except Exception as error:
                report.update(status="failed", completed=False)
                report["userdata"]["cleanup_error"] = str(error)
                raise
            finally:
                write(args.output / "qualification.json", report)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    build = commands.add_parser("record")
    build.add_argument("--platform", choices=NATIVE, required=True)
    build.add_argument("--binary", type=Path, required=True)
    build.add_argument("--output", type=Path, required=True)
    build.add_argument("--toolchain", type=Path)
    build.add_argument("--build-ledger", type=Path,
                       help="Verify native inputs of an already-built pre-checkpoint local candidate")
    stage = commands.add_parser("install")
    stage.add_argument("--platform", choices=NATIVE, required=True)
    stage.add_argument("--candidate", type=Path, required=True)
    publication = commands.add_parser("publish")
    publication.add_argument("--linux", type=Path, required=True)
    publication.add_argument("--windows", type=Path, required=True)
    publication.add_argument("--linux-report", type=Path)
    publication.add_argument("--windows-report", type=Path)
    publication.add_argument("--windows-installed-report", type=Path)
    publication.add_argument("--windows-modules-report", type=Path)
    run = commands.add_parser("test")
    run.add_argument("--godot", type=Path, required=True)
    run.add_argument("--candidate", type=Path, required=True)
    run.add_argument("--output", type=Path, required=True)
    run.add_argument("--cases", help="Comma-separated focused selection; omission executes complete registered set")
    run.add_argument("--graphical", action="store_true")
    run.add_argument("--measure", action="store_true",
                     help="Measure 12 actual owner workloads on 1024x512 and 2048x1024 canvases")
    run.add_argument("--package", type=Path,
                     help="Validate and run a portable Windows installation outside Git")
    args = parser.parse_args()
    if args.command == "record": record(args)
    elif args.command == "install": install(args)
    elif args.command == "publish": publish(args)
    else: return test(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
