from __future__ import annotations

import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

from experiments.driv3r import provenance


class RequestTests(unittest.TestCase):
    def test_exact_request_admitted(self):
        request = {**provenance.REQUEST_FIELDS, "sequence": 1}
        self.assertEqual(provenance.validate_request(request), request)

    def test_unsafe_scope_changes_refused(self):
        for key, value in (("training", True), ("schedules", True),
                           ("stage", "B"), ("quantization", "Q4_K_M"),
                           ("foundation_sha", "0" * 40),
                           ("production_defaults", True)):
            with self.subTest(key=key), self.assertRaises(ValueError):
                provenance.validate_request({**provenance.REQUEST_FIELDS, "sequence": 1, key: value})

    def test_request_types_and_extra_fields_refused(self):
        for sequence in (True, False, 1.0, "1", 0, 1001):
            with self.subTest(sequence=sequence), self.assertRaises(ValueError):
                provenance.validate_request({**provenance.REQUEST_FIELDS, "sequence": sequence})
        with self.assertRaises(ValueError):
            provenance.validate_request({**provenance.REQUEST_FIELDS, "sequence": 1, "override": True})
        with self.assertRaises(ValueError):
            provenance.validate_request({**provenance.REQUEST_FIELDS, "sequence": 1, "training": 0})


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.evidence = self.root / "evidence"
        self.evidence.mkdir()
        self.source = "a" * 40
        self.custody = {"schema": "driv3r-source-custody-v1", "source_sha": self.source,
                        "source_tree": "b" * 40, "source_inputs": {"test.py": "c" * 64}}
        self.custody["source_inputs_sha256"] = hashlib.sha256(provenance.canonical(self.custody["source_inputs"])).hexdigest()
        provenance.write_json(self.evidence / "source-custody.json", self.custody)
        (self.evidence / "failure.json").write_text('{"gate":"A2","status":"FAIL","raw_error":"original"}\n')
        (self.evidence / "native.png").write_bytes(b"original-PNG-fixture-bytes")

    def tearDown(self):
        self.temporary.cleanup()

    def test_inventory_detects_changed_and_added_bytes(self):
        inventory = provenance.inventory(self.evidence)
        provenance.verify_inventory(self.evidence, inventory)
        (self.evidence / "native.png").write_bytes(b"changed")
        with self.assertRaises(ValueError):
            provenance.verify_inventory(self.evidence, inventory)

    def test_inventory_refuses_symlinks(self):
        (self.evidence / "link").symlink_to(self.evidence / "native.png")
        with self.assertRaises(ValueError):
            provenance.inventory(self.evidence)

    def test_package_retains_original_failure_and_readback_bytes(self):
        output = self.root / "release"
        manifest = provenance.package(self.evidence, output, self.source)
        self.assertFalse(manifest["publication_is_acceptance"])
        self.assertTrue(manifest["draft_hold"])
        archive = output / manifest["assets"][0]["file"]
        self.assertEqual(provenance.digest(archive), manifest["assets"][0]["sha256"])
        with zipfile.ZipFile(archive) as stored:
            self.assertEqual(stored.read("native.png"), (self.evidence / "native.png").read_bytes())
            self.assertEqual(json.loads(stored.read("failure.json"))["status"], "FAIL")
            self.assertEqual(json.loads(stored.read("EVIDENCE-INVENTORY.json")), provenance.inventory(self.evidence))
        with self.assertRaises(ValueError):
            provenance.package(self.evidence, output, self.source)

    def test_package_refuses_wrong_source_and_nested_output(self):
        with self.assertRaises(ValueError):
            provenance.package(self.evidence, self.root / "release", "d" * 40)
        with self.assertRaises(ValueError):
            provenance.package(self.evidence, self.evidence / "release", self.source)

    def test_package_refuses_corrupt_source_inventory(self):
        self.custody["source_inputs"]["test.py"] = "f" * 64
        (self.evidence / "source-custody.json").write_text(json.dumps(self.custody))
        with self.assertRaises(ValueError):
            provenance.package(self.evidence, self.root / "release", self.source)

    def test_package_refuses_reserved_inventory(self):
        (self.evidence / "EVIDENCE-INVENTORY.json").write_text('{}')
        with self.assertRaises(ValueError):
            provenance.package(self.evidence, self.root / "release", self.source)


if __name__ == "__main__":
    unittest.main()
