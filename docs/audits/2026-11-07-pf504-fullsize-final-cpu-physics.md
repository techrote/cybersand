---
title: PF504 full-size workbench gas CPU and physical conservation — final bounded acceptance
status: Current
document-kind: audit
scope: One source-matched 2048x1024 real Godot/Rapier qualification; diagnostic-only, no merge or factorial
last-reviewed: 2026-11-07
related-documents: [2026-11-07-pf504-actual-workbench-stress-ab.md, ../architecture/pressure-flow-v1.md]
---

# PF504 full-size gas CPU and physics qualification: final decision

## Disposition — performance evidence PASS; full source-to-source physics acceptance UNPROVEN; HOLD MERGE

**The real 2048×1024 workbench improvement is reproducible in this bounded sample, and the optimization demonstrably reduces measured gas-stage CPU.** Both same-host matched pairs improved native tick time, gas-stage wall duration and CPU time. Independently checked native Water/ballistic and gas accounting remained closed at **20 actual World checkpoints**; the native worker telemetry observed **4/4 actual participants** across **345 sampled worker observations**.

**The experiment does not qualify source-to-source deterministic physics parity.** Full physical state hashes were captured at native ticks 48, 96, 144, 192 and 240 in all four runs (hash5 / explicit C2048), but most differ between separate processes. They also differ between independent executions of the **same baseline source**, reflecting the non-input-locked asynchronous actor/jet/edit stream. It would be unsound to treat such inequality as a gas defect *or* to claim hash equality on this real-app input. The independent small native synthetic proof in #504 is separate evidence, not an exact control over this application's live asynchronous inputs.

**Decision: HOLD / CONDITIONALLY WORTH INTEGRATING AFTER FURTHER REQUIRED PHYSICAL ACCEPTANCE.** The real full-size profile is positive and CPU-efficient, not the synthetic-only false gain suspected earlier. But +3.09% total native tick over two paired repetitions is too narrow, with a previously measured negative reduced Windows screen, to authorize expensive 2,160-trial factorial, runtime admission or guarded #504 merge from this evidence alone.

## Immutable source and runtime evidence

- Source baseline: accepted C2048 main **\`24a8bbe8ccf0d17196ebbab580b924930a964584\`**; candidate source under study **\`186452b9f035961325ad71917a76ba8834e30bcf\`**. These are exactly the two source arms used by the original independent full workbench [#515](https://github.com/techrote/cybersand/pull/515) and its prior positive [run 42342604239](https://github.com/techrote/cybersand/actions/runs/42342604239). The only native production code difference was **\`native/src/world_pressure.inc\`**. No #405 source was imported.
- Both native/GDExtension libraries were built with the same pinned Godot 4.7 \`godot-cpp=101ae38034304346a46ea9ea84ae156d3e860496\`, GCC 13, SCons 4.10.1 and original pinned Linux Rapier. Original full-size scene, workbench script, material distribution, real physical actors and native/graphics ownership were retained.
- Identical test-only probes were injected in each *detached build checkout* using \`tools/ci/pf504_full_cpu_probe.py\`: Linux \`clock_gettime(CLOCK_PROCESS_CPUTIME_ID)\` for the complete process across native gas-stage boundaries, \`CLOCK_THREAD_CPUTIME_ID\` for the owning thread, existing high-resolution gas/head wall counters, separate discovery/identity/relabel CPU windows, and read-only C++ World six-kind Water quantity ledger readback. The exact original/instrumented SHA-256 pairs are in \`evidence/probe-patch-identities.json\`.
- Test-only GDScript owner snapshots (identical in both arms) add read-only running counters, actual native task-participant inspection, and physical hash5 / Water / gas / ballistic closure samples **once per 48 completed native ticks**. The host code did not change tick pacing, gameplay controls or native physical laws.
- **Original full execution:** [GitHub Actions run 42356806615](https://github.com/techrote/cybersand/actions/runs/42356806615), [retained complete raw logs, both build records, four workbench receipts and source SHA archive](https://github.com/techrote/cybersand/actions/runs/42356806615/artifacts/13568252504). The two source builds, official Godot import and all four executable workbench cases **PASS**. That run's final reduction step failed on a Python reference typo after successful execution; no physics/test failure. The raw bytes were preserved.
- **Independent archival reduction after one-line correction, NO replay or rebuild:** [successful run 42357747749](https://github.com/techrote/cybersand/actions/runs/42357747749), [machine-readable \`fullsize-cpu-physics-report.json\` and hashes](https://github.com/techrote/cybersand/actions/runs/42357747749/artifacts/13568109169). Final programmatic verdict \`HOLD_SMALL_POSITIVE_UNQUALIFIED\`, \`decision=NO_MERGE_NO_FULL_FACTORIAL\`, all checks valid.

This is **not** the original historical 1,080-trial #493 factorial, a new scene, a renderer-FPS benchmark or a production runtime publication.

## Actual complete workbench workload and coverage

The built-in \`workbench_setup.gd::stress_canvas\` uses the actual **2048 × 1024** live workbench, **eight real Rapier barrels**, **explicit C2048** PF \`cached_dormant\` + gas ON, ballistic Water with face/spray/jet, and sustained hard-wall/erase edits every two native ticks. Each of four new Godot processes executed **24 warmup + 240 measured native ticks**, with hundreds of actor steps, >200 collected original simulation samples, >=45 accepted hard edits, >=35 distinct hard-surface revisions, live collider packets, true ballistic launches and no native failed state.

Two pairs were run on one Linux runner in **B1–C1–C2–B2** order, source-compiled native DLL switched at each process boundary. Both sources used identical instrumented native API/host scripts. No change to a physical rule, simulation RNG, gas-compartment law or source-authority lock occurred.

## Measured CPU and native tick, actual full-size gameplay

Rows report the **median** of the two separately reconstructed executions of each source. The speedup column is **median of the two individually matched B/C percentage contrasts**, not a ratio of pooled medians. Values are ms per actual native tick, in the same pinned Linux runner and test-only instrumented builds.

| Timing region | Accepted C2048 baseline | Optimized #504 | Median paired speedup |
|---|---:|---:|---:|
| **Gas-stage wall time** | **20.285** | **18.111** | **+10.72%** |
| **Gas-window process CPU** (all concurrent process threads) | **30.814** | **26.604** | **+13.66%** |
| Gas owner-thread CPU (excluding pool) | 16.382 | 15.032 | +8.24% |
| Discovery/seed/BFS process CPU window | 26.876 | 22.800 | +15.16% |
| Identity and relabel CPU windows | individually minor | individually minor | noisy/noncausal |
| Pressure preparation wall time (gas + heads) | 30.618 | 28.293 | +7.59% |
| Pressure-head wall time | 10.333 | 10.182 | +1.46% |
| **Complete native tick wall p50** | **76.048** | **73.699** | **+3.09%** |
| Complete native tick wall p95 | 81.051 | 78.320 | +3.37% |

Both source pairs improved: **native p50 +2.55% / +3.62%**, gas-stage wall **+11.07% / +10.37%**, gas-window process CPU **+14.05% / +13.27%**. The earlier **uninstrumented, same original full-size** #515 experiment saw native tick p50 +2.02% and +2.32% (median +2.17%); its sign agrees with this independent instrumented full-size result.

By contrast, the earlier **reduced** Windows Godot 1024×512 screen [42340715185](https://github.com/techrote/cybersand/actions/runs/42340715185) was **−2.71%** native p50, and the diagnostic reduced Windows CPU run [42343175428](https://github.com/techrote/cybersand/actions/runs/42343175428) was **−4.52%** gas-stage wall time. Different scene density, actor/edits, actual capacity and host OS mean these percentages cannot be averaged or substituted for one another.

## Why the full-size scene benefits, but the reduced scene does not

**Directly observed in actual 2048×1024 gameplay:**
- Approximately **2,949,120 seed cells and 2,949,120 relabelled cells per tick**, **228,000–228,300 BFS cells per tick**.
- **1.00 complete reference gas pass per native tick**, **zero gas-cache reuse**, **zero component reuse** and **zero gas-restart fallbacks** in *both* source variants. Even \`cached_dormant\` recomputes topology under this actively edited, reacting scene.
- Total worker participation **four real task-claiming workers** in all four source runs (maximum and median 4; capacities 4), sampled at the exclusive owner. This is measured task participation, not assumed from configuration.
- Both variants perform essentially the same global work; the candidate runs that compulsory work faster. Gas discovery/seed/BFS process CPU is reduced by about **15%** here, consistent with the benefit of optimized same-chunk reads at a larger traversal scale. This is workload-level attribution; exclusive per-instruction CPU or proof of a specific mask branch is **not** established.
- Native gas-stage cost accounts for roughly 20 ms of the ~76 ms baseline tick and improves ~2.17 ms; this bounds the whole-tick improvement near 3%, rather than 14%.

The full-size scene is therefore not benefiting from topology **cache reuse**. Its improvement is in the **compulsory gas traversal**, with enough work to amortize optimized address/lookup behavior. This explains the direction of the workload discrepancy without pretending to isolate individual CPU instructions.

## Physical-state and native conservation checks

Each source recorded periodic completed-tick native state hashes (\`hash5\`), exact native Water quantity (baseline, six cause kinds, visible+overfill+ballistic), gas compartment count/capacity and the complete gas creation/vent/collapse balance. **Every one of the 20 native checkpoints across four workbench runs passed**:

- \`actual Water = baseline + all six produced causes − all six consumed causes\`.
- Water \`visible + overfill + ballistic\` equaled the same native expected total and the Water amount separately reported by ballistic spray.
- Gas \`amount_live + vented + collapsed = created + absorbed\`.
- Applied capacity 2048; native physical hash version 5; no missing/invalid hashes or over-capacity gas census.
- Actual four-worker participation at 84–89 exclusive-owner samples per run.

**Source-to-source bitwise physical hash equality is NOT established.** Across the ten same-tick B/C checkpoint comparisons (five per pair), **two matched** and **eight differed**. Independent repetitions of the *same baseline source* also diverged at some checkpoints, so these differences cannot be causally attributed to optimized gas code. The workbench's asynchronous Rapier actor publication, jet/spray interactions and editing schedule are not replay-locked by native tick. This experiment preserves every hash and actual quantity record rather than inventing deterministic parity; the native exact-input replay gate remains a separate prerequisite to eventual production admission.

Therefore: **physics conservation PASS in the live application; deterministic cross-source physical equality UNPROVEN**, not "physics acceptance pass" and not "native gas physics defect".

## Limits and integration decision

1. **Performance accepted as a narrowly measured real-workload improvement.** Both same-host pairs and prior uninstrumented full-size experiment agree on a small 2–3% net native tick improvement and a substantial gas-stage CPU reduction.
2. **No general speedup claim.** Reduced half-size Godot screen regressed. This result is a full-size, eight-actor C2048 headless Godot workload, not rendered desktop FPS or an alternative source baseline.
3. **Process CPU is not function-exclusive.** Linux process CPU measured between the gas-owner's stage boundaries includes all other concurrent worker and Godot/Rapier threads. Owner-thread CPU excludes pool tasks. The measured gas-stage wall improvement is independent high-resolution monotonic stage timing.
4. **No merge authority.** The current #504 branch also includes retained-runtime publication/source-provenance steps that are not requalified by this historical exact source pair. Before merging #504, a deterministic same-input full-size native physical/quantity parity, final-head platform/runtime source publication and owner approval remain essential; do not treat async hash divergence as a physics defect.
5. **No broad expansion from this task.** The requested bounded qualification ends here. Do not trigger the 360×3×2 factorial, more synthetic campaigns, an optimization feature branch or a speculative physics repair.

**Final disposition: \`HOLD_SMALL_POSITIVE_UNQUALIFIED\` — #504 merits preservation and guarded follow-on exactness/integration consideration, but not immediate merge.** This is the strongest verified application-CPU evidence now available for the current gas hotpath. Leave #515 and #521 Draft, the existing native source and current \`main\` unchanged.
