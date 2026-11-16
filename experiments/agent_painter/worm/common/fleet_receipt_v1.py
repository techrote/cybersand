#!/usr/bin/env python3
"""Opt-in evidence envelopes for WORM W0 fleet experiments; never runs a model.

A completed synthetic W0 process is not a resident inference model. A reported
model count is only an externally sampled concurrent-process observation, not
independent proof of native Godot execution or authorisation to expand leases.
"""
from __future__ import annotations

from collections import Counter, defaultdict
import hashlib
import json
import re

CONTRACT = 'cybersand.worm.fleet-evidence/1-experimental'
W0_CONTRACT = 'cybersand.worm.observation-action/0-experimental'
EVIDENCE_CLASSES = frozenset(('synthetic_w0', 'model_scored_w0', 'native_model'))
STATES = frozenset(('queued', 'starting', 'loaded', 'actively_deciding',
                    'completed', 'failed', 'stopped'))
ACTIVE_WINDOW_NS = 15_000_000_000
_SHA = re.compile(r'[0-9a-f]{64}\Z')


def _sha(value: str) -> bool:
    return isinstance(value, str) and _SHA.fullmatch(value) is not None


def original_w0_envelope(record: dict, png: bytes, *, wrangler_id: str,
                         lease_id: str, runner_id: str, run_id: str,
                         job_id: str) -> dict:
    """Bind original synthetic W0 PNG + canonical event bytes.

    Never set model/PID evidence here: a Python W0 replay does not imply inference.
    """
    if record.get('contract') != W0_CONTRACT or record.get('engine') != 'python-stdlib-baseline-not-native':
        raise ValueError('record is not the pinned synthetic W0 contract')
    if not (isinstance(record.get('steps_executed'), int) and
            0 <= record['steps_executed'] <= record.get('step_budget', -1) and
            len(record.get('events', [])) == record['steps_executed']):
        raise ValueError('W0 event/budget mismatch')
    if not isinstance(png, bytes) or not png.startswith(b'\x89PNG\r\n\x1a\n'):
        raise ValueError('original PNG bytes required')
    canonical = (json.dumps(record, sort_keys=True, separators=(',', ':')) + '\n').encode()
    out = dict(contract=CONTRACT, wrangler_id=wrangler_id, lease_id=lease_id,
               runner_id=runner_id, run_id=str(run_id), job_id=str(job_id),
               evidence_class='synthetic_w0', status='completed',
               world_seed=record['seed'], decision_budget=record['step_budget'],
               decisions_applied=record['steps_executed'],
               original_png_sha256=hashlib.sha256(png).hexdigest(),
               original_receipt_sha256=hashlib.sha256(canonical).hexdigest(),
               model_forward_count=0, native_execution=False)
    validate_identity(out)
    return out


def validate_identity(x: dict) -> None:
    if not isinstance(x, dict) or x.get('contract') != CONTRACT:
        raise ValueError('invalid fleet evidence contract')
    for k in ('wrangler_id', 'lease_id', 'runner_id', 'run_id', 'job_id'):
        if not isinstance(x.get(k), str) or not x[k].strip():
            raise ValueError('missing identity: ' + k)
    if x.get('status') not in STATES or x.get('evidence_class') not in EVIDENCE_CLASSES:
        raise ValueError('unknown state or evidence class')
    if not isinstance(x.get('world_seed'), int) or not isinstance(x.get('decision_budget'), int) or x['decision_budget'] < 0:
        raise ValueError('seed/budget not recorded')
    if x['evidence_class'] == 'synthetic_w0' and (x.get('model_forward_count', 0) != 0 or x.get('native_execution', False)):
        raise ValueError('synthetic W0 cannot claim inference or native execution')
    if x['evidence_class'] == 'model_scored_w0' and x.get('native_execution', False):
        raise ValueError('model-scored synthetic W0 is not native')
    if x['evidence_class'] == 'native_model' and x.get('native_execution') is not True:
        raise ValueError('native evidence must be explicit')
    if x['status'] == 'completed':
        for k in ('original_png_sha256', 'original_receipt_sha256'):
            if not _sha(x.get(k)):
                raise ValueError('completed claim has no original digest: ' + k)
        applied = x.get('decisions_applied')
        if not isinstance(applied, int) or not 0 <= applied <= x['decision_budget']:
            raise ValueError('invalid applied decision count')


def is_live_model(x: dict, *, sampled_utc_ns: int,
                  max_age_ns: int = ACTIVE_WINDOW_NS) -> bool:
    """Require actual PID-liveness and in-flight forward sampled on the runner.

    Checks an externally supplied measurement; only source-bound authentic runner
    observations are sufficient evidence for a real fleet admission.
    """
    validate_identity(x)
    if x['status'] != 'actively_deciding' or x['evidence_class'] == 'synthetic_w0':
        return False
    if (x.get('pid_alive') is not True or x.get('forward_in_flight') is not True or
            not isinstance(x.get('pid'), int) or x['pid'] <= 0 or
            not isinstance(x.get('model_forward_count'), int) or x['model_forward_count'] < 1):
        return False
    for k in ('model_revision', 'model_name'):
        if not isinstance(x.get(k), str) or not x[k].strip():
            return False
    for k in ('model_sha256', 'checkpoint_sha256', 'source_sha256', 'world_sha256'):
        if not _sha(x.get(k)):
            return False
    if x['evidence_class'] == 'native_model' and x.get('native_host_receipts_verified') is not True:
        return False
    for k in ('pid_sampled_utc_ns', 'forward_sampled_utc_ns'):
        t = x.get(k)
        if not isinstance(t, int) or not 0 <= sampled_utc_ns - t <= max_age_ns:
            return False
    return True


def summarise_fleet(leases: list[dict], *, sampled_utc_ns: int) -> dict:
    """Counts unique simultaneous model PIDs; never counts queued/W0 stubs."""
    if not isinstance(sampled_utc_ns, int) or sampled_utc_ns <= 0:
        raise ValueError('real runner sampled UTC nanoseconds required')
    ids = set()
    live_pid_keys = set()
    statuses = Counter()
    per_wrangler = defaultdict(int)
    per_runner = defaultdict(Counter)
    for x in leases:
        validate_identity(x)
        if x['lease_id'] in ids:
            raise ValueError('duplicate lease ID')
        ids.add(x['lease_id'])
        statuses[x['status']] += 1
        if is_live_model(x, sampled_utc_ns=sampled_utc_ns):
            key = (x['runner_id'], x['pid'])
            if key in live_pid_keys:
                raise ValueError('one resident PID counted twice')
            live_pid_keys.add(key)
            per_wrangler[x['wrangler_id']] += 1
            per_runner[x['wrangler_id']][x['runner_id']] += 1
    four_reported = bool(per_wrangler) and all(n >= 4 for n in per_wrangler.values())
    cross_runner_four = any(sum(counts.values()) >= 4 and len(counts) > 1
                            for counts in per_runner.values())
    # Supplied PID/UTC fields are unauthenticated telemetry, not proof.
    # In particular, cross-VM monotonic timestamps have unrelated epochs.
    # Original on-runner progress plus independent common-time liveness
    # evidence must be verified externally before a four-active claim.
    return dict(contract=CONTRACT, sampled_utc_ns=sampled_utc_ns,
                status_counts=dict(sorted(statuses.items())),
                active_resident_models=len(live_pid_keys),
                active_per_wrangler=dict(sorted(per_wrangler.items())),
                active_per_wrangler_runner={
                    wrangler: dict(sorted(counts.items()))
                    for wrangler, counts in sorted(per_runner.items())},
                four_active_per_wrangler_reported=four_reported,
                four_active_per_wrangler_proven=False,
                cross_runner_four_requires_independent_clock_witness=cross_runner_four,
                caveat=('UNVERIFIED telemetry counts only: externally verify real model '
                        'weights, source, PIDs, forward progress and common-time '
                        'cross-runner concurrency; synthetic W0 is not model capacity'))
