---
title: Configuration and capacity budgets
status: Current
scope: Current constants/configuration, required serializable values, initial reservations, safe expansion, diagnostics, validation, and unresolved schema
keywords: [configuration, capacity budget, interest region, active chunk budget, preallocation, reconfiguration, serialization]
related-documents: [../systems/world-storage-and-interest-region.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/configuration-reference.md]
last-reviewed: 2026-08-27
implementation-state: Native WorldConfig and versioned C ABI expose geometry, workers, chunk/work/event capacities, and explosion bounds; reusable snapshot capacities are explicit at exchange construction, while persistent serialization and safe live resize remain unimplemented.
---

# Configuration and capacity budgets

## At a glance

- Purpose: make simulation scale adjustable without redesigning module boundaries.
- **Current**: native WorldConfig exposes chunk/activity/core geometry, rule radius, worker count, sleep, bounded work/event capacities, and explosion radius.
- **Current**: `reserve_region` and `reserve_temperature_region` prepare chunk/field storage before ticking.
- **Current**: maximum chunk, active chunk, and active-core exhaustion fail explicitly.
- **Current**: TickStats reports chunk and temperature-field allocations made during a tick.
- **Current**: the versioned C ABI exposes the complete native construction configuration.
- **Current**: render snapshot slot, patch, and byte capacities are explicit when constructing a snapshot exchange.
- **Planned**: persistent serialization and pause/drain/resize/publish live reconfiguration.
- Unresolved: saved schema format/version, bridge pressure policy, and production capacity defaults.

## Search anchors

change simulation size, capacity exceeded, current and 2x preallocation, active chunk budget, serialized configuration, safe resize, compile-time limit

## Current configuration evidence

| Source | Current name | Current value | Current behavior | Production status |
|---|---|---:|---|---|
| native/include/cybersand/world.hpp | WorldConfig::chunk_size | 128 | Sets native chunk dimensions at construction | **Current**, not serialized and not yet enforced as production invariant |
| native/include/cybersand/world.hpp | WorldConfig::sleep_after_quiet_ticks | 3 | Native chunk sleep threshold | **Current** prototype value |
| native/include/cybersand/world.hpp | WorldConfig::ambient_temperature | 200 | Initializes native temperature storage | **Current** storage value |
| native/include/cybersand/world.hpp | WorldConfig::backend | PhasedInPlace | Selects native cellular backend | **Current**; Buffered fails explicitly because it is not implemented |
| native/include/cybersand/world.hpp | WorldConfig::activity_block_size | 32 | Native work-elimination granularity | **Current** default |
| native/include/cybersand/world.hpp | WorldConfig::scheduling_core_size | 64 | Native parity-phase job core | **Current** default |
| native/include/cybersand/world.hpp | WorldConfig::maximum_rule_radius | 2 | Bounds prepared write domains | **Current** default and catalogue requirement |
| native/include/cybersand/world.hpp | WorldConfig::worker_threads | 1 | Persistent native worker count | **Current** default; four workers benchmarked |
| native/include/cybersand/world.hpp | WorldConfig::parallel_job_threshold | 8 | Avoids pool dispatch for undersubscribed phases | **Current** default |
| native/include/cybersand/world.hpp | WorldConfig::active_core_capacity | 4096 | Bounds gathered scheduling-core candidates | **Current** default |
| native/include/cybersand/world.hpp | WorldConfig::active_chunk_capacity | 4096 | Bounds active chunk scratch | **Current** default |
| native/include/cybersand/world.hpp | WorldConfig::maximum_chunk_count | 4096 | Hard runtime chunk budget | **Current** default |
| native/include/cybersand/world.hpp | WorldConfig::deferred_event_capacity | 1024 | Preallocates and bounds accepted external explosion commands | **Current** default |
| native/include/cybersand/world.hpp | WorldConfig::maximum_explosion_radius | 64 | Rejects larger explosion commands; constructor rejects values outside 1–256 | **Current** default |
| native/include/cybersand/render_snapshot.hpp | RenderSnapshotExchange constructor capacities | caller supplied | Fixes slot count plus patch/byte capacity per slot before publication | **Current** explicit capacity; no production default |
| godot/scripts/cell_world.gd | WORLD_WIDTH | 1024 | Finite GDScript world width | **Current** material-lab constant |
| godot/scripts/cell_world.gd | WORLD_HEIGHT | 1024 | Finite GDScript world height | **Current** material-lab constant |
| godot/scripts/cell_world.gd | ACTIVITY_BLOCK_SIZE | 16 | Godot activity-block size | **Current**; production leading activity-block candidate is 32×32 |
| godot/scripts/cell_world.gd | CELL_SLEEP_TICKS | 8 | Per-cell/block quiet behavior | **Current** prototype constant |
| godot/scripts/cell_world.gd | TARGET_ACTIVE_BLOCKS_PER_TICK / FULL_RATE_INTEREST_BLOCK_RADIUS | 12 / 1 | Soft overload target plus full-rate 3×3 interest neighbourhood | **Current** adaptive-fidelity proof; not a hard capacity |
| godot/scripts/cell_world.gd | FREE_LIQUID_LATERAL_FLOW | 255 | Byte sentinel for persistent directed Water flow | **Current** discrete Godot Water behavior |
| godot/scripts/cell_world.gd | YIELDING_LIQUID_LATERAL_BUDGET | 6 | Finite Slush spread budget | **Current** prototype tuning |
| godot/scripts/cell_world.gd | WATER_VISCOSITY | 0 | Fastest normalized gameplay viscosity | **Current** Water tuning |
| godot/scripts/cell_world.gd | SLUSH_VISCOSITY / PASTE_VISCOSITY | 192 / 240 | Distinct prototype liquid flow speeds | **Current** prototype tuning |
| godot/scripts/cell_world.gd | MAX_LIQUID_LATERAL_FLOW_RATE | 24 | Maximum contiguous empty cells crossed by the fastest serial discrete liquid update | **Current** Godot reference constant; not a native scheduler write radius |
| godot/scripts/cell_world.gd | COHERENT_LIQUID_LATERAL_FLOW_RATE | 1 | Caps supported pressure-flow for coherent-emitted liquid; gravity/density retain the state | **Current** command-selected behavior, independent of viscosity |
| godot/scripts/cell_world.gd | LIQUID_PRESSURE_SAMPLE_DEPTH | 64 | Bounds stopped-edge depth comparison | **Current** Godot reference constant |
| godot/scripts/cell_world.gd | LIQUID_LEVEL_SEARCH_DISTANCE | 256 | Bounds free-surface look-ahead used to reject staircase heaps | **Current** Godot reference constant |
| godot/scripts/cell_world.gd | LIQUID_LEVEL_PROBE_COUNT | 8 | Limits deep column samples across the broad look-ahead | **Current** sampled-search proof |
| godot/scripts/cell_world.gd | MAX_BODY_PIXEL_EJECTION_DISTANCE | 8 | Bounds rectangle-body overlap ejection search | **Current** body proof; unresolved pixels are retained/counted |
| godot/scripts/cell_world.gd | MAX_BODY_IMPULSE_PER_TICK | 3.0 | Caps accumulated result impulse per body/sample | **Current** body proof tuning |
| godot/scripts/rigid_body_coupling.gd | MAX_BODIES | 16 | Bounds accepted prototype body IDs/results; scene supplies three | **Current** prototype bound, not production capacity |
| godot/scripts/main.gd | VIEW_SIZE_PRESETS | 320×180; 480×270; 640×360; 960×540 | Runtime render-view choices | **Current** material-lab fixtures, not permanent limits |
| godot/scripts/main.gd | SIMULATION_MARGIN_PRESETS | 0×0; 32×36; 128×128; 256×256 | Runtime per-side simulation margins | **Current** independently selected fixtures; final serialized policy unresolved |
| godot/scripts/simulation_worker.gd | TICK_INTERVAL_USEC | 16667 | Godot worker tick interval | **Current** prototype constant |
| godot/scripts/simulation_worker.gd | MAX_BACKLOG_TICKS | 3 | Caps current worker backlog | **Current** prototype behavior; not production overload policy |

The versioned C ABI mirrors the native values, but current project.godot and a
persistent world/configuration file do not store them.

## Approved serializable configuration concepts

The table deliberately gives concepts, not invented key names.

| Configuration concept | Status | Required meaning |
|---|---|---|
| interest-region width and height | **Approved design** | Requested full simulation dimensions around the selected center/camera policy |
| horizontal margin policy | **Approved design** | Initial margin corresponding to the current 10% behavior; exact per-side/total semantics must be frozen |
| vertical margin policy | **Approved design** | Initial margin corresponding to the current 20% behavior; exact per-side/total semantics must be frozen |
| active storage-chunk budget | **Current** native construction value | Maximum active chunks admitted to tick planning |
| scheduling-core task capacity | **Current** native construction value | Reusable planning/result reservation |
| transfer-buffer capacity | **Approved design** | Reusable per-tick transfer reservation |
| immutable snapshot capacity | **Current** native runtime; persistence **Planned** | Reusable slot count and patch/byte capacity per slot |
| gameplay fidelity policy | **Approved design** | Bounded interest/cadence/sampling choices plus strict validation mode |
| rigid-body coupling capacity | **Approved design** | Explicit bodies/shapes, sample/result, overlap, force, and substep/sweep reservations |

Exact saved names, migration behavior, and persistent schema version are **Ambiguous**.

## Capacity is not a permanent maximum

Capacity budgets describe currently reserved memory/work, not architectural limits:

- the stored world may exceed active capacity;
- the requested interest region may be changed later;
- initial reservation may cover current and 2× target fixtures;
- measured tick time and memory determine practical scale;
- a later larger region does not require changing storage-chunk or worker-tile architecture;
- compile-time clipping is prohibited.

## Initial reservation procedure

**Current** native procedure:

1. Construct World with explicit maximum and active-work capacities.
2. Call `reserve_region` for the interest region plus required movement margin.
3. Call `reserve_temperature_region` only where optional temperature storage is required.
4. Construct RenderSnapshotExchange with explicit slot, patch, and byte capacities if native publication is required.
5. Populate or load the region outside the tick loop.
6. Assert TickStats chunk/temperature allocation counters remain zero in normal ticks.
7. Observe scheduled cores, resident cell bytes, event acceptance, snapshot requirements/high-water, and capacity failures.

The 4,096 defaults are current prototype values, not measured production promises.

## Capacity exhaustion

### Prohibited behavior

- silent clipping of the requested region;
- silent dropping of transfers, commands, or dirty state;
- hidden hot-path growth;
- compile-time permanent maximum presented as architecture;
- continuing with partial halos or incomplete outputs.

### Required behavior

- report requested and available capacity;
- identify the exhausted category;
- expose its current use and high-water;
- stop or defer affected work safely;
- enter reconfiguration only at a tick boundary or loading transition;
- preserve authoritative state.

Current concrete outcomes are deliberately local: invalid/full explosion enqueue
returns false; snapshot publication reports Backpressure or CapacityExceeded and
retains dirty state. Broader work-capacity recovery and live resize remain
**Planned**, including whether the simulation pauses or rejects a reconfiguration request.

## Safe reconfiguration

Reconfiguration may alter capacities only after affected worker jobs and views are drained. It must preserve:

- committed state;
- pending authoritative commands according to the future queue contract;
- deterministic tick identity;
- dirty state not yet safely published;
- optional-field identity;
- serialization/version compatibility.

Diagnostics must clearly report the exhausted capacity, requested versus available capacity, memory use, and the reconfiguration outcome. Exact diagnostic fields and names are not approved.

## Serialization requirements

**Planned**: a versioned configuration artifact must store every simulation-affecting value needed to reproduce or resume a world. Configuration migration must reject unknown unsafe changes rather than silently reinterpret data.

No format such as Godot Resource, JSON, binary, or custom schema has been selected.

## Validation

- load/save configuration round trip once a format exists;
- current-interest and 2× fixtures use configured rather than compiled dimensions;
- request just within capacity succeeds without hot allocation;
- request beyond capacity produces diagnostics and a safe transition/result;
- state/hash is preserved across successful capacity-only reconfiguration;
- no interest-region clipping occurs;
- high-water and memory observations change as expected;
- invalid or incompatible configuration fails explicitly.

## Related decisions

- [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md)
- [Configuration reference](../reference/configuration-reference.md)
- [Profiling](profiling-observability-and-performance.md)
