---
title: Configuration reference
document-kind: reference
canonical-for: [current-configuration-values, adapter-worker-policy]
status: Current
scope: Exact native, adapter, fallback, presentation, and Web defaults; construction constraints and unimplemented production schema
last-reviewed: 2026-10-18
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
blocks; excluded blocks retain wake flags. Native Water's three-quarter lateral
mass-difference relaxation, 12-tick
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

## Which settings belong only to physics experiments?

**Current:** [diagnostic_reset](../operations/physics-characterisation.md)
accepts immutable per-fixture telemetry, traversal/worker, Mercury viscosity,
powder-target exchange and coupling gain/cap options. The runbook owns their
exact bounds and the fixture definitions own scene variants. Ordinary World
construction disables telemetry/overrides; `reset_demo_world` restores production
gains. No UI slider, material descriptor, gravity default or save field changed.
The [dated results](../audits/2026-09-09-physics-characterisation.md) distinguish
existing constants from diagnostic rule vetoes and future support models.

## Granular policy configuration

**Current:** `InteractionPolicy` version 1 sets downward/side occupancy to 8/9 and
9/9 samples and Mercury eligibility to every 30 ticks. Diagnostic reset accepts
`support_cells` 1..9 and `mercury_period` 1..60 only during fresh construction;
normal reset restores defaults. The C ABI and CYSD1 schema are unchanged and use
compiled defaults. No live/UI setting is added. See the
[granular policy](../systems/granular-interaction-policy.md) and
[version decision](../decisions/ADR-011-granular-interaction-policy.md).


## Issue #13 experiment checkpoint

[Experiment Tower](../operations/experiment-tower.md) recipe v4 is 1024 by 1024, with five 198-cell floor pitches, a 4096-rectangle constructor bound, one pending lab command, two release deadlines and a 256-input observation bound. No new per-cell storage is added.


## Opt-in transport profiles

**Current:** the [profile contract](../systems/flow-transport-and-profiles.md)
owns schema, inheritance, units, immutable native tables and explicit owner restart.
The Tower applies validated profiles through restart. Actual powder falls and
lateral Water mass transport drive bounded optional mixing and grain pickup;
horizontal sampling and cadence are separate fixed experiments.
Ordinary gameplay keeps Baseline; chemistry cadence, compact cells and CYSD1
are unchanged. No unsynchronized live descriptor mutation is introduced.

## Soliding successor experiment capacities

**Current standalone tooling:** [lifecycle model](../architecture/soliding-lifecycle.md)
and [discovery journal](../systems/settled-region-discovery.md) use explicit template
capacities. The journal defaults to at most 1024 cells per registered block; a
producer must refuse or deliberately tile larger custom World geometry. There is
no WorldConfig flag or gameplay control for either module. These test capacities
are not selected production thresholds; ordinary runtime remains unchanged.


## Player/environment tuning profile

**Current:** `godot/scripts/player_environment_profiles.gd` owns version 1.
The exact-current preset uses effective mass 1.0, gravity acceleration 92,
terminal fall speed 86, jetpack acceleration 180, maximum rise speed 60,
granular-response sensitivity 1.0, liquid-response sensitivity 1.0, traversal
thresholds 1/1/1 px and knee/clamber speed factors 0.65/0.35. The latter factors
are unreachable in the exact-current profile because knee/clamber do not extend
beyond the historical one-pixel step.

The Earth-feel candidate changes gravity only to 184; terminal speed remains 86.
These values are existing gameplay-space cell/pixel units, not calibrated SI
gravity or mass. The desktop editor accepts bounded custom values and applies
them only through a fresh reset. See the
[player/environment contract](../systems/player-environment-profiles-and-traversal.md)
for field bounds, material-response ownership and traversal semantics.

## Actor control prototype values

**Current, experimental:** [`actor_prototype.gd`](../../godot/scripts/actor_prototype.gd)
owns fixed version-1 **SetA** Runner, Skimmer and Crawler tuning. These values do not
inherit live PENV player/environment edits. Positions and dimensions use cells
(the current gameplay pixels), speeds use cells/second and timing uses seconds;
energy is a normalized gameplay resource. None is an SI calibration.

| Shared limit | Value and meaning |
|---|---|
| Sampled body | 8 by 14 cells, shared by all three models |
| Accepted update duration | At most 1/30 second; longer updates are bounded rather than running an unlimited catch-up loop |
| Velocity magnitude | At most 120 cells/second |
| Downward gravity | 140 cells/second squared for ground models and unpowered Skimmer motion |
| Ordinary movement sweep | At most four one-cell increments per axis per accepted update |
| Traversal search | At most one ledge search per update, with a maximum four-cell rise and clearance along the intervening path |
| Occupancy-query budget | At most 32 adapter occupancy queries per actor update; quota refusal blocks further movement |
| Observation | 16 floats; schema/order belongs to the [actor contract](../systems/actor-control-prototypes.md#how-can-a-neural-policy-control-the-same-actor) |
| Material landing response | Existing REM-003 C1 hook at effective mass 1.0 and sensitivity 1.0 |
| Runtime enclosure recovery | Disabled for these prototypes; bounded explicit spawn repair remains separate |
| Session admission | At most eight actor slots |
| Human command lease | Six ticks (100 ms at 60 Hz), renewed from the latest published observation |
| Policy command lease | Default 12 ticks, maximum 18 ticks, based on observation tick; at 60 Hz this is 200/300 ms of simulation time |
| Pending input | One latest held state plus coalesced rising edges per actor, with epoch/producer/sequence validation |
| Scripted demonstration cadence | One bounded action decision every six actor ticks (10 Hz at the 60 Hz simulation rate) |

| Model | Version-1 movement/action settings |
|---|---|
| Runner | Walk 60; jump speed 78; jump-release rise-speed cutoff 32; coyote time 0.10 s; input buffer 0.12 s; dash speed 120 for 0.10 s with 0.65 s cooldown |
| Skimmer | Cruise 54; boost 90; normalized two-axis input; energy drain 0.10/s in powered flight plus 0.65/s while boosting; ground recharge 0.45/s; braking recharge 0.20/s; exhausted flight resumes after energy reaches 0.15 |
| Crawler | Walk 32; hop speed 48; supported clamber up to four cells; secondary action braces |

| Model | Acceleration and deceleration in cells/second squared |
|---|---|
| Runner | Ground acceleration 900; air acceleration 360; neutral ground deceleration 1100; neutral air deceleration 180 |
| Skimmer | Powered steering and horizontal exhaustion drag 360; explicit vector airbrake 720, followed by gravity |
| Crawler | Movement acceleration 720; neutral horizontal deceleration 1200; brace immediately clears horizontal velocity |

The Crawler's admitted clamber may add up to four cells of vertical relocation
beside the ordinary movement sweep; the four-cell sweep limit alone is not a
total vertical-displacement claim. Skimmer energy recharges while resting on
ground, braking or exhausted. Neutral airborne input uses powered hover until
energy is exhausted. Lease durations are simulation-time limits, not a guarantee
of wall-clock response when the world or host is overloaded.

These finite limits describe controller work, not accepted many-NPC throughput or
zero-allocation execution. Read the [actor contract](../systems/actor-control-prototypes.md)
for input lifetime, ownership, capabilities and remaining platform/acceptance gaps.

## Actor rig values

**Current, experimental ACT-002:** the 26 additional SetB/F/Y/U/V rigs use
[`actor_rig_motor.gd`](../../godot/scripts/actor_rig_motor.gd), while SetA retains
the preceding constants. Catalog metadata supplies fixed unrotated dimensions;
the motor owns movement/resource tuning. Effort is a bounded action input, not a
live PENV override. Units remain gameplay cells, seconds and radians.

| Shared new-rig limit | Value and meaning |
|---|---|
| Session capacity | Eight actors; the F5 compare-set option adds the other selected-set rigs, at most seven actors total |
| Update duration / speed norm | At most 1/30 second / 160 cells per second |
| Baseline gravity | 156 cells per second squared before rig-specific authored lift/braking/gravity factors |
| Translation | Six one-cell sweep increments per axis; six-cell absolute travel budget per axis includes admitted ledge/pivot movement |
| Angular motion | At most 6 radians per second and eight tested angular increments; interval envelopes include interior AABB maxima |
| Occupancy queries | At most 96 per actor update; refusal is treated as blocked movement |
| Surface ray queries | At most 64 material reads per actor update, shared by cast/revalidation/ground sensing and actor-to-effect-origin checks |
| Rope length / acquisition range | 6–44 cells / 44 cells; retained anchors are refused beyond 52 cells, and read-budget exhaustion may shorten the available cast |
| Rope work | One terrain anchor and straight segment; bounded spring force with no positional teleport; negative reel shortens and positive reel extends |
| Ripper / Digger / Lineshank tool radius | 3 / 4 / 2 cells |
| Rocketjumper / Dropbot blast radius | 4 / 3 cells |
| Rocketjumper surface reach | At most six cells beyond the current conservative collision proxy along aim; no surface means no energy spend/recoil/effect |
| Local effect work | At most one effect, 64 material reads and 64 single-cell adapter writes per actor update; fixed radius at most four cells |
| Effect retention | No deferred effect queue; cancellation drops armed effects and charge |
| Effect materials | Explicit whitelist in `CyberActorRigEffects.editable_material`; Wall, composed body masks, out-of-bounds and other noneditable cells are protected |
| Input bounds | Movement components -1..1; normalized nonzero aim or zero; effort 0..1; trim/reel -1..1; finite values required |
| Minimal adapter defaults | Aim follows movement, effort 0.7, trim/reel zero, auxiliary false |
| Leases and producer cadence | Existing six-tick human lease, 12-tick policy default/18-tick maximum, six-tick demo cadence; deadlines derive from observed actor tick |
| Publications | Legacy 16-float rows plus v2 40-float rows; consumed action rows of ten floats, consumed edge flags and admitted/applied sequence identities |

The 12/18-tick policy limits are 200/300 ms at the desktop 60 Hz actor cadence;
they are simulation-time limits rather than a wall-clock service guarantee.
The ten consumed action fields and 40 observation fields are defined only in the
[actor-rigs contract](../systems/actor-rigs.md#what-does-the-version-2-observation-contain).
The internal catalog's `parameters` dictionary is currently empty; it is not an
editable movement schema. Effect-strength telemetry is an authored fraction,
not a calibrated physical pressure or a promise to edit every cell in the radius.

Clamberer adhesion drains 0.025 energy/second, permitting roughly 40 seconds from
full energy with valid contact and no other action expenditure. Walljumper's
1.15/second drain deliberately allows a much shorter attachment window. These are
resource calculations, not guaranteed travel durations across changing terrain.
Lineshank's held blade drains 0.06/second and derives lift and drag from airspeed,
each capped at 240 cells/second squared; its separate initial pulse costs 0.09
with a 0.24-second cooldown. Its bungee stiffness is `24 + 20 * effort`.
Rocketjumper recoil is `(78 + 65 * effort) * (1 - 0.7 * gap / 6)` in the direction
opposite aim, with admitted gap clamped to 0–6 cells, cost 0.26 and cooldown
0.55 seconds. The final common speed bound still applies.

| Set | Unrotated body dimensions in catalog order, width × height |
|---|---|
| SetA | Runner 8×14; Skimmer 8×14; Crawler 8×14 |
| SetB | Scout 8×12; Scrabbler 14×10; Ripper 10×10; GroundEffect 14×7; Digger 6×6 |
| SetF | Copter 12×8; Pouncer 10×10; Dropbot 10×10; Lineshank 8×12 |
| SetY | Walljumper 8×14; Clamberer 8×12; Swinger 8×12; Rocketjumper 10×12 |
| SetU | Springjack 8×12; Gyrocrate 10×10; Bellows 10×10; Winchbug 10×8; Magpie 8×10; Skatesail 12×8 |
| SetV | Astra 8×12; Claude 8×12; Luna 8×10; Qwen 10×10; Bonsai 6×10; Jev 10×10; Gemini 12×8 |

Clamberer may hold an 8×6 tuck and Bonsai a 6×6 tuck. Both preserve their center
while resizing and restore the full hull only if its conservative occupied volume
is clear. The rotated occupancy envelope can exceed the listed unrotated width
or height; decorative extremities do not enlarge collision authority.

Bounds apply to owner-local controller work. They do not establish zero
allocations, complete native reaction cost, neural inference latency, target-PC
frame time or large NPC-population throughput. Source-owned movement details and
per-rig limitations remain in the [catalog contract](../systems/actor-rigs.md).

## Thunderbowl values

**Current, experimental ACT-003:** the standalone
[arena/control reference](../systems/thunderbowl-control-reference.md) owns
behavior and schema meaning. These are fixed prototype constants, not live
world/PENV tuning or accepted population-throughput targets. Sources are
[`thunderbowl_arena.gd`](../../godot/scripts/thunderbowl_arena.gd),
[`thunderbowl_contract.gd`](../../godot/scripts/thunderbowl_contract.gd),
[`actor_rig_actuation.gd`](../../godot/scripts/actor_rig_actuation.gd) and the
[`example driver`](../../godot/examples/thunderbowl/thunderbowl_driver.gd).

| Boundary | Current value and consequence |
|---|---|
| Arena / population | One 256 by 144 cell training pit beginning at (96,96); 1–8 rigs; native workers=1 |
| Episode duration | 1–36,000 ticks; rig/material step 1/60 second; terminal scores freeze |
| Script / human cadence | Script, local reflex and graph-NCA decisions every six ticks (10 Hz); scene human sampling every tick (60 Hz) |
| Commands | At most eight envelopes per owner step, at most one admitted per actor; one latest held session packet |
| Input lease | Default 12, maximum 18 ticks, derived from the issued observation's tick; 19 issuance-history slots per actor |
| Local sensing | 9 by 9 material samples spaced four cells; at most seven actors within 64 cells and clear native-cell line of sight |
| Oracle sensing | Full copied actor states/virtual HP plus 32 by 18 global material samples at eight-cell spacing; no full-resolution native grid |
| Sensing budget | At most 8,192 reads per completed-state generation; at most 192 reads per line; conservative opaque result on exhaustion |
| Tag combat | Virtual HP=3, range=56 cells, aim dot threshold=0.94, rising-edge shot, cooldown=30 ticks, one target per shot |
| Tag work / reward | At most 10,752 line reads per step; +1/-1 per hit; elimination +2 shared among simultaneous contributors and -2 to victim; ring-out -2 |
| Local messages | One typed four-float message per admitted sender command; same team, radius/LOS gated, next-tick delivery; expiry is packet lease deadline; at most seven retained senders per receiver / 56 deliveries |
| Event history | Last 128 events retained with monotonic IDs and explicit dropped-event count |
| Smart-link requests | At most one pending request per actor, request interval at least 30 ticks; plan validity 1–120 ticks from original observation |
| JSON file boundary | At most 65,536 bytes for a loaded config/response; optional file I/O runs between arena steps and can delay the caller |
| Graph neural example | Four hidden channels per actor; one shared 12→8→4 residual MLP update per decision; 140 authored untrained weight/bias values clamped by schema to -4..4 |
| Metal profiles | Ripper: drive/torque/brake/zero; Copter: collective/lateral/torque/brake; Gemini: independent left/right/zero/zero; original motor geometry/query/speed caps remain |
| Direct readback | Version 1, 32 values per actor, separate from v1/v2 rig state; game-unit force/torque and mass/inertia, no SI/Rapier-force claim |
| Optional scene image | At most one copied 256 by 144 material region every six ticks (36,864 reads); no such full-region sampling in headless policy sensing |

`evaluation` declares `mechanics`, `matched`, `asymmetric` or `oracle_reference`.
The matched configuration gate requires equal rig, actuation lane and observation
profile and excludes human cadence; it does not prove equal effective compute,
training privilege or empirical fairness. The visible scene displays evaluator
information, so its human examples use mechanics/asymmetric classification.
