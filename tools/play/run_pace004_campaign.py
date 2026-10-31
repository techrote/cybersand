#!/usr/bin/env python3
"""Run and independently read back source-pinned PACE004 original process evidence.

Windows/Linux headless: all five rigs with one/Auto workers plus two pressure
policy pairs. Linux graphical: Acrobat/Jetbarrel one/Auto plus Jetbarrel pressure.
Graphical failure never changes the separate headless evidence into graphics.
"""
from __future__ import annotations

import argparse
import ast
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

ROOT=Path(__file__).resolve().parents[2]
BASE="0bf28d5760aed989a79386de03ef4fc6171fef42"
VERSION="4.7.stable.official.5b4e0cb0f"
WORKFLOW=".github/workflows/play-pace004.yml"
SCOPES=("godot","native","third_party","tools/ci","tools/play",WORKFLOW)
PROTECTED=("native","godot/native_extension","godot/shaders","godot/addons","third_party",
           "godot/main.tscn","godot/project.godot",".github/workflows/native.yml",".github/workflows/gdextension.yml")
FIXTURE="godot/tests/play_pace004_input_tape.gd"
PROBE="godot/tests/play_pace004_worker_probe.gd"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path,value: object) -> None:
    path.write_text(json.dumps(value,indent=2,sort_keys=True,allow_nan=False)+"\n",encoding="utf-8")


def git(*args: str) -> bytes:
    return subprocess.check_output(["git","-C",str(ROOT),*args],timeout=60)


def plan(graphical: bool) -> list[tuple[str,int,int]]:
    rigs=("acrobat","jetbarrel") if graphical else RIGS
    rows=[(rig,workers,0) for rig in rigs for workers in (1,0)]
    rows += [(rig,workers,2) for rig in (("jetbarrel",) if graphical else ("acrobat","jetbarrel")) for workers in (1,0)]
    return rows


def safe_file(root: Path,name: str) -> Path:
    require(type(name) is str and name and not name.startswith(("/","\\"))
            and "\\" not in name and ":" not in name and ".." not in Path(name).parts,"Unsafe evidence path")
    path=root/name
    require(path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(root.resolve()),
            "Missing/unsafe evidence file: "+name)
    return path


def verify_process(process: dict,limit: int,graphical: bool=False) -> None:
    require(process.get("status")=="passed" and type(process.get("returncode")) is int and process["returncode"]==0,
            "Original process did not pass")
    require(process.get("timeout_seconds")==limit and 0<=process.get("seconds",-1)<=limit,
            "Wrong or exceeded original process deadline")
    require(process.get("requires_display") is graphical,"Process display scope mismatch")
    require(not any(process.get(k) for k in ("diagnostic_error","launch_error","capture_error","skip_messages","timeout_kind")),
            "Original process contains error/timeout/skip")


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
                       cwd=ROOT,stdout=handle,check=True,timeout=60,
                       env=os.environ|{"GIT_LFS_SKIP_SMUDGE":"1"})
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(pending,destination)
    (output/"executed-commit.txt").write_bytes(git("cat-file","commit",source))
    (output/"executed-tree.bin").write_bytes(git("ls-tree","-r","-z",source))
    return sha(destination)


def verify_source_archive(output: Path,report: dict) -> None:
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


def verify_directory(output: Path,*,sealed: bool=True) -> dict:
    if sealed:
        inventory=json.loads(safe_file(output,"manifest.json").read_text())
        actual={p.relative_to(output).as_posix() for p in output.rglob("*") if p.is_file() and p.name!="manifest.json"}
        require(actual==set(inventory["files"]),"Original artifact inventory changed")
        for name,record in inventory["files"].items():
            path=safe_file(output,name)
            require(path.stat().st_size==record["bytes"] and sha(path)==record["sha256"],"Original evidence digest changed: "+name)
    report=json.loads(safe_file(output,"campaign.json").read_text())
    require(report.get("schema")=="play-pace004-campaign-v1" and report.get("completed") is True
            and report.get("errors")==[],"Campaign incomplete/failed")
    require(report.get("source_unchanged") is True and report.get("runtimes_unchanged") is True
            and report.get("protected_inputs_unchanged_from_base") is True,"Source/runtime postflight failed")
    require(report.get("godot_identity",{}).get("version")==VERSION,"Wrong Godot engine")
    graphical=report.get("graphical")
    require(type(graphical) is bool and (not graphical or report.get("platform")=="linux"),"Unregistered platform scope")
    expected=plan(graphical)
    observed=[(row.get("rig"),row.get("workers"),row.get("policy")) for row in report["rows"]]
    require(Counter(observed)==Counter(expected) and len(observed)==len(expected),"Incomplete/duplicate rig-worker-policy inventory")
    require(report.get("case_plan")==[list(row) for row in expected],"Registered case plan changed")
    verify_source_archive(output,report)
    verify_process(report["import"],240)
    require(sha(safe_file(output,report["import"]["log"]))==report["import_log_sha256"],"Import log changed")
    summaries=[]
    for row in report["rows"]:
        directory=output/row["directory"]
        require(directory.resolve().is_relative_to(output.resolve()),"Unsafe case directory")
        process=json.loads(safe_file(directory,"process.json").read_text())
        require(process==row["process"],"Original process receipt changed")
        verify_process(process,180,graphical)
        require(row["observed_total_seconds"]<=180,"Late observed process completion")
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
        summary=verify_result(result,row["rig"],row["workers"],row["policy"],report["source_commit"],graphical,report["platform"])
        summary["visual"]=verify_visual(result,directory)
        require(summary==row["summary"],"Independent reduction differs from campaign summary")
        summaries.append(summary)
    return {"status":"passed","source_commit":report["source_commit"],"source_tree":report["source_tree"],
            "platform":report["platform"],"graphical":graphical,"case_count":len(summaries),"rows":summaries,
            "qualification":"PACE004 scoped real host/input evidence; no physical devices, scanout FPS, human feel or shader qualification"}


def seal(output: Path,source: str|None) -> None:
    files={p.relative_to(output).as_posix():{"bytes":p.stat().st_size,"sha256":sha(p)}
           for p in sorted(output.rglob("*")) if p.is_file() and p.name!="manifest.json"}
    write(output/"manifest.json",{"source_commit":source,"files":files})


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot-archive",type=Path)
    parser.add_argument("--expected-source-sha")
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--graphical",action="store_true")
    parser.add_argument("--verify-only",action="store_true")
    args=parser.parse_args()
    output=args.output.resolve()
    if args.verify_only:
        summary=verify_directory(output)
        require(args.expected_source_sha is None or summary["source_commit"]==args.expected_source_sha,
                "Artifact source differs from independently expected commit")
        print(json.dumps({k:v for k,v in summary.items() if k!="rows"},sort_keys=True))
        return 0
    require(args.godot_archive is not None and args.expected_source_sha is not None,"Execution requires archive and exact source")
    require(not args.graphical or sys.platform.startswith("linux"),"Graphical campaign is registered for Linux only")
    output.mkdir(parents=True,exist_ok=False)
    sys.path.insert(0,str(ROOT/"tools/ci"))
    import run_godot_regressions as runner
    import run_windows_godot_regressions as windows
    from check_repository import verify_runtime,verify_rapier_overrides
    report={"schema":"play-pace004-campaign-v1","status":"failed","completed":False,
        "source_commit":None,"base_commit":BASE,"platform":sys.platform,"host":platform.platform(),
        "python":sys.version,"graphical":args.graphical,"case_plan":[list(row) for row in plan(args.graphical)],
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
        source=git("rev-parse","HEAD").decode().strip()
        require(source==args.expected_source_sha,"Wrong executed source commit")
        report.update(source_commit=source,source_tree=git("rev-parse","HEAD^{tree}").decode().strip())
        require(not git("diff","--name-only",BASE,"HEAD","--",*PROTECTED).strip(),"Protected native/shader/runtime/workflow inputs changed")
        report["protected_inputs_unchanged_from_base"]=True
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
            version=subprocess.check_output([str(binary),"--version"],text=True,timeout=30).strip()
            report["godot_identity"]={"version":version,"binary_sha256":sha(binary),"archive_sha256":sha(archive)}
        require(report["godot_identity"]["version"]==VERSION,"Wrong engine version")
        report["executed_source_archive_sha256"]=publish_source_archive(output,source)
        write(output/"campaign.json",report)
        # Reject incomplete/corrupted retained source before any import or
        # engine case. Final independent readback still detects later damage.
        verify_source_archive(output,report)
        environment=os.environ|{"CYBERSAND_SOURCE_REVISION":source,"GODOT_SILENCE_ROOT_WARNING":"1"}
        report["import"],failed=execute(binary,runner.Case("import",("--editor","--quit"),240,0),output,"ordinary headless import",environment)
        report["import_log_sha256"]=sha(output/report["import"]["log"])
        write(output/"campaign.json",report)
        verify_process(report["import"],240)
        for rig,workers,policy in plan(args.graphical):
            name=f"pace004-{rig}-workers{workers}-policy{policy}";directory=output/name
            directory.mkdir()
            nonce=uuid.uuid4().hex
            env=environment|{"CYBERSAND_PACE004_PROCESS_NONCE":nonce,"CYBERSAND_PACE004_CAPTURE":str(directory)}
            case=runner.Case(name,("--script","res://tests/play_pace004_input_tape.gd","--",
                f"--rig={rig}",f"--workers={workers}",f"--policy={policy}"),180,0,args.graphical)
            started=time.perf_counter()
            process,failed=execute(binary,case,directory,"actual first-attempt input custody and gameplay measurement",env)
            observed=time.perf_counter()-started
            write(directory/"process.json",process)
            row={"rig":rig,"workers":workers,"policy":policy,"directory":name,"process_nonce":nonce,
                 "process":process,"observed_total_seconds":observed,"log_sha256":sha(directory/process["log"]),"errors":[]}
            report["rows"].append(row)
            try:
                verify_process(process,180,args.graphical)
                require(observed<=180,"Late process observation")
                result=extract((directory/process["log"]).read_text(encoding="utf-8"));row["result"]=result
                require(result.get("process_nonce")==nonce,"Process nonce mismatch")
                row["summary"]=verify_result(result,rig,workers,policy,source,args.graphical,sys.platform)
                row["summary"]["visual"]=verify_visual(result,directory)
            except Exception as error:
                row["errors"].append(f"{type(error).__name__}: {error}")
                report["errors"].append(name+": "+row["errors"][-1])
            write(output/"campaign.json",report)
            print(json.dumps({"case":name,"process":process["status"],"seconds":process["seconds"],"errors":row["errors"]}),flush=True)
            # Preserve the first original graphical failure, then stop this
            # graphical cohort. An incomplete inventory cannot pass. Continue
            # unaffected OS/headless cohorts in independent hosted jobs.
            if args.graphical and row["errors"]:break
        report["completed"]=len(report["rows"])==len(plan(args.graphical))
    except Exception as error:
        report["errors"].append(f"{type(error).__name__}: {error}")
    finally:
        try:
            report["source_unchanged"]=bool(before) and inputs()==before
            report["runtimes_unchanged"]=bool(runtimes) and runtime_ids()==runtimes
        except Exception as error:report["errors"].append("Postflight: "+str(error))
        write(output/"campaign.json",report)
    try:
        reduction=verify_directory(output,sealed=False)
        report["status"]="passed";write(output/"campaign.json",report);write(output/"readback.json",reduction)
    except Exception as error:
        report["errors"].append("Final readback: "+str(error));write(output/"campaign.json",report)
    seal(output,report["source_commit"])
    print("PLAY_PACE004_CAMPAIGN "+json.dumps({k:report[k] for k in ("status","completed","errors")}))
    return 0 if report["status"]=="passed" else 1


if __name__=="__main__":
    raise SystemExit(main())
