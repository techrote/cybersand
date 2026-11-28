#!/usr/bin/env python3
"""Adversarial admission/readback controls for the finite Art recovery adapter."""
from __future__ import annotations

import copy
from contextlib import nullcontext
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import types
import unittest
from unittest import mock
import zipfile

import mergedown_art_qualification as q

ROOT = Path(__file__).resolve().parents[2]
REQUEST = ROOT / "tools/fixtures/mergedown-art-windows-request.json"


class AdmissionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_original_complete_case_inventory_and_watchdogs(self):
        runner = q.module(ROOT, "run_godot_regressions")
        cases = {case.name: case for case in runner.discover_cases(ROOT)}
        self.assertEqual([name for mode in q.MODES[:3] for name in q.selected_names(mode)], list(q.CORE))
        self.assertEqual(len(q.CORE), 23)
        for mode in q.MODES:
            plan = q.plan(ROOT, mode)
            self.assertLessEqual(plan["total_seconds"], 360 * 60)
            self.assertEqual([case["timeout_seconds"] for case in plan["cases"]],
                             [cases[name].timeout for name in q.selected_names(mode)])
        self.assertEqual(cases["test_art_architecture_workbench"].timeout, 3940)
        self.assertEqual(cases["test_workbench_combined_authoring"].timeout, 1200)

    def test_extended_source_budget_refuses_before_hosted_work(self):
        runner = q.module(ROOT, "run_godot_regressions")
        cases = runner.discover_cases(ROOT)
        changed = [q.replace(case, timeout=30000) if case.name == q.CORE[0] else case for case in cases]
        with mock.patch.object(runner, "discover_cases", return_value=changed):
            with self.assertRaisesRegex(ValueError, "six-hour"):
                q.plan(ROOT, "retained-core-0")

    def test_request_rejects_missing_duplicate_modes_and_owner_activation(self):
        original = q.read(REQUEST)
        for key, value in (("modes", list(q.MODES[:-1])), ("modes", list(q.MODES) + [q.MODES[0]]),
                           ("owner_accepted", True), ("public_release", True), ("source_commit", "main"),
                           ("native_inputs", 117), ("status", "pending")):
            with self.subTest(key=key, value=value):
                request = dict(original, **{key: value})
                q.write(self.root / "request.json", request)
                with self.assertRaises(ValueError):
                    q.request(self.root / "request.json")

    def test_duplicate_json_keys_refuse(self):
        path = self.root / "duplicate.json"
        path.write_text('{"passed":false,"passed":true}')
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            q.read(path)

    def test_required_source_contract_cannot_be_omitted_or_substituted(self):
        for required in ("tools/ci/run_art_storage_qualification.py", "tools/ci/_architecture_campaign_context.py"):
            for substitution in (False, True):
                with self.subTest(required=required, substitution=substitution):
                    value = q.read(REQUEST)
                    del value["source_contracts_sha256"][required]
                    if substitution:
                        value["source_contracts_sha256"]["unrelated.py"] = "a" * 64
                    q.write(self.root / "request.json", value)
                    with self.assertRaisesRegex(ValueError, "qualification contracts"):
                        q.request(self.root / "request.json")

    def test_untracked_executable_input_refused_in_either_real_git_checkout(self):
        product, harness = self.root / "product", self.root / "harness"
        for root in (product, harness):
            root.mkdir()
            for args in (("init", "-q"), ("config", "user.name", "Fixture"),
                         ("config", "user.email", "fixture@example.invalid")):
                subprocess.run(["git", "-C", str(root), *args], check=True, stdout=subprocess.DEVNULL)
            (root / "application.py").write_text("# tracked source\n")
            subprocess.run(["git", "-C", str(root), "add", "."], check=True)
            subprocess.run(["git", "-C", str(root), "commit", "-qm", "fixture"], check=True)
        source = q.git(product, "rev-parse", "HEAD")
        value = {"source_commit": source, "source_tree": q.git(product, "rev-parse", "HEAD^{tree}"),
                 "accepted_main_baseline": source, "art_parent": source, "architecture_parent": source,
                 "source_contracts_sha256": {"application.py": q.sha(product / "application.py")}}
        env = {"GITHUB_SHA": q.git(harness, "rev-parse", "HEAD"), "GITHUB_RUN_ID": "42", "GITHUB_RUN_ATTEMPT": "1"}
        with mock.patch.object(q, "request", return_value=value), mock.patch.object(q, "plan", return_value={}), mock.patch.dict(os.environ, env):
            q.admit(REQUEST, product, harness)
            for root in (product, harness):
                unknown = root / "unknown_execution.py"
                unknown.write_text("raise RuntimeError('unregistered executable input')\n")
                with self.assertRaisesRegex(ValueError, "not clean committed source"):
                    q.admit(REQUEST, product, harness)
                unknown.unlink()

    def test_actual_campaign_context_required(self):
        for values in ({}, {"GITHUB_SHA": "a" * 40, "GITHUB_RUN_ID": "0", "GITHUB_RUN_ATTEMPT": "1"},
                       {"GITHUB_SHA": "a" * 40, "GITHUB_RUN_ID": "10", "GITHUB_RUN_ATTEMPT": "0"}):
            with mock.patch.dict(os.environ, values, clear=True):
                with self.assertRaises(ValueError):
                    q.context()

    def test_route_never_waives_future_application_changes(self):
        def git(*args):
            return subprocess.check_output(["git", "-C", str(self.root), *args], text=True, stderr=subprocess.DEVNULL).strip()
        git("init", "-q")
        git("config", "user.name", "Fixture")
        git("config", "user.email", "fixture@example.invalid")
        (self.root / "application.txt").write_text("source\n")
        git("add", ".")
        git("commit", "-qm", "application")
        source = git("rev-parse", "HEAD")
        value = dict(q.read(REQUEST), source_commit=source)
        request = self.root / "tools/fixtures/mergedown-art-windows-request.json"
        q.write(request, value)
        git("add", ".")
        git("commit", "-qm", "registered harness")
        self.assertIs(q.recovery_route(self.root, request)["recovery"], True)
        (self.root / "application.txt").write_text("new application\n")
        git("add", ".")
        git("commit", "-qm", "application changed")
        self.assertIs(q.recovery_route(self.root, request)["recovery"], False)
        self.assertIs(q.recovery_route(self.root, self.root / "absent")["recovery"], False)

    def test_command_failure_keeps_original_process_receipt(self):
        log = self.root / "failed.log"
        with self.assertRaises(ValueError):
            q.command([sys.executable, "-c", "import sys; print('original failure'); sys.exit(23)"],
                      self.root, log, 15)
        receipt = q.read(log.with_suffix(".log.process.json"))
        self.assertEqual(receipt["exit_code"], 23)
        self.assertIs(receipt["natural_completion"], True)
        self.assertIn("original failure", log.read_text())

    def test_command_timeout_is_not_completion(self):
        log = self.root / "timeout.log"
        with self.assertRaises(ValueError):
            q.command([sys.executable, "-c", "import time; time.sleep(30)"], self.root, log, 0.03)
        receipt = q.read(log.with_suffix(".log.process.json"))
        self.assertIs(receipt["timed_out"], True)
        self.assertIs(receipt["natural_completion"], False)

    def engine(self):
        archive = self.root / "engine.zip"
        names = ("Godot_v4.7-stable_win64_console.exe", "Godot_v4.7-stable_win64.exe")
        with zipfile.ZipFile(archive, "w") as bundle:
            for name in names:
                data = ("fixture bytes " + name).encode()
                bundle.writestr(name, data)
                (self.root / name).write_bytes(data)
        pin = types.SimpleNamespace(GODOT_SHA512=hashlib.sha512(archive.read_bytes()).hexdigest(),
                                    GODOT_VERSION="4.7.stable.official.5b4e0cb0f")
        return archive, self.root / names[0], pin

    def test_engine_exact_bytes_admitted(self):
        archive, binary, pin = self.engine()
        with mock.patch.object(q, "module", return_value=pin), mock.patch.object(q.subprocess, "check_output", return_value=pin.GODOT_VERSION):
            value = q.admit_engine(ROOT, archive, binary)
        self.assertEqual(value["sha256"], q.sha(binary))
        self.assertEqual(value["archive_sha512"], pin.GODOT_SHA512)

    def test_same_version_changed_engine_bytes_refused_before_execution(self):
        archive, binary, pin = self.engine()
        binary.write_bytes(b"same advertised version; different executable")
        with mock.patch.object(q, "module", return_value=pin), mock.patch.object(q.subprocess, "check_output") as version:
            with self.assertRaisesRegex(ValueError, "executable differs"):
                q.admit_engine(ROOT, archive, binary)
            version.assert_not_called()

    def test_wrong_engine_archive_refused(self):
        archive, binary, pin = self.engine()
        archive.write_bytes(archive.read_bytes() + b"changed")
        with mock.patch.object(q, "module", return_value=pin):
            with self.assertRaisesRegex(ValueError, "source pin"):
                q.admit_engine(ROOT, archive, binary)

    def base_receipt(self, mode="collaborative-headless"):
        binding = {"harness_commit": "a" * 40, "run_id": "5", "attempt": 1,
                   "source_commit": "b" * 40, "source_tree": "c" * 40,
                   "request_sha256": "d" * 64, "adapter_sha256": "e" * 64}
        logs = ("import.log", "collaborative.log")
        commands = []
        for name in logs:
            (self.root / name).write_text("original\n")
            commands.append({"log": name, "log_sha256": q.sha(self.root / name), "status": "passed",
                             "natural_completion": True, "exit_code": 0, "timed_out": False})
        value = {"schema": q.SCHEMA, "status": "passed", "completed": True, "platform": "win32",
                 "inputs_unchanged": True, "mode": mode, "model_calls": 0, "physical_owner_accepted": False,
                 **binding, "cases": [], "commands": commands, "files": q.inventory(self.root)}
        return value, binding

    def test_minimal_complete_mode_envelope(self):
        value, expected = self.base_receipt()
        q.verify_evidence(self.root, value, expected, value["mode"])

    def test_stale_source_run_attempt_and_harness_refused(self):
        value, expected = self.base_receipt()
        for key, changed in (("attempt", 2), ("attempt", True), ("run_id", "6"),
                             ("source_commit", "f" * 40), ("harness_commit", "f" * 40),
                             ("request_sha256", "f" * 64)):
            with self.subTest(key=key):
                with self.assertRaisesRegex(ValueError, "binding"):
                    q.verify_evidence(self.root, dict(value, **{key: changed}), expected, value["mode"])

    def test_linux_partial_or_owner_claim_cannot_be_windows_pass(self):
        value, expected = self.base_receipt()
        for key, changed in (("platform", "linux"), ("completed", False), ("model_calls", 1),
                             ("physical_owner_accepted", True), ("inputs_unchanged", False)):
            with self.subTest(key=key):
                with self.assertRaises(ValueError):
                    q.verify_evidence(self.root, dict(value, **{key: changed}), expected, value["mode"])

    def test_omitted_original_helper_refused(self):
        value, expected = self.base_receipt()
        value["commands"] = []
        with self.assertRaisesRegex(ValueError, "Missing original"):
            q.verify_evidence(self.root, value, expected, value["mode"])

    def test_tampered_file_inventory_refused(self):
        value, expected = self.base_receipt()
        (self.root / "import.log").write_text("changed\n")
        with self.assertRaisesRegex(ValueError, "inventory changed"):
            q.verify_evidence(self.root, value, expected, value["mode"])

    def test_resealed_inventory_does_not_hide_changed_original_log(self):
        value, expected = self.base_receipt()
        (self.root / "import.log").write_text("changed\n")
        value["files"] = q.inventory(self.root)
        with self.assertRaisesRegex(ValueError, "helper log differs"):
            q.verify_evidence(self.root, value, expected, value["mode"])

    def test_timeout_receipt_refused(self):
        value, expected = self.base_receipt()
        value["commands"][0]["timed_out"] = True
        with self.assertRaisesRegex(ValueError, "Failed source-owned"):
            q.verify_evidence(self.root, value, expected, value["mode"])

    def storage_receipt(self):
        return {"passed": True, "status": "passed", "completed": True, "platform": "win32",
                "source_head": "b" * 40, "inputs_unchanged": True, "cases": [
                    {"operation": operation, "fault": fault, "passed": True,
                     "natural_completion": True, "exit_code": 0} for operation, fault in q.STORAGE_ROWS]}

    def test_nine_windows_storage_rows_required(self):
        value = self.storage_receipt()
        q.verify_storage(value, {"source_commit": "b" * 40})
        for rows in (value["cases"][:-1], value["cases"] + [value["cases"][0]], list(reversed(value["cases"]))):
            with self.assertRaisesRegex(ValueError, "storage inventory"):
                q.verify_storage(dict(value, cases=rows), {"source_commit": "b" * 40})

    def test_original_private_and_public_storage_directory_names(self):
        self.assertEqual([q.storage_case_directory(operation, fault) for operation, fault in q.STORAGE_ROWS],
            ["export-normal", "export-locked-target", "new-event-normal", "append-normal", "append-locked-target",
             "settings-none", "settings-locked-target", "pending-history-none", "pending-history-existing-receipt"])

    def test_linux_faults_and_false_natural_completion_refused(self):
        value = self.storage_receipt()
        for changed in (dict(value, platform="linux"), dict(value, source_head="d" * 40)):
            with self.assertRaises(ValueError):
                q.verify_storage(changed, {"source_commit": "b" * 40})
        value["cases"][0]["natural_completion"] = False
        with self.assertRaises(ValueError):
            q.verify_storage(value, {"source_commit": "b" * 40})

    def test_duplicate_original_result_markers_refuse(self):
        log = self.root / "log"
        log.write_text('RESULT {}\nRESULT {}\n')
        with self.assertRaisesRegex(ValueError, "duplicate"):
            q.original_marker(log, "RESULT ")

    def test_all_original_required_retained_markers(self):
        log = self.root / "retained.log"
        for name, marker in q.RETAINED_MARKERS.items():
            with self.subTest(name=name):
                log.write_text(marker + '{"checks":5,"failures":[]}\n')
                q.verify_retained_case_log(name, log, name.endswith("_render"))
                log.write_text("process exited zero but omitted its original footer\n")
                with self.assertRaisesRegex(ValueError, "original result marker"):
                    q.verify_retained_case_log(name, log, name.endswith("_render"))

    def test_retained_marker_does_not_admit_failure_or_zero_assertions(self):
        log = self.root / "retained.log"
        for result in ({"checks":0,"failures":[]}, {"checks":1,"failures":["failed"]},
                       {"checks":True,"failures":[]}):
            log.write_text("ART_UNDO_RESULT " + json.dumps(result) + "\n")
            with self.assertRaisesRegex(ValueError, "completed assertions"):
                q.verify_retained_case_log("test_art_undo", log, False)

    def test_displayed_clipboard_requires_actual_native_differential(self):
        log = self.root / "clipboard.log"
        result = {"checks":6,"failures":[],"native_clipboard_differential":True}
        log.write_text("ART_CONVERSATION_CLIPBOARD_RESULT " + json.dumps(result) + "\n")
        q.verify_retained_case_log("test_art_conversation_clipboard", log, True)
        for changed in (False, 1, None):
            result["native_clipboard_differential"] = changed
            log.write_text("ART_CONVERSATION_CLIPBOARD_RESULT " + json.dumps(result) + "\n")
            with self.assertRaisesRegex(ValueError, "clipboard differential"):
                q.verify_retained_case_log("test_art_conversation_clipboard", log, True)

    def test_source_diagnostics_retain_original_dirty_paths(self):
        def original(command, **_):
            if "status" in command:
                return b"?? unknown-script.py\0" if "-z" in command else b"?? unknown-script.py\n"
            if "--name-only" in command:
                return b""
            return b"original binary diff\n"
        with mock.patch.object(q, "git", return_value="a" * 40), mock.patch.object(
                q.subprocess, "check_output", side_effect=original), mock.patch.object(
                q.subprocess, "run", return_value=types.SimpleNamespace(stdout=b"core.autocrlf false\n")):
            q.capture_source_state(ROOT, self.root)
        self.assertEqual((self.root / "source-status-nul.bin").read_bytes(), b"?? unknown-script.py\0")
        self.assertIn("unknown-script.py", (self.root / "source-status.txt").read_text())
        self.assertEqual((self.root / "unstaged.diff").read_bytes(), b"original binary diff\n")

    def runtime_checkout(self):
        """Real Git/LFS pointer/index fixture; source runtime verifier is mocked."""
        root = self.root / "runtime-product"
        root.mkdir()
        def git(*args):
            return subprocess.check_output(["git", "-C", str(root), *args], text=True, stderr=subprocess.DEVNULL).strip()
        for args in (("init", "-q"), ("config", "user.name", "Fixture"),
                     ("config", "user.email", "fixture@example.invalid"),
                     ("config", "core.autocrlf", "false"), ("lfs", "install", "--local")):
            git(*args)
        (root / ".gitattributes").write_text("*.dll filter=lfs diff=lfs merge=lfs -text\n")
        (root / "application.gd").write_text("# tracked application\n")
        paths = ("godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
                 "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll")
        payloads = {}
        for index, relative in enumerate(paths):
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            data = ("MZsynthetic-real-lfs-object-" + str(index)).encode()
            payloads[relative] = data
            path.write_bytes(("version https://git-lfs.github.com/spec/v1\noid sha256:"
                              + hashlib.sha256(data).hexdigest() + "\nsize " + str(len(data)) + "\n").encode())
        provenance = root / "godot/addons/godot-rapier2d/runtime-provenance.windows.json"
        q.write(provenance, {"source_inputs": {str(i): "a" * 64 for i in range(4)}})
        git("add", ".")
        git("commit", "-qm", "canonical pointers and source")
        expected = {"source_commit": git("rev-parse", "HEAD"), "source_tree": git("rev-parse", "HEAD^{tree}")}
        for relative, data in payloads.items():
            (root / relative).write_bytes(data)
        verifier = types.SimpleNamespace(verify_retained_runtime=mock.Mock(return_value={
            "native_source_inputs": {str(i): "a" * 64 for i in range(105)}}),
            execution_policy=types.SimpleNamespace(watchdog_seconds=lambda _: 300), metadata_budget=nullcontext)
        return root, expected, verifier, paths

    def test_only_exact_lfs_bytes_refresh_to_identical_git_tree(self):
        root, expected, verifier, _ = self.runtime_checkout()
        output = self.root / "refresh.json"
        with mock.patch.object(q, "module", return_value=verifier):
            q.refresh_verified_runtime_index(root, output, expected)
        receipt = q.read(output)
        self.assertEqual(receipt["status"], "passed")
        self.assertEqual(receipt["index_before"], receipt["index_after"])
        self.assertEqual(receipt["index_after"], expected["source_tree"])
        self.assertEqual(q.git(root, "status", "--porcelain=v1", "--untracked-files=all"), "")
        self.assertEqual(verifier.verify_retained_runtime.call_count, 2)

    def test_actual_changed_runtime_cannot_be_refreshed(self):
        root, expected, verifier, paths = self.runtime_checkout()
        (root / paths[0]).write_bytes(b"MZchanged bytes")
        with mock.patch.object(q, "module", return_value=verifier):
            with self.assertRaisesRegex(ValueError, "Runtime bytes differ"):
                q.refresh_verified_runtime_index(root, self.root / "refresh.json", expected)
        self.assertEqual(q.git(root, "write-tree"), expected["source_tree"])
        self.assertEqual((root / paths[0]).read_bytes(), b"MZchanged bytes")

    def test_unknown_input_is_not_hidden_by_runtime_refresh(self):
        root, expected, verifier, _ = self.runtime_checkout()
        (root / "unknown.gd").write_text("# unregistered executable input\n")
        with mock.patch.object(q, "module", return_value=verifier):
            with self.assertRaisesRegex(ValueError, "Unknown or actual source"):
                q.refresh_verified_runtime_index(root, self.root / "refresh.json", expected)
        self.assertEqual(q.git(root, "write-tree"), expected["source_tree"])
        self.assertTrue((root / "unknown.gd").is_file())

    def test_staged_source_is_never_reset_or_admitted(self):
        root, expected, verifier, _ = self.runtime_checkout()
        (root / "application.gd").write_text("# changed staged application\n")
        q.git(root, "add", "application.gd")
        staged = q.git(root, "write-tree")
        with mock.patch.object(q, "module", return_value=verifier):
            with self.assertRaisesRegex(ValueError, "Staged source"):
                q.refresh_verified_runtime_index(root, self.root / "refresh.json", expected)
        self.assertEqual(q.git(root, "write-tree"), staged)
        verifier.verify_retained_runtime.assert_not_called()

    def test_runtime_filter_must_preserve_committed_object(self):
        root, expected, verifier, _ = self.runtime_checkout()
        original = q.git
        def changed_filter(directory, *args):
            return "f" * 40 if args[0] == "hash-object" else original(directory, *args)
        with mock.patch.object(q, "module", return_value=verifier), mock.patch.object(q, "git", side_effect=changed_filter):
            with self.assertRaisesRegex(ValueError, "clean filter"):
                q.refresh_verified_runtime_index(root, self.root / "refresh.json", expected)
        self.assertEqual(q.git(root, "write-tree"), expected["source_tree"])

    def test_source_owned_native_contract_remains_mandatory(self):
        root, expected, verifier, _ = self.runtime_checkout()
        verifier.verify_retained_runtime.return_value = {"native_source_inputs": {str(i): "a" * 64 for i in range(104)}}
        with mock.patch.object(q, "module", return_value=verifier):
            with self.assertRaisesRegex(ValueError, "native input contract"):
                q.refresh_verified_runtime_index(root, self.root / "refresh.json", expected)
        self.assertEqual(q.git(root, "write-tree"), expected["source_tree"])

    def test_runtime_proof_requires_its_complete_source_allowance(self):
        root, _, verifier, _ = self.runtime_checkout()
        metadata = q.MetadataEnvelope(299)
        with metadata.phase(), self.assertRaisesRegex(ValueError, "complete runtime proof"):
            q.verified_runtime(root, verifier)
        verifier.verify_retained_runtime.assert_not_called()

    def test_metadata_deadline_is_cumulative_and_paused_between_phases(self):
        metadata = q.MetadataEnvelope(900)
        with mock.patch.object(q.time, "monotonic", side_effect=[10, 110, 110]):
            with metadata.phase():
                pass
        self.assertEqual(metadata.remaining, 800)
        with mock.patch.object(q.time, "monotonic", side_effect=[5000, 5100, 5100]):
            with metadata.phase():
                pass
        self.assertEqual(metadata.remaining, 700)
        self.assertIsNone(q._METADATA_DEADLINE)

    def test_metadata_overrun_refuses_and_restores_outer_state(self):
        metadata = q.MetadataEnvelope(1)
        with mock.patch.object(q.time, "monotonic", side_effect=[10, 12, 12]):
            with self.assertRaisesRegex(ValueError, "allowance exhausted"):
                with metadata.phase():
                    pass
        self.assertIsNone(q._METADATA_DEADLINE)


if __name__ == "__main__":
    unittest.main()
