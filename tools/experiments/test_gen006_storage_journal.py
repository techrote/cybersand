"""GEN-006 G6J1 standalone executable fixture (process-crash and integrity gates)."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from gen006_storage_journal import (EDIT, HEADER, Identity, Mutation, Journal,
                                     recover, replay_checked)


def baseline():
    return bytes((i*37+11) % 256 for i in range(512*1024))


def ident():
    return Identity(-17, 201, 0x4433221177, 5, 42, 0xabcddcba)


class Tests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='gen006-journal-')
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / 'test.g6j'

    def test_publication_replay_and_volume(self):
        j = Journal.create(self.path, ident(), baseline())
        with self.assertRaisesRegex(ValueError, 'G6J_DESTINATION_EXISTS'):
            Journal.create(self.path, ident(), baseline())
        with self.assertRaisesRegex(ValueError, 'G6J_IDENTITY_REFUSED'):
            Journal.open(self.path, -16, 201, ident().incarnation)
        with self.assertRaisesRegex(ValueError, 'G6J_STALE_GENERATION'):
            j.append(Mutation(1, 1, 1, 0, 0, 6, 42, 0), 4)
        with self.assertRaisesRegex(ValueError, 'G6J_TICK_DOMAIN_REFUSED'):
            j.append(Mutation(1, 1, 1, 0, 0, 6, 43, 0), 5)
        for i in range(200):
            j.append(Mutation(2 if i & 1 else 4, i%64, (i//64)%64,
                              0 if i&1 else 17, 0 if i&1 else 417,
                              i+6, 42, 0x123456000+i), i+5)
        r = recover(self.path)
        self.assertEqual(r.checkpoint, baseline())
        self.assertEqual(len(r.edits), 200)
        self.assertEqual(r.generation, 205)
        self.assertFalse(r.torn_tail)
        self.assertEqual(r.valid_length, HEADER.size+512*1024+200*EDIT.size)
        h = [r.identity.physical_hash]
        replay_checked(r, lambda e: h.__setitem__(0, e.physical_hash) is None,
                       lambda: h[0])
        h[0] = 0
        with self.assertRaisesRegex(ValueError, 'G6J_BASE_PHYSICAL_HASH_REFUSED'):
            replay_checked(r, lambda e: True, lambda: h[0])
        h[0] = r.identity.physical_hash
        with self.assertRaisesRegex(ValueError, 'G6J_REPLAY_HASH_REFUSED'):
            replay_checked(r, lambda e: True, lambda: h[0])
        j2 = Journal.open(self.path, -17, 201, ident().incarnation)
        j2.append(Mutation(1, 5, 6, 0, 0, 206, 42, 1), 205)
        with self.assertRaisesRegex(ValueError, 'G6J_EXTERNAL_WRITE_REFUSED'):
            j.append(Mutation(1, 5, 6, 0, 0, 206, 42, 1), 205)
        with self.path.open('ab') as f:
            f.write(b'EDIT\0\0\0')  # crash during unacknowledged record
        tail = recover(self.path)
        self.assertTrue(tail.torn_tail)
        self.assertEqual(tail.generation, 206)  # prior ACKs intact
        with self.assertRaisesRegex(ValueError, 'G6J_TORN_TAIL_REPAIR_REQUIRED'):
            Journal.open(self.path, -17, 201, ident().incarnation)
        corrupt = Path(self.tmp.name) / 'corrupt.g6j'
        corrupt.write_bytes(self.path.read_bytes()[:tail.valid_length])
        with corrupt.open('r+b') as f:
            f.seek(HEADER.size + 512*1024 + 10)
            f.write(b'\x7f')
        with self.assertRaisesRegex(ValueError, 'G6J_EDIT_INTEGRITY_REFUSED'):
            recover(corrupt)
        print('G6J_BYTES', r.valid_length, 'full_rewrite_bytes', (HEADER.size+512*1024)*200,
              'static_ticking_only=1 not_integrated_native_benchmark=1')

    def test_crash_orphan_stage_and_failed_publication_retry(self):
        # Simulate an old interrupted fixed-name stage and a crashed unique
        # stage. Neither may block a fresh, safely exclusive checkpoint.
        stale_fixed = self.path.with_name(self.path.name + '.staging')
        stale_fixed.write_bytes(b'previous-writer-unpublished')
        stale_unique = self.path.with_name('.' + self.path.name + '.g6j-dead.staging')
        stale_unique.write_bytes(b'crashed-before-publish')
        stages = list(self.path.parent.glob('.test.g6j.g6j-*.staging'))
        self.assertEqual(stages, [stale_unique])

        # A link failure is not a durable ACK and must clean up its own stage,
        # without modifying any unrelated crashed stage or creating a target.
        with mock.patch('gen006_storage_journal.os.link',
                        side_effect=OSError('G6J_INJECTED_LINK_FAILURE')):
            with self.assertRaisesRegex(OSError, 'G6J_INJECTED_LINK_FAILURE'):
                Journal.create(self.path, ident(), b'candidate-checkpoint')
        self.assertFalse(self.path.exists())
        self.assertEqual(list(self.path.parent.glob('.test.g6j.g6j-*.staging')),
                         [stale_unique])
        self.assertEqual(stale_fixed.read_bytes(), b'previous-writer-unpublished')

        Journal.create(self.path, ident(), b'committed-checkpoint')
        restored = recover(self.path)
        self.assertEqual(restored.checkpoint, b'committed-checkpoint')
        self.assertEqual(restored.identity, ident())
        self.assertEqual(stale_unique.read_bytes(), b'crashed-before-publish')
        self.assertEqual(stale_fixed.read_bytes(), b'previous-writer-unpublished')
        self.assertEqual(list(self.path.parent.glob('.test.g6j.g6j-*.staging')),
                         [stale_unique])
        with self.assertRaisesRegex(ValueError, 'G6J_DESTINATION_EXISTS'):
            Journal.create(self.path, ident(), b'overwrite-refused')
        self.assertEqual(recover(self.path).checkpoint, b'committed-checkpoint')

    def test_separate_process_abrupt_exit(self):
        subprocess.run([sys.executable, __file__, '--child', str(self.path)], check=True)
        r = recover(self.path)
        self.assertEqual((r.identity.x, r.identity.y, r.generation), (-17, 201, 6))
        self.assertEqual((r.edits[0].amount, r.edits[0].temperature), (17, 417))
        self.assertFalse(r.torn_tail)


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--child':
        j = Journal.create(Path(sys.argv[2]), ident(), baseline())
        j.append(Mutation(4, 7, 9, 17, 417, 6, 42, 0x123456789), 5)
        os._exit(0)  # no atexit, no final save, real child process
    unittest.main(verbosity=2)
