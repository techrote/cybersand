"""Synthetic regressions for the signed campaign ledger (lcb-signed-ledger-v2).

These exercise the reducer only. They do not touch protected fixture bytes or
the retained 2026-10-23 controls file.
"""
from __future__ import annotations

import json
import unittest

import lcb_registry as reg


def run(cells, series, source=0, sink=0, species=None):
    checkpoints = [{"tick": t, "water_integer": w, **({"species": species[i]} if species else {})}
                   for i, (t, w) in enumerate(series)]
    ledger = {"initial_integer": series[0][1], "explicit_source": source, "explicit_sink": sink}
    return reg.signed_ledger({"cells": cells}, ledger, checkpoints)


SALT = {"water": 40, "salt": 40}


class ReactiveEscapeRemoved(unittest.TestCase):
    """Review counterexamples: Salt present, no explicit source/sink, initial 10,000."""

    def test_unexplained_gain_fails(self):
        r = run(SALT, [(0, 10000), (30, 10001)])
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")
        self.assertFalse(r["eligible_for_acceptance"])

    def test_large_loss_is_unverified_not_explained(self):
        r = run(SALT, [(0, 10000), (30, 1)])
        self.assertEqual(r["state"], "UNVERIFIED_REACTION_AMOUNT")
        self.assertFalse(r["eligible_for_acceptance"])

    def test_loss_beyond_dissolution_bound_fails(self):
        r = run({"water": 40, "salt": 1}, [(0, 10000), (30, 1)])
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")

    def test_gain_after_loss_fails(self):
        r = run(SALT, [(0, 10000), (30, 9000), (60, 9001)])
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")

    def test_sodium_is_never_an_explanation(self):
        for final in (10001, 1):
            r = run({"water": 40, "sodium": 4}, [(0, 10000), (30, final)])
            self.assertEqual(r["state"], "UNVERIFIED_REACTION_AMOUNT")
            self.assertFalse(r["eligible_for_acceptance"])

    def test_reactive_with_explicit_source_is_unverified(self):
        r = run(SALT, [(0, 10000), (30, 10100)], source=255)
        self.assertEqual(r["state"], "UNVERIFIED_REACTION_AMOUNT")


class SignedSpeciesLedger(unittest.TestCase):
    cells = {"water": 40, "salt": 40, "brine": 10, "oil": 5}

    def species(self, *rows):
        return [{"salt": s, "brine": b, "oil": o} for s, b, o in rows]

    def test_valid_signed_ledger_closes(self):
        r = run(self.cells, [(0, 10000), (30, 7450), (60, 7450)],
                species=self.species((40, 10, 5), (30, 30, 5), (30, 30, 5)))
        self.assertEqual(r["state"], "closed_signed_reaction_ledger")
        self.assertTrue(r["eligible_for_acceptance"])

    def test_partial_water_is_160_boundary_unverified(self):
        r = run(self.cells, [(0, 10000), (30, 8000)], species=self.species((40, 10, 5), (30, 30, 5)))
        self.assertEqual(r["state"], "UNVERIFIED_PARTIAL_WATER_160")
        self.assertFalse(r["eligible_for_acceptance"])

    def test_brine_mismatch_fails(self):
        r = run(self.cells, [(0, 10000), (30, 7450)], species=self.species((40, 10, 5), (30, 29, 5)))
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")

    def test_post_dissolution_change_fails(self):
        for late in (7451, 7449):
            r = run(self.cells, [(0, 10000), (30, 7450), (60, late)],
                    species=self.species((40, 10, 5), (30, 30, 5), (30, 30, 5)))
            self.assertEqual(r["state"], "OPEN_UNEXPLAINED", late)

    def test_water_outside_bounds_fails(self):
        for water in (10000 - 255 * 10 - 1, 10000 - 9):
            r = run(self.cells, [(0, 10000), (30, water)], species=self.species((40, 10, 5), (30, 30, 5)))
            self.assertEqual(r["state"], "OPEN_UNEXPLAINED", water)

    def test_other_species_must_be_constant(self):
        r = run(self.cells, [(0, 10000), (30, 7450)], species=self.species((40, 10, 5), (30, 30, 4)))
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")


class NonReactive(unittest.TestCase):
    def test_constant_closes_and_any_transient_fails(self):
        self.assertEqual(run({"water": 40}, [(0, 10000), (30, 10000)])["state"], "closed")
        for mid in (10001, 9999):
            self.assertEqual(run({"water": 40}, [(0, 10000), (30, mid), (60, 10000)])["state"], "OPEN_UNEXPLAINED")

    def test_explicit_source_closes_exactly(self):
        self.assertEqual(run({"water": 40}, [(0, 0), (30, 4080), (60, 80900)], source=80900)["state"], "closed")
        self.assertEqual(run({"water": 40}, [(0, 0), (60, 80901)], source=80900)["state"], "OPEN_UNEXPLAINED")
        self.assertEqual(run({"water": 40}, [(0, 0), (30, 90000), (60, 80900)], source=80900)["state"],
                         "OPEN_UNEXPLAINED")


class RetainedRecords(unittest.TestCase):
    def test_historical_controls_preserved_and_v2_current(self):
        controls = json.loads(reg.CONTROLS.read_text(encoding="utf-8"))
        states = {s: c["ledger"]["state"] for s, c in controls["cases"].items() if "ledger" in c}
        self.assertEqual(sorted(s for s, v in states.items() if v == "open_by_declared_reaction"),
                         ["lcb.granular.salt-dissolution.v1", "lcb.mixed.sodium-oil-fire.v1",
                          "lcb.mixed.water-oil-brine.v1"])
        expected = json.dumps(reg.reledger(), indent=2) + "\n"
        self.assertEqual(reg.LEDGER_V2.read_text(encoding="utf-8").replace("\r\n", "\n"), expected)
        v2 = json.loads(expected)
        self.assertEqual(v2["open_unexplained"], [])
        self.assertEqual(v2["accounting_unverified_ineligible_for_acceptance"], sorted(
            s for s, v in states.items() if v == "open_by_declared_reaction"))


if __name__ == "__main__":
    unittest.main()
