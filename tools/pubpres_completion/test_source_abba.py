#!/usr/bin/env python3
"""Reject source-cohort claims with a reordered or physically unmatched arm."""

import copy
import json
from pathlib import Path
import unittest

from run_main_abba import CASE_ORDER, ORDER as MAIN_ORDER, comparison_campaign
from run_source_abba import compare_registered_direction, validate_source_cohort


def cohort():
    sources = {"D": "d" * 40, "C": "c" * 40}
    results = []
    selectors = {"physics": "early", "presentation": "coherent", "cadence": "repaired",
                 "rendezvous": {"mode": "off"}}
    for index, role in enumerate(("D", "C", "C", "D")):
        rate, gap = (5.0, 200.0) if role == "D" else (5.1, 190.0)
        results.append({"index": index, "arm": role, "statistics": {
            "source": sources[role], "observer_mode": "full", "match": {
                "water_law": "wave_flow_v1", "water_profile": "gameplay", "adapter": "fixture"},
            "registered_material_treatment": {"backend": "full", "policy": ""},
            "same_frame_continuation": {"enabled": False}, "selectors_before": selectors, "selectors_after": selectors,
            "first_144_body_trajectory_sha256": "body", "first_144_admitted_moves_sha256": "admitted",
            "command_counts": {"accepted": 144}, "command_mode": "repeated_callback",
            "windows": {"first_144_steps": {"completed_rapier_steps": 144, "rapier_steps_per_second": rate,
                         "physical_gap_ms": {"p95": gap, "p99": gap + 1, "max": gap + 2}}},
            "physical_gap_counts_above_ms": {"first_144_steps": {key: 0 for key in ("100", "250", "500", "1000")}},
        }})
    return results, sources


class SourceCohortTests(unittest.TestCase):
    def test_complete_ordered_exact_parity_and_repeatable_direction(self):
        arms, sources = cohort()
        self.assertEqual(len(validate_source_cohort(arms, sources)["pairs"]), 6)
        self.assertTrue(compare_registered_direction(arms)["repeatable_direction"])

    def test_rejectable_physical_outcome_and_requested_source_mismatches(self):
        arms, sources = cohort()
        for field, value in (
            ("first_144_body_trajectory_sha256", "different"),
            ("first_144_admitted_moves_sha256", "different"),
            ("source", "0" * 40),
            ("registered_material_treatment", {"backend": "blit"}),
            ("same_frame_continuation", {"enabled": True}),
        ):
            with self.subTest(field=field), self.assertRaises(ValueError):
                changed = copy.deepcopy(arms)
                changed[1]["statistics"][field] = value
                validate_source_cohort(changed, sources)
        with self.assertRaises(ValueError):
            validate_source_cohort([arms[0], arms[2], arms[1], arms[3]], sources)

    def test_one_favourable_candidate_cannot_establish_relative_gain(self):
        arms, _ = cohort()
        arms[1]["statistics"]["windows"]["first_144_steps"]["rapier_steps_per_second"] = 100
        arms[2]["statistics"]["windows"]["first_144_steps"]["rapier_steps_per_second"] = 4.99
        self.assertEqual(compare_registered_direction(arms)["disposition"], "NOT_ESTABLISHED")

    def test_faster_candidate_cannot_hide_worse_maximum_or_severe_freeze(self):
        arms, _ = cohort()
        stats = arms[1]["statistics"]
        stats["windows"]["first_144_steps"]["physical_gap_ms"]["max"] = 600
        stats["physical_gap_counts_above_ms"]["first_144_steps"]["500"] = 1
        result = compare_registered_direction(arms)
        self.assertTrue(result["all_candidate_rates_higher"])
        self.assertTrue(all(result["all_candidate_gap_quantiles_lower"].values()))
        self.assertFalse(result["all_candidate_max_gaps_within_worst_reference"])
        self.assertFalse(result["all_candidate_severe_counts_within_worst_reference"]["500"])
        self.assertEqual(result["disposition"], "NOT_ESTABLISHED")

    def test_independent_current_main_treatment_registers_two_balanced_cases(self):
        tools = Path(__file__).resolve().parents[1]
        frozen = (tools / "pubpres_playability/campaign.json").read_bytes()
        settings = json.loads(Path(__file__).with_name("registration.json").read_bytes())
        campaign = comparison_campaign(frozen, settings)
        predecessor = json.loads(frozen)
        self.assertEqual(tuple(case["id"] for case in campaign["cases"]), CASE_ORDER)
        self.assertTrue(all(tuple(case["arm_order"]) == MAIN_ORDER for case in campaign["cases"]))
        self.assertEqual(campaign["source_commits"]["main"], settings["reference_sources"]["M"]["source_commit"])
        self.assertEqual(campaign["arms"]["M"], predecessor["arms"]["M"])
        self.assertEqual(campaign["arms"]["I"], predecessor["arms"]["I"])
        self.assertEqual(campaign["arms"]["C"]["material"], "full")
        self.assertIs(campaign["arms"]["C"]["same_frame_continuation"], False)
        self.assertIs(campaign["cases"][0]["compatibility_preflight"]["performance_capture_attempted"], False)

    def test_main_cohort_rejects_integrated_treatment_on_historical_baseline(self):
        arms, sources = cohort()
        sources["M"] = sources.pop("D")
        for index in (0, 3):
            arms[index]["arm"] = "M"
            state = dict.fromkeys(("material", "physics", "presentation", "cadence", "rendezvous"))
            state["requested"] = {"CYBERSAND_DIAG_PHYSICS_PUBLICATION": "combined", "CYBERSAND_DIAG_PRESENTATION": "legacy"}
            arms[index]["statistics"].update(selectors_before=state, selectors_after=state)
        self.assertEqual(len(validate_source_cohort(arms, sources, MAIN_ORDER)["pairs"]), 6)
        self.assertEqual(compare_registered_direction(arms, reference="M")["reference_role"], "M")
        arms[0]["statistics"]["selectors_after"]["physics"] = "early"
        with self.assertRaisesRegex(ValueError, "Accepted main acquired"):
            validate_source_cohort(arms, sources, MAIN_ORDER)


if __name__ == "__main__":
    unittest.main()
