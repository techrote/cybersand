# CyberSand — fast in-chunk neighbour cursor independent qualification

**Date:** 2026-11-06  
**Decision (7 November 2026): ACCEPT FOR FURTHER ADMISSION — independent #485 source review ACCEPT; code-pinned LF-verified transition prepared on Draft #477. Exactness PASS, modest but statistically positive multiworker gain +2.677% on the tested 4-logical-CPU host; not a 5–10% claim or a production/merge approval. Deployment 6-core/12-thread performance and actual Godot/Rapier FPS remain untested.**  
**Scope:** `techrote/cybersand` PR [#471](https://github.com/techrote/cybersand/pull/471); isolated follow-up Draft [#477](https://github.com/techrote/cybersand/pull/477); no merge or production publication.

## Final transition-preparation status — 7 November 2026

**Accepted for further admission only, not merge or production publication.**
After the earlier REVISE qualification snapshots were written, the separate
[issue #485 read-only MAT-AUTH source review](https://github.com/techrote/cybersand/issues/485#issuecomment-6699706678)
returned **ACCEPT** for semantic preservation of the exact protected
`native/src/world.cpp` delta. The original 5–10% performance target was a
working aspiration, not an acceptance assumption; independent repeated
1,800-tick six-worker trials support a **+2.6771%** whole-native-tick effect
(95% paired CI **+2.0865% to +3.2677%**) on a four-logical-CPU hosted runner.
The narrow read-only cursor saves about 1.12 ms per heavy tick there, with
zero state/physical/work discrepancies across the native, sanitizer and
focused signed/non-power-of-two/mask/epoch execution gates.

**Prepared source admission is not historical acceptance.** A dedicated
[2026-11-07 reviewed-transition record](2026-11-07-pf471-reviewed-world-transition.md)
now accompanies the chained, exact Git-ancestry
`REVIEWED_TRANSITIONS` entry prepared on independent Draft #477:
`native/src/world.cpp`
`5a9de5e09a8665392677902ab501696aafefb5bbd2d2800e3dc1059b87a6f17d`
→ `bbd9741311bc67905934048633846b8d011efd760033edd0ff9e88be5b262868`,
`source_commit=b51f01536db6408458442c532d75256d33422fba`,
issue #485, PR #471. The repository's immutable material compatibility
lock and BASELINE are still untouched. Normal documentation/provenance,
Native and Godot exact-head checks remain a separate admission gate.
No merge or runtime publication has been authorized.

**Historical qualification and earlier REVISE notes below remain as dated
intermediate records.** Read the terminal disposition in conjunction with
this section; do not treat earlier "unreviewed source" statements as
current. The exact source-identity audit and all original raw evidence
links are preserved.

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
- Corrected balanced timing-only run: [#42303273494](https://github.com/techrote/cybersand/actions/runs/42303273494). **PASS**, 24×600 ticks, four 1,800-tick extensions and guarded oracle; raw evidence cited below.
- Full native / ASan / UBSan / focused TSan / deterministic worker parity: isolated qualification [#42301379645](https://github.com/techrote/cybersand/actions/runs/42301379645). **188+188+188 native/sanitizer tests PASS and seven focused TSan selections PASS**; overall job red was a benchmark output-directory defect after tests.
- Original PR #471 documentation provenance: FAIL due missing `world.cpp` protected reviewed transition; deliberately not bypassed.
- Exact-head Godot/native PR checks: skipped while Draft; these are not passes.

## Benchmark methodology

Host first timing-only run: GitHub-hosted Ubuntu 24.04, Linux kernel 7.0.0-1017-azure, AMD EPYC 9V74, **four logical CPUs**, GCC 13.3.0. Six configured simulation workers exceed available logical CPUs. `worker_threads_observed` records task claimants, not simultaneous execution. Tests must distinguish this oversubscription from benefit or regression on the owner's workstation.

For performance builds compile `native/src/world.cpp`, `native/src/material_rules.cpp`, `native/src/scheduler_geometry.cpp`, `native/src/settled_world_discovery.cpp`, and the exact same neutral benchmark C++ from the experimental branch for both source pins. No benchmark changes are applied to the reference's tracked checkout. Use WorldConfig defaults except worker count 1/6 and capacities 512/512/4096. All 129 fixture rectangles remain material-exact. The Godot scene has eight passive Rapier barrels that are outside the native cellular-only benchmark.

## Measurement results

The paired 600/1,800-tick measurements and full hashes are in the **Post-run qualification readback** below; the six-pair extended 1,800-tick campaign and final confidence intervals are in the concluding readback. All reported timings derive from raw host execution, not synthetic estimates.

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

## Completed independent focused edge-case qualification (23:38 UTC)

**PASS** — exact-head [hosted run 42312672077](https://github.com/techrote/cybersand/actions/runs/42312672077),
[source-pinned input and 66 original log/JSON files](https://github.com/techrote/cybersand/actions/runs/42312672077/artifacts/13548524780).
Source reference `4a80af2a891332176a3912a235582d77d076a185`,
cursor `0ddfacd143d53191b2d16947f64aeebfe3e819c2`, both protected
`native/src/world.cpp` LF hashes match those established above. GCC 13.3.0,
`-O2 -g -fno-omit-frame-pointer` on Linux/GitHub-hosted 4-logical-CPU machine.

The **identical source-neutral fixture** `native/bench/neighbour_cursor_focused.cpp`
was linked separately against the original and cursor simulation translation units,
with `CYBERSAND_VERIFY_LOCAL_NEIGHBOUR` enabled for the cursor. It covers:
- Signed 128-cell seams, corners, absent and newly prepared chunks (`seams128`);
- Signed non-power-of-two **192-cell** chunks under valid 64-core/32-block geometry
  (`seams192`);
- Transient body-mask installation, removal and reacquisition, with interacting
  neighbours and scheduled wakes (`masked128`);
- Full 192-cell preprepared region, changing reactive materials and epoch wrap
  beyond ticks 255/256/512 (`epochs192`).

| Qualification | Execution | Result |
|---|---|---|
| Baseline vs candidate with 1 and 6 workers | 4 scenes × 2 engines × 2 worker settings × 520 ticks = 16 complete runs | **PASS**, zero state/physical/content checkpoint and per-tick deterministic-work discrepancies |
| Candidate ASan/UBSan, guarded local oracle | 4 scenes × 2 worker settings × 520 ticks = 8 complete runs | **PASS**, outputs match unsanitized candidate exactly |
| Candidate TSan, guarded local oracle | 192 signed-seam and 128 dynamic-mask scenes × 6 workers × 520 ticks = 2 complete runs | **PASS**, outputs match unsanitized candidate exactly |
| Machine, fixture and source identification | Exact Git SHAs, LF SHA-256, compiler and execution flags in raw evidence | **PASS** |

Checkpoint ticks include 1, 2, 16, 31–33, 63–65, 127–129, 150, 255–257,
300, 383–385, 450 and 511–513/520. These 16 source- and worker-paired
replays are new independent correctness evidence, **not** additional
statistical repetitions for speedup inference.

**Remaining:** independent source/acceptance review, permitted function/line
profile, six-core/12-logical-CPU late-activity repeated speedup measurement,
protected-source admission only after a positive benefit decision, and
source-matched Godot/Native exact-head acceptance. The status remains
**REVISE** rather than ACCEPT/merge.

## Completed owner-side full native + guarded oracle gate

**PASS:** PR #471's independent, newly added exact-head
[workflow #42313096990](https://github.com/techrote/cybersand/actions/runs/42313096990),
job `native-and-verify-oracle` (ID `128219159891`), compiled and executed
the original full native suite and then the full suite built with
`-DCYBERSAND_VERIFY_LOCAL_NEIGHBOUR` using GCC 13.3.0. The original logs show
**188 tests passed** both times on candidate `cd26abd96bb4d620f123e3fbb199354b8ee2c482`.
That commit adds no new `native/src/world.cpp` bytes relative to the cursor
checkpoint originally measured; see the independent source-diff readback.
[Native and oracle original evidence artifact](https://github.com/techrote/cybersand/actions/runs/42313096990/artifacts/13550106854).
The owner-side full ASan/UBSan sanitizer family (job `128219159816`) also
**PASSED** at candidate `cd26abd96bb4d620f123e3fbb199354b8ee2c482`, with
`188 tests passed`, GCC 13.3.0, compiler `-O1 -g -fno-omit-frame-pointer`
and `-fsanitize=address,undefined`. Its build and execution completed with
exit 0, including `RENDER_COPY_QUALIFICATION` 153,284 assertions/0 failures
and pressure capacity 52 assertions/0 failures. Source-owner TSan and ABBA
benchmark are separate pending evidence gates, not included in this ASan result.

## Original source-pinned Callgrind read-path attribution

A fully executed preliminary [Callgrind source-pinned run #42313028634](https://github.com/techrote/cybersand/actions/runs/42313028634)
sampled **exactly 16 `World::tick` calls, one worker**, excluding scene
construction and post-run state hash, with the same 129 rectangles and source
compiler flags. Its Python summary command failed with `ZeroDivisionError`
because it mistakenly read the `summary: 0` header from outside the active
instrumentation interval. The original raw profile files **are complete and
independently inspected**, with actual `totals: Ir` (instruction counts).
The parser was corrected on #477 and the independent exact-head
[rerun #42314416637](https://github.com/techrote/cybersand/actions/runs/42314416637)
**PASSED** at commit `f3046d6fc8c7694bfd9060bc554371bd1d995724`,
reporting the same `Ir` totals, hashes and deterministic counters; original
[qualified artifact #13549687979](https://github.com/techrote/cybersand/actions/runs/42314416637/artifacts/13549687979)
contains `summary.json`, both `.callgrind` raw files, function/line
annotations, commands and source revisions. This is the completed diagnostic
profile gate, not an elapsed-CPU `perf` pass.

| Callgrind property | Baseline #406 | Cursor #471 | Delta |
|---|---:|---:|---:|
| Complete 16-tick instruction count (`totals: Ir`) | 14,690,762,574 | 13,828,652,071 | **−862,110,503 (−5.87%)** |
| `World::update_rule_kernel` inclusive instructions (same 6,460,155 calls) | 10,739,791,027 | 10,117,308,862 | −622,482,165 |
| `World::schedule_pending_reaction_wake` inclusive instructions (same 2,401,754 calls) | 1,577,798,188 | 1,245,325,926 | −332,472,262 |
| `World::address` attributed instruction count at its declaration | 185,922,904 | 128,426,822 | −57,496,082 |
| `World::find_chunk` attributed instruction count at its declaration | 650,434,939 | 449,198,652 | −201,236,287 |

All figures are copied from the archived `callgrind_annotate` original
raw text and active instrumentation `totals: Ir`, not from compiler estimates.
The inclusive function results overlap; **do not add rows together** or infer
a corresponding elapsed-time/CPU speedup from instruction counts alone.
Source callsite annotation also shows the hot
`address`/`find_chunk` pathway's 38,937,445 attributed original calls
falling to alternative paths in the cursor build; the call graph has changed
and these attribution lines are not direct estimates of API-wide calls.
Early-tick lower instruction count is mechanistically consistent with the
changed read path; 6-worker/late-activity CPU profiles are **still missing**.

Source exactness of the 16-tick profile is proven separately:
`state_hash 777d7c77a080375c`,
`physical_state_hash 7e75bdda37de5ca2`, visited 6,460,155,
moved 4,059,127, scheduled cores 4,879, identical both builds.
[Preserved raw Callgrind source and full line records](https://github.com/techrote/cybersand/actions/runs/42313028634/artifacts/13549667384).
The accepted six-worker performance question is separate.

## Final cross-owner, profiling, and sustained-tick evidence — 6 November 2026

**Technical disposition: REVISE.** The narrow cursor is demonstrably exact under
the exercised domains and does produce a repeatable positive performance change.
However, the 5–10% total-tick working target is not met on the tested multiworker
host; the target six-core/12-thread CPU, permitted Linux `perf` elapsed-CPU
function/line attribution, protected-source admission, exact-head Godot runtime
qualification, and independent acceptance remain unresolved.

### Six paired 1,800-tick six-worker trials: PASS

[Completed GitHub Actions #42313589873](https://github.com/techrote/cybersand/actions/runs/42313589873)
and [artifact #13549909353](https://github.com/techrote/cybersand/actions/runs/42313589873/artifacts/13549909353)
cover 12 total 1,800-tick runs (six balanced A/B pairs, always **six**
configured workers) against unmodified, LF-SHA-verified world source commits
`4a80af2a891332176a3912a235582d77d076a185` and
`eadbc96fa466cdfd0a2956d4a72a0c04d35dd279`, respectively.
The candidate SHA is an apparatus branch descendant of the exact original
cursor engine bytes; its source `world.cpp` LF SHA-256 remains
`bbd9741311bc67905934048633846b8d011efd760033edd0ff9e88be5b262868`.
Raw CSVs and machine/provenance logs are retained; both arms use the same fixture,
flags, compiler, benchmark and 600-tick analytic window selected *before*
repeated measurement. **All hashes, physical hashes and per-tick deterministic
work records match across every run**, with up to six actual task claimants.

| Window | Baseline elapsed mean | Cursor elapsed mean | Mean of six paired speedups | 95% paired Student-t CI | Verdict |
|---|---:|---:|---:|---|---|
| Complete 1–1800 | 41.775095 ms/tick | 40.655751 ms/tick | **+2.6771%** | **+2.0865 to +3.2677%** | Positive on this host, below target |
| Activity-grown 1201–1800 | 44.562861 ms/tick | 43.415197 ms/tick | **+2.5714%** | **+1.7409 to +3.4018%** | Positive on this host, below target |

All twelve run executions completed, with **6/6 paired wins** in each
analysis. Complete-run paired gains were 3.340%, 2.613%, 3.356%, 2.119%,
2.085%, 2.550%; activity-grown paired gains were 3.439%, 2.000%, 3.243%,
2.105%, 1.528%, 3.113%. The mean scheduled-core count across the last 600
ticks was 563.86; mean visited cells 428,780.48. These figures extend the
prior 600-tick observation without assuming that activity growth itself
proves a large gain.

**Hardware warning:** GitHub-hosted Ubuntu 24.04 AMD EPYC runner exposed only
four logical processors while running six configured workers. The experiment
establishes a real gain under that specific oversubscribed configuration, **not**
on the owner's Ryzen 5600X or another real six-core/12-logical-CPU host. It is
scientifically inappropriate to extrapolate a 5–10% full-tick effect from it.

### Independently executed owner #471 current-head gates: ALL PASS

[The owner-side current-head workflow #42313096990](https://github.com/techrote/cybersand/actions/runs/42313096990)
at cursor branch source `cd26abd96bb4d620f123e3fbb199354b8ee2c482`
ran these **four completed jobs** on Linux with GCC 13.3.0:

| Job | Result | Original evidence |
|---|---|---|
| Full native C++ | **188 tests passed** | [Native artifact #13550106854](https://github.com/techrote/cybersand/actions/runs/42313096990/artifacts/13550106854) |
| Native with `CYBERSAND_VERIFY_LOCAL_NEIGHBOUR` | **188 tests passed** | Same native artifact |
| Full native ASan + UBSan | **188 tests passed** | [Sanitizer artifact #13548879500](https://github.com/techrote/cybersand/actions/runs/42313096990/artifacts/13548879500) |
| Full native TSan | **188 tests passed** (1048.433 s, exit 0) | [TSan artifact #13550043815](https://github.com/techrote/cybersand/actions/runs/42313096990/artifacts/13550043815) |
| Original 96-tick signed/mask/chunk-seam adversary, workers 1/6 | **PASS**, exact baseline/candidate hashes, work and multiple worker claimants | [ABBA/adversary artifact #13549754379](https://github.com/techrote/cybersand/actions/runs/42313096990/artifacts/13549754379) |
| Owner source-pinned 3-cycle ABBA, workers 1/6 | **PASS**, checkpoint/hash/work parity | Same ABBA/adversary artifact |

Owner-side ABBA mean tick timings (three cycles, baseline/candidate each
twice per cycle; *different and smaller campaign* than our six-cycle analysis):
one worker `82.969 → 80.803 ms`, approximately **+2.61%**, and six workers
`37.593 → 36.791 ms`, approximately **+2.13%**. The respective median
candidate/baseline ratios are 0.977659 and 0.979403. This is further
independent evidence of modest improvements, **not** an additional set of
six unbiased independent pairs for our 1,800-tick CI.

### Corrected Callgrind source-line profile: PASS

[Callgrind exact-head #42314416637](https://github.com/techrote/cybersand/actions/runs/42314416637),
[artifact #13549687979](https://github.com/techrote/cybersand/actions/runs/42314416637/artifacts/13549687979):
original and cursor **identical hashes, work and 16 first ticks** on one worker.
Active `Ir` counts are 14,690,762,574 vs 13,828,652,071 instructions:
**862,110,503 fewer (−5.868385%)**. Source-line and function annotations
attribute major savings to `update_rule_kernel`,
`schedule_pending_reaction_wake` and `address/find_chunk` call reductions
under the cursor. Full raw source-level `.callgrind` files retained.
Do not add overlapping inclusive counts, or treat −5.87% instructions as
elapsed-time speedup. Native `perf` still blocked by
`perf_event_paranoid=4` on hosted runner.

### Source admission and CI boundary

All engineering source bytes tested remained under the original #471 cursor
`world.cpp` LF SHA-256. The owner initially added a `workflow_dispatch` plus
unconditional-cancellation conflict that the repository CI scheduling-policy
checker correctly rejected. After independent notification, the owner **retired
both temporary `pf471-neighbour-qualification.yml` and `pf471-neighbour-perf.yml`
workflows** (while retaining their immutable successful Action run artifacts)
in the successor commit
`6c58a736f814faf48e9a616652760a45467d8d16`. The new
[documentation/provenance run #42315943431](https://github.com/techrote/cybersand/actions/runs/42315943431)
progressed past scheduling checks and fails only at the **expected**
`Check material catalogue shadow compatibility` gate: the modified
`native/src/world.cpp` bytes do not yet have an owner-reviewed
`REVIEWED_TRANSITIONS` entry. **This is the intended fail-closed boundary.**
No scheduling-policy checker was weakened, and no immutable source lock changed.
Our independent qualification workflows use non-cancelling, per-run groups.

**No owner-approved `REVIEWED_TRANSITIONS` entry; no immutable compatibility
lock refresh; no modifications or merge of #471 or `main` by this review.
PRs #471 and #477 remain Draft.** Formal independent third-party source and
performance acceptance plus real six-core/12-thread replication remain
required before considering **ACCEPT FOR FURTHER ADMISSION**. If the
deployment-representative effect remains around 2–3%, decide explicitly
whether approximately 1 ms per stress-canvas tick warrants the protected-source
and maintenance complexity, or **REJECT** the production change.

## Final current-head status and independent handover

**State observed 7 November 2026 00:07 UTC:**

- PR #406 was merged by a different actor on 6 November at 22:08 UTC.
- PR #471 is **Draft, unmerged**; latest reviewed owner branch
  `27ce2aca9e061090160d8ca06e76da82bf2bc8b9` adds a dated **unadmitted
  MAT-AUTH transition proposal** and new independent read-only review
  [issue #485](https://github.com/techrote/cybersand/issues/485) after
  the temporary owner workflows were retired. No new cursor engine source
  bytes or source-admission records have been added since the pinned
  measured candidate. The protected `native/src/world.cpp` LF SHA-256 remains
  `bbd9741311bc67905934048633846b8d011efd760033edd0ff9e88be5b262868`.
- PR #477 is a **separate Draft, unmerged**, with the independently corrected
  benchmark apparatus, edge fixtures, scoped workflows and this dated audit.
  This work has not changed the original implementation branch or protected
  catalogue lock.
- Owner's review-ready source note now states **ACCEPT FOR INDEPENDENT
  SOURCE-ADMISSION REVIEW** — a request for strictly read-only review rather
  than admitting protected bytes, issuing a production runtime, or merging.
  This independent report's disposition remains **REVISE** for production
  qualification pending deployment-representative perf/benefit acceptance.

**No native correctness or benchmark apparatus gates remain pending on the
pinned source.** Proven exactness includes both full native 188-test builds,
188 full ASan/UBSan tests and 188 full TSan tests at the owner-controlled
exact cursor source, separate independent 1/6-worker signed/mask/nonpower2/epoch
replays with sanitizers, 24 standard 600-tick measurements, 12 sustained
1,800-tick measurements, the source-derived 129-rectangle fixture, and
verified original/candidate Callgrind Ir with full line annotations.
All state hashes, physical hashes and compared deterministic work counts
match. The 1/6-worker elapsed-time benefit is positive, but only
**+2.677% six-worker sustained on an oversubscribed four-logical-CPU host.**
Host system `perf` still returns `perf_record_exit=255` with
`perf_event_paranoid=4`; this is not a successful `perf` profile.

**Next bounded owner decisions, not another speculative implementation:**

1. Complete the already registered [#485 **strictly read-only MAT-AUTH source-admission review**](https://github.com/techrote/cybersand/issues/485) of
   the unchanged cursor source, full original GitHub Actions evidence and the
   ABI/phase/worker safety contracts. Reconcile the conclusion with the
   owner-requested admission review; do not change the protected lock.
2. On a quiet six-core/12-logical-CPU host (with permitted native Linux
   `perf` sampling), run the same source-pinned 1/6-worker, 600/1800-tick
   campaign and gather actual function/line CPU attribution. Preserve
   failures as well as successful raw records.
3. Owner makes an explicit **risk/benefit** choice: retain the narrow
   cursor if ~1 ms/tick or the measured target-host gain is worthwhile,
   or REJECT the production optimisation if complexity outweighs benefits.
   The original 5–10% target is not automatically met by a 2–3% gain.
4. **Only following independent acceptance and owner approval**, prepare a
   reviewed source-ancestry transition from the verified LF baseline
   `5a9de5e09a8665392677902ab501696aafefb5bbd2d2800e3dc1059b87a6f17d`
   to the verified candidate LF hash above, record exact commit identity,
   preserve immutable compatibility locks, and execute exact-head
   documentation/provenance, Native and Godot/GDExtension acceptance.
   Never bypass source admission.
5. Leave **both PRs Draft and unmerged** until these separate requirements
   are satisfied. No production runtime publication by this independent work.

**Repository audit / raw evidence URLs and benchmark commands are linked
throughout this report and the #477 Draft PR.**
