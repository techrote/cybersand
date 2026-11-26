#!/usr/bin/env python3
"""Guard selected physical comparison custody; synthetic fixtures are not episodes."""
from copy import deepcopy
import unittest
import probe_recovery as probe
from test_episode_tools import fixture


class RecoveryProbeTests(unittest.TestCase):
    def pair(self):
        before = fixture()
        # Extend the synthetic fixture to its registered30-second horizon.
        for item in (before["registration"][0], before["complete_registration"][0], before["campaigns"][0]):
            item["seconds"] = 30
        case = before["campaigns"][0]
        case.update(native_ticks=1800, physical_ticks=1800, completed_seconds=30)
        row = case["episodes"][0]
        row["trace"] = [dict(deepcopy(row["trace"][0]), seconds=i*.1, tick=i*6) for i in range(300)]
        row["accepted_commands"] = 300
        after = deepcopy(before)
        after["source_identity"]["source_revision"] = "1"*40
        after["source_identity"]["sha256"][probe.ALLOWED_CHANGED_SOURCE] = "2"*64
        return before, after

    def test_matching_source_change_is_scoped(self):
        before, after = self.pair()
        result = probe.compare_reports(before, after)
        self.assertEqual(result["changed_physical_source"], [probe.ALLOWED_CHANGED_SOURCE])
        self.assertEqual(len(result["pairs"]), 1)

    def test_reject_additional_physics_or_harness_change(self):
        for name in ("scripts/physical_actor_rig.gd", "tests/test_ambient2_episodes.gd"):
            before, after = self.pair()
            after["source_identity"]["sha256"][name] = "3"*64
            with self.assertRaises(ValueError): probe.compare_reports(before, after)

    def test_reject_runtime_change(self):
        before, after = self.pair()
        after["source_identity"]["godot_executable_sha256"] = "3"*64
        with self.assertRaises(ValueError): probe.compare_reports(before, after)

    def test_complete_project_guard_rejects_hidden_autoload_and_new_helper(self):
        before = {"loaded_project_sha256": {name: "a"*64 for name in
                  list(probe.ALLOWED_PROJECT_CHANGES)+["project.godot"]}}
        after = deepcopy(before)
        for name in probe.ALLOWED_PROJECT_CHANGES: after["loaded_project_sha256"][name] = "b"*64
        self.assertEqual(set(probe.comparison_projects(before, after)), probe.ALLOWED_PROJECT_CHANGES)
        after["loaded_project_sha256"]["project.godot"] = "b"*64
        with self.assertRaises(ValueError): probe.comparison_projects(before, after)
        after = deepcopy(before); after["loaded_project_sha256"]["scripts/new_helper.gd"] = "b"*64
        with self.assertRaises(ValueError): probe.comparison_projects(before, after)

    def test_reject_mismatched_material_pose_or_profile(self):
        for edit in (
            lambda c: c["initial_materials"].update(sha256="3"*64),
            lambda c: c.update(initial_pose_sha256="3"*64),
            lambda c: c["episodes"][0]["profile"].update(id="different"),
        ):
            before, after = self.pair(); edit(after["campaigns"][0])
            with self.assertRaises(ValueError): probe.compare_reports(before, after)

    def test_label_changes_and_vertical_gait_are_not_heading_reversals(self):
        before, _ = self.pair(); row = before["campaigns"][0]["episodes"][0]
        for i, sample in enumerate(row["trace"]):
            sample["position"] = [32, 175+(i%2)*3]
            sample["selection"] = "wander" if i%2 else "explore_unfamiliar"
        result = probe.direction_readback(row, 6.5, 8.5)
        self.assertEqual(result["samples"], 21)
        self.assertEqual(result["horizontal_heading_reversals"], 0)
        self.assertEqual(result["x_range_cells"], 0)

    def test_adjacent_active_heading_reversal_and_neutral_break(self):
        row = {"trace": [{"seconds": i*.1, "position": [32, 175], "intent_direction": [x, 0],
                          "intent_pace": .45, "has_procedural_intent": True}
                         for i, x in enumerate([1,-1,0,1,-1])]}
        self.assertEqual(probe.direction_readback(row)["horizontal_heading_reversals"], 2)
        row["trace"][1]["intent_pace"] = 0
        self.assertEqual(probe.direction_readback(row)["horizontal_heading_reversals"], 1)
        row["trace"][4]["has_procedural_intent"] = False
        self.assertEqual(probe.direction_readback(row)["horizontal_heading_reversals"], 0)

    def test_selected_report_cannot_claim_full_programme(self):
        before, _ = self.pair()
        registry = {"registration": before["registration"], "source_identity": before["source_identity"]}
        report = probe.selected_report(registry, before["registration"], [before], [])
        self.assertEqual(report["mode"], "shard")
        self.assertIn("not the full", report["selection_scope"])
        self.assertEqual(report["expected_actor_episodes"], 1)

    def test_unknown_or_duplicate_requested_case_is_refused(self):
        registration = fixture()["registration"]
        for requested in (["missing"], ["synthetic-case", "synthetic-case"]):
            with self.assertRaises(ValueError): probe.select_cases(registration, requested)


if __name__ == "__main__":
    unittest.main()
