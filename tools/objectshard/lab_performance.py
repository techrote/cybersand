"""Apply registered standalone Lab budgets to complete actual-Godot observations."""
from __future__ import annotations

import math


def check(report: dict, budget: dict, *, rendered: bool) -> dict:
    failures: list[str] = []
    checks = 0

    def maximum(label: str, actual: object, limit: float) -> None:
        nonlocal checks
        checks += 1
        if type(actual) not in (int, float) or not math.isfinite(actual) or actual < 0 or actual > limit:
            failures.append(f"{label}: observed {actual!r}, maximum {limit}")

    if budget.get("schema") != "objectshard-lab-budgets-v1":
        raise ValueError("Unknown Lab budget contract")
    if report.get("schema") != "objectshard-lab-profile-v1" or type(report.get("failures")) is not int or report["failures"] != 0:
        failures.append("Incomplete or unsuccessful actual-Godot profiling report")
    if report.get("rendered") is not rendered:
        failures.append("Rendered/headless measurement scope differs from requested qualification")
    cases = report.get("cases", [])
    names = [case.get("name") for case in cases]
    if len(names) != len(set(names)) or set(names) != set(budget["required_workloads"]):
        failures.append("Missing, repeated or unexpected workload inventory")
    limits = budget["limits"]
    for case in cases:
        name = case.get("name", "unknown")
        if case.get("failed") is not False:
            failures.append(f"{name}: coordinator/physics scenario did not complete")
        samples = case.get("profile_samples", [])
        frame = case.get("timings", {}).get("frame_usec", {})
        if len(samples) < budget["minimum_samples_per_workload"] or frame.get("samples") != len(samples):
            failures.append(f"{name}: incomplete sample inventory")
        # Verify reported statistics against the retained complete sample stream.
        # No sparse maximum or failed frame can be removed while preserving a pass.
        for metric, prefix in (("frame_usec", "frame"), ("present_interval_usec", "rendered_present_interval")):
            if metric != "frame_usec" and not rendered:
                continue
            series = [sample[metric] for sample in samples if metric in sample]
            if not series or any(type(value) not in (int, float) or not math.isfinite(value) or value < 0 for value in series):
                failures.append(f"{name}.{metric}: missing or invalid elapsed samples")
                continue
            if len(series) != len(samples) - (1 if metric == "present_interval_usec" else 0):
                failures.append(f"{name}.{metric}: omitted elapsed samples")
            series.sort()
            for label, fraction in (("p95", .95), ("p99", .99), ("max", 1.0)):
                value = series[math.ceil(len(series) * fraction) - 1]
                declared = case.get("timings", {}).get(metric, {}).get(label)
                if declared != value:
                    failures.append(f"{name}.{metric}.{label}: summary differs from retained samples")
                maximum(f"{name}.{metric}.{label}", value, limits[f"{prefix}_{label}_usec"])
        maximum(f"{name}.promotion_pause", case.get("promotion_max_usec"), limits["promotion_pause_max_usec"])
        physics = case.get("physics_metrics", {})
        maximum(f"{name}.geometry_install", physics.get("geometry_install_max_usec"), limits["geometry_install_max_usec"])
        native = case.get("native_metrics", {})
        maximum(f"{name}.geometry_age", native.get("maximum_geometry_age"), limits["geometry_age_max_ticks"])
        wait = native.get("maximum_geometry_wait_ns")
        maximum(f"{name}.geometry_wait", wait / 1000 if type(wait) in (int, float) else None, limits["geometry_wait_max_usec"])
    return {"status": "passed" if not failures else "failed", "limits_checked": checks, "failures": failures,
            "scope": budget["scope"], "physical_owner_acceptance": "unrecorded"}
