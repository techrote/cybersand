---
title: Freed objects in the ordinary workbench
status: Current
document-kind: contract
scope: Bounded RedBrick release after ordinary erasing, same-World ownership and unchanged physical response; implementation and functional qualification on Draft466
canonical-for: [workbench-freed-object-rules, workbench-native-aggregate-handoff]
last-reviewed: 2026-11-07
related-documents: [data-ownership-and-lifetimes.md, rigid-body-and-cellular-coupling.md, ../systems/solid-detachment.md, ../systems/player-control-playground.md, ../reference/interfaces-and-message-contracts.md]
---

# Freed objects in the ordinary workbench

## Implementation paused by owner — 2026-11-07

Further SOL cutting, representation, asynchronous handoff and response work is
**Deferred** until the majority of major physics integrations reconcile with main.
The [owner decision](../reference/product-intent-and-priorities.md#sol-deferred-during-physics-reconciliation--2026-11-07)
supersedes earlier continuation suggestions. Existing Draft implementations and
failures stay source-bound; [the findings handoff](../audits/2026-11-07-cut-outcomes-and-triage.md#owner-pause-and-reusable-findings--2026-11-07)
identifies independently useful work. This documentation does not select a
material outcome, change physics or admit a new ownership contract.

## Asynchronous cut status and post-cut outcome comparison

Current capture globally fences native ticks, commit requires the original tick
and terrain revision, and mixed-body append requires suspension with unchanged
old-body samples. Full non-pausing cutting is unavailable through this contract.
Speculative copied-value and isolated first-body preparation is a Planned design
option, followed by authoritative revalidation/hold; mixed-body staging and local
reservation/epoch semantics require a separately admitted contract. No pause or
safety gate is removed in the current comparison checkpoint.

The [dated comparison and triage](../audits/2026-11-07-cut-outcomes-and-triage.md)
uses uniformly fresh authored post-cut starts for all three outcomes. Existing
live conversion does not support all-Sand520/356 or discarded fringe. All-Sand
has no body; core-only explicitly loses312/204 cells. Both rigid arms retain the
same208/152 core mass and native inertia. All preserve the eight-cell stump.
Five-repeat Windows1 primary and Linux1/Windows4 spots observe120 exact native
steps. First contact is age-refused in each fresh rigid episode, then119 are
accepted; no warm-up is inserted. These starts are not strict live-cut replay.
Keep the material/fidelity choices provisional and stop for owner triage.

## Interior rectangle experiment

On `codex/workbench-rectangle-core-20261107` only, ordinary cuts request one
largest cell-aligned rectangle entirely inside the proven source. Full-source
eligibility and the1024-cell/62-span limits remain. Original sources1–16 still
crumble; larger sources keep the rectangle as one body and convert all excess
cells to native Sand2. Ties prefer top, left, width then height descending.
Unit-cell mass/inertia use only retained cells. Geometry/material deliberately
change; contact law, gravity, damping and force caps do not. Exact native/control
mode remains available with `rectangle_core=false` before a fresh cut.

One native transaction revalidates full core/fringe tuples, retires core and
converts fringe, then waits for matching terrain/roster before activation.
Generic committed rollback refuses; partial failures quarantine. Saved fringe
row spans and core-only appearance prevent duplicate brick on fresh replay.
See [source and qualification](../audits/2026-11-07-workbench-rectangle-core.md).
This lossy approximation is separate from exact whole-object SOL acceptance.

## Cut responsiveness and carried material

Dependent Draft510 now draws newly freed RedBrick from one exact cropped RG8
material image, with transparent holes and original source-coordinate pattern.
Optional saved `body.appearance` is `{material:43, origin:[x,y]}`; old two-field
body hashes remain unchanged. Appearance does not enter the physical definition.
Main-thread session/overlay caches hold at most8 images of at most130×130 cells;
no per-frame image rebuild or GPU readback. Old authored bodies without metadata
retain their placeholder appearance. The existing palette Shader/LUTs are shared.

Terrain scheduling diffs each validated full packet against installed geometry,
including partial supersession and trailing removals. Only changed chunks consume
the unchanged8-chunk/2000-usec cut budget; empty chunks create no static RID.
Native commit, terrain revision and fresh-roster sample fences remain mandatory.
The [dated correction](../audits/2026-11-07-workbench-cut-feedback.md) records
2048² five-repeat Windows/Linux1/4 comparisons and the separate shader transition.
Physics, source eligibility and cell/body capacities remain unchanged here.

## Cut scheduling and exact recipe reconstruction

On the dependent rectangle-core branch, the remaining hitch correction replaces
frame-polled worker replies with deferred one-use main-thread notifications.
Reply values still cross the mutex mailbox under exact serial/generation checks.
A cut-only semaphore wakes the exclusive owner on requests/stop; only empty
held turns wait after a mutex recheck. Opt-in normal begin prefetches the first
bounded discovery, preserving begin then every native discovery receipt; census
begins retain old semantics. Main consumes prefetch once.
Absent/structurally incomplete prefetch or timeout/stop/stale transport leaves clocks held; retirement wakes pending work.
The GDScript owner schedules notifications, never native pool workers. Up to8
consecutive refused discovery attempts share a publication; every refusal and
counter is retained. Accepted preparation, two frozen physics checks, terrain
installation, adoption and fresh-sample fences are unchanged.

Authored history reconstructs exact ordered material row intervals. Empty
writes erase spans; the4096 final-run budget,2048-stamp budget and disc raster
are unchanged. Fragmented histories can still cost more; no universal60Hz or
original SOL CPU qualification follows. Cut timings freeze before observer
census. See the [registered correction and evidence](../audits/2026-11-07-workbench-rectangle-core.md#remaining-cut-hitch-correction--2026-11-07).

Fresh live timing also measures the first accepted resumed Rapier step, with
exact cut-end sample/session/epoch and first-step coverage checks. Its scope is
Windows/Linux worker1/60FPS with five repeats per tree/building case; paused
worker1/4 measurements remain separate. See the [wake/resume evidence](../audits/2026-11-07-workbench-rectangle-core.md#cut-wake-and-live-resume-follow-up--2026-11-07).

## Small native-debris tangent

Current only on dependent branch `codex/workbench-small-cut-debris-20261107`,
from unchanged Draft466 b140265d: a detached RedBrick component of1..16
remaining cells converts in place to alternating Sand2/Rust29 in sorted y,x
order, starting with Sand. This is the owner-selected existing granular path,
not the liquid inertial solver. Larger pieces retain the existing rigid route.
Native callers default to threshold0; the tangent workbench profile uses16.
No new menu or threshold setting is added.

Full eligibility precedes classification. Anchors and unknown/hot/masked/stateful
geometry still refuse. Main preflights exact version4 one-cell material stamps;
native revalidates all tuples and converts without aggregate removal/restoration
or Rapier allocation. DebrisCommitted phase8 fences ticks and mutations until
the updated terrain is installed; end re-primes the unchanged live roster.
Normal granular motion follows with no injected velocity or fabricated arrival.
Cell counts are preserved; material identity/density changes intentionally.
See the [small cut-debris tangent](../audits/2026-11-07-workbench-small-debris.md) for execution, source and limits.


## Brush admission correction

The owner found a real ordinary-painting gap in the initial qualification. The
old eight-rectangle limit rejected even the default radius-8 brush. The
[brush regression dossier](../audits/2026-11-07-workbench-brush-cut.md) records
the correction: up to 64 exact shapes within the shared proxy budget, lazy
frontier traversal and persistent plain-language refusal status. Actual
Windows/Linux worker-1/4 runs each pass 165 checks. The 1,024-member and
62-cell occupied-span limits remain; arbitrary-size cutting is not supported.

## Initial rectangle-fixture implementation checkpoint

Current on Draft #466: the registered release rules are implemented. Actual
Windows/Linux workers1/4 pass83 checks each and52 lifecycle checks per host.
The [dated dossier](../audits/2026-11-07-workbench-freed-objects.md) owns execution,
failures and runtime identities. A cold requested/applied region mismatch
refuses; use an ordinary Step or Play first. No hidden tick admits it. Full
Restore/Load/New blank uses checked whole-scene retirement when custody is live;
retained edits refuse. Contact law, parameters and accepted defaults stay fixed.

## Owner boundary and current source

The owner authorizes defining this contract and implementing normal-workbench
cutting on Draft #466, with no new test menu or change to physics. The accepted
four-body live demonstration remains open and must not be reset or closed by
qualification. Parent source is f56795ba8acd6c3c4a2e7d9280b83083e48e1c81.
**Current at registration:** ordinary erasing removes cells but performs no
native-to-Rapier transaction. This document defines the implementation target;
runtime evidence and implemented status must be recorded separately.

The old numerical rest and clearance failures remain historical evidence.
The owner accepts the demonstrated visible granular response. Do not tune the
contact law, gravity, damping, weights, gains, budgets or force/correction caps
to make that numerical screen pass. Main and parent PRs remain unchanged;
#466 stays Draft. Native material identity and existing refusals remain binding.

## What becomes freed

1. **Structural membership is face connectivity.** RedBrick43 cells sharing
   an edge belong to one candidate. Corner-only contact does not join them.
   Wall1 and Hard wall58 (ReinforcedConcrete) remain native anchor material;
   neither is released in this first normal-workbench rule.
2. **An anchor is a native structural connection.** A candidate touching1/58
   by an edge, or touching the canvas boundary, remains terrain. A RedBrick
   path transmits that attachment to its entire connected component. Sand2
   and ordinary FreeMass Water3 provide contact, not a structural bond.
   Contact after release does not weld a body back into native terrain.
3. **A completed erase stroke triggers the check.** Inspect the RedBrick
   neighbours of the erased footprint, including every resulting piece.
   Painting alone does not immediately drop construction while it is being
   drawn. Burning, explosions, Wood/bark/reactive and mixed structural bonds
   require separate material/lifecycle admission and are not inferred here.
4. **Freed describes eligibility for an ownership change, not visible motion.**
   An admitted body may immediately rest on a floor or in Sand. No extra kick,
   warm physics step, support force or positional correction is supplied.
5. **Unknown is not free.** Hot/stateful material, foreign/unsupported contact,
   missing residency, excluded region, transient mask, pending event, policy
   mismatch or failed World refuses transfer. The intentional erase remains;
   remaining source cells stay native and the disposition is visible.

The normal palette gains RedBrick in its existing material picker. There is no
new cut tool, fixture selector, scene or special object catalogue. Right-mouse
erase and the existing Erase paint selection use the same stroke-end operation.

## Bounded discovery and admission

Native owns discovery, eligibility and complete tuples. Inspect at most256
admitted erase dabs (radius<=24), up to64 actual native investigations and8
result pieces per stroke. Traverse the erased-disc frontier lazily after each
handoff; retired cells no longer consume investigations. Suppress repeated
seed coordinates. Refused components may consume several investigations;
these are not distinct-component counts. A 65th candidate records incomplete
discovery and retains its source. At most2,458,624 face checks and50,176
outward face incidences are enumerated; both counters include refused work.
Overflow is explicit; do not discard work and report complete discovery.

Each candidate has at most1,024 members, a padded64x64 discovery domain and at
most64 exact nonoverlapping rectangle proxies within the shared64-proxy
scene budget. The authored fleet and original SOL diagnostic retain their
eight-rectangle guards. Discovery first obtains a bounded
component box using fixed scratch, then invokes the existing native ownership
kernel. Do not substitute an AABB or impose a hardcoded tree search position.
Unknown boundaries and oversized components remain native. The existing
workbench limits of8 bodies/64 proxies include all old actors plus new pieces.
Capacity is checked before retiring any source cell.

The first lane retains the existing native ambient inert eligibility and
supported liquid-policy restrictions; it does not disable a chosen policy to
force admission. Full material/state/temperature tuples, shape union, unit
mass, centroid and inertia are authenticated. Mass is one unit per actual
member and inertia includes each unit cell's1/6. Density ranks are not physical
weight calibration.

## One owner through the handoff

One native World and its exclusive worker continue throughout a cut. The main
thread alone constructs bodies and touches Godot/RIDs. Complete the stroke's
already accepted brush commands in their original worker order, pause both
clocks, revoke controller/emitter leases and fence roster/settings changes.
Do not lose queued edits while establishing that hold.

Native prepare freezes a source-bound token, tick/revision, tuples and shape
partition. Main stages one inactive body in the existing held space, using
AUTO COM and unchanged native M/I, gravity0.094, damping0.04/0.04 and reference
friction. Existing bodies keep their RIDs, poses, velocities and numerical
properties. An empty canvas may construct its first physical owner without
replacing its native World.

Validate the entire prospective roster before acknowledge/commit. Native commit
retires only exact still-matching source tuples. Install the post-commit static
terrain under the same hold, adopt an explicit new roster session/epoch, then
finalize and retain the aggregate's complete ownership record. Never loosen
ordinary sample parsing to accept a changed roster or restamp old responses.
Clear retired application namespaces; publish a fresh live sample and preserve
main's completed-sample/terrain fence before resuming the user's prior pause
state. Old granular events must not be replayed or replenished by retries.

The existing single-aggregate diagnostic path keeps its original semantics.
The normal workbench has eight bounded active ownership records and one pending
transaction. Tokens and incarnation/sequence values remain monotonic. Cancel
before commit leaves source authority unchanged. An inactive committed failure
uses the existing rollback contract or quarantines; after activation there is
no restoration into cells. Post-commit unknown outcomes fail-stop and retain
ownership rather than retrying. Hash/CYPS APIs must continue refusing when active
native aggregate state is not serializable.

## Editing, persistence and retirement

Captured shapes use the same passive body representation and response path as
the owner-accepted fresh canvas. They have no pilot, equipment or propulsion.
There is no automatic reanchoring, welding, recutting of live bodies or #365
restoration in this change.

The authored start must record both the new body and exact removal of its
source terrain, in operation order. Version4 adds validated rectangle stamps
to the existing disc recipe; versions2/3 remain readable. Saving or restoring
must never reconstruct both original source cells and the new body. A named
pre-cut start still loads intact; a saved post-cut authoring start rebuilds fresh
bodies and does not claim serialized native runtime/token continuation.

Ordinary paint/erase, powder and observation continue after capture. Retained
owner replacement currently copies cells, not native aggregate ownership.
Until that separate transfer is admitted, actions requiring retained World/roster
replacement refuse explicitly while captured ownership is live. Whole Load,
Restore start, New blank and teardown may retire the complete owner and its
native records under their existing authoring/reset disposition. They must not
be used to implement the live cut. No hidden per-object deletion or source
restoration is substituted for these boundaries.

## Required qualification

Before reporting implemented success, test anchored/diagonal/disconnected,
multiple pieces, arbitrary component position, multiple sequential cuts,
existing moving body preservation, empty-canvas first capture, capacity and
unknown/material/thermal/mask refusals. Independently verify exact source
retirement and tuple/shape/M/I equality, one body per aggregate, no step during
handoff and native applied mode. Exercise cancellation, stale token/epoch,
injected construction/application failure, reset/load/save/teardown, workers1/4
and actual Windows/Linux with fresh source-authenticated binaries.

Record command/log/source/runtime identities, all failed attempts, storage,
latency and refused work. Run optimized/strict ASan/UBSan native and affected
Godot suites, frozen material/provenance/repository/docs/M11/retrieval checks.
Protected consumer edits require new independently reviewed per-file transitions;
never refresh a frozen guard or old receipt. No original SOL clearance/CPU,
MSVC, release/default or integration pass follows from these scoped checks.
