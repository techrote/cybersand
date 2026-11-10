"""Independent adversarial controls for B2-REGION-004 accepted-effect snapshots.

Research-only. Run from this directory with:
  python3 -m unittest -v test_sparse_fence_witness
No native worker/runtime qualification is implied.
"""
import unittest

from sparse_fence import (
    EMPTY, ROCK, STEAM, WATER, Fence, Packet, Sparse, digest, freeze_events,
    full_step, initial,
)


class WitnessTests(unittest.TestCase):
    def _replay(self, workers, original, mutate):
        oracle = initial("quiet")
        fence = Fence(Sparse(oracle), workers)
        expected = freeze_events([original])
        # Bypass Packet.make intentionally: model an externally supplied nested
        # mutable Packet whose digest was valid at admission.
        raw = [original]
        packet = Packet(0, 0, 0, tuple(raw), digest(0, 0, 0, tuple(raw)))
        fence.accept(packet)
        self.assertEqual(fence.packets[0].events, expected)
        mutate(original)
        self.assertNotEqual(packet.check, digest(0, 0, 0, packet.events))
        self.assertEqual(fence.packets[0].events, expected)
        for shard in reversed(range(1, workers)):
            fence.accept(Packet.make(0, 0, shard, ()))
        self.assertEqual(fence.advance(), "COMMITTED")
        full_step(oracle, expected)
        self.assertEqual(fence.engine.state, oracle)
        self.assertEqual(fence.packets, {})
        self.assertEqual(fence.accepted_checks, {})
        return fence.engine.state

    def test_post_accept_nested_mutation_matches_full_oracle_1_and_4(self):
        for workers in (1, 4):
            with self.subTest(workers=workers, event="remote pressure"):
                state = self._replay(workers, ["pressure", 1],
                                     lambda e: e.__setitem__(1, 0))
                self.assertEqual(state.pressure, 1)
                self.assertIn(STEAM, state.cells)
            with self.subTest(workers=workers, event="edit"):
                self._replay(workers, ["set", 3, 1, WATER],
                             lambda e: e.__setitem__(3, ROCK))
            with self.subTest(workers=workers, event="nested body mask"):
                state = self._replay(workers, ["body", [[7, 7], [8, 7]]],
                                     lambda e: e[1][0].__setitem__(0, 10))
                self.assertIn(7 * 24 + 7, state.body)
                self.assertNotIn(7 * 24 + 10, state.body)
            with self.subTest(workers=workers, event="explosion"):
                self._replay(workers, ["explode", 5, 5, 2],
                             lambda e: e.__setitem__(3, 0))

    def test_packet_make_owns_original_before_admission(self):
        for workers in (1, 4):
            source = [["pressure", 1]]
            packet = Packet.make(0, 0, 0, source)
            source[0][1] = 0
            self.assertEqual(packet.events, (("pressure", 1),))
            fence = Fence(Sparse(initial("quiet")), workers)
            fence.accept(packet)
            for shard in range(1, workers):
                fence.accept(Packet.make(0, 0, shard, ()))
            self.assertEqual(fence.advance(), "COMMITTED")
            self.assertEqual(fence.engine.state.pressure, 1)

    def test_changed_witness_before_admission_refuses(self):
        raw = [["pressure", 1]]
        packet = Packet(0, 0, 0, tuple(raw), digest(0, 0, 0, tuple(raw)))
        raw[0][1] = 0
        fence = Fence(Sparse(initial("quiet")), 1)
        before = fence.engine.state.copy()
        with self.assertRaisesRegex(ValueError, "witness"):
            fence.accept(packet)
        self.assertEqual(fence.engine.state, before)

    def test_replaced_retained_packet_cannot_supply_new_checksum(self):
        for workers in (1, 4):
            fence = Fence(Sparse(initial("quiet")), workers)
            fence.accept(Packet.make(0, 0, 0, (("pressure", 1),)))
            for shard in range(1, workers):
                fence.accept(Packet.make(0, 0, shard, ()))
            before = fence.engine.state.copy()
            # A replacement with its OWN valid digest is not the original
            # admission witness. Do not partially publish on final-barrier drift.
            fence.packets[0] = Packet.make(0, 0, 0, (("pressure", 0),))
            with self.assertRaisesRegex(ValueError, "identity drift"):
                fence.advance()
            self.assertEqual(fence.engine.state, before)
            self.assertEqual(fence.engine.state.tick, 0)
            fence.restore(before)
            self.assertEqual(fence.accepted_checks, {})
            with self.assertRaises(ValueError):
                fence.accept(Packet.make(0, 0, 0, ()))
            for shard in range(workers):
                fence.accept(Packet.make(fence.generation, 0, shard, ()))
            self.assertEqual(fence.advance(), "COMMITTED")

    def test_final_barrier_payload_drift_is_atomic(self):
        fence = Fence(Sparse(initial("quiet")), 4)
        for shard in range(4):
            fence.accept(Packet.make(0, 0, shard,
                                     (("set", 3, 1, WATER),) if shard == 0 else ()))
        before = fence.engine.state.copy()
        witness = fence.packets[0]
        # Simulate illicit direct replacement of the stored record without
        # changing the trusted admission witness or completing a new epoch.
        fence.packets[0] = Packet(0, 0, 0, (("set", 3, 1, ROCK),), witness.check)
        with self.assertRaisesRegex(ValueError, "payload drift"):
            fence.advance()
        self.assertEqual(fence.engine.state, before)

    def test_bounded_grammar_declines_unbounded_and_hostile_inputs(self):
        class Tripwire:
            called = False
            def __iter__(self):
                self.called = True
                raise AssertionError("must never enumerate a hostile source")
        bad = Tripwire()
        with self.assertRaises(ValueError):
            Packet.make(0, 0, 0, bad)
        self.assertFalse(bad.called)
        for events in (
            [["unknown"]] * 25,
            [["body", [[0, 0]] * 33]],
            [["body", [[True, 0]]]],
            [["pressure", True]],
            [["set", 1, 1, object()]],
            [["unexpected"]],
        ):
            with self.subTest(events=str(events)[:50]):
                with self.assertRaises(ValueError):
                    Packet.make(0, 0, 0, events)

    def test_incomplete_barrier_unknown_and_rollback(self):
        oracle = initial("quiet")
        fence = Fence(Sparse(oracle), 4)
        for shard in range(3):
            fence.accept(Packet.make(0, 0, shard, ()))
        self.assertEqual(fence.advance(), "BLOCKED")
        self.assertEqual(fence.engine.state, oracle)
        packet = Packet.make(0, 0, 3, (("unknown",),))
        fence.accept(packet)
        self.assertEqual(fence.advance(), "COMMITTED")
        full_step(oracle, (("unknown",),))
        self.assertEqual(fence.engine.state, oracle)
        self.assertGreater(fence.engine.counts.global_fallbacks, 0)
        fence.restore(initial("quiet"))
        self.assertEqual(fence.accepted_checks, {})
        with self.assertRaises(ValueError):
            fence.accept(packet)


if __name__ == "__main__":
    unittest.main()
