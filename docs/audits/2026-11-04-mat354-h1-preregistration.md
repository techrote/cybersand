---
title: MAT354-B H1 successor correctness and performance registration
status: Planned
document-kind: evidence
scope: Frozen paired native H1 qualification plan; no runtime adoption, merge, historical evidence replacement or performance acceptance
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-mat354-correction-admission.md, 2026-11-04-mat354-findings.md, ../operations/ci-execution-and-performance.md, ../operations/profiling-observability-and-performance.md, ../operations/material-liveness-investigation.md]
---

# MAT354-B H1 successor registration

This registration is written before successor performance execution. The owner
authorizes the narrow cooling deadline correction, its explicit source transition,
tests and measurements, but has not authorized adoption or merge. The original
Phase A registration, 552-case plan, raw outputs and failed evidence remain intact.

## Frozen source and apparatus

The untouched comparison is accepted main
`751edc0b495dc85484ad5509a7c95f863651c76b`, tree
`b0d42a256285e6049a6d3bdd1613d7ecd89f43c6`. The source-only H1 successor is
`16533ff81c561677308665357eb1d0d5f65e85bc`, tree
`c0545655f190f0c9e990010873d24b1e702385a5`. Its only production delta is
`native/src/world.cpp`, inside `World::schedule_pending_reaction_wake`.

| Source | LF-normalized World SHA-256 |
|---|---|
| Untouched baseline | `b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1` |
| H1 successor | `df0bb080084972c49ca400b7bfc6504f7ec27fa474112bc2bd56abe5d3d21539` |

The [machine plan](../../native/tests/fixtures/material_liveness_h1_v1.json)
binds those identities and the unchanged Phase A manifest. The
[new C++ apparatus](../../native/tests/test_mat354_h1.cpp) includes the unchanged
Phase A probe under a renamed entry point, through an explicit source-root include
path. The same new apparatus bytes therefore compile separately against each
authenticated source without editing the baseline. Compiler depfiles authenticate
the actual included World and native headers; duplicate World compilation is
forbidden. The [paired runner](../../tools/material_cooling_h1/qualify.py) records
compiler bytes/version/flags, exact input and executable digests, Git commit/tree,
source guards, actual commands, raw bytes, exits and complete row coverage.

Qualifying execution requires clean committed checkouts and exact raw Git input
bytes. The final apparatus/plan commit is captured in each receipt. A source-only
receipt does not by itself qualify later test, checker or runtime changes.

## Correctness and source-sensitive differences

Reuse the 124 explicitly named original Phase A cases: 27,264 owner steps per
source. They cover the four phases at quiet3/1024, translated seams, source and
partner edits/removal, masking, region exclusion/re-entry, owner pause/reset,
touching hot pools, generic yielding controls, Water families, Oil/Lava/Acid/Cement,
Ice and distributed jobs. This is a selected successor comparison, not a new
552-case investigation or alteration of the historical hypotheses.

The added actual-World regressions run twice and require:

- Every thermal phase from countdown180 and zero, at quiet3/1024 and configured
  workers1/4. The quiet physical tuples follow the exact existing thermal lane;
  actual singleton kernel counters establish each required visit. Exact physical
  hashes match workers and identical repeats. No configurable seed exists:
  the preserved identity is x/y/tick/stream, not an invented seed parameter.
- Short cooling across activity/core/chunk seams and negative coordinates.
  Source writes and postconversion retirement remain bounded.
- Sub180 and181 hot reset, fixed hot180 pairs/pools, all eight visible heat positions,
  and alive/masked Spark exclusion. Equal-density MoltenGlass partners avoid
  introducing an unrelated density swap in the eight-direction control.
- A first-slot Water pair with last-slot Lava heat at `(0,96)`. The source's
  contact lane is next4 and thermal lane next2; Water is in another activity
  block. Hot180 must preserve the legitimate pair deadline4 without inventing
  thermal deadline2. This detects a pair-loop early exit truncating heat discovery.
- Shared MoltenGlass, Ice, compact-pair and Mercury obligations inside one
  activity block. Removing one source cannot erase another's required work.
- A source masked exactly at its due tick, eventual stale-deadline retirement,
  and actual cooling after unmasking.
- Same-source CYPS save/restore with an outstanding deadline, exact continuing
  physical hashes at workers1/4, and separately reported historical-source import.
- An actual down move from `(26,31)` to `(26,32)` after the old activity block
  acquired deadline4. Source/destination state and actual move counters establish
  execution; the old obligation must retire while the destination cools. The
  stationary rejection/conversion entry proxy is not an absence test for motion.
- External source replacement with Glass and actual native cooling of a heat
  partner while the other source is masked, followed by unmasking and cooling.

Within each source, unchanged execution settings must reproduce complete physical
hash sequences across workers and repeats. Non-MoltenGlass control sequences must
also match between sources. Quiet1024 MoltenGlass physical tuples must match the
historical awake control even though source-qualified scheduling hashes may differ.
The converted Glass and already-hot180 pool are exact whole-trajectory controls.
The hot pair/hot Lava fixtures retain exact physical tuples. Singleton cold/edit
rows must independently follow the existing thermal law on every actual visit,
with no off-lane change and explicit pause/mask/region boundaries. Their first
tuple divergence must be a restored due-lane visit, absent from the baseline,
after a retained finite deadline. This is not a blanket MoltenGlass exemption.
Changed aggregate/distributed or multi-source edit trajectories are explicitly
`REVIEW_REQUIRED` until independent per-source causal review; `EXECUTED` reports
completed processes without declaring those cases qualified. Complete new-test
physical trajectories must also match between both process repeats. An endpoint
image alone establishes no kernel execution.

The original runner's independent domain/ledger census remains active in reused
cases. It closes actual Water quantity and separately accounts for permitted
chemical products and external edits. Observed worker claimants must exceed one
in the four-worker distributed cases; configuration alone is insufficient.

## Saved-state boundary experiment

Export an untouched baseline phase0 singleton at `(11,8)` after8 ticks. Import
those exact CYPS bytes into the successor and observe1024 unaltered ticks. Record
whether the old state is accepted, its old active/deadline state, actual jobs and
cooling progress. Then apply one separately labelled existing region-exclusion/
re-entry intervention and observe768 ticks. This intervention is not automatic
migration, a changed save format, source authentication or strict replay.

If an accepted historical snapshot remains asleep without a successor deadline,
report that as an adoption limitation requiring an explicit compatibility decision.
Do not edit serialized bytes, inject a deadline, change the old oracle or imply
that unchanged catalogue/ABI identities establish cross-source continuation.

## Performance cohorts fixed before timing

Use the same compiler executable and `-O3 -DNDEBUG` flags for both sources, with
no cross-translation-unit LTO. Run on the same observed host/settings. For each
workload and configured workers1/4, execute five paired repetitions, alternating
baseline/successor then successor/baseline order. Preserve all outliers. Do not
run other owned builds or benchmark work concurrently with this timed cohort.

| Workload | Construction and purpose |
|---|---|
| Empty | 32 pre-reserved empty chunks; reveal added idle work |
| Inert | Eight separated sealed Wall rooms; quiet/idle control |
| Cold1, Cold16, Cold64 | Enclosed isolated countdown180 cells, with separated cells in distinct cores of the same scheduler phase and fixed, source-derived thermal phases; measure finite scaling and actual claimants |
| Hot180 | Original sealed12×12 fixed-point pool; reveal permanent activity |
| Mixed | 32 separated rooms cycling isolated cold, touching hot, Ice/Water and Water/Salt; expose shared scheduling interactions |
| Ice pair, compact pair | Eight separated existing Ice/Water or Water/Salt contacts |
| Water FreeMass, CY, PressureFlow, IN | Original source-owned three-cell protected-liquid constructions; IN uses required radius3 |
| Paste | Original generic yielding rest witness; H3 control |

Each measured World runs1024 ticks after a separate, identically configured
throwaway World warms32 ticks. The measured cold source retains its full180
countdown. Retain all ticks; also report active ticks and fixed tail769–1024.
The tail must have zero jobs for empty/inert/hot180 and corrected cold cohorts.
No assertion that every mixed or other-liquid control has the same settling time
is introduced. Deadlines and geometry are not tuned after observing results.

Time only `World::tick` with a monotonic wall clock; record a POSIX process CPU
clock separately, including worker CPU and its explicit `CLOCKS_PER_SEC` nominal
resolution. CPU per-tick mean/median/p95/p99/max retain that coarse resolution;
zero samples are reported as measured rather than replaced by wall times. CPU
clock values remain unavailable on Windows. Array allocation, JSON output, census,
hashing, deadline inspection and observation occur outside the timed tick.
Report monotonic elapsed wall time from the first measured tick to the first
Glass observation separately from the sum of timed tick intervals up to that
conversion. The elapsed value includes between-tick observation/clock overhead;
the cumulative tick cost does not.
The primary timed cohort disables diagnostic histograms. One separate diagnostic
work replay per source/workload/worker configuration records actual material
entries and conversions; its timing is never pooled with the primary cohort.
The diagnostic replay must preserve the same physical result.
All benchmark workloads except admitted cold/mixed workloads must preserve exact
baseline/successor final physical and tuple identities. This is a final-state
benchmark check; the separate correctness controls retain complete trajectories.

Report per-run mean, median, p95, p99 and maximum tick time; variance and range of
run medians; baseline/successor absolute deltas and ratios; work/active blocks,
selected visits, scheduled jobs, actual claimants, conversion tick/time, observed
block-deadline changes, allocations and resident capacity. Block observations
do not count every coalesced request. Whole-World material entry counters are
cell-specific only in singleton cases; unobservable per-cell thermal/off-lane
counts remain unavailable. `TickStats` counts chunk/temperature allocations only,
and `resident_cell_bytes` excludes hash nodes, scheduler buffers and total RSS.
Neither metric is represented as complete heap or process-memory accounting.

## Acceptance policy and bounds

The [current CI policy](../operations/ci-execution-and-performance.md) supplies
advisory timing warnings, not an H1 adoption threshold. The
[profiling contract](../operations/profiling-observability-and-performance.md)
requires comparable repeats and representative-hardware acceptance. No numerical
H1 performance threshold is defined. **An explicit owner performance disposition
remains necessary before adoption**, even if the measured finite work is bounded.

Retain the inherited900-second build,60-second process and1800-second campaign
bounds. A timeout, incomplete/raw/source mismatch, quarantine, quantity failure,
unexplained control change, worker/repeat mismatch, missing actual distributed
claimants, permanent cold/fixed-hot tail activity, new tick-time chunk/temperature
allocation or resident growth fails this bounded qualification. Do not relax an
oracle or resource bound after a failure. Newly corrected apparatus receives a
new source and attempt while retaining the original failed output.

Ordinary native execution is distinct from ASan/UBSan, TSan, actual Windows,
Godot/GDExtension, LFS publication, full CI and independent review. A failed or
unexecuted required gate keeps adoption blocked; this apparatus grants none of
those results by inference.

## Publication identity reconciliation

The original preregistration and local execution are immutable at
`9d218bb179e72e9fa68b755d82680dbd739fb85e` (tree
`d025ee050b8c782873161443428f804dd1622cfb`), with local source-only ancestor
`ca11dd4f4a98e819ed043a19fd63bf2ac89810b1`. Direct shell push lacked GitHub
credentials. Authenticated Git-data publication produced source-only commit
`16533ff81c561677308665357eb1d0d5f65e85bc`, with exactly the same source tree
`c0545655f190f0c9e990010873d24b1e702385a5`, parent and World bytes. The
[explicit mapping](2026-11-04-mat354-publication-identity.json) retains both
authorities. This published registration changes only the Git source anchor;
all workloads, fixture geometry, repeats, bounds, comparison oracles and
performance policy remain unchanged. Original local receipts retain their actual
HEAD and apparatus hashes. Fresh published-source identity checks and compiled
input/binary equivalence are required before transferring any conclusion.
