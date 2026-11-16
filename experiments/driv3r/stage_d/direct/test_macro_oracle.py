"""Pure offline tests, no held-out dispatch or real native controller."""
import unittest
from experiments.driv3r.stage_d.direct.macro_oracle import reverse_lexicographic_plan, trace_planned_route

class MacroOracleTests(unittest.TestCase):
    def test_straight_macro_uses_minimum_decisions(self):
        plan = reverse_lexicographic_plan(20, 8, (15, 3), lambda p: True)
        report = trace_planned_route((1, 3), (15, 3), plan)
        self.assertEqual(len(report['decisions']), 3)
        self.assertEqual(len(report['cursor_path']), 15)
        self.assertTrue(report['arrived_in_hypothetical_plan'])
        self.assertFalse(report['native_qualified'])

    def test_blocked_intermediate_cell_forbids_jump(self):
        blocked = {(3, 2)}
        plan = reverse_lexicographic_plan(8, 5, (6, 2), lambda p: p not in blocked)
        report = trace_planned_route((1, 2), (6, 2), plan)
        self.assertTrue(report['arrived_in_hypothetical_plan'])
        self.assertNotIn([3, 2], report['cursor_path'])
        self.assertGreater(len(report['cursor_path'])-1, 5)

    def test_cannot_cross_barrier(self):
        barrier = {(3, y) for y in range(5)}
        plan = reverse_lexicographic_plan(8, 5, (6, 2), lambda p: p not in barrier)
        self.assertNotIn((1, 2), plan)
        report = trace_planned_route((1, 2), (6, 2), plan)
        self.assertFalse(report['arrived_in_hypothetical_plan'])

    def test_wall_prefers_staying_in_band_even_if_detour(self):
        clearance = lambda p: abs(p[0] - 2)
        plan = reverse_lexicographic_plan(20, 18, (10, 14), lambda p: True,
                                           selected_clearance=clearance)
        route = trace_planned_route((10, 2), (10, 14), plan)
        self.assertTrue(route['arrived_in_hypothetical_plan'])
        self.assertTrue(all(6 <= clearance(tuple(p)) <= 10 for p in route['cursor_path']))

    def test_callback_and_macro_menu_adversarial_refusals(self):
        for lengths in ((8,), (2,1), (1,1), (1,3), (1,True), ()):
            with self.subTest(lengths=lengths), self.assertRaises(ValueError):
                reverse_lexicographic_plan(8,8,(7,7),lambda p: True,lengths)
        with self.assertRaises(ValueError):
            reverse_lexicographic_plan(8,8,(7,7),lambda p: 1)
        with self.assertRaises(ValueError):
            reverse_lexicographic_plan(8,8,(7,7),lambda p: True,
                                        selected_clearance=lambda p: float('nan'))


    def test_reject_forged_macro_footprint(self):
        fake = {(1, 1): ((1, 0, 1, 2), 'E2', ((0,1), (-1,1)))}
        with self.assertRaisesRegex(AssertionError, 'Claimed cardinal macro'):
            trace_planned_route((1,1),(-1,1),fake)

    def test_budget_does_not_upgrade_incomplete_to_success(self):
        plan = reverse_lexicographic_plan(50, 3, (49, 1), lambda p: True, (1,))
        report = trace_planned_route((0, 1), (49, 1), plan, max_decisions=36)
        self.assertFalse(report['arrived_in_hypothetical_plan'])
        self.assertTrue(report['decision_budget_exhausted'])
        self.assertEqual(len(report['decisions']),36)

if __name__ == '__main__':
    unittest.main()
