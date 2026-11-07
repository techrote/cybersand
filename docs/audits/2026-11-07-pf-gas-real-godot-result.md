---
title: PF gas exact-hotpath real Godot A/B - negative application performance screen
status: Current
document-kind: audit
scope: Independent 20-configuration matched Windows Godot C2048-capable application screen; not complete factorial or engine acceptance
last-reviewed: 2026-11-07
related-documents: [2026-11-07-pf-gas-optimization-acceptance-gate.md, ../architecture/pressure-flow-v1.md, ../architecture/pressure-optimization.md]
---

# PressureFlow gas optimization: independent real Godot result (7 Nov 2026)

## Decision: REPAIR / HOLD — no full factorial yet

The +14.10% same-source native-only gas-on tick improvement in [PR #504](https://github.com/techrote/cybersand/pull/504) does **not** reproduce in the 59-material, eight-barrel Windows Godot/Rapier app. In the real application screen, the optimized source is **2.71% slower** by the median paired gas-on native tick p50. All six exactly matched gas-enabled options have negative speedup point estimates, 0.52% to 3.65% slower. This is an adverse performance screen, not a claim of irreparable physics or universal slowdown across machines.

**Source-matched successful execution:** [Actions run 42340715185](https://github.com/techrote/cybersand/actions/runs/42340715185), tested apparatus HEAD 5e28994e4b91174432e5bebcd01974a6e85989f9.

**Complete machine-readable raw evidence:** [artifact 13561274352](https://github.com/techrote/cybersand/actions/runs/42340715185/artifacts/13561274352). Contains every case, exact source and DLL SHA manifests, Godot import log, all actors and spray ledgers, latency samples and source-paired comparison JSON. Earlier #493 historical 1,080 trials were not rerun.

## Source/runtime identity and matching controls

- Accepted real Godot application source: main 24a8bbe8ccf0d17196ebbab580b924930a964584 (merged #491 C2048 support).
- Published Windows control DLL: built at 3b41f020a8616052d72666ed65624d9b1447a419; SHA-256 acff339266bab58278aa3e4ea2e3b183ef0a031cf796bd50bcf6fc928b26fce4; accepted application differs only by installed runtime/provenance publication since that source build.
- Optimized candidate Windows DLL: built from actual two-parent PR test merge b7f151f85676ffc6b2ea87f3e5c6165b890727e0 (PR head 186452b9f035961325ad71917a76ba8834e30bcf); SHA-256 605519f58708c7d4f5fe6256c18a6dc4c6b10acf343c38c34b10b36cf04ad6d0; [GDExtension build 42333533378](https://github.com/techrote/cybersand/actions/runs/42333533378).
- Same pinned LLVM-MinGW 20260826 UCRT, Godot-cpp 101ae380, template_debug/O3 flags, actual Windows 2022 hosted runner (4 vCPUs), Godot 4.7.stable.official.5b4e0cb0f and Rapier library SHA-256 b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7.
- The independent byte/scope guard confirmed the **sole production source delta is native/src/world_pressure.inc**; no #405 optimization, host script or other material/pressure law was changed between arms.
- The application is **C2048-capable** because #491 merged. The benchmark did **not explicitly opt in to capacity 2048**; default applied capacity remains unchanged in both arms. This is a fair source comparison of the optimized gas operator, not a C1024-vs-C2048 capacity test.
- Source and runtime SHA identities were independently attested before each swap. The real Godot app imported successfully on the control runtime. The same host executed B-C-C-B.

## Real benchmark and effect sizes

The inherited #493 Godot fixture used the same half-size 1024x512 stress construction, 119 stamps, all 59 materials, eight live Rapier barrels, ballistic Water, face release and impact spray. A fixed warmup of 30 native ticks precedes 100 measured native ticks. Twenty legal configurations cross all ten Water variants with both 64-cell and 32-cell scheduling cores; jet and Water normalization are held off. Two independent Godot/World reconstructions per source give 40 control + 40 optimized = **80 trials; all 80 PASS**, no missing/duplicate/World failure.

| Source-paired cohort | Control p50 (ms) | Candidate p50 (ms) | Median paired p50 speedup |
|---|---:|---:|---:|
| PressureFlow gas ON, 6 options | 21.887 | 22.275 | **-2.71% (slower)** |
| PressureFlow gas OFF, 6 options | 13.514 | 13.429 | +0.89% |
| Other Water families, 8 controls | 10.364 | 10.273 | +0.48% |
| All 20 legal cases | 13.358 | 13.380 | -0.58% |

Values in the timing columns are cohort medians of two-repetition per-configuration medians. The percentage is the median of exact-other-factor **per-configuration source ratios**, not the ratio of aggregate columns.

- Gas-on p95 median 23.532 to 24.036 ms; **1.76% slower** by paired ratios.
- Gas-on p99 median 24.007 to 24.644 ms; **1.99% slower** by paired ratios.
- Gas-on achieved native rate median 27.178 to 26.816 steps/s, **2.21% lower** by paired ratios.
- Gas-on source-paired by PF variant: reference -2.09%, cached -2.71%, cached_dormant -2.09%.
- Gas-on 64-cell scheduling cores: -3.52%; 32-cell: -0.65%.
- Across two repeats, within-source gas-on p50 spread median 1.45% baseline, 1.61% candidate (maximum candidate spread 7.22%). The small slowdown is not claimed statistically definitive over wider host populations. Still, this screen supplies **no positive** application evidence for the fast path.

## Observed actor and quantity behaviour

All 80 trials advanced exactly 100 native ticks, and 99-101 actual Rapier steps were sampled per trial. Zero Rapier callbacks exceeded 40 ms. For every one of the 40 exact-config-and-repeat source pairs, the Godot-reported **spray ledger, spray receipt and spray totals were JSON-exact**. This includes launched/deposited Water parcel quantity, impact/body/terrain contacts, refused launches and forced deposits. Of the 96 gas-on final actor-position comparisons, 74 were within 0.01 cell, 91 within 1 cell; maximum offset 1.566 cells. Ordinary async initial actor states were not always identical (25/40 matched), so these are behaviour and telemetry checks, **not** bitwise deterministic coupled-physics acceptance.

The inherited Godot fixture does not expose native physical-state hash, complete native quantity ledger, gas-stage CPU time, process CPU time or observed native worker participation. The comparator explicitly returned **NOT_YET_QUALIFIED** for these five missing fields. Native tick values are *wall durations*, and the reported step rate is headless Godot advancement, not desktop GPU FPS. Lockstep and moving Acrobat were not executed in this bounded screen.

## Disposition and bounded next engineering work

**REPAIR the optimization's practical application performance; HOLD #504 unmerged.** The 14.1% native-only result remains valid for its narrower synthetic 360-pocket fixture but is not portable to this observed reacting gameplay workload.

Do not spend GitHub Actions on full 1,080+1,080 matched factorial until an independently repeatable real-app benefit has been demonstrated.

Next, use read-only stage CPU/profiler and actual worker counters in this same source-matched eight-barrel host to identify why the native seed/BFS fast path does not materially reduce complete real application ticks. Preserve gas-law/physical-hash/conservation checks, replay this same small matched A/B only after a justified implementation change, then consider full factorial plus full canvas/Acrobat acceptance if meaningful application benefit emerges. Do not ascribe cause to cache churn or masks without measured stage evidence.

**Final screen verdict: REPAIR / HOLD (performance), NOT production ACCEPT; no physics change is proven by timing alone.**
