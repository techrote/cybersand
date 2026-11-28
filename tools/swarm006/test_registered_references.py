#!/usr/bin/env python3
"""Reference-registration invariants; tests use revealed seed605 only."""
import copy
import gzip
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import run_registered_references as refs


def fixture():
    receipt = {"result": "PASS", "variant": "swarm006", "source_dirty": "", "allow_dirty_requested": False,
        "source_custody_revalidated": True, "source_commit": "a" * 40, "source_tree": "e" * 40,
        "definition_sha256": "b" * 64, "harness_sha256": "c" * 64, "runner_sha256": "d" * 64,
        "binary_sha256": "e" * 64}
    registration = {"schema": 1, "programme": "GENTEK-SWARM-006", "classification": "preregistered_unseen",
        "registration_id": "unit-test-not-a-registration", "candidate": {"git_sha": receipt["source_commit"],
        **{k: receipt[k] for k in ("definition_sha256", "harness_sha256", "runner_sha256")}},
        "limits": dict(refs.runner.REGISTERED_LIMITS), "cases": [{"fixture": "island", "profile": "industrial", "seed": 605}],
        "policies": [{"name": name, "rounds": 2, "role": "primary" if name in ("both", "recovery") else "secondary"}
            for name in ("off", "terminal_only", "receptor_only", "both", "recovery")],
        "case_count": 1, "execution_count": 5, "controls": False, "timeout_seconds": 90}
    identity = {key: receipt[key] for key in ("variant", "source_commit", "source_tree", "definition_sha256",
        "binary_sha256", "harness_sha256", "runner_sha256")}
    identity["build_receipt_sha256"] = "f" * 64
    identities = {"swarm006": identity}
    for variant in refs.REFERENCE_POLICIES:
        identities[variant] = {**identity, "variant": variant, "source_commit": refs.runner.FROZEN[variant]}
    hashes = {"candidate_registration_sha256": "1" * 64, "wrapper_sha256": "2" * 64,
        "helper_runner_sha256": "d" * 64, "analysis_plan_sha256": "3" * 64, "analysis_program_sha256": "4" * 64}
    cases = registration["cases"]; choices = [(p["name"], p["rounds"]) for p in registration["policies"]]
    master = {"schema": 1, "programme": "GENTEK-SWARM-006", "classification": "preregistered_frozen_reference_comparison",
        "registration_id": "unit-test-master-not-published", "candidate_registration": copy.deepcopy(registration), **hashes,
        "cases_sha256": refs.digest(cases), "candidate_build": identity, "controls": False,
        "references": {variant: {"build": identities[variant], "policies": [{"name": p, "rounds": r} for p, r in policies],
            "expected_ids": refs.execution_ids(cases, policies)} for variant, policies in refs.REFERENCE_POLICIES.items()},
        "expected_candidate_ids": refs.execution_ids(cases, choices), "expected_candidate_executions": 5,
        "expected_reference_executions": 5, "expected_total_executions": 10,
        "primary": copy.deepcopy(refs.PRIMARY), "required_parity": list(refs.PARITY)}
    return master, registration, receipt, identities, hashes


class ReferenceTests(unittest.TestCase):
    def test_unseen_guard_is_not_weakened_for_references(self):
        with self.assertRaises(ValueError): refs.validate_plan(*fixture())

    @mock.patch.object(refs.runner, "FRESH_EXCLUDED_SEEDS", frozenset())
    def test_exact_manifest_keeps_all_reference_policies_and_ids(self):
        master, registration, receipt, identities, hashes = fixture()
        cases, policies = refs.validate_plan(master, registration, receipt, identities, hashes)
        self.assertEqual(1, len(cases)); self.assertEqual(5, len(policies))
        self.assertEqual(5, sum(len(v["expected_ids"]) for v in master["references"].values()))
        self.assertEqual("swarm005", master["primary"]["before"]["variant"])
        self.assertEqual("R", master["primary"]["priority"])

    @mock.patch.object(refs.runner, "FRESH_EXCLUDED_SEEDS", frozenset())
    def test_manifest_rejects_changed_bindings_denominator_and_scope(self):
        master, registration, receipt, identities, hashes = fixture()
        changes = []
        for key in hashes:
            value = copy.deepcopy(master); value[key] = "0" * 64; changes.append(value)
        for key in ("expected_candidate_executions", "expected_reference_executions", "expected_total_executions"):
            value = copy.deepcopy(master); value[key] += 1; changes.append(value)
        value = copy.deepcopy(master); value["expected_candidate_ids"] = []; changes.append(value)
        value = copy.deepcopy(master); value["references"]["swarm004"]["expected_ids"] = []; changes.append(value)
        value = copy.deepcopy(master); value["references"]["swarm005"]["policies"].pop(); changes.append(value)
        value = copy.deepcopy(master); value["references"]["swarm005"]["build"]["binary_sha256"] = "0" * 64; changes.append(value)
        value = copy.deepcopy(master); value["primary"]["before"]["variant"] = "swarm006"; changes.append(value)
        value = copy.deepcopy(master); value["required_parity"].pop(); changes.append(value)
        value = copy.deepcopy(master); value["cases_sha256"] = "0" * 64; changes.append(value)
        value = copy.deepcopy(master); value["controls"] = True; changes.append(value)
        for value in changes:
            with self.assertRaises(ValueError): refs.validate_plan(value, registration, receipt, identities, hashes)

    @mock.patch.object(refs.runner, "FRESH_EXCLUDED_SEEDS", frozenset())
    def test_reference_cannot_use_another_harness_or_conditional_controls(self):
        master, registration, receipt, identities, hashes = fixture()
        identities["swarm004"]["harness_sha256"] = "0" * 64
        with self.assertRaises(ValueError): refs.validate_plan(master, registration, receipt, identities, hashes)
        master, registration, receipt, identities, hashes = fixture()
        registration["controls"] = True; master["candidate_registration"] = copy.deepcopy(registration)
        with self.assertRaises(ValueError): refs.validate_plan(master, registration, receipt, identities, hashes)

    def test_failed_reference_child_cannot_authorize_but_keeps_every_byte(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); binary = root / "binary"; binary.write_bytes(b"not executed")
            registration_path = root / "registration.json"; registration_path.write_bytes(b"{}")
            case = {"fixture": "island", "profile": "industrial", "seed": 605}
            ids = refs.execution_ids([case], refs.REFERENCE_POLICIES["swarm004"])
            receipt = {"binary": str(binary), "binary_sha256": refs.runner.sha(binary), "source_commit": "a" * 40}
            identity = {"build_receipt_sha256": "b" * 64}
            ctx = {"receipts": {"swarm004": receipt}, "identities": {"swarm004": identity}, "cases": [case],
                "builds": {"swarm004": root / "build"}, "registration": {"timeout_seconds": 90},
                "master": {"references": {"swarm004": {"expected_ids": ids}}}, "master_sha256": "c" * 64,
                "paths": {"registration": registration_path}, "raw": {"registration": b"{}"},
                "hashes": {"helper_runner_sha256": "d" * 64, "wrapper_sha256": "e" * 64, "candidate_registration_sha256": "f" * 64}}
            raw = json.dumps({"input": {}, "source": "a" * 40, "status": "complete", "can_apply": True,
                "metrics": {"still_required": 0}, "obligations": [], "cells": [3], "joints": [], "rounds": []}).encode()
            def execute(command, log, timeout):
                destination = Path(command[2]); destination.mkdir()
                (destination / "request-envelope.json").write_text('{"input": {}}')
                (destination / "response-native.json").write_bytes(raw)
                log.write_text("failed child\n")
                return {"returncode": 3, "cancelled": False, "timed_out": False}
            output = root / "evidence"
            with mock.patch.object(refs.runner, "execute", side_effect=execute), \
                    mock.patch.object(refs, "build_identity", return_value=(identity, receipt)), mock.patch("builtins.print"):
                result = refs.execute_reference(ctx, "swarm004", output)
            self.assertEqual("FAIL", result["result"]); self.assertEqual(1, result["retained_executions"])
            row = result["records"][0]
            self.assertFalse(row["can_apply"]); self.assertIn("evidence_error", row)
            self.assertEqual(raw, gzip.decompress((output / ids[0] / row["storage"]["response-native.json"]["file"]).read_bytes()))
            self.assertIn("request.json", row["storage"])
            analyzed = refs.endpoint_rows(output, result, "a" * 40, "off")[("island", "industrial", 605)]
            self.assertFalse(analyzed["A"]); self.assertFalse(analyzed["R"])
            self.assertIsNone(analyzed["still_required"]); self.assertIsNone(analyzed["qualified_joints"])
            self.assertFalse(analyzed["closure_evaluated"])
            (output / ids[0] / row["storage"]["response-native.json"]["file"]).write_bytes(b"corrupted")
            with self.assertRaises(ValueError): refs.endpoint_rows(output, result, "a" * 40, "off")

    def test_missing_response_stays_negative_with_unknown_native_counts(self):
        row = {"id": "missing", "fixture": "island", "profile": "industrial", "seed": 605,
            "policy": "both", "rounds": 2, "status": "execution_failed", "storage": {},
            "execution": {"returncode": -9, "timed_out": True, "cancelled": False}}
        result = refs.endpoint_rows(Path("unused"), {"records": [row]}, "a" * 40, "both")
        value = result[("island", "industrial", 605)]
        self.assertFalse(value["A"]); self.assertFalse(value["R"])
        self.assertIsNone(value["qualified_joints"]); self.assertIsNone(value["still_required"])
        self.assertFalse(value["closure_evaluated"]); self.assertTrue(value["failure_reason"])
        row.update({"status": "complete", "execution": {"returncode": 0, "timed_out": False, "cancelled": False}})
        with self.assertRaises(ValueError): refs.endpoint_rows(Path("unused"), {"records": [row]}, "a" * 40, "both")

    def test_final_custody_rejects_midrun_wrapper_or_helper_change(self):
        ctx = {"hashes": {"wrapper_sha256": "a" * 64, "helper_runner_sha256": "b" * 64},
               "paths": {}, "raw": {}, "builds": {}, "identities": {}}
        with mock.patch.object(refs.runner, "sha", side_effect=["a" * 64, "b" * 64]):
            self.assertTrue(refs.custody(ctx))
        with mock.patch.object(refs.runner, "sha", return_value="c" * 64):
            self.assertFalse(refs.custody(ctx))
        with mock.patch.object(refs.runner, "sha", side_effect=["a" * 64, "c" * 64]):
            self.assertFalse(refs.custody(ctx))

    def test_failed_campaign_requires_all_identified_rows_and_custody(self):
        master, registration, receipt, identities, hashes = fixture()
        ctx = {"master": master, "registration": registration, "identities": identities, "hashes": hashes,
               "cases": registration["cases"], "policies": [(p["name"], p["rounds"]) for p in registration["policies"]]}
        variant = "swarm004"
        ids = master["references"][variant]["expected_ids"]
        value = {"result": "FAIL", "variant": variant, "source": identities[variant]["source_commit"],
            "build_receipt_sha256": identities[variant]["build_receipt_sha256"], "runner_sha256": hashes["helper_runner_sha256"],
            "registration_sha256": hashes["candidate_registration_sha256"], "cases": ctx["cases"],
            "policies": refs.REFERENCE_POLICIES[variant], "records": [{"id": item} for item in ids],
            "expected_executions": len(ids), "retained_executions": len(ids), "master_sha256": "c" * 64,
            "wrapper_sha256": hashes["wrapper_sha256"], "source_custody_revalidated": True,
            "binary_custody_revalidated": True, "registration_custody_revalidated": True}
        ctx["master_sha256"] = "c" * 64
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary); manifest = path / "manifest.json"
            manifest.write_text(json.dumps(value)); self.assertEqual("FAIL", refs.campaign(ctx, path, variant)["result"])
            for key in ("source_custody_revalidated", "binary_custody_revalidated", "registration_custody_revalidated"):
                changed = copy.deepcopy(value); changed["result"] = "PASS"; changed[key] = False
                manifest.write_text(json.dumps(changed))
                with self.assertRaises(ValueError): refs.campaign(ctx, path, variant)
            changed = copy.deepcopy(value); changed["records"] = []; manifest.write_text(json.dumps(changed))
            with self.assertRaises(ValueError): refs.campaign(ctx, path, variant)


if __name__ == "__main__":
    unittest.main(verbosity=2)
