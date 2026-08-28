---
title: Module boundaries
status: Approved design
scope: Responsibilities, permitted dependencies, forbidden knowledge, and current analogues for each named module
keywords: [SimulationCore, SimulationScheduler, WorldStorage, TileJob, MaterialRules, RenderBridge, GameplayBridge, rigid body coupling, dependencies]
related-documents: [overview.md, data-ownership-and-lifetimes.md, rendering-and-gameplay-bridges.md, rigid-body-and-cellular-coupling.md]
last-reviewed: 2026-08-27
implementation-state: Native World combines SimulationCore, Scheduler, WorldStorage, job, and rule responsibilities; the godot-cpp adapter carries dirty RG8 render patches, emissions, queries, metrics, and packed rigid-body samples/results.
---

# Module boundaries

## At a glance

- Purpose: make ownership and dependency direction reviewable before implementation.
- **Approved design**: SimulationCore owns authoritative simulation semantics.
- **Approved design**: SimulationScheduler owns timing and worker coordination, not material behavior.
- **Approved design**: WorldStorage owns persistence, chunk lifetime, activation, and serialization.
- **Approved design**: TileJob is a bounded unit of work, not a long-lived world owner.
- **Approved design**: MaterialRules supplies immutable descriptors and compact rule kernels.
- **Approved design**: RenderBridge and GameplayBridge are the only Godot-facing simulation boundaries.
- Non-goal: final class layouts, ABI signatures, or message fields are not specified here.

## Search anchors

module responsibility, permitted dependency, forbidden dependency, who owns state, where does code belong, bridge boundary

## Boundary summary

| Module | Status | Owns | Must not own or access |
|---|---|---|---|
| SimulationCore | **Approved design** | Authoritative tick semantics, committed cell/field state through WorldStorage, invariant enforcement | Godot APIs, rendering resources, scene objects, worker threads as material-specific resources |
| SimulationScheduler | **Approved design** | Fixed timestep, backend/phase plan, persistent worker pool, barriers, deterministic transfer/event coordination, overload reporting | Material-specific policy, Godot scene access, long-term world persistence |
| WorldStorage | **Approved design** | 128×128 storage chunks, load/unload state, activity/wake metadata, optional-field allocation, serialization | Render objects, Godot nodes, material behavior decisions |
| TileJob | **Approved design** | A temporary bounded assignment with either a phased exclusive write domain or a buffered isolated output | Persistent world ownership, out-of-domain writes, dynamic hot-path allocation |
| MaterialRules | **Current**, combined with World execution | Immutable descriptors plus compact kernel selection/state/radius metadata | Threads, queues, scene objects, per-material classes controlling scheduling |
| RenderBridge | **Current**, partial Godot adapter | Reusable immutable native leases, copied dirty RG8 material/condition patches, CPU image reconstruction, and GPU LUT rendering; true GPU subregion texture writes are future work | Mutable simulation pointers, authoritative physics decisions, worker-thread rendering |
| GameplayBridge | **Current**, narrow; generalized form **Approved design** | Current emission commands, region queries, and packed body results; future bounded typed queues | Direct scene-object access from native workers, render snapshot ownership |
| Rigid-body coupling boundary | **Current** native rectangle proof | Stable body samples, separate transient entity occupancy, bounded impact/pressure/displacement observations, and overlap outcomes | Live Node/RID access on workers, material erasure as collision representation, unbounded ejection/substeps |

## SimulationCore

### Responsibilities

- Apply the approved tick semantics.
- Enforce material and conserved-field invariants.
- Coordinate authoritative commit with WorldStorage.
- Produce authoritative dirty, wake, and gameplay-result information for later publication.
- Remain usable by native tests without Godot.

### Permitted dependencies

- WorldStorage
- MaterialRules
- data-only scheduler contracts

### Forbidden dependencies

- Godot headers or runtime objects
- RenderBridge and GameplayBridge implementation details
- UI, audio, camera, scene-tree, or gameplay-node lifetimes

### Current evidence

cybersand::World is the Current standalone authority. It combines storage,
material rules, serial/phased scheduling, worker coordination, dirty tracking,
and RGBA conversion, so the separate SimulationCore module boundary is not yet
conforming even though its core behavior now exists.

## SimulationScheduler

### Responsibilities

- Advance simulation using a fixed timestep.
- Own a persistent native worker pool.
- Latch tick-boundary inputs.
- Build deterministic phased or buffered TileJobs for the selected backend/field.
- Establish stage barriers.
- Invoke deterministic transfer and deferred-event resolution where applicable.
- Publish timing, utilization, backlog, capacity, and overflow diagnostics.
- Run safe capacity reconfiguration only at an approved boundary.

### Non-responsibilities

- It does not decide how water flows or smoke rises.
- It does not serialize world content.
- It does not call Godot scene, rendering, audio, or gameplay APIs from workers.

### Current evidence

World's phased backend now owns a persistent native worker pool, parity phases,
barriers, bounded job results, and deterministic merge. CyberSimulationWorker
still owns wall-clock pacing for the separate Godot proof; no bridge coordinates
the two.

## WorldStorage

### Responsibilities

- Own storage chunk identity and lifetime.
- Store authoritative committed arrays and optional fields.
- Track loaded, active, sleeping, dirty, and wake state.
- Provide active-only next-buffer storage when a selected backend/field requires it.
- Serialize configuration and world state.
- Enforce configured capacity budgets and expose memory/capacity observations.

### Current evidence

World::chunks_ and World::Chunk provide sparse signed-coordinate 128×128 chunks,
four-byte cells, optional temperature, 32×32 activity metadata, dirty bounds,
explicit capacities, and region reservation. They do not provide a separate
storage module, streaming/serialization, or safe live reconfiguration.

## TileJob

### Responsibilities

- Represent one bounded work item.
- In phased mode, access only the provided neighbourhood and mutate only the exclusive current-phase write domain.
- In buffered mode, read the provided current/neighbourhood state and write only isolated next/output and transfer storage.
- Return activity, wake, dirty, and profiling observations through scheduler-owned storage.

### Forbidden behavior

- Any write outside a phased exclusive domain or buffered isolated output.
- Direct structural world mutation or unbounded long-range write.
- Access to Godot or persistent storage containers outside supplied views.
- Unbounded allocation or creation of background threads.

Current jobs are implicit scheduling-core indices with job-local TickStats and
JobEffects. Phase geometry and radius-two writes are source-backed; a public
bounded view, buffered halo, deferred-event records, and final job type remain
undecided.

## MaterialRules

### Responsibilities

- Keep immutable material descriptors separate from mutable cell state.
- Select compact rule-kernel behavior without growing an inheritance hierarchy.
- Make optional-field requirements queryable before work begins.
- Define deterministic interactions that TileJobs can execute.

### Current evidence

native/include/cybersand/material_rules.hpp exposes an immutable descriptor span,
lookup, identifier validation, Current-rule availability, directional density
exchange eligibility, free-leveling liquid classification, hard-surface
classification, and compact oriented pair-reaction queries.
`native/include/cybersand/material.hpp` stores byte IDs, RuleKernel selection,
initial compact state, maximum radius, density motion/acceptance, lateral flow
mode, and normalized viscosity. Executable kernels are compiled into
World's private dispatcher; Godot still duplicates only its small prototype.

The existing MaterialRules boundary is **Current** for immutable lookup, compact
pair chemistry, and the compiled kernel catalogue. Separating execution behind
a type-enforced bounded context, generated external packs, and a modding format
remain **Planned**.

## RenderBridge

### Responsibilities

- Consume immutable dirty snapshots on permitted Godot threads.
- Translate snapshot payloads into Godot image, texture, shader, and presentation updates.
- Report upload bytes, upload time, snapshot pressure, and consumption state.
- Release snapshot storage according to the eventual contract.

`RenderSnapshotExchange` implements the native ownership API: preallocated
slots, deterministic dirty rectangles, read-only material/condition leases,
non-blocking pressure, dirty retention, and high-water metrics. The C ABI keeps
the exchange alive while a lease exists. The Godot adapter copies and
accumulates patches, applies them to a persistent CPU image, and derives colour
through GPU LUTs. It still uses a full `ImageTexture.update()` after patching;
true GPU subregion writes remain **Planned**. No pointer into WorldStorage or
SimulationCore is exposed.

## GameplayBridge

### Responsibilities

- Translate Godot gameplay intent into queued data for a future tick boundary.
- Translate immutable simulation results into main-thread gameplay updates.
- Maintain stable native identifiers where Godot object identity cannot cross the boundary.
- Diagnose rejected, delayed, or capacity-blocked commands according to the eventual overload contract.

The exact command/result schema, queue capacity policy, and identifier format remain undecided.

## Permitted dependency direction

| Caller | May depend on |
|---|---|
| Godot gameplay | GameplayBridge |
| Godot rendering | RenderBridge |
| GameplayBridge | data-only public simulation contracts |
| RenderBridge | immutable snapshot contract |
| SimulationScheduler | SimulationCore, WorldStorage coordination views, data-only work contracts |
| SimulationCore | WorldStorage and MaterialRules |
| TileJob implementation | supplied storage views and MaterialRules |
| WorldStorage | platform-neutral storage/serialization support only |
| MaterialRules | platform-neutral descriptor and kernel data only |

Dependency cycles between these modules require an ADR before implementation.

## Extensibility check

Smoke, heat, pressure, chemistry, electricity, vehicles, and GPU-coprocessed fields must enter through existing ownership directions:

- New fields are owned by WorldStorage.
- Their authoritative update semantics belong to SimulationCore and MaterialRules.
- Their work is scheduled by SimulationScheduler.
- TileJobs access them only through declared views.
- RenderBridge receives derived immutable presentation data.
- GameplayBridge receives only explicit immutable results.
- Rigid-body transforms cross only as value samples; the coupling stage returns bounded observations through GameplayBridge or an equivalent approved data boundary.

## Related decisions

- [ADR-001](../decisions/ADR-001-native-simulation-core.md)
- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md)
- [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md)
- [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md)
