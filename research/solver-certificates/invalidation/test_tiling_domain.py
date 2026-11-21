"""B2-REGION-009: complete tile coverage is an admission precondition.

Exact-module regression, stdlib only. These tests exercise the research model,
not CyberSand native World or workers:
    cd research/solver-certificates/invalidation
    python3 -m unittest -v test_tiling_domain
"""
import unittest

from sparse_fence import EMPTY, ROCK, SAND, WATER, Fence, Packet, Sparse, State, full_step


def falling_source(width=4, height=4):
    state = State(width, height, [ROCK] * (width * height))
    state.cells[0] = SAND
    state.cells[width] = EMPTY
    return state


def committed(fence, events=()):
    for shard in reversed(range(fence.workers)):
        payload = tuple(events) if shard == 0 else ()
        fence.accept(Packet.make(
            fence.generation, fence.engine.state.tick, shard, payload))
    return fence.advance()


class TileCoverDomain(unittest.TestCase):
    def test_historical_negative_size_yields_empty_roster_and_false_skip(self):
        # Source-derived historical constructor formula, deliberately retained
        # as a NEGATIVE CONTROL rather than calling the now-guarded constructor.
        width = height = 4
        size = -10
        cols = (width + size - 1) // size
        rows = (height + size - 1) // size
        self.assertEqual((cols, rows), (0, 0))
        self.assertEqual(tuple(range(cols * rows)), ())
        before = falling_source()
        reference = before.copy()
        full_step(reference, ())
        # The historical zero-roster step could commit zero writes.
        wrong_skip = before.copy()
        wrong_skip.tick += 1
        self.assertNotEqual(wrong_skip, reference)
        self.assertEqual((wrong_skip.cells[0], wrong_skip.cells[4]), (SAND, EMPTY))
        self.assertEqual((reference.cells[0], reference.cells[4]), (EMPTY, SAND))

    def test_bad_tile_sizes_refuse_before_certificate_construction(self):
        invalid = (-10, -5, -1, 0, False, True, None, 1.0, 2.0, "2", b"2", (), object())
        for size in invalid:
            with self.subTest(tile_size=repr(size)):
                owner = falling_source()
                before = owner.copy()
                with self.assertRaisesRegex(ValueError, "positive tile size"):
                    Sparse(owner, tile_size=size)
                self.assertEqual(owner, before)

    def test_positive_integer_tiles_form_disjoint_complete_cover(self):
        # Finite independent challenge of the infinite quotient/remainder law.
        for width in range(1, 10):
            for height in range(1, 10):
                for size in range(1, 13):
                    with self.subTest(width=width, height=height, size=size):
                        sparse = Sparse(State(width, height, [ROCK] * (width * height)),
                                        tile_size=size)
                        cover = [i for roster in sparse.roster for i in roster]
                        self.assertEqual(len(cover), width * height)
                        self.assertEqual(sorted(cover), list(range(width * height)))
                        self.assertEqual(len(sparse.roster),
                                         ((width + size - 1) // size) *
                                         ((height + size - 1) // size))

    def test_complete_empty_packets_with_valid_partition_match_full_step(self):
        for size in (1, 2, 3, 4, 7, 100):
            for workers in (1, 4):
                with self.subTest(tile_size=size, workers=workers):
                    source = falling_source()
                    reference = source.copy()
                    fence = Fence(Sparse(source, tile_size=size), workers)
                    self.assertEqual(committed(fence), "COMMITTED")
                    full_step(reference, ())
                    self.assertEqual(fence.engine.state, reference)
                    self.assertEqual(reference.cells[4], SAND)

    def test_witnessed_writes_and_global_dependency_across_partitions(self):
        tape = ((), (("set", 0, 0, WATER),), (("pressure", 1),),
                (("pressure", 0),), (("unknown",),))
        for size in (1, 2, 5, 100):
            for workers in (1, 4):
                with self.subTest(tile_size=size, workers=workers):
                    reference = falling_source()
                    fence = Fence(Sparse(reference, tile_size=size), workers)
                    oracle = reference.copy()
                    for events in tape:
                        self.assertEqual(committed(fence, events), "COMMITTED")
                        full_step(oracle, tuple(events))
                        self.assertEqual(fence.engine.state, oracle)


if __name__ == "__main__":
    unittest.main()
