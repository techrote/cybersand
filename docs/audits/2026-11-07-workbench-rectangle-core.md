---
title: Interior rigid core and native Sand fringe
status: Current
document-kind: audit
scope: Owner-directed RedBrick approximation on a dependent draft branch; complete source proof, one interior rectangle and explicit material conversion
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [../architecture/workbench-freed-objects.md, 2026-11-07-workbench-cut-feedback.md, 2026-11-07-workbench-small-debris.md]
---

# Interior rigid core and native Sand fringe

Owner asks for a rectangle inside a cut piece, with excess becoming Sand.
Sole writer branches `codex/workbench-rectangle-core-20261107` from stable
Draft510 head53d642b8b0c7b773318ed1660a657d38e9ec6800. Draft466 remains
b140265d; main and accepted defaults are unchanged. Registration899a939d
precedes implementation/builddf5fa14ebac93852660489437e270064120cb346.
The fixed profile is `native/tests/fixtures/workbench_rectangle_core_001.json`.

## Design choices

Complete existing source proof comes first: face connectivity, all tuples,
anchors, state/temperature, foreign contact, mask, residency, region, policy and
pending events. The original component is bounded by1024 cells/62-cell span.
Sources1–16 retain Sand/Rust crumble. Larger sources choose the largest fully
occupied cell-aligned rectangle. Ties prefer lowest y, lowest x, greatest width,
then height. There is no new minimum core size/aspect threshold. Selection occurs
before exact-partition capacity: a jagged833-cell lattice with289 exact runs can
choose one33-cell rectangle. Native default/control remains exact; the ordinary
workbench on this branch requests core mode. No new menu is introduced.

The rectangle is one rigid body/collider. Every other source cell converts in
place to ordinary native Sand2, with zero ordinary state, no kick and no arrival
stamp. This deliberately changes shape/material and reduces rigid mass. Core
mass is retained-cell count and inertia includes cell1/6, using the original
unit convention. Catalogue density ranks are not physical mass. Gravity,
damping, friction, LA-SELECTIVE law, gains/caps/budget and liquid policy stay.
Hollow buildings can leave one wall segment; the rest becomes Sand. Reversal
requires choosing exact mode before a fresh cut, not undoing a live conversion.

Pending tuples are sorted core prefix/fringe tail. A complete original-source
digest and partition bind the reservation. Commit revalidates every original
tuple before retiring core and converting fringe under one fence. Partial failure
records actual ownership/conversion and quarantines. Generic committed rollback
refuses this representation. Matching post-all-mutations terrain and roster
precede activation; archive owns only core tuples. Counts satisfy
`source = owned core + native Sand fringe`. This is cell custody, not total
physical mass/energy conservation. Core-only material image retains brick shading.
Saved recipe coalesces exact fringe row spans; stamp/file budgets preflight before
commit. Fresh Restore never recreates both brick fringe and Sand.

## Executed qualification

| Original cut source | Retained rectangle x/y/w/h | Core mass | Native Sand | Native inertia |
|---|---|---:|---:|---:|
| Tree520 |44/27/16/13|208|312|7366.6666667|
| Building356 |50/27/4/38|152|204|18493.3333333|

Each actual Windows/Linux worker1/4 corrected suite passes4206 checks. Four
workers are observed. Four fresh cases per run cover both structures on dry
and Sand beds, building plus an existing passive barrel,120+ unpowered steps,
actual current-roster application, exact per-cell pre-step census, real core
collider/mass/inertia, saved recipe/readback/Restore and precommit recipe-capacity
refusal. Existing RID/motion and same-World/no-hidden-step handoff pass. All
original1–16 debris230, brush165 and whole520/356 controls83 pass per host/worker.
Legacy52 and core52 lifecycle checks pass each host; canvas/fleet/pilot/input pass.
Original refusal facade passes each host/worker. These are functional episodes,
not a repeated settling or original SOL clearance campaign.

Optimized and strict ASan/UBSan each pass12314 workbench/core plus19338 original
transaction checks. All511 nonempty3×3 masks, workers1/4, use an independent
prefix-sum exhaustive rectangle oracle. Ties, disconnected sources, cancellation,
one-use commit, core-only archive, ledger,17-source/16-core discrimination,
833-cell lattice and discarded-tail Wall/hot/mask/foreign refusal pass.
Leak detection is disabled; extension-host sanitizers are not claimed.

Initial host observer correctly received refusal for a cold Restore contact
census and then emitted1756 derived failures. Production was unchanged. Corrected
external fixture reads the native copied render image at tick0, matching native
generation/serial; its SHA256 is
e16ee34a7a092f810c46c7ea00eae094ecffca870d60bbd9b67a1fd0937dd139.
Identical observer source is committed at25f79e5a27e50661bcc747e460c692338f89de92.
All failed attempts remain indexed. Both hosts' actual graphical material test
passes with zero source/rotation RGB error and transparent holes, using Dummy
audio explicitly. Parent's independent shader transition remains unchanged.

## Source, resources and limits

Fresh Windows/Linux artifacts bind complete93 native plus15 build inputs and
full SDK dependency inventories. No protected material source or identity changes
from parent; all ten reviewed transitions/frozen lock remain. Windows uses actual
LLVM-MinGW host execution, not MSVC. Linux is actual WSL Ubuntu24.04/X11.
Rebuilt ELF imports GLIBC2.35/GLIBCXX3.4.31/CXXABI1.3.9: accepted2.34/3.4.30
floor fails. Native custody storage278776 bytes,392 above parent; no new per-cell
sidecar. More loose Sand can increase simulation work despite fewer colliders.
Existing2048² arrival history42.47MB and heavy-activity quarantine limits remain.
512² functional cut timings are not the parent's2048² matched latency campaign
or original SOL24-group/3-repeat/2ms CPU gate. No universal60Hz claim.

[Build](workbench-rectangle-core-20261107/build.json),
[native](workbench-rectangle-core-20261107/native.json),
[host controls](workbench-rectangle-core-20261107/hosts.json),
[corrected observer](workbench-rectangle-core-20261107/observer.json),
[facade](workbench-rectangle-core-20261107/facade.json),
[graphics](workbench-rectangle-core-20261107/graphics.json),
[ABI](workbench-rectangle-core-20261107/abi.json) and
[runtime custody](workbench-rectangle-core-20261107/runtime-validation.md)
retain commands/exits, source/runtime hashes and qualifiers. Raw campaign lives
under `build/workbench-rectangle-core`, with1GiB cap/5GiB free reserve.

## Decisions

PASS for bounded interior-core/Sand custody and functional falling on these
sources. CONDITIONAL for gameplay promotion, pending owner feel and independent
adversarial review. Original whole-geometry SOL clearance remains unproved;
historical NO-GO is preserved, with84/84 clearance,64/84 depth,36/36 overlap,
1452/1452 refusals, CPU, #365, hard exclusions and tiny RedBrick1e-9 filter.
Integration remains CONDITIONAL with ABI, inherited Windows growth/camera test,
MSVC and authority/material gates. This does not admit a general mesh solver,
live-body recutting, restoration or cross-owner recovery. Keep all PRs Draft;
request independent review before an owner integration decision.


## Remaining cut-hitch correction — 2026-11-07

Owner reports a remaining pause on the accepted rectangle-core build. Fixed
registration35f41ba7 precedes the correction; baseline production is55cbc819,
with observer-only v4/fresh-scene fixes40c36b41/b041f576. The profile is
`native/tests/fixtures/workbench_cut_hitch_001.json`. Initial baseline attempts
001/002 had harness errors and were stopped; their logs remain local. The
corrected benchmark uses a fresh native World for each repeat, four routes,
60/30 FPS, five repeats, Windows/Linux workers1/4, plus a2048-square erased
paint-history stress case. Thresholds and physics are unchanged.

Design choices: replace per-frame RPC polling with a one-use main-thread
notification latch; keep the mutex-protected copied reply mailbox, serial,
World generation,20-second timeout and fail-stop behavior. The GDScript owner
schedules deferred wakeups after unlocking; native pool workers call no Godot
APIs. Stop/replacement/retirement retire notifications. Each refused `next`
investigation still executes; up to eight run consecutively before one immutable
publication, stopping at an accepted payload, terminal status or unexpected
failure. Every native refusal and counter remains in ordered receipts and the
status denominator. Body staging, both frozen physics frames, commit, terrain
installation, finalization and fresh-sample pacing stay separate and unchanged.
No acknowledgement/commit fusion is introduced.

Saved-canvas reconstruction uses exact sorted disjoint row spans rather than
per-cell replay and full-row scanning. Original stamp order, integer disc raster,
Empty erasure, same-material coalescing, output order and final4096-run limit
remain. Intermediate excess can still be erased. This reduces uniform-area
work; adversarial fragmented histories remain bounded by existing authoring
limits rather than a universal frame-time promise. Cut timing stops accumulating
at completion; later census RPCs cannot inflate it. First render-parts observer
CPU time can hit an existing cache and is not GPU first-presentation latency.

Production correction14f7c60c is qualified by160 fresh matched episodes per
arm:32 host/worker/FPS/route cells with five repeats each. All32 candidate
medians are lower under the registered rule, with exact ordered native-attempt,
source/geometry, mass/inertia, frontier/discovery and conversion-counter parity
in every episode. The [comparison ledger](workbench-cut-hitch-20261107/comparison.csv)
retains unrounded microseconds and per-cell minimum/maximum. The
[summary](workbench-cut-hitch-20261107/summary.json) and
[raw custody index](workbench-cut-hitch-20261107/raw-artifact-index.json)
retain all cohorts, commands, statuses, hashes, failed attempts and resource use.
The reproducible analyzer is `tools/sol281/compare_workbench_cut_hitch.py`.

Windows worker1 at60FPS: median first-tree hold309016→179138usec;
appended-building278087→219310; refused cut254956→49867. The deliberately
heavy2048-square history stress medians fall from8.018–9.281seconds to
0.080–0.103seconds across the four host/worker combinations. These are starting
recipe CPU costs, not the measured duration of the owner's particular pause.
Tiny debris at30FPS remains approximately200ms on Windows: nominally lower
medians do not establish a meaningful improvement there. The six-request handoff
and deferred delivery still take frame opportunities; both frozen physics-frame
checks remain. [Godot's deferred-call contract](https://docs.godotengine.org/en/stable/classes/class_callable.html#class-callable-method-call-deferred)
explains idle delivery. This is no universal60Hz, zero-pause or original SOL CPU
result. Fragmented histories may retain more temporary interval storage than
the old dense bitmap; adversarial editor peak memory was not measured. Native
arrival-history storage/capacity is unchanged, including42.47MB at2048square.

Actual Windows/Linux workers1/4 each pass the597-check benchmark plus4206 core,
230 debris,165 brush and83 whole-object checks. Both hosts also pass154 exact
row-span oracle checks,18 notification/timeout checks and24 actual-worker
transport checks, plus retained canvas/fleet/pilot/input controls. The initial
Linux core lifecycle observer missed a short phase:50checks/1failure is retained
in candidate-001. Observer-only a8649e99 holds a test subclass at pre-acknowledge
or post-commit/pre-finalize, checks actual phase, then tears down the owner.
All four Windows/Linux exact/core reruns pass56checks each against the unchanged
14f7c60c production project. No production delay was added to rescue the observer.
The replacement bookkeeping test runs after worker join; it does not prove a
concurrent replacement/shutdown schedule. Actual before/after-publication stop,
late/stale reply, timeout, retirement and discovery transport refusal are covered.

All nine implementation-head docs/M11/material/compiler/repository/runtime/
retrieval/diff gates pass at14f7c60c. Final documentation-head gates are recorded
separately in the PR with exact head and receipt hash. New native compilation or
sanitizer execution is unnecessary for unchanged compiled inputs and is not claimed.
Native93-source plus15-build-input inventories, material guards and both compiled
binaries remain unchanged. No fresh native compilation or sanitizer run is
claimed for this GDScript-only correction. Draft519/510/466, historical SOL
failures and platform admission blockers remain separate and unchanged.


Performance decision: PASS for the registered lower-median comparison and exact
functional/ownership equivalence; CONDITIONAL for a universally hitch-free
workbench. Original whole-geometry SOL physical clearance remains NO-GO, and
general integration remains blocked by the retained Linux ABI floor and other
historical qualifications. No force, mass, gravity, contact law, material ID,
capacity, accepted default or parent PR changed. Keep Draft and request separate
independent adversarial review before owner integration.

An immutable Windows preview from the tested production project is left open as
“CyberSand · Faster cuts · Draft #519”. Existing user windows/drawings were not
reset or closed. Existing local launchers now select this package. It starts the
same native512-square cut canvas with one initial region Step before any body
exists. OpenGL/NVIDIA581.80/TITAN RTX, Godot4.7 and Rapier0.35.2 startup/readback
are recorded; this is a GUI startup observation, not a graphical latency cohort.


## Cut wake and live-resume follow-up — 2026-11-07

Owner still observes tens/hundreds of milliseconds after c7af5809. Registration
87dbe5f6 fixes the next experiment before implementation. It retains the same
paused inputs and reuses the immutable14f7c60c/c7af5809 production cohort as a
historical baseline; wall-clock cohorts differ. A new source-identical observer
runs fresh live Windows/Linux worker1/60FPS tree/building repeats five times per
cell, measuring held completion and first observed actual native/Rapier resume
separately. The exact first physical-step count and cut-end sample are asserted;
no missing first observation is silently treated as complete coverage.

Design choices: a cut-only semaphore replaces the held-owner polling sleep.
Only an empty held turn may wait after a mutex recheck. Request/stop/retired-hold
replacement post after unlock; stop posts before joining. Normal tick cadence
is unchanged. Separately, opt-in normal cuts prefetch the first bounded native
next after accepted begin; main had no mutation between these two calls. Begin
and every native discovery receipt retain their order. Main consumes prefetch
once; missing/malformed data fail-stops. Direct census/control begins retain old
semantics. Publication follows prefetch, while the native begin receipt captures
the earlier Idle state. No acknowledgement/commit/finalize fusion occurs; both
frozen physics frames and all existing ownership/terrain/sample fences remain.
[Godot Semaphore](https://docs.godotengine.org/en/stable/classes/class_semaphore.html)
requires waking waits before owner/thread destruction. Native pool workers call
no Godot APIs; the existing exclusive GDScript owner uses this value-only signal.

Qualification is pending at this checkpoint. Native93+15 compiled/build inputs,
material guards, physics/core mass/gravity/caps and all historical failures stay.
The fixed profile is `native/tests/fixtures/workbench_cut_wake_001.json`.
