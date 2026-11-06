# CyberSand — fast in-chunk neighbour cursor independent qualification

**Date:** 2026-11-06  
**Decision:** REVISE — completed native/paired evidence; gain is modest and six-worker benefit unproven; no protected-source admission.  
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

## Post-run qualification readback — 2026-11-06, hosted runs completed

**Decision: REVISE.** Neither an exactness failure nor a justified 5–10% total-tick gain is established. Keep experimental #471 and follow-up #477 Draft; do not submit `world.cpp` for material-source admission or merge.

### Original executable evidence

- [Native/sanitizer/TSan run #42301379645](https://github.com/techrote/cybersand/actions/runs/42301379645), pinned candidate `7abee56161c809bf46a4cabbff41b51a7bba350c`, reference `4a80af2a891332176a3912a235582d77d076a185`, GCC 13.3.0, Ubuntu 24.04 / Linux Azure four-logical-CPU Intel Xeon Platinum 8370C. **Full original native suite PASS 188; full candidate native suite PASS 188; candidate full ASan/UBSan suite PASS 188.** All seven focused candidate TSan selections exited 0, including complete-material worker parity, determinism, phased scheduling, explosion parity, parallel PressureFlow heads, Water IN workers, and ballistic-water persistence.
- This job's final status **FAIL** occurred *after* those passes. It used an older copy of the paired driver and tried to create the first CSV inside a nonexistent `raw/` directory (`neighbour_cursor_bench: could not open csv`). It is an apparatus failure, not a failed engine test; the missing-output-directory fix is present on #477.
- [Paired timing run #42303273494](https://github.com/techrote/cybersand/actions/runs/42303273494): **PASS**, with six balanced baseline/candidate cycles (24 complete 600-tick runs), four 1,800-tick extended runs, and two `CYBERSAND_VERIFY_LOCAL_NEIGHBOUR` 600-tick guarded runs. Its benchmark engine source was pinned to the same `7abee561...` candidate and `4a80af2a...` baseline; the timing-only driver correction changes no engine bytes. Runtime: GCC 13.3.0 on GitHub-hosted four-logical-CPU AMD EPYC 7763 (six configured workers are oversubscribed).

### Measured total `World::tick` times, not gameplay FPS

| Workers | Baseline mean (ms/tick) | Cursor mean (ms/tick) | Six-cycle mean paired improvement | Paired improvement 95% Student-t CI | Inference |
|---|---:|---:|---:|---|---|
| 1 | 85.691 | 82.105 | +4.138% | +1.507% to +6.770% | Positive on this host; below 5–10% mean target |
| 6 | 38.045 | 37.185 | +2.243% | -0.295% to +4.781% | Not statistically established; oversubscribed host |

The one-worker paired speedups were `8.490, 4.624, 3.789, 0.756, 3.382, 3.790%`. Six-worker paired speedups were `2.851, 4.065, -2.533, 2.462, 3.770, 2.844%`. The six-worker confidence interval includes zero. A 5–10% total-tick gain **must not** be claimed from these data.

Across all 24 short trials, baseline/candidate and 1/6-worker checkpoints matched `state_hash` and `physical_state_hash` at ticks 150, 300, 450 and 600; each per-tick deterministic work-counter record also matched. Final tick-600 hashes: `d2c019a2752b7657` / `f9631ca2bece4d99`. Totals in every short trial: 249,475,527 visited, 74,373,999 moved, 211,869 scheduled cores. Configured six workers achieved a maximum of six observed task claimants, **not proof of simultaneous physical CPU execution**.

All four extended 1,800-tick runs matched exact checkpoint hashes and deterministic work counts, ending with `state_hash=76d8f5318940614e`, `physical_state_hash=e1594d5f50a82bae`, 765,562,578 visited, 184,079,327 moved and 823,626 scheduled cores. Scheduled cores rose from about 292.35 mean early to about 598.78 mean in the final 180 ticks; final 619 cores and 2,202 active blocks. The guarded cursor-oracle runs for 1/6 worker completed without a mismatch.

**Profiling limitation:** Linux `perf record` returned exit 255 on both baseline and candidate: `perf_event_paranoid=4`, insufficient `CAP_PERFMON` / relevant privileges on hosted runner. No function/line attribution is available. No privilege escalation or safety bypass was attempted.

**Artifact custody (14-day GitHub Actions retention):**
- [Raw six-cycle and 1,800-tick CSV/JSON, per-run logs and failed perf captures](https://github.com/techrote/cybersand/actions/runs/42303273494/artifacts/13545494749) — artifact 13545494749.
- [Native reference/candidate full-suite logs, candidate ASan/UBSan and seven TSan filtered logs](https://github.com/techrote/cybersand/actions/runs/42301379645/artifacts/13546303495) — artifact 13546303495.

### Remaining admission requirements

1. Preserve raw evidence outside the hosted artifact-retention interval; the archive is not a production runtime and must not be committed to tracked source.
2. Obtain a narrowly scoped 6-core/12-logical-CPU profile with permitted Linux `perf` sampling and repeat the paired measurements without concurrent heavy machine work; distinguish in-chunk read savings from scheduling and other kernels. Reassess the 5–10% target **only** from the measured host-specific distribution.
3. Add independent focused regressions for negative coordinate seams, 128-chunk corners, transient mask mutation, missing chunks, rule write-followed-by-read, reaction wake, epoch wrap, and permitted non-power-of-two chunk geometry (e.g. 192 at six-worker aligned phase geometry); run candidate ASan/UBSan and relevant TSan again at exact source head.
4. Have a separate reviewer inspect source correctness and resulting evidence. If six-worker improvement remains below a worthwhile practical threshold, **REJECT the optimization** rather than adding broader 3×3 caches or preparing protected source admission. Only if it demonstrates worthwhile benefit with independent acceptance should source transition ancestry, exact-head provenance, Native/Godot gates, and owner acceptance proceed.

## Activity-window reanalysis of the archived 600/1800-tick runs

**Independent post-run analysis, 6 November 2026.** Recomputed from the complete per-tick
CSV streams in [artifact #13545494749](https://github.com/techrote/cybersand/actions/runs/42303273494/artifacts/13545494749)
(no fresh simulation). For each 600-tick time window, calculate the mean of
the six within-cycle paired speedups, where improvement is
`100 * (baseline_mean_ms - candidate_mean_ms) / baseline_mean_ms`.
These are descriptive window estimates, *not* independent windows or additional
replicates for statistical inference.

| 600-tick window | Mean baseline 1-worker | Mean cursor 1-worker | Paired gain, 1 worker | Mean baseline 6-worker | Mean cursor 6-worker | Paired gain, 6 workers | Mean scheduled cores |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1–180 | 76.180 ms | 74.438 ms | +2.21% | 34.393 ms | 33.921 ms | +1.35% | 292.35 |
| 181–360 | 87.634 ms | 83.904 ms | +4.22% | 38.957 ms | 37.925 ms | +2.62% | 353.50 |
| 361–600 | 91.367 ms | 86.505 ms | +5.27% | 40.100 ms | 39.079 ms | +2.53% | 398.40 |
| 421–600 | 91.588 ms | 86.641 ms | +5.35% | 40.154 ms | 39.136 ms | +2.52% | 402.19 |

The stronger later one-worker benefit supports the hypothesis that the read
optimization is more useful under a larger active-core workload. The six-worker
increase is weaker and variable on a four-logical-processor hosted machine.
The scheduled-core counts are *exactly the same* in each comparison; changed
work is not the cause of the measured timing differences. This is consistent
with read-path cost reduction but does not prove a causal microarchitectural
mechanism without function/line profiling.

The **single** baseline/candidate 1,800-tick extension for each worker setting
(additional descriptive information, `n=1`, not an inference) was:

| 1,800-tick window | 1-worker baseline → candidate | Gain | 6-worker baseline → candidate | Gain | Mean scheduled cores |
|---|---:|---:|---:|---:|---:|
| 1–180 | 76.360 → 74.542 ms | +2.38% | 34.852 → 34.137 ms | +2.05% | 292.35 |
| 721–900 | 94.621 → 90.437 ms | +4.42% | 42.766 → 40.320 ms | +5.72% | 441.20 |
| 1621–1800 | 103.024 → 98.445 ms | +4.44% | 45.505 → 43.534 ms | +4.33% | 598.80 |
| 1–1800 | 93.976 → 90.087 ms | +4.14% | 42.161 → 40.302 ms | +4.41% | 457.60 |

A repeatable sustained 6-worker gain is still *not proven*, particularly on a
machine with only four logical CPUs. If further perf effort is justified, prioritise
steady-state/late-activity measurements on a true 6-core/12-logical-CPU host and
keep the 600-tick early-growth and 1,800-tick results separately labeled.

### Independent edge-case and non-perf profiling follow-up

[Focused source-pinned CI #42312672077](https://github.com/techrote/cybersand/actions/runs/42312672077)
compares all 520 ticks for the original and cursor under 1/6 workers in
signed 128/192-cell chunk-seam, dynamic transient-mask/re-entry, non-resident/new
chunk, and epoch-wrap cases; candidate sanitizers and guarded local oracle are
included. [Callgrind CI #42313028634](https://github.com/techrote/cybersand/actions/runs/42313028634)
uses identical 16 early stress-canvas ticks with the Valgrind instruction event
to provide supplemental function/source-line attribution without elevated
`perf_event` privileges. Neither makes a six-core speedup claim. Results require
their own exact-head evidence readback; at the time of this report, both are
running.

## Required follow-up and admission gate

1. Decode all artifacts; classify full native/sanitizer/TSan results, including environmental failures. Compile and execute full native tests with `CYBERSAND_VERIFY_LOCAL_NEIGHBOUR` where practicable, concentrating on signed seams, nonpower-two chunks, transient masks, reaction wake, and changing material values in a rule. Non-power-two chunk size 192 is valid for six-worker phased geometry (aligned to 64-core), unlike 48.
2. Check 1, 6, reference and candidate at ticks 150/300/450/600 and 1800; preserve exact state, physical and deterministic work parity for all versions. If mismatch or failure is observed, isolate source vs harness vs baseline before alteration.
3. Review `perf` function/line profiles where permitted; if hosted `perf` is blocked, obtain a supplementary host with permissions and do not represent missing profiles as pass.
4. Decide performance based on six paired repeats and confidence intervals, not an assumed 5–10%. If neutral or slower, REJECT the optimisation instead of requesting source admission.
5. Only after affirmative technical decision and independent review, prepare the reviewed protected-source transition with commit ancestry, then qualify exact head with documentation/provenance, Native and Godot CI. Leave #471 and #477 Draft in the meantime.

**No merge. No production runtime publication.**