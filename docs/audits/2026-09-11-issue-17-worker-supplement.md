---
title: Issue17 concurrent-worker validation supplement
status: Current
document-kind: evidence
scope: Preregistered focused concurrency validation before timing; no new precision comparison or solver change
canonical-for: []
last-reviewed: 2026-09-11
related-documents: [../operations/state-precision-experiment.md]
---

# Concurrent-worker validation supplement

Registered before its implementation/execution and before timing, September11.
The compact primary fixtures use threshold1 and the actual four-worker pool, but
their compact phase geometry does not require several jobs in the same phase.
Add one focused native test for each of the eight configurations: four copies of
the registered48-wide basin at x offsets0/128/256/384, y0, closed independently.
Use production geometry and quiet3, threshold1, prepared region{-128,-128,768,512},
capacity64 chunks,512 cores,64 active chunks. Two runs each at workers1/4,
1800 ticks, diagnostics enabled; assert at least one phase has four jobs,
exact384*M integer quantity in each basin every tick, and matching canonical
mass/delay/material fingerprints and work every tick across all four processes.
This exercises simultaneous independent write domains with the existing scheduler.
No sleep threshold, precision rule, timing fixture or source semantics changes.
Build/run sequentially after the current behavior campaign and before timing.
All source/compiler/command/artifact/output identities go in the local supplement
manifest; retain any failure. Existing native55 tests cover failure/region/ownership
contracts at reference mass8. This supplement extends concurrency coverage to every
registered precision/threshold/delay configuration without asserting new platform
or cross-ABI acceptance.

## Executed result

All eight configurations passed the registered test. Source/artifact identities
and individual build/run logs are in validation/local/issue-17/workers-20260911-110341.
Four simultaneous phase jobs were actually exercised; each1/4-worker repeated
run conserved all four basins every tick. No runtime correction or rerun.
