---
title: REM-003 player↔granular preregistration and current-source evidence plan
status: Current
document-kind: evidence
scope: Frozen REM-003 current-main characterization matrix, measurements, decision rules and owner-review questions before player/granular candidate semantics
canonical-for: []
last-reviewed: 2026-09-24
related-documents: [../operations/development-claims-remediation-programme.md, ../systems/granular-interaction-policy.md, ../decisions/ADR-011-granular-interaction-policy.md, 2026-09-09-issue-10-granular-policy.md, 2026-09-24-rem002-issue11-integration-forensics.md]
---

# REM-003 player↔granular preregistration — 2026-09-24

## Authority, source identity and frozen boundary

This record is the preregistration required by issue #82 / REM-003. It is committed
before any REM-003 semantic candidate change.

Authoritative intake source is current `main`
`abad553cbd249f9bf2a574f20517d70ad7b6074f`, the REM-002 / #81 merge.
Execution must re-check main before merge, but all Current/pre-change observations in
this REM-003 packet must identify the exact source and runtime they actually execute.

The Current version-1 granular support policy remains the baseline under test:
eight of nine stable samples for downward support, nine of nine for side/upward
resistance, current stability/history semantics and bounded enclosure recovery.
Historical #10 results are retained as bounded evidence and are not replayed as
current-main gameplay acceptance.

REM-003 owns only sampled-player↔granular behavior. It does not own generic Rapier
body bearing (#83 / REM-004), reversible soliding/fracture (#12), Water pressure/head,
broad transport/erosion tuning or INT-000 non-kinetic interactions. The current
REM-002 generic-body bearing baseline must not be weakened to make this work easier.

At preregistration time there is no open REM-003 branch/PR other than this branch,
no #66 implementation branch/PR, and no #83 implementation branch/PR. If that
changes before an overlapping write, execution must serialize the genuine collision.

## Evidence classes

Three evidence classes are kept separate.

1. **Objective correctness/authority:** conservation, ownership, failure/re-entry,
   determinism, bounded work and source/runtime identity.
2. **Objective behavior characterization:** player motion, contact/support decisions,
   overlap, transition continuity, activity and work in frozen scenarios.
3. **Owner gameplay review:** whether the resulting behavior is acceptable as
   CyberSand gameplay. Automated counters do not substitute for this gate.

No subjective threshold is to be invented after seeing a candidate. A visually
questionable result may remain objectively correct; an objectively passing result
may still remain unaccepted.

## Frozen scenario matrix

Unless a case is impossible on a deliberately different fallback architecture,
run the same declared geometry/input schedule on native and fallback and report
differences rather than asserting parity.

### Static support

| ID | Case | Primary question |
|---|---|---|
| S01 | deep packed Sand bed | Stable ordinary standing/support baseline |
| S02 | shallow supported Sand bed | Does local support remain credible without deep material? |
| S03 | one-cell unsupported Sand film | Does unsupported film avoid becoming a floor? |
| S04 | partially undermined Sand bed | Does lost local support release promptly? |
| S05 | packed Dust | Representative low-density support-capable powder |
| S06 | packed Salt | Representative dense support-capable powder |
| S07 | intact versus granular Stone where source contracts distinguish them | Preserve Stone state distinctions; do not fabricate equivalence |

### Horizontal movement

Use explicit input segments at 60 Hz: rest, acceleration, steady travel, braking,
reversal and repeated traversal. Retain at least slow, ordinary and high commanded
speeds without changing production constants solely for the fixture.

| ID | Geometry |
|---|---|
| H01 | flat packed bed |
| H02 | one-cell step |
| H03 | shallow slope |
| H04 | pile shoulder and crest |
| H05 | edge / partial support |
| H06 | repeated traversal of the same packed bed |

### Vertical movement

| ID | Case |
|---|---|
| V01 | ordinary descent/landing |
| V02 | harder descent/landing |
| V03 | jump/jetpack takeoff then landing using the production sampled character |
| V04 | falling grains becoming settled support |
| V05 | support collapse/removal after the player is grounded |

### Dynamic granular conditions

| ID | Case |
|---|---|
| D01 | loose/falling grains around the player |
| D02 | active avalanche under/alongside the player |
| D03 | excavation directly under support |
| D04 | supported → unsupported transition |
| D05 | unsupported → supported recovery |

### Geometry, boundaries and lifecycle

| ID | Case |
|---|---|
| G01 | core/activity boundary |
| G02 | native chunk/storage boundary |
| G03 | signed-coordinate native support probe where the native API supports it |
| L01 | simulation-window exclusion while relevant granular work is active |
| L02 | re-entry without catch-up |
| L03 | sleep then wake |
| L04 | repeated exclusion/re-entry |
| L05 | failed-world/reset guard where the existing owner harness permits player-path coverage |

The finite Godot adapter cannot represent negative world coordinates; a native-only
signed-coordinate support query is therefore not fallback parity evidence.

## Registered measurements

For every applicable case record, before evaluating any candidate:

- exact source SHA, runtime hash, Godot/platform/profile identity and worker count;
- scenario ID, material, geometry, seed and input schedule;
- player position and horizontal/vertical velocity at the registered sample cadence;
- grounded state and grounded-state transition count;
- directional support/collision decision at feet, sides and head;
- local support sample/packing information where the execution path exposes it;
- player/material overlap count and maximum penetration depth;
- support-loss and support-recovery latency in owner steps;
- nearby material movement / changed occupied-cell count in the observation ROI;
- active/wake and exclusion/re-entry state where exposed;
- support-query count and query time where exposed;
- player coupling time and native tick time;
- total active material work/lifetime proxy where exposed;
- material counts/Water mass only where the case can alter those quantities.

Unavailable telemetry is reported as unavailable, not numeric zero. A new
read-only diagnostic may be added only if it is bounded, cannot mutate authority
and is needed to distinguish mechanisms.

## Frozen objective metrics and invariants

These are fixed before candidate tuning.

### Correctness invariants

- The sampled player may never erase, duplicate or silently transfer authoritative
  material.
- Hard terrain remains non-penetrable under the existing character contract.
- A one-cell unsupported film or currently falling support-capable grain must not
  become durable standing support.
- Excavating/removing the real support must remove the corresponding support
  decision on the next owner-visible query; no support cache may outlive it.
- Simulation-window exclusion must not create catch-up granular motion on re-entry.
- Failed-world/reset behavior remains governed by the existing F01 contract.
- Deterministic fixtures must repeat exactly within the currently promised
  platform/worker scope.
- Support/recovery/query work remains bounded; no per-cell character physics,
  universal pressure field, unbounded search or hot-loop allocation is admitted.

### Behavioral measurements

The following are measurements rather than automatic taste scores:

- settled-bed vertical resting depth relative to the local surface;
- peak/final overlap and penetration;
- time and distance to regain stable support after a landing;
- time/distance to release after support disappears;
- grounded-state transition count over a settled interval;
- horizontal speed continuity through slopes/shoulders/edges;
- number and duration of complete horizontal stops caused by granular contact;
- local material displacement/activity caused by traversal;
- repeated-traversal drift in player path and bed state;
- difference between loose and packed material responses;
- query count/cost and total active-material work caused by the interaction.

A candidate that merely prevents falling through does not pass by definition.

### Structural-failure classifications

Record each reproduced defect against its likely mechanism before changing code:

- material support capability;
- local packing/sample geometry;
- freshness/history semantics;
- downward support response;
- lateral resistance response;
- penetration/yield response;
- grounded-state hysteresis;
- enclosure recovery;
- wake/activity coupling;
- controller-level movement semantics.

Explicitly look for rigid-floor behavior, sinking then abrupt lock, hovering,
stale excavation support, grounded oscillation, edge jitter/stickiness,
invisible-wall side resistance, loose-grain support, packed-grain failure,
unnatural slope/shoulder behavior, threshold discontinuity, excessive recovery,
seam artifacts and traversal-induced perpetual wake or nonphysical bed drift.
Negative findings are retained.

## Candidate decision rule

Do not begin by changing the 8/9 or 9/9 constants.

1. Characterize Current source using the frozen matrix.
2. Classify reproduced defects by mechanism.
3. If the shared support predicate is wrong, revise it explicitly, version the
   shared contract, rerun REM-002 recurrence tests and update #83's starting
   baseline.
4. If support classification is sound but the sampled-character response is
   structurally wrong, prefer a bounded player-specific response change so generic
   body bearing remains unchanged.
5. If the existing response is structurally adequate, tune the minimum justified
   parameter only.
6. Preserve failed/rejected candidates and their reason.

No candidate may weaken this objective after its results are observed.

## Validation gate for an engineering-complete candidate

Run focused cases first, then the applicable complete repository gates:

- REM-003 sampled-player native/fallback behavioral regression;
- existing granular-policy regressions;
- REM-002 recurrence if shared support/native coupling code changes;
- failed-world and interest-region/re-entry regressions;
- native behavioral/integration tests and applicable sanitizer/TSan lanes;
- GDExtension/Godot Linux runtime regression;
- Water apparatus only if a shared World/coupling write makes it applicable;
- documentation/provenance/retrieval checks;
- retained-runtime publication only if source-sensitive native/GDExtension inputs change.

A Windows cross-build is not Windows runtime execution. No Web/browser acceptance is
claimed without an actual identified browser/Wasm execution.

## Frozen owner-review questions

The eventual compact playable packet must make the owner judge these cases without
telling them what answer to give:

1. packed-bed standing and ordinary walking;
2. acceleration, braking and reversal;
3. slope, shoulder, crest and edge transitions;
4. ordinary and harder landing;
5. loose/falling granular interaction;
6. excavation/support collapse;
7. at least one alternate powder;
8. any remaining behavior that the implementation review considers materially
   questionable.

For each case the packet records Current/pre-fix behavior, candidate behavior,
known limitations and exact source/runtime identity.

## Closure semantics

REM-003 records Implemented, Integrated, Verified, Accepted and Dispositioned
separately. If objective engineering is complete but owner gameplay review has not
occurred, #82 stays open at that exact gate. A green CI suite or merged PR is not
owner acceptance.
