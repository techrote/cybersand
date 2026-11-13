#!/usr/bin/env python3
"""GEN-008 profile over the accepted MAT/Workbench four-path publication engine.

Keep every inherited build, target-OS, graphical, source-input, request and
branch-lease gate. Add the complete native-backed Flatten/fresh-process matrix;
neither an old Workbench receipt nor a partial/headless Flatten run can publish.
This module never pushes a branch: the named workflow owns the leased append.
"""
from __future__ import annotations

import argparse
from importlib.util import module_from_spec, spec_from_file_location
import json
import os
from pathlib import Path
import re
import sys

_spec = spec_from_file_location(
    "_gen008_private_mat_workbench_publication",
    Path(__file__).with_name("mat_workbench_runtime_publication.py"))
workbench = module_from_spec(_spec)
_spec.loader.exec_module(workbench)
engine = workbench.engine
_previous_workflow, _previous_request = engine.WORKFLOW, engine.REQUEST
engine.BRANCH = "feat/gen008-flatten-material-baseline"
engine.WORKFLOW = ".github/workflows/gen008-flatten-qualification.yml"
engine.REQUEST = "tools/ci/gen008_flatten_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-13-gen008-flatten-qualification.md"
engine.BUNDLE_PREFIX = "gen008-flatten-runtime-attempt-" + os.environ.get("GITHUB_RUN_ATTEMPT", "1")
engine.REQUEST_VALUE = {
    "schema": "gen008-flatten-runtime-publish-request-v1",
    "family": "shared-workbench-material-baseline",
    "variant": "uint16le-stored-materials-same-live-world",
    "scope": "source-matched-linux-windows-flatten-save-fresh-reopen-and-retained-regressions",
    "intent": "publish-source-matched-runtimes",
}
engine.BUILD_EXACT = (set(engine.BUILD_EXACT) - {_previous_workflow, _previous_request}) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/gen008_flatten_runtime_publication.py",
    "tools/ci/test_gen008_flatten_runtime_publication.py",
    "tools/ci/run_flatten_qualification.py",
    "tools/package_gen008_flatten_candidate.py",
}
_verify_workbench_bundle = workbench.verify_materials_bundle
CASES = ((512, 1), (1024, 1), (2048, 1), (512, 4))
SOURCE_PATHS = (
    "scripts/main.gd", "scripts/shared_workbench.gd", "scripts/simulation_worker.gd",
    "scripts/microscenario_host.gd",
    "scripts/workbench_setup.gd", "scripts/workbench_material_baseline.gd",
    "scripts/workbench_generated_map.gd", "scripts/workbench_paint_editor_controller.gd",
    "scripts/workbench_paint_editor_executor.gd", "scripts/workbench_paint_editor_history.gd", "scripts/art_batch_executor.gd",
    "tests/test_workbench_flatten.gd", "tests/test_workbench_material_baseline.gd",
    "tests/flatten_save_fault_child.gd",
)


def __getattr__(name):
    return getattr(workbench, name)


def flatten_labels() -> list[str]:
    return ["flatten-import", "standalone-format-adversarial", *[
        f"side-{side}-workers-{workers}-{phase}" for side, workers in CASES
        for phase in ("author", "reopen")]]


def evidence_files(directory: Path) -> dict[str, str]:
    result = {}
    for path in sorted((directory / "flatten").rglob("*")):
        engine.require(not path.is_symlink(), "Flatten evidence cannot contain a symlink")
        if path.is_file():
            result[path.relative_to(directory).as_posix()] = engine.runner.sha256(path)
    return result


def verify_storage_faults(directory: Path, platform: str) -> dict:
    import run_workbench_qualification as wb
    report = workbench.lab.read_json(directory / "storage-faults.json")
    engine.require(report.get("schema") == "gen008-flatten-storage-faults-v1" and
                   report.get("status") == "passed" and report.get("completed") is True and
                   report.get("platform") == platform, "Storage-fault execution is incomplete or on the wrong OS")
    expected = ["locked-target"] if platform == "windows" else ["partial-write", "process-termination"]
    rows = report.get("cases", [])
    engine.require(isinstance(rows, list) and [row.get("kind") for row in rows] == expected,
                   "Storage-fault coverage is incomplete")
    for row in rows:
        kind = row["kind"]
        engine.require(re.fullmatch(r"[0-9a-f]{64}", str(row.get("prior_sha256", ""))) is not None and
                       row.get("prior_sha256") == row.get("after_sha256") and row.get("retry_ok") is True and
                       re.fullmatch(r"[0-9a-f]{64}", str(row.get("retry_sha256", ""))) is not None and
                       row.get("retry_sha256") != row.get("prior_sha256") and row.get("attempted_plane_bytes") == 524288,
                       "Failed Save did not preserve the original named start and permit a real retry")
        logs = directory / "storage-faults"
        for phase in ("prepare", "recover"):
            text = (logs / f"{kind}-{phase}.log").read_text(encoding="utf-8")
            engine.require(len(re.findall(r"(?m)^FLATTEN_STORAGE_RESULT ", text)) == 1,
                           "Storage-fault setup/recovery receipt is missing or ambiguous")
            receipt = wb.completion(text, "FLATTEN_STORAGE_RESULT")
            expected_hash = row["prior_sha256"] if phase == "prepare" else row["retry_sha256"]
            engine.require(receipt.get("phase") == phase and receipt.get("error") == "" and
                           receipt.get("after_sha256") == expected_hash,
                           "Storage setup/recovery receipt differs from original saved bytes")
        refusal_log = (logs / f"{kind}-refusal.log").read_text(encoding="utf-8")
        if kind == "process-termination":
            engine.require(row.get("exit_code") == -25 and row.get("signal") == 25 and
                           row.get("file_size_limit_bytes") == 65536 and row.get("partial_temporary_bytes") == [65536] and
                           row.get("explicit_refusal") is False and "FLATTEN_STORAGE_WRITING " in refusal_log and
                           "FLATTEN_STORAGE_RESULT " not in refusal_log,
                           "Process-fault case did not die during a real partial temporary-file write")
        else:
            receipt = wb.completion(refusal_log, "FLATTEN_STORAGE_RESULT")
            engine.require(row.get("exit_code") == 0 and row.get("explicit_refusal") is True and
                           row.get("partial_temporary_bytes") == [] and bool(receipt.get("error")) and
                           receipt.get("phase") == "refusal" and receipt.get("prior_sha256") == row["prior_sha256"] and
                           receipt.get("after_sha256") == row["prior_sha256"],
                           "Recoverable Save fault was not explicitly refused with original bytes intact")
            if kind == "partial-write":
                engine.require(row.get("file_size_limit_bytes") == 65536,
                               "Partial-write fixture omitted the actual OS storage-capacity bound")
    return {"status": "passed", "report_sha256": engine.runner.sha256(directory / "storage-faults.json")}


def verify_flatten_cases(directory: Path, platform: str, native_sha: str,
                         project: Path) -> list[dict]:
    import run_workbench_qualification as wb
    records = workbench.verify_results(directory / "results.json", flatten_labels())
    summary = workbench.lab.read_json(directory / "qualification.json")
    engine.require(summary == {"status": "passed", "cases": [list(case) for case in CASES], "graphical": True,
                               "storage_faults": verify_storage_faults(directory,platform)},
                   "Flatten qualification matrix is partial, failed or headless")
    expected_os = "Windows" if platform == "windows" else "Linux"
    for entry in records:
        engine.require(type(entry.get("sampled_peak_rss_bytes")) is int and entry["sampled_peak_rss_bytes"] > 0
                       and type(entry.get("os_peak_rss_bytes")) is int and entry["os_peak_rss_bytes"] > 0,
                       "Original process memory evidence is missing")
    format_log = (directory / "standalone-format-adversarial.log").read_text(encoding="utf-8")
    engine.require(len(re.findall(r"(?m)^WORKBENCH_MATERIAL_BASELINE ", format_log)) == 1,
                   "Material format completion is missing or ambiguous")
    wb.completion(format_log, "WORKBENCH_MATERIAL_BASELINE")
    pairs = {}
    for entry in records[2:]:
        label = entry["label"]
        match = re.fullmatch(r"side-(512|1024|2048)-workers-(1|4)-(author|reopen)", label)
        engine.require(match is not None, "Unregistered Flatten execution")
        side, workers, phase = int(match[1]), int(match[2]), match[3]
        text = (directory / (label + ".log")).read_text(encoding="utf-8")
        engine.require(len(re.findall(r"(?m)^FLATTEN_RESULT ", text)) == 1,
                       "Flatten completion is missing or ambiguous")
        receipt = wb.completion(text, "FLATTEN_RESULT")
        engine.require(receipt == entry.get("completion") and receipt.get("completed") is True and
                       receipt.get("phase") == phase and receipt.get("side") == side and
                       receipt.get("workers") == workers and receipt.get("canonical_bytes") == 2*side*side,
                       "Flatten result differs from its original complete process receipt")
        identity = receipt.get("source_identity", {})
        engine.require(identity.get("os") == expected_os and identity.get("display", "").lower() in
                       ({"windows"} if platform == "windows" else {"x11"}) and
                       identity.get("godot") == workbench.GODOT_DISPLAY_VERSION,
                       "Flatten requires actual pinned graphical target-OS execution")
        engine.require(identity.get("native_sha256") == native_sha and
                       all(identity.get(path) == engine.runner.sha256(project / path) for path in SOURCE_PATHS),
                       "Flatten runtime or authored source differs from the qualified bundle")
        required_phases = ({"startup", "generate", "construction", "simulation", "flatten_paused",
                            "flatten_playing", "post_flatten_history", "save", "complete"}
                           if phase == "author" else {"startup", "reopen", "continued_authoring", "complete"})
        if phase == "author" and side == 512:
            required_phases.add("failure_atomicity")
        engine.require(all(receipt.get("phases", {}).get(key) is True for key in required_phases),
                       "Flatten skipped a required execution phase")
        witnesses = receipt.get("native_material_witnesses", [])
        engine.require(isinstance(witnesses, list) and witnesses and
                       len({row.get("label") for row in witnesses}) == len(witnesses) and
                       all(row.get("bytes") == 2*side*side and
                           re.fullmatch(r"[0-9a-f]{64}", str(row.get("sha256", ""))) for row in witnesses),
                       "Flatten omitted complete native material readback")
        indexed = {row["label"]: row for row in witnesses}
        if phase == "author":
            engine.require({"before-simulation", "simulation-derived-materials", "after-flatten",
                            "post-flatten-edits-before-later-simulation", "later-simulation-excluded-from-save"}.issubset(indexed),
                           "Flatten omitted a native simulation or identity witness")
            engine.require(indexed["before-simulation"]["sha256"] != indexed["simulation-derived-materials"]["sha256"] and
                           indexed["simulation-derived-materials"]["sha256"] == indexed["after-flatten"]["sha256"] and
                           indexed["post-flatten-edits-before-later-simulation"]["sha256"] !=
                           indexed["later-simulation-excluded-from-save"]["sha256"],
                           "Native material witnesses do not prove simulation capture and unchanged Flatten")
            for field in ("generation", "native_generation", "tick", "revision"):
                engine.require(indexed["simulation-derived-materials"].get(field) == indexed["after-flatten"].get(field),
                               "Paused Flatten changed native World identity or transient boundary: " + field)
        else:
            engine.require("fresh-process-reconstructed-plane" in indexed,
                           "Fresh-process native reconstruction readback is missing")
        required_images = ({"flatten-identical-live-world.png", "flatten-explicitly-saved.png"}
                           if phase == "author" else {"flatten-reopened-and-continued.png"})
        frames = directory / (label + "-frames")
        engine.require(all((frames / name).is_file() and
                           (frames / name).read_bytes().startswith(b"\x89PNG\r\n\x1a\n") for name in required_images),
                       "Flatten is missing original graphical framebuffer evidence")
        instance = receipt.get("process_instance", "")
        engine.require(re.fullmatch(r"[0-9a-f]{32}", str(instance)) is not None,
                       "Fresh-process instance identity is missing")
        if phase == "author":
            pairs[(side, workers)] = receipt
        else:
            previous = pairs[(side, workers)]
            engine.require(previous["process_instance"] != instance and previous["source_identity"] == identity,
                           "Reopen did not use a new process with identical source/runtime bytes")
    return records


def verify_flatten(directory: Path, platform: str, source: str, native_sha: str) -> dict:
    report = workbench.lab.read_json(directory / "flatten.json")
    workbench.lab.verify_context(report, source)
    engine.require(report.get("schema") == "gen008-flatten-source-qualification-v1" and
                   report.get("platform") == platform and report.get("native_sha256") == native_sha and
                   report.get("status") == "passed" and report.get("completed") is True,
                   "Flatten execution identity is incomplete or different")
    engine.require(report.get("files_sha256") == evidence_files(directory), "Flatten evidence changed")
    verify_flatten_cases(directory / "flatten", platform, native_sha, engine.ROOT / "godot")
    return report


def verify_materials_bundle(directory: Path, platform: str, source: str) -> dict:
    manifest = _verify_workbench_bundle(directory, platform, source)
    verify_flatten(directory, platform, source, manifest["sha256"])
    engine.require(manifest.get("gen008_flatten_execution_sha256") == engine.runner.sha256(directory / "flatten.json"),
                   "Flatten execution receipt differs from its runtime manifest")
    return manifest


# Only this privately loaded original receives the additional stage/package gate.
# Its ordinary workbench command still completes before the new Flatten command.
workbench.lab.verify_materials_bundle = verify_materials_bundle


def flatten(args: argparse.Namespace) -> None:
    import run_flatten_qualification as runner
    workbench.lab.require_platform(args.platform)
    manifest = _verify_workbench_bundle(args.bundle, args.platform, args.source_sha)
    output = args.bundle / "flatten"
    engine.require(not output.exists(), "Do not overwrite earlier Flatten execution evidence")
    if args.platform == "windows":
        godot, _ = engine.windows.prepare_godot(args.godot_archive)
    else:
        engine.require(engine.runner.sha256(args.godot_archive) == engine.GODOT_LINUX_SHA256,
                       "Linux Godot archive changed")
        godot = args.godot_archive.with_suffix("") / "Godot_v4.7-stable_linux.x86_64"
    report = engine.context(args.source_sha) | {
        "schema": "gen008-flatten-source-qualification-v1", "platform": args.platform,
        "native_sha256": manifest["sha256"], "completed": False, "status": "running", "files_sha256": {},
    }
    engine.write_json(args.bundle / "flatten.json", report)
    summary = {"status": "running", "cases": [list(case) for case in CASES], "graphical": True}
    try:
        summary["storage_faults"] = runner.flatten(argparse.Namespace(godot=godot, project=engine.ROOT / "godot",
                                         evidence=output, package=None, headless=False, cases=CASES))
        summary["status"] = "passed"
        engine.write_json(output / "qualification.json", summary)
        verify_flatten_cases(output, args.platform, manifest["sha256"], engine.ROOT / "godot")
        engine.require(engine.input_ledgers(args.source_sha) == {key: manifest[key] for key in ("source_inputs", "build_inputs")},
                       "Build/test source changed during Flatten qualification")
        engine.require(engine.runtime_identity(engine.ROOT / engine.RUNTIMES[args.platform], args.platform)["sha256"] == manifest["sha256"],
                       "Runtime changed during Flatten qualification")
        report.update(status="passed", completed=True)
    except Exception as error:
        summary.update(status="failed", error=str(error))
        report.update(status="failed", error=str(error))
        raise
    finally:
        engine.write_json(output / "qualification.json", summary)
        report["files_sha256"] = evidence_files(args.bundle)
        engine.write_json(args.bundle / "flatten.json", report)
    manifest.update(gen008_flatten_execution_sha256=engine.runner.sha256(args.bundle / "flatten.json"),
                    gen008_flatten_scope="Complete 512/1024/2048 uint16 stored-material planes, same live World, "
                    "manual/agent history, failure atomicity, separate-process Save/reopen, graphics and process RSS; retained MAT/Workbench gates")
    engine.write_json(engine.manifest_path(args.bundle, args.platform), manifest)
    verify_materials_bundle(args.bundle, args.platform, args.source_sha)


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "flatten":
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("command")
        parser.add_argument("--source-sha", required=True)
        parser.add_argument("--platform", choices=["linux", "windows"], required=True)
        parser.add_argument("--bundle", type=Path, required=True)
        parser.add_argument("--godot-archive", type=Path, required=True)
        flatten(parser.parse_args())
        return 0
    return workbench.main()


if __name__ == "__main__":
    raise SystemExit(main())
