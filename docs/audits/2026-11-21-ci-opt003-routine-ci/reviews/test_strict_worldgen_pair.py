#!/usr/bin/env python3
"""Synthetic offline-reader regressions; no native execution/performance claim."""
import copy
import importlib.util
import json
from pathlib import Path
import shlex
import tempfile
import unittest

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('strict',HERE/'strict_worldgen_pair.py')
strict=importlib.util.module_from_spec(spec);spec.loader.exec_module(strict)
REPO=Path('/workspace/scratch/a3adba76fa99/ci003-proof-review')

def put(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,indent=2)+'\n')

def fixture(root):
    c=strict.load_contract(REPO)
    target='worldgen-sanitize'
    (root/'host.txt').write_text(f'proof_source={strict.PROOF} run=777 attempt=1\nSYNTHETIC READER FIXTURE\n')
    expected=list(c.expected_commands(True).values())
    tests=[c.showcase_loop(True),*[[f'./build/test_{n}_sanitized'] for n in c.TESTS]]
    for arm,sha,t0 in [('baseline',strict.BASE,10**18),('candidate',strict.CANDIDATE,10**18+90000000000)]:
        folder=root/arm;folder.mkdir()
        cwd='/tmp/'+arm;workspace='/workspace/host'
        wrapper=workspace+'/tools/ci/ci_opt003_proof/profile_cxx.py'
        rows=[]
        def row(kind,argv,start,finish):
            data={'schema':'cybersand-ci-opt003-command-v1','id':f'{len(rows)+1:032x}',
                  'kind':kind,'argv':argv,'cwd':cwd,'status':'passed','returncode':0,'signals':[],
                  'start_time_ns':t0+start,'end_time_ns':t0+finish,'elapsed_seconds':(finish-start)/1e9,
                  'child_user_seconds':0.7,'child_system_seconds':0.1,'max_child_rss_kib':100}
            rows.append(data)
        for i,cmd in enumerate(expected):
            start=(i+1)*1000000000;end=start+800000000
            row('compiler',['g++-13',*cmd[1:]],start,end)
            row('shell',['/bin/sh','-c',shlex.join([wrapper,*cmd[1:]])],start-10000000,end+10000000)
        for i,cmd in enumerate(tests):
            start=(40+i)*1000000000
            row('shell',['/bin/sh','-c',shlex.join(cmd)],start,start+800000000)
        for r in rows:put(folder/'commands'/(r['id']+'.json'),r)
        put(folder/'command-index.json',rows)
        ident={'commit':sha,'tree':strict.git(REPO,'rev-parse',sha+'^{tree}').decode().strip(),
               'tracked_status':'','makefile_sha256':strict.digest(strict.git(REPO,'show',sha+':Makefile'))}
        profile={'schema':'cybersand-ci-opt003-make-profile-v1','status':'passed','returncode':0,
                 'source_before':ident,'source_after':ident,'start_time_ns':t0,'end_time_ns':t0+60000000000,
                 'elapsed_seconds':60,'compiler_version':'g++-13 (SYNTHETIC reader fixture 13.3.0)',
                 'command':['make','--no-print-directory','-j2','CXX='+wrapper,
                            'SHELL='+workspace+'/tools/ci/ci_opt003_proof/profile_shell.py',target],
                 'sanitizer_environment':{'ASAN_OPTIONS':'detect_leaks=0:strict_string_checks=1','UBSAN_OPTIONS':'halt_on_error=1'},
                 'instrumentation_sha256':{name:strict.digest(strict.git(REPO,'show',strict.PROOF+':tools/ci/ci_opt003_proof/'+name)) for name in strict.WRAPPERS},
                 'compiler_command_count':28,'shell_command_count':38,
                 'verified_inventory':{'compiler_commands':expected,'test_commands':tests,'objects':12,'binaries':16,'test_executions':16}}
        put(folder/'profile.json',profile)
        watch=root/(arm+'-watchdog');watch.mkdir()
        stdout='SYNTHETIC READER FIXTURE\n'
        (folder/'stdout.log').write_text(stdout)
        (folder/'lines.jsonl').write_text(json.dumps({'time_ns':t0+1000,'line':'SYNTHETIC READER FIXTURE'})+'\n')
        summary={key:profile[key] for key in ('status','elapsed_seconds','returncode','compiler_command_count','shell_command_count')}
        (watch/'command.log').write_text(stdout+json.dumps(summary)+'\n')
        policy_path='godot/tests/support/ci_execution_policy.json'
        policy_bytes=strict.git(REPO,'show',strict.PROOF+':'+policy_path);policy=json.loads(policy_bytes)
        receipt={'schema':'execution-command-v1','status':'passed','returncode':0,'complete':True,
                 'natural_completion':True,'timed_out':False,'timeout_seconds':3600,'label':arm+'-'+target,
                 'execution_policy':{'schema_version':1,'policy_id':policy['policy_id'],'scale':1.0,
                                     'watchdogs':policy['watchdogs'],'advisories':policy['advisories'],
                                     'path':policy_path,'sha256':strict.digest(policy_bytes)},
                 'source':{'commit':strict.PROOF,'tree':strict.git(REPO,'rev-parse',strict.PROOF+'^{tree}').decode().strip(),
                           'tracked_delta_sha256':None,'run_id':'777','run_attempt':'1','job':'pair','runner_name_sha256':'f'*64},
                 'command':['python3',strict.PROFILE_PATH,'--source',cwd,'--output',workspace+'/build/proof/'+target+'/'+arm,
                            '--target',target,'--jobs','2','--cxx','g++-13'],'elapsed_seconds':65,
                 'log_sha256':strict.digest((watch/'command.log').read_bytes())}
        put(watch/'receipt.json',receipt)
        put(root/(arm+'-inventory.json'),{'status':'passed','source_revision':sha,'makefile_sha256':ident['makefile_sha256'],
             'families':{target:{'compile_link_commands':expected,'ordered_tests':[f'./build/test_{n}_sanitized' for n in (*c.SHOWCASES,*c.TESTS)]}}})

class StrictReaderTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='strict-worldgen-reader-')
        self.root=Path(self.temp.name);fixture(self.root)
    def tearDown(self):self.temp.cleanup()
    def verify(self):return strict.verify(self.root,REPO,'worldgen-sanitize',777,1)
    def mutate(self,relative,fn):
        p=self.root/relative;data=json.loads(p.read_text());fn(data);put(p,data)
    def mutate_raw(self,index,fn):
        p=self.root/'baseline/command-index.json';rows=json.loads(p.read_text())
        fn(rows[index]);put(p,rows);put(self.root/'baseline/commands'/(rows[index]['id']+'.json'),rows[index])
    def test_complete_reader_fixture(self):self.assertEqual(self.verify()['status'],'passed')
    def test_index_omits_test_receipts(self):
        self.mutate('baseline/command-index.json',lambda rows:rows.__delitem__(slice(56,None)))
        with self.assertRaisesRegex(ValueError,'Raw command files differ'):self.verify()
    def test_index_and_raw_both_omit_test_receipts(self):
        rows=json.loads((self.root/'baseline/command-index.json').read_text())
        for r in rows[56:]:(self.root/'baseline/commands'/(r['id']+'.json')).unlink()
        put(self.root/'baseline/command-index.json',rows[:56])
        with self.assertRaisesRegex(ValueError,'Actual test receipts missing'):self.verify()
    def test_changed_compiler_argv(self):
        self.mutate_raw(0,lambda row:row['argv'].insert(1,'-fno-sanitize=all'))
        with self.assertRaisesRegex(ValueError,'Actual compiler arguments'):self.verify()
    def test_wrong_source_cwd(self):
        self.mutate_raw(0,lambda row:row.update(cwd='/different-source-and-run'))
        with self.assertRaisesRegex(ValueError,'wrong-source'):self.verify()
    def test_incomplete_command(self):
        self.mutate_raw(0,lambda row:row.update(status='started'))
        with self.assertRaisesRegex(ValueError,'did not pass'):self.verify()
    def test_signaled_command(self):
        self.mutate_raw(0,lambda row:row.update(signals=[15]))
        with self.assertRaisesRegex(ValueError,'Signaled'):self.verify()
    def test_missing_raw_receipt(self):
        next((self.root/'baseline/commands').glob('*.json')).unlink()
        with self.assertRaisesRegex(ValueError,'Raw command files differ'):self.verify()
    def test_tampered_original_log(self):
        (self.root/'baseline-watchdog/command.log').write_text('replacement log')
        with self.assertRaisesRegex(ValueError,'missing/corrupt'):self.verify()
    def test_timeout_receipt(self):
        self.mutate('baseline-watchdog/receipt.json',lambda d:d.update(timed_out=True))
        with self.assertRaisesRegex(ValueError,'Incomplete/timeout'):self.verify()
    def test_failed_receipt(self):
        self.mutate('baseline-watchdog/receipt.json',lambda d:d.update(status='failed',returncode=17))
        with self.assertRaisesRegex(ValueError,'did not pass'):self.verify()
    def test_stale_run_attempt(self):
        self.mutate('baseline-watchdog/receipt.json',lambda d:d['source'].update(run_attempt='2'))
        with self.assertRaisesRegex(ValueError,'Stale run/attempt'):self.verify()
    def test_wrong_source_commit(self):
        self.mutate('baseline/profile.json',lambda d:d['source_before'].update(commit=strict.CANDIDATE))
        with self.assertRaisesRegex(ValueError,'source/tree/Makefile'):self.verify()
    def test_summary_omits_original_command(self):
        self.mutate('baseline/profile.json',lambda d:d['verified_inventory']['compiler_commands'].pop())
        with self.assertRaisesRegex(ValueError,'Profile summary differs'):self.verify()
    def test_changed_make_stdout(self):
        (self.root/'baseline/stdout.log').write_text('Changed source output\n')
        with self.assertRaisesRegex(ValueError,'Make stdout/profile summary differs'):self.verify()
    def test_changed_watchdog_policy(self):
        self.mutate('baseline-watchdog/receipt.json',lambda d:d['execution_policy'].update(scale=2))
        with self.assertRaisesRegex(ValueError,'Changed execution watchdog policy'):self.verify()
    def test_different_worker(self):
        self.mutate('candidate-watchdog/receipt.json',lambda d:d['source'].update(runner_name_sha256='e'*64))
        with self.assertRaisesRegex(ValueError,'different worker'):self.verify()
    def test_temp_receipt_is_refused(self):
        (self.root/'baseline/commands/incomplete.tmp').write_text('{}')
        with self.assertRaisesRegex(ValueError,'Incomplete/unexpected'):self.verify()

if __name__=='__main__': unittest.main()
