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

Current preflight disposition: owner acceptance, accepted-main reconciliation, ABI repair, source admission and rebuilt-runtime checks are complete. The exact resulting-head hosted status is owned by the PR ledger; merge remains held. Earlier stages below retain their original failures and qualification limits.

## First complete hosted campaign — 5 November

Published head `38b9464efcfad8b0368418b1c2c6b96e4a5528b0` executed as synthetic merge `0b5e409dd0c30e4e6bb3ee5f151ca17688bd4579`, with the same tree `dbf68b4d0c95418aa56d0467cbfa8ac567117765`; Palette explicitly checked out the published head. Attempt 1 passed Documentation/provenance (41941292131), all six Native families and the independent 166-case aggregate (41941292138), and corrected Water's sanitizer/adverse controls and complete 120-case baseline (41941292139). Native/Water evidence receipt `build/ready394-native-water-triage/receipt.json` has SHA-256 `1bef61b259aa2b3807a235d60173793b19d447eac2400fdb93dce51d358332ad`.

**Godot and Palette failed.** GDExtension run 41941292157 built both platforms and executed all 514 assigned cases: 264 Linux cases (including 14 actual-display cases) over 21 shards and 250 Windows cases over 20 shards. Twelve workbench fixtures were present. Execution coverage cannot pass merely because every case ran: retained diagnostics, assertions and two Windows post-summary access violations still block qualification. Palette run 41941292111 also failed its backend/readback gates; passing framebuffer assertions did not excuse shutdown diagnostics. Original cohort archives, logs and reports are retained under `build/ready394-godot-ci` and `build/ready394-palette-triage` and in their hosted artifacts. No failed case is waived or silently retried.

Focused reconciliation identifies a malformed legacy request reading `scenario_reset.id` before contract validation, a legacy Blacksite fixture submitting ten brush commands into the new explicit eight-command bound, omitted historical script observations in published runtime metadata, and a Scooper census consulting a legitimately retired response-history sample after pause. These have separate fixes and controls; they do not justify changes to force, torque, response age, material laws or flight tuning. The rendering/host shutdown diagnosis remains separately qualified. New source and metadata must pass local controls and a fresh resulting-head hosted campaign before readiness can be claimed.

### Focused desktop repairs

The added `WorkbenchBridge._next_session` GDScript static variable is replaced by a main-loop-owned scalar counter. Baseline/current/one-change/reintroduced-static controls use the same native runtimes and pinned engines. Removing only that static variable eliminates the reproduced Palette/pilot leaks; restoring it restores the leak diagnostics. Session IDs remain monotonic across graph retirement, with explicit maximum-capacity refusal and a main-thread allocation guard. Fleet regressions additionally verify that an old packet cannot authorize a new session at the same epoch. No palette, usable-runtime, library, force or response-law change is needed. Both target OSes pass actual-frame vapour, pilot, Acrobat, flight-lab and fleet controls after the repair; full hosted shutdown coverage remains required, including the two original Windows access violations.

The causal receipt `build/ready394-leak-probe/summary.json` has SHA-256 `d53322279666d629a3f474745e9cb6a52008ad6edfad1874accd9728fca3a30e`. Both final fleet controls pass 88 checks; the pilot's four physical metrics are bit-identical before/after and against the same-runtime baseline. The verbose Linux fleet footer retains eleven unclaimed StringNames, without an ERROR/WARNING, ObjectDB or resource-leak diagnostic; the raw observation is preserved rather than waived. Reintroducing the static counter reliably restores the measured leaks but did not reproduce the intermittent Windows access violation in every reverse-control sample. Full hosted Windows exit coverage remains necessary.

The missing-identity request now reaches the existing host validator, preserving the live World. Its regression additionally requires explicit contract refusal rather than allowing a script exception to masquerade as refusal. Windows before: 24 assertions, one failure and the original script error; Windows/Linux after: 24 assertions, zero failures, clean exit. Receipt `build/ready394-render-refusal/receipt.json` SHA-256 `ad05b10091c62673488c0ee90841538d2c26b42a58e7163b3fcc888923c4135f`.

Blacksite's seam plus nine room probes retain all their original cell, camera, lifecycle and off-camera stepping checks. The fixture waits for the first seam-plus-seven publication before sending the last two probes, respecting the unchanged eight-command bound. Both OSes pass 251 assertions with clean exits. The Scooper census keeps four bounded copies taken immediately after actual sample submission and joins them by session, epoch and sample. It preserves every material/frame/pose comparison and adds an explicit sample-serial assertion. These observer-only copies grant no response authority and do not enlarge production history. Final Windows/Linux runs each pass 72 assertions with no diagnostics; receipts `build/ready394-godot-ci/local-workbench-final-windows.json` / `local-workbench-final-linux.json` have SHA-256 `e45ac6496b9109705a202639c3872538804c53ff718b95a3cc639374d7ad4d6e` / `90a39c1fdcb03cac12cc5fb09ca45a85f08b1b1388896a73be63726cd76b59ae`.

Both runtime manifests again include 514 historical `.gd` hashes authenticated against retained source `acce570e` and its actual scoped host-input receipt, alongside the original native build-tool inputs. Their explicit scope grants only comparisons with current files; later mismatches remain visible, and mapped-module/executed-script binding remains unverified. No current hash is substituted to imply new-head execution. The unchanged host-evidence fixture passes 38 assertions on Windows/Linux, with clean exits; metadata receipt SHA-256 `d81bc09be21b3e54a132e887388ad60a4d32c0cf35793a88413c5f18b69e34b5`. All 84 native production inputs, both artifact bytes, source/build checkpoint and dependency pins are unchanged by these desktop repairs. The next exact-head hosted campaign remains the final gate, recorded in the PR ledger without a result-only source edit.

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

## ABI repair source checkpoint and fifth transition

Retained repaired native source is `acce570e667c7e2cc3ef83ab451e7dff262006a9`, with 84 actual production inputs. The new pressure admission step is `native/src/world_pressure.inc`, from LF SHA-256 `9977b8c49bfb523acf2f0abcedfc6cc99e2348c60e2bbbfeb29d1fc53738c1a8` to LF SHA-256 `7b28bf216bf70af7059267cae31117f1f01e88d0e5f276f61d67280ab5c6d2e5`, source commit `acce570e667c7e2cc3ef83ab451e7dff262006a9`, issue 391 / PR 394. The adopted P1 step and all prior retained active steps are preserved; the table now has five transitions over three paths. Before adding this step the guard correctly refused the repaired pressure bytes; the refusal is retained in `build/ready394-abi-admission/pre-entry-refusal.log`. Checker rules, frozen lock and identity inputs remain unchanged.

Independent source/focused-native review gave GO for the bounded relay: all 78 recorded compilation/test inputs authenticate, all final commands exit 0, and the compiled World object has no exception_ptr/current_exception/rethrow_exception references. This remains separate from full SDK ABI-floor and Ready acceptance. The exact new entry and rebuilt SDKs require their own checks below.

## Rebuilt ABI-compatible SDK preflight

Both final development runtimes are built from retained source `acce570e667c7e2cc3ef83ab451e7dff262006a9`; all **84** production input hashes match before/after. Windows DLL SHA-256 `cb675a4cde4317608bb892437af9b9f2b7cddf6a7289a6a028500efab19aae9d`, 4,920,832 bytes; Linux SO `a09a4a60cb54c8f1ca5c339d5ef8c3e230b53fc931b845690211ca33b5dac588`, 4,333,984 bytes. Pinned dependency/toolchain inputs are unchanged. The unmodified Linux floor gate passes before publication and again on the installed libraries: bundle GLIBC 2.34 (CyberSand 2.32), GLIBCXX 3.4.30, CXXABI 1.3.9. The old CXXABI failure remains retained; no compatibility threshold was raised.

Each actual desktop OS passed import, fleet80, pilot179 and pressure-optimization4152 (all six completion sections), with eight clean processes and no script/error/leak diagnostics. Native/code/library bytes remained fixed; only post-validation provenance acceptance/receipt metadata changed, explicitly recorded by the builder. Summary `build/ready394-runtimes-abi/summary.json` raw SHA-256 `854814f7ecd0182f6729ed77527af40f8ba3a37886be731cad02e9df15d323e9`. These local results supplement full Ready validation rather than replace it.

The repaired-source inactive probe against accepted main `ee92dc45` again matched all 192 observations and all 25,478,922 CYPS bytes (SHA-256 `902dc1c553e6f49d6694c55c875143fd07c164e0d8452e5158beda3e9b7fa519`) plus work and legacy contact outputs. Receipt is `build/ready394-abi-differential/receipt.json`.

Independent review authenticated all five source entries and the entire adopted pressure chain. Fresh Linux-clone execution at `fda6d77d` passed all 118 catalogue tests, compatibility/compiler and compiled native metadata query parity; no World execution is claimed by that query. Receipt `build/ready394-mat/fda6d77d/execution-receipt.json` SHA-256 `41f703a93cf0b68302e229389548e288fdc9e01c8e3f480d4b8c459de7c356b6`. Entry review SHA-256 `73fb58d76e745644e6d003e3574222316c494a224a596aeeb2c5d451c9bb5242`. Scoped MAT/repair GO is recorded; complete hosted Native/sanitizer/desktop/Water/Palette acceptance remains separate.

The [compact preflight manifest](workbench-391/ready-preflight-summary.json) maps retained sources, runtime/ABI checks and bounded comparison results.

## Final hosted ledger boundary

After the final source/runtime/evidence commit, move #394 to Ready and execute the existing full gates. To keep the qualified source immutable, the [PR #394 ledger](https://github.com/techrote/cybersand/pull/394) records final head, actual executed SHA/tree, run/attempt IDs, coverage, failures and outcome after those runs complete. The preflight results in this file do not assert that pending hosted runs have passed. No source edit, acceptance-threshold relaxation, default selection, issue closure or merge is implied by a green advisory or a skipped job.

A repository check before committing the new SDK pointers correctly refused the two old committed LFS identities while the new files were still working-tree changes. Source/provenance checks otherwise matched; the committed-artifact check is repeated after publication. This intermediate result is retained in `build/ready394-final-preflight/repository.log`.
