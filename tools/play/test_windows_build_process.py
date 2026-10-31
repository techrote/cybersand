#!/usr/bin/env python3
"""Portable deadline/evidence adversaries; actual Windows controls run separately."""
import copy
import ctypes
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import windows_build_process as owned
import run_windows_crash_capture as campaign


def synthetic_operation(directory, command, identity, cwd, *, mode='build', timeout=15):
    """Synthetic Windows facts for reducer tests, never an OS qualification."""
    directory.mkdir()
    child = mode in ('normal-child','orphan-hang')
    nonzero = mode == 'nonzero'
    timed_out = mode == 'orphan-hang'
    root = {'pid':10,'image':command[0],'created_100ns':1,'user_100ns':10,'kernel_100ns':20}
    secondary = root | {'pid':11,'created_100ns':2}
    first = {'root_pid':10,'active_processes':2 if child else 1,'total_processes':2 if child else 1,
             'job_user_100ns':20,'job_kernel_100ns':40,'active_observed':[root,secondary] if child else [root],
             'exited_observed':[],'job_empty':False,'log_bytes':0,'seconds':.1}
    exits = [root | {'exit_code':19 if nonzero else 0,'exit_observed':True}]
    if child:
        exits.append(secondary | {'exit_code':124 if timed_out else 0,'exit_observed':True})
    last = first | {'active_processes':0,'active_observed':[],'exited_observed':exits,'job_empty':True,
                    'seconds':2.4 if timed_out else .2,'log_bytes':40}
    launch = {'schema':owned.SCHEMA,'command':command,'cwd':cwd,'timeout_seconds':timeout,'identity':identity}
    owned.write_new(directory/'launch.json',launch)
    log = 'OWNED_NONZERO\n' if nonzero else 'OWNED_PARENT_CHILD 11\nOWNED_CHILD 11\n' if child else 'compiler control\n'
    (directory/'process.log').write_bytes(log.encode())
    samples = [first,last]
    (directory/'samples.jsonl').write_bytes(('\n'.join(json.dumps(r) for r in samples)+'\n').encode())
    result = {'schema':owned.SCHEMA,'status':'failed' if nonzero or timed_out else 'passed',
              'timeout_seconds':timeout,'cleanup_reserve_seconds':min(1.5,timeout/4),
              'seconds':2.5 if timed_out else .3,'root_pid':10,'root_exit':19 if nonzero else 0,
              'job_joined':True,'termination_requested':timed_out,'timed_out':timed_out,
              'termination_started_seconds':2.3 if timed_out else None,
              'error':None,'samples':samples,'creation_job_assigned':True,
              'launch_sha256':owned.digest(directory/'launch.json'),'log_sha256':owned.digest(directory/'process.log')}
    owned.write_new(directory/'result.json',result)
    return result


class Clock:
    def __init__(self):
        self.value = 0.0
        self.waits = []

    def now(self):
        return self.value

    def pause(self,seconds):
        self.waits.append(seconds)
        self.value += seconds


class ModelJob:
    root_pid = 10
    creation_job_assigned = True

    def __init__(self, *, hang=False, unjoined=False, code=0):
        self.hang,self.unjoined,self.code = hang,unjoined,code
        self.termination = None

    def snapshot(self):
        done = (not self.hang or self.termination is not None) and not self.unjoined
        return {'job_empty':done,'exited_observed':[{'pid':10,'exit_code':self.code}] if done else []}

    def terminate(self,code):
        self.termination = code


class OwnedBuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.command = ['C:\\compiler\\cl.exe','source.cpp']
        self.identity = {'source_sha256':'1'*64,'compiler':{'sha256':'2'*64}}
        self.cwd = 'C:\\out'

    def fixture(self,mode='build'):
        self.directory = self.root/'operation'
        self.result = synthetic_operation(self.directory,self.command,self.identity,self.cwd,
                                          mode=mode,timeout=3 if mode=='orphan-hang' else 15)

    def rewrite_result(self):
        (self.directory/'result.json').write_text(json.dumps(self.result))

    def rewrite_samples(self):
        (self.directory/'samples.jsonl').write_text('\n'.join(json.dumps(r) for r in self.result['samples'])+'\n')
        self.rewrite_result()

    def verify(self):
        return owned.verify(self.directory,self.command,self.identity,cwd=self.cwd)

    def test_fixed_x64_sdk_structure_layouts(self):
        self.assertEqual((ctypes.sizeof(owned.StartupEx),ctypes.sizeof(owned.ExtendedLimits),ctypes.sizeof(owned.Accounting)),(112,144,48))

    def test_deadline_reducer_preserves_positive_and_nonzero(self):
        for code in (0,19):
            clock = Clock()
            result = owned.monitor(ModelJob(code=code),0,15,lambda row:None,clock=clock.now,pause=clock.pause)
            self.assertEqual(result['root_exit'],code)
            self.assertEqual(result['status'],'passed' if code == 0 else 'failed')

    def test_deadline_reserves_cleanup_and_observes_join(self):
        clock, job = Clock(),ModelJob(hang=True)
        result = owned.monitor(job,0,3,lambda row:None,clock=clock.now,pause=clock.pause)
        self.assertEqual(result['status'],'failed')
        self.assertTrue(result['timed_out'] and result['job_joined'])
        self.assertEqual(job.termination,124)
        self.assertGreaterEqual(result['termination_started_seconds'],2.25)
        self.assertLessEqual(result['seconds'],3)
        self.assertTrue(all(wait <= owned.POLL_SECONDS for wait in clock.waits))

    def test_unobserved_cleanup_is_never_a_pass(self):
        clock = Clock()
        result = owned.monitor(ModelJob(hang=True,unjoined=True),0,3,lambda row:None,clock=clock.now,pause=clock.pause)
        self.assertFalse(result['job_joined'])
        self.assertEqual(result['status'],'failed')
        self.assertLessEqual(result['seconds'],3)

    def test_elapsed_clock_jump_cannot_restart_a_budget(self):
        clock = Clock()
        clock.value = 20
        result = owned.monitor(ModelJob(hang=True),0,15,lambda row:None,clock=clock.now,pause=clock.pause)
        self.assertEqual(result['status'],'failed')
        self.assertEqual(clock.waits,[])

    def test_launch_failure_preserves_prelaunch_identity(self):
        observed = []
        class FailingBackend:
            root_pid = None
            def start(self,command,cwd,environment,log):
                observed.append(json.loads((log.parent/'launch.json').read_bytes()))
                raise OSError('controlled launch refusal')
            def close(self):
                observed.append('closed')
        directory = self.root/'launch-failure'
        result = owned.run(self.command,self.cwd,{},directory,self.identity,backend=FailingBackend)
        self.assertEqual(result['status'],'failed')
        self.assertIn('controlled launch refusal',result['error'])
        self.assertEqual(observed[0]['identity'],self.identity)
        self.assertEqual(observed[-1],'closed')
        self.assertTrue((directory/'result.json').is_file())

    def test_build_timeout_keeps_compiler_and_source_receipt(self):
        compiler = self.root/'cl.exe'
        compiler.write_bytes(b'synthetic compiler identity')
        failure = {'status':'failed','timed_out':True,'root_exit':124,'job_joined':True}
        with mock.patch.object(campaign.shutil,'which',return_value=str(compiler)), \
             mock.patch.object(campaign.owned_build,'run',return_value=failure):
            with self.assertRaisesRegex(ValueError,'build failed or timed out'):
                campaign.build_tools(self.root,{})
        record = json.loads((self.root/'tools/build.json').read_bytes())
        self.assertEqual(record['compiler']['sha256'],hashlib.sha256(compiler.read_bytes()).hexdigest())
        row = record['builds'][0]
        self.assertEqual(row['result'],failure)
        self.assertEqual(row['identity']['source_sha256'],owned.digest(campaign.ROOT/row['identity']['source']))
        self.assertIn('/showIncludes',row['command'])
        self.assertIn('/WX',row['command'])

    def test_original_synthetic_positive_and_negative_controls_reduce(self):
        for mode in campaign.BUILD_CONTROL_MODES:
            directory = self.root/mode
            command = campaign.build_control_command('C:\\python.exe',mode)
            result = synthetic_operation(directory,command,self.identity,self.cwd,mode=mode,
                                         timeout=3 if mode=='orphan-hang' else 15)
            self.assertEqual(owned.verify(directory,command,self.identity,cwd=self.cwd),result)
            campaign.verify_build_control(mode,result,(directory/'process.log').read_text())

    def test_nonzero_child_cannot_hide_behind_zero_root(self):
        self.fixture('normal-child')
        self.result['samples'][-1]['exited_observed'][1]['exit_code'] = 9
        self.rewrite_samples()
        with self.assertRaisesRegex(ValueError,'false pass'):
            self.verify()

    def test_missing_join_or_changed_original_digest_rejected(self):
        self.fixture()
        self.result['job_joined'] = False
        self.rewrite_result()
        with self.assertRaisesRegex(ValueError,'ownership/cleanup'):
            self.verify()
        self.result['job_joined'] = True
        self.rewrite_result()
        (self.directory/'process.log').write_bytes(b'substituted')
        with self.assertRaisesRegex(ValueError,'original digest'):
            self.verify()

    def test_source_identity_and_working_directory_are_exact(self):
        self.fixture()
        with self.assertRaisesRegex(ValueError,'launch identity'):
            owned.verify(self.directory,self.command,{'source_sha256':'0'*64},cwd=self.cwd)
        with self.assertRaisesRegex(ValueError,'working directory'):
            owned.verify(self.directory,self.command,self.identity,cwd='C:\\other')

    def test_relabelled_timeout_does_not_pass(self):
        self.fixture('orphan-hang')
        self.result['timed_out'] = self.result['termination_requested'] = False
        self.result['termination_started_seconds'] = None
        self.result['status'] = 'passed'
        self.rewrite_result()
        with self.assertRaisesRegex(ValueError,'false pass'):
            self.verify()

    def test_reused_pid_and_regressing_cpu_are_refused(self):
        self.fixture()
        self.result['samples'][-1]['exited_observed'][0]['created_100ns'] = 3
        self.rewrite_samples()
        with self.assertRaisesRegex(ValueError,'PID creation identity'):
            self.verify()
        self.result['samples'][-1]['exited_observed'][0]['created_100ns'] = 1
        self.result['samples'][-1]['job_user_100ns'] = 0
        self.rewrite_samples()
        with self.assertRaisesRegex(ValueError,'progress regressed'):
            self.verify()

    def test_original_result_cannot_contain_duplicate_keys(self):
        self.fixture()
        path = self.directory/'result.json'
        path.write_text(path.read_text().replace('"status": "passed"','"status": "failed", "status": "passed"'))
        with self.assertRaisesRegex(ValueError,'Duplicate'):
            self.verify()


if __name__ == '__main__':
    unittest.main(verbosity=2)
