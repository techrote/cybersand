#!/usr/bin/env python3
"""Exact-source native and graphical Gentek 2048 Workbench acceptance runner.

Executes 2048 single/mixed authorship, explicit cancel/invalid refusal and
fresh-process persistence. Preserves original receipts, logs, hashes and
source/runtime distinctions. A hosted result is NOT owner physical Windows 11.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/ci"))
from check_repository import verify_runtime
EXPECTED_GODOT = "4.7.stable.official.5b4e0cb0f"
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|GDExtension library not found|Error loading extension")

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, sort_keys=True, indent=2)+"\n", encoding="utf-8")

def execute(label: str, cmd: list[str], env: dict[str,str], dest: Path, timeout: int, marker: str|None=None) -> dict:
    log=dest / (label+".log")
    started=time.monotonic()
    with log.open("w", encoding="utf-8") as stream:
        try:
            completed=subprocess.run(cmd, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                     timeout=timeout, check=False)
            code=completed.returncode; timed_out=False
        except subprocess.TimeoutExpired:
            code=-1; timed_out=True
    content=log.read_text(encoding="utf-8", errors="replace")
    passed=(code==0 and not timed_out and ERRORS.search(content) is None
            and (marker is None or re.search(marker,content) is not None))
    receipt=dict(command=cmd,returncode=code,timed_out=timed_out,passed=passed,
                 log_sha256=sha(log),duration_seconds=round(time.monotonic()-started,3))
    write_json(dest/(label+"-process.json"),receipt)
    if not passed: print(content[-8000:],file=sys.stderr)
    return receipt

def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot",type=Path,required=True)
    parser.add_argument("--out",type=Path,required=True)
    parser.add_argument("--headless",action="store_true")
    parser.add_argument("--timeout",type=int,default=1800)
    args=parser.parse_args()
    out=args.out.resolve()
    if out.exists():
        parser.error("Use a fresh evidence output directory.")
    out.mkdir(parents=True)
    godot=args.godot.resolve()
    source=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip()
    tracked_changes=subprocess.check_output(["git","status","--porcelain","--untracked-files=no"],cwd=ROOT,text=True).strip()
    if tracked_changes:
        diff=subprocess.check_output(["git","diff","--name-status"],cwd=ROOT,text=True).strip()
        print("GENTEK2048_TRACKED_SOURCE_DELTA",tracked_changes, "DIFF",diff, file=sys.stderr)
        parser.error("Tracked source changed during Godot import; refusing to treat changed bytes as exact-source qualification.")
    version=subprocess.check_output([str(godot),"--version"],text=True,timeout=45).strip()
    if version!=EXPECTED_GODOT:
        parser.error("Pinned Godot version differs: "+version)
    target = "windows" if os.name == "nt" else "linux"
    native_manifest = "runtime-provenance.json" if os.name == "nt" else "runtime-provenance.linux.json"
    identity={"source":source,"source_tree":subprocess.check_output(["git","rev-parse","HEAD^{tree}"],cwd=ROOT,text=True).strip(),
              "godot_version":version,"godot_sha256":sha(godot),
              "platform":platform.platform(),"physical_owner_windows11":False,
              "runner_is_graphical":not args.headless}
    for name, path in (("native", ROOT/"godot/addons/cybersand_native"/native_manifest),
                       ("rapier", ROOT/"godot/addons/godot-rapier2d"/f"runtime-provenance.{target}.json")):
        manifest = json.loads(path.read_text(encoding="utf-8"))
        errors = verify_runtime(ROOT, manifest)
        digest = sha(ROOT / manifest["artifact"])
        if errors or digest != manifest["sha256"]:
            parser.error(f"{name} runtime admission failed: {errors or 'materialized bytes differ'}")
        identity[name + "_runtime_sha256"] = digest
        identity[name + "_provenance_sha256"] = sha(path)
        identity[name + "_source_input_count"] = len(manifest["source_inputs"])
    write_json(out/"source-runtime-identity.json",identity)
    env=os.environ.copy()
    for key,suffix in (("XDG_DATA_HOME","data"),("XDG_CONFIG_HOME","config"),("XDG_CACHE_HOME","cache"),
                       ("APPDATA","roaming"),("LOCALAPPDATA","local")):
        folder=out/"profile"/suffix
        folder.mkdir(parents=True,exist_ok=True)
        env[key]=str(folder)
    env["CYBERSAND_ARCHITECTURE_OUTPUT"]=str(out)
    env["CYBERSAND_GENTEK2048_CAMPAIGN"]=str(uuid.uuid4())
    env["CYBERSAND_ARCHITECTURE_REQUIRE_GRAPHICS"]="0" if args.headless else "1"
    base=[str(godot),"--audio-driver","Dummy","--path",str(ROOT/"godot")]
    display=(["--headless"] if args.headless else
            ["--rendering-method","gl_compatibility"]+
            (["--rendering-driver","opengl3_angle"] if os.name=="nt" else ["--display-driver","x11"]))
    receipts={}
    receipts["import"]=execute("import",base+["--headless","--editor","--quit"],env,out,args.timeout)
    if receipts["import"]["passed"]:
        for phase in ("author","reopen"):
            env["CYBERSAND_GENTEK2048_PHASE"]=phase
            env["CYBERSAND_GENTEK2048_PROCESS"]=str(uuid.uuid4())
            marker=rf"GENTEK2048_RESULTS phase={phase} checks=[1-9][0-9]* failures=0 complete=true"
            receipts[phase]=execute(phase,base+display+["--script","res://tests/fixtures/gentek2048_workbench.gd"],
                                    env,out,args.timeout,marker)
            if not receipts[phase]["passed"]: break
    reports={}
    for phase in ("author","reopen"):
        path=out/("gentek2048-"+phase+".json")
        if path.is_file(): reports[phase]=json.loads(path.read_text(encoding="utf-8"))
    def native_cases(report):
        return [row for row in report["cases"] if row.get("case", "").startswith("gentek2048-")]
    complete=(set(reports)=={"author","reopen"} and
        all(r["failures"]==0 and r["complete"] and len(native_cases(r))==2 for r in reports.values()))
    if complete:
        for author, reopen in zip(native_cases(reports["author"]),native_cases(reports["reopen"])):
            for key in ("case","origin","seed","modules","zones","native_chunks","native_material_sha256","recipe_sha256","material_bytes","edits"):
                if author[key]!=reopen[key]: complete=False
            if not args.headless and (author["display"]=="headless" or reopen["display"]=="headless"): complete=False
            if author["material_bytes"]!=2048*2048 or author["native_chunks"]!=256: complete=False
    passed=complete and len(receipts)==3 and all(v["passed"] for v in receipts.values())
    summary=dict(source=identity,receipts=receipts,reports=reports,passed=passed,
                 owner_physical_acceptance="NOT RUN",tested_squares=[2048],
                 produced_png_sha256={p.name:sha(p) for p in sorted(out.glob("*.png"))})
    write_json(out/"qualification.json",summary)
    print("GENTEK2048_QUALIFICATION "+json.dumps({"passed":passed,"phases":list(reports),"source":source}),flush=True)
    return 0 if passed else 1

if __name__=="__main__":
    raise SystemExit(main())
