# #12 / #20: singular-ownership protocol preparation

**Executed finite abstract-model checks; no engine implementation, admission or ownership ADR.** [Repository constraints and external references](primary-sources.md) remain distinct.

## What was modeled

Two identifiable material units start cell-owned. Pool capacities of one and two slots are explored separately. Each unit has six phases: cell-owned, promotion-prepared, promotion-acknowledged, pool-owned, return-prepared and return-acknowledged. The owner bits are deliberately separate from protocol phase, so the checker can detect a protocol that releases or duplicates material at the wrong time.

Promotion reservations consume pool capacity but do not own a second copy of material. Return preparation leaves pool ownership in place. A full destination does not discard the payload. Revision changes invalidate pending acknowledgements/commits; revisions 0..2 do not wrap. Cancellation releases only the reservation. Quarantine is absorbing: automatic retry/reset is not modeled or introduced into the failed-world contract.

The invariants require exactly one owner per unit, owner/phase consistency and capacity including reservations. A stale promotion acknowledgement is a separate checked violation. The model's transitions are atomic abstract actions. They are not a claim that a multi-cell C++ mutation or a cross-thread Rapier handshake is already atomic.

## Results and retained counterexamples

| Capacity | Depth 10 states / transitions | Extended states / transitions | Extended graph closed? |
|---:|---:|---:|---|
| 1 | 1,328 / 3,620 | 1,368 / 3,768 | Yes |
| 2 | 4,601 / 14,181 | 7,200 / 23,640 | Yes |

The registered extension used depth 64 and a 60,000-state ceiling. Neither bound was hit in the extended models. No safe-model invariant violation was found. This means all reachable states of **these finite models** were explored; it says nothing by itself about unbounded revisions, C++ memory ordering or an implementation not modeled.

Four deliberately broken variants produce short reviewable failures:

| Broken rule | Retained shortest trace | Failure |
|---|---|---|
| Release source during reservation | prepare promotion | Material has no owner |
| Keep both owners at commit | prepare, acknowledge, commit promotion | Material is duplicated |
| Discard on full return | block destination, prepare, acknowledge, commit promotion, fail return | Pool payload is lost |
| Accept stale acknowledgement | prepare promotion, edit revision, acknowledge promotion | An invalidated preparation is accepted |

These mutants demonstrate that the checked properties are capable of detecting the named bugs. They do not establish test-suite adequacy for all implementation errors. The complete traces and bounds are retained in the generated JSON.

## What this model deliberately does not prove

Destination-free flags are independent per unit: a shared destination allocator, two returns contending for the same cell and cross-region reinsertion are **not** modeled. Pool slots are capacity-counted, not individual generation-tagged addresses. There is no queued/delayed duplicate message delivery, generation wrap/ABA reuse, multi-cell aggregate shape, topology change, frame transform, sweep, force, torque or material reaction.

The two bounded revisions can detect stale preparation, not prove arbitrary request-ID lifetime handling. Liveness is also absent: repeated cancellation, blocked destinations or starvation can persist. The safety/liveness distinction is an important reason to retain explicit scope; Lamport's published specification material is a reference for subsequent formalization [S5], not a tool used by this Python exploration. TLA+/TLC was not executed.

## Implementation obligations before either representation handoff

Use engine-owned payloads and explicit request/world/body generations. A main-thread physics proxy should not become active merely because storage was reserved; collision-proxy activation and material ownership are separate obligations. Reject stale acknowledgement after source edit, reset, object replacement or region change. Cancellation must also retire any uncommitted proxy through its owning thread.

Before releasing cell authority, validate and reserve all bounded resources needed for a non-throwing commit path. Current tick failure is not a rollback transaction. A proposed aggregate transaction cannot assume that a later exception restores source cells, nor retry automatically in a quarantined World. Its failure inventory and last valid publication must remain identifiable.

A return must check the intended destination at commit, not merely at preparation. Keep the moving/aggregate payload when reinsertion cannot complete. Specify backlog priority, bounded retries, overflow outcomes and fairness separately from exact ownership. A full-pool admission refusal leaves the source intact. Mixed success across a multi-cell aggregate needs a deliberate all-or-bounded-partial ownership policy, not ad hoc deletion.

For #12, face connectivity, holes, loose-pile exclusion, membership versioning and near-rest versus energetic return still need the reviewed ownership design. The source-backed #10/#11 support boundary also remains. For #20, the issue's bounded pool/sweep/reinsertion limits do not demonstrate a motion need. #18/G-M and its own G-B admission remain prerequisites.

## CCD is not a universal repair

Rapier's official guide describes nonlinear CCD with motion clamping for fast-moving bodies, considering angular and translational motion [S6]. This is useful context for swept-collision design, not evidence that CyberSand's adapter applies it to cellular destinations. It does not supply persistent granular bearing, source feedback or an ownership transaction. Slow sinking into a granular bed and high-speed tunneling require different measurements; do not “fix #11” by simply turning on an unrelated fast-motion feature.

The smallest further design test is an explicit shared-target reservation model with generation-tagged slots and delayed messages, followed by implementation-specific failure injection after an ADR/admission permits code. That remains a proposed follow-on, not a hidden claim that this bundle has implemented reversible soliding or sparse ballistics.
