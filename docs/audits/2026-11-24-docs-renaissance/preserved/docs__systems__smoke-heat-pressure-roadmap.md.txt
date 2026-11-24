---
title: Smoke, heat, and pressure roadmap
document-kind: design
canonical-for: [smoke-behavior, optional-heat-pressure-fields]
status: Current
scope: Implemented native and fallback Smoke, limited temperature use, and unimplemented heat/pressure/composition fields
last-reviewed: 2026-09-08
related-documents: [materials-and-rule-kernels.md, water-design.md, activity-dirty-regions-and-waking.md, ../decisions/ADR-006-gpu-compute-deferral.md]
---

# Smoke, heat, and pressure roadmap

**Current:** Smoke is a discrete material with buoyancy and intentional
non-conserved decay. Optional temperature storage exists and Rocket reads it,
but there is no heat-conduction solver. General pressure and gas-composition
fields are **Planned**. Local body-pressure impulses and liquid comparisons do
not establish such fields.

These are source claims for the [secured checkpoint](../operations/source-checkpoint-and-recovery.md).
Dated runs are in the [evidence ledger](../reference/validation-evidence.md).

## Current native Smoke

[MaterialRules](../../native/include/cybersand/material.hpp) names material ID 4
`Smoke`, with `Gas` as an alias. In
[World::update_rule_kernel, RuleKernel::Gas](../../native/src/world.cpp), Smoke
attempts up, both up-diagonals, then lateral movement. An Empty target permits a
move; a denser movable target permits an exchange only when its descriptor
accepts density exchange. Wall and the Mite/Rocket agents opt out. Numeric
density alone does not imply permeability.

Smoke starts with `state_a = 240`. On its coordinate-staggered eight-tick lane,
it loses one lifetime unit, or two when at least five of the eight neighbors
are Smoke. At the final decay sample it becomes Empty. Movement changes the
coordinate-dependent phase, so this is not a universal lifetime in seconds.

Trapped Smoke uses `keep_cell_active` between samples. The ignition helper
excludes Smoke: ordinary heat-contact/Fire ignition does not turn it into Fire.
The owner-approved visual intent is a lingering cloud with slow internal
collapse, substantially slower than Foam, without an extra full-world age scan.
Further artistic tuning is **Planned**.

## Desktop fallback Smoke

[CyberCellWorld](../../godot/scripts/cell_world.gd) lacks the native authoritative
lifetime byte. Its hazard is disabled for the first 64 world ticks, then uses
a slower coordinate/tick sample. This is not a 64-tick grace period for every
newly painted Smoke cell. It approximates the appearance intent but does not preserve
native decay timing or state equality. Web requires the native cellular adapter;
“compatibility Web” does not mean this GDScript fallback.

## Temperature is storage plus a limited input

[World::ensure_temperature_field, temperature, set_temperature, and move_cell](../../native/src/world.cpp)
manage an optional signed 16-bit array per chunk, initialized from
`WorldConfig::ambient_temperature`. Ordinary movement carries stored temperature
with cells. Explicit setters can alter values; the Rocket kernel can launch at
a temperature greater than ambient + 400.

No conduction stage evolves temperature between neighboring cells. Existing
Lava/Ice/Steam/Molten Glass reactions use material identity and compact state;
their names do not imply a conserved heat equation. Units, physically calibrated
thresholds, and a general source/sink accounting model are undefined. Exact
storage defaults belong to [configuration](../reference/configuration-reference.md).

[Native fixtures](../../native/tests/test_world.cpp) cover optional storage and
selected material reactions, Smoke density exchange, lifetime/culling, Fire
exclusion, and conserved Water during selected exchanges. They do not validate
a nonexistent field solver or a complete reaction matrix.

## Planned field work

| Field | Implemented boundary | Missing design |
|---|---|---|
| Heat | Optional temperature storage; Rocket threshold | Units, conduction, energy accounting, cadence, phase transitions |
| Pressure | Local liquid/body coupling heuristics | General pressure storage, equation/update, room/breach semantics |
| Gas composition | Discrete Smoke/Steam material occupants | Mixture representation, quantities, conservation, vacuum behavior |
| Field-based Smoke | Current discrete Smoke reference | Whether to replace occupancy with an optional density/composition field |

**Approved:** future fields share native world authority, scheduler ownership,
activity, bounded capacity, and immutable publication. Optional data should be
allocated where required. Existing Water/Sand/Smoke already use World; they do
not need a new port before this design work.

For each proposed field, define one stage and cadence, numeric representation,
read/write reach, in-place or buffered ownership, conservation or explicit error
bounds, wake/interest behavior, serialization/hash coverage, and failure behavior.
Then add a reference fixture, edge/worker comparison, and current/2× load
measurements. Production interaction ordering across fields is not approved.

### WEX-003 compartment-pressure research

The [WEX-003 feasibility result](../research/lumped-gas-region-pressure-bookkeeping.md)
does **not** implement the general Pressure row above. It identifies a narrower
optional architecture: resolved connected gas regions own amount/free-volume
bookkeeping and derive a compartment boundary pressure, while closures use
affected-component reconstruction and unresolved topology returns no authoritative
pressure. The result admits only the bounded #94 decompression research proof.
Per-cell gas pressure/velocity, composition, heat coupling and production field
integration remain unimplemented.

**Deferred:** GPU-resident derived fields may be benchmarked after their authority
and synchronization are explicit. **Rejected for the current architecture:**
GPU-only terrain/collision authority, unsynchronized gameplay reads, and routine
GPU readback as a prerequisite for authoritative ticks. These dispositions are
owned by [ADR-006](../decisions/ADR-006-gpu-compute-deferral.md), not a permanent
ban on every GPU experiment.
