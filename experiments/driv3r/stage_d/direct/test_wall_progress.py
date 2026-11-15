"""Exact, cheap selected-wall progress diagnostics; no native or held-out rollout."""
import copy
import unittest

from experiments.driv3r.stage_d.direct import offline as d
from experiments.driv3r.stage_d.direct import wall_progress as w


class WallProgressTests(unittest.TestCase):
    def test_far_from_wall_false_max_y_progress(self):
        path = [(x, 2) for x in range(18, 30)] + [(29, y) for y in range(3, 7)]
        result = w._summarize_wall_progress(path, 2, 6,
            lambda p: float(p[0] - 10))
        self.assertEqual(result["ungated_max_y_progress_fraction"], 1.0)
        self.assertEqual(result["ordered_band_qualified_rows"], 1)
        self.assertEqual(result["ordered_band_progress_fraction"], 0.0)
        self.assertEqual(result["distinct_band_qualified_rows"], 1)
        self.assertGreater(result["ungated_minus_ordered_progress"], 0.7)
        self.assertEqual(result["first_band_exit_path_index"], 3)

    def test_ordered_band_coverage_and_reentry(self):
        path = [(18, 2), (18, 3), (30, 4), (18, 4), (18, 5), (18, 6)]
        result = w._summarize_wall_progress(path, 2, 6,
            lambda p: 20.0 if p == (30, 4) else 8.0)
        self.assertEqual(result["ordered_band_qualified_rows"], 5)
        self.assertEqual(result["ordered_band_progress_fraction"], 1.0)
        self.assertEqual(result["distinct_band_qualified_rows"], 5)
        self.assertEqual(result["band_exits"], 1)
        self.assertEqual(result["band_reentries"], 1)
        self.assertEqual(result["longest_consecutive_off_band_path_cells"], 1)

    def test_out_of_order_row_visits_do_not_imply_ordered_coverage(self):
        result = w._summarize_wall_progress(
            [(18, 2), (18, 5), (18, 6)], 2, 6, lambda p: 8.0)
        self.assertEqual(result["distinct_band_qualified_rows"], 3)
        self.assertEqual(result["ordered_band_qualified_rows"], 1)

    def test_full_development_oracle_replay(self):
        for family in ("step", "recess", "bulge"):
            with self.subTest(family=family):
                fixture = d.wall_fixture(family, "development")
                record = d.run_episode(fixture, "contour_astar")
                report = w.audit_development_wall_progress(fixture, record)
                self.assertFalse(report["native_qualified"])
                self.assertFalse(report["model_evaluated"])
                self.assertEqual(report["summary"]["ungated_max_y_progress_fraction"],
                                 record["metrics"]["route_progress_fraction"])

    def test_sealed_heldout_and_tampered_development_rejected(self):
        heldout = d.wall_fixture("switchback", "heldout")
        with self.assertRaises(ValueError):
            w.audit_development_wall_progress(heldout, {"events": []})
        fixture = d.wall_fixture("step", "development")
        record = d.run_episode(fixture, "contour_astar")
        tampered = copy.deepcopy(record)
        tampered["events"][0]["choice_id"] = "W8"
        with self.assertRaises(ValueError):
            w.audit_development_wall_progress(fixture, tampered)


if __name__ == "__main__":
    unittest.main()
