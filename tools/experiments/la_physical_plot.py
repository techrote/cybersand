#!/usr/bin/env python3
"""Plot retained real-body records; requires matplotlib3.10.7, no image editing."""
import argparse
import hashlib
import json
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

def main():
    parser=argparse.ArgumentParser(__doc__)
    parser.add_argument("input",type=Path,help="One actual-host folder")
    parser.add_argument("output",type=Path)
    args=parser.parse_args();inputs={};sources=set()
    def read(case,arm):
        path=args.input/(case+"-w1-r0")/(case+"-"+arm+"-w1-r0.json")
        raw=path.read_bytes();inputs[str(path)]=hashlib.sha256(raw).hexdigest()
        d=json.loads(raw);assert not d["failures"];sources.add(d["source"]);return d
    arms=[("LA-SELECTIVE","Baseline","#245a81","-"),
          ("LA-SELECTIVE-LIVE-PASSIVE","Strict v1","#c76b18","-"),
          ("LA-SELECTIVE-LIVE-PASSIVE-GATED","Changed-state v2","#458454","--"),
          ("LA-SELECTIVE-SEPARATING-GUARD","Separating v3","#8a4694",":")]
    plt.rcParams.update({"font.size":10,"axes.spines.top":False,"axes.spines.right":False})
    fig,grid=plt.subplots(2,2,figsize=(11,7.5));axes=grid.flatten()
    for panel,case,title in [(0,"barrel-rest","Synchronous barrel support"),(1,"actual-step-delayed-support","Support after a real Rapier delay")]:
        for arm,label,color,style in arms:
            d=read(case,arm);steps=d["steps"];origin=d["authored"][0]["state"]["pose"][5]
            axes[panel].plot([(s["step"]+1)/60 for s in steps],
                [s["after_step"][0]["pose"][5]-origin for s in steps],label=label,color=color,ls=style,lw=1.8)
        axes[panel].set(title=title,xlabel="Time (s)",ylabel="Downward displacement (cells)")
        axes[panel].axvspan(4,6,alpha=.06,color="black")
        axes[panel].grid(alpha=.18)
    values=[]
    for arm,label,color,style in arms:
        d=read("live-velocity-reversal",arm)
        values.append(d["steps"][0]["after_application"][0]["velocity"][1])
    axes[2].bar(["Baseline","Strict v1","Gated v2","v3"],values,color=[a[2] for a in arms],width=.65)
    axes[2].axhline(-3,color="black",lw=1,ls="--",label="Externally reversed live velocity")
    axes[2].set(title="Stale response after velocity reversal",ylabel="Immediate applied vY (cells/s)")
    axes[2].grid(axis="y",alpha=.18)
    for case,label,color in [("barrel-rest","Barrel","#245a81"),("needle-rest","Needle","#c76b18"),("scooper-rest","Scooper","#458454")]:
        d=read(case,"LA-SELECTIVE");tail=d["steps"][-120:]
        axes[3].plot([(s["step"]+1)/60 for s in tail],[sum(v*v for v in s["after_step"][0]["velocity"])**.5 for s in tail],label=label,color=color,lw=1)
    axes[3].set(title="Residual speed in the terminal 120 steps",xlabel="Time (s)",ylabel="Baseline speed (cells/s)")
    axes[3].grid(alpha=.18);axes[3].legend(fontsize=8)
    axes[0].legend(fontsize=9,loc="upper left");axes[2].legend(fontsize=8,loc="lower right")
    fig.suptitle("Measured support, residual motion, and the stale-response guard",fontsize=14)
    assert len(sources)==1,"Mixed source figure"
    source=next(iter(sources))
    fig.text(.5,.015,f"Actual Windows / worker 1 / source {source[:8]} / native budget 20. v1/v2 rejected for support; v3 remains opt-in.\nShading: terminal 120 steps. Bounded pose and final speed do not prove sustained equilibrium.\nThese plots do not establish original SOL clearance or universal passivity.",ha="center",fontsize=9)
    fig.tight_layout(rect=(0,.1,1,.95));args.output.parent.mkdir(parents=True,exist_ok=True)
    fig.savefig(args.output,dpi=160)
    args.output.with_suffix(".inputs.json").write_text(json.dumps(dict(source=source,matplotlib=matplotlib.__version__,inputs=inputs,output_sha256=hashlib.sha256(args.output.read_bytes()).hexdigest()),indent=2)+"\n",encoding="utf-8")

if __name__=="__main__":main()
