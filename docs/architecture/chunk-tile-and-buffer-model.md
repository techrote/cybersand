---
title: Chunk, tile, and buffer model
document-kind: contract
canonical-for: [spatial-scheduling-geometry]
status: Current
scope: Native storage, activity, scheduling and write-domain geometry; explicit fallback and buffered distinctions
keywords: [128x128 chunk, 32x32 activity, 64x64 core, radius two, four phases, Buffered]
related-documents: [data-ownership-and-lifetimes.md, determinism-and-boundary-transfers.md, ../systems/activity-dirty-regions-and-waking.md]
last-reviewed: 2026-09-08
---

# Chunk, tile, and buffer model

## Why are there three different spatial sizes?

**Current native defaults:** storage allocation, activity elimination and
parallel work use independent units. Sources:
[WorldConfig/Chunk](../../native/include/cybersand/world.hpp),
[SchedulerGeometry](../../native/include/cybersand/scheduler_geometry.hpp) and
[World execution](../../native/src/world.cpp).

| Unit | Default | Purpose |
|---|---|---|
| Storage chunk | 128×128 cells | Cell allocation, optional temperature, metadata and render dirty bounds |
| Activity block | 32×32 cells | Local wake, quiet tracking and eligibility; 16 blocks per default chunk |
| Scheduling core | 64×64 cells | Spatial job membership and one of four parity phases |
| Write domain | Core expanded by maximum rule radius | All cells a job may mutate; current catalogue requires at most radius two |
| Hard-terrain packet | 64×64 cells in the Godot demo | Rapier collider rebuild unit; separate from native scheduling |

Native coordinates are signed and sparse. The Godot adapter's 1024×1024 world
is a finite demo choice, not a limit inherent in native ChunkCoord. The desktop
GDScript fallback has its own finite arrays and **16×16** activity blocks.
That fallback geometry does not describe either native Web profile.

## How are writes into a neighboring tile made safe?

With the Current native defaults, each job scans a 64×64 core and may write
within its core expanded by the catalogue maximum radius of two cells.
`SchedulerGeometry::phase` uses global core-coordinate parity. Same-phase
cores are separated enough that their expanded half-open write rectangles do
not share cells; geometry rejects a radius greater than half a core. World
also validates compatible chunk/core/activity alignment for its parallel path.
See [geometry implementation](../../native/src/scheduler_geometry.cpp).

`World::scan_rect` visits cells inside the core; an operation may touch the
expanded domain only within the enforced rule radius. Every affected cell must
be owned. Out-of-domain attempts are rejected by the operation's checks; they
are not automatically enqueued into a transfer system. Later visits may make
them eligible. General deferred boundary policies remain **Planned**.

The coordinator prepares structural storage before phase dispatch. Jobs mutate
cells in place and accumulate local effects; the barrier precedes deterministic
metadata merge. No next-state cell array or ordinary movement-transfer record
is needed for this backend. A storage or activity edge is not itself an extra
physics rule. Boundary fixtures must verify that geometry changes do not
introduce unintended seams; intended scan/phase order can still affect results.

## What is stored per cell and per chunk?

**Current source at `de332ea`, checked 2026-09-19:** `World::Chunk::Cell` aliases
[`detail::PrecisionStorage`](../../native/include/cybersand/precision_storage.hpp),
whose enforced physical size/alignment is **8/8 bytes**. It retains material identity,
material-local state and epoch through explicit masks/accessors. Default Water still
uses mass8/coherence12. Earlier four-byte prose and the stale World source comment
refer to a prior baseline; do not apply those storage costs to this source. This
source-scoped correction does not select a final production layout or reinterpret
#16/#17/#26 experimental controls. The [ordinary-sleep measurement](../operations/soliding-measurement.md)
records the actual carrier in its frozen artifact. Temperature is a
separate optional signed-16-bit array, allocated for a chunk only when needed.
Temperature storage exists; conduction is not implemented. Rule descriptors
declare bounded behavior in [material definitions](../../native/include/cybersand/material.hpp).

Activity and render dirtiness are distinct. Sleeping blocks eliminate rule
scans; dirty chunk bounds track needed visual publication and remain until
successful capture. The compact epoch prevents accidental repeated cell work
and incurs a full loaded-cell epoch clear on wrap. Normal sparse work claims
must account for that periodic exception. Detailed wake/sleep behavior belongs
in [activity tracking](../systems/activity-dirty-regions-and-waking.md).

## Are simulation tiles double buffered?

**Planned:** `SimulationBackend::Buffered` reserves a candidate name;
`World::tick` currently throws if selected. It is not a runnable rollback.
Executable alternatives are SerialInPlace and one-worker PhasedInPlace.

The retained design gives only active fields/regions isolated next/output
storage, uses read-only neighborhood views, then resolves cross-output effects
deterministically. Halo representation, transfer schema, conflict ordering and
capacity-recovery behavior remain unspecified. It cannot share mutable ownership
of a field with phased updates without a new explicit contract.

**Rejected:** full-world double buffering as the ordinary model, per-cell locks,
and a second competing liquid world. **Deferred:** alternative coarse-field or
hexagonal work experiments; local occupancy coarsening remains Rejected.
[ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md) explains the selection.

## Can these resources grow during play?

**Current:** native construction capacities and reservation methods are
explicit; lazy coordinator preparation may allocate during ticks. Preallocated
regions avoid the tracked chunk/temperature allocation classes. Workers do not
grow storage containers. **Approved:** a future drained transition can expand
capacity. **Planned:** live resize and general persistence; **Deferred:** broad
world streaming. Fixed-demo level saves provide none of these. Use
[capacity budgets](../operations/configuration-and-capacity-budgets.md),
[ownership](data-ownership-and-lifetimes.md) and the
[validation ledger](../reference/validation-evidence.md) before claiming a
particular region, allocation or boundary fixture is covered.
