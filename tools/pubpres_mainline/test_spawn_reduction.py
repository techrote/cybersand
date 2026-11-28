"""Independent clock joins, including owner replacement and recording gaps."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("run_spawn", Path(__file__).with_name("run_spawn.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SpawnReduction(unittest.TestCase):
    def test_short_adverse_tail_uses_established_nearest_rank(self):
        result = module.metrics([10,20,500])
        self.assertEqual(result["p50_usec"],20)
        self.assertEqual(result["p95_usec"],500)
        self.assertEqual(result["p99_usec"],500)

    def case(self):
        return {"label":"spawn", "accepted":True, "request_serial":9, "request_usec":100,
                "request_return_usec":125,"admitted_usec":200,"epoch":8,"end_usec":400,
                "first_observed_step_usec":260,"first_input_usec":220,
                "input_accepted_observed_usec":230,"input_applied_observed_usec":270,
                "first_coherent_draw_observed_usec":280}

    def reduce(self, rows):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            (folder / "segment-0.jsonl").write_text("\n".join(json.dumps(row) for row in rows)+"\n")
            return module.reduce(folder,{"cases":[self.case()]})

    def test_keeps_replacement_gap_and_separates_physical_clock(self):
        rows = [["step",80,0,0,1,7], ["step",210,0,0,1,7], ["step",240,0,0,2,8],
                ["step",260,0,0,2,8], ["step",410,0,0,2,8],
                ["spawn",200,"physical_adopted",9,1,7,4,3,3,80,{}],
                ["spawn",201,"foreign",10,1,7,4,3,3,81,{}],
                ["draw",95], ["draw",280], ["draw",300]]
        result = self.reduce(rows)["cases"][0]
        self.assertEqual(result["first_completed_step_usec"],140)
        self.assertEqual(result["first_observed_step_upper_bound_usec"],160)
        self.assertEqual(result["physical_gaps"]["maximum_usec"],130)
        self.assertEqual(result["physical_gap_context_both_boundaries"]["maximum_usec"],150)
        self.assertEqual(result["physical_unfinished_suffix_usec"],140)
        self.assertEqual(result["draw_callback_gaps"]["maximum_usec"],185)
        self.assertEqual([p["phase"] for p in result["phases"]],["physical_adopted"])
        self.assertEqual(result["input_physical_application_observed_usec"],50)

    def test_missing_and_dropped_records_are_explicit(self):
        result = self.reduce([["loss",300,100,{"step":8}]])
        self.assertIsNone(result["cases"][0]["first_completed_step_usec"])
        self.assertIsNone(result["cases"][0]["physical_gaps"])
        self.assertIsNone(result["cases"][0]["draw_callback_gaps"])
        self.assertEqual(len(result["recorder_loss_intervals"]),1)
        self.assertFalse(module.complete_recording(result,False))

    def test_incomplete_recorder_cannot_qualify_observed_gameplay(self):
        complete = self.reduce([["step",80,0,0,1,7], ["step",240,0,0,2,8],
                                ["step",260,0,0,2,8],["close",401]])
        self.assertTrue(module.complete_recording(complete,False))
        self.assertFalse(module.complete_recording(complete,True))
        complete["recorder_loss_intervals"] = [["loss",300,200,{"step":1}]]
        self.assertFalse(module.complete_recording(complete,False))
        complete["recorder_loss_intervals"] = []
        complete["recorder_closed"] = False
        self.assertFalse(module.complete_recording(complete,False))

    def test_off_draw_observer_is_distinct_from_exact_physical_recording(self):
        with tempfile.TemporaryDirectory() as temp:
            case = self.case()
            case.update(admission_physical_step=2, final_physical_steps=8,
                        admission_rapier_steps=2, final_rapier_steps=8,
                        admission_native_tick=1, final_native_tick=4, physical_delta_seconds=1/60)
            result = module.reduce(Path(temp), {"cases":[case], "draw_callback_usec":[95,280,300],
                                               "observed_completion_usec":[80,240,410]})["cases"][0]
        self.assertEqual(result["observed_draw_callback_gaps"]["maximum_usec"],185)
        self.assertEqual(result["process_sampled_completion_gaps_upper_bound"]["maximum_usec"],160)
        self.assertIsNone(result["physical_gaps"])
        self.assertIsNone(result["first_completed_step_usec"])
        self.assertIsNone(result["draw_callback_gaps"])
        self.assertEqual(result["post_admission"]["simulated_seconds_per_wall_second"],500)

    def test_following_spawn_tail_keeps_its_own_case_and_prior_context(self):
        first, second = self.case(), self.case()
        second.update(label="next", request_usec=450, request_return_usec=475,
                      admitted_usec=550, end_usec=800, epoch=9)
        rows = [["step",t,0,0,1,8 if t < 450 else 9] for t in (80,200,350,750,850)]
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)
            (path/"segment-0.jsonl").write_text("\n".join(json.dumps(row) for row in rows)+"\n")
            result = module.reduce(path,{"cases":[first,second]})
        self.assertEqual(result["cases"][0]["physical_gaps"]["maximum_usec"],150)
        self.assertEqual(result["cases"][0]["physical_gap_context_both_boundaries"]["maximum_usec"],400)
        self.assertEqual(result["cases"][0]["physical_unfinished_suffix_usec"],50)
        self.assertEqual(result["cases"][1]["physical_gaps"]["maximum_usec"],400)
        self.assertEqual(result["whole_recording_physical_gaps"]["maximum_usec"],400)


if __name__ == "__main__":
    unittest.main()
