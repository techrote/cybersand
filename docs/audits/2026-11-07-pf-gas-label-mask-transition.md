---
title: PressureFlow gas label memoization and absent-mask hotpath transition
status: Current
document-kind: evidence
scope: Third bounded read-side gas hotpath source transition, no identity or law change
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [2026-11-07-pf-gas-exact-hotpath-transition.md, 2026-11-07-pf-gas-cached-seed-transition.md, ../architecture/pressure-optimization.md]
---

# Gas old-label index hint and absent-mask fastpath

Experimental performance [PR #504](https://github.com/techrote/cybersand/pull/504) continues without importing the concurrent native changes on #491/#405. This append-only reviewed transition authenticates the **third** exact-source candidate; earlier source commits and audit records remain unchanged.

| Protected source | From admitted LF SHA-256 | To LF SHA-256 | Authenticated source commit |
|---|---|---|---|
| `native/src/world_pressure.inc` | `3f044246d306c8c56b072d3d040beebaf8d2aa04fb713eaebdd2e6a231511a9d` | `0753b354e88f659759b5b5d800850b77c081b687874d701f2b3ee898710ebb3e` | `731d2444ef7bb367587e31d3c1d4eca921eca086` |

During single-threaded BFS discovery, every old compartment ID lookup previously performed a binary search of the *unchanged, sorted* old compartment table. This candidate memoizes the last **successfully validated** ID and its corresponding ordinal, returning that ordinal for repeated same-ID cells without changing the valid ID set or retired-ID refusal. The old compartment table is only swapped **after** BFS, so the memoized index remains stable. On a new ID the original sorted lookup and error are unchanged.

The transient mask has one authoritative occupied-index set, which is not mutated during the phased gas discovery. If empty, no body IDs remain set, so gas BFS visitation and Water seed probes can skip per-cell `transient_obstacle_at` calls. When occupied, all existing checks remain. No compartment ordering, overlap accumulation, 16,384 atmosphere bound, labels, gas pressure heads, conservative amounts, warm/cold cache, retained physical hash, CYPS bytes or C1024 capacity policy is altered.

Prior [paired native run 42331636322](https://github.com/techrote/cybersand/actions/runs/42331636322) compared candidate revision 2 to accepted main on **the same Linux runner** and passed 72 pairs of full 40-tick physical hash traces, achieving 4.98% median gas-on native tick improvement. **No third-revision timing or acceptance is claimed by that previous run.**

This third source commit requires a new exact-head A/B and complete native suite, Windows source-built tests, documentation/MAT-AUTH compatibility checks and source-matched Linux/Windows Godot DLL publication before any guarded merge. The immutable historical material lock and earlier reviewed transitions are preserved. Merge with ancestry preserving source commits.
