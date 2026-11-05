---
title: Authored gravity and damping operator qualification
status: Current
document-kind: evidence
scope: Actual-host no-contact operator compatibility evidence; no predictive contact or SOL authority
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [2026-11-05-sol-contact-application.md, ../architecture/rigid-body-and-cellular-coupling.md]
---

# Gravity/damping operator oracle — 5 November 2026

[SOL-GRAVITY-OPERATOR-001](../../native/tests/fixtures/sol_gravity_operator_001.json)
is registered before new operator outcomes. The preceding contact/application
experiment completes48episodes/28,800applications and rejects retain-linear:
support and geometric sinking worsen. Baseline end-of-window speed can conceal
large motion earlier in the same tail. This motivates source-qualified integration
measurements before a different support predictor; it does not admit that predictor.

The [Godot direct-state API](https://docs.godotengine.org/en/stable/classes/class_physicsdirectbodystate2d.html)
exposes total gravity, damping and step. The pinned addon forwards automatic
damping to Rapier, while its manual direct-state helper uses a distinct linear
law. The inspected crate-version source uses rational damping. Source/blob links
are in the registration; none substitutes for actual automatic integration.

The oracle preserves authored barrel/Kestrel/Scooper properties in fresh empty
private Rapier spaces, with three declared initial motion states and32steps on
each actual host. It applies no native contact, controller force or predicted
load. All four preregistered model equations are evaluated without fitting;
missing properties remain unavailable. Native World/worker participation is
not applicable. Keep Draft and preserve the original SOL/ownership gates.

## Actual execution and fixed-model evaluation

**Current source-bound qualification:** operator003 executes at
ef106ff7ab04b190d3b481784ecf4e8aaf8a1bb1; final independent analysis is
5198ba5fd1a38e2a987330adca0bb73edf627c23. Actual Windows Godot/Rapier and WSL
Ubuntu/Linux each pass1182fixture checks in nine fresh sessions:18episodes,
576body-steps total. Source/project post-inventories agree. Each session removes
the bridge's empty static terrain RID, performs one neutral prime, restores
authored gravity and initial motion, then takes32single manual steps. Authored
`can_sleep` is retained; an explicit awake-state setter precedes each observation.
No native World, coupling packet, controller advance, force, impulse or Area
override is used. Session controller objects exist but are not advanced.

Both actual Python hosts pass16equation/corruption tests and complete independent
reduction. Parsed results agree exactly (raw Windows/Linux JSON newline bytes
can differ). These two analyses add no physical episodes. Finite pose/COM/mass,
gravity bits, no-contact/no-force/awake state, single-step order, initial motion,
shape type/dimensions/local transform and complete coverage are checked. Actual
server shapes equal the authored rectangle unions, including Scooper's five
pieces on one body. No520-member original SOL shape is claimed here.

Only gravity-then-rational-damping is compatible with the registered maximum
**one-step** error≤1e-5 across all observations. It is not exact engine replay.

| Preregistered equation | Maximum one-step error, float64 | Maximum one-step error, explicitfloat32 | Compatible |
| --- | ---: | ---: | --- |
| Gravity only |0.1949211121|0.1949195862|No|
| Gravity then rational damping |5.191787146e-6|7.629394531e-6|Yes|
| Rational damping then gravity |0.0063746741|0.0063743591|No|
| Gravity then linear damping |0.0008169079|0.0008163452|No|

The compatible model's maximum accumulated32step errors are4.317107545e-5
and5.340576172e-5 respectively; no full-trajectory1e-5 pass is claimed. Equations
retain declared1/60dt; measured direct step0.0166666675359011 is recorded
separately. No retiming, fitted multiplier, extra warm-up or threshold change
was introduced. Explicitfloat32 uses rounded operations/reciprocals; float64
evaluates the same declared rational expression without those casts.

| Authored body | Measured gravityY | Effective linear damping | Effective angular damping | Damping policy |
| --- | ---: | ---: | ---: | --- |
| Barrel |92.1199951171875|0.25|1.35000002384186|Combine|
| Kestrel |38|0|0.180000007152557|Replace|
| Scooper |38|0|0.180000007152557|Replace|

The barrel's approximately0.15linear/0.35angular node values combine with project
0.1/1.0. Actual mass/inertia differ:1/21.66666603,0.10000000149/0.97500002384
and0.18000000715/24.79013634. The reducer records project×body nominal gravity
and combine/replace damping differences without adding a new tolerance gate.
Effective gravity is not yet authenticated against a native owner's sampled
nominal gravity; that binding is **UNAVAILABLE** because this oracle has no native
owner. A future predictor must establish direction, scale and actual coefficient
provenance instead of substituting a flyer's nominal38 for the barrel's measured
gravity.

## Evidence, failures and limits

The [full evaluation](sol-gravity-operator-20261105/comparison.json),
[execution receipt](sol-gravity-operator-20261105/execution.json),
[analysis receipt](sol-gravity-operator-20261105/analysis.json), complete
[Windows](sol-gravity-operator-20261105/windows-observations.json) and
[Linux](sol-gravity-operator-20261105/linux-observations.json) observations,
[custody](sol-gravity-operator-20261105/custody.json) and
[retained attempts](sol-gravity-operator-20261105/retained-attempts.json) preserve
source, actual-host runtime hashes, commands, durations, timeouts, exits and
raw-log identities. Public receipt JSON uses LF; build receipts retain original
byte hashes. Raw logs/copies/binaries stay under `build/sol-gravity-operator`.

Reproduce physical measurement with
`python tools/experiments/sol_gravity_operator.py --run <new-name>`; each import
and oracle command has300s timeout. Reduce with
`python tools/experiments/sol_gravity_operator_reduce.py build/sol-gravity-operator/<run> --output <new-directory>`.
Actual-host Python analysis commands use60s. Operator001 completes894checks
per host with the earlier `can_sleep=false` apparatus. Operator002 fails both
hosts at script parse (unsupported `body_is_shape_disabled`) and has no physical
oracle observations. Operator003 replaces that query with the pinned
`CollisionObject2D.is_shape_owner_disabled` API and qualifies authored sleep
properties. Original samples/failed attempts are retained, not relabelled.

All three operator run folders together occupy865,738,503bytes before later
analysis/curation, within1GiB for each new run, with the5GiB free-space reserve.
These short, fully observed steps are not engine scalability/CPU-gate evidence.
Native84/material32 and reused DLL/SO remain unchanged/source-qualified; no new
native build or sanitizer run is claimed for these Godot/test-only changes.

**PASS** applies to bounded no-contact compatibility. Predicted contact response
is **UNAVAILABLE/unimplemented** and physics promotion is `NOT_ADMITTED`.
Original SOL clearance and source/ownership/MAT composition remain **NO-GO**.
A new support candidate needs a separate registration, actual synchronous
application→Rapier-step ownership, gravity/damping transport of the applied
impulse, stale/extra-step/live-change refusals and intermediate/final energy
accounting. An upward pre-step impulse may increase instantaneous KE even if
the following gravity step cancels it; native virtual passivity is insufficient.
Preserve failed contact StageA and its unadmitted StageB. Request independent
adversarial review before owner selection; keep Draft429 and all defaults intact.
