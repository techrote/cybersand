# B3-RESEARCH-4 — signed-IN initial-state admission and explicit restore validation

**Date:** 2026-11-10. **Disposition:** GO for the conditional research-model invariant; HOLD for independently replayed full source tests, actual native handoff/restore qualification and any production consumer.

## Exact source / baseline

- Accepted `main`: `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`.
- Previous B3 Draft head: `acf7ce6e14bd7b0e46f61e308d1b42a8867829d8`, original model blob `fd389750d19a05d740e3f8894af514314d590780`.
- Corrected model blob: `523810bee1d9b219a421557181ecae108d222ef2`.
- Corrected tests blob: `fd88ac60ab08f20a2a0b4d442f52d9117d61ee18`.
- Standalone checker blob: `b53f8179d337ae4bb21ef2a7bd6cf3b78d81f852`. A byte-identical local CPython 3.11 script ran successfully in `--selftest` mode.
- Independent B4 source-critical seed challenge: [#555 comment 6755672772](https://github.com/techrote/cybersand/pull/555#issuecomment-6755672772), [B4 report](https://github.com/techrote/cybersand/pull/554).
- Native source constraints consulted: `native/include/cybersand/world.hpp`, `native/src/world.cpp`, `native/src/world_inertial.inc`, `docs/architecture/inertial-cellular-v1.md`, `docs/architecture/ballistic-water-v1.md`, `docs/architecture/pressure-flow-v1.md`, current worker/lockstep and physical-state authority. #470/#471/#522 are accepted performance work; their bounds do not qualify this research model. #361 remains an opt-in equipment lane; #362's ballistic work is not an authorization for dynamic arbitrary materials.

## Preregistered falsifier and original negative result

Original `World.start(3, [Record("water", Owner.INERTIAL, 256, velocity_q256=(0,-8))], signed_inertial_world_enabled=False)` **admitted** a negative-vy IN seed, despite `commit()` refusing an unsigned negative-vy IN destination. The old `assert_invariants` checked IN amount but not signed velocity. B4 independently demonstrated the gap with source-faithful controls. It is an **abstract model initial-state admission defect**, not evidence of a native CyberSand bug or a failed Water quantity-conservation theorem.

## One bounded change

`inertial_seed_admissible` is a research predicate. A non-IN record is outside its scope; an IN record requires exactly one 256-quantum cell, two integer velocity components, and either nonnegative vertical velocity or a World-construction-bound signed-law opt-in. `World.start` refuses unsupported IN seeds. `World.assert_invariants` applies the same predicate, enabling explicit validation of a restored World before it may be used. `MODEL_VERSION` advances to B3-RESEARCH-4. No existing caller default or native law changes.

The rejection does **not** normalize bad seeds, fabricate momentum, infer a valid applied material policy from a caller flag, authenticate body contact, or change an existing accepted transfer.

## Conditional safety law (unbounded finite sequence length)

Fix a World whose records are created through `World.start`, with a construction-bound signed-law boolean, and changed **only** by the model's `commit`, `elapse` and `record_contact`. For any finite sequence of those operations, every surviving IN record remains exactly whole-cell; and if the World signed-law option is false, its IN vertical velocity remains nonnegative.

Proof by induction: `start` establishes the predicate. `elapse` and `record_contact` do not rewrite records or the option. Refused commits do not rewrite them. A committed transfer preserves unaffected records; whole-cell/partial-IN guards forbid invalid IN quantities; and a new negative-vy IN target is refused unless both the caller request and World signed-law capability permit it. Candidate `assert_invariants` is checked before the atomic swap. Thus every committed successor preserves the property. This is an elementary state-machine invariant, **not a new physics theorem**; the resource limit `MAX_TX` and model capacity may refuse otherwise valid long traces.

For an untrusted direct construction, a saved-state restore, a direct mutation of `records` or a policy flip, this theorem's transition premises do not apply. `assert_invariants` detects the exhibited unsigned IN seed and a forged policy downgrade **when actually called**. A mere `World(...)` dataclass constructor has no implicit authentication; restored data must pass explicit validation and a trusted native policy/source receipt.

## Deterministic qualification

`python3 research/solver-certificates/handoff/seed_policy_adversary.py --selftest` ran locally: **38/38 independent predicate controls PASS** across signed/unsigned policies, 14 vertical velocities per mode, malformed velocities, fractional IN and non-IN controls. The locally executed checker Git blob matches the published blob exactly. `python3 -m py_compile` also passed for that checker.

`python3 research/solver-certificates/handoff/seed_policy_adversary.py` is designed to **refuse** an unpinned model blob, then load and execute the actual published B3 module: 36 source-model seed/restore cases plus 38 independent controls. This mode, and the expanded `test_handoff_contract.py` suite (27 authored test methods), are **NOT EXECUTED** in this environment; do not report their results as pass. The exact-model check requires a checkout containing blob `523810bee1d9b219a421557181ecae108d222ef2`. Any subsequent model edits require deliberate pin refresh and independent replay.

No native/Godot execution, real Rapier sample, CYPS4 restore, exact physical-hash/quantity-ledger parity, 1/4 actual worker trace, full suite or same-host A/B/B/A was conducted.

## Cost and limitations

The additional `start` predicate is constant work per initial IN record; `assert_invariants` adds one fixed-size check per record and executes as part of the model's existing O(N) validation. The normal research `commit` already copies/scans O(N) records. No hot per-cell production hook has been added, and **no native time, allocation or tick benefit is measured or claimed**.

Native IN velocity is encoded in q16 with additional physical bounds; this abstract research model labels its momentum/velocity q256 and checks only the vertical sign and integer representation. Even signed model seeds therefore do **not** establish native range, unit or saved-state validity. Source provenance, same-value ABA, forged contact producers, aliasable nested token fields, stale source-policy readbacks, duplicate cached `COMMITTED` receipts and true native restoration remain separate open falsifiers. B2's stable-packet/epoch contract and B4's physical/parity fixture are required before an opt-in consumer could be considered.

## Requested independent qualification

1. **B4:** run the exact checker (without `--selftest`) and `python3 -m unittest discover -s research/solver-certificates/handoff -v` on this precise model blob; extend counterexamples to direct restored state, poisoned signed-policy receipt and signed q16 overflow without treating them as same unit domain.
2. **B2:** classify absent trusted owner policy, mutation-generation, immutable contact or complete barrier as UNKNOWN/BLOCKED; never use a model constructor flag as a current worker fence.
3. **B5:** keep handoff admission HOLD until trusted World-source hashes, applied-policy/physical identity, body sample, rollback/restore and run-time cost are independently established; keep this artifact additive and research-only.

The experiment changes only `research/solver-certificates/handoff/**` on existing Draft #555. There is no claim of solver-family switching, universal conservation, production authorization or native physical correctness.
