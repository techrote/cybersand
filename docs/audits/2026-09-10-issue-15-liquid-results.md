# Issue 15: completed liquid characterization

Date: 2026-09-10. **Research completed locally; retain production behavior.**
The owner released the uncontended-run hold after preparation commit
`903e40f27a1c9abf2e50f1d9e5817c7855b7d21b`. The
[registration](../operations/liquid-characterization.md) and
[preparation/source review](2026-09-10-issue-15-liquid-characterization.md) remain
the inputs, including the complete eleven-liquid descriptor/exception map and
the attributed #9/#10/#13/September10 Water metrics. No old matrix was rerun.

**Finding:** sleep is part of the observed whole-cell liquid rest mechanism.
It does not explain the Water residual in these fixtures. Keeping everything
awake is costly and does not improve the tested Water trajectories. No universal
liquid solver, new mass representation or default quiet threshold is selected.

## Executed identity and validity

Worktree `C:/kybersand/worktrees/issue-15-liquid-characterization`, branch
`codex/issue-15-liquid-characterization`, originates at local `b16408c`, including
the three-quarter Water solver `8f4ffb9`. Core/harness inputs are unchanged from
the prepared executables; the completion delta is the reducer, evidence and
documentation. [Preparation manifests](issue-15-2026-09-10/preparation.json)
identify both executables, their source-file hashes, compiler and host.
Observed executable SHA256:
`df3447b98f5b7532575855a1eb922cfddfbb0998118ce9345fd7a487836b3435`.
The baseline executable uses unmodified local `b16408c` core sources and the same
fixture harness. This baseline is not the older half-difference Water solver.

Pinned Windows inputs: LLVM-MinGW Clang23.1.0, C++20/O3/NDEBUG/pthread/static;
Python3.12.14; Windows11 build26200; Ryzen5 2600X, six cores/twelve logical
processors. No compiler/build, other issue experiment or report-analysis run was
launched by this task during timing. The owner arranged contention exclusion;
the runner also rejects detected compiler/build processes. OS scheduling,
frequency changes and background service activity were not controlled or measured.

Raw prefix: `validation/local/issue-15/` inside this worktree. Per-process
`.execution.json` records command, exit, timeout180s and executable SHA256;
JSONL and stderr are retained without overwrite. `campaign.json` records the
owner release, runner hash and timing interval **21:07:28–21:14:14 UTC**.

| Validation | Result and exact scope |
|---|---|
| Full behavior screen | **352/352** processes:320 registered comparisons plus32 repeats, each1800 ticks; five signed translations/alternating mirrors, workers1/4, quiet3/4096, observer off/on |
| Timing | **224/224** processes,112 interleaved pairs, each2048 ticks; seven AB/BA pairs for each registered case and worker count; observer/source controls included |
| Quantity, conversion, allocation, overflow | Every process checks quantity each tick; no unexpected species conversion, prepared chunk/temperature allocation or histogram overflow |
| Determinism/neutrality | All80 behavior groups match matching-tick state/content/work across workers, observer off/on and registered repeats. Source and observer timing controls match semantic records; seven timing repeats per arm also match. |
| Release/exclusion | All support cases release below the shelf at tick602, remain content-stable during exclusion901..960, and resume the existing re-entry schedule. No changed catch-up policy. |
| Native and checker regressions | Preparation's55 native tests/C11 check and8 validation-checker tests remain applicable to identical core input hashes. They include Mercury policy, temperature, F01/F02, capacity and immutable snapshots; they are not relabeled as rerun in this phase. |
| Fresh platform scope | Windows native core only. No adapter/render change; no new desktop owner, browser, Web, Linux or sanitizer acceptance is inferred. |

Total new campaign: **1,092,352 ticks**, excluding the84 final preparation runs.
The [integrity manifest](issue-15-2026-09-10/completed/integrity.json) hashes all576
raw outputs and both input summary files. The reducer independently verifies
completion counts, raw hashes, quantity constancy, observer/worker/repeat groups
and timing semantic controls before emitting a report. No campaign run failed,
was discarded, or was rerun to improve its timing. Preparation failures remain
documented in their original audit.

## Normalized behavior and sleep attribution

Numbers below are medians of five translations, one worker, observer on; the
four-worker results match. Entries are **quiet3 / quiet4096**. Late means
ticks1201..1800. The [full behavior table](issue-15-2026-09-10/completed/behavior.json)
retains each translation, min/median/max, event counts and configuration. The
[selected raw traces](issue-15-2026-09-10/completed/traces.json) include release,
exclusion and re-entry boundaries with source-file hashes.

| Case | Last content-change tick | Late changed ticks | Actual visited cells | Different final content under4096 |
|---|---:|---:|---:|---:|
| Water support | 624 /624 | 0 /0 | 261 /12161 | 0/5 |
| Brine support | 1289 /1800 | 77 /527 | 702 /1740 | 5/5 |
| Paste support | 624 /1777 | 0 /36 | 35 /1740 | 5/5 |
| Slush support | 962 /1797 | 0 /159 | 36 /1740 | 5/5 |
| Mercury support | 972 /1800 | 0 /376 | 84 /1740 | 5/5 |
| Water48-wide basin | 1018 /1018 | 0 /0 | 404994 /722024 | 0/5 |
| Water96-wide basin | 1800 /1800 | 600 /600 | 726291 /726291 | 0/5 |
| Water48-unit film | 0 /0 | 0 /0 | 3 /1800 | 0/5 |

The **entire per-tick Water content trajectory**, not just the endpoint, matches
quiet3 versus4096 in all four Water fixtures at every translation. Whole-cell
trajectories differ in all20 material/translation comparisons. Every basin keeps
exact97920 Water units; Water support keeps255, film48, and each whole-cell
support fixture keeps exactly one cell. Whole-cell counts and fractional Water
units are separate ledgers; no reaction mass equivalence is asserted.

Generic mobility failures/opportunities have medians: Brine82/678 versus207/1716;
Paste10/11 versus1608/1716; Slush11/12 versus1277/1716; Mercury26/60 versus651/1716.
These count entry to the generic gate after gravity fails, not the number of
geometrically legal lateral destinations. A failed deterministic byte sample
returns before `lateral_due`, with no retry deadline. Under4096, later samples
can move the cell. There is no added stress state or constitutive yield test.
The single-cell fixture diagnoses this mechanism; it does not quantify a
macroscopic heap's angle, bearing strength or desirability.

Default first whole-world sleep ranges: Water support9..11, Paste3..5,
Slush3..14, Mercury5..21, Brine137..1333. Re-entry can wake these worlds later;
first sleep is not final rest. Water film sleeps at3 in every translation and
stays content-stable even when forced to receive1800 visits. Neither film nor
basin rest needs extra persistent motion state to explain these results.

The48-wide basin levels within the255-unit column-spread criterion in556..564
ticks (median562), then settles at46 units of spread. The96-wide basin reaches
the three-quarter-width front in250..267 ticks (median256), but still has
418..435 units of column spread (median424, **1.66 full cells**) at1800 and remains
active. Neither quiet setting reaches the255-unit leveling criterion there.
This reproduces the retained current Water finding with a different registered
translation/mirror set; it does not replace its earlier medians. The retained
half-to-three-quarter source change remains480->258 wide arrival and
1080.5->562 narrow leveling in that audit's six geometries. Optional erosion
strength changed with actual Water flux despite unchanged profile hashes; no
transport profile was retuned here.

## Work, memory and performance

The long threshold is a **diagnostic**, not a proposed production setting.
After support-fixture re-entry at961, all newly included resident blocks receive
the existing eligibility wake, including empty prepared blocks. Under4096 they
remain eligible through the horizon. Median support scheduled-core sum is71640
versus302..2475 under3; active-block sum is280800 versus810..5766. In the96-wide
basin visited cells are identical, while scheduled cores rise7162->10800 and
active-block sum21191->27000. Scheduled work and visited material work therefore
cannot be substituted for each other. This also explains why support's all-tick
cost changes much more than its pre-re-entry window.

The raw `cell_bytes` field is the existing `World::resident_cell_bytes()` query.
**Source clarification:** despite its name it includes cell, optional-temperature
and activity-block vector capacities, not just four-byte Cell payload. Here it is
1,052,672..1,644,800 bytes for16..25 prepared chunks, identical across paired
thresholds. Pure Cell payload is1,048,576..1,638,400 bytes; there is no new field.
This query excludes the pool, histogram tables, maps and process overhead.
No process-memory or hardware-counter result is claimed. Diagnostics reuse the
existing fixed256-entry job/8192-entry total tables without changing capacity.

The following are **medians of seven per-process all-tick summaries**, in
microseconds except total milliseconds. Entries are quiet3 / quiet4096;
ratios in the data file are calculated within each pair before summarization.

| Fixture / workers | p50 | p95 | p99 | Maximum | Total ms |
|---|---:|---:|---:|---:|---:|
| Water support /1 | 0.8 /869.3 | 2.7 /1328.2 | 27.0 /2005.5 | 907.2 /4476.7 | 8.16 /1120.55 |
| Water support /4 | 0.8 /388.8 | 2.4 /625.9 | 55.6 /913.8 | 588.0 /1776.0 | 8.21 /543.20 |
| Brine support /1 | 1.4 /867.5 | 27.3 /1099.5 | 65.6 /1594.1 | 1033.5 /2438.7 | 27.72 /1049.82 |
| Brine support /4 | 1.3 /389.5 | 66.5 /625.6 | 119.6 /899.9 | 610.6 /1389.8 | 47.74 /552.28 |
| Paste support /1 | 0.8 /866.0 | 2.6 /1079.4 | 25.2 /1797.3 | 1001.4 /2920.1 | 7.96 /1063.83 |
| Paste support /4 | 0.8 /388.1 | 1.5 /556.2 | 50.9 /688.7 | 548.7 /1242.5 | 7.28 /516.13 |
| Slush support /1 | 0.8 /867.3 | 1.7 /1053.1 | 25.1 /1742.7 | 915.8 /2636.5 | 6.90 /1049.22 |
| Slush support /4 | 0.8 /387.2 | 1.4 /542.8 | 47.0 /703.4 | 547.8 /1068.4 | 7.08 /510.29 |
| Mercury support /1 | 0.8 /863.0 | 15.7 /1014.6 | 36.9 /1300.3 | 935.9 /2361.2 | 9.33 /1020.38 |
| Mercury support /4 | 0.8 /385.6 | 29.0 /536.2 | 66.3 /684.0 | 567.2 /1076.1 | 10.59 /523.26 |
| Water96 basin /1 | 209.9 /209.8 | 286.9 /274.2 | 384.8 /393.7 | 725.8 /638.5 | 455.39 /452.92 |
| Water96 basin /4 | 252.3 /263.5 | 360.5 /374.5 | 507.5 /484.9 | 865.9 /1199.1 | 551.16 /571.05 |

[Complete timing summaries](issue-15-2026-09-10/completed/timing.json) preserve all
pair ratios, initial1..120, post-warmup121..600 and post-re-entry961..2048 windows,
startup samples and individual epoch-clear excesses. Raw `timing/pairs.json`
additionally retains active/sleeping subsets for every process. None of these
finite-workload windows is claimed to be stationary sustained flow. Scans,
hashing and output are outside `tick()` timing, but their cache disturbance and
per-process scheduling overhead remain limitations.

### Review of the registered flags

**85/112 pairs** exceeded15% p95 in at least one registered window or the1ms
additional epoch-excess screen. The criteria trigger review, not automatic
production acceptance or statistical significance. Every flagged pair is kept.

* All70 support quiet-threshold pairs flag. Default sleep removes work, while
 4096 allows continuing lateral samples and prolonged re-entry activity. For
 Water, additional work buys **no content improvement**. Reject4096 as a default
 replacement; this negative result does not reject material-specific future
 scheduling contracts.
* Six of14 wide-basin quiet pairs flag in at least one window. All-tick median
 paired p95 ratios are1.000 (one worker) and1.067 (four). The one-worker range
 is0.684..1.384, four-worker0.799..1.137. With identical Water trajectories and
 this variability, there is no reliable leveling benefit or universal speedup.
* Observer off/on flags2/7 one-worker and1/7 four-worker pairs across windows.
 All-tick median paired p95 increases are3.34% and4.38%; construction/reservation
 median startup rises509.0->939.7us and665.8->1072.4us. Observer neutrality is
 semantic, not zero overhead. Diagnostic tables already incur construction cost.
* Baseline-source/observed-source, both observer off, flags2/7 one-worker and4/7
 four-worker pairs across windows. All-tick median paired p95 ratios are0.854
 and1.074; four-worker maximum is1.349. Post-warmup four-worker median is1.096
 with range1.001..1.263. Identical semantic records support correctness, but
 these variable tails do not certify cost neutrality or a compiler speedup.
 Keep this instrumentation on the experiment branch; production integration
 would need a narrower repeatability/cost investigation.
* Two quiet-support pairs exceed the extra epoch-clear excess screen: Water,
 one worker,pair1, **1369.6us**; Brine,four workers,pair2, **1491.4us**. The metric
 is the difference between each arm's maximum clear-tick excess over adjacent
 non-clear ticks. Same epoch/layout, different active work and noisy scheduling
 mean it is not isolated epoch implementation cost. Both are explicit review
 failures for any blanket latency acceptance. No width/epoch policy is changed.

## Per-material decisions and G-C admission

The preparation's table remains the full quantity/kernel/lateral/delay/adhesion/
exchange/chemistry map for all11 liquids. This table supplies final dispositions;
retained reactive evidence is not mislabeled as new pure-flow measurement.

| Material | Decision from this evidence |
|---|---|
| Water | Retain FreeMass,8-bit mass,12-tick emission and48-unit adhesion. Longer wake does not change the tested flow/rest/film trajectory. Admit the narrow precision diagnostic below; do not select higher precision. |
| Brine | Retain whole-cell behavior. All five sleep pairs differ and4096 sustains late lateral movement; whether that is wanted requires an explicit material-rest requirement. No default change from a one-cell fixture. |
| Paste | Retain liked heap-capable behavior. Direct evidence of sleep-censored mobility, not a measured stress/yield law or proof of an undesirable heap. |
| Slush | Same bounded conclusion as Paste, with its own higher observed mobility. No unification with Water or Paste tuning. |
| Mercury | Retain whole cells and protected period30 powder exchange. Sleep affects empty-space lateral rest; the separate delayed-pair policy is supported by retained #10/#13 and unchanged native regressions. This support fixture contains no powder and does not remeasure permeability. |
| Oil | Retain specialized no-swap source motion/burning behavior. Retained Dust nonpenetration is intentional. Its descriptor viscosity bypass needs intent review before any tuning. |
| Lava | Retain sampled chemistry and specialized motion. Descriptor224 does not supply generic lateral mobility here; intent remains unresolved, not declared a bug. |
| Acid | Retain specialized motion, finite erosion and pair chemistry. No new corrosion or rate result; descriptor64 bypass is an intent question. |
| Cement | Retain whole-cell cure state and lifecycle ordering. Conversion quantities differ from Water mass; no transport-only conservation generalization. |
| Toxic Sludge | Retain whole cells and explicit purification. Generalized quantity is not admitted without reaction-unit/source-sink rules. |
| Molten Glass | Retain cooling/reset/quench specialization. Thermal writes can sustain activity; no new independent cooling/sleep campaign is justified by these results. |

**G-C result: retain distinct liquids and production defaults.** The conditional
research dispositions are complete:

| Next question | Gate disposition and evidence |
|---|---|
| P, issue17 precision | **Admit a bounded diagnostic, conditional on independent G-L evidence from issue16.** Target:96-wide remaining column spread418..435 at1800 versus narrow46-unit stable residue and preserved48-unit film. Exact trajectories under both sleep thresholds rule out this quiet threshold as their cause in the measured horizon. Compare normalized precision/threshold response at fixed solver/layout, with longer-time completion treated separately if needed. This does not prove that precision causes the residual or choose more bits. |
| M, compact motion/history | **No-go from C for implementation now.** No measured unmet jet/spray target; unchanged Water motion and extra whole-cell movement from longer scheduling do not justify persistent direction/velocity. A later named deficit can reopen the experiment. |
| V, fractional presentation | **C does not admit a render change.** Stable48-unit film and narrow-basin authority are usable frozen inputs, but no visual defect, orientation comparison or render-cost result was measured. Separate presentation research may test those frames under its own visual contract. No wider Cell inference. |
| General quantity/yield | **No-go for generalization now.** FreeMass and whole cells have different quantity/state/reaction contracts, and the four sampled whole-cell liquids demonstrably depend on scheduler eligibility. A future narrowly chartered material-rest question must define desired rest/mobility and reaction accounting first. |
| Production migration | **Not admitted.** Diagnostic quiet4096 fails cost screens and brings no measured Water gain; instrumentation tail-cost neutrality also remains unresolved. No merge, deployment, replacement solver or ADR change. |

This is a completed C evidence gate, not a completion claim for issue16,17 or14.
No remote issue, branch or programme mirror was mutated by this local task.

## Explicit gaps and completion checks

Generalization beyond five translations/one host and the registered geometries,
macroscopic heap/yield/pressure laws, chemistry quantities, jets/spray/visual
quality, full memory/PMU/GPU metrics, exact per-block wake-cause counts, and counts
of individual content writes remain gaps. Content hashes measure changed ticks;
BlockSleep aggregates include empty resident blocks. Stronger performance claims
need an isolated repeatability study of the flagged tails, not discarded outliers.
The intentionally unchanged serial/fallback/Web semantics are not newly certified.

Canonical synchronization covers materials, activity, Water, the experiment
runbook, programme G-C entry, roadmap, validation ledger, handover and retrieval
routes. Source identity, ownership/lifetime, interfaces, capacities, ADRs, saves
and user controls are unchanged. This completion changes no native input.

Reproduce reduction and documentation checks from the worktree with pinned Python:

```text
python tools/physics/liquid_report.py validation/local/issue-15 docs/audits/issue-15-2026-09-10/completed
python tools/physics/liquid_characterization.py gates --output validation/local/issue-15/gates-completed
git diff --check
```

The separate current repository gate retains14 published-source provenance
mismatches (seven per Windows/Linux record). The clean committed DLL in this
worktree removes the original checkout's two dirty-artifact mismatches but is not
a current runtime release. M11 hashes are preserved. Final checker outcomes and
retrieval scores are recorded in the checkpoint section below.

### Checkpoint validation and retrieval

Documentation structure/links, historical M11 integrity (18 records/28 historical
source hashes), all three retrieval evaluations and `git diff --check` pass.
The current repository check exits1 with the14 provenance mismatches described
above; that failure is retained in `gates-completed/repository.log`.
The context-aware checker uses an exact copied source snapshot plus the required
companion files, all under this worktree, without changing frozen questions or
shared workspace paths. Snapshot hashes and exact commands/exits are retained.
The final pass after the canonical admission qualifier is in
`gates-completed-final/`, with the same exits and retrieval scores.

Frozen32:22 top1/32 top5, MRR0.8281 (preparation0.8229). Existing16 challenges:
12 top1/16 top5, MRR0.8562. Programme set:5 top1/7 top5, MRR0.8571.
The six existing programme query wordings stay fixed; AP06's expected fact changes
from pending to measured evidence. New AP07 asks about the Water residual and G-C.
Manual review checks that AP06 supplies the specialized-gate/sleep qualifiers and
AP07 supplies unchanged Water trajectories plus conditional G-L/P admission,
without claiming a precision cause. Both route first to their canonical section.
AP01/AP04 still rank second. These are development-set lexical results, not
independent answer-correctness or unseen retrieval improvement claims.

The completed local commit is on `codex/issue-15-liquid-characterization`, following
903e40f; its exact hash is captured after commit in the ignored campaign checkpoint
record. The original checkout remains at b16408c with its original dirty DLL
SHA256 `fc6cb4ee1096219f581bace3df04ee8138e996aaf4c1436f5b2c071ea62dd496`.
No source checkout, runtime, save, deliverable, merge or deployment is replaced.
