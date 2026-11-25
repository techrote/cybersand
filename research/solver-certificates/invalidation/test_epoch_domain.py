"""B2-REGION-005: finite witness-epoch closure and atomic exhaustion refusal.

Source-bound research model only. No native worker or CyberSand speed claim.
Run: python3 -m unittest -v test_epoch_domain
"""
import unittest

from sparse_fence import (
    Fence, Packet, Sparse, MAX_WITNESS_EPOCH, full_step, initial,
    STEAM,
)


class EpochDomainTests(unittest.TestCase):
    def _fence(self, workers, tick=0):
        s = initial("quiet")
        s.tick = tick
        return Fence(Sparse(s), workers)

    def _complete(self, fence, events=()):
        for shard in reversed(range(fence.workers)):
            fence.accept(Packet.make(
                fence.generation, fence.engine.state.tick, shard,
                events if shard == 0 else (),
            ))

    def test_last_representable_tick_is_atomic_refusal(self):
        # Before the fix, complete packets at MAX were accepted and commit
        # incremented owner state to MAX+1; subsequent Packet.make refused.
        for workers in (1, 4):
            with self.subTest(workers=workers):
                fence = self._fence(workers, MAX_WITNESS_EPOCH)
                for shard in range(workers - 1):
                    fence.accept(Packet.make(0, MAX_WITNESS_EPOCH, shard, ()))
                before = fence.engine.state.copy()
                self.assertEqual(fence.advance(), "BLOCKED")
                self.assertEqual(fence.engine.state, before)
                fence.accept(Packet.make(
                    0, MAX_WITNESS_EPOCH, workers - 1, (("pressure", 1),)
                ))
                before_packets = dict(fence.packets)
                before_checks = dict(fence.accepted_checks)
                with self.assertRaisesRegex(ValueError, "successor domain"):
                    fence.advance()
                self.assertEqual(fence.engine.state, before)
                self.assertEqual(fence.packets, before_packets)
                self.assertEqual(fence.accepted_checks, before_checks)
                with self.assertRaises(ValueError):
                    Packet.make(0, MAX_WITNESS_EPOCH + 1, 0, ())

    def test_preceding_tick_commits_and_matches_full_state(self):
        for workers in (1, 4):
            with self.subTest(workers=workers):
                fence = self._fence(workers, MAX_WITNESS_EPOCH - 1)
                oracle = fence.engine.state.copy()
                events = (("pressure", 1),)
                self._complete(fence, events)
                self.assertEqual(fence.advance(), "COMMITTED")
                full_step(oracle, events)
                self.assertEqual(fence.engine.state, oracle)
                self.assertEqual(fence.engine.state.tick, MAX_WITNESS_EPOCH)
                self.assertIn(STEAM, fence.engine.state.cells)
                self._complete(fence)
                before = fence.engine.state.copy()
                with self.assertRaisesRegex(ValueError, "successor domain"):
                    fence.advance()
                self.assertEqual(fence.engine.state, before)

    def test_exhausted_rollback_generation_preserves_receipts(self):
        for workers in (1, 4):
            with self.subTest(workers=workers):
                fence = self._fence(workers)
                # Direct mutation represents a finite protocol owner already
                # at its final admissible generation, not an external attacker.
                fence.generation = MAX_WITNESS_EPOCH
                self._complete(fence, (("set", 3, 1, 0),))
                before = fence.engine.state.copy()
                packets = dict(fence.packets)
                checks = dict(fence.accepted_checks)
                with self.assertRaisesRegex(ValueError, "restoration epoch"):
                    fence.restore(initial("mixed"))
                self.assertEqual(fence.generation, MAX_WITNESS_EPOCH)
                self.assertEqual(fence.engine.state, before)
                self.assertEqual(fence.packets, packets)
                self.assertEqual(fence.accepted_checks, checks)

    def test_last_valid_rollback_then_exhaustion(self):
        for workers in (1, 4):
            fence = self._fence(workers)
            fence.generation = MAX_WITNESS_EPOCH - 1
            fence.restore(initial("quiet"))
            self.assertEqual(fence.generation, MAX_WITNESS_EPOCH)
            self._complete(fence)
            self.assertEqual(fence.advance(), "COMMITTED")
            before = fence.engine.state.copy()
            with self.assertRaisesRegex(ValueError, "restoration epoch"):
                fence.restore(initial("mixed"))
            self.assertEqual(fence.engine.state, before)

    def test_bad_restored_tick_and_owner_tick_refuse(self):
        for workers in (1, 4):
            for bad_tick in (-1, MAX_WITNESS_EPOCH + 1, 1 << 100, True):
                with self.subTest(workers=workers, tick=bad_tick):
                    with self.assertRaisesRegex(ValueError, "initial owner tick"):
                        self._fence(workers, bad_tick)
                    fence = self._fence(workers)
                    self._complete(fence)
                    before = fence.engine.state.copy()
                    packets = dict(fence.packets)
                    bad_snapshot = initial("mixed")
                    bad_snapshot.tick = bad_tick
                    with self.assertRaisesRegex(ValueError, "restoration epoch"):
                        fence.restore(bad_snapshot)
                    self.assertEqual(fence.engine.state, before)
                    self.assertEqual(fence.packets, packets)
                    self.assertEqual(fence.generation, 0)


if __name__ == "__main__":
    unittest.main()
