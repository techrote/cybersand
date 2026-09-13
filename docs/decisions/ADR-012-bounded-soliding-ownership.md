---
title: ADR-012 - Bounded soliding ownership and transition fence
status: Approved design
document-kind: decision
scope: Accepted isolated manual-step diagnostic design; no production soliding or asynchronous dynamic handoff
canonical-for: [decision-soliding-ownership]
last-reviewed: 2026-09-13
related-documents: [ADR-001-native-simulation-core.md, ADR-007-rigid-body-cellular-coupling.md, ADR-010-failed-tick-quarantine.md, ../operations/soliding-experiment.md]
---

# ADR-012: Bounded soliding ownership and transition fence

## Decision and scope

After 130 Stage A cases, stationary-proxy evidence and an independent fresh Sol
High challenge, Astra admits one isolated near-rest dynamic proof. This decision
was recorded before dynamic implementation. Implementation outcomes and review
repairs remain in the [dated evidence](../audits/2026-09-13-issue-12-soliding.md).

Only an explicitly requested authored Wall rectangle, initially 8x8 or 8x14,
qualifies: complete same-material face membership, exact rectangular geometry,
packing 1, actual bottom support and 300 consecutive healthy included observed
ticks. The selected candidate must match the source rectangle exactly; another
candidate cannot authorize it. Rest resets on relevant payload/temperature,
activity, topology, support, mask, exclusion, failure or observation-gap witnesses.
Loose powder, granular/braced Stone, Water/liquids, mixed material, holes, seams,
necks, arbitrary contours and automatic promotion are excluded from dynamics.
Stationary exact row geometry can represent holes while cells remain authoritative;
it does not assert structural strength, fracture or collapse.

This is a scoped experimental exception to ADR-007's ordinary rigid-body material
remaining in the grid. It is a rare fenced ownership transition, not its rejected
erase/simulate/restore collision scheme each tick. ADR-001 native authority is
preserved. No #18/#20 motion carrier or human H preference is assumed.

## Owners and lifetimes

A native `soliding::Session` exclusively owns its private World, fixed material
slot, transaction phase and witnesses. No mutable World escapes. The Godot wrapper
rejects calls away from the main thread and permits configuration once on a virgin
object. A main-thread coordinator owns an isolated inactive Rapier space and all
body/shape RIDs. Internal native workers may execute ordinary ticks and call no
Godot APIs. Dynamic desktop worker handoff and production snapshot integration
are Deferred until an explicit rendezvous implements this protocol.

| Phase | Sole material owner | Geometry meaning |
|---|---|---|
| Cells | Native cells | One static representation, no active aggregate |
| PromotionPrepared / PromotionAcknowledged | Source cells | Copied payload and disabled body own nothing |
| PromotionCommitted awaiting topology | Native slot | Both solvers remain fenced |
| Aggregate | Native slot | Rapier owns transform/velocity/angular state/contact; endpoint mask is descriptive |
| ReversalPrepared / ReversalAcknowledged | Native slot | Reserved destinations and disabled static replacement own nothing |
| ReversalCommitted awaiting topology | Native cells | Both solvers remain fenced; slot no longer owns |
| Quarantine | Last committed owner | No steps or ordinary publication; census is diagnostic only |

The wrapper exposes no mutable fixture edit after topology setup; its edit request
explicitly refuses. Native fixture edits are test/setup operations before a Rapier
coordinator exists. There is no event queue: accepted synchronous setup finishes
before capture; paint/explosion/heat/chemistry requests are rejected while pending
or Aggregate. No silent event loss or unbounded deferred queue is claimed.

## Payload, identity and capacity

One slot, one proposal and fixed 224-entry payload/destination arrays; initial
accepted membership is 64 or 112 cells. One exact rectangle collider is used, with
no registry expansion beyond the ordinary 16-body bound. The whole isolated
128x128 region and optional temperature storage are reserved before transitions;
mask scratch holds 1024 entries. Preflight failures refuse, never truncate.

Preserve actual `(material,state_a,state_b,temperature)` and local membership.
Promotion leaves canonical Empty `(0,0,0,ambient)` at every source. Reversal
requires canonical Empty destinations, including stored heat beneath the body's
own mask; there is no implicit thermal merge. Compact state uses existing widths,
not new generic fields. Epoch is scheduling metadata: reconstructed cells receive
the current epoch and fresh dirty/activity witnesses. Water is ineligible, so no
Water-quantity transfer is claimed. No exact continuation promise.

A process-wide native atomic allocator issues a nonwrapping incarnation outside
replaceable World state. The exact seven-integer token is incarnation, transition
generation, packed patch-registration/candidate ID (high/low 32 bits), candidate
revision, direction, payload digest and topology epoch. Generation/topology
exhaustion refuses rather than wrapping. The private slot/phase plus exact token
binds a proposal; the digest is an integrity witness, not a cryptographic identity.
Ordinary wrapping float-packed body samples never acknowledge transitions.

## Prepare / acknowledge / commit / finalize

Both solvers stay behind one explicit no-step fence during the entire transition.
No ordinary asynchronous terrain cache or pending input is involved.

1. Capture the exact selected source candidate or exact reversal destinations.
   Validate world health, inclusion/halo, complete membership, capacity and tuple
   witnesses. Source cells or the slot retain ownership throughout preparation.
2. Main thread prebuilds disabled replacement body/shape resources in the inactive
   space. Validate RIDs, shape count and space before acknowledging the exact token.
   Reversal is symmetric: replacement static terrain exists before ACK.
3. Exclusive native commit rechecks phase/token, health, inclusion, resident
   cell/temperature storage and source/destination tuples. A specialized private
   `noexcept` bulk writer performs only bounded resident writes and dirty/activity
   accounting. The logical owner changes once under the fence; intermediate
   writes are not solver-observable. No concurrent memory-atomicity claim.
4. **Only a confirmed native commit** permits collider layer switching. Disable
   obsolete source/dynamic contact and activate the prepared replacement. Promotion
   also installs a complete endpoint mask. Verify the owner/collider census, then
   finalize and resume. No step sees both stale static and dynamic contact or a gap.
5. Any precommit construction/ACK/commit refusal cancels and disposes only disabled
   resources, preserving the old material and collision representation. Cancellation
   is precommit only. Stale/duplicate operations cannot change the phase or owner.
6. Unexpected postcommit topology failure or a failed native tick enters Session
   quarantine, which is distinct from `World::has_failed()`. Retain the last
   committed owner and fence; no rollback, payload deletion or in-place retry.

Final Aggregate census: source canonical Empty; exactly one active aggregate
rectangle; obsolete source static contact disabled; floor present once; complete
occupancy. Final Cells census: restored material once, aggregate collision/mask
retired, one static replacement and one floor. Disabled retained RIDs own neither
material nor active collision. The aggregate's dedicated coupling role is Rapier
hard contact only: no generic #11 cellular bearing/correction is also applied.
Ordinary #11 support remains accepted solely in its documented rectangle/load
envelope and receives separate preservation tests.

## Occupancy, region and recoverable deferral

Rectangle-cell-centre endpoint rasterization reports required, written and conflict
counts. Check the whole rotated bounding box plus two-cell halo against included
coverage and the finite prepared region. Reject unrelated occupancy/material and
out-of-bounds placements; never silently clamp or partially admit a mask. This is
an endpoint approximation, not swept geometry, arbitrary-shape support or broad CCD.

A bounds/conflict preflight refusal is a **recoverable fenced deferral**: no mask
writes, material transfer, native tick or Rapier step occurs. The prior mask/payload
remain retained; a caller may revalidate a legal endpoint while still fenced.
An unexpected partial write or postcommit topology failure quarantines instead.
The diagnostic coordinator uses the same checked step gate on ordinary motion and
re-entry; failed mask/native tick returns before calling Rapier.

Exclusion pauses the entire isolated space and native owner before applying the
excluded state. Retain direct-server transform/velocities and payload; no rest is
earned. Re-entry validates occupancy and restarts the 300-observation body rest
window with actual simulation steps. Other bodies, partial streaming and general
reactive aggregates are Deferred.

## Units, controlled motion and reversal

Units are cells/pixels, seconds and radians. Per-cell mass 1/112 yields 8x14 mass 1
and 8x8 mass 64/112. Centre of mass is the rectangle centre; inertia is
`m*(w*w+h*h)/12`. Collision geometry error is zero for these rectangles; raster
occupancy is approximate. The proof uses controlled relocation/quarter-turn setup,
then real Rapier falling/contact and settling. It makes no general torque or CCD
claim. Promotion starts at zero velocity under the explicit rest screen because
cells have no generic velocity to recover.

After stepping is suppressed, take a direct PhysicsServer sample and require
finite values, speed <=0.05 cell/s, |omega| <=0.005 rad/s, quarter-turn error
<=0.001 rad and grid alignment <=0.01 cell. Reject energetic/nonaligned placements;
no universal cell velocity or #18/#20 carrier is invented. Record snap corrections,
per-member speed bound `|v|+|omega|*radius` and discarded kinetic energy.

For q=0,1,2,3, positive clockwise with screen y-down, map local `(i,j)` to `(i,j)`,
`(h-1-j,i)`, `(w-1-i,h-1-j)`, `(j,w-1-i)` in the integer lower corner of the rotated
rectangle. Bounded coordinates, N unique destinations and exact tuples are checked
before any write. No per-member rounding or overwrite. The asymmetric 8x14 case
must exercise 90-degree reversal; repeat cycles and compare exact mapped tuples,
counts, sole-owner census and material-state-temperature accounting.

Damage/stress/heat/chemistry triggers do not silently fracture the moving payload.
They are refused in this proof; automatic dissolution, splitting, merging,
structural failure and energetic reversal require a later explicit design. A
blocked/hot/full/invalid reversal retains the whole aggregate and reports refusal.

## Persistence and teardown

CYSD1 has no aggregate schema. The wrapper has no import/export implementation;
its persistence admission query refuses pending/Aggregate/excluded/quarantined
states. Cells-only export integration is Deferred; there is no hidden omission or
mask-clearing export path. The wrapper cannot reconfigure an existing Session.
Whole-experiment teardown first retires its isolated RIDs/space, then releases the
Session; constructing a new wrapper obtains a fresh incarnation. This explicit
abandonment is not save/load continuation, rollback or replay.

## Independent challenge and admission disposition

Sol's named missing prerequisite was a durable transition-owner state machine.
Astra resolved the four architectural forks: private native Session plus manual
main-thread coordinator; explicit event rejection; canonical Empty heat; whole
isolated-space exclusion. Sol's remaining token, preflight, topology symmetry,
coupling, occupancy, direct-sample and quarantine findings became required
invariants above. Astra retained final authority and admitted this scope before
implementation. Subsequent Terra implementation findings and delta verification
are recorded in the dated evidence, separately from design acceptance.

**G-R admits this one-slot isolated proof only.** No production representation
ladder, generic motion, #18/#20 implementation, human H result or G-final selection
follows from it. A successful bounded result can inform #14; production/asynchronous
integration remains Deferred.
