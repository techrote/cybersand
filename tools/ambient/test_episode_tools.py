#!/usr/bin/env python3
"""Synthetic metric/custody regressions. These are NOT physical episodes."""
from __future__ import annotations
from copy import deepcopy
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
import analyze_episodes as analysis
import run_episodes as runner


def fixture():
    source={"source_revision":"a"*40,"godot_executable_sha256":"b"*64,"runtime_supported":True,"platform":"Linux",
        "sha256":{p:"c"*64 for p in analysis.REQUIRED_SOURCES},
        "runtime_sha256":{"addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so":"d"*64,
            "addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so":"e"*64}}
    item={"id":"synthetic-case","matched_group":"synthetic-match","group":"main","layout":"pockets",
        "model":"runner","arm":"stateful","seed":1701,"actor_count":1,"seconds":2}
    trace=[]
    for i in range(20):
        trace.append({"seconds":i*.1,"tick":i*6,"position":[32.,175+(i%2)*3],"velocity":[0,0],
            "action_move":[.45,0],"intent_direction":[1,0],"intent_pace":.45,"has_procedural_intent":True,
            "selection":"wander","phase":"","oil":{"available":True,"present":False},
            "water":{"available":True,"present":False},"nearest_peer":None,"observed_peer_count":0,
            "wall_left":None,"wall_right":None})
    row={"episode_id":"synthetic-actor","actor_instance":100,"model":"runner","controller":"stateful",
        "profile":{"id":"synthetic"},"start":[32,175],"last":[32,178],"trace":trace,"accepted_commands":20,
        "rejected_commands":0,"outcome_sensor_unavailable":0,"total_decision_usec":500,"sensor_usec_total":700,
        "physical_path_cells":60,"neutral_command_path_cells":0,"canvas_center_incidents":0,
        "sensor_usec_max":60,"decision_usec_max":35,"observer_usec":900}
    campaign=dict(item,native_ticks=120,physical_ticks=120,completed_seconds=2,run_id="synthetic-run",
        epoch=1,physical_parts=6,native_masks=6,initial_materials={"sha256":"f"*64},initial_pose_sha256="0"*64,
        geometry=[0,200,512,8,1],episodes=[row],native_step_usec=200,physics_step_usec=400,
        production_advance_usec=1500,elapsed_usec=2000)
    return {"case":"AMBIENT-002 matched physical actor episodes","mode":"shard","actor_limit":8,"decision_period_ticks":6,
        "source_identity":source,"registration":[item],"complete_registration":[item],"expected_campaigns":1,
        "expected_actor_episodes":1,"completed_campaigns":1,"completed_actor_episodes":1,"complete":True,
        "checks":12,"failures":[],"campaigns":[campaign]}


def terminal(report):
    return {"source_revision":report["source_identity"]["source_revision"],"case_id":"synthetic-case",
        "mode":report["mode"],"complete":report["complete"],"checks":report["checks"],"failures":report["failures"],
        "campaigns":report["completed_campaigns"],"episodes":report["completed_actor_episodes"],
        "expected_episodes":report["expected_actor_episodes"]}


class ReductionTests(unittest.TestCase):
    def test_valid_synthetic_contract(self):
        self.assertEqual(len(analysis.validate(fixture())),1)

    def test_ground_gait_is_not_exploration_or_active_progress(self):
        c,r=analysis.validate(fixture())[0]; m=analysis.episode_metrics(c,r)
        self.assertEqual(m["stable_territory_cells"],1)
        self.assertEqual(m["net_displacement_cells"],0)
        self.assertEqual(m["home_distance_final"],0)
        self.assertEqual(m["stalled_active_fraction"],1)
        self.assertEqual(m["physical_path_including_gait_cells"],60)
        self.assertEqual(m["decision_plus_sensor_usec"],1200)

    def test_vertical_flight_progress_is_not_discarded(self):
        c,r=analysis.validate(fixture())[0]; r["model"]="4ly_trainer"; m=analysis.episode_metrics(c,r)
        self.assertEqual(m["stalled_active_fraction"],0)
        self.assertEqual(m["home_distance_final"],3)

    def test_intentional_inactivity_retains_physical_drift(self):
        c,r=analysis.validate(fixture())[0]
        for sample in r["trace"]:
            sample["intent_direction"]=[0,0]; sample["action_move"]=[0,0]
        m=analysis.episode_metrics(c,r)
        self.assertAlmostEqual(m["intentional_idle_seconds"],2)
        self.assertGreater(m["sampled_intentional_idle_drift_cells"],0)

    def test_reject_missing_source_and_wrong_actual_roster(self):
        for mutate in (
            lambda r:r["source_identity"].update(sha256={}),
            lambda r:r["source_identity"].update(godot_executable_sha256="unknown"),
            lambda r:r["campaigns"][0]["episodes"][0].update(actor_instance=101),
            lambda r:r["campaigns"][0].update(physical_ticks=119),
            lambda r:r["campaigns"][0].update(seed=2909),
            lambda r:r.update(expected_actor_episodes=99),
        ):
            report=fixture(); mutate(report)
            with self.assertRaises(ValueError): analysis.validate(report)

    def test_auxiliary_companions_are_not_subject_replicates(self):
        report=fixture(); c=report["campaigns"][0]
        c["group"]="catalogue"; c["actor_count"]=2
        companion=deepcopy(c["episodes"][0])
        companion.update(episode_id="synthetic-companion",actor_instance=101,controller="passive_companion",accepted_commands=0)
        c["episodes"].append(companion)
        report["registration"][0].update(group="catalogue",actor_count=2)
        report.update(expected_actor_episodes=2,completed_actor_episodes=2)
        summary=analysis.summarize(report,analysis.validate(report))
        self.assertEqual(summary["actor_episodes"],2)
        self.assertEqual(summary["subject_actor_episodes"],1)
        self.assertEqual(summary["auxiliary_actor_episodes"],1)
        self.assertEqual(summary["cohorts"][0]["actor_episodes"],1)

    def test_initial_proximity_is_not_formation_during_play(self):
        case = fixture()["campaigns"][0]
        first = case["episodes"][0]
        second = deepcopy(first); second["actor_instance"] = 101
        for index, sample in enumerate(second["trace"]):
            sample["position"] = [62 if index < 5 or index >= 10 else 82, 175]
        case["episodes"].append(second)
        result = analysis.social_metrics(case)
        self.assertEqual(result["initial_proximity_components"], [[100,101]])
        self.assertEqual(result["formation_events"], 2)
        self.assertEqual(result["formation_events_after_initial"], 1)
        self.assertEqual(result["dissolution_events"], 1)


class CustodyTests(unittest.TestCase):
    def write_attempt(self,folder):
        report=fixture()
        for name in analysis.REQUIRED_SOURCES:
            path=folder/"godot"/name; path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(b"synthetic unit-test input\n")
            report["source_identity"]["sha256"][name]=runner.sha(path)
        directory=folder/"output"/"shards"/"synthetic-case"
        target=directory/"attempt-001"; target.mkdir(parents=True)
        report_path=target/"report.json"; runner.write(report_path,report)
        console=target/"console.log"; console.write_text("AMBIENT2_EPISODES "+json.dumps(terminal(report))+"\n")
        receipt={"returncode":0,"mode":"full","case_id":"synthetic-case","source_revision":"a"*40,"custody_sha256":"e"*64,
            "report_sha256":runner.sha(report_path),"console_sha256":runner.sha(console)}
        receipt_path=target/"execution.json"; runner.write(receipt_path,receipt)
        retained={"report":str(report_path.relative_to(folder/"output")),"report_sha256":runner.sha(report_path),
            "console_sha256":runner.sha(console),"execution_receipt_sha256":runner.sha(receipt_path)}
        args=SimpleNamespace(resume=True,root=folder,source_sha="a"*40,output=folder/"output",
            retained_receipts={"synthetic-case":retained})
        return directory,report,args,target

    def test_resume_requires_original_console_report_and_receipt(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory,report,args,target=self.write_attempt(Path(temporary)); identity=runner.identity_key(report["source_identity"])
            self.assertIsNotNone(runner.find_valid_shard(directory,report["registration"][0],identity,args,"e"*64))
            (target/"console.log").write_text("edited\n")
            self.assertIsNone(runner.find_valid_shard(directory,report["registration"][0],identity,args,"e"*64))

    def test_resume_refuses_missing_console(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory,report,args,target=self.write_attempt(Path(temporary)); (target/"console.log").unlink()
            self.assertIsNone(runner.find_valid_shard(directory,report["registration"][0],
                runner.identity_key(report["source_identity"]),args,"e"*64))

    def test_resume_refuses_edited_receipt(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory,report,args,target=self.write_attempt(Path(temporary))
            receipt=json.loads((target/"execution.json").read_text()); receipt["started_utc"]="edited"
            runner.write(target/"execution.json",receipt)
            self.assertIsNone(runner.find_valid_shard(directory,report["registration"][0],
                runner.identity_key(report["source_identity"]),args,"e"*64))

    def test_terminal_must_agree_with_original_report(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory,report,args,target=self.write_attempt(Path(temporary))
            receipt=json.loads((target/"execution.json").read_text()); wrong=terminal(report); wrong["episodes"]=8
            (target/"console.log").write_text("AMBIENT2_EPISODES "+json.dumps(wrong)+"\n")
            with self.assertRaises(ValueError):
                runner.check_terminal(target/"console.log",report,receipt,"synthetic-case","a"*40,"full")


if __name__=="__main__":
    unittest.main()

