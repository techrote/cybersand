#!/usr/bin/env python3
"""Offline adverse controls; synthetic records never qualify an engine host."""
from copy import deepcopy
import unittest

import pace004_load_contract as load
import pace004_execution as execution
import run_pace004_campaign as campaign
from test_pace004_contract import Tape


def fixture(mode=load.ACTIVE):
    owner=Tape().snap()
    start=1_000_000_000
    owner.update(time_usec=start,native_tick=10,tick=10,serial=100,step=10)
    native=[];main=[];pulses=[]
    for i in range(900):
        timestamp=start+i*16_666
        native.append({"completed_usec":timestamp,"tick":11+i,"serial":101+i,
            "generation":owner["world_generation"],"epoch":owner["epoch"],
            "visited_cells":128 if mode==load.ACTIVE else 0,
            "moved_cells":32 if mode==load.ACTIVE else 0,"observer_usec":2,
            "brush_observer_usec":3,"brush_cells":[
                {"ok":True,"completed_tick":11+i,"x":centre[0],"y":centre[1],
                 "material":material if mode==load.ACTIVE else 0}
                for centre,material in zip(load.CENTRES,load.MATERIALS)]})
        main.append({"started_usec":timestamp,"ended_usec":timestamp+100,
            "serial":101+i,"tick":11+i,"epoch":owner["epoch"],"generation":owner["world_generation"]})
    for pulse_id in range(1,151):
        due=start+(pulse_id-1)*load.PERIOD_USEC
        entered=due+200
        callback=max((row for row in main if row["ended_usec"]<=entered),key=lambda row:row["ended_usec"])
        before=deepcopy(owner)|{"time_usec":entered+10,"serial":callback["serial"],"native_tick":callback["tick"]}
        after=deepcopy(before)|{"time_usec":entered+100}
        commands=[]
        for slot in (0,1):
            commands.append({"id":(pulse_id-1)*2+slot+1,"pulse_id":pulse_id,"slot":slot,
                "centre":list(load.CENTRES[slot]),"material":load.MATERIALS[slot],"flags":0,
                "shape":"square","size":8,"points":load.footprint(load.CENTRES[slot]),
                "started_usec":entered+20+slot*20,"ended_usec":entered+25+slot*20,
                "attempted":mode==load.ACTIVE,"accepted":mode==load.ACTIVE,"control_skipped":mode!=load.ACTIVE})
        pulses.append({"id":pulse_id,"scheduled_usec":due,"entered_usec":entered,"ended_usec":entered+110,
            "before":before,"after":after,"commands":commands,"recipe_sha256":load.RECIPE_SHA256})
    return {"measurement":{"started_usec":start,"ended_usec":start+15_000_000,"initial":owner},
        "waits":[{"name":"initial loaded owner native progress","passed":True,"limit_usec":execution.usec("operation_seconds"),
                  "started_usec":start-10_000,"ended_usec":start-100}],
        "main_rows":main,"native_rows":native,"workload":{
            "mode":mode,"started":True,"recipe":load.RECIPE,"recipe_sha256":load.RECIPE_SHA256,
            "helper_sha256":"a"*64,"errors":[],"owner":deepcopy(owner),"started_usec":start,
            "stopped_usec":start+15_000_001,"pulses":pulses,
            "scope":{"normal_brush_queue":True,"native_world_queries_from_main":0,"priming_usec":0,
                "per_command_native_applied_receipts":False,"individual_admission_then_measured_cell_activity":True,
                "producer_cost_outside_main_callback":True}}}


class ActiveWorkload(unittest.TestCase):
    def setUp(self):self.value=fixture()
    def verify(self,mode=load.ACTIVE):return load.verify_workload(self.value,mode,"a"*64)
    def reject(self,message,mode=load.ACTIVE):
        with self.assertRaisesRegex(ValueError,message):self.verify(mode)

    def test_positive_full_active_inventory(self):
        result=self.verify()
        self.assertEqual((result["pulse_count"],result["command_count"],result["admitted_commands"]),(150,300,300))
        self.assertTrue(result["active_activity_passed"])
        self.assertEqual(len(result["activity"]["seconds"]),15)
        self.assertFalse(result["individual_native_application_receipts"])

    def test_positive_matched_no_load_fails_activity_for_intended_reasons(self):
        self.value=fixture(load.IDLE)
        result=self.verify(load.IDLE)
        self.assertFalse(result["active_activity_passed"])
        self.assertEqual(result["admitted_commands"],0)
        self.assertIn("median_visited_below_64",result["activity_rejections"])
        self.assertIn("median_moved_below_16",result["activity_rejections"])
        self.assertIn("second_14_no_intended_material_observation",result["activity_rejections"])

    def test_complete_sixteen_case_plan_separate_from_original_fourteen(self):
        self.assertEqual(len(load.plan()),16)
        self.assertEqual(len(set(load.plan())),16)
        self.assertEqual(len(campaign.plan(False)),14)
        self.assertEqual(len(campaign.plan(True)),6)
        with self.assertRaisesRegex(ValueError,"headless only"):campaign.case_plan(True,True)

    def test_unstarted_failure_not_accepted(self):
        self.value["workload"]["started"]=False;self.reject("Wrong/unstarted workload")

    def test_wrong_recipe_rejected(self):
        self.value["workload"]["recipe"]+=";changed";self.reject("recipe identity")

    def test_wrong_helper_source_rejected(self):
        self.value["workload"]["helper_sha256"]="b"*64;self.reject("differs from executed source")

    def test_producer_failure_rejected(self):
        self.value["workload"]["errors"].append("queue refused");self.reject("producer reported")

    def test_invented_native_application_receipt_rejected(self):
        self.value["workload"]["scope"]["per_command_native_applied_receipts"]=True;self.reject("receipt claim")

    def test_native_running_acknowledgement_required(self):
        self.value["waits"]=[];self.reject("bounded native-running acknowledgement")

    def test_still_paused_native_owner_rejected(self):
        self.value["measurement"]["initial"]["native_paused"]=True
        self.value["workload"]["owner"]["native_paused"]=True
        self.reject("before native running acknowledgement")

    def test_missing_pulse_rejected(self):
        self.value["workload"]["pulses"].pop();self.reject("pulse inventory")

    def test_duplicate_pulse_identity_rejected(self):
        self.value["workload"]["pulses"][1]["id"]=1;self.reject("pulse source/order")

    def test_late_pulse_cannot_be_hidden_by_complete_count(self):
        pulse=self.value["workload"]["pulses"][0];pulse["entered_usec"]=pulse["scheduled_usec"]+100_000
        self.reject("Late/reordered workload pulse")

    def test_native_owner_and_control_generation_substitution_rejected(self):
        for field in load.LOAD_OWNER:
            with self.subTest(field=field):
                self.value=fixture();pulse=self.value["workload"]["pulses"][10]
                pulse["before"][field]="other" if field=="run_id" else pulse["before"][field]+1
                self.reject("owner/generation changed")

    def test_pulse_state_must_match_real_main_publication(self):
        pulse=self.value["workload"]["pulses"][10]
        pulse["before"]["serial"]+=1;pulse["after"]["serial"]+=1
        self.reject("matching actual Main publication")

    def test_focus_or_pause_refusal_is_not_load_admission(self):
        for field,replacement in (("paused",True),("native_paused",True),("suspended",True),("focus",False),("rearm",True)):
            with self.subTest(field=field):
                self.value=fixture()
                for label in ("before","after"):self.value["workload"]["pulses"][10][label][field]=replacement
                self.reject("without playable authority")

    def test_missing_command_rejected(self):
        self.value["workload"]["pulses"][10]["commands"].pop();self.reject("command inventory")

    def test_reordered_command_rejected(self):
        self.value["workload"]["pulses"][10]["commands"].reverse();self.reject("reordered workload command")

    def test_footprint_or_material_change_rejected(self):
        for field,replacement in (("material",0),("flags",1),("size",7),("shape","circle"),("points",[1,2])):
            with self.subTest(field=field):
                self.value=fixture();self.value["workload"]["pulses"][10]["commands"][0][field]=replacement
                self.reject("footprint/material changed")

    def test_queue_refusal_cannot_be_relabelled_as_active_work(self):
        self.value["workload"]["pulses"][10]["commands"][0]["accepted"]=False
        self.reject("admission/control disposition")

    def test_true_activity_cannot_substitute_for_no_load_control(self):
        self.value["workload"]["mode"]=load.IDLE
        for pulse in self.value["workload"]["pulses"]:
            for command in pulse["commands"]:command.update(attempted=False,accepted=False,control_skipped=True)
        self.reject("no-load negative unexpectedly passed",load.IDLE)

    def test_all_admitted_but_no_actual_cell_work_rejected(self):
        for row in self.value["native_rows"]:row.update(visited_cells=0,moved_cells=0)
        self.reject("median_visited_below_64")

    def test_visited_cells_without_actual_motion_rejected(self):
        for row in self.value["native_rows"]:row["moved_cells"]=0
        self.reject("median_moved_below_16")

    def test_short_burst_cannot_replace_sustained_activity(self):
        for row in self.value["native_rows"][:300]:row.update(visited_cells=0,moved_cells=0)
        self.reject("active_tick_fraction_below_0.75")

    def test_one_idle_second_rejected_even_with_positive_global_medians(self):
        for row in self.value["native_rows"][300:360]:row.update(visited_cells=0,moved_cells=0)
        self.reject("second_05_insufficient")

    def test_counters_without_intended_native_material_observation_rejected(self):
        for row in self.value["native_rows"]:
            for cell in row["brush_cells"]:cell["material"]=0
        self.reject("no_intended_material_observation")

    def test_stale_native_cell_tick_rejected(self):
        self.value["native_rows"][10]["brush_cells"][0]["completed_tick"]-=1
        self.reject("Stale/mismatched native brush cell")

    def test_other_native_cell_position_rejected(self):
        self.value["native_rows"][10]["brush_cells"][0]["x"]+=1
        self.reject("Stale/mismatched native brush cell")

    def test_missing_native_observation_or_cost_rejected(self):
        self.value["native_rows"][10].pop("brush_observer_usec")
        self.reject("brush cell observer time")

    def test_boolean_is_not_a_command_identity_or_flags(self):
        for field in ("id","flags"):
            with self.subTest(field=field):
                self.value=fixture();self.value["workload"]["pulses"][0]["commands"][0][field]=field=="id"
                self.reject("Invalid integer: brush command")


if __name__=="__main__":unittest.main()
