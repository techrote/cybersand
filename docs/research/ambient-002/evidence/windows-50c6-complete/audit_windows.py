"""Independent read-only audit of exact hosted Windows records and an inner ZIP.

This program never launches Godot or substitutes for the actual extracted
Windows execution. It streams package members to bound local memory use.
"""
from __future__ import annotations
import argparse, hashlib, json, pathlib, re, struct, zipfile

GUI_SHA = "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8"
CONSOLE_SHA = "d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c"
NATIVE_SHA = "668f2dd094fca611a97c2b6aa38c4cd072179fe9cf591e53578ef57c7db1625e"
RAPIER_SHA = "b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7"

def sha_stream(stream):
    h = hashlib.sha256()
    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
        h.update(chunk)
    return h.hexdigest()

def sha(path):
    with path.open("rb") as f:
        return sha_stream(f)

def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

def process(folder, row):
    assert row["status"] == "passed" and row["exit_code"] == 0
    assert sha(folder / "process.json") == row["process_sha256"]
    assert sha(folder / "process.log") == row["log_sha256"]
    original = read(folder / "process.json")
    assert all(row[k] == v for k,v in original.items())
    if "report_sha256" in row:
        assert sha(folder / "report.json") == row["report_sha256"]
    return {"name":folder.name,"process_sha256":row["process_sha256"],
            "log_sha256":row["log_sha256"],"exit_code":0,
            "pid":row["pid"],"seconds":row["seconds"],
            **({"report_sha256":row["report_sha256"]} if "report_sha256" in row else {})}

def completed_from_original(name, folder, contract):
    text = re.sub(r"\x1b\[[0-9;]*m", "", (folder / "process.log").read_text(encoding="utf-8",errors="replace"))
    assert "SKIP WB_ACTOR_COMPOSE" not in text
    if name in contract["TERMINALS"]:
        prefix = contract["TERMINALS"][name] + " "
        lines = [line[len(prefix):] for line in text.splitlines() if line.startswith(prefix)]
        assert len(lines) == 1
        result = json.loads(lines[0]); checks,failures = result.get("checks"),result.get("failures")
    else:
        found = re.findall(contract["TEXT_TERMINALS"][name], text, flags=re.MULTILINE)
        assert len(found) == 1
        checks,failures = map(int,found[0])
    assert type(checks) is int and checks > 0
    assert failures == [] or type(failures) is int and failures == 0
    if name in contract["REPORTS"]:
        original = read(folder / "report.json")
        assert original["checks"] == checks and original["failures"] in ([],0)
    return {"checks":checks,"failures":0}

def campaign(folder, expected_source, expected_tree, contract):
    q = read(folder / "qualification.json")
    assert q["status"] == q["input_custody"] == "passed"
    assert q["platform"] == "win32" and q["local_delta"] == []
    assert q["source_commit"] == expected_source and q["source_tree"] == expected_tree
    assert q["source_inputs_sha256"]["tools/qualify_ambient_living.py"] == contract["qualifier_sha256"]
    assert q["godot"]["sha256"] == CONSOLE_SHA and q["godot"]["gui_sha256"] == GUI_SHA
    assert q["runtime"]["cybersand_runtime"]["sha256"] == NATIVE_SHA
    assert q["runtime"]["rapier_runtime"]["sha256"] == RAPIER_SHA
    assert q["runtime"]["runtime_source_commit"] == "c53fd6f9d3d0f2b3f39396c7e605654f65c17299"
    custody = [process(folder / "import", q["import"])]
    cases = []
    assert len({c["name"] for c in q["cases"]}) == len(q["cases"])
    for c in q["cases"]:
        custody.append(process(folder / c["name"],c))
        assert c["completion"] == completed_from_original(c["name"],folder / c["name"],contract)
        assert c["completion"]["checks"] > 0 and c["completion"]["failures"] == 0
        if "checks" in c: assert c["checks"] == c["completion"]["checks"]
        cases.append({"name":c["name"],"checks":c["completion"]["checks"],"failures":0,"seconds":c["seconds"]})
    summary = {"status":"passed","input_custody":"passed","platform":"win32",
               "complete_campaign":q["complete_campaign"],"elapsed_seconds":q["elapsed_seconds"],
               "qualification_sha256":sha(folder / "qualification.json"),"cases":cases,
               "checks":sum(c["checks"] for c in cases),"original_process_custody":custody}
    if any(c["name"] == "living_editor" for c in cases):
        editor = read(folder / "living_editor/report.json")
        assert editor["failures"] in ([],0)
        live = editor["live_audition"]
        assert live["resume_configuration_unchanged"] and live["unapplied_configuration_unchanged"]
        assert live["unapplied_generation"] == live["playing_generation"]
        assert live["playing_generation"] > live["paused_generation"]
        assert live["applied_generation"] > live["unapplied_generation"]
        summary["live_editor"] = {"checks":editor["checks"],"failures":0,"live_audition":live}
    if q.get("graphical"):
        g = q["graphical"]
        custody.append(process(folder / "graphical",g["process"]))
        assert q["headless"] is False
        report_path = folder / "captures/capture-report.json"
        assert sha(report_path) == g["report_sha256"]
        captured = read(report_path)
        assert captured["failures"] == [] and captured["source_revision"] == expected_source
        assert captured["engine_sha256"] == GUI_SHA
        assert captured["display"] == "Windows" and captured["renderer"]
        assert captured["rendering_method"] == "gl_compatibility" and captured["rendering_driver"] == "opengl3_angle"
        assert len(captured["phases"]) == len(contract["EXAMPLES"]) == 11
        assert {p["example"] for p in captured["phases"]} == set(contract["EXAMPLES"])
        for phase in captured["phases"]:
            assert phase["passed"]
            assert phase["physical_ticks"] >= phase["requested_physical_ticks"]
            assert phase["native_ticks"] >= phase["requested_physical_ticks"]-1
        inventory = {}
        for name,digest in g["images_sha256"].items():
            p = folder / "captures" / name
            assert pathlib.Path(name).name == name and sha(p) == digest
            with p.open("rb") as f: header=f.read(24)
            assert header[:8] == b"\x89PNG\r\n\x1a\n"
            dimensions = list(struct.unpack(">II",header[16:24]))
            assert all(0 < n <= 8192 for n in dimensions)
            inventory[name] = {"sha256":digest,"bytes":p.stat().st_size,"dimensions":dimensions}
        assert len(inventory) == 29 and len(captured["captures"]) == 29
        expected_images={name+suffix+".png" for name in contract["EXAMPLES"] for suffix in ("-authored","-playing")}
        expected_images.update({"ambient-oil-water-overlay.png","ambient-behaviour-profile-editor.png",
            "ambient2-settlement-overlay.png","ambient2-behaviour-profile-editor.png",
            "ambient2-personality-settings.png","ambient2-places-and-peers.png","ambient2-library-and-group.png"})
        assert set(inventory)==expected_images
        recorded_names=[pathlib.PureWindowsPath(c["path"]).name for c in captured["captures"]]
        assert len(recorded_names)==len(set(recorded_names))==29
        assert set(recorded_names)==expected_images
        available = 0
        for c in captured["captures"]:
            frame,material = c["rendered_actor_frame"],c["material_display"]
            if frame["available"]:
                assert frame["world_generation"] == material["generation"] and frame["revision"] == material["revision"]
                available += 1
        new_phases=[p for p in captured["phases"] if p["example"].startswith("ambient2-")]
        assert len(new_phases)==6
        timings={
            "wall_seconds":[p["wall_usec"]/1_000_000 for p in new_phases],
            "mean_draw_interval_ms":[p["draw_intervals"]["mean_usec"]/1000 for p in new_phases],
            "p95_draw_interval_ms":[p["draw_intervals"]["p95_usec"]/1000 for p in new_phases]}
        timing_ranges={k:{"minimum":min(v),"maximum":max(v)} for k,v in timings.items()}
        summary["graphical"] = {"display":captured["display"],"renderer":captured["renderer"],
            "renderer_vendor":captured.get("renderer_vendor"),"rendering_method":captured["rendering_method"],
            "rendering_driver":captured["rendering_driver"],"report_sha256":g["report_sha256"],
            "images":inventory,"phases":captured["phases"],"matched_displayed_actor_frames":available,
            "capture_record_inventory_exact":True,"six_new_scene_timing_ranges":timing_ranges,
            "owner_playfeel_accepted":False}
    return q,summary

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--evidence",type=pathlib.Path,required=True)
    ap.add_argument("--portable",type=pathlib.Path,required=True)
    ap.add_argument("--source",required=True)
    ap.add_argument("--tree",required=True)
    ap.add_argument("--contract",type=pathlib.Path,required=True)
    ap.add_argument("--job-log",type=pathlib.Path,required=True)
    ap.add_argument("--output",type=pathlib.Path,required=True)
    args=ap.parse_args()
    assert re.fullmatch(r"[0-9a-f]{40}",args.source) and re.fullmatch(r"[0-9a-f]{40}",args.tree)
    contract=read(args.contract)
    assert contract["source_commit"] == args.source
    records,summary={},{}
    for name in ("ambient","ambient-graphical","extracted-package","extracted-graphical"):
        matches=[p.parent for p in args.evidence.rglob("qualification.json") if p.parent.name==name]
        assert len(matches)==1,(name,matches)
        records[name],summary[name]=campaign(matches[0],args.source,args.tree,contract)
    primary=records["ambient"]
    assert primary["complete_campaign"] and len(primary["cases"])==24
    assert {c["name"] for c in primary["cases"]}=={c[0] for c in contract["CASES"]}
    expected_extracted={"living_engine","living_spatial","living_authoring_save","living_authoring_reopen",
                        "living_editor","living_group","living_examples","living_episodes"}
    assert {c["name"] for c in records["extracted-package"]["cases"]}==expected_extracted
    for q in records.values():
        for key in ("source_commit","source_tree","source_inputs_sha256","project_inputs_sha256","runtime"):
            assert q[key]==primary[key],key
        for key in ("version","sha256","gui_sha256"):
            assert q["godot"][key]==primary["godot"][key],key
    with zipfile.ZipFile(args.portable) as z:
        members=[m.filename for m in z.infolist() if not m.is_dir()]
        assert len(members)==len(set(members))
        for name in members:
            p=pathlib.PurePosixPath(name)
            assert not p.is_absolute() and '..' not in p.parts
        with z.open("evaluation-manifest.json") as f: manifest_bytes=f.read()
        m=json.loads(manifest_bytes)
        assert m["schema_version"]==1 and m["kind"]=="ambient-002-owner-evaluation"
        assert m["qualification_platform"]=="win32" and m["windows_execution_qualified"]
        assert m["owner_playfeel_accepted"] is False and m["disposition"]=="Draft/HOLD"
        for key in ("source_commit","source_tree","source_inputs_sha256","runtime"):
            assert m[key]==primary[key],key
        assert m["qualification_sha256"]==summary["ambient"]["qualification_sha256"]
        assert set(members)==set(m["files_sha256"])|{"evaluation-manifest.json"}
        total_bytes=0
        for name,expected in m["files_sha256"].items():
            with z.open(name) as f: assert sha_stream(f)==expected,name
            total_bytes+=z.getinfo(name).file_size
        omitted=m.get("regenerated_imports_omitted",{})
        for relative,qualified_digest in primary["project_inputs_sha256"].items():
            name="godot/"+relative
            if name in m["files_sha256"]:
                assert m["files_sha256"][name]==qualified_digest,name
            else:
                assert omitted.get(name)==qualified_digest and name.endswith(".import"),name
                assert name.removesuffix(".import") in m["files_sha256"],name
        assert m["files_sha256"]["Godot_v4.7-stable_win64.exe"]==GUI_SHA
        assert m["files_sha256"]["Godot_v4.7-stable_win64_console.exe"]==CONSOLE_SHA
        assert m["files_sha256"][m["runtime"]["cybersand_runtime"]["path"]]==NATIVE_SHA
        assert m["files_sha256"][m["runtime"]["rapier_runtime"]["path"]]==RAPIER_SHA
        assert len(m["ambient_examples_sha256"])==11
        for name,expected in m["ambient_examples_sha256"].items():
            assert m["files_sha256"]["godot/examples/workbench/"+name]==expected
        with z.open("godot/data/ambient/profiles.json") as f: profiles=json.load(f)
        catalogue=profiles["profiles"] if isinstance(profiles,dict) else profiles
        assert len(catalogue)==16
        assert "Open Workbench.cmd" in members
        assert "docs/operations/ambient-living-workbench.md" in members
        assert "docs/systems/ambient-living-inhabitants.md" in members
        package={"name":args.portable.name,"bytes":args.portable.stat().st_size,"sha256":sha(args.portable),
                 "manifest_sha256":hashlib.sha256(manifest_bytes).hexdigest(),
                 "payload_files_independently_hash_checked":len(m["files_sha256"]),
                 "payload_uncompressed_bytes":total_bytes,"unexpected_members":0,
                 "zip_crc_integrity":"passed while streaming every member",
                 "qualification_platform":"win32","owner_playfeel_accepted":False}
    launches=list(args.evidence.rglob("packaged-launcher.stdout.log"))
    assert len(launches)==1
    stdout_path=launches[0];stderr_path=stdout_path.with_name("packaged-launcher.stderr.log")
    stdout=stdout_path.read_text(encoding="utf-8-sig");stderr=stderr_path.read_text(encoding="utf-8-sig")
    assert "SHARED_WORKBENCH_LAUNCH_READY" in stdout
    assert not re.search(r"SCRIPT ERROR:|Parse Error:|Failed to load script|ERROR:",stdout+stderr)
    assert not stderr.strip()
    # The unchanged workflow prints the pristine verifier before extraction
    # testing, and the complete original-input verifier again after the launcher.
    # Keep that original hosted stdout in addition to the launcher readiness log.
    job_text=args.job_log.read_text(encoding="utf-8",errors="replace")
    verifications=[]
    for line in job_text.splitlines():
        match=re.search(r'(\{"verified":\s*true,.*\})\s*$',line)
        if not match:continue
        try: item=json.loads(match[1])
        except json.JSONDecodeError:continue
        if item.get("source_commit")==args.source:
            assert item["files"]==package["payload_files_independently_hash_checked"]
            verifications.append(item)
    assert len(verifications)==2,"Missing original pristine or post-launch input-verifier stdout"
    result={"schema":"ambient2-windows-originals-independent/v1","status":"passed",
            "reviewer":"Specialist C; read-only original artifact and payload audit, not a new physical execution",
            "reader_sha256":sha(pathlib.Path(__file__)),"source_commit":args.source,"source_tree":args.tree,
            "qualification_contract_sha256":sha(args.contract),
            "portable_zip":package,"campaigns":summary,
            "cross_campaign_identity":{"source_inputs":len(primary["source_inputs_sha256"]),
                "project_inputs":len(primary["project_inputs_sha256"]),
                "all_four_source_tree_inputs_runtime_engine_equal":True,
                "original_and_extracted_images_need_not_be_byte_identical":True},
            "runtime":primary["runtime"],"godot":primary["godot"],
            "ordinary_launcher":{"ready_marker_observed":True,"stderr_empty_except_whitespace":True,
                "stdout_sha256":sha(stdout_path),"stderr_sha256":sha(stderr_path),"error_markers_observed":False,
                "original_job_log_sha256":sha(args.job_log),"pristine_and_post_launch_verifications":verifications},
            "limits":["This audit consumes completed original Windows and extracted-package receipts.",
                      "Visual frame inspection is recorded separately; hashes alone do not establish playfeel.",
                      "No physical NVIDIA or monitor acceptance; no cross-platform trajectory bit-determinism claim."]}
    args.output.write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps({"status":"passed","payload_files":package["payload_files_independently_hash_checked"],
                     "campaign_checks":{k:v["checks"] for k,v in summary.items()},
                     "graphical_images":sum(len(v.get("graphical",{}).get("images",{})) for v in summary.values())},indent=2))

if __name__=="__main__":main()
