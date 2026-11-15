"""Source-frozen typed A1/A2/A3 numeric guidance; soft preference, never permission."""
from __future__ import annotations
import hashlib
from pathlib import Path
import struct

from experiments.driv3r.m3_native.qualify import guidance, _blob, digest
from experiments.driv3r.d_common.v1.verify import CHANNEL_PRESETS

FRAME=[8,20,32,32]
GOAL=[30,38]
ARMS=("A1","A2","A3")

def sample(frame,values,point,vector=False):
    x,y,w,h=frame
    if not(x<=point[0]<x+w and y<=point[1]<y+h): return [0,0] if vector else 0
    i=(point[1]-y)*w+point[0]-x
    return values[2*i:2*i+2] if vector else values[i]

def make(root:Path,episode:str,arm:str):
    if arm not in ARMS: raise ValueError("Unknown M4 guidance arm")
    result=guidance(root,episode)
    x0,y0,w,h=FRAME
    positive=[]
    for y in range(y0,y0+h):
        for x in range(x0,x0+w):
            # Declared original scalar; plateau around planned horizontal coverage.
            distance=abs(y-27)+max(0,abs(x-22)-8)
            positive.append(max(0,65535-3400*distance))
    raw=struct.pack("<"+"H"*len(positive),*positive)
    (root/"guide/positive.u16le").write_bytes(raw)
    result.update({"frame":FRAME.copy(),"label":"M4 shared soft positive guidance",
                   "values":_blob(root,"guide/positive.u16le","u16le")})
    result["speckle"]["radius_cells"]=32
    values={"core":positive}
    recipes={
      "soft_attraction/v1":("attract","u16le",
        [max(0,65535-2450*(abs(x-GOAL[0])+abs(y-GOAL[1])))
            for y in range(y0,y0+h) for x in range(x0,x0+w)]),
      "soft_avoidance/v1":("avoid","u16le",
        [min(65535,6200*max(0,7-abs(x-8)))
            for y in range(y0,y0+h) for x in range(x0,x0+w)]),
      "signed_distance/v1":("distance","i16le",
        [y-27 for y in range(y0,y0+h) for x in range(x0,x0+w)]),
      "flow_vector_xy/v1":("flow","vec2_i16le",
        [v for y in range(y0,y0+h) for x in range(x0,x0+w) for v in (32767,0)]),
    }
    chosen=[] if arm=="A1" else (
      ["soft_attraction/v1","soft_avoidance/v1","flow_vector_xy/v1"] if arm=="A2"
      else ["signed_distance/v1","flow_vector_xy/v1"])
    for semantic in chosen:
        cid,enc,numbers=recipes[semantic]
        fmt="H" if enc=="u16le" else "h"
        bytes_=struct.pack("<"+fmt*len(numbers),*numbers)
        name=f"guide/{cid}.{enc}"
        (root/name).write_bytes(bytes_)
        cls,encoding,units,num,den,zero,pos,neg,needs_ref=CHANNEL_PRESETS[semantic]
        field={
            "channel_id":cid,"signal_class":cls,"semantic_id":semantic,
            "encoding":encoding,"units":units,
            "scale":{"numerator":num,"denominator":den},
            "zero_meaning":zero,"positive_meaning":pos,
            "negative_meaning":neg,
            "reference_id":"original_frozen_boundary_y27" if needs_ref else None,
            "canvas_size":[512,512],"frame":FRAME.copy(),
            "values":_blob(root,name,encoding),
            "producer":{"kind":"derived_geometry" if cls=="geometry_metric" else "procedural",
                        "producer_id":"m4_guidance_v1","revision":"1",
                        "source_sha256":digest({"boundary":27,"goal":GOAL}),
                        "parameters_sha256":digest({"arm":arm,"semantic":semantic,"frame":FRAME}),
                        "seed":570},
            "native_material_authority":False,
        }
        result["optional_channels"].append(field)
        values[cid]=numbers
    return result,values

def values_for(guide,raw,point):
    answer={"positive_scalar_u16":sample(guide["frame"],raw["core"],point)}
    for field in guide["optional_channels"]:
        cid=field["channel_id"]
        answer[cid]={"semantic":field["semantic_id"],
                     "encoding":field["encoding"],"units":field["units"],
                     "scale":field["scale"],
                     "sample":sample(field["frame"],raw[cid],point,
                                     field["encoding"]=="vec2_i16le")}
    return answer
