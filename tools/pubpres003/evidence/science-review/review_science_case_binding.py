#!/usr/bin/env python3
"""Independently replay the request binding against retained genuine evidence.

No original receipt, trace, or source is changed. This exercises the exact AST
condition used by the reviewed runner, plus the unchanged frozen v3 reducer.
It is a validator adversary, not a new graphical/performance execution.
"""
import ast
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path('/workspace/scratch/d425b9146667/cybersand-pubpres003')
EVIDENCE = Path('/workspace/scratch/d425b9146667/pubpres003-science-recovery/extracted/pubpres-playability-linux-wave_512_follow-same-frame-44963596029-1/same-frame-abba')
OUT = Path(__file__).with_suffix('.json')
sys.path.insert(0, str(ROOT / 'tools/pubpres_playability'))
from results_same_frame import reduce_receipt

runner = ROOT / 'tools/pubpres003/run_focus.py'
source = runner.read_bytes()
tree = ast.parse(source)
calls = [n for n in ast.walk(tree) if isinstance(n, ast.Call) and isinstance(n.func, ast.Name)
         and n.func.id == 'need' and len(n.args) == 2 and isinstance(n.args[1], ast.Constant)
         and n.args[1].value == 'Captured workload differs']
assert len(calls) == 1, 'Reviewed check changed; inspect repaired driver instead.'
receipt = EVIDENCE / 'wave_512_follow/0-C/receipt.json'
data = json.loads(receipt.read_text())
campaign = json.loads((EVIDENCE / 'campaign.json').read_text())
case = next(c for c in campaign['cases'] if c['id'] == 'wave_2048_follow')
accepted = eval(compile(ast.Expression(calls[0].args[0]), str(runner), 'eval'), {},
                {'data': data, 'case': case, 'campaign': campaign})
effective = copy.deepcopy(campaign)
effective['arms']['C'] = json.loads((receipt.parent / 'arm.json').read_text())['arm']
analysis = reduce_receipt(receipt, effective, arm_letter='C')
record = {
    'schema': 'pubpres003-independent-case-binding-adversary-v1',
    'reviewed_commit': subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip(),
    'reviewed_runner_sha256': hashlib.sha256(source).hexdigest(),
    'original_receipt': str(receipt),
    'original_receipt_sha256': hashlib.sha256(receipt.read_bytes()).hexdigest(),
    'original_trace_sha256': analysis['trace_sha256'],
    'requested_case': case,
    'actual_fixture': data['fixture'],
    'existing_request_predicate_accepts_wrong_fixture': accepted,
    'frozen_v3_reduction_of_original_receipt_passes': True,
    'actual_completed_first_144_step_count': analysis['windows']['first_144_steps']['completed_rapier_steps'],
    'disposition': 'FAIL: requested 2048 workload is not bound to actual valid 512 receipt',
    'scope': 'Offline validator adversary only. Original source, source hashes, receipt and trace were not modified. Source/nonce bind as recorded for this same original run; the requested case identity alone is changed.',
}
assert accepted and data['fixture']['name'] != case['fixture']
OUT.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
