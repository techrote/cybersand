"""Independent DRIV3R body preflight. NO native, inference or live model claims."""
from dataclasses import dataclass
from pathlib import Path
import hashlib
import json
import random
import struct
import zlib

W=H=96
INK=58
HEADINGS={"N":(0,-1),"E":(1,0),"S":(0,1),"W":(-1,0)}
BASELINE=(36,36,64,8)  # model decisions, new ink, M3 logical moves, recovery


class Refusal(ValueError):
    pass


def native_envelope(decisions, ink, logical_moves, recoveries, *, extended=False):
    observed=(decisions,ink,logical_moves,recoveries)
    if any(type(n) is not int or n<0 for n in observed):
        raise Refusal("Invalid nonnegative integer native envelope")
    if any(value>limit for value,limit in zip(observed,BASELINE)) or extended:
        raise Refusal("Long-horizon native host NOT qualified: #611 36/36/64/8")
    return observed


@dataclass(frozen=True)
class HostView:
    material: tuple
    protected: tuple=()
    width: int=W
    height: int=H

    def __post_init__(self):
        if type(self.material) is not tuple or len(self.material)!=self.width*self.height:
            raise Refusal("Host material readback dimensions invalid")
        if type(self.width) is not int or type(self.height) is not int or not (0<self.width<=96 and 0<self.height<=96):
            raise Refusal("Invalid native focus size")
        if any(type(x) is not int or x<0 for x in self.material):
            raise Refusal("Host snapshot contains invalid material")
        for rect in self.protected:
            if len(rect)!=4 or any(type(x) is not int for x in rect) or rect[2]<=0 or rect[3]<=0:
                raise Refusal("Malformed protected region")

    def empty_and_unprotected(self,x,y):
        return (0<=x<self.width and 0<=y<self.height and
                self.material[y*self.width+x]==0 and
                not any(a<=x<a+w and b<=y<b+h for a,b,w,h in self.protected))


def swept_menu(view, cursor, *, span=4):
    """Model selects only offered action ID; actual native host rechecks all cells."""
    if type(span) is not int or not 1<=span<=4:
        raise Refusal("Illegal swept stroke length")
    if len(cursor)!=2 or any(type(v) is not int for v in cursor):
        raise Refusal("Invalid cursor")
    if not (0<=cursor[0]<view.width and 0<=cursor[1]<view.height):
        raise Refusal("Cursor outside focus")
    menu={"STOP":()}
    for heading,(dx,dy) in HEADINGS.items():
        path=[]
        for i in range(1,span+1):
            cell=(cursor[0]+dx*i,cursor[1]+dy*i)
            if not view.empty_and_unprotected(*cell):
                break
            path.append(cell)
            menu[f"INK_{heading}_{i}"]=tuple(path)
    return menu


def new_ink_from_readbacks(initial, current):
    """Correct cursor-history count using host-supplied native material arrays."""
    if (initial.width,initial.height,initial.protected)!=(current.width,current.height,current.protected):
        raise Refusal("Changed World/protection identity")
    n=0
    for k,(before,after) in enumerate(zip(initial.material,current.material)):
        if before==after:
            continue
        x,y=k%initial.width,k//initial.width
        if before!=0 or after!=INK or not initial.empty_and_unprotected(x,y):
            raise Refusal("Forbidden or non-additive material mutation")
        n+=1
    return n


def corrected_prompt(original, initial, current):
    """Pure opt-in replacement; frozen #611 prompt is NEVER modified."""
    if not isinstance(original,dict) or "already_inked_cells_this_run" not in original:
        raise Refusal("Missing original #611 prompt counter")
    clean=dict(original)
    clean["already_inked_cells_this_run"]=new_ink_from_readbacks(initial,current)
    clean["ink_counter_source"]="source-fenced-native-readback-required"
    return clean


@dataclass(frozen=True)
class Lease:
    id: str
    wrangler: str
    runner: str
    world: str
    model_label: str
    seed: int

    def __post_init__(self):
        if any(not isinstance(v,str) or not v.strip() for v in
               (self.id,self.wrangler,self.runner,self.world,self.model_label)):
            raise Refusal("Incomplete episode identity")
        if type(self.seed) is not int or self.seed<0:
            raise Refusal("Bad seed")


class FourSlotPreflight:
    """Model-free contract only; cannot report four ACTIVE resident processes."""
    def __init__(self):
        self.leases={}
        self.traces={}

    def register(self, lease):
        if len(self.leases)>=4 or lease.id in self.leases or any(
           existing.world==lease.world for existing in self.leases.values()):
            raise Refusal("Capacity, lease or world collision")
        self.leases[lease.id]=lease

    def add_synthetic(self, ident, outcome):
        if ident not in self.leases or ident in self.traces:
            raise Refusal("Unknown or reused episode")
        if outcome.get("evidence_class")!="model-free-synthetic":
            raise Refusal("Synthetic model-free ledger cannot accept live/native claims")
        self.traces[ident]=json.loads(json.dumps(outcome))

    def summary(self):
        return {"registered":len(self.leases),"synthetic_completed":len(self.traces),
                "verified_active_model_processes":0,"native_receipts":0,
                "model_process_probe":"NOT_IMPLEMENTED"}


def _png(view):
    lines=[]
    for y in range(view.height):
        row=bytearray(b"\x00")
        for x in range(view.width):
            v=view.material[y*view.width+x]
            row+=bytes((244,189,80) if v==INK else
                       ((91,96,107) if v!=0 else (18,22,30)))
        lines.append(row)
    def chunk(kind,data):
        return (struct.pack(">I",len(data))+kind+data+
                struct.pack(">I",zlib.crc32(kind+data)&0xffffffff))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR",struct.pack(">IIBBBBB",
            view.width,view.height,8,2,0,0,0))+
            chunk(b"IDAT",zlib.compress(b"".join(lines),9))+chunk(b"IEND",b""))


def synthetic_world(lease, turns=24):
    """NO model loads or Godot. A four-seed independent visual demo only."""
    if type(turns) is not int or not 0<=turns<=36:
        raise Refusal("Synthetic test cannot exceed frozen 36-turn envelope")
    rng=random.Random(lease.seed)
    cells=[0]*(W*H)
    for x in range(30,45):
        cells[36*W+x]=61
    protected=((40,40,8,8),)
    cursor=(12,24)
    painted=0
    trace=[]
    for i in range(turns):
        menu=swept_menu(HostView(tuple(cells),protected),cursor,span=2)
        legal=[name for name,path in menu.items()
               if path and len(path)+painted<=36]
        if not legal:
            trace.append({"turn":i,"choice":"STOP","path":[]})
            break
        action=rng.choice(legal)
        path=menu[action]
        for x,y in path:
            cells[y*W+x]=INK
        painted+=len(path)
        cursor=path[-1]
        trace.append({"turn":i,"choice":action,"path":path,"cursor_after":cursor})
    result={"evidence_class":"model-free-synthetic","native_execution":False,
            "model_execution":False,"native_receipts":0,
            "lease_id":lease.id,"seed":lease.seed,"turns":len(trace),
            "synthetic_painted_cells":painted,"trace":trace}
    return HostView(tuple(cells),protected),result


def demo(folder):
    folder=Path(folder)
    folder.mkdir(parents=True,exist_ok=False)
    fleet=FourSlotPreflight()
    artifacts=[]
    for i,model in enumerate(("d1-2B","LFM2.5-350M",
                               "SmolLM2-135M","Sprocket-500M")):
        # These are labels ONLY. No actual model is ever loaded here.
        lease=Lease(f"synthetic-{i}","bodylab",f"proposed-runner-{i//2}",
                    f"isolated-world-{i}",model,570+i*71)
        fleet.register(lease)
        view,result=synthetic_world(lease)
        fleet.add_synthetic(lease.id,result)
        png=_png(view)
        name=f"worm-{i}.png"
        (folder/name).write_bytes(png)
        trace=f"worm-{i}.json"
        raw=(json.dumps(result,sort_keys=True,indent=2)+"\n").encode()
        (folder/trace).write_bytes(raw)
        artifacts.append({"id":lease.id,"model_label_only":model,
                          "png":name,"png_sha256":hashlib.sha256(png).hexdigest(),
                          "trace":trace,"trace_sha256":hashlib.sha256(raw).hexdigest(),
                          "synthetic_painted_cells":result["synthetic_painted_cells"]})
    manifest={"schema":"driv3r-body-lab-preflight/1",
              "classification":"model-free-synthetic-only",
              "paired-runners":"proposed, NOT measured",
              "native_qualification":"NOT_RUN",
              "roster":fleet.summary(),"artifacts":artifacts}
    (folder/"manifest.json").write_text(json.dumps(manifest,sort_keys=True,indent=2)+"\n")
    return manifest


if __name__=="__main__":
    import argparse
    parser=argparse.ArgumentParser()
    parser.add_argument("--out",required=True)
    args=parser.parse_args()
    print(json.dumps(demo(args.out),sort_keys=True,indent=2))
