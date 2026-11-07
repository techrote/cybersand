#!/usr/bin/env python3
"""Generate immutable source-bound FULL-SIZE workbench-derived native-input tape.

The fixture is exported verbatim by Godot's Setup.rectangles(stress_canvas).
The eight actor origins are parsed from the *same* authored workbench_setup.gd.
This is a deterministic scripted mask/edit/jet input trace, NOT a claim that
it captures/locks the real Rapier body's asynchronous physics.
Both standalone native build arms receive the byte-identical tape.
"""
from __future__ import annotations
import argparse, hashlib, json, pathlib, re

STEPS=264
# Same stress-canvas hard edit anchors and alternating wall/erase schedule as #515.
ANCHORS=((64,90),(256,90),(448,90),(640,90),(832,90),(1024,90),
         (1216,90),(1408,90),(1600,90),(1792,90),(1984,90),
         (192,570),(576,570),(960,570),(1344,570),(1728,570))
SPAWN='var spots := '

def main():
    a=argparse.ArgumentParser()
    a.add_argument("--workbench-setup",required=True)
    a.add_argument("--fixture",required=True)
    a.add_argument("--out",required=True)
    args=a.parse_args()
    src=pathlib.Path(args.workbench_setup).read_text()
    match=re.search(r"var spots := (\[\[[0-9,\[\] ]+\]\])",src)
    if not match: raise ValueError("Authored eight actor stress positions missing")
    origins=json.loads(match.group(1))
    if len(origins)!=8 or any(len(pair)!=2 for pair in origins):
        raise ValueError("Wrong Godot physical actor roster")
    fixture=pathlib.Path(args.fixture).read_bytes()
    line=fixture.decode("utf-8").splitlines()[0]
    if line!="2048,1024":raise ValueError("Full authored 2048x1024 material fixture required")
    rows=[]
    for t in range(1,STEPS+1):
        # Actor movement is deterministic, bounded, and defined solely by t
        # and the Godot-authored eight original spawn coordinates. No wall time.
        bodies=[]
        for i,(x0,y0) in enumerate(origins):
            x=int(x0) + ((t*(i+3)+i*13) % 37) - 18
            y=int(y0) + ((t*(i+5)+i*7) % 19) - 9
            if not (8<x<2040 and 16<y<1008):
                raise ValueError("Body outside finite native canvas")
            bodies.extend((x,y))
        edit=[-1,-1,-1]
        if t>24 and (t-25)%2==0:
            edit_i=(t-25)//2
            x,y=ANCHORS[edit_i%len(ANCHORS)]
            material=58 if (edit_i//len(ANCHORS))%2==0 else 0
            edit=[x,y,material]
        # Workbench jet origin is extent x=1024 and y=floor(1024*.55)=563.
        # Unlike async actor forces, a deterministic injected parcel sequence
        # exercises the same native ballistic quantity source/sink contract.
        inject=(t>24 and t%7==0)
        rows.append(",".join(map(str,(t,*edit,1 if inject else 0,1024,563,*bodies))))
    dst=pathlib.Path(args.out)
    dst.parent.mkdir(parents=True,exist_ok=True)
    text="pf504-native-input-v1,2048,1024,8,264\n"+"\n".join(rows)+"\n"
    dst.write_text(text,encoding="utf-8",newline="\n")
    manifest={
        "schema":"pf504-native-workbench-derived-input-tape-v1",
        "ticks":STEPS,"actors":8,"extent":[2048,1024],
        "source_of_actor_origins":"godot/scripts/workbench_setup.gd::stress_canvas",
        "material_fixture_sha256":hashlib.sha256(fixture).hexdigest(),
        "source_workbench_sha256":hashlib.sha256(pathlib.Path(args.workbench_setup).read_bytes()).hexdigest(),
        "tape_sha256":hashlib.sha256(dst.read_bytes()).hexdigest(),
        "hard_edit_period":2,"warmup":24,"input_type":"scripted deterministic native mask/edit/jet playback; not Rapier-captured live tape",
        "body_origins":origins,
        "edits":sum(int(row.split(",")[1])>=0 for row in rows),
        "injections":sum(int(row.split(",")[4]) for row in rows),
    }
    (dst.parent/"replay-input-manifest.json").write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    if manifest["edits"]!=120 or manifest["injections"]==0:
        raise ValueError("Incomplete native replay input")
    print("PF504_EXACT_INPUT_TAPE_GENERATED "+json.dumps(manifest,sort_keys=True))

if __name__=="__main__": main()
