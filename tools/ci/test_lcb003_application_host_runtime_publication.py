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
import lcb005_water_inertial_runtime_publication as historical_water
import lcb003_application_host_runtime_publication as profile
from test_lcb001_shared_contract_runtime_publication import SUCCESS_LOGS
from test_lcb005_water_inertial_runtime_publication import water_line, water_proof

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
    mixed = [{"variant": variant, "census": {"counts": {"water": 55, "oil": 48, "brine": 48}, "motion": True},
              "water_integer": 12240, "observed_retained_motion": True, "physical_hash": "a" * 16,
              "policy_sha256": str(i) * 64, "native_receipt_sha256": "b" * 64}
             for i, variant in enumerate(profile.WEB_MIXED_VARIANTS)]
    for row in mixed[1:]:
        row.update(projection="c" * 16, optimization_execution_version=3)
    return {"schema_version": 1, "terminal": True, "ok": True, "failures": [],
            "normalization": {"rule": "water-normalize-v1", "water_after": 255,
                              "payload_sha256": "a" * 64, "receipt_sha256": "b" * 64},
            "checks": [{"name": name, "passed": True} for name in profile.web_check_names()],
            "mixed_runs": mixed,
            "water_runs": [{"family": family, "variant": variant, "policy_sha256": str(i) * 64,
                            "native_receipt_sha256": "b" * 64, "normalized_payload_sha256": "c" * 64,
                            "positive_delta": 127, "negative_delta": 127, "water_integer": 12495,
                            "ticks": 30, "quantity_exact_each_tick": True,
                            "observed_retained_motion": family == "inertial_cellular_v1",
                            "census": {"count": 49, "full": True, "motion": False, "quantity": 12495},
                            "hash_version": 3 if family == "inertial_cellular_v1" else 2,
                            "radius": 3, "physical_hash": "d" * 16}
                           for i, (family, variant) in enumerate(profile.WEB_WATER_ARMS)]}


def ordinary_result():
    return {"ok": True, "cohorts": [{"demo": demo, "quality": quality, "region": [0, 0, 600, 420],
            "policy_hash": "a" * 64, "initial_player": [24, 222], "executed_ticks": 12, "reset_generation": 3}
            for demo in profile.ORDINARY_DEMOS for quality in (0, 2)], "matched_geometry": {
                "inertial": {"geometry": 3, "physical_hash_version": 3, "extension": "b" * 64,
                             "native_extension": {"family": 4, "extension_digest": "b" * 64}},
                "current_comparator": {"geometry": 3, "physical_hash_version": 2}}}


def poses_result():
    return {"ok": True, "frozen_frames": 32, "default_mask_sha256": "c" * 64,
            "explicit_positions": [[124, 92], [140, 72], [176, 52]]}


def synchronous_result():
    return {"ok": True, "cohorts": [{"preset": preset, "family": "pressure_flow_v1",
            "variant": {2:"reference",3:"cached",4:"cached_dormant"}[preset], "policy_hash": str(preset)*64,
            "completed_ticks": 240, "manual_steps": 240,
            "contacts": 34670, "water": 937125, "gas_closes": True, "applications": 270,
            "accepted_impulse": [-102.8, -9.5], "absolute_impulse": 876.6, "max_accepted_age": 0,
            "initial_body0": [124, 90], "final_body0": [124, 159.0]} for preset in profile.SYNCHRONOUS_BODY_PRESETS]}


def synchronous_water_result():
    return {"ok": True, "whole_cell_source_refusal_families": ["cellular_yield_v1", "inertial_cellular_v1"],
            "cohorts": [{"preset": preset, "family": "freemass_v1" if preset == 0 else "pressure_flow_v1",
            "variant": {0:"reference",2:"reference",3:"cached",4:"cached_dormant"}[preset],
            "policy_hash": str(preset)*64, "quality": 0, "completed_ticks": 240, "manual_steps": 240,
            "contacts": 83046, "water": 3718400, "gas_available": preset != 0, "gas_closes": preset != 0,
            "pressure_accounting_valid": True, "applications": 421, "observation_tick": 180,
            "accepted_impulse": [36.5, 772.0], "absolute_impulse": 1394.2, "max_accepted_age": 0,
            "initial_body0": [124, 90], "final_body0": [123.5, 245.0]} for preset in profile.SYNCHRONOUS_WATER_PRESETS]}


def default_play(variant):
    return {"variant": variant, "completed_ticks": 97, "attempted_tick": 97, "rapier_steps": 96,
            "contacts": 137, "applications": 6, "signed_impulse": [9.95, -1.14], "ages": {"0": 117, "1": 66},
            "water": 628320, "initial_water": 628320, "gas": {}, "failed": False, "snapshot_failed": False}


def capacity_refusal(variant):
    return {"variant": variant, "healthy": True, "tick": 0, "retained_receipt_hash": "d" * 64,
            "actual_receipt_hash": "d" * 64, "attempt_kind": "construction_attempt",
            "error": "capacity_refused: initial pressure gas compartment capacity exceeds 1024"}


def default_log(plays=None, refusals=None):
    plays = [default_play(v) for v in profile.DEFAULT_PLAY_VARIANTS] if plays is None else plays
    refusals = [capacity_refusal(v) for v in profile.DEFAULT_CAPACITY_VARIANTS] if refusals is None else refusals
    return "".join("LIQUID_DESKTOP_DEFAULT_PLAY: " + json.dumps(row) + "\n" for row in plays) + \
        "".join("LIQUID_DESKTOP_DEFAULT_CAPACITY_REFUSAL: " + json.dumps(row) + "\n" for row in refusals) + \
        "LIQUID_DESKTOP_DEFAULT_HOST: 86 assertions; 0 failures\n"


def successful_logs():
    values = {"import": "import complete\n", **SUCCESS_LOGS}
    values["test_liquid_solver_policy"] += water_line()
    for name, prefix, sections in (
        ("test_lcb_pressure_optimization", "LCB_PRESSURE_OPTIMIZATION", profile.union.OPTIMIZATION_SECTIONS),
        ("test_lcb_inertial_adapter", "LCB_INERTIAL_ADAPTER", profile.union.INERTIAL_SECTIONS),
    ):
        values[name] = prefix + ": 100 assertions; 0 failures; completed=" + json.dumps(sections) + "\n"
    values.update({name: prefix + ": 100 assertions; 0 failures\n" for name, prefix in profile.HOST_MARKERS.items()})
    values["test_liquid_host_evidence"] = "LIQUID_HOST_EVIDENCE: 34 assertions, 0 failures\n"
    values["test_liquid_water_reference_body"] = body_log()
    values["test_liquid_level_preparation"] = "LIQUID_LEVEL_PREPARATION: 493 assertions; 0 failures; completed=" + json.dumps(profile.LEVEL_SECTIONS) + "\n"
    values["test_liquid_default_demo_preparation"] = "LIQUID_DEFAULT_DEMO_PREPARATION: 100 assertions; 0 failures; completed=" + json.dumps(profile.DEFAULT_SECTIONS) + "\n"
    values["test_liquid_level_import_host"] += "LIQUID_LEVEL_IMPORT_HOST_RESULT " + json.dumps({"ok": True, "sections": profile.IMPORT_SECTIONS}) + "\n"
    for name, prefix, result in (
        ("test_liquid_ordinary_demo_host", "LIQUID_ORDINARY_DEMO_HOST_RESULT", ordinary_result()),
        ("test_liquid_reference_body_poses", "LIQUID_REFERENCE_BODY_POSES_RESULT", poses_result()),
        ("test_liquid_synchronous_reference_body", "LIQUID_SYNCHRONOUS_REFERENCE_BODY_RESULT", synchronous_result()),
        ("test_liquid_synchronous_water_reference_body", "LIQUID_SYNCHRONOUS_WATER_REFERENCE_BODY_RESULT", synchronous_water_result()),
    ):
        values[name] += prefix + " " + json.dumps(result) + "\n"
    values["test_liquid_desktop_default_host"] = default_log()
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
        self.assertEqual(historical_water.engine.BRANCH, "codex/lcb005-water-inertial")
        self.assertEqual(len(historical_water.engine.CASE_MARKERS), 14)
        self.assertEqual(subject.BRANCH, "codex/lcb003-final-integration")
        self.assertEqual(len(subject.CASE_MARKERS), 35)
        self.assertEqual(list(subject.CASE_MARKERS), list(successful_logs())[1:])
        self.assertNotIn("tools/ci/lcb005_inertial_publish_request.json", subject.BUILD_EXACT)
        self.assertEqual(subject.CASE_TIMEOUTS, historical_union.engine.CASE_TIMEOUTS)
        subject.verify_case_results(self.root, self.report)
        subject.require_publication_request(self.source)
        self.assertEqual(subject.context(self.source)["source_commit"], self.source)

    def test_wrong_ref_and_old_source_refuse(self):
        for field, value in (("GITHUB_REF", "refs/heads/main"), ("GITHUB_EVENT_NAME", "pull_request"),
                             ("GITHUB_SHA", "a" * 40), ("GITHUB_RUN_ATTEMPT", "0")):
            with self.subTest(field=field), mock.patch.dict(os.environ, {field: value}):
                with self.assertRaises(RuntimeError): subject.context(self.source)

    def test_missing_actual_owner_cases_refuse_even_with_request(self):
        for name in ("test_liquid_level_import_host", "test_liquid_default_demo_preparation", "test_liquid_desktop_default_host",
                     "test_liquid_synchronous_water_reference_body"):
            path = self.root / ("godot/tests/" + name + ".gd")
            path.unlink()
            with self.subTest(name=name), self.assertRaisesRegex(RuntimeError, "Required focused regression"):
                subject.require_publication_request(self.source)
            path.write_text("fixture\n", encoding="utf-8")

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
            ("test_liquid_default_demo_preparation", profile.DEFAULT_SECTIONS,
             "LIQUID_DEFAULT_DEMO_PREPARATION: 100 assertions; 0 failures; completed=", "\n"),
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
        changed = probe();changed["checks"][0]["name"] = "different check";values.append(changed)
        changed = probe();changed["checks"][0], changed["checks"][1] = changed["checks"][1], changed["checks"][0];values.append(changed)
        changed = probe();changed["schema_version"] = True;values.append(changed)
        changed = probe();changed["failures"] = ["retained failure"];values.append(changed)
        for value in values:
            self.log("test_liquid_host_web_probe", "LIQUID_HOST_WEB_PROBE_NATIVE: " + json.dumps(value) + "\n")
            with self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)

    def test_web_common_water_requires_six_actual_normalized_family_arms(self):
        original = probe()
        values = []
        for replacement in ([], original["water_runs"][:-1], list(reversed(original["water_runs"])),
                            original["water_runs"] + [original["water_runs"][-1]]):
            value = copy.deepcopy(original);value["water_runs"] = replacement;values.append(value)
        for key, replacement in (("family", "inertial_cellular_v1"), ("variant", "cached"),
                                 ("policy_sha256", ""), ("native_receipt_sha256", "x" * 64),
                                 ("normalized_payload_sha256", "e" * 64), ("physical_hash", ""),
                                 ("radius", 2), ("radius", True), ("hash_version", 3),
                                 ("positive_delta", 0), ("negative_delta", 0), ("water_integer", 12494),
                                 ("ticks", 29), ("quantity_exact_each_tick", 1)):
            value = copy.deepcopy(original);value["water_runs"][0][key] = replacement;values.append(value)
        for index, key, replacement in ((0, "quantity", 12494), (0, "count", 0),
                                        (1, "full", 1), (1, "count", 48)):
            value = copy.deepcopy(original);value["water_runs"][index]["census"][key] = replacement;values.append(value)
        value = copy.deepcopy(original);value["water_runs"][-1]["observed_retained_motion"] = False;values.append(value)
        value = copy.deepcopy(original);value["water_runs"][-1]["hash_version"] = 2;values.append(value)
        value = copy.deepcopy(original);value["water_runs"][1]["policy_sha256"] = value["water_runs"][0]["policy_sha256"];values.append(value)
        for value in values:
            self.log("test_liquid_host_web_probe", "LIQUID_HOST_WEB_PROBE_NATIVE: " + json.dumps(value) + "\n")
            with self.subTest(value=value), self.assertRaises(RuntimeError):
                subject.verify_case_results(self.root, self.report)

    def test_web_retains_original_mixed_and_normalization_proof(self):
        original = probe()
        values = []
        for key, replacement in (("mixed_runs", []), ("normalization", {})):
            value = copy.deepcopy(original);value[key] = replacement;values.append(value)
        for key, replacement in (("water_integer", 12239), ("observed_retained_motion", False),
                                 ("physical_hash", ""), ("policy_sha256", ""), ("native_receipt_sha256", "")):
            value = copy.deepcopy(original);value["mixed_runs"][0][key] = replacement;values.append(value)
        value = copy.deepcopy(original);value["mixed_runs"].reverse();values.append(value)
        for key, replacement in (("oil", 47), ("brine", 47), ("water", 0)):
            value = copy.deepcopy(original);value["mixed_runs"][0]["census"]["counts"][key] = replacement;values.append(value)
        value = copy.deepcopy(original);value["mixed_runs"][1]["optimization_execution_version"] = 2;values.append(value)
        value = copy.deepcopy(original);value["mixed_runs"][1]["projection"] = "e" * 16;values.append(value)
        value = copy.deepcopy(original);value["mixed_runs"][1]["policy_sha256"] = value["mixed_runs"][0]["policy_sha256"];values.append(value)
        value = copy.deepcopy(original);value["normalization"]["water_after"] = 254;values.append(value)
        for value in values:
            self.log("test_liquid_host_web_probe", "LIQUID_HOST_WEB_PROBE_NATIVE: " + json.dumps(value) + "\n")
            with self.subTest(value=value), self.assertRaises(RuntimeError):
                subject.verify_case_results(self.root, self.report)

    def test_ordinary_demo_coverage_execution_restart_and_native_identity(self):
        name, prefix = "test_liquid_ordinary_demo_host", "LIQUID_ORDINARY_DEMO_HOST_RESULT"
        values = []
        for key, replacement in (("cohorts", []), ("ok", 1), ("matched_geometry", {})):
            changed = ordinary_result(); changed[key] = replacement; values.append(changed)
        for key, replacement in (("quality", False), ("executed_ticks", 11), ("reset_generation", 0),
                                 ("policy_hash", ""), ("initial_player", [400, 300]), ("region", [0, 0, 0, 420])):
            changed = ordinary_result(); changed["cohorts"][0][key] = replacement; values.append(changed)
        changed = ordinary_result(); changed["cohorts"].reverse(); values.append(changed)
        changed = ordinary_result(); changed["cohorts"][0] = changed["cohorts"][1]; values.append(changed)
        changed = ordinary_result(); changed["matched_geometry"]["inertial"]["native_extension"]["extension_digest"] = "d" * 64; values.append(changed)
        changed = ordinary_result(); changed["matched_geometry"]["current_comparator"]["geometry"] = 2; values.append(changed)
        for value in values:
            self.log(name, "LIQUID_ORDINARY_DEMO_HOST: 117 assertions; 0 failures\n" + prefix + " " + json.dumps(value) + "\n")
            with self.subTest(value=value), self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)

    def test_reference_poses_require_frozen_frames_and_actual_original_coordinates(self):
        name, prefix = "test_liquid_reference_body_poses", "LIQUID_REFERENCE_BODY_POSES_RESULT"
        for key, replacement in (("ok", 1), ("frozen_frames", 31), ("default_mask_sha256", ""),
                                 ("explicit_positions", [[160, 176], [212, 176], [264, 176]])):
            changed = poses_result(); changed[key] = replacement
            self.log(name, "LIQUID_REFERENCE_BODY_POSES: 50 assertions; 0 failures\n" + prefix + " " + json.dumps(changed) + "\n")
            with self.subTest(key=key), self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)

    def test_synchronous_bodies_need_all_three_healthy_positive_prefixes(self):
        name, prefix = "test_liquid_synchronous_reference_body", "LIQUID_SYNCHRONOUS_REFERENCE_BODY_RESULT"
        values = []
        for key, replacement in (("completed_ticks", 239), ("manual_steps", 239), ("contacts", 0),
                                 ("family", "freemass_v1"), ("variant", "cached"), ("policy_hash", ""),
                                 ("applications", 0), ("water", 937124), ("gas_closes", 1),
                                 ("accepted_impulse", [0, 0]), ("accepted_impulse", [float("nan"), 1]),
                                 ("absolute_impulse", 0), ("max_accepted_age", 9), ("max_accepted_age", -1),
                                 ("final_body0", [124, 90]), ("initial_body0", [124, 92])):
            changed = synchronous_result(); changed["cohorts"][0][key] = replacement; values.append(changed)
        changed = synchronous_result(); changed["cohorts"].pop(); values.append(changed)
        changed = synchronous_result(); changed["cohorts"].reverse(); values.append(changed)
        for value in values:
            self.log(name, "LIQUID_SYNCHRONOUS_REFERENCE_BODY: 70 assertions; 0 failures\n" + prefix + " " + json.dumps(value) + "\n")
            with self.subTest(value=value), self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)

    def test_new_host_json_must_be_present_unique_and_terminal(self):
        for name, prefix in (("test_liquid_ordinary_demo_host", "LIQUID_ORDINARY_DEMO_HOST_RESULT"),
                             ("test_liquid_reference_body_poses", "LIQUID_REFERENCE_BODY_POSES_RESULT"),
                             ("test_liquid_synchronous_reference_body", "LIQUID_SYNCHRONOUS_REFERENCE_BODY_RESULT"),
                             ("test_liquid_synchronous_water_reference_body", "LIQUID_SYNCHRONOUS_WATER_REFERENCE_BODY_RESULT")):
            original = successful_logs()[name]
            summary, result = original.split(prefix, 1)
            for changed in (summary, original + prefix + result, summary + prefix + " {malformed}\n",
                            original + prefix + " malformed trailing record\n", summary + prefix + " []\n",
                            original + "SCRIPT ERROR: Invalid assignment of property\n"):
                self.log(name, changed)
                with self.subTest(name=name), self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)
            self.log(name, original)

    def test_synchronous_water_requires_actual_four_policies_and_accounting(self):
        name = "test_liquid_synchronous_water_reference_body"
        prefix = "LIQUID_SYNCHRONOUS_WATER_REFERENCE_BODY_RESULT "
        values = []
        for key, replacement in (("family", "cellular_yield_v1"), ("variant", "cached"), ("policy_hash", ""),
                                 ("quality", 2), ("completed_ticks", 239), ("manual_steps", 239),
                                 ("water", 3718399), ("observation_tick", 179), ("contacts", 0),
                                 ("applications", 0), ("gas_available", False), ("gas_closes", 1),
                                 ("pressure_accounting_valid", False), ("accepted_impulse", [0, 0]),
                                 ("absolute_impulse", 0), ("max_accepted_age", 9), ("final_body0", [124, 90])):
            changed = synchronous_water_result();changed["cohorts"][0][key] = replacement;values.append(changed)
        changed = synchronous_water_result();changed["cohorts"].pop();values.append(changed)
        changed = synchronous_water_result();changed["cohorts"].reverse();values.append(changed)
        changed = synchronous_water_result();changed["cohorts"][1]["policy_hash"] = changed["cohorts"][0]["policy_hash"];values.append(changed)
        changed = synchronous_water_result();changed["cohorts"][-1]["gas_available"] = True;values.append(changed)
        changed = synchronous_water_result();changed["whole_cell_source_refusal_families"].pop();values.append(changed)
        for value in values:
            self.log(name, "LIQUID_SYNCHRONOUS_WATER_REFERENCE_BODY: 93 assertions; 0 failures\n" + prefix + json.dumps(value) + "\n")
            with self.subTest(value=value), self.assertRaises(RuntimeError):
                subject.verify_case_results(self.root, self.report)

    def test_water_native_proof_cannot_be_dropped_or_substituted(self):
        name = "test_liquid_solver_policy"
        original = successful_logs()[name].split("WATER_INERTIAL_POLICY_PROOF:", 1)[0]
        self.log(name, original)
        with self.assertRaisesRegex(RuntimeError, "Missing or duplicate Water IN proof"):
            subject.verify_case_results(self.root, self.report)
        values = []
        for section in ("cohorts", "coherence", "restores"):
            value = water_proof();value[section].pop();values.append(value)
        value = water_proof();value["cohorts"][1]["physical_hash"] = "f" * 16;values.append(value)
        value = water_proof();value["coherence"][0]["observed"][-1] = 1;values.append(value)
        value = water_proof();value["refusals"]["rows"][0]["unchanged_session"] = False;values.append(value)
        for value in values:
            self.log(name, original + water_line(value))
            with self.subTest(value=value), self.assertRaises(RuntimeError):
                subject.verify_case_results(self.root, self.report)

    def test_duplicate_host_fields_refuse_even_with_passing_summary(self):
        name = "test_liquid_synchronous_water_reference_body"
        output = successful_logs()[name].replace('"ok": true', '"ok": false, "ok": true', 1)
        self.log(name, output)
        with self.assertRaisesRegex(RuntimeError, "Duplicate host observation field"):
            subject.verify_case_results(self.root, self.report)

    def test_default_play_requires_both_healthy_fm_cy_prefixes(self):
        original = [default_play(v) for v in profile.DEFAULT_PLAY_VARIANTS]
        values = [original[:-1], original + [original[-1]], list(reversed(original))]
        for key, replacement in (("failed", True), ("snapshot_failed", 1), ("completed_ticks", 95),
                                 ("attempted_tick", 98), ("rapier_steps", 0), ("contacts", 0), ("applications", 0),
                                 ("water", 628319), ("initial_water", 628319), ("signed_impulse", [0, 0]),
                                 ("signed_impulse", [float("inf"), 1]), ("ages", {}), ("ages", {"0": 0}),
                                 ("ages", {"old": 1}), ("ages", {"9": 10})):
            changed = copy.deepcopy(original); changed[0][key] = replacement; values.append(changed)
        for rows in values:
            self.log("test_liquid_desktop_default_host", default_log(plays=rows))
            with self.subTest(rows=rows), self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)

    def test_all_three_default_pressure_refusals_retain_healthy_native_identity(self):
        original = [capacity_refusal(v) for v in profile.DEFAULT_CAPACITY_VARIANTS]
        values = [original[:-1], original + [original[-1]], list(reversed(original))]
        for key, replacement in (("healthy", 1), ("tick", 1), ("actual_receipt_hash", "e" * 64),
                                 ("retained_receipt_hash", ""), ("attempt_kind", "host_invented"),
                                 ("error", "some setup failed")):
            changed = copy.deepcopy(original); changed[0][key] = replacement; values.append(changed)
        for rows in values:
            self.log("test_liquid_desktop_default_host", default_log(refusals=rows))
            with self.subTest(rows=rows), self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)

    def test_completed_default_json_cannot_override_process_crash(self):
        row = next(row for row in self.report["results"] if row["name"] == "test_liquid_desktop_default_host")
        row["returncode"] = 0xC0000005
        with self.assertRaisesRegex(RuntimeError, "Non-passing execution record"):
            subject.verify_case_results(self.root, self.report)

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
        self.assertIn("tools/ci/test_lcb005_water_inertial_runtime_publication.py", text)
        self.assertEqual(text.count("contents: write"), 1)
        self.assertIn('test "$(git rev-list --parents -n 1 HEAD)" = "$(git rev-parse HEAD) $GITHUB_SHA"', text)
        self.assertIn('git push --force-with-lease="refs/heads/' + subject.BRANCH + ':$GITHUB_SHA" origin HEAD:refs/heads/' + subject.BRANCH, text)
        self.assertIn("git add -- " + " ".join([*subject.RUNTIMES.values(), *subject.MANIFESTS.values()]), text)


if __name__ == "__main__":
    unittest.main()
