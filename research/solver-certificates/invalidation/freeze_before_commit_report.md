# B2-REGION-004 — accepted-effect snapshot noninterference (10 November 2026)

**Disposition:** bounded, research-only source-contract repair on Draft PR #556; **GO to independent test/review, HOLD for native admission and performance**. Do not merge or promote any default, worker fence, material or pressure policy on the strength of this report.

## Exact source and preserved negative evidence

- Accepted main inspected for this cycle: `d4b18e7f06839b35c8f6a66195206da0f33c5fa3` (GitHub branch API).
- B2 starting Draft head: `90d87d4611ed09ae034b95f99fa7bc17125cff3e`; original `sparse_fence.py` Git blob: `f20d33ea7ec30be91107a0cdb3248b9358ee2b9c`.
- New `sparse_fence.py` blob: `d8bf5de644f65bacf0bba840ae3182aabc8d7cf6`; independent adversarial test module `test_sparse_fence_witness.py` blob: `b1c8da44f0a5296068bf99f4c9937eea33cb7c0f`. These are the byte identities to inspect and execute, not an assertion that new complete-suite execution has occurred.
- Pre-edit B4 [alias falsifier](https://github.com/techrote/cybersand/blob/1e10420b0970e041c941981ecdb13f29faad6ec5/research/solver-certificates/performance/B4-ALIAS-20261109.md), [B4 correction request](https://github.com/techrote/cybersand/pull/556#issuecomment-6754694627) and [B5 independent corroboration](https://github.com/techrote/cybersand/pull/556#issuecomment-6754758561). The B2 pre-edit implementation kept nested, caller-owned event-list aliases after checking their digest.
- The [B2-REGION-002](scan_floor_report.md) O(N) scan-floor negative result is retained for its original model. The [B2-REGION-003](sparse_fence_report.md) sparse-model high-churn regression is likewise retained. This change does not measure or override either.
- Accepted #470 collider dirty packet, #471 neighbour cursor, #522 PressureFlow optimisation, #406 ballistic Water and #474 opt-in lockstep are not changed. Draft #533 separately explores gas-component cache admission, and B3 [#555](https://github.com/techrote/cybersand/pull/555) separately studies solver handoff. Real source contracts remain in `AGENTS.md`, `docs/architecture/pressure-optimization.md`, `docs/architecture/pressure-flow-v1.md`, and `docs/architecture/shared-workbench-authoring-data.md`.

## Preregistered falsifier and correction

**Falsifier:** after the owner accepts a worker packet at generation `g`, tick `t`, shard `s` with checksum `h`, changing a caller-held nested body/pressure/set/explosion payload must not change the effects committed by that accepted packet. Directly replacing a retained packet with a *different* valid packet/checksum must not silently change its admission witness. A missing shard must still return `BLOCKED`; an invalid completed barrier must refuse atomically.

**Correction:**
1. `Packet.make` copies only finite, concrete list/tuple protocol sources into canonical owned tuples, recursively including body positions, before hashing. `Fence.accept` repeats canonical ownership even for directly constructed `Packet` instances, compares against the supplied digest and retains a separate admission witness. Inputs outside the small admitted grammar refuse before JSON conversion; no unbounded generators or arbitrary object traversal.
2. The final *complete* barrier checks generation, tick, shard, original accepted checksum and current canonical data digest **before** any event reducer or state write. Receipt replacement or witness drift refuses. A successful commit and generation-changing restore clear witness and packet tables together.
3. Fixed-size scalar admission bounds all numeric event/header fields to signed 64-bit; generation/tick are nonnegative; packet shard is at most 3. Up to 24 events per packet and 32 body sites per event are admitted. Model-specific coordinate/material/cross-shard ownership checks still occur before the atomic publish.

**Noninterference lemma (conditional, arbitrary finite admitted traces):** let `C(e)` recursively materialise every admitted event leaf into an immutable tuple tree, with no references to mutable caller containers. Let the owner accept a packet only if `SHA256(header,C(e))` equals the supplied digest and persist both `C(e)` and the accepted digest. For any finite sequence of mutations that touch *only the caller's old mutable containers* after acceptance, `C(e)` in the owner is unchanged; hence the event sequence that a completed barrier will reduce is unchanged. This follows by structural induction over the bounded grammar (scalar, flat event, body-point sequence, event list). For a packet-table mutation not covered by that lemma, final digest and admission-witness comparison either refuses or requires direct compromise of the *trusted owner* itself.

This is standard copy/isolation reasoning, **not a novel physics theorem, not a cryptographic authentication scheme, and not a claim that a malicious party cannot mutate the trusted `Fence` internals or their witness table**. It also does not prove the native source's complete worker-effect inventory, asynchronous serialization, crash atomicity or physical correctness. The source model still requires all authoritative producer effects and all nonlocal dependencies to be correctly declared.

## Bounded adversarial experiment and qualification limits

At the original A/B controls, a shallow accepted `["pressure",0]` event was mutated to `["pressure",1]` while its saved digest still bound the former; complete four-shard reduction could incorrectly consume the latter. This precise negative control is retained, not dismissed as a native defect. The new test module directly constructs such mutable packets, changes nested pressure/edit/body/explosion data **after** acceptance, and compares the completed sparse `State` against `full_step` on the original accepted events for both one and four logical shards. It also checks different-checksum packet replacement, illegal direct payload substitution, incomplete barriers, UNKNOWN fallback, rollback, hostile iterables and scalar/footprint bounds.

Reproduction on an exact checkout at the stated blobs:

```sh
python3 -m unittest discover -s research/solver-certificates/invalidation -p 'test_*.py' -v
python3 research/solver-certificates/invalidation/sparse_fence.py
```

**Executed here:** four standalone CPython shadow checks of the new canonical snapshot and final-witness logic passed (1/4 logical shard nested mutation, valid-digest replacement refusal, hostile/unbounded input and incomplete barrier). The shadow was independently reconstructed locally and is **not the actual published `sparse_fence.py` module**. All new repository unit tests were authored and committed, **but complete exact-head execution was not available here**. In particular, the previous 6/6 authored B2 tests and 384/384 state comparisons apply only to blob `f20d33ea...`, not the new blob; this report does not relabel them as new qualification. No native/STEP/Godot/Windows tests or actual worker traces were run.

## Cost, falsification budget and practical limits

| Measure | Prior B2-REGION-003 result (old blob only) |
|---|---:|
| Grid / stage / logical workers | 24×16 / radius-one synchronous two-phase rule / 1 or 4 |
| Opportunities per profile | 64 |
| Quiet rule calls avoided | 24,576/24,576 (100%) |
| Mixed rule calls avoided | 20,960/24,576 (85.29%) |
| High-churn rule calls avoided | 0/24,576 (0%) |
| Mixed / high-churn online abstract cost vs full | 0.590× / **3.089×** (negative) |
| Mixed / high-churn offline false-positive revocations | 86 / 1,363 |
| Mixed / high-churn offline diagnostic probes | 3,680 / 44,495 |

The new admission layer walks at most 24 events and, for each body event, at most 32 coordinate pairs: **768 pairs per packet**, at most **3,072 pairs per four-shard barrier**, before the distinct native-owner and physics work. For `Packet.make` sources, it may canonicalise up to three times (construction, acceptance and final-barrier validation) and hash the canonical JSON up to three times; a direct `Packet` source uses two passes/hashes. Space is linear in the bounded accepted payloads. These counts are *structural upper bounds*, not timing or allocation measurements. Quiet-mode packet handling still incurs overhead even when zero cell-rule calls execute, so the former abstract skip ratios do not justify a total-tick speed claim. A malicious validly shaped but semantically out-of-grid input is refused on final preflight.

## Conservative authority boundary and handoff

- **Missing authoritative shard:** `BLOCKED`, no ordinary or fallback tick.
- **Complete authentic barrier, unknown influence range or gas topology:** full same-law stage, no sleeping certificate.
- **Complete stable barrier, exact local halo and global dependencies unchanged:** potentially reuse a *previously validated pure stage result*; never a blanket World tick skip.
- **Malformed/stale/changed witness or overlap:** typed `REFUSE`, no partial cell mutation.
- **Rollback/restore:** new generation, discard all derived certificates and accepted packets; never treat a historical acknowledgement as a current authorization.

B4 should execute the test module against the exact published head, rerun its independent alias falsifier with expected refusal/unchanged-state semantics, and check bounded hashing overhead separately from material/pressure/gas tick costs. B5 should independently validate the `ImmutableAcceptedEffects` premise in the shared worker-barrier contract and investigate an already-skippable stage instead of a per-cell proof engine. No claim of runtime applicability is admitted without independent source mapping, native exact-state/parity checks, real 1/4 workers and same-host A/B/B/A including allocation/RSS and tail time.

**Final research disposition: GO to independent source/test review; HOLD for production, universal dependency cones, general sleeping, native speedup and physics admission.**
