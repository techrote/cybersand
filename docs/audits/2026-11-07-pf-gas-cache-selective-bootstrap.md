---
title: PressureFlow gas-cache admission NO-GO and sparse relabel implementation
status: Proposed
document-kind: audit
scope: PR #532 causal diagnosis, rejected cache bootstrap, bounded replacement and qualification record
last-reviewed: 2026-11-07
related-documents: [../architecture/pressure-optimization.md, 2026-11-07-pf-gas-selective-cache-transition.md]
---

# PressureFlow gas-cache admission NO-GO and sparse relabel implementation

## Source baseline and existing evidence

PR #532 branches from accepted main `81bbd5ff5cf366159e2b8a630609359c13560080`.
It does not import the #504 BFS/seed fast paths or rewrite #505/#515/#522.

Existing application evidence established one complete gas reference pass per
gas-enabled tick, zero cache/component reuse, and a much smaller real-workbench
benefit than #504's isolated native result. PR #532 therefore bounded its first
investigation to the existing cache admission path.

## Bounded cache investigation — NO-GO

The current cache already has selective component replay and dirty-chunk
invalidation, but component summaries are normally built only after the
complete gas operator reaches a global fixed point:

`!topology_changed && !labels_changed && chunk_allocations == 0`.

PR #532 first tested whether that global prerequisite was unnecessarily keeping
otherwise stable components cold. A bounded experimental bootstrap constructed
candidate summaries from one completed authoritative pass, retained the
owner-reduced dirty set and invalidated dirty-adjacent components before any
future replay.

The workbench-derived exact-input diagnostic disproved that hypothesis for the
target workload:

- 264 gas-enabled ticks;
- 1,659 component proof checks;
- one 2,097,152-cell component-build scan;
- zero member initializations;
- zero member builds;
- zero cache builds;
- zero component reuses;
- zero capacity or pair-budget fallbacks;
- 22,094 dirty chunks queued cumulatively;
- 54,537,949 authoritative BFS cells;
- 572,309,504 seed cells and 572,309,504 relabel cells.

Thus the cache was not merely being refused by the global fixed-point gate or a
capacity budget. Under continuous authored-workbench churn, no region inspected
by the existing strong component proof qualified as a safely reusable sealed
component. The experimental bootstrap is therefore rejected rather than
weakening the proof or forcing unsafe reuse.

The same exact-input run compared accepted main with the experimental candidate
for 264 ticks in each of four source lanes (1/4 workers, camera off/on). All
1,056 source-paired ticks matched physical hash, quantity digest, gas digest,
Water quantities, gas ledgers and compartment counts exactly. The failure was
strictly “no useful cache opportunity”, not a physics mismatch.

## Implemented lower-cost alternative: sparse authoritative relabel

The reference gas operator remains the oracle. PR #532 now leaves its seed
census, BFS, identity/lineage reducer, quantity law and whole/component cache
admission unchanged.

The measured redundancy is instead in the final label publication sweep:
the diagnostic examined ~2.17 million resident cells per gas tick for relabel
while the BFS actually visited ~207 thousand cells per tick.

Execution v5 adds bounded derived bookkeeping to cached variants:

1. Two construction-time bits per admitted resident cell retain the current
   and immediately previous authoritative BFS visit sets.
2. The existing owner-reduced gas-dirty chunk set is retained until relabelling
   finishes rather than being drained immediately after cache invalidation.
3. Every gas-dirty chunk executes the original complete relabel scan.
4. A complete scan records whether a chunk still contains any unvisited,
   positive live gas label under material or transient-mask occlusion. Such a
   chunk remains on the complete-scan path because a remote split/merge could
   later retire that label.
5. Only a clean indexed chunk with no latent-label obligation may publish labels
   by iterating the union of the current and previous exact BFS visit sets.
   Prior-only cells are deliberately revisited so a remote vent/split that makes
   a formerly visited cell unvisited cannot strand a stale positive label.
6. Missing prior-visit history, dirty-set overflow, cache/index uncertainty,
   gas-cache replay, gas-pass chunk allocation, or a malformed visit/bit
   relation falls back to the original complete relabel sweep.

The complete scan's dangling-label retirement rule is retained exactly. Sparse
relabelling therefore does not infer topology from visible pixels, Water
quantity, pressure stability or apparent motion; it merely avoids revisiting
cells that the authoritative BFS did not touch when the owner already has a
complete proof that no hidden positive label needs retirement.

## Cost and authority boundary

The new storage is bounded at cache construction: two bits per admitted cell plus
one latent-label byte per admitted chunk. It is derived, nonserialized and
reported through existing gas/derived capacity accounting. There are no
per-tick heap allocations and no per-cell atomics.

The pressure-optimization execution identity advances from v4 to v5. Physical
state, gas IDs/generations/parents, gas quantities, pressure law, C1024/C2048
capacity identities, CYPS/hash semantics, Water defaults and save authority are
unchanged.

## Qualification gates

The exact-source deterministic replay and actual 2048x1024 eight-Rapier-barrel
B-C-C-B CPU qualification are branch-scoped gates:

- deterministic replay: `pf532-gas-cache-identical-replay.yml`
- actual gameplay CPU/workbench: `pf532-fullsize-cpu-physics.yml`

The deterministic gate requires exact per-tick physical/gas/Water parity across
accepted main and PR #532 and exact 1/4-worker parity. It additionally requires
unchanged seed/BFS/reference-pass/component-cache work and a relabel-cell
reduction in every lane.

The workbench gate builds accepted main and the exact PR head with the same
compiler and temporary identical stage probes, then executes the original
2048x1024 `stress-canvas` with eight live Rapier barrels in balanced B-C-C-B
order. It records native tick p50/p95, gas wall/process/owner CPU, discovery,
identity and relabel CPU windows, cache work/memory, actual worker
participation and conservation checkpoints.

**No performance GO is asserted until those final sparse-relabel measurements
complete.** If real gameplay CPU does not improve by more than the maintenance
cost, execution v5 is a NO-GO and must not be integrated.
