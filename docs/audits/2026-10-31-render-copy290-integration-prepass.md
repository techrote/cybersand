---
title: PR #290 render-copy integration prepass
status: Draft
scope: Non-admitted reconciliation against 31 October PLAY mainline
last-reviewed: 2026-10-31
---

# PR #290 — draft integration prepass (2026-10-31)

**NO MERGE / NO RELEASE / NO NEW PUBLISHER AUTHORISATION.** This candidate combines the #290 → #295 → #298 → #301 dependency history with current main solely for review. No original source or PLAY branch is modified.

## Fixed inputs and merge treatment

- Main: `adaaa37ae35ffcdaa961b80353be3a23b805c0cc` (tree `ad800ebd5c876f6d1ecd080a6dc3f02918b21870`).
- Render-copy published stack: #301 head `b5e415784d5e0884684869dd622883dacf3c9de5`, as merge second parent, current main as first parent.
- Preserve exact #301 Git blobs for production native code, INT64_MAX identity test/oracle, original source-matched LFS pointers and provenance, verification workflows, original owner-authorized publisher and dated evidence.
- Preserve newer `.github/workflows/native.yml` and its six-shard test structure; do not replace it with #301's now-obsolete monolithic job or its 15→30-minute sanitizer timeout edit.
- Preserve all current-main documentation, including 154 question objects, and resolve four overlapping paths additively: docs index, roadmap Rendering row, the unique RENDER-COPY-01 retrieval question (with publication-status correction), and the validation ledger (with dated historical evidence plus superseding #301 publication note).

## Native/runtime provenance

- Original P2 exclusive-endpoint overflow was corrected in source `60915dc86631271ea8661377a3458149adda9361`. `world.cpp` Git blob `a6afd8ca`, `test_world.cpp` blob `5613d216`. Do not reintroduce exclusive coordinate endpoints.
- Publisher [#40959131274](https://github.com/techrote/cybersand/actions/runs/40959131274) passed dual-host build, 2/2 remote LFS uploads and fresh-store materialisation. [Strict provenance #40961463487](https://github.com/techrote/cybersand/actions/runs/40961463487) passed for original published source.
- Retained LFS SHA-256: Linux `0f60213c7fc3f9a1b1d7ad5143fdb22d453a452cddefd3fe4d7b6cf45` (4,222,424 bytes); Windows `39bcf4c0fb4df8162acb88d5049c5c9d94a24ccd747593355eda805ed4670e9b` (4,824,064 bytes).
- Of the 80 native source-input paths in the original runtime manifests, **none** changed in the 64 commits from `aac0feb6` to `adaaa37a`. Fourteen of 558 *historical* build-ledger paths did (Godot PLAY scripts, `gdextension.yml`, test runners). Do not rewrite the historical ledger, relabel published runtime source, or trigger an unauthorized republish. The current `check_repository.py` checks source-input bytes/LFS hashes, not entire build-ledger equality or live host execution.
- The original publisher request and script are part of the recorded build-input set. Preserve them as historical verification material; do not replay the source-locked sequence 1 authorization or remove source-pinned files as cleanup.

## Remaining tests and decisions (not prequalified)

1. Read back candidate exact parents/tree, SHA-identity, `git diff --check`, documentation/retrieval checks, actual `git lfs fsck` and `check_repository.py --require-materialized`; these are not claimed as executed by this report.
2. Run full native normal, TSan, ASan+UBSan, other soliding/worldgen suites and Linux/Windows Godot/Rapier GDExtension/Water/render. Previous [Native #40971149450](https://github.com/techrote/cybersand/actions/runs/40971149450) passed on #301, but [Godot #40971092409](https://github.com/techrote/cybersand/actions/runs/40971092409) was **cancelled**, not a passing complete acceptance gate.
3. Reconcile pending #330's generous shared watchdogs before relying on current main's old 15-minute native ASan+UBSan limit; the historical successful single-process suite took around 20 minutes. #330 → #331 → #332 are NOT present here. Reconcile fresh against actual post-PLAY main and preserve all changed host/build-input contracts.
4. Run a 1024² Deepworks Hybrid graphical forced-full rendering session, reset, zoom/pan, pixel/oracle/packet comparison and representative CPU/lock/publication timings. Distinguish isolated-copy gains from overall FPS.
5. Require independent final-head review and entire final-head CI after subsequent PLAY merges. This prepass does not grant authority to mark ready, merge or release.

## Limitations

This is a draft-only combined-tree candidate and a concrete conflict-resolution proposal. No gameplay scheduler, Rapier, water/ACK policy, shaders, or native simulation default changes were introduced by the reconciliation. Upstream PLAY may still advance; the final integration must be reviewed against its new HEAD.
