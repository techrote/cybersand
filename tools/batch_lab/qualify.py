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
             "scripts/art_provider.gd"]
    for directory in ("scripts/batch_lab", "batch_lab"):
        names.extend(p.relative_to(project).as_posix() for p in (project / directory).rglob("*")
                     if p.is_file() and p.suffix in {".gd", ".json", ".txt"})
    names.extend(p.relative_to(project).as_posix() for p in (project / "tests").glob("test_batch_lab*.gd"))
    native = "cybersand_native.windows.x86_64.dll" if sys.platform == "win32" else "libcybersand_native.linux.x86_64.so"
    names.append("addons/cybersand_native/bin/" + native)
    return {name: sha(project / name) for name in sorted(names)}


def regression_cases(runner: Runner, project: Path) -> None:
    # Existing native protocols and shared editor/history semantics. The new
    # feature owns no C++/physics/provider-stack mutation and needs no duplicate
    # all-Gentek research or provider-quality campaign.
    cases = [
        ("art-keyless", "test_art_provider", "ART_PROVIDER_KEYLESS"),
        ("art-native", "test_art_batch_native", "ART_STAGE1_RESULT"),
        ("edit-ordering", "test_workbench_edit_ordering", "EDIT_ORDER_RESULT"),
        ("manual-shapes", "test_paint_editor_shapes", "PAINT_EDITOR_SHAPES"),
        ("manual-recovery", "test_paint_editor_recovery", "PAINT_RECOVERY"),
        ("materials", "test_material_lab_catalogue", "MATERIAL_LAB_CATALOGUE:"),
        ("actors", "test_workbench_actor_composition_native", "Workbench actor composition native:"),
        ("equipment", "test_workbench_liquid_equipment", "LIQUID_EQUIPMENT"),
        ("worldgen", "test_worldgen_workbench", "WORLDGEN_WORKBENCH:"),
    ]
    for label, script, marker in cases:
        runner.godot(project, "regression-" + label, script, marker)
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
        runner.godot(project, "experiment-contracts", "test_batch_lab_experiments",
                     "Batch Lab experiment/metric script contracts:")
        runner.execute("independent-metric-controls", [sys.executable, str(ROOT / "tools/batch_lab/test_evaluate.py")])
        runner.godot(project, "provider-loopback-protocol", "test_batch_lab_provider", "BATCH_PROVIDER_RESULT",
                     env={"BATCH_LAB_EVIDENCE_DIR": str(args.evidence / "provider-protocol")})
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
