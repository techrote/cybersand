#!/usr/bin/env python3
"""Adverse controls for the independent input-custody reducer (synthetic only)."""
from __future__ import annotations

from copy import deepcopy
import hashlib
import io
import json
from pathlib import Path
import struct
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import zlib

import pace004_contract as c
import run_pace004_campaign as campaign


class Tape:
    """Small explicit observations, never an engine-behaviour qualification."""
    def __init__(self):
        self.clock=1_000_000;self.rows=[];self.n=0;self.applied={k:False for k in c.BUTTONS}
        self.command={"move":[0,0],"trim":0,"primary":False,"secondary":False,"auxiliary":False}
        self.s={"worker":-9223372036854775500,"session":43,"bridge":-9223372036854775400,
            "run_id":"synthetic-old","epoch":1,"generation":1,"world_generation":1,"sequence":-1,
            "tick":0,"step":0,"native_tick":0,"serial":1,"backend":"native-phased","native_paused":False,
            "paused":False,"suspended":False,"focus":True,"rearm":False,"pending":False,
            "accepted":0,"rejected":0,"edges":[],"action":deepcopy(self.command),"position":[10,20],
            "impulse":[0,0],"torque_impulse":0,"lap_ticks":0,"fault":"","render_rejections":0}

    def snap(self):
        self.clock+=1000
        return deepcopy(self.s)|{"time_usec":self.clock}

    def append(self,row):
        self.rows.append(row|{"ordinal":len(self.rows)+1})

    def cancel(self):
        self.s["generation"]+=1;self.s["edges"]=[];self.s["rearm"]=True
        self.applied={k:False for k in c.BUTTONS};self.command={"move":[0,0],"trim":0,**self.applied}
        self.s["action"]=deepcopy(self.command)

    def event(self):
        self.n+=1;key,pressed,outcome=c.EXPECTED[self.n-1]
        a=self.snap();aa=self.snap();event={"key":key,"pressed":pressed}
        if outcome=="refused":
            if self.s["paused"] or not self.s["focus"]:self.cancel()
        else:
            self.s["rearm"]=False
            self.s["accepted"]+=1;self.s["sequence"]+=1
            component,value=c.expected_component(event,"acrobat");self.command[component]=value
            if key in c.BUTTONS:self.s["edges"].append({"button":key,"pressed":pressed})
        ab=self.snap();b=self.snap()
        self.append({"kind":"event","id":self.n,"key":key,"pressed":pressed,"expected":outcome,
            "before":a,"after":b,"handler_calls":1,
            "admissions":[{"before":aa,"after":ab,"command":deepcopy(self.command)}]})

    def physics(self):
        started=self.clock+1;a=self.snap();aa=self.snap()
        if not self.s["focus"] or self.s["paused"]:self.cancel()
        elif not self.s["rearm"] and not self.s["pending"]:
            self.s["accepted"]+=1;self.s["sequence"]+=1
        ab=self.snap();admission={"before":aa,"after":ab,"command":deepcopy(self.command)}
        if not self.s["paused"] and not self.s["pending"]:
            changed=set()
            while self.s["edges"] and self.s["edges"][0]["button"] not in changed:
                edge=self.s["edges"].pop(0);changed.add(edge["button"]);self.applied[edge["button"]]=edge["pressed"]
            self.s["action"]=deepcopy(self.command)|self.applied
            self.s["tick"]+=1;self.s["step"]+=1;self.s["native_tick"]+=1;self.s["serial"]+=1
        b=self.snap()
        self.append({"kind":"physics","before":a,"after":b,"started_usec":started,"ended_usec":b["time_usec"]-1,
            "admission":admission,"rapier_ms":0.2,"sampling":self.n<=16})

    def transition(self,name,before,details=None):
        self.append({"kind":"transition","name":name,"before":before,"after":self.snap(),"details":details or {}})


def fixture():
    t=Tape()
    for _ in range(4):t.event();t.physics()
    for _ in range(3):t.event();t.event();t.physics();t.physics()
    for _ in range(4):t.event();t.physics()
    t.event();t.event();t.physics();t.physics()
    assert t.n==16
    a=t.snap();t.s["paused"]=True;t.s["suspended"]=True;t.s["native_paused"]=True;t.cancel();t.s["serial"]+=1
    t.transition("pause_acknowledged",a)
    a=t.snap();t.clock+=350000;t.transition("paused_window",a)
    a=t.snap();t.s["paused"]=False;t.s["suspended"]=False;t.s["native_paused"]=False;t.s["rearm"]=False
    t.physics();t.physics();t.transition("resume_completed",a)
    t.event();t.event();a=t.snap();t.cancel();t.transition("rapid_pause",a)
    t.event();t.physics();t.physics()
    for _ in range(3):t.event();t.physics()
    assert t.n==22
    t.event();t.event();a=t.snap();t.s["focus"]=False;t.transition("focus_lost",a)
    t.physics();t.physics();t.event();t.event();a=t.snap();t.s["focus"]=True;t.s["rearm"]=False
    t.physics();t.transition("focus_regained",a)
    t.event();t.physics();t.event();t.physics()
    assert t.n==28
    t.event();t.event();a=t.snap();t.s["pending"]=True;t.s["paused"]=True;t.transition("reset_requested",a)
    t.s.update(session=44,bridge=-9223372036854775399,run_id="synthetic-new",epoch=2,world_generation=2,
               generation=1,tick=0,step=0,native_tick=0,sequence=-1,accepted=0,rejected=0,
               paused=True,suspended=True,native_paused=True,pending=False,edges=[],rearm=True)
    t.command={"move":[0,0],"trim":0,**{k:False for k in c.BUTTONS}};t.s["action"]=deepcopy(t.command)
    t.applied={k:False for k in c.BUTTONS}
    t.transition("reset_completed",a,{"old_session_retired":True})
    t.event();t.event();t.s.update(paused=False,suspended=False,native_paused=False,rearm=False)
    t.physics();t.event();t.physics();t.event();t.physics()
    for _ in range(3):t.event();t.event();t.physics();t.physics()
    assert t.n==40
    return t.rows


class InputCustody(unittest.TestCase):
    def setUp(self):self.trace=fixture()
    def event(self,n):return next(r for r in self.trace if r.get("kind")=="event" and r.get("id")==n)
    def transition(self,name):return next(r for r in self.trace if r.get("name")==name)
    def physics_after(self,n):
        ordinal=self.event(n)["ordinal"]
        return next(r for r in self.trace if r["kind"]=="physics" and r["ordinal"]>ordinal)
    def reject(self,pattern):
        with self.assertRaisesRegex(ValueError,pattern):c.verify_trace(self.trace,"acrobat")

    def test_positive_exact_signed_identity_and_full_inventory(self):
        result=c.verify_trace(self.trace,"acrobat")
        self.assertEqual(result["counts"],{"applied":29,"cancelled":6,"refused":5})
        self.assertEqual([r["id"] for r in result["outcomes"]],list(range(1,41)))
        self.assertTrue(all(r["completed_step"] is not None for r in result["outcomes"] if r["outcome"]=="applied"))

    def test_counter_only_non_neutral_loss_rejected(self):
        self.physics_after(1)["after"]["action"]["move"]=[0,0]
        self.reject("not applied by next completed step")

    def test_intended_event_not_admitted_rejected(self):
        self.event(1)["admissions"][0]["command"]["move"]=[0,0]
        self.reject("not admitted")

    def test_quick_edge_consumption_without_applied_action_rejected(self):
        self.physics_after(6)["after"]["action"]["primary"]=False
        self.reject("Consumed edge was not actually applied")

    def test_increasing_session_clock_without_rapier_step_rejected(self):
        self.physics_after(1)["after"]["step"]-=1
        self.reject("Unbound or duplicate Rapier completion")

    def test_duplicate_event_identity_rejected(self):
        self.event(2)["id"]=1
        self.reject("individual-event inventory")

    def test_missing_tail_event_rejected(self):
        self.trace=self.trace[:self.event(40)["ordinal"]-1]
        self.reject("Incomplete 40-event")

    def test_changed_registered_tape_rejected(self):
        self.event(1)["key"]="back"
        self.reject("Registered input tape changed")

    def test_duplicate_handler_refused(self):
        self.event(5)["handler_calls"]=2
        self.reject("exactly one production admission")

    def test_out_of_order_button_queue_refused(self):
        self.event(6)["admissions"][0]["after"]["edges"].reverse()
        self.reject("exact FIFO edge")

    def test_cancelled_input_cannot_be_relabelled_applied(self):
        self.event(17)["expected"]="applied"
        self.reject("Registered input tape changed")

    def test_rapid_pause_no_generation_revoke_rejected(self):
        row=self.transition("rapid_pause");row["after"]["generation"]=row["before"]["generation"]
        self.reject("synchronously revoke")

    def test_paused_native_drift_rejected(self):
        self.transition("paused_window")["after"]["native_tick"]+=1
        self.reject("pause drifted")

    def test_retained_reset_owner_rejected(self):
        self.transition("reset_completed")["details"]["old_session_retired"]=False
        self.reject("retire old authority")

    def test_wrong_generation_application_rejected(self):
        self.physics_after(1)["after"]["generation"]+=1
        self.reject("Unexplained automatic cancellation")

    def test_each_complete_owner_component_must_survive_physics(self):
        for key in c.OWNER:
            with self.subTest(key=key):
                self.trace=fixture();row=self.physics_after(1)
                row["after"][key] = "substituted-run" if key=="run_id" else row["after"][key]+100
                self.reject("Complete owner changed inside a physical callback")

    def test_refused_rearm_step_must_be_fully_neutral(self):
        for key,value in (("move",[1,0]),("trim",1),*((key,True) for key in c.BUTTONS)):
            with self.subTest(key=key):
                self.trace=fixture();self.physics_after(19)["after"]["action"][key]=value
                self.reject("Refused or unowned input reached a nonneutral completed step")

    def test_unfocused_cancellation_must_clear_trim(self):
        self.physics_after(24)["after"]["action"]["trim"]=1
        self.reject("Cancelled input reached a completed physical action")

    def test_stale_released_button_cannot_reappear_without_an_edge(self):
        self.physics_after(13)["after"]["action"]["primary"]=True
        self.reject("Completed action differs from the admitted held/edge controls")

    def test_automatic_admission_cannot_change_owner(self):
        self.physics_after(1)["admission"]["after"]["bridge"]+=100
        self.reject("Automatic admission is not bound")

    def test_completed_step_cannot_omit_automatic_observation(self):
        self.physics_after(1)["admission"]={}
        self.reject("Completed step lacks an automatic admission observation")

    def test_reset_does_not_permanently_authorize_later_owner_replacement(self):
        row=self.event(33)
        for state in (row["before"],row["after"],row["admissions"][0]["before"],row["admissions"][0]["after"]):
            state["session"]+=1;state["rearm"]=True
        self.reject("Unrequested complete owner replacement")

    def test_rounded_object_id_refused(self):
        self.event(1)["before"]["worker"]=float(-9223372036854775500)
        self.reject("exact signed identity")

    def test_original_log_diagnostics_skips_and_duplicate_markers_rejected(self):
        for log in ("SCRIPT ERROR: example", "SKIP missing runtime", "ERROR: wrong runtime",
                    c.MARKER+"{}\n"+c.MARKER+"{}"):
            with self.subTest(log=log),self.assertRaises(ValueError):c.extract(log)

    def test_no_assert_based_safety_dependency(self):
        with self.assertRaisesRegex(ValueError,"Invalid number"):
            c.numeric(float("nan"),"nan")
        with self.assertRaisesRegex(ValueError,"Invalid integer"):
            c.integer(True,"bool")


class MeasurementCustody(unittest.TestCase):
    def setUp(self):
        self.trace=fixture()
        first=next(r for r in self.trace if r.get("id")==1)
        last=next(r for r in self.trace if r.get("id")==16)
        completed=[r for r in self.trace if r["kind"]=="physics" and r["ordinal"]>last["ordinal"]][:2][-1]
        self.measurement={"started_usec":first["before"]["time_usec"]-1,
            "ended_usec":completed["after"]["time_usec"]+1,
            "initial":deepcopy(first["before"]),"final":deepcopy(completed["after"])}
        for r in self.trace:
            if r["kind"]=="physics":r["sampling"]=r["after"]["time_usec"]<=self.measurement["ended_usec"]

    def test_positive_complete_step_inventory_from_actual_interval(self):
        rows=c.measured_physics(self.trace,self.measurement)
        self.assertEqual(len(rows),self.measurement["final"]["step"]-self.measurement["initial"]["step"])

    def test_dropping_one_sampling_flag_is_rejected(self):
        next(r for r in self.trace if r["kind"]=="physics")["sampling"]=False
        with self.assertRaisesRegex(ValueError,"Sampling flag differs"):
            c.measured_physics(self.trace,self.measurement)

    def test_inverted_sampling_flags_are_rejected(self):
        for r in self.trace:
            if r["kind"]=="physics":r["sampling"]=not r["sampling"]
        with self.assertRaisesRegex(ValueError,"Sampling flag differs"):
            c.measured_physics(self.trace,self.measurement)

    def test_deleting_sampled_physical_observation_is_rejected(self):
        self.trace.remove(next(r for r in self.trace if r["kind"]=="physics"))
        with self.assertRaisesRegex(ValueError,"Incomplete measured Rapier tick/step inventory"):
            c.measured_physics(self.trace,self.measurement)

    def test_other_owner_cannot_supply_measured_steps(self):
        next(r for r in self.trace if r["kind"]=="physics")["after"]["worker"]+=1
        with self.assertRaisesRegex(ValueError,"Sampling flag differs"):
            c.measured_physics(self.trace,self.measurement)

    def test_positive_native_boundary_publication_is_retained_but_not_measured(self):
        packets=[{"tick":tick,"serial":tick+5,"completed_usec":tick*100,"native_completed":True} for tick in range(1,5)]
        c.verify_native_inventory(packets,deepcopy(packets[1:]),200,500)

    def test_dropping_first_or_last_native_measurement_is_rejected(self):
        packets=[{"tick":tick,"serial":tick+5,"completed_usec":tick*100,"native_completed":True} for tick in range(1,5)]
        for native in (packets[1:],packets[:-1]):
            with self.subTest(ticks=[r["tick"] for r in native]),self.assertRaisesRegex(ValueError,"omit/duplicate actual measured owner completions"):
                c.verify_native_inventory(packets,native,100,500)

    def test_first_callback_rejection_is_included(self):
        self.assertEqual(c.monotonic_counter_delta([1,1,2],0,2),2)

    def test_regressed_rejection_counter_is_refused(self):
        with self.assertRaisesRegex(ValueError,"Cumulative counter regressed"):
            c.monotonic_counter_delta([1,0],0,0)


class ConfigurationCustody(unittest.TestCase):
    def setUp(self):
        self.environment={"platform":"Linux","godot":{"major":4,"minor":7,"patch":0,"status":"stable",
            "build":"official","hash":c.GODOT_HASH},"rendering_method":"gl_compatibility",
            "rendering_driver":"opengl3","display_server":"headless","engine_sha256":"a"*64}
        self.policy={"assignments":[{"material":m,"requested_family":"freemass_v1" if m==3 else "cellular_yield_v1",
            "applied_family":"freemass_v1" if m==3 else "cellular_yield_v1","applied_variant":"reference"}
            for m in (3,8,12,16,20,21,24,30,32,33,36)],"admission":"current_defaults_only","refusal":None,
            "normalization":None,"session_generation":2,"platform":"linux","maximum_rule_radius":2,
            "policy_hash":"4b7922ad7badb443556d82ea0c624c259da7b75e85f92f87cdab216f95cab53a",
            "catalogue_digest":"82b5ab9a6e87ae817072390105052f8a5ac6d0ee22b3301cd973efdfc7fdbad3",
            "capability_matrix_digest":"33c608f875e3d8b5730f1d3b81a54dbeff9579b433e061535610a8bfa276e237",
            "version":1,"wire_version":1,"family_blocks":[],"material_blocks":[]}
        raw=b"synthetic-verifier-control"
        self.receipt={"kind":"applied_run","schema_version":1,"session_generation":2,"policy_hash":self.policy["policy_hash"],
            "completed_tick":0,"run_intent":"exploratory","region":[128,128,512,256],"maximum_rule_radius":2,
            "worker_threads":1,"canonical_bytes":json.dumps(list(raw)),"receipt_hash":hashlib.sha256(raw).hexdigest()}

    def test_positive_registered_environment_and_policy(self):
        c.verify_environment(self.environment,False,"linux")
        self.assertEqual(c.verify_policy(self.policy,self.receipt,0,2,1,"linux"),1)

    def test_current_policy_cannot_be_relabelled_pressure(self):
        with self.assertRaisesRegex(ValueError,"Requested preset differs"):
            c.verify_policy(self.policy,self.receipt,2,2,1,"linux")

    def test_receipt_must_match_world_generation(self):
        self.receipt["session_generation"]=1
        with self.assertRaisesRegex(ValueError,"another owner/platform"):
            c.verify_policy(self.policy,self.receipt,0,2,1,"linux")

    def test_worker_request_must_match_construction_capacity(self):
        self.receipt["worker_threads"]=2
        with self.assertRaisesRegex(ValueError,"ignored requested worker capacity"):
            c.verify_policy(self.policy,self.receipt,0,2,1,"linux")

    def test_changed_canonical_receipt_is_rejected(self):
        self.receipt["canonical_bytes"]="[0]"
        with self.assertRaisesRegex(ValueError,"receipt digest differs"):
            c.verify_policy(self.policy,self.receipt,0,2,1,"linux")

    def test_forged_policy_digest_is_rejected(self):
        self.policy["policy_hash"]="a"*64;self.receipt["policy_hash"]="a"*64
        with self.assertRaisesRegex(ValueError,"policy hash differs from exact assignment bytes"):
            c.verify_policy(self.policy,self.receipt,0,2,1,"linux")

    def test_actual_os_cannot_be_relabelled(self):
        self.environment["platform"]="Windows"
        with self.assertRaisesRegex(ValueError,"Actual process OS differs"):
            c.verify_environment(self.environment,False,"linux")

    def test_forged_engine_hash_is_rejected(self):
        self.environment["godot"]["hash"]="fake"
        with self.assertRaisesRegex(ValueError,"Actual engine build/hash differs"):
            c.verify_environment(self.environment,False,"linux")

    def test_renderer_substitution_is_rejected(self):
        self.environment["rendering_method"]="forward_plus"
        with self.assertRaisesRegex(ValueError,"Actual renderer differs"):
            c.verify_environment(self.environment,False,"linux")

    def test_headless_cannot_be_relabelled_graphical(self):
        with self.assertRaisesRegex(ValueError,"Actual display differs"):
            c.verify_environment(self.environment,True,"linux")


class SourceCustody(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        normalized={"godot/addons/godot-rapier2d/Radial2D.svg.import",
            "godot/addons/godot-rapier2d/icons/Fluid2D.svg.import",
            "godot/addons/godot-rapier2d/icons/StateManager2D.svg.import",
            "godot/addons/godot-rapier2d/logo_square_2d.png.import"}
        files={name:b"source\n" for name in {campaign.FIXTURE,campaign.PROBE,"godot/scripts/main.gd",*normalized}}
        files[".gitattributes"]=b"*.bat text eol=crlf\n*.ps1 text eol=crlf\n"
        files["build_control.bat"]=b"first\nsecond\n"
        runtimes={}
        for name in campaign.selected_runtimes("linux"):
            payload=b"\x7fELFsynthetic-control";digest=hashlib.sha256(payload).hexdigest()
            pointer=f"version https://git-lfs.github.com/spec/v1\noid sha256:{digest}\nsize {len(payload)}\n"
            files[name]=pointer.encode();runtimes[name]={"sha256":digest,"bytes":len(payload),"pointer":pointer}
        files["native/include/control.hpp"]=b"native control\n"
        files["third_party/rapier-control.patch"]=b"rapier control\n"
        provenances=[]
        for folder,source in (("cybersand_native","native/include/control.hpp"),("godot-rapier2d","third_party/rapier-control.patch")):
            artifact=next(name for name in runtimes if ("/"+folder+"/") in name)
            record={"artifact":artifact,"sha256":runtimes[artifact]["sha256"],"size":runtimes[artifact]["bytes"],
                "source_inputs":{source:hashlib.sha256(files[source]).hexdigest()}}
            files["godot/addons/"+folder+"/runtime-provenance.linux.json"]=json.dumps(record).encode()
            provenances.append(record)
        files["third_party/godot-runtime.lock.json"]=json.dumps({"godot_version":campaign.VERSION,"editor":{"sha256":"d"*64}}).encode()
        entries={name:("100644","blob",campaign.git_object(b"blob",data)) for name,data in files.items()}
        tree=campaign.tree_identity(entries);commit=f"tree {tree}\nauthor Test <test@example.invalid> 1 +0000\ncommitter Test <test@example.invalid> 1 +0000\n\nsynthetic verifier control\n".encode()
        source=campaign.git_object(b"commit",commit)
        (self.root/"executed-commit.txt").write_bytes(commit)
        (self.root/"executed-tree.bin").write_bytes(b"".join((" ".join(entries[name])+"\t"+name).encode()+b"\0" for name in sorted(entries)))
        with tarfile.open(self.root/"executed-source.tar","w",format=tarfile.PAX_FORMAT,pax_headers={"comment":source}) as archive:
            for name,data in files.items():
                if name.endswith(".bat"):data=data.replace(b"\n",b"\r\n")
                member=tarfile.TarInfo(name);member.size=len(data);member.mode=0o644;archive.addfile(member,io.BytesIO(data))
        inputs={name:runtimes[name]["sha256"] if name in runtimes else hashlib.sha256(data).hexdigest()
                for name,data in files.items() if any(name==scope or name.startswith(scope+"/") for scope in campaign.SCOPES)}
        self.report={"source_commit":source,"source_tree":tree,"executed_source_archive_sha256":campaign.sha(self.root/"executed-source.tar"),
            "execution_inputs":inputs,"runtimes":runtimes,"platform":"linux","normalized_import_descriptors":sorted(normalized),
            "native_provenance":provenances[0],"godot_identity":{"version":campaign.VERSION,"archive_sha256":"d"*64}}

    def test_positive_commit_tree_and_complete_inventory(self):
        campaign.verify_source_archive(self.root,self.report)

    def test_missing_executed_main_source_is_rejected(self):
        del self.report["execution_inputs"]["godot/scripts/main.gd"]
        with self.assertRaisesRegex(ValueError,"complete committed scopes"):
            campaign.verify_source_archive(self.root,self.report)

    def test_runtime_oid_and_size_cannot_be_relabelled(self):
        name=next(iter(self.report["runtimes"]))
        self.report["runtimes"][name].update(sha256="0"*64,bytes=1);self.report["execution_inputs"][name]="0"*64
        with self.assertRaisesRegex(ValueError,"Archived/runtime LFS identity mismatch"):
            campaign.verify_source_archive(self.root,self.report)

    def test_reported_tree_must_match_exact_commit_object(self):
        self.report["source_tree"]="0"*40
        with self.assertRaisesRegex(ValueError,"Reported source tree differs"):
            campaign.verify_source_archive(self.root,self.report)

    def test_original_tree_inventory_cannot_drop_a_source_blob(self):
        path=self.root/"executed-tree.bin";rows=path.read_bytes().split(b"\0")
        path.write_bytes(b"\0".join(r for r in rows if b"godot/scripts/main.gd" not in r))
        with self.assertRaisesRegex(ValueError,"tree inventory does not match committed tree"):
            campaign.verify_source_archive(self.root,self.report)

    def test_native_provenance_cannot_be_relabelled(self):
        self.report["native_provenance"]["sha256"]="0"*64
        with self.assertRaisesRegex(ValueError,"Reported native provenance differs"):
            campaign.verify_source_archive(self.root,self.report)

    def test_engine_archive_must_match_committed_pin(self):
        self.report["godot_identity"]["archive_sha256"]="0"*64
        with self.assertRaisesRegex(ValueError,"Engine archive differs from committed pin"):
            campaign.verify_source_archive(self.root,self.report)

    def test_undeclared_archive_crlf_is_not_normalized(self):
        data=b"unrelated\r\n"
        self.assertEqual(campaign.canonical_archive_blob("godot/scripts/main.gd",data,b"*.bat text eol=crlf\n"),data)
        self.assertNotEqual(campaign.git_object(b"blob",data),campaign.git_object(b"blob",b"unrelated\n"))

    def test_real_git_archive_explicit_crlf_rule_round_trips(self):
        root=self.root/"git-control";root.mkdir()
        attrs=b"*.bat text eol=crlf\n*.ps1 text eol=crlf\n"
        (root/".gitattributes").write_bytes(attrs);(root/"launch.bat").write_bytes(b"first\nsecond\n")
        def git(*args):
            return subprocess.check_output(["git","-C",str(root),"-c","core.autocrlf=false",*args],stderr=subprocess.PIPE)
        git("init","-q");git("add",".");tree=git("write-tree").decode().strip()
        with tarfile.open(fileobj=io.BytesIO(git("archive",tree))) as archive:
            exported=archive.extractfile("launch.bat").read()
        self.assertEqual(exported,b"first\r\nsecond\r\n")
        self.assertEqual(campaign.git_object(b"blob",campaign.canonical_archive_blob("launch.bat",exported,attrs)),
                         git("rev-parse",tree+":launch.bat").decode().strip())

    def test_atomic_archive_refuses_to_replace_original(self):
        before=(self.root/"executed-source.tar").read_bytes()
        with self.assertRaisesRegex(ValueError,"Refusing to replace an original source archive"):
            campaign.publish_source_archive(self.root,self.report["source_commit"])
        self.assertEqual((self.root/"executed-source.tar").read_bytes(),before)

    def test_failed_original_export_remains_failed_without_final_archive(self):
        output=self.root/"failed-export";output.mkdir()
        with patch.object(campaign.subprocess,"run",side_effect=subprocess.CalledProcessError(1,["git","archive"])):
            with self.assertRaises(subprocess.CalledProcessError):
                campaign.publish_source_archive(output,self.report["source_commit"])
        self.assertFalse((output/"executed-source.tar").exists())
        self.assertEqual(len(list(output.glob("*.pending"))),1)


class VisualReadback(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        self.frames={}
        for count,name in enumerate(("baseline","unchanged","without_actor","without_terrain","restored"),1):
            actor=name!="without_actor";terrain=name!="without_terrain"
            rows=[]
            for y in range(540):
                row=bytearray((bytes((60,80,100)) if terrain else bytes((0,0,0)))*960)
                if actor and 50<=y<80:row[50*3:80*3]=bytes((230,120,60))*30
                rows.append(b"\0"+row)
            def chunk(kind,data):return struct.pack(">I",len(data))+kind+data+struct.pack(">I",zlib.crc32(kind+data)&0xffffffff)
            data=b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",960,540,8,2,0,0,0))
            data+=chunk(b"IDAT",zlib.compress(b"".join(rows)))+chunk(b"IEND",b"")
            (self.root/(name+".png")).write_bytes(data)
            self.frames[name]={"file":name+".png","saved":True,"sha256":hashlib.sha256(data).hexdigest(),"draw_count":count}
        self.result={"visual":{"executed":True,"physics_pose_injected":False,"layer_removal_after_measurement":True,
            "frames":self.frames,"actor_polygons":[{"vertices":[[50,50],[80,50],[80,80],[50,80]],"color":[.9,.5,.2]}],
            "world_rect":[0,0,960,540]}}

    def copy_frame(self,source,target):
        data=(self.root/(source+".png")).read_bytes();(self.root/(target+".png")).write_bytes(data)
        self.frames[target]["sha256"]=hashlib.sha256(data).hexdigest()

    def test_positive_rendered_actor_terrain_controls(self):
        row=c.verify_visual(self.result,self.root)
        self.assertEqual(row["actor_removed_changed"],900)
        self.assertGreater(row["terrain_removed_changed"],100)

    def test_nonblank_ui_without_actor_evidence_rejected(self):
        self.copy_frame("baseline","without_actor")
        with self.assertRaisesRegex(ValueError,"Actor pixels not distinguished"):
            c.verify_visual(self.result,self.root)

    def test_nonblank_actor_without_terrain_evidence_rejected(self):
        self.copy_frame("baseline","without_terrain")
        with self.assertRaisesRegex(ValueError,"Terrain pixels absent"):
            c.verify_visual(self.result,self.root)

    def test_unretained_and_changed_original_pixels_rejected(self):
        (self.root/"baseline.png").write_bytes(b"fake")
        with self.assertRaisesRegex(ValueError,"missing/changed"):
            c.verify_visual(self.result,self.root)

    def test_reused_draw_submission_rejected(self):
        self.frames["without_actor"]["draw_count"]=1
        with self.assertRaisesRegex(ValueError,"Reused/fabricated draw"):
            c.verify_visual(self.result,self.root)

    def test_png_crc_failure_rejected(self):
        path=self.root/"baseline.png";data=bytearray(path.read_bytes());data[32]^=1;path.write_bytes(data)
        with self.assertRaisesRegex(ValueError,"PNG CRC failed"):
            c.png_rgb(path)


if __name__=="__main__":unittest.main()
