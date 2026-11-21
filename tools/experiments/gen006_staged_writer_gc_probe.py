#!/usr/bin/env python3
"""GEN-006 #194: test-only staged-writer/GC race, using the #458 OS-lock apparatus.

Synthetic two-chunk records, real independent OS writer and collector processes.
No CyberSand native World, Windows power-loss durability or admitted serializer.
Usage: python gen006_staged_writer_gc_probe.py --test
       python gen006_staged_writer_gc_probe.py --witness results.json
"""
from __future__ import annotations
import argparse
import json
import multiprocessing as mp
import os
from pathlib import Path
import platform
import tempfile
import unittest
import uuid

from gen006_windows_lease_probe import (
    Store, Refused, COORDS, FMT, root_guard, atomic_write,
    enc, dec, digest, lock_byte, require,
)


def next_records():
    """A signed-seam pair with an Empty->Wall edit and a Water state update."""
    return [
        {'coord': COORDS[0], 'tick': 103, 'material': 'Wall',
         'intent': 'explicit_place', 'due': 107},
        {'coord': COORDS[1], 'tick': 103, 'material': 'Water',
         'state_a': 19, 'quantity': 19},
    ]


def reserve_writer_lease(store, expected_root, staged_hashes):
    """Experimental prospective-hash lease; existing GC sees an active digest set.

    This is *not* a production writer-lease API. The original #458 reader-only
    lease format happens to carry an active root digest and two blob digests.
    """
    with root_guard(store.lock):
        _, current_root = store.load_root()
        require(current_root == expected_root, 'STALE_ROOT')
        require(len(list(store.leases.iterdir())) < 4, 'LEASE_BUDGET')
        path = store.leases / (uuid.uuid4().hex + '.lease')
        lease = open(path, 'x+b')
        try:
            lease.write(b'L' + enc({'root': expected_root, 'hashes': staged_hashes}))
            lease.flush()
            os.fsync(lease.fileno())
            require(lock_byte(lease), 'LEASE_LOCK')
        except BaseException:
            lease.close()
            path.unlink(missing_ok=True)
            raise
    return lease, path


def commit_staged(store, old_root, hashes, validate=True):
    with root_guard(store.lock):
        previous, current_hash = store.load_root()
        if validate:
            require(previous['rev'] == 1 and current_hash == old_root, 'STALE_ROOT')
            for record, h in zip(next_records(), hashes):
                try:
                    raw = (store.blobs / (h + '.json')).read_bytes()
                except FileNotFoundError as e:
                    raise Refused('STAGED_BLOB_MISSING') from e
                require(digest(raw) == h and dec(raw) == record, 'STAGED_BLOB_CORRUPT')
        new_root = {'format': FMT, 'rev': 2,
                    'slots': [{'coord': c, 'hash': h} for c, h in zip(COORDS, hashes)]}
        atomic_write(store.root, enc(new_root))
    return store.load_root()[1]


def writer(path, mode, conn, crash):
    s = Store(path)
    lease = lease_path = None
    try:
        _, old_root = s.load_root()
        records = next_records()
        hashes = [digest(enc(record)) for record in records]
        if mode == 'lease':
            # Pin prospective hashes BEFORE asynchronous staging starts.
            lease, lease_path = reserve_writer_lease(s, old_root, hashes)
        for r, h in zip(records, hashes):
            require(s.put_blob(r) == h, 'STAGING_HASH_CHANGED')
        conn.send({'status': 'STAGED', 'writer_pid': os.getpid(),
                   'old_root': old_root, 'staged_hashes': hashes})
        if crash:
            os._exit(17)
        require(conn.recv() == 'COMMIT', 'CONTROL')
        try:
            updated = commit_staged(s, old_root, hashes, validate=mode != 'naive')
            conn.send({'status': 'COMMITTED', 'root_hash': updated})
        except Refused as e:
            conn.send({'status': 'REFUSED', 'reason': str(e)})
    finally:
        if lease is not None:
            s.unpin(lease, lease_path)
        conn.close()


def interleaving(mode, race='collect'):
    require(mode in ('naive', 'guarded', 'lease'), 'MODE')
    require(race in ('collect', 'crash', 'stale', 'corrupt'), 'RACE')
    with tempfile.TemporaryDirectory(prefix='gen006-stage-gc-') as home:
        s = Store(home)
        first = s.publish(1)
        ctx = mp.get_context('spawn')
        parent, child = ctx.Pipe()
        child_process = ctx.Process(target=writer, args=(home, mode, child, race == 'crash'))
        try:
            child_process.start()
            child.close()
            require(parent.poll(30), 'WRITER_STAGE_TIMEOUT')
            staged = parent.recv()
            require(staged['status'] == 'STAGED' and staged['old_root'] == first,
                    'STAGING_RECEIPT')
            require(staged['writer_pid'] != os.getpid(), 'NOT_AN_OS_PROCESS')
            if race == 'crash':
                child_process.join(30)
                require(child_process.exitcode == 17, 'CRASH_EXIT')
                collected = s.collect()
                now, h = s.load_root()
                return {'mode': mode, 'race': race, 'staged': staged,
                        'writer_exit': child_process.exitcode, 'gc': collected,
                        'root_revision': now['rev'], 'root_hash_unchanged': h == first,
                        'read': s.read(now), 'leases': len(list(s.leases.iterdir()))}
            if race == 'stale':
                s.publish(2)
                collected = s.collect()
            elif race == 'corrupt':
                bad_path = s.blobs / (staged['staged_hashes'][0] + '.json')
                bad_path.write_bytes(b'corrupt')
                collected = None
            else:
                collected = s.collect()
            parent.send('COMMIT')
            require(parent.poll(30), 'WRITER_COMMIT_TIMEOUT')
            result = parent.recv()
            child_process.join(30)
            require(child_process.exitcode == 0, 'WRITER_EXIT')
            current, h = s.load_root()
            try:
                content = {'status': 'READ_OK', 'records': s.read(current)}
            except Refused as e:
                content = {'status': 'REFUSED', 'reason': str(e)}
            after_gc = None
            if result['status'] == 'COMMITTED' and content['status'] == 'READ_OK':
                after_gc = s.collect()
            return {'mode': mode, 'race': race, 'staged': staged, 'gc': collected,
                    'writer': result, 'writer_exit': child_process.exitcode,
                    'root_revision': current['rev'], 'root_hash_unchanged': h == first,
                    'read': content, 'after_gc': after_gc,
                    'leases': len(list(s.leases.iterdir()))}
        finally:
            if child_process.is_alive():
                child_process.terminate()
                child_process.join(5)
            parent.close()


class Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.naive = interleaving('naive')
        cls.guarded = interleaving('guarded')
        cls.leased = interleaving('lease')
        cls.crashed = interleaving('lease', 'crash')
        cls.stale = interleaving('lease', 'stale')
        cls.corrupt = interleaving('lease', 'corrupt')

    def test_real_process(self):
        self.assertNotEqual(self.leased['staged']['writer_pid'], os.getpid())

    def test_unprotected_gc_removes_staged_blobs(self):
        self.assertEqual(self.naive['gc']['removed'], 2)
        self.assertEqual(self.naive['gc']['retained'], 2)

    def test_negative_naive_pub_dangling_manifest(self):
        self.assertEqual(self.naive['writer']['status'], 'COMMITTED')
        self.assertEqual(self.naive['root_revision'], 2)
        self.assertEqual(self.naive['read'], {'status': 'REFUSED', 'reason': 'BLOB_MISSING'})

    def test_commit_boundary_verification_fails_closed(self):
        self.assertEqual(self.guarded['writer'], {'status': 'REFUSED', 'reason': 'STAGED_BLOB_MISSING'})
        self.assertEqual(self.guarded['root_revision'], 1)
        self.assertTrue(self.guarded['root_hash_unchanged'])
        self.assertEqual(self.guarded['read']['status'], 'READ_OK')

    def test_active_writer_lease_prevents_stage_gc(self):
        self.assertEqual(self.leased['gc']['removed'], 0)
        self.assertEqual(self.leased['gc']['live'], 1)
        self.assertEqual(self.leased['writer']['status'], 'COMMITTED')
        self.assertEqual(self.leased['root_revision'], 2)
        self.assertEqual(self.leased['read']['status'], 'READ_OK')

    def test_material_and_water_exact(self):
        left, right = self.leased['read']['records']
        self.assertEqual((left['coord'], left['material'], left['intent'], left['due']),
                         ([-1, 0], 'Wall', 'explicit_place', 107))
        self.assertEqual((right['coord'], right['state_a'], right['quantity'], right['tick']),
                         ([0, 0], 19, 19, 103))

    def test_after_publication_retire_old(self):
        self.assertEqual(self.leased['after_gc']['removed'], 2)
        self.assertEqual(self.leased['leases'], 0)

    def test_crashed_writer_reclaims_unpublished_blobs(self):
        self.assertEqual(self.crashed['writer_exit'], 17)
        self.assertEqual(self.crashed['gc']['retired'], 1)
        self.assertEqual(self.crashed['gc']['removed'], 2)
        self.assertTrue(self.crashed['root_hash_unchanged'])
        self.assertEqual(self.crashed['leases'], 0)

    def test_concurrent_root_replacement_refused(self):
        self.assertEqual(self.stale['writer'], {'status': 'REFUSED', 'reason': 'STALE_ROOT'})
        self.assertEqual(self.stale['read']['status'], 'READ_OK')
        self.assertEqual(self.stale['root_revision'], 2)

    def test_staged_corruption_refused(self):
        self.assertEqual(self.corrupt['writer'], {'status': 'REFUSED', 'reason': 'STAGED_BLOB_CORRUPT'})
        self.assertTrue(self.corrupt['root_hash_unchanged'])
        self.assertEqual(self.corrupt['root_revision'], 1)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--test', action='store_true')
    parser.add_argument('--witness')
    args = parser.parse_args()
    if args.test:
        unittest.main(argv=[__file__], verbosity=2)
    else:
        witness = {name: interleaving(*params) for name, params in {
            'naive': ('naive',), 'guarded': ('guarded',), 'lease': ('lease',),
            'crash': ('lease', 'crash'), 'stale': ('lease', 'stale'),
            'corrupt': ('lease', 'corrupt'),
        }.items()}
        witness['platform'] = {'system': platform.platform(), 'python': platform.python_version(),
                               'parent_pid': os.getpid()}
        witness['qualification'] = 'EXPERIMENTAL; synthetic records, real OS processes; not native World'
        output = json.dumps(witness, sort_keys=True, indent=2) + '\n'
        if args.witness:
            Path(args.witness).write_text(output, encoding='utf-8')
        else:
            print(output, end='')
