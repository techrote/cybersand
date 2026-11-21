#!/usr/bin/env python3
"""Bounded exact-source Batch Lab qualification using the existing Godot runner.

Real native execution is separate from pure metric/HTTP protocol fixtures.
No model endpoint, credential or paid request is supplied by this campaign.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
from run_workbench_qualification import Runner, verify_package


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def identity(project: Path) -> dict:
    names = ["scripts/shared_workbench.gd", "scripts/simulation_worker.gd",
             "scripts/art_batch_plan.gd", "scripts/art_batch_executor.gd",
             "scripts/art_provider.gd", "scripts/art_traffic_archive.gd"]
    for directory in ("scripts/batch_lab", "batch_lab"):
        names.extend(p.relative_to(project).as_posix() for p in (project / directory).rglob("*")
                     if p.is_file() and p.suffix in {".gd", ".json", ".txt"})
    names.extend(p.relative_to(project).as_posix() for p in (project / "tests").glob("test_batch_lab*.gd"))
    native = "cybersand_native.windows.x86_64.dll" if sys.platform == "win32" else "libcybersand_native.linux.x86_64.so"
    names.append("addons/cybersand_native/bin/" + native)
    return {name: sha(project / name) for name in sorted(names)}


def material_completion(log: Path) -> dict:
    """The accepted catalogue uses a comma, unlike other shared-runner markers."""
    matches = re.findall(r"^MATERIAL_LAB_CATALOGUE: (\d+) assertions, (\d+) failures(?:;.*)?$",
                         log.read_text(encoding="utf-8"), flags=re.MULTILINE)
    if not matches or int(matches[-1][0]) < 1 or int(matches[-1][1]) != 0:
        raise RuntimeError("Materials Lab catalogue did not finish with positive assertions and zero failures")
    return {"checks": int(matches[-1][0]), "failures": 0}


def validate_project(project: Path, package: Path | None, allow_dirty: bool) -> None:
    expected = (package / "godot" if package else ROOT / "godot").resolve()
    if project.resolve() != expected and (package or not allow_dirty):
        raise ValueError("Qualification project must be the exact source checkout or verified package/godot")


def launch_workbench(runner: Runner, project: Path, graphical: bool) -> None:
    command = [str(runner.args.godot.resolve()), "--audio-driver", "Dummy", "--max-fps", "60",
               "--path", str(project), "--quit-after", "30"]
    if graphical:
        command += ["--rendering-method", "gl_compatibility"]
        command += (["--rendering-driver", "opengl3_angle"] if sys.platform == "win32"
                    else ["--display-driver", "x11"])
    else:
        command += ["--headless"]
    command += ["--", "--workbench"]

    def validate() -> dict:
        text = (runner.evidence / "actual-workbench-launch.log").read_text(encoding="utf-8")
        if "SHARED_WORKBENCH_LAUNCH_READY" not in text.splitlines():
            raise RuntimeError("The shipped --workbench launch route was not entered")
        return {"launch_route": "--workbench", "checks": 1, "failures": 0}

    runner.execute("actual-workbench-launch", command, validate=validate, timeout=120)


def regression_cases(runner: Runner, project: Path) -> None:
    # Existing native protocols and shared editor/history semantics. The new
    # feature owns no C++/physics/provider-transport mutation and needs no duplicate
    # all-Gentek research or provider-quality campaign.
    cases = [
        ("art-keyless", "test_art_provider", "ART_PROVIDER_KEYLESS"),
        ("art-archive-integrity", "test_art_traffic_integrity", "ART_TRAFFIC_INTEGRITY"),
        ("art-lazy-history", "test_art_lazy_traffic", "ART_LAZY_TRAFFIC"),
        ("art-history-identity", "test_art_history_receipt_identity", "ART_HISTORY_RECEIPT_IDENTITY_RESULT"),
        ("art-native", "test_art_batch_native", "ART_STAGE1_RESULT"),
        ("edit-ordering", "test_workbench_edit_ordering", "EDIT_ORDER_RESULT"),
        ("manual-shapes", "test_paint_editor_shapes", "PAINT_EDITOR_SHAPES"),
        ("manual-recovery", "test_paint_editor_recovery", "PAINT_RECOVERY"),
        ("actors", "test_workbench_actor_composition_native", "Workbench actor composition native:"),
        ("equipment", "test_workbench_liquid_equipment", "LIQUID_EQUIPMENT"),
        ("worldgen", "test_worldgen_workbench", "WORLDGEN_WORKBENCH:"),
    ]
    for label, script, marker in cases:
        # These archive adversaries deliberately damage profiles and segments.
        # Give each its own test profile; the Batch provider -> mounted editor
        # sequence above deliberately shares a profile to detect interference.
        environment = None
        if label in {"art-archive-integrity", "art-lazy-history", "art-history-identity"}:
            profile = str(runner.evidence / "archive-fixtures" / label)
            environment = {"XDG_DATA_HOME": profile, "APPDATA": profile}
        runner.godot(project, "regression-" + label, script, marker, env=environment)
    runner.execute("regression-materials", [str(runner.args.godot.resolve()), "--audio-driver", "Dummy",
                   "--headless", "--path", str(project), "--script", "res://tests/test_material_lab_catalogue.gd"],
                   validate=lambda: material_completion(runner.evidence / "regression-materials.log"))
    for workers in (1, 4):
        runner.godot(project, f"manual-native-{workers}", "test_paint_editor_native", "PAINT_EDITOR_NATIVE",
                     env={"PAINT_TEST_WORKERS": str(workers)})
        runner.godot(project, f"shared-undo-{workers}", "test_art_undo", "ART_UNDO_RESULT",
                     env={"ART_UNDO_WORKERS": str(workers)})
    for phase in ("author", "reopen"):
        runner.godot(project, f"ordinary-history-{phase}", "test_paint_editor_history", "PAINT_EDITOR_HISTORY",
                     env={"CYBERSAND_PAINT_HISTORY_REOPEN": "1" if phase == "reopen" else "0"})


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--regressions", action="store_true")
    parser.add_argument("--allow-dirty", action="store_true", help="local development only; recorded as unqualified source")
    args = parser.parse_args()
    args.evidence = args.evidence.resolve()
    project = args.project.resolve()
    validate_project(project, args.package.resolve() if args.package else None, args.allow_dirty)
    args.evidence.mkdir(parents=True, exist_ok=True)
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    if not args.allow_dirty:
        subprocess.run(["git", "diff", "--exit-code", "HEAD", "--", "godot/scripts", "godot/tests", "godot/batch_lab"],
                       cwd=ROOT, check=True)
    manifest = verify_package(args.package.resolve()) if args.package else None
    if manifest and manifest["source_commit"] != revision:
        raise ValueError("Delivered package and qualification commit differ")
    before = identity(project)
    runner = Runner(args)
    runner.env["CYBERSAND_SOURCE_REVISION"] = revision
    started = time.monotonic()
    report = {"schema": "world-steer-batch-qualification-v1", "source_commit": revision,
              "source_files_sha256": before, "development_dirty_allowed": args.allow_dirty,
              "graphical": args.graphical, "packaged": bool(manifest), "platform": sys.platform,
              "actual_model_calls": 0, "physical_owner_acceptance": "pending", "status": "running"}
    try:
        runner.godot(project, "import")
        launch_workbench(runner, project, args.graphical)
        runner.godot(project, "experiment-contracts", "test_batch_lab_experiments",
                     "Batch Lab experiment/metric script contracts:")
        runner.execute("independent-metric-controls", [sys.executable, str(ROOT / "tools/batch_lab/test_evaluate.py")])
        runner.godot(project, "provider-loopback-protocol", "test_batch_lab_provider", "BATCH_PROVIDER_RESULT",
                     env={"BATCH_LAB_EVIDENCE_DIR": str(args.evidence / "provider-protocol")})
        runner.godot(project, "independent-security", "test_batch_lab_security", "BATCH_SECURITY_RESULT",
                     env={"BATCH_LAB_EVIDENCE_DIR": str(args.evidence / "security")})
        namespace_profile = str(args.evidence / "archive-fixtures" / "batch-namespace")
        runner.godot(project, "independent-archive-namespace", "test_batch_lab_namespace", "BATCH_NAMESPACE_CONTRACT",
                     env={"BATCH_LAB_EVIDENCE_DIR": str(args.evidence / "namespace"),
                          "XDG_DATA_HOME": namespace_profile, "APPDATA": namespace_profile})
        runner.godot(project, "native-failure-recovery", "test_batch_lab_failure_recovery", "BATCH_RECOVERY_RESULT",
                     env={"BATCH_LAB_EVIDENCE_DIR": str(args.evidence / "failure-recovery")})
        runner.godot(project, "independent-ui-lifecycle", "test_batch_lab_ui_lifecycle", "BATCH_UI_LIFECYCLE",
                     env={"BATCH_LAB_EVIDENCE_DIR": str(args.evidence / "ui-lifecycle")})
        native = args.evidence / "native"
        runner.godot(project, "batch-native", "test_batch_lab_native", "BATCH_NATIVE_RESULT",
                     env={"BATCH_LAB_EVIDENCE_DIR": str(native)})
        runner.godot(project, "batch-fresh-reopen", "test_batch_lab_reopen", "BATCH_REOPEN_RESULT",
                     env={"BATCH_LAB_EVIDENCE_DIR": str(args.evidence / "reopen"),
                          "BATCH_LAB_SESSION_PATH": str(native / "native-session.json")})
        runner.execute("independent-native-reduction", [sys.executable, str(ROOT / "tools/batch_lab/evaluate.py"),
                       str(native / "native-session.json"), "--output", str(args.evidence / "analysis.json"),
                       "--blind-dir", str(args.evidence / "blind-review")])
        runner.godot(project, "mounted-workbench", "test_batch_lab_workbench", "BATCH_LAB_WORKBENCH",
                     graphical=args.graphical, env={"BATCH_LAB_EVIDENCE_DIR": str(args.evidence / "workbench")},
                     max_fps=60 if args.graphical else None)
        if args.graphical:
            runner.godot(project, "batch-ui", "test_batch_lab_ui", "BATCH_LAB_UI_RESULT", graphical=True,
                         env={"BATCH_LAB_EVIDENCE_DIR": str(args.evidence / "ui")}, max_fps=60)
        if args.regressions:
            regression_cases(runner, project)
        if identity(project) != before:
            raise ValueError("Executed application source or native bytes changed during qualification")
        report["status"] = "passed"
        return 0
    except Exception as error:
        report.update(status="failed", error=str(error))
        raise
    finally:
        report["elapsed_seconds"] = round(time.monotonic() - started, 3)
        report["results"] = runner.results
        (args.evidence / "qualification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
