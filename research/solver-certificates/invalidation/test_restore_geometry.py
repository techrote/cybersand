"""B2-REGION-006: topology-identity falsifier and guarded restore.

Run at the Draft head:
    python3 -m unittest discover -s research/solver-certificates/invalidation -p 'test_*.py' -v
No native/worker/pressure-host claims: 1/4 shards are deterministic logical partitions.
"""
import unittest

from sparse_fence import (
    EMPTY, ROCK, WATER, Fence, Packet, Sparse, State, full_step,
)


def before_and_after_shapes():
    initial = State(4, 4, [ROCK] * 16)
    restored = State(8, 2, [ROCK] * 16)
    restored.cells[0] = WATER
    return initial, restored


class RestoreGeometryChallenge(unittest.TestCase):
    def test_original_same_cell_count_topology_counterexample(self):
        """Deliberately bypass the new guard to replay the OLD restore logic."""
        initial, restored = before_and_after_shapes()
        event = ("set", 0, 1, EMPTY)
        for workers in (1, 4):
            with self.subTest(workers=workers):
                unsafe = Sparse(initial, tile_size=2)
                unsafe.state = restored.copy()  # exactly the former restore assignment
                unsafe.reset_certificates()     # exactly the former certificate rebuild
                self.assertEqual(len(unsafe.roster), 4)
                self.assertEqual(unsafe.roster[2], (8, 9, 12, 13))
                self.assertEqual(unsafe.tile(8), 0)  # wake and roster disagree
                self.assertIn(2, unsafe.certified)

                reference = restored.copy()
                unsafe.step((event,), workers=workers)
                full_step(reference, (event,))
                self.assertEqual(reference.cells[8], WATER)
                self.assertEqual(unsafe.state.cells[8], EMPTY)
                self.assertNotEqual(unsafe.state, reference)
                self.assertEqual(
                    [i for i, (a, b) in enumerate(zip(
                        unsafe.state.cells, reference.cells)) if a != b],
                    [8],
                )

    def test_fenced_restore_refuses_before_receipt_retirement(self):
        initial, restored = before_and_after_shapes()
        for workers in (1, 4):
            with self.subTest(workers=workers):
                fence = Fence(Sparse(initial, tile_size=2), workers)
                for shard in range(workers):
                    events = (("set", 1, 1, ROCK),) if shard == 0 else ()
                    fence.accept(Packet.make(0, 0, shard, events))
                prior_state = fence.engine.state.copy()
                prior_packets = dict(fence.packets)
                prior_checks = dict(fence.accepted_checks)
                with self.assertRaisesRegex(ValueError, "source geometry"):
                    fence.restore(restored)
                self.assertEqual(fence.engine.state, prior_state)
                self.assertEqual(fence.generation, 0)
                self.assertEqual(fence.packets, prior_packets)
                self.assertEqual(fence.accepted_checks, prior_checks)
                self.assertEqual(fence.advance(), "COMMITTED")
                full_step(prior_state, (("set", 1, 1, ROCK),))
                self.assertEqual(fence.engine.state, prior_state)

    def test_direct_restore_refusal_and_bad_flat_length(self):
        initial, restored = before_and_after_shapes()
        engine = Sparse(initial, tile_size=2)
        before = engine.state.copy()
        for invalid in (restored, State(4, 4, [ROCK] * 15),
                        State(4, 4, tuple([ROCK] * 16))):
            with self.subTest(shape=(invalid.width, invalid.height),
                              length=len(invalid.cells)):
                with self.assertRaisesRegex(ValueError, "source geometry"):
                    engine.restore(invalid)
                self.assertEqual(engine.state, before)
                self.assertEqual(engine.cols, 2)
                self.assertEqual(engine.roster[2], (8, 9, 12, 13))

    def test_same_shape_restore_and_source_typed_continuation(self):
        initial, _ = before_and_after_shapes()
        for workers in (1, 4):
            with self.subTest(workers=workers):
                fence = Fence(Sparse(initial, tile_size=2), workers)
                restored = State(4, 4, [ROCK] * 16, tick=4)
                restored.cells[0] = WATER
                fence.restore(restored)
                self.assertEqual(fence.generation, 1)
                self.assertEqual(fence.engine.state.tick, 4)
                event = ("set", 0, 1, EMPTY)
                for shard in range(workers):
                    fence.accept(Packet.make(
                        fence.generation, fence.engine.state.tick, shard,
                        (event,) if shard == 0 else ()))
                self.assertEqual(fence.advance(), "COMMITTED")
                full_step(restored, (event,))
                self.assertEqual(fence.engine.state, restored)
                self.assertEqual(restored.cells[4], WATER)


if __name__ == "__main__":
    unittest.main()
