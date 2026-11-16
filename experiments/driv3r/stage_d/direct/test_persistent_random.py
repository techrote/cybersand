"""DEVELOPMENT-only movement-complete seeded-random control regressions.

The original random_legal first-pass policy remains untouched, including its
legal STOP selection. These tests do not open held-out behavioral outcomes.
"""
import json
import random
import unittest

from experiments.driv3r.stage_d.direct import offline as d
from experiments.driv3r.stage_d.direct import paired as p


class PersistentRandomControls(unittest.TestCase):
    def setUp(self):
        self.route = d.routing_fixture("gate", "development")
        self.wall = d.wall_fixture("step", "development")

    def test_original_random_stop_semantics_remain_intact(self):
        choices = d.candidates(self.route, self.route.start)
        class First:
            def choice(self, values):
                return values[0]
        old = d.select_candidate(self.route, self.route.start, choices,
                                 "random_legal", First())
        new = d.select_candidate(self.route, self.route.start, choices,
                                 "random_legal_persistent_v1", First())
        self.assertEqual(old.candidate_id, "STOP")
        self.assertNotEqual(new.candidate_id, "STOP")
        self.assertIn(new, choices)

    def test_persistent_random_stops_only_when_trapped_or_arrived(self):
        for fixture in (self.route, self.wall):
            for seed in (0, 1, 7):
                with self.subTest(fixture=fixture.fixture_id, seed=seed):
                    result = d.run_episode(
                        fixture, "random_legal_persistent_v1", seed,
                        lengths=(1, 2, 4, 8))
                    for event in result["events"]:
                        offered = event["observation"]["candidates"]
                        if event["choice_id"] == "STOP":
                            self.assertFalse(any(not c["stop"] for c in offered))
                    self.assertLessEqual(len(result["events"]), 36)
                    self.assertEqual(result["metrics"]["collisions"], 0)
                    self.assertEqual(result["metrics"]["material_z_violations"], 0)
                    self.assertEqual(result["sequential_native_receipts"], 0)

    def test_no_movement_candidates_force_inert_stop(self):
        stop = d.Candidate("STOP", (), True)
        chosen = d.select_candidate(self.route, self.route.start, (stop,),
                                    "random_legal_persistent_v1", random.Random(5))
        self.assertIs(chosen, stop)
        score = d.score_episode(self.route, [self.route.start],
                                1, "no_legal_moves")
        self.assertEqual(score["stop_reason"], "no_legal_moves")
        self.assertFalse(score["false_stop"])

    def test_seeded_replay_and_json_roundtrip(self):
        original = d.run_episode(self.route, "random_legal_persistent_v1",
                                 seed=91, lengths=(1, 2, 4, 8))
        self.assertEqual(original, d.run_episode(
            self.route, "random_legal_persistent_v1", 91, (1, 2, 4, 8)))
        self.assertTrue(p.verify_episode(
            self.route, json.loads(json.dumps(original)))["validated"])
        self.assertFalse(original["native_qualified"])

    def test_three_controls_preserve_source_matched_initial_menu(self):
        for fixture in (self.route, self.wall):
            with self.subTest(fixture=fixture.fixture_id):
                result = p.run_development_controls(
                    fixture, seed=13, macro_lengths=(1, 2, 4, 8))
                self.assertEqual(result["comparison_design"],
                                 "d1a-three-offline-controls/1")
                self.assertEqual(set(result["arm_names"]), {
                    "geometric", "random_legal", "random_persistent_v1"})
                self.assertTrue(result["matched_candidate_sets_checked_through_divergence"])
                self.assertFalse(result["post_divergence_candidate_matching_claimed"])
                self.assertEqual(result["synthetic_effect_audit"][
                    "first_consequential_native_divergence"], "not_measured")

    def test_heldout_dispatch_refused_before_behavior(self):
        sealed = d.wall_fixture("switchback", "heldout")
        with self.assertRaisesRegex(p.EvidenceError, "Held-out"):
            p.run_development_controls(sealed, seed=5)
        with self.assertRaisesRegex(ValueError, "Held-out"):
            d.run_episode(sealed, "random_legal_persistent_v1", seed=5)


if __name__ == "__main__":
    unittest.main()
