"""Cheap DEVELOPMENT-only target-sweep diagnostic regression tests."""
import copy
import unittest

from experiments.driv3r.stage_d.direct import offline as d
from experiments.driv3r.stage_d.direct import target_sweep as t


class TargetSweepTests(unittest.TestCase):
    def test_interior_macro_target_contact_is_not_arrival(self):
        report = t._summarize_sweeps((2, 0),
            [(0, ((1, 0), (2, 0), (3, 0), (4, 0)))], (4, 0))
        self.assertTrue(report["target_swept_at_least_once"])
        self.assertFalse(report["terminal_cursor_at_target"])
        self.assertTrue(report["first_contact_overshot_within_macro"])
        self.assertEqual(report["first_target_contact"]["one_based_global_cell_step"], 2)
        self.assertEqual(report["post_first_contact_cell_steps"], 2)
        self.assertEqual(report["total_target_cell_contacts"], 1)

    def test_macro_endpoint_contact_is_terminal_arrival(self):
        report = t._summarize_sweeps((2, 0),
            [(0, ((1, 0), (2, 0)))], (2, 0))
        self.assertTrue(report["terminal_cursor_at_target"])
        self.assertFalse(report["first_contact_overshot_within_macro"])
        self.assertTrue(report["first_target_contact"]["contact_at_action_endpoint"])
        self.assertEqual(report["post_first_contact_cell_steps"], 0)

    def test_no_contact_is_distinct_from_false_stop(self):
        report = t._summarize_sweeps((3, 0),
            [(0, ((1, 0),)), (1, ())], (1, 0))
        self.assertFalse(report["target_swept_at_least_once"])
        self.assertIsNone(report["first_target_contact"])
        self.assertIsNone(report["post_first_contact_cell_steps"])
        self.assertEqual(report["total_swept_cell_steps"], 1)

    def test_repeated_contact_counts_each_crossing(self):
        report = t._summarize_sweeps((2, 0),
            [(0, ((1, 0), (2, 0), (3, 0))),
             (1, ((2, 0), (1, 0), (2, 0)))], (2, 0))
        self.assertEqual(report["total_target_cell_contacts"], 3)
        self.assertEqual(report["post_first_contact_cell_steps"], 4)
        self.assertTrue(report["terminal_cursor_at_target"])

    def test_development_replay_pins_native_claims_to_false(self):
        for fixture in (d.wall_fixture("step", "development"),
                        d.routing_fixture("gate", "development")):
            policy = "contour_astar" if fixture.task == "wall_offset" else "astar"
            for lengths in ((1,), (1, 2, 4, 8)):
                with self.subTest(fixture=fixture.fixture_id, lengths=lengths):
                    episode = d.run_episode(fixture, policy, lengths=lengths)
                    result = t.audit_development_target_contact(fixture, episode)
                    self.assertFalse(result["native_qualified"])
                    self.assertFalse(result["model_evaluated"])
                    self.assertEqual(result["decision_count"], len(episode["events"]))
                    self.assertEqual(result["target_contact_summary"][
                        "terminal_cursor_at_target"], episode["metrics"]["arrived"])
                    self.assertEqual(result["target_contact_summary"][
                        "total_swept_cell_steps"], episode["metrics"]["cursor_cell_steps"])

    def test_heldout_and_tampered_synthetic_episode_refused(self):
        heldout = d.wall_fixture("switchback", "heldout")
        with self.assertRaises(ValueError):
            t.audit_development_target_contact(heldout, {"events": []})
        fixture = d.routing_fixture("gate", "development")
        valid = d.run_episode(fixture, "astar")
        forged = copy.deepcopy(valid)
        forged["events"][0]["choice_id"] = "UNAPPROVED"
        with self.assertRaises(ValueError):
            t.audit_development_target_contact(fixture, forged)


if __name__ == "__main__":
    unittest.main()
