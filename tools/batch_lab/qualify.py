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


def identity(project: Path, collaborative: bool = False) -> dict:
    names = ["scripts/shared_workbench.gd", "scripts/simulation_worker.gd",
             "scripts/art_batch_plan.gd", "scripts/art_batch_executor.gd",
             "scripts/art_provider.gd", "scripts/art_traffic_archive.gd"]
    for directory in ("scripts/batch_lab", "batch_lab", "data/batch_lab"):
        names.extend(p.relative_to(project).as_posix() for p in (project / directory).rglob("*")
                     if p.is_file() and p.suffix in {".gd", ".json", ".txt"})
    for pattern in ("test_batch_lab*.gd", "test_native_module*.gd", "test_architectur*.gd", "test_native_detail*.gd"):
        names.extend(p.relative_to(project).as_posix() for p in (project / "tests").glob(pattern))
    if collaborative:
        # Bind accepted actor ownership, render helpers and the actual Rapier
        # runtime in addition to the architectural application source.
        names.extend(p.relative_to(project).as_posix() for p in (project / "scripts").glob("*.gd"))
        names.extend(p.relative_to(project).as_posix() for p in (project / "tests/support").rglob("*")
                     if p.is_file() and p.suffix in {".gd", ".json"})
        names.extend(p.relative_to(project).as_posix() for p in (project / "shaders").rglob("*")
                     if p.is_file() and p.suffix in {".gdshader", ".gdshaderinc"})
        names += ["project.godot", "main.tscn", "tools/world_art_render_rig.gd"]
        rapier = ("libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if sys.platform == "win32"
                  else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")
        names.append("addons/godot-rapier2d/bin/" + rapier)
    native = "cybersand_native.windows.x86_64.dll" if sys.platform == "win32" else "libcybersand_native.linux.x86_64.so"
    names.append("addons/cybersand_native/bin/" + native)
    return {name: sha(project / name) for name in sorted(set(names))}


# Development fixture switches cannot enter a canonical source/extracted run.
# Even an explicit "0" must be removed: final runtime scope is unambiguous.
COLLABORATIVE_FORBIDDEN_ENV = (
    "ARCHITECTURE_DEVELOPMENT_CORE_CAPACITY", "ARCHITECTURE_GAMEPLAY_CROP",
    "ARCHITECTURE_GAMEPLAY_CONTROL", "ARCHITECTURE_GAMEPLAY_FAMILY",
    "ARCHITECTURE_FLAGSHIP_FAMILY", "ARCHITECTURE_UI_ONLY",
    "NATIVE_DETAIL_PREFLIGHT_ONLY", "NATIVE_CATALOGUE_RENDER_VALIDATE_ONLY",
    "NATIVE_CATALOGUE_RENDER_ALLOW_ARCHIVAL", "CYBERSAND_NATIVE_SOURCE_REVISION",
    "M67_COMPARISON_BASELINE_DIR", "NATIVE_MODULE_MODE",
)


def validate_collaborative_environment(environment: dict) -> None:
    active = [name for name in COLLABORATIVE_FORBIDDEN_ENV if environment.get(name)]
    if active:
        raise ValueError("Canonical collaborative qualification refuses development/subset/archive overrides: " + ", ".join(active))


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
        ("art-lazy-history", "test_art_lazy_traffic", "ART_LAZY_RESULT"),
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


def architecture_cases(runner: Runner, project: Path, graphical: bool) -> None:
    """M3–M5 consumes the original runner, native owner and package custody.

    Every selected case is required. Missing scripts are failures, never a
    permissive feature-detection skip. A fresh process performs each reopen.
    """
    evidence = runner.evidence / "architecture"
    evidence.mkdir(parents=True, exist_ok=True)
    module_env = {"NATIVE_MODULE_EVIDENCE_DIR": str(evidence / "modules"),
                  "NATIVE_MODULE_LIBRARY_PATH": str(evidence / "modules" / "library.json")}
    runner.godot(project, "native-module-author", "test_native_module", "NATIVE_MODULE_RESULT", env=module_env)
    runner.godot(project, "native-module-fresh-reopen", "test_native_module", "NATIVE_MODULE_RESULT",
                 env=dict(module_env, NATIVE_MODULE_MODE="reopen"))
    runner.godot(project, "native-module-starter-parts", "test_native_module_examples", "NATIVE_PARTS_RESULT", env=module_env)
    runner.godot(project, "native-module-observation-custody", "test_batch_lab_native_custody", "BATCH_NATIVE_CUSTODY_RESULT")
    runner.execute("architecture-retrieval", [str(runner.args.godot.resolve()), "--headless", "--audio-driver", "Dummy",
                   "--path", str(project.resolve()), "--script", "res://tests/test_architectural_retrieval.gd",
                   "--", "--output=" + str(evidence / "retrieval-results.json")], marker="Architectural retrieval:")
    runner.execute("architecture-independent-metrics", [sys.executable, str(ROOT / "tools/batch_lab/test_architecture_evaluation.py")])
    stage_env = {"ARCHITECTURE_EVIDENCE_DIR": str(evidence / "stages")}
    runner.godot(project, "architecture-context-detail", "test_architecture_context_detail",
                 "ARCHITECTURE_CONTEXT_DETAIL:", env=stage_env)
    runner.godot(project, "architecture-stage-plan", "test_architecture_stage_plan",
                 "ARCHITECTURE_STAGE_PLAN:", env=stage_env)
    runner.godot(project, "architecture-module-contracts", "test_architecture_stage_modules",
                 "ARCHITECTURE_STAGE_MODULE_RESULT", env=stage_env)
    runner.godot(project, "architecture-stage-native", "test_architecture_stage_native",
                 "ARCHITECTURE_STAGE_NATIVE:", env=stage_env)
    runner.godot(project, "architecture-stage-fresh-reopen", "test_architecture_stage_reopen",
                 "ARCHITECTURE_STAGE_REOPEN:", env=stage_env)
    runner.godot(project, "architecture-module-compositions", "test_architecture_module_compositions",
                 "ARCHITECTURE_MODULE_COMPOSITIONS_RESULT", env={"ARCHITECTURE_MODULE_COMPOSITIONS_DIR": str(evidence / "stages")})
    comparison = evidence / "comparison"
    runner.godot(project, "architecture-native-comparison", "test_architecture_comparison", "ARCHITECTURE_COMPARISON_RESULT",
                 env={"ARCHITECTURE_COMPARISON_DIR": str(comparison)})
    runner.execute("architecture-native-independent-reduction", [sys.executable, str(ROOT / "tools/batch_lab/evaluate_architecture.py"),
                   str(comparison / "cases.json"), "--registration", str(project / "data/batch_lab/architecture_experiment_registration.v1.json"),
                   "--output", str(comparison / "analysis.json")])
    if graphical:
        runner.godot(project, "architecture-stage-render", "test_architecture_stage_render",
                     "ARCHITECTURE_STAGE_RENDER:", graphical=True, env=stage_env, max_fps=60)
    else:
        runner.godot(project, "architecture-stage-ui", "test_architecture_stage_render",
                     "ARCHITECTURE_STAGE_UI:", env=dict(stage_env, ARCHITECTURE_UI_ONLY="1"))


COLLABORATIVE_CONTRACTS = (
    ("module-v2", "test_native_module_v2", "NATIVE_MODULE_V2_RESULT"),
    ("catalogue-contracts", "test_native_module_catalogue", "NATIVE_CATALOGUE_RESULT"),
    ("detail-jobs", "test_native_detail_jobs", "NATIVE_DETAIL_JOBS_RESULT"),
    ("detail-contracts", "test_native_detail_contracts", "NATIVE_DETAIL_CONTRACTS_RESULT"),
    ("catalogue-wear", "test_native_detail_catalogue_wear", "NATIVE_DETAIL_CATALOGUE_WEAR_RESULT"),
    ("connections", "test_architecture_connections", "ARCHITECTURE_CONNECTIONS:"),
    ("session-views", "test_architecture_session_views", "ARCHITECTURE_SESSION_VIEW_RESULT"),
    ("module-controls", "test_architecture_controls", "ARCHITECTURE_CONTROLS:"),
    ("detail-controls", "test_architecture_detail_controls", "ARCHITECTURE_DETAIL_CONTROLS:"),
    ("campaign", "test_architecture_campaign", "ARCHITECTURE_CAMPAIGN:"),
    ("planning-adapter", "test_architecture_planning_adapter", "ARCHITECTURE_PLANNING_ADAPTER:"),
    ("proposal-bridge", "test_architecture_proposal_bridge", "ARCHITECTURE_PROPOSAL_BRIDGE:"),
    ("goldmaps-consumer", "test_goldmaps_consumer", "GOLDMAPS_READ_ONLY_CONSUMER:"),
    ("workflow", "test_architecture_workflow", "ARCHITECTURE_WORKFLOW:"),
    ("workflow-controls", "test_architecture_workflow_controls", "ARCHITECTURE_WORKFLOW_CONTROLS:"),
    ("compositional-retrieval", "test_architecture_compositional_retrieval", "ARCHITECTURE_COMPOSITIONAL_RETRIEVAL:"),
    ("comparison-recipes", "test_architecture_comparison_recipes", "M67_COMPARISON_RECIPES:"),
    ("frozen-comparison-catalogue", "test_architecture_comparison_catalogue", "M67_FROZEN_COMPARISON_CATALOGUE_RESULT"),
    ("delegation", "test_architecture_delegation", "ARCHITECTURE_DELEGATION_RESULT"),
    ("flagship-plans", "test_architecture_flagships", "ARCHITECTURE_FLAGSHIP_PLANS:"),
)


def collaborative_cases(runner: Runner, project: Path, revision: str, native_sha256: str) -> Path:
    """Required M6/M7 gates with serial native owners and separate reopen processes.

    A registered refused comparison arm remains in its denominator. Independent
    reducers judge native custody and measured constraints, not aesthetic quality.
    """
    evidence = runner.evidence / "architecture/collaborative"
    evidence.mkdir(parents=True, exist_ok=True)
    for label, script, marker in COLLABORATIVE_CONTRACTS:
        runner.godot(project, "collaborative-" + label, script, marker, max_fps=60)
    for label, script in (
            ("detail-reducer-adversaries", "test_detail_evaluation.py"),
            ("comparison-reducer-adversaries", "m67/test_reduce_comparison.py"),
            ("qualification-adversaries", "test_collaborative_qualification.py")):
        runner.execute("collaborative-" + label, [sys.executable, str(ROOT / "tools/batch_lab" / script)])

    for label, pattern in (("hierarchy-reducer-adversaries", "test_verify_hierarchy_native.py"),
                           ("overview-transport-adversaries", "test_architecture_overview_transport.py")):
        runner.execute("collaborative-" + label, [sys.executable, "-m", "unittest", "discover", "-s",
                       str(ROOT / "tools/batch_lab"), "-p", pattern])

    catalogue = evidence / "catalogue"
    catalogue_env = {"NATIVE_CATALOGUE_EVIDENCE_DIR": str(catalogue),
                     "NATIVE_CATALOGUE_RENDER_DIR": str(catalogue / "rendered")}
    runner.godot(project, "collaborative-catalogue-native", "test_native_module_catalogue_native",
                 "NATIVE_CATALOGUE_NATIVE_RESULT", env=catalogue_env, max_fps=60)
    runner.godot(project, "collaborative-catalogue-render", "test_native_module_catalogue_render",
                 "NATIVE_CATALOGUE_RENDER_RESULT", graphical=True, env=catalogue_env, max_fps=60)

    detail = evidence / "detail"
    runner.godot(project, "collaborative-detail-native", "test_native_detail_jobs_native",
                 "NATIVE_DETAIL_NATIVE_RESULT", env={"NATIVE_DETAIL_EVIDENCE_DIR": str(detail)}, max_fps=60)
    runner.execute("collaborative-detail-independent-reduction", [sys.executable,
                   str(ROOT / "tools/batch_lab/evaluate_detail_jobs.py"), str(detail / "cases.json"),
                   "--registration", str(project / "data/batch_lab/m67/detail-experiment.v1.json"),
                   "--output", str(detail / "analysis.json")])

    comparison = evidence / "comparison"
    runner.godot(project, "collaborative-composition-native", "test_architecture_composition_comparison",
                 "M67_NATIVE_COMPOSITION_COMPARISON_RESULT", env={"M67_COMPARISON_EVIDENCE_DIR": str(comparison)}, max_fps=60)
    runner.execute("collaborative-composition-independent-reduction", [sys.executable,
                   str(ROOT / "tools/batch_lab/m67/reduce_comparison.py"), str(comparison / "cases.json"),
                   "--output", str(comparison / "analysis.json")])

    flagships = evidence / "flagships"
    flagship_env = {"ARCHITECTURE_FLAGSHIP_DIR": str(flagships)}
    runner.godot(project, "collaborative-flagships-native", "test_architecture_flagships_native",
                 "ARCHITECTURE_FLAGSHIPS_NATIVE:", env=flagship_env, max_fps=60)
    runner.godot(project, "collaborative-flagships-render", "test_architecture_flagships_render",
                 "ARCHITECTURE_FLAGSHIPS_RENDER:", graphical=True, env=flagship_env, max_fps=60)
    transport = runner.execute("collaborative-overview-transport", [sys.executable,
                   str(ROOT / "tools/batch_lab/emit_architecture_overviews.py"), str(flagships), "--source", revision],
                   marker="ARCHITECTURE_OVERVIEW_TRANSPORT")
    print(transport, end="", flush=True)
    actor_env = {"ARCHITECTURE_GAMEPLAY_EVIDENCE_DIR": str(evidence / "gameplay"),
                 "ARCHITECTURE_GAMEPLAY_MANIFEST": str(flagships / "flagships-native.json")}
    runner.godot(project, "collaborative-full-world-gameplay", "test_architecture_gameplay",
                 "ARCHITECTURE_GAMEPLAY:", graphical=True, env=actor_env, max_fps=60)
    runner.godot(project, "collaborative-gameplay-fresh-reopen", "test_architecture_gameplay_reopen",
                 "ARCHITECTURE_GAMEPLAY_REOPEN:", graphical=True, env=actor_env, max_fps=60)
    runner.godot(project, "collaborative-native-ui", "test_architecture_collaborative_ui",
                 "ARCHITECTURE_COLLABORATIVE_UI:", graphical=True, max_fps=60,
                 env={"ARCHITECTURE_MODULE_CATALOGUE_DIR": str(catalogue),
                      "ARCHITECTURE_COLLABORATIVE_UI_DIR": str(evidence / "ui")})

    hierarchy_env = {"ARCHITECTURE_HIERARCHY_DIR": str(evidence / "hierarchy")}
    runner.godot(project, "collaborative-hierarchy-native", "test_architecture_hierarchy_native",
                 "ARCHITECTURE_HIERARCHY_NATIVE:", env=hierarchy_env, max_fps=60)
    runner.execute("collaborative-hierarchy-independent-reduction", [sys.executable,
                   str(ROOT / "tools/batch_lab/verify_hierarchy_native.py"), str(evidence / "hierarchy/hierarchy-native.json"),
                   "--expected-source", revision, "--require-default-capacity",
                   "--output", str(evidence / "hierarchy/independent-hierarchy-verification.json")])
    runner.godot(project, "collaborative-hierarchy-fresh-reopen", "test_architecture_hierarchy_reopen",
                 "ARCHITECTURE_HIERARCHY_REOPEN:", env=hierarchy_env, max_fps=60)
    runner.godot(project, "collaborative-hierarchy-render", "test_architecture_hierarchy_render",
                 "ARCHITECTURE_HIERARCHY_RENDER:", graphical=True, env=hierarchy_env, max_fps=60)
    custody = evidence / "custody.json"
    runner.execute("collaborative-evidence-custody", [sys.executable,
                   str(ROOT / "tools/batch_lab/verify_collaborative_evidence.py"), str(evidence),
                   "--source", revision, "--native-sha256", native_sha256,
                   "--output", str(custody)], marker="COLLABORATIVE_EVIDENCE_CUSTODY")
    return custody


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--regressions", action="store_true")
    parser.add_argument("--architecture", action="store_true", help="Require the M3–M5 module/stage successor gates")
    parser.add_argument("--collaborative", action="store_true", help="Require full M6/M7 graphical/default-runtime gates, including M3–M5")
    parser.add_argument("--allow-dirty", action="store_true", help="local development only; recorded as unqualified source")
    args = parser.parse_args()
    if args.collaborative:
        if not args.graphical or args.allow_dirty:
            parser.error("--collaborative requires --graphical and clean committed source")
        validate_collaborative_environment(os.environ)
        args.architecture = True
    args.evidence = args.evidence.resolve()
    project = args.project.resolve()
    validate_project(project, args.package.resolve() if args.package else None, args.allow_dirty)
    args.evidence.mkdir(parents=True, exist_ok=True)
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    if not args.allow_dirty:
        subprocess.run(["git", "diff", "--exit-code", "HEAD", "--", "godot/scripts", "godot/tests", "godot/batch_lab", "godot/data/batch_lab",
                        "godot/project.godot", "godot/main.tscn", "godot/shaders", "godot/tools",
                        "tools/batch_lab", ".github/workflows/world-steer-batch-qualification.yml"],
                       cwd=ROOT, check=True)
    manifest = verify_package(args.package.resolve()) if args.package else None
    if manifest and manifest["source_commit"] != revision:
        raise ValueError("Delivered package and qualification commit differ")
    before = identity(project, args.collaborative)
    engine_sha256 = sha(args.godot.resolve())
    runner = Runner(args)
    runner.env["CYBERSAND_SOURCE_REVISION"] = revision
    started = time.monotonic()
    report = {"schema": "world-steer-batch-qualification-v1", "source_commit": revision,
              "source_files_sha256": before, "development_dirty_allowed": args.allow_dirty,
              "graphical": args.graphical, "packaged": bool(manifest), "platform": sys.platform,
              "architecture_m3_m5": args.architecture,
              "collaborative_m6_m7": args.collaborative, "godot_executable_sha256": engine_sha256,
              "actual_model_calls": 0, "physical_owner_acceptance": "pending", "status": "running"}
    try:
        if args.collaborative and args.package:
            launcher = args.evidence / "architecture/collaborative/launcher"
            runner.execute("collaborative-pristine-delivered-cmd", [sys.executable,
                           str(ROOT / "tools/batch_lab/verify_windows_launcher.py"), "--package", str(args.package.resolve()),
                           "--evidence", str(launcher), "--source", revision],
                           marker="WINDOWS_EVALUATOR_LAUNCHER_RESULT", timeout=210)
            report["delivered_launcher"] = {"path": (launcher / "launcher.json").relative_to(args.evidence).as_posix(),
                                           "sha256": sha(launcher / "launcher.json")}
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
        if args.architecture:
            architecture_cases(runner, project, args.graphical)
        if args.collaborative:
            native_name = ("cybersand_native.windows.x86_64.dll" if sys.platform == "win32"
                           else "libcybersand_native.linux.x86_64.so")
            custody = collaborative_cases(runner, project, revision, before["addons/cybersand_native/bin/" + native_name])
            report["collaborative_evidence"] = {"path": custody.relative_to(args.evidence).as_posix(), "sha256": sha(custody),
                                               "native_active_core_capacity": 1024, "cropped_route_worlds": False}
        if args.regressions:
            regression_cases(runner, project)
        if identity(project, args.collaborative) != before or sha(args.godot.resolve()) != engine_sha256:
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
