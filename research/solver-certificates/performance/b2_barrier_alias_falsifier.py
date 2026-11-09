"""B4 independent packet-alias falsifier for B2 sparse_fence (research only).

Run on an *exact* local checkout of B2 PR #556:
  python3 research/solver-certificates/performance/b2_barrier_alias_falsifier.py \
    --model /path/to/b2-worktree/research/solver-certificates/invalidation/sparse_fence.py

The B4 branch does not vendor or modify B2. No CyberSand native code is used.
Expected B2 source Git blob: f20d33ea7ec30be91107a0cdb3248b9358ee2b9c
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

EXPECTED_B2_BLOB = "f20d33ea7ec30be91107a0cdb3248b9358ee2b9c"
EXPECTED_B2_HEAD = "90d87d4611ed09ae034b95f99fa7bc17125cff3e"
ACCEPTED_MAIN = "d4b18e7f06839b35c8f6a66195206da0f33c5fa3"


def git_blob_id(data: bytes) -> str:
    prefix = b"blob " + str(len(data)).encode("ascii") + bytes([0])
    return hashlib.sha1(prefix + data).hexdigest()


def load_exact_model(path: Path):
    source = path.read_bytes()
    actual_blob = git_blob_id(source)
    if actual_blob != EXPECTED_B2_BLOB:
        raise ValueError(
            f"SOURCE_MISMATCH: expected {EXPECTED_B2_BLOB}, got {actual_blob}"
        )
    spec = importlib.util.spec_from_file_location("b2_sparse_fence_pinned", path)
    if spec is None or spec.loader is None:
        raise ValueError("cannot import pinned B2 model")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module, actual_blob


def probe(mod, workers: int, kind: str) -> dict:
    """Compare post-commit state to *accepted* payload, not later aliased bytes."""
    baseline = mod.initial("quiet")
    fence = mod.Fence(mod.Sparse(baseline), workers)
    if kind == "pressure":
        mutable_event = ["pressure", 0]
        accepted_event = ("pressure", 0)
        mutated_value = 1
    elif kind == "set":
        mutable_event = ["set", 4, 4, mod.ROCK]
        accepted_event = ("set", 4, 4, mod.ROCK)
        mutated_value = mod.WATER
    else:
        raise ValueError("unregistered case")

    # The nested event list is caller-owned. Packet.make only tuple-wraps
    # the outer iterable; the frozen dataclass does not deep-freeze this list.
    submitted = mod.Packet.make(0, 0, workers - 1, (mutable_event,))
    for shard in range(workers - 1):
        fence.accept(mod.Packet.make(0, 0, shard, ()))
    if workers == 4:
        if fence.advance() != "BLOCKED":
            raise AssertionError("barrier committed with a missing fourth shard")
    fence.accept(submitted)
    accepted_check = submitted.check
    if mod.digest(0, 0, workers - 1, submitted.events) != accepted_check:
        raise AssertionError("the accepted packet was already inconsistent")

    expected = baseline.copy()
    mod.full_step(expected, (accepted_event,))
    mutable_event[-1] = mutated_value  # after accept, before owner reduction
    changed_check = mod.digest(0, 0, workers - 1, submitted.events)
    if changed_check == accepted_check:
        raise AssertionError("mutation did not change digest")

    try:
        outcome = fence.advance()
    except ValueError as exc:
        return dict(workers=workers, kind=kind, outcome="REFUSED",
                    detail=str(exc), digest_changed=True, state_matches_original=True)
    actual = fence.engine.state
    diverges = actual != expected
    return dict(workers=workers, kind=kind, outcome=outcome,
                digest_changed=True, state_matches_original=not diverges,
                pressure_actual=actual.pressure, pressure_accepted=expected.pressure,
                accepted_witness_stale=changed_check != accepted_check,
                falsifier_hit=(outcome == "COMMITTED" and diverges))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", type=Path, required=True,
                    help="B2 exact-head sparse_fence.py in a separate checkout")
    args = ap.parse_args()
    mod, blob = load_exact_model(args.model)
    results = [probe(mod, workers, kind)
               for workers in (1, 4) for kind in ("pressure", "set")]
    report = dict(accepted_main=ACCEPTED_MAIN, b2_head=EXPECTED_B2_HEAD,
                  b2_blob=blob, scope="research-model-only",
                  results=results,
                  any_accepted_payload_substitution=any(
                      r.get("falsifier_hit", False) for r in results))
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, AssertionError) as exc:
        print(f"INCONCLUSIVE: {exc}", file=sys.stderr)
        sys.exit(2)
