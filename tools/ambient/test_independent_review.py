#!/usr/bin/env python3
"""Independent readback boundary tests. Synthetic inputs are zero physical episodes."""
from copy import deepcopy
import unittest
import review_episodes as review


def movement_fixture():
    samples = []
    for index in range(20):
        samples.append({"seconds": index*.1, "position": [32.0, 175.0+(index % 2)*3],
                        "has_procedural_intent": True, "intent_direction": [1, 0],
                        "intent_pace": .45, "action_move": [.45, 0], "selection": "wander",
                        "oil": {"available": True, "present": False},
                        "water": {"available": True, "present": False}})
    actor = {"episode_id": "synthetic", "model": "runner", "start": [32.0, 175.0],
             "last": [32.0, 178.0], "trace": samples, "physical_path_cells": 60.0,
             "active_intervals": 19, "stalled_active_intervals": 19}
    return {"seconds": 2}, actor


def profile_fixture():
    return {"id": "synthetic", "seed": 1701, "memory": {"enabled": True, "capacity": 64},
            "personality": {"enabled": True, "curiosity": .7}, "drives_enabled": True,
            "perception": {"spacing_cells": 4, "near_radius_cells": 8, "refine_boundaries": True},
            "modules": [{"type": "regroup", "enabled": True}, {"type": "wander", "enabled": True}]}


def ablation_fixture():
    base = {"id": "base", "matched_group": "synthetic", "arm": "stateful",
            "initial_materials": {}, "initial_pose_sha256": "a"*64, "geometry": [],
            "episodes": [{"episode_id": "synthetic-base", "actor_instance": 100,
                          "controller": "stateful", "profile": profile_fixture()}]}
    altered = deepcopy(base)
    altered.update(id="altered", arm="no_memory")
    altered["episodes"][0]["episode_id"] = "synthetic-altered"
    altered["episodes"][0]["profile"] = review.expected_ablation(base["episodes"][0]["profile"], "no_memory")
    return base, altered


class IndependentReadbackTests(unittest.TestCase):
    def test_vertical_ground_gait_does_not_become_exploration(self):
        campaign, actor = movement_fixture()
        result = review.independent_metrics(campaign, actor)
        self.assertEqual(result["stalled_active_fraction"], 1)
        self.assertEqual(result["net_displacement_cells"], 0)
        self.assertEqual(result["stable_territory_cells"], 1)

    def test_same_vertical_motion_is_real_flight_progress(self):
        campaign, actor = movement_fixture()
        actor.update(model="4ly_trainer", stalled_active_intervals=0)
        result = review.independent_metrics(campaign, actor)
        self.assertEqual(result["stalled_active_fraction"], 0)
        self.assertEqual(result["net_displacement_cells"], 3)

    def test_grid_boundary_occupancy_keeps_small_actual_range_visible(self):
        campaign, actor = movement_fixture()
        actor["start"] = [15.99, 175.0]
        for index, sample in enumerate(actor["trace"]):
            sample["position"] = [15.99 if index % 2 == 0 else 16.01, 175.0]
        actor["last"] = [16.01, 175.0]
        result = review.independent_metrics(campaign, actor)
        self.assertEqual(result["stable_territory_cells"], 2)
        self.assertAlmostEqual(result["x_range_cells"], .02)
        self.assertAlmostEqual(result["net_displacement_cells"], .02)

    def test_raw_stall_disagreement_is_refused(self):
        campaign, actor = movement_fixture()
        actor["stalled_active_intervals"] = 0
        with self.assertRaises(ValueError):
            review.independent_metrics(campaign, actor)

    def test_material_distance_must_agree_with_observed_position(self):
        campaign, actor = movement_fixture()
        actor["trace"][0]["oil"] = {"available": True, "present": True,
                                   "nearest": [62.0, 175.0], "distance": 1.0}
        with self.assertRaises(ValueError):
            review.independent_metrics(campaign, actor)

    def test_exact_memory_ablation_is_admitted_without_mutating_base(self):
        base, altered = ablation_fixture()
        original = deepcopy(base)
        pairs = review.audit_ablations([base, altered])
        self.assertEqual(pairs[0]["subject_pairs"], 1)
        self.assertEqual(base, original)

    def test_seed_change_disqualifies_an_otherwise_valid_ablation(self):
        base, altered = ablation_fixture()
        altered["episodes"][0]["profile"]["seed"] += 1
        with self.assertRaises(ValueError):
            review.audit_ablations([base, altered])

    def test_partial_or_preflight_report_cannot_claim_full_programme(self):
        for report in ({"complete": False, "failures": [], "mode": "full"},
                       {"complete": True, "failures": [], "mode": "shard"}):
            with self.assertRaises(ValueError):
                review.audit(report, {})

    def test_blended_contributors_are_not_counted_as_new_goals(self):
        actor = {"profile": {"modules": [{"id": "investigate", "type": "investigate_material"}]},
                 "trace": [{"selection": "blend:wander", "phase": ""},
                           {"selection": "blend:wander,align", "phase": ""},
                           {"selection": "investigate", "phase": "approach"},
                           {"selection": "investigate", "phase": "inspect"}]}
        result = review.selection_activity(actor)
        self.assertEqual(result["selection_label_changes"], 2)
        self.assertEqual(result["blend_to_blend_label_changes"], 1)
        self.assertEqual(result["same_module_phase_changes"], 1)
        self.assertIsNone(result["goal_instance_count"])
        self.assertFalse(result["home_module_authored"])


if __name__ == "__main__":
    unittest.main()
