"""Model-free supervised evaluation tests; no model load, accelerator, or native engine."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import textwrap
import types
import unittest

from filelock import FileLock, Timeout
from evaluation_guard import evaluation_fingerprint, verified_evaluation
from job_guard import LEASE_NAME, LOCK_NAME, run

FAKE_EVALUATOR = r'''
import argparse, json, pathlib, signal, time
from job_guard import trainer_lock
p = argparse.ArgumentParser()
for key in ('model', 'dev', 'admission', 'corpus-manifest', 'compiler', 'output', 'adapter', 'eval-count', 'suite', 'device'):
    p.add_argument('--'+key)
a = p.parse_args()
out = pathlib.Path(a.output)
with trainer_lock(out):
    assert {p.name for p in out.iterdir()} == {'guard_start.json'}
    (out/'lease_handshake_passed').write_text('yes')
if a.device == 'hang':
    signal.signal(signal.SIGTERM, lambda *_: None)
    while True: time.sleep(.2)
if a.device == 'early':
    (out/'predictions.json').write_text(json.dumps({'records':[{'id':'one'}]}))
    raise SystemExit(0)
records = [{'id':name,'json_valid':True,'program_valid':True,'first_pass_accepted':True,
            'theme_field_correct':True,'primary_motif_correct':True,'motif_layout_exact':True,
            'exact_target':False} for name in ('one','two')]
metrics = {'count':len(records),'json_valid':2,'program_valid':2,'first_pass_accepted':2,
           'theme_field_correct':2,'primary_motif_correct':2,'motif_layout_exact':2,
           'exact_target':0}
config = {'suite':a.suite or 'dev','training_executed':False}
if a.device == 'mismatch': metrics['first_pass_accepted'] = 9
(out/'run_config.json').write_text(json.dumps(config))
(out/'predictions.json').write_text(json.dumps({'records':records,'summary':metrics}))
(out/'summary.json').write_text(json.dumps({'config':config,'metrics':metrics}))
'''


class EvaluationGuardTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="wb-slm-eval-")
        self.root = Path(self.tmp.name)
        self.parent = self.root / "private"
        self.model = self.root / "model"
        self.model.mkdir()
        self.model_files = {"weights.safetensors": b"base-weights", "config.json": b"{}"}
        for name, value in self.model_files.items():
            (self.model / name).write_bytes(value)
        self.revision = "a" * 40
        receipt = {"model_id": "test/frozen", "resolved_revision": self.revision,
                   "profile": "test", "subfolder": "",
                   "files": {name: {"sha256": hashlib.sha256(value).hexdigest()}
                             for name, value in self.model_files.items()}}
        (self.model / "download_receipt.json").write_text(json.dumps(receipt))
        self.inputs = {}
        for name in ("dev", "admission", "corpus-manifest", "compiler"):
            self.inputs[name] = self.root / (name + ".txt")
            self.inputs[name].write_text('{"id":"one"}\n{"id":"two"}\n' if name == "dev" else name)
        self.adapter = self.root / "adapter"
        self.adapter.mkdir()
        (self.adapter / "adapter_model.safetensors").write_bytes(b"LoRA")
        (self.adapter / "adapter_config.json").write_text("{}")
        contract = {"model_id": "test/frozen", "revision": self.revision,
                    "compiler_sha256": hashlib.sha256(b"compiler").hexdigest(),
                    "model_files": {k:hashlib.sha256(v).hexdigest() for k,v in self.model_files.items()}}
        (self.adapter / "inference_contract.json").write_text(json.dumps(contract))
        self.worker = self.root / "evaluate_model.py"
        self.worker.write_text(textwrap.dedent(FAKE_EVALUATOR))
        for name in ("job_guard.py", "evaluation_guard.py", "train_lora.py", "system_prompt.txt"):
            shutil.copy2(Path(__file__).with_name(name), self.root / name)

    def tearDown(self):
        self.tmp.cleanup()

    def setup_run(self, output="eval-one", device="complete", wall=6, margin=2):
        params = {
            "output": str(self.parent / output), "model": str(self.model),
            "adapter": str(self.adapter), "eval-count": "2", "suite": "dev", "device": device,
            **{name: str(path) for name, path in self.inputs.items()},
        }
        argv = [item for key, value in params.items() for item in ("--" + key, value)]
        args = types.SimpleNamespace(run_parent=self.parent, worker_script=self.worker,
                                     wall_seconds=wall, save_margin_seconds=margin)
        return args, argv

    def test_complete_evaluation_has_exact_evidence_and_shared_lease(self):
        args, argv = self.setup_run()
        result = run(args, argv)
        self.assertEqual(result["kind"], "evaluation")
        self.assertEqual(result["status"], "completed")
        self.assertEqual(result["evidence"]["observed_requests"], 2)
        self.assertEqual(result["evidence"]["raw_first_pass_accepted"], 2)
        self.assertFalse(result["evidence"]["native_execution"])
        self.assertEqual(json.loads((self.parent / LEASE_NAME).read_text())["state"], "completed")
        self.assertEqual((self.parent / "eval-one" / "lease_handshake_passed").read_text(), "yes")

    def test_incomplete_raw_predictions_not_credited(self):
        args, argv = self.setup_run(device="early")
        result = run(args, argv)
        self.assertEqual(result["status"], "incomplete")
        self.assertIsNone(result["evidence"])

    def test_inconsistent_summary_rejected_even_on_clean_exit(self):
        args, argv = self.setup_run(device="mismatch")
        result = run(args, argv)
        self.assertEqual(result["status"], "incomplete")
        self.assertIsNone(verified_evaluation(self.parent / "eval-one", argv))

    def test_duplicate_evaluation_fingerprint_not_relaunched(self):
        args, argv = self.setup_run()
        run(args, argv)
        args2, argv2 = self.setup_run(output="eval-two")
        with self.assertRaisesRegex(FileExistsError, "Identical fingerprint"):
            run(args2, argv2)
        self.assertFalse((self.parent / "eval-two").exists())

    def test_training_lock_also_blocks_evaluation(self):
        args, argv = self.setup_run()
        self.parent.mkdir()
        with FileLock(str(self.parent / LOCK_NAME), timeout=0):
            with self.assertRaises(Timeout):
                run(args, argv)
        self.assertFalse((self.parent / "eval-one").exists())

    def test_adapter_mutation_fingerprints_and_model_mutation_fail_closed(self):
        args, argv = self.setup_run()
        old, _ = evaluation_fingerprint(argv, self.worker)
        (self.adapter / "adapter_model.safetensors").write_bytes(b"modified")
        changed, _ = evaluation_fingerprint(argv, self.worker)
        self.assertNotEqual(old, changed)
        (self.model / "weights.safetensors").write_bytes(b"tampered")
        with self.assertRaisesRegex(ValueError, "checksum differs"):
            run(args, argv)
        self.assertFalse((self.parent / "eval-one").exists())

    @unittest.skipIf(os.name == "nt", "POSIX process-group SIGTERM behavior")
    def test_uncooperative_evaluator_has_strict_deadline(self):
        args, argv = self.setup_run(device="hang", wall=3, margin=1)
        result = run(args, argv)
        self.assertEqual(result["status"], "deadline_killed")
        self.assertTrue(result["hard_kill_sent"])
        self.assertLess(result["whole_process_seconds"], 4)

    def test_missing_output_or_unexpected_flag_rejected(self):
        args, argv = self.setup_run()
        with self.assertRaisesRegex(ValueError, "Unknown evaluation arguments"):
            evaluation_fingerprint(argv + ["--train", "/private/final.jsonl"], self.worker)
        with self.assertRaisesRegex(ValueError, "positive evaluation"):
            evaluation_fingerprint(argv + ["--threads", "0"], self.worker)


if __name__ == "__main__":
    unittest.main()
