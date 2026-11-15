"""No-model tests: selected-wall band feasibility is stricter than endpoint reach."""
import copy
import unittest

from experiments.driv3r.stage_d.direct import band_horizon as b


class BandHorizonTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
