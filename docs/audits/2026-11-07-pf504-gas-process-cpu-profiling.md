---
title: PF504 workbench stress-canvas gas-stage process CPU attribution
status: Current
document-kind: audit
scope: Exact-source same-host Linux CPU profiling of 2048x1024 authored workbench stress-canvas
last-reviewed: 2026-11-07
related-documents: [2026-11-07-pf504-actual-workbench-stress-ab.md, ../architecture/pressure-optimization.md]
---

# PR #504 — full workbench gas-stage process CPU profiling

## Motivation

Source-matched [native synthetic comparison](https://github.com/techrote/cybersand/actions/runs/42333533560) found +14.10% native tick and +19.36% gas-phase wall improvement. The earlier [half-scale Windows real application screen](https://github.com/techrote/cybersand/actions/runs/42340715185) found -2.71%; the subsequently completed [full 2048x1024 actual workbench B-C-C-B](https://github.com/techrote/cybersand/actions/runs/42342604239) found +2.1686%. These are different workloads, hosts and clocks; their ratios must not be averaged or treated as CPU measurements.

## Exact-source isolated instrumentation

- Pinned **accepted C2048 baseline**: `24a8bbe8ccf0d17196ebbab580b924930a964584`.
- Pinned **optimized #504 source**: `186452b9f035961325ad71917a76ba8834e30bcf`. Later #504 revisions are deliberately excluded.
- After verifying protected source LF SHA-256 and identical production source scope, apply **the same test-only clock and observation overlay** to both independent checkouts. Nothing is committed to production protected files; the base and candidate Git source identities and pre-/post-overlay LF hashes are archived.
- Linux C++ `std::clock()` clocks measure **process-wide cumulative CPU time**. Samples bracket `resolve_gas_topology` + gas decision, the pressure-head/certificate preparation and the complete native `World::tick` call. They include unrelated process threads scheduled concurrently, so bracketed **process CPU is not isolated gas-worker CPU**. Existing pressure `gas_nanoseconds`, `head_nanoseconds` and workbench `simulation_time_ms` remain separate wall-clock quantities.
- Copy only cumulative native counters/worker participation into the workbench's immutable snapshot on the exclusive worker thread while `PF504_STAGE_PROFILE=1`; no mutable World reference crosses threads.
- Preserve original pressure law, material rules, C2048 opt-in, CYPS5/hash5, default FreeMass, native active-body masks and the existing paired workload.

## Workload and acceptance

One Linux host, two separately compiled source-matched native GDExtensions, **B-C-C-B**, fresh actual Godot 4.7 workbench and Rapier sessions. Use the original `workbench_setup.gd::stress_canvas` (2048x1024, eight barrels), PF gas `cached_dormant` explicit C2048, ballistic face/jet/spray, hard wall/erase edits every two native ticks, 24 warmup and 240 requested native sample ticks.

Independent readback fails closed on missing source/overlay SHA, absent native worker or pressure CPU counters, no gas work, too few actual actor/collider/edit samples, stage CPU exceeding complete native tick CPU, mismatched toolchain/runtime identity, or incomplete B-C-C-B. Retain raw per-run Godot logs, original build logs, exact binary hashes, profiler overlay manifest, and the full JSON report.

Report paired gas wall and gas process CPU per native tick, head wall/head process CPU, total native process CPU, gas fraction of native tick CPU, seed/BFS/relabel work, reference/reuse/fallback counts, observed workers and actual workbench p50/p95. Use those to test the Amdahl/workload-mix explanation without *asserting* the cause until the evidence supports it.

## Release/physics limits

Ordinary asynchronous native/Rapier actor and jet timing may differ, and the inherited workbench lacks a complete native physical-state hash/quantity replay. The process-CPU clocks cannot prove that other Godot threads did no work during the gas-stage bracket. This bounded profiling experiment cannot authorize #504 merge, production LFS publication or a full 1080x2 factorial. Any physical source change after this pinned revision requires a fresh independent exact-source campaign.

**Status:** planned; no result claimed before the hosted comparison actually executes.


## Executed source-locked result — 7 November 2026

**The CPU-stage comparison is complete, with independent evidence replay passing.**

- **Original four source-built real-Godot executions:** [run 42357179356](https://github.com/techrote/cybersand/actions/runs/42357179356), each `B1`, `C1`, `C2`, `B2` completed the full authored 2048×1024 workbench, eight live Rapier barrels, C2048 cached_dormant gas, face/spray/jet, 121 accepted edits and 240 measured native ticks. The workflow conclusion was `failure` **only** because its original aggregation helper divided by gas counters with an ordinary zero baseline; none of the four native/Godot executions failed.
- **Independent zero-safe readback of the original immutable archive:** [successful run 42358203393](https://github.com/techrote/cybersand/actions/runs/42358203393), [validated 90-day raw+JSON artifact #13568531697](https://github.com/techrote/cybersand/actions/runs/42358203393/artifacts/13568531697). The replayer pinned original run #42357179356, source SHA IDs, artifact ID #13568138870 and ZIP digest `sha256:2dc85818dd9648ad6f8bf1fa1af96423d899be0bc08fe119814e3565b1e0e874`; compared all four unchanged native receipts and copied counters. `PF504_GAS_STAGE_CPU_REPLAY_PASS` and `PF504_GAS_PROCESS_CPU_PROFILE_PASS` were emitted.
- Original native sources: accepted C2048 `24a8bbe8ccf0d17196ebbab580b924930a964584`; optimized #504 `186452b9f035961325ad71917a76ba8834e30bcf`; instrumentation applied equally and only to temporary test checkouts. Baseline/Candidate instrumented Linux GDExtension SHA256 `9b36aa557f397dc7852a4bb0196e22d8e01b84951097710dcfdb86374b804bff` / `5f8f0a5c2f5a110b7e03255516aa92e9d9749de357c4d5b2c7998f2680833384`.

### B-C-C-B matched measurements

| Per measured native tick (two source-paired repetitions) | Accepted baseline | Optimized #504 | Median paired improvement |
|---|---:|---:|---:|
| Gas-stage process CPU (all process threads within gas bracket) | 24.738 ms | 20.819 ms | **15.839%** |
| Gas-stage wall time | 16.649 ms | 14.265 ms | **14.314%** |
| Head/certificate process CPU | 23.116 ms | 22.743 ms | 1.600% |
| Other native-tick bracketed process CPU | 112.502 ms | 110.193 ms | 2.045% |
| Complete native tick process CPU | 160.356 ms | 153.755 ms | **4.109%** |
| Observed workbench native tick wall p50 | 57.096 ms | 53.788 ms | **5.796%** |
| Observed workbench native tick wall p95 | 62.084 ms | 58.850 ms | **5.177%** |

Both source pairs improved gas-stage process CPU: **+14.81% / +16.87%**, with independent whole-native process CPU **+3.09% / +5.13%**. Actual CPU totals are time-bracketed process-wide CPU (`std::clock`), not isolated CPU of individual pool workers; reported native tick wall is the previously existing `simulation_time_ms` observation, not CPU.

### Gas-work attribution and limiting factor

- Every one of the four 240-tick measurement windows completed **240 gas topology reference passes**, **240 reference head fallbacks**, **zero gas topology reuses**, **zero gas component-cache reuses**, and **4 observed worker participants**. The nominal `cached_dormant` family repeatedly executes the full reference topology/head path in this continuously edited, ballistic and actor-active workbench. This does **not** prove which individual edit or invalidation caused each cold/recompute decision.
- In every arm the workload was essentially **2,949,120 gas seed cells** and **2,949,120 gas relabel cells per tick**, ~**228,104 gas BFS cells per tick**, ~**129,077 Water material calls per tick** and **2,304 recomputed columns/tick**. The source optimization makes these operations faster; it does **not** remove most of them. Counts differ by negligible fractions due to asynchronous physical scheduling.
- The gas stage is only **15.43% of baseline total native process CPU** (24.738/160.356). Assuming everything else were constant, its measured **15.84%** process-CPU improvement could save only about **2.44% of the total native CPU**. The complete native CPU actually improved **4.11%** here; favorable pressure-head, other-stage and host scheduling differences contribute to the remainder and are not independently attributable to #504.
- By contrast, in the narrower 360-pocket native-only synthetic benchmark the cumulative gas wall timer accounted for approximately **74%** of measured native tick wall time (different clock denominator and workload). The original full-workbench uninstrumented test measured **+2.1686%** p50, whereas the separately instrumented host in this test measured **+5.796%**. Likewise the half-scale Windows app screen was **-2.71%**. These effects are not replicates of one experiment; they must not be pooled, compared by absolute milliseconds across hosts or claimed universal.
- All four runs had **identical** full recorded ballistic spray ledgers, including 7,416 launched parcels, 753 injected parcels, 7,629 deposited parcels, body/ceiling contacts and total deposited quantity, plus 121 accepted hard edits and 264–265 actual actor steps. This is useful behavioral evidence **but not** a complete native physical hash or conservation replay.

### Decision

**BFS optimization is genuinely faster inside the full real workbench gas stage; Amdahl's law and the unchanged large reference workload explain why a native-only ~14% tick win becomes a low-single-digit complete-game tick benefit.** The observed host/source conditions affect the precise overall percentage. Continue to HOLD #504 production integration. Next highest-value performance work is to determine why active gas invalidation/reference fallback occurs every tick and how to avoid unnecessary full seed/relabel passes *without changing physical identity*. Before any admission, require independently matched Windows/Linux gameplay, full per-tick physical hash/quantity checks and source-matched binary publication, rather than the full 1,080+1,080 factorial first.
