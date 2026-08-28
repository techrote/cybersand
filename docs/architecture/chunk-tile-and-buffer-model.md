---
title: Chunk, tile, and buffer model
status: Approved design
scope: Independent storage, activity, and scheduling geometry; phased ownership; retained active-only buffering; optional fields; and dirty/activity tracking
keywords: [128x128 storage chunk, 32x32 activity block, 64x64 scheduling core, phased ownership, optional field, active-only buffer]
related-documents: [data-ownership-and-lifetimes.md, determinism-and-boundary-transfers.md, ../systems/activity-dirty-regions-and-waking.md]
last-reviewed: 2026-08-27
implementation-state: Native World implements 128×128 chunks, 32×32 activity blocks, 64×64 four-phase scheduling cores, radius-two ownership, and optional temperature fields; the buffered comparison remains unimplemented.
---

# Chunk, tile, and buffer model

## At a glance

- Purpose: separate persistent world storage from parallel work granularity.
- **Current**: native World uses configurable chunks defaulting to 128×128.
- **Current**: native 32×32 activity blocks control work elimination, sleep, and local wake.
- **Current**: native 64×64 scheduling cores use four parity phases.
- **Current**: every active kernel declares a write radius no greater than two cells.
- **Current**: the hot Cell is four bytes; temperature is an optional per-chunk SoA.
- **Planned**: active-only isolated output buffers remain a comparison/fallback and field-specific option.
- **Current** Godot contrast: the runnable proof still uses 16×16 activity blocks in a finite flat world.

## Search anchors

storage chunk size, activity block size, scheduling core size, Noita phase geometry, write ownership, double-buffer fallback, optional arrays

## Spatial hierarchy

| Level | Status | Size/purpose |
|---|---|---|
| World coordinates | **Current**; target is **Approved design** | Native ChunkCoord supports signed coordinates; production retains a sparse large-world coordinate model. |
| storage chunk | **Current** native default | 128×128 cells; allocation, cell payload, optional fields, activity metadata, and dirty bounds. Streaming/serialization remain planned. |
| activity block | **Current** native default | 32×32 cells for work elimination, sleep, wake, and changed-this-tick state. |
| scheduling core | **Current** native default | 64×64 core assigned by global coordinate parity to one of four phases. |
| owned write domain | **Current** | Core rectangle expanded by configured maximum rule radius; non-overlap is geometry-tested. |
| buffered output region | **Planned** retained candidate | Reserved comparison/fallback; no implementation exists. |

A storage chunk contains four 32×32 activity blocks along each axis and sixteen total. Scheduling cores may span activity or storage boundaries; storage layout must not create a physics seam. Final coordinate and ownership-mask types are undecided.

## Current repository model

### Native

WorldConfig defaults to 128-cell chunks, 32-cell activity blocks, 64-cell
scheduling cores, and radius-two writes. World::Chunk stores a four-byte Cell
array and allocates temperature only on demand. World::tick can use the serial
reference path or the four-phase persistent-worker path.

### Godot

CyberCellWorld uses:

- WORLD_WIDTH 1024 and WORLD_HEIGHT 1024 in the current finite material lab;
- ACTIVITY_BLOCK_SIZE 16;
- active_blocks and next_active_blocks;
- per-cell updated_at and quiet_ticks;
- block_movable_counts.

These 16×16 blocks are Current activity regions, not the production 32×32 activity-block candidate.

## Scheduling and buffer policy

### Current phased backend

- Committed cells are mutated in place only by a job that owns every touched cell in the current phase.
- Four deterministic phases and intervening barriers provide the leading concurrency boundary.
- Ordinary bounded local movement and reactions do not require a next buffer or transfer record.
- Inactive loaded chunks and sleeping activity blocks are not scanned merely because they exist.
- Rule access radius is finite and enforced.

### Retained buffered candidate

- Only active regions and fields receive isolated next/output storage.
- Inactive loaded chunks are not copied.
- Cross-output effects are staged and deterministically resolved.
- The backend remains a benchmark comparison, rollback path, and option for fields whose semantics require immutable-current evaluation.

Both candidates keep optional fields present only where their field policy requires them.

### Not yet specified

- exact structure-of-arrays or array-of-structures layout;
- bit widths beyond existing current prototypes;
- allocator/pool implementation;
- sparse optional-field representation;
- active-next retention across consecutive ticks in the buffered candidate;
- cache-line alignment and SIMD packing.

These choices require measured comparison and must not change module ownership.

## Ownership and neighbourhood rules

Requirements:

- A phased job receives a proven-exclusive write domain and cannot mutate outside it.
- A buffered job receives an isolated output region and cannot write through read-only neighbouring state.
- All data needed by active rule kernels must be available without unrestricted world pointers.
- A chunk or tile boundary does not change rule meaning.
- Structural storage changes cannot invalidate job views while a worker runs.
- Every rule declares or belongs to an enforced maximum access radius.

The current phase mask is `(core_x parity, core_y parity)`, the active catalogue
requires a maximum radius of two, and the buffered halo remains **Ambiguous**.

## Job write regions

Each phased job has a non-overlapping write domain for its phase. Each buffered job has a non-overlapping next/output region.

- In-place writes are legal only when every affected cell is phase-owned.
- Buffered next-state writes are private to that job.
- Out-of-domain local work waits for an eligible phase or uses a future approved deferred policy.
- A job may emit local wake, activity, dirty, and profiling observations.
- Observations become authoritative only in their designated merge/commit stage.

No implementation representation or field list is approved.

## Transfers

The primary phased backend does not stage ordinary bounded cell movement. Transfers remain relevant to the buffered comparison backend:

- buffered jobs calculate effects locally;
- cross-tile and cross-chunk effects are staged;
- SimulationScheduler merges them after the worker barrier;
- merge ordering is canonical and independent of completion order;
- transfer capacity is bounded, observable, and reconfigurable.

See [Determinism and boundary transfers](determinism-and-boundary-transfers.md). The exact transfer schema and conflict rule remain undecided.

Long-range explosions, structural collapse, rigid-body fracture, and generation use bounded deferred events under either backend; their schemas remain undecided.

## Activity and dirty tracking

Activity and dirty state are different:

- activity controls whether simulation work is scheduled;
- wake state makes currently sleeping work eligible;
- simulation dirty state means authoritative state changed;
- render dirty state means an immutable presentation update is needed;
- serialization dirty state means persistent data must eventually be saved.

The approved design keeps fine-grained tracking inside activity blocks. Exact bitsets, rectangles, epochs, or lists are implementation choices not yet approved.

## Optional fields and future systems

| Field/system | Status | Buffer expectation |
|---|---|---|
| Material ID | **Current**; authority concept is **Approved design** | Present for loaded committed cells; exact production representation undecided. |
| Liquid mass/flux | **Current** | Water mass occupies `state_a`; pairwise phased transfers conserve its integer sum in closed fixtures. |
| Temperature | **Current** optional storage; behavior is **Planned** | Per-chunk SoA is allocated on request; conduction is not implemented. |
| Smoke state | **Current** | Compact Gas/Smoke kernel uses the same cell and scheduling model. |
| Pressure/composition | **Planned** | Optional active fields; cadence and resolution undecided. |
| GPU-resident derived fields | **Deferred / experimental** | Must not become terrain/collision authority initially. |

## Alternative resolution and topology

- **Deferred / experimental**: dynamically lower-resolution physics beneath full-resolution pixels may be benchmarked after authoritative semantics are stable.
- **Deferred / experimental**: hexagonal grouping may be evaluated for coarse fields or work aggregation.
- **Approved design**: neither experiment changes the initial 128×128 rectilinear storage hierarchy or the current leading 32×32 activity-block candidate.
- **Explicitly rejected**: introducing a second competing world model solely for liquids or coarse fields.

## Capacity implications

Capacity is not a permanent world-size limit:

- interest region dimensions and active-chunk budget are serializable configuration concepts;
- initial buffers may reserve for the current fixture and a 2× target fixture;
- a larger request triggers explicit safe reconfiguration;
- high-water marks and memory observations determine practical expansion limits;
- compile-time clipping and silent allocation are prohibited.

## Related decisions

- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md)
- [ADR-005](../decisions/ADR-005-water-model.md)
