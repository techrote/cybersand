#!/usr/bin/env python3
"""Publish source-matched LCB-002 runtimes on its explicit candidate branch.

Reuse the accepted shared-contract publisher's byte, execution, source-lease and
four-path checks in an isolated module. Its historical LCB-001 configuration is
unchanged. This profile additionally requires actual cached/dormant execution.
The workflow owns the single-parent append; this helper never pushes.
"""
from importlib.util import module_from_spec, spec_from_file_location
import json
from pathlib import Path
import re

_spec = spec_from_file_location(
    "_lcb002_shared_publication_engine",
    Path(__file__).with_name("lcb001_shared_contract_runtime_publication.py"),
)
engine = module_from_spec(_spec)
_spec.loader.exec_module(engine)
engine.BRANCH = "codex/lcb002-pressure-variants"
engine.WORKFLOW = ".github/workflows/lcb002-pressure-variants-runtime-publication.yml"
engine.REQUEST = "tools/ci/lcb002_pressure_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-10-25-lcb002-pressure-variants.md"
engine.BUNDLE_PREFIX = "lcb002-pressure-variants-runtime"
engine.PRESSURE_CASE = "godot/tests/test_lcb_pressure_optimization.gd"
engine.REQUEST_VALUE = {
    "schema": "lcb002-pressure-publish-request-v1",
    "family": "pressure_flow_v1",
    "variant": "reference-cached-cached_dormant",
    "scope": "lcb002-bounded-pressure-optimization-execution3",
    "intent": "publish-source-matched-runtimes",
}
engine.CASE_MARKERS = dict(engine.CASE_MARKERS) | {
    "test_lcb_pressure_optimization":
        r"(?m)^LCB_PRESSURE_OPTIMIZATION: [1-9][0-9]* assertions; 0 failures; completed=(.+)$",
}
engine.CASE_TIMEOUTS = dict(engine.CASE_TIMEOUTS) | {"test_lcb_pressure_optimization": 360}
engine.EXECUTION_SCOPE = (
    "Import plus reference, cached and cached_dormant pressure arms, native copied "
    "readback and identity, one/four-worker equivalence and retained shared-contract, "
    "MicroScenario, Water Feel and WEX controls on each target OS; full ready-PR CI "
    "remains separate"
)
engine.BUILD_EXACT = set(engine.BUILD_EXACT) | {
    engine.WORKFLOW, engine.REQUEST,
    "tools/ci/lcb002_pressure_runtime_publication.py",
    "tools/ci/test_lcb002_pressure_runtime_publication.py",
}

# Filled by the independently asserted GDExtension regression. A green process
# or a positive assertion count alone cannot replace completed groups.
OPTIMIZATION_SECTIONS = {
    "native_variants": True, "readback_encoding": True, "exact_parity": True,
    "gas_invalidation": True, "cold_restore": True, "default_preservation": True,
}
_verify_shared = engine.verify_case_results


def verify_case_results(directory: Path, report: dict) -> None:
    _verify_shared(directory, report)
    output = (directory / "test_lcb_pressure_optimization.log").read_text(encoding="utf-8")
    summaries = re.findall(engine.CASE_MARKERS["test_lcb_pressure_optimization"], output)
    engine.require(len(summaries) == 1, "Incomplete pressure-optimization helper sections")
    try:
        sections = json.loads(summaries[0])
    except (ValueError, TypeError) as exc:
        raise RuntimeError("Malformed pressure-optimization helper sections") from exc
    engine.require(
        sections == OPTIMIZATION_SECTIONS
        and all(type(sections[key]) is bool for key in OPTIMIZATION_SECTIONS),
        "Incomplete pressure-optimization helper sections",
    )


engine.verify_case_results = verify_case_results

if __name__ == "__main__":
    raise SystemExit(engine.main())
