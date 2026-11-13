#!/usr/bin/env python3
"""Private MAT-AUTH + Workbench qualification profile and four-path publisher.

The original Materials Lab and Workbench owners remain unchanged. This profile
adds their combined execution to the existing source/lease/receipt boundaries.
"""
from __future__ import annotations

import argparse
from importlib.util import module_from_spec, spec_from_file_location
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

_spec = spec_from_file_location(
    "_mat_workbench_private_lab_publication", Path(__file__).with_name("materials_lab_runtime_publication.py"))
lab = module_from_spec(_spec)
_spec.loader.exec_module(lab)
engine = lab.engine
_former_workflow, _former_request = engine.WORKFLOW, engine.REQUEST
engine.BRANCH = "codex/mat-auth-workbench-integration-20261112"
engine.WORKFLOW = ".github/workflows/mat-workbench-runtime-publication.yml"
engine.REQUEST = "tools/ci/mat_workbench_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-12-mat-auth-workbench-integration.md"
engine.BUNDLE_PREFIX = "mat-workbench-runtime-attempt-" + os.environ.get("GITHUB_RUN_ATTEMPT", "1")
engine.REQUEST_VALUE = {
    "schema": "mat-workbench-runtime-publish-request-v1",
    "family": "materials-lab-and-integrated-workbench",
    "variant": "shared-manual-agent-history-and-isolated-material-authoring",
    "scope": "source-matched-linux-windows-lab-workbench-and-combined-authoring",
    "intent": "publish-source-matched-runtimes",
}
engine.BUILD_EXACT = (set(engine.BUILD_EXACT) - {_former_workflow, _former_request}) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/mat_workbench_runtime_publication.py",
    "tools/ci/test_mat_workbench_runtime_publication.py",
    "tools/package_mat_workbench_candidate.py",
    "tools/ci/run_workbench_qualification.py", "tools/ci/native_candidate_identity.py",
    "tools/package_explore001_candidate.py", "tools/ci/test_workbench_profile_packaging.py",
    "tools/ci/stage_windows_vc_runtime.ps1", "tools/ci/check_windows_package_modules.ps1",
    "tools/test_art_provider_transport.py", "tools/test_art_final_graphical.py",
}
_verify_lab_bundle = lab.verify_materials_bundle
# Engine.get_version_info().string uses the display spelling; --version has
# engine.GODOT_VERSION. The original publisher also authenticates archive bytes.
GODOT_DISPLAY_VERSION = "4.7-stable (official)"
# Windows diagnostic 43355051094: the same 5 FPS comparison exhausted its
# unchanged deadline at both worker counts; 1 FPS completed both author/reopen
# pairs. Bound only this combined capture; inherited Lab captures retain 15 FPS
# and product frame rates, native work, assertions and deadlines are unchanged.
COMBINED_GRAPHICAL_MAX_FPS = 1


def __getattr__(name):
    return getattr(lab, name)


def regression_labels() -> list[str]:
    labels = ["regression-import", "art-keyless", "art-panel-ui", "art-stored-material", "art-deferred-manual", "art-native",
              "art-native-render", "art-http-fixtures-graphical", "art-final-graphical-mocked",
              "native-edit-ordering", "combined-deferred-paint", "paint-shapes", "paint-executor", "paint-recovery"]
    labels += [f"{name}-{workers}" for workers in (1, 4) for name in ("paint-native", "agent-undo")]
    labels += [f"paint-history-{phase}" for phase in ("author", "reopen")]
    labels += [f"paint-{family}-{phase}" for family in ("workbench", "generated_workbench") for phase in ("author", "reopen")]
    labels += ["existing-workbench-input"]
    labels += [f"existing-{family}-{workers}" for workers in (1, 4) for family in ("liquid_equipment", "reservoir_lab")]
    labels += ["existing-worldgen-planes", "existing-worldgen-workbench", "existing-canvas-author", "existing-canvas-reopen"]
    labels += [f"source-combined-workers-{workers}-{phase}" for workers in (1, 4) for phase in ("author", "reopen")]
    return labels


def installed_labels() -> list[str]:
    return ["complete-import", "complete-discovery", "installed-author", "installed-reopen",
            *[f"installed-combined-1024-workers-{workers}-{phase}" for workers in (1, 4) for phase in ("author", "reopen")],
            "resource-only-import", "resource-only-discovery", "missing-profiles-import", "missing-profiles-discovery"]


def integration_labels() -> list[str]:
    return [f"mat-workbench-workers-{workers}-{phase}" for workers in (1, 4) for phase in ("author", "reopen")]


def verify_results(path: Path, expected: list[str]) -> list:
    records = json.loads(path.read_text(encoding="utf-8"))
    engine.require(isinstance(records, list) and [item.get("label") for item in records] == expected,
                   "Incomplete or reordered Workbench coverage: " + str(path))
    for item in records:
        engine.require(item.get("status") == "passed" and item.get("exit_code") == 0,
                       "Unsuccessful Workbench case: " + item.get("label", "unknown"))
        log = path.parent / (item["label"] + ".log")
        engine.require(log.is_file() and log.stat().st_size > 0, "Original Workbench log is missing")
    return records


def combined_lab_workbench(runner, project: Path) -> None:
    # Lab deliberately refuses backend response paths inside source custody.
    # Keep each author/reopen pair on one external userdata root, then retain
    # its original saved files as evidence after both processes have exited.
    with tempfile.TemporaryDirectory(prefix="mat-workbench-userdata-") as temporary:
        external = Path(temporary).resolve()
        engine.require(not external.is_relative_to(project.resolve().parent),
                       "Combined Lab userdata must be outside source custody")
        for workers in (1, 4):
            userdata = external / f"workers-{workers}"
            try:
                for phase in ("author", "reopen"):
                    label = f"mat-workbench-workers-{workers}-{phase}"
                    runner.godot(project, label, "test_material_lab_workbench_integration", "MAT_WB_INTEGRATION",
                                 graphical=True, max_fps=COMBINED_GRAPHICAL_MAX_FPS, env={"ART_UNDO_WORKERS": str(workers),
                                 "MAT_WB_REOPEN": "1" if phase == "reopen" else "0",
                                 "MAT_WB_SCREENSHOTS": str(runner.evidence / (label + "-frames")),
                                 "XDG_DATA_HOME": str(userdata), "APPDATA": str(userdata)})
                    verify_combined_case(runner.evidence, label, project, workers, phase)
            finally:
                if userdata.is_dir():
                    shutil.copytree(userdata, runner.evidence / f"workers-{workers}-userdata")


def verify_combined_case(directory: Path, label: str, project: Path, workers: int, phase: str,
                         *, platform: str | None = None, native_sha: str | None = None) -> dict:
    import run_workbench_qualification as wb
    text = (directory / (label + ".log")).read_text(encoding="utf-8")
    receipt = wb.completion(text, "MAT_WB_EVIDENCE")
    engine.require(receipt.get("complete") is True and receipt.get("workers") == workers and
                   receipt.get("phase") == phase and receipt.get("errors") == [], "Combined authoring receipt is incomplete")
    identity = receipt.get("source_identity", {})
    if platform is None:
        platform = "windows" if sys.platform == "win32" else "linux"
    expected_os = "Windows" if platform == "windows" else "Linux"
    runtime = project / "addons/cybersand_native/bin" / Path(engine.RUNTIMES[platform]).name
    engine.require(identity.get("os") == expected_os and identity.get("display", "").lower() in
                   ({"windows"} if platform == "windows" else {"x11"}) and identity.get("godot") == GODOT_DISPLAY_VERSION,
                   "Combined authoring did not use the pinned graphical target-OS runtime")
    if native_sha is None:
        native_sha = engine.runner.sha256(runtime)
    engine.require(identity.get("native_sha256") == native_sha, "Combined native runtime changed")
    sources = {"test_sha256": project / "tests/test_material_lab_workbench_integration.gd",
               "history_helper_sha256": project / "tests/test_art_undo.gd"}
    for name in ("simulation_worker.gd", "shared_workbench.gd", "art_batch_executor.gd", "art_batch_panel.gd",
                 "workbench_paint_editor_controller.gd", "workbench_paint_editor_executor.gd",
                 "workbench_paint_editor_history.gd", "workbench_setup.gd", "material_lab_panel.gd",
                 "material_lab_service.gd", "material_lab_catalogue.gd", "material_lab_world_panel.gd"):
        sources[name] = project / "scripts" / name
    engine.require(all(identity.get(name) == engine.runner.sha256(path) for name, path in sources.items()),
                   "Combined test or application scripts differ from the delivered source")
    required = ({"mat-workbench-isolated-comparison-workbench.png", "mat-workbench-isolated-comparison-lab.png",
                 "mat-workbench-saved-workbench.png"} if phase == "author" else {"mat-workbench-reopened-workbench.png"})
    images = directory / (label + "-frames")
    engine.require(all((images / name).is_file() and (images / name).read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
                       for name in required), "Combined authoring is missing actual framebuffer evidence")
    return receipt


def evidence_files(directory: Path) -> dict[str, str]:
    return {p.relative_to(directory).as_posix(): engine.runner.sha256(p)
            for p in sorted((directory / "workbench").rglob("*")) if p.is_file()}


def verify_workbench(directory: Path, platform: str, source: str, native_sha: str) -> dict:
    report = lab.read_json(directory / "workbench.json")
    lab.verify_context(report, source)
    engine.require(report.get("schema") == "mat-workbench-source-qualification-v1" and
                   report.get("platform") == platform and report.get("native_sha256") == native_sha and
                   report.get("status") == "passed" and report.get("completed") is True,
                   "Workbench execution identity is incomplete or different")
    engine.require(report.get("files_sha256") == evidence_files(directory), "Workbench evidence changed")
    verify_results(directory / "workbench/regressions/results.json", regression_labels())
    verify_results(directory / "workbench/combined/results.json", integration_labels())
    for workers in (1, 4):
        for phase in ("author", "reopen"):
            verify_combined_case(directory / "workbench/combined", f"mat-workbench-workers-{workers}-{phase}",
                                 engine.ROOT / "godot", workers, phase, platform=platform, native_sha=native_sha)
    if platform == "linux":
        verify_results(directory / "workbench/installed/results.json", installed_labels())
    return report


def verify_materials_bundle(directory: Path, platform: str, source: str) -> dict:
    manifest = _verify_lab_bundle(directory, platform, source)
    verify_workbench(directory, platform, source, manifest["sha256"])
    engine.require(manifest.get("mat_workbench_execution_sha256") == engine.runner.sha256(directory / "workbench.json"),
                   "Combined Workbench receipt differs from its runtime manifest")
    return manifest


# Only this privately loaded Lab profile receives the stricter publication gate.
lab.verify_materials_bundle = verify_materials_bundle


def workbench(args: argparse.Namespace) -> None:
    import run_workbench_qualification as wb
    lab.require_platform(args.platform)
    manifest = _verify_lab_bundle(args.bundle, args.platform, args.source_sha)
    output = args.bundle / "workbench"
    engine.require(not output.exists(), "Do not overwrite earlier Workbench evidence")
    output.mkdir()
    if args.platform == "windows":
        godot, _ = engine.windows.prepare_godot(args.godot_archive)
    else:
        engine.require(engine.runner.sha256(args.godot_archive) == engine.GODOT_LINUX_SHA256, "Linux engine archive changed")
        godot = args.godot_archive.with_suffix("") / "Godot_v4.7-stable_linux.x86_64"
    report = engine.context(args.source_sha) | {
        "schema": "mat-workbench-source-qualification-v1", "platform": args.platform,
        "native_sha256": manifest["sha256"], "completed": False, "status": "running", "files_sha256": {},
    }
    engine.write_json(args.bundle / "workbench.json", report)
    try:
        wb.regressions(argparse.Namespace(godot=godot, evidence=output / "regressions", project=engine.ROOT / "godot", paint=True))
        verify_results(output / "regressions/results.json", regression_labels())
        runner = wb.Runner(argparse.Namespace(godot=godot, evidence=output / "combined"))
        combined_lab_workbench(runner, engine.ROOT / "godot")
        verify_results(output / "combined/results.json", integration_labels())
        if args.platform == "linux":
            with tempfile.TemporaryDirectory(prefix="mat-workbench-installed-") as temporary:
                root = Path(temporary)
                wb.stage_linux(argparse.Namespace(output=root / "package"))
                wb.installed(argparse.Namespace(godot=godot, evidence=output / "installed", package=root / "package",
                                                scratch=root / "copies", combined=True))
            verify_results(output / "installed/results.json", installed_labels())
        engine.require(engine.input_ledgers(args.source_sha) == {key: manifest[key] for key in ("source_inputs", "build_inputs")},
                       "Build/test source changed during Workbench qualification")
        engine.require(engine.runtime_identity(engine.ROOT / engine.RUNTIMES[args.platform], args.platform)["sha256"] == manifest["sha256"],
                       "Runtime changed during Workbench qualification")
        report.update(status="passed", completed=True)
    except Exception as error:
        report.update(status="failed", error=str(error))
        raise
    finally:
        report["files_sha256"] = evidence_files(args.bundle)
        engine.write_json(args.bundle / "workbench.json", report)
    manifest.update(mat_workbench_execution_sha256=engine.runner.sha256(args.bundle / "workbench.json"),
                    mat_workbench_scope="Complete PAINT/agent source regressions, native shared Undo/Redo, Lab/Workbench author-reopen at 1/4 workers; Linux copied installations")
    engine.write_json(engine.manifest_path(args.bundle, args.platform), manifest)
    verify_materials_bundle(args.bundle, args.platform, args.source_sha)


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "workbench":
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("command")
        parser.add_argument("--source-sha", required=True)
        parser.add_argument("--platform", choices=["linux", "windows"], required=True)
        parser.add_argument("--bundle", type=Path, required=True)
        parser.add_argument("--godot-archive", type=Path, required=True)
        workbench(parser.parse_args())
        return 0
    return lab.main()


if __name__ == "__main__":
    raise SystemExit(main())
