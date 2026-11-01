---
title: GCR-001 experimental granular contact response
status: Current
document-kind: contract
scope: Opt-in retained GCR R2 and admission-only GCR-A1, bounded value ownership and failed physical qualification; ordinary B0 remains default
canonical-for: [experimental-granular-contact-response]
last-reviewed: 2026-11-01
related-documents: [rigid-body-and-cellular-coupling.md, ../systems/granular-interaction-policy.md, ../operations/granular-contact-response-plan.md, ../audits/2026-11-01-gcr001-qualification.md, ../operations/granular-contact-admission-plan.md, ../audits/2026-11-01-gcr-admission-qualification.md]
---

# GCR-001 experimental granular contact response

## Does GCR change ordinary physics, and did qualification pass?

**Current experimental source:** retained GCR-001 R2 combines geometric normal resistance,
friction and contact moment for copied rectangular Rapier parts. It is selected
only by explicit fresh developer/test construction. Ordinary B0 remains the
default; the retained B0 and experimental Y1 response paths are unchanged.
The old Float32 11/9 ABI remains separate from the new Float64 17/14 ABI.

**Current experiment disposition: NO-GO for the R2 integration.** Registered
physical comparisons show material resistance/preservation regressions. A passed
mechanics/reduction oracle does not qualify the integrated behavior. The audit
owns exact case results and source-bound Windows/Linux qualification; neither
this contract nor the review UI supplies owner gameplay acceptance.

**Current admission-only successor:** explicit `GCR-A1` /
`GCR-ADMISSION-001-2026-11-01` fixes clean side/up admission while retaining the
R2 response law. The native query/oracle and actual adapter gates pass, including
all nine capable materials. **Its integrated physical qualification is also
NO-GO**: Sand/Dust/Rust bank entry and four impact-preservation cases fail.
All237 registered captures completed; additional contacts expose response/load
allocation limitations rather than supplying an accepted friction law. See the
[new audit](../audits/2026-11-01-gcr-admission-qualification.md). Neither draft
changes the default or establishes owner gameplay acceptance.

**Deferred:** sleep admission/wake changes, persistent support/rest caches,
freezing, soliding/desoliding and body-to-cell conversion. Ejection search,
compaction, push chains, controllers and material laws are not retuned by GCR.

## Which materials and state semantics apply?

The existing capability covers Sand, Stone, Dust, Seed, Salt, Sodium, Gunpowder,
Coal and Rust. Admission reads current stored material and the shared stability
policy; it does not special-case yellow Sand or infer capability from density.
Stone state 0/intact bracing and state 1/granular movement remain native rules.
The registered granular-Stone fixtures explicitly use state 1; the support
predicate itself admits both states when its existing neighborhood test passes.
Seed becoming Plant removes powder capability. Reactive transformations retain
their existing sources/sinks and cannot be judged by closed per-ID conservation.

The A1 actual adapter mechanically admits clean interfaces for all nine materials.
Native query tests preserve material/state/temperature and cover actual Dust-to-Fire
and Seed-to-Plant support retirement. These native reaction tests do not establish
full adapter reactive/state/temperature payload qualification; that remains a gap.
Inherited native conservative-relocation tests remain separate payload evidence.
See [granular policy](../systems/granular-interaction-policy.md) and the
[registration](../audits/gcr001-2026-11-01/protocol.json).

## Who owns cells, bodies and published values?

Native World remains authoritative for cells. Overlap uses existing bounded
`relocate_stored_cell`; refusal retains the payload and records unresolved work.
The transient occupancy mask is separate from stored material. Rapier objects,
live scene-tree objects and impulse/torque application remain main-thread owned.
Workers receive copied body values and publish owned snapshot/result values.
No body is erased into cells, no mutable World storage reaches consumers, and
the numerical contacts are not per-cell physics objects.

The GCR arm replaces overlapping granular displacement/boundary/bearing feedback.
Non-granular feedback retains its legacy channel. Native blocked granular move
attempts carry a separately attributed integer source moment into GCR; they are
density-weighted feedback, not physical parcel momentum conservation.
Sources: [adapter ownership and response](../../godot/native_extension/cyber_native_cell_world.cpp),
[native contact accumulation](../../native/src/world.cpp), and
[main-thread bridge](../../godot/scripts/rapier_physics_bridge.gd).

## What crosses the versioned value boundary?

| Input offsets, Float64 stride 17 | Meaning |
| --- | --- |
| 0; 1–2; 3; 4–5 | Body ID; rectangle origin; rotation; actual rectangle size |
| 6–7; 8; 9; 10 | Linear velocity; angular velocity; actual mass; sample serial |
| 11; 12–13; 14; 15; 16 | Actual inertia; world COM; existing body friction; dt; session |

| Result offsets, Float64 stride 14 | Meaning |
| --- | --- |
| 0; 1–2; 3–4 | Body ID; linear impulse; separate positional correction |
| 5; 6; 7; 8 | Contact, displaced, unresolved counts; sample serial |
| 9; 10–11; 12; 13 | Angular impulse about sampled COM; sampled COM; version 1; session |

Mass/COM/inertia come from the real Rapier part, including authored flight inertia;
inertia is read from the pinned backend's actual server parameter, not inferred
from the drawing AABB or an unreliable inverse-inertia cache. Locked/unknown
inertia, invalid records and unsupported dimensions refuse explicitly. Initial
rectangle dimensions are 1..128 cells; there are at most 64 bodies.
The process-scoped session is an exact positive Float64 integer at most 2^53−1
and never wraps. It fences fresh bridge/reset lifetimes separately from serials.

The bridge validates the entire batch before applying anything. GCR accepts at
most age 1 and at most 0.5-cell maximum rectangle-corner displacement. A response
sample owns at most one native step; repeated/refused samples invalidate response
observations while retaining occupancy. There is no central-only legacy fallback.
Delayed wrench transport uses `Lcurrent = Lsample + (COMsample − COMcurrent − correction) × J`;
the same age scale applies to J and L. Correction has its own age 1 ceiling.
Duplicate, malformed, cross-session and stale/geometry refusal are atomic.
Accepted nonzero angular impulses use the same response-triggered wake behavior
as existing linear impulses; no sleep admission, rest threshold or wake-scheduling
scheme is introduced.
Sources: [ABI definitions](../../godot/scripts/rigid_body_coupling.gd),
[producer validation](../../godot/native_extension/cyber_native_cell_world.cpp),
[application and moment transport](../../godot/scripts/rapier_physics_bridge.gd).

## How is the work bounded?

Each admitted source cell is counted once per body and projected to the nearest
actual rectangle face, with deterministic X-before-Y corner ties. Eight source
bins represent two tangent halves per face. R2 stores tangent spread using
Welford mean/M2 and support extents, then uses at most two numerical quadrature
nodes per bin. Symmetric clipping preserves first moments; variance clipping is
counted rather than presented as exact equivalence.

Four projected Jacobi normal/tangent passes use sample-count weights and updated
provisional linear/angular velocity. The body shares normal capacity 20 and the
per-source capacity 2 reference; friction uses unchanged body mu, material
multiplier 1, with `abs(Jt) <= mu * Jn`. Accumulated caps never renew per pass.
The bound is 16 nodes/body and 8,192 scalar updates per 64-body boundary. Native
fixed bin storage and construction-reserved raster capacity are disclosed in
diagnostics. A passive kinetic-energy guard refuses injection beyond the
registered tolerance; moving events, correction, controls and hard contact remain
separate ledgers. No total-system energy-conservation claim follows.

The retained R1 centroid reduction failed its registered 10% normalized wrench
gate. R2 passed the same 36-case independent unreduced-solver oracle under that
unchanged gate; this is scoped approximation evidence, not universal equivalence
or physical efficacy. See [bounded evaluator](../../native/include/cybersand/granular_contact_response.hpp),
[oracle](../../native/tests/granular_contact_qualification.inc), and the dated audit.

## Why did retained R2 fail side admission?

The adapter ejects interior cells before collecting exterior contacts. A side
source is immediately adjacent to a masked pixel, while the unchanged side 9/9
predicate tests a centered stored-material neighborhood containing that pixel.
Successful ejection leaves it Empty, so a clean interface cannot satisfy the
predicate. Unresolved interior grains may admit response only after penetration.
Normals at exactly 45° also take this side path, affecting rotated downward
support. GCR suppresses the old granular displacement and boundary reactions,
so missing new admission can remove resistance. This is an adapter/admission
integration conflict; it is not a negative verdict on the contact equations once
contacts exist. Sources: `prepare_body_coupling`, `reconcile_overlap`,
`accumulate_boundary_pressure`, `accumulate_gcr_contacts` in the
[adapter](../../godot/native_extension/cyber_native_cell_world.cpp), and
`World::granular_support_at` in [World](../../native/src/world.cpp).

Separately, R2 admits the blocked-move event wrench first and subtracts its cost
from passive capacity. Downward events can both load the body and reduce upward
braking capacity. Y1 instead caps legacy feedback before adding bearing. These
are distinct registered response policies; event/capacity ledgers must establish
their contribution to any observed vertical regression. Neither blocked attempts
nor repeated displacement attempts are independent physical efficacy samples.

## How does admission-only A1 select contacts, and why is it still NO-GO?

The [preregistered A1 plan](../operations/granular-contact-admission-plan.md)
owns the exact algorithm, population and frozen hashes. `World::granular_contact_witness`
uses the original geometric outward normal to choose the first mask-free depth1
or2 witness (Chebyshev2, Euclidean at most2sqrt(2)). Its full12-cell predicate
footprint must exclude every body ID; the source and closed-square straight-path
supercover must contain actual stable capable powder. Only then does the unchanged
shared side9/9 plus downward8/9 predicate run once. Material/path/packing refusal
does not select a deeper witness. The original projection, source count and
capacity remain authoritative. The ordinary downward8/9 branch is unchanged.
The bound is65 logical probes per side candidate, including at most31 mask,
26 stability and34 material reads. These overlapping categories are not summed
as separate probes. No allocation, World mutation or persistent support is added.
Sources: [World helper](../../native/src/world.cpp),
[adapter selection/counters](../../godot/native_extension/cyber_native_cell_world.cpp),
and [independent query oracle](../../native/tests/granular_admission_qualification.inc).

All named mechanical cases pass, with zero mask-interior grains required at clean
interfaces. Physical Sand/Dust/Rust bank penetration nevertheless worsens versus
Y1, and heavy high entry reaches the hard floor. Timing also triggers investigation.
The frozen solver allocates its normal budget across **all** source counts before
resolving closing velocity, without transferring unused node capacity. Correctly
admitting more side/up sources can dilute nominal-bottom allocation. Detailed
heavy-case ledgers support this mechanism but do not isolate its dominant causal
contribution; retained R2 ledgers and current A1 have explicitly different source
identities. Events, evolving geometry/stability, delivery and hard collisions
remain separate influences. No counterfactual law or load refinement was tested.

Pure vertical sliding on an upright side still creates zero normal load and zero
Coulomb tangent response. Raising friction alone cannot create confinement load.
Any allocator, event-budget, friction or load-law change needs a new registration;
A1 admission success does not authorize post-result tuning. R1/R2 failures and
their original artifacts remain unchanged.

## How do I compare A1, retained R2 and Y1 with actual playground controls?

Use a source-matched, authenticated project and engine; Windows example from the
repository root (substitute the authenticated project path for an isolated copy):

```powershell
$env:CYBERSAND_SOURCE_REVISION = (git rev-parse HEAD)
& C:/Godot47/Godot_v4.7-stable_win64_console.exe --path ./godot res://player_playground.tscn -- --player=jetbarrel --granular-experiment=GCR-A1 --granular-token=GCR-ADMISSION-001-2026-11-01 --granular-review-material=2
```

Change `GCR-A1` to `Y1` for the reference. Retained R2 uses `GCR` with
`GCR-001-2026-11-01`; material2/14/29 selects Sand/Dust/Rust.
Before a manual launch, run `python tools/experiments/run_gcr_admission.py
--identity-only` from the same checkout to authenticate its native/Rapier/engine
and project-source identities. The environment value labels that inspected Git
revision; it is not independently an artifact authenticity check.
`--player=acrobat` selects the articulated runner. The explicit route starts a
fresh experiment, raises the initial spawn identically, removes stock material
samples and creates the same supported review bed. Reset reconstructs the arm;
controller commands do not restore cells. The compact
`y1_envelope_review.tscn` comparison uses the A1 protocol explicitly; ordinary
review still uses its retained protocol. The authenticated A1 runner requires a
fresh source-bound mechanical receipt before review/acquisition. The dated audit
records the captured checkpoint and supported receipt identities. No persisted setting enables GCR.
Ordinary launch without experiment arguments retains B0 and the authored course.
Swarm presets refuse this comparison. Circle occupancy remains the existing
rectangle approximation, and this bounded view is not the full planned topology
or human-feel matrix. The UI labels experimental source/arm; no owner verdict is
inferred. Sources: [UI](../../godot/scripts/player_playground.gd),
[runtime](../../godot/scripts/player_playground_runtime.gd), and
[actual-host test](../../godot/tests/test_gcr_playground.gd).

