"""Source-matched identity and existing Linux scheduling/timing comparison."""
import datetime
import hashlib
import json
from pathlib import Path
import zipfile

from investigate_windows_drift import delta, stages

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent


def main():
    old=ROOT/"build/m3-platform/linux/objectshard-m3-linux-evidence-14744731008.zip"
    new=ROOT/"build/m3-platform/repair-linux/objectshard-m3-repaired-linux-evidence-14746310288.zip"
    report={"schema":"objectshard-independent-existing-linux-performance-drift-v1",
            "utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"baseline_source":"68235b12d7f41f7b590456971f21dfc3f5c6d701",
            "repair_source":"e034f2294663e0485cfb9adcc8ada46a6e977cee","evidence_sha256":{},"scheduling_modes":{}}
    with zipfile.ZipFile(old) as zo,zipfile.ZipFile(new) as zn:
        def read(z,name,label):
            data=z.read("lab/"+name);report["evidence_sha256"][label+"/"+name]=hashlib.sha256(data).hexdigest();return json.loads(data)
        oq=read(zo,"qualification.json","baseline");nq=read(zn,"qualification.json","repair")
        assert oq["runtime"]==nq["runtime"]
        report["identical_actual_runtimes"]=nq["runtime"]
        for pump in [0,4000]:
            name="objectshard_worker_profile_"+str(pump)+".json"
            a=read(zo,name,"baseline");b=read(zn,name,"repair")
            keys=["engine","platform","notifications","pump_budget_usec","requested_process_hz","completed_intervals","actual_live_inputs","actual_physics_steps","initial_tick","final_tick","publication_digests","native_accounting","maximum_displacements","contact_owners","sleeping_owners"]
            equal={key:a[key]==b[key] for key in keys};assert all(equal.values())
            assert a["identity"]["files"]==b["identity"]["files"] and a["identity"]["engine_sha256"]==b["identity"]["engine_sha256"]
            old_calls=a["process_callback_interval_usec"]["count"];new_calls=b["process_callback_interval_usec"]["count"]
            report["scheduling_modes"][str(pump)]={"workload_equal":equal,"all_runtime_profile_input_hashes_identical":True,
                "wall_usec":delta(a["play_elapsed_usec"],b["play_elapsed_usec"]),"semantic_rate":delta(a["semantic_ticks_per_wall_second"],b["semantic_ticks_per_wall_second"]),
                "callback_cadence":stages({"callback":a["process_callback_interval_usec"]},{"callback":b["process_callback_interval_usec"]})["callback"],
                "extra_callbacks":new_calls-old_calls,"extra_callbacks_times_repair_median_usec":(new_calls-old_calls)*b["process_callback_interval_usec"]["p50"],
                "host_stages_usec":stages(a["host_stages_usec"],b["host_stages_usec"])}
        a=read(zo,"continuous-play-rendered.json","baseline");b=read(zn,"continuous-play-rendered.json","repair")
        ui=lambda d:{k:{"count":v["count"],**{s:v[s+"_usec"] for s in ["p50","p95","p99","maximum"]}} for k,v in d["presentation_timing"]["stages"].items()}
        report["rendered_burst"]={"actions_baseline":len(a["action_results"]),"actions_repair":len(b["action_results"]),
            "pointer_counts":{"baseline":a["pointer_input"],"repair":b["pointer_input"]},"accounting_equal":a["accounting"]==b["accounting"],
            "completed_ticks":{"baseline":a["completed_ticks"],"repair":b["completed_ticks"]},
            "host_stages_usec":stages(a["timings_usec"],b["timings_usec"]),"ui_stages_usec":stages(ui(a),ui(b))}
        report["lab_frame_drift"]={}
        for mode in ["headless","rendered"]:
            a=read(zo,"objectshard_profile_"+mode+".json","baseline");b=read(zn,"objectshard_profile_"+mode+".json","repair")
            assert [c["name"] for c in a["cases"]]==[c["name"] for c in b["cases"]]
            rows=[]
            for x,y in zip(a["cases"],b["cases"]):
                assert len(x["profile_samples"])==len(y["profile_samples"])==1200
                stats=lambda c:{"frame":{s:c["timings"]["frame_usec"]["max" if s=="maximum" else s] for s in ["p50","p95","p99","maximum"]}}
                rows.append({"name":x["name"],"samples_each":1200,"frame_usec":stages(stats(x),stats(y))["frame"]})
            report["lab_frame_drift"][mode]=rows
        selected=["objectshard_worker_profile_0","objectshard_worker_profile_4000","objectshard_continuous_play_rendered"]
        report["environment_evidence"]={"process_resources":{label:{name:next(c for c in q["cases"] if c["name"]==name)["resources"] for name in selected} for label,q in [("baseline",oq),("repair",nq)]}}
        for label,z,q in [("baseline",zo,oq),("repair",zn,nq)]:
            case=next(c for c in q["cases"] if c["name"]=="objectshard_continuous_play_rendered")
            log=z.read("lab/"+case["log"]).decode(errors="replace")
            report["environment_evidence"][label+"_renderer_lines"]=[line for line in log.splitlines() if "OpenGL API" in line or "Vulkan" in line]
    report["status"]="investigated; timing drift retained; underlying causal attribution unresolved"
    report["interpretation"]=[
        "The repaired Linux pump workload is slower despite identical executed native, Rapier, engine, worker, host, bridge and profile bytes. All 240 published material/pose digests and material accounting match the old same-platform observation.",
        "The difference is visible as 94 additional process callbacks at the same approximately 16.67 ms cadence. Their duration accounts for approximately the whole 1.564-second extra wall interval; the underlying reason more callbacks were needed is not proved by these summaries.",
        "Native-execute median rose from 354 to 366 microseconds, snapshot from 1300 to 1304, physics segment from 108 to 121, and queue-wait from 14 to 20. These are retained observations, not an identified root cause or a changed workload.",
        "Linux process resource sampling is available: the candidate profile CPU observation rose from 5.48 to 5.59 seconds, with direct-process RSS observations retained. It does not establish external contention or hardware equivalence.",
        "The rendered 153-action burst p95 is slightly higher while p99 and maximum are slightly lower. Both runs retain approximately 1.8-second tails; neither is a proof of uniformly fast interaction.",
        "No threshold changed and no replacement timing campaign was commissioned. Final registered Lab budgets pass; negative cross-campaign throughput drift remains part of the owner decision."
    ]
    (OUT/"linux-performance-drift-investigation.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps({"status":report["status"],"pair":{k:v for k,v in report["scheduling_modes"]["4000"].items() if k not in ["host_stages_usec","workload_equal"]},
                      "burst":report["rendered_burst"]["host_stages_usec"]["input_to_presented_usec"],"environment":report["environment_evidence"]},indent=2))


if __name__=="__main__":
    main()
