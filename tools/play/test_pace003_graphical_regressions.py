#!/usr/bin/env python3
"""Negative controls for graphical regression evidence; never launch Godot."""
import copy
import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import run_pace003_graphical_regressions as graphical


def life007():
    return {"assertions": 151, "failures": 0, "retries": 0, "real_native_failure": True,
            "synthesized_failure": False, "native_healthy_guard_changed": False,
            "injected_setting_restored_before_first_ready": True, "internal_budget_ms": 150000,
            "rows": [{"rig": rig, "old_worker_joined": True, "old_worker_destroyed": True,
                      "old_adapter_destroyed": True, "recovered_owner_joined": True,
                      "recovery_usec": 5000} for rig in graphical.campaign.RIGS]}


def marked(name, value):
    return next(spec[1] for spec in graphical.CASES if spec[0] == name) + json.dumps(value)


class GraphicalEvidenceTests(unittest.TestCase):
    def test_all_required_cases_are_graphical_and_originally_bounded(self):
        self.assertEqual(len(graphical.CASES), 7)
        self.assertEqual(len({case[0] for case in graphical.CASES}), 7)
        for platform, driver in (("linux", "opengl3"), ("win32", "opengl3_angle")):
            for name, _marker, _assertions in graphical.CASES:
                case = graphical.case_for(name, driver)
                command = graphical.runner.case_command("godot", case, platform)
                self.assertTrue(case.requires_display)
                self.assertEqual(case.timeout, 180)
                self.assertNotIn("--headless", command)
                self.assertIn(driver, command)
                self.assertIn("res://tests/" + name + ".gd", command)

    def test_life007_requires_all_five_presets_and_no_worker_leaks(self):
        name = graphical.CASES[0][0]
        valid = life007()
        self.assertEqual(graphical.check_result(name, marked(name, valid)), valid)
        for mutate in (
            lambda value: value["rows"].pop(),
            lambda value: value["rows"][0].update(old_worker_destroyed=False),
            lambda value: value["rows"][0].update(recovered_owner_joined=False),
            lambda value: value.update(failures=1),
            lambda value: value.update(failures=False),
            lambda value: value.update(retries=1),
            lambda value: value.update(synthesized_failure=True),
            lambda value: value.update(internal_budget_ms=180000),
        ):
            invalid = copy.deepcopy(valid)
            mutate(invalid)
            with self.assertRaises(RuntimeError):
                graphical.check_result(name, marked(name, invalid))

    def test_missing_duplicate_or_false_success_markers_rejected(self):
        name = graphical.CASES[0][0]
        marker = marked(name, life007())
        for raw in ("Engine exited zero", marker + "\n" + marker):
            with self.assertRaises(RuntimeError):
                graphical.check_result(name, raw)
        for name, prefix, _ in graphical.CASES[-3:]:
            with self.assertRaises(RuntimeError):
                graphical.check_result(name, prefix + "skipped (headless)")

    def test_ui005_requires_real_graphical_layout_and_each_configuration(self):
        name = graphical.CASES[2][0]
        value = {"assertions": 90, "failures": 0, "retries": 0, "accepted_sessions": 5,
                 "policy_retaining_resets": 5, "native_refusals": 1, "window_layout_checked": True,
                 "real_host": "main.tscn+CyberSimulationWorker+main-thread-Rapier",
                 "rows": [{"rig": rig} for rig in graphical.campaign.RIGS]}
        self.assertEqual(graphical.check_result(name, marked(name, value)), value)
        for key, changed in (("window_layout_checked", False), ("policy_retaining_resets", 4),
                             ("native_refusals", 0), ("real_host", "mock")):
            with self.assertRaises(RuntimeError):
                graphical.check_result(name, marked(name, {**value, key: changed}))

    def test_ui003_requires_real_step_and_render_only_negative_control(self):
        name = graphical.CASES[3][0]
        value = {"assertions": 41, "failures": 0, "real_host_completed_step_visits": 1,
                 "negative_control_render_only": 1, "model_only": False,
                 "test_only_rapier_fixture_reposition": True,
                 "source": "original-course+existing-native-worker+real-rapier"}
        self.assertEqual(graphical.check_result(name, marked(name, value)), value)
        for key, changed in (("real_host_completed_step_visits", 0), ("negative_control_render_only", 0),
                             ("model_only", True)):
            with self.assertRaises(RuntimeError):
                graphical.check_result(name, marked(name, {**value, key: changed}))

    def test_process_zero_exit_does_not_hide_skip_headless_wrong_renderer_or_timeout(self):
        name = graphical.CASES[0][0]
        case = graphical.case_for(name, "opengl3")
        process = {"name": name, "requires_display": True, "status": "passed", "returncode": 0,
                   "timeout_seconds": 180, "timeout_kind": None, "diagnostic_error": False,
                   "skip_messages": [], "launch_error": None, "capture_error": None,
                   "timeout_diagnostic_error": None,
                   "command": graphical.runner.case_command("godot", case)}
        log = "OpenGL API 4.5 Mesa - Compatibility - Using Device: Mesa - llvmpipe\n"
        graphical.check_process(process, log, name, "opengl3")
        for key, value in (("timeout_seconds", 181), ("requires_display", False),
                           ("timeout_kind", "case"), ("skip_messages", ["SKIP"]),
                           ("capture_error", "failed"), ("command", ["godot", "--headless"])):
            with self.assertRaises(RuntimeError):
                graphical.check_process({**process, key: value}, log, name, "opengl3")
        for bad in ("No display", log + "SCRIPT ERROR: bad", log + "fixture skipped"):
            with self.assertRaises(RuntimeError):
                graphical.check_process(process, bad, name, "opengl3")

    def test_missing_or_invalid_pixel_files_fail(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaises(RuntimeError):
                graphical.check_pixels("test_material_presentation_render", root)
            (root / "material-id-slots-000-131.png").write_bytes(b"not a png")
            with self.assertRaises(RuntimeError):
                graphical.check_pixels("test_material_presentation_render", root)

    def test_windows_readback_does_not_depend_on_current_os_or_checkout(self):
        name = graphical.CASES[0][0]
        command = graphical.runner.case_command("D:\\godot\\Godot.exe", graphical.case_for(name, "opengl3_angle"), "win32")
        command[command.index("--path") + 1] = "D:\\a\\cybersand\\cybersand\\godot"
        process = {"name": name, "requires_display": True, "status": "passed", "returncode": 0,
                   "timeout_seconds": 180, "timeout_kind": None, "diagnostic_error": False,
                   "skip_messages": [], "launch_error": None, "capture_error": None,
                   "timeout_diagnostic_error": None, "command": command}
        log = "OpenGL API OpenGL ES 3.0 (ANGLE) - Compatibility - Using Device: Microsoft Basic Render Driver"
        graphical.check_process(process, log, name, "opengl3_angle", "Windows", "D:\\a\\cybersand\\cybersand")
        with self.assertRaises(RuntimeError):
            graphical.check_process(process, log, name, "opengl3_angle", "Windows", "D:\\a\\different")

    def test_evidence_inventory_detects_changed_original_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            original = root / "negative.log"
            original.write_text("TIMEOUT at 180s", encoding="utf-8")
            before = graphical.inventory(root)
            original.write_text("passed", encoding="utf-8")
            self.assertNotEqual(before, graphical.inventory(root))

    def test_graphical_summary_cannot_pass_with_missing_required_cases(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            graphical.runner.write_json(root / "regressions.json", {
                "schema": graphical.SCHEMA, "status": "passed", "errors": [], "retries": 0,
                "source_unchanged": True, "runtime_unchanged": True, "preceding_campaign_unchanged": True,
                "source_mode": "clean-recorded-inputs", "pace_measurement": False, "rows": [],
                "platform": "Linux", "rendering_driver": "opengl3", "godot_version": graphical.campaign.GODOT_VERSION})
            with self.assertRaises(RuntimeError):
                graphical.verify_directory(root)

    def test_first_failure_is_retained_and_other_required_cases_still_get_one_attempt(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            prior_dir = root / "campaign"
            prior_dir.mkdir()
            engine = root / "godot"
            engine.write_bytes(b"test executable identity, never launched")
            driver = "opengl3_angle" if sys.platform == "win32" else "opengl3"
            source = {"source_sha": "a" * 40, "source_tree": "b" * 40, "source_mode": "clean-recorded-inputs",
                      "source_delta_paths": [], "execution_inputs": {}}
            prior = {"schema": graphical.campaign.SCHEMA, "status": "failed", **source,
                     "runtimes": {}, "godot_sha256": graphical.runner.sha256(engine),
                     "godot_version": graphical.campaign.GODOT_VERSION,
                     "finished_utc": "2026-01-01T00:00:00+00:00", "import": {"status": "passed"},
                     "config": {"headless": False, "rendering_driver": driver}}
            graphical.runner.write_json(prior_dir / "campaign.json", prior)
            prior_files = graphical.inventory(prior_dir)
            attempted = []

            @contextlib.contextmanager
            def isolated(_output, _name, environment):
                yield environment, {}

            def run(_godot, case, output, _role, *, env):
                self.assertEqual(case.timeout, 180)
                self.assertTrue(case.requires_display)
                attempted.append(case.name)
                failed = len(attempted) == 1
                (output / (case.name + ".log")).write_text("original timeout" if failed else "original success")
                return {"log": case.name + ".log", "status": "timeout" if failed else "passed"}, failed

            arguments = ["graphical", "--godot", str(engine), "--output", str(root / "regressions"),
                         "--preceding-campaign", str(prior_dir), "--rendering-driver", driver]
            with contextlib.ExitStack() as stack:
                stack.enter_context(patch.object(sys, "argv", arguments))
                stack.enter_context(patch.dict(graphical.os.environ, {}, clear=True))
                stack.enter_context(patch.object(graphical.campaign, "source_identity", return_value=source))
                stack.enter_context(patch.object(graphical.campaign, "runtime_identity", return_value={}))
                stack.enter_context(patch.object(graphical.campaign, "cold_cache_environment", isolated))
                stack.enter_context(patch.object(graphical.subprocess, "check_output", return_value=graphical.campaign.GODOT_VERSION))
                stack.enter_context(patch.object(graphical.runner, "run_case", run))
                for name in ("check_process", "check_cache"):
                    stack.enter_context(patch.object(graphical, name, return_value=None))
                for name in ("check_result", "check_pixels"):
                    stack.enter_context(patch.object(graphical, name, return_value={}))
                stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
                self.assertEqual(graphical.main(), 1)
            report = json.loads((root / "regressions/regressions.json").read_text())
            self.assertEqual(attempted, [spec[0] for spec in graphical.CASES])
            self.assertEqual(report["status"], "failed")
            self.assertEqual(report["rows"][0]["process"]["status"], "timeout")
            self.assertTrue(report["rows"][0]["errors"])
            self.assertTrue(all(row["attempt"] == 1 for row in report["rows"]))
            self.assertEqual(graphical.inventory(prior_dir), prior_files)


if __name__ == "__main__":
    unittest.main()
