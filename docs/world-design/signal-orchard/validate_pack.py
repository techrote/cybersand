#!/usr/bin/env python3
"""Source-pinned world-design staging validation, not a game simulation."""
import argparse, hashlib, json
from pathlib import Path
here=Path(__file__).resolve().parent
root=here.parents[2]
p=json.loads((here/"pack.json").read_text())
args=argparse.ArgumentParser()
args.add_argument("--source-check",action="store_true")
opt=args.parse_args()
assert p["schema_id"]=="cybersand.world-feature-pack.proposal" and p["schema_version"]==1
assert len(p["features"])==len(p["scene"]["placements"])==8 and len(p["repeatable_patterns"])==3
mats={m["id"]:m for m in p["palette"]}
assert len(mats)==len(p["palette"])
if opt.source_check:
    s=p["source"]
    for file,expected in [(s["native_material_enum"],s["native_enum_blob_sha"]),(s["shadow_catalogue"],s["shadow_catalogue_blob_sha"]),(s["interaction_rules"],s["interaction_rules_blob_sha"])]:
        data=(root/file).read_bytes()
        sha=hashlib.sha1(b"blob "+str(len(data)).encode()+b"\0"+data).hexdigest()
        assert sha==expected,(file,sha)
    actual={m["id"]:m for m in json.loads((root/s["shadow_catalogue"]).read_text())["native"]["materials"]}
    for id,m in mats.items():
        assert actual[id]["valid"]
        for field in ("name","rgba","state","kernel","movable","lateral_flow","initial_state_a","initial_state_b"):
            assert m[field]==actual[id][field],(id,field)
def rect(r,w,h):
    assert len(r)==5 and all(type(v)==int for v in r)
    x,y,rw,rh,id=r
    assert x>=0 and y>=0 and rw>0 and rh>0 and x+rw<=w and y+rh<=h and id in mats
fs={f["id"]:f for f in p["features"]}
assert len(fs)==8
count=0
for f in fs.values():
    assert len(f["rectangles"])>=20 and len(f["variants"])==2
    assert f["anchor"]["point"][1]==f["size"][1] and len(f["neighbour_rules"])>=2
    for r in f["rectangles"]:
        rect(r,*f["size"])
        m=mats[r[4]]
        if f["kind"]=="inert-static": assert not m["movable"] and m["kernel"]==0
        count+=1
    for v in f["variants"]:
        for a,b in v["swap"].items():
            assert b in mats and any(r[4]==int(a) for r in f["rectangles"])
end=-20
for z in p["scene"]["placements"]:
    f=fs[z["feature"]]
    v=next(v for v in f["variants"] if v["id"]==z["variant"])
    assert z["y"]+f["size"][1]==248 and z["x"]>=end+18
    assert z["x"]+f["size"][0]<=1220
    end=z["x"]+f["size"][0]
    for r in f["rectangles"]:
        m=mats[v["swap"].get(str(r[4]),r[4])]
        assert not m["movable"] and m["kernel"]==0
for r in p["scene"]["terrain_rectangles"]:
    rect(r,*p["scene"]["size"])
    assert not mats[r[4]]["movable"] and mats[r[4]]["kernel"]==0
assert count>=200
print(json.dumps({"status":"PASS","modules":len(fs),"rectangles":count,"materials":len(mats),"source_check":opt.source_check}))
