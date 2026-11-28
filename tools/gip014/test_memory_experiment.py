"""Synthetic experiment/custody controls only; these tests never run a game."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import qualify_memory as memory


CONTEXT = {"fixture_id": "construction", "fixture_version": 2,
           "fixture_sha256": "a" * 64, "provenance_sha256": "b" * 64}


def synthetic_record(name, score, sequence, actions):
    return {"id": name, "score": score, "sequence": sequence, "context": copy.deepcopy(CONTEXT),
            "reusable": True, "prefix_complete": True, "classification": "legal_unusual_gameplay",
            "actions": copy.deepcopy(actions)}


def synthetic_capture(source, cells, operation):
    return {"source_matches": True, "source_before": copy.deepcopy(source), "source_after": copy.deepcopy(source),
            "region": [32, 32, 8, 8], "materials": list(cells),
            "admission": {"status": "queued", "operation_id": operation},
            "native_receipt": {**source, "observed_generation": source["generation"], "operation_id": operation,
                               "status": "completed", "kind": "capture", "backend": "CyberNativeCellWorld"}}


def synthetic_prefix():
    before = {"generation": 3, "revision": 3, "tick": 0, "paused": True, "failed": False}
    after = {**before, "revision": 67}
    rows = [{"index": index + 1, "action": copy.deepcopy(action), "status": "completed",
             "admission": {"accepted": True, "status": "accepted"},
             "before": {"native": copy.deepcopy(before)}, "after": {"native": copy.deepcopy(after)}}
            for index, action in enumerate(memory.PREFIX)]
    rows[-1]["capture_before"] = synthetic_capture(before, [0] * 64, 1)
    rows[-1]["capture_after"] = synthetic_capture(after, [58] * 64, 3)
    return {"steps": rows, "policy_summary": {"retained_prefix_actions_proposed": 4,
            "retained_prefix_actions_queued": 4, "memory": {"total_observed": 68}}}


def synthetic_result(case_id, arm, seed, seconds=10):
    keys = {dimension: ["old", "new"] for dimension in memory.coverage.DIMENSIONS}
    return {"case_id": case_id, "arm": arm, "launch": memory.config("COVERAGE_HUNTER", seed, arm),
            "status": "pass", "memory_integrity": True, "summary": {"termination": "budget_complete"},
            "process": {"elapsed_seconds": seconds, "peak_tree_rss_bytes": 1000},
            "coverage": {"keys": keys, "unique": {key: len(value) for key, value in keys.items()},
                         "recorded_coverage_present": True, "recorded_count_mismatches": [],
                         "recorded_dimension_mismatches": [], "attempted_records": 64,
                         "admitted_observed_actions": 63, "completed_admitted_actions": 62,
                         "partial_admitted_actions": 1, "refused_actions": 1}}


class MemoryExperimentControls(unittest.TestCase):
    def test_actual_prefix_rank_uses_exact_context_and_import_demotion(self):
        records = [synthetic_record("higher", 20, 1, memory.PREFIX[:1]),
                   synthetic_record("selected", 10, 3, memory.PREFIX),
                   synthetic_record("tie-before", 10, 2, memory.PREFIX[:2]),
                   synthetic_record("foreign", 90, 4, memory.PREFIX),
                   synthetic_record("claimed-confirmed", 99, 5, memory.PREFIX)]
        records[3]["context"]["provenance_sha256"] = "c" * 64
        records[4]["classification"] = "confirmed_production_gameplay_defect"
        selection = memory.selected_prefix({"records": records}, CONTEXT)
        self.assertEqual(selection["candidate_order_ids"], ["higher", "tie-before", "selected"])
        self.assertEqual(selection["seeds"], [66, 130])
        self.assertTrue(all((seed % 64) % 3 == 2 for seed in selection["seeds"]))
        self.assertEqual(records[4]["classification"], "confirmed_production_gameplay_defect")

    def test_no_selected_prefix_or_ambiguous_prefix_is_not_invented(self):
        one = synthetic_record("one", 10, 1, memory.PREFIX)
        with self.assertRaises(ValueError):
            memory.selected_prefix({"records": []}, CONTEXT)
        with self.assertRaises(ValueError):
            memory.selected_prefix({"records": [one, {**one, "id": "duplicate"}]}, CONTEXT)
        one["reusable"] = False
        with self.assertRaises(ValueError):
            memory.selected_prefix({"records": [one]}, CONTEXT)

    def test_matched_plan_has_six_fixed_treatments_without_feedback(self):
        plan = memory.measured_plan({"seeds": [66, 130]})
        self.assertEqual(len({row["case_id"] for row in plan}), 6)
        self.assertEqual([row["arm"] for row in plan[:3]], list(memory.ARMS))
        self.assertEqual([row["arm"] for row in plan[3:]], list(reversed(memory.ARMS)))
        for seed in (66, 130):
            self.assertEqual({row["arm"] for row in plan if row["seed"] == seed}, set(memory.ARMS))
        for arm in memory.ARMS:
            launch = memory.config("COVERAGE_HUNTER", 66, arm)
            self.assertEqual((launch["fixture_id"], launch["budget"], launch["pacing_ms"]), ("construction", 64, 0))
            self.assertIs(launch["reuse_memory"], arm == "explicit_prefix")

    def test_prefix_requires_actual_source_matched_material_change(self):
        tape = synthetic_prefix()
        self.assertTrue(memory.prefix_proof(tape)["valid"])
        self.assertEqual(memory.prefix_proof(tape)["actual_changed_cells"], 64)
        tape["steps"][-1]["capture_after"]["native_receipt"]["tick"] += 1
        self.assertFalse(memory.prefix_proof(tape)["valid"])
        self.assertIsNone(memory.prefix_proof(tape)["actual_changed_cells"])

    def test_prefix_rejects_refusal_wrong_arguments_and_unchanged_cells(self):
        for mutate in (
            lambda tape: tape["steps"][1].update(status="refused"),
            lambda tape: tape["steps"][3]["action"]["args"].update(x1=40),
            lambda tape: tape["steps"][3]["capture_after"].update(materials=[0] * 64),
        ):
            tape = synthetic_prefix()
            mutate(tape)
            self.assertFalse(memory.prefix_proof(tape)["valid"])

    def test_memory_counter_requires_actual_import_and_proposed_prefix(self):
        tape = synthetic_prefix()
        self.assertTrue(memory.memory_integrity(tape, "explicit_prefix", 64, 68))
        self.assertFalse(memory.memory_integrity(tape, "explicit_prefix", 0, 68))
        self.assertFalse(memory.memory_integrity(tape, "explicit_prefix", 64, 4))
        tape["policy_summary"]["retained_prefix_actions_proposed"] = 1
        self.assertFalse(memory.memory_integrity(tape, "explicit_prefix", 64, 68))

    def test_hints_import_does_not_claim_prefix_reuse(self):
        tape = synthetic_prefix()
        tape["policy_summary"].update(retained_prefix_actions_proposed=0, retained_prefix_actions_queued=0)
        self.assertTrue(memory.memory_integrity(tape, "hints_only", 64, 68))
        self.assertFalse(memory.memory_integrity(tape, "fresh", 0, 68))
        tape["policy_summary"]["memory"]["total_observed"] = 4
        self.assertTrue(memory.memory_integrity(tape, "fresh", 0, 4))

    def test_early_failure_length_difference_is_not_changed_choice(self):
        a, b = synthetic_prefix(), synthetic_prefix()
        b["steps"] = b["steps"][:2]
        result = memory.choice_change(a, b)
        self.assertFalse(result["observed_choice_change"])
        self.assertTrue(result["different_recorded_lengths"])
        self.assertFalse(memory.choice_change(a, None)["available"])

    def test_actual_different_choice_reports_first_difference_and_state_scope(self):
        a, b = synthetic_prefix(), synthetic_prefix()
        b["steps"][2]["action"]["args"]["material"] = 3
        b["steps"][2]["before"]["material"] = 3
        result = memory.choice_change(a, b)
        self.assertTrue(result["observed_choice_change"])
        self.assertEqual(result["first_different_action_index"], 2)
        self.assertTrue(result["same_prior_action_prefix"])
        self.assertFalse(result["before_abstract_state_equal"])

    def test_missing_and_failed_arms_are_unknown_and_cost_is_retained(self):
        selection = {"seeds": [66, 130]}
        plan = memory.measured_plan(selection)
        ledger = {"selection": selection, "measured_plan": plan, "attempts": [{}, {}, {}]}
        training = synthetic_result(memory.CULTIVATION, "fresh", 13, 9)
        training["coverage"]["keys"] = {dimension: ["old"] for dimension in memory.coverage.DIMENSIONS}
        fresh = synthetic_result(plan[0]["case_id"], "fresh", 66, 11)
        failed = synthetic_result(plan[1]["case_id"], "hints_only", 66, 15)
        failed.update(status="timeout", summary={"termination": "incomplete"})
        report = memory.comparison_report(ledger, training, [fresh, failed], {})
        self.assertEqual(report["not_registered_gameplay_slots"], 4)
        self.assertEqual(report["measured_slots_without_result"], 4)
        self.assertEqual(report["all_observed_gameplay_process_seconds_including_training"], 35)
        self.assertFalse(any(pair["eligible"] for pair in report["paired_differences"]))
        missing = report["measured_episodes"][2]
        self.assertEqual(missing["status"], "not_attempted")
        self.assertIsNone(missing["coverage_unique"])
        self.assertIsNone(missing["counts"]["completed_admitted_actions"])
        self.assertEqual(report["measured_episodes"][0]["new_keys_beyond_training"]["action"], 1)
        self.assertIsNone(report["measured_episodes"][1]["new_keys_beyond_training"])

    def test_complete_pairs_use_actual_completed_denominator_and_exclude_imported_keys(self):
        selection = {"seeds": [66, 130]}
        plan = memory.measured_plan(selection)
        ledger = {"selection": selection, "measured_plan": plan, "attempts": [{}] * 7}
        training = synthetic_result(memory.CULTIVATION, "fresh", 13)
        results = [synthetic_result(row["case_id"], row["arm"], row["seed"]) for row in plan]
        results[1]["coverage"]["completed_admitted_actions"] = 60
        results[1]["coverage"]["partial_admitted_actions"] = 3
        report = memory.comparison_report(ledger, training, results, {})
        self.assertEqual(report["budget_complete_valid_gameplay_episodes"], 7)
        self.assertTrue(all(pair["eligible"] for pair in report["paired_differences"]))
        self.assertEqual(report["paired_differences"][0]["completed_actions_difference"], -2)
        self.assertEqual(report["measured_episodes"][0]["new_keys_beyond_training"]["action"], 0)
        self.assertFalse(report["statistical_inference_performed"])
        self.assertFalse(report["production_defect_confirmation_performed"])

    def test_custody_paths_cannot_escape_or_select_a_link(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            with self.assertRaises(ValueError):
                memory._path(root, "../outside.json")
            target = root / "target.json"
            target.write_text("{}")
            try:
                (root / "link.json").symlink_to(target)
            except OSError:
                return  # Windows may lack symlink privileges; traversal above still ran.
            with self.assertRaises(ValueError):
                memory._path(root, "link.json")

    def test_wrong_engine_bytes_are_refused_before_any_process_or_source_probe(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            engine = root / "fake-engine"
            engine.write_bytes(b"synthetic non-engine")
            with patch.object(memory.runner, "git", side_effect=AssertionError("must not probe source")), \
                    patch.object(memory.owned_process, "execute", side_effect=AssertionError("must not execute")):
                with self.assertRaisesRegex(ValueError, "Pinned Linux Godot"):
                    memory.qualify(engine, root / "result")
            self.assertFalse((root / "result").exists())

    def test_aggregate_deadline_and_cancel_refuse_next_process(self):
        with tempfile.TemporaryDirectory() as folder:
            cancel = Path(folder) / "cancel.json"
            with patch.object(memory.time, "monotonic", return_value=100):
                with self.assertRaisesRegex(RuntimeError, "Aggregate wall bound"):
                    memory._room(200, memory.GAME_SECONDS, cancel)
                memory._room(400, memory.GAME_SECONDS, cancel)
                cancel.write_text("{}")
                with self.assertRaisesRegex(RuntimeError, "cancellation"):
                    memory._room(400, memory.GAME_SECONDS, cancel)

    def test_read_only_analysis_does_not_launch_or_rewrite_raw_evidence(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            ledger = {"schema": memory.SCHEMA, "reader_sha256": memory.tool_hashes(),
                      "status": "incomplete_retained", "attempts": []}
            (root / "experiment.json").write_text(json.dumps(ledger))
            before = (root / "experiment.json").read_bytes()
            with patch.object(memory.owned_process, "execute", side_effect=AssertionError("read-only launched a process")):
                report = memory.analyze(root)
            self.assertEqual(report["status"], "incomplete_or_failed")
            self.assertEqual(report["not_registered_gameplay_slots"], 7)
            self.assertIsNone(report["cultivation"]["counts"]["completed_admitted_actions"])
            self.assertEqual((root / "experiment.json").read_bytes(), before)
            self.assertEqual([path.name for path in root.iterdir()], ["experiment.json"])

    def test_pre_ledger_worker_failure_retains_all_seven_missing_slots(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "supervisor.json").write_text(json.dumps({"status": "cancelled", "exit_code": -9, "interrupted": True}))
            with patch.object(memory.owned_process, "execute", side_effect=AssertionError("must not launch")):
                report = memory.analyze(root)
            self.assertEqual(report["experiment_status"], "worker_ended_before_ledger")
            self.assertEqual(report["planned_gameplay_episodes"], 7)
            self.assertEqual(report["planned_slots_without_validated_result"], 7)
            self.assertEqual(report["measured_slots_without_result"], 6)
            self.assertTrue(report["operator_cancelled"])
            self.assertIsNone(report["cultivation"]["counts"]["completed_admitted_actions"])

    def test_source_archive_requires_exact_members_and_bytes(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            payload = b"# synthetic non-executed source\n"
            snapshot = {"files": {"goblin/synthetic.gd": memory.hashlib.sha256(payload).hexdigest(),
                                   "excluded.svg": "a" * 64}}
            path = root / "executed-game-source.zip"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("goblin/synthetic.gd", payload)
            self.assertEqual(memory.source_archive_record(root, snapshot)["members"],
                             {"goblin/synthetic.gd": snapshot["files"]["goblin/synthetic.gd"]})
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("goblin/synthetic.gd", b"changed bytes")
            with self.assertRaisesRegex(ValueError, "member changed"):
                memory.source_archive_record(root, snapshot)
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("goblin/synthetic.gd", payload)
                archive.writestr("extra.gd", b"extra")
            with self.assertRaisesRegex(ValueError, "membership differs"):
                memory.source_archive_record(root, snapshot)

    def test_incomplete_result_can_retain_checked_process_cost_without_gameplay_success(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "campaign.log").write_text("synthetic owned process receipt\n")
            process = {"status": "timeout", "elapsed_seconds": 180.3,
                       "log_sha256": memory.runner.sha_file(root / "campaign.log")}
            (root / "process.json").write_text(json.dumps(process))
            checked = memory._checked_process(root)
            result = {"case_id": "incomplete", "status": "incomplete_attempt", "process": checked}
            report = memory.comparison_report({"attempts": [result]}, result, [], {})
            self.assertEqual(report["all_observed_gameplay_process_seconds_including_training"], 180.3)
            self.assertEqual(report["budget_complete_valid_gameplay_episodes"], 0)
            self.assertEqual(report["process_status_inventory"], {"timeout": 1})
            (root / "campaign.log").write_text("changed log")
            with self.assertRaisesRegex(ValueError, "custody"):
                memory._checked_process(root)

    def test_source_identity_change_is_a_distinct_custody_failure(self):
        with patch.object(memory.runner, "git", return_value="other"):
            with self.assertRaises(memory.CustodyError):
                memory._source_guard("source", "tree")


if __name__ == "__main__":
    unittest.main()
