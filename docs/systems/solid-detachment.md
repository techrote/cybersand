---
title: Experimental native solid detachment and Rapier tree laboratory
status: Current
document-kind: contract
scope: Branch-local dry inert one-aggregate detachment, native ownership fences and actual Linux asynchronous Rapier proof; not general production soliding
canonical-for: [solid-detachment-runtime, solid-detachment-lab]
last-reviewed: 2026-10-27
related-documents: [../operations/soliding-structural-detachment-programme.md, ../architecture/soliding-lifecycle.md, ../architecture/rigid-body-and-cellular-coupling.md, ../architecture/simulation-tick-and-threading.md, ../audits/2026-10-27-sol281-native-tree.md]
---

# Experimental native solid detachment

## Implemented scope and source identity

**Current on the implementation branch, not accepted production main.**
[Issue #281](https://github.com/techrote/cybersand/issues/281) now has a
bounded actual-native-cell → live Rapier handoff and an inspectable tree-shaped
fixture. Executed source is
[`741bc0775c190be98e2f5d23da3d47dd354fef99`](https://github.com/techrote/cybersand/commit/741bc0775c190be98e2f5d23da3d47dd354fef99),
stacked on the [#282 documentation proposal](https://github.com/techrote/cybersand/pull/282).
The [dated evidence](../audits/2026-10-27-sol281-native-tree.md) distinguishes
native Linux/Windows conformance, actual Linux Godot/Rapier motion, rendered
frames and remaining acceptance. Later documentation does not retest changed
executable source. The issue stays open pending the missing integration,
platform and independent review gates.

The fixture starts as **real RedBrick native cells**, not a pre-authored body.
An actual trunk cut identifies 520 unsupported cells; those exact cells become
one native-owned aggregate, represented by six exact compound rectangles in a
new Rapier body. Main-thread gravity/contact generates rotation and horizontal
movement without scripted per-frame transforms. The cut stump, floor and nearby
control structure remain native. An intact tree refuses as `Anchored`.

This demonstrates the primary mechanical direction, not general reactive Wood,
bark/leaf cohesion or unrestricted terrain dynamics. No ordinary gameplay mode
or material policy automatically enables the feature.

## Native owner, shape and transaction contract

Implementation: `native/include/cybersand/solid_detachment.hpp`,
`native/src/world_solid_detachment.inc`, and the guarded methods in
`native/include/cybersand/world.hpp` / `native/src/world.cpp`.

| Boundary | Implemented limit or meaning |
|---|---|
| Activation | Explicit `World::configure_solid_detachment`; disabled with no store allocation otherwise |
| Aggregate count | One experimental aggregate per configured World |
| Discovery domain | At most 64×64 resident cells; no implicit chunk creation |
| Payload | At most 1,024 exact material/state-A/state-B/temperature members |
| Shapes | At most 256 exact rectangles; default admission limit 128 |
| Material eligibility | Homogeneous ambient-temperature Wall or RedBrick; pressure/inertial Worlds refused |
| Support | Explicit anchor rectangle, face-connected candidate, closed local boundary; unknown/excluded scope refuses |
| Geometry | Exact non-overlapping horizontal runs with identical-span vertical merging; holes are not filled |
| Mass/inertia | Homogeneous unit-cell masses, derived COM and summed unit-square moment of inertia |
| Identity | Nonwrapping World incarnation + transaction sequence; body generation and terrain revision bound to receipt |
| Serialization | An outstanding or active aggregate explicitly refuses existing physical-state save/hash formats that would omit its payload |

`Prepared` and `Acknowledged` copies are **evidence**, not a second material
owner. Cells stay authoritative until all member/source checks pass.
`Committed` moves payload ownership into the native aggregate store and retires
source cells. `Active` is reached only after a main-thread collision receipt
matches the current committed terrain revision and body identity.

While Prepared/Acknowledged/Committed/Restored/Quarantined, ordinary native
mutation and ticking are fenced. Read-only material/render/terrain extraction
remains available to complete collision repair. Admission reserves revision
headroom for both commit and an inactive-body rollback. A rollback returns cells
but remains fenced until static-terrain repair is acknowledged. Unexpected
partial failure preserves diagnostic ownership accounting and quarantines the
World; it does not silently retry or activate a body.

**Native receipts alone are not proof of a live RID.** The native tests use
synthetic receipts to check native invariants. The separate real-host tests
construct and inspect actual Rapier bodies/shapes and exercise the same protocol.

## Existing asynchronous host and collision handoff

`godot/native_extension/solid_detachment_adapter.inc` exposes only copied typed
values through a **diagnostic-only** facade. Tokens/digests/revisions use exact
decimal strings rather than lossy floating-point identifiers.

`godot/scripts/solid_detachment_worker.gd` subclasses the existing
`CyberSimulationWorker`, reusing its pacing loop, native World and snapshot
exchange. The shared worker now recognizes a representation fence so ordinary
paused-loop configuration and body-mask refresh cannot mutate a staged source.
The special lane introduces no alternate cellular integrator or second native
clock. Main-thread consumers never read its live native World after thread start.

`godot/scripts/solid_detachment_session.gd` owns the main-thread sequence:

1. Perform the actual native cut and acquire an exact prepared payload.
2. Construct a frozen, noncolliding `RigidBody2D` and exact rectangle shapes.
3. Acknowledge those reserved objects; commit native source retirement.
4. Install the copied post-commit static terrain through the existing
   `CyberRapierPhysicsBridge` and finish its pending collider work.
5. Activate the compound body while physics stepping remains held; finalize
   the exact terrain/body receipt on the native owner.
6. Resume independently paced cells and ordinary main-thread Rapier stepping.

No Rapier step is permitted during a partial handoff. Failed final receipts can
restore the native source and static collision while the body remains inactive.
Session teardown joins the native owner before retiring its Rapier space/body;
old transaction tokens cannot revive a new session's payload.

## Dry-fixture limitations that must remain visible

**Not implemented/admitted:** compound native occupancy/sweep and interaction
with surrounding active liquids/powders; reactive aggregate Wood/heat/chemistry;
mixed-material bonds; arbitrary fracture; rotated dynamic desoliding;
aggregate saves/streaming; multiple simultaneous aggregates; full normal-app
admission; Windows Godot/Rapier qualification and Web support.

In particular, the current general native coupling interface expects rectangle
body records. This laboratory deliberately does **not** publish a filled bounding
rectangle for a tree with holes. Its dry inert source uses real Rapier contact
against static terrain, but does not prove general aggregate↔cellular coupling.
The planned compound-mask/material owner is a named gate, not silently inherited
from existing barrel tests. The opt-in native feature does not itself prevent a
future caller from constructing unsupported surrounding material; the diagnostic
host and its declared workload boundary are part of this qualification.

`rollback_solid_detachment` is only cancellation of an **inactive staged body**.
It is not safe arbitrary body-to-cells desoliding. An activated body remains an
aggregate and may sleep in Rapier. No automatic weld-back claim follows.

## Running the inspected laboratory

Use a native extension built from the **same implementation source**. The
unchanged checked-in main/runtime libraries do not expose this branch's new API;
the laboratory fails rather than substituting GDScript or a prefab.

After the pinned build procedure in
[local build and validation](../operations/local-build-and-validation.md):

```text
godot --path godot res://solid_detachment_lab.tscn
```

**Space:** cut the real trunk and request detachment. **P:** pause/resume.
**R:** join/close and rebuild the complete session. **Escape:** exit.
The display identifies native tick, Rapier tick, angle and the dry inert scope.
Static pixels are drawn from copied native render snapshots; the moving payload
is the exact original member set transformed by actual Rapier state.

The authored clear-fall fixture places its unrelated control tree to the left;
a retained earlier right-side-neighbour fixture blocked further toppling. That
negative is documented, not erased or relabelled as successful free motion.

## Reproducible validation and acceptance limits

```text
make solid-detachment-test
make solid-detachment-sanitize
godot --headless --path godot --editor --import --quit
godot --headless --path godot --script res://tests/test_solid_detachment.gd -- /absolute/path/rapier.json
godot --headless --path godot --script res://tests/test_solid_detachment_failures.gd
```

The native executable is integrated into `soliding-test`. Its allocation-failure
control, capacity/unknown/thermal/mask/event/exclusion refusals, exact payload and
shape coverage, source ABA, revision exhaustion, reset and configured workers
1/4 checks do not establish general threaded performance or body physics.
The two Godot suites separately exercise actual async native transfer, real
Rapier motion, source/contact fences and rollback/reset. Numerical pass is not
owner feel approval. No independent review or full release gate is claimed by
this page; consult the source-qualified audit before using any result.
