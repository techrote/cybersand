"""B2-REGION-003: sparse, barrier-fenced fixed-point reuse. RESEARCH MODEL ONLY.

Not CyberSand World, PressureFlow or a native performance implementation. No
cryptographic provenance: SHA256 is a local mutation sentinel, not an authority.
Run: python3 sparse_fence.py
"""
from __future__ import annotations

from dataclasses import dataclass, field
from hashlib import sha256
import json
import random
import unittest

EMPTY, SAND, WATER, ROCK, WOOD, FIRE, ASH, STEAM = range(8)


@dataclass
class State:
    width: int
    height: int
    cells: list[int]
    body: frozenset[int] = frozenset()
    pressure: int = 0
    tick: int = 0

    def copy(self):
        return State(self.width, self.height, self.cells.copy(), self.body, self.pressure, self.tick)

    def index(self, x, y):
        if not (0 <= x < self.width and 0 <= y < self.height):
            raise ValueError("outside test grid")
        return y * self.width + x


def rule(s: State, i: int, phase: int) -> int:
    w, h = s.width, s.height
    x, y = i % w, i // w
    c = s.cells[i]
    if c in (WOOD, FIRE):
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            xx, yy = x + dx, y + dy
            if 0 <= xx < w and 0 <= yy < h:
                neighbour = s.cells[yy * w + xx]
                if c == WOOD and neighbour == FIRE:
                    return FIRE
                if c == FIRE and neighbour == WATER:
                    return ASH
    if c == WATER and s.pressure:
        return STEAM
    if c == STEAM and not s.pressure:
        return WATER
    top_y = y if y % 2 == phase else y - 1
    if top_y < 0 or top_y + 1 >= h:
        return c
    top, bottom = top_y * w + x, (top_y + 1) * w + x
    if (top not in s.body and bottom not in s.body
            and s.cells[top] in (SAND, WATER) and s.cells[bottom] == EMPTY):
        return EMPTY if i == top else s.cells[top]
    return c


def events_apply(s: State, events: tuple[tuple, ...]):
    touched = set()
    global_wake = False
    for e in events:
        kind = e[0]
        if kind == "set":
            _, x, y, value = e
            if value not in range(8):
                raise ValueError("bad material")
            i = s.index(x, y)
            s.cells[i] = value
            touched.add(i)  # ABA/redundant writes are still producer witnesses
        elif kind == "explode":
            _, cx, cy, radius = e
            if not (0 <= radius <= 3):
                raise ValueError("bounded explosion required")
            for y in range(max(0, cy-radius), min(s.height, cy+radius+1)):
                for x in range(max(0, cx-radius), min(s.width, cx+radius+1)):
                    if (x-cx)**2 + (y-cy)**2 <= radius*radius:
                        i = s.index(x, y)
                        s.cells[i] = EMPTY
                        touched.add(i)
        elif kind == "body":
            _, positions = e
            mask = frozenset(s.index(x, y) for x, y in positions)
            touched.update(s.body ^ mask)
            s.body = mask
        elif kind == "pressure":
            if e[1] not in (0, 1):
                raise ValueError("unsupported pressure input")
            global_wake |= (s.pressure != e[1])
            s.pressure = e[1]
        elif kind == "unknown":
            global_wake = True
        else:
            raise ValueError("unmodelled event: conservative refusal")
    return touched, global_wake


def full_step(s: State, events: tuple[tuple, ...]):
    events_apply(s, events)
    s.cells = [rule(s, i, s.tick % 2) for i in range(len(s.cells))]
    s.tick += 1


@dataclass
class Counts:
    initial_probes: int = 0
    rule_calls: int = 0
    recert_probes: int = 0
    halo_sites: int = 0
    tile_visits: int = 0
    cell_writes: int = 0
    invalidations: int = 0
    false_positive_invalidations: int = 0  # offline diagnostic only
    diagnostic_probes: int = 0
    global_fallbacks: int = 0
    packets: int = 0


class Sparse:
    """One-time whole-grid proof, then O(active tiles + touched halos) loops.

    No per-tick cell snapshot, output buffer, full comparison or tile census.
    Only safe for pure synchronous bounded-read stages with all writes witnessed.
    """
    def __init__(self, state: State, tile_size: int = 4, diagnostic: bool = False):
        self.state = state.copy()
        self.tile_size = tile_size
        self.diagnostic = diagnostic
        self.cols = (state.width + tile_size - 1) // tile_size
        self.rows = (state.height + tile_size - 1) // tile_size
        self.roster = tuple(tuple(self._indices(t)) for t in range(self.cols*self.rows))
        self.counts = Counts()
        self.certified = set()
        self.active = set()
        self.reset_certificates()

    def _indices(self, tile):
        x0 = (tile % self.cols) * self.tile_size
        y0 = (tile // self.cols) * self.tile_size
        for y in range(y0, min(y0+self.tile_size, self.state.height)):
            for x in range(x0, min(x0+self.tile_size, self.state.width)):
                yield y*self.state.width+x

    def tile(self, i):
        x, y = i % self.state.width, i // self.state.width
        return y//self.tile_size*self.cols + x//self.tile_size

    def stable(self, tile, counter="recert_probes"):
        for i in self.roster[tile]:
            for phase in (0, 1):
                setattr(self.counts, counter, getattr(self.counts, counter)+1)
                if rule(self.state, i, phase) != self.state.cells[i]:
                    return False
        return True

    def reset_certificates(self):
        self.certified.clear()
        self.active.clear()
        for tile in range(len(self.roster)):
            if self.stable(tile, "initial_probes"):
                self.certified.add(tile)
            else:
                self.active.add(tile)

    def revoke(self, touched, global_wake):
        if global_wake:
            affected = set(range(len(self.roster)))
            self.counts.global_fallbacks += 1
        else:
            affected = set()
            w, h = self.state.width, self.state.height
            for i in touched:
                x, y = i % w, i // w
                for yy in range(max(0, y-1), min(h, y+2)):
                    for xx in range(max(0, x-1), min(w, x+2)):
                        self.counts.halo_sites += 1
                        affected.add(self.tile(yy*w+xx))
        revoked = self.certified & affected
        self.counts.invalidations += len(revoked)
        self.certified.difference_update(affected)
        self.active.update(affected)
        # Instrumentation is deliberately EXCLUDED from online cost.
        for t in revoked if self.diagnostic else ():
            if self.stable(t, "diagnostic_probes"):
                self.counts.false_positive_invalidations += 1

    def step(self, events=(), workers=1):
        if workers not in (1, 4):
            raise ValueError("only 1 or 4 logical partitions")
        touched, global_wake = events_apply(self.state, tuple(events))
        self.revoke(touched, global_wake)
        pending = {}  # sparse write set, committed AFTER all reads
        active = sorted(self.active)
        for shard in range(workers):
            for tile in active:
                if tile % workers != shard:
                    continue
                self.counts.tile_visits += 1
                for i in self.roster[tile]:
                    self.counts.rule_calls += 1
                    value = rule(self.state, i, self.state.tick % 2)
                    if value != self.state.cells[i]:
                        pending[i] = value
        for i, v in pending.items():
            self.state.cells[i] = v
            self.counts.cell_writes += 1
        self.state.tick += 1
        self.revoke(set(pending), False)
        for tile in tuple(sorted(self.active)):
            if self.stable(tile):
                self.active.remove(tile)
                self.certified.add(tile)
        return len(active), len(pending)

    def restore(self, snapshot: State):
        self.state = snapshot.copy()
        self.reset_certificates()  # never restore derived certificates


def digest(gen, tick, shard, events):
    wire = json.dumps([gen, tick, shard, events], separators=(",", ":"), sort_keys=True)
    return sha256(wire.encode()).hexdigest()


@dataclass(frozen=True)
class Packet:
    generation: int
    tick: int
    shard: int
    events: tuple[tuple, ...]
    check: str

    @classmethod
    def make(cls, generation, tick, shard, events):
        events = tuple(events)
        return cls(generation, tick, shard, events, digest(generation, tick, shard, events))


class Fence:
    """Hypothetical trusted-owner stage barrier; no network/worker authentication.

    Incomplete authority => BLOCKED (not an unsafe full recompute). Bad identity
    => REFUSE. A complete epoch can be committed and THEN evaluated/skipped.
    """
    def __init__(self, engine: Sparse, workers: int):
        if workers not in (1, 4):
            raise ValueError("bounded worker count")
        self.engine = engine
        self.workers = workers
        self.generation = 0
        self.packets = {}

    def accept(self, p: Packet):
        if (p.generation != self.generation or p.tick != self.engine.state.tick
                or not (0 <= p.shard < self.workers)
                or p.check != digest(p.generation, p.tick, p.shard, p.events)
                or len(p.events) > 24 or p.shard in self.packets):
            raise ValueError("stale/forged/duplicate/capacity packet: REFUSE")
        self.packets[p.shard] = p

    def _sites_and_kind(self, e):
        """Prevalidate the complete declared input before any authoritative write."""
        if not isinstance(e, (tuple, list)) or not e or not isinstance(e[0], str):
            raise ValueError("malformed event: REFUSE")
        kind = e[0]
        s = self.engine.state
        if kind == "set" and len(e) == 4:
            _, x, y, material = e
            if not all(type(v) is int for v in (x, y, material)) or material not in range(8):
                raise ValueError("invalid cell write: REFUSE")
            return kind, (s.index(x, y),)
        if kind == "explode" and len(e) == 4:
            _, x, y, radius = e
            if not all(type(v) is int for v in (x, y, radius)) or not 0 <= radius <= 3:
                raise ValueError("invalid bounded explosion: REFUSE")
            s.index(x, y)
            return kind, tuple(yy*s.width+xx
                               for yy in range(max(0, y-radius), min(s.height, y+radius+1))
                               for xx in range(max(0, x-radius), min(s.width, x+radius+1))
                               if (xx-x)**2 + (yy-y)**2 <= radius*radius)
        if kind == "body" and len(e) == 2:
            positions = e[1]
            if not isinstance(positions, (tuple, list)) or len(positions) > 32:
                raise ValueError("unbounded body footprint: REFUSE")
            for point in positions:
                if (not isinstance(point, (tuple, list)) or len(point) != 2
                        or not all(type(v) is int for v in point)):
                    raise ValueError("malformed body position: REFUSE")
                s.index(*point)
            return kind, ()
        if kind == "pressure" and len(e) == 2 and type(e[1]) is int and e[1] in (0, 1):
            return kind, ()
        if kind == "unknown" and len(e) == 1:
            return kind, ()
        raise ValueError("unsupported event shape: REFUSE")

    def advance(self):
        if len(self.packets) != self.workers:
            return "BLOCKED"  # not even full recompute is authoritative yet
        events = []
        writers = {}
        globals_seen = set()
        for shard in range(self.workers):
            for e in self.packets[shard].events:
                kind, sites = self._sites_and_kind(e)
                for site in sites:
                    if site in writers and writers[site] != shard:
                        raise ValueError("cross-shard overlapping write: REFUSE")
                    writers[site] = shard
                if kind in ("body", "pressure"):
                    if kind in globals_seen:
                        raise ValueError("multiple global owners: REFUSE")
                    globals_seen.add(kind)
                events.append(e)
        self.engine.step(tuple(events), workers=self.workers)
        self.engine.counts.packets += self.workers
        self.packets.clear()
        return "COMMITTED"

    def restore(self, state: State):
        self.generation += 1
        self.packets.clear()
        self.engine.restore(state)


def initial(kind: str, width=24, height=16):
    s = State(width, height, [ROCK]*(width*height))
    if kind == "quiet":
        for x in range(3, 8):
            s.cells[s.index(x, height-2)] = SAND
        s.cells[s.index(width-2, 1)] = WATER
    elif kind in ("mixed", "churn"):
        rng = random.Random(1731)
        choices = [EMPTY]*6+[SAND]*3+[ROCK]*3+[WATER]*2+[WOOD, FIRE]
        s.cells = [rng.choice(choices) for _ in s.cells]
        s.cells[s.index(width-2, 1)] = WATER
    else:
        raise ValueError(kind)
    return s


def tape(kind: str, ticks=64, width=24, height=16):
    rng = random.Random(481)
    for t in range(ticks):
        events = []
        if kind != "quiet":
            if kind == "churn":
                events.append(("unknown",))
            if t == 4: events.append(("body", ((7, 7), (8, 7))))
            if t == 6: events.append(("body", ((8, 7), (9, 7))))
            if t == 10: events.extend((("set", 11, 5, WOOD), ("set", 12, 5, FIRE)))
            if t in (13, 14, 28, 29): events.append(("pressure", 1 if t%2 else 0))
            if t == 18: events.append(("explode", 12, 10, 2))
            if t == 20: events.extend((("set", 3, 1, ROCK), ("set", 3, 1, EMPTY)))
            if t == 24: events.append(("unknown",))
            if t % 7 == 0:
                events.append(("set", rng.randrange(width), rng.randrange(height),
                               rng.choice((EMPTY, WATER, ROCK, FIRE))))
        yield tuple(events)


def experiment(kind, workers=1, ticks=64, diagnose=False):
    oracle = initial(kind)
    inc = Sparse(oracle, diagnostic=diagnose)
    fence = Fence(inc, workers)
    snap = None
    full_calls = len(oracle.cells)*ticks
    diagnostics = []
    for t, es in enumerate(tape(kind, ticks)):
        if t == 31:
            snap = oracle.copy()
        if t == 44:
            oracle = snap.copy()
            fence.restore(snap)
        # All packets participate, even empty ones; names are logical shards.
        pieces = [tuple(es) if shard == 0 else () for shard in range(workers)]
        for shard in reversed(range(workers)):
            fence.accept(Packet.make(fence.generation, inc.state.tick, shard, pieces[shard]))
        if fence.advance() != "COMMITTED":
            raise AssertionError("complete barrier did not commit")
        full_step(oracle, es)
        if oracle != inc.state:
            raise AssertionError((kind, workers, t, oracle, inc.state))
        diagnostics.append(len(inc.active))
    c = inc.counts
    return dict(profile=kind, logical_shards=workers, ticks=ticks,
                end_tick=inc.state.tick, oracle_exact_at_every_tick=True,
                full_calls=full_calls, cached_calls=c.rule_calls,
                skipped_calls=full_calls-c.rule_calls,
                skip_ratio=round(1-c.rule_calls/full_calls, 5),
                proof_calls=c.initial_probes+c.recert_probes,
                halo_sites=c.halo_sites, output_writes=c.cell_writes,
                active_tile_visits=c.tile_visits, initial_probes=c.initial_probes,
                diagnostic_probe_calls=c.diagnostic_probes,
                invalidation_false_positives=c.false_positive_invalidations,
                packets=c.packets, global_fallbacks=c.global_fallbacks,
                abstract_cost=c.rule_calls+c.recert_probes+c.halo_sites,
                online_full_grid_traversals=0, output_full_grid_copies=0,
                highest_active_tiles=max(diagnostics))


class Checks(unittest.TestCase):
    def test_exact_oracle_and_logical_partitions(self):
        for kind in ("quiet", "mixed", "churn"):
            r1 = experiment(kind, 1)
            r4 = experiment(kind, 4)
            for key in ("cached_calls", "skipped_calls", "proof_calls", "halo_sites"):
                self.assertEqual(r1[key], r4[key])
            if kind == "quiet":
                self.assertEqual(r1["cached_calls"], 0)
                self.assertEqual(r1["online_full_grid_traversals"], 0)
            if kind == "churn":
                self.assertEqual(r1["cached_calls"], r1["full_calls"])

    def test_incomplete_barrier_is_not_recompute(self):
        oracle = initial("quiet")
        engine = Sparse(oracle)
        fence = Fence(engine, 4)
        start = engine.state.copy()
        packets = [Packet.make(0, 0, i, (("pressure", 1),) if i == 3 else ()) for i in range(4)]
        for p in packets[:3]: fence.accept(p)
        self.assertEqual(fence.advance(), "BLOCKED")
        self.assertEqual(engine.state, start)
        # Wrong shortcut: treating three of four arrivals as a complete input
        # would keep remote Water unchanged whereas full authoritative step evaporates it.
        bad = engine.state.copy()
        full_step(bad, ())
        full_step(oracle, (("pressure", 1),))
        self.assertNotEqual(bad, oracle)
        fence.accept(packets[3])
        self.assertEqual(fence.advance(), "COMMITTED")
        self.assertEqual(engine.state, oracle)

    def test_stale_rollback_aba_and_forged_packet(self):
        engine = Sparse(initial("quiet"))
        fence = Fence(engine, 1)
        p = Packet.make(0, 0, 0, (("set", 3, 1, EMPTY), ("set", 3, 1, ROCK)))
        fence.accept(p)
        with self.assertRaises(ValueError): fence.accept(p)
        self.assertEqual(fence.advance(), "COMMITTED")
        old = engine.state.copy()
        fence.restore(initial("quiet"))
        with self.assertRaises(ValueError): fence.accept(Packet.make(0, 0, 0, ()))
        changed = Packet.make(fence.generation, 0, 0, (("pressure", 1),))
        with self.assertRaises(ValueError):
            fence.accept(Packet(changed.generation, changed.tick, changed.shard,
                                (("pressure", 0),), changed.check))
        self.assertEqual(engine.state.tick, 0)
        self.assertEqual(old.tick, 1)

    def test_conflicting_shard_owners_refuse(self):
        fence = Fence(Sparse(initial("quiet")), 4)
        for i in range(4):
            event = (("set", 5, 5, WATER),) if i < 2 else ()
            fence.accept(Packet.make(0, 0, i, event))
        with self.assertRaises(ValueError): fence.advance()
        self.assertEqual(fence.engine.state.tick, 0)

    def test_explosion_overlap_and_late_bad_event_are_atomic_refusals(self):
        for bad in ((("set", 5, 5, WATER),), (("set", 40, 5, WATER),)):
            fence = Fence(Sparse(initial("quiet")), 4)
            initial_state = fence.engine.state.copy()
            inputs = [(("explode", 5, 5, 1),), bad, (), ()]
            for shard, events in enumerate(inputs):
                fence.accept(Packet.make(0, 0, shard, events))
            with self.assertRaises(ValueError): fence.advance()
            self.assertEqual(fence.engine.state, initial_state)
        # An otherwise valid write preceding a malformed later shard must not
        # partially apply before the preflight rejects the complete packet.
        fence = Fence(Sparse(initial("quiet")), 4)
        before = fence.engine.state.copy()
        for shard, events in enumerate(((("set", 5, 5, EMPTY),), (), (), (("pressure", 7),))):
            fence.accept(Packet.make(0, 0, shard, events))
        with self.assertRaises(ValueError): fence.advance()
        self.assertEqual(fence.engine.state, before)

    def test_contact_seam_and_unknown(self):
        s = State(8, 8, [ROCK]*64, frozenset({4*8+3}))
        s.cells[s.index(3,3)] = SAND
        s.cells[s.index(3,4)] = EMPTY
        oracle=s.copy(); sparse=Sparse(s)
        for es in ((), (("body", ()),), (("unknown",),)):
            full_step(oracle, es); sparse.step(es, workers=4)
            self.assertEqual(oracle, sparse.state)
        self.assertEqual(sparse.state.cells[s.index(3,4)], SAND)


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(Checks)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful():
        raise SystemExit(1)
    print(json.dumps([experiment(k, w) for k in ("quiet", "mixed", "churn") for w in (1, 4)] +
                     [experiment(k, 1, diagnose=True) for k in ("mixed", "churn")],
                     indent=2, sort_keys=True))
