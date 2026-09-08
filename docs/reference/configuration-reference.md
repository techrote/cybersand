---
title: Configuration reference
status: Current
scope: Exact current code/configuration values plus approved configuration concepts whose final keys, types, defaults, and serialization remain undecided
keywords: [WorldConfig, WORLD_WIDTH, interest margin, tick interval, capacity keys, configuration status]
related-documents: [../operations/configuration-and-capacity-budgets.md, ../systems/world-storage-and-interest-region.md, status-and-roadmap.md]
last-reviewed: 2026-09-08
implementation-state: Native World construction and snapshot capacities are Current; the Godot adapter has an automatic/override worker setting, full-rate native activity, rectangle coupling constants, and an active pinned Rapier2D backend.
---

# Configuration reference

Source reviewed against the local reconstructed snapshot on 2026-09-08; see the
[audit](../audits/2026-09-08-documentation-audit.md) for source identity and
validation scope. Constants below describe inspected source, not proof that a
retained binary was built from it. The finite CYSD1 schema is documented in
[world storage](../systems/world-storage-and-interest-region.md); it does not
persist general `WorldConfig` or exact replay state.

## At a glance

- Purpose: separate exact Current constants from unimplemented configurable concepts.
- **Current**: native WorldConfig and GDScript constants are listed with exact source paths.
- Current values are prototype evidence, not automatically approved production defaults.
- **Approved design**: interest dimensions and capacity budgets become serializable and reconfigurable.
- No production serialized key names are defined here.
- **Current** prototype numerical chunk and scheduler capacities are listed; they are not production promises.
- **Current** explosion-event and snapshot-publication bounds are explicit runtime inputs.
- Use the operations guide before changing scale assumptions.
- **Current**: Godot 4.7.x, Rapier v0.35.2, and the selected `Rapier2D` server are pinned; Linux and Windows x86_64 native adapters are built for the 4.7 API.

## Search anchors

current world size, current view size, chunk size, sleep ticks, water budget, tick interval, future capacity key, margin fraction

## Native Current configuration

Source: [world.hpp](../../native/include/cybersand/world.hpp), with construction
validation in [world.cpp](../../native/src/world.cpp).

| Exact current member | Current default | Meaning in current native World | Production disposition |
|---|---:|---|---|
| WorldConfig::chunk_size | 128 | Width/height of current native chunks | 128×128 is **Approved design**, but current configurability and validation are not the production schema |
| WorldConfig::sleep_after_quiet_ticks | 3 | Activity-block quiet threshold; chunk state follows active blocks | **Current** prototype value; final sleep policy undecided |
| WorldConfig::ambient_temperature | 200 | Initial temperature value | **Current** storage value; units and heat model undecided |
| WorldConfig::initial_chunk_reserve | 64 | Initial hash/scratch reservation hint | **Current** prototype preallocation only; not a maximum or serialized active-chunk budget |
| WorldConfig::backend | PhasedInPlace | Selects serial, phased, or reserved buffered enum | Phased and serial are **Current**; buffered tick is **Planned** and fails explicitly |
| WorldConfig::activity_block_size | 32 | Activity/sleep granularity | **Current** default |
| WorldConfig::scheduling_core_size | 64 | Four-phase core edge | **Current** default |
| WorldConfig::maximum_rule_radius | 2 | Prepared write-domain expansion | **Current**; active catalogue construction rejects smaller values |
| WorldConfig::worker_threads | 1 | Persistent native workers | Standalone default; adapter Auto policy is specified below |
| WorldConfig::parallel_job_threshold | 8 | Minimum jobs in a phase before pool dispatch | **Current** prototype tuning value |
| WorldConfig::active_core_capacity | 4096 | Bounds gathered core candidates and job results | **Current** explicit capacity |
| WorldConfig::active_chunk_capacity | 4096 | Bounds active-chunk scratch | **Current** explicit capacity |
| WorldConfig::maximum_chunk_count | 4096 | Hard bound on resident native chunks | **Current** explicit capacity |
| WorldConfig::deferred_event_capacity | 1024 | Preallocated accepted-explosion queue bound | **Current** explicit capacity; full enqueue returns false |
| WorldConfig::maximum_explosion_radius | 64 | Maximum accepted bounded explosion radius | **Current**; construction permits values 1–256 |

`CyberNativeCellWorld` overrides several standalone defaults for the finite
sandbox: maximum chunks 128, active-core capacity 1024, active-chunk capacity
128, and parallel job threshold 2. These are adapter fixture values, not new
`WorldConfig` defaults.

The exact project setting `cybersand/native_worker_threads` is **Current**. Zero
selects 2 workers for fewer than 4 reported logical processors, 4 for 4–11,
and 6 for 12 or more (owner rule, 2026-09-08). A positive value requests a
count clamped to 1 through `min(32, reported logical processors)`. No-thread Web forces one worker. The live Web menu
reports the selected count and logical-processor input. Auto does not resize
the running pool or infer physical cores. These exact rules are implemented in
[CyberNativeCellWorld::create_world](../../godot/native_extension/cyber_native_cell_world.cpp).

WorldConfig is passed at construction and mirrored by `cybersand_config_v2`
ABI version 2.
It is not persisted as world configuration.

`RenderSnapshotExchange` separately requires nonzero slot count, patch capacity
per slot, and byte capacity per slot. No default is supplied because the native
caller must size publication for its interest/upload policy. These capacities
are exposed to C callers and report exact requirements on failure.

## Godot Current simulation constants

Source: [cell_world.gd](../../godot/scripts/cell_world.gd). These are fallback
constants; native coupling has its own inspected values in
[cyber_native_cell_world.hpp](../../godot/native_extension/cyber_native_cell_world.hpp).

| Exact current name | Current value | Meaning | Production disposition |
|---|---:|---|---|
| WORLD_WIDTH | 1024 | Finite GDScript material-array width | Material-lab fixture only |
| WORLD_HEIGHT | 1024 | Finite GDScript material-array height | Material-lab fixture only |
| ACTIVITY_BLOCK_SIZE | 16 | Current activity block edge | Production leading activity-block candidate is 32×32; scheduling-core geometry is independent |
| CELL_SLEEP_TICKS | 8 | Current quiet/sleep threshold | Prototype only |
| FREE_LIQUID_LATERAL_FLOW | 255 | Persistent directed-flow sentinel for discrete Water | Prototype reference; native production Water uses conserved mass |
| YIELDING_LIQUID_LATERAL_BUDGET | 6 | Slush lateral travel budget | Prototype Slush tuning; Water remains free-flowing |
| YIELDING_LIQUID_PRESSURE_YIELD | 1 | Slush resting-height tolerance | Prototype Slush tuning; Water uses zero yield |
| PASTE_LIQUID_LATERAL_BUDGET | 3 | Paste lateral travel budget | Prototype Paste tuning |
| PASTE_LIQUID_PRESSURE_YIELD | 3 | Paste resting-height tolerance | Prototype Paste tuning |
| WATER_VISCOSITY | 0 | Fastest normalized gameplay viscosity | Current Water tuning |
| SLUSH_VISCOSITY | 192 | Slush normalized viscosity | Prototype material tuning |
| PASTE_VISCOSITY | 240 | Paste normalized viscosity | Prototype material tuning |
| MAX_LIQUID_LATERAL_FLOW_RATE | 24 | Fastest serial discrete dispersion distance per update | Prototype reference; not a phased native write radius |
| COHERENT_LIQUID_LATERAL_FLOW_RATE | 1 | Lateral cap for supported, pressure-driven coherent-emission cells | Command-selected prototype behavior; independent of viscosity |
| WATER_SURFACE_ADHESION | true | Allows unsupported lateral bridging for Water | Prototype material trait; runtime `T` override is for comparison |
| SLUSH_SURFACE_ADHESION | true | Allows unsupported lateral bridging for Slush | Prototype material trait |
| PASTE_SURFACE_ADHESION | true | Allows unsupported lateral bridging for Paste | Prototype material trait |
| LIQUID_PRESSURE_SAMPLE_DEPTH | 32 | Stopped-edge vertical comparison bound | Script fallback only |
| LIQUID_LEVEL_SEARCH_DISTANCE | 256 | Stopped-edge horizontal look-ahead bound | Script fallback only |
| MAX_BODY_PIXEL_EJECTION_DISTANCE | 8 | Maximum outward search beyond first overlap-exit distance | Current rectangle body proof; no particle fallback |
| BODY_PIXEL_CONTACT_IMPULSE | 0.025 | Per attempted cell/body impact before density scaling | Prototype coupling tuning, not a physical-unit guarantee |
| BODY_DISPLACEMENT_REACTION_IMPULSE | 0.18 | Per body-overlap displacement reaction before density scaling | Prototype coupling tuning |
| BODY_BOUNDARY_PRESSURE_IMPULSE | 0.19 | Per adjacent body/material face before density scaling | Prototype pressure/buoyancy tuning |
| BODY_GRAVITY_SUPPORT_IMPULSE_PER_MASS | 92/60 | Retained script-fallback constant | Hard Wall support in the preferred runtime is Rapier-owned and does not apply this impulse |
| MAX_BODY_IMPULSE_PER_TICK | 3.0 | Magnitude cap for one body's published accumulated impulse | Prototype safety bound |

Other material and movement constants exist in source but are not promoted here as production configuration.

## Godot Current view and interest constants

Source: [main.gd](../../godot/scripts/main.gd) and
[project.godot](../../godot/project.godot). This table describes desktop.
Web's [controller](../../godot/scripts/web_demo_controller.gd) uses LOW/NORMAL/HIGH
320×180/480×270/640×360 views with 30/45/60 Hz publication respectively.

| Exact current name | Current value | Meaning | Production disposition |
|---|---:|---|---|
| VIEW_SIZE_PRESETS | 320×180; 480×270; 640×360; 960×540 | Runtime logical render-window choices, cycled with `V` | Material-lab fixtures, not permanent limits |
| display/window viewport and override | 1920×1080 | Default material-lab output/window size | Aspect-fits the independently selected logical view |
| SIMULATION_MARGIN_PRESETS | 0×0; 32×36; 128×128; 256×256 | Per-side pixel margins, cycled independently with `B` | Material-lab fixtures; future serialized policy remains undecided |
| TEST_RIGID_BODY_SIZE | 8×14 | Size of each red test rectangle, matching the character | Test-scene value only |
| HARD_SURFACE_CHUNKS_PER_FRAME | 32 | Maximum queued chunk rebuilds considered per rendered frame | Shared inherited Web/desktop tuning |
| HARD_SURFACE_FRAME_BUDGET_USEC | 750 | Collider processing time budget checked between chunk rebuilds | Not a preemptive bound on one rebuild |

`CyberRigidBodyCoupling.MAX_BODIES` is 16 in the GDScript proof. The scene
currently supplies three bodies. This is a prototype bound, not an approved
production body capacity.

## Godot Current worker constants

Source: [simulation_worker.gd](../../godot/scripts/simulation_worker.gd).
These pacing constants apply to the desktop coordination Thread. Web instead
calls native ticks synchronously in `_physics_process`, requests at most two
Godot physics steps per rendered frame, and pauses stepping while hard-surface
collider updates remain pending. A threaded Web build parallelizes cellular
jobs within that synchronous tick; it does not use the desktop pacing Thread.

| Exact current name | Current value | Meaning | Production disposition |
|---|---:|---|---|
| TICK_INTERVAL_USEC | 16667 | Current worker tick interval | Prototype evidence; production tick-rate default undecided |
| MAX_BACKLOG_TICKS | 3 | Current backlog cap | Not a complete approved overload policy |

## Rapier2D migration lock

Source: [rapier2d.lock.json](../../godot/third_party/rapier2d.lock.json).

| Exact lock field | Prepared value | Status |
|---|---|---|
| godot_version | `4.7.x` | **Current** migration constraint |
| rapier_tag | `v0.35.2` | **Current** pinned source tag |
| build | Official 2D single build: parallel SIMD and cross-platform deterministic | Lock description of upstream build; not a CyberSand cross-platform replay proof |
| physics_engine_name | `Rapier2D` | **Current**, selected in project.godot |
| release_asset_sha256 | `73b46bfe…aae1f0` | **Current**, exact downloaded asset hash |

Rapier solver/CCD defaults are deliberately not copied into project configuration
as a general tuned production profile. Their project-setting paths and tuned values must be
recorded from the installed version rather than inferred from display labels.
The lock's `4.7.x` compatibility constraint is broader than the exact tested
editor pin `4.7.stable.official.5b4e0cb0f`. Platform binaries, actual tests, and
remaining limits are in the [Rapier runbook](../operations/rapier-2d-migration-runbook.md).

## Approved production configuration concepts

No exact serialized key names exist. The concepts below must receive names/types/defaults in a later schema decision.

| Concept | Status | Requirement |
|---|---|---|
| interest-region width | **Approved design** | Serializable and changeable |
| interest-region height | **Approved design** | Serializable and changeable |
| horizontal margin semantics/value | **Approved design** | Proposed 10% policy; current view-independent pixel presets are above |
| vertical margin semantics/value | **Approved design** | Proposed 20% policy; percentage interpretation remains unresolved |
| active storage-chunk capacity | **Current** construction value; serialization is **Planned** | Bounded and observable, not stored-world size |
| scheduling-core task capacity | **Current** construction value; serialization is **Planned** | Bounded, reusable, explicit failure |
| transfer capacity | **Approved design** | Bounded, reusable, high-water observed |
| immutable snapshot capacity | **Current** native runtime; serialization is **Planned** | Bounded reusable slots with patch/byte capacities and high-water observations |
| gameplay fidelity policy | **Approved design** | Explicit tier/cadence/sampling policy with strict-mode override and observations |
| rigid-body coupling capacity/substep policy | **Approved design** | Bounded accepted bodies/shapes, observations, overlap work, and motion subdivision/sweep behavior |

## Values intentionally not specified

- transfer capacity counts and production snapshot capacity defaults;
- generalized liquid reaction/source/sink accounting;
- buffered halo width;
- production workload-adaptive pool resizing beyond the Current 2/4/6 Auto policy;
- canonical merge priorities;
- queue behavior/timeouts;
- snapshot retention count;
- memory limit;
- benchmark acceptance thresholds;
- production fidelity thresholds/hysteresis and rigid-body substep/sweep limits;
- configuration serialization format.

These omissions prevent prototype assumptions from becoming accidental API.

## Change rules

- Current source constants may be changed only as implementation work with appropriate tests.
- Production simulation-affecting configuration changes at a whole tick or loading transition.
- Capacity growth follows safe reconfiguration.
- Unknown/incompatible generalized configuration values must fail explicitly when that Planned schema exists; Current CYSD1 already validates its fixed level/metadata format.
- Documentation status changes from Approved design to Current only after source and validation evidence exists.

## Related decisions

- [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md)
- [Configuration and capacity](../operations/configuration-and-capacity-budgets.md)
- [Status and roadmap](status-and-roadmap.md)
- [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md)
- [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md)
- [ADR-009](../decisions/ADR-009-rapier-2d-rigid-body-backend.md)
