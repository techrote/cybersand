#!/usr/bin/env python3
"""Adversarial checks of the isolated H1 publication profile.

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
import re
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import lcb001_shared_contract_runtime_publication as historical
import mat354_h1_runtime_publication as profile

subject = profile.engine
BRANCH = "fix/mat354b-moltenglass-deadline-20261104"
WORKFLOW = ".github/workflows/mat354-h1-runtime-publication.yml"
# Independent fixture: removing a case from the profile cannot change this list.
def godot_proof():
    return {"schema": "mat354.h1.godot.v1", "assertions": 13056, "failures": 0,
            "scope": "actual native cooling and hot180 retirement; native standalone owns distributed-worker proof",
            "cohorts": [{"phase": phase, "x": x, "first_decrement_tick": first,
                         "conversion_tick": conversion, "completed_ticks": 768,
                         "configured_workers": [1, 4], "physical_hash": "1234567890abcdef",
                         "actual_distributed_workers_claimed": False}
                        for phase, x, first, conversion in
                        ((0, 11, 4, 720), (1, 8, 1, 717), (2, 10, 2, 718), (3, 26, 3, 719))]}


def h1_log(result=None):
    return "H1_GODOT_PROOF: " + json.dumps(godot_proof() if result is None else result) + "\n"


SUCCESS_LOGS = {
    "test_material_cooling_h1": h1_log(),
    "test_water_feel_integration":
        "WATER_FEEL_INTEGRATION: 24 policy cases + 70 scenario builds/reset/invalid/actions/RG8/authority passed default_hash=123456789\n",
    "test_liquid_solver_policy":
        'LIQUID_SOLVER_POLICY: 385 assertions; 0 failures; completed={"validation":true,"default_readback":true,"refusals":11,"parity_checkpoints":5,"cysd1_defaults":true,"whole_cell_admission_parity":true,"whole_cell_overlay_refusals":true}\n',
    "test_liquid_policy_worker":
        'LIQUID_POLICY_WORKER: 100 assertions; 0 failures; completed={"initial":true,"explicit":true,"isolation":true,"refusals":3,"normalized":true,"no_request":true}\n',
    "test_lcb_pressure_reference":
        'LCB_PRESSURE_REFERENCE: 100 assertions; 0 failures; completed={"native_dispatch":true,"no_fallback":true,"gas_identity":true,"gas_merge_split":true,"vent_reseal":true,"empty_only_gas":true,"quantity_ledger":true,"physical_state_hash":true,"save_roundtrip":true,"refusal_isolation":true,"default_goldens":true,"worker_parity":true}\n',
    "test_microscenario_native_observation":
        "MICROSCENARIO_NATIVE_OBSERVATION: 100 assertions; 0 failures\n",
}


class RepositoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git("init", "--quiet")
        self.git("config", "user.name", "H1 publication fixture")
        self.git("config", "user.email", "H1-fixture@example.invalid")
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
        for overrides in ({"schema": "H1290-publish-request-v1"},
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

    def test_missing_h1_or_retained_control_refuses_admission(self):
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
                         "tools/ci/mat354_h1_runtime_publication.py"}.issubset(subject.BUILD_EXACT))

    def test_all_source_byte_lease_staging_and_execution_guards_are_unchanged(self):
        for name in ("context", "require_publication_request", "check_source", "input_ledgers",
                     "runtime_identity", "execute", "stage", "check_index"):
            with self.subTest(name=name):
                self.assertEqual(inspect.getsource(getattr(subject, name)), inspect.getsource(getattr(historical, name)))
        self.assertEqual(inspect.getsource(profile._verify_bundle), inspect.getsource(historical.verify_bundle))
        self.assertEqual(inspect.getsource(profile._verify_case_results), inspect.getsource(historical.verify_case_results))
        self.assertEqual(inspect.getsource(profile._record_build), inspect.getsource(historical.record_build))

    def test_selected_case_watchdogs_flags_and_display_requirements_are_preserved(self):
        discovered = {case.name: case for case in subject.runner.discover_cases()}
        cases = subject.focused_cases(discovered)
        self.assertEqual([case.name for case in cases], ["import", *SUCCESS_LOGS])
        self.assertEqual(cases[0].timeout, subject.runner.execution_policy.watchdog_seconds("godot_import_seconds"))
        for case in cases[1:]:
            self.assertEqual(case, discovered[case.name])
            self.assertFalse(case.requires_display)
        # Hosted parent budgets leave full room for the unshortened case ceilings.
        self.assertLess(sum(case.timeout for case in cases), 340 * 60)
        del discovered["test_material_cooling_h1"]
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
        for text in (h1_log(godot_proof() | {"assertions": 0}),
                     h1_log(godot_proof() | {"failures": 1})):
            self.write_log("test_material_cooling_h1", text)
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


class H1EvidenceTests(unittest.TestCase):
    def test_exact_registered_godot_proof_passes(self):
        self.assertEqual(profile.verify_h1_godot(h1_log()), godot_proof())

    def test_wrong_godot_counts_scope_or_source_cohorts_are_refused(self):
        invalid = ["", h1_log() * 2,
                   h1_log().replace('"failures": 0', '"failures": 0, "failures": 0')]
        for field, value in (("assertions", 0), ("assertions", 13055), ("assertions", True),
                             ("failures", True), ("failures", 1), ("schema", "other"), ("scope", "all")):
            invalid.append(h1_log(godot_proof() | {field: value}))
        for change in ("missing", "duplicate", "reorder", "unknown"):
            value = godot_proof()
            if change == "missing": value["cohorts"].pop()
            if change == "duplicate": value["cohorts"][3] = value["cohorts"][2]
            if change == "reorder": value["cohorts"].reverse()
            if change == "unknown": value["extra"] = "permission"
            invalid.append(h1_log(value))
        for field, value in (("phase", True), ("first_decrement_tick", 1), ("conversion_tick", 719),
                             ("completed_ticks", 767), ("configured_workers", [1, True]),
                             ("physical_hash", ""), ("physical_hash", 123),
                             ("actual_distributed_workers_claimed", True)):
            result = godot_proof()
            result["cohorts"][0][field] = value
            invalid.append(h1_log(result))
        for text in invalid:
            with self.subTest(text=text), self.assertRaises(RuntimeError):
                profile.verify_h1_godot(text)

    def test_validated_artifact_keeps_its_original_attempt_identity(self):
        with tempfile.TemporaryDirectory() as directory, mock.patch.dict(os.environ, {"GITHUB_RUN_ID": "123456"}):
            root = Path(directory)
            (root / "validation.json").write_text(json.dumps({"scope": subject.EXECUTION_SCOPE}), encoding="utf-8")
            manifest = {"workflow_attempt": "1", "validation_output": "mat354-h1-runtime-attempt-1-windows-123456/validation.json"}
            with mock.patch.object(profile, "_verify_bundle", return_value=manifest), \
                    mock.patch.object(profile.compiled_inputs, "verify") as dependencies:
                self.assertEqual(profile.verify_bundle(root, "windows", "a" * 40, True), manifest)
                dependencies.assert_called_once_with(root, manifest, "a" * 40, subject.ROOT)
                manifest["validation_output"] = "mat354-h1-runtime-attempt-2-windows-123456/validation.json"
                with self.assertRaisesRegex(RuntimeError, "artifact identity"):
                    profile.verify_bundle(root, "windows", "a" * 40, True)

    def test_built_and_validated_bundles_require_compiler_input_receipt(self):
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(profile, "_verify_bundle", return_value={}):
            for validated in (False, True):
                with self.subTest(validated=validated), self.assertRaisesRegex(RuntimeError, "Missing compiled-input receipt"):
                    profile.verify_bundle(Path(directory), "linux", "a" * 40, validated)

    def test_record_command_rejects_missing_compiler_input_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            argv = ["mat354_h1_runtime_publication.py", "record", "--source-sha", "a" * 40,
                    "--platform", "linux", "--bundle", directory, "--runtime", "runtime.so", "--toolchain", "toolchain.txt"]
            with mock.patch.object(sys, "argv", argv), mock.patch.object(profile, "_record_build") as record, \
                    mock.patch.object(profile, "_verify_bundle", return_value={}):
                with self.assertRaisesRegex(RuntimeError, "Missing compiled-input receipt"):
                    profile.main()
                record.assert_called_once()


class HostedToolchainEvidenceTests(unittest.TestCase):
    def test_every_hosted_build_records_resolved_compiler_and_linker_payloads(self):
        workflow = (subject.ROOT / WORKFLOW).read_text(encoding="utf-8")
        expected = {
            "native-differential": (
                'record_executable compiler-driver "$(command -v g++-13)"',
                'record_executable compiler-cc1plus "$(g++-13 -print-prog-name=cc1plus)"',
                'record_executable linker "$(g++-13 -print-prog-name=ld)"',
                '} > build/mat354-h1-native/compiler.txt',
            ),
            "linux-build": (
                'record_executable compiler-driver "$LINUX_CXX"',
                'record_executable compiler-cc1plus "$("$LINUX_CXX" -print-prog-name=cc1plus)"',
                'record_executable linker "$("$LINUX_CXX" -print-prog-name=ld)"',
                '} > "$RUNNER_TEMP/toolchain.txt"',
                '--toolchain "$RUNNER_TEMP/toolchain.txt"',
            ),
            "windows-build": (
                'record_executable compiler-driver-wrapper "$WINDOWS_CXX"',
                'record_executable compiler-clang-payload "$LLVM_MINGW_ROOT/bin/clang"',
                'record_executable linker-lld-payload "$LLVM_MINGW_ROOT/bin/ld.lld"',
                '} > "$RUNNER_TEMP/toolchain.txt"',
                '--toolchain "$RUNNER_TEMP/toolchain.txt"',
            ),
        }
        for job, markers in expected.items():
            with self.subTest(job=job):
                blocks = re.findall(r"(?ms)^  " + job + r":\n(.*?)(?=^  [a-z][a-z0-9-]*:\n|\Z)", workflow)
                self.assertEqual(len(blocks), 1)
                body = blocks[0]
                self.assertIn('resolved="$(readlink -f "$selected")"', body)
                self.assertIn('bytes="$(stat -Lc \'%s\' "$resolved")"', body)
                self.assertIn('digest="$(sha256sum "$resolved")"', body)
                for marker in markers:
                    self.assertIn(marker, body)

    def test_both_runtime_builds_capture_and_bind_actual_full_dependencies(self):
        workflow = (subject.ROOT / WORKFLOW).read_text(encoding="utf-8")
        for platform in ("linux", "windows"):
            blocks = re.findall(r"(?ms)^  " + platform + r"-build:\n(.*?)(?=^  [a-z][a-z0-9-]*:\n|\Z)", workflow)
            self.assertEqual(len(blocks), 1)
            self.assertIn("mat354_h1_runtime_dependencies.py build", blocks[0])
            self.assertIn("runtime-compiled-inputs.json", blocks[0])
            self.assertIn("H1_COMPILED_INPUTS_SHA256=", blocks[0])
            self.assertIn("--bundle build/mat354-h1-" + platform, blocks[0])


class NativeEvidenceTests(unittest.TestCase):
    @staticmethod
    def rows():
        # This fixture is independent of the profile's NATIVE_CASES and phase table.
        cases = ("phase-0", "zero-phase-0", "phase-1", "zero-phase-1", "phase-2", "zero-phase-2",
                 "phase-3", "zero-phase-3", "boundary-31-8", "boundary-32-8", "boundary-63-8",
                 "boundary-64-8", "boundary-127-8", "boundary-128-8", "boundary--1-8", "boundary--129--1",
                 "molten_pair", "molten_pool_small", "molten_pool_large", "molten_hot", "hot-above180-reset",
                 "eight-visible-heat-neighbours", "spark-is-not-thermal-heat", "last-heat-after-first-pair",
                 "shared-molten-ice-pair-mercury", "source-masked-exactly-at-due", "same-source-save-continuation",
                 "source-moves-across-activity-seam", "source-replaced-with-glass", "heat-partner-converts-natively-to-glass")
        rows = [{"type": "h1_regression_metadata", "kernel_entry_proxy_scope":
                 "stationary downward rejections plus Glass conversions; successful motion uses separate actual move counters"}]
        for phase, first, conversion in ((0, 4, 720), (1, 1, 717), (2, 2, 718), (3, 3, 719)):
            for replica in ("q3-w1", "q3-w4", "q1024-w1", "q1024-w4"):
                for tick in range(1, 769):
                    rows.append({"type": "h1_tick", "case": "phase-" + str(phase), "replica": replica,
                                 "tick": tick, "state_a": max(0, 180 - max(0, (tick - first) // 4 + 1)),
                                 "material": 35 if tick >= conversion else 36,
                                 "kernel_entries_world": int(tick <= conversion and tick % 4 == phase),
                                 "scheduled_jobs": 0, "block_after": {"due": 0},
                                 "physical_hash": "0123456789abcdef", "tuple_hash": "fedcba9876543210"})
        def append_trace(case, replica, ticks):
            rows.extend({"type": "h1_tick", "case": case, "replica": replica, "tick": tick,
                         "physical_hash": "0123456789abcdef", "tuple_hash": "fedcba9876543210"}
                        for tick in ticks)
        for case in ("zero-phase-0", "zero-phase-1", "zero-phase-2", "zero-phase-3",
                     "boundary-31-8", "boundary-32-8", "boundary-63-8", "boundary-64-8",
                     "boundary-127-8", "boundary-128-8", "boundary--1-8", "boundary--129--1"):
            for replica in ("q3-w1", "q3-w4", "q1024-w1", "q1024-w4"):
                append_trace(case, replica, range(1, 49))
        for case in ("molten_pair", "molten_pool_small", "molten_pool_large", "molten_hot"):
            for replica in ("w1", "w4"):
                append_trace(case, replica, range(1, 129))
        for replica in ("w1", "w4"):
            append_trace("hot-above180-reset", replica, range(1, 33))
        append_trace("eight-visible-heat-neighbours", "w1", list(range(1, 33)) * 8)
        for replica in ("visible", "masked"):
            append_trace("spark-is-not-thermal-heat", replica, [1])
        append_trace("last-heat-after-first-pair", "w1", [1])
        for replica in ("w1", "w4", "awake"):
            append_trace("shared-molten-ice-pair-mercury", replica, range(1, 769))
        append_trace("source-masked-exactly-at-due", "w1", range(1, 65))
        append_trace("same-source-save-continuation", "original", range(1, 51))
        for replica in ("restored-w1", "restored-w4"):
            append_trace("same-source-save-continuation", replica, range(3, 51))
        for replica in ("w1", "w4"):
            append_trace("source-moves-across-activity-seam", replica, range(1, 49))
        append_trace("source-replaced-with-glass", "w1", range(1, 33))
        append_trace("heat-partner-converts-natively-to-glass", "w1", range(1, 49))
        rows.extend({"type": "h1_move_deadlines", "tick": tick, "old_block": {"due": 0},
                     "new_block": {"due": 0}} for tick in range(1, 49))
        rows.extend({"type": "h1_case", "case": name, "status": "PASS"} for name in cases)
        rows.append({"type": "h1_regression_summary", "status": "PASS"})
        return rows

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.log, self.output = Path(self.temp.name) / "native.log", Path(self.temp.name) / "receipt.json"
        self.patch = mock.patch.object(subject, "context", return_value={"source_commit": "a" * 40})
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def verify(self, rows):
        self.log.write_text("".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8")
        return profile.verify_native(self.log, self.output, "a" * 40)

    def test_native_proof_requires_actual_complete_phase_execution(self):
        receipt = self.verify(self.rows())
        self.assertEqual(receipt["phase_trace_rows"], 4 * 4 * 768)
        self.assertEqual(receipt["trace_rows"], 18629)
        self.assertEqual(len(receipt["trace_cohorts"]), 89)
        self.assertEqual(len(receipt["cases"]), 30)
        self.assertEqual(receipt["log_sha256"], hashlib.sha256(self.log.read_bytes()).hexdigest())

    def test_missing_duplicate_case_or_phase_trace_is_refused(self):
        good = self.rows()
        for rows in ([], good[:-1], good[:-2] + good[-1:], good + good[-1:], good[1:], good[:1] + good):
            with self.subTest(length=len(rows)), self.assertRaises(RuntimeError):
                self.verify(rows)

    def test_false_cooling_kernel_or_idle_evidence_is_refused(self):
        mutations = ((4, "kernel_entries_world", 0), (4, "kernel_entries_world", True),
                     (4, "state_a", 180), (720, "material", 36), (745, "scheduled_jobs", 1),
                     (745, "block_after", {"due": 748}), (769, "physical_hash", "ffffffffffffffff"))
        for index, key, value in mutations:
            rows = self.rows()
            rows[index][key] = value
            with self.subTest(index=index, key=key), self.assertRaises(RuntimeError):
                self.verify(rows)

    def test_native_diagnostic_or_duplicate_json_fields_are_refused(self):
        good = "".join(json.dumps(row) + "\n" for row in self.rows())
        for text in (good + "AddressSanitizer error\n", good + "SKIP absent input\n",
                     good.replace('"status": "PASS"', '"status": "PASS", "status": "PASS"', 1)):
            self.log.write_text(text, encoding="utf-8")
            with self.assertRaises(RuntimeError):
                profile.verify_native(self.log, self.output, "a" * 40)

    def test_phase_only_rows_with_thirty_pass_labels_are_refused(self):
        rows = [row for row in self.rows() if row["type"] != "h1_tick" or row["case"].startswith("phase-")]
        with self.assertRaisesRegex(RuntimeError, "Incomplete.*trace"):
            self.verify(rows)

    def test_every_nonphase_case_requires_its_complete_trace(self):
        good = self.rows()
        cases = [row["case"] for row in good if row["type"] == "h1_case" and not row["case"].startswith("phase-")]
        self.assertEqual(len(cases), 26)
        for case in cases:
            indices = [i for i, row in enumerate(good) if row["type"] == "h1_tick" and row["case"] == case]
            for label, removed in (("all", set(indices)), ("truncated", {indices[-1]})):
                rows = [row for index, row in enumerate(good) if index not in removed]
                with self.subTest(case=case, mutation=label), self.assertRaisesRegex(RuntimeError, "Incomplete.*trace"):
                    self.verify(rows)

    def test_unknown_duplicate_reordered_or_malformed_nonphase_cohort_is_refused(self):
        for mutation in ("replica", "duplicate", "reorder", "boolean-tick"):
            rows = self.rows()
            indices = [i for i, row in enumerate(rows) if row["type"] == "h1_tick"
                       and row["case"] == "molten_hot" and row["replica"] == "w1"]
            if mutation == "replica": rows[indices[0]]["replica"] = "unregistered"
            if mutation == "duplicate": rows[indices[1]] = dict(rows[indices[0]])
            if mutation == "reorder": rows[indices[0]], rows[indices[1]] = rows[indices[1]], rows[indices[0]]
            if mutation == "boolean-tick": rows[indices[0]]["tick"] = True
            with self.subTest(mutation=mutation), self.assertRaises(RuntimeError):
                self.verify(rows)

    def test_nonphase_physical_and_tuple_hashes_require_actual_wire_shape(self):
        for field in ("physical_hash", "tuple_hash"):
            for value in (None, True, 123, "", "abc123", "0" * 15, "0" * 17,
                          "g" * 16, "0123456789ABCDEF", "0123456789abcdef\n"):
                rows = self.rows()
                row = next(row for row in rows if row["type"] == "h1_tick" and row["case"] == "source-replaced-with-glass")
                if value is None:
                    del row[field]
                else:
                    row[field] = value
                with self.subTest(field=field, value=value), self.assertRaisesRegex(RuntimeError, "Malformed native H1.*hash"):
                    self.verify(rows)


if __name__ == "__main__":
    unittest.main()
