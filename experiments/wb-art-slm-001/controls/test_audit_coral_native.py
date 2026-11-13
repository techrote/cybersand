"""Reader gate controls: synthetic fixtures are never counted as native evidence."""
import json
import os
from pathlib import Path
import tempfile
import unittest
import zipfile

import audit_coral_native as m


class CoralReceiptGate(unittest.TestCase):
    def test_frozen_source_and_gate_set(self):
        self.assertEqual(len(m.REQUIRED_GATES), 15)
        self.assertEqual(len(m.SOURCE), 40)
        self.assertEqual(len(m.NATIVE), 64)

    def test_forged_receipt_is_not_accepted(self):
        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder)/"forged.zip"
            with zipfile.ZipFile(archive, "w") as z:
                z.writestr("native_full_01/verified-admission-receipts.json", json.dumps({
                    "passed": True, "failures": [], "global_gates": {
                        k: True for k in m.REQUIRED_GATES},
                    "runtime": {"source_commit": m.SOURCE, "native_sha256": m.NATIVE},
                    "cases": []}))
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                m.analyze(archive)

    @unittest.skipUnless(os.environ.get("WB_ART_SLM_TEACHER_ARCHIVE"), "native evidence ZIP not mounted")
    def test_recovered_original_native_coral(self):
        result = m.analyze(Path(os.environ["WB_ART_SLM_TEACHER_ARCHIVE"]))
        self.assertEqual(result["case_count"], 16)
        self.assertEqual(result["nonborder_single_layer_top_empty"], 6)
        self.assertEqual(result["mean_top_fraction"], 0.104738)
        self.assertFalse(result["candidate_native_executed"])
        self.assertEqual(len({c["readback_sha256"] for c in result["cases"]}), 16)


if __name__ == "__main__":
    unittest.main()
