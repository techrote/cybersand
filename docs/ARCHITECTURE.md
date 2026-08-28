---
title: Legacy architecture baseline
status: Ambiguous
scope: Historical milestone architecture notes retained for provenance
keywords: [legacy architecture, current prototype, historical plan, cybersand World]
related-documents: [README.md, architecture/overview.md, reference/status-and-roadmap.md]
last-reviewed: 2026-08-27
implementation-state: Legacy document; it mixes historical and intended behavior and is superseded by the status-labelled architecture set and Current native Linux runtime.
---

# Architecture baseline

## At a glance

- Purpose: preserve the architecture thinking shipped with the current milestone.
- **Current**, superseding this history: native World drives bundled Linux and Windows x86_64 builds, with GDScript retained as an unsupported-architecture fallback.
- **Ambiguous**: statements below may describe earlier standalone/fallback states rather than the preferred runtime.
- **Approved design**: use the lowercase architecture documents for production module boundaries.
- Non-goal: this legacy file is not the authoritative target specification.

## Search anchors

legacy architecture baseline, native library owns state claim, historical ownership, postponed systems

## Related decisions

- [ADR-001](decisions/ADR-001-native-simulation-core.md)
- [ADR-002](decisions/ADR-002-double-buffered-tile-jobs.md)
- [Current status](reference/status-and-roadmap.md)

## Ownership

The native `cybersand` library owns cell state, chunk activity, deterministic
updates, and bulk pixel extraction. Godot owns presentation, input, gameplay
entities, UI, audio, and authoring tools.

The binding boundary must remain coarse. A normal frame should involve a few
calls to advance the simulation, collect events, obtain dirty rectangles, and
upload changed image regions. It must never involve a call per cell.

## Coordinate model

- Global cell coordinates are signed 64-bit integers.
- A chunk coordinate plus a non-negative local coordinate addresses a cell.
- Floor division is used so negative global coordinates behave correctly.
- Local Godot scenes will eventually use a floating origin.

The runnable large-world proof already keeps cellular, character, and camera
positions in a common world-cell coordinate space. Panning changes shader
sampling coordinates rather than moving the world array. This prevents the
finite GDScript backing store from leaking loaded-buffer coordinates into future
gameplay APIs.

## Runtime thread ownership

The runnable proof now gives one dedicated `Thread` exclusive ownership of
`CyberCellWorld` and `CyberSampledCharacter`. The main thread never reads or
edits their mutable arrays directly.

- Input, camera-interest state, pause state, material-emission operations (including the retained paint UI), and reset requests
  cross to the worker as small mutex-protected values or command records.
- The worker applies commands, advances character and cellular physics at a
  fixed rate, and produces a new typed snapshot.
- Material bytes are duplicated only when the world revision changes. Published
  byte arrays and snapshot objects are immutable afterward.
- The main thread consumes the newest available snapshot, uploads changed
  material bytes, and renders the previous state if the worker is still busy.

This is asynchronous single-worker simulation, not parallel cell mutation. It
separates frame responsiveness from simulation throughput while preserving the
deterministic in-place reference order. Native multicore chunk jobs still need
staged boundary buffers before several workers can safely advance cells.

## Current cell storage

Each chunk currently stores structure-of-arrays fields:

- 16-bit material identifier.
- 16-bit signed temperature in an arbitrary prototype scale.
- 64-bit update epoch used to prevent a moved cell updating twice in one tick.

The epoch array is intentionally straightforward for this milestone. It is a
candidate for reduction to 16 or 32 bits once wraparound behaviour is tested.

## Determinism

- Sparse chunks use hash-based storage, but every order-sensitive traversal is
  explicitly sorted.
- Chunk and row traversal direction is derived from the fixed tick number.
- Movement direction is selected by a coordinate-and-tick integer hash.
- Cross-chunk transfers occur through the same world-coordinate API.
- `state_hash()` provides a regression and replay oracle.

Multithreading is intentionally deferred until the single-threaded reference
cell order is locked down. The current dedicated worker changes thread ownership
but still executes one deterministic cell scan at a time. Future intra-simulation
parallelism will preserve results by using staged boundary exchange buffers.

## Sleeping and dirty regions

Chunks begin active. A processed chunk that neither moves nor is externally
changed accumulates quiet ticks and eventually sleeps. Movement wakes the source,
destination, and neighbouring chunks. Every cell mutation expands a per-chunk
dirty rectangle for future texture uploads.

The native implementation currently scans every cell in an active chunk. The
runnable GDScript proof now subdivides its finite world into 16×16 activity
blocks with movable-cell counts and double-buffered wake flags. That block layer
is the prototype for compact masks within future native chunks.

Activity grouping is intentionally independent of storage chunks. Storage,
render upload, collision meshes, and simulation jobs may use different region
sizes while sharing absolute world coordinates.

The runnable proof schedules only activity blocks intersecting the current
camera view plus a percentage-based buffer. Blocks beyond that region retain
their wake flags without advancing. This policy sits above cell storage, so a
future sparse native world can select loaded, rendered, simulated, and saved
regions independently.

Within an awake block, movable cells also carry a byte-sized quiet age. A cell
that finds no legal move for eight scheduled ticks becomes dormant. Any actual
cell mutation clears the quiet age in a one-cell ring around the changed area,
and the existing block wake flags propagate that activity across block
boundaries. Consequently, the buried interior of a liquid or powder volume can
remain dormant even while its surface shares the same 16×16 block and continues
to move.

## Entities and cellular terrain

Ordinary entities are not material cells. The proof character stores continuous
position and velocity, uses swept one-cell movement increments, samples the
world occupancy field around its perimeter, and applies capped upward jetpack
acceleration while Space is held. The shader composites it after material
lookup.

The sampled character remains one-way, but the sandbox now also contains three
independent RigidBody2D rectangles. Their copied transforms rasterize into a
separate worker-owned obstacle mask; material cannot enter those cells, moved
bodies eject overlapped movable material, and packed impulses/corrections return
to Godot. Generalized shapes, the native bridge, and character participation in
that mask remain **Planned**. See
[Rigid-body and cellular coupling](architecture/rigid-body-and-cellular-coupling.md).

## Planned Godot bridge

The production bridge will be a thin `godot-cpp` GDExtension that wraps the
native library. It will expose a `PixelWorld` RefCounted object and bulk methods:

- `step(ticks)`
- bounded material emission such as a disc position/radius/material command; painting is one producer, not the identity model
- `copy_region_rgba(rect)`
- `take_dirty_chunks()`
- `query_cell(position)`
- `query_region_summary(rect)`
- `query_solid_rect(rect)`
- `copy_material_ids(rect)`

The existing C ABI already proves that the core does not depend on Godot.

## Deliberately postponed systems

- Heat conduction and material reactions.
- Coarse pressure and atmospheric composition.
- Generated collision contours.
- Save files and chunk compression.
- Job-system scheduling.
- Conserved coarse-state simulation LOD.
- Optional hex-topology coarse fields.
- Compute-shader heat, pressure, and visual field experiments.
- Vehicle-local simulation grids.
- Electrical and data-network graphs.
- Programmable device virtual machine.
