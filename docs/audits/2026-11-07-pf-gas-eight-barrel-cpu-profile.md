---
title: PressureFlow gas stage — same-host Windows eight-barrel CPU profile, 7 November 2026
status: Current
document-kind: audit
scope: Diagnostic-only C2048-main-versus-#504 exact-source instrumented run; no runtime publication or solver admission
last-reviewed: 2026-11-07
related-documents: [2026-11-07-pf-gas-real-godot-result.md, 2026-11-07-pf-gas-optimization-acceptance-gate.md, ../architecture/pressure-flow-v1.md, ../architecture/pressure-optimization.md]
---

# PressureFlow gas hotpath: actual eight-barrel CPU attribution

## Decision: REPAIR / HOLD #504, no full factorial

**The exact synthetic native 14.10% improvement does not survive the real Godot workload.** [Bounded real-Godot source-matched CPU run 42343175428](https://github.com/techrote/cybersand/actions/runs/42343175428) passed **64/64 real Windows Godot trials** using identical temporary CPU probes in both source arms, but observed a **4.52% median paired gas-stage wall-time regression** and **6.81% median paired increase in process CPU consumed during gas-stage windows**. This independently corroborates the earlier uninstrumented [real Godot run 42340715185](https://github.com/techrote/cybersand/actions/runs/42340715185), which found −2.71% median paired gas-on native-tick speedup across the wider 20-case screen. It does not justify #504 integration or the 1,080+1,080 full factorial.

**High-confidence mechanism at the work level:** The reacting eight-actor Water scene runs **one full gas reference topology pass every native tick** for all three PressureFlow variants. Across every measured gas-on case and both scheduling cores, **gas reuse=0, certified component reuse=0, cache restart=0**. The operator scans **983,040 seed cells/tick**, visits approximately **125,047 gas BFS cells/tick** and relabels **983,040 cells/tick**. This full-world work is exactly identical between baseline and candidate. There is no cache-reuse workload advantage for the cached/cached_dormant variants here; source-level shortcuts have not reduced compulsory full-scan/relabel work and cost more gas-stage wall time on this workload.

This **does not prove which individual optimized instruction is responsible**. Active body masks and ongoing topological change are plausible engagement limits, but mask occupancy counts and instruction-level inclusive samples were not measured. Do not assert that relabelling itself became slower due to a code change: that substage's process-CPU samples are coarse and concurrent, and the optimization does not change relabelling work counts.

## Source/run custody

- **Baseline accepted app/World source:** main \`24a8bbe8ccf0d17196ebbab580b924930a964584\`, tree \`fa4d05fbdc11ef43d852ec51fc7998c5a04b0813\`. Identically instrumented diagnostic Windows DLL SHA-256 \`df138dacef8bb3ea63d91ba8c561b5de69069d93b1a6bf9580572c2cc55a6268\`.
- **Optimization source:** pinned two-parent #504 merge \`b7f151f85676ffc6b2ea87f3e5c6165b890727e0\` with #504 PR head \`186452b9f035961325ad71917a76ba8834e30bcf\`; source tree \`c4263f11c7cb1972a1a2015638b5f520fd46fd3f\`. Identically instrumented diagnostic Windows DLL SHA-256 \`5a5f0f61a6c838aa4eaf3f57971843afbce6a823b43f892c914f567b9654a19e\`.
- **Native source difference before instrumentation:** only \`native/src/world_pressure.inc\`; accepted SHA-256 \`71723fa32bbd29aafe93f1a8dd233cece1eec7ed295da81c1e021f635085c17a\` versus optimized \`899ada71b89d30ba063e047bdd5b02346948008f1b7c0bec9fa0f2272e4d86ec\`. No #405 source imported.
- **Temporary diagnostic source patch:** common script SHA-256 \`a5ea18db030e2b3cf4c29f9fc961feafe5bfc69e412777f8badebde174a11a40\`, authored at \`tools/ci/pf_gas_cpu_instrument.py\`; it augments both World counters, pressure timing observations and \`world_pressure.inc\` with the same process/thread CPU stage clocks in **detached ephemeral source worktrees only**. It changes no pressure law, RNG/order, gas identity, persistent codec or production runtime. [Source-build run 42342476788](https://github.com/techrote/cybersand/actions/runs/42342476788) completed both builds successfully and retained both original/source/build/patch SHA manifests.
- **Compiler/engine:** pinned LLVM-MinGW 20260826 UCRT archive SHA-256 \`cee8d2ce3da5145ce4dc882e70d0b0719a783d53a99752c60948fc0659975a65\`; Godot-cpp \`101ae38034304346a46ea9ea84ae156d3e860496\`, SCons 4.10.1, C++20 \`-O3 -DNDEBUG\`; original Godot 4.7 Windows application and original Rapier DLL shared between both arms. The identical test-only Godot worker/fixture probe identities are in the artifact.
- **Final actual execution:** [successful run 42343175428](https://github.com/techrote/cybersand/actions/runs/42343175428), artifact [\`pf-gas-eight-barrel-cpu-profile-42343175428\`](https://github.com/techrote/cybersand/actions/runs/42343175428/artifacts/13562064199), 90-day retention. It contains all four raw Godot results/logs and manifests, per-case trajectories/splash telemetry, individual stage/CPU counters and [\`cpu-stage-report.json\`](https://github.com/techrote/cybersand/actions/runs/42343175428). Original #493 historical run and all its test files are preserved.

A preliminary same-workflow execution [42342476788](https://github.com/techrote/cybersand/actions/runs/42342476788) compiled both binaries but its dependent Windows job stopped **before launching Godot** because the downloaded ZIP retained \`source/probe-patch-identities.json\` under \`source/\` rather than artifact root. The stage path was fixed. The successful separate Windows-only job **reused those same source-verified compiled binaries**, rather than repeating compilation or running the historical baseline.

## Workload, sample and exact coverage

This is the original #493 1024×512 reduction of the original 2048×1024 stress canvas. It retains the 59-material construction, 119 authored stamps, eight **real Rapier barrels**, ballistic Water, face release, impact spray and ordinary asynchronous game ownership. The legal finite-toggle source is unchanged. The reduced profiling subset selects exactly **16 configurations**: all six PF modes (reference/cached/cached_dormant × gas on/off) plus FreeMass and CellularYield, each at 64-cell and 32-cell scheduling cores, with normalization and jet off.

Two complete independent World reconstructions per source produced **32 baseline + 32 optimized = 64 PASS**, no missing/duplicate/refused or aborted case, 30 warmup and 100 measured native ticks per case. Source order was balanced **B–C–C–B**, the same Windows host, Godot/Rapier version and source-backed fixture for all four batches. Splash ledgers, totals and receipts matched within all source/replicate pairs. Actor traces were retained; ordinary asynchronous trajectory equality and full physical-state-hash/quantity conservation were not independently established in this profiling gate.

**These source builds retain the accepted app's C2048-capable code but use the #493 fixture's ordinary default gas-compartment capacity unless the scenario explicitly requests the C2048 opt-in. Do not mistake a C2048-capable binary for a proven applied C2048 trial.**

## Measured real-Godot performance, gas ON only

Units are ms per native tick except where stated. The values in the first two columns are medians of the six gas-on PF configuration medians (each from its two independent repetitions). The paired-effect column is the median of six *per-config* candidate/baseline percent contrasts, not a ratio of those two pooled medians.

| Measured region | Accepted baseline | #504 optimized | Median paired speedup |
|---|---:|---:|---:|
| **Gas stage WALL** | **9.0122** | **9.4135** | **−4.52%** |
| Whole-process CPU *during gas-stage window* | 14.3750 | 15.5469 | **−6.81%** |
| Gas owner-thread CPU *during gas stage* | 7.2656 | 7.5781 | **−3.79%** |
| Discovery/BFS/seed process-CPU window | 11.6797 | 12.7734 | −4.06% (mixed per-stratum) |
| Gas label/relabel process-CPU window | 2.6563 | 3.4375 | −41.67% (very noisy; not a causal relabel claim) |
| Pressure head WALL (subsequent stage) | 4.1437 | 4.0357 | +2.78% |
| **Native simulation tick WALL p50** | **25.3860** | **25.7469** | **−1.11%** |
| Native simulation tick p95 | 27.2363 | 27.2510 | −0.99% |
| Native simulation tick p99 | 27.5590 | 27.4960 | −0.45% |

All six gas-on paired **gas-stage wall** comparisons worsened (from −1.73% to −5.53% speedup). By core, gas-stage wall paired speedup was **−4.49% at 64-cell**, **−4.55% at 32-cell**. This is a stronger and more direct explanation of the application regression than comparing native tick p50 alone. Gas-stage wall duration increases by median **+0.406 ms/tick**; the head stage subsequently improves around **0.116 ms/tick**, partially masking that gas-stage regression in whole native tick time.

**Controls:** Six PF gas-off configurations had gas-window CPU ~zero and median paired native tick improvement **+2.32%**; four non-PF configurations had median paired tick improvement **+0.35%**. The source-specific regression is concentrated in actual gas-on execution rather than a universal slowdown of the application binary.

## Why synthetic 14.1% differs from actual gameplay

The [#504 paired native benchmark](https://github.com/techrote/cybersand/actions/runs/42333533560) uses a constructed 1024×512 **360-pocket** stress input, fixed 8 warmup + 32 measurement native ticks and independent native World host. Under that specialized geometry, same-run native tick improvement was +14.10% on accepted C2048 main, with exact physical hashes and gas work. Those absolute timings and operation mix cannot be imported into the 59-material eight-Rapier-barrel, continuously reacting application scene.

Here the actual sampled work mix is different:
- **All three PF variants execute one actual gas reference pass per tick.** Gas cache reuse and component reuse are both zero, so cached/dormant do not skip this operator.
- The global seed scan and relabelling cover approximately **983k cells every native tick**, despite ~125k BFS visits. Both source arms do *identical* work counts (including ~490,760 BFS probes and ~129,453 seed probes per tick).
- The optimized extra address/mask/cache fast paths have a workload-dependent benefit. The exact stage wall timing indicates they are not profitable in this real scene as currently composed. The findings are consistent with a different topology/mask/cache regime, but do **not** isolate individual hot instructions; final per-instruction causation requires a different sampling technique, which is outside this authorized bounded task.
- No evidence here supports accepting #504 on the strength of the synthetic 14.10%; conversely, no evidence refutes the narrow synthetic benefit measured on its original input.

## Critical interpretation limits

Windows \`GetProcessTimes\` measures **all process threads** during the gas-owner's wall-time window: it includes concurrent other worker and Godot/Rapier CPU. It may exceed elapsed wall time. Windows \`GetThreadTimes\` measures **only the gas-stage owner** and excludes worker-pool CPU. These are inclusive *time-window* observations, not exclusive per-function processor profiles, and the shorter discovery/identity/relabel process windows are highly quantized and variable. The label/relabel CPU percentage has large relative variation and must not be treated as independently proved regression. By contrast, gas-stage wall time uses the native existing high-resolution monotonic timer and consistently regresses in all six measured PF gas-on strata.

The CPU diagnostic extends an existing 53-counter snapshot with temporary non-serialized counters, intentionally changes instrumented compilation slightly, and does not claim byte identity with the historical production DLL. Both sides get **the same** probe code and toolchain. The default asynchronous game is not a deterministic input/actor-state lockstep; actual native full physical hashes and complete Water/gas/ballistic conservation ledgers were not compared in this scoped profile. Actual worker-participation readback was empty in these snapshots; do not claim observed worker count or attribute all process CPU to pool tasks. Headless Godot is real physics execution, not representative rendered GPU FPS.

## Handoff, stop condition and recommendation

**REPAIR / HOLD #504; DO NOT MERGE or launch the full factorial.** The bounded causal investigation is **complete at the operator and workload level**: global gas reference scanning and relabelling are compulsory on every active game tick and the #504 optimization increases measured gas-stage wall and CPU-window cost on the real scene. The exact mechanism within the optimized hotpath is not instruction-isolated, and shall not be guessed.

If an implementation owner later elects to repair #504, direct that owner to the actually active global seed/BFS/relabel path, optimize only when branch behavior and occupancy/cache conditions are justified by verified real-host observations, and re-run this *existing* small source-matched application screen **once** after a stable justified patch. Preserve gas-free controls and exactness and do not restart new native benchmark programmes. Defer full 360×3×2 and full physical/human gameplay acceptance until a candidate demonstrates reproducible real-app benefits.

No production native World, source admission lock, Godot runtime, physics law, save format, default Water policy or accepted main was modified; no merge was performed.
