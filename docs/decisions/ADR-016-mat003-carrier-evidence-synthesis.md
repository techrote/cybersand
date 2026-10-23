---
title: ADR-016 MAT-003PREPASS conditional carrier architecture synthesis
status: Planned
document-kind: decision
scope: Evidence-backed conditional carrier dispositions only; no adopted production representation, epoch policy or state schema
canonical-for: [mat003-carrier-conditional-architecture-decision]
keywords: [carrier, safe-memcpy, packed, dual64, u128, epoch, clear, fixed-memory, MAT-003PREPASS, GEN-006]
last-reviewed: 2026-10-23
related-documents: [ADR-015-material-state-schema-and-carrier-gates.md, ../audits/2026-10-23-mat003-independent-carrier-audit.md, ../research/mat003-continuation.md, ../research/mat-003prepass-gen006-handoff.md, ../architecture/chunk-tile-and-buffer-model.md]
---

# ADR-016 — conditional carrier architecture decision

**Status: Planned independent synthesis, not a production adoption ADR.** This document consolidates four separately accepted experiments [S2A](https://github.com/techrote/cybersand/issues/204#issuecomment-6354419821), [S2P](../audits/2026-10-23-s2p-results.md), [WCLEAR](../audits/2026-10-23-wclear-results.md) and [C128](../audits/2026-10-23-c128-results.md) under their original baseline, source, statistics and platform. Its separate [raw-archive audit](../audits/2026-10-23-mat003-independent-carrier-audit.md) independently checks hashes, per-file seals and raw reductions. Issue [#204](https://github.com/techrote/cybersand/issues/204) remains open; both [PR #211](https://github.com/techrote/cybersand/pull/211) and [PR #221](https://github.com/techrote/cybersand/pull/221) stay draft. Existing [ADR-015](ADR-015-material-state-schema-and-carrier-gates.md) continues to own *proposed* adoption budgets and pending owner field semantics.

## Decision now

**Retain production C64-E8 and decouple GEN-006 durable semantics from the in-memory native carrier.** No evidence demonstrates a needed new authoritative capacity, a passing full replacement correctness gate, a production fixed-memory performance gain, an end-to-end supported platform migration or compatible continuation codec sufficient to justify a pre-GEN-006 production change. An eventual approved state schema may establish a capacity need; it is not an input that can be inferred from the 8/16-bit experiment headers or the neutral high64 in C128 timing. [GEN-006 / #194](https://github.com/techrote/cybersand/issues/194) can finish a versioned, layout-independent semantic state/identity/persistence contract while these separate architecture choices remain unresolved. No production carrier/epoch/solver change or scheduling rewrite is authorized.

Retain **C72/C80 compact safe-memcpy** as the principal *small incremental payload* option and **C128 DUAL64** as the *larger contiguous capacity* option if an explicit schema really needs it. Both are experimental. No direct paired P2-versus-DUAL64 or fixed-memory production workload has been measured. No new benchmark is required to make the **retain/no-migrate** decision today.

## Unified source-qualified architecture matrix

Capacity is *logical carrier bits*; `+N` is additional *total logical capacity beyond C64*, **not** a count of approved new material fields. Stride/alignment are observed x86-64 GCC ABI facts for the tested carriers, not portable ABI promises; split is a physically separate dense chunk-owned tail array, not a contiguous 9/10-byte struct. MiB are **derived 2048² cell-array storage only**, excluding temperatures, activity, scratch, chunk metadata, allocation and total RSS.

Abbreviations: **S2A-Axx** active512/w4 with E8 vs C64-word baseline (except A01/A02 stated below), **S2A-Qxx** quiet2048/w1 with same-layout E16/E8 ratio (E8 cleared at sample tick256 and E16 did not); **S2P** active512/w4 E8 direct P2/P1 or P2/C64; **C128-A/Q** direct E8 paired comparisons against C80-aligned, including natural E8 clear. Every number is a **median of seven fresh-process B-mean/A-mean ratios**, except the *WCLEAR* event latencies in the separate section. No cross-campaign row ranking is valid.

| Architecture / tested epoch | Logical bits; +capacity | Physical bytes / align | 2048² cell array | Registered active ratio (original contrast) | Registered quiet ratio (original contrast) | Clear-event / correctness scope | Disposition |
|---|---|---|---:|---|---|---|---|
| **Production C64-E8** | 64; +0 | 8 / 8 | 32MiB | S2A A01 source→word 1.00160; source retained | E8 natural clear is baseline of S2A Q arms; no standalone E8 long-run cost estimate | Existing production and S0/S1 native controls; independent semantic/epoch validation | **Retained baseline** |
| C64-E16 word (experimental) | 64; +0 | 8 / 8 | 32MiB | No registered active E16 contrast | S2A A09 E16/E8 0.69118 (**different clear horizons**) | S1 two natural E16 rollovers, not wide-epoch natural timing | **Unresolved / needs qualification** |
| C64 padded E8/E16 control | 64; +0 | 16 / 8 | 64MiB | S2A A02 padded/word 1.02546 | S2A A10 E16/E8 0.52338 | No extra semantic capacity; two-epoch correctness as qualified | **Retained experimental control**; production padding **disfavored** |
| C72 P1 original packed E8/E16 | 72; +8 | 9 / 1 | 36MiB | S2A A03 P1/C64-word 1.49605 | S2A A11 E16/E8 0.09202 | Native S1 E8/E16 correctness; old byte-loop implementation | **Currently disfavored** |
| C80 P1 original packed E8/E16 | 80; +16 | 10 / 1 | 40MiB | S2A A04 P1/C64-word 1.51165 | S2A A12 E16/E8 0.09204 | Same qualified source/ABI context | **Currently disfavored** |
| C72 P2 safe-memcpy compact E8/E16 | 72; +8 | 9 / 1 | 36MiB | S2P P2/P1 0.657751; **direct P2/C64** 0.996224 | No admitted P2 E16 quiet timing | Untimed Linux E8/E16 S1-equivalence; S2P E8 natural clear in active measured horizon | **Promising experimental candidate** |
| C80 P2 safe-memcpy compact E8/E16 | 80; +16 | 10 / 1 | 40MiB | S2P P2/P1 0.663646; **direct P2/C64** 1.008852 | No admitted P2 E16 quiet timing | Same scope, 10-byte physical stride, extra16 neutral | **Promising experimental candidate** |
| C72 aligned E8/E16 | 72; +8 | 16 / 8 | 64MiB | S2A A05 aligned/C64 1.01991 | S2A A13 E16/E8 0.53216 | S1 Linux equivalence; no independent long-run clear cost | **Currently disfavored for capacity efficiency**; retained comparator |
| C80 aligned E8/E16 | 80; +16 | 16 / 8 | 64MiB | S2A A06 aligned/C64 1.01797 | S2A A14 E16/E8 0.52982 | C128 and WCLEAR use this kind of aligned footprint as their **own** controls | **Retained experimental control**; capacity efficiency **disfavored** |
| C72 dense split E8/E16 | 72; +8 | Base 8 / 8 + dense tail 1 | 36MiB + metadata | S2A A07 split/C64 1.00001 | S2A A15 E16/E8 0.72318 | Qualified split array/ownership as generated World control, **not** sparse allocation or sidecar mutability | **Unresolved / needs qualification** |
| C80 dense split E8/E16 | 80; +16 | Base 8 / 8 + dense tail 2 | 40MiB + metadata | S2A A08 split/C64 1.00194 | S2A A16 E16/E8 0.72394 | Same dense-tail limitation | **Unresolved / needs qualification** |
| C128 native u128 E8 (E16 untimed only) | 128; +64 | 16 / 16 | 64MiB | C128 active U128/aligned 0.991539; direct U128/DUAL64 1.005942 | C128 quiet U128/aligned **1.234276** | Natural E8 clear sampled; high64 neutral during timing; high-lane correctness separate | **Currently disfavored on tested quiet workload** |
| C128 DUAL64 E8 (E16 untimed only) | 128; +64 | 16 / 8 | 64MiB | C128 active DUAL64/aligned 1.002677 | C128 quiet DUAL64/aligned 1.009461 | Natural E8 clear sampled; high64 neutral during timing; high-lane correctness separate | **Promising experimental candidate** |

**Interpretation of the controls.** A01 measures source C64→abstraction C64-word and is not a new memory design; A02 tests *padding without useful additional payload*. Aligned C72/C80 and C128 all use 16 physical bytes but retain distinct logical fields and ABI behavior. C128 has +64 bits relative to 64, but **no semantic ownership** is yet adopted for its high lane. The base current layout has material16 + `state_a`16 + `state_b`8 = 40 bits before epoch; the public `Material` enum and adapters remain narrower than the material-storage mask. E24 can be carried within64 total bits, E32 requires at least72 under those intact fields. WCLEAR's E24/E32 result used C80 aligned only; it does not qualify an E24/E32 × every-carrier Cartesian product.

## What the accepted evidence establishes — and does not

**Compact safe-memcpy vs original packed.** S2P answers *yes*, for its exact active512/w4 E8 workload: P2/P1 seven-pair median 0.657751 (C72) and 0.663646 (C80), approximately 34.22%/33.64% less process-mean tick time, retaining 9/10-byte stride. Direct paired P2/C64 median 0.996224/1.008852 is **near unity, not certified parity** (respective seven-pair observed ranges 0.955452–1.071350 and 0.998306–1.029975). Frozen source and assembly show original P1 head-byte reconstruction/scatter loops versus GCC13.3's compact P2 64-bit `memcpy` head operations, explaining a plausible *implementation-specific* penalty. It does not prove unaligned-memory access is free, quantify cache effects or generalize to other compilers, platforms, field-access patterns, high-payload frequency, larger residency or worst-frame behavior. S2A's original P1 1.50–1.51× results remain valid and **are not retroactively retimed**.

**DUAL64 vs native U128 / aligned16.** In C128's direct active-E8 tests, U128/aligned 0.991539 and DUAL64/aligned 1.002677 have overlapping seven-pair ranges; neither establishes superiority. Direct active U128/DUAL64 1.005942 is similarly descriptive. In **quiet2048/w1 E8**, U128/aligned 1.234276 (1.218679–1.256161), whereas DUAL64/aligned is 1.009461 (0.989924–1.029310). Every U128/aligned quiet ratio exceeds1. Supplementary retained clear-frame partition, without changing full registered means, shows U128/aligned clear-inclusive ratio ~1.3490, 1.908–2.191ms paired event-frame excess, and ordinary255-tick median ratio ~0.99718. DUAL64 is thus the more useful 16-byte experiment to keep. **No direct quiet U128/DUAL64 contrast** was registered. Compiler-output low-word-only DUAL64 mutation vs native U128 high-lane preservation is evidence of different emitted instructions, **not causal proof** of the frame gap. It is not an x86 atomic128 contract, production fallback qualification or multi-platform speedup.

**Real WCLEAR behavior.** [The complete accepted 48-context matrix](../audits/2026-10-23-wclear-results.md) records 336 real clear events, seven pairs each, keeping all spikes. Quiet sleeping/excluded w1 event-inclusive medians in milliseconds:

| Epoch / resident cells | 512² | 1024² | 2048² |
|---|---:|---:|---:|
| E8 (natural) | 0.062092 | 0.467809 | 2.406053 |
| E16 (prepared) | 0.065046 | 0.486447 | 2.385403 |
| E24 (prepared) | 0.063403 | 0.474999 | 2.444518 |
| E32 (prepared) | 0.098465 | 0.543130 | 2.510146 |

The largest event-inclusive tick across the complete WCLEAR matrix was 4.739428ms; the largest paired event-minus-ordinary excess 2.509726ms. All 112 pairs at 2048² exceeded the historical 1ms **review trigger**, not an adopted statistical rejection rule. E16/E24/E32 events are actual `World::tick` clears from **prepared** near-rollover state, **not natural 65,536/16m/4bn-tick running histories**. E8 has a natural event. Because wide-epoch preparation writes stamps and changes store/cache preconditions, differences between rows do not establish a cross-width performance ranking. WCLEAR has diagnostics enabled and cannot serve as a paired clear-loop subtraction for diagnostic-disabled S2P/C128. Increasing epoch width changes **frequency**, not observed per-event resident traversal/hitch; it may exchange frequent visible E8 hitches for far rarer but still nonzero large hitches.

**Projected maintenance strictly separated.** From zero, first clear at `2^E`; following interval `2^E-1`. Conditional *steady interval* mean estimator for one registered WCLEAR context is `ordinary_median_N + paired_excess_median_D/(2^E-1)`; exact finite start periods remain distinct. This estimates neither actual long-run E16/E24/E32 process means, quantiles nor natural-clear tail/cold-cache risk. A 2048-tick sample with no wide wrap cannot make that decision. Even a narrow average advantage cannot by itself satisfy a worst-frame target.

## Fixed cells, fixed bytes and budget risk

| Dense-carrier family | Bytes per cell (array equivalent) | 128² chunk cells | 2048² arrays | Cells at the same C64 array-only budget (relative) |
|---|---:|---:|---:|---:|
| C64 word E8/E16 | 8 | 128KiB | 32MiB | 1.0000 |
| C72 packed/memcpy, or eager split base+tail | 9 aggregate | 144KiB + split metadata | 36MiB + split metadata | 0.8889 |
| C80 packed/memcpy, or eager split base+tail | 10 aggregate | 160KiB + split metadata | 40MiB + split metadata | 0.8000 |
| C64 padded, C72/C80 aligned, C128 u128/DUAL64 | 16 | 256KiB | 64MiB | 0.5000 |

This is exact **array arithmetic for fixed cell count**, and inverse arithmetic for a **fixed array-byte budget**. It is *not* measured total-world occupancy, effective cache footprint, performance at constant RSS, a valid comparison of adaptive sparse streaming worlds, or evidence that the simulation may halve capacity safely. An optional full-temperature array adds 2 bytes/cell, i.e. 8MiB at2048², independently. Split is eagerly allocated in the qualified World, not optional sparse sidecars, and has metadata/owner/move/invalidation costs. The S2A observed process RSS figures describe whole fresh processes only and cannot replace this accounting or establish fixed-memory throughput.

**Production budgeting guard:** [ADR-015](ADR-015-material-state-schema-and-carrier-gates.md) records approved *qualification targets* (256 resident128² chunks, 64 active cores, 512MiB aggregate cellular budget under2GiB process RSS, native60Hz, ordinary p95≤5ms/p99≤8ms, observed tick≤10ms, initial Linux+Windows scope). None is an accepted pass by these research campaigns; the reference Windows machine, authoritative high-state schema, allocation/refusal strategy and worst-frame policies remain undecided.

## Conditional recommendation and uncertainty

1. **If GEN-006 can serialize fully authoritative semantic state without selecting a new physical carrier:** continue GEN-006 contract work now on C64-E8. Keep generation/chunk identity, mutation receipts, paused state, Empty tombstones, solver/catalogue/schema/baseline versions and support/epoch rebasing independent from native struct bytes. Do not infer durable state from padding, 8/16-bit experimental spare capacity or wrapped update epochs.
2. **If a reviewed schema needs exactly +8 or +16 logical payload bits per resident cell:** P2 safe-memcpy C72/C80 is the *first* bounded expansion candidate, conditional on complete correctness, cross-platform codegen/performance, relevant high-state real workloads, memory and rollover admission. Original P1 byte-loop packed is not the production starting point.
3. **If a named schema demonstrably needs substantially more than16 extra bits on essentially all cells, and 16-byte storage fits the resident budget:** keep DUAL64 as the 16-byte test candidate. It uses the same measured array footprint as C80 aligned but offers neutral extra capacity; this is not an endorsement to allocate it by default. Native U128 currently has no demonstrated advantage over DUAL64 and a repeatable *registered quiet-E8* deficit versus aligned; preserve it as a diagnostic comparison, not as an automatically preferred C128 implementation.
4. **If new state is genuinely optional/sparse:** a bounded chunk-owned optional sidecar is a separate design hypothesis. S2A's *eager dense* split controls show neither sparse occupancy benefit nor correct allocation/migration/eviction behavior. A sparse implementation needs its own ownership, memory-refusal, move/reset, hash and persistence contract before performance comparisons.
5. **If epoch width changes independently of payload:** preserve C64-E8 as Current; E16/E24/E32 remain a *separate scheduler/clear policy decision*. WCLEAR has established a real per-event resident-hitch concern, not eliminated by width. A chunk-local/lazy invalidation strategy is an optional later separately scoped algorithm with proof obligations for missed cycles, reentry, cross-boundary writes, stale stamps and support predicates; this synthesis authorizes no scheduler changes.

The recommendation is explicitly **conditional** on a not-yet-approved semantic schema, budget, workloads, correctness, platform and lifecycle requirements. It is not a ranked cross-campaign benchmark, a quantitative game FPS forecast, or an accepted production winner.

## Truly missing evidence, in execution order

**No additional experiment is necessary to decide not to migrate production before GEN-006.** Do not run S2B or repeat any accepted measurement for this decision.

**Gate 0 — correctness, not a performance experiment:** resume the separately authorized process for the existing Windows 152-case R16-T1/containment replacement registration only after **new exact owner authority**. Latest `e655166` 32 Windows binary builds and admitted registration `9b1dbfb70d90102b1a95a9fedb360daab7e1d14036b13757bbeb05d1cc5dc59e` do not imply successful execution; earlier attempts retained real failures. Resolve full Windows cases, Linux equivalent high-state/consumer qualification and source identity before carrier adoption. Do not issue authorization here.

**Gate 1 — approve the actual semantic requirement and budgets:** establish authoritative high-lane use, initial/default/Empty/reset, Water conservation, optional state lifetime, support/epoch rebasing, cross-boundary move and GEN-006 continuation semantics. If it fits C64 or a versioned optional solver sidecar, **stop without a carrier benchmark**.

**Only genuinely useful new measurement if a migration still remains plausible:** preregister one paired **same-source / same-semantic high-state** comparison of C72/C80 P2 compact versus DUAL64, with the relevant C64/aligned controls, across the minimum two existing active512/w4 and quiet2048/w1 anchors, actual clear-inclusive frames, and both fixed-cell and explicitly controlled fixed-allocated-memory cases. Pin compiler/platform (including the actual Windows target after correctness qualification), field mutation frequency, temperature/sidecar allocation, resident maxima, failure/refusal handling, n=7 process pairs or separately justified statistical power, and exact mean/p95/p99/max/per-clear frame definitions; independently qualify observed/observer-off twins and register timing only afterwards. It is *not* yet authorized. This answers the actual compact-vs-DUAL64 crossover that no campaign has measured.

**If a wider epoch itself is then proposed for production:** separately qualify event-tail and real-World long-horizon/reentry/sleep behavior at the chosen memory envelope. WCLEAR prepared-event absolute latencies can remain bounded evidence; a truly natural wide rollover or a proved-equivalent controlled replay requires a distinct admitted protocol. Avoid 2^32 brute-force ticks without a feasibility/admission argument. Hardware counters/isolated low-level microbenchmarks may refine causal diagnosis but are **not** required to choose retain-C64 now.

## Preservation and downstream boundaries

No changes to original S0/S1/S2F/S2A, S2P, WCLEAR, C128 source, raw files, seals, registrations, reduction definitions, interpretation fields or failed attempts; no new benchmarks, owner authority, R16-T1 adoption, normal production code, native DLL, Godot runtime, Water/solver/LCB scope, serialization codec or GEN-006 streaming. [#204](https://github.com/techrote/cybersand/issues/204) stays open; neither stacked draft PR is promoted. Any future carrier migration requires an independent schema/correctness/performance decision, rollback/refusal and source-matched platform acceptance; this record is only a conditional architecture **synthesis**.
