"""Research evidence must retain tails, source distinctions and failed receipts."""
import copy
import math
from pathlib import Path
import unittest

import run_campaign as campaign


class ReductionTests(unittest.TestCase):
    def test_import_uids_do_not_hide_new_or_committed_resource_changes(self):
        tracked = ["godot/scripts/old.gd", "godot/shaders/old.gdshader", "godot/scripts/kept.gd.uid"]
        untracked = ["godot/scripts/old.gd.uid", "godot/shaders/old.gdshader.uid",
                     "godot/scripts/new.gd", "godot/scripts/new.gd.uid", "tools/stray.gd.uid"]
        paths, actual_untracked = campaign.source_inventory(tracked, untracked)
        self.assertEqual(actual_untracked, ["godot/scripts/new.gd", "godot/scripts/new.gd.uid", "tools/stray.gd.uid"])
        self.assertIn("godot/scripts/kept.gd.uid", paths)
        self.assertNotIn("godot/scripts/old.gd.uid", paths)

    def test_sparse_stalls_are_not_hidden_by_all_frame_p95(self):
        values = [1.0] * 96 + [100.0] * 4
        result = campaign.summary(values)
        self.assertEqual(result["p95"], 1.0)
        self.assertEqual(result["p99"], 100.0)
        self.assertEqual(campaign.summary([100.0] * 4)["p95"], 100.0)

    def test_original_16_event_nearest_rank_tail_is_maximum(self):
        self.assertEqual(campaign.summary([float(n) for n in range(16)])["p95"], 15.0)

    def test_invalid_numeric_evidence_is_refused(self):
        for value in (math.inf, -math.inf, math.nan):
            with self.assertRaises(ValueError):
                campaign.summary([1.0, value])

    def test_reducer_keeps_repeat_variance_and_byte_totals(self):
        runs = []
        for strategy, values in (("full", [1.0, 9.0]), ("drawable", [2.0, 3.0]),
                                 ("drawable", [3.0, 4.0]), ("full", [6.0, 18.0])):
            runs.append({"case": {"id": "sparse_2048_w1"}, "strategy": strategy,
                         "data": {"frames": [{"frame_ms": value} for value in values],
                                  "uploads": [{"logical_bytes": 8, "dirty_bytes": 2, "submit_ms": 0.3}]},
                         "process": {"peak_rss_bytes": 1024}})
        result = campaign.reduce_runs(runs)[0]
        full = result["strategies"]["full"]
        self.assertEqual(full["arms"], 2)
        self.assertEqual([x["p95"] for x in full["repeat_frame_ms"]], [9.0, 18.0])
        self.assertEqual(full["totals"]["logical_bytes"], 16.0)
        self.assertEqual(full["frame_metrics"]["frame_ms"]["count"], 4)
        self.assertEqual(result["drawable_minus_full_frame_ms"]["p95"]["ms"], -14.0)
        for run in runs:
            run["process"]["peak_rss_bytes"] = None
        self.assertIsNone(campaign.reduce_runs(runs)[0]["strategies"]["full"]["peak_process_rss_bytes"])

    def test_coverage_excludes_transitions_and_keeps_fractions_separate(self):
        runs = []
        for strategy in campaign.ORDER:
            frames, uploads = [], []
            for fraction in (0.01, 0.05, 0.1, 0.25, 0.5, 1.0):
                for phase_frame in range(16):
                    frames.append({"frame_ms": 1000.0 if phase_frame < 8 else (10.0 if strategy == "full" else 5.0),
                                   "coverage_fraction": fraction, "coverage_phase_frame": phase_frame,
                                   "upload_count": 1})
                    uploads.append({"accepted": True, "submit_ms": 1.0, "dirty_bytes": 2, "logical_bytes": 4,
                                    "metrics": {"mode": "full_update" if strategy == "full" else "partial"}})
            runs.append({"case": {"id": "coverage_2048_w1", "workload": "coverage", "workers": 1},
                         "strategy": strategy, "data": {"frames": frames, "uploads": uploads},
                         "process": {"peak_rss_bytes": None}})
        result = campaign.reduce_runs(runs)[0]
        self.assertEqual(result["strategies"]["full"]["frame_metrics"]["frame_ms"]["p95"], 1000.0)
        self.assertEqual(len(result["coverage_strata"]), 6)
        for stratum in result["coverage_strata"]:
            full = stratum["strategies"]["full"]
            self.assertEqual(full["frame_metrics"]["frame_ms"]["count"], 16)
            self.assertEqual(full["frame_metrics"]["frame_ms"]["p95"], 10.0)
            self.assertEqual(full["excluded_transition_frames"], 16)
            self.assertEqual(full["totals"]["logical_bytes"], 64.0)
            self.assertEqual(stratum["drawable_minus_full_frame_ms"]["p95"]["ms"], -5.0)
        invalid = copy.deepcopy(runs)
        invalid[0]["data"]["frames"][0]["upload_count"] = 0
        with self.assertRaises(ValueError):
            campaign.reduce_coverage(invalid)
        invalid = copy.deepcopy(runs)
        invalid[0]["data"]["uploads"][0]["accepted"] = False
        with self.assertRaises(ValueError):
            campaign.reduce_coverage(invalid)


class ReceiptTests(unittest.TestCase):
    def setUp(self):
        path = str(Path(__file__).resolve())
        self.engine = {"runtime": {"path": path, "sha256": "a" * 64}}
        self.source = {"commit": "b" * 40}
        self.process = {"renderer_banners": ["OpenGL API 4.5 Mesa - Compatibility - Using Device: Mesa - llvmpipe"]}
        self.config = {"size": 512, "workers": 1, "workload": "sparse"}
        self.data = {"ok": True, "failures": [],
                     "context": {"engine_path": path, "engine_sha256": "a" * 64,
                                 "source_revision": "b" * 40, "display_server": "X11",
                                 "backend": "opengl3", "video_adapter": "llvmpipe", "platform": "Linux"},
                     "config": {**self.config, "strategy": "full"},
                     "fixture_sha256": "d" * 64, "initial_image_sha256": "e" * 64,
                     "final_image_sha256": "f" * 64, "cohort": "deterministic_renderer_seam",
                     "final_strategy": {"active": "full"},
                     "frames": [{"frame_ms": 1.0}] * 4}

    def verify(self, data):
        campaign.verify_runtime_result(data, self.engine, self.source,
                                       process=self.process, rendering_driver="opengl3",
                                       config=self.config, frames=4, strategy="full")

    def test_qualified_receipt_accepted(self):
        self.verify(self.data)

    def test_failure_missing_frames_source_and_headless_refused(self):
        mutations = [
            lambda d: d.update(ok=False),
            lambda d: d.update(failures=["mismatch"]),
            lambda d: d.update(frames=d["frames"][:-1]),
            lambda d: d["context"].update(source_revision="c" * 40),
            lambda d: d["context"].update(display_server="headless"),
            lambda d: d["context"].update(engine_sha256="d" * 64),
            lambda d: d["context"].update(backend="opengl3_angle"),
            lambda d: d["context"].update(video_adapter=""),
            lambda d: d["config"].update(strategy="drawable"),
            lambda d: d.pop("initial_image_sha256"),
            lambda d: d.update(cohort="mounted_native_workbench"),
            lambda d: d["final_strategy"].update(active="drawable"),
        ]
        for mutate in mutations:
            data = copy.deepcopy(self.data)
            mutate(data)
            with self.subTest(mutate=mutate), self.assertRaises(ValueError):
                self.verify(data)

    def test_renderer_api_and_adapter_identity_are_preserved(self):
        graphics = campaign.verify_runtime_result(self.data, self.engine, self.source,
            process=self.process, rendering_driver="opengl3", config=self.config, frames=4, strategy="full")
        self.assertEqual(graphics["backend"], "opengl3")
        self.assertEqual(graphics["video_adapter"], "llvmpipe")
        self.assertEqual(graphics["renderer_api_banner"], self.process["renderer_banners"][0])
        for banners in ([], ["Vulkan 1.3 - Forward+"], ["OpenGL API invalid"]):
            with self.subTest(banners=banners), self.assertRaises(ValueError):
                campaign.verify_runtime_result(self.data, self.engine, self.source,
                    process={"renderer_banners": banners}, rendering_driver="opengl3",
                    config=self.config, frames=4, strategy="full")

    def test_native_worker_capacity_is_observed_not_assumed_equal_to_request(self):
        data = copy.deepcopy(self.data)
        config = {"size": 512, "workers": 4, "workload": "active"}
        data.update(cohort="mounted_native_workbench", native_backend="native-phased",
                    requested_workers=4, actual_native_worker_capacity=2,
                    config={**config, "strategy": "full"})
        campaign.verify_runtime_result(data, self.engine, self.source, process=self.process,
            rendering_driver="opengl3", config=config, frames=4, strategy="full")
        for capacity in (None, 0, -1):
            data["actual_native_worker_capacity"] = capacity
            with self.subTest(capacity=capacity), self.assertRaises(ValueError):
                campaign.verify_runtime_result(data, self.engine, self.source, process=self.process,
                    rendering_driver="opengl3", config=config, frames=4, strategy="full")


if __name__ == "__main__":
    unittest.main()
