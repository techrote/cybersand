#!/usr/bin/env python3
"""Build and verify PR593 physical Windows candidate from a fixed Git tree."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import zipfile

ROOT=Path(__file__).resolve().parents[2]
SOURCE=os.environ.get("CYBERSAND_EVAL_SOURCE_SHA","9628729af052b417aa8a64e56f7e7bcdf4f2e876")
PARENT="214de85adef2aaabc8e26de8612a3bf27cc1a081"
NATIVE="godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
NATIVE_HASH="6c7811b78c12e34a68931f83f2fd505c20078c089bce245a9be8be6e02e6d04d"
RAPIER="godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
RAPIER_HASH="b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7"
ENGINE="Godot_v4.7-stable_win64.exe"
CONSOLE="Godot_v4.7-stable_win64_console.exe"
ENGINE_VERSION="4.7.stable.official.5b4e0cb0f"
ENGINE_ZIP_HASH=("41645a908eb3181d6f2d1201ed7b6d6f095f6a23aaed8903d5d255277cc8d142814f3e"
                 "6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9")

def need(ok,message):
    if not ok: raise RuntimeError(message)

def digest(file,algorithm="sha256"):
    h=hashlib.new(algorithm)
    with Path(file).open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""): h.update(chunk)
    return h.hexdigest()

def git(*args):
    return subprocess.check_output(["git",*args],cwd=ROOT,text=True).strip()

def source_and_binaries(native_dir):
    need(git("rev-parse",SOURCE)==SOURCE,"Pinned Git source does not exist")
    subprocess.run(["git","merge-base","--is-ancestor",PARENT,SOURCE],cwd=ROOT,check=True)
    subprocess.run(["git","diff","--exit-code",PARENT,SOURCE,"--","native","godot/native_extension",
                    "godot/scripts/workbench_physics_bridge.gd",
                    "godot/scripts/pixel_camera_transform.gd"],cwd=ROOT,check=True)
    provenance=json.loads((native_dir/"runtime-provenance.json").read_text())
    dll=native_dir/Path(NATIVE).name
    need(provenance.get("source_commit")==PARENT and provenance.get("sha256")==NATIVE_HASH
         and digest(dll)==NATIVE_HASH,"Unqualified native DLL")
    sources=provenance.get("source_inputs",{})
    need(isinstance(sources,dict) and len(sources)>20,"Unqualified source inputs")
    for name,expected in sources.items():
        file=ROOT/name
        need(file.is_file(),"Native source not present: "+name)
        need(hashlib.sha256(file.read_bytes().replace(b"\r\n",b"\n")).hexdigest()==expected,
             "Native source drift: "+name)
    rapier=ROOT/RAPIER
    need(rapier.is_file() and digest(rapier)==RAPIER_HASH,"Missing pinned x64 Rapier")
    return dll,rapier,provenance

def project_from_git(output,dll,rapier):
    # Git archive reads the exact #593 commit, not the separate packaging branch.
    files=["godot","examples/worldgen","THIRD_PARTY_NOTICES.md","LICENSE_STATUS.md",
           "third_party/godot-runtime.lock.json","third_party/native-toolchain.lock.json",
           "third_party/rapier-bvh-build.lock.json",
           "docs/audits/2026-11-14-pr566-mask-coherent-presentation-qualification.md"]
    tar=subprocess.check_output(["git","archive","--format=tar",SOURCE,"--",*files],cwd=ROOT,timeout=90)
    count=0
    with tarfile.open(fileobj=io.BytesIO(tar)) as archive:
        for member in archive:
            if not member.isfile(): continue
            name=member.name
            need(not name.startswith("/") and ".." not in Path(name).parts,"Unsafe archive path "+name)
            if name.startswith("godot/.godot/"): continue
            if Path(name).suffix.lower() in {".dll",".so",".dylib",".wasm"} and name not in {NATIVE,RAPIER}:
                continue
            f=archive.extractfile(member)
            need(f is not None,"Unreadable source file "+name)
            body=f.read()
            if name==NATIVE: body=dll.read_bytes()
            if name==RAPIER: body=rapier.read_bytes()
            need(not body.startswith(b"version https://git-lfs.github.com/spec/v1\n"),"Unresolved LFS "+name)
            destination=output/name
            destination.parent.mkdir(parents=True,exist_ok=True)
            destination.write_bytes(body)
            count+=1
    need(digest(output/NATIVE)==NATIVE_HASH and digest(output/RAPIER)==RAPIER_HASH,"Packaged DLL mismatch")
    recipes=list((output/"examples/worldgen").glob("*.json"))
    need({"gen007-deepworks.json","gen007-qualification.json"}<={p.name for p in recipes},
         "Missing generator profiles")
    target=output/"godot/authoring/worldgen"
    target.mkdir(parents=True,exist_ok=True)
    for r in recipes:
        need(isinstance(json.loads(r.read_text()),dict),"Malformed source recipe "+r.name)
        shutil.copyfile(r,target/r.name)
    old=output/"godot/addons/cybersand_native/runtime-provenance.json"
    if old.exists(): old.rename(old.with_name("retained-runtime-provenance.reference.json"))
    return count

def dependencies(output,engine_zip,notices,vc):
    need(digest(engine_zip,"sha512")==ENGINE_ZIP_HASH,"Godot archive mismatch")
    with zipfile.ZipFile(engine_zip) as z:
        need(z.testzip() is None,"Godot ZIP failed CRC")
        for name in (ENGINE,CONSOLE): (output/name).write_bytes(z.read(name))
    version=subprocess.check_output([str(output/CONSOLE),"--version"],text=True,timeout=45).strip()
    need(version==ENGINE_VERSION,"Godot version drift: "+version)
    for name in ("LICENSE.txt","COPYRIGHT.txt"):
        need((notices/name).is_file(),"Godot notice missing")
        shutil.copyfile(notices/name,output/("Godot-"+name))
    vcproof=json.loads((vc/"vc-runtime-provenance.json").read_text(encoding="utf-8-sig"))
    need(vcproof.get("schema")==1 and set(vcproof.get("files_sha256",{}))==
         {"vcruntime140.dll","Microsoft-Visual-C-Runtime-LICENSE.docx",
          "Microsoft-Visual-Studio-2022-LICENSE.docx"},"Signed VC runtime evidence missing")
    for name,expected in vcproof["files_sha256"].items():
        need(digest(vc/name)==expected,"VC runtime hash mismatch: "+name)
    for file in vc.iterdir():
        if file.is_file(): shutil.copyfile(file,output/file.name)

def launchers(output):
    for name,mode in (("Open Workbench.cmd","guarded"),
                      ("Open Guarded Workbench.cmd","guarded"),
                      ("Open Mask Baseline.cmd","mask")):
        script=('@echo off\nsetlocal\ncd /d "%~dp0"\n'
                'set "CYBERSAND_SOURCE_REVISION='+SOURCE+'"\n'
                'set "CYBERSAND_DIAG_FLYER_POSE='+mode+'"\n'
                'echo CyberSand PR593 '+mode+' - '+SOURCE+'\n'
                '"%~dp0'+CONSOLE+'" --headless --path "%~dp0godot" --editor --quit\n'
                'if errorlevel 1 (echo Import failed. & pause & exit /b 1)\n'
                'start "" "%~dp0'+ENGINE+'" --path "%~dp0godot" -- --workbench\n')
        (output/name).write_bytes(script.replace("\n","\r\n").encode())
    gpu=("$ErrorActionPreference='Stop'\n"
         "$os=Get-CimInstance Win32_OperatingSystem | Select Caption,Version,BuildNumber\n"
         "$gpu=Get-CimInstance Win32_VideoController | Select Name,DriverVersion,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate\n"
         "'CyberSand PR593 '+[DateTime]::UtcNow.ToString('o') | Out-File (Join-Path $PSScriptRoot 'GPU-LOCAL-INFO.txt')\n"
         "$os | Format-List | Out-File (Join-Path $PSScriptRoot 'GPU-LOCAL-INFO.txt') -Append\n"
         "$gpu | Format-List | Out-File (Join-Path $PSScriptRoot 'GPU-LOCAL-INFO.txt') -Append\n")
    (output/"Capture GPU information.ps1").write_text(gpu.replace("\n","\r\n"),encoding="utf-8")

GUIDE="""# CyberSand Engine Lab - Windows 11 experimental performance evaluation

This is an experimental evaluation candidate. No production release or merge acceptance.

Application source: SOURCE_SHA
Parent PR566 source: PARENT_SHA
Native Windows DLL SHA256: NATIVE_SHA256
Godot: 4.7.stable.official.5b4e0cb0f
Rapier Windows x64 module SHA256: RAPIER_SHA256

## Start
Extract the INNER CyberSand-593-Windows-9628729a.zip from the GitHub Actions
artifact into a fresh writable folder, e.g. C:\\CyberSand593. Keep all files
together. Double-click Open Guarded Workbench.cmd; it imports the project with
the bundled Godot console, then launches the actual GUI Workbench.

To compare the original uploaded-mask pose, CLOSE all running CyberSand
instances, then double-click Open Mask Baseline.cmd.
Open Workbench.cmd is an alias for the guarded launch mode.
No separate Godot, Git, Python, native DLL or compiler installation is needed.

## Engine Lab controls
Open the Workbench and click Engine Lab... on its top toolbar.
Use the FPS cap, VSync, Pixel and Rapier tick targets, material publication target, ACK delay and coupling toggles LIVE. Native worker count is saved for the NEXT full launch.
The advanced override enables rates up to 1000 Hz without repeated popups. The 10-second scripted benchmark saves actual-clock JSON in user data.
Non-60 cadence intentionally changes simulation speed because the flight integrator stays fixed at 1/60 per completed step.

## Physical acceptance
- [ ] Confirm Windows 11 OS build, GPU model/driver, resolution/Hz,
      Windows display scale and VSync; optionally run Capture GPU information.ps1.
- [ ] Open Guarded mode and fly an active Kestrel at low and high speed.
- [ ] Toggle Thruster Fire ON, then OFF; keep flying in Free camera.
- [ ] Repeat Fire ON->OFF under Follow camera.
- [ ] Pan/zoom; compare normal and rapid camera motion, resize the window.
- [ ] Fly near hard walls and through material-dense Sand/Water/Fire/Smoke.
- [ ] Capture any double image, visual holds, geometry separation or jank.
- [ ] Close completely, repeat with Open Mask Baseline.cmd under matched setup.
- [ ] Repeat pertinent settings at 100%, 125%, 150%, 200% scaling and VSync.
- [ ] Record qualitative smoothness, GPU load and frame pacing if available.
- [ ] Record your PASS/FAIL/HOLD and exact reproduction in ACCEPTANCE.md.

The hosted Windows ANGLE and Linux GL CI passed at this exact app source:
https://github.com/techrote/cybersand/actions/runs/43648093562
https://github.com/techrote/cybersand/actions/runs/43648093611

These hosted runs are NOT proof of physical NVIDIA GPU quality or dense-world
p95 performance. Conservative false refusals and material-contact holds remain
possible. Keep #593 and #566 Draft/HOLD until owner authorization.
"""
FEEDBACK="""# CyberSand PR593 - physical owner acceptance form

App source: SOURCE_SHA
Owner physical review: NOT YET PERFORMED

| Field | Observed |
|---|---|
| Windows build | |
| GPU / driver | |
| Resolution and refresh rate | |
| Windows display scaling | |
| VSync | |
| Scene/setup | |
| Guarded Free camera, Fire ON->OFF | |
| Guarded Follow camera, Fire ON->OFF | |
| Fast flight and dense materials | |
| Mask baseline comparison | |
| Frame pacing / GPU load | |
| Screenshot or video paths | |
| PASS / FAIL / HOLD | |

Reproduction steps:

Observed issues:

Owner decision (initially HOLD):
"""

def files_map(root):
    return {p.relative_to(root).as_posix():digest(p) for p in sorted(root.rglob("*"))
            if p.is_file() and p.name!="PR593-MANIFEST.json"}

def verify(output):
    m=json.loads((output/"PR593-MANIFEST.json").read_text())
    need(m.get("source_commit")==SOURCE and files_map(output)==m.get("files_sha256"),
         "Installed files are missing or changed")
    need(digest(output/NATIVE)==NATIVE_HASH and digest(output/RAPIER)==RAPIER_HASH,"Installed native mismatch")
    print("PR593_INSTALLED_INTEGRITY",len(m["files_sha256"]),SOURCE)
    return m

def build(args):
    need(os.name=="nt","Build must run on Windows")
    need(not args.output.exists() and not args.archive.exists(),"Refusing to overwrite package")
    dll,rapier,provenance=source_and_binaries(args.native_stage)
    args.output.mkdir(parents=True)
    count=project_from_git(args.output,dll,rapier)
    dependencies(args.output,args.godot_zip,args.notices,args.vc)
    launchers(args.output)
    replacements={"SOURCE_SHA":SOURCE,"PARENT_SHA":PARENT,
                  "NATIVE_SHA256":NATIVE_HASH,"RAPIER_SHA256":RAPIER_HASH}
    for name,data in (("READ-ME.md",GUIDE),("ACCEPTANCE.md",FEEDBACK)):
        for a,b in replacements.items():data=data.replace(a,b)
        (args.output/name).write_text(data,encoding="utf-8")
    (args.output/"PR566-qualified-native-provenance.json").write_text(
        json.dumps(provenance,indent=2,sort_keys=True)+"\n")
    identity={"schema":"engine-lab-001-windows-physical-v1","source_commit":SOURCE,
              "source_tree":git("rev-parse",SOURCE+"^{tree}"),"parent_commit":PARENT,
              "baseline_593_windows_run":43648093562,"baseline_593_linux_run":43648093611,
              "native_sha256":NATIVE_HASH,"rapier_sha256":RAPIER_HASH,
              "godot_version":ENGINE_VERSION,"godot_zip_sha512":ENGINE_ZIP_HASH,
              "owner_gpu_acceptance":"pending","source_archive_files":count,
              "files_sha256":files_map(args.output)}
    (args.output/"PR593-MANIFEST.json").write_text(json.dumps(identity,indent=2,sort_keys=True)+"\n")
    verify(args.output)
    args.archive.parent.mkdir(parents=True,exist_ok=True)
    paths=sorted(p for p in args.output.rglob("*") if p.is_file())
    names=[p.relative_to(args.output).as_posix() for p in paths]
    need(len(set(n.lower() for n in names))==len(names) and max(map(len,names))<220,
         "Windows-incompatible archive names")
    with zipfile.ZipFile(args.archive,"w",zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=False) as z:
        for p,name in zip(paths,names):z.write(p,name)
    with zipfile.ZipFile(args.archive) as z:
        need(z.testzip() is None and sorted(z.namelist())==sorted(names),"Archive CRC/manifest failed")
    archive_sha=digest(args.archive)
    args.archive.with_suffix(".zip.sha256").write_text(archive_sha+"  "+args.archive.name+"\n")
    args.archive.with_suffix(".zip.json").write_text(json.dumps({
        "source_commit":SOURCE,"zip":args.archive.name,"sha256":archive_sha,
        "bytes":args.archive.stat().st_size,"members":len(names),
        "owner_physical_gpu_acceptance":"pending"},indent=2)+"\n")
    print("PR593_PHYSICAL_PACKAGE",json.dumps({"source":SOURCE,"sha256":archive_sha,
           "bytes":args.archive.stat().st_size,"files":len(names)}),flush=True)

def smoke(output,evidence):
    verify(output)
    evidence.mkdir(parents=True,exist_ok=True)
    console=output/CONSOLE
    project=output/"godot"
    cases=[
        ("import",["--headless","--editor","--quit"],180,None),
        ("sweep",["--headless","--script","res://tests/test_workbench_presentation_coherence.gd"],120,"WORKBENCH_PRESENTATION_COHERENCE_RESULT"),
        ("production",["--headless","--script","res://tests/test_pr593_mask_coherent_production.gd"],210,"PR593_PRODUCTION_POSE_RESULT"),
        ("crossfade",["--headless","--script","res://tests/test_pr593_mask_coherent_edit_crossfade.gd"],210,"PR593_NATIVE_EDIT_CROSSFADE_RESULT"),
        ("dense-budget",["--headless","--script","res://tests/test_pr593_mask_coherent_dense_budget.gd"],120,"PR593_GUARD_DENSE_BUDGET_RESULT"),
        ("engine-lab",["--headless","--script","res://tests/test_workbench_engine_lab.gd"],180,"ENGINE_LAB_RESULT"),
        ("graphical",["--rendering-method","gl_compatibility","--quit-after","180","--","--workbench"],120,"Rapier2D")
    ]
    report=[]
    for name,suffix,timeout,marker in cases:
        cmd=[str(console),"--path",str(project),*suffix]
        print("PR593_SMOKE_START",name,flush=True)
        r=subprocess.run(cmd,cwd=output,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                         timeout=timeout,text=True,errors="replace")
        file=evidence/(name+".log")
        file.write_text(r.stdout)
        need(r.returncode==0 and "SCRIPT ERROR:" not in r.stdout and
             (marker is None or marker in r.stdout),"Installed "+name+" failed: "+r.stdout[-3500:])
        report.append({"name":name,"log_sha256":digest(file),"exit":r.returncode})
        print("PR593_SMOKE_PASS",name,flush=True)
    (evidence/"summary.json").write_text(json.dumps({
        "source_commit":SOURCE,"acceptance":"physical GPU pending","cases":report},indent=2)+"\n")

def main():
    p=argparse.ArgumentParser()
    p.add_argument("command",choices=["build","verify","smoke"])
    for name in ["native-stage","godot-zip","notices","vc","output","archive","evidence"]:
        p.add_argument("--"+name,type=Path,required=name=="output")
    a=p.parse_args()
    if a.command=="build":build(a)
    elif a.command=="verify":verify(a.output)
    else:
        need(a.evidence is not None,"Missing smoke evidence path")
        smoke(a.output,a.evidence)

if __name__=="__main__":main()
