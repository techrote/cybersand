#!/usr/bin/env python3
"""Run registered unchanged-header synthetic controls, never a live SOL solver."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess

import la_selective_experiment as p

ROOT=Path(__file__).resolve().parents[2]
PROFILE="native/tests/fixtures/sol_passive_values_001.json"
SOURCE="native/tests/sol_passive_values.cpp"
HEADER="native/include/cybersand/granular_contact_response.hpp"

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def settings(case,profile):
    body=dict(profile["default_body"]);body.update({k:case[k] for k in body if k in case})
    solve=dict(profile["default_solve"]);solve.update({k:case[k] for k in solve if k in case})
    point=case.get("front_point",profile["front"]["point"]);normal=case.get("front_normal",profile["front"]["normal"])
    mode=2 if case.get("null_bin") else (1 if "points" in case else 0)
    values=[case["id"],*body["velocity"],body["omega"],body["mass"],body["inertia"],body["mu"],solve["available"],solve["capacity_scale"],solve["base_budget"],case.get("bins",1),case.get("front_samples",64),*point,*normal,case.get("support_samples",0),*case.get("support_normal",[0,0]),mode]
    return body,solve,values

def expected_bins(case,profile,body):
    def bin_value(points,normal):
        count=len(points);coords=[-normal[1]*x+normal[0]*y for x,y in points]
        mean=sum(coords)/count if count else 0
        return dict(count=count,material_mask=0,state_b_min=255,state_b_max=0,
            position_sum=[sum(p[k] for p in points) for k in range(2)],normal=normal if count else [0,0],
            maximum_radius=max((math.hypot(p[0]-body["com"][0],p[1]-body["com"][1]) for p in points),default=0),
            tangent_mean=mean,tangent_m2=sum((v-mean)**2 for v in coords),
            tangent_min=min(coords,default=0),tangent_max=max(coords,default=0))
    result=[]
    if not case.get("null_bin"):
        points=case.get("points",[case.get("front_point",profile["front"]["point"])]*case.get("front_samples",64))
        result=[bin_value(points,case.get("front_normal",profile["front"]["normal"])) for _ in range(case.get("bins",1))]
    if case.get("support_samples",0):result.append(bin_value([[0,0]]*case["support_samples"],case["support_normal"]))
    return result

def audit(data,profile):
    assert data["registration"]==profile["id"] and len(data["cases"])==25 and data["replay_equal_cases"]==25
    rows=[]
    for case,record in zip(profile["cases"],data["cases"]):
        assert case["id"]==record["id"] and record["replays_equal"]
        body,solve,_=settings(case,profile);obs=record["observation"];result=obs["result"]
        assert obs["body"]==body and all(obs[k]==solve[k] for k in solve),"Input mismatch"
        bins=expected_bins(case,profile,body)
        assert obs["null_bin"]==case.get("null_bin",False) and obs["input_bins"]==bins,"Registered contact-bin mismatch"
        refused=case.get("expected_refusal",False);assert result["passive_rejected"]==refused
        if refused:
            assert result["scale"]==0 and result["nodes"]==0 and result["impulse"]==[0,0] and result["torque"]==0
            rows.append(dict(id=case["id"],status="REFUSAL_AS_REGISTERED"));continue
        expected_nodes=sum((2 if b["tangent_m2"] else 1) for b in bins if b["count"])
        assert result["nodes"]==len(obs["nodes"])==expected_nodes
        assert result["bins"]==sum(b["count"]>0 for b in bins)
        assert result["quadrature_clamps"]==0
        tol=1e-12 if case["id"]=="mass-520" else 0
        vx,vy=[a+j/body["mass"] for a,j in zip(body["velocity"],result["impulse"])]
        omega=body["omega"]+result["torque"]/body["inertia"]
        assert all(abs(a-b)<=tol for a,b in zip([vx,vy],case["expected_velocity"])) and abs(omega-case.get("expected_omega",0))<=tol,"Registered analytic oracle failed"
        before=.5*body["mass"]*sum(v*v for v in body["velocity"])+.5*body["inertia"]*body["omega"]**2
        after=.5*body["mass"]*(vx*vx+vy*vy)+.5*body["inertia"]*omega*omega
        energy_tol=1e-10 if tol else 0
        assert abs(before-result["energy_before"])<=energy_tol and abs(after-result["energy_after"])<=energy_tol
        assert after<=before+profile["oracle"]["energy_increase_tolerance"]
        impulse=[0.,0.];normal_impulse=[0.,0.];tangent_impulse=[0.,0.];torque=0.;normal_total=0.;tangent_total=0.;residual=[];weight=0.
        for node in obs["nodes"]:
            n=node["normal"];t=[-n[1],n[0]];jn,jt=node["jn"],node["jt"]
            assert -1e-12<=jn<=node["capacity"]+1e-12 and abs(jt)<=body["mu"]*jn+1e-12
            j=[n[k]*jn+t[k]*jt for k in range(2)];r=[node["position"][k]-body["com"][k] for k in range(2)]
            impulse=[impulse[k]+j[k] for k in range(2)];torque+=r[0]*j[1]-r[1]*j[0]
            normal_impulse=[normal_impulse[k]+n[k]*jn for k in range(2)]
            tangent_impulse=[tangent_impulse[k]+t[k]*jt for k in range(2)];tangent_total+=abs(jt)
            residual.append((vx-omega*r[1])*n[0]+(vy+omega*r[0])*n[1]);normal_total+=jn;weight+=node["weight"]
        assert impulse==result["impulse"] and torque==result["torque"]
        assert normal_impulse==result["normal_impulse"] and tangent_impulse==result["tangent_impulse"]
        assert normal_total==result["normal"] and tangent_total==result["tangent"]
        assert not obs["nodes"] or abs(weight-1)<=1e-12
        assert normal_total<=result["capacity"]+1e-10 and result["updates"]==8*result["nodes"]
        if case["id"] in ["front","support-64","support-192","support-448","separating-64","separating-192","separating-448","mass-520"]:assert result["normal_cap_hits"]==0
        if case["id"] in ["low-cap","zero-cap"]:assert result["normal_cap_hits"]>0
        rows.append(dict(id=case["id"],status="ANALYTIC_PASS",velocity=[vx,vy],omega=omega,energy_before=before,energy_after=after,residual_node_normal_speeds=residual,capacity=result["capacity"],normal_cap_hits=result["normal_cap_hits"],nodes=result["nodes"],updates=result["updates"]))
    return rows

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("output",type=Path);args=parser.parse_args()
    output=args.output.resolve();assert output.is_relative_to(ROOT/"build") and not output.exists();output.mkdir(parents=True)
    source=p.git("rev-parse","HEAD").decode().strip();assert not p.git("status","--porcelain"),"Commit apparatus before execution"
    profile=json.loads((ROOT/PROFILE).read_text(encoding="utf-8"));assert sha(ROOT/HEADER)==profile["header_sha256"]
    inputs={name:sha(ROOT/name) for name in [PROFILE,SOURCE,HEADER,"tools/experiments/sol_passive_values.py"]}
    spec=output/"inputs.tsv";spec.write_bytes(("\n".join(" ".join(map(str,settings(case,profile)[2])) for case in profile["cases"])+"\n").encode())
    receipt=dict(source=source,tree=p.git("rev-parse","HEAD^{tree}").decode().strip(),profile=profile,input_sha256=inputs,spec_sha256=sha(spec),commands=[],observations=[])
    receipt.update(solver_calls_per_binary=100,registered_calls=75,workspace_priming_calls=25)
    def run(name,argv,env=None,timeout=180):
        row=p.command(name,argv,output,env,timeout);receipt["commands"].append(row);p.write(output/"receipt.json",receipt)
        assert row["clean"],name;return row
    linux=["wsl.exe","-d","Ubuntu-24.04","--cd",p.wsl_path(ROOT),"--"]
    run("gcc-version",linux+["g++","--version"])
    code="import hashlib,json,pathlib,shutil,subprocess; paths={'driver':pathlib.Path(shutil.which('g++')).resolve(),'frontend':pathlib.Path(subprocess.check_output(['g++','-print-prog-name=cc1plus'],text=True).strip()).resolve()}; print(json.dumps({k:dict(path=str(v),sha256=hashlib.sha256(v.read_bytes()).hexdigest()) for k,v in paths.items()}))"
    row=run("gcc-identity",linux+["python3","-c",code])
    receipt["gcc_toolchain"]=json.loads((ROOT/row["log"]).read_text(encoding="utf-8"))
    for variant,flags in [("opt",["-O3","-DNDEBUG"]),("san",["-O1","-g1","-fno-omit-frame-pointer","-fsanitize=address,undefined","-fno-sanitize-recover=all"])]:
        binary=output/("values-"+variant)
        run("compile-"+variant,linux+["g++","-std=c++20","-Wall","-Wextra","-Wpedantic","-Wconversion","-Wshadow","-Werror","-ffp-contract=off",*flags,"-Inative/include",SOURCE,"-o",p.wsl_path(binary)])
        extra=["env","ASAN_OPTIONS=detect_leaks=1:halt_on_error=1:strict_string_checks=1","UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1"] if variant=="san" else []
        row=run("run-"+variant,linux+extra+[p.wsl_path(binary),p.wsl_path(spec)])
        data=json.loads((ROOT/row["log"]).read_text(encoding="utf-8"));rows=audit(data,profile)
        receipt["observations"].append(dict(platform="linux",variant=variant,binary_sha256=sha(binary),cases=rows,raw_sha256=row["log_sha256"]));p.write(output/"receipt.json",receipt)
    setup=output/"msvc-env.cmd"
    script='@echo off\r\ncall "C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools\\Common7\\Tools\\VsDevCmd.bat" -no_logo -arch=x64 -host_arch=x64 -vcvars_ver=14.38 > "%~dp0msvc-setup.log" 2>&1\r\nif errorlevel 1 exit /b %errorlevel%\r\npython -c "import os,json;print(json.dumps({k:os.environ[k] for k in [\'PATH\',\'INCLUDE\',\'LIB\',\'LIBPATH\',\'VCToolsVersion\']}))"\r\n'
    setup.write_bytes(script.encode());row=run("msvc-env",["cmd.exe","/d","/c",str(setup)])
    selected=json.loads((ROOT/row["log"]).read_text(encoding="utf-8"));env=dict(os.environ,**selected)
    env.pop("CL",None);env.pop("_CL_",None)
    compiler=shutil.which("cl.exe",path=selected["PATH"]);assert compiler and "14.38.33130" in compiler
    receipt["msvc"]=dict(compiler=compiler,sha256=sha(Path(compiler)),selected_environment=selected,implicit_flags="CL and _CL_ removed from compile environment")
    binary=output/"values-msvc.exe"
    run("compile-msvc",[compiler,"/nologo","/Bv","/std:c++20","/W4","/WX","/EHsc","/O2","/fp:strict","/Inative/include",SOURCE,"/Fe:"+str(binary),"/Fo:"+str(output/"values-msvc.obj")],env)
    row=run("run-msvc",[str(binary),str(spec)],env)
    data=json.loads((ROOT/row["log"]).read_text(encoding="utf-8"));rows=audit(data,profile)
    receipt["observations"].append(dict(platform="windows",variant="msvc-opt",binary_sha256=sha(binary),cases=rows,raw_sha256=row["log_sha256"]))
    assert inputs=={name:sha(ROOT/name) for name in inputs} and not p.git("status","--porcelain")
    receipt["status"]="PASS; synthetic value oracle only";p.write(output/"receipt.json",receipt)
    print(json.dumps(dict(source=source,variants=3,cases=25,replays_per_case=3,accepted_per_variant=23,refusals_per_variant=2,status=receipt["status"])))

if __name__=="__main__":main()
