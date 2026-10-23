"""Synthetic regressions for the signed campaign ledger (lcb-signed-ledger-v4).

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


class RetainedRecords(unittest.TestCase):
    def test_historical_controls_preserved(self):
        self.assertEqual(reg.lf_sha256(reg.CONTROLS),
                         "989ff70dba646285991a2a5e8ca5c3b0aa94b9381dc44c849528518e4238fac1")

    def test_v2_verifies_against_its_frozen_reducer(self):
        expected = json.dumps(reg.reledger_v2(), indent=2) + "\n"
        self.assertEqual(reg.LEDGER_V2.read_text(encoding="utf-8").replace("\r\n", "\n"), expected)
        self.assertEqual(json.loads(expected)["input"]["reducer_sha256_lf"],
                         "56293fc96c243423f90b2381d98c5b54f5aff83b06fcfd8bad8d32befa3e6583")

    def test_v3_verifies_against_its_frozen_reducer(self):
        self.assertEqual(reg.lf_sha256(reg.LEDGER_V3),
                         "b70f325739035e943e27a8b36273757e054db4092fda0ed113d1db89485d399b")
        expected = json.dumps(reg.reledger_v3(), indent=2) + "\n"
        self.assertEqual(reg.LEDGER_V3.read_text(encoding="utf-8").replace("\r\n", "\n"), expected)
        self.assertEqual(json.loads(expected)["input"]["reducer_sha256_lf"],
                         "23dcb9a25649d1560ce2b319dd24402fabc6ef7415ee66ff2ccb484a15734355")

    def test_v4_current_and_classifications(self):
        expected = json.dumps(reg.reledger(), indent=2) + "\n"
        self.assertEqual(reg.LEDGER_V4.read_text(encoding="utf-8").replace("\r\n", "\n"), expected)
        v4 = json.loads(expected)
        self.assertEqual(v4["rule"], "lcb-signed-ledger-v4")
        self.assertEqual(v4["open_unexplained_or_malformed"], [])
        self.assertEqual(v4["changed_from_v3"], [])
        timing = ["lcb.mixed.repeated-openings.v1", "lcb.rest.remote-disturbance.v1",
                  "lcb.rest.two-pool-partial-activity.v1", "lcb.shallow.stream-steps.v1"]
        reaction = ["lcb.granular.salt-dissolution.v1", "lcb.mixed.sodium-oil-fire.v1",
                    "lcb.mixed.water-oil-brine.v1"]
        self.assertEqual(v4["accounting_unverified_ineligible_for_acceptance"], sorted(timing + reaction))
        self.assertTrue(all(v4["cases"][s]["state"] == "UNVERIFIED_SOURCE_SINK_TIMING" for s in timing))
        self.assertTrue(all(v4["cases"][s]["state"] == "UNVERIFIED_REACTION_AMOUNT" for s in reaction))


if __name__ == "__main__":
    unittest.main()
