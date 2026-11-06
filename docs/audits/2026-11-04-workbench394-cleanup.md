---
title: Workbench 394 cleanup qualification
status: Current
document-kind: evidence
scope: Draft PR394 registry shutdown, flyer tuning retention, corrected core-log citation and source-qualified cleanup validation; no flight/contact law change
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../systems/player-control-playground.md, ../operations/material-catalogue-shadow.md, 2026-11-04-workbench394-material-source-transition.md, 2026-11-04-workbench-boundary-and-pacing.md, 2026-11-04-workbench-consolidation.md]
---

# Workbench 394 cleanup — 4 November 2026

The initial cleanup/admission results below remain historical for their named checkpoints. Later owner acceptance authorizes Ready validation; the [current-main final-validation record](2026-11-04-workbench394-ready-validation.md) supersedes the earlier Draft hold and owns the chained pressure admission after #382. The unmerged hold continues.

## Scope and recoverable checkpoints

The owner requested cleanup of Draft [PR #394](https://github.com/techrote/cybersand/pull/394): fix the teardown diagnostic and core-log citation, retain tuning during flyer replacement, and work through MAT admission while preserving flight/contact feel. **Keep the PR Draft and unmerged.** No sleep, controller calibration, material-law change or new physics response is introduced here.

The accepted-main base remains `751edc0b495dc85484ad5509a7c95f863651c76b`. Cleanup starts from reviewed PR head `1f968fa2ab403aa564aa6c816e60bf6c572b27a5`, in isolated branch `codex/workbench-394-cleanup-20261104`. Ordinary merge `972616ef3d5fc1d476a3fcc5c0ea13fb7057dcf9` imports the independently reviewed #396 admission mechanism at `4aeac7071d1446e33bce7ccda0eafaeae7077847`. Transition entries and their initial audit are committed at `d008b292e51754a4a3e4995aaaddfe08a7987d99`; runtime/test cleanup is frozen at **`a393a797ad7c535fdf177143e660838726ad9ba2`**. Subsequent documentation/results commits do not change production inputs.

The Windows working directory is `C:/Users/_/.codex/worktrees/workbench-394-cleanup/khybersand`. The original workbench-retry checkout and its frozen review packages remain intact. Raw cleanup evidence is local under `build/cleanup394-*`; [compact process results](workbench-391/cleanup-results.json) and reproduction inputs are retained with this record. Evidence is scoped to Windows 11 and WSL Ubuntu 24.04, pinned Godot `4.7.stable.official.5b4e0cb0f`, Rapier addon 0.35.2/core 0.35.1, and the existing materialized native runtimes built from `1ca90de5181953f9ebd95ef19c920d8dee7e17e2`.

## Teardown lifetime

The unchanged fleet fixture at `1f968fa2` printed **70 checks / 0 failures and exit 0**, followed by four leaked ObjectDB instances and three script-resource warnings/errors. A normal Godot regression treats `ERROR:` as failure regardless of the assertion marker. The diagnostic first appeared after an actual Rapier bridge step; construction, control and sampling alone exited cleanly. The retained scripts were the Fleet façade and its Authoring/Catalog dependencies.

The fix removes script-owned static cache variables. A stateless Fleet façade stores the same validated, bounded authored values in one namespaced, versioned dictionary on the **current main loop**. This shares accepted definitions while sessions are alive and releases them before global script shutdown. The cache contains no live scene/script/resource/callable/physics ownership. Getters and registry snapshots return copies. The three workbench display-name consumers use the copied getter. Registry contents, authored profiles and controller calculations are unchanged.

The extended real-Rapier fixture adds ten checks for copied getters/snapshots, accepted and refused reloads, exact restoration, value-only cache contents and continuity after stepped session retirement. Fresh worker verification passed **80/80 on Windows and Linux**, exit 0 without error, ObjectDB or resource diagnostics. Worker receipt: `build/cleanup394-teardown/mainloop-receipts.json`. Final worker log SHA-256s are Windows `6fe52b427c28de452430afac2b99140048b1316dba9a650ae1e199ad5331353d` and Linux `009be181308f060734aab8e1d9231c991ac50c1bb3b9bca4dfec02c9c87486a1`.

Rejected attempts remain under `build/cleanup394-teardown`: `@static_unload` caused Windows access violation `0xC0000005` after the original assertions; Engine-singleton metadata passed the original fixture but crashed after extended reload/restore at Windows shutdown; stripping typed containers did not repair it. A first metadata key containing `/` was refused as an invalid identifier and corrected. These attempts are not qualification passes. Main-loop ownership passed repeated Windows teardown and the Linux fixture. Independent review confirmed the final source, UTF-8 labels and both final log hashes.

## Tuning continuity

Replacing a selected flyer with a model not already present now deep-copies its **six applied options**: budget, mass, inertia, thrust, torque and Shift multiplier. It retains the saved spawn and the existing replacement transaction, new instance identity, neutral input retirement and live-material transfer. Selecting an existing flyer keeps that instance's own tuning. Independent placement and the explicit **Defaults** action still use model defaults. Existing setup validation and RFT budget restrictions remain active.

The test-first actual-host run at the original behavior executed 179 assertions with 36 failures, all identifying missing-model replacement/reselection resetting actual, saved and UI tuning. Independently placed Needle and explicit Defaults controls passed. With the fix, Windows and Linux each passed **179/179**, covering budget 40, mass 1.5, inertia 1.75, thrust 1.6, torque 1.3 and boost 2.75 through Scooper → missing Kestrel, then reselection and actual controller/Rapier readback. Receipts are `build/cleanup394-tuning/{baseline-windows,candidate-windows,candidate-linux}`. Initial evidence-helper checks also reported disposable copied-project `.import` changes; those generated-cache observations are retained separately and are not production source drift.

## Corrected log citation

The [boundary/pacing audit](2026-11-04-workbench-boundary-and-pacing.md#qualification) originally printed SHA-256 `f7c8e941a5715c36310973c63f7699e3476ce7174716ec409a484704e4e49d7f` without an exact filename. Recursive verification located **`build/wb/edge-native/core-checked.log`** in the original workbench-retry checkout: its raw bytes match that digest and report 165/165. The original hash is valid; the correction supplies the missing path. The first cleanup lookup examined only the top-level logs and missed this nested file; no log was altered. A different retained top-level `build/wb/core-checked.log` has digest `3d9d996785eee53b00b903f52c659b3ac50e3b107e1f8894ba71ccd34d42b94d` and is not substituted for the originally cited file. The boundary audit also now distinguishes the historical fleet assertions from its teardown diagnostic failure.

The fresh sanitized core log is `build/cleanup394-native/run-core-asan-ubsan.log`, raw-byte SHA-256 `7348fff54dbcac0003e4ebfab79d8a0860a1ffd820ed23a735cb39f9cbe7f605`. The fresh 165/165 normal core run is `build/cleanup394-native/run-core-normal.log`, raw-byte SHA-256 `688bf7106ad3990a03bed8ad78b3cf37bb3b6e1d4843a0a7ea9f108cf64b621a`, exit 0 in 127.632 seconds with a 900-second bound. Earlier commands and failed logs are preserved rather than rewritten to manufacture the old citation.

## Integrated qualification

Native production, controller and all eight flyer JSON inputs are unchanged from the reviewed PR head. Runtime provenance is verified against all 83 production inputs and the selected DLL/SO bytes; a new SDK build is unnecessary when those inputs match. The scoped [MAT transition record](2026-11-04-workbench394-material-source-transition.md) owns the three protected hashes, unchanged 24 other consumers, twelve identity inputs, catalogue/capability digests and admission verdict.

The same [inactive material probe](workbench-391/material_source_probe.cpp) is compiled against accepted main and the candidate's separate native headers/objects. Four arms (Water FreeMass/PressureFlow reference × one/six workers), 48 ticks each, compare full CYPS bytes plus physical hashes, visited/active work and legacy contact counts/impulses. It includes Sand, Dust, Rust, Coal, Water, Oil, Brine, Mercury, signed boundaries, moving/retired masks and floor removal. All **192 observations** match: **25,478,922 identical CYPS bytes**, SHA-256 `902dc1c553e6f49d6694c55c875143fd07c164e0d8452e5158beda3e9b7fa519`; stdout SHA-256 `8a2e89744abfd937ebdc31e182a8597c55baa73dbe8a8d58f97654b6882cb01d`. This is bounded inactive-feature equivalence, not proof for every map or chemistry. IN and nonambient thermal behavior are separately covered by existing core controls.

| Gate | Result |
|---|---|
| Normal native core, including quantity/inheritance/boundary/IN and pressure-capacity controls | 165/165 PASS; pressure capacity 52/52 |
| Full core ASan/UBSan | 165/165 PASS, exit 0 in 680.042 s / 900 s; leak detection and halt-on-error enabled, no sanitizer diagnostics |
| Native arrivals, normal and ASan/UBSan | 196/196 PASS each |
| Pressure-head serial/parallel and one/six-worker parity, normal and ASan/UBSan | 827,303/827,303 PASS each |
| MAT compatibility, compiler, catalogue suite and compiled pure-query parity | PASS; 118 catalogue tests; scope in separate admission record |
| Integrated Windows/Linux workbench hosts at a393a797 | PASS: all twelve fixtures and imports on each platform; fleet 80, pilot 179 and physics 72 assertions; exit 0 without script/error/leak diagnostics |
| Documentation, materialized repository identity, M11 and whitespace | PASS at the cleanup inputs; final-head repeat recorded separately |
| Retrieval canonical hits in top five | Frozen 32/32, PLAY 12/12 (including the new tuning question), challenge 156/157; existing LCB03 miss retained |

Native builds use GCC 13.3, `-std=c++20 -O1 -g1 -pthread -Inative/include`; sanitizer builds add `-fno-omit-frame-pointer -fsanitize=address,undefined`, with `ASAN_OPTIONS=detect_leaks=1:halt_on_error=1` and `UBSAN_OPTIONS=halt_on_error=1` for the core. The four simulation sources and core test-source list are those in Makefile. Compiles/link/core have 900-second bounds; scoped controls have 180-second bounds. Exact argv, elapsed time and raw-log hashes are in `build/cleanup394-native/{core,scoped,san-scoped,differential}-receipt.json`. An initial attempt to invoke Make on this WSL installation failed because Make is absent; direct GCC builds replaced that attempt, whose logs remain.

The integrated host runner copies committed Godot inputs into separate Windows/Linux projects, imports each with the pinned engine, then runs fleet, pilot UI, desktop interest, physics play, hard placement, input, live liquid edit, retained pressure, failed-owner recovery, liquid edges, boundary retention and canvas. Each has a 180-second bound and `--headless --audio-driver Dummy --max-fps 120 --script res://tests/test_workbench_<name>.gd`. Receipts bind source and input hashes before/after; no generated caches are copied back. This checks actual Rapier/native ownership and preserves barrel/Scooper controls. It does not replace subjective gameplay acceptance, hardware/gamepad qualification, Web testing or full hosted release matrices.

## Handoff

**Independent scoped verdict: GO for the cleanup runtime at `a393a797` and the three exact MAT consumer transitions.** The reviewer independently authenticated source/lock/identity hashes, 118 catalogue tests and native query parity, the inactive differential, normal/sanitized native controls, all 26 host processes and the corrected historical citation. This is technical compatibility/runtime admission on the Draft branch; it is not owner production adoption or merge authorization.

Technical source admission and gameplay/production adoption are separate. No new owner gameplay verdict is inferred from these automated runs. Preserve earlier leakage, carry, performance and platform limitations. PR #394 remains **Draft and unmerged**, and the source commits admitted by MAT must be retained through an eventual ordinary merge, not removed by squash/rebase.

The new Windows package is `build/workbench-owner-review-a393a797`, with source `a393a797ad7c535fdf177143e660838726ad9ba2`. Its own bundled engine passed import, fleet 80/80 and pilot UI 179/179 with clean teardown. The stable launcher at `C:/Users/_/.codex/worktrees/workbench-retry/khybersand/build/Open Workbench.cmd` now delegates to this new package; earlier frozen packages and running processes remain untouched. Package and launcher identities are in `build/cleanup394-package/launcher-receipt.json`; `review-manifest.json` records exact source/tree, engine and all materialized LFS hashes. Restart to load the cleanup; no live process is upgraded in place.

The first documentation/repository run lacked five companion files (six expected-fact references) in the new worktree parent. Unchanged copies from the existing workbench-retry companion layout restored that premise; the subsequent checks pass. The first retrieval invocation also lacked its output directory and was rerun after creating it. No source identity or checker rule was weakened to pass these checks.

## Owner acceptance and final-validation intake

After testing package source `a393a797`, the owner reported: "Flyer switching and tuning seem to work properly now." Following the proposed final-validation sequence and a fresh launch link, the owner then said: "Yeah it's brilliant go ahead." This records owner acceptance of the playable workbench and authorization to proceed to Ready/final qualification. The earlier unmerged hold remains in force; no merge is authorized here. It does not invent a detailed human execution receipt for individual save/load steps.

The Kestrel Q/E preference and a saved per-flyer binding/options system are a follow-up; no control law or binding changes are included in this validation intake.

Fresh reconciliation found accepted main advanced from `751edc0b` to `ee92dc45b12455f01218394fd773da516caf356e`, containing #396 and #382's pressure wake-summary optimization. #394 is temporarily non-mergeable. Preserve both accepted-main behavior and the reviewed workbench, reconcile source/admission and rebuild both desktop runtimes before final hosted execution. The earlier `f44488e9` qualification remains historical for its exact native source; it is not qualification of the combined candidate.
