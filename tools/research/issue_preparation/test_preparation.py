"""Tests for standalone preparation, never an engine acceptance suite."""
from __future__ import annotations
from collections import Counter
from dataclasses import FrozenInstanceError, replace
from fractions import Fraction
import json
import math
import unittest

from policy import WaterPolicy, PresentationPolicy, quantize, canonical_json, strict_json, lateral_pair, visible_level, projected_condition
from geometry import area, clip, intercept, normals
from transfer_model import State, Unit, CP, CA, P, PA, invariant, successors, explore
from precompute import balanced_orders, fixture


class PolicyTests(unittest.TestCase):
    def test_known_precision_thresholds(self):
        self.assertEqual([(WaterPolicy(mass_bits=b).film, WaterPolicy(mass_bits=b).tolerance)
                          for b in range(3, 9)], [(1, 0), (3, 0), (6, 0), (12, 0), (24, 0), (48, 1)])

    def test_rounding_exact_halves(self):
        for maximum in (7, 15, 31, 63, 127, 255, 1023):
            for k in range(maximum):
                self.assertEqual(quantize(2*k+1, 2*maximum, maximum), k+1)

    def test_quantizer_refusals(self):
        for args in ((1, 0, 255), (-1, 255, 255), (256, 255, 255), (1, 255, 0), (True, 2, 3), (1., 2, 3)):
            with self.assertRaises(ValueError):
                quantize(*args)

    def test_all_surfaces_resolve_identically(self):
        for bits in range(3, 9):
            for delay in range(13):
                for rest in ("normalized", "literal_one"):
                    ui = {"mass_bits": bits, "coherence_ticks": delay, "rest_policy": rest}
                    a = WaterPolicy.from_mapping(ui)
                    b = WaterPolicy.from_json(json.dumps(ui))
                    c = WaterPolicy.from_cli(["--water-mass-bits", str(bits), "--water-coherence", str(delay), "--water-rest", rest])
                    self.assertEqual(a, b)
                    self.assertEqual(a.identity(), c.identity())

    def test_strict_refusal(self):
        invalid = [{"mass_bits": v} for v in (2, 9, True, 4.0, "4", None)]
        invalid += [{"coherence_ticks": v} for v in (-1, 13, False, "7")]
        invalid += [{"schema": 2}, {"rest_policy": "magic"}, {"render_fill_levels": 4}]
        for mapping in invalid:
            with self.assertRaises(ValueError, msg=repr(mapping)):
                WaterPolicy.from_mapping(mapping)
        for text in ('{"mass_bits":4,"mass_bits":8}', '{"mass_bits":NaN}', '[]', 'null'):
            with self.assertRaises(ValueError):
                WaterPolicy.from_json(text)

    def test_immutable_and_failed_proposal_leaves_reference(self):
        current = WaterPolicy()
        original = current.identity()
        with self.assertRaises(FrozenInstanceError):
            current.mass_bits = 4
        with self.assertRaises(ValueError):
            WaterPolicy.from_mapping({"mass_bits": 99})
        self.assertEqual(current.identity(), original)

    def test_semantic_and_render_identity_separate(self):
        water = WaterPolicy()
        a = PresentationPolicy()
        b = replace(a, interface_mode="gravity")
        self.assertNotEqual(a.identity(), b.identity())
        self.assertEqual(water.identity(), WaterPolicy.from_json(canonical_json(water.record())).identity())
        self.assertNotEqual(water.identity(), replace(water, coherence_ticks=7).identity())

    def test_tiny_source_quantization_is_not_runtime_drift(self):
        self.assertEqual([quantize(1, 255, (1 << b)-1) for b in range(3, 9)], [0, 0, 0, 0, 0, 1])

    def test_pair_zero_request_edge(self):
        for bits in range(3, 9):
            self.assertEqual(lateral_pair(1, 0, WaterPolicy(mass_bits=bits)), (1, 0, 0))
            self.assertEqual(lateral_pair(2, 0, WaterPolicy(mass_bits=bits)), (1, 1, 1))

    def test_projection_endpoints_and_roundtrip(self):
        for bits in range(3, 9):
            policy = WaterPolicy(mass_bits=bits)
            self.assertEqual(projected_condition(0, policy), 0)
            self.assertEqual(projected_condition(policy.maximum, policy), 255)
            for mass in range(policy.maximum + 1):
                self.assertEqual(quantize(projected_condition(mass, policy), 255, policy.maximum), mass)

    def test_four_level_visibility_tradeoff(self):
        self.assertEqual(sum(visible_level(m, 255, "nearest") == 0 for m in range(1, 256)), 31)
        self.assertEqual(visible_level(1, 255, "positive_nearest") * 255, Fraction(255, 4))
        for method in ("nearest", "positive_nearest", "ceiling"):
            self.assertEqual(visible_level(0, 255, method), 0)
            self.assertEqual(visible_level(255, 255, method), 1)


class GeometryTests(unittest.TestCase):
    def test_axis_closed_form(self):
        for fraction in (0., .01, .25, .5, .75, .99, 1.):
            alpha = intercept(1, 0, fraction)
            self.assertAlmostEqual(alpha, fraction - .5, places=12)
            self.assertAlmostEqual(area(clip(1, 0, alpha)), fraction, places=12)

    def test_complement_and_rotation(self):
        for nx, ny in normals():
            for fraction in (0., .125, .25, .5, .75, .875, 1.):
                alpha = intercept(nx, ny, fraction)
                self.assertAlmostEqual(area(clip(nx, ny, alpha)), fraction, places=12)
                self.assertAlmostEqual(area(clip(-ny, nx, alpha)), fraction, places=12)
                self.assertAlmostEqual(area(clip(-nx, -ny, -alpha)), 1-fraction, places=12)

    def test_geometry_refusal(self):
        for args in ((0, 0, .5), (1, 0, -1), (1, 0, 2), (math.nan, 0, .5)):
            with self.assertRaises(ValueError):
                intercept(*args)

    def test_neighbor_mass_is_underdetermined(self):
        # Four half-filled cells admit opposing interfaces with equal fractions.
        left = clip(1, 0, intercept(1, 0, .5))
        right = clip(-1, 0, intercept(-1, 0, .5))
        self.assertAlmostEqual(area(left), area(right))
        self.assertNotEqual(left, right)


class ApparatusTests(unittest.TestCase):
    def test_balanced_orders(self):
        for n in (4, 6):
            rows = balanced_orders(n)
            for pos in range(n):
                self.assertEqual(Counter(row[pos] for row in rows), Counter(range(n)))
            pairs = Counter((a, b) for row in rows for a, b in zip(row, row[1:]))
            self.assertEqual(len(pairs), n*(n-1))
            self.assertEqual(set(pairs.values()), {1})

    def test_recipe_repeat_and_oracle_initial_mass(self):
        self.assertEqual(fixture("basin48"), fixture("basin48"))
        data = fixture("basin48")
        self.assertEqual(data["requested_initial_volume"], "384")
        self.assertEqual(data["initial_ledgers"][-1]["integer_quantity"], 97920)
        self.assertTrue(all(row["initial_quantization_error"] == "0" for row in data["initial_ledgers"]))

    def test_all_geometry_recipes(self):
        for name in ("basin48", "supported-film", "support-removal", "ledge", "tiny-inputs"):
            record = fixture(name)
            barriers = set(map(tuple, record["barriers"]))
            self.assertFalse({(p["x"], p["y"]) for p in record["water"]} & barriers)
            self.assertEqual(len(record["recipe_sha256"]), 64)


class ProtocolTests(unittest.TestCase):
    def test_reservation_has_no_second_material_owner(self):
        s = State(units=(replace(Unit(), phase=CP, ticket=0), Unit()))
        self.assertTrue(invariant(s, 1))
        self.assertFalse(any(action == "1:prepare_promotion" for action, _ in successors(s, 1)))

    def test_stale_commit_refused(self):
        s = State(units=(replace(Unit(), phase=CA, ticket=0, revision=1), Unit()))
        self.assertFalse(any(action == "0:commit_promotion" for action, _ in successors(s, 2)))

    def test_full_destination_preserves_pool(self):
        u = Unit(cell=False, pool=True, phase=P, destination_free=False)
        s = State(units=(u, Unit()))
        self.assertTrue(all(invariant(following, 2) for _, following in successors(s, 2)))
        self.assertFalse(any(action == "0:prepare_return" for action, _ in successors(s, 2)))

    def test_quarantine_has_no_automatic_retry(self):
        self.assertEqual(list(successors(State(failed=True), 2)), [])

    def test_four_mutants_have_short_counterexamples(self):
        for variant in ("early_release", "duplicate_owner", "drop_on_full", "stale_ack"):
            result = explore(2, variant, depth=6)
            self.assertTrue(result["counterexample"], variant)
            self.assertLessEqual(len(result["counterexample"]), 5)


if __name__ == "__main__":
    unittest.main()
