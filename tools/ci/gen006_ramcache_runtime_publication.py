#!/usr/bin/env python3
"""Isolated stacked GEN-006 RAM-cache publication; all donor fences remain."""
from __future__ import annotations

from importlib.util import module_from_spec, spec_from_file_location
import json
import math
import os
import re
from pathlib import Path
from run_persistent_areas_qualification import ERRORS, completion

_spec = spec_from_file_location("_ramcache_private_donor_profile",
    Path(__file__).with_name("gen006_persistent_runtime_publication.py"))
donor = module_from_spec(_spec)
_spec.loader.exec_module(donor)
engine = donor.engine
old_workflow, old_request = engine.WORKFLOW, engine.REQUEST
engine.BRANCH = "exp/gen006-ramcache-001-20261122"
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
EXTRA_INPUTS = {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE, donor.CAMPAIGN_SCRIPT,
    "tools/ci/test_gen006_ramcache_packaged_smoke.ps1",
    "tools/ci/gen006_ramcache_runtime_publication.py",
    "tools/ci/test_gen006_ramcache_runtime_publication.py",
    "tools/ci/run_persistent_area_writeback_faults.py",
    "tools/ci/run_persistent_area_residency_memory.py",
    "tools/ci/run_persistent_area_recovery.py",
    "tools/ci/run_persistent_area_travel_benchmark.py",
    "tools/ci/benchmark_persistent_area_travel.gd",
    "tools/package_gen006_ramcache.py",
    "docs/operations/persistent-area-ramcache-evaluation.md",
}
engine.BUILD_EXACT = (set(engine.BUILD_EXACT) - {old_workflow, old_request}) | EXTRA_INPUTS
BOUNDARIES = ("before_snapshot", "after_checkpoint", "after_stage", "after_previous", "before_publish", "after_publish")
RAMCACHE_LABELS = frozenset({"ramcache-native", "ramcache-clock", "ramcache-ledger", "ramcache-writeback", "ramcache-owner-review", "ramcache-prefetch-concurrency", "donor-cold", "successor-cold"}
    | {"ramcache-hot-recovery", "ramcache-healthy-seed", "ramcache-healthy-verify", "ramcache-metadata-bounds"}
    | {"ramcache-independent-"+mode for mode in ("healthy", "missing_setup", "wrong_setup_types", "wrong_execution_type", "missing_worker_type", "stop",
            "runtime_mismatch", "session_mismatch", "source_identity_mismatch", "physics_mismatch", "policy_mismatch",
            "authoring_changed", "warm_corruption", "warm_wrong_tick", "short_native_reservation",
            "short_transient_reservation", "wrong_incarnation", "oversized_metadata")}
    | {f"ramcache-recoverable-{case}-{mode}" for case in ("deferred", "strict", "first") for mode in ("write", "reopen")}
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
    rows = proof.get("rows", [])
    require(isinstance(rows, list) and len(rows) == 18, "Six deaths and twelve fresh restores are mandatory")
    for index, phase in enumerate(BOUNDARIES):
        death, first, repeat = rows[3*index:3*index+3]
        require(all(isinstance(row, dict) and row.get("ok") is True and type(row.get("pid")) is int
            and row["pid"] > 0 and type(row.get("exit_code")) is int and row.get("boundary") == phase
            for row in (death, first, repeat)), "Recovery child process did not complete its declared boundary")
        barrier = death.get("observed_barrier", {})
        require(death.get("kind") == "intentional_process_death" and death.get("forced_termination") is True
            and death["exit_code"] != 0 and barrier.get("phase") == phase and barrier.get("pid") == death["pid"]
            and re.fullmatch(r"[0-9a-f]{32}", str(barrier.get("session_id", ""))) is not None,
            "Write-behind death lacks an actual matching native process barrier")
        expected = 4 if phase == "after_publish" else 0
        require(len({death["pid"], first["pid"], repeat["pid"]}) == 3, "Recovery reused a process identity")
        for child in (first, repeat):
            require(child.get("kind") == "fresh_process_recovery" and child["exit_code"] == 0
                and child.get("observed_pid") == child["pid"] and child.get("expected_tick") == expected and child.get("checks", 0) >= 8
                and child.get("session_id") == barrier["session_id"]
                and re.fullmatch(r"[0-9a-f]{64}", str(child.get("native_sha256", ""))) is not None
                and re.fullmatch(r"[0-9a-f]{16}", str(child.get("physical_hash", ""))) is not None,
                "Fresh recovery did not verify the expected exact native frontier")
        require(all(first.get(key) == repeat.get(key) for key in ("session_id", "native_sha256", "physical_hash", "expected_tick")),
            "Repeated reopening changed retained native authority")


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


def verify_qualification(*args, **kwargs) -> None:
    _verify_donor_qualification(*args, **kwargs)
    value = args[1] if len(args) > 1 else kwargs["value"]
    verify_ramcache_evidence(args[0] if args else kwargs["directory"], value)


def verify_ramcache_evidence(directory: Path, value: dict) -> None:
    """Rebind the complete successor evidence without requiring a local Git checkout."""
    verify_ramcache(value)
    verify_files(directory, value.get("files_sha256"))
    original_rows = value.get("results", [])
    rows = {row["label"]: row for row in original_rows}
    require(len(rows) == len(original_rows) and REQUIRED_LABELS.issubset(rows)
        and all(row.get("status") == "passed" and type(row.get("pid")) is int and row["pid"] > 0
            and row.get("log") in value["files_sha256"] for row in original_rows),
        "Required original process evidence is missing, failed or unbound")
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
    for case in ("deferred", "strict", "first"):
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
            else: require(receipt.get("fresh_process") is True, "Recovery did not reopen in a new process")
            pair.append(receipt["process_id"])
        require(pair[0] != pair[1], "Failed-owner recovery reused its process")
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
            require(barriers == [child["observed_barrier"]], "Original process-death barrier differs from the report")
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
                and native.get("fresh_owner_manifest", {}).get("clock", {}).get("game_ticks") == child["expected_tick"],
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
