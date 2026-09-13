"""Reduce recorded fixtures into reviewable tables and scientific plots.

Requires matplotlib 3.10.6; pip freeze is retained with each evidence checkpoint.
Raw logs are read only. Output is a small curated data/plot artifact directory.
"""
from __future__ import annotations
import argparse
import base64
import csv
import hashlib
import json
from pathlib import Path
import statistics

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import Polygon

EVENTS={1:"empty_moves",2:"density_swaps",3:"conversions",4:"water_transfer_mass",5:"rejected_moves",6:"body_displacements",7:"body_contacts"}
NAMES={0:"Empty",1:"Wall",2:"Sand",3:"Water",8:"Lava",13:"Stone",14:"Dust",16:"Oil",19:"Seed",20:"Paste",22:"Steam",23:"Salt",24:"Brine",25:"Sodium",26:"Gunpowder",27:"Coal",29:"Rust",31:"Concrete",33:"Mercury"}

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def write_csv(path, rows):
    if not rows:return
    keys=list(dict.fromkeys(k for row in rows for k in row))
    with path.open("w",newline="",encoding="utf-8") as f:
        w=csv.DictWriter(f,keys);w.writeheader();w.writerows(rows)

def load_native(directory):
    records=[]
    for spec in json.loads((directory/"cases.json").read_text()):
        path=directory/(spec["id"]+".jsonl")
        if not path.exists():continue
        data=[json.loads(line) for line in path.read_text().splitlines()]
        if data[-1].get("type")!="result":continue
        records.append((spec,data,path))
    return records

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("raw",type=Path);p.add_argument("output",type=Path)
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
    native=[];godot=[];sources=[];pairs=[];counts=[];traces=[]
    for group in ["native-expanded","native-controls","native-finalists"]:
        directory=a.raw/group
        if not (directory/"cases.json").exists():continue
        sources.append({"group":group,"manifest_sha256":digest(directory/"manifest.json"),"manifest":json.loads((directory/"manifest.json").read_text())})
        for spec,data,path in load_native(directory):
            result=data[-1];initial=data[0];final=data[-2]
            row={"group":group,"id":spec["id"],**spec,"hash":final["hash"],"data_sha256":digest(path),
                 "breakthrough_tick":result["breakthrough_tick"],"front":final["top_front"],"interface_width":final["interface_width"],
                 "water_delta":final["water_mass"]-initial["water_mass"],"tick_p50_us":result["tick_us_p50"],"tick_p95_us":result["tick_us_p95"],"tick_max_us":result["tick_us_max"],
                 "overflow":result.get("overflow","disabled"),"max_cores":result["max_cores"],"max_chunks":result["max_chunks"],"allocations":result["chunk_allocations"]}
            row.update({v:0 for v in EVENTS.values()})
            for key,count in result.get("histogram",[]):
                row[EVENTS[key>>24]]+=count
                if key>>24 in (1,2,3,4):
                    source=(key>>16)&255;target=(key>>8)&255;direction=key&255
                    pairs.append({"group":group,"id":spec["id"],"event":EVENTS[key>>24],"source":NAMES.get(source,str(source)),"target":NAMES.get(target,str(target)),"dx":direction%3-1,"dy":direction//3-1,"count":count})
            row["counts_conserved"]=initial["counts"][1:]==final["counts"][1:]
            for m in range(1,81):
                if initial["counts"][m] or final["counts"][m]:
                    counts.append({"group":group,"id":spec["id"],"material":NAMES.get(m,str(m)),"initial_count":initial["counts"][m],"final_count":final["counts"][m],"initial_sum_y":initial["sum_y"][m],"final_sum_y":final["sum_y"][m]})
            native.append(row)
    for group in ["godot-controls-final","godot-expanded","godot-creep","water-accounting"]:
        directory=a.raw/group
        if not (directory/"cases.json").exists():continue
        sources.append({"group":group,"manifest_sha256":digest(directory/"manifest.json"),"manifest":json.loads((directory/"manifest.json").read_text())})
        for batch in sorted(directory.glob("batch-*.manifest.json")):
            sources.append({"group":group,"batch":batch.name,"manifest_sha256":digest(batch),"manifest":json.loads(batch.read_text())})
        for spec in json.loads((directory/"cases.json").read_text()):
            path=directory/(spec["id"]+".json")
            if not path.exists():continue
            d=json.loads(path.read_text());initial=d["initial"];final=d["final"]
            row={"group":group,"id":spec["id"],**spec,"hash":final["hash"],"data_sha256":digest(path),
                 **{k:d[k] for k in ["completed_ticks","peak_depth","final_depth","late_creep","floor_contact_tick","grounded_ticks","max_overlap","intermediate_caps","final_caps","displaced","unresolved","max_sample_age","stale","duplicates"]},
                 "water_delta":final["water_mass"]-initial["water_mass"],"global_water_delta":final.get("global_water_mass",-1)-initial.get("global_water_mass",-1) if "global_water_mass" in final else None,
                 "water_below_floor":final.get("water_below_floor"),"counts_conserved":final["counts"][1:]==initial["counts"][1:],"overflow":final.get("overflow","disabled"),
                 "tick_p50_us":d["tick_us"][0],"tick_p95_us":d["tick_us"][1],"tick_max_us":d["tick_us"][2],
                 "coupling_p50_us":d["coupling_us"][0],"coupling_p95_us":d["coupling_us"][1],"coupling_max_us":d["coupling_us"][2]}
            for term in ["displacement","boundary","contact","applied"]:
                row[term+"_impulse_x"]=d[term+"_impulse"][0];row[term+"_impulse_y"]=d[term+"_impulse"][1]
                row["pre_floor_"+term+"_y"]=d.get("pre_floor",{}).get(term,[None,None])[1]
            godot.append(row)
            for m in range(1,81):
                if initial["counts"][m] or final["counts"][m]:
                    counts.append({"group":group,"id":spec["id"],"material":NAMES.get(m,str(m)),"initial_count":initial["counts"][m],"final_count":final["counts"][m]})
            if spec["seed"] == 0 or (group == "godot-creep" and spec.get("contact") == 0):
                for point in d["rows"]:
                    traces.append({"group":group,"id":spec["id"],**{k:point[k] for k in ["tick","x","y","vx","vy","rotation","depth","local_depth","local_surface","overlap","caps","unresolved","displaced"]}})
    write_csv(a.output/"cellular-results.csv",native)
    write_csv(a.output/"ordered-events.csv",pairs)
    write_csv(a.output/"coupled-results.csv",godot)
    write_csv(a.output/"material-counts.csv",counts)
    write_csv(a.output/"depth-traces.csv",traces)
    # One row per controlled setting, retaining the other defaults in cases.json.
    parameters=[]
    for group in ["godot-controls-final","godot-creep"]:
        for index in sorted({r["id"].split("-")[0] for r in godot if r["group"]==group and r["mode"]=="barrel"}):
            runs=[r for r in godot if r["group"]==group and r["id"].split("-")[0]==index]
            r=runs[0]
            variants={k:r[k] for k in ["material","layout","contact","boundary","displacement","cap","density_limit","mass","damping","friction","delay","drop","serial","workers","telemetry","duplicate","fallback"] if k in r}
            row={"group":group,"setting_id":index,"setting":json.dumps(variants,sort_keys=True),"seeds":len(runs),"ticks":r["ticks"],"floor_hits":sum(v["floor_contact_tick"]>=0 for v in runs)}
            for k in ["peak_depth","final_depth","late_creep","floor_contact_tick","intermediate_caps","tick_p95_us","coupling_p95_us"]:
                values=[v[k] for v in runs if v[k] is not None and (k!="floor_contact_tick" or v[k]>=0)]
                for label,fn in [("median",statistics.median),("min",min),("max",max)]:
                    row[k+"_"+label]=fn(values) if values else None
            parameters.append(row)
    write_csv(a.output/"parameter-results.csv",parameters)
    # Compact provenance keeps complete per-file inputs and manifests for every
    # series, but not the per-tick raw telemetry or generated runtime libraries.
    (a.output/"source-and-artifacts.json").write_text(json.dumps(sources,indent=2),encoding="utf-8")
    plt.rcParams.update({"font.size":10,"axes.spines.top":False,"axes.spines.right":False})
    directory=a.raw/"native-controls"
    if directory.exists():
        fig,axes=plt.subplots(1,2,figsize=(11,4),layout="constrained")
        wanted=["Sand-Dust-packed-32-baseline-w32","Mercury-Sand-packed-32-baseline-w32","Mercury-Sand-packed-32-exchange_off-w32","Mercury-Sand-packed-32-viscosity_248-w32"]
        for spec,data,_ in load_native(directory):
            if spec["name"] not in wanted or spec["seed"] or spec.get("serial") or spec.get("workers",1)!=1 or not spec.get("telemetry",True):continue
            samples=data[:-1]
            axes[0].step([d["tick"]/60 for d in samples],[d["top_front"] for d in samples],where="post",label=spec["name"].replace("-packed-32-"," / ").replace("-w32",""))
        axes[0].axvline(32/60,color="#b54436",linestyle=":",label="Exact breakthrough: 32 ticks")
        axes[0].set(xlabel="Simulated seconds",ylabel="Upper-material front below interface (cells)",xlim=(0,3),title="Packed bed: 1 Hz front samples; exact arrival")
        axes[0].legend(fontsize=7)
        viscosity=[96,160,224,248]
        values=[statistics.median([r["breakthrough_tick"]/60 for r in native if r["group"]=="native-controls" and r["name"]==f"Mercury-Sand-packed-32-viscosity_{v}-w32"]) for v in viscosity]
        axes[1].plot(viscosity,values,"o-");axes[1].set(xlabel="Mercury viscosity index",ylabel="Breakthrough time (seconds)",title="5 seeds; 32-cell packed Sand",ylim=(0,1))
        fig.savefig(a.output/"cellular-penetration.png",dpi=180);plt.close(fig)
    directory=a.raw/"godot-controls-final"
    if directory.exists():
        fig,axes=plt.subplots(1,2,figsize=(11,4.5),layout="constrained")
        for material in [2,14,23,3,16,33]:
            candidates=[r for r in godot if r["group"]=="godot-controls-final" and r["mode"]=="barrel" and r["material"]==material and r["seed"]==0 and r["layout"]=="flat"]
            if not candidates:continue
            d=json.loads((directory/(candidates[0]["id"]+".json")).read_text());rows=d["rows"]
            until=[v for v in rows if d["floor_contact_tick"]<0 or v["tick"]<=d["floor_contact_tick"]]
            axes[0].plot([v["tick"]/60 for v in until],[v["depth"] for v in until],label=NAMES[material])
            if material==2:
                axes[1].plot([v["tick"]/60 for v in rows],[v["depth"] for v in rows],label="Initial surface")
                axes[1].plot([v["tick"]/60 for v in rows],[v["local_depth"] for v in rows],label="Deformed local surface",linestyle="--")
                if d["floor_contact_tick"]>0:axes[1].axvline(d["floor_contact_tick"]/60,color="#bb4430",linestyle=":",label="Hard floor reached")
        for ax in axes:
            ax.set(xlabel="Simulated seconds",ylabel="Barrel bottom depth (cells)")
            ax.axhline(8,color="#445566",linestyle=":",label="Provisional 0.5H + 1 cell")
            ax.legend(fontsize=8)
        axes[0].set_title("Ordinary one-height drops; cut at hard floor")
        axes[1].set_title("Sand: floor support censors late creep")
        fig.savefig(a.output/"barrel-depth.png",dpi=180);plt.close(fig)
        selected=next((r for r in godot if r["group"]=="godot-controls-final" and r["name"]=="barrel-Sand-flat" and r["seed"]==0),None)
        if selected:
            d=json.loads((directory/(selected["id"]+".json")).read_text());frames=d.get("frames",[])
            if frames:
                palette=np.zeros((81,3));palette[:]=[0.08,0.10,0.15];palette[1]=[0.50,0.53,0.59];palette[2]=[0.87,0.68,0.30];palette[14]=[0.75,0.69,0.87]
                fig,axes=plt.subplots(1,len(frames),figsize=(12,4),layout="constrained")
                for ax,frame in zip(axes,frames):
                    w,h=frame["width"],frame["height"];ox,oy=frame["origin"]
                    cells=np.frombuffer(base64.b64decode(frame["cells"]),dtype=np.uint8).reshape(h,w)
                    ax.imshow(palette[cells],extent=(ox,ox+w,oy+h,oy),interpolation="nearest")
                    x,y,angle,bw,bh=frame["body"];c,s=np.cos(angle),np.sin(angle)
                    polygon=np.array([[-bw/2,-bh/2],[bw/2,-bh/2],[bw/2,bh/2],[-bw/2,bh/2]])@np.array([[c,s],[-s,c]])+np.array([x,y])
                    ax.add_patch(Polygon(polygon,fill=False,edgecolor="#f44747",linewidth=2))
                    # Exact projected overlap from the recorded authoritative
                    # cells. Arrows show world-axis inward face-normal directions,
                    # never inferred force magnitudes.
                    yy,xx=np.nonzero(cells);dx=xx+ox+.5-x;dy=yy+oy+.5-y
                    overlap=(np.abs(c*dx+s*dy)<=bw/2)&(np.abs(-s*dx+c*dy)<=bh/2)
                    ax.scatter(xx[overlap]+ox+.5,yy[overlap]+oy+.5,s=2,c="#fff8a2")
                    for dx,dy in [(0,-1),(1,0),(0,1),(-1,0)]:
                        edge=bw/2 if dx else bh/2
                        ax.annotate("",xy=(x+dx*(edge-3.5),y+dy*(edge-3.5)),xytext=(x+dx*(edge-.5),y+dy*(edge-.5)),arrowprops={"color":"#56d7e8","width":1,"headwidth":4})
                    ax.axhline(frame["surface"],color="#e8edf3",linestyle="--",linewidth=1)
                    ax.set(xlim=(x-26,x+26),ylim=(min(oy+h,y+32),max(oy,y-32)),title=f"{frame['tick']/60:.2f}s · depth {max(0,y+bh/2-frame['surface']):.1f}")
                    ax.set_xlabel("World x (cells)")
                axes[0].set_ylabel("World y (cells; downward positive)")
                fig.suptitle("Stored Sand / hard terrain · red body mask · yellow overlap · cyan face-normal directions",fontsize=10)
                fig.savefig(a.output/"barrel-overlays.png",dpi=200);plt.close(fig)
    selected=[r for r in godot if r["group"]=="godot-creep" and r.get("contact")==0]
    if selected:
        fig,axes=plt.subplots(1,2,figsize=(11,4.5),layout="constrained")
        for r in selected:
            if r["layout"]!="flat" or r.get("delay") or r.get("drop"):continue
            d=json.loads((a.raw/r["group"]/(r["id"]+".json")).read_text())
            axes[0].plot([v["tick"]/60 for v in d["rows"]],[v["depth"] for v in d["rows"]],alpha=.5,linewidth=.8)
        for ax in axes:
            ax.axhline(8,color="#445566",linestyle=":")
            ax.set(xlabel="Simulated seconds",ylabel="Depth below original surface (cells)")
        axes[0].set_title("Contact gain 0: ordinary impact, 20 seeds")
        for r in selected:
            if r["seed"]!=0:continue
            label="ordinary"
            if r["layout"]=="excavate":label="excavate at 10s"
            if r.get("drop"):label="four-height drop"
            if r.get("delay"):label="sample delay 4"
            d=json.loads((a.raw/r["group"]/(r["id"]+".json")).read_text())
            rows=[v for v in d["rows"] if d["floor_contact_tick"]<0 or v["tick"]<=d["floor_contact_tick"]]
            axes[1].plot([v["tick"]/60 for v in rows],[v["depth"] for v in rows],label=label)
        axes[1].set_title("Candidate interactions; traces stop at floor")
        axes[1].legend(fontsize=8)
        fig.savefig(a.output/"barrel-creep.png",dpi=180);plt.close(fig)
    summary={"native_runs":len(native),"godot_runs":len(godot),"native_completed_ticks":sum(r["ticks"] for r in native),"godot_completed_ticks":sum(r["completed_ticks"] for r in godot),
             "native_overflows":sum(r["overflow"] for r in native if isinstance(r["overflow"],int)),"godot_overflows":sum(max(0,r["overflow"]) for r in godot if isinstance(r["overflow"],int))}
    (a.output/"totals.json").write_text(json.dumps(summary,indent=2),encoding="utf-8")
    print(json.dumps(summary))

if __name__=="__main__":main()
