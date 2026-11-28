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


def header_refusal_fixture():
    # Small representation of the actual native preflight refusal contract;
    # values come from an exhausted max-bytes request, never a passing fixture.
    owner = {"gentek": "FRAMEWEAVER", "version": 0, "source": "a" * 40, "definition": "definition",
        "fixture": "workbench_territory", "seed": 605, "width": 3, "height": 1, "origin": [0, 0],
        "profile": {"name": "industrial", "clutter": 0.35}, "limits": {"work": 2000000, "bytes": 1024},
        "activation": [[1, 0]], "eligible": [1, 1, 0], "protected": [0, 0, 0], "transition": [0, 0, 0],
        "context": [0, 0, 0], "neighbor_cells": [3],
        "neighbors": {"hard": [1], "soft": [], "protected": [], "transition": []}}
    request = {"frame": copy.deepcopy(owner), "mosaic": copy.deepcopy(owner),
        "shared_zone": [0, 1, 0], "options": {"negotiated_recovery": True, "rounds": 4}}
    request["mosaic"]["gentek"] = "MOSAIC"
    header = copy.deepcopy(request); header["shared_zone"] = []
    for side in ("frame", "mosaic"):
        for key in ("activation", "eligible", "protected", "transition", "context", "neighbor_cells"):
            header[side][key] = []
        header[side]["neighbors"] = {key: [] for key in ("hard", "soft", "protected", "transition")}
    empty = {"gentek": "FRAMEWEAVER", "implementation": "", "definition": "", "source": "", "seed": 0,
        "status": "complete", "termination": "complete", "request_digest": "0000000000000000",
        "material_digest": "0000000000000000", "digest": "0000000000000000", "width": 0, "height": 0,
        "work": 0, "candidates": 0, "solver_work": 0, "backtracks": -1, "protected_violations": 0,
        "illegal_overlaps": 0, "unresolved_joints": 0, "metrics": {}, "rejected": {}, "notes": [],
        "cells": [], "roles": [], "provenance": [], "instances": [], "connectors": [], "attachments": [],
        "boundary": {"hard": [], "soft": [], "protected": [], "transition": []}}
    value = {"input": header, "status": "exhausted", "can_apply": False, "source": "a" * 40,
        "digest": "0000000000000000", "metrics": {"input_header_only": 1, "frame_work": 0, "total_charged_work": 0},
        "rounds": [], "cells": [], "ledger": [], "rules": [], "obligations": [], "joints": [], "rejections": [],
        "damage_derivative": None, "original_frame": {"core": copy.deepcopy(empty), "result": copy.deepcopy(empty),
            "slots": [], "reservation_rejections": [], "source_feasibility": []}}
    return request, value


class EvidenceTests(unittest.TestCase):
    def test_header_refusal_preserves_full_original_request(self):
        request, value = header_refusal_fixture(); original = copy.deepcopy(request)
        self.assertEqual("bounded_header_refusal", runner.verify_native_input(request, value))
        self.assertEqual(original, request)
        row = runner.reduce_result(value)
        self.assertFalse(row["can_apply"])
        self.assertIsNone(row["still_required"])
        self.assertEqual(0, row["native_material_cells"])

    def test_header_refusal_cannot_change_identity_limits_or_input_shape(self):
        request, value = header_refusal_fixture()
        mutations = [(("input", "frame", "source"), "forged"), (("input", "mosaic", "seed"), 606),
            (("input", "frame", "limits", "work"), 2000001), (("input", "frame", "limits", "bytes"), 1024.0),
            (("input", "mosaic", "profile", "clutter"), 0.5), (("input", "options", "rounds"), 3),
            (("input", "frame", "origin"), [1, 0]), (("input", "frame", "eligible"), [0]),
            (("input", "frame", "neighbors", "hard"), [1]), (("input", "shared_zone"), [0]),
            (("source",), "forged"), (("digest",), "1111111111111111")]
        for path, replacement in mutations:
            changed = copy.deepcopy(value); parent = changed
            for key in path[:-1]: parent = parent[key]
            parent[path[-1]] = replacement
            with self.subTest(path=path), self.assertRaises(ValueError): runner.verify_native_input(request, changed)
        changed = copy.deepcopy(value); del changed["input"]["frame"]["activation"]
        with self.assertRaises(ValueError): runner.verify_native_input(request, changed)

    def test_header_refusal_cannot_hide_work_outputs_or_authorization(self):
        request, value = header_refusal_fixture()
        bad = []
        for status in ("complete", "blocked", "cancelled"):
            changed = copy.deepcopy(value); changed["status"] = status; bad.append(changed)
        for flag in (None, 0, True, 2):
            changed = copy.deepcopy(value); changed["metrics"]["input_header_only"] = flag; bad.append(changed)
        changed = copy.deepcopy(value); changed["can_apply"] = True; bad.append(changed)
        changed = copy.deepcopy(value); changed["metrics"]["frame_work"] = 1; bad.append(changed)
        for name in ("rounds", "cells", "ledger", "rules", "obligations", "joints", "rejections"):
            changed = copy.deepcopy(value); changed[name] = [0]; bad.append(changed)
        changed = copy.deepcopy(value); changed["damage_derivative"] = {}; bad.append(changed)
        changed = copy.deepcopy(value); changed["original_frame"]["result"]["cells"] = [3]; bad.append(changed)
        changed = copy.deepcopy(value); changed["original_frame"]["core"]["work"] = 1; bad.append(changed)
        changed = copy.deepcopy(value); changed["original_frame"]["slots"] = [{}]; bad.append(changed)
        for changed in bad:
            with self.assertRaises(ValueError): runner.verify_native_input(request, changed)

    def test_full_native_input_remains_exact_without_header_exception(self):
        request, value = header_refusal_fixture()
        value["input"] = copy.deepcopy(request); value["metrics"]["input_header_only"] = 0
        self.assertEqual("full_exact", runner.verify_native_input(request, value))
        value["input"]["frame"]["limits"]["bytes"] = 1024.0
        with self.assertRaises(ValueError): runner.verify_native_input(request, value)

    def test_rejected_native_header_still_retains_original_request_and_response(self):
        request, value = header_refusal_fixture()
        value["input"]["frame"]["seed"] = 606
        response_bytes = json.dumps(value).encode() + b"\n"
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); build = root / "build"; build.mkdir()
            binary = build / "unused-binary"; binary.write_bytes(b"not executed")
            receipt = {"result": "PASS", "variant": "swarm006", "binary": str(binary),
                "binary_sha256": runner.sha(binary), "source_root": str(root / "source"),
                "source_commit": "a" * 40, "source_dirty": "", "source_inputs": {}}
            (build / "build.json").write_text(json.dumps(receipt))
            args = SimpleNamespace(build=build, out=root / "evidence", registration=None,
                suite="development", policy=["recovery+memory_budget@4"], controls=False, timeout=None)
            def execute(command, log, timeout):
                destination = Path(command[2]); destination.mkdir()
                (destination / "request-envelope.json").write_text(json.dumps({"input": request}))
                (destination / "response-native.json").write_bytes(response_bytes)
                log.write_text("malformed header fixture\n")
                return {"returncode": 0, "cancelled": False, "timed_out": False}
            case = {"fixture": "island", "profile": "industrial", "seed": 605}
            with mock.patch.object(runner, "cases", return_value=[case]), \
                    mock.patch.object(runner, "execute", side_effect=execute), \
                    mock.patch.object(runner, "source_inputs", return_value={}), mock.patch("builtins.print"):
                self.assertEqual(1, runner.run(args))
            manifest = json.loads((args.out / "manifest.json").read_text()); row = manifest["records"][0]
            self.assertEqual("FAIL", manifest["result"])
            self.assertFalse(row["can_apply"])
            self.assertIn("evidence_error", row)
            self.assertEqual(hashlib.sha256(runner.canonical(request)).hexdigest(), row["request_sha256"])
            directory = args.out / row["id"]
            stored_request = row["storage"]["request.json"]
            self.assertEqual(request, json.loads(gzip.decompress((directory / stored_request["file"]).read_bytes())))
            stored_response = row["storage"]["response-native.json"]
            self.assertEqual(response_bytes, gzip.decompress((directory / stored_response["file"]).read_bytes()))
            self.assertEqual(hashlib.sha256(response_bytes).hexdigest(), stored_response["raw_sha256"])

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
