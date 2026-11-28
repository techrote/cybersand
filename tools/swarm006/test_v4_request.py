#!/usr/bin/env python3
"""Exercise exact native V4 transport; retain every synthetic owner-style outcome.

This is development transport evidence, not a fresh holdout or an owner World.
No passing count or foreign-joint outcome is imposed on these declared examples.
Native success must independently close every remaining foreign obligation.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

CASES = {
    'industrial': (192, 112, (.65, .15, 0., 0., .75, 1., .15)),
    'viaduct_like': (192, 112, (.65, .05, .15, 0., .55, .25, .35)),
    'irregular_megastructure': (192, 112, (.65, .95, .25, 0., 1., .7, .2)),
    'irregular_square': (128, 128, (.65, .95, .25, 0., 1., .7, .2)),
}


def request(name: str, recovery: bool, v3: bool = False) -> str:
    width, height, parameters = CASES[name]
    profile = 'irregular_megastructure' if name == 'irregular_square' else name
    knobs = ' '.join(f'{value:.8f}' for value in parameters)
    lines = ['SWARM005 3' if v3 else 'SWARM006 4', f'{width} {height} 605 0 0 2 13 -1', profile,
             knobs+' 1', knobs+' 1', '1 1' if v3 else '1 1 '+str(int(recovery)), '1', '64 48']
    for y in range(height):
        for x in range(width):
            inside = 4 <= x < width-4 and 4 <= y < height-4
            lines.append(f'{int(inside and x < width//2)} {int(inside and x >= width//2)} 0 '
                         f'{int(inside and width//2-14 <= x <= width//2+13)} 0')
    return '\n'.join(lines)+'\n'


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--source', required=True)
    args = parser.parse_args()
    if args.output.exists() and any(args.output.iterdir()):
        raise ValueError('Native V4 evidence destination must be fresh')
    args.output.mkdir(parents=True, exist_ok=True)
    rows = []

    def execute(label: str, text: str, valid: bool = True) -> dict:
        inp, out = args.output/(label+'.txt'), args.output/(label+'.json')
        inp.write_text(text)
        child = subprocess.run([str(args.exe.resolve()), 'request', str(inp), str(out), args.source],
                               capture_output=True, text=True, timeout=90)
        (args.output/(label+'.log')).write_text(child.stdout+child.stderr)
        if not valid:
            assert child.returncode != 0 and not out.exists(), label
            return {}
        assert child.returncode == 0 and out.exists(), (label, child.stderr)
        value = json.loads(out.read_text())
        assert value['source'] == args.source and value['status'] != 'invalid', label
        options = value['input']['options']
        assert options['compact_native_termination'] is True and options['supported_native_receptors'] is True
        assert options['rounds'] == 2 and options['shared_ownership'] is True
        bounds = {'frame_work': 2000000, 'mosaic_work': 2000000, 'solver_work': 4000000, 'shared_work': 2000000}
        for field, maximum in bounds.items():
            assert type(value['metrics'][field]) is int and 0 <= value['metrics'][field] <= maximum, (label, field)
        assert sum(value['metrics'][field] for field in bounds) <= 10000000, label
        if value['can_apply']:
            assert value['status'] == 'complete' and value['cells'], label
            assert all(o['state'] == 'FOREIGN_JOINED' and o['foreign_joined'] is True and not o['local_terminated']
                       for o in value['obligations']), label
        return value

    for name in CASES:
        old = execute(name+'-v3', request(name, False, True))
        off = execute(name+'-v4-off', request(name, False))
        assert off == old and off['schema'] == 5, name+' OFF changes V3 semantics'
        candidate = execute(name+'-v4-on', request(name, True))
        assert candidate['schema'] == 6 and candidate['programme'] == 'GENTEK-SWARM-006'
        assert candidate['identity'] == 'gentek_swarm_006_negotiated_recovery_v1'
        assert candidate['input']['options']['negotiated_recovery'] is True
        assert candidate['input']['options']['recovery_offers'] is True
        replay = execute(name+'-v4-replay', request(name, True))
        assert replay == candidate, name+' replay changed'
        for round_value in candidate['rounds']:
            assert len(round_value['recovery_frontier']) <= 8 and len(round_value['mosaic_recovery_receipts']) <= 8
            assert len(round_value['recovery_attempts']) <= 520 and round_value['recovery_work'] <= 2000000
        for label, value in [('off', off), ('on', candidate)]:
            plane = b''.join(int(cell).to_bytes(2, 'little') for cell in value['cells'])
            remaining = value['metrics'].get('still_required')
            evaluated = value['status'] in ('complete', 'blocked') and type(remaining) is int and remaining >= 0
            row = {'case': name, 'recovery': label, 'status': value['status'], 'can_apply': value['can_apply'],
                   'stop_reason': value['stop_reason'], 'native_cells': sum(cell != 0 for cell in value['cells']),
                   'joints': len(value['joints']), 'obligations': len(value['obligations']),
                   'closure_evaluated': evaluated, 'unresolved': remaining if evaluated else None,
                   'retained_obligation_unresolved': sum(o['state'] == 'STILL_REQUIRED' for o in value['obligations']),
                   'material_sha256': hashlib.sha256(plane).hexdigest(), 'metrics': value['metrics']}
            rows.append(row);print(json.dumps(row), flush=True)
    lines = request('industrial', True).splitlines()
    for label, header, flags in [('wrong_version', 'SWARM006 3', '1 1 1'),
                                  ('wrong_family', 'SWARM005 4', '1 1 1'),
                                  ('bad_bool', 'SWARM006 4', '1 1 2'),
                                  ('missing_bool', 'SWARM006 4', '1 1'),
                                  ('trailing', 'SWARM006 4', '1 1 1')]:
        malformed = lines.copy();malformed[0] = header;malformed[5] = flags
        if label == 'trailing': malformed.append('999')
        execute(label, '\n'.join(malformed)+'\n', False)
    (args.output/'summary.json').write_text(json.dumps({'source': args.source, 'synthetic_blank_world': True,
                                                     'owner_nvidia_acceptance': 'pending', 'rows': rows}, indent=2)+'\n')
    print('PASS SWARM006_V4_NATIVE: four paired controls, exact replay, five malformed-request refusals')


if __name__ == '__main__': main()
