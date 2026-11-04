---
title: MAT-AUTH-002 ranked correction admission
status: Planned
document-kind: design
scope: Separately reviewable minimal future correction for demonstrated MoltenGlass cooling starvation; no production implementation or compatibility transition is authorized by this document
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-mat354-findings.md, 2026-11-04-mat354-preregistration.md, ../operations/material-liveness-investigation.md, ../operations/material-catalogue-shadow.md, ../architecture/material-authoring-catalogue-plan.md]
---

# MAT-AUTH-002 correction admission

## Decision and rank

Phase A demonstrates one mandatory cooling obligation lost to sleep. It also
reproduces two distinct existing physical policies that must not be silently
changed. This memo proposes a finite successor implementation; it is not that
implementation and does not authorize protected-source edits.

| Rank | Finding | Next action | Authorization |
|---|---|---|---|
| 1 | Cold, stationary MoltenGlass omits a valid future cooling visit after sleep | Extend the existing coalesced block-deadline mechanism narrowly | **Pending owner and compatibility review** |
| 2 | A hot partner can disappear, leaving a cooling cell that later sleeps | Exercise the same intrinsic deadline repair after the already-working edit wake | Included in rank1 design; no separate wake defect demonstrated |
| 3 | Touching MoltenGlass repeatedly resets to180 when actually executed | Preserve Current; optional versioned thermal experiment only if requested | Separate physical/gameplay decision pending |
| 4 | Generic CellularYield sleeps after mobility failure | Preserve documented legacy rest and trajectory behavior | Optional versioned rheological/retry experiment requires separate admission |
| 5 | Source, partner, masks, region re-entry and reset restore execution in registered cases | Retain negative evidence and existing mechanisms | No speculative repair |

Evidence, exact source identities and limitations are in the
[findings report](2026-11-04-mat354-findings.md). The source baseline is accepted
main `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`; #371's shadow catalogue remains
unconsumed by production World.

## Smallest proposed source change

Target **only `native/src/world.cpp`**, specifically
`World::schedule_pending_reaction_wake`, which already retains compact-pair and
Ice obligations. `update_cell` invokes it for an unchanged, unmasked source after
the ordinary kernel. Writes and movement already keep their affected blocks
active. Preserve that source-epoch guard and existing publication path.

Add MoltenGlass to the helper's eligible materials. Inspect all eight visible
neighbors using the same `get()` authority and exact heat predicate as the
existing kernel: **Fire, Lava or MoltenGlass**. Generic `is_hot()` also includes
Spark and therefore is not an interchangeable helper here. Existing pair
reaction discovery currently permits an early loop break; do not let that break
truncate the new absence-of-heat test. Do not change pair ordering or Ice's
existing obligations.

For a visible unchanged MoltenGlass source:

| Current local state | Future existing-law action | Proposed deadline |
|---|---|---|
| No visible heat, countdown above0 | Decrement on the next thermal lane | Retain next period4/stream192 lane |
| No visible heat, countdown0 | Convert to Glass on the next thermal lane | Retain next period4/stream192 lane |
| Visible heat, countdown other than180 | Reset to180 on the next thermal lane | Retain next period4/stream192 lane |
| Visible heat, countdown180 | Thermal rule is a fixed point while neighborhood remains unchanged | Do not add an intrinsic thermal deadline |
| Source removed, converted, moved or hidden by a body mask | No unchanged visible MoltenGlass source at this location | Preserve current epoch/mask rules; do not renew that source's obligation |

With current tick `t`, period `p=4` and the existing deterministic lane phase
`phi`, calculate `elapsed=(t % p + p - phi) % p`, then request `t+p-elapsed`.
This is strictly future even if this tick was eligible. Reuse the helper's
existing `schedule_next_lane` logic rather than introducing a new cadence.

The deadline is a request for the earliest necessary block wake, not a per-cell
appointment or promise that no unrelated cell will be scanned. Coalesce by
minimum with existing obligations. Preserve job-owned effect grids and the
existing owner-side merge/barrier ordering. Do not publish a cell's private timer
from a worker, add threads, allocate per cell, scan an idle World, manufacture
dirty writes or alter random salts.

## Cancellation, invalidation and bounded work

Do not clear a shared block deadline when one source disappears or converts.
Another cell, compact reaction, Water-CY lane or Ice contact may own the same
earliest wake. The existing deadline may cause one stale wake; after current
state is re-examined, an ineligible source does not renew it. This avoids new
per-cell ownership while keeping cancellation bounded.

External source and neighbor changes already wake the registered cases. The
successor should rely on and qualify these paths rather than refactoring them
without evidence. Removal of a hot partner must expose cold eligibility; adding
one must allow reset then rest. Current visible body occupancy controls both
source admission and neighbor heat. Region exclusion retains the documented
pause/re-entry policy; no catch-up series is invented for omitted ticks. Owner
pause is no `World::tick` call, not a hidden simulation clock.

Hot180 pools must remain able to sleep. Keeping all MoltenGlass blocks awake
would perform extensive no-op work in the pair/pool controls and is not the
admissible repair. Inert and converted controls must still sleep and cease
subject-kernel work.

Quiet3 with a four-tick cooling period can nevertheless cause almost every-tick
visits during the finite countdown: a decrement writes activity, intervening
quiet visits accumulate, then the next due tick wakes the block. The current
awake controls require717–720 singleton kernel entries, depending on phase,
before conversion from180. This is a measured comparison, not a measurement of
the unimplemented fix. The design does not claim only180 total visits. Reducing
off-lane work would be a separate optimization with its own evidence.

Retaining a cold MoltenGlass block's cooling work may also admit additional
ordinary movement opportunities while that source remains eligible. Preserving
the thermal formula does not imply byte-identical old trajectories. The
successor must explicitly qualify those movement and workload consequences,
while preserving the generic Paste/Slush/Brine/Mercury retry policies.

## Required successor acceptance

Freeze the approved mechanism, source transition and expected invariants before
executing the successor. Reuse the Phase A fixtures with new source-qualified
receipts; retain Phase A as the unchanged negative baseline.

- All four isolated phases at quiet3 must execute every necessary cooling lane
  and reach the same Glass product/countdown sequence as the matching awake
  controls. Off-lane visit counts may differ; deterministic ordering may not.
- Explicit state0 and hot sub180 sources must receive the next valid conversion
  or reset; hot180 pair/pool controls must settle without perpetual renewal.
- Multiple sources and mixed compact/Ice obligations in one block must retain
  the earliest due tick. Removing one must not cancel another.
- Source/partner removal, replacement and addition must exercise actual wakes
  across activity/core/chunk seams and negative coordinates, with current body
  masks and region exclusion/re-entry. Test source/partner masked at due time.
- Conversion, clear/reset and fresh reconstruction must retire obsolete work;
  shared stale wakes must be bounded and then stop.
- Existing MAT-001, Ice, Water-CY mandatory retry, Water FreeMass, Oil, Lava,
  Acid, Cement, inert, PressureFlow, IN, quantity and worker ownership controls
  must remain source-matched and pass.
- Configured workers1/4 must have exact physical-state parity; distributed work
  must document actual multiple claimants. Ordinary Windows/Linux and feasible
  sanitizers require actual receipts, not configuration-based claims.
- Account for additional finite cooling work, active blocks, jobs, idle cost,
  wake latency, allocations and resident capacity. No global idle scan or new
  permanent per-cell storage is allowed.

Stop on World quarantine, quantity error, out-of-bounds access, unexpected
product, parity/source mismatch, unbounded wake, or the frozen resource/time
bound. Keep failed and inconclusive cases rather than changing the threshold.

## Compatibility transition and source ownership

#371 protects27 legacy files against immutable baseline
`0fd4af5987e77db4da3e37c757cf2c0917ae9e15`. The proposed production path is
`native/src/world.cpp`, whose accepted SHA-256 is
`b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1`.
No protected header, material table or movement include is required by this
minimal design. If implementation unexpectedly needs another protected path,
stop and expand the review explicitly before editing it.

The change intentionally alters physical trajectories of cold MoltenGlass that
previously stalled. It preserves the thermal law, phase,180 value, products,
random streams, quantities and existing ordering. Because the identity-bearing
source changes, it cannot honestly retain the old source identity merely because
the law is unchanged. Exact effects on catalogue/capability identities and old
policy/save/runtime receipts must be inventoried from the production identity
code in the implementation review, rather than guessed or suppressed by a hash
refresh. The old baseline and historical receipts remain reproducible.

Required transition steps are:

1. Owner explicitly admits the narrow cooling correction and the protected path.
2. Review old/new source behavior and an explicit compatibility/version policy,
   including strict stale-identity refusal and any controlled regeneration.
3. Implement and qualify the small patch with frozen baseline/successor fixtures;
   review new source identity independently from the fixture oracle.
4. Review an explicit source-guard transition with preserved historical baseline;
   never disable the checker or rewrite hashes merely to make physics pass.
5. Rebuild the affected native runtime artifacts on required platforms, publish
   them through the existing LFS/provenance process, and verify loaded runtime
   identity and applicable integration gates before merge.

These are future gates. Phase A neither performs nor needs a production runtime
publication. Do not implement #353-B consumer migration as part of this repair.
Serialize protected `world.cpp`, interaction, quantity and material-header writes
with #355 if its reaction-effects work starts concurrently. Preserve separate
#358 finite Binder/quantity, #160/#162 Water, #347 detachment, #373 events, #201
PressureFlow and #370 liquid-comparison ownership.

## Optional physical-policy experiments remain separate

Changing MoltenGlass mutual heating would replace an identity-based fixed point
with a different thermal law. Any proposal must specify old/new pool lifetime,
cooling and product transitions, Ice/Water/quench interactions, gameplay effect,
performance, source identity and a versioned optional thermal profile. Phase A
does not select such a law or imply that a touching pool should cool.

Likewise, generic CellularYield retry deadlines would change later random
opportunities and deterministic trajectories for Paste, Slush, Brine and Mercury,
even if cell count were conserved. Water-CY's stronger existing retry contract
does not establish one for those materials. Preserve legacy rest unless a
separately versioned gameplay policy is approved.

## Finite handover

The next agent should first obtain the explicit rank1/compatibility admission,
revalidate accepted main and active ownership, then implement only the targeted
MoltenGlass deadline extension in an isolated branch. Preserve H2/H3 negative
controls and all Phase A failures. No generalized scheduler or thermal framework
is a prerequisite. If the owner declines admission, retain the demonstrated
limitation and keep #354 open with that decision rather than changing physics.
