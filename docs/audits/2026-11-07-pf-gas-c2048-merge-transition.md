---
title: Accepted C2048 main to exact PressureFlow gas hotpath reconciliation
status: Current
document-kind: evidence
scope: Explicit new reviewed source transition from accepted C2048 main to the optimized gas discovery operator
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [2026-11-07-pf-gas-exact-hotpath-transition.md, 2026-11-07-pf-gas-cached-seed-transition.md, 2026-11-07-pf-gas-label-mask-transition.md, 2026-11-07-pf-c2048-mat-auth-transition.md, ../architecture/pressure-optimization.md]
---

# PressureFlow gas optimization reconciled onto C2048 accepted main

Source integration for [PR #504](https://github.com/techrote/cybersand/pull/504) reconciled **accepted PR #491** (opt-in C2048 capacity and explicit CYPS5 contract) from the actual main commit `24a8bbe8ccf0d17196ebbab580b924930a964584` into the isolated performance candidate. **No work from in-flight PR #405 has been imported.** This is a new experimental source candidate, not a production admission or performance claim.

| Protected source | Accepted previous LF SHA-256 | New combined LF SHA-256 | Reconciliation source merge commit |
|---|---|---|---|
| `native/src/world_pressure.inc` | `71723fa32bbd29aafe93f1a8dd233cece1eec7ed295da81c1e021f635085c17a` | `899ada71b89d30ba063e047bdd5b02346948008f1b7c0bec9fa0f2272e4d86ec` | `d8b314deb8164f9641117a13fce286d23340936b` |

## Source merge discipline

The C2048 accepted source and its original `tools/material_catalogue/compatibility.py` canonically record the earlier linear transition `26051b0d...`→`71723fa3...` at source commit `5f107db52a2c002e19f5f8ff284cf8f4ebeeb421`. A two-parent merge commit `d8b314deb8164f9641117a13fce286d23340936b` **retains both accepted-main ancestry and the three experimental gas-performance source commits** (`250f91bc`, `6eab269b`, `731d2444`). Their original three audit documents and historical commits remain intact.

An unaccepted parallel experimental source-hash chain (`26051b0d...`→`a71d593a...`→`3f044246...`→`0753b354...`) cannot be appended to the already accepted *linear* C2048 MAT-AUTH list without falsely joining incompatible byte states. The canonical reviewed transition sequence therefore follows **accepted main** and appends exactly **one fresh reviewed C2048→combined** transition. No immutable lock, accepted entry or historical experimental Git commit is modified or deleted. The experimental audit records are retained as development evidence, not misrepresented as main's sequential admitted chain.

The resolver's gas flood/parallel seed section was verified **byte-identical between the pre-C2048 base and C2048 accepted main** before transplanting the exact optimized BFS/seed/cache/mask/ID lookup changes. Everything outside that section is the **accepted C2048 source**, including dynamic `state.parameters.gas_compartment_capacity` guards, opt-in gas capacity profile, reserved-ID refusal, CYPS5 save/restore and physical hash. The previously accepted dense lookup and cursor are retained.

Other updated C2048 files (`native/src/world.cpp`, `world_pressure_state.inc`, `world_pressure_gas_cache.inc`, `pressure_flow.hpp`, native tests, pressure capacity contract, retained runtime LFS/provenance files) are inherited directly from the accepted main tree. PR #504 adds only its disjoint test/CI files and this reconciled protected-source payload.

## Admission

The prior three-way benchmarks and 191 passing Windows MSVC tests were executed **before** the C2048 accepted source merge and are historical C1024 evidence only. The reconciled candidate requires fresh **accepted C2048 main versus combined-source** paired native timing, exact physical parity, C1024/C2048 capacity/admission/refusal/CYPS regression, one/four workers, Windows/Linux exact-head native and Godot, renewed source-matched compiled runtimes and independent review. PR #405 is still an independent owner. **DO NOT MERGE** on this record alone.
