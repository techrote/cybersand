"""Versioned source-bound recipes for the existing compiled candidate World.

A case stores authoring inputs, not a saved World or a prior PASS. Import is
validation only; the source and scenario must be exercised again to qualify it.
"""
from __future__ import annotations

import copy
from pathlib import Path
from typing import Any

import lab
import world_candidate

SCHEMA = "cybersand.material-lab.world-case"
VERSION = 1
CASE_FIELDS = ("schema_id", "schema_version", "candidate", "candidate_digest",
               "scenario", "source_identity", "digest")
SOURCE_FIELDS = ("digest", "lf_sha256")


def _identity() -> dict:
    source, _ = world_candidate._source_snapshot()
    # Git HEAD is informational, not an input: documentation-only commits
    # must not invalidate an otherwise identical executable experiment.
    return {key: copy.deepcopy(source[key]) for key in SOURCE_FIELDS}


def _validate_identity(value: Any) -> dict:
    lab.fields(value, SOURCE_FIELDS, "/case/source_identity")
    hashes = value["lf_sha256"]
    if type(hashes) is not dict or not hashes or len(hashes) > 4096:
        lab.fail("/case/source_identity/lf_sha256", "expected a bounded native source hash map")
    for name, hashed in hashes.items():
        if type(name) is not str or type(hashed) is not str or len(hashed) != 64 or any(c not in "0123456789abcdef" for c in hashed):
            lab.fail("/case/source_identity/lf_sha256", "expected source paths and lowercase SHA-256 values")
    if value["digest"] != lab.digest(hashes):
        lab.fail("/case/source_identity/digest", "source hash map does not match its digest")
    current = _identity()
    if current != value:
        changed = sorted(name for name in set(current["lf_sha256"]) | set(hashes)
                         if current["lf_sha256"].get(name) != hashes.get(name))
        lab.fail("/case/source_identity", "this test case belongs to different executable inputs: " +
                 ", ".join(changed[:5]) + ". Import its material preset separately and save a new case after explicitly reconciling the source; the old test is not replayed as equivalent.")
    return current


def _result(candidate: dict, scenario: dict, source: dict, case_digest: str) -> dict:
    result = lab.validate_candidate(candidate)
    if _identity() != source:
        lab.fail("/case/source_identity", "source changed during case validation; retry against stable source")
    result.update(scenario=copy.deepcopy(scenario), case_digest=case_digest,
                  world_case_schema=SCHEMA,
                  boundary="Source-bound candidate and World recipe validated. No simulation was run by saving or importing this case. Compile + compare World to obtain a fresh native result; runtime-active is false.")
    return result


def export_case(candidate: Any, scenario: Any, path: Path) -> dict:
    # A saved case is an explicit recipe. The compile API's optional default
    # scenario must never silently replace malformed saved authoring inputs.
    lab.fields(scenario, world_candidate.SCENARIO_FIELDS, "/scenario")
    source = _identity()
    normalized, _catalogue, recipe = world_candidate.admit(candidate, scenario)
    document = {"schema_id": SCHEMA, "schema_version": VERSION,
                "candidate": normalized, "candidate_digest": lab.digest(normalized),
                "scenario": recipe, "source_identity": source}
    document["digest"] = lab.digest(document)
    result = _result(normalized, recipe, source, document["digest"])
    lab._check_cancelled()
    lab._atomic_json(Path(path), document)
    result["path"] = str(Path(path).resolve())
    return result


def import_case(path: Path) -> dict:
    document = lab.read_json(Path(path))
    lab.fields(document, CASE_FIELDS, "/case")
    if document["schema_id"] != SCHEMA or type(document["schema_version"]) is not int or document["schema_version"] != VERSION:
        lab.fail("/case/schema_version", "unsupported compiled-World case schema/version")
    payload = {key: value for key, value in document.items() if key != "digest"}
    if type(document["digest"]) is not str or document["digest"] != lab.digest(payload):
        lab.fail("/case/digest", "test recipe content does not match its deterministic digest")
    if document["candidate_digest"] != lab.digest(document["candidate"]):
        lab.fail("/case/candidate_digest", "material definition does not match its digest")
    lab.fields(document["scenario"], world_candidate.SCENARIO_FIELDS, "/scenario")
    source = _validate_identity(document["source_identity"])
    normalized, _catalogue, recipe = world_candidate.admit(document["candidate"], document["scenario"])
    if normalized != document["candidate"]:
        lab.fail("/case/candidate", "case contains a noncanonical candidate; export a freshly validated case")
    result = _result(normalized, recipe, source, document["digest"])
    result["path"] = str(Path(path).resolve())
    return result
