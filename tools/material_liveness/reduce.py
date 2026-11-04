#!/usr/bin/env python3
"""Independently authenticate and reduce MAT354 raw native JSONL.

This reader never imports the probe, reproduces movement, or treats equal final
images as visit evidence. It authenticates raw files, checks complete run coverage,
counts reported native observations, and compares full per-tick physical hashes.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import re
import sys


class ReductionError(ValueError):
    pass


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ReductionError(f'duplicate JSON key {key}')
        result[key] = value
    return result


def decode(text):
    return json.loads(text, object_pairs_hook=unique_object,
                      parse_constant=lambda value: (_ for _ in ()).throw(ReductionError(f'nonfinite {value}')))


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical_sha(value):
    return digest(json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode())


def integer(value, name, minimum=0):
    if type(value) is not int or value < minimum:
        raise ReductionError(f'{name} must be integer >= {minimum}')
    return value


def boolean(value, name):
    if type(value) is not bool:
        raise ReductionError(f'{name} must be boolean')
    return value


def text(value, name):
    if type(value) is not str or not value:
        raise ReductionError(f'{name} must be nonempty text')
    return value


def sha256(value, name):
    if type(value) is not str or not re.fullmatch('[0-9a-f]{64}', value):
        raise ReductionError(f'{name} must be lowercase SHA-256')
    return value


def raw_file(info, raw_root=None):
    if type(info) is not dict:
        raise ReductionError('raw file descriptor must be an object')
    original = Path(text(info.get('path'), 'raw path'))
    path = (raw_root / original.name) if raw_root else original
    data = path.read_bytes()
    if integer(info.get('bytes'), 'raw bytes') != len(data) or sha256(info.get('sha256'), 'raw digest') != digest(data):
        raise ReductionError(f'raw identity mismatch: {path}')
    return data


def read_rows(data):
    rows = []
    if not data or not data.endswith(b'\n'):
        raise ReductionError('raw JSONL is empty or truncated (requires terminal newline)')
    for line_number, line in enumerate(data.decode('utf-8').splitlines(), 1):
        if not line:
            raise ReductionError(f'blank JSONL line {line_number}')
        row = decode(line)
        if type(row) is not dict:
            raise ReductionError(f'JSONL line {line_number} is not an object')
        rows.append(row)
    if len(rows) > 1_000_002:
        raise ReductionError('raw JSONL exceeds registered hard row bound')
    return rows


def state(row):
    return {key: row[key] for key in ('material', 'state_a', 'state_b', 'temperature', 'physical_hash', 'state_hash') if key in row}


def reduce_case(result, plan, raw_root=None):
    if result.get('id') != plan.get('id'):
        raise ReductionError('executed case order/identity differs from plan')
    if boolean(result.get('timed_out'), 'timed_out') or type(result.get('returncode')) is not int or result['returncode'] != 0:
        raise ReductionError(f'failed native process: {result.get("id")}')
    if result.get('argv', [])[1:] != plan.get('argv'):
        raise ReductionError('executed arguments differ from registered plan')
    data = raw_file(result.get('stdout'), raw_root)
    raw_file(result.get('stderr'), raw_root)
    rows = read_rows(data)
    if len(rows) < 2 or rows[0].get('type') != 'metadata' or rows[-1].get('type') != 'summary':
        raise ReductionError('requires exactly metadata, tick rows, summary in that order')
    metadata, summary = rows[0], rows[-1]
    ticks = rows[1:-1]
    if any(row.get('type') != 'tick' for row in ticks):
        raise ReductionError('unexpected non-tick row inside execution')
    case_id = text(metadata.get('case_id'), 'metadata.case_id')
    if summary.get('case_id') != case_id:
        raise ReductionError('metadata/summary case identity mismatch')
    workers = integer(metadata.get('workers'), 'workers', 1)
    if workers not in (1, 4):
        raise ReductionError('unregistered worker capacity')
    if 'expected_workers' in plan and (type(plan['expected_workers']) is not int or workers != plan['expected_workers']):
        raise ReductionError('worker configuration differs from plan')
    horizon = integer(metadata.get('horizon'), 'horizon', 1)
    if len(ticks) != horizon:
        raise ReductionError(f'incomplete tick coverage: {len(ticks)}/{horizon}')
    for flag, field in (('--fixture', 'fixture'), ('--quiet', 'quiet'), ('--workers', 'workers'),
                        ('--x', 'x'), ('--y', 'y'), ('--ticks', 'horizon'),
                        ('--variant', 'variant'), ('--active-neighbour', 'active_neighbour')):
        if flag in plan['argv']:
            index = plan['argv'].index(flag)
            if index + 1 == len(plan['argv']):
                raise ReductionError(f'flag missing value: {flag}')
            expected = plan['argv'][index + 1]
            actual = metadata.get(field)
            if field == 'active_neighbour' and type(actual) is bool:
                actual = int(actual)
            if str(actual) != expected:
                raise ReductionError(f'metadata {field} differs from actual invocation')
    sums = defaultdict(int)
    observation = {'id': result['id'], 'case_id': case_id, 'metadata': metadata,
                   'raw_sha256': digest(data), 'ticks': horizon, 'workers_configured': workers,
                   'workers_observed_max': 0, 'first_kernel_visit': None, 'last_kernel_visit': None,
                   'first_state_change': None, 'last_state_change': None, 'state_changes': 0,
                   'kernel_visit_observation_complete': True}
    last_world_tick = -1
    hashes = []
    prior_state = None
    for index, row in enumerate(ticks, 1):
        if integer(row.get('tick'), 'tick', 1) != index:
            raise ReductionError('tick index must start at 1 and be contiguous')
        world_tick = integer(row.get('world_tick'), 'world_tick')
        if world_tick < last_world_tick:
            raise ReductionError('world_tick regressed without a separate reconstruction run')
        last_world_tick = world_tick
        if boolean(row.get('has_failed'), 'has_failed') or not boolean(row.get('quantity_ok'), 'quantity_ok'):
            raise ReductionError(f'health/accounting stop at tick {index}')
        if 'unexpected_conversion' in row and boolean(row['unexpected_conversion'], 'unexpected_conversion'):
            raise ReductionError(f'unexpected conversion at tick {index}')
        observed = integer(row.get('worker_threads_observed'), 'worker_threads_observed')
        if observed > workers:
            raise ReductionError('observed worker count exceeds configuration')
        observation['workers_observed_max'] = max(observation['workers_observed_max'], observed)
        phase_jobs = row.get('phase_jobs')
        if type(phase_jobs) is not list:
            raise ReductionError('phase_jobs must be array of actual native job counts')
        sums['phase_jobs'] += sum(integer(value, 'phase job') for value in phase_jobs)
        for key in ('visited_cells', 'scheduled_cores', 'active_blocks_after'):
            sums[key] += integer(row.get(key), key)
        if row.get('kernel_visits') is None:
            observation['kernel_visit_observation_complete'] = False
        else:
            visits = integer(row['kernel_visits'], 'kernel_visits')
            sums['kernel_visits'] += visits
            if visits:
                if observation['first_kernel_visit'] is None:
                    observation['first_kernel_visit'] = index
                observation['last_kernel_visit'] = index
        current_state = tuple(row.get(key) for key in ('material', 'state_a', 'state_b', 'temperature'))
        if prior_state is not None and current_state != prior_state:
            observation['state_changes'] += 1
            if observation['first_state_change'] is None:
                observation['first_state_change'] = index
            observation['last_state_change'] = index
        prior_state = current_state
        hashes.append(text(row.get('physical_hash'), 'physical_hash'))
    if boolean(summary.get('has_failed'), 'summary.has_failed') or not boolean(summary.get('quantity_ok'), 'summary.quantity_ok'):
        raise ReductionError('summary health/accounting violation')
    if summary.get('physical_hash') != hashes[-1]:
        raise ReductionError('final physical hash differs from final tick')
    observation['first_observation'] = state(ticks[0])
    observation['last_observation'] = state(ticks[-1])
    observation['summary'] = summary
    observation['totals'] = dict(sums)
    observation['trajectory_sha256'] = canonical_sha(hashes)
    observation['raw_process_seconds'] = result.get('duration_seconds')
    return observation, hashes


def reduce(receipt, raw_root=None):
    if type(receipt) is not dict or receipt.get('schema') != 'mat354.campaign.v1':
        raise ReductionError('unsupported campaign schema')
    if receipt.get('status') != 'EXECUTED':
        raise ReductionError('campaign was not completely executed; preserve failure receipt')
    if not boolean(receipt.get('source_qualified'), 'source_qualified'):
        raise ReductionError('diagnostic dirty-apparatus execution is not source-qualified evidence')
    if receipt.get('protected_source_guard') != receipt.get('post_run_guard'):
        raise ReductionError('protected-source guard changed during execution')
    guard = receipt.get('protected_source_guard', {})
    if guard.get('status') != 'PASS' or guard.get('protected_sources') != 27 or guard.get('production_cutover') is not False:
        raise ReductionError('legacy 27-file compatibility guard did not pass')
    inventory = receipt.get('compiled_input_inventory')
    if type(inventory) is not list or not inventory:
        raise ReductionError('missing source inventory')
    paths = set()
    for entry in inventory:
        path = text(entry.get('path'), 'inventory path')
        if path in paths:
            raise ReductionError('duplicate source input')
        paths.add(path)
        integer(entry.get('bytes'), 'inventory bytes')
        sha256(entry.get('sha256'), 'inventory digest')
    if 'native/src/world.cpp' not in paths or 'native/tests/material_liveness_probe.cpp' not in paths:
        raise ReductionError('inventory must bind actual World and probe')
    if receipt.get('input_inventory_sha256') != canonical_sha(inventory):
        raise ReductionError('input inventory digest mismatch')
    plan = receipt.get('plan')
    if type(plan) is not dict or plan.get('schema') != 'mat354.plan.v1' or canonical_sha(plan) != receipt.get('plan_sha256'):
        raise ReductionError('registered plan identity mismatch')
    planned = plan.get('cases')
    cases = receipt.get('cases')
    if type(planned) is not list or type(cases) is not list or not planned or len(cases) != len(planned):
        raise ReductionError('missing or extra native processes')
    if len({row.get('id') for row in planned}) != len(planned):
        raise ReductionError('duplicate registered case ID')
    observations = []
    groups = defaultdict(list)
    for actual, expected in zip(cases, planned):
        observation, hashes = reduce_case(actual, expected, raw_root)
        observations.append(observation)
        if expected.get('parity_group'):
            groups[expected['parity_group']].append((observation, hashes))
    parity = []
    for name, arms in sorted(groups.items()):
        reference = arms[0][1]
        matching = all(hashes == reference for _, hashes in arms)
        capacities = sorted({arm['workers_configured'] for arm, _ in arms})
        if not matching:
            raise ReductionError(f'worker/repeat physical trajectory parity violation: {name}')
        parity.append({'group': name, 'cases': [arm['id'] for arm, _ in arms], 'matching': True,
                       'worker_capacities': capacities,
                       'one_four_comparison': capacities == [1, 4],
                       'workers_observed_max': max(arm['workers_observed_max'] for arm, _ in arms),
                       'trajectory_sha256': arms[0][0]['trajectory_sha256']})
    return {'schema': 'mat354.reduction.v1', 'status': 'PASS', 'source_commit': receipt['source_commit'],
            'source_tree': receipt['source_tree'], 'input_inventory_sha256': receipt['input_inventory_sha256'],
            'executable': receipt['executable'], 'mode': receipt['mode'], 'host': receipt['host'],
            'cases': observations, 'parity': parity,
            'limits': ['Native source-matched fixture evidence only; no graphical/gameplay acceptance.',
                       'Timing includes instrumented observation; not a production scheduler benchmark.',
                       'A configured pool capacity does not establish actual worker participation.',
                       'Thermal or stochastic behavior classification requires source-contract review.']}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('receipt', type=Path)
    parser.add_argument('--raw-root', type=Path, help='relocated raw directory, preserving every original filename')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(argv)
    if args.output.resolve() == args.receipt.resolve():
        parser.error('output cannot overwrite input receipt')
    try:
        receipt = decode(args.receipt.read_text(encoding='utf-8'))
        result = reduce(receipt, args.raw_root)
        result['campaign_receipt_sha256'] = digest(args.receipt.read_bytes())
        exit_code = 0
    except (ReductionError, ValueError, OSError, KeyError, TypeError) as exc:
        result = {'schema': 'mat354.reduction.v1', 'status': 'FAIL', 'reason': str(exc)}
        exit_code = 1
    if args.output.suffix != '.json' or args.output.exists():
        parser.error('output must be a new .json file; preserve prior results')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True, allow_nan=False) + '\n', encoding='utf-8')
    print(json.dumps({'status': result['status'], 'output': str(args.output)}))
    return exit_code


if __name__ == '__main__':
    raise SystemExit(main())
