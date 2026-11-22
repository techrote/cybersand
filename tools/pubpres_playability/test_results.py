#!/usr/bin/env python3
"""Adversarial checks for the versioned measurement boundary, not speed claims."""
import copy
import hashlib
import json
import os
from pathlib import Path
import struct
import tempfile
import unittest
import zlib
from types import SimpleNamespace
from unittest.mock import Mock, patch

from results import SNAPSHOT_CAPABILITIES, digest, reduce_receipt, window
from run_campaign import archive_identities, dependency_custody, engine_command, physical_outcome_parity, select_cases, verify_experimental_runtime


def snapshot(tick, sample, handoff, end, generation=7):
    return {"event":"worker_snapshot","start_usec":end-50,"time_usec":end,
        "world_generation":generation,"tick_index":tick,"completed_body_sample":sample,
        "physics_handoff_usec":handoff,"native_completed_usec":990 if tick==1 else 2690,
        "failed":False,"hard_surface_revision":9,"required_hard_revision":9,
        "native_tick_ms":1.0,"render_serial":tick,"copy_ms":.01,"publication_ms":.03,
        "wave_column_probe":None}


def step(tick, sample, handoff, end):
    return {"event":"rapier_step","start_usec":end-50,"time_usec":end,"step":tick,
        "native_tick_used":tick,"completed_body_sample":sample,"required_hard_revision":9,
        "physics_handoff_usec":handoff,"native_completed_usec":990 if tick==1 else 2690,
        "fixed_delta":1/60,"solver_usec":20,"observer_usec":3,"bodies":[{"contacts":0}],"response_refusal":""}


def fixture():
    events=[{"event":"native_completion_observed","time_usec":1000,"tick_index":1,"world_generation":7},
        {"event":"native_completion_observed","time_usec":2700,"tick_index":2,"world_generation":7},
        snapshot(1,2,100,500,generation=8),  # another World must never win
        snapshot(1,2,1200,1300),snapshot(1,2,1500,1700),snapshot(2,3,2800,2900),
        step(1,2,1500,2000),step(2,3,2800,3200)]
    for n,t in enumerate((500,1800,2500,3500)):
        events.append({"event":"main_callback","start_usec":t,"time_usec":t+10,
            "process_frame":n,"uploaded_generated_usec":-1})
    events += [{"event":"texture_upload","start_usec":2050,"time_usec":2100,
        "generated_usec":1900,"render_serial":7,"patch_bytes":32,"patch_count":1,"full_refresh":False},
        {"event":"framebuffer_draw","time_usec":2300,"render_serial":1},
        {"event":"framebuffer_draw","time_usec":3000,"render_serial":7}]
    return {"capture_start_usec":0,"observer_mode":"full","water_before":{"wave_flow":{}}},events


def complete_reader_fixture(folder):
    """Synthetic codec/adversary fixture only; never engine/performance evidence.

    Extends the independent reviewer's intentionally incomplete receipt so
    every rejection below changes one otherwise valid observation contract.
    """
    campaign=json.loads(Path(__file__).with_name("campaign-development-01-v2.json").read_text())
    tape=campaign["measurement"]["input_tape"]
    source={"source_sha":campaign["source_commits"]["main"],"engine_sha256":"e"*64,
        "files":{"res://"+k:v for k,v in campaign["overlay_sha256"].items()}}
    water={"water_ledger_healthy":True,"water_ledger":{"total":1,"expected":1,"visible":1,"overfill":0,"ballistic":0},"wave_flow":{},
        "construction":{"initial_body_state_sha256":"a"*64,"prepared_payload_hash":"b"*64,"prepared_setup_hash":"c"*64},
        "policy":{"policy_hash":"d"*64,"assignments":[{"material":3,"applied_family":"freemass_v1","applied_variant":"reference"}]}}
    selectors={"requested":{"CYBERSAND_MATERIAL_PUBLICATION":"full","CYBERSAND_DIAG_PHYSICS_PUBLICATION":"combined",
        "CYBERSAND_DIAG_PRESENTATION":"legacy","CYBERSAND_DIAG_MATERIAL_TIMING":"legacy"},"material":None,"physics":None,"presentation":None}
    roster=[{"actor_slot":0,"instance_id":1,"model":"needle","producer":"human", "bodies":[
        {"body_slot":0,"node_class":"RigidBody2D","body_rid":101,"bridge_rid":101,"node_instance_id":99}]}]
    data={"schema":"pubpres-playability-gameplay-v2","complete":True,"failures":[],
        "render_thread":{"runtime":"safe","requested":"safe"},"command_mode":"repeated_callback","observer_mode":"full",
        "gpu_history":{"current_matches_cpu":True,"previous_verified":False},
        "display":{"server":"X11","window":[1600,900],"fps_cap":60,"physics_callbacks_hz":60,"vsync_mode":0},
        "source_identity":source,"fixture":{"name":"basin512"},"input_tape":tape,"input_mode":"tape","input_events":[],
        "selectors_before":selectors,"selectors_after":selectors,"command_counts":{"attempted":144,"accepted":144,"rejected":0},
        "capture_physical_tick_start":0,"capture_native_tick_start":0,"capture_start_usec":1_000_000,"capture_end_usec":11_000_000,
        "water_before":water,"water_after":water,"workers":4,"water_law":"freemass_v1","water_variant":"reference",
        "water_profile":campaign["measurement"]["water_profile"],"process_id":123,"renderer":"opengl3","adapter":"synthetic","cpu":"synthetic",
        "logical_processors":1,"static_memory_peak_bytes":0,"video_memory_bytes":0,"actor_roster_before":roster,"actor_roster_after":copy.deepcopy(roster),
        "snapshot_capabilities":{k:False for k in SNAPSHOT_CAPABILITIES},
        "target_physical_steps":144,"minimum_capture_usec":10_000_000,"maximum_capture_usec":90_000_000,"setup_timeout_msec":240000,"maximum_events_per_owner":30000}
    rows=[{"event":"identity","source":source}]
    for tick in range(1,145):
        now=data["capture_start_usec"]+tick*60000
        selected=max(i for i,r in enumerate(tape) if r["tick"]<=tick-1)
        requested=tape[selected]["move"]
        admitted=[struct.unpack("!f",struct.pack("!f",v))[0] for v in requested]
        command={"event":"command_attempt","time_usec":now-1000,"accepted":True,"accepted_before":tick-1,"accepted_after":tick,
            "rejected_before":0,"rejected_after":0,"sequence_before":tick-1,"sequence_after":tick,"deadline_tick":tick+5,
            "absolute_tick":tick-1,"physical_tick":tick-1,"input_index":selected,"move":requested,"accepted_move":admitted,
            "instance_id":1,"actor_slot":0,"epoch":1,"producer":"human","ports":{"q":False,"e":False,"s":False,"boost":False},"fire":False}
        rows.append(command)
        if tape[selected]["tick"]==tick-1:
            data["input_events"].append({"input_index":selected,"requested_physical_tick":tick-1,"accepted_physical_tick":tick-1,
                "move":requested,"time_usec":command["time_usec"]+1})
        sample=-1 if tick==1 else tick
        if tick>1:rows.append({"event":"native_completion_observed","tick_index":tick-1,"time_usec":now-300,"world_generation":7,"body_sample":sample})
        rows.append({"event":"worker_snapshot","start_usec":now-250,"time_usec":now-100,"world_generation":7,"tick_index":tick-1,
            "completed_body_sample":sample,"native_completed_usec":None,"physics_handoff_usec":None,"failed":False,
            "hard_surface_revision":1,"required_hard_revision":1,"native_tick_ms":1,"render_serial":tick,"copy_ms":.01,"publication_ms":.03,
            "wave_column_probe":None,"water_ledger":water["water_ledger"],"water_ledger_healthy":True})
        rows.append({"event":"native_render_capture","start_usec":now-200,"time_usec":now-150,"force_full_requested":False,
            "status":1,"full_refresh":False,"serial":tick,"tick_index":tick-1,"bytes":32,"rectangle_values":6})
        rows.append({"event":"rapier_step","step":tick,"time_usec":now,"start_usec":now-50,"manual_steps":tick,"fixed_delta":1/60,
            "pending_hard_chunks":0,"required_hard_revision":1,"packet_hard_revision":1,"installed_hard_revision":1,"session":1,"epoch":1,
            "native_tick_used":tick-1,"completed_body_sample":sample,"native_completed_usec":None,"physics_handoff_usec":None,
            "bodies":[{"slot":0,"instance_id":1,"xy":[200,160+tick*.001],"angle":0,"velocity":[0,.01],"contacts":0}],
            "body_ownership":[{"slot":0,"body_rid":101}],"world_generation":7,"packet_failed":False,
            "world_generation_field":"render_world_generation","render_world_generation":7,
            "native_completed_source_usec":None,"physics_handoff_source_usec":None,
            "native_completion_world_generation":None,"native_completion_body_sample":None,
            "solver_usec":1,"observer_usec":3,"response_refusal":"","response_accepted":tick>1,"accepted_samples":[sample],
            "admitted_move":admitted,"command_sequence":tick,"command_deadline_tick":tick+5})
        rows.append({"event":"physics_callback","start_usec":now-50,"time_usec":now+10,"before_step":tick-1,"after_step":tick,"pending_hard_chunks":0})
        rows.append({"event":"main_callback","start_usec":now+20,"time_usec":now+80,"process_frame":tick,"uploaded_generated_usec":now-2000})
        rows.append({"event":"texture_upload","start_usec":now+25,"time_usec":now+40,"generated_usec":now-2000,
            "render_serial":tick,"patch_bytes":32,"patch_count":1,"full_refresh":False,"world_generation":7,"material":None})
        rows.append({"event":"framebuffer_draw","time_usec":now+100,"render_serial":tick})
    rows.append({"event":"worker_participation","time_usec":data["capture_start_usec"]+10000,"sample":{"workers_observed":1,"worker_capacity":4}})
    def chunk(kind,payload):return struct.pack(">I",len(payload))+kind+payload+struct.pack(">I",zlib.crc32(kind+payload)&0xffffffff)
    png=b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",1600,900,8,6,0,0,0))+chunk(b"IDAT",zlib.compress((b"\x00"+bytes(1600*4))*900,1))+chunk(b"IEND",b"")
    data["framebuffers"]=[]
    for label in ("before","after"):
        path=folder/("receipt-"+label+".png");path.write_bytes(png)
        data["framebuffers"].append({"label":label,"outside_timing":True,"sha256":digest(path),"width":1600,"height":900})
    def save():
        path=folder/"receipt-events.jsonl";path.write_text("\n".join(json.dumps(r) for r in rows)+"\n")
        data["trace_sha256"]=digest(path)
        receipt=folder/"receipt.json";receipt.write_text(json.dumps(data))
        return receipt
    return campaign,data,rows,save


class ClockTests(unittest.TestCase):
    def test_first_healthy_match_not_latest_status(self):
        data,events=fixture()
        r=window(events,data,4000)
        self.assertAlmostEqual(r["first_physics_handoff_to_rapier_ms"]["p50"],.6)
        self.assertAlmostEqual(r["first_observed_eligible_snapshot_to_rapier_ms"]["p50"],.5)
        self.assertAlmostEqual(r["native_exact_to_first_physics_handoff_ms"]["p50"],.16)
        self.assertAlmostEqual(r["first_physics_handoff_to_callback_start_ms"]["p50"],.55)

    def test_draw_delivery_does_not_claim_upload_identity(self):
        data,events=fixture()
        r=window(events,data,4000)
        self.assertAlmostEqual(r["upload_return_to_next_delivered_draw_callback_ms"]["p50"],.2)
        self.assertIn("no upload-specific",r["draw_clock_scope"])
        self.assertNotIn("upload_to_post_draw_callback_ms",r)

    def test_unavailable_legacy_clocks_are_null(self):
        data,events=fixture()
        for e in events:
            if "native_completed_usec" in e:e["native_completed_usec"]=None
            if "physics_handoff_usec" in e:e["physics_handoff_usec"]=None
        r=window(events,data,4000)
        self.assertIsNone(r["native_exact_to_first_physics_handoff_ms"])
        self.assertIsNone(r["first_physics_handoff_to_rapier_ms"])
        self.assertIsNone(r["wave_column_stage_counter_deltas"])

    def test_forged_chronology_fails(self):
        data,events=fixture()
        for e in events:
            if e.get("world_generation")==7 and e.get("event")=="worker_snapshot" and e["tick_index"]==1:
                e["physics_handoff_usec"]=900
        with self.assertRaisesRegex(ValueError,"follows its healthy mailbox"):window(events,data,4000)

    def test_reduced_observer_does_not_claim_zero_publications(self):
        data,events=fixture()
        data["observer_mode"]="reduced"
        events=[r for r in events if r["event"]=="rapier_step"]
        r=window(events,data,4000)
        self.assertIsNone(r["publication"])
        self.assertIsNone(r["native_capture"])
        self.assertIsNone(r["physical_callbacks_without_step"])
        self.assertEqual(r["completed_rapier_steps"],2)

    def test_missing_fields_remain_null_in_window(self):
        data,events=fixture()
        for row in events:
            if row["event"]=="rapier_step":row.pop("observer_usec")
            if row["event"]=="texture_upload":row["material"]={"mode":"blit"}
        r=window(events,data,4000)
        self.assertIsNone(r["rapier_observer_ms"])
        self.assertIsNone(r["publication"]["cpu_staging_submitted_bytes"])


class ReceiptTests(unittest.TestCase):
    def test_severe_initial_stall_remains_valid_negative_evidence(self):
        for offset, expected_steps in ((11_000_000, 0), (9_900_000, 1)):
            with self.subTest(prefix_steps=expected_steps), tempfile.TemporaryDirectory() as tmp:
                campaign,data,rows,save=complete_reader_fixture(Path(tmp))
                for row in rows:
                    for key in ("time_usec", "start_usec", "generated_usec", "uploaded_generated_usec"):
                        if key in row:
                            row[key] += offset
                for item in data["input_events"]:
                    item["time_usec"] += offset
                data["capture_end_usec"] += offset
                result=reduce_receipt(save(),campaign,arm_letter="M")
                prefix=result["windows"]["first_10s"]
                self.assertEqual(prefix["completed_rapier_steps"], expected_steps)
                self.assertEqual(prefix["rapier_steps_per_second"], expected_steps / 10)
                self.assertIsNone(prefix["physical_gap_ms"])
                self.assertEqual(prefix["first_step"], 1 if expected_steps else None)
                self.assertEqual(result["windows"]["whole_capture"]["completed_rapier_steps"], 144)
                self.assertGreaterEqual(prefix["physical_no_step_prefix_ms"], 9900)

    def test_complete_synthetic_contract(self):
        with tempfile.TemporaryDirectory() as tmp:
            campaign,data,rows,save=complete_reader_fixture(Path(tmp))
            result=reduce_receipt(save(),campaign,arm_letter="M")
            self.assertEqual(result["measurement_coverage"]["matched_step_command_count"],144)
            self.assertEqual(result["measurement_coverage"]["initial_pre_capture_native_steps"],[1])
            self.assertEqual(result["windows"]["whole_capture"]["completed_rapier_steps"],144)

    def test_missing_each_real_channel_rejected(self):
        for kind in ("worker_snapshot","texture_upload","framebuffer_draw","native_render_capture","native_completion_observed","main_callback","physics_callback","worker_participation"):
            with self.subTest(channel=kind),tempfile.TemporaryDirectory() as tmp:
                campaign,data,rows,save=complete_reader_fixture(Path(tmp))
                rows[:]=[r for r in rows if r["event"]!=kind]
                with self.assertRaisesRegex(ValueError,"missing a real"):reduce_receipt(save(),campaign,arm_letter="M")

    def test_actor_action_clock_and_cap_adversaries(self):
        mutations={
            "empty_body":lambda d,r:r.__setitem__("bodies",[]),
            "nonfinite_pose":lambda d,r:r["bodies"][0]["xy"].__setitem__(0,float("nan")),
            "different_body":lambda d,r:r["body_ownership"][0].__setitem__("body_rid",999),
            "missing_observer":lambda d,r:r.pop("observer_usec"),
            "wrong_admitted_move":lambda d,r:r.__setitem__("admitted_move",[.5,.5]),
            "wrong_sequence":lambda d,r:r.__setitem__("command_sequence",999),
            "wrong_deadline":lambda d,r:r.__setitem__("command_deadline_tick",999),
            "missing_response":lambda d,r:r.__setitem__("response_accepted",False),
            "after_capture":lambda d,r:r.__setitem__("time_usec",d["capture_end_usec"]+1),
            "hundred_seconds":lambda d,r:d.__setitem__("capture_end_usec",d["capture_start_usec"]+100_000_000),
        }
        for name,change in mutations.items():
            with self.subTest(adversary=name),tempfile.TemporaryDirectory() as tmp:
                campaign,data,rows,save=complete_reader_fixture(Path(tmp))
                row=[r for r in rows if r["event"]=="rapier_step"][20]
                change(data,row)
                with self.assertRaises(ValueError):reduce_receipt(save(),campaign,arm_letter="M")

    def test_transition_only_commands_and_fake_png_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);campaign,data,rows,save=complete_reader_fixture(folder)
            ticks={r["tick"] for r in data["input_tape"]}
            rows[:]=[r for r in rows if r["event"]!="command_attempt" or r["physical_tick"] in ticks]
            data["command_counts"]={"attempted":11,"accepted":11,"rejected":0}
            with self.assertRaisesRegex(ValueError,"actual admitted command"):reduce_receipt(save(),campaign,arm_letter="M")
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);campaign,data,rows,save=complete_reader_fixture(folder)
            image=folder/"receipt-before.png";image.write_bytes(b"synthetic-only")
            data["framebuffers"][0]["sha256"]=digest(image)
            with self.assertRaisesRegex(ValueError,"not a PNG"):reduce_receipt(save(),campaign,arm_letter="M")

    def test_early_mailbox_owner_and_bootstrap_sentinel(self):
        with tempfile.TemporaryDirectory() as tmp:
            campaign,data,rows,save=complete_reader_fixture(Path(tmp))
            data["source_identity"]["source_sha"]=campaign["source_commits"]["integration"]
            data["snapshot_capabilities"]={k:True for k in SNAPSHOT_CAPABILITIES}
            material={"requested_mode":"blit","backend":"blit","policy":"","fallback_reason":""}
            selectors={"requested":{"CYBERSAND_MATERIAL_PUBLICATION":"blit","CYBERSAND_DIAG_PHYSICS_PUBLICATION":"early",
                "CYBERSAND_DIAG_PRESENTATION":"coherent","CYBERSAND_DIAG_MATERIAL_TIMING":"measured"},
                "material":material,"physics":"early","presentation":"coherent","material_timing":"measured",
                "cadence":"repaired","rendezvous":{"mode":"off"}}
            data["selectors_before"]=selectors;data["selectors_after"]=copy.deepcopy(selectors)
            for row in rows:
                if row["event"]=="texture_upload":row["material"]=material
                if row["event"]!="rapier_step":continue
                bootstrap=row["step"]==1
                row.update(world_generation_field="physics_world_generation",render_world_generation=0,
                    native_completed_source_usec=-1 if bootstrap else row["time_usec"]-400,
                    native_completed_usec=None if bootstrap else row["time_usec"]-400,
                    physics_handoff_source_usec=row["time_usec"]-200,physics_handoff_usec=row["time_usec"]-200,
                    native_completion_world_generation=-1 if bootstrap else 7,
                    native_completion_body_sample=-1 if bootstrap else row["completed_body_sample"])
            result=reduce_receipt(save(),campaign,arm_letter="I")
            self.assertEqual(result["measurement_coverage"]["matched_step_command_count"],144)
            step_row=[r for r in rows if r["event"]=="rapier_step"][4]
            original=copy.deepcopy(step_row)
            step_row["world_generation"]=step_row["render_world_generation"]
            with self.assertRaises(ValueError):reduce_receipt(save(),campaign,arm_letter="I")
            step_row.update(original);step_row["native_completed_source_usec"]=-1;step_row["native_completed_usec"]=None
            with self.assertRaisesRegex(ValueError,"clock missing, negative"):reduce_receipt(save(),campaign,arm_letter="I")
            step_row.update(original)
            for row in rows:
                if row["event"]=="native_completion_observed":row["body_sample"]=-999
            with self.assertRaisesRegex(ValueError,"another body sample"):reduce_receipt(save(),campaign,arm_letter="I")


class RegistrationTests(unittest.TestCase):
    def test_diagnostics_use_registered_cases_and_order(self):
        campaign=json.loads(Path(__file__).with_name("campaign-development-01-v2.json").read_text())
        cases,registration=select_cases(campaign,[],False,"render_thread_calibration")
        self.assertEqual({c["id"] for c in cases},set(campaign["render_thread_calibration"]["cases"]))
        self.assertEqual(len(cases),6)
        self.assertEqual(registration["order"],["safe","separate","separate","safe"])
        for diagnostic in ("observer_calibration","input_equivalence","native_probe_calibration"):
            with self.subTest(diagnostic=diagnostic):
                with self.assertRaisesRegex(ValueError,"requires --development"):
                    select_cases(campaign,["freemass_512_free"],False,diagnostic)
                self.assertEqual(select_cases(campaign,["freemass_512_free"],False,diagnostic,True)[0][0]["id"],"freemass_512_free")
        wrong=copy.deepcopy(campaign);wrong["calibration"]["order"].reverse();wrong["calibration"]["order"][0]="reduced"
        with self.assertRaisesRegex(ValueError,"source/order"):
            select_cases(wrong,[],False,"observer_calibration")

    @unittest.skipIf(os.name=="nt","Display wrappers are a Linux-only path")
    def test_display_wrapper_interpreter_selection(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);shell=folder/"xvfb-run";shell.write_text("#!/bin/sh\nexit 0\n");shell.chmod(0o755)
            python=folder/"display.py";python.write_text("pass\n")
            self.assertEqual(engine_command("Godot",["--test"],shell),[str(shell),"-a","-s","-screen 0 1920x1080x24","Godot","--test"])
            self.assertEqual(engine_command("Godot",["--test"],python)[1:],[str(python),"Godot","--test"])


class RuntimeTests(unittest.TestCase):
    def test_runtime_source_identity_and_complete_closure(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)/"source";out=Path(tmp)/"runtime";out.mkdir()
            (root/"native/include").mkdir(parents=True)
            (root/"native/src").mkdir(parents=True)
            (root/"godot/native_extension").mkdir(parents=True)
            code=root/"native/include/world.hpp";code.write_bytes(b"// exact\n")
            (root/"tools").mkdir()
            build_script="tools/build_native_extension_windows.sh" if os.name == "nt" else "tools/build_native_extension.sh"
            (root/build_script).write_bytes(b"exit 0\n")
            runtime_file="cybersand_native.windows.x86_64.dll" if os.name == "nt" else "libcybersand_native.linux.x86_64.so"
            binary=out/runtime_file;binary.write_bytes(b"binary")
            (out/"build.log").write_bytes(b"successful isolated build\n")
            digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
            driver=Path(__file__).resolve().parents[1]/"pubpres_playability_build/build_runtime.py"
            platform="windows" if os.name=="nt" else "linux"
            (out/"GODOT-CPP-BUILD.log").write_text("synthetic dependency build\n")
            (out/"GODOT-CPP-BUILD.sh").write_text("synthetic dependency builder\n")
            (out/"GODOT-CPP-CXX.sh").write_text("synthetic dependency helper\n")
            dependency={"schema":"pubpres-godot-cpp-dependency-v1","platform":platform,
                "source_commit":dependency_custody.REVISION,"source_tree":"f"*40,"builder_commit":"e"*40,
                "library_sha256":"d"*64,"source_inputs_sha256":{name:"b"*64 for name in sorted(dependency_custody.REQUIRED)},
                "builder_inputs_sha256":{"tools/build_pinned_godot_cpp.sh":digest(out/"GODOT-CPP-BUILD.sh"),
                                          "tools/toolchains/g++":digest(out/"GODOT-CPP-CXX.sh")},
                "build_log_sha256":digest(out/"GODOT-CPP-BUILD.log"),"build_script_sha256":digest(out/"GODOT-CPP-BUILD.sh"),
                "command":"Pinned godot-cpp "+platform+" build command: synthetic fixture"}
            (out/"GODOT-CPP-DEPENDENCY.json").write_text(json.dumps(dependency))
            source={"source_commit":"a"*40,"source_tree":"b"*40}
            record={"schema":"pubpres-playability-native-build-v1","returncode":0,**source,
                "platform":platform,"runtime_file":binary.name,"runtime_bytes":6,"runtime_sha256":digest(binary),
                "source_inputs_sha256":{"native/include/world.hpp":digest(code)},"build_script":build_script,"build_script_sha256":digest(root/build_script),
                "godot_cpp_commit":dependency_custody.REVISION,"godot_cpp_library_sha256":"d"*64,
                "godot_cpp_dependency_sha256":digest(out/"GODOT-CPP-DEPENDENCY.json"),
                "compiler_command":"g++","compiler_version":"pinned","toolchain_drift_allowed":False,
                "production_runtime_promotion":False,"driver_sha256":hashlib.sha256(driver.read_bytes().replace(b"\r\n",b"\n")).hexdigest(),"log_sha256":digest(out/"build.log"),
                "driver_inputs_sha256":{name:hashlib.sha256((driver.parent/name).read_bytes().replace(b"\r\n",b"\n")).hexdigest() for name in dependency_custody.DRIVER_FILES}}
            path=out/"PUBPRES-RUNTIME.json"
            def save():path.write_text(json.dumps(record))
            save()
            with patch("run_campaign.git",return_value="native/include/world.hpp"):
                self.assertEqual(verify_experimental_runtime(root,source,out)["checked_source_files"],1)
                binary.write_bytes(b"forged")
                with self.assertRaisesRegex(ValueError,"binary hash/size"):verify_experimental_runtime(root,source,out)
                binary.write_bytes(b"binary")
                record["source_commit"]="e"*40;save()
                with self.assertRaisesRegex(ValueError,"another source HEAD/tree"):verify_experimental_runtime(root,source,out)
                record.update(source);save()
                expected_dependency=record["godot_cpp_dependency_sha256"]
                record["godot_cpp_dependency_sha256"]="0"*64;save()
                with self.assertRaisesRegex(ValueError,"Dependency custody"):verify_experimental_runtime(root,source,out)
                record["godot_cpp_dependency_sha256"]=expected_dependency
                expected_driver=record["driver_inputs_sha256"].pop("process_owner.py");save()
                with self.assertRaisesRegex(ValueError,"driver module closure"):verify_experimental_runtime(root,source,out)
                record["driver_inputs_sha256"]["process_owner.py"]=expected_driver;save()
                (root/"native/src/unreported.cpp").write_text("// new source\n")
                with self.assertRaisesRegex(ValueError,"closure differs"):verify_experimental_runtime(root,source,out)

    def test_archive_uses_verified_package_and_exact_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            package=Path(tmp)/"package";package.mkdir()
            manifest=package/"PUBPRES-PLAYABILITY-MANIFEST.json";manifest.write_text("{}")
            expected="a"*40
            engine=package/"Godot.exe";campaign=package/"tools/pubpres_playability/campaign.json"
            roots={letter:package/"sources"/letter for letter in "MIC"}
            record={"engine":{"gui":{"path":"Godot.exe"}},"campaign":"tools/pubpres_playability/campaign.json","sources":{}}
            for letter,root in roots.items():
                provenance=root/"provenance";provenance.mkdir(parents=True)
                receipt=provenance/"PUBPRES-RUNTIME.json"
                receipt.write_text(json.dumps({"runtime_file":"native.dll","source_inputs_sha256":{"native/src/x.cpp":"b"*64}}))
                record["sources"][letter]={"root":"sources/"+letter,"source_commit":expected,"source_tree":"c"*40,"source_projection":"committed source with disclosed runtime additions",
                    "native":{"receipt":receipt.relative_to(package).as_posix(),"path":"sources/"+letter+"/godot/native.dll","sha256":"d"*64},"toolchain":{"compiler":"same"}}
            verify=Mock(return_value=record)
            module=SimpleNamespace()
            spec=SimpleNamespace(loader=SimpleNamespace(exec_module=lambda target:setattr(target,"verify",verify)))
            with patch("importlib.util.spec_from_file_location",return_value=spec),patch("importlib.util.module_from_spec",return_value=module):
                result=archive_identities(manifest,expected,roots,engine,campaign,Path(tmp)/"evidence")
                verify.assert_called_once_with(package.resolve(),expected)
                self.assertTrue(result["C"]["qualified_source_archive"])
                self.assertIsNone(result["C"]["qualified_exact_head"])
                with self.assertRaisesRegex(ValueError,"source root differs"):
                    archive_identities(manifest,expected,{**roots,"C":roots["M"]},engine,campaign,Path(tmp)/"evidence")
                with self.assertRaisesRegex(ValueError,"direct Godot"):
                    archive_identities(manifest,expected,roots,package/"console.exe",campaign,Path(tmp)/"evidence")
                with self.assertRaisesRegex(ValueError,"outside the pristine"):
                    archive_identities(manifest,expected,roots,engine,campaign,package/"evidence")
                with self.assertRaisesRegex(ValueError,"expected-candidate"):
                    archive_identities(manifest,None,roots,engine,campaign,Path(tmp)/"evidence")


class OutcomeTests(unittest.TestCase):
    def test_source_difference_disclosed_but_same_source_divergence_refused(self):
        def arm(letter,index,body):
            return {"arm":letter,"index":index,"statistics":{"source":letter*40,
                "match":{"water_law":"wave_flow_v1","water_profile":"registered"},
                "first_144_body_trajectory_sha256":body,"first_144_admitted_moves_sha256":"same",
                "command_counts":{"attempted":500+index,"accepted":500+index,"rejected":0},"command_mode":"repeated_callback"}}
        values=[arm("M",0,"old"),arm("C",1,"new"),arm("C",2,"new"),arm("M",3,"old")]
        result=physical_outcome_parity(values)
        self.assertTrue(result["same_source_pairs_equal"])
        self.assertTrue(any(not p["same_source"] and not p["bodies_equal"] for p in result["pairs"]))
        values[2]["statistics"]["first_144_body_trajectory_sha256"]="divergent"
        self.assertFalse(physical_outcome_parity(values)["same_source_pairs_equal"])


if __name__=="__main__":unittest.main()
