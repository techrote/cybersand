#!/usr/bin/env python3
"""Prospective v3 transport controls; old v2 registration stays byte-frozen."""
import copy
import hashlib
import json
from pathlib import Path
import unittest

from run_campaign import measurement_protocol, select_cases
from results import reduce_receipt as reduce_v2
from results_same_frame import reduce_receipt as reduce_v3

ROOT = Path(__file__).resolve().parent


class ProtocolTests(unittest.TestCase):
    def setUp(self):
        self.old = json.loads((ROOT / "campaign-development-01-v2.json").read_text())
        self.new = json.loads((ROOT / "campaign.json").read_text())

    def test_legacy_definition_and_reader_remain_frozen(self):
        self.assertEqual(hashlib.sha256((ROOT / "campaign-development-01-v2.json").read_bytes()).hexdigest(),
                         "d44ba75d49c708de409633659caadeb9f284c69623c649296342ec5c89ef1286")
        self.assertEqual(measurement_protocol(self.old), ("v2", "tests/pubpres_playability_gameplay.gd", reduce_v2))
        self.assertEqual(select_cases(self.old, [], False, "render_thread_calibration")[1]["order"],
                         ["safe", "separate", "separate", "safe"])

    def test_old_protocol_cannot_advertise_new_treatment(self):
        for value in (False, True, "0", 0):
            with self.subTest(value=value):
                c = copy.deepcopy(self.old)
                c["arms"]["C"]["same_frame_continuation"] = value
                with self.assertRaises(ValueError): measurement_protocol(c)

    def test_new_protocol_is_explicit_and_source_bound(self):
        self.assertEqual(measurement_protocol(self.new), ("v3", "tests/pubpres_same_frame_gameplay.gd", reduce_v3))
        self.assertTrue(self.new["arms"]["C"]["same_frame_continuation"])
        for change in ("schema", "observer", "receipt", "hash", "extra_overlay", "integer", "rendezvous", "historical"):
            with self.subTest(change=change):
                c = copy.deepcopy(self.new)
                if change == "schema": c["schema"] = "unknown"
                if change == "observer": c["observer_entrypoint"] = "tests/pubpres_playability_gameplay.gd"
                if change == "receipt": c["measurement"]["receipt_schema"] = "pubpres-playability-gameplay-v2"
                if change == "hash": c["overlay_sha256"].pop(c["observer_entrypoint"])
                if change == "extra_overlay": c["overlay_sha256"]["tests/pubpres_playability_gameplay.gd"] = "a" * 64
                if change == "integer": c["arms"]["C"]["same_frame_continuation"] = 1
                if change == "rendezvous": c["arms"]["C"]["rendezvous"] = "16"
                if change == "historical": c["arms"]["M"]["same_frame_continuation"] = True
                with self.assertRaises(ValueError): measurement_protocol(c)

    def test_paired_treatment_and_retired_engine_control(self):
        cases, policy = select_cases(self.new, [], False, "same_frame_calibration")
        self.assertEqual(policy["order"], [False, True, True, False])
        self.assertEqual(len(cases), 6)
        with self.assertRaises(ValueError): select_cases(self.new, [], False, "render_thread_calibration")
        changed = copy.deepcopy(self.new)
        changed["same_frame_calibration"]["order"] = [False, False, True, True]
        with self.assertRaises(ValueError): select_cases(changed, [], False, "same_frame_calibration")


if __name__ == "__main__": unittest.main()
