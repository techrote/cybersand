"""B2-REGION-007: exact-module restored-body custody + historical negative.

Run at the published Draft head:
    python3 -m unittest discover -s research/solver-certificates/invalidation -p 'test_*.py' -v

Logical 1/4 shard loops are NOT native CyberSand workers. Research only.
"""
import unittest

from sparse_fence import (
    EMPTY, ROCK, SAND, Fence, Packet, Sparse, State, full_step,
)


def fixture():
    cells = [ROCK] * 16
    cells[0], cells[4] = SAND, EMPTY
    caller_body = {0}
    return State(4, 4, cells, body=caller_body), caller_body


def complete(fence, events=()):
    for shard in range(fence.workers):
        fence.accept(Packet.make(
            fence.generation, fence.engine.state.tick, shard,
            events if shard == 0 else (),
        ))
    return fence.advance()


class RestoredBodyCustody(unittest.TestCase):
    def test_deliberate_old_unowned_path_is_unsound_one_tick(self):
        # Bypass State.copy intentionally to reconstruct the historical
        # restore assignment that retained the caller's mutable set.
        for workers in (1, 4):
            with self.subTest(workers=workers):
                snapshot, alias = fixture()
                unsafe = Sparse(State(4, 4, [ROCK] * 16), tile_size=2)
                unsafe.state = State(4, 4, snapshot.cells.copy(), body=alias)
                unsafe.reset_certificates()
                self.assertIn(0, unsafe.certified)
                alias.clear()
                oracle = State(4, 4, snapshot.cells.copy(),
                               body=frozenset(), tick=0)
                unsafe.step((), workers=workers)
                full_step(oracle, ())
                self.assertEqual(unsafe.state.cells[4], EMPTY)
                self.assertEqual(oracle.cells[4], SAND)
                self.assertNotEqual(unsafe.state, oracle)

    def test_restored_set_is_deep_owned_then_witnessed_body_clear_wakes(self):
        for workers in (1, 4):
            with self.subTest(workers=workers):
                source, caller_mask = fixture()
                fence = Fence(Sparse(State(4, 4, [ROCK] * 16),
                                     tile_size=2), workers)
                fence.restore(source)
                self.assertEqual(fence.generation, 1)
                self.assertIs(type(fence.engine.state.body), frozenset)
                self.assertEqual(fence.engine.state.body, frozenset({0}))
                caller_mask.clear()  # unversioned external source mutation
                self.assertEqual(fence.engine.state.body, frozenset({0}))
                oracle = State(4, 4, source.cells.copy(),
                               body=frozenset({0}))
                for events in ((), (("body", ()),), ()):
                    self.assertEqual(complete(fence, events), "COMMITTED")
                    full_step(oracle, events)
                    self.assertEqual(fence.engine.state, oracle)
                self.assertEqual(oracle.cells[4], SAND)

    def test_construction_copy_owns_body_before_initial_certification(self):
        for workers in (1, 4):
            source, mask = fixture()
            engine = Sparse(source, tile_size=2)
            self.assertIs(type(engine.state.body), frozenset)
            mask.clear()
            oracle = engine.state.copy()
            engine.step((), workers=workers)
            full_step(oracle, ())
            self.assertEqual(engine.state, oracle)
            self.assertEqual(engine.state.cells[0], SAND)

    def test_invalid_body_refuses_restore_atomically_with_receipts(self):
        class Tripwire:
            called = False
            def __iter__(self):
                self.called = True
                raise AssertionError("opaque body must not be enumerated")

        for workers in (1, 4):
            fence = Fence(Sparse(State(4, 4, [ROCK] * 16),
                                 tile_size=2), workers)
            for shard in range(workers):
                fence.accept(Packet.make(0, 0, shard, ()))
            before = fence.engine.state.copy()
            packets, checks = dict(fence.packets), dict(fence.accepted_checks)
            hostile = Tripwire()
            for mask in (hostile, [0], {16}, {-1}, {True}, {0, 16}):
                with self.subTest(workers=workers, mask=type(mask).__name__):
                    candidate = State(4, 4, before.cells.copy(), body=mask)
                    with self.assertRaisesRegex(ValueError, "body footprint"):
                        fence.restore(candidate)
                    self.assertEqual(fence.generation, 0)
                    self.assertEqual(fence.engine.state, before)
                    self.assertEqual(fence.packets, packets)
                    self.assertEqual(fence.accepted_checks, checks)
                    with self.assertRaisesRegex(ValueError, "body footprint"):
                        fence.engine.restore(candidate)
                    self.assertEqual(fence.engine.state, before)
            self.assertFalse(hostile.called)
            self.assertEqual(fence.advance(), "COMMITTED")
            full_step(before, ())
            self.assertEqual(fence.engine.state, before)

    def test_frozenset_input_and_witnessed_actor_changes_remain_supported(self):
        for workers in (1, 4):
            source, _ = fixture()
            source.body = frozenset({0})
            fence = Fence(Sparse(source, tile_size=2), workers)
            oracle = fence.engine.state.copy()
            for events in ((), (("body", ()),), ()):
                self.assertEqual(complete(fence, events), "COMMITTED")
                full_step(oracle, events)
                self.assertEqual(fence.engine.state, oracle)
            self.assertEqual(fence.engine.state.cells[4], SAND)


if __name__ == "__main__":
    unittest.main()
