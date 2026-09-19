import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import stage3b_validation as v


class Stage3BValidationTests(unittest.TestCase):
    def final_plan(self):
        return v.build_plan("deadbeef", "final")

    def test_fixture_catalogue_preserves_historical_meanings_and_true_one_cell_edits(self):
        fixtures = v.fixture_catalogue()
        v.validate_fixtures(fixtures)
        self.assertEqual(len(fixtures), 168)
        self.assertIn("not-applicable", {x["id"]: x for x in fixtures}["one-cell.negative_temperature.tile-interior"]["expected_outcomes"])
        by_id = {item["id"]: item for item in fixtures}
        self.assertEqual(by_id["historical.local-edit-8x8"]["retained_meaning"], "8x8 patch edit")
        self.assertEqual(by_id["historical.bridge-whole-column"]["retained_meaning"], "whole-column change")
        one_cell = [item for item in fixtures if item["family"] == "genuine-one-cell-edit"]
        self.assertEqual(len(one_cell), 32)
        self.assertTrue(all(item["intended_changed_cell_count"] == 1 for item in one_cell))
        self.assertEqual(by_id["topology.one-cell-bridge-add"]["intended_changed_cell_count"], 1)
        self.assertEqual(by_id["topology.one-cell-bridge-remove"]["intended_changed_cell_count"], 1)
        self.assertTrue(all(len(item["protocol_sha256"]) == 64 for item in fixtures))
        one = by_id["one-cell.material.tile-face"]
        self.assertEqual(one["protocol"]["operations"][0]["at"], [31, 16])
        self.assertEqual(one["protocol"]["operations"][0]["authoritative_cells_changed"], 1)
        historical = by_id["historical.local-edit-8x8"]["protocol"]["operations"][0]
        self.assertEqual(historical["rect"], [28, 28, 8, 8])
        self.assertEqual(historical["every_iterations"], 16)
        self.assertEqual(v.BASE_TUPLE["temperature"], 200)
        self.assertIn("x==32", by_id["historical.ring"]["protocol"]["setup"]["solid_predicate"])
        halo = by_id["aba.event-dependency-halo-fanout"]["protocol"]
        halo_op = halo["operations"][0]
        self.assertEqual(halo_op["maximum_rule_radius"], 1)
        self.assertEqual(halo_op["effect_footprint_extra"], 2)
        self.assertEqual(halo_op["pending_observation_half_extent"], 5)
        self.assertIn("pending observation half-extent is (radius + 2) + maximum_rule_radius", halo["assertions"])
        replacement = by_id["failure.allocation-failure-observer-replacement"]
        self.assertEqual(replacement["expected_outcomes"], ["refused"])
        replacement_protocol = replacement["protocol"]
        self.assertIn("replacement construction failure leaves discovery unavailable and World not failed", replacement_protocol["assertions"])
        self.assertIn("later successful clear constructs a fresh observer incarnation; no stale handle revives", replacement_protocol["assertions"])

    def test_final_plan_freezes_workers_budgets_repeats_and_explicit_unavailability(self):
        plan = self.final_plan()
        v.validate_plan(plan)
        self.assertEqual(plan["workers"], [1, 4])
        self.assertEqual(plan["fixed_primitive_budgets"], [1, 8, 64, 256, 1024])
        self.assertEqual(plan["repeat_policy"]["paired_drain_cells"], 5)
        self.assertEqual(plan["repeat_policy"]["fixed_budget_cells"], 5)
        arms = {arm["id"]: arm for arm in plan["arms"]}
        self.assertEqual(arms["stage3b-candidate"]["availability"], "unavailable")
        self.assertEqual(len(plan["runs"]), 6488)
        self.assertTrue(any(row["run_state"] == "unavailable" for row in plan["runs"]))
        fixture_hashes = {item["id"]: item["protocol_sha256"] for item in plan["fixture_catalogue"]["fixtures"]}
        self.assertTrue(all(row["fixture_protocol_sha256"] == fixture_hashes[row["fixture_id"]] for row in plan["runs"]))

    def test_plan_generation_is_deterministic(self):
        a = self.final_plan()
        b = self.final_plan()
        self.assertEqual(v.pdigest(a), v.pdigest(b))
        self.assertEqual(a["runs"], b["runs"])

    def test_even_repeat_reverses_arm_order(self):
        plan = self.final_plan()
        rows = [row for row in plan["runs"]
                if row["fixture_id"] == "quiet.initial-512"
                and row["worker_count"] == 1
                and row["service_mode"] == "drain"]
        odd = [row["arm_id"] for row in rows if row["repeat_index"] == 1]
        even = [row["arm_id"] for row in rows if row["repeat_index"] == 2]
        self.assertEqual(even, list(reversed(odd)))

    def test_executed_result_requires_provenance_and_failure_kind(self):
        plan = v.build_plan("deadbeef", "smoke")
        row = next(row for row in plan["runs"] if row["arm_id"] == "current-discovery-disabled")
        success = v.result_template(row, "success")
        with self.assertRaisesRegex(ValueError, "missing provenance"):
            v.validate_result(success, row)
        success["provenance"].update({
            "source_commit": "deadbeef", "dirty_status": "clean",
            "source_input_hashes": {}, "compiler_executable": "cc",
            "compiler_version": "test", "compiler_sha256": "cc-hash",
            "flags": [], "executable_sha256": "exe-hash", "capacities": {},
            "hardware": {}, "os": "test", "power_mode": "test",
            "stdout_identity": "stdout", "stderr_identity": "stderr",
            "raw_result_identity": "raw",
        })
        v.validate_result(success, row)
        wrong_protocol = copy.deepcopy(success)
        wrong_protocol["provenance"]["authoritative_mutation_schedule"]["protocol_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "fixture protocol provenance mismatch"):
            v.validate_result(wrong_protocol, row)
        unsupported = copy.deepcopy(success)
        unsupported["measurements"]["end_to_end"]["service_call_latency_sample_count"] = 5
        unsupported["measurements"]["end_to_end"]["service_call_latency_p95_ms"] = 1.0
        with self.assertRaisesRegex(ValueError, "p95 requires at least 20 samples"):
            v.validate_result(unsupported, row)
        failed = copy.deepcopy(success)
        failed["state"] = "timeout"
        with self.assertRaisesRegex(ValueError, "explicit failure kind"):
            v.validate_result(failed, row)

    def test_current_cannot_fabricate_observer_measurements(self):
        plan = v.build_plan("deadbeef", "smoke")
        row = next(row for row in plan["runs"] if row["arm_id"] == "current-discovery-disabled")
        value = v.result_template(row, "success")
        value["provenance"].update({
            "source_commit": "deadbeef", "dirty_status": "clean",
            "source_input_hashes": {}, "compiler_executable": "cc",
            "compiler_version": "test", "compiler_sha256": "cc-hash",
            "flags": [], "executable_sha256": "exe-hash", "capacities": {},
            "hardware": {}, "os": "test", "power_mode": "test",
            "stdout_identity": "stdout", "stderr_identity": "stderr",
            "raw_result_identity": "raw",
        })
        value["measurements"]["producer_signal"]["changed_coverage"] = 0
        with self.assertRaisesRegex(ValueError, "fabricated observer"):
            v.validate_result(value, row)

    def test_synthetic_smoke_reduces_success_and_unavailable_without_blank_rows(self):
        plan, results, report = v.synthetic_smoke("deadbeef")
        self.assertEqual(len(results), len(plan["runs"]))
        self.assertGreater(report["state_counts"]["success"], 0)
        self.assertGreater(report["state_counts"]["unavailable"], 0)
        self.assertEqual(report["missing_available_run_ids"], [])
        self.assertEqual(len(report["provenance_index"]), len(results))
        self.assertIn("successful_numeric_metrics", report["summaries"][0])
        self.assertEqual(report["summary_statistics_policy"]["p95_min_samples"], 20)
        before = copy.deepcopy(results)
        rerun = v.reduce_results(plan, results)
        self.assertEqual(results, before)
        self.assertEqual(rerun["state_counts"], report["state_counts"])
        self.assertTrue(all(item["state"] in v.RESULT_STATES for item in results))


if __name__ == "__main__":
    unittest.main()
