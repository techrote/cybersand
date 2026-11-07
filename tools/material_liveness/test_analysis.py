#!/usr/bin/env python3
"""Adversarial scientific-reader tests. Synthetic rows are never World evidence."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import analyze


def summarize(rows):
    """Create a synthetic receipt summary, not a prediction of native behavior."""
    metadata, ticks = rows[0], rows[1:]
    return {
        'type': 'summary', 'case_id': metadata['case_id'], 'has_failed': False, 'quantity_ok': True,
        'physical_hash': ticks[-1]['physical_hash'], 'tuple_hash': ticks[-1]['tuple_hash'],
        'selected_visits': sum(row['visited_cells'] for row in ticks),
        'scheduled_jobs': sum(row['scheduled_cores'] for row in ticks),
        'max_workers_observed': max(row['worker_threads_observed'] for row in ticks),
        'tick_ns_total': sum(row['tick_ns'] for row in ticks),
        'final_world_tick': ticks[-1]['world_tick'], 'final_subject_count': ticks[-1]['subject_count'],
        'final_glass_count': ticks[-1]['glass_count'],
        'first_kernel_visit': next((row['tick'] for row in ticks if (row['kernel_visits'] or 0) > 0), 0),
        'last_kernel_visit': next((row['tick'] for row in reversed(ticks) if (row['kernel_visits'] or 0) > 0), 0),
        'first_move': next((row['tick'] for row in ticks if row['subject_moves']), 0),
        'first_glass': next((row['tick'] for row in ticks if row['glass_conversions']), 0),
    }


def payload(workers=1):
    metadata = {
        'type': 'metadata', 'schema': 'mat354.probe.v1', 'case_id': f'synthetic-w{workers}',
        'fixture': 'paste', 'variant': 'baseline', 'x': 8, 'y': 8, 'quiet': 3, 'workers': workers,
        'horizon': 6, 'repeat': 0, 'active_neighbour': False, 'rng_seed': None,
        'rng_identity': 'native-coordinate-tick-stream', 'material': 20,
        'descriptor_viscosity': 240, 'initial_state_a': 9, 'initial_temperature': 20, 'origin_count': 1,
        'kernel_counter_scope': 'whole-world subject material; singleton only is cell-specific',
    }
    rows = [metadata]
    for tick, draw in enumerate((200, 220, 240, 0, 100, 100), 1):
        visits = int(tick <= 3)
        rows.append({
            'type': 'tick', 'tick': tick, 'world_tick': tick, 'reset_epoch': 0, 'paused': False,
            'wake_cause': 'none', 'source_x': 8, 'source_y': 8, 'carrier_x': 8, 'carrier_y': 8,
            'material_before': 20, 'material': 20, 'state_a_before': 9, 'state_a': 9, 'state_b': 0,
            'temperature': 20, 'thermal_phase': 1, 'cooling_due': tick % 4 == 1,
            'hot_neighbor_before': False, 'source_masked': False, 'mobility_applicable': True,
            'rng_stream': 91, 'mobility_draw': draw, 'mobility_threshold': 16, 'lateral_eligible': True,
            'block_before': {'active': bool(visits), 'quiet': min(tick - 1, 3), 'due': 0},
            'block_after': {'active': tick < 3, 'quiet': min(tick, 3), 'due': 0},
            'visited_cells': visits, 'kernel_visits': visits,
            'down_rejections': visits, 'down_all_rejections': 3 * visits,
            'lateral_probes': 0, 'subject_moves': 0, 'subject_conversions': 0, 'glass_conversions': 0,
            'block_wakes': 0, 'block_sleeps': int(tick == 3), 'water_updates': 0,
            'scheduled_cores': visits, 'phase_jobs': [visits, 0, 0, 0], 'worker_threads_observed': visits,
            'active_blocks_after': int(tick < 3), 'active_chunks_after': int(tick < 3),
            'chunk_allocations': 0, 'temperature_field_allocations': 0, 'resident_cell_bytes': 1024,
            'water_quantity': 0, 'subject_count': 1, 'glass_count': 0, 'tick_ns': 100 + tick,
            'has_failed': False, 'quantity_ok': True, 'reset_fresh_equal': True,
            'physical_hash': 'a' * 16, 'tuple_hash': 'b' * 16,
        })
    return [*rows, summarize(rows)]


def facts(rows):
    return analyze.case_facts(rows[0], rows[1:-1], rows[-1])


def refresh_summary(rows):
    rows[-1] = summarize(rows[:-1])


class ScientificReaderTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)

    def file_record(self, path):
        data = path.read_bytes()
        return {'path': str(path), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}

    def receipt(self):
        plans, processes = [], []
        for workers in (1, 4):
            rows = payload(workers)
            identifier = rows[0]['case_id']
            argv = ['--fixture', 'paste', '--variant', 'baseline', '--x', '8', '--y', '8',
                    '--quiet', '3', '--workers', str(workers), '--ticks', '6', '--repeat', '0',
                    '--active-neighbour', '0']
            stdout = self.directory / f'{identifier}.stdout'
            stderr = self.directory / f'{identifier}.stderr'
            stdout.write_text(''.join(json.dumps(row) + '\n' for row in rows))
            stderr.write_text('')
            plans.append({'id': identifier, 'argv': argv, 'expected_workers': workers})
            processes.append({'id': identifier, 'argv': ['synthetic', *argv], 'returncode': 0, 'timed_out': False,
                              'stdout': self.file_record(stdout), 'stderr': self.file_record(stderr)})
        guard = {'status': 'PASS', 'protected_sources': 27, 'production_cutover': False}
        inventory = [{'path': path, 'bytes': 1, 'sha256': '0' * 64}
                     for path in ('native/src/world.cpp', 'native/tests/material_liveness_probe.cpp')]
        plan = {'schema': 'mat354.plan.v1', 'cases': plans, 'witnesses': {'paste': [8, 8]}}
        return {
            'schema': 'mat354.campaign.v1', 'status': 'EXECUTED', 'source_qualified': True,
            'source_commit': 'a' * 40, 'source_tree': 'b' * 40, 'mode': 'synthetic-unit-test', 'host': {},
            'executable': {'sha256': 'c' * 64}, 'protected_source_guard': guard, 'post_run_guard': guard,
            'compiled_input_inventory': inventory, 'input_inventory_sha256': analyze.authentication.canonical_sha(inventory),
            'plan': plan, 'plan_sha256': analyze.authentication.canonical_sha(plan), 'cases': processes,
        }

    def rewrite(self, receipt, mutate, index=0):
        process = receipt['cases'][index]
        path = Path(process['stdout']['path'])
        rows = analyze.authentication.read_rows(path.read_bytes())
        mutate(rows)
        path.write_text(''.join(json.dumps(row) + '\n' for row in rows))
        process['stdout'] = self.file_record(path)

    def test_full_analysis_calls_complete_authentication(self):
        with patch.object(analyze.authentication, 'reduce', wraps=analyze.authentication.reduce) as authenticate:
            result = analyze.analyze(self.receipt())
        authenticate.assert_called_once()
        self.assertEqual(result['status'], 'PASS')
        self.assertTrue(result['independent_authentication_passed'])
        self.assertEqual(result['coverage']['authenticated_scientific_case_facts'], 2)
        self.assertTrue(result['workers']['authenticated_parity'][0]['one_four_comparison'])
        self.assertEqual(result['cases'][1]['workers']['configured'], 4)
        self.assertEqual(result['cases'][1]['workers']['max_distinct_claimants_in_one_dispatch'], 1)

    def test_successful_status_string_is_not_an_authenticated_receipt(self):
        receipt = self.receipt()
        receipt['status'] = 'PASS'
        with self.assertRaisesRegex(analyze.AnalysisError, 'authentication failed'):
            analyze.analyze(receipt)

    def test_authentication_return_must_explicitly_pass(self):
        with patch.object(analyze.authentication, 'reduce', return_value={'status': 'FAIL'}):
            with self.assertRaisesRegex(analyze.AnalysisError, 'did not explicitly pass'):
                analyze.analyze(self.receipt())

    def test_corrupt_raw_is_rejected_and_partial_keeps_case_identity(self):
        receipt = self.receipt()
        Path(receipt['cases'][0]['stdout']['path']).write_bytes(b'{')
        with self.assertRaisesRegex(analyze.AnalysisError, 'raw identity mismatch'):
            analyze.analyze(receipt)
        partial = analyze.analyze(receipt, allow_partial=True)
        self.assertEqual(partial['status'], 'UNQUALIFIED')
        self.assertFalse(partial['independent_authentication_passed'])
        self.assertEqual(partial['coverage']['unavailable_case_ids'], ['synthetic-w1'])
        self.assertEqual(partial['coverage']['authenticated_scientific_case_facts'], 1)
        self.assertTrue(any('raw identity mismatch' in error['reason'] for error in partial['errors']))
        self.assertIsNone(partial['workers']['authenticated_parity'])

    def test_partial_mode_is_unqualified_even_with_complete_valid_rows(self):
        result = analyze.analyze(self.receipt(), allow_partial=True)
        self.assertEqual(result['status'], 'UNQUALIFIED')
        self.assertTrue(result['independent_authentication_passed'])
        self.assertEqual(result['errors'], [])

    def test_explicit_sanitizer_limit_survives_scientific_reduction(self):
        receipt = self.receipt()
        receipt.update(mode='asan-ubsan', disable_leak_check=True,
                       leak_check={'status': 'unexecuted', 'reason': 'explicit campaign scope'},
                       sanitizer_environment={'ASAN_OPTIONS': 'detect_leaks=0'})
        result = analyze.analyze(receipt)
        self.assertTrue(result['runtime_qualifications']['disable_leak_check'])
        self.assertEqual(result['runtime_qualifications']['leak_check']['status'], 'unexecuted')
        self.assertEqual(result['runtime_qualifications']['sanitizer_environment']['ASAN_OPTIONS'], 'detect_leaks=0')

    def test_missing_process_is_not_silently_dropped(self):
        receipt = self.receipt()
        receipt['cases'].pop()
        partial = analyze.analyze(receipt, allow_partial=True)
        self.assertEqual(partial['status'], 'UNQUALIFIED')
        self.assertEqual(partial['coverage']['registered_cases'], 2)
        self.assertEqual(partial['coverage']['unavailable_case_ids'], ['synthetic-w4'])
        self.assertTrue(any('process is missing' in error['reason'] for error in partial['errors']))

    def test_failed_process_kept_as_unavailable(self):
        receipt = self.receipt()
        receipt['cases'][1]['returncode'] = 1
        partial = analyze.analyze(receipt, allow_partial=True)
        self.assertEqual(partial['coverage']['unavailable_case_ids'], ['synthetic-w4'])
        self.assertTrue(any('failed native process' in error['reason'] for error in partial['errors']))

    def test_valid_hash_does_not_hide_malformed_scientific_field(self):
        receipt = self.receipt()
        self.rewrite(receipt, lambda rows: rows[1].update(mobility_draw=True))
        with self.assertRaisesRegex(analyze.AnalysisError, 'mobility_draw: expected integer'):
            analyze.analyze(receipt)
        partial = analyze.analyze(receipt, allow_partial=True)
        self.assertEqual(partial['coverage']['authenticated_scientific_case_facts'], 1)
        self.assertEqual(partial['coverage']['unavailable_case_ids'], ['synthetic-w1'])

    def test_scientific_summary_mismatch_is_retained(self):
        receipt = self.receipt()
        self.rewrite(receipt, lambda rows: rows[-1].update(selected_visits=99))
        with self.assertRaisesRegex(analyze.AnalysisError, 'summary selected_visits disagrees'):
            analyze.analyze(receipt)

    def test_actual_failed_draw_and_counterfactual_success_are_distinct(self):
        observation = facts(payload())['generic_mobility']
        self.assertEqual(observation['admitted_failed_draws']['count'], 3)
        self.assertEqual(observation['admitted_success_with_legal_side']['count'], 0)
        self.assertEqual(observation['unexecuted_prospective_success_bytes']['count'], 1)
        self.assertEqual(observation['unexecuted_prospective_success_bytes']['first_events'][0]['tick'], 4)
        self.assertEqual(observation['subject_moves'], 0)

    def test_actual_success_cannot_be_inferred_from_failed_draw(self):
        rows = payload()
        rows[1]['subject_moves'] = 1
        refresh_summary(rows)
        with self.assertRaisesRegex(analyze.AnalysisError, 'failed admitted mobility sample'):
            facts(rows)

    def test_blocked_cell_has_no_legal_prospective_success(self):
        rows = payload()
        rows[0]['variant'] = 'blocked'
        for row in rows[1:-1]:
            row['lateral_eligible'] = False
        result = facts(rows)
        self.assertEqual(result['generic_mobility']['unexecuted_prospective_success_bytes']['count'], 0)
        self.assertIsNone(result['first_subject_move'])

    def test_singleton_visit_witness_requires_three_rejections(self):
        rows = payload()
        rows[1]['down_all_rejections'] = 2
        with self.assertRaisesRegex(analyze.AnalysisError, 'one direct and two diagonal'):
            facts(rows)

    def test_dispatch_count_does_not_prove_configured_worker_participation(self):
        result = facts(payload(4))
        self.assertEqual(result['workers'], {'configured': 4, 'max_distinct_claimants_in_one_dispatch': 1,
                                           'ticks_observing_multiple_claimants': 0, 'max_jobs_in_one_phase': 1})
        rows = payload(4)
        rows[1]['worker_threads_observed'] = 5
        with self.assertRaisesRegex(analyze.AnalysisError, 'claimant count exceeds'):
            facts(rows)

    def test_pool_reset_is_representative_and_visits_remain_aggregate(self):
        rows = payload()
        rows[0].update(fixture='molten_pair', material=36, descriptor_viscosity=224, initial_state_a=7)
        for index, row in enumerate(rows[1:-1]):
            row.update(material_before=36, material=36, state_a_before=7 if index == 0 else 180,
                       state_a=180, hot_neighbor_before=True, rng_stream=127, mobility_threshold=32,
                       lateral_eligible=False, subject_count=2, kernel_visits=2, visited_cells=2,
                       down_rejections=2, down_all_rejections=6, scheduled_cores=1,
                       phase_jobs=[1, 0, 0, 0], worker_threads_observed=1)
        refresh_summary(rows)
        result = facts(rows)
        self.assertFalse(result['observational_scope']['single_subject_throughout'])
        self.assertEqual(result['work']['subject_kernel_visits'], 12)
        self.assertEqual(result['thermal']['representative_resets_from_7_to_180']['count'], 1)
        self.assertEqual(result['thermal']['hot_due_at_180_with_subject_work']['count'], 1)
        self.assertEqual(result['thermal']['cold_due_without_subject_visit']['count'], 0)
        self.assertIn('aggregate', result['thermal']['hot_due_counter_limit'])

    def test_singleton_cold_due_omission_requires_native_no_visit_and_no_job(self):
        rows = payload()
        rows[0].update(fixture='molten_short', material=36, descriptor_viscosity=224, initial_state_a=4)
        for row in rows[1:-1]:
            row.update(material_before=36, material=36, state_a_before=4, state_a=4,
                       rng_stream=127, mobility_threshold=32, lateral_eligible=False)
        result = facts(rows)
        self.assertEqual(result['thermal']['included_unmasked_cold_due']['count'], 2)
        self.assertEqual(result['thermal']['cold_due_with_subject_visit']['count'], 1)
        self.assertEqual(result['thermal']['cold_due_without_any_scheduled_job']['first_events'][0]['tick'], 5)
        rows[5]['source_masked'] = True
        self.assertEqual(facts(rows)['thermal']['cold_due_without_any_scheduled_job']['count'], 0)

    def test_scientific_comparison_uses_subject_tuple_not_configuration_hash(self):
        ordinary = facts(payload())
        awake, busy = copy.deepcopy(ordinary), copy.deepcopy(ordinary)
        awake['configuration']['quiet'] = 1024
        busy['configuration']['active_neighbour'] = True
        awake['final']['physical_hash'] = 'c' * 16
        busy['final']['physical_hash'] = 'd' * 16
        table = analyze.matched_table([ordinary, awake, busy], lambda _: True)
        self.assertTrue(table[0]['complete_three_arm_comparison'])
        self.assertTrue(table[0]['extended_and_active_neighbour_subject_trajectory_equal'])

    def test_time_quantiles_and_idle_ticks_are_descriptive(self):
        result = facts(payload())
        self.assertEqual(result['tick_cost']['all_native_ticks']['samples'], 6)
        self.assertEqual(result['tick_cost']['all_native_ticks']['p50_ns'], 103)
        self.assertEqual(result['tick_cost']['zero_job_native_ticks']['samples'], 3)
        self.assertEqual(analyze.quantiles([])['mean_ns'], None)
        self.assertIn('no future-fix overhead', result['tick_cost']['scope'])

    def test_world_tick_stall_is_not_an_unregistered_pause(self):
        rows = payload()
        rows[2]['world_tick'] = 1
        with self.assertRaisesRegex(analyze.AnalysisError, 'inconsistently with pause/reset'):
            facts(rows)

    def long_variant(self, variant):
        rows = payload()
        rows[0].update(variant=variant, horizon=18)
        rows = rows[:-1]
        for step in range(7, 19):
            row = copy.deepcopy(rows[-1])
            row.update(tick=step, world_tick=step, cooling_due=step % 4 == 1, tick_ns=100 + step)
            rows.append(row)
        return [*rows, summarize(rows)]

    def test_owner_pause_excludes_zero_cost_steps_and_preserves_world_tick(self):
        rows = self.long_variant('owner_pause')
        for row in rows[1:-1]:
            step = row['tick']
            row['paused'] = 9 <= step <= 16
            row['world_tick'] = step if step <= 8 else 8 if step <= 16 else step - 8
            row['cooling_due'] = not row['paused'] and row['world_tick'] % 4 == 1
            if row['paused']:
                row['tick_ns'] = 0
                row['wake_cause'] = 'owner_pause'
            if step == 17:
                row['wake_cause'] = 'owner_resume'
        refresh_summary(rows)
        result = facts(rows)
        self.assertEqual(result['work']['owner_pause_steps'], 8)
        self.assertEqual(result['tick_cost']['all_native_ticks']['samples'], 10)
        self.assertEqual(result['external_events'][-1]['world_tick'], 9)
        rows[9]['tick_ns'] = 1
        with self.assertRaisesRegex(analyze.AnalysisError, 'owner pause reports native execution'):
            facts(rows)

    def test_region_exclusion_is_not_a_missed_thermal_obligation(self):
        rows = self.long_variant('region')
        rows[0].update(fixture='molten_short', material=36, descriptor_viscosity=224, initial_state_a=4)
        for row in rows[1:-1]:
            row.update(material_before=36, material=36, state_a_before=4, state_a=4,
                       rng_stream=127, mobility_threshold=32, lateral_eligible=False)
        result = facts(rows)
        due = result['thermal']['included_unmasked_cold_due']
        self.assertEqual([event['tick'] for event in due['first_events']], [1, 5, 17])
        self.assertEqual(result['work']['native_ticks'], 18)

    def test_named_reentry_records_actual_visit_separately_from_edit_cause(self):
        rows = self.long_variant('region')
        rows[9]['wake_cause'] = 'region_exclude'
        rows[17].update(wake_cause='region_reenter', mobility_draw=200, kernel_visits=1,
                        visited_cells=1, down_rejections=1, down_all_rejections=3,
                        scheduled_cores=1, phase_jobs=[1, 0, 0, 0], worker_threads_observed=1)
        refresh_summary(rows)
        events = facts(rows)['external_events']
        self.assertEqual([(event['cause'], event['kernel_visits']) for event in events],
                         [('region_exclude', 0), ('region_reenter', 1)])

    def test_unobservable_protected_kernel_is_not_counted_as_no_visits(self):
        rows = payload()
        rows[0].update(fixture='water_cy', material=3, descriptor_viscosity=0)
        for row in rows[1:-1]:
            row.update(material_before=3, material=3, kernel_visits=None, mobility_threshold=256)
        refresh_summary(rows)
        result = facts(rows)
        self.assertFalse(result['work']['subject_kernel_visits_observable'])
        self.assertIsNone(result['work']['subject_kernel_visits'])
        self.assertNotIn('generic_mobility', result)

    def test_partial_cli_with_invalid_json_stays_unqualified(self):
        source = self.directory / 'invalid.json'
        output = self.directory / 'partial.json'
        source.write_text('{')
        code = analyze.main([str(source), '--output', str(output), '--allow-partial'])
        result = json.loads(output.read_text())
        self.assertEqual(code, 1)
        self.assertEqual(result['status'], 'UNQUALIFIED')
        self.assertTrue(result['errors'])
        self.assertFalse(result['independent_authentication_passed'])


if __name__ == '__main__':
    unittest.main()
