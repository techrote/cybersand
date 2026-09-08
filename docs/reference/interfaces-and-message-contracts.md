---
title: Interfaces and message contracts
document-kind: contract
canonical-for: [public-and-adapter-interface-layouts]
status: Current
scope: Current C ABI versions and private Godot packed layouts; proposed gameplay/job/reconfiguration contracts are not executable APIs
keywords: [C API v2, material_info_v3, material_info_v4, body packet, INPUT_STRIDE, RG8, gameplay command]
related-documents: [../architecture/data-ownership-and-lifetimes.md, ../architecture/simulation-tick-and-threading.md, ../architecture/rendering-and-gameplay-bridges.md, level-saves-and-replay.md]
last-reviewed: 2026-09-08
---

# Interfaces and message contracts

## Current public surfaces

### Native C API

**Current:** [c_api.h](../../native/include/cybersand/c_api.h) defines the
exported `cybersand_` functions; [c_api.cpp](../../native/src/c_api.cpp) defines
validation and failures. The header is the source of exact C types/alignment.
These host-ABI structs are not a portable serialized file/network format.
Signed `int64_t` positions and rectangle dimensions are cell coordinates;
`size_t` capacity/stride/offset widths depend on the target ABI.

Start v2 construction from `cybersand_default_config_v2()`. `create_v2` checks
`struct_size >= sizeof(cybersand_config_v2)`, `abi_version == 2`, valid backend
range and checked conversion of 64-bit capacities to host `size_t`, then World
validates geometry/capacities. It returns null on invalid configuration or
caught construction failure. Buffered is a representable backend value, but
its tick implementation throws.

| Versioned surface | Current additional fields/behavior |
|---|---|
| `cybersand_config_v2` | Size/version; chunk/activity/core/radius; sleep and ambient temperature; backend/workers; chunk reserve, job threshold, active-core/chunk/max-chunk/event capacities and maximum explosion radius |
| `cybersand_tick_stats_v2` | Legacy tick/visited/moved/active/dirty counts plus scheduled cores, four phase-job counts, owned chunk/temperature allocations and committed deferred events |
| `cybersand_material_info_v2` | Base material metadata plus kernel, initial state bytes and write radius |
| `cybersand_material_info_v3` | v2 base plus density-motion direction, target exchange acceptance and lateral-flow mode |
| `cybersand_material_info_v4` | v3 base plus dimensionless 0–255 viscosity index |

Material-info v3/v4 are additive query layouts; they do not change the config
ABI version from 2. Valid material queries return 1; invalid ID or null output
returns 0. Density metadata is a gameplay scale, not a declared physical density
unit. Native optional temperature is signed 16-bit storage; physical thermal
calibration/conduction is not defined by this API.

Checked set/tick/reservation/explosion/copy methods return 1/0; legacy set/tick
surfaces provide weaker error reporting. `tick_v2` zeroes output after a caught
exception, but **does not roll World back**. Null input/output also fails; no
structured error reason is returned. Hash and resident-byte queries are
[scoped diagnostics](../architecture/determinism-and-boundary-transfers.md),
not complete replay capture or process-memory accounting.

### Godot worker surface

**Current desktop:** `start_worker`/`stop_worker`, `set_frame_state`,
`set_rigid_body_states`, `queue_emit_disc`/`queue_paint`, `queue_reset`,
`take_latest_snapshot`, `acknowledge_render_snapshot` and
`request_render_full_refresh` are GDScript methods, not a stable native ABI.
Web calls its exclusive native adapter synchronously and does not instantiate
this worker protocol. Source: [simulation_worker.gd](../../godot/scripts/simulation_worker.gd).
Ownership and timing are defined by [lifetimes](../architecture/data-ownership-and-lifetimes.md)
and [step order](../architecture/simulation-tick-and-threading.md).

## Gameplay command contract

**Current desktop emission encoding:** `Vector4i(x, y, radius, packed)` where
`packed = (material_id & 255) | (emission_flags << 8)`. `queue_paint` forwards to
`queue_emit_disc`; consecutive identical pending emissions are coalesced.
The only defined option is coherent-liquid emission. UI slots never cross this
boundary. The dynamic queue has no production capacity, target-tick ID or
acceptance result. Reset/frame inputs are separate latched fields.

**Approved:** future commands need bounded immutable value data, deterministic
accepted ordering and explicit failure. **Planned:** the generalized schema,
queue/backpressure policy and exact target-tick semantics. Do not infer them
from this prototype encoding.

<a id="rigid-body-coupling-contract"></a>

## What crosses the rigid-body bridge, and which limits apply?

**Current private adapter format:** `PackedFloat32Array`, not a versioned C ABI.
Source: [rigid_body_coupling.gd](../../godot/scripts/rigid_body_coupling.gd),
[native parser/results](../../godot/native_extension/cyber_native_cell_world.cpp).
Offsets below are float indices within each record.

| Input stride 11 | Field | Result stride 9 | Field |
|---|---|---|---|
| 0 | Body ID | 0 | Body ID |
| 1–2 | Centre x/y | 1–2 | Central impulse x/y |
| 3 | Rotation | 3–4 | Positional correction x/y |
| 4–5 | Full rectangle size x/y | 5 | Contact count |
| 6–7 | Linear velocity x/y | 6 | Displaced-cell count |
| 8 | Angular velocity | 7 | Unresolved-cell count |
| 9 | Mass | 8 | Sample serial |
| 10 | Sample serial | — | — |

Positions/sizes/corrections use pixels/cells, rotation radians, velocities
pixels/second and radians/second. Mass/impulse use the Godot adapter's quantities;
production physical-unit calibration remains unresolved. IDs/counts/serials
travel as floats. Native parsing rounds IDs/serials, considers at most 16
complete records, accepts IDs 1–16, ignores trailing partial records and retains
the first duplicate. Full sizes clamp to at least one cell; mass to 0.001.
This is not a complete hostile-input validator: it does not establish a finite-
number/NaN policy for every field. General shapes, torque and robust public
validation remain Planned. Numerical response and sample-age policy belong in
[coupling](../architecture/rigid-body-and-cellular-coupling.md).

## Immutable dirty snapshot contract

**Current native:** `cybersand_render_patch` stores `int64_t` x/y/width/height
plus byte offset and row stride. Payload is two bytes/cell: material ID and
read-only condition projection. `take_dirty_chunks` with null/insufficient
output returns required count without clearing; failure uses
`CYBERSAND_SIZE_ERROR`, not zero.

`cybersand_world_publish_render_snapshot` returns call success (1/0), separately
from its output status: NoChanges=0, Published=1, Backpressure=2,
CapacityExceeded=3. Call success therefore does not mean a snapshot published.
Result includes serial and required patch/byte counts. `acquire_latest(after_serial)`
returns a lease or null; lease bytes remain valid until lease destruction even
if the exchange handle is destroyed. Publication must serialize with World.

**Current Godot:** six `PackedInt32Array` values per patch are x, y, width,
height, byte offset, row stride. Snapshot also carries render serial, channels,
full-refresh flag and copied byte array. Native is RG8; fallback is R8. The
adapter selects three slots, 64 patches/slot and 2,097,152 bytes/slot for its
finite world. These are prototype defaults, not universal production budgets.
See [snapshot fields](../../godot/scripts/simulation_snapshot.gd),
[lifetime](../architecture/data-ownership-and-lifetimes.md) and
[consumption/failure](../architecture/rendering-and-gameplay-bridges.md).

## Gameplay result contract

**Current:** copied character metrics/body observations. **Approved:** generalized
results must be immutable with explicit IDs, capacity and retention.
**Planned:** final categories and full-result pressure behavior.

## Interest-region update contract

Current native/Godot setters are documented in the
[interest contract](../systems/world-storage-and-interest-region.md), including
backend differences and re-entry defect. **Approved:** explicit requested bounds
and diagnosed capacity. **Planned/Ambiguous:** serialized percentage semantics,
multi-camera policy and live reconfiguration responses.

## TileJob contract

Current jobs are internal core indices and local effects. **Approved:** bounded
views, exclusive phased writes and no retained views after a barrier.
**Planned:** a public type-enforced job/rule context. See
[geometry](../architecture/chunk-tile-and-buffer-model.md).

## Boundary-transfer contract

**Planned:** buffered cross-output records, bounded assigned storage and
canonical merge. No generalized schema/sort tuple exists. Ordinary phased
movement is direct; the Current external explosion queue is a separate narrow
contract. See [ordering](../architecture/determinism-and-boundary-transfers.md).

## Capacity reconfiguration transition

**Approved, unimplemented:** drain affected views, replace capacity intentionally,
then resume with valid state and explicit outcome. No state-machine/API or
failure policy is defined. [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md)
records the decision; current tick exceptions do not implement this guarantee.

## World serialization contract

The canonical [level saves versus exact replay](level-saves-and-replay.md)
contract owns CYSD1 fields, validation, exclusive export/import, omissions and
future replay requirements. Level reconstruction is Current; general streamed
persistence and exact replay are Planned. This stable route intentionally avoids
a second copy of the format specification.
