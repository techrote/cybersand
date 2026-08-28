---
title: Rendering and gameplay bridges
status: Current
scope: Current Godot data flow and rigid-body value bridge, immutable snapshot boundary, queued gameplay commands, immutable results, thread restrictions, and unresolved pressure behavior
keywords: [RenderBridge, GameplayBridge, rigid body sample, immutable dirty snapshot, gameplay command, Godot main thread, mutable simulation memory]
related-documents: [module-boundaries.md, data-ownership-and-lifetimes.md, rigid-body-and-cellular-coupling.md, ../reference/interfaces-and-message-contracts.md]
last-reviewed: 2026-08-27
implementation-state: Current bundled Linux and Windows x86_64 builds advance native World through a GDExtension; Godot consumes copied dirty RG8 render patches and packed rectangle body samples/results without accessing mutable simulation memory.
---

# Rendering and gameplay bridges

## At a glance

- Purpose: isolate Godot presentation and gameplay objects from native mutable state.
- **Current**: a Godot worker consumes copied dirty RG8 material/condition patches and retains them until the main thread acknowledges publication.
- **Current**: Godot physics sends packed rectangle samples and consumes packed coupling results; no live Node or RID crosses to the worker.
- **Current**: standalone native callers can publish deterministic dirty rectangles into preallocated two-byte material/condition slots and acquire immutable leases.
- **Current**: snapshot backpressure/capacity outcomes retain dirty state and expose requirements/high-water counts.
- **Current**: the adapter applies dirty patches to a persistent CPU image; the current `ImageTexture.update()` call still transfers the complete RG8 backing image to the GPU.
- **Current**: GPU palette/program LUTs derive deterministic variation, condition response, 42 procedural flair classes, four-neighbour relief, HDR emission, and dual-radius glow without writing simulation state.
- **Approved design**: GameplayBridge queues commands for tick boundaries and reads immutable results.
- **Approved design**: no simulation worker accesses Godot scene-tree, rendering, audio, or gameplay objects.
- **Explicitly rejected**: exposing mutable cell arrays or long-lived storage pointers to Godot.
- Unresolved: stable public adapter methods, gameplay message schemas/queue capacity, production dirty-snapshot defaults, and optional compression/coalescing.

## Search anchors

Can Godot access simulation memory directly, immutable dirty snapshot, render upload, gameplay command queue, worker thread Godot access, bridge backpressure

## Current Godot flow

Repository evidence:

- godot/scripts/simulation_worker.gd owns CyberNativeCellWorld when available, otherwise CyberCellWorld, plus CyberSampledCharacter.
- main.gd maps temporary paint-tool slots to material IDs, then writes frame inputs and paint requests through mutex-protected worker methods.
- simulation_worker.gd converts the retained paint wrapper into generic material-emission work, drains it, and coordinates both systems on one Godot Thread; native World dispatches eligible cellular jobs to its persistent pool.
- simulation_snapshot.gd stores immutable dirty-render payloads plus character/frame data.
- main.gd copies three RigidBody2D transforms into packed samples; the selected world rasterizes a separate obstacle mask and simulation_snapshot.gd returns sample-keyed impulses/corrections.
- main.gd applies copied RG8 patches to a persistent CPU Image, ping-pongs two textures for temporal smoothing, and performs a full texture update on changed render publications.
- material_palette.gdshader maps material ID and a read-only condition projection through palette/program LUTs; it composites the player plus three red body transforms without writing body pixels into the cell texture.
- material_emission.gdshader and glow_composite.gdshader implement one bounded half-resolution HDR source plus a wider filtered additive composite rather than per-cell lights.

This avoids direct main-thread reads while the worker mutates cells. It still:

- copies only accumulated dirty RG8 payloads in the native-to-GDScript bridge during ordinary changed revisions;
- uploads the full finite RG8 texture after patching because the current `ImageTexture` path has no implemented subregion update;
- uses Godot runtime types at the simulation coordination boundary;
- lacks stable, bounded native command/result queue contracts;
- limits rigid-body coupling to a rectangle proof and an asynchronous sample;
- uses a private Godot adapter method rather than exposing the versioned C lease API directly.

## Current native publication

`RenderSnapshotExchange`, the versioned C API, and the `godot-cpp` adapter provide
the Current native publication layer:

- query required dirty-chunk count without acknowledging/clearing it;
- extract dirty rectangles only when caller capacity is sufficient;
- copy two bytes per requested render cell (material ID and a material-selected condition projection from `state_a`, `state_b`, or zero);
- copy derived RGBA with stable Water mass dithering;
- preallocate a caller-selected number of uniform patch/byte-capacity slots;
- publish chunk-local dirty bounds in deterministic chunk-coordinate order;
- return immutable leases whose shared slot state remains stable until release, even while other slots are reused or the exchange facade is destroyed;
- return `NoChanges`, `Published`, `Backpressure`, or `CapacityExceeded` without silently clearing unpublished dirty state;
- report required patch/byte counts and patch/byte high-water, pressure, and capacity-failure totals;
- never expose a mutable Cell or chunk pointer.

The single producer must serialize publication with ticking and World mutation.
Consumers may acquire/release leases concurrently. Current slot selection reuses
the oldest unleased slot; if every slot is leased, publication is non-blocking
and returns Backpressure while dirty bounds continue to accumulate. The Godot
adapter copies leases into value arrays, accumulates unacknowledged patches, and
replaces excessive pending data with an explicit full refresh. There are no
palette-update records, compression, or generalized native GameplayBridge yet.

## Approved bridge topology

| Interaction | Producer | Consumer | Timing | Mutability | Status |
|---|---|---|---|---|---|
| Gameplay command contract | GameplayBridge on an allowed Godot thread | SimulationScheduler tick-latch stage | Before a target tick boundary | Immutable after enqueue | **Approved design** |
| Gameplay result contract | SimulationCore/Scheduler publication | GameplayBridge | After authoritative commit | Immutable after publication | **Approved design** |
| Interest-region update contract | GameplayBridge or camera policy adapter | SimulationScheduler | Tick boundary or safe reconfiguration transition | Immutable request | **Approved design** |
| Immutable dirty snapshot contract | Native publication stage | RenderBridge | After authoritative commit | Immutable for consumer lifetime | **Current** native layer and copied Godot adapter |
| Capacity reconfiguration transition | Configuration/control boundary | SimulationScheduler and WorldStorage | Tick boundary or loading transition | Controlled structural mutation while workers are drained | **Approved design** |
| Rigid-body sample/result contract | Allowed Godot physics context and worker/native adapter | Cellular coupling stage, then body result consumer | Start-of-stage sample; immutable result after completion | Packed value data only | **Current** rectangle proof in native preferred path and GDScript fallback; generalized shapes **Planned** |

These are documentation-level contract names. Exact C++ types, fields, ABI, and Godot binding methods are undecided.

## RenderBridge

### Reads

- immutable dirty snapshot payloads;
- immutable metadata necessary to place changed regions;
- presentation-only material/palette data where the final contract assigns it;
- snapshot and upload observations.

### Writes

- Godot image/texture/shader resources on permitted Godot threads;
- non-authoritative rendering metrics;
- snapshot-consumption acknowledgement according to the future retention contract.

### Never reads or writes

- mutable current or next simulation buffers;
- TileJob output in progress;
- transfer buffers;
- WorldStorage containers;
- activity/sleep data except immutable diagnostic data explicitly copied into a snapshot.

### Snapshot requirements

The Current native immutable dirty snapshot:

- correspond to completed authoritative state;
- remain stable for its entire consumer lifetime;
- describe dirty content without requiring mutable simulation reads;
- use bounded reusable storage;
- exposes snapshot capacity/high-water observations;
- preserve dirty state if publication cannot proceed.

Its Current payload is an ordered array of world rectangles plus tightly packed
two-byte material/condition rows. A native lease is the lifetime token; the
Godot adapter copies it before release and retains its own immutable value
arrays until acknowledged. Publication is non-blocking under pressure.
Renderer-specific GPU subregion writes, palette-change publication, compression,
and any policy that supersedes accumulated dirty rectangles remain **Planned**.

## GameplayBridge

### Command direction

GameplayBridge translates Godot intent into data that can be latched at a simulation tick boundary. The prototype now exposes generic disc material emission beneath its retained paint UI; paint slots remain presentation-only. The same semantic category can represent later equipment, enemy, and fixed/dynamic spawner output. Other evidenced categories include frame movement inputs, reset, and camera-derived simulation-window updates.

These current categories do not define the final command schema.

### Result direction

GameplayBridge consumes immutable results generated after authoritative commit. The final result categories and identifier representation are undecided.

### Object identity

Godot object references cannot be passed to native workers. Any future mapping between gameplay objects and native simulation entities must use an explicit data contract and stable lifetime rules. No identifier format has been approved.

## Thread rules

| Thread/context | Allowed bridge work |
|---|---|
| Godot main/render thread | Scene-tree access, rendering resource update, UI, gameplay-object mutation, bridge enqueue/poll operations |
| Native SimulationScheduler coordinator | Tick latch, job dispatch, merge, commit coordination, publication |
| Native worker | TileJob data only; no Godot calls or bridge consumer behavior |
| Background serialization/I/O | Only immutable/staged storage approved for that operation; no scene-tree or active mutable views |

## Failure and pressure behavior

Approved constraints:

- no command, result, transfer, or dirty state is silently lost;
- no hidden hot-path allocation;
- required versus available capacity is diagnosed;
- Godot never receives a mutable fallback view;
- any structural expansion occurs through safe reconfiguration.

Current snapshot decisions:

- full slots do not block the simulation coordinator;
- dirty state remains unacknowledged and coalesces in chunk bounds;
- a released slot permits a later publication to capture all retained changes;
- consumers explicitly release leases;
- snapshot rectangles use storage-chunk dirty bounds and material/condition payloads.

Unresolved decisions:

- whether a full command queue rejects, blocks, or defers a producer;
- how long gameplay results remain available;
- production slot/byte defaults and whether Godot ever blocks outside the simulation path;
- whether later compression or tile coalescing outperforms Current rectangles.

## Rendering-only water dithering

**Current** Godot rendering hashes stable world coordinates and compares the
result with projected Water mass; it never alters material, mass, activity, or
replay. The same hash also selects palette variation without consuming a cell
byte. Accessibility controls remain **Planned**.

## Related decisions

- [ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md)
- [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md)
- [Interfaces and contracts](../reference/interfaces-and-message-contracts.md)
- [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md)
