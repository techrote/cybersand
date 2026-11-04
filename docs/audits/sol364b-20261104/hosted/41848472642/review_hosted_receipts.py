#!/usr/bin/env python3
"""Independently inspect downloaded SOL receipts; no project imports or writes.

The CPU numerator is reconstructed from all-attempt work counters and every
registered repeat is retained. Synchronized clearance/depth are reconstructed
from complete observations. This script does not run a physics simulation.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import math
import os
import subprocess

SOURCE = '9597abd76c01e4a940ff3ea26ff01fca43bf55a6'
TREE = '11e986214f056f3f39631bb0331b3cd4930c3d1c'
LOCAL_EQUIVALENT = '2f0ea3bdba5b7aef2fddef7d3a70f7e8d21adab9'
RUN = 41848472642
EXPECTED_COHORTS = {(p, w) for p in ('Linux', 'Windows') for w in (1, 4)}
EXPECTED_GROUPS = {(kind, arm) for kind in ('packed_sand', 'embedded_sand', 'mixed') for arm in (False, True)}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(path):
    return json.loads(path.read_bytes())


def identity(path):
    data = path.read_bytes()
    return {'path': str(path), 'bytes': len(data), 'sha256': sha(data)}


def finite(value):
    return type(value) in (float, int) and math.isfinite(value)


def source_map_check(repository, inputs, cache, checkout=False):
    key = sha(json.dumps({'inputs': inputs, 'checkout': checkout}, sort_keys=True, separators=(',', ':')).encode())
    if key in cache:
        return cache[key]
    assert isinstance(inputs, dict) and 0 < len(inputs) < 5000
    names = sorted(inputs)
    for name in names:
        path = Path(name)
        assert not path.is_absolute() and '..' not in path.parts
        assert not any(c in name for c in '\r\n\0')
    crlf = set()
    if checkout:
        info = Path(subprocess.check_output(['git', 'rev-parse', '--git-path', 'info/attributes'], cwd=repository, text=True).strip())
        if not info.is_absolute():
            info = repository / info
        assert not info.is_file() or not info.read_bytes(), 'Uncommitted attribute overrides cannot authorize source conversion'
        attrs = subprocess.run(['git', '-c', 'core.attributesFile=' + os.devnull,
            'check-attr', '--source=' + LOCAL_EQUIVALENT, '-z', '--stdin', 'eol'],
            cwd=repository, input=('\0'.join(names) + '\0').encode(), capture_output=True,
            check=True, timeout=60, env={**os.environ, 'GIT_ATTR_NOSYSTEM': '1'}).stdout.decode().split('\0')
        assert len(attrs) == 3 * len(names) + 1 and attrs[-1] == ''
        for i, name in enumerate(names):
            assert attrs[3*i:3*i+2] == [name, 'eol']
            if attrs[3*i+2] == 'crlf':
                crlf.add(name)
    command = ['git', 'cat-file', '--batch']
    queries = ''.join(LOCAL_EQUIVALENT + ':' + name + '\n' for name in names).encode()
    raw = subprocess.run(command, cwd=repository, input=queries, capture_output=True,
                         check=True, timeout=60).stdout
    offset = 0; conversions = []
    for name in names:
        end = raw.index(b'\n', offset)
        fields = raw[offset:end].split()
        assert len(fields) == 3 and fields[1] == b'blob', name
        size = int(fields[2]); start = end + 1
        data = raw[start:start+size]
        assert len(data) == size
        if sha(data) != inputs[name]:
            assert checkout and name in crlf and b'\r\n' not in data, name
            assert sha(data.replace(b'\n', b'\r\n')) == inputs[name], name
            conversions.append({'path': name, 'canonical_git_sha256': sha(data),
                                'actual_checkout_sha256': inputs[name], 'committed_eol': 'crlf'})
        assert raw[start+size:start+size+1] == b'\n'
        offset = start + size + 1
    assert offset == len(raw)
    result = {'status': 'PASS', 'count': len(names), 'checked_manifest_sha256': key,
              'all_match_exact_tree_or_its_committed_checkout_rules': True,
              'direct_git_byte_matches': len(names) - len(conversions),
              'committed_crlf_conversions': conversions, 'git_tree': TREE,
              'local_equal_tree_commit': LOCAL_EQUIVALENT}
    cache[key] = result
    return result


def check_source(source):
    assert source == {'sha': SOURCE, 'tree': TREE}, source


def build_receipt(path, repository, cache):
    report = read(path); check_source(report['source'])
    before = path.parent / 'before.json'
    assert sha(before.read_bytes()) == report['before_manifest_sha256']
    before_data = read(before)
    assert before_data['source'] == report['source'] and before_data['inputs'] == report['inputs']
    assert before_data['checkout_inputs'] == report['checkout_inputs']
    runtime = path.parent / report['runtime']['filename']
    assert sha(runtime.read_bytes()) == report['runtime']['sha256']
    assert runtime.stat().st_size == report['runtime']['size']
    assert report['bindings']['revision'] == '101ae38034304346a46ea9ea84ae156d3e860496'
    return {'receipt': identity(path), 'source': report['source'],
            'runtime': report['runtime'], 'compiler': report['compiler'],
            'bindings': report['bindings'],
            'input_verification': source_map_check(repository, report['inputs'], cache),
            'checkout_verification': source_map_check(repository, report['checkout_inputs'], cache, checkout=True)}


def diagnostic_receipt(path, repository, cache):
    q = read(path); check_source(q['source']); check_source(q['source_after'])
    assert q['status'] == 'passed' and q['run_id'] == str(RUN) and q['run_attempt'] == '1'
    assert q['inputs_before'] == q['inputs_after']
    assert q['platform'] in ('Linux', 'Windows') and q['live_candidate_applications'] == 0
    source_check = source_map_check(repository, q['inputs_before'], cache)
    summary_path = path.parent / 'replay/summary.json'
    s = read(summary_path)
    assert sha(summary_path.read_bytes()) == q['summary_sha256']
    assert s['analysis_git_head'] == SOURCE and s['analysis_git_tree'] == TREE
    assert s['checked_inputs'] == s['checked_inputs_at_finish']
    assert all(q['inputs_before'][name] == digest for name, digest in s['checked_inputs'].items())
    assert s['probe_sha256'] == q['executables']['probe']['sha256']
    tests = s['native_tests']
    assert tests['status'] == 'PASS' and tests['sha256'] == q['executables']['tests']['sha256']
    assert tests['result']['groups'] == 6 and tests['result']['checks'] == 142
    assert tests['result']['failures'] == 0 and tests['result']['live_application'] is False
    assert s['reports'] == 4 and s['retained_states_evaluated'] == 1452
    assert s['unique_geometric_inputs'] == 349 and s['live_candidate_applications'] == 0
    assert s['geometry_only_unique_routes'] == 0 and s['disposition'] == 'BOUNDED_FAMILY_NO_GO'
    assert s['outcome_counts'] == {'InitialExcludedOverlap': 728, 'NoRegisteredCorridor': 724}
    query_files = list((path.parent / 'replay/inputs').glob('*.txt'))
    certificate_files = list((path.parent / 'replay/certificates').glob('*.json'))
    assert len(query_files) == len(certificate_files) == 349
    for query in query_files:
        data = query.read_bytes()
        assert sha(data) == query.stem and b'\r' not in data
    for certificate in certificate_files:
        c = read(certificate)
        assert c['input_sha256'] == certificate.stem and c['probe_sha256'] == s['probe_sha256']
        assert c['result']['live_authority'] is False and c['result']['application_count'] == 0
    commands = {row['label']: row for row in q['commands']}
    assert commands['compile-probe']['returncode'] == 0 and commands['compile-tests']['returncode'] == 0
    assert commands['retained-state-replay']['returncode'] == 0
    if q['platform'] == 'Windows':
        assert Path(q['compiler_path'].replace('\\', '/')).name.lower() == 'cl.exe'
        assert '/std:c++20' in commands['compile-tests']['command']
        sanitizer = {'status': 'NOT_APPLICABLE_TO_MSVC_COHORT'}
    else:
        c = commands['address-undefined-tests']
        assert c['returncode'] == 0 and not c['stderr']
        assert json.loads(c['stdout']) == tests['result']
        assert 'halt_on_error=1' in c['environment_overrides']['UBSAN_OPTIONS']
        assert 'detect_leaks=0' in c['environment_overrides']['ASAN_OPTIONS']
        sanitizer = {'status': 'PASS_ADDRESS_AND_UB_ONLY', 'command': c,
                     'leak_check': q['leak_sanitizer']}
    return {'qualification': identity(path), 'summary': identity(summary_path),
            'platform': q['platform'], 'platform_detail': q['platform_detail'],
            'source': q['source'], 'input_verification': source_check,
            'tool_executables': q['tool_executables'], 'executables': q['executables'],
            'compiler_version': commands['compiler-version'], 'native_tests': tests,
            'sanitizers': sanitizer, 'result': q['result'],
            'query_hashes_and_LF_bytes_verified': 349, 'certificates_verified': 349}


def authenticate_result(host, host_path, name):
    record = next(row for row in host['records'] if row['name'] == name)
    assert record['status'] == 'passed' and record['returncode'] == 0
    assert record['natural_completion'] is True
    result = host_path.parent / record['result']['path']
    assert sha(result.read_bytes()) == record['result']['sha256']
    return result, read(result)


def cpu_groups(path, report):
    assert report['schema'] == 'cybersand.sol281.contact-recovery.v1'
    assert report['failures'] == [] and report['checks'] == 290 and report['case_count'] == 18
    assert len(report['cases']) == 18
    grouped = {}
    seen = set()
    candidate_final_positive = 0
    for case in report['cases']:
        key = (case['surroundings'], case['candidate'])
        full = (*key, case['repeat']); assert full not in seen; seen.add(full)
        assert case['steps'] == 360 and case['trace']
        assert case['sand_before'] == case['sand_after'] and case['water_before'] == case['water_after']
        p = case['metrics']['physical_contact']; observations = p['observations']
        assert type(observations) is int and observations > 0
        owner = p['worker_contact_ms_total']; response = p['response_ms_all_attempts']
        assert finite(owner) and owner >= 0 and finite(response) and response >= 0
        assert abs(p['worker_native_call_ms_all_attempts'] + p['worker_envelope_ms_all_attempts'] - owner) <= 1e-6
        assert p['worker_complete_attempts'] + p['worker_refused_attempts'] == p['worker_observation_attempts']
        stages = sum(p['response_' + name + '_ms_all_attempts'] for name in ('rid_state', 'planner', 'impulse_apply', 'readback', 'other'))
        assert abs(stages - response) <= 1e-6
        value = (owner + response) / observations
        assert finite(value)
        grouped.setdefault(key, []).append({'repeat': case['repeat'], 'id': case['id'],
            'owner_all_attempt_ms': owner, 'response_all_attempt_ms': response,
            'complete_consumed_observations': observations, 'unrounded_repeat_mean_ms': value,
            'energy_violations': p['energy_violations'],
            'maximum_sampled_sand_depth': p['max_sand_penetration'],
            'final_sample_sand_area': case['trace'][-1]['sand_overlap_area']})
        if case['candidate'] and case['trace'][-1]['sand_overlap_area'] > 1e-9:
            candidate_final_positive += 1
    assert seen == {(kind, arm, repeat) for kind, arm in EXPECTED_GROUPS for repeat in range(3)}
    result = []
    for (kind, arm), repeats in sorted(grouped.items()):
        worst = max(row['unrounded_repeat_mean_ms'] for row in repeats)
        result.append({'platform': report['platform'], 'workers': report['workers'],
            'surroundings': kind, 'candidate': arm, 'repeats': repeats,
            'maximum_repeat_mean_ms': worst, 'limit_ms': 2.0, 'passed': worst <= 2.0,
            'raw_report': identity(path)})
    return result, candidate_final_positive


def synchronized_physics(path, report):
    assert report['schema'] == 'cybersand.sol364.synchronized-contact.v1'
    assert report['failures'] == [] and report['complete_replay'] is True
    assert report['case_count'] == 21 and len(report['cases']) == 21
    rows = []
    for case in report['cases']:
        assert case['steps'] == 180 and len(case['trace']) == 180
        assert case['payload_preserved'] is True and case['aggregate_owned'] == 520
        trace = case['trace']; initial = case['initial']['measurement']
        assert [row['step'] for row in trace] == list(range(1, 181))
        observations = [initial] + [row['measurement'] for row in trace]
        maximum_depth = max(row['max_sand_penetration'] for row in observations)
        initial_depth = initial['max_sand_penetration']
        allowed_depth = initial_depth + 0.25 if initial_depth > 2e-5 else 1.0
        clear_run = longest_clear = 0; sustained_start = -1; positive_steps = 0
        for row in trace:
            m = row['measurement']
            positive = m['sand_overlap_area'] > 1e-6 or m['max_sand_penetration'] > 2e-5
            positive_steps += positive
            clear_run = 0 if positive else clear_run + 1
            longest_clear = max(longest_clear, clear_run)
            if clear_run >= 60 and sustained_start < 0:
                sustained_start = row['step'] - 59
        gate = case['physical_gates']; first = gate['first_valid_impact_step']
        clearance = first >= 0 and first <= sustained_start <= first + 120
        depth_pass = maximum_depth <= allowed_depth
        assert gate['depth_pass'] == depth_pass and gate['sustained_clearance_pass'] == clearance
        assert gate['clearance_start_step'] == sustained_start
        assert gate['initial_depth'] == initial_depth and gate['allowed_depth'] == allowed_depth
        assert gate['position_work'] == 0.0
        rows.append({'id': case['id'], 'maximum_sand_depth': maximum_depth,
            'initial_sand_depth': initial_depth, 'allowed_depth': allowed_depth,
            'depth_pass': depth_pass, 'sustained_clearance_pass': clearance,
            'positive_observation_steps': positive_steps, 'longest_clear_run': longest_clear,
            'clearance_start_step': sustained_start, 'first_valid_impact_step': first,
            'introduced_position_work': 0.0})
    return {'platform': report['platform'], 'workers': report['workers'], 'raw_report': identity(path),
        'cases': rows, 'clearance_failures': sum(not row['sustained_clearance_pass'] for row in rows),
        'depth_failures': sum(not row['depth_pass'] for row in rows)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', type=Path, required=True)
    parser.add_argument('--artifacts', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    repository = args.repository.resolve(); artifacts = args.artifacts.resolve()
    actual_tree = subprocess.check_output(['git', 'rev-parse', LOCAL_EQUIVALENT + '^{tree}'], cwd=repository, text=True).strip()
    assert actual_tree == TREE
    cache = {}; errors = []; builds = []; diagnostics = []; hosts = []; costs = []; physical = []
    asynchronous_final_positive = 0
    for path in sorted(artifacts.rglob('*.json')):
        if path.name not in ('build.json', 'qualification.json', 'report.json'):
            continue
        try:
            report = read(path); schema = report.get('schema')
            if schema == 'cybersand.sol281.source-build.v1':
                builds.append(build_receipt(path, repository, cache))
            elif schema == 'cybersand.sol364b.diagnostic-qualification.v1':
                diagnostics.append(diagnostic_receipt(path, repository, cache))
            elif schema == 'cybersand.sol281.qualification.v1':
                check_source(report['source'])
                assert report['status'] == 'passed' and report['errors'] == []
                assert report['source_unchanged'] is True and report['checkout_inputs_unchanged'] is True
                cohort = report['cohort']; platform_name = report['platform']
                hosts.append({'receipt': identity(path), 'cohort': cohort, 'platform': platform_name,
                    'source': report['source'], 'runtime': report['runtime'], 'engine': report['engine'],
                    'rapier': report['rapier'], 'build_manifest_sha256': report['build_manifest_sha256'],
                    'records': len(report['records']), 'status': report['status']})
                if cohort in ('contact-w1', 'contact-w4'):
                    workers = int(cohort[-1]); raw_path, raw = authenticate_result(report, path, 'contact-recovery-w' + str(workers))
                    assert raw['platform'] == platform_name and raw['workers'] == workers
                    groups, positives = cpu_groups(raw_path, raw); costs.extend(groups)
                    asynchronous_final_positive += positives
                elif cohort == 'mechanism':
                    for workers in (1, 4):
                        raw_path, raw = authenticate_result(report, path, 'synchronized-contact-w' + str(workers))
                        assert raw['platform'] == platform_name and raw['workers'] == workers
                        physical.append(synchronized_physics(raw_path, raw))
        except Exception as error:
            errors.append({'path': str(path), 'error': type(error).__name__ + ': ' + str(error)})
    cohorts = {(row['platform'], row['workers']) for row in costs}
    complete_cpu = cohorts == EXPECTED_COHORTS and len(costs) == 24
    for platform_name, workers in cohorts:
        assert {(row['surroundings'], row['candidate']) for row in costs if (row['platform'], row['workers']) == (platform_name, workers)} == EXPECTED_GROUPS
    complete_physics = {(row['platform'], row['workers']) for row in physical} == EXPECTED_COHORTS and len(physical) == 4
    complete_diagnostics = len(diagnostics) == 2 and {row['platform'] for row in diagnostics} == {'Linux', 'Windows'}
    for host in hosts:
        matching = [row for row in builds if row['runtime']['filename'] == host['runtime']['filename']]
        if len(matching) != 1:
            errors.append({'path': host['receipt']['path'], 'error': 'Missing or ambiguous downloaded source-build receipt'})
            continue
        build = matching[0]
        if build['runtime'] != host['runtime'] or build['receipt']['sha256'] != host['build_manifest_sha256']:
            errors.append({'path': host['receipt']['path'], 'error': 'Actual-host runtime does not match the downloaded exact-source build'})
    complete_hosts = len(hosts) == 8 and {(row['platform'], row['cohort']) for row in hosts} == {
        (platform_name, cohort) for platform_name in ('Linux', 'Windows')
        for cohort in ('core', 'contact-w1', 'contact-w4', 'mechanism')}
    result = {'schema': 'cybersand.sol364b.independent-hosted-review.v1',
        'reviewed_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'run_id': RUN, 'attempt': 1, 'source': SOURCE, 'tree': TREE,
        'review_program': identity(Path(__file__).resolve()), 'errors': errors,
        'builds': builds, 'diagnostics': diagnostics, 'host_receipts': hosts,
        'diagnostic_host_inventory_complete': complete_diagnostics,
        'live_host_inventory_complete': complete_hosts,
        'live_process_records': sum(row['records'] for row in hosts),
        'source_manifest_verifications': list(cache.values()),
        'cpu_matrix': {'complete': complete_cpu, 'expected_groups': 24, 'groups': costs,
            'passed_groups': sum(row['passed'] for row in costs),
            'failed_groups': [row for row in costs if not row['passed']],
            'maximum_unrounded_repeat_mean_ms': max((row['maximum_repeat_mean_ms'] for row in costs), default=None),
            'verdict': ('PASS' if all(row['passed'] for row in costs) else 'FAIL') if complete_cpu else 'INCOMPLETE',
            'definition': 'For each of all 24 groups: largest of three repeat means. Each numerator is all owner observation/envelope attempts plus all main response attempts; denominator is complete consumed observations. No nested native stage is counted twice. Elapsed work intervals, not OS thread CPU.'},
        'synchronized_physics': {'complete': complete_physics, 'reports': physical,
            'clearance_failures': sum(row['clearance_failures'] for row in physical),
            'depth_failures': sum(row['depth_failures'] for row in physical)},
        'asynchronous_candidate_final_positive_samples': asynchronous_final_positive,
        'scope': 'Fresh actual-host evidence at the exact published source. Diagnostic success and CPU success do not establish recovery or integration admission. Historical negatives retain their original identities.'}
    args.output.write_text(json.dumps(result, sort_keys=True, indent=2, allow_nan=False) + '\n')
    print(json.dumps({'output': identity(args.output), 'errors': errors,
        'builds': len(builds), 'diagnostics': [row['platform'] for row in diagnostics],
        'hosts': len(hosts), 'cpu_complete': complete_cpu, 'cpu_groups': len(costs),
        'cpu_passed': sum(row['passed'] for row in costs), 'physics_complete': complete_physics,
        'clearance_failures': result['synchronized_physics']['clearance_failures'],
        'depth_failures': result['synchronized_physics']['depth_failures']}, indent=2))


if __name__ == '__main__':
    main()
