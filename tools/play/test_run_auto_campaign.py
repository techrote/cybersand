"""Adversarial evidence checks; these model tests do not execute native workers."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import run_auto_campaign as campaign


def process(name="row", timeout=None):
    if timeout is None:
        timeout = campaign.case_seconds("run_play_auto_campaign")
    return {"name": name, "status": "passed", "returncode": 0,
            "execution_policy": campaign.policy_identity(), "natural_completion": True,
            "diagnostic_error": False, "launch_error": None, "capture_error": None,
            "skip_messages": [], "timeout_kind": None, "timeout_diagnostic_error": None,
            "seconds": 1.0, "timeout_seconds": timeout, "command": ["godot", "--headless"],
            "log": name + ".log"}


def report(logical_processors=4):
    config = {"requested_counts": campaign.COUNTS, "sizes": campaign.SIZES,
              "repetitions": 5, "warmup_ticks": 60, "ticks": 120,
              "process_timeout_seconds": campaign.case_seconds("run_play_auto_campaign"), "order": "cyclic-per-repeat"}
    rows = []
    for identity in campaign.plan(config):
        requested = identity["requested_workers"]
        automatic = campaign.native_auto_workers(logical_processors)
        capacity = automatic if requested == 0 else min(requested, logical_processors)
        # Intentionally slower multiworker rows must remain valid counterexamples.
        native_times = [2.0 if capacity == 1 else 3.0] * config["ticks"]
        frame_times = [16.0] * config["ticks"]
        observed = min(capacity, 2)
        phases = 4 if capacity > 1 else 0
        value = {"ok": True, "side": identity["side"], "requested_workers": requested,
                 "ticks": config["ticks"], "warmup_ticks": config["warmup_ticks"],
                 "configured_worker_capacity": capacity, "actual_workers": capacity,
                 "resolved_workers": capacity, "workers": capacity,
                 "readback_consistent": True, "logical_threads": logical_processors, "auto_workers": automatic,
                 "threaded_runtime": True, "worker_capacity_readback_kind": "adapter-configured-count",
                 "workers_created_count_measured": False, "concurrent_execution_measured": False,
                 "resolution_source": "native-auto-policy" if requested == 0 else "explicit-request-clamped-to-host",
                 "global_setting_unchanged": True, "global_setting_before": 0, "global_setting_after": 0,
                 "level_hash": ("a" if identity["side"] == 480 else "b") * 64,
                 "moves": 100, "maximum_scheduler_jobs": 8, "maximum_eligible_blocks": 8,
                 "measured_wall_ms": 1920.0, "completed_hz": 62.5, "terminal_export_hash_ms": 1.0,
                 "native_ms": campaign.stats(native_times), "frame_interval_ms": campaign.stats(frame_times),
                 "maximum_workers_observed": observed,
                 "worker_participation_ticks": config["ticks"] if observed > 1 else 0,
                 "parallel_participation": observed > 1,
                 "parallel_dispatch_observed": phases > 0,
                 "parallel_phase_ticks": config["ticks"] if phases else 0,
                 "parallel_phases": phases * config["ticks"],
                 "tick_samples": {"native_ms": native_times, "test_frame_interval_ms": frame_times,
                                  "workers_observed": [observed] * config["ticks"],
                                  "parallel_phases": [phases] * config["ticks"]}}
        rows.append({**identity, "schema": "play-auto-campaign-row-v1", "cpu_name": "Synthetic model CPU",
                     "logical_processors": logical_processors, "os": "Linux", "os_version": "model-only",
                     "godot": {"major": 4, "minor": 7, "patch": 0, "status": "stable",
                               "build": "official", "hash": "5b4e0cb0f"},
                     "result": value, "process": process(identity["id"]),
                     "rendered_gameplay_fps_measured": False, "concurrent_execution_measured": False,
                     "worker_creation_count_measured": False})
    return {"schema": campaign.SCHEMA, "status": "passed", "execution_policy": campaign.policy_identity(), "errors": [], "source_drift": [],
            "platform": "linux", "source_sha": "c" * 40, "source_tree": "d" * 40,
            "native_inputs": {"native/src/world.cpp": "e" * 64},
            "runtime_source_mode": "fresh-publisher-build-assertion",
            "built_runtime_source_assertion": "c" * 40,
            "tested_inputs": {p: "f" * 64 for p in campaign.TESTED},
            "native_runtime": {"path": "native.so", "sha256": "a" * 64, "size": 1024},
            "rapier_runtime": {"path": "rapier.so", "sha256": "b" * 64, "size": 1024},
            "config": config, "godot_version": campaign.GODOT_VERSION,
            "rows": rows, "summaries": campaign.reduction(rows), "log_sha256": {},
            "preflight_results": [process("import", campaign.watchdog_seconds("godot_import_seconds"))],
            "concurrent_execution_measured": False, "rendered_gameplay_fps_measured": False,
            "positive_speedup_required": False, "retries": 0}


class CampaignEvidenceTests(unittest.TestCase):
    def setUp(self):
        patch = mock.patch.object(campaign, "verify_source_policy", return_value=campaign.policy_identity())
        patch.start()
        self.addCleanup(patch.stop)

    def test_slow_process_is_retained_but_late_exit_or_failure_is_rejected(self):
        data = report()
        data["rows"][0]["process"]["seconds"] = 181
        campaign.verify_report(data)
        for field, value in (("seconds", campaign.case_seconds("run_play_auto_campaign") + .1),
                             ("seconds", float("nan")), ("returncode", 1),
                             ("natural_completion", False), ("execution_policy", {}), ("timed_out", True)):
            changed = copy.deepcopy(data)
            changed["rows"][0]["process"][field] = value
            with self.subTest(field=field), self.assertRaises(RuntimeError):
                campaign.verify_report(changed)

    def test_old_campaign_schema_requires_its_historical_reader(self):
        data = report()
        data["schema"] = "play-auto-campaign-v1"
        with self.assertRaises(RuntimeError):
            campaign.verify_report(data)

    def test_balanced_order_and_complete_identity(self):
        data = report()
        campaign.verify_report(data, "c" * 40)
        for side in campaign.SIZES:
            for count in campaign.COUNTS:
                self.assertEqual({r["order"] for r in data["rows"]
                                  if r["side"] == side and r["requested_workers"] == count}, set(range(5)))

    def test_slower_multiworker_counterexamples_are_retained(self):
        data = report()
        campaign.verify_report(data)
        multi = next(s for s in data["summaries"] if s["requested_workers"] == 2)
        self.assertEqual(multi["slower_than_serial_repeats"], list(range(5)))
        self.assertLess(multi["paired_native_mean_ratio_to_serial"]["mean"], 1.0)

    def test_nearest_rank_timing_percentiles(self):
        value = campaign.stats([1., 2., 3., 4.])
        self.assertEqual(value, {"count": 4, "mean": 2.5, "p50": 2., "p95": 4., "p99": 4., "max": 4.})

    def test_production_auto_thresholds_include_unclamped_low_core_policy(self):
        for logical, expected in ((1, 2), (2, 2), (3, 2), (4, 4), (11, 4), (12, 6), (64, 6)):
            with self.subTest(logical=logical):
                self.assertEqual(campaign.native_auto_workers(logical), expected)
                campaign.verify_report(report(logical))

    def test_invented_auto_capacity_refuses_even_when_aliases_are_consistent(self):
        data = report()
        for row in data["rows"]:
            value = row["result"]
            value["auto_workers"] = 3
            if row["requested_workers"] == 0:
                for key in ("configured_worker_capacity", "actual_workers", "resolved_workers", "workers"):
                    value[key] = 3
        data["summaries"] = campaign.reduction(data["rows"])
        with self.assertRaisesRegex(RuntimeError, "production native policy"):
            campaign.verify_report(data)

    def test_completed_throughput_is_derived_from_measured_ticks_and_wall(self):
        self.reject(lambda d: d["rows"][0]["result"].__setitem__("completed_hz", 1e99), "throughput differs")
        self.reject(lambda d: d["rows"][0]["result"].__setitem__("measured_wall_ms", 1e99), "throughput differs")

    def test_participants_cannot_exist_without_same_tick_parallel_dispatch(self):
        data = report()
        for row in data["rows"]:
            value = row["result"]
            value["tick_samples"]["parallel_phases"] = [0] * 120
            value["parallel_phases"] = 0
            value["parallel_phase_ticks"] = 0
            value["parallel_dispatch_observed"] = False
        data["summaries"] = campaign.reduction(data["rows"])
        with self.assertRaisesRegex(RuntimeError, "same tick"):
            campaign.verify_report(data)

    def test_serial_capacity_and_parallel_summary_are_mutually_consistent(self):
        def serial_parallel(data):
            value = data["rows"][0]["result"]
            value["tick_samples"]["parallel_phases"] = [1] * 120
            value["parallel_phases"] = 120
            value["parallel_phase_ticks"] = 120
            value["parallel_dispatch_observed"] = True
        self.reject(serial_parallel, "Serial capacity")
        self.reject(lambda d: d["rows"][2]["result"].__setitem__("maximum_scheduler_jobs", 1),
                    "dispatch counters")
        self.reject(lambda d: d["rows"][2]["result"].__setitem__("parallel_dispatch_observed", False),
                    "dispatch counters")

    def reject(self, mutate, message=None):
        data = report()
        mutate(data)
        with self.assertRaises(RuntimeError) as caught:
            campaign.verify_report(data, "c" * 40)
        if message:
            self.assertIn(message, str(caught.exception))

    def test_missing_duplicate_or_reordered_rows_refuse(self):
        self.reject(lambda d: d["rows"].pop())
        self.reject(lambda d: d["rows"].__setitem__(1, copy.deepcopy(d["rows"][0])))
        self.reject(lambda d: d["rows"].reverse())

    def test_short_warmup_unbalanced_repeats_or_escalated_timeout_refuse(self):
        self.reject(lambda d: d["config"].__setitem__("warmup_ticks", 10))
        self.reject(lambda d: d["config"].__setitem__("repetitions", 6))
        self.reject(lambda d: d["config"].__setitem__("process_timeout_seconds", 241))

    def test_actual_capacity_does_not_prove_participation(self):
        data = report()
        for row in data["rows"]:
            value = row["result"]
            value["maximum_workers_observed"] = 1
            value["worker_participation_ticks"] = 0
            value["parallel_participation"] = False
            value["tick_samples"]["workers_observed"] = [1] * 120
        data["summaries"] = campaign.reduction(data["rows"])
        with self.assertRaisesRegex(RuntimeError, "no actual multiworker"):
            campaign.verify_report(data)

    def test_parity_or_source_or_host_drift_refuses(self):
        self.reject(lambda d: d["rows"][1]["result"].__setitem__("level_hash", "9" * 64))
        self.reject(lambda d: d.__setitem__("source_sha", "9" * 40))
        self.reject(lambda d: d["source_drift"].append("changed input"))
        self.reject(lambda d: d["rows"][1].__setitem__("cpu_name", "Other CPU"))
        self.reject(lambda d: d.__setitem__("platform", "windows"))

    def test_invented_concurrency_or_created_count_refuses(self):
        self.reject(lambda d: d["rows"][0].__setitem__("worker_creation_count_measured", True))
        self.reject(lambda d: d["rows"][0]["result"].__setitem__("concurrent_execution_measured", True))
        self.reject(lambda d: d.__setitem__("rendered_gameplay_fps_measured", True))

    def test_incomplete_raw_ticks_or_false_timing_reducer_refuses(self):
        self.reject(lambda d: d["rows"][0]["result"]["tick_samples"]["native_ms"].pop())
        self.reject(lambda d: d["rows"][0]["result"]["native_ms"].__setitem__("p99", 999))
        self.reject(lambda d: d["rows"][0]["result"]["tick_samples"]["workers_observed"].__setitem__(0, 99))
        self.reject(lambda d: d["rows"][0]["result"]["tick_samples"]["native_ms"].__setitem__(0, float("nan")))

    def test_failed_process_or_zero_work_refuses(self):
        self.reject(lambda d: d["rows"][0]["process"].__setitem__("status", "timeout"))
        self.reject(lambda d: d["rows"][0]["process"].__setitem__("returncode", True))
        self.reject(lambda d: d["rows"][0]["process"]["skip_messages"].append("SKIP"))
        self.reject(lambda d: d["rows"][0]["result"].__setitem__("moves", 0))

    def test_duplicate_json_fields_and_nonfinite_json_refuse(self):
        for text in ('{"x":1,"x":2}', '{"x":NaN}', '{"x":Infinity}'):
            with self.assertRaises((RuntimeError, ValueError)):
                campaign.load_json(text)

    def directory(self, root):
        data = report()
        (root / "import.log").write_text("Godot import complete\n", encoding="utf-8")
        data["log_sha256"]["import.log"] = campaign.runner.sha256(root / "import.log")
        for row in data["rows"]:
            raw = {k: v for k, v in row.items() if k not in ("id", "process")}
            name = row["process"]["log"]
            (root / name).write_text(campaign.MARKER + json.dumps(raw) + "\n", encoding="utf-8")
            data["log_sha256"][name] = campaign.runner.sha256(root / name)
        (root / "campaign.json").write_text(json.dumps(data), encoding="utf-8")
        return data

    def test_retained_directory_verifies_without_current_runtime(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.directory(root)
            self.assertEqual(campaign.verify_directory(root, "c" * 40)["status"], "passed")

    def test_log_tamper_and_duplicate_raw_marker_refuse(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data = self.directory(root)
            log = root / data["rows"][0]["process"]["log"]
            log.write_text(log.read_text() + "ERROR: hidden failure\n", encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "log hash"):
                campaign.verify_directory(root)
            data["log_sha256"][log.name] = campaign.runner.sha256(log)
            (root / "campaign.json").write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "diagnostic failure"):
                campaign.verify_directory(root)

    def test_duplicate_raw_markers_refuse_even_with_updated_digest(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data = self.directory(root)
            log = root / data["rows"][0]["process"]["log"]
            log.write_text(log.read_text(encoding="utf-8") * 2, encoding="utf-8")
            data["log_sha256"][log.name] = campaign.runner.sha256(log)
            (root / "campaign.json").write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "duplicate raw row marker"):
                campaign.verify_directory(root)

    def test_summary_cannot_drop_slow_repeats(self):
        self.reject(lambda d: d["summaries"][1].__setitem__("slower_than_serial_repeats", []))


if __name__ == "__main__":
    unittest.main()
