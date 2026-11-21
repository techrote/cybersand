"""B3 research-only signed-IN seed adversary; not a native physics oracle.

Default: requires exact pinned handoff_contract.py beside this file, executes
its actual World.start and invariants. --selftest checks only the independent
predicate oracle when the published module is not locally mounted.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
from pathlib import Path
import sys

EXPECTED_MODEL_BLOB = "523810bee1d9b219a421557181ecae108d222ef2"
TEST_VY = (-4096, -512, -256, -33, -32, -8, -1, 0, 1, 8, 32, 256, 512, 4096)


def git_blob_sha(path: Path) -> str:
    content = path.read_bytes()
    return hashlib.sha1(b"blob " + str(len(content)).encode("ascii") + b"\0" + content).hexdigest()


def independent_seed_oracle(*, signed: bool, owner: str, amount: int, velocity: object) -> bool:
    # This predicate is deliberately independent of the model implementation.
    if owner != "inertial":
        return True
    return (amount == 256 and isinstance(velocity, (tuple, list))
            and len(velocity) == 2 and type(velocity[0]) is int
            and type(velocity[1]) is int and (signed or velocity[1] >= 0))


def independent_selftest() -> int:
    checked = 0
    for enabled in (False, True):
        for vy in TEST_VY:
            result = independent_seed_oracle(signed=enabled, owner="inertial",
                                             amount=256, velocity=(0, vy))
            assert result is (enabled or vy >= 0)
            checked += 1
        for velocity in ((0, True), (0, "-8"), [0, -8]):
            value = independent_seed_oracle(signed=enabled, owner="inertial",
                                            amount=256, velocity=velocity)
            assert value is (enabled and velocity == [0, -8])
            checked += 1
        assert not independent_seed_oracle(signed=enabled, owner="inertial",
                                            amount=255, velocity=(0, 8))
        checked += 1
        assert independent_seed_oracle(signed=enabled, owner="ballistic",
                                       amount=96, velocity=(0, -8))
        checked += 1
    return checked


def exact_source_test(path: Path) -> int:
    actual_blob = git_blob_sha(path)
    assert actual_blob == EXPECTED_MODEL_BLOB, (actual_blob, EXPECTED_MODEL_BLOB)
    spec = importlib.util.spec_from_file_location("b3_pinned_model", path)
    assert spec is not None and spec.loader is not None
    model = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = model
    spec.loader.exec_module(model)
    assert model.MODEL_VERSION == "B3-RESEARCH-4"
    checked = 0
    for signed in (False, True):
        for vy in TEST_VY:
            source = model.Record("water", model.Owner.INERTIAL, model.WHOLE_CELL,
                                  velocity_q256=(0, vy))
            expected = independent_seed_oracle(signed=signed, owner="inertial",
                                                amount=256, velocity=(0, vy))
            try:
                w = model.World.start(3, [source], signed_inertial_world_enabled=signed)
            except ValueError:
                assert not expected, (signed, vy)
            else:
                assert expected, (signed, vy)
                w.assert_invariants()
                assert w.water_total() == model.WHOLE_CELL
            checked += 1
        for vel in ((0, True), (0, "-8"), [0, -8]):
            record = model.Record("bad", model.Owner.INERTIAL, 256, velocity_q256=vel)
            expected = independent_seed_oracle(signed=signed, owner="inertial",
                                                amount=256, velocity=vel)
            try:
                model.World.start(3, [record], signed_inertial_world_enabled=signed)
            except ValueError:
                assert not expected
            else:
                assert expected
            checked += 1
    negative = model.Record("water", model.Owner.INERTIAL, 256, velocity_q256=(0, -8))
    w = model.World(3, 0, {"water": negative}, 256,
                    signed_inertial_world_enabled=False)
    try:
        w.assert_invariants()
    except AssertionError:
        checked += 1
    else:
        raise AssertionError("unsigned direct restored IN state incorrectly verified")
    # Original valid signed World must be invalidated by a forged applied-policy flip.
    w = model.World.start(3, [negative], signed_inertial_world_enabled=True)
    w.signed_inertial_world_enabled = False
    try:
        w.assert_invariants()
    except AssertionError:
        checked += 1
    else:
        raise AssertionError("forged signed-policy downgrade survived invariant check")
    return checked


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--selftest", action="store_true", help="predicate only; NOT exact B3 source")
    ap.add_argument("--module", type=Path, default=Path(__file__).with_name("handoff_contract.py"))
    args = ap.parse_args()
    controls = independent_selftest()
    if args.selftest:
        print(f"PASS: {controls} independent predicate controls only; B3 module NOT EXECUTED")
    else:
        actual = exact_source_test(args.module)
        print(f"PASS: pinned model blob {EXPECTED_MODEL_BLOB}; {actual} exact B3 source controls, {controls} predicate controls")


if __name__ == "__main__":
    main()
