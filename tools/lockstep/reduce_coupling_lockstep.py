#!/usr/bin/env python3
"""Reduce COUPLING-LOCKSTEP-001 episodes into the registered (a)-(c) decisions.

Decisions are computed only after the complete registered matrix and every
artifact validate independently: the receipt's own ``clean`` flag is never
trusted. A run with any validation error writes its errors and no decisions,
and exits 2. Output goes to ``reduction-v2.json``; the original
``reduction.json`` files are retained unchanged as historical evidence.
"""
import argparse
import hashlib
import itertools
import json
import re
import statistics
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRATION = ROOT / 'native/tests/fixtures/coupling_lockstep_001.json'
OUTPUT_NAME = 'reduction-v2.json'
# Every recorded per-step field. ``serial`` (applied snapshot serial) is
# registered under recorded_per_rapier_step and was missing from v1.
STEP_FIELDS = ('tick', 'serial', 'publication', 'states', 'results', 'pre', 'post', 'character')
RACE_FIELDS = ('tick', 'serial', 'publication')
HEX = re.compile(r'^[0-9a-f]+$')
PLATFORMS = {'windows': 'Windows', 'linux': 'Linux'}
# Runs whose final diagnostic hashes are a registered apparatus defect
# (amendment_001.apparatus_defect): both fields must be empty, and the tail
# comparison reports them as not compared rather than equal.
FINAL_HASH_DEFECT_RUNS = ('matrix-001', 'smoke-001')
# amendment_002: the production packing arm must reproduce a validated earlier arm.
CROSS_RUN_REFERENCES = {'packed-001': ('horizon-001', 'lockstep-f64rot', 'lockstep-packed')}
IDENTITY_FILES = {'registration_sha256': 'native/tests/fixtures/coupling_lockstep_001.json',
                  'runner_sha256': 'tools/lockstep/run_coupling_lockstep.py',
                  'fixture_sha256': 'godot/tests/test_coupling_lockstep.gd',
                  'worker_sha256': 'godot/scripts/simulation_worker.gd'}
# Recorded from amendment_002 on (packing moved into the bridge); checked when present.
OPTIONAL_IDENTITY_FILES = {'bridge_sha256': 'godot/scripts/rapier_physics_bridge.gd'}


def registered_matrix(run, registration):
    """Expected matrix for a registered run name; None if unregistered."""
    host = lambda names: [n.split()[0] for n in names]
    if run == 'matrix-001':
        m = registration['matrix']
        return dict(hosts=host(m['hosts']), workers=m['workers'], arms=m['arms'], repeats=m['repeats'],
                    ticks=registration['fixture']['ticks'], delay_usec=0, decisional=True)
    if run == 'smoke-001':
        # Registered as an excluded mechanics check; validated, never decisional.
        return dict(hosts=['windows', 'linux'], workers=[1], arms=['async', 'lockstep'], repeats=2,
                    ticks=registration['fixture']['ticks'], delay_usec=0, decisional=False)
    amendment = registration['amendment_001']['matrix']
    names = {'f64rot-001': 'f64rot', 'horizon-001': 'long_horizon'}
    if run in names:
        m = amendment[names[run]]
        return dict(hosts=m['hosts'], workers=m['workers'], arms=m['arms'], repeats=m['repeats'],
                    ticks=m['ticks'], delay_usec=0, decisional=True)
    if run == 'packed-001' and 'amendment_002' in registration:
        m = registration['amendment_002']['matrix']['packed']
        return dict(hosts=m['hosts'], workers=m['workers'], arms=m['arms'], repeats=m['repeats'],
                    ticks=m['ticks'], delay_usec=0, decisional=True)
    match = re.fullmatch(r'load-(\d+)', run)
    if match and int(match.group(1)) in amendment['load']['delay_usec']:
        m = amendment['load']
        return dict(hosts=m['hosts'], workers=m['workers'], arms=m['arms'], repeats=m['repeats'],
                    ticks=m['ticks'], delay_usec=int(match.group(1)), decisional=True)
    return None


def sha_bytes(data):
    return hashlib.sha256(data).hexdigest()


def git_show(commit, path):
    try:
        return subprocess.check_output(['git', '-C', str(ROOT), 'show', '%s:%s' % (commit, path)],
                                       stderr=subprocess.DEVNULL)
    except (subprocess.CalledProcessError, OSError):
        return None


def validate_identity(receipt, show=git_show, notes=None):
    """Receipt source hashes must equal the files at the recorded source commit."""
    errors = []
    notes = [] if notes is None else notes
    identity = receipt.get('identity') or {}
    commit = identity.get('source_commit')
    if not isinstance(commit, str) or not re.fullmatch(r'[0-9a-f]{40}', commit):
        return ['receipt: source_commit missing or malformed']
    if receipt.get('post_source_equality') is not True:
        errors.append('receipt: post_source_equality is not true')
    files = dict(IDENTITY_FILES, **{k: p for k, p in OPTIONAL_IDENTITY_FILES.items() if k in identity})
    if CROSS_RUN_REFERENCES.get(receipt.get('matrix', {}).get('run')) and 'bridge_sha256' not in identity:
        errors.append('receipt: bridge_sha256 missing for a packed run')
    for key, path in files.items():
        data = show(commit, path)
        if data is None:
            errors.append('receipt: %s not readable at %s' % (path, commit[:12]))
        elif identity.get(key) == sha_bytes(data):
            continue
        elif b'\r' not in data and identity.get(key) == sha_bytes(data.replace(b'\n', b'\r\n')):
            # The runner hashed working-tree bytes; a Windows CRLF checkout of
            # the committed LF blob is the same committed content.
            notes.append('%s matches the CRLF checkout of %s at %s' % (key, path, commit[:12]))
        else:
            errors.append('receipt: %s does not match %s at %s' % (key, path, commit[:12]))
    return errors


def validate_episode(row, data, log_bytes, result_bytes, expected, run):
    """Independent validation of one receipt row and its artifacts."""
    name = '%s/%s/w%s/r%s' % (row.get('host'), row.get('arm'), row.get('workers'), row.get('repeat'))
    errors = []

    def bad(message):
        errors.append('%s: %s' % (name, message))

    if row.get('exit') != 0:
        bad('exit %r' % row.get('exit'))
    if row.get('ticks') != expected['ticks']:
        bad('receipt ticks %r != registered %d' % (row.get('ticks'), expected['ticks']))
    if row.get('delay_usec', 0) != expected['delay_usec']:
        bad('receipt delay %r != registered %d' % (row.get('delay_usec'), expected['delay_usec']))
    if log_bytes is None:
        bad('log missing')
    else:
        if sha_bytes(log_bytes) != row.get('log_sha256'):
            bad('log sha256 mismatch')
        text = log_bytes.decode('utf-8', errors='replace')
        if 'SCRIPT ERROR' in text or 'COUPLING_LOCKSTEP {' not in text:
            bad('log lacks a clean COUPLING_LOCKSTEP report')
    if result_bytes is None:
        bad('result missing')
        return errors
    if sha_bytes(result_bytes) != row.get('result_sha256'):
        bad('result sha256 mismatch')
    if data is None:
        bad('result is not valid JSON')
        return errors
    ticks = expected['ticks']
    fenced = row.get('arm', '').startswith('lockstep')
    checks = [
        (data.get('registration') == 'COUPLING-LOCKSTEP-001', 'registration'),
        (data.get('ok') is True, 'ok flag'),
        (data.get('mode') == row.get('arm'), 'mode %r' % data.get('mode')),
        (data.get('workers') == row.get('workers'), 'workers'),
        (data.get('ticks') == ticks, 'ticks'),
        (data.get('completed_ticks') == ticks, 'completed_ticks %r' % data.get('completed_ticks')),
        (data.get('native_delay_usec', 0) == expected['delay_usec'], 'native_delay_usec'),
        (data.get('platform') == PLATFORMS.get(row.get('host')), 'platform %r' % data.get('platform')),
        (str(data.get('engine', '')).startswith('4.7-stable'), 'engine %r' % data.get('engine')),
    ]
    for ok, label in checks:
        if not ok:
            bad('result field %s' % label)
    wall = data.get('wall_usec')
    seconds = row.get('seconds')
    if not isinstance(wall, int) or wall <= 0:
        bad('wall_usec %r' % wall)
    elif not isinstance(seconds, (int, float)) or not wall / 1e6 < seconds:
        bad('measured wall %.3fs is not inside receipt process duration %r' % (wall / 1e6, seconds))
    frames, steps_n, held = data.get('physics_frames'), data.get('rapier_steps'), data.get('held_frames')
    if not all(isinstance(v, int) and v >= 0 for v in (frames, steps_n, held)) or held > frames or steps_n > frames:
        bad('frame counts physics=%r steps=%r held=%r' % (frames, steps_n, held))
    ages = data.get('age_histogram')
    if not isinstance(ages, list) or not ages or not all(isinstance(v, int) and v >= 0 for v in ages):
        bad('age_histogram')
    lock = data.get('lockstep')
    keys = ('enabled', 'ticks', 'holds', 'hold_usec_total', 'hold_usec_max', 'timeouts')
    if not isinstance(lock, dict) or any(k not in lock for k in keys):
        bad('lockstep metrics incomplete')
    elif lock['enabled'] is not fenced or (fenced and lock['ticks'] != ticks):
        bad('lockstep metrics enabled=%r ticks=%r' % (lock['enabled'], lock['ticks']))
    for key in ('initial_bits', 'final_bits'):
        if not isinstance(data.get(key), str) or not data[key] or not HEX.match(data[key]):
            bad('%s empty or not hex' % key)
    finals = [data.get('state_hash'), data.get('final_physical_hash')]
    if run in FINAL_HASH_DEFECT_RUNS:
        if any(finals):
            bad('final hashes present in a run registered as the empty-final-hash defect')
    elif not all(isinstance(v, str) and v for v in finals):
        bad('final state_hash/final_physical_hash empty')
    hashes = data.get('tick_hashes')
    if not isinstance(hashes, list) or len(hashes) != ticks + 1:
        bad('tick_hashes length %r != %d' % (len(hashes) if isinstance(hashes, list) else None, ticks + 1))
    else:
        # Tick 0 precedes the first completed tick and is never recorded.
        missing = [t for t in range(1, ticks + 1) if not isinstance(hashes[t], str) or not hashes[t]]
        if hashes[0] != '' or missing:
            bad('tick hash coverage: %d missing (first %s)' % (len(missing), missing[:5]))
    steps = data.get('steps')
    if not isinstance(steps, list) or not steps or len(steps) != steps_n:
        bad('steps length %r != rapier_steps %r' % (len(steps) if isinstance(steps, list) else None, steps_n))
        return errors
    previous = None
    for index, step in enumerate(steps):
        if not isinstance(step, dict) or any(f not in step for f in STEP_FIELDS):
            bad('step %d incomplete' % index)
            break
        # Async main may apply the pre-tick snapshot (tick 0) and re-apply an
        # unchanged newest snapshot; the fence requires strict advance.
        if not isinstance(step['tick'], int) or not (1 if fenced else 0) <= step['tick'] <= ticks:
            bad('step %d tick %r out of range' % (index, step['tick']))
            break
        if previous and (step['tick'] < previous['tick'] or step['serial'] < previous['serial']
                         or (fenced and step['serial'] == previous['serial'])):
            bad('step %d tick/serial not monotonic' % index)
            break
        if fenced and not (step['tick'] == index + 1 and step['publication'] == index + 1):
            bad('step %d violates the fence (tick %r publication %r)' % (index, step['tick'], step['publication']))
            break
        previous = step
    return errors


def load(run, show=git_show, base=None):
    """Load and validate one run; returns (receipt, groups, expected, errors, notes)."""
    base = base or ROOT
    registration = json.loads(REGISTRATION.read_text(encoding='utf-8'))
    expected = registered_matrix(run, registration)
    folder = base / 'build/coupling-lockstep' / run
    errors = []
    if expected is None:
        return None, {}, None, ['run %s is not registered' % run], []
    receipt_path = folder / 'receipt.json'
    if not receipt_path.is_file():
        return None, {}, expected, ['receipt missing'], []
    receipt = json.loads(receipt_path.read_text(encoding='utf-8'))
    notes = []
    errors += validate_identity(receipt, show, notes)
    seen = {}
    groups = {}
    for row in receipt.get('episodes', []):
        key = (row.get('host'), row.get('arm'), row.get('workers'), row.get('repeat'))
        if key[0] not in expected['hosts'] or key[1] not in expected['arms'] or key[2] not in expected['workers'] \
                or not isinstance(key[3], int) or not 0 <= key[3] < expected['repeats']:
            errors.append('unregistered episode %s' % (key,))
            continue
        if key in seen:
            errors.append('duplicate episode %s' % (key,))
            continue
        result_rel = row.get('result')
        result_path = base / result_rel.replace('\\', '/') if result_rel else None
        log_path = folder / key[0] / ('%s-w%d-r%d' % (key[1], key[2], key[3])) / 'godot.log'
        log_bytes = log_path.read_bytes() if log_path.is_file() else None
        result_bytes = result_path.read_bytes() if result_path and result_path.is_file() else None
        try:
            data = json.loads(result_bytes) if result_bytes is not None else None
        except ValueError:
            data = None
        episode_errors = validate_episode(row, data, log_bytes, result_bytes, expected, run)
        if bool(row.get('clean')) != (not episode_errors):
            episode_errors.append('%s: receipt clean=%r disagrees with independent validation'
                                  % ('/'.join(map(str, key)), row.get('clean')))
        errors += episode_errors
        seen[key] = data if not episode_errors else None
    for key in itertools.product(expected['hosts'], expected['arms'], expected['workers'], range(expected['repeats'])):
        if key not in seen:
            errors.append('missing episode %s' % (key,))
    for key, data in sorted(seen.items(), key=lambda kv: kv[0][3]):
        groups.setdefault(key[:3], []).append(data)
    return receipt, groups, expected, errors, notes


def compare(a, b, final_hashes_recorded=True):
    """First difference between two episodes, classified by the registered rule."""
    for k, (x, y) in enumerate(zip(a['steps'], b['steps'])):
        differing = [f for f in STEP_FIELDS if x[f] != y[f]]
        if not differing:
            continue
        if any(f in differing for f in RACE_FIELDS):
            kind = 'RACE'
        elif 'pre' in differing or 'states' in differing:
            kind = 'OTHER'
        elif 'results' in differing:
            kind = 'NATIVE'
        elif 'post' in differing:
            kind = 'RAPIER'
        else:
            kind = 'OTHER'
        tick = x['tick']
        return dict(equal=False, step=k, tick=tick, fields=differing, kind=kind,
                    tick_hash_equal_at_step=a['tick_hashes'][tick] == b['tick_hashes'][tick],
                    first_tick_hash_difference=first_hash(a, b))
    tails = dict(steps=len(a['steps']) == len(b['steps']), initial_bits=a['initial_bits'] == b['initial_bits'],
                 final_bits=a['final_bits'] == b['final_bits'], tick_hashes=a['tick_hashes'] == b['tick_hashes'])
    if final_hashes_recorded:
        tails.update(state_hash=a['state_hash'] == b['state_hash'],
                     final_physical_hash=a['final_physical_hash'] == b['final_physical_hash'])
    if all(tails.values()):
        return dict(equal=True, final_hashes_compared=final_hashes_recorded)
    return dict(equal=False, step=None, kind='OTHER', tails=tails, first_tick_hash_difference=first_hash(a, b))


def first_hash(a, b):
    for tick, (x, y) in enumerate(zip(a['tick_hashes'], b['tick_hashes'])):
        if x != y:
            return tick
    return None


def cost(eps):
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


def reduce(run, show=git_show, base=None):
    receipt, groups, expected, errors, notes = load(run, show, base)
    out = dict(run=run, reducer='v2', source_commit=(receipt or {}).get('identity', {}).get('source_commit'),
               expected_matrix=expected, validation=dict(valid=not errors, errors=errors, notes=notes))
    reference = CROSS_RUN_REFERENCES.get(run)
    if reference and not errors:
        # The reference run is validated exactly as if it were reduced on its own.
        _, ref_groups, _, ref_errors, _ = load(reference[0], show, base)
        errors.extend('reference %s: %s' % (reference[0], e) for e in ref_errors)
        out['validation']['valid'] = not errors
    if errors:
        out['decisions'] = None
        return out
    recorded = run not in FINAL_HASH_DEFECT_RUNS
    out.update(groups={}, repeatability={}, worker_parity={}, cross_host={}, decisions={})
    for key, eps in sorted(groups.items()):
        name = '%s/%s/w%d' % key
        pairs = [dict(a=i, b=j, **compare(eps[i], eps[j], recorded)) for i, j in itertools.combinations(range(len(eps)), 2)]
        vs0 = [compare(eps[0], e, recorded) for e in eps[1:]]
        out['groups'][name] = dict(episodes=len(eps), cost=cost(eps))
        out['repeatability'][name] = dict(all_equal_to_repeat0=len(eps) >= 2 and all(c['equal'] for c in vs0),
                                          differing_pairs=sum(not p['equal'] for p in pairs), pairs=len(pairs),
                                          final_hashes_compared=recorded,
                                          first_divergence_kinds=sorted({p['kind'] for p in pairs if not p['equal']}),
                                          first_divergence_steps=sorted(p['step'] for p in pairs if not p['equal'] and p['step'] is not None),
                                          detail=[p for p in pairs if not p['equal']][:10])
    hosts, workers, arms = expected['hosts'], sorted(expected['workers']), expected['arms']
    fenced = [arm for arm in arms if arm.startswith('lockstep')]
    if len(workers) > 1:
        for host in hosts:
            for arm in fenced:
                out['worker_parity']['%s/%s' % (host, arm)] = compare(groups[(host, arm, workers[0])][0],
                                                                      groups[(host, arm, workers[-1])][0], recorded)
    if len(hosts) > 1:
        for arm in arms:
            for w in workers:
                out['cross_host']['%s/w%d' % (arm, w)] = compare(groups[(hosts[0], arm, w)][0], groups[(hosts[1], arm, w)][0], recorded)
    if not expected['decisional']:
        out['decisions'] = 'excluded (registered smoke)'
        return out
    rep = out['repeatability']
    d = out['decisions']
    d['a_lockstep_repeatable'] = {'%s/%s' % (h, arm): all(rep['%s/%s/w%d' % (h, arm, w)]['all_equal_to_repeat0']
                                                          and out['groups']['%s/%s/w%d' % (h, arm, w)]['cost']['worker_timeouts'] == 0
                                                          for w in workers) for h in hosts for arm in fenced}
    d['a_worker_parity'] = {k: v['equal'] for k, v in out['worker_parity'].items()}
    d['a_async_control_differing_pairs'] = {k: '%d/%d' % (v['differing_pairs'], v['pairs']) for k, v in rep.items() if '/async/' in k}
    d['b_cross_host_lockstep_match'] = {k: v['equal'] for k, v in out['cross_host'].items() if k.startswith('lockstep')}
    d['b_cross_host_first_divergence'] = {k: [v.get('step'), v.get('kind'), v.get('fields')]
                                          for k, v in out['cross_host'].items() if not v['equal']}
    d['final_hashes_compared'] = recorded
    if reference:
        ref_run, ref_arm, arm = reference
        out['cross_run'] = {'%s/w%d' % (h, w): compare(groups[(h, arm, w)][0], ref_groups[(h, ref_arm, w)][0], recorded)
                            for h in hosts for w in workers}
        d['packed_equals_%s' % ref_arm.replace('lockstep-', '')] = {k: v['equal'] for k, v in out['cross_run'].items()}
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', required=True)
    args = parser.parse_args()
    out = reduce(args.run)
    path = ROOT / 'build/coupling-lockstep' / args.run / OUTPUT_NAME
    if path.parent.is_dir():
        path.write_text(json.dumps(out, indent=2) + '\n', encoding='utf-8')
    if not out['validation']['valid']:
        print('INVALID %s: %d errors' % (args.run, len(out['validation']['errors'])))
        for error in out['validation']['errors'][:40]:
            print('  ' + error)
        return 2
    print(json.dumps(out['decisions'], indent=2))
    rep = out['repeatability']
    for name, group in out['groups'].items():
        c = group['cost']
        print(name, 'n=%d' % group['episodes'], 'wall=%.2fs' % c['wall_seconds_median'],
              'steps/s=%.1f' % c['rapier_steps_per_second_median'], 'held=%.3f' % c['held_frame_fraction_median'],
              'ages=%s' % c['result_age_histogram'][:5], 'holds=%d' % c['worker_holds'],
              'hold_mean_us=%.0f' % c['worker_hold_usec_mean_median'], 'hold_max_us=%d' % c['worker_hold_usec_max'],
              'timeouts=%d' % c['worker_timeouts'], 'overruns=%d' % c['worker_overruns'],
              'differing=%d/%d' % (rep[name]['differing_pairs'], rep[name]['pairs']), rep[name]['first_divergence_kinds'])
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
