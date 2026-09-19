#!/usr/bin/env python3
import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import reduce as wl


class WaterLevelingReducerTests(unittest.TestCase):
    def test_ols_slope(self):
        self.assertAlmostEqual(wl.ols_slope([(0.0, 0.0), (1.0, 2.0), (2.0, 4.0)]), 2.0)

    def test_symmetric_mound_has_local_slope_even_when_global_is_zero(self):
        columns = [0] * 31
        for x in range(5, 26):
            columns[x] = 10 * wl.MASS_MAX
        for x in range(13, 18):
            columns[x] += (2 - abs(15 - x)) * wl.MASS_MAX
        global_slope = wl.max_abs_global_slope(columns, [(5, 25)], 30, False)
        local_slope = wl.max_abs_local_slope(columns, [(5, 25)], 30, wet_only=False)
        self.assertAlmostEqual(global_slope, 0.0, places=12)
        self.assertGreater(local_slope, 0.05)

    def test_hill_sideband_excludes_peak(self):
        columns = [0] * 41
        for x in range(5, 36):
            columns[x] = 10 * wl.MASS_MAX
        columns[20] += 2 * wl.MASS_MAX
        amplitude, width = wl.hill_metrics(columns, [(5, 35)], 40)
        self.assertAlmostEqual(amplitude, 2.0, places=9)
        self.assertEqual(width, 1)

    def test_wet_dry_cliff_is_leveling_not_internal(self):
        columns = [0, 2 * wl.MASS_MAX, 3 * wl.MASS_MAX]
        internal, leveling = wl.cliff_counts(columns, [(0, 2)])
        self.assertIn(0, leveling)
        self.assertNotIn(0, internal)
        self.assertNotIn(1, leveling)  # exactly one cell is not > one-cell threshold

    def test_internal_cliff(self):
        columns = [wl.MASS_MAX, 2 * wl.MASS_MAX + 1]
        internal, leveling = wl.cliff_counts(columns, [(0, 1)])
        self.assertEqual(internal, {0})
        self.assertEqual(leveling, {0})

    def test_terrace_is_quarter_cell_classified_and_severe(self):
        columns = [0] * 20
        for x in range(2, 8):
            columns[x] = 10 * wl.MASS_MAX
        for x in range(8, 14):
            columns[x] = 10 * wl.MASS_MAX + 128
        count, total, largest, step, severe, edges = wl.terrace_metrics(columns, [(2, 13)], 30)
        self.assertEqual(count, 2)
        self.assertEqual(total, 12)
        self.assertEqual(largest, 6)
        self.assertGreaterEqual(step, 0.5)
        self.assertTrue(severe)
        self.assertIn(7, edges)

    def test_persistence_reports_start_tick_not_completion_tick(self):
        values = [1.0] * 5 + [0.4] * 60 + [1.0]
        self.assertEqual(wl.persistent_first(values, lambda v: v <= 0.5, 60), 5)

    def test_calm_mound_is_not_flat_when_dry_columns_are_in_leveling_roi(self):
        columns = [0] * 128
        for x in range(40, 80):
            columns[x] = 48 * wl.MASS_MAX
        row = {
            "tick": 0,
            "quantity": 40 * 48 * wl.MASS_MAX,
            "columns": columns,
            "downstream": 0,
            "min_wet_x": 40,
            "max_wet_x": 79,
        }
        metric = wl.metric_rows("cs", [row])[0]
        self.assertFalse(metric["flat_conditions"])
        self.assertGreater(metric["local_leveling_slope"], 0.0)

    def test_cs_surface_phase_waits_for_sixty_stable_span_ticks(self):
        rows = []
        for tick in range(70):
            columns = [10 * wl.MASS_MAX] * 128
            if tick < 5:
                columns[1] = 15 * wl.MASS_MAX
            rows.append({"tick": tick, "columns": columns})
        self.assertEqual(wl.surface_phase_start("cs", rows), 5)

    def test_fd_surface_phase_starts_on_terminal_contact(self):
        rows = []
        for tick in range(6):
            columns = [0] * 128
            if tick >= 4:
                columns[126] = wl.MASS_MAX
            rows.append({"tick": tick, "columns": columns})
        self.assertEqual(wl.surface_phase_start("fd", rows), 4)

    def test_ls_surface_phase_requires_sixty_fully_wet_ticks(self):
        rows = []
        for tick in range(66):
            columns = [0] * 128
            if tick >= 3:
                for x in range(68, 124):
                    columns[x] = wl.MASS_MAX
            rows.append({"tick": tick, "columns": columns})
        self.assertEqual(wl.surface_phase_start("ls", rows), 3)

    def test_qualified_terrace_edges_ignore_short_run_pair(self):
        columns = [0] * 12
        columns[2:4] = [10 * wl.MASS_MAX] * 2
        columns[4:6] = [11 * wl.MASS_MAX] * 2
        count, _, _, _, _, edges = wl.terrace_metrics(columns, [(2, 5)], 30)
        self.assertEqual(count, 0)
        self.assertEqual(edges, set())

        columns[2:5] = [10 * wl.MASS_MAX] * 3
        columns[5:7] = [11 * wl.MASS_MAX] * 2
        count, _, _, _, _, edges = wl.terrace_metrics(columns, [(2, 6)], 30)
        self.assertEqual(count, 1)
        self.assertEqual(edges, {4})

    def test_surface_l1_is_cell_equivalent_quantity_motion(self):
        before = [0, wl.MASS_MAX, 2 * wl.MASS_MAX, 0]
        after = [0, 2 * wl.MASS_MAX, wl.MASS_MAX, 0]
        self.assertAlmostEqual(
            wl.surface_l1_cell_equivalents(before, after, [(1, 2)]),
            2.0,
        )

    def test_equal_communicating_arms_meet_registered_difference(self):
        columns = [0] * 128
        for x in range(8, 56):
            columns[x] = 20 * wl.MASS_MAX
        for x in range(72, 120):
            columns[x] = 20 * wl.MASS_MAX
        quantity = sum(columns)
        row = {
            "tick": 0,
            "quantity": quantity,
            "columns": columns,
            "left": 48 * 20 * wl.MASS_MAX,
            "right": 48 * 20 * wl.MASS_MAX,
            "min_wet_x": 8,
            "max_wet_x": 119,
        }
        metric = wl.metric_rows("cp16", [row])[0]
        self.assertAlmostEqual(metric["arm_difference"], 0.0)
        self.assertTrue(metric["flat_conditions"])


if __name__ == "__main__":
    unittest.main()
