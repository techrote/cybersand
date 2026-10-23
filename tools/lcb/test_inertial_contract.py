"""Regressions for the standalone `inertial-update-v1` contract oracle.

These test the Proposed #212 update rule on static neighbourhoods. They do not
execute a World, a scheduler or an inertial family.
"""
from __future__ import annotations

import itertools
import unittest

import inertial_contract as ic

P = ic.Params()


def run(name):
    return ic.example(name)


class WorkedExamples(unittest.TestCase):
    def test_every_example_closes(self):
        for name in ic.EXAMPLES:
            self.assertTrue(run(name)["ledger_closes"], name)

    def test_deflect_right_and_left_are_mirrors(self):
        right, left = run("deflect-right"), run("deflect-left")
        self.assertEqual((right["end"]["vx"], right["end"]["vy"], right["end"]["ax"]), (23, 0, 7))
        self.assertEqual((left["end"]["vx"], left["end"]["vy"], left["end"]["ax"]), (-23, 0, -7))
        self.assertEqual(right["moves"], [(3, 1)])
        self.assertEqual(left["moves"], [(1, 1)])
        deflect = [e for e in right["entries"] if e["stage"] == "deflect"][0]
        self.assertEqual((deflect["jx"], deflect["jy"], deflect["loss"]), (24, -32, 8))

    def test_damping_negative_velocity_is_a_signed_positive_impulse(self):
        e = run("damp-negative-vx")
        damping = [x for x in e["entries"] if x["stage"] == "damping"][0]
        self.assertEqual((damping["jx"], damping["loss"], damping["remainder"]), (2, 2, -8))
        self.assertEqual((e["end"]["vx"], e["end"]["ax"], e["end"]["x"]), (-38, -6, 0))

    def test_supported_rest_with_free_side_stays_exactly_zero(self):
        e = run("supported-rest-free-side")
        self.assertEqual((e["end"]["vx"], e["end"]["vy"], e["end"]["ax"], e["end"]["ay"]), (0, 0, 0, 0))
        self.assertEqual(e["moves"], [])
        self.assertTrue(e["sleep_eligible"])
        self.assertEqual([x["stage"] for x in e["entries"]], ["gravity", "support"])

    def test_blocked_same_family_is_inelastic_contact(self):
        e = run("blocked-same-family")
        contact = [x for x in e["entries"] if x["stage"] == "contact"][0]
        self.assertEqual((contact["jy"], contact["loss"]), (-20, 20))
        self.assertEqual((e["end"]["vx"], e["end"]["vy"]), (0, 0))
        self.assertTrue(e["sleep_eligible"])

    def test_wall_body_mask_and_same_family_share_one_contact_rule(self):
        self.assertEqual(run("body-mask-landing")["end"], run("deflect-right")["end"])
        for blocker in (ic.WALL, ic.MASK, ic.SAME):
            res = ic.update(ic.Grid(["#####", "##W..", "##" + blocker + "##"]), ic.Cell(2, 1, 0, 32))
            self.assertEqual((res.cell.vx, res.cell.vy), (23, 0), blocker)

    def test_reaim_from_rest_gains_only_gravity_along_the_diagonal(self):
        e = run("reaim-from-rest")
        self.assertEqual((e["end"]["vx"], e["end"]["vy"]), (2, 2))
        self.assertEqual(e["end"]["vx"] + e["end"]["vy"], P.gravity)

    def test_reaim_carried_speed_minus_turn_loss(self):
        e = run("reaim-carried")
        reaim = [x for x in e["entries"] if x["stage"] == "reaim"][0]
        self.assertEqual((reaim["jx"], reaim["jy"], reaim["loss"], reaim["remainder"]), (19, -24, 5, 4))
        self.assertEqual(e["moves"], [(3, 2)])  # one diagonal move (N1: no split into axis substeps)


def deflect_entry(rows, vx):
    res = ic.update(ic.Grid(rows), ic.Cell(2, 1, vx, 32))
    return res, [e for e in res.entries if e.stage == "deflect"][0]


class DeflectionLossN2(unittest.TestCase):
    """U3b deflection, checked against independently computed values (re-review N2)."""

    RIGHT_FREE, LEFT_FREE = ["#####", "##W..", "#####"], ["#####", "..W##", "#####"]

    def test_review_counterexample_opposing_vx(self):
        res, d = deflect_entry(self.LEFT_FREE, 40)
        # (40, 32) -> (16, 0): impulses (-24, -32); L1 loss 72 - 16 = 56, not vy_in - d = 8.
        self.assertEqual((d.jx, d.jy, d.loss), (-24, -32, 56))
        self.assertEqual((res.cell.vx, res.cell.vy), (15, 0))  # after damping -1

    def test_hand_computed_registered_examples(self):
        expected = {  # name: (deflect jx, jy, loss), end (x, y, vx, vy, ax, ay)
            "deflect-right-aligned-vx": ((24, -32, 8), (4, 1, 32, 0, 0, 0)),
            "deflect-right-opposing-vx": ((24, -32, 28), (2, 1, 14, 0, 14, 0)),
            "deflect-left-aligned-vx": ((-24, -32, 8), (0, 1, -32, 0, 0, 0)),
            "deflect-left-opposing-vx": ((-24, -32, 56), (2, 1, 15, 0, 15, 0)),
        }
        for name, (entry, end) in expected.items():
            e = run(name)
            d = [x for x in e["entries"] if x["stage"] == "deflect"][0]
            self.assertEqual((d["jx"], d["jy"], d["loss"]), entry, name)
            self.assertEqual(tuple(e["end"][k] for k in ("x", "y", "vx", "vy", "ax", "ay")), end, name)

    def test_general_formula_both_sides_and_signs(self):
        for rows, s in ((self.RIGHT_FREE, 1), (self.LEFT_FREE, -1)):
            for vx in (-40, -24, -10, -1, 0, 1, 10, 24, 40):
                for vy_in in (1, 7, 32, 60):
                    res = ic.update(ic.Grid(rows), ic.Cell(2, 1, vx, vy_in))
                    d = [e for e in res.entries if e.stage == "deflect"][0]
                    mag = vy_in * 3 // 4
                    self.assertEqual((d.jx, d.jy), (s * mag, -vy_in), (s, vx, vy_in))
                    self.assertEqual(d.loss, abs(vx) + vy_in - abs(vx + s * mag), (s, vx, vy_in))
                    self.assertGreaterEqual(d.loss, 0)
                    self.assertEqual(sum(e.stage == "gravity" for e in res.entries), 1)
                    stages = [e.stage for e in res.entries]
                    self.assertLess(stages.index("support"), stages.index("deflect"))

    def test_native_rest_registration_is_qualified(self):
        # Re-review R5: the generated #212 registration must not demand rest when U3a may re-aim.
        import physics_contracts
        contract = [c for c in physics_contracts.contracts(physics_contracts.fixtures())["contracts"]
                    if c["id"] == "inertial-update"][0]
        rest = [r for r in contract["native_registrations_for_212"] if "initially at rest" in r]
        self.assertTrue(any("both diagonals blocked" in r for r in rest), rest)
        self.assertTrue(any("eligible diagonal re-aims" in r for r in rest), rest)
        self.assertIn("static closed pool keeps every velocity exactly 0 (mandatory)",
                      contract["native_registrations_for_212"])
        self.assertFalse(any("supported cell with a free side keep" in r
                             for r in contract["native_registrations_for_212"]))
        # The reviewer's case: support below, a free side and an eligible diagonal re-aims from rest.
        res = ic.update(ic.Grid(["#####", "#.W..", "###.."]), ic.Cell(2, 1, 0, 0))
        self.assertEqual((res.cell.vx, res.cell.vy), (2, 2))

    def test_rest_qualification_reaim_is_intentional(self):
        # Diagonally blocked support: rest never drifts. An enterable diagonal re-aims from rest (U3a).
        self.assertEqual(run("supported-rest-free-side")["end"]["vx"], 0)
        self.assertEqual(run("reaim-from-rest")["end"]["vx"], 2)


class DirectionalEligibilityN1(unittest.TestCase):
    """A lighter foreign liquid is entered only by a move with dy = +1 (re-review N1)."""

    def test_review_counterexample_no_horizontal_swap(self):
        e = run("no-horizontal-swap")
        self.assertEqual(e["moves"], [])
        self.assertEqual(e["swaps"], [])
        self.assertEqual((e["end"]["x"], e["end"]["vx"]), (1, 0))
        self.assertFalse(any(x["stage"] == "drag" for x in e["entries"]))
        contact = [x for x in e["entries"] if x["stage"] == "contact"][0]
        self.assertEqual((contact["jx"], contact["loss"]), (-19, 19))

    def test_horizontal_lighter_contact_equals_wall_mask_same(self):
        ends = {}
        for blocker in (ic.LIGHTER, ic.WALL, ic.MASK, ic.SAME):
            res = ic.update(ic.Grid(["#####", "#W" + blocker + ".#", "#####"]), ic.Cell(1, 1, 20, 0))
            ends[blocker] = (vars(res.cell), [(e.stage, e.jx, e.jy, e.loss) for e in res.entries])
        self.assertEqual(len({str(v) for v in ends.values()}), 1, ends)

    def test_no_deflection_into_lighter_side(self):
        e = run("no-deflection-into-lighter")
        self.assertEqual((e["end"]["vx"], e["end"]["vy"]), (0, 0))
        self.assertEqual([x["stage"] for x in e["entries"]], ["gravity", "support", "contact"])

    def test_vertical_and_diagonal_down_swaps_are_permitted(self):
        self.assertEqual(run("drag-density-swap")["swaps"], [(0, 1)])
        e = run("reaim-diagonal-into-lighter")
        self.assertEqual((e["swaps"], e["moves"]), ([(1, 1)], [(3, 2)]))
        drag = [x for x in e["entries"] if x["stage"] == "drag"][0]
        self.assertEqual((drag["jx"], drag["jy"], drag["loss"]), (-4, -4, 8))

    def test_lighter_below_is_not_support(self):
        res = ic.update(ic.Grid([".....", "..W..", "..o..", "#####"]), ic.Cell(2, 1, 0, 0))
        self.assertFalse(any(e.stage == "support" for e in res.entries))

    def test_corner_falling_cell_never_swaps_sideways(self):
        # Falling cell whose DDA first wants a horizontal-only substep (nx=2, ny=1): the
        # lighter neighbour is a horizontal contact, never a sideways swap.
        res = ic.update(ic.Grid(["######", "#Wo..#", "#....#", "######"]), ic.Cell(1, 1, 40, 20))
        self.assertEqual((res.swaps, res.moves), ([], []))
        self.assertEqual((res.cell.vx, res.cell.vy), (0, 23))
        # The same history with the lighter cell on the true diagonal-down target swaps.
        res = ic.update(ic.Grid(["######", "#W...#", "#..o.#", "######"]), ic.Cell(1, 1, 40, 20))
        self.assertEqual((res.swaps, res.moves), ([(1, 1)], [(2, 1), (3, 2)]))

    def test_saturation_and_travel_bounds(self):
        e = run("saturate-free-fall")
        sat = [x for x in e["entries"] if x["stage"] == "saturate"][0]
        self.assertEqual((sat["jy"], sat["loss"]), (-2, 2))
        self.assertEqual((e["end"]["vy"], e["end"]["ay"], len(e["moves"])), (60, 11, 4))

    def test_contact_mid_travel_ends_travel_and_zeroes_normal(self):
        e = run("contact-mid-travel")
        self.assertEqual(e["moves"], [(1, 1)])
        self.assertEqual((e["end"]["vx"], e["end"]["ax"]), (0, 0))

    def test_density_swap_drag(self):
        e = run("drag-density-swap")
        drag = [x for x in e["entries"] if x["stage"] == "drag"][0]
        self.assertEqual((drag["jy"], drag["loss"], drag["remainder"]), (-5, 5, 3))


class Invariants(unittest.TestCase):
    """Exhaustive 3x3 neighbourhoods (Empty/Wall/Lighter) over a velocity grid."""

    def test_sweep(self):
        alphabet = (ic.EMPTY, ic.WALL, ic.LIGHTER)
        cases = 0
        for ring in itertools.product(alphabet, repeat=8):
            rows = ["".join(ring[0:3]), ring[3] + ic.SAME + ring[4], "".join(ring[5:8])]
            probe = ic.Grid(rows)
            below_blocked = not probe.enterable(1, 1, 0, 1)
            diag_blocked = not probe.enterable(1, 1, -1, 1) and not probe.enterable(1, 1, 1, 1)
            for vx, vy, ax, ay in itertools.product((-40, -1, 0, 1, 40), (0, 1, 32, 64), (0, -15, 15), (0, 15)):
                start = ic.Cell(1, 1, vx, vy, ax, ay)
                res = ic.update(ic.Grid(rows), start)
                c = res.cell
                cases += 1
                key = (rows, vx, vy, ax, ay)
                self.assertTrue(ic.ledger_closes(start, res), key)
                self.assertTrue(abs(c.vx) <= P.vmax and 0 <= c.vy <= P.vmax, key)
                self.assertTrue(abs(c.ax) < P.q and abs(c.ay) < P.q, key)
                self.assertLessEqual(len(res.moves), 2 * (P.vmax // P.q), key)
                self.assertTrue(all(dy == 1 for _, dy in res.swaps), key)  # N1: never a sideways swap
                path = [(1, 1)] + res.moves
                for (x0, y0), (x1, y1) in zip(path, path[1:]):
                    if rows[y1][x1] == ic.LIGHTER if 0 <= y1 < 3 and 0 <= x1 < 3 else False:
                        self.assertEqual(y1 - y0, 1, key)
                stages = {e.stage for e in res.entries}
                if vx == 0 and c.vx != 0:
                    self.assertTrue(stages & {"reaim", "deflect"}, key)
                if below_blocked and diag_blocked and vx == 0 and vy == 0:
                    self.assertEqual((c.vx, c.vy, res.moves), (0, 0, []), key)
                    if ax == 0 and ay == 0:
                        self.assertTrue(res.sleep_eligible, key)
                self.assertEqual(sum(e.stage == "gravity" for e in res.entries), 1, key)
        self.assertEqual(cases, 3 ** 8 * 5 * 4 * 3 * 2)


class Registry(unittest.TestCase):
    def test_registry_examples_are_current(self):
        data = ic.registry()
        self.assertEqual(data["rule"], "inertial-update-v1")
        self.assertEqual([e["name"] for e in data["examples"]], list(ic.EXAMPLES))
        self.assertTrue(all(e["ledger_closes"] for e in data["examples"]))


if __name__ == "__main__":
    unittest.main()
