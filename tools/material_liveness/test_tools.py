#!/usr/bin/env python3
"""Adversarial evidence tests; synthetic rows are never physical evidence."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
import sys
import unittest

import reduce as reader
import run as runner


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)

    def payload(self, workers):
        common = {'case_id': 'isolated:q3:x8:y8', 'workers': workers, 'quiet': 3,
                  'fixture': 'isolated', 'x': 8, 'y': 8, 'horizon': 2,
                  'variant': 'base', 'active_neighbour': False}
        ticks = []
        for tick in (1, 2):
            ticks.append({'type': 'tick', 'tick': tick, 'world_tick': tick,
                          'has_failed': False, 'quantity_ok': True,
                          'worker_threads_observed': 1, 'phase_jobs': [1, 0, 0, 0],
                          'visited_cells': 1, 'scheduled_cores': 1, 'active_blocks_after': 1,
                          'kernel_visits': 1, 'material': 36, 'state_a': 180, 'state_b': 0,
                          'temperature': 20, 'physical_hash': str(tick), 'state_hash': str(tick)})
        return [{'type': 'metadata', **common}, *ticks,
                {'type': 'summary', 'case_id': common['case_id'], 'has_failed': False,
                 'quantity_ok': True, 'physical_hash': '2'}]

    def receipt(self):
        cases, plans = [], []
        for workers in (1, 4):
            name = f'case-w{workers}'
            argv = ['--workers', str(workers), '--ticks', '2', '--quiet', '3', '--fixture', 'isolated',
                    '--x', '8', '--y', '8', '--variant', 'base', '--active-neighbour', '0']
            stdout = self.directory / (name + '.stdout')
            stderr = self.directory / (name + '.stderr')
            stdout.write_text(''.join(json.dumps(row) + '\n' for row in self.payload(workers)))
            stderr.write_text('')
            plans.append({'id': name, 'argv': argv, 'parity_group': 'same', 'expected_workers': workers})
            cases.append({'id': name, 'argv': ['probe', *argv], 'timed_out': False, 'returncode': 0,
                          'stdout': runner.fact(stdout), 'stderr': runner.fact(stderr)})
        inventory = [{'path': name, 'bytes': 1, 'sha256': '0' * 64} for name in
                     ('native/src/world.cpp', 'native/tests/material_liveness_probe.cpp')]
        plan = {'schema': 'mat354.plan.v1', 'cases': plans}
        guard = {'status': 'PASS', 'protected_sources': 27, 'production_cutover': False}
        return {'schema': 'mat354.campaign.v1', 'status': 'EXECUTED', 'source_qualified': True,
                'source_commit': 'a' * 40, 'source_tree': 'b' * 40, 'mode': 'normal', 'host': {},
                'executable': {'sha256': 'c' * 64}, 'protected_source_guard': guard, 'post_run_guard': guard,
                'compiled_input_inventory': inventory, 'input_inventory_sha256': reader.canonical_sha(inventory),
                'plan': plan, 'plan_sha256': reader.canonical_sha(plan), 'cases': cases}

    def rewrite(self, receipt, mutate, index=0):
        record = receipt['cases'][index]
        path = Path(record['stdout']['path'])
        rows = reader.read_rows(path.read_bytes())
        mutate(rows)
        path.write_text(''.join(json.dumps(row) + '\n' for row in rows))
        record['stdout'] = runner.fact(path)

    def test_complete_evidence_parity_and_actual_workers(self):
        result = reader.reduce(self.receipt())
        self.assertEqual(result['status'], 'PASS')
        self.assertTrue(result['parity'][0]['one_four_comparison'])
        self.assertEqual(result['cases'][1]['workers_configured'], 4)
        self.assertEqual(result['cases'][1]['workers_observed_max'], 1)
        self.assertEqual(result['cases'][0]['totals']['kernel_visits'], 2)

    def test_corrupted_raw_hash_fails(self):
        receipt = self.receipt()
        Path(receipt['cases'][0]['stdout']['path']).write_text('{}\n')
        with self.assertRaisesRegex(reader.ReductionError, 'raw identity'):
            reader.reduce(receipt)

    def test_missing_tick_is_not_success(self):
        receipt = self.receipt()
        self.rewrite(receipt, lambda rows: rows.pop(1))
        with self.assertRaisesRegex(reader.ReductionError, 'tick coverage'):
            reader.reduce(receipt)

    def test_no_final_summary_is_not_success(self):
        receipt = self.receipt()
        self.rewrite(receipt, lambda rows: rows.pop())
        with self.assertRaisesRegex(reader.ReductionError, 'metadata, tick rows, summary'):
            reader.reduce(receipt)

    def test_accounting_failure_stops_reduction(self):
        receipt = self.receipt()
        self.rewrite(receipt, lambda rows: rows[1].update(quantity_ok=False))
        with self.assertRaisesRegex(reader.ReductionError, 'health/accounting'):
            reader.reduce(receipt)

    def test_health_failure_stops_reduction(self):
        receipt = self.receipt()
        self.rewrite(receipt, lambda rows: rows[1].update(has_failed=True))
        with self.assertRaisesRegex(reader.ReductionError, 'health/accounting'):
            reader.reduce(receipt)

    def test_boolean_in_integer_field_is_rejected(self):
        receipt = self.receipt()
        self.rewrite(receipt, lambda rows: rows[1].update(worker_threads_observed=True))
        with self.assertRaisesRegex(reader.ReductionError, 'must be integer'):
            reader.reduce(receipt)

    def test_integer_in_boolean_field_is_rejected(self):
        receipt = self.receipt()
        self.rewrite(receipt, lambda rows: rows[1].update(quantity_ok=1))
        with self.assertRaisesRegex(reader.ReductionError, 'must be boolean'):
            reader.reduce(receipt)

    def test_excess_worker_claim_is_rejected(self):
        receipt = self.receipt()
        self.rewrite(receipt, lambda rows: rows[1].update(worker_threads_observed=4))
        with self.assertRaisesRegex(reader.ReductionError, 'exceeds configuration'):
            reader.reduce(receipt)

    def test_parity_failure_cannot_hide_in_final_hash(self):
        receipt = self.receipt()
        self.rewrite(receipt, lambda rows: rows[1].update(physical_hash='different'), 1)
        with self.assertRaisesRegex(reader.ReductionError, 'parity violation'):
            reader.reduce(receipt)

    def test_source_inventory_mutation_is_rejected(self):
        receipt = self.receipt()
        receipt['compiled_input_inventory'][0]['bytes'] = 2
        with self.assertRaisesRegex(reader.ReductionError, 'inventory digest mismatch'):
            reader.reduce(receipt)

    def test_unregistered_arguments_are_rejected(self):
        receipt = self.receipt()
        receipt['cases'][0]['argv'][-1] = '1'
        with self.assertRaisesRegex(reader.ReductionError, 'arguments differ'):
            reader.reduce(receipt)

    def test_missing_process_is_rejected(self):
        receipt = self.receipt()
        receipt['cases'].pop()
        with self.assertRaisesRegex(reader.ReductionError, 'missing or extra'):
            reader.reduce(receipt)

    def test_dirty_run_cannot_be_qualified(self):
        receipt = self.receipt()
        receipt['source_qualified'] = False
        with self.assertRaisesRegex(reader.ReductionError, 'dirty-apparatus'):
            reader.reduce(receipt)

    def test_duplicate_json_and_nonfinite_values_are_rejected(self):
        for content in ('{"x":1,"x":2}', '{"x":NaN}', '{"x":Infinity}'):
            with self.assertRaises(reader.ReductionError):
                reader.decode(content)

    def test_plan_refuses_duplicate_and_artifact_aliases(self):
        valid = {'schema': 'mat354.plan.v1', 'cases': [{'id': 'one', 'argv': []}]}
        for cases in ([{'id': '../overwrite', 'argv': []}], [{'id': 'compiler-version', 'argv': []}],
                      [{'id': 'compile-00', 'argv': []}], valid['cases'] * 2):
            with self.assertRaises(runner.EvidenceError):
                runner.validate_plan({**valid, 'cases': cases})

    def test_output_cannot_overwrite_checkout_or_previous_attempt(self):
        checkout = self.directory / 'checkout'
        checkout.mkdir()
        with self.assertRaises(runner.EvidenceError):
            runner.output_directory(checkout / 'build', checkout)
        output = self.directory / 'output'
        output.mkdir()
        (output / 'earlier.json').write_text('{}')
        with self.assertRaises(runner.EvidenceError):
            runner.output_directory(output, checkout)

    def test_dotted_case_ids_preserve_distinct_outputs(self):
        result = runner.process([sys.executable, '-c', 'print("sample")'], self.directory,
                                self.directory / 'case.one', 5)
        self.assertEqual(Path(result['stdout']['path']).name, 'case.one.stdout')


if __name__ == '__main__':
    unittest.main()
