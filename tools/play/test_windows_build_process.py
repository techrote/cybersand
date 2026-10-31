#!/usr/bin/env python3
"""Portable deadline/evidence adversaries; actual Windows controls run separately."""
import copy
import ctypes
import contextlib
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

import windows_build_process as owned
import run_windows_crash_capture as campaign


def synthetic_operation(directory, command, identity, cwd, *, mode='build', timeout=campaign.policy.OPERATION_SECONDS):
    """Synthetic Windows facts for reducer tests, never an OS qualification."""
    directory.mkdir()
    child = mode in ('normal-child','orphan-hang','slow-child','late-child-failure')
    nonzero = mode in ('nonzero','late-child-failure')
    slow = mode in ('slow-child','late-child-failure')
    timed_out = mode == 'orphan-hang'
    root = {'pid':10,'image':command[0],'created_100ns':1,'user_100ns':10,'kernel_100ns':20}
    secondary = root | {'pid':11,'created_100ns':2}
    first = {'root_pid':10,'active_processes':2 if child else 1,'total_processes':2 if child else 1,
             'job_user_100ns':20,'job_kernel_100ns':40,'active_observed':[root,secondary] if child else [root],
             'exited_observed':[],'job_empty':False,'log_bytes':0,'seconds':.1}
    exits = [root | {'exit_code':19 if nonzero else 0,'exit_observed':True}]
    if child:
        exits.append(secondary | {'exit_code':124 if timed_out else 19 if nonzero else 0,'exit_observed':True})
    last = first | {'active_processes':0,'active_observed':[],'exited_observed':exits,'job_empty':True,
                    'seconds':2.4 if timed_out else campaign.SLOW_CONTROL_SECONDS+.2 if slow else .2,'log_bytes':40}
    launch = {'schema':owned.SCHEMA,'command':command,'cwd':cwd,'timeout_seconds':timeout,'identity':identity}
    owned.write_new(directory/'launch.json',launch)
    log = 'OWNED_PARENT_CHILD 11\nOWNED_CHILD 11\n' if child else 'OWNED_NONZERO\n' if nonzero else 'compiler control\n'
    (directory/'process.log').write_bytes(log.encode())
    samples = [first,last]
    (directory/'samples.jsonl').write_bytes(('\n'.join(json.dumps(r) for r in samples)+'\n').encode())
    result = {'schema':owned.SCHEMA,'status':'failed' if nonzero or timed_out else 'passed',
              'timeout_seconds':timeout,'cleanup_reserve_seconds':min(campaign.policy.CLEANUP_SECONDS,timeout/4),
              'seconds':2.5 if timed_out else campaign.SLOW_CONTROL_SECONDS+.3 if slow else .3,'root_pid':10,'root_exit':19 if nonzero else 0,
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
                                          mode=mode,timeout=campaign.policy.ORPHAN_CONTROL_SECONDS if mode=='orphan-hang' else campaign.policy.OPERATION_SECONDS)

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

    def test_slow_success_and_late_failure_survive_old_deadline_and_sample_cap(self):
        for code in (0,19):
            with self.subTest(code=code):
                clock = Clock()
                class DelayedJob(ModelJob):
                    def snapshot(self):
                        self.hang = clock.value < 30
                        return super().snapshot()
                job = DelayedJob(code=code)
                result = owned.monitor(job,0,campaign.policy.OPERATION_SECONDS,lambda row:None,
                                       clock=clock.now,pause=clock.pause)
                self.assertGreaterEqual(result['seconds'],30)
                self.assertGreater(len(result['samples']),160)
                self.assertEqual(result['status'],'passed' if code == 0 else 'failed')
                self.assertEqual(result['root_exit'],code)
                self.assertFalse(result['timed_out'] or result['termination_requested'])
                self.assertTrue(result['job_joined'])

    def test_full_watchdog_hang_terminates_and_joins_without_sample_cutoff(self):
        clock, job = Clock(),ModelJob(hang=True)
        result = owned.monitor(job,0,campaign.policy.OPERATION_SECONDS,lambda row:None,
                               clock=clock.now,pause=clock.pause)
        self.assertTrue(result['timed_out'] and result['job_joined'])
        self.assertEqual(result['status'],'failed')
        self.assertGreaterEqual(result['termination_started_seconds'],
                                campaign.policy.OPERATION_SECONDS-campaign.policy.CLEANUP_SECONDS)
        self.assertGreater(len(result['samples']),160)
        self.assertLessEqual(result['seconds'],campaign.policy.OPERATION_SECONDS)

    def test_invalid_watchdog_cannot_create_an_unbounded_operation(self):
        for timeout in (0,-1,float('nan'),float('inf'),True,campaign.policy.OPERATION_SECONDS+1):
            with self.subTest(timeout=timeout), self.assertRaisesRegex(ValueError,'watchdog'):
                owned.sample_limit(timeout)

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
        failure = {'status':'failed','timed_out':True,'root_exit':124,'job_joined':True}
        with mock.patch.object(campaign,'verify_tool_files'), \
             mock.patch.object(campaign,'probe_toolchain'), \
             mock.patch.object(campaign.owned_build,'run',return_value=failure):
            with self.assertRaisesRegex(ValueError,'compile failed or timed out'):
                campaign.build_tools(self.root,{})
        record = json.loads((self.root/'tools/build.json').read_bytes())
        self.assertEqual(record['toolchain'],campaign.TOOLCHAIN)
        row = record['builds'][0]['phases'][0]
        self.assertEqual(row['result'],failure)
        self.assertEqual(row['status'],'failed')
        self.assertEqual(row['identity']['source_sha256'],owned.digest(campaign.ROOT/row['identity']['source']))
        self.assertIn('/showIncludes',row['command'])
        self.assertIn('/WX',row['command'])
        self.assertIn('/DCYBERSAND_CRASH_CAPTURE_LIMIT_MS='+str(campaign.policy.CAPTURE_MS),row['command'])
        self.assertIn('/DCYBERSAND_CRASH_MAX_CASE_MS='+str(campaign.policy.FIXTURE_MS),row['command'])

    def test_tool_version_timeout_is_retained_before_any_compilation(self):
        failure = {'status':'failed','timed_out':True,'root_exit':124,'job_joined':True}
        with mock.patch.object(campaign,'verify_tool_files'), \
             mock.patch.object(campaign.owned_build,'run',return_value=failure):
            with self.assertRaisesRegex(ValueError,'version failed or timed out'):
                campaign.build_tools(self.root,{})
        record=json.loads((self.root/'tools/build.json').read_bytes())
        self.assertEqual(record['builds'],[])
        self.assertEqual(record['probes'][0]['result'],failure)
        self.assertEqual(record['probes'][0]['status'],'failed')

    def test_short_unobserved_child_cannot_qualify_new_llvm_operation(self):
        self.fixture()
        self.result['samples'][-1]['total_processes']=2
        self.rewrite_samples()
        # Historical v2 promises containment plus observed exits only.
        self.assertEqual(self.verify()['status'],'passed')
        with self.assertRaisesRegex(ValueError,'unobserved process exit'):
            campaign.verify_complete_tool_exits(self.result)

    def test_compiler_overrides_are_removed_only_from_build_environment(self):
        original={'INCLUDE':'sdk includes','LIB':'sdk libraries','PATH':'sdk tools','CL':'/DUNDECLARED',
                  '_cl_':'/DUNDECLARED_TOO','CCC_OVERRIDE_OPTIONS':'^--config=unknown.cfg',
                  'CLANG_CONFIG_FILE_USER_DIR':'untrusted configs','LINK':'/FORCE'}
        clean,removed=campaign.build_environment(original)
        self.assertEqual(clean,{'INCLUDE':'sdk includes','LIB':'sdk libraries','PATH':'sdk tools'})
        self.assertEqual(set(removed),set(original)-set(clean))
        self.assertIn('CL',original)

    def test_pinned_tool_files_reject_same_size_substitution(self):
        pins=copy.deepcopy(campaign.TOOLCHAIN)
        for role in ('compiler','linker'):
            path=self.root/(role+'.exe');path.write_bytes(role.encode())
            pins[role]={'path':str(path),'bytes':path.stat().st_size,'sha256':owned.digest(path)}
        with mock.patch.object(campaign,'TOOLCHAIN',pins):
            campaign.verify_tool_files()
            Path(pins['linker']['path']).write_bytes(b'X'*pins['linker']['bytes'])
            observed={}
            with self.assertRaisesRegex(ValueError,'Pinned LLVM linker executable'):
                campaign.verify_tool_files(observed)
            self.assertEqual(observed['linker']['sha256'],owned.digest(Path(pins['linker']['path'])))

    def test_inconsistent_size_and_hash_pin_retains_observation_without_launch(self):
        # The first LLVM pin accidentally paired an archive-declared full size
        # with a truncated extraction's digest. Neither the full file nor the
        # truncated file may qualify against that inconsistent declaration.
        complete=b'complete official executable';truncated=complete[:-7]
        compiler=self.root/'compiler.exe';compiler.write_bytes(truncated)
        pins=copy.deepcopy(campaign.TOOLCHAIN)
        pins['compiler']={'path':str(compiler),'bytes':len(complete),'sha256':owned.digest(compiler)}
        for label,contents in (('complete',complete),('truncated',truncated)):
            output=self.root/label;output.mkdir();compiler.write_bytes(contents)
            with self.subTest(label=label),mock.patch.object(campaign,'TOOLCHAIN',pins), \
                 mock.patch.object(campaign.owned_build,'run') as launch:
                with self.assertRaisesRegex(ValueError,'Pinned LLVM compiler executable'):
                    campaign.build_tools(output,{})
                launch.assert_not_called()
            record=json.loads((output/'tools/build.json').read_bytes())
            self.assertEqual(record['toolchain'],pins)
            self.assertEqual(record['observed_tools'],{'compiler':{
                'path':str(compiler),'bytes':len(contents),'sha256':owned.digest(compiler)}})
            self.assertEqual(record['probes'],[])
            self.assertEqual(record['builds'],[])

    def test_versions_require_both_exact_release_and_x64_msvc_target(self):
        campaign.verify_tool_version('compiler','clang version 20.1.8\nTarget: x86_64-pc-windows-msvc\n')
        campaign.verify_tool_version('linker','LLD 20.1.8\n')
        for role,log in (('compiler','clang version 20.1.7\nTarget: x86_64-pc-windows-msvc\n'),
                         ('compiler','clang version 20.1.8\nTarget: i686-pc-windows-msvc\n'),
                         ('linker','LLD 20.1.9\n')):
            with self.subTest(role=role,log=log),self.assertRaisesRegex(ValueError,'version differs|target differs'):
                campaign.verify_tool_version(role,log)

    def test_original_synthetic_positive_and_negative_controls_reduce(self):
        for mode in campaign.BUILD_CONTROL_MODES:
            directory = self.root/mode
            command = campaign.build_control_command('C:\\python.exe',mode)
            result = synthetic_operation(directory,command,self.identity,self.cwd,mode=mode,
                                         timeout=campaign.policy.ORPHAN_CONTROL_SECONDS if mode=='orphan-hang' else campaign.policy.OPERATION_SECONDS)
            self.assertEqual(owned.verify(directory,command,self.identity,cwd=self.cwd),result)
            campaign.verify_build_control(mode,result,(directory/'process.log').read_text())

    def test_slow_commands_wait_then_propagate_actual_child_exit(self):
        for mode,code in (('slow-child',0),('late-child-failure',19)):
            child=mock.Mock(pid=11);child.wait.return_value=code
            command=campaign.build_control_command('C:\\python.exe',mode)
            with mock.patch('subprocess.Popen',return_value=child) as launch, \
                 mock.patch('subprocess.DETACHED_PROCESS',0x8,create=True), \
                 contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as exited:
                exec(compile(command[2],'<slow-control>','exec'),{})
            self.assertEqual(exited.exception.code,code)
            child_script=launch.call_args.args[0][2]
            with mock.patch('time.sleep') as delay, contextlib.redirect_stdout(io.StringIO()), \
                 self.assertRaises(SystemExit) as child_exit:
                exec(compile(child_script,'<slow-child>','exec'),{})
            delay.assert_called_once_with(campaign.SLOW_CONTROL_SECONDS)
            self.assertEqual(child_exit.exception.code,code)

    def test_slow_control_receipt_cannot_relabel_fast_execution(self):
        self.fixture('slow-child')
        self.result['seconds']=1
        self.result['samples'][-1]['seconds']=.9
        with self.assertRaisesRegex(ValueError,'former watchdog'):
            campaign.verify_build_control('slow-child',self.result,(self.directory/'process.log').read_text())

    def test_late_child_failure_cannot_hide_behind_successful_parent(self):
        self.fixture('late-child-failure')
        self.result['root_exit']=0
        with self.assertRaisesRegex(ValueError,'termination code'):
            campaign.verify_build_control('late-child-failure',self.result,(self.directory/'process.log').read_text())

    def test_root_detaches_console_without_changing_owned_job_or_standard_handles(self):
        # Exercise the real launch assembly against a mocked Win32 API. This
        # proves construction only; the actual Windows inventory is mandatory.
        api, observed = mock.Mock(), {}
        api.CreateJobObjectW.return_value = 11
        api.CreateFileW.side_effect = [22,23]
        api.ResumeThread.return_value = 1
        def limits(_job,kind,pointer,_size):
            value = ctypes.cast(pointer,ctypes.POINTER(owned.ExtendedLimits)).contents
            observed['limits'] = (kind,value.basic.flags,value.basic.active_process_limit)
            return True
        def initialize(attributes,count,_flags,size):
            ctypes.cast(size,ctypes.POINTER(owned.U)).contents.value = 64
            observed.setdefault('attribute_counts',[]).append(count)
            return attributes is not None
        def attribute(_attributes,_flags,kind,value,_size,_previous,_returned):
            observed[kind] = tuple(value)
            return True
        def create(_application,_command,_process_security,_thread_security,inherit,flags,
                   _environment,_cwd,startup_pointer,info_pointer):
            startup = ctypes.cast(startup_pointer,ctypes.POINTER(owned.StartupEx)).contents
            observed['creation'] = (inherit,flags,startup.startup.flags,startup.startup.stdin,
                                    startup.startup.stdout,startup.startup.stderr)
            observed['attributes_before_create'] = (observed[0x2000D],observed[0x20002])
            info = ctypes.cast(info_pointer,ctypes.POINTER(owned.ProcessInfo)).contents
            info.process,info.thread,info.pid,info.tid = 101,102,10,20
            return True
        api.SetInformationJobObject.side_effect = limits
        api.InitializeProcThreadAttributeList.side_effect = initialize
        api.UpdateProcThreadAttribute.side_effect = attribute
        api.CreateProcessW.side_effect = create
        with mock.patch.object(owned.sys,'platform','win32'), \
             mock.patch.object(owned.C,'WinDLL',return_value=api,create=True):
            job = owned.WindowsJob()
            job.start(self.command,self.cwd,{'CONTROL':'owned'},self.root/'root.log')
        self.assertEqual(observed['creation'],(True,0x8 | 0x4 | 0x80000 | 0x400,0x100,23,22,22))
        self.assertEqual(observed['limits'],(9,0x2000 | 0x8,owned.MAX_PROCESSES))
        self.assertEqual(observed['attribute_counts'],[2,2])
        self.assertEqual(observed['attributes_before_create'],((11,),(23,22)))
        calls = [call[0] for call in api.method_calls]
        self.assertLess(calls.index('CreateProcessW'),calls.index('ResumeThread'))
        self.assertTrue(job.creation_job_assigned)
        self.assertEqual((job.root_pid,job.handles),(10,{10:101}))
        self.assertEqual(api.CloseHandle.call_args_list,[mock.call(102),mock.call(23),mock.call(22)])

    def test_child_control_explicitly_detaches_console_and_redirects_standard_streams(self):
        # Portable command-construction proof only; real Windows must still
        # establish the unchanged exact two-process inventory and join.
        for mode in ('normal-child','orphan-hang'):
            child = mock.Mock(pid=11)
            child.wait.return_value = 0
            command = campaign.build_control_command('C:\\python.exe',mode)
            output = io.StringIO()
            with mock.patch('subprocess.Popen',return_value=child) as launch, \
                 mock.patch('subprocess.DETACHED_PROCESS',0x8,create=True), \
                 mock.patch('subprocess.CREATE_NO_WINDOW',0x08000000,create=True), \
                 mock.patch('time.sleep'), contextlib.redirect_stdout(output):
                if mode == 'normal-child':
                    with self.assertRaises(SystemExit) as exited:
                        exec(compile(command[2],'<owned-control>','exec'),{})
                    self.assertEqual(exited.exception.code,0)
                else:
                    exec(compile(command[2],'<owned-control>','exec'),{})
            self.assertEqual(launch.call_count,1)
            self.assertEqual(launch.call_args.kwargs,{'creationflags':0x8,'stdin':sys.stdin,
                             'stdout':output,'stderr':sys.stderr,'close_fds':True})
            self.assertEqual(launch.call_args.args[0][:2],[sys.executable,'-c'])
            self.assertIn('print("OWNED_CHILD " + str(os.getpid()), flush=True)',launch.call_args.args[0][2])
            self.assertIn('time.sleep('+('20' if mode=='orphan-hang' else '0.4')+')',launch.call_args.args[0][2])
            self.assertEqual(child.wait.call_count,1 if mode == 'normal-child' else 0)

    def test_extra_process_still_fails_the_exact_control_inventory(self):
        self.fixture('normal-child')
        for total in (3,4):
            with self.subTest(total=total):
                self.result['samples'][-1]['total_processes'] = total
                with self.assertRaisesRegex(ValueError,'Build ownership control requires exactly two processes'):
                    campaign.verify_build_control('normal-child',self.result,
                                                  (self.directory/'process.log').read_text())

    def test_missing_child_execution_marker_is_refused(self):
        self.fixture('normal-child')
        with self.assertRaisesRegex(ValueError,'Build child execution marker missing or duplicated'):
            campaign.verify_build_control('normal-child',self.result,'OWNED_PARENT_CHILD 11\n')

    def test_duplicate_child_execution_marker_is_refused(self):
        self.fixture('normal-child')
        with self.assertRaisesRegex(ValueError,'Build child execution marker missing or duplicated'):
            campaign.verify_build_control('normal-child',self.result,
                                          'OWNED_PARENT_CHILD 11\nOWNED_CHILD 11\nOWNED_CHILD 11\n')

    def test_mismatched_child_execution_marker_is_refused(self):
        self.fixture('normal-child')
        with self.assertRaisesRegex(ValueError,'Build child execution marker PID mismatch'):
            campaign.verify_build_control('normal-child',self.result,'OWNED_PARENT_CHILD 11\nOWNED_CHILD 12\n')

    def test_child_execution_marker_may_precede_parent_marker(self):
        self.fixture('normal-child')
        campaign.verify_build_control('normal-child',self.result,'OWNED_CHILD 11\nOWNED_PARENT_CHILD 11\n')

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
