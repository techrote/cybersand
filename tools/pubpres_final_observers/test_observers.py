#!/usr/bin/env python3
"""Meaningful live CPU accounting and independent sidecar tamper controls."""
from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

from execution_contract import ROOT, expected_execution, function_source, verify_execution_derivation
from execute_with_resources import execute_with_resources
from presentation_metrics import (PROBE, GEOMETRY_SOURCES, composition_equal, transform_product,
                                  transform_product_magnitudes, validate_presentation, validate_cpu_trace)
from resource_sampler import linux_stat_sample, process_cpu_sample, summarize_cpu


def put(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data) + "\n")


class CpuTests(unittest.TestCase):
    def test_exact_runner_keeps_every_ownership_and_completion_gate(self):
        self.assertIn("exact executable/ancestry/creation discovery",verify_execution_derivation()["scope"])
        text = (ROOT / "tools/pubpres_final_observers/execute_with_resources.py").read_text()
        expected = expected_execution((ROOT / "tools/pubpres_playability/run_campaign.py").read_bytes())
        self.assertEqual(function_source(text, "execute_with_resources"), expected)
        for old, new in (("owner.close()", "False"), ("not timed_out", "True"),
                         ("exit_code == 0", "True"), ("raise failure", "pass")):
            self.assertNotEqual(function_source(text.replace(old, new), "execute_with_resources"), expected)

    def test_linux_comm_parentheses_and_raw_cpu_units(self):
        fields = ["R"] + ["0"]*21
        fields[11], fields[12], fields[19] = "20", "5", "9000"
        row = linux_stat_sample("123 (worker (odd) name) " + " ".join(fields), 123, 250, 100)
        self.assertEqual((row["user_seconds"], row["kernel_seconds"], row["creation_identity"]),
                         (0.2, 0.05, "linux-start-ticks:9000"))
        with self.assertRaises(ValueError): linux_stat_sample("123 (x) R", 123, 0, 100)
        with self.assertRaises(ValueError): linux_stat_sample("123 (x) " + " ".join(fields), 124, 0, 100)

    def test_actual_this_process_counter_and_creation_identity(self):
        first = process_cpu_sample(os.getpid(), 0)
        second = process_cpu_sample(os.getpid(), 1)
        self.assertEqual(first["pid"], os.getpid())
        self.assertEqual(first["creation_identity"], second["creation_identity"])
        self.assertGreaterEqual(second["user_units"], first["user_units"])
        self.assertGreaterEqual(second["kernel_units"], first["kernel_units"])

    def test_regression_pid_reuse_and_unit_tampering_refused(self):
        first = {"pid":123,"elapsed_ms":100,"creation_identity":"test:1","user_units":10,
                 "kernel_units":5,"units_per_second":100,"user_seconds":0.1,"kernel_seconds":0.05,"sampler_elapsed_usec":4}
        second = dict(first, elapsed_ms=1100, user_units=40, kernel_units=15, user_seconds=0.4, kernel_seconds=0.15)
        summary = summarize_cpu([first,second], expected_pid=123, errors=[])
        self.assertTrue(summary["complete"])
        self.assertAlmostEqual(summary["mean_cpu_core_equivalents"],0.4)
        for key,value in (("creation_identity","test:2"),("pid",124),("elapsed_ms",50),
                          ("user_units",1),("kernel_seconds",99)):
            with self.subTest(key=key):
                changed = dict(second); changed[key] = value
                self.assertFalse(summarize_cpu([first,changed], expected_pid=123, errors=[])["complete"])
        self.assertFalse(summarize_cpu([first,second], expected_pid=123, errors=[], dropped=1)["complete"])

    def test_real_owned_child_cpu_samples_and_sidecar_binding(self):
        # A one-second Python CPU fixture verifies process accounting and the
        # original process owner. These bytes never stand in for Godot evidence.
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "cpu-fixture"
            child = "import time\nend=time.monotonic()+1.0\nx=1\nwhile time.monotonic()<end: x=(x*37+11)%1000003\n"
            result = execute_with_resources(Path(sys.executable).resolve(), ["-c",child], path, "f"*40, {}, 10)
            self.assertTrue(result["process_cpu"]["summary"]["complete"])
            self.assertGreater(result["process_cpu"]["summary"]["observed_user_seconds"],0)
            self.assertFalse(result["surviving_children_at_exit"])
            receipt = {"source_identity":{"source_sha":"f"*40,
                       "engine_sha256":hashlib.sha256(Path(sys.executable).resolve().read_bytes()).hexdigest()},
                       "process_id":result["observed_application_pid"]}
            summary = validate_cpu_trace(path/"process-cpu.json",result,receipt)
            self.assertEqual(summary,result["process_cpu"]["summary"])
            raw = json.loads((path/"process-cpu.json").read_text())
            raw["samples"][-1]["creation_identity"] += "-reused"
            put(path/"process-cpu.json",raw)
            with self.assertRaises(ValueError): validate_cpu_trace(path/"process-cpu.json",result,receipt)


def presentation_fixture(root, separate=False):
    project = root/"project"
    (project/PROBE).parent.mkdir(parents=True)
    probe_bytes = (ROOT/"tools/pubpres_final_observers/presentation_probe.gd").read_bytes()
    (project/PROBE).write_bytes(probe_bytes)
    sha = hashlib.sha256(probe_bytes).hexdigest()
    source = {"source_sha":"a"*40,"engine_sha256":"b"*64,"files":{"res://"+PROBE:sha}}
    for name in GEOMETRY_SOURCES:
        content=(ROOT/"godot"/name).read_bytes()
        (project/name).parent.mkdir(parents=True,exist_ok=True)
        (project/name).write_bytes(content)
        source["files"]["res://"+name]=hashlib.sha256(content).hexdigest()
    receipt = {"complete":True,"failures":[],"source_identity":source,"process_id":123,
               "platform":"Linux","renderer":"opengl3","capture_start_usec":1000,"capture_end_usec":200000,
               "capture_physical_tick_start":0,"camera":"follow","render_thread":{"runtime":"separate" if separate else "safe"},
               "actor_roster_before":[{"actor_slot":0,"instance_id":1,"bodies":[{"body_slot":0,"body_rid":777,"node_instance_id":555}]}],
               "selectors_before":{"requested":{"CYBERSAND_DIAG_PRESENTATION_OBSERVER":"1"}},
               "selectors_after":{"requested":{"CYBERSAND_DIAG_PRESENTATION_OBSERVER":"1"}}}
    events = [{"event":"identity","source":source}]
    for step in range(1,145):
        events.append({"event":"rapier_step","step":step,"start_usec":950+step*1000,"time_usec":1000+step*1000,
                       "session":7,"epoch":11,"world_generation":42,
                       "bodies":[{"instance_id":1,"xy":[float(step),0.0],"angle":0.0}]})
    trace = b"".join((json.dumps(event)+"\n").encode() for event in events)
    (root/"receipt-events.jsonl").write_bytes(trace)
    receipt["trace_sha256"] = hashlib.sha256(trace).hexdigest()
    put(root/"receipt.json",receipt)
    rows, draws = [], []
    for index,step in enumerate((2,72,144)):
        body = {"slot":0,"instance_id":1,"generation":0,"body_rid":"777",
                "selected_visible":True,"overlay_visible":True,
                "selected_pose":{"xy":[float(step),0.0],"angle":0.0},
                "first_overlay_part":{"xy":[float(step),0.0],"angle":0.0},
                "selected_transform":[1.0,0.0,0.0,1.0,float(step),0.0],
                "first_overlay_transform":[1.0,0.0,0.0,1.0,float(step),0.0],
                "geometry":{"available":True,"reason":"actual_collision_node","actor_slot":0,"part_index":0,
                    "declared_shape":"rectangle","declared_part_id":"body","body_node_id":"555","body_rid":"777",
                    "child_index":0,"child_node_id":"556","child_parent_id":"555","child_class":"CollisionShape2D",
                    "shape_class":"RectangleShape2D","shape_instance_id":"-9223372000000000012","shape_size":[8.0,12.0],
                    "collision_local_transform":[1.0,0.0,0.0,1.0,0.0,0.0],"composition":"selected_direct",
                    "overlay_actor_slot":0,"overlay_body_slot":-1,"overlay_part_id":"body","overlay_physical_part_id":"",
                    "overlay_shape":"rectangle","overlay_size":[8.0,12.0]},
                "selected_step":step,"desired_step":step,"selected_completed_usec":1000+step*1000,
                "selected_sampled_usec":1000+step*1000,"source":"live","reason":"clear",
                "intentional_hold":False,"hold_age_usec":0,"explicit_reentry":False,"timeline_reset":False,
                "projection":{"overlay_px":[float(step),0.0],"shader_px":[float(step),0.0],"residual_px":0.0}}
        time = 1500+step*1000
        rows.append({"event":"main_presentation_submission","index":index,"time_usec":time,"process_frame":index+1,
                     "main_thread":True,"render_thread_inline":not separate,"presentation_resolved_usec":time-10,
                     "session":7,"epoch":11,"world_generation":42,"frame_session":7,"frame_epoch":11,
                     "frame_valid":True,"frame_reason":"resolved","physical_tick":step,
                     "body_count":1,"truncated_bodies":0,"truncated_parts":0,"visible_part_count":1,"bodies":[body],
                     "render_serial":index+1,"material_revision":step,"material_generated_usec":time-100,"observer_usec":5,
                     "camera_requested":[0,0],"camera_submitted":[0,0],"view_size":[512,512],
                     "content_position":[0,0],"content_size":[512,512],"camera_mode":1,
                     "follow":{"instance_id":1,"source_step":step,"held":False,"target":[float(step),0.0]}})
        draws.append({"event":"draw_notification","time_usec":time+10,"callback_process_frame":index+1,
                      "render_thread_inline":not separate,"submission_index":-1 if separate else index,"observer_usec":2})
        events.append({"event":"framebuffer_draw","time_usec":time+8,"process_frame":index+1,"inline_main":not separate})
        events.append({"event":"texture_upload","time_usec":time-20,"render_serial":index+1,
                       "world_generation":42,"generated_usec":time-100})
    trace = b"".join((json.dumps(event)+"\n").encode() for event in events)
    (root/"receipt-events.jsonl").write_bytes(trace)
    receipt["trace_sha256"] = hashlib.sha256(trace).hexdigest()
    put(root/"receipt.json",receipt)
    data = {"schema":"pubpres-final-presentation-observer-v1","complete":True,"source_identity":source,
            "probe_sha256":sha,"engine_sha256":source["engine_sha256"],"process_id":123,"platform":"Linux","renderer":"opengl3",
            "selector":"1","capture_start_usec":1000,"capture_end_usec":200000,"max_submissions":6000,
            "max_notifications":6000,"max_bodies":8,"max_parts":512,"dropped_submissions":0,"dropped_notifications":0,
            "invalid_samples":0,"observer_total_usec":21,"observer_max_usec":5,"submissions":rows,"notifications":draws}
    put(root/"presentation.json",data)
    return data,receipt,project


class PresentationTests(unittest.TestCase):
    def test_compound_roundoff_bound_accounts_for_cancellation(self):
        a=[0.7071067690849304,0.7071067690849304,-0.7071067690849304,0.7071067690849304,1024.0,0.0]
        b=[1.0,0.0,0.0,1.0,-724.0773315429688,724.0773315429688]
        rounded=transform_product(a,b)
        magnitude=transform_product_magnitudes(a,b)[4]
        fused=a[0]*b[4]+a[2]*b[5]+a[4]
        self.assertTrue(composition_equal(rounded[4],fused,magnitude))
        self.assertFalse(composition_equal(rounded[4]+0.01,fused,magnitude))

    def test_independently_joined_poses_follow_and_separate_unknown_draws(self):
        for separate in (False,True):
            with tempfile.TemporaryDirectory() as folder:
                root=Path(folder)
                _,_,project=presentation_fixture(root,separate)
                result=validate_presentation(root/"presentation.json",root/"receipt.json",project)
                self.assertEqual(result["joined_selected_physical_poses"],3)
                self.assertEqual(result["joined_follow_targets"],3)
                self.assertTrue(result["all_visible_first_parts_verified"])
                self.assertEqual(result["verified_first_part_submissions"],3)
                self.assertEqual(result["windows"]["whole_capture"]["withheld_body_submissions"],0)

    def test_owner_pose_follow_clock_cost_and_loss_tampering_refused(self):
        mutations = {
            "owner":lambda d:d["submissions"][0].update(epoch=12),
            "invented-step":lambda d:d["submissions"][0].update(physical_tick=3),
            "invented-pose":lambda d:d["submissions"][0]["bodies"][0]["selected_pose"].update(xy=[99,0]),
            "wrong-body":lambda d:d["submissions"][0]["bodies"][0].update(body_rid="778"),
            "stale-submitted-part":lambda d:d["submissions"][0]["bodies"][0]["first_overlay_transform"].__setitem__(4,1.0),
            "wrong-collider-parent":lambda d:d["submissions"][0]["bodies"][0]["geometry"].update(child_parent_id="557"),
            "wrong-collider-body":lambda d:d["submissions"][0]["bodies"][0]["geometry"].update(body_rid="778"),
            "wrong-collider-node":lambda d:d["submissions"][0]["bodies"][0]["geometry"].update(body_node_id="557",child_parent_id="557"),
            "wrong-part":lambda d:d["submissions"][0]["bodies"][0]["geometry"].update(overlay_part_id="other"),
            "wrong-shape-size":lambda d:d["submissions"][0]["bodies"][0]["geometry"].update(overlay_size=[9.0,12.0]),
            "replaced-collider":lambda d:d["submissions"][1]["bodies"][0]["geometry"].update(child_node_id="558"),
            "zero-shape-id":lambda d:d["submissions"][0]["bodies"][0]["geometry"].update(shape_instance_id="0"),
            "invented-scale":lambda d:d["submissions"][0]["bodies"][0]["selected_transform"].__setitem__(0,2.0),
            "overlay-withheld":lambda d:d["submissions"][0]["bodies"][0].update(overlay_visible=False),
            "future-pose-clock":lambda d:d["submissions"][0]["bodies"][0].update(selected_completed_usec=999999),
            "fresh-false-pose-clock":lambda d:d["submissions"][0]["bodies"][0].update(selected_completed_usec=d["submissions"][0]["time_usec"]),
            "fresh-false-material-clock":lambda d:d["submissions"][0].update(material_generated_usec=d["submissions"][0]["time_usec"]),
            "stale-upload-serial":lambda d:d["submissions"][1].update(render_serial=1),
            "invented-follow":lambda d:d["submissions"][0]["follow"].update(target=[88,0]),
            "underreported-cost":lambda d:d.update(observer_total_usec=20),
            "lost-row":lambda d:d.update(dropped_submissions=1),
            "wrong-source":lambda d:d.update(probe_sha256="f"*64),
            "lost-notification":lambda d:d["notifications"].pop(),
        }
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder); original,_,project=presentation_fixture(root)
            for name,mutate in mutations.items():
                with self.subTest(name=name):
                    altered=copy.deepcopy(original);mutate(altered);put(root/"presentation.json",altered)
                    with self.assertRaises(ValueError): validate_presentation(root/"presentation.json",root/"receipt.json",project)

    def test_separate_notification_cannot_gain_submission_identity(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder); data,_,project=presentation_fixture(root,True)
            data["notifications"][0]["submission_index"]=0
            put(root/"presentation.json",data)
            with self.assertRaises(ValueError): validate_presentation(root/"presentation.json",root/"receipt.json",project)

    def test_compound_actual_local_composition_and_stale_geometry_refusal(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);data,_,project=presentation_fixture(root)
            for row in data["submissions"]:
                body=row["bodies"][0]
                # Nonidentity local rotation and offset must enter the actual
                # submitted matrix, not be mistaken for a stale body pose.
                body["geometry"].update(declared_shape="rectangle_union",composition="selected_times_collision_local",
                    overlay_body_slot=0,overlay_physical_part_id="body",collision_local_transform=[0.0,1.0,-1.0,0.0,5.0,-3.0])
                actual=transform_product(body["selected_transform"],body["geometry"]["collision_local_transform"])
                body["first_overlay_transform"]=actual
                body["first_overlay_part"]={"xy":actual[4:],"angle":1.5707963267948966}
            put(root/"presentation.json",data)
            result=validate_presentation(root/"presentation.json",root/"receipt.json",project)
            self.assertEqual(result["verified_first_part_submissions"],3)
            for change in ("stale-consistent-submission","self-consistent-local-change","wrong-branch"):
                altered=copy.deepcopy(data);body=altered["submissions"][1]["bodies"][0]
                if change=="stale-consistent-submission":
                    body["first_overlay_part"]["xy"][0]-=1
                    body["first_overlay_transform"][4]-=1
                elif change=="self-consistent-local-change":
                    body["geometry"]["collision_local_transform"][4]+=1
                    body["first_overlay_part"]["xy"][0]+=1
                    body["first_overlay_transform"][4]+=1
                else: body["geometry"]["composition"]="selected_direct"
                put(root/"presentation.json",altered)
                with self.subTest(change=change),self.assertRaises(ValueError):
                    validate_presentation(root/"presentation.json",root/"receipt.json",project)

    def test_unavailable_geometry_is_explicitly_unverified_and_source_drift_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);data,_,project=presentation_fixture(root)
            data["submissions"][0]["bodies"][0]["geometry"]={"available":False,"reason":"unsupported_collision_geometry"}
            put(root/"presentation.json",data)
            result=validate_presentation(root/"presentation.json",root/"receipt.json",project)
            self.assertFalse(result["all_visible_first_parts_verified"])
            self.assertEqual(result["unverified_first_part_submissions"],1)
            self.assertEqual(result["windows"]["whole_capture"]["unverified_visible_first_parts"],1)
            (project/GEOMETRY_SOURCES[-1]).write_text("# changed production drawing\n")
            with self.assertRaises(ValueError): validate_presentation(root/"presentation.json",root/"receipt.json",project)


if __name__ == "__main__":
    unittest.main()
