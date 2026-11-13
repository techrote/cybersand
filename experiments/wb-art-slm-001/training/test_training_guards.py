"""Concrete regression tests for leakage, admission, strict output and EOS guards."""
import json
from pathlib import Path
import tempfile
import unittest

from train_lora import balanced_rows, read_rows, sha256_file, split_guard, strict_json, validate_admission, verify_checkpoint


class TrainingGuards(unittest.TestCase):
    def test_candidates_cannot_train(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "candidate.jsonl"
            path.write_text(json.dumps({"id": "x", "prompt": "roots", "completion": "{}", "group_id": "g", "theme": "roots", "split": "train", "native_qualified": False}) + "\n")
            with self.assertRaisesRegex(ValueError, "native admission"):
                read_rows(path, "train")

    def test_final_cannot_be_read_as_dev(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "final.jsonl"
            path.write_text(json.dumps({"id": "x", "prompt": "roots", "completion": "{}", "group_id": "g", "theme": "roots", "split": "final"}) + "\n")
            with self.assertRaisesRegex(ValueError, "expected split dev"):
                read_rows(path, "dev")

    def test_family_leakage_fails(self):
        with self.assertRaisesRegex(ValueError, "family overlap"):
            split_guard([{"id": "a", "group_id": "same"}], [{"id": "b", "group_id": "same"}])

    def test_sorted_corpus_is_balanced(self):
        rows = [{"id": f"{theme}-{i}", "theme": theme} for theme in ("roots", "coral", "veins") for i in range(10)]
        selected = balanced_rows(rows, 6)
        self.assertEqual({t: sum(r["theme"] == t for r in selected) for t in ("roots", "coral", "veins")}, {"roots": 2, "coral": 2, "veins": 2})
        self.assertEqual(selected, balanced_rows(list(reversed(rows)), 6))

    def test_no_repair_or_nonstandard_json(self):
        for text in ('```json\n{"a":1}\n```', '{"a":1,"a":2}', '{"a":NaN}', 'reasoning: {"a":1}', '{"a":1} trailing'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                strict_json(text)

    def test_manifest_requires_admission(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "admission.json"
            path.write_text('{"state":"native-replay-pending"}')
            with self.assertRaisesRegex(ValueError, "not admitted"):
                validate_admission(path, {}, {}, path, path)

    def test_checkpoint_corruption_fails_before_deserialization(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "adapter").mkdir()
            names = ("adapter/adapter_model.safetensors", "adapter/adapter_config.json", "adapter/inference_contract.json", "training_state.pt", "receipt.json")
            for name in names:
                (root / name).write_text("fixture")
            inventory = {name: {"sha256": sha256_file(root / name), "bytes": (root / name).stat().st_size} for name in names}
            (root / "inventory.json").write_text(json.dumps(inventory))
            verify_checkpoint(root)
            (root / "adapter/adapter_model.safetensors").write_text("mutated")
            with self.assertRaisesRegex(ValueError, "custody mismatch"):
                verify_checkpoint(root)


if __name__ == "__main__":
    unittest.main()
