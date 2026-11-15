"""Offline shape-only aggregator tests; no native/model conclusions."""
import copy
import json
import unittest
import tempfile
from pathlib import Path
from experiments.driv3r.wormbrain.aggregate import compare, read_original_artifact, M1_SCHEMA_SHA


def fixture(mode):
    return {
        "mode":mode, "source_sha":"a"*40, "status":"PASS",
        "initial_world_sha256":"b"*64,
        "initial_host_legal_catalog_sha256":"c"*64,
        "final_world_sha256":"d"*64,
        "model_decisions":2,"native_painted_cells":2,
        "brush_up_recoveries":0,"termination":"budget_exhausted",
        "independent_native_replay":True,
        "source_fenced_m1_valid":True,
        "original_model_process_reaped":True,
        "material_derived_gallery":["gallery/native-material.png"],
        "elapsed_seconds":1.0,
    }


def trace(choice="MOVE_E"):
    return [{"source_world_sha256":"b"*64,"cursor_before":[12,24],
             "host_legal_sha256":"c"*64,"candidate_ids":["MOVE_E","STOP"],
             "choice":choice,"cursor_after":[13,24] if choice!="STOP" else [12,24],
             "world_after_sha256":"d"*64 if choice!="STOP" else "b"*64}]


class WormAggregateTests(unittest.TestCase):
    def test_exact_source_initial_world_and_catalog_required(self):
        reports={m:fixture(m) for m in ("free","soft")}
        traces={m:trace() for m in reports}
        self.assertEqual(compare(reports,traces)["status"],
                         "NATIVE_WORM_PAIR_SOURCE_VERIFIED")
        for field in ("source_sha","initial_world_sha256",
                      "initial_host_legal_catalog_sha256"):
            altered=copy.deepcopy(reports)
            altered["soft"][field]="e"*len(altered["soft"][field])
            with self.subTest(field=field),self.assertRaises(ValueError):
                compare(altered,traces)

    def test_early_stop_kept_as_data_not_padded_or_replayed_as_ink(self):
        reports={m:fixture(m) for m in ("free","soft")}
        reports["soft"]["status"]="VALID_NO_INK"
        reports["soft"]["native_painted_cells"]=0
        reports["soft"]["termination"]="stop"
        out=compare(reports,{"free":trace(),"soft":trace("STOP")})
        self.assertEqual(out["first_choice_divergence_on_matched_world"],0)
        self.assertEqual(out["first_consequential_native_divergence"],0)
        self.assertEqual(out["original_episodes"]["soft"]["actual_native_ink_cells"],0)

    def test_original_actions_artifact_nested_execution_layout(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            for mode in ("free","soft"):
                folder=root/mode/"execution"
                (folder/"execution").mkdir(parents=True)
                report=fixture(mode)
                report.update({"original_model_pid_count":1,
                               "native_painted_cells":1,
                               "model_decisions":1})
                original=trace()
                original[0]["index"]=0
                original[0]["original_model_artifact"]="model/turn-00.json"
                (folder/"execution"/"summary.json").write_text(json.dumps(report))
                (folder/"original-decisions.json").write_text(json.dumps(original))
                (folder/"native-replay.json").write_text(json.dumps({
                    "final_world_sha256":report["final_world_sha256"],
                    "native_material_actions_replayed":1,
                    "actual_independent_native_replay":True}))
                (folder/"bundle-validation.json").write_text(json.dumps({
                    "schema_sha256":M1_SCHEMA_SHA,
                    "evidence_bytes_verified":True}))
            parsed={mode:read_original_artifact(root,mode,expected_source="a"*40)
                    for mode in ("free","soft")}
            self.assertEqual(compare({m:p[0] for m,p in parsed.items()},
                                     {m:p[1] for m,p in parsed.items()})["status"],
                             "NATIVE_WORM_PAIR_SOURCE_VERIFIED")
            with self.assertRaises(ValueError):
                read_original_artifact(root,"free",expected_source="b"*40)
            (root/"soft"/"execution"/"native-replay.json").unlink()
            with self.assertRaises(ValueError):
                read_original_artifact(root,"soft",expected_source="a"*40)

    def test_missing_original_native_arm_is_not_promoted(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertIsNone(read_original_artifact(Path(tmp),"free"))
            self.assertEqual(compare({}, {})["status"],"INCOMPLETE")

    def test_incomplete_does_not_claim_a_native_pair(self):
        self.assertEqual(compare({"free":fixture("free")},{"free":trace()})["status"],
                         "INCOMPLETE")

    def test_unverified_native_or_model_shutdown_is_refused(self):
        reports={m:fixture(m) for m in ("free","soft")}
        for key in ("independent_native_replay","source_fenced_m1_valid",
                    "original_model_process_reaped"):
            bad=copy.deepcopy(reports)
            bad["soft"][key]=False
            with self.subTest(key=key),self.assertRaises(ValueError):
                compare(bad,{m:trace() for m in reports})


if __name__=="__main__":
    unittest.main()
