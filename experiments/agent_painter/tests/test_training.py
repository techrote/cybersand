"""Refusal and tensor-comparison tests; never optimizer or native evidence."""
from __future__ import annotations

import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import struct
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "training"))
from common import (canonical, compiler_module, digest_json, encode_row, load_training_corpus, profile,
                    relative_file, sha256_file, strict_completion, strict_json,
                    verify_checkpoint, write_json)
from numerics import ENVIRONMENT


class NumericalEnvironmentGuards(unittest.TestCase):
    def run_clean(self, script, changes=None):
        environment = {key: value for key, value in os.environ.items() if key not in ENVIRONMENT}
        environment.update(changes or {})
        return subprocess.run([sys.executable, "-c", script],
                              cwd=Path(__file__).resolve().parents[1] / "training",
                              env=environment, capture_output=True, text=True, timeout=30)

    def test_conflicting_environment_refused_before_torch_import(self):
        result = self.run_clean("""
import sys
from numerics import prepare_environment
try:
    prepare_environment()
except ValueError as error:
    assert 'OMP_NUM_THREADS' in str(error)
    assert 'torch' not in sys.modules
else:
    raise AssertionError('conflicting threads were accepted')
""", {"OMP_NUM_THREADS": "4"})
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_multiple_threads_refused_before_torch_import(self):
        result = self.run_clean("""
import sys
from numerics import prepare_environment
try:
    prepare_environment(4)
except ValueError:
    assert 'torch' not in sys.modules
else:
    raise AssertionError('nonportable thread recipe was accepted')
""")
        self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(importlib.util.find_spec("torch"), "requires the pinned CPU PyTorch environment")
    def test_actual_backend_profile_and_late_initialization_refusal(self):
        result = self.run_clean("""
import json
from numerics import configure_cpu
recipe, runtime = configure_cpu()
assert recipe['profile'] == 'portable-cpu-fp32-v1'
assert recipe['effective']['aten_cpu_capability'] == 'DEFAULT'
assert recipe['effective']['mkldnn_enabled'] is False
assert recipe['effective']['float32_matmul_precision'] == 'highest'
assert recipe['effective']['intraop_threads'] == recipe['effective']['interop_threads'] == 1
assert len(recipe['torch_build_sha256']) == len(recipe['numerics_sha256']) == 64
assert runtime['torch_build'] and runtime['identity']['machine']
json.dumps((recipe, runtime), allow_nan=False)
try:
    configure_cpu()
except RuntimeError as error:
    assert 'before importing Torch' in str(error)
else:
    raise AssertionError('late backend initialization was accepted')
""")
        self.assertEqual(result.returncode, 0, result.stderr)


@unittest.skipUnless(importlib.util.find_spec("torch"), "requires the pinned CPU PyTorch environment")
class ResumeTensorComparison(unittest.TestCase):
    def test_later_larger_differences_are_reported_after_an_earlier_failure(self):
        import torch
        from compare_resume import tensors_close

        # This uses actual tensors and a nested optimizer-like state. The first
        # failure must not hide the larger error in the final dictionary/list.
        first = {"state": [{"moment": torch.tensor([0.0])},
                           {"moment": torch.tensor([1.0])}]}
        second = {"state": [{"moment": torch.tensor([0.125])},
                            {"moment": torch.tensor([1.75])}]}
        passed, maximum = tensors_close(first, second)
        self.assertFalse(passed)
        self.assertEqual(maximum, 0.75)

    def test_structure_failure_does_not_hide_later_comparable_tensor(self):
        import torch
        from compare_resume import tensors_close

        first = {"missing": 1, "state": [torch.tensor([0.0]), torch.tensor([1.0])]}
        second = {"state": [torch.tensor([0.25]), torch.tensor([1.5]), torch.tensor([2.0])]}
        passed, maximum = tensors_close(first, second)
        self.assertFalse(passed)
        self.assertEqual(maximum, 0.5)

    def test_existing_numerical_threshold_is_preserved(self):
        import torch
        from compare_resume import tensors_close

        self.assertTrue(tensors_close(torch.tensor([0.0]), torch.tensor([0.5e-6]))[0])
        self.assertFalse(tensors_close(torch.tensor([0.0]), torch.tensor([2e-6]))[0])


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

    def test_all_four_pins_require_their_exact_reviewed_adapter(self):
        from lane_adapters import adapter_identity, validate_profile
        for name in ("smol", "void", "sprocket", "lfm25_vl"):
            selected = profile(name, require_supported=True)
            self.assertEqual(len(selected["revision"]), 40)
            self.assertEqual(selected["subfolder"], "")
            self.assertEqual(adapter_identity(selected)["lane"], name)
            for field, value in (("loader", "arbitrary.Model"), ("trust_remote_code", True),
                                 ("architecture", "SubstituteModel")):
                changed = copy.deepcopy(selected)
                changed[field] = value
                with self.assertRaises(ValueError):
                    validate_profile(name, changed)
        with self.assertRaises(ValueError):
            profile("../unreviewed", require_supported=True)
        changed = copy.deepcopy(profile("smol"))
        changed["required_hashes"]["../payload.py"] = "a" * 64
        with self.assertRaises(ValueError):
            validate_profile("smol", changed)

    def test_model_adapter_import_does_not_initialize_torch(self):
        script = """
import sys
from common import profile
from lane_adapters import adapter_for
for name in ('smol', 'void', 'sprocket', 'lfm25_vl'):
    adapter_for(profile(name, require_supported=True))
assert 'torch' not in sys.modules
assert 'transformers' not in sys.modules
assert 'peft' not in sys.modules
"""
        result = subprocess.run([sys.executable, "-c", script],
                                cwd=Path(__file__).resolve().parents[1] / "training",
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_invalid_utf8_retains_tokens_without_replacement_or_crash(self):
        class ByteDecoder:
            eos_token_id = 258

            def decode(self, ids, skip_special_tokens=False):
                return bytes(ids).decode("utf-8", errors="strict")

        ids = [255, 258]
        result = strict_completion(ByteDecoder(), ids, lambda value: None)
        self.assertFalse(result["first_pass_accepted"])
        self.assertFalse(result["text_decoded"])
        self.assertEqual(result["token_ids"], ids)
        self.assertEqual(result["raw_text"], "")
        self.assertIn("decode", result["failure"])

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
