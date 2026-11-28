#!/usr/bin/env python3
"""Adversarial custody tests; synthetic fixtures are never product qualification."""
from __future__ import annotations

import copy
from contextlib import ExitStack
import json
import importlib
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock
import zipfile

import mainline_evaluator as delivery


class DeliveryCustody(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mainline-delivery-test-")
        self.root = Path(self.temporary.name)

    def tearDown(self):
        self.temporary.cleanup()

    def request_fixture(self):
        return {"schema": delivery.SCHEMA, "repository": "techrote/cybersand", "status": "admitted",
                "source_commit": "1" * 40, "source_tree": "2" * 40, "accepted_main_at_request": "1" * 40,
                "required_foundations": copy.deepcopy(delivery.FOUNDATIONS),
                "native_source_input_count": 105, "rapier_source_input_count": 4,
                "owner_playfeel_accepted": False, "public_release": False}

    def requested(self, value=None):
        path = self.root / "request.json"
        delivery.write(path, self.request_fixture() if value is None else value)
        return path

    def test_exact_admitted_request_is_read(self):
        self.assertEqual(delivery.request(self.requested()), self.request_fixture())

    def test_prepared_incomplete_or_moved_request_is_refused(self):
        for key, value in (("status", "prepared"), ("source_commit", "main"), ("source_tree", "0" * 40),
                           ("accepted_main_at_request", "3" * 40), ("required_foundations", {}),
                           ("native_source_input_count", 105.0), ("native_source_input_count", 106),
                           ("rapier_source_input_count", 5), ("owner_playfeel_accepted", True), ("public_release", True)):
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                changed = self.request_fixture()
                changed[key] = value
                delivery.request(self.requested(changed))

    def test_duplicate_request_key_is_refused(self):
        path = self.root / "duplicate.json"
        path.write_text('{"status":"prepared","status":"admitted"}')
        with self.assertRaisesRegex(ValueError, "Duplicate JSON key"):
            delivery.read(path)

    def create_git(self, name, files):
        root = self.root / name
        root.mkdir()
        subprocess.run(["git", "init", "--initial-branch=main", str(root)], check=True, capture_output=True)
        delivery.git(root, "config", "user.name", "Synthetic custody fixture")
        delivery.git(root, "config", "user.email", "fixture@example.invalid")
        delivery.git(root, "config", "core.autocrlf", "false")
        for name in files:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("Synthetic custody fixture, not product source.\n")
        delivery.git(root, "add", ".")
        delivery.git(root, "commit", "-qm", "Synthetic fixture")
        return root

    def admission_fixture(self):
        product = self.create_git("product", ["fixture.txt"])
        base = delivery.git(product, "rev-parse", "HEAD")
        (product / "fixture.txt").write_text("A second fixture commit.\n")
        for relative, count, digest in (("godot/addons/cybersand_native/runtime-provenance.json", 105, "a" * 64),
                                       ("godot/addons/godot-rapier2d/runtime-provenance.windows.json", 4, "b" * 64)):
            delivery.write(product / relative, {"sha256": digest, "source_inputs": {str(i): "fixture" for i in range(count)}})
        case = product / ("godot/tests/" + delivery.DEFAULT_OFF_CASE + ".gd")
        case.parent.mkdir(parents=True, exist_ok=True)
        case.write_text('extends SceneTree\nconst Watchdogs = preload("res://tests/support/ci_execution_policy.gd")\n')
        delivery.git(product, "add", ".")
        delivery.git(product, "commit", "-am", "Synthetic successor")
        source = delivery.git(product, "rev-parse", "HEAD")
        delivery.git(product, "update-ref", "refs/remotes/origin/main", source)
        harness = self.create_git("harness", delivery.SOURCE_FILES)
        value = self.request_fixture()
        value.update(source_commit=source, source_tree=delivery.git(product, "rev-parse", "HEAD^{tree}"), accepted_main_at_request=source,
                     required_foundations={"fixture_foundation": base})
        return product, harness, value

    @staticmethod
    def policy():
        return json.loads((Path(__file__).resolve().parents[2] / "godot/tests/support/ci_execution_policy.json").read_text())

    def admission_context(self, product, harness, value):
        stack = ExitStack()
        stack.enter_context(mock.patch.object(delivery, "FOUNDATIONS", value["required_foundations"]))
        stack.enter_context(mock.patch.object(delivery, "SOURCE_CONTRACTS", {"fixture.txt": delivery.source_contract_sha(product / "fixture.txt")}))
        def module(_root, name):
            return SimpleNamespace(identity=self.policy) if name == "execution_policy" else importlib.import_module(name)
        stack.enter_context(mock.patch.object(delivery, "product_module", side_effect=module))
        stack.enter_context(mock.patch.dict(os.environ, {"GITHUB_SHA": delivery.git(harness, "rev-parse", "HEAD")}))
        return stack

    def test_actual_git_ancestry_and_separate_harness_are_admitted(self):
        product, harness, value = self.admission_fixture()
        with self.admission_context(product, harness, value):
            result = delivery.admit(self.requested(value), product, harness)
        self.assertEqual(result["source_commit"], value["source_commit"])
        self.assertNotEqual(result["source_commit"], result["harness_commit"])
        self.assertTrue(result["source_is_accepted_main_ancestor"])

    def test_unmerged_source_is_refused_even_when_self_declared_accepted(self):
        product, harness, value = self.admission_fixture()
        delivery.git(product, "update-ref", "refs/remotes/origin/main", value["required_foundations"]["fixture_foundation"])
        with self.admission_context(product, harness, value), self.assertRaises(subprocess.CalledProcessError):
            delivery.admit(self.requested(value), product, harness)

    def test_dirty_source_and_wrong_harness_run_are_refused(self):
        product, harness, value = self.admission_fixture()
        with self.admission_context(product, harness, value), mock.patch.dict(os.environ, {"GITHUB_SHA": "9" * 40}), self.assertRaisesRegex(ValueError, "Harness"):
            delivery.admit(self.requested(value), product, harness)
        (product / "untracked.txt").write_text("uncommitted product")
        with self.admission_context(product, harness, value), self.assertRaisesRegex(ValueError, "clean committed"):
            delivery.admit(self.requested(value), product, harness)

    def identities(self):
        admission = {"schema": "cybersand-accepted-main-evaluator-admission-v1", "status": "passed",
                     "source_is_accepted_main_ancestor": True, "source_commit": "1" * 40, "source_tree": "2" * 40,
                     "runtime_expected": {"native_sha256": "a" * 64, "rapier_sha256": "b" * 64,
                                          "native_provenance_sha256": "c" * 64, "rapier_provenance_sha256": "d" * 64}}
        goblin = {"schema": "cybersand-goblin-evaluator-v1", "source_commit": "1" * 40, "source_tree": "2" * 40,
                  "provenance": {"native_source_input_count": 105, "rapier_source_input_count": 4,
                  "native_sha256": "a" * 64, "rapier_sha256": "b" * 64, "native_build_commit": "3" * 40,
                  "native_provenance_sha256": "c" * 64, "rapier_provenance_sha256": "d" * 64,
                  "source_commit": "1" * 40, "source_tree": "2" * 40, "source_dirty": False}}
        return admission, goblin

    def test_matching_constituent_identities_are_admitted(self):
        delivery.verify_constituent_identities(*self.identities())

    def test_assembly_calls_the_source_owned_runtime_helper(self):
        # Reach the real assembly join with a deliberately refused runtime.
        # qualify_ambient has no `windows` attribute; that obsolete indirection
        # must not fail before the actual source-owned verifier gets authority.
        product = Path(__file__).resolve().parents[2]
        admission, goblin = self.identities()
        admission_path = self.root / "admission.json"
        delivery.write(admission_path, admission)
        archive = self.archive([("CyberSand-goblin/goblin-evaluator-manifest.json",
                                 json.dumps(goblin).encode())])
        runtime = delivery.product_module(product, "run_windows_godot_regressions")
        args = SimpleNamespace(product=product, admission=admission_path,
                               goblin_archive=archive, output=self.root / "assembly",
                               archive=self.root / "delivery.zip")
        with mock.patch.object(delivery, "run_verifiers"), mock.patch.object(
                runtime, "verify_retained_runtime", side_effect=ValueError("Deliberately refused runtime")) as check:
            with self.assertRaisesRegex(ValueError, "Deliberately refused runtime"):
                delivery.assemble(args)
        check.assert_called_once_with(product)

    def test_finalizer_accepts_actual_delivered_proof_options_and_refuses_drift(self):
        proof = (Path(__file__).parent / "verify_mainline_launchers.ps1").read_text()
        matches = re.findall(r"Invoke-DeliveredCmd 'workbench' 'Open Workbench.cmd' '([^']+)'", proof)
        self.assertEqual(len(matches), 1)
        text = "OpenGL API ANGLE synthetic fixture\nSHARED_WORKBENCH_LAUNCH_READY synthetic fixture\n"
        delivery.verify_workbench_launcher(matches[0], text)
        for arguments, changed in (("--quit-after 180", text), (matches[0] + " --headless", text),
                                   (matches[0], text.replace("OpenGL API ANGLE", "headless")),
                                   (matches[0], text + text)):
            with self.subTest(arguments=arguments, log=changed), self.assertRaises(ValueError):
                delivery.verify_workbench_launcher(arguments, changed)

    @unittest.skipUnless(sys.platform == "win32", "Actual Windows shell autoload requires Windows")
    def test_delivered_cmd_preserves_hashing_through_powershell7_intermediate(self):
        folder = self.root / "Actual CMD path with spaces"
        workbench = folder / "workbench"
        workbench.mkdir(parents=True)
        original = ('@echo off\nsetlocal\npowershell.exe -NoProfile -ExecutionPolicy Bypass '
                    '-File "%~dp0workbench\\Open goblin.ps1" %*\nexit /b %errorlevel%\n')
        content = workbench / "fixture.txt"
        content.write_bytes(b"Synthetic shell custody fixture, not product qualification.\n")
        (workbench / "Open goblin.ps1").write_text(
            "$ErrorActionPreference = 'Stop'\n(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'fixture.txt') -Algorithm SHA256).Hash.ToLowerInvariant()\n",
            encoding="utf-8")
        before = folder / "Before.cmd"
        repaired = folder / "Open Goblin.cmd"
        before.write_text(original, encoding="utf-8", newline="\r\n")
        repaired.write_text(delivery.goblin_launcher(), encoding="utf-8", newline="\r\n")
        def execute(path):
            # cmd.exe does not use the C-runtime backslash-quote grammar that
            # subprocess.list2cmdline applies to a list. Match the real proof's
            # /s /c outer quoting instead of manufacturing literal backslashes.
            command = '"' + os.environ["ComSpec"] + '" /d /s /c ""' + str(path) + '""'
            return subprocess.run(command,
                                  cwd=folder, capture_output=True, text=True, timeout=30)
        baseline = execute(before)
        result = execute(repaired)
        print("MAINLINE_SHELL_AUTOLOAD_CONTROL " + json.dumps({
            "original_exit": baseline.returncode, "original_stdout": baseline.stdout, "original_stderr": baseline.stderr,
            "corrected_exit": result.returncode, "corrected_stdout": result.stdout, "corrected_stderr": result.stderr,
            "inherited_module_path": os.environ.get("PSModulePath"), "expected_sha256": delivery.sha(content)}))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), delivery.sha(content))
        self.assertEqual(result.stderr.strip(), "")

    def test_other_source_and_other_runtime_are_refused(self):
        for mutate in (lambda g: g.update(source_commit="9" * 40),
                       lambda g: g["provenance"].update(native_sha256="9" * 64),
                       lambda g: g["provenance"].update(rapier_source_input_count=5),
                       lambda g: g["provenance"].update(source_dirty=True),
                       lambda g: g["provenance"].update(native_provenance_sha256="9" * 64)):
            admission, goblin = self.identities()
            mutate(goblin)
            with self.assertRaises(ValueError):
                delivery.verify_constituent_identities(admission, goblin)

    def test_complete_budget_covers_each_declared_process_and_retention(self):
        product, harness, value = self.admission_fixture()
        with self.admission_context(product, harness, value):
            registered = delivery.registered_default_case(product)
        budget = delivery.execution_budget(self.policy(), registered)
        self.assertEqual(registered.timeout, importlib.import_module("execution_policy").complex_process_seconds())
        self.assertGreater(registered.timeout, importlib.import_module("execution_policy").case_seconds(delivery.DEFAULT_OFF_CASE))
        actual = next(row for row in budget["rows"] if row["name"].startswith("default-OFF"))
        self.assertEqual(actual["seconds"], self.policy()["watchdogs"]["godot_import_seconds"] + registered.timeout + 30)
        self.assertEqual(budget["default_off_registered_case"]["timeout_seconds"], registered.timeout)
        self.assertEqual(budget["total_seconds"], 21290)
        self.assertEqual(budget["required_minutes"], 355)
        self.assertEqual(budget["parent_minutes"], 360)
        self.assertEqual(budget["launcher_watchdogs"], {"workbench": 2460, "goblin": 1770})
        self.assertEqual(budget["source_tape_job"]["total_seconds"], 6240)
        self.assertEqual(budget["source_tape_job"]["parent_minutes"], 120)
        self.assertFalse(budget["full_ambient_feature_campaign_claimed"])

    def test_delivery_budget_requires_one_exact_64_action_successor_tape(self):
        folder = self.root / "successor"
        index = folder / "replay-corpus/index.json"
        case = {"id": "case-000", "attempted_actions": 64}
        delivery.write(index, {"cases": [case]})
        manifest = {"successor_contract_version": 3, "portable_replay_index": {
            "path": "replay-corpus/index.json", "sha256": delivery.sha(index),
            "required_replay_case": "case-000"}}
        delivery.verify_successor_replay(folder, manifest)
        for cases in ([], [case, case], [{**case, "attempted_actions": True}],
                      [{**case, "attempted_actions": 128}], [{**case, "id": "case-001"}]):
            delivery.write(index, {"cases": cases})
            changed = copy.deepcopy(manifest)
            changed["portable_replay_index"]["sha256"] = delivery.sha(index)
            with self.subTest(cases=cases), self.assertRaises(ValueError):
                delivery.verify_successor_replay(folder, changed)
        delivery.write(index, {"cases": [case]})
        with self.assertRaises(ValueError):
            delivery.verify_successor_replay(folder, {**manifest, "successor_contract_version": 2})
        index.write_bytes(index.read_bytes() + b" ")
        with self.assertRaisesRegex(ValueError, "exact successor"):
            delivery.verify_successor_replay(folder, manifest)

    def test_changed_policy_cannot_silently_overrun_parent(self):
        product, harness, value = self.admission_fixture()
        with self.admission_context(product, harness, value):
            registered = delivery.registered_default_case(product)
        policy = self.policy()
        policy["watchdogs"]["complex_fixture_seconds"] += 2000
        with self.assertRaisesRegex(ValueError, "exceeds"):
            delivery.execution_budget(policy, registered)

    def test_changed_source_proof_contract_requires_review(self):
        product, harness, value = self.admission_fixture()
        with self.admission_context(product, harness, value), mock.patch.object(delivery, "SOURCE_CONTRACTS", {"fixture.txt": "9" * 64}), self.assertRaisesRegex(ValueError, "requires review"):
            delivery.admit(self.requested(value), product, harness)

    def test_powershell_source_text_normalization_does_not_relax_raw_payload_hashes(self):
        source = self.root / "fixture.ps1"
        source.write_bytes(b"one\ntwo\n")
        canonical, original = delivery.source_contract_sha(source), delivery.sha(source)
        source.write_bytes(b"one\r\ntwo\r\n")
        self.assertEqual(delivery.source_contract_sha(source), canonical)
        self.assertNotEqual(delivery.sha(source), original)

    def auxiliary_fixture(self):
        folder = self.root / "auxiliary"
        (folder / "test-output/import").mkdir(parents=True)
        (folder / "test-output/graphical").mkdir(parents=True)
        imported = folder / "test-output/import/import.log"
        graphical = folder / "test-output/graphical/interactive-smoke.log"
        imported.write_text("Godot Engine v4.7.stable.official.5b4e0cb0f - synthetic fixture\n")
        graphical.write_text('OpenGL API ANGLE synthetic fixture\nGOBLIN_INTERACTIVE_RESULT {"checks":25,"failures":[],"evidence_kind":"graphical_godot"}\n')
        report = {"import_log": imported.relative_to(folder).as_posix(), "import_log_sha256": delivery.sha(imported),
                  "graphical_smoke": {"status": "pass", "log": graphical.relative_to(folder).as_posix(), "log_sha256": delivery.sha(graphical)}}
        return folder, report, imported, graphical

    def test_original_import_and_graphics_log_bytes_are_read_back(self):
        folder, report, _imported, _graphical = self.auxiliary_fixture()
        self.assertEqual(delivery.verify_goblin_auxiliary_logs(folder, report)["graphical_terminal"]["checks"], 25)

    def test_graphics_status_cannot_hide_missing_or_changed_original_logs(self):
        folder, report, imported, graphical = self.auxiliary_fixture()
        imported.write_text("changed purported import")
        with self.assertRaises(ValueError):
            delivery.verify_goblin_auxiliary_logs(folder, report)
        report["import_log_sha256"] = delivery.sha(imported)
        with self.assertRaisesRegex(ValueError, "pinned engine"):
            delivery.verify_goblin_auxiliary_logs(folder, report)
        report["import_log"] = "../outside.log"
        with self.assertRaises(ValueError):
            delivery.verify_goblin_auxiliary_logs(folder, report)

    def test_graphics_log_requires_unique_clean_completion_and_actual_renderer(self):
        folder, report, _imported, graphical = self.auxiliary_fixture()
        original = graphical.read_text()
        for changed in (original.replace("OpenGL API ANGLE", "headless"), original + "ERROR: a real failure\n",
                        original + original, original.replace('"checks":25', '"checks":true'),
                        original.replace('"failures":[]', '"failures":["failed assertion"]')):
            graphical.write_text(changed)
            report["graphical_smoke"]["log_sha256"] = delivery.sha(graphical)
            with self.subTest(log=changed[:60]), self.assertRaises(ValueError):
                delivery.verify_goblin_auxiliary_logs(folder, report)

    def archive(self, names, attributes=None):
        archive = self.root / "fixture.zip"
        with zipfile.ZipFile(archive, "w") as bundle:
            for name, content in names:
                info = zipfile.ZipInfo(name)
                # ZipInfo normally sanitizes names at construction on Windows.
                # Serialize the actual adversarial metadata on every host.
                info.filename = name
                info.orig_filename = name
                if attributes is not None:
                    info.external_attr = attributes
                bundle.writestr(info, content)
        with zipfile.ZipFile(archive) as observed:
            self.assertEqual([item.orig_filename for item in observed.infolist()],
                             [name for name, _content in names])
        return archive

    def test_pristine_constituent_zip_preserves_exact_bytes(self):
        archive = self.archive([("CyberSand-goblin/godot/example.gd", b"fixture\r\n")])
        target = self.root / "payload"
        delivery.extract(archive, target, "CyberSand-goblin/")
        self.assertEqual((target / "godot/example.gd").read_bytes(), b"fixture\r\n")

    def test_traversal_and_windows_collision_zip_are_refused(self):
        for index, names in enumerate(([('../escape', b'x')], [('File', b'x'), ('file', b'y')], [('bad\\path', b'x')], [('C:/bad', b'x')], [('hidden\x00suffix', b'x')])):
            with self.subTest(names=names), self.assertRaises(ValueError):
                delivery.extract(self.archive(names), self.root / str(index))

    def test_windows_reader_normalization_cannot_hide_raw_metadata(self):
        # This exercises the actual standard-library normalization path on
        # every host; it is not a claim of Windows package execution.
        with mock.patch.object(zipfile.os, "sep", "\\"):
            archive = self.archive([("bad\\path", b"fixture")])
            with zipfile.ZipFile(archive) as observed:
                info = observed.infolist()[0]
                self.assertEqual(info.orig_filename, "bad\\path")
                self.assertEqual(info.filename, "bad/path")
            with self.assertRaisesRegex(ValueError, "original filename"):
                delivery.extract(archive, self.root / "normalized-payload")

    def test_final_archive_readback_rejects_normalized_aliases(self):
        folder = self.payload()
        contents = [(p.relative_to(folder).as_posix(), p.read_bytes())
                    for p in sorted(folder.rglob("*")) if p.is_file()]
        selected = "workbench/godot/example.gd"
        for suffix, separator in (("\x00hidden", "/"), ("", "\\")):
            names = [((name + suffix if suffix else name.replace("/", "\\")) if name == selected else name, data)
                     for name, data in contents]
            with self.subTest(suffix=suffix, separator=separator), mock.patch.object(zipfile.os, "sep", separator):
                archive = self.archive(names)
                with self.assertRaisesRegex(ValueError, "original filename"):
                    delivery.verify_archive(archive, folder / delivery.MANIFEST)

    def test_zip_symlink_is_refused_on_all_platforms(self):
        archive = self.archive([("link", b"outside")], (stat.S_IFLNK | 0o777) << 16)
        with self.assertRaisesRegex(ValueError, "Symlink"):
            delivery.extract(archive, self.root / "payload")

    def payload(self):
        folder = self.root / "payload"
        (folder / "workbench/godot").mkdir(parents=True)
        (folder / "workbench/godot/example.gd").write_text("fixture source\n")
        delivery.write(folder / "workbench/evaluation-manifest.json", {"regenerated_imports_omitted": {}})
        files = {p.relative_to(folder).as_posix(): delivery.sha(p) for p in folder.rglob("*") if p.is_file()}
        delivery.write(folder / delivery.MANIFEST, {"schema": "cybersand-accepted-main-evaluator-v1", "owner_playfeel_accepted": False, "files_sha256": files})
        return folder

    def test_original_payload_and_scoped_user_outputs_are_distinguished(self):
        folder = self.payload()
        delivery.verify(folder, pristine=True)
        (folder / "workbench/userdata").mkdir()
        (folder / "workbench/userdata/save.json").write_text("fixture user save")
        delivery.verify(folder)
        with self.assertRaisesRegex(ValueError, "Pristine"):
            delivery.verify(folder, pristine=True)

    def test_changed_original_or_injected_script_is_refused(self):
        folder = self.payload()
        injected = folder / "workbench/godot/injected.gd"
        injected.write_text("unregistered script")
        with self.assertRaisesRegex(ValueError, "Unexpected"):
            delivery.verify(folder)
        injected.unlink()
        (folder / "workbench/godot/example.gd").write_text("different input")
        with self.assertRaisesRegex(ValueError, "payload changed"):
            delivery.verify(folder)

    def test_delivered_archive_cannot_change_after_extraction(self):
        folder = self.payload()
        names = [(p.relative_to(folder).as_posix(), p.read_bytes()) for p in folder.rglob("*") if p.is_file()]
        archive = self.archive(names)
        delivery.verify_archive(archive, folder / delivery.MANIFEST)
        changed = [(name, b"changed" if name.endswith("example.gd") else content) for name, content in names]
        self.archive(changed)
        with self.assertRaisesRegex(ValueError, "archive bytes"):
            delivery.verify_archive(archive, folder / delivery.MANIFEST)


if __name__ == "__main__":
    unittest.main(verbosity=2)
