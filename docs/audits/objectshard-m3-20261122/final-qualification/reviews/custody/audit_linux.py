"""Audit authentic Linux archive in place, without extracting binaries/objects."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
import subprocess
import zipfile

import audit_navigation

SOURCE = "e034f2294663e0485cfb9adcc8ada46a6e977cee"
TREE = "246e7324ca618d98c43a0ed54fe19bc86a155877"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo",type=Path,required=True)
    parser.add_argument("--archive",type=Path,required=True)
    parser.add_argument("--artifact-id",type=int,required=True)
    parser.add_argument("--remote",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args = parser.parse_args()
    out = args.output.parent
    report = {"schema":"objectshard-independent-final-linux-review-v1","source_commit":SOURCE,"source_tree":TREE,
              "utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"failures":[],"artifact_id":args.artifact_id}
    def expect(condition,message):
        if not condition:
            report["failures"].append(message)
    cache={}
    def committed(path):
        if path not in cache:
            cache[path]=subprocess.check_output(["git","-C",str(args.repo),"show",SOURCE+":"+path])
        return cache[path]
    remote=json.loads(args.remote.read_text())
    metadata=next(row for row in remote["artifacts"] if row["id"]==args.artifact_id)
    job=next(row for row in remote["jobs"] if row["id"]==137136516239)
    expect(job["status"]=="completed" and job["conclusion"]=="success","Actual final Linux job incomplete/failed")
    with args.archive.open("rb") as stream:
        archive_sha=hashlib.file_digest(stream,"sha256").hexdigest()
    expect(metadata["digest"]=="sha256:"+archive_sha and metadata["size_in_bytes"]==args.archive.stat().st_size
           and metadata["workflow_run"]["head_sha"]==SOURCE and metadata["workflow_run"]["id"]==44999117090,
           "Authentic exact-source Linux archive bytes and remote metadata")
    report.update(archive_sha256=archive_sha,archive_bytes=args.archive.stat().st_size,job_id=137136516239,
                  remote_readback_sha256=sha(args.remote.read_bytes()))
    with zipfile.ZipFile(args.archive) as z:
        names=z.namelist()
        expect(len(names)==len(set(names)),"No duplicate archive names")
        member_hashes={}
        for member in z.infolist():
            p=PurePosixPath(member.filename)
            expect(not p.is_absolute() and ".." not in p.parts and "\\" not in member.filename,"Unsafe archive member")
            with z.open(member) as stream:
                digest=hashlib.file_digest(stream,"sha256").hexdigest()
            member_hashes[member.filename]={"bytes":member.file_size,"sha256":digest}
        report.update(archive_members=len(member_hashes),expanded_bytes=sum(row["bytes"] for row in member_hashes.values()),all_members_stream_hashed=True)
        (out/"linux-archive-members.json").write_text(json.dumps(member_hashes,indent=2)+"\n")
        def read(name):
            return z.read(name)
        def document(name):
            return json.loads(read(name))
        expect(read("source-commit.txt").decode().strip()==SOURCE and read("source-tree.txt").decode().strip()==TREE,"Archive source markers")
        summary=document("native/summary.json")
        expect(summary["git_head"]==SOURCE and summary["status"]=="passed" and summary["counts_complete"] is True and summary["failures_reported"]==0,
               "Native suite source and completion")
        expect(summary["sanitizers"] is True and summary["leak_sanitizer"] is False,"ASan/UBSan scope; leak checking remains disabled")
        prefix="native/"+PurePosixPath(summary["run_directory"]).name
        expect(document(prefix+"/summary.json")==summary,"Native root/nested summaries agree")
        inputs=document(prefix+"/inputs.json")
        expect(inputs["git_head"]==SOURCE and inputs["input_digest"]==summary["input_digest"] and inputs["world_filter"]=="","Exact native source/full World input inventory")
        specification={k:inputs[k] for k in ["schema","sources","compiler","compiler_version","flags","suites","world_filter","platform","world_test_flags"]}
        expect(sha(json.dumps(specification,sort_keys=True).encode())==inputs["input_digest"],"Independently recomputed complete compiler/source/test input digest")
        expect(len(inputs["sources"])==128,"Complete 128 native/test inputs")
        for path,digest in inputs["sources"].items():
            expect(sha(committed(path))==digest==member_hashes[prefix+"/source/"+path]["sha256"],"Frozen native/test source differs: "+path)
        expect("-fsanitize=address,undefined" in inputs["flags"] and "-fsanitize=address,undefined" in inputs["world_test_flags"],"Sanitizer compile flags")
        builds=document(prefix+"/builds.json")
        expect(len(builds)==22,"Complete 22 native compile object receipts")
        for name,row in builds.items():
            obj=prefix+"/objects/"+name+".o"
            expect(row["returncode"]==0 and row["timed_out"] is False and row["object_sha256"]==member_hashes[obj]["sha256"],"Actual compiled object: "+name)
            expect("-fsanitize=address,undefined" in row["command"],"Object lacks sanitizer flags: "+name)
            expect(PurePosixPath(row["log"]).name in [PurePosixPath(n).name for n in names if n.startswith(prefix+"/logs/")],"Compiler log retained")
        suites=summary["suites"]
        expect(set(suites)=={"admission","chemistry","contact","coordinator","external_fire","storage","world"},"Complete seven-suite inventory")
        rows=[]
        for name,row in suites.items():
            binary=prefix+"/test_object_shard_"+name
            expect(row["binary_sha256"]==member_hashes[binary]["sha256"] and row["status"]=="passed" and row["failures"]==0,"Native suite executable/status: "+name)
            for stage in ["link","execution"]:
                record=row[stage]
                expect(record["returncode"]==0 and record["timed_out"] is False,"Native suite phase: "+name+"/"+stage)
            text=read(prefix+"/logs/"+PurePosixPath(row["execution"]["log"]).name).decode(errors="replace")
            expect(re.search(r"(?:ERROR: AddressSanitizer|runtime error:|UndefinedBehaviorSanitizer:)",text) is None,"Sanitizer error in passing suite: "+name)
            if name=="world":
                passing=re.findall(r"^\[pass\] (.+)$",text,re.MULTILINE)
                expect(len(passing)==len(set(passing))==row["checks"]==192 and "192 tests passed" in text and row.get("name_filter") is None,"Complete actual 192 World cases, no filter")
            else:
                parsed=re.search(r"(\d+) checks, (\d+) failures",text)
                if parsed:
                    expect(int(parsed[1])==row["checks"] and int(parsed[2])==0,"Native complete check footer: "+name)
                else:
                    objects=[]
                    for line in text.splitlines():
                        try: value=json.loads(line)
                        except json.JSONDecodeError: continue
                        if isinstance(value,dict) and "checks" in value and "failures" in value:objects.append(value)
                    expect(bool(objects) and objects[-1]["checks"]==row["checks"] and objects[-1]["failures"]==0,"Native JSON completion footer: "+name)
            rows.append({"suite":name,"checks":row["checks"],"unit":row["count_unit"],"seconds":row["execution"]["elapsed_seconds"],"binary_sha256":row["binary_sha256"]})
        expect(sum(row["checks"] for row in rows if row["unit"]=="checks")==summary["checks_reported"]==93529 and summary["test_cases_reported"]==192,"Native assertion totals")
        report["native_sanitizer"]={"source_inputs":128,"input_digest":summary["input_digest"],"compiler":inputs["compiler_version"].splitlines()[0],
            "compiled_objects":22,"checks":summary["checks_reported"],"world_test_cases":192,"suites":rows,"asan":True,"ubsan":True,"leak_sanitizer":False,"world_filter":None,"elapsed_seconds":summary["elapsed_seconds"]}
        receipt=document("linux-native-provenance.json")
        source=receipt["source"]
        expect(receipt["phase"]=="sealed" and source["source_commit"]==SOURCE and source["source_tree"]==TREE,"Sealed exact native runtime source receipt")
        independent_inputs=json.loads((out/"source-inventory.json").read_text())["native_inputs"]
        expect(source["source_inputs"]==independent_inputs,"Complete 116 native runtime input ledger")
        for path,digest in source["build_contract_inputs"].items():
            expect(sha(committed(path))==digest,"Native build contract input: "+path)
        so_name="libcybersand_native.linux.x86_64.so"
        expect(receipt["runtime"]["sha256"]==member_hashes[so_name]["sha256"] and receipt["runtime"]["size"]==member_hashes[so_name]["bytes"],"Actual sealed Linux runtime bytes")
        with z.open(so_name) as stream: header=stream.read(64)
        expect(header.startswith(b"\x7fELF\x02\x01") and struct.unpack_from("<H",header,18)[0]==62,"Actual Linux x86_64 ELF runtime")
        build_rows=[]
        for stage in ["bindings","extension"]:
            row=document(stage+"/receipt.json");log=read(stage+"/command.log")
            expect(row["status"]=="passed" and row["returncode"]==0 and row["natural_completion"] is True and not row["timed_out"] and row["complete"] is True,"Fresh Linux compiler phase: "+stage)
            expect(row["source"]["commit"]==SOURCE and row["source"]["tree"]==TREE and row["source"]["run_id"]=="44999117090" and row["source"]["tracked_delta_sha256"] is None,"Fresh Linux compile identity: "+stage)
            expect(sha(log)==row["log_sha256"],"Fresh Linux compilation output hash: "+stage)
            expect(sha(committed(row["execution_policy"]["path"]))==row["execution_policy"]["sha256"] and row["execution_policy"]["scale"]==1,"Unchanged compiler watchdog policy")
            build_rows.append({"stage":stage,"seconds":row["elapsed_seconds"],"log_sha256":sha(log),"receipt_sha256":member_hashes[stage+"/receipt.json"]["sha256"]})
        report["runtime"]={**receipt["runtime"],"native_inputs":len(source["source_inputs"]),"build_contract_inputs":len(source["build_contract_inputs"]),"fresh_builds":build_rows}
        q=document("lab/qualification.json")
        expect(q["source_commit"]==SOURCE and q["source_tree"]==TREE and q["status"]=="passed" and not q["failures"],"Actual Linux source qualification complete")
        expect(q["native_source_inputs"]==independent_inputs and q["runtime"]["native_sha256"]==receipt["runtime"]["sha256"] and q["runtime"]["platform"]=="linux","Actually executed Linux native identity")
        expect(q["runtime"]["godot_version"]=="4.7.stable.official.5b4e0cb0f" and q["runtime"]["godot_sha256"]=="f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75"
               and q["runtime"]["rapier_sha256"]=="566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a","Pinned actual Linux Godot/Rapier")
        for field in ["lab_source_inputs","qualification_tool_inputs"]:
            for path,digest in q[field].items():
                expect(sha(committed(path))==digest,"Executed script/qualifier input: "+path)
        windows=json.loads((out/"windows-execution-review.json").read_text())
        expected={row["name"] for row in windows["process_cases"]["windows-lab"]}
        expect(len(q["cases"])==41 and {row["name"] for row in q["cases"]}==expected,"Complete 41-case actual Linux inventory")
        case_rows=[]
        for case in q["cases"]:
            log=read("lab/"+case["log"])
            expect(case["status"]=="passed" and case["natural_completion"] is True and case["returncode"]==0 and not any(case.get(k) for k in ["diagnostic_error","launch_error","capture_error","skip_messages","timeout_kind"]),"Actual Godot completion: "+case["name"])
            expect(sha(log)==case["log_sha256"],"Godot process log hash: "+case["name"])
            expect(sha(committed(case["execution_policy"]["path"]))==case["execution_policy"]["sha256"] and case["execution_policy"]["scale"]==1,"Godot ordinary watchdog contract")
            completion=case.get("completion_receipt")
            if completion:
                footers=[]
                for line in log.decode(errors="replace").splitlines():
                    try: value=json.loads(line)
                    except json.JSONDecodeError: continue
                    if isinstance(value,dict) and value.get("schema")==completion["schema"]:footers.append(value)
                expect(footers==[completion] and type(completion.get("failures")) is int and completion["failures"]==0,"Actual successful unique completion footer: "+case["name"])
            case_rows.append({"name":case["name"],"seconds":case["seconds"],"checks":completion.get("checks") if completion else None,"requires_display":case["requires_display"]})
        navigation=audit_navigation.audit(lambda name:read("lab/"+name),SOURCE)
        expect(navigation["status"]=="passed","Actual Linux navigation/real exit child: "+repr(navigation["failures"]))
        report["godot"]={"runtime":q["runtime"],"lab_source_inputs":len(q["lab_source_inputs"]),"qualification_tool_inputs":len(q["qualification_tool_inputs"]),"cases":case_rows,"navigation":navigation}
        unitlog=read("package-contracts.log");unitcount=re.search(rb"Ran (\d+) tests",unitlog)
        expect(unitcount and int(unitcount[1])==50 and re.search(rb"\nOK\s*$",unitlog),"Fresh hosted package contracts complete50 tests")
        report["hosted_package_contracts"]={"tests":50,"log_sha256":sha(unitlog)}
    report["status"]="passed" if not report["failures"] else "failed"
    report["scope"]="Fresh exact-source Linux native sanitizers, full World192 cases, runtime compilation and actual Godot/Rapier/navigation process custody. Raw performance distributions are reduced separately. No owner physical acceptance."
    report["remaining_limits"]=["LeakSanitizer remains disabled by unchanged harness","No native performance matrix was generated by this artifact-only workflow; retained source-identical matrix74/74 is separately attributed","Native allocator limit is not Godot/Rapier/GPU or mailbox allocation qualification","Full ordinary production provenance remains six failures"]
    args.output.write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps({"status":report["status"],"failures":report["failures"],"archive_sha256":archive_sha,
                      "archive_members":report["archive_members"],"native_checks":report["native_sanitizer"]["checks"],
                      "World_cases":192,"Godot_cases":len(report["godot"]["cases"]),"navigation":navigation},indent=2))
    raise SystemExit(bool(report["failures"]))


if __name__=="__main__":
    main()
