---
title: Bounded PressureFlow per-run head repair — experimental Draft and qualification boundary
status: Current
document-kind: audit
scope: 2026-11-06 PR 472 isolated source implementation, exactness design, unexecuted native gates, and honest benchmark boundary; not an accepted speedup or runtime
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [../architecture/pressure-flow-v1.md, ../architecture/pressure-optimization.md, 2026-11-06-workbench-pf-tick-cost.md, 2026-11-06-pf-ballistic-tick-cost.md, ../operations/cybersand-codex-development-handover.md]
---

# Experimental bounded per-run head repair — 2026-11-06

**Disposition: REPAIR REQUIRED; NOT ADMITTED; DO NOT MERGE.** This is a source
prototype with a native test implementation, not a validated physical-equivalence
or performance result. No actual g++-13 native build, native test, sanitizer,
Godot runtime, or after-change canvas measurement was executed in the Chat
authoring environment. None of the source analysis below should be promoted
to a passing executable gate. Draft PR [#472](https://github.com/techrote/cybersand/pull/472)
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

## Native test and benchmark apparatus (not executed)

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

## Qualification gates and blockers

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
| Docs/checks `check_docs.py`, `check_m11_consistency.py`, `check_repository.py`, retrieval evaluation | **NOT RUN locally**; inspect Draft PR's exact-head hosted Documentation/provenance check separately |
| Protected MAT-AUTH source admission, runtime provenance and owner review | **PENDING**; do not refresh frozen protection locks or publish runtime |
| Exactness / no race / <=2.5 ms target | **UNESTABLISHED** |

**STOP / handover:** Keep Draft and unmerged. On a native-enabled runner,
execute the pinned baseline and candidate, produce smallest counterexamples
for any head/continuation disagreement, repair them in this isolated branch,
and rerun. A correct but slower result is a negative outcome; investigate
broad producer rectangles, run-discovery time and mandatory row/wake cost.
Do not promote physical exactness or speedup until the required runtime
matrix and independent review pass. No source-only claim overrides this gate.
