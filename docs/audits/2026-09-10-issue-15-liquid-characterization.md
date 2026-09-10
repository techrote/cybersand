# Issue 15 liquid characterization: preparation checkpoint

Date: 2026-09-10. **Preparation, not completed experiment acceptance.** The owner
requested a stop before performance measurements because issue #16 may be active.
The [registration](../operations/liquid-characterization.md) predates new
instrumentation/results and owns the sample budget, metrics and rejection gates.

## Source and workspace identity

Local baseline `b16408c` includes `8f4ffb96e03dc50cb43ab9c84de17ccb44c03774`
(three-quarter Water) and #9/#10/#13. A new worktree and branch were created with:

```text
git -C C:/kybersand/source worktree add -b codex/issue-15-liquid-characterization C:/kybersand/worktrees/issue-15-liquid-characterization b16408c
```

The baseline checkout remains on `codex/architecture-programme`; its only intake
delta was the Windows DLL, SHA256
`fc6cb4ee1096219f581bace3df04ee8138e996aaf4c1436f5b2c071ea62dd496`.
This worktree materialized all 18 committed LFS payloads, including the older
committed DLL. That is a source-control identity check, not a current runtime.
No DLL, export or user session in the original checkout is replaced. No merge,
deployment or remote mutation is part of this issue. The local preparation
commit is recoverable on `codex/issue-15-liquid-characterization`.

## All eleven liquid paths, inspected at the planning baseline

Sources: [descriptors](../../native/include/cybersand/material.hpp),
[World::update_rule_kernel/update_water/lateral_due](../../native/src/world.cpp),
[pair reactions and exchange eligibility](../../native/src/material_rules.cpp).
All eleven have downward density motion and accept target-side exchange. That
does not guarantee a source kernel attempts swaps. Vertical density eligibility
also rejects equal density and horizontal swaps. Whole-cell moves preserve the
two compact bytes and optional temperature; their count is **not Water mass**.

Pair chemistry is sampled on its four-tick lane before kernel dispatch. If it
reacts, it writes descriptor-initialized products and returns without motion.
Additional kernel-specific chemistry can occur before or after movement; Acid's
erosion, for example, follows failed motion. No universal conserved reaction
quantity follows from these rules.

| Material / ID / density | Quantity and kernel exception | Executed lateral mechanism; descriptor viscosity | Delay/adhesion, exchange/chemistry | Evidence status and decision |
|---|---|---|---|---|
| Water /3/1000 | Fractional state_a1..255; FreeMass; Empty is zero | Adjacent three-quarter imbalance, tolerance1; viscosity0 scales mass request | state_b12 emission, max merge, pre-decrement suppression; supported film<=48; directional exchange; Lava/Fire/Salt/Sodium/Sludge/Molten Glass pair rules | Retained current basins/films; sleep pair absent. Preserve specialization; isolate residual before admitting precision. |
| Lava /8/2600 | Whole cell; Lava kernel | One chosen lateral candidate after down/both diagonals; descriptor224 **does not gate this path** | No Water delay/film; sampled ignition/Ice melt; Water quench and Glass melt; vertical exchange | Retained #10 pair coverage; specialization effect on lateral cost absent. Preserve; flag descriptor/implementation mismatch for later intent review, not retune. |
| Acid /12/1050 | Whole cell; state_a255 corrosion strength; Acid kernel | Down/one diagonal/one lateral; descriptor64 **does not gate this path** | No Water film/delay; sampled erosion after failed moves, strength decrement24; Metal pair reaction; vertical exchange | Retained #10 pairs and #13 Metal gallery; closed pure flow sleep attribution absent. Preserve chemistry scope. |
| Oil /16/800 | Whole cell; state_b burning; Oil kernel | Down/both diagonals/one lateral, swaps disabled; descriptor160 **does not gate this path** | No Water film/delay; ignition, extinguish, burn/emission; Spark pair; source Oil/powder veto also explicit in policy | Retained #9 nonpenetration and #10 pairs; intentional protected exception. No universal solver conclusion. |
| Paste /20/1300 | Whole cell; generic YieldingLiquid | After failed gravity, mobility16/256 then up to two empty lateral candidates; viscosity240 | No constitutive stress/yield field, no Water film/delay; no direct pair reaction; vertical exchange | Retained #9 Dust penetration/#10 pairs; sleep-censored mobility unresolved. Preserve liked heap behavior pending paired support fixture. |
| Slush /21/1080 | Whole cell; generic YieldingLiquid | Mobility64/256; viscosity192 | No Water film/delay or direct pair rule; vertical exchange | Retained #10 pairs; paired sleep/heap attribution absent. Same conditional decision as Paste, separate outcome required. |
| Brine /24/1120 | Whole cell; generic YieldingLiquid | Mobility224/256; viscosity32 | No Water film/delay; Sodium and Fire pair reactions; vertical exchange | Retained #9/#10 pairs; selected mobile whole-cell control for new sleep comparison. No fractional quantity equivalence assumed. |
| Cement /30/2600 | Whole cell; state_a180 cure; Cement kernel then generic flow | Mobility80/256; viscosity176; lifecycle writes can extend activity | No Water film/delay; two-tick cure lane, rate4 Water/Brine,2 Concrete,1 air; becomes Concrete | Retained #10 reactive pair evidence; transport-only count test insufficient. Preserve cure specialization; no new cure tuning. |
| Toxic Sludge /32/1050 | Whole cell; generic YieldingLiquid | Mobility192/256; viscosity64 | No Water film/delay; Water purification pair creates Water; vertical exchange | Retained #10 pairs; reaction quantity contract missing. Do not generalize FreeMass without units. |
| Mercury /33/13500 | Whole cell; generic YieldingLiquid | Mobility160/256; viscosity96 | No Water film/delay; no direct pair reaction; powder exchange period30 with explicit deadline wake, ordinary void movement full rate | Retained #10/#13 protected references; selected sleep control, not a changed permeability candidate. |
| Molten Glass /36/2500 | Whole cell; state_a180 cooling; specialized then generic flow | Mobility32/256; viscosity224; thermal changes can extend activity | No Water film/delay; four-tick cooling, reset by Fire/Lava/Molten Glass, becomes Glass; Water pair quench | Retained #10 pair evidence; isolated cooling/sleep ambiguity remains. Preserve specialization; no claimed general liquid rest equivalence. |

The fractions above describe the range test on the existing deterministic byte,
not a probabilistic independence claim. Generic failure returns without a wake
deadline. `lateral_due` is called **after** that gate, so optional cadence does
not itself rescue a cell whose failed mobility samples let its block sleep first.
At default cadence1 it always returns true. Neighbor writes, shared block activity,
chemistry and region re-entry can change which later opportunities occur.
Calling this a measured universal premature-sleep defect would be unsupported.

Useful specialization: Water quantity/film/emission, protected Oil nonpenetration,
Mercury pair deadlines, and material reaction state. Possible historical mismatch:
Lava/Acid/Oil viscosity descriptors bypassed by specialized motion. Actual intent
behind those descriptor values is unresolved; source inspection cannot classify
it as an accidental bug. Paste/Slush heaps are explicitly liked, while the share
attributable to sleep remains an experimental question.

## Retained evidence and minimum missing measurements

All metrics below are **retained**, not fresh issue15 runs. Each linked audit
owns its dated command/artifact/source manifests and failures. Inputs are local;
the issue URLs in the implementation prompt are attribution, not new remote scope.

| Dimension | Attributed retained result | Sufficiency for this issue |
|---|---|---|
| Ordered exchange/confinement | [#9](2026-09-09-physics-characterisation.md), `ab4851e` plus diagnostic delta (committed10e8153): Mercury/Sand32-cell passage32 ticks, viscosity96/160/224/248 identical state; Oil declines Dust exchange | Sufficient causal evidence that viscosity is not the vertical permeability control; obsolete current Mercury rate. No rerun. |
| All liquids and protected Mercury | [#10](2026-09-09-issue-10-granular-policy.md), source through372bfb3:198 cases=11 liquids x9 powders x2 orders, one translation; period1/10/30/60 breakthrough32/320/960/1920 ticks, 62 permeability cases | Coverage retained; current protected period30. One translation does not settle sleep/mobility in all liquids. |
| Quantity and chemistry | #10 has119 nonreactive Water controls and26 Water reaction cases; species counts balanced against conversions; #9 open-crop outflow separately identified | Retained closed accounting; conversions are not conserved chemical mass. No generalized quantity contract. |
| Opt-in transport | [#13](2026-09-09-issue-13-transport.md), through4bead55:480 corrected sampling runs with384 reused/96 rerun;60 exact default references; horizontal2/cadence1 retained | Preserve old Water source qualifier, failed injector ledger, depth limitations and shared-host timing. Does not isolate current sleep. |
| Current Water flow | [Water follow-up](2026-09-10-water-leveling.md), 4bead55 plus three-quarter delta committed8f4ffb9:24 cases per implementation, exact97920 units each tick;96-wide arrival480->258 ticks;48-wide leveling1080.5->562; tick1800 spread1076->425 wide and57->46 narrow | Sufficient current front/leveling fact. Wide spread remains1.67 full cells and neither wide variant meets255 by1800. Precision versus transport/sleep unresolved. |
| Current Water work/cost | Same Water report: narrow visited714316->406306, active-block sum11328->6391; wide730615.5->726517 and18220->17991; p95 narrow290.8->279.7us, wide304.65->334.8us | Work retained; timing **insufficient** for attribution due overlapping builds/checks. New isolated paired cost required. |
| Solver/profile identity | Current Water baseline carried mass18078720/18024029 ->28296903/28414321; Erosion pickups71/89 ->428/508 packed/loose, same profile hash | Sufficient evidence that current flux alters pickup. No opt-in tuning in issue15. |
| Stable film/rest, state/temperature, boundaries | Current Water native55/55 and #13 signed seam tests; Water follow-up30 exact Mercury/powder references,24 Godot fixtures,72 native/Web transport cases | Retained regressions. No new Web/desktop acceptance; single-cell film pair isolates extra visits from motion. |
| Sleep versus mobility, release and late work | Generic early return and block quiet policy inspected; no controlled3 versus4096 retained matrix found | **Absent**, registered new support-release and film/basin pairs. No outcome assumed. |
| Uncontended p50/p95/p99/max/total and epoch excess | Existing shared-host timing lacks registered seven-pair isolation | **Absent**, owner hold. At least2048 ticks and explicit windows registered. |
| Work/memory | Existing TickStats distinguishes visited cells/cores/active blocks, tracked allocations; histograms fixed256/8192 | Retained implementation; new per-case counts pending. Process memory, PMU, GPU and exact wake-cause counts explicit gaps. |

## New preparation and validation

New modules: [CLI](../../native/bench/liquid_characterization.cpp) and
[runner](../../tools/physics/liquid_characterization.py). The only native rule
delta adds diagnostic counters for generic mobility opportunities/failures and
block sleep. It reuses existing optional histograms and random samples; no
simulation setting or descriptor default is changed. Old event IDs stay stable.
Reference source is recovered using local `git show b16408c:<path>` into the
issue-specific build directory, then compiled with the same new fixture harness.
The candidate and reference executables stay separate. No shared bindings build
or extension deployment is needed for these core observations.

Commands from the worktree, with pinned
`C:/kybersand/.local/python/Scripts/python.exe`:

```text
python tools/physics/liquid_characterization.py prepare --build build/issue-15/final --output validation/local/issue-15/prepare-final
python tools/physics/liquid_characterization.py smoke --build build/issue-15/final --output validation/local/issue-15/smoke-reproduction
```

`prepare` uses pinned LLVM-MinGW Clang23.1.0, C++20/O3/NDEBUG/pthread/static,
300-second compile timeout, sequential builds and a read-only competing-builder
check. Source inputs, compiler and executable SHA256s are in
`build/issue-15/final/{baseline,observed}.manifest.json`. Every execution preserves
command, exit, timeout, stderr and raw JSONL, and refuses to overwrite earlier
runs. Build-input hashes are rechecked before running. Behavior mode never reads
the tick clock. Existing binaries/runs are retained: choose a fresh build/output
directory when rebuilding/repeating. The earlier executables remain in
`build/issue-15/`; final startup timing stops before metadata output. That clock
boundary correction changes no behavior-mode result.

### Clock-free preparation results

Final source passes **55/55 native tests** plus the C11 header syntax check,
using the pinned workspace Make recipe with `BUILD_DIR=build/issue-15/tests`
and explicit Clang C/C++ paths. Timeout600s; raw log/command is
`validation/local/issue-15/native-v2/`. Includes the existing protected Mercury,
Water/temperature, allocation, failure, region and snapshot regressions.
Eight validation-checker contract tests pass separately in `checker-tests/`.

The final support/film controls pass **72/72 processes**, 1800 ticks each, under
`smoke-final/`: two quiet thresholds, observer off/on, workers1/4, and unmodified
baseline-source controls. The additional two basin geometries have12 preparation
processes in `basin-preparation/`. The `smoke` command now reproduces both groups
in one84-process invocation. Initial72-process output in `smoke/` is retained
separately, not counted twice. Every run checks exact quantity every tick, zero
unexpected conversion/allocation/overflow, exclusion immutability and release.
Matching-tick content/state and work records match workers, observer off/on and
unmodified source within each quiet setting. Generic positive/failure observations
and film sleep counters are present. These are fresh Windows core results,
not desktop/Godot/Web execution or a completed five-translation screen.

[Curated preparation data and source/artifact manifests](issue-15-2026-09-10/preparation.json)
retain the selected traces' summaries and hashes of the complete raw result
tables. Final observed CLI SHA256 is
`df3447b98f5b7532575855a1eb922cfddfbb0998118ce9345fd7a487836b3435`.
Host: Windows11 build26200, AMD Ryzen5 2600X (6 cores/12 logical processors),
Python3.12.14. The translation0 basin controls reach the one-cell spread criterion
at561 ticks (width48); width96 does not reach it by1800, and front arrival is250
ticks. Those individual values must not be substituted for the retained
six-geometry medians. All six executions per width match; no tick cost is recorded.

Selected final translation0, one-worker observer-on values; four-worker records
match. `none` means the **whole world** never reaches zero resident active blocks;
individual blocks can sleep earlier. All support cases descend below the removed
shelf at tick602 (the input edit is before601). Late-change ticks exclude the
external shelf deletion. BlockSleep counts include prepared empty resident blocks,
so they must not be read as liquid cell counts.

| Case | First zero-active tick, quiet3 /4096 | Last content-change tick, quiet3 /4096 | Visited cells, quiet3 /4096 | Generic mobility failures/opportunities, quiet3 /4096 |
|---|---|---|---|---|
| Water support | 9 /none | 624 /624 | 289 /13897 | 0/0 /0/0 |
| Brine support | 395 /none | 1384 /1800 | 939 /1740 | 125/915 /207/1716 |
| Paste support | 3 /none | 624 /1772 | 33 /1740 | 9/9 /1601/1716 |
| Slush support | 3 /none | 962 /1797 | 36 /1740 | 10/12 /1285/1716 |
| Mercury support | 11 /none | 976 /1800 | 112 /1740 | 27/88 /626/1716 |
| Water48-unit film | 3 /none | 0 /0 | 3 /1800 | 0/0 /0/0 |

The single-translation result supports **scheduler-dependent whole-cell rest**:
Paste's default world receives only failed lateral samples, while the same
unmodified solver under4096 later moves. Supported film content remains identical
under both thresholds despite many additional visits. Water support ends with
identical content in both; the four whole-cell controls end differently. This
neither proves an unwanted heap nor supplies a physical yield law. Broader signed
translations, basin sleep pairs, repeat screen and cost remain pending.

### Documentation gates, failures and limits

Direct worktree docs checking initially reported six missing companion expected-
fact paths because frozen questions assume `source/` immediately below the
workspace. No frozen question or checker was rewritten to suppress this. The
runner's `gates` action copies exact working source and the five referenced
companion files into an issue-local validation context, records hashes, and
passes that root to the existing checkers. It writes nothing beside other
worktrees. Initial failed outputs remain in `gates/`.

Context-aware docs and historical M11 checks pass (18 retained records/28 source
hashes). The repository gate reports **14 current published-source provenance
mismatches**, seven per Windows/Linux record. The intake's16 included two dirty
DLL byte/LFS mismatches; this worktree has the clean committed DLL, so those two
do not apply. This does not repair publication or certify that committed DLL as
current. Historical hashes remain unchanged.

Frozen32 retrieval:22 top1/32 top5, MRR0.8229; prior retained Water checkpoint
was23/32 and0.8385. Existing16 challenges:12 top1/16 top5, MRR0.8562. Programme
set now6 with new AP06:4 top1/6 top5, MRR0.8333. AP06 retrieves the canonical
specialization paragraph first; manual review confirms the failed-mobility and
pending-screen qualifiers. Prior five-question wording is unchanged. This is
development-set routing, not an unseen retrieval improvement claim.

The first native Make invocation failed on its Unix `mkdir -p` recipe under the
Windows shell before compilation. Precreating the issue-specific build directory
allowed the unchanged test recipe to run; `native/` retains the failed attempt.
A final build attempt correctly refused while native Make was still running;
the successful final build followed its completion. No competing process was
stopped. No performance measurements were made during preparation.

Final documentation command:

```text
python tools/physics/liquid_characterization.py gates --output validation/local/issue-15/gates-final
git diff --check
```

`gates-final/` preserves commands, exits, exact context input hashes, all three
retrieval reports and the14-error repository result. The final diff check passes.
The original checkout's DLL is rehashed at final checkpoint; no generated
runtime, test binary, raw log or companion toolchain is committed.

## Remaining execution and G-C

After the owner releases the performance hold, run the full behavior screen
before timing, using fresh output directories:

```text
python tools/physics/liquid_characterization.py screen --build build/issue-15/final --output validation/local/issue-15/screen
python tools/physics/liquid_characterization.py timing --build build/issue-15/final --uncontended --output validation/local/issue-15/timing
```

The timing flag is an explicit release mechanism, not automatic evidence of an
idle host; arrange no other experiment/build first. Do not run timing while issue
#16 is measuring. Report all paired distributions and diagnostic overhead, then
complete the normalized side-by-side table, sleep/late-work interpretation and
per-material gate notes. Preserve negative and ambiguous outcomes.

**G-C pending:** no precision, memory, rendering or generalized quantity/yield
migration admitted at this checkpoint. The specific possible precision question
is the retained96-wide residual; no evidence yet assigns it to bit precision.
No measured jet/spray deficit admits memory. Separate frozen-state presentation
research can be discussed without claiming a simulation benefit. Keep existing
liquid specialization; any new quantity model needs explicit reaction units.
Issue15 is deliberately unfinished at the requested measurement boundary.

Documentation synchronization: material/activity contracts link the mechanism
distinction and experiment; programme, roadmap, validation ledger, handover and
retrieval routes link this preparation state. No changes to ownership/lifetimes,
adapter/C API, capacity defaults, ADRs, saves or user controls. Existing counter
storage is reused; three additive diagnostic event IDs are the only diagnostic
schema extension. Historical M11 and published runtime identities stay intact.
