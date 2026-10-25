#!/usr/bin/env python3
"""LCB-002 profile checks; the shared engine retains its complete guard suite."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import lcb001_shared_contract_runtime_publication as historical
import lcb002_pressure_runtime_publication as profile
from test_lcb001_shared_contract_runtime_publication import SUCCESS_LOGS

subject = profile.engine
SECTIONS = {"native_variants": True, "readback_encoding": True, "exact_parity": True,
            "gas_invalidation": True, "cold_restore": True, "default_preservation": True}
CASE = "test_lcb_pressure_optimization"


class ProfileTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.git("init", "--quiet")
        self.git("config", "user.name", "LCB publisher fixture")
        self.git("config", "user.email", "lcb-fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        for relative in (subject.REQUEST, subject.EVIDENCE, *(
                "godot/tests/" + name + ".gd" for name in subject.CASE_MARKERS)):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(dict(subject.REQUEST_VALUE, request_sequence=1))
                            if relative == subject.REQUEST else "fixture\n", encoding="utf-8")
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "Fixture")
        self.source = self.git("rev-parse", "HEAD").strip()
        patch = mock.patch.object(subject, "ROOT", self.root)
        patch.start()
        self.addCleanup(patch.stop)
        patch = mock.patch.dict(os.environ, {
            "GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_NAME": "push",
            "GITHUB_REF": "refs/heads/codex/lcb002-pressure-variants",
            "GITHUB_WORKFLOW_REF": "techrote/cybersand/.github/workflows/lcb002-pressure-variants-runtime-publication.yml@refs/heads/codex/lcb002-pressure-variants",
            "GITHUB_SHA": self.source, "GITHUB_RUN_ID": "123456", "GITHUB_RUN_ATTEMPT": "1",
        })
        patch.start()
        self.addCleanup(patch.stop)
        self.report = {"results": [], "log_sha256": {}}
        for name, output in {"import": "import complete\n", **SUCCESS_LOGS,
                             CASE: self.summary(SECTIONS)}.items():
            self.log(name, output)
            self.report["results"].append({"name": name, "status": "passed", "returncode": 0,
                "diagnostic_error": False, "launch_error": None, "skip_messages": []})

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], text=True,
                                       stderr=subprocess.PIPE)

    def summary(self, sections):
        return "LCB_PRESSURE_OPTIMIZATION: 100 assertions; 0 failures; completed=" + json.dumps(sections) + "\n"

    def log(self, name, output):
        path = self.root / (name + ".log")
        path.write_bytes(output.encode())
        self.report["log_sha256"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()

    def test_profile_does_not_modify_historical_publisher(self):
        self.assertEqual(historical.BRANCH, "codex/lcb001-shared-contract")
        self.assertNotIn(CASE, historical.CASE_MARKERS)
        self.assertEqual(historical.BUNDLE_PREFIX, "lcb001-shared-contract-runtime")
        self.assertEqual(subject.BUNDLE_PREFIX, "lcb002-pressure-variants-runtime")

    def test_exact_source_context_and_request(self):
        self.assertEqual(subject.context(self.source)["source_commit"], self.source)
        subject.require_publication_request(self.source)

    def test_other_branch_event_workflow_and_source_refuse(self):
        for key, value in {
            "GITHUB_REF": "refs/heads/codex/lcb001-shared-contract",
            "GITHUB_EVENT_NAME": "pull_request", "GITHUB_SHA": "f" * 40,
            "GITHUB_WORKFLOW_REF": "techrote/cybersand/.github/workflows/lcb001-shared-contract-runtime-publication.yml@refs/heads/codex/lcb002-pressure-variants",
        }.items():
            with self.subTest(key=key), mock.patch.dict(os.environ, {key: value}):
                with self.assertRaises(RuntimeError): subject.context(self.source)

    def test_unarmed_request_refuses_before_remote_or_build(self):
        (self.root / subject.REQUEST).unlink()
        with mock.patch.object(subject, "git", wraps=subject.git) as git:
            with self.assertRaisesRegex(RuntimeError, "Missing explicit"):
                subject.check_source(argparse.Namespace(source_sha=self.source))
            self.assertFalse(any(call.args[0] == "ls-remote" for call in git.call_args_list))

    def test_request_cannot_borrow_previous_scope(self):
        path = self.root / subject.REQUEST
        path.write_text(json.dumps(dict(historical.REQUEST_VALUE, request_sequence=1)), encoding="utf-8")
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "Wrong scope fixture")
        with self.assertRaisesRegex(RuntimeError, "Invalid shared-contract publish request"):
            subject.require_publication_request(self.git("rev-parse", "HEAD").strip())

    def test_all_thirteen_cases_and_six_new_sections_pass(self):
        self.assertEqual(profile.OPTIMIZATION_SECTIONS, SECTIONS)
        self.assertEqual(len(subject.CASE_MARKERS), 13)
        subject.verify_case_results(self.root, self.report)

    def test_missing_new_case_or_log_refuses(self):
        self.report["results"].pop()
        with self.assertRaisesRegex(RuntimeError, "Incomplete focused case coverage"):
            subject.verify_case_results(self.root, self.report)

    def test_each_new_section_requires_actual_boolean_true(self):
        variants = [{key: value for key, value in SECTIONS.items() if key != omitted} for omitted in SECTIONS]
        variants += [dict(SECTIONS, **{key: value}) for key in SECTIONS for value in (False, 1, "true")]
        variants += [[], "done", dict(SECTIONS, extra=True)]
        for sections in variants:
            with self.subTest(sections=sections):
                self.log(CASE, self.summary(sections))
                with self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)

    def test_zero_failed_duplicate_and_skip_summaries_refuse(self):
        original = self.summary(SECTIONS)
        for output in (original.replace("100 assertions", "0 assertions"),
                       original.replace("0 failures", "1 failures"), original + original,
                       original + "SKIP missing native arm\n", original + "ERROR: native fault\n"):
            with self.subTest(output=output):
                self.log(CASE, output)
                with self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)

    def test_new_case_preserves_flags_and_has_finite_bound(self):
        discovered = {name: subject.runner.Case(name, ("--script", "res://tests/" + name + ".gd"), 180, 5.0)
                      for name in subject.CASE_MARKERS}
        cases = subject.focused_cases(discovered)
        self.assertEqual([case.name for case in cases], ["import", *subject.CASE_MARKERS])
        self.assertEqual(cases[-1].timeout, 360)
        self.assertEqual(cases[-1].flags, discovered[CASE].flags)

    def test_new_profile_files_are_required_build_inputs(self):
        for path in (subject.WORKFLOW, subject.REQUEST,
                     "tools/ci/lcb002_pressure_runtime_publication.py",
                     "tools/ci/test_lcb002_pressure_runtime_publication.py"):
            self.assertIn(path, subject.BUILD_EXACT)


if __name__ == "__main__":
    unittest.main()
