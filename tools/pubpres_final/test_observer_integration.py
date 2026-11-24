#!/usr/bin/env python3
"""Pure integration adversaries; these are not graphical or timing evidence."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import observer_support as support
from run_comparison import comparison_plan


class ObserverIntegrationTests(unittest.TestCase):
    def test_new_calibration_has_explicit_same_source_full_two_off_on_on_off(self):
        self.assertEqual(comparison_plan("observer-abba",2), [
            {"role":"C","slots":2,"presentation_observer":value} for value in (False,True,True,False)])
        with self.assertRaises(ValueError): comparison_plan("observer-abba",3)

    def test_disabled_freshness_is_absent_and_cannot_fake_zero_or_an_enabled_sidecar(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder); helper=root/support.PROBE
            helper.parent.mkdir(parents=True);helper.write_bytes(b"synthetic helper")
            receipt=root/"receipt.json"
            data={"source_identity":{"files":{"res://"+support.PROBE:hashlib.sha256(helper.read_bytes()).hexdigest()}},
                  **{phase:{"requested":{support.SELECTOR:"0"}} for phase in ("selectors_before","selectors_after")}}
            def write():receipt.write_text(json.dumps(data))
            write()
            with patch.object(support.observer_bundle,"identity",return_value={"synthetic":True}), \
                    patch.object(support,"validate_policy_observation",return_value={"synthetic":True}), \
                    patch.object(support,"validate_cpu_trace",return_value={"synthetic":True}):
                result=support.validate_observers(receipt,{},root,False)
                self.assertIsNone(result["presentation"])
                self.assertIs(result["presentation_enabled"],False)
                for invalid in (0,1,"0",None):
                    with self.assertRaises(ValueError):support.validate_observers(receipt,{},root,invalid)
                data["selectors_after"]["requested"][support.SELECTOR]="1";write()
                with self.assertRaises(ValueError):support.validate_observers(receipt,{},root,False)
                data["selectors_after"]["requested"][support.SELECTOR]="0";write()
                sidecar=root/"receipt-presentation.json";sidecar.write_text("{}")
                with self.assertRaises(ValueError):support.validate_observers(receipt,{},root,False)
                sidecar.unlink();helper.write_bytes(b"different")
                with self.assertRaises(ValueError):support.validate_observers(receipt,{},root,False)

    def test_calibration_retains_all_pairings_and_does_not_declare_zero_overhead(self):
        arms=[]
        for index,enabled in enumerate((False,True,True,False)):
            arms.append({"index":index,"statistics":{"source":"same-current-source",
                         "windows":{"first_144_steps":{"completed_rapier_steps":144,
                            "rapier_steps_per_second":4+index/10,
                            "physical_gap_ms":{"p50":80,"p95":100,"p99":200,"max":300}}},
                         "physical_gap_counts_above_ms":{"first_144_steps":{"100":5,"250":1,"500":0,"1000":0}}},
                         "observers":{"presentation_enabled":enabled,"cpu":{"synthetic":True},
                            "presentation":{"observer_total_usec":100,"observer_call_ms":{"max":.1}} if enabled else None}})
        result=support.calibration_measurements(arms)
        self.assertEqual(len(result["readings"]),4)
        self.assertEqual(len(result["all_cross_arm_ratios"]),4)
        self.assertEqual(result["overhead_acceptance"],"NO_OWNER_BUDGET_REGISTERED")
        self.assertIsNone(result["readings"][0]["presentation_callback_cost"])
        for label,change in (
            ("drop arm",lambda a:a.pop()),
            ("order",lambda a:a.reverse()),
            ("state",lambda a:a[1]["observers"].update(presentation_enabled=False)),
            ("boolean domain",lambda a:a[1]["observers"].update(presentation_enabled=1)),
            ("source",lambda a:a[2]["statistics"].update(source="another")),
            ("steps",lambda a:a[2]["statistics"]["windows"]["first_144_steps"].update(completed_rapier_steps=143)),
        ):
            with self.subTest(label=label):
                altered=copy.deepcopy(arms);change(altered)
                with self.assertRaises(ValueError):support.calibration_measurements(altered)


if __name__=="__main__":unittest.main()
