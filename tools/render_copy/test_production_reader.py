#!/usr/bin/env python3
"""Adverse readback controls over actual retained graphical receipts.

No fabricated fixture is promoted to runtime evidence. With receipt arguments,
the reader first accepts the original then must refuse each corrupted copy.
Without arguments, only small input-admission unit tests run.
"""
from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

import run_production_campaign as campaign
from run_production_campaign import (
    graphics_classification, parse_cohort, percentiles, read_json, reduce_trace,
    unique_object,
)


class AdmissionTests(unittest.TestCase):
    def test_software_renderers_cannot_claim_hardware(self):
        for name in ("llvmpipe (LLVM 20.1.2, 256 bits)", "SwiftShader Device", "Microsoft Basic Render Driver", "GDI Generic", "lavapipe"):
            self.assertEqual(graphics_classification(name), "software")
        self.assertEqual(graphics_classification("NVIDIA TITAN RTX/PCIe/SSE2"), "hardware_adapter_reported")
        self.assertEqual(graphics_classification("unknown adapter"), "unclassified")

    def test_unknown_or_ambiguous_cohorts_are_refused(self):
        for value in ("play:N:0:extra", "play:unknown:0", "unknown:N:0", "play:N:-1", "play:N:1", "play:N:050000"):
            with self.assertRaises(ValueError):
                parse_cohort(value)
        self.assertEqual(parse_cohort("play:N:50000"), {"workload": "play", "arm": "N", "consumer_usec": 50000})
        self.assertEqual(parse_cohort("play:D:0"), {"workload": "play", "arm": "D", "consumer_usec": 0})
        self.assertEqual(campaign.VARIANTS, ("R", "ER"))

    def test_duplicate_source_identity_fields_are_refused(self):
        with self.assertRaises(ValueError):
            json.loads('{"source_sha":"one","source_sha":"two"}', object_pairs_hook=unique_object)

    def test_invalid_measurement_population_is_not_a_percentile(self):
        for value in (float("nan"), float("inf"), -1, True, "3"):
            with self.assertRaises(ValueError):
                percentiles([0, value])


def unit_events(rows):
    """Small synthetic validator inputs only, never graphical evidence."""
    return [{"event": kind, "event_sequence": i+1, "usec": clock, **fields}
            for i, (kind, clock, fields) in enumerate(rows)]


def unit_delayed_ack():
    identity = {"serial": 5, "queue_sequence": 1, "queued_usec": 100,
                "due_usec": 100100, "delay_usec": 100000}
    return {"arm": "D", "ack_mode": "delayed", "ack_delay_usec": 100000,
            "ack_queue_capacity": 256, "ack_queue_high_water": 1,
            "ack_queue_overflows": 0, "ack_queue_errors": 0, "ack_queue_remaining": 0,
            "events": unit_events([
                ("texture_success", 90, {"serial": 5}),
                ("ack_queued", 101, {**identity, "queue_count": 1}),
                ("ack_delay_release", 100101, {**identity, "released_usec": 100100, "queue_count": 0}),
                ("ack_issue", 100102, {"serial": 5}),
                ("ack_visible", 100103, {"serial": 5}),
                ("ack_observed", 100104, {"ack_serial": 5, "will_clear": True}),
                ("ack_clear", 100105, {"ack_serial": 5, "pending_serial": 5}),
                ("owner_end", 100106, {}), ("owner_end", 100107, {}),
                ("tail_caught_up", 100108, {"owner_count": 12, "ack_empty_owner_count": 10, "ack_queue_remaining": 0}),
                ("owner_joined", 100109, {})])}


def unit_baseline():
    identity = {"serial": 1, "generation": 1, "channels": 2, "bytes": 2097152,
                "accept_usec": 10, "birth_refresh": 1}
    return {"baseline_observer_errors": 0,
            "baseline_timing_scope": "post-operation owner observer timestamps; not allocator lifetime",
            "events": unit_events([
                ("baseline_begin", 10, {**identity, "refresh": 1}),
                ("production_append_end", 11, {"accepted": True, "packet_full": True, "packet_bytes": 2097152,
                    "refresh": 1, "after": {"pending_serial": 1, "generation": 1}}),
                ("ack_clear", 20, {"refresh": 2, "pending_serial": 1, "ack_serial": 1}),
                ("baseline_end", 21, {**identity, "refresh": 2, "end_usec": 20, "lifetime_usec": 10,
                    "reason": "ack", "covering_ack_serial": 1, "replacement_serial": 0,
                    "replacement_generation": 0, "pending_serial_at_retirement": 1})])}


def unit_worker_memory():
    rows = [("worker_config", 1, {"generation": 1, "refresh": 1, "requested_native_workers": 0,
                "actual_native_workers": 4, "logical_processors": 8}),
            ("native_end", 2, {"generation": 1}),
            ("owner_end", 3, {"refresh": 1, "generation": 1, "bytes": 2097152, "rectangles": 1}),
            ("owner_payload_bytes", 4, {"refresh": 1, "generation": 1, "pending_bytes": 2097152,
                "pending_rectangles": 1, "published_bytes": 2097152, "published_rectangles": 1, "legacy_full_bytes": 2097152})]
    stages = ["before_host", "startup", "before_reset", "frame", "frame", "measurement_end", "tail_drained", "owner_joined", "oracles_complete"]
    frame = 0
    for i, stage in enumerate(stages):
        rows.append(("memory_sample", 5+i, {"stage": stage, "frame": frame if stage == "frame" else -1,
                    "godot_static_bytes": 100+i, "godot_static_peak_bytes": 200+i}))
        frame += stage == "frame"
    return {"arm": "N", "workload": "paused", "frame_count": 2, "native_workers_mode": "auto",
            "native_worker_request": 0, "actual_native_workers": 4, "native_worker_config_source": "project-default-auto",
            "native_worker_count_scope": "configured native pool capacity; not observed task participation or concurrency",
            "memory_scope": "Godot tracked allocator only; excludes untracked native allocations and GPU/driver memory",
            "memory_window": "process allocator peak observed through oracles_complete; before trace export and receipt serialization",
            "memory_sample_count": len(stages), "godot_static_peak_bytes": 208,
            "payload_memory_scope": "logical array lengths; may share COW storage; not unique allocated bytes or capacity",
            "ack_queue_logical_storage_bytes": 0, "published_high_water": 2097152, "legacy_full_high_water": 2097152,
            "events": unit_events(rows)}


def unit_freshness():
    identity1 = {"snapshot_serial": 1, "serial": 1, "generation": 1, "revision": 1}
    identity2 = {"snapshot_serial": 3, "serial": 2, "generation": 2, "revision": 2}
    def owner(snapshot, packet, generation, refresh, published, end):
        return {"snapshot_serial": snapshot, "pending_serial": packet, "generation": generation,
                "render_generation": generation, "revision": generation, "refresh": refresh,
                "full": True, "published_usec": published, "end_usec": end, "duration_usec": 15}
    return {"events": unit_events([
        ("native_end", 9, {"refresh": 1, "packet_full": True, "start_usec": 1, "end_usec": 9}),
        ("render_consume", 15, identity1), ("texture_success", 17, identity1),
        ("consumer_displayed", 18, identity1), ("owner_end", 21, owner(1, 1, 1, 1, 10, 20)),
        ("render_consume", 35, {**identity1, "snapshot_serial": 2}),
        ("owner_end", 41, owner(2, 1, 1, 2, 30, 40)),
        ("reset_request", 45, {"frame": 0, "generation": 1}),
        ("native_end", 49, {"refresh": 3, "packet_full": True, "start_usec": 45, "end_usec": 49}),
        ("render_consume", 55, identity2), ("texture_success", 57, identity2),
        ("consumer_displayed", 58, identity2), ("owner_end", 61, owner(3, 2, 2, 3, 50, 60)),
        ("frame_end", 80, {"frame": 0, "start_usec": 0, "end_usec": 80, "duration_usec": 80})])}


class NewEvidenceTests(unittest.TestCase):
    def refuses_changes(self, fixture, validator, mutations):
        validator(fixture)
        for name, mutate in mutations.items():
            with self.subTest(name=name):
                changed = copy.deepcopy(fixture)
                mutate(changed)
                with self.assertRaises((ValueError, KeyError, TypeError)):
                    validator(changed)

    def test_delayed_ack_requires_real_success_and_at_least_100ms(self):
        first = lambda d, name: next(e for e in d["events"] if e["event"] == name)
        self.refuses_changes(unit_delayed_ack(), campaign.validate_ack_evidence, {
            "failed-upload": lambda d: first(d, "texture_success").update(event="reject"),
            "early-release": lambda d: first(d, "ack_delay_release").update(released_usec=100099),
            "early-ordinary-ACK": lambda d: first(d, "ack_issue").update(usec=102),
            "invented-ACK-observation": lambda d: first(d, "ack_observed").update(ack_serial=6),
            "noncovering-ACK": lambda d: first(d, "ack_clear").update(pending_serial=6),
            "queue-overflow": lambda d: d.update(ack_queue_overflows=1),
            "queue-not-drained": lambda d: d.update(ack_queue_remaining=1),
            "queue-peak-forged": lambda d: d.update(ack_queue_high_water=2),
            "queue-count-forged": lambda d: first(d, "ack_queued").update(queue_count=2),
            "queue-sequence-forged": lambda d: first(d, "ack_queued").update(queue_sequence=2),
            "delay-mislabeled": lambda d: d.update(ack_delay_usec=0),
            "owner-tail-short": lambda d: first(d, "tail_caught_up").update(owner_count=11),
            "owner-tail-count-only": lambda d: d["events"].remove(first(d, "owner_end")),
            "post-join-release": lambda d: first(d, "owner_joined").update(event_sequence=1),
        })
        result = campaign.validate_ack_evidence(unit_delayed_ack())
        self.assertEqual(result["ack_queue_to_issue_usec"]["p99"], 100002)

    def test_baseline_retirement_requires_actual_covering_ack_or_full_successor(self):
        first = lambda d, name: next(e for e in d["events"] if e["event"] == name)
        self.refuses_changes(unit_baseline(), campaign.validate_baseline_lifetimes, {
            "fake-clear": lambda d: first(d, "ack_clear").update(ack_serial=0),
            "wrong-generation": lambda d: first(d, "baseline_end").update(generation=2),
            "fake-lifetime": lambda d: first(d, "baseline_end").update(lifetime_usec=9),
            "reset-is-not-retirement": lambda d: first(d, "baseline_end").update(reason="reset"),
            "unaccepted-full": lambda d: first(d, "production_append_end").update(accepted=False),
            "missing-retirement": lambda d: d["events"].remove(first(d, "baseline_end")),
            "fake-replacement": lambda d: first(d, "baseline_end").update(reason="full_replacement",
                covering_ack_serial=0, replacement_serial=2, replacement_generation=1),
            "allocation-lifetime-claim": lambda d: d.update(baseline_timing_scope="allocator lifetime"),
        })

    def test_memory_and_worker_scope_are_verified_without_allocation_fictions(self):
        first = lambda d, name: next(e for e in d["events"] if e["event"] == name)
        self.refuses_changes(unit_worker_memory(), campaign.validate_worker_memory, {
            "auto-forced-one": lambda d: first(d, "worker_config").update(actual_native_workers=1),
            "false-request": lambda d: d.update(native_worker_request=1),
            "missing-generation": lambda d: first(d, "native_end").update(generation=2),
            "participation-claim": lambda d: d.update(native_worker_count_scope="all workers participated"),
            "false-RSS-claim": lambda d: d.update(memory_scope="complete process RSS"),
            "false-exit-peak": lambda d: d.update(memory_window="complete process lifetime"),
            "nonfinite-memory": lambda d: first(d, "memory_sample").update(godot_static_bytes=float("nan")),
            "bool-memory": lambda d: first(d, "memory_sample").update(godot_static_bytes=True),
            "low-peak": lambda d: d.update(godot_static_peak_bytes=0),
            "inflated-peak": lambda d: d.update(godot_static_peak_bytes=999999),
            "missing-sample": lambda d: d.update(memory_sample_count=0),
            "fake-frame-population": lambda d: next(e for e in d["events"] if e.get("stage") == "frame").update(frame=1),
            "fake-payload-peak": lambda d: d.update(published_high_water=0),
            "wrong-owner": lambda d: first(d, "owner_payload_bytes").update(refresh=2),
            "unique-allocation-claim": lambda d: d.update(payload_memory_scope="unique allocated bytes"),
        })
        result = campaign.validate_worker_memory(unit_worker_memory())
        self.assertEqual(result["godot_tracked_allocator_frame_bytes"]["n"], 2)
        self.assertIn("No allocation count measured", result["logical_payload_scope"])

    def test_freshness_matches_exact_owners_and_allows_real_publication_return_races(self):
        first = lambda d, name: next(e for e in d["events"] if e["event"] == name)
        self.refuses_changes(unit_freshness(), campaign.derive_freshness, {
            "missing-owner": lambda d: first(d, "render_consume").update(snapshot_serial=999),
            "future-status-same-render-serial": lambda d: first(d, "render_consume").update(snapshot_serial=2),
            "wrong-render-generation": lambda d: first(d, "render_consume").update(generation=2),
            "impossible-authority-revision": lambda d: first(d, "render_consume").update(revision=999),
            "publication-after-return": lambda d: first(d, "owner_end").update(published_usec=22),
            "publication-before-call": lambda d: first(d, "owner_end").update(published_usec=0),
            "submission-from-another-snapshot": lambda d: first(d, "texture_success").update(snapshot_serial=2),
            "unmatched-consumer-completion": lambda d: first(d, "consumer_displayed").update(serial=2),
        })
        result = campaign.derive_freshness(unit_freshness())
        self.assertEqual(result["consumers_before_owner_return_observation"], 3)
        self.assertEqual(result["render_publication_to_consume_usec"]["lower_bound"]["max"], 0)
        self.assertEqual(result["render_publication_to_consume_usec"]["upper_bound"]["max"], 5)
        self.assertEqual(result["retained_payload_to_all_consume_usec"]["upper_bound"]["max"], 25)
        self.assertEqual(result["unchanged_payload_consume_count"], 1)
        self.assertEqual(result["reset_to_first_new_generation_submission_usec"], 12)
        self.assertEqual(result["reset_overlap_frame_usec"]["max"], 80)

    def test_startup_is_explicit_and_not_a_gpu_or_process_launch_claim(self):
        fixture = {"workload": "play", "startup_times_usec": {"harness_entry": 1, "host_begin": 2,
            "host_ready": 10, "play_ready": 20, "measurement_begin": 21, "first_frame_submitted": 15},
            "startup_timing_scope": "harness-entry-relative CPU/host milestones and first frame_post_draw observation; not process-launch or GPU completion latency",
            "events": unit_events([("startup_first_frame_submitted", 16, {"submitted_usec": 15}),
                ("measurement_begin", 22, {"start_usec": 21})])}
        self.refuses_changes(fixture, campaign.validate_startup, {
            "missing-host-construction": lambda d: d["startup_times_usec"].pop("host_begin"),
            "reordered-host": lambda d: d["startup_times_usec"].update(host_begin=11),
            "uninstalled-PLAY": lambda d: d["startup_times_usec"].update(play_ready=0),
            "frame-before-host": lambda d: d["startup_times_usec"].update(first_frame_submitted=9),
            "unmatched-first-frame": lambda d: d["startup_times_usec"].update(first_frame_submitted=16),
            "false-GPU-completion": lambda d: d.update(startup_timing_scope="GPU completion latency"),
        })
        self.assertEqual(campaign.validate_startup(fixture)["harness_to_measurement_begin_usec"], 20)

    def test_process_peak_is_observed_direct_process_metric_and_unavailable_is_explicit(self):
        with mock.patch.object(campaign, "observe_campaign_process", return_value={"available": False, "scope": "direct_process_only"}):
            samples = campaign.ProcessMemorySamples(os.getpid())
            samples.sample()
            result = samples.finish()
        self.assertFalse(result["available"])
        self.assertIsNone(result["observed_peak_rss_bytes"])
        with mock.patch.object(campaign, "observe_campaign_process", side_effect=[
                {"available": True, "scope": "direct_process_only", "peak_rss_bytes": 100},
                {"available": True, "scope": "direct_process_only", "peak_rss_bytes": 200}]):
            samples = campaign.ProcessMemorySamples(os.getpid())
            samples.sample()
            samples.sample()
            result = samples.finish()
        self.assertEqual(result["observed_peak_rss_bytes"], 200)
        self.assertFalse(result["final_lifetime_peak_guaranteed"])
        self.assertEqual(result["scope"], "direct_process_only")

    def test_windows_peak_counter_uses_owned_pid_and_closes_query_handle(self):
        kernel, psapi = mock.Mock(), mock.Mock()
        kernel.OpenProcess.return_value = 123

        def fill(handle, pointer, size):
            self.assertEqual(handle, 123)
            counters = pointer._obj
            self.assertEqual(size, counters.cb)
            self.assertEqual(size, 8+9*campaign.ctypes.sizeof(campaign.ctypes.c_size_t))
            counters.PeakWorkingSetSize, counters.WorkingSetSize = 300, 200
            counters.PrivateUsage, counters.PeakPagefileUsage = 400, 500
            return 1

        psapi.GetProcessMemoryInfo.side_effect = fill
        with mock.patch.object(campaign.ctypes, "WinDLL", side_effect=[kernel, psapi], create=True):
            result = campaign.observe_windows_process(987)
        kernel.OpenProcess.assert_called_once_with(0x1000, False, 987)
        kernel.CloseHandle.assert_called_once_with(123)
        self.assertTrue(result["available"])
        self.assertEqual(result["peak_rss_bytes"], 300)
        self.assertEqual(result["private_commit_bytes"], 400)
        self.assertEqual(result["peak_private_commit_bytes"], 500)

    def test_windows_query_failure_is_explicit_and_handles_are_released(self):
        for opened, read_ok in ((0, 0), (123, 0)):
            with self.subTest(opened=opened):
                kernel, psapi = mock.Mock(), mock.Mock()
                kernel.OpenProcess.return_value = opened
                psapi.GetProcessMemoryInfo.return_value = read_ok
                with mock.patch.object(campaign.ctypes, "WinDLL", side_effect=[kernel, psapi], create=True), \
                        mock.patch.object(campaign.ctypes, "get_last_error", return_value=5, create=True):
                    result = campaign.observe_windows_process(987)
                self.assertFalse(result["available"])
                self.assertEqual(result["win32_error"], 5)
                self.assertNotIn("peak_rss_bytes", result)
                if opened:
                    kernel.CloseHandle.assert_called_once_with(123)
                else:
                    kernel.CloseHandle.assert_not_called()


class InterruptionTests(unittest.TestCase):
    """Real OS children, explicit tiny adverse-control cleanup limits only."""

    def launch_wait_control(self, directory, interrupt, ignore_term=False):
        original_popen = subprocess.Popen
        children = []
        output = Path(directory) / "owned-process"
        witness = "ERROR: retained interruption-control witness"
        code = "import signal,time\n"
        if ignore_term:
            code += "signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
        code += f"print({witness!r},flush=True)\ntime.sleep(60)\n"

        class WaitControl:
            def __init__(self, child):
                self.child = child
                self.pid = child.pid
                self.first_wait = True

            def poll(self):
                return self.child.poll()

            def wait(self, timeout=None):
                if self.first_wait:
                    self.first_wait = False
                    if interrupt:
                        raise KeyboardInterrupt("explicit test interruption")
                    raise subprocess.TimeoutExpired("explicit test deadline", 0.01)
                return self.child.wait(timeout=timeout)

        def launch(_argv, **kwargs):
            child = original_popen([sys.executable, "-u", "-c", code], **kwargs)
            children.append(child)
            deadline = time.monotonic()+5
            log = Path(str(output)+".log")
            while time.monotonic() < deadline:
                if log.is_file() and witness in log.read_text():
                    return WaitControl(child)
                time.sleep(0.01)
            child.kill()
            child.wait(timeout=5)
            raise AssertionError("real child failed to write its startup witness")

        def watchdog(name):
            return 0.15 if name == "terminate_grace_seconds" else 5

        def reap_test_children():
            for child in children:
                if child.poll() is None:
                    child.kill()
                child.wait(timeout=5)
        self.addCleanup(reap_test_children)
        with mock.patch.object(campaign.subprocess, "Popen", side_effect=launch), \
                mock.patch.object(campaign, "watchdog_seconds", side_effect=watchdog):
            if interrupt:
                with self.assertRaises(campaign.CampaignInterrupted) as caught:
                    campaign.run_process(Path(sys.executable), output, "R",
                        {"workload": "play", "arm": "N", "consumer_usec": 0}, 120,
                        {"path": "unused-native", "sha256": "a"*64}, [])
                row = caught.exception.row
            else:
                row = campaign.run_process(Path(sys.executable), output, "R",
                    {"workload": "play", "arm": "N", "consumer_usec": 0}, 120,
                    {"path": "unused-native", "sha256": "a"*64}, [])
        self.assertEqual(len(children), 1)
        self.assertIsNotNone(children[0].poll(), "interrupted child was orphaned")
        self.assertTrue(row["process_started"])
        self.assertTrue(row["cleanup"]["required"])
        self.assertIn(witness, Path(row["log_path"]).read_text())
        self.assertIn("engine error in original log", row["reader_failure"])
        self.assertEqual(read_json(row["process_record"]), row)
        return row

    @unittest.skipIf(os.name == "nt", "POSIX process-group interruption is exercised on the actual Linux test host")
    def test_keyboard_interrupt_reaps_actual_child_and_preserves_failed_log(self):
        with tempfile.TemporaryDirectory() as directory:
            row = self.launch_wait_control(directory, interrupt=True)
            self.assertEqual(row["state"], "interrupted")
            self.assertEqual(row["exit"], "interrupted")
            self.assertIn("KeyboardInterrupt", row["interruption"])

    @unittest.skipIf(os.name == "nt", "SIGTERM-ignore adverse control is POSIX-specific")
    def test_timeout_escalates_for_actual_sigterm_ignoring_child(self):
        with tempfile.TemporaryDirectory() as directory:
            row = self.launch_wait_control(directory, interrupt=False, ignore_term=True)
            self.assertEqual(row["exit"], "timeout")
            self.assertTrue(row["cleanup"]["forced"])
            self.assertEqual(row["cleanup"]["returncode"], -9)

    def test_campaign_distinguishes_started_interruption_from_unstarted_cells(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "campaign"
            row = {"variant": "R", "workload": "paused", "arm": "N", "consumer_usec": 0,
                "process_started": True, "state": "interrupted", "exit": "interrupted",
                "interruption": "KeyboardInterrupt: explicit control", "cleanup": {"required": True, "returncode": -15}}
            error = campaign.CampaignInterrupted(row, KeyboardInterrupt("explicit control"))
            args = ["run_production_campaign.py", "--engine", "unused", "--engine-archive", "unused.zip",
                "--expected-source", "a"*40, "--variant", "R", "--output", str(output), "--repeats", "1"]
            with mock.patch.object(sys, "argv", args), \
                    mock.patch.object(campaign, "source_identity", return_value={"head": "a"*40}), \
                    mock.patch.object(campaign, "authenticate_engine", return_value={}), \
                    mock.patch.object(campaign, "authenticate_runtime", return_value={}), \
                    mock.patch.object(campaign, "run_process", side_effect=error) as run:
                with self.assertRaises(campaign.CampaignInterrupted):
                    campaign.main()
            report = read_json(output / "report.json")
            self.assertEqual(report["status"], "failed")
            self.assertIn("KeyboardInterrupt", report["fatal_error"])
            self.assertEqual(len(report["processes"]), 1)
            self.assertEqual(report["processes"][0]["state"], "interrupted")
            self.assertEqual([cell["sequence"] for cell in report["unstarted_processes"]], [2, 3, 4, 5])
            self.assertEqual(run.call_count, 1, "campaign started another cell after interruption")


def verify(path):
    original = read_json(path)
    summary = reduce_trace(original)
    controls = []

    def first(document, kind):
        return next(e for e in document["events"] if e["event"] == kind)

    def refuses(name, mutation):
        changed = copy.deepcopy(original)
        mutation(changed)
        try:
            reduce_trace(changed)
        except (ValueError, KeyError, TypeError, StopIteration):
            controls.append(name)
            return
        raise AssertionError("reader accepted corrupt actual evidence: " + name)

    refuses("headless", lambda d: d.update(display="headless"))
    refuses("unknown-schema", lambda d: d.update(schema="unknown"))
    refuses("old-schema-version", lambda d: d.update(schema_version=1))
    refuses("unknown-source-variant", lambda d: d.update(variant="unknown"))
    refuses("unknown-workload", lambda d: d.update(workload="unknown"))
    refuses("missing-native-identity", lambda d: d.update(runtime_sha256=""))
    refuses("wrong-owner", lambda d: d.update(owner_script="res://wrong.gd"))
    refuses("wrong-consumer", lambda d: d.update(consumer_script="res://wrong.gd"))
    refuses("failed-process", lambda d: d.update(failures=1))
    refuses("truncated-trace", lambda d: d.update(dropped=1))
    refuses("event-gap", lambda d: d["events"][0].update(event_sequence=2))
    refuses("nonfinite-clock", lambda d: d["events"][0].update(usec=float("nan")))
    refuses("false-counter", lambda d: d["counts"].update(refresh=0))
    refuses("frame-missing", lambda d: d["frame_usec"].pop())
    refuses("frame-pairing", lambda d: first(d, "frame_end").update(duration_usec=-1))
    refuses("under-applied-command-stream", lambda d: d.update(accepted_pulses=0))
    refuses("incorrect-material-stream", lambda d: first(d, "emission_queued").update(material=-1))
    refuses("late-marker-refused", lambda d: first(d, "tail_marker_queued").update(accepted=False))
    refuses("CPU-native-mismatch", lambda d: d.update(final_cpu_native_equal=False))
    refuses("CPU-texture-mismatch", lambda d: d.update(final_texture_image_equal=False))
    refuses("tail-marker-missing", lambda d: d.update(final_marker_equal=False))
    refuses("post-join-repair", lambda d: d.update(post_join_consumer_calls=1))
    refuses("tail-not-drained", lambda d: d.update(tail_drained=False))
    refuses("tail-in-flight-only", lambda d: first(d, "tail_caught_up").update(owner_count=0))
    refuses("tail-upload-lag", lambda d: first(d, "tail_caught_up").update(uploaded_revision=-1))
    refuses("tail-generation-lag", lambda d: first(d, "tail_caught_up").update(uploaded_generation=-1))
    refuses("owner-not-joined", lambda d: first(d, "owner_joined").update(thread_started=True))
    refuses("missing-full-start", lambda d: first(d, "native_end").update(complete_full=False))
    refuses("native-call-unpaired", lambda d: first(d, "native_begin").update(refresh=-1))
    refuses("third-native-call", lambda d: first(d, "native_end").update(call=3))
    refuses("native-timing-corrupt", lambda d: first(d, "native_end").update(duration_usec=-1))
    refuses("consumer-identity-changed", lambda d: first(d, "patch_end").update(serial=-1))
    refuses("consumer-timing-corrupt", lambda d: first(d, "texture_update_end").update(usec=-1))
    refuses("pending-high-water-forged", lambda d: d.update(pending_high_water=0))
    refuses("pending-rectangle-high-water-forged", lambda d: d.update(pending_rectangle_high_water=0))
    refuses("ACK-mode-mislabeled", lambda d: d.update(ack_mode="unknown"))
    refuses("ACK-delay-mislabeled", lambda d: d.update(ack_delay_usec=d["ack_delay_usec"]+1))
    refuses("ACK-queue-peak-forged", lambda d: d.update(ack_queue_high_water=d["ack_queue_high_water"]+1))
    refuses("ACK-queue-undrained", lambda d: d.update(ack_queue_remaining=1))
    refuses("ACK-queue-error-hidden", lambda d: d.update(ack_queue_errors=1))
    refuses("baseline-observer-error-hidden", lambda d: d.update(baseline_observer_errors=1))
    refuses("baseline-birth-forged", lambda d: first(d, "baseline_begin").update(birth_refresh=-1))
    refuses("baseline-allocation-lifetime-claim", lambda d: d.update(baseline_timing_scope="native allocation lifetime"))
    if summary["baseline_completed_lifetime_usec"]["n"]:
        refuses("baseline-age-forged", lambda d: first(d, "baseline_end").update(lifetime_usec=-1))
        refuses("baseline-reset-falsely-retires", lambda d: first(d, "baseline_end").update(reason="reset"))
    if summary["baseline_right_censored_age_usec"]["n"]:
        refuses("baseline-censored-age-forged", lambda d: first(d, "baseline_censored").update(age_usec=-1))
    refuses("native-workers-mislabeled", lambda d: d.update(native_workers_mode="unknown"))
    refuses("native-workers-capacity-forged", lambda d: first(d, "worker_config").update(actual_native_workers=-1))
    refuses("native-workers-participation-claim", lambda d: d.update(native_worker_count_scope="measured participation"))
    refuses("Godot-memory-false-RSS-claim", lambda d: d.update(memory_scope="complete process RSS"))
    refuses("Godot-memory-false-exit-peak", lambda d: d.update(memory_window="complete process lifetime"))
    refuses("Godot-memory-peak-forged", lambda d: d.update(godot_static_peak_bytes=d["godot_static_peak_bytes"]+1))
    refuses("Godot-memory-population-forged", lambda d: d.update(memory_sample_count=0))
    refuses("Godot-memory-invalid", lambda d: first(d, "memory_sample").update(godot_static_bytes=-1))
    refuses("logical-payload-owner-unpaired", lambda d: first(d, "owner_payload_bytes").update(refresh=-1))
    refuses("logical-payload-high-water-forged", lambda d: d.update(published_high_water=d["published_high_water"]+1))
    refuses("logical-payload-unique-allocation-claim", lambda d: d.update(payload_memory_scope="unique heap allocation bytes"))
    refuses("missing-startup-milestones", lambda d: d.update(startup_times_usec={}))
    refuses("startup-first-frame-forged", lambda d: d["startup_times_usec"].update(first_frame_submitted=0))
    refuses("startup-GPU-completion-claim", lambda d: d.update(startup_timing_scope="GPU completion latency"))
    refuses("freshness-unowned-snapshot", lambda d: first(d, "render_consume").update(snapshot_serial=-1))
    refuses("freshness-impossible-publication-clock", lambda d: first(d, "owner_end").update(published_usec=first(d, "owner_end")["end_usec"]+1))
    refuses("freshness-submission-from-wrong-snapshot", lambda d: first(d, "texture_success").update(snapshot_serial=-1))
    refuses("freshness-unmatched-consumer-completion", lambda d: first(d, "consumer_displayed").update(serial=-1))
    refuses("unmeasured-GPU-completion-claim", lambda d: d.update(gpu_completion_latency_measured=True))
    refuses("unmeasured-human-pacing-claim", lambda d: d.update(human_pacing_qualified=True))
    ack_kind = "ack_withheld" if original["arm"] == "W" else "ack_issue"
    refuses("ACK-before-upload", lambda d: first(d, ack_kind).update(usec=0))
    if original["arm"] == "D":
        refuses("delayed-ACK-before-due", lambda d: first(d, "ack_delay_release").update(
            released_usec=first(d, "ack_delay_release")["due_usec"]-1))
        refuses("delayed-ACK-queue-identity-changed", lambda d: first(d, "ack_delay_release").update(serial=-1))
        refuses("delayed-ACK-count-forged", lambda d: first(d, "ack_queued").update(queue_count=257))
        refuses("delayed-ACK-tail-no-owner-drain", lambda d: first(d, "tail_caught_up").update(ack_empty_owner_count=first(d, "tail_caught_up")["owner_count"]))
    if summary["counts"].get("ack_clear", 0):
        refuses("ACK-clear-without-cover", lambda d: first(d, "ack_clear").update(ack_serial=-1))
    if original["workload"] == "play":
        def erase_play_progress(d):
            start = d["lifecycle"][0]["native_tick"]
            d["lifecycle"][1]["native_tick"] = start
            rows = [e for e in d["events"] if e["event"] == "play_lifecycle"]
            rows[1]["native_tick"] = start
        refuses("active-PLAY-native-clock-stalled", erase_play_progress)
    if any(e.get("observer_accounting") == "constant-time-full-tag-v2" for e in original["events"]):
        def corrupt_charge(d):
            target = first(d, "production_append_begin")
            for e in d["events"]:
                if (e["event"] in ("production_append_begin", "production_append_end")
                        and e["refresh"] == target["refresh"]
                        and e["before"]["pending_serial"] == target["before"]["pending_serial"]):
                    e["predicted_e_charged_bytes"] += 1
        refuses("independent-observer-charge-forged", corrupt_charge)
    return {"status": "passed", "path": str(path), "positive": "unaltered actual graphical receipt",
            "variant": original["variant"], "workload": original["workload"], "arm": original["arm"],
            "negative_controls": controls}


if __name__ == "__main__":
    if len(sys.argv) > 1 and all(not arg.startswith("-") for arg in sys.argv[1:]):
        print(json.dumps([verify(Path(arg)) for arg in sys.argv[1:]], indent=2))
    else:
        unittest.main()
