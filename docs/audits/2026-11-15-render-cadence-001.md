---
title: POSE-TRACE-001 and RENDER-CADENCE-001 causal repair
status: Current
document-kind: evidence
scope: Separate Draft/HOLD continuation of #609; confirmed bounded mechanisms, exact-source experiment apparatus and unresolved independent-clock architecture
canonical-for: []
related-documents: [../operations/engine-lab-pose-tracing.md, ../architecture/rendering-and-gameplay-bridges.md, ../architecture/rigid-body-and-cellular-coupling.md]
last-reviewed: 2026-11-15
---

# Native-pixel and actor cadence: bounded causal repair

**Draft/HOLD. No merge, Ready transition, production runtime or default physics
promotion.** The separate branch `fix/render-cadence-001-20261115` starts at
#609 `01a8416761ba3477a2587d7b07a854945b0f0286`, retaining #606, #593 and #566
ancestry. #582 is outside this work; it is not a merge or test dependency.

The owner's Windows NVIDIA observations are the motivating evidence: slowing
native material ticks lengthens apparent freezes and catch-up, graphical FPS can
remain near 60 while native throughput is 10–20, and changing ACK policy affects
judder. These observations must be tested against achieved clocks, not dismissed
by successful software-renderer assertions.

## Source-fenced intake

| PR | Reviewed head | Role |
| --- | --- | --- |
| #566 | `214de85adef2aaabc8e26de8612a3bf27cc1a081` | Native display-pixel camera and qualified native binaries |
| #593 | `9628729af052b417aa8a64e56f7e7bcdf4f2e876` | Guarded live versus uploaded-mask pose selection |
| #606 | `2632422aa67ee9acdc347089cd54c36e518c713a` | Engine Lab clock and ACK controls |
| #609 | `01a8416761ba3477a2587d7b07a854945b0f0286` | Actual-submission pose trace and offline Test It runner |

The original [Windows package and test run](https://github.com/techrote/cybersand/actions/runs/43670077510)
remain historical evidence. Original raw Test It archive artifact 14144256526
SHA-256 is `277d10f6852512489065429f980fa06d1238328fc28ee14f2d7f88630a5b359f`;
its pose JSONL SHA-256 is
`25221279016d319af3cf97c8439ba93f353da7a1979f855bb1f5b63c41b2aca7`.
No old artifacts, receipts or review history are rewritten.

Independent reduction of that hosted Windows ANGLE trace found 43 Main
submissions spanning 10.066606 seconds: 4.1722 submissions/s, 33 native tick
advances (3.2782/s), and 34 observed Rapier advances (3.3775/s). Median/p95/max
submission gaps were 239.5355/444.136/674.402 ms. There were 28 frames with
`previous_texture_unbounded`, 14 live/mask source changes, and approximately
0.0001 px maximum intended projection residual. Several source changes had zero
visible jump. This is strong evidence of slow completion and history pressure,
not reproduction of the owner's severe physical-GPU symptom. The receipt's
requested 240×135 view differed from the actual traced 480×270 view.

## Pipeline and competing mechanisms

1. The worker latches immutable body samples and owns native World mutation.
   A successful `simulation_tick()` completes before render-byte extraction.
2. `_publish_snapshot()` copies immutable material, terrain and mask receipts.
   A status snapshot may advance without replacing the retained material bytes.
3. Main consumes the newest snapshot and uploads complete CPU Image data through
   `ImageTexture.update`, even when the native payload contains small patches.
4. GPU textures ping-pong. The shader may blend current and previous material
   colors at the same World coordinates; this is not motion interpolation.
5. Follow requests a camera centered on live Rapier. The native-pixel mapping
   snaps its physical screen translation once. The actor overlay uses the same
   presented origin but can submit a different, older mask-bound actor pose.
6. Main queues the overlay and material shader parameters. A post-draw signal
   marks Godot's rendering boundary; monitor presentation and GPU fences remain
   unmeasured here.

### Confirmed: large-payload history causes artificial pose switching

In the #609 source, Main's `_capture_previous_presentation_occupancy()` discards
knowledge of the entire previous texture when changed patch area exceeds
16,384 cells. `WorkbenchPresentationCoherence.assess()` then refuses every live
pose during the shader's active blend interval, even for an actor in unchanged
empty space. Once the interval expires, it can admit live again. The next large
upload restarts the interval and can restore the older mask endpoint.

This is a publication-phase discontinuity, not an inverted camera matrix.
Follow uses the live position during both phases, so the stale overlay moves
relative to the followed terrain. Free camera still exhibits the same World
pose selection jump.

**Repair:** retain the exact pre-mutation CPU image corresponding to the GPU
`previous_world_texture`, and inspect old occupancy locally within the existing
swept-mask query. An oversized transport payload no longer means unknown
occupancy everywhere. Native material, body masks, physics, shader appearance,
transform formulas, scan/time budgets and actual material vetoes are preserved.
Only one extra World-sized image is retained: 8 MiB for 2048² RG8. The legacy
control retains the original unknown-history rule for source-matched A/B.

### Confirmed: delayed ACKs can starve under continuous uploads

The original Main ACK implementation restarts its countdown on every upload.
If uploads arrive each frame and delay is at least two frames, the countdown
never expires. This contaminates an intended bounded-delay experiment.

**Repair:** each accepted upload receives a fixed due process-frame. Uploads
with the same due frame coalesce to their highest serial. Pumping retires due
serials without postponement; delay zero flushes pending accepted uploads.
The queue has at most four future due-frame buckets with the existing 0–4
setting. No ACK can authorize an unconsumed material packet.

ACK is an upload-submission acknowledgement, not a GPU fence. The ordinary
worker retains cumulative patches until ACK catches the latest pending serial;
positive delay under a continuous ungated stream can therefore still accumulate
patches. The deadline repair does not claim a new incremental-retention design.

The diagnostic default-off publication gate changes only whether new render
bytes are extracted before the previous upload is acknowledged. Native ticks
and status continue. Explicit full resync and accepted World replacement bypass
it, avoiding a deadlock when a rejected upload cannot be acknowledged.

### Confirmed: normal Workbench physics is coupled to native completion

`Main._physics_process()` waits for `workbench_completed_sample` to match the
previously published body sample. The worker avoids ticking the same sample
twice. Reducing native throughput therefore holds the actual Rapier state in
the normal path. A 60-FPS graphical window does not establish 60-Hz physical
motion. This is a physical scheduling limitation in addition to the repaired
presentation discontinuity.

The existing lab bypass permits a responsive-Rapier counterfactual. Its
one-step native-response age limit, geometry/epoch validation and terrain-install
fence remain intact. Delayed native contact responses can be refused. This mode
cannot be promoted as correct asynchronous material coupling solely because
air-flight presentation improves.

### Rejected narrowly: a static camera sign or double-transform defect

For one submitted World pose, the intended shader and overlay projections use
the same screen translation and basis. If `B` is the screen basis and `T` is the
snapped translation, both produce `T+B*pose`. Subtracting the common World-zero
screen point removes camera translation and exposes actor selection changes.
The original measured residual and the new independent projection oracle agree.
This rejects a static algebraic double subtraction in those tested paths. It
does not establish physical scanout timing or reject every layout/driver issue.

### Unresolved: interpolation and genuine contact holds

The actor path chooses completed endpoints; it has no presentation interpolation.
At 60 actual steps and 120 graphical frames, repeated poses are expected.
The material crossfade does not interpolate actor motion or native material
transport. Genuine material intersections, too-large deltas, unknown reset
history and exhausted sweep budgets still select the conservative bound pose.
The candidate does not disguise these holds with smoothing or freeze Rapier.

## Executable experiments and qualification boundaries

The [runbook](../operations/engine-lab-pose-tracing.md) and committed
[condition matrix](../../godot/tests/fixtures/engine_lab/render-cadence-conditions.json)
define the exact orthogonal controls. They extend the original 2048² reference
and deterministic Needle tape. Pixel, material publication, graphical FPS,
Rapier callback rate, camera, pose selection and ACK policy are distinct axes.
Every condition receives legacy/repaired controls from the same source.

The original eight tape entries remain intact; Cadence appends sustained motion
at ticks 30/90/120. All inputs are tied to completed physical steps. The fixed
1/60 physical timestep is unchanged; matching is by completed step, not equal
wall time. Changes in physical trajectory are reported rather than attributed
automatically to rendering. Captures occur outside timed measurements.

| Regression | What it proves |
| --- | --- |
| `test_render_cadence_contract.gd` | Actual native World/full publication/Kestrel RID; old-history phase jump versus exact previous-image repair, Free/Follow, GPU framebuffer and prior-texture readback when graphically executed, real Wall veto |
| `test_render_ack_deadlines.gd` | Production Main ACK scheduler, continuous-stream negative control, deadlines, bounded storage and flush |
| `test_render_cadence_worker.gd` | Actual native completion events, unread-snapshot resilience, publication-only gating, resync/reset progress, bounded trace and generation isolation |
| Existing #593 and #609 tests | Swept collision safety, real PAINT old material, guard budgets, production selection, Engine Lab and trace preservation |
| Original Test It extended matrix | Real 2048² source identity, deterministic tick actions, achieved clocks, original event/pose traces, per-step physical comparisons and framebuffers |

Initial local Godot 4.7 native results: the mechanism test passed 65 assertions;
it measured 14.0247 px phase-only jump under legacy and 0.0 px under repair in
both camera modes, with unchanged material and physical state. Its genuine
native Fire-to-Empty PAINT case also retains old GPU-visible material authority.
ACK deadlines
passed 108 assertions; worker instrumentation/gating passed 43 assertions. The
original pose-trace regression retained all 24 assertions and original render
handoff passed. These are local headless results, not graphical acceptance.
The first ACK fixture incorrectly counted a deferred/first-frame boundary; the
corrected fixture counts distinct observed Engine frames. The first mechanism
fixture misdeclared its Wall negative; correcting the authored rectangle made
that negative actually test Wall. Original failed local logs remain external
evidence, not reclassified passes.

Exact-source CI uses the existing qualification workflow with its source/native
guards preserved. Linux performs actual graphical native runs under Xvfb;
Windows extracts and hashes the original deliverable, runs the installed
PowerShell 5.1 test and graphical native regressions. Each run retains its
source identity, logs, PNGs, receipts, original JSONL and independent reduction.
Consult the run for the tested commit, not an older green parent. A hosted
software renderer is never a physical TITAN RTX acceptance result.

## Integration disposition and follow-on boundary

The bounded repair is suitable for **conditional technical review** only after
its exact-source Windows/Linux jobs and preserved-feature regressions complete.
Full independently paced real-time physics/presentation remains **HOLD** pending
an asynchronous coupling contract and real Windows NVIDIA acceptance. No merge
or default physics change is authorized by this branch.

The required next architecture is a separately reviewed timestamped coupling
boundary: completed native material/terrain epochs; completed Rapier states with
fixed simulation time; render-time sampling from a bounded pose history; one
camera/overlay presentation timestamp; explicit handling of stale material and
late native contact impulses. It must conserve/correct material-contact effects
without applying stale wrenches to unrelated poses or fabricating native state.
Keeping 1/60 physical steps with 120 callbacks is a scheduling experiment, not
true real-time 120-Hz physics. Supporting a 1/120 integrator requires validation
of flight/control and coupled response semantics rather than changing a label.

### Planned: precise independent-clock boundary

The following is a follow-on design, **not implemented or accepted by this
candidate**. It preserves one native World writer and Main-owned Rapier.

| Record | Required identity and time |
| --- | --- |
| Completed physical state | World generation, session, epoch, actor generation, physical step and simulated time, monotonic completion, input identity, pose/velocity, material response identity consumed |
| Completed material state | World generation, material revision, native tick and simulated time, monotonic completion, terrain revision, body sample used for its mask |
| Material transport | Base/target serial, immutable material identity, extraction interval, worker handoff, Main receipt, CPU upload submission and ACK; current and previous GPU slots retain their corresponding identities |
| Graphical submission | One selected physical presentation time, actor pose, requested camera and presented camera transform; all overlay and shader inputs come from that submission record |

Preserve the fixed sixty-step law initially. A wall-time accumulator advances
1/60-second physics steps, records overload explicitly, and permits faster input
sampling and graphical submission. Interpolation uses two completed physical
samples at a declared presentation time, normally one physical step behind that
clock. It must not wait for every native material tick. Missing samples expose
their age and a bounded fallback; arbitrary extrapolation is not a substitute
for actual progress. Follow camera is evaluated from the same presentation pose
as the overlay, then both shader and overlay use one spatial transform.

A true 1/120 integrator is a separate opt-in law/semantics change. Validate
controller gains, forces versus impulses, damping, time-based leases, action
tape time and material response integration at equal simulated seconds. Do not
label doubled fixed-1/60 throughput as normalized 120-Hz physics.

For asynchronous contact, the current one-step native-response age/geometry
fence cannot simply be widened. A bounded first proof can certify empty air or
unchanged static terrain around a body's swept region. Such a certificate names
the material/terrain revision, actor identity/shape, region, valid motion/time
interval and invalidation conditions. Paint, erase, emitted or incoming dynamic
material, actor replacement, reset, expired bounds and terrain changes invalidate
it. Hard terrain collision stays active. Regions without a certificate retain
the existing safety boundary and are explicitly outside the independent-rate
claim.

Dynamic granular/liquid response needs a reviewed interval-based coupling law.
Requests describe bounded physical history or sweeps over the native interval;
responses identify that interval and the material sample from which force,
impulse and correction were derived. Consumption must establish applicable
identity, time and geometry, and exactly-once application. Sample-and-hold,
delayed response and rollback/reintegration have different energy and control
consequences; none is silently selected here. Rejecting stale contact effects
preserves an admission check but does not establish accurate interaction.

Transport retention should retire an acknowledged **prefix**, independently of
the newest producer serial. A bounded per-tile version journal or immutable
batch journal can retain newer changes while ACK N releases only content fully
represented by N. Payloads declare a base and target; skipped intermediate
versions must still reconstruct that target. Missing bases and rejected payloads
request an explicit full resync, which cannot be blocked by the experimental
ACK gate. This design addresses the remaining ordinary-stream accumulation
without turning delayed upload acknowledgement into a global simulation clock.

Admission proceeds from the fixed-law clock/interpolation proof, through empty
air and static-wall certificates, then paint/erase, material intrusion, missed
snapshots, resets, Undo/Redo, actor replacement and shutdown. Dynamic contact
requires appropriate mass, impulse, torque and energy checks. Physical Windows
NVIDIA and Linux graphical evidence, identical completed-step input controls,
original traces and exact-source artifacts remain required at each claimed
boundary.

Do not replace the confirmed history repair with another pose mask, force all
actors to wait for textures, slow Rapier to hide the defect, or infer physical
GPU smoothness from CI. The owner package exists to test the remaining physical
display boundary with the same source and original evidence collection.
