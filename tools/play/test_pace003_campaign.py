#!/usr/bin/env python3
"""Adversarial readback tests; these synthetic rows are NOT engine evidence."""
import copy
import contextlib
import io
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import zlib

import run_pace003_campaign as campaign


def example(graphical=True):
    expected = {"rig": "jetbarrel", "requested_workers": 1, "policy_preset": 0,
                "sample_seconds": 15, "source_sha": "a" * 40, "platform": "Linux", "headless": not graphical,
                "rendering_driver": "engine-default"}
    value = {"schema": "play-pace003-shared-host-v1", **{key: expected[key] for key in
             ("rig", "requested_workers", "policy_preset", "sample_seconds")},
             "source_revision": expected["source_sha"], "failures": 0, "assertions": 17 if graphical else 15,
             "requested_rendering_driver": "engine-default",
             "workers_joined": 1, "rapier_sessions_retired": 1, "retries": 0, "native_rows_overflow": False,
             "started_usec": 1_000_000, "ended_usec": 16_000_000, "elapsed_usec": 15_000_000,
             "viewport": [960, 540], "canvas": [960, 540], "platform": "Linux", "cpu_name": "synthetic",
             "logical_processors": 4, "godot": {"hash": "5b4e0cb0f"}, "display_server": "x11" if graphical else "headless",
             "scope": {"frame_submissions_measured": graphical, "physical_scanout_measured": False,
                       "human_feel": False, "native_jobs_held": False}, "course_recipe_hash": "b" * 64,
             "policy": {"policy_hash": "c" * 64}, "receipt": {"kind": "applied_run", "policy_hash": "c" * 64},
             "construction_usec": 100, "reset_usec": 100, "scene_retirement_usec": 100, "stop_join_usec": 100,
             "generation": 2, "actor_epoch": 1, "native_hz_observed_by_main": 2 / 15, "rapier_hz": 2 / 15,
             "native_ticks_observed_by_main": 2, "native_completion_count": 2, "native_vs_main_boundary_difference": 0,
             "initial_main_native_tick": 19, "final_main_native_tick": 21,
             "initial_rapier_tick": 19, "final_rapier_tick": 21, "rapier_ticks": 2,
             "framebuffer": {"captured": True, "width": 960, "height": 540, "captured_after_sample": True,
                             "different_from_top_left_rgb": 50, "png_sha256": "a" * 64}
                            if graphical else {"captured": False, "reason": "headless"},
             "raw": {"main_started_usec": [1_010_000, 1_080_000], "main_callback_usec": [100, 200],
                     "physics_callback_usec": [100, 200], "snapshot_mutex_wait_usec": [0, 5],
                     "snapshot_mutex_critical_usec": [1, 2],
                     "rendered_usec": [1_020_000, 1_090_000] if graphical else [],
                     "snapshot_rows": [], "native_rows": []}}
    for index in range(2):
        value["raw"]["snapshot_rows"].append({"generation": 2, "epoch": 1, "failed": False,
            "serial": 10 + index * 3, "tick": 20 + index, "render_tick": 20 + index,
            "observed_usec": 1_015_000 + index * 70_000, "published_usec": 1_010_000 + index * 70_000,
            "render_generated_usec": 1_009_000 + index * 70_000})
        value["raw"]["native_rows"].append({"statistics_ok": True, "generation": 2, "actor_epoch": 1,
            "tick": 20 + index, "native_completed_tick": 20 + index, "completed_usec": 1_005_000 + index * 70_000,
            "native_ms": 2 + index, "worker_step_ms": 3 + index, "probe_usec": 20,
            "workers_observed": 1, "parallel_phases": 0, "jobs": 2, "overruns": index, "capacity": 1})
    return value, expected


def png_bytes():
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
    data = b"".join(b"\0" + bytes([y % 256, 40, 80]) * 960 for y in range(540))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 960, 540, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(data)) + chunk(b"IEND", b""))


def process_record(name, timeout):
    return {"name": name, "log": name + ".log", "status": "passed", "returncode": 0,
            "timeout_kind": None, "diagnostic_error": False, "skip_messages": [],
            "launch_error": None, "capture_error": None, "timeout_diagnostic_error": None,
            "timeout_seconds": timeout}


def retained_graphical_campaign(directory):
    report = {"schema": campaign.SCHEMA, "status": "passed", "errors": [], "retries": 0,
              "source_sha": "a" * 40, "platform": "Linux", "config": {"headless": False,
              "repetitions": 1, "rig": "jetbarrel", "sample_seconds": 15, "policy_preset": 0,
              "rendering_driver": "engine-default"}, "rows": [], "log_sha256": {}}
    report["import"] = process_record("import", 240)
    (directory / "import.log").write_text("Synthetic importer parser fixture\n")
    report["log_sha256"]["import.log"] = campaign.runner.sha256(directory / "import.log")
    for order, count in enumerate([1, 0]):
        value, _ = example()
        value["requested_workers"] = count
        name = f"r0-o{order}-w{count}"
        image = directory / (name + ".png")
        image.write_bytes(png_bytes())
        value["framebuffer"]["path"] = image.name
        value["framebuffer"]["png_sha256"] = campaign.runner.sha256(image)
        log = directory / (name + ".log")
        log.write_text(campaign.MARKER + json.dumps(value) + "\n")
        report["log_sha256"][log.name] = campaign.runner.sha256(log)
        report["rows"].append({"repeat": 0, "order": order, "requested_workers": count,
            "process": process_record(name, 180), "result": value, "summary": campaign.reduce_row(value)})
    campaign.runner.write_json(directory / "campaign.json", report)
    return report


class ReadbackTests(unittest.TestCase):
    def test_valid_graphical_and_headless_remain_distinct(self):
        for graphical in (True, False):
            value, expected = example(graphical)
            campaign.verify_row(value, expected)
            reduced = campaign.reduce_row(value)
            self.assertEqual(reduced["render_submission_interval_usec"]["count"], int(graphical))
            if not graphical:
                self.assertIsNone(reduced["render_submission_interval_usec"]["p95"])

    def test_exact_reduction_and_long_interval(self):
        value, expected = example()
        campaign.verify_row(value, expected)
        reduced = campaign.reduce_row(value)
        self.assertEqual(reduced["native_tick_ms"], {"count": 2, "mean": 2.5, "p50": 2, "p95": 3, "p99": 3, "max": 3})
        self.assertEqual(reduced["snapshot_serials_coalesced_between_Main_reads"], 2)
        self.assertEqual(reduced["render_submission_long_intervals"]["50000"]["count"], 1)
        self.assertEqual(reduced["render_submission_long_intervals"]["100000"]["count"], 0)

    def test_missing_duplicate_and_out_of_order_native_ticks_refuse(self):
        for tick in (20, 19, 22):
            value, expected = example()
            value["raw"]["native_rows"][1]["tick"] = tick
            with self.assertRaises(RuntimeError): campaign.verify_row(value, expected)

    def test_wrong_epoch_generation_and_window_refuse(self):
        for key, replacement in (("generation", 1), ("actor_epoch", 2), ("completed_usec", 16_000_000),
                                 ("native_completed_tick", 19)):
            value, expected = example()
            value["raw"]["native_rows"][1][key] = replacement
            with self.assertRaises(RuntimeError): campaign.verify_row(value, expected)

    def test_missing_frame_submission_does_not_pass_as_graphics(self):
        value, expected = example()
        value["raw"]["rendered_usec"] = []
        with self.assertRaises(RuntimeError): campaign.verify_row(value, expected)

    def test_headless_cannot_claim_rendered_result(self):
        value, expected = example(False)
        value["raw"]["rendered_usec"] = [1, 2]
        with self.assertRaises(RuntimeError): campaign.verify_row(value, expected)

    def test_native_participants_cannot_exceed_capacity(self):
        value, expected = example()
        value["raw"]["native_rows"][0]["workers_observed"] = 2
        with self.assertRaises(RuntimeError): campaign.verify_row(value, expected)

    def test_failed_snapshot_and_regressed_serial_refuse(self):
        for key, replacement in (("failed", True), ("serial", 5), ("tick", 19)):
            value, expected = example()
            value["raw"]["snapshot_rows"][1][key] = replacement
            with self.assertRaises(RuntimeError): campaign.verify_row(value, expected)

    def test_identity_lifecycle_overflow_and_retry_refuse(self):
        for key, replacement in (("failures", 1), ("workers_joined", 0), ("retries", 1),
                                 ("native_rows_overflow", True), ("source_revision", "d" * 40),
                                 ("reset_usec", -1)):
            value, expected = example()
            value[key] = replacement
            with self.assertRaises(RuntimeError): campaign.verify_row(value, expected)

    def test_reported_rate_cannot_disagree_with_completed_clock(self):
        for key, replacement in (("native_hz_observed_by_main", 60), ("rapier_hz", 60),
                                 ("native_completion_count", 3), ("final_main_native_tick", 22)):
            value, expected = example()
            value[key] = replacement
            with self.assertRaises(RuntimeError): campaign.verify_row(value, expected)

    def test_nonfinite_duplicate_json_and_negative_timing_refuse(self):
        for text in ('{"a":1,"a":2}', '{"a":NaN}'):
            with self.assertRaises((RuntimeError, ValueError)): campaign.load_json(text)
        for values in ([float("inf")], [-1], [True]):
            with self.assertRaises(RuntimeError): campaign.stats(values)

    def test_timestamp_intervals_require_strict_order(self):
        for values in ([2, 2], [2, 1], [False, 1]):
            with self.assertRaises(RuntimeError): campaign.intervals(values)

    def test_summary_does_not_mutate_raw_evidence(self):
        value, _ = example()
        before = copy.deepcopy(value)
        campaign.reduce_row(value)
        self.assertEqual(value, before)

    def test_complete_graphical_log_and_png_readback(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            expected = retained_graphical_campaign(directory)
            self.assertEqual(campaign.verify_directory(directory), expected)
            image = directory / expected["rows"][0]["result"]["framebuffer"]["path"]
            image.write_bytes(image.read_bytes()[:-1] + b"x")
            with self.assertRaisesRegex(RuntimeError, "PNG hash"):
                campaign.verify_directory(directory)

    def test_runtime_provenance_binds_selected_bytes_and_committed_lfs(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            native = root / "native/bin/native.so"
            rapier = root / "rapier/bin/rapier.so"
            source = root / "native/source.cpp"
            native.parent.mkdir(parents=True)
            rapier.parent.mkdir(parents=True)
            source.write_bytes(b"synthetic provenance input\n")
            native.write_bytes(b"synthetic native runtime" * 100)
            rapier.write_bytes(b"synthetic Rapier runtime" * 100)
            target = "windows" if campaign.sys.platform == "win32" else "linux"
            manifests = [native.parent.parent / ("runtime-provenance.json" if target == "windows"
                         else "runtime-provenance.linux.json"),
                         rapier.parent.parent / ("runtime-provenance." + target + ".json")]
            committed = {}
            values = []
            for path, manifest_path in zip((native, rapier), manifests):
                relative = path.relative_to(root).as_posix()
                value = {"schema_version": 1, "artifact": relative, "sha256": campaign.runner.sha256(path),
                         "size": path.stat().st_size, "source_commit": "a" * 40,
                         "source_inputs": {"native/source.cpp": campaign.runner.sha256(source)}}
                values.append(value)
                data = (json.dumps(value) + "\n").encode()
                manifest_path.write_bytes(data)
                committed[manifest_path.relative_to(root).as_posix()] = data
                committed[relative] = ("version https://git-lfs.github.com/spec/v1\n"
                    f"oid sha256:{value['sha256']}\nsize {value['size']}\n").encode()
            original = committed.copy()
            native_relative = native.relative_to(root).as_posix()
            manifest_relative = manifests[0].relative_to(root).as_posix()
            with patch.object(campaign, "ROOT", root), \
                 patch.object(campaign.runner, "runtime_paths", return_value=(native, rapier)), \
                 patch.object(campaign.windows, "native_input_paths", return_value={"native/source.cpp"}), \
                 patch.object(campaign.windows, "git", side_effect=lambda _root, _show, name: committed[name[5:]]):
                identity = campaign.runtime_identity()
                self.assertEqual(identity["native"]["sha256"], values[0]["sha256"])
                # Checkout line-ending conversion is legitimate; manifest content is fixed.
                manifests[0].write_bytes(original[manifest_relative].replace(b"\n", b"\r\n"))
                campaign.runtime_identity()
                for mutation, expected in (("artifact", "actual selected runtime"), ("hash", "hash/size"),
                                           ("size", "hash/size"), ("pointer", "committed LFS identity"),
                                           ("noncanonical", "canonical committed LFS"),
                                           ("local_manifest", "committed content")):
                    with self.subTest(mutation=mutation):
                        committed.clear()
                        committed.update(original)
                        manifests[0].write_bytes(original[manifest_relative])
                        changed = copy.deepcopy(values[0])
                        if mutation in ("artifact", "hash", "size", "local_manifest"):
                            key, replacement = {"artifact": ("artifact", "rapier/bin/rapier.so"),
                                "hash": ("sha256", "0" * 64), "size": ("size", values[0]["size"] + 1),
                                "local_manifest": ("source_commit", "b" * 40)}[mutation]
                            changed[key] = replacement
                            manifests[0].write_bytes((json.dumps(changed) + "\n").encode())
                            if mutation != "local_manifest":
                                committed[manifest_relative] = manifests[0].read_bytes()
                        elif mutation == "pointer":
                            committed[native_relative] = original[native_relative].replace(values[0]["sha256"].encode(), b"0" * 64)
                        else:
                            committed[native_relative] = b"noncanonical\n" + original[native_relative]
                        with self.assertRaisesRegex(RuntimeError, expected):
                            campaign.runtime_identity()

    def test_unexpected_final_verifier_error_is_retained_as_failure(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            godot = directory / "godot-synthetic"
            godot.write_text("synthetic parser test only")
            output = directory / "output"
            calls = 0

            def fake_process(_godot, case, target, _role, **_kwargs):
                nonlocal calls
                process = process_record(case.name, case.timeout)
                text = "Synthetic importer\n"
                if case.name != "import":
                    value, _ = example(False)
                    value["requested_workers"] = 1 if calls == 1 else 0
                    text = campaign.MARKER + json.dumps(value) + "\n"
                (target / process["log"]).write_text(text)
                calls += 1
                return process, False

            with patch("sys.argv", ["run_pace003_campaign.py", "--godot", str(godot), "--output", str(output),
                                    "--headless", "--repetitions", "1"]), \
                 patch.object(campaign, "source_identity", return_value={"source_sha": "a" * 40}), \
                 patch.object(campaign, "runtime_identity", return_value={}), \
                 patch.object(campaign.subprocess, "check_output", return_value=campaign.GODOT_VERSION), \
                 patch.object(campaign.runner, "run_case", side_effect=fake_process), \
                 patch.object(campaign, "verify_directory", side_effect=NameError("synthetic verifier failure")), \
                 contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(campaign.main(), 1)
            report = json.loads((output / "campaign.json").read_text())
            self.assertEqual(report["status"], "failed")
            self.assertIn("NameError: synthetic verifier failure", report["errors"])


if __name__ == "__main__":
    unittest.main()
