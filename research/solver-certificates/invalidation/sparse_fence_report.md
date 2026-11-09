# B2-REGION-003 — fenced sparse change-stream experiment (9 November 2026)

**Disposition:** independent research candidate, Draft/HOLD; not a native performance result, accepted CyberSand physics, or authority to skip a World/PressureFlow tick. No production/default/source-policy changes.

## Source identities and preregistered falsifiers

- Accepted main at experiment start: `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`.
- Prior B2 research head: `2c3fe265427ddcc0014f689b31abffb04a49f270`. The B2-REGION-002 negative finding (mandatory full-grid snapshot, copy and comparison) remains valid for its original `Cached.step` implementation.
- New implementation: [`sparse_fence.py`](sparse_fence.py), source Git blob `cb7350d8d78d5a64da691f8b931d674aebcc45f3` (locally executed file **exactly matches the published blob**).
- One finite adversarial experiment: 24×16 cells; 4×4 tiles; 64 transition opportunities/profile; deterministic seed; quiet, mixed and UNKNOWN-every-tick; 1 and 4 *logical*, sequential shard receipts.
- Falsifier: any unequal full-reference vs sparse `State` after any committed step; incomplete shard receipts incorrectly permitting a step; stale generation/epoch, duplicate or tampered packets accepted; conflicting cross-shard writes admitted; or a wrongly retained tile after local, global, body, phase or rollback change.
- Test: `python3 research/solver-certificates/invalidation/sparse_fence.py` from repository root (Python 3.13+). On local CPython 3.13.5, all **5/5 unit tests passed** and all **384 profile/tick comparisons** (3 profiles × 2 shard settings × 64) passed, using full dataclass equality, not hashes alone. Main/test/runtime provenance is **local Python only**; no hosted CI, native or graphics execution is claimed here.

## Exact bounded claim

The existing B2 proof shows that a two-phase fixed-point certificate can skip a pure synchronous stage while *all* local read-halo and global input dependencies retain their admitted values. This new implementation tests an additional operational condition: **no staged result, including a conservative full recompute, may be published while any authoritative producer shard for its tick is missing**.

For a finite grid, a pure deterministic synchronous radius-1 stage `F_p`, a complete finite event stream `E_t`, exact event witnesses and globally versioned external inputs, partition event receipts by distinct shard at owner barrier `(world_generation, tick)`. A complete set is first validated, reduced in the agreed deterministic order, then its local input and global influence dependencies are invalidated. Evaluate *only* active tiles into a sparse write set; all reads happen before any stage writes commit. A certified tile is retained only if its full two-phase read set and global inputs were unchanged. Invalidate affected radius-1 tile halos after every committed producer and stage write; restore starts a new generation and discards all proofs.

**Induction (all finite grid sizes, lengths and admissible traces, not merely the six fixtures):** complete source-barrier reduction makes the sparse and full reference pre-stage input identical. Every active cell evaluates the same `F_p` against that input. A retained cell is certified fixed for both phases, and its read and external inputs have not changed, so its output equals its current value. Sparse write publication therefore equals simultaneous full publication. Recording every changed read input and discarding proofs on global/unknown changes preserves the induction invariant for the next transition. A missing shard invalidates the premise of identical authoritative input: the correct outcome is **BLOCKED**, not `UNKNOWN=>RECOMPUTE` against stale input.

This is standard deterministic dependency-closure reasoning, **not an original universal solver theorem**. It is valid only for the declared pure synchronous stage and complete/authentic producer witnesses. For a *complete* barrier with unclassified stage dependency, `UNKNOWN=>FULL RECOMPUTE`; for an *incomplete* barrier, `BLOCKED/REFUSE`. This distinction matters for native worker and Rapier publication fences.

## Results — standalone abstract counts, not wall-clock units

| Profile | Full rule calls | Sparse rule calls | Avoided | Online recert + halo + calls | Initial proof calls | False-positive revocations* |
|---|---:|---:|---:|---:|---:|---:|
| Quiet | 24,576 | **0** | 100.00% | **0** | 1,536 | 0 |
| Mixed | 24,576 | 3,616 | 85.29% | **14,510** (0.590×) | 965 | 86 |
| Churn / UNKNOWN each tick | 24,576 | 24,576 | **0%** | **75,922** (3.089×) | 965 | 1,363 |

Identical rule, recertification and halo counts were obtained with 1/4 logical partitions. The event-driven path uses no full-cell output copy or full-cell changed-state comparison **per tick**: it traverses active tiles, supplied event sites and their read halos. An initial O(N) proof is still necessary, and a global fallback traverses all tiles. Every step still incurs packet production, JSON digests, barrier accounting, Python allocations and sparse bookkeeping **not priced in the abstract totals**. Each logical 4-shard step requires four packets instead of one. The oracle's full-grid comparison, snapshots and rollback are test-only; the algorithm's tests require them, but a proposed consumer would not run them in a hot path. No measured memory, allocation, p50/p95, Godot/native worker or speedup claim follows.

*Independent diagnostic runs (not part of online cost) recertified revoked tiles and counted 86 mixed / 1,363 churn revocations that would still pass the *immediate* fixed-point test. Their additional 3,680 / 44,495 rule probes are excluded from the table, and not evidence that those invalidated source assumptions were admissible to retain. Churn's 3.089× abstract cost is a retained **negative result**.

The 64 opportunities include a snapshot at opportunity 31 and a full rollback to it before opportunity 44, so the final state tick is 51; no skipped experiment opportunities are hidden.

## Distinguishing falsifiers and CyberSand source constraints

- **Missing producer:** in the explicit four-shard negative control, shard 3 owns a remote pressure change; shards 0–2 alone leave the model's water unchanged. Treating this incomplete input as authority diverges from the complete full oracle (Water→Steam). Proper fence leaves the state/tick unchanged until all four receipts arrive.
- **Sided contact, seams, identity:** body-mask release across a 4×4 tile edge must revoke its neighbour. Phase-dependent Sand transport then matches the oracle. ABA writes, explosion, pressure, reaction, UNKNOWN and rollback are covered in the deterministic tape; stale-generation, duplicate, altered payload and cross-shard double-write receipts are refused.
- **Trusted source limitation:** a self-calculated SHA-256 is only a corruption sentinel here, **not authentication**. In production the packet must originate from native World / the exclusive worker owner, with a trusted World generation, applied policy, tick and complete effects. Malformed/capacity-failing payload handling in this sketch is not a transactional native input contract.
- **Native stage mismatch:** accepted [`pressure-optimization.md`](../../../docs/architecture/pressure-optimization.md) already permits skipping **only Water pressure motion**, not lifecycle, chemistry, contact impulses or gas/pressure preparation; any 5×5 body mask declines that proof, and remote gas table changes revoke Water certificates. [`world.cpp`](../../../native/src/world.cpp) owns `merge_job_effects` and input invalidation at phase barriers; [`world_pressure_cache.inc`](../../../native/src/world_pressure_cache.inc) accounts certificate work after worker reduction. Real phased in-place, side effects, dynamic actors and bounded gas discovery are not this synchronous Python automaton.
- #470 hard-surface packets, #471 neighbour cursor, #522 PressureFlow fastpaths and Draft #533 per-component caching retain their accepted/independent roles. #406 ballistic Water, #474 opt-in lockstep and B3 handoff do not supply a source-authenticated input receipt for this model. No native proof stage or production code is modified.

## B4 and B5 independent handoffs

**B4:** first source-audit native owner-fence completeness and whether any already-skippable *stage* can consume O(touched) invalidation without an O(N) discovery pass. Preserve the **high-churn 3.089× rejection**; do not equate Python abstract units with CPU time. Any real deployment requires same-host A/B/B/A, physical hash/quantity/gas/contact exact parity, 1/4 **actual** workers, p50/p95, allocations/RSS and wrong-wake/rollback controls.

**B5:** consider a typed `CompleteOwnerBarrier(generation,tick,worker-set,effect-witnesses)` distinct from `DependencyUnknown`. Only the former permits either certified reuse or same-law full fallback. Incomplete/mismatched authority **blocks/refuses**; an old/duplicate receipt must not authorize a later tick. Research-only interface discussion, not a production authorization. Request independent review of whether the full native effect and side-effect inventory can ever satisfy the theorem's read-domain and atomic-barrier assumptions.

**Disposition:** bounded model GO for review; native applicability and performance **HOLD**. Retain the original B2-REGION-002 full-grid-scan negative result and this experiment's high-churn negative result.