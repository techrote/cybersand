#!/usr/bin/env python3
"""GEN-006 #194: experimental cross-process blob-quota check/insert race.

Extends Draft PR #458's synthetic checkpoint apparatus only. Real OS processes,
real filesystem, unchanged Store.put_blob. No native World or admitted codec.

python tools/experiments/gen006_blob_quota_race_probe.py --test
python tools/experiments/gen006_blob_quota_race_probe.py --witness quota-witness.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
import multiprocessing as mp
import os
from pathlib import Path
import platform
import tempfile
import unittest

import gen006_windows_lease_probe as apparatus

EXPECTED_STORE_BLOB = '9c42d3339065b5e23bf42f99abf82976d58ba05a'


def verify_source():
    """Refuse to apply a race conclusion to an uninspected changed Store."""
    path = Path(apparatus.__file__)
    raw = path.read_bytes()
    git_blob = hashlib.sha1(b'blob ' + str(len(raw)).encode('ascii') + b'\0' + raw).hexdigest()
    apparatus.require(git_blob == EXPECTED_STORE_BLOB, 'STORE_SOURCE_DRIFT')
    return git_blob


def child_put(home, record, mode, gate, conn):
    store = apparatus.Store(home)
    original = apparatus.atomic_write
    try:
        if mode == 'unsafe':
            # Intentionally interrupt inside the real Store.put_blob *after*
            # its existing unguarded length/quota check, before creation.
            def staged_atomic_write(path, raw):
                if Path(path).parent == store.blobs:
                    gate.wait(timeout=20)
                return original(path, raw)
            apparatus.atomic_write = staged_atomic_write
            h = store.put_blob(record)
        elif mode == 'serialized':
            # Reuse the existing root lock: capacity check and insertion share
            # the short critical section. This is an independent CONTROL,
            # not a proposed production performance/lifetime design.
            gate.wait(timeout=20)
            with apparatus.root_guard(store.lock):
                h = store.put_blob(record)
        else:
            raise ValueError('unknown mode')
        conn.send({'status': 'STORED', 'hash': h, 'pid': os.getpid()})
    except apparatus.Refused as exc:
        conn.send({'status': 'REFUSED', 'reason': str(exc), 'pid': os.getpid()})
    finally:
        apparatus.atomic_write = original
        conn.close()


def execute(mode):
    apparatus.require(mode in ('unsafe', 'serialized'), 'MODE')
    verify_source()
    with tempfile.TemporaryDirectory(prefix='gen006-blob-quota-') as home:
        store = apparatus.Store(home)
        store.publish(1)  # 2 referenced blobs
        for i in range(13):
            store.put_blob({'unreferenced_fixture': i})
        before = sorted(p.name for p in store.blobs.iterdir())
        apparatus.require(len(before) == 15, 'SEED_COUNT')
        old_root, old_hash = store.load_root()
        original_records = store.read(old_root)

        ctx = mp.get_context('spawn')
        gate = ctx.Barrier(2)
        processes = []
        parents = []
        records = [{'quota_writer': 'A', 'coord': [-1, 0]},
                   {'quota_writer': 'B', 'coord': [0, 0]}]
        try:
            for record in records:
                parent, child = ctx.Pipe(duplex=False)
                p = ctx.Process(target=child_put, args=(home, record, mode, gate, child))
                p.start()
                child.close()
                processes.append(p)
                parents.append(parent)
            events = []
            for parent in parents:
                apparatus.require(parent.poll(30), 'CHILD_TIMEOUT')
                events.append(parent.recv())
            for p in processes:
                p.join(10)
                apparatus.require(p.exitcode == 0, 'CHILD_EXIT')
            after = sorted(p.name for p in store.blobs.iterdir())
            new_root, new_hash = store.load_root()
            retained_records = store.read(new_root)
            # Explicitly preserve how the *existing* collector handles an
            # over-budget directory, including its refusal to sweep.
            try:
                collected = {'status': 'OK', **store.collect()}
            except apparatus.Refused as exc:
                collected = {'status': 'REFUSED', 'reason': str(exc)}
            final_files = sorted(p.name for p in store.blobs.iterdir())
            return {
                'mode': mode, 'source_blob': verify_source(),
                'platform': {'system': platform.platform(),
                             'python': platform.python_version(), 'parent_pid': os.getpid()},
                'initial_files': len(before),
                'after_two_writers': len(after),
                'final_files': len(final_files),
                'new_files': sorted(set(after) - set(before)),
                'child_outcomes': events,
                'root_rev': new_root['rev'], 'root_hash_unchanged': old_hash == new_hash,
                'live_records_unchanged': retained_records == original_records,
                'gc': collected,
                'classification': 'TEST_ONLY; native World and Windows power-loss durability untested'
            }
        finally:
            for p in processes:
                if p.is_alive():
                    p.terminate()
                    p.join(5)
            for parent in parents:
                parent.close()


class Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.unsafe = execute('unsafe')
        cls.serialized = execute('serialized')

    def test_real_distinct_processes(self):
        for result in (self.unsafe, self.serialized):
            pids = [event['pid'] for event in result['child_outcomes']]
            self.assertEqual(len(set(pids + [result['platform']['parent_pid']])), 3)

    def test_original_source_guard(self):
        self.assertEqual(self.unsafe['source_blob'], EXPECTED_STORE_BLOB)

    def test_unguarded_both_admitted(self):
        self.assertEqual([e['status'] for e in self.unsafe['child_outcomes']], ['STORED', 'STORED'])

    def test_unprotected_quota_overshoot(self):
        self.assertEqual((self.unsafe['initial_files'], self.unsafe['after_two_writers']), (15, 17))
        self.assertEqual(len(self.unsafe['new_files']), 2)

    def test_overquota_gc_refuses(self):
        self.assertEqual(self.unsafe['gc'], {'status': 'REFUSED', 'reason': 'BLOB_BUDGET'})
        self.assertEqual(self.unsafe['final_files'], 17)

    def test_unprotected_root_still_readable(self):
        self.assertTrue(self.unsafe['root_hash_unchanged'])
        self.assertTrue(self.unsafe['live_records_unchanged'])
        self.assertEqual(self.unsafe['root_rev'], 1)

    def test_serialized_exactly_one_refusal(self):
        statuses = sorted((e['status'], e.get('reason')) for e in self.serialized['child_outcomes'])
        self.assertEqual(statuses, [('REFUSED', 'BLOB_BUDGET'), ('STORED', None)])

    def test_serialized_respects_quota(self):
        self.assertEqual(self.serialized['after_two_writers'], 16)
        self.assertEqual(len(self.serialized['new_files']), 1)

    def test_serialized_sweep_recovers_capacity(self):
        self.assertEqual(self.serialized['gc'],
                         {'status': 'OK', 'live': 0, 'retired': 0, 'removed': 14, 'retained': 2})
        self.assertEqual(self.serialized['final_files'], 2)

    def test_serialized_root_unchanged(self):
        self.assertTrue(self.serialized['root_hash_unchanged'])
        self.assertTrue(self.serialized['live_records_unchanged'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--test', action='store_true')
    parser.add_argument('--witness')
    arguments = parser.parse_args()
    if arguments.test:
        unittest.main(argv=[__file__], verbosity=2)
    else:
        data = {'unsafe': execute('unsafe'), 'serialized': execute('serialized')}
        raw = json.dumps(data, indent=2, sort_keys=True) + '\n'
        if arguments.witness:
            Path(arguments.witness).write_text(raw, encoding='utf-8')
        else:
            print(raw, end='')
