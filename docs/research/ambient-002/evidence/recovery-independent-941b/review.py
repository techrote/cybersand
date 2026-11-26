#!/usr/bin/env python3
"""Reproduce the independent nine-case review from original retained reports.

This post-run reader executes no actors. Pass the extracted probe directory,
the source checkout containing the original two readers, and an output path.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def withdrawals(case, row):
    trace, runs, start = row['trace'], [], None
    for index, sample in enumerate(trace + [{'selection': 'end'}]):
        if sample['selection'] == 'withdraw_obstruction':
            if start is None:
                start = index
            continue
        if start is None:
            continue
        first = trace[start]
        final = trace[index]['position'] if index < len(trace) else row['last']
        elapsed = trace[index]['seconds'] if index < len(trace) else case['seconds']
        runs.append({'begin_seconds': first['seconds'], 'end_seconds': elapsed,
                     'net_x_cells': final[0]-first['position'][0],
                     'retreat_and_quiet_seconds': (index-start)*.1})
        start = None
    return runs


def headings(row, begin=0, end=30):
    trace = [s for s in row['trace'] if begin-1e-8 <= s['seconds'] <= end+1e-8]
    signs = []
    for sample in trace:
        x = sample['intent_direction'][0]
        signs.append(0 if not sample['has_procedural_intent'] or sample['intent_pace'] <= .05
                     else 1 if x > .05 else -1 if x < -.05 else 0)
    xs = [s['position'][0] for s in trace]
    return {'samples': len(trace), 'begin_seconds': trace[0]['seconds'],
            'end_seconds': trace[-1]['seconds'],
            'horizontal_heading_reversals': sum(a*b == -1 for a, b in zip(signs, signs[1:])),
            'x_range_cells': max(xs)-min(xs), 'net_x_cells': xs[-1]-xs[0]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--probe', type=Path, required=True)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    sys.path.insert(0, str(args.source/'tools/ambient'))
    import review_episodes as independent
    import analyze_episodes as reducer
    files = {name: args.probe/name for name in ('episodes.json', 'comparison.json', 'baseline-original.json')}
    candidate, comparison, baseline = [json.loads(files[name].read_bytes()) for name in files]
    reducer.validate(candidate)
    assert candidate['source_identity']['source_revision'] == '941b79154c890098350725f274b85f26b44f77b0'
    assert baseline['source_identity']['source_revision'] == '83a3db6ffb207761df999abedac77eb1401604a8'
    assert len(candidate['campaigns']) == 9 and comparison['qualifies_full_programme'] is False
    old = {c['id']: c for c in baseline['campaigns']}
    paired = {p['case_id']: p for p in comparison['pairs']}
    reviewed, numeric_checks, table_checks, heading_checks = [], 0, 0, 0
    for case in candidate['campaigns']:
        before = old[case['id']]
        for key in ('initial_materials', 'initial_pose_sha256', 'geometry', 'seed', 'seconds', 'actor_count'):
            assert before[key] == case[key], (case['id'], key)
        previous, current = before['episodes'][0], case['episodes'][0]
        for key in ('model', 'controller', 'profile', 'start', 'actor_instance'):
            assert previous[key] == current[key], (case['id'], key)
        item = {'case_id': case['id'], 'group': case['group'], 'layout': case['layout'], 'seed': case['seed']}
        for phase, campaign, row in [('before', before, previous), ('after', case, current)]:
            computed = independent.independent_metrics(campaign, row)
            reduced = reducer.episode_metrics(campaign, row)
            for key, value in computed.items():
                independent.close(reduced[key], value, case['id']+phase+key)
                numeric_checks += 1
            for key in ('x_range_cells', 'net_displacement_cells', 'stable_territory_cells', 'stalled_active_fraction'):
                independent.close(paired[case['id']][phase][key], computed[key], case['id']+phase+key)
                table_checks += 1
            for key, interval in [('directions_', (0, campaign['seconds'])), ('original_negative_window_', (6.5, 8.5))]:
                expected = headings(row, *interval)
                for field, value in expected.items():
                    independent.close(paired[case['id']][key+phase][field], value, case['id']+phase+field)
                    heading_checks += 1
            item[phase] = {'metrics': computed, 'active_headings': headings(row),
                           'original_negative_window': headings(row, 6.5, 8.5),
                           'memory_failure_events': row['final_memory'].get('failure_events'),
                           'retained_obstructions': row['final_memory'].get('obstructions', []),
                           'withdrawal_selected_seconds': sum(s['selection'] == 'withdraw_obstruction' for s in row['trace'])*.1,
                           'withdrawal_motion': withdrawals(campaign, row),
                           'events': campaign['events']}
        reviewed.append(item)
    receipt = {'scope': 'Independent review of nine matched existing cases, not a complete 194-case candidate programme. Zero new episodes are executed by this reader.',
               'candidate_source': candidate['source_identity']['source_revision'],
               'baseline_source': baseline['source_identity']['source_revision'],
               'original_sha256': {name: sha(path) for name, path in files.items()},
               'reviewer_sha256': sha(__file__), 'movement_reader_sha256': sha(independent.__file__),
               'reducer_sha256': sha(reducer.__file__), 'independent_movement_comparisons': numeric_checks,
               'comparison_table_checks': table_checks, 'independent_heading_checks': heading_checks,
               'matched_world_pairs': len(reviewed), 'pairs': reviewed,
               'limits': ['No elapsed performance inference under concurrent local work.',
                         'Blocked-route memory records predate the 15-second new-wall intervention; the result does not prove learning that new wall.',
                         'Heading reversals are changes of active final steering, not goal-instance transitions.',
                         'The full baseline programme and subsequent complete candidate qualification remain separately identified.']}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2, sort_keys=True)+'\n')
    print(json.dumps({k: receipt[k] for k in ('candidate_source', 'matched_world_pairs', 'independent_movement_comparisons', 'comparison_table_checks', 'independent_heading_checks')}))


if __name__ == '__main__':
    main()
