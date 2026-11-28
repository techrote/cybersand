#!/usr/bin/env python3
"""Reject stale pixels, aliased two-slot resources and false render owners."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pubpres_final"))
import test_qualification_oracles as common
import two_slot_oracle


class TwoSlotOracleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        common.QualificationOracles.setUpClass()
        cls.fixture = common.QualificationOracles()
        path = cls.fixture.project / two_slot_oracle.FIXTURE[6:]
        path.write_text("synthetic two-slot oracle source\n")

    @classmethod
    def tearDownClass(cls):
        common.QualificationOracles.tearDownClass()

    def receipt(self):
        data = self.fixture.transition()
        data["schema"] = "pubpres-source-transition-history-v1"
        data["context"] = self.fixture.context(two_slot_oracle.FIXTURE)
        data["history"].update(render_thread_inline=True, publisher_sha256=data["publisher_sha256"])
        for row in data["admissions"]:
            first, second = (100, 101) if row["sequence"] % 2 == 0 else (101, 100)
            row["material"].update(full_image_slots_requested="2", full_image_slots=2,
                                   two_slot_current_rid=first, two_slot_previous_rid=second)
        return data

    def validate(self, data):
        path = self.fixture.project / "two-slot-receipt.json"
        path.write_text(json.dumps(data))
        return two_slot_oracle.validate(path, self.fixture.project, source=common.SOURCE,
            driver=common.DRIVER, engine_sha256=common.ENGINE, separate=False)

    def test_complete_registered_control(self):
        self.assertEqual(self.validate(self.receipt())["independent_validation"]["slot_admissions_checked"], 180)

    def test_observed_owner_and_pair_and_bytes_cannot_be_relabelled(self):
        faults = [
            ("false_owner", lambda data: data["history"].update(render_thread_inline=False)),
            ("stale_current", lambda data: data["entry_history"][0].update(current_sha256=data["entry_history"][0]["previous_sha256"])),
            ("aliased_pair", lambda data: data["admissions"][0]["material"].update(two_slot_previous_rid=100)),
            ("recreated_pair", lambda data: data["admissions"][-1]["material"].update(two_slot_current_rid=999)),
            ("missed_rotation", lambda data: data["admissions"][1]["material"].update(two_slot_current_rid=100, two_slot_previous_rid=101)),
            ("unregistered_slots", lambda data: data["admissions"][0]["material"].update(full_image_slots=3)),
            ("engine_substitution", lambda data: data["context"].update(engine_sha256="0" * 64)),
        ]
        for name, change in faults:
            with self.subTest(name=name):
                data = copy.deepcopy(self.receipt())
                change(data)
                with self.assertRaises((ValueError, KeyError, TypeError)):
                    self.validate(data)


if __name__ == "__main__":
    unittest.main()
