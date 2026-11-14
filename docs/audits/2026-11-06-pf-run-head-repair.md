---
title: PressureFlow per-run head repair — isolated candidate and native qualification
status: Current
document-kind: evidence
scope: Dated experimental PR #406 stacked candidate; native differential tests, measured source-matched canvas-sized proxies, rejected speedup and remaining proof/platform gates; no production admission
canonical-for: [pf-run-head-repair-2026-11-06]
last-reviewed: 2026-11-06
related-documents: [../architecture/pressure-flow-v1.md, ../architecture/pressure-optimization.md, 2026-11-06-workbench-pf-tick-cost.md, 2026-11-06-pf-ballistic-tick-cost.md]
---

# Per-run PressureFlow head repair — 6 November 2026

**Disposition: REPAIR REQUIRED / PERFORMANCE NO-GO.** This is a candidate on its own
Draft stacked branch, **not a mainline or #406 change**. It deliberately does not
change the Water default, pressure law, gas topology, saved CYPS format or
physical hash domain. No production binary is published. The native differential
suite below is positive; the first matched performance series is negative, and
complete proof, platform/sanitizer and real workbench qualification remain admission
requirements. Do not interpret this audit as acceptance.

## Pinned source and scope

- Required source: `techrote/cybersand` PR #406, branch
  `claude/water-ballistic-hybrid`, commit
  `4a80af2a891332176a3912a235582d77d076a185` (read before branch creation).
- Isolated source branch: `codex/pf-run-head-repair-20261106`.
- Local comparison: full tracked source snapshot at pinned #406 head, plus only the
  candidate's native, native-test, benchmark and documentation changes.
- Measurement compiler: Debian GCC 14.2.0 (`g++`), Linux x86-64, `-O2 -DNDEBUG`;
  native tests built with `-O0 -g3` and the repository's `COMMON_FLAGS`.
  Hosted source-matched baseline GCC 13 build and two test filters passed in
  [run 42293616008](https://github.com/techrote/cybersand/actions/runs/42293616008).
- Separate #405 (#201 camera-region) and active ballistic/collider optimisation
  work are **not** consumed. The branch does not edit `world.cpp` and is not a
  claim that concurrent pressure work can be merged without reconciliation.

## Implementation and proof boundary

`PressureCache` now reserves one inclusive dirty local-Y hull per resident
chunk/local-X, one bounded candidate run span per resident slot, preflight
row-closure bitmaps and exact owner-merge scratch at World construction. Native
`invalidate_pressure_input` producers retain existing native JobEffects
rectangles and add Y bounds; renderer dirt is not consulted. An incomplete or
cold membership, global gas pass, failed budget preflight or capacity refusal
selects the existing complete reference path before any cached base write.

For each dirty X, the owner extends affected intervals upward through contiguous
unmasked Water (run top and immediately-above floor support), and downward
through unmasked Water and foreign liquids to the next non-liquid boundary.
Resident chunk gaps and masked positions terminate Water runs. Overlapping
spans merge. Column jobs use the unchanged `top_pressure`, quantity, supported
versus unsupported run closure, integer truncation and signed unknown encoding.
Only changed `base_head` values mark exact local rows; existing full-width row
interpolation and sleeping wake scans are preserved. Parallel jobs write only
own columns and row marks; the owner joins them before row/certificate merges.

**Remaining proof risk:** the budget charges preflight probes, selected span
cells and an upper bound on candidate row closure but does not separately charge
all upward `top_pressure` reads in the worst-case many-run/foreign-liquid stack.
This is a bounded preflight (probe cutoff), not yet a proof that the entire
incremental preparation's work is bounded by the requested cell budget. That
must be corrected and independently reviewed before acceptance. A dynamic
fallback is mandatory whenever source membership or dependency closure cannot
be established. Execution identity changed from version 4 to **5**; the native
readback known answers were updated. New counters include preflight timing and
probes, spans, selected cells, run count, column/row/wake timings and fallbacks.
Task timings are summed across potentially concurrent tasks, **not** mutually
exclusive elapsed wall times.

## Exact native test evidence

On the native candidate compiled with GCC 14.2.0:

- `make CXX=g++ build/tests`: **PASS** (compilation/link).
- `./build/tests 'PressureFlow per-run'`: **PASS**. A permanent production-World
  test runs 24 configurations: reference (A), same-variant cached or
  cached_dormant (B), forced index-capacity reference fallback (C); gas on/off,
  1/4/6 workers and serial/parallel head preparation. **100 ticks per
  configuration = 2,400 three-arm steps.** Each tick compares all resident
  `prepared_pressure_head` statuses and signed values, normalized
  cross-variant physical projection, B/C raw complete hash and CYPS bytes,
  Water quantity, gas topology IDs/revisions/history, wake counts and quantity
  ledgers. Includes negative coordinates, resident seams/gaps, lids, masks,
  foreign liquids, wall/floor edits, reversible edits, and deterministic
  four-cell randomized mutations. B remained on its cached path; C selected
  complete reference fallback on all 100 ticks per configuration.
- `./build/tests 'LCB-002'` and
  `./build/tests 'Workbench parallel'`: baseline GitHub GCC 13 **PASS** on
  source `4a80af2a` plus branch-scoped CI file. Candidate results are recorded
  in the PR and must not be inferred from the baseline.
- The complete native suite, focused Godot cases, ASan/UBSan and TSan require
  candidate-head evidence before admission. Source package omitted Git history
  and vendor runtime files, so local M11 and repository-policy checks cannot
  be treated as complete; rerun on the full GitHub checkout.

Some derived counters legitimately differ between A/B/C. The probe does not
mistake raw full-hash equality across implementation variants for physics parity.
`save_physical_state` is compared only for the same variant.

## Before/after matched timing — negative experiment

**Controlled native-harness proxies, not actual Godot application canvases.**
Both binaries compiled with GCC 14.2.0 `-O2 -DNDEBUG` from pinned baseline and
candidate on the *same machine*, using 128×128 chunks, six configured workers,
pooled heads, gas disabled, Water band height 64, and 457/979/2,039 authored
local-X edits per step. Profile widths match the requested labels; the synthetic
height, fill, core settings, active blocks and edits are not guaranteed to match
recorded user scenes. Four warm ticks precede eight measured steps. Source-matched
raw CSV comes from `native/bench/pf_run_head_repair.cpp`. Mean ± population SD:

| Synthetic case | Baseline head (ms) | Candidate head (ms) | Candidate preflight (ms) | Baseline tick (ms) | Candidate tick (ms) |
|---|---:|---:|---:|---:|---:|
| my-canvas 512×512, 457 X | 0.910 ± 0.257 | 0.972 ± 0.234 | 0.208 ± 0.030 | 6.747 ± 0.658 | 6.449 ± 0.279 |
| bench-canvas 1024×768, 979 X | 1.723 ± 0.716 | 2.326 ± 0.887 | 0.786 ± 0.280 | 13.171 ± 1.963 | 13.246 ± 1.183 |
| stress-canvas 2048×1024, 2,039 X | 2.502 ± 0.988 | **3.798 ± 1.418** | **1.648 ± 0.998** | 20.338 ± 2.490 | 20.502 ± 2.172 |

The stress proxy's base writes fell from about 527 thousand to about 134 thousand
per measured tick; **wall head time nevertheless regressed 52%**. No measured
improvement in whole native tick is established. Candidate fallback frequency
was zero (gas off), so the regression is preflight/closure overhead and row
work, not an omitted fallback. The historical real-Godot 4.2 ms head cost and
~88% fallback frequency are **not** substituted for a fresh application baseline.
With gas on, the mandated global topology invalidation continues to recompute
full columns: the candidate's gas-on stress proxy has zero per-run preflight
work, providing no claimed benefit in that configuration.

## Required next correction and review gate

The immediate bounded follow-up is to profile per-X dirty rectangles and
preflight probes on the **real** `my-canvas`, `bench-canvas`, and `stress-canvas`
scenes, shorten preflight's repeated map/mask lookups or use precomputed
bounded residency/run descriptors, and add explicit accounting for every
`top_pressure` look-up. Compare release-matched compile, gas on/off, six native
workers, the same ballistic configuration and at least three warm replicates.
Only after head/final-hash parity, CYPS, wakes/certificates, full native and
Godot regression matrices, sanitizers and a **positive** head-time improvement
may this draft progress toward independent review. Even then do not merge
without owner authorization.


## Additive qualification checkpoint — 6 November 2026, 21:48 UTC

- The complete candidate native `./build/tests` run finished **PASS: 189 tests**, GCC 14.2 Linux source-matched to the pinned candidate native tree. Its 24-case, 2,400-tick per-run differential is included.
- The independently submitted stacked **Draft PR #476** is [here](https://github.com/techrote/cybersand/pull/476). The PR must remain Draft/unmerged: source/head dependency on #406 is pinned; no accepted protected-source transition or positive speedup is demonstrated.
- On candidate [GitHub Docs/provenance run 42299519412](https://github.com/techrote/cybersand/actions/runs/42299519412), the workflow scheduling inventory **PASSED** after protecting independently requested manual runs, but the MAT-AUTH shadow compatibility check **FAILED** for the edited `native/src/world_pressure.inc`: the reviewed protected source hash `26051b0d10ab10d65db822c993742e0a0bf13711f3bd56158e95d77735737aca` does not match candidate `5f01c143ebe8e7f52ab08a0b137b8fae4e3a0e9eaa6f424b67236f4b438d28a2`. **Do not refresh or weaken the guard.** A separately reviewed protected-consumer transition is required before admission.
- The Draft's routine native/Godot platform workflows are policy-suppressed; the dedicated experimental branch build supplies only its explicitly recorded targeted evidence. Neither missing routine platform runs nor documentation guard failures are represented as passes.
- Final source/CI checkout identity may advance for documentation/qualification-only commits; record the tested native tree and final PR SHA separately.

**Disposition remains REPAIR REQUIRED / PERFORMANCE NO-GO** even if all routine tests later pass, until the work budget is proved and a real workbench speedup is shown.
