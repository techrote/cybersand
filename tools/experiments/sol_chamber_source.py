#!/usr/bin/env python3
"""Authenticate the complete historical SOL payload, without importing its code."""
import hashlib
import json
from pathlib import Path
import struct
import subprocess

ROOT=Path(__file__).resolve().parents[2]
PROFILE=ROOT/"godot/tests/fixtures/sol_chamber/registration.json"

def main():
    p=json.loads(PROFILE.read_text(encoding="utf-8"))
    raw=subprocess.check_output(["git","-C",str(ROOT),"show",p["historical_source"]+":"+p["historical_report"]])
    assert hashlib.sha256(raw).hexdigest()==p["historical_report_sha256"]
    source=json.loads(raw)["source"];flat=source["members"]
    assert len(flat)==520*6
    members=[flat[i:i+6] for i in range(0,len(flat),6)]
    rectangles=p["source_rectangles"]
    assert source["rectangles"]==[v for r in rectangles for v in r]
    expected=[[x,y,43,0,0,200] for rx,ry,w,h in rectangles for y in range(ry,ry+h) for x in range(rx,rx+w)]
    assert sorted(members)==sorted(expected) and len({tuple(m[:2]) for m in members})==520
    assert all(hole not in [m[:2] for m in members] for hole in p["source_holes"])
    assert source["member_count"]==source["mass"]==520 and source["shape_count"]==6
    com64=[sum(m[axis]+.5 for m in members)/520 for axis in range(2)]
    com32=[struct.unpack("<f",struct.pack("<f",v))[0] for v in com64]
    # The historical JSON decimal display is not a bit-exact COM encoding.
    assert all(abs(a-b)<1e-12 for a,b in zip(com32,source["center"]))
    inertia=sum(1/6+(m[0]+.5-com64[0])**2+(m[1]+.5-com64[1])**2 for m in members)
    assert abs(inertia-source["inertia"])<1e-8 and source["inertia"]==p["nominal_inertia"]
    out=dict(schema="cybersand.sol-chamber.source.v1",source=p["historical_source"],report=p["historical_report"],report_sha256=p["historical_report_sha256"],
        git_blob=subprocess.check_output(["git","-C",str(ROOT),"rev-parse",p["historical_source"]+":"+p["historical_report"]]).decode().strip(),
        original=source,member_tuples=members,exact_geometric_com64=com64,stored_com32=com32,stored_com32le=struct.pack("<ff",*com32).hex(),
        recomputed_geometric_inertia=inertia,translation=p["translation"],limits=["Geometry payload evidence, no duplicate native aggregate authority.","Stored float32 COM and actual Rapier inertia remain separately reported."])
    target=PROFILE.with_name("source.json");assert not target.exists(),"Retain earlier extraction"
    target.write_bytes((json.dumps(out,indent=2)+"\n").encode());print("authenticated520 full tuples,6proxies,both holes; wrote",target)

if __name__=="__main__":main()
