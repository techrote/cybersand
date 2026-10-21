---
title: GEN-007 Workbench 2 and procedural qualification
status: Current
document-kind: audit
scope: Issue 193 implementation checkpoints, declared qualification and dated execution evidence
canonical-for: []
last-reviewed: 2026-10-21
related-documents: [../systems/procedural-world-generation.md, ../systems/procedural-hierarchical-generation.md, ../systems/procedural-semantic-planes.md, ../operations/deepworks-exhibition.md, ../operations/github-development-and-release.md]
---

# GEN-007 Workbench 2 and procedural qualification

## Scope and starting identity

**In progress; not acceptance.** Issue [#193](https://github.com/techrote/cybersand/issues/193)
adds identity-bound native explanation, transactional visual authoring and a compact
1024 × 1024 procedural qualification scene. All eleven issue acceptance gates
remain required. Counts alone cannot establish Deepworks-equivalent visual polish.
Persistent runtime streaming, durable world mutations and reconciliation remain
GEN-006 [#194](https://github.com/techrote/cybersand/issues/194).

Work starts from main `285ddf6381bf0a8f6dc81fd15b470a8a9bad9547`, the merge of
GEN-005 PR #197. Its accepted source tree is
`ff7638bf15300e97ae500e385fc23f66a659b98a`. The issue #192 acceptance receipt
records its completed source-matched Linux/Windows runtime publication and
required pre-merge gates. No unrelated open PR is included in this change.

The implementation branch is `codex/gen007-workbench-qualification`. Three
parallel source owners cover native tracing/stages, authoring UI/transactions,
and the declarative scene/qualification apparatus. Integration, source-matched
runtime publication, canonical documentation and final review remain one task.

## Declared qualification and evidence

The required fixture is one 1024 × 1024 map projected into play, scripted,
effects and background. Required minima remain four major regions, eight named
subregions, 24 identifiable stable micro-features, two cross-chunk structures,
a primary route connecting every region, two optional loops and secondary
passages, four paired native play/rear exhibits and explicit depth treatment
in every subregion. One reference seed and three declared variants must pass.

The scene must use declarative reusable definitions, with recipe size, reuse
and manual placements reported. Native reagents and kernels must produce the
observed products. Every exhibit helper must report completion; no-op, absent
partner and aborted-helper controls must fail. Route checks consume final
rasterized play materials, including final hard overrides.

Captured evidence must include the real four-plane compositor, isolated planes,
routes and sockets, seams, close-ups and seed comparisons. Source, recipe,
runtime, renderer and image identities accompany the files. The visual review
uses the retained [Deepworks atlas](../images/deepworks/deepworks-atlas.png) and
[exhibition guide](../operations/deepworks-exhibition.md) as composition references.
It covers regional coherence, silhouettes, readable passages, layer correspondence,
detail density, material roles and visible seams. Deficiencies remain explicit.

## Acceptance ledger

| Gate | Initial state | Required evidence |
|---|---|---|
| Native explanations and actual intermediate stages | Pending | Independent material/field/stage comparisons; bounded truthful replay; stale refusal |
| Complete visual editing and diagnostics | Pending | Real graph, hierarchy, plane, field/vector, stage, density, cost, seeds and comparison interactions |
| Transactional edits and mixed undo/redo | Pending | Invalid input/budget preservation; canonical recipe and semantic/material reproducibility |
| Stale preview, trace and comparison rejection | Pending | Rapid edits, seed switches, undo/redo and fresh session identities |
| Reference plus three variant structure | Pending | Final-raster routes/loops, stable features, four-plane regional treatment |
| Whole/tiled/order/worker/budget equivalence | Pending | Equal baseline materials and semantic/fixture records |
| Native exhibit mechanisms | Pending | Complete eight paired-plane exhibit receipts and effective failure controls |
| Actual rendered evidence and visual review | Pending | Display-backed pixels, all required capture categories and candid comparison |
| Bounded cost and memory | Pending | Logical bounds plus separately labelled measured times/environment/peak memory |
| Canonical docs and retrieval | Pending | Source-backed contract routes, unchanged prior questions and new coverage |
| Platform and repository completion | Pending | Published source-matched Linux/Windows runtimes; final-head Documentation, Native, Godot and applicable apparatus gates; merge verification |

## Initial inspection and local environment

The source clone was clean before changes. All 18 required LFS runtime payloads
were restored from existing local copies only after their exact sizes and SHA-256
hashes matched this checkout's Git LFS pointers. No dependency pin changed.
The available environment provides GCC 13.3.0, GNU ld 2.42, the pinned godot-cpp
commit `101ae38034304346a46ea9ea84ae156d3e860496` and Godot
`4.7.stable.official.5b4e0cb0f`. Xvfb is available for actual OpenGL rendering.

A first headless editor import completed without script errors but emitted
sandbox socket-open errors. That invocation is **not a clean pass**. Required
local Godot execution must use an environment that permits its local sockets;
script errors, skipped render tests and zero-exit incomplete helpers never count.

Baseline retrieval before documentation edits: 101 documents, 1,109 heading
chunks, frozen 32 questions; hit@1 21/32, hit@5 32/32, MRR@5 0.7953. The initial
documentation checker reported six missing companion-workspace source references.
The five distinct referenced files were restored byte-for-byte from the same
companion commit used by hosted CI, `6a58311982941b75f46e22109a0829e5acb83c7e`.
These files live outside this source repository and are not implementation edits.

## Checkpoint protocol

Recoverable commits and PR comments retain progress and unresolved gates.
Iteration uses focused native and Godot tests. The PR stays draft while work is
incomplete, as required by the repository's CI cost policy. Source-sensitive
native changes need fresh Linux/Windows runtime publication. The final ready
transition runs every applicable exact-head gate before merge and issue closure.
