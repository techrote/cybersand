#!/usr/bin/env python3
"""Adversarial checks of the reused #471 source-matched runtime publication profile.

The unchanged shared-engine suite separately covers Git/LFS staging, PE/ELF,
source-ledger completeness and original log integrity. These tests prove this
profile retains those implementations and supplies its own fail-closed scope.
"""
import argparse
import copy
from dataclasses import replace
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
import wbh406_runtime_publication as profile

subject = profile.engine
BRANCH = "integrate/hs-pkt-neighbour-20261107"
WORKFLOW = ".github/workflows/wbh406-runtime-publication.yml"
# Independent fixture: removing a case from the profile cannot change this list.
SUCCESS_LOGS = {
    "test_lcb_pressure_optimization":
        'LCB_PRESSURE_OPTIMIZATION: 4152 assertions; 0 failures; completed={"native_variants":true,"readback_encoding":true,"exact_parity":true,"gas_invalidation":true,"cold_restore":true,"default_preservation":true}\n',
    "test_lcb_pressure_reference":
        'LCB_PRESSURE_REFERENCE: 1934 assertions; 0 failures; completed={"native_dispatch":true,"no_fallback":true,"gas_identity":true,"gas_merge_split":true,"vent_reseal":true,"empty_only_gas":true,"quantity_ledger":true,"physical_state_hash":true,"save_roundtrip":true,"refusal_isolation":true,"default_goldens":true,"worker_parity":true}\n',
    "test_liquid_pressure_rapier": "LIQUID_PRESSURE_RAPIER: 120 assertions; 0 failures\n",
    "test_simulation_worker_interest_ownership": "SIMULATION_WORKER_INTEREST_OWNERSHIP: 57 assertions; 0 failures\n",
    "test_workbench_canvas": "WORKBENCH_CANVAS 131 checks, 0 failures\n",
}


class RepositoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git("init", "--quiet")
        self.git("config", "user.name", "#406 publication fixture")
        self.git("config", "user.email", "wbh406-fixture@example.invalid")
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
        for overrides in ({"schema": "lcb002-pressure-publish-request-v1"},
                          {"variant": "cached"}, {"scope": "lcb002-bounded-pressure-optimization-execution3"},
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

    def test_missing_pressure_or_water_case_refuses_admission(self):
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
                         "tools/ci/wbh406_runtime_publication.py",
                         "godot/tests/test_simulation_worker_interest_ownership.gd",
                         "godot/tests/test_workbench_canvas.gd"}.issubset(subject.BUILD_EXACT))
        # The historical #201 P1 profile, request and workflow stay untouched beside this one.
        self.assertTrue(Path(__file__).with_name("lcb201_p1_runtime_publication.py").is_file())
        self.assertNotEqual(subject.REQUEST, "tools/ci/lcb201_p1_publish_request.json")
        self.assertNotIn(".github/workflows/lcb201-p1-runtime-publication.yml", subject.BUILD_EXACT)

    def test_all_source_byte_lease_staging_and_execution_guards_are_unchanged(self):
        for name in ("context", "require_publication_request", "check_source", "input_ledgers",
                     "runtime_identity", "record_build", "execute", "stage", "check_index"):
            with self.subTest(name=name):
                self.assertEqual(inspect.getsource(getattr(subject, name)), inspect.getsource(getattr(historical, name)))
        self.assertEqual(inspect.getsource(profile._verify_bundle), inspect.getsource(historical.verify_bundle))
        self.assertEqual(inspect.getsource(profile._verify_shared), inspect.getsource(historical.verify_case_results))
        self.assertIs(subject.verify_case_results, profile.verify_case_results)

    def test_selected_case_watchdogs_flags_and_display_requirements_are_preserved(self):
        discovered = {case.name: case for case in subject.runner.discover_cases()}
        cases = subject.focused_cases(discovered)
        self.assertEqual([case.name for case in cases], ["import", *SUCCESS_LOGS])
        self.assertEqual(cases[0].timeout, subject.runner.execution_policy.watchdog_seconds("godot_import_seconds"))
        for case in cases[1:]:
            original = discovered[case.name]
            if case.name == "test_workbench_canvas":
                # The single explicit bound may only tighten the current-policy watchdog.
                self.assertEqual(case.timeout, 600)
                self.assertLess(case.timeout, original.timeout)
                case = replace(case, timeout=original.timeout)
            self.assertEqual(case, original)
            self.assertFalse(case.requires_display)
        self.assertEqual(subject.CASE_TIMEOUTS, {"test_workbench_canvas": 600})
        # Linux: 360 min less <=65 min of build/download; Windows: 300 min less setup.
        self.assertLess(sum(case.timeout for case in cases), 270 * 60)
        del discovered["test_liquid_pressure_rapier"]
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
        for text in ("LIQUID_PRESSURE_RAPIER: 0 assertions; 0 failures\n",
                     "LIQUID_PRESSURE_RAPIER: 120 assertions; 1 failures\n"):
            self.write_log("test_liquid_pressure_rapier", text)
            with self.assertRaises(RuntimeError):
                subject.verify_case_results(self.root, self.report)

    def test_changed_raw_log_and_passing_record_with_failure_are_refused(self):
        path = self.root / "test_liquid_pressure_rapier.log"
        path.write_bytes(path.read_bytes() + b"extra bytes\n")
        with self.assertRaisesRegex(RuntimeError, "digest mismatch"):
            subject.verify_case_results(self.root, self.report)
        self.write_log("test_liquid_pressure_rapier", SUCCESS_LOGS["test_liquid_pressure_rapier"])
        for field, value in (("status", "failed"), ("returncode", 1), ("diagnostic_error", True),
                             ("skip_messages", ["skipped"]), ("launch_error", "failed")):
            changed = copy.deepcopy(self.report)
            changed["results"][1][field] = value
            with self.subTest(field=field), self.assertRaises(RuntimeError):
                subject.verify_case_results(self.root, changed)

    def test_pressure_reference_noop_or_missing_sections_are_refused(self):
        prefix, raw = SUCCESS_LOGS["test_lcb_pressure_reference"].split("completed=", 1)
        sections = json.loads(raw)
        for values in ({key: val for key, val in sections.items() if key != "worker_parity"},
                       sections | {"worker_parity": False}, sections | {"vent_reseal": 1}):
            self.write_log("test_lcb_pressure_reference", prefix + "completed=" + json.dumps(values) + "\n")
            with self.assertRaises(RuntimeError):
                subject.verify_case_results(self.root, self.report)


    def test_skipped_builtin_canvas_check_is_refused(self):
        self.write_log("test_workbench_canvas", "WORKBENCH_CANVAS: user bench-canvas exists; built-in load skipped\n"
                       + SUCCESS_LOGS["test_workbench_canvas"])
        with self.assertRaisesRegex(RuntimeError, "skip"):
            subject.verify_case_results(self.root, self.report)
        for text in ("WORKBENCH_CANVAS 0 checks, 0 failures\n", "WORKBENCH_CANVAS 131 checks, 2 failures\n"):
            self.write_log("test_workbench_canvas", text)
            with self.subTest(text=text), self.assertRaises(RuntimeError):
                subject.verify_case_results(self.root, self.report)


class OptimizationSectionTests(EvidenceTests):
    def test_partial_or_noop_optimization_sections_are_refused(self):
        prefix, raw = SUCCESS_LOGS["test_lcb_pressure_optimization"].split("completed=", 1)
        sections = json.loads(raw)
        for values in ({key: val for key, val in sections.items() if key != "exact_parity"},
                       sections | {"exact_parity": False}, sections | {"cold_restore": 1},
                       sections | {"extra": True}):
            self.write_log("test_lcb_pressure_optimization", prefix + "completed=" + json.dumps(values) + "\n")
            with self.subTest(values=values), self.assertRaises(RuntimeError):
                subject.verify_case_results(self.root, self.report)


class NativeEvidenceTests(unittest.TestCase):
    def test_native_groups_require_complete_failure_free_named_work(self):
        good = {
            "LCB-002": "[pass] LCB-002 cached incremental heads and continuation\n"
                       + "".join("[pass] " + name + "\n" for name in profile.NATIVE_REQUIRED["LCB-002"])
                       + "2 tests passed\n",
            "LCB-001 pressure": "[pass] LCB-001 pressure admission and refusal\n1 tests passed\n",
            "Workbench parallel": "[pass] " + profile.NATIVE_REQUIRED["Workbench parallel"][0] + "\n1 tests passed\n",
            "Pair reaction": "[pass] " + profile.NATIVE_REQUIRED["Pair reaction"][0] + "\n1 tests passed\n",
        }
        self.assertEqual(set(good), set(profile.NATIVE_FILTERS))
        with tempfile.TemporaryDirectory() as directory, \
                mock.patch.object(subject, "context", return_value={"source_commit": "a" * 40}):
            log, output = Path(directory) / "native.log", Path(directory) / "receipt.json"
            for name_filter, text in good.items():
                log.write_text(text, encoding="utf-8")
                self.assertEqual(profile.verify_native(log, output, "a" * 40, name_filter)["filter"], name_filter)
            base = good["LCB-002"]
            invalid = [("LCB-002", ""), ("LCB-002", "0 tests passed\n"),
                       ("LCB-002", base.replace("2 tests passed", "3 tests passed")),
                       ("LCB-002", base + "[fail] LCB-002 other: broken\n"),
                       ("LCB-002", base + "test skipped\n"),
                       ("LCB-002", base.replace(profile.NATIVE_REQUIRED["LCB-002"][0], "LCB-002 something else")),
                       ("LCB-002", "[pass] LCB-002 a\n[pass] LCB-002 a\n2 tests passed\n"),
                       ("LCB-001 pressure", "[pass] LCB-002 foreign\n1 tests passed\n"),
                       ("Workbench parallel", "[pass] Workbench parallel other\n1 tests passed\n"),
                       ("Pair reaction", "[pass] Pair reaction other\n1 tests passed\n"),
                       ("Pair reaction", good["Pair reaction"] + "runtime error: shift exponent\n"),
                       ("all", base)]
            for name_filter, text in invalid:
                log.write_text(text, encoding="utf-8")
                with self.subTest(name_filter=name_filter, text=text), self.assertRaises(RuntimeError):
                    profile.verify_native(log, output, "a" * 40, name_filter)

    def test_validated_artifact_keeps_its_original_attempt_identity(self):
        with tempfile.TemporaryDirectory() as directory, mock.patch.dict(os.environ, {"GITHUB_RUN_ID": "123456"}):
            root = Path(directory)
            (root / "validation.json").write_text(json.dumps({"scope": subject.EXECUTION_SCOPE}), encoding="utf-8")
            manifest = {"workflow_attempt": "1", "validation_output": "wbh406-runtime-attempt-1-windows-123456/validation.json"}
            with mock.patch.object(profile, "_verify_bundle", return_value=manifest):
                self.assertEqual(profile.verify_bundle(root, "windows", "a" * 40, True), manifest)
                manifest["validation_output"] = "wbh406-runtime-attempt-2-windows-123456/validation.json"
                with self.assertRaisesRegex(RuntimeError, "artifact identity"):
                    profile.verify_bundle(root, "windows", "a" * 40, True)


if __name__ == "__main__":
    unittest.main()
