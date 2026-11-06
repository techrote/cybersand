---
title: Rigid-body and cellular coupling
document-kind: contract
canonical-for: [rigid-body-cellular-coupling]
status: Current
scope: Rectangle occupancy, bounded displacement/impulses and Rapier hard contact, plus an opt-in detached-aggregate Sand constraint; generalized physics and exact replay remain absent
keywords: [Rapier2D, occupancy mask, sweep, CCD, terrain budget, impulse, unresolved overlap]
related-documents: [simulation-tick-and-threading.md, data-ownership-and-lifetimes.md, ../reference/interfaces-and-message-contracts.md, ../operations/rapier-2d-migration-runbook.md, ../systems/solid-detachment.md, ../audits/2026-09-24-rem002-issue11-integration-forensics.md, ../audits/2026-09-25-pchar001-player-representation-experiment.md]
last-reviewed: 2026-11-06
---

# Rigid-body and cellular coupling

## Fixed-action SOL application-order registration

The [fixed-action ordering result](../systems/solid-detachment.md#fixed-action-correction-and-impulse-ordering--2026-11-06)
uses one native World/body, the same LA-SELECTIVE law/fence/constants and a
test-only exchange of correction/clip versus the combined impulse/torque block.
All96 episodes and345,600 primitive transitions are admitted; the reversed arm
fails rest and worsens burial/sink. Production order and computed torque stay
unchanged. This body-work ledger is not total Sand energy closure or separate
passive/event/legacy causal attribution. No new authority/default follows.

## SOL adopts the workbench package experimentally

The [opt-in actual-cut route](../systems/solid-detachment.md#workbench-law-actual-cuts--2026-11-06)
uses one native owner and one Rapier aggregate with main's six/five-proxy
LA-SELECTIVE contact packet. It disables both legacy SOL281 Sand and separate
ordinary application to avoid double counting, keeps main's completed-sample
fence and overlap handling, and preserves M/I, gravity/damping and budget20.
Arrival-only selection applies to the event wrench; legacy/passive/correction
terms remain. No-arrival late response can still move the body.

This is a law-plus-pacing package comparison. All five-repeat packed cells show
less burial but fail rest; no isolated force-law causal claim or synchronized
original SOL clearance follows. The old observer is incompatible with main's
whole-M/I-per-proxy packet; its zeros are not a no-Water/no-work observation.
The actual packet and paused independent census are separate evidence channels.

## SOL contact ordering experiment

The [isolated route](../systems/solid-detachment.md#contact-and-gravity-ordering--2026-11-06)
can apply unchanged Sand response after one confirmed Rapier advance and before
publication. This ages the original witness by one before packing increments its
serial. Publication/native tick/physical step are distinct clocks; independent
60Hz loops supply age0/1, becoming post age1/2. No source sample/timestamp refresh,
relaxed age/drift/energy guard, mass/cap change or new continuous support force
is admitted. More support with worse burial is a negative settling result.

## Source-local SOL mass readiness — 2026-11-06

The isolated [initialization candidate](../systems/solid-detachment.md#first-impulse-backend-readiness--2026-11-06)
uses automatic COM with explicit native mass/inertia for the exact uniform
rectangle partition. Proxy point velocity uses its world offset from actual COM;
Godot/RIDs remain main-thread owned and only packed values cross to native.
Cached parameter reads do not establish effective backend mass readiness. The
[actual oracle and cut qualification](../audits/2026-11-06-sol-stage-and-mass-readiness.md)
show first impulse/torque recovery without advancing native handoff or altering
forces. Automatic COM has a small measured local residual; actual world COM is
checked against proxy centroid within the existing four-float32-ULP bound.
This does not admit heterogeneous density or new restoration/support physics.

## Opt-in detached compounds — 2026-11-01

**Current experimental source:** the [structural detachment host](../systems/solid-detachment.md)
publishes an exact rectangle union for one genuine native-derived Rapier body.
Its opt-in strict contact policy uses at most four one-cell cardinal parcel
moves and requires full unit-square clearance against every oriented proxy.
Ordinary independent-body ejection, material/Water rules and the11/9 packed ABI
remain unchanged. The shared Rapier bridge owns both ordinary and compound
response; the latter applies existing proxy impulses at rotated offsets and
one weighted correction, refusing duplicate/mixed/stale samples. This is not
a new bearing/friction law or a claim that dense-bed penetration is solved.

### Separately enabled supported-Sand constraint — 2026-11-03

**Current experimental source:** the detachment session can additionally enable
`sand_resistance`; its default remains `false`. The exclusive native owner
publishes whole-cell/rotated-proxy SAT depth, clipped overlap area and supported
ambient-Sand exterior face segments. The observer removes internal compound
seams and preserves the six proxies and both tree holes. Its copied immutable
payload is separate from the unchanged 11/9 ABI and conservative material
transactions. Water, MAT chemistry, hard contact, ordinary granular defaults and
the unaccepted Y1 #343 policy are unchanged.

The existing main-thread bridge authenticates snapshot, tick, **revision**,
epoch, token/generation and sample order before applying any candidate impulse.
The pure planner validates all geometry against the observed and current poses,
refuses sample age over one or corner drift over 0.25 cells, and constructs an
effective-mass, zero-restitution normal response. Parallel segments use only
currently approaching point velocities in each of four fixed sweeps; symmetric
falling contact therefore retains zero artificial torque while rotating approach
cannot disappear at the group's center. Energy nonincrease is preflighted for
every impulse and checked against actual Rapier readback. No candidate position
correction, friction gain, ejection radius or native material mutation is added.

The [4 November SOL364 correction](../systems/solid-detachment.md#sol364-bounded-witness-recovery--2026-11-04)
transports and reclips only the original authenticated exterior segment at the
present pose. Its old midpoint may have left the cell while a valid span
remains. All source records and duplicates are checked before cleared spans are
discarded; current span length and midpoint determine weighting and torque.
Native scalar payloads are frozen once, with the older recursive fallback
preserved. Exact-step replay proves that this witness repair still cannot clear
stationary interior burial; no new granular law or position work is introduced.

This is a bounded dissipative resistance experiment, not a calibrated granular
momentum law or completed penetration recovery. Deep embedding, residual contact
after the fixed sweeps, rejected stale geometry and asynchronous contact latency
remain measurable limitations. Geometry work is bounded by 8,192 cell/proxy
probes and 256 contact segments. Capacity, malformed compound geometry or
unknown residency refuse the observation. Hot or unsupported native materials
remain in the geometric measurement but supply no new supported-Sand response
segment; their presence does not necessarily refuse the entire observation.
The [canonical detachment contract](../systems/solid-detachment.md#opt-in-supported-sand-resistance)
owns the full algorithm, capacity, controls, metric denominators and lifecycle
limits. The [dated ledger](../audits/2026-11-03-sol281-dense-contact.md) separates
local iterations from completed source-qualified Linux/Windows evidence and
the [later recovery qualification](../audits/2026-11-03-sol281-takeover.md).


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
