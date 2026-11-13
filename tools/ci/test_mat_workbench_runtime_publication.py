#!/usr/bin/env python3
"""Integration branch, original-receipt and standalone composition negatives."""
import copy
import inspect
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import mat_workbench_runtime_publication as subject
import materials_lab_runtime_publication as original

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import package_mat_workbench_candidate as package
from test_workbench_profile_packaging import WindowsRuntime


class IntegrationPublication(unittest.TestCase):
    def test_isolated_owner_and_unchanged_four_path_lease_engine(self):
        self.assertIsNot(subject.lab, original)
        self.assertIsNot(subject.engine, original.engine)
        self.assertEqual(original.engine.BRANCH, "codex/materials-native-capabilities-20261111")
        self.assertEqual(subject.engine.BRANCH, "codex/mat-auth-workbench-integration-20261112")
        for name in ("context", "check_source", "check_index", "require_publication_request", "input_ledgers", "stage"):
            self.assertEqual(inspect.getsource(getattr(subject.engine, name)), inspect.getsource(getattr(original.engine, name)))
        self.assertEqual(subject.lab.DISPATCH_WORKFLOWS,
                         ("documentation.yml", "native.yml", "gdextension.yml", "palette-shader-qualification.yml"))
        self.assertNotIn(original.engine.REQUEST, subject.engine.BUILD_EXACT)
        self.assertNotIn(original.engine.WORKFLOW, subject.engine.BUILD_EXACT)
        for path in (subject.engine.WORKFLOW, subject.engine.REQUEST, subject.engine.EVIDENCE,
                     "tools/ci/run_workbench_qualification.py", "tools/package_mat_workbench_candidate.py",
                     "tools/ci/check_windows_package_modules.ps1", "tools/test_art_provider_transport.py"):
            self.assertIn(path, subject.engine.BUILD_EXACT)

    def test_foreign_branch_event_or_workflow_cannot_enter_profile(self):
        source = "a" * 40
        environment = {"GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_NAME": "push",
            "GITHUB_REF": "refs/heads/" + subject.engine.BRANCH, "GITHUB_SHA": source,
            "GITHUB_WORKFLOW_REF": "techrote/cybersand/" + subject.engine.WORKFLOW + "@refs/heads/" + subject.engine.BRANCH,
            "GITHUB_RUN_ID": "123", "GITHUB_RUN_ATTEMPT": "1"}
        with patch.object(subject.engine, "git", return_value=source.encode()):
            with patch.dict(os.environ, environment, clear=True):
                self.assertEqual(subject.engine.context(source)["source_commit"], source)
            for key, value in (("GITHUB_REF", "refs/heads/" + original.engine.BRANCH),
                               ("GITHUB_REF", "refs/heads/main"), ("GITHUB_EVENT_NAME", "pull_request"),
                               ("GITHUB_WORKFLOW_REF", "techrote/cybersand/" + original.engine.WORKFLOW + "@refs/heads/" + original.engine.BRANCH)):
                with self.subTest(key=key, value=value), patch.dict(os.environ, environment | {key: value}, clear=True):
                    with self.assertRaises(RuntimeError): subject.engine.context(source)

    def result_fixture(self, directory, labels):
        directory.mkdir(parents=True)
        records = [{"label": name, "status": "passed", "exit_code": 0} for name in labels]
        for name in labels: (directory / (name + ".log")).write_text("original native execution log\n")
        path = directory / "results.json"
        path.write_text(json.dumps(records))
        return path, records

    def test_partial_reordered_failed_or_logless_campaign_is_refused(self):
        for mode in ("pass", "missing", "reorder", "duplicate", "failed", "exit", "log"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                labels = subject.regression_labels()
                path, records = self.result_fixture(Path(temporary) / "regressions", labels)
                if mode == "missing": records.pop()
                if mode == "reorder": records.reverse()
                if mode == "duplicate": records[-1] = records[0]
                if mode == "failed": records[-1]["status"] = "failed"
                if mode == "exit": records[-1]["exit_code"] = 1
                if mode == "log": (path.parent / (labels[-1] + ".log")).unlink()
                path.write_text(json.dumps(records))
                if mode == "pass": self.assertEqual(len(subject.verify_results(path, labels)), len(labels))
                else:
                    with self.assertRaises(RuntimeError): subject.verify_results(path, labels)

    def test_lab_green_alone_cannot_qualify_combined_runtime(self):
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(subject, "_verify_lab_bundle", return_value={"sha256": "a" * 64}):
                with self.assertRaises(FileNotFoundError):
                    subject.verify_materials_bundle(Path(temporary), "windows", "b" * 40)

    def test_original_receipt_files_and_runtime_binding_are_required(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for family, labels in (("regressions", subject.regression_labels()), ("combined", subject.integration_labels()),
                                   ("installed", subject.installed_labels())):
                self.result_fixture(root / "workbench" / family, labels)
            report = {"schema": "mat-workbench-source-qualification-v1", "platform": "linux",
                      "native_sha256": "a" * 64, "status": "passed", "completed": True,
                      "files_sha256": subject.evidence_files(root)}
            subject.engine.write_json(root / "workbench.json", report)
            with patch.object(subject.lab, "verify_context"), patch.object(subject, "verify_combined_case"):
                subject.verify_workbench(root, "linux", "b" * 40, "a" * 64)
                with self.assertRaises(RuntimeError): subject.verify_workbench(root, "linux", "b" * 40, "c" * 64)
                log = root / "workbench/combined" / (subject.integration_labels()[0] + ".log")
                log.write_text("changed execution receipt\n")
                with self.assertRaises(RuntimeError): subject.verify_workbench(root, "linux", "b" * 40, "a" * 64)

    def test_combined_graphical_receipt_refuses_wrong_source_missing_images_and_partial_work(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            project, evidence = subject.engine.ROOT / "godot", root / "evidence"
            evidence.mkdir()
            label = "mat-workbench-workers-4-author"
            frames = evidence / (label + "-frames")
            frames.mkdir()
            for name in ("mat-workbench-isolated-comparison-workbench.png", "mat-workbench-isolated-comparison-lab.png",
                         "mat-workbench-saved-workbench.png"):
                (frames / name).write_bytes(b"\x89PNG\r\n\x1a\nimage integrity fixture")
            identity = {"os": "Windows", "display": "Windows", "godot": "4.7-stable (official)",
                        "native_sha256": "a" * 64,
                        "test_sha256": subject.engine.runner.sha256(project / "tests/test_material_lab_workbench_integration.gd"),
                        "history_helper_sha256": subject.engine.runner.sha256(project / "tests/test_art_undo.gd")}
            for name in ("simulation_worker.gd", "shared_workbench.gd", "art_batch_executor.gd", "art_batch_panel.gd",
                         "workbench_paint_editor_controller.gd", "workbench_paint_editor_executor.gd",
                         "workbench_paint_editor_history.gd", "workbench_setup.gd", "material_lab_panel.gd",
                         "material_lab_service.gd", "material_lab_catalogue.gd", "material_lab_world_panel.gd"):
                identity[name] = subject.engine.runner.sha256(project / "scripts" / name)
            receipt = {"checks": 10, "failures": 0, "errors": [], "complete": True, "workers": 4,
                       "phase": "author", "source_identity": identity}
            for mutation in ("pass", "phase", "complete", "display", "runtime", "script", "images"):
                value = copy.deepcopy(receipt)
                if mutation == "phase": value["phase"] = "reopen"
                if mutation == "complete": value["complete"] = False
                if mutation == "display": value["source_identity"]["display"] = "headless"
                if mutation == "runtime": value["source_identity"]["native_sha256"] = "b" * 64
                if mutation == "script": value["source_identity"]["shared_workbench.gd"] = "c" * 64
                if mutation == "images": (frames / "mat-workbench-isolated-comparison-lab.png").unlink()
                (evidence / (label + ".log")).write_text("MAT_WB_EVIDENCE " + json.dumps(value) + "\n")
                with self.subTest(mutation=mutation):
                    if mutation == "pass":
                        subject.verify_combined_case(evidence, label, project, 4, "author", platform="windows", native_sha="a" * 64)
                    else:
                        with self.assertRaises(RuntimeError):
                            subject.verify_combined_case(evidence, label, project, 4, "author", platform="windows", native_sha="a" * 64)

    def test_workbench_entry_preserves_bundled_lab_environment(self):
        original_launcher = '@echo off\r\nset "CYBERSAND_LAB_CXX=%~dp0dependencies\\cxx\\bin\\g++.exe"\r\nset "CYBERSAND_SOURCE_REVISION=abc"\r\ngodot res://materials_lab.tscn\r\n'
        converted = package.workbench_launcher(original_launcher)
        self.assertEqual(converted.replace('-- --workbench', 'res://materials_lab.tscn'), original_launcher)
        for malformed in ("godot", original_launcher * 2):
            with self.assertRaises(RuntimeError): package.workbench_launcher(malformed)

    def test_source_campaign_keeps_paired_userdata_outside_checkout_and_retains_it_afterward(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            project = source / "godot"
            project.mkdir(parents=True)
            evidence = source / "build/evidence"
            evidence.mkdir(parents=True)
            calls = []
            class Recorder:
                def godot(self, project, label, script, marker, **kwargs):
                    env = kwargs["env"]
                    userdata = Path(env["APPDATA"])
                    self_outer.assertFalse(userdata.is_relative_to(source))
                    self_outer.assertEqual(env["APPDATA"], env["XDG_DATA_HOME"])
                    self_outer.assertEqual(kwargs["max_fps"], 5)
                    self_outer.assertEqual(subject.lab.GRAPHICAL_MAX_FPS, 15)
                    userdata.mkdir(parents=True, exist_ok=True)
                    (userdata / "saved-layout.json").write_text('{"saved":true}\n')
                    calls.append((env["ART_UNDO_WORKERS"], env["MAT_WB_REOPEN"], str(userdata)))
            self_outer = self
            runner = Recorder()
            runner.evidence = evidence
            with patch.object(subject, "verify_combined_case"):
                subject.combined_lab_workbench(runner, project)
            self.assertEqual([item[:2] for item in calls], [("1", "0"), ("1", "1"), ("4", "0"), ("4", "1")])
            self.assertEqual(calls[0][2], calls[1][2])
            self.assertEqual(calls[2][2], calls[3][2])
            self.assertNotEqual(calls[0][2], calls[2][2])
            for workers in (1, 4):
                self.assertEqual((evidence / f"workers-{workers}-userdata/saved-layout.json").read_text(), '{"saved":true}\n')
            self.assertFalse(Path(calls[0][2]).exists())

    def test_packaged_profiles_runtime_and_launcher_survive_composition(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            WindowsRuntime().stage(root)
            for name in ("examples/worldgen", "godot/authoring/worldgen"):
                path = root / "source" / name
                path.mkdir(parents=True)
                (path / "profile.json").write_text('{"profile":"fixture"}\n')
            launcher = 'godot res://materials_lab.tscn\r\n'
            (root / "Open-Materials-Lab.cmd").write_bytes(launcher.encode())
            (root / "Open Workbench.cmd").write_bytes(package.workbench_launcher(launcher).encode())
            identity = {"integration_scope": "MAT-AUTH #562 + Integrated Workbench #564",
                        "vc_runtime_sha256": package.lab.sha(root / "vcruntime140.dll"),
                        "generator_profiles_sha256": {"profile.json": package.lab.sha(root / "source/examples/worldgen/profile.json")}}
            with patch.object(package.lab, "verify_package", return_value=identity):
                package.verify(root)
                (root / "source/godot/authoring/worldgen/profile.json").write_text('{}')
                with self.assertRaises(RuntimeError): package.verify(root)


if __name__ == "__main__":
    unittest.main()
