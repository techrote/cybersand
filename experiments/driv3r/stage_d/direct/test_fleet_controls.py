"""Fail-closed tests for planned four-stream D-1A synthetic controls."""
from __future__ import annotations

from copy import deepcopy
import unittest

from experiments.driv3r.stage_d.direct import fleet_controls as fleet


class FourStreamControls(unittest.TestCase):
    def setUp(self):
        self.slots = fleet.make_slots()

    def test_four_unique_planned_streams_are_not_loaded_models(self):
        self.assertEqual(len(self.slots), 4)
        for k in ("wrangler_id", "synthetic_run_id", "seed", "requested_model_family"):
            self.assertEqual(len({s[k] for s in self.slots}), 4)
        for s in self.slots:
            fleet.validate_slot(s)
            self.assertIsNone(s["model_checkpoint_sha256"])
            self.assertIsNone(s["github_run_id"])
            self.assertEqual(s["active_worms"], 0)
            self.assertFalse(s["native_qualified"])

    def test_reject_fake_native_or_model_execution(self):
        for key, value in (("active_worms", 4), ("resident_pid", 1),
                           ("model_checkpoint_sha256", "a"*64),
                           ("github_run_id", 123), ("native_qualified", True),
                           ("native_receipt_artifact", "fake.zip")):
            with self.subTest(key=key):
                changed = dict(self.slots[0], **{key: value})
                with self.assertRaises(fleet.ControlRefused):
                    fleet.validate_slot(changed)

    def test_source_and_cross_stream_id_tampering_refused(self):
        for key, value in (("fixture_sha256", "f"*64),
                           ("synthetic_run_id", self.slots[1]["synthetic_run_id"]),
                           ("seed", self.slots[1]["seed"]),
                           ("m1_schema_sha256", "0"*64)):
            with self.subTest(key=key):
                with self.assertRaises(fleet.ControlRefused):
                    fleet.validate_slot(dict(self.slots[0], **{key: value}))

    def test_no_heldout_relabel_or_outcome_access(self):
        with self.assertRaisesRegex(fleet.ControlRefused, "held-out"):
            fleet._get_fixture("wall_switchback_v1")
        with self.assertRaisesRegex(fleet.ControlRefused, "held-out"):
            fleet._get_fixture("route_offset_gates_v1")

    def test_reject_unsupported_horizons_and_unbounded_work(self):
        for h in (0, 35, 37, 64, 129, True):
            with self.subTest(horizon=h):
                with self.assertRaises(fleet.ControlRefused):
                    fleet.run_matched_controls(self.slots[0], horizon=h)
        with self.assertRaises(fleet.ControlRefused):
            fleet.run_matched_controls(self.slots[0], horizon=128,
                                       oracle_probe_cap=3_000_001)

    def test_128_oracle_cap_is_preserved_as_negative_not_arrival(self):
        result = fleet.run_matched_controls(self.slots[0], horizon=128,
                                             oracle_probe_cap=1)
        self.assertEqual(result["state"], "ORACLE_RESOURCE_EXHAUSTED")
        self.assertEqual(result["arms"], [])
        self.assertEqual(result["sequential_native_receipts"], 0)
        with self.assertRaises(fleet.ControlRefused):
            fleet.replay_matched_controls(self.slots[0], result)

    def test_explicit_36_128_source_overlay_does_not_change_frozen_fixture(self):
        source = fleet._get_fixture(self.slots[0]["fixture_id"])
        before = source.sha256
        self.assertEqual(source.budget, 36)
        fleet.run_matched_controls(self.slots[0], horizon=128, oracle_probe_cap=1)
        self.assertEqual(fleet._get_fixture(source.fixture_id).sha256, before)
        self.assertEqual(source.budget, 36)

    def test_36_source_matched_three_controls_and_replay(self):
        report = fleet.run_matched_controls(self.slots[1], horizon=36)
        self.assertEqual(report["state"], "SYNTHETIC_CONTROLS_COMPLETE")
        self.assertEqual([a["policy"] for a in report["arms"]], list(fleet.POLICIES))
        self.assertTrue(fleet.replay_matched_controls(self.slots[1], report))
        self.assertGreater(report["oracle"]["predecessor_probes"], 0)
        self.assertLessEqual(report["oracle"]["predecessor_probes"],
                             report["oracle"]["probe_cap"])
        self.assertEqual({a["events"][0]["legal_set_sha256"]
                          for a in report["arms"]},
                         {report["common_initial_legal_set_sha256"]})
        for arm in report["arms"]:
            self.assertEqual(arm["sequential_native_receipts"], 0)
            self.assertEqual(arm["metrics"]["native_edit_operations"], 0)
            self.assertTrue(all(not e["native_receipt_ref"] for e in arm["events"]))

    def test_replay_rejects_fabricated_result_and_missing_failure_arm(self):
        report = fleet.run_matched_controls(self.slots[1], horizon=36)
        corrupt = deepcopy(report)
        corrupt["arms"][0]["metrics"]["arrived"] = not corrupt["arms"][0]["metrics"]["arrived"]
        with self.assertRaises(fleet.ControlRefused):
            fleet.replay_matched_controls(self.slots[1], corrupt)
        corrupt = deepcopy(report)
        corrupt["oracle"]["predecessor_probes"] += 1
        with self.assertRaises(fleet.ControlRefused):
            fleet.replay_matched_controls(self.slots[1], corrupt)
        corrupt = deepcopy(report)
        del corrupt["arms"][1]
        with self.assertRaises(fleet.ControlRefused):
            fleet.replay_matched_controls(self.slots[1], corrupt)

    def test_handoff_retains_all_four_negative_resource_cases(self):
        reports = tuple(fleet.run_matched_controls(s, horizon=128,
                                                     oracle_probe_cap=1)
                        for s in self.slots)
        handoff = fleet.compact_handoff(self.slots, reports)
        self.assertEqual(len(handoff["streams"]), 4)
        self.assertEqual([s["state"] for s in handoff["streams"]],
                         ["ORACLE_RESOURCE_EXHAUSTED"]*4)
        self.assertFalse(handoff["four_loaded_models"])
        self.assertFalse(handoff["native_128_approved"])
        self.assertEqual({s["native_receipts"] for s in handoff["streams"]}, {0})


if __name__ == "__main__":
    unittest.main()
