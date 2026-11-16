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
                           ("native_receipt_artifact", "fake.zip"),
                           ("native_128_turn_approved", True),
                           ("native_logical_move_cap_unmodified", 128),
                           ("policies", ["astar_or_contour"]),
                           ("fixture_split", "heldout")):
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

    def test_four_negative_cases_report_exact_attempted_cost(self):
        reports = tuple(fleet.run_matched_controls(s, horizon=128,
                                                    oracle_probe_cap=1)
                        for s in self.slots)
        for report in reports:
            self.assertEqual(report["state"], "ORACLE_RESOURCE_EXHAUSTED")
            self.assertEqual(report["oracle_predecessor_probes"], 2)
            self.assertEqual(report["oracle_probe_cap"], 1)
            self.assertEqual(report["oracle_failure_kind"],
                             "resource_exhausted_before_optimum")
            self.assertIsNone(report["oracle_optimal_cost_within_budget"])
            self.assertIsNone(report["oracle_feasible_arrival_within_budget"])
            self.assertEqual(report["arms"], [])
        handoff = fleet.compact_handoff(self.slots, reports)
        self.assertEqual([s["oracle_predecessor_probes"]
                          for s in handoff["streams"]], [2]*4)
        self.assertEqual([s["oracle_failure_kind"]
                          for s in handoff["streams"]],
                         ["resource_exhausted_before_optimum"]*4)
        forged = deepcopy(reports)
        forged[0]["oracle_predecessor_probes"] = 1
        with self.assertRaises(fleet.ControlRefused):
            fleet.compact_handoff(self.slots, tuple(forged))

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

    def test_source_replayed_line_character_is_descriptive_not_art_quality(self):
        report = fleet.run_matched_controls(self.slots[1], horizon=36)
        self.assertEqual(report["state"], "SYNTHETIC_CONTROLS_COMPLETE")
        self.assertEqual(len(report["line_character_source_sha256"]), 64)
        for arm in report["arms"]:
            signature = arm["line_character"]
            self.assertEqual(signature["movement_cells"], arm["metrics"]["cursor_cell_steps"])
            self.assertEqual(signature["revisited_cursor_steps"], arm["metrics"]["retraced_cells"])
            self.assertFalse(signature["artistic_quality_measured"])
            self.assertFalse(signature["native_qualified"])
            self.assertEqual(signature["evidence_kind"],
                             "descriptive_synthetic_cursor_geometry_only")
        self.assertTrue(fleet.replay_matched_controls(self.slots[1], report))

    def test_line_character_forgery_rejected_even_when_arrival_unchanged(self):
        report = fleet.run_matched_controls(self.slots[1], horizon=36)
        report["arms"][0]["line_character"]["nontrivial_loop_closures"] += 1
        with self.assertRaises(fleet.ControlRefused):
            fleet.replay_matched_controls(self.slots[1], report)

    def test_episode_identity_distinguishes_horizon_and_oracle_work_cap(self):
        slot = self.slots[0]
        a = fleet.run_matched_controls(slot, horizon=36, oracle_probe_cap=1)
        b = fleet.run_matched_controls(slot, horizon=128, oracle_probe_cap=1)
        c = fleet.run_matched_controls(slot, horizon=128, oracle_probe_cap=2)
        self.assertEqual({r["state"] for r in (a, b, c)},
                         {"ORACLE_RESOURCE_EXHAUSTED"})
        self.assertEqual({r["synthetic_run_id"] for r in (a, b, c)},
                         {slot["synthetic_run_id"]})
        self.assertEqual(len({r["episode_run_id"] for r in (a, b, c)}), 3)
        for result in (a, b, c):
            self.assertEqual(result["native_qualified"], False)
            self.assertEqual(result["arms"], [])
            for source in ("fleet_controls_source_sha256", "oracle_source_sha256",
                           "offline_source_sha256", "line_character_source_sha256"):
                self.assertEqual(len(result[source]), 64)

    def test_four_stream_handoff_rejects_mixed_horizon_and_probe_cap(self):
        reports = [fleet.run_matched_controls(s, horizon=128,
                                              oracle_probe_cap=1)
                   for s in self.slots]
        self.assertEqual(len({r["episode_run_id"] for r in reports}), 4)
        handoff = fleet.compact_handoff(self.slots, tuple(reports))
        self.assertEqual(handoff["matched_horizon"], 128)
        self.assertEqual(handoff["matched_oracle_probe_cap"], 1)
        self.assertEqual(len({r["episode_run_id"] for r in handoff["streams"]}), 4)
        mismatched = reports[:]
        mismatched[0] = fleet.run_matched_controls(self.slots[0], horizon=36,
                                                    oracle_probe_cap=1)
        with self.assertRaisesRegex(fleet.ControlRefused, "same horizon"):
            fleet.compact_handoff(self.slots, tuple(mismatched))
        mismatched[0] = fleet.run_matched_controls(self.slots[0], horizon=128,
                                                    oracle_probe_cap=2)
        with self.assertRaisesRegex(fleet.ControlRefused, "same horizon"):
            fleet.compact_handoff(self.slots, tuple(mismatched))

    def test_resource_exhaustion_identity_forgery_is_rejected(self):
        reports = [fleet.run_matched_controls(s, horizon=128,
                                              oracle_probe_cap=1)
                   for s in self.slots]
        reports[0]["episode_run_id"] = "f" * 64
        with self.assertRaisesRegex(fleet.ControlRefused, "replay mismatch"):
            fleet.compact_handoff(self.slots, tuple(reports))

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
        self.assertTrue(all(s["arm_line_character"] == {} for s in handoff["streams"]))


if __name__ == "__main__":
    unittest.main()
