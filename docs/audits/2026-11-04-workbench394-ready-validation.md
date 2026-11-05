---
title: Workbench 394 current-main reconciliation and final validation
status: Current
document-kind: evidence
scope: Owner-accepted desktop workbench reconciled with accepted pressure wake summaries; resulting-source runtime publication and Ready gates, with merge held
canonical-for: []
last-reviewed: 2026-11-05
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

## Retained combined checkpoint and chained entry

Combined native build/source checkpoint is `d04fe009c2d5ab45f49a1d02cd36bb377f5d9873` (ordinary merge of owner-acceptance branch and accepted main). The new workbench pressure step is pinned to this retained commit: `native/src/world_pressure.inc`, from LF SHA-256 `d766e808e88287f3f9ef1b833d790106e56eb512654a350716c8573beb30a874` to LF SHA-256 `9977b8c49bfb523acf2f0abcedfc6cc99e2348c60e2bbbfeb29d1fc53738c1a8`, issue 391 / PR 394. The active table has four transitions over three protected paths; the adopted #382 step and two unchanged workbench entries are retained. Exact-entry independent review and full guard/adverse controls remain pending until recorded below.

Fresh focused source qualification passed reference serial/parallel and one/six-worker head parity (827,303 checks, exit 0), P1 quiet/invalidation, remote-head wake, single-quiet-tick protection, default-policy preservation and execution-4 readback. Four simulation objects were freshly built with GCC 13.3 (`-std=c++20 -O1 -g1 -pthread`); input hashes matched before/after. The focused receipt `build/reconcile394-pressure/receipt.json` has raw SHA-256 `462a83ca15a48e67777172550d6e9c622f580d949c65e5f6d7fa88d24ac0c761`. Independent focused composition verdict: GO; full resulting-source qualification remains open.

## Preflight results and retained ABI failure — 5 November

At native source `d04fe009` / admission head `4eb87606`, all 118 MAT catalogue tests, compatibility/compiler and compiled native metadata parity passed. Independent review authenticated all four transition entries, unchanged checker logic, frozen lock and twelve identity inputs. The MAT receipt `build/ready394-mat/execution-receipt.json` has raw SHA-256 `4073cd107b12acf3491237b7aa9432ec0a78ef017a30d455e4516258ca65f7eb`. This scoped technical GO does not qualify a failed runtime floor.

The inactive accepted-main/combined-source probe also passed all 192 observations against `ee92dc45`: 25,478,922 identical complete CYPS bytes, SHA-256 `902dc1c553e6f49d6694c55c875143fd07c164e0d8452e5158beda3e9b7fa519`, with matching physical hashes, tick work and legacy contact counts/impulses. Commands/logs are retained under `build/ready394-differential`.

Both source-matched runtimes were built from all 83 native production inputs, using pinned Godot-cpp/GCC/LLVM-MinGW. Windows DLL SHA-256 `1f9edfe1755581e38b11dfda23a3cdd87b639a493ae00bbdff78b2f1a0430352`; Linux SO `aeef06e89fd48f2df6d7135151c76e2fc37f4be4a995e1d2cb967ebace13aed9`. Both actual-OS import/fleet80/pilot179/pressure-optimization4152 cohorts exited cleanly, eight processes total. These are development/preflight results, not release acceptance.

**Failed Linux runtime floor:** `tools/check_linux_runtime_floor.sh` found CXXABI 1.3.13 imports where the accepted floor is 1.3.9. GLIBC 2.34 and GLIBCXX 3.4.30 pass. The added imports are `std::exception_ptr::_M_addref/_M_release`, introduced by the earlier workbench pressure worker relay: the owner-tested `a393a797` package also has them, while accepted-main #382 retains 1.3.9. The full floor log is `build/ready394-runtimes/linux-runtime-floor-complete.log`, raw SHA-256 `475a9d39a72a389dfad0c84af6138241948bd4759c99595a55d44ff20d092a08`. It exits 1. Runtime qualification is blocked until repaired; no checker or compatibility limit is weakened.

The first Windows build attempt also stopped before compilation because Git Bash resolved `python3` to the Windows Store alias. The preserved retry used an ignored, child-process-local shim to the installed Python, without OS setting changes; the pinned source/toolchain verification remained active. The complete build/host summary is `build/ready394-runtimes/summary.json`, raw SHA-256 `0210a93b33b41a588a036519084696114c7146f3a52e4d2e1b7a15f74c869c76`.

The planned repair is limited to transporting pressure-worker failures as bounded values and raising them on the owner after the join, preserving the existing World quarantine contract and healthy pressure results. Its source, failure-path tests, new admission step and rebuilt runtime results must be recorded before Ready execution.

## Bounded pressure-worker failure relay

The repair replaces `std::exception_ptr` only in the pressure-column task relay. A private value contains a standard error category, truncation flag and fixed 192-byte message buffer. Capture is `noexcept` and allocation-free; it never reads beyond the fixed diagnostic bound. After the existing full pool barrier, the owner raises the corresponding common standard exception. `bad_alloc` remains `bad_alloc`; length/out-of-range/invalid-argument/logic/runtime categories and bounded messages are retained. Arbitrary subclasses normalize to their caught standard base; otherwise unknown standard/nonstandard failures become `runtime_error`. These failure-only diagnostic differences are explicit. Healthy head math, counter merging, P1 wake summaries, controls and material laws are unchanged.

The fixed buffer increases bounded pre-reserved per-task storage; no heap-owned exception is retained in a task. The private helper is an actual production input, so the rebuilt input ledger must derive its new count. No public fault-injection knob or new pool owner is added.

The permanent relay regression is included in the existing native core pressure lifecycle case. It verifies error categories/messages, marked truncation, unknown failures, reset and actual `std::jthread` drain-before-owner-throw. It does not impersonate an injected failure in the private World pool. Real healthy World/pool parity and existing actual-World capacity/quarantine/refused-continuation controls separately test that composition. Fresh normal GCC13 qualification passes 827,303 head checks, the relay/quarantine/P1 controls and execution-4 readback; the final object has no exception_ptr references. Receipt `build/reconcile394-abi-floor-final/receipt.json` SHA-256 `d4d815e30b9572e3d02f425cef214bcddf70bc6a72f46292092099216ea7cc95`. Initial ignored-runner syntax and anonymous-namespace warning attempts remain retained.

The repaired pressure LF hash is `7b28bf216bf70af7059267cae31117f1f01e88d0e5f276f61d67280ab5c6d2e5`; the earlier combined hash remains `9977b8c49bfb523acf2f0abcedfc6cc99e2348c60e2bbbfeb29d1fc53738c1a8`. The subsequent admission step will pin these to the retained repair source commit. Exact new runtime-floor and target-OS results remain pending.

Affected-document map: the threading guide owns worker/owner failure lifetime, the configuration reference owns the fixed scratch bound, this dated record owns source/ABI evidence, the existing material transition guide owns unchanged checker rules, and the player guide/roadmap/retrieval routes own workbench controls and progression. Public message layouts, material authority, fluid laws, ADR-010 quarantine semantics, dependency pins and flyer bindings are unchanged.
