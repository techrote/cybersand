#!/usr/bin/env python3
"""Adversarial coverage of the branch-scoped host publication profile."""
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest import mock

import lcb001_shared_contract_runtime_publication as shared
import lcb005_inertial_runtime_publication as historical_union
import lcb003_application_host_runtime_publication as profile
from test_lcb001_shared_contract_runtime_publication import SUCCESS_LOGS

subject = profile.engine
REPOSITORY = shared.ROOT


def body(variant):
    return {"variant": variant, "failed": False, "snapshot_failed": False, "error": "",
            "completed_ticks": 97, "attempted_tick": 97, "snapshot_tick": 96,
            "rapier_steps": 120, "contacts": 42, "applications": 30, "received": 30,
            "water": 3718400, "initial_water": 3718400,
            "accepted_impulse": [-1.0, -40.0], "gas": {"closes": True}}


def body_log(values=None):
    values = [body(variant) for variant in profile.BODY_VARIANTS] if values is None else values
    return "".join("LIQUID_WATER_REFERENCE_PLAY: " + json.dumps(value) + "\n" for value in values) + \
        "LIQUID_WATER_REFERENCE_BODY: 75 assertions; 0 failures\n"


def probe():
    return {"terminal": True, "ok": True,
            "checks": [{"name": "check" + str(i), "passed": True} for i in range(33)]}


def successful_logs():
    values = {"import": "import complete\n", **SUCCESS_LOGS}
    for name, prefix, sections in (
        ("test_lcb_pressure_optimization", "LCB_PRESSURE_OPTIMIZATION", profile.union.OPTIMIZATION_SECTIONS),
        ("test_lcb_inertial_adapter", "LCB_INERTIAL_ADAPTER", profile.union.INERTIAL_SECTIONS),
    ):
        values[name] = prefix + ": 100 assertions; 0 failures; completed=" + json.dumps(sections) + "\n"
    values.update({name: prefix + ": 100 assertions; 0 failures\n" for name, prefix in profile.HOST_MARKERS.items()})
    values["test_liquid_host_evidence"] = "LIQUID_HOST_EVIDENCE: 34 assertions, 0 failures\n"
    values["test_liquid_water_reference_body"] = body_log()
    values["test_liquid_level_preparation"] = "LIQUID_LEVEL_PREPARATION: 493 assertions; 0 failures; completed=" + json.dumps(profile.LEVEL_SECTIONS) + "\n"
    values["test_liquid_level_import_host"] += "LIQUID_LEVEL_IMPORT_HOST_RESULT " + json.dumps({"ok": True, "sections": profile.IMPORT_SECTIONS}) + "\n"
    values["test_liquid_host_web_probe"] = "LIQUID_HOST_WEB_PROBE_NATIVE: " + json.dumps(probe()) + "\n"
    return values


class ApplicationHostProfileTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.git("init", "--quiet")
        self.git("config", "user.name", "LCB host publisher fixture")
        self.git("config", "user.email", "lcb-fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        for relative in (subject.REQUEST, subject.EVIDENCE, *("godot/tests/" + name + ".gd" for name in subject.CASE_MARKERS)):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(dict(subject.REQUEST_VALUE, request_sequence=1))
                            if relative == subject.REQUEST else "fixture\n", encoding="utf-8", newline="\n")
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "Fixture")
        self.source = self.git("rev-parse", "HEAD").strip()
        patch = mock.patch.object(subject, "ROOT", self.root)
        patch.start(); self.addCleanup(patch.stop)
        patch = mock.patch.dict(os.environ, {
            "GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_NAME": "push",
            "GITHUB_REF": "refs/heads/" + subject.BRANCH,
            "GITHUB_WORKFLOW_REF": "techrote/cybersand/" + subject.WORKFLOW + "@refs/heads/" + subject.BRANCH,
            "GITHUB_SHA": self.source, "GITHUB_RUN_ID": "123456", "GITHUB_RUN_ATTEMPT": "1",
        })
        patch.start(); self.addCleanup(patch.stop)
        self.report = {"results": [], "log_sha256": {}}
        for name, output in successful_logs().items():
            self.log(name, output)
            self.report["results"].append({"name": name, "status": "passed", "returncode": 0,
                "diagnostic_error": False, "launch_error": None, "skip_messages": []})

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], text=True, stderr=subprocess.PIPE)

    def log(self, name, text):
        p = self.root / (name + ".log")
        p.write_bytes(text.encode())
        self.report["log_sha256"][p.name] = hashlib.sha256(p.read_bytes()).hexdigest()

    def test_isolated_defaults_and_exact_coverage(self):
        self.assertEqual(shared.BRANCH, "codex/lcb001-shared-contract")
        self.assertEqual(historical_union.engine.BRANCH, "codex/lcb005-inertial")
        self.assertEqual(len(historical_union.engine.CASE_MARKERS), 14)
        self.assertEqual(subject.BRANCH, "codex/lcb003-application-host")
        self.assertEqual(len(subject.CASE_MARKERS), 29)
        self.assertEqual(list(subject.CASE_MARKERS), list(successful_logs())[1:])
        self.assertNotIn("tools/ci/lcb005_inertial_publish_request.json", subject.BUILD_EXACT)
        subject.verify_case_results(self.root, self.report)
        subject.require_publication_request(self.source)
        self.assertEqual(subject.context(self.source)["source_commit"], self.source)

    def test_wrong_ref_and_old_source_refuse(self):
        for field, value in (("GITHUB_REF", "refs/heads/main"), ("GITHUB_EVENT_NAME", "pull_request"),
                             ("GITHUB_SHA", "a" * 40), ("GITHUB_RUN_ATTEMPT", "0")):
            with self.subTest(field=field), mock.patch.dict(os.environ, {field: value}):
                with self.assertRaises(RuntimeError): subject.context(self.source)

    def test_missing_actual_cysd_user_case_refuses_even_with_request(self):
        (self.root / "godot/tests/test_liquid_level_import_host.gd").unlink()
        with self.assertRaisesRegex(RuntimeError, "Required focused regression"):
            subject.require_publication_request(self.source)

    def test_each_missing_case_and_changed_log_refuse(self):
        for name in subject.CASE_MARKERS:
            with self.subTest(name=name):
                rows = self.report["results"]
                self.report["results"] = [row for row in rows if row["name"] != name]
                with self.assertRaisesRegex(RuntimeError, "Incomplete focused case coverage"):
                    subject.verify_case_results(self.root, self.report)
                self.report["results"] = rows
                path = self.root / (name + ".log")
                previous = path.read_bytes()
                path.write_bytes(b"changed\n")
                with self.assertRaisesRegex(RuntimeError, "Execution log digest mismatch"):
                    subject.verify_case_results(self.root, self.report)
                path.write_bytes(previous)

    def test_missing_duplicate_reordered_or_short_body_cohort_refuses(self):
        original = [body(variant) for variant in profile.BODY_VARIANTS]
        variants = [original[:-1], original + [original[-1]], list(reversed(original))]
        for key, value in (("failed", True), ("snapshot_failed", True), ("error", "retired compartment"),
                           ("completed_ticks", 95), ("snapshot_tick", 95), ("attempted_tick", 98),
                           ("contacts", 0), ("applications", 0), ("rapier_steps", 0), ("received", 0),
                           ("water", 3718399), ("accepted_impulse", [0, 0]), ("accepted_impulse", [float("nan"), 1]),
                           ("gas", {"closes": False})):
            changed = copy.deepcopy(original);changed[0][key] = value;variants.append(changed)
        for values in variants:
            with self.subTest(values=values):
                self.log("test_liquid_water_reference_body", body_log(values))
                with self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)

    def test_boolean_sections_and_exact_keys_are_required(self):
        for name, expected, prefix, suffix in (
            ("test_liquid_level_preparation", profile.LEVEL_SECTIONS,
             "LIQUID_LEVEL_PREPARATION: 493 assertions; 0 failures; completed=", "\n"),
            ("test_liquid_level_import_host", profile.IMPORT_SECTIONS,
             'LIQUID_LEVEL_IMPORT_HOST: 100 assertions; 0 failures\nLIQUID_LEVEL_IMPORT_HOST_RESULT {"ok": true, "sections": ', "}\n"),
        ):
            for key in expected:
                for value in (False, 1, "true", None):
                    changed = dict(expected);changed[key] = value
                    self.log(name, prefix + json.dumps(changed) + suffix)
                    with self.subTest(name=name, key=key, value=value), self.assertRaises(RuntimeError):
                        subject.verify_case_results(self.root, self.report)
            for changed in ({}, dict(expected, extra=True), []):
                self.log(name, prefix + json.dumps(changed) + suffix)
                with self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)
            self.log(name, successful_logs()[name])

    def test_probe_must_finish_all_distinct_checks(self):
        values = []
        for key in ("terminal", "ok"):
            changed = probe();changed[key] = False;values.append(changed)
        changed = probe();changed["checks"].pop();values.append(changed)
        changed = probe();changed["checks"][0]["passed"] = 1;values.append(changed)
        changed = probe();changed["checks"][0] = changed["checks"][1];values.append(changed)
        for value in values:
            self.log("test_liquid_host_web_probe", "LIQUID_HOST_WEB_PROBE_NATIVE: " + json.dumps(value) + "\n")
            with self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)

    def test_errors_skips_and_zero_assertions_cannot_publish(self):
        for name in profile.HOST_MARKERS:
            original = successful_logs()[name]
            for text in (original.replace("0 failures", "1 failures"),
                         re.sub(r"[0-9]+ assertions", "0 assertions", original),
                         original + "ERROR: native fault\n", original + "SKIP missing owner\n", original + original):
                self.log(name, text)
                with self.subTest(name=name), self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)
            self.log(name, original)

    def test_workflow_unarmed_branch_bound_four_path_append(self):
        text = (REPOSITORY / subject.WORKFLOW).read_text(encoding="utf-8")
        self.assertIn("branches: [" + subject.BRANCH + "]", text)
        self.assertIn("echo 'armed=false'", text)
        self.assertNotIn("workflow_dispatch:", text)
        self.assertIn("needs.admission.outputs.armed == 'true'", text)
        self.assertIn("runs-on: windows-2022", text)
        self.assertIn("runs-on: ubuntu-24.04", text)
        self.assertEqual(text.count("contents: write"), 1)
        self.assertIn('test "$(git rev-list --parents -n 1 HEAD)" = "$(git rev-parse HEAD) $GITHUB_SHA"', text)
        self.assertIn('git push --force-with-lease="refs/heads/' + subject.BRANCH + ':$GITHUB_SHA" origin HEAD:refs/heads/' + subject.BRANCH, text)
        self.assertIn("git add -- " + " ".join([*subject.RUNTIMES.values(), *subject.MANIFESTS.values()]), text)


if __name__ == "__main__":
    unittest.main()
