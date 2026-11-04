---
title: Workbench 394 current-main reconciliation and final validation
status: Current
document-kind: evidence
scope: Owner-accepted desktop workbench reconciled with accepted pressure wake summaries; resulting-source runtime publication and Ready gates, with merge held
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-workbench394-cleanup.md, 2026-11-04-workbench394-material-source-transition.md, 2026-11-04-lcb201-world-pressure-transition.md, ../operations/github-development-and-release.md, ../systems/player-control-playground.md]
---

# Workbench 394 final validation

## Owner authority and exact intake

The owner tested Windows package source `a393a797ad7c535fdf177143e660838726ad9ba2`, confirmed flyer switching/tuning, and then said: "Yeah it's brilliant go ahead." The [cleanup acceptance record](2026-11-04-workbench394-cleanup.md#owner-acceptance-and-final-validation-intake) retains the scope. This authorizes proceeding to Ready and final qualification of the desktop workbench. **Leave PR #394 unmerged.** The per-flyer controls/options suggestion remains a separate follow-up; current controller, Q/E mapping, authored flyer values and sleep boundaries are retained.

Intake PR head is `f44488e9b24c61db3924685ef3723296ab768533`, with hosted Documentation/provenance run 41928761530 successful. Acceptance is recorded at `a972b5d2`. Fresh accepted main is `ee92dc45b12455f01218394fd773da516caf356e`, which includes merged #396 and #382. It adds the reviewed pressure wake-summary implementation, execution identity 4 and its own source transition. The prior `751edc0b`-based workbench qualification is historical evidence for its exact source and cannot establish resulting-source qualification.

## Combined pressure source and admission

The ordinary main merge preserves both histories. Native `world_pressure.inc` auto-merges; independent source review found no edit necessary. All 65 accepted P1 pressure delta lines remain identical, and the workbench liquid inheritance and reference column-parallel route remain intact. P1 wake-summary mutation is cached-only; the workbench pool dispatch is admitted only with `!cache` and joins before row repair/wake processing. Cached wake-summary state remains serial. The combined LF SHA-256 is `9977b8c49bfb523acf2f0abcedfc6cc99e2348c60e2bbbfeb29d1fc53738c1a8`.

The adopted #382 step is retained verbatim:

- Path: `native/src/world_pressure.inc`.
- From LF SHA-256: `c8cb11512e935d05e099d8f155c1659473a7f61aa301e2e4900e55bdcfe4024b`.
- To LF SHA-256: `d766e808e88287f3f9ef1b833d790106e56eb512654a350716c8573beb30a874`.
- Retained source commit: `e5416b81bebf7ce79ac9894f7f9edf88f63b58da`.
- Record: [accepted P1 source transition](2026-11-04-lcb201-world-pressure-transition.md).

The previous unadopted #394 pressure entry (`c8cb...` to `a1dd...` at `1ca90de5`) remains valid historical evidence in the earlier audit/commits. It is replaced for this candidate by a chained step **from adopted P1 `d766...` to combined `9977...`**, pinned to the retained combined-source merge commit after it exists. The other two reviewed workbench entries (World.cpp and world_inertial.inc) are unchanged. The frozen lock, twelve identity inputs, material/capability digests and checker rules are unchanged. This source checkpoint intentionally precedes the final pressure entry and runtime publication; it is not a passing release checkpoint.

## Runtime and qualification stages

The combined native source requires new Windows/Linux GDExtension artifacts and authenticated provenance. The old `1ca90de5` artifacts are retained only as the previous source-qualified checkpoint until those builds complete. Frozen owner-review packages remain untouched. Runtime publication must use pinned Godot-cpp and the existing compiler scripts, actual output hashes and all actual production inputs; no manual acceptance of stale input hashes is permitted.

Required resulting-source gates are Documentation/provenance, all six Native families plus `native`, both GDExtension builds and complete Linux/Windows shard coverage/aggregates, Issue49 Water apparatus and Palette backend/readback. Both scoped workflows apply to this implementation. Source advisories and old Draft skips grant no exemption. Record PR head, actual executed commit/tree and run/attempt identities; a synthetic PR merge commit may differ from the published head.

Fresh focused reference pressure-head/P1 tests, rebuilt-runtime workbench controls, MAT source/adverse checks, inactive-main differential and independent resulting-source review supplement those hosted gates. Actual outcomes, failed attempts, runtime identities and final review are recorded below as they complete. No pending/skipped gate is a pass. No merge or programme closure is authorized.
