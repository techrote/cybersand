"""Validate and reduce the three immutable INV154 worker-trace trials."""
import argparse
import copy
import json
from pathlib import Path
import statistics

EXPECTED = {
    '02': (57, '24c6cfa365d020b8f101502d3a687a7d04b4723c98e86f7b69d425e270c645fd'),
    '04': (56, 'e6d2de79d1664f2957329a41ec9be94f619130febb46856eb809bc64160f60a2'),
    '06': (56, '1f6c4ab77909e4e7d6346da8ac6476a6b75ee8baf3875d8c76421553ec24fd8a'),
}


def require(value, message):
    if not value:
        raise ValueError(message)


def verify(census, state, stacks, occupancy, samples, trial):
    count, digest = EXPECTED[trial]
    require(census['etl_sha256'] == digest, 'wrong retained ETL')
    require(census['raw_sha256'] == occupancy['raw_sha256'], 'raw timing identity mismatch')
    for record in (census, state, stacks, occupancy, samples):
        require(record.get('events_lost') == 0, 'lost ETW events')
        require(not record.get('trace_truncated', False), 'truncated trace')
    require(not state['stack_rows_truncated'], 'truncated worker stacks')
    require(samples.get('rows_truncated') is False, 'missing or truncated competitor sample rows')
    require(samples.get('eligible_samples_in_windows') == samples.get('retained_rows') == len(samples['rows']), 'incomplete eligible sample capture')
    require(len(state['long_events']) == count, 'missing long events')
    ready_rows = {r['qpc']: r for r in stacks['rows'] if r['kind'] == 'ready_target'}
    caller_rows = {r['qpc']: r for r in stacks['rows'] if r['kind'] == 'switch_out' and r['tid'] in census['caller_tids']}
    critical = set()
    ready_fractions, final_spans = [], []
    phases = {'condition_variable': 0, 'mutex_reacquisition': 0}
    for event in state['long_events']:
        matched = [s for s in event['verified_caller_completion_signals'] if s['is_longest_caller_wait']]
        require(len(matched) == 1, 'missing unique dominant-wait completion')
        signal = matched[0]
        worker = signal['worker_tid']
        require(worker in state['worker_tids'], 'completion worker not identified')
        critical.add(worker)
        states = signal['worker_states_during_caller_wait_usec']
        require(set(states) <= {'ready', 'scheduled'}, 'critical path waiting or unknown')
        total = sum(states.values())
        require(abs(total - signal['preceding_caller_wait_usec']) < .1, 'critical-path coverage gap')
        ready_fractions.append(states.get('ready', 0) / total)
        final_spans.append(signal['last_schedule_to_signal_usec'])
        row = ready_rows[signal['signal_qpc']]
        require(row['tid'] == event['window']['tid'] and row['flags'] == 0, 'wrong wake target/flags')
        require(row['header_tid'] == worker == row['cpu_current_tid'], 'wake emitter mismatch')
        names = [f['function'] or '' for f in row['frames']]
        require(any('RtlpWakeByAddress' in f for f in names), 'missing OS wake frame')
        require(any('rayon_core::job::' in f and 'LockLatch' in f and 'physics_world::' in f for f in names), 'missing exact Rapier completion job')
        blocking = caller_rows.get(signal['preceding_caller_wait_start_qpc'])
        require(blocking is not None, 'missing caller blocking stack')
        functions = [f['function'] or '' for f in blocking['frames']]
        phase = 'mutex_reacquisition' if any('mutex::futex::Mutex::lock_contended' in f for f in functions) else 'condition_variable'
        phases[phase] += 1
    windows = occupancy['windows']
    expected_cpu = 4 * sum((w['end'] - w['start']) * 1e6 / w['freq'] for w in windows)
    require(abs(expected_cpu - occupancy['total_cpu_residency_usec']) < .1, 'logical CPU coverage gap')
    warp = {r['tid'] for r in samples['rows'] if r['pid'] == census['process_id'] and any(f['module'].lower().startswith('d3d10warp') for f in r['frames'])}
    require(warp, 'missing WARP stack evidence')
    slices = occupancy['slices']
    associated = sum(s['usec'] for s in slices if s['pid'] == census['process_id'] and s['tid'] in warp)
    fractions = [sum(s['usec'] for s in slices if s['window'] == w['index'] and s['tid'] in warp and s['pid'] == census['process_id']) / (4 * (w['end'] - w['start']) * 1e6 / w['freq']) for w in windows]
    return {'trial': trial, 'long_events': count, 'critical_workers': sorted(critical),
            'minimum_critical_ready_fraction': min(ready_fractions),
            'median_critical_ready_fraction': statistics.median(ready_fractions),
            'last_schedule_to_dominant_wake_usec_range': [min(final_spans), max(final_spans)],
            'dominant_caller_wait_phases': phases,
            'logical_cpu_residency_usec': expected_cpu, 'warp_associated_tid_residency_usec': associated,
            'warp_associated_tid_residency_fraction': associated / expected_cpu,
            'minimum_event_warp_associated_tid_fraction': min(fractions)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('analysis', type=Path)
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    summaries = []
    for trial in EXPECTED:
        directory = args.analysis / ('trial-' + trial + '-enabled')
        paths = ['worker-census.json', 'worker-state.json', 'worker-stacks.json',
                 'competition/cpu-occupancy.json', 'competition/competitor-samples.json']
        records = [json.loads((directory / name).read_text(encoding='utf-8')) for name in paths]
        summaries.append(verify(*records, trial))
        if args.self_test and trial == '02':
            mutations = [
                ('missing completion', 1, lambda d: d['long_events'][0].__setitem__('verified_caller_completion_signals', [])),
                ('unknown critical state', 1, lambda d: d['long_events'][0]['verified_caller_completion_signals'][0]['worker_states_during_caller_wait_usec'].__setitem__('unknown', 1)),
                ('lost events', 2, lambda d: d.__setitem__('events_lost', 1)),
                ('CPU coverage gap', 3, lambda d: d.__setitem__('total_cpu_residency_usec', 0)),
                ('sample row cap', 4, lambda d: d.__setitem__('rows_truncated', True)),
            ]
            for label, index, mutate in mutations:
                changed = list(records)
                changed[index] = copy.deepcopy(records[index])
                mutate(changed[index])
                try:
                    verify(*changed, trial)
                except ValueError:
                    print('PASS reject ' + label)
                else:
                    raise AssertionError('accepted invalid analysis: ' + label)
    result = {'schema': 'inv154-worker-verification-v1', 'trials': summaries,
              'scope': 'same-process WARP-associated residency and critical Rayon ready delay; no hardware-GPU or individual shader claim'}
    (args.analysis / 'worker-analysis-summary.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
