---
title: B3-RESEARCH-7 — same-generation World clone and cross-incarnation handoff intent
status: Experimental / Draft HOLD; conditional lemma selftested, exact published model replay pending
document-kind: research-evidence
scope: B3 source-typed handoff model only; no production/native admission
last-reviewed: 2026-11-10
---

# B3-RESEARCH-7 — same-generation incarnation collision

## Source baseline and preregistration

- Accepted CyberSand main: `d4b18e7f06839b35c8f6a66195206da0f33c5fa3` (rechecked 10 Nov 2026). Root `AGENTS.md` blob `d12d9d07101b7f7bc734835cf4b4b7849fca16d8`.
- Existing [B3 Draft #555](https://github.com/techrote/cybersand/pull/555) before this increment: `f30a002ca08910e4a711692863471f56756e1cf2`. Reviewed `handoff_contract.py` exact blob `e8176a1a2a63fdd3edc1b097cf47647a20ff34bf` (374 lines). This increment does **not** change that implementation.
- [Preregistered falsifier](https://github.com/techrote/cybersand/pull/555#issuecomment-6759100353), before edits.
- Already merged [#470](https://github.com/techrote/cybersand/pull/470), [#471](https://github.com/techrote/cybersand/pull/471), [#522](https://github.com/techrote/cybersand/pull/522), opt-in ballistic [#406](https://github.com/techrote/cybersand/pull/406), opt-in lockstep [#474](https://github.com/techrote/cybersand/pull/474). None supplies performance evidence for B3. [#361](https://github.com/techrote/cybersand/issues/361) and [#362](https://github.com/techrote/cybersand/issues/362) retain separately owned tool/spray concerns. Current main selects one immutable liquid solver family per material per World. [B2 #556](https://github.com/techrote/cybersand/pull/556) and [B4 #554](https://github.com/techrote/cybersand/pull/554) are independent Draft research sources.

## Source-critical negative construction

The model exposes `World.start(generation, records, *, signed_inertial_world_enabled=False)`; `generation` is caller-supplied. `prepare` copies generation, epoch, source snapshot, applied policy and token, but **not independently authenticated World-instance identity**. `commit` checks the receiving World's generation/epoch/source/policy and its **local** accepted-token map. Its `material_identity()` hashes state, not verified incarnation identity.

Construct two distinct `World.start(3, [Record("water", Owner.FREE_MASS, 256)])` instances A and B with equal starting generation, epoch, applied policy, source record and `material_identity()`. Prepare one `FM -> BALLISTIC, 256` intent *only on A*. Commit it on A. Since B has an independent empty accepted-token map and identical guard fields, the same intent also satisfies B's commit guards. Conversely, a World with generation 4 refuses `BAD_GENERATION`, and one with a different signed-IN policy refuses `POLICY_DRIFT`. Same-World replay remains `HISTORICAL_ACK_ONLY`. The attached `--exact` mode makes these assertions executable against precisely the pinned B3 implementation Git blob and refuses source drift.

This attacks **cross-World authorization**, not the local conservation proof: both Worlds separately conserve their 256 Water units and each has a single Water owner. It does **not** establish a defect in actual native World, which may provide stronger incarnation and worker fencing than the Python abstraction. A B3 receipt is not a native parcel-spawn permit.

## Conditional law over an infinite identity family

Suppose an external trusted owner assigns each simultaneously live World incarnation W a distinct immutable ID `inc(W)`. Bind the prepared intent's ID to its source World and require `inc(intent) == inc(target World)` on admission, with UNKNOWN/blank refusing. For any two distinct live incarnations A and B, injectivity implies `inc(A) != inc(B)`. Therefore, **an A-prepared intent cannot authorize a B commit**, independent of the number of records, integer quantities, contact class or handoff sequence length. This is elementary established namespace/equality reasoning, not a new theorem in computational geometry or a proof of runtime identity allocation.

The same-ID spoof negative control remains permitted by bare equality; unique **trusted allocation/rollback custody** is the missing premise. Neither the caller-supplied generation nor an identical physical-state hash alone establishes that premise. Restore may require either a new incarnation or an authenticated continuation lineage; owner policy must choose.

## Deterministic experiment and qualification

```sh
python3 research/solver-certificates/handoff/incarnation_collision_probe.py --selftest
# From the exact checked-out B3 #555 parent module:
python3 research/solver-certificates/handoff/incarnation_collision_probe.py --exact
```

Local CPython standalone `--selftest`: **2,050 deterministic checks PASS** (512 distinct-incarnation refusals, identical-incarnation controls, wrong-generation/source guards, same-ID spoof negative and blank-ID refusal). `py_compile`: PASS. Published checker Git blob `63bfd726d646b81f3b3a7cac5ce6904e60e5cbdf` independently matches the locally executed file. These checks test the **conditional guard**, not the full existing B3 module. **`--exact` against the published module remains NOT RUN**; prospective expected trace is not claimed as a run result. No native/Godot/Windows tick, physical hash, worker participation, Rapier contact/impulse, persistence or runtime benchmark was performed.

Proposed overhead: a fixed-size incarnation value in a prepared command/receipt and an O(1) compare at the *bounded command boundary*, not a per-cell hot-path proof. Unique allocation, checkpoint continuity and invalidation overhead is unmeasured. No production speedup claimed. B4's actual full-host A/B/B/A cost gate still applies.

## Review disposition and one next seam

**GO**: conditional abstract cross-incarnation non-transport lemma and selftest.

**HOLD**: exact pinned-module replay, authentic native applied-policy/incarnation/worker fence, rollback/restart continuity, and production consumption. B2 should invalidate derived ownership/region certificates across restoration and incarnation changes; B4 should run the `--exact` case plus distinct native-world A/B/A rollback scenarios; B5 should never treat B3 `COMMITTED` or `HISTORICAL_ACK_ONLY` as a native action permit.

**Single highest-value theorem/engineering seam:** an owner-issued, independently verifiable native World incarnation/continuation witness with explicit restore/rollback revocation rules. No change to protected World, pressure, MAT-AUTH, native hash, Rapier, worker fences, save state, default materials or any other research subtree.
