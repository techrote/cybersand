#!/usr/bin/env python3
"""Revisit existing exact c90 causal clocks before registering another capture."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--workspace-root', type=Path, default=Path('/workspace/scratch/0b2a9bdf7883'))
parser.add_argument('--output', type=Path)
args = parser.parse_args()
base = args.workspace_root
root = base/'cybersand-qualification'
sys.path[:0] = [str(root/'tools/pubpres003'), str(root/'tools/pubpres_final')]
from causal_trace import analyze
from independent_reduction import witnessed_steps, summary

def sha(data):
    return hashlib.sha256(data).hexdigest()

source = 'c90dbc46e1f57f28e06b1f4205b83467335ff657'
for relative in ('tools/pubpres003/causal_trace.py', 'tools/pubpres003/audit_traces.py'):
    committed = subprocess.check_output(['git', '-C', str(root), 'show', source+':'+relative])
    assert committed == (root/relative).read_bytes(), relative
archive = base/'evidence-c/14778950415-original.zip'
prefix = 'causal/wave_gameplay_2048_follow/0-C/'
with zipfile.ZipFile(archive) as z:
    raw = {name: z.read(prefix+name) for name in ('receipt.json', 'receipt-events.jsonl',
           'receipt-causal-events.jsonl', 'causal-analysis.json', 'arm.json')}
receipt = json.loads(raw['receipt.json'])
base_events = [json.loads(line) for line in raw['receipt-events.jsonl'].splitlines()]
causal = [json.loads(line) for line in raw['receipt-causal-events.jsonl'].splitlines()]
identity = causal[0]
assert sha(raw['receipt-events.jsonl']) == identity['base_trace_sha256'] == receipt['trace_sha256']
assert sha(raw['receipt-causal-events.jsonl']) == receipt['observer_extension']['sha256']
assert identity['source'] == receipt['source_identity'] and identity['fixture'] == receipt['fixture']
assert identity['enabled'] is True
assert all(identity[k] == receipt[k] for k in ('capture_start_usec', 'capture_end_usec'))
steps, witness = witnessed_steps(receipt, base_events[1:])
replayed = analyze(identity, causal[1:], receipt, base_events[1:])
original = json.loads(raw['causal-analysis.json'])
assert all(value == original[key] for key, value in replayed.items())
worker = [e for e in causal[1:] if e['observer_owner'] == 'worker']
by_kind = {}
for event in worker:
    by_kind.setdefault(event['kind'], []).append(event)
partitions = []
for previous, step in zip(steps, steps[1:]):
    native = [e for e in by_kind['native_tick'] if e['body_sample'] == step['completed_body_sample']
              and e['tick_index'] == step['native_tick_used'] and e['world_generation'] == step['world_generation']
              and e['session'] == step['session'] and e['rigid_body_epoch'] == step['epoch']]
    assert len(native) == 1
    native = native[0]
    matches = lambda kind: [e for e in by_kind[kind] if e['body_sample'] == native['body_sample']
                            and e['session'] == native['session'] and e['rigid_body_epoch'] == native['rigid_body_epoch']]
    admission, latch = matches('sample_admitted'), matches('worker_latch')
    assert len(admission) == len(latch) == 1
    admission, latch = admission[0], latch[0]
    clocks = [previous['time_usec'], admission['start_usec'], admission['completed_usec'],
              latch['start_usec'], native['start_usec'], native['completed_usec'], step['time_usec']]
    partitions.append({'step': step['step'], 'clocks_usec': clocks,
                       'ordered': all(a <= b for a, b in zip(clocks, clocks[1:])),
                       'previous_completion_to_admission_start_ms': (clocks[1]-clocks[0])/1000,
                       'admission_call_wall_ms': (clocks[2]-clocks[1])/1000,
                       'admission_completed_to_worker_latch_ms': (clocks[3]-clocks[2])/1000,
                       'worker_latch_to_native_start_ms': (clocks[4]-clocks[3])/1000,
                       'native_wall_ms': (clocks[5]-clocks[4])/1000,
                       'native_completion_to_physical_completion_ms': (clocks[6]-clocks[5])/1000,
                       'observed_native_deadline_lateness_ms': native['lateness_usec']/1000})
result = {'schema':'pubpres-historical-c90-causal-stage-recovery-v1',
          'program_sha256':sha(Path(__file__).read_bytes()),
          'archive_sha256':sha(archive.read_bytes()),
          'members_sha256':{prefix+name:sha(value) for name,value in raw.items()},
          'source':json.loads(raw['arm.json'])['source'], 'base_step_witness':witness,
          'unchanged_causal_reducer_replay':True,
          'replayed_joined_transactions':replayed['matched_native_to_rapier_transactions'],
          'historical_transaction_latency_ms':replayed['transaction_latency_ms'],
          'historical_main_phase_wall_ms':replayed['main_phase_wall_ms'],
          'consecutive_gap_partitions':partitions,
          'nonordered_partitions':[p for p in partitions if not p['ordered']],
          'partition_distributions':{k:summary(p[k] for p in partitions) for k in partitions[0] if k.endswith('_ms')},
          'scope':['Existing single Windows c90 current-gameplay Wave2048 causal ON diagnostic, not a new runtime execution.',
                   'Admission-to-latch includes wake/queue/scheduling delay and cannot identify kernel wakeup alone.',
                   'Worker native elapsed includes descheduling and is not on-CPU execution.',
                   'This capture already answers the broad large-workload post-publication delay question at c90.',
                   'No matched causal off/on/on/off calibration or Wave512 stage capture exists in this recovered cohort.',
                   'A prospective Wave512 diagnostic is justified; no broad repeated Wave2048 campaign is necessary.'],
          'physical_acceptance':'HOLD'}
output = args.output or base/'evidence-c/historical-c90-causal-stage-recovery.json'
output.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'output':str(output),'sha256':sha(output.read_bytes()),
                  'transactions':replayed['matched_native_to_rapier_transactions'],
                  'nonordered':len(result['nonordered_partitions']),
                  'distributions':result['partition_distributions']}))
