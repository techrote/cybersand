#!/usr/bin/env python3
"""Run a same-Windows-host C2048 Godot A/B/B/A from verified source-built DLLs.

This program orchestrates the *existing* #493 Godot fixture through #505's
source-locked comparison; no solver or game physics is changed.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import sys
import urllib.request
import zipfile

from pf_gas_acceptance import read_json, write_json, sha256

STEPS = (("baseline", 0, 0), ("candidate", 0, 1),
         ("candidate", 1, 2), ("baseline", 1, 3))
GODOT_EXE = "Godot_v4.7-stable_win64_console.exe"
WIN_DLL = "cybersand_native.windows.x86_64.dll"

def call(cmd: list[str], log: Path | None = None, timeout: int = 600) -> None:
    if log:
        with log.open("w",encoding="utf-8") as out:
            r = subprocess.run(cmd, stdout=out, stderr=subprocess.STDOUT,
                               env={**os.environ, "GODOT_SILENCE_ROOT_WARNING":"1"},
                               timeout=timeout,check=False)
    else:
        r = subprocess.run(cmd, timeout=timeout, check=False)
    if r.returncode:
        tail = log.read_text(encoding="utf-8", errors="replace")[-3500:] if log else ""
        raise RuntimeError(f"Executable returned {r.returncode}: {cmd[0]} {tail}")

def download_godot(out: Path, url: str, sha512: str, version: str) -> Path:
    out.mkdir(parents=True,exist_ok=True)
    archive = out/"godot.zip"
    if archive.exists():
        raise FileExistsError(f"Do not overwrite prior engine provenance: {archive}")
    urllib.request.urlretrieve(url,archive)
    got=hashlib.sha512(archive.read_bytes()).hexdigest()
    if got!=sha512: raise RuntimeError("Official Godot archive SHA512 mismatch")
    with zipfile.ZipFile(archive) as f:
        if f.testzip(): raise RuntimeError("Godot archive CRC mismatch")
        for n in ("Godot_v4.7-stable_win64.exe",GODOT_EXE):
            f.extract(n,out)
    archive.unlink()
    engine=out/GODOT_EXE
    found=subprocess.check_output([str(engine),"--version"],text=True,timeout=30).strip()
    if found!=version: raise RuntimeError("Wrong official Godot engine: "+found)
    write_json(out/"engine-source.json",{
        "version":found,"archive_sha512":got,"console_sha256":sha256(engine)})
    return engine

def metrics(cases: list[dict]) -> dict | None:
    if not cases: return None
    dat=[x["metrics"]["native_tick_p50_ms"] for x in cases]
    ratios=[x["ratio"] for x in dat]
    return {"configurations":len(dat),
            "baseline_median_tick_ms":statistics.median(x["baseline"] for x in dat),
            "candidate_median_tick_ms":statistics.median(x["candidate"] for x in dat),
            "median_paired_speedup_percent":statistics.median(100*(1-r) for r in ratios),
            "min_speedup_percent":min(100*(1-r) for r in ratios),
            "max_speedup_percent":max(100*(1-r) for r in ratios),
            "individual_paired_speedups_percent":[100*(1-r) for r in ratios]}

def summarize(path: Path, out: Path) -> None:
    report=read_json(path)
    cases=report.get("per_configuration",[])
    def gas(g):
        return [c for c in cases if c["config"]["family"]=="pressure_flow_v1"
                and c["config"]["gas"]==g]
    overview={"schema":"pf-gas-godot-app-scope-v1",
              "scope":"real Windows Godot C2048 59 material 8 actor 1024x512 30+100 native-tick ballistic/face/spray",
              "status":report["disposition"],
              "coverage":report["coverage"],
              "errors":report["errors"],"gaps":report["gaps"],
              "all":metrics(cases),
              "gas_on":metrics(gas(True)),
              "gas_off":metrics(gas(False)),
              "controls":metrics([c for c in cases if c["config"]["family"]!="pressure_flow_v1"]),
              "gas_on_by_variant":{variant:metrics(
                  [c for c in gas(True) if c["config"]["variant"]==variant])
                  for variant in ("reference","cached","cached_dormant")},
              "gas_on_by_core":{str(fine):metrics(
                  [c for c in gas(True) if c["config"]["fine"]==fine])
                  for fine in (False,True)},
              "limitations":"Native tick WALL duration, not CPU time, rendered GPU FPS, deterministic full-state proof, or full-factorial admission"}
    write_json(out/"app-screen-summary.json",overview)
    print("REAL_GODOT_PF_APP_COMPARISON "+json.dumps(overview,sort_keys=True),flush=True)

def main() -> int:
    p=argparse.ArgumentParser()
    p.add_argument("--app",required=True)
    p.add_argument("--candidate",required=True)
    p.add_argument("--out",required=True)
    p.add_argument("--godot-url",required=True)
    p.add_argument("--godot-sha512",required=True)
    p.add_argument("--godot-version",required=True)
    args=p.parse_args()
    out=Path(args.out).resolve()
    app=Path(args.app).resolve()
    candidate=Path(args.candidate).resolve()
    if (out/"ABBA").exists():
        raise FileExistsError("Refusing to overwrite an existing application A/B run")
    native=app/"godot/addons/cybersand_native/bin"/WIN_DLL
    rapier=app/"godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
    baseline_sha=read_json(out/"identities/baseline.json")["native_sha256"]
    candidate_sha=read_json(out/"identities/candidate.json")["native_sha256"]
    if sha256(native)!=baseline_sha:
        raise RuntimeError("Accepted main runtime has changed since provenance validation")
    if sha256(candidate/WIN_DLL)!=candidate_sha:
        raise RuntimeError("Candidate runtime has changed since provenance validation")
    # Preserve exact original runtime bytes, rather than relying on the mutable
    # app installation after each source switch.
    shutil.copy2(native,out/"identities/baseline.dll")
    shutil.copy2(candidate/WIN_DLL,out/"identities/candidate.dll")
    engine=download_godot(out/"toolchain",args.godot_url,args.godot_sha512,args.godot_version)
    call([str(engine),"--headless","--editor","--path",str(app/"godot"),"--import"],
         log=out/"toolchain/import.log",timeout=600)
    print("REAL_GODOT_SOURCE_MATCHED_IMPORT_PASS",flush=True)
    for role,rep,order in STEPS:
        dll=(out/"identities"/(role+".dll"))
        expected=baseline_sha if role=="baseline" else candidate_sha
        if sha256(dll)!=expected: raise RuntimeError("Source-swap runtime hash changed")
        shutil.copy2(dll,native)
        if sha256(native)!=expected: raise RuntimeError("Installed Godot DLL not the requested source")
        cmd=[sys.executable,"tools/ci/pf_gas_acceptance.py","execute",
             "--subset","quick","--role",role,"--replicate",str(rep),
             "--order-position",str(order),
             "--source-build-manifest",str(out/"identities"/(role+".json")),
             "--godot",str(engine),"--project",str(app/"godot"),
             "--native",str(native),"--rapier",str(rapier),
             "--out",str(out/"ABBA"/role),"--timeout","2400"]
        print(f"REAL_GODOT_ABBA_BEGIN {role} repetition={rep} position={order}",flush=True)
        call(cmd,timeout=2500)
        print(f"REAL_GODOT_ABBA_END {role} repetition={rep} position={order}",flush=True)
    output=out/"ABBA/comparison.json"
    cmd=[sys.executable,"tools/ci/pf_gas_acceptance.py","compare",
         "--subset","quick","--baseline",str(out/"ABBA/baseline"),
         "--candidate",str(out/"ABBA/candidate"),"--output",str(output)]
    r=subprocess.run(cmd,check=False)
    if output.is_file():
        summarize(output,out/"ABBA")
    if r.returncode not in (0,2):
        raise RuntimeError("Real Godot comparison failed source/physical validity, exit "+str(r.returncode))
    print("REAL_GODOT_APP_SCREEN_COMPLETED; final full 360x3 and gameplay gates remain separate",flush=True)
    return 0

if __name__=="__main__":
    try: raise SystemExit(main())
    except Exception as e:
        print("REAL_GODOT_APP_SCREEN_ERROR: "+str(e),file=sys.stderr,flush=True)
        raise SystemExit(1)
