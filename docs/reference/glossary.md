---
title: Glossary
status: Current
scope: Canonical project terminology, status labels, ownership words, spatial hierarchy, rigid-body coupling, fidelity, buffers, bridges, water, profiling, and deferred concepts
keywords: [glossary, canonical terms, SimulationCore, rigid body mask, fidelity tier, storage chunk, worker tile, halo, transfer, immutable snapshot]
related-documents: [../README.md, invariants.md, interfaces-and-message-contracts.md]
last-reviewed: 2026-09-08
implementation-state: Terms describe both inspected current code and approved design; each definition identifies which.
---

# Glossary

Definitions were reconciled with the local source on 2026-09-08. See the
[audit](../audits/2026-09-08-documentation-audit.md) for identity and dated
platform evidence. Module names describe responsibilities; they do not imply
that every named module is already a separate implementation type.

## At a glance

- Purpose: keep retrieval and implementation language consistent.
- Use exact module names: SimulationCore, SimulationScheduler, WorldStorage, TileJob, MaterialRules, RenderBridge, GameplayBridge.
- Use exact spatial names: storage chunk, activity block, scheduling core, owned write domain, buffered output, transfer, interest region.
- Use immutable snapshot for published read-only presentation data.
- Capacity budget means a configurable reservation, never a permanent world-size limit.
- Current prototype names remain valid only when discussing inspected source.
- Status labels are defined in [docs/README.md](../README.md).

## Search anchors

term definition, authoritative, current buffer, next buffer, dirty, active, sleep, wake, high-water, replay hash, fixed-point flux

## Canonical architecture terms

| Term | Status | Definition |
|---|---|---|
| SimulationCore | **Current**, partial | Native World is cellular authority in native and Web adapter paths; production module extraction and complete replay persistence remain Approved/Planned. |
| SimulationScheduler | **Current**, combined implementation; separate module **Approved** | World coordinates phased jobs, barriers, and a persistent native worker pool. Desktop and Web supply different wall-clock pacing owners. |
| WorldStorage | **Approved design** | Owner of storage chunks, loaded/active/sleep metadata, optional fields, capacity enforcement, and future serialization. |
| TileJob | **Approved design** | Temporary bounded work assignment. A phased job writes only its exclusive domain; a buffered job writes only isolated output and staged transfers. |
| MaterialRules | **Current**, combined execution | Immutable material descriptors and compact kernel selection are public; executable dispatch remains private inside World. |
| RenderBridge | **Current**, partial | Native immutable leases and copied dirty RG8 Godot patches exist. CPU image reconstruction is dirty; GPU `ImageTexture.update()` still submits the full image. True GPU subregion writes remain Planned. |
| GameplayBridge | **Approved design** | Godot/native boundary that queues gameplay commands at tick boundaries and consumes immutable results. |

## Current prototype terms

| Term | Status | Definition |
|---|---|---|
| cybersand::World | **Current** | Preferred cellular authority combining sparse chunks, phased workers, material rules, activity/dirty behavior, transient body occupancy, hashing, and display copying. |
| CyberNativeCellWorld | **Current** source, native/Web adapter | GDExtension adapter owning World; desktop calls it from the coordination Thread and Web calls it synchronously from Godot main. Runtime proof is platform/build-specific; see the audit. |
| CyberCellWorld | **Current**, fallback | Finite GDScript cell simulation used only when the native adapter is unavailable. |
| CyberSimulationWorker | **Current**, desktop | One Godot coordination Thread owns the selected cellular world and sampled character; native phase jobs use a separate C++ pool. Web's controller does not use this owner. |
| CyberSimulationSnapshot | **Current**, desktop | Immutable-after-publication value object containing copied RG8 dirty patch payloads in the native path; the fallback may carry full R8 material bytes. |
| Web controller | **Current** | `web_demo_controller.gd` owns cellular/character ticks and Rapier adapter calls on Godot main; threaded Web only parallelizes jobs within the synchronous native tick. |
| CYSD1 level save | **Current**, finite Web demo | Versioned compressed 1024² material/state/temperature payload plus player/options/body metadata. Reconstruction is not an exact replay checkpoint. |
| CyberCellWorld activity block | **Current** prototype | Current Godot work-elimination region is 16×16; it is not the production scheduling geometry. |
| rigid-body coupling packet | **Current** prototype | Packed rectangle body sample/result layout shared by the worker and native adapter; it is not a stable public ABI. |
| rigid-body occupancy mask | **Current** rectangle proof; generalized form **Approved design** | Separate stable collision view rasterized from latched body transforms. It never changes material identity merely to represent a body. |
| coupling sample | **Current** prototype | Complete body value data tagged by a sample ID so a published impulse/correction is applied at most once. |

## Spatial and storage terms

| Term | Status | Definition |
|---|---|---|
| storage chunk | **Current** native default | 128×128 storage/activation unit; persistence/serialization is Planned. |
| activity block | **Current** native default | 32×32 work-elimination, sleep, and wake region. |
| scheduling core | **Current** native default | 64×64 core used to construct four-phase in-place jobs. |
| owned write domain | **Current** native phased backend | Core expanded by declared rule radius; same-phase domains do not overlap. |
| buffered output region | **Approved design** retained candidate | Non-overlapping next-state region a buffered job may write. |
| transfer | **Approved design** | Staged effect crossing a buffered output boundary; ordinary phased local movement does not require one. |
| stored world | **Approved design** | All persistent world content, including content not currently loaded. |
| loaded chunk | **Approved design** | storage chunk whose committed data is resident in WorldStorage. |
| interest region | **Current** concept; configurable form is **Approved design** | Camera-selected eligible simulation area with current pixel-margin presets. The proposed serialized 10%/20% policy remains distinct from those presets. |
| rendered region | **Current** concept | Area sampled/presented by the camera; it need not match the interest region. |

## State and lifetime terms

| Term | Status | Definition |
|---|---|---|
| authoritative state | **Approved design** | State that determines gameplay, future simulation, conservation, saves, and replay. |
| committed authoritative state | **Approved design** | World state mutated only under phased ownership or finalized from an isolated buffered output. |
| active next state | **Approved design** retained candidate | Isolated writable state for an active buffered region/field before commit. |
| optional field | **Current** minimal storage | Field allocated only in chunks/regions that require it; temperature storage exists, while conduction/other fields are Planned. |
| active | **Current** | Eligible for scheduled simulation work. |
| sleeping | **Current** | Committed state retained without ordinary scheduled updates until a wake condition. |
| wake | **Current** | Deterministic transition making sleeping/inactive work eligible after relevant change. |
| dirty | **Current** render scope | Per-chunk bounds accumulated until extraction or successful immutable snapshot capture; serialization dirty is Planned. |
| immutable snapshot | **Current** native render scope | Published read-only data whose bytes/content cannot change during consumer lifetime. |
| immutable dirty snapshot | **Current** native render scope | Ordered rectangle/material-state updates derived from committed dirty state without exposing mutable storage. |
| snapshot lease | **Current** | Move-only C++ token or opaque C handle that keeps one preallocated snapshot slot immutable until release. |
| snapshot backpressure | **Current** native behavior | Non-blocking publication result when every slot is leased; dirty state remains pending. |

## Timing and determinism terms

| Term | Status | Definition |
|---|---|---|
| fixed timestep | **Current** prototype; target is **Approved design** | Simulation advances in whole ticks independent of render frame rate. |
| stage barrier | **Current** native phased scope | Every parity phase completes before the next begins. |
| canonical order | **Current** phased/explosion scope; generalized order **Planned** | Phase/scan/effect merge and accepted explosion order do not derive from worker timing. |
| deterministic replay | **Current** tested scope | Re-running identical authoritative inputs/configuration produces identical authoritative state/hash across tested worker counts. |
| replay hash | **Current**, unversioned native fixture oracle | `World::state_hash()` covers cells, temperature, tick/epoch, activity/sleep, selected configuration, and queued explosions. It does not serialize them or cover the full Godot/Rapier/input state. |
| content hash | **Current**, native fixture oracle | `World::content_hash()` covers non-empty/material/temperature cell content and selected storage settings while excluding tick, epoch, and sleep metadata; settled Water tests use this hash. |
| overload policy | **Current** partial | Native primary transport stays full cadence inside the selected region; secondary rules use fixed spatial lanes, while fallback overload distributes excess blocks. Web ticks may wait for pending collider rebuilds. Production thresholds remain unresolved. |
| fidelity tier | **Approved design** | Named scope in which local full-resolution interaction, temporally sampled surroundings, coarse optional fields, distant macro-state, or strict validation rules apply. |
| adaptive block stride | **Current** fallback only | GDScript cadence derived from eligible block count; the preferred native runtime does not use it. |

## Capacity and profiling terms

| Term | Status | Definition |
|---|---|---|
| capacity budget | **Approved design** | Explicit serializable reservation for work/memory. It can be changed through safe reconfiguration. |
| high-water mark | **Current** snapshot scope; broader metrics **Planned** | Maximum observed use; snapshot patch/byte high-water exists, while reset/aggregation policy is Planned. |
| safe reconfiguration | **Approved design** | Intentional capacity/configuration change at a tick boundary or loading transition after affected views/jobs are drained. |
| hot path | **Current** concept; constraint is **Approved design** | Normal per-tick work where hidden allocation is prohibited. |
| worker utilization | **Approved design** metric concept | Observation of useful worker work versus available worker capacity; formula is undecided. |
| dirty render bytes | **Current** | Packed RG8 bytes copied from native publication and applied to the persistent Godot CPU image. This is not the same as GPU upload bytes. |
| GPU upload bytes | **Current** full RG8 update | Bytes submitted by the present `ImageTexture.update()` path; still the complete 1024×1024 RG8 image for each changed render publication. |

## Water terms

| Term | Status | Definition |
|---|---|---|
| free directed Water | **Current** Godot reference | Discrete Water carrying flow direction and an unlimited byte sentinel until obstructed, with viscosity-derived bounded dispersion and stopped-edge pressure look-ahead. |
| yielding liquid flow | **Current** prototype mode | Finite travel budget and nonzero pressure yield used by Godot Paste/Slush; not assigned to Water. |
| viscosity index | **Current** | Dimensionless 0–255 material tuning where 0 is maximally mobile and 255 is slowest; distinct from pressure yield and not a physical-unit claim. |
| liquid mass | **Current** | Unsigned 8-bit conserved Water quantity in `state_a`, with 255 capacity. |
| liquid transfer | **Current** phased Water scope | Exact bounded pairwise movement of integer mass under phase ownership. |
| density exchange | **Current** | Directional vertical swap: opted-in falling material displaces a lighter accepting target, or rising gas displaces a heavier accepting target. |
| equivalent-state swap | **Explicitly rejected** at rest | State exchange that changes activity without changing meaningful liquid equilibrium. |
| render-only dither | **Current** Godot RG8/LUT path | Stable coordinate-hashed coverage or variation derived without modifying authoritative material/mass, wake, dirty, or replay state. |

## Deferred and rejected terms

| Term | Status | Definition |
|---|---|---|
| phased in-place scheduler | **Current** native default | Four deterministic parity passes of 64×64 cores whose expanded same-phase write domains do not overlap. |
| ExplosionCommand | **Current** private native command | Accepted bounded external event hashed in enqueue order and committed at the next tick boundary; its C API uses value parameters rather than exposing the private type. |
| granular Stone | **Current** | Explosion-created Stone with `state_b=1`; it ignores brace-aware suspension and enters the falling-material solver. |
| GPU-resident field | **Deferred / experimental** | Field computed and consumed on GPU, initially non-authoritative unless a later ADR changes authority. |
| hexagonal grouping | **Deferred / experimental** | Possible coarse/work topology experiment; not the approved initial storage/tile grid. |
| per-cell mutex | **Explicitly rejected** | Lock per cell or equivalently fine-grained lock scheme. |
| material-specific thread | **Explicitly rejected** | Thread or scheduler lane owned by one material type. |

## Related decisions

- [Native World/hash source](../../native/src/world.cpp)
- [Desktop snapshot layout](../../godot/scripts/simulation_snapshot.gd)
- [Web owner](../../godot/scripts/web_demo_controller.gd)
- [Level persistence scope](../systems/world-storage-and-interest-region.md)

- [Architecture overview](../architecture/overview.md)
- [Invariants](invariants.md)
- [Status and roadmap](status-and-roadmap.md)
