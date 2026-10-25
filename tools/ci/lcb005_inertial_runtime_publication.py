#!/usr/bin/env python3
"""Prepare branch-scoped IN plus pressure-union runtime publication.

The accepted shared-contract engine owns byte/provenance verification, actual
target-OS execution, the source lease and four-path publication checks. Load it
in isolation so historical profile defaults retain their identity. This profile
requires both IN and pressure-optimization regressions; it cannot qualify an
IN-only source. The workflow owns the append, and this helper never pushes.
"""
from importlib.util import module_from_spec, spec_from_file_location
import json
from pathlib import Path
import re

_spec = spec_from_file_location(
    "_lcb005_shared_publication_engine",
    Path(__file__).with_name("lcb001_shared_contract_runtime_publication.py"),
)
engine = module_from_spec(_spec)
_spec.loader.exec_module(engine)
engine.BRANCH = "codex/lcb005-inertial"
engine.WORKFLOW = ".github/workflows/lcb005-inertial-runtime-publication.yml"
engine.REQUEST = "tools/ci/lcb005_inertial_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-10-25-lcb005-pressure-union-integration.md"
engine.BUNDLE_PREFIX = "lcb005-inertial-runtime"
engine.PRESSURE_CASE = "godot/tests/test_lcb_inertial_adapter.gd"
engine.REQUEST_VALUE = {
    "schema": "lcb005-inertial-publish-request-v1",
    "family": "inertial_cellular_v1",
    "variant": "reference",
    "scope": "lcb005-inertial-and-lcb002-pressure-execution3-union",
    "intent": "publish-source-matched-runtimes",
}
engine.CASE_MARKERS = dict(engine.CASE_MARKERS) | {
    "test_lcb_pressure_optimization":
        r"(?m)^LCB_PRESSURE_OPTIMIZATION: [1-9][0-9]* assertions; 0 failures; completed=(.+)$",
    "test_lcb_inertial_adapter":
        r"(?m)^LCB_INERTIAL_ADAPTER: [1-9][0-9]* assertions; 0 failures; completed=(.+)$",
}
engine.CASE_TIMEOUTS = dict(engine.CASE_TIMEOUTS) | {
    "test_lcb_pressure_optimization": 360, "test_lcb_inertial_adapter": 360,
}
engine.EXECUTION_SCOPE = (
    "Import plus actual Brine IN parameter/instance identity, explicit radius-three "
    "construction and radius-two refusal/default preservation, mixed IN/CY/FM/PF "
    "one/four-worker continuation, all three pressure arms and their readback, "
    "identity/gas/cold-restore controls, and all twelve retained shared-contract, "
    "MicroScenario, Water Feel and WEX cases on each target OS; full ready-PR CI "
    "remains separate"
)
engine.BUILD_EXACT = set(engine.BUILD_EXACT) | {
    engine.WORKFLOW, engine.REQUEST,
    "tools/ci/lcb005_inertial_runtime_publication.py",
    "tools/ci/test_lcb005_inertial_runtime_publication.py",
    "godot/tests/fixtures/lcb/inertial-adapter-parameters.json",
}
OPTIMIZATION_SECTIONS = {
    "native_variants": True, "readback_encoding": True, "exact_parity": True,
    "gas_invalidation": True, "cold_restore": True, "default_preservation": True,
}
INERTIAL_SECTIONS = {
    "oracle_parameters": True, "instance_readback": True, "radius_transaction": True,
    "mixed_workers": True, "cyps_continuation": True, "default_preservation": True,
}
_verify_shared = engine.verify_case_results


def verify_case_results(directory: Path, report: dict) -> None:
    _verify_shared(directory, report)
    for name, expected in (
        ("test_lcb_pressure_optimization", OPTIMIZATION_SECTIONS),
        ("test_lcb_inertial_adapter", INERTIAL_SECTIONS),
    ):
        output = (directory / (name + ".log")).read_text(encoding="utf-8")
        summaries = re.findall(engine.CASE_MARKERS[name], output)
        engine.require(len(summaries) == 1, "Incomplete union helper sections: " + name)
        try:
            sections = json.loads(summaries[0])
        except (ValueError, TypeError) as exc:
            raise RuntimeError("Malformed union helper sections: " + name) from exc
        engine.require(
            sections == expected and all(type(sections[key]) is bool for key in expected),
            "Incomplete union helper sections: " + name,
        )


engine.verify_case_results = verify_case_results

if __name__ == "__main__":
    raise SystemExit(engine.main())
