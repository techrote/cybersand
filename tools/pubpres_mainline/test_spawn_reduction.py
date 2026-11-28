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
        self.assertEqual(result["physical_gaps"]["maximum_usec"],150)
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


if __name__ == "__main__":
    unittest.main()
