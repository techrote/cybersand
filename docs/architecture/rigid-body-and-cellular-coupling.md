---
title: Rigid-body and cellular coupling
document-kind: contract
canonical-for: [rigid-body-cellular-coupling, rapier-force-impulse-sequencing]
status: Current
scope: Rectangle occupancy, bounded displacement/impulses and Rapier hard contact; generalized physics and exact replay remain absent
keywords: [Rapier2D, occupancy mask, sweep, CCD, terrain budget, impulse, unresolved overlap]
related-documents: [simulation-tick-and-threading.md, data-ownership-and-lifetimes.md, ../reference/interfaces-and-message-contracts.md, ../operations/rapier-2d-migration-runbook.md, ../audits/2026-09-24-rem002-issue11-integration-forensics.md, ../audits/2026-09-25-pchar001-player-representation-experiment.md]
last-reviewed: 2026-11-05
---

# Rigid-body and cellular coupling

## Bounded passive contact residual

**Current source, qualified synthetic diagnostic:** the compound value solver
weights each node by its share of all admitted samples and performs four normal/
tangent batches. At zero lever arm, with inactive caps and approaching sample
fraction `a`, the remaining incoming velocity is `(1-a)^4` times its initial
value. Support/separating samples can therefore dilute arrest without consuming
the available normal capacity. This is the declared bounded approximation, not
a convergence or nonpenetration guarantee. The unchanged final energy gate
rejects energy-increasing wrenches but supplies no residual-speed gate.

[SOL-PASSIVE-VALUES-001](../audits/2026-11-05-sol-chamber-yielding.md#unchanged-passive-value-diagnostic)
checks this relation on actual Linux optimized/strict ASan+UBSan and actual
Windows MSVC using the unchanged header. It also checks friction, rotation,
capacity, refusal and workspace reuse. These synthetic bins carry no material
eligibility, live World/Rapier authority or original SOL clearance claim.

### Active-normal copied-value candidate

**Current experimental values, not live physics:** the separately registered
[active-normal comparison](../audits/2026-11-05-sol-active-normal.md) normalizes
normal relaxation over approaching or already-loaded contacts. It preserves
original capacity shares, four passes, tangent rules and final rejection.
All-active batches reuse original weights exactly. Nine uncapped COM targets
stop across Linux optimized/strict sanitizers and actual Windows MSVC; a capped
front still retains15/16speed, so unused support capacity is not borrowed.
Loaded impulses unwind and a changing active set is recomputed per batch.

The production header remains unchanged in this value phase. Normal-batch
passivity does not extend to every computational tangent batch; shrinking cones
can unwind friction and raise intermediate energy. No live material, World,
Rapier, original SOL or default admission follows. Live comparison needs its
own registration and fresh native runtime qualification.

### Opt-in live normal policy

**Current dependent experimental source:** the
[live policy qualification](../audits/2026-11-05-sol-active-normal-live.md)
adds an explicit native normal-policy argument with Original as the unchanged
default. ActiveNormal001 is restricted to a fresh diagnostic LA-SELECTIVE
Workbench and locked against mid-trajectory selection. Reset/replacement retire
that state; native top-level and row readback precede test application.
Detailed scalar64 passive/legacy/total-wrench and energy diagnostics are copied
only for diagnostic Worlds. Passive energy starts after the accepted event
wrench and excludes the separately added legacy contribution.

Fresh DLL/SO builds,38-case exact value parity and98 lifecycle assertions on
each actual host pass. Eight independently reduced smoke episodes conserve
tuples. In closed driven contact, area falls38.7651→14.2322cell² and depth
1.39637→0.544231cells on both hosts, while strict clearance still fails.
The change acts before the first selected arrival; legacy/correction stay zero.
Native strict/optimized and both-host workbench regressions pass. The full
worker/repeat/authored/workload matrix remains pending. Original SOL
eligibility, composition, physical clearance and general default promotion do
not follow. No capacity/pass/gain changes or penetration correction are added.

## Granular response cost and observation

**Current experimental evidence:** [SOL-CHAMBER-COST-001](../audits/2026-11-05-sol-response-cost.md)
isolates `workbench_coupling_results()` from the native tick. The getter includes
the passive solve and serial response construction; the older four-stage
subtotal omitted it. In48fresh single-body sessions at `a47be4e2`,24full/minimal
observer pairs match body states, response/application and all scheduled exports.
Recorded response-generation means are12.739–22.25µs for this256² workload.
Full per-cell/mask observation adds roughly11.8–13.1ms per recorded step compared
with minimal observation. This is test-apparatus overhead, not a shipped speedup.

Minimal observation still records body states, statistics and exports; export
peaks prevent universal60Hz claims. Requested workers1/4 are read back correctly
but each native phase has at most one job and one actual participant. This
does not qualify scaling, dense/stress memory or the original24group SOL CPU
gate. The solver's measured finite-pass residual and driven overlap remain
unchanged; low response-generation cost is not collision correctness.

## Pinned Rapier drive sequencing in chamber experiments

**Current on authenticated desktop Rapier v0.35.2:** the addon implements
`body_apply_central_force` as one immediate `F*dt` impulse using the configured
physics tick rate. In the registered 60Hz chamber operator sequence, native
sampling already sees that updated velocity. Measure external API work between
precall/postcall states, then response work between live preapplication and
postapplication states. An endpoint `F*dx` estimate does not replace the actual
drive impulse's kinetic change. A hypothetical force increment after response
is counterfactual and must not be added as applied work.

The [source-pinned chamber ledger](../audits/2026-11-05-sol-chamber-yielding.md#force-accounting-correction)
links the exact addon implementation, host observations and the corrected
apparatus registration. This is backend/source-specific behaviour, not a
portable promise about every PhysicsServer implementation. Existing ownership,
one-use application and default response contracts remain unchanged.

## When a crate moves through sand, are its pixels erased and restored?

**Current:** native World owns cellular materials; Rapier2D owns independent
rigid bodies. Bodies are never erased from/restored into the material array.
`CyberNativeCellWorld` projects copied rectangles into a separate transient
body-ID field. Sand, liquids, Smoke, painting and the sampled character read
that endpoint field as occupied. The retained three 8×14 reference bodies are drawn through
shader transforms. ACT-004 instead draws each articulated part from its actual
collider and copied Rapier transform; body colour is not stored in the cell texture. Moved-body
overlap is resolved by bounded material ejection; if no destination fits, the
material stays in place and unresolved overlap is counted. The body receives
bounded reaction observations instead of silently deleting trapped sand.

[CyberRapierPhysicsBridge](../../godot/scripts/rapier_physics_bridge.gd) owns live
Nodes/RIDs and manual stepping on the main thread. The native adapter receives
values only. Desktop samples asynchronously; Web sequences both solvers and
waits behind pending terrain colliders. Exact controller order belongs in
[threading](simulation-tick-and-threading.md), not a universal coupling schedule.

## How is a moved rectangle reconciled?

Source: [native `prepare_rigid_body_coupling`, `parse_body_states`, `rasterize_body_sweep`, `reconcile_swept_overlaps`](../../godot/native_extension/cyber_native_cell_world.cpp).

1. Clear/wake the previous obstacle field and clear observations. Mask changes
   wake their own resident activity block and boundary neighbors without a cell
   or render write, including masks wholly inside a sleeping block. Parse at most
   64 complete records with body IDs 1–64; retain the first duplicate ID.
   ACT-004 rejects nonfinite records, fractional IDs/serials and nonpositive
   sizes/mass. The physical session checks its complete assembly budget before
   installation; the low-level bounded parser does not admit excess records.
2. Traverse ascending body IDs and rasterize a temporary sweep from prior to
   current accepted transform. The first mask writer wins where bodies overlap.
3. When overlap response is enabled, reconcile movable material against the
   temporary sweep. Then clear it and rebuild only endpoint occupancy.
4. Accumulate endpoint boundary pressure, cellular movement contacts and the
   bounded granular-bearing contribution from exposed downward body cells. Bearing
   queries the existing granular support policy against **stored** material, not
   the transient body proxy. Publish bounded observations keyed by body/sample
   identity.

The GDScript fallback projects input order; arbitrary sample reordering is not
claimed equivalent. Body/body collision remains Rapier's responsibility.

### Circular player wheels retain rectangular native occupancy

**Current experimental SetP:** the [player buggy and trials bike](../systems/player-control-playground.md)
use real `CircleShape2D` Rapier colliders and matching round graphics. Their
copied native body records still carry the circle's full diameter as rectangle
size. The resulting oriented circumscribed square conservatively includes corner
cells outside the wheel and may change its mask as it rotates. Hard contact is
circular; native material occupancy, sweep and displacement remain rectangular.
This declared approximation adds no generalized contour rasterizer or packed-ABI
change and does not widen earlier rectangle-fixture acceptance.

## What are the current numerical bounds and units?

Body centres/sizes/corrections use cell/pixel coordinates; rotation is radians,
linear velocity is pixels per second, angular velocity is radians per second.
Mass and returned central impulses use the Godot physics adapter's quantities;
there is no approved production SI calibration or generalized force/torque
unit contract. Packed fields are documented in
[interfaces](../reference/interfaces-and-message-contracts.md).

| Operation | Current bound or response |
|---|---|
| Translation sweep | More than 32 pixels between samples is treated as a teleport: endpoint only |
| Sweep sampling | Approximately one-cell spacing, capped at 24 intervals/25 samples; interpolates centre, shortest rotation and size |
| Endpoint overlap | Search outward from nearest face and along its tangent, at most eight cells; the bounded half-cell path may not cross hard terrain or another body's transient mask |
| Swept-only overlap | Prefer ejection in body-travel direction; rotational response remains approximate |
| No valid destination | Retain the complete stored cell payload and report unresolved overlap plus reaction; no particle fallback or silent deletion |
| Granular bearing | Exposed downward body cells query the version-1 granular support predicate against stored material; response is recomputed each accepted sample, capped at 20 impulse units and uses at most 0.5-cell low-speed correction |
| Native impulse | Contact/displacement/density pressure terms retain the ordinary cap; the bounded bearing term shares the cellular coupling owner rather than becoming a second collider/solver |
| Stale results | Reject age above eight body samples; suppress correction above one; scale impulse by `1/(1+0.25*age)` |

Ejection transfers the compact cell state including Water mass. Pure closed
Water conservation does not establish general body/cell energy conservation.
Duplicate sample serials are not applied twice. Sample wrap and age constants
are in [Rapier `apply_cellular_results`](../../godot/scripts/rapier_physics_bridge.gd).

The internal [4LY free-flight chassis](../systems/physical-free-flight.md) reuses
this same rectangle publication and cellular response. Its authored propulsion
force cap is separate from the native impulse cap above. Raising a flight thrust
limit does not repair or requalify body/material coupling. Flight receipts report
only their own applied assistance; they cannot decompose Rapier contact, passive
damping or delayed cellular impulses into a claimed total-force measurement.

## Who resolves hard terrain and thin floors?

**Current:** hard-surface pixels, including construction materials, are merged
into static Rapier rectangle shapes. Cellular hard-contact correction/support
is disabled to avoid double-solving delayed contacts. The demo bodies already
have cast-shape CCD enabled and zero restitution; see
[body configuration](../../godot/main.tscn). A future adaptive CCD/substep
controller is a separate **Planned** feature.

Hard-terrain extraction creates 64×64 packets: 256 units for the 1024² demo.
The consumer checks a 32-chunk/750-microsecond soft rebuild budget between units.
The preceding native `get_hard_surface_chunk_rectangles` extraction is outside
that budget, and one indivisible changed chunk may exceed it. This is bounded
consumer granularity, not an end-to-end frame-time guarantee. Source:
[native extraction](../../godot/native_extension/cyber_native_cell_world.cpp),
[Rapier `process_hard_surface_collider_budget`](../../godot/scripts/rapier_physics_bridge.gd).

## What does the fixture prove, and what remains open?

For the **Planned** investigation of barrel sinking into powders, half-depth
embedding and reversible soliding, see the [characterisation plan](../operations/physics-characterisation-plan.md).
The owner now calls the demo rectangles barrels; this does not change their
Current rectangle geometry or internal scene identifiers.

The dated 600-tick rectangle fixture permits two pixels and observed about 1.32 pixels of
transient floor penetration; it is not a zero-penetration proof. Its exact
platforms, artifact identity, inputs and tolerance are in the
[Rapier runbook](../operations/rapier-2d-migration-runbook.md) and
[validation ledger](../reference/validation-evidence.md). Level/body restoration
is not complete trajectory replay; see
[level saves](../reference/level-saves-and-replay.md).

**Planned:** generalized shapes/contours, torque feedback, fracture membership,
particle conversion, serialized sweep/CCD policy and wider numerical acceptance.
The sampled character reads the body mask but is not a PhysicsServer collider
and does not push a body. Rectangle sweep coverage and capped pressure are a
bounded gameplay approximation, not exact continuum mechanics or a guarantee
for every fast/thin/rotating shape. Rationale lives in
[ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md) and
[ADR-009](../decisions/ADR-009-rapier-2d-rigid-body-backend.md).

## PCHAR-001 switchable barrel-player experiment

**Current experiment:** the ordinary sandbox can select either the historical
sampled character or a barrel-style player through a fresh-reset-only boundary.
The barrel player is the existing body-0 rectangle and uses the same
`CyberRapierPhysicsBridge` sampling, transient body mask, native cellular
reaction results, static hard-terrain colliders and Rapier ownership as the red
reference barrel. There is no in-place sampled↔body ownership conversion.

Barrel locomotion adds only a bounded main-thread horizontal central impulse.
The controller reads live Rapier velocity **after** cellular results are applied,
adds at most 3 impulse units per fixed step toward a 42 px/s horizontal target,
does nothing when there is no horizontal input, and never assigns linear velocity
or changes the vertical component. Existing cellular displacement/contact/bearing
results therefore remain observable rather than being overwritten by a character
velocity controller.

PCHAR-001 does not change generic body↔cellular semantics, result ABI, bearing,
ejection, sample-age policy, Water behavior or hard-terrain ownership. Any such
change still belongs to #83 / REM-004. The switch is an evidence-generating
player-representation experiment under parent #132, not a declaration that the
current rectangle envelope is production-complete.

## What did the measured barrel baseline establish?

**Historical 2026-09-09 scope:** the [issue #9 report](../audits/2026-09-09-physics-characterisation.md)
separated stored-cell displacement, boundary pressure, transient contact and
Rapier hard-floor collision. On that source, packed Sand did not stop an ordinary
rectangle before the deep hard floor; masked stored grains could produce
Wall-proxy-derived contact feedback; and endpoint-only ejection could move Water
across a one-cell hard floor. Those observations remain valid historical evidence
for the identified source. They are no longer Current behavior after REM-002.

## What does REM-002 establish on Current source?

**Current bounded baseline, 2026-09-24:** [REM-002 evidence](../audits/2026-09-24-rem002-issue11-integration-forensics.md)
reconciles the never-integrated historical #11 repair into current main without
claiming broad body/granular gameplay acceptance.

Current semantics are:

- a stored cell beneath a transient body mask remains material authority and does
  not execute its normal cellular kernel as the body Wall proxy;
- ejection endpoints and their bounded path reject hard terrain and foreign body
  masks; if no legal target exists, the complete payload stays at the source and
  unresolved overlap is reported;
- an ordinary rectangle may receive a bounded cellular-owned granular-bearing
  contribution from current support-capable packed material;
- bearing is recomputed from current cells every accepted sample and disappears
  after excavation/support loss; there is no support cache or granular Rapier
  collider;
- hard terrain remains Rapier/static-terrain contact, and liquids do not become
  granular bearing;
- the existing 11-float input / 9-float result ABI and sample-age policy remain
  unchanged.

On frozen source `df54e927...`, the focused real-Rapier Linux regression measured
one-height Sand peak/final depth **3.748/0.000 cells**, four-height
**6.652/1.472 cells**, and explicit excavation released the body into substantial
downward travel. The exact runtime/platform qualifications and retained hashes are
in the dated REM-002 audit.

This is still a bounded ordinary rectangle/load baseline. General shapes, high
energy/thin beds, crowding, sustained publication delay, calibrated force/torque,
fracture and broad body↔granular gameplay acceptance remain outside this contract
and are owned by REM-004 / #83 where applicable.

## Sampled player support is a separate owner

**Current:** the [granular/player policy](../systems/granular-interaction-policy.md)
still owns sampled-character material-aware packing queries, directional collision
and bounded enclosure recovery. REM-002 reuses the same support predicate for a
separate bounded body-coupling observation against stored material; it does not
make the sampled character a Rapier collider and does not add a second material
owner.

## Development workbench physical ownership

The Draft #391 host stages one bounded multi-body roster at a time. Each
instance has one session/epoch, generation, actual mass/inertia/centre of mass,
gravity, drive sample and response budget. Collision rectangles contribute to
the same body's wrench. The worker owns the cellular state, checks the copied
geometry and samples in the native adapter, and publishes value-only rows.
The main-thread bridge rejects retired or duplicated results and checks sample
age and corner travel before applying the wrench to that instance's Rapier RID.
The finite canvas owns interest independently of presentation. The
[workbench guide](../systems/player-control-playground.md#development-workbench-on-desktop)
and [qualification record](../audits/2026-11-04-workbench-consolidation.md)
distinguish authoring controls, observed behavior and unresolved review gates.
