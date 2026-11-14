"""D-2 pre-registered off-line confirmation consumer. No model/native execution.

Fixture source+manifest frozen independently at commit 8b2fe242666ba8ee4c6459a43e39de0ef0f582a6
BEFORE this module or its outcomes existed. Do not tune fixture/policy on results.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

import confirmation_fixtures as ff
import pareto_study as policy

FROZEN_COMMIT = '8b2fe242666ba8ee4c6459a43e39de0ef0f582a6'
FROZEN_FIXTURE_SHA256 = 'de9ca09eca3ec6a67d106c40e8fb2084b53c719a18259552518bfc4184bfe14c'
FROZEN_MANIFEST_SHA256 = 'fcdf3103ffba3da992d46ceee61ce21829d5a185a75a2fece673e431d079b9fb'
POLICY_GIT_BLOB = '7fe2f1c49f765730354077703c1aae76c40a41b9'
VERSION = 'd2.synthetic-confirmation/1'


def verify_frozen_input(root: Path) -> dict:
    original = (root / 'corpus' / 'confirmation-prereg-v1.json').read_bytes()
    expected = ff.encode(ff.manifest()) + b'\n'
    if ff.digest(original) != FROZEN_MANIFEST_SHA256 or original != expected:
        raise ValueError('predeclared manifest changed; do not silently regenerate holdout')
    if ff.digest((root / 'confirmation_fixtures.py').read_bytes()) != FROZEN_FIXTURE_SHA256:
        raise ValueError('fixture source changed; refuse post-freeze edits')
    return json.loads(original)


def permitted_reachability(permitted, initial):
    """Hard-mask reachability ignores paint budget, guidance, and controller.

    If material islands are in separate 4-connected *permitted* domains, no
    authorized bridge can connect them, irrespective of algorithm or budget.
    """
    remaining = set(permitted)
    reach = []
    while remaining:
        p = min(remaining); pending = [p]; remaining.remove(p); group = {p}
        while pending:
            x, y = pending.pop()
            for dx,dy in ((0,1),(1,0),(0,-1),(-1,0)):
                q = (x+dx,y+dy)
                if q in remaining:
                    remaining.remove(q); group.add(q); pending.append(q)
        reach.append(group)
    occupied_domains = sum(bool(group & initial) for group in reach)
    return {'permitted_domains':len(reach),
            'initial_occupied_permitted_domains':occupied_domains,
            'all_initial_islands_globally_reachable':occupied_domains == 1}


def audit_events(initial, allowed, result, final):
    """Reconstruct synthetic edits; cursor travel and route plans never paint."""
    material = set(initial); steps = 0
    for event in result['events']:
        if event['before'] != policy.cell_sha(material):
            raise AssertionError('synthetic material before-hash mismatch')
        if event['kind'] in ('BRUSH_UP_ROUTE', 'BRIDGE_PATH_SYNTHETIC'):
            if event['before'] != event['after']:
                raise AssertionError('cursor move/route plan modified material')
            route = [tuple(p) for p in event['path']]
            if not route or not all(p in allowed for p in route):
                raise AssertionError('synthetic path outside permitted mask')
            for p, q in zip(route,route[1:]):
                if abs(p[0]-q[0]) + abs(p[1]-q[1]) != 1:
                    raise AssertionError('non-cardinal step in synthetic path')
        elif event['kind'] == 'SYNTHETIC_BRIDGE_PAINT':
            p = tuple(event['point'])
            if p not in allowed or p in material:
                raise AssertionError('duplicate or prohibited new material')
            material.add(p); steps += 1
            if event['after'] != policy.cell_sha(material):
                raise AssertionError('synthetic material after-hash mismatch')
        else:
            raise AssertionError('unknown event kind')
    if material != final or steps != result['new_cells'] or result['material_sha256'] != policy.cell_sha(final):
        raise AssertionError('final material or edit count mismatch')


def run(out: Path, names=None):
    root = Path(__file__).resolve().parent
    frozen = verify_frozen_input(root)
    if policy.VERSION != 'd2.synthetic-topology-pareto/1' or tuple(policy.POLICIES) != tuple(frozen['policy_arm_names']):
        raise ValueError('policy interface changed since preregistration')
    if policy.WIDTH != 32 or policy.HEIGHT != 32 or policy.THRESHOLD != 48000:
        raise ValueError('policy geometry/threshold changed')
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    requested = set(names) if names is not None else {c['id'] for c in frozen['cases']}
    if not requested <= {c['id'] for c in frozen['cases']}:
        raise ValueError('not predeclared')
    cases = []
    for registered in frozen['cases']:
        name = registered['id']
        if name not in requested:
            continue
        seed = registered['seed']; allowed, initial, scalar = ff.fixture(name, seed)
        case_dir = out / name; case_dir.mkdir(exist_ok=True)
        original_view = policy.png(initial, allowed)
        guide_bytes = struct.pack('<1024H',*(scalar[(x,y)] for y in range(32) for x in range(32)))
        (case_dir / 'original.png').write_bytes(original_view)
        (case_dir / 'guidance.u16le').write_bytes(guide_bytes)
        reach = permitted_reachability(allowed, initial)
        policies = {}
        for policy_name in frozen['policy_arm_names']:
            strict = policy_name == 'guidance-strict'
            weight = 0 if strict else int(policy_name.split('-')[1])
            result, after = policy.run_bridge(allowed, initial, scalar, budget=44,
                                              weight=weight, strict=strict, max_hops=120)
            audit_events(initial, allowed, result, after)
            control, ctrl_after = policy.guidance_greedy(allowed,initial,scalar,result['new_cells'])
            if len(ctrl_after - initial) != result['new_cells']:
                raise AssertionError('unequal actual paint budget')
            after_view = policy.png(after,allowed)
            control_view = policy.png(ctrl_after,allowed)
            events_raw = ff.encode(result['events']) + b'\n'
            (case_dir / (policy_name + '.png')).write_bytes(after_view)
            (case_dir / (policy_name + '-control.png')).write_bytes(control_view)
            (case_dir / (policy_name + '-events.json')).write_bytes(events_raw)
            summary = {k:v for k,v in result.items() if k != 'events'}
            summary.update({'view_sha256':ff.digest(after_view),
                            'events_file_sha256':ff.digest(events_raw),
                            'control_view_sha256':ff.digest(control_view),
                            'matched_control':control,
                            'control_components_delta':result['components'] - control['components']})
            policies[policy_name] = summary
        if name == 'hard-separator' and any(p['components']==1 for p in policies.values()):
            raise AssertionError('hard-separator negative control was crossed')
        cases.append({'id':name, 'seed':seed, 'registered':registered,
                      'reachability':reach,'original_png_sha256':ff.digest(original_view),
                      'policies':policies})
    report = {'version':VERSION,'qualification':'PRE_REGISTERED_SYNTHETIC_OFFLINE_ONLY',
              'freeze_commit':FROZEN_COMMIT,
              'frozen_fixture_sha256':FROZEN_FIXTURE_SHA256,
              'frozen_manifest_sha256':FROZEN_MANIFEST_SHA256,
              'policy_git_blob_sha1':POLICY_GIT_BLOB,
              'native_executed':False, 'native_receipts':0,
              'model_inference':False,'model_training':False,
              'material_undo':'HOST_NATIVE_RECEIPT_REQUIRED_NOT_TESTED',
              'visual_acceptance':'NOT_PERFORMED',
              'no_policy_or_fixture_tuning_after_freeze':True,
              'all_registered_cases_included':len(cases)==len(frozen['cases']),
              'cases':cases}
    raw = ff.encode(report) + b'\n'
    (out / 'confirmation-results.json').write_bytes(raw)
    return report, ff.digest(raw)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out',required=True,type=Path)
    args=parser.parse_args()
    result, h = run(args.out)
    print(ff.encode({'cases':len(result['cases']),'sha256':h,
                     'qualification':result['qualification']}).decode())


if __name__ == '__main__':main()
