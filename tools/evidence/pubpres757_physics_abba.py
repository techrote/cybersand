#!/usr/bin/env python3
"""Detached PUBPRES-757 Wave512 physics-publication selector experiment.

This wrapper does not edit or patch tested Godot or native application source.
It binds the already source-verified frozen PUBPRES focused runner to an explicit
ABBA early/combined/combined/early sequence with Full image publication fixed.
The underlying runner's legacy "renderer-abba" enum is only the four-arm
execution container; the actual treatment is recorded independently in arm.json.
No physical or GPU completion result may be inferred from the wrapper itself.
"""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path.cwd()
sys.path.insert(0, str(ROOT / "tools" / "pubpres003"))
import run_focus as focus  # noqa: E402

SOURCE_SHA = "c90dbc46e1f57f28e06b1f4205b83467335ff657"
ORDER = ("early", "combined", "combined", "early")
ORIGINAL_SELECTORS = focus.selectors
ORIGINAL_VALIDATOR = focus.validate_requested_capture


def planned_arms(mode):
    if mode != "renderer-abba":
        raise ValueError("Diagnostic requires exactly the four-arm runner container")
    return [
        {"same_frame_continuation": False, "wave_column_probe": False,
         "causal": False, "material": "full", "physics": setting, "physics_mode": setting}
        for setting in ORDER
    ]


def selectors(arm, nonce, retirement_source="stage"):
    if retirement_source != "stage" or arm["material"] != "full":
        raise ValueError("Physics isolation requires unchanged Full material path")
    selected = arm.get("physics_mode")
    if selected not in ORDER:
        raise ValueError("Unregistered physics selector")
    result = ORIGINAL_SELECTORS(arm, nonce, retirement_source)
    result["CYBERSAND_DIAG_PHYSICS_PUBLICATION"] = selected
    return result


def validate_requested_capture(data, case, campaign, source_commit, nonce,
                               driver, retirement_source="stage"):
    ORIGINAL_VALIDATOR(data, case, campaign, source_commit, nonce, driver,
                       retirement_source)
    focus.need(source_commit == SOURCE_SHA, "Tested application source differs from frozen candidate")
    before, after = data["selectors_before"], data["selectors_after"]
    selected = before["requested"]["CYBERSAND_DIAG_PHYSICS_PUBLICATION"]
    focus.need(selected in ORDER and
               after["requested"]["CYBERSAND_DIAG_PHYSICS_PUBLICATION"] == selected,
               "Requested early/combined physics publication changed")
    focus.need(before["physics"] == after["physics"] == selected,
               "Active early/combined publication selector differs")
    focus.need(before["material"]["backend"] == after["material"]["backend"] == "full",
               "Actual Full material publication was not preserved")
    focus.need(before["presentation"] == after["presentation"] == "coherent",
               "Presentation changed during physics-only experiment")
    focus.need(before["same_frame_continuation"]["mode"] == "off" and
               after["same_frame_continuation"]["mode"] == "off",
               "Continuation must remain disabled")


def main():
    focus.planned_arms = planned_arms
    focus.selectors = selectors
    focus.validate_requested_capture = validate_requested_capture
    print(json.dumps({
        "schema": "pubpres757-physics-publication-only-abba-v1",
        "tested_source": SOURCE_SHA,
        "treatment": list(ORDER),
        "fixed_material": "full",
        "fixed_presentation": "coherent",
        "fixed_render_owner": "safe",
        "same_frame_continuation": False,
        "source_policy": "Original committed application and focused runner; detached wrapper only",
        "physical_acceptance": "HOLD",
        "wrapper_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    }), flush=True)
    return focus.main()


if __name__ == "__main__":
    sys.exit(main())
