"""Leakage and false-admission regression tests; native tests live elsewhere."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

import build_corpus as corpus


class CorpusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.temp.name)
        cls.manifest = corpus.build(cls.root)
        cls.rows = [json.loads(line) for line in (cls.root / "candidates.jsonl").read_text().splitlines()]
        cls.cases = json.loads((cls.root / "native_cases.json").read_text())["cases"]

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_counts_and_split_claim(self):
        self.assertEqual(self.manifest["split_counts"], {"train": 1152, "dev": 192, "final": 192})
        self.assertEqual(self.manifest["group_counts"], {"train": 72, "dev": 12, "final": 12})
        self.assertEqual(len(self.cases), 864)
        self.assertEqual(len(set(self.manifest["gallery_case_ids"])), 192)
        corpus.validate_splits(self.rows)

    def test_all_literal_words_are_train_only(self):
        literal = [r for r in self.rows if r["prompt"] in corpus.THEMES]
        self.assertEqual(len(literal), 12)
        self.assertEqual({r["split"] for r in literal}, {"train"})

    def test_reference_generation_never_claims_execution(self):
        self.assertTrue(all(r["native_qualified"] is False for r in self.rows))

    def test_group_leakage_fails(self):
        row = {**self.rows[0], "id": "injected-cross-split", "split": "dev"}
        with self.assertRaises(ValueError):
            corpus.validate_splits(self.rows + [row])

    def test_target_leakage_fails_even_with_fake_group(self):
        row = {**self.rows[0], "id": "injected", "group_id": "different", "split": "dev", "prompt": "unseen wording"}
        with self.assertRaises(ValueError):
            corpus.validate_splits(self.rows + [row])

    def test_changed_completion_with_old_receipt_is_refused(self):
        changed = copy.deepcopy(self.rows)
        program = json.loads(changed[0]["completion"])
        program["layers"][0]["density"] = .999
        changed[0]["completion"] = corpus.canonical_json(program)
        with self.assertRaises(ValueError):
            corpus.validate_candidate_bindings(self.root, changed, self.cases)

    def test_changed_native_operations_are_refused(self):
        changed = copy.deepcopy(self.cases)
        changed[0]["operations"][0]["material"] = 0
        with self.assertRaises(ValueError):
            corpus.validate_candidate_bindings(self.root, self.rows, changed)

    def mock_admission(self, mutation=None):
        # Synthetic evidence is confined to this test's temporary directory.
        case = self.cases[0]
        receipt = {"id": case["id"], "success": True,
                   "operations_sha256": case["operations_sha256"],
                   "image_sha256": "1" * 64, "readback_sha256": "2" * 64,
                   "outside_focus_violations": 0, "unexpected_material_cells": 0,
                   "acknowledged_cells": 42}
        if mutation:
            receipt.update(mutation)
        evidence = {"passed": True, "runtime": {"source_commit": "3" * 40,
                                "native_sha256": "4" * 64,
                                "godot_version": "synthetic-unit-test-only"}, "cases": [receipt]}
        review = {"reviewed_case_ids": [case["id"]],
                  "accepted_group_ids": [case["group_id"]], "notes": "synthetic unit test"}
        corpus.write_json(self.root / "test-receipts.json", evidence)
        corpus.write_json(self.root / "test-review.json", review)
        return self.root / "test-receipts.json", self.root / "test-review.json"

    def test_partial_admission_has_explicit_exclusions(self):
        receipt, review = self.mock_admission()
        result = corpus.admit(self.root, receipt, review, True)
        self.assertEqual(result["admitted_records"], 2)
        self.assertEqual(result["excluded_records"], 1534)
        self.assertEqual(result["state"], "partial-native-pilot")

    def test_no_silent_partial_corpus(self):
        receipt, review = self.mock_admission()
        with self.assertRaises(ValueError):
            corpus.admit(self.root, receipt, review, False)

    def test_wrong_operation_hash_cannot_be_admitted(self):
        receipt, review = self.mock_admission({"operations_sha256": "0" * 64})
        with self.assertRaises(ValueError):
            corpus.admit(self.root, receipt, review, True)

    def test_outside_focus_write_cannot_be_admitted(self):
        receipt, review = self.mock_admission({"outside_focus_violations": 1})
        with self.assertRaises(ValueError):
            corpus.admit(self.root, receipt, review, True)

    def test_zero_work_cannot_be_admitted(self):
        receipt, review = self.mock_admission({"acknowledged_cells": 0})
        with self.assertRaises(ValueError):
            corpus.admit(self.root, receipt, review, True)

    def test_global_failure_cannot_be_hidden_by_passed_case(self):
        receipt, review = self.mock_admission()
        value = json.loads(receipt.read_text())
        value["passed"] = False
        corpus.write_json(receipt, value)
        with self.assertRaises(ValueError):
            corpus.admit(self.root, receipt, review, True)

    def test_unexpected_material_cannot_be_admitted(self):
        receipt, review = self.mock_admission({"unexpected_material_cells": 1})
        with self.assertRaises(ValueError):
            corpus.admit(self.root, receipt, review, True)

    def test_unexecuted_reviewed_representative_is_refused(self):
        receipt, review = self.mock_admission()
        value = json.loads(review.read_text())
        same_group = next(c for c in self.cases if c["group_id"] == value["accepted_group_ids"][0] and c["id"] not in value["reviewed_case_ids"])
        value["reviewed_case_ids"] = [same_group["id"]]
        corpus.write_json(review, value)
        with self.assertRaises(ValueError):
            corpus.admit(self.root, receipt, review, True)


if __name__ == "__main__":
    unittest.main()
