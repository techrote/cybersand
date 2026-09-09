---
title: Experiment Tower and transport comparisons
status: Current
document-kind: runbook
scope: Shared five-floor recipe, exclusive owner controls and issue 13 transport evidence
canonical-for: [experiment-tower, transport-comparison-procedure]
last-reviewed: 2026-09-09
related-documents: [physics-characterisation.md, ../systems/granular-interaction-policy.md, ../audits/2026-09-09-issue-13-transport.md]
---

# Experiment Tower

## How do I open and reset the experiments?

**Current reference checkpoint:** desktop has an Experiment Tower button and F9.
The native Web menu includes Experiment Tower. Both consume the same
[recipe](../../godot/scripts/experiment_tower.gd) through `CyberDemoWorlds` and
`CyberDemoBridge`. Existing demos retain their recipes. The lab starts paused;
floor selection places the player on a safe shaft landing and pans the camera.
Arrows pan horizontally to the remaining bays; A/D and Space provide normal movement.

Floors contain flowing powders; Water/Sand slopes and settling; eleven liquids;
packed, poured and excavated Mercury references; and separated chemistry.
Amber bottom plugs can be erased or opened with the tube selector, singly or
with their neighbour. Sequence releases use offsets 30 and 90 from the command
tick. Fresh tower restores deterministic recipe version 1, seed 0 and selected
floor. The first reference preset is Baseline. Tuning/transport are **Planned**
in the next checkpoints of this issue, not established by the initial tower.

Chemistry is deliberately unchanged. Materials may age before their release.
The owner reports that an earlier reduced fire cadence made Wood smoulder while
Oil and Coal felt good. This is owner feedback for later chemistry work, not a
new measurement or authorization to retune combustion here.

## Who owns tower commands and what is bounded?

Desktop `CyberSimulationWorker.queue_lab` copies one latest pending command under
its mutex. The worker constructs the candidate through the native bridge outside
ticks; only successful installation replaces authority. Web controls operate at
their synchronous main-thread owner boundary. Native workers call no Godot APIs.
Single-step executes one tick while paused. Recipes obey the existing 4096-record
and eight-world-area construction budgets, without changing cell or CYSD1 layout.
Lab observations retain at most 256 control inputs and two scheduled releases.
Current snapshot metadata is copied; it exposes no mutable native storage.
Ordinary camera interest filtering remains in use; other floors are not forced
to simulate and exclusion never represents elapsed simulation work.

## Which reference fixtures precede solver changes?

[transport_characterisation.cpp](../../native/bench/transport_characterisation.cpp)
defines packed Mercury, Sand poured onto a slope then Mercury at tick 300,
Sand/Dust coflow, Water release at tick 30 over Sand, loose grains and a 32-unit
Water film control. Five translations include negative coordinates and core/chunk
seams; each runs one/four workers for 1800 ticks. Every 60 ticks records exact
content identity, species counts and Water mass. Seed is a translation, not a
new random stream. Input timing is independent of wall clock and workers.

Run `tools/physics/issue13.py --output <raw>` to rebuild before executing. Pass
`--reference <baseline/references.json>` to reject any Baseline content drift.
Raw results belong under `C:/kybersand/validation/local`; the
[dated audit](../audits/2026-09-09-issue-13-transport.md) owns acceptance and gaps.
Native counters do not constitute visual approval of the poured Mercury feel.
