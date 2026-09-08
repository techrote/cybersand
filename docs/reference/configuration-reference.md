---
title: Configuration reference
document-kind: reference
canonical-for: [current-configuration-values, adapter-worker-policy]
status: Current
scope: Exact native, adapter, fallback, presentation, and Web defaults; construction constraints and unimplemented production schema
last-reviewed: 2026-09-08
related-documents: [../operations/configuration-and-capacity-budgets.md, ../systems/world-storage-and-interest-region.md, ../architecture/rigid-body-and-cellular-coupling.md, level-saves-and-replay.md]
---

# Configuration reference

**Current:** the following values are inspected source/configuration at the
[secured checkpoint](../operations/source-checkpoint-and-recovery.md). They are
prototype/runtime values, not automatically approved production defaults or
proof that a retained binary was rebuilt. Exact saved general configuration
keys, migration, and live resize are **Planned**.

This page owns values. The [capacity runbook](../operations/configuration-and-capacity-budgets.md)
owns preparation/failure semantics. [Evidence](validation-evidence.md) owns
executed validation; [level saves](level-saves-and-replay.md) owns what CYSD1
actually persists.

## Native WorldConfig defaults

Source: [world.hpp::WorldConfig](../../native/include/cybersand/world.hpp).
All members are construction-time; `cybersand_config_v2` mirrors the configuration.

| Member | Default | Meaning |
|---|---:|---|
| `chunk_size` | 128 | Storage chunk edge |
| `sleep_after_quiet_ticks` | 3 | Activity-block quiet threshold |
| `ambient_temperature` | 200 | Initial signed temperature; physical units undefined |
| `initial_chunk_reserve` | 64 | Initial reservation hint, not maximum/resident count |
| `backend` | `PhasedInPlace` | Serial and phased implemented; Buffered tick throws |
| `activity_block_size` | 32 | Activity/sleep block edge |
| `scheduling_core_size` | 64 | Four-phase core edge |
| `maximum_rule_radius` | 2 | Prepared write expansion; active catalogue requires at least 2 |
| `worker_threads` | 1 | Standalone worker count; adapter overrides below |
| `parallel_job_threshold` | 8 | Minimum phase jobs before pool dispatch |
| `active_core_capacity` | 4096 | Gathered core candidates/results; checked before deduplication |
| `active_chunk_capacity` | 4096 | Active-chunk scratch bound |
| `maximum_chunk_count` | 4096 | Resident chunk limit |
| `deferred_event_capacity` | 1024 | Accepted explosion queue bound |
| `maximum_explosion_radius` | 64 | Largest accepted radius |

[World::World](../../native/src/world.cpp) checks chunk edge 8–1024, activity edge
1–1024, workers 1–256, explosion maximum 1–256, and nonzero quiet/reservation/
capacity/dispatch values. Initial reserve cannot exceed resident capacity.
Multiple workers require phased backend and aligned chunk/core/activity sizes.
[SchedulerGeometry](../../native/src/scheduler_geometry.cpp) requires even core
edge at least 2 and radius from zero through half the core edge; descriptor
validation imposes the active-catalogue radius requirement.

These constraints do not make serial and phased interest filtering equivalent;
see the [region contract](../systems/world-storage-and-interest-region.md#interest-filtering-and-re-entry).

## Finite native adapter overrides

Source: [CyberNativeCellWorld::create_world](../../godot/native_extension/cyber_native_cell_world.cpp)
and [header constants](../../godot/native_extension/cyber_native_cell_world.hpp).

| Value | Adapter setting |
|---|---:|
| Finite world | 1024×1024 |
| Backend / initial reserve | PhasedInPlace / 64 |
| Maximum resident chunks | 128 |
| Active-core / active-chunk capacity | 1024 / 128 |
| Parallel phase threshold | 2 |
| Native snapshot slots | 3 |
| Patch capacity per native snapshot slot | 64 |
| Byte capacity per native snapshot slot | 2,097,152 (1024×1024×2) |

The standalone snapshot constructor requires nonzero caller-supplied slot/patch/
byte limits and has no general defaults. Adapter choices are a separate layer.

## Adapter worker policy

The project setting is `cybersand/native_worker_threads=0`.
`auto_worker_threads` implements the owner's 2026-09-08 policy:

| Reported logical processors | Auto workers |
|---|---:|
| Below 4 | 2 |
| 4–11 | 4 |
| 12 or more | 6 |

A positive explicit request is clamped to 1 through
`min(32, reported logical processors)`; the adapter clamps its processor input
to at least 1. Nonpositive requests take Auto. Auto can intentionally choose two
on a one-processor report. Counts are resolved when constructing a world, not
retuned during play.

No-thread Web forces one cellular worker. Threaded Web keeps Auto and separately
stages `threads/emscripten_pool_size=32` plus `threads/godot_pool_size=2` in
[build_web.py](../../tools/build_web.py). Prewarmed slots are not all cellular
workers. Browser UI reports `navigator.hardwareConcurrency`; it does not detect
physical cores.

## Body coupling values

Source: [native adapter constants](../../godot/native_extension/cyber_native_cell_world.cpp),
[World::kMaximumTransientBodies](../../native/include/cybersand/world.hpp),
[fallback constants](../../godot/scripts/cell_world.gd), and
[packed contract](../../godot/scripts/rigid_body_coupling.gd).
These are gameplay tuning/bounds, not calibrated physical units.

| Native constant/concept | Value | Fallback counterpart |
|---|---:|---|
| Maximum transient body IDs | 16 | `MAX_BODIES=16` |
| Input/result float stride | 11 / 9 | Shared packed layout |
| `kMaximumBodySweepDistance` | 32.0 | `MAX_BODY_SWEEP_DISTANCE` |
| `kBodySweepSampleSpacing` | 1.0 | `BODY_SWEEP_SAMPLE_SPACING` |
| `kMaximumBodySweepSteps` | 24 | `MAX_BODY_SWEEP_STEPS` |
| `kMaximumEjectionDistance` | 8 | `MAX_BODY_PIXEL_EJECTION_DISTANCE` |
| `kBodyPixelContactImpulse` | 0.025 | `BODY_PIXEL_CONTACT_IMPULSE` |
| `kBodyDisplacementReactionImpulse` | 0.18 | `BODY_DISPLACEMENT_REACTION_IMPULSE` |
| `kBodyBoundaryPressureImpulse` | 0.19 | `BODY_BOUNDARY_PRESSURE_IMPULSE` |
| `kMaximumBodyImpulsePerTick` | 3.0 | `MAX_BODY_IMPULSE_PER_TICK` |

The three test rectangles are 8×14. Sweep truncation/sample limits and unresolved
overlap semantics belong to the [coupling contract](../architecture/rigid-body-and-cellular-coupling.md);
these numbers do not guarantee continuous collision detection.
Fallback-only `BODY_GRAVITY_SUPPORT_IMPULSE_PER_MASS=92/60` is retained in
source. Preferred hard-terrain contacts are Rapier-owned, without that support
impulse.

## Desktop fallback simulation constants

Source: [cell_world.gd](../../godot/scripts/cell_world.gd). These are not native
Water/activity semantics; the Web compatibility profile still uses native cells.

| Exact name | Value |
|---|---:|
| `WORLD_WIDTH` / `WORLD_HEIGHT` | 1024 / 1024 |
| `ACTIVITY_BLOCK_SIZE` / `CELL_SLEEP_TICKS` | 16 / 8 |
| `SPARSE_FLIGHT_ACTIVE_BLOCK_THRESHOLD` / `SPARSE_FLIGHT_DISTANCE` | 12 / 2 |
| `FREE_LIQUID_LATERAL_FLOW` | 255 (directed-flow sentinel, not native mass) |
| `YIELDING_LIQUID_LATERAL_BUDGET` / `YIELDING_LIQUID_PRESSURE_YIELD` | 6 / 1 |
| `PASTE_LIQUID_LATERAL_BUDGET` / `PASTE_LIQUID_PRESSURE_YIELD` | 3 / 3 |
| `WATER_VISCOSITY` / `SLUSH_VISCOSITY` / `PASTE_VISCOSITY` | 0 / 192 / 240 |
| `MAX_LIQUID_LATERAL_FLOW_RATE` | 24 cells per serial update |
| `COHERENT_LIQUID_LATERAL_FLOW_RATE` | 1 |
| `WATER_SURFACE_ADHESION` / `SLUSH_SURFACE_ADHESION` / `PASTE_SURFACE_ADHESION` | true / true / true |
| `LIQUID_PRESSURE_SAMPLE_DEPTH` / `LIQUID_LEVEL_SEARCH_DISTANCE` | 32 / 256 |

The threshold enables isolated-cell alternate-tick free flight, not the removed
load-derived block stride. Current fallback reports stride one and zero deferred
blocks; excluded blocks retain wake flags. Native Water's mass, 12-tick
coherence delay, 48-unit supported-film threshold and separate fallback mechanics
belong to the [Water contract](../systems/water-design.md). Material cadence,
including specialized Ice sampling, belongs to
[material kernels](../systems/materials-and-rule-kernels.md#kernel-execution-and-cadence).

## Desktop presentation and pacing

Sources: [main.gd](../../godot/scripts/main.gd),
[simulation_worker.gd](../../godot/scripts/simulation_worker.gd), and
[project.godot](../../godot/project.godot).

| Name/concept | Current value |
|---|---|
| `VIEW_SIZE_PRESETS` | 320×180; 480×270; 640×360; 960×540; default first |
| `SIMULATION_MARGIN_PRESETS` | Per side: 0×0; 32×36; 128×128; 256×256; default second |
| Output/window viewport | 1920×1080, logical view aspect-fitted |
| `SIMULATION_HZ` / `FIXED_TIMESTEP` | 60 / 1÷60 s |
| `TICK_INTERVAL_USEC` / `MAX_BACKLOG_TICKS` | 16667 / 3 |
| Render publication choices/default | 30/45/60 Hz; default 45 |
| `DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC` | 22222 |
| `HARD_SURFACE_SNAPSHOT_INTERVAL_USEC` | 250000, desktop extraction sampling |
| `HARD_SURFACE_REBUILD_INTERVAL` | 0.10 s, controller sync cooldown |
| `HARD_SURFACE_CHUNKS_PER_FRAME` | 32 queued chunks |
| `HARD_SURFACE_FRAME_BUDGET_USEC` | 750, checked between chunk rebuilds |
| `MAX_PENDING_RENDER_PATCHES` | 256 before full-refresh recovery |
| Pending render-byte recovery threshold | Greater than 2,097,152 bytes |
| `RENDER_PATCH_METADATA_STRIDE` | 6 integers |

The 750 µs check excludes extraction and packet validation/copy/queueing; a single
chunk can exceed it. Pending limits trigger recovery after accumulation and are
not process-wide allocation ceilings. Target pacing does not guarantee actual
60 ticks/s.

## Web quality

Source: [web_demo_controller.gd::set_quality](../../godot/scripts/web_demo_controller.gd).
Default quality is NORMAL.

| Quality | Logical view | Per-side margin | Publication target |
|---|---|---|---:|
| LOW | 320×180 | 16×18 | 30 Hz |
| NORMAL | 480×270 | 32×36 | 45 Hz |
| HIGH | 640×360 | 64×72 | 60 Hz |

Web tick ownership, maximum callback catch-up, and terrain gating belong to
[threading](../architecture/simulation-tick-and-threading.md).
These pixel presets do not implement a universal 10% horizontal/20% vertical
formula; that Approved proposal still has unresolved percentage semantics.

## Dependencies and unimplemented configuration

[rapier2d.lock.json](../../godot/third_party/rapier2d.lock.json) selects
`Rapier2D`, tag `v0.35.2`, official 2D single build, with a `4.7.x`
compatibility constraint. The exact tested editor is
`4.7.stable.official.5b4e0cb0f`. Upstream “cross-platform deterministic” build
wording is not a CyberSand replay proof. Full dependency hashes/build pins and
platform payload limits belong to the [build guide](../operations/github-development-and-release.md)
and [Rapier runbook](../operations/rapier-2d-migration-runbook.md).

**Approved concepts; Planned schema:** serializable interest and capacity,
bounded gameplay fidelity with a future strict mode, general command/transfer
reservations, and body/shape/substep policy. Final numeric units, production
memory/quality/acceptance thresholds, high-water reset conventions, automatic
live resizing, and configuration migration remain undecided. Do not invent keys
or confuse the existing fixed CYSD1 metadata with that future schema.

## Diagnostic construction capacity

**Current:** Godot `cybersand/native_active_core_capacity` defaults to 1024 and
clamps to 1–1024 at adapter construction. It uses the same real core-candidate
capacity check as production. The issue #1 regression uses one to force failure;
changing this setting does not resize an existing World. Worker/profile pins and
other adapter defaults are unchanged.

## Interest request accounting

Current native `set_simulation_region` rejects nonpositive sizes and inclusive
endpoint overflow. Null selects all cores; finite bounds normalize to intersecting
cores. Same-coverage requests are equivalent for activity. Region transitions
reuse existing resident metadata passes, and retained excluded activity still
counts toward active-chunk capacity. Candidate-core capacity is checked before
deduplication; a re-entry wake may explicitly fail under a small construction
budget. Failed regions cannot be retried by reducing the window. See the
[interest contract](../systems/world-storage-and-interest-region.md).
