"""Controlled topology gates plus regression against the frozen live corpus."""
import copy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ejection_topology as topology


class EjectionTopologyTests(unittest.TestCase):
    def setUp(self):
        self.cases = topology.synthetic_cases()

    def analyze(self, name):
        return topology.analyze_capsule(self.cases[name])

    def set_row(self, capsule, point, row):
        left, top, width, _ = capsule["bounds"]
        capsule["cells"][(point[1] - top) * width + point[0] - left] = list(row)
        capsule["target"], capsule["trace"] = topology.production_replay(topology.Grid(capsule))

    def test_seven_registered_controls(self):
        expected = {"direct_forward_empty": (0, "forward"),
                    "one_movable_forward": (1, "forward"),
                    "lateral_void": (0, "lateral"),
                    "rear_only_void": (None, None),
                    "hard_wall": (None, None),
                    "foreign_body": (None, None),
                    "jammed": (None, None)}
        self.assertEqual(set(self.cases), set(expected))
        for name, (cost, sector) in expected.items():
            with self.subTest(name=name):
                result = self.analyze(name)
                self.assertEqual(result["minimum_cost"], cost)
                self.assertEqual(result["lowest_void"]["sector"] if result["lowest_void"] else None, sector)
                self.assertTrue(result["candidate_trace_differential"])
                self.assertTrue(result["nonmutation_verified"])

    def test_movable_between_source_and_enumerated_void_does_not_reject_production(self):
        result = self.analyze("one_movable_forward")
        self.assertTrue(result["production_success"])
        self.assertFalse(result["strict_empty_route"])
        self.assertTrue(result["permissive_movable_route"])
        self.assertEqual(result["minimum_cost"], 1)

    def test_rear_void_is_only_in_diagnostic_ring(self):
        result = self.analyze("rear_only_void")
        self.assertEqual(result["void_count"], 0)
        self.assertEqual(result["outer_ring_void_count"], 1)
        self.assertTrue(result["outer_ring_reachable_only"])
        self.assertEqual(result["lowest_outer_ring_void"]["sector"], "rear")
        self.assertFalse(result["lowest_outer_ring_void"]["production_enumerated"])

    def test_hard_foreign_and_jammed_remain_distinct(self):
        hard, foreign, jammed = (self.analyze(name) for name in ("hard_wall", "foreign_body", "jammed"))
        self.assertEqual(hard["refusal"], "barrier_separated")
        self.assertIn("hard", hard["disconnecting_barrier_classes"])
        self.assertEqual(foreign["refusal"], "barrier_separated")
        self.assertIn("foreign", foreign["disconnecting_barrier_classes"])
        self.assertEqual(jammed["refusal"], "no_interior_void")
        self.assertTrue(jammed["no_void_interior_or_ring"])

    def test_own_mask_can_be_diagnostic_transit_but_never_a_terminal_void(self):
        c = copy.deepcopy(self.cases["one_movable_forward"])
        self.set_row(c, (33, 32), (0, 0, 0, 200, 1, False, False, 0, "0000000000000000"))
        result = topology.analyze_capsule(c)
        self.assertEqual(result["minimum_cost"], 0)
        self.assertFalse(result["strict_empty_route"])
        self.assertEqual(result["lowest_void"]["cell"], [34, 32])
        self.assertNotIn([33, 32], [v["cell"] for v in result["voids"]])

    def test_immovable_predicate_is_an_impassable_graph_barrier(self):
        c = copy.deepcopy(self.cases["one_movable_forward"])
        # Abstract descriptor adversary, independent of the current catalogue.
        row = list(topology.Grid(c).row((33, 32)))
        row[6] = False
        self.set_row(c, (33, 32), row)
        result = topology.analyze_capsule(c)
        self.assertIsNone(result["minimum_cost"])
        self.assertIn("immovable", result["disconnecting_barrier_classes"])

    def test_cost_precedes_path_length_and_lowest_ties_use_y_then_x(self):
        c = copy.deepcopy(self.cases["one_movable_forward"])
        empty = (0, 0, 0, 200, 0, False, False, 0, "0000000000000000")
        for p in ((32, 31), (33, 31), (34, 31), (32, 33)):
            self.set_row(c, p, empty)
        grid = topology.Grid(c)
        distance, _ = topology.dijkstra(grid)
        self.assertEqual(distance[(34, 32)], (0, 4))
        self.assertEqual(topology.analyze_capsule(c)["lowest_void"]["cell"], [32, 31])

    def test_geometry_and_sector_boundaries(self):
        for vector, expected in (((1, 1), "forward"), ((0, 1), "lateral"), ((-1, 1), "lateral"), ((-1, 0), "rear")):
            c = copy.deepcopy(self.cases["direct_forward_empty"])
            grid = topology.Grid(c)
            p = (grid.source[0] + vector[0], grid.source[1] + vector[1])
            values = topology.void_geometry(grid, p, set(), set())
            self.assertEqual(values["sector"], expected)
            self.assertEqual(values["chebyshev_distance"], 1)
            self.assertAlmostEqual(values["euclidean_distance"], sum(x*x for x in vector)**.5)

    def test_frozen_live_corpus_trace_order_costs_and_nonmutation(self):
        path = Path(__file__).resolve().parents[2] / "docs/audits/physical-detachment-2026-10-31/stage-a-corpus.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        before = copy.deepcopy(data)
        first = topology.analyze_corpus(data)
        second = topology.analyze_corpus(data)
        self.assertEqual(first, second)
        self.assertEqual(data, before)
        self.assertEqual(first["unresolved"]["minimum_cost"], {"0": 2, "1": 1, "2": 0, "3": 6, "4+": 8, "unreachable": 47})
        self.assertEqual(first["unresolved"]["lowest_route_sector"], {"forward": 0, "lateral": 15, "rear": 2, "unreachable": 47})
        self.assertEqual(first["unresolved"]["ring_void_exists_without_interior_void"], 22)
        self.assertEqual(first["unresolved"]["outer_ring_reachable_only"], 21)
        self.assertEqual(first["unresolved"]["no_void_interior_or_ring"], 25)
        self.assertEqual(first["unresolved"]["contacts_with_enumerated_empty_void"], 0)
        self.assertEqual(first["unresolved"]["strict_empty_routes"], 0)
        self.assertEqual(first["unresolved"]["forward_or_lateral_cost_1_or_2"], 1)
        self.assertEqual(first["positive_controls"]["contacts"], 16)
        self.assertTrue(all(row["candidate_trace_differential"] for row in first["capsules"]))
        self.assertTrue(first["nonmutation_verified"])

    def test_refuses_incomplete_or_inaccurate_footprint_and_trace(self):
        c = copy.deepcopy(self.cases["direct_forward_empty"])
        c["cells"].pop()
        with self.assertRaisesRegex(ValueError, "incomplete"):
            topology.analyze_capsule(c)
        c = copy.deepcopy(self.cases["direct_forward_empty"])
        c["trace"][0][2] = "non_empty"
        with self.assertRaisesRegex(ValueError, "differential"):
            topology.analyze_capsule(c)


if __name__ == "__main__":
    unittest.main()
