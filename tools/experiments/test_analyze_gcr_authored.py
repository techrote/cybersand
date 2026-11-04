"""Failure controls for the authored-compound evidence reducer."""
import copy
import unittest
from analyze_gcr_authored import (DEFINITION_HASH, REG, EvidenceError,
                                  carry_gate, conserved, reduce_capture,verify_source_map,
                                  DEFINITION, HISTORICAL_DEFINITION, registered_definition_path)


class AuthoredAnalysisTests(unittest.TestCase):
    def test_historical_profile_authority_is_explicit(self):
        self.assertEqual(registered_definition_path({"retained":{DEFINITION:b"old"},"hashes":{}}),DEFINITION)
        new={"retained":{DEFINITION:b"new",HISTORICAL_DEFINITION:b"old"},"hashes":{}}
        with self.assertRaises(EvidenceError):registered_definition_path(new)
        new["hashes"]["godot/tests/support/gcr_historical_scooper.gd"]="bound"
        self.assertEqual(registered_definition_path(new),HISTORICAL_DEFINITION)
    def fixture(self):
        census={"counts":[100,0,16,20],"sum_y":[0,0,160,200],"water_mass":36}
        spec={"id":"landing","material":2,"ticks":1}
        context={"platform":"windows","source":"source","inputs_hash":"inputs","protocol_sha256":"protocol","native_sha256":"native","dt":1/60,"carry_gate":{}}
        g={"proxy_count":6,"physical_body_id":1,"sample_serial":2,"session_id":1,"mass":.18,"inertia":22.099868512110724,
           "normal_accepted":1.,"event_budget_cost":1.,"global_capacity":20.,"energy_before":1.,"energy_after":1.,
           "nodes":16,"updates":128,"impulse":[0.,1.],"torque":0.,"event_accepted":[0.,1.],"event_torque":0.}
        row={"tick":0,"gcr":g,"application":{"accepted":True,"bodies":[{"session":1,"index":0,"sample":2,"age":0,"physical_wrench_applications":1}]},
             "observed_steps":[1,1],"observed_response_counts":[1,1],"physical_wrench_applications":1,
             "state":{"position":[0.,0.],"velocity":[0.,0.],"rotation":0.,"omega":0.},"step_us":100,"work":[4,2,8]}
        raw={"registration":REG,"case":spec,"response":"LA","platform":"Windows",
             "identity":{"source":"source","inputs":"inputs","protocol_sha256":"protocol","native_sha256":"native","definition_hash":DEFINITION_HASH,"physics_backend":"Rapier2D","engine_version":"4.7-stable"},
             "options":{"response":"LA","budget":20.,"mass_multiplier":1.,"inertia_multiplier":1.,"thrust_multiplier":1.,"torque_multiplier":1.,"boost_multiplier":2.},
             "mass":.18,"inertia":22.099868512110724,"rows":[row],"initial":copy.deepcopy(row["state"]),"before":census,"after":copy.deepcopy(census),
             "censuses":[{"tick":0,"observed":copy.deepcopy(census),"conserved":True,"source_inserted":0}],"source":{"inserted":0},"errors":[],"ok":True}
        receipt={"ok":True,"exit":0,"timed_out":False,"identity_ok":True}
        return raw,spec,context,receipt

    def test_prefix_never_becomes_complete(self):
        raw,spec,context,receipt=self.fixture()
        spec["ticks"]=2;raw["ok"]=False;receipt["ok"]=False;receipt["exit"]=1
        result,_,_=reduce_capture(raw,spec,"LA",context,receipt)
        self.assertTrue(result["mechanical_observed_prefix_ok"])
        self.assertFalse(result["capture_complete"])
        self.assertFalse(result["mechanical_complete_pass"])

    def test_budget_and_passivity_corruption(self):
        for key,value in (("normal_accepted",20.),("energy_after",1.001),("nodes",97),("updates",769)):
            raw,spec,context,receipt=self.fixture();raw["rows"][0]["gcr"][key]=value
            result,_,_=reduce_capture(raw,spec,"LA",context,receipt)
            self.assertFalse(result["mechanical_complete_pass"],key)

    def test_identity_corruption_refuses(self):
        raw,spec,context,receipt=self.fixture();raw["identity"]["definition_hash"]="wrong"
        with self.assertRaises(EvidenceError):reduce_capture(raw,spec,"LA",context,receipt)

    def test_empty_or_partial_source_maps_refuse(self):
        expected={"godot/a.gd":"a","godot/b.json":"b"}
        for bad in ({},{"godot/a.gd":"a"},{"godot/a.gd":"a","godot/b.json":"wrong"}):
            with self.assertRaises(EvidenceError):verify_source_map(bad,expected,"test")
        verify_source_map(expected,expected,"test")

    def test_events_off_cannot_retain_event_wrench(self):
        raw,spec,context,receipt=self.fixture()
        raw["response"]="LA-EVENT-OFF";raw["options"]["response"]="LA-EVENT-OFF"
        result,_,_=reduce_capture(raw,spec,"LA-EVENT-OFF",context,receipt)
        self.assertFalse(result["mechanical_complete_pass"])

    def test_exact_native_and_water_accounting(self):
        before={"counts":[100,0,16,20],"sum_y":[0,0,160,200],"water_mass":36}
        after={"counts":[98,0,20,12],"sum_y":[0,0,180,160],"water_mass":36}
        self.assertTrue(conserved(before,after,2,4))
        after["counts"][2]=19;self.assertFalse(conserved(before,after,2,4))
        after["counts"][2]=20;after["water_mass"]=35;self.assertFalse(conserved(before,after,2,4))

    def test_auxiliary_pose_cannot_replace_primary_gap(self):
        gate={"initial_grains":16,"min_retained":8,"rise_cells":8,"tip_start":300,"tip_deadline":600,"release_fraction":.5}
        raw={"case":{"material":2},"before":{"counts":[0,0,16]},"initial":{"position":[0,100]},"rows":[]}
        for tick,y,count in ((0,100,16),(15,90,0),(300,90,0),(600,90,0)):
            raw["rows"].append({"tick":tick,"state":{"position":[0,y]},"cavity_count":count,"sample_pose_cavity_count":16})
        result=carry_gate(raw,gate)
        self.assertFalse(result["lift_gate_pass"])
        self.assertFalse(result["spill_gate_pass"])
        self.assertFalse(result["observed_uninterrupted_primary_load_before_tip"])
        self.assertIn(15,result["primary_zero_before_tip"])


if __name__=="__main__":unittest.main()
