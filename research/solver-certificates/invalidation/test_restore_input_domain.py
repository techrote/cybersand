"""B2-REGION-008: finite source-alphabet admission and restore atomicity.

Research-only model; logical 1/4 shards are not native worker threads.
Run: python3 -m unittest -v test_restore_input_domain
"""
import unittest

from sparse_fence import (
    EMPTY, ROCK, SAND, STEAM, WATER, Fence, Packet, Sparse, State, full_step,
)


def completed_packets(fence, events=()):
    for shard in range(fence.workers):
        fence.accept(Packet.make(
            fence.generation, fence.engine.state.tick, shard,
            events if shard == 0 else (),
        ))
    return fence.advance()


class InputDomainRestore(unittest.TestCase):
    def _accepted(self, workers):
        fence = Fence(Sparse(State(4, 4, [ROCK] * 16), tile_size=2), workers)
        for shard in range(workers):
            fence.accept(Packet.make(0, 0, shard, ()))
        return fence

    def test_historical_assignment_before_proof_can_partially_publish(self):
        # Deliberately reconstruct the old unsafe order, not a call to the
        # now-guarded restore implementation. Retain as negative evidence.
        class Poison:
            probes = 0
            def __eq__(self, _):
                self.probes += 1
                raise RuntimeError("foreign cell compared")

        for workers in (1, 4):
            with self.subTest(workers=workers):
                fence = self._accepted(workers)
                before = fence.engine.state
                unsafe = State(4, 4, [Poison()] + [ROCK] * 15)
                fence.engine.state = unsafe  # historical publish-before-proof
                with self.assertRaisesRegex(RuntimeError, "foreign cell compared"):
                    fence.engine.reset_certificates()
                self.assertIs(fence.engine.state, unsafe)
                self.assertIsNot(fence.engine.state, before)
                self.assertEqual(fence.generation, 0)
                self.assertEqual(len(fence.packets), workers)
                self.assertEqual(unsafe.cells[0].probes, 1)

    def test_opaque_cell_restore_refuses_atomically_without_comparison(self):
        class Poison:
            comparisons = 0
            def __eq__(self, _):
                self.comparisons += 1
                raise AssertionError("noncanonical leaf must never be compared")

        for workers in (1, 4):
            with self.subTest(workers=workers):
                fence = self._accepted(workers)
                before = fence.engine.state.copy()
                packets = dict(fence.packets)
                checks = dict(fence.accepted_checks)
                certified = set(fence.engine.certified)
                active = set(fence.engine.active)
                poison = Poison()
                candidate = State(4, 4, [poison] + [ROCK] * 15)
                with self.assertRaisesRegex(ValueError, "material snapshot"):
                    fence.restore(candidate)
                with self.assertRaisesRegex(ValueError, "material snapshot"):
                    fence.engine.restore(candidate)
                self.assertEqual(poison.comparisons, 0)
                self.assertEqual(fence.generation, 0)
                self.assertEqual(fence.engine.state, before)
                self.assertEqual(fence.packets, packets)
                self.assertEqual(fence.accepted_checks, checks)
                self.assertEqual(fence.engine.certified, certified)
                self.assertEqual(fence.engine.active, active)
                self.assertEqual(fence.advance(), "COMMITTED")
                full_step(before, ())
                self.assertEqual(fence.engine.state, before)

    def test_material_domain_refuses_unsupported_restored_values(self):
        bad_cells = [
            [True] + [ROCK] * 15,
            [None] + [ROCK] * 15,
            [8] + [ROCK] * 15,
            [-1] + [ROCK] * 15,
            [ROCK] * 15,
            [ROCK] * 17,
            type("ListSubclass", (list,), {})([ROCK] * 16),
        ]
        for workers in (1, 4):
            fence = self._accepted(workers)
            before = fence.engine.state.copy()
            checks = dict(fence.accepted_checks)
            for cells in bad_cells:
                with self.subTest(workers=workers, values=repr(cells)[:35]):
                    with self.assertRaisesRegex(ValueError, "material snapshot"):
                        fence.restore(State(4, 4, cells))
                    self.assertEqual(fence.engine.state, before)
                    self.assertEqual(fence.generation, 0)
                    self.assertEqual(fence.accepted_checks, checks)

    def test_pressure_domain_refuses_unknown_and_boolean_values(self):
        for workers in (1, 4):
            fence = self._accepted(workers)
            before = fence.engine.state.copy()
            for pressure in (True, None, 2, -1, 1.0, "1"):
                with self.subTest(workers=workers, pressure=pressure):
                    with self.assertRaisesRegex(ValueError, "pressure snapshot"):
                        fence.restore(State(4, 4, [ROCK] * 16, pressure=pressure))
                    self.assertEqual(fence.engine.state, before)
                    self.assertEqual(fence.generation, 0)
            self.assertEqual(len(fence.packets), workers)

    def test_valid_restored_source_and_pressure_witness_replay(self):
        for workers in (1, 4):
            with self.subTest(workers=workers):
                fence = self._accepted(workers)
                snapshot = State(4, 4, [ROCK] * 16, pressure=1, tick=0)
                snapshot.cells[1] = WATER
                snapshot.cells[0], snapshot.cells[4] = SAND, EMPTY
                fence.restore(snapshot)
                oracle = snapshot.copy()
                self.assertEqual(fence.generation, 1)
                self.assertEqual(fence.packets, {})
                self.assertEqual(fence.accepted_checks, {})
                snapshot.cells[1] = ROCK  # state owns its copied cells
                for events in ((), (("pressure", 0),), (("set", 0, 0, ROCK),)):
                    self.assertEqual(completed_packets(fence, events), "COMMITTED")
                    full_step(oracle, events)
                    self.assertEqual(fence.engine.state, oracle)
                self.assertEqual(oracle.pressure, 0)
                self.assertEqual(oracle.cells[1], WATER)  # steam recondenses


if __name__ == "__main__":
    unittest.main()
