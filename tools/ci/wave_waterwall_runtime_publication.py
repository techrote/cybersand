#!/usr/bin/env python3
"""Source-matched WAVE-WATERWALL-001 runtime publication on its own Draft branch.

The Wave Flow publisher profile (PR #631) is reused unchanged: the same source,
input-ledger, target-OS, LFS and four-file publication guards, and the same
Wave/Workbench/Rapier cases. This profile only binds the branch, request and
evidence record of the exposed-face spill lane and adds its Workbench case.
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
}
engine.EXECUTION_SCOPE = (
    base.engine.EXECUTION_SCOPE
    + " WAVE-WATERWALL-001: native admission, refusal atomicity, exact conservation and"
    " worker parity of Waterwall spill with ballistic release, and its ordinary"
    " Workbench Water Lab apply/compare lifecycle."
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


engine.verify_case_results = verify_case_results

if __name__ == "__main__":
    raise SystemExit(engine.main())
