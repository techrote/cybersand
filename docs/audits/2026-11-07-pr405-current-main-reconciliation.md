---
title: PR 405 current-main composed PressureFlow and chunk-cache transition
status: Current
document-kind: evidence
scope: Explicit protected-source identity, #405 historical preservation, current-main reconciliation and remaining qualification
last-reviewed: 2026-11-07
related-documents: [2026-11-05-lcb201-moving-camera-invalidation.md, 2026-11-06-hard-surface-packet-incremental.md, ../architecture/pressure-optimization.md]
---

# PR #405 — current-main reconciliation and protected-source transition

This record accompanies the **candidate** (not final acceptance) of #201's three
native optimizations. It does not supersede the historical qualification or
claim an independently reviewed, accepted runtime.

- Protected consumer path: `native/src/world.cpp`
- LF SHA-256 before: `8bf0cb0058b139c32c030f5bbbc7e7e4555814c601598e1d6c7abecf7397d7fb`
- LF SHA-256 after: `84817f013e8689d26ee584d45102610d058c864a5b3de9194efdb0d3a152cfdd`
- Protected change source commit: `6d567730038ae45b6634ab35dccfeab008a0c6b0`
- Previous main: `3d953ed1c1f5bd0bcf582359d47863689b9e2310`
- Original #405 head: `438a6779f31f162082267424bf7bdbf8dcc255f8`
- Merge ancestry: original #405 first parent, accepted main second parent.
- Historical source qualification: 59 passing checks at the original head;
  these are **not** current-main acceptance evidence.

## Composition and design choices

**A / moving-camera PressureFlow.** Port Claude's removal of region-motion
`cache->cold()` and retain the independent settled-discovery inclusion wake.
Real gas, cell and owned-state mutations still take their existing invalidation
paths. Includes native reference/cached/cached_dormant gas-on/off camera,
region-shrink and boundary coverage and the updated Godot worker control.

**B / chemistry.** Adopt the already-merged constant material-partner bitset
`kPairPartners` and `may_pair_react` from current main. This implements the same
eligible-pair rejection fast path, without introducing Claude's duplicate
256-entry table. The existing RNG roll, neighbour order and authoritative
`pair_reaction` invocation for eligible pairs remain intact.

**C / chunk lookup.** Keep main's owner-maintained dense chunk directory as
the first lookup. For out-of-directory hash-map probes, port Claude's one-entry
thread-local `{generation, coordinate, pointer}` cache. A global monotonic
generation invalidates on insertion, clear and both sides of World move.
The separate direct `World::operator=(World&&)` regression exercises an already
populated destination, two concurrently living Worlds, same-address reuse,
and ordinary-vs-moved state/physical hashes across 1- and 4-worker ticks.

**Alternative rejected:** wholesale replacement of main's World with #405's
pre-#406/pre-#470 World would drop ballistic quantity ownership, lockstep
groundwork, dense chunk lookup and incremental collider publication. Branch
historical MAT-AUTH transitions form a fork from the old source and therefore
must not be appended after #470's protected-source chain. The single composed
transition above advances the actual current-main source without rewriting
historical SHA-256 evidence.

## Qualification still outstanding

The combined candidate has not yet passed new exact-head native, sanitizer,
Godot, Windows platform, collider-packet, material, docs or performance tests.
Retained Windows/Linux native libraries still come from accepted main, not this
new source. Only the repository's approved source-matched publication workflow
may update them. No new performance improvement, reviewer approval or merge is
claimed by this record.
