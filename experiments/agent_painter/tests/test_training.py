"""Model-free refusal tests. These tests are not optimizer or native evidence."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import struct
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "training"))
from common import (canonical, compiler_module, digest_json, encode_row, load_training_corpus, profile,
                    relative_file, sha256_file, strict_completion, strict_json,
                    verify_checkpoint, write_json)


class TinyTokenizer:
    """Explicit synthetic tokenizer for loss-mask/refusal logic only."""
    eos_token_id = 1000
    chat_template = "synthetic-test-only"

    def apply_chat_template(self, messages, tokenize=False, add_generation_prompt=False):
        text = "".join(message["role"] + ":" + message["content"] + "\n" for message in messages)
        if add_generation_prompt:
            return text + "assistant:"
        return text.removesuffix("\n") + "<eos>"

    def encode(self, text, add_special_tokens=False):
        if text.endswith("<eos>"):
            return [ord(c) for c in text[:-5]] + [1000]
        return [ord(c) for c in text]

    def decode(self, ids, skip_special_tokens=False):
        return "".join("<eos>" if x == 1000 else chr(x) for x in ids)


class TrainingGuards(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def fixture(self):
        compiler = self.root / "compiler.py"
        compiler.write_bytes((Path(__file__).resolve().parents[1] / "compiler.py").read_bytes())
        evidence = self.root / "evidence"
        evidence.mkdir()
        program = {"version": 2, "family": "greebles", "variation": 0,
                   "components": [{"kind": "panel", "box": [8, 8, 32, 32], "detail": "inset", "density": 1, "border": 1, "fasteners": True}],
                   "requirements": {"negative_space_min_percent": 20}}
        compiled = compiler_module(compiler).compile_program(program, seed=17)
        operations = compiled["operations"]
        # Synthetic protocol fixture only: the real native replay creates these
        # files on a separately qualified runner. This unit test executes no World.
        values = compiler_module(compiler).rasterize_operations(operations)
        (evidence / "readback").write_bytes(struct.pack("<" + "i" * len(values), *values))
        (evidence / "png").write_bytes(b"synthetic unit-test PNG custody bytes")
        receipt = {"id": "unit-train-1", "family": "greebles", "seed": 17, "passed": True,
                   "program_sha256": compiled["program_sha256"], "operations_sha256": compiled["operations_sha256"],
                   "crop_i32le_sha256": sha256_file(evidence / "readback"), "outside_area_cells": 0,
                   "unexpected_material_cells": 0, "deterministic_replay_checked": True}
        write_json(evidence / "receipt", receipt)
        paths = {key: "evidence/" + key for key in ("png", "readback", "receipt")}
        hashes = {key + "_sha256": sha256_file(evidence / key) for key in paths}
        row = {"id": "unit-train-1", "group_id": "greebles:train", "split": "TRAIN", "family": "greebles",
               "prompt": "Synthetic unit test only", "program": program, "seed": 17, "compiled": compiled,
               "native_admission": {"state": "PASS", "native_execution": True, "verified": True,
                    "source_sha": "a" * 40, "runtime_sha256": "b" * 64, "affected_cells": 1,
                    "program_sha256": compiled["program_sha256"],
                    "operations_sha256": digest_json(operations), "paths": paths, **hashes}}
        manifest = {"schema_version": 1, "state": "native-admitted", "source_sha": "a" * 40,
                    "runtime_sha256": "b" * 64, "native_verification_sha256": "e" * 64,
                    "compiler_sha256": sha256_file(compiler),
                    "structural_groups": {"TRAIN": ["greebles:train"], "DEVELOPMENT": ["pipework:dev"], "FINAL": ["architecture:final"]},
                    "split_files": {"TRAIN": {"path": "train.jsonl", "sha256": "", "count": 1},
                                    "DEVELOPMENT": {"path": "development.jsonl", "sha256": "c" * 64, "count": 1},
                                    "FINAL": {"path": "final.jsonl", "sha256": "d" * 64, "count": 1}}}
        return compiler, row, manifest

    def persist(self, row, manifest):
        path = self.root / "train.jsonl"
        path.write_text(canonical(row) + "\n")
        manifest["split_files"]["TRAIN"]["sha256"] = sha256_file(path)
        write_json(self.root / "admitted-corpus.json", manifest)

    def test_duplicate_nonfinite_and_wrapped_json_are_refused(self):
        for text in ('{"x":1,"x":2}', '{"x":NaN}', '{"x":Infinity}', '```json\n{}\n```', '{} trailing'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                strict_json(text)

    def test_eos_required_and_no_special_token_repair(self):
        tokenizer = TinyTokenizer()
        validator = lambda value: None
        valid = tokenizer.encode('{}<eos>')
        self.assertTrue(strict_completion(tokenizer, valid, validator)["first_pass_accepted"])
        self.assertFalse(strict_completion(tokenizer, valid[:-1], validator)["first_pass_accepted"])
        for malformed in (valid + [32], [1000] + valid, tokenizer.encode('```json{}') + [1000]):
            self.assertFalse(strict_completion(tokenizer, malformed, validator)["first_pass_accepted"])

    def test_loss_mask_includes_completion_and_true_eos(self):
        row = {"id": "x", "prompt": "draw", "completion": '{}'}
        encoded = encode_row(TinyTokenizer(), row, "system", 256)
        boundary = encoded["boundary"]
        self.assertTrue(all(value == -100 for value in encoded["labels"][:boundary]))
        self.assertEqual(encoded["labels"][boundary:], [ord('{'), ord('}'), 1000])
        with self.assertRaisesRegex(ValueError, "no truncation"):
            encode_row(TinyTokenizer(), row, "system", 8)

    def test_all_four_pins_are_full_and_unsupported_lanes_fail_closed(self):
        for name in ("smol", "void", "sprocket", "lfm25_vl"):
            self.assertEqual(len(profile(name)["revision"]), 40)
            self.assertEqual(profile(name)["subfolder"], "")
        for name in ("void", "sprocket", "lfm25_vl"):
            with self.assertRaisesRegex(ValueError, "preflight required"):
                profile(name, require_supported=True)

    def test_train_loader_never_opens_final_targets(self):
        compiler, row, manifest = self.fixture()
        self.persist(row, manifest)
        # No DEVELOPMENT/FINAL files exist. TRAIN validation consumes only their
        # frozen group/hash metadata; it cannot leak held-out target content.
        rows, _ = load_training_corpus(self.root, compiler)
        self.assertEqual([item["id"] for item in rows], [row["id"]])

    def test_group_leakage_is_refused(self):
        compiler, row, manifest = self.fixture()
        manifest["structural_groups"]["FINAL"] = ["greebles:train"]
        self.persist(row, manifest)
        with self.assertRaisesRegex(ValueError, "leakage"):
            load_training_corpus(self.root, compiler)

    def test_nontrain_rows_and_unexecuted_admission_are_refused(self):
        compiler, row, manifest = self.fixture()
        for change in (lambda x: x.update(split="FINAL"),
                       lambda x: x["native_admission"].update(state="PLANNED"),
                       lambda x: x["native_admission"].update(native_execution=False),
                       lambda x: x["native_admission"].update(affected_cells=0)):
            altered = copy.deepcopy(row)
            change(altered)
            self.persist(altered, manifest)
            with self.assertRaises(ValueError):
                load_training_corpus(self.root, compiler)

    def test_missing_or_tampered_native_payload_refused(self):
        compiler, row, manifest = self.fixture()
        self.persist(row, manifest)
        (self.root / "evidence/png").write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "custody"):
            load_training_corpus(self.root, compiler)

    def test_unbound_operations_and_completion_refused(self):
        compiler, row, manifest = self.fixture()
        altered = copy.deepcopy(row)
        altered["compiled"]["operations"][0]["material"] = 0
        self.persist(altered, manifest)
        with self.assertRaisesRegex(ValueError, "operations"):
            load_training_corpus(self.root, compiler)
        altered = copy.deepcopy(row)
        altered["completion"] = '{"different":true}'
        self.persist(altered, manifest)
        with self.assertRaisesRegex(ValueError, "completion"):
            load_training_corpus(self.root, compiler)
        altered = copy.deepcopy(row)
        altered["program"]["components"][0]["detail"] = "ribs"
        self.persist(altered, manifest)
        with self.assertRaisesRegex(ValueError, "compile"):
            load_training_corpus(self.root, compiler)

    def test_manifest_and_compiler_tamper_refused(self):
        compiler, row, manifest = self.fixture()
        self.persist(row, manifest)
        (self.root / "train.jsonl").write_text("{}\n")
        with self.assertRaisesRegex(ValueError, "custody"):
            load_training_corpus(self.root, compiler)
        self.persist(row, manifest)
        compiler.write_text("# changed")
        with self.assertRaisesRegex(ValueError, "compiler"):
            load_training_corpus(self.root, compiler)

    def test_rehashed_readback_cannot_override_compiled_cells(self):
        compiler, row, manifest = self.fixture()
        raw_path = self.root / "evidence/readback"
        raw_path.write_bytes(bytes(96 * 96 * 4))
        row["native_admission"]["readback_sha256"] = sha256_file(raw_path)
        receipt_path = self.root / "evidence/receipt"
        receipt = json.loads(receipt_path.read_text())
        receipt["crop_i32le_sha256"] = sha256_file(raw_path)
        write_json(receipt_path, receipt)
        row["native_admission"]["receipt_sha256"] = sha256_file(receipt_path)
        self.persist(row, manifest)
        with self.assertRaisesRegex(ValueError, "native material cells"):
            load_training_corpus(self.root, compiler)

    def test_evidence_cannot_escape_or_follow_symlinks(self):
        for path in ("../outside", "/etc/passwd", "evidence\\x"):
            with self.assertRaises(ValueError):
                relative_file(self.root, path)
        (self.root / "link").symlink_to("/etc/passwd")
        with self.assertRaisesRegex(ValueError, "symlink"):
            relative_file(self.root, "link")

    def test_checkpoint_missing_extra_or_tampered_files_refused(self):
        directory = self.root / "checkpoint"
        (directory / "adapter").mkdir(parents=True)
        for name in ("adapter/adapter_model.safetensors", "adapter/adapter_config.json", "training_state.pt", "receipt.json"):
            (directory / name).write_text('{}')
        inventory = {path.relative_to(directory).as_posix(): {"bytes": path.stat().st_size, "sha256": sha256_file(path)} for path in directory.rglob('*') if path.is_file()}
        write_json(directory / "inventory.json", inventory)
        self.assertEqual(verify_checkpoint(directory), {})
        (directory / "extra").write_text("x")
        with self.assertRaisesRegex(ValueError, "inventory"):
            verify_checkpoint(directory)
        (directory / "extra").unlink()
        (directory / "training_state.pt").write_text("tampered")
        with self.assertRaisesRegex(ValueError, "custody"):
            verify_checkpoint(directory)


if __name__ == "__main__":
    unittest.main()
