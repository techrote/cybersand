"""Investigate existing cross-campaign timing drift without new trials."""
from collections import Counter
import datetime
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
OLD = "68235b12d7f41f7b590456971f21dfc3f5c6d701"
NEW = "e034f2294663e0485cfb9adcc8ada46a6e977cee"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def file_sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream,"sha256").hexdigest()


def sections(data):
    pe = struct.unpack_from("<I",data,0x3c)[0]
    n = struct.unpack_from("<H",data,pe+6)[0]
    optional = struct.unpack_from("<H",data,pe+20)[0]
    result = {}
    for index in range(n):
        offset = pe+24+optional+40*index
        name = data[offset:offset+8].rstrip(b"\0").decode()
        size,start = struct.unpack_from("<II",data,offset+16)
        result[name] = {"bytes":size,"offset":start,"sha256":sha(data[start:start+size])}
    return result


def delta(old, new):
    return {"baseline":old,"repair":new,"delta":new-old,"percent":((new-old)/old*100 if old else None)}


def stages(old,new):
    result = {}
    for key in sorted(set(old)&set(new)):
        if not isinstance(old[key],dict) or not isinstance(new[key],dict):
            continue
        row = {label:delta(old[key][label],new[key][label]) for label in ["p50","p95","p99","maximum","count"] if label in old[key] and label in new[key]}
        if row:
            result[key] = row
    return result


def main():
    oldzip=ROOT/"build/m3-platform/windows/objectshard-m3-artifact-14744390583.zip"
    newzip=ROOT/"build/m3-platform/repair-windows/objectshard-m3-repair-artifact-14745662483.zip"
    assert file_sha(oldzip)=="e2b10d5f114ebffd923f908972e2e4ccc4dd882bcc08f365f5d63d9e3375c9d7"
    assert file_sha(newzip)=="f3c51e40774429a88294c2218724368534dc811c32e0f7869b2d065246cf38eb"
    report={"schema":"objectshard-independent-existing-windows-performance-drift-v1","utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "baseline_source":OLD,"repair_source":NEW,"scope":"Existing immutable hosted trials only; old682 is superseded functional/package evidence, not final acceptance. No rerun or threshold change.","evidence_sha256":{}}
    with zipfile.ZipFile(oldzip) as zo,zipfile.ZipFile(newzip) as zn:
        def read(z,name,label):
            b=z.read("windows-lab/"+name);report["evidence_sha256"][label+"/"+name]=sha(b);return json.loads(b)
        oq=read(zo,"qualification.json","baseline");nq=read(zn,"qualification.json","repair")
        assert oq["source_commit"]==OLD and nq["source_commit"]==NEW
        report["runtimes"]={"baseline":oq["runtime"],"repair":nq["runtime"]}
        report["scheduling_modes"]={}
        for pump in [0,4000]:
            name="objectshard_worker_profile_"+str(pump)+".json"
            a=read(zo,name,"baseline");b=read(zn,name,"repair")
            shared=["engine","platform","notifications","pump_budget_usec","requested_process_hz","completed_intervals","actual_live_inputs","actual_physics_steps","initial_tick","final_tick","publication_digests","native_accounting","maximum_displacements","contact_owners","sleeping_owners"]
            equal={key:a[key]==b[key] for key in shared};assert all(equal.values())
            identity_diff={key:{"baseline":a["identity"]["files"].get(key),"repair":b["identity"]["files"].get(key)} for key in set(a["identity"]["files"])|set(b["identity"]["files"]) if a["identity"]["files"].get(key)!=b["identity"]["files"].get(key)}
            assert set(identity_diff)=={"res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"}
            report["scheduling_modes"][str(pump)]={"workload_equal":equal,"identity_file_differences":identity_diff,
                "wall_usec":delta(a["play_elapsed_usec"],b["play_elapsed_usec"]),
                "semantic_rate":delta(a["semantic_ticks_per_wall_second"],b["semantic_ticks_per_wall_second"]),
                "poll_count":delta(a["poll_count"],b["poll_count"]),
                "callback_cadence":stages({"callback":a["process_callback_interval_usec"]},{"callback":b["process_callback_interval_usec"]})["callback"],
                "pump_call":stages({"pump":a["pump_call_usec"]},{"pump":b["pump_call_usec"]}).get("pump",{}),
                "host_stages_usec":stages(a["host_stages_usec"],b["host_stages_usec"]),
                "native_value_sizes":{key:{"baseline":a["host"]["worker"][key],"repair":b["host"]["worker"][key]} for key in ["maximum_snapshot_value_bytes","maximum_reply_value_bytes","snapshot_copies"]}}
        a=read(zo,"continuous-play-rendered.json","baseline");b=read(zn,"continuous-play-rendered.json","repair")
        outcomes=lambda doc:dict(Counter(row["outcome"] for row in doc["action_results"]))
        ui=lambda doc:{key:{"count":value["count"],**{s:value[s+"_usec"] for s in ["p50","p95","p99","maximum"]}} for key,value in doc["presentation_timing"]["stages"].items()}
        report["rendered_burst"]={"action_counts":{"baseline":len(a["action_results"]),"repair":len(b["action_results"])},
            "pointer_counts":{"baseline":a["pointer_input"],"repair":b["pointer_input"]},"outcomes":{"baseline":outcomes(a),"repair":outcomes(b)},
            "host_stages_usec":stages(a["timings_usec"],b["timings_usec"]),"ui_stages_usec":stages(ui(a),ui(b)),
            "completed_tick_counts":{"baseline":a["completed_ticks"],"repair":b["completed_ticks"]},
            "accounting_equal":a["accounting"]==b["accounting"],"source_scope":"The same153-action script includes a96-point burst; callback and tick counts can differ because this is real asynchronous UI progression, not a forced identical temporal trace."}
        report["lab_frame_drift"]={}
        for mode in ["headless","rendered"]:
            a=read(zo,"objectshard_profile_"+mode+".json","baseline");b=read(zn,"objectshard_profile_"+mode+".json","repair")
            assert [x["name"] for x in a["cases"]]==[x["name"] for x in b["cases"]]
            rows=[]
            for x,y in zip(a["cases"],b["cases"]):
                assert len(x["profile_samples"])==len(y["profile_samples"])==1200
                stats=lambda c:{"frame":{s:(c["timings"]["frame_usec"]["max"] if s=="maximum" else c["timings"]["frame_usec"][s]) for s in ["p50","p95","p99","maximum"]}}
                rows.append({"name":x["name"],"samples_each":1200,"frame_usec":stages(stats(x),stats(y))["frame"]})
            report["lab_frame_drift"][mode]=rows
        selected=["objectshard_worker_profile_0","objectshard_worker_profile_4000","objectshard_continuous_play_rendered","objectshard_profile_headless","objectshard_profile_rendered"]
        report["environment_evidence"]={"process_resources":{label:{name:next(c for c in q["cases"] if c["name"]==name)["resources"] for name in selected} for label,q in [("baseline",oq),("repair",nq)]}}
        for label,z,q in [("baseline",zo,oq),("repair",zn,nq)]:
            name=next(c["log"] for c in q["cases"] if c["name"]=="objectshard_continuous_play_rendered")
            log=z.read("windows-lab/"+name).decode(errors="replace")
            report["environment_evidence"][label+"_renderer_lines"]=[line for line in log.splitlines() if "ANGLE" in line or "OpenGL API" in line or "Vulkan" in line]
    dlls=[]
    for path in [ROOT/"build/m3-platform/windows/objectshard-m3-windows-dll-14743743167.zip",ROOT/"build/m3-platform/repair-windows/objectshard-m3-repair-artifact-14745122677.zip"]:
        with zipfile.ZipFile(path) as z:dlls.append(z.read("cybersand_native.windows.x86_64.dll"))
    os,ns=map(sections,dlls)
    report["native_pe_sections"]={name:{"baseline":os[name],"repair":ns[name],"identical":os[name]["sha256"]==ns[name]["sha256"]} for name in os}
    report["native_differing_byte_count"]=sum(a!=b for a,b in zip(*dlls))+abs(len(dlls[0])-len(dlls[1]))
    paths=["godot/scripts/object_shard_worker_host.gd","godot/scripts/object_shard_native_worker.gd","godot/scripts/object_shard_physics_bridge.gd",
           "godot/scripts/object_shard_lab_session.gd","godot/tests/profile_object_shard_worker.gd","godot/tests/profile_object_shard_lab.gd",
           "godot/tests/test_object_shard_continuous_play.gd","godot/project.godot","tools/build_native_extension_windows.sh","third_party/native-toolchain.lock.json"]
    report["unchanged_runtime_hotpaths"]={}
    for path in paths:
        a=subprocess.check_output(["git","-C",str(ROOT),"show",OLD+":"+path]);b=subprocess.check_output(["git","-C",str(ROOT),"show",NEW+":"+path]);assert a==b
        report["unchanged_runtime_hotpaths"][path]=sha(b)
    report["interpretation"]=[
        "Observed regression is retained: same240-interval pump workload takes longer and the same153-action UI burst has larger queue/presentation tails. No claim of performance equivalence to682.",
        "Headless pump profiles do not instantiate the repaired owner scene. They retain identical script/runtime interface inputs, canonical publications, accounting, cadence target and workload counts; nativeExecute/snapshot/value-accounting medians rose in the new actual run.",
        "PE code and data section comparisons below assess whether the freshly built native executable code differs. Fresh artifact source custody is still mandatory even for equal code sections.",
        "Same pinned engine and selected Rapier, same reported software renderer, but resource sampling is unavailable in both Windows trials. There is no retained CPU utilization, host scheduling or hardware evidence that proves a cause.",
        "Inference only: broad measured per-stage cost increases and extra callback cycles are compatible with execution-cost/scheduling differences; these trials do not establish runner variance or causation by the navigation changes.",
        "Unchanged registered Lab limits still pass. These do not constrain the new burst input latency. That observed1.9-second failure tail remains a practical limitation to report and test physically; no60FPS or universally responsive editing claim.",
        "No additional campaign was commissioned: existing evidence identifies the actual stage/cadence difference and the limits of attribution without weakening budgets or treating a repeated trial as a replacement."
    ]
    report["status"]="investigated; negative timing drift retained; causal attribution unresolved"
    (OUT/"windows-performance-drift-investigation.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps({"status":report["status"],"native_differing_byte_count":report["native_differing_byte_count"],
                      "changed_pe_sections":[name for name,row in report["native_pe_sections"].items() if not row["identical"]],
                      "pump4000_wall":report["scheduling_modes"]["4000"]["wall_usec"],
                      "pump4000_rate":report["scheduling_modes"]["4000"]["semantic_rate"],
                      "burst_input_to_presented":report["rendered_burst"]["host_stages_usec"]["input_to_presented_usec"],
                      "environment":report["environment_evidence"]},indent=2))


if __name__=="__main__":
    main()
