"""Adverse controls for retained evidence custody and a real reader subprocess.

The committed miniature reader is an apparatus control, not PLAY qualification.
It exercises the same source/receipt interface while actual scientific readers
remain responsible for the real packets, owners and physical sample contracts.
"""

from dataclasses import replace
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import execution_policy
import run_godot_regressions as runner
import verify_retained_play_readback as subject


READER = '''import argparse
import hashlib
import json
from pathlib import Path
import time

parser = argparse.ArgumentParser()
for key in ('result','log','process-json','source','rig','platform','output'):
    parser.add_argument('--' + key, required=True)
parser.add_argument('--self-test', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
record = json.loads(Path(args.result).read_text())
if record.get('semantic_valid') is not True or not args.self_test:
    raise SystemExit(19)
if record.get('packet'):
    packet = Path(args.result).parent / record['packet']
    if not packet.is_file() or digest(packet) != record['packet_sha256']:
        raise SystemExit(19)
if record.get('mode') == 'empty-success':
    raise SystemExit(0)
time.sleep(record.get('sleep_seconds', 0))
dependency = root / 'tools/ci/control_dependency.py'
reduced = {'status':'passed','source_revision':args.source,'rig':args.rig,
    'platform':args.platform,'passed_samples':3,'completed_steps':4,
    'graphical_qualification':False,
    'adverse_controls':[{'name':'first','rejected_for':'bad_first'},
                        {'name':'second','rejected_for':'bad_second'}],
    'execution_policy':json.loads((root/'policy-identity.json').read_text()),
    'process_sha256':digest(args.process_json),'log_sha256':digest(args.log),
    record['digest_field']:digest(args.result),
    'consumed_source_sha256':{'dependency_sha256':digest(dependency)},
    'verifier_sha256':digest(__file__)}
Path(args.output).write_text(json.dumps(reduced))
print(json.dumps(reduced))
if record.get('mutate_input'):
    Path(args.result).write_text('{}')
if record.get('mutate_source'):
    dependency.write_text('changed after reduction\\n')
'''


class RetainedReadbackTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.repo = self.root / 'source'
        (self.repo / 'tools/ci').mkdir(parents=True)
        self.script = self.repo / 'tools/ci/control_reader.py'
        self.script.write_text(READER, encoding='utf-8')
        (self.repo / 'tools/ci/control_dependency.py').write_text('control = 1\n', encoding='utf-8')
        (self.repo / 'policy-identity.json').write_text(json.dumps(execution_policy.identity()))
        for command in (
            ['git','init','--quiet',str(self.repo)],
            ['git','-C',str(self.repo),'add','.'],
            ['git','-C',str(self.repo),'-c','user.name=Control','-c','user.email=control@example.invalid',
             '-c','commit.gpgsign=false','commit','--quiet','-m','Retained reader control'],
        ):
            subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.source = subprocess.check_output(['git','-C',str(self.repo),'rev-parse','HEAD'], text=True).strip()
        self.contract = runner.ReadbackContract('CONTROL','test_play_control_',
            'tools/ci/control_reader.py','control',
            (('status','passed'),('passed_samples',3),('graphical_qualification',False)),
            (('adverse_controls',2),), minimum_values=(('completed_steps',4),),
            arguments=('--rig','{rig}','--platform','{platform}'),
            source_inputs=('tools/ci/control_dependency.py','policy-identity.json'),
            consumed_source_fields=(('dependency_sha256','tools/ci/control_dependency.py'),),
            verifier_digest_field='verifier_sha256')
        self.case = runner.Case('test_play_control_jetbarrel',
            ('--script','res://tests/test_play_control_jetbarrel.gd'),3940,1)
        self.directory = self.root / 'shard'
        self.directory.mkdir()
        self.root_patch = mock.patch.object(runner,'ROOT',self.repo)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)
        self.contract_patch = mock.patch.object(runner,'case_readback_contract',side_effect=lambda case:self.contract)
        self.contract_patch.start()
        self.addCleanup(self.contract_patch.stop)
        self.sequence = 0
        self.prepare_original()

    def identity(self, path):
        value = subject.digest(self.repo / path)
        return {'path':path,'source_revision':self.source,'actual_sha256':value,'canonical_sha256':value}

    def prepare_original(self, platform='Linux', embedded=False):
        self.platform = platform
        if embedded:
            self.contract = replace(self.contract,embedded_marker='CONTROL_RESULT ',result_digest_field='raw_result_sha256')
        base = self.case.name + '-readback/'
        self.relative = {'process':base+'engine-process.json','log':self.case.name+'.log',
            'result':base+'raw-result.json' if embedded else self.case.name+'-artifacts/jetbarrel-control.json',
            'output':base+'verified.json','verifier_log':base+'verifier-output.txt'}
        self.paths = {key:self.directory/path for key,path in self.relative.items()}
        for path in self.paths.values():
            path.parent.mkdir(parents=True,exist_ok=True)
        self.raw = {'semantic_valid':True,'digest_field':self.contract.result_digest_field}
        if not embedded:
            packet = self.paths['result'].parent/'packet.bin'
            packet.write_bytes(b'retained packet control\x00\x01')
            self.raw.update(packet=packet.name,packet_sha256=subject.digest(packet))
        self.row = {'name':self.case.name,'role':'case','status':'passed','returncode':0,
            'natural_completion':True,'execution_policy':execution_policy.identity(),
            'seconds':25,'timeout_seconds':self.case.timeout,'requires_display':False,
            'command':['Godot','--headless','--path',str(self.repo/'godot'),*self.case.flags],
            'log':self.relative['log']}
        self.write_raw()
        self.row['log_sha256'] = subject.digest(self.paths['log'])
        self.paths['process'].write_text(json.dumps(self.row))
        command = [sys.executable,str(self.script),'--result',str(self.paths['result']),
            '--log',str(self.paths['log']),'--process-json',str(self.paths['process']),
            '--source',self.source,'--rig','jetbarrel','--platform',platform,
            '--self-test','--output',str(self.paths['output'])]
        with self.paths['verifier_log'].open('w') as log:
            subprocess.run(command,check=True,stdout=log,stderr=subprocess.STDOUT)
        self.row['independent_evidence'] = {'status':'passed','returncode':0,'error':None,
            'seconds':25,'timeout_seconds':execution_policy.watchdog_seconds('operation_seconds'),
            'receipt':self.relative['process'],'output':self.relative['output'],
            'verifier_log':self.relative['verifier_log'],'command':command,
            'input_sha256':{key:subject.digest(self.paths[key]) for key in ('process','log','result')},
            'receipt_sha256':subject.digest(self.paths['process']),
            'output_sha256':subject.digest(self.paths['output']),
            'verifier_log_sha256':subject.digest(self.paths['verifier_log']),
            'verifier_identity':self.identity(self.contract.verifier),
            'source_input_identity':{path:self.identity(path) for path in self.contract.source_inputs}}
        if embedded:
            self.row['independent_evidence']['raw_result'] = self.relative['result']

    def write_raw(self):
        value = json.dumps(self.raw)
        self.paths['result'].write_text(value)
        self.paths['log'].write_text((self.contract.embedded_marker or 'CONTROL_RESULT ') + value + '\n')

    def alter_reduced(self, change):
        value = json.loads(self.paths['output'].read_text())
        change(value)
        self.paths['output'].write_text(json.dumps(value))
        self.row['independent_evidence']['output_sha256'] = subject.digest(self.paths['output'])

    def forge_raw_with_self_consistent_seals(self, **changes):
        self.raw.update(changes)
        self.write_raw()
        self.row['log_sha256'] = subject.digest(self.paths['log'])
        engine = {key:value for key,value in self.row.items() if key != 'independent_evidence'}
        self.paths['process'].write_text(json.dumps(engine))
        readback = self.row['independent_evidence']
        readback['input_sha256'] = {key:subject.digest(self.paths[key]) for key in ('process','log','result')}
        readback['receipt_sha256'] = readback['input_sha256']['process']
        self.alter_reduced(lambda value:value.update({
            self.contract.result_digest_field:readback['input_sha256']['result'],
            'log_sha256':readback['input_sha256']['log'],'process_sha256':readback['input_sha256']['process']}))

    def verify(self):
        self.sequence += 1
        return subject.verify(self.case,self.row,self.directory,self.source,self.platform,
                              output_dir=self.root/'coverage'/str(self.sequence))

    def test_real_reader_passes_and_preserves_every_original_byte(self):
        originals = {path:path.read_bytes() for path in self.directory.rglob('*') if path.is_file()}
        result = self.verify()
        self.assertEqual(result['status'],'passed')
        self.assertTrue(result['complete'])
        self.assertEqual(result['returncode'],0)
        self.assertIn('--self-test',result['command'])
        self.assertEqual(originals,{path:path.read_bytes() for path in originals})

    def test_exact_embedded_raw_payload_is_reverified(self):
        self.prepare_original(embedded=True)
        self.assertEqual(self.verify()['status'],'passed')

    def test_arbitrary_output_with_self_consistent_hash_cannot_pass(self):
        self.alter_reduced(lambda value:(value.clear(),value.update(arbitrary='not a verified result')))
        with self.assertRaisesRegex(ValueError,'source or rig'):
            self.verify()

    def test_missing_receipt_raw_result_log_or_verifier_log_cannot_pass(self):
        for name in ('process','result','log','verifier_log','output'):
            path = self.paths[name]
            original = path.read_bytes()
            path.unlink()
            with self.subTest(name=name),self.assertRaisesRegex(ValueError,'Missing retained'):
                self.verify()
            path.write_bytes(original)

    def test_changed_original_hash_is_rejected(self):
        self.paths['verifier_log'].write_text('replacement output')
        with self.assertRaisesRegex(ValueError,'digest mismatch'):
            self.verify()

    def test_missing_original_packet_is_rejected_by_the_real_reader(self):
        (self.paths['result'].parent/'packet.bin').unlink()
        with self.assertRaisesRegex(ValueError,'reader rejected'):
            self.verify()

    def test_changed_original_packet_is_rejected_by_the_real_reader(self):
        (self.paths['result'].parent/'packet.bin').write_bytes(b'substitute')
        with self.assertRaisesRegex(ValueError,'reader rejected'):
            self.verify()

    def test_engine_process_receipt_must_equal_original_case_row(self):
        self.row['seconds'] += 1
        with self.assertRaisesRegex(ValueError,'receipt differs'):
            self.verify()

    def test_original_error_or_unnatural_completion_cannot_pass(self):
        for key,value in (('returncode',19),('natural_completion',False),('timeout_kind','case_deadline')):
            original = dict(self.row)
            self.row[key] = value
            with self.subTest(key=key),self.assertRaisesRegex(ValueError,'engine process'):
                self.verify()
            self.row = original

    def test_wrong_source_dependency_or_verifier_identity_cannot_pass(self):
        for record,key in ((self.row['independent_evidence']['verifier_identity'],'source_revision'),
                           (self.row['independent_evidence']['source_input_identity']['tools/ci/control_dependency.py'],'canonical_sha256')):
            original = record[key]
            record[key] = '0' * len(original)
            with self.subTest(key=key),self.assertRaisesRegex(ValueError,'source identity mismatch'):
                self.verify()
            record[key] = original

    def test_current_reader_source_drift_is_refused(self):
        self.script.write_text(READER+'\n# uncommitted modification\n')
        with self.assertRaisesRegex(ValueError,'differs from committed'):
            self.verify()

    def test_missing_or_duplicate_controls_cannot_pass(self):
        for change in (lambda value:value['adverse_controls'].pop(),
                       lambda value:value['adverse_controls'][1].update(name='first')):
            original = self.paths['output'].read_bytes()
            self.alter_reduced(change)
            with self.assertRaisesRegex(ValueError,'control inventory'):
                self.verify()
            self.paths['output'].write_bytes(original)
            self.row['independent_evidence']['output_sha256'] = subject.digest(self.paths['output'])

    def test_boolean_cannot_replace_required_count(self):
        self.alter_reduced(lambda value:value.update(passed_samples=True))
        with self.assertRaisesRegex(ValueError,'required result'):
            self.verify()

    def test_forged_reason_cannot_replace_the_fresh_adverse_control(self):
        self.alter_reduced(lambda value:value['adverse_controls'][0].update(rejected_for='invented'))
        with self.assertRaisesRegex(ValueError,'differs from retained'):
            self.verify()

    def test_wrong_consumed_source_is_refused(self):
        self.alter_reduced(lambda value:value['consumed_source_sha256'].update(dependency_sha256='0'*64))
        with self.assertRaisesRegex(ValueError,'consumed source'):
            self.verify()

    def test_semantically_bad_raw_data_with_all_resealed_claims_fails_real_reader(self):
        self.forge_raw_with_self_consistent_seals(semantic_valid=False)
        with self.assertRaisesRegex(ValueError,'reader rejected'):
            self.verify()
        proof = json.loads((self.root/'coverage/1/proof.json').read_text())
        self.assertEqual(proof['returncode'],19)
        self.assertEqual(proof['status'],'failed')

    def test_fresh_zero_exit_without_result_cannot_pass(self):
        self.forge_raw_with_self_consistent_seals(mode='empty-success')
        with self.assertRaisesRegex(ValueError,'FileNotFoundError'):
            self.verify()

    def test_original_and_fresh_reductions_must_match_in_full(self):
        self.alter_reduced(lambda value:value.update(unverified_claim='extra'))
        with self.assertRaisesRegex(ValueError,'differs from retained'):
            self.verify()

    def test_reader_cannot_change_original_inputs(self):
        self.forge_raw_with_self_consistent_seals(mutate_input=True)
        with self.assertRaisesRegex(ValueError,'evidence changed'):
            self.verify()

    def test_reader_cannot_change_source_dependencies(self):
        self.forge_raw_with_self_consistent_seals(mutate_source=True)
        with self.assertRaisesRegex(ValueError,'dependency changed'):
            self.verify()

    def test_recorded_windows_crlf_identity_remains_distinct_from_linux_reader(self):
        self.prepare_original(platform='Windows')
        readback = self.row['independent_evidence']
        for record in [readback['verifier_identity'],*readback['source_input_identity'].values()]:
            canonical = (self.repo/record['path']).read_bytes()
            record['actual_sha256'] = hashlib.sha256(canonical.replace(b'\n',b'\r\n')).hexdigest()
        self.alter_reduced(lambda value:value.update(verifier_sha256=readback['verifier_identity']['actual_sha256']))
        result = self.verify()
        self.assertEqual(result['status'],'passed')
        self.assertNotEqual(result['verifier_identity']['original_actual_sha256'],
                            result['verifier_identity']['coverage_actual_sha256'])

    def test_arbitrary_original_actual_source_hash_is_not_a_crlf_exception(self):
        self.prepare_original(platform='Windows')
        self.row['independent_evidence']['verifier_identity']['actual_sha256'] = '0'*64
        with self.assertRaisesRegex(ValueError,'source identity mismatch'):
            self.verify()

    def test_foreign_original_command_input_is_refused(self):
        self.row['independent_evidence']['command'][3] = '/foreign/result.json'
        with self.assertRaisesRegex(ValueError,'foreign inputs'):
            self.verify()

    def test_symlinked_original_or_parent_directory_is_refused(self):
        original = self.paths['result'].read_bytes()
        outside = self.root/'foreign.json'
        outside.write_bytes(original)
        self.paths['result'].unlink()
        self.paths['result'].symlink_to(outside)
        with self.assertRaisesRegex(ValueError,'symlink'):
            self.verify()

    def test_supplied_shard_directory_symlink_is_refused_before_resolution(self):
        link = self.root/'linked-shard'
        link.symlink_to(self.directory,target_is_directory=True)
        with self.assertRaisesRegex(ValueError,'shard is a symlink'):
            subject.verify(self.case,self.row,link,self.source,output_dir=self.root/'new-proof')

    def test_real_reader_timeout_retains_failure_and_originals(self):
        self.forge_raw_with_self_consistent_seals(sleep_seconds=1)
        self.row['independent_evidence'].update(seconds=.01,timeout_seconds=.2)
        with mock.patch.object(execution_policy,'watchdog_seconds',return_value=.2):
            with self.assertRaisesRegex(ValueError,'TimeoutExpired'):
                self.verify()
        proof = json.loads((self.root/'coverage/1/proof.json').read_text())
        self.assertEqual(proof['status'],'failed')
        self.assertTrue(proof['complete'])
        self.assertTrue(self.paths['result'].is_file())

    def test_source_queries_and_reader_share_one_clock_and_late_zero_exit_fails(self):
        clock = [0]
        actual_run = subprocess.run
        timeouts = []
        def delayed(command,**kwargs):
            value = actual_run(command,**kwargs)
            timeouts.append(kwargs['timeout'])
            clock[0] += 60 if command[0] == 'git' else 301
            return value
        with mock.patch.object(subject.time,'monotonic',side_effect=lambda:clock[0]), \
             mock.patch.object(subprocess,'run',side_effect=delayed):
            with self.assertRaisesRegex(ValueError,'operation watchdog'):
                self.verify()
        self.assertEqual(timeouts,[300,240,180,120])

    def test_existing_coverage_output_is_never_overwritten(self):
        directory = self.root/'existing'
        directory.mkdir()
        marker = directory/'proof.json'
        marker.write_text('keep original')
        with self.assertRaises(FileExistsError):
            subject.verify(self.case,self.row,self.directory,self.source,output_dir=directory)
        self.assertEqual(marker.read_text(),'keep original')


if __name__ == '__main__':
    unittest.main()
