#!/usr/bin/env python3
"""Independent, read-only audit of downloaded MAT354 run 41817101140 evidence."""
import argparse
import hashlib
import json
import pathlib
import posixpath
import re
import subprocess

SOURCE = '1a06a0d88d295ed99983e7b1f6149b9fff84f1b3'
ACCEPTED = '7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8'))


def git_bytes(repo, spec):
    return subprocess.check_output(['git', 'show', spec], cwd=repo)


def authenticate(info, raw_root):
    path = raw_root / pathlib.PurePosixPath(info['path'].replace('\\', '/')).name
    data = path.read_bytes()
    assert len(data) == info['bytes'], f'Raw byte mismatch: {path}'
    assert sha(data) == info['sha256'], f'Raw SHA mismatch: {path}'
    return data


def source_inventory(receipt, repo):
    expected_tree = subprocess.check_output(
        ['git', 'rev-parse', SOURCE + '^{tree}'], cwd=repo, text=True).strip()
    assert receipt['source_commit'] == SOURCE
    assert receipt['source_tree'] == expected_tree
    assert receipt['accepted_source'] == ACCEPTED
    assert receipt['worktree_status'] == ''
    assert receipt['source_qualified'] is True
    inventory = receipt['compiled_input_inventory']
    mismatches = []
    for entry in inventory:
        data = git_bytes(repo, SOURCE + ':' + entry['path'])
        if len(data) != entry['bytes'] or sha(data) != entry['sha256']:
            mismatches.append(entry['path'])
    assert not mismatches, f'Git blob mismatches: {mismatches}'
    actual = receipt['actual_dependency_inventory']
    assert all(row in inventory for row in actual)
    assert len({row['path'] for row in actual}) == len(actual)
    assert {'native/src/world.cpp', 'native/tests/material_liveness_probe.cpp'} <= {row['path'] for row in actual}
    assert receipt['committed_input_check']['status'] == 'PASS'
    assert receipt['committed_input_check']['checked_files'] == len(inventory)
    canonical = json.dumps(inventory, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()
    assert sha(canonical) == receipt['input_inventory_sha256']
    assert sha(canonical) == receipt['committed_input_check']['committed_inventory_sha256']
    return {'status': 'PASS', 'checked_files': len(inventory), 'mismatches': [],
            'actual_dependency_count': len(actual), 'source_tree': expected_tree,
            'input_inventory_sha256': sha(canonical)}


def dependencies(receipt, raw_root):
    # The retained two hosted builds have no escaped spaces in their checkout
    # paths. Refuse rather than silently generalize this independent parser.
    root = receipt['root'].replace('\\', '/').rstrip('/')
    assert ' ' not in root
    observed = set()
    for entry in receipt['dependency_files']:
        data = authenticate(entry, raw_root).decode('utf-8')
        data = re.sub(r'\\\r?\n', ' ', data)
        target, separator, body = data.partition(': ')
        assert separator, entry['path']
        assert target.endswith(('.o', '.obj'))
        for token in body.split():
            token = posixpath.normpath(token.replace('\\', '/'))
            assert token.startswith(root + '/'), token
            observed.add(token[len(root) + 1:])
    expected = {entry['path'] for entry in receipt['actual_dependency_inventory']}
    assert observed == expected, {'missing': sorted(expected - observed), 'extra': sorted(observed - expected)}
    return {'status': 'PASS', 'dependency_files': len(receipt['dependency_files']),
            'source_paths': sorted(observed)}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=pathlib.Path, required=True,
                        help='Git checkout containing the recorded source commit and blobs')
    parser.add_argument('--audit-root', type=pathlib.Path, required=True,
                        help='Restored evidence containing linux/campaign, windows/campaign and verified reductions/analyses')
    parser.add_argument('--output', type=pathlib.Path,
                        help='New output JSON; defaults to AUDIT_ROOT/hosted-independent-audit.json')
    args = parser.parse_args(argv)
    audit = args.audit_root.resolve()
    repo = args.repo.resolve()
    output = args.output.resolve() if args.output else audit / 'hosted-independent-audit.json'
    if output.suffix != '.json' or output.exists():
        parser.error('output must be a new .json file; preserve earlier audits')
    result = {'schema': 'mat354.hosted-independent-recovery-audit.v1',
              'workflow_run': 41817101140, 'source_commit': SOURCE,
              'accepted_production_source': ACCEPTED,
              'audit_script_sha256': sha(pathlib.Path(__file__).read_bytes()),
              'platforms': {}, 'limits': [
                  'Checks native source and evidence; does not qualify graphics or gameplay.',
                  'Hosted runners have distinct recorded hostnames/CPU descriptions; physical host independence is not established.',
                  'Executable hashes are authenticated receipt identities; executable bytes are intentionally not in the artifacts.',
                  'No new native execution was performed by this artifact audit.']}
    trajectories = {}
    receipts = {}
    reductions = {}
    for osname in ['linux', 'windows']:
        raw_root = audit / osname / 'campaign'
        receipt = read_json(raw_root / 'campaign.json')
        context = read_json(audit / osname / 'hosted-context.json')
        assert context['source_commit'] == context['expected_source'] == SOURCE
        assert context['run_id'] == '41817101140'
        reduction = read_json(audit / (osname + '-reduction-verified.json'))
        analysis = read_json(audit / (osname + '-analysis-verified.json'))
        assert reduction['status'] == analysis['status'] == 'PASS'
        assert reduction['campaign_receipt_sha256'] == sha((raw_root / 'campaign.json').read_bytes())
        assert len(receipt['cases']) == len(reduction['cases']) == 552
        source = source_inventory(receipt, repo)
        dep = dependencies(receipt, raw_root)
        raw_files = 0
        for process in [receipt['compiler_version'], *receipt['build_steps'], *receipt['cases']]:
            assert process['returncode'] == 0 and process['timed_out'] is False
            for stream in ['stdout', 'stderr']:
                authenticate(process[stream], raw_root)
                raw_files += 1
        per_case = {}
        for case in receipt['cases']:
            rows = [json.loads(line) for line in authenticate(case['stdout'], raw_root).decode().splitlines()]
            ticks = [row for row in rows if row['type'] == 'tick']
            sequence = [(row['reset_epoch'], row['world_tick'], row['physical_hash']) for row in ticks]
            assert all(row['quantity_ok'] and not row['has_failed'] for row in ticks)
            per_case[case['id']] = sequence
        trajectories[osname] = per_case
        receipts[osname] = receipt
        reductions[osname] = reduction
        assert len(reduction['parity']) == 261 and all(row['matching'] for row in reduction['parity'])
        distributed = [row for row in reduction['cases'] if row['metadata']['fixture'].startswith('distributed') and row['workers_configured'] == 4]
        assert len(distributed) == 8 and all(row['workers_observed_max'] == 4 for row in distributed)
        result['platforms'][osname] = {
            'status': 'PASS', 'source': source, 'dependency_proof': dep,
            'receipt_sha256': sha((raw_root / 'campaign.json').read_bytes()),
            'authenticated_process_streams': raw_files,
            'cases': len(per_case), 'owner_steps': sum(len(seq) for seq in per_case.values()),
            'matching_worker_repeat_groups': len(reduction['parity']),
            'distributed_four_worker_cases': len(distributed),
            'all_distributed_cases_observed_four_claimants': True,
            'host': receipt['host'], 'executable': receipt['executable'],
            'compiler_version': authenticate(receipt['compiler_version']['stdout'], raw_root).decode().strip(),
            'compile_flags': receipt['compile_flags']}
    assert receipts['linux']['compiled_input_inventory'] == receipts['windows']['compiled_input_inventory']
    assert receipts['linux']['actual_dependency_inventory'] == receipts['windows']['actual_dependency_inventory']
    assert receipts['linux']['plan'] == receipts['windows']['plan']
    left = trajectories['linux']
    right = trajectories['windows']
    assert left.keys() == right.keys()
    mismatches = [case for case in left if left[case] != right[case]]
    assert not mismatches, mismatches
    lr = {row['id']: row for row in reductions['linux']['cases']}
    wr = {row['id']: row for row in reductions['windows']['cases']}
    assert all(lr[key]['trajectory_sha256'] == wr[key]['trajectory_sha256'] for key in lr)
    result['cross_os'] = {'status': 'PASS', 'matching_cases': len(left),
                          'matching_owner_steps': sum(len(seq) for seq in left.values()),
                          'mismatch_cases': [], 'identical_compiled_input_inventory': True,
                          'identical_actual_dependency_inventory': True,
                          'comparison': 'Every (reset_epoch, world_tick, physical_hash) tuple in every retained native tick; corroborated by every reducer trajectory digest.'}
    result['status'] = 'PASS'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    print(json.dumps({'status': result['status'], 'output': str(output), 'cross_os': result['cross_os']}))


if __name__ == '__main__':
    main()
