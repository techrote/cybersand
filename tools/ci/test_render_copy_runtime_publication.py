#!/usr/bin/env python3
"""Adversarial checks of the isolated render-copy publication profile.

The unchanged shared-engine suite separately covers Git/LFS staging, PE/ELF,
source-ledger completeness and original log integrity. These tests prove this
profile retains those implementations and supplies its own fail-closed scope.
"""
import argparse
import copy
import hashlib
import inspect
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import lcb001_shared_contract_runtime_publication as historical
import render_copy_runtime_publication as profile

subject = profile.engine
BRANCH = "codex/render-copy-production-20261101"
WORKFLOW = ".github/workflows/render-copy-runtime-publication.yml"
# Independent fixture: removing a case from the profile cannot change this list.
SUCCESS_LOGS = {
    "test_render_world_generation": "RENDER_WORLD_GENERATION: 23 assertions, 0 failures\n",
    "test_native_render_bridge_regression":
        "Native RenderBridge regression passed; full 8192 bytes, delta 4 bytes/2 patches\n",
    "test_render_patch_handoff_regression": "Render patch handoff regression passed\n",
    "test_water_feel_integration":
        "WATER_FEEL_INTEGRATION: 24 policy cases + 70 scenario builds/reset/invalid/actions/RG8/authority passed default_hash=123456789\n",
    "test_liquid_solver_policy":
        'LIQUID_SOLVER_POLICY: 385 assertions; 0 failures; completed={"validation":true,"default_readback":true,"refusals":11,"parity_checkpoints":5,"cysd1_defaults":true,"whole_cell_admission_parity":true,"whole_cell_overlay_refusals":true}\n',
}


class RepositoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git("init", "--quiet")
        self.git("config", "user.name", "Render-copy publication fixture")
        self.git("config", "user.email", "render-copy-fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        for relative in (subject.REQUEST, subject.EVIDENCE, *(
                "godot/tests/" + name + ".gd" for name in SUCCESS_LOGS)):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            data = json.dumps(dict(subject.REQUEST_VALUE, request_sequence=1)) if relative == subject.REQUEST else "fixture"
            path.write_text(data + "\n", encoding="utf-8", newline="\n")
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "Frozen fixture source")
        self.source = self.git("rev-parse", "HEAD").decode().strip()
        patch = mock.patch.object(subject, "ROOT", self.root)
        patch.start()
        self.addCleanup(patch.stop)
        patch = mock.patch.dict(os.environ, {
            "GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_NAME": "push",
            "GITHUB_REF": "refs/heads/" + BRANCH,
            "GITHUB_WORKFLOW_REF": "techrote/cybersand/" + WORKFLOW + "@refs/heads/" + BRANCH,
            "GITHUB_SHA": self.source, "GITHUB_RUN_ID": "123456", "GITHUB_RUN_ATTEMPT": "1",
        })
        patch.start()
        self.addCleanup(patch.stop)

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], stderr=subprocess.PIPE)

    def test_exact_request_and_push_are_admitted(self):
        self.assertEqual(subject.context(self.source)["source_tree"], self.git("rev-parse", "HEAD^{tree}").decode().strip())
        subject.require_publication_request(self.source)

    def test_foreign_context_or_source_is_refused(self):
        for key, value in {
            "GITHUB_REPOSITORY": "other/cybersand", "GITHUB_EVENT_NAME": "pull_request",
            "GITHUB_REF": "refs/heads/main", "GITHUB_SHA": "f" * 40,
            "GITHUB_WORKFLOW_REF": "techrote/cybersand/.github/workflows/other.yml@refs/heads/" + BRANCH,
            "GITHUB_RUN_ATTEMPT": "0",
        }.items():
            with self.subTest(key=key), mock.patch.dict(os.environ, {key: value}):
                with self.assertRaises(RuntimeError):
                    subject.context(self.source)

    def test_absent_request_refuses_before_any_remote_access(self):
        (self.root / subject.REQUEST).unlink()
        with mock.patch.object(subject, "git", wraps=subject.git) as git:
            with self.assertRaisesRegex(RuntimeError, "Missing explicit"):
                subject.check_source(argparse.Namespace(source_sha=self.source))
            self.assertFalse(any(call.args[0] == "ls-remote" for call in git.call_args_list))

    def test_changed_request_bytes_are_refused(self):
        (self.root / subject.REQUEST).write_text("{}\n", encoding="utf-8")
        with self.assertRaisesRegex(RuntimeError, "differs from source commit"):
            subject.require_publication_request(self.source)

    def test_foreign_or_malformed_request_cannot_arm_profile(self):
        for overrides in ({"schema": "render-copy290-publish-request-v1"},
                          {"variant": "baseline_exemption"}, {"scope": "all"},
                          {"request_sequence": 0}, {"request_sequence": True},
                          {"request_sequence": "1"}, {"extra": "permission"}):
            with self.subTest(overrides=overrides):
                path = self.root / subject.REQUEST
                path.write_text(json.dumps(dict(subject.REQUEST_VALUE, request_sequence=1) | overrides) + "\n", encoding="utf-8")
                self.git("add", "--", subject.REQUEST)
                self.git("commit", "--quiet", "-m", "Invalid request fixture")
                with self.assertRaisesRegex(RuntimeError, "Invalid .* publish request"):
                    subject.require_publication_request(self.git("rev-parse", "HEAD").decode().strip())

    def test_source_lease_refuses_concurrent_branch_movement(self):
        with mock.patch.object(subject, "git", wraps=subject.git) as git:
            original = subject.git
            git.side_effect = lambda *args: (("f" * 40 + "\trefs/heads/" + BRANCH + "\n").encode()
                                           if args[0] == "ls-remote" else self.git(*args))
            with self.assertRaisesRegex(RuntimeError, "Feature branch changed"):
                subject.check_source(argparse.Namespace(source_sha=self.source))
        self.assertEqual(self.git("rev-parse", "HEAD").decode().strip(), self.source)

    def test_missing_render_or_water_case_refuses_admission(self):
        for name in SUCCESS_LOGS:
            path = self.root / "godot/tests" / (name + ".gd")
            data = path.read_bytes()
            path.unlink()
            with self.subTest(name=name), self.assertRaisesRegex(RuntimeError, "regression is not implemented"):
                subject.require_publication_request(self.source)
            path.write_bytes(data)


class ProfileTests(unittest.TestCase):
    def test_profile_does_not_mutate_shared_or_historical_owners(self):
        self.assertIsNot(subject, historical)
        self.assertEqual(historical.BRANCH, "codex/lcb001-shared-contract")
        self.assertEqual(subject.BRANCH, BRANCH)
        self.assertEqual(subject.WORKFLOW, WORKFLOW)
        self.assertEqual(list(subject.CASE_MARKERS), list(SUCCESS_LOGS))
        self.assertNotIn(historical.WORKFLOW, subject.BUILD_EXACT)
        self.assertNotIn(historical.REQUEST, subject.BUILD_EXACT)
        self.assertTrue({WORKFLOW, subject.REQUEST, subject.EVIDENCE,
                         "tools/ci/lcb001_shared_contract_runtime_publication.py",
                         "tools/ci/render_copy_runtime_publication.py"}.issubset(subject.BUILD_EXACT))

    def test_all_source_byte_lease_staging_and_execution_guards_are_unchanged(self):
        for name in ("context", "require_publication_request", "check_source", "input_ledgers",
                     "runtime_identity", "record_build", "execute", "stage", "check_index", "verify_case_results"):
            with self.subTest(name=name):
                self.assertEqual(inspect.getsource(getattr(subject, name)), inspect.getsource(getattr(historical, name)))
        self.assertEqual(inspect.getsource(profile._verify_bundle), inspect.getsource(historical.verify_bundle))

    def test_selected_case_watchdogs_flags_and_display_requirements_are_preserved(self):
        discovered = {case.name: case for case in subject.runner.discover_cases()}
        cases = subject.focused_cases(discovered)
        self.assertEqual([case.name for case in cases], ["import", *SUCCESS_LOGS])
        self.assertEqual(cases[0].timeout, subject.runner.execution_policy.watchdog_seconds("godot_import_seconds"))
        for case in cases[1:]:
            self.assertEqual(case, discovered[case.name])
            self.assertFalse(case.requires_display)
        # Hosted parent budgets leave full room for the unshortened case ceilings.
        self.assertLess(sum(case.timeout for case in cases), 240 * 60)
        del discovered["test_render_patch_handoff_regression"]
        with self.assertRaises(RuntimeError):
            subject.focused_cases(discovered)


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.report = {"results": [], "log_sha256": {}}
        for name, text in {"import": "clean import\n", **SUCCESS_LOGS}.items():
            self.report["results"].append({"name": name, "status": "passed", "returncode": 0,
                                           "diagnostic_error": False, "launch_error": None, "skip_messages": []})
            self.write_log(name, text)

    def write_log(self, name, text):
        path = self.root / (name + ".log")
        path.write_bytes(text.encode())
        self.report["log_sha256"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()

    def test_exact_complete_host_receipt_passes(self):
        subject.verify_case_results(self.root, self.report)

    def test_missing_duplicate_or_reordered_case_is_refused(self):
        for name in SUCCESS_LOGS:
            changed = dict(self.report, results=[row for row in self.report["results"] if row["name"] != name])
            with self.subTest(name=name), self.assertRaises(RuntimeError):
                subject.verify_case_results(self.root, changed)
        for rows in (list(reversed(self.report["results"])), self.report["results"] + [self.report["results"][-1]]):
            with self.assertRaises(RuntimeError):
                subject.verify_case_results(self.root, dict(self.report, results=rows))

    def test_missing_duplicate_error_skip_or_failing_summary_is_refused(self):
        for name, original in SUCCESS_LOGS.items():
            for text in ("no completed work\n", original * 2, original + "ERROR: after success\n",
                         original + "SKIP missing input\n"):
                with self.subTest(name=name, text=text):
                    self.write_log(name, text)
                    with self.assertRaises(RuntimeError):
                        subject.verify_case_results(self.root, self.report)
            self.write_log(name, original)
        for text in ("RENDER_WORLD_GENERATION: 0 assertions, 0 failures\n",
                     "RENDER_WORLD_GENERATION: 23 assertions, 1 failures\n"):
            self.write_log("test_render_world_generation", text)
            with self.assertRaises(RuntimeError):
                subject.verify_case_results(self.root, self.report)

    def test_changed_raw_log_and_passing_record_with_failure_are_refused(self):
        path = self.root / "test_water_feel_integration.log"
        path.write_bytes(path.read_bytes() + b"extra bytes\n")
        with self.assertRaisesRegex(RuntimeError, "digest mismatch"):
            subject.verify_case_results(self.root, self.report)
        self.write_log("test_water_feel_integration", SUCCESS_LOGS["test_water_feel_integration"])
        for field, value in (("status", "failed"), ("returncode", 1), ("diagnostic_error", True),
                             ("skip_messages", ["skipped"]), ("launch_error", "failed")):
            changed = copy.deepcopy(self.report)
            changed["results"][1][field] = value
            with self.subTest(field=field), self.assertRaises(RuntimeError):
                subject.verify_case_results(self.root, changed)

    def test_water_policy_noop_or_missing_sections_are_refused(self):
        prefix, raw = SUCCESS_LOGS["test_liquid_solver_policy"].split("completed=", 1)
        sections = json.loads(raw)
        for values in ({key: val for key, val in sections.items() if key != "parity_checkpoints"},
                       sections | {"parity_checkpoints": 0}, sections | {"validation": 1}):
            self.write_log("test_liquid_solver_policy", prefix + "completed=" + json.dumps(values) + "\n")
            with self.assertRaises(RuntimeError):
                subject.verify_case_results(self.root, self.report)


class NativeEvidenceTests(unittest.TestCase):
    def test_native_proof_requires_real_work_and_exact_failure_free_summary(self):
        result = {"assertions": 100, "regions": 20, "compared_bytes": 10000,
                  "nonmutation_checks": 40, "refusal_checks": 8, "failures": 0}
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(subject, "context", return_value={"source_commit": "a" * 40}):
            log, output = Path(directory) / "native.log", Path(directory) / "receipt.json"
            good = "RENDER_COPY_QUALIFICATION " + json.dumps(result) + "\n"
            log.write_text(good, encoding="utf-8")
            self.assertEqual(profile.verify_native(log, output, "a" * 40)["result"], result)
            invalid = ["", good * 2, good + "AddressSanitizer error\n",
                       good.replace('"failures": 0', '"failures": 1'),
                       good.replace('"failures": 0', '"failures": 0, "failures": 0')]
            for field in result:
                if field != "failures":
                    for value in (0, -1, True, "100"):
                        invalid.append("RENDER_COPY_QUALIFICATION " + json.dumps(result | {field: value}) + "\n")
            for text in invalid:
                log.write_text(text, encoding="utf-8")
                with self.subTest(text=text), self.assertRaises(RuntimeError):
                    profile.verify_native(log, output, "a" * 40)

    def test_validated_artifact_keeps_its_original_attempt_identity(self):
        with tempfile.TemporaryDirectory() as directory, mock.patch.dict(os.environ, {"GITHUB_RUN_ID": "123456"}):
            root = Path(directory)
            (root / "validation.json").write_text(json.dumps({"scope": subject.EXECUTION_SCOPE}), encoding="utf-8")
            manifest = {"workflow_attempt": "1", "validation_output": "render-copy-runtime-attempt-1-windows-123456/validation.json"}
            with mock.patch.object(profile, "_verify_bundle", return_value=manifest):
                self.assertEqual(profile.verify_bundle(root, "windows", "a" * 40, True), manifest)
                manifest["validation_output"] = "render-copy-runtime-attempt-2-windows-123456/validation.json"
                with self.assertRaisesRegex(RuntimeError, "artifact identity"):
                    profile.verify_bundle(root, "windows", "a" * 40, True)


if __name__ == "__main__":
    unittest.main()
