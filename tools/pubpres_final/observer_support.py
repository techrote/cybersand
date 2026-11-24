#!/usr/bin/env python3
"""Explicit supplementary evidence; the complete physical oracle runs first."""
from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = ROOT / "tools/pubpres_final_observers"
sys.path.insert(0, str(DIRECTORY))
import bundle as observer_bundle
from execute_with_resources import execute_with_resources as _execute_with_resources
from presentation_metrics import PROBE, validate_cpu_trace
from results import digest, need
from material_steps_status import SELECTOR as MATERIAL_STEPS_SELECTOR, validate_policy_observation

SELECTOR = "CYBERSAND_DIAG_PRESENTATION_OBSERVER"


def execute_with_resources(engine, args, folder, source_sha, settings, timeout, wrapper=None):
    # Existing ordinary runners get an explicit control. The prospective count
    # runner supplies its own registered0/2. The complete owned-process/CPU
    # executor remains unchanged and independently SHA-pinned.
    explicit = dict(settings)
    explicit.setdefault(MATERIAL_STEPS_SELECTOR, "0")
    need(explicit[MATERIAL_STEPS_SELECTOR] in ("0", "2"), "Unregistered material-step process selector")
    return _execute_with_resources(engine, args, folder, source_sha, explicit, timeout, wrapper)


def validate_observers(receipt: Path, process: dict, project: Path, enabled: bool,
                       *, expected_material_steps: int = 0) -> dict:
    need(type(enabled) is bool, "Presentation observer state must be explicitly enabled or disabled")
    data = json.loads(receipt.read_bytes())
    material_steps = validate_policy_observation(data, project, expected_material_steps)
    expected = "1" if enabled else "0"
    need(all(data[phase]["requested"].get(SELECTOR) == expected
             for phase in ("selectors_before", "selectors_after")),
         "Presentation observer changed state or differs from the registered arm")
    need(data["source_identity"]["files"].get("res://" + PROBE) == digest(project / PROBE),
         "Enabled and disabled observer arms must bind the same actual helper source")
    if enabled:
        result = observer_bundle.validate(receipt, process, project)
        need(result["presentation"]["all_visible_first_parts_verified"] is True,
             "Registered ordinary workload has unavailable submitted collider/part geometry")
    else:
        need(not receipt.with_name(receipt.stem + "-presentation.json").exists(),
             "Disabled presentation observer unexpectedly emitted a sidecar")
        result = {"bundle": observer_bundle.identity(), "presentation": None,
                  "cpu": validate_cpu_trace(receipt.parent / "process-cpu.json", process, data)}
    return {"presentation_enabled": enabled, "material_steps_policy": material_steps, **result,
            "scope": "Additional submitted-pose and whole-process CPU evidence. Disabled pose/freshness is unavailable, never zero; actual displayed pixels and input-device latency remain unobserved."}


def calibration_measurements(arms: list[dict]) -> dict:
    """Describe every off/on outcome without inventing an overhead pass budget."""
    need(len(arms) == 4 and [arm["index"] for arm in arms] == list(range(4)),
         "Observer calibration requires the full off/on/on/off order")
    need(all(type(arm["observers"]["presentation_enabled"]) is bool for arm in arms)
         and [arm["observers"]["presentation_enabled"] for arm in arms] == [False, True, True, False],
         "Observer calibration state order differs")
    need(len({arm["statistics"]["source"] for arm in arms}) == 1,
         "Observer calibration mixed application sources")
    off, on = [arms[0], arms[3]], [arms[1], arms[2]]
    readings = []
    for arm in arms:
        window = arm["statistics"]["windows"]["first_144_steps"]
        need(window["completed_rapier_steps"] == 144, "Calibration physical window is incomplete")
        readings.append({"index": arm["index"], "presentation_enabled": arm["observers"]["presentation_enabled"],
                         "steps_per_second": window["rapier_steps_per_second"],
                         "physical_gap_ms": window["physical_gap_ms"],
                         "gap_counts_above_ms": arm["statistics"]["physical_gap_counts_above_ms"]["first_144_steps"],
                         "cpu": arm["observers"]["cpu"],
                         "presentation_callback_cost": None if arm["observers"]["presentation"] is None else {
                             key: arm["observers"]["presentation"][key]
                             for key in ("observer_total_usec", "observer_call_ms")}})
    ratios = []
    for observed in on:
        for control in off:
            a = observed["statistics"]["windows"]["first_144_steps"]
            b = control["statistics"]["windows"]["first_144_steps"]
            ratios.append({"on_index": observed["index"], "off_index": control["index"],
                           "physical_rate_ratio_on_over_off": a["rapier_steps_per_second"] / b["rapier_steps_per_second"],
                           "gap_ratio_on_over_off": {key: a["physical_gap_ms"][key] / b["physical_gap_ms"][key]
                                if b["physical_gap_ms"][key] > 0 else None for key in ("p50", "p95", "p99", "max")}})
    return {"schema": "pubpres-final-observer-calibration-analysis-v1", "readings": readings,
            "all_cross_arm_ratios": ratios, "overhead_acceptance": "NO_OWNER_BUDGET_REGISTERED",
            "scope": "Same-source/runtime/policy off/on/on/off calibration with the original full V3 observer and identical external CPU sampling in every arm. All timings retained. This bounds only the observed cohort; it does not establish zero overhead, inherit older observer calibration, or qualify a physical display."}
