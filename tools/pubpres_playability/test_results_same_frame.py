#!/usr/bin/env python3
"""Synthetic adversaries for v3 evidence admission; no performance claims."""
import copy
from pathlib import Path
import tempfile
import unittest

from results import reduce_receipt as reduce_v2
from results_same_frame import reduce_receipt, validate_continuations, window
from test_results import complete_reader_fixture, fixture


def continuation_fixture():
    owner = {"owner":"100","bridge":"-9223372009138813471","worker":"-9223372009138813472","epoch":7,"session":11}
    status = {"version":1,"requested":True,"enabled":True,"disabled_reason":"","mode":"same_frame_once",
              "maximum_attempts_per_process_frame":1,"maximum_mailbox_reads_per_attempt":1,
              "wait_usec":0,"new_physics_callbacks":0,"carried_time_credit":False}
    selectors = {"requested":{"CYBERSAND_DIAG_SAME_FRAME_CONTINUATION":"1"},"same_frame_continuation":status}
    data = {"physical_owner_before":owner,"physical_owner_after":copy.deepcopy(owner),
            "selectors_before":selectors,"selectors_after":copy.deepcopy(selectors)}
    campaign = {"arms":{"C":{"same_frame_continuation":True}}}
    callback = {"event":"physics_callback","callback_id":1,"physics_frame":600,"process_frame":10,
                "start_usec":100,"time_usec":120,"before_step":12,"after_step":12,"waiting_body_sample":13}
    identity = {**owner,"tick":12,"manual_steps":12,"sample":13,"bridge_sample":13,"installed_revision":99,
                "accepted_commands":20,"sequences":[20],"generations":[2],"deadlines":[18]}
    attempt = {"event":"physics_continuation","start_usec":160,"time_usec":200,"process_frame":10,
               "origin_callback_id":1,"origin_callback_start_usec":100,"origin_process_frame":10,"origin_physics_frame":600,
               "source_callback_serial":1,"source_callback_start_usec":102,"held_usec":115,
               "source_process_frame":10,"source_physics_frame":600,"before_step":12,"after_step":13,
               "advanced":True,"status":"ready","polls":1,"fixed_callback_delta":1/60,"expected_identity":identity,
               "expected_world_generation":4,"expected_required_revision":99}
    step = {"event":"rapier_step","start_usec":160,"time_usec":190,"step":13,
            "execution_kind":"physics_continuation","origin_callback_id":1,"origin_callback_start_usec":100,
            "origin_process_frame":10,"origin_physics_frame":600,"process_frame":10,
            "epoch":7,"session":11,"control_generations":[2],"accepted_command_count":20,
            "world_generation":4,"manual_steps":13,"completed_body_sample":13,"required_hard_revision":99,
            "command_sequence":20,"command_deadline_tick":18}
    return data,campaign,[callback,step,attempt]


class ContinuationEvidenceTests(unittest.TestCase):
    def test_step_endpoint_precedes_attempt_observation(self):
        data, events = fixture()
        step = next(r for r in events if r["event"] == "rapier_step" and r["step"] == 1)
        step["execution_kind"] = "physics_continuation"
        events.append({"event":"physics_continuation", "start_usec":1950, "time_usec":2010,
                       "held_usec":1800, "advanced":True})
        for cutoff, steps, completed, censored in ((1999,0,0,1),(2000,1,0,1),(2010,1,1,0)):
            with self.subTest(cutoff=cutoff):
                result = window(events, data, cutoff)
                self.assertEqual(result["same_frame_completed_steps"], steps)
                self.assertEqual(result["same_frame_attempts"], completed)
                self.assertEqual(result["same_frame_attempts_censored_at_end"], censored)
                self.assertEqual(result["same_frame_attempts_started"], 1)

    def test_unique_withheld_callback_is_accepted(self):
        data,campaign,events=continuation_fixture()
        result=validate_continuations(data,campaign,events,"C")
        self.assertEqual(result["actual_physics_callbacks"],1)
        self.assertEqual(result["completed_continuations"],1)
        self.assertEqual(result["completed_in_callbacks"],0)

    def test_each_forged_credit_or_owner_fails(self):
        mutations = [
            (0,"after_step",13),(0,"callback_id",2),(0,"physics_frame",601),
            (1,"origin_callback_id",2),(1,"execution_kind","physics_callback"),
            (1,"manual_steps",14),(1,"completed_body_sample",14),(1,"required_hard_revision",98),
            (1,"command_sequence",21),(1,"command_deadline_tick",19),(1,"control_generations",[3]),
            (1,"accepted_command_count",21),(1,"world_generation",5),(1,"epoch",8),
            (1,"session",12),(1,"process_frame",11),(1,"start_usec",159),(1,"time_usec",201),
            (2,"process_frame",11),(2,"source_process_frame",11),(2,"source_physics_frame",601),
            (2,"source_callback_serial",2),(2,"polls",2),(2,"fixed_callback_delta",1/30),
            (2,"advanced",False),(2,"status","native_sample"),(2,"source_callback_start_usec",99),
            (2,"held_usec",121),(2,"origin_callback_start_usec",101),
        ]
        for index,key,value in mutations:
            with self.subTest(event=index,field=key):
                data,campaign,events=continuation_fixture()
                events[index][key]=value
                with self.assertRaises(ValueError): validate_continuations(data,campaign,events,"C")
        for key in ("owner","bridge","worker","sample","bridge_sample","manual_steps","tick","installed_revision","accepted_commands"):
            with self.subTest(identity=key):
                data,campaign,events=continuation_fixture()
                value=events[2]["expected_identity"][key]
                events[2]["expected_identity"][key]=str(int(value)+1) if isinstance(value,str) else value+1
                with self.assertRaises(ValueError): validate_continuations(data,campaign,events,"C")

    def test_no_duplicate_or_new_callback_credit(self):
        for variant in ("duplicate_step","duplicate_attempt","later_callback","extra_command","no_callback"):
            with self.subTest(variant=variant):
                data,campaign,events=continuation_fixture()
                if variant=="duplicate_step":events.append(copy.deepcopy(events[1]))
                if variant=="duplicate_attempt":events.append(copy.deepcopy(events[2]))
                if variant=="later_callback":events.append({**events[0],"callback_id":2,"physics_frame":601,"start_usec":130,"time_usec":140})
                if variant=="extra_command":events.append({"event":"command_attempt","time_usec":150})
                if variant=="no_callback":events=events[1:]
                with self.assertRaises(ValueError): validate_continuations(data,campaign,events,"C")

    def test_contended_attempt_is_not_a_step(self):
        data,campaign,events=continuation_fixture()
        events.pop(1)
        events[1].update(advanced=False,after_step=12,status="contended")
        result=validate_continuations(data,campaign,events,"C")
        self.assertEqual(result["completed_continuations"],0)
        self.assertEqual(result["outcomes"],{"contended":1})

    def test_selector_and_owner_refusals(self):
        for variant in ("disabled","unavailable","budget","renamed_owner","float_owner"):
            with self.subTest(variant=variant):
                data,campaign,events=continuation_fixture()
                if variant=="disabled":campaign["arms"]["C"]["same_frame_continuation"]=False
                if variant=="unavailable":data["selectors_before"]["same_frame_continuation"]=None
                if variant=="budget":data["selectors_after"]["same_frame_continuation"]["wait_usec"]=1
                if variant=="renamed_owner":data["physical_owner_after"]["owner"]="101"
                if variant=="float_owner":data["physical_owner_before"]["bridge"]=float(data["physical_owner_before"]["bridge"])
                with self.assertRaises(ValueError): validate_continuations(data,campaign,events,"C")

    def test_full_144_step_legacy_oracles_remain_exact(self):
        with tempfile.TemporaryDirectory() as folder:
            campaign,data,rows,save=complete_reader_fixture(Path(folder))
            original=reduce_v2(save(),campaign,arm_letter="M")
            campaign["schema"]="pubpres-playability-campaign-v3"
            data["schema"]="pubpres-playability-gameplay-v3"
            owner={"owner":"100","bridge":"-9223372009138813471","worker":"-9223372009138813472","epoch":1,"session":1}
            data["physical_owner_before"]=owner;data["physical_owner_after"]=copy.deepcopy(owner)
            for selector in (data["selectors_before"],data["selectors_after"]): selector["same_frame_continuation"]=None
            for row in rows:
                if row["event"]=="physics_callback":
                    tick=row["after_step"]
                    row.update(callback_id=tick,physics_frame=600+tick,process_frame=tick,waiting_body_sample=tick+1)
                if row["event"]=="rapier_step":
                    tick=row["step"]
                    row.update(execution_kind="physics_callback",origin_callback_id=tick,origin_callback_start_usec=row["start_usec"],
                               origin_physics_frame=600+tick,origin_process_frame=tick,process_frame=tick,
                               control_generations=[2],accepted_command_count=tick)
            current=reduce_receipt(save(),campaign,arm_letter="M")
            for key in ("first_144_body_trajectory_sha256","first_144_admitted_moves_sha256"):
                self.assertEqual(current[key],original[key])
            for key in ("duration_seconds","completed_rapier_steps","physical_gap_ms","rapier_steps_per_second"):
                self.assertEqual(current["windows"]["first_144_steps"][key],original["windows"]["first_144_steps"][key])
            self.assertEqual(current["same_frame_continuation"]["completed_in_callbacks"],144)
            self.assertFalse(current["same_frame_continuation"]["available"])
            data["render_thread"] = {"runtime":"separate", "requested":"separate"}
            with self.assertRaisesRegex(ValueError, "Safe"): reduce_receipt(save(), campaign, arm_letter="M")
            data["render_thread"] = {"runtime":"safe", "requested":"safe"}
            # Full original native/terrain/input/ownership validation still runs.
            for field,value in (("packet_failed",True),("world_generation",8),("pending_hard_chunks",1),
                                ("response_accepted",False),("admitted_move",[.5,.5]),("body_ownership",[])):
                row=next(r for r in rows if r["event"]=="rapier_step" and r["step"]==20)
                old=row[field];row[field]=value
                with self.subTest(field=field),self.assertRaises(ValueError): reduce_receipt(save(),campaign,arm_letter="M")
                row[field]=old


if __name__=="__main__": unittest.main()
