"""Read original hosted receipt chains and compare registered physical executions."""
from pathlib import Path
import hashlib
import json
import math
import sys

ROOT = Path('/tmp/ambient-002/perception')
BASE = Path('/tmp/ambient-002/evidence/perception/hosted-83a/extracted')
LOCAL = Path('/tmp/ambient-002/evidence/perception/isolated-83a3')
OUT = BASE.parent / 'independent-custody'
SOURCE = '83a3db6ffb207761df999abedac77eb1401604a8'
sys.path.insert(0, str(ROOT / 'tools/ambient'))
import run_episodes as runner
import analyze_episodes as reducer


def read(path):
    return json.loads(path.read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


physical = BASE / 'episodes-full'
receipt = read(physical / 'runner-receipt.json')
custody = read(physical / 'custody.json')
local_custody = read(LOCAL / 'custody.json')
assert receipt['source_revision'] == custody['source']['source_commit'] == SOURCE
assert receipt['complete'] and receipt['campaigns'] == 122 and receipt['actual_actor_episodes'] == 194
assert not custody['source']['local_delta']
assert receipt['custody_sha256'] == sha(physical / 'custody.json')
assert receipt['report_sha256'] == sha(physical / 'episodes.json')
assert receipt['runner_sha256'] == sha(ROOT / 'tools/ambient/run_episodes.py')
assert receipt['analyzer_sha256'] == sha(ROOT / 'tools/ambient/analyze_episodes.py')
assert custody['source'] == local_custody['source']
assert custody['loaded_project_sha256'] == local_custody['loaded_project_sha256']
assert custody['experiment_tools_sha256'] == local_custody['experiment_tools_sha256']
assert custody['engine']['sha256'] == local_custody['engine']['sha256']
assert custody['runtime'] == local_custody['runtime']

registry_path = physical / receipt['registry']
registration = read(registry_path)
registration_receipt = read(registry_path.parent / 'execution.json')
assert receipt['registry_sha256'] == sha(registry_path)
assert receipt['registration_receipt_sha256'] == sha(registry_path.parent / 'execution.json')
assert registration_receipt['console_sha256'] == sha(registry_path.parent / 'console.log')
assert registration_receipt['report_sha256'] == sha(registry_path)
assert registration_receipt['custody_sha256'] == receipt['custody_sha256']
runner.check_terminal(registry_path.parent / 'console.log', registration, registration_receipt, '', SOURCE, 'registry')

aggregate = read(physical / 'episodes.json')
reducer.validate(aggregate, source_root=ROOT)
assert len(aggregate['shard_receipts']) == 122
campaigns = {c['id']: c for c in aggregate['campaigns']}
matches = []
for retained in aggregate['shard_receipts']:
    report_path = physical / retained['report']
    execution_path = physical / retained['execution_receipt']
    console_path = physical / retained['console']
    assert retained['report_sha256'] == sha(report_path)
    assert retained['execution_receipt_sha256'] == sha(execution_path)
    assert retained['console_sha256'] == sha(console_path)
    report, execution = read(report_path), read(execution_path)
    assert execution['report_sha256'] == sha(report_path)
    assert execution['console_sha256'] == sha(console_path)
    assert execution['custody_sha256'] == receipt['custody_sha256']
    cid = report['campaigns'][0]['id']
    runner.check_terminal(console_path, report, execution, cid, SOURCE, 'full')
    reducer.validate(report, source_root=ROOT)
    current = report['campaigns'][0]
    assert current == campaigns[cid]
    original = read(LOCAL / retained['report'])['campaigns'][0]
    assert current['id'] == original['id']
    assert current['initial_materials'] == original['initial_materials']
    assert current['initial_pose_sha256'] == original['initial_pose_sha256']
    assert current['geometry'] == original['geometry']
    assert len(current['episodes']) == len(original['episodes'])
    actor_rows = []
    for hosted, local in zip(current['episodes'], original['episodes']):
        assert hosted['episode_id'] == local['episode_id']
        assert hosted['profile'] == local['profile']
        assert len(hosted['trace']) == len(local['trace'])
        position_differences = [math.dist(h['position'], l['position']) for h,l in zip(hosted['trace'], local['trace'])]
        actor_rows.append({
            'episode_id': hosted['episode_id'],
            'position_samples': len(position_differences),
            'exact_position_samples': sum(value == 0 for value in position_differences),
            'maximum_position_difference_cells': max(position_differences),
            'selection_differences': sum(h['selection'] != l['selection'] for h,l in zip(hosted['trace'], local['trace'])),
            'phase_differences': sum(h['phase'] != l['phase'] for h,l in zip(hosted['trace'], local['trace'])),
            'exact_complete_trace': hosted['trace'] == local['trace'],
        })
    matches.append({'campaign_id': cid, 'initial_materials_and_pose_match': True, 'profiles_match': True,
                    'hosted_report_sha256': sha(report_path), 'local_report_sha256': sha(LOCAL / retained['report']),
                    'actors': actor_rows})

rows = [r for match in matches for r in match['actors']]
result = {
    'status': 'PASS', 'source_revision': SOURCE,
    'artifact_id': 14988238799,
    'artifact_sha256': sha(BASE.parent / 'artifact.zip'),
    'hosted_raw_report_sha256': sha(physical / 'episodes.json'),
    'local_raw_report_sha256': sha(LOCAL / 'episodes.json'),
    'hosted_runner_receipt_sha256': sha(physical / 'runner-receipt.json'),
    'source_input_count': len(custody['source']['source_inputs_sha256']),
    'loaded_project_input_count': len(custody['loaded_project_sha256']),
    'verified_campaigns': len(matches), 'actual_actor_episodes': len(rows),
    'position_samples': sum(r['position_samples'] for r in rows),
    'exact_position_samples': sum(r['exact_position_samples'] for r in rows),
    'maximum_position_difference_cells': max(r['maximum_position_difference_cells'] for r in rows),
    'selection_differences': sum(r['selection_differences'] for r in rows),
    'phase_differences': sum(r['phase_differences'] for r in rows),
    'exact_complete_actor_traces': sum(r['exact_complete_trace'] for r in rows),
    'cases': matches,
    'limits': [
        'Both complete executions use the stated Linux engine/native bytes; agreement is not a cross-platform bit-determinism guarantee.',
        'Repeated execution of the registered194cases does not create194additional independent experimental conditions.',
        'All original per-process reports, consoles and execution receipts were checked against retained SHA-256 references.',
        'Local timings after approximately03:20UTC were contended; behavioral comparisons do not equate local and hosted performance environments.',
    ],
    'auditor_sha256': sha(Path(__file__)),
}
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'receipt-chain-and-repeat.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k:v for k,v in result.items() if k not in {'cases','limits'}}))
