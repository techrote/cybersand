---
title: Water state precision experiment registration
status: Current
document-kind: runbook
scope: Preregistered Issue 17 P1 mass, P2 threshold and P3 delay experiments on one fixed experimental carrier
canonical-for: [state-precision-experiment]
last-reviewed: 2026-09-11
related-documents: [architecture-programme.md, architecture-programme-prompts/state-precision.md, ../systems/water-design.md]
---

# Water state precision experiment

## Registration before candidate code

Recorded September 11, 2026. Source is f3fb9de2c6e62907b07b50c7036af389da67d4a5,
the published programme reconciliation, in C:/kybersand/source. Experiment branch
codex/issue-17-state-precision is a separate worktree at
C:/kybersand/worktrees/issue-17-state-precision. No source delta at branch creation.
Origin is techrote/cybersand; remote main remains ab4851e9e6a3ee182aba1a31a8f66d135e87df3a.
Connector identity is techrote; local gh has no authentication. Git remote refs
match completed C cdb4c2a and L 4726f8d. Baseline DLL SHA-256 is
fc6cb4ee1096219f581bace3df04ee8138e996aaf4c1436f5b2c071ea62dd496; it stays untouched.
Both prior experiment worktrees are clean. Workspace has untracked worktrees/.

G-C found identical Water quiet3/4096 trajectories in its horizon: sleep does not
explain those residuals. No sleep campaign is repeated. G-L validates carriers,
not production width: current4 remains baseline pending G-final, widening costs
memory, packing has no universal winner, short epoch is not selected, optional
storage is density dependent, wider IDs deferred, generic10/14/8 not equivalent,
and L6 geometry not admitted. None is reopened here.

## Fixed representation and semantics

Reuse L2's validated uint64 mask/shift 16/40/8 carrier/accessor implementation
from b97c7c1 (completed L evidence at4726f8d). All P arms use size/stride/alignment
8/8/8, legacy material IDs, epoch bits56..63 unchanged. State allocation inside
the existing40-bit capacity is fixed: a16 at bits16..31, b8 at32..39, unused40..55.
The a slot accommodates mass10 without moving fields between arms. Other
materials retain byte a/b semantics. P3 masks only Water b to4 bits; other b stays8.
This capacity use changes neither the carrier nor its access model. Validate the
mass8/delay8 control against unmodified current source before candidate evidence.
No save/adapter/render migration; new precision APIs are native experiment only.

Keep gravity/down/diagonal ordering, floor(3*imbalance/4), lateral order, viscosity,
cadence, coherent12/pre-decrement/max merge, activity, interactions, worker model
and material authority fixed. No minimum transfer, cleanup, smoothing or rescue.
Fixed geometry128/32/64/radius2, quiet3, Baseline transport unconfigured (optional
mixing off), parallel threshold1 as established Water fixtures, ambient200,
chunks64/active chunks64/cores512/events1024, region reservation512 square.
Each executable uses identical C++20 O3/NDEBUG/LTO, pthread/static flags with the
workspace Python3.12.14 and LLVM-MinGW Clang23.1.0/UCRT configured via tools/dev.py.
Debug tests use O0/g3. No concurrent builds/campaigns; process timeout1800s,
build1200s. Executable/compiler/source hashes are captured before measurement.

## Mathematical contract

Mass bits b=4/6/8/10 give M=15/63/255/1023; physical fill=m/M. Input is an exact
rational n/d in [0,1]; quantize per cell Q=floor((2*n*M+d)/(2*d)), nearest with
half up. Zero becomes Empty. Record requested rational sum, actual initial
integer sum and error=sum(Q)/M-requested. Full-cell basin inputs are exact.
Integer additions/subtractions and capacity caps remain exact; no fractional
remainder is stored. Lateral request floor(3*positive difference/4), then existing
integer viscosity scaling; merge amount=min(request,source,M-target), subtraction
and addition identical. Empty has zero quantity. Output divides by each arm's M;
runtime conservation compares every tick against that arm's initial integer total.
All fixtures are closed and nonreactive: source=sink=0, including shelf removal.

P1: four mass arms, delay8. Common normalized policy maps film48/255 and tolerance
1/255 by nearest/half-up: film=3/12/48/193, tolerance=0/0/1/4. Zero tolerance is
intentional nearest representation, not permission to add a minimum transfer.
Front threshold uses ceil(128*M/255); one-cell levelness is spread<=M; tiny residue
means mass<=Q(1/255), with zero threshold counting no positive cell.

P2: same four masses/delay8, normalized policy versus literal tolerance1. Film
remains normalized48/255 in both: replacing film by1 would redefine film intent
and conflate two threshold changes. Mass8 policies are identical controls.

P3: mass8/normalized, delay8 versus Water-only delay4. Legal semantic countdown
domain0..12, including all pairwise max merges, pre-decrement timing, movement,
creation/reset and repeated transfers. Out-of-domain Water delay rejected by
experiment setter; no generic state compression claim. Exhaustive storage tests
also preserve every non-Water byte a/b value and epoch across writes.

## Fixtures, horizon and observations

Reuse closed48/96-wide, height48 basins with12x32 full Water at x1..12,y15..46,
walls x0/width+1,y0/47 (water_leveling.cpp / C harness). Five (shift,mirror)
settings: (0,0),(-129,0),(127,1),(-257,1),(65,0), applied to both axes. Coordinates
provide positive/negative core/storage seams; coordinate-sensitive random ordering
may change trajectories across translations but must not change accounting.
All applicable behavior arms run workers1/4 twice,1800 ticks, no clock reads.

Reuse C film (one48/255 cell at12,46); support shelf y23, full cell12,22, shelf
removed before601, with fixed region throughout. Add a bounded ledge/drop fixture
in the same box: shelf y23,x1..24, Water x17..24,y15..22, ordinary delay0 or coherent12.
Compare discharged quantity below y23, front, fragmentation, droplet survival,
last change and work; this is native movement evidence, not a visual acceptance.
Small paired lanes: isolated adjacent cells on closed floor with adhesion disabled
to isolate transfers, fractions (128/255,127/255), (2/255,1/255), (1/255,0), and their
mirrors in separated chambers. Add lattice pairs (2,1) and (1,0), explicitly distinct
arm-dependent physical inputs, to explain exact zero-transfer boundaries. Register
these as low-difference diagnostics, not physical-input equivalence claims.
Delay fixture includes separated chambers for countdown0..12 and asymmetric merges;
focused tests exhaust all169 merge inputs through the actual transfer function.

Capture each behavior tick's exact quantity, canonical coordinate/material/a/b/
temperature semantic fingerprint, normalized columns, front, discharge, occupied
and tiny counts, last content-change, visited cells, moved cells, scheduled cores,
active blocks and cumulative diagnostic events. Successful transfer count and
transferred integer units are distinct; record lateral requests/zero requests,
probes, Water updates and block wake/sleep transitions using existing job histogram.
Rest: at least40 unchanged final content ticks; last-change is censored if still
changing at horizon. Active lifetime uses last tick with visited cells, separately.
Observations must not change behavior: off/on control records compare exactly.

## Timing design and review rules

Seven alternating AB/BA independent process pairs: mass8 versus each4/6/10 on
basin48,basin96,ledge and workers1/4; P3 delay8/4 on coherent ledge workers1/4.
P2 is behavioral isolation, no separate speed claim. Timing runs1920 ticks with
first120 warmup retained separately, next1800 steady; startup separate. Observer
and per-tick semantic traversal off in primary timing. Final exact state/work must
match corresponding observer-on/off1920-tick verification runs; those verification
runs retain every-tick ledgers. Separate seven observer-off/on pairs on basin96,
workers1/4, each P1 mass to quantify instrumentation overhead; never substitute
observer-on cost for primary cost. All samples/outliers retained; no overlapping
builds/measurements. Host process/power snapshots qualify uncontended-host claims.

Nearest-rank p50/p95/p99/max, steady total, visits and ns/visit; per pair candidate/
control ratios then median ratios. Report work totals, activity and transfer counts
separately from per-work costs. Flag paired p95>1.15 for review, not automatic
failure. No byte saving exists in this fixed carrier. Missing PMU/GPU/platform data
remain limits. No significance/general-host claim from seven pairs.

Unaccounted integer loss/creation, nondeterminism, illegal state truncation or
worker divergence is a correctness failure, never a precision tradeoff. Film loss,
stalling, worse fronts, residuals or persistent work are retained negative results.
Mass8 remains reference unless lower precision preserves important behaviors;
extra precision must demonstrate useful benefit. No production migration or #18
implementation. #18 still needs a measured motion target; #19 independent,
#20 blocked, G-final open.

## Evidence, recovery and completion

Generated data/builds: worktree validation/local/issue-17/ and build/issue-17/.
Commit registration, harness, curated summaries/audit and documentation checkpoints;
raw JSONL/logs/executables remain ignored. Full source and executable manifest and
run order are frozen before timing. A harness error stops the affected stage:
retain failed files, register diagnosis/correction before rerunning affected runs
in a new named attempt; no deletion, automatic retry, rule change or outlier removal.
Do not alter candidate semantics/measurement rules after timing begins.

Complete native focused/full reference tests, experiment Python tests, deterministic
repeat/worker/delay checks, docs/M11/repository/retrieval checks and diff check.
Keep inherited provenance failures separate. After all P1/P2/P3 results are reduced,
record G-P in #14 and synchronized canonical docs, then close #17 as completed.
The user explicitly authorized those issue writes in this execution request.
