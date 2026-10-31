---
title: Granular bearing and pre-overlap response investigation
status: Planned
document-kind: guide
scope: Measurement-first causal successor to the A2 finite-cohort local-rearrangement no-go; no bearing changes approved here
canonical-for: [granular-bearing-pre-overlap-investigation]
last-reviewed: 2026-10-31
related-documents: [../audits/2026-10-31-physical-detachment-a2.md, ../architecture/rigid-body-and-cellular-coupling.md, ../systems/granular-interaction-policy.md, ../reference/status-and-roadmap.md]
---

# Granular Bearing / Pre-Overlap Response Investigation

## Question and admission boundary

Why does a rigid rectangle reach locally saturated overlap states with no
admissible nearby displacement endpoint? A2 closes bounded one-to-four-parcel
push chains as the primary solution in its measured Sand/drop cohort. This
successor investigates the upstream response, without treating a wider radius,
longer chain, broad compaction or a bearing gain change as the assumed answer.
Generic body/granular ownership remains the existing coupling contract and
REM-004 / #83. This document specifies a future experiment, not runtime policy.

## Current measured premise

The [A2 evidence](../audits/2026-10-31-physical-detachment-a2.md) retains the same
600-tick, one-worker, 8×14 real Rapier rectangle and 32×48 Sand bank as #336.
The source-matched trajectory records:

| Observation | First bearing | First ejection/no-target | Maximum entry / first slow correction |
|---|---:|---:|---:|
| Frame | 68 | 69 | 87 |
| Input vertical velocity, pixels/s | 91.9046 | 87.0771 | 3.8970 |
| Qualifying support samples | 3 | 6 | 16 |
| Nominal bearing / requested net / accepted net Y impulse | −6 | −12 | −1.9588 |
| Lower oriented extent below initial surface, pixels | 0.6711 | 2.1143 | 8.9647 |

Bearing engaged before the first raster ejection. It was delivered: all 600
frames had age zero and exact requested/accepted net-impulse equality. Nominal
bearing equalled requested vertical net impulse in all 439 bearing-active frames.
The first two bearing frames were support-capacity limited; frames 70–87 were
yield-limited. The global bearing cap of 20 was never reached; the maximum
observed bearing magnitude was 14.99035. Thus raising that global cap is not
supported by this run. Generic intermediate caps occurred, but did not attenuate
the recorded vertical bearing handoff.

The existing native law has no penetration-depth term. For this mass-one case:

```text
reference gravity impulse = 92 / 60
arrest = vy
yield = 92/60 + max(0, vy - 92/60) * 0.18
capacity = min(20, support_samples * 2)
bearing_y = -min(arrest, yield, capacity)
```

See native `accumulate_granular_bearing` and `rigid_body_results` in
[the adapter](../../godot/native_extension/cyber_native_cell_world.cpp), and
`World::granular_support_at` in [World](../../native/src/world.cpp). Support
requires a stable granular load-bearing cell and at least eight qualifying cells
in its three-by-three support neighbourhood. Published support count is assigned
only after descending-velocity/positive-bearing gates. Zero published count for
a rising or stationary body is not evidence that geometric support disappeared.

The first slow correction at frame 87 was −0.05508 pixels. The bridge zeroed
opposing positive vertical velocity before applying the accepted upward impulse;
the next sample was rising. Of 1,231 failed attempts, 635 occurred during exit
and 596 during descent. Count repeated exit contacts separately from first entry.
No ejection attempts occurred in frames 200–599; those frames retain a small
settling/correction cycle. The body was not fully buried: its upper extent stayed
above the initial surface. Initial-surface depth is a reference, not the changing
local grain contour or the captured per-cell penetration metric.

## Strongest specific hypothesis

High incoming momentum meets a deliberately bounded, yielding response whose
initial support capacity and then yield term limit braking over several steps.
Velocity-gated positional correction begins only after the body has slowed and
already entered the bank. This is a supported causal hypothesis, not a proven
defect or an approved request to increase impulses. The current trace argues
against absent delivery, stale rejection, global-cap saturation and a complete
support-sampling collapse as explanations for this synchronous fixture.

## Exact next measurement experiment

First reproduce the four-height A2 drop and a matched one-height arm based on the REM-002
control using the same bank, body/mass, initial orientation/angular velocity,
default gains, seed, fixed timestep and one native worker. Use fresh owners and
reset receipts. Keep the compact boundary channels for all 600 ticks, as A2 did.
If additional detailed channels need a shorter window, preregister it: retain
20 buffered ticks before first raw support until 30 consecutive ticks with zero
stored movable material under the endpoint body mask, falling back to tick 599
when that clearance condition never holds. Rising alone is not exit. Retain every
failed and successful contact with the existing two identities.

The primary comparison is incoming momentum versus cumulative accepted net
impulse, with nominal bearing and pre-bearing generic terms recorded separately, first no-target onset, maximum body entry and unresolved overlap.
If the one-/four-height comparison supports the momentum hypothesis, register a
second finite initial-velocity series before running it: lower body extent two
pixels above the initial bank, vertical velocities 0, 30, 60 and 90 pixels/s,
with initial orientation 0.08 radians, zero initial angular velocity and all
response laws fixed. This is an explicitly separate zero-spin control: changing
drop duration in the spinning one-/four-height arms also changes orientation at
contact, so their differences alone cannot isolate momentum. Record achieved
orientation and raw support geometry in every arm. Set velocity only at
initialization. These are diagnostic fixture arms, not per-tick forced motion.
Do not change bearing gains or add prediction/correction policy in this phase.

Record once per native/physics boundary:

| Channel | Required values and interpretation |
|---|---|
| Identity/time | World incarnation/reset, native attempted/completed tick, packed sample serial, fixed delta, producer/consumer timestamps and sample age |
| Body motion | Previous/current transform, linear/angular velocity before Rapier step, after step, after correction and after impulse; finite-difference acceleration with those boundaries explicit |
| Geometric contact | Oriented lower extent, per-cell penetration distribution, current grain-contour clearance, normal/nearest face, newly overlapping cells versus persistent overlap |
| Candidate saturation | All 81 candidate reasons, occupied/unmasked-empty fractions and transition into first no-target; preserve repeated events rather than treating them as independent improvements |
| Support | Raw geometric boundary candidates and qualifying stable-support count **before** velocity gates, published count, failed predicate categories and neighbourhood occupancy |
| Bearing law | Gravity/reference term, arrest, yield, sample capacity, global cap, active limiter, nominal requested bearing vector |
| Other native response | Raw displacement/reaction, boundary and pixel-contact sums, incremental/final generic cap events, final requested net impulse and requested positional correction |
| Delivery | Accepted total net impulse, correction eligibility/age suppression, correction actually applied and any velocity zeroing; distinguish nominal bearing from an inferred marginal contribution |
| Rapier | Available per-contact normals/impulses, hard-body contact count, gravity/damping inputs and explicit unobserved residuals; do not label a velocity residual a measured contact force |

Use copied value observations owned by the existing simulation owner. Live
Rapier/scene objects remain main-thread owned; native pool workers call no Godot
APIs. Never call `pack_body_states()` extra times merely for observation, since
that increments sample serial. Observe the cached single packed sample instead.
Any new diagnostics must be opt-in, bounded and report saturation explicitly.

## Failure-mode adjudication

| Hypothesis | A2 evidence | Next discriminating observation |
|---|---|---|
| Response starts too late | Bearing precedes raster ejection by one frame, but the lower oriented extent is already 0.67 pixels below the initial surface | Compare pre-step current-contour clearance, first raw support and first accepted braking, not just initial-surface depth |
| Support sampling collapses with penetration | Initial published samples grow 3 → 6 → 16; rising zeros are gated | Publish raw qualifying count before velocity gates and distinguish instability, masking and loss of actual support |
| Bearing saturates | Initial sample capacity then yield limits braking; global 20 cap is unused | Record each limiter and stopping distance across entry-speed arms |
| Impulse insufficient relative to momentum/gravity | First incoming `vy≈91.9` receives −6, then −12 on the next sample | Integrate actual accepted net impulse and measured motion over the braking window; compare matched lower-speed entry |
| Correction too small or too late | First correction requires `vy≤4` and occurs at peak reference depth | Separate the correction trigger, requested amount, applied amount and velocity zeroing; do not infer a gain fix |
| Cadence/freshness permits excess entry | A2 is synchronous with age zero throughout | Establish the synchronous cause first; any later asynchronous arm must match motion/terrain and report age/correction suppression separately |
| Other terms cancel or clamp bearing | Recorded requested and accepted vertical net equal nominal bearing on every bearing frame | Preserve term accounting; add backend channels before attributing unexplained residuals |
| Body asks for more displacement than free volume permits | 1,094/1,231 A2 failures have no interior void; lengths 2–4 add zero recovery | Relate first volume saturation to entry momentum, support/clearance and overlap growth |

Pass the **measurement** gate only with exact source/runtime identity, complete
bounded traces, diagnostic-neutrality controls, material conservation and an
independently reviewed causal account. A later owner-approved response experiment
must be justified by that account. Neither this plan nor A2 admits a production
bearing change, generalized granular compaction or broad gameplay acceptance.
