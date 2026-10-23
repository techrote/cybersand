#!/usr/bin/env python3
"""Standalone contract oracle for the Proposed inertial cell update (#212).

`inertial-update-v1` is one ordered, bounded, exact-integer update of a single
`inertial_cellular_v1` cell against a small static neighbourhood. It specifies:
support detection and cancellation, exactly one gravity application, diagonal
re-aim, blocked-fall deflection, signed per-component impulses, separate
non-negative speed-loss accounting, truncation/saturation/remainder rules,
accumulator travel with target rechecks, one contact rule for Wall, body mask
and same-family cells, and rest/sleep eligibility.

This is a contract model only. It does not execute a World, a scheduler or a
solver, and nothing here claims an inertial family exists. #212 must reproduce
the worked examples and the invariants; parameter values are illustrative and
recorded in the receipt, not frozen.
"""
from __future__ import annotations

from dataclasses import dataclass, field

# Neighbourhood cells. Eligibility is directional (re-review N1): EMPTY is
# enterable by any move; LIGHTER (a lighter foreign liquid) only by a move with a
# downward vertical displacement (dy = +1, straight or diagonal down), the
# density exchange Current `can_density_exchange` admits (vertical delta != 0).
# A horizontal move (dy = 0) never swaps. WALL, MASK (transient body mask) and
# SAME (an occupied same-family cell) are never enterable and use one contact
# rule.
EMPTY, LIGHTER, WALL, MASK, SAME = ".", "o", "#", "M", "W"


@dataclass(frozen=True)
class Params:
    q: int = 16            # velocity/accumulator units per cell (Q4: 1/16 cell per tick)
    gravity: int = 4       # +vy per tick, applied exactly once
    vmax: int = 64         # per-component saturation; vmax // q = 4 cells <= write radius
    turn: tuple = (1, 8)   # diagonal re-aim loss fraction of the L1 speed
    deflect: tuple = (3, 4)  # fraction of the carried vy turned into vx on a blocked fall
    damping: tuple = (1, 16)  # per-tick multiplicative damping, per component
    drag: tuple = (1, 4)   # fraction removed from each component on a density swap
    rest: int = 1          # supported cell with vy == 0 and |vx| <= rest is zeroed


@dataclass
class Cell:
    x: int
    y: int
    vx: int = 0
    vy: int = 0
    ax: int = 0
    ay: int = 0


@dataclass
class Entry:
    stage: str        # gravity, support, reaim, deflect, contact, saturate, damping, drag, rest, travel
    jx: int = 0       # signed impulse on vx
    jy: int = 0       # signed impulse on vy
    loss: int = 0     # non-negative L1 speed loss (gravity: negative = speed added)
    remainder: int = 0  # truncated fraction numerator (audit only; never state)
    note: str = ""


@dataclass
class Result:
    cell: Cell
    entries: list = field(default_factory=list)
    moves: list = field(default_factory=list)
    swaps: list = field(default_factory=list)  # (dx, dy) of every density-exchange move
    sleep_eligible: bool = False


def trunc_mul(v: int, frac: tuple) -> tuple[int, int]:
    """v * num / den truncated toward zero, and the signed remainder numerator."""
    num, den = frac
    applied = abs(v) * num // den * (1 if v >= 0 else -1)
    return applied, v * num - applied * den


def speed(c: Cell) -> int:
    return abs(c.vx) + abs(c.vy)


class Grid:
    def __init__(self, rows: list[str]):
        self.rows = [list(r) for r in rows]

    def at(self, x: int, y: int) -> str:
        if 0 <= y < len(self.rows) and 0 <= x < len(self.rows[y]):
            return self.rows[y][x]
        return WALL  # outside the neighbourhood is a boundary

    def enterable(self, x: int, y: int, dx: int, dy: int) -> bool:
        """May a cell at (x, y) move by (dx, dy)? The one eligibility rule for support,
        re-aim, side selection and every travel move."""
        target = self.at(x + dx, y + dy)
        return target == EMPTY or (target == LIGHTER and dy == 1)


def _book(res: Result, stage: str, before: tuple, c: Cell, remainder: int = 0, note: str = "") -> None:
    jx, jy = c.vx - before[0], c.vy - before[1]
    loss = abs(before[0]) + abs(before[1]) - speed(c)
    if jx or jy or remainder or note:
        res.entries.append(Entry(stage, jx, jy, loss, remainder, note))


def _side(g: Grid, c: Cell, dy: int, order: tuple) -> int:
    """First eligible move (s, dy), s = +1 right / -1 left: sign(vx) first, else `order`.
    dy = 1 asks for a diagonal-down target, dy = 0 for a horizontal neighbour."""
    sides = ((1 if c.vx > 0 else -1), (-1 if c.vx > 0 else 1)) if c.vx else order
    for s in sides:
        if g.enterable(c.x, c.y, s, dy):
            return s
    return 0


def _land(g: Grid, c: Cell, p: Params, res: Result, carried: int, order: tuple) -> None:
    """Blocked fall: the carried vy is removed by the contact; d = trunc(f_deflect * vy) is
    added to vx toward the first horizontally eligible side. Impulses (s*d, -vy); L1 loss
    |vx| + vy - |vx + s*d|, which includes cancellation against an opposing vx (N2).
    Used both before travel (U3) and at a travel contact (U6)."""
    before = (c.vx, c.vy)
    side = _side(g, c, 0, order)
    if side and carried > 0:
        d, rem = trunc_mul(carried, p.deflect)
        c.vy -= carried
        c.vx += side * d
        _book(res, "deflect", before, c, rem, f"carried vy {carried} -> {side * d:+d} vx")
    else:
        c.vy -= carried
        _book(res, "contact", before, c, note="vertical contact; no free side" if carried else "")
    c.ay = 0


def _saturate(c: Cell, p: Params, res: Result) -> None:
    before = (c.vx, c.vy)
    c.vx = max(-p.vmax, min(p.vmax, c.vx))
    c.vy = max(-p.vmax, min(p.vmax, c.vy))
    _book(res, "saturate", before, c)


def update(g: Grid, start: Cell, p: Params = Params(), order: tuple = (1, -1)) -> Result:
    """One `inertial-update-v1` tick for one cell. `order` is deterministic_direction's side order."""
    c = Cell(**vars(start))
    res = Result(c)
    assert c.vy >= 0, "v1 has no upward impulse source"
    carried = c.vy
    # U1 support detection, before any velocity change.
    supported = not g.enterable(c.x, c.y, 0, 1)
    # U2 exactly one gravity application.
    before = (c.vx, c.vy)
    c.vy += p.gravity
    _book(res, "gravity", before, c)
    # U3 vertical resolution of a supported cell.
    if supported:
        diag = _side(g, c, 1, order)
        if diag:
            # (A) diagonal re-aim: L1 speed minus the turn loss, split |vx| = s // 2, vy = rest.
            before = (c.vx, c.vy)
            s_in = speed(c)
            loss, rem = trunc_mul(s_in, p.turn)
            s_out = s_in - loss
            c.vx, c.vy = diag * (s_out // 2), s_out - s_out // 2
            _book(res, "reaim", before, c, rem, f"diagonal {diag:+d}")
        else:
            # Support cancels this tick's gravity (a constraint impulse, not dissipation) ...
            before = (c.vx, c.vy)
            c.vy -= p.gravity
            _book(res, "support", before, c)
            # ... and only the velocity carried in from earlier ticks can deflect.
            _land(g, c, p, res, carried, order)
    # U4 saturation, U5 damping (truncation toward zero, signed per component).
    _saturate(c, p, res)
    before = (c.vx, c.vy)
    dx, rx = trunc_mul(c.vx, p.damping)
    dy, ry = trunc_mul(c.vy, p.damping)
    c.vx, c.vy = c.vx - dx, c.vy - dy
    _book(res, "damping", before, c, rx + ry)
    # U6 travel: accumulate, then whole-cell unit moves with a target recheck each.
    c.ax += c.vx
    c.ay += c.vy
    nx, ny = int(c.ax / p.q), int(c.ay / p.q)  # truncation toward zero
    c.ax -= nx * p.q
    c.ay -= ny * p.q
    k = max(abs(nx), abs(ny))
    sx, sy = (1 if nx > 0 else -1), (1 if ny > 0 else -1)
    done_x = done_y = 0
    for i in range(1, k + 1):
        want_y = abs(ny) * i // k - done_y
        want_x = abs(nx) * i // k - done_x
        # A sub-step needing both axes is first tried as one diagonal move, so a
        # permitted move with vertical displacement is never split into a forbidden
        # horizontal swap. Otherwise vertical, then horizontal, unit moves.
        plan = [(sx, sy)] if want_x and want_y and g.enterable(c.x, c.y, sx, sy) else \
            [(0, sy)] * bool(want_y) + [(sx, 0)] * bool(want_x)
        stop = False
        for dx, dy in plan:
            if not g.enterable(c.x, c.y, dx, dy):
                target = g.at(c.x + dx, c.y + dy)
                if dy:
                    _land(g, c, p, res, c.vy, order)
                    _saturate(c, p, res)
                else:
                    before = (c.vx, c.vy)
                    c.vx, c.ax = 0, 0
                    _book(res, "contact", before, c, note=f"horizontal contact with {target!r}")
                stop = True
                break
            tx, ty = c.x + dx, c.y + dy
            target = g.at(tx, ty)
            if target == LIGHTER:
                before = (c.vx, c.vy)
                gx, rgx = trunc_mul(c.vx, p.drag)
                gy, rgy = trunc_mul(c.vy, p.drag)
                c.vx, c.vy = c.vx - gx, c.vy - gy
                _book(res, "drag", before, c, rgx + rgy, "density swap")
                res.swaps.append((dx, dy))
            g.rows[c.y][c.x], g.rows[ty][tx] = target, SAME  # swap/move in the scratch grid
            c.x, c.y = tx, ty
            res.moves.append((tx, ty))
            done_x += abs(dx)
            done_y += abs(dy)
        if stop:
            break
    # U7 rest and sleep eligibility.
    supported = not g.enterable(c.x, c.y, 0, 1)
    if supported and c.vy == 0 and abs(c.vx) <= p.rest:
        before = (c.vx, c.vy)
        c.vx = 0
        _book(res, "rest", before, c)
        if c.ax or c.ay:
            res.entries.append(Entry("travel", note=f"accumulator reset ({c.ax}, {c.ay}); position unchanged"))
            c.ax = c.ay = 0
    res.sleep_eligible = supported and c.vx == 0 and c.vy == 0 and c.ax == 0 and c.ay == 0
    return res


def ledger_closes(start: Cell, res: Result, p: Params = Params()) -> bool:
    """Per-component signed identity and the separate L1 speed identity."""
    jx = sum(e.jx for e in res.entries)
    jy = sum(e.jy for e in res.entries)
    loss = sum(e.loss for e in res.entries)
    gravity = [e for e in res.entries if e.stage == "gravity"]
    return (res.cell.vx == start.vx + jx and res.cell.vy == start.vy + jy
            and len(gravity) == 1 and gravity[0].jy == p.gravity and gravity[0].jx == 0
            and speed(res.cell) == speed(start) - loss
            and all(e.loss >= 0 for e in res.entries if e.stage != "gravity"))


# Worked examples. The neighbourhood is centred on (2, 1); row 2 is the support row.
EXAMPLES = {
    "deflect-right": (["#####", "##W..", "#####"], Cell(2, 1, 0, 32)),
    "deflect-left": (["#####", "..W##", "#####"], Cell(2, 1, 0, 32)),
    "deflect-right-aligned-vx": (["#####", "##W..", "#####"], Cell(2, 1, 10, 32)),
    "deflect-right-opposing-vx": (["#####", "##W..", "#####"], Cell(2, 1, -10, 32)),
    "deflect-left-aligned-vx": (["#####", "..W##", "#####"], Cell(2, 1, -10, 32)),
    "deflect-left-opposing-vx": (["#####", "..W##", "#####"], Cell(2, 1, 40, 32)),
    "damp-negative-vx": (["#####", "..W..", "#####"], Cell(2, 1, -40, 0)),
    "supported-rest-free-side": (["#####", "#.W..", "#####"], Cell(2, 1, 0, 0)),
    "blocked-same-family": (["WWWWW", "WWWWW", "WWWWW"], Cell(2, 1, 0, 20)),
    "reaim-from-rest": (["#####", "#.W..", "###.."], Cell(2, 1, 0, 0)),
    "reaim-carried": (["#####", "#.W..", "###.."], Cell(2, 1, 0, 40)),
    "saturate-free-fall": ([".....", "..W..", ".....", ".....", ".....", "....."], Cell(2, 1, 0, 62, 0, 15)),
    "contact-mid-travel": (["#####", "W.#..", "#####"], Cell(0, 1, 48, 0)),
    "body-mask-landing": (["#####", "##W.M", "##M##"], Cell(2, 1, 0, 32)),
    "drag-density-swap": ([".....", "..W..", "..o..", "..o..", "#####"], Cell(2, 1, 0, 20)),
    "reaim-diagonal-into-lighter": ([".....", "..W..", "..#o.", "#####"], Cell(2, 1, 0, 40)),
    "no-horizontal-swap": (["#####", "#Wo.#", "#####"], Cell(1, 1, 20, 0)),
    "no-deflection-into-lighter": (["#####", "#oW##", "#####"], Cell(2, 1, 0, 32)),
}


def example(name: str, p: Params = Params()) -> dict:
    rows, start = EXAMPLES[name]
    res = update(Grid(rows), start, p)
    return {"name": name, "neighbourhood": rows,
            "start": vars(start), "end": vars(res.cell), "moves": res.moves, "swaps": res.swaps,
            "entries": [{k: v for k, v in vars(e).items() if v or k in ("stage",)} for e in res.entries],
            "ledger_closes": ledger_closes(start, res, p), "sleep_eligible": res.sleep_eligible}


def registry() -> dict:
    p = Params()
    return {
        "rule": "inertial-update-v1",
        "status": "Proposed #212 contract model (tools/lcb/inertial_contract.py). Exact-integer worked examples "
                  "of one cell update against a static neighbourhood; no World, scheduler or inertial family "
                  "has executed.",
        "illustrative_parameters": {k: (list(v) if isinstance(v, tuple) else v) for k, v in vars(p).items()},
        "eligibility": "Empty: any move. Lighter foreign liquid: only a move with dy = +1 (straight or diagonal "
                       "down; Current can_density_exchange, vertical delta != 0). Wall, body mask, same family: "
                       "never. One rule for support, re-aim, side selection and every travel move.",
        "deflection": "s*d with d = trunc(vy_in * deflect); impulses (s*d, -vy_in); L1 loss "
                      "|vx| + vy_in - |vx + s*d| (cancellation against an opposing vx included)",
        "order": ["U1 support detection (below enterable?) before any velocity change",
                  "U2 gravity: vy += g exactly once",
                  "U3 supported cell: diagonal re-aim (A) if a diagonal is enterable; otherwise support cancels "
                  "this tick's g, then blocked-fall deflection (B) of the vy carried in from earlier ticks",
                  "U4 per-component saturation to +-vmax",
                  "U5 per-component damping, truncated toward zero",
                  "U6 accumulator travel: whole-cell unit moves, target recheck each; a sub-step needing both axes "
                  "is tried as one diagonal move first; a lighter liquid swaps with drag only on a move with "
                  "dy = +1 (never horizontally); the first contact ends travel (vertical contact = rule B then "
                  "saturation, horizontal = zero vx)",
                  "U7 rest: supported, vy == 0, |vx| <= rest -> vx = 0 and accumulators reset; "
                  "sleep-eligible iff v == 0, a == 0 and supported"],
        "ledgers": {"momentum": "per component: v_after = v_before + gravity + sum(signed impulses)",
                    "speed_loss": "L1: |v_after| = |v_before| + g - sum(loss); every non-gravity loss >= 0; "
                                  "support cancellation is a constraint, not dissipation",
                    "rounding": "products truncate toward zero; the signed remainder numerator is audited, "
                                "never stored"},
        "examples": [example(n, p) for n in EXAMPLES],
    }
