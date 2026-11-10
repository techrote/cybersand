#!/usr/bin/env python3
"""No native run: attack provenance and statistical admission on captured profiles."""
import copy
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from reduce_hs470_abba import EvidenceError, reduce


class ABBAEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = json.loads((Path(__file__).parent / "hs470_abba_profiles.json").read_text())

    def mutated(self):
        return copy.deepcopy(self.fixture)

    def test_real_run_stage_gate(self):
        r = reduce(self.fixture)
        self.assertEqual(r["canvases"]["bench-canvas"]["gate"], "STAGE_ONLY")
        self.assertEqual(r["canvases"]["stress-canvas"]["gate"], "HOLD_LOW_SAMPLE")
        self.assertEqual(r["canvases"]["my-canvas"]["gate"], "NO_PACKET_EVENTS")
        self.assertEqual(r["canvases"]["bench-canvas"]["pairs"][0]["control_packet_samples"], 122)
        self.assertGreater(r["canvases"]["bench-canvas"]["pairs"][0]["packet_p50_reduction_pct"], 94)
        self.assertEqual(r["physical_parity"], "NOT_OBSERVED_IN_THIS_PROFILE")

    def test_wrong_source_rejected(self):
        d = self.mutated(); d["records"][4]["profile"]["source_sha"] = "0" * 40
        with self.assertRaisesRegex(EvidenceError, "source mismatch"): reduce(d)

    def test_wrong_native_rejected(self):
        d = self.mutated(); d["records"][4]["profile"]["runtime"]["native_sha256"] = "a" * 64
        with self.assertRaisesRegex(EvidenceError, "binary mismatch"): reduce(d)

    def test_wrong_host_rejected(self):
        d = self.mutated(); d["records"][4]["profile"]["runtime"]["processor"] = "another-host"
        with self.assertRaisesRegex(EvidenceError, "host/environment mismatch"): reduce(d)

    def test_forged_order_rejected(self):
        d = self.mutated(); d["records"][4]["arm"] = "control"
        with self.assertRaisesRegex(EvidenceError, "arm/ordering mismatch"): reduce(d)

    def test_zero_samples_with_nonzero_time_rejected(self):
        d = self.mutated(); d["records"][0]["profile"]["hard_surface_packet_executed"]["p50_ms"] = 0.1
        with self.assertRaisesRegex(EvidenceError, "nonzero timing without samples"): reduce(d)

    def test_fake_p95_rejected(self):
        d = self.mutated(); d["records"][4]["profile"]["simulation"]["p95_ms"] = 0.01
        with self.assertRaisesRegex(EvidenceError, "impossible percentile order"): reduce(d)

    def test_missing_run_rejected(self):
        d = self.mutated(); d["records"].pop()
        with self.assertRaisesRegex(EvidenceError, "exactly 12"): reduce(d)

    def test_wrong_window_rejected(self):
        d = self.mutated(); d["records"][3]["profile"]["warmup_ticks"] = 0
        with self.assertRaisesRegex(EvidenceError, "acquisition window mismatch"): reduce(d)


    def test_original_12_profiles_obey_producer_sample_invariants(self):
        for item in self.fixture["records"]:
            p = item["profile"]
            n = p["observed_snapshots"]
            for metric in ("simulation", "snapshot_copy_total", "publication_build"):
                self.assertEqual(p[metric]["samples"], n)
            for metric in ("hard_surface_packet_executed", "render_exchange_executed"):
                self.assertLessEqual(p[metric]["samples"], n)
            for metric in ("simulation", "snapshot_copy_total", "publication_build",
                           "hard_surface_packet_executed", "render_exchange_executed"):
                self.assertLessEqual(p[metric]["mean_ms"], p[metric]["max_ms"] + 1e-9)

    def test_forged_stress_packet_exposure_cannot_promote_gate(self):
        d = self.mutated()
        # Exact upstream producer appends at most one packet timing per snapshot.
        # A mutator could previously inflate low-count stress arms >100 and
        # turn HOLD_LOW_SAMPLE into STAGE_ONLY without touching source/host IDs.
        for idx in (2, 5, 8, 11):
            p = d["records"][idx]["profile"]
            p["hard_surface_packet_executed"]["samples"] = p["observed_snapshots"] + 1
        with self.assertRaisesRegex(EvidenceError, "event count exceeds snapshots"):
            reduce(d)

    def test_impossible_mean_above_maximum_refused(self):
        d = self.mutated()
        s = d["records"][1]["profile"]["hard_surface_packet_executed"]
        s["mean_ms"] = s["max_ms"] + 1.0
        with self.assertRaisesRegex(EvidenceError, "mean exceeds maximum"):
            reduce(d)

    def test_whole_snapshot_cardinality_refusals(self):
        for metric in ("simulation", "snapshot_copy_total", "publication_build"):
            with self.subTest(metric=metric):
                d = self.mutated()
                d["records"][1]["profile"][metric]["samples"] -= 1
                with self.assertRaisesRegex(EvidenceError, "whole-snapshot sample mismatch"):
                    reduce(d)

    def test_executed_render_exposure_refusal(self):
        d = self.mutated()
        p = d["records"][3]["profile"]
        p["render_exchange_executed"]["samples"] = p["observed_snapshots"] + 1
        with self.assertRaisesRegex(EvidenceError, "event count exceeds snapshots"):
            reduce(d)


if __name__ == "__main__":
    unittest.main()
