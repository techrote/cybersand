"""Synthetic regressions for the signed campaign ledger (lcb-signed-ledger-v7).

These exercise the reducer only. They do not touch protected fixture bytes or
the retained 2026-10-23 controls file.
"""
from __future__ import annotations

import argparse
import contextlib
import copy
import io
import json
import tempfile
import unittest
from pathlib import Path

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


class MixedReactiveEvidenceR1(unittest.TestCase):
    """Re-review R1: constant Water never bypasses supplied species evidence."""

    def sp(self, sodium):
        return [{"salt": 40, "brine": 10, "oil": 5, "sodium": sodium},
                {"salt": 30, "brine": 30, "oil": 5, "sodium": sodium}]

    def test_positive_sodium_constant_water_fails(self):
        cells = {"water": 40, "salt": 40, "brine": 10, "oil": 5, "sodium": 1}
        r = run(cells, [(0, 10000), (30, 10000)], species=self.sp(1), initial=10000)
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")
        self.assertFalse(r["eligible_for_acceptance"])
        self.assertEqual(r["active_reactions"], ["salt"])

    def test_zero_sodium_constant_water_fails(self):
        cells = {"water": 40, "salt": 40, "brine": 10, "oil": 5, "sodium": 0}
        r = run(cells, [(0, 10000), (30, 10000)], species=self.sp(0), initial=10000)
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")
        self.assertEqual(r["active_reactions"], ["salt"])

    def test_changing_sodium_is_unverified_never_closed(self):
        cells = {"water": 40, "salt": 40, "brine": 10, "oil": 5, "sodium": 1}
        sp = [{"salt": 40, "brine": 10, "oil": 5, "sodium": 1}, {"salt": 30, "brine": 30, "oil": 5, "sodium": 0}]
        for water in (10000, 7450, 9000):
            r = run(cells, [(0, 10000), (30, water)], species=sp, initial=10000)
            self.assertEqual(r["state"], "UNVERIFIED_REACTION_AMOUNT", water)
            self.assertFalse(r["eligible_for_acceptance"])

    def test_sodium_without_species_evidence_is_unverified_even_if_constant(self):
        r = run({"water": 40, "sodium": 4}, [(0, 10000), (30, 10000)])
        self.assertEqual(r["state"], "UNVERIFIED_REACTION_AMOUNT")

    def test_salt_only_valid_closure_preserved(self):
        cells = {"water": 40, "salt": 40, "brine": 10, "oil": 5}
        sp = [{"salt": 40, "brine": 10, "oil": 5}, {"salt": 30, "brine": 30, "oil": 5}]
        r = run(cells, [(0, 10000), (30, 7450)], species=sp, initial=10000)
        self.assertEqual(r["state"], "closed_signed_reaction_ledger")
        self.assertTrue(r["eligible_for_acceptance"])

    def test_unconsumed_salt_with_constant_water_closes(self):
        cells = {"water": 40, "salt": 40, "brine": 10}
        sp = [{"salt": 40, "brine": 10}, {"salt": 40, "brine": 10}]
        r = run(cells, [(0, 10000), (30, 10000)], species=sp)
        self.assertEqual(r["state"], "closed")
        self.assertEqual(r["active_reactions"], [])


class SpeciesDomainR2(unittest.TestCase):
    """Re-review R2: observed species outside the inventory are validated, not ignored."""

    cells = {"water": 40, "salt": 40, "brine": 10, "oil": 5}

    def sp(self, t0_extra, t30_extra):
        return [{"salt": 40, "brine": 10, "oil": 5, **t0_extra}, {"salt": 30, "brine": 30, "oil": 5, **t30_extra}]

    def test_unexplained_production_of_an_undeclared_species_fails(self):
        r = run(self.cells, [(0, 10000), (30, 7450)], species=self.sp({"lava": 0}, {"lava": 100}), initial=10000)
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")
        self.assertEqual(r["changed_species"], ["lava"])
        self.assertIn("lava", r["species_domain"])

    def test_disappearing_observation_is_malformed(self):
        r = run(self.cells, [(0, 10000), (30, 7450)], species=self.sp({"lava": 0}, {}), initial=10000)
        self.assertEqual(r["state"], "MALFORMED_EVIDENCE")
        self.assertFalse(r["eligible_for_acceptance"])

    def test_undeclared_species_present_at_tick0_fails_binding(self):
        r = run(self.cells, [(0, 10000), (30, 7450)], species=self.sp({"lava": 3}, {"lava": 3}), initial=10000)
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")
        self.assertIn("initial_species_discrepancy", r)

    def test_constant_undeclared_zero_species_is_allowed(self):
        r = run(self.cells, [(0, 10000), (30, 7450)], species=self.sp({"lava": 0}, {"lava": 0}), initial=10000)
        self.assertEqual(r["state"], "closed_signed_reaction_ledger")

    def test_water_as_species_key_is_malformed(self):
        r = run(self.cells, [(0, 10000), (30, 7450)], species=self.sp({"water": 40}, {"water": 30}), initial=10000)
        self.assertEqual(r["state"], "MALFORMED_EVIDENCE")

    def test_non_reactive_species_change_without_reaction_fails(self):
        cells = {"water": 40, "oil": 5}
        r = run(cells, [(0, 10000), (30, 10000)], species=[{"oil": 5}, {"oil": 4}])
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")


class TimedHorizonR3(unittest.TestCase):
    """Re-review R3: every counted event must be observed; event N is first seen at completed N+1."""

    def test_source_beyond_observation_is_not_closed(self):
        r = run({"water": 40}, [(0, 0), (10, 0)], source=100, events=[{"tick": 10, "source": 100}])
        self.assertEqual(r["state"], "UNVERIFIED_INCOMPLETE_HORIZON")
        self.assertFalse(r["eligible_for_acceptance"])
        self.assertEqual(r["signed_delta"], -100)

    def test_mixed_future_events_are_not_closed(self):
        r = run({"water": 40}, [(0, 100), (10, 100)], source=100, sink=50,
                events=[{"tick": 10, "source": 100}, {"tick": 11, "sink": 50}])
        self.assertEqual(r["state"], "UNVERIFIED_INCOMPLETE_HORIZON")
        self.assertEqual(r["signed_delta"], -50)

    def test_net_zero_future_pair_defeats_final_net_check(self):
        r = run({"water": 40}, [(0, 100), (10, 100)], source=50, sink=50,
                events=[{"tick": 10, "source": 50}, {"tick": 11, "sink": 50}])
        self.assertEqual(r["signed_delta"], 0)
        self.assertEqual(r["state"], "UNVERIFIED_INCOMPLETE_HORIZON")

    def test_event_at_last_tick_minus_one_is_observed(self):
        r = run({"water": 40}, [(0, 0), (10, 100)], source=100, events=[{"tick": 9, "source": 100}])
        self.assertEqual(r["state"], "closed_timed_source_sink")
        self.assertEqual(r["signed_delta"], 0)


class EventBalanceR4(unittest.TestCase):
    """Re-review R4: the chronological balance is checked at every event boundary."""

    def test_sink_before_source_is_impossible(self):
        r = run({"water": 40}, [(0, 0), (10, 0)], source=100, sink=100,
                events=[{"tick": 1, "sink": 100}, {"tick": 2, "source": 100}])
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")
        self.assertEqual(r["event_prefix"], [(1, -100)])
        self.assertFalse(r["eligible_for_acceptance"])

    def test_source_before_sink_control_closes(self):
        r = run({"water": 40}, [(0, 0), (10, 0)], source=100, sink=100,
                events=[{"tick": 1, "source": 100}, {"tick": 2, "sink": 100}])
        self.assertEqual(r["state"], "closed_timed_source_sink")

    def test_same_tick_order_is_application_order(self):
        sink_first = run({"water": 40}, [(0, 0), (10, 0)], source=100, sink=100,
                         events=[{"tick": 3, "sink": 100}, {"tick": 3, "source": 100}])
        self.assertEqual(sink_first["state"], "OPEN_UNEXPLAINED")
        source_first = run({"water": 40}, [(0, 0), (10, 0)], source=100, sink=100,
                           events=[{"tick": 3, "source": 100}, {"tick": 3, "sink": 100}])
        self.assertEqual(source_first["state"], "closed_timed_source_sink")

    def test_unordered_or_combined_events_are_malformed(self):
        unordered = run({"water": 40}, [(0, 0), (10, 0)], source=100, sink=100,
                        events=[{"tick": 2, "source": 100}, {"tick": 1, "sink": 100}])
        self.assertEqual(unordered["state"], "MALFORMED_EVIDENCE")
        both = run({"water": 40}, [(0, 0), (10, 0)], source=100, sink=100,
                   events=[{"tick": 1, "source": 100, "sink": 100}])
        self.assertEqual(both["state"], "MALFORMED_EVIDENCE")


class ObservedOnlySaltF1(unittest.TestCase):
    """Re-review F1: Salt seen only in observations must never reach the Salt ledger without Brine."""

    def ledger(self, species, cells=None):
        checkpoints = [{"tick": t, "water_integer": 10000, "species": s} for t, s in zip((0, 30), species)]
        return reg.signed_ledger({"water_integer": 10000, "cells": cells or {}},
                                 {"initial_integer": 10000, "explicit_source": 0, "explicit_sink": 0}, checkpoints)

    def test_review_reproducer_is_malformed_not_an_exception(self):
        r = self.ledger([{"salt": 0}, {"salt": 1}])
        self.assertEqual(r["state"], "MALFORMED_EVIDENCE")
        self.assertFalse(r["eligible_for_acceptance"])
        self.assertIn("brine", r["species_domain"])
        self.assertIn("'brine'", r["reason"])

    def test_explicit_zero_brine_is_unexplained_salt_production(self):
        r = self.ledger([{"salt": 0, "brine": 0}, {"salt": 1, "brine": 0}])
        self.assertEqual(r["state"], "OPEN_UNEXPLAINED")
        self.assertIn("Salt reappeared", r["reason"])

    def test_brine_supplied_at_one_checkpoint_only(self):
        for species in ([{"salt": 0, "brine": 0}, {"salt": 1}], [{"salt": 0}, {"salt": 1, "brine": 0}]):
            r = self.ledger(species)
            self.assertEqual(r["state"], "MALFORMED_EVIDENCE", species)

    def test_salt_first_appearing_at_a_later_checkpoint(self):
        for species in ([{}, {"salt": 1}], [{"brine": 0}, {"salt": 1, "brine": 0}]):
            r = self.ledger(species)
            self.assertEqual(r["state"], "MALFORMED_EVIDENCE", species)

    def test_declared_salt_closure_and_r2_binding_preserved(self):
        cells = {"water": 40, "salt": 40, "brine": 10, "oil": 5}
        sp = [{"salt": 40, "brine": 10, "oil": 5}, {"salt": 30, "brine": 30, "oil": 5}]
        r = run(cells, [(0, 10000), (30, 7450)], species=sp, initial=10000)
        self.assertEqual(r["state"], "closed_signed_reaction_ledger")
        bad = run(cells, [(0, 10000), (30, 7450)], species=[sp[0], {"salt": 30, "brine": 30, "oil": 5.5}])
        self.assertEqual(bad["state"], "MALFORMED_EVIDENCE")


class EventShapeF2(unittest.TestCase):
    """Re-review F2: exactly one of source/sink by key presence, independent of amount."""

    def probe(self, event, source=0, sink=0, initial=0, final=0):
        return reg.signed_ledger({"water_integer": initial, "cells": {}},
                                 {"initial_integer": initial, "explicit_source": source, "explicit_sink": sink,
                                  "events": [event]},
                                 [{"tick": 0, "water_integer": initial}, {"tick": 10, "water_integer": final}])

    def test_tick_only_and_dual_key_variants_are_malformed(self):
        for event, kw in (({"tick": 1}, {}),
                          ({"tick": 1, "source": 0, "sink": 0}, {}),
                          ({"tick": 1, "source": 100, "sink": 0}, {"source": 100, "final": 100}),
                          ({"tick": 1, "source": 0, "sink": 100}, {"sink": 100, "initial": 100})):
            r = self.probe(event, **kw)
            self.assertEqual(r["state"], "MALFORMED_EVIDENCE", event)
            self.assertFalse(r["eligible_for_acceptance"])

    def test_explicit_zero_under_one_key_is_valid(self):
        # A recorded zero-amount event is valid evidence: the timed ledger closes on it.
        self.assertEqual(self.probe({"tick": 1, "source": 0})["state"], "closed_timed_source_sink")
        self.assertEqual(self.probe({"tick": 1, "sink": 0})["state"], "closed_timed_source_sink")

    def test_amount_and_tick_types_still_checked(self):
        for event in ({"tick": 1, "source": -1}, {"tick": 1, "source": 1.5}, {"tick": -1, "source": 1},
                      {"tick": 1, "source": True}, {"tick": 1, "flow": 1}):
            self.assertEqual(self.probe(event, source=1, final=1)["state"], "MALFORMED_EVIDENCE", event)

    def test_valid_single_key_controls(self):
        self.assertEqual(self.probe({"tick": 1, "source": 100}, source=100, final=100)["state"],
                         "closed_timed_source_sink")
        self.assertEqual(self.probe({"tick": 1, "sink": 100}, sink=100, initial=100)["state"],
                         "closed_timed_source_sink")


_DEFAULT = object()


def direct(inventory=_DEFAULT, ledger=_DEFAULT, checkpoints=_DEFAULT):
    inventory = {"water_integer": 0, "cells": {}} if inventory is _DEFAULT else inventory
    ledger = {"initial_integer": 0, "explicit_source": 0, "explicit_sink": 0} if ledger is _DEFAULT else ledger
    if checkpoints is _DEFAULT:
        checkpoints = [{"tick": 0, "water_integer": 0}, {"tick": 10, "water_integer": 0}]
    return reg.signed_ledger(inventory, ledger, checkpoints)


ZERO = {"initial_integer": 0, "explicit_source": 0, "explicit_sink": 0}


class EventContainerF3(unittest.TestCase):
    """Re-review F3: the events value itself is validated; malformed containers never raise or close."""

    def test_malformed_containers(self):
        for events in ({}, False, 0, "", "x", None, 1.5, {"tick": 1, "source": 0}):
            r = direct(ledger={**ZERO, "events": events})
            self.assertEqual(r["state"], "MALFORMED_EVIDENCE", repr(events))
            self.assertFalse(r["eligible_for_acceptance"])

    def test_omitted_list_and_empty_list_semantics(self):
        self.assertEqual(direct(ledger=dict(ZERO))["state"], "closed")
        self.assertEqual(direct(ledger={**ZERO, "events": []})["state"], "closed")
        empty_with_totals = direct(ledger={**ZERO, "explicit_source": 100, "events": []},
                                   checkpoints=[{"tick": 0, "water_integer": 0}, {"tick": 10, "water_integer": 100}])
        self.assertEqual(empty_with_totals["state"], "MALFORMED_EVIDENCE")
        self.assertEqual(direct(ledger={**ZERO, "events": [{"tick": 1, "source": 0}]})["state"],
                         "closed_timed_source_sink")


class ReactionHorizonF4(unittest.TestCase):
    """Re-review F4: the event horizon applies before any reaction closure."""

    def salt(self, event_tick):
        return reg.signed_ledger(
            {"water_integer": 255, "cells": {"salt": 1}},
            {"initial_integer": 255, "explicit_source": 0, "explicit_sink": 0,
             "events": [{"tick": event_tick, "source": 0}]},
            [{"tick": 0, "water_integer": 255, "species": {"salt": 1, "brine": 0}},
             {"tick": 30, "water_integer": 0, "species": {"salt": 0, "brine": 2}}])

    def test_future_zero_event_blocks_reaction_closure(self):
        r = self.salt(30)
        self.assertEqual(r["state"], "UNVERIFIED_INCOMPLETE_HORIZON")
        self.assertFalse(r["eligible_for_acceptance"])

    def test_observed_zero_event_allows_reaction_closure(self):
        self.assertEqual(self.salt(29)["state"], "closed_signed_reaction_ledger")


class RootContainersG1G2(unittest.TestCase):
    """Re-review G1/G2: roots, items, keys and water_integer are type-checked; nothing raises."""

    def test_root_and_item_containers(self):
        cases = [dict(inventory=None), dict(inventory=[]), dict(inventory={"cells": None}),
                 dict(inventory={"cells": []}), dict(inventory={"cells": {1: 0}}), dict(ledger=None),
                 dict(ledger=[]), dict(checkpoints={}), dict(checkpoints=[None]),
                 dict(checkpoints=[{"tick": 0, "water_integer": 0}, 7]),
                 dict(checkpoints=[{"tick": 0, "water_integer": 0, "species": {1: 0}},
                                   {"tick": 10, "water_integer": 0, "species": {1: 0}}]),
                 dict(checkpoints=[{"tick": 0, "water_integer": 0, "species": None},
                                   {"tick": 10, "water_integer": 0, "species": None}]),
                 dict(checkpoints=[{"tick": 0, "water_integer": 0, "species": {"oil": 1, 2: 0}},
                                   {"tick": 10, "water_integer": 0, "species": {"oil": 1, 2: 0}}])]
        for kw in cases:
            r = direct(**kw)
            self.assertEqual(r["state"], "MALFORMED_EVIDENCE", kw)
            self.assertFalse(r["eligible_for_acceptance"])

    def test_inventory_water_integer_type(self):
        for value in (True, 1.0, None, -1, "1"):
            r = direct(inventory={"water_integer": value, "cells": {}},
                       ledger={**ZERO, "initial_integer": 1},
                       checkpoints=[{"tick": 0, "water_integer": 1}, {"tick": 10, "water_integer": 1}])
            self.assertEqual(r["state"], "MALFORMED_EVIDENCE", repr(value))
        absent = direct(inventory={"cells": {}}, ledger={**ZERO, "initial_integer": 1},
                        checkpoints=[{"tick": 0, "water_integer": 1}, {"tick": 10, "water_integer": 1}])
        self.assertEqual(absent["state"], "closed")


QUIET = "lcb.rest.deep-quiet-pool.v1"


class ReducerPipeline(unittest.TestCase):
    """reduce_cmd on synthetic report pairs (G1/G3/G4/G5): never aborts; identity binds parity."""

    @classmethod
    def setUpClass(cls):
        cls.meta = {s.id: s.metadata() for s in reg.catalogue.build()}[QUIET]
        cls.pinned = next(e for e in reg.load(reg.REGISTRY)["scenarios"] if e["id"] == QUIET)["definition"][
            "canonical_hash"]

    def report(self, workers, overrides=None, **override):
        override = {**(overrides or {}), **override}
        water = self.meta["initial_inventory"]["water_integer"]
        identity = {"source_revision": "abc123", "native_sha256": "n", "godot": "g", "script_set_sha256": "s",
                    "platform": "Windows"}
        r = {"status": "completed", "id": QUIET, "workers": workers, "horizon": self.meta["horizon_ticks"],
             "definition_hash": self.pinned,
             "checkpoints": [{"tick": 0, "water_integer": water, "content_hash": "c0", "state_hash": "s0"},
                             {"tick": 30, "water_integer": water, "content_hash": "c1", "state_hash": "s1"}],
             "capture": {"observations": [], "outcome": "complete", "runtime_identity": identity,
                         "water_ledger": {"initial_integer": water, "explicit_source": 0, "explicit_sink": 0}}}
        for path, value in override.items():
            node = r
            keys = path.split("__")
            for k in keys[:-1]:
                node = node[k]
            node[keys[-1]] = value
        return r

    def reduce(self, w1, w4, raw_w1=None):
        with tempfile.TemporaryDirectory() as tmp:
            d1, d4, out = Path(tmp, "w1"), Path(tmp, "w4"), Path(tmp, "out.json")
            d1.mkdir(), d4.mkdir()
            Path(d1, f"{QUIET}-w1.json").write_text(raw_w1 if raw_w1 is not None else json.dumps(w1), encoding="utf-8")
            Path(d4, f"{QUIET}-w4.json").write_text(json.dumps(w4), encoding="utf-8")
            args = argparse.Namespace(w1=str(d1), w4=str(d4), out=str(out), date="2026-10-23", platform="test",
                                      source_sha="abc123")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(reg.reduce_cmd(args), 0)
            return json.loads(out.read_text(encoding="utf-8"))

    def test_valid_pair_is_identical(self):
        out = self.reduce(self.report(1), self.report(4))
        case = out["cases"][QUIET]
        self.assertEqual(case["parity_1_vs_4_workers"], "identical")
        self.assertEqual(case["ledger"]["state"], "closed")
        self.assertEqual(out["problems"], [])

    def test_identity_mismatch_is_never_identical_or_measured(self):
        for override in ({"definition_hash": "f" * 64}, {"capture__runtime_identity__native_sha256": "other"},
                         {"horizon": 1}, {"id": "lcb.other.v1"}, {"workers": 1},
                         {"capture__runtime_identity__source_revision": "zzz"}):
            out = self.reduce(self.report(1), self.report(4, overrides=override))
            case = out["cases"][QUIET]
            self.assertEqual(case["parity_1_vs_4_workers"], "IDENTITY_MISMATCH", override)
            self.assertIn(QUIET, out["problems"])
            arms = reg.arms_for(QUIET, ["water"], case, False)
            self.assertNotEqual(arms[0]["status"], "measured", override)

    def test_null_water_ledger_and_bad_checkpoints_do_not_abort(self):
        out = self.reduce(self.report(1, capture__water_ledger=None), self.report(4, capture__water_ledger=None))
        self.assertEqual(out["cases"][QUIET]["ledger"]["state"], "MALFORMED_EVIDENCE")
        self.assertIn(QUIET, out["problems"])
        for events in (False, {}, ""):
            ledger = {"initial_integer": self.meta["initial_inventory"]["water_integer"], "explicit_source": 0,
                      "explicit_sink": 0, "events": events}
            out = self.reduce(self.report(1, capture__water_ledger=ledger), self.report(4))
            self.assertEqual(out["cases"][QUIET]["ledger"]["state"], "MALFORMED_EVIDENCE", repr(events))

    def test_duplicate_json_names_are_a_malformed_report(self):
        raw = json.dumps(self.report(1)).replace('"status": "completed"', '"status": "completed", "status": "x"')
        out = self.reduce(None, self.report(4), raw_w1=raw)
        case = out["cases"][QUIET]
        self.assertEqual(case["status"]["w1"], "malformed_report")
        self.assertIn("duplicate JSON object names", case["errors"]["w1"])
        self.assertIn(QUIET, out["problems"])
        with self.assertRaises(ValueError):
            json.loads('{"a": 1, "a": 2}', object_pairs_hook=reg._unique_pairs)

    def test_i1_malformed_observations_and_timing_never_abort(self):
        for override in ({"capture__observations": [{"id": "synthetic"}]},
                         {"capture__timing": [1]},
                         {"capture__observations": [{"id": "a", "value": "x"}]},
                         {"capture__observations": [{"id": "a", "value": 1}, {"id": "a", "value": 1}]},
                         {"capture__observations": {"a": 1}},
                         {"capture__observations": [{"value": 1}]},
                         {"capture__timing": {"p50_ms": "slow"}},
                         {"capture__runtime_identity": [1]},
                         {"checkpoints": {"tick": 0}}):
            for side in ("w1", "w4"):
                w1 = self.report(1, overrides=override) if side == "w1" else self.report(1)
                w4 = self.report(4, overrides=override) if side == "w4" else self.report(4)
                out = self.reduce(w1, w4)
                case = out["cases"][QUIET]
                self.assertEqual(case["status"][side], "malformed_report", (override, side))
                self.assertIn(side, case["errors"])
                self.assertNotEqual(case["parity_1_vs_4_workers"], "identical")
                self.assertIn(QUIET, out["problems"])
                self.assertIn(QUIET, out["ineligible_for_acceptance"])
        out = self.reduce(self.report(1, capture__timing={"p50_ms": 1.5, "p95_ms": None, "max_ms": 3}),
                          self.report(4, capture__observations=[{"id": "cell", "value": {"material": 3}}]))
        self.assertEqual(out["cases"][QUIET]["status"], {"w1": "completed", "w4": "completed"})

    def test_i1_malformed_report_beside_a_valid_one(self):
        other = "lcb.rest.remote-disturbance.v1"
        meta = {s.id: s.metadata() for s in reg.catalogue.build()}[other]
        pinned = next(e for e in reg.load(reg.REGISTRY)["scenarios"] if e["id"] == other)["definition"][
            "canonical_hash"]
        water = meta["initial_inventory"]["water_integer"]

        def valid(workers):
            r = self.report(workers)
            r.update(id=other, horizon=meta["horizon_ticks"], definition_hash=pinned)
            for c in r["checkpoints"]:
                c["water_integer"] = water
            r["capture"]["water_ledger"] = {"initial_integer": water, "explicit_source": 0, "explicit_sink": 0}
            return r
        with tempfile.TemporaryDirectory() as tmp:
            d1, d4, out = Path(tmp, "w1"), Path(tmp, "w4"), Path(tmp, "out.json")
            d1.mkdir(), d4.mkdir()
            Path(d1, f"{QUIET}-w1.json").write_text(json.dumps(self.report(1, capture__timing=[1])), encoding="utf-8")
            Path(d4, f"{QUIET}-w4.json").write_text(json.dumps(self.report(4)), encoding="utf-8")
            Path(d1, f"{other}-w1.json").write_text(json.dumps(valid(1)), encoding="utf-8")
            Path(d4, f"{other}-w4.json").write_text(json.dumps(valid(4)), encoding="utf-8")
            args = argparse.Namespace(w1=str(d1), w4=str(d4), out=str(out), date="2026-10-23", platform="test",
                                      source_sha="abc123")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(reg.reduce_cmd(args), 0)
            result = json.loads(out.read_text(encoding="utf-8"))
        self.assertEqual(result["cases"][QUIET]["status"]["w1"], "malformed_report")
        self.assertEqual(result["cases"][other]["parity_1_vs_4_workers"], "identical")
        self.assertEqual(result["cases"][other]["ledger"]["state"], "closed")
        self.assertEqual(result["problems"], [QUIET])
        self.assertEqual(result["runtime"]["native_sha256"], "n")

    def test_identity_only_failure_is_in_the_complete_ineligible_list(self):
        out = self.reduce(self.report(1), self.report(4, definition_hash="f" * 64))
        case = out["cases"][QUIET]
        self.assertEqual((case["parity_1_vs_4_workers"], case["ledger"]["state"]), ("IDENTITY_MISMATCH", "closed"))
        self.assertIn(QUIET, out["ineligible_for_acceptance"])

    def test_summary_lists_are_orthogonal(self):
        water = self.meta["initial_inventory"]["water_integer"]
        unverified = {"initial_integer": water, "explicit_source": 10, "explicit_sink": 10}
        w1 = self.report(1, capture__water_ledger=unverified)
        w4 = self.report(4, capture__observations=[{"id": "x", "value": 1}])
        out = self.reduce(w1, w4)
        self.assertEqual(out["cases"][QUIET]["ledger"]["state"], "UNVERIFIED_SOURCE_SINK_TIMING")
        self.assertIn(QUIET, out["problems"])
        self.assertIn(QUIET, out["accounting_unverified_ineligible_for_acceptance"])
        self.assertIn(QUIET, out["ineligible_for_acceptance"])


class ArmAvailabilityH1(unittest.TestCase):
    """Re-review H1: a manifest status label never makes a candidate mapping executable."""

    def test_relabelled_protected_candidate_stays_blocked(self):
        manifest = reg.load(reg.PROTECTED_MANIFEST)
        for fixture in manifest["fixtures"]:
            f = copy.deepcopy(fixture)
            for arm in f["arms"]:
                arm["status"] = "measured"
            meta = {"category": "protected-reference", "horizon_ticks": f["horizon_ticks"],
                    "initial_inventory": reg.inventories()[f["id"]]}
            e = reg.entry(f["id"], meta, reg.ROOT / f["path"], None, reg.load(reg.MATRIX), f)
            for arm in e["arms"]:
                current = reg.current_default_mapping(arm["mapping"], {r["name"]: r for r in
                                                                       reg.load(reg.MATRIX)["liquid_rows"]})
                self.assertEqual(arm["executable_today"], current, (f["id"], arm["id"]))
                if not current:
                    self.assertEqual(arm["status"], "blocked")
                    self.assertTrue(arm["depends_on"])

    def test_registry_has_no_executable_candidate(self):
        rows = {r["name"]: r for r in reg.load(reg.MATRIX)["liquid_rows"]}
        for s in reg.load(reg.REGISTRY)["scenarios"]:
            for arm in s["arms"]:
                if not reg.current_default_mapping(arm["mapping"], rows):
                    self.assertFalse(arm["executable_today"], (s["id"], arm["id"]))
                    self.assertEqual(arm["status"], "blocked", (s["id"], arm["id"]))


class InventoryModelH3(unittest.TestCase):
    """Re-review H3: inventory_of models the native constructor exactly or refuses."""

    M8 = [1, 8, 12, 0]

    def test_water_rectangle_holds_maximum(self):
        inv = reg.catalogue.inventory_of([100, 100, 1, 1, 3], [], self.M8)
        self.assertEqual((inv["cells"], inv["water_integer"]), ({"water": 1}, 255))

    def test_zero_fill_is_a_noop(self):
        inv = reg.catalogue.inventory_of([100, 100, 1, 1, 2], [100, 100, 1, 1, 0, 0], self.M8)
        self.assertEqual((inv["cells"], inv["water_integer"]), ({"sand": 1}, 0))
        over_water = reg.catalogue.inventory_of([100, 100, 1, 1, 3], [100, 100, 1, 1, 0, 0], self.M8)
        self.assertEqual(over_water["water_integer"], 255)

    def test_overlaps_and_repeated_fills(self):
        inv = reg.catalogue.inventory_of([100, 100, 2, 1, 2, 101, 100, 1, 1, 16],
                                         [101, 100, 1, 1, 255, 0, 101, 100, 1, 1, 17, 0], self.M8)
        self.assertEqual((inv["cells"], inv["water_integer"]), ({"sand": 1, "water": 1}, 17))

    def test_unsupported_semantics_and_materials_refuse(self):
        with self.assertRaises(ValueError):
            reg.catalogue.inventory_of([], [100, 100, 1, 1, 128, 0], [1, 4, 12, 0])
        with self.assertRaises(ValueError):
            reg.catalogue.inventory_of([100, 100, 1, 1, 99], [], self.M8)


class RetainedRecords(unittest.TestCase):
    def test_historical_controls_preserved(self):
        self.assertEqual(reg.lf_sha256(reg.CONTROLS),
                         "989ff70dba646285991a2a5e8ca5c3b0aa94b9381dc44c849528518e4238fac1")

    def test_superseded_records_replay_at_their_own_revisions(self):
        expected = {"v2": "5688e26f19c5514ac2ece0ab1acde2ebda2077603bc85575245a4203b353d8fa",
                    "v3": "b70f325739035e943e27a8b36273757e054db4092fda0ed113d1db89485d399b",
                    "v4": "0cc6d6dfa5da907c981f954e19ed2858f573a7e12996017b293872bf84030e13",
                    "v5": "6f7b294e54534d92d434320b724dff6552095f993f5a3ce13b518e9f9c786084",
                    "v6": "a7189204ebf1a3632431ecd5794b03556f30e079a838cfaeb0272761685bbd34"}
        for version, digest in expected.items():
            self.assertEqual(reg.lf_sha256(reg.HISTORICAL_LEDGERS[version][1]), digest, version)
            ok, notes = reg.verify_historical(version)
            self.assertTrue(ok, (version, notes))

    def test_altered_historical_record_fails(self):
        for version in ("v4", "v7"):
            commit, path = reg.HISTORICAL_LEDGERS[version]
            with tempfile.TemporaryDirectory(dir=reg.ROOT / "docs/reference") as tmp:
                altered = Path(tmp, path.name)
                altered.write_bytes(path.read_bytes().replace(b'"closed"', b'"OPEN"', 1))
                saved = reg.HISTORICAL_LEDGERS[version]
                reg.HISTORICAL_LEDGERS[version] = (commit, altered)
                try:
                    ok, notes = reg.verify_historical(version)
                finally:
                    reg.HISTORICAL_LEDGERS[version] = saved
            self.assertFalse(ok, version)

    def test_v7_retained_producer_and_current_classifications(self):
        # Live admission-reason edits change the whole-file producer hash, not
        # the signed accounting law. Prove the immutable record with its actual
        # old producer, then compare every current reduction field except that
        # deliberately different producer-file identity.
        ok, notes = reg.verify_historical("v7")
        self.assertTrue(ok, notes)
        retained = reg.load(reg.LEDGER_V7)
        current = json.loads(json.dumps(reg.reledger()))
        self.assertEqual(current["input"]["reducer_sha256_lf"], reg.lf_sha256(Path(reg.__file__)))
        self.assertEqual(retained["input"].pop("reducer_sha256_lf"),
                         "e34ef2f75391ac31ec5ce29f416256dc6945df08977f7e755303d2a258f98998")
        current["input"].pop("reducer_sha256_lf")
        self.assertEqual(retained, current)
        v6 = current
        self.assertEqual(v6["rule"], "lcb-signed-ledger-v7")
        self.assertEqual(v6["open_unexplained_or_malformed"], [])
        self.assertEqual(v6["changed_from_v6"], [])
        timing = ["lcb.mixed.repeated-openings.v1", "lcb.rest.remote-disturbance.v1",
                  "lcb.rest.two-pool-partial-activity.v1", "lcb.shallow.stream-steps.v1"]
        reaction = ["lcb.granular.salt-dissolution.v1", "lcb.mixed.sodium-oil-fire.v1",
                    "lcb.mixed.water-oil-brine.v1"]
        self.assertEqual(v6["accounting_unverified_ineligible_for_acceptance"], sorted(timing + reaction))
        self.assertEqual(sum(c["state"] == "closed" for c in v6["cases"].values()), 20)


if __name__ == "__main__":
    unittest.main()
