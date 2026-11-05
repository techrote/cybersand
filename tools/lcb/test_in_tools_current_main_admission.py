"""Adversarial tests for the #361 current-main successor source admission."""
from __future__ import annotations

import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools/lcb/in_tools_current_main_admission.py"
SPEC = importlib.util.spec_from_file_location("in_tools_current_main_admission", MODULE_PATH)
subject = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(subject)


class AdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.record = subject.parse_json(subject.RECORD.read_text(encoding="utf-8"))

    def test_current_checkout_and_minimal_authority(self) -> None:
        result = subject.check()
        self.assertEqual(result["status"], "admitted")
        self.assertEqual(result["adopted_main"], "ba9cbc89029be88b812af59b19e5c59829bbcd90")
        self.assertEqual(result["authority_count"], 11)
        self.assertEqual(result["planned_count"], 6)
        self.assertEqual(result["planned_execution"], "NOT_RUN")
        self.assertFalse(result["gameplay_qualified"])
        self.assertFalse(result["runtime_qualified"])

    def test_duplicate_json_key_refuses(self) -> None:
        with self.assertRaisesRegex(subject.AdmissionError, "duplicate JSON key"):
            subject.parse_json('{"schema":"a","schema":"b"}')

    def test_stale_registered_blob_refuses(self) -> None:
        record = copy.deepcopy(self.record)
        record["authority"][0]["git_blob"] = "0" * 40
        with self.assertRaisesRegex(subject.AdmissionError, "registered blob is stale"):
            subject.check(record=record)

    def test_missing_or_extra_authority_refuses(self) -> None:
        record = copy.deepcopy(self.record)
        record["authority"].pop()
        with self.assertRaisesRegex(subject.AdmissionError, "authority count"):
            subject.validate_record(record)

    def test_fixture_cannot_be_relabelled_current_or_passed(self) -> None:
        record = copy.deepcopy(self.record)
        record["planned"][0]["status"] = "Current"
        record["planned"][0]["execution"] = "PASS"
        with self.assertRaisesRegex(subject.AdmissionError, "Planned/NOT_RUN"):
            subject.validate_record(record)

    def test_qualification_flags_cannot_be_predeclared(self) -> None:
        for field in ("gameplay_qualified", "runtime_qualified"):
            record = copy.deepcopy(self.record)
            record[field] = True
            with self.subTest(field=field), self.assertRaisesRegex(
                subject.AdmissionError, "cannot claim"
            ):
                subject.validate_record(record)

    def test_working_copy_mutation_refuses_and_is_restored(self) -> None:
        target = ROOT / self.record["authority"][0]["path"]
        original = target.read_bytes()
        try:
            target.write_bytes(original + b"\n# admission-negative-control\n")
            with self.assertRaisesRegex(subject.AdmissionError, "working source changed"):
                subject.check()
        finally:
            target.write_bytes(original)
        self.assertEqual(subject.check()["status"], "admitted")


if __name__ == "__main__":
    unittest.main()
