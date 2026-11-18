#!/usr/bin/env python3
"""Source-matched WAVE-WATERWALL-001 runtime publication on its own Draft branch.

The Wave Flow publisher profile (PR #631) is reused unchanged: the same source,
input-ledger, target-OS, LFS and four-file publication guards, and the same
Wave/Workbench/Rapier cases. This profile binds the branch, request and
evidence record of the exposed-face spill lane and adds its Workbench spill
and native/owner exception-containment regressions on both desktop platforms.
An explicit versioned request arms builds; this helper never pushes or merges.
"""
import json
import re

import wave_mt_runtime_publication as base

engine = base.engine
_wave_markers = dict(engine.CASE_MARKERS)
_previous_exact = set(engine.BUILD_EXACT)
engine.BRANCH = "claude/wave-waterwall-001"
engine.WORKFLOW = ".github/workflows/wave-waterwall-runtime-publication.yml"
engine.REQUEST = "tools/ci/wave_waterwall_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-17-wave-waterwall-001.md"
engine.REQUEST_VALUE = {
    "schema": "wave-waterwall-runtime-publish-request-v1",
    "family": "experimental-wave-flow-v1-spill",
    "variant": "opt-in-default-off",
    "scope": "linux-windows-native-wave-spill-workbench",
    "intent": "publish-source-matched-runtimes",
}
engine.CASE_MARKERS = _wave_markers | {
    "test_workbench_wave_spill": r"(?m)^WORKBENCH_WAVE_SPILL (.+)$",
    "test_failed_world_status_survives": r"(?m)^FAILED_WORLD_STATUS (.+)$",
    "test_workbench_failure_containment": r"(?m)^WORKBENCH_FAILURE_CONTAINMENT (.+)$",
}
engine.EXECUTION_SCOPE = (
    base.engine.EXECUTION_SCOPE
    + " WAVE-WATERWALL-001: native admission, refusal atomicity, exact conservation and"
    " worker parity of Waterwall spill with ballistic release, and its ordinary"
    " Workbench Water Lab apply/compare lifecycle; native exception containment,"
    " first-error retention, numeric boundary refusals, failed observation/mutation"
    " contracts, pre/late-publication quarantine and actual Workbench owner recovery."
    " Native Wave body-boundary controls additionally cover prescribed body crossings,"
    " overlap relocation, ballistic capacity, region changes and worker parity."
)
engine.BUILD_EXACT = (_previous_exact - {
    ".github/workflows/wave-mt-runtime-publication.yml",
    "tools/ci/wave_mt_publish_request.json",
    "docs/audits/2026-11-16-wave-workbench-631-finisher.md",
}) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "docs/audits/2026-11-16-wave-workbench-631-finisher.md",
    "tools/ci/wave_waterwall_runtime_publication.py",
    "tools/ci/test_wave_waterwall_runtime_publication.py",
    "native/bench/wave_waterwall.cpp",
}
SPILL_SECTIONS = {"native_admission", "native_conservation", "lab_controls", "workbench_apply"}
FAILED_WORLD_SECTIONS = {
    "native_exception", "capacity_failure", "failed_observation", "failed_mutation",
    "first_error", "reset_recovery", "healthy_refusals", "numeric_boundaries",
}
WORKBENCH_FAILURE_SECTIONS = {
    "prepublication_fault", "late_publication_fault", "running_owner_failure", "restore_recovery",
}
_verify_wave = base.verify_case_results


def verify_spill_summary(output: str) -> None:
    summaries = re.findall(engine.CASE_MARKERS["test_workbench_wave_spill"], output)
    engine.require(len(summaries) == 1, "Missing unique Workbench Waterwall spill summary")
    try:
        result = json.loads(summaries[0])
    except (ValueError, TypeError) as error:
        raise RuntimeError("Malformed Workbench Waterwall spill summary") from error
    engine.require(isinstance(result, dict) and type(result.get("checks")) is int and result["checks"] > 0
                   and result.get("failures") == [],
                   "Workbench Waterwall spill did not pass")
    sections = result.get("sections")
    engine.require(isinstance(sections, dict) and set(sections) == SPILL_SECTIONS
                   and all(value is True for value in sections.values()),
                   "Incomplete Workbench Waterwall spill coverage")


def verify_case_results(directory, report: dict) -> None:
    _verify_wave(directory, report)
    verify_spill_summary((directory / "test_workbench_wave_spill.log").read_text(encoding="utf-8"))
    verify_failed_world_summary((directory / "test_failed_world_status_survives.log").read_text(encoding="utf-8"))
    verify_workbench_failure_summary((directory / "test_workbench_failure_containment.log").read_text(encoding="utf-8"))


def _completed_summary(output: str, case: str, sections: set[str], minimum_checks: int) -> dict:
    summaries = re.findall(engine.CASE_MARKERS[case], output)
    engine.require(len(summaries) == 1, "Missing unique failure-containment summary: " + case)
    try:
        result = json.loads(summaries[0])
    except (ValueError, TypeError) as error:
        raise RuntimeError("Malformed failure-containment summary: " + case) from error
    engine.require(isinstance(result, dict) and type(result.get("checks")) is int
                   and result["checks"] >= minimum_checks and result.get("failures") == [],
                   "Failure containment did not execute successfully: " + case)
    completed = result.get("sections")
    engine.require(isinstance(completed, dict) and set(completed) == sections
                   and all(value is True for value in completed.values()),
                   "Incomplete failure-containment sections: " + case)
    return result


def verify_failed_world_summary(output: str) -> None:
    result = _completed_summary(output, "test_failed_world_status_survives", FAILED_WORLD_SECTIONS, 100)
    faults = result.get("faults")
    engine.require(isinstance(faults, list) and len(faults) == 2
                   and all(isinstance(item, dict) and isinstance(item.get("operation"), str) for item in faults),
                   "Missing actual native exception witnesses")
    by_operation = {item.get("operation"): item for item in faults}
    engine.require(set(by_operation) == {"diagnostic_fill_rect", "simulation_tick"},
                   "Missing independent write and tick exception witnesses")
    for operation, detail in (("diagnostic_fill_rect", "experimental Water state out of domain"),
                              ("simulation_tick", "active scheduling-core capacity exhausted")):
        item = by_operation[operation]
        engine.require(type(item.get("count")) is int and item["count"] == 1
                       and isinstance(item.get("error"), str) and detail in item["error"]
                       and type(item.get("completed_tick")) is int and item["completed_tick"] >= 0
                       and type(item.get("attempted_tick")) is int
                       and item["attempted_tick"] >= item["completed_tick"],
                       "Invalid diagnosed native exception witness: " + operation)


def verify_workbench_failure_summary(output: str) -> None:
    result = _completed_summary(output, "test_workbench_failure_containment", WORKBENCH_FAILURE_SECTIONS, 50)
    engine.require(result.get("real_workbench") is True and type(result.get("recovered_ticks")) is int
                   and result["recovered_ticks"] >= 4, "Real Workbench recovery did not advance")
    observations = result.get("observations")
    engine.require(isinstance(observations, list) and len(observations) == 3
                   and all(isinstance(item, dict) and isinstance(item.get("case"), str) for item in observations),
                   "Missing failure-publication observations")
    by_case = {item.get("case"): item for item in observations}
    engine.require(set(by_case) == {"prepublication_fault", "late_publication_fault", "running_owner"},
                   "Incomplete owner failure witnesses")
    for name, item in by_case.items():
        engine.require(type(item.get("failure_count")) is int and item["failure_count"] == 1
                       and isinstance(item.get("error"), str) and bool(item["error"]),
                       "Invalid owner failure diagnosis: " + name)
    late = by_case["late_publication_fault"]
    engine.require(late.get("late_fault_injected") is True
                   and type(late.get("previous_tick")) is int
                   and type(late.get("published_tick")) is int
                   and late["previous_tick"] == late["published_tick"],
                   "Late publication did not preserve the last healthy tick")
    native = by_case["running_owner"].get("native")
    engine.require(isinstance(native, dict) and native.get("enabled") is True
                   and isinstance(native.get("spill"), dict) and native["spill"].get("parcels") is True
                   and isinstance(native.get("parameters"), dict)
                   and type(native["parameters"].get("body_push")) is int
                   and native["parameters"]["body_push"] == 0,
                   "Running owner did not exercise zero-push hybrid Wave")


engine.verify_case_results = verify_case_results

if __name__ == "__main__":
    raise SystemExit(engine.main())
