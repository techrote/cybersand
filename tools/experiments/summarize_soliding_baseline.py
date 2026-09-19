"""Reduce retained issue #12 Current-sleep output without modifying raw evidence.

All timing statistics retain outliers and failed attempts. Derived scheduler work
ratios describe Current behavior; they do not admit a soliding representation.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def quantile(values, proportion):
    ordered = sorted(values)
    return ordered[math.ceil(proportion * len(ordered)) - 1] if ordered else None


def timing(rows):
    values = [row['tick_ms'] for row in rows]
    return {'count': len(values), 'total_ms': sum(values),
            'p50_ms': quantile(values, .50), 'p95_ms': quantile(values, .95),
            'p99_ms': quantile(values, .99), 'max_ms': max(values) if values else None}


def edit_windows(samples):
    starts = [index for index, sample in enumerate(samples) if sample['edit_cells']]
    windows = []
    for position, start in enumerate(starts):
        stop = starts[position + 1] if position + 1 < len(starts) else len(samples)
        rows = samples[start:stop]
        edits = samples[start]['edit_cells']
        quiet = next((offset for offset, row in enumerate(rows) if row['active_blocks_after'] == 0), None)
        windows.append({'edit_tick': samples[start]['tick'], 'edited_cells': edits,
                        'observed_ticks': len(rows), 'tick_ms': sum(row['tick_ms'] for row in rows),
                        'edit_ms': samples[start]['edit_ms'],
                        'visited_cells': sum(row['visited_cells'] for row in rows),
                        'visited_per_edited_cell': sum(row['visited_cells'] for row in rows) / edits,
                        'scheduled_cores': sum(row['scheduled_cores'] for row in rows),
                        'max_active_blocks': max(row['active_blocks_after'] for row in rows),
                        'ticks_until_no_active_blocks': quiet,
                        'returned_to_sleep_within_window': quiet is not None})
    return windows


def reduce(completed_path):
    completed = json.loads(completed_path.read_text(encoding='utf-8'))
    registration = completed['registration']
    artifact_path = Path(registration['artifact'])
    problems = []
    if digest(artifact_path) != registration['artifact_sha256']:
        problems.append('Artifact manifest changed after registration')
    artifact = json.loads(artifact_path.read_text(encoding='utf-8'))
    if digest(artifact['executable']) != registration['executable_sha256']:
        problems.append('Control executable changed after registration')
    for name, expected in artifact['source_files'].items():
        if digest(Path(artifact['source_root']) / name) != expected:
            problems.append('Frozen source changed: ' + name)
    protocol = registration.get('measurement_protocol', 'soliding-baseline-v1')
    processes = []
    failed = []
    for result in completed['results']:
        output = Path(result['output'])
        execution_path = output.with_name(output.stem + '.execution.json')
        execution = json.loads(execution_path.read_text(encoding='utf-8'))
        errors = []
        if digest(output) != execution['stdout_sha256']:
            errors.append('stdout hash mismatch')
        stderr = output.with_suffix('.stderr')
        if digest(stderr) != execution['stderr_sha256']:
            errors.append('stderr hash mismatch')
        if result['exit'] or execution['exit']:
            errors.append('nonzero exit')
        if result.get('parse_failure'):
            errors.append(result['parse_failure'])
        if not result.get('deterministic_content', True):
            errors.append('content parity failure')
        if not result.get('deterministic_state', True):
            errors.append('state parity failure')
        try:
            value = json.loads(output.read_text(encoding='utf-8'))
            if not value['valid']:
                errors.append('native validation failure')
            if value['schema'] != protocol:
                errors.append('measurement protocol mismatch')
            samples = value['samples']
            if len(samples) != value['measured_ticks']:
                errors.append('sample count mismatch')
            if any(row['epoch_clear'] != (row['tick'] > 1 and (row['tick'] - 1) % 255 == 0) for row in samples):
                errors.append('epoch attribution mismatch')
            ordinary = [row for row in samples if not row['epoch_clear']]
            epochs = [row for row in samples if row['epoch_clear']]
            all_timing, ordinary_timing, epoch_timing = timing(samples), timing(ordinary), timing(epochs)
            area = value['size'] ** 2
            processes.append({'name': result['name'], 'fixture': value['fixture'], 'size': value['size'],
                              'workers': value['workers'], 'offset': value['offset'], 'area': area,
                              'errors': errors, 'all_timing': all_timing, 'ordinary_timing': ordinary_timing,
                              'epoch_timing': epoch_timing,
                              'epoch_share_of_tick_time': epoch_timing['total_ms'] / all_timing['total_ms'] if all_timing['total_ms'] else None,
                              'resident_chunks': value['resident_chunks'],
                              'resident_cell_bytes': value['resident_cell_bytes'],
                              'resident_bytes_per_fixture_cell': value['resident_cell_bytes'] / area,
                              'cell_storage_bytes': value.get('cell_storage_bytes'),
                              'rule_visited_cells': sum(row['visited_cells'] for row in samples),
                              'scheduled_cores': sum(row['scheduled_cores'] for row in samples),
                              'moved_cells': sum(row['moved_cells'] for row in samples),
                              'tick_chunk_allocations': sum(row['chunk_allocations'] for row in samples),
                              'tick_temperature_allocations': sum(row['temperature_field_allocations'] for row in samples),
                              'max_active_blocks': max(row['active_blocks_after'] for row in samples),
                              'final_content_hash': value['final_content_hash'], 'final_state_hash': value['final_state_hash'],
                              'conserved': value['conserved'], 'edit_windows': edit_windows(samples)})
        except (ValueError, KeyError, TypeError) as error:
            errors.append('could not reduce raw result: ' + str(error))
        if errors:
            failed.append({'name': result['name'], 'errors': errors, 'stdout': str(output)})
    groups = {}
    for process in processes:
        key = f"{process['fixture']}/{process['size']}/w{process['workers']}/{process['offset']}"
        groups.setdefault(key, []).append(process)
    aggregate = []
    for key, group in groups.items():
        sample = group[0]
        windows = [window for process in group for window in process['edit_windows']]
        p95s = [process['all_timing']['p95_ms'] for process in group]
        aggregate.append({'key': key, 'fixture': sample['fixture'], 'size': sample['size'], 'workers': sample['workers'],
                          'offset': sample['offset'], 'processes': len(group),
                          'process_p95_ms': p95s, 'median_process_p95_ms': statistics.median(p95s),
                          'minimum_process_p95_ms': min(p95s), 'maximum_process_p95_ms': max(p95s),
                          'median_process_p99_ms': statistics.median(process['all_timing']['p99_ms'] for process in group),
                          'worst_tick_ms': max(process['all_timing']['max_ms'] for process in group),
                          'median_total_tick_ms': statistics.median(process['all_timing']['total_ms'] for process in group),
                          'median_ordinary_p50_ms': statistics.median(process['ordinary_timing']['p50_ms'] for process in group if process['ordinary_timing']['count']) if any(process['ordinary_timing']['count'] for process in group) else None,
                          'median_epoch_p50_ms': statistics.median(process['epoch_timing']['p50_ms'] for process in group if process['epoch_timing']['count']) if any(process['epoch_timing']['count'] for process in group) else None,
                          'median_epoch_share_of_tick_time': statistics.median(process['epoch_share_of_tick_time'] for process in group),
                          'resident_chunks': sample['resident_chunks'], 'resident_cell_bytes': sample['resident_cell_bytes'],
                          'resident_bytes_per_fixture_cell': sample['resident_bytes_per_fixture_cell'],
                          'rule_visited_range': [min(p['rule_visited_cells'] for p in group), max(p['rule_visited_cells'] for p in group)],
                          'scheduled_cores_range': [min(p['scheduled_cores'] for p in group), max(p['scheduled_cores'] for p in group)],
                          'edit_events': len(windows),
                          'median_visited_per_edited_cell': statistics.median(w['visited_per_edited_cell'] for w in windows) if windows else None,
                          'maximum_ticks_until_sleep': max((w['ticks_until_no_active_blocks'] for w in windows if w['ticks_until_no_active_blocks'] is not None), default=None),
                          'windows_without_sleep': sum(not w['returned_to_sleep_within_window'] for w in windows),
                          'all_conserved': all(p['conserved'] for p in group),
                          'all_processes_valid': all(not p['errors'] for p in group)})
    return {'schema': 'soliding-baseline-reduction-v1', 'completed_path': str(completed_path),
            'completed_sha256': digest(completed_path), 'reducer_sha256': digest(__file__),
            'source_ref': registration['source_ref'], 'executable_sha256': registration['executable_sha256'],
            'measurement_protocol': protocol, 'registered_timing_campaign': registration['registered_timing_campaign'],
            'uncontended_note': registration['uncontended_note'],
            'hardware_before': registration['hardware_before'], 'hardware_after': completed['hardware_after'],
            'reported_failure_count': completed['failures'], 'integrity_problems': problems,
            'failed_attempts': failed, 'groups': aggregate, 'processes': processes,
            'interpretation_limits': [
                'Current-only native measurements prove no candidate speedup or stage admission.',
                'All tails/outliers and failed attempts are retained; no significance or noise model is inferred.',
                'Zero rule visits excludes neither resident metadata passes nor epoch clears.',
                'Epoch attribution follows the frozen source tick schedule; deeper CPU attribution needs profiling.',
                'Resident bytes include reserved halo and existing World payload/activity estimate, not process RSS or full allocations.',
                'Edit amplification measures Current scheduler scans, not future discovery/rebuild work.',
                'Sleep latency is tick-index offset from the edit (0 means that edit tick) to first zero active-block count; right-censored windows remain explicit.',
                'Endpoint material census and worker parity do not certify transient conservation, rendering, Rapier, Web or Linux behavior.',
            ]}


def markdown(value):
    lines = ['# Current ordinary-sleep control reduction', '',
             f"Source `{value['source_ref']}`; protocol `{value['measurement_protocol']}`.",
             f"Reported failures: {value['reported_failure_count']}; integrity findings: {len(value['integrity_problems'])}; reduced failed attempts: {len(value['failed_attempts'])}.", '',
             '| Fixture | Area | Workers | Processes | Median process p95 (ms) | Median process p99 (ms) | Worst tick (ms) | Median epoch share | Resident bytes/cell |',
             '|---|---:|---:|---:|---:|---:|---:|---:|---:|']
    for group in value['groups']:
        lines.append(f"| {group['fixture']} {group['offset']} | {group['size']}² | {group['workers']} | {group['processes']} | {group['median_process_p95_ms']:.6f} | {group['median_process_p99_ms']:.6f} | {group['worst_tick_ms']:.6f} | {group['median_epoch_share_of_tick_time']:.1%} | {group['resident_bytes_per_fixture_cell']:.3f} |")
    lines.extend(['', '## Interpretation limits', ''])
    lines.extend('- ' + limit for limit in value['interpretation_limits'])
    if value['failed_attempts'] or value['integrity_problems']:
        lines.extend(['', '## Retained failures', ''])
        lines.extend('- ' + problem for problem in value['integrity_problems'])
        lines.extend('- ' + item['name'] + ': ' + '; '.join(item['errors']) for item in value['failed_attempts'])
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('completed', type=Path)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--markdown', type=Path)
    args = parser.parse_args()
    for output in [args.out, args.markdown]:
        if output and output.exists():
            raise RuntimeError('refuse overwrite ' + str(output))
    value = reduce(args.completed.resolve())
    args.out.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')
    if args.markdown:
        args.markdown.write_text(markdown(value), encoding='utf-8')
    print(f"Reduced {len(value['processes'])} processes; {len(value['failed_attempts'])} failed attempts; {len(value['integrity_problems'])} integrity findings")
    return int(bool(value['reported_failure_count'] or value['failed_attempts'] or value['integrity_problems']))


if __name__ == '__main__':
    raise SystemExit(main())
