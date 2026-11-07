---
title: Cut responsiveness and carried brick appearance
status: Current
document-kind: audit
scope: Draft510 presentation and terrain scheduling correction; fixed latency qualification, unchanged physics
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [../architecture/workbench-freed-objects.md, 2026-11-07-workbench-small-debris.md, 2026-11-07-workbench-carried-shader-transition.md]
---

# Cut responsiveness and carried brick appearance

Owner reports working debris, laminated bodies and1–2-second cut pauses; the
screenshot is explicitly old. Sole writer continues Draft510 from
2253eb2dd2e22f5dacb30cedd37084600e776656 on
`codex/workbench-small-cut-debris-20261107`. Parent Draft466 stays
b140265d1a2ef2fd76787f8048dbcc5e9fa545ac. No merge, Ready, default, native
law, mass/gravity/damping/cap change.

## Design choices

Old terrain scheduling marks all1024 chunks of2048² pending. Held cut drains8
per rendered frame, including unchanged/empty chunks: at least128 frames,
about2.13 seconds at60Hz. This is a simulation hold across yielding frames.
New validated packets diff installed geometry; only changes consume budget.
Partial supersession, shrink/removal and invalid-packet nonmutation retain exact
geometry. Global terrain retires even on empty packets. Logical empty chunks
have invalid RID placeholders; late chunks create no preceding empty bodies.
The8-chunk/2000-usec budget and final ownership/revision fence stay.

Ambient RedBrick43 source and exact rectangle union supply one carried RG8
material mask. Optional saved appearance records43 and integer source origin.
Legacy hashes stay; new hashes authenticate appearance. Physics definitions
remain identical. One image/sprite replaces per-collider seams; holes discard
and source coordinates retain brick pattern through actual body display pose.
Already-selected Shader/LUTs are shared; no first-cut shader variant/readback.
Main-thread caches retain at most8 images of at most130×130×2 bytes each.
Old authored bodies lacking appearance keep their original presentation.

Protected shader has a reviewed
[transition](2026-11-07-workbench-carried-shader-transition.md). Frozen guard,
catalogue/policy identities and nine prior transitions stay. All93 compiled
native inputs/artifacts equal build1826c994. No native rebuild or new sanitizer
execution is claimed for unchanged inputs.

## Registration and custody

Implementation/tests/profile committed at299866d81a02d2a516f2109d0feef5bfeb0235c0
before qualified execution. Profile `workbench_cut_responsiveness_001.json`
fixes2048²,60 maximum FPS, original520-member tree/16-cell debris,5 repeats,
Windows/Linux workers1/4. Report medians/ranges, frame gaps, recipe/stage/RPC
and terrain counts; no universal frame-time claim. Evidence cap1GiB/reserve5GiB.
`tools/sol281/workbench_cut_feedback.py` authenticates baseline2253 production
separately from current scripts/shader and unchanged native build.

Preflight observer incorrectly waited for Rapier in a debris-only scene without
an aggregate. It timed out and was stopped; corrected observer waits for native
Step. Harness preparation refused changed protected shader and ignored bootstrap
bytes; neither is positive runtime evidence. Read-only review caught late-chunk
RID allocation before registration; fixed without physics/threshold changes.

## Results

Production source is299866d8/c799863f; corrected external observer is
45e4c55b4a3ea071bcbe2bcd0ddd188bdea02f5e. All four corrected host/worker runs
pass219 checks with10 fresh cuts each. Earlier219/1 disk-assertion failures
remain in hosts-002; every retained small-debris230, brush165 and actual
tree/building83 suite passes per host/worker. Lifecycle52 and canvas/fleet/
pilot/input controls pass per host. Native worker4 participation is observed.

| Host/workers | Tree baseline median ms | Tree candidate median ms | Candidate range ms | Debris baseline/candidate median ms |
|---|---:|---:|---:|---:|
| Windows1 |2532.963|463.363|450.613–500.297|203.051 /200.957|
| Windows4 |2544.387|481.705|431.790–483.953|217.081 /202.882|
| Linux1 |2399.977|316.586|300.037–316.697|133.365 /133.325|
| Linux4 |2399.829|316.885|316.686–333.531|133.689 /150.014|

These are complete five-repeat local transactions at maximum60 FPS, with
overlapping host/graphical campaigns and ordinary desktop scheduling. Reported
maximum frame gaps are about17–32ms, not multi-second main-thread blocks. First
tree owner installs32 occupied floor chunks rather than1024 pending chunks;
native-only debris has no physical terrain to install in either arm. Thus the
large cut improves; no general debris CPU improvement is established. Heavy
first-owner terrain, refusal discovery and authored-recipe reconstruction can
still cost time. No universal60Hz or zero-pause claim.

Actual Windows OpenGL and Linux X11 graphical oracles each give zero source
pixel difference on384 occupied pixels,516 transparent cells and zero90-degree
rotation difference. Linux initially exits0 but strict logs fail from absent
audio hardware; an explicit Dummy-audio rerun is clean and retains the same
render result. Existing Windows material-presentation test fails its growth
decor/camera assertion on both original2253 shader and candidate. This inherited
failure remains a readiness blocker, not a new material-render pass. Compile-
bounds and LUT controls pass Windows; Linux raw runs have audio diagnostics.

[Compact command/source summary](workbench-cut-feedback-20261107/summary.json),
[full timing ranges](workbench-cut-feedback-20261107/timings.json) and
[raw artifact index](workbench-cut-feedback-20261107/raw-artifact-index.json)
retain source/runtime hashes, exits and refused/failed attempts. Local campaign
is `build/workbench-cut-feedback`; no raw logs, caches or binaries are committed.
The evidence footprint was360,688,304 bytes with14,538,866,688 free at observer
completion, within1GiB/5GiB bounds. No new native-sidecar memory is introduced.

Decision: PASS for the scoped cut rendering and scheduling correction;
CONDITIONAL for broader platform/release admission with inherited blockers.
Independent read-only source review completed; request separate adversarial
review before an owner integration decision. The owner's later inscribed-core
proposal is a distinct representation/material experiment and is not executed
or accepted by this correction's numerical results.

Preserve84/84 clearance,64/84 depth,36/36 overlaps,1452/1452 refusals, CPU,
#365, hard exclusions and tiny RedBrick1e-9 filter. Linux ABI-floor/MSVC gaps
remain. No original SOL clearance or Noita geometry redesign is admitted.
