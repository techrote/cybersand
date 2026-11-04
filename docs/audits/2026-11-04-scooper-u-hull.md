---
title: Braced U-shaped Scooper comparison
status: Current
document-kind: validation
scope: Geometry-only U prototype, static mask topology and matched motion; powered retention remains unqualified
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../operations/gcr-scooper-u-hull-registration.md, ../systems/granular-review-flight-fleet.md, ../architecture/compound-granular-coupling.md, 2026-11-04-scooper-carried-material-leak.md]
---

# U-shaped Scooper — 4 November 2026

## Source, authorisation and shape

The owner reports remaining apparent seam leakage after the translated entry-
side repair and requests a simple U with inside-corner blocks. This checkpoint
implements that shape while keeping the response, material and motor laws fixed.
It is an exploratory geometry comparison, **not a demonstrated leak cure**.

The isolated codex/gcr-scooper-u-hull-20261104 branch starts from unmerged PR387
source350a9814fe50609b8eb664a8896fb9e3d5e69dd0. Fresh main is
01f9b7c8e382ca6bdbaf0bf70c7847adc12fe0bc, tree
4cf99921dc2b33233c3a254f4b6f27ed7cb0f204. Its intervening PR374 adds only
pressure-cost research/docs and a bench; production/Godot/dependency inputs do
not change. Retain the reviewed runtime branch for a controlled shape comparison.
Dirty checkouts, active review games and independently owned PR347 are preserved.

The [registration](../operations/gcr-scooper-u-hull-registration.md) d33026cb
precedes authoring/results; [machine protocol](gcr-u-hull-2026-11-04/protocol.json)
7c203a6f freezes two shapes,12 motions and the sampled static poses. Shape
commitb19159f5 changes only Scooper hull/description. All seven other definitions
and every Scooper mass, friction, bounce, gravity, flight, motor and capability
field remain exact. Existing mass/inertia/actuator controls are retained.

The five nonoverlapping rectangles form a33×12 U: continuous33×4 floor, two3×8
walls and two2×3 inside-corner reserves. They adjoin without double-counting
overlap. Actual area192, raw COM(1.5,0.28125), mass0.18 and derived inertia
24.79013671875 are installed once on one actual body. The torque needed for
the unchanged angular-acceleration cap48 is1189.9265625, below the existing1200
ceiling. Graphics/native masks/hard colliders use the same real five-piece union.
This is not a new density or material law, and the geometry differences cannot
be attributed solely to the corner blocks.

All89 production-native inputs and both SDKs remain matched to compiled
3df1279f799230bafdc7a34766eb2995bf4ae69b; no native rebuild is needed or claimed.
Godot4.7.stable.official.5b4e0cb0f and Rapier addon0.35.2/core0.35.1 remain
pinned. Native core, ejection/search, support/friction/load rules, ownership,
capacity, sample age, sleep and structural payloads are unchanged.

## Matched observations and actual result

Acquired source48ab262b556f905b98fd4c96a00d4d3eaa9fa628 completes all48
physical captures and four raster captures/96 poses on Windows/Linux, with
unchanged-source custody. One worker, dt1/60,450 owner boundaries/case, default
budget20/mass/motor multipliers. Each shape's cavity centre and floor top align
to world(512,250); actual COM spawn and inertia are reported independently.
Exactly16 Sand or Dust grains are verified clear of each initial mask and
conserved in the closed fixture. No body/material restoration, inventory,
attachment or extra native/Rapier tick is introduced.

The [machine summary](gcr-u-hull-2026-11-04/machine-summary.json),
[paired summary](gcr-u-hull-2026-11-04/paired-summary.json) and
[raw manifest](gcr-u-hull-2026-11-04/raw-manifest.json) bind exact source,
definition/protocol/runtime bytes, copied masks, command/quantity/owner/work and
physical observations. Selected same-boundary witnesses retain reproducible
coordinate sets; large raw remains local at build/u-hull-captures-03.

| Final cavity grains, both OSs | Stepped | Braced U |
| --- | --- | --- |
| Stationary |16|16|
| Full rise selective / boost / events off |16|16|
| Full rise LA |16|16|
| Strafe left/right |0|0|
| Diagonal left/right and Dust diagonal |0|0|
| Deliberate tip left |8|6|
| Deliberate tip right |0|8|

All arms have16 cavity grains at119. Selective/boost/event-off rising arms reach
zero current-pose cavity count at239 and recover16 by329, retaining the known
sequential native/Rapier phase distinction. Final counts alone are not proof
of uninterrupted carrying. LA's16 final grains do not establish lift: its body
ends about142cells lower for the U and144 lower for the stepped profile,
retaining the existing strong-loading limitation.

U persistent below-floor occupancy starts at153 in both strafes (peak3 grains),
150 in diagonals (peak2/3), and154 in Dust diagonal (peak2). Before those first
observations, the whole16-point cloud remains inside the independently checked
closed-floor envelope, with no preceding observed rim or outer-side exit.
Diagonal-right has12 points strictly inside the floor before the transition;
the others begin at wall/corner overlap rather than a complete floor-interior
population. These are copied coordinate sets, not persistent parcel identities.

For example, U strafe-right before153 has wall/toe overlaps and all points
within raw x[-12.52,-8.53], y[-5.09,-0.057]. A new post-step cell(517,256)
lies at sampled raw(-10.6047,5.9232), below the four-cell floor; far-side
occupancy persists. Native reports five displacements and overlap5→0.
This supports a relocation/union-boundary limitation despite a statically
closed mask. Endpoint identities/internal substeps remain unavailable. Tipping
observations have prior rim/side exposure and are not labelled seam crossings.

## Static topology and precision limits

Each shape/OS has24 poses:0/45/90 degrees and eight quarter-cell phases. Actual
native mask IDs are copied over a bounded64×64 region. Independent four/eight-
neighbour reachability uses the actual mask below an observational virtual rim;
there is no native lid. Open exits terminate paths and cannot wrap around to
masquerade as a floor gap. Positive cavity seeds and complete-union coverage
prevent an opaque AABB from passing vacuously.

No missing union pixels or closed-side graph path is found in these sampled
poses for either shape. The old open-right paths remain explicitly labelled.
The U has28 extra occupied native boundary pixels per OS at two90-degree
phases. Their maximum ideal outside distance is7.78609e-8cell; float32 local-
vector rounding explains every one, with no missing native pixels. All exact
discrepancies remain recorded. This is a finite sample, not universal topology
or rotational continuous-collision proof. The new COM/local centres are exactly
binary-representable at zero rotation; rotated world rounding still matters.

The reducer independently authenticates paths, adjacency, free cells, cap,
endpoint side/flags and actual hull memberships. Exact and boundary-sensitive
paths remain separate from its separated-boundary cross-check. Acquisition
success is not itself a seal verdict. Ten corruption/self-test groups pass.

## Compatibility, failures and instrumented coverage

Historical six-piece JSON is frozen byte-for-byte at fixture350a, canonical-LF
SHA25601c41a1fb37489aa017bf39bffdf42557cd78a8000fb3dfae51b26c8d059603f.
Old authored/carry classifiers and900-tick receipt tests explicitly install that
profile with a hash guard before construction. Their reducers bind the fixture
instead of silently using the editable U. Past records/hashes are unchanged.
The active U has separate authoring/body and support-release controls with
actual definition/hash, shape count, mass and inertia in their receipts.

Preflight01 fails only nested-array coordinate comparison: Godot JSON numbers
are Float variants while literal arrays are Int variants. A retained pinned-
engine probe proves scalar/numeric values exactly equal. Exact per-coordinate
comparison and a quarter-cell corruption control fix the test without epsilon.
Preflight02 catches the same strict numeric membership issue in material IDs
and corner labels. Finite/integral validation plus explicit integer membership
fixes only apparatus; fractional IDs remain refused. Both failed cohorts stop
before physical acquisition with true source custody; their logs are retained.

Source-matched reused adapter instrumentation passes six processes/9079 checks:
authoring586, actual five-shape body266, U apparatus48, active-U release1902 and
native authored API6277. No native compilation is repeated: instrumented module
9993d33a9941c2d891c66af7429604e2561dbe557e5d867d5fe106dfa14f70eb,
compilede625c6f2, has the exact same89 native inputs as current shipping3df.
Fresh host source is48ab262b. This uses the documented local loader shim,
not an ordinary pinned-host sanitizer execution. Leak detection stays enabled.
The narrow Fontconfig suppression matches three external allocations/320bytes
in both import and UI authoring; four other processes have none. An additional
unsuppressed authoring control passes586 checks then exits1 with those exact
external stacks. Shipping libraries/engine are untouched. Native core177 Debug
and177 sanitizer results retain their separately authenticated136 input scope.

## Disposition and owner review

The U is an implemented, mechanically admitted authoring prototype. **It does
not qualify as a solution for fast powered carrying.** Static sampled masks
do not support a persistent open-seam explanation; motion/contact relocation
across the union remains the stronger follow-up. Do not add arbitrary overlapping
blocks, stronger friction, sleep or material pinning to conceal that result.

Final exact-head host/docs/provenance/retrieval and hosted statuses are bound in
the focused successor draft PR. Material-shadow's three inherited mismatches
remain a separate blocker; no lock/checker is refreshed. Select8 Scooper and
selective arrivals in the source-labelled new room to judge the U's shape,
pickup/tipping and remaining loss against the preserved older build. No owner
acceptance, production promotion, REM004 completion or merge is claimed.
