#!/usr/bin/env python3
"""Build the coherent Workbench Windows evaluation from one exact Git source."""
import argparse
import hashlib
import io
import json
import os
import re
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile
import zipfile

ROOT=Path(__file__).resolve().parents[2]
SOURCE=os.environ.get("CYBERSAND_EVAL_SOURCE_SHA", "")
ACCEPTED_MAIN="018bd09503d7f079ddac52e225c2f7daf8d678bf"
MANIFEST="CAMERA-STACK-MANIFEST.json"
PARENT="214de85adef2aaabc8e26de8612a3bf27cc1a081"
NATIVE="godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
RAPIER="godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
RAPIER_HASH="b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7"
ENGINE="Godot_v4.7-stable_win64.exe"
CONSOLE="Godot_v4.7-stable_win64_console.exe"
ENGINE_VERSION="4.7.stable.official.5b4e0cb0f"
ENGINE_ZIP_HASH=("41645a908eb3181d6f2d1201ed7b6d6f095f6a23aaed8903d5d255277cc8d142814f3e"
                 "6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9")
PRESERVED=("native","godot/native_extension","godot/addons/cybersand_native",
           "godot/addons/godot-rapier2d","third_party/native-toolchain.lock.json",
           "third_party/godot-runtime.lock.json","godot/third_party/rapier2d.lock.json")
APPLICATION=("godot/scripts","godot/tests","godot/shaders","godot/project.godot","godot/main.tscn",
             "tools/ci/package_engine_lab_windows.py","tools/ci/run_render_cadence_matrix.py",
             "tools/ci/run_physics_freeze_comparison.py","tools/ci/run_camera_coherence_regressions.py",
             "tools/ci/analyze_pose_trace.py","Run-Test-It.ps1","Test It.cmd",
             "docs/operations/camera-stack-coherence-acceptance.md")

def need(ok,message):
    if not ok: raise RuntimeError(message)

def digest(file,algorithm="sha256"):
    h=hashlib.new(algorithm)
    with Path(file).open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""): h.update(chunk)
    return h.hexdigest()

def git(*args):
    return subprocess.check_output(["git",*args],cwd=ROOT,text=True).strip()

def safe_name(name):
    path=PurePosixPath(name)
    need(name and path.parts and str(path)==name and not path.is_absolute() and
         ".." not in path.parts and "\\" not in name,"Unsafe package path: "+name)
    need(all(part and not re.search(r'[<>:"|?*\x00-\x1f]',part) and not part.endswith(("."," ")) and
             not re.fullmatch(r"(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?",part)
             for part in path.parts),"Windows-incompatible package path: "+name)
    return path

def verify_runtime(root, provenance, kind="native"):
    inputs=provenance.get("source_inputs",{})
    need(isinstance(inputs,dict) and len(inputs)>0,"Missing runtime source-input ledger")
    if kind=="native":
        need(re.fullmatch(r"[0-9a-f]{40}",provenance.get("source_commit","")),"Native build identity missing")
    elif kind=="rapier":
        build=provenance.get("build_record",{})
        need(provenance.get("schema_version")==1 and
             provenance.get("status")=="source-matched-cooperative-bvh-backport" and
             re.fullmatch(r"[0-9a-f]{40}",provenance.get("build_commit","")) and
             build.get("source_sha")==provenance["build_commit"] and build.get("variant")=="patched" and
             build.get("godot_version")==ENGINE_VERSION and build.get("join_regression_exit")==0 and
             build.get("artifacts",{}).get(Path(provenance.get("artifact","")).name)==provenance.get("sha256"),
             "Missing or inconsistent Rapier build-record identity")
    else: raise RuntimeError("Unknown retained runtime kind: "+kind)
    for name,expected in inputs.items():
        relative=safe_name(name)
        file=root/relative
        need(file.is_file(),"Runtime source not present: "+name)
        need(hashlib.sha256(file.read_bytes().replace(b"\r\n",b"\n")).hexdigest()==expected,
             "Runtime source drift: "+name)
    name=provenance.get("artifact","")
    safe_name(name)
    file=root/name
    need(file.is_file() and digest(file)==provenance.get("sha256")
         and file.stat().st_size==provenance.get("size"),"Runtime bytes differ from recorded build: "+name)


def preflight(platform="windows"):
    need(re.fullmatch(r"[0-9a-f]{40}",SOURCE or ""),"Full exact application source SHA required")
    need(git("rev-parse","HEAD")==SOURCE,"Checkout is not the requested application source")
    for parent in (PARENT,ACCEPTED_MAIN):
        subprocess.run(["git","merge-base","--is-ancestor",parent,SOURCE],cwd=ROOT,check=True)
    subprocess.run(["git","diff","--exit-code",ACCEPTED_MAIN,SOURCE,"--",*PRESERVED],cwd=ROOT,check=True)
    # The helper and the application under test must be the archived source.
    # Generated Godot caches are excluded from these source paths.
    subprocess.run(["git","diff","--exit-code",SOURCE,"--",*PRESERVED,*APPLICATION],cwd=ROOT,check=True)
    untracked=git("ls-files","--others","--exclude-standard","--",*APPLICATION).splitlines()
    need(not any(Path(name).suffix in {".gd",".gdshader",".gdshaderinc",".py",".ps1",".json",".md"} for name in untracked),
         "Untracked application or qualification source prevents exact-source execution")
    subprocess.run(["git","diff","--exit-code",PARENT,SOURCE,"--",
                    "godot/scripts/workbench_physics_bridge.gd","godot/scripts/pixel_camera_transform.gd"],
                   cwd=ROOT,check=True)
    manifest=ROOT/"godot/addons/cybersand_native"/("runtime-provenance.json" if platform=="windows" else "runtime-provenance.linux.json")
    provenance=json.loads(manifest.read_text())
    need(re.fullmatch(r"[0-9a-f]{40}",provenance.get("source_commit","")),"Native build identity missing")
    for name,expected in provenance.get("source_inputs",{}).items():
        canonical=subprocess.check_output(["git","show",SOURCE+":"+name],cwd=ROOT)
        need(hashlib.sha256(canonical.replace(b"\r\n",b"\n")).hexdigest()==expected,
             "Exact source differs from retained native build: "+name)
    verify_runtime(ROOT,provenance)
    rapier=json.loads((ROOT/("godot/addons/godot-rapier2d/runtime-provenance."+platform+".json")).read_text())
    verify_runtime(ROOT,rapier,"rapier")
    return {"source_commit":SOURCE,"source_tree":git("rev-parse",SOURCE+"^{tree}"),
            "accepted_main":ACCEPTED_MAIN,"native_build_commit":provenance["source_commit"],
            "native_sha256":provenance["sha256"],"native_source_inputs":len(provenance["source_inputs"]),
            "rapier_sha256":rapier["sha256"],"platform":platform,"physical_gpu_acceptance":"pending"}


def source_and_binaries(native_dir=None):
    identity=preflight("windows")
    folder=ROOT/"godot/addons/cybersand_native"
    provenance=json.loads((folder/"runtime-provenance.json").read_text())
    dll=ROOT/NATIVE
    if native_dir is not None:
        staged=json.loads((native_dir/"runtime-provenance.json").read_text())
        need(staged==provenance,"Staged runtime provenance differs from exact source")
        dll=native_dir/Path(NATIVE).name
        if not dll.is_file(): dll=native_dir/"bin"/Path(NATIVE).name
    need(digest(dll)==identity["native_sha256"],"Unqualified staged native DLL")
    return dll,ROOT/RAPIER,provenance


def project_from_git(output,dll,rapier,provenance):
    # Git archive reads the exact integrated source, never an uncommitted working copy.
    files=["godot","examples/worldgen","THIRD_PARTY_NOTICES.md","LICENSE_STATUS.md",
           "third_party/godot-runtime.lock.json","third_party/native-toolchain.lock.json",
           "third_party/rapier-bvh-build.lock.json",
           "docs/audits/2026-11-14-pr566-mask-coherent-presentation-qualification.md",
           "docs/audits/2026-11-15-render-cadence-001.md",
           "docs/audits/2026-11-15-camera-stack-coherence.md",
           "docs/audits/2026-11-15-workbench-physics-freezes.md",
           "docs/audits/2026-11-16-physics-freeze-remediation-002.md",
           "docs/operations/engine-lab-pose-tracing.md",
           "docs/operations/camera-stack-coherence-acceptance.md",
           "docs/operations/native-pixel-scrolling.md",
           "docs/architecture/rendering-and-gameplay-bridges.md",
           "tools/ci/analyze_pose_trace.py",
           "tools/ci/run_render_cadence_matrix.py",
           "Run-Test-It.ps1","Test It.cmd"]
    rapier_provenance=json.loads((ROOT/"godot/addons/godot-rapier2d/runtime-provenance.windows.json").read_text())
    files=sorted(set(files+list(provenance["source_inputs"])+list(rapier_provenance["source_inputs"])))
    tar=subprocess.check_output(["git","archive","--format=tar",SOURCE,"--",*files],cwd=ROOT,timeout=90)
    count=0
    with tarfile.open(fileobj=io.BytesIO(tar)) as archive:
        for member in archive:
            if not member.isfile(): continue
            name=member.name
            safe_name(name)
            if name.startswith("godot/.godot/"): continue
            if (Path(name).suffix.lower() in {".dll",".so",".dylib",".wasm"} or ".framework/" in name) and name not in {NATIVE,RAPIER}:
                continue
            f=archive.extractfile(member)
            need(f is not None,"Unreadable source file "+name)
            body=f.read()
            if name==NATIVE: body=dll.read_bytes()
            if name==RAPIER: body=rapier.read_bytes()
            if name=="Test It.cmd": body=body.replace(b"\r\n",b"\n").replace(b"\n",b"\r\n")
            need(not body.startswith(b"version https://git-lfs.github.com/spec/v1\n"),"Unresolved LFS "+name)
            destination=output/name
            destination.parent.mkdir(parents=True,exist_ok=True)
            destination.write_bytes(body)
            count+=1
    need(digest(output/NATIVE)==provenance["sha256"] and digest(output/RAPIER)==RAPIER_HASH,"Packaged DLL mismatch")
    recipes=list((output/"examples/worldgen").glob("*.json"))
    need({"gen007-deepworks.json","gen007-qualification.json"}<={p.name for p in recipes},
         "Missing generator profiles")
    target=output/"godot/authoring/worldgen"
    target.mkdir(parents=True,exist_ok=True)
    for r in recipes:
        need(isinstance(json.loads(r.read_text()),dict),"Malformed source recipe "+r.name)
        shutil.copyfile(r,target/r.name)
    verify_runtime(output,provenance)
    verify_runtime(output,rapier_provenance,"rapier")
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
    for name,mode,selection,cadence,material,physics in (
            ("Open Workbench.cmd","guarded","", "","auto",""),
            ("Open Publication Control.cmd","guarded","", "","full","combined"),
            ("Open Full Texture Control.cmd","guarded","", "","full",""),
            ("Open Coherent Workbench.cmd","guarded","", "","auto",""),
            ("Open Guarded Workbench.cmd","guarded","", "","auto",""),
            ("Open Original Presentation.cmd","guarded","legacy", "","auto",""),
            ("Open Mask Baseline.cmd","mask","legacy", "","auto",""),
            ("Open Original Cadence.cmd","guarded","legacy","legacy","full","combined")):
        script=('@echo off\nsetlocal\ncd /d "%~dp0"\n'
                'set "CYBERSAND_SOURCE_REVISION='+SOURCE+'"\n'
                'set "CYBERSAND_EVAL_SOURCE_SHA='+SOURCE+'"\n'
                'set "CYBERSAND_DIAG_FLYER_POSE='+mode+'"\n'
                'set "CYBERSAND_DIAG_PRESENTATION='+selection+'"\n'
                'set "CYBERSAND_DIAG_RENDER_CADENCE='+cadence+'"\n'
                'set "CYBERSAND_MATERIAL_PUBLICATION='+material+'"\n'
                'set "CYBERSAND_DIAG_PHYSICS_PUBLICATION='+physics+'"\n'
                'set "CYBERSAND_DIAG_COMMON_OBSERVER="\n'
                'echo CyberSand Workbench - '+('original presentation' if selection else 'coherent candidate')+'\n'
                'echo Source '+SOURCE+'\n'
                '"%~dp0'+CONSOLE+'" --headless --path "%~dp0godot" --editor --quit\n'
                'if errorlevel 1 (echo Import failed. & pause & exit /b 1)\n'
                'if defined CYBERSAND_LAUNCH_TEST_WAIT (\n'
                '  start "" /wait "%~dp0'+ENGINE+'" --path "%~dp0godot" %* -- --workbench\n'
                '  exit /b\n'
                ')\n'
                'start "" "%~dp0'+ENGINE+'" --path "%~dp0godot" %* -- --workbench\n')
        (output/name).write_bytes(script.replace("\n","\r\n").encode())

GUIDE=r"""# CyberSand coherent Workbench - Windows evaluation

Application source: SOURCE_SHA
Accepted-main base: ACCEPTED_MAIN_SHA
Native build: NATIVE_BUILD_SHA
Native Windows DLL SHA256: NATIVE_SHA256
Godot: 4.7.stable.official.5b4e0cb0f
Rapier Windows x64 module SHA256: RAPIER_SHA256

Extract this entire ZIP into a fresh writable directory. No separate Godot,
Python, Git or repository installation is required.

1. Double-click Open Workbench.cmd for the repaired interactive Shared Workbench.
2. Fly a Needle in Free and Follow modes. Turn Thruster fire ON, then OFF.
   Try fast movement, contact/dense materials, and normal camera pan/zoom.
   Paint small and large areas while playing; pause, single-step, Undo/Redo,
   Save and reopen in a fresh process.
3. Close CyberSand. Open Publication Control.cmd uses full texture uploads
   and the combined native/graphical handoff in the same reviewed source.
   Repeat the same setup. Both modes retain coherent presentation, fixed-step
   authoritative Rapier physics and the normal native-sample safety wait.
4. Open Full Texture Control.cmd isolates full texture uploads while keeping
   the early physics handoff. Engine Lab also switches texture modes live;
   it reports the active backend and any fallback reason.
5. Double-click Test It.cmd for two matched Free/Follow publication pairs
   (four fresh application windows). Test It.cmd -Quick runs the Follow pair.
   Results and the complete local ZIP appear under Test-It-Results.
   READ-RESULTS.txt gives actual completed native/Rapier rates, physical gap
   distributions and hold reasons, upload stages, and frame cadence.
   A complete capture does not mean gameplay passed physical evaluation.

Automatic material publication uploads bounded independent R8/RG8 arrays and copies
dirty rectangles on the GPU into linear RGBA8 history textures. The
desktop OpenGL/ANGLE path retains exact material/condition bytes and the original
appearance shaders; unsupported or detectably invalid resources use full texture
fallback. Current/previous history, crossfade, collision masks and revision ACKs
are preserved. At 2048-square RG8, one changed tile submits 32KiB instead of 8MiB;
the two histories and bounded staging/retirement resources occupy about64.0MiB
of logical GPU texture storage. GPU copy writes are additional traffic.
Three independent one-layer staging arrays per size class rotate after submission.
Each has its own fixed sampler. Adjacent copies merge only inside both source
and destination rows, without extra upload bytes or destination pixels.
Only the copy operation samples these arrays; ordinary World appearance keeps
its existing 2D textures. Layer updates retain allocated staging storage.
Rotation increases reuse distance; it is not a GPU fence or a nonblocking guarantee.
Large changes/full initialization can still be expensive. The early physical
mailbox removes graphical packet work from the completion handoff but does not
remove native computation, required terrain installation, strict feedback age,
or the need for actual main-thread physics callbacks.

The comparison uses the exact original 2048-square Needle reference, native 60/
Rapier 60 requests, native wait/wake ON, Auto workers, normal window/zoom and
startup VSync. Fire toggles at completed steps 0/60. Both arms use the same input
tape and require exact equality of all recorded common physical states and
feedback associations. It compares modes within one source; the CI evidence
separately compares the old c1ad source against this application on one host.
Configured rates are not achieved rates; Rapier retains fixed 1/60 simulated
seconds per completed step. Upload-stage timers are elapsed calls and include
possible waiting/descheduling, not isolated CPU execution or GPU transfer time.

Every case records CPU, native worker request/capacity, GPU/driver, DPI, VSync,
renderer and source. Your saved worker preference stays unchanged. Hosted
ANGLE/software rendering does not establish physical Windows 11 NVIDIA acceptance.
Engine Lab retains FPS/VSync, Pixel/Rapier/publication pacing and local pose traces.
The earlier temporal-policy comparison remains explicitly available:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Run-Test-It.ps1 -Coherence
The earlier cadence investigation uses -Cadence. Open Original Presentation.cmd
retains the old visual source policy; it is separate from publication controls.

The full practical acceptance guide is:
docs/operations/camera-stack-coherence-acceptance.md
Record your observations in ACCEPTANCE.md. Automated execution and hosted
Windows rendering do not establish physical NVIDIA acceptance. This candidate
and the camera PR stack remain Draft/HOLD; no merge is implied.
"""
FEEDBACK="""# CyberSand physical owner acceptance

App source: SOURCE_SHA
Prior physical result: FAIL - source 43f46c6e5ec9 had frequent physics freezes.
Corrective candidate owner decision: HOLD - this source not yet physically evaluated.

| Field | Observation |
| --- | --- |
| Windows build, NVIDIA GPU / driver | |
| CPU model, logical processors, requested/resolved native workers | |
| Resolution, refresh rate, Windows display scale | |
| VSync / FPS target | |
| Free camera: coherence, jumps/reversals, Fire ON to OFF | |
| Follow camera: coherence, camera motion, Fire ON to OFF | |
| Fast Needle, contact and dense materials | |
| Physical freezing or long gaps (separate from visual source holds) | |
| Pan, zoom, fractional scale and painting | |
| Publication Control / Full Texture Control comparison | |
| Materially preferable candidate? | |
| Test-It-Results ZIP name | |
| PASS / FAIL / HOLD | |

Reproduction steps and observed issues:
"""

def files_map(root):
    return {p.relative_to(root).as_posix():digest(p) for p in sorted(root.rglob("*"))
            if p.is_file() and p.name!=MANIFEST}

def verify(output):
    m=json.loads((output/MANIFEST).read_text())
    need(m.get("schema")=="camera-stack-coherence-windows-v1" and m.get("accepted_main")==ACCEPTED_MAIN,
         "Wrong integrated evaluation manifest")
    need(m.get("source_commit")==SOURCE and files_map(output)==m.get("files_sha256"),
         "Installed files are missing or changed")
    need(digest(output/NATIVE)==m["native_sha256"] and digest(output/RAPIER)==m["rapier_sha256"],"Installed native mismatch")
    verify_runtime(output,json.loads((output/"godot/addons/cybersand_native/runtime-provenance.json").read_text()))
    verify_runtime(output,json.loads((output/"godot/addons/godot-rapier2d/runtime-provenance.windows.json").read_text()),"rapier")
    print("COHERENCE_INSTALLED_INTEGRITY",len(m["files_sha256"]),SOURCE)
    return m

def build(args):
    need(os.name=="nt","Build must run on Windows")
    need(not args.output.exists() and not args.archive.exists(),"Refusing to overwrite package")
    dll,rapier,provenance=source_and_binaries(args.native_stage)
    args.output.mkdir(parents=True)
    count=project_from_git(args.output,dll,rapier,provenance)
    dependencies(args.output,args.godot_zip,args.notices,args.vc)
    launchers(args.output)
    replacements={"SOURCE_SHA":SOURCE,"ACCEPTED_MAIN_SHA":ACCEPTED_MAIN,
                  "NATIVE_BUILD_SHA":provenance["source_commit"],
                  "NATIVE_SHA256":provenance["sha256"],"RAPIER_SHA256":RAPIER_HASH}
    for name,data in (("READ-ME.md",GUIDE),("ACCEPTANCE.md",FEEDBACK)):
        for a,b in replacements.items():data=data.replace(a,b)
        (args.output/name).write_text(data,encoding="utf-8")
    (args.output/"retained-native-build-provenance.json").write_text(
        json.dumps(provenance,indent=2,sort_keys=True)+"\n")
    identity={"schema":"camera-stack-coherence-windows-v1","source_commit":SOURCE,
              "source_tree":git("rev-parse",SOURCE+"^{tree}"),"parent_commit":PARENT,"accepted_main":ACCEPTED_MAIN,
              "native_build_commit":provenance["source_commit"],"native_source_inputs":len(provenance["source_inputs"]),
              "baseline_593_windows_run":43648093562,"baseline_593_linux_run":43648093611,
              "native_sha256":provenance["sha256"],"rapier_sha256":RAPIER_HASH,
              "godot_version":ENGINE_VERSION,"godot_zip_sha512":ENGINE_ZIP_HASH,
              "owner_gpu_acceptance":"pending","source_archive_files":count,
              "files_sha256":files_map(args.output)}
    (args.output/MANIFEST).write_text(json.dumps(identity,indent=2,sort_keys=True)+"\n")
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
    print("COHERENCE_PHYSICAL_PACKAGE",json.dumps({"source":SOURCE,"sha256":archive_sha,
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
        ("temporal",["--headless","--script","res://tests/test_workbench_temporal_presentation.gd"],240,"TEMPORAL_PRESENTATION_RESULT"),
        ("temporal-dense",["--headless","--script","res://tests/test_workbench_temporal_dense.gd"],240,"TEMPORAL_DENSE_RESULT"),
        ("temporal-contact",["--headless","--script","res://tests/test_workbench_temporal_contact.gd"],240,"TEMPORAL_CONTACT_RESULT"),
        ("temporal-contact-graphical",["--rendering-driver","opengl3_angle","--rendering-method","gl_compatibility",
         "--audio-driver","Dummy","--max-fps","60","--script","res://tests/test_workbench_temporal_contact.gd"],300,"TEMPORAL_CONTACT_RESULT"),
        ("materials",["--headless","--script","res://tests/test_material_lab_catalogue.gd"],180,"MATERIAL_LAB_CATALOGUE"),
        ("architecture-contract",["--headless","--script","res://tests/test_architectural_project_contract.gd"],180,"ARCHITECTURAL_PROJECT_CONTRACT"),
        ("architecture-native",["--headless","--script","res://tests/test_architectural_generator.gd"],300,"ARCHITECTURE_RESULTS"),
        ("architecture-author",["--rendering-method","gl_compatibility","--script","res://tests/test_architectural_generator.gd"],600,"ARCHITECTURE_RESULTS"),
        ("architecture-reopen",["--rendering-method","gl_compatibility","--script","res://tests/test_architectural_generator.gd"],300,"ARCHITECTURE_RESULTS"),
        ("flatten-author",["--headless","--script","res://tests/test_workbench_flatten.gd"],600,"FLATTEN_RESULT"),
        ("flatten-reopen",["--headless","--script","res://tests/test_workbench_flatten.gd"],300,"FLATTEN_RESULT"),
        ("engine-lab",["--headless","--script","res://tests/test_workbench_engine_lab.gd"],180,"ENGINE_LAB_RESULT"),
        ("pose-trace",["--headless","--script","res://tests/test_workbench_pose_trace.gd"],180,"POSE_TRACE_RESULT"),
        ("cadence-contract",["--headless","--script","res://tests/test_render_cadence_contract.gd"],180,"RENDER_CADENCE_CONTRACT_RESULT"),
        ("cadence-worker",["--headless","--script","res://tests/test_render_cadence_worker.gd"],180,"RENDER_CADENCE_WORKER:"),
        ("ack-deadlines",["--headless","--script","res://tests/test_render_ack_deadlines.gd"],180,"RENDER_ACK_DEADLINES_RESULT"),
        ("paint-author",["--rendering-method","gl_compatibility","--audio-driver","Dummy","--script","res://tests/test_paint_editor_workbench.gd"],600,"PAINT_EDITOR_WORKBENCH"),
        ("paint-reopen",["--rendering-method","gl_compatibility","--audio-driver","Dummy","--script","res://tests/test_paint_editor_workbench.gd"],240,"PAINT_EDITOR_WORKBENCH"),
        ("native-camera",["--headless","--script","res://tests/test_native_pixel_camera.gd"],300,"NATIVE_PIXEL_CAMERA_RESULT"),
        ("failure-recovery",["--headless","--script","res://tests/test_workbench_failure_recovery.gd"],300,"WORKBENCH_FAILURE_RECOVERY"),
        ("workbench-input",["--headless","--script","res://tests/test_workbench_input.gd"],240,"WORKBENCH_INPUT"),
        ("workbench-fleet",["--headless","--script","res://tests/test_workbench_fleet_session.gd"],240,"WORKBENCH_FLEET"),
        ("workbench-physics",["--headless","--script","res://tests/test_workbench_physics_play.gd"],600,"WORKBENCH_PHYSICS"),
        ("physics-pacing",["--headless","--audio-driver","Dummy","--script","res://tests/test_workbench_physics_pacing.gd"],300,"PHYSICS_PACING_RESULT"),
        ("physics-publication",["--headless","--audio-driver","Dummy","--script","res://tests/test_workbench_physics_publication.gd"],300,"PHYSICS_PUBLICATION_RESULT"),
        ("physics-publication-graphical",["--rendering-method","gl_compatibility","--audio-driver","Dummy","--script","res://tests/test_workbench_physics_publication.gd"],300,"PHYSICS_PUBLICATION_RESULT"),
        ("physics-pacing-graphical",["--rendering-method","gl_compatibility","--audio-driver","Dummy","--script","res://tests/test_workbench_physics_pacing.gd"],600,"PHYSICS_PACING_RESULT"),
        ("material-tiles",["--headless","--audio-driver","Dummy","--script","res://tests/test_material_tile_publication.gd"],300,"MATERIAL_TILE_PUBLICATION:"),
        ("palette-compile-bounds",["--headless","--audio-driver","Dummy","--script","res://tests/test_palette_shader_compile_bounds.gd"],180,"PALETTE_COMPILE_BOUNDS_RESULT"),
        ("material-tiles-graphical",["--rendering-method","gl_compatibility","--audio-driver","Dummy","--script","res://tests/test_material_tile_publication.gd"],600,"MATERIAL_TILE_PUBLICATION:"),
        ("material-history-graphical",["--rendering-method","gl_compatibility","--audio-driver","Dummy","--script","res://tests/test_material_history_transaction.gd"],600,"MATERIAL_HISTORY_TRANSACTION:"),
        ("rapier-manual",["--headless","--script","res://tests/test_rapier_manual_step.gd"],180,"Rapier2D manual-step coupling fixture passed"),
        ("terrain-packet",["--headless","--script","res://tests/test_hard_surface_incremental_packet.gd"],180,"HARD_SURFACE_INCREMENTAL"),
        ("full-material-upload",["--headless","--audio-driver","Dummy","--script","res://tests/test_render_full_upload.gd"],180,"RENDER_FULL_UPLOAD:"),
        ("actor-integration",["--headless","--script","res://tests/test_physical_actor_integration.gd"],300,"Physical actor integration:"),
        ("native-world-clearance",["--headless","--script","res://tests/test_pr566_mask_coherent_native_world.gd"],240,"PR566_WORLD_CLEARANCE_RESULT"),
        ("cadence-contract-graphical",["--rendering-driver","opengl3_angle","--rendering-method","gl_compatibility",
         "--audio-driver","Dummy","--max-fps","60","--script","res://tests/test_render_cadence_contract.gd",
         "--","--render-cadence-evidence="+str((evidence/"cadence-contract").resolve())],300,"RENDER_CADENCE_CONTRACT_RESULT"),
        ("engine-lab-gui",["--rendering-method","gl_compatibility","--script","res://tests/test_workbench_engine_lab.gd"],180,"ENGINE_LAB_RESULT"),
        ("graphical",["--rendering-method","gl_compatibility","--quit-after","180","--","--workbench"],120,"Rapier2D")
    ]
    report=[]
    failures=[]
    for name,suffix,timeout,marker in cases:
        if "--headless" not in suffix and "--rendering-driver" not in suffix:
            suffix=["--rendering-driver","opengl3_angle",*suffix]
        cmd=[str(console),"--path",str(project),*suffix]
        print("COHERENCE_SMOKE_START",name,flush=True)
        env=os.environ.copy()
        env["CYBERSAND_SOURCE_REVISION"]=SOURCE
        env["CYBERSAND_DIAG_PRESENTATION"]="legacy" if name in {"production","crossfade","dense-budget","cadence-contract","cadence-contract-graphical"} else ""
        env["CYBERSAND_DIAG_RENDER_CADENCE"]=""
        env["CYBERSAND_DIAG_FLYER_POSE"]=""
        if name=="temporal-dense":
            env["CYBERSAND_TEMPORAL_DENSE_OUTPUT"]=str((evidence/"temporal-dense").resolve())
        if name in {"temporal-contact","temporal-contact-graphical"}:
            env["CYBERSAND_TEMPORAL_CONTACT_OUTPUT"]=str((evidence/name).resolve())
        if name.startswith("physics-pacing"):
            env["CYBERSAND_PHYSICS_PACING_OUTPUT"]=str((evidence/name).resolve())
        if name.startswith("physics-publication"):
            env["CYBERSAND_PHYSICS_PUBLICATION_OUTPUT"]=str((evidence/(name+".json")).resolve())
        if name.startswith("material-tiles"):
            env["CYBERSAND_MATERIAL_TILE_OUTPUT"]=str((evidence/(name+".json")).resolve())
        if name=="material-history-graphical":
            env["CYBERSAND_MATERIAL_HISTORY_OUTPUT"]=str((evidence/(name+".json")).resolve())
            env["CYBERSAND_DIAG_MATERIAL_HISTORY_TARGETS"]="2"
            env["CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS"]="3"
            env["CYBERSAND_DIAG_MATERIAL_COPY_MODE"]="runs"
        if name=="full-material-upload":
            env["CYBERSAND_FULL_UPLOAD_OUTPUT"]=str((evidence/name/"full-upload.json").resolve())
        group="paint-persistence" if name in {"paint-author","paint-reopen"} else name
        if name in {"architecture-author","architecture-reopen"}: group="architecture-persistence"
        if name in {"flatten-author","flatten-reopen"}: group="flatten-persistence"
        env["APPDATA"]=str((evidence/"userdata"/group).resolve())
        env["XDG_DATA_HOME"]=env["APPDATA"]
        if name in {"paint-author","paint-reopen"}:
            env["PAINT_REOPEN"]="1" if name=="paint-reopen" else ""
            env["PAINT_CAPTURE_DIR"]=str((evidence/name/"frames").resolve())
        if name.startswith("architecture-") and name!="architecture-contract":
            env["CYBERSAND_ARCHITECTURE_PHASE"]=name.removeprefix("architecture-")
            env["CYBERSAND_ARCHITECTURE_OUTPUT"]=str((evidence/"architecture").resolve())
            env["CYBERSAND_ARCHITECTURE_REQUIRE_GRAPHICS"]="0" if name=="architecture-native" else "1"
        if name.startswith("flatten-"):
            env["FLATTEN_SIDE"]="512";env["FLATTEN_WORKERS"]="1"
            env["FLATTEN_REOPEN"]="1" if name=="flatten-reopen" else "0"
        if name=="native-camera":
            env["CYBERSAND_TEST_ARTIFACT_DIR"]=str((evidence/"native-camera").resolve())
        if name=="engine-lab-gui":
            env["CYBERSAND_ENGINE_LAB_SCREENSHOT"]=str((evidence/"engine-lab-popup.png").resolve())
        file=evidence/(name+".log")
        try:
            r=subprocess.run(cmd,cwd=output,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                             timeout=timeout,text=True,errors="replace",env=env)
            file.write_text(r.stdout,encoding="utf-8")
            need(r.returncode==0 and "SCRIPT ERROR:" not in r.stdout and "SHADER ERROR:" not in r.stdout and
                 (marker is None or marker in r.stdout),"Installed "+name+" failed: "+r.stdout[-3500:])
            detail={}
            if name=="material-history-graphical":
                from run_camera_coherence_regressions import validate_material_history_receipt
                receipt=evidence/(name+".json")
                transaction=validate_material_history_receipt(json.loads(receipt.read_text(encoding="utf-8")),r.stdout)
                need("--headless" not in cmd and "opengl3_angle" in cmd and "ANGLE" in r.stdout,
                     "Installed material transaction did not execute the requested Windows ANGLE backend")
                detail={"command":cmd,"graphical":True,"material_history":transaction,
                        "receipt_sha256":digest(receipt),
                        "executed_files_sha256":{name:digest(project/name) for name in
                            ("scripts/main.gd","scripts/blit_material_publisher.gd","tests/test_material_history_transaction.gd")}}
            if name in {"paint-author","paint-reopen"}:
                completions=[line for line in r.stdout.splitlines() if line.startswith("PAINT_EDITOR_WORKBENCH ")]
                need(bool(completions),"Installed graphical PAINT completion missing")
                paint=json.loads(completions[-1].split(" ",1)[1])
                need(not paint["failures"] and paint["checks"]>0 and
                     paint["reopen"]==("1" if name=="paint-reopen" else ""),
                     "Installed graphical PAINT author/reopen phase did not complete")
                need("--headless" not in cmd and "opengl3_angle" in cmd and "ANGLE" in r.stdout,
                     "Installed PAINT pair did not execute the requested graphical Windows backend")
                frames=[]
                if name=="paint-author":
                    for label in ("paint001-mixed-stamp-preview","paint001-mounted-editor"):
                        frame=evidence/name/"frames"/(label+".png")
                        need(frame.is_file() and frame.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"),
                             "Installed PAINT framebuffer missing: "+label)
                        frames.append({"path":str(frame),"sha256":digest(frame)})
                detail={"command":cmd,"graphical":True,"paint_completion":paint,"framebuffers":frames,
                        "test_sha256":digest(project/"tests/test_paint_editor_workbench.gd")}
            if name=="full-material-upload":
                upload=json.loads((evidence/name/"full-upload.json").read_text())
                need(upload["source_sha"]==SOURCE and upload["failures"]==0 and upload["assertions"]>0,
                     "Installed full material upload source/assertions not verified")
                need(upload["main_sha256"]==digest(project/"scripts/main.gd") and
                     {row["channels"] for row in upload["measurements"]}=={1,2} and
                     all(row["side"]==2048 and len(row["samples"])==12 for row in upload["measurements"]),
                     "Installed full material upload did not cover exact R8/RG8 source and workload")
            if name.startswith("physics-pacing"):
                folder=evidence/name
                pacing=json.loads((folder/"physics-pacing.json").read_text())
                need(pacing.get("schema")=="workbench-physics-pacing-v1" and
                     not pacing["failures"] and pacing["checks"]>0 and len(pacing["phases"])==6,
                     "Installed production physics pacing did not complete all six phases")
                need(all(row["wait_native_sample"] and row["sample_wake"] for row in pacing["phases"]),
                     "Production pacing phases did not retain default native coupling")
                need(pacing["source_identity"]["source_sha"]==SOURCE and pacing["completed_steps"],
                     "Production pacing source/completed physics evidence missing")
                phase_map={row["label"]:row for row in pacing["phases"]}
                need(set(phase_map)=={"interactive-default-60","render-30-physics-120","fire-on-contact",
                                     "fire-off-flight","fire-off-recovery-contact","live-erasing-flight"},
                     "Installed production pacing phase identities missing or duplicated")
                recovery=phase_map["fire-off-recovery-contact"]
                need(recovery["required_contact_slot"]==0 and recovery["required_contact_observations"]>0 and
                     recovery["contact_recovery"]["reason"]=="contact" and recovery["completed_steps"]<=360,
                     "Selected Needle did not complete bounded physical contact recovery")
                live=[row["receipt"] for row in pacing["observations"] if row["label"]=="live-erasing-flight"]
                need(len(live)==1 and not live[0]["limit_reached"] and
                     48<=phase_map["live-erasing-flight"]["completed_steps"]<=90 and
                     [edit["footprint_cells"] for edit in live[0]["edits"]]==[13,1793] and
                     all(edit.get("publication") and len(edit.get("queue_receipts",[]))==1
                         for edit in live[0]["edits"]),
                     "Ordinary small/large live-erasing input, native progress and publication evidence missing")
                if name=="physics-pacing-graphical":
                    need(live[0].get("gpu_history_readback_after_phase"),
                         "Installed live erasing did not verify actual current/previous GPU history")
                need((folder/"physics-pacing-poses.jsonl").stat().st_size>0,
                     "Original production physics pacing trace missing")
            if name=="cadence-contract-graphical":
                folder=evidence/"cadence-contract"
                contract=json.loads((folder/"contract.json").read_text())
                need(not contract["failures"] and len(contract["observations"])==8,
                     "Graphical cadence contract did not complete all eight observations")
                need(len(list(folder.glob("*.png")))==8,"Missing eight original contract framebuffers")
                for row in contract["observations"]:
                    need(row["graphical"] and digest(row["capture_path"])==row["capture_sha256"],
                         "Graphical contract capture hash drift")
                for arm in ("legacy","repair"):
                    need((folder/(arm+"-poses.jsonl")).stat().st_size>0,"Missing original contract trace: "+arm)
            report.append({"name":name,"log_sha256":digest(file),"exit":r.returncode,"passed":True,**detail})
            print("COHERENCE_SMOKE_PASS",name,flush=True)
        except (RuntimeError,OSError,ValueError,subprocess.TimeoutExpired) as error:
            if isinstance(error,subprocess.TimeoutExpired):
                raw=error.stdout or b""
                file.write_text(raw.decode("utf-8","replace") if isinstance(raw,bytes) else raw,encoding="utf-8")
            failures.append({"name":name,"error":str(error)})
            report.append({"name":name,"passed":False,"error":str(error),
                           "log_sha256":digest(file) if file.exists() else None})
            print("COHERENCE_SMOKE_FAIL",name,str(error),flush=True)
        (evidence/"summary.json").write_text(json.dumps({
            "source_commit":SOURCE,"acceptance":"physical GPU pending","cases":report,
            "failures":failures,"complete":len(report)==len(cases) and not failures},indent=2)+"\n")
    need(not failures,"Installed application failed one or more required cases; see smoke summary")


def main():
    global SOURCE
    p=argparse.ArgumentParser()
    p.add_argument("command",choices=["preflight","build","verify","smoke"])
    p.add_argument("--source")
    p.add_argument("--platform",choices=["linux","windows"],default="windows")
    for name in ["native-stage","godot-zip","notices","vc","output","archive","evidence"]:
        p.add_argument("--"+name,type=Path)
    a=p.parse_args()
    if a.source: SOURCE=a.source
    if a.command=="preflight":
        print(json.dumps(preflight(a.platform),indent=2));return
    need(a.output is not None,"Output directory required")
    if a.command=="build":build(a)
    elif a.command=="verify":verify(a.output)
    else:
        need(a.evidence is not None,"Missing smoke evidence path")
        smoke(a.output,a.evidence)

if __name__=="__main__":main()
