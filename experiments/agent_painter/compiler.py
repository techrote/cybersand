"""Versioned three-family programs compiled to bounded native Art operations.

This is a proposal compiler, never a mutation authority. Host seed, focus,
material and budgets are separate arguments; current CyberSand owns protection,
Stop, receipts, history and persistence. Coordinates in programs use a 96-unit
design grid. Every emitted operation is an exact integer rectangle.

Salvage: strict types, canonical hashes, host-owned geometry budgets and the
positive-plan boundary adapt #567 controls/pattern_compiler.py at bac120981fdd.
New panel, graph and architecture semantics replace its old motif vocabulary.
"""
from __future__ import annotations

import argparse
from collections import deque
import hashlib
import json
from pathlib import Path
from typing import Any, Iterable

VERSION = 2
COMPILER_VERSION = "cybersand.agent-painter/2.0.0"
FAMILIES = ("greebles", "pipework", "architecture")
MAX_COMPONENTS = 12
MAX_FOCUS = 512
MAX_PROGRAM_BYTES = 32768


class CompilerError(ValueError):
    """Malformed input or bounded compilation refusal; no partial plan escapes."""


def canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def digest(value: Any) -> str:
    return hashlib.sha256(canonical_json(value).encode("utf-8")).hexdigest()


def _integer(value: Any, name: str, low: int, high: int) -> int:
    if type(value) is not int or not low <= value <= high:
        raise CompilerError(f"{name} must be an integer in [{low},{high}]")
    return value


def _keys(value: Any, keys: set[str], name: str) -> None:
    if type(value) is not dict or set(value) != keys:
        raise CompilerError(f"{name} requires exactly {', '.join(sorted(keys))}")


def _point(value: Any, name: str, margin: int = 0) -> tuple[int, int]:
    if type(value) is not list or len(value) != 2:
        raise CompilerError(f"{name} must be an integer XY pair")
    return tuple(_integer(v, name, margin, 95-margin) for v in value)


def _box(value: Any, name: str, minimum: int = 1) -> tuple[int, int, int, int]:
    if type(value) is not list or len(value) != 4:
        raise CompilerError(f"{name} must be an integer XYWH box")
    x, y = (_integer(v, name, 0, 95) for v in value[:2])
    w, h = (_integer(v, name, minimum, 96) for v in value[2:])
    if x+w > 96 or y+h > 96:
        raise CompilerError(f"{name} exceeds the design grid")
    return x, y, w, h


def parse_program(text: str) -> dict:
    """One complete JSON object only: no fences, duplicate keys or repair."""
    if type(text) is not str or len(text.encode("utf-8")) > MAX_PROGRAM_BYTES:
        raise CompilerError("program exceeds the byte budget")

    def object_pairs(pairs: list[tuple[str, Any]]) -> dict:
        result = {}
        for key, value in pairs:
            if key in result:
                raise CompilerError(f"duplicate JSON key: {key}")
            result[key] = value
        return result

    def nonfinite(value: str) -> None:
        raise CompilerError(f"nonfinite JSON constant: {value}")

    try:
        result = json.loads(text, object_pairs_hook=object_pairs, parse_constant=nonfinite)
    except (json.JSONDecodeError, RecursionError) as exc:
        raise CompilerError("one complete strict JSON program is required") from exc
    validate_program(result)
    return result


def structural_signature(program: dict) -> dict:
    """Conservative composition key that ignores seed and numeric style tuning.

    Named group custody remains required. This extra guard catches common
    relabeling leaks: width/density edits, coordinate shifts and graph-node
    reordering do not turn a held-out structure into training data. Pipe
    signatures are deliberately coarse; a collision holds groups together.
    """
    validate_program(program)
    family, cs = program["family"], program["components"]
    if family == "pipework":
        graph = [set() for _ in cs[0]["nodes"]]
        for a, b in cs[0]["edges"]:
            graph[a].add(b); graph[b].add(a)
        nodes = sorted((len(adj), sorted(len(graph[n]) for n in adj)) for adj in graph)
        return {"family": family, "nodes": nodes, "cycles": program["requirements"]["cycles"]}
    if family == "architecture":
        parts = []
        for c in cs:
            item = {"kind": c["kind"]}
            if c["kind"] == "room":
                # Preserve vertical-versus-horizontal adjacency while treating
                # mirror images as the same broad structural family.
                item["openings"] = sorted("side" if o["side"] in ("left", "right") else "floor" for o in c["openings"])
            parts.append(item)
        return {"family": family, "components": sorted(parts, key=canonical_json),
                "route_required": bool(program["requirements"]["route"])}
    panels = []
    for i, c in enumerate(cs):
        x, y, w, h = c["box"]
        relations = []
        for j, other in enumerate(cs):
            if i == j:
                continue
            ox, oy, ow, oh = other["box"]
            relations.append((other["detail"], max(x, ox) < min(x+w, ox+ow),
                              max(y, oy) < min(y+h, oy+oh)))
        panels.append({"detail": c["detail"], "neighbors": sorted(relations)})
    return {"family": family, "components": sorted(panels, key=canonical_json)}


def validate_program(program: Any) -> None:
    _keys(program, {"version", "family", "components", "requirements", "variation"}, "program")
    if type(program["version"]) is not int or program["version"] != VERSION:
        raise CompilerError("unsupported program version")
    if type(program["family"]) is not str or program["family"] not in FAMILIES:
        raise CompilerError("unknown drawing family")
    _integer(program["variation"], "variation", 0, 2)
    cs = program["components"]
    if type(cs) is not list or not 1 <= len(cs) <= MAX_COMPONENTS:
        raise CompilerError("components requires 1..12 entries")
    family = program["family"]
    req = program["requirements"]
    if family == "greebles":
        _keys(req, {"negative_space_min_percent"}, "greeble requirements")
        _integer(req["negative_space_min_percent"], "negative space", 20, 90)
        for c in cs:
            _keys(c, {"kind", "box", "detail", "density", "border", "fasteners"}, "panel")
            if c["kind"] != "panel" or c["detail"] not in ("vent", "grille", "inset", "plates", "ribs"):
                raise CompilerError("unknown greeble component/detail")
            _box(c["box"], "panel box", 12)
            _integer(c["density"], "panel density", 1, 4)
            _integer(c["border"], "panel border", 1, 2)
            if type(c["fasteners"]) is not bool:
                raise CompilerError("fasteners must be boolean")
        for i, c in enumerate(cs):
            a = c["box"]
            for d in cs[i+1:]:
                b = d["box"]
                if not (a[0]+a[2]+1 <= b[0] or b[0]+b[2]+1 <= a[0] or
                        a[1]+a[3]+1 <= b[1] or b[1]+b[3]+1 <= a[1]):
                    raise CompilerError("panels must retain at least one cell of separation")
    elif family == "pipework":
        _keys(req, {"connected", "cycles"}, "pipe requirements")
        if req["connected"] is not True:
            raise CompilerError("v2 pipe networks must be connected")
        _integer(req["cycles"], "pipe cycles", 0, 4)
        if len(cs) != 1:
            raise CompilerError("one composed pipe graph is required")
        c = cs[0]
        _keys(c, {"kind", "nodes", "edges", "diameter", "fittings"}, "pipe network")
        if c["kind"] != "pipe_network" or type(c["fittings"]) is not bool:
            raise CompilerError("invalid pipe component")
        d = _integer(c["diameter"], "pipe diameter", 3, 9)
        if d % 2 == 0:
            raise CompilerError("pipe diameter must be odd on the canonical grid")
        nodes = c["nodes"]
        if type(nodes) is not list or not 2 <= len(nodes) <= 32:
            raise CompilerError("pipe nodes require 2..32 positions")
        points = [_point(p, "pipe node", d//2+3) for p in nodes]
        if len(set(points)) != len(points):
            raise CompilerError("duplicate pipe node")
        edges = c["edges"]
        if type(edges) is not list or not 1 <= len(edges) <= 40:
            raise CompilerError("pipe edges require 1..40 connections")
        seen, graph = set(), {i: set() for i in range(len(nodes))}
        for e in edges:
            if type(e) is not list or len(e) != 2:
                raise CompilerError("pipe edge requires two node indexes")
            a, b = [_integer(v, "node index", 0, len(nodes)-1) for v in e]
            key = tuple(sorted((a, b)))
            if a == b or key in seen:
                raise CompilerError("duplicate or zero-length pipe edge")
            p, q = points[a], points[b]
            if (p[0] != q[0] and p[1] != q[1]) or abs(p[0]-q[0])+abs(p[1]-q[1]) < 12:
                raise CompilerError("pipe edges must be orthogonal and at least 12 design cells long")
            seen.add(key); graph[a].add(b); graph[b].add(a)
        reached, queue = {0}, [0]
        while queue:
            for n in graph[queue.pop()]:
                if n not in reached:
                    reached.add(n); queue.append(n)
        if len(reached) != len(nodes) or any(len(x) > 4 for x in graph.values()):
            raise CompilerError("pipe graph must be connected with degree at most four")
        if len(edges)-len(nodes)+1 != req["cycles"]:
            raise CompilerError("declared pipe cycle count differs from graph")
        # Every junction must be an explicit node. Near parallel runs may not
        # merge into a hidden junction after thickening or fitting expansion.
        for i, (a, b) in enumerate(edges):
            p, q = points[a], points[b]
            for c0, d0 in edges[i+1:]:
                r, s = points[c0], points[d0]
                shared = {a, b} & {c0, d0}
                if shared:
                    center = next(iter(shared))
                    other1 = b if a == center else a
                    other2 = d0 if c0 == center else c0
                    v = (points[other1][0]-points[center][0], points[other1][1]-points[center][1])
                    w = (points[other2][0]-points[center][0], points[other2][1]-points[center][1])
                    if v[0]*w[1] == v[1]*w[0] and v[0]*w[0]+v[1]*w[1] > 0:
                        raise CompilerError("overlapping edges at a pipe node")
                elif _rect_distance(p, q, r, s) <= d+4:
                    raise CompilerError("unannounced crossing or insufficient pipe separation")
    else:
        _keys(req, {"route", "clearance", "region"}, "architecture requirements")
        route = req["route"]
        if type(route) is not list or len(route) not in (0, 2):
            raise CompilerError("architecture route requires zero or two anchors")
        for p in route:
            _point(p, "route anchor")
        clearance = _integer(req["clearance"], "route clearance", 3, 9)
        if clearance % 2 == 0:
            raise CompilerError("clearance must be odd")
        _box(req["region"], "route region", clearance)
        for c in cs:
            if type(c) is not dict or "kind" not in c:
                raise CompilerError("missing architecture component kind")
            kind = c["kind"]
            if kind == "room":
                _keys(c, {"kind", "box", "thickness", "openings"}, "room")
                x, y, w, h = _box(c["box"], "room box", 16)
                t = _integer(c["thickness"], "room thickness", 1, 4)
                if type(c["openings"]) is not list or len(c["openings"]) > 6:
                    raise CompilerError("room openings require at most six entries")
                for o in c["openings"]:
                    _keys(o, {"side", "offset", "size"}, "opening")
                    if o["side"] not in ("left", "right", "top", "bottom"):
                        raise CompilerError("unknown opening side")
                    limit = h if o["side"] in ("left", "right") else w
                    offset = _integer(o["offset"], "opening offset", t, limit-t-1)
                    size = _integer(o["size"], "opening size", 3, limit-2*t)
                    if offset+size > limit-t:
                        raise CompilerError("opening crosses a room corner")
            elif kind in ("wall", "floor", "platform", "support"):
                _keys(c, {"kind", "box"}, kind)
                _, _, w, h = _box(c["box"], f"{kind} box")
                if kind in ("floor", "platform") and not (h <= 6 and w >= 8):
                    raise CompilerError("floors/platforms must be horizontal and thin")
                if kind in ("wall", "support") and not (w <= 6 and h >= 8):
                    raise CompilerError("walls/supports must be vertical and thin")
            elif kind == "stairs":
                _keys(c, {"kind", "box", "steps", "rise"}, "stairs")
                _, _, w, h = _box(c["box"], "stairs box", 8)
                n = _integer(c["steps"], "stair steps", 2, 8)
                if w < n*2 or h < n or c["rise"] not in ("left", "right"):
                    raise CompilerError("invalid staircase geometry")
            else:
                raise CompilerError("unknown architecture component")


def _rect_distance(p: tuple, q: tuple, r: tuple, s: tuple) -> int:
    dx = max(min(p[0], q[0])-max(r[0], s[0]), min(r[0], s[0])-max(p[0], q[0]), 0)
    dy = max(min(p[1], q[1])-max(r[1], s[1]), min(r[1], s[1])-max(p[1], q[1]), 0)
    return max(dx, dy)


class _Random:
    """Counter-based deterministic choices without low-bit seed correlations."""
    def __init__(self, seed: int):
        self.seed, self.counter = seed, 0

    def choose(self, low: int, high: int) -> int:
        word = hashlib.sha256(f"agent-painter-v2:{self.seed}:{self.counter}".encode()).digest()
        self.counter += 1
        return low+int.from_bytes(word[:8], "big") % (high-low+1)


class _Canvas:
    def __init__(self, focus: tuple[int, int, int, int], shift: tuple[int, int]):
        self.x, self.y, self.w, self.h = focus
        self.shift = shift
        self.mask = bytearray(self.w*self.h)

    def point(self, p: Iterable[int]) -> tuple[int, int]:
        x, y = p
        a = round((x+self.shift[0])*(self.w-1)/95)
        b = round((y+self.shift[1])*(self.h-1)/95)
        if not (0 <= a < self.w and 0 <= b < self.h):
            raise CompilerError("seed variation moves geometry outside host focus")
        return a, b

    def world(self, p: tuple[int, int]) -> list[int]:
        return [p[0]+self.x, p[1]+self.y]

    def box(self, box: list[int]) -> tuple[int, int, int, int]:
        x, y, w, h = box
        a = self.point((x, y)); b = self.point((x+w-1, y+h-1))
        return a[0], a[1], b[0]-a[0]+1, b[1]-a[1]+1

    def size(self, v: int, odd: bool = False) -> int:
        value = max(1, round(v*min(self.w, self.h)/96))
        return value+1 if odd and value % 2 == 0 else value

    def rect(self, x0: int, y0: int, x1: int, y1: int, value: int = 1) -> None:
        if not (0 <= x0 <= x1 < self.w and 0 <= y0 <= y1 < self.h):
            raise CompilerError("expanded geometry exceeds host focus")
        row = bytes([value])*(x1-x0+1)
        for y in range(y0, y1+1):
            self.mask[y*self.w+x0:y*self.w+x1+1] = row

    def frame(self, box: tuple[int, int, int, int], t: int) -> None:
        x, y, w, h = box
        self.rect(x, y, x+w-1, y+t-1)
        self.rect(x, y+h-t, x+w-1, y+h-1)
        self.rect(x, y+t, x+t-1, y+h-t-1)
        self.rect(x+w-t, y+t, x+w-1, y+h-t-1)


def _greebles(canvas: _Canvas, program: dict, rng: _Random) -> dict:
    panels = []
    for c in program["components"]:
        box = canvas.box(c["box"]); x, y, w, h = box
        t = canvas.size(c["border"]); inset = t+canvas.size(3)
        canvas.frame(box, t)
        inner = (x+inset, y+inset, w-2*inset, h-2*inset)
        ix, iy, iw, ih = inner
        if iw < 3 or ih < 3:
            raise CompilerError("panel interior is too small for requested detail")
        n = c["density"]+1
        detail = c["detail"]
        if detail in ("vent", "grille", "ribs"):
            vertical = detail in ("grille", "ribs")
            extent = iw if vertical else ih
            positions = sorted({max(1, min(extent-2, round((i+1)*(extent-1)/(n+1))+rng.choose(-1, 1))) for i in range(n)})
            for pos in positions:
                if vertical:
                    canvas.rect(ix+pos, iy, ix+pos, iy+ih-1)
                else:
                    canvas.rect(ix, iy+pos, ix+iw-1, iy+pos)
            if detail == "grille":
                for pos in (ih//3, 2*ih//3):
                    canvas.rect(ix, iy+pos, ix+iw-1, iy+pos)
        elif detail == "inset":
            canvas.frame(inner, 1)
            if iw >= 9 and ih >= 9:
                left = rng.choose(ix+2, ix+max(2, iw//3))
                canvas.rect(left, iy+2, min(ix+iw-3, left+max(1, iw//4)), iy+max(2, ih//3))
                canvas.rect(ix+iw-3, iy+ih-4, ix+iw-2, iy+ih-3)
        else:
            # Offset alternating plates create hierarchy without random pixels.
            for i in range(n):
                top = iy+round(i*ih/n)
                bottom = min(iy+ih-1, iy+round((i+1)*ih/n)-2)
                left = ix+(i % 2)*max(1, iw//4)
                right = ix+iw-1-((i+1) % 2)*max(1, iw//5)
                if bottom >= top:
                    canvas.rect(left, top, right, bottom)
        fasteners = []
        if c["fasteners"]:
            off = t+1
            for px, py in ((x+off, y+off), (x+w-off-1, y+off), (x+off, y+h-off-1), (x+w-off-1, y+h-off-1)):
                canvas.rect(px, py, px, py); fasteners.append(canvas.world((px, py)))
        panels.append({"box": [x+canvas.x, y+canvas.y, w, h], "detail": detail,
                       "fasteners": fasteners, "border": t})
    return {"panels": panels, "negative_space_min_percent": program["requirements"]["negative_space_min_percent"]}


def _pipework(canvas: _Canvas, program: dict, rng: _Random) -> dict:
    c = program["components"][0]
    nodes = [canvas.point(p) for p in c["nodes"]]
    d = canvas.size(c["diameter"], odd=True); r = d//2
    edges, degree = [], [0]*len(nodes)
    for a, b in c["edges"]:
        p, q = nodes[a], nodes[b]
        degree[a] += 1; degree[b] += 1
        if p[1] == q[1]:
            canvas.rect(min(p[0], q[0])-r, p[1]-r, max(p[0], q[0])+r, p[1]+r)
        else:
            canvas.rect(p[0]-r, min(p[1], q[1])-r, p[0]+r, max(p[1], q[1])+r)
        edges.append({"from": a, "to": b, "diameter": d})
    collars = []
    for e in edges:
        p, q = nodes[e["from"]], nodes[e["to"]]
        horizontal = p[1] == q[1]
        lo, hi = sorted((p[0], q[0]) if horizontal else (p[1], q[1]))
        if c["fittings"] and hi-lo >= d*3:
            pos = lo+(hi-lo)*(1+rng.choose(0, 1))//3
            if horizontal:
                bounds = (pos-1, p[1]-r-2, pos+1, p[1]+r+2)
            else:
                bounds = (p[0]-r-2, pos-1, p[0]+r+2, pos+1)
            canvas.rect(*bounds)
            collars.append(bounds)
    if c["fittings"]:
        for i, p in enumerate(nodes):
            if degree[i] >= 3:
                canvas.rect(p[0]-r-1, p[1]-r-1, p[0]+r+1, p[1]+r+1)
    probes = []
    for e in edges:
        p, q = nodes[e["from"]], nodes[e["to"]]
        horizontal = p[1] == q[1]
        lo, hi = sorted((p[0], q[0]) if horizontal else (p[1], q[1]))
        choices = []
        for pos in range(lo+r+3, hi-r-2):
            a, b = (pos, p[1]) if horizontal else (p[0], pos)
            if any(x0-1 <= a <= x1+1 and y0-1 <= b <= y1+1 for x0, y0, x1, y1 in collars):
                continue
            choices.append((a, b))
        if not choices:
            raise CompilerError("pipe segment too short for an independent diameter probe")
        p0 = choices[len(choices)//2]
        probes.append({"at": canvas.world(p0), "axis": "vertical" if horizontal else "horizontal", "diameter": d})
    return {"nodes": [canvas.world(p) for p in nodes], "edges": edges,
            "degree": degree, "diameter_probes": probes,
            "expected_cycles": program["requirements"]["cycles"],
            "endpoints": [i for i, v in enumerate(degree) if v == 1],
            "junctions": [i for i, v in enumerate(degree) if v >= 3],
            "fittings": [[a+canvas.x, b+canvas.y, c0-a+1, d0-b+1] for a, b, c0, d0 in collars]}


def _architecture(canvas: _Canvas, program: dict) -> dict:
    openings, solids, rooms = [], [], []
    # Compose all solids before subtracting declared openings. This handles
    # shared room walls without painting a neighbor's doorway shut.
    for c in program["components"]:
        box = canvas.box(c["box"]); x, y, w, h = box
        kind = c["kind"]
        if kind == "room":
            t = canvas.size(c["thickness"])
            canvas.frame(box, t)
            rooms.append([x+canvas.x, y+canvas.y, w, h])
            for o in c["openings"]:
                horizontal = o["side"] in ("top", "bottom")
                scale = (canvas.w-1 if horizontal else canvas.h-1)/95
                offset = round(o["offset"]*scale); size = max(3, round(o["size"]*scale))
                if o["side"] == "left":
                    b = [x, y+offset, t, size]
                elif o["side"] == "right":
                    b = [x+w-t, y+offset, t, size]
                elif o["side"] == "top":
                    b = [x+offset, y, size, t]
                else:
                    b = [x+offset, y+h-t, size, t]
                openings.append(b)
        elif kind == "stairs":
            n = c["steps"]
            for i in range(n):
                left = x+round(i*w/n); right = x+round((i+1)*w/n)-1
                level = i+1 if c["rise"] == "right" else n-i
                top = y+h-round(level*h/n)
                canvas.rect(left, top, right, y+h-1)
        else:
            canvas.rect(x, y, x+w-1, y+h-1)
            solids.append({"kind": kind, "box": [x+canvas.x, y+canvas.y, w, h]})
    for x, y, w, h in openings:
        canvas.rect(x, y, x+w-1, y+h-1, 0)
    req = program["requirements"]
    region = canvas.box(req["region"])
    return {"rooms": rooms, "solids": solids,
            "openings": [[x+canvas.x, y+canvas.y, w, h] for x, y, w, h in openings],
            "route": [canvas.world(canvas.point(p)) for p in req["route"]],
            "clearance": canvas.size(req["clearance"], odd=True),
            "region": [region[0]+canvas.x, region[1]+canvas.y, region[2], region[3]],
            "route_claim": "four-neighbor free-space square-clearance connectivity; not a gravity/jump/playtest result"}


def _rectangles(mask: bytearray, width: int, height: int) -> list[tuple[int, int, int, int]]:
    """Exact disjoint row runs, coalesced vertically; no hidden work inflation."""
    active: dict[tuple[int, int], tuple[int, int]] = {}
    result = []
    for y in range(height+1):
        runs = []
        x = 0
        while y < height and x < width:
            if not mask[y*width+x]:
                x += 1; continue
            start = x
            while x+1 < width and mask[y*width+x+1]:
                x += 1
            runs.append((start, x)); x += 1
        current = set(runs)
        for run in sorted(set(active)-current):
            start, end = active.pop(run)
            result.append((run[0], start, run[1], end))
        for run in runs:
            active[run] = (active.get(run, (y, y))[0], y)
    return result


def compile_program(program: dict, *, seed: int, focus: tuple[int, int, int, int] = (0, 0, 96, 96),
                    material: int = 58, allowed_materials: Iterable[int] = (58,),
                    max_operations: int = 512, max_cell_work: int = 100000) -> dict:
    validate_program(program)
    _integer(seed, "host seed", 0, 2**32-1)
    if type(focus) not in (list, tuple) or len(focus) != 4:
        raise CompilerError("host focus requires XYWH")
    x, y = [_integer(v, "focus origin", 0, 1048576) for v in focus[:2]]
    w, h = [_integer(v, "focus extent", 96, MAX_FOCUS) for v in focus[2:]]
    _integer(material, "host material", 1, 65535)
    allowed = tuple(allowed_materials)
    if any(type(v) is not int for v in allowed) or material not in allowed:
        raise CompilerError("host material is not authorized")
    _integer(max_operations, "host operation budget", 1, 8192)
    _integer(max_cell_work, "host cell-work budget", 1, MAX_FOCUS**2)
    rng = _Random(seed)
    variation = program["variation"]
    shift = (rng.choose(-variation, variation), rng.choose(-variation, variation))
    canvas = _Canvas((x, y, w, h), shift)
    if program["family"] == "greebles":
        semantic = _greebles(canvas, program, rng)
    elif program["family"] == "pipework":
        semantic = _pipework(canvas, program, rng)
    else:
        semantic = _architecture(canvas, program)
    rectangles = _rectangles(canvas.mask, w, h)
    work = sum(canvas.mask)
    if not rectangles or len(rectangles) > max_operations or work > max_cell_work:
        raise CompilerError("compiled plan exceeds host operation/cell-work budget or is empty")
    operations = [{"shape": "rectangle", "x0": a+x, "y0": b+y, "x1": c+x, "y1": d+y,
                   "material": material} for a, b, c, d in rectangles]
    result = {"schema": "cybersand.agent-painter.compiled/2", "compiler_version": COMPILER_VERSION,
              "compiler_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "program_sha256": digest(program), "operations_sha256": digest(operations),
              "family": program["family"], "focus": [x, y, w, h], "seed": seed,
              "material": material, "operation_count": len(operations), "estimated_cell_work": work,
              "unique_cells": work, "operations": operations, "semantic": semantic,
              "proposal_only": True, "native_qualified": False}
    check = verify_structure(result, [material if v else 0 for v in canvas.mask])
    if not check["passed"]:
        raise CompilerError("semantic preflight: "+"; ".join(check["errors"]))
    result["structural_preflight"] = check
    return result


def rasterize_operations(operations: list[dict], focus: Iterable[int] = (0, 0, 96, 96)) -> list[int]:
    """Independent exact rectangle oracle for comparison with native readback."""
    x, y, w, h = focus
    result = [0]*(w*h)
    for op in operations:
        _keys(op, {"shape", "x0", "y0", "x1", "y1", "material"}, "compiled rectangle")
        if op["shape"] != "rectangle":
            raise CompilerError("unsupported compiled operation")
        for name in ("x0", "y0", "x1", "y1", "material"):
            _integer(op[name], name, 0, 2**31-1)
        if not (x <= op["x0"] <= op["x1"] < x+w and y <= op["y0"] <= op["y1"] < y+h):
            raise CompilerError("compiled rectangle outside focus")
        for py in range(op["y0"]-y, op["y1"]-y+1):
            for px in range(op["x0"]-x, op["x1"]-x+1):
                result[py*w+px] = op["material"]
    return result


def _components(mask: list[bool], w: int, h: int) -> tuple[int, int]:
    remaining = bytearray(mask)
    count, enclosed = 0, 0
    for start in range(w*h):
        if not remaining[start]:
            continue
        count += 1; boundary = False
        remaining[start] = 0; queue = [start]
        while queue:
            i = queue.pop(); x, y = i % w, i//w
            boundary |= x == 0 or x == w-1 or y == 0 or y == h-1
            for nx, ny in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                if 0 <= nx < w and 0 <= ny < h and remaining[ny*w+nx]:
                    remaining[ny*w+nx] = 0; queue.append(ny*w+nx)
        enclosed += not boundary
    return count, enclosed


def verify_structure(compiled: dict, material_ids: list[int]) -> dict:
    """Evaluate actual native material cells, never a claimed model success.

    Receipt/identity integrity is owned by native.py. This function supplies
    semantic geometry checks in addition to its exact oracle comparison.
    """
    x0, y0, w, h = compiled["focus"]
    errors: list[str] = []
    if len(material_ids) != w*h or any(type(v) is not int or not 0 <= v <= 65535 for v in material_ids):
        return {"passed": False, "errors": ["native material dimensions or IDs invalid"]}
    material, semantic = compiled["material"], compiled["semantic"]
    occupied = [v != 0 for v in material_ids]
    painted = [v == material for v in material_ids]
    metrics: dict[str, Any] = {"family": compiled["family"], "painted_cells": sum(painted),
                               "negative_space_percent": 100*occupied.count(False)/(w*h)}

    def at(x: int, y: int) -> int:
        return material_ids[(y-y0)*w+x-x0] if x0 <= x < x0+w and y0 <= y < y0+h else -1

    family = compiled["family"]
    if family == "greebles":
        if metrics["negative_space_percent"] < semantic["negative_space_min_percent"]:
            errors.append("greeble negative-space requirement failed")
        details, sizes = set(), set()
        for p in semantic["panels"]:
            x, y, pw, ph = p["box"]; details.add(p["detail"]); sizes.add((pw, ph))
            border = [(px, y) for px in range(x, x+pw)] + [(px, y+ph-1) for px in range(x, x+pw)]
            border += [(x, py) for py in range(y, y+ph)] + [(x+pw-1, py) for py in range(y, y+ph)]
            if any(at(px, py) != material for px, py in border):
                errors.append("incomplete native panel border")
            if any(at(px, py) != material for px, py in p["fasteners"]):
                errors.append("missing native fastener")
            inner = [at(px, py) for py in range(y+p["border"], y+ph-p["border"]) for px in range(x+p["border"], x+pw-p["border"])]
            if not any(v == material for v in inner) or not any(v == 0 for v in inner):
                errors.append("panel requires both interior details and voids")
        metrics.update(panel_count=len(semantic["panels"]), detail_kinds=len(details), panel_sizes=len(sizes))
    elif family == "pipework":
        count, _ = _components(painted, w, h)
        _, holes = _components([not v for v in occupied], w, h)
        if count != 1:
            errors.append("native pipes are disconnected")
        if holes != semantic["expected_cycles"]:
            errors.append("native pipe enclosed-loop count differs from graph")
        for e in semantic["edges"]:
            a, b = (semantic["nodes"][e[k]] for k in ("from", "to"))
            if a[1] == b[1]:
                cells = ((x, a[1]) for x in range(min(a[0], b[0]), max(a[0], b[0])+1))
            else:
                cells = ((a[0], y) for y in range(min(a[1], b[1]), max(a[1], b[1])+1))
            if any(at(x, y) != material for x, y in cells):
                errors.append("native pipe centerline has a gap")
        actual_diameters = []
        for probe in semantic["diameter_probes"]:
            x, y = probe["at"]; dx, dy = (0, 1) if probe["axis"] == "vertical" else (1, 0)
            r = probe["diameter"]//2
            correct = all(at(x+t*dx, y+t*dy) == material for t in range(-r, r+1))
            correct &= at(x-(r+1)*dx, y-(r+1)*dy) == 0 and at(x+(r+1)*dx, y+(r+1)*dy) == 0
            actual_diameters.append(correct)
            if not correct:
                errors.append("native pipe diameter/clearance mismatch")
        metrics.update(connected_components=count, enclosed_loops=holes,
                       endpoints=len(semantic["endpoints"]), junctions=len(semantic["junctions"]),
                       diameter_probes=len(actual_diameters), diameter_probes_passed=sum(actual_diameters))
    else:
        for x, y, bw, bh in semantic["openings"]:
            if any(at(px, py) != 0 for py in range(y, y+bh) for px in range(x, x+bw)):
                errors.append("native architecture opening is obstructed")
        route = semantic["route"]
        metrics.update(room_count=len(semantic["rooms"]), opening_count=len(semantic["openings"]),
                       route_requested=bool(route), route_claim=semantic["route_claim"])
        if route:
            rx, ry, rw, rh = semantic["region"]; radius = semantic["clearance"]//2
            # Integral image makes clearance checks bounded by focus area.
            stride = w+1; prefix = [0]*((w+1)*(h+1))
            for y in range(h):
                row = 0
                for x in range(w):
                    row += occupied[y*w+x]
                    prefix[(y+1)*stride+x+1] = prefix[y*stride+x+1]+row

            def clear(p: tuple[int, int]) -> bool:
                x, y = p
                if not (rx+radius <= x < rx+rw-radius and ry+radius <= y < ry+rh-radius):
                    return False
                a, b, c, d = x-x0-radius, y-y0-radius, x-x0+radius+1, y-y0+radius+1
                if a < 0 or b < 0 or c > w or d > h:
                    return False
                return prefix[d*stride+c]-prefix[b*stride+c]-prefix[d*stride+a]+prefix[b*stride+a] == 0

            start, goal = map(tuple, route)
            seen = {start} if clear(start) else set()
            queue = deque(seen)
            while queue and goal not in seen:
                x, y = queue.popleft()
                for p in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                    if p not in seen and clear(p):
                        seen.add(p); queue.append(p)
            metrics["clearance_route_passed"] = goal in seen
            metrics["clearance_cells"] = semantic["clearance"]
            if goal not in seen:
                errors.append("native architecture route lacks requested square clearance")
    return {"passed": not errors, "errors": sorted(set(errors)), "metrics": metrics}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("program", type=Path)
    parser.add_argument("--seed", type=int, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = compile_program(parse_program(args.program.read_text()), seed=args.seed)
    except (CompilerError, OSError) as exc:
        parser.exit(2, f"compilation refused: {exc}\n")
    args.out.write_text(json.dumps(result, indent=2, allow_nan=False)+"\n")


if __name__ == "__main__":
    main()
