---
title: Actual SOL cut structures, mass and settling qualification
status: Current
document-kind: evidence
scope: Source-local structural detachment and scalar energy repair on the dependent Draft; partial physical result, no original clearance or integration admission
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [../systems/solid-detachment.md, ../operations/local-build-and-validation.md, 2026-11-05-sol-energy-precision.md, 2026-11-04-sol-facade-refusal-repair.md]
---

# Actual SOL cut structures — 6 November 2026

The actual cut tree and building have correct aggregate ownership, mass/inertia
and dry falling/collision/rest behaviour. A reproduced scalar energy-evaluation
defect is repaired without changing their masses or forces. Dense-Sand settling
and strict physical clearance remain **NO-GO**. This is structural SOL execution,
not a Kestrel/workbench proxy or proof that relative material weight is calibrated.

## Source, scope and custody

Root is the only writer of `codex/sol-structure-cut-20261106`, based on #393
`e4c2649e82d943554f4dc6a0634336770cda08f6`, retaining #347
`1598115c9065239cc1eaec11e99077274b457be1`. An ordinary local merge retains
the exact #407 `bbca191544f6a578ee14323c08d48021904893f7` repair ancestry;
it does not merge or write any owning PR. The only production change from #393
is the six-line `_energy` replacement in `solid_contact_response.gd`.
Native source, extension, World/pressure semantics and frozen material consumers
are byte-equivalent to #393. No default, gain, impulse formula, geometry,
material policy, sweep count or guard tolerance changes.

The [manifest](sol-structure-cut-20261106/manifest.json) records live upstream
heads, input tree, code checkpoint `d5c3e05f`, raw dependent patch hash and
retained local artifacts. Main was freshly observed as `06522e30`; it is not an
integration base. #393 remained e4; upstream #347/#386/#394/#400/#407/#429
observations are retained separately. Earlier workbench/gravity-support work is
separate: #429 stays Draft at `67f93a28`; its untested local prototype is not
published through this branch.

[Comparison](sol-structure-cut-20261106/comparison.json) contains all 48 cases,
runtime/source receipts and performance/refusal counters. Compact
[step ledgers](sol-structure-cut-20261106/step-ledgers.json) retain all 23,040
steps' independent hard geometry, scalar KE, potential change, aggregate
application/correction and publication identities. Raw full native/Rapier reports
and logs stay in the manifest's local paths with SHA-256 receipts; binaries/logs
are not committed. A consumer without those raw files has the public reduced
packet and replay inputs, not independent access to every original contact cache.

## Actual cut, ownership and mass before the repair

The unchanged native session authors the original RedBrick tree-shaped fixture.
Removing eight support cells at `(50,65,4,2)` produces the actual **520-member,
six-proxy aggregate**, preserving hole `(60,32)` and concavity `(68,50)`.
A separately registered RedBrick building frame produces **356 members/five
proxies** after the same real cut. It is a new building geometry, not the original
520-member partition. Neither fixture establishes Wood cohesion: current SOL
accepts homogeneous Wall/RedBrick; Wood, reactive and mixed material cohesion
remain unavailable/refused.

Native prepare owns all source tuples; ACK/commit retires them; the one actual
Rapier body owns the exact union after commit. Final native source count is zero
and all six-field payload tuples remain identical. There is no physics step
inside handoff, per-member Rapier body or independently animated proxy. Existing
ordinary cellular positional correction remains active and separately counted;
the fixture adds no positional correction or force.

| Quantity | Original tree | Registered building |
| --- | ---: | ---: |
| Mass (one unit/member) | 520 | 356 |
| Analytic cell-centre COM | (57.33076923,37.875) | (59.68539326,41.12921348) |
| Analytic unit-square inertia | 70453.64935897 | 59192.15355805 |
| Actual server inertia | 70453.6484375 | 59192.15234375 |
| Actual gravity Y | 92.11999512 | 92.11999512 |
| Gravity impulse at 60 Hz | 798.3732910 | 546.5786377 |
| Ordinary aggregate impulse cap | 3 | 3 |

All 48 episodes independently pass full tuples, exact nonoverlapping source/server
rectangle union, individual proxy mass/centre, four-float32-ULP COM/inertia,
handoff/final ownership, per-step finite state, terrain/gravity constancy and native
material quantities. Packed episodes preserve **1,176 Sand cells**. The requested
worker count is read back at prepare/final; this capture does not identify every
pool worker's participation on every tick.

This checks the source's actual unit-mass contract, not physical density ratios.
Catalogue Sand1600/RedBrick1900/Wood720/Wall65535 are exchange/heuristic ranks;
SOL does not map them to body mass and Sand has no calibrated per-grain Newtonian
mass/velocity. Cap 3 is only about 0.376%/0.549% of these gravity impulses, but it
does not cap hard Rapier contacts or the separate opt-in Sand projection. That
ratio alone neither proves a bug nor licenses increasing forces. Dry runs show
no stale/wrong mass or gravity value. The actual total damping is approximately
0.14 linear/1.04 angular, including project damping.

## Reproduced defect and narrow repair

Baseline source `3f6014bb` executes eight dry720 and sixteen packed360 fresh
episodes on actual Windows/Linux, workers1/4. Their 53 new nonmutating
`NonDissipativeResponse` refusals are replayed against exact #393/#407 planners
on both Godot hosts. All 53 original refusal outcomes recur; scalar component
energy accepts 18 proposals with independently measured KE decreases
0.0377081901–743.1484958; 35 remain refused.

The replay has lossless eleven-double **body-state** envelopes and recorded,
reconstructed native witnesses. Original witness area/depth/weight used default
JSON formatting; bit identity of every original scalar witness is not established.
These reports are preserved. Fresh physical captures use full-precision JSON.
For the refused plans, there are no Sand impulses or await/physics steps between
the bridge's planner input and the captured state; ordinary response has already
run. This reasoning does not reconstruct preapplication state for accepted plans.

The repair calculates `vx*vx + vy*vy` in scalar64 instead of a float32
`Vector2.length_squared()` norm. Fresh pure tests reproduce the #407 controls:
104 cases/2,289 checks per host, with eight false refusals repaired and two old
false acceptances newly refused. Nine independent reducer mutation controls pass.

Fresh physical sources `ce6ae855` (dry) and `0ffa0b89` (packed) repeat the full
unchanged matrix from new sessions. Across 2,826 accepted repaired Sand responses,
independent scalar64 actual backend KE never exceeds the planner's unchanged
tolerance; maximum delta is zero for no-work outcomes. There are no terminal
readback failures. The production bridge still uses its original float32 energy
receipt and `1e-4` guard; those are not silently changed. Its largest receipt vs
scalar audit difference is about 0.00170241 at KE about 23,925.

## Physical result and limits

All **8/8 baseline and 8/8 repaired dry** episodes pass the registered final120
steps `[600,719]`: zero COM speed, omega, pose span and vertex speed, sleeping
throughout. Both structures actually fall, strike native hard terrain and topple
before resting. This is preserved behaviour, not a newly invented support force.

Strict clearance is separate. All sixteen dry cases fail the depth reference:
tree terminal Wall area approximately6.19947e-7 cell²/depth0.0007697546cell;
building area0.00258622026/depth0.0001733508. Tree area passes1e-6, building fails;
both depths fail2e-5. These may be small contact-scale residuals, but no contact-skin
explanation or tolerance change is admitted from this measurement.

Repaired response-On packed results below use paused post-trajectory Sand maps;
they are not complete synchronized final/recurrence clearance observations.

| Host/workers | Tree late peak speed / endpoint Sand area | Building late peak speed / endpoint Sand area |
| --- | --- | --- |
| Windows/1 | 5.19935 /17.5654 | 1.93808 /19.3577 |
| Windows/4 | 5.19935 /17.5654 | 1.93808 /19.3577 |
| Linux/1 | 5.22542 /17.6269 | 1.64617 /19.8693 |
| Linux/4 | 5.22542 /17.6269 | 2.78366 /19.7916 |

All 32 packed late windows remain nonquiet. The packed `[240,359]` screen is
descriptive, not the registered dry720 gate. Repaired On endpoint Sand depths
remain2.547–2.686cells. Repaired planner refusals remain **52 nondissipative +1
invalid geometry witness** (Linux/w4 building step185). Two ordinary
`DuplicateOrOldSample` refusals are separate. The baseline had53 nondissipative
refusals; identical totals do not erase the pure replay proof or demonstrate a
uniform live improvement. The full packet includes response-Off controls.

Inputs are common-setup, but asynchronous native/Rapier publication schedules
differ; these are observational comparisons, not schedule-matched causal A/B
trajectories. No thrust or player controls operate. No powered escape is claimed.
Sand arrival LA-SELECTIVE is not executable here as a matched arm: importing
#394 World/material semantics requires a separately admitted composition.

## Cost, energy and qualification

Both actual native extensions were built with complete SDK/compiler/linker and
source input inventories; native inputs remain identical through the repair.
Windows DLL SHA-256 `9e68d2d7927a2434ce60bd2d367498d9de72c010f28a52bc743fa7f9bad46abd`;
Linux SO `8bf350d9ef1f3cca81bbd7cc41018d2cd74d473a5259e83e2e62a69bbed4c172`.
Actual Godot4.7/Rapier hashes are in each receipt. Windows extension execution
uses LLVM-MinGW; it is not an MSVC extension claim. Actual Windows MSVC 14.44
passes four scoped native/model executables. Linux GCC 13.3 passes those four
optimized and four strict ASan/UBSan executables; leak detection is explicitly off.
Three cases exercise native geometry/World; lifecycle is a separately labelled
standalone model. Fresh actual Rapier response101/compound33-check fixtures pass
on each host. Four original600-step detachment tests also pass at their recorded
earlier source, separate from the48-episode denominator.

Observer-inclusive timings, all-attempt native/refused work, latency and capacity
counters remain in the comparison packet. New cohort allocation count is bounded
by source policy; this is not a universal latency/memory proof. The native suite
and pure diagnostic checks overlapped part of the repaired packed capture: its
timings are diagnostic host-load observations. The original inclusive24-group,
three-repeat, worst-unrounded-mean≤2ms CPU gate is **UNAVAILABLE in this lane**;
none of these timings replaces it or erases old failures. No 60 Hz guarantee.

Before→after_application KE includes ordinary coupling and Sand; correction
potential work is recorded separately from impulses. Scalar receipt-before to
actual-state-after audits the repaired Sand application. Cached hard impulses
are not summed as new work. Gravity, damping, hard contacts and native Sand energy
are not fully separated, so a closed total-energy/conservation proof is
**UNAVAILABLE**. Native material quantity conservation is independently checked.

Original 4 GiB artifact cap/5GiB free reserve remain; projects copy actual host
binaries only, with omitted-nonhost inventories. Final physical matrix artifacts
are about3.16GB decimal, with about20.4GB free at the receipt. Later reducers and
the public packet add separately inventoried bytes; outside native artifacts are
about217.6MB. No old evidence is deleted. The #394 workbench42.47MB arrival sidecar
and native-capacity quarantine are different-source findings, not resolved here.

## Decisions, admission and next action

| Decision | Source-bound result |
| --- | --- |
| Actual structural ownership/mass and dry fall/collision/rest | **PASS**, registered inert fixtures/hosts/workers only |
| Scalar energy-evaluation repair | **PASS**, replay/numerical and live application scope above |
| Dense-Sand structural settling/clearance | **NO-GO**, residual motion and overlap |
| LA-SELECTIVE intended primary gameplay candidate | **CONDITIONAL** owner direction retained; no new LA qualification here |
| Measured LA-SELECTIVE benefit to actual SOL | **UNAVAILABLE**, no admitted executable common-source arm |
| Original SOL physical clearance | **NO-GO**, historical failures unchanged and no new full acceptance clock |
| Source/ownership/MAT-AUTH integration | **NO-GO**, frozen consumer/runtime gates and composition admission missing |

Keep84/84 synchronized clearance failures,64/84 depth failures,36/36 async final
overlaps,1,452/1,452 corridor refusals, old CPU failures, hard Wall/RedBrick
exclusions, original material source hashes and#365 restoration block. Refusals
are not physical clearance. No SOL364-D clock is adopted.

Next is **actual structural contact/load diagnosis**: freeze a native/Rapier
publication schedule for a diagnostic replay, capture ordinary capped wrench,
correction and Sand contact support separately, and trace the52 genuine numerical
refusals plus invalid witness. Establish physical relative-weight units before
any mass/cap/gravity tuning. A new prospective support/recovery law requires its
own work/energy registration and, if cross-owner capture/application is needed,
E1/E2 authority admission. Do not resume flyer support experiments as SOL proof.

LA primary-default promotion remains a later #394-source task: qualify selectable
legacy LA/LA-EVENT-OFF/RFT controls, supported desktop modes and per-material liquid
policy, then seek independent review and owner approval. This branch changes no
accepted default. Independent read-only reviews approved the scoped numerical
repair and corrected reduction; request a **separate independent adversarial PR
review before an owner decision**. Keep the new dependent PR Draft against #393.

## Documentation and validation map

Canonical semantics: detachment contract; operational checkpoint: handover;
qualification commands: local build guide; remaining work: roadmap; discovery:
documentation/retrieval indexes and additive post-result questions. Native
ownership/ADRs/interfaces/capacity, authoring catalogue, Water, fleet controls,
painting and save/load implementations are unchanged. Frozen questions and past
audits retain their original content. [Validation](sol-structure-cut-20261106/validation.json)
records current checks and source identities. Missing platform/material/runtime
admission is a blocker, not a pass. Initial apparatus/CLI/doc failures remain
listed in the manifest rather than being relabelled as physical outcomes.
