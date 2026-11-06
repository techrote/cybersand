---
title: SOL stages and first-impulse mass readiness repair
status: Current
document-kind: evidence
scope: Actual structural stage attribution and source-pinned backend initialization repair; no dense-Sand settling or integration admission
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [../systems/solid-detachment.md, ../operations/local-build-and-validation.md, 2026-11-06-sol-structural-cut-behaviour.md, 2026-11-05-sol-energy-precision.md]
---

# SOL stages and mass readiness — 6 November 2026

The trace found a real initialization defect: an aggregate could report the
correct mass/inertia while losing its first linear/angular impulses. The
candidate repairs backend readiness without changing declared mass, inertia,
gravity, caps or contact-solver arithmetic. **Dense-Sand settling remains NO-GO.**
Earlier cached-parameter checks did not establish effective backend readiness;
their dated source-bound evidence remains unchanged.

## Source and executed stage experiment

Published as [Draft PR #460](https://github.com/techrote/cybersand/pull/460),
targeting #393. Earlier combined shell commands were rejected before dispatch;
a literal body-file edit and separate short Draft-creation command succeeded.
The exact original rejection cause was not supplied. No Ready/merge action occurs.

The sole-writer branch remains `codex/sol-structure-cut-20261106`, based on #393
e4 and retaining #347/#407 ancestry. Previous pushed checkpoint is4ee0e591.
Native World/include/extension/pressure and frozen material guards are unchanged.
No accepted default or #394 material/World composition is introduced.

Registration90f440a4 precedes packed source2c1d05d5 and dry3958aaaf: **24 fresh
episodes/11,520 actual steps**, Windows/Linux, workers1/4. The synchronous no-op
observer exposes S0 before ordinary coupling, S1 after ordinary/before Sand,
S2 after Sand and S3 after Rapier. Manual-step indices are n,n,n,n+1.
Only copied bounded values/scalars enter the observer; no World/snapshot object,
await, setter, native query, extra publication or physics step is added.

All steps preserve body/generation/epoch/M/I and exact inter-step rigid bits.
Ordinary counts partition into10,934 accepts,221 duplicate/old-sample refusals
and365 nonexecuted frames. Sand has2,825 accepts,48 nondissipative and4 pose-drift
refusals;3 On frames have no execution. Accepted scalar64 actual Sand KE never
exceeds its unchanged planner bound. All frames remain in denominators.

The [comparison](sol-structure-stages-20261106/comparison.json),
[all-step ledgers](sol-structure-stages-20261106/step-ledgers.json),
[full fixtures](sol-structure-stages-20261106/fixtures.json) and
[manifest](sol-structure-stages-20261106/manifest.json) bind sources, runtimes,
dependencies, commands, exits/log hashes and retained local raw reports. RIDs and
tokens are session-local; run/host/coordinate identifies each fresh process.
Public text copies have separate Git-LF hashes; original raw bytes are unchanged.

## What the late motion trace establishes

Ordinary coupling translates the body, zeros velocity components opposing that
correction, applies capped impulses and requests wake. Sand acts next; Rapier
then advances gravity/damping/contact integration. Signed upward momentum ratios
below divide by summed `M*|g|*bridge.fixed_delta()` over **all120 physical frames**.
That is a load reference, not calibrated granular pressure or proof that sleeping
bodies actually receive the reference impulse.

| Late window | Ordinary impulse | Velocity clipping | Sand impulse |
| --- | ---: | ---: | ---: |
| Windows tree/On, workers1 or4 | .003630 | .941317 | .064926 |
| Windows building/On, workers1 or4 | .005442 | .908199 | .050372 |
| Linux building/On, worker1 | .005472 | .992386 | -.000173 |
| Linux building/Off, worker1 | .003886 | .089139 | 0 |

Clipping contributes90.8–99.3% in14/16 packed windows. Two Linux building/Off
exceptions contribute8.9% and32.6%, with much greater motion. Native impulses
contribute about0.329–0.548%. The negative Sand value remains signed. Mass-independent
clipping dominates many observations; cap3 divided by weight alone was incomplete.

Linux/worker1 building/On step359 has vertical velocities **+1.523517 →-.00840583
→-.00822572 →+1.52355254** at S0…S3. Correction moves the origin up.00487518cells;
the whole step ends down.0109825cells. The measured gravity/damping velocity
model predicts S3 within4.14e-8cell/s. See the retained
[three-step witness](sol-structure-stages-20261106/stage-cycle-witness.json).
This attributes executed changes; it does not prove the outcome of changing order.

Every packed episode has negative full/late mechanical-energy change. That
representative tail adds about+19,185.76 potential units through correction and
removes-49,587.04 KE through clipping. Ordinary/Sand/backend stage totals are
approximately-30,398.46/-1.40/-12,820.07. Native Sand has no calibrated Newtonian
energy state; backend effects are combined. Cached contact impulses are not summed
as fresh work. Telescoping is an arithmetic identity, not closed-system conservation.

## Initialization defect and independent oracle

First Windows tree/Off reports J=(.04,.28), applicationcount1, yet immediate
momentum change is zero: residual.2828427135. It was **not** accepted as float32
rounding. Later maximum residual is about.00139511; wrench closure remains diagnostic.

Pinned addon172c66f5 assigns custom COM/inertia mass properties without forcing
immediate effective-property recomputation; cached parameter getters can still
return expected values. See the [mass-update path](https://github.com/appsinacup/godot-rapier-physics/blob/172c66f5a88bf1164c2b8cf2d775ed889edefd75/src/bodies/rapier_body.rs#L253)
and [wrapper recomputation](https://github.com/appsinacup/godot-rapier-physics/blob/172c66f5a88bf1164c2b8cf2d775ed889edefd75/src/rapier_wrapper/body.rs#L487).
Pinned Rapier applies impulses using current effective inverse mass immediately,
without saving them for a later mass update: [implementation](https://github.com/dimforge/rapier/blob/3e12c2679cb1940a876bde93af9cec0cf2f57944/src/dynamics/rigid_body.rs#L1304).

Oracle001 at793394f6 uses the exact two aggregate geometries in isolated actual
Rapier spaces, zero gravity/replacement-zero damping, no native World. Both hosts
lose all8 fresh-custom linear/angular impulses; they remain absent after a step.
Sixteen warmed/AUTO controls work. Warm stepping is only an isolated control,
never inserted into native handoff.

Repair registration0c0fc3da expands to **64 backend cases**: two geometries,
four initialization orderings, central/offcentre impulses, ordinary/doubled custom
inertia, both hosts. All48 ready controls meet the frozen immediate **and post-step**
references;16 old fresh-custom negatives retain lost impulses. Getter/direct-state
velocities agree. Doubling diagnostic inertia halves angular response, preserving
J/M. Frozen torque references/tolerances remain; actual-COM lever differences are
additional diagnostics. Doubled inertia is never assigned to native aggregates.

## Repair and fresh actual native-cut qualification

`_prepare_body()` selects AUTO COM before unchanged prepared mass/custom inertia
and removes the explicit zero-COM setter. For the admitted homogeneous unit-mass,
exact nonoverlapping rectangles, automatic and unit-cell centroids are mathematically
equivalent. Source origin, tuples, proxy offsets, shapes and explicit inertia stay.
This does not extend to Wood or heterogeneous density. Proxy velocities now use
actual COM rather than scene origin; RIDs stay main-thread owned.

Sourcec0d8544f completes another **24 fresh native-cut episodes/11,520 steps** and
the64-case oracle on both hosts; the native-cut matrix uses workers1/4. Exact source-matched native binaries are
verified/reused; no native build inputs change. Prior optimized/ASan/UBSan/MSVC
qualification scopes are retained, not relabelled as freshly executed here.
Guard-only descendant1d83c881 returns an empty packet on null direct state, using
the existing refusal/pause path. Both actual hosts parse it; no actual null-state
fault or native `Quarantined` phase is claimed executed.

Tuples, one-body ownership, exact union, M/I, world COM within the existing
four-float32-ULP bound, and zero-step handoff pass, including the first genuine
application midpoint. Matching cached preactivation COM is still not readiness
proof. The known-wrench oracle and actual first application provide that evidence.

The first actual tree/Off packet on both hosts still has J=(.04,.28); measured
M*deltaV becomes(.03999999928,.28000000631), residual about5.125e-9 instead of.28284.
Torque is also honored; its reconstruction residual is retained. No diagnostic
impulse, warm step, new correction, elasticity or support force enters production.

All8 repaired dry episodes settle with zero last120 motion. All16 packed cases
remain nonquiet. Sand has2,706 accepts,116 nondissipative and4 pose-drift refusals;
54 On frames have no Sand execution. On endpoint Sand area is16.534–23.307cell²/depth2.505–2.703cells,
using paused post-trajectory maps, not synchronized clearance coverage. Asynchronous
source comparisons show no uniform settling benefit. See the
[repair comparison](sol-structure-stages-20261106/mass-fix-comparison.json) and
[independent oracle audit](sol-structure-stages-20261106/mass-fix-oracle.json).

## Qualification, decisions and next action

Seven geometry controls, seven stage controls, eleven adverse trace mutations
and valid-report admission pass. Cross-host reductions differ only in two derived
angles by at most1.11e-16rad. The initial exact-basis reducer failure is retained:
ordinary transform correction can re-encode float32 basis values. Its observed
maximum angle difference3.304e-8rad is recorded, not hidden behind a fitted bound.

All-attempt/refused/overwritten metrics remain. Repair captures omit redundant
per-step cumulative dictionaries after retaining deltas and final complete metrics;
serialization workload can change asynchronous scheduling. These timings are not
the original24-group/three-repeat≤2ms CPU gate or a universal60Hz result.
Physical-run artifacts total4,275,796,378bytes against the frozen4,294,967,296-byte
collection cap; free storage is18,873,139,200bytes. Compact analysis/validation
receipts add their separately recorded bytes. No prior artifacts are deleted;
earlier outside-checkout native qualification artifacts remain separately inventoried.

| Decision | Source-bound result |
| --- | --- |
| Stage attribution | PASS with stated limits |
| First-impulse initialization repair | PASS for pinned geometry/runtime and tested normal path |
| Ownership/M/COM/I and dry cut behaviour | PASS for the actual matrix |
| Relative material-weight calibration | UNAVAILABLE; density ranks are not physical units |
| Packed settling/original SOL clearance | NO-GO |
| Original CPU gate/closed total-energy proof | UNAVAILABLE here |
| MAT/runtime/source integration | NO-GO; inherited guards remain |

Keep84/84 clearance,64/84 depth,36/36 async-overlap and1,452/1,452 corridor
negatives, historical cost/hash records, hard exclusions and#365 block. No SOL364-D
clock, E1/E2 recovery authority or #394 source equivalence is inferred. LA-SELECTIVE
primary intent/default promotion remains a separate conditional lane.

Next is a separately registered **pure-value operator comparison** using retained
authenticated contacts: unchanged planner at measured preRapier velocity versus
a labelled gravity/damping prediction. It would apply no forces or move cells.
A live order/load-aware candidate needs its own registration and applicable
authority contract. Raising caps or guessing density ratios is unsupported.

Keep any PR Draft; independent adversarial review precedes owner admission.
Prior automatic Draft-creation rejection is retained, with no bypass attempt.
Current semantics/commands/remaining work belong to the detachment/coupling
contracts, handover, build guide, roadmap and retrieval routes. Native catalogue,
Water, fleet/UI/save-load implementations and historical questions are unchanged.
[Validation](sol-structure-stages-20261106/validation.json) records exact sources,
command outcomes and persistent admission blockers.
