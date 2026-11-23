#!/usr/bin/env python3
"""Evidence-only selector registration regression for PUBPRES #757.

Runs without Godot, native DLLs, or CI billing. This guards the *metadata*
contract that the original C focused runner enforces; it cannot qualify GPU,
physics performance, or production source. The executable Windows ABBA from
45104078108 is separately retained as a failed-registration raw diagnostic.
"""
import importlib.util
import sys
import types
import unittest
from pathlib import Path


WRAPPER = Path(__file__).with_name("pubpres757_physics_abba.py")
ORDER = ("early", "combined", "combined", "early")


def make_subject():
    """Load the untouched wrapper with an isolated original-runner mock."""
    original = types.ModuleType("run_focus")
    original.seen = []

    def original_selectors(arm, nonce, retirement_source="stage"):
        return {
            "CYBERSAND_DIAG_PHYSICS_PUBLICATION": "early",
            "CYBERSAND_MATERIAL_PUBLICATION": arm["material"],
            "CYBERSAND_DIAG_PRESENTATION": "coherent",
        }

    def original_validate(data, case, campaign, source_commit, nonce,
                          driver, retirement_source="stage"):
        original.seen.append((case, source_commit, nonce, driver, retirement_source))

    def need(ok, message):
        if not ok:
            raise ValueError(message)

    original.selectors = original_selectors
    original.validate_requested_capture = original_validate
    original.need = need
    original.planned_arms = None
    prior = sys.modules.get("run_focus")
    sys.modules["run_focus"] = original
    try:
        spec = importlib.util.spec_from_file_location("pubpres757_wrapper_subject", WRAPPER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    finally:
        if prior is None:
            del sys.modules["run_focus"]
        else:
            sys.modules["run_focus"] = prior
    return module, original


class TestPhysicsEvidenceABBA(unittest.TestCase):
    def setUp(self):
        self.wrapper, self.original = make_subject()

    def test_planned_arm_expected_physics_matches_live_selector(self):
        arms = self.wrapper.planned_arms("renderer-abba")
        self.assertEqual(len(arms), 4)
        self.assertEqual(tuple(arm["physics"] for arm in arms), ORDER)
        for index, arm in enumerate(arms):
            with self.subTest(arm=index):
                self.assertEqual(arm["physics_mode"], ORDER[index])
                self.assertEqual(arm["material"], "full")
                self.assertFalse(arm["same_frame_continuation"])
                # The actual original focus runner constructs this merged arm
                # using campaign['arms']['C'] then the detached treatment.
                merged = {"physics": "early", "presentation": "coherent", **arm}
                selected = self.wrapper.selectors(merged, "selector-guard", "stage")
                # results.py's registered gate compares these two values:
                self.assertEqual(
                    selected["CYBERSAND_DIAG_PHYSICS_PUBLICATION"],
                    merged["physics"],
                )
                self.assertEqual(selected["CYBERSAND_MATERIAL_PUBLICATION"], "full")

    def test_invalid_envelope_is_rejected(self):
        with self.assertRaises(ValueError):
            self.wrapper.planned_arms("baseline")
        arm = self.wrapper.planned_arms("renderer-abba")[0]
        with self.assertRaises(ValueError):
            self.wrapper.selectors({**arm, "material": "blit"}, "nonce")
        with self.assertRaises(ValueError):
            self.wrapper.selectors(arm, "nonce", "target")
        with self.assertRaises(ValueError):
            self.wrapper.selectors({**arm, "physics_mode": "unknown"}, "nonce")

    def test_observation_must_report_same_requested_and_effective_mode(self):
        for setting in ("early", "combined"):
            row = {
                "requested": {"CYBERSAND_DIAG_PHYSICS_PUBLICATION": setting},
                "physics": setting,
                "material": {"backend": "full"},
                "presentation": "coherent",
                "same_frame_continuation": {"mode": "off"},
            }
            data = {"selectors_before": row, "selectors_after": row}
            self.wrapper.validate_requested_capture(
                data, "wave_512_follow", {}, self.wrapper.SOURCE_SHA,
                "nonce", "opengl3_angle", "stage",
            )
            with self.assertRaises(ValueError):
                self.wrapper.validate_requested_capture(
                    {"selectors_before": row, "selectors_after": {**row, "physics": "early" if setting == "combined" else "combined"}},
                    "wave_512_follow", {}, self.wrapper.SOURCE_SHA,
                    "nonce", "opengl3_angle", "stage",
                )


if __name__ == "__main__":
    unittest.main()
