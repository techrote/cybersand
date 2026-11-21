---
title: B3-RESEARCH-5 seed alias custody and owned initial World values
status: Experimental / HOLD, independent exact-module replay pending
document-kind: research-evidence
scope: Isolated B3 multisolver handoff model only
last-reviewed: 2026-11-10
---

# B3-RESEARCH-5 — eliminate mutable caller-owned seed aliases

## Frozen source, independent challenge, bounded falsifier

Accepted CyberSand main: `d4b18e7f06839b35c8f6a66195206da0f33c5fa3` (verified live on 10 Nov 2026). Existing B3 Draft #555 parent: `aedb37ab671888a2c9914ad01d8c33c330cbc3f1`; previous `handoff_contract.py` blob: `523810bee1d9b219a421557181ecae108d222ef2` (B3-RESEARCH-4). Proposed resulting code/test blobs at this checkpoint: `facfa6ff8a1d67448a17faf5dfe0c7393ea04d13` and `e494a301b344c6cfc3f6839b1c50d69f92f8f972`.

Pre-registered before edits in [PR #555](https://github.com/techrote/cybersand/pull/555#issuecomment-6757410417). Independent B4 [negative source-critical finding](https://github.com/techrote/cybersand/pull/555#issuecomment-6756719578), [independent checker](https://github.com/techrote/cybersand/blob/665e7e05be06b829d5f4e0163b0a80019a0c37aa/research/solver-certificates/performance/b3_seed_alias_adversary.py).

**Original counterexample:** Pass caller-owned `velocity_q256=[0,0]` to a nominally frozen `Record` used as an unsigned IN seed. The original `World.start` put this same object into `World.records`. Mutating the caller's list to `[0,-8]` silently changed previously admitted signed-velocity values without an epoch/revision advance. A later invariant check would complain, but this was too late to establish initial-state custody. Not a native CyberSand bug.

**Falsifier after repair:** An initially accepted, properly signed/unsigned-typed World changes `World.records`, its model identity or a pending prepared intent's source witness after a later change **only to the caller-owned initial list**. No such change is permitted.

## Exact research-model repair

`World.start` verifies the input's primitive types, owner and initial IN signed policy, then creates a new `Record` per seed and stores a fresh immutable tuple of its two integer velocities. `Record.valid` now requires exact integer types for scalar values and both velocity elements (bool is not an integer for admission). Untrusted initial inputs may use either a two-integer tuple or list for compatibility, but `World.assert_invariants` requires canonical tuple-valued **owned** World records. A directly constructed/restored dataclass holding a list is not considered validated.

This is construction-boundary materialization, not extra per-tick state copying. It does not modify Python public `World.records` mutability or prevent arbitrary privileged writes. Such direct unversioned state updates remain outside the trusted one-writer transition theorem; existing prepared-intent source signatures detect value drift when the value changes. A malicious writer that controls the World object or both policy and source state is not authenticated by a Python tuple.

## Conditional infinite-family ownership lemma

For **every** accepted initial tuple/list of exact Python integers `(a,b)` (unbounded as mathematical integers, within the specified model admission grammar), each seeded `Record` installed by `World.start` has a distinct, immutable tuple value `(a,b)`. Consequently any later in-place mutation of the caller-held input list cannot change that World record. The proof is by value-copy construction: Python exact integers and their tuple container do not expose a nested mutable reference, and `replace` allocates a new record. This is a standard ownership/copying invariant, not a new theorem of physics.

Induction extension: for a World created only through `start`, a finite sequence of admitted `commit` and `elapse` calls preserves canonical tuple velocity fields. A successful commit copies unaffected records that already satisfy the invariant and creates its new record with `Intent.next_velocity_q256`, which its guard requires to be a two-element tuple of exact integers. A refusal, historical receipt or `elapse` introduces no records. The induction assumes no external writes to `records` and no hostile direct construction or policy mutation. The existing exact Water inventory/accounting proof remains conditional on those trusted producer assumptions.

## Verification and limits

New deterministic `test_seed_caller_alias_is_owned_before_policy_admission` adds **24** signed policy × owner × vertical velocity cells: 23 admitted seed/prepare/commit controls, one unsigned negative-IN admission refusal; seven malformed nested inputs refused; one direct unowned restore invariant refusal. The module now contains **28 authored test methods**.

A source-independent CPython semantic shadow executed 23 accepted cases, one policy refusal and five malformed nested-value refusals. It reproduced **23/23 old alias exposures** and **0/23** with canonical tuple construction. The shadow is not an execution of the exact published B3 module. No complete B3 28-method module run, native Windows/Linux worker run, real physical-hash parity or engine-level contact check has been performed in this checkpoint. Source and test Git blob identities were read back after publication. A3-style/B4 exact-head replay remains requested before any source-level GO.

Run an independent exact-head Python replay with:

```sh
python3 -m unittest discover -s research/solver-certificates/handoff -v
python3 -m py_compile research/solver-certificates/handoff/handoff_contract.py research/solver-certificates/handoff/test_handoff_contract.py
```

**Cost model:** one new two-integer tuple and one new `Record` per seed, plus constant-shape type/policy admission; `O(initial_records)` construction overhead and no added per-tick or per-transfer allocation. `assert_invariants` adds one exact-tuple predicate per record to its already whole-World research scan; benchmark not measured. The Python reference commit copies all records, so it is not a production hot-path template.

**Explicit unresolved independent issue:** B5's [applied signed-policy custody falsifier](https://github.com/techrote/cybersand/pull/555#issuecomment-6756801337) demonstrates unversioned direct mutation of `World.signed_inertial_world_enabled`. This checkpoint does **not** repair it. Likewise no trusted Rapier sample binding, native worker fence, q256→q16 conversion, source-sink accounting for arbitrary solvers, rollback durability or production authorization is established.

Disposition: mathematical/model-specific conditional seed-alias invariance **GO for independent challenge**; exact-module/runtime and any production integration **HOLD**. No physics laws, simulation defaults, MAT-AUTH, Rapier, worker, physical hash, saved state or protected source altered.
