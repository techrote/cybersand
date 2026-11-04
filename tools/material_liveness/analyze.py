#!/usr/bin/env python3
"""Authenticate MAT354 evidence, then independently summarize scientific observations.

This reader consumes recorded native counters and stored states. It does not
import the probe, implement movement, execute World, or authorize production
changes. Full findings require reduce.reduce() to authenticate the complete
receipt, raw files, process completion, source custody and worker/repeat parity.
--allow-partial is explicitly UNQUALIFIED even when all available rows validate.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import re

import reduce as authentication

SCHEMA = 'mat354.analysis.v1'
GENERIC = {'paste': (20, 240), 'slush': (21, 192), 'brine': (24, 32), 'mercury': (33, 96)}
MOLTEN, GLASS = 36, 35
H2_FIXTURES = {'molten_pair', 'molten_pool_small', 'molten_pool_large', 'molten_hot',
               'molten_heterogeneous', 'molten_lost_neighbor', 'molten_cold'}
ARM_NAMES = {(3, False): 'default', (1024, False): 'extended_quiet', (3, True): 'active_neighbour'}
ERRORS = (ValueError, OSError, KeyError, TypeError, AttributeError, OverflowError)


class AnalysisError(ValueError):
    pass


def check(condition, reason):
    if not condition:
        raise AnalysisError(reason)


def integer(value, name, minimum=0, maximum=None):
    check(type(value) is int and (minimum is None or value >= minimum),
          f'{name}: expected integer' + (f' >= {minimum}' if minimum is not None else ''))
    check(maximum is None or value <= maximum, f'{name}: integer exceeds registered bound')
    return value


def boolean(value, name):
    check(type(value) is bool, f'{name}: expected boolean')
    return value


def event(row):
    return {key: row[key] for key in ('tick', 'world_tick', 'reset_epoch')}


def first(rows, predicate):
    return next((event(row) for row in rows if predicate(row)), None)


def samples(rows, predicate, limit=8):
    selected = [row for row in rows if predicate(row)]
    return {'count': len(selected), 'first_events': [event(row) for row in selected[:limit]],
            'last_event': event(selected[-1]) if selected else None}


def quantiles(values):
    """Nearest-rank quantiles; never mix owner-pause zeros into native tick cost."""
    if not values:
        return {'samples': 0, 'total_ns': 0, 'mean_ns': None,
                'p50_ns': None, 'p95_ns': None, 'p99_ns': None, 'max_ns': None}
    ordered = sorted(values)
    result = {'samples': len(values), 'total_ns': sum(values),
              'mean_ns': sum(values) / len(values), 'max_ns': ordered[-1]}
    for percentile in (50, 95, 99):
        result[f'p{percentile}_ns'] = ordered[(len(values) * percentile + 99) // 100 - 1]
    return result


def excluded(metadata, row):
    # The registered apparatus excludes before owner step9 and re-enters at17.
    return metadata['variant'] == 'region' and 9 <= row['tick'] <= 16


def validate_rows(metadata, ticks, summary):
    check(metadata.get('schema') == 'mat354.probe.v1', 'unsupported native probe schema')
    horizon = integer(metadata.get('horizon'), 'horizon', 1, 1024)
    check(len(ticks) == horizon, 'incomplete scientific tick coverage')
    check(metadata.get('rng_seed') is None and metadata.get('rng_identity') == 'native-coordinate-tick-stream',
          'random identity must name native coordinate/tick/stream and no configurable seed')
    check(type(metadata.get('fixture')) is str and type(metadata.get('variant')) is str, 'missing fixture/variant')
    for field in ('x', 'y'):
        integer(metadata.get(field), field, -16384, 16384)
    for field in ('workers', 'quiet', 'origin_count'):
        integer(metadata.get(field), field, 1)
    for field in ('material', 'initial_state_a', 'descriptor_viscosity'):
        integer(metadata.get(field), field)
    integer(metadata.get('initial_temperature'), 'initial_temperature', None)
    integer(metadata.get('repeat'), 'repeat')
    boolean(metadata.get('active_neighbour'), 'active_neighbour')
    check(metadata['workers'] in (1, 4) and metadata['quiet'] in (3, 1024), 'unregistered execution configuration')
    check(bool(metadata.get('kernel_counter_scope')), 'missing aggregate/singleton counter scope')
    previous_world_tick = 0
    previous_epoch = 0
    for index, row in enumerate(ticks, 1):
        check(integer(row.get('tick'), 'tick', 1) == index, 'noncontiguous owner steps')
        for name in ('world_tick', 'reset_epoch', 'state_a_before', 'state_a', 'state_b',
                     'down_rejections', 'down_all_rejections', 'lateral_probes', 'subject_moves',
                     'subject_conversions', 'glass_conversions', 'block_wakes', 'block_sleeps',
                     'water_updates', 'visited_cells', 'scheduled_cores', 'worker_threads_observed',
                     'active_blocks_after', 'active_chunks_after', 'chunk_allocations',
                     'temperature_field_allocations', 'resident_cell_bytes', 'water_quantity',
                     'subject_count', 'glass_count', 'tick_ns'):
            integer(row.get(name), name)
        for name in ('source_x', 'source_y', 'carrier_x', 'carrier_y', 'temperature'):
            integer(row.get(name), name, None)
        for name in ('material_before', 'material'):
            integer(row.get(name), name, 0, 255)
        integer(row.get('thermal_phase'), 'thermal_phase', 0, 3)
        integer(row.get('mobility_draw'), 'mobility_draw', 0, 255)
        integer(row.get('mobility_threshold'), 'mobility_threshold', 1, 256)
        integer(row.get('rng_stream'), 'rng_stream')
        for name in ('paused', 'cooling_due', 'hot_neighbor_before', 'source_masked',
                     'mobility_applicable', 'lateral_eligible', 'has_failed', 'quantity_ok', 'reset_fresh_equal'):
            boolean(row.get(name), name)
        check(not row['has_failed'] and row['quantity_ok'] and row['reset_fresh_equal'], 'native stop invariant failed')
        check(type(row.get('wake_cause')) is str, 'missing wake cause')
        for field in ('physical_hash', 'tuple_hash'):
            check(type(row.get(field)) is str and re.fullmatch('[0-9a-f]{16}', row[field]) is not None,
                  f'{field}: expected native 64-bit hash')
        if row['reset_epoch'] != previous_epoch:
            check(metadata['variant'] == 'reset' and index == 17 and row['reset_epoch'] == previous_epoch + 1,
                  'unregistered reset during scientific reduction')
            expected_world_tick = 1
        else:
            expected_world_tick = previous_world_tick + int(not row['paused'])
        check(row['world_tick'] == expected_world_tick, 'World tick advanced or stopped inconsistently with pause/reset')
        check(row['paused'] == (metadata['variant'] == 'owner_pause' and 9 <= index <= 16), 'unregistered owner pause')
        check(row['cooling_due'] == (not row['paused'] and row['world_tick'] % 4 == row['thermal_phase']),
              'recorded thermal eligibility disagrees with its recorded phase/tick')
        for name in ('block_before', 'block_after'):
            block = row.get(name)
            check(type(block) is dict, f'{name}: expected copied block observations')
            boolean(block.get('active'), name + '.active')
            integer(block.get('quiet'), name + '.quiet')
            integer(block.get('due'), name + '.due')
        jobs = row.get('phase_jobs')
        check(type(jobs) is list and len(jobs) == 4, 'expected four native phase job counts')
        check(sum(integer(value, 'phase job count') for value in jobs) == row['scheduled_cores'],
              'phase job count differs from actual scheduled core count')
        observed = row['worker_threads_observed']
        check(observed <= metadata['workers'], 'claimant count exceeds configured capacity')
        check((observed == 0) == (row['scheduled_cores'] == 0), 'claimants and actual jobs disagree')
        visits = row.get('kernel_visits')
        if visits is not None:
            integer(visits, 'kernel_visits')
            check(visits <= row['visited_cells'], 'material execution exceeds selected source visits')
            check(visits == row['down_rejections'] + row['glass_conversions'],
                  'kernel visit witness disagrees with direct rejection plus Glass conversion counters')
        if row['paused']:
            check(row['tick_ns'] == row['scheduled_cores'] == row['visited_cells'] == 0,
                  'owner pause reports native execution')
        if metadata['fixture'] in GENERIC:
            material, viscosity = GENERIC[metadata['fixture']]
            check(metadata.get('material') == material and metadata.get('descriptor_viscosity') == viscosity,
                  'generic descriptor differs from frozen source contract')
            check(visits in (0, 1) and visits is not None and row['subject_count'] == 1,
                  'single-source generic fixture lost its single subject/execution scope')
            check(row['down_rejections'] == visits and row['down_all_rejections'] == 3 * visits,
                  'generic visit witness is not one direct and two diagonal rejected moves')
            check(row['subject_conversions'] == 0, 'generic control unexpectedly converted')
            check(row['mobility_applicable'] and row['rng_stream'] == 91 and row['mobility_threshold'] == 256 - viscosity,
                  'generic mobility interpretation uses the wrong stream/threshold')
            if row['source_masked'] or row['paused'] or excluded(metadata, row):
                check(visits == 0, 'generic source executed despite registered mask/pause/exclusion')
            if not visits:
                check(row['subject_moves'] == row['lateral_probes'] == 0, 'generic motion/probe lacks an admitted visit')
            elif row['mobility_draw'] >= row['mobility_threshold']:
                check(row['subject_moves'] == row['lateral_probes'] == 0, 'failed admitted mobility sample produced lateral work')
            elif row['lateral_eligible']:
                check(row['subject_moves'] == 1, 'admitted successful sample with legal side did not move')
        previous_world_tick, previous_epoch = row['world_tick'], row['reset_epoch']
    check(summary.get('physical_hash') == ticks[-1]['physical_hash'], 'summary/final physical state disagree')
    check(summary.get('tuple_hash') == ticks[-1]['tuple_hash'], 'summary/final tuple census disagree')
    for name, expected in {
        'selected_visits': sum(row['visited_cells'] for row in ticks),
        'scheduled_jobs': sum(row['scheduled_cores'] for row in ticks),
        'max_workers_observed': max(row['worker_threads_observed'] for row in ticks),
        'tick_ns_total': sum(row['tick_ns'] for row in ticks),
        'final_world_tick': ticks[-1]['world_tick'],
        'final_subject_count': ticks[-1]['subject_count'],
        'final_glass_count': ticks[-1]['glass_count'],
        'first_kernel_visit': next((row['tick'] for row in ticks if (row['kernel_visits'] or 0) > 0), 0),
        'last_kernel_visit': next((row['tick'] for row in reversed(ticks) if (row['kernel_visits'] or 0) > 0), 0),
        'first_move': next((row['tick'] for row in ticks if row['subject_moves'] > 0), 0),
        'first_glass': next((row['tick'] for row in ticks if row['glass_conversions'] > 0), 0),
    }.items():
        check(integer(summary.get(name), 'summary.' + name) == expected, f'summary {name} disagrees with recorded ticks')


def case_facts(metadata, ticks, summary):
    validate_rows(metadata, ticks, summary)
    fixture = metadata['fixture']
    is_generic = fixture in GENERIC
    is_molten = fixture.startswith('molten_') or fixture == 'distributed_molten'
    singleton = (is_generic or (is_molten and max(row['subject_count'] +
                 (row['glass_count'] if metadata['material'] == MOLTEN else 0) for row in ticks) <= 1))
    visits_complete = all(row['kernel_visits'] is not None for row in ticks)
    kernel_total = sum(row['kernel_visits'] for row in ticks) if visits_complete else None
    def cold_due(row):
        return (singleton and is_molten and row['material_before'] == MOLTEN and row['cooling_due'] and
                not row['source_masked'] and not row['hot_neighbor_before'] and not excluded(metadata, row))
    cold_omission = lambda row: cold_due(row) and row['kernel_visits'] == 0
    no_jobs_omission = lambda row: cold_omission(row) and row['scheduled_cores'] == 0
    executed = [row for row in ticks if not row['paused']]
    subject_trace = [[row[key] for key in ('world_tick', 'reset_epoch', 'material', 'state_a', 'state_b',
                                           'temperature', 'carrier_x', 'carrier_y')] for row in ticks]
    result = {
        'case_id': metadata['case_id'],
        'configuration': {key: metadata[key] for key in ('fixture', 'variant', 'x', 'y', 'quiet', 'workers',
                                                       'horizon', 'repeat', 'active_neighbour')},
        'initial': {key: metadata[key] for key in ('material', 'initial_state_a', 'initial_temperature',
                                                  'descriptor_viscosity', 'origin_count')},
        'observational_scope': {
            'kernel_counter': metadata['kernel_counter_scope'], 'single_subject_throughout': singleton,
            'state_fields': 'representative source/carrier only; pool/distributed kernel counts are aggregate',
            'rng_bytes': 'prospective deterministic bytes; interpreted as consumed only when actual kernel admission is established',
        },
        'first_kernel_visit': first(ticks, lambda row: (row['kernel_visits'] or 0) > 0),
        'last_kernel_visit': next((event(row) for row in reversed(ticks) if (row['kernel_visits'] or 0) > 0), None),
        'first_subject_move': first(ticks, lambda row: row['subject_moves'] > 0),
        'first_glass_conversion': first(ticks, lambda row: row['glass_conversions'] > 0),
        'final': {key: ticks[-1][key] for key in ('material', 'state_a', 'state_b', 'temperature', 'carrier_x',
                                                 'carrier_y', 'subject_count', 'glass_count', 'water_quantity',
                                                 'block_after', 'physical_hash', 'tuple_hash')},
        'subject_trajectory_sha256': authentication.canonical_sha(subject_trace),
        'work': {
            'native_ticks': len(executed), 'owner_pause_steps': len(ticks) - len(executed),
            'selected_cell_visits': sum(row['visited_cells'] for row in ticks),
            'subject_kernel_visits': kernel_total, 'subject_kernel_visits_observable': visits_complete,
            'scheduled_jobs': sum(row['scheduled_cores'] for row in ticks),
            'phase_jobs': [sum(row['phase_jobs'][i] for row in ticks) for i in range(4)],
            'active_block_tick_sum': sum(row['active_blocks_after'] for row in executed),
            'ticks_with_zero_active_blocks_after': sum(row['active_blocks_after'] == 0 for row in executed),
            'zero_scheduled_job_ticks': sum(row['scheduled_cores'] == 0 for row in executed),
            'source_deadline_nonzero_ticks': sum(row['block_before']['due'] != 0 or row['block_after']['due'] != 0 for row in executed),
            'native_block_wakes_aggregate': sum(row['block_wakes'] for row in ticks),
            'native_block_sleeps_aggregate': sum(row['block_sleeps'] for row in ticks),
            'chunk_allocations': sum(row['chunk_allocations'] for row in ticks),
            'temperature_field_allocations': sum(row['temperature_field_allocations'] for row in ticks),
            'resident_cell_bytes_max': max(row['resident_cell_bytes'] for row in ticks),
        },
        'workers': {'configured': metadata['workers'],
                    'max_distinct_claimants_in_one_dispatch': max(row['worker_threads_observed'] for row in ticks),
                    'ticks_observing_multiple_claimants': sum(row['worker_threads_observed'] > 1 for row in ticks),
                    'max_jobs_in_one_phase': max(max(row['phase_jobs']) for row in ticks)},
        'tick_cost': {'units': 'nanoseconds', 'quantile_method': 'nearest rank',
                      'scope': 'descriptive World::tick duration; includes native diagnostics, excludes external census/JSON; no future-fix overhead or benchmark claim',
                      'all_native_ticks': quantiles([row['tick_ns'] for row in executed]),
                      'zero_job_native_ticks': quantiles([row['tick_ns'] for row in executed if row['scheduled_cores'] == 0])},
        'thermal': {
            'representative_phases': sorted({row['thermal_phase'] for row in ticks}),
            'included_unmasked_cold_due': samples(ticks, cold_due),
            'cold_due_with_subject_visit': samples(ticks, lambda row: cold_due(row) and (row['kernel_visits'] or 0) > 0),
            'cold_subject_visits_off_thermal_lane': samples(ticks, lambda row: singleton and is_molten and
                row['material_before'] == MOLTEN and not row['cooling_due'] and not row['hot_neighbor_before'] and
                (row['kernel_visits'] or 0) > 0),
            'cold_due_without_subject_visit': samples(ticks, cold_omission),
            'cold_due_without_any_scheduled_job': samples(ticks, no_jobs_omission),
            'cold_due_in_sleeping_source_block_without_visit': samples(ticks, lambda row: cold_omission(row) and
                not row['block_before']['active'] and row['block_before']['due'] == 0),
            'representative_resets_to_180': samples(ticks, lambda row: row['material_before'] == MOLTEN and
                row['state_a_before'] < 180 and row['material'] == MOLTEN and row['state_a'] == 180),
            'representative_resets_from_7_to_180': samples(ticks, lambda row: row['material_before'] == MOLTEN and
                row['state_a_before'] == 7 and row['material'] == MOLTEN and row['state_a'] == 180),
            'representative_countdown_decrements': samples(ticks, lambda row: is_molten and
                row['material_before'] == row['material'] == MOLTEN and row['state_a'] < row['state_a_before']),
            'hot_due_at_180_with_subject_work': samples(ticks, lambda row: is_molten and row['cooling_due'] and
                row['hot_neighbor_before'] and row['material_before'] == row['material'] == MOLTEN and
                row['state_a_before'] == row['state_a'] == 180 and (row['kernel_visits'] or 0) > 0),
            'hot_due_counter_limit': 'for pools/pairs, coincident aggregate work does not attribute every visit to the representative cell',
            'glass_conversions_total': sum(row['glass_conversions'] for row in ticks),
            'observed_subject_count_min_max': [min(row['subject_count'] for row in ticks), max(row['subject_count'] for row in ticks)],
            'observed_glass_count_min_max': [min(row['glass_count'] for row in ticks), max(row['glass_count'] for row in ticks)],
        },
        'external_events': [{**event(row), 'cause': row['wake_cause'], 'kernel_visits': row['kernel_visits'],
                            'scheduled_jobs': row['scheduled_cores'], 'subject_moves': row['subject_moves'],
                            'source_masked': row['source_masked'], 'block_before': row['block_before'],
                            'block_after': row['block_after']} for row in ticks if row['wake_cause'] != 'none'],
    }
    if is_generic:
        admitted = lambda row: row['kernel_visits'] == 1
        prospective = lambda row: (not row['paused'] and not row['source_masked'] and not excluded(metadata, row) and
                                   row['lateral_eligible'] and row['mobility_draw'] < row['mobility_threshold'])
        result['generic_mobility'] = {
            'stream': 91, 'threshold': 256 - GENERIC[fixture][1],
            'initial_three_observations': [{**event(row), 'draw': row['mobility_draw'],
                                            'kernel_visits': row['kernel_visits'], 'lateral_eligible': row['lateral_eligible']} for row in ticks[:3]],
            'admitted_failed_draws': samples(ticks, lambda row: admitted(row) and row['mobility_draw'] >= row['mobility_threshold']),
            'admitted_success_with_legal_side': samples(ticks, lambda row: admitted(row) and prospective(row)),
            'unexecuted_prospective_success_bytes': samples(ticks, lambda row: not admitted(row) and prospective(row)),
            'prospective_byte_limit': 'an unexecuted byte is not an actual random event and does not establish a mandatory retry obligation',
            'lateral_probes': sum(row['lateral_probes'] for row in ticks),
            'subject_moves': sum(row['subject_moves'] for row in ticks),
        }
    return result


def matched_table(facts, predicate):
    groups = defaultdict(dict)
    for item in facts:
        config = item['configuration']
        arm = ARM_NAMES.get((config['quiet'], config['active_neighbour']))
        if not predicate(item) or arm is None:
            continue
        key = tuple((name, config[name]) for name in ('fixture', 'variant', 'x', 'y', 'workers', 'horizon', 'repeat'))
        check(arm not in groups[key], 'duplicate scientific comparison arm')
        groups[key][arm] = item
    output = []
    for key, arms in sorted(groups.items()):
        row = {'configuration': dict(key), 'arms': {}}
        for name, item in sorted(arms.items()):
            row['arms'][name] = {
                'case_id': item['case_id'], 'kernel_visits': item['work']['subject_kernel_visits'],
                'scheduled_jobs': item['work']['scheduled_jobs'], 'first_move': item['first_subject_move'],
                'first_glass_conversion': item['first_glass_conversion'], 'final': item['final'],
                'thermal': item['thermal'], 'generic_mobility': item.get('generic_mobility'),
            }
        row['complete_three_arm_comparison'] = set(arms) == set(ARM_NAMES.values())
        row['extended_and_active_neighbour_subject_trajectory_equal'] = (
            arms['extended_quiet']['subject_trajectory_sha256'] == arms['active_neighbour']['subject_trajectory_sha256']
            if 'extended_quiet' in arms and 'active_neighbour' in arms else None)
        row['default_and_extended_subject_trajectory_equal'] = (
            arms['default']['subject_trajectory_sha256'] == arms['extended_quiet']['subject_trajectory_sha256']
            if 'default' in arms and 'extended_quiet' in arms else None)
        output.append(row)
    return output


def analyze(receipt, raw_root=None, *, allow_partial=False):
    errors, facts, missing = [], [], []
    authenticated = None
    try:
        authenticated = authentication.reduce(receipt, raw_root)
        check(type(authenticated) is dict and authenticated.get('status') == 'PASS',
              'independent authentication did not explicitly pass')
    except ERRORS as exc:
        authenticated = None
        if not allow_partial:
            raise AnalysisError(f'complete independent authentication failed: {exc}') from exc
        errors.append({'stage': 'campaign_authentication', 'reason': str(exc)})
    check(type(receipt) is dict, 'receipt must be an object')
    plans = receipt.get('plan', {}).get('cases', [])
    processes = receipt.get('cases', [])
    check(type(plans) is list and type(processes) is list, 'planned/executed cases must be arrays')
    seen = set()
    for index, plan in enumerate(plans):
        identifier = plan.get('id') if type(plan) is dict else f'index-{index}'
        try:
            check(identifier not in seen, 'duplicate planned case identifier')
            seen.add(identifier)
            check(index < len(processes), 'registered native process is missing')
            process = processes[index]
            if authenticated is None:
                authentication.reduce_case(process, plan, raw_root)
            # Reauthenticate bytes used for the scientific pass; never trust a
            # stale reduction file or a caller-supplied successful status alone.
            raw = authentication.raw_file(process['stdout'], raw_root)
            rows = authentication.read_rows(raw)
            item = case_facts(rows[0], rows[1:-1], rows[-1])
            item['raw_sha256'] = hashlib.sha256(raw).hexdigest()
            facts.append(item)
        except ERRORS as exc:
            if not allow_partial:
                raise AnalysisError(f'{identifier}: {exc}') from exc
            missing.append(identifier)
            errors.append({'stage': 'case_scientific_read', 'case_id': identifier, 'reason': str(exc)})
    for process in processes[len(plans):]:
        errors.append({'stage': 'unregistered_process', 'case_id': process.get('id'), 'reason': 'process exceeds registered plan'})
    witnesses = receipt.get('plan', {}).get('witnesses', {})
    check(type(witnesses) is dict, 'witness coordinate map must be an object')
    for name, point in witnesses.items():
        check(name in GENERIC and type(point) is list and len(point) == 2 and all(type(v) is int for v in point),
              'invalid preregistered generic witness coordinates')
    def primary(item):
        c = item['configuration']
        return c['fixture'] in witnesses and c['variant'] == 'baseline' and [c['x'], c['y']] == witnesses[c['fixture']]
    status = 'UNQUALIFIED' if allow_partial or errors else 'PASS'
    return {
        'schema': SCHEMA, 'status': status,
        'qualification': 'source-qualified observations only; production authorization remains pending' if status == 'PASS'
                         else 'partial/failed evidence; no campaign acceptance or causal admission',
        'independent_authentication_passed': authenticated is not None,
        'source_commit': receipt.get('source_commit'), 'source_tree': receipt.get('source_tree'),
        'accepted_source': receipt.get('accepted_source'), 'mode': receipt.get('mode'), 'host': receipt.get('host'),
        'executable': receipt.get('executable'), 'input_inventory_sha256': receipt.get('input_inventory_sha256'),
        'runtime_qualifications': {
            'disable_leak_check': receipt.get('disable_leak_check', False),
            'leak_check': receipt.get('leak_check'),
            'sanitizer_environment': receipt.get('sanitizer_environment', {}),
            'artifact_mode_repairs': receipt.get('artifact_mode_repairs', []),
            'authentication_limits': authenticated.get('limits', []) if authenticated is not None else [],
        },
        'coverage': {'registered_cases': len(plans), 'executed_processes': len(processes),
                     'authenticated_scientific_case_facts': len(facts), 'unavailable_case_ids': missing},
        'errors': errors, 'cases': facts,
        'h1': {'phase_table': matched_table(facts, lambda item: item['configuration']['fixture'] in
              {'molten_isolated', 'molten_short'} and item['configuration']['variant'] == 'baseline'),
               'interpretation_limit': 'cold due rows without visits/jobs are observations; compare matched awake controls and current source contract before admitting a scheduler correction'},
        'h2': {'cases': [{key: item[key] for key in ('case_id', 'configuration', 'observational_scope', 'thermal', 'final', 'work')}
                         for item in facts if item['configuration']['fixture'] in H2_FIXTURES],
               'interpretation_limit': 'finite observed retention is separate from a source-derived indefinite fixed point; per-cell pool countdown histories are not exposed by aggregate counters'},
        'h3': {'primary_witnesses': matched_table(facts, primary),
               'blocked_controls': [{key: item[key] for key in ('case_id', 'configuration', 'generic_mobility', 'final', 'work')}
                                    for item in facts if item['configuration']['fixture'] in GENERIC and item['configuration']['variant'] == 'blocked'],
               'named_wake_controls': [{'case_id': item['case_id'], 'configuration': item['configuration'], 'events': item['external_events']}
                                       for item in facts if item['configuration']['fixture'] in GENERIC and item['external_events']],
               'interpretation_limit': 'generic sleep-censored sampling is documented legacy rest; no mandatory retry follows from different quiet-threshold trajectories. Default viscosity0 Water-CY probe rows are not rare-retry evidence; use the separate existing liveness regression.'},
        'workers': {'authenticated_parity': authenticated['parity'] if authenticated is not None else None,
                    'distributed_cases': [{'case_id': item['case_id'], **item['workers'], 'scheduled_jobs': item['work']['scheduled_jobs']}
                                          for item in facts if item['configuration']['fixture'].startswith('distributed_')]},
        'limits': [
            'No production scheduler/material change, gameplay acceptance, fallback/Godot qualification or missing-platform execution is inferred.',
            'No unexecuted prospective random byte is an actual event or a promised future move.',
            'Representative pool state and aggregate material visits have different scopes.',
            'Native tick timing includes enabled physics diagnostics; no instrumentation-neutrality, future-fix overhead or controlled benchmark claim.',
            'Earlier apparatus versions can have finite active-neighbour coverage; equality is measured per case, never assumed.',
            'Partial mode retains authentication failures and missing records and is always UNQUALIFIED.',
        ],
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('receipt', type=Path)
    parser.add_argument('--raw-root', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--allow-partial', action='store_true', help='retain named partial facts/errors; always UNQUALIFIED')
    args = parser.parse_args(argv)
    if args.output.exists() or args.output.suffix != '.json' or args.output.resolve() == args.receipt.resolve():
        parser.error('output must be a new .json file; never overwrite evidence')
    try:
        raw_receipt = args.receipt.read_bytes()
        result = analyze(authentication.decode(raw_receipt.decode('utf-8')), args.raw_root, allow_partial=args.allow_partial)
        result['campaign_receipt_sha256'] = hashlib.sha256(raw_receipt).hexdigest()
    except ERRORS as exc:
        result = {'schema': SCHEMA, 'status': 'UNQUALIFIED' if args.allow_partial else 'FAIL',
                  'independent_authentication_passed': False,
                  'errors': [{'stage': 'analysis', 'reason': str(exc)}]}
    result['analysis_script_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    result['authentication_script_sha256'] = hashlib.sha256(Path(authentication.__file__).read_bytes()).hexdigest()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2, sort_keys=True, allow_nan=False)
        stream.write('\n')
    print(json.dumps({'status': result['status'], 'output': str(args.output), 'coverage': result.get('coverage')}))
    return 0 if result['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
