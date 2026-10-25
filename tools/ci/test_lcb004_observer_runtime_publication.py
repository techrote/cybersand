#!/usr/bin/env python3
"""Pure adversarial guards for the isolated, explicitly armed observer publisher."""
import argparse
import copy
from importlib.util import module_from_spec, spec_from_file_location
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import lcb001_shared_contract_runtime_publication as shared
import lcb005_inertial_runtime_publication as brine
import lcb005_water_inertial_runtime_publication as water
import lcb003_application_host_runtime_publication as original
import lcb004_observer_runtime_publication as profile
from test_lcb003_application_host_runtime_publication import successful_logs as host_logs

subject = profile.engine
REPOSITORY = Path(__file__).resolve().parents[2]
BRANCH = "codex/lcb004-observer"
WORKFLOW = ".github/workflows/lcb004-observer-runtime-publication.yml"
LEDGER_CASE = "test_lcb_inertial_observation"
WORKER_CASE = "test_native_worker_observation"
# Independent retained fixture identities: no producer constants define coverage.
LEDGER_FIELDS = (
    "gravity_y", "impulse_x", "impulse_y", "loss", "support", "remainder",
    "updates", "unit_moves", "density_swaps", "contacts", "rests", "velocity_retired",
    "retired_x", "retired_y", "external_x", "external_y", "maximum_read_reach",
    "maximum_write_reach", "external_speed",
)
UNSIGNED = {"updates", "unit_moves", "density_swaps", "contacts", "rests",
            "velocity_retired", "maximum_read_reach", "maximum_write_reach"}


def ledger():
    return {"schema": "lcb-inertial-ledger-observation-v1", "ok": True, "available": True,
            "completed_tick": "12", "session_generation": "3",
            "policy_hash": "a297f572bf00dd6736397b3cad9b12738b2377a1802f1c9ef70ab6ddd3b10cd8",
            "extension_identity": "1311496abb91801b710afa02bc30ed415534f188271af0a734ff898edd177239",
            "values": dict(zip(LEDGER_FIELDS, map(str, (1136, 4, -427, 391, 88, 1709,
                           284, 291, 0, 0, 0, 27, 0, 27, 0, 0, 3, 2, 0))))}


def participation(observed=1):
    # Configured4 may legitimately observe only one actual participant.
    rows = []
    for tick in range(9):
        for configured in (1, 4):
            row = {"fixture": "moving", "tick": tick, "configured": configured,
                   "observed": 0 if tick == 0 else (1 if configured == 1 else observed),
                   "available": True, "scheduled_cores": 0 if tick == 0 else 16}
            if tick:
                row["maximum_phase_jobs"] = 4
            rows.append(row)
    return rows + [{"fixture": "idle", "tick": 1, "configured": 4,
                    "observed": 0, "available": True, "scheduled_cores": 0},
                   {"fixture": "serial-unmeasured", "tick": 1, "configured": 1,
                    "observed": 0, "available": False, "visited_cells": 64, "moved_cells": 64}]


def ledger_log(value=None):
    return "INERTIAL_OBSERVATION_LEDGER: " + json.dumps(ledger() if value is None else value) + "\nINERTIAL_OBSERVATION: 504 assertions; 0 failures\n"


def worker_log(value=None):
    return "NATIVE_WORKER_PARTICIPATION: " + json.dumps(participation() if value is None else value) + "\nNATIVE_WORKER_OBSERVATION: 265 assertions; 0 failures\n"


def successful_logs():
    return host_logs() | {LEDGER_CASE: ledger_log(), WORKER_CASE: worker_log()}


class ObserverFixture(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.git("init", "--quiet")
        self.git("config", "user.name", "Observer guard fixture")
        self.git("config", "user.email", "observer-fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        for relative in (subject.REQUEST, subject.EVIDENCE, *(
                "godot/tests/" + name + ".gd" for name in successful_logs() if name != "import")):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(dict(subject.REQUEST_VALUE, request_sequence=1))
                            if relative == subject.REQUEST else "fixture\n", encoding="utf-8", newline="\n")
        oracle = self.root / profile.INERTIAL_FIXTURE
        oracle.parent.mkdir(parents=True, exist_ok=True)
        oracle.write_bytes((REPOSITORY / profile.INERTIAL_FIXTURE).read_bytes())
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
        for name, output in successful_logs().items():
            self.log(name, output)
            self.report["results"].append({"name": name, "status": "passed", "returncode": 0,
                "diagnostic_error": False, "launch_error": None, "skip_messages": [],
                "capture_error": None, "timeout_kind": None, "timeout_diagnostics": None,
                "timeout_diagnostic_error": None})

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], text=True, stderr=subprocess.PIPE)

    def log(self, name, output):
        path = self.root / (name + ".log")
        path.write_bytes(output.encode())
        self.report["log_sha256"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()


class AdmissionTests(ObserverFixture):
    def test_exact_new_identity_and_full38_order(self):
        self.assertEqual(subject.BRANCH, BRANCH)
        self.assertEqual(subject.WORKFLOW, WORKFLOW)
        self.assertEqual(list(subject.CASE_MARKERS), list(successful_logs())[1:])
        self.assertEqual(len(subject.CASE_MARKERS), 37)
        self.assertEqual(subject.CASE_TIMEOUTS, original.engine.CASE_TIMEOUTS | {LEDGER_CASE: 180, WORKER_CASE: 180})
        discovered = {case.name: case for case in subject.runner.discover_cases(REPOSITORY)}
        cases = subject.focused_cases(discovered)
        self.assertEqual([case.name for case in cases], list(successful_logs()))
        self.assertEqual(cases[0].timeout, 240)
        self.assertEqual([case.timeout for case in cases[-2:]], [180, 180])
        subject.require_publication_request(self.source)
        subject.context(self.source)
        subject.verify_case_results(self.root, self.report)

    def test_missing_new_request_with_all_inherited_requests_cannot_arm(self):
        (self.root / subject.REQUEST).unlink()
        for old in (shared, brine.engine, water.engine, original.engine):
            path = self.root / old.REQUEST
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(dict(old.REQUEST_VALUE, request_sequence=1)), encoding="utf-8")
        with self.assertRaisesRegex(RuntimeError, "Missing explicit"):
            subject.require_publication_request(self.source)

    def test_request_scope_type_sequence_and_duplicate_keys_refuse(self):
        mutations = [{key: value} for key, value in (
            ("schema", original.engine.REQUEST_VALUE["schema"]), ("scope", "other"),
            ("family", "inertial_cellular_v1"), ("variant", "reference"), ("intent", "build-only"),
            ("request_sequence", 0), ("request_sequence", -1), ("request_sequence", True),
            ("request_sequence", "1"), ("request_sequence", 1.0), ("extra", True))]
        values = [json.dumps(dict(subject.REQUEST_VALUE, request_sequence=1) | value) for value in mutations]
        values += [json.dumps({key: value for key, value in dict(subject.REQUEST_VALUE, request_sequence=1).items() if key != field})
                   for field in (*subject.REQUEST_VALUE, "request_sequence")]
        good = json.dumps(dict(subject.REQUEST_VALUE, request_sequence=1))
        values += [good[:-1] + ', "request_sequence": 1}', good.replace('"schema":', '"schema":"discarded", "schema":', 1)]
        for text in values:
            with self.subTest(text=text):
                (self.root / subject.REQUEST).write_text(text, encoding="utf-8", newline="\n")
                self.git("add", "--", subject.REQUEST)
                self.git("commit", "--quiet", "-m", "Invalid observer request fixture")
                source = self.git("rev-parse", "HEAD").strip()
                with self.assertRaises(RuntimeError): subject.require_publication_request(source)

    def test_uncommitted_symlink_request_and_missing_observer_source_refuse(self):
        path = self.root / subject.REQUEST
        original_bytes = path.read_bytes()
        path.write_bytes(original_bytes + b"\n")
        with self.assertRaisesRegex(RuntimeError, "differs from source"): subject.require_publication_request(self.source)
        path.write_bytes(original_bytes)
        with mock.patch.object(Path, "is_symlink", lambda p: p == path):
            with self.assertRaises(RuntimeError): subject.require_publication_request(self.source)
        for relative in (subject.EVIDENCE, "godot/tests/" + LEDGER_CASE + ".gd", "godot/tests/" + WORKER_CASE + ".gd"):
            path = self.root / relative; saved = path.read_bytes(); path.unlink()
            try:
                with self.subTest(path=relative), self.assertRaises(RuntimeError): subject.require_publication_request(self.source)
            finally: path.write_bytes(saved)

    def test_wrong_event_repo_branch_workflow_run_or_head_refuses(self):
        for key, value in (("GITHUB_REPOSITORY", "other/cybersand"), ("GITHUB_EVENT_NAME", "pull_request"),
                           ("GITHUB_REF", "refs/heads/codex/lcb003-final-integration"),
                           ("GITHUB_WORKFLOW_REF", "techrote/cybersand/wrong@refs/heads/" + BRANCH),
                           ("GITHUB_SHA", "f" * 40), ("GITHUB_RUN_ID", ""), ("GITHUB_RUN_ATTEMPT", "0")):
            with self.subTest(key=key), mock.patch.dict(os.environ, {key: value}):
                with self.assertRaises(RuntimeError): subject.context(self.source)
        with self.assertRaises(RuntimeError): subject.context("e" * 40)

    def test_changed_remote_lease_refuses(self):
        actual = subject.git
        def different(*args):
            return (("f" * 40 + "\trefs/heads/" + BRANCH + "\n").encode()
                    if args[0] == "ls-remote" else actual(*args))
        with mock.patch.object(subject, "git", different):
            with self.assertRaisesRegex(RuntimeError, "Feature branch changed"):
                subject.check_source(argparse.Namespace(source_sha=self.source))


class ReportTests(ObserverFixture):
    def test_every_process_is_required_in_exact_order_once(self):
        for index in range(38):
            for kind in ("missing", "duplicate", "reordered"):
                value = copy.deepcopy(self.report)
                if kind == "missing": value["results"].pop(index)
                elif kind == "duplicate": value["results"].insert(index, value["results"][index])
                else:
                    other = (index + 1) % 38
                    value["results"][index], value["results"][other] = value["results"][other], value["results"][index]
                with self.subTest(index=index, kind=kind), self.assertRaises(RuntimeError):
                    subject.verify_case_results(self.root, value)

    def test_success_footer_cannot_override_failed_process_or_capture(self):
        for name in ("import", "test_liquid_desktop_default_host", LEDGER_CASE, WORKER_CASE):
            for key, value in (("returncode", 0xC0000005), ("returncode", False), ("status", "timeout"),
                               ("diagnostic_error", True), ("launch_error", "failed"), ("skip_messages", ["skip"]),
                               ("capture_error", "stream failed"), ("timeout_kind", "deadline"),
                               ("timeout_diagnostics", "dump"), ("timeout_diagnostic_error", "capture failed")):
                changed = copy.deepcopy(self.report)
                next(row for row in changed["results"] if row["name"] == name)[key] = value
                with self.subTest(name=name, key=key), self.assertRaises(RuntimeError):
                    subject.verify_case_results(self.root, changed)
        for key in ("capture_error", "timeout_kind", "timeout_diagnostics", "timeout_diagnostic_error"):
            changed = copy.deepcopy(self.report); changed["results"][-1].pop(key)
            with self.subTest(missing=key), self.assertRaises(RuntimeError): subject.verify_case_results(self.root, changed)

    def test_missing_duplicate_wrong_summary_and_dirty_observer_logs_refuse(self):
        for name in (LEDGER_CASE, WORKER_CASE):
            output = successful_logs()[name]
            variants = [output.replace("0 failures", "1 failures"), output.replace(" assertions", "0 assertions"),
                        output + output, output + "ERROR: failed\n", output + "SKIP unavailable\n",
                        output + "WARNING: incomplete observer\n", output.replace("504 assertions", "503 assertions").replace("265 assertions", "264 assertions"),
                        output.splitlines()[-1] + "\n"]
            for text in variants:
                self.log(name, text)
                with self.subTest(name=name, text=text), self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)
            self.log(name, output)
        (self.root / (WORKER_CASE + ".log")).write_text(worker_log() + "unhashed\n", encoding="utf-8")
        with self.assertRaisesRegex(RuntimeError, "log digest"): subject.verify_case_results(self.root, self.report)

    def test_duplicate_json_keys_nonfinite_and_bad_container_refuse(self):
        for name, output in ((LEDGER_CASE, ledger_log().replace('"ok": true', '"ok": false, "ok": true', 1)),
                             (WORKER_CASE, worker_log().replace('"configured": 1', '"configured": 4, "configured": 1', 1)),
                             (LEDGER_CASE, ledger_log().replace('"loss": "391"', '"loss": NaN', 1)),
                             (WORKER_CASE, worker_log({})), (LEDGER_CASE, ledger_log([]))):
            self.log(name, output)
            with self.subTest(name=name), self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)
            self.log(name, successful_logs()[name])
        for report in (None, [], {}, {"results": [None]}, {"results": None}):
            with self.subTest(report=report), self.assertRaises(RuntimeError): subject.verify_case_results(self.root, report)


class BundleTests(ObserverFixture):
    def setUp(self):
        super().setUp()
        # A real format-checked PE fixture, not a replacement runtime or build.
        image = bytearray(256); image[:2] = b"MZ"
        struct.pack_into("<I", image, 60, 128)
        image[128:134] = b"PE\0\0\x64\x86"
        struct.pack_into("<H", image, 150, 0x2000)
        struct.pack_into("<H", image, 152, 0x20B)
        (self.root / Path(subject.RUNTIMES["windows"]).name).write_bytes(image)
        self.ledgers = {"source_inputs": {"native/include/fixture.hpp": "a" * 64},
                        "build_inputs": {WORKFLOW: "b" * 64}}
        patch = mock.patch.object(subject, "input_ledgers", lambda source: copy.deepcopy(self.ledgers))
        patch.start(); self.addCleanup(patch.stop)
        identity = subject.runtime_identity(self.root / Path(subject.RUNTIMES["windows"]).name, "windows")
        self.report.update({"status": "passed", "completed": True, "source_commit": self.source,
            "platform": "windows", "runtime": identity,
            "godot": {"version": subject.GODOT_VERSION, "archive_sha512": subject.windows.GODOT_SHA512},
            "rapier_sha256": subject.RAPIER["windows"][1], "scope": subject.EXECUTION_SCOPE})
        self.manifest = subject.context(self.source) | copy.deepcopy(self.ledgers) | identity | {
            "schema_version": 1, "platform": "windows", "evidence": subject.EVIDENCE,
            "toolchain": "pure PE fixture, no native execution", "build_attempt": "1",
            "status": "validated-development-runtime",
            "validation_output": subject.BUNDLE_PREFIX + "-windows-123456/validation.json"}
        self.save_bundle()

    def save_bundle(self):
        path = self.root / "validation.json"
        path.write_bytes((json.dumps(self.report, sort_keys=True) + "\n").encode())
        self.manifest["validation_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        subject.manifest_path(self.root, "windows").write_bytes((json.dumps(self.manifest, sort_keys=True) + "\n").encode())

    def test_complete_new38_bundle_passes_with_correct_source_pins_scope_prefix(self):
        self.assertIs(subject.verify_bundle.__globals__["engine"], subject)
        result = subject.verify_bundle(self.root, "windows", self.source, validated=True)
        self.assertEqual(result, self.manifest)

    def test_foreign_stale_or_unvalidated_manifest_and_wrong_scope_prefix_refuse(self):
        original_manifest = copy.deepcopy(self.manifest)
        for key, value in (("source_commit", "f" * 40), ("source_tree", "f" * 40),
                           ("source_inputs", {}), ("build_inputs", {}), ("toolchain", ""),
                           ("status", "built-not-executed"), ("workflow_attempt", "2"),
                           ("build_attempt", "0"), ("evidence", "foreign"),
                           ("validation_output", original.engine.BUNDLE_PREFIX + "-windows-123456/validation.json")):
            self.manifest = copy.deepcopy(original_manifest); self.manifest[key] = value; self.save_bundle()
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                subject.verify_bundle(self.root, "windows", self.source, validated=True)
        self.manifest = original_manifest
        self.report["scope"] = original.engine.EXECUTION_SCOPE; self.save_bundle()
        with self.assertRaisesRegex(RuntimeError, "scope differs"):
            subject.verify_bundle(self.root, "windows", self.source, validated=True)

    def test_finished_json_cannot_hide_missing_case_wrong_pin_or_replaced_runtime(self):
        original_report = copy.deepcopy(self.report)
        for change in ("missing-case", "incomplete", "wrong-source", "wrong-runtime", "wrong-engine", "wrong-rapier"):
            self.report = copy.deepcopy(original_report)
            if change == "missing-case": self.report["results"].pop()
            elif change == "incomplete": self.report["completed"] = False
            elif change == "wrong-source": self.report["source_commit"] = "f" * 40
            elif change == "wrong-runtime": self.report["runtime"]["sha256"] = "f" * 64
            elif change == "wrong-engine": self.report["godot"]["archive_sha512"] = "f" * 128
            else: self.report["rapier_sha256"] = "f" * 64
            self.save_bundle()
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                subject.verify_bundle(self.root, "windows", self.source, validated=True)
        self.report = original_report; self.save_bundle()
        image = self.root / Path(subject.RUNTIMES["windows"]).name
        image.write_bytes(image.read_bytes() + b"replacement")
        with self.assertRaisesRegex(RuntimeError, "provenance mismatch"):
            subject.verify_bundle(self.root, "windows", self.source, validated=True)


class LedgerTests(ObserverFixture):
    def test_owner_generation_uses_full_unsigned64_not_signed64_or_json_number(self):
        # Pure codec/verifier boundaries, not executed native generation extrema.
        for text in ("9223372036854775808", "18446744073709551615"):
            value = ledger(); value["session_generation"] = text
            profile.verify_ledger(value)
        for text in ("18446744073709551616", "-1", "0", "01", "+1", 1, True, 1.0):
            value = ledger(); value["session_generation"] = text
            with self.subTest(value=text), self.assertRaises(RuntimeError): profile.verify_ledger(value)

    def test_actual_complete_ledger_and_full_native_decimal_ranges(self):
        profile.verify_ledger(ledger())
        for value, unsigned, expected in (("-9223372036854775808", False, -(1 << 63)),
                                           ("9223372036854775807", False, (1 << 63) - 1),
                                           ("18446744073709551615", True, (1 << 64) - 1),
                                           ("9007199254740993", True, (1 << 53) + 1), ("0", False, 0)):
            self.assertEqual(profile.decimal64(value, unsigned), expected)
        self.assertEqual(set(profile.LEDGER_KEYS), set(LEDGER_FIELDS))
        self.assertEqual(set(profile.UNSIGNED_KEYS), UNSIGNED)

    def test_every_ledger_key_is_required_and_preserves_native_decimal_type_range(self):
        for field in LEDGER_FIELDS:
            for bad in (0, 1.0, True, None, "01", "+1", "-0", "1.0", "1e2", " 1", "1 ", "9" * 100,
                        "18446744073709551616" if field in UNSIGNED else "9223372036854775808"):
                value = ledger(); value["values"][field] = bad
                with self.subTest(field=field, bad=bad), self.assertRaises(RuntimeError): profile.verify_ledger(value)
            value = ledger(); value["values"].pop(field)
            with self.subTest(missing=field), self.assertRaises(RuntimeError): profile.verify_ledger(value)
        for field in UNSIGNED | {"loss", "support", "remainder"}:
            value = ledger(); value["values"][field] = "-1"
            with self.subTest(field=field), self.assertRaises(RuntimeError): profile.verify_ledger(value)

    def test_native_binding_and_real_motion_retirement_reach_cannot_be_omitted(self):
        for key in ledger():
            value = ledger(); value.pop(key)
            with self.subTest(missing=key), self.assertRaises(RuntimeError): profile.verify_ledger(value)
        for key, bad in (("schema", "other"), ("ok", 1), ("available", False), ("completed_tick", "11"),
                         ("session_generation", "0"), ("policy_hash", "f" * 64), ("extension_identity", "f" * 64),
                         ("values", [])):
            value = ledger(); value[key] = bad
            with self.subTest(key=key), self.assertRaises(RuntimeError): profile.verify_ledger(value)
        for key in ("updates", "unit_moves", "velocity_retired", "retired_y", "maximum_read_reach", "maximum_write_reach"):
            value = ledger(); value["values"][key] = "0"
            with self.subTest(key=key), self.assertRaises(RuntimeError): profile.verify_ledger(value)
        value = ledger(); value["values"]["extra"] = "0"
        with self.assertRaises(RuntimeError): profile.verify_ledger(value)


class ParticipationTests(unittest.TestCase):
    def test_nondeterministic_actual_one_through_four_are_accepted(self):
        for observed in (1, 2, 3, 4): profile.verify_participation(participation(observed))
        rows = participation(); rows[3]["observed"] = 3; rows[7]["observed"] = 2
        profile.verify_participation(rows)

    def test_all20_rows_have_exact_unique_cohort_order(self):
        for index in range(20):
            for kind in ("missing", "duplicate", "reordered"):
                rows = participation()
                if kind == "missing": rows.pop(index)
                elif kind == "duplicate": rows.insert(index, rows[index])
                else: rows[index], rows[(index + 1) % 20] = rows[(index + 1) % 20], rows[index]
                with self.subTest(index=index, kind=kind), self.assertRaises(RuntimeError): profile.verify_participation(rows)

    def test_each_participant_field_type_identity_and_execution_bound(self):
        for index, row in enumerate(participation()):
            for key in row:
                rows = participation(); rows[index].pop(key)
                with self.subTest(index=index, missing=key), self.assertRaises(RuntimeError): profile.verify_participation(rows)
                for value in (None, "1", 1.0, []):
                    rows = participation(); rows[index][key] = value
                    with self.subTest(index=index, key=key, bad=value), self.assertRaises(RuntimeError): profile.verify_participation(rows)
            for key in set(row) - {"fixture", "available"}:
                rows = participation(); rows[index][key] = True
                with self.subTest(index=index, bool_key=key), self.assertRaises(RuntimeError): profile.verify_participation(rows)
            rows = participation(); rows[index]["extra"] = 0
            with self.subTest(index=index, extra=True), self.assertRaises(RuntimeError): profile.verify_participation(rows)
        for index, key, value in ((0, "observed", 1), (0, "scheduled_cores", 1), (18, "observed", 1),
                                  (18, "available", False), (19, "available", True), (19, "observed", 1),
                                  (19, "configured", 4), (19, "visited_cells", 0), (19, "moved_cells", 0),
                                  (2, "observed", 0), (3, "observed", 5), (3, "maximum_phase_jobs", 0),
                                  (3, "scheduled_cores", 3), (3, "available", False)):
            rows = participation(); rows[index][key] = value
            with self.subTest(index=index, key=key, value=value), self.assertRaises(RuntimeError): profile.verify_participation(rows)
        rows = participation()
        for row in rows:
            if "maximum_phase_jobs" in row: row["maximum_phase_jobs"] = 1
        with self.assertRaisesRegex(RuntimeError, "multiple-job"): profile.verify_participation(rows)


class IsolationTests(unittest.TestCase):
    def test_accepted_profiles_keep_private_maps_functions_and_full_positive_negative_controls(self):
        engines = [shared, brine.engine, water.engine, original.engine]
        before = [(old.BRANCH, dict(old.CASE_MARKERS), dict(old.CASE_TIMEOUTS), set(old.BUILD_EXACT),
                   dict(old.REQUEST_VALUE), old.verify_case_results) for old in engines]
        for old in engines:
            self.assertIsNot(old, subject)
            self.assertIs(old.context.__globals__, old.__dict__)
            self.assertIsNot(old.CASE_MARKERS, subject.CASE_MARKERS)
            self.assertIsNot(old.CASE_TIMEOUTS, subject.CASE_TIMEOUTS)
            self.assertIsNot(old.BUILD_EXACT, subject.BUILD_EXACT)
        self.assertIs(subject.context.__globals__, subject.__dict__)
        self.assertIs(profile._verify_application.__globals__["engine"], subject)
        self.assertIs(profile.application._verify_union.__globals__["engine"], subject)
        self.assertIs(subject.runner, original.engine.runner)
        roots = (subject.runner.ROOT, subject.windows.ROOT)
        for name in ("CASE_MARKERS", "CASE_TIMEOUTS", "REQUEST_VALUE", "LIQUID_POLICY_SECTIONS"):
            mapping = getattr(subject, name); saved = dict(mapping); mapping["observer-sentinel"] = {"own": False}
            try:
                for old in engines: self.assertNotIn("observer-sentinel", getattr(old, name))
            finally: mapping.clear(); mapping.update(saved)
        self.assertEqual(before, [(old.BRANCH, dict(old.CASE_MARKERS), dict(old.CASE_TIMEOUTS), set(old.BUILD_EXACT),
                                   dict(old.REQUEST_VALUE), old.verify_case_results) for old in engines])
        self.assertEqual(roots, (subject.runner.ROOT, subject.windows.ROOT))
        old_sections = copy.deepcopy(original.LEVEL_SECTIONS)
        saved_sections = copy.deepcopy(profile.application.LEVEL_SECTIONS)
        try:
            profile.application.LEVEL_SECTIONS["observer"] = {"nested": False}
            self.assertEqual(original.LEVEL_SECTIONS, old_sections)
        finally:
            profile.application.LEVEL_SECTIONS.clear(); profile.application.LEVEL_SECTIONS.update(saved_sections)
        with tempfile.TemporaryDirectory() as value:
            directory = Path(value); report = {"results": [], "log_sha256": {}}
            for name, output in host_logs().items():
                path = directory / (name + ".log"); path.write_bytes(output.encode())
                report["log_sha256"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
                report["results"].append({"name": name, "status": "passed", "returncode": 0,
                    "diagnostic_error": False, "launch_error": None, "skip_messages": []})
            original.engine.verify_case_results(directory, report)
            missing = copy.deepcopy(report); missing["results"].pop()
            with self.assertRaises(RuntimeError): original.engine.verify_case_results(directory, missing)
            path = directory / "test_liquid_level_preparation.log"
            path.write_bytes(path.read_bytes().replace(b'"thermal_payload": true', b'"thermal_payload": false'))
            report["log_sha256"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
            with self.assertRaises(RuntimeError): original.engine.verify_case_results(directory, report)

    def test_both_import_orders_keep_every_existing_profile_unchanged(self):
        names = ["lcb001_shared_contract_runtime_publication", "lcb005_inertial_runtime_publication",
                 "lcb005_water_inertial_runtime_publication", "lcb003_application_host_runtime_publication",
                 "lcb004_observer_runtime_publication"]
        for order in (names, list(reversed(names))):
            code = "import importlib; m={n:importlib.import_module(n) for n in " + repr(order) + "}; "
            code += "eng=[m[n] if n.startswith('lcb001') else m[n].engine for n in " + repr(names) + "]; "
            code += "assert len({id(e) for e in eng})==5; assert [len(e.CASE_MARKERS) for e in eng]==[12,14,14,35,37]; "
            code += "assert all(e.context.__globals__ is e.__dict__ for e in eng); assert eng[3].BRANCH=='codex/lcb003-final-integration'; assert eng[4].BRANCH=='codex/lcb004-observer'"
            result = subprocess.run([sys.executable, "-B", "-c", code], cwd=Path(__file__).parent,
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_shared_input_and_four_path_index_guards_bind_the_new_profile(self):
        spec = spec_from_file_location("_observer_shared_guard_fixture", Path(__file__).with_name("test_lcb001_shared_contract_runtime_publication.py"))
        fixture = module_from_spec(spec); spec.loader.exec_module(fixture)
        fixture.subject = subject; fixture.BRANCH = BRANCH
        fixture.WORKFLOW = "techrote/cybersand/" + WORKFLOW + "@refs/heads/" + BRANCH
        fixture.SUCCESS_LOGS = {name: text for name, text in successful_logs().items() if name != "import"}
        original_input_test = fixture.InputLedgerTests.test_grammar_sources_examples_and_fixture_are_source_bound
        def bind_observer_paths(case):
            original_input_test(case)
            source = case.git("rev-parse", "HEAD").decode().strip()
            for relative in (subject.WORKFLOW, subject.REQUEST, subject.EVIDENCE,
                             "tools/ci/lcb004_observer_runtime_publication.py",
                             "tools/ci/test_lcb004_observer_runtime_publication.py"):
                path = case.root / relative; data = path.read_bytes(); path.write_bytes(data + b"changed\n")
                try:
                    with case.subTest(path=relative), case.assertRaisesRegex(RuntimeError, "Working build/test input differs"):
                        subject.input_ledgers(source)
                finally: path.write_bytes(data)
        fixture.InputLedgerTests.test_grammar_sources_examples_and_fixture_are_source_bound = bind_observer_paths
        suite = unittest.TestSuite(unittest.defaultTestLoader.loadTestsFromTestCase(cls)
            for cls in (fixture.InputLedgerTests, fixture.PublicationIndexTests))
        result = unittest.TestResult(); suite.run(result)
        self.assertEqual(result.testsRun, 7)
        self.assertEqual(result.errors, [])
        self.assertEqual(result.failures, [])


class WorkflowTests(unittest.TestCase):
    def test_exact_unarmed_branch_and_unchanged_budgets_pins_four_path_lease(self):
        text = (REPOSITORY / WORKFLOW).read_text(encoding="utf-8")
        parent = (REPOSITORY / original.engine.WORKFLOW).read_text(encoding="utf-8")
        self.assertIn("branches: [" + BRANCH + "]", text)
        self.assertNotIn("workflow_dispatch:", text)
        self.assertIn("if test -f '" + subject.REQUEST + "'", text)
        self.assertIn("echo 'armed=false'", text)
        self.assertIn("needs.admission.outputs.armed == 'true'", text)
        self.assertNotIn("refs/heads/codex/lcb003-final-integration", text)
        self.assertEqual(re.findall(r"timeout-minutes: ([0-9]+)", text), ["5", "5", "55", "55", "25", "15"])
        self.assertEqual(re.findall(r"timeout [0-9]+m", text), re.findall(r"timeout [0-9]+m", parent))
        self.assertEqual(re.findall(r"uses: (\S+)", text), re.findall(r"uses: (\S+)", parent))
        self.assertEqual(re.findall(r"^\s*runs-on: (.+)$", text, re.M), re.findall(r"^\s*runs-on: (.+)$", parent, re.M))
        for line in parent.splitlines():
            if any(pin in line for pin in ("GODOT_URL:", "GODOT_CPP_COMMIT:", "LLVM_MINGW_URL:", "LLVM_MINGW_SHA256:", "GODOT_WINDOWS_URL:")):
                self.assertIn(line, text)
        self.assertEqual(text.count("contents: write"), 1)
        self.assertIn('test "$(git rev-list --parents -n 1 HEAD)" = "$(git rev-parse HEAD) $GITHUB_SHA"', text)
        self.assertIn('git push --force-with-lease="refs/heads/' + BRANCH + ':$GITHUB_SHA" origin HEAD:refs/heads/' + BRANCH, text)
        self.assertIn("git add -- " + " ".join([*subject.RUNTIMES.values(), *subject.MANIFESTS.values()]), text)
        filters = text.split("permissions:", 1)[0]
        for path in (*subject.RUNTIMES.values(), *subject.MANIFESTS.values()): self.assertNotIn(path, filters)
        for script in ("test_lcb001_shared_contract_runtime_publication.py", "test_lcb005_inertial_runtime_publication.py",
                       "test_lcb005_water_inertial_runtime_publication.py", "test_lcb003_application_host_runtime_publication.py",
                       "test_lcb004_observer_runtime_publication.py", "check_ci_provider_policy.py"):
            self.assertIn("tools/ci/" + script, text)
        self.assertTrue(set(original.engine.BUILD_EXACT).issubset(subject.BUILD_EXACT))
        for path in (WORKFLOW, subject.REQUEST, subject.EVIDENCE,
                     "tools/ci/lcb004_observer_runtime_publication.py", "tools/ci/test_lcb004_observer_runtime_publication.py"):
            self.assertIn(path, subject.BUILD_EXACT)


if __name__ == "__main__":
    unittest.main()
