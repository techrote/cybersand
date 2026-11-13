"""Offline process-level guard regressions; no model weights or compute needed."""
from __future__ import annotations

import hashlib
import json
import os
import shutil
from pathlib import Path
import tempfile
import textwrap
import types
import unittest
from unittest import mock

from filelock import FileLock, Timeout

from job_guard import LEASE_NAME, LOCK_NAME, build_fingerprint, options, run, trainer_lock

FAKE_WORKER = r'''
import argparse, hashlib, json, os, pathlib, signal, time
p = argparse.ArgumentParser()
for k in ('output','model','train','dev','admission','corpus-manifest','compiler','model-id','revision','steps','mode'):
    p.add_argument('--'+k, required=True)
a = p.parse_args()
root = pathlib.Path(a.output)
root.mkdir(exist_ok=True)
from job_guard import trainer_lock
with trainer_lock(root):
    (root/'lease_handshake_passed').write_text('yes')
stop = False
def signal_stop(*args):
    global stop
    if a.mode != 'ignore': stop = True
signal.signal(signal.SIGTERM, signal_stop)
# Mimic the trainer owning a valid full checkpoint, without model loading.
def save(steps):
    ckpt = root / ('checkpoint-%06d' % steps)
    (ckpt/'adapter').mkdir(parents=True)
    files = {}
    for fn in ('adapter/adapter_model.safetensors','adapter/adapter_config.json','adapter/inference_contract.json','training_state.pt','receipt.json'):
        content = fn.encode()
        (ckpt/fn).write_bytes(content)
        files[fn]={'sha256':hashlib.sha256(content).hexdigest(),'bytes':len(content)}
    (ckpt/'inventory.json').write_text(json.dumps(files))
    (root/'latest_checkpoint.json').write_text(json.dumps({'path':str(ckpt),'global_step':steps}))
    (root/'summary.json').write_text(json.dumps({'global_step':steps,'status':'training_executed'}))
if a.mode in ('complete', 'tamper-model', 'tamper-train'):
    if a.mode == 'tamper-model':
        (pathlib.Path(a.model)/'weights.safetensors').write_bytes(b'modified after guard preflight')
    if a.mode == 'tamper-train':
        pathlib.Path(a.train).write_text('modified after guard preflight')
    save(int(a.steps))
else:
    while not stop:
        time.sleep(.1)
    save(1)
'''

class JobGuardTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='wb-slm-guard-')
        self.root = Path(self.tmp.name)
        self.parent = self.root / 'private'
        self.model = self.root / 'model'
        self.model.mkdir()
        (self.model/'weights.safetensors').write_bytes(b'known-model-bytes')
        (self.model/'download_receipt.json').write_text(json.dumps({
            'model_id':'test/frozen','resolved_revision':'a'*40,
            'files':{'weights.safetensors':{'sha256':hashlib.sha256(b'known-model-bytes').hexdigest()}}}))
        self.inputs = {}
        for name in ('train','dev','admission','corpus-manifest','compiler'):
            self.inputs[name]=self.root/(name+'.txt')
            self.inputs[name].write_text(name+'-exact')
        self.worker=self.root/'fake_worker.py'
        self.worker.write_text(textwrap.dedent(FAKE_WORKER))
        shutil.copy2(Path(__file__).with_name('job_guard.py'), self.root/'job_guard.py')

    def tearDown(self): self.tmp.cleanup()

    def setup_run(self, output='candidate-one', mode='complete', wall=6, margin=2):
        cmd=[]
        vals = {'output':str(self.parent/output), 'model':str(self.model),
                'model-id':'test/frozen','revision':'a'*40,'steps':'400',
                'mode':mode,**{k:str(v) for k,v in self.inputs.items()}}
        for k,v in vals.items(): cmd.extend(('--'+k,v))
        args=types.SimpleNamespace(run_parent=self.parent, worker_script=self.worker,
                                   wall_seconds=wall,save_margin_seconds=margin)
        return args,cmd

    def test_completed_job_and_durable_lease(self):
        args,cmd=self.setup_run()
        result=run(args,cmd)
        self.assertEqual(result['status'],'completed')
        self.assertEqual(result['observed_steps'],400)
        self.assertTrue(Path(result['verified_checkpoint']).is_dir())
        lease=json.loads((self.parent/LEASE_NAME).read_text())
        self.assertEqual(lease['state'],'completed')
        self.assertEqual(result['fingerprint'],lease['fingerprint'])
        self.assertFalse(result['soft_stop_sent'])
        self.assertEqual((self.parent/'candidate-one'/'lease_handshake_passed').read_text(), 'yes')

    def test_same_fingerprint_refuses_different_output(self):
        args,cmd=self.setup_run()
        run(args,cmd)
        args2,cmd2=self.setup_run(output='candidate-two')
        with self.assertRaisesRegex(FileExistsError, 'Identical fingerprint'):
            run(args2,cmd2)
        self.assertFalse((self.parent/'candidate-two').exists())

    def test_soft_deadline_graceful_save(self):
        args,cmd=self.setup_run(mode='stop',wall=4,margin=2)
        result=run(args,cmd)
        self.assertEqual(result['status'],'stopped_early')
        self.assertTrue(result['soft_stop_sent'])
        self.assertFalse(result['hard_kill_sent'])
        self.assertTrue(result['verified_checkpoint'])
        self.assertLess(result['whole_process_seconds'],4)

    @unittest.skipIf(os.name=='nt','SIGTERM ignore semantics differ on Windows')
    def test_hard_deadline_kills_uncooperative_child(self):
        args,cmd=self.setup_run(mode='ignore',wall=3,margin=1)
        result=run(args,cmd)
        self.assertEqual(result['status'],'deadline_killed')
        self.assertTrue(result['hard_kill_sent'])
        self.assertLess(result['whole_process_seconds'],4)

    def test_existing_direct_trainer_lock_blocks_supervisor(self):
        args,cmd=self.setup_run()
        self.parent.mkdir()
        with FileLock(str(self.parent/LOCK_NAME), timeout=0):
            with self.assertRaises(Timeout):
                run(args,cmd)
        self.assertFalse((self.parent/'candidate-one').exists())

    def test_model_custody_rejects_tamper_before_start(self):
        args,cmd=self.setup_run()
        (self.model/'weights.safetensors').write_bytes(b'mutated')
        with self.assertRaisesRegex(ValueError,'checksum differs'):
            run(args,cmd)
        self.assertFalse((self.parent/'candidate-one').exists())

    def test_model_receipt_inventory_must_be_complete(self):
        args, cmd = self.setup_run()
        (self.model/'weights.safetensors').unlink()
        with self.assertRaisesRegex(ValueError, 'inventories differ'):
            run(args, cmd)
        self.assertFalse((self.parent/'candidate-one').exists())

    def test_completed_worker_cannot_launder_modified_model_or_corpus(self):
        for mode, named in (('tamper-model', 'weights.safetensors'), ('tamper-train', 'train.txt')):
            with self.subTest(mode=mode):
                args, cmd = self.setup_run(output=mode, mode=mode)
                result = run(args, cmd)
                self.assertEqual(result['status'], 'failed')
                self.assertRegex(result['error'], 'fingerprint changed|custody recheck failed')
                self.assertTrue(result['verified_checkpoint'])
                self.assertEqual(result['observed_steps'], 400)
                # Restore source bytes before the next independently fingerprinted subcase.
                if mode == 'tamper-model':
                    (self.model/named).write_bytes(b'known-model-bytes')
                else:
                    self.inputs['train'].write_text('train-exact')

    def test_resume_payloads_verified_before_worker_and_bound_to_fingerprint(self):
        args, cmd = self.setup_run()
        first = run(args, cmd)
        self.assertEqual(first['status'], 'completed')
        checkpoint = Path(first['verified_checkpoint'])
        resume_args, resume_cmd = self.setup_run(output='resumed')
        resume_cmd += ['--resume', str(checkpoint)]
        fingerprint, inventory = build_fingerprint(resume_cmd, self.worker)
        self.assertTrue(fingerprint)
        self.assertIn('resume/training_state.pt', inventory['files'])
        (checkpoint/'training_state.pt').write_bytes(b'damaged optimizer state')
        with self.assertRaisesRegex(ValueError, 'Checkpoint custody mismatch'):
            run(resume_args, resume_cmd)
        self.assertFalse((self.parent/'resumed').exists())

    def test_unfinished_durable_lease_refuses_overlap_after_lock_release(self):
        args, cmd = self.setup_run()
        self.parent.mkdir()
        lease = {'state': 'running', 'supervisor_pid': 1234567, 'child_pid': 7654321,
                 'output': str(self.parent/'orphaned'), 'token': 'other'}
        (self.parent/LEASE_NAME).write_text(json.dumps(lease))
        with self.assertRaisesRegex(FileExistsError, 'Unfinished durable role lease'):
            run(args, cmd)
        self.assertFalse((self.parent/'candidate-one').exists())
        self.assertEqual(json.loads((self.parent/LEASE_NAME).read_text()), lease)

    def test_corrupt_durable_lease_requires_manual_recovery(self):
        args, cmd = self.setup_run()
        self.parent.mkdir()
        (self.parent/LEASE_NAME).write_text('{bad json')
        with self.assertRaisesRegex(ValueError, 'Unparseable durable role lease'):
            run(args, cmd)
        self.assertFalse((self.parent/'candidate-one').exists())

    def test_supervisor_token_cannot_bypass_wrong_lease(self):
        args,cmd=self.setup_run()
        self.parent.mkdir()
        (self.parent/LEASE_NAME).write_text(json.dumps({'token':'other','supervisor_pid':os.getppid(),
            'output':str((self.parent/'candidate-one').resolve()),'state':'running'}))
        with mock.patch.dict(os.environ, {'WB_ART_SLM_SUPERVISOR_TOKEN':'wrong'}):
            with self.assertRaisesRegex(ValueError,'identity'):
                trainer_lock(self.parent/'candidate-one')

    def test_same_code_train_inputs_distinct_revision(self):
        args,cmd=self.setup_run()
        first,inv1=build_fingerprint(cmd,self.worker)
        changed=cmd.copy()
        changed[changed.index('--revision')+1]='b'*40
        with self.assertRaisesRegex(ValueError,'receipt identity'):
            build_fingerprint(changed,self.worker)
        self.assertTrue(first)
        self.assertIn('model/weights.safetensors',inv1['files'])

    def test_duplicate_and_relative_paths_rejected(self):
        args,cmd=self.setup_run()
        with self.assertRaisesRegex(ValueError,'repeated'):
            options(cmd+['--steps','500'])
        cmd[cmd.index('--train')+1]='relative.jsonl'
        with self.assertRaisesRegex(ValueError,'absolute'):
            build_fingerprint(cmd,self.worker)

    def test_margin_and_optimizer_timeout_must_fit(self):
        args,cmd=self.setup_run(wall=4,margin=4)
        with self.assertRaisesRegex(ValueError,'graceful-save margin'):
            run(args,cmd)
        args,cmd=self.setup_run(wall=4,margin=2)
        cmd += ['--max-seconds','3']
        with self.assertRaisesRegex(ValueError,'optimizer timeout'):
            run(args,cmd)

if __name__=='__main__': unittest.main()
