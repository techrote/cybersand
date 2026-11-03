#!/usr/bin/env python3
"""Adverse controls for successor custody; synthetic rows never qualify a host."""
from __future__ import annotations

import base64
from copy import deepcopy
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

import pace004_contract as contract
import pace004_execution as execution
import run_pace004_campaign as campaign


def fixture_policy():
    source = execution.policy.identity()
    return {"ok": True, "schema_version": source["schema_version"], "scale": source["scale"],
            "sha256": source["sha256"], "path": "res://tests/support/ci_execution_policy.json",
            "watchdogs": {key: source["watchdogs"][key] for key in execution.GODOT_KEYS}}


class PolicyCustody(unittest.TestCase):
    def test_actual_godot_subset_is_bound_to_python_source(self):
        self.assertTrue(execution.fixture_policy_matches(fixture_policy()))

    def test_receipt_cannot_choose_a_larger_watchdog(self):
        value = fixture_policy()
        value["watchdogs"]["main_ack_seconds"] *= 2
        self.assertFalse(execution.fixture_policy_matches(value))

    def test_receipt_cannot_choose_its_policy_digest(self):
        value = fixture_policy(); value["sha256"] = "a" * 64
        self.assertFalse(execution.fixture_policy_matches(value))

    def test_boolean_scale_or_schema_is_not_numeric_one(self):
        for field in ("scale", "schema_version"):
            with self.subTest(field=field):
                value = fixture_policy(); value[field] = True
                self.assertFalse(execution.fixture_policy_matches(value))

    def test_two_cases_fit_all_children_and_dependency_stage(self):
        with patch.dict(os.environ, {execution.policy.SCALE_ENV: "1"}):
            budget = execution.budgets(2)
        self.assertEqual(budget["case_seconds"], 3940)
        self.assertEqual(budget["suite_seconds"], 12800)
        self.assertEqual(budget["suite_minutes"], 214)
        self.assertEqual(budget["dependency_stage_minutes"], 46)
        self.assertEqual(budget["readback_minutes"], 6)
        self.assertEqual(budget["process_cleanup_seconds"], 240)
        self.assertEqual(budget["import_readback_seconds"], 300)
        self.assertEqual(budget["job_minutes"], 300)
        self.assertGreaterEqual(budget["job_minutes"], budget["sequential_stage_minutes"])

    def test_three_cases_cannot_hide_inside_two_case_shard(self):
        with self.assertRaisesRegex(ValueError, "one or two"):
            execution.budgets(3)

    def test_scale_that_exceeds_host_cap_fails_without_shrinking_science(self):
        with patch.dict(os.environ, {execution.policy.SCALE_ENV: "2"}):
            with self.assertRaisesRegex(ValueError, "reduce shard size"):
                execution.budgets(2)

    def test_enlarged_scale_keeps_complete_case_union_and_all_stage_allowances(self):
        with patch.dict(os.environ, {execution.policy.SCALE_ENV: "1.25"}):
            plan = campaign.hosted_plan()
        self.assertEqual(sum(row["case_count"] for row in plan["include"]), 72)
        self.assertTrue(all(row["job_minutes"] == 360 and row["readback_minutes"] == 7
                            for row in plan["include"]))
        self.assertEqual(plan["inventory"]["job_minutes"], 330)

    def test_scale_cannot_hide_overflow_in_one_case_or_final_inventory(self):
        with patch.dict(os.environ, {execution.policy.SCALE_ENV: "2"}):
            with self.assertRaisesRegex(ValueError, "shard budget exceeds"):
                campaign.hosted_plan()
        with patch.dict(os.environ, {execution.policy.SCALE_ENV: "1.3"}):
            with self.assertRaisesRegex(ValueError, "complete inventory exceeds"):
                campaign.hosted_plan()

    def test_actual_workflow_reserves_every_sequential_step(self):
        workflow = (campaign.ROOT / campaign.WORKFLOW).read_text()
        with patch.dict(os.environ, {execution.policy.SCALE_ENV: "1"}):
            budget = execution.budgets(2)
        for name, following in (("linux", "windows"), ("windows", "complete_inventory")):
            section = workflow.split("\n  " + name + ":\n", 1)[1].split("\n  " + following + ":\n", 1)[0]
            fixed, dynamic = 0, set()
            for step in re.split(r"(?m)^      - name: ", section)[1:]:
                timeout = re.search(r"(?m)^        timeout-minutes: (.+)$", step)
                self.assertIsNotNone(timeout, "Unbudgeted workflow step: " + step.splitlines()[0])
                value = timeout[1]
                if value.isdigit():
                    fixed += int(value)
                else:
                    dynamic.add(value)
            self.assertLessEqual(fixed, budget["setup_minutes"] + budget["artifact_minutes"])
            self.assertEqual(dynamic, {"${{ matrix.dependency_minutes }}", "${{ matrix.suite_minutes }}",
                                       "${{ matrix.readback_minutes }}"})

    def test_final_inventory_reserves_all_readbacks_and_fails_skipped_prerequisites(self):
        with patch.dict(os.environ, {execution.policy.SCALE_ENV: "1"}):
            budget = execution.inventory_budgets(36)
        self.assertEqual(budget, {"shards": 36, "readback_minutes": 190, "job_minutes": 280})
        self.assertGreaterEqual(budget["readback_minutes"] * 60, 36 * 300)
        workflow = (campaign.ROOT / campaign.WORKFLOW).read_text().split("\n  complete_inventory:\n", 1)[1]
        self.assertIn("if: always() && (github.event_name", workflow)
        self.assertIn("needs.plan.outputs.inventory_job_minutes", workflow)
        self.assertIn("needs.plan.outputs.inventory_readback_minutes", workflow)
        self.assertIn("any(value != 'success' for value in results.values())", workflow)
        for name in ("plan", "linux", "windows"):
            self.assertIn("needs." + name + ".result", workflow)


class SharedOperationClock(unittest.TestCase):
    def setUp(self):
        self.clock = [0.0]
        timer = patch.object(execution.time, "monotonic", side_effect=lambda: self.clock[0])
        timer.start(); self.addCleanup(timer.stop)
        scale = patch.dict(os.environ, {execution.policy.SCALE_ENV: "1"})
        scale.start(); self.addCleanup(scale.stop)

    def test_nested_readback_does_not_restart_parent_allowance(self):
        with execution.operation_budget():
            self.clock[0] = 200
            with execution.operation_budget():
                self.assertEqual(execution.operation_remaining(), 100)
            self.assertEqual(execution.operation_remaining(), 100)
        self.assertIsNone(execution._OPERATION_DEADLINE)

    def test_sequential_git_calls_share_one_clock_and_stop_before_another_launch(self):
        with patch.object(campaign.subprocess, "check_output", return_value=b"source") as process:
            with self.assertRaisesRegex(TimeoutError, "shared execution allowance"):
                with execution.operation_budget():
                    for now in (0, 100, 200):
                        self.clock[0] = now
                        campaign.git("rev-parse", "HEAD")
                    self.clock[0] = 301
                    campaign.git("rev-parse", "HEAD")
            self.assertEqual([call.kwargs["timeout"] for call in process.call_args_list], [300, 200, 100])
        self.assertIsNone(execution._OPERATION_DEADLINE)

    def test_late_pure_readback_is_a_retained_failure_and_restores_clock(self):
        @execution.bounded_operation
        def slow_readback():
            self.clock[0] = 301
            return {"status": "passed"}
        with self.assertRaisesRegex(TimeoutError, "shared execution allowance"):
            slow_readback()
        self.assertIsNone(execution._OPERATION_DEADLINE)


class OriginalProcessCommands(unittest.TestCase):
    def receipt(self, platform="linux", graphical=False, imported=False):
        import run_godot_regressions as runner
        engine = (r"C:\engine\Godot_v4.7-stable_win64_console.exe" if platform == "win32"
                  else "/engine/Godot_v4.7-stable_linux.x86_64")
        project = r"C:\source\godot" if platform == "win32" else "/source/godot"
        flags = (("--editor", "--quit") if imported else
                 campaign.case_flags("jetbarrel", 1, 0, "none", graphical, platform))
        command = runner.case_command(engine, runner.Case("control", flags, 1200, 0, graphical), platform)
        command[command.index("--path") + 1] = project
        return {"command": command}, flags, (engine, project)

    def test_original_linux_windows_headless_graphical_and_import_argv(self):
        for platform in ("linux", "win32"):
            for graphical, imported in ((False, True), (False, False), (True, False)):
                process, flags, paths = self.receipt(platform, graphical, imported)
                original = deepcopy(process)
                self.assertEqual(campaign.verify_command(process, flags, graphical, platform), paths)
                self.assertEqual(process, original)

    def test_import_cannot_be_replaced_by_version_probe(self):
        process, flags, _ = self.receipt(imported=True)
        process["command"][-2:] = ["--version"]
        with self.assertRaisesRegex(ValueError, "registered source/configuration"):
            campaign.verify_command(process, flags, False, "linux")

    def test_original_case_cannot_gain_extra_flags_or_wrong_fixture_and_config(self):
        for change in ("extra", "script", "rig", "driver", "headless"):
            process, flags, _ = self.receipt()
            command = process["command"]
            if change == "extra": command += ["--quit"]
            elif change == "script": command[command.index("--script") + 1] = "res://tests/another.gd"
            elif change == "rig": command[command.index("--rig=jetbarrel")] = "--rig=acrobat"
            elif change == "driver": command[command.index("--rendering-driver") + 1] = "vulkan"
            else: command.remove("--headless")
            with self.subTest(change=change), self.assertRaisesRegex(ValueError, "registered source/configuration"):
                campaign.verify_command(process, flags, False, "linux")

    def test_engine_project_and_import_host_path_changes_are_refused(self):
        for change in ("engine", "relative", "host", "duplicate"):
            process, flags, paths = self.receipt("win32")
            command = process["command"]
            if change == "engine": command[0] = r"C:\engine\another.exe"
            elif change == "relative": command[command.index("--path") + 1] = "godot"
            elif change == "host": command[command.index("--path") + 1] = r"C:\other\godot"
            else: command += ["--path", r"C:\source\godot"]
            with self.subTest(change=change), self.assertRaises(ValueError):
                campaign.verify_command(process, flags, False, "win32", paths)

    def test_boolean_and_nonfinite_process_elapsed_are_not_observations(self):
        process = {"status": "passed", "returncode": 0, "timeout_seconds": 1200,
                   "requires_display": False, "execution_policy": execution.policy.identity(),
                   "natural_completion": True}
        for elapsed in (True, -1, float("nan"), float("inf")):
            process["seconds"] = elapsed
            with self.subTest(elapsed=elapsed), self.assertRaisesRegex(ValueError, "deadline"):
                campaign.verify_process(process, 1200)

    def test_linked_ancestor_cannot_alias_an_original_file(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            actual = root / "actual"; actual.mkdir(); (actual / "log.txt").write_text("original")
            (root / "alias").symlink_to(actual, target_is_directory=True)
            with self.assertRaisesRegex(ValueError, "path component"):
                campaign.safe_file(root, "alias/log.txt")


class CleanupCustody(unittest.TestCase):
    def setUp(self):
        self.args = ("a" * 40, "b" * 32, "c" * 64, "d" * 64, "e" * 64)
        self.process = {"pid": 110, "natural_completion": True, "returncode": 1,
                        "execution_policy": execution.policy.identity()}
        self.result = {"schema": "play-pace004-v2", "source_revision": self.args[0],
                       "process_nonce": self.args[1], "fixture_sha256": self.args[2],
                       "probe_sha256": self.args[3], "engine_sha256": self.args[4],
                       "execution_policy": fixture_policy(), "process_id": 111,
                       "worker_joined": True, "sessions_retired": 1, "failures": 1}

    def receipt(self, state="absent"):
        return execution.cleanup_receipt(self.process, self.result, *self.args, inspect=lambda pid: state)

    def test_failed_assertion_with_real_retirement_can_continue(self):
        receipt = self.receipt()
        self.assertTrue(receipt["safe_to_continue"])
        self.assertEqual([row["pid"] for row in receipt["processes"]], [110, 111])
        execution.verify_cleanup(receipt, self.process, self.result, *self.args)

    def test_same_engine_wrapper_pid_is_one_observation(self):
        self.result["process_id"] = self.process["pid"]
        self.assertTrue(self.receipt()["safe_to_continue"])
        self.assertEqual(len(self.receipt()["processes"]), 1)

    def test_missing_footer_cannot_authorize_next_case(self):
        receipt = execution.cleanup_receipt(self.process, None, *self.args, inspect=lambda pid: "absent")
        self.assertFalse(receipt["safe_to_continue"])

    def test_timeout_cannot_be_relabelled_retirement(self):
        self.process["natural_completion"] = False
        self.assertFalse(self.receipt()["safe_to_continue"])

    def test_each_engine_and_wrapper_pid_is_required(self):
        for target in (self.process, self.result):
            key = "pid" if target is self.process else "process_id"
            old = target.pop(key)
            self.assertFalse(self.receipt()["safe_to_continue"])
            target[key] = old

    def test_active_or_unobserved_pid_blocks_continuation(self):
        for state in ("active", "unobserved"):
            self.assertFalse(self.receipt(state)["safe_to_continue"])

    def test_owner_join_and_one_actual_retirement_required(self):
        self.result["worker_joined"] = False
        self.assertFalse(self.receipt()["safe_to_continue"])
        self.result["worker_joined"] = True
        for value in (0, 2, True):
            self.result["sessions_retired"] = value
            self.assertFalse(self.receipt()["safe_to_continue"])

    def test_foreign_source_nonce_probe_or_engine_blocks_continuation(self):
        for field in ("source_revision", "process_nonce", "fixture_sha256", "probe_sha256", "engine_sha256"):
            old = self.result[field]; self.result[field] = "wrong"
            self.assertFalse(self.receipt()["safe_to_continue"])
            self.result[field] = old

    def test_unbound_fixture_or_process_policy_blocks_continuation(self):
        self.result["execution_policy"]["scale"] = True
        self.assertFalse(self.receipt()["safe_to_continue"])
        self.result["execution_policy"] = fixture_policy()
        self.process["execution_policy"]["scale"] = True
        self.assertFalse(self.receipt()["safe_to_continue"])

    def test_independent_readback_rejects_invented_process_absence(self):
        receipt = self.receipt(); receipt["processes"].pop()
        with self.assertRaisesRegex(ValueError, "cleanup"):
            execution.verify_cleanup(receipt, self.process, self.result, *self.args)

    def test_independent_readback_rejects_boolean_or_nonfinite_timestamp(self):
        for value in (True, float("nan"), float("inf")):
            receipt = self.receipt(); receipt["checked_unix_seconds"] = value
            with self.assertRaisesRegex(ValueError, "cleanup"):
                execution.verify_cleanup(receipt, self.process, self.result, *self.args)

    def test_real_read_only_probe_sees_this_live_python_process(self):
        self.assertEqual(execution.pid_state(os.getpid()), "active")


class BaselineCustody(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.previous = {name: ("100644", "blob", campaign.git_object(b"blob", name.encode()))
                         for name in ("godot/scripts/main.gd", campaign.PALETTE,
                                      "tools/ci/execution_policy.py", "godot/tests/support/ci_execution_policy.json")}
        self.executed = self.previous | {campaign.FIXTURE: ("100644", "blob", "1" * 40)}
        self.baseline_raw = self.commit(campaign.tree_identity(self.previous), None, "accepted timeout and shader")
        self.baseline = campaign.git_object(b"commit", self.baseline_raw)
        self.source_raw = self.commit(campaign.tree_identity(self.executed), self.baseline, "PACE apparatus")
        self.source = campaign.git_object(b"commit", self.source_raw)
        self.report = {"source_commit": self.source, "source_baseline": {
            "schema": "play-pace004-source-baseline-v2", "commit": self.baseline,
            "tree": campaign.tree_identity(self.previous), "protected_scopes": list(campaign.SCOPES),
            "apparatus_paths": sorted(campaign.PACE_INPUTS), "historical_base": campaign.HISTORICAL_BASE,
            "historical_source": campaign.HISTORICAL_SOURCE, "historical_run": campaign.HISTORICAL_RUN,
            "historical_results_are_separate": True}}
        (self.root / "baseline-commit.txt").write_bytes(self.baseline_raw)
        (self.root / "baseline-tree.bin").write_bytes(b"".join(
            (" ".join(entry) + "\t" + name).encode() + b"\0" for name, entry in sorted(self.previous.items())))
        (self.root / "executed-commit.txt").write_bytes(self.source_raw)
        self.ancestry = {self.baseline: base64.b64encode(self.baseline_raw).decode(),
                         self.source: base64.b64encode(self.source_raw).decode()}
        self.save_ancestry()

    @staticmethod
    def commit(tree, parent, message):
        return (f"tree {tree}\n" + (f"parent {parent}\n" if parent else "") +
                "author Test <control@example.invalid> 1 +0000\n"
                "committer Test <control@example.invalid> 1 +0000\n\n" + message + "\n").encode()

    def save_ancestry(self):
        (self.root / "source-ancestry.json").write_text(json.dumps(self.ancestry))

    def verify(self):
        campaign.verify_baseline(self.root, self.report, self.executed, self.baseline)

    def test_versioned_accepted_source_allows_only_registered_apparatus(self):
        self.verify()

    def test_production_shader_main_runner_and_policy_are_protected(self):
        for name in self.previous:
            with self.subTest(name=name):
                old = self.executed[name]; self.executed[name] = ("100644", "blob", "2" * 40)
                with self.assertRaisesRegex(ValueError, "Production/runner/policy"):
                    self.verify()
                self.executed[name] = old

    def test_unregistered_test_or_workflow_cannot_enter(self):
        for name in ("godot/tests/unregistered.gd", ".github/workflows/native.yml"):
            self.executed[name] = ("100644", "blob", "3" * 40)
            with self.assertRaisesRegex(ValueError, "Production/runner/policy"):
                self.verify()
            del self.executed[name]

    def test_independently_supplied_baseline_is_required_to_match(self):
        with self.assertRaisesRegex(ValueError, "independently supplied"):
            campaign.verify_baseline(self.root, self.report, self.executed, "a" * 40)

    def test_baseline_raw_commit_cannot_be_relabelled(self):
        (self.root / "baseline-commit.txt").write_bytes(self.baseline_raw + b"changed")
        with self.assertRaisesRegex(ValueError, "commit/tree"):
            self.verify()

    def test_tree_inventory_cannot_omit_protected_file(self):
        path = self.root / "baseline-tree.bin"
        path.write_bytes(b"\0".join(path.read_bytes().split(b"\0")[1:]))
        with self.assertRaisesRegex(ValueError, "tree inventory"):
            self.verify()

    def test_authenticated_but_unrelated_commit_is_not_an_ancestor(self):
        self.source_raw = self.commit(campaign.tree_identity(self.executed), "9" * 40, "unrelated source")
        self.source = campaign.git_object(b"commit", self.source_raw)
        self.report["source_commit"] = self.source
        (self.root / "executed-commit.txt").write_bytes(self.source_raw)
        self.ancestry = {self.baseline: base64.b64encode(self.baseline_raw).decode(),
                         self.source: base64.b64encode(self.source_raw).decode()}
        self.save_ancestry()
        with self.assertRaisesRegex(ValueError, "not an authenticated source ancestor"):
            self.verify()

    def test_ancestry_object_must_match_its_content_digest(self):
        self.ancestry[self.source] = base64.b64encode(self.source_raw + b"changed").decode()
        self.save_ancestry()
        with self.assertRaisesRegex(ValueError, "Ancestry commit authentication"):
            self.verify()


class RegisteredInventory(unittest.TestCase):
    def setUp(self):
        control = patch.dict(os.environ, {execution.policy.SCALE_ENV: "1"})
        control.start(); self.addCleanup(control.stop)

    def test_exact_seventy_two_cases_without_invented_sampled_or_sync_arm(self):
        plan = campaign.hosted_plan()["include"]
        self.assertEqual(len(plan), 36)
        self.assertEqual(sum(row["case_count"] for row in plan), 72)
        for platform in ("linux", "win32"):
            for mode, size in (("ordinary", 14), ("active", 16), ("graphical", 6)):
                rows = [row for row in plan if row["platform"] == platform and row["mode"] == mode]
                observed = [case for row in rows for case in campaign.selected_plan(
                    row["graphical"], row["active"], row["shard_index"], row["shard_count"])]
                self.assertEqual(len(observed), size)
                self.assertEqual(len(set(observed)), size)
                self.assertTrue(all(row["case_count"] == 2 and row["job_minutes"] == 300 for row in rows))

    def test_empty_or_out_of_range_shards_are_not_allowed(self):
        for index, count in ((0, 0), (-1, 7), (7, 7), (0, 15)):
            with self.assertRaises(ValueError):
                campaign.selected_plan(False, False, index, count)

    def make_suite(self):
        temp = tempfile.TemporaryDirectory(); self.addCleanup(temp.cleanup)
        root = Path(temp.name); reduced = {}
        for i, row in enumerate(campaign.hosted_plan()["include"]):
            directory = root / str(i); directory.mkdir(); (directory / "campaign.json").write_text("{}")
            reduced[directory] = {"source_commit": "a" * 40, "platform": row["platform"],
                "graphical": row["graphical"], "active_workload": row["active"], "case_count": row["case_count"],
                "shard": {"index": row["shard_index"], "count": row["shard_count"]}}
        return root, reduced

    def test_complete_suite_reduces_to_exact_cross_os_inventory(self):
        root, reduced = self.make_suite()
        with patch.object(campaign, "verify_directory", side_effect=lambda path, **kwargs: reduced[path]):
            report = campaign.verify_suite(root, "a" * 40, "b" * 40)
        self.assertEqual((report["shards"], report["cases"]), (36, 72))
        self.assertEqual(report["inventory"], {"linux": {"headless": 30, "graphical": 6},
                                                "win32": {"headless": 30, "graphical": 6}})

    def test_missing_shard_cannot_be_accepted_as_complete(self):
        root, reduced = self.make_suite(); (root / "0/campaign.json").unlink()
        with patch.object(campaign, "verify_directory", side_effect=lambda path, **kwargs: reduced[path]):
            with self.assertRaisesRegex(ValueError, "Missing registered"):
                campaign.verify_suite(root, "a" * 40, "b" * 40)

    def test_duplicate_or_foreign_source_shard_is_rejected(self):
        for field in ("duplicate", "source"):
            root, reduced = self.make_suite()
            if field == "duplicate":
                reduced[root / "1"] = deepcopy(reduced[root / "0"])
            else:
                reduced[root / "1"]["source_commit"] = "c" * 40
            with patch.object(campaign, "verify_directory", side_effect=lambda path, **kwargs: reduced[path]):
                with self.assertRaises(ValueError):
                    campaign.verify_suite(root, "a" * 40, "b" * 40)


class WindowAndRenderer(unittest.TestCase):
    def setUp(self):
        self.packets = [{"published_usec": 99, "completed_usec": 98, "native_completed": True},
                        {"published_usec": 101, "completed_usec": 100, "native_completed": True},
                        {"published_usec": 201, "completed_usec": 199, "native_completed": True}]
        self.receipt = {"schema": "play-pace004-window-retention-v1", "started_usec": 100, "ended_usec": 200,
            "startup_boundary_capacity": 1, "window_capacity": 12000, "overflow": False,
            "read_after_owner_join": True, "retained_boundary_publications": 1,
            "retained_window_publications": 2, "startup_publications_observed": 24000,
            "after_window_publications_observed": 99999}

    def verify(self):
        contract.verify_retention(self.receipt, self.packets, 100, 200)

    def test_long_startup_boundary_and_late_completion_receipt_are_valid(self):
        self.verify()

    def test_two_startup_boundaries_or_missing_window_row_are_rejected(self):
        self.packets.insert(0, deepcopy(self.packets[0]))
        with self.assertRaisesRegex(ValueError, "boundary/window"):
            self.verify()
        self.packets.pop(); self.packets.pop(0)
        with self.assertRaisesRegex(ValueError, "boundary/window"):
            self.verify()

    def test_completion_after_window_is_not_a_measured_receipt(self):
        self.packets[-1]["completed_usec"] = 200
        with self.assertRaisesRegex(ValueError, "After-window"):
            self.verify()

    def test_overflow_or_read_before_join_cannot_be_qualified(self):
        self.receipt["overflow"] = True
        with self.assertRaisesRegex(ValueError, "retention identity"):
            self.verify()
        self.receipt["overflow"] = False; self.receipt["read_after_owner_join"] = False
        with self.assertRaisesRegex(ValueError, "retention identity"):
            self.verify()

    def test_actual_windows_angle_is_required_for_windows_graphics(self):
        result = {"platform": "Windows", "godot": {"major": 4, "minor": 7, "patch": 0,
                  "status": "stable", "build": "official", "hash": contract.GODOT_HASH},
                  "rendering_method": "gl_compatibility", "rendering_driver": "opengl3_angle",
                  "display_server": "Windows", "engine_sha256": "a" * 64}
        contract.verify_environment(result, True, "win32")
        result["rendering_driver"] = "opengl3"
        with self.assertRaisesRegex(ValueError, "Actual renderer"):
            contract.verify_environment(result, True, "win32")


if __name__ == "__main__":
    unittest.main()
