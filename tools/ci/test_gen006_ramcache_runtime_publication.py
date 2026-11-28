#!/usr/bin/env python3
"""Reject synthetic cache-hit claims and unsafe successor publication routing."""
from __future__ import annotations

import ast
import copy
from contextlib import ExitStack
import hashlib
import inspect
import json
import os
from pathlib import Path
import re
import sys
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import gen006_ramcache_runtime_publication as profile
import gen006_persistent_runtime_publication as original

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/"tools"))
import package_gen006_ramcache as package


def valid_guard_fixture() -> dict:
    """Metadata-only guard fixture; never labelled native execution evidence."""
    io = dict(profile_read_calls=4, native_deserializations=3, source_constructions=6, synchronous_publications=0)
    hot = dict(residency="HOT", status="completed", debt_before_ticks=0, native_ticks_executed=0,
        elapsed_ms=20, io_before=io, io_after=io, game_tick_before=0, game_tick_after=0,
        target_native_tick_before=0, target_native_tick_after=0, max_main_frame_ms=5,
        start_usec=100000, end_usec=120000, worst_frame_start_usec=105000, worst_frame_end_usec=110000,
        frame_observations=4)
    warm = dict(hot, residency="WARM", io_after=dict(io, native_deserializations=4))
    native = dict(native_restorations=3, source_constructions=6, captures=1, hot_activations=3)
    filesystem = {key: 2 for key in ("checkpoint_read_requests", "checkpoint_read_bytes", "read_system_calls",
        "write_system_calls", "write_bytes", "file_flush_calls", "directory_flush_calls", "publication_calls")}
    filesystem["available"] = True
    warm.update(filesystem_before=filesystem, filesystem_after=filesystem,
        native_before={"native_restorations":3}, native_after={"native_restorations":4})
    receipt = dict(schema="gen006-ramcache-workbench-v1", failures=[], graphical=True, checks=500,
        process_id=10, hot_samples=[dict(copy.deepcopy(hot), source_area=("a","b","c")[i%3],
            target_area=("b","c","a")[i%3]) for i in range(30)],
        warm_samples=[dict(copy.deepcopy(warm), source_area=("a","b","c")[i%3],
            target_area=("b","c","a")[i%3]) for i in range(30)], native_before=native,
        native_after=dict(native, hot_activations=33), filesystem_before=filesystem, filesystem_after=filesystem,
        evidence={"cache_io": {"prefetch_completed": 2, "prefetch_hits": 1, "background_publications": 1}})
    value = {"ramcache_schema": "gen006-ramcache-qualification-v1", "platform":"linux", "native_sha256": "a"*64,
        "engine_sha256": "b"*64, "source_commit": "c"*40, "source_tree": "d"*40,
        "local_delta": [], "missing_source_inputs": [], "source_inputs_sha256": {
            "tools/ci/run_persistent_area_residency_memory.py": "e"*64,
            "godot/tests/test_persistent_area_residency_memory.gd": "f"*64},
        "ramcache": {}, "ramcache_memory": {}, "ramcache_performance": {}}
    before = {key:copy.deepcopy(value[key]) for key in ("source_commit", "source_tree", "local_delta", "missing_source_inputs", "source_inputs_sha256")}
    proof = dict(ok=True, qualified_source=True, diagnostic=False, source_unchanged=True, platform="posix",
        source_before=before, source_after=copy.deepcopy(before), rows=[],
        source_commit=value["source_commit"], source_tree=value["source_tree"],
        engine_sha256=value["engine_sha256"], native_sha256=value["native_sha256"],
        binaries_before={"/engine": "b"*64, "/native": "a"*64}, binaries_after={"/engine": "b"*64, "/native": "a"*64})
    for index, phase in enumerate(profile.BOUNDARIES):
        pid = 100+index*3
        expected = 4 if phase in ("after_publish","newer_dirty_after_durable") else 0
        revision = 2 if expected == 4 else 1
        marker = dict(pid=pid,phase=phase,session_id="a"*32,
            revision=2 if phase in ("after_publish","newer_dirty_after_durable") else 1)
        if phase in ("before_capture","queued_dirty","newer_dirty_after_durable"):
            marker.update(live_native_tick=4 if phase == "before_capture" else 6,
                durable_native_tick=4 if phase == "newer_dirty_after_durable" else 0)
        if phase == "queued_dirty":
            marker["queued_requests"] = 1
        witness = [dict(marker,phase="before_snapshot"),marker] if phase == "queued_dirty" else [marker]
        clock = dict(version=1,game_ticks=expected,areas={
            id:dict(accounted_ticks=expected if id=="a" else 0,
                native_ticks=expected if id=="a" else 0,origin_game_tick=0) for id in ("a","b","c")})
        records = {id:dict(area_id=id,generation=revision if id=="a" else 1,
            incarnation="d"*32, mutation_generation=1 if id=="a" and expected==4 else 0,
            completed_tick=expected if id=="a" else 0,
            native_sha256="c"*64 if id=="a" else "e"*64,
            authoring_sha256="1"*64,authored_source_sha256="2"*64,
            physics_profile_sha256="3"*64,policy_sha256="4"*64) for id in ("a","b","c")}
        oracle = dict(revision=revision,game_ticks=expected,clock=clock,areas=records)
        death = dict(kind="intentional_process_death",pid=pid,launcher_pid=pid,
            native_identity=dict(native_pid=pid,launcher_pid=pid,relationship="direct"),
            exit_code=-9,ok=True,boundary=phase,forced_termination=True,
            observed_barrier=marker,barrier_witnesses=witness)
        if phase == "newer_dirty_after_durable":
            baseline = dict(kind="fresh_process_recovery",pid=501,launcher_pid=501,session_id="a"*32,
                native_sha256="c"*64, durable_oracle=copy.deepcopy(oracle))
            death["seed"] = dict(ok=True,pid=500,launcher_pid=500,exit_code=0,log_sha256="8"*64,baseline=baseline)
        proof["rows"].append(death)
        for offset in (1, 2):
            proof["rows"].append(dict(kind="fresh_process_recovery",pid=pid+offset,launcher_pid=pid+offset,observed_pid=pid+offset,
                exit_code=0,ok=True,boundary=phase,expected_tick=expected,checks=8,
                session_id="a"*32,native_sha256="c"*64,physical_hash="d"*16,
                durable_oracle=copy.deepcopy(oracle)))
    value["ramcache_recovery"] = proof
    for workers in (1, 4):
        value["ramcache"][f"ramcache-write-w{workers}"] = copy.deepcopy(receipt)
        value["ramcache"][f"ramcache-reopen-w{workers}"] = dict(copy.deepcopy(receipt), process_id=11)
        value["ramcache_performance"][str(workers)] = {
            "hot_zero_debt": profile.timing_statistics(receipt["hot_samples"]),
            "warm_zero_debt": profile.timing_statistics(receipt["warm_samples"])}
        names = ["one_hot_world", "two_hot_worlds", "three_hot_worlds", "two_hot_one_warm",
                 "two_hot_after_180_handoffs", "one_hot_buffers_released"] + ["other"+str(index) for index in range(9)]
        value["ramcache_memory"][str(workers)] = dict(ok=True, native_sha256="a"*64, godot_sha256="b"*64,
            configured_workers=workers, pid=20+workers, exit_code=0, binaries_unchanged=True,
            source_inputs_unchanged=True, harness_unchanged=True, peak_sampled_rss_bytes=100, samples=[{}],
            source_inputs={"godot/tests/test_persistent_area_residency_memory.gd": "f"*64}, harness_sha256="e"*64,
            completed=dict(ok=True, failures=[], configured_workers=workers, phases=15),
            phases=[dict(pid=20+workers, workers=workers, label=name) for name in names])
    return value


class QualificationGuards(unittest.TestCase):
    def test_ordinary_water_host_source_and_terminal_are_required(self):
        from run_persistent_areas_qualification import UNIT_CASES
        plan = {label: (fixture, marker) for label, fixture, marker in UNIT_CASES[:2]}
        self.assertEqual(plan, profile.ORDINARY_WATER_HOSTS)
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            report = {"source_inputs_sha256": {}, "files_sha256": {}}
            rows = {}
            for pid, (label, (fixture, marker)) in enumerate(plan.items(), 101):
                log = label + ".log"
                original = marker + " 17 assertions; 0 failures\n"
                (directory / log).write_text(original)
                report["source_inputs_sha256"]["godot/tests/" + fixture] = "a" * 64
                report["files_sha256"][log] = profile.sha(directory / log)
                rows[label] = {"log": log, "pid": pid, "status": "passed", "exit_code": 0,
                               "command": ["godot", "--headless", "--script", "res://tests/" + fixture],
                               "completion": profile.completion(original, marker)}
            profile.verify_ordinary_water_hosts(directory, report, rows)
            for label in rows:
                with self.subTest(label=label), self.assertRaises(RuntimeError):
                    profile.verify_ordinary_water_hosts(directory, report, {k: v for k, v in rows.items() if k != label})
                with self.subTest(label=label), self.assertRaises(RuntimeError):
                    profile.verify_ordinary_water_hosts(directory, report, rows | {label: rows[label] | {"timed_out": True}})
                path = directory / rows[label]["log"]
                original = path.read_text()
                path.write_text("SCRIPT ERROR: Invalid access to property id\n" + original)
                with self.assertRaises(RuntimeError):
                    profile.verify_ordinary_water_hosts(directory, report, rows)
                path.write_text(original)

    def test_cross_authoring_requires_both_original_processes_and_complete_native_write(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "cross-authoring").mkdir()
            value = {"source_inputs_sha256": {"godot/tests/fixtures/persistent_area_cross_authoring.gd": "1" * 64},
                     "files_sha256": {}}
            rows = {}
            for mode, pid in (("write", 111), ("reopen", 222)):
                marker = {"mode": mode, "checks": 25, "failures": [], "pid": pid, "graphical": True}
                log = mode + ".log"
                (root / log).write_text("PERSISTENT_AREAS_WORKBENCH " + json.dumps(marker) + "\n")
                path = f"cross-authoring/workbench-{mode}.json"
                raw = {"mode": mode, "process_id": pid, "assertions": 24, "failures": [], "graphical": True}
                (root / path).write_text(json.dumps(raw))
                value["files_sha256"][path] = profile.sha(root / path)
                rows[f"ramcache-cross-authoring-{mode}"] = {"log": log, "completion": marker, "pid": pid, "exit_code": 0}
            original = "cross-authoring/cross-authoring.json"
            writer = {"process_id": 111, "art_changed": 180, "art_receipt_count": 1, "architecture_receipts": 1,
                      "projected_sha256": "a" * 64, "session_id": "b" * 32, "durable_revision": 9, "marker": 58}
            (root / original).write_text(json.dumps(writer))
            value["files_sha256"][original] = profile.sha(root / original)
            restored = "cross-authoring/cross-authoring-reopen.json"
            reader = {"process_id": 222, "projected_sha256": "a" * 64, "session_id": "b" * 32,
                      "durable_revision": 11, "marker": 58, "area": "a"}
            (root / restored).write_text(json.dumps(reader))
            value["files_sha256"][restored] = profile.sha(root / restored)
            profile.verify_cross_authoring(root, value, rows)
            for changed in ({"process_id": 222}, {"art_changed": 179}, {"architecture_receipts": 0}):
                (root / original).write_text(json.dumps(writer | changed))
                with self.subTest(changed=changed), self.assertRaises(RuntimeError):
                    profile.verify_cross_authoring(root, value, rows)
            (root / original).write_text(json.dumps(writer))
            for changed in ({"process_id": 111}, {"projected_sha256": "c" * 64}, {"session_id": "c" * 32},
                            {"marker": 28}, {"durable_revision": 8}, {"area": "b"}):
                (root / restored).write_text(json.dumps(reader | changed))
                with self.subTest(changed=changed), self.assertRaises(RuntimeError):
                    profile.verify_cross_authoring(root, value, rows)
            with self.assertRaises(RuntimeError):
                profile.verify_cross_authoring(root, value, {"ramcache-cross-authoring-write": rows["ramcache-cross-authoring-write"]})
            profile.verify_cross_authoring(root, {"source_inputs_sha256": {}}, {})

    def test_late_native_prefix_preserves_debt_and_credits_only_completed_future(self):
        # Publication arithmetic only; real native/process receipts are a separate gate.
        clock = dict(version=1, game_ticks=160, areas={
            "a":dict(accounted_ticks=160,native_ticks=160,origin_game_tick=0),
            "b":dict(accounted_ticks=159,native_ticks=159,origin_game_tick=0),
            "c":dict(accounted_ticks=0,native_ticks=0,origin_game_tick=0)})
        plan = dict(version=1, area_id="b", mode="ahead",
            source_clock_sha256=hashlib.sha256(json.dumps(clock,sort_keys=True,separators=(",", ":")).encode()).hexdigest(),
            source_native_tick=159,source_debt_ticks=1,requested_future_ticks=64,max_work_ticks=600,
            work_ticks=65,debt_work_ticks=1,future_work_ticks=64)
        original = copy.deepcopy(clock)
        first = profile._advance_clock_completion(clock,plan,5)
        self.assertEqual((first["clock"]["game_ticks"],first["paid_debt_ticks"],first["game_advanced_ticks"]),(164,1,4))
        final = profile._advance_clock_completion(clock,plan,11)
        self.assertEqual((final["clock"]["game_ticks"],final["clock"]["areas"]["b"]["native_ticks"]),(170,170))
        self.assertEqual((final["paid_debt_ticks"],final["game_advanced_ticks"],final["remaining_future_ticks"]),(1,10,54))
        self.assertEqual(clock,original)
        self.assertEqual(profile._advance_clock_completion(clock,plan,0)["clock"],clock)
        # Reusing the original plan against the already-accounted prefix must refuse.
        with self.assertRaises(RuntimeError): profile._advance_clock_completion(first["clock"],plan,6)
        for fault in ("wrong_digest","native_gap","native_bool","wrong_debt","double_future","extra_field",
                "future_catchup","work_limit","requested_limit","unexecuted","negative","bool_ticks","origin"):
            changed_clock, changed_plan, actual = copy.deepcopy(clock),copy.deepcopy(plan),11
            if fault=="wrong_digest": changed_plan["source_clock_sha256"]="0"*64
            elif fault=="native_gap": changed_plan["source_native_tick"]+=1
            elif fault=="native_bool": changed_plan["source_native_tick"]=True
            elif fault=="wrong_debt": changed_plan["source_debt_ticks"]=0
            elif fault=="double_future": changed_plan["future_work_ticks"]=65
            elif fault=="extra_field": changed_plan["recovered"]=True
            elif fault=="future_catchup": changed_plan["mode"]="catch_up"
            elif fault=="work_limit": changed_plan["max_work_ticks"]=601
            elif fault=="requested_limit": changed_plan["requested_future_ticks"]=36001
            elif fault=="unexecuted": actual=66
            elif fault=="negative": actual=-1
            elif fault=="bool_ticks": actual=True
            else: changed_clock["areas"]["b"]["origin_game_tick"]=1
            with self.subTest(fault=fault), self.assertRaises(RuntimeError):
                profile._advance_clock_completion(changed_clock,changed_plan,actual)
        debt_plan = dict(plan,area_id="c",mode="catch_up",source_native_tick=0,source_debt_ticks=160,
            requested_future_ticks=0,work_ticks=160,debt_work_ticks=160,future_work_ticks=0)
        debt = profile._advance_clock_completion(clock,debt_plan,9)
        self.assertEqual((debt["clock"]["game_ticks"],debt["clock"]["areas"]["c"]["native_ticks"],debt["debt_ticks"]),(160,9,151))

    def test_valid_metadata_shape_only(self):
        profile.verify_ramcache(valid_guard_fixture())

    def test_controlled_cold_benchmark_requires_same_workload_and_actual_custody(self):
        parent = valid_guard_fixture()
        parent["platform"] = "linux"
        parent["source_inputs_sha256"].update({"tools/ci/run_persistent_area_travel_benchmark.py":"1"*64,
            "tools/ci/benchmark_persistent_area_travel.gd":"2"*64,"godot/scripts/persistent_area_fixtures.gd":"3"*64})
        for label in ("donor-cold", "successor-cold"):
            before = {key:copy.deepcopy(parent[key]) for key in ("source_commit","source_tree","local_delta","missing_source_inputs","source_inputs_sha256")}
            native = parent["native_sha256"]
            if label == "donor-cold":
                before["source_commit"] = "d0d043f4740ffed5f0dbb4120e437458d7a9bd57"
                native = "1198c1a252cba4ae9ee14371f7b386f685155438bd3556b8640f04f9253ea977"
            proof = dict(schema="gen006-ramcache-travel-benchmark-v1",status="passed",diagnostic=False,graphical=True,
                source_before=before,source_after=copy.deepcopy(before),source_unchanged=True,binaries_unchanged=True,
                harness_unchanged=True,exit_code=0,pid=52,godot_sha256=parent["engine_sha256"],native_sha256=native,
                harness_sha256="1"*64,script_sha256="2"*64,samples=[{"rss_bytes":123}],
                receipt=dict(pid=52,passed=True,failures=[],workers=1,fixture_extent=[512,512],graphics="X11",
                    renderer="llvmpipe",rendering_method="gl_compatibility",rows=[dict(kind="travel",elapsed_ms=i,
                        max_frame_gap_ms=5,native_tick=0,game_tick=0,
                        source=("a","b","c")[i%3],target=("b","c","a")[i%3]) for i in range(30)]),
                statistics=dict(samples=30,p50_ms=14.5,p95_ms=28,worst_ms=29,maximum_correlated_main_frame_ms=5),
                donor_runtime_provenance=dict(sha256=native,source_commit="1ceac7e3d4d9e9f6b24833ced340286a4a15d01e",
                    source_inputs={"godot/scripts/persistent_area_fixtures.gd":"3"*64}))
            profile.verify_cold_benchmark(parent,proof,label)
            for fault in ("headless","wrong_pid","runtime","source","harness","ticks","few_samples","fake_statistics","changed_inputs","area_mix","donor_binary"):
                changed=copy.deepcopy(proof)
                if fault=="headless": changed["receipt"]["graphics"]="headless"
                elif fault=="wrong_pid": changed["receipt"]["pid"]=99
                elif fault=="runtime": changed["godot_sha256"]="0"*64
                elif fault=="source": changed["source_before"]["source_commit"]="0"*40
                elif fault=="harness": changed["harness_sha256"]="0"*64
                elif fault=="ticks": changed["receipt"]["rows"][0]["native_tick"]=1
                elif fault=="few_samples": changed["receipt"]["rows"].pop()
                elif fault=="fake_statistics": changed["statistics"]["p95_ms"]=1
                elif fault=="changed_inputs": changed["source_after"]["source_inputs_sha256"]["godot/scripts/persistent_area_fixtures.gd"]="0"*64
                elif fault=="area_mix": changed["receipt"]["rows"][1]["target"]="a"
                elif label=="donor-cold": changed["donor_runtime_provenance"]["sha256"]="0"*64
                else: changed["native_sha256"]="0"*64
                with self.subTest(label=label,fault=fault), self.assertRaises(RuntimeError):
                    profile.verify_cold_benchmark(parent,changed,label)

    def test_ram_timings_require_balanced_cyclic_areas_and_initial_native_state(self):
        for kind in ("hot", "warm"):
            for key, changed_value in (("source_area", "c"), ("target_area", "a"),
                ("game_tick_before", 1), ("target_native_tick_before", 1)):
                value = valid_guard_fixture()
                value["ramcache"]["ramcache-write-w1"][kind+"_samples"][0][key] = changed_value
                with self.subTest(kind=kind, key=key), self.assertRaises(RuntimeError):
                    profile.verify_ramcache(value)

    def test_correlated_timings_and_summaries_are_finite_and_derived_from_samples(self):
        for key, invalid in (("elapsed_ms", float("inf")), ("elapsed_ms", True),
                ("max_main_frame_ms", -1), ("max_main_frame_ms", float("nan")),
                ("worst_frame_start_usec", 0), ("end_usec", 105000), ("frame_observations", 0)):
            value = valid_guard_fixture()
            value["ramcache"]["ramcache-write-w1"]["hot_samples"][0][key] = invalid
            with self.subTest(key=key, invalid=invalid), self.assertRaises(RuntimeError):
                profile.verify_ramcache(value)
        value = valid_guard_fixture()
        value["ramcache_performance"]["1"]["hot_zero_debt"]["p95_ms"] = 0.1
        with self.assertRaises(RuntimeError): profile.verify_ramcache(value)

    def test_responsiveness_requires_matched_processes_and_preparation_inside_measured_window(self):
        # Deliberately synthetic guard inputs; these are never execution evidence.
        parent = valid_guard_fixture()
        parent["platform"] = "linux"
        graphics = {method:dict(available=True, value=value) for method,value in (
            ("get_current_rendering_driver_name", "opengl3"), ("get_current_rendering_method", "gl_compatibility"),
            ("get_video_adapter_name", "fixture"), ("get_video_adapter_vendor", "fixture"),
            ("get_video_adapter_api_version", "fixture"))}
        graphics["display_server"] = "X11"
        initial = dict(area_id="b", extent=[512,512], native_tick=0, game_tick=0, worker_threads=1,
            target_residency="COLD", active_handle=1, world_generation=2,
            **{key:"f"*64 for key in ("native_sha256","authoring_sha256","authored_source_sha256",
                "physics_profile_sha256","target_native_sha256","target_source_sha256")})
        frames = [dict(start_usec=200000+i*1000000, end_usec=200000+(i+1)*1000000, interval_usec=1000000,
            native_tick_before=i, native_tick_after=i+1, area_id="b", world_generation=2) for i in range(10)]
        group = {}
        for i, variant in enumerate(("control", "prefetch", "reversal")):
            group[variant] = dict(schema="gen006-ramcache-responsiveness-v1", completed=True, variant=variant,
                graphical=True, failures=[], process_id=100+i, checks=20, initial=copy.deepcopy(initial),
                comparison_valid=variant!="reversal", prefetch_busy_at_window_end=False, prefetch_records=[],
                identity=dict(native_runtime_sha256=parent["native_sha256"], source_revision=parent["source_commit"],
                    os_name="Linux", os_version="fixture", processor_name="fixture", logical_processors=4,
                    engine=dict(major=4,minor=7,hash="fixture"), graphics=copy.deepcopy(graphics)),
                apparatus=dict(requested_window_msec=10000, automatic_prediction_suppressed=True,
                    background_checkpointing=False, arrival_outside_window=True, active_area="b", prefetch_target="c"),
                window_start_usec=200000, window_end_usec=10200000, actual_window_usec=10000000,
                frame_intervals=copy.deepcopy(frames), native_ticks_observed_in_window=10,
                frame_statistics=dict(count=10,p50_ms=1000.0,p95_ms=1000.0,worst_ms=1000.0),
                io_at_window_end=dict(prefetch_requests=0 if i==0 else 1,prefetch_completed=1,prefetch_cancelled=1),
                target_hot_at_window_end=i==1,reversal_usec=2200000,
                arrival=dict(status="completed",residency="HOT",target_area="c" if i==1 else "a",start_usec=11000000,
                    prefetch_hit=True,prefetch_operation_id=str(i)*32,target_native_tick_before=1,
                    io_before=dict(profile_read_calls=1,profile_read_bytes=100,native_deserializations=1,
                        source_constructions=1,synchronous_publications=1,hot_handoffs=0,prefetch_hits=0),
                    io_after=dict(profile_read_calls=1,profile_read_bytes=100,native_deserializations=1,
                        source_constructions=1,synchronous_publications=1,hot_handoffs=1,prefetch_hits=1)),
                prepared_receipt=dict(identity=dict(area_id="c" if i==1 else "a",session_id="a"*32,
                    incarnation="b"*32,runtime_sha256=parent["native_sha256"],authored_source_sha256="f"*64),
                    active=False,failed=False,handle=3,resident_generation=1,physics_profile_sha256="f"*64,
                    worker_threads=1,schema=1,completed_tick=1,mutation_generation=2))
        group["prefetch"]["prefetch_records"] = [dict(area_id="c",source_residency="COLD",status="completed",
            start_usec=2200000,end_usec=3500000,operation_id="1"*32,
            phase_timestamps=dict(checkpoint_load_started_usec=2210000,checkpoint_load_finished_usec=2300000,
                cache_admission_started_usec=3400000,cache_admission_finished_usec=3450000),
            native_work=dict(prepare_started_usec=2400000,prepare_completed_usec=3000000,
                import_started_usec=3100000,import_completed_usec=3300000,prepared_before_activation=True,
                receipt=copy.deepcopy(group["prefetch"]["prepared_receipt"])))]
        group["reversal"]["prefetch_records"] = [
            dict(area_id="c",source_residency="COLD",status="cancelled",start_usec=2100000,end_usec=2400000,operation_id="3"*32),
            dict(area_id="a",source_residency="HOT",status="completed",start_usec=2500000,end_usec=2800000,operation_id="2"*32,
                native_work=dict(receipt=copy.deepcopy(group["reversal"]["prepared_receipt"])))]
        profile.verify_responsiveness(parent,1,group)
        for fault in ("late_admission","missing_phase","wrong_initial","reused_pid","frame_gap","fake_statistics",
                "no_progress","cold_at_deadline","invalid_comparison","headless_identity","different_renderer",
                "different_os","pending_prefetch","tick_jump","missing_generation","arrival_miss","arrival_restore",
                "prepared_handle","prepared_runtime","wrong_operation","missing_reversal","late_cancel"):
            changed=copy.deepcopy(group)
            if fault=="late_admission": changed["prefetch"]["prefetch_records"][0]["phase_timestamps"]["cache_admission_finished_usec"]=11200000
            elif fault=="missing_phase": del changed["prefetch"]["prefetch_records"][0]["native_work"]["import_started_usec"]
            elif fault=="wrong_initial": changed["prefetch"]["initial"]["native_sha256"]="e"*64
            elif fault=="reused_pid": changed["prefetch"]["process_id"]=100
            elif fault=="frame_gap": changed["control"]["frame_intervals"][1]["start_usec"]+=1
            elif fault=="fake_statistics": changed["prefetch"]["frame_statistics"]["worst_ms"]=1
            elif fault=="no_progress": changed["control"]["native_ticks_observed_in_window"]=0
            elif fault=="cold_at_deadline": changed["prefetch"]["target_hot_at_window_end"]=False
            elif fault=="invalid_comparison": changed["prefetch"]["comparison_valid"]=False
            elif fault=="headless_identity": changed["prefetch"]["identity"]["graphics"]["display_server"]="headless"
            elif fault=="different_renderer": changed["prefetch"]["identity"]["graphics"]["get_video_adapter_name"]["value"]="different"
            elif fault=="different_os": changed["prefetch"]["identity"]["os_name"]="Windows"
            elif fault=="pending_prefetch": changed["prefetch"]["prefetch_busy_at_window_end"]=True
            elif fault=="tick_jump": changed["prefetch"]["frame_intervals"][1]["native_tick_before"]=2
            elif fault=="missing_generation":
                for proof in changed.values():
                    del proof["initial"]["world_generation"]
                    for frame in proof["frame_intervals"]: del frame["world_generation"]
            elif fault=="arrival_miss": changed["prefetch"]["arrival"]["prefetch_hit"]=False
            elif fault=="arrival_restore": changed["prefetch"]["arrival"]["io_after"]["native_deserializations"]+=1
            elif fault=="prepared_handle": changed["prefetch"]["prepared_receipt"]["handle"]=99
            elif fault=="prepared_runtime": changed["prefetch"]["prepared_receipt"]["identity"]["runtime_sha256"]="0"*64
            elif fault=="wrong_operation": changed["prefetch"]["arrival"]["prefetch_operation_id"]="9"*32
            elif fault=="missing_reversal": changed["reversal"]["prefetch_records"]=[]
            else: changed["reversal"]["prefetch_records"][0]["end_usec"]=11200000
            with self.subTest(fault=fault), self.assertRaises(RuntimeError):
                profile.verify_responsiveness(parent,1,changed)

    def test_healthy_rescue_requires_two_source_bound_native_processes(self):
        parent=valid_guard_fixture()
        before={key:copy.deepcopy(parent[key]) for key in ("source_commit","source_tree","local_delta","missing_source_inputs","source_inputs_sha256")}
        identities=dict(godot_sha256=parent["engine_sha256"],native_sha256=parent["native_sha256"],source_files=copy.deepcopy(parent["source_inputs_sha256"]))
        proof=dict(passed=True,qualified_source=True,diagnostic=False,source_unchanged=True,inputs_unchanged=True,
            source_before=before,source_after=copy.deepcopy(before),before=identities,after=copy.deepcopy(identities),
            runs=[dict(mode=mode,passed=True,exit_code=0,timed_out=False,pid=20+i,observed_pid=20+i,checks=25,failures=0)
                for i,mode in enumerate(("seed","verify"))])
        profile.verify_healthy_recovery(parent,proof)
        for fault in ("diagnostic","source","runtime","failed","timeout","same_process","wrong_mode","missing_process"):
            changed=copy.deepcopy(proof)
            if fault=="diagnostic":changed["diagnostic"]=True
            elif fault=="source":changed["source_before"]["source_tree"]="0"*40
            elif fault=="runtime":changed["before"]["native_sha256"]="0"*64
            elif fault=="failed":changed["runs"][1]["exit_code"]=3
            elif fault=="timeout":changed["runs"][1]["timed_out"]=True
            elif fault=="same_process":changed["runs"][1].update(pid=20,observed_pid=20)
            elif fault=="wrong_mode":changed["runs"][1]["mode"]="seed"
            else:changed["runs"].pop()
            with self.subTest(fault=fault), self.assertRaises(RuntimeError):profile.verify_healthy_recovery(parent,changed)

    def test_missing_short_or_failed_graphical_execution_refused(self):
        for fault in ("missing", "headless", "failed", "same_pid", "few_hot", "few_warm"):
            with self.subTest(fault=fault):
                value = valid_guard_fixture()
                first = value["ramcache"]["ramcache-write-w1"]
                if fault == "missing": value["ramcache_schema"] = "donor-only"
                elif fault == "headless": first["graphical"] = False
                elif fault == "failed": first["failures"] = ["failure"]
                elif fault == "same_pid": value["ramcache"]["ramcache-reopen-w1"]["process_id"] = first["process_id"]
                else: first["hot_samples" if fault == "few_hot" else "warm_samples"].pop()
                with self.assertRaises(RuntimeError): profile.verify_ramcache(value)

    def test_bytes_as_hot_hidden_work_and_real_filesystem_activity_refused(self):
        faults = ("warm_as_hot", "debt", "ticks", "read", "deserialize", "construction", "flush", "native_capture",
                  "native_restore", "no_handoff", "os_read", "os_write", "no_os_telemetry")
        for fault in faults:
            with self.subTest(fault=fault):
                value = valid_guard_fixture()
                first = value["ramcache"]["ramcache-write-w1"]
                sample = first["hot_samples"][0]
                if fault == "warm_as_hot": sample["residency"] = "WARM"
                elif fault == "debt": sample["debt_before_ticks"] = 1
                elif fault == "ticks": sample["native_ticks_executed"] = 1
                elif fault in ("read", "deserialize", "construction", "flush"):
                    key = {"read": "profile_read_calls", "deserialize": "native_deserializations",
                        "construction": "source_constructions", "flush": "synchronous_publications"}[fault]
                    sample["io_after"] = dict(sample["io_after"], **{key: 99})
                elif fault in ("native_capture", "native_restore", "no_handoff"):
                    key = {"native_capture": "captures", "native_restore": "native_restorations", "no_handoff": "hot_activations"}[fault]
                    first["native_after"][key] = 99
                else:
                    key = {"os_read": "read_system_calls", "os_write": "write_system_calls", "no_os_telemetry": "available"}[fault]
                    first["filesystem_after"] = dict(first["filesystem_after"], **{key: False if fault == "no_os_telemetry" else 99})
                with self.assertRaises(RuntimeError): profile.verify_ramcache(value)

    def test_unperformed_prefetch_writeback_memory_or_recovery_refused(self):
        for fault in ("prefetch_completed", "prefetch_hits", "background_publications", "memory", "death", "diagnostic"):
            value = valid_guard_fixture()
            if fault in ("prefetch_completed", "prefetch_hits", "background_publications"):
                value["ramcache"]["ramcache-write-w4"]["evidence"]["cache_io"][fault] = 0
            elif fault == "memory": value["ramcache_memory"]["4"]["samples"] = []
            elif fault == "death": value["ramcache_recovery"]["rows"].pop()
            else: value["ramcache_recovery"]["qualified_source"] = False
            with self.subTest(fault=fault), self.assertRaises(RuntimeError): profile.verify_ramcache(value)


    def test_windows_console_child_identity_is_source_bound(self):
        # The producer also permits a direct Windows native process when the
        # actual Godot PID equals the launched handle; prove both arrangements.
        direct = valid_guard_fixture()
        direct["platform"] = "windows"
        direct["ramcache_recovery"]["platform"] = "nt"
        profile.verify_ramcache(direct)
        value = valid_guard_fixture()
        value["platform"] = "windows"
        proof = value["ramcache_recovery"]
        proof["platform"] = "nt"
        for index in range(len(profile.BOUNDARIES)):
            death, first, repeat = proof["rows"][index*3:index*3+3]
            launcher = death["pid"] + 50000
            death["launcher_pid"] = launcher
            death["native_identity"] = dict(native_pid=death["pid"],launcher_pid=launcher,
                                             parent_pid=launcher,relationship="windows-console-child")
            for child in (first,repeat):
                child["launcher_pid"] = child["pid"] + 50000
            if "seed" in death:
                seed = death["seed"]
                seed["launcher_pid"] = seed["pid"] + 50000
                seed["baseline"]["launcher_pid"] = seed["baseline"]["pid"] + 50000
        profile.verify_ramcache(value)
        invalid = copy.deepcopy(value)
        invalid["ramcache_recovery"]["rows"][0]["native_identity"]["parent_pid"] = 99
        with self.assertRaises(RuntimeError):
            profile.verify_ramcache(invalid)
        invalid = copy.deepcopy(value)
        invalid["ramcache_recovery"]["rows"][0]["native_identity"]["native_pid"] = 99
        with self.assertRaises(RuntimeError):
            profile.verify_ramcache(invalid)
        invalid = copy.deepcopy(value)
        invalid["ramcache_recovery"]["rows"][1]["launcher_pid"] = 0
        with self.assertRaises(RuntimeError):
            profile.verify_ramcache(invalid)
        invalid = copy.deepcopy(direct)
        invalid["ramcache_recovery"]["rows"][0]["native_identity"]["native_pid"] += 1
        with self.assertRaises(RuntimeError):
            profile.verify_ramcache(invalid)
        invalid = copy.deepcopy(direct)
        invalid["ramcache_recovery"]["rows"][0]["native_identity"]["relationship"] = "windows-console-child"
        with self.assertRaises(RuntimeError):
            profile.verify_ramcache(invalid)


    def test_additional_lifecycle_death_oracles_fail_closed(self):
        for fault in ("old_authoring_changed","new_authoring_changed","second_area_clock",
                      "unacknowledged_generation","queued_write_missing","write_barrier_missing",
                      "seed_process_reuse","seed_runtime_rewritten","new_dirty_not_witnessed"):
            with self.subTest(fault=fault):
                value = valid_guard_fixture()
                rows = value["ramcache_recovery"]["rows"]
                offset = list(profile.BOUNDARIES).index("newer_dirty_after_durable")*3
                queued = list(profile.BOUNDARIES).index("queued_dirty")*3
                if fault == "old_authoring_changed":
                    rows[offset]["seed"]["baseline"]["durable_oracle"]["areas"]["a"]["authoring_sha256"] = "f"*64
                elif fault == "new_authoring_changed":
                    rows[offset+1]["durable_oracle"]["areas"]["a"]["authoring_sha256"] = "f"*64
                elif fault == "second_area_clock":
                    rows[offset+1]["durable_oracle"]["areas"]["b"]["completed_tick"] = 1
                elif fault == "unacknowledged_generation":
                    rows[offset+1]["durable_oracle"]["areas"]["a"]["mutation_generation"] = 2
                elif fault == "queued_write_missing":
                    rows[queued]["observed_barrier"]["queued_requests"] = 0
                elif fault == "write_barrier_missing":
                    rows[queued]["barrier_witnesses"].pop(0)
                elif fault == "seed_process_reuse":
                    rows[offset]["seed"]["pid"] = rows[offset]["pid"]
                elif fault == "seed_runtime_rewritten":
                    rows[offset]["seed"]["baseline"]["native_sha256"] = "f"*64
                else:
                    rows[offset]["observed_barrier"]["live_native_tick"] = 5
                with self.assertRaises(RuntimeError):
                    profile.verify_ramcache(value)


    def test_child_custody_and_failed_recovery_cannot_be_relabelled(self):
        for fault in ("engine", "memory_pid", "phase_pid", "worker", "harness", "source", "binary", "failed_child",
                      "fake_kill", "wrong_barrier", "wrong_session", "wrong_tick", "reused_process", "changed_resume"):
            value = valid_guard_fixture()
            memory, recovery = value["ramcache_memory"]["1"], value["ramcache_recovery"]
            if fault == "engine": memory["godot_sha256"] = "z"*64
            elif fault == "memory_pid": memory["pid"] = -1
            elif fault == "phase_pid": memory["phases"][0]["pid"] += 1
            elif fault == "worker": memory["configured_workers"] = 4
            elif fault == "harness": memory["harness_sha256"] = "z"*64
            elif fault == "source": recovery["source_before"]["source_commit"] = "z"*40
            elif fault == "binary": recovery["native_sha256"] = "z"*64
            elif fault == "failed_child": recovery["rows"][1].update(ok=False, exit_code=7)
            elif fault == "fake_kill": recovery["rows"][0]["forced_termination"] = False
            elif fault == "wrong_barrier": recovery["rows"][0]["observed_barrier"]["pid"] += 1
            elif fault == "wrong_session": recovery["rows"][1]["session_id"] = "b"*32
            elif fault == "wrong_tick": recovery["rows"][1]["expected_tick"] = 4
            elif fault == "reused_process": recovery["rows"][2]["pid"] = recovery["rows"][1]["pid"]
            else: recovery["rows"][2]["native_sha256"] = "f"*64
            with self.subTest(fault=fault), self.assertRaises(RuntimeError): profile.verify_ramcache(value)


class PublicationGuards(unittest.TestCase):
    def test_reciprocal_package_requires_host_bytes_binding_and_clean_platform_roster(self):
        guard = package.donor.reciprocal
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / guard.WINDOWS_CLI).parent.mkdir(parents=True)
            content = b"Windows reciprocal test payload"
            binding = json.dumps({"platform": "windows", "artifact": guard.WINDOWS_CLI,
                                  "bytes": len(content), "sha256": hashlib.sha256(content).hexdigest(),
                                  "native_definition_inputs_sha256": {"example.cpp": "a" * 64}}).encode()
            (root / guard.WINDOWS_BINDING).write_bytes(binding)
            (root / guard.WINDOWS_CLI).write_bytes(content)
            guard.verify_bound_package(root, hashlib.sha256(binding).hexdigest())
            with self.assertRaisesRegex(ValueError, "no admitted"):
                guard.verify_bound_package(root, None)
            with tempfile.TemporaryDirectory() as historical:
                guard.verify_bound_package(Path(historical), None)
            with patch.object(guard, "committed_binding", return_value=binding):
                guard.verify_package(root, root)
                with patch.object(guard, "definition_inputs", return_value={}):
                    with self.assertRaisesRegex(ValueError, "definition"):
                        guard.windows_cli_replacement(root)
                for foreign in guard.FOREIGN_PATHS:
                    (root / foreign).touch()
                    with self.assertRaisesRegex(ValueError, "Linux"):
                        guard.verify_package(root, root)
                    (root / foreign).unlink()
                (root / guard.WINDOWS_CLI).write_bytes(b"x" * len(content))
                with self.assertRaisesRegex(ValueError, "executable"):
                    guard.verify_package(root, root)
                (root / guard.WINDOWS_BINDING).write_text("{}")
                with self.assertRaisesRegex(ValueError, "binding"):
                    guard.verify_package(root, root)

    def _execute_campaign_probe(self, selected, outcome):
        # Orchestration-only probe: native/runtime/custody checks are mocked here,
        # never reported as application qualification. Exercise the actual execute
        # function so timeout selection and publication refusal are behavioral.
        with tempfile.TemporaryDirectory() as directory, ExitStack() as stack:
            root = Path(directory)
            engine = selected.engine
            manifest = {"source_inputs": {"native": "c"*64}, "build_inputs": {"runner": "d"*64}}
            args = SimpleNamespace(platform="windows", source_sha="a"*40,
                bundle=root/"bundle", godot_archive=root/"godot.zip")
            stack.enter_context(patch.object(engine, "ROOT", root))
            stack.enter_context(patch.object(selected.sys, "platform", "win32"))
            stack.enter_context(patch.dict(os.environ, {"GITHUB_RUN_ATTEMPT":"1", "GITHUB_RUN_ID":"123"}))
            verify = stack.enter_context(patch.object(engine, "verify_bundle", return_value=manifest))
            stack.enter_context(patch.object(selected.shutil, "copyfile"))
            stack.enter_context(patch.object(selected, "sha", return_value=engine.RAPIER["windows"][1]))
            stack.enter_context(patch.object(selected, "prepare_godot", return_value=(root/"godot.exe", {})))
            stack.enter_context(patch.object(engine, "runtime_identity", return_value={"sha256":"e"*64}))
            stack.enter_context(patch.object(selected, "verify_build_ledger"))
            stack.enter_context(patch.object(engine, "input_ledgers", return_value=copy.deepcopy(manifest)))
            stack.enter_context(patch.object(engine, "manifest_path", return_value=root/"manifest.json"))
            checked = stack.enter_context(patch.object(selected, "verify_case_results"))
            writes = []
            stack.enter_context(patch.object(engine, "write_json", side_effect=lambda path, value:
                writes.append((path, copy.deepcopy(value)))))
            run = stack.enter_context(patch.object(selected, "execute_campaign",
                **({"side_effect":outcome} if isinstance(outcome, Exception) else {"return_value":outcome})))
            if isinstance(outcome, Exception):
                with self.assertRaises(type(outcome)): selected.execute(args)
            elif outcome.returncode:
                with self.assertRaisesRegex(RuntimeError, "no validated runtime published"): selected.execute(args)
            else:
                selected.execute(args)
            run.assert_called_once()
            command = run.call_args.args[0]
            self.assertEqual(command[:2], [sys.executable, str(root/selected.CAMPAIGN_SCRIPT)])
            self.assertIn("--require-clean-source", command)
            timeout = selected.CAMPAIGN_TIMEOUT_SECONDS[args.platform]
            self.assertEqual(run.call_args.kwargs, {"cwd":root, "timeout":timeout, "bundle":args.bundle})
            self.assertEqual(writes[0][1]["campaign_timeout_seconds"], timeout)
            if isinstance(outcome, Exception) or outcome.returncode:
                checked.assert_not_called()
                self.assertEqual(len(writes), 1)
                self.assertEqual(writes[0][1]["status"], "running")
                self.assertIs(writes[0][1]["completed"], False)
                verify.assert_called_once_with(args.bundle, "windows", args.source_sha, validated=False)
                self.assertNotIn("status", manifest)
            else:
                checked.assert_called_once()
                self.assertEqual(writes[-1][1]["status"], "validated-development-runtime")
                self.assertEqual(verify.call_args.kwargs, {"validated":True})

    def test_bounded_private_campaign_timeout_preserves_donor_policy(self):
        self.assertIsNot(profile.donor, original)
        self.assertIs(profile.donor.execute.__globals__, profile.donor.__dict__)
        self.assertIsNot(profile.donor.CAMPAIGN_TIMEOUT_SECONDS, original.CAMPAIGN_TIMEOUT_SECONDS)
        self.assertEqual(original.CAMPAIGN_TIMEOUT_SECONDS, {"linux":3600,"windows":3600})
        self.assertEqual(profile.donor.CAMPAIGN_TIMEOUT_SECONDS, {"linux":3600,"windows":7200})
        self.assertIs(profile.donor.execute_campaign, profile.execute_owned_campaign)
        self.assertIsNot(original.execute_campaign, profile.execute_owned_campaign)
        for selected in (original, profile.donor):
            with self.subTest(profile=selected.CAMPAIGN_SCRIPT):
                self._execute_campaign_probe(selected, subprocess.CompletedProcess([], 0))
        workflow = (ROOT/profile.engine.WORKFLOW).read_text()
        windows = workflow.split("  windows-execution:\n", 1)[1].split("\n  publish:", 1)[0]
        minutes = int(re.search(r"(?m)^    timeout-minutes: ([0-9]+)$", windows).group(1))
        self.assertEqual(minutes, 150)
        self.assertGreaterEqual(minutes*60-profile.donor.CAMPAIGN_TIMEOUT_SECONDS["windows"], 1800)
        # A longer watchdog is not permission to omit native or portable gates.
        self.assertTrue(original.REQUIRED_LABELS <= profile.REQUIRED_LABELS)
        for marker in ("Run Automated Smoke.ps1", "Run RAM Cache Smoke.ps1", "Open Workbench.cmd",
                "Original package files mutated during smoke", "Retain Windows runtime and complete original evidence"):
            self.assertIn(marker, windows)

    def test_timeout_and_nonzero_campaign_never_validate_a_runtime(self):
        for outcome in (subprocess.TimeoutExpired(["campaign"], 7200), subprocess.CompletedProcess([], 7)):
            with self.subTest(outcome=type(outcome).__name__):
                self._execute_campaign_probe(profile.donor, outcome)

    def test_donor_default_keeps_dynamic_subprocess_boundary(self):
        command=["qualified-campaign"]
        with patch.object(original.subprocess,"run",return_value=subprocess.CompletedProcess(command,7)) as run:
            result=original.execute_campaign(command,cwd=Path("cwd"),timeout=3600,bundle=Path("bundle"))
        self.assertEqual(result.returncode,7)
        run.assert_called_once_with(command,cwd=Path("cwd"),timeout=3600)

    def test_retirement_receipt_is_current_and_does_not_hide_failure(self):
        # Orchestration fault injection only. Actual process trees are qualified
        # separately on Linux/Windows by test_bounded_campaign_process.py.
        for mode in ("success","nonzero","timeout","unknown","unknown-timeout",
                     "missing","wrong-command","boolean-timeout","false-proof","missing-pid",
                     "boolean-pid","negative-pid","no-child-with-members","list-proof-timeout"):
            with self.subTest(mode=mode),tempfile.TemporaryDirectory() as directory:
                root=Path(directory);output=root/"outputs";command=["exact-campaign"]
                output.write_text("campaign_retirement_record=stale\ncampaign_retired_record=stale\n")
                stale=root/"campaign-process-owner-stale.json"
                stale.write_text(json.dumps({"retired":True,"status":"retired"}))
                outcome=subprocess.TimeoutExpired(command,7200)
                records=[]
                def invoke(actual,*,cwd,timeout,record_path):
                    records.append(record_path)
                    self.assertEqual(actual,command);self.assertEqual(cwd,root)
                    self.assertEqual(timeout,7200);self.assertNotEqual(record_path,stale)
                    self.assertEqual(json.loads(record_path.read_text()),{"status":"reserved","retired":False})
                    value={"schema":"gen006-campaign-process-owner-v1","command":command,
                        "timeout_seconds":7200,"retired":True,"status":"retired","pid":123,
                        "process_created":True,"method":"owned-linux-process-group","retirement_error":"",
                        "retirement_proof":{"complete":True}}
                    if mode.startswith("unknown"):
                        value.update(retired=False,status="retirement-unproven",retirement_proof={"complete":False})
                    if mode=="wrong-command":value["command"]=["stale-campaign"]
                    if mode=="boolean-timeout":value["timeout_seconds"]=True
                    if mode=="false-proof":value["retirement_proof"]["complete"]=False
                    if mode=="missing-pid":del value["pid"]
                    if mode=="boolean-pid":value["pid"]=True
                    if mode=="negative-pid":value["pid"]=-1
                    if mode=="no-child-with-members":
                        value.update(process_created=False,pid=None,original_error="refusal")
                        value["retirement_proof"].update(no_process_created=True,scope="no process created",retained_job_pids=[123])
                    if mode=="list-proof-timeout":value["retirement_proof"]=[]
                    if mode!="missing":record_path.write_text(json.dumps(value))
                    if mode in ("timeout","unknown-timeout","list-proof-timeout"):raise outcome
                    return subprocess.CompletedProcess(command,7 if mode=="nonzero" else 0)
                with patch.dict(os.environ,{"GITHUB_OUTPUT":str(output)}),patch.object(profile.process_owner,"run_campaign",side_effect=invoke):
                    if mode in ("timeout","unknown-timeout","list-proof-timeout"):
                        with self.assertRaises(subprocess.TimeoutExpired) as caught:
                            profile.execute_owned_campaign(command,cwd=root,timeout=7200,bundle=root)
                        self.assertIs(caught.exception,outcome)
                    elif mode in ("missing","wrong-command","boolean-timeout","false-proof","missing-pid",
                                  "boolean-pid","negative-pid","no-child-with-members"):
                        with self.assertRaisesRegex(RuntimeError,"receipt"):
                            profile.execute_owned_campaign(command,cwd=root,timeout=7200,bundle=root)
                    else:
                        result=profile.execute_owned_campaign(command,cwd=root,timeout=7200,bundle=root)
                        self.assertEqual(result.returncode,7 if mode=="nonzero" else 0)
                fields=dict(line.split("=",1) for line in output.read_text().splitlines())
                self.assertEqual(fields["campaign_retirement_record"],records[0].name)
                positive=mode in ("success","nonzero","timeout")
                self.assertEqual(fields["campaign_retired_record"],records[0].name if positive else "")
                self.assertEqual(json.loads(stale.read_text()),{"retired":True,"status":"retired"})

    def test_inherited_portable_smoke_explicitly_qualifies_only_the_cold_path(self):
        source = ast.parse((ROOT/"tools/package_gen006_persistent_areas.py").read_text())
        values = [ast.literal_eval(node.value) for node in source.body if isinstance(node, ast.Assign)
            and any(isinstance(target, ast.Name) and target.id == "SMOKE" for target in node.targets)]
        self.assertEqual(len(values), 1)
        original = values[0]
        changed = package._legacy_cold_smoke(original)
        self.assertEqual(changed, package.donor.SMOKE)
        self.assertEqual(changed.count("--persistent-cache-off"), 1)
        self.assertEqual(changed.replace(",'--persistent-cache-off'", "", 1), original)
        self.assertNotIn("--persistent-cache-off", package.RAM_SMOKE)
        anchor = "'--persistent-start-paused','--persistent-require-graphics')"
        for invalid in (original.replace(anchor, ""), original+anchor, changed,
                original.replace("res://tests/test_persistent_areas_workbench.gd", "res://tests/another.gd")):
            with self.subTest(invalid=invalid[-70:]), self.assertRaises(RuntimeError):
                package._legacy_cold_smoke(invalid)

    def test_separate_engine_and_all_donor_fences(self):
        self.assertIsNot(profile.engine, original.engine)
        self.assertEqual(original.engine.BRANCH, "exp/gen006-persistent-areas-001-20261121")
        for name in ("context", "require_publication_request", "check_source", "check_index", "input_ledgers",
                     "runtime_identity", "record_build", "stage", "verify_bundle"):
            self.assertEqual(inspect.getsource(getattr(profile.engine, name)), inspect.getsource(getattr(original.engine, name)))
        self.assertTrue(original.REQUIRED_LABELS <= profile.REQUIRED_LABELS)
        self.assertEqual(profile.engine.BRANCH, "exp/gen006-ramcache-finisher-001-20261122")
        self.assertEqual(profile.donor.CAMPAIGN_SCRIPT, "tools/ci/run_persistent_area_ramcache_qualification.py")

    def test_explicit_standard_host_stacked_routing(self):
        text = (ROOT/profile.engine.WORKFLOW).read_text()
        self.assertNotIn("workflow_dispatch:", text)
        self.assertNotIn("pull_request_target:", text)
        self.assertIn("github.base_ref == 'main'", text)
        self.assertIn("needs: [linux, windows-execution]", text)
        self.assertEqual(text.count("contents: write"), 1)
        self.assertIn('git push --force-with-lease="refs/heads/'+profile.engine.BRANCH+':$GITHUB_SHA"', text)
        self.assertTrue(set(re.findall(r"(?m)^\s+runs-on:\s*(\S+)", text)) <= {"ubuntu-24.04", "windows-2022"})
        self.assertNotIn("gh pr merge", text)
        self.assertNotIn("gh pr ready", text)
        self.assertNotIn("run_gentek80", text)
        self.assertIn("Run RAM Cache Smoke.ps1", text)
        path = ROOT/profile.engine.REQUEST
        if path.exists():
            request = json.loads(path.read_text())
            self.assertEqual(set(request), set(profile.engine.REQUEST_VALUE) | {"request_sequence"})
            self.assertEqual({k:v for k,v in request.items() if k != "request_sequence"}, profile.engine.REQUEST_VALUE)
            self.assertIs(type(request["request_sequence"]), int)
            self.assertGreater(request["request_sequence"], 0)

    def test_portable_smoke_requires_actual_process_custody_and_executed_platform_guards(self):
        # The successor directly owns the real engine process. Its Windows
        # PowerShell5 failure guards execute the complete actual script.
        for fragment in ("New-Object System.Diagnostics.ProcessStartInfo", "$receipt.process_id -ne $actualPid",
                         "$cache.process_id -ne $actualPid", "$done.pid -ne $actualPid", "packaged-processes.json",
                         "test_persistent_area_ramcache.gd", "prefetch_hits -lt 1", "background_publications -lt 1"):
            self.assertIn(fragment, package.RAM_SMOKE)
        self.assertIn("test_gen006_ramcache_packaged_smoke.ps1 -Output", (ROOT/profile.engine.WORKFLOW).read_text())


if __name__ == "__main__":
    unittest.main()
