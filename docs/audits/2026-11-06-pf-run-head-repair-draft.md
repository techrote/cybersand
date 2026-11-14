---
title: Bounded PressureFlow per-run head repair — experimental Draft and qualification boundary
status: Current
document-kind: audit
scope: 2026-11-06 PR 472 Draft source experiment, hosted native qualification and negative source-pinned host-scale performance; original pre-execution record retained below
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [../architecture/pressure-flow-v1.md, ../architecture/pressure-optimization.md, 2026-11-06-workbench-pf-tick-cost.md, 2026-11-06-pf-ballistic-tick-cost.md, ../operations/cybersand-codex-development-handover.md]
---

# Experimental bounded per-run head repair — 2026-11-06

**Current disposition: NO-GO for the existing per-run preflight optimisation; NOT MAT-AUTH ADMITTED; KEEP DRAFT; DO NOT MERGE.** Real GCC 13 native (188/188), three-arm differential, ASan/UBSan (188/188) and TSan (188/188) qualification subsequently succeeded on pinned candidate commits, but a reproducible exact-source 1024×1024 host-scale proxy measured a **18–147% slower cached total tick** across all five tested profiles. The new preflight probes every cell and adds approximately 18.1 ms to the full-dirty churn path while all existing base-head and row work remains. The exact native/Godot and named-canvas workbench matrix on the **latest** gap-corrected source is incomplete, and MAT-AUTH still correctly blocks. See the authoritative executed continuation near the end of this report. Original pre-execution findings below are retained as historical checkpoints, **not** current test status. Draft PR [#472](https://github.com/techrote/cybersand/pull/472)
is stacked on experimental [#406](https://github.com/techrote/cybersand/pull/406).

## Reproducible source identity and independent ownership

| Item | Value / authority |
|---|---|
| Repo | techrote/cybersand |
| Parent/source branch | claude/water-ballistic-hybrid (#406) |
| Source SHA explicitly refreshed before work | `4a80af2a891332176a3912a235582d77d076a185` |
| Candidate branch | `sol6/pf-run-head-repair-20261106-2100` |
| Candidate final SHA | consult PR #472 head and `git rev-parse HEAD` on the exact candidate checkout; never infer from this report's own writing commit |
| Source worktree | GitHub connector branch isolated from owner branches; no local clone mounted |
| Research provenance | supplied standalone model/probe/runner; evidence only, not CyberSand native exactness |
| Protected consumers | `world_pressure.inc` and other pressure-derived files changed only on candidate; `world.cpp` remains unchanged |
| Concurrent exclusion | collider #470, neighbour kernel #471, render/ballistic/workbench implementations not incorporated |
| Local host restriction | no checkout or source-matched native compiler/process, no g++-13 build, Godot executable or scene/tick measurements |

This branch does not change defaults, physical pressure parameters, CYPS codecs,
physical hash domains, worker scheduler or any production binary. It *does*
change the optimisation execution identity from 4 to 5; the older accepted
identity and evidence remain historical.

## Implementation and intended invariants

The owner-only cache now reserves one inclusive dirty-Y hull per indexed
chunk/local-X (C * S slots, where C is index capacity and S is chunk side).
`DirtyY` is two uint16_t fields (4 bytes at the intended ABI), and a
`prospective_rows` record contributes 128 bytes per admitted chunk slot.
Additional declared capacity is at most C * (4S + 128) bytes, excluding
allocator overhead; the actual limit is reported by
`run_repair_capacity_bytes`, included in `derived_capacity_bytes`.

`invalidate_pressure_input` validates its index slot, unions X/Y rectangles at
existing serial phase barriers and also preserves certificate and wake
invalidation. Broad parallel `JobEffects` rectangles remain conservative,
rather than being inferred from renderer dirty records. Cold membership or
incomplete slots fail to the full reference operator; gas-topology execution
still marks **every X as full-height**, clears wake summaries and revokes
certificates. Chunk installation, region reset, destruction and restoration
continue through cold/rebuild fallback. Repeated/reversing edits only enlarge
the stored Y hull.

Before any derived write, the owner scans each changed chunk-X/local-X
vertically, excluding nonresident chunk-Y gaps. It tracks the dirty effect
through contiguous unmasked liquids, a changed Water run, and the floor
directly below a Water run. A changed Water cell, contiguous foreign-liquid
load, lid/Empty boundary or masked cell can select a complete Water run.
A known non-liquid boundary that is unchanged stops the upward-load
dependency cone. Adjacent Water runs propagate through an actual liquid
continuation. A selected run is recomputed *in full*, with the existing
`top_pressure`, supported/unsupported closure, saturation, signed integer
arithmetic and negative unknown sentinel. Dirty non-Water positions are
written `kNoHead` without redoing other clean positions.

The preflight also reserves a conservative set of candidate full-width dirty
rows: existing row marks, all candidate Water-run rows, all dirty non-Water
rows. Its budget estimate is **candidate base writes + candidate full-width
row interpolation cells**. It includes an independent probe guard at most
4 * `head_repair_cell_budget` (saturating on integer overflow), without
increasing the existing head-cell budget. A missing membership/slot, exceeded
capacity or budget selects reference preparation before any base-head
repair is committed. The 4x guard is an engineering bound, **not** a measured
break-even point or a proof the fast path will outperform reference.

The existing row algorithm, unknown-anchor interpolation, activity-block wake
predicates, own-row wake bitmaps and serial owner merge of deferred certificate
invalidation are intentionally retained. Column worker tasks still own disjoint
columns and private row marks, which the owner merges only after their join;
row sub-band tasks own disjoint row/activity-block domains.

**Important limitation:** This is a proposed dependency-closure argument
based on the inspected source, not a proof established by execution, formal
verification, sanitizer evidence, or an independent reviewer. In particular,
cross-chunk floor support, masked non-resident holes, foreign-liquid/Water
transitions and all edit producers must be checked under actual native tests.

## Native test and benchmark apparatus (original proposed protocol)

The permanent native
`native/tests/test_workbench_pressure_heads.cpp` was extended with A/B/C
comparisons: A reference, B repaired cached or cached_dormant, C same variant
with intentionally undersized index capacity for fallback. The matrix requests
1, 4 and 6 workers, serial/pooled column and row paths, gas on/off, 96
completed ticks per case, deterministic direct edits and moving masks.
The test checks **every resident prepared-head status/signed value** after
every tick, normalized A/B variant-equivalence hash, raw B/C physical hash and
CYPS bytes, quantity and gas continuity, wake counts and phase scheduling.
The existing broader test suite remains responsible for additional producer,
reactive, restored, negative-coordinate and scenario cases. These assertions
have not been compiled or executed. Passing this fixture alone would not
prove all requested adversarial families; it is an initial regression.

`tools/lcb/pf_run_repair_compare.sh` compiles the *existing registered*
1024x1024 LCB-201 host-scale native fixture independently from an exact
baseline checkout and exact candidate checkout, runs three late-phase
rotated repeats across two worker counts and five water profiles, preserves
raw JSONL plus compiler/host/source/binary fences, and computes medians.
This is a **native synthetic host-scale proxy**, not the named
my-canvas, bench-canvas or stress-canvas, and excludes live Rapier and actual
Godot workbench pacing. Never label a proxy sample as an in-app result.

Execute on a machine with a clone, native toolchain and source-matched test
assets (from the parent checkout, not on the active owner's branch):

```bash
git fetch origin claude/water-ballistic-hybrid sol6/pf-run-head-repair-20261106-2100
git worktree add --detach ../pf-base 4a80af2a891332176a3912a235582d77d076a185
git worktree add --detach ../pf-candidate origin/sol6/pf-run-head-repair-20261106-2100
(cd ../pf-base && make CXX=g++-13 build/tests && ./build/tests "LCB-002" &&
 ./build/tests "Workbench parallel")
(cd ../pf-candidate && make CXX=g++-13 build/tests && ./build/tests "LCB-002" &&
 ./build/tests "Workbench parallel" && ./build/tests)
bash tools/lcb/pf_run_repair_compare.sh ../pf-base ../pf-candidate /tmp/pf-run-compare g++-13
```

Run the existing Godot PressureFlow/workbench test suite with a GDExtension
built from the candidate exact source, then strict ASan/UBSan and TSan native
jobs (compare 1/4/6-worker paths and real pool participation). Run the
full exact-gas, negative-coordinates, transient-mask, burst JobEffects,
continuation and restore matrix. The three-arm tests currently do *not*
include exhaustive differential enumeration of all runtime-generated masks
and every producer. Do not extrapolate qualification from a partial pass.

## Measurements and counter interpretation

| Scenario | Existing historical dirty columns | Parent as newly measured here | Candidate as newly measured here |
|---|---:|---|---|
| my-canvas | 457 / 512 | **Not measured** | **Not measured** |
| bench-canvas | 979 / 1,024 | **Not measured** | **Not measured** |
| stress-canvas | 2,039 / 2,048 | **Not measured** | **Not measured** |

Historical parent-source gas-off stress-canvas: head preparation approximately
4.2 ms/tick (2.9 ms column, 1.3 ms row) with approximately 88% complete
reference fallback. These are from
[the earlier 2026-11-06 PressureFlow/ballistic investigation](2026-11-06-pf-ballistic-tick-cost.md),
**not** an A/B benchmark and not an improvement claim. No measured
gas-on/ballistic-on before/after pair or <=2.5 ms result exists.

Execution-v5 counters disclose preflight time/probes, dirty-Y spans, selected
runs, candidate base/row cells, budget rejection, column and row wall time
and worker-summed wake-scan CPU time. Cumulative counter deltas are needed
per tick/profile. `head_wake_worker_nanoseconds` is task CPU sum, not elapsed
critical-path wall time; it must not be added blindly to `head_row_nanoseconds`.
`base_cells_written` and `head_cells` change as execution bookkeeping, not
physical authority. Wake decisions, CYPS, gas ledgers and quantity events are
physical-continuation obligations; physical and work hashes have distinct
comparison domains. The backend's row wake scan remains mandatory unless
the independently admitted wake-clean summary allows a justified skip.

If dirty spans, foreign-liquid run closure or owner preflight approach the
whole column, the candidate may be slower. Row interpolation and sleeping
wakes may dominate even with fewer column writes. No threshold is relaxed to
mask negative evidence.

## Original pre-execution qualification snapshot (superseded)

| Required gate | Actual outcome in this authoring session |
|---|---|
| PR #406 exact starting SHA refreshed | PASS — pinned as above |
| New branch, stacked Draft PR, no owner write | PASS — Draft #472, independent branch |
| Actual g++-13 test build and focused filters | **NOT RUN** — local source/toolchain unavailable |
| Full native regression suite | **NOT RUN** |
| Native A/B/C head, CYPS, gas, certificate and wake parity | **NOT RUN** — no native evidence |
| 1/4/6-worker serial/parallel and actual participation | **NOT RUN** |
| ASan / UBSan / TSan | **NOT RUN** |
| Real Godot Linux/Windows and actual named scenes | **NOT RUN** |
| Paired warmed source-matched stress benchmark | **NOT RUN** |
| Docs/checks `check_docs.py`, `check_m11_consistency.py`, `check_repository.py`, retrieval evaluation | **NOT RUN locally**; hosted Documentation/provenance failed *before* these checks at MAT-AUTH protected-source compatibility, so no pass may be attributed to these checks |
| Protected MAT-AUTH source admission, runtime provenance and owner review | **FAIL** in [hosted Documentation run 42297131161](https://github.com/techrote/cybersand/actions/runs/42297131161): reviewed target SHA-256 `26051b0d10ab10d65db822c993742e0a0bf13711f3bd56158e95d77735737aca` for `native/src/world_pressure.inc`, observed experimental file `934c8229f50c4638e6db2aff2135fbf7209da5599f69002157fe3238ca26de4a`; independent reviewed transition required, no lock refresh |
| Exactness / no race / <=2.5 ms target | **UNESTABLISHED** |

**Source-matched hosted CI on implementation head `494f1447038996ba32dc3d618c3cf1fa74489d05` (2026-11-06):**
[Documentation run 42297131161](https://github.com/techrote/cybersand/actions/runs/42297131161)
failed at the material-catalogue shadow-compatibility check, before the docs,
provenance, M11 and retrieval steps were reached; native/Godot were skipped
by the deliberate Draft workflow. This is an **actual negative result**, not a
pass or a reason to bypass the guard. [Native source-scope advisory run
42297131107](https://github.com/techrote/cybersand/actions/runs/42297131107)
passed its report-only classification and does not qualify the native source.
Subsequent documentation-only commits must be rechecked against their own
exact head; do not substitute this earlier run as the latest-head gate.

**Research-only extra observation:** the supplied stand-alone
`pf_run_repair_model.cpp` compiled with GCC 14.2.0 in the limited authoring
container and returned `OK model_only head_repair seed=0x406b624e7`,
`edits=1218`, `planned_runs=894`, `dirty_row_recomputes=986`.
This uses neither native CyberSand World nor the new candidate source.
It is not native exactness or benchmark evidence.

**Original STOP / handover, before any real native execution:** Keep Draft and unmerged. On a native-enabled runner,
execute the pinned baseline and candidate, produce smallest counterexamples
for any head/continuation disagreement, repair them in this isolated branch,
and rerun. A correct but slower result is a negative outcome; investigate
broad producer rectangles, run-discovery time and mandatory row/wake cost.
Do not promote physical exactness or speedup until the required runtime
matrix and independent review pass. No source-only claim overrides this gate.


---

## Execution continuation — actual native, sanitizer and performance evidence

**Evidence cut: 6 November 2026, later hosted campaign; the preceding historical PRE-EXECUTION sections are superseded for validation status.** This is a one-time bounded engineering continuation, not an admission decision. Host execution occurred on GitHub-hosted **Ubuntu 24.04 / GCC 13.3.0**, using source-pinned checkouts and retained command/artifact logs. Local Chat authoring still cannot run a source-matched Godot executable. Do not extrapolate any result from an earlier SHA to a later modified source file.

### Source and ownership fences

| Identity | Exact SHA / state |
|---|---|
| Parent dependency, unmodified #406 | `4a80af2a891332176a3912a235582d77d076a185` |
| First full-native PASS and new identity goldens | `4f490658c3b3017dabbec51d613d99569a13a437` |
| Paired sanitizer and proxy candidate PASS / negative benchmark | `6c40b58f52f1151fac133fd696ecd41d5655ddca` |
| Directed nonresident-gap source repair | `05cc48394c1a82bc08bef7fbdecaaf50ca18dad4` |
| CI scheduling-policy correction (same physics) | `d5d12dab375e3375ea4c9b3238994865b0225278` |
| Draft branch | `sol6/pf-run-head-repair-20261106-2100`; inspect PR #472 for later documentation-only descendant |
| State | Draft, open, unmerged; no write to #406, main, #470 or #471 |

The first `make CXX=g++-13 build/tests` compiled before running fixtures but exposed stale **execution-v4** identity assertions when executing `LCB-002`. The production execution identity was already intentionally **v5**, so the test's two known SHA-256 answers and diagnostic label were independently recomputed and corrected, rather than weakening identity semantics. The cached v5 answer is `5f836af796c8df8d208b4faf2a3ca981e2875fd2e3b8f49b62000b20c5eac4a4`; the dormant v5 answer is `ef1acfa5deb819af2516d99d7e3f48180a591556d3cd7adf8554f13b5127eb54`.

### Native exactness and concurrent execution

| Actual command or workflow | Source commit | Observed result |
|---|---|---|
| `make CXX=g++-13 build/tests` | `4f49065…` | **PASS**, full test binary constructed |
| `./build/tests 'LCB-002'` | `4f49065…` | **17/17 PASS**, 125.970 s |
| `./build/tests 'Workbench parallel'` | `4f49065…` | **PASS**, includes three-arm directed differential |
| `./build/tests` | `4f49065…` | **188/188 PASS**, 631.480 s |
| `bash tools/ci/run_native_family.sh asan-ubsan …` | `6c40b58…` | **188/188 PASS**, full sanitized test run 450.152 s; build 196.339 s |
| `bash tools/ci/run_native_family.sh tsan …` | `6c40b58…` | **188/188 PASS**, full TSan test run 1234.153 s; build 101.728 s; no race reported |
| Final gap-repair source native/sanitizer/Godot matrix | `05cc483…` descendants | **Not all completed at this evidence cut**; status must be checked separately and cannot inherit old passes |

Evidence: [exact full-native run #42300993231](https://github.com/techrote/cybersand/actions/runs/42300993231) and [sanitizer/proxy campaign #42301636450](https://github.com/techrote/cybersand/actions/runs/42301636450). Command logs and original timing output are retained as Actions artifacts under those runs.

The three-arm fixture checks reference (**A**) against cached or cached_dormant (**B**) with the **PressureVariantEquivalenceV1** projection, and the repaired variant against same-variant forced-reference-fallback (**C**) with **raw physical hashes and complete CYPS continuation bytes**. Every completed tick compares all resident prepared-head status/signed values, gas continuity, quantity, wake and scheduling. It ran **24 combinations**: 2 cached policies × 3 configured worker counts (1/4/6) × 2 serial/parallel head modes × 2 gas policies, with **96 ticks/case (2,304 fixture ticks across cases)**. Initial `run()` also covers reference and same-variant serial/parallel comparison at 160 ticks/variant. All reported three-arm comparisons passed. Normal cached path logged zero reference fallbacks in these 24 combinations; forced-fallback arm did exercise fallback.

The 1024² proxy separately demonstrates source-matched **4-worker task participation**: the completed fixture emits `max_observed_participants=[4,4,4,4]` for its four simulation arms, versus `[1,1,1,1]` on the one-worker control. This is not a general proof that all six configured workers executed simultaneously in every directed test. TSan's entire native suite included actual multiworker PressureFlow/producer code, but there is no independent current-source Windows native TSan or Godot matrix here.

**Gap hazard correction:** reviewing preflight versus commit found that `prepare_pressure_tick()` reset the `chain_dirty` dependency across a non-resident chunk-Y gap unconditionally, but the column pass reset it only inside an `if (open)` Water-run closure. The candidate source at `05cc483…` now resets `chain_dirty` across any such gap, closing an open run first if necessary. A directed `gap_preflight_commit_bound()` case was added, with an upper foreign liquid, genuinely missing vertical chunk, supported lower Water, explicit initial-reserve limits and a post-tick `base_cells_written <= head_candidate_base_cells` assertion. First execution failed because the new test configured `maximum_chunk_count=16` but left `initial_chunk_reserve` at its default; fixed in the test. A later version positioned Water at the first resident lower row. **The pre-fix case subsequently passed its focused execution:** therefore the source mismatch was corrected conservatively but *a failing differential runtime witness has not been established*. The directed regression is a useful boundary control, not proof of a previously reproduced physics divergence. Do not overstate a negative test.

### Reproducible same-host, same-flags native performance decision

Existing [`tools/lcb/pf_run_repair_compare.sh`](../../tools/lcb/pf_run_repair_compare.sh) compiled parent and candidate from clean, pinned Git worktrees with the same GCC 13 flags (`-O3 -DNDEBUG -pthread`, C++20, strict warnings) and host. It ran **three full 256-tick repeats** for **each of five 1024×1024 Water profiles**, at configured 1 and 4 workers. Every repeat includes reference, cached, dormant and FreeMass arms. `summary.json` contains **30 parent/candidate median comparisons**, with the original **60 full runs of four-arm JSONL** and complete source/host/binary checksums in artifact [`pf472-parent-candidate-proxy-42301636450-1`](https://github.com/techrote/cybersand/actions/runs/42301636450).

**All 30 comparisons were slower** with the candidate. Reported values below are medians of the three **per-run tail-phase mean total-tick times**; SD is the across-repeat sample standard deviation in ms.

| Profile | Workers | Parent cached ms (SD) | Candidate cached ms (SD) | Candidate/parent | Parent/candidate dormant ratio |
|---|---:|---:|---:|---:|---:|
| pool-vented | 1 | 0.327 (0.003) | 0.386 (0.002) | **1.18×** | 1.17× |
| pool-sealed | 1 | 0.318 (0.006) | 0.382 (0.001) | **1.20×** | 1.18× |
| pool-sealed-remote-gas | 1 | 4.346 (0.020) | 10.051 (0.041) | **2.31×** | 2.30× |
| pool-vented-moving-mask | 1 | 6.986 (0.026) | 16.425 (0.071) | **2.35×** | 2.33× |
| pool-vented-boundary-churn | 1 | 18.524 (0.191) | 45.576 (0.070) | **2.46×** | 2.46× |
| pool-vented | 4 | 0.326 | 0.384 | **1.18×** | 1.16× |
| pool-sealed-remote-gas | 4 | 4.351 | 10.079 | **2.32×** | 2.32× |
| pool-vented-moving-mask | 4 | 7.008 | 16.270 | **2.32×** | 2.33× |
| pool-vented-boundary-churn | 4 | 18.435 | 45.599 | **2.47×** | 2.46× |

**Counter attribution (cached, 1 worker; 96 tail ticks × 3 repeats):** in the boundary-churn profile, parent average total tick **18.53 ms**, entire head preparation **10.77 ms**, gas **7.49 ms**. Candidate average tick **45.62 ms**, entire head **37.82 ms**, gas **7.52 ms**. Of candidate head preparation, average **18.16 ms** was the new read-only preflight, followed by approximately **15.0 ms** of column preparation and **4.6 ms** of row repair. This is direct per-tick instrumentation: the gas phase did not explain the 27-ms total regression.

The churn candidate probes **1,638,400 cells/tick** in preflight, proposes **1,638,400 candidate base writes and 1,638,400 candidate row cells**, and actually writes **1,638,400 base cells**, with **944 selected Water runs, zero reference fallbacks and zero preflight budget rejections**. The default budget of 4,194,304 cells admits all 3,276,800 proposed base+row cells, so it fails to detect this severe cost despite staying within the declared bound. Column work remains whole-column on the dirty span and the new scan is additive. The moving-mask and remote-gas profiles show the same pattern. Near-idle profiles have zero preflight probes yet remain ~18–20% slower.

The reference variant also slowed by approximately **32%**, and the runner executes baseline batches before candidate batches, not in interleaved order. Frequency/host-order drift or code-path differences cannot be entirely excluded; do not claim all reference slowdown is caused by preflight. Nevertheless, head/gas timing decomposition, 1/4-worker consistency and three-repeat stability locate the **active cached regression** in the added head preparation rather than gas or unrelated renderer processing. The current candidate **does not meet** the intended improvement criterion; it is substantially worse in all active proxy profiles. A cheaper early all-dirty rejection / run-boundary index would be a *new, independently justified design*, not an excuse to inflate budgets or relax exactness.

**Memory/capacity:** on this proxy `index_chunk_capacity=128`, chunk side 128, 100 actual resident chunks and budget 4,194,304. The intended fixed extra run-repair storage is `C * (4*S + 128) = 81,920 bytes` (two uint16 dirty bounds per chunk-X and preallocated 128-byte prospective row masks); the measured `derived_capacity_bytes` rose from **15,345,028 to 15,427,084** (+82,056 bytes including counter expansion). Counter payload rose from **424 to 504 bytes**. Work and memory are bounded under the declared capacities but not acceptably fast. Peak RSS is a multisimulation-world process measure and not a reliable per-cache allocation size. Worker-summed wake CPU counters are **not** added to wall clock. No reliable native-only estimate is mislabelled as real Godot end-to-end workbench pacing.

**Scope limit:** this is a committed synthetic **1024²** proxy, **not** the saved `my-canvas`, `bench-canvas`, or `stress-canvas` (2048×1024) workbench scenes. No actual gas-off stress-canvas head preparation, capped versus uncapped Godot FPS/tickrate, ballistic Water with face release/impact spray, or source-matched Godot runtime was measured. Thus no ≤2.5 ms stress-canvas result is established. The proxy measured source `6c40b58…`, before the small gap-correctness source repair; remeasure that exact descendant if it is revived, never silently attribute the earlier times to the latest head.

### Documentation/provenance, source protection and outstanding gates

The protected `native/src/world_pressure.inc` **must continue to fail MAT-AUTH**. The prior *admitted* LF SHA-256 is `26051b0d10ab10d65db822c993742e0a0bf13711f3bd56158e95d77735737aca`, while the actual gap-corrected source LF SHA-256 is `bbc33dbc6b12404de06db2dda5a16b90a7d787f4d183ed06ad9b5751b631f360`. [Official docs/provenance run #42305345227](https://github.com/techrote/cybersand/actions/runs/42305345227) reached the guard and failed on exactly that protected drift after passing CI inventory/scheduling, source capability and policy prechecks. All eleven changed-file hunks in the protected path are confined to `prepare_pressure_tick()` and `compute_pressure_heads()` (188 additions, 26 deletions); this scope observation is not admission. The separate [source-pinned unadmitted transition proposal](2026-11-06-pf472-mat-auth-transition-proposal.md) records the old/new hashes, exact code commit `05cc48394c1a82bc08bef7fbdecaaf50ca18dad4`, role analysis and mandatory independent review; **no guard or lock changed**.

An independent **source-only** supplemental check on `6c40b58…` established PASS for `python3 tools/ci/check_m11_consistency.py`, the material compiler `--check`, both frozen/challenge `tools/docs/retrieval_eval.py` invocations. Its `check_docs.py`, `check_repository.py` and material-native parity commands had missing-workspace/missing-LFS failures because the supplemental job did **not** reproduce the official pinned companion-workspace checkout or materialised artifact environment: these are harness shortcomings and **not product-source passes or definitive product failures**. The separate official documentation job stops earlier at the legitimate protection gate, so downstream checks remain unqualified for this exact head. Historical M11 hashes remain untouched.

Normal PR-scoped Native/Godot workflows are correctly **skipped** while Draft; branch-scoped supplemental jobs do not weaken or override their admission requirements. The 1/4/6 configured-worker and native TSan coverage are real on the earlier revision, but an exact-runtime **Godot GDExtension built from the latest source**, strict Linux/Windows regression suites and saved real scenes have not completed. No production runtime or protected compatibility lock was published. No independent MAT-AUTH reviewer admitted this transition. Other candidate branches retain independent ownership.

### Decision and bounded handover

**NO-GO for PR #472's present optimisation design** on the evidence acquired: the retained actual source-matched active-water benchmark misses the required **useful performance improvement** decisively and repeatedly, and its counters show that the preflight duplicates work for all-dirty liquid paths. Earlier true native and sanitizer passes support physical exactness *for those tested commits and fixtures only*; they cannot override the negative cost decision or protect the not-yet-completed final-head Godot/MAT gates.

Keep #472 **Draft and unmerged**, preserve the tests, counter diagnostics, benchmark raw artifacts and the explicitly **unadmitted** transition proposal as experimental research. A future separate proposal may investigate producer dirty-rectangle narrowing or a strictly bounded early-rejection / reusable exact run-boundary index **only with a new matched baseline and three-arm proof**, not by changing the budgets/guards or quietly merging this slower implementation. Record progress and stop.
