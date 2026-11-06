---
title: PressureFlow gas-compartment capacity — native C1024/C2048/C4096 research
status: Current
document-kind: evidence
scope: Research-only #475: source-matched Linux native topology, exactness, persistence and cost observations; no production limit change, no policy admission and no merge
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [../architecture/pressure-flow-v1.md, ../architecture/liquid-prepared-setup-and-receipts.md, ../operations/configuration-and-capacity-budgets.md, ../reference/invariants.md, 2026-11-06-stress-canvas.md]
---

# PressureFlow gas capacity — research qualification, 6 November 2026

## Decision and authority boundary

**Research disposition: C2048 is the preferred *next experimental admission candidate*; no production decision.** The existing 1,024 ceiling and default FreeMass Water remain unchanged on `main`. Do **not** merge #475, change the default, silently coarsen gas pockets, update goldens, change the pressure equation or rewrite historical capacity refusals. A separately commissioned independent read-only acceptance review, followed by explicit owner authorization, is required before selecting any production transition.

Research PR: [#475](https://github.com/techrote/cybersand/pull/475), created from the merged [#406](https://github.com/techrote/cybersand/pull/406) source. The isolated research branch uses one source with `CYBERSAND_PF_GAS_CAPACITY=1024|2048|4096`; absent the flag, the compiled ceiling remains **1024**. The 16,384-cell atmosphere law, 65,535-region limit and 64 retirement-record history are unchanged.

Research raw evidence is retained by GitHub Actions, **not committed into the source tree**:

- [120-tick hosted initial pass 42298235461](https://github.com/techrote/cybersand/actions/runs/42298235461), source `2cedcffb33edf749d37e04bf33ac750e3a33669c`, artifact `13542918227` (PASS).
- [300-tick source-pinned execution 42299965145](https://github.com/techrote/cybersand/actions/runs/42299965145), source `dbdef3471cddb23d9aa2378a2e18c6615d521bf8`, artifact `13544721572`. Native cases and comparisons ran, but the workflow ended **FAIL** at the old-decoder negative test: Bash's inherited errexit aborted on the expected exit code 7. The failed original is preserved.
- Follow-up `ac887c1a1457cbeeb24fb8ee92b6050a4275c873` explicitly validates the decoder refusal and its text. Research branch merge `c4dd222e59217e94fa098a6cf24b5668ec913d71` incorporates `main` `7e2c2fd1aa2759590d63d5dfb53ce9e4c0a76e4b` while preserving the research diff. [Reconciled-head scoped run 42312272377](https://github.com/techrote/cybersand/actions/runs/42312272377) is the required source-specific qualification record; inspect its completed steps/artifacts, not historical statuses.
- A separate 900-tick exploratory replay used the **same archived Linux GCC 13.3.0 executables** from `dbdef347`, independently SHA-256 matched (C2048 `55c346d1c85fa8a97ba5255e4d4d66e9a1377fd62da5133ff63c5ebb8f62db9c`; C4096 `75f636451c8031d15900b35a84c7dd1f04978f28e8672dbfc52c668523382f2d`), on a Xeon Platinum 8573C Linux 6.18.57 host. Its two 901-row CSVs are retained with a SHA-256 manifest in the research conversation, **not a published GitHub Actions artifact**; distinguish this supplementary run from hosted CI qualification.

The actual authored Godot workbench fixtures were exported from `workbench_setup.gd`, not approximated by the earlier synthetic geometry census. Stress-canvas fixture SHA-256: `5ba5a349bcb8afed7582a04f2225e82a28d54a89a180f18f3aa46d23f0cd79c4` (2048×1024, 129 merged rectangles). Bench-canvas SHA-256: `0dd1b2088924e191bd150229339a0e32072d2c1420aeb67d27cefc3d469dd9ed`; my-canvas: `1fa48289c5f831cf9ab9612f1886d7b20bc2be4916f38208d5fe4e72d60f0de2`. Toolchain: Ubuntu 24.04/GCC 13.3.0, C++20 `-O2 -DNDEBUG -pthread`, research variants built separately.

## Native measured outcomes

| Native workload / measure | C1024 | C2048 | C4096 |
|---|---:|---:|---:|
| Default authored demo initial preflight | refuses at early stop 1025 | complete census **1175** | complete census **1175** |
| Default demo after 300 ticks | fails first tick | completes; live 0 at t300 | completes; live 0 at t300 |
| Stress canvas initial compartments | 0 | 0 | 0 |
| Stress canvas last completed tick in hosted 300-tick trial | **124** | **300** | **300** |
| Stress canvas refusal | tick **125**, quarantine | none | none |
| Stress peak through tick 300 | 975 before failure | **1314 at tick 133** | **1314 at tick 133** |
| Stress live at tick 300 | not reached | **506** | **506** |
| Supplementary Linux stress completed ticks | not tested | **900**, no refusal | **900**, no refusal |
| Supplementary stress live at tick 900 | not tested | **479** | **479** |

At t125 the high-capacity control has **1048** live compartments, explaining why the C1024 World fails before completing that tick. At t133 the peak **1314** consists of **1031 one-cell**, 95 two-to-four-cell, 56 five-to-sixteen-cell and 132 larger gas compartments. Median volume is 1 cell, p95 64. Geometry (including small Water-adjacent pockets and dynamic voids) therefore drives live-table occupancy; this is not evidence supporting a silent gas-law change.

The supplementary 900-tick C2048/C4096 replays both produced 901 initial-plus-completed observations, zero failed Worlds, closed gas ledgers and **zero mismatches in 19 recorded authoritative fields** over all 901 rows. The first 301 C2048 snapshots match the independently preserved hosted 300-tick records. This is useful extended evidence, but differs from a target-platform acceptance suite or full multi-run statistical study.

## Exactness, save and accounting

The `dbdef347` archive was independently inspected: C1024 and C2048 have identical recorded authoritative fields through C1024's last successful tick; C2048 and C4096 remain identical through tick 300. Twenty-one sets of sampled canonical CYPS saves were compared by SHA-256, with **no differences** between capacities represented in each set. The nine low-ceiling cross-decoder restores were successful. The repaired [research workflow](../../.github/workflows/pf-gas-capacity-research.yml) also checks that the C1024 decoder refuses the 1175-compartment high-capacity CYPS with exactly the expected count-bound failure, while C2048 and C4096 decode it successfully.

The reference/cached/cached-dormant and configured 1/4-worker comparisons use [`PressureVariantEquivalenceV1`](../architecture/pressure-flow-v1.md#liquid-comparison-projections), since raw variant-specific physical hashes intentionally differ. The native harness reports gas identities, lineage, amounts, volumes, gauges, gas/quantity ledgers, physical hashes and serialized bytes. **Configured workers alone do not prove actual participant count.** Independent full-host and Windows execution remain separate gates. Every simulation failure is an explicit failed-World quarantine, not a successful tick.

No historical golden/hash is regenerated. No production default, physical law, gas history capacity, 16-bit region layout, CYPS schema or public catalogue/policy digest was intentionally changed by this research.

## Capacity-dependent implementation and costs

- [`pressure_flow.hpp:15–25`](../../native/include/cybersand/pressure_flow.hpp): fixed capacity and independent 16,384-cell volume limit.
- [`world_pressure_state.inc:73–90`](../../native/src/world_pressure_state.inc): 65,535-region, 8,192-overlap, 1,024-chunk-node bounds and two compartment tables, union-find, order and member reservations.
- [`world_pressure.inc:610–668`](../../native/src/world_pressure.inc): 16-bit visit region marks; region saturation is separate from live compartment capacity. [`world_pressure.inc:887–905,989–1006`](../../native/src/world_pressure.inc): checked creation/split and quarantine; [`:2769–2795`](../../native/src/world_pressure.inc): CYPS count and per-record bound validation.
- [`world_pressure.inc:87–89`](../../native/src/world_pressure.inc): fixed `gas_coverage` array in retained workbench transfer; [`world_pressure_cache_state.inc:29–40`](../../native/src/world_pressure_cache_state.inc) and [`world_pressure_gas_cache.inc:114–115`](../../native/src/world_pressure_gas_cache.inc): derived cache reservation and fallback.
- [`pressure_setup_capacity.hpp:14–19,29–109`](../../native/include/cybersand/pressure_setup_capacity.hpp) plus [`prepared_world.hpp:36–54`](../../native/include/cybersand/prepared_world.hpp): initial seeded-gas census and typed, non-mutating refusal. The early-return count 1025 is *not* the full demo count.
- [`liquid_solver_policy.hpp:300–319`](../../native/include/cybersand/liquid_solver_policy.hpp) and [`liquid_run_receipt.hpp:253–257`](../../native/include/cybersand/liquid_run_receipt.hpp): policy/typed native receipt encode the family parameters, **not the compiled compartment ceiling**. The [GDExtension parameter readback](../../godot/native_extension/cyber_native_cell_world.cpp) exposes it, but an explicitly versioned applied-capacity/run identity would be necessary for future admission.

Actually observed World-owned topology reservations (bytes) from the debug-only capacity readback: **5,487,172 / 5,712,452 / 6,163,012** for C1024/C2048/C4096. Increments over C1024: **225,280 B / 675,840 B**. Cached derived state adds approximately **90,112 B / 270,336 B** over its C1024 counterpart; the cache member allocation is included in those derived figures and must not be counted again. Per-process RSS is noisier than these fixed reservations.

On the **same 124 successful stress ticks**, observed single-run reference means were **137.47 / 136.65 / 135.92 ms** (C1024/C2048/C4096). These are not paired statistical estimates and do **not** establish a capacity-induced speedup or cost regression. Total native tick time is not equivalent to gameplay FPS or a full Rapier/Godot cost.

## Options and independent owner decision

1. **Retain C1024**: zero migration cost, but preserves real demo refusal and stress tick-125 failure. Existing LCBH-019 and all native/host refusal expectations remain correct.
2. **Trial C2048 explicitly (research recommendation)**: enough for the measured 1175 initial demo and the 1314-compartment 900-tick stress peak; +225,280 B World topology reservation. Does not guarantee other later or more fragmented scenes. Owner must approve a capacity contract, negative-fixture successor and identity treatment; default stays C1024 until then.
3. **Trial C4096**: more safety margin (+675,840 B topology), but no measured physics or full-tick advantage on these scenes. Needs a positive added workload justification before selecting it over C2048.
4. **Configurable/admitted capacity**: more extensible, but needs `WorldConfig`/policy/versioned receipt and save/restore decision, bounded-construction cost and cross-capacity migration tests, not merely a macro.
5. **Tiny-pocket vacuum/merge law**: *not this work*. It changes gauge, label identity, gas amount, split/merge/vent accounting, conservation and registered LCB science. Requires a separately approved physics-law experiment and new negative controls.

Before any implementation admission, independently verify source/fixture provenance, the entire result artifact, 1/4-worker actual participation, high-capacity cached/dormant cases, CYPS old/new decoder behaviour, per-World memory and the correct native/host platform matrix. Update `pressure-flow-v1.md`, `liquid-prepared-setup-and-receipts.md`, configuration/capacity references, [LCBH-019](../reference/invariants.md), native pressure and setup capacity tests, cache tests, Godot default/Trial host refusal fixtures, receipt/version acceptance and any source-bound retrieval examples. **Do not replace historic refusals with newly qualified positives.**

### Protected-source admission hold

The experimental measurement adds a read-only `pressure_topology_reserved_bytes()` observation to protected `native/src/world_pressure.inc`. The ordinary documentation/provenance workflow correctly refuses unreviewed LF-byte drift under the [MAT-AUTH rule](../operations/material-catalogue-shadow.md#reviewed-per-file-transitions). That failure is **not a physics benchmark failure** and must not be bypassed by changing the lock, its baseline, policy digests or the gate. An independent per-file review and owner-approved `REVIEWED_TRANSITIONS` entry, or a reviewed design that removes the protected edit, is required before any production integration.

**No merge. No production capacity change.** The independent reviewer should provide `ACCEPT RESEARCH EVIDENCE`, `REPAIR RESEARCH`, or `INSUFFICIENT EVIDENCE` separately from any later owner decision to admit C2048/C4096.
