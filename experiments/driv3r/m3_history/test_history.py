"""Offline-only M3 history tests. No native painting or inference without opt-in CI."""
from __future__ import annotations

import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from experiments.driv3r.native import NativeError, NativeSession
from experiments.driv3r.m3_history.native import HistorySession, HISTORY_HARNESS
from experiments.driv3r.m3_history.qualify import (
    SOURCE_SCENARIO, _op, _record_reversal, digest, _record_action,
)
from experiments.driv3r.d_common.v1.verify import SCHEMA, validate_bundle
from experiments.driv3r.m3_native.qualify import M1_SCHEMA_SHA
import hashlib


class HistoryPilotOfflineTests(unittest.TestCase):
    def test_original_harness_default_still_frozen(self):
        n=NativeSession(".","/not-running","/not-running/out","a"*40)
        self.assertEqual(n.harness_script,"res://tests/run_driv3r_stage_a.gd")

    def test_exact_m3_harness_is_host_allowlisted(self):
        n=HistorySession(".","/not-running","/not-running/out","a"*40)
        self.assertEqual(n.harness_script,HISTORY_HARNESS)
        with self.assertRaises(NativeError):
            NativeSession(".","/not-running","/not-running/out","a"*40,
                          harness_script="res://scripts/evil.gd")

    def test_m1_schema_bytes_remain_frozen(self):
        self.assertEqual(hashlib.sha256(SCHEMA.read_bytes()).hexdigest(),M1_SCHEMA_SHA)

    def test_boundaries_forbid_36_decision_and_model_campaigns(self):
        self.assertEqual(SOURCE_SCENARIO["phase2"]["decision_budget"],4)
        self.assertEqual(len(SOURCE_SCENARIO["phase2"]["points"]),4)
        self.assertIsNone(SOURCE_SCENARIO["model"])
        self.assertFalse(SOURCE_SCENARIO["formal_A1_A2_A3"])
        self.assertEqual(SOURCE_SCENARIO["max_total_forward_material_operations_across_all_sessions"],8)

    def test_four_short_steps_are_cardinal_and_unique(self):
        steps=[[12,24],*SOURCE_SCENARIO["phase2"]["points"]]
        self.assertEqual(len(set(map(tuple,steps))),5)
        self.assertTrue(all(abs(a[0]-b[0])+abs(a[1]-b[1])==1 for a,b in zip(steps,steps[1:])))
        self.assertTrue(all(0<=x<96 and 0<=y<96 for x,y in steps))

    def test_native_undo_and_logical_branch_not_conflated(self):
        old={"world_id":"source","generation":4,"revision":8,"tick":0,
             "material_sha256":"0"*64,"world_material_sha256":"1"*64}
        changed={**old,"revision":9,"material_sha256":"f"*64,
                 "world_material_sha256":"f"*64}
        s=_record_reversal("fixture",3,"BRANCH","RELOCATE_TO_BRANCH",
                          "action-test","obs-anchor",old,old,[12,25],[12,24])
        self.assertTrue(s["preserve_material_edits"])
        self.assertEqual(s["actual_material_cells_changed"],0)
        self.assertIsNone(s["native_undo_receipt_artifact"])
        undo_blob={"path":"receipts/test.json","sha256":"b"*64,"bytes":100,"format":"json"}
        undo=_record_reversal("fixture",4,"UNDO","UNDO_MATERIAL_EDIT",
                             "action-test","obs-anchor",old,changed,
                             [12,24],[12,24],1,undo_blob)
        self.assertFalse(undo["preserve_material_edits"])
        self.assertEqual(undo["actual_material_cells_changed"],1)
        self.assertIsNotNone(undo["native_undo_receipt_ref"])

    def test_host_selected_one_cell_material_operation(self):
        self.assertEqual(_op([12,25]),{"shape":"rectangle","x0":12,"y0":25,
                                      "x1":12,"y1":25,"material":58})
        self.assertNotEqual(digest([_op([12,25])]),digest([_op([13,25])]))

    def test_invalid_m3_method_does_not_send_rpc(self):
        with tempfile.TemporaryDirectory() as d:
            h=HistorySession(".","/not-running",Path(d)/"native","a"*40)
            with self.assertRaises(NativeError):
                h._command("new_native_op",{})

    def test_missing_fresh_source_rejected_before_native_rpc(self):
        with tempfile.TemporaryDirectory() as d:
            h=HistorySession(".","/not-running",Path(d)/"native","a"*40)
            with self.assertRaises(NativeError):
                h.undo()

    def test_stale_source_passed_as_explicit_native_precondition(self):
        with tempfile.TemporaryDirectory() as d:
            h=HistorySession(".","/not-running",Path(d)/"native","a"*40)
            stale={"generation":7,"revision":2,"tick":0}
            with patch.object(h,"_request",return_value={"status":"refused",
                     "receipt":{"actual_changed_cells":0}}) as request:
                result=h.undo(precondition=stale)
                self.assertEqual(result["status"],"refused")
                fields=request.call_args.args[1]
                self.assertEqual([fields[f"expected_{k}"] for k in ("generation","revision","tick")],[7,2,0])

    def test_positive_logical_ack_requires_zero_material_changes(self):
        with tempfile.TemporaryDirectory() as d:
            h=HistorySession(".","/not-running",Path(d)/"native","a"*40)
            h.latest_observation={"generation":4,"revision":1,"tick":0}
            with patch.object(h,"_request",return_value={
                    "status":"completed","receipt":{"actual_changed_cells":1,
                      "readback_matches":True}}):
                with self.assertRaises(NativeError):
                    h.relocate_branch("anchor",[13,25])

    def test_actual_undo_requires_valid_PAINT_receipt(self):
        with tempfile.TemporaryDirectory() as d:
            h=HistorySession(".","/not-running",Path(d)/"native","a"*40)
            h.latest_observation={"generation":4,"revision":1,"tick":0}
            with patch.object(h,"_request",return_value={
                    "status":"completed","receipt":{"actual_changed_cells":1,
                      "readback_matches":True},
                    "history_receipt":{"action":"undo","status":"completed",
                      "changed":1,"recorded":False}}):
                with self.assertRaises(NativeError):
                    h.undo()


if __name__=="__main__":
    unittest.main()
