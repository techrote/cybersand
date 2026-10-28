#!/usr/bin/env python3
"""Source-bound PLAY-AUTO-002 runtime publication profile; never pushes.

Reuse the existing byte/source/lease engine in isolation. A fresh explicit
request and successful actual Windows/Linux execution are required before
the workflow can append the four runtime/provenance paths to this branch.
"""
from importlib.util import module_from_spec, spec_from_file_location
import json
from pathlib import Path
import re
import subprocess
import sys

_spec = spec_from_file_location(
    "_play_auto002_publication_engine",
    Path(__file__).with_name("lcb001_shared_contract_runtime_publication.py"),
)
engine = module_from_spec(_spec)
_spec.loader.exec_module(engine)
_historical_workflow = engine.WORKFLOW
_historical_request = engine.REQUEST
engine.BRANCH = "play-266-worker-matrix-20261027"
engine.WORKFLOW = ".github/workflows/play-auto002-runtime-publication.yml"
engine.REQUEST = "tools/ci/play_auto002_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-10-27-play-auto002-worker-matrix-candidate.md"
engine.BUNDLE_PREFIX = "play-auto002-runtime"
engine.PRESSURE_CASE = "godot/tests/test_worker_benchmark.gd"
engine.REQUEST_VALUE = {
    "schema": "play-auto002-publish-request-v1",
    "family": "native_worker_pool",
    "variant": "1-2-4-6-auto",
    "scope": "play-auto002-participation-parity-and-shared-host-policy-controls",
    "intent": "publish-source-matched-runtimes",
}
engine.CASE_MARKERS = {
    "test_worker_benchmark": r"(?m)^PLAY_AUTO002_RESULT (\{.+\})\s*$",
    "test_microscenario_native_observation":
        r"(?m)^MICROSCENARIO_NATIVE_OBSERVATION: [1-9][0-9]* assertions; 0 failures\s*$",
    "test_play_auto001_shared_course": r"(?m)^PLAY_AUTO001_RESULT (\{.+\})\s*$",
    "test_play_comp002_five_rig_course": r"(?m)^PLAY_COMP002_RESULT (\{.+\})\s*$",
    "test_liquid_solver_policy": engine.CASE_MARKERS["test_liquid_solver_policy"],
    "test_liquid_policy_worker": engine.CASE_MARKERS["test_liquid_policy_worker"],
}
# Preserve the ordinary PLAY per-process bounds; no slower historical publisher
# override is borrowed. Import retains its existing 240-second preflight bound.
engine.CASE_TIMEOUTS = {name: 180 for name in engine.CASE_MARKERS}
engine.EXECUTION_SCOPE = (
    "Import plus the fixed-input 1/2/4/6/Auto worker-participation/parity regression, "
    "native observation compatibility/quarantine, real shared-course Auto readback, "
    "five actual SetP rigs with construction-time pressure policy/reset/refusal, "
    "liquid-policy admission/refusal/worker-lifetime controls and the repeated "
    "50-row 1/2/4/6/Auto native timing campaign on each target OS; "
    "full ready-PR CI and representative performance/desktop-feel qualification remain separate"
)
engine.BUILD_EXACT = (set(engine.BUILD_EXACT) - {_historical_workflow, _historical_request}) | {
    engine.WORKFLOW, engine.REQUEST,
    "tools/ci/play_auto002_runtime_publication.py",
    "tools/ci/test_play_auto002_runtime_publication.py",
    "tools/play/run_auto_campaign.py",
    "tools/play/test_run_auto_campaign.py",
}
_verify_base = engine.verify_case_results
_verify_bundle = engine.verify_bundle
_execute = engine.execute
_collecting_campaign = False


def unique_object(pairs: list) -> dict:
    result = {}
    for key, value in pairs:
        engine.require(key not in result, "Duplicate PLAY evidence field: " + key)
        result[key] = value
    return result


def json_rows(directory: Path, name: str, prefix: str) -> list[dict]:
    output = (directory / (name + ".log")).read_text(encoding="utf-8")
    try:
        rows = [json.loads(value, object_pairs_hook=unique_object)
                for value in re.findall(r"(?m)^" + re.escape(prefix) + r" (.*)$", output)]
    except (ValueError, TypeError) as exc:
        raise RuntimeError("Malformed PLAY evidence: " + prefix) from exc
    engine.require(all(isinstance(row, dict) for row in rows), "Non-object PLAY evidence: " + prefix)
    return rows


def integer(value: object, minimum: int = 0) -> bool:
    return type(value) is int and value >= minimum


def sha256_text(value: object) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def completed_result(directory: Path, name: str, prefix: str) -> dict:
    rows = json_rows(directory, name, prefix)
    engine.require(len(rows) == 1, "Missing or duplicate PLAY result: " + prefix)
    value = rows[0]
    engine.require(integer(value.get("assertions"), 1) and type(value.get("failures")) is int
                   and value["failures"] == 0, "PLAY result has no passing assertions: " + prefix)
    return value


def verify_worker_matrix(value: dict) -> None:
    counts = value.get("distinct_actual_counts")
    requested = value.get("requested_counts")
    engine.require(type(value.get("rows")) is int and value["rows"] == 10
                   and requested == [1, 2, 4, 6, 0]
                   and all(type(item) is int for item in requested)
                   and isinstance(counts, list) and len(counts) > 0
                   and all(integer(item, 1) for item in counts)
                   and len(set(counts)) == len(counts) and 1 in counts,
                   "Incomplete PLAY worker policy matrix")
    engine.require(integer(value.get("logical_threads"), 1) and integer(value.get("auto_workers"), 1)
                   and integer(value.get("global_setting_before"))
                   and type(value.get("global_setting_after")) is int
                   and value["global_setting_after"] == value["global_setting_before"],
                   "PLAY worker identity or global-setting preservation differs")
    if len(counts) > 1:
        actual = value.get("participating_actual_workers")
        observed = value.get("maximum_workers_observed")
        engine.require(value.get("fixed_input_parity") is True
                       and integer(value.get("parallel_participation_rows"), 1)
                       and type(value.get("participating_request")) is int
                       and value["participating_request"] in [2, 4, 6, 0]
                       and integer(actual, 2) and actual in counts
                       and integer(observed, 2) and observed <= actual
                       and integer(value.get("worker_participation_ticks"), 1)
                       and integer(value.get("participating_parallel_ticks"), 1),
                       "PLAY matrix lacks actual multiworker task participation or parity")
    else:
        engine.require(value.get("fixed_input_parity") is None
                       and type(value.get("parallel_participation_rows")) is int
                       and value["parallel_participation_rows"] == 0
                       and value.get("participating_request") is None
                       and value.get("participating_actual_workers") is None
                       and all(type(value.get(key)) is int and value[key] == 0 for key in
                               ("maximum_workers_observed", "worker_participation_ticks", "participating_parallel_ticks")),
                       "One-count PLAY matrix invents parity or participation")
    for key in ("rendered_gameplay_fps_measured", "causal_speedup_claimed",
                "per_worker_utilization_measured", "player_world_reconfigured"):
        engine.require(value.get(key) is False, "PLAY bounded regression overclaims: " + key)


def verify_auto_host(value: dict) -> None:
    engine.require(type(value.get("requested_setting")) is int and value["requested_setting"] == 0
                   and integer(value.get("logical_processors"), 1)
                   and integer(value.get("auto_policy_workers"), 1)
                   and type(value.get("actual_worker_capacity")) is int
                   and value["actual_worker_capacity"] == value["auto_policy_workers"]
                   and integer(value.get("native_ticks_observed"), 3)
                   and integer(value.get("last_native_tick"), 1)
                   and integer(value.get("rapier_tick"), 1)
                   and value.get("terrain_ready") is True
                   and value.get("native_auto_source") == "CyberNativeCellWorld::create_world"
                   and value.get("route") == "existing-CyberSimulationWorker+main-Rapier"
                   and isinstance(value.get("backend"), str) and value["backend"] != ""
                   and value["backend"] != "gdscript-serial-fallback",
                   "Incomplete real shared-host Auto readback")
    for key in ("parallel_speedup_proven", "rendered_fps_measured", "gamepad_qualified"):
        engine.require(value.get(key) is False, "Shared-host Auto readback overclaims: " + key)


def verify_course(directory: Path, value: dict) -> None:
    engine.require(type(value.get("mechanical_presets")) is int and value["mechanical_presets"] == 5
                   and value.get("route") == "existing-CyberSimulationWorker+main-Rapier",
                   "Incomplete actual five-rig course")
    for key in ("swarm_qualified", "gamepad_qualified", "frame_pacing_measured", "parallel_speedup_proven"):
        engine.require(value.get(key) is False, "Five-rig fixture overclaims: " + key)
    rows = json_rows(directory, "test_play_comp002_five_rig_course", "PLAY_COMP002_RIG")
    engine.require([row.get("rig") for row in rows] ==
                   ["stuntbuggy", "trialsbike", "acrobat", "arcadelander", "jetbarrel"]
                   and all(integer(row.get("physics_tick"), 1) and integer(row.get("native_tick"), 1)
                           and integer(row.get("resolved_native_workers"), 1)
                           and row.get("terrain_ready") is True for row in rows),
                   "Missing actual five-rig movement/terrain receipts")
    liquid = json_rows(directory, "test_play_comp002_five_rig_course", "PLAY_COMP002_LIQUID")
    engine.require(len(liquid) == 1, "Missing actual course solver reconstruction")
    row = liquid[0]
    engine.require(all(sha256_text(row.get(key)) for key in ("policy_hash", "native_receipt", "recipe_hash"))
                   and integer(row.get("initial_generation"))
                   and type(row.get("applied_generation")) is int
                   and row["applied_generation"] > row["initial_generation"]
                   and type(row.get("reset_generation")) is int
                   and row["reset_generation"] > row["applied_generation"]
                   and row.get("switched_actor") == "acrobat"
                   and row.get("selected_water_family") == "pressure_flow_v1"
                   and row.get("real_frame_pacing_measured") is False,
                   "Incomplete construction-time solver/reset/refusal receipt")


def verify_case_results(directory: Path, report: dict) -> None:
    _verify_base(directory, report)
    verify_worker_matrix(completed_result(directory, "test_worker_benchmark", "PLAY_AUTO002_RESULT"))
    verify_auto_host(completed_result(directory, "test_play_auto001_shared_course", "PLAY_AUTO001_RESULT"))
    verify_course(directory, completed_result(directory, "test_play_comp002_five_rig_course", "PLAY_COMP002_RESULT"))


def campaign_module():
    spec = spec_from_file_location("_play_auto002_campaign", engine.ROOT / "tools/play/run_auto_campaign.py")
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def verify_campaign(directory: Path, platform: str, source: str, manifest: dict) -> None:
    engine.require(manifest.get("campaign_report") == "campaign/campaign.json",
                   "Missing repeated PLAY campaign identity")
    path = directory / "campaign/campaign.json"
    engine.require(path.is_file() and not path.is_symlink()
                   and engine.runner.sha256(path) == manifest.get("campaign_sha256"),
                   "Repeated PLAY campaign digest mismatch")
    report = campaign_module().verify_directory(path.parent, expected_source_sha=source)
    engine.require(report.get("platform") == platform,
                   "Repeated PLAY campaign target platform differs")
    runtime = report.get("native_runtime", {})
    engine.require(runtime.get("path") == manifest.get("artifact")
                   and all(runtime.get(key) == manifest.get(key) for key in ("sha256", "size")),
                   "Repeated PLAY campaign runtime differs from published runtime")
    engine.require(report.get("source_tree") == manifest.get("source_tree")
                   and report.get("native_inputs") == manifest.get("source_inputs"),
                   "Repeated PLAY campaign native source differs from published runtime")
    tested = report.get("tested_inputs")
    ledger = manifest.get("source_inputs", {}) | manifest.get("build_inputs", {})
    engine.require(isinstance(tested, dict) and tested
                   and all(ledger.get(path) == digest for path, digest in tested.items()),
                   "Repeated PLAY campaign execution inputs differ from publication source")


def verify_bundle(directory: Path, platform: str, source: str, validated: bool) -> dict:
    manifest = _verify_bundle(directory, platform, source, validated)
    if validated and not _collecting_campaign:
        verify_campaign(directory, platform, source, manifest)
    return manifest


def execute(args) -> None:
    global _collecting_campaign
    # The inherited helper validates the six focused cases first. Publication
    # remains impossible until the separately bounded repeated campaign completes.
    _collecting_campaign = True
    try:
        _execute(args)
    finally:
        _collecting_campaign = False
    manifest_path = engine.manifest_path(args.bundle, args.platform)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["status"] = "focused-passed-campaign-pending"
    engine.write_json(manifest_path, manifest)
    godot_directory = args.godot_archive.with_suffix("")
    godot = godot_directory / ("Godot_v4.7-stable_win64_console.exe" if args.platform == "windows"
                               else "Godot_v4.7-stable_linux.x86_64")
    try:
        subprocess.run([sys.executable, str(engine.ROOT / "tools/play/run_auto_campaign.py"),
                        "--godot", str(godot.resolve()), "--output", str((args.bundle / "campaign").resolve()),
                        "--built-runtime-source", args.source_sha], cwd=engine.ROOT, check=True)
        manifest.update({"campaign_report": "campaign/campaign.json",
                         "campaign_sha256": engine.runner.sha256(args.bundle / "campaign/campaign.json")})
        verify_campaign(args.bundle, args.platform, args.source_sha, manifest)
    except Exception as exc:
        manifest.update({"status": "campaign-failed", "campaign_error": str(exc)})
        engine.write_json(manifest_path, manifest)
        raise
    manifest["status"] = "validated-development-runtime"
    engine.write_json(manifest_path, manifest)
    verify_bundle(args.bundle, args.platform, args.source_sha, validated=True)


engine.verify_case_results = verify_case_results
engine.verify_bundle = verify_bundle
engine.execute = execute

if __name__ == "__main__":
    raise SystemExit(engine.main())
