#!/usr/bin/env python3
"""Admission/readback adverse controls, not replacement engine observations."""
from copy import deepcopy
import io
import json
from pathlib import Path
import tarfile
import tempfile
import time
import unittest
from unittest.mock import patch

import run_paired_material_remediation as q


def fixture_log(name):
    if name in q.JSON_FOOTERS:
        return q.JSON_FOOTERS[name] + json.dumps({'checks': 3, 'failures': 0}) + '\n'
    if name in q.COUNT_FOOTERS:
        return q.COUNT_FOOTERS[name] + ': 3 assertions; 0 failures\n'
    if name == 'test_water_feel_controller':
        return 'WATER_FEEL_CONTROLLER: transactional rejection/body collision isolation/desktop+Web blind lifecycle passed\n'
    return 'WATER_FEEL_INTEGRATION: 24 policy cases + 70 scenario builds/reset/invalid/actions/RG8/authority passed default_hash=123\n'


def native_fixture_log():
    source = (q.ROOT / 'native/tests/test_paired_materials.cpp').read_text(encoding='utf-8')
    phases = q.re.findall(r'"PAIR_CURE phase=([^"\\]+)\\n"', source)
    workers = ''.join(f'PAIR_CURE worker-parity family={family} bits={bits} ticks=210 capsules=64 '
        f'curing_peak=4 curing_parallel_ticks=180 observed_histogram=0,0,0,0,210 trajectory_sha256={"a" * 64}\n'
        for family, bits in sorted(q.NATIVE_PROFILES))
    return ''.join('PAIR_CURE phase=' + phase + '\n' for phase in phases) + workers + 'PAIR_CURE_001 checks=55937 failures=0\n'


def process(case, report, log):
    return {'name': case['name'], 'role': q.ROLE, 'status': 'passed', 'returncode': 0,
            'natural_completion': True, 'execution_policy': q.policy.identity(),
            'timeout_seconds': case['timeout'], 'seconds': 1.0, 'requires_display': False,
            'command': q.c.expected_command(case, report), 'log': case['name'] + '.log',
            'log_sha256': q.hashlib.sha256(log.encode()).hexdigest(), 'pid': 12345}


class AdmissionTests(unittest.TestCase):
    def test_complete_two_host_scope_and_full_watchdogs(self):
        plan = q.hosted_plan()
        self.assertEqual(plan['max_parallel_hosts'], 2)
        self.assertEqual([host['platform'] for host in plan['hosts']], ['linux', 'win32'])
        for host in plan['hosts']:
            names = [case['name'] for case in host['cases']]
            self.assertEqual(names[:len(q.HEADLESS)], list(q.HEADLESS))
            rendered = [case for case in host['cases'] if case['rendered']]
            self.assertEqual([case['name'] for case in rendered], ['material-render'] if host['platform'] == 'linux' else [])
            self.assertLessEqual(host['budgets']['total_stage_minutes'], host['budgets']['job_minutes'])
            self.assertLessEqual(host['budgets']['suite_minutes'] * 60, q.scheduling.execution_seconds())
            self.assertEqual(host['budgets']['job_minutes'], 360)
            for case in host['cases']:
                self.assertGreaterEqual(case['timeout'], q.policy.watchdog_seconds('ordinary_case_seconds'))
        with self.assertRaises((ValueError, RuntimeError)):
            q.case_plan('darwin')

    def test_insufficient_remainder_refuses_without_shortening_case(self):
        plan = q.budgets('linux')
        case = q.case_plan('linux')[0]
        allowance = case['timeout'] + q.policy.watchdog_seconds('operation_seconds')
        required = q.scheduling.case_allowance(allowance) + plan['terminal_reserve_seconds']
        budget = q.scheduling.ExecutionBudget(plan['suite_minutes'] * 60,
            started=time.monotonic() - (plan['suite_minutes'] * 60 - required + 1))
        budget.terminal_reserve = plan['terminal_reserve_seconds']
        self.assertFalse(budget.admission(allowance)['admitted'])
        self.assertEqual(budget.admission(allowance)['required_seconds'], required)
        self.assertEqual(case, q.case_plan('linux')[0])

    def test_native_sanitizer_requires_leaks_and_exact_instrumentation(self):
        report = {'platform': 'linux', 'native_output_root': '/evidence/native',
                  'native_compiler': {'path': '/usr/bin/g++-13'}}
        normal = q.native_commands('normal', report)
        sanitized = q.native_commands('asan-ubsan', report)
        self.assertNotIn('-fsanitize=address,undefined', normal[0])
        self.assertIn('-fsanitize=address,undefined', sanitized[0])
        self.assertEqual(sanitized[1][:-1], ['env', 'ASAN_OPTIONS=detect_leaks=1:strict_string_checks=1',
                                           'UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1'])
        self.assertIn('native/tests/paired_materials_main.cpp', sanitized[0])
        with self.assertRaises((ValueError, RuntimeError)):
            q.native_commands('asan-ubsan', dict(report, platform='win32'))

    def test_untracked_source_refused_but_generated_uid_has_tracked_parent(self):
        with patch.object(q.palette, 'git', return_value=b'godot/tests/registered.gd.uid\0'):
            q.reject_untracked_inputs({'godot/tests/registered.gd'})
            with self.assertRaises((ValueError, RuntimeError)):
                q.reject_untracked_inputs(set())
        for name in ('godot/scripts/uncommitted.gd', 'tools/experiments/uncommitted.py', '.github/workflows/extra.yml'):
            with self.subTest(name=name), patch.object(q.palette, 'git', return_value=name.encode() + b'\0'):
                with self.assertRaises((ValueError, RuntimeError)):
                    q.reject_untracked_inputs(set())


class FooterTests(unittest.TestCase):
    def test_each_positive_footer_and_missing_duplicate_negative(self):
        for case in q.case_plan('win32'):
            log = fixture_log(case['name'])
            with self.subTest(case=case['name']):
                self.assertTrue(q.reduce_footer(case, log))
                for rejected in ('', log + log, log.replace('passed', 'failed').replace('0 failures', '1 failures').replace('"failures": 0', '"failures": 1')):
                    with self.assertRaises((ValueError, RuntimeError)):
                        q.reduce_footer(case, rejected)

    def test_zero_boolean_and_malformed_material_counts_refused(self):
        case = q.case_plan('win32')[0]
        for checks, failures in ((0, 0), (True, 0), (2, False), (2, 1), (-1, 0)):
            with self.subTest(checks=checks, failures=failures), self.assertRaises((ValueError, RuntimeError)):
                q.reduce_footer(case, q.JSON_FOOTERS[case['name']] + json.dumps({'checks': checks, 'failures': failures}))

    def test_strict_original_process_control_reused(self):
        case = q.case_plan('win32')[0]
        report = {'platform': 'win32', 'host_paths': {
            'source_root': 'C:\\source', 'project_root': 'C:\\source\\godot',
            'launcher': 'C:\\engine\\Godot_v4.7-stable_win64_console.exe',
            'engine': 'C:\\engine\\Godot_v4.7-stable_win64.exe'}}
        log = fixture_log(case['name'])
        original = process(case, report, log)
        q.verify_headless_process(original, case, log, report)
        changes = {'status': 'skipped', 'returncode': False, 'natural_completion': False,
                   'execution_policy': {}, 'timeout_seconds': case['timeout'] - 1,
                   'seconds': float('nan'), 'requires_display': True, 'capture_error': 'capture failed',
                   'diagnostic_error': True, 'skip_messages': ['skipped'], 'timeout_kind': 'wall',
                   'role': 'another task', 'name': 'another fixture', 'command': original['command'] + ['--quit']}
        for key, value in changes.items():
            with self.subTest(key=key), self.assertRaises((ValueError, RuntimeError)):
                q.verify_headless_process(dict(original, **{key: value}), case, log, report)
        for diagnostic in ('ERROR: retained failure', 'SCRIPT ERROR: bad script', 'SKIP no renderer', 'fixture skipped'):
            with self.subTest(diagnostic=diagnostic), self.assertRaises((ValueError, RuntimeError)):
                q.verify_headless_process(original, case, log + diagnostic, report)

    def test_native_completion_cannot_hide_leak_teardown_failure(self):
        source = (q.ROOT / 'native/tests/test_paired_materials.cpp').read_text(encoding='utf-8')
        phases = q.re.findall(r'"PAIR_CURE phase=([^"\\]+)\\n"', source)
        log = native_fixture_log()
        self.assertEqual(q.reduce_native_log(log)['checks'], 55937)
        for bad in (log + 'LeakSanitizer has encountered a fatal error\n',
                    log + 'AddressSanitizer: heap-use-after-free\n', log + 'runtime error: signed overflow\n',
                    log.replace('PAIR_CURE phase=' + phases[-1] + '\n', ''), log + log,
                    log.replace('family=4 bits=8', 'family=4 bits=3'),
                    log.replace('curing_peak=4', 'curing_peak=1'),
                    log.replace('observed_histogram=0,0,0,0,210', 'observed_histogram=0,0,0,0,209')):
            with self.subTest(bad=bad[-100:]), self.assertRaises((ValueError, RuntimeError)):
                q.reduce_native_log(bad)

    def test_normal_and_sanitized_trajectories_match_independent_of_worker_histograms(self):
        normal = {'checks': 55937, 'worker_parity': [
            {'family': family, 'bits': bits, 'trajectory_sha256': 'a' * 64, 'curing_peak': 4}
            for family, bits in sorted(q.NATIVE_PROFILES)]}
        sanitized = deepcopy(normal)
        sanitized['worker_parity'][0]['curing_peak'] = 3
        q.compare_native_runs([normal, sanitized])
        for change in ('hash', 'missing', 'count'):
            mutated = deepcopy(sanitized)
            if change == 'hash':
                mutated['worker_parity'][0]['trajectory_sha256'] = 'b' * 64
            elif change == 'missing':
                mutated['worker_parity'].pop()
            else:
                mutated['checks'] -= 1
            with self.subTest(change=change), self.assertRaises(ValueError):
                q.compare_native_runs([normal, mutated])


class RetainedEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name)
        self.source = 'a' * 40
        self.report = {'schema': q.SCHEMA, 'scope': q.SCOPE, 'source_commit': self.source,
            'platform': 'win32', 'status': 'passed', 'completed': True, 'errors': [], 'source_unchanged': True,
            'python_packages': dict(item.split('==') for item in q.c.PYTHON_PACKAGES),
            'case_plan': q.case_plan('win32'), 'budgets': q.budgets('win32'), 'rows': [], 'native_rows': [],
            'host_paths': {'source_root': 'C:\\source', 'project_root': 'C:\\source\\godot',
                'launcher': 'C:\\engine\\Godot_v4.7-stable_win64_console.exe',
                'engine': 'C:\\engine\\Godot_v4.7-stable_win64.exe'}}
        imported = {'name': 'import', 'rendered': False, 'timeout': q.policy.watchdog_seconds('godot_import_seconds')}
        self.report['import'] = process(imported, self.report, 'Godot import\n')
        self.report['import_log_sha256'] = self.report['import']['log_sha256']
        self.report['import_process_exited'] = True
        (self.directory / 'import.log').write_bytes(b'Godot import\n')
        q.c.write(self.directory / 'import-process.json', self.report['import'])
        for case in self.report['case_plan']:
            directory = self.directory / case['name']; directory.mkdir()
            log = fixture_log(case['name'])
            row = {'case': case, 'directory': case['name'], 'errors': [], 'known_processes_exited': True,
                   'process': process(case, self.report, log), 'readback': q.reduce_footer(case, log)}
            row['log_sha256'] = row['process']['log_sha256']
            (directory / (case['name'] + '.log')).write_bytes(log.encode())
            q.c.write(directory / 'process.json', row['process'])
            self.report['rows'].append(row)
        self.save()

    def tearDown(self):
        self.temp.cleanup()

    def save(self):
        q.c.write(self.directory / 'qualification.json', self.report)
        with q.palette.metadata_budget('synthetic unit artifact seal'):
            q.palette.seal(self.directory)

    def verify(self):
        # These unit receipts are synthetic. Source/runtime/archive verification
        # is deliberately not represented as an actual source-qualified run.
        with patch.object(q.palette, 'verify_source'), patch.object(q, 'verify_extra_source'):
            return q.verify_directory(self.directory, self.source)

    def test_complete_synthetic_cohort_reduces_and_missing_case_refuses(self):
        self.assertEqual(len(self.verify()['cases']), len(q.HEADLESS))
        self.report['rows'].pop(); self.save()
        with self.assertRaises((ValueError, RuntimeError)):
            self.verify()

    def test_failed_incomplete_changed_source_or_unretired_process_refuses(self):
        original = deepcopy(self.report)
        for key, value in [('status', 'failed'), ('completed', False), ('source_unchanged', False),
                           ('errors', ['retained historical failure']), ('import_process_exited', False)]:
            self.report = deepcopy(original); self.report[key] = value; self.save()
            with self.subTest(key=key), self.assertRaises((ValueError, RuntimeError)):
                self.verify()
        self.report = deepcopy(original)
        self.report['rows'][0]['known_processes_exited'] = False; self.save()
        with self.assertRaises((ValueError, RuntimeError)):
            self.verify()

    def test_resealed_wrong_receipt_log_or_readback_refuses(self):
        original = deepcopy(self.report)
        for alteration in ('readback', 'process', 'log', 'duplicate-case'):
            self.report = deepcopy(original)
            row = self.report['rows'][0]
            directory = self.directory / row['case']['name']
            log = fixture_log(row['case']['name'])
            (directory / row['process']['log']).write_bytes(log.encode())
            q.c.write(directory / 'process.json', row['process'])
            if alteration == 'readback':
                row['readback']['checks'] += 1
            elif alteration == 'process':
                q.c.write(directory / 'process.json', dict(row['process'], returncode=1))
            elif alteration == 'log':
                (directory / row['process']['log']).write_bytes((log + 'ERROR: actual retained failure\n').encode())
            else:
                self.report['rows'][-1] = deepcopy(row)
            self.save()
            with self.subTest(alteration=alteration), self.assertRaises((ValueError, RuntimeError)):
                self.verify()

    def test_added_removed_or_changed_sealed_member_refuses(self):
        path = self.directory / 'import.log'
        path.write_text('changed\n')
        with self.assertRaises((ValueError, RuntimeError)):
            self.verify()
        self.save()
        extra = self.directory / 'extra.bin'; extra.write_bytes(b'new')
        with self.assertRaises((ValueError, RuntimeError)):
            self.verify()
        extra.unlink(); path.unlink()
        with self.assertRaises((ValueError, RuntimeError)):
            self.verify()

    def test_extra_driver_source_and_native_inventory_must_match_archive(self):
        extra_name = 'tools/experiments/run_paired_material_remediation.py'
        data = b'# synthetic committed driver\n'
        inputs = {'native/src/world.cpp': '1' * 64}
        with tarfile.open(self.directory / 'executed-source.tar', 'w') as archive:
            for name, content in (('.gitattributes', b'* text=auto\n'), (extra_name, data),
                ('godot/addons/cybersand_native/runtime-provenance.json', json.dumps({'source_inputs': inputs}).encode())):
                member = tarfile.TarInfo(name); member.size = len(content)
                archive.addfile(member, io.BytesIO(content))
        value = {'platform': 'win32', 'source_inputs': dict.fromkeys(q.REQUIRED, ''),
                 'extra_source_inputs': {extra_name: q.hashlib.sha256(data).hexdigest()},
                 'native_source_inputs': inputs, 'native_source_input_count': len(inputs)}
        value['extra_source_inputs_after'] = dict(value['extra_source_inputs'])
        with q.palette.metadata_budget('synthetic source controls'), patch.object(q.windows, 'native_input_paths', return_value=set(inputs)):
            q.verify_extra_source(self.directory, value)
            for key, replacement in [('extra_source_inputs_after', {}), ('native_source_input_count', 19),
                                     ('native_source_inputs', {}), ('source_inputs', {})]:
                with self.subTest(key=key), self.assertRaises((ValueError, RuntimeError)):
                    q.verify_extra_source(self.directory, dict(value, **{key: replacement}))
            mutated = deepcopy(value)
            mutated['extra_source_inputs'][extra_name] = '0' * 64
            mutated['extra_source_inputs_after'] = dict(mutated['extra_source_inputs'])
            with self.assertRaises((ValueError, RuntimeError)):
                q.verify_extra_source(self.directory, mutated)

    def test_native_receipts_refuse_changed_source_failure_or_disabled_leaks(self):
        report = {'platform': 'linux', 'source_commit': self.source, 'source_tree': 'b' * 40,
                  'native_output_root': '/evidence/native', 'native_compiler': {'path': '/usr/bin/g++-13'}, 'native_rows': []}
        for mode in q.NATIVE_MODES:
            folder = self.directory / 'native' / mode
            folder.mkdir(parents=True)
            binary = folder / 'paired-materials'; binary.write_bytes(b'\x7fELFsynthetic readback control')
            row = {'mode': mode, 'completed': True, 'errors': [], 'commands': [],
                   'binary': {'sha256': q.c.sha(binary), 'bytes': binary.stat().st_size},
                   'readback': q.reduce_native_log(native_fixture_log())}
            for index, (phase, key) in enumerate((('compile', 'native_compile_seconds'), ('run', 'native_case_seconds'))):
                child = folder / phase; child.mkdir()
                log = child / 'command.log'
                log.write_bytes((native_fixture_log() if phase == 'run' else 'synthetic compiler receipt\n').encode())
                receipt = {'schema': 'execution-command-v1', 'label': 'paired-' + mode + '-' + phase,
                    'command': q.native_commands(mode, report)[index], 'complete': True, 'status': 'passed',
                    'returncode': 0, 'timed_out': False, 'natural_completion': True,
                    'execution_policy': q.policy.identity(), 'timeout_seconds': q.policy.watchdog_seconds(key),
                    'elapsed_seconds': 1.0, 'source': {'commit': self.source, 'tree': report['source_tree']},
                    'log_sha256': q.c.sha(log)}
                row['commands'].append(receipt); q.c.write(child / 'receipt.json', receipt)
            report['native_rows'].append(row)
        self.assertEqual(len(q.verify_native(self.directory, report)), 2)
        original = deepcopy(report)
        for alteration in ('source', 'exit', 'leaks', 'timeout', 'cleanup', 'binary'):
            changed = deepcopy(original)
            receipt = changed['native_rows'][1]['commands'][1]
            if alteration == 'source':
                receipt['source']['commit'] = 'c' * 40
            elif alteration == 'exit':
                receipt['returncode'] = 1
            elif alteration == 'leaks':
                receipt['command'][1] = 'ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1'
            elif alteration == 'timeout':
                receipt['timed_out'] = True
            elif alteration == 'cleanup':
                receipt['cleanup_error'] = 'surviving child'
            else:
                changed['native_rows'][1]['binary']['sha256'] = '0' * 64
            q.c.write(self.directory / 'native/asan-ubsan/run/receipt.json', receipt)
            with self.subTest(alteration=alteration), self.assertRaises(ValueError):
                q.verify_native(self.directory, changed)


if __name__ == '__main__':
    unittest.main()
