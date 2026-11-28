#!/usr/bin/env python3
"""Reproduce retained fixture completion schemas from unchanged process evidence."""
import json
from pathlib import Path
import re
import sys

BASE = Path('/workspace/scratch/1f637294a480')
SOURCE = BASE / 'mat-solver-source2'
EVIDENCE = BASE / 'qualification/existing-solver-regressions-source2'
CANDIDATE = BASE / 'evidence/hosted-source2-linux/build/audition-linux'
sys.path.insert(0, str(SOURCE / 'tools/ci'))
import run_material_audition_qualification as q

manifest = q.verify(SOURCE, CANDIDATE, 'linux')
original = json.loads((EVIDENCE / 'qualification.json').read_text())
q.require(original['source_commit'] == manifest['source_commit'] and original['native_sha256'] == manifest['native_sha256'], 'Source or runtime mismatch')
q.require(q.sha(SOURCE / q.RUNTIMES['linux']) == manifest['native_sha256'], 'Installed source2 runtime differs')
for path, digest in original['files_sha256'].items():
    q.require(q.sha(EVIDENCE / path) == digest, 'Original execution evidence changed: ' + path)
sections = {
    'test_liquid_solver_policy': {'cysd1_defaults': True, 'default_readback': True, 'parity_checkpoints': 5,
                                 'refusals': 11, 'validation': True, 'whole_cell_admission_parity': True,
                                 'whole_cell_overlay_refusals': True},
    'test_liquid_policy_worker': {'explicit': True, 'initial': True, 'isolation': True, 'no_request': True,
                                 'normalized': True, 'refusals': 3},
    'test_lcb_inertial_adapter': {key: True for key in ('oracle_parameters', 'instance_readback', 'radius_transaction',
                                'mixed_workers', 'cyps_continuation', 'default_preservation')},
    'test_wave_flow': {key: True for key in ('native_configuration', 'mass_readback', 'region_pause', 'state_identity',
                      'save_refusal', 'solver_comparison', 'fixtures', 'rapier_contact', 'needle_contact')},
}
markers = {'test_liquid_solver_policy': 'LIQUID_SOLVER_POLICY:', 'test_liquid_policy_worker': 'LIQUID_POLICY_WORKER:',
           'test_lcb_inertial_adapter': 'LCB_INERTIAL_ADAPTER:', 'test_wave_flow': 'WAVE_FLOW:'}
rows = []
for case in original['cases']:
    name = case['name']
    receipt_path, log_path = EVIDENCE / (name + '.receipt.json'), EVIDENCE / (name + '.log')
    receipt = json.loads(receipt_path.read_text())
    text = log_path.read_text(encoding='utf-8')
    q.require(receipt['status'] == 'passed' and type(receipt['exit_code']) is int and receipt['exit_code'] == 0 and
              receipt['log_sha256'] == q.sha(log_path) and not q.ERRORS.search(text), 'Original process failed')
    q.require(case['test_sha256'] == q.sha(SOURCE / ('godot/tests/' + name + '.gd')), 'Fixture source changed')
    if name in markers:
        marker = markers[name]
        complete = q.completion(text, marker)
        q.require(complete == receipt['completion'], 'Original counted completion differs')
        lines = [line for line in text.splitlines() if line.startswith(marker + ' ')]
        actual = json.loads(lines[0].split('completed=', 1)[1])
        expected = sections[name]
        q.require(actual == expected and all(type(actual[key]) is type(value) for key, value in expected.items()),
                  'Retained fixture completion schema does not match required sections/counters')
        complete = complete | {'completed': actual}
    elif name == 'test_workbench_material_baseline':
        values = re.findall(r'^WORKBENCH_MATERIAL_BASELINE checks=(\d+) failures=(\d+)$', text, re.M)
        q.require(len(values) == 1 and int(values[0][0]) > 0 and values[0][1] == '0', 'Baseline failed')
        complete = {'checks': int(values[0][0]), 'failures': 0}
    else:
        lines = [line[len('WORKBENCH_PHYSICS '):] for line in text.splitlines() if line.startswith('WORKBENCH_PHYSICS ')]
        q.require(len(lines) == 1, 'Missing unique physics result')
        complete = json.loads(lines[0])
        q.require(type(complete.get('assertions')) is int and complete['assertions'] > 0 and complete['failures'] == [] and
                  len(complete['results']) == 4 and complete == json.loads((EVIDENCE / 'workbench-physics-readback.json').read_text()),
                  'Physical Workbench cases failed or incomplete')
    rows.append({'name': name, 'status': 'passed', 'completion': complete, 'process_receipt_sha256': q.sha(receipt_path),
                 'log_sha256': q.sha(log_path), 'test_sha256': case['test_sha256']})
q.require(len(rows) == 6, 'Missing requested regression case')
result = {'schema': 'cybersand.material-audition.existing-solver-regression-review', 'schema_version': 1,
          'status': 'passed', 'source_commit': manifest['source_commit'], 'source_tree': manifest['source_tree'],
          'native_sha256': manifest['native_sha256'], 'godot_version': original['godot_version'],
          'godot_sha256': original['godot_sha256'], 'rapier_sha256': original['rapier_sha256'],
          'native_build_run_id': manifest['run_id'], 'candidate_manifest_sha256': q.sha(CANDIDATE / q.MANIFEST),
          'original_wrapper_summary_sha256': q.sha(EVIDENCE / 'qualification.json'),
          'reviewer_script_sha256': q.sha(Path(__file__)), 'original_processes_unchanged': True,
          'correction': 'The first external reducer wrongly required all completed fields to be booleans; retained policy fixtures intentionally count refusals and parity checkpoints. Original processes all exited0 with zero failures. This separate typed-schema review preserves that earlier reduction and every original receipt/log; no execution was repeated or reclassified from failure.',
          'cases': rows, 'assertions': sum(row['completion'].get('checks', row['completion'].get('assertions', 0)) for row in rows)}
q.write(EVIDENCE / 'independent-review.json', result)
print(json.dumps({'status': result['status'], 'source_commit': result['source_commit'], 'assertions': result['assertions'],
                  'cases': [(row['name'], row['completion'].get('checks', row['completion'].get('assertions'))) for row in rows]}))
