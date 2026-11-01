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

    def test_duplicate_source_identity_fields_are_refused(self):
        with self.assertRaises(ValueError):
            json.loads('{"source_sha":"one","source_sha":"two"}', object_pairs_hook=unique_object)

    def test_invalid_measurement_population_is_not_a_percentile(self):
        for value in (float("nan"), float("inf"), -1):
            with self.assertRaises(ValueError):
                percentiles([0, value])


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
            self.assertEqual([cell["sequence"] for cell in report["unstarted_processes"]], [2, 3, 4])
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
    refuses("unmeasured-GPU-completion-claim", lambda d: d.update(gpu_completion_latency_measured=True))
    refuses("unmeasured-human-pacing-claim", lambda d: d.update(human_pacing_qualified=True))
    ack_kind = "ack_issue" if original["arm"] == "N" else "ack_withheld"
    refuses("ACK-before-upload", lambda d: first(d, ack_kind).update(usec=0))
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
