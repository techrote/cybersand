#!/usr/bin/env python3
"""LCB-005 union-profile guards; the accepted engine retains its full suite."""
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
import lcb005_inertial_runtime_publication as profile
from test_lcb001_shared_contract_runtime_publication import SUCCESS_LOGS

subject = profile.engine
BRANCH = "codex/lcb005-inertial"
WORKFLOW = ".github/workflows/lcb005-inertial-runtime-publication.yml"
ADDED = {
    "test_lcb_pressure_optimization": (
        "LCB_PRESSURE_OPTIMIZATION",
        {"native_variants": True, "readback_encoding": True, "exact_parity": True,
         "gas_invalidation": True, "cold_restore": True, "default_preservation": True}),
    "test_lcb_inertial_adapter": (
        "LCB_INERTIAL_ADAPTER",
        {"oracle_parameters": True, "instance_readback": True, "radius_transaction": True,
         "mixed_workers": True, "cyps_continuation": True, "default_preservation": True}),
}


def summary(name, sections):
    return ADDED[name][0] + ": 100 assertions; 0 failures; completed=" + json.dumps(sections) + "\n"


class ProfileTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.git("init", "--quiet")
        self.git("config", "user.name", "LCB union publisher fixture")
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
        patch.start(); self.addCleanup(patch.stop)
        patch = mock.patch.dict(os.environ, {
            "GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_NAME": "push",
            "GITHUB_REF": "refs/heads/" + BRANCH,
            "GITHUB_WORKFLOW_REF": "techrote/cybersand/" + WORKFLOW + "@refs/heads/" + BRANCH,
            "GITHUB_SHA": self.source, "GITHUB_RUN_ID": "123456", "GITHUB_RUN_ATTEMPT": "1",
        })
        patch.start(); self.addCleanup(patch.stop)
        self.report = {"results": [], "log_sha256": {}}
        logs = {"import": "import complete\n", **SUCCESS_LOGS,
                **{name: summary(name, sections) for name, (_, sections) in ADDED.items()}}
        for name, output in logs.items():
            self.log(name, output)
            self.report["results"].append({"name": name, "status": "passed", "returncode": 0,
                "diagnostic_error": False, "launch_error": None, "skip_messages": []})

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], text=True,
                                       stderr=subprocess.PIPE)

    def log(self, name, output):
        path = self.root / (name + ".log")
        path.write_bytes(output.encode())
        self.report["log_sha256"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()

    def test_profile_is_isolated_and_binds_its_own_artifact_prefix(self):
        self.assertEqual(historical.BRANCH, "codex/lcb001-shared-contract")
        self.assertEqual(historical.BUNDLE_PREFIX, "lcb001-shared-contract-runtime")
        self.assertEqual(set(historical.CASE_MARKERS), set(SUCCESS_LOGS))
        self.assertEqual(subject.BUNDLE_PREFIX, "lcb005-inertial-runtime")
        self.assertEqual(subject.WORKFLOW, WORKFLOW)
        self.assertEqual(subject.BRANCH, BRANCH)

    def test_exact_source_context_and_request(self):
        self.assertEqual(subject.context(self.source)["source_commit"], self.source)
        subject.require_publication_request(self.source)

    def test_other_repository_branch_event_workflow_source_or_attempt_refuse(self):
        for key, value in {
            "GITHUB_REPOSITORY": "other/cybersand", "GITHUB_REF": "refs/heads/codex/lcb002-pressure-variants",
            "GITHUB_EVENT_NAME": "pull_request", "GITHUB_SHA": "f" * 40, "GITHUB_RUN_ATTEMPT": "0",
            "GITHUB_WORKFLOW_REF": "techrote/cybersand/.github/workflows/lcb001-shared-contract-runtime-publication.yml@refs/heads/" + BRANCH,
        }.items():
            with self.subTest(key=key), mock.patch.dict(os.environ, {key: value}):
                with self.assertRaises(RuntimeError): subject.context(self.source)

    def test_unarmed_request_refuses_before_remote_or_build(self):
        (self.root / subject.REQUEST).unlink()
        with mock.patch.object(subject, "git", wraps=subject.git) as git:
            with self.assertRaisesRegex(RuntimeError, "Missing explicit"):
                subject.check_source(argparse.Namespace(source_sha=self.source))
            self.assertFalse(any(call.args[0] == "ls-remote" for call in git.call_args_list))

    def test_request_cannot_borrow_historical_or_partial_scope(self):
        for request in (dict(historical.REQUEST_VALUE, request_sequence=1),
                        dict(subject.REQUEST_VALUE, scope="inertial-only", request_sequence=1),
                        dict(subject.REQUEST_VALUE, request_sequence=True),
                        dict(subject.REQUEST_VALUE, request_sequence=0),
                        dict(subject.REQUEST_VALUE, request_sequence=1, extra=True)):
            path = self.root / subject.REQUEST; path.write_text(json.dumps(request), encoding="utf-8")
            self.git("add", "."); self.git("commit", "--quiet", "--allow-empty", "-m", "Wrong request")
            with self.assertRaisesRegex(RuntimeError, "Invalid shared-contract publish request"):
                subject.require_publication_request(self.git("rev-parse", "HEAD").strip())

    def test_in_only_and_pressure_only_sources_cannot_arm(self):
        for name in ADDED:
            path = self.root / "godot/tests" / (name + ".gd")
            path.unlink()
            with self.assertRaisesRegex(RuntimeError, "regression is not implemented"):
                subject.require_publication_request(self.source)
            path.write_text("fixture\n", encoding="utf-8")

    def test_all_fourteen_cases_and_twelve_new_sections_pass(self):
        self.assertEqual(profile.OPTIMIZATION_SECTIONS, ADDED["test_lcb_pressure_optimization"][1])
        self.assertEqual(profile.INERTIAL_SECTIONS, ADDED["test_lcb_inertial_adapter"][1])
        self.assertEqual(list(subject.CASE_MARKERS), [*SUCCESS_LOGS, *ADDED])
        subject.verify_case_results(self.root, self.report)

    def test_each_missing_case_log_or_changed_digest_refuses(self):
        for name in ADDED:
            original = self.report["results"]
            self.report["results"] = [row for row in original if row["name"] != name]
            with self.assertRaisesRegex(RuntimeError, "Incomplete focused case coverage"):
                subject.verify_case_results(self.root, self.report)
            self.report["results"] = original
            (self.root / (name + ".log")).write_text("changed\n", encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "Execution log digest mismatch"):
                subject.verify_case_results(self.root, self.report)
            self.log(name, summary(name, ADDED[name][1]))

    def test_each_section_requires_actual_boolean_true_and_exact_keys(self):
        for name, (_, expected) in ADDED.items():
            variants = [{key: value for key, value in expected.items() if key != omitted} for omitted in expected]
            variants += [dict(expected, **{key: value}) for key in expected for value in (False, 1, "true")]
            variants += [[], "done", dict(expected, extra=True)]
            for sections in variants:
                with self.subTest(name=name, sections=sections):
                    self.log(name, summary(name, sections))
                    with self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)
            self.log(name, summary(name, expected))

    def test_zero_failed_duplicate_malformed_skip_and_error_summaries_refuse(self):
        for name, (_, sections) in ADDED.items():
            original = summary(name, sections)
            for output in (original.replace("100 assertions", "0 assertions"),
                           original.replace("0 failures", "1 failures"), original + original,
                           original.replace(json.dumps(sections), "{broken}"),
                           original + "SKIP missing native arm\n", original + "ERROR: native fault\n"):
                with self.subTest(name=name, output=output):
                    self.log(name, output)
                    with self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)
            self.log(name, original)

    def test_new_cases_preserve_flags_and_every_existing_deadline(self):
        discovered = {name: subject.runner.Case(name, ("--script", "res://tests/" + name + ".gd"), 180, 5.0)
                      for name in subject.CASE_MARKERS}
        cases = subject.focused_cases(discovered)
        self.assertEqual([case.name for case in cases], ["import", *subject.CASE_MARKERS])
        for case in cases[1:]:
            self.assertEqual(case.flags, discovered[case.name].flags)
            self.assertEqual(case.timeout, 360 if case.name in ADDED else historical.CASE_TIMEOUTS.get(case.name, 180))
        self.assertEqual(cases[0].timeout, 240)
        del discovered["test_lcb_pressure_optimization"]
        with self.assertRaisesRegex(RuntimeError, "Required focused regression is missing"):
            subject.focused_cases(discovered)

    def test_required_profile_and_oracle_inputs_are_bound(self):
        for path in (WORKFLOW, subject.REQUEST, "tools/ci/lcb005_inertial_runtime_publication.py",
                     "tools/ci/test_lcb005_inertial_runtime_publication.py",
                     "godot/tests/fixtures/lcb/inertial-adapter-parameters.json"):
            self.assertIn(path, subject.BUILD_EXACT)


class WorkflowTests(unittest.TestCase):
    def test_workflow_has_an_unarmed_path_and_only_branch_bound_execution(self):
        text = (historical.ROOT / WORKFLOW).read_text(encoding="utf-8")
        self.assertIn("branches: [" + BRANCH + "]", text)
        self.assertIn("echo 'armed=false'", text)
        self.assertNotIn("workflow_dispatch:", text)
        self.assertIn("needs.admission.outputs.armed == 'true'", text)
        self.assertIn("runs-on: windows-2022", text)
        self.assertIn("runs-on: ubuntu-24.04", text)
        self.assertIn("timeout-minutes: 55", text)
        self.assertIn("timeout-minutes: 25", text)

    def test_workflow_preserves_exact_parent_four_paths_and_atomic_branch_lease(self):
        text = (historical.ROOT / WORKFLOW).read_text(encoding="utf-8")
        self.assertEqual(text.count("contents: write"), 1)
        self.assertIn('test "$(git rev-list --parents -n 1 HEAD)" = "$(git rev-parse HEAD) $GITHUB_SHA"', text)
        self.assertIn('git push --force-with-lease="refs/heads/' + BRANCH + ':$GITHUB_SHA" origin HEAD:refs/heads/' + BRANCH, text)
        self.assertIn('check-index --source-sha "$GITHUB_SHA"', text)
        allowed = [*subject.RUNTIMES.values(), *subject.MANIFESTS.values()]
        self.assertIn("git add -- " + " ".join(allowed), text)
        self.assertIn("test_lcb001_shared_contract_runtime_publication.py", text)


if __name__ == "__main__":
    unittest.main()
