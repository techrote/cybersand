---
title: Issue 12 Stage 3B parent architecture decision
status: Approved design
document-kind: decision
scope: Supervising-parent disposition for Stage-3B locality/scalability after the read-only architecture review
canonical-for: [soliding-stage3b-parent-decision]
last-reviewed: 2026-09-19
related-documents: [../operations/soliding-stage3b-production-plan.md, ../operations/soliding-stage3b-astra-review.md, ../operations/soliding-stage3-freeze.md, stage3-exit-review.md]
---

# Issue 12 Stage 3B parent architecture decision

## Decision boundary

This record captures the supervising-parent decision for issue #12 Stage 3B at
repository head `35d03001257e0e2a3f60fa7ce6c9f6774c93e9d7`.

Two independent read-only architecture-review outputs were produced against that
same inspected head and reconciled by the supervising parent. The longer review
is the primary architecture authority; the second is independent corroboration
and contributes bounded refinements. This record does not claim that the
historical dispatch packet's requested exact model identity was confirmed. The
dispatch packet remains truthful historical review input rather than current
execution routing.

Stage 3A remains the bounded correctness/observability reference. Stage 3B is
approved for production implementation decomposition. Stage 4 remains blocked.

## Selected architecture

Proceed with an owner-serialized, change-driven settled-region observer using:

- immediate allocation-free observation invalidation plus deferred maintenance;
- runtime-capacity storage;
- bounded canonical spatial indexes;
- exact local component and revision-bound face data;
- explicit reverse dependency incidence;
- immediate public-generation retirement with bounded reclamation;
- deterministic bounded service/admission;
- resumable exact deletion/split reconstruction;
- certified local/addition fast paths only after the generic exact backend works;
- explicit local, externally blocked and globally closed observation types;
- Stage 3A retained as differential oracle/control.

Cells remain the sole material authority. Discovery remains opt-in/read-only.
No scheduler skip, stationary representation, cohesion, Rapier transfer, fracture
or INT-000 ownership is admitted here.

## Parent dispositions

### P1 — Canonical fairness

Approve deterministic eligible cohorts/admission rounds, retained tickets,
bounded cyclic service and canonical scarce-capacity arbitration. Progress claims
remain conditional on adequate configured capacity, continuing service and a
sufficiently stable dependency interval.

### P2 — Publication digest compatibility

Use a staged policy. Preserve the legacy canonical global fold through the
foundation implementation and charge its whole-sequence work explicitly.
Later, permit a versioned composable diagnostic digest and incrementally
maintained ordered aggregates if differential evidence justifies them. Exact
revisions and dependencies remain the correctness witnesses; hashes are not
connectivity proofs.

### P3 — Absence and coverage semantics

Distinguish at least `NotResident`, `ResidentUntracked`, `Excluded`,
`Blocked`, `CapacityRefused` and `Failed`. Only authoritative
`NotResident` coverage with a maintained creation/registration subscription may
support an absence certificate. If local coverage integrity cannot be represented,
retain conservative observer-wide quarantine.

### P4 — Event effect footprint / dependency halo

Issue #57 resolves this gate from source originally inspected at
`910717aac101363ec2b1b89e4041a22bc9a97b97` and narrowly revalidated after
reconciliation against current `main`
`17f01f729b41da0e0a635a279b6e72684422cdd4`. The authoritative paths are
`World::queue_explosion`, `World::apply_pending_explosions`,
`World::discovery_signals` and `World::observe_discovery_event` in
`native/src/world.cpp`, with configuration/rule reach established by
`WorldConfig`, `SchedulerGeometry` and the material-rule descriptors.

The three contracts are separate:

- **effect footprint** is where the accepted event itself can change authoritative
  cell material/state. For the only implemented deferred event,
  `ExplosionCommand`, radius `R` has exact maximum cell-effect reach
  `E = R + 2`. Execution visits the Euclidean disc of that radius: cells at
  distance at most `R` may be cleared, Wall cells in the outer two-cell annulus
  may become granular Stone, and the centre may become Fire. A
  `collapse_strength = 0` instance cannot write the outer annulus, and target
  contents/random selection can make any instance sparser; `E` is the
  source-proven maximum event-kind reach used by the conservative observer
  contract, not a claim that every cell changes. The event itself performs no
  temperature write. Actual cell writes also mark their activity
  block active and can wake an immediately adjacent activity block at a block
  face/corner; those execution-time activity signals remain a separate producer
  contract and do not redefine `E`.
- **dependency halo** is the independently configured rule reach
  `r = maximum_rule_radius`. It bounds active material-rule/scheduler write
  dependencies and is also used when deciding whether discovery coverage is
  fully included. It is not an explosion radius and does not already contain
  `E`.
- **pending observation footprint** is the conservative coverage that must be
  fenced immediately when the event is accepted, before any event write runs.
  Its inclusive axis-aligned half-extent is

  `P = E + r = (R + 2) + r`.

Therefore every tracked discovery tile intersecting
`[x-P, x+P] × [y-P, y+P]` must be pending at acceptance. The square is an
intentional conservative over-approximation of the circular cell-effect footprint.

The alternatives from the architecture review are rejected for concrete reasons.
`R + r` can omit the implemented two-cell collapse annulus when `r < 2`.
`R + max(2, r)` takes the larger reach rather than composing the event effect
with the additional dependency halo. With the default `r = 2`, both that
formula and the current Stage-3A observer produce `R + 2`; the numerical
coincidence is the ambiguity #57 closes, not evidence that the quantities are the
same.

Current source is intentionally not changed by #57. At the inspected head,
`queue_explosion` checks authoritative endpoint representability and
`observe_discovery_event` / `discovery_signals` mark only `R + 2`.
That is narrower than the frozen Stage-3 requirement to add the configured
dependency halo. Stage 3A remains the bounded reference; #63 owns the Stage-3B
producer change to `P = (R + 2) + r`.

Geometry and failure behavior are part of this decision:

- explosion radius zero is not legal; the minimum accepted `R` is 1;
- scheduler geometry permits `r = 0`, but the current World rejects a
  `maximum_rule_radius` smaller than any active material rule, so the current
  executable catalogue requires at least `r = 1`;
- negative coordinates use the same formula and floor-based canonical mapping as
  positive coordinates; face, corner, activity-block, chunk and discovery-tile
  crossings do not narrow the footprint;
- all signed endpoints for the pending box must be computed with checked
  arithmetic; never wrap or clamp a witness into a smaller box;
- if the authoritative `R + 2` event extent is representable and accepted but
  the wider `P` observation extent cannot be represented or indexed, discovery
  must conservatively fence/refuse the affected observation (up to an
  observer-wide quarantine when local integrity cannot be represented). It must
  not reject, alter or roll back the authoritative event;
- absent or resident-untracked coverage does not change event acceptance. Coverage
  that becomes tracked while the event is still pending must inherit the pending
  state if it intersects `P`; inability to retain that obligation is a
  conservative discovery refusal, not permission to forget it;
- overlapping accepted events have independent lifetime obligations. Shared tiles
  remain pending until every overlapping event drains; no decrement may underflow
  and no first drain may clear another event's obligation;
- a rejected event creates no pending observation state.

No other deferred event kind exists at the inspected head. A future event kind
must establish its own source-proven effect footprint before sparse observation
may give it a bounded local pending footprint; an unsupported kind must remain
conservatively fenced rather than inheriting explosion's `+2` by name.

Issue #63 must retain or implement the following adversarial regression contract:

1. default explosion radius/default `r = 2`, with a halo-only tile proving
   `P = R + 4` rather than the current `R + 2`;
2. a valid smaller non-default `r = 1`, proving `P = R + 3`;
3. a valid larger non-default `r > 2`, proving the halo is added to `R + 2`;
4. minimum legal `R = 1`, plus rejected `R = 0` producing no pending state;
5. event centres on a discovery-tile face and on a tile corner;
6. equivalent negative-coordinate face/corner crossings;
7. overlapping events whose footprints share tiles, including staggered drain
   with no early clear or pending-count underflow;
8. event acceptance while intersecting destination coverage is absent/untracked,
   then coverage registration before drain;
9. pending state visible immediately after acceptance and before execution;
10. successful removal after execution/drain, including a halo-only tile;
11. rejected capacity/radius/authoritative-endpoint events producing no pending
    state; and
12. an accepted event whose authoritative extent is representable but whose
    observation expansion cannot be represented, proving discovery fences/refuses
    without changing authoritative acceptance.

The existing `movement_mask_event_and_far_locality` regression already proves
acceptance-before-execution and owner-side drain for the currently marked event
tile. Existing deferred-explosion tests also cover zero/over-limit radius,
authoritative endpoint overflow, queue capacity and execution physics. #63 should
extend those observer obligations rather than duplicate their physics assertions.

### P5 — Clear/replacement failure

Approve retire-before-reset discovery semantics. An old observation may not remain
current after its underlying World authority has been cleared/replaced. Replacement
construction failure after authoritative clear leaves discovery explicitly
unavailable while the cleared World remains usable and not failed; it does not
resurrect stale generations. Existing failed-tick quarantine remains a separate
failure boundary.

### P6 — Local observations

Approve architecture/test work for a separately typed declared-scope local
observation. No production consumer or Stage-4 eligibility follows automatically.

### P7 — Runtime capacities

Approve mechanical runtime sizing before topology changes, preserving Stage-3A
semantics. In that checkpoint retain publication capacity `P=4096`; do not
silently replace it with `P=T`. Later production pools may expose independent
documented capacities.

## Reconciled refinements

The independent second review contributes these accepted refinements:

- retain exact Git-tree/source identity evidence across the review boundary;
- use explicit coverage-state vocabulary;
- use a bounded row-interval ordered compatibility design for arbitrary rectangle
  queries unless an equivalently proved structure replaces it;
- use at least five sequential process repeats per paired final-campaign cell.

Its mechanical `P=T` sizing proposal is not adopted because it changes a
publication-capacity dimension while claiming only to resize equivalent storage.

## Evidence continuity

The #57 source audit also preserves the useful review lineage without creating a
new gate. The preparatory briefing boundary was
`13a26b78b1ef4d6eafa5f2fc649c79976a2eb6ac`; the architecture-review head was
`35d03001257e0e2a3f60fa7ce6c9f6774c93e9d7`. Relevant Stage-3 native
source/tests/bench did not change across that interval. Intervening MS-001 and CI
integration did not constitute a fresh Stage-3 timing campaign. From the
architecture-review head through the #57 inspected source head `910717a`, the
Stage-3 World event/discovery implementation likewise remained unchanged. The
intervening changes established Stage-3B planning/CI authority and merged
#29/INT-000; that merge changed interaction/material-rule and `test_world` surfaces,
but not the World event/discovery source audited for this decision. Final #57
reconciliation then revalidated the same event/halo facts against current `main`
`17f01f729b41da0e0a635a279b6e72684422cdd4`. PR #75 changed only canonical
worker-parity CI routing. #58 / PR #72 changed discovery retirement/reset ordering,
settled-discovery lifecycle internals/tests and source-matched runtimes; it did not
change explosion acceptance/execution, event effect reach, dependency-halo
semantics or the Stage-3A event observation formula.

## Implementation authority

The active production routing document is
[soliding-stage3b-production-plan.md](../operations/soliding-stage3b-production-plan.md).
Issues #56-#70 are its bounded work packages.

#58 / PR #72 is merged on `main` as
`17f01f729b41da0e0a635a279b6e72684422cdd4`, closing G1 lifecycle safety.
Issue #57 resolves G-P4 in this document without production source changes;
validation preregistration #69 remains an independent lane. Central World producer
work remains serialized within #61-#63, and #63 retains the event/coverage
implementation after its separate #62 prerequisite.

## Later admission

No child issue self-admits Stage 3B. Issue #70 produces the exact-head registered
exit packet. The supervising parent then decides Stage-3B admission. Stage 4
remains blocked until that separate decision.
