#!/usr/bin/env python3
"""Independent double-precision historical geometry audit, never live admission.

Reads original retained Git objects, does not import SOL or modify its records.
"""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOL = "1598115c9065239cc1eaec11e99077274b457be1"
REPORT = "docs/audits/sol281-20261103/hosted/9edc4f8f7d8cd8fc65119d176c9e1981ab6ea77d/cohorts/linux/mechanism/host/synchronized-contact-w1.json"
REPORT_SHA = "7b91158f0d4652cb415e9dfd614cda4ab535685f39cfbcf663457c26cf513724"


def clip(poly, axis, bound, sign):
    if not poly:
        return []
    out = []
    previous = poly[-1]
    old = sign*(previous[axis]-bound)
    for point in poly:
        new = sign*(point[axis]-bound)
        if (old >= 0) != (new >= 0):
            t = old/(old-new)
            out.append(tuple(a+(b-a)*t for a,b in zip(previous,point)))
        if new >= 0:
            out.append(point)
        previous, old = point,new
    return out


def cell_area(poly, x, y):
    for axis,bound,sign in [(0,x,1),(0,x+1,-1),(1,y,1),(1,y+1,-1)]:
        poly = clip(poly,axis,bound,sign)
    if len(poly) < 3:
        return 0.0
    # Translate before cross products to avoid world-coordinate cancellation.
    poly = [(p[0]-x,p[1]-y) for p in poly]
    return abs(sum(a[0]*b[1]-a[1]*b[0] for a,b in zip(poly,poly[1:]+poly[:1])))*0.5


def main():
    profile = json.loads((ROOT/"godot/tests/fixtures/la_selective/registration.json").read_text())
    source = profile["source_rectangles"]
    members = [(x,y) for rx,ry,w,h in source for y in range(ry,ry+h) for x in range(rx,rx+w)]
    assert len(members) == len(set(members)) == 520
    assert all(tuple(hole) not in members for hole in profile["source_holes"])
    # Preserve full original member tuple distinctions even though the live
    # surrogate carries no duplicate authoritative native RedBrick members.
    tuples = [[x,y,43,0,0,200] for x,y in sorted(members,key=lambda p:(p[1],p[0]))]
    proxies = [[(x+43,y),(x+w+43,y),(x+w+43,y+h),(x+43,y+h)] for x,y,w,h in source]
    sand = sum(cell_area(p,x,y) for p in proxies for y in range(28,31) for x in range(90,93))
    wall_cells = {(x,y) for x in range(89,94) for y in range(27,32)
                  if x in [89,93] or y in [27,31]}
    wall = sum(cell_area(p,x,y) for p in proxies for x,y in wall_cells)
    assert sand == 9 and wall == 16
    raw = subprocess.check_output(["git","-C",str(ROOT),"show",SOL+":"+REPORT])
    assert hashlib.sha256(raw).hexdigest() == REPORT_SHA
    retained = json.loads(raw)
    case = next(c for c in retained["cases"] if c["fixture"]=="embedded_stationary")
    recorded = retained["geometries"][case["initial"]["measurement"]["geometry_id"]]
    tiny = cell_area(recorded["proxies"][5],53,67)
    assert tiny > 1e-9
    result = dict(source=SOL,report=REPORT,report_sha256=REPORT_SHA,scope="independent geometry only; no live eligibility admission",
                  member_count=520,proxy_count=6,holes_empty=True,member_tuples=tuples,
                  source_rectangles=source,source_com=profile["source_com"],source_inertia=profile["source_inertia"],
                  nine_cell=dict(sand_area=sand,hard_Wall_material_id=1,hard_Wall_area=wall,eligible=False),
                  tiny_hard_edge=dict(proxy=6,cell=[53,67],material=43,area=tiny,exclusion_filter=1e-9,eligible=False),
                  limits=["Recorded material RLE does not establish state, temperature, residency or foreign-mask authority.",
                          "Double clipping of recorded corners differs from double common-transform reconstruction.",
                          "No SOL ownership transfer, hard eligibility guard or live refusal is executed by this script."])
    output=ROOT/"build/la-selective/historical-geometry.json"
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps({k:v for k,v in result.items() if k not in ["member_tuples","limits"]}))


if __name__=="__main__":
    main()
