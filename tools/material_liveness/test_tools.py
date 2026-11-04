#!/usr/bin/env python3
"""Adversarial evidence tests; synthetic rows are never physical evidence."""
from __future__ import annotations

import copy
import errno
import io
import os
import stat
import json
from pathlib import Path
import tempfile
import sys
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import reduce as reader
import run as runner


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)

    def payload(self, workers):
        common = {'case_id': f'case-w{workers}', 'workers': workers, 'quiet': 3,
                  'fixture': 'isolated', 'x': 8, 'y': 8, 'horizon': 2,
                  'variant': 'base', 'active_neighbour': False}
        ticks = []
        for tick in (1, 2):
            ticks.append({'type': 'tick', 'tick': tick, 'world_tick': tick, 'reset_epoch': 0, 'wake_cause': 'none',
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

    def reset_case(self):
        receipt = self.receipt()
        for index, (result, plan) in enumerate(zip(receipt['cases'], receipt['plan']['cases'])):
            plan['argv'][plan['argv'].index('--ticks') + 1] = '18'
            plan['argv'][plan['argv'].index('--variant') + 1] = 'reset'
            result['argv'] = ['probe', *plan['argv']]
            def change(rows):
                metadata, summary = rows[0], rows[-1]
                metadata['horizon'] = 18
                metadata['variant'] = 'reset'
                ticks = []
                for step in range(1, 19):
                    row = dict(rows[1])
                    row.update(tick=step, world_tick=step if step < 17 else step - 16,
                               reset_epoch=0 if step < 17 else 1,
                               wake_cause='reset' if step == 17 else 'none', physical_hash=str(step))
                    ticks.append(row)
                summary['physical_hash'] = '18'
                rows[:] = [metadata, *ticks, summary]
            self.rewrite(receipt, change, index)
        receipt['plan_sha256'] = reader.canonical_sha(receipt['plan'])
        return receipt

    def test_dependency_parser_preserves_windows_drive_colons_and_separators(self):
        dep = r'C:\build\probe.obj: C:\src\native\src\world.cpp C:\Program\ Files\SDK\header.hpp' + '\n'
        self.assertEqual(runner.make_dependency_paths(dep), [r'C:\src\native\src\world.cpp', r'C:\Program Files\SDK\header.hpp'])
        escaped = r'C\:/build/probe.obj: C\:/src/native/src/world.cpp D\:/sdk/a.hpp' + '\n'
        self.assertEqual(runner.make_dependency_paths(escaped), ['C:/src/native/src/world.cpp', 'D:/sdk/a.hpp'])

    def test_dependency_parser_decodes_generated_spaces_hashes_and_dollars(self):
        dep = 'object.o: source.cpp path\\ with\\ space.hpp tag\\#value.hpp dollar$$name.hpp \\\n  second.hpp\n'
        self.assertEqual(runner.make_dependency_paths(dep),
                         ['source.cpp', 'path with space.hpp', 'tag#value.hpp', 'dollar$name.hpp', 'second.hpp'])

    def test_dependency_parser_retains_unescaped_windows_drive_target(self):
        dep = 'C:/build/object.obj: C:/src/world.cpp \\\r\n C:/include/a.hpp\r\n'
        self.assertEqual(runner.make_dependency_paths(dep), ['C:/src/world.cpp', 'C:/include/a.hpp'])

    def test_dependency_parser_rejects_missing_rules_and_empty_inputs(self):
        for dep in ('not a rule', 'empty.o:\n', '\0'):
            with self.assertRaises(runner.EvidenceError):
                runner.make_dependency_paths(dep)

    def test_actual_dependencies_resolve_from_compiler_directory_and_require_world(self):
        root, build = self.directory / 'repo', self.directory / 'build'
        world = root / 'native/src/world.cpp'
        world.parent.mkdir(parents=True)
        world.write_text('test-only bytes')
        build.mkdir()
        dep = build / 'input.d'
        dep.write_text('object.o: ../repo/native/src/world.cpp\n')
        inventory = runner.actual_dependencies(root, [dep], build)
        self.assertEqual(inventory[0]['path'], 'native/src/world.cpp')
        another = root / 'other.hpp'
        another.write_text('header')
        dep.write_text('object.o: ../repo/other.hpp\n')
        with self.assertRaisesRegex(runner.EvidenceError, 'does not contain actual'):
            runner.actual_dependencies(root, [dep], build)
        dep.write_text('object.o: ../repo/missing.hpp\n')
        with self.assertRaisesRegex(runner.EvidenceError, 'unavailable or misparsed'):
            runner.actual_dependencies(root, [dep], build)

    def test_windows_flags_use_explicit_cxx_exceptions_without_posix_threads(self):
        windows = runner.compiler_flags('normal', 'nt')
        linux = runner.compiler_flags('normal', 'posix')
        self.assertNotIn('-pthread', windows)
        self.assertIn('-fexceptions', windows)
        self.assertIn('-fcxx-exceptions', windows)
        self.assertIn('-pthread', linux)
        self.assertIn('-O2', windows)
        self.assertIn('-O2', linux)

    def test_current_committed_manifest_loads_without_executing(self):
        path = runner.ROOT / 'native/tests/fixtures/material_liveness_campaign_v1.json'
        manifest = runner.load_json(path)
        cases = runner.validate_plan(manifest)
        self.assertEqual(len(cases), 552)
        self.assertEqual(sum(row['ticks'] for row in cases), 88384)
        self.assertTrue(all(row['expected_workers'] == row['workers'] for row in cases))
        self.assertTrue(all(row['parity_group'] == reader.physical_group(row) for row in cases))
        self.assertEqual(cases[0]['parity_group'], cases[1]['parity_group'])
        self.assertNotEqual(cases[0]['parity_group'], cases[2]['parity_group'])
        repeated = [row for row in cases if row['repeat'] == 1]
        self.assertTrue(repeated)
        for repeat in repeated:
            matches = [row for row in cases if row['parity_group'] == repeat['parity_group'] and row['repeat'] == 0]
            self.assertTrue(matches)
        self.assertNotIn('expected_workers', manifest['cases'][0], 'normalization must not rewrite the registration')

    def test_worker_aliases_cannot_disagree(self):
        with self.assertRaisesRegex(runner.EvidenceError, 'aliases disagree'):
            runner.validate_plan({'schema': 'mat354.campaign.v1', 'cases': [
                {'id': 'one', 'argv': ['--workers', '1'], 'workers': 1, 'expected_workers': 4}]})

    def test_case_metadata_cannot_disagree_with_invocation(self):
        with self.assertRaisesRegex(runner.EvidenceError, 'differs from its argv'):
            runner.validate_plan({'schema': 'mat354.campaign.v1', 'cases': [
                {'id': 'one', 'argv': ['--workers', '4'], 'workers': 1}]})

    def test_registration_budgets_are_inherited_and_cannot_be_extended(self):
        plan = runner.load_json(runner.ROOT / 'native/tests/fixtures/material_liveness_campaign_v1.json')
        args = SimpleNamespace(compile_timeout=None, case_timeout=None, campaign_timeout=None)
        self.assertEqual(runner.time_budgets(plan, args), {'build': 900, 'case': 60, 'campaign': 1800})
        args.case_timeout = 61
        with self.assertRaisesRegex(runner.EvidenceError, 'cannot exceed'):
            runner.time_budgets(plan, args)
        args.case_timeout = 30
        self.assertEqual(runner.time_budgets(plan, args)['case'], 30)
        with self.assertRaises(runner.EvidenceError):
            runner.time_budgets({**plan, 'build_timeout_seconds': True}, args)

    def test_build_steps_share_one_decreasing_budget(self):
        with patch.object(runner.time, 'monotonic', return_value=100):
            self.assertEqual(runner.remaining_budget(900, 1800), 800)
        with patch.object(runner.time, 'monotonic', return_value=899):
            self.assertEqual(runner.remaining_budget(900, 1800), 1)
        with patch.object(runner.time, 'monotonic', return_value=900):
            with self.assertRaisesRegex(runner.EvidenceError, 'exhausted'):
                runner.remaining_budget(900, 1800)

    def test_reset_epoch_authorizes_only_registered_step17_reconstruction(self):
        result = reader.reduce(self.reset_case())
        self.assertEqual(result['cases'][0]['reset_events'], [{'step': 17, 'reset_epoch': 1, 'world_tick': 1}])
        self.assertTrue(result['parity'][0]['matching'])

    def test_world_tick_regression_without_epoch_fails(self):
        receipt = self.receipt()
        self.rewrite(receipt, lambda rows: rows[2].update(world_tick=0))
        with self.assertRaisesRegex(reader.ReductionError, 'regressed'):
            reader.reduce(receipt)

    def test_reset_epoch_without_reset_cause_fails(self):
        receipt = self.reset_case()
        self.rewrite(receipt, lambda rows: rows[17].update(wake_cause='none'))
        with self.assertRaisesRegex(reader.ReductionError, 'invalid or unregistered reset'):
            reader.reduce(receipt)

    def test_skipped_reset_epoch_fails(self):
        receipt = self.reset_case()
        self.rewrite(receipt, lambda rows: rows[17].update(reset_epoch=2))
        with self.assertRaisesRegex(reader.ReductionError, 'invalid or unregistered reset'):
            reader.reduce(receipt)

    def test_reset_at_unregistered_step_fails(self):
        receipt = self.reset_case()
        self.rewrite(receipt, lambda rows: rows[16].update(reset_epoch=1, world_tick=1, wake_cause='reset'))
        with self.assertRaisesRegex(reader.ReductionError, 'invalid or unregistered reset'):
            reader.reduce(receipt)

    def test_reset_cause_without_epoch_increment_fails(self):
        receipt = self.receipt()
        self.rewrite(receipt, lambda rows: rows[1].update(wake_cause='reset'))
        with self.assertRaisesRegex(reader.ReductionError, 'lacks an epoch'):
            reader.reduce(receipt)

    def test_owner_pause_does_not_require_world_tick_advance(self):
        receipt = self.receipt()
        for index in (0, 1):
            self.rewrite(receipt, lambda rows: rows[2].update(world_tick=1), index)
        self.assertEqual(reader.reduce(receipt)['status'], 'PASS')

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

    def test_raw_files_are_private_until_complete_fsynced_publication(self):
        prefix = self.directory / 'atomic'
        final_stdout = self.directory / 'atomic.stdout'
        final_stderr = self.directory / 'atomic.stderr'
        def child(*arguments, **kwargs):
            self.assertFalse(final_stdout.exists())
            self.assertFalse(final_stderr.exists())
            self.assertTrue(str(kwargs['stdout'].name).endswith('.partial'))
            self.assertTrue(str(kwargs['stderr'].name).endswith('.partial'))
            self.assertNotEqual(kwargs['stdout'].name, kwargs['stderr'].name)
            kwargs['stdout'].write(b'complete stdout\n')
            kwargs['stderr'].write(b'complete stderr\n')
            return SimpleNamespace(wait=lambda timeout: 0)
        with patch.object(runner.subprocess, 'Popen', side_effect=child), patch.object(runner.os, 'fsync', wraps=os.fsync) as fsync:
            result = runner.process(['fixture'], self.directory, prefix, 5)
        self.assertGreaterEqual(fsync.call_count, 2)
        self.assertEqual(final_stdout.read_bytes(), b'complete stdout\n')
        self.assertEqual(final_stderr.read_bytes(), b'complete stderr\n')
        self.assertTrue(result['output_publication']['flushed_and_fsynced_before_publication'])
        self.assertFalse(list(self.directory.glob('*.partial')))
        self.assertFalse(list(self.directory.glob('.*.partial')))
        self.assertEqual(runner.verify_retained_outputs([result])['files'], 2)

    def test_existing_raw_output_refused_before_spawn(self):
        prior = self.directory / 'existing.stdout'
        prior.write_bytes(b'preserved historical output')
        with patch.object(runner.subprocess, 'Popen') as spawn:
            with self.assertRaisesRegex(runner.EvidenceError, 'refusing overwrite'):
                runner.process(['fixture'], self.directory, self.directory / 'existing', 5)
        spawn.assert_not_called()
        self.assertEqual(prior.read_bytes(), b'preserved historical output')
        self.assertFalse((self.directory / 'existing.stderr').exists())

    def test_atomic_publish_refuses_a_late_existing_destination(self):
        temporary = self.directory / 'temp.partial'
        final = self.directory / 'prior.stdout'
        temporary.write_bytes(b'new output')
        final.write_bytes(b'original')
        with self.assertRaises(FileExistsError):
            runner.publish_no_replace(temporary, final)
        self.assertEqual(final.read_bytes(), b'original')
        self.assertEqual(temporary.read_bytes(), b'new output')

    def test_final_raw_verification_detects_later_equal_size_corruption(self):
        result = runner.process([sys.executable, '-c', 'print("sample")'], self.directory,
                                self.directory / 'checked', 5)
        runner.verify_retained_outputs([result])
        Path(result['stdout']['path']).write_bytes(b'broken\n')
        with self.assertRaisesRegex(runner.EvidenceError, 'retained raw identity mismatch'):
            runner.verify_retained_outputs([result])

    @unittest.skipUnless(os.name == 'posix', 'POSIX permission-bit restoration')
    def test_unchanged_owned_generated_binary_recovers_only_owner_execute(self):
        executable = self.directory / 'generated'
        executable.write_bytes(b'verified generated bytes')
        executable.chmod(0o644)
        expected = runner.fact(executable)
        repair = runner.restore_generated_executable(executable, expected, self.directory)
        self.assertEqual(repair['kind'], 'artifact-mode-repair')
        self.assertEqual(repair['before_mode'], '0o644')
        self.assertEqual(repair['after_mode'], '0o744')
        self.assertEqual(stat.S_IMODE(executable.stat().st_mode), 0o744)
        self.assertEqual(runner.fact(executable), expected)

    @unittest.skipUnless(os.name == 'posix', 'POSIX executable fixture')
    def test_generated_mode_repair_is_recorded_in_the_invocation_receipt(self):
        executable = self.directory / 'generated-script'
        executable.write_text('#!/bin/sh\nprintf "fixture output\\n"\n')
        executable.chmod(0o644)
        expected = runner.fact(executable)
        result = runner.process([str(executable)], self.directory, self.directory / 'repaired-run', 5,
                                generated_executable=expected, artifact_directory=self.directory)
        self.assertEqual(result['returncode'], 0)
        self.assertEqual(result['artifact_mode_repair']['kind'], 'artifact-mode-repair')
        self.assertEqual(Path(result['stdout']['path']).read_bytes(), b'fixture output\n')
        self.assertEqual(runner.fact(executable), expected)

    @unittest.skipUnless(os.name == 'posix', 'POSIX permission-bit restoration')
    def test_changed_binary_is_not_chmod_repaired(self):
        executable = self.directory / 'changed'
        executable.write_bytes(b'original')
        executable.chmod(0o644)
        expected = runner.fact(executable)
        executable.write_bytes(b'modified')
        with patch.object(runner.os, 'fchmod') as chmod:
            with self.assertRaisesRegex(runner.EvidenceError, 'identity mismatch'):
                runner.restore_generated_executable(executable, expected, self.directory)
        chmod.assert_not_called()
        self.assertEqual(stat.S_IMODE(executable.stat().st_mode), 0o644)

    @unittest.skipUnless(os.name == 'posix', 'POSIX permission-bit restoration')
    def test_any_existing_execute_bit_prevents_mode_broadening(self):
        executable = self.directory / 'already-executable'
        executable.write_bytes(b'verified')
        executable.chmod(0o655)
        with patch.object(runner.os, 'fchmod') as chmod:
            self.assertIsNone(runner.restore_generated_executable(executable, runner.fact(executable), self.directory))
        chmod.assert_not_called()
        self.assertEqual(stat.S_IMODE(executable.stat().st_mode), 0o655)

    @unittest.skipUnless(os.name == 'posix', 'POSIX permission-bit restoration')
    def test_access_denial_on_executable_is_preserved_without_retry_or_chmod(self):
        executable = self.directory / 'denied'
        executable.write_bytes(b'verified')
        executable.chmod(0o755)
        expected = runner.fact(executable)
        with patch.object(runner.subprocess, 'Popen', side_effect=PermissionError(errno.EACCES, 'denied')) as spawn, patch.object(runner.os, 'fchmod') as chmod:
            result = runner.process([str(executable)], self.directory, self.directory / 'denied-run', 5,
                                    generated_executable=expected, artifact_directory=self.directory)
        self.assertEqual(spawn.call_count, 1)
        chmod.assert_not_called()
        self.assertIsNone(result['returncode'])
        self.assertIn('denied', result['spawn_error'])
        self.assertNotIn('artifact_mode_repair', result)
        self.assertEqual(stat.S_IMODE(executable.stat().st_mode), 0o755)

    def test_mode_repair_cannot_target_another_directory(self):
        executable = self.directory / 'outside'
        executable.write_bytes(b'verified')
        with self.assertRaisesRegex(runner.EvidenceError, 'limited to this build output'):
            runner.restore_generated_executable(executable, runner.fact(executable), self.directory / 'different')

    def test_disable_leaks_is_explicit_asan_only_and_marked_unexecuted(self):
        environment, recorded, leak = runner.sanitizer_configuration('asan-ubsan', True,
            {'ASAN_OPTIONS': 'halt_on_error=1:detect_leaks=1:allocator_may_return_null=0'})
        self.assertIn('detect_leaks=0', environment['ASAN_OPTIONS'])
        self.assertNotIn('detect_leaks=1', environment['ASAN_OPTIONS'])
        self.assertIn('allocator_may_return_null=0', environment['ASAN_OPTIONS'])
        self.assertEqual(recorded['ASAN_OPTIONS'], environment['ASAN_OPTIONS'])
        self.assertEqual(leak['status'], 'unexecuted')
        for mode in ('normal', 'tsan'):
            with self.assertRaisesRegex(runner.EvidenceError, 'only with --mode asan-ubsan'):
                runner.sanitizer_configuration(mode, True, {})

    def test_implicit_environment_leak_disable_is_refused(self):
        with self.assertRaisesRegex(runner.EvidenceError, 'requires explicit'):
            runner.sanitizer_configuration('asan-ubsan', False, {'ASAN_OPTIONS': 'detect_leaks=0'})
        environment, _, leak = runner.sanitizer_configuration('asan-ubsan', False, {})
        self.assertIn('detect_leaks=1', environment['ASAN_OPTIONS'])
        self.assertEqual(leak['status'], 'requested')

    def test_nonasan_cli_flag_is_rejected_before_run(self):
        with patch.object(runner, 'run') as execute, patch('sys.stderr', new_callable=io.StringIO):
            with self.assertRaises(SystemExit) as raised:
                runner.main(['--mode', 'normal', '--disable-leak-check', '--plan', 'manifest.json', '--output', 'output'])
        self.assertEqual(raised.exception.code, 2)
        execute.assert_not_called()

    def test_reduction_carries_unexecuted_leak_limit(self):
        receipt = self.receipt()
        receipt.update(mode='asan-ubsan', disable_leak_check=True,
                       sanitizer_environment={'ASAN_OPTIONS': 'halt_on_error=1:detect_leaks=0'},
                       leak_check={'status': 'unexecuted', 'reason': 'explicit --disable-leak-check'})
        result = reader.reduce(receipt)
        self.assertTrue(result['disable_leak_check'])
        self.assertEqual(result['leak_check']['status'], 'unexecuted')
        self.assertTrue(any('leak checking is unexecuted' in item for item in result['limits']))
        receipt['mode'] = 'normal'
        with self.assertRaisesRegex(reader.ReductionError, 'inconsistent mode'):
            reader.reduce(receipt)

    def test_dotted_case_ids_preserve_distinct_outputs(self):
        result = runner.process([sys.executable, '-c', 'print("sample")'], self.directory,
                                self.directory / 'case.one', 5)
        self.assertEqual(Path(result['stdout']['path']).name, 'case.one.stdout')


if __name__ == '__main__':
    unittest.main()
