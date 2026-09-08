---
title: Glossary
document-kind: contract
canonical-for: [project-terminology]
status: Current
scope: Short definitions and canonical routes; implemented types, planned concepts and evidence terms are distinguished
keywords: [glossary, authority, chunk, tile, hash, replay, snapshot, capacity]
related-documents: [../README.md, retrieval-index.md, ../architecture/module-boundaries.md]
last-reviewed: 2026-09-08
---

# Glossary

Status words use the [documentation vocabulary](../README.md). Current names
refer to inspected source; named production responsibilities need not be
separate classes. Follow the owning page for exact limits and evidence.

## Authority and implementations

| Term | Meaning and canonical route |
|---|---|
| Authoritative state | State used to decide future simulation; cellular and rigid-body authority are distinct in the [architecture](../architecture/overview.md) |
| `cybersand::World` | Current native cellular owner combining storage, rules and scheduler |
| SimulationCore / SimulationScheduler / WorldStorage / TileJob | Approved responsibility names; current extraction is partial. [Module boundaries](../architecture/module-boundaries.md) |
| MaterialRules | Current immutable descriptors/pair lookup; compiled execution still resides in World. [Material rules](../systems/materials-and-rule-kernels.md) |
| CyberNativeCellWorld | Current Godot adapter owning native World; required by Web |
| CyberCellWorld | Current alternate desktop GDScript solver; different Water semantics, no Web fallback |
| CyberSimulationWorker | Desktop Godot pacing Thread; separate from the native pool |
| Web controller | Main-thread synchronous tick owner; pthreads parallelize only native jobs. [Threading](../architecture/simulation-tick-and-threading.md) |

## Space and work

| Term | Meaning and canonical route |
|---|---|
| Storage chunk | Native default 128×128 allocation/metadata unit |
| Activity block | Native 32×32 eligibility/sleep unit; fallback uses 16×16 |
| Scheduling core / worker tile | Native 64×64 job core; avoid using “tile” for every spatial unit |
| Owned write domain | Core expanded by permitted radius; same-phase domains are exclusive |
| PhasedInPlace | Current four-phase direct mutation backend |
| Buffered output / halo / transfer | Planned isolated next state, read neighborhood and cross-output record; Buffered cannot run. [Geometry](../architecture/chunk-tile-and-buffer-model.md) |
| Loaded / stored / rendered / interest region | Resident chunks / future persistent extent / visible area / eligible simulation bounds; these differ. [Interest contract](../systems/world-storage-and-interest-region.md) |
| Active / sleeping / wake | Eligible metadata / retained quiet state / making work eligible after change; region return currently has a native wake defect. [Activity](../systems/activity-dirty-regions-and-waking.md) |

## Publication and physics

| Term | Meaning and canonical route |
|---|---|
| Dirty | Pending render change bounds; distinct from activity and Planned serialization dirtiness |
| Immutable snapshot / lease | Copied publication plus lifetime token; consumer delay cannot mutate bytes. [Lifetimes](../architecture/data-ownership-and-lifetimes.md) |
| RenderBridge | Current native leases and copied Godot patches; GPU update remains full texture |
| GameplayBridge | Current narrow commands/results; general bounded typed queues Planned |
| Backpressure | Native publication finds every slot leased and retains dirty state |
| Dirty bytes / upload bytes | CPU packet volume / GPU submission volume, currently different. [Bridges](../architecture/rendering-and-gameplay-bridges.md) |
| Body occupancy mask | Separate endpoint body-ID field, not erased/restored material pixels |
| Coupling sample / sweep / CCD | Copied pose identity / bounded sampled reconciliation / Rapier cast-shape contact safeguard; adaptive substeps remain Planned. [Coupling](../architecture/rigid-body-and-cellular-coupling.md) |

## Reproducibility and policy

| Term | Meaning and canonical route |
|---|---|
| Fixed tick / barrier | Whole simulation step / all phase jobs finish before the next; fixed time does not imply transactional failure |
| Worker parity | Exact declared native fixture comparison across worker counts, not all-backend equivalence |
| `state_hash` / `content_hash` | Partial future-state fixture hash / time-independent committed-content hash. [Coverage](../architecture/determinism-and-boundary-transfers.md#replay-state-coverage) |
| CYSD1 / exact replay | Current finite level reconstruction / Planned complete continuation capture. [Saves/replay](level-saves-and-replay.md) |
| Fidelity tier / strict policy | Approved approximation scope / Planned selectable fixed validation mode; current lanes are compiled. [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md) |
| Capacity / high-water / safe reconfiguration | Explicit limit / observed peak / Planned drained growth transition. [Budgets](../operations/configuration-and-capacity-budgets.md) |
| Historical validation / current evidence | Result scoped to its original revision/artifact/platform / separately dated inspection or execution. [Ledger](validation-evidence.md) |

## Materials

| Term | Meaning and canonical route |
|---|---|
| Liquid mass | Native Water's conserved byte quantity, capacity 255 |
| Viscosity index / yield / adhesion | Dimensionless mobility tuning / resting-slope behavior / surface retention; distinct policies |
| Render-only dither | Stable display coverage/variation without changing mass or activity. [Water](../systems/water-design.md) |
| Density exchange | Opted-in directional vertical swap, not unrestricted swapping |
| ExplosionCommand / granular Stone | Bounded queued blast / Stone tagged `state_b=1` for falling behavior. [Rules](../systems/materials-and-rule-kernels.md) |
| Item material program | Planned bounded compiler/registry/recipe system; arbitrary per-cell scripts are Rejected. [Proposal](../architecture/item-authored-material-programs.md) |
