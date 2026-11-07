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

    def test_same_length_replacement_refuses_stale_handle(self):
        stale = Journal.create(self.path, ident(), b'checkpoint-a')
        other = self.path.with_name('other.g6j')
        foreign = Identity(ident().x, ident().y, ident().incarnation + 1,
                           ident().generation, ident().tick, ident().physical_hash)
        Journal.create(other, foreign, b'checkpoint-b')
        self.assertEqual(self.path.stat().st_size, other.stat().st_size)
        # External owner improperly replaces the path without closing a stale
        # Journal handle. The stale handle must not damage the new incarnation.
        os.replace(other, self.path)
        with self.assertRaisesRegex(ValueError, 'G6J_EXTERNAL_WRITE_REFUSED'):
            stale.append(Mutation(1, 1, 1, 0, 0, 6, 42, 1), 5)
        preserved = recover(self.path)
        self.assertEqual(preserved.identity, foreign)
        self.assertEqual(preserved.checkpoint, b'checkpoint-b')
        self.assertEqual(preserved.edits, ())

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

    def test_explicit_torn_rollover_preserves_acknowledged_prefix(self):
        j = Journal.create(self.path, ident(), b'native-source-checkpoint')
        first = Mutation(4, 7, 9, 17, 417, 6, 42, 0x123456789)
        j.append(first, 5)
        # A crash interrupts an unacknowledged next record. Keep the entire
        # original file as failure evidence; NEVER truncate it in place.
        with self.path.open('ab') as f:
            f.write(b'EDIT\\x00\\x00\\x00')
        original = self.path.read_bytes()
        torn = recover(self.path)
        self.assertTrue(torn.torn_tail)
        self.assertEqual(torn.edits, (first,))
        with self.assertRaisesRegex(ValueError, 'G6J_TORN_TAIL_REPAIR_REQUIRED'):
            Journal.open(self.path, ident().x, ident().y, ident().incarnation)

        successor = self.path.with_name('repaired.g6j')
        checked = []

        def verify_staged(state):
            checked.append(state)
            return state.identity == ident() and state.edits == (first,)

        with self.assertRaisesRegex(ValueError, 'G6J_IDENTITY_REFUSED'):
            Journal.rollover_torn_tail(self.path, successor, -16, 201,
                                       ident().incarnation, 6, verify_staged)
        with self.assertRaisesRegex(ValueError, 'G6J_STALE_GENERATION'):
            Journal.rollover_torn_tail(self.path, successor, -17, 201,
                                       ident().incarnation, 7, verify_staged)
        with self.assertRaisesRegex(ValueError, 'G6J_ROLLOVER_NATIVE_REPLAY_REFUSED'):
            Journal.rollover_torn_tail(self.path, successor, -17, 201,
                                       ident().incarnation, 6, lambda _: False)
        with self.assertRaisesRegex(ValueError, 'G6J_ROLLOVER_PATH_REFUSED'):
            Journal.rollover_torn_tail(self.path, self.path, -17, 201,
                                       ident().incarnation, 6, verify_staged)
        self.assertFalse(successor.exists())
        self.assertEqual(self.path.read_bytes(), original)

        # Interrupted publication is retryable; the original evidence stays
        # untouched and unique failed stages are cleaned.
        with mock.patch('gen006_storage_journal.os.link',
                        side_effect=OSError('G6J_ROLLOVER_LINK_FAILURE')):
            with self.assertRaisesRegex(OSError, 'G6J_ROLLOVER_LINK_FAILURE'):
                Journal.rollover_torn_tail(self.path, successor, -17, 201,
                                           ident().incarnation, 6, verify_staged)
        self.assertFalse(successor.exists())
        self.assertEqual(list(self.path.parent.glob('.repaired.g6j.g6j-*.staging')), [])

        # A source changed during physical replay cannot be promoted.
        def mutating_replay(state):
            with self.path.open('ab') as f:
                f.write(b'x')
            return True

        with self.assertRaisesRegex(ValueError, 'G6J_ROLLOVER_SOURCE_CHANGED'):
            Journal.rollover_torn_tail(self.path, successor, -17, 201,
                                       ident().incarnation, 6, mutating_replay)
        self.assertFalse(successor.exists())
        self.path.write_bytes(original)

        repaired = Journal.rollover_torn_tail(self.path, successor, -17, 201,
                                               ident().incarnation, 6, verify_staged)
        self.assertEqual(self.path.read_bytes(), original)
        self.assertEqual(recover(successor).checkpoint, torn.checkpoint)
        self.assertEqual(recover(successor).edits, torn.edits)
        self.assertFalse(recover(successor).torn_tail)
        self.assertGreaterEqual(len(checked), 2)
        repaired.append(Mutation(1, 4, 5, 0, 0, 7, 42, 0x887766), 6)
        self.assertEqual(recover(successor).generation, 7)
        self.assertEqual(recover(self.path).generation, 6)
        with self.assertRaisesRegex(ValueError, 'G6J_DESTINATION_EXISTS'):
            Journal.rollover_torn_tail(self.path, successor, -17, 201,
                                       ident().incarnation, 6, verify_staged)

        bad = self.path.with_name('corrupt-complete.g6j')
        bad.write_bytes(original[:torn.valid_length])
        raw = bytearray(bad.read_bytes())
        raw[-1] ^= 0x80
        bad.write_bytes(raw)
        with self.assertRaisesRegex(ValueError, 'G6J_EDIT_INTEGRITY_REFUSED'):
            Journal.rollover_torn_tail(
                bad, self.path.with_name('bad-successor.g6j'), -17, 201,
                ident().incarnation, 6, verify_staged)

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
