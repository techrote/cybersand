#!/usr/bin/env python3
"""Reduce COUPLING-LOCKSTEP-001 episodes into the registered (a)-(c) decisions."""
import argparse
import itertools
import json
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STEP_FIELDS = ('tick', 'publication', 'states', 'results', 'pre', 'post', 'character')


def compare(a, b):
    """First difference between two episodes, classified by the registered rule."""
    for k, (x, y) in enumerate(zip(a['steps'], b['steps'])):
        differing = [f for f in STEP_FIELDS if x[f] != y[f]]
        if not differing:
            continue
        if 'tick' in differing or 'publication' in differing:
            kind = 'RACE'
        elif 'pre' in differing:
            kind = 'OTHER'
        elif 'states' in differing:
            kind = 'OTHER'
        elif 'results' in differing:
            kind = 'NATIVE'
        elif 'post' in differing:
            kind = 'RAPIER'
        else:
            kind = 'OTHER'
        tick = x['tick']
        hash_equal = a['tick_hashes'][tick] == b['tick_hashes'][tick]
        return dict(equal=False, step=k, tick=tick, fields=differing, kind=kind, tick_hash_equal_at_step=hash_equal,
                    first_tick_hash_difference=first_hash(a, b))
    tails = dict(steps=len(a['steps']) == len(b['steps']), final_bits=a['final_bits'] == b['final_bits'],
                 state_hash=a['state_hash'] == b['state_hash'], final_physical_hash=a.get('final_physical_hash') == b.get('final_physical_hash'),
                 tick_hashes=a['tick_hashes'] == b['tick_hashes'])
    if all(tails.values()):
        return dict(equal=True)
    return dict(equal=False, step=None, kind='OTHER', tails=tails, first_tick_hash_difference=first_hash(a, b))


def first_hash(a, b):
    for tick, (x, y) in enumerate(zip(a['tick_hashes'], b['tick_hashes'])):
        if x != y:
            return tick
    return None


def load(run):
    folder = ROOT / 'build/coupling-lockstep' / run
    receipt = json.loads((folder / 'receipt.json').read_text(encoding='utf-8'))
    groups = {}
    for row in receipt['episodes']:
        if not row['clean']:
            groups.setdefault((row['host'], row['arm'], row['workers']), []).append(None)
            continue
        data = json.loads((ROOT / row['result']).read_text(encoding='utf-8'))
        groups.setdefault((row['host'], row['arm'], row['workers']), []).append(data)
    return receipt, groups


def cost(episodes):
    eps = [e for e in episodes if e]
    wall = [e['wall_usec'] / 1e6 for e in eps]
    rate = [e['rapier_steps'] / (e['wall_usec'] / 1e6) for e in eps]
    held = [e['held_frames'] / max(1, e['physics_frames']) for e in eps]
    ages = [sum(col) for col in zip(*[e['age_histogram'] for e in eps])]
    lock = [e['lockstep'] for e in eps]
    hold_mean = [l['hold_usec_total'] / l['holds'] for l in lock if l['holds']]
    return dict(episodes=len(eps), wall_seconds_median=statistics.median(wall), wall_seconds_range=[min(wall), max(wall)],
                rapier_steps_per_second_median=statistics.median(rate), held_frame_fraction_median=statistics.median(held),
                held_frames_total=sum(e['held_frames'] for e in eps), physics_frames_total=sum(e['physics_frames'] for e in eps),
                result_age_histogram=ages, worker_overruns=sum(e['worker_overruns'] for e in eps),
                worker_holds=sum(l['holds'] for l in lock), worker_hold_usec_mean_median=statistics.median(hold_mean) if hold_mean else 0,
                worker_hold_usec_max=max((l['hold_usec_max'] for l in lock), default=0),
                worker_timeouts=sum(l['timeouts'] for l in lock), lockstep_ticks=sum(l['ticks'] for l in lock),
                native_worker_threads=sorted({e['native_worker_threads'] for e in eps}))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', required=True)
    args = parser.parse_args()
    receipt, groups = load(args.run)
    out = dict(run=args.run, source_commit=receipt['identity']['source_commit'], groups={}, repeatability={},
               worker_parity={}, cross_host={}, decisions={})
    for key, episodes in sorted(groups.items()):
        name = '%s/%s/w%d' % key
        failed = sum(e is None for e in episodes)
        eps = [e for e in episodes if e]
        pairs = [dict(a=i, b=j, **compare(eps[i], eps[j])) for i, j in itertools.combinations(range(len(eps)), 2)]
        vs0 = [compare(eps[0], e) for e in eps[1:]]
        out['groups'][name] = dict(failed=failed, cost=cost(episodes))
        out['repeatability'][name] = dict(all_equal_to_repeat0=all(c['equal'] for c in vs0) and failed == 0,
                                          differing_pairs=sum(not p['equal'] for p in pairs), pairs=len(pairs),
                                          first_divergence_kinds=sorted({p['kind'] for p in pairs if not p['equal']}),
                                          first_divergence_steps=sorted(p['step'] for p in pairs if not p['equal'] and p['step'] is not None),
                                          detail=[p for p in pairs if not p['equal']][:10])
    hosts = sorted({k[0] for k in groups})
    workers = sorted({k[2] for k in groups})
    arms = sorted({k[1] for k in groups})
    fenced = [arm for arm in arms if arm.startswith('lockstep')]
    for host in hosts:
        for arm in fenced:
            a, b = groups.get((host, arm, workers[0])), groups.get((host, arm, workers[-1]))
            if a and b and a[0] and b[0] and len(workers) > 1:
                out['worker_parity']['%s/%s' % (host, arm)] = compare(a[0], b[0])
    if len(hosts) > 1:
        for arm in arms:
            for w in workers:
                a, b = groups.get((hosts[0], arm, w)), groups.get((hosts[1], arm, w))
                if a and b and a[0] and b[0]:
                    out['cross_host']['%s/w%d' % (arm, w)] = compare(a[0], b[0])
    rep = out['repeatability']
    out['decisions']['a_lockstep_repeatable'] = {'%s/%s' % (h, arm): all(rep['%s/%s/w%d' % (h, arm, w)]['all_equal_to_repeat0']
                                                        and out['groups']['%s/%s/w%d' % (h, arm, w)]['cost']['worker_timeouts'] == 0
                                                        for w in workers) for h in hosts for arm in fenced}
    out['decisions']['a_worker_parity'] = {k: v['equal'] for k, v in out['worker_parity'].items()}
    out['decisions']['a_async_control_differing_pairs'] = {k: '%d/%d' % (v['differing_pairs'], v['pairs'])
                                                          for k, v in rep.items() if '/async/' in k}
    out['decisions']['b_cross_host_lockstep_match'] = {k: v['equal'] for k, v in out['cross_host'].items() if k.startswith('lockstep')}
    out['decisions']['b_cross_host_first_divergence'] = {k: [v.get('step'), v.get('kind'), v.get('fields')] for k, v in out['cross_host'].items() if not v['equal']}
    path = ROOT / 'build/coupling-lockstep' / args.run / 'reduction.json'
    path.write_text(json.dumps(out, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(out['decisions'], indent=2))
    for name, group in out['groups'].items():
        c = group['cost']
        print(name, 'failed=%d' % group['failed'], 'wall=%.2fs' % c['wall_seconds_median'],
              'steps/s=%.1f' % c['rapier_steps_per_second_median'], 'held=%.3f' % c['held_frame_fraction_median'],
              'ages=%s' % c['result_age_histogram'][:5], 'holds=%d' % c['worker_holds'],
              'hold_mean_us=%.0f' % c['worker_hold_usec_mean_median'], 'hold_max_us=%d' % c['worker_hold_usec_max'],
              'timeouts=%d' % c['worker_timeouts'], 'overruns=%d' % c['worker_overruns'],
              'differing=%d/%d' % (rep[name]['differing_pairs'], rep[name]['pairs']), rep[name]['first_divergence_kinds'])


if __name__ == '__main__':
    main()
