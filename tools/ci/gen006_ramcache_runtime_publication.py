#!/usr/bin/env python3
"""Isolated stacked GEN-006 RAM-cache publication; all donor fences remain."""
from __future__ import annotations

from importlib.util import module_from_spec, spec_from_file_location
import hashlib
import json
import math
import os
import re
import uuid
from pathlib import Path
import bounded_campaign_process as process_owner
from run_persistent_areas_qualification import ERRORS, completion

_spec = spec_from_file_location("_ramcache_private_donor_profile",
    Path(__file__).with_name("gen006_persistent_runtime_publication.py"))
donor = module_from_spec(_spec)
_spec.loader.exec_module(donor)
engine = donor.engine
old_workflow, old_request = engine.WORKFLOW, engine.REQUEST
engine.BRANCH = "exp/gen006-ramcache-finisher-001-20261122"
engine.WORKFLOW = ".github/workflows/gen006-ramcache-qualification.yml"
engine.REQUEST = "tools/ci/gen006_ramcache_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-22-gen006-ramcache.md"
engine.BUNDLE_PREFIX = "gen006-ramcache-runtime-attempt-" + os.environ.get("GITHUB_RUN_ATTEMPT", "1")
engine.REQUEST_VALUE = {
    "schema": "gen006-ramcache-runtime-publish-request-v1",
    "family": "persistent-authored-areas",
    "variant": "hot-native-warm-cyps2-deferred-durability-predictive-preparation",
    "scope": "three-areas-native-residency-writeback-prefetch-linux-windows",
    "intent": "publish-source-matched-runtimes",
}
engine.EXECUTION_SCOPE = (
    "Three actor-free 512x512 Current/FreeMass areas: unique-owned retained HOT "
    "native Worlds, distinct WARM checkpoints, bounded cache admission, immutable "
    "asynchronous durable publication, legitimate game-time debt and private "
    "predictive preparation. Actual graphical Linux/Windows and independent "
    "process recovery. Draft/HOLD; physical Windows 11/NVIDIA acceptance pending. "
    "No general streaming, arbitrary actor/Rapier or unsupported solver claim."
)
donor.CAMPAIGN_SCRIPT = "tools/ci/run_persistent_area_ramcache_qualification.py"
# This private profile adds native residency, fault recovery and 30-sample route
# comparisons to the donor campaign. Windows requires a larger finite aggregate
# watchdog; every child deadline and the production native owner timeout remain.
# The ordinarily imported donor and successor Linux retain 3600-second limits.
donor.CAMPAIGN_TIMEOUT_SECONDS["windows"] = 7200


def execute_owned_campaign(command: list[str], *, cwd: Path, timeout: float, bundle: Path):
    """Keep failure evidence immutable without claiming a universal Job barrier.

    A new exclusive receipt belongs only to this invocation. Positive retirement
    can admit failed evidence uploads. Otherwise only the complete, successful
    existing child-wait/custody/semantic campaign verifier admits normal uploads.
    """
    record = bundle / ("campaign-process-owner-" + uuid.uuid4().hex + ".json")

    def step_output(text: str) -> None:
        if os.environ.get("GITHUB_OUTPUT"):
            with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8") as output:
                output.write(text)

    # Clear any earlier invocation in the same step before fallible preparation.
    step_output("campaign_retirement_record=\ncampaign_retired_record=\n")
    with record.open("x", encoding="utf-8") as stream:
        json.dump({"status":"reserved", "retired":False}, stream)
    step_output("campaign_retirement_record=" + record.name + "\n")

    def acknowledge() -> bool:
        try:
            value = json.loads(record.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return False
        valid = isinstance(value, dict) and value.get("schema") == "gen006-campaign-process-owner-v1" \
            and value.get("command") == command and type(value.get("timeout_seconds")) in (int, float) \
            and value["timeout_seconds"] == timeout \
            and type(value.get("retired")) is bool and type(value.get("process_created")) is bool \
            and "pid" in value and isinstance(value.get("retirement_proof"), dict) \
            and type(value["retirement_proof"].get("complete")) is bool \
            and value.get("retirement_error") == ""
        if not valid:
            return False
        proof=value["retirement_proof"]
        if value["process_created"]:
            valid = type(value["pid"]) is int and value["pid"] > 0 \
                and value.get("method") in ("owned-linux-process-group", "suspended-windows-process-job") \
                and proof.get("no_process_created") is not True
        else:
            valid = value["pid"] is None and value.get("returncode") is None \
                and isinstance(value.get("original_error"), str) and bool(value["original_error"]) \
                and set(proof) == {"complete", "scope", "no_process_created"} \
                and proof.get("scope") == "no process created" and proof.get("no_process_created") is True
        if not valid:
            return False
        proven = value["retired"] and value.get("status") == "retired" \
            and proof["complete"]
        if proven:
            step_output("campaign_retired_record=" + record.name + "\n")
        return proven or (value["process_created"] and value["retired"] is False \
            and value.get("status") == "retirement-unproven" and proof["complete"] is False)

    try:
        result = process_owner.run_campaign(command, cwd=cwd, timeout=timeout, record_path=record)
    except BaseException:
        try:
            acknowledge()  # A proven cleanup does not change the failed outcome.
        except Exception as acknowledgement_error:
            # Evidence-record failure must not mask the original timeout/refusal.
            print("Campaign retirement acknowledgement refused: " + repr(acknowledgement_error), flush=True)
        raise
    require(acknowledge(), "Campaign process completion receipt is absent or invalid")
    return result


donor.execute_campaign = execute_owned_campaign
EXTRA_INPUTS = {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE, donor.CAMPAIGN_SCRIPT,
    "tools/ci/materialize_lfs.py",
    "tools/ci/test_gen006_ramcache_packaged_smoke.ps1",
    "tools/ci/gen006_ramcache_runtime_publication.py",
    "tools/ci/test_gen006_ramcache_runtime_publication.py",
    "tools/ci/bounded_campaign_process.py",
    "tools/ci/test_bounded_campaign_process.py",
    "tools/ci/run_persistent_area_writeback_faults.py",
    "tools/ci/run_persistent_area_residency_memory.py",
    "tools/ci/run_persistent_area_recovery.py",
    "tools/ci/run_persistent_area_travel_benchmark.py",
    "tools/ci/benchmark_persistent_area_travel.gd",
    "tools/package_gen006_ramcache.py",
    "docs/operations/persistent-area-ramcache-evaluation.md",
}
engine.BUILD_EXACT = (set(engine.BUILD_EXACT) - {old_workflow, old_request}) | EXTRA_INPUTS
BOUNDARIES = ("before_capture", "before_snapshot", "queued_dirty", "after_checkpoint", "after_stage", "after_previous", "before_publish", "after_publish", "newer_dirty_after_durable")
RAMCACHE_LABELS = frozenset({"ramcache-native", "ramcache-clock", "ramcache-ledger", "ramcache-writeback", "ramcache-owner-review", "ramcache-prefetch-concurrency", "donor-cold", "successor-cold"}
    | {"ramcache-hot-recovery", "ramcache-healthy-seed", "ramcache-healthy-verify", "ramcache-metadata-bounds"}
    | {"ramcache-resident-storage-write", "ramcache-resident-storage-reopen"}
    | {"ramcache-advance-recovery-write", "ramcache-advance-recovery-reopen"}
    | {"ramcache-independent-"+mode for mode in ("healthy", "missing_setup", "wrong_setup_types", "wrong_execution_type", "missing_worker_type", "stop",
            "runtime_mismatch", "session_mismatch", "source_identity_mismatch", "physics_mismatch", "policy_mismatch",
            "authoring_changed", "warm_corruption", "warm_wrong_tick", "short_native_reservation",
            "short_transient_reservation", "wrong_incarnation", "oversized_metadata")}
    | {f"ramcache-recoverable-{case}-{mode}" for case in ("deferred", "strict", "first", "ahead") for mode in ("write", "reopen")}
    | {f"ramcache-{mode}-w{workers}" for mode in ("write", "reopen", "memory") for workers in (1, 4)}
    | {f"ramcache-responsiveness-{variant}-w{workers}" for variant in ("control", "prefetch", "reversal") for workers in (1, 4)}
    | {"ramcache-crash-"+phase for phase in BOUNDARIES}
    | {f"ramcache-recover-{phase}-{index}" for phase in BOUNDARIES for index in (1, 2)})
donor.REQUIRED_LABELS = donor.REQUIRED_LABELS | RAMCACHE_LABELS
require, sha = engine.require, donor.sha
verify_files, safe_relative = donor.verify_files, donor.safe_relative
_verify_donor_qualification = donor.verify_qualification


def finite_nonnegative(value) -> bool:
    return type(value) in (int, float) and math.isfinite(value) and value >= 0


def timing_statistics(samples: list[dict]) -> dict:
    values = sorted(float(row["elapsed_ms"]) for row in samples)
    n = len(values)
    return {"samples": n, "p50_ms": (values[(n-1)//2]+values[n//2])/2,
        "p95_ms": values[math.ceil(n*0.95)-1], "worst_ms": values[-1],
        "maximum_correlated_main_frame_ms": max(float(row["max_main_frame_ms"]) for row in samples),
        "native_ticks": sum(int(row["native_ticks_executed"]) for row in samples)}


def verify_operation_timing(sample: dict) -> None:
    require(finite_nonnegative(sample.get("elapsed_ms")) and finite_nonnegative(sample.get("max_main_frame_ms"))
        and all(type(sample.get(key)) is int and sample[key] >= 0
            for key in ("start_usec", "end_usec", "worst_frame_start_usec", "worst_frame_end_usec", "frame_observations"))
        and sample["frame_observations"] > 0
        and sample["start_usec"] <= sample["worst_frame_start_usec"] <= sample["worst_frame_end_usec"] <= sample["end_usec"]
        and abs(sample["elapsed_ms"]-(sample["end_usec"]-sample["start_usec"])/1000.0) < 2
        and math.isclose(sample["max_main_frame_ms"]*1000,
            sample["worst_frame_end_usec"]-sample["worst_frame_start_usec"], abs_tol=0.000001, rel_tol=1e-12),
        "Operation timing is nonfinite, inconsistent or outside its correlated interval")


def verify_responsiveness(parent: dict, workers: int, group: dict, expected_window_msec: int = 10000) -> None:
    require(isinstance(group, dict) and set(group) == {"control", "prefetch", "reversal"},
        "Matched active-control, preparation and reversal evidence is incomplete")
    identities, environments, pids = [], [], []
    for variant, proof in group.items():
        initial, apparatus = proof.get("initial", {}), proof.get("apparatus", {})
        identity = proof.get("identity", {})
        graphics = identity.get("graphics", {})
        require(proof.get("schema") == "gen006-ramcache-responsiveness-v1" and proof.get("completed") is True
            and proof.get("variant") == variant and proof.get("graphical") is True and proof.get("failures") == []
            and proof.get("comparison_valid") is (variant != "reversal")
            and proof.get("prefetch_busy_at_window_end") is False
            and type(proof.get("process_id")) is int and proof["process_id"] > 0
            and type(proof.get("checks")) is int and proof["checks"] > 0
            and proof.get("identity", {}).get("native_runtime_sha256") == parent.get("native_sha256")
            and proof.get("identity", {}).get("source_revision") == parent.get("source_commit"),
            "Responsiveness requires source-bound real graphical process evidence")
        require(identity.get("os_name") == {"linux":"Linux", "windows":"Windows"}.get(parent.get("platform"))
            and isinstance(identity.get("os_version"), str) and identity["os_version"]
            and isinstance(identity.get("processor_name"), str) and identity["processor_name"]
            and type(identity.get("logical_processors")) is int and identity["logical_processors"] > 0
            and identity.get("engine", {}).get("major") == 4 and identity["engine"].get("minor") == 7
            and identity["engine"].get("hash") and graphics.get("display_server") not in (None, "", "headless")
            and all(graphics.get(method, {}).get("available") is True
                and isinstance(graphics[method].get("value"), str) and graphics[method]["value"]
                for method in ("get_current_rendering_driver_name", "get_current_rendering_method",
                    "get_video_adapter_name", "get_video_adapter_vendor", "get_video_adapter_api_version"))
            and graphics["get_current_rendering_method"]["value"] == "gl_compatibility",
            "Responsiveness lacks observed graphical, engine or machine identity")
        environments.append({key:identity[key] for key in
            ("engine", "graphics", "os_name", "os_version", "processor_name", "logical_processors")})
        require(initial.get("area_id") == "b" and initial.get("extent") == [512, 512]
            and initial.get("native_tick") == 0 and initial.get("game_tick") == 0
            and initial.get("worker_threads") == workers and initial.get("target_residency") == "COLD"
            and all(type(initial.get(key)) is int and initial[key] > 0 for key in ("active_handle", "world_generation"))
            and all(re.fullmatch(r"[0-9a-f]{64}", str(initial.get(key, ""))) is not None for key in (
                "native_sha256", "authoring_sha256", "authored_source_sha256", "physics_profile_sha256",
                "target_native_sha256", "target_source_sha256")), "Active comparison initial native state is unbound")
        require(apparatus.get("requested_window_msec") == expected_window_msec
            and apparatus.get("automatic_prediction_suppressed") is True
            and apparatus.get("background_checkpointing") is False and apparatus.get("arrival_outside_window") is True
            and apparatus.get("active_area") == "b" and apparatus.get("prefetch_target") == "c",
            "Responsiveness comparison changed its declared workload")
        pids.append(proof["process_id"])
        identities.append({key:value for key,value in initial.items() if key not in ("active_handle", "world_generation")})
        begin, end = proof.get("window_start_usec"), proof.get("window_end_usec")
        require(type(begin) is int and type(end) is int and begin > 0
            and expected_window_msec*1000 <= end-begin <= expected_window_msec*1000+3000000
            and proof.get("actual_window_usec") == end-begin, "Active comparison window was skipped or unbounded")
        frames = proof.get("frame_intervals", [])
        require(isinstance(frames, list) and len(frames) >= 10, "Active comparison omitted original frame intervals")
        last, tick, values = begin, 0, []
        for frame in frames:
            require(all(type(frame.get(key)) is int for key in (
                "start_usec", "end_usec", "interval_usec", "native_tick_before", "native_tick_after"))
                and frame["start_usec"] == last and frame["end_usec"] > last and frame["end_usec"] <= end
                and frame["interval_usec"] == frame["end_usec"]-last
                and frame["native_tick_before"] == tick and frame["native_tick_after"] >= frame["native_tick_before"]
                and frame.get("area_id") == "b" and frame.get("world_generation") == initial.get("world_generation"),
                "Frame series is discontinuous, unmeasured or changes active World authority")
            last, tick = frame["end_usec"], frame["native_tick_after"]
            values.append(frame["interval_usec"]/1000.0)
        require(last == end and tick > 0 and proof.get("native_ticks_observed_in_window") == tick,
            "Active interval does not establish actual completed native progression")
        values.sort()
        measured = {"count":len(values), "p50_ms":values[math.ceil(len(values)*0.5)-1],
            "p95_ms":values[math.ceil(len(values)*0.95)-1], "worst_ms":values[-1]}
        require(all(proof.get("frame_statistics", {}).get(key) == value for key,value in measured.items()),
            "Active-play frame statistics differ from their original intervals")
        if variant == "control":
            require(proof.get("io_at_window_end", {}).get("prefetch_requests") == 0
                and proof.get("target_hot_at_window_end") is False and proof.get("prefetch_records") == [],
                "Active control executed speculative preparation")
            continue
        all_records = proof.get("prefetch_records", [])
        require(isinstance(all_records, list) and all(isinstance(row, dict) for row in all_records),
            "Original speculative operation records are absent")
        if variant == "prefetch":
            require(proof.get("target_hot_at_window_end") is True
                and proof.get("io_at_window_end", {}).get("prefetch_requests") == 1
                and proof.get("io_at_window_end", {}).get("prefetch_completed") == 1,
                "Cold preparation did not complete inside the measured active window")
            records = [row for row in all_records if row.get("area_id") == "c"
                and row.get("source_residency") == "COLD" and row.get("status") == "completed"]
            require(len(records) == 1, "Missing or ambiguous actual cold preparation record")
            record = records[0]
            phases, native = record.get("phase_timestamps", {}), record.get("native_work", {})
            times = [record.get("start_usec"), phases.get("checkpoint_load_started_usec"),
                phases.get("checkpoint_load_finished_usec"), native.get("prepare_started_usec"),
                native.get("prepare_completed_usec"), native.get("import_started_usec"), native.get("import_completed_usec"),
                phases.get("cache_admission_started_usec"), phases.get("cache_admission_finished_usec"), record.get("end_usec")]
            require(all(type(value) is int and begin <= value <= end for value in times)
                and times == sorted(times) and native.get("prepared_before_activation") is True,
                "Preparation/import/cache admission is absent or outside the active comparison")
        else:
            require(proof.get("io_at_window_end", {}).get("prefetch_cancelled", 0) >= 1
                and type(proof.get("reversal_usec")) is int and begin <= proof["reversal_usec"] <= end,
                "Reversal evidence did not cancel actual outstanding preparation")
            cancelled = [row for row in all_records if row.get("area_id") == "c"
                and row.get("source_residency") == "COLD" and row.get("status") == "cancelled"]
            require(len(cancelled) == 1 and all(type(cancelled[0].get(key)) is int for key in ("start_usec", "end_usec"))
                and begin <= cancelled[0]["start_usec"] <= proof["reversal_usec"] <= cancelled[0]["end_usec"] <= end,
                "Reversal lacks actual cold preparation cancellation inside the measured window")
        arrival, prepared = proof.get("arrival", {}), proof.get("prepared_receipt", {})
        target = "c" if variant == "prefetch" else "a"
        require(arrival.get("status") == "completed" and arrival.get("residency") == "HOT"
            and arrival.get("prefetch_hit") is True
            and arrival.get("target_area") == target and arrival.get("start_usec", 0) >= end
            and prepared.get("identity", {}).get("area_id") == target and prepared.get("active") is False
            and type(prepared.get("handle")) is int and prepared["handle"] > 0,
            "Prepared native destination was not reused by an admitted arrival after measurement")
        matched = [row for row in all_records if row.get("operation_id") == arrival.get("prefetch_operation_id")]
        require(isinstance(arrival.get("prefetch_operation_id"), str) and arrival["prefetch_operation_id"]
            and len(matched) == 1 and matched[0].get("status") == "completed"
            and matched[0].get("area_id") == target
            and all(type(matched[0].get(key)) is int for key in ("start_usec", "end_usec"))
            and begin <= matched[0]["start_usec"] <= matched[0]["end_usec"] <= end
            and (variant != "reversal" or cancelled[0]["end_usec"] <= matched[0]["start_usec"]),
            "Arrival does not identify the actual destination prepared inside the measured window")
        native_receipt = matched[0].get("native_work", {}).get("receipt", {})
        stable_keys = ("handle", "identity", "resident_generation", "physics_profile_sha256", "worker_threads", "schema")
        require(all(key in prepared and prepared[key] == native_receipt.get(key) for key in stable_keys)
            and prepared.get("failed") is False and native_receipt.get("active") is False
            and native_receipt.get("failed") is False and prepared.get("worker_threads") == workers
            and prepared["identity"].get("runtime_sha256") == parent["native_sha256"]
            and all(re.fullmatch(r"[0-9a-f]{32}", str(prepared["identity"].get(key, ""))) for key in ("session_id", "incarnation"))
            and all(re.fullmatch(r"[0-9a-f]{64}", str(value)) for value in
                (prepared["identity"].get("authored_source_sha256", ""), prepared.get("physics_profile_sha256", "")))
            and all(type(prepared.get(key)) is int and type(native_receipt.get(key)) is int
                and prepared[key] >= native_receipt[key] >= 0 for key in ("completed_tick", "mutation_generation"))
            and arrival.get("target_native_tick_before") == prepared["completed_tick"],
            "Prepared receipt differs from the admitted native owner or completed tick frontier")
        before_io, after_io = arrival.get("io_before", {}), arrival.get("io_after", {})
        require(all(type(before_io.get(key)) is int and before_io[key] >= 0 and after_io.get(key) == before_io[key]
            for key in ("profile_read_calls", "profile_read_bytes", "native_deserializations", "source_constructions", "synchronous_publications"))
            and all(type(before_io.get(key)) is int and before_io[key] >= 0 and after_io.get(key) == before_io[key]+1
                for key in ("hot_handoffs", "prefetch_hits")),
            "Prefetched arrival reconstructed, reread, republished or did not transfer the resident owner")
    require(len(set(pids)) == 3 and identities[0] == identities[1] == identities[2],
        "Responsiveness comparison reused a process or changed initial native/authoring/physics state")
    require(environments[0] == environments[1] == environments[2],
        "Responsiveness comparison changed engine, operating system, CPU or observed graphics identity")


def verify_healthy_recovery(parent: dict, proof: dict) -> None:
    before = proof.get("source_before", {})
    require(proof.get("passed") is True and proof.get("qualified_source") is True and proof.get("diagnostic") is False
        and proof.get("source_unchanged") is True and proof.get("inputs_unchanged") is True
        and before == proof.get("source_after") and proof.get("before") == proof.get("after")
        and all(before.get(key) == parent.get(key) for key in ("source_commit", "source_tree", "local_delta", "missing_source_inputs"))
        and before.get("local_delta") == [] and before.get("missing_source_inputs") == [],
        "Healthy-area rescue source custody differs from qualification")
    inputs = before.get("source_inputs_sha256", {})
    identity = proof.get("before", {})
    require(inputs and all(parent.get("source_inputs_sha256", {}).get(path) == digest for path, digest in inputs.items())
        and identity.get("godot_sha256") == parent.get("engine_sha256") and identity.get("native_sha256") == parent.get("native_sha256")
        and identity.get("source_files") and all(parent.get("source_inputs_sha256", {}).get(path) == digest
            for path, digest in identity["source_files"].items()), "Healthy rescue input/runtime identities differ")
    runs = proof.get("runs", [])
    require(isinstance(runs, list) and len(runs) == 2 and [row.get("mode") for row in runs] == ["seed", "verify"]
        and all(row.get("passed") is True and row.get("exit_code") == 0 and row.get("timed_out") is False
            and type(row.get("pid")) is int and row["pid"] > 0 and row.get("observed_pid") == row["pid"]
            and row.get("checks", 0) > 0 and row.get("failures") == 0 for row in runs)
        and runs[0]["pid"] != runs[1]["pid"], "Healthy rescue requires two successful independent native processes")


def verify_recovery(parent: dict, proof: dict) -> None:
    before = proof.get("source_before", {})
    require(proof.get("ok") is True and proof.get("qualified_source") is True and proof.get("diagnostic") is False
        and proof.get("source_unchanged") is True and before == proof.get("source_after")
        and all(before.get(key) == parent.get(key) for key in ("source_commit", "source_tree", "local_delta", "missing_source_inputs"))
        and before.get("local_delta") == [] and before.get("missing_source_inputs") == [],
        "Write-behind recovery source custody differs from qualification")
    inputs = before.get("source_inputs_sha256", {})
    require(isinstance(inputs, dict) and inputs and all(parent.get("source_inputs_sha256", {}).get(path) == digest
        for path, digest in inputs.items()), "Recovery source inputs differ from the parent campaign")
    binaries = proof.get("binaries_before", {})
    require(isinstance(binaries, dict) and len(binaries) == 2 and binaries == proof.get("binaries_after")
        and set(binaries.values()) == {parent.get("native_sha256"), parent.get("engine_sha256")},
        "Recovery native/engine identity differs from qualification")
    require(all(proof.get(key) == parent.get(key) for key in ("source_commit", "source_tree", "engine_sha256", "native_sha256")),
        "Recovery top-level source/runtime identity differs")
    platform = proof.get("platform")
    require(platform in ("nt", "posix") and platform == ("nt" if parent.get("platform") == "windows" else "posix"),
        "Recovery OS identity differs from graphical campaign")
    rows = proof.get("rows", [])
    require(isinstance(rows, list) and len(rows) == len(BOUNDARIES)*3,
        "Nine actual OS deaths and eighteen independent native restores are mandatory")
    for index, phase in enumerate(BOUNDARIES):
        death, first, repeat = rows[3*index:3*index+3]
        require(all(isinstance(row, dict) and row.get("ok") is True and type(row.get("pid")) is int
            and row["pid"] > 0 and type(row.get("exit_code")) is int and row.get("boundary") == phase
            for row in (death, first, repeat)), "Recovery child process did not complete its declared boundary")
        barrier = death.get("observed_barrier", {})
        witnesses = death.get("barrier_witnesses", [])
        phases = {"before_snapshot", "queued_dirty"} if phase == "queued_dirty" else {phase}
        native_identity = death.get("native_identity", {})
        launcher_pid = death.get("launcher_pid")
        # The real Windows engine may run in the tracked launcher PID or a
        # verified console-child PID. Both forms are admitted by the producer;
        # the final verifier must apply that same exact, fail-closed contract.
        require(type(launcher_pid) is int and launcher_pid > 0
            and native_identity.get("native_pid") == death["pid"]
            and native_identity.get("launcher_pid") == launcher_pid
            and ((native_identity.get("relationship") == "direct" and launcher_pid == death["pid"])
                 or (platform == "nt" and native_identity.get("relationship") == "windows-console-child"
                     and death["pid"] != launcher_pid and native_identity.get("parent_pid") == launcher_pid)),
            "Native process-death witness is not the tracked real engine process")
        require(isinstance(witnesses, list) and len(witnesses) == len(phases)
            and {w.get("phase") for w in witnesses if isinstance(w, dict)} == phases
            and all(w.get("pid") == death["pid"] and w.get("session_id") == barrier.get("session_id")
                for w in witnesses if isinstance(w, dict))
            and death.get("kind") == "intentional_process_death" and death.get("forced_termination") is True
            and death["exit_code"] != 0 and barrier.get("phase") == phase and barrier.get("pid") == death["pid"]
            and re.fullmatch(r"[0-9a-f]{32}", str(barrier.get("session_id", ""))) is not None,
            "Write-behind death lacks its matching real native/Main process barriers")
        expected = 4 if phase in ("after_publish", "newer_dirty_after_durable") else 0
        revision = 2 if expected == 4 else 1
        require(barrier.get("revision") == (2 if phase in ("after_publish","newer_dirty_after_durable") else 1),
            "Death marker disagrees with the actual pre-/post-publication manifest frontier")
        if phase in ("before_capture", "queued_dirty", "newer_dirty_after_durable"):
            require(barrier.get("live_native_tick") == (4 if phase == "before_capture" else 6)
                and barrier.get("durable_native_tick") == (4 if phase == "newer_dirty_after_durable" else 0),
                "Crash marker does not witness real newer dirty native work")
        if phase == "queued_dirty":
            require(barrier.get("queued_requests") == 1, "Write-behind process death lost pending coalesced work")
        require(len({death["pid"], first["pid"], repeat["pid"]}) == 3, "Recovery reused a process identity")
        for child in (first, repeat):
            oracle = child.get("durable_oracle", {})
            clock = oracle.get("clock", {}) if isinstance(oracle, dict) else {}
            area = oracle.get("areas", {}) if isinstance(oracle, dict) else {}
            require(child.get("kind") == "fresh_process_recovery" and child["exit_code"] == 0
                and child.get("observed_pid") == child["pid"] and child.get("expected_tick") == expected
                and type(child.get("launcher_pid")) is int and child["launcher_pid"] > 0
                and (platform == "nt" or child["pid"] == child["launcher_pid"])
                and child.get("checks", 0) >= 8 and child.get("session_id") == barrier["session_id"]
                and re.fullmatch(r"[0-9a-f]{64}", str(child.get("native_sha256", ""))) is not None
                and re.fullmatch(r"[0-9a-f]{16}", str(child.get("physical_hash", ""))) is not None
                and oracle.get("revision") == revision and oracle.get("game_ticks") == expected
                and clock.get("game_ticks") == expected and set(area) == {"a","b","c"}
                and all(area[id].get("completed_tick") == (expected if id == "a" else 0)
                    and area[id].get("mutation_generation") == (1 if id == "a" and expected == 4 else 0)
                    and (id != "a" or area[id].get("native_sha256") == child["native_sha256"])
                    for id in ("a","b","c")),
                "Fresh recovery lacks the exact independent durable-area/native/clock oracle")
        require(all(first.get(key) == repeat.get(key) for key in
            ("session_id", "native_sha256", "physical_hash", "expected_tick", "durable_oracle")),
            "Repeated reopening changed authored, native, or accounted durable authority")
        if phase == "newer_dirty_after_durable":
            seed = death.get("seed", {})
            baseline = seed.get("baseline", {}) if isinstance(seed, dict) else {}
            require(seed.get("ok") is True and seed.get("exit_code") == 0
                and type(seed.get("pid")) is int and seed.get("pid") > 0
                and type(seed.get("launcher_pid")) is int and seed.get("launcher_pid") > 0
                and (platform == "nt" or seed["pid"] == seed["launcher_pid"])
                and type(baseline.get("launcher_pid")) is int
                and (platform == "nt" or baseline["pid"] == baseline["launcher_pid"])
                and len({seed["pid"], baseline.get("pid"), death["pid"], first["pid"], repeat["pid"]}) == 5
                and baseline.get("kind") == "fresh_process_recovery"
                and baseline.get("session_id") == barrier["session_id"]
                and baseline.get("durable_oracle") == first.get("durable_oracle")
                and baseline.get("native_sha256") == first.get("native_sha256"),
                "Older acknowledged durable state did not survive newer unsaved mutations")
        else:
            require("seed" not in death, "Unexpected seed process in an unseeded death case")


def verify_cold_benchmark(parent: dict, proof: dict, label: str) -> None:
    require(label in ("donor-cold", "successor-cold"), "Unknown benchmark role")
    before = proof.get("source_before", {})
    expected_source = "d0d043f4740ffed5f0dbb4120e437458d7a9bd57" if label == "donor-cold" else parent["source_commit"]
    donor_native = "1198c1a252cba4ae9ee14371f7b386f685155438bd3556b8640f04f9253ea977" if parent["platform"] == "linux" else "408283d6a5cf4db3830a20b971eb614f17161890bf268c63c405bdc2d219479f"
    require(proof.get("schema") == "gen006-ramcache-travel-benchmark-v1" and proof.get("status") == "passed"
        and proof.get("diagnostic") is False and proof.get("graphical") is True and proof.get("exit_code") == 0
        and before.get("source_commit") == expected_source and before.get("local_delta") == []
        and before.get("missing_source_inputs") == [] and before == proof.get("source_after")
        and all(proof.get(key) is True for key in ("source_unchanged", "binaries_unchanged", "harness_unchanged"))
        and proof.get("godot_sha256") == parent["engine_sha256"]
        and proof.get("native_sha256") == (donor_native if label == "donor-cold" else parent["native_sha256"]),
        "Controlled cold comparison source/runtime/custody differs")
    inputs = parent["source_inputs_sha256"]
    require(proof.get("harness_sha256") == inputs.get("tools/ci/run_persistent_area_travel_benchmark.py")
        and proof.get("script_sha256") == inputs.get("tools/ci/benchmark_persistent_area_travel.gd")
        and before.get("source_inputs_sha256", {}).get("godot/scripts/persistent_area_fixtures.gd")
            == inputs.get("godot/scripts/persistent_area_fixtures.gd"), "Cold comparison changed the fixture or harness")
    receipt = proof.get("receipt", {})
    require(type(proof.get("pid")) is int and proof["pid"] > 0 and receipt.get("pid") == proof["pid"]
        and receipt.get("passed") is True and receipt.get("failures") == [] and receipt.get("workers") == 1
        and receipt.get("fixture_extent") == [512, 512] and receipt.get("graphics") not in (None, "", "headless")
        and receipt.get("renderer") and receipt.get("rendering_method") == "gl_compatibility",
        "Cold comparison lacks actual graphical/native process evidence")
    rows = [row for row in receipt.get("rows", []) if row.get("kind") == "travel"]
    require(len(rows) == 30 and all(row.get("native_tick") == 0 and row.get("game_tick") == 0
        and row.get("source") == ("a", "b", "c")[index % 3]
        and row.get("target") == ("b", "c", "a")[index % 3]
        and finite_nonnegative(row.get("elapsed_ms")) and finite_nonnegative(row.get("max_frame_gap_ms"))
        for index, row in enumerate(rows)),
        "Cold comparison performed a different workload or area mix")
    times = sorted(row["elapsed_ms"] for row in rows)
    expected = {"samples": 30, "p50_ms": (times[14]+times[15])/2, "p95_ms": times[math.ceil(30*0.95)-1],
        "worst_ms": times[-1], "maximum_correlated_main_frame_ms": max(row["max_frame_gap_ms"] for row in rows)}
    require(proof.get("statistics") == expected and proof.get("samples"), "Cold statistics differ from original samples")
    if label == "donor-cold":
        provenance = proof.get("donor_runtime_provenance", {})
        require(provenance.get("sha256") == donor_native
            and provenance.get("source_commit") == "1ceac7e3d4d9e9f6b24833ced340286a4a15d01e"
            and provenance.get("source_inputs") and all(before.get("source_inputs_sha256", {}).get(path) == digest
                for path, digest in provenance["source_inputs"].items()),
            "Donor runtime is not its published source-matched product binary")
    else:
        require(before.get("source_tree") == parent["source_tree"] and before.get("source_inputs_sha256")
            and all(inputs.get(path) == digest for path, digest in before["source_inputs_sha256"].items()),
            "Successor cold comparison did not execute the qualified source")


def verify_ramcache(value: dict) -> None:
    require(value.get("ramcache_schema") == "gen006-ramcache-qualification-v1", "RAM-cache qualification is absent")
    rows = value.get("ramcache", {})
    for workers in (1, 4):
        first = rows.get(f"ramcache-write-w{workers}", {})
        second = rows.get(f"ramcache-reopen-w{workers}", {})
        for receipt in (first, second):
            require(receipt.get("schema") == "gen006-ramcache-workbench-v1" and receipt.get("failures") == []
                and receipt.get("graphical") is True and type(receipt.get("checks")) is int and receipt["checks"] > 0,
                "Actual graphical RAM-cache write/reopen evidence is incomplete")
        require(type(first.get("process_id")) is int and type(second.get("process_id")) is int
            and first["process_id"] > 0 and second["process_id"] > 0 and first["process_id"] != second["process_id"],
            "RAM-cache restore requires distinct real process identities")
        for kind in ("hot", "warm"):
            samples = first.get(kind+"_samples", [])
            require(isinstance(samples, list) and len(samples) == 30, "Exactly thirty qualified "+kind+" samples are required")
            for index, sample in enumerate(samples):
                verify_operation_timing(sample)
                require(sample.get("residency") == kind.upper() and sample.get("status") == "completed"
                    and sample.get("debt_before_ticks") == 0 and sample.get("native_ticks_executed") == 0
                    and sample.get("source_area") == ("a", "b", "c")[index % 3]
                    and sample.get("target_area") == ("b", "c", "a")[index % 3]
                    and sample.get("game_tick_before") == 0 and sample.get("game_tick_after") == 0
                    and sample.get("target_native_tick_before") == 0 and sample.get("target_native_tick_after") == 0
                    and finite_nonnegative(sample.get("elapsed_ms")),
                    "Residency benchmark contains a failed or incomparable workload or area mix")
                before, after = sample.get("io_before", {}), sample.get("io_after", {})
                keys = ("profile_read_calls", "native_deserializations", "source_constructions", "synchronous_publications") \
                    if kind == "hot" else ("profile_read_calls",)
                require(all(type(before.get(key)) is int and before[key] == after.get(key) for key in keys),
                    "Qualified hot/warm path repeated forbidden target I/O or reconstruction")
                if kind == "warm":
                    require(after.get("native_deserializations") == before.get("native_deserializations", -2)+1,
                        "WARM evidence does not identify its actual native reconstruction")
                    fs_before, fs_after = sample.get("filesystem_before", {}), sample.get("filesystem_after", {})
                    require(fs_before.get("available") is True and fs_after.get("available") is True
                        and all(type(fs_before.get(key)) is int and fs_before[key] == fs_after.get(key)
                            for key in ("checkpoint_read_requests", "checkpoint_read_bytes", "read_system_calls",
                                        "write_system_calls", "publication_calls")), "WARM evidence performed actual profile filesystem I/O")
                    require(sample.get("native_after", {}).get("native_restorations") ==
                        sample.get("native_before", {}).get("native_restorations", -2)+1,
                        "WARM sample omitted its actual native restoration")
            reported = value.get("ramcache_performance", {}).get(str(workers), {}).get(kind+"_zero_debt")
            require(reported == timing_statistics(samples), "Reported "+kind+" statistics differ from original qualified samples")
        before, after = first.get("native_before", {}), first.get("native_after", {})
        require(all(type(before.get(key)) is int and before[key] == after.get(key)
            for key in ("native_restorations", "source_constructions", "captures")),
            "Native counters contradict genuine zero-reconstruction HOT residency")
        require(after.get("hot_activations", 0)-before.get("hot_activations", 0) == len(first["hot_samples"]),
            "Every qualified HOT sample must perform exactly one native owner handoff")
        before, after = first.get("filesystem_before", {}), first.get("filesystem_after", {})
        require(before.get("available") is True and after.get("available") is True
            and all(type(before.get(key)) is int and before[key] == after.get(key) for key in (
                "checkpoint_read_requests", "checkpoint_read_bytes", "read_system_calls", "write_system_calls",
                "write_bytes", "file_flush_calls", "directory_flush_calls", "publication_calls")),
            "Actual filesystem telemetry contradicts the zero-I/O HOT path")
        io = first.get("evidence", {}).get("cache_io", {})
        require(io.get("prefetch_completed", 0) > 0 and io.get("prefetch_hits", 0) > 0
            and io.get("background_publications", 0) > 0,
            "Predictive preparation, real arrival reuse or background publication was never exercised")
        memory = value.get("ramcache_memory", {}).get(str(workers), {})
        require(memory.get("ok") is True and memory.get("native_sha256") == value.get("native_sha256")
            and memory.get("godot_sha256") == value.get("engine_sha256") and memory.get("configured_workers") == workers
            and type(memory.get("pid")) is int and memory["pid"] > 0 and memory.get("exit_code") == 0
            and memory.get("binaries_unchanged") is True and memory.get("source_inputs_unchanged") is True
            and memory.get("harness_unchanged") is True and memory.get("peak_sampled_rss_bytes", 0) > 0 and memory.get("samples"),
            "Actual native residency memory measurements are missing")
        phases = memory.get("phases", [])
        completed = memory.get("completed", {})
        require(completed.get("ok") is True and completed.get("failures") == []
            and completed.get("configured_workers") == workers and completed.get("phases") == len(phases)
            and len(phases) == 15 and all(phase.get("pid") == memory["pid"] and phase.get("workers") == workers for phase in phases)
            and {"one_hot_world", "two_hot_worlds", "three_hot_worlds", "two_hot_one_warm",
                 "two_hot_after_180_handoffs", "one_hot_buffers_released"}.issubset({phase.get("label") for phase in phases}),
            "Native memory phase receipts are incomplete or belong to another process")
        require(memory.get("source_inputs") and all(value.get("source_inputs_sha256", {}).get(path) == digest
            for path, digest in memory["source_inputs"].items())
            and memory.get("harness_sha256") == value.get("source_inputs_sha256", {}).get("tools/ci/run_persistent_area_residency_memory.py"),
            "Native memory input/harness custody differs from the campaign")
    verify_recovery(value, value.get("ramcache_recovery", {}))


def verify_resident_storage_recovery(parent: dict, pair: dict) -> None:
    """Bind storage Retry to retained native authority and independent restart."""
    require(isinstance(pair, dict) and set(pair) == {"write", "reopen"},
        "Resident storage recovery needs a writer and independent reopening")
    writer, reopened = pair["write"], pair["reopen"]
    valid_hash = lambda value, size=64: isinstance(value, str) and re.fullmatch(r"[0-9a-f]{%d}" % size, value)
    integer = lambda value: type(value) is int and 0 <= value <= 9007199254740991

    def validate_clock(value: dict) -> None:
        require(isinstance(value, dict) and set(value) == {"version", "game_ticks", "areas"}
            and integer(value.get("version")) and value["version"] == 1 and integer(value.get("game_ticks"))
            and set(value.get("areas", {})) == {"a", "b", "c"}, "Recovery clock has an invalid shape or game frontier")
        for frontier in value["areas"].values():
            require(set(frontier) == {"accounted_ticks", "native_ticks", "origin_game_tick"}
                and all(integer(tick) for tick in frontier.values())
                and frontier["accounted_ticks"] <= value["game_ticks"]
                and frontier["origin_game_tick"]+frontier["native_ticks"] == frontier["accounted_ticks"],
                "Recovery native, origin and accounted clock disagree")
    writer_pid = writer.get("process_id")
    require(type(writer_pid) is int and writer_pid > 0 and type(reopened.get("process_id")) is int
        and reopened["process_id"] > 0 and reopened["process_id"] != writer_pid,
        "Resident recovery must execute in two distinct actual processes")
    for mode, proof in pair.items():
        require(proof.get("schema") == "gen006-resident-storage-recovery-v1" and proof.get("mode") == mode
            and proof.get("graphical") is True and proof.get("completed") is True and proof.get("failures") == []
            and type(proof.get("checks")) is int and proof["checks"] > 0
            and proof.get("originating_write_process_id") == writer_pid
            and valid_hash(proof.get("session_id"), 32)
            and valid_hash(proof.get("expected_reopen_sha256")),
            "Resident recovery lacks a successful graphical process receipt")
    expected = writer.get("expected_reopen", {})
    require(expected == reopened.get("expected_reopen") and expected.get("session_id") == writer["session_id"]
        == reopened["session_id"] and expected.get("originating_write_process_id") == writer_pid
        and writer["expected_reopen_sha256"] == reopened["expected_reopen_sha256"]
        and set(expected.get("areas", {})) == {"a", "b", "c"}
        and set(reopened.get("actual_areas", {})) == {"a", "b", "c"},
        "Independent resident recovery differs from its acknowledged writer oracle")
    clock = expected.get("clock", {})
    validate_clock(clock)
    for proof in pair.values():
        evidence = proof.get("evidence", {})
        manifest = evidence.get("manifest", {})
        require(evidence.get("process_id") == proof["process_id"] and evidence.get("clock") == clock
            and manifest.get("clock") == clock and manifest.get("session_id") == expected["session_id"]
            and set(manifest.get("areas", {})) == {"a", "b", "c"},
            "Recovery oracle contradicts the actual process clock or acknowledged manifest")
        for area in ("a", "b", "c"):
            require(all(manifest["areas"][area].get(key) == expected["areas"][area].get(key)
                for key in ("native_sha256", "physical_hash", "completed_tick", "authoring_sha256", "authored_source_sha256")),
                "Recovery oracle contradicts its actual saved native or authoring identity")
    require(type(clock.get("game_ticks")) is int and clock["game_ticks"] > 0
        and set(clock.get("areas", {})) == {"a", "b", "c"}, "Recovery oracle has no completed game-time frontier")
    for area in ("a", "b", "c"):
        wanted, actual, frontier = expected["areas"][area], reopened["actual_areas"][area], clock["areas"][area]
        require(all(valid_hash(wanted.get(key), size) and actual.get(key) == wanted[key]
            for key, size in (("native_sha256", 64), ("physical_hash", 16), ("authoring_sha256", 64),
                              ("authored_source_sha256", 64)))
            and type(wanted.get("completed_tick")) is int and wanted["completed_tick"] >= 0
            and actual.get("completed_tick") == wanted["completed_tick"] == frontier.get("native_ticks")
            and frontier.get("accounted_ticks") == clock["game_ticks"],
            "Independent restart lost native, authored or accounted state for area "+area)
    cases = writer.get("cases", [])
    require(isinstance(cases, list) and [(row.get("kind"), row.get("residency"), row.get("fault")) for row in cases] == [
        ("ahead", None, None), ("unpublished_save", None, None), ("save", None, None),
        ("destination", "COLD", "before_publish"), ("destination", "COLD", "after_publish"),
        ("destination", "WARM", "after_publish")], "Resident publication failure cases are incomplete or duplicated")
    for case in cases:
        source = case.get("source_area", "a")
        before, after = case.get("before_native", {}), case.get("after_native", {})
        left, right = before.get("active", {}), after.get("active", {})
        resident_clock = case.get("retained_clock" if case["kind"] == "destination" else "clock", {})
        validate_clock(resident_clock)
        for snapshot in (before, after):
            entries = snapshot.get("entries", [])
            require(snapshot.get("ok") is True and isinstance(entries, list) and 1 <= len(entries) <= 3
                and snapshot.get("active") in entries and sum(entry.get("active") is True for entry in entries) == 1
                and snapshot.get("inactive") == [entry for entry in entries if entry.get("active") is False]
                and len({entry.get("handle") for entry in entries}) == len(entries)
                and len({entry.get("identity", {}).get("area_id") for entry in entries}) == len(entries),
                "Resident Retry snapshot has a failed, missing or duplicated native registry owner")
            for entry in entries:
                identity = entry.get("identity", {})
                area = identity.get("area_id")
                require(area in ("a", "b", "c") and entry.get("schema") == 1 and entry.get("failed") is False
                    and type(entry.get("active")) is bool and integer(entry.get("handle")) and entry["handle"] > 0
                    and integer(entry.get("resident_generation")) and entry["resident_generation"] > 0
                    and integer(entry.get("mutation_generation")) and entry["mutation_generation"] > 0
                    and entry.get("worker_threads") == 1 and type(entry.get("worker_threads")) is int
                    and integer(entry.get("native_bytes")) and entry["native_bytes"] > 0
                    and entry.get("completed_tick") == resident_clock["areas"][area]["native_ticks"]
                    and identity.get("session_id") == writer["session_id"]
                    and identity.get("runtime_sha256") == parent.get("native_sha256")
                    and identity.get("authored_source_sha256") == expected["areas"][area]["authored_source_sha256"]
                    and identity.get("incarnation") == writer["evidence"]["manifest"]["areas"][area].get("incarnation")
                    and entry.get("physics_profile_sha256") == writer["evidence"]["manifest"]["areas"][area].get("physics_profile_sha256"),
                    "Resident native registry contradicts its session, source, physics or completed time")
            owner = snapshot.get("owner_fence", {})
            require(owner.get("completed_tick") == snapshot["active"].get("completed_tick")
                and owner.get("mutation_generation") == snapshot["active"].get("mutation_generation")
                and owner.get("operation_id") == "" and integer(owner.get("world_generation"))
                and owner["world_generation"] > 0
                and snapshot.get("native_bytes") == sum(entry["native_bytes"] for entry in entries),
                "Recovery observation contradicts its acknowledged native lease or registry memory")
        require(all(before.get(key) == after.get(key) for key in ("entries", "inactive", "owner_fence", "native_bytes")),
            "Storage Retry changed the retained registry or its owner fence")
        counter_keys = {"admissions", "captures", "hot_activations", "imports", "native_restorations",
            "private_ticks", "releases", "source_constructions"}
        require(set(before.get("counters", {})) == set(after.get("counters", {})) == counter_keys
            and all(integer(before["counters"][key]) and integer(after["counters"][key])
                and after["counters"][key] == before["counters"][key]+(2 if key == "captures" and case["kind"] == "unpublished_save" else 0)
                for key in counter_keys), "Recovery executed unexpected native work or changed registry lifetime")
        require(source in ("a", "b", "c") and left == right and left.get("active") is True
            and left.get("failed") is False and type(left.get("handle")) is int and left["handle"] > 0
            and type(left.get("completed_tick")) is int and left["completed_tick"] >= 0
            and type(left.get("mutation_generation")) is int and left["mutation_generation"] > 0
            and left.get("identity", {}).get("area_id") == source
            and left["identity"].get("session_id") == writer["session_id"]
            and left["identity"].get("runtime_sha256") == parent.get("native_sha256")
            and left["identity"].get("authored_source_sha256") == expected["areas"][source]["authored_source_sha256"],
            "Storage Retry replaced or changed the retained source native authority")
        for counter in ("native_restorations", "source_constructions"):
            count = before.get("counters", {}).get(counter)
            require(type(count) is int and count >= 0 and after.get("counters", {}).get(counter) == count,
                "Storage reconciliation performed another native restoration or source construction")
        if case["kind"] != "unpublished_save":
            for counter in ("profile_read_calls", "native_deserializations", "source_constructions", "synchronous_publications"):
                count = case.get("io_before", {}).get(counter)
                require(type(count) is int and count >= 0 and case.get("io_after", {}).get(counter) == count,
                    "Resident Retry repeated target loading, restoration or publication")
        if case["kind"] != "destination":
            require(valid_hash(case.get("published_native_sha256")) and valid_hash(case.get("previous_native_sha256"))
                and case["published_native_sha256"] != case["previous_native_sha256"]
                and case.get("clock", {}).get("areas", {}).get(source, {}).get("native_ticks") == left["completed_tick"],
                "Resident publication did not preserve a real edited or progressed native snapshot")
            if case["kind"] != "unpublished_save":
                completed = case.get("completed_ticks")
                require(type(completed) is int and (0 < completed <= 12 if case["kind"] == "ahead" else completed == 0)
                    and type(case.get("published_revision")) is int and case["published_revision"] > 0,
                    "Lost-ACK recovery reports an invalid actual native interval or publication revision")
            continue
        target, old, retained = case.get("target_area"), case.get("clock_before", {}), case.get("retained_clock", {})
        completed = case.get("completed_ticks")
        validate_clock(old)
        validate_clock(retained)
        require(target in ("a", "b", "c") and target != source and type(completed) is int and completed > 0
            and old.get("game_ticks") == retained.get("game_ticks")
            and set(old.get("areas", {})) == set(retained.get("areas", {})) == {"a", "b", "c"}
            and all(old["areas"][area] == retained["areas"][area] for area in ("a", "b", "c") if area != target)
            and retained["areas"][target].get("native_ticks") == old["areas"][target].get("native_ticks", -1)+completed
            and retained["areas"][target].get("accounted_ticks") == old["areas"][target].get("accounted_ticks", -1)+completed
            and retained["areas"][target]["accounted_ticks"] <= retained["game_ticks"]
            and case.get("retained_native_tick") == retained["areas"][target]["native_ticks"]
            and valid_hash(case.get("retained_native_sha256"))
            and valid_hash(case.get("source_native_sha256"))
            and case["source_native_sha256"] == case.get("source_native_sha256_after")
            and type(case.get("pending_reservations")) is int and case["pending_reservations"] == 0,
            "Retained WARM publication lost native work, changed source, duplicated time or leaked reservations")
        activation = case.get("activation", {})
        extra = activation.get("completed_ticks")
        require(activation.get("residency") == "WARM" and activation.get("target_area") == target
            and activation.get("source_area") == source and type(extra) is int and extra >= 0
            and activation.get("kind") == "travel" and activation.get("requested_future_ticks") == 0
            and activation.get("remaining_future_ticks") == 0
            and activation.get("game_tick_before") == retained["game_ticks"]
            and activation.get("debt_before_ticks") == retained["game_ticks"]-retained["areas"][target]["accounted_ticks"]
            and extra <= activation["debt_before_ticks"]
            and activation.get("native_ticks_executed") == extra
            and activation.get("plan_source_native_tick") == case["retained_native_tick"]
            and case.get("activated_native_tick") == case["retained_native_tick"]+extra
            and valid_hash(case.get("activated_native_sha256"))
            and (extra > 0 or case["activated_native_sha256"] == case["retained_native_sha256"]),
            "Later WARM activation repeated the already retained native interval")


def _validate_advance_clock(clock: dict) -> None:
    integer = lambda value: type(value) is int and 0 <= value <= 9007199254740991
    require(isinstance(clock, dict) and set(clock) == {"version", "game_ticks", "areas"}
        and type(clock.get("version")) is int and clock["version"] == 1 and integer(clock.get("game_ticks"))
        and isinstance(clock.get("areas"), dict) and set(clock["areas"]) == {"a", "b", "c"},
        "Advancement clock has an invalid shape or global frontier")
    for frontier in clock["areas"].values():
        require(isinstance(frontier, dict) and set(frontier) == {"accounted_ticks", "native_ticks", "origin_game_tick"}
            and all(integer(value) for value in frontier.values())
            and frontier["accounted_ticks"] <= clock["game_ticks"]
            and frontier["origin_game_tick"]+frontier["native_ticks"] == frontier["accounted_ticks"],
            "Advancement native, origin and accounted time disagree")


def _advance_clock_completion(clock: dict, plan: dict, actual: int) -> dict:
    """Independently recompute one bounded, debt-first native prefix."""
    _validate_advance_clock(clock)
    integer = lambda value: type(value) is int and 0 <= value <= 9007199254740991
    fields = {"version", "area_id", "mode", "source_clock_sha256", "source_native_tick", "source_debt_ticks",
        "requested_future_ticks", "max_work_ticks", "work_ticks", "debt_work_ticks", "future_work_ticks"}
    require(isinstance(plan, dict) and set(plan) == fields and plan.get("area_id") in ("a", "b", "c")
        and plan.get("mode") in ("ahead", "catch_up")
        and all(integer(plan[key]) for key in fields-{"area_id", "mode", "source_clock_sha256"})
        and plan["version"] == 1 and 1 <= plan["max_work_ticks"] <= 600
        and plan["requested_future_ticks"] <= 36000
        and (plan["mode"] == "ahead" or plan["requested_future_ticks"] == 0),
        "Advancement plan is malformed or exceeds its fixed work domain")
    area = plan["area_id"]
    debt = clock["game_ticks"]-clock["areas"][area]["accounted_ticks"]
    paid = min(debt, plan["max_work_ticks"])
    future = min(plan["requested_future_ticks"], plan["max_work_ticks"]-paid,
        9007199254740991-clock["game_ticks"]) if plan["mode"] == "ahead" else 0
    require(plan["source_native_tick"] == clock["areas"][area]["native_ticks"] and plan["source_debt_ticks"] == debt
        and plan["debt_work_ticks"] == paid and plan["future_work_ticks"] == future and plan["work_ticks"] == paid+future
        and plan["source_clock_sha256"] == hashlib.sha256(json.dumps(clock, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        and integer(actual) and actual <= plan["work_ticks"],
        "Advancement plan or actual interval differs from its original clock")
    result = json.loads(json.dumps(clock))
    debt_paid = min(actual, paid)
    advanced = actual-debt_paid
    result["game_ticks"] += advanced
    result["areas"][area]["accounted_ticks"] += actual
    result["areas"][area]["native_ticks"] += actual
    return {"ok": True, "clock": result, "completed_ticks": actual, "paid_debt_ticks": debt_paid,
        "game_advanced_ticks": advanced, "remaining_future_ticks": plan["requested_future_ticks"]-advanced,
        "debt_ticks": result["game_ticks"]-result["areas"][area]["accounted_ticks"]}


def verify_resident_advance_recovery(parent: dict, pair: dict) -> None:
    """Bind late native work, accounted prefixes, owner cleanup and restart."""
    require(isinstance(pair, dict) and set(pair) == {"write", "reopen"}, "Late advancement needs two original processes")
    writer, reopened = pair["write"], pair["reopen"]
    integer = lambda value: type(value) is int and 0 <= value <= 9007199254740991
    digest = lambda value, size=64: isinstance(value, str) and re.fullmatch(r"[0-9a-f]{%d}" % size, value)
    pid = writer.get("process_id")
    require(integer(pid) and pid > 0 and integer(reopened.get("process_id")) and reopened["process_id"] > 0
        and reopened["process_id"] != pid, "Late advancement reopening reused its originating process")
    for mode, proof in pair.items():
        require(proof.get("schema") == "gen006-resident-advance-recovery-v1" and proof.get("mode") == mode
            and proof.get("graphical") is True and proof.get("completed") is True and proof.get("failures") == []
            and integer(proof.get("checks")) and proof["checks"] > 0
            and proof.get("originating_write_process_id") == pid and digest(proof.get("session_id"), 32)
            and digest(proof.get("expected_reopen_sha256")), "Late advancement lacks a complete original graphical receipt")
    oracle = writer.get("expected_reopen", {})
    require(oracle == reopened.get("expected_reopen") and oracle.get("originating_write_process_id") == pid
        and oracle.get("session_id") == writer["session_id"] == reopened["session_id"]
        and writer["expected_reopen_sha256"] == reopened["expected_reopen_sha256"]
        and set(oracle.get("areas", {})) == set(reopened.get("actual_areas", {})) == {"a", "b", "c"},
        "Late advancement restart differs from its acknowledged three-area oracle")
    final_clock = oracle.get("clock", {})
    _validate_advance_clock(final_clock)
    for proof in pair.values():
        evidence = proof.get("evidence", {})
        manifest = evidence.get("manifest", {})
        require(evidence.get("process_id") == proof["process_id"] and evidence.get("clock") == final_clock
            and manifest.get("clock") == final_clock and manifest.get("session_id") == writer["session_id"],
            "Late advancement oracle differs from actual durable process state")
        for area in ("a", "b", "c"):
            wanted, actual = oracle["areas"][area], reopened["actual_areas"][area]
            for key, size in (("native_sha256", 64), ("physical_hash", 16), ("authoring_sha256", 64), ("authored_source_sha256", 64)):
                require(digest(wanted.get(key), size) and actual.get(key) == wanted[key]
                    and manifest.get("areas", {}).get(area, {}).get(key) == wanted[key],
                    "Late advancement restart lost full native or authored identity")
            require(integer(wanted.get("completed_tick")) and actual.get("completed_tick") == wanted["completed_tick"]
                == final_clock.get("areas", {}).get(area, {}).get("native_ticks")
                and manifest["areas"][area].get("completed_tick") == wanted["completed_tick"]
                and final_clock["areas"][area].get("accounted_ticks") == final_clock.get("game_ticks"),
                "Late advancement restart lost completed native or accounted time")

    def registry(snapshot: dict, clock: dict, source: str, free_owner: bool = True) -> dict:
        entries = snapshot.get("entries", [])
        require(snapshot.get("ok") is True and isinstance(entries, list) and len(entries) == 3
            and snapshot.get("active") in entries and sum(entry.get("active") is True for entry in entries) == 1
            and snapshot.get("inactive") == [entry for entry in entries if entry.get("active") is False]
            and len({entry.get("handle") for entry in entries}) == 3,
            "Late advancement native registry is incomplete or duplicates ownership")
        by_area = {entry.get("identity", {}).get("area_id"): entry for entry in entries}
        require(set(by_area) == {"a", "b", "c"} and snapshot["active"] == by_area[source],
            "Late advancement changed the active source or area identity")
        for area, entry in by_area.items():
            identity = entry.get("identity", {})
            saved = writer["evidence"]["manifest"]["areas"][area]
            require(type(entry.get("schema")) is int and entry["schema"] == 1 and entry.get("failed") is False
                and type(entry.get("active")) is bool and entry["active"] == (area == source)
                and all(integer(entry.get(key)) for key in ("handle", "resident_generation", "mutation_generation", "completed_tick", "native_bytes", "native_reservation_bytes"))
                and entry["handle"] > 0 and entry["resident_generation"] > 0 and entry["native_bytes"] > 0
                and entry["native_reservation_bytes"] >= entry["native_bytes"]
                and type(entry.get("worker_threads")) is int and entry["worker_threads"] == 1
                and entry["completed_tick"] == clock["areas"][area]["native_ticks"]
                and identity.get("session_id") == writer["session_id"] and identity.get("runtime_sha256") == parent.get("native_sha256")
                and identity.get("authored_source_sha256") == oracle["areas"][area]["authored_source_sha256"]
                and identity.get("incarnation") == saved.get("incarnation")
                and entry.get("physics_profile_sha256") == saved.get("physics_profile_sha256"),
                "Late advancement registry contradicts native state, source, runtime or execution identity")
        require(snapshot.get("native_bytes") == sum(entry["native_bytes"] for entry in entries),
            "Late advancement registry memory contradicts its retained owners")
        if free_owner:
            fence = snapshot.get("owner_fence", {})
            require(fence.get("operation_id") == "" and integer(fence.get("world_generation")) and fence["world_generation"] > 0
                and fence.get("completed_tick") == by_area[source]["completed_tick"]
                and fence.get("mutation_generation") == by_area[source]["mutation_generation"],
                "Late advancement has no actual released owner acknowledgement")
        return by_area

    def status_clock(status: dict, clock: dict) -> None:
        require(status.get("session_id") == writer["session_id"] and status.get("game_tick") == clock["game_ticks"]
            and set(status.get("areas", {})) == {"a", "b", "c"}, "Resident status has the wrong session or global time")
        for area in ("a", "b", "c"):
            value = status["areas"][area]
            require(value.get("accounted_tick") == clock["areas"][area]["accounted_ticks"]
                and value.get("completed_tick") == clock["areas"][area]["native_ticks"]
                and value.get("debt_ticks") == clock["game_ticks"]-clock["areas"][area]["accounted_ticks"],
                "Resident status disagrees with its admitted per-area prefix")

    cases = writer.get("cases", [])
    require(isinstance(cases, list) and [row.get("kind") for row in cases] == ["inactive_debt", "active_debt", "ahead_debt_future"],
        "Late advancement cases are missing, duplicated or reordered")
    for index, case in enumerate(cases):
        source, target = case.get("source_area"), case.get("target_area")
        base, plan = case.get("base_clock", {}), case.get("plan", {})
        prefix, late = case.get("acknowledged_prefix_ticks"), case.get("late_ticks")
        require(source == ("a" if index == 0 else "b") and target == "b" and plan.get("area_id") == target
            and integer(prefix) and integer(late) and 0 < prefix <= 32 and 0 < late <= 32
            and integer(case.get("timeout_elapsed_msec")) and case["timeout_elapsed_msec"] >= 30000,
            "Late advancement did not exercise a positive prefix and late bounded native slice")
        prefix_completion = _advance_clock_completion(base, plan, prefix)
        completed = _advance_clock_completion(base, plan, prefix+late)
        require(case.get("expected_completion") == completed and plan["max_work_ticks"] == 600
            and plan["requested_future_ticks"] == (64 if index == 2 else 0)
            and (plan["source_debt_ticks"] == 1 and completed["game_advanced_ticks"] == prefix+late-1 if index == 2
                else completed["game_advanced_ticks"] == 0), "Late work was reclassified as active time or credited twice")
        before = registry(case.get("before_native", {}), base, source)
        after = registry(case.get("after_native", {}), completed["clock"], source)
        require(case.get("before_cache", {}).get("hot") == before[target]
            and case.get("before_source", {}).get("hot") == before[source]
            and case.get("after_cache", {}).get("hot") == after[target]
            and case.get("after_source", {}).get("hot") == after[source]
            and case["after_cache"].get("completed_tick") == after[target]["completed_tick"],
            "Late native work and cache receipt do not describe the same retained owner")
        slices = case.get("slices", [])
        require(isinstance(slices, list) and len(slices) == 2 and all(integer(s.get("token")) and s["token"] > 0 for s in slices)
            and slices[0]["token"] != slices[1]["token"]
            and all(integer(s.get("native_completed_usec")) and s["native_completed_usec"] > 0 for s in slices)
            and slices[0]["native_completed_usec"] <= slices[1]["native_completed_usec"],
            "Late advancement has no distinct original positive native completions")
        previous = before[target]
        for position, ticks in enumerate((prefix, late)):
            result = slices[position].get("result", {})
            receipt = result.get("receipt", {})
            require(result.get("ok") is True and result.get("completed_ticks") == ticks
                and result.get("current_tick") == previous["completed_tick"]+ticks
                and receipt.get("completed_tick") == result["current_tick"] and receipt.get("failed") is False
                and all(receipt.get(key) == previous[key] for key in ("handle", "identity", "resident_generation", "worker_threads", "physics_profile_sha256", "active"))
                and integer(receipt.get("mutation_generation")) and receipt["mutation_generation"] >= previous["mutation_generation"],
                "Late native completion contradicts its exact original target and interval")
            previous = receipt
        terminal, pending = case.get("terminal", {}), case.get("pending_at_timeout", {})
        operation = case.get("operation", {})
        token = pending.get("pending", {})
        require(terminal.get("ok") is True and terminal.get("status") == "complete" and terminal.get("lease_held") is True
            and terminal.get("result") == slices[1]["result"] and terminal.get("operation_id") == operation.get("operation_id")
            and digest(operation.get("operation_id"), 32) and pending.get("operation_id") == operation["operation_id"]
            and pending.get("session_id") == writer["session_id"] and pending.get("source_area") == source
            and pending.get("target_area") == target and pending.get("source_clock") == base and pending.get("plan") == plan
            and pending.get("accounted_ticks") == prefix and token.get("token") == slices[1]["token"]
            and token.get("kind") == ("resident_advance" if index == 0 else "advance_active")
            and token.get("start_tick") == plan["source_native_tick"]+prefix
            and token.get("max_ticks") == min(32, plan["work_ticks"]-prefix)
            and token.get("receipt") == slices[0]["result"]["receipt"],
            "Timeout lost its original plan, cumulative prefix or exact native request")
        before_retry, after_retry = case.get("before_retry", {}), case.get("after_retry", {})
        status_clock(before_retry, prefix_completion["clock"])
        status_clock(after_retry, completed["clock"])
        require(before_retry.get("resident_advancement") == pending and before_retry.get("ready") is False
            and before_retry.get("busy") is False and before_retry.get("active_area") == source
            and before_retry.get("quarantined") is True and before_retry.get("owner_cleanup_required") is True
            and before_retry.get("unresolved_worker") == {"token":slices[1]["token"], "operation_id":operation["operation_id"], "kind":token["kind"]}
            and after_retry.get("ready") is True and after_retry.get("busy") is False and after_retry.get("quarantined") is False
            and after_retry.get("active_area") == source and after_retry.get("resident_advancement") == {}
            and after_retry.get("unresolved_worker") == {} and after_retry.get("owner_cleanup_required") is False
            and after_retry.get("cache", {}).get("pending_reservations") == 0,
            "Late advancement did not retain then safely retire its exact native owner")
        require(operation.get("source_area") == source and operation.get("target_area") == target
            and operation.get("completed_ticks") == operation.get("native_ticks_executed") == prefix+late
            and operation.get("native_slice_count") == 2 and operation.get("remaining_future_ticks") == completed["remaining_future_ticks"]
            and operation.get("measurement_outcome") == "owner_recovered", "Late advancement metrics duplicate or omit verified native work")
        late_native = slices[1].get("native_status", {})
        observed_late = registry(late_native, completed["clock"], source, False)
        require(slices[1]["result"]["receipt"] == observed_late[target],
            "Late completion receipt differs from its actual retained native owner")
        for area in ("a", "b", "c"):
            require(all(after[area][key] == observed_late[area][key] for key in ("handle", "identity", "resident_generation", "mutation_generation", "completed_tick", "worker_threads", "physics_profile_sha256", "active", "failed")),
                "Retry changed native authority after the already completed late interval")
        require(case["after_native"].get("counters") == late_native.get("counters")
            and set(late_native.get("counters", {})) == {"admissions", "captures", "hot_activations", "imports", "native_restorations", "private_ticks", "releases", "source_constructions"}
            and all(integer(value) for value in late_native["counters"].values()), "Retry reconstructed, recaptured, advanced or released native state")
        native_identity = case.get("actual_native_identity", {})
        require(native_identity == slices[1].get("native_identity") and digest(native_identity.get("native_sha256"))
            and digest(native_identity.get("physical_hash"), 16) and native_identity.get("completed_tick") == after[target]["completed_tick"]
            and native_identity.get("authored_source_sha256") == oracle["areas"][target]["authored_source_sha256"],
            "Late Retry changed complete native continuation or authored source identity")
        for key in ("profile_read_calls", "native_deserializations", "source_constructions", "synchronous_publications"):
            require(integer(case.get("io_before", {}).get(key)) and case["io_before"][key] == case.get("io_after", {}).get(key),
                "Late Retry repeated source loading, native restoration or publication")
        filesystem = case.get("filesystem_before", {})
        require(filesystem == case.get("filesystem_after") and filesystem.get("available") is True
            and filesystem.get("acquired") is True and type(filesystem.get("schema")) is int and filesystem["schema"] == 1
            and type(filesystem.get("storage_owner_id")) is int and filesystem["storage_owner_id"] != 0
            and isinstance(filesystem.get("profile_directory"), str) and bool(filesystem["profile_directory"]),
            "Late recovery filesystem observations lack the same acquired profile owner or available counters")
        for key in ("read_requests", "read_system_calls", "read_bytes", "write_requests", "write_system_calls", "write_bytes", "publication_requests"):
            require(integer(case.get("filesystem_before", {}).get(key)) and case["filesystem_before"][key] == case.get("filesystem_after", {}).get(key),
                "Late resident recovery performed actual profile filesystem work")
        release = case.get("release_timeout", {})
        if index == 0:
            status_clock(release.get("status", {}), completed["clock"])
            guard = release["status"].get("resident_advancement", {})
            require(operation.get("cancel_requested") is True and release["status"].get("ready") is False
                and release["status"].get("quarantined") is True and release["status"].get("busy") is False
                and release["status"].get("active_area") == source
                and release["status"].get("owner_cleanup_required") is True and guard.get("pending") == {}
                and all(guard.get(key) == pending[key] for key in ("operation_id", "session_id", "source_area", "target_area", "source_clock", "plan"))
                and guard.get("accounted_ticks") == prefix+late
                and release["status"].get("unresolved_worker") == release.get("unresolved")
                and all(release.get("operation", {}).get(key) == operation.get(key) for key in (
                    "operation_id", "source_area", "target_area", "kind", "completed_ticks", "native_ticks_executed", "native_slice_count",
                    "game_tick_before", "debt_before_ticks", "requested_future_ticks", "remaining_future_ticks"))
                and release.get("unresolved", {}).get("kind") == "release"
                and release["unresolved"].get("operation_id") == operation["operation_id"]
                and integer(release["unresolved"].get("token")) and release["unresolved"]["token"] > slices[1]["token"],
                "Cancellation or delayed release discarded the already accounted native interval")
        else:
            require(release == {} and operation.get("cancel_requested") is False, "Unexpected release/cancellation case shape")
    require(cases[1]["base_clock"] == cases[0]["expected_completion"]["clock"], "Active-debt setup changed time during its pure ownership handoff")
    setup = writer.get("debt_setup", {})
    require(setup.get("target_area") == "b" and setup.get("base_clock") == cases[1]["expected_completion"]["clock"]
        and setup.get("clock") == cases[2]["base_clock"] and isinstance(setup.get("slices"), list) and setup["slices"],
        "Debt/future boundary has no actual independent native setup")
    total = 0
    previous = cases[1]["after_native"]["active"]
    for step in setup["slices"]:
        result = step.get("result", {})
        receipt = result.get("receipt", {})
        ticks = result.get("completed_ticks")
        require(step.get("before_receipt") == previous and integer(ticks) and 0 < ticks <= 32
            and result.get("ok") is True and result.get("current_tick") == previous["completed_tick"]+ticks
            and receipt.get("completed_tick") == result["current_tick"] and receipt.get("failed") is False
            and all(receipt.get(key) == previous[key] for key in ("handle", "identity", "resident_generation", "worker_threads", "physics_profile_sha256", "active"))
            and integer(receipt.get("mutation_generation")) and receipt["mutation_generation"] >= previous["mutation_generation"],
            "Debt setup fabricated or replayed native ticks or changed native authority")
        total += ticks
        require(step.get("accounted") == _advance_clock_completion(setup["base_clock"], setup.get("plan", {}), total),
            "Debt setup credited a different interval than actual native work")
        previous = result["receipt"]
    finished = _advance_clock_completion(setup["base_clock"], setup["plan"], total)
    require(setup.get("completed_ticks") == total and setup["clock"] == finished["clock"]
        and finished["debt_ticks"] == 1 and finished["game_advanced_ticks"] == 0
        and previous == cases[2]["before_native"]["active"],
        "Debt setup skipped time or failed to leave the real debt/future boundary")


def verify_qualification(*args, **kwargs) -> None:
    _verify_donor_qualification(*args, **kwargs)
    value = args[1] if len(args) > 1 else kwargs["value"]
    verify_ramcache_evidence(args[0] if args else kwargs["directory"], value, require_ordinary_water=True)


ORDINARY_WATER_HOSTS = {
    "regression-desktop-default-water": ("test_liquid_desktop_default_host.gd", "LIQUID_DESKTOP_DEFAULT_HOST:"),
    "regression-f5-water-trial-body": ("test_liquid_trial_body.gd", "LIQUID_TRIAL_BODY:"),
}


def verify_ordinary_water_hosts(directory: Path, value: dict, rows: dict) -> None:
    for label, (fixture, marker) in ORDINARY_WATER_HOSTS.items():
        require(label in rows, "Missing ordinary Water host case: " + label)
        row = rows[label]
        log = row.get("log")
        command = row.get("command", [])
        require("godot/tests/" + fixture in value["source_inputs_sha256"]
            and log in value["files_sha256"] and row.get("status") == "passed" and row.get("exit_code") == 0
            and "--headless" in command and command[-2:] == ["--script", "res://tests/" + fixture]
            and type(row.get("pid")) is int and row["pid"] > 0 and not row.get("timed_out")
            and not row.get("forced_termination"), "Ordinary Water host has no actual completed process: " + label)
        original = (directory / log).read_text(encoding="utf-8")
        require(not ERRORS.search(original) and completion(original, marker) == row.get("completion"),
            "Ordinary Water host original completion or engine diagnostics differ: " + label)


def verify_cross_authoring(directory: Path, value: dict, rows: dict) -> None:
    # Earlier frozen evaluators predate the integrated Workbench fixture.
    fixture = "godot/tests/fixtures/persistent_area_cross_authoring.gd"
    if fixture not in value["source_inputs_sha256"]:
        return
    identities = []
    for mode in ("write", "reopen"):
        label = f"ramcache-cross-authoring-{mode}"
        relative = f"cross-authoring/workbench-{mode}.json"
        require(label in rows and relative in value["files_sha256"], "Missing cross-authoring phase: " + mode)
        row = rows[label]
        log = (directory / row["log"]).read_text(encoding="utf-8")
        marker = completion(log, "PERSISTENT_AREAS_WORKBENCH")
        receipt = json.loads((directory / relative).read_text(encoding="utf-8"))
        require(not ERRORS.search(log) and row.get("exit_code") == 0 and not row.get("timed_out")
            and not row.get("forced_termination") and marker == row.get("completion")
            and marker.get("pid") == receipt.get("process_id") == row["pid"]
            and marker.get("mode") == receipt.get("mode") == mode
            and marker.get("graphical") is True and receipt.get("graphical") is True
            and isinstance(receipt.get("assertions"), int) and marker.get("checks") == receipt["assertions"] + 1
            and receipt.get("failures") == [],
            "Cross-authoring original process or native receipt differs: " + mode)
        identities.append(row["pid"])
    original = "cross-authoring/cross-authoring.json"
    reopened = "cross-authoring/cross-authoring-reopen.json"
    require(original in value["files_sha256"] and reopened in value["files_sha256"],
        "Missing native cross-authoring writer or reader result")
    proof = json.loads((directory / original).read_text(encoding="utf-8"))
    restored = json.loads((directory / reopened).read_text(encoding="utf-8"))
    require(identities[0] != identities[1] and proof.get("process_id") == identities[0]
        and proof.get("art_changed") == 180 and proof.get("art_receipt_count") == 1
        and type(proof.get("architecture_receipts")) is int and proof["architecture_receipts"] > 0
        and re.fullmatch(r"[0-9a-f]{64}", str(proof.get("projected_sha256", "")))
        and re.fullmatch(r"[0-9a-f]{32}", str(proof.get("session_id", ""))) and proof.get("marker") in (28, 58)
        and type(proof.get("durable_revision")) is int and proof["durable_revision"] > 0
        and restored.get("process_id") == identities[1] and restored.get("area") == "a"
        and all(restored.get(key) == proof[key] for key in ("session_id", "projected_sha256", "marker"))
        and type(restored.get("durable_revision")) is int and restored["durable_revision"] >= proof["durable_revision"],
        "Cross-authoring writer, fresh reader or material projection differs")


def verify_ramcache_evidence(directory: Path, value: dict, *, require_ordinary_water: bool = False) -> None:
    """Rebind the complete successor evidence without requiring a local Git checkout."""
    verify_ramcache(value)
    verify_files(directory, value.get("files_sha256"))
    original_rows = value.get("results", [])
    rows = {row["label"]: row for row in original_rows}
    require(len(rows) == len(original_rows) and REQUIRED_LABELS.issubset(rows)
        and all(row.get("status") == "passed" and type(row.get("pid")) is int and row["pid"] > 0
            and row.get("log") in value["files_sha256"] for row in original_rows),
        "Required original process evidence is missing, failed or unbound")
    verify_cross_authoring(directory, value, rows)
    # The producer always requires both. Existing frozen evaluator archives predate these cases.
    if require_ordinary_water or ORDINARY_WATER_HOSTS.keys() & rows.keys():
        verify_ordinary_water_hosts(directory, value, rows)
    markers = {"ramcache-clock":"GEN006_RAMCACHE_BACKGROUND_CLOCK", "ramcache-ledger":"GEN006_RAMCACHE_CACHE",
        "ramcache-writeback":"GEN006_RAMCACHE_WRITEBACK", "ramcache-metadata-bounds":"GEN006_RAMCACHE_METADATA_BOUNDS",
        "ramcache-owner-review":"GEN006_RAMCACHE_OWNER_REVIEW", "ramcache-prefetch-concurrency":"GEN006_RAMCACHE_PREFETCH_CONCURRENCY"}
    logs = {}
    for label in RAMCACHE_LABELS:
        row = rows[label]
        logs[label] = (directory/row["log"]).read_text(encoding="utf-8")
        require(ERRORS.search(logs[label]) is None, "Original process log reports failure: "+label)
        if not label.startswith("ramcache-crash-"):
            require(row.get("exit_code") == 0 and not row.get("timed_out", False)
                and not row.get("forced_termination", False), "Successful process was failed, timed out or killed: "+label)
        if label in markers:
            require(completion(logs[label], markers[label]) == row.get("completion"),
                "Original native completion differs from result row: "+label)
        elif label.startswith("ramcache-independent-"):
            done = completion(logs[label], "GEN006_INDEPENDENT_NATIVE_REVIEW")
            require(done == row.get("completion") and done.get("mode") == label.removeprefix("ramcache-independent-")
                and done.get("script_errors") == [], "Independent worker mode or original completion differs: "+label)
    for workers in (1, 4):
        group = value.get("ramcache_responsiveness", {}).get(str(workers), {})
        verify_responsiveness(value, workers, group)
        for variant, proof in group.items():
            label = f"ramcache-responsiveness-{variant}-w{workers}"
            relative = label+"/responsiveness-"+variant+".json"
            require(relative in value["files_sha256"]
                and json.loads((directory/relative).read_text(encoding="utf-8")) == proof
                and proof["process_id"] == rows[label]["pid"], "Active-play comparison is unbound to its original process/receipt")
            done = completion(logs[label], "GEN006_RAMCACHE_RESPONSIVENESS")
            require(done == rows[label].get("completion") and done.get("pid") == rows[label]["pid"]
                and done.get("variant") == variant and done.get("graphical") is True
                and done.get("checks") == proof["checks"]+1,
                "Responsiveness original completion contradicts its process/receipt")
    native = [json.loads(line.partition(" ")[2]) for line in logs["ramcache-native"].splitlines()
        if line.startswith("GEN006_NATIVE_RESIDENCY_RESULT ")]
    require(native == [rows["ramcache-native"].get("completion")] and native[0].get("failures") == []
        and native[0].get("assertions", 0) > 0, "Original native residency completion differs")
    proof = value.get("ramcache_healthy_recovery", {})
    verify_healthy_recovery(value, proof)
    relative = "ramcache-healthy-recovery/report.json"
    require(relative in value["files_sha256"] and json.loads((directory/relative).read_text(encoding="utf-8")) == proof,
        "Healthy recovery report differs from its original evidence")
    from run_persistent_area_recovery import validate_child
    seed = None
    for child in proof["runs"]:
        label = "ramcache-healthy-"+child["mode"]
        log = "ramcache-healthy-recovery/"+child["log"]
        receipt_path = "ramcache-healthy-recovery/"+child["evidence"]
        require(rows[label].get("pid") == child["pid"] and rows[label].get("completion") == child.get("completion")
            and value["files_sha256"].get(log) == child.get("log_sha256")
            and value["files_sha256"].get(receipt_path) == child.get("evidence_sha256"),
            "Healthy recovery child is not bound to original process/log/receipt bytes")
        receipt = json.loads((directory/receipt_path).read_text(encoding="utf-8"))
        complete = validate_child(child["mode"], child["pid"], child["exit_code"],
            (directory/log).read_text(encoding="utf-8"), receipt, seed)
        require(complete == child["completion"], "Healthy recovery completion differs from original log")
        if child["mode"] == "seed": seed = receipt
    resident_pair = value.get("ramcache_resident_storage_recovery", {})
    verify_resident_storage_recovery(value, resident_pair)
    oracle_path = "ramcache-resident-storage/expected-reopen.json"
    require(value["files_sha256"].get(oracle_path) == resident_pair["write"]["expected_reopen_sha256"]
        and json.loads((directory/oracle_path).read_text(encoding="utf-8")) == resident_pair["write"]["expected_reopen"],
        "Resident recovery oracle is not bound to its original acknowledged writer file")
    for mode, proof in resident_pair.items():
        label = "ramcache-resident-storage-"+mode
        relative = "ramcache-resident-storage/resident-storage-recovery-"+mode+".json"
        require(relative in value["files_sha256"]
            and json.loads((directory/relative).read_text(encoding="utf-8")) == proof
            and proof["process_id"] == rows[label]["pid"] and rows[label].get("exit_code") == 0,
            "Resident recovery receipt differs from its original successful process")
        done = completion(logs[label], "GEN006_RAMCACHE_RESIDENT_STORAGE_RECOVERY")
        require(done == rows[label].get("completion") and done.get("mode") == mode
            and done.get("graphical") is True and done.get("pid") == proof["process_id"]
            and done.get("failures") == 0 and done.get("checks") == proof["checks"]+1,
            "Resident storage recovery completion differs from original process and receipt")
    advance_pair = value.get("ramcache_advance_recovery", {})
    verify_resident_advance_recovery(value, advance_pair)
    oracle_path = "ramcache-advance-recovery/expected-reopen.json"
    require(value["files_sha256"].get(oracle_path) == advance_pair["write"]["expected_reopen_sha256"]
        and json.loads((directory/oracle_path).read_text(encoding="utf-8")) == advance_pair["write"]["expected_reopen"],
        "Late advancement oracle is not bound to the original acknowledged writer file")
    for mode, proof in advance_pair.items():
        label = "ramcache-advance-recovery-"+mode
        relative = "ramcache-advance-recovery/advance-recovery-"+mode+".json"
        require(relative in value["files_sha256"]
            and json.loads((directory/relative).read_text(encoding="utf-8")) == proof
            and proof["process_id"] == rows[label]["pid"] and rows[label].get("exit_code") == 0,
            "Late advancement receipt differs from its original successful process")
        done = completion(logs[label], "GEN006_RAMCACHE_ADVANCE_RECOVERY")
        require(done == rows[label].get("completion") and done.get("mode") == mode and done.get("graphical") is True
            and done.get("pid") == proof["process_id"] and done.get("failures") == 0
            and done.get("checks") == proof["checks"]+1,
            "Late advancement completion differs from its original process and receipt")
    for case in ("deferred", "strict", "first", "ahead"):
        pair = []
        for mode in ("write", "reopen"):
            label = f"ramcache-recoverable-{case}-{mode}"
            relative = f"ramcache-recoverable-{case}/recoverable-workbench-{mode}.json"
            receipt = value.get("ramcache_recoverable_workbench", {}).get(case+"-"+mode, {})
            require(receipt.get("failures") == [] and receipt.get("graphical") is True
                and receipt.get("mode") == mode and receipt.get("process_id") == rows[label]["pid"]
                and receipt.get("checks", 0) > 0 and relative in value["files_sha256"]
                and json.loads((directory/relative).read_text(encoding="utf-8")) == receipt,
                "Actual graphical failed-owner recovery evidence is incomplete or unbound")
            done = completion(logs[label], "GEN006_RAMCACHE_RECOVERABLE_WORKBENCH")
            require(done == rows[label].get("completion") and done.get("mode") == mode and done.get("graphical") is True
                and done.get("checks") == receipt["checks"]+1,
                "Recovery marker differs from the original receipt and its final output-file assertion")
            if mode == "write":
                require(receipt.get("explicit_close_acknowledged") is True
                    and (receipt.get("first_area_case") is True if case == "first" else
                         receipt.get("lost_ack_recovered") is True and receipt.get("strict_exit_case") == (case == "strict"))
                    and receipt.get("native_after", {}).get("active", {}).get("failed") is True
                    and receipt["native_after"]["active"].get("handle") == receipt.get("native_before", {}).get("active", {}).get("handle"),
                    "Recovery did not preserve the failed native owner through a lost publication ACK")
                require(receipt.get("during_ahead_case", False) == (case == "ahead"),
                    "Failed-owner recovery selected the wrong native failure boundary")
                if case == "ahead":
                    failed = receipt.get("failed_advancement", {})
                    pending, terminal = failed.get("pending", {}), failed.get("terminal", {})
                    request, native = pending.get("pending", {}), terminal.get("result", {})
                    original, after = request.get("receipt", {}), native.get("receipt", {})
                    ticks = native.get("completed_ticks")
                    planned = pending.get("plan", {})
                    require(type(ticks) is int and 0 <= ticks <= request.get("max_ticks", -1)
                        and pending.get("target_area") == pending.get("source_area") == "a"
                        and pending.get("source_clock") == failed.get("before_clock") and pending.get("accounted_ticks") == 0
                        and pending.get("session_id") == receipt.get("expected_reopen", {}).get("session_id")
                        and planned.get("mode") == "ahead" and planned.get("area_id") == "a"
                        and planned.get("requested_future_ticks") == 1
                        and request.get("start_tick") == planned.get("source_native_tick") == original.get("completed_tick")
                        and request.get("max_ticks") == min(32, planned.get("work_ticks", -1))
                        and request.get("kind") == "advance_active" and type(request.get("token")) is int and request["token"] > 0
                        and original == receipt.get("native_before", {}).get("active")
                        and after == receipt.get("native_after", {}).get("active")
                        and original.get("identity", {}).get("runtime_sha256") == value.get("native_sha256")
                        and original.get("identity", {}).get("session_id") == pending.get("session_id")
                        and original.get("identity", {}).get("area_id") == "a"
                        and terminal.get("status") == "failed" and terminal.get("ok") is False and terminal.get("lease_held") is True
                        and terminal.get("operation_id") == pending.get("operation_id")
                        and native.get("ok") is False and original.get("failed") is False and after.get("failed") is True
                        and native.get("current_tick") == request.get("start_tick", -1)+ticks
                        and after.get("completed_tick") == native["current_tick"]
                        and all(after.get(key) == original.get(key) for key in ("handle", "identity", "resident_generation", "worker_threads", "physics_profile_sha256", "active"))
                        and after.get("active") is True and type(after.get("mutation_generation")) is int
                        and after["mutation_generation"] >= original.get("mutation_generation", 0),
                        "Failed Ahead did not retain a real bounded terminal native failure and its original owner")
                    accounted = _advance_clock_completion(failed["before_clock"], pending["plan"], ticks)
                    clean = failed.get("after_cleanup", {})
                    require(failed.get("completed") == accounted and clean.get("game_tick") == accounted["clock"]["game_ticks"]
                        and clean.get("areas", {}).get("a", {}).get("accounted_tick") == accounted["clock"]["areas"]["a"]["accounted_ticks"]
                        and clean.get("areas", {}).get("a", {}).get("completed_tick") == native["current_tick"]
                        and clean.get("active_area") == "a" and clean.get("session_id") == pending["session_id"]
                        and clean.get("ready") is False and clean.get("quarantined") is True and clean.get("busy") is False
                        and clean.get("resident_advancement") == {} and clean.get("unresolved_worker") == {}
                        and clean.get("owner_cleanup_required") is False and clean.get("recoverable_save_available") is True,
                        "Known failed native completion resumed its World, credited its failed tick or blocked healthy recovery")
                    for area in ("a", "b", "c"):
                        current = clean.get("areas", {}).get(area, {})
                        frontier = accounted["clock"]["areas"][area]
                        require(current.get("completed_tick") == frontier["native_ticks"]
                            and current.get("accounted_tick") == frontier["accounted_ticks"]
                            and current.get("debt_ticks") == accounted["clock"]["game_ticks"]-frontier["accounted_ticks"],
                            "Failed active cleanup changed another area's native or accounted clock")
            else: require(receipt.get("fresh_process") is True, "Recovery did not reopen in a new process")
            pair.append(receipt["process_id"])
        require(pair[0] != pair[1], "Failed-owner recovery reused its process")
        if case == "ahead":
            writer = value["ramcache_recoverable_workbench"]["ahead-write"]
            reopened = value["ramcache_recoverable_workbench"]["ahead-reopen"]
            oracle = writer.get("expected_reopen", {})
            _validate_advance_clock(oracle.get("clock", {}))
            oracle_path = "ramcache-recoverable-ahead/recovery-expected.json"
            require(oracle == reopened.get("expected_reopen")
                and oracle.get("originating_write_process_id") == writer["process_id"]
                and reopened.get("originating_write_process_id") == writer["process_id"]
                and writer.get("expected_reopen_sha256") == reopened.get("expected_reopen_sha256")
                == value["files_sha256"].get(oracle_path)
                and json.loads((directory/oracle_path).read_text(encoding="utf-8")) == oracle
                and set(oracle.get("areas", {})) == set(reopened.get("actual_areas", {})) == {"a", "b", "c"},
                "Failed Ahead rescue is not bound to its original acknowledged three-area restart oracle")
            for proof in (writer, reopened):
                evidence = proof.get("evidence", {})
                manifest = evidence.get("manifest", {})
                require(evidence.get("process_id") == proof["process_id"]
                    and manifest.get("session_id") == oracle.get("session_id")
                    and evidence.get("clock") == manifest.get("clock") == oracle.get("clock"),
                    "Failed Ahead rescue changed its durable session or game-time authority on reopen")
                for area in ("a", "b", "c"):
                    saved, actual = oracle["areas"][area], reopened["actual_areas"][area]
                    for key in ("native_sha256", "physical_hash", "authoring_sha256", "authored_source_sha256", "completed_tick"):
                        require(key in saved and actual.get(key) == saved[key]
                            and manifest.get("areas", {}).get(area, {}).get(key) == saved[key],
                            "Failed Ahead rescue lost the exact native or authored state of a saved area")
    relative = "ramcache-hot-recovery/hot-recovery.json"
    late = value.get("ramcache_late_handoff", {})
    require(late.get("failures") == [] and late.get("graphical") is True and late.get("checks", 0) > 0
        and late.get("process_id") == rows["ramcache-hot-recovery"]["pid"]
        and all(key in late for key in ("before_recovery", "after_recovery", "release_recovery", "cold_recovery"))
        and relative in value["files_sha256"] and json.loads((directory/relative).read_text(encoding="utf-8")) == late,
        "Late native/Main/release and cold handoff recovery was not actually qualified")
    done = completion(logs["ramcache-hot-recovery"], "GEN006_RAMCACHE_HOT_RECOVERY")
    require(done == rows["ramcache-hot-recovery"].get("completion") and done.get("graphical") is True
        and done.get("checks") == late["checks"]+1, "Late handoff completion differs from its original receipt")
    for workers in (1, 4):
        for mode in ("write", "reopen"):
            label = f"ramcache-{mode}-w{workers}"
            relative = f"ramcache-w{workers}/ramcache-{mode}.json"
            require(relative in value["files_sha256"]
                and json.loads((directory/relative).read_text(encoding="utf-8")) == value["ramcache"][label]
                and value["ramcache"][label]["process_id"] == rows[label]["pid"],
                "RAM-cache receipt is not bound to its original measured process")
            receipt = value["ramcache"][label]
            done = completion(logs[label], "GEN006_RAMCACHE")
            require(done == rows[label].get("completion") and done.get("mode") == mode and done.get("graphical") is True
                and done.get("pid") == rows[label]["pid"] and done.get("checks") == receipt["checks"]+1
                and done.get("hot_samples") == len(receipt.get("hot_samples", []))
                and done.get("warm_samples") == len(receipt.get("warm_samples", [])),
                "RAM-cache original completion differs from its native/receipt sample evidence")
        performance = value["ramcache_performance"][str(workers)]
        measured_process = rows[f"ramcache-write-w{workers}"]
        require(type(performance.get("whole_process_peak_rss_bytes")) is int
            and performance["whole_process_peak_rss_bytes"] > 0
            and performance["whole_process_peak_rss_bytes"] == measured_process.get("os_peak_rss_bytes")
            and finite_nonnegative(performance.get("whole_process_cpu_seconds"))
            and performance["whole_process_cpu_seconds"] == measured_process.get("sampled_cpu_seconds"),
            "Reported RAM-cache process memory/CPU differs from actual process observations")
        relative = f"ramcache-memory/native-memory-w{workers}.json"
        require(relative in value["files_sha256"]
            and json.loads((directory/relative).read_text(encoding="utf-8")) == value["ramcache_memory"][str(workers)]
            and rows[f"ramcache-memory-w{workers}"]["pid"] == value["ramcache_memory"][str(workers)]["pid"]
            and rows[f"ramcache-memory-w{workers}"].get("exit_code") == 0,
            "Native memory report differs from original evidence")
        memory = value["ramcache_memory"][str(workers)]
        text = logs[f"ramcache-memory-w{workers}"]
        original_phases = [json.loads(line.partition(" ")[2]) for line in text.splitlines() if line.startswith("GEN006_NATIVE_MEMORY_PHASE ")]
        original_done = [json.loads(line.partition(" ")[2]) for line in text.splitlines() if line.startswith("GEN006_NATIVE_MEMORY_DONE ")]
        require(original_done == [memory["completed"]] and len(original_phases) == len(memory["phases"])
            and all(original == {key:datum for key, datum in retained.items() if key not in ("observed_elapsed_seconds", "process_memory")}
                for original, retained in zip(original_phases, memory["phases"])),
            "Native memory report is not bound to its original phase/terminal observations")
    relative = "ramcache-writeback-faults/results.json"
    require(relative in value["files_sha256"]
        and json.loads((directory/relative).read_text(encoding="utf-8")) == value["ramcache_recovery"],
        "Write-behind recovery report differs from original process evidence")
    for index, child in enumerate(value["ramcache_recovery"]["rows"]):
        phase, position = BOUNDARIES[index//3], index % 3
        label = "ramcache-crash-"+phase if position == 0 else f"ramcache-recover-{phase}-{position}"
        record = rows[label]
        require(all(record.get(key) == datum for key, datum in child.items())
            and value["files_sha256"].get(record["log"]) == child.get("log_sha256"),
            "Recovery child differs from its measured parent row or original log")
        if position == 0:
            lines = (directory/record["log"]).read_text(encoding="utf-8").splitlines()
            barriers = [json.loads(line.partition(" ")[2]) for line in lines if line.startswith("GEN006_RAMCACHE_BARRIER ")]
            require(barriers == child.get("barrier_witnesses")
                and child["observed_barrier"] in barriers,
                "Original native/Main process-death barriers differ from the report")
            if phase == "newer_dirty_after_durable":
                seed = child["seed"]
                for name, digest in (("seed.log", seed["log_sha256"]),
                                     ("reopen.log",seed["baseline"]["log_sha256"])):
                    path = "ramcache-writeback-faults/" + phase + "/seed/" + name
                    require(value["files_sha256"].get(path) == digest,
                        "Original durable seed or baseline-reopen process log is missing or changed")
                path = "ramcache-writeback-faults/" + phase + "/seed/recovered.json"
                require(value["files_sha256"].get(path) == seed["baseline"]["evidence_sha256"]
                    and json.loads((directory/path).read_text(encoding="utf-8"))["pid"] == seed["baseline"]["pid"],
                    "Original seeded recovery receipt differs from source-bound durable baseline")
        else:
            receipt_path = str(Path(record["log"]).with_name("recovered.json")).replace("\\", "/")
            require(value["files_sha256"].get(receipt_path) == child.get("evidence_sha256"),
                "Fresh recovery receipt is not bound to its original bytes")
            receipt = json.loads((directory/receipt_path).read_text(encoding="utf-8"))
            native = receipt.get("events", [{}])[-1]
            require(receipt.get("pid") == child["pid"] and receipt.get("failures") == 0
                and receipt.get("checks") == child["checks"] and native.get("native_tick") == child["expected_tick"]
                and native.get("native_sha256") == child["native_sha256"] and native.get("physical_hash") == child["physical_hash"]
                and native.get("fresh_owner_manifest", {}).get("session_id") == child["session_id"]
                and native.get("fresh_owner_manifest", {}).get("clock", {}).get("game_ticks") == child["expected_tick"]
                and native.get("fresh_owner_manifest", {}).get("revision") == child["durable_oracle"]["revision"]
                and native.get("fresh_owner_manifest", {}).get("clock") == child["durable_oracle"]["clock"]
                and all(native["fresh_owner_manifest"]["areas"][id][key] == data
                    for id,fields in child["durable_oracle"]["areas"].items() for key,data in fields.items()),
                "Original fresh recovery failed or restored a different native/game-time frontier")
    for label in ("donor-cold", "successor-cold"):
        proof = value.get("ramcache_cold_comparison", {}).get(label, {})
        verify_cold_benchmark(value, proof, label)
        relative = label+"/benchmark.json"
        require(relative in value["files_sha256"] and json.loads((directory/relative).read_text(encoding="utf-8")) == proof
            and rows[label]["pid"] == proof["pid"] and rows[label].get("statistics") == proof["statistics"]
            and rows[label].get("log") == label+"/execution.log", "Cold comparison is not bound to its original process")
        relative = label+"/travel.json"
        require(relative in value["files_sha256"] and json.loads((directory/relative).read_text(encoding="utf-8")) == proof["receipt"],
            "Cold comparison original native receipt differs from its embedded summary")
        samples = [json.loads(line.partition(" ")[2]) for line in logs[label].splitlines() if line.startswith("RAMCACHE_BASELINE_SAMPLE ")]
        require(samples == [row for row in proof["receipt"]["rows"] if row.get("kind") == "travel"],
            "Cold comparison original sample log differs from its native receipt")


donor.verify_qualification = verify_qualification
donor.NATIVE_MARKERS += (
    r"(?m)^GEN006_NATIVE_RESIDENCY_MEMORY_PASS owned_bytes=[1-9][0-9]* reservation_bytes=[1-9][0-9]* cell_bytes=[1-9][0-9]* render_bytes=[1-9][0-9]* immutable_lease_survives_world_and_exchange_release=true excludes=allocator_metadata,os_thread_stacks,host_values$",
)
NATIVE_MARKERS = donor.NATIVE_MARKERS
REQUIRED_LABELS = donor.REQUIRED_LABELS


if __name__ == "__main__":
    raise SystemExit(donor.main())
