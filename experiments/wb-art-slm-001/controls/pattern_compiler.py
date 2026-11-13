"""Bounded, seed-replayable pattern programs for CyberSand's Art JSON planner.

This module does not draw or authorize mutations. It produces local-coordinate
geometry; the existing Workbench executor remains the authority for native
source protection, world revisions, acknowledgement, history and persistence.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import random
from pathlib import Path
from typing import Any

VERSION = 1
COMPILER_VERSION = "wb-art-slm-001/1.0.0"
THEMES = ("roots", "coral", "veins", "mycelium", "strata", "dunes",
          "crystals", "honeycomb", "labyrinth", "ruins", "circuitry", "ribs")
MOTIFS = ("branch", "fan", "network", "threads", "bands", "ridges",
          "facets", "cells", "maze", "blocks", "orthogonal", "ribs")
LAYOUTS = ("center", "offset", "split", "border")
MODIFIERS = ("sparse", "dense", "open", "twisted", "thick", "thin", "symmetric")
MAX_LAYERS = 4
MAX_FOCUS = 512


class CompilerError(ValueError):
    """Invalid input or a preflight capacity refusal; no partial plan escapes."""


def canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def _integer(value: Any, name: str, low: int, high: int) -> int:
    if type(value) is not int or not low <= value <= high:
        raise CompilerError(f"{name} must be an integer in [{low},{high}]")
    return value


def _number(value: Any, name: str, low: float, high: float) -> float:
    if type(value) not in (int, float) or not low <= value <= high or not math.isfinite(value):
        raise CompilerError(f"{name} must be finite in [{low},{high}]")
    return float(value)


def validate_program(program: Any) -> None:
    if type(program) is not dict or set(program) != {"version", "theme", "layers"}:
        raise CompilerError("program requires exactly version, theme, layers")
    if type(program["version"]) is not int or program["version"] != VERSION:
        raise CompilerError("unsupported program version")
    if program["theme"] not in THEMES:
        raise CompilerError("unknown theme")
    layers = program["layers"]
    if type(layers) is not list or not 1 <= len(layers) <= MAX_LAYERS:
        raise CompilerError(f"layers must contain 1..{MAX_LAYERS} entries")
    for i, layer in enumerate(layers):
        if type(layer) is not dict or set(layer) != {"motif", "density", "scale", "width", "angle", "layout"}:
            raise CompilerError(f"layer {i} has missing or unknown fields")
        if layer["motif"] not in MOTIFS or layer["layout"] not in LAYOUTS:
            raise CompilerError(f"layer {i} has an unknown motif or layout")
        for key in ("density", "scale", "width"):
            _number(layer[key], f"layers[{i}].{key}", 0, 1)
        _number(layer["angle"], f"layers[{i}].angle", -180, 180)


_BASE = {
    "roots": ("branch", .57, .63, .58), "coral": ("fan", .62, .59, .56),
    "veins": ("network", .55, .56, .50), "mycelium": ("threads", .65, .58, .05),
    "strata": ("bands", .59, .55, .42), "dunes": ("ridges", .45, .62, .50),
    "crystals": ("facets", .49, .62, .36), "honeycomb": ("cells", .63, .56, .20),
    "labyrinth": ("maze", .62, .56, .15), "ruins": ("blocks", .56, .55, .55),
    "circuitry": ("orthogonal", .56, .59, .20), "ribs": ("ribs", .58, .56, .42),
}
# A second generic motif gives some template families genuine composition.
_COMPANION = {"roots": "network", "coral": "branch", "veins": "threads",
              "mycelium": "network", "strata": "facets", "dunes": "bands",
              "crystals": "ridges", "honeycomb": "ribs", "labyrinth": "blocks",
              "ruins": "ribs", "circuitry": "blocks", "ribs": "bands"}


def make_program(theme: str, variant_id: int = 0, modifiers: list[str] | None = None) -> dict:
    """Create an explicit reference program, not a model-produced prediction.

    variant_id is a structural template ID (0..7): it changes layout and, in the
    second half, motif composition. Splits must group this before seed expansion.
    """
    if theme not in THEMES:
        raise CompilerError("unknown theme")
    _integer(variant_id, "variant_id", 0, 7)
    mods = [] if modifiers is None else modifiers
    if type(mods) is not list or any(type(x) is not str or x not in MODIFIERS for x in mods):
        raise CompilerError("unsupported modifier list")
    if len(mods) != len(set(mods)):
        raise CompilerError("duplicate modifier")
    if {"sparse", "dense"} <= set(mods) or {"thick", "thin"} <= set(mods):
        raise CompilerError("conflicting modifiers")
    motif, density, scale, stroke = _BASE[theme]
    density = .27 if "sparse" in mods else .82 if "dense" in mods else density
    stroke = .90 if "thick" in mods else .03 if "thin" in mods else stroke
    angle = 22 if "twisted" in mods else 0
    layout = "border" if "open" in mods else LAYOUTS[variant_id % 4]
    first = {"motif": motif, "density": density, "scale": scale,
             "width": stroke, "angle": angle, "layout": layout}
    layers = [first]
    if variant_id >= 4:
        layers.append({"motif": _COMPANION[theme], "density": round(density * .35, 3),
                       "scale": .31, "width": .08, "angle": -angle,
                       "layout": "border"})
    # Split has exact horizontal reflection semantics, including companion layers.
    if "symmetric" in mods:
        for layer in layers:
            layer["layout"] = "split"
            layer["angle"] = 0
    program = {"version": VERSION, "theme": theme, "layers": layers}
    validate_program(program)
    return program


def _regions(width: int, height: int, layout: str) -> list[tuple[float, float, float, float]]:
    m = max(2, min(width, height) * .045)
    if layout == "offset":
        return [(m, m, width * .72 - m, height * .84 - m)]
    if layout == "split":
        return [(m, m, width * .45 - m, height - 2 * m),
                (width * .55, m, width * .45 - m, height - 2 * m)]
    if layout == "border":
        # Four non-overlapping strips preserve a true central void.
        return [(m, m, width - 2*m, height*.23-m),
                (m, height*.77, width - 2*m, height*.23-m),
                (m, height*.23, width*.23-m, height*.54),
                (width*.77, height*.23, width*.23-m, height*.54)]
    return [(m, m, width - 2*m, height - 2*m)]


class _Builder:
    def __init__(self, width, height, material, max_shapes, max_cost):
        self.width, self.height, self.material = width, height, material
        self.max_shapes, self.max_cost = max_shapes, max_cost
        self.operations: list[dict] = []
        self.op_costs: list[int] = []
        self.cost = 0
        self.seen: set[str] = set()
        self.region = (0., 0., float(width-1), float(height-1))
        self.angle = 0.

    def point(self, p, margin=0):
        x, y, w, h = self.region
        a = math.radians(self.angle)
        dx, dy = p[0] - (x+w/2), p[1] - (y+h/2)
        px = x+w/2 + dx*math.cos(a)-dy*math.sin(a)
        py = y+h/2 + dx*math.sin(a)+dy*math.cos(a)
        lo_x, hi_x = math.ceil(x)+margin, math.floor(x+w)-margin
        lo_y, hi_y = math.ceil(y)+margin, math.floor(y+h)-margin
        if lo_x > hi_x or lo_y > hi_y:
            lo_x=hi_x=round(x+w/2); lo_y=hi_y=round(y+h/2)
        return [max(0, min(self.width-1, max(lo_x, min(hi_x, round(px))))),
                max(0, min(self.height-1, max(lo_y, min(hi_y, round(py)))))]

    def emit(self, shape, cost):
        shape["material"] = self.material
        key = canonical_json(shape)
        if key in self.seen:
            return
        if len(self.operations) >= self.max_shapes or self.cost + cost > self.max_cost:
            raise CompilerError("compiled plan exceeds host shape/cell-work budget")
        self.operations.append(shape); self.op_costs.append(cost); self.seen.add(key); self.cost += cost

    def line(self, a, b, width=1):
        width = max(1, min(9, int(width)))
        margin = math.ceil(width/2) if width > 1 else 0
        a, b = self.point(a, margin), self.point(b, margin)
        steps = max(abs(a[0]-b[0]),abs(a[1]-b[1]))+1
        cost = steps if width==1 else steps*(2*width+3)+4*width*width
        self.emit({"shape":"line","x0":a[0],"y0":a[1],"x1":b[0],"y1":b[1],"width":width}, cost)

    def polyline(self, points, width=1):
        width=max(1,min(9,int(width)))
        margin=math.ceil(width/2) if width>1 else 0
        out=[]
        for p in points:
            q=self.point(p,margin)
            if not out or q!=out[-1]:out.append(q)
        if len(out)<2:return
        steps=sum(max(abs(a[0]-b[0]),abs(a[1]-b[1]))+1 for a,b in zip(out,out[1:]))
        cost=steps if width==1 else steps*(2*width+3)+len(out)*4*width*width
        self.emit({"shape":"polyline","points":out,"width":width},cost)

    def polygon(self, points):
        out=[]
        for p in points:
            q=self.point(p)
            if not out or q!=out[-1]:out.append(q)
        if len(set(map(tuple,out)))<3:return
        if out[0]==out[-1]:out.pop()
        twice_area=sum(a[0]*c[1]-c[0]*a[1] for a,c in zip(out,out[1:]+out[:1]))
        if twice_area==0:return
        # Bounding-box area is a conservative bound for the native fill.
        cost=(max(p[0] for p in out)-min(p[0] for p in out)+1)*(max(p[1] for p in out)-min(p[1] for p in out)+1)
        self.emit({"shape":"polygon","points":out},cost)

    def rect(self, x0,y0,x1,y1):
        if self.angle:
            self.polygon([(x0,y0),(x1,y0),(x1,y1),(x0,y1)]);return
        a,b=self.point((x0,y0)),self.point((x1,y1))
        x0,x1=sorted((a[0],b[0]));y0,y1=sorted((a[1],b[1]))
        self.emit({"shape":"rectangle","x0":x0,"y0":y0,"x1":x1,"y1":y1},(x1-x0+1)*(y1-y0+1))

    def disc(self, p, radius):
        q=self.point(p)
        x,y,w,h=self.region
        r=max(0,min(int(radius),q[0]-math.ceil(x),math.floor(x+w)-q[0],q[1]-math.ceil(y),math.floor(y+h)-q[1]))
        self.emit({"shape":"disc","x":q[0],"y":q[1],"radius":r},(2*r+1)**2)


def _stroke(b, layer):
    return 1+round(layer["width"]*min(b.region[2:])*.024)


def _branch(b, r, l):
    x,y,w,h=b.region; d=l["density"]; stroke=_stroke(b,l)
    roots=1+int(d*3); depth=3+int(l["scale"]*3)
    for k in range(roots):
        start=(x+w*(k+1)/(roots+1),y+h*.96)
        queue=[(start,-math.pi/2+r.uniform(-.16,.16),h*(.20+.07*l["scale"]),depth)]
        while queue:
            start,a,length,level=queue.pop()
            end=(start[0]+math.cos(a)*length,start[1]+math.sin(a)*length)
            mid=((start[0]+end[0])/2+r.uniform(-1,1)*length*.12,(start[1]+end[1])/2)
            b.polyline([start,mid,end],max(1,round(stroke*level/depth)))
            if level<=1:continue
            spread=.32+r.random()*.43
            children=2+(r.random()<d*.18)
            for j in range(children):
                da=(j/(children-1)-.5)*2*spread+r.uniform(-.1,.1)
                queue.append((end,a+da,length*r.uniform(.58,.79),level-1))


def _fan(b,r,l):
    x,y,w,h=b.region; count=2+int(l["density"]*5); stroke=_stroke(b,l)
    for k in range(count):
        cx=x+w*(k+.5)/count; cy=y+h*r.uniform(.72,.95)
        radius=min(w/count*.8,h*.6)*(0.7+l["scale"]*.6)
        arms=4+int(l["density"]*7)
        for j in range(arms):
            a=-math.pi*.92+j/max(1,arms-1)*math.pi*.84
            length=radius*r.uniform(.6,1.2)
            tip=(cx+math.cos(a)*length,cy+math.sin(a)*length)
            mid=(cx+math.cos(a)*length*.45,cy+math.sin(a)*length*.65)
            b.polyline([(cx,cy),mid,tip],stroke)
            b.disc(tip,max(1,stroke))
            if j%2==0:
                side=(mid[0]+math.cos(a-.5)*length*.35,mid[1]+math.sin(a-.5)*length*.35)
                b.line(mid,side,1)


def _network(b,r,l):
    x,y,w,h=b.region; n=5+int(l["density"]*20); stroke=_stroke(b,l)
    pts=[(x+r.uniform(.05,.95)*w,y+r.uniform(.05,.95)*h) for _ in range(n)]
    edges=[];connected={0};remaining=set(range(1,n))
    while remaining:
        _,a,c=min(((pts[a][0]-pts[c][0])**2+(pts[a][1]-pts[c][1])**2,a,c) for a in connected for c in remaining)
        edges.append((a,c));connected.add(c);remaining.remove(c)
    for a in range(n):
        if r.random()<l["density"]*.55:
            near=sorted((math.dist(pts[a],p),j) for j,p in enumerate(pts) if a!=j)
            edges.append((a,near[min(1,len(near)-1)][1]))
    for i,(a,c) in enumerate(edges):
        p,q=pts[a],pts[c]
        mid=((p[0]+q[0])/2+r.uniform(-.06,.06)*w,(p[1]+q[1])/2+r.uniform(-.06,.06)*h)
        b.polyline([p,mid,q],stroke if i<n//3 else max(1,stroke-1))


def _threads(b,r,l):
    x,y,w,h=b.region; n=4+int(l["density"]*20); steps=8+int(l["scale"]*16)
    for _ in range(n):
        px=x+r.random()*w;py=y+r.random()*h;a=r.uniform(0,math.tau);pts=[(px,py)]
        for j in range(steps):
            a+=r.uniform(-.9,.9);length=min(w,h)*(.025+.045*l["scale"])
            px=max(x,min(x+w,px+math.cos(a)*length));py=max(y,min(y+h,py+math.sin(a)*length));pts.append((px,py))
            if j%5==0:
                b.line((px,py),(px+math.cos(a+1.2)*length*1.7,py+math.sin(a+1.2)*length*1.7),1)
        b.polyline(pts,_stroke(b,l))


def _bands(b,r,l):
    x,y,w,h=b.region; n=3+int(l["density"]*10); thickness=max(1,h/n*(.08+.28*l["width"]))
    fault=x+w*r.uniform(.35,.7);offset=h*r.uniform(.025,.09)
    phase=r.random()*math.tau
    for i in range(n):
        base=y+h*(i+.5)/n;pts=[]
        for j in range(17):
            px=x+w*j/16
            py=base+math.sin(j/16*math.tau*(1.1+l["scale"])+phase+i*.45)*h*.035
            py+=(offset if px>fault else 0)
            pts.append((px,py))
        lower=[(px,py+thickness*r.uniform(.8,1.2)) for px,py in reversed(pts)]
        b.polygon(pts+lower)


def _ridges(b,r,l):
    x,y,w,h=b.region;n=2+int(l["density"]*5)
    for i in range(n):
        baseline=y+h*(i+1)/(n+.3);height=h/n*(.35+.4*l["scale"])
        peaks=2+int(l["scale"]*3);top=[(x,baseline)]
        for j in range(peaks):
            left=x+w*j/peaks;right=x+w*(j+1)/peaks
            crest=left+(right-left)*r.uniform(.65,.82)
            top.extend([(left,baseline),(crest,baseline-height*r.uniform(.65,1)),(right,baseline)])
        # Preserve deliberate empty bands rather than filling a complete slope.
        b.polygon(top+[(x+w,baseline+max(1,height*.12)),(x,baseline+max(1,height*.12))])


def _facets(b,r,l):
    x,y,w,h=b.region;n=3+int(l["density"]*13)
    for _ in range(n):
        cx=x+r.uniform(.1,.9)*w;cy=y+r.uniform(.25,.92)*h
        size=min(w,h)*(.045+.15*l["scale"])*r.uniform(.6,1.5)
        a=r.uniform(-.7,.7);ux,uy=math.sin(a),-math.cos(a);vx,vy=-uy,ux
        pts=[(cx-vx*size*.28,cy-vy*size*.28),(cx+ux*size-vx*size*.22,cy+uy*size-vy*size*.22),
             (cx+ux*size*1.5,cy+uy*size*1.5),(cx+ux*size+vx*size*.22,cy+uy*size+vy*size*.22),
             (cx+vx*size*.28,cy+vy*size*.28)]
        b.polygon(pts)


def _cells(b,r,l):
    x,y,w,h=b.region;rad=max(3,min(w,h)/max(3,9-l["scale"]*5));stroke=_stroke(b,l)
    row=0;cy=y+rad
    while cy<y+h-rad*.3:
        cx=x+rad+(row%2)*rad*.866
        while cx<x+w-rad*.3:
            if r.random()<.35+.65*l["density"]:
                verts=[(cx+math.cos(math.pi/6+k*math.pi/3)*rad*.88,cy+math.sin(math.pi/6+k*math.pi/3)*rad*.88) for k in range(6)]
                for k in range(6):
                    if r.random()>.12*(1-l["density"]):b.line(verts[k],verts[(k+1)%6],stroke)
            cx+=rad*1.732
        cy+=rad*1.5;row+=1


def _maze(b,r,l):
    x,y,w,h=b.region
    cols=max(3,min(15,round(4+l["density"]*8)));rows=max(3,min(15,round(cols*h/max(w,1))))
    cells={(a,c) for a in range(cols) for c in range(rows)};visited={(0,0)};stack=[(0,0)];passages=set()
    while stack:
        a,c=stack[-1];neighbors=[p for p in ((a-1,c),(a+1,c),(a,c-1),(a,c+1)) if p in cells and p not in visited]
        if not neighbors:stack.pop();continue
        q=r.choice(neighbors);passages.add(tuple(sorted(((a,c),q))));visited.add(q);stack.append(q)
    cw,ch=w/cols,h/rows;stroke=_stroke(b,l)
    for a in range(cols):
        for c in range(rows):
            if a<cols-1 and tuple(sorted(((a,c),(a+1,c)))) not in passages:
                if r.random()>.08*l["scale"]:b.line((x+(a+1)*cw,y+c*ch),(x+(a+1)*cw,y+(c+1)*ch),stroke)
            if c<rows-1 and tuple(sorted(((a,c),(a,c+1)))) not in passages:
                if r.random()>.08*l["scale"]:b.line((x+a*cw,y+(c+1)*ch),(x+(a+1)*cw,y+(c+1)*ch),stroke)
    # The outer two gaps provide visible entry/exit instead of a sealed box.
    b.polyline([(x,y+ch),(x,y+h),(x+w-cw,y+h)],stroke)
    b.polyline([(x+cw,y),(x+w,y),(x+w,y+h-ch)],stroke)


def _blocks(b,r,l):
    x,y,w,h=b.region;tiers=2+int(l["density"]*5);bays=3+int(l["scale"]*5)
    thickness=max(1,_stroke(b,l));bw=w/bays;th=h/tiers
    for c in range(tiers):
        base=y+(c+1)*th
        for a in range(bays):
            if r.random()<.15+(1-l["density"])*.35:continue
            left=x+a*bw;right=left+bw*r.uniform(.64,.94)
            b.rect(left,base-thickness,right,base)
            if r.random()<.8:b.rect(left,base-th*r.uniform(.45,.95),left+thickness,base)
            if r.random()<.35:b.line((right,base),(right-bw*.25,base-th*.55),1)


def _orthogonal(b,r,l):
    x,y,w,h=b.region;grid=5+int(l["scale"]*7);paths=3+int(l["density"]*18);stroke=_stroke(b,l)
    def node():return (x+r.randrange(grid+1)*w/grid,y+r.randrange(grid+1)*h/grid)
    for i in range(paths):
        a,c=node(),node();mx=(a[0]+c[0])/2
        pts=[a,(mx,a[1]),(mx,c[1]),c] if i%2 else [a,(a[0],c[1]),c]
        b.polyline(pts,stroke)
        if i%3==0:
            size=max(1,min(w,h)*.018)
            b.rect(c[0]-size,c[1]-size,c[0]+size,c[1]+size)


def _ribs(b,r,l):
    x,y,w,h=b.region;n=4+int(l["density"]*15);stroke=_stroke(b,l)
    bend=(.15+.3*l["scale"])*w
    spine=[]
    for i in range(n):
        t=(i+.5)/n;cy=y+t*h;cx=x+w*.45+math.sin(t*math.pi)*bend*.35
        spine.append((cx,cy));span=w*(.21+.18*math.sin(t*math.pi))*r.uniform(.8,1)
        for side in (-1,1):
            b.polyline([(cx,cy),(cx+side*span*.6,cy-h*.025),(cx+side*span,cy+h*(.02+.04*l["scale"]))],stroke)
    b.polyline(spine,max(1,stroke))


_DRAW = {"branch":_branch,"fan":_fan,"network":_network,"threads":_threads,
         "bands":_bands,"ridges":_ridges,"facets":_facets,"cells":_cells,
         "maze":_maze,"blocks":_blocks,"orthogonal":_orthogonal,"ribs":_ribs}


def reflected_operation(operation: dict, width: int) -> dict:
    """Return the exact horizontal reflection of a canonical native operation."""
    op=copy.deepcopy(operation)
    if "points" in op:
        op["points"]=[[width-1-x,y] for x,y in op["points"]]
    elif op["shape"]=="disc":
        op["x"]=width-1-op["x"]
    else:
        op["x0"],op["x1"]=width-1-op["x0"],width-1-op["x1"]
        if op["shape"]=="rectangle":op["x0"],op["x1"]=sorted((op["x0"],op["x1"]))
    return op


def structural_signature(program: dict) -> str:
    """Group templates after modifiers, before paraphrase/seed expansion.

    This is an explicit template grouping, not proof of unseen motif learning.
    """
    validate_program(program)
    return canonical_json({"theme":program["theme"],"structure":[[x["motif"],x["layout"]] for x in program["layers"]]})


def compile_with_report(program: dict, width: int, height: int, seed: int, material: int = 58,
                        *, max_shapes: int = 2048, max_estimated_cells: int = 131072) -> dict:
    validate_program(program)
    _integer(width,"width",16,MAX_FOCUS);_integer(height,"height",16,MAX_FOCUS)
    _integer(seed,"seed",0,2**63-1)
    if type(material) is not int or material not in (0,58):
        raise CompilerError("v1 host material must be verified Empty 0 or Hard Wall 58")
    _integer(max_shapes,"max_shapes",1,2048);_integer(max_estimated_cells,"max_estimated_cells",1,131072)
    b=_Builder(width,height,material,max_shapes,max_estimated_cells)
    for index,layer in enumerate(program["layers"]):
        regions=_regions(width,height,layer["layout"])
        if layer["layout"]=="split":regions=regions[:1]
        for ri,region in enumerate(regions):
            # Stable substreams prevent unrelated layer edits perturbing earlier layers.
            digest=hashlib.sha256(f"{COMPILER_VERSION}:{seed}:{index}:{ri}".encode()).digest()
            r=random.Random(int.from_bytes(digest[:16],"big"))
            b.region=region;b.angle=layer["angle"]
            start=len(b.operations)
            _DRAW[layer["motif"]](b,r,layer)
            if layer["layout"]=="split":
                original=list(zip(b.operations[start:],b.op_costs[start:]))
                for operation,cost in original:b.emit(reflected_operation(operation,width),cost)
    if not b.operations:
        raise CompilerError("positive pattern compiled to no operations")
    return {"compiler_version":COMPILER_VERSION,"program_sha256":hashlib.sha256(canonical_json(program).encode()).hexdigest(),
            "width":width,"height":height,"seed":seed,"material":material,
            "operation_count":len(b.operations),"estimated_cell_work":b.cost,"operations":b.operations}


def compile_program(program: dict, width: int, height: int, seed: int, material: int = 58,
                    *, max_shapes: int = 2048, max_estimated_cells: int = 131072) -> list[dict]:
    return compile_with_report(program,width,height,seed,material,max_shapes=max_shapes,
                               max_estimated_cells=max_estimated_cells)["operations"]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    source=p.add_mutually_exclusive_group(required=True)
    source.add_argument("--theme",choices=THEMES);source.add_argument("--program",type=Path)
    p.add_argument("--variant",type=int,default=0);p.add_argument("--modifier",action="append",default=[],choices=MODIFIERS)
    p.add_argument("--width",type=int,default=96);p.add_argument("--height",type=int,default=96)
    p.add_argument("--seed",type=int,default=1);p.add_argument("--material",type=int,default=58,choices=(0,58))
    p.add_argument("--out",type=Path);p.add_argument("--report",action="store_true")
    args=p.parse_args()
    try:
        program=json.loads(args.program.read_text()) if args.program else make_program(args.theme,args.variant,args.modifier)
        result=compile_with_report(program,args.width,args.height,args.seed,args.material)
        output=result if args.report else result["operations"]
        data=json.dumps(output,indent=2,allow_nan=False)+"\n"
        if args.out:args.out.write_text(data)
        else:print(data,end="")
    except (CompilerError,json.JSONDecodeError,OSError) as e:p.exit(2,f"pattern compilation refused: {e}\n")


if __name__ == "__main__":
    main()
