---
title: Soliding macro-dynamics and fracture fixture preregistration
status: Planned
document-kind: runbook
scope: Blocked Stage 6 and 7 fixture specification for real Rapier rotation and coherent-child motion inheritance; no implementation or acceptance claim
canonical-for: [soliding-macro-fracture-fixture]
last-reviewed: 2026-09-19
related-documents: [soliding-programme.md, ../architecture/soliding-lifecycle.md, soliding-measurement.md, ../audits/2026-09-19-issue-12-phase0-reuse.md]
---

# Macro-dynamics and coherent fracture preregistration

## Entry gate and evidence boundary

**Planned, blocked fixture:** the reviewed standalone lifecycle is sufficient to
state these obligations, but is not an integrated ownership kernel. Do not run
this as production acceptance until Stage 6 has a source-matched native registry,
worker/main-thread fences, exact payload accounting, body/shape/destination capacity,
failed-world handling and current #11 support/coupling prerequisite disposition.
Retain the current [programme](soliding-programme.md) order. This preregistration
reduces future ambiguity without admitting a dynamic runtime port.

The [Phase 0 audit](../audits/2026-09-19-issue-12-phase0-reuse.md) shows that its
quarter-turn was externally assigned to a rotation-locked body. These fixtures
require ordinary angular integration and off-centre torque. No repeated manual
transform writes may manufacture a rotational pass. No generic cellular velocity
or #20 carrier is a prerequisite for coherent fragments.

## Frozen recipe families before runtime implementation

Use only exact rectangles first, with authored homogeneous RedBrick payload and
explicit supported material/state admission. Copy exact material/state/temperature
records at the ownership fence. No material is converted into Sand, deleted, or
made cohesive to simplify a fixture. Native cells initially contain the recipe;
near-rest admission supplies zero/known initial velocity, not guessed history.

| ID | Recipe and stimulus | Primary observable |
|---|---|---|
| MD-01 | 8x14 coherent near-rest rectangle above a flat supported floor; remove admitted support after promotion | Gravity creates nonzero downward COM velocity; contact stops/deflects it without lost payload |
| MD-02 | 8x14 admitted body; one declared off-centre impulse at a known body-local point, plus centre-impulse control | Off-centre impulse produces the declared angular-velocity change; centred isolated control adds no angular velocity; existing free spin continues |
| FR-02 | 16x12 rectangle in free flight after MD-02-like impulse; authored vertical topology partition at x=8 into two 8x12 coherent children | Both children remain bodies, exact partition, inherited translational and rotational point velocities |
| FR-03 | 24x12 rectangle; authored partitions at x=8 and x=16 into three 8x12 coherent children | Three distinct generation-bearing children, conserved payload, no whole-body cell demotion |
| FR-CHIP | Conditional later arm after merged-rectangle/orthogonal geometry admission: parent with a small separable corner, partition into the large remainder and small coherent fragment | Large unaffected membership stays aggregate-owned; bounded geometry/contact rebuild; not part of the rectangle-only entry gate |
| FR-CAP | FR-02/03 with one fewer free child/body/shape/result slot than required | Whole request defers/refuses; original body/payload remains authoritative and motion is not reset |

The partition request is an explicitly authored **test topology event**, not a
new material damage/reaction law or universal structural-integrity simulation.
Its production physical trigger must later cite the actual material/interaction
policy. First test partitions have no removed cells and **zero loose debris**;
therefore zero cellular emission is the truthful result. A later nonzero debris
arm requires evidence that those members are genuinely loose under existing or
separately admitted material/state semantics. Do not infer looseness from fragment
size or arbitrary visual effect. Preserve exact tuples and explicitly account any
admitted reaction/source/sink event. #29 remains the semantics owner.

Register frame/event indices, initial placement, free-flight clearance, initial
orientation, impulse point/vector, selected step size and repeat schedule in the
fixture data before collecting result data. Use translations across block/chunk
seams and a mirrored impulse/control. Pin source, runtime hashes, Rapier/Godot
versions, world/profile policy, native worker count and platform ownership mode.
A test-only scenario event requests the engine transition; scenario code may not
perform per-frame material writes or implement fracture ownership itself.

## Units and motion ledger required before execution

The fixture manifest must supply and justify length units per cell, Rapier time
step, mass-per-admitted-cell mapping, density source and centre-of-mass convention.
Current material density values used for sorting/contact heuristics are not
silently physical mass calibration. Freeze shape mass/inertia derivation and
friction/restitution/gravity settings. Initial angular state is zero/known; all
subsequent motion must arise through admitted Rapier dynamics or declared impulses.
Missing units block the fixture; they are not filled by guessed constants.

Sample parent rigid state at the fenced split: COM c, linear velocity v, angular
velocity omega, mass M and inertia I about c. Child i gets its recomputed m_i,
c_i and I_i plus v_i = v + omega * (-(c_i.y-c.y), c_i.x-c.x). Inherited omega_i
is omega for a pure partition without separately sourced fracture impulse.
Use a fixed common origin for angular momentum comparisons. Record before/after:

- exact member identity/tuple census and cells/stationary/aggregate owner counts;
- total linear momentum sum(m_i*v_i) and parent M*v;
- angular momentum sum(I_i*omega_i + cross(c_i-origin, m_i*v_i));
- kinetic energy sum(0.5*m_i*|v_i|^2 + 0.5*I_i*omega_i^2);
- external gravity/contact/fracture impulses over the sampled interval;
- parent/child transform, COM, angle, angular velocity, shapes and contact count.

Separate the immediate no-step transfer error from subsequent contact/integration
error. Exact raster partition with consistent mass/inertia supplies an analytic
reference; geometry approximation and floating-point integration require measured,
preregistered tolerances after an independent numerical calibration arm. Do not
choose an error band after viewing a desired fracture result. A body-wide reset
to zero velocity is a failure regardless of visually plausible debris.

## Required failure and ownership probes

Before play/Inspect acceptance, run stale generation/token, duplicate ACK, cancel,
failed body construction, full registry/queues/shapes/payload/destination, support
change during preparation, exclusion/re-entry and injected postcommit failure.
Precommit refusal preserves the parent; postcommit failure retains the committed
owner under quarantine. Test exact one-owner membership across repeated
fracture -> settle -> readmitted representation cycles, with copied immutable
observations and no stale-parent collider self-contact or collision hole.

New children must not begin in pathological self-overlap. Freeze sibling contact
separation/filtering policy before accepting collision results; do not hide energy
injection with a larger motion tolerance. Keep geometry complexity, queue high-water,
partition/build time and native/main-thread budgets alongside mechanics results.

Run real desktop asynchronous and supported native Web sequencing after native
contract acceptance. A pure model, native CLI, compile, or scripted quarter-turn
is not equivalent to actual Rapier rotation/fracture execution. Save/export must
explicitly refuse/drain unsupported aggregate or pending states. Exact replay is
not implied by a capture. Preserve every failed, ambiguous and negative arm and
name the next prerequisite rather than changing the recipe to make it pass.
