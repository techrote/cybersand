"""Artificial matched-cohort controls; no game simulation or defect evidence."""
import copy
import unittest

import paired_comparison as paired


def synthetic_plan_and_results():
    rows, results = [], []
    fixtures = ("construction", "liquid_channel", "actor_workshop", "history_edges")
    for fixture_index, fixture in enumerate(fixtures):
        for seed_index, seed in enumerate((13, 605, 1701)):
            for mode_index, mode in enumerate(paired.MATCHED_MODES):
                episode = {"id": f"matched-{len(rows):04d}-{mode.lower()}-{fixture}-s{seed}-n64",
                           "cohort": "matched", "fixture": fixture, "policy": mode, "seed": seed,
                           "budget": 64, "timeout_seconds": 210}
                rows.append(episode)
                unique = {name: 1 for name in paired.DIMENSIONS}
                unique["action"] = 2
                unique["state_transition"] = 12 + fixture_index * 3 + seed_index * 2 + mode_index
                coverage = {"schema": "cybersand-goblin-independent-coverage-v1",
                            "attempted_records": 64, "admitted_observed_actions": 64,
                            "completed_admitted_actions": 64, "partial_admitted_actions": 0,
                            "refused_actions": 0, "records_without_native_observation": 0,
                            "unique": unique, "state_action_pairs": unique["state_transition"],
                            "recorded_coverage_present": True, "recorded_count_mismatches": [],
                            "recorded_dimension_mismatches": []}
                results.append({"episode": episode, "attempt_number": 1, "status": "pass",
                                "evidence_kind": "unit_fixture", "coverage": coverage,
                                "summary": {"completed_features": {"pause": 32, "brush": 32}},
                                "process": {"elapsed_seconds": 10.0, "peak_tree_rss_bytes": 1000}})
    plan = {"kind": "matched", "episodes": rows, "corpus_reuse": False, "pacing_ms": 0,
            "provenance": {"source_commit": "1" * 40, "source_tree": "2" * 40, "source_dirty": False},
            "plan_sha256": "3" * 64, "evidence_kind": "unit_fixture"}
    return plan, results


def contrast(report, candidate="COVERAGE_HUNTER", baseline="RANDOM"):
    return next(row for row in report["paired_comparisons"]
                if row["candidate"] == candidate and row["baseline"] == baseline)


def selected_mode(results, mode="COVERAGE_HUNTER"):
    return next(row for row in results if row["episode"]["policy"] == mode)


class PairedComparisonControls(unittest.TestCase):
    def test_artificial_complete_plan_has_twelve_blocks_and_exact_descriptive_difference(self):
        plan, results = synthetic_plan_and_results()
        report = paired.compare(results, plan, results)
        self.assertEqual(report["planned_episodes"], 108)
        self.assertEqual(report["matched_block_count"], 12)
        self.assertEqual(report["complete_matched_blocks"], 12)
        delta = contrast(report)["metrics"]["unique_state_transition"]["candidate_minus_baseline"]
        self.assertEqual(delta["observed"], 12)
        self.assertEqual((delta["minimum"], delta["p25"], delta["median"], delta["p75"], delta["maximum"]),
                         (3, 3, 3, 3, 3))
        self.assertFalse(report["statistical_inference_performed"])
        self.assertEqual(report["confirmed_production_defects"], [])
        behavior = report["groups"]["matched/COVERAGE_HUNTER"]["observed_behavior"]
        self.assertEqual(behavior["shannon_entropy_bits"], 1)
        self.assertEqual(behavior["effective_action_types"], 2)

    def test_missing_episode_is_unknown_and_removes_only_its_eligible_pair(self):
        plan, results = synthetic_plan_and_results()
        results.remove(selected_mode(results))
        report = paired.compare(results, plan)
        self.assertEqual(report["complete_matched_blocks"], 11)
        self.assertEqual(contrast(report)["eligible_blocks"], 11)
        self.assertEqual(contrast(report, "STATEFUL")["eligible_blocks"], 12)
        values = report["groups"]["matched/COVERAGE_HUNTER"]["all_planned_episode_metrics"]["unique_state_transition"]
        self.assertEqual((values["observed"], values["missing"]), (11, 1))
        self.assertGreater(values["minimum"], 0)
        self.assertFalse(report["all_attempt_cost"]["available"])

    def test_partial_valid_observations_survive_without_becoming_complete_episode(self):
        plan, results = synthetic_plan_and_results()
        row = selected_mode(results)
        row["status"] = "resource_limit"
        row["coverage"].update(attempted_records=12, admitted_observed_actions=10,
                               completed_admitted_actions=8, partial_admitted_actions=2, refused_actions=1)
        row["coverage"]["unique"]["state_transition"] = 7
        row["summary"]["completed_features"] = {"brush": 8}
        report = paired.compare(results, plan)
        group = report["groups"]["matched/COVERAGE_HUNTER"]
        self.assertEqual(group["attempted_budget_completed_episodes"], 11)
        self.assertEqual(group["all_planned_episode_metrics"]["completed_actions"]["minimum"], 8)
        self.assertEqual(group["all_planned_episode_metrics"]["partial_actions"]["maximum"], 2)
        self.assertEqual(group["budget_complete_episode_metrics"]["completed_actions"]["minimum"], 64)
        self.assertEqual(contrast(report)["eligible_blocks"], 11)

    def test_observed_zero_is_retained_while_zero_admission_rate_is_undefined(self):
        plan, results = synthetic_plan_and_results()
        row = selected_mode(results)
        row["coverage"].update(admitted_observed_actions=0, completed_admitted_actions=0,
                               partial_admitted_actions=0, refused_actions=64, state_action_pairs=0)
        row["coverage"]["unique"] = {name: 0 for name in paired.DIMENSIONS}
        row["summary"]["completed_features"] = {}
        report = paired.compare(results, plan)
        group = report["groups"]["matched/COVERAGE_HUNTER"]
        self.assertEqual(group["attempted_budget_completed_episodes"], 12)
        observed = group["all_planned_episode_metrics"]["completed_actions"]
        self.assertEqual((observed["observed"], observed["missing"], observed["minimum"]), (12, 0, 0))
        rate = group["all_planned_episode_metrics"]["state_transitions_per_100_admitted"]
        self.assertEqual((rate["observed"], rate["missing"]), (11, 1))
        self.assertEqual(contrast(report)["eligible_blocks"], 12)

    def test_evidence_mismatch_excludes_coverage_without_erasing_measured_resource_cost(self):
        plan, results = synthetic_plan_and_results()
        row = selected_mode(results)
        row["coverage"]["recorded_dimension_mismatches"] = ["state_transition"]
        report = paired.compare(results, plan)
        group = report["groups"]["matched/COVERAGE_HUNTER"]
        self.assertEqual(group["coverage_availability"]["recorded_coverage_mismatch"], 1)
        self.assertEqual(group["all_planned_episode_metrics"]["unique_state_transition"]["missing"], 1)
        self.assertEqual(group["all_planned_episode_metrics"]["wall_seconds"]["observed"], 12)
        self.assertEqual(contrast(report)["eligible_blocks"], 11)

    def test_retry_cost_and_first_attempt_failure_are_retained(self):
        plan, results = synthetic_plan_and_results()
        retry = selected_mode(results)
        original = copy.deepcopy(retry)
        original["status"] = "resource_limit"
        original["process"]["elapsed_seconds"] = 30
        original["process"]["peak_tree_rss_bytes"] = 3000
        retry["attempt_number"] = 2
        attempts = [copy.deepcopy(row) for row in results] + [original]
        report = paired.compare(results, plan, attempts)
        all_cost = report["all_attempt_cost"]
        self.assertEqual(all_cost["attempts"], 109)
        self.assertEqual(all_cost["known_wall_seconds"], 1110)
        self.assertEqual(all_cost["first_attempt_budget_completed_episodes"], 107)
        self.assertEqual(all_cost["peak_observed_tree_rss_bytes"], 3000)
        self.assertEqual(report["groups"]["matched/COVERAGE_HUNTER"]["latest_attempt_cost"]["known_wall_seconds"], 120)
        self.assertEqual(all_cost["groups"]["matched/COVERAGE_HUNTER"]["known_wall_seconds"], 150)

    def test_missing_process_receipt_never_becomes_zero_cost(self):
        plan, results = synthetic_plan_and_results()
        attempts = [copy.deepcopy(row) for row in results]
        attempts[0].pop("process")
        report = paired.compare(results, plan, attempts)
        cost = report["all_attempt_cost"]
        self.assertEqual(cost["known_wall_seconds"], 1070)
        self.assertEqual(cost["wall_measurements_missing"], 1)
        self.assertFalse(cost["wall_cost_complete"])
        empty = paired.distribution([None, None])
        self.assertIsNone(empty["median"])
        self.assertIsNone(empty["minimum"])

    def test_duplicate_and_foreign_identities_are_refused_before_aggregation(self):
        plan, results = synthetic_plan_and_results()
        with self.assertRaisesRegex(ValueError, "unique planned"):
            paired.compare(results[:-1] + [results[0]], plan)
        changed = copy.deepcopy(results)
        changed[0]["episode"] = dict(changed[0]["episode"], seed=999)
        with self.assertRaisesRegex(ValueError, "unique planned"):
            paired.compare(changed, plan)
        with self.assertRaisesRegex(ValueError, "unique bounded"):
            paired.compare(results, plan, results + [results[0]])
        bad_plan = copy.deepcopy(plan)
        bad_plan["episodes"][1] = copy.deepcopy(bad_plan["episodes"][0])
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            paired.compare([], bad_plan)


if __name__ == "__main__":
    unittest.main()
