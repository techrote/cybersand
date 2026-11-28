#!/usr/bin/env python3
"""GEN-006 #194: experimental real-process POSIX/Windows checkpoint-reader lease probe.

Not a production persistence format or CyberSand native test. Uses genuine
filesystem publication, OS byte-range locks, separate reader processes and GC.
Run: python gen006_windows_lease_probe.py --test
     python gen006_windows_lease_probe.py --witness evidence.json
"""
from __future__ import annotations
import argparse
from contextlib import contextmanager
import errno
import hashlib
import json
import multiprocessing as mp
import os
from pathlib import Path
import platform
import re
import tempfile
import unittest
import uuid

WINDOWS = os.name == 'nt'
if WINDOWS:
    import msvcrt
else:
    import fcntl

MAX_RECORD = 4096
MAX_LEASES = 4
MAX_BLOBS = 16
HEX = re.compile(r'^[0-9a-f]{64}$')
LEASE = re.compile(r'^[0-9a-f]{32}\.lease$')
FMT = 'gen006.experimental.winlease.v1'
COORDS = [[-1, 0], [0, 0]]

class Refused(Exception):
    pass

def require(condition, code):
    if not condition:
        raise Refused(code)

def enc(obj):
    raw = json.dumps(obj, sort_keys=True, separators=(',', ':'), allow_nan=False).encode('ascii')
    require(len(raw) <= MAX_RECORD, 'RECORD_BUDGET')
    return raw

def dec(raw):
    require(len(raw) <= MAX_RECORD, 'READ_BUDGET')
    def unique(pairs):
        d = {}
        for key, val in pairs:
            require(key not in d, 'DUPLICATE_KEY')
            d[key] = val
        return d
    try:
        return json.loads(raw, object_pairs_hook=unique)
    except (UnicodeError, ValueError) as e:
        raise Refused('BAD_JSON') from e

def digest(raw):
    return hashlib.sha256(raw).hexdigest()

def lock_byte(file, blocking=True):
    file.seek(0)
    if WINDOWS:
        try:
            msvcrt.locking(file.fileno(), msvcrt.LK_LOCK if blocking else msvcrt.LK_NBLCK, 1)
            return True
        except OSError as e:
            if not blocking and (e.errno in (errno.EACCES, errno.EAGAIN) or getattr(e, 'winerror', None) in (32, 33)):
                return False
            raise
    try:
        fcntl.flock(file.fileno(), fcntl.LOCK_EX | (0 if blocking else fcntl.LOCK_NB))
        return True
    except OSError as e:
        if not blocking and e.errno in (errno.EACCES, errno.EAGAIN):
            return False
        raise

def unlock_byte(file):
    file.seek(0)
    if WINDOWS:
        msvcrt.locking(file.fileno(), msvcrt.LK_UNLCK, 1)
    else:
        fcntl.flock(file.fileno(), fcntl.LOCK_UN)

@contextmanager
def root_guard(path):
    with open(path, 'r+b' if path.exists() else 'w+b') as f:
        if f.seek(0, os.SEEK_END) == 0:
            f.write(b'L')
            f.flush()
            os.fsync(f.fileno())
        require(lock_byte(f), 'ROOT_LOCK')
        try:
            yield
        finally:
            unlock_byte(f)

def atomic_write(path, raw):
    require(len(raw) <= MAX_RECORD, 'WRITE_BUDGET')
    fd, name = tempfile.mkstemp(dir=path.parent, prefix='.gen006-stage-')
    try:
        with os.fdopen(fd, 'wb') as f:
            f.write(raw)
            f.flush()
            os.fsync(f.fileno())
        os.replace(name, path)
        # Windows directory fsync is not available through portable Python.
        # This does NOT prove power-loss durability on either filesystem.
    finally:
        if os.path.exists(name):
            os.unlink(name)

class Store:
    def __init__(self, path):
        self.home = Path(path)
        self.blobs = self.home / 'blobs'
        self.leases = self.home / 'leases'
        for d in (self.home, self.blobs, self.leases):
            d.mkdir(parents=True, exist_ok=True)
        self.root = self.home / 'root.json'
        self.lock = self.home / 'root.lock'

    def put_blob(self, record):
        raw = enc(record)
        h = digest(raw)
        path = self.blobs / (h + '.json')
        require(len(list(self.blobs.iterdir())) < MAX_BLOBS or path.exists(), 'BLOB_BUDGET')
        if not path.exists():
            atomic_write(path, raw)
        return h

    def load_root(self):
        try:
            raw = self.root.read_bytes()
        except FileNotFoundError as e:
            raise Refused('ROOT_MISSING') from e
        r = dec(raw)
        require(type(r) is dict and set(r) == {'format', 'rev', 'slots'}, 'ROOT_SCHEMA')
        require(r['format'] == FMT and type(r['rev']) is int and r['rev'] in (1, 2), 'ROOT_ID')
        require(type(r['slots']) is list and len(r['slots']) == 2, 'ROOT_SLOTS')
        for i, item in enumerate(r['slots']):
            require(type(item) is dict and set(item) == {'coord', 'hash'}, 'SLOT_SCHEMA')
            require(item['coord'] == COORDS[i] and all(type(n) is int for n in item['coord']), 'SIGNED_COORD')
            require(type(item['hash']) is str and HEX.fullmatch(item['hash']) is not None, 'SLOT_HASH')
        return r, digest(raw)

    def publish(self, rev):
        require(rev in (1, 2), 'REV')
        with root_guard(self.lock):
            if rev == 1:
                require(not self.root.exists(), 'ALREADY_SEEDED')
            else:
                old, _ = self.load_root()
                require(old['rev'] == 1, 'STALE_PUBLICATION')
            records = [
                {'coord': COORDS[0], 'tick': 100 if rev == 1 else 103,
                 'material': 'Empty' if rev == 1 else 'Wall',
                 'intent': 'explicit_empty' if rev == 1 else 'explicit_place',
                 'due': 104 if rev == 1 else 107},
                {'coord': COORDS[1], 'tick': 100 if rev == 1 else 103,
                 'material': 'Water', 'state_a': 17 if rev == 1 else 19,
                 'quantity': 17 if rev == 1 else 19}
            ]
            slots = [{'coord': rec['coord'], 'hash': self.put_blob(rec)} for rec in records]
            atomic_write(self.root, enc({'format': FMT, 'rev': rev, 'slots': slots}))
        return self.load_root()[1]

    def read(self, r):
        out = []
        for coord, slot in zip(COORDS, r['slots']):
            try:
                raw = (self.blobs / (slot['hash'] + '.json')).read_bytes()
            except FileNotFoundError as e:
                raise Refused('BLOB_MISSING') from e
            require(digest(raw) == slot['hash'], 'BLOB_CORRUPT')
            rec = dec(raw)
            require(type(rec) is dict and rec.get('coord') == coord and type(rec.get('tick')) is int,
                    'RECORD_ID')
            out.append(rec)
        require(out[0]['tick'] == out[1]['tick'], 'MIXED_TICK')
        return out

    def pin(self):
        with root_guard(self.lock):
            require(len(list(self.leases.iterdir())) < MAX_LEASES, 'LEASE_BUDGET')
            root, root_hash = self.load_root()
            path = self.leases / (uuid.uuid4().hex + '.lease')
            f = open(path, 'x+b')
            try:
                f.write(b'L' + enc({'root': root_hash, 'hashes': [s['hash'] for s in root['slots']]}))
                f.flush()
                os.fsync(f.fileno())
                require(lock_byte(f), 'LEASE_LOCK')
            except BaseException:
                f.close()
                path.unlink(missing_ok=True)
                raise
        return root, f, path, root_hash

    def unpin(self, f, path):
        # Windows cannot unlink an open leased file. Root lock prevents GC from
        # racing the close-then-unlink pair; Linux uses identical order.
        with root_guard(self.lock):
            unlock_byte(f)
            f.close()
            path.unlink()

    def collect(self):
        with root_guard(self.lock):
            root, _ = self.load_root()
            keep = {s['hash'] for s in root['slots']}
            lease_files = list(self.leases.iterdir())
            require(len(lease_files) <= MAX_LEASES, 'LEASE_BUDGET')
            alive = 0
            dead = 0
            for path in lease_files:
                require(path.is_file() and not path.is_symlink() and LEASE.fullmatch(path.name), 'LEASE_PATH')
                with open(path, 'r+b') as f:
                    available = lock_byte(f, blocking=False)
                    if not available:
                        f.seek(1)
                        info = dec(f.read(MAX_RECORD + 1))
                        require(type(info) is dict and set(info) == {'root', 'hashes'}, 'LEASE_SCHEMA')
                        require(type(info['root']) is str and HEX.fullmatch(info['root']), 'LEASE_ROOT')
                        hashes = info['hashes']
                        require(type(hashes) is list and len(hashes) == 2 and
                                all(type(h) is str and HEX.fullmatch(h) for h in hashes), 'LEASE_DIGESTS')
                        keep.update(hashes)
                        alive += 1
                    else:
                        unlock_byte(f)
                        dead += 1
                if available:
                    path.unlink()  # Closed first for Windows deletion semantics.
            paths = list(self.blobs.iterdir())
            require(len(paths) <= MAX_BLOBS, 'BLOB_BUDGET')
            remove = []
            for path in paths:
                require(path.is_file() and not path.is_symlink() and
                        re.fullmatch(r'[0-9a-f]{64}\.json', path.name), 'BLOB_PATH')
                if path.stem in keep:
                    require(digest(path.read_bytes()) == path.stem, 'RETAINED_BLOB_CORRUPT')
                else:
                    remove.append(path)
            for path in remove:
                path.unlink()
            return {'live': alive, 'retired': dead, 'removed': len(remove), 'retained': len(paths)-len(remove)}

def reader(path, protected, conn, crash):
    s = Store(path)
    handle = None
    lease_path = None
    try:
        if protected:
            root, handle, lease_path, h = s.pin()
        else:
            root, h = s.load_root()
        conn.send({'status': 'READY', 'pid': os.getpid(), 'root': h})
        if crash:
            os._exit(17)
        require(conn.recv() == 'CONTINUE', 'CONTROL')
        try:
            records = s.read(root)
            conn.send({'status': 'READ_OK', 'left': records[0], 'right': records[1]})
        except Refused as e:
            conn.send({'status': 'REFUSED', 'reason': str(e)})
        require(conn.recv() == 'RELEASE', 'CONTROL')
    finally:
        if handle is not None:
            s.unpin(handle, lease_path)
        conn.close()

def pair(protected=False, crash=False):
    with tempfile.TemporaryDirectory(prefix='gen006-winlease-') as tmp:
        s = Store(tmp)
        old = s.publish(1)
        ctx = mp.get_context('spawn')
        parent, child = ctx.Pipe()
        p = ctx.Process(target=reader, args=(tmp, protected, child, crash))
        try:
            p.start()
            child.close()
            require(parent.poll(15), 'CHILD_READY_TIMEOUT')
            ready = parent.recv()
            require(ready['root'] == old and ready['status'] == 'READY', 'BAD_READY')
            if crash:
                p.join(15)
                require(p.exitcode == 17, 'CRASH_EXIT')
                s.publish(2)
                swept = s.collect()
                return {'child_pid': ready['pid'], 'main_pid': os.getpid(),
                        'exit': p.exitcode, 'gc': swept, 'leases': len(list(s.leases.iterdir()))}
            new = s.publish(2)
            first = s.collect()
            parent.send('CONTINUE')
            require(parent.poll(15), 'CHILD_READ_TIMEOUT')
            result = parent.recv()
            parent.send('RELEASE')
            p.join(15)
            require(p.exitcode == 0, 'CHILD_EXIT')
            second = s.collect()
            now, _ = s.load_root()
            records = s.read(now)
            return {'protected': protected, 'child_pid': ready['pid'], 'main_pid': os.getpid(),
                    'old_root': old, 'new_root': new, 'first_gc': first, 'reader': result,
                    'second_gc': second, 'new_records': records}
        finally:
            if p.is_alive():
                p.terminate()
                p.join(5)
            parent.close()

class Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.unleased = pair(False)
        cls.leased = pair(True)
        cls.crashed = pair(True, True)

    def test_real_process(self):
        self.assertNotEqual(self.leased['child_pid'], self.leased['main_pid'])

    def test_old_and_new_root_distinct(self):
        self.assertNotEqual(self.leased['old_root'], self.leased['new_root'])

    def test_unleased_gc_loses_snapshot(self):
        self.assertEqual(self.unleased['reader'], {'status': 'REFUSED', 'reason': 'BLOB_MISSING'})
        self.assertEqual(self.unleased['first_gc']['removed'], 2)

    def test_lease_preserves_exact_old_state(self):
        r = self.leased['reader']
        self.assertEqual(r['status'], 'READ_OK')
        self.assertEqual((r['left']['material'], r['left']['intent'], r['left']['due']),
                         ('Empty', 'explicit_empty', 104))
        self.assertEqual((r['right']['state_a'], r['right']['quantity']), (17, 17))

    def test_windows_compatible_gc_order(self):
        self.assertEqual(self.leased['first_gc'], {'live': 1, 'retired': 0, 'removed': 0, 'retained': 4})
        self.assertEqual(self.leased['second_gc'], {'live': 0, 'retired': 0, 'removed': 2, 'retained': 2})

    def test_crash_unlocks_and_reclaims(self):
        self.assertEqual(self.crashed['exit'], 17)
        self.assertEqual(self.crashed['gc'], {'live': 0, 'retired': 1, 'removed': 2, 'retained': 2})
        self.assertEqual(self.crashed['leases'], 0)

    def test_new_revision_intact(self):
        r = self.leased['new_records']
        self.assertEqual((r[0]['material'], r[1]['quantity'], r[1]['tick']), ('Wall', 19, 103))

    def test_malformed_live_lease_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            s = Store(tmp)
            s.publish(1)
            _, handle, lease, _ = s.pin()
            try:
                handle.seek(1)
                handle.write(b'{')
                handle.truncate(2)
                handle.flush()
                os.fsync(handle.fileno())
                s.publish(2)
                with self.assertRaisesRegex(Refused, 'BAD_JSON'):
                    s.collect()
                self.assertEqual(len(list(s.blobs.iterdir())), 4)
            finally:
                s.unpin(handle, lease)

    def test_lease_quota(self):
        with tempfile.TemporaryDirectory() as tmp:
            s = Store(tmp)
            s.publish(1)
            pins = []
            try:
                for _ in range(MAX_LEASES):
                    pins.append(s.pin())
                with self.assertRaisesRegex(Refused, 'LEASE_BUDGET'):
                    s.pin()
            finally:
                for _, handle, lease, _ in pins:
                    s.unpin(handle, lease)

    def test_corrupt_root_refuses_gc(self):
        with tempfile.TemporaryDirectory() as tmp:
            s = Store(tmp)
            s.publish(1)
            s.root.write_text('{', encoding='utf-8')
            with self.assertRaisesRegex(Refused, 'BAD_JSON'):
                s.collect()
            self.assertEqual(len(list(s.blobs.iterdir())), 2)

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--test', action='store_true')
    ap.add_argument('--witness')
    args = ap.parse_args()
    if args.test:
        unittest.main(argv=[__file__], verbosity=2)
    else:
        result = {'unleased': pair(False), 'leased': pair(True), 'crashed': pair(True, True),
                  'platform': {'system': platform.system(), 'release': platform.release(),
                               'version': platform.version(), 'python': platform.python_version(),
                               'filesystem': 'local tempdir; mount type not independently asserted'},
                  'source': {'repo': 'techrote/cybersand',
                             'base_sha': '06522e300dcf91efbab0ac8f4f4370af72cf2029',
                             'base_tree': '40fa1b41bc1d7c809101bcf95125ac56019f424b'},
                  'qualification': 'EXPERIMENTAL OS-process filesystem-only; no native World, power loss or network FS'}
        raw = json.dumps(result, sort_keys=True, indent=2) + '\n'
        if args.witness:
            Path(args.witness).write_text(raw, encoding='utf-8')
        else:
            print(raw, end='')
