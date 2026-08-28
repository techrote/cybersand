---
title: World storage and interest region
status: Approved design
scope: Current finite/sparse worlds, stored-loaded-active-rendered distinctions, camera-centred policy, margins, serialization, capacity, panning, and safe expansion
keywords: [WorldStorage, interest region, camera window, 10 percent, 20 percent, storage chunk, active chunk budget, serialization]
related-documents: [../architecture/chunk-tile-and-buffer-model.md, ../operations/configuration-and-capacity-budgets.md, ../decisions/ADR-004-interest-region-and-reconfiguration.md]
last-reviewed: 2026-08-27
implementation-state: Sparse native chunks, activity/work/event capacities, explicit region/optional-field reservation, and separately bounded immutable snapshot slots are Current; camera policy, streaming, serialization, and safe live expansion remain unimplemented.
---

# World storage and interest region

## At a glance

- Purpose: allow world size and simulated area to grow independently.
- **Current**: the material lab simulates inside a finite 1024×1024 world.
- **Current**: render view and simulation margins are independently selectable at runtime.
- **Current**, Linux and Windows x86_64: native World supports sparse signed-coordinate chunks, explicit capacity limits, region preallocation, and a Godot GDExtension adapter.
- **Approved design**: interest dimensions and active-chunk capacity are serializable configuration values, not permanent limits.
- **Approved design**: exceeding reserved capacity triggers diagnosed safe reconfiguration at a tick/loading boundary.
- **Planned**: WorldStorage serialization, loading, and migration.

## Search anchors

change interest region size, visible simulation buffer, larger world panning, active chunk budget, capacity exceeded, chunk serialization, stored versus active

## Current Godot world

Repository evidence:

- CyberCellWorld.WORLD_WIDTH is 1024.
- CyberCellWorld.WORLD_HEIGHT is 1024.
- main.gd defaults to a 320×180 logical view.
- `V` cycles 320×180, 480×270, 640×360, and 960×540 views.
- `B` independently cycles 0×0, 32×36, 128×128, and 256×256 per-side margins.
- set_simulation_window limits active processing.
- the shader samples a camera-positioned portion of the full R8 world texture.

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

It has no serializer, streaming/camera policy, or safe live resize protocol.
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

## Serialization

Status: **Planned**.

WorldStorage must eventually serialize:

- chunk identity and authoritative committed data;
- active optional fields;
- material/rule schema version;
- configuration that affects simulation;
- activity/sleep state when required for deterministic continuation;
- pending authoritative state that survives a tick boundary;
- format version and migration metadata.

No file format, compression, version scheme, asynchronous I/O contract, or save migration implementation exists.

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
