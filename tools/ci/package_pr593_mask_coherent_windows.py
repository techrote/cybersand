#!/usr/bin/env python3
"""Build/verify a portable PR593 Windows *owner-playtest* ZIP.

Never relabel the existing PR566-qualified native DLL as newly compiled. Source
is archived from the exact PR593 commit; native inputs are checked byte-for-byte
against the original builder's attestation, and the original native provenance
is retained with its original build SHA. No production publish or merge.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tools"))
from package_explore001_candidate import stage_generator_profiles,stage_vc_runtime

SOURCE="27d98572ab6f4d69c578bd3f4b907291bfb7da06"
NATIVE_SOURCE="214de85adef2aaabc8e26de8612a3bf27cc1a081"
NATIVE="godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
RAPIER="godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
NATIVE_SHA="6c7811b78c12e34a68931f83f2fd505c20078c089bce245a9be8be6e02e6d04d"
RAPIER_SHA="b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7"
GODOT_SHA512=(
    "41645a908eb3181d6f2d1201ed7b6d6f095f6a23aaed8903d5d255277cc8d142814f3e"
    "6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9"
)
ENGINE_GUI="Godot_v4.7-stable_win64.exe"
ENGINE_CONSOLE="Godot_v4.7-stable_win64_console.exe"
VERSION="4.7.stable.official.5b4e0cb0f"
SCHEMA="cybersand-pr593-mask-coherent-windows-playtest-v1"
MANIFEST="candidate-manifest.json"
ARCHIVE_NAME="CyberSand-PR593-Mask-Coherent-Windows-"+SOURCE[:12]+".zip"


def sha(path:Path)->str:
    with path.open("rb") as f:
        h=hashlib.sha256()
        for chunk in iter(lambda:f.read(1024*1024),b""):
            h.update(chunk)
    return h.hexdigest()


def git(*args:str)->str:
    return subprocess.check_output(["git","-C",str(ROOT),*args],text=True,timeout=90).strip()


def assert_source_attestation(origin:Path)->tuple[dict,Path,str]:
    # This is an original source-built artifact on the accepted PR566 native
    # tree, NOT a freshly built DLL from PR593's newer GDScript/Docs tree.
    provenance=json.loads((origin/"runtime-provenance.json").read_text("utf-8"))
    binary=origin/Path(NATIVE).name
    if provenance.get("source_commit")!=NATIVE_SOURCE or provenance.get("build_commit")!=NATIVE_SOURCE:
        raise ValueError("Unqualified native source/build identity")
    if provenance.get("sha256")!=NATIVE_SHA or sha(binary)!=NATIVE_SHA or binary.stat().st_size!=provenance.get("size"):
        raise ValueError("Qualified PR566 Windows native DLL changed")
    if not binary.read_bytes()[:2]==b"MZ" or not provenance.get("source_inputs"):
        raise ValueError("Native PE / source inventory is missing")
    # In addition to native-source hashes, forbid any source difference
    # between the parent of the *rendered PR593 candidate* and packaged PR593.
    if git("rev-parse",SOURCE)!=SOURCE:
        raise ValueError("Source revision missing from checkout")
    if git("diff","--name-only",NATIVE_SOURCE,SOURCE,"--","native/include","native/src","godot/native_extension"):
        raise ValueError("PR593 changed the original qualified native source")
    tracked=provenance["source_inputs"]
    for relative,wanted in tracked.items():
        current=ROOT/relative
        if not current.is_file():
            raise ValueError("Qualified native source missing: "+relative)
        digest=hashlib.sha256(current.read_bytes().replace(b"\r\n",b"\n")).hexdigest()
        if digest!=wanted:
            raise ValueError("Native input diverges from qualified PR566 "+relative)
    if len(tracked)<80:
        raise ValueError("Unexpectedly small native source inventory")
    return provenance,binary,git("rev-parse",SOURCE+"^{tree}")


def check_godot_archive(path:Path)->tuple[bytes,str]:
    data=path.read_bytes()
    if hashlib.sha512(data).hexdigest()!=GODOT_SHA512:
        raise ValueError("Official Godot Windows 4.7 archive changed")
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        if z.testzip() is not None:
            raise ValueError("Official Godot archive corrupt")
        names={Path(x).name for x in z.namelist()}
        if {ENGINE_GUI,ENGINE_CONSOLE}!=names:
            raise ValueError("Unrecognized official Godot engine ZIP file inventory")
    return data,VERSION


def readme()->str:
    return (
        "CyberSand PR #593 — Windows 11 mask-coherent flyer GPU evaluation\n"
        "=================================================================\n\n"
        "This is a standalone TEST BUILD, not a release. #593 and #566 remain Draft/HOLD.\n"
        "Exact GDScript/source: "+SOURCE+"\n"
        "Native C++ DLL previously built and qualified from PR566: "+NATIVE_SOURCE+"\n"
        "Native DLL SHA-256: "+NATIVE_SHA+"\n"
        "Godot: "+VERSION+" / Rapier2D 0.35.2\n\n"
        "SETUP: Extract the ENTIRE ZIP into a short writable directory, e.g. C:\\CyberSand593.\n"
        "Double-click \"Open Workbench.cmd\". The first launch imports the project.\n"
        "Keep the two Godot executables, vc-runtime DLLs and godot folder together.\n\n"
        "TEST: Select Kestrel, begin a free flight, use W to thrust. Toggle \"Thruster fire\"\n"
        "ON for a short interval, then OFF. Watch for rapid double images/flicker.\n"
        "Repeat while flying quickly in Free camera and Follow selected. Try near Sand,\n"
        "Water and hard Walls. The guard intentionally reuses the uploaded pose\n"
        "whenever the swept area contains visible material, so some hold is possible.\n"
        "Use Restore start between reproducible trials. Test zoom, pan and display scaling.\n\n"
        "DIAGNOSTIC BASELINE (same ZIP): run \"Compare original mask pose.cmd\" instead.\n"
        "This sets CYBERSAND_DIAG_FLYER_POSE=mask only for that process.\n"
        "The ordinary Open Workbench.cmd uses the guarded repair by default.\n\n"
        "Report your GPU/driver, Windows DPI scale, refresh rate, VSync, zoom, World\n"
        "size, elapsed flight time and any problematic screenshot or short recording.\n"
        "Hosted CI graphics/physics PASS is NOT physical owner-GPU acceptance.\n"
        "See PLAYTEST.md and candidate-manifest.json for provenance.\n"
    )


def launcher(original:bool)->str:
    setting="set CYBERSAND_DIAG_FLYER_POSE=mask\n" if original else "set CYBERSAND_DIAG_FLYER_POSE=\n"
    return (
        "@echo off\nsetlocal\ncd /d \"%~dp0\"\n"+setting+
        "set CYBERSAND_SOURCE_REVISION="+SOURCE+"\n"
        "\"%~dp0"+ENGINE_CONSOLE+"\" --headless --path \"%~dp0godot\" --editor --quit\n"
        "if errorlevel 1 (echo CyberSand project import failed. & pause & exit /b 1)\n"
        "start \"\" \"%~dp0"+ENGINE_GUI+"\" --path \"%~dp0godot\" -- --workbench\n"
    ).replace("\n","\r\n")


def build(args)->Path:
    output=args.output.resolve()
    if output.exists(): raise ValueError("Refuse to overwrite a candidate directory")
    provenance,binary,source_tree=assert_source_attestation(args.origin)
    _,engine_version=check_godot_archive(args.godot_archive)
    rapier=ROOT/RAPIER
    if not rapier.is_file() or sha(rapier)!=RAPIER_SHA:
        raise ValueError("Pinned Git LFS Windows Rapier DLL missing/changed")
    # No mutable editor cache, platform-irrelevant compiled libraries or
    # arbitrary untracked files. Only bytes from the frozen source Git tree.
    names=("godot","examples/worldgen","THIRD_PARTY_NOTICES.md","LICENSE_STATUS.md",
           "docs/operations/native-pixel-scrolling.md",
           "docs/audits/2026-11-14-pr566-mask-coherent-presentation-qualification.md")
    payload=subprocess.check_output(["git","-C",str(ROOT),"archive","--format=tar",SOURCE,"--",*names],timeout=120)
    copied=0
    output.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(payload)) as archive:
        for member in archive:
            if not member.isfile():continue
            name=member.name
            if "/.godot/" in name or name.startswith("godot/.godot/"):
                continue
            if "/bin/" in name and name not in (NATIVE,RAPIER):
                continue
            data=archive.extractfile(member).read()
            if name==NATIVE:
                data=binary.read_bytes()
            elif name==RAPIER:
                data=rapier.read_bytes()
            elif data.startswith(b"version https://git-lfs.github.com/spec/v1"):
                raise ValueError("Unexpected unmaterialized LFS source "+name)
            target=output/name
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(data)
            copied+=1
    if not (output/NATIVE).is_file() or not (output/RAPIER).is_file():
        raise ValueError("Archive omitted required native addon / Rapier DLL")
    stage_generator_profiles(output)
    with zipfile.ZipFile(args.godot_archive) as z:
        for filename in (ENGINE_GUI,ENGINE_CONSOLE):
            (output/filename).write_bytes(z.read(filename))
    # Qualify the shipped executable, not merely the official archive metadata.
    version=subprocess.check_output([str(output/ENGINE_CONSOLE),"--version"],text=True,timeout=45).strip()
    if version!=engine_version:
        raise ValueError("Staged Godot executable is not exact pinned 4.7")
    for name in ("LICENSE.txt","COPYRIGHT.txt"):
        shutil.copyfile(args.notices/name,output/("Godot-"+name))
    vc_sha=stage_vc_runtime(args.vc_runtime,output)
    (output/"qualified-pr566-native-origin.json").write_text(
        json.dumps(provenance,sort_keys=True,indent=2)+"\n",encoding="utf-8")
    # Original retained binary provenance is *not* the delivered DLL's
    # provenance and should never be interpreted as such.
    old=output/"godot/addons/cybersand_native/runtime-provenance.json"
    if old.is_file():
        old.rename(old.with_name("retained-runtime-provenance.reference.json"))
    (output/"Open Workbench.cmd").write_bytes(launcher(False).encode("ascii"))
    (output/"Compare original mask pose.cmd").write_bytes(launcher(True).encode("ascii"))
    (output/"README.txt").write_text(readme(),encoding="utf-8")
    shutil.copyfile(output/"docs/audits/2026-11-14-pr566-mask-coherent-presentation-qualification.md",
                    output/"PLAYTEST.md")
    files={p.relative_to(output).as_posix():sha(p) for p in sorted(output.rglob("*")) if p.is_file()}
    if len(files)<500: raise ValueError("Incomplete Godot project package")
    attestation={
        "schema":SCHEMA,"purpose":"owner Windows GPU playtest; NOT a production release",
        "source_commit":SOURCE,"source_tree":source_tree,
        "parent_pr":566,"candidate_pr":593,
        "native_build_commit":NATIVE_SOURCE,"native_sha256":NATIVE_SHA,
        "native_inputs_verified":len(provenance["source_inputs"]),
        "native_origin_run":43537909868,
        "rapier_sha256":RAPIER_SHA,
        "godot_version":VERSION,"godot_zip_sha512":GODOT_SHA512,
        "vc_runtime_sha256":vc_sha,"files_sha256":files,
        "bundled_source_files":copied,
        "physical_owner_acceptance":"PENDING",
        "merge_status":"DRAFT HOLD (both PRs)",
    }
    (output/MANIFEST).write_text(json.dumps(attestation,sort_keys=True,indent=2)+"\n",encoding="utf-8")
    verify(output)
    print("PR593_PACKAGE_STAGE",json.dumps({"source":SOURCE,"source_tree":source_tree,
          "members":len(files)+1,"qualified_native":NATIVE_SHA,"path":str(output)}),flush=True)
    return output


def verify(output:Path)->dict:
    output=output.resolve()
    manifest=json.loads((output/MANIFEST).read_text("utf-8"))
    if manifest.get("schema")!=SCHEMA or manifest.get("source_commit")!=SOURCE or manifest.get("native_build_commit")!=NATIVE_SOURCE:
        raise ValueError("Delivered source/build identity mismatch")
    if manifest.get("native_sha256")!=NATIVE_SHA or manifest.get("rapier_sha256")!=RAPIER_SHA:
        raise ValueError("Native/Rapier provenance mismatch")
    for name,want in ((NATIVE,NATIVE_SHA),(RAPIER,RAPIER_SHA)):
        if sha(output/name)!=want:
            raise ValueError("Runtime differs from qualified source: "+name)
    expected=manifest["files_sha256"]
    actual={p.relative_to(output).as_posix():sha(p) for p in sorted(output.rglob("*")) if p.is_file() and p.name!=MANIFEST}
    if actual!=expected:
        missing=sorted(set(expected)-set(actual))
        extra=sorted(set(actual)-set(expected))
        changed=sorted(p for p in actual.keys() & expected.keys() if actual[p]!=expected[p])
        raise ValueError(f"Delivered file manifest mismatch: missing={missing[:4]} extra={extra[:4]} changed={changed[:4]}")
    for name,mask in (("Open Workbench.cmd",False),("Compare original mask pose.cmd",True)):
        if (output/name).read_bytes()!=launcher(mask).encode("ascii"):
            raise ValueError("Launcher is not exact supported command: "+name)
    print("PR593_PACKAGE_VERIFY",json.dumps({"status":"passed","source":SOURCE,
          "file_count":len(actual)+1,"runtime_sha256":NATIVE_SHA}),flush=True)
    return manifest


def archive_package(root:Path,destination:Path)->dict:
    verify(root)
    if destination.exists(): raise ValueError("No ZIP overwrite")
    allfiles=sorted(p for p in root.rglob("*") if p.is_file())
    names=[p.relative_to(root).as_posix() for p in allfiles]
    if not names or len({name.lower() for name in names})!=len(names):
        raise ValueError("ZIP collision/empty inventory")
    if max(len(name) for name in names)>210:
        raise ValueError("Archive exceeds portable Windows relative path limit")
    destination.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(destination,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=False) as z:
        for file,name in zip(allfiles,names):z.write(file,name)
    with zipfile.ZipFile(destination) as z:
        if z.testzip() is not None or set(z.namelist())!=set(names):
            raise ValueError("ZIP CRC/readback or member inventory mismatch")
    out={"schema":"cybersand-pr593-windows-zip-v1","source_commit":SOURCE,
         "native_build_commit":NATIVE_SOURCE,"native_sha256":NATIVE_SHA,
         "archive_name":destination.name,"archive_bytes":destination.stat().st_size,
         "archive_sha256":sha(destination),"members":len(names),
         "max_relative_path":max(len(x) for x in names)}
    (destination.parent/(destination.name+".sha256")).write_text(out["archive_sha256"]+"  "+destination.name+"\n",encoding="ascii")
    (destination.parent/(destination.name+".json")).write_text(json.dumps(out,indent=2)+"\n",encoding="utf-8")
    print("PR593_PACKAGE_ZIP",json.dumps(out),flush=True)
    return out


def main()->None:
    p=argparse.ArgumentParser()
    p.add_argument("action",choices=["build","verify","zip"])
    p.add_argument("--origin",type=Path)
    p.add_argument("--godot-archive",type=Path)
    p.add_argument("--notices",type=Path)
    p.add_argument("--vc-runtime",type=Path)
    p.add_argument("--output",required=True,type=Path)
    p.add_argument("--archive",type=Path)
    args=p.parse_args()
    if args.action=="build":
        if any(x is None for x in (args.origin,args.godot_archive,args.notices,args.vc_runtime)):
            p.error("build requires qualified native origin, official Godot and verified VC notices/runtime")
        build(args)
    elif args.action=="verify":
        verify(args.output)
    else:
        if args.archive is None:p.error("zip requires --archive")
        archive_package(args.output,args.archive)

if __name__=="__main__":main()
