#!/usr/bin/env python3
"""B3 research-only incarnation-token cross-World falsifier.

--selftest: standalone conditional pin lemma (no repository dependency).
--exact: execute pinned handoff_contract.py in this directory; refuses wrong blob.
Neither mode authenticates a native World, producer, contact or physical hash.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path

EXPECTED_MODEL_BLOB = "e8176a1a2a63fdd3edc1b097cf47647a20ff34bf"
EXPECTED_MAIN = "d4b18e7f06839b35c8f6a66195206da0f33c5fa3"


def git_blob_id(content: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(content)).encode() + b"\0" + content).hexdigest()


@dataclass(frozen=True)
class Pin:
    """Explicitly externally allocated identity; never internally minted."""
    generation: int
    incarnation_id: str
    source_id: str


def pinned_commit_admissible(prepared: Pin, destination: Pin) -> bool:
    """Necessary equality guards, not independent authenticity of the IDs."""
    return (prepared.generation == destination.generation
            and bool(prepared.incarnation_id)
            and prepared.incarnation_id == destination.incarnation_id
            and prepared.source_id == destination.source_id)


def selftest() -> dict:
    checks = 0
    for n in range(1, 513):
        generation = n % 11 + 1
        original = Pin(generation, f"original-{n}", "water")
        same = Pin(generation, f"original-{n}", "water")
        other = Pin(generation, f"restored-{n}", "water")
        assert pinned_commit_admissible(original, same)
        assert not pinned_commit_admissible(original, other)
        assert not pinned_commit_admissible(original, Pin(generation + 1, original.incarnation_id, "water"))
        assert not pinned_commit_admissible(original, Pin(generation, original.incarnation_id, "sand"))
        checks += 4
    # Negative control: a caller *reusing* the same claimed incarnation ID is not
    # detectable by equality alone. This is the exact source-custody dependency.
    forged = Pin(3, "reused-untrusted", "water")
    assert pinned_commit_admissible(forged, Pin(3, "reused-untrusted", "water"))
    checks += 1
    # Invalid blank pins must refuse, rather than silently falling back to epoch.
    assert not pinned_commit_admissible(Pin(3, "", "water"), Pin(3, "", "water"))
    checks += 1
    return {"mode": "selftest", "checks": checks, "distinct_incarnation_refusals": 512,
            "same_id_spoof_is_undetectable": True, "native_executed": False}


def exact_probe() -> dict:
    src = Path(__file__).resolve().with_name("handoff_contract.py")
    if not src.is_file():
        raise RuntimeError("exact B3 model unavailable beside this script; use --selftest or check out #555")
    actual_blob = git_blob_id(src.read_bytes())
    if actual_blob != EXPECTED_MODEL_BLOB:
        raise RuntimeError(f"B3 model blob drift: expected {EXPECTED_MODEL_BLOB}, got {actual_blob}; re-review before replay")
    from handoff_contract import (Record, Owner, World, prepare, commit,
                                  Refusal, ReceiptStatus, WHOLE_CELL)

    def initial(gen: int = 3, signed: bool = False):
        return World.start(gen, [Record("water", Owner.FREE_MASS, WHOLE_CELL)],
                           signed_inertial_world_enabled=signed)

    a = initial()
    b = initial()
    assert a is not b and a.material_identity() == b.material_identity()
    i = prepare(a, token="one-prepared-intent", source_id="water",
                target=Owner.BALLISTIC, amount=WHOLE_CELL)
    assert commit(a, i, fenced=True).status == ReceiptStatus.COMMITTED
    # This is an independent clone: the token was never prepared here.
    assert commit(b, i, fenced=True).status == ReceiptStatus.COMMITTED
    assert a.water_total() == b.water_total() == WHOLE_CELL
    assert a.records["water"].owner == b.records["water"].owner == Owner.BALLISTIC
    a.assert_invariants(); b.assert_invariants()

    # Control: generation does detect a different incarnation *when the caller
    # actually assigns a different generation*.
    c = initial(gen=4)
    assert commit(c, i, fenced=True).reason == Refusal.BAD_GENERATION
    # Signed policy protects cross-policy restoration, not a same-policy clone.
    d = initial(signed=True)
    assert commit(d, i, fenced=True).reason == Refusal.POLICY_DRIFT
    # Same-World replay remains history-only and does not spawn a second parcel.
    assert commit(a, i, fenced=False).status == ReceiptStatus.HISTORICAL_ACK_ONLY
    return {"mode": "exact", "model_blob": actual_blob,
            "same_generation_same_policy_cross_world_commit": True,
            "unique_intent_accepted_in_two_worlds": True,
            "distinct_generation_rejected": True,
            "distinct_policy_rejected": True,
            "same_world_retry_historical_only": True,
            "world_conservation_failed": False,
            "native_executed": False}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--selftest", action="store_true")
    modes.add_argument("--exact", action="store_true")
    args = parser.parse_args()
    result = selftest() if args.selftest else exact_probe()
    print(json.dumps({"research_only": True, "accepted_main": EXPECTED_MAIN, **result},
                     sort_keys=True))


if __name__ == "__main__":
    main()
