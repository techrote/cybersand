# CyberSand native in-chunk neighbour cursor — executed Draft qualification

Base: techrote/cybersand PR #406 at `4a80af2a891332176a3912a235582d77d076a185`.
Protected implementation bytes were introduced before the qualification-only descendants; current qualification head `cd26abd96bb4d620f123e3fbb199354b8ee2c482` changes only test/workflow apparatus beyond the implementation.
Status: **ACCEPT FOR INDEPENDENT SOURCE-ADMISSION REVIEW; remain Draft/unmerged.** No production runtime or protected transition is admitted here.

## Scope and invariants

`World::update_cell` passes a read-only source-chunk cursor to
`update_rule_kernel` and the pending pair-reaction wake scan. Twenty-seven
visible reads avoid address/chunk-map lookup when the target remains within the
already resolved source chunk. `World::get`'s transient body mask is checked
before every fast read. Cross-chunk and missing-chunk reads retain the existing
`stored_material` path.

No material value is cached across a write. No movement, sidecar, JobEffects,
activity, epoch, scheduling, physical hash, CYPS, PressureFlow or IN authority
is changed. The compile-time `CYBERSAND_VERIFY_LOCAL_NEIGHBOUR` path compares
every guarded same-chunk fast read against the ordinary `World::get()` answer.

## Actual source-matched qualification — 6 November 2026

Primary execution: [Actions 42313096990](https://github.com/techrote/cybersand/actions/runs/42313096990),
GitHub-hosted Ubuntu 24.04, GCC 13.3.0.

| Gate | Result |
|---|---|
| Ordinary registered native suite | **188/188 PASS** |
| Entire native suite compiled with `CYBERSAND_VERIFY_LOCAL_NEIGHBOUR` | **188/188 PASS**; no oracle mismatch |
| Strict ASan/UBSan | **188/188 PASS**; build 290.731 s, execution 607.013 s |
| Strict TSan | **188/188 PASS**; build 115.477 s, execution 1048.433 s; no race report |
| Signed/mask/chunk-seam/missing-residency adversary | **PASS** at 1 and 6 configured workers |
| Six-worker adversary participation | **4 workers actually observed** in both parent and candidate |
| Exact parent/candidate stress A/B/B/A | **PASS parity in all 24 runs; candidate faster in all six paired cycles** |

The first adversary attempt refused because its test-only maximum chunk capacity
was 64 while reactive products legitimately expanded residency. The apparatus
was corrected to a bounded 256 chunks / 1024 active cores. No engine source or
optimization setting changed in that repair.

### Adversarial exactness

Parent and candidate are identical at ticks 24/48/72/96 for both worker counts,
including final state/physical hashes, 9,849 visited cells, 9,831 moved cells and
3,959 scheduled cores. Six configured workers observe four actual participants.

Final adversary hashes:

- state `855e9ac93035a44c`;
- physical `35be6ceef2619b3a`.

### Same-host A/B/B/A performance

The benchmark compiles the same 129-rectangle stress fixture against a detached
exact parent `4a80af2a...` and candidate `cd26abd...`, using identical
`-O2 -g -fno-omit-frame-pointer -pthread` GCC 13 flags. Each arm executes
600 ticks. Each worker count has three **parent / candidate / candidate / parent**
cycles; raw per-tick CSV and JSON, host/compiler/source fences and executable
SHA-256 values are retained in artifact `pf471-abba-42313096990-1`.

Every run has exactly:

- state hash `d2c019a2752b7657`;
- physical hash `f9631ca2bece4d99`;
- 249,475,527 visited cells;
- 74,373,999 moved cells;
- 211,869 scheduled cores.

| Workers | Cycle | Parent mean ms | Candidate mean ms | Candidate/parent | Improvement |
|---:|---:|---:|---:|---:|---:|
| 1 | 1 | 85.656 | 81.486 | 0.9513 | 4.87% |
| 1 | 2 | 82.318 | 80.479 | 0.9777 | 2.23% |
| 1 | 3 | 80.932 | 80.444 | 0.9940 | 0.60% |
| 6 | 1 | 37.290 | 36.382 | 0.9757 | 2.43% |
| 6 | 2 | 37.751 | 36.973 | 0.9794 | 2.06% |
| 6 | 3 | 37.738 | 37.017 | 0.9809 | 1.91% |

Across all runs, mean parent/candidate is **82.969 → 80.803 ms** at one worker
(~2.61%) and **37.593 → 36.791 ms** at six workers (~2.13%). Median cycle ratio
is 0.97766 and **0.97940** respectively.

The one-worker first cycle has visible host/order drift, which is why the
production-relevant six-worker result is the stronger claim: all three cycles
cluster within 0.5 percentage points. This is a **modest kernel-level speedup**,
not a claim of 2% whole-game FPS on a Rapier/Godot workload.

The result aligns with PF-V2 #481/#482: on current-main stress-canvas,
PressureFlow head preparation is only ~16% of native tick time while ~84% lies
in the material/kernel residual. This cursor targets part of that dominant path.

## Remaining gates and admission boundary

- The branch still changes MAT-AUTH-protected `native/src/world.cpp`.
  Correctness/performance evidence justifies preparing a source-pinned transition
  proposal, but **does not itself admit it**. Frozen locks must not be refreshed.
- The ordinary Draft PR Native/Godot workflows are intentionally skipped.
  A current-main reconciliation and resulting-head qualification must occur only
  after independent source-admission review.
- Source-line `perf` attribution was requested by the original experiment plan
  but is not part of the successful A/B artifact. A bounded follow-up attempts
  it on GitHub-hosted Linux; host perf-event policy may legitimately refuse.
- No source-matched Godot/Rapier FPS claim has been made.
- No runtime binary is published.

## Disposition

**ACCEPT FOR INDEPENDENT REVIEW / CURRENT-MAIN RECONCILIATION PLANNING.**
The implementation is exact across the executed normal/oracle/sanitizer/adversary
matrix and produces a small, repeatable same-host six-worker gain. Do not merge
the current stacked Draft or add a reviewed transition until an independent
MAT-AUTH source reviewer accepts the exact protected delta and the resulting
current-main candidate passes its own gates.


## Source-line profiling follow-up

A bounded source-line profiling attempt ran in [Actions 42315420376](https://github.com/techrote/cybersand/actions/runs/42315420376).
The runner provides `perf 7.0.14` but has `/proc/sys/kernel/perf_event_paranoid = 4`
and no privileged performance-monitoring capability. Both parent and candidate
`perf record` invocations therefore refused before executing the benchmark with
`Failure to open any events for recording`. Empty perf data and the complete
refusal stderr are retained in artifact `pf471-perf-42315420376-1`.

No sysctl, capability or runner policy was changed to obtain profiling access.
The unavailable source-line attribution is explicitly retained as a host/tooling
limitation. It does not substitute for, or invalidate, the successful repeated
A/B/B/A wall-clock result.
