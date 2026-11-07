---
title: PressureFlow gas cached pooled seed candidate transition
status: Current
document-kind: evidence
scope: Second bounded exactness-preserving PressureFlow optimization source transition
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [2026-11-07-pf-gas-exact-hotpath-transition.md, ../architecture/pressure-optimization.md]
---

# Gas cache + parallel seed prefilter — candidate transition

PR [#504](https://github.com/techrote/cybersand/pull/504) continues the same isolated experimental branch. The first exact intra-chunk read candidate measured **2.43% median paired gas-on native tick improvement** (72 source-matched pairs, 3 repeats per finite configuration, 40 ticks; [run 42330932992](https://github.com/techrote/cybersand/actions/runs/42330932992)). This alone is not a sufficient performance result.

| Protected source path | Previous reviewed LF SHA-256 | New LF SHA-256 | Source commit |
|---|---|---|---|
| `native/src/world_pressure.inc` | `a71d593a7ce3831e96f8bae47f5ff520ea75220da0ce94314d6d9ffc57960641` | `3f044246d306c8c56b072d3d040beebaf8d2aa04fb713eaebdd2e6a231511a9d` | `6eab269bebd70e4bb4fa98dc108f77afbc919ae8` |

The second edit lets the already accepted parallel seed-prepass run when a *derived*, valid gas-component cache exists. A cache replay validates actual cell membership before writing any visit stamp. Any stale cache proof sets `retry_requested`; the pooled candidate scan now checks that flag at both task and bitset-inner-loop boundaries and executes the original *one complete uncached* restart **before** the authoritative identity reducer. The prefilter conservatively includes all Water/Empty seed candidates; it does not skip potentially actionable seeds based on the cache or globally dormant assumption. Gas laws, ordering, labels, gauge/amount/revision, output material state, history and declared C1024 profile remain unchanged.

This append-only provenance record must not be treated as scientific acceptance. The prior source commit `250f91bc4bb41d5ec0c8115933d87ade5648aa5e` and its previous audit remain reachable, not rewritten. The immutable material identity lock is not changed. The ongoing opt-in C2048 PR #491 and moving-camera PR #405 are still outside this isolated branch pending authorized reconciliation.

**Required:** fresh 72-pair native execution including reference/cached/cached_dormant and 1/4-worker physical hash parity; exact-head Native and Godot Windows/Linux source-built execution; sanitizers; strict MAT-AUTH and source-matched runtime artifacts; independent review. A changed source hash invalidates previous timing/acceptance, even if earlier run passed.
