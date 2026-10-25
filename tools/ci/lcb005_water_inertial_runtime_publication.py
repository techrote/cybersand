#!/usr/bin/env python3
"""Unarmed, branch-isolated Water IN successor of the complete 005/001 engine.

No shared imported profile is mutated. The separate request is deliberately
absent until independent review and a final source freeze. This helper never
pushes; the exact-branch workflow owns the four-path atomic append.
"""
from importlib.util import module_from_spec, spec_from_file_location
import json
import os
from pathlib import Path
import re

_spec = spec_from_file_location(
    "_lcb005_water_private_union_profile",
    Path(__file__).with_name("lcb005_inertial_runtime_publication.py"),
)
union = module_from_spec(_spec)
_spec.loader.exec_module(union)
engine = union.engine
OPTIMIZATION_SECTIONS = dict(union.OPTIMIZATION_SECTIONS)
INERTIAL_SECTIONS = dict(union.INERTIAL_SECTIONS)
engine.BRANCH = "codex/lcb005-water-inertial"
engine.WORKFLOW = ".github/workflows/lcb005-water-inertial-runtime-publication.yml"
engine.REQUEST = "tools/ci/lcb005_water_inertial_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-10-25-water-inertial-publication.md"
engine.BUNDLE_PREFIX = "lcb005-water-inertial-runtime"
engine.REQUEST_VALUE = {
    "schema": "lcb005-water-inertial-publish-request-v1",
    "family": "inertial_cellular_v1",
    "material": "water",
    "variant": "reference",
    "scope": "water-inertial-admission-coherence-ingress-restore-and-complete005-pressure-union",
    "intent": "publish-source-matched-runtimes",
}
engine.EXECUTION_SCOPE = (
    "All fifteen original 005/001 processes on each target OS, including strict "
    "seven-field liquid policy and both six-field IN/pressure helpers, plus "
    "actual Water IN retained motion, whole-cell mass3/8 configured1/4-worker "
    "parity, exact 7-to-0 live coherence with vertical travel, transactional "
    "fractional ingress refusal and five-tick CYPS3 continuation; full ready-PR "
    "CI, common-Water scientific screens and host/Web/owner qualification remain separate"
)
engine.BUILD_EXACT = set(engine.BUILD_EXACT) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/lcb005_water_inertial_runtime_publication.py",
    "tools/ci/test_lcb005_water_inertial_runtime_publication.py",
}
WATER_MARKER = r"(?m)^WATER_INERTIAL_POLICY_PROOF: (\{.+\})\s*$"
SCHEMA = "water-inertial-runtime-proof-v1"
_verify_union = engine.verify_case_results
_verify_union_bundle = engine.verify_bundle


def _keys(value, keys, label):
    engine.require(isinstance(value, dict) and set(value) == set(keys), "Incomplete Water IN " + label)


def _integer(value, expected):
    return type(value) is int and value == expected


def _hash64(value):
    # The actual immutable GDExtension value API encodes uint64 as16hex.
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{16}", value) is not None


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        engine.require(key not in result, "Duplicate Water IN proof field")
        result[key] = value
    return result


def verify_water_proof(proof):
    _keys(proof, ("schema", "assertions", "failures", "cohorts", "restores", "refusals", "coherence"), "proof fields")
    engine.require(proof["schema"] == SCHEMA and type(proof["assertions"]) is int and proof["assertions"] > 0
                   and _integer(proof["failures"], 0), "Non-passing Water IN proof")
    cohorts = proof["cohorts"]
    engine.require(isinstance(cohorts, list) and len(cohorts) == 4, "Incomplete Water IN cohorts")
    by_key = {}
    for row in cohorts:
        _keys(row, ("mass_bits", "workers", "family", "policy_hash", "radius", "hash_version", "tick1_motion",
                    "censuses", "initial_content_hash", "completed_ticks", "physical_hash", "final_content_hash"), "cohort")
        bits, workers = row["mass_bits"], row["workers"]
        engine.require(type(bits) is int and bits in (3, 8) and type(workers) is int and workers in (1, 4)
                       and (bits, workers) not in by_key, "Duplicate or invalid Water IN cohort")
        by_key[bits, workers] = row
        engine.require(row["family"] == "inertial_cellular_v1" and isinstance(row["policy_hash"], str)
                       and re.fullmatch(r"[0-9a-f]{64}", row["policy_hash"]) is not None
                       and _integer(row["radius"], 3) and _integer(row["hash_version"], 3)
                       and _integer(row["completed_ticks"], 20) and row["tick1_motion"] is True,
                       "Water IN native admission/motion is not proved")
        engine.require(all(_hash64(row[key]) for key in ("initial_content_hash", "final_content_hash", "physical_hash"))
                       and row["initial_content_hash"] != row["final_content_hash"], "Water IN did not move")
        censuses = row["censuses"]
        engine.require(isinstance(censuses, list) and len(censuses) == 3, "Incomplete Water IN census")
        for tick, census in zip((0, 10, 20), censuses):
            _keys(census, ("tick", "count", "full", "quantity"), "census")
            engine.require(_integer(census["tick"], tick) and _integer(census["count"], 144)
                           and census["full"] is True and _integer(census["quantity"], 144 * ((1 << bits) - 1)),
                           "Water IN whole-cell quantity changed")
    engine.require(set(by_key) == {(bits, workers) for bits in (3, 8) for workers in (1, 4)}, "Incomplete Water IN worker matrix")
    engine.require(len({row["policy_hash"] for row in cohorts}) == 1, "Water IN applied policy differs")
    for bits in (3, 8):
        engine.require(by_key[bits, 1]["physical_hash"] == by_key[bits, 4]["physical_hash"], "Water IN worker parity differs")
    restores = proof["restores"]
    engine.require(isinstance(restores, list) and len(restores) == 2, "Incomplete Water IN restore matrix")
    seen = set()
    for row in restores:
        _keys(row, ("mass_bits", "source_workers", "format_version", "saved_bytes", "source_hash", "restored_hash", "continuation"), "restore")
        bits = row["mass_bits"]
        engine.require(type(bits) is int and bits in (3, 8) and bits not in seen and _integer(row["source_workers"], 1)
                       and _integer(row["format_version"], 3) and type(row["saved_bytes"]) is int and row["saved_bytes"] > 8,
                       "Invalid Water IN CYPS3 restore")
        seen.add(bits)
        engine.require(row["source_hash"] == row["restored_hash"] == by_key[bits, 1]["physical_hash"], "Water IN initial restore differs")
        continuation = row["continuation"]
        engine.require(isinstance(continuation, list) and len(continuation) == 5, "Incomplete Water IN continuation")
        for tick, pair in zip(range(21, 26), continuation):
            _keys(pair, ("tick", "source_hash", "restored_hash"), "continuation pair")
            engine.require(_integer(pair["tick"], tick) and _hash64(pair["source_hash"])
                           and pair["source_hash"] == pair["restored_hash"], "Water IN continuation differs")
    refusal = proof["refusals"]
    _keys(refusal, ("rows", "tick_before", "tick_after"), "refusal")
    engine.require(_integer(refusal["tick_before"], 0) and _integer(refusal["tick_after"], 1)
                   and isinstance(refusal["rows"], list) and len(refusal["rows"]) == 3, "Incomplete Water IN refusal continuation")
    for row in refusal["rows"]:
        _keys(row, ("code", "material", "unchanged_session"), "refusal row")
        engine.require(row["code"] == "normalization_required" and _integer(row["material"], 3)
                       and row["unchanged_session"] is True, "Water IN fractional refusal changed the live session")
    coherence = proof["coherence"]
    engine.require(isinstance(coherence, list) and len(coherence) == 4, "Incomplete Water IN coherence matrix")
    seen = set()
    for row in coherence:
        _keys(row, ("mass_bits", "workers", "initial", "observed", "completed_ticks", "vertical_before_expiry",
                    "retained_motion", "count", "full", "quantity"), "coherence")
        bits, workers = row["mass_bits"], row["workers"]
        engine.require(type(bits) is int and bits in (3, 8) and type(workers) is int and workers in (1, 4)
                       and (bits, workers) not in seen, "Duplicate or invalid Water IN coherence cohort")
        seen.add((bits, workers))
        engine.require(_integer(row["initial"], 7) and _integer(row["completed_ticks"], 7)
                       and row["observed"] == list(range(6, -1, -1)) and all(type(n) is int for n in row["observed"])
                       and row["vertical_before_expiry"] is True and row["retained_motion"] is True
                       and _integer(row["count"], 1) and row["full"] is True
                       and _integer(row["quantity"], (1 << bits) - 1), "Water IN coherence/material work is not proved")


def verify_case_results(directory: Path, report: dict) -> None:
    _verify_union(directory, report)
    output = (directory / "test_liquid_solver_policy.log").read_text(encoding="utf-8")
    summaries = re.findall(WATER_MARKER, output)
    engine.require(len(summaries) == 1, "Missing or duplicate Water IN proof")
    try:
        proof = json.loads(summaries[0], object_pairs_hook=_unique_object)
    except (ValueError, TypeError) as exc:
        raise RuntimeError("Malformed Water IN proof") from exc
    verify_water_proof(proof)
    assertions = re.findall(r"(?m)^LIQUID_SOLVER_POLICY: ([1-9][0-9]*) assertions; 0 failures; completed=", output)
    engine.require(len(assertions) == 1 and proof["assertions"] == int(assertions[0]), "Water IN assertion count differs from its process")


def verify_bundle(directory: Path, platform: str, source: str, validated: bool) -> dict:
    manifest = _verify_union_bundle(directory, platform, source, validated)
    if validated:
        expected = engine.BUNDLE_PREFIX + "-" + platform + "-" + os.environ["GITHUB_RUN_ID"] + "/validation.json"
        engine.require(manifest.get("validation_output") == expected, "Water IN artifact prefix differs")
        report = json.loads((directory / "validation.json").read_text(encoding="utf-8"))
        engine.require(report.get("scope") == engine.EXECUTION_SCOPE, "Water IN execution scope differs")
    return manifest


engine.verify_case_results = verify_case_results
engine.verify_bundle = verify_bundle

if __name__ == "__main__":
    raise SystemExit(engine.main())
