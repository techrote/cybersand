---
title: SOL281 supported-Sand contact implementation and qualification ledger
status: Current
document-kind: evidence
scope: Draft PR347 contact successor, preserved local failures, source reconciliation and separate physical, ownership and platform gates
canonical-for: []
last-reviewed: 2026-11-03
related-documents: [2026-11-03-sol281-dense-contact-registration.md, 2026-11-01-sol281-current-main.md, ../systems/solid-detachment.md, ../architecture/rigid-body-and-cellular-coupling.md]
---

# SOL281 dense contact continuation

## Decision and source authority

**Current implementation, experimental acceptance:** PR #347 adds a separately
enabled supported-Sand normal response and exact rotated contact measurements.
Its native aggregate, conservative vacancy transactions, ordinary 11/9 interface,
six-proxy geometry and two holes remain. The candidate is available for focused
qualification; it is not accepted gameplay physics. #347 stays draft/unmerged,
#281 and #12 stay open, and no merge of #282/#283 is authorized.

| Source boundary | Verified identity and scope |
|---|---|
| Accepted main inspected before changes | `89020b9eb6d540383a5bb64b58dcd29a87592c32` |
| Active #347 before continuation | `5af50b3c5a5f11614099a82090ad431646db4cba` |
| Main / #347 common ancestor | `a8f08a67fea3c58f6df7473cbae1831334fcc04e` |
| Prospective registration | `34ce548381cae8ed0017eee5507381d783195f26`; proposed gates fixed before candidate tuning and ancestry reconciliation |
| Ordinary reconciliation merge | `2321cf24d65024a609140b949efc3f5d909f6afa`; tree `4c7d29809b527e5303f3f50fb941523a251d6a2e` |
| Frozen #283 | `254235ec4c3d58782bba44b478caca86bf57c856`; draft, open, unchanged |
| New candidate execution source / tree | Pending final source freeze and exact-source qualification; this row is not a runtime pass |

Main's accepted PLAY #332 changes were reconciled through an ordinary merge.
Only three additive documentation sections conflicted; both SOL and PLAY content
were retained. Seven incoming PLAY execution/test files were checked against
main. Production render-copy #344, existing physics/material/worker policies and
the full #347 evidence ancestry remain. No history was rewritten or archive
experiment promoted. Y1 #343 stays independently owned and unaccepted as default.
The [earlier qualification](2026-11-01-sol281-current-main.md) retains its source,
runtime and platform scope; it does not qualify this successor.

## Implemented mechanism and ownership audit

The [canonical contract](../systems/solid-detachment.md#opt-in-supported-sand-resistance)
owns the precise bounds and algorithm. The narrow defect motivating this
experiment is the prior aggregate's small three-unit impulse ceiling relative
to its mass of 520; merely widening ejection search is not the response.

| Boundary | Current source and invariant |
|---|---|
| Geometry | `solid_contact_geometry.hpp` intersects the full unit square with each rotated rectangle using SAT and polygon clipping; AABBs only bound traversal. |
| Native observation | `solid_contact_adapter.inc` reads the exclusive native World, reconstructs one coherent compound transform, removes sibling internal face spans and records all-material overlap plus supported ambient-Sand segments. It moves no cells. |
| Capacity and admission | 8,192 cell/proxy probes, 256 contact segments and at most 4,096 source edge units; malformed/coherence, foreign-body, residency, support and capacity failures refuse. |
| Material authority | The existing native aggregate retains all exact material/state/temperature tuples. Existing conservative transfers are unchanged; no new rasterization or terrain conversion occurs. |
| Publication | The specialized worker adds a copied, recursively frozen observation before snapshot publication. Failure clears the channel; main never queries live native state. |
| Identity | Snapshot/tick/revision/epoch/token/generation/sample equality and forward ordering precede every candidate RID mutation. Sample age over one and maximum proxy-corner drift over 0.25 cells refuse. |
| Main response | A pure complete-record planner computes zero-restitution effective-mass impulses. The bridge alone applies them through Rapier after ordinary compound response is admitted. |
| Rotation and energy | Approaching segment subsets are recomputed during each of four fixed sweeps. Each planned impulse is dissipative within the registered tolerance, with actual Rapier energy readback checked separately. |
| Policies and lifecycle | No Water, chemistry, hard-contact or ordinary GCR default change; no Y1 promotion, additional ejection radius, friction gain or candidate position correction. Sleeping still means aggregate ownership. |

Deeply embedded material can overlap without crossing an exterior face and
therefore produce no candidate response segment. Four fixed sweeps do not
guarantee complete multi-contact convergence. These limitations remain visible
in overlap and residual approach metrics. Supported Sand acts as a dissipative
reservoir; exact two-way granular momentum conservation is not established.

## Independent review and retained counterevidence

Separate agent review inspected the native geometry/ownership, response and
qualification paths. This is independent technical review within the engineering
session, not independent human gameplay acceptance.

| Finding | Correction / remaining qualification |
|---|---|
| A fixed parallel-group center can hide an approaching spinning edge behind the separating edge. | Recompute the approaching subset every sweep. Preserve the original failing report and rerun the same regression inputs. |
| Partial sibling seams and separately rounded proxy centers can create false support or geometry slivers. | Derive exterior runs in the exact source grid and reconstruct all proxies from one aggregate transform; native observation tests include rotated partial seams and float32 center perturbations. |
| Observation revision was only type-checked. | Match it exactly to the enclosing snapshot's `simulation_world_revision`; the negative fence case must produce no RID mutation. |
| An all-refused candidate could pass a conservation-only live fixture. | Populated candidate cases require actual accepted response and nonzero applied impulse; baseline remains a separately instrumented arm. |
| Timing omitted refused responses and native publications skipped by main. | Count every response attempt and carry cumulative owner observation/freeze work, including refusals and unconsumed publications. Retain the original 2 ms proposed gate and disclose its denominator. |

The [iteration manifest](sol281-20261103/iteration/manifest.json) preserves
original JSON bytes and available source copies. The failed planner's original
source bytes were not retained; its original report records their SHA-256.
No source was reconstructed to fill that gap. These local reports bind the
planner/test hashes and official Godot engine identity, not a complete final
repository tree or runtime receipt.

| Same contact inputs | Original policy | Corrected policy |
|---|---:|---:|
| Pure spin: maximum sampled approach, cells/s | 4.0 | 0.0 |
| Pure spin: impulse count | 0 | 1 |
| Pure spin: final kinetic energy, adapter units | 24,000 | 20,454.545557164 |
| Falling plus spin: maximum sampled approach, cells/s | 4.0 | 0.0 |
| Falling plus spin: impulse count | 1 | 2 |
| Checks / failures in the identical test source | 90 / 4 | 90 / 0 |

The corrected symmetric falling fixture has zero angular response. Negative
and corrected test results remain distinct; the correction does not relabel the
failed source. Reported planner SHA-256 changes from
`747b397cb9533842a8127a993bb57d2020594e1083ef60252f2b4c7a5e431f47`
to `d5bebb75d81cf5bc0dce756f7a844f19ad9f145fbd9ca96775ad8f999a061d6d`.
The common test SHA-256 is
`6b4ab230c642e78430a04c6575066d00247532342b5740c089ed5e43d68d973b`.
Later wording/source changes require their own final run.

## Physical evidence and registered gates

### Local mechanism iteration

The preserved corrected report executes official Godot
`4.7.stable.official.5b4e0cb0f` with actual Linux Rapier. Its fixed controls use
mass 520, identical incoming velocity 12 cells/s, no gravity/damping and twelve
1/60-second steps. The baseline offers the old aggregate's full three-unit
impulse ceiling upward on every step. This deliberately generous ceiling control
isolates an impulse/overlap mechanism; it does not reproduce the entire native
B0 session or compare Y1.

| Controlled metric | Ceiling control | Candidate | Registered decision |
|---|---:|---:|---|
| Flat-support added overlap area-steps, 12 steps | 56.75390625 | 0.0 | 100% reduction; passes proposed minimum 25% |
| Flat-support maximum penetration, cells | 2.6425018311 | 0.25 | Initial 0.25-cell embedding retained; no candidate correction |
| Off-centre support-column added overlap area-steps, 12 steps | 14.1884765625 | 1.2502432300 | 91.1883194468% reduction; passes proposed minimum 25% |
| Off-centre maximum candidate rotation, radians | Not the comparison gate | 0.8998947144 | Actual rotation remains present |

The central impulse is -6,240 in vertical adapter units, arresting incoming
energy 37,440. The off-centre impulse produces torque impulse -3,900, angular
velocity -4.5 and final energy 14,040, matching Rapier readback within the
registered tolerance. These are narrow matched controls, not acceptance of
whole-session resistance, rolling, burial recovery or sustained clearance.

### Live sessions, cost and source-qualified platforms

The apparatus extends the existing native/Rapier session with packed Sand,
embedded Sand and mixed Sand/Water; baseline and candidate each run three
repeats of 360 actual Rapier steps per worker setting. Repetition order alternates.
Each trace keeps source/current poses, native tick/revision, sample, token,
generation and epoch; payload conservation and candidate exercise are required.

Overlap **cell-samples** and **area-samples** sum complete consumed native
publications, not native simulation ticks. Report per-observation means and
run-to-run ranges. Contact CPU includes every owner observation/freeze attempt
and every main response attempt, including refused or unconsumed publications;
its registered mean divides by complete consumed geometry observations. This
conservative denominator remains fixed at the proposed 2 ms limit. Native-worker,
Rapier, synchronization and publication-latency denominators remain separate.
Unmatched asynchronous trajectories support descriptive comparisons only.

**Final execution evidence is pending in this ledger.** Freeze the candidate
commit/tree, build matching runtimes, execute the declared Linux/Windows cohorts,
and append the original source/runtime/toolchain/artifact identities here before
claiming platform passes. The existing targeted workflow adds a small separate
mechanism cohort because unchanged per-case watchdog allowances would overflow
the core job's hosted aggregate budget; maximum matrix concurrency is unchanged.
MSVC native coverage is separate from the existing LLVM-MinGW extension build
and actual Windows Godot execution. Draft-skipped ordinary workflows are not
passing tests.

| Gate | Current disposition at this checkpoint |
|---|---|
| Prospective thresholds and source reconciliation | Recorded; original main and #347 ancestry preserved |
| Frozen-contact plane/off-centre improvement, energy and pure spin | PASS for the preserved local iteration; final-source rerun required |
| Native geometry, ownership/displacement, ASan/UBSan | Focused tests implemented; exact candidate receipts to be appended |
| Complete Linux/Windows Godot/Rapier, workers 1 and 4 | PENDING final source-qualified cohorts and runtime publication |
| GCC and MSVC native builds | PENDING final source-qualified compiler receipts |
| Stale/revision/reset/duplicate and exact-payload coverage | Existing negatives retained and new cases added; final cohort evidence required |
| Live penetration, persistence, resistance and cost | UNPASSED physical acceptance; publish all repeated results and original failed gates |
| GPU pacing, graphical interaction and human feel | UNTESTED; no inference from software/headless execution |
| Active restoration, multiple aggregates, reactive cohesion, fracture and persistence | DEFERRED independent features; no sleeping-body desoliding claim |
| #281 closure / #347 merge readiness | NO-GO; partial physical and lifecycle acceptance is insufficient |

The next implementation should use the complete live refusals and exact geometry
to isolate sustained penetration under embedded/rotating load. Restoration is
held until preceding physical gates justify it; any future prototype still needs
stable-rest evidence, exact transformed destination/residency preflight, rollback,
collision reconstitution and epoch-safe single-owner retirement.

## Documentation and retrieval map

The canonical detachment page owns the specialized observation schema, algorithm,
capacity, ownership, controls and measurement semantics. The coupling contract
adds a scoped route; ordinary packed-interface/configuration and material-policy
pages retain their unchanged contracts. Documentation and retrieval indexes route
to both this evidence and the historical 1 November record. The current corpus
retains canonical contracts and explicitly excludes these dated audits.

The frozen 1 November SOL281 questions remain unchanged. A separate
[contact question set](../reference/retrieval-questions-sol281-contact.json)
tests exact geometry, refusal fences, opt-in controls, metric denominators,
default-policy ownership and lifecycle limits. Final documentation, repository,
historical-M11 and retrieval receipts must retain their own source scope; a
lexical canonical hit alone is not proof of answer correctness.
