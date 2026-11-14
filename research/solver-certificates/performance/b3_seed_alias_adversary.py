"""B4 exact-blob-gated B3-RESEARCH-4 mutable-IN-seed adversary.

Run against a local B3 #555 checkout (no network required):
  python b3_seed_alias_adversary.py --module /path/to/handoff_contract.py
Or independent predicate-only shadow control:
  python b3_seed_alias_adversary.py --shadow

Never substitutes this model for CyberSand native World / physical-hash proof.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

MAIN = "d4b18e7f06839b35c8f6a66195206da0f33c5fa3"
B3_HEAD = "aedb37ab671888a2c9914ad01d8c33c330cbc3f1"
B3_BLOB = "523810bee1d9b219a421557181ecae108d222ef2"


def blob_id(raw: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw).hexdigest()


def load_pinned(path: Path):
    raw = path.read_bytes()
    got = blob_id(raw)
    if got != B3_BLOB:
        raise ValueError(f"SOURCE_MISMATCH expected={B3_BLOB} actual={got}")
    spec = importlib.util.spec_from_file_location("b4_exact_b3_alias_probe", path)
    if spec is None or spec.loader is None:
        raise ValueError("could not load pinned B3 source")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = mod
    spec.loader.exec_module(mod)
    if mod.MODEL_VERSION != "B3-RESEARCH-4":
        raise ValueError("MODEL_VERSION mismatch")
    return mod


def exact_probe(m):
    # Positive control: tuple IN source cannot be changed through element assignment.
    w = m.World.start(3, [m.Record("water", m.Owner.INERTIAL,
                                    m.WHOLE_CELL, velocity_q256=(0, 0))],
                      signed_inertial_world_enabled=False)
    try:
        w.records["water"].velocity_q256[1] = -8
    except TypeError:
        tuple_mutation_refused = True
    else:
        raise AssertionError("tuple unexpectedly mutable")
    w.assert_invariants()

    # Negative: mutable list accepted by B3 seed predicate and aliased in World.
    v = [0, 0]
    seed = m.Record("water", m.Owner.INERTIAL, m.WHOLE_CELL, velocity_q256=v)
    w = m.World.start(3, [seed], signed_inertial_world_enabled=False)
    h0 = w.material_identity()
    initial_epoch, initial_revision = w.epoch, w.records["water"].revision
    assert w.records["water"].velocity_q256 is v
    v[1] = -8
    assert w.records["water"].velocity_q256[1] == -8
    assert (w.epoch, w.records["water"].revision) == (initial_epoch, initial_revision)
    assert w.material_identity() != h0
    try:
        w.assert_invariants()
    except AssertionError:
        invariant_later_detects = True
    else:
        raise AssertionError("invalid unsigned IN state not detected")
    assert not m.inertial_seed_admissible(w.records["water"], False)

    # Follow-on: a fresh token from the already-invalid source can move IN to BW.
    # Conservation still holds, but provenance/policy custody was bypassed.
    intent = m.prepare(w, token="late", source_id="water",
                       target=m.Owner.BALLISTIC, amount=m.WHOLE_CELL,
                       next_velocity_q256=(0, -8))
    receipt = m.commit(w, intent, fenced=True)
    assert receipt.status == m.ReceiptStatus.COMMITTED
    assert w.records["water"].owner == m.Owner.BALLISTIC
    assert w.water_total() == m.WHOLE_CELL
    w.assert_invariants()

    # Existing source-snapshot protection is effective when prepare preceded mutation.
    old_list = [0, 0]
    w2 = m.World.start(3, [m.Record("water", m.Owner.INERTIAL,
                                    m.WHOLE_CELL, velocity_q256=old_list)],
                       signed_inertial_world_enabled=False)
    old_intent = m.prepare(w2, token="early", source_id="water",
                           target=m.Owner.BALLISTIC, amount=m.WHOLE_CELL)
    old_list[1] = -8
    r2 = m.commit(w2, old_intent, fenced=True)
    assert r2.status == m.ReceiptStatus.REFUSED
    assert r2.reason == m.Refusal.SOURCE_DRIFT
    assert w2.epoch == 0

    # Signed-world control: same list mutation is policy-permitted, still unversioned.
    sv = [0, 0]
    ws = m.World.start(3, [m.Record("water", m.Owner.INERTIAL,
                                    m.WHOLE_CELL, velocity_q256=sv)],
                       signed_inertial_world_enabled=True)
    sv[1] = -8
    ws.assert_invariants()
    return dict(tuple_mutation_refused=tuple_mutation_refused,
                unsigned_mutable_seed_admitted=True,
                post_start_unsigned_in_negative_velocity=True,
                world_epoch_or_source_revision_changed_on_alias=False,
                later_invariant_detected=invariant_later_detects,
                post_mutation_fresh_handoff_committed=True,
                source_snapshot_prepared_before_alias_refused=True,
                signed_world_control_valid=True, water_quantity_preserved=True)


def shadow_probe():
    # Independent source-equivalent construction/alias predicate only.
    # Not a replacement for exact-source execution of model commit().
    checks = []
    for signed in (False, True):
        for mutable in (False, True):
            v = [0, 0] if mutable else (0, 0)
            assert isinstance(v, (tuple, list)) and all(type(x) is int for x in v)
            original_id = id(v)
            record = {"velocity": v, "owner": "inertial", "amount": 256}
            if mutable:
                v[1] = -8
                assert id(record["velocity"]) == original_id
                later_admissible = signed or record["velocity"][1] >= 0
                assert later_admissible == signed
            else:
                try:
                    v[1] = -8
                except TypeError:
                    later_admissible = True
                else:
                    raise AssertionError("tuple mutability control failed")
            checks.append(dict(signed=signed, mutable=mutable,
                               post_mutation_admissible=later_admissible))
    return dict(shadow_controls=len(checks), cases=checks)


def main():
    ap = argparse.ArgumentParser()
    group = ap.add_mutually_exclusive_group(required=True)
    group.add_argument("--shadow", action="store_true")
    group.add_argument("--module", type=Path)
    args = ap.parse_args()
    result = shadow_probe() if args.shadow else exact_probe(load_pinned(args.module))
    print(json.dumps(dict(scope="B3-research-model-only", accepted_main=MAIN,
                          b3_head=B3_HEAD, b3_blob=B3_BLOB,
                          exact_module_executed=not args.shadow, result=result),
                     indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
