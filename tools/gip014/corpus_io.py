"""Bounded data-only corpus admission for the fixed disposable-profile launcher."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import re

from verify_transcript import action_error, bounded, integer

SCHEMA = "cybersand-goblin-corpus-v1"
MAX_BYTES = 2 * 1024 * 1024
CLASSIFICATIONS = {"unresolved_observation", "legal_unusual_gameplay", "expected_refusal", "unsupported_action",
                   "confirmed_harness_defect", "test_oracle_defect", "infrastructure_failure", "deliberate_negative_control",
                   "confirmed_production_gameplay_defect"}


def _hash(value):
    return isinstance(value, str) and re.fullmatch("[0-9a-f]{64}", value) is not None


def _canonical(value):
    if isinstance(value, dict):
        return {k: _canonical(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_canonical(v) for v in value]
    return int(value) if type(value) is float and value.is_integer() else value


def _plain(value, depth=0):
    if depth > 10:
        return False
    if value is None or type(value) is bool:
        return True
    if isinstance(value, str):
        return len(value) <= 4096
    if type(value) in (int, float):
        return math.isfinite(value)
    if isinstance(value, list):
        return len(value) <= 1024 and all(_plain(v, depth + 1) for v in value)
    if isinstance(value, dict):
        return len(value) <= 256 and all(isinstance(k, str) and len(k) <= 128 and _plain(v, depth + 1) for k, v in value.items())
    return False


def validate_corpus(value) -> dict:
    if not _plain(value) or not isinstance(value, dict) or value.get("schema") != SCHEMA:
        raise ValueError("Unsupported or malformed corpus")
    if len(json.dumps(value, ensure_ascii=False, allow_nan=False).encode()) > MAX_BYTES:
        raise ValueError("Corpus exceeds2MiB")
    records = value.get("records")
    if not isinstance(records, list) or len(records) > 64 or any(not bounded(value.get(k), 0, 1000000) for k in ("sequence", "total_observed", "evicted")):
        raise ValueError("Corpus record or counter bound")
    hints = value.get("search_hints", {})
    if not isinstance(hints, dict) or hints.get("schema") != "cybersand-goblin-coverage-v1" or not isinstance(hints.get("action"), dict):
        raise ValueError("Malformed corpus search hints")
    for dimension in ("action", "state_action", "action_transition", "variants"):
        supplied = hints.get(dimension, {})
        if not isinstance(supplied, dict) or len(supplied) > 256 or any(not isinstance(k, str) or len(k) > 170 or not bounded(v, 0, 1000000) for k, v in supplied.items()):
            raise ValueError("Malformed bounded corpus search hints")
    identities = set()
    for record in records:
        if not isinstance(record, dict) or not _hash(record.get("id")) or record["id"] in identities or record.get("classification") not in CLASSIFICATIONS:
            raise ValueError("Invalid or duplicate corpus identity")
        context = record.get("context", {})
        if not isinstance(context, dict) or not isinstance(context.get("fixture_id"), str) or not 1 <= len(context["fixture_id"]) <= 80 or not bounded(context.get("fixture_version"), 1, 1024) or not _hash(context.get("fixture_sha256")) or not _hash(context.get("provenance_sha256")) or not bounded(context.get("seed", 0), -(2**31), 2**31 - 1) or not isinstance(context.get("personality", ""), str) or len(context.get("personality", "")) > 80:
            raise ValueError("Invalid exact corpus fixture context")
        if record.get("verification") not in ("observed_candidate", "imported_unverified") or record.get("status") not in ("completed", "partial", "refused") or not bounded(record.get("sequence"), 1, value["sequence"]) or not bounded(record.get("step"), 1, 1024) or not bounded(record.get("score"), 0, 1124) or not bounded(record.get("seed"), -(2**31), 2**31 - 1):
            raise ValueError("Invalid corpus disposition or counters")
        if not isinstance(record.get("personality"), str) or len(record["personality"]) > 80 or not _hash(record.get("before_state")) or not _hash(record.get("after_state")):
            raise ValueError("Invalid corpus state signature")
        actions = record.get("actions")
        if type(record.get("prefix_complete")) is not bool or type(record.get("reusable")) is not bool or not isinstance(actions, list) or len(actions) > 128:
            raise ValueError("Invalid bounded action prefix")
        if record["prefix_complete"]:
            if len(actions) != record["step"] or not actions:
                raise ValueError("Incomplete corpus prefix claimed complete")
        elif actions or record["reusable"]:
            raise ValueError("Observation-only corpus record cannot be replayed")
        failed = record.get("failed_assertions")
        if not isinstance(failed, list) or len(failed) > 64 or any(not isinstance(v, str) or not 1 <= len(v) <= 120 for v in failed):
            raise ValueError("Invalid corpus assertion references")
        if record["reusable"] and (record["status"] != "completed" or failed):
            raise ValueError("Failed/partial corpus prefix cannot be reused")
        if not isinstance(record.get("native_observation_identity"), dict) or not isinstance(record.get("retention_scope"), str) or any(record.get(k) != "" and not _hash(record.get(k)) for k in ("semantic_sha256", "observation_sha256")):
            raise ValueError("Missing corpus observation custody")
        if any(action_error(action) or ("goal" in action and (not isinstance(action["goal"], str) or len(action["goal"]) > 240)) for action in actions):
            raise ValueError("Corpus contains unsupported game action")
        identity = {k: record[k] for k in ("context", "step", "before_state", "after_state", "actions", "failed_assertions")}
        encoded = json.dumps(_canonical(identity), sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()
        if hashlib.sha256(encoded).hexdigest() != record["id"]:
            raise ValueError("Corpus semantic identity differs")
        identities.add(record["id"])
    return {"valid": True, "records": len(records), "scope": "Imported hints only; game revalidates and demotes serialized confirmation labels"}


def load_corpus(path: Path) -> dict:
    with path.open("rb") as stream:
        raw = stream.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise ValueError("Corpus exceeds2MiB")
    value = json.loads(raw, parse_constant=lambda v: (_ for _ in ()).throw(ValueError("Nonfinite JSON constant")))
    validate_corpus(value)
    return value
