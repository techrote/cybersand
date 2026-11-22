#!/usr/bin/env python3
"""Evidence custody and bounded CLI parser tests, never a research corpus."""
from __future__ import annotations

import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from reciprocal_gallery import read_record
from run_reciprocal import CompressionWorker, atomic_json


class CompressionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="sw4-evidence-test-")
        self.root = Path(self.temporary.name)

    def tearDown(self):
        self.temporary.cleanup()

    def completed(self, name="case.json"):
        raw = json.dumps({"cells": [0, 1, 13, 27, 131] * 200, "failed_reason": "retained negative"}).encode()
        (self.root / name).write_bytes(raw)
        atomic_json(self.root / "campaign.json", {"records": [{"file": name}, {"file": name}]})
        return raw

    def test_duplicate_views_compress_once_with_verified_original_bytes(self):
        raw = self.completed()
        worker = CompressionWorker(self.root)
        worker.start()
        worker.finish()
        self.assertFalse(worker.thread.is_alive())
        self.assertFalse((self.root / "case.json").exists())
        self.assertEqual(gzip.decompress((self.root / "case.json.gz").read_bytes()), raw)
        receipt = json.loads((self.root / "storage.json").read_text())
        self.assertIsNone(receipt["error"])
        self.assertEqual(len(receipt["records"]), 1)
        self.assertEqual(receipt["records"]["case.json"]["raw_sha256"], hashlib.sha256(raw).hexdigest())
        restored, digest = read_record(self.root, "case.json", receipt["records"])
        self.assertEqual(restored, json.loads(raw))
        self.assertEqual(digest, hashlib.sha256(raw).hexdigest())

    def test_directory_alias_preserves_relative_storage_and_verified_bytes(self):
        raw = self.completed()
        with tempfile.TemporaryDirectory(prefix="sw4-evidence-alias-") as directory:
            alias = Path(directory) / "evidence"
            if sys.platform == "win32":
                subprocess.run(["cmd", "/d", "/c", "mklink", "/J", str(alias), str(self.root.resolve())],
                               check=True, capture_output=True, text=True)
            else:
                alias.symlink_to(self.root.resolve(), target_is_directory=True)
            self.assertNotEqual(alias, self.root.resolve())
            self.assertEqual(alias.resolve(), self.root.resolve())
            worker = CompressionWorker(alias)
            worker.start()
            worker.finish()
            self.assertFalse(worker.thread.is_alive())
            self.assertFalse((self.root / "case.json").exists())
            packed = self.root / "case.json.gz"
            self.assertEqual(gzip.decompress(packed.read_bytes()), raw)
            receipt = json.loads((self.root / "storage.json").read_text())
            self.assertIsNone(receipt["error"])
            self.assertEqual(len(receipt["records"]), 1)
            record = receipt["records"]["case.json"]
            self.assertEqual(record["file"], "case.json.gz")
            self.assertEqual(record["raw_bytes"], len(raw))
            self.assertEqual(record["compressed_sha256"], hashlib.sha256(packed.read_bytes()).hexdigest())
            restored, digest = read_record(alias, "case.json", receipt["records"])
            self.assertEqual(restored, json.loads(raw))
            self.assertEqual(digest, hashlib.sha256(raw).hexdigest())

    def test_storage_hash_detects_tampered_native_arrays(self):
        raw = self.completed()
        with gzip.open(self.root / "case.json.gz", "wb") as stream:
            stream.write(raw.replace(b"retained negative", b"altered evidence"))
        (self.root / "case.json").unlink()
        with self.assertRaisesRegex(ValueError, "hash mismatch"):
            read_record(self.root, "case.json", {"case.json": {"raw_sha256": hashlib.sha256(raw).hexdigest()}})

    def test_existing_archive_is_not_overwritten_or_original_deleted(self):
        raw = self.completed()
        (self.root / "case.json.gz").write_bytes(b"old archive")
        worker = CompressionWorker(self.root)
        worker.start()
        with self.assertRaisesRegex(RuntimeError, "Unexpected existing"):
            worker.finish()
        self.assertEqual((self.root / "case.json").read_bytes(), raw)
        self.assertEqual((self.root / "case.json.gz").read_bytes(), b"old archive")

    def test_cancel_retains_uncompressed_evidence_and_stops_worker(self):
        raw = self.completed()
        worker = CompressionWorker(self.root)
        worker.start()
        worker.finish(drain=False)
        self.assertFalse(worker.thread.is_alive())
        self.assertEqual((self.root / "case.json").read_bytes(), raw)
        self.assertEqual(json.loads((self.root / "storage.json").read_text())["records"], {})

    def test_path_escape_is_rejected(self):
        atomic_json(self.root / "campaign.json", {"records": [{"file": "../foreign.json"}]})
        worker = CompressionWorker(self.root)
        worker.start()
        with self.assertRaisesRegex(RuntimeError, "escapes"):
            worker.finish()
        with self.assertRaisesRegex(ValueError, "escaped"):
            read_record(self.root, "../foreign.json", {})

    def test_incomplete_index_does_not_publish_or_delete_records(self):
        raw = self.completed()
        (self.root / "campaign.json").write_text('{"records":[')
        worker = CompressionWorker(self.root)
        worker.start()
        worker.finish()
        self.assertEqual((self.root / "case.json").read_bytes(), raw)
        self.assertEqual(worker.records, {})


class RequestParserTests(unittest.TestCase):
    binary = None

    def setUp(self):
        if self.binary is None:
            self.skipTest("pass --binary after building the native CLI")
        self.temporary = tempfile.TemporaryDirectory(prefix="sw4-request-test-")
        self.root = Path(self.temporary.name)
        self.width, self.height = 64, 48
        self.header = ["SWARM004", "1", "64", "48", "605", "-2048", "4096", "0", "13", "-1",
                       "industrial", "0.45", "0.2", "0.1", "0", "0.5", "0.5", "0.6", "1", "0"]
        self.cells = [[int(x < 32), int(x >= 32), 0, int(min(abs(x - 31), abs(x - 32)) <= 13), 0]
                      for _y in range(self.height) for x in range(self.width)]
        self.serial = 0

    def tearDown(self):
        if hasattr(self, "temporary"):
            self.temporary.cleanup()

    def payload(self, header=None, cells=None):
        return " ".join(header or self.header) + "\n" + "\n".join(" ".join(map(str, row)) for row in cells or self.cells) + "\n"

    def invoke(self, payload):
        self.serial += 1
        source, output = self.root / f"request{self.serial}.txt", self.root / f"output{self.serial}.json"
        source.write_text(payload)
        process = subprocess.run([str(self.binary), "request", str(source), str(output), "request-parser-test"],
                                 capture_output=True, text=True, timeout=30)
        return process, output

    def test_protocol_reaches_native_coordinator_with_exact_fields(self):
        process, output = self.invoke(self.payload())
        self.assertIn(process.returncode, (0, 1))  # native rejection is a retained result
        document = json.loads(output.read_text())
        self.assertEqual(document["schema"], 5)
        self.assertEqual(document["source"], "request-parser-test")
        frame, mosaic = document["input"]["frame"], document["input"]["mosaic"]
        self.assertEqual(frame["seed"], 605)
        self.assertEqual(frame["origin"], [-2048, 4096])
        self.assertEqual(frame["transition"], document["input"]["shared_zone"])
        self.assertEqual(mosaic["limits"]["instances"], 192)
        self.assertEqual(frame["context"], [0] * (64 * 48))
        if document["status"] != "complete":
            self.assertFalse(document["can_apply"])

    def test_out_of_range_and_nonfinite_header_fields(self):
        invalid = {0: "SWARM003", 1: "3", 2: "257", 3: "129", 4: "18446744073709551616",
                   5: "-1000001", 6: "1000001", 7: "5", 8: "14", 9: "2", 10: "arbitrary_profile",
                   11: "nan", 12: "inf", 13: "-0.1", 14: "1.1", 18: "2", 19: "17"}
        for index, value in invalid.items():
            with self.subTest(index=index, value=value):
                header = self.header.copy()
                header[index] = value
                process, output = self.invoke(self.payload(header=header))
                self.assertEqual(process.returncode, 2)
                self.assertFalse(output.exists())

    def version_two_header(self, mosaic=None, sharing="1"):
        header = self.header.copy()
        header[1] = "2"
        header[19:19] = list(mosaic or self.header[11:18]) + [sharing]
        return header

    def test_v2_linked_controls_are_exactly_v1_equivalent(self):
        old_process, old_output = self.invoke(self.payload())
        new_process, new_output = self.invoke(self.payload(header=self.version_two_header()))
        self.assertEqual(old_process.returncode, new_process.returncode)
        self.assertEqual(json.loads(old_output.read_text()), json.loads(new_output.read_text()))

    def test_v2_per_gentek_values_and_fixed_ownership_preserve_transition(self):
        changed = ["0.9", "0.8", "0.7", "0", "0.6", "0.4", "0.2"]
        _, original_output = self.invoke(self.payload())
        process, output = self.invoke(self.payload(header=self.version_two_header(changed, "0")))
        self.assertIn(process.returncode, (0, 1))
        original = json.loads(original_output.read_text())
        document = json.loads(output.read_text())
        frame, mosaic = document["input"]["frame"], document["input"]["mosaic"]
        keys = ["variation", "irregularity", "clutter", "destruction", "branching", "environment_affinity", "cohesion"]
        self.assertEqual(frame["profile"], original["input"]["frame"]["profile"])
        self.assertEqual([mosaic["profile"][key] for key in keys], list(map(float, changed)))
        self.assertFalse(document["input"]["options"]["shared_ownership"])
        self.assertEqual(document["input"]["shared_zone"], [0] * (64 * 48))
        self.assertTrue(any(frame["transition"]))
        for gentek in ("frame", "mosaic"):
            for field in ("transition", "eligible", "limits", "context", "protected"):
                self.assertEqual(document["input"][gentek][field], original["input"][gentek][field])

    def test_v2_independent_controls_are_strict_and_bounded(self):
        for offset, value in [(0, "nan"), (1, "inf"), (2, "-0.01"), (3, "1.01"),
                              (4, "true"), (5, "missing"), (6, "1.1"), (7, "2")]:
            with self.subTest(offset=offset, value=value):
                header = self.version_two_header()
                header[19 + offset] = value
                process, output = self.invoke(self.payload(header=header))
                self.assertEqual(process.returncode, 2)
                self.assertFalse(output.exists())

    def test_invalid_masks_materials_and_trailing_data(self):
        for replacement in ([2, 0, 0, 0, 0], [1, 1, 0, 0, 0], [1, 0, 2, 0, 0],
                            [1, 0, 0, 2, 0], [1, 0, 0, 0, 10], [1, 0, 0, 0, 132]):
            with self.subTest(cell=replacement):
                cells = self.cells.copy()
                cells[0] = replacement
                process, output = self.invoke(self.payload(cells=cells))
                self.assertEqual(process.returncode, 2)
                self.assertFalse(output.exists())
        for payload in (self.payload() + "trailing", "x" * (2 * 1024 * 1024 + 1), self.payload()[:-10]):
            process, output = self.invoke(payload)
            self.assertEqual(process.returncode, 2)
            self.assertFalse(output.exists())

    def test_native_shared_extent_cannot_be_spoofed(self):
        cells = [[a, b, protected, 1, material] for a, b, protected, _shared, material in self.cells]
        process, output = self.invoke(self.payload(cells=cells))
        self.assertEqual(process.returncode, 1)
        document = json.loads(output.read_text())
        self.assertEqual(document["status"], "invalid")
        self.assertIn("interface", document["reason"])
        self.assertFalse(document["can_apply"])


if __name__ == "__main__":
    if "--binary" in sys.argv:
        index = sys.argv.index("--binary")
        RequestParserTests.binary = Path(sys.argv[index + 1]).resolve()
        del sys.argv[index:index + 2]
    unittest.main()
