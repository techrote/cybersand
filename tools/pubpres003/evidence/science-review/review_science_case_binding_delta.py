#!/usr/bin/env python3
"""Independent delta review; reuse untouched genuine receipt and trace."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path('/workspace/scratch/d425b9146667/pubpres003-science')
BASE = Path('/workspace/scratch/d425b9146667/pubpres003-science-recovery/extracted/pubpres-playability-linux-wave_512_follow-same-frame-44963596029-1/same-frame-abba')
sys.path.insert(0, str(ROOT / 'tools/pubpres003'))
from run_focus import validate_requested_capture, validate_complete_comparison

receipt = BASE / 'wave_512_follow/0-C/receipt.json'
data = json.loads(receipt.read_text())
campaign = json.loads((BASE / 'campaign.json').read_text())
cases = {c['id']: c for c in campaign['cases']}
commit = data['source_identity']['source_sha']
nonce = data['case_nonce']
validate_requested_capture(data, cases['wave_512_follow'], campaign, commit, nonce, 'opengl3')
rejections = {}
try:
    validate_requested_capture(data, cases['wave_2048_follow'], campaign, commit, nonce, 'opengl3')
except ValueError as error:
    rejections['original512_receipt_for_requested2048'] = str(error)
assert 'original512_receipt_for_requested2048' in rejections
for field, value in {
        'renderer': 'opengl3_angle', 'water_variant': 'cached_dormant', 'input_mode': 'neutral',
        'command_mode': 'once_per_step', 'observer_mode': 'reduced',
        'render_thread': {'requested': 'separate', 'runtime': 'separate'},
        'workers': 1, 'camera': 'free', 'water_profile': 'gameplay_main846f',
        'water_law': 'free_mass_v1', 'source_identity': {'source_sha': 'f' * 40},
        'case_nonce': 'replayed'} .items():
    changed = {**data, field: value}
    try:
        validate_requested_capture(changed, cases['wave_512_follow'], campaign, commit, nonce, 'opengl3')
    except ValueError as error:
        rejections[field] = str(error)
    assert field in rejections, field
analysis = json.loads((receipt.parent / 'analysis.json').read_text())
arms = [{'index': i, 'statistics': copy.deepcopy(analysis)} for i in range(4)]
validate_complete_comparison(arms, 4)
for field in ('adapter', 'cpu', 'logical_processors', 'display', 'fixture', 'tape', 'water_variant',
              'worker_capacities', 'initial_body_state_sha256', 'prepared_payload_hash', 'engine'):
    changed = copy.deepcopy(arms)
    changed[1]['statistics']['match'][field] = 'changed'
    try:
        validate_complete_comparison(changed, 4)
    except ValueError as error:
        rejections['match:' + field] = str(error)
    assert 'match:' + field in rejections, field
for label, changed in (('missing_arm', arms[:-1]), ('reordered_arms', arms[::-1])):
    try:
        validate_complete_comparison(changed, 4)
    except ValueError as error:
        rejections[label] = str(error)
    assert label in rejections
record = {
    'schema': 'pubpres003-independent-capture-binding-delta-review-v1',
    'reviewed_commit': subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip(),
    'reviewed_runner_sha256': hashlib.sha256((ROOT / 'tools/pubpres003/run_focus.py').read_bytes()).hexdigest(),
    'original_receipt_sha256': hashlib.sha256(receipt.read_bytes()).hexdigest(),
    'positive_original512_case': 'PASS', 'negative_checks': rejections,
    'disposition': 'PASS: confirmed request-binding and pair-completeness blocker repaired',
    'scope': 'Source/validator review and synthetic substitutions using an untouched genuine frozen receipt; no new graphical or performance claim.',
}
Path(__file__).with_suffix('.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
