---
title: PressureFlow gas optimization — matched acceptance handoff
status: Planned
document-kind: audit
scope: Independent acceptance apparatus, no production simulation edits
last-reviewed: 2026-11-07
related-documents: [../architecture/pressure-flow-v1.md, ../architecture/pressure-optimization.md, ../operations/github-development-and-release.md]
---

# PressureFlow gas optimization — source-matched acceptance gate

## Status and authoritative baseline

**NOT YET QUALIFIED.** No stable, independently qualified gas-optimization
candidate was present among the open CyberSand PRs at this checkpoint.
Prepare the rapid screen, preserve progress and stop. Do not rerun the unchanged
historical dataset, manufacture a speedup or merge this Draft apparatus.

Historical reference: [PR #493](https://github.com/techrote/cybersand/pull/493)
at b62eb26a867c08e9933d507a4699bb02be7c10d1;
[successful run 42324048779](https://github.com/techrote/cybersand/actions/runs/42324048779).
It demonstrated 360 legal configurations x 3 fresh repetitions = **1,080
passes, no missing/duplicate**. PF gas enabled had +61.37% median native
tick p50 wall duration across 108 precisely factor-matched pairs.
This is **historical diagnosis, not the new optimization denominator**.

This branch descends from #493 but does **not** edit its three historical test
files, its planner, its original successful run or its artifacts.
The added Python imports the exact 360-case planner and drives the *unchanged*
Godot factorial fixture. This acceptance PR is stacked and non-mergeable as an
independent performance claim until both source arms are available.

## Rapid subset

Run: python tools/ci/pf_gas_acceptance.py check

The 40 chosen legal configurations include all ten Water modes in each
of four identical other-option strata:

| Options | Core | Modes |
|---|---:|---:|
| No ballistic, face, spray or jet | 64 cell | 10 |
| Ballistic only; face/spray off | 64 cell | 10 |
| Ballistic + face + impact spray | 64 cell | 10 |
| Ballistic + face + impact spray | 32 cell | 10 |

Every group includes FreeMass, CellularYield, PressureFlow
reference/cached/cached_dormant (all three gas off/on), Inertial and signed
Inertial. Jet and Water normalization are deliberately off in this *rapid*
screen; their interactions remain in the 360-case full factorial.

The existing 1024x512 reduction, 59 materials, 119 construction stamps,
eight real Rapier barrels, authored Water policies, 30 fixed warmup and
100 measured native ticks, actor traces and Water/splash records are retained.
Two independent World/process repetitions per source give **80 trials each,
160 matched in total**. Matched sequence uses B-C-C-B: baseline repeat 0,
candidate repeat 0, candidate repeat 1, baseline repeat 1.

## Source-build handoff and B-C-C-B execution

Before running, obtain a stable gas optimization PR and two **source-built**
Windows native DLLs from the same current-main feature set: optimization
disabled versus enabled. In particular #405, #470/#471, merged #474 and
#491 must be reconciled **equally into both arms**, with no capacity or
other physical options changed on one arm only.

The source-build owner must publish a per-DLL JSON manifest with the
following nonempty string fields:
- source_commit (full 40-hex SHA)
- source_tree_sha (full 40-hex SHA)
- native_sha256 (full 64-hex SHA-256)
- compiler, build_flags, build_profile, build_job_url

These must originate from the real build job, not be handwritten as a
substitute for provenance. Archive both source-identified binaries,
compiler versions, exact build commands, runtime dependencies and hashes.
The historical LFS-retained native DLL used by #493 **is not** an admissible
new source-matched baseline by itself.

All four runs must execute sequentially on **one Windows host**, with the
same test checkout, official Godot 4.7 executable, Rapier DLL, hardware,
worker policy and build flags. The run command validates the **currently
installed Godot native DLL** against the named build manifest; the operator
is responsible for installing the correct prebuilt baseline/candidate DLL
*before each launch*. Never overwrite previous result directories.

Commands, in exact order (after installing that arm's DLL):

    python tools/ci/pf_gas_acceptance.py execute --role baseline  --replicate 0 --order-position 0 --source-build-manifest build/native-baseline.json  --godot build/water-factorial/toolchain/Godot_v4.7-stable_win64_console.exe --out build/pf-gas/baseline
    python tools/ci/pf_gas_acceptance.py execute --role candidate --replicate 0 --order-position 1 --source-build-manifest build/native-candidate.json --godot build/water-factorial/toolchain/Godot_v4.7-stable_win64_console.exe --out build/pf-gas/candidate
    python tools/ci/pf_gas_acceptance.py execute --role candidate --replicate 1 --order-position 2 --source-build-manifest build/native-candidate.json --godot build/water-factorial/toolchain/Godot_v4.7-stable_win64_console.exe --out build/pf-gas/candidate
    python tools/ci/pf_gas_acceptance.py execute --role baseline  --replicate 1 --order-position 3 --source-build-manifest build/native-baseline.json  --godot build/water-factorial/toolchain/Godot_v4.7-stable_win64_console.exe --out build/pf-gas/baseline

Run the comparator:

    python tools/ci/pf_gas_acceptance.py compare --baseline build/pf-gas/baseline --candidate build/pf-gas/candidate --output build/pf-gas/comparison.json

The comparator rejects missing/duplicate/failed trials, invalid case-policy
echoes, incorrect ABBA order, unequal machine/Godot/Rapier/fixture/runner
identities, incompatible compiler/profile flags and mismatched source-build
identity. It records p50/p95/p99, native throughput, Rapier step timing,
candidate/baseline ratios, repeat ranges, all outliers and failures.
Exit 1 means invalid comparison; exit 2 means screening data exist but
required correctness/CPU telemetry is incomplete. **Neither is acceptance.**

The existing #493 Godot result records native/worker *wall* samples,
native throughput, actor positions every 20 native ticks, Rapier timings
and splash telemetry. It does **not** yet expose direct process/calling-thread
CPU time, gas-specific stage CPU time, actual native worker participation,
native physical state hashes or full native quantity ledgers. The comparator
explicitly flags these absent fields; they must be added with read-only,
source-matched instrumentation on **both** source arms. Do not infer CPU
use from wall time or infer actual workers from requested worker settings.
Ordinary asynchronous actor traces need not be bit-identical to themselves.

## Complete factorial (required after stable screen)

Rerun the *unchanged* 360-case generator and 24-shard Windows infrastructure
for **both** source-built arms, 3 independent repetitions each: **1,080
baseline + 1,080 candidate trials**. Build and execute both arms within
each same-host matched shard job; balance source order by alternating
B-C versus C-B and reverse initial order on half the shards.
Simply comparing different hosted Windows VMs, or comparing fresh
optimized results to old #493 medians, is not admissible.

Verify exact 2,160-record coverage, native applied policy and option
readback, native state and full Water/gas/ballistic quantity ledgers, stage
CPU timing, actual worker participation and native/Rapier step rates.
Report source-paired p50/p95/p99, variability and effect sizes across
all Water family, PF variant/gas, ballistic, face, spray, jet, normalization,
Inertial signed and 32/64 core choices. Preserve every outlier, non-PASS
trial, boundary refusal and runtime log.

## Full gameplay gate

After the full factorial, execute source-matched Windows **and** Linux
gameplay builds. Use the original **2048x1024 full stress-canvas**, all
59 materials, eight live barrels, PF cached_dormant gas on, ballistic Water,
face release and impact spray. Use opt-in C2048 from #491 **only if independently
qualified and applied identically on both sides**. Do not conflate an
optional capacity/profile change with gas-solver optimization.

Also replay a deterministic **moving Acrobat** input sequence, matching
initial native and Rapier states. Compare default asynchronous and the
merged #474 opt-in lockstep paths separately, including physical-state hashes,
body trajectories, impact and collision/contact outcomes, spray launches,
parcel conservation, terrain freshness, capacity refusals and actual native/
Rapier progress. Inspect visual captures and gameplay behaviour. Hosted
software rendering measurements are **not representative desktop GPU FPS**;
separate native CPU work from pacing/render idle.

## Final decision and collaborator handoff

A single consolidated acceptance report must contain full pass/fail coverage,
exact source/runtime identities, matched distribution tables, Water-family/
option speedups and regressions, CPU and worker data, conservation and native
hashes, Acrobat/barrel and splash outcomes, async/lockstep results and actual
graphical qualification.

**ACCEPT** only with reproducible material CPU/whole-app improvement, fully
correct physics/conservation and acceptable gameplay; **REPAIR** a fixable
correctness/telemetry/performance failure; **REJECT** unacceptable physics
or an optimization that cannot deliver worthwhile gains. At this checkpoint:
**NOT YET QUALIFIED**, no recommendation about the candidate itself.

Handoff:
- Gas optimization owner: stable exact candidate, clean source-matched
  baseline, source-build manifests, and missing read-only metrics.
- #491: source-qualified C2048, historical C1024 compatibility, CYPS5 identity
  and capacity receipts for the separate heavy gameplay case.
- #405/#474 integration: same accepted-main features in both arms, qualified
  default-async and opt-in lockstep runtime.
- Independent acceptance owner: only after candidate handoff, execute subset,
  full factorial and gameplay tests, publish one verdict. No new solver and
  no production merge authority.
