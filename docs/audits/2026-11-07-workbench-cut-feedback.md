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

Qualification is in progress at this checkpoint. Windows OpenGL preflight gives
zero source-pixel difference on384 occupied pixels,516 transparent cells and
zero90-degree rotation difference. This small oracle is separate from actual
native-cut ownership and broad engine performance. Record raw commands/exits,
source/runtime hashes and remaining gaps before completed-result claims.

Preserve84/84 clearance,64/84 depth,36/36 overlaps,1452/1452 refusals, CPU,
#365, hard exclusions and tiny RedBrick1e-9 filter. Linux ABI-floor/MSVC gaps
remain. No original SOL clearance or Noita geometry redesign is admitted.
