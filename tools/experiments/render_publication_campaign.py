"""Fresh-process rendered publication investigation; retain failures and raw traces."""
from __future__ import annotations
import argparse
from collections import Counter
import hashlib
import json
import math
import platform
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
BASE = "adaaa37ae35ffcdaa961b80353be3a23b805c0cc"

def git_value(value):
    # This investigation also runs Linux Godot against this Windows worktree in
    # WSLg. Its Git metadata uses Windows absolute paths, so use its owning Git.
    git = "git" if platform.system() == "Windows" else "/mnt/c/Program Files/Git/cmd/git.exe"
    return subprocess.check_output([git,"rev-parse",value],cwd=ROOT,text=True).strip()

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def percentiles(values):
    values = sorted(values)
    if not values:
        return {"n": 0}
    return {"n": len(values), **{label: values[min(len(values)-1, math.ceil(len(values)*q)-1)]
        for label, q in [("p50", .5), ("p95", .95), ("p99", .99), ("max", 1)]}}

def reduce_trace(data):
    events = data["events"]
    if data["dropped"] or data["failures"]:
        raise ValueError("failed/truncated graphical trace")
    counts = data["counts"]
    if Counter(e["event"] for e in events) != counts:
        raise ValueError("event/counter mismatch")
    if "candidate" in data:
        if not data["final_cpu_native_equal"] or not data["final_texture_image_equal"]:
            raise ValueError("final CPU/native/texture parity failed")
        expected_script="res://tests/render_publication_e.gd" if data["candidate"]=="E" else "res://tests/render_publication_worker.gd"
        if data.get("owner_script",expected_script) != expected_script: raise ValueError("wrong candidate owner")
        if data["candidate"]=="E" and data["pending_high_water"] > 4194304:
            raise ValueError("candidate pending bound exceeded")
    def select(kind): return [e for e in events if e["event"] == kind]
    calls = select("native_end")
    begins = select("native_begin")
    call_keys=[(e["refresh"],e["call"]) for e in calls]
    if (len(call_keys)!=len(set(call_keys)) or sorted(call_keys)!=sorted((e["refresh"],e["call"]) for e in begins)
            or any(e["call"] not in [1,2] or e["duration_usec"]<0 or e["end_usec"]-e["start_usec"]!=e["duration_usec"] for e in calls)):
        raise ValueError("invalid native call pairing or duration")
    owner_ends=select("owner_end")
    for refresh in {e["refresh"] for e in calls}:
        if sum(e["refresh"]==refresh for e in owner_ends)!=1:
            raise ValueError("missing/duplicate owner publication")
    retry_causes = []
    for retry in [e for e in calls if e["call"] == 2]:
        first = [e for e in events if e["event"] == "dirty_onto_full" and e["refresh"] == retry["refresh"]]
        if len(first) != 1 or not first[0]["before"]["full"] or not first[0]["byte_overflow"]:
            raise ValueError("unexplained retry")
        retry_causes.append({"refresh": retry["refresh"], "byte": first[0]["byte_overflow"],
            "rectangles": first[0]["rectangle_overflow"], "status": next(e["status"] for e in calls
                if e["refresh"] == retry["refresh"] and e["call"] == 1)})
    durations = {}
    for begin, end, name in [("validation_begin", "validation_end", "validation_usec"),
            ("patch_begin", "patch_end", "patch_including_validation_usec"),
            ("texture_update_begin", "texture_update_end", "texture_update_call_usec"),
            ("texture_begin", "texture_success", "texture_submission_usec")]:
        starts = select(begin)
        ends = select(end)
        if len(starts) != len(ends): raise ValueError("unpaired consumer events")
        if any(a.get("serial") != b.get("serial") or a.get("generation") != b.get("generation") for a,b in zip(starts,ends)):
            raise ValueError("consumer identity changed inside operation")
        durations[name] = percentiles([b["usec"]-a["usec"] for a,b in zip(starts, ends)])
    # CPU image work excludes the nested complete-payload validation interval.
    durations["cpu_patch_usec"] = percentiles([(b["usec"]-a["usec"])-(d["usec"]-c["usec"])
        for a,b,c,d in zip(select("patch_begin"),select("patch_end"),select("validation_begin"),select("validation_end"))])
    clears = select("ack_clear")
    ack_latency = []
    for clear in clears:
        eligible = [e for e in select("ack_issue") if e["serial"] == clear["ack_serial"] and e["usec"] <= clear["usec"]]
        if not eligible or clear["ack_serial"] < clear["pending_serial"]:
            raise ValueError("clear without a covering ACK")
        ack_latency.append(clear["usec"] - eligible[-1]["usec"])
    # Verify every observed World generation starts with a complete replacement.
    seen_generations = set()
    for e in calls:
        if e["generation"] not in seen_generations:
            if not e["complete_full"]: raise ValueError("new generation did not start with an exact complete full packet")
            seen_generations.add(e["generation"])
    if seen_generations != {1,2}: raise ValueError("missing reset generation")
    successes = select("texture_success") + select("texture_create_success")
    for ack in select("ack_issue") + select("ack_withheld"):
        if not any(e["serial"] == ack["serial"] and e["usec"] < ack["usec"] for e in successes):
            raise ValueError("ACK before successful upload")
    if data["arm"] == "W" and (select("ack_issue") or clears): raise ValueError("withheld control acknowledged")
    if data["arm"] == "N" and not select("ack_issue"): raise ValueError("normal arm has no ACK")
    return {"counts": counts, "retry_causes": retry_causes,
        "native_exchange_usec": percentiles([e["duration_usec"] for e in calls]),
        "native_first_usec": percentiles([e["duration_usec"] for e in calls if e["call"] == 1]),
        "native_retry_usec": percentiles([e["duration_usec"] for e in calls if e["call"] == 2]),
        "worker_publication_usec": percentiles([e["duration_usec"] for e in select("owner_end") if e["calls"] > 0]),
        "ack_to_clear_usec": percentiles(ack_latency), "frame_usec": percentiles(data["frame_usec"]),
        "native_bytes_per_refresh": sum(e["packet_bytes"] for e in calls)/max(1,counts.get("refresh",0)),
        "pending_high_water": data["pending_high_water"], "generations": sorted(seen_generations), **durations}

def source_identity(engine):
    provenance_path = ROOT / ("godot/addons/cybersand_native/runtime-provenance.json" if platform.system() == "Windows"
        else "godot/addons/cybersand_native/runtime-provenance.linux.json")
    provenance = json.loads(provenance_path.read_text())
    native = {}
    for path, expected in provenance["source_inputs"].items():
        actual = hashlib.sha256((ROOT/path).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
        native[path] = {"expected": expected, "actual": actual}
    mismatches = [p for p,v in native.items() if v["actual"] != v["expected"]]
    if mismatches:
        raise ValueError("runtime native source mismatch: " + str(mismatches))
    runtime = ROOT / provenance["artifact"]
    if digest(runtime) != provenance["sha256"]: raise ValueError("runtime digest mismatch")
    files = [*ROOT.glob("godot/scripts/*.gd"), *ROOT.glob("godot/tests/render_publication*.gd"),
        ROOT/"godot/tests/run_render_publication.gd", ROOT/"godot/main.tscn", ROOT/"godot/project.godot",
        ROOT/"godot/shaders/material_palette.gdshader", Path(__file__)]
    return {"frozen_main": BASE, "head": git_value("HEAD"),
        "tree": git_value("HEAD^{tree}"),
        "source_hashes": {str(p.relative_to(ROOT)).replace("\\","/"):digest(p) for p in files},
        "native_source_inputs": native, "runtime_sha256": digest(runtime), "runtime_path":str(runtime),
        "engine_sha256":digest(engine), "engine_path":str(engine), "platform":platform.platform()}

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--engine", required=True, type=Path)
    p.add_argument("--output", required=True, type=Path)
    p.add_argument("--repeats", type=int, default=3)
    p.add_argument("--candidate", choices=["control","E"], default="control")
    a=p.parse_args()
    a.output.mkdir(parents=True,exist_ok=False)
    identity=source_identity(a.engine)
    (a.output/"inputs.json").write_text(json.dumps(identity,indent=2))
    results=[]
    for repeat in range(a.repeats):
        for arm in (["N","W"] if repeat%2 == 0 else ["W","N"]):
            receipt=a.output/f"{arm}-{repeat}.json"
            argv=[str(a.engine),"--audio-driver","Dummy","--path",str(ROOT/"godot"),"--resolution","960x540","--script",
                "res://tests/run_render_publication.gd","--",f"--arm={arm}",f"--receipt={receipt}",f"--candidate={a.candidate}"]
            start=time.monotonic()
            with receipt.with_suffix(".log").open("wb") as log:
                process=subprocess.Popen(argv,stdout=log,stderr=subprocess.STDOUT)
                try: code=process.wait(timeout=1200)
                except subprocess.TimeoutExpired:
                    process.terminate()
                    try: process.wait(timeout=30)
                    except subprocess.TimeoutExpired: process.kill(); process.wait(timeout=30)
                    code="timeout"
            row={"arm":arm,"repeat":repeat,"candidate":a.candidate,"argv":argv,"exit":code,"seconds":time.monotonic()-start,
                "log_sha256":digest(receipt.with_suffix(".log"))}
            log_text=receipt.with_suffix(".log").read_text(errors="replace")
            if "SCRIPT ERROR:" in log_text or "ERROR:" in log_text: row["reader_failure"]="engine error in log"
            if receipt.exists():
                row["raw_sha256"]=digest(receipt)
                row["png_sha256"]=digest(str(receipt)+".png")
                try:
                    raw=json.loads(receipt.read_text())
                    if raw["arm"]!=arm or raw["candidate"]!=a.candidate: raise ValueError("launched arm/candidate mismatch")
                    row["summary"]=reduce_trace(raw)
                except (ValueError,KeyError) as e: row["reader_failure"]=str(e)
            results.append(row)
            (a.output/"processes.json").write_text(json.dumps(results,indent=2))
            print(arm,repeat,code,row.get("summary",{}).get("counts",{}),flush=True)
    after=source_identity(a.engine)
    if after != identity: raise ValueError("source changed during campaign")
    report={"identity":identity,"processes":results}
    (a.output/"report.json").write_text(json.dumps(report,indent=2))
    if any(r["exit"] != 0 or "summary" not in r or "reader_failure" in r for r in results):
        raise SystemExit(1)

if __name__ == "__main__": main()
