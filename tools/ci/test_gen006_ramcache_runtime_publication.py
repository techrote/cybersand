#!/usr/bin/env python3
"""Reject synthetic cache-hit claims and unsafe successor publication routing."""
from __future__ import annotations

import copy
import inspect
import json
from pathlib import Path
import re
import sys
import unittest

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
        target_native_tick_before=0, target_native_tick_after=0)
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
    value = {"ramcache_schema": "gen006-ramcache-qualification-v1", "native_sha256": "a"*64,
        "engine_sha256": "b"*64, "source_commit": "c"*40, "source_tree": "d"*40,
        "local_delta": [], "missing_source_inputs": [], "source_inputs_sha256": {
            "tools/ci/run_persistent_area_residency_memory.py": "e"*64,
            "godot/tests/test_persistent_area_residency_memory.gd": "f"*64},
        "ramcache": {}, "ramcache_memory": {}}
    before = {key:copy.deepcopy(value[key]) for key in ("source_commit", "source_tree", "local_delta", "missing_source_inputs", "source_inputs_sha256")}
    proof = dict(ok=True, qualified_source=True, diagnostic=False, source_unchanged=True,
        source_before=before, source_after=copy.deepcopy(before), rows=[],
        source_commit=value["source_commit"], source_tree=value["source_tree"],
        engine_sha256=value["engine_sha256"], native_sha256=value["native_sha256"],
        binaries_before={"/engine": "b"*64, "/native": "a"*64}, binaries_after={"/engine": "b"*64, "/native": "a"*64})
    for index, phase in enumerate(profile.BOUNDARIES):
        pid = 100+index*3
        proof["rows"].append(dict(kind="intentional_process_death", pid=pid, exit_code=-9, ok=True,
            boundary=phase, forced_termination=True, observed_barrier={"pid": pid, "phase": phase, "session_id": "a"*32}))
        for offset in (1, 2):
            proof["rows"].append(dict(kind="fresh_process_recovery", pid=pid+offset, observed_pid=pid+offset,
                exit_code=0, ok=True, boundary=phase, expected_tick=4 if phase == "after_publish" else 0,
                checks=8, session_id="a"*32, native_sha256="c"*64, physical_hash="d"*16))
    value["ramcache_recovery"] = proof
    for workers in (1, 4):
        value["ramcache"][f"ramcache-write-w{workers}"] = copy.deepcopy(receipt)
        value["ramcache"][f"ramcache-reopen-w{workers}"] = dict(copy.deepcopy(receipt), process_id=11)
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
    def test_separate_engine_and_all_donor_fences(self):
        self.assertIsNot(profile.engine, original.engine)
        self.assertEqual(original.engine.BRANCH, "exp/gen006-persistent-areas-001-20261121")
        for name in ("context", "require_publication_request", "check_source", "check_index", "input_ledgers",
                     "runtime_identity", "record_build", "stage", "verify_bundle"):
            self.assertEqual(inspect.getsource(getattr(profile.engine, name)), inspect.getsource(getattr(original.engine, name)))
        self.assertTrue(original.REQUIRED_LABELS <= profile.REQUIRED_LABELS)
        self.assertEqual(profile.engine.BRANCH, "exp/gen006-ramcache-001-20261122")
        self.assertEqual(profile.donor.CAMPAIGN_SCRIPT, "tools/ci/run_persistent_area_ramcache_qualification.py")

    def test_explicit_standard_host_stacked_routing(self):
        text = (ROOT/profile.engine.WORKFLOW).read_text()
        self.assertNotIn("workflow_dispatch:", text)
        self.assertNotIn("pull_request_target:", text)
        self.assertIn("github.base_ref == 'exp/gen006-persistent-areas-001-20261121'", text)
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
