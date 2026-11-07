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
