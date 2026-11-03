#!/usr/bin/env python3
"""Run and independently read back source-pinned PACE004 original process evidence.

Windows/Linux headless: all five rigs with one/Auto workers plus two pressure
policy pairs. Both graphical hosts: Acrobat/Jetbarrel one/Auto plus Jetbarrel pressure.
Graphical failure never changes the separate headless evidence into graphics.
"""
from __future__ import annotations

import argparse
import base64
import math
import ast
import ntpath
import posixpath
from collections import Counter
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import tarfile
import time
import uuid
import zipfile

from pace004_contract import RIGS, extract, require, verify_result, verify_visual
import pace004_load_contract as load_contract
import pace004_execution as execution

ROOT=Path(__file__).resolve().parents[2]
HISTORICAL_BASE="0bf28d5760aed989a79386de03ef4fc6171fef42"
HISTORICAL_SOURCE="0744d267d1c37e4fc0b648e9f58e29ed3bec0c47"
HISTORICAL_RUN=41192641443
VERSION="4.7.stable.official.5b4e0cb0f"
WORKFLOW=".github/workflows/play-pace004.yml"
SCOPES=("godot","native","third_party","tools/ci","tools/play",".github/workflows")
PACE_INPUTS={WORKFLOW,
    "godot/tests/play_pace004_input_tape.gd","godot/tests/play_pace004_worker_probe.gd",
    "godot/tests/play_pace004_brush_load.gd","godot/tests/play_pace004_capture_buffer.gd",
    "godot/tests/test_play_pace004_capture_buffer.gd",
    "tools/play/pace004_contract.py","tools/play/pace004_load_contract.py",
    "tools/play/pace004_execution.py","tools/play/run_pace004_campaign.py",
    "tools/play/test_pace004_contract.py","tools/play/test_pace004_load_contract.py",
    "tools/play/test_pace004_execution.py"}
PALETTE="godot/shaders/material_palette.gdshader"
BOUNDED_PREFIX=b"#define CYBER_BOUNDED_CROSSFADE\n"
FIXTURE="godot/tests/play_pace004_input_tape.gd"
PROBE="godot/tests/play_pace004_worker_probe.gd"


def sha(path: Path) -> str:
    execution.operation_remaining()
    result = hashlib.sha256(path.read_bytes()).hexdigest()
    execution.operation_remaining()
    return result


def write(path: Path,value: object) -> None:
    path.write_text(json.dumps(value,indent=2,sort_keys=True,allow_nan=False)+"\n",encoding="utf-8")


def git(*args: str) -> bytes:
    return subprocess.check_output(["git","-C",str(ROOT),*args],timeout=execution.operation_remaining())


def plan(graphical: bool) -> list[tuple[str,int,int]]:
    rigs=("acrobat","jetbarrel") if graphical else RIGS
    rows=[(rig,workers,0) for rig in rigs for workers in (1,0)]
    rows += [(rig,workers,2) for rig in (("jetbarrel",) if graphical else ("acrobat","jetbarrel")) for workers in (1,0)]
    return rows


def case_plan(graphical: bool, active_workload: bool) -> list[tuple[str,int,int,str]]:
    require(not graphical or not active_workload,"Active brush workload is headless only")
    return load_contract.plan() if active_workload else [(*row,"none") for row in plan(graphical)]


def safe_file(root: Path,name: str) -> Path:
    execution.operation_remaining()
    require(type(name) is str and name and not name.startswith(("/","\\"))
            and "\\" not in name and ":" not in name and ".." not in Path(name).parts,"Unsafe evidence path")
    path=root/name
    cursor=root
    require(not cursor.is_symlink(),"Unsafe evidence directory")
    for part in Path(name).parts:
        cursor/=part
        require(not cursor.is_symlink(),"Unsafe evidence path component: "+name)
    require(path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(root.resolve()),
            "Missing/unsafe evidence file: "+name)
    return path


def verify_process(process: dict,limit: int,graphical: bool=False) -> None:
    require(process.get("status")=="passed" and type(process.get("returncode")) is int and process["returncode"]==0,
            "Original process did not pass")
    require(execution._same(process.get("timeout_seconds"),limit)
            and type(process.get("seconds")) in (int,float) and math.isfinite(process["seconds"])
            and 0<=process["seconds"]<=limit,
            "Wrong or exceeded original process deadline")
    require(process.get("requires_display") is graphical,"Process display scope mismatch")
    require(execution._same(process.get("execution_policy"),execution.policy.identity())
            and process.get("natural_completion") is True,"Process policy/natural completion mismatch")
    require(not any(process.get(k) for k in ("diagnostic_error","launch_error","capture_error","skip_messages","timeout_kind","timeout_diagnostic_error")),
            "Original process contains error/timeout/skip")


def case_flags(rig: str,workers: int,policy: int,workload: str,graphical: bool,platform_name: str) -> tuple:
    driver="opengl3_angle" if graphical and platform_name=="win32" else "opengl3"
    return ("--rendering-driver",driver,"--script","res://tests/play_pace004_input_tape.gd","--",
            f"--rig={rig}",f"--workers={workers}",f"--policy={policy}",f"--workload={workload}")


def verify_command(process: dict,flags: tuple,graphical: bool,platform_name: str,host_paths: tuple|None=None) -> tuple:
    import run_godot_regressions as runner
    require(platform_name in ("linux","win32"),"Unregistered process command platform")
    command=process.get("command")
    require(isinstance(command,list) and all(type(part) is str and part for part in command)
            and command.count("--path")==1,"Wrong original process command")
    index=command.index("--path")+1
    require(index<len(command),"Missing original project path")
    paths=(command[0],command[index]); path_module=ntpath if platform_name=="win32" else posixpath
    engine="Godot_v4.7-stable_win64_console.exe" if platform_name=="win32" else "Godot_v4.7-stable_linux.x86_64"
    require(all(path_module.isabs(path) and ".." not in path.replace("\\","/").split("/") for path in paths)
            and path_module.basename(paths[0])==engine and path_module.basename(paths[1])=="godot",
            "Original process engine/project path differs")
    require(host_paths is None or paths==host_paths,"Original process host paths changed")
    expected=runner.case_command(paths[0],runner.Case("pace004",flags,1,0,graphical),platform_name)
    expected[expected.index("--path")+1]=paths[1]
    require(command==expected,"Original process command differs from registered source/configuration")
    return paths


def git_object(kind: bytes,data: bytes) -> str:
    return hashlib.sha1(kind+b" "+str(len(data)).encode()+b"\0"+data).hexdigest()


def tree_identity(entries: dict[str,tuple[str,str,str]]) -> str:
    root={}
    for path,(mode,kind,oid) in entries.items():
        parts=path.split("/");node=root
        require(all(p not in ("",".","..") for p in parts),"Unsafe archived tree path")
        for part in parts[:-1]:
            require(part not in node or isinstance(node[part],dict),"Overlapping archived tree paths")
            node=node.setdefault(part,{})
        require(parts[-1] not in node,"Duplicate archived tree path")
        node[parts[-1]]=(mode,kind,oid)
    def reduce(node):
        content=[]
        for name,value in sorted(node.items(),key=lambda item:(item[0]+("/" if isinstance(item[1],dict) else "")).encode()):
            mode,oid=("40000",reduce(value)) if isinstance(value,dict) else (value[0],value[2])
            content.append(mode.encode()+b" "+name.encode()+b"\0"+bytes.fromhex(oid))
        return git_object(b"tree",b"".join(content))
    return reduce(root)


def selected_runtimes(platform_name: str) -> set[str]:
    require(platform_name in ("linux","win32"),"Unregistered runtime platform")
    if platform_name=="win32":
        return {"godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
                "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"}
    return {"godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
            "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"}


def canonical_archive_blob(name: str,data: bytes,attributes: bytes) -> bytes:
    # Git archive exports the two explicit committed CRLF attributes. Invert
    # only those rules after the caller authenticates .gitattributes itself.
    # Unknown paths and implicit/global conversion must remain byte-exact.
    suffix=Path(name).suffix
    if suffix in (".bat",".ps1"):
        rule=[("*"+suffix).encode(),b"text",b"eol=crlf"]
        if any(line.split()==rule for line in attributes.splitlines()):
            return data.replace(b"\r\n",b"\n")
    return data


def publish_source_archive(output: Path,source: str) -> str:
    destination=output/"executed-source.tar"
    require(not destination.exists(),"Refusing to replace an original source archive")
    pending=output/("executed-source-"+uuid.uuid4().hex+".tar.pending")
    with pending.open("xb") as handle:
        subprocess.run(["git","-c","core.autocrlf=false","-c","core.eol=lf","archive","--format=tar",source],
                       cwd=ROOT,stdout=handle,check=True,timeout=execution.operation_remaining(),
                       env=os.environ|{"GIT_LFS_SKIP_SMUDGE":"1"})
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(pending,destination)
    (output/"executed-commit.txt").write_bytes(git("cat-file","commit",source))
    (output/"executed-tree.bin").write_bytes(git("ls-tree","-r","-z",source))
    return sha(destination)


def verify_source_archive(output: Path,report: dict) -> dict:
    source=safe_file(output,"executed-source.tar")
    require(sha(source)==report["executed_source_archive_sha256"],"Source archive digest changed")
    commit=safe_file(output,"executed-commit.txt").read_bytes()
    require(git_object(b"commit",commit)==report["source_commit"],"Original commit object differs from source SHA")
    first=commit.splitlines()[0]
    require(re.fullmatch(rb"tree [0-9a-f]{40}",first) is not None
            and first[5:].decode()==report["source_tree"],"Reported source tree differs from original commit")
    raw_tree=safe_file(output,"executed-tree.bin").read_bytes()
    require(raw_tree.endswith(b"\0"),"Incomplete original tree inventory")
    entries={}
    for raw in raw_tree[:-1].split(b"\0"):
        header,path=raw.split(b"\t",1);mode,kind,oid=header.decode().split(" ");name=path.decode()
        require(mode in ("100644","100755","120000","160000")
                and kind==("commit" if mode=="160000" else "blob")
                and re.fullmatch(r"[0-9a-f]{40}",oid) is not None and name not in entries,
                "Invalid original tree entry")
        entries[name]=(mode,kind,oid)
    require(tree_identity(entries)==report["source_tree"],"Original tree inventory does not match committed tree")
    with tarfile.open(source,"r:") as archive:
        require(archive.pax_headers.get("comment")==report["source_commit"],"Git archive source commit mismatch")
        blobs=[m for m in archive.getmembers() if m.isfile() or m.issym()]
        members={m.name:m for m in blobs}
        require(len(members)==len(blobs) and set(members)=={name for name,entry in entries.items() if entry[1]=="blob"},
                "Archive is missing or duplicating committed blobs")
        require({name for name in members if Path(name).name==".gitattributes"}=={".gitattributes"},
                "Archive attribute policy requires independent review")
        attributes=archive.extractfile(members[".gitattributes"]).read()
        require(git_object(b"blob",attributes)==entries[".gitattributes"][2],"Archive attributes differ from committed blob")
        for name,member in members.items():
            mode,_,oid=entries[name]
            require(member.issym()==(mode=="120000")
                    and (member.issym() or bool(member.mode&0o111)==(mode=="100755")),"Archived file mode differs from committed tree")
            data=member.linkname.encode() if member.issym() else archive.extractfile(member).read()
            canonical=data if member.issym() else canonical_archive_blob(name,data,attributes)
            require(git_object(b"blob",canonical)==oid,"Archived blob differs from committed tree: "+name)
        inputs=report["execution_inputs"]
        expected={name for name in members if any(name==scope or name.startswith(scope+"/") for scope in SCOPES)
                  and not name.startswith("godot/.godot/")}
        require(set(inputs)==expected and FIXTURE in inputs and PROBE in inputs,
                "Execution source inventory differs from complete committed scopes")
        require(set(report["runtimes"])==selected_runtimes(report["platform"]),"Incomplete selected runtime inventory")
        normalized=set(report["normalized_import_descriptors"])
        require(normalized=={
            "godot/addons/godot-rapier2d/Radial2D.svg.import",
            "godot/addons/godot-rapier2d/icons/Fluid2D.svg.import",
            "godot/addons/godot-rapier2d/icons/StateManager2D.svg.import",
            "godot/addons/godot-rapier2d/logo_square_2d.png.import"},"Source normalization rule changed")
        for name,expected in inputs.items():
            data=archive.extractfile(members[name]).read()
            if name in report["runtimes"]:
                runtime=report["runtimes"][name]
                pointer=re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n",data)
                require(pointer is not None and data.decode()==runtime["pointer"]
                        and expected==runtime["sha256"]==pointer[1].decode()
                        and type(runtime["bytes"]) is int and runtime["bytes"]==int(pointer[2]),
                        "Archived/runtime LFS identity mismatch")
                continue
            if name in normalized:data=data.replace(b"\r\n",b"\n")
            require(hashlib.sha256(data).hexdigest()==expected,"Executed/archive source differs: "+name)
        def original(name):
            require(name in members,"Missing original provenance source: "+name)
            return archive.extractfile(members[name]).read()
        platform_name="windows" if report["platform"]=="win32" else "linux"
        suffix=".json" if platform_name=="windows" else ".linux.json"
        native=json.loads(original("godot/addons/cybersand_native/runtime-provenance"+suffix))
        require(native==report.get("native_provenance"),"Reported native provenance differs from committed manifest")
        source_suffixes={".c",".cc",".cpp",".cxx",".h",".hh",".hpp",".hxx",".inc",".inl",".tpp"}
        native_paths={name for name in members if any(name.startswith(prefix+"/") for prefix in
            ("native/include","native/src","godot/native_extension")) and Path(name).suffix in source_suffixes}
        require(native_paths and set(native["source_inputs"])==native_paths,"Native provenance omits compiled source")
        rapier=json.loads(original("godot/addons/godot-rapier2d/runtime-provenance."+platform_name+".json"))
        for provenance in (native,rapier):
            runtime=report["runtimes"].get(provenance.get("artifact"),{})
            require(runtime.get("sha256")==provenance.get("sha256") and runtime.get("bytes")==provenance.get("size"),
                    "Runtime payload differs from committed build provenance")
            require(provenance.get("source_inputs"),"Missing runtime build source inventory")
            for name,digest in provenance["source_inputs"].items():
                require(hashlib.sha256(original(name).replace(b"\r\n",b"\n")).hexdigest()==digest,
                        "Runtime build source differs from executed commit: "+name)
        identity=report["godot_identity"]
        if platform_name=="linux":
            lock=json.loads(original("third_party/godot-runtime.lock.json"))
            require(identity.get("archive_sha256")==lock["editor"]["sha256"]
                    and identity.get("version")==lock["godot_version"],"Engine archive differs from committed pin")
        else:
            definitions=ast.parse(original("tools/ci/run_windows_godot_regressions.py"))
            pinned=next(ast.literal_eval(node.value) for node in definitions.body if isinstance(node,ast.Assign)
                        and any(isinstance(target,ast.Name) and target.id=="GODOT_SHA512" for target in node.targets))
            require(identity.get("archive_sha512")==pinned,"Engine archive differs from committed pin")

    return entries



def protected_source(entries: dict) -> dict:
    return {name:entry for name,entry in entries.items()
            if any(name==scope or name.startswith(scope+"/") for scope in SCOPES)
            and name not in PACE_INPUTS and not name.startswith("godot/.godot/")}


def read_tree_inventory(raw: bytes, expected: str) -> dict:
    require(raw.endswith(b"\0"), "Incomplete baseline tree inventory")
    entries={}
    for row in raw[:-1].split(b"\0"):
        header,path=row.split(b"\t",1);mode,kind,oid=header.decode().split(" ");name=path.decode()
        require(name not in entries and mode in ("100644","100755","120000","160000")
                and kind==("commit" if mode=="160000" else "blob")
                and re.fullmatch(r"[0-9a-f]{40}",oid) is not None, "Invalid baseline tree inventory")
        entries[name]=(mode,kind,oid)
    require(tree_identity(entries)==expected,"Baseline tree inventory differs from authenticated commit")
    return entries


def publish_baseline(output: Path, source: str, baseline: str) -> dict:
    require(re.fullmatch(r"[0-9a-f]{40}",baseline) is not None,"Baseline must be an independently supplied exact commit")
    git("merge-base","--is-ancestor",baseline,source)
    raw=git("cat-file","commit",baseline)
    tree=git("rev-parse",baseline+"^{tree}").decode().strip()
    (output/"baseline-commit.txt").write_bytes(raw)
    (output/"baseline-tree.bin").write_bytes(git("ls-tree","-r","-z",baseline))
    path=git("rev-list","--ancestry-path",baseline+".."+source).decode().splitlines()
    require(len(path)<=10000,"Baseline ancestry evidence capacity exceeded")
    commits={commit:base64.b64encode(git("cat-file","commit",commit)).decode() for commit in {*path,baseline,source}}
    write(output/"source-ancestry.json",commits)
    return {"schema":"play-pace004-source-baseline-v2","commit":baseline,"tree":tree,
            "protected_scopes":list(SCOPES),"apparatus_paths":sorted(PACE_INPUTS),
            "historical_base":HISTORICAL_BASE,"historical_source":HISTORICAL_SOURCE,
            "historical_run":HISTORICAL_RUN,"historical_results_are_separate":True}


def verify_baseline(output: Path, report: dict, executed: dict, expected: str|None=None) -> None:
    basis=report.get("source_baseline",{})
    baseline=basis.get("commit","")
    require(re.fullmatch(r"[0-9a-f]{40}",baseline) is not None
            and (expected is None or baseline==expected),"Unexpected independently supplied source baseline")
    require(basis=={"schema":"play-pace004-source-baseline-v2","commit":baseline,"tree":basis.get("tree"),
            "protected_scopes":list(SCOPES),"apparatus_paths":sorted(PACE_INPUTS),
            "historical_base":HISTORICAL_BASE,"historical_source":HISTORICAL_SOURCE,
            "historical_run":HISTORICAL_RUN,"historical_results_are_separate":True},"Baseline source scope changed")
    raw=safe_file(output,"baseline-commit.txt").read_bytes()
    require(git_object(b"commit",raw)==baseline and raw.splitlines()[0]==b"tree "+basis["tree"].encode(),
            "Baseline commit/tree authentication failed")
    previous=read_tree_inventory(safe_file(output,"baseline-tree.bin").read_bytes(),basis["tree"])
    require(protected_source(previous)==protected_source(executed),
            "Production/runner/policy inputs differ from accepted baseline")
    encoded=json.loads(safe_file(output,"source-ancestry.json").read_text())
    require(type(encoded) is dict and 1<=len(encoded)<=10002,"Missing bounded ancestry inventory")
    commits={name:base64.b64decode(value,validate=True) for name,value in encoded.items()}
    require(all(git_object(b"commit",value)==name for name,value in commits.items()),"Ancestry commit authentication failed")
    require(commits.get(baseline)==raw and commits.get(report["source_commit"])==safe_file(output,"executed-commit.txt").read_bytes(),
            "Ancestry endpoints differ from original commits")
    pending=[report["source_commit"]];seen=set()
    while pending:
        current=pending.pop()
        if current==baseline:break
        if current in seen:continue
        seen.add(current)
        pending.extend(line[7:].decode() for line in commits.get(current,b"").split(b"\n\n",1)[0].splitlines()
                       if re.fullmatch(rb"parent [0-9a-f]{40}",line) and line[7:].decode() in commits)
    else:
        raise ValueError("Accepted baseline is not an authenticated source ancestor")


def verify_successor_inputs(output: Path, report: dict) -> None:
    require(execution._same(report.get("execution_policy"),execution.policy.identity()),"Campaign execution policy differs from source")
    with tarfile.open(safe_file(output,"executed-source.tar"),"r:") as archive:
        policy_bytes=archive.extractfile("godot/tests/support/ci_execution_policy.json").read()
        require(hashlib.sha256(policy_bytes).hexdigest()==report["execution_policy"]["sha256"],
                "Execution policy differs from authenticated source")
        code=archive.extractfile(PALETTE).read()
    expected={"full_crossfade":hashlib.sha256(code).hexdigest(),
              "angle_bounded_crossfade":hashlib.sha256(BOUNDED_PREFIX+code).hexdigest()}
    require(report.get("palette_shader_inputs")==expected,"Palette variant identity differs from authenticated source")


def selected_plan(graphical: bool, active: bool, index: int, count: int) -> list:
    require(type(count) is int and count>=1 and type(index) is int and 0<=index<count,"Invalid exact campaign shard")
    rows=case_plan(graphical,active)
    require(count<=len(rows),"Empty PACE004 shards are not registered")
    return [row for ordinal,row in enumerate(rows) if ordinal%count==index]


def hosted_plan() -> dict:
    matrix=[]
    # Keep two cases together at the registered scale. An explicitly larger
    # execution allowance may require one case per hosted job; never shorten a
    # case or scientific input to fit the platform's parent ceiling.
    per_shard=2
    try:
        execution.budgets(per_shard)
    except ValueError:
        per_shard=1
        execution.budgets(per_shard)
    for platform_name,runner_os in (("linux","ubuntu-24.04"),("win32","windows-2022")):
        for mode,graphical,active in (("ordinary",False,False),("active",False,True),("graphical",True,False)):
            rows=case_plan(graphical,active)
            count=math.ceil(len(rows)/per_shard)
            for index in range(count):
                cases=selected_plan(graphical,active,index,count)
                budget=execution.budgets(len(cases))
                matrix.append({"platform":platform_name,"os":runner_os,"mode":mode,"graphical":graphical,
                    "active":active,"shard_index":index,"shard_count":count,"case_count":len(cases),
                    "job_minutes":budget["job_minutes"],"suite_minutes":budget["suite_minutes"],
                    "dependency_minutes":budget["dependency_stage_minutes"],
                    "readback_minutes":budget["readback_minutes"]})
    return {"include":matrix, "inventory":execution.inventory_budgets(len(matrix))}


@execution.bounded_operation
def verify_directory(output: Path,*,sealed: bool=True,baseline_source: str|None=None) -> dict:
    if sealed:
        inventory=json.loads(safe_file(output,"manifest.json").read_text())
        actual={p.relative_to(output).as_posix() for p in output.rglob("*") if p.is_file() and p.name!="manifest.json"}
        require(actual==set(inventory["files"]),"Original artifact inventory changed")
        for name,record in inventory["files"].items():
            path=safe_file(output,name)
            require(path.stat().st_size==record["bytes"] and sha(path)==record["sha256"],"Original evidence digest changed: "+name)
    report=json.loads(safe_file(output,"campaign.json").read_text())
    require(report.get("schema")=="play-pace004-campaign-v2" and report.get("completed") is True
            and report.get("errors")==[],"Campaign incomplete/failed")
    require(report.get("source_unchanged") is True and report.get("runtimes_unchanged") is True
            and report.get("production_inputs_unchanged_from_baseline") is True,"Source/runtime postflight failed")
    require(report.get("godot_identity",{}).get("version")==VERSION,"Wrong Godot engine")
    graphical=report.get("graphical")
    require(type(graphical) is bool and report.get("platform") in ("linux","win32"),"Unregistered platform scope")
    active_workload=report.get("active_workload",False)
    require(type(active_workload) is bool,"Unregistered active workload campaign scope")
    shard=report.get("shard",{})
    expected=selected_plan(graphical,active_workload,shard.get("index"),shard.get("count"))
    require(report.get("registered_case_plan")==[list(row) for row in case_plan(graphical,active_workload)],
            "Complete registered configuration inventory changed")
    observed=[(row.get("rig"),row.get("workers"),row.get("policy"),row.get("workload","none")) for row in report["rows"]]
    require(Counter(observed)==Counter(expected) and len(observed)==len(expected),"Incomplete/duplicate rig-worker-policy inventory")
    registered=[list(row) for row in expected]
    require(report.get("case_plan")==registered,"Registered case plan changed")
    entries=verify_source_archive(output,report)
    verify_baseline(output,report,entries,baseline_source)
    verify_successor_inputs(output,report)
    verify_process(report["import"],execution.policy.watchdog_seconds("godot_import_seconds"))
    host_paths=verify_command(report["import"],("--editor","--quit"),False,report["platform"])
    require(sha(safe_file(output,report["import"]["log"]))==report["import_log_sha256"],"Import log changed")
    summaries=[]
    for row in report["rows"]:
        directory=output/row["directory"]
        require(directory.resolve().is_relative_to(output.resolve()),"Unsafe case directory")
        process=json.loads(safe_file(directory,"process.json").read_text())
        require(process==row["process"],"Original process receipt changed")
        verify_process(process,execution.case_seconds(graphical),graphical)
        verify_command(process,case_flags(row["rig"],row["workers"],row["policy"],row.get("workload","none"),graphical,report["platform"]),
                       graphical,report["platform"],host_paths)
        require(type(row["observed_total_seconds"]) in (int,float) and math.isfinite(row["observed_total_seconds"])
                and 0<=row["observed_total_seconds"]<=execution.case_observation_seconds(graphical),"Late/invalid observed process completion")
        log=safe_file(directory,process["log"])
        require(sha(log)==row["log_sha256"],"Original process log changed")
        result=extract(log.read_text(encoding="utf-8"))
        require(result==row["result"],"Campaign result differs from original engine output")
        require(result.get("process_nonce")==row["process_nonce"]
                and re.fullmatch(r"[0-9a-f]{32}",row["process_nonce"]) is not None,"Wrong process nonce")
        require(result.get("fixture_sha256")==report["execution_inputs"][FIXTURE]
                and result.get("probe_sha256")==report["execution_inputs"][PROBE],"Engine executed mismatched fixture/probe")
        require(type(result.get("process_id")) is int and result["process_id"]>0,"Missing actual engine PID")
        if report["platform"]=="linux":require(result["process_id"]==process["pid"],"Mismatched actual Linux process")
        expected_engine=report["godot_identity"]["runtime_sha256" if report["platform"]=="win32" else "binary_sha256"]
        require(result.get("engine_sha256")==expected_engine,"Actual process executable differs from prepared engine")
        cleanup=json.loads(safe_file(directory,"cleanup.json").read_text())
        require(cleanup==row.get("cleanup"),"Original cleanup receipt changed")
        execution.verify_cleanup(cleanup,process,result,report["source_commit"],row["process_nonce"],
                                 report["execution_inputs"][FIXTURE],report["execution_inputs"][PROBE],expected_engine)
        require(result["palette_shader"]["source_sha256"]==report["palette_shader_inputs"]["full_crossfade"]
                and result["palette_shader"]["source_file_sha256"]==report["palette_shader_inputs"]["full_crossfade"]
                and result["palette_shader"]["variant_sha256"]==report["palette_shader_inputs"][result["palette_shader"]["variant"]],
                "Executed palette bytes differ from authenticated source variant")
        summary=verify_result(result,row["rig"],row["workers"],row["policy"],report["source_commit"],graphical,report["platform"])
        summary["visual"]=verify_visual(result,directory)
        if active_workload:
            summary["workload"]=load_contract.verify_workload(result,row["workload"],report["execution_inputs"][load_contract.HELPER])
        else:
            require(result.get("workload",{"mode":"none"})=={"mode":"none"},"Unregistered workload in original campaign")
        require(summary==row["summary"],"Independent reduction differs from campaign summary")
        summaries.append(summary)
    return {"status":"passed","source_commit":report["source_commit"],"source_tree":report["source_tree"],
            "platform":report["platform"],"graphical":graphical,"active_workload":active_workload,"case_count":len(summaries),"rows":summaries,
            "shard":report["shard"],"source_baseline":report["source_baseline"],"execution_policy":report["execution_policy"],
            "qualification":"PACE004 scoped real host/input evidence; no physical devices, scanout FPS, human feel or shader qualification"}



def verify_suite(root: Path, source: str, baseline: str) -> dict:
    expected={(row["platform"],row["graphical"],row["active"],row["shard_index"],row["shard_count"])
              for row in hosted_plan()["include"]}
    observed={};totals={"linux":{"headless":0,"graphical":0},"win32":{"headless":0,"graphical":0}}
    for path in sorted(root.rglob("campaign.json")):
        reduced=verify_directory(path.parent,baseline_source=baseline)
        require(reduced["source_commit"]==source,"Suite mixes source revisions")
        key=(reduced["platform"],reduced["graphical"],reduced["active_workload"],
             reduced["shard"]["index"],reduced["shard"]["count"])
        require(key in expected and key not in observed,"Unexpected/duplicate campaign shard")
        observed[key]=reduced
        totals[key[0]]["graphical" if key[1] else "headless"]+=reduced["case_count"]
    require(set(observed)==expected,"Missing registered campaign shards")
    require(totals=={"linux":{"headless":30,"graphical":6},"win32":{"headless":30,"graphical":6}},
            "Complete registered PACE004 inventory differs")
    return {"schema":"play-pace004-suite-v2","status":"passed","source_commit":source,
            "baseline_source":baseline,"shards":len(observed),"cases":sum(sum(v.values()) for v in totals.values()),
            "inventory":totals,"scope":"Current and pressure; one and Auto; active and idle; no sync-reference arm"}


@execution.bounded_operation
def seal(output: Path,source: str|None) -> None:
    files={p.relative_to(output).as_posix():{"bytes":p.stat().st_size,"sha256":sha(p)}
           for p in sorted(output.rglob("*")) if p.is_file() and p.name!="manifest.json"}
    write(output/"manifest.json",{"source_commit":source,"files":files})


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot-archive",type=Path)
    parser.add_argument("--expected-source-sha")
    parser.add_argument("--output",type=Path)
    parser.add_argument("--baseline-source",help="Exact accepted timeout/shader baseline commit, independently supplied")
    parser.add_argument("--shard-index",type=int,default=0)
    parser.add_argument("--shard-count",type=int,default=1)
    parser.add_argument("--plan-json",action="store_true")
    parser.add_argument("--verify-suite",action="store_true")
    parser.add_argument("--graphical",action="store_true")
    parser.add_argument("--active-workload",action="store_true",
                        help="Run16 paired active/no-load headless cases; original14-case and graphical cohorts remain separate")
    parser.add_argument("--verify-only",action="store_true")
    args=parser.parse_args()
    if args.plan_json:
        print(json.dumps(hosted_plan(),separators=(",",":")))
        return 0
    require(args.output is not None and args.baseline_source is not None,"PACE004 requires output and an independently supplied baseline")
    output=args.output.resolve()
    if args.verify_suite:
        require(args.expected_source_sha is not None,"Suite readback requires an independently expected source")
        print(json.dumps(verify_suite(output,args.expected_source_sha,args.baseline_source),sort_keys=True))
        return 0
    if args.verify_only:
        summary=verify_directory(output,baseline_source=args.baseline_source)
        require(args.expected_source_sha is None or summary["source_commit"]==args.expected_source_sha,
                "Artifact source differs from independently expected commit")
        print(json.dumps({k:v for k,v in summary.items() if k!="rows"},sort_keys=True))
        return 0
    require(args.godot_archive is not None and args.expected_source_sha is not None,"Execution requires archive and exact source")
    require(not args.graphical or not args.active_workload,"Active brush workload is headless only")
    output.mkdir(parents=True,exist_ok=False)
    sys.path.insert(0,str(ROOT/"tools/ci"))
    import run_godot_regressions as runner
    import run_windows_godot_regressions as windows
    from check_repository import verify_runtime,verify_rapier_overrides
    report={"schema":"play-pace004-campaign-v2","status":"failed","completed":False,
        "source_commit":None,"source_baseline":{},"platform":sys.platform,"host":platform.platform(),
        "execution_policy":execution.policy.identity(),"shard":{"index":args.shard_index,"count":args.shard_count},
        "python":sys.version,"graphical":args.graphical,"active_workload":args.active_workload,
        "case_plan":[list(row) for row in selected_plan(args.graphical,args.active_workload,args.shard_index,args.shard_count)],
        "registered_case_plan":[list(row) for row in case_plan(args.graphical,args.active_workload)],
        "run_id":os.getenv("GITHUB_RUN_ID"),"run_attempt":os.getenv("GITHUB_RUN_ATTEMPT"),"rows":[],"errors":[]}
    paths=[];before={};runtimes={}

    def inputs():return {p:windows.content_digest(ROOT,p) for p in paths}
    def runtime_ids():
        result={}
        for path in runner.runtime_paths():
            relative=path.relative_to(ROOT).as_posix();pointer=git("show","HEAD:"+relative)
            match=re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n",pointer)
            require(match is not None,"Noncanonical runtime LFS pointer")
            data=path.read_bytes()
            require(len(data)==int(match[2]) and hashlib.sha256(data).hexdigest()==match[1].decode()
                    and data.startswith(b"MZ" if sys.platform=="win32" else b"\x7fELF"),"Runtime bytes are not authentic materialized LFS")
            result[relative]={"sha256":sha(path),"bytes":len(data),"pointer":pointer.decode()}
        return result

    def execute(binary,case,directory,role,environment):
        # The process log remains byte-for-byte original on disk. Suppress only
        # run_case's duplicate console echo of that potentially large JSON line.
        with contextlib.redirect_stdout(io.StringIO()):
            return runner.run_case(str(binary),case,directory,role,env=environment)

    try:
        with execution.operation_budget(), windows.metadata_budget():
            source=git("rev-parse","HEAD").decode().strip()
            require(source==args.expected_source_sha,"Wrong executed source commit")
            report.update(source_commit=source,source_tree=git("rev-parse","HEAD^{tree}").decode().strip())
            report["source_baseline"]=publish_baseline(output,source,args.baseline_source)
            changed=git("diff","--name-only",args.baseline_source,source,"--",*SCOPES).decode().splitlines()
            require(all(name in PACE_INPUTS or name.startswith("godot/.godot/") for name in changed),
                    "Production/runner/policy inputs differ from accepted baseline")
            report["production_inputs_unchanged_from_baseline"]=True
            paths=[p for p in git("ls-files","-z","--",*SCOPES).decode().split("\0") if p and not p.startswith("godot/.godot/")]
            require(FIXTURE in paths and PROBE in paths and paths,"Fixture must be committed before qualification")
            git("diff","--exit-code","HEAD","--",*SCOPES,":!godot/.godot")
            before,runtimes=inputs(),runtime_ids()
            report.update(execution_inputs=before,runtimes=runtimes,
                          normalized_import_descriptors=sorted(windows.RAPIER_IMPORT_DESCRIPTORS))
            manifest_name="runtime-provenance.json" if sys.platform=="win32" else "runtime-provenance.linux.json"
            manifest=json.loads((ROOT/"godot/addons/cybersand_native"/manifest_name).read_text())
            require(set(manifest["source_inputs"])==windows.native_input_paths(ROOT),"Native runtime does not cover the complete current native source")
            require(not verify_runtime(ROOT,manifest),"Native runtime/source provenance mismatch")
            lock=json.loads((ROOT/"godot/third_party/rapier2d.lock.json").read_text())
            require(not verify_rapier_overrides(ROOT,lock),"Rapier override provenance mismatch")
            report["native_provenance"]=manifest
            if sys.platform=="win32":
                report["native_runtime_provenance"]=windows.verify_retained_runtime(ROOT)
                binary,report["godot_identity"]=windows.prepare_godot(args.godot_archive.resolve())
            else:
                require(sys.platform.startswith("linux"),"Actual Windows/Linux only")
                lock=json.loads((ROOT/"third_party/godot-runtime.lock.json").read_text())
                archive=args.godot_archive.resolve()
                require(archive.stat().st_size==lock["editor"]["size"] and sha(archive)==lock["editor"]["sha256"],"Wrong Linux Godot archive")
                engine=archive.parent/("pace004-engine-"+output.parent.name+"-"+output.name)
                with zipfile.ZipFile(archive) as bundle:
                    require(bundle.testzip() is None,"Engine archive CRC failed")
                    bundle.extractall(engine)
                binary=engine/"Godot_v4.7-stable_linux.x86_64";binary.chmod(0o755)
                version=subprocess.check_output([str(binary),"--version"],text=True,timeout=execution.operation_remaining()).strip()
                report["godot_identity"]={"version":version,"binary_sha256":sha(binary),"archive_sha256":sha(archive)}
            require(report["godot_identity"]["version"]==VERSION,"Wrong engine version")
            code=(ROOT/PALETTE).read_bytes()
            report["palette_shader_inputs"]={"full_crossfade":hashlib.sha256(code).hexdigest(),
                "angle_bounded_crossfade":hashlib.sha256(BOUNDED_PREFIX+code).hexdigest()}
            report["executed_source_archive_sha256"]=publish_source_archive(output,source)
            write(output/"campaign.json",report)
            # Reject incomplete/corrupted retained source before any import or
            # engine case. Final independent readback still detects later damage.
            entries=verify_source_archive(output,report)
            verify_baseline(output,report,entries,args.baseline_source)
            verify_successor_inputs(output,report)
            prepared=[]
            for rig,workers,policy,workload in selected_plan(args.graphical,args.active_workload,args.shard_index,args.shard_count):
                name=f"pace004-{rig}-workers{workers}-policy{policy}"+("-"+workload if args.active_workload else "")
                directory=output/name
                directory.mkdir()
                prepared.append((rig,workers,policy,workload,name,directory,uuid.uuid4().hex))
        environment=os.environ|{"CYBERSAND_SOURCE_REVISION":source,"GODOT_SILENCE_ROOT_WARNING":"1"}
        report["import"],failed=execute(binary,runner.Case("import",("--editor","--quit"),execution.policy.watchdog_seconds("godot_import_seconds"),0),output,"ordinary headless import",environment)
        with execution.operation_budget():
            report["import_log_sha256"]=sha(output/report["import"]["log"])
            write(output/"campaign.json",report)
            verify_process(report["import"],execution.policy.watchdog_seconds("godot_import_seconds"))
        for rig,workers,policy,workload,name,directory,nonce in prepared:
            env=environment|{"CYBERSAND_PACE004_PROCESS_NONCE":nonce,"CYBERSAND_PACE004_CAPTURE":str(directory)}
            case=runner.Case(name,case_flags(rig,workers,policy,workload,args.graphical,sys.platform),execution.case_seconds(args.graphical),0,args.graphical)
            started=time.perf_counter()
            process,failed=execute(binary,case,directory,"actual first-attempt input custody and gameplay measurement",env)
            observed=time.perf_counter()-started
            with execution.operation_budget():
                write(directory/"process.json",process)
                row={"rig":rig,"workers":workers,"policy":policy,"directory":name,"process_nonce":nonce,
                     "process":process,"observed_total_seconds":observed,"log_sha256":sha(directory/process["log"]),"errors":[]}
                if args.active_workload:row["workload"]=workload
                report["rows"].append(row)
                try:
                    result=extract((directory/process["log"]).read_text(encoding="utf-8"));row["result"]=result
                    verify_process(process,execution.case_seconds(args.graphical),args.graphical)
                    require(observed<=execution.case_observation_seconds(args.graphical),"Late process observation")
                    require(result.get("process_nonce")==nonce,"Process nonce mismatch")
                    row["summary"]=verify_result(result,rig,workers,policy,source,args.graphical,sys.platform)
                    row["summary"]["visual"]=verify_visual(result,directory)
                    if args.active_workload:
                        row["summary"]["workload"]=load_contract.verify_workload(result,workload,before[load_contract.HELPER])
                    else:
                        require(result.get("workload")=={"mode":"none"},"Unregistered workload in original campaign")
                except Exception as error:
                    row["errors"].append(f"{type(error).__name__}: {error}")
                    report["errors"].append(name+": "+row["errors"][-1])
                engine_hash=report["godot_identity"]["runtime_sha256" if sys.platform=="win32" else "binary_sha256"]
                row["cleanup"]=execution.cleanup_receipt(process,row.get("result"),source,nonce,before[FIXTURE],before[PROBE],engine_hash)
                write(directory/"cleanup.json",row["cleanup"])
                write(output/"campaign.json",report)
            print(json.dumps({"case":name,"process":process["status"],"seconds":process["seconds"],"errors":row["errors"]}),flush=True)
            # Preserve every assertion failure, but do not start another case
            # until actual fixture retirement and engine/wrapper exit are seen.
            if not row["cleanup"]["safe_to_continue"]:
                report["errors"].append(name+": cleanup not verified; remaining shard cases unexecuted")
                break
        report["completed"]=len(report["rows"])==len(selected_plan(args.graphical,args.active_workload,args.shard_index,args.shard_count))
    except Exception as error:
        report["errors"].append(f"{type(error).__name__}: {error}")
    finally:
        try:
            with execution.operation_budget(), windows.metadata_budget():
                report["source_unchanged"]=bool(before) and inputs()==before
                report["runtimes_unchanged"]=bool(runtimes) and runtime_ids()==runtimes
        except Exception as error:report["errors"].append("Postflight: "+str(error))
        write(output/"campaign.json",report)
    try:
        reduction=verify_directory(output,sealed=False,baseline_source=args.baseline_source)
        report["status"]="passed";write(output/"campaign.json",report);write(output/"readback.json",reduction)
    except Exception as error:
        report["errors"].append("Final readback: "+str(error));write(output/"campaign.json",report)
    seal(output,report["source_commit"])
    print("PLAY_PACE004_CAMPAIGN "+json.dumps({k:report[k] for k in ("status","completed","errors")}))
    return 0 if report["status"]=="passed" else 1


if __name__=="__main__":
    raise SystemExit(main())
