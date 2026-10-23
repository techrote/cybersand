"""Synthetic regressions for the signed campaign ledger (lcb-signed-ledger-v3).

These exercise the reducer only. They do not touch protected fixture bytes or
the retained 2026-10-23 controls file.
"""
from __future__ import annotations

import json
import unittest

import lcb_registry as reg


def run(cells, series, source=0, sink=0, species=None, initial=None, events=None, declared=None):
    """`initial` is the declared ledger initial (default: the tick-0 value)."""
    checkpoints = [{"tick": t, "water_integer": w, **({"species": species[i]} if species else {})}
                   for i, (t, w) in enumerate(series)]
    ledger = {"initial_integer": series[0][1] if initial is None else initial,
              "explicit_source": source, "explicit_sink": sink}
    if events is not None:
        ledger["events"] = events
    inventory = {"cells": cells, **({"water_integer": declared} if declared is not None else {})}
    return reg.signed_ledger(inventory, ledger, checkpoints)


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

    def test_aggregate_only_source_is_never_closed(self):
        r = run({"water": 40}, [(0, 0), (30, 4080), (60, 80900)], source=80900)
        self.assertEqual(r["state"], "UNVERIFIED_SOURCE_SINK_TIMING")
        self.assertFalse(r["eligible_for_acceptance"])
        self.assertEqual(run({"water": 40}, [(0, 0), (60, 80901)], source=80900)["state"], "OPEN_UNEXPLAINED")
        self.assertEqual(run({"water": 40}, [(0, 0), (30, 90000), (60, 80900)], source=80900)["state"],
                         "OPEN_UNEXPLAINED")


class SourceSinkReconciliation(unittest.TestCase):
    """Re-review N4: a final net balance and a global envelope are not a ledger."""

    def test_review_counterexample_transient_loss_and_restoration(self):
        r = run({"water": 40}, [(0, 0), (10, 100), (20, 50), (30, 100)], source=100)
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")
        self.assertIn("no declared sink", r["reason"])
        self.assertEqual((r["positive_increments"], r["negative_increments"]), (150, 50))
        self.assertFalse(r["eligible_for_acceptance"])

    def test_source_gross_budget_exhausted(self):
        # A sink exists, so the loss direction is allowed, but gains 150 exceed the source 100.
        r = run({"water": 40}, [(0, 0), (10, 100), (20, 50), (30, 100)], source=100, sink=50)
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")
        self.assertIn("exceed the declared source", r["reason"])

    def test_sink_only_transient_gain_and_exhausted_sink(self):
        self.assertEqual(run({"water": 40}, [(0, 100), (10, 0), (20, 50), (30, 0)], sink=100)["state"],
                         "OPEN_UNEXPLAINED")
        r = run({"water": 40}, [(0, 100), (10, 0), (20, 50), (30, 0)], sink=100, source=50)
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")
        self.assertIn("exceed the declared sink", r["reason"])

    def test_mixed_aggregate_without_timing_is_unverified(self):
        r = run({"water": 40}, [(0, 1000), (10, 1100), (20, 1000)], source=100, sink=100)
        self.assertEqual(r["state"], "UNVERIFIED_SOURCE_SINK_TIMING")
        self.assertFalse(r["eligible_for_acceptance"])

    def test_timed_events_close_legitimate_changes(self):
        events = [{"tick": 5, "source": 100}, {"tick": 15, "sink": 100}]
        r = run({"water": 40}, [(0, 1000), (10, 1100), (20, 1000)], source=100, sink=100, events=events)
        self.assertEqual(r["state"], "closed_timed_source_sink")
        self.assertTrue(r["eligible_for_acceptance"])
        self.assertEqual(run({"water": 40}, [(0, 0), (10, 100), (30, 100)], source=100,
                             events=[{"tick": 3, "source": 100}])["state"], "closed_timed_source_sink")
        self.assertEqual(run({"water": 40}, [(0, 100), (10, 60), (30, 0)], sink=100,
                             events=[{"tick": 3, "sink": 40}, {"tick": 12, "sink": 60}])["state"],
                         "closed_timed_source_sink")

    def test_timed_events_reject_transient_and_phase_errors(self):
        bad = run({"water": 40}, [(0, 0), (10, 100), (20, 50), (30, 100)], source=100,
                  events=[{"tick": 5, "source": 100}])
        self.assertEqual(bad["state"], "OPEN_UNEXPLAINED")
        self.assertEqual(bad["deviations"], [(20, -50)])
        # An event indexed 10 is first observable at completed tick 11, not at tick 10.
        early = run({"water": 40}, [(0, 0), (10, 100), (20, 100)], source=100,
                    events=[{"tick": 10, "source": 100}])
        self.assertEqual(early["state"], "OPEN_UNEXPLAINED")

    def test_timed_events_must_match_totals(self):
        r = run({"water": 40}, [(0, 0), (10, 100)], source=100, events=[{"tick": 3, "source": 90}])
        self.assertEqual(r["state"], "MALFORMED_EVIDENCE")


class SpeciesEvidence(unittest.TestCase):
    """Re-review N3: species accounting is bound to the declared initial state."""

    cells = {"water": 40, "salt": 40, "brine": 10, "oil": 5}
    sp = [{"salt": 40, "brine": 10, "oil": 5}, {"salt": 30, "brine": 30, "oil": 5}]

    def test_initial_gain_or_loss_against_declared_initial_fails(self):
        for start, end in ((10001, 7451), (9999, 7449)):
            r = run(self.cells, [(0, start), (30, end)], species=self.sp, initial=10000)
            self.assertEqual(r["state"], "OPEN_UNEXPLAINED", start)
            self.assertEqual(r["initial_discrepancy"], start - 10000)
            self.assertFalse(r["eligible_for_acceptance"])

    def test_constant_water_contradicting_consumed_salt_fails(self):
        r = run(self.cells, [(0, 10000), (30, 10000)], species=self.sp, initial=10000)
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")
        self.assertIn("[-255 s, -s]", r["reason"])

    def test_valid_history_bound_to_declared_initial_closes(self):
        r = run(self.cells, [(0, 10000), (30, 7450)], species=self.sp, initial=10000, declared=10000)
        self.assertEqual(r["state"], "closed_signed_reaction_ledger")
        self.assertTrue(r["eligible_for_acceptance"])

    def test_ledger_and_inventory_initial_must_agree(self):
        r = run(self.cells, [(0, 10000), (30, 7450)], species=self.sp, initial=10000, declared=10001)
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")

    def test_tick0_species_must_match_inventory(self):
        sp = [{"salt": 39, "brine": 10, "oil": 5}, {"salt": 30, "brine": 28, "oil": 5}]
        self.assertEqual(run(self.cells, [(0, 10000), (30, 7705)], species=sp)["state"], "OPEN_UNEXPLAINED")

    def test_missing_or_partial_species_evidence_is_malformed(self):
        missing_oil = [{"salt": 40, "brine": 10}, {"salt": 30, "brine": 30}]
        self.assertEqual(run(self.cells, [(0, 10000), (30, 7450)], species=missing_oil)["state"],
                         "MALFORMED_EVIDENCE")
        negative = [{"salt": 40, "brine": 10, "oil": 5}, {"salt": 30, "brine": 30, "oil": -1}]
        self.assertEqual(run(self.cells, [(0, 10000), (30, 7450)], species=negative)["state"],
                         "MALFORMED_EVIDENCE")
        checkpoints = [{"tick": 0, "water_integer": 10000, "species": self.sp[0]},
                       {"tick": 30, "water_integer": 7450}]
        r = reg.signed_ledger({"cells": self.cells}, {"initial_integer": 10000, "explicit_source": 0,
                                                     "explicit_sink": 0}, checkpoints)
        self.assertEqual(r["state"], "MALFORMED_EVIDENCE")
        self.assertFalse(r["eligible_for_acceptance"])

    def test_malformed_checkpoint_structure(self):
        for series in ([(1, 10000), (30, 10000)], [(0, 10000), (0, 10000)], [(0, 10000), (30, -1)]):
            self.assertEqual(run({"water": 40}, series, initial=10000)["state"], "MALFORMED_EVIDENCE", series)
        self.assertEqual(reg.signed_ledger({"cells": {}}, {"initial_integer": 0, "explicit_source": 0,
                                                          "explicit_sink": 0}, [])["state"], "MALFORMED_EVIDENCE")


class RetainedRecords(unittest.TestCase):
    def test_historical_controls_preserved(self):
        self.assertEqual(reg.lf_sha256(reg.CONTROLS),
                         "989ff70dba646285991a2a5e8ca5c3b0aa94b9381dc44c849528518e4238fac1")

    def test_v2_verifies_against_its_frozen_reducer(self):
        expected = json.dumps(reg.reledger_v2(), indent=2) + "\n"
        self.assertEqual(reg.LEDGER_V2.read_text(encoding="utf-8").replace("\r\n", "\n"), expected)
        self.assertEqual(json.loads(expected)["input"]["reducer_sha256_lf"],
                         "56293fc96c243423f90b2381d98c5b54f5aff83b06fcfd8bad8d32befa3e6583")

    def test_v3_current_and_classifications(self):
        expected = json.dumps(reg.reledger(), indent=2) + "\n"
        self.assertEqual(reg.LEDGER_V3.read_text(encoding="utf-8").replace("\r\n", "\n"), expected)
        v3 = json.loads(expected)
        self.assertEqual(v3["rule"], "lcb-signed-ledger-v3")
        self.assertEqual(v3["open_unexplained_or_malformed"], [])
        self.assertEqual(v3["changed_from_v2"], ["lcb.mixed.repeated-openings.v1", "lcb.rest.remote-disturbance.v1",
                                                 "lcb.rest.two-pool-partial-activity.v1",
                                                 "lcb.shallow.stream-steps.v1"])
        self.assertTrue(all(v3["cases"][s]["state"] == "UNVERIFIED_SOURCE_SINK_TIMING"
                            for s in v3["changed_from_v2"]))
        for sid in ("lcb.granular.salt-dissolution.v1", "lcb.mixed.sodium-oil-fire.v1",
                    "lcb.mixed.water-oil-brine.v1"):
            self.assertEqual(v3["cases"][sid]["state"], "UNVERIFIED_REACTION_AMOUNT")


if __name__ == "__main__":
    unittest.main()
