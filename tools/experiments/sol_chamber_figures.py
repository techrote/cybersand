#!/usr/bin/env python3
"""Static source-qualified chamber figures; matplotlib3.10.7 analysis only."""
import argparse
import json
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon
import numpy as np

def load(path):return json.loads(path.read_text(encoding="utf-8"))
def expand(runs):return [value for value,count in runs for _ in range(count)]

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("directory",type=Path);parser.add_argument("output",type=Path);args=parser.parse_args()
    summary=load(args.directory/"reduction/reduced.json");assert summary["full_matrix_coverage"] and len(summary["episodes"])==192
    assert not args.output.exists();args.output.mkdir(parents=True)
    plt.rcParams.update({"font.size":10,"axes.spines.top":False,"axes.spines.right":False,"savefig.dpi":160})
    modes=["LA-SELECTIVE","LA","LA-EVENT-OFF","RFT"]
    colors=["#1464a5","#c2701f","#3b8b68","#766c8a"]
    reference={}
    for row in summary["episodes"]:
        if row["platform"]=="windows" and row["requested_workers"]==1 and row["repeat"]==0:
            reference[(row["case"]["id"],row["mode"])]=load(args.directory/"reduction"/("windows-"+row["id"]+".metrics.json"))
    fig,axes=plt.subplots(2,2,figsize=(11,7),sharex=True)
    for column,case in enumerate(["closed-driven","open-driven"]):
        for mode,color in zip(modes,colors):
            steps=reference[(case,mode)]["steps"]
            after=[next(b for b in s["geometry"] if b["boundary"]=="after_rapier_step") for s in steps]
            axes[0,column].plot(range(180),[b["sand_area"] for b in after],label=mode,color=color)
            axes[1,column].plot(range(180),[b["sand_max_depth"] for b in after],color=color)
        axes[0,column].set_title(case.replace("-"," ").title())
        for axis in axes[:,column]:
            axis.axvspan(30,150,color="#74808a",alpha=.12);axis.grid(alpha=.18);axis.set_xlim(0,179)
        axes[1,column].set_xlabel("Registered step (60 Hz)")
    axes[0,0].set_ylabel("Stored Sand intersection (cell²)")
    axes[1,0].set_ylabel("Maximum convex-proxy depth (cells)")
    axes[0,1].legend(loc="upper left",fontsize=8)
    fig.suptitle("Driven exact-520 geometry surrogate: remaining penetration",fontsize=15)
    fig.text(.5,.015,"Fixed Windows / requested worker1 / repeat0. Grey: registered drive. Full192-run matrix reported separately. No original SOL clearance claim.",ha="center",fontsize=8)
    fig.tight_layout(rect=[0,.04,1,.95]);fig.savefig(args.output/"driven-comparison.png");plt.close(fig)

    row=next(r for r in summary["episodes"] if r["platform"]=="windows" and r["case"]["id"]=="closed-driven" and r["mode"]=="LA-SELECTIVE" and r["requested_workers"]==1 and r["repeat"]==0)
    raw=load(Path(__file__).resolve().parents[2]/row["report_path"]);metrics=reference[("closed-driven","LA-SELECTIVE")]
    captures=[raw["initial"],raw["steps"][60]["boundaries"][2],raw["steps"][179]["boundaries"][4]]
    measures=[metrics["initial"],metrics["steps"][60]["geometry"][2],metrics["steps"][179]["geometry"][4]]
    fig,axes=plt.subplots(1,3,figsize=(12,5.8))
    for axis,capture,measure,title in zip(axes,captures,measures,["Initial: valid occupancy","Step60: after native tick","Step179: after Rapier"]):
        width,height=capture["size"];ox,oy=capture["origin"]
        cells=np.array(expand(capture["material_runs"])).reshape(height,width)
        mask=np.array(expand(capture["mask_runs"])).reshape(height,width)>0
        image=np.ones((height,width,3));image[cells==1]=[.22,.25,.29];image[cells==2]=[.86,.65,.28]
        image[mask & (cells==0)]=[.82,.91,.97];image[mask & (cells==2)]=[.88,.31,.26]
        axis.imshow(image,extent=[ox,ox+width,oy+height,oy],interpolation="nearest")
        for polygon in measure["recorded_transform_proxy_union"]:axis.add_patch(Polygon(polygon,fill=False,edgecolor="#105f9d",linewidth=1.15))
        axis.set_title(title,fontsize=11);axis.set_xlabel("x (cells)");axis.set_ylabel("y (cells)")
        axis.text(.02,-.24,"Area %.6g; depth %.6g\nSand under mask: %s; vacancy: %s"%(measure["sand_area"],measure["sand_max_depth"],measure["sand_cells_under_actual_mask"],measure["chamber_unmasked_empty_cells"]),transform=axis.transAxes,fontsize=8)
    fig.suptitle("Conserved Sand can overlap the rigid shape",fontsize=15)
    fig.text(.5,.015,"Tan: stored Sand. Pale blue: actual empty-cell mask. Red: stored Sand under mask. Outline: recorded-transform union, not internal Rapier vertices.",ha="center",fontsize=8)
    fig.subplots_adjust(left=.055,right=.985,top=.83,bottom=.29,wspace=.26);fig.savefig(args.output/"occupancy-counterexample.png");plt.close(fig)

    fig,axes=plt.subplots(1,2,figsize=(11,5),sharey=True)
    for axis,host in zip(axes,["windows","linux"]):
        segments=[]
        for mode in modes:
            rows=[r for r in summary["episodes"] if r["platform"]==host and r["mode"]==mode]
            def mean(keys):return sum(sum(r["cost_us"].get(k,0) for k in keys) for r in rows)/len(rows)/180/1000
            kernel=mean(["preparation_us","native_tick_us","application_us","rapier_us"])
            observer=mean(["observer_us"]);export=mean(["export_us"]);total=mean(["elapsed_us"])
            segments.append([kernel,observer,export,max(0,total-kernel-observer-export)])
        bottom=np.zeros(4)
        for index,label,color in [(0,"Native + preparation + application + Rapier","#236c9b"),(1,"Five-boundary observation","#d0a750"),(2,"CYPS export","#68977f"),(3,"Other measured step work","#a4a8ad")]:
            values=np.array([s[index] for s in segments]);axis.bar(range(4),values,bottom=bottom,label=label,color=color);bottom+=values
        axis.set_xticks(range(4),["SELECTIVE","LA","EVENT-OFF","RFT"]);axis.set_title(host.title());axis.grid(axis="y",alpha=.18)
    axes[0].set_ylabel("Measured elapsed milliseconds per step")
    handles,labels=axes[1].get_legend_handles_labels();fig.legend(handles,labels,loc="lower center",ncol=2,fontsize=8)
    fig.suptitle("Observation dominates this chamber apparatus",fontsize=15)
    fig.text(.5,.105,"Mean of24 episodes per mode/host, requested workers1/4 combined; one actual participant. Startup/final serialization/setup costs are separate.",ha="center",fontsize=8)
    fig.tight_layout(rect=[0,.15,1,.93]);fig.savefig(args.output/"cost-ledger.png");plt.close(fig)
    print("3 scientific figures; matplotlib",matplotlib.__version__,"fixed reference windows/w1/r0; no clearance or60Hz qualification")

if __name__=="__main__":main()
