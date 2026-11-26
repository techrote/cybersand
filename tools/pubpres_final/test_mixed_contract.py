#!/usr/bin/env python3
"""Synthetic mixed-workload adversaries, never engine or performance evidence."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from run_mixed_qualification import mixed_campaign, correctness_prerequisite
from mixed_contract import expected_mixed_observer, expected_mixed_reducer, verify_mixed_contract
from mixed_oracles import BASIN_EDITS, OPTIONS, required_actors, validate_mixed_workload, validate_setup
from results_registered_mixed import validate_measurement_trace
from test_results import complete_reader_fixture

ROOT = Path(__file__).resolve().parents[2]
REGISTRATION = json.loads((ROOT / "tools/pubpres_final/mixed_registration.json").read_text())


def fixture(scale=1):
    """Deliberately synthetic eight-owner/action fixture for pure validator tests."""
    setup = {"version":2,"extent":[512*scale,512*scale],"actors":[
        {"id":row[0],"model":row[1],"hash":REGISTRATION["model_hashes"][row[1]],
         "spawn":[row[2]*scale,row[3]*scale],"options":copy.deepcopy(OPTIONS)} for row in REGISTRATION["actors"]],
        "next_id":9,"selected":1,"response":"LA-SELECTIVE","normalize":False,"rule_radius":2,
        "source":[],"material":2,"brush":8,"fire":False,"liquid_policy":[1,2,3],
        "edits":[[value*scale if i<4 else value for i,value in enumerate(row)] for row in BASIN_EDITS]}
    raw = json.dumps(setup)
    controls = [{"slot":i,"instance_id":i+1,"sequence":-1,"deadline":-1,"generation":3,"command_empty":True}
                for i in range(8)]
    data = {"schema":"pubpres-final-mixed-gameplay-v1","camera":"follow","workers":4,
            "water_law":"wave_flow_v1","water_profile":"gameplay_main846f","water_variant":"reference",
            "input_mode":"tape","command_mode":"repeated_callback","observer_mode":"full",
            "capture_start_usec":1_000_000,"capture_end_usec":61_000_000,"capture_physical_tick_start":0,
            "physical_owner_before":{"epoch":7,"session":9},
            "fixture":{"name":"basin512" if scale==1 else "basin1024","source":"pubpres_final_mixed_eight_actor_v1",
                       "actors":8,"extent":[512*scale,512*scale],"setup_sha256":hashlib.sha256(raw.encode()).hexdigest()},
            "mixed_workload":{"schema":"pubpres-final-mixed-workload-v1","setup_json":raw,
                "paint_tape":copy.deepcopy(REGISTRATION["paint_tape"]),"actor_specification":copy.deepcopy(REGISTRATION["actors"]),
                "neutral_controls_before":copy.deepcopy(controls),"paint_events":[],"material_observations":[],
                "material_probe_cost":{"attempts":4,"total_usec":4,"max_usec":1}}}
    for phase in ("selectors_before","selectors_after"):
        data[phase]={"requested":{"CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ":"0"},
            "material_deadline":{"schema":"pubpres-material-deadline-v1","requested_hz":0,
                "enabled":False,"physical_credit":False,"interval_usec":0,"pending_count":0,
                "offers":0,"replaced_offers":0,"consumptions":0,"accepted_uploads":0,"cancellations":0,
                "pending_serial":-1,"pending_generation":-1,"deadline_usec":-1,"next_upload_usec":-1}}
    events = []
    for tick in range(1,145):
        selected = copy.deepcopy(controls)
        selected[0].update(sequence=tick,deadline=tick+5,command_empty=False)
        bodies = [{"slot":i,"instance_id":i+1,"xy":[i*30+tick if i==0 else i*30,80],"contacts":0} for i in range(8)]
        bodies[7].update(xy=[176*scale,233*scale],contacts=1)
        events.append({"event":"rapier_step","step":tick,"time_usec":1_000_000+tick*400_000,
                       "world_generation":4,"installed_hard_revision":200+tick,"command_sequence":tick,
                       "command_deadline_tick":tick+5,"control_generations":[3]*8,
                       "mixed_actor_controls":selected,"bodies":bodies})
    for i,spec in enumerate(REGISTRATION["paint_tape"]):
        clock = 1_000_000+spec["tick"]*400_000+10
        point = [value*scale for value in spec["point"]]
        data["mixed_workload"]["paint_events"].append({"action_index":i,"accepted":True,
            "physical_tick":spec["tick"],"absolute_tick":spec["tick"],"point":point,"material":spec["material"],
            "radius":8,"start_usec":clock,"time_usec":clock+10,"before_world_revision":99+i,
            "before_hard_revision":100+i,"before_native_tick":spec["tick"],"world_generation":4,"epoch":7})
        data["mixed_workload"]["material_observations"].append({"action_index":i,"material":spec["material"],
            "point":point,"time_usec":clock+150,"observer_usec":1,"world_generation":4,"world_revision":100+i,
            "render_serial":20+i,"native_tick":spec["tick"]+1,"generated_usec":clock+30})
        events += [{"event":"texture_upload","start_usec":clock+50,"time_usec":clock+100,
                    "world_generation":4,"render_serial":20+i,"tick_index":spec["tick"]+1,"generated_usec":clock+30},
                   {"event":"main_callback","start_usec":clock-10,"time_usec":clock+1000}]
    return data,events


class MixedContractTests(unittest.TestCase):
    def test_explicit_derivation_preserves_original_callback_and_oracle_bytes(self):
        proof = verify_mixed_contract(ROOT)
        self.assertEqual(len(proof["observer_sha256"]),64)
        observer = (ROOT / "tools/pubpres003/pubpres_causal_gameplay.gd").read_bytes()
        with self.assertRaises(ValueError):
            expected_mixed_observer(observer.replace(b"super._physics_process(delta)",b"pass",1),REGISTRATION)
        reducer = (ROOT / "tools/pubpres_playability/results_same_frame.py").read_bytes()
        with self.assertRaises(ValueError):
            expected_mixed_reducer(reducer.replace(b'"pending_hard_chunks"',b'"ignored_hard_chunks"',1))

    def test_new_registration_has_eight_actors_four_workers_and_sixty_seconds(self):
        campaign = mixed_campaign(REGISTRATION,REGISTRATION["cases"])
        self.assertEqual(campaign["schema"],"pubpres-final-mixed-campaign-v1")
        self.assertEqual(len(campaign["measurement"]["required_actors"]),8)
        self.assertEqual(campaign["measurement"]["minimum_capture_usec"],60_000_000)
        self.assertEqual([row["workers"] for row in campaign["cases"]],[4,4])
        self.assertEqual([row["fixture"] for row in campaign["cases"]],["basin512","basin1024"])
        with self.assertRaises(ValueError): mixed_campaign(REGISTRATION,["wave_512_follow"])

    def test_native_selector_derivation_still_refuses_callback_or_readback_mutation(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for relative in ("tools/pubpres_final/mixed_registration.json",
                             "tools/pubpres_final/pubpres_final_mixed_gameplay.gd",
                             "tools/pubpres_final/results_registered_mixed.py",
                             "tools/pubpres003/pubpres_causal_gameplay.gd",
                             "tools/pubpres_playability/results_same_frame.py"):
                target = root / relative
                target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(ROOT / relative,target)
            observer = root / "tools/pubpres_final/pubpres_final_mixed_gameplay.gd"
            original = observer.read_bytes()
            self.assertEqual(verify_mixed_contract(root)["observer_sha256"],hashlib.sha256(original).hexdigest())
            for old,new in ((b"super._physics_process(delta)",b"pass"),
                            (b'.get("task_completion",null)',b'.get("column_probe",null)'),
                            (b'"cybersand/pubpres_task_completion_barrier"',b'"cybersand/native_worker_threads"')):
                self.assertEqual(original.count(old),1)
                observer.write_bytes(original.replace(old,new,1))
                with self.subTest(change=old),self.assertRaisesRegex(ValueError,"unregistered callback"):
                    verify_mixed_contract(root)

    def test_both_registered_extents_validate_complete_synthetic_controls(self):
        for scale in (1,2):
            data,events = fixture(scale)
            result = validate_mixed_workload(data,events,REGISTRATION)
            self.assertEqual(result["controls"]["neutral_actor_count"],7)
            self.assertEqual(result["paint"]["ordinary_admissions"],4)
            self.assertEqual(result["passive_contact_steps"],144)

    def test_mixed_requires_actual_deadline_off_in_both_observations(self):
        for phase in ("selectors_before","selectors_after"):
            for key,value in (("requested_hz",30),("enabled",True),("physical_credit",True),
                              ("offers",1),("accepted_uploads",1),("pending_count",1),
                              ("next_upload_usec",100),("pending_serial",0),("interval_usec",16667),
                              ("pending_count",False),("offers",0.0)):
                data,events=fixture();data[phase]["material_deadline"][key]=value
                with self.subTest(phase=phase,key=key,value=value),self.assertRaises(ValueError):
                    validate_mixed_workload(data,events,REGISTRATION)
            data,events=fixture();data[phase]["material_deadline"]=None
            with self.assertRaises(ValueError):validate_mixed_workload(data,events,REGISTRATION)
            data,events=fixture();data[phase]["requested"]["CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ"]="30"
            with self.assertRaises(ValueError):validate_mixed_workload(data,events,REGISTRATION)

    def test_consistent_setup_rehash_cannot_change_positions_materials_or_models(self):
        for label,change in (
            ("position",lambda s:s["actors"][5]["spawn"].__setitem__(0,359)),
            ("definition",lambda s:s["actors"][6].update(hash="other")),
            ("option",lambda s:s["actors"][7]["options"].update(mass_multiplier=.5)),
            ("terrain",lambda s:s["edits"][0].__setitem__(4,1)),
            ("actor_count",lambda s:s["actors"].pop()),
            ("brush",lambda s:s.update(brush=16)),
            ("source",lambda s:s.update(source=[1,2,3])),
        ):
            with self.subTest(label=label):
                data,_ = fixture()
                setup = json.loads(data["mixed_workload"]["setup_json"]);change(setup)
                raw = json.dumps(setup);data["mixed_workload"]["setup_json"] = raw
                data["fixture"]["setup_sha256"] = hashlib.sha256(raw.encode()).hexdigest()
                with self.assertRaises(ValueError): validate_setup(data,REGISTRATION)

    def test_paint_clock_owner_upload_contact_and_probe_cost_adversaries(self):
        changes = [
            ("paint_rejected",lambda d,e:d["mixed_workload"]["paint_events"][0].update(accepted=False)),
            ("wrong_tick",lambda d,e:d["mixed_workload"]["paint_events"][1].update(physical_tick=63)),
            ("different_world",lambda d,e:d["mixed_workload"]["paint_events"][2].update(world_generation=5)),
            ("outside_callback",lambda d,e:d["mixed_workload"]["paint_events"][0].update(start_usec=1_000_000)),
            ("no_revision",lambda d,e:d["mixed_workload"]["material_observations"][0].update(world_revision=99)),
            ("wrong_upload",lambda d,e:d["mixed_workload"]["material_observations"][1].update(render_serial=999)),
            ("wrong_native_tick",lambda d,e:d["mixed_workload"]["material_observations"][2].update(native_tick=1)),
            ("outside_sand_scan",lambda d,e:d["mixed_workload"]["material_observations"][2].update(point=[500,500])),
            ("erase_without_wall",lambda d,e:d["mixed_workload"]["material_observations"][0].update(time_usec=60_000_000)),
            ("probe_cost_hidden",lambda d,e:d["mixed_workload"]["material_probe_cost"].update(total_usec=0)),
            ("unselected_command",lambda d,e:e[40]["mixed_actor_controls"][4].update(command_empty=False)),
            ("unselected_generation",lambda d,e:e[40]["mixed_actor_controls"][5].update(generation=4)),
            ("selected_sequence",lambda d,e:e[40]["mixed_actor_controls"][0].update(sequence=999)),
            ("no_contact",lambda d,e:[row["bodies"][7].update(contacts=0) for row in e if row["event"]=="rapier_step"]),
            ("no_later_terrain",lambda d,e:[row.update(installed_hard_revision=0) for row in e if row["event"]=="rapier_step"]),
        ]
        for label,change in changes:
            with self.subTest(label=label):
                data,events = fixture();change(data,events)
                with self.assertRaises(ValueError): validate_mixed_workload(data,events,REGISTRATION)

    def test_expanded_reducer_validates_every_real_body_and_sample(self):
        with tempfile.TemporaryDirectory() as folder:
            campaign,data,rows,_ = complete_reader_fixture(Path(folder))
            campaign["measurement"].pop("required_actor")
            campaign["measurement"]["required_actors"] = required_actors(REGISTRATION)
            campaign["measurement"]["minimum_capture_usec"] = 60_000_000
            data.update(minimum_capture_usec=60_000_000,capture_end_usec=61_000_000)
            roster = []
            for expected in required_actors(REGISTRATION):
                slot = expected["actor_slot"]
                roster.append({**{k:v for k,v in expected.items() if k!="body_count"},"bodies":[{
                    "body_slot":slot,"node_class":"RigidBody2D","body_rid":101+slot,
                    "bridge_rid":101+slot,"node_instance_id":99+slot}]})
            data["actor_roster_before"]=roster;data["actor_roster_after"]=copy.deepcopy(roster)
            events = rows[1:]
            for row in events:
                if row["event"]!="rapier_step": continue
                body=row["bodies"][0]
                row["bodies"]=[{**body,"slot":slot,"instance_id":slot+1} for slot in range(8)]
                row["body_ownership"]=[{"slot":slot,"body_rid":101+slot} for slot in range(8)]
                row["accepted_samples"]*=8
            result=validate_measurement_trace(data,campaign,events)
            self.assertEqual(len(result["actor_roster"]),8)
            step=next(row for row in events if row["event"]=="rapier_step" and row["step"]==20)
            for field,value in (("bodies",step["bodies"][:7]),("body_ownership",step["body_ownership"][:7]),
                                ("accepted_samples",step["accepted_samples"][:7]),("packet_failed",True),
                                ("completed_body_sample",999),("world_generation",8)):
                old=step[field];step[field]=value
                with self.subTest(field=field),self.assertRaises(ValueError): validate_measurement_trace(data,campaign,events)
                step[field]=old
            data["actor_roster_before"][6]["bodies"][0].update(body_rid=101,bridge_rid=101)
            data["actor_roster_after"]=copy.deepcopy(data["actor_roster_before"])
            with self.assertRaisesRegex(ValueError,"aliases"): validate_measurement_trace(data,campaign,events)

    def test_correctness_source_runtime_and_graphical_prerequisites_cannot_be_relabelled(self):
        with tempfile.TemporaryDirectory() as folder:
            folder=Path(folder);engine=folder/"engine";engine.write_bytes(b"synthetic executable identity")
            source={"source_commit":"a"*40,"source_tree":"b"*40,
                    "native_runtime":{"binary_sha256":"c"*64,"manifest_sha256":"d"*64}}
            driver={"source_commit":source["source_commit"],"source_tree":source["source_tree"]}
            proof={"schema":"pubpres-playability-final-correctness-v1","complete":True,"headless_only":False,
                   "physical_acceptance":"HOLD","source":source,"driver":driver,"native":source["native_runtime"],
                   "engine_sha256":hashlib.sha256(engine.read_bytes()).hexdigest(),
                   "import_source_mutations":[],"final_source_mutations":[],"outcomes":[{"test":name,"valid":True} for name in
                    ("test_full_image_ring_publication","pubpres_full_image_ring_oracle","test_full_image_ring_main_recovery",
                     "test_physical_actor_integration","test_workbench_physics_publication")]}
            path=folder/"SUMMARY.json";path.write_text(json.dumps(proof))
            self.assertTrue(correctness_prerequisite(path,source,driver,engine)["complete"])
            for key,value in (("complete",False),("headless_only",True),("engine_sha256","wrong"),("outcomes",[]),
                              ("final_source_mutations",["scripts/main.gd"])):
                bad=copy.deepcopy(proof);bad[key]=value;path.write_text(json.dumps(bad))
                with self.subTest(field=key),self.assertRaises(ValueError): correctness_prerequisite(path,source,driver,engine)


if __name__=="__main__":
    unittest.main()
