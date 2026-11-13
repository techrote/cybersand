"""Model-free supervised evaluation tests; no model load, accelerator, or native engine."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import textwrap
import types
import unittest

from filelock import FileLock, Timeout
from evaluation_guard import evaluation_fingerprint, verified_evaluation
from job_guard import LEASE_NAME, LOCK_NAME, run

FAKE_EVALUATOR = r'''
import argparse, hashlib, json, pathlib, signal, time
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
program = {'version':1,'theme':'roots','layers':[
    {'motif':'branch','density':0.5,'scale':0.5,'width':0.3,'angle':0,'layout':'center'}]}
reference = {'version':1,'theme':'roots','layers':[
    {'motif':'branch','density':0.6,'scale':0.5,'width':0.3,'angle':0,'layout':'center'}]}
records = [{'id':name,'theme':'roots','completion':json.dumps(program),
            'expected_completion':json.dumps(reference),'program':program,
            'compiled_operations':3,'output_tokens':24,'eos_emitted':True,
            'eos_terminated':True,'json_valid':True,'program_valid':True,
            'first_pass_accepted':True,'theme_field_correct':True,
            'primary_motif_correct':True,'motif_layout_exact':True,
            'exact_target':False} for name in ('one','two')]
metrics = {'count':len(records),'json_valid':2,'program_valid':2,'first_pass_accepted':2,
           'theme_field_correct':2,'primary_motif_correct':2,'motif_layout_exact':2,
           'exact_target':0}
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
receipt = json.loads((pathlib.Path(a.model)/'download_receipt.json').read_text())
config = {'suite':a.suite or 'dev','training_executed':False,
          'model_id':receipt['model_id'],'revision':receipt['resolved_revision'],
          'model_profile':receipt.get('profile'),'model_subfolder':receipt.get('subfolder'),
          'compiler_sha256':sha(pathlib.Path(a.compiler)),
          'dev_sha256':sha(pathlib.Path(a.dev)),'admission_sha256':sha(pathlib.Path(a.admission)),
          'adapter_sha256':sha(pathlib.Path(a.adapter)/'adapter_model.safetensors'),
          'max_new_tokens':256,'decoding':'greedy, unconstrained, no repair'}
if a.device == 'mismatch': metrics['first_pass_accepted'] = 9
if a.device == 'tamper':
    (pathlib.Path(a.adapter)/'adapter_model.safetensors').write_bytes(b'mutated during evaluation')
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

    def test_midflight_adapter_mutation_is_not_a_completed_candidate(self):
        args, argv = self.setup_run(device="tamper")
        result = run(args, argv)
        self.assertEqual(result["status"], "failed")
        self.assertIn("fingerprint changed", result["error"])
        self.assertIsNone(result["evidence"])

    def test_raw_completion_eos_and_semantic_flag_tampering_refused(self):
        args, argv = self.setup_run()
        result = run(args, argv)
        self.assertEqual(result["status"], "completed")
        path = self.parent / "eval-one" / "predictions.json"
        authentic = json.loads(path.read_text())
        alterations = (
            {"completion": '{"value":0595931}'},  # malformed coral-style decimal
            {"eos_terminated": False},           # EOS did not end the generation
            {"primary_motif_correct": False},   # claimed score disagrees with raw
            {"program": {"version": 1}},       # compiled program differs from raw
            {"output_tokens": 300},             # exceeds pinned token cap
        )
        for alteration in alterations:
            with self.subTest(alteration=alteration):
                modified = json.loads(json.dumps(authentic))
                modified["records"][0].update(alteration)
                path.write_text(json.dumps(modified))
                self.assertIsNone(verified_evaluation(path.parent, argv))
        path.write_text(json.dumps(authentic))
        self.assertIsNotNone(verified_evaluation(path.parent, argv))

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

    def test_direct_evaluator_refuses_without_leased_supervisor(self):
        script = Path(__file__).with_name("evaluate_model.py")
        args, argv = self.setup_run()
        proc = subprocess.run([sys.executable, str(script), *argv],
                              capture_output=True, text=True, timeout=10,
                              env={k: v for k, v in os.environ.items()
                                   if k != "WB_ART_SLM_SUPERVISOR_TOKEN"})
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("direct evaluation is not guarded", proc.stderr)
        self.assertFalse((self.parent / "eval-one").exists())

    def test_missing_output_or_unexpected_flag_rejected(self):
        args, argv = self.setup_run()
        with self.assertRaisesRegex(ValueError, "Unknown evaluation arguments"):
            evaluation_fingerprint(argv + ["--train", "/private/final.jsonl"], self.worker)
        with self.assertRaisesRegex(ValueError, "positive evaluation"):
            evaluation_fingerprint(argv + ["--threads", "0"], self.worker)


if __name__ == "__main__":
    unittest.main()
