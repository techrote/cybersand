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

    def test_clean_contiguous_trace_covers_entire_selected_wall(self):
        path = [(18, y) for y in range(2, 7)]
        summary = w._summarize_wall_progress(path, 2, 6, lambda p: 8.0)
        self.assertEqual(summary["ordered_band_progress_fraction"], 1.0)
        self.assertEqual(summary["longest_contiguous_forward_band_rows"], 5)
        self.assertEqual(summary["longest_contiguous_forward_band_progress_fraction"], 1.0)
        self.assertEqual(summary["longest_contiguous_forward_band_start_row"], 2)
        self.assertEqual(summary["longest_contiguous_forward_band_end_row"], 6)

    def test_disconnected_row_contacts_do_not_count_as_continuous_trace(self):
        # Adjacent four-connected cells; leave the selected 6-10 band via x=21,
        # return at the next row, and reach every row in order nevertheless.
        path = [(18, 2), (18, 3), (19, 3), (20, 3), (21, 3),
                (21, 4), (20, 4), (19, 4), (18, 4), (18, 5), (18, 6)]
        summary = w._summarize_wall_progress(path, 2, 6,
                                              lambda p: float(p[0] - 10))
        self.assertEqual(summary["ordered_band_progress_fraction"], 1.0)
        self.assertEqual(summary["longest_contiguous_forward_band_rows"], 3)
        self.assertEqual(summary["longest_contiguous_forward_band_progress_fraction"], 0.5)
        self.assertEqual(summary["longest_contiguous_forward_band_start_row"], 4)
        self.assertEqual(summary["longest_contiguous_forward_band_end_row"], 6)
        self.assertEqual(summary["band_exits"], 1)
        self.assertEqual(summary["band_reentries"], 1)

    def test_reverse_motion_resets_forward_continuity(self):
        path = [(18, y) for y in (2, 3, 4, 3, 4, 5, 6)]
        summary = w._summarize_wall_progress(path, 2, 6, lambda p: 8.0)
        self.assertEqual(summary["ordered_band_progress_fraction"], 1.0)
        self.assertEqual(summary["longest_contiguous_forward_band_rows"], 4)
        self.assertEqual(summary["longest_contiguous_forward_band_progress_fraction"], 0.75)
        self.assertEqual(summary["longest_contiguous_forward_band_start_row"], 3)
        self.assertEqual(summary["longest_contiguous_forward_band_end_row"], 6)

    def test_lateral_duplicates_and_sparse_jumps_do_not_inflate_continuity(self):
        lateral = [(18, 2), (19, 2), (20, 2), (19, 2), (18, 2)]
        summary = w._summarize_wall_progress(lateral, 2, 6,
                                              lambda p: float(p[0] - 10))
        self.assertEqual(summary["longest_contiguous_forward_band_rows"], 1)
        self.assertEqual(summary["longest_contiguous_forward_band_progress_fraction"], 0.0)
        # Pure-helper defensive case. Real production entry point admits only
        # replay-verified cardinal movement with complete swept-cell records.
        sparse = w._summarize_wall_progress(
            [(18, 2), (18, 4), (18, 6)], 2, 6, lambda p: 8.0)
        self.assertEqual(sparse["longest_contiguous_forward_band_rows"], 1)
        self.assertEqual(sparse["longest_contiguous_forward_band_progress_fraction"], 0.0)

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
