"""B2 research-only conservative fixed-point region certificates.

This is an abstract synchronous, finite-radius automaton, NOT CyberSand native
physics, pressure, collision, liquid quantity, or a performance qualification.
Run: python3 -m unittest discover -s . -p 'test_*.py' -v
     python3 model.py
No non-stdlib dependencies.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from hashlib import sha256
import json
import random
from time import perf_counter_ns

EMPTY, SAND, WATER, ROCK, WOOD, FIRE, ASH, STEAM = range(8)
NAMES = ".swrWfaV"


@dataclass
class State:
    width: int
    height: int
    cells: list[int]
    actor: frozenset[int] = frozenset()
    pressure: int = 0
    tick: int = 0

    def copy(self) -> State:
        return State(self.width, self.height, self.cells.copy(), self.actor, self.pressure, self.tick)

    def at(self, x: int, y: int) -> int:
        return self.cells[y * self.width + x]

    def index(self, x: int, y: int) -> int:
        assert 0 <= x < self.width and 0 <= y < self.height
        return y * self.width + x

    def digest(self) -> str:
        payload = (self.width.to_bytes(4, "little") + self.height.to_bytes(4, "little")
                   + self.tick.to_bytes(8, "little") + self.pressure.to_bytes(1, "little")
                   + bytes(self.cells) + b"@"
                   + b"".join(i.to_bytes(4, "little") for i in sorted(self.actor)))
        return sha256(payload).hexdigest()[:20]


def step_cell(s: State, x: int, y: int, phase: int) -> int:
    """Pure local radius-1 rule with an explicitly global pressure input.

    Actor footprint participates in the pair rule as a transient obstacle, not
    as material authority. This toy reaction/transport rule is NOT physically
    conservative and must never be promoted as a CyberSand water law.
    """
    w, h = s.width, s.height
    i = y * w + x
    c = s.cells[i]
    if c == WOOD:
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            xx, yy = x + dx, y + dy
            if 0 <= xx < w and 0 <= yy < h and s.cells[yy * w + xx] == FIRE:
                return FIRE
    if c == FIRE:
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            xx, yy = x + dx, y + dy
            if 0 <= xx < w and 0 <= yy < h and s.cells[yy * w + xx] == WATER:
                return ASH
    if c == WATER and s.pressure:
        return STEAM
    if c == STEAM and not s.pressure:
        return WATER
    # Checkerboard disjoint vertical pairs; the phase is a declared global
    # time input, and both phases must be certified before a tile can sleep.
    top_y = y if y % 2 == phase else y - 1
    if top_y < 0 or top_y + 1 >= h:
        return c
    top_i, bottom_i = top_y * w + x, (top_y + 1) * w + x
    if (top_i not in s.actor and bottom_i not in s.actor
            and s.cells[top_i] in (SAND, WATER) and s.cells[bottom_i] == EMPTY):
        return EMPTY if i == top_i else s.cells[top_i]
    return c


# Events are ordered tuples: ('set', x,y,material), ('explode', x,y,radius),
# ('actor', ((x,y),...)), ('pressure', bit), ('unknown',). Rollback is separate
# because restoring the *entire* state revokes every previously derived proof.
def apply_events(s: State, events: list[tuple]) -> tuple[set[int], bool]:
    touched: set[int] = set()
    global_wake = False
    for event in events:
        kind = event[0]
        if kind == "set":
            _, x, y, material = event
            i = s.index(x, y)
            s.cells[i] = material
            touched.add(i)  # includes ABA changes or a redundant producer write
        elif kind == "explode":
            _, cx, cy, r = event
            for y in range(max(0, cy-r), min(s.height, cy+r+1)):
                for x in range(max(0, cx-r), min(s.width, cx+r+1)):
                    if (x-cx)**2 + (y-cy)**2 <= r*r:
                        i = s.index(x, y)
                        s.cells[i] = EMPTY
                        touched.add(i)
        elif kind == "actor":
            _, cells = event
            new_actor = frozenset(s.index(x, y) for x, y in cells)
            touched.update(s.actor ^ new_actor)
            s.actor = new_actor
        elif kind == "pressure":
            _, pressure = event
            assert pressure in (0, 1)
            global_wake |= pressure != s.pressure
            s.pressure = pressure
        elif kind == "unknown":
            global_wake = True  # UNKNOWN always means full fallback
        else:
            raise ValueError(f"unknown event kind: {kind}")
    return touched, global_wake


def full_step(s: State, events: list[tuple]) -> int:
    apply_events(s, events)
    phase = s.tick % 2
    old = s.copy()
    s.cells = [step_cell(old, i % s.width, i // s.width, phase)
               for i in range(len(s.cells))]
    s.tick += 1
    return len(s.cells)


@dataclass
class Stats:
    executed: int = 0
    probe_calls: int = 0
    halo_sites: int = 0
    invalidated: int = 0
    false_positive_invalidations: int = 0
    diagnostic_probe_calls: int = 0  # offline only, not hot-path work units
    recertified: int = 0
    unknown_fallbacks: int = 0
    pressure_fallbacks: int = 0
    events_touched: int = 0


@dataclass
class Cached:
    state: State
    tile_size: int = 4
    certified: set[int] = field(default_factory=set)
    stats: Stats = field(default_factory=Stats)

    def __post_init__(self) -> None:
        self.cols = (self.state.width + self.tile_size - 1) // self.tile_size
        self.rows = (self.state.height + self.tile_size - 1) // self.tile_size
        self.recertify_all()

    def tile(self, x: int, y: int) -> int:
        return (y // self.tile_size) * self.cols + x // self.tile_size

    def indices(self, tile: int):
        x0 = (tile % self.cols) * self.tile_size
        y0 = (tile // self.cols) * self.tile_size
        for y in range(y0, min(y0 + self.tile_size, self.state.height)):
            for x in range(x0, min(x0 + self.tile_size, self.state.width)):
                yield x, y

    def stable_both_phases(self, tile: int, *, diagnostic: bool = False) -> bool:
        s = self.state
        for x, y in self.indices(tile):
            for p in (0, 1):
                if diagnostic:
                    self.stats.diagnostic_probe_calls += 1
                else:
                    self.stats.probe_calls += 1
                if step_cell(s, x, y, p) != s.at(x, y):
                    return False
        return True

    def recertify_all(self) -> None:
        self.certified.clear()
        for tile in range(self.rows * self.cols):
            if self.stable_both_phases(tile):
                self.certified.add(tile)
                self.stats.recertified += 1

    def invalidate(self, touched: set[int], global_wake: bool, *,
                   faulty_no_halo: bool = False) -> None:
        if global_wake:
            revoked = self.certified.copy()
            self.stats.invalidated += len(revoked)
            self.certified.clear()
            # Offline diagnostic: a revoked fixed-point tile may still be stable,
            # but its certificate input assumptions were invalidated. This
            # check is NOT performed by a proposed production implementation.
            self.stats.false_positive_invalidations += sum(
                self.stable_both_phases(t, diagnostic=True) for t in revoked)
            return
        w, h = self.state.width, self.state.height
        affected: set[int] = set()
        for i in touched:
            x, y = i % w, i // w
            radius = 0 if faulty_no_halo else 1
            for yy in range(max(0, y-radius), min(h, y+radius+1)):
                for xx in range(max(0, x-radius), min(w, x+radius+1)):
                    self.stats.halo_sites += 1
                    affected.add(self.tile(xx, yy))
        revoked = affected & self.certified
        self.stats.invalidated += len(revoked)
        self.certified.difference_update(affected)
        self.stats.false_positive_invalidations += sum(
            self.stable_both_phases(t, diagnostic=True) for t in revoked)

    def step(self, events: list[tuple], *, workers: int = 1,
             faulty_ignore_pressure: bool = False,
             faulty_no_halo: bool = False) -> None:
        if workers not in (1, 4):
            raise ValueError("research partition only admits 1 or 4 logical shards")
        s = self.state
        touched, global_wake = apply_events(s, events)
        self.stats.events_touched += len(touched)
        if any(e[0] == "pressure" for e in events) and global_wake:
            self.stats.pressure_fallbacks += 1
        if any(e[0] == "unknown" for e in events):
            self.stats.unknown_fallbacks += 1
        if faulty_ignore_pressure and all(e[0] != "unknown" for e in events):
            # Unsound negative control: erroneously claims pressure has no
            # influence outside changed material positions.
            global_wake = False
        self.invalidate(touched, global_wake, faulty_no_halo=faulty_no_halo)
        old = s.copy()
        phase = s.tick % 2
        output = old.cells.copy()
        # Logical worker partition; NO parallel execution or native worker claim.
        # Each shard reads the same immutable pre-tick state.
        for shard in range(workers):
            for tile in range(shard, self.rows * self.cols, workers):
                if tile in self.certified:
                    continue
                for x, y in self.indices(tile):
                    output[y * s.width + x] = step_cell(old, x, y, phase)
                    self.stats.executed += 1
        changed = {i for i, (a,b) in enumerate(zip(old.cells, output)) if a != b}
        s.cells = output
        s.tick += 1
        self.invalidate(changed, False, faulty_no_halo=faulty_no_halo)
        # Recertification is optional derived work. Here it is throttled,
        # performed after the authoritative new state has been published.
        if s.tick % 4 == 0:
            for tile in range(self.rows * self.cols):
                if tile not in self.certified and self.stable_both_phases(tile):
                    self.certified.add(tile)
                    self.stats.recertified += 1

    def restore(self, snapshot: State) -> None:
        # No serialized certificate is ever treated as authoritative.
        self.state = snapshot.copy()
        self.recertify_all()


def make_state(profile: str, width: int = 24, height: int = 16) -> State:
    s = State(width, height, [EMPTY] * (width*height))
    if profile == "quiet":
        for x in range(width):
            s.cells[s.index(x, height-1)] = ROCK
        for x in range(3, 8):
            s.cells[s.index(x, height-2)] = SAND
            s.cells[s.index(x, height-3)] = ROCK
        for x in range(width-4, width-1):
            s.cells[s.index(x, height-2)] = WATER
            s.cells[s.index(x, height-3)] = ROCK
    elif profile in ("mixed", "dense", "churn"):
        rng = random.Random(931 if profile == "mixed" else 274)
        rates = [EMPTY] * (7 if profile == "mixed" else 2) + [SAND] * 3 + [WATER] * 2 + [ROCK] * 3 + [WOOD] + [FIRE]
        s.cells = [rng.choice(rates) for _ in s.cells]
        # Guaranteed remote pressure-dependent cell, regardless of noise.
        s.cells[s.index(width-2, 1)] = WATER
    else:
        raise ValueError(profile)
    return s


def tape(profile: str, ticks: int = 64, width: int = 24, height: int = 16):
    rng = random.Random(442)
    for t in range(ticks):
        e: list[tuple] = []
        if profile != "quiet":
            if profile == "churn":
                # Unmodelled effect each frame: safe full-recompute control.
                e.append(("unknown",))
            if t in (2, 3): e.append(("set", 7+t-2, 6, SAND if t == 2 else WATER))
            if t == 5: e.append(("actor", ((7, 7), (8, 7))))
            if t == 7: e.append(("actor", ((8, 7), (9, 7))))
            if t == 9: e.append(("set", 12, 5, WOOD))
            if t == 10: e.append(("set", 11, 5, FIRE))
            if t in (13, 14, 28, 29): e.append(("pressure", 1 if t % 2 else 0))
            if t in (18, 45): e.append(("explode", 12, 10, 2))
            if t == 20:
                # ABA: real material transitions produce two producer events,
                # even though the final source value is identical to baseline.
                e.extend((("set", 3, 1, ROCK), ("set", 3, 1, EMPTY)))
            if t == 24: e.append(("unknown",))
            if t == 37: e.append(("actor", ((0, 0),)))
            if t % 5 == 4:
                x, y = rng.randrange(width), rng.randrange(height)
                e.append(("set", x, y, rng.choice((SAND, WATER, ROCK, WOOD, FIRE, EMPTY))))
        yield e


def run(profile: str, *, workers: int = 1, ticks: int = 64) -> dict:
    oracle = make_state(profile)
    inc = Cached(oracle.copy())
    snapshots = None
    full_calls = 0
    full_ns = inc_ns = 0
    hashes = []
    for index, events in enumerate(tape(profile, ticks=ticks)):
        if index == 31:
            snapshots = (oracle.copy(), inc.state.copy())
        if index == 44 and snapshots is not None:
            oracle = snapshots[0].copy()
            inc.restore(snapshots[1])
        now = perf_counter_ns()
        full_calls += full_step(oracle, events)
        full_ns += perf_counter_ns() - now
        now = perf_counter_ns()
        inc.step(events, workers=workers)
        inc_ns += perf_counter_ns() - now
        assert oracle == inc.state, (profile, workers, index, oracle.digest(), inc.state.digest())
        assert oracle.digest() == inc.state.digest()
        hashes.append(oracle.digest())
    stats = vars(inc.stats)
    evaluated = inc.stats.executed
    return {
        "profile": profile, "logical_shards": workers, "ticks": ticks,
        "source": "standalone-abstract-model-v1", "end_hash": oracle.digest(),
        "full_calls": full_calls, "incremental_calls": evaluated,
        "skipped_calls": full_calls-evaluated,
        "skip_ratio": round(1-evaluated/full_calls, 4),
        "probe_calls": inc.stats.probe_calls,
        "halo_sites": inc.stats.halo_sites,
        "abstract_work_units": evaluated+inc.stats.probe_calls+inc.stats.halo_sites,
        "oracle_work_units": full_calls,
        "native_speed_claim": False,
        "python_reference_full_ns": full_ns,
        "python_reference_incremental_ns": inc_ns,
        "statistics": stats,
    }


if __name__ == "__main__":
    results = [run(p, workers=w) for p in ("quiet", "mixed", "dense", "churn") for w in (1, 4)]
    for profile in ("quiet", "mixed", "dense", "churn"):
        a,b = (r for r in results if r["profile"] == profile)
        assert a["end_hash"] == b["end_hash"]
    print(json.dumps(results, indent=2, sort_keys=True))
