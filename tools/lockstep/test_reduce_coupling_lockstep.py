#!/usr/bin/env python3
"""Negative regressions for the COUPLING-LOCKSTEP-001 v2 reducer.

Builds synthetic registered runs in a temporary tree and checks that the
reducer compares every recorded field (including the applied serial) and
refuses to decide on corrupted, missing, incomplete or inconsistent evidence.
"""
import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import reduce_coupling_lockstep as reducer  # noqa: E402

COMMIT = 'a' * 40
SOURCES = {path: ('source of %s\n' % path).encode() for path in reducer.IDENTITY_FILES.values()}


def show(commit, path):
    return SOURCES.get(path) if commit == COMMIT else None


def sha(data):
    return hashlib.sha256(data).hexdigest()


def episode(arm, workers, ticks, serial_offset=0):
    fenced = arm.startswith('lockstep')
    steps = []
    for index in range(ticks - 1):
        steps.append(dict(tick=index + 1, serial=index + 10 + serial_offset, publication=index + 1,
                          states='00ff', results='0a0b', pre='%04x' % index, post='%04x' % (index + 1), character='00'))
    return dict(registration='COUPLING-LOCKSTEP-001', ok=True, mode=arm, workers=workers, ticks=ticks,
                completed_ticks=ticks, native_delay_usec=0, platform='Windows', engine='4.7-stable (official)',
                wall_usec=10_000_000, physics_frames=ticks + 5, rapier_steps=ticks - 1, held_frames=3,
                age_histogram=[ticks, 0, 0], worker_overruns=0, native_worker_threads=workers,
                lockstep=dict(enabled=fenced, ticks=ticks if fenced else 0, holds=1, hold_usec_total=10,
                              hold_usec_max=10, timeouts=0, hold_timeout_usec=250000),
                initial_bits='00aa', final_bits='00bb', state_hash='1234', final_physical_hash='5678',
                tick_hashes=[''] + ['%016x' % t for t in range(1, ticks + 1)], steps=steps)


class Run:
    """A synthetic registered load-0 run: windows, workers 4, async+lockstep, 2 repeats."""

    def __init__(self, base, run='load-0'):
        self.base, self.run = Path(base), run
        registration = json.loads(reducer.REGISTRATION.read_text(encoding='utf-8'))
        self.expected = reducer.registered_matrix(run, registration)
        self.folder = self.base / 'build/coupling-lockstep' / run
        self.receipt = dict(identity=dict(source_commit=COMMIT, **{k: sha(SOURCES[p]) for k, p in reducer.IDENTITY_FILES.items()}),
                            matrix={}, episodes=[], post_source_equality=True)
        for host in self.expected['hosts']:
            for repeat in range(self.expected['repeats']):
                for workers in self.expected['workers']:
                    for arm in self.expected['arms']:
                        self.write(host, arm, workers, repeat, episode(arm, workers, self.expected['ticks']))

    def write(self, host, arm, workers, repeat, data, log=b'COUPLING_LOCKSTEP {"ok":true}\n'):
        folder = self.folder / host / ('%s-w%d-r%d' % (arm, workers, repeat))
        folder.mkdir(parents=True, exist_ok=True)
        result = folder / ('%s-w%d.json' % (arm, workers))
        result.write_text(json.dumps(data), encoding='utf-8')
        (folder / 'godot.log').write_bytes(log)
        row = dict(host=host, arm=arm, workers=workers, ticks=self.expected['ticks'], delay_usec=0, exit=0, seconds=11.0,
                   clean=True, log_sha256=sha(log), result=str(result.relative_to(self.base)),
                   result_sha256=sha(result.read_bytes()), repeat=repeat)
        self.receipt['episodes'] = [r for r in self.receipt['episodes']
                                    if (r['host'], r['arm'], r['workers'], r['repeat']) != (host, arm, workers, repeat)]
        self.receipt['episodes'].append(row)
        return row

    def row(self, arm, repeat):
        return next(r for r in self.receipt['episodes'] if r['arm'] == arm and r['repeat'] == repeat)

    def reduce(self):
        (self.folder / 'receipt.json').write_text(json.dumps(self.receipt), encoding='utf-8')
        return reducer.reduce(self.run, show=show, base=self.base)


class ReducerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.run = Run(self.tmp.name)
        self.ticks = self.run.expected['ticks']

    def tearDown(self):
        self.tmp.cleanup()

    def assertInvalid(self, out, fragment):
        self.assertFalse(out['validation']['valid'])
        self.assertIsNone(out['decisions'])
        self.assertTrue(any(fragment in e for e in out['validation']['errors']), out['validation']['errors'])

    def test_valid_baseline_decides(self):
        out = self.run.reduce()
        self.assertTrue(out['validation']['valid'], out['validation']['errors'])
        self.assertTrue(out['decisions']['a_lockstep_repeatable']['windows/lockstep'])
        self.assertTrue(out['decisions']['final_hashes_compared'])

    def test_serial_only_difference_is_detected(self):
        self.assertIn('serial', reducer.STEP_FIELDS)
        self.run.write('windows', 'lockstep', 4, 1, episode('lockstep', 4, self.ticks, serial_offset=1000))
        out = self.run.reduce()
        self.assertTrue(out['validation']['valid'], out['validation']['errors'])
        self.assertFalse(out['decisions']['a_lockstep_repeatable']['windows/lockstep'])
        detail = out['repeatability']['windows/lockstep/w4']['detail'][0]
        self.assertEqual((detail['step'], detail['fields'], detail['kind']), (0, ['serial'], 'RACE'))

    def test_corrupted_result_bytes_refused(self):
        path = self.run.base / self.run.row('lockstep', 1)['result']
        path.write_text(path.read_text(encoding='utf-8').replace('"00bb"', '"00bc"'), encoding='utf-8')
        self.assertInvalid(self.run.reduce(), 'result sha256 mismatch')

    def test_corrupted_log_refused(self):
        self.run.write('windows', 'lockstep', 4, 1, episode('lockstep', 4, self.ticks), log=b'SCRIPT ERROR\n')
        self.assertInvalid(self.run.reduce(), 'log lacks a clean COUPLING_LOCKSTEP report')

    def test_missing_repeat_refused(self):
        self.run.receipt['episodes'].remove(self.run.row('lockstep', 1))
        self.assertInvalid(self.run.reduce(), "missing episode ('windows', 'lockstep', 4, 1)")

    def test_empty_group_refused_without_exception(self):
        for repeat in (0, 1):
            self.run.receipt['episodes'].remove(self.run.row('lockstep', repeat))
        self.assertInvalid(self.run.reduce(), "missing episode ('windows', 'lockstep', 4, 0)")

    def test_duplicate_and_unregistered_episodes_refused(self):
        self.run.receipt['episodes'].append(copy.deepcopy(self.run.row('lockstep', 0)))
        extra = copy.deepcopy(self.run.row('lockstep', 0))
        extra['repeat'] = 7
        self.run.receipt['episodes'].append(extra)
        out = self.run.reduce()
        self.assertInvalid(out, 'duplicate episode')
        self.assertInvalid(out, 'unregistered episode')

    def test_incomplete_tick_hash_coverage_refused(self):
        data = episode('lockstep', 4, self.ticks)
        data['tick_hashes'][300] = ''
        self.run.write('windows', 'lockstep', 4, 1, data)
        self.assertInvalid(self.run.reduce(), 'tick hash coverage: 1 missing')

    def test_truncated_trace_refused(self):
        data = episode('lockstep', 4, self.ticks)
        data['steps'] = data['steps'][:-5]
        self.run.write('windows', 'lockstep', 4, 1, data)
        self.assertInvalid(self.run.reduce(), 'steps length')

    def test_incomplete_native_ticks_refused(self):
        data = episode('lockstep', 4, self.ticks)
        data['completed_ticks'] = self.ticks - 1
        self.run.write('windows', 'lockstep', 4, 1, data)
        self.assertInvalid(self.run.reduce(), 'completed_ticks')

    def test_fence_violation_refused(self):
        data = episode('lockstep', 4, self.ticks)
        data['steps'][10]['publication'] = 10
        self.run.write('windows', 'lockstep', 4, 1, data)
        self.assertInvalid(self.run.reduce(), 'violates the fence')

    def test_duration_outside_process_refused(self):
        self.run.row('lockstep', 1)['seconds'] = 5.0
        self.assertInvalid(self.run.reduce(), 'not inside receipt process duration')

    def test_receipt_clean_flag_not_trusted(self):
        self.run.row('lockstep', 1)['clean'] = False
        self.assertInvalid(self.run.reduce(), 'disagrees with independent validation')
        row = self.run.row('lockstep', 1)
        row['clean'], row['exit'] = True, 1
        self.assertInvalid(self.run.reduce(), 'exit 1')

    def test_empty_final_hash_refused_outside_registered_defect(self):
        data = episode('lockstep', 4, self.ticks)
        data['state_hash'] = ''
        self.run.write('windows', 'lockstep', 4, 1, data)
        self.assertInvalid(self.run.reduce(), 'final state_hash/final_physical_hash empty')

    def test_source_identity_mismatch_refused(self):
        self.run.receipt['identity']['fixture_sha256'] = '0' * 64
        self.assertInvalid(self.run.reduce(), 'fixture_sha256 does not match')

    def test_crlf_checkout_identity_is_noted(self):
        path = reducer.IDENTITY_FILES['runner_sha256']
        self.run.receipt['identity']['runner_sha256'] = sha(SOURCES[path].replace(b'\n', b'\r\n'))
        out = self.run.reduce()
        self.assertTrue(out['validation']['valid'], out['validation']['errors'])
        self.assertTrue(any('CRLF checkout' in n for n in out['validation']['notes']))

    def test_unregistered_run_refused(self):
        out = reducer.reduce('load-9999', show=show, base=Path(self.tmp.name))
        self.assertInvalid(out, 'not registered')


class DefectRunTests(unittest.TestCase):
    def test_registered_final_hash_defect_is_not_compared(self):
        with tempfile.TemporaryDirectory() as tmp:
            run = Run(tmp, 'smoke-001')
            for row in list(run.receipt['episodes']):
                data = episode(row['arm'], row['workers'], run.expected['ticks'])
                data['platform'] = reducer.PLATFORMS[row['host']]
                data['state_hash'] = data['final_physical_hash'] = ''
                run.write(row['host'], row['arm'], row['workers'], row['repeat'], data)
            out = run.reduce()
            self.assertTrue(out['validation']['valid'], out['validation']['errors'])
            self.assertFalse(out['repeatability']['windows/lockstep/w1']['final_hashes_compared'])
            self.assertEqual(out['decisions'], 'excluded (registered smoke)')


if __name__ == '__main__':
    unittest.main()
