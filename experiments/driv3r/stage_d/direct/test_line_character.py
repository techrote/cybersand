"""Cheap exact-geometry D-1A drawing-worm descriptors; no model/native work."""
import json
import unittest

from experiments.driv3r.stage_d.direct.line_character import describe_cursor_path as describe


class CursorLineCharacterTests(unittest.TestCase):
    def test_stationary_start_has_no_fabricated_stroke(self):
        r = describe([(2, 3)])
        self.assertEqual(r["movement_cells"], 0)
        self.assertEqual(r["maximum_consecutive_straight_cells"], 0)
        self.assertEqual(r["heading_entropy_bits"], 0)
        self.assertFalse(r["native_qualified"])
        self.assertFalse(r["artistic_quality_measured"])

    def test_straight_path_has_zero_turns_and_entropy(self):
        r = describe([(0, 0), (1, 0), (2, 0), (3, 0)])
        self.assertEqual(r["movement_cells"], 3)
        self.assertEqual(r["maximum_consecutive_straight_cells"], 3)
        self.assertEqual(r["heading_counts"], {"E": 3, "N": 0, "S": 0, "W": 0})
        self.assertEqual(r["heading_entropy_bits"], 0)
        self.assertEqual(r["turn_fraction_per_heading_transition"], 0)

    def test_square_loop_is_legal_character_not_failure(self):
        r = describe([(0, 0), (1, 0), (1, 1), (0, 1), (0, 0)])
        self.assertEqual(r["nontrivial_loop_closures"], 1)
        self.assertEqual(r["revisited_cursor_steps"], 1)
        self.assertEqual(r["reused_undirected_edge_steps"], 0)
        self.assertEqual(r["right_angle_clockwise_turns"], 3)
        self.assertEqual(r["heading_entropy_bits"], 2)
        self.assertEqual(r["distinct_cursor_cells"], 4)

    def test_pingpong_is_retracing_not_a_four_cell_loop(self):
        r = describe([(0, 0), (1, 0), (0, 0), (1, 0), (0, 0)])
        self.assertEqual(r["immediate_reverse_turns"], 3)
        self.assertEqual(r["reused_undirected_edge_steps"], 3)
        self.assertEqual(r["revisited_cursor_steps"], 3)
        self.assertEqual(r["nontrivial_loop_closures"], 0)
        self.assertEqual(r["turn_fraction_per_heading_transition"], 0)

    def test_left_and_right_use_downward_y_screen_coordinates(self):
        right = describe([(0, 0), (1, 0), (1, 1)])
        left = describe([(0, 0), (1, 0), (1, -1)])
        self.assertEqual((right["right_angle_clockwise_turns"], right["left_angle_counterclockwise_turns"]), (1, 0))
        self.assertEqual((left["right_angle_clockwise_turns"], left["left_angle_counterclockwise_turns"]), (0, 1))

    def test_json_roundtrip_keeps_exact_character(self):
        original = [(0, 0), (1, 0), (2, 0), (2, -1), (2, -2)]
        self.assertEqual(describe(original), describe(json.loads(json.dumps(original))))

    def test_rejects_teleport_diagonal_stay_and_noninteger_coordinates(self):
        cases = [[], [(0, 0), (2, 0)], [(0, 0), (1, 1)],
                 [(0, 0), (0, 0)], [(True, 0)], [(0.0, 0)], [(1,)], "nopath"]
        for case in cases:
            with self.subTest(case=case), self.assertRaises(ValueError):
                describe(case)

    def test_max_path_bound_and_no_art_ranking(self):
        with self.assertRaises(ValueError):
            describe([(0, 0)] * 4098)
        r = describe([(0, 0), (0, 1)])
        self.assertEqual(r["evidence_kind"], "descriptive_synthetic_cursor_geometry_only")
        self.assertNotIn("success", r)
        self.assertNotIn("beauty_score", r)


if __name__ == "__main__":
    unittest.main()
