#!/usr/bin/env python3
"""Evidence reducer tests: failed/unknown closure must never become success."""
import copy
import gzip
import hashlib
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

import run_swarm006 as runner


def sample(status="blocked", still=1):
    return {"status": status, "can_apply": status == "complete", "metrics": {"still_required": still},
            "obligations": [{"state": "STILL_REQUIRED"} for _ in range(still)],
            "cells": [0, 38, 3], "joints": [], "rounds": []}


def registration_fixture():
    # Deliberately use already revealed seed605, never choose any fresh holdout
    # data in a test. Successful schema tests explicitly mock the exclusion set.
    receipt = {"result": "PASS", "variant": "swarm006", "source_dirty": "", "allow_dirty_requested": False,
        "source_custody_revalidated": True, "source_commit": "a" * 40,
        "definition_sha256": "b" * 64, "harness_sha256": "c" * 64, "runner_sha256": "d" * 64}
    registration = {"schema": 1, "programme": "GENTEK-SWARM-006", "classification": "preregistered_unseen",
        "registration_id": "unit-test-only-not-a-registration",
        "candidate": {"git_sha": receipt["source_commit"], **{k: receipt[k] for k in ("definition_sha256", "harness_sha256", "runner_sha256")}},
        "limits": dict(runner.REGISTERED_LIMITS), "cases": [{"fixture": "island", "profile": "industrial", "seed": 605}],
        "policies": [{"name": "both", "rounds": 2, "role": "primary"}, {"name": "recovery", "rounds": 2, "role": "primary"}],
        "case_count": 1, "execution_count": 2, "controls": True, "timeout_seconds": 90}
    return registration, receipt


class EvidenceTests(unittest.TestCase):
    def test_registration_rejects_revealed_development_seeds(self):
        registration, receipt = registration_fixture()
        for seed in runner.FRESH_EXCLUDED_SEEDS:
            registration["cases"][0]["seed"] = seed
            with self.assertRaises(ValueError): runner.validate_registration(registration, receipt, "d" * 64)

    @mock.patch.object(runner, "FRESH_EXCLUDED_SEEDS", frozenset())
    def test_registration_requires_exact_clean_source_and_tools(self):
        registration, receipt = registration_fixture()
        cases, policies = runner.validate_registration(registration, receipt, "d" * 64)
        self.assertEqual(registration["cases"], cases)
        self.assertEqual([("both", 2), ("recovery", 2)], policies)
        for key, value in (("source_dirty", " M file"), ("allow_dirty_requested", True),
                           ("source_commit", "e" * 40), ("definition_sha256", "e" * 64),
                           ("harness_sha256", "e" * 64), ("runner_sha256", "e" * 64)):
            changed = dict(receipt); changed[key] = value
            with self.assertRaises(ValueError): runner.validate_registration(registration, changed, "d" * 64)

    @mock.patch.object(runner, "FRESH_EXCLUDED_SEEDS", frozenset())
    def test_registration_locks_envelope_policies_and_denominator(self):
        registration, receipt = registration_fixture()
        bad = []
        changed = copy.deepcopy(registration); changed["limits"]["shared_work"] += 1; bad.append(changed)
        changed = copy.deepcopy(registration); changed["policies"][1]["rounds"] = 5; bad.append(changed)
        changed = copy.deepcopy(registration); changed["policies"][1]["name"] = "recovery+unknown"; bad.append(changed)
        changed = copy.deepcopy(registration); changed["policies"][1]["role"] = "secondary"; bad.append(changed)
        changed = copy.deepcopy(registration); changed["cases"] *= 2; changed["case_count"] = 2; changed["execution_count"] = 4; bad.append(changed)
        changed = copy.deepcopy(registration); changed["execution_count"] = 1; bad.append(changed)
        changed = copy.deepcopy(registration); changed["cases"][0]["seed"] = True; bad.append(changed)
        changed = copy.deepcopy(registration); changed["cases"][0]["fixture"] = "unknown"; bad.append(changed)
        for value in bad:
            with self.assertRaises(ValueError): runner.validate_registration(value, receipt, "d" * 64)

    def test_registration_rejects_cli_overrides_before_creating_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); build = root / "build"; build.mkdir()
            binary = build / "unused-binary"; binary.write_bytes(b"not executed")
            receipt = {"result": "PASS", "variant": "swarm006", "binary": str(binary),
                "binary_sha256": runner.sha(binary), "source_root": str(root / "source")}
            (build / "build.json").write_text(json.dumps(receipt))
            defaults = dict(build=build, out=root / "evidence", registration=root / "never-read.json",
                            suite=None, policy=None, controls=False, timeout=None)
            for key, value in (("suite", "owner"), ("policy", ["recovery@2"]), ("controls", True), ("timeout", 1)):
                args = SimpleNamespace(**{**defaults, key: value})
                with self.assertRaises(ValueError): runner.run(args)
                self.assertFalse(args.out.exists())

    def test_exhaustion_does_not_infer_zero_foreign_requirements(self):
        value = sample("exhausted", 0)
        row = runner.reduce_result(value)
        self.assertIsNone(row["still_required"])
        self.assertIsNone(row["foreign_joined"])
        self.assertFalse(row["closure_evaluated"])
        self.assertFalse(row["can_apply"])

    def test_apply_requires_complete_and_consistent_native_ledger(self):
        for value in (sample("complete", 1), sample("blocked", 0), sample("exhausted", 0)):
            value["can_apply"] = True
            with self.assertRaises(ValueError): runner.reduce_result(value)
        value = sample("blocked", 1)
        value["obligations"] = []
        with self.assertRaises(ValueError): runner.reduce_result(value)

    def test_zero_joint_complete_is_not_implicitly_reciprocal(self):
        row = runner.reduce_result(sample("complete", 0))
        self.assertTrue(row["can_apply"])
        self.assertEqual(0, row["qualified_joints"])
        self.assertNotIn("causal_complete", row)

    def test_distributions_keep_unknown_closure_and_missing_work(self):
        rows = [runner.reduce_result(sample("complete", 0)), runner.reduce_result(sample("exhausted", 0)),
                {"status": "execution_failed", "can_apply": False}]
        summary = runner.distribution(rows)
        self.assertEqual({"complete": 1, "exhausted": 1, "execution_failed": 1}, summary["statuses"])
        self.assertEqual(2, summary["closure_unknown"])
        self.assertEqual({"0": 1, "None": 2}, summary["remaining_requirements"])
        self.assertEqual({"count": 0}, summary["work"]["frame_work"])
        self.assertEqual(1, summary["apply_valid"])
        self.assertEqual(0, summary["causal_complete"])

    def test_new_obligations_do_not_replace_original_deficits(self):
        value = sample("blocked", 1)
        value["obligations"].append({"origin": "new_assembly", "state": "FOREIGN_JOINED"})
        row = runner.reduce_result(value)
        self.assertEqual({"original_frame/STILL_REQUIRED": 1, "new_assembly/FOREIGN_JOINED": 1}, row["obligation_counts"])
        self.assertEqual(1, row["still_required"])

    def test_native_plane_is_exact_little_endian_uint16(self):
        self.assertEqual(hashlib.sha256(b"\x00\x00\x26\x00\x03\x00").hexdigest(), runner.cell_sha([0, 38, 3]))
        for bad in ([True], [1.0], [-1], [65536]):
            with self.assertRaises(ValueError): runner.cell_sha(bad)

    def test_compression_retains_every_original_byte(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "negative.json"
            raw = b'{"status":"exhausted","can_apply":false}\n' * 200
            path.write_bytes(raw)
            receipt = runner.compress_json(path)
            self.assertFalse(path.exists())
            self.assertEqual(raw, gzip.decompress((path.parent / receipt["file"]).read_bytes()))
            self.assertEqual(hashlib.sha256(raw).hexdigest(), receipt["raw_sha256"])

    def test_revealed_corpus_has_all_360_unique_executions(self):
        cases = runner.cases("revealed005")
        policies = runner.policies("swarm005", "revealed005", None)
        identities = {(v["fixture"], v["profile"], v["seed"], p, r) for v in cases for p, r in policies}
        self.assertEqual(360, len(identities))
        self.assertEqual(set(runner.REVEALED_005_SEEDS), {c["seed"] for c in cases})

    def test_controls_cannot_silently_expand_to_unknown_policies(self):
        for value in ("recovery", "recovery@5", "recovery@-1", "recovery@nan"):
            with self.assertRaises(ValueError): runner.policies("swarm006", "owner", [value])
        with self.assertRaises(ValueError): runner.policies("swarm006", "owner", ["off@2", "off@2"])

    def test_compatibility_preserves_geometry_work_and_obligations(self):
        request = {"source": "source-a", "definition": "native.aabb", "width": 1, "height": 1}
        native_result = {**request, "request_digest": "sourcebound1", "digest": "sourcebound2", "cells": [38], "work": 12}
        document = {"schema": 5, "type": "reciprocal_assembly", "source": "source-a",
            "input": {"frame": copy.deepcopy(request), "mosaic": copy.deepcopy(request), "options": {}},
            "original_frame": {"core": copy.deepcopy(native_result), "result": copy.deepcopy(native_result)},
            "rounds": [], "obligations": [{"state": "STILL_REQUIRED"}], "metrics": {"shared_work": 14}}
        normalized = runner.normalized_composition(document, "source-a", "aabb")
        for path, value in (("work", 11), ("cells", [0])):
            forged = copy.deepcopy(document)
            forged["original_frame"]["result"][path] = value
            self.assertNotEqual(normalized, runner.normalized_composition(forged, "source-a", "aabb"))
        changed = copy.deepcopy(document)
        changed["obligations"][0]["state"] = "FOREIGN_JOINED"
        self.assertNotEqual(normalized, runner.normalized_composition(changed, "source-a", "aabb"))
        with self.assertRaises(ValueError): runner.normalized_composition(document, "forged-source", "aabb")
        with self.assertRaises(ValueError): runner.normalized_composition(document, "source-a", "wrong-definition")
        self.assertEqual({}, document["input"]["options"])

    def test_compatibility_checks_compressed_and_uncompressed_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); folder = root / "case"; folder.mkdir()
            path = folder / "response-native.json"; path.write_text('{"status":"blocked"}\n')
            storage = runner.compress_json(path)
            row = {"id": "case", "storage": {"response-native.json": storage}}
            self.assertEqual({"status": "blocked"}, runner.retained_document(root, row))
            (folder / storage["file"]).write_bytes(gzip.compress(b'{"status":"complete"}'))
            with self.assertRaises(ValueError): runner.retained_document(root, row)

    def test_causal_controls_require_same_full_native_plans_and_inputs(self):
        initial = {"frame": {"result": {"cells": [3], "provenance": [1]}},
                   "mosaic": {"result": {"cells": [0], "provenance": [0]}, "categories": [0]},
                   "mosaic_request": {"eligible": [1], "limits": {"max_work": 20}}}
        candidate = {"input": {"options": {"negotiated_recovery": True, "recovery_offers": True, "mosaic_adaptation": True}},
                     "status": "blocked", "can_apply": False, "joints": [], "rounds": [initial, copy.deepcopy(initial)]}
        metadata = {"available": True, "mosaic_offer_causal_footprint": 0, "frame_offer_causal_footprint": 0,
                    "causal_both_with_joint": False, "causal_complete": False}
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for name, key in (("no-offer-native.json", "recovery_offers"), ("frozen-peer-native.json", "mosaic_adaptation")):
                control = copy.deepcopy(candidate); control["input"]["options"][key] = False
                (root / name).write_text(json.dumps(control))
            runner.verify_recovery_controls(candidate, root, metadata)
            self.assertEqual("PASS", metadata["full_native_control_validation"])
            path = root / "frozen-peer-native.json"; control = json.loads(path.read_text())
            control["rounds"][-1]["mosaic"]["categories"] = [1]
            path.write_text(json.dumps(control))
            with self.assertRaises(ValueError): runner.verify_recovery_controls(candidate, root, metadata)


if __name__ == "__main__":
    unittest.main(verbosity=2)
