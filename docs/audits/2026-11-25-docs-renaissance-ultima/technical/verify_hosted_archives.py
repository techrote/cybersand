"""Independently verify already-downloaded, source-bound hosted receipts."""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import zipfile

HEAD = 'bfa40c84964b10b8bc15b2d836ce93d389f20836'
TREE = '6f7e761d64db191d0bc94f3568440ca017274047'
EXPECTED = {
    'ultima-linux-45697930828-1.zip': '1666462effaaef97921f44d00181dc8368f62d16ed052aba6db827c068ab3262',
    'ultima-windows-45697930828-1.zip': 'b379b821e15bf127a3ea34710f3a8f633fab2e488e84fa80713f62404feb7562',
    'causal-bfa40c84.zip': 'bbdd5a9d7a88d8115e5539724e33ba6b7587f1a5eba009d1c8ee79df21ed78ea',
}

def sha(data):
    return hashlib.sha256(data).hexdigest()

def compact_result(value):
    return {k: v for k, v in value.items() if k not in ('path', 'transaction')}

def check_normal(z, case):
    data = z.read(case['log'])
    assert sha(data) == case['log_sha256']
    assert case['status'] == 'passed' and case['returncode'] == 0
    assert case['natural_completion'] and not case['skip_messages']
    assert not case['timeout_kind'] and not case['launch_error']
    assert not case['capture_error'] and not case['diagnostic_error']
    lines = data.decode('utf-8', 'replace').splitlines()
    footers = [line for line in lines if re.search(r'checks=\d+ failures=0|\d+ checks, 0 failures', line)]
    if case['role'] != 'preflight':
        assert footers, case['name']
    return {k: case[k] for k in ('name', 'role', 'returncode', 'natural_completion', 'log', 'log_sha256', 'seconds')} | {'assertion_footers': footers}

def qualify(z, platform):
    q = json.loads(z.read('qualification.json'))
    p = json.loads(z.read('persistence/report.json'))
    provenance = json.loads(z.read('materialized-provenance.json'))
    source_bytes = z.read('source-inputs.json')
    inputs = json.loads(source_bytes)
    assert q['source_head'] == HEAD and q['source_tree'] == TREE
    assert q['status'] == 'passed' and q['completed'] and not q['errors'] and not q['changed_inputs']
    assert sha(source_bytes) == q['source_inputs_sha256']
    assert p == q['persistence'] and p['source_head'] == HEAD
    assert p['status'] == 'passed' and p['completed']
    assert provenance['status'] == 'passed' and not provenance['errors']
    assert len(provenance['materialized_runtime_files']) == 18 and not provenance['unmaterialized_runtime_files']
    log_records = []
    log_digests = {}
    focused = []
    for name in z.namelist():
        if not (name.startswith('persistence/') and name.endswith('.log')):
            continue
        content = z.read(name)
        log_digests[name] = sha(content)
        for line in content.decode('utf-8', 'replace').splitlines():
            if line.startswith('WORKBENCH_SAVE_RESULT '):
                log_records.append(json.loads(line.split(' ', 1)[1]))
            if line.startswith('FILE_TRANSACTION_RESULT '):
                focused.append(json.loads(line.split(' ', 1)[1]))
    summaries = []
    checked_records = 0
    for case in p['cases']:
        result = {k: case[k] for k in ('kind', 'fault', 'evidence_class', 'staging_sha256', 'exit_code', 'termination', 'lock') if k in case}
        if 'result' in case:
            assert case['result'] in focused
            assert not case['result']['failures']
            assert len(case['result']['cases']) == 10
            assert case['result']['checks'] == (84 if platform == 'linux' else 75)
            for injection in case['result']['cases']:
                assert injection['after_sha256'] == injection['old_sha256']
            result['focused_checks'] = case['result']['checks']
            result['injected_faults'] = [c['fault'] for c in case['result']['cases']]
        for phase in ('before', 'replacement', 'refusal', 'retry', 'after', 'first', 'second', 'final'):
            if phase not in case:
                continue
            record = case[phase]
            assert record in log_records, (case.get('fault'), phase, 'receipt is not in archived child log')
            checked_records += 1
            assert record['readable'] and record['read_error'] == ''
            result[phase] = compact_result(record)
        if 'refusal' in case:
            assert case['refusal']['error']
            assert case['before']['after_sha256'] == case['refusal']['after_sha256']
            assert case['before']['file_bytes'] == case['refusal']['file_bytes']
            if case['kind'] != 'helper':
                key, old, new = ('seed', 123, 456) if case['kind'] == 'project' else ('material', 2, 14)
                assert case['before'][key] == case['refusal'][key] == old
                assert case['retry'][key] == new
            assert not case['retry']['error']
        if 'replacement' in case:
            key, old, new = ('seed', 123, 456) if case['kind'] == 'project' else ('material', 2, 14)
            assert case['before'][key] == old and case['replacement'][key] == new
            assert not case['replacement']['error']
            assert case['before']['after_sha256'] != case['replacement']['after_sha256']
        if case.get('fault') == 'process-termination-before-commit':
            assert case['after']['after_sha256'] == case['before']['after_sha256']
            assert case['after']['value'] == 'old' and case['retry']['value'] == 'new'
            assert case['exit_code'] != 0
        if case.get('evidence_class') == 'real-concurrent-processes':
            assert not case['first']['error'] and not case['second']['error']
            assert case['final']['after_sha256'] in (case['first']['after_sha256'], case['second']['after_sha256'])
        if case.get('fault') == 'locked-source-with-unlocked-destination':
            assert case['lock']['delete_access_probe_error'] == 32
            assert 'Windows error 32' in case['refusal']['error']
            assert case['refusal']['transaction']['staging_retained']
            assert 'it is not a saved start' in case['refusal']['error']
            result['staging_retained'] = True
        summaries.append(result)
    assert len(p['cases']) == (13 if platform == 'linux' else 10)
    return {
        'platform': q['platform'], 'source_head': HEAD, 'source_tree': TREE,
        'run_url': f"https://github.com/techrote/cybersand/actions/runs/{q['run_id']}",
        'source_inputs_sha256': sha(source_bytes), 'source_input_count': len(inputs),
        'changed_inputs': q['changed_inputs'], 'engine': q['engine'],
        'materialized_runtime_count': len(provenance['materialized_runtime_files']),
        'normal_workflows': [check_normal(z, c) for c in q['cases']],
        'persistence_case_count': len(p['cases']), 'archived_child_records_independently_matched': checked_records,
        'persistence_input_sha256': p['input_sha256'], 'native_sha256': p['native_sha256'],
        'persistence_cases': summaries, 'child_log_sha256': log_digests,
        'limits': q['limits'] + p['limits'], 'verdict': 'APPROVE within the declared local-filesystem and process-failure model',
    }, inputs

parser = argparse.ArgumentParser()
parser.add_argument('--archives', type=pathlib.Path, required=True)
parser.add_argument('--repository', type=pathlib.Path, required=True)
parser.add_argument('--output', type=pathlib.Path, required=True)
args = parser.parse_args()
out = {'schema': 1, 'authority': 'historical-non-authoritative', 'reviewer': 'Specialist A', 'method': 'Independent archive CRC, digest, source identity, process-log and child-result readback; no new execution claimed', 'archives': {}, 'platforms': {}}
inputmaps = {}
for name, digest in EXPECTED.items():
    file = args.archives / name
    data = file.read_bytes()
    assert sha(data) == digest
    with zipfile.ZipFile(file) as z:
        assert z.testzip() is None
        out['archives'][name] = {'bytes': len(data), 'sha256': digest, 'crc': 'passed'}
        if name.startswith('ultima-'):
            platform = name.split('-')[1]
            out['platforms'][platform], inputmaps[platform] = qualify(z, platform)
        else:
            q = json.loads(z.read('windows-causal-gate.json'))
            admission = json.loads(z.read('source-admission.json'))
            assert q['source_commit'] == HEAD and q['source_tree'] == TREE
            assert q['status'] == 'passed' and q['completed'] and q['actual_windows']
            assert q['fixture_completed_naturally'] and q['process_exit_unsigned'] == 0 and not q['errors']
            assert q['assertion_footer'] == {'assertions': 86, 'failures': 0}
            process = q['process']
            assert sha(z.read(process['log'])) == process['log_sha256']
            assert process['natural_completion'] and process['returncode'] == 0
            assert not process['skip_messages'] and process['timeout_kind'] is None
            assert not q['historical_signature_match']
            assert q['causal_disposition'] == 'historical_crash_not_reproduced_causality_unresolved'
            assert admission['runtime_qualified'] is False and admission['gameplay_qualified'] is False
            out['windows_causal'] = {k:q[k] for k in ('source_commit','source_tree','platform','assertion_footer','fixture_completed_naturally','process_exit_hex','historical_signature_match','causal_disposition','status')}
            out['windows_causal']['log_sha256'] = process['log_sha256']
            out['windows_causal']['source_admission_sha256'] = sha(z.read('source-admission.json'))
            out['windows_causal']['scope'] = 'The unchanged causal fixture exits normally on this exact Windows source/runtime. Historical crash causality is unresolved; six proposed fixtures remain NOT_RUN.'
assert inputmaps['linux'].keys() == inputmaps['windows'].keys()
differences = []
for path in inputmaps['linux']:
    if inputmaps['linux'][path] == inputmaps['windows'][path]:
        continue
    blob = subprocess.check_output(['git','show',f'{HEAD}:{path}'], cwd=args.repository)
    lf = blob.replace(b'\r\n', b'\n')
    assert sha(lf) == inputmaps['linux'][path], ('not Linux LF blob',path)
    assert sha(lf.replace(b'\n', b'\r\n')) == inputmaps['windows'][path], ('not Windows CRLF checkout',path)
    differences.append(path)
out['cross_platform_input_comparison'] = {'same_paths': len(inputmaps['linux']), 'identical_byte_digests': len(inputmaps['linux']) - len(differences), 'different_worktree_digests': len(differences), 'all_differences_proven_git_LF_to_Windows_CRLF': True, 'difference_paths': differences, 'explanation': 'Source-input receipts measure checkout bytes. Same Git tree does not imply byte-identical platform worktrees; these differing text files are independently verified against the exact Git blob with only LF/CRLF conversion.'}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(out, indent=2, sort_keys=True)+'\n')
print(json.dumps({'status':'passed','output':str(args.output),'bytes':args.output.stat().st_size,'platforms':{k: {'normal_workflows':len(v['normal_workflows'])-1,'persistence_cases':v['persistence_case_count'],'matched_child_records':v['archived_child_records_independently_matched']} for k,v in out['platforms'].items()}, 'cross_platform_LF_CRLF_differences':len(differences)}))
