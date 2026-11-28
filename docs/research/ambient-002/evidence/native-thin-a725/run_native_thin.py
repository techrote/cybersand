#!/usr/bin/env python3
"""External native observation probe with unchanged frozen application custody."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

SOURCE = "a7250e15495667b2fcf564cbed1eaa8dea217c45"

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2)+"\n", encoding="utf-8")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.root=args.root.resolve(); args.godot=args.godot.resolve()
    args.output=args.output.resolve(); args.source_sha=SOURCE
    sys.path.insert(0, str(args.root/"tools/ambient"))
    import run_episodes as runner
    before=runner.full_custody(args)
    args.output.mkdir(parents=True, exist_ok=False)
    external=Path(__file__).resolve().parent
    scripts={p.name:sha(p) for p in (Path(__file__).resolve(),external/"native_thin_probe.gd")}
    write(args.output/"custody-before.json", before)
    report=args.output/"report.json"; console=args.output/"console.log"
    cells=args.output/"publication.cells.bin"
    env=os.environ.copy()
    env.update(CYBERSAND_SOURCE_REVISION=SOURCE,CYBERSAND_THIN_REPORT=str(report),
               CYBERSAND_THIN_CELLS=str(cells),XDG_DATA_HOME=str(args.output/"userdata"))
    command=[str(args.godot),"--headless","--audio-driver","Dummy","--path",str(args.root/"godot"),
             "--script",str(external/"native_thin_probe.gd")]
    receipt={"source_revision":SOURCE,"external_scripts_sha256":scripts,"command":command,
             "started_utc":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),"timeout_seconds":180,
             "behavioral_episodes_added":0,"custody_before_sha256":sha(args.output/"custody-before.json")}
    begun=time.monotonic()
    try:
        with console.open("wb") as stream:
            completed=subprocess.run(command,cwd=args.root,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=180)
        receipt["returncode"]=completed.returncode
    except subprocess.TimeoutExpired:
        receipt.update(returncode=None,timed_out=True)
    receipt["elapsed_seconds"]=time.monotonic()-begun
    receipt["console_sha256"]=sha(console)
    after=runner.full_custody(args)
    write(args.output/"custody-after.json", after)
    receipt["custody_after_sha256"]=sha(args.output/"custody-after.json")
    receipt["application_custody_unchanged"]=before==after
    receipt["external_scripts_unchanged"]=scripts=={name:sha(external/name) for name in scripts}
    for p in (report,cells):
        if p.is_file(): receipt[p.name+"_sha256"]=sha(p)
    write(args.output/"execution.json",receipt)
    assert receipt["returncode"]==0, receipt
    assert receipt["application_custody_unchanged"] and receipt["external_scripts_unchanged"],receipt
    value=json.loads(report.read_text())
    text=console.read_text(errors="replace")
    assert "ERROR:" not in text and "SCRIPT ERROR:" not in text,text
    terminals=[json.loads(line.removeprefix("AMBIENT2_NATIVE_THIN ")) for line in text.splitlines()
               if line.startswith("AMBIENT2_NATIVE_THIN ")]
    assert len(terminals)==1,terminals
    terminal=terminals[0]
    assert value["complete"] and terminal["complete"] and value["failures"]==terminal["failures"]==[],value
    assert terminal["checks"]==value["checks"]>0
    assert terminal["source_revision"]==value["source_revision"]==SOURCE
    assert terminal["diagnostic_sha256"]==value["diagnostic_sha256"]==scripts["native_thin_probe.gd"]
    assert terminal["behavioral_episodes_added"]==value["behavioral_episodes_added"]==0
    assert value["godot_executable_sha256"]==before["engine"]["sha256"]
    assert value["publication"]["sha256"]==sha(cells)
    summary={"pass":True,"checks":value["checks"],"source_revision":SOURCE,
             "report_sha256":sha(report),"receipt_sha256":sha(args.output/"execution.json"),
             "coarse_reads":value["coarse"]["materials"]["sample_count"],
             "adaptive_reads":value["adaptive"]["materials"]["sample_count"],
             "native_tick":value["native_tick"],"physical_ticks":value["physical_ticks"],
             "behavioral_episodes_added":0}
    write(args.output/"verification.json",summary)
    print(json.dumps(summary,indent=2))

if __name__=="__main__": main()
