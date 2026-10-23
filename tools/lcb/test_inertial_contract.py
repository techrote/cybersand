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
        self.assertEqual(e["moves"], [(3, 1), (3, 2)])

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
            below_blocked = ring[6] not in ic.ENTERABLE
            diag_blocked = ring[5] not in ic.ENTERABLE and ring[7] not in ic.ENTERABLE
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
