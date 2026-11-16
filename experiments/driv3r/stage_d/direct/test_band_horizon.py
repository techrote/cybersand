"""No-model tests: selected-wall band feasibility is stricter than endpoint reach."""
import copy
import unittest

from experiments.driv3r.stage_d.direct import band_horizon as b


class BandHorizonTests(unittest.TestCase):
    def test_swept_band_exit_and_reentry_inside_one_eight_cell_macro(self):
        # Both endpoints are in-band; two intermediate swept cells are not.
        sweep = [[(x, 1) for x in range(1, 9)]]
        observed = b.scan_swept_band_transitions(
            (0, 1), sweep, lambda p: 11.0 if p[0] in (3, 4) else 8.0)
        self.assertEqual(observed["swept_band_exits"], 1)
        self.assertEqual(observed["swept_band_reentries"], 1)
        self.assertEqual(observed["swept_out_of_band_cells"], 2)
        self.assertEqual(observed["first_swept_band_exit"],
                         {"decision_index": 0, "swept_step_in_decision": 3})
        self.assertEqual(observed["first_swept_band_reentry"],
                         {"decision_index": 0, "swept_step_in_decision": 5})
        self.assertEqual(observed["per_decision"][0]["swept_band_exits"], 1)

    def test_swept_band_transitions_across_decisions_and_stop(self):
        observed = b.scan_swept_band_transitions(
            (0, 0), [[(1, 0), (2, 0)], [], [(3, 0), (4, 0)]],
            lambda p: 11 if p[0] in (2, 3) else 8)
        self.assertEqual(observed["swept_band_exits"], 1)
        self.assertEqual(observed["swept_band_reentries"], 1)
        self.assertEqual(observed["per_decision"][1]["swept_band_exits"], 0)
        self.assertEqual(observed["first_swept_band_reentry"]["decision_index"], 2)

    def test_swept_band_rejects_nonfinite_clearance(self):
        self.assertEqual(b.scan_swept_band_transitions(
            (0, 0), [[]], lambda p: 8)["swept_band_exits"], 0)
        with self.assertRaises(ValueError):
            b.scan_swept_band_transitions((0, 0), [], lambda p: float("nan"))
        with self.assertRaises(ValueError):
            b.scan_swept_band_transitions((0, 0), [], lambda p: True)

    def test_unblocked_band_accepts_eight_cell_macro(self):
        distances = b.exact_band_decisions(
            9, 3, (8, 1), lambda p: True,
            lambda p: 8.0 if p[1] == 1 else 11.0, (1, 2, 4, 8))
        self.assertEqual(distances[(0, 1)], 1)
        self.assertEqual(distances[(8, 1)], 0)
        self.assertNotIn((0, 0), distances)

    def test_legal_detour_outside_selected_band_is_not_band_completion(self):
        legal = lambda p: p != (3, 1)
        distance = lambda p: 8.0 if p[1] == 1 else 11.0
        unrestricted = b.horizon.exact_remaining_decisions(
            7, 3, (6, 1), legal, (1, 2, 4, 8))
        restricted = b.exact_band_decisions(
            7, 3, (6, 1), legal, distance, (1, 2, 4, 8))
        self.assertIn((0, 1), unrestricted)
        self.assertNotIn((0, 1), restricted)

    def test_macro_cannot_skip_single_out_of_band_cell(self):
        distance = lambda p: 11.0 if p[1] != 1 or p == (4, 1) else 8.0
        restricted = b.exact_band_decisions(
            9, 1 + 1, (8, 1), lambda p: True, distance,
            (1, 2, 4, 8))
        self.assertNotIn((0, 1), restricted)
        self.assertNotIn((4, 1), restricted)

    def test_type_exact_host_legal_and_finite_clearance(self):
        with self.assertRaises(ValueError):
            b.exact_band_decisions(4, 1, (3, 0), lambda p: "ALLOW",
                                   lambda p: 8.0)
        with self.assertRaises(ValueError):
            b.exact_band_decisions(4, 1, (3, 0), lambda p: True,
                                   lambda p: float("nan"))
        with self.assertRaises(ValueError):
            b.exact_band_decisions(4, 1, (3, 0), lambda p: True,
                                   lambda p: True)
        with self.assertRaises(ValueError):
            b.exact_band_decisions(4, 1, (3, 0), lambda p: True,
                                   lambda p: 11.0)

    def test_development_original_replay_retains_receipt_and_stop_boundaries(self):
        from experiments.driv3r.stage_d.direct import offline as d
        fixture = d.wall_fixture("step", "development")
        for policy in ("contour_astar", "random_legal"):
            with self.subTest(policy=policy):
                record = d.run_episode(fixture, policy, seed=23)
                result = b.audit_development_band_horizon(fixture, record)
                self.assertEqual(result["fixture_sha256"], fixture.sha256)
                self.assertEqual(result["original_arrived"],
                                 record["metrics"]["arrived"])
                self.assertEqual(result["original_stop_reason"],
                                 record["metrics"]["stop_reason"])
                self.assertEqual(len(result["decision_horizons"]),
                                 len(record["events"]))
                self.assertTrue(result["initial_cursor_within_selected_band"])
                self.assertEqual(
                    sum(row["original_swept_band_transitions"]["swept_band_exits"]
                        for row in result["decision_horizons"]),
                    result["swept_band_exit_count"])
                self.assertEqual(
                    sum(row["original_swept_band_transitions"]["swept_out_of_band_cells"]
                        for row in result["decision_horizons"]),
                    result["swept_out_of_band_cells"])
                self.assertFalse(result["native_qualified"])
                self.assertEqual(result["sequential_native_receipts"], 0)
                for row in result["decision_horizons"]:
                    if not row["original_prefix_entirely_in_band"]:
                        self.assertFalse(row[
                            "hypothetical_continuous_band_completion_preserving_prefix"])

    def test_heldout_and_tampered_evidence_fail_closed(self):
        from experiments.driv3r.stage_d.direct import offline as d
        heldout = d.wall_fixture("switchback", "heldout")
        with self.assertRaises(ValueError):
            b.audit_development_band_horizon(heldout, {})
        dev = d.wall_fixture("step", "development")
        record = d.run_episode(dev, "contour_astar")
        forged = copy.deepcopy(record)
        forged["events"][0]["choice_id"] = "STOP"
        with self.assertRaises(ValueError):
            b.audit_development_band_horizon(dev, forged)



class MonotoneBandHorizonTests(unittest.TestCase):
    def test_downgoing_detour_is_legal_band_but_not_monotone(self):
        legal = lambda p: p != (2, 1)
        clearance = lambda p: 8.0
        strict = b.exact_band_decisions(
            5, 3, (4, 1), legal, clearance, (1, 2, 4))
        monotone = b.exact_monotone_band_decisions(
            5, 3, (4, 1), legal, clearance, (1, 2, 4))
        self.assertIn((0, 1), strict)
        self.assertNotIn((0, 1), monotone)
        self.assertEqual(monotone[(4, 1)], 0)

    def test_open_selected_band_with_macro_and_forward_y(self):
        clearance = lambda p: 8.0 if p[1] in (1, 2) else 11.0
        results = b.exact_monotone_band_decisions(
            9, 3, (8, 2), lambda p: True,
            clearance, (1, 2, 4, 8))
        self.assertEqual(results[(0, 2)], 1)
        self.assertEqual(results[(0, 1)], 2)
        self.assertNotIn((0, 0), results)
        self.assertNotIn((8, 0), results)

    def test_independent_seeded_forward_search_matches_reverse_oracle(self):
        from collections import deque
        from random import Random

        def independent_forward(start, goal, width, height, legal, lengths):
            if not legal(start):
                return None
            queue = deque([(start, 0)])
            seen = {start}
            while queue:
                point, cost = queue.popleft()
                if point == goal:
                    return cost
                for dx, dy in ((1, 0), (-1, 0), (0, 1)):
                    for length in range(1, max(lengths) + 1):
                        end = (point[0] + dx * length, point[1] + dy * length)
                        if not (0 <= end[0] < width and
                                0 <= end[1] < height and legal(end)):
                            break
                        if length in lengths and end not in seen:
                            seen.add(end)
                            queue.append((end, cost + 1))
            return None

        rng = Random(570)
        comparisons = 0
        for case in range(24):
            width, height = 6, 5
            blocked = {(x, y) for x in range(width) for y in range(height)
                       if rng.random() < 0.17}
            goal = (rng.randrange(width), rng.randrange(height))
            blocked.discard(goal)
            legal = lambda p: p not in blocked
            lengths = (1,) if case % 2 else (1, 2, 4, 8)
            measured = b.exact_monotone_band_decisions(
                width, height, goal, legal, lambda p: 8.0, lengths)
            for y in range(height):
                for x in range(width):
                    start = (x, y)
                    expected = independent_forward(
                        start, goal, width, height, legal, lengths)
                    self.assertEqual(measured.get(start), expected,
                                     (case, start, goal, lengths))
                    comparisons += 1
        self.assertEqual(comparisons, 720)

    def test_replayed_development_ablation_preserves_original_terminal(self):
        from experiments.driv3r.stage_d.direct import offline as d
        fixture = d.wall_fixture("step", "development")
        episode = d.run_episode(fixture, "contour_astar", seed=3)
        report = b.audit_development_monotone_band_horizon(fixture, episode)
        self.assertEqual(report["fixture_sha256"], fixture.sha256)
        self.assertEqual(report["original_arrived"], episode["metrics"]["arrived"])
        self.assertEqual(report["original_stop_reason"],
                         episode["metrics"]["stop_reason"])
        self.assertEqual(len(report["decision_horizons"]),
                         len(episode["events"]))
        self.assertFalse(report["native_qualified"])
        self.assertFalse(report["model_evaluated"])
        self.assertEqual(report["sequential_native_receipts"], 0)
        for row in report["decision_horizons"]:
            if not row["original_prefix_nondecreasing_y"]:
                self.assertFalse(
                    row["original_prefix_preserving_monotone_completion"])

    def test_heldout_and_original_receipt_tamper_remain_sealed(self):
        from experiments.driv3r.stage_d.direct import offline as d
        with self.assertRaises(ValueError):
            b.audit_development_monotone_band_horizon(
                d.wall_fixture("switchback", "heldout"), {})
        fixture = d.wall_fixture("step", "development")
        episode = d.run_episode(fixture, "astar")
        forged = copy.deepcopy(episode)
        forged["metrics"]["native_receipts"] = 1
        with self.assertRaises(ValueError):
            b.audit_development_monotone_band_horizon(fixture, forged)


if __name__ == "__main__":
    unittest.main()
