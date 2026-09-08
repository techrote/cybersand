---
title: World storage and interest region
status: Approved design
scope: Current finite/sparse worlds, stored-loaded-active-rendered distinctions, camera-centred policy, margins, serialization, capacity, panning, and safe expansion
keywords: [WorldStorage, interest region, camera window, 10 percent, 20 percent, storage chunk, active chunk budget, serialization]
related-documents: [../architecture/chunk-tile-and-buffer-model.md, ../operations/configuration-and-capacity-budgets.md, ../decisions/ADR-004-interest-region-and-reconfiguration.md]
last-reviewed: 2026-09-08
implementation-state: Sparse native chunks, bounded capacities, finite camera-interest filtering, and CYSD1 level reconstruction are Current; sparse streaming, exact replay persistence, and safe live capacity expansion remain Planned.
---

# World storage and interest region

Source review: 2026-09-08 local reconstructed snapshot, not a verified Git HEAD.
See the [documentation audit](../audits/2026-09-08-documentation-audit.md) for
identity and dated platform evidence. Current storage claims refer to
[World](../../native/include/cybersand/world.hpp) and its
[implementation](../../native/src/world.cpp); the finite adapter and level
boundary are [CyberNativeCellWorld](../../godot/native_extension/cyber_native_cell_world.cpp)
and [CyberDemoBridge](../../godot/native_extension/cyber_demo_bridge.hpp).

## At a glance

- Purpose: allow world size and simulated area to grow independently.
- **Current**: the material lab simulates inside a finite 1024×1024 world.
- **Current**: render view and simulation margins are independently selectable at runtime.
- **Current** source: native World supports sparse signed-coordinate chunks, explicit capacity limits, region preallocation, and native/Web Godot adapters; a declared platform binary does not establish runtime validation.
- **Approved design**: interest dimensions and active-chunk capacity are serializable configuration values, not permanent limits.
- **Approved design**: exceeding reserved capacity triggers diagnosed safe reconfiguration at a tick/loading boundary.
- **Current**: CYSD1 reconstructs the finite Web level. **Planned**: general WorldStorage persistence, streamed loading, schema migration, and exact replay checkpoints.

## Search anchors

change interest region size, visible simulation buffer, larger world panning, active chunk budget, capacity exceeded, chunk serialization, stored versus active

## Current Godot world

Desktop source: [main.gd](../../godot/scripts/main.gd) and
[cell_world.gd](../../godot/scripts/cell_world.gd). Web instead uses
[web_demo_controller.gd](../../godot/scripts/web_demo_controller.gd), whose
three quality choices pair 320×180, 480×270, and 640×360 with 30/45/60 Hz
publication. Both remain finite 1024² adapters.

- CyberCellWorld.WORLD_WIDTH is 1024.
- CyberCellWorld.WORLD_HEIGHT is 1024.
- main.gd defaults to a 320×180 logical view.
- `V` cycles 320×180, 480×270, 640×360, and 960×540 views.
- `B` independently cycles 0×0, 32×36, 128×128, and 256×256 per-side margins.
- set_simulation_window limits active processing.
- the shader samples a camera-positioned portion of the full RG8 native world texture (R8 for the GDScript fallback).

These preset tables are compile-time GDScript constants selected at runtime.
They are not serialized capacity configuration and do not implement arbitrary
sparse streaming.

## Current native world

cybersand::World uses:

- signed 64-bit ChunkCoord values;
- floor division and positive modulo for negative coordinates;
- an unordered map of sparse chunks;
- a configurable chunk_size defaulting to 128;
- dynamic chunk creation;
- per-chunk 32×32 activity, sleep, and dirty metadata;
- maximum resident chunk and active-work capacities;
- bounded accepted explosion-event capacity and maximum radius;
- explicit material and optional-temperature region reservation.

World has no general sparse-world serializer, streaming manager, or safe live resize protocol.
`CyberNativeCellWorld` forwards the finite proof's camera window to World, but
`reserve_region` remains caller-directed preparation rather than a
camera-following streaming manager.

## Region vocabulary

| Region/state | Status | Definition |
|---|---|---|
| stored world | **Approved design** | All serialized world content, potentially much larger than memory. |
| loaded storage chunks | **Current** native concept; streaming is **Planned** | Chunks with committed state resident in World. |
| interest region | **Current** Godot concept; native manager is **Planned** | Camera-centred area eligible for full simulation, initially visible bounds plus margins. |
| active chunks/blocks | **Current** | Loaded work units selected because authoritative state may change. |
| rendered region | **Current** concept | Pixels sampled/presented by the camera; it need not equal simulation or storage extent. |

These sets overlap but are not interchangeable.

## Approved initial interest policy

- Center the interest region on the visible camera window.
- Extend horizontal simulation bounds by 10% beyond the visible area.
- Extend vertical simulation bounds by 20% beyond the visible area.
- Keep dimensions and margin policy explicit and serializable.
- Allow later increases without changing WorldStorage, TileJob, or bridge architecture.

Whether the percentages are applied per side or to total dimension must be frozen in the configuration specification before implementation. Current main.gd is the evidence for prototype behavior.

## Capacity is not world size

The following concepts are separate:

- requested interest-region dimensions;
- active storage-chunk budget;
- preallocated task capacity;
- transfer-buffer capacity;
- snapshot-buffer capacity;
- actual stored world extent.

Native construction exposes maximum chunk/active/event capacities and region
reservation. RenderSnapshotExchange separately exposes slot/patch/byte
capacities. These are Current runtime bounds with explicit failure, not stored
world size or compile-time clipping. Safe replacement with larger capacities is
still **Planned**.

## Safe expansion

When a requested interest region exceeds reserved capacity:

1. calculate and report the requested region and required capacity;
2. do not clip the region or allocate secretly;
3. enter an approved tick-boundary or loading transition;
4. drain affected worker/snapshot/storage views;
5. explicitly resize the relevant bounded resources;
6. report new capacity and memory use;
7. resume with a whole deterministic tick.

The exact request API, pause behavior, and failure result are not approved.

## Panning and activation

### Approved constraints

- Camera movement changes interest policy, not authoritative world coordinates.
- Newly included loaded chunks/tiles become eligible through a deterministic activation step.
- Leaving the interest region does not erase committed state.
- Sleeping/out-of-region state remains serializable and queryable through approved boundaries.
- A boundary transfer cannot be lost because its destination is just outside the current region.
- RenderBridge may display cached immutable data for inactive regions without waking simulation.

### Ambiguous decisions

- catch-up behavior for time-dependent fields;
- prefetch distance and loading-thread policy;
- behavior when camera motion demands more chunks than can be loaded immediately;
- whether multiple cameras or gameplay interest sources are supported;
- render-region margin separate from simulation margin.

## Level reconstruction and planned WorldStorage serialization

**Current**, finite demo scope: [demo_snapshot.hpp](../../native/include/cybersand/demo_snapshot.hpp)
copies material ID, `state_a`, `state_b`, and signed temperature into five bytes
per cell. [demo_save_codec.gd](../../godot/scripts/demo_save_codec.gd) wraps that
1024×1024 payload and validated JSON metadata in version-1 CYSD1 using DEFLATE,
SHA-256, and Base64 for text export. The Web controller also records player,
options, and optional Physics Pit body values. Native payload validation and
candidate allocation precede replacement of the cellular world.

Export requires exclusive World ownership: `copy_level()` temporarily clears
the derived transient obstacle mask to sample stored-cell temperatures, and the
caller must rebuild body occupancy before the next cellular tick. It is not a
concurrent read-only World operation. Payload validation checks length and
material IDs; a complete per-material state-byte validity schema is not defined.

This is a level reconstruction: tick/epoch, activity/sleep history, queued
explosions, and Rapier solver/contact state are not restored. Byte-identical
level re-export is not proof of identical future simulation. Current fixture
scope is in [test_web_demo_setup.gd](../../godot/tests/test_web_demo_setup.gd)
and the [Rapier runbook](../operations/rapier-2d-migration-runbook.md).

**Planned**, general persistence scope:

WorldStorage must eventually serialize:

- chunk identity and authoritative committed data;
- active optional fields;
- material/rule schema version;
- configuration that affects simulation;
- activity/sleep state when required for deterministic continuation;
- pending authoritative state that survives a tick boundary;
- format version and migration metadata.

CYSD1 does not implement this general sparse-world schema, asynchronous I/O,
migration, safe live capacity resizing, or an exact replay continuation format.

## Large coordinates and presentation

The native signed chunk-coordinate approach is a useful **Current** foundation. Godot presentation should use local camera-relative coordinates or another floating-origin strategy as world scale grows, while authoritative world identity remains native and stable.

The final coordinate contract between WorldStorage, GameplayBridge, and RenderBridge is **Planned**.

## Required observations

- requested interest dimensions;
- active chunk/tile/cell counts;
- active-chunk budget and high-water;
- task/transfer/snapshot buffer high-water;
- memory use;
- allocation count;
- dirty upload bytes;
- measured tick time as the region changes.

Exact metric and serialized key names are not approved.

## Related decisions

- [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md)
- [Configuration and capacity](../operations/configuration-and-capacity-budgets.md)
- [Activity and waking](activity-dirty-regions-and-waking.md)
