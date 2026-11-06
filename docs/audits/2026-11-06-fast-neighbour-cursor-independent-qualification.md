# CyberSand — fast in-chunk neighbour cursor independent qualification

**Date:** 2026-11-06  
**Decision:** REVISE — provisional until paired native work and independent acceptance finish.  
**Scope:** `techrote/cybersand` PR [#471](https://github.com/techrote/cybersand/pull/471); isolated follow-up Draft [#477](https://github.com/techrote/cybersand/pull/477); no merge or production publication.

## Source identity and isolation

- Original reference PR #406 `claude/water-ballistic-hybrid`: `4a80af2a891332176a3912a235582d77d076a185`.
- Candidate #471 at inspected head: `0df569bfd5e82853c9025762061ed4e8debd5be1`.
- Separate follow-up branch: `codex/neighbour-cursor-independent-qualification-20261106`, based on candidate; measurement source HEAD as at 22:15 UTC `7abee56161c809bf46a4cabbff41b51a7bba350c`.
- Auxiliary benchmark-only branch: `codex/neighbour-cursor-timing-only-20261106` — this changes only benchmark driver order and output-directory creation, **not native engine bytes**; its run compares pinned reference and pinned candidate exactly.
- Protected `native/src/world.cpp` LF SHA-256 independently computed from fetched source: original `5a9de5e09a8665392677902ab501696aafefb5bbd2d2800e3dc1059b87a6f17d`, candidate `bbd9741311bc67905934048633846b8d011efd760033edd0ff9e88be5b262868`.
- No source-lock refresh, no `REVIEWED_TRANSITIONS` entry, no edits to #406 or #471, no merge.

## Work completed

- A fail-closed, source-derived GDScript stress-canvas verifier reads the 119 authored box stamps, resolves overlaps and material identities, merges raster runs, and compares **all 129 rectangle tuples and every cell** of the 2048×1024 raster to the benchmark fixture. Result: PASS; zero differing tuples and cells.
- Fixture raster SHA-256: `3ef9392f52778eaa8fdc06ee6c23aabbb9f0a54d4f134ba647dca238a573718e`; `workbench_setup.gd` source LF SHA-256: `8c5bf3641e1791b1fa13ce262ee96701cefb9eacc357219080099c60bd19a013`.
- Compiled both reference and candidate with GCC 13.3.0, identical `-std=c++20 -O2 -g -fno-omit-frame-pointer -pthread` flags and Makefile's four translation units. Both builds PASS as shown in [timing-only CI run #42302869232](https://github.com/techrote/cybersand/actions/runs/42302869232).
- Replaced misleading single-checkout worker-count comparison with detached, SHA-pinned baseline/candidate worktrees, 6 interleaved balanced cycles of 600 ticks (24 runs), 4 additional 1800-tick trials, per-tick timings, 1/6 worker occupancy, activity, allocations, `state_hash`, `physical_state_hash`, work-statistics equality, Student-t paired intervals, guarded source cursor oracle and optional `perf` function/line data.
- On the isolated timing branch, corrected output directory creation and balanced three baseline-first/three candidate-first orderings per worker count; a new exact-source timing-only CI run was started.

## Actually executed vs unqualified

- Static source review of `KernelReadCursor`, `World::update_cell`, `update_rule_kernel`, reaction wake: no obvious new material read or phase-ownership semantic change; **not a substitute for runtime exactness**. Body mask remains consulted per read; in-chunk cell data remains live; cross-chunk falls back to `stored_material`; source chunk points to stable `unique_ptr`-owned chunk payloads.
- Static and hosted fixture: PASS.
- GCC baseline & candidate profiling build: PASS.
- First hosted combined qualification [run #42301283868](https://github.com/techrote/cybersand/actions/runs/42301283868): fixture PASS, metadata JSON serialization setup FAILED, repaired. No native simulation executed in that attempt.
- First timing-only [run #42302869232](https://github.com/techrote/cybersand/actions/runs/42302869232): both native build PASS, benchmark CSV output directory missing; repaired. No simulation ticks in that attempt.
- Corrected balanced timing-only run: [#42303273494](https://github.com/techrote/cybersand/actions/runs/42303273494). **PENDING** at time report first authored; update this before admitting.
- Full native / ASan / UBSan / focused TSan / deterministic worker parity: isolated qualification [#42301379645](https://github.com/techrote/cybersand/actions/runs/42301379645). **PENDING** at time report first authored; update this before admitting.
- Original PR #471 documentation provenance: FAIL due missing `world.cpp` protected reviewed transition; deliberately not bypassed.
- Exact-head Godot/native PR checks: skipped while Draft; these are not passes.

## Benchmark methodology

Host first timing-only run: GitHub-hosted Ubuntu 24.04, Linux kernel 7.0.0-1017-azure, AMD EPYC 9V74, **four logical CPUs**, GCC 13.3.0. Six configured simulation workers exceed available logical CPUs. `worker_threads_observed` records task claimants, not simultaneous execution. Tests must distinguish this oversubscription from benefit or regression on the owner's workstation.

For performance builds compile `native/src/world.cpp`, `native/src/material_rules.cpp`, `native/src/scheduler_geometry.cpp`, `native/src/settled_world_discovery.cpp`, and the exact same neutral benchmark C++ from the experimental branch for both source pins. No benchmark changes are applied to the reference's tracked checkout. Use WorldConfig defaults except worker count 1/6 and capacities 512/512/4096. All 129 fixture rectangles remain material-exact. The Godot scene has eight passive Rapier barrels that are outside the native cellular-only benchmark.

## Measurement results

Pending completion and extraction from run #42303273494. **Do not report speedup or exact hashes without raw execution evidence.** Retain all raw CSV/JSON, CI logs and `perf` reports, including explicit `perf_event` permission or availability failures.

## Required follow-up and admission gate

1. Decode all artifacts; classify full native/sanitizer/TSan results, including environmental failures. Compile and execute full native tests with `CYBERSAND_VERIFY_LOCAL_NEIGHBOUR` where practicable, concentrating on signed seams, nonpower-two chunks, transient masks, reaction wake, and changing material values in a rule. Non-power-two chunk size 192 is valid for six-worker phased geometry (aligned to 64-core), unlike 48.
2. Check 1, 6, reference and candidate at ticks 150/300/450/600 and 1800; preserve exact state, physical and deterministic work parity for all versions. If mismatch or failure is observed, isolate source vs harness vs baseline before alteration.
3. Review `perf` function/line profiles where permitted; if hosted `perf` is blocked, obtain a supplementary host with permissions and do not represent missing profiles as pass.
4. Decide performance based on six paired repeats and confidence intervals, not an assumed 5–10%. If neutral or slower, REJECT the optimisation instead of requesting source admission.
5. Only after affirmative technical decision and independent review, prepare the reviewed protected-source transition with commit ancestry, then qualify exact head with documentation/provenance, Native and Godot CI. Leave #471 and #477 Draft in the meantime.

**No merge. No production runtime publication.**