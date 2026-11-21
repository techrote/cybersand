#!/usr/bin/env python3
"""Adversarial controls for the programme's process and source boundaries."""
import os
import ast
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

from build_runtime import bounded_process
from process_owner import OwnedProcess
from run_regressions import stage_source, validate_completion, terminal_json


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
