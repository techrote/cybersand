#!/usr/bin/env python3
"""Recompute exact or explicitly declared historical source drift for Gentek parity.

A source drift policy does NOT make differing inputs identical. It authorizes a
full source-matched 80-default native/recipe/RGBA replay, with its original
public gallery unchanged and all differences retained in the evidence.
"""
from __future__ import annotations

import hashlib
import json
import re

HEX = re.compile(r"[0-9a-f]{64}\Z")


def _sha(payload: object) -> str:
    return hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":")).encode()).hexdigest()


def assess(reference: dict, source: dict, policy: dict | None = None) -> dict:
    expected = reference.get("rendering_inputs_sha256")
    actual = source.get("inputs")
    errors: list[str] = []
    if not isinstance(expected,dict) or not expected or not isinstance(actual,dict) or not actual:
        errors.append("Source input ledger is missing")
        expected, actual = {}, {}
    for ledger in (expected,actual):
        if any(not isinstance(p,str) or not p or not isinstance(h,str) or HEX.fullmatch(h) is None
               for p,h in ledger.items()):
            errors.append("Malformed source input paths or SHA-256 hashes")
    diff = sorted(path for path in expected.keys()|actual.keys() if expected.get(path)!=actual.get(path))
    mode = "exact-inputs" if not diff else "unapproved-drift"
    if diff:
        if not isinstance(policy,dict):
            errors.append("Source inputs differ without an explicitly reviewed input delta")
        else:
            mode = "declared-drift-requires-all-80-pixel-parity"
            allowed = policy.get("baseline_sha256")
            if (policy.get("schema") != "gentek80-merged-reference-delta-v1"
                    or policy.get("reference_commit") != reference.get("source_commit")
                    or policy.get("reference_tree") != reference.get("source_tree")
                    or not isinstance(allowed,dict) or not allowed):
                errors.append("Source delta policy is malformed or targets another gallery")
            else:
                if sorted(allowed) != diff:
                    errors.append("Source delta differs from precisely enumerated approved paths")
                for p,h in allowed.items():
                    if expected.get(p) != h or (h is not None and
                            (not isinstance(h,str) or HEX.fullmatch(h) is None)):
                        errors.append("Historical SHA-256 differs from policy for "+str(p))
                    if p not in actual:
                        errors.append("Approved source drift cannot remove a source path: "+str(p))
    elif policy is not None:
        errors.append("Input drift policy supplied but all inputs are identical")
    return {
      "schema":"gentek80-reference-source-attestation-v1",
      "status":"pass" if not errors else "fail",
      "mode":mode,
      "reference_input_count":len(expected),
      "candidate_input_count":len(actual),
      "changed_paths":diff,
      "changes":[{"path":p,"reference_sha256":expected.get(p),
                  "candidate_sha256":actual.get(p)} for p in diff],
      "policy_sha256":_sha(policy) if policy is not None else None,
      "failures":errors,
    }
