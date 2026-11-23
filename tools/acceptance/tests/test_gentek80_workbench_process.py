#!/usr/bin/env python3
"""Synthetic failure-admission tests, not a substitute for actual Win32_process inventory.

An exact Windows/Godot all-80 qualification must still observe both packaged
console and GUI executable paths before/after each author/reopen OS process.
"""
from __future__ import annotations
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ARCHITECTURE = Path(__file__).resolve().parents[2] / "architecture"
sys.path.insert(0, str(ARCHITECTURE))
import gentek80_workbench as workbench


def inventory(*pids):
    return {"supported": True, "pids": list(pids),
            "checked_console_and_gui": True,
            "paths": ["C:/sandbox/Godot_v4.7-stable_win64_console.exe",
                      "C:/sandbox/Godot_v4.7-stable_win64.exe"]}


class WorkbenchEngineExitTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="gentek-process-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.project = self.root / "godot"
        self.project.mkdir()
        self.output = self.root / "evidence"
        self.engine = self.root / "Godot_v4.7-stable_win64_console.exe"

    def run_driver(self, responses):
        identity = {"source_commit": "a" * 40, "source_tree": "b" * 40,
                    "runtime_sha256": "c" * 64}
        def fake_run(phase, command, environment, output, timeout, marker=None):
            if phase in ("author", "reopen"):
                receipt = {"schema": "gentek80-workbench-v1", "completed": True,
                           "process_id": 101 if phase == "author" else 202,
                           "styles": 80, "failures": 0, "cases": [
                               {"case": "gentek80-" + phase, "preset_id": "gentek1",
                                "source_sha256": "d" * 64,
                                "recipe_sha256": "e" * 64}]}
                (output / ("gentek80-workbench-" + phase + ".json")).write_text(
                    json.dumps(receipt), encoding="utf-8")
            return {"case": phase, "passed": True}
        argv = ["gentek80_workbench.py", "--godot", str(self.engine),
                "--project", str(self.project), "--output", str(self.output)]
        with (mock.patch.object(sys, "argv", argv),
              mock.patch.object(workbench.subprocess, "check_output",
                                return_value=workbench.qualify.VERSION),
              mock.patch.object(workbench.qualify, "source_identity",
                                return_value=identity),
              mock.patch.object(workbench.qualify, "run", side_effect=fake_run),
              mock.patch.object(workbench, "REQUIRE_ENGINE_EXIT_CHECK", True),
              mock.patch.object(workbench, "inventory_packaged_godot",
                                side_effect=responses) as check):
            code = workbench.main()
        report = json.loads((self.output / "qualification.json").read_text(encoding="utf-8"))
        return code, report, check.call_count

    def test_all_four_console_and_gui_boundaries_empty(self):
        code, report, count = self.run_driver([inventory() for _ in range(4)])
        self.assertEqual(code, 0)
        self.assertTrue(report["passed"])
        self.assertEqual(count, 4)
        boundaries = report["matching_engine_process_boundaries"]
        self.assertEqual([(x["phase"], x["when"]) for x in boundaries],
                         [("author", "before"), ("author", "after"),
                          ("reopen", "before"), ("reopen", "after")])
        self.assertTrue(all(x["checked_console_and_gui"] and not x["pids"]
                            for x in boundaries))

    def test_preexisting_child_process_refuses_author(self):
        code, report, count = self.run_driver([inventory(701)])
        self.assertEqual(code, 1)
        self.assertFalse(report["passed"])
        self.assertEqual(count, 1)
        self.assertTrue(any(x["case"] == "author-preexisting-engine-process"
                            for x in report["results"]))

    def test_surviving_engine_child_refuses_reopen(self):
        code, report, count = self.run_driver([
            inventory(), inventory(), inventory(), inventory(702)])
        self.assertEqual(code, 1)
        self.assertFalse(report["passed"])
        self.assertEqual(count, 4)
        self.assertTrue(any(x["case"] == "reopen-surviving-engine-process"
                            for x in report["results"]))

    def test_unavailable_inventory_refuses_without_fictional_pass(self):
        code, report, count = self.run_driver([
            {"supported": False, "error": "Get-CimInstance unavailable"}])
        self.assertEqual(code, 1)
        self.assertFalse(report["passed"])
        self.assertEqual(count, 1)


if __name__ == "__main__":
    unittest.main()
