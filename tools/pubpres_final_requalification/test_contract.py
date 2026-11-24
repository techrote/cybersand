#!/usr/bin/env python3
"""Adversarial checks for retained application/new qualifier separation."""
import ast
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import contract
from restore_artifacts import extract_exact, validate_metadata


class ExecutionCustodyTests(unittest.TestCase):
    def test_exact_derivations_keep_physical_and_runtime_gates(self):
        for role, record in contract.FROZEN.items():
            raw = (contract.ROOT / record["path"]).read_bytes()
            for function in record["functions"]:
                derived = contract.derive(role, function, raw)
                ast.parse(derived)
                self.assertIn("_registered_source(source,", derived)
                self.assertIn("_registered_runtime(source)", derived)
                self.assertIn("_registered_engine(", derived)
                self.assertIn("execution_registration", derived)
                with self.assertRaises(ValueError):
                    contract.derive(role, function, raw.replace(b'physical_acceptance', b'physical_acceptancX', 1))
            # A changed unrelated helper is also rejected by the whole-file pin.
            with self.assertRaises(ValueError):
                contract.derive(role, "main", raw + b"\n# unregistered qualifier\n")
        renderer = contract.derive("renderer", "main", (contract.ROOT / contract.FROZEN["renderer"]["path"]).read_bytes())
        for predicate in ("validate_runtime(", "verify_qualification(", "validate_two_slot_oracle(",
                          "validate_requested_renderer(", "validate_deadline_off(", "reduce_receipt(",
                          "validate_observers(", "validate_draw_identity(", "validate_slot_treatment(",
                          "validate_cohort("):
            self.assertIn(predicate, renderer)
        self.assertIn('need(os.name=="nt"', renderer)
        self.assertIn('identity["build_source"]==source["source_commit"]', renderer)

    def test_application_and_current_qualifier_are_distinct_and_exact(self):
        source = {"source_commit": contract.APPLICATION, "source_tree": contract.APPLICATION_TREE}
        driver = {"source_commit": "d" * 40, "source_tree": "e" * 40}
        with patch.object(contract, "git", side_effect=lambda *a, **kw: "e" * 40 if a[-1] == "HEAD^{tree}" else "d" * 40):
            contract.registered_source(source, driver)
            for target, key in ((source, "source_commit"), (source, "source_tree"), (driver, "source_commit"), (driver, "source_tree")):
                changed = copy.deepcopy(target)
                changed[key] = "f" * 40
                with self.assertRaises(ValueError):
                    contract.registered_source(changed if target is source else source, changed if target is driver else driver)
        with patch.object(contract, "git", side_effect=lambda *a, **kw: contract.APPLICATION_TREE if a[-1] == "HEAD^{tree}" else contract.APPLICATION):
            with self.assertRaises(ValueError):
                contract.registered_source(source, source)

    def test_runtime_and_external_engine_identity_are_exact(self):
        source = {"native_runtime": {"binary_sha256": contract.RUNTIME_SHA, "manifest_sha256": contract.RUNTIME_MANIFEST_SHA}}
        contract.registered_runtime(source)
        for key in source["native_runtime"]:
            changed = copy.deepcopy(source)
            changed["native_runtime"][key] = "0" * 64
            with self.assertRaises(ValueError):
                contract.registered_runtime(changed)
        contract.registered_engine(contract.ENGINE_IDENTITY)
        for key in contract.ENGINE_IDENTITY:
            changed = copy.deepcopy(contract.ENGINE_IDENTITY)
            changed[key] = 2 if type(changed[key]) is int else "0" * len(changed[key])
            with self.assertRaises(ValueError):
                contract.registered_engine(changed)

    def test_artifact_metadata_rejects_wrong_source_run_or_archive(self):
        expected = contract.registration()["artifacts"]["engine"]
        metadata = {"id": expected["id"], "expired": False, "size_in_bytes": expected["bytes"],
                    "digest": "sha256:" + expected["sha256"],
                    "workflow_run": {"id": expected["workflow_run"], "head_sha": expected["source_commit"]}}
        validate_metadata(metadata, expected)
        for path, value in ((["id"], 1), (["expired"], True), (["size_in_bytes"], 0),
                            (["digest"], "sha256:" + "0" * 64), (["workflow_run", "id"], 1),
                            (["workflow_run", "head_sha"], "0" * 40)):
            changed = copy.deepcopy(metadata)
            target = changed
            for key in path[:-1]:
                target = target[key]
            target[path[-1]] = value
            with self.assertRaises(ValueError):
                validate_metadata(changed, expected)

    def test_zip_namespace_and_bytes_are_checked_before_extraction(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            for index, names in enumerate((["valid/file.txt"], ["../escape.txt"], ["A.txt", "a.txt"], ["CON.txt"])):
                archive = base / f"{index}.zip"
                with zipfile.ZipFile(archive, "w") as z:
                    for name in names:
                        z.writestr(name, b"retained exact bytes\n")
                record = {"bytes": archive.stat().st_size, "sha256": hashlib.sha256(archive.read_bytes()).hexdigest()}
                target = base / str(index)
                if index == 0:
                    result = extract_exact(archive, target, record)
                    self.assertTrue(result["all_member_crcs_verified"])
                    self.assertEqual((target / names[0]).read_bytes(), b"retained exact bytes\n")
                    with self.assertRaises(ValueError):
                        extract_exact(archive, base / "wrong-hash", {**record, "sha256": "0" * 64})
                else:
                    with self.assertRaises((ValueError, RuntimeError)):
                        extract_exact(archive, target, record)
                    self.assertFalse(target.exists())


if __name__ == "__main__":
    unittest.main()
