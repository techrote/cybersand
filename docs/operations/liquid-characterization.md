---
title: Liquid characterization registration and reproduction
status: Current
document-kind: runbook
scope: Registered and completed issue 15 research comparison; findings do not approve production changes
canonical-for: [liquid-characterization-experiment]
last-reviewed: 2026-09-10
related-documents: [architecture-programme.md, ../systems/materials-and-rule-kernels.md, ../audits/2026-09-10-issue-15-liquid-results.md]
---

# Liquid characterization registration

Registration date: 2026-09-10, before observation code or new fixture results.
Baseline is local planning commit `b16408c`, including solver commit `8f4ffb9`.
Editing workspace: `C:/kybersand/worktrees/issue-15-liquid-characterization`,
branch `codex/issue-15-liquid-characterization`. Build products and raw logs use
`build/issue-15/` and `validation/local/issue-15/` inside this worktree.
The owner initially required a stop before performance so issue16 could be made
idle, then released that hold. Preparation903e40f and its dated audit are retained
separately from the [completed results](../audits/2026-09-10-issue-15-liquid-results.md).
The sample budget below was registered before the corresponding results.

## Does keeping Water awake fix its residual leveling?

**Measured Windows core, 2026-09-10:** no difference in the entire Water content
trajectory for quiet3 versus4096 in both basins, support-release and film, across
five translations and workers1/4. The96-wide basin still has418..435 units of
column spread at1800 ticks and remains active; the48-wide basin settles at46.
The48-unit supported film remains immutable despite extra visits. Longer wake
therefore does not fix the residual in these fixtures. This does not prove that
precision is its cause. Brine/Paste/Slush/Mercury whole-cell trajectories differ
in every paired translation, establishing scheduler-dependent rest without a
constitutive stress/yield model. Production defaults remain unchanged.

The completed campaign has352 behavior processes and224 timed processes.
Observed tail variability and costly post-re-entry scheduling prevent a universal
performance or cost-neutrality claim. The dated report owns the full windowed
timings,85 flagged pairs, exceptions and separate publication gate.
G-C retains defaults and conditionally admits only the bounded P precision
diagnostic after independent G-L evidence; it selects neither a bit budget nor
liquid unification. The final dispositions below name the other no-go branches.

## Question and controlled variables

Does stopping ordinary scheduling after three quiet ticks censor subsequent
deterministic lateral mobility opportunities? Compare fresh worlds with quiet
thresholds **3 and 4096**. Zero is invalid; 4096 exceeds both registered horizons.
No mobility, viscosity, reaction, relaxation, profile, adhesion or default changes.
There is no stress field. A successful move after a failed mobility sample under
4096 is evidence of scheduler dependence, not proof that heap behavior is unwanted.

Fixed: phased traversal, 128/32/64 geometry, radius 2, four-byte Cell, Water
mass 255, film 48, coherent delay 12, three-quarter relaxation, default transport
(horizontal 2/cadence 1, carrying/mixing off), Mercury period 30. Workers 1/4.
Five translations `-129,-65,0,63,127` select the existing coordinate/tick streams;
there is no independently seeded PRNG. Mirror alternates with translation index.
All paired worlds receive identical input and inclusion schedules.

## Registered missing cases and budget

| Case | Materials | Input and primary observations |
|---|---|---|
| Closed support-release ledge | Water, Brine, Paste, Slush, Mercury | 48-wide, 48-high closed Wall box; one cell on a full-width shelf at y23, remove shelf before tick601; exclude before901, re-enter before961. Lateral opportunities/failures, last content-change tick, first release descent, rest/wake trace, exact quantity each tick. Inclusion fixed within each pair; this transition case is separate from fixed-inclusion basins. |
| Existing basin geometry | Water | Mirror 48/96-wide, 12x32 full cells, walls y0/47 as existing water_leveling. Fixed inclusion. Front reaching 3/4 width at >=128 column mass, column spread <=255, rest, work. Reuse retained ordinary-threshold results; new pairs isolate sleep. |
| Supported film | Water | Single 48-unit cell above closed floor y47; no intervention. Exact mass, immutable content, sleep versus continuing visits. Partial quantity has no asserted whole-cell equivalent. |

Behavior: 8 material/fixture combinations x 5 translations x 2 workers x 2
thresholds x 2 observers = **320 processes**, 1800 ticks each. Repeat observer-on
cases at translation0 for both workers/thresholds (32 processes). Retain full
per-tick records, not only winning translations. No old #9/#10 matrices rerun.
Preparation may execute translation0 support/film correctness controls only;
these have **no tick clocks** and do not substitute for the full screen.

Preparation extension registered before execution: also check both reused basin
geometries at translation0/quiet3, workers1/4 and observer off/on plus baseline
source off (12 processes). This checks that the copied fixture geometry and
accounting are runnable before the performance handoff; it is not a new sleep
matrix. Support/film preparation has72 processes including baseline-source
controls. Final preparation therefore has84 clock-free processes.

Timing after owner releases the hold: support-release for the five materials
plus 96-wide Water, translation0, workers1/4. Seven interleaved process pairs per
case, alternating AB/BA, A=quiet3/B=quiet4096, **168 processes**. Observer disabled.
Run another seven pairs on 96-wide Water for each worker, quiet3, observer off/on
(28 processes). Baseline-source versus instrumented-source observer-off on the
same basin adds 28 processes. **224 timed processes total**, 2048 ticks each.
Stop on any correctness failure; keep failed/outlier output. Compilation timeout
300s, behavior/timing process timeout180s; whole campaign budget2h. No automatic
larger finalist: register a specific ambiguity before expanding.

Report initial ticks1..120 separately. Ticks121..600 and961..2048 are separate
post-warmup windows, excluding release/pause/re-entry transition ticks601..960.
These finite workloads can settle: call the windows post-warmup, never assert
stationary flow merely because 120 ticks elapsed. Report sleeping and active
subsets, p50/p95/p99/max/total tick microseconds and all-tick cost. Timing encloses
only tick(), with scans/hashes/output outside; their cache disturbance remains a
limitation. Startup construction/reservation is timed separately. Epoch clears
occur at ticks256,511,...; compare excess over adjacent non-clear ticks, screening
>1ms additional excess. Flag >15% paired p95 regression, using per-pair ratios
and reporting every pair; these are research review thresholds, not production limits.

## Observation contract and rejection criteria

Reuse fixed PhysicsDiagnostics histograms and TickStats. New observer events may
count entry to the generic lateral mobility gate, its failed sample and block
sleep transitions. LateralProbe already counts candidate probes, not successful
motion; WaterTransfer counts transferred **mass units**, EmptyMove/DensitySwap
count whole-cell operations. Generic mobility events do not cover specialized
Oil/Acid/Lava (they have no such gate). Record scheduled cores, actual visited
cells, resident active blocks, tracked allocations, histogram overflow and
resident Cell bytes. Net active-count changes do not count every individual wake;
precise wake-cause attribution remains an explicit gap unless separately added.

Per-tick content hashes identify **ticks with content changes**, not a count of
individual writes or a complete replay state. Trace before input edits so shelf
removal does not masquerade as solver motion. Compare matching-tick state and
content for same configuration, observer on/off, repeat and workers1/4; compare
content/normalized quantities across quiet thresholds, since state_hash includes
the threshold. Exact nonreactive species counts and Water totals must hold every
tick, including pause and re-entry. Track compact bytes and temperature via content
hash and retained focused regressions. Reject data on conversion, quantity loss,
observer-induced semantic change, unprepared chunk/temperature allocation,
histogram overflow, timeout or unmatched control. Record every rejection.

Capacity: maximum/reserved initial chunks64, active chunks64, active cores512,
reserve a 512x512 region around each fixture. Existing histogram capacities256
per job/8192 totals remain fixed. No new field, worker allocation or mutable
snapshot interface. Full memory/PMU/GPU measurements remain gaps; the legacy
`resident_cell_bytes()` query includes cell, optional-temperature and activity-block
capacities, not process memory. No adapter/render changes require new platform
builds at preparation; native diagnostics do not establish fresh Web acceptance.

## Conditional dispositions

**G-C completed:** retain separate liquid paths and production defaults. Admit P's
bounded normalized precision/threshold diagnostic for the residual and film target,
conditional on independent G-L evidence from issue16. No precision cause or bit
budget is selected. M has no admitted jet/spray deficit; V has no new visual or
render-cost evidence; generalized quantity/yield lacks reaction units and a named
unwanted material behavior. Those implementation paths have explicit no-go
dispositions from C. Frozen-state presentation research may still use the stable
film/basin inputs under its own visual contract. No production migration is
admitted. See the [complete per-material decisions](../audits/2026-09-10-issue-15-liquid-results.md).

Reproduction commands and executed outcomes are recorded in the
[dated preparation audit](../audits/2026-09-10-issue-15-liquid-characterization.md).
