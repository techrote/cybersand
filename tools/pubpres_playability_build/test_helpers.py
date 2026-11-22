#!/usr/bin/env python3
"""Adversarial controls for the programme's process and source boundaries."""
import os
import ast
import copy
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest import mock

from build_runtime import bounded_process, digest
from process_owner import OwnedProcess
from run_regressions import (SAME_FRAME_COMPLETIONS, SAME_FRAME_HEADLESS, combined_evidence,
                             continuation_policy, invoke_authoring_pairs, stage_source,
                             validate_completion, terminal_json)
import run_installed_authoring


class HelperContracts(unittest.TestCase):
    def test_actual_clean_process_exit_is_not_a_survivor(self):
        self.assertEqual(bounded_process([sys.executable, "-c", "pass"],
                         stdout=subprocess.DEVNULL, timeout=5), (0, False))

    def test_packaged_error_contract_matches_unchanged_shared_checker(self):
        root = Path(__file__).resolve().parents[2]
        def definition(path):
            node = next(n for n in ast.parse(path.read_text()).body
                        if isinstance(n, ast.FunctionDef) and n.name == "case_diagnostic_error")
            return ast.dump(node, include_attributes=False)
        self.assertEqual(definition(root / "tools/ci/run_godot_regressions.py"),
                         definition(Path(__file__).with_name("regression_contract.py")))

    def test_zero_exit_does_not_admit_script_error(self):
        text = "PUBPRES_NATIVE_PROBE checks=222 failures=0\nSCRIPT ERROR: deliberate negative\n"
        self.assertTrue(validate_completion("test_pubpres_playability_native_probe", text, 0))

    def test_zero_exit_without_assertion_footer_refuses(self):
        self.assertTrue(validate_completion("test_pubpres_playability_native_probe", "Godot started\n", 0))
        self.assertFalse(validate_completion("test_pubpres_playability_native_probe", "PUBPRES_NATIVE_PROBE checks=222 failures=0\n", 0))

    def test_missing_zero_and_repeated_json_assertions_refuse(self):
        for text in ("", 'RESULT {"checks":0,"failures":[]}\n',
                     'RESULT {"checks":1,"failures":[]}\nRESULT {"checks":1,"failures":[]}\n'):
            with self.assertRaises(ValueError):
                terminal_json(text, "RESULT ")

    def test_author_phase_cannot_qualify_reopen(self):
        text = 'WB_COMBINED_EVIDENCE {"checks":10,"failures":[],"author_complete":true,"reopen_complete":false}\n'
        self.assertFalse(validate_completion("test_workbench_combined_authoring", text, 0))
        self.assertTrue(validate_completion("test_workbench_combined_authoring", text, 0, reopen=True))

    def test_same_frame_suites_require_exact_markers_and_assertion_counts(self):
        for test, (marker, schema, count) in SAME_FRAME_COMPLETIONS.items():
            result = {"schema": schema, "checks": count, "failures": []}
            good = marker + json.dumps(result) + "\n"
            with self.subTest(test=test):
                self.assertFalse(validate_completion(test, good, 0))
                for text in ("", good + good, good + "SCRIPT ERROR: deliberate negative\n"):
                    self.assertTrue(validate_completion(test, text, 0))
                self.assertTrue(validate_completion(test, good, 1))
                for key, value in (("checks", count - 1), ("checks", count + 1), ("checks", True),
                                   ("schema", schema + "-other"), ("failures", ["failed"]),
                                   ("failures", 0), ("failures", False)):
                    forged = dict(result, **{key: value})
                    self.assertTrue(validate_completion(test, marker + json.dumps(forged) + "\n", 0),
                                    (test, key, value))

    def test_same_frame_regression_matrix_keeps_both_publication_controls(self):
        self.assertEqual([(test, mode) for _, test, mode in SAME_FRAME_HEADLESS], [
            ("test_workbench_same_frame_continuation", "off"),
            ("test_workbench_same_frame_integration", "on"),
            ("test_workbench_physics_publication", "off"),
            ("test_workbench_physics_publication", "on"),
        ])
        self.assertEqual(len({label for label, _, _ in SAME_FRAME_HEADLESS}), 4)

    def test_failed_off_authoring_does_not_skip_on_or_either_fresh_process(self):
        calls = []
        def refuse(label, options, **settings):
            calls.append((label, options, settings))
            return False
        invoke_authoring_pairs(refuse, ["--headless"], False)
        prefix = "test_workbench_combined_authoring-"
        self.assertEqual([label for label, _, _ in calls],
                         [prefix + suffix for suffix in ("off", "off-reopen", "on", "on-reopen")])
        for index, (_, options, settings) in enumerate(calls):
            mode = "off" if index < 2 else "on"
            self.assertEqual(settings["same_frame"], mode)
            self.assertEqual(options, ["--headless", "--script", "res://tests/test_workbench_combined_authoring.gd"])
            self.assertFalse(settings["graphical"])
            if index % 2:
                self.assertEqual(settings["profile_key"], prefix + mode)
                self.assertTrue(settings["reopen"])
            else:
                self.assertNotIn("profile_key", settings)
                self.assertNotIn("reopen", settings)

    @staticmethod
    def continuation_receipt(mode):
        enabled = mode == "on"
        observed = {"selectors": continuation_policy(mode)["selectors"], "status": {
            "version": 1, "requested": enabled, "enabled": enabled, "disabled_reason": "",
            "mode": "same_frame_once" if enabled else "off",
            "maximum_attempts_per_process_frame": 1, "maximum_mailbox_reads_per_attempt": 1,
            "wait_usec": 0, "new_physics_callbacks": 0, "carried_time_credit": False,
        }}
        return {"schema": "pubpres-authoring-continuation-evidence-v1", "mode": mode,
                "claim": "configuration-only", "before": copy.deepcopy(observed), "after": observed}

    def test_combined_authoring_binds_configuration_and_main_helper_hashes(self):
        with tempfile.TemporaryDirectory() as folder:
            project = Path(folder)
            identity = {"native_sha256": "a" * 64, "display": "headless"}
            for name in ("scripts/main.gd", "scripts/workbench_same_frame_continuation.gd",
                         "tests/test_workbench_combined_authoring.gd"):
                path = project / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("extends Node\n# " + name + "\n")
                identity[name] = digest(path)
            phases = {name: True for name in ("discovery", "generation", "manual", "leases", "agent",
                "provider_fixture", "late_response", "human_after_agent", "stop", "agent_undo_saved",
                "simulation_equipment", "save", "reopen", "continued_authoring")}
            result = {"schema": "workbench-combined-authoring-v2", "checks": 10, "failures": [],
                      "prepared_sha256": "b" * 64, "map_side": 512, "source_identity": identity,
                      "phases": phases, "same_frame_continuation": self.continuation_receipt("on")}
            def evaluate(receipt, mode="on", reopen=False):
                return combined_evidence("WB_COMBINED_EVIDENCE " + json.dumps(receipt), project,
                    "a" * 64, project / "screenshots", graphical=False, reopen=reopen, same_frame=mode)
            for mode in ("off", "on"):
                result["same_frame_continuation"] = self.continuation_receipt(mode)
                for reopen in (False, True):
                    self.assertEqual(evaluate(result, mode, reopen)["prepared_sha256"], "b" * 64)
            for missing in ("scripts/main.gd", "scripts/workbench_same_frame_continuation.gd"):
                altered = copy.deepcopy(result)
                del altered["source_identity"][missing]
                with self.assertRaisesRegex(ValueError, "source identity"):
                    evaluate(altered)
            changes = (
                (("schema",), "workbench-combined-authoring-v1"),
                (("source_identity", "scripts/main.gd"), "c" * 64),
                (("source_identity", "scripts/workbench_same_frame_continuation.gd"), "c" * 64),
                (("same_frame_continuation", "claim"), "continuation-caused-steps"),
                (("same_frame_continuation", "mode"), "off"),
                (("same_frame_continuation", "before", "status", "wait_usec"), 16000),
                (("same_frame_continuation", "after", "status", "enabled"), False),
                (("same_frame_continuation", "after", "status", "requested"), 1),
                (("same_frame_continuation", "after", "status", "new_physics_callbacks"), 1),
                (("same_frame_continuation", "after", "selectors", "CYBERSAND_DIAG_NATIVE_RENDEZVOUS"), "1"),
                (("same_frame_continuation", "before", "selectors", "CYBERSAND_DIAG_PHYSICS_PUBLICATION"), "combined"),
            )
            for keys, value in changes:
                with self.subTest(keys=keys):
                    altered = copy.deepcopy(result)
                    target = altered
                    for key in keys[:-1]:
                        target = target[key]
                    target[keys[-1]] = value
                    with self.assertRaises(ValueError):
                        evaluate(altered)

    def test_installed_authoring_selector_defaults_off_and_refuses_unknown(self):
        required = ["--package", "payload", "--candidate", "a" * 40, "--output", "evidence"]
        self.assertEqual(run_installed_authoring.parse_arguments(required).same_frame, "off")
        self.assertEqual(run_installed_authoring.parse_arguments(required + ["--same-frame", "on"]).same_frame, "on")
        with mock.patch("sys.stderr", io.StringIO()), self.assertRaises(SystemExit):
            run_installed_authoring.parse_arguments(required + ["--same-frame", "auto"])
        with self.assertRaises(ValueError):
            continuation_policy("auto")

    def test_installed_policy_and_fresh_process_material_mismatch_fail_closed(self):
        # Mocked transport tests the Windows runner contract, not actual Windows
        # rendering or native simulation. Those remain separate platform gates.
        for mode in ("off", "on"):
            for changed_plane in (False, True):
                with self.subTest(mode=mode, changed_plane=changed_plane), tempfile.TemporaryDirectory() as folder:
                    root = Path(folder)
                    payload = root / "payload"
                    (payload / "C/godot").mkdir(parents=True)
                    (payload / "godot.exe").write_bytes(b"mock-engine")
                    (payload / run_installed_authoring.package_windows.MANIFEST).write_text("{}\n")
                    manifest = {"schema": run_installed_authoring.package_windows.COMPLETION_SCHEMA,
                                "sources": {"C": {"root": "C", "native": {"sha256": "a" * 64}}},
                                "engine": {"gui": {"path": "godot.exe"}}}
                    args = SimpleNamespace(package=payload, candidate="c" * 40, output=root / "output", same_frame=mode)
                    calls = []
                    def fake_run(command, environment, output, timeout):
                        calls.append((list(command), dict(environment)))
                        output.mkdir(parents=True)
                        (output / "stdout.log").write_text("mocked transport\n")
                        return {"returncode": 0, "timed_out": False}
                    def fake_evidence(text, project, native_sha, screenshots, *, graphical, reopen, same_frame):
                        self.assertEqual((native_sha, graphical, same_frame), ("a" * 64, True, mode))
                        return {"prepared_sha256": ("d" if reopen and changed_plane else "b") * 64,
                                "same_frame_continuation": self.continuation_receipt(mode)}
                    inherited = {"CYBERSAND_DIAG_NATIVE_RENDEZVOUS": "render-overlap",
                                 "CYBERSAND_DIAG_SAME_FRAME_CONTINUATION": "1",
                                 "WB_COMBINED_REOPEN": "1"}
                    with mock.patch.object(run_installed_authoring, "parse_arguments", return_value=args), \
                            mock.patch.object(run_installed_authoring, "os", SimpleNamespace(name="nt", environ=inherited)), \
                            mock.patch.object(run_installed_authoring.package_windows, "verify", return_value=manifest) as verify, \
                            mock.patch.object(run_installed_authoring, "run", side_effect=fake_run), \
                            mock.patch.object(run_installed_authoring, "validate_completion", return_value=[]), \
                            mock.patch.object(run_installed_authoring, "combined_evidence", side_effect=fake_evidence):
                        self.assertEqual(run_installed_authoring.main(), 1 if changed_plane else 0)
                    summary = json.loads((args.output / "SUMMARY.json").read_text())
                    self.assertEqual(summary["schema"], "pubpres-installed-authoring-v2")
                    self.assertEqual(summary["same_frame_continuation_policy"], continuation_policy(mode))
                    self.assertEqual(summary["complete"], not changed_plane)
                    if changed_plane:
                        self.assertIn("native material digest differs", summary["failure"])
                    self.assertEqual(verify.call_count, 2)
                    self.assertEqual(len(calls), 3)
                    for _, environment in calls:
                        for name, value in continuation_policy(mode)["selectors"].items():
                            self.assertEqual(environment[name], value)
                        self.assertEqual(environment["WB_COMBINED_SAME_FRAME"], mode)
                        self.assertEqual(environment["CYBERSAND_DIAG_MATERIAL_RETIREMENT_SOURCE"], "target")
                    self.assertEqual(calls[1][1]["WB_COMBINED_REOPEN"], "0")
                    self.assertEqual(calls[2][1]["WB_COMBINED_REOPEN"], "1")
                    self.assertEqual(calls[1][1]["APPDATA"], calls[2][1]["APPDATA"])
                    for command, _ in calls[1:]:
                        self.assertNotIn("--headless", command)
                        self.assertEqual(command[command.index("--render-thread") + 1], "safe")
                        self.assertEqual(command[command.index("--rendering-driver") + 1], "opengl3_angle")

    def test_exact_source_includes_recipes_and_refuses_project_delta(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / "source"
            root.mkdir()
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            subprocess.run(["git", "config", "user.name", "PUBPRES isolated test"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.email", "pubpres-test@example.invalid"], cwd=root, check=True)
            for name, body in {"godot/scripts/main.gd": "extends Node\n", "examples/worldgen/fixture.json": "{}\n"}.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(body)
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            subprocess.run(["git", "commit", "-qm", "isolated source fixture"], cwd=root, check=True)
            source = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
            output = Path(folder) / "exact"
            output.mkdir()
            project = stage_source(root, source, output)
            self.assertEqual((project / "scripts/main.gd").read_text(), "extends Node\n")
            self.assertEqual((output / "examples/worldgen/fixture.json").read_text(), "{}\n")
            (root / "godot/scripts/main.gd").write_text("extends Control\n")
            with self.assertRaises(subprocess.CalledProcessError):
                stage_source(root, source, Path(folder) / "dirty")
            subprocess.run(["git", "restore", "godot/scripts/main.gd"], cwd=root, check=True)
            (root / "godot/scripts/untracked.gd").write_text("extends Node\n")
            with self.assertRaises(ValueError):
                stage_source(root, source, Path(folder) / "untracked")

    def test_timeout_kills_descendant_before_late_write(self):
        with tempfile.TemporaryDirectory() as folder:
            marker = Path(folder) / "late-write"
            descendant = "import time,pathlib;time.sleep(2);pathlib.Path(" + repr(str(marker)) + ").write_text('orphan')"
            parent = "import subprocess,sys,time;subprocess.Popen([sys.executable,'-c'," + repr(descendant) + "]);time.sleep(20)"
            with (Path(folder) / "process.log").open("w") as log:
                code, timed_out = bounded_process([sys.executable, "-c", parent], stdout=log, timeout=1)
            self.assertEqual(code, 124)
            self.assertTrue(timed_out)
            time.sleep(1.4)
            self.assertFalse(marker.exists(), "A timed-out descendant continued writing")

    def test_detached_descendant_is_owned_on_timeout_and_zero_exit(self):
        for early_exit in (False, True):
            with self.subTest(early_exit=early_exit), tempfile.TemporaryDirectory() as folder:
                marker = Path(folder) / "detached-late-write"
                descendant = "import time,pathlib;time.sleep(2);pathlib.Path(" + repr(str(marker)) + ").write_text('orphan')"
                detach = ",creationflags=subprocess.CREATE_NEW_PROCESS_GROUP" if os.name == "nt" else ",start_new_session=True"
                parent = ("import subprocess,sys,time;subprocess.Popen([sys.executable,'-c'," + repr(descendant) + "]" + detach + ");"
                          + ("sys.exit(0)" if early_exit else "time.sleep(20)"))
                with (Path(folder) / "process.log").open("w") as log:
                    code, timed_out = bounded_process([sys.executable, "-c", parent], stdout=log, timeout=1)
                self.assertEqual((code, timed_out), (125, False) if early_exit else (124, True))
                time.sleep(2.1)
                self.assertFalse(marker.exists(), "A separately grouped child survived cleanup")

    def test_keyboard_interrupt_cleans_actual_process(self):
        with tempfile.TemporaryDirectory() as folder:
            marker = Path(folder) / "cancelled-late-write"
            command = "import time,pathlib;time.sleep(1);pathlib.Path(" + repr(str(marker)) + ").write_text('orphan')"
            owner = None
            with self.assertRaises(KeyboardInterrupt):
                with OwnedProcess([sys.executable, "-c", command], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT) as owner:
                    raise KeyboardInterrupt("deliberate cancellation")
            self.assertIsNotNone(owner.process.poll())
            time.sleep(1.1)
            self.assertFalse(marker.exists(), "Cancellation left the actual child running")


if __name__ == "__main__":
    unittest.main()
