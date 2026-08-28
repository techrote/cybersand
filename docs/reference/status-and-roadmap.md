---
title: Status and roadmap
status: Current
scope: Inspected implementation baseline, approved architecture, known contradictions, reversible checkpoints, deliverables, rollback points, and open decisions
keywords: [status, roadmap, current implementation, approved design, checkpoint, rollback, technical debt]
related-documents: [../README.md, ../architecture/overview.md, ../operations/testing-validation-and-replay.md]
last-reviewed: 2026-08-28
implementation-state: The m9 GPU-flair checkpoint retains m8 simulation behavior while adding 42 GPU material finishes, neighbour-derived relief, dual-radius bloom, F3 stats visibility, and 1920x1080 output.
---

# Status and roadmap

## At a glance

- Purpose: prevent planned architecture from being mistaken for present code.
- **Current**: the asynchronous Godot simulation owner invokes native World through a `godot-cpp` GDExtension on bundled Linux and Windows x86_64 builds; unsupported architectures retain a serial GDScript fallback.
- **Current**: the phased backend uses a persistent worker pool and matches exactly at one and four workers in tested fixtures.
- **Current**: all valid Sandspiel catalogue IDs have adapted executable bounded kernels.
- **Current**: 43 project construction materials occupy IDs 38–80; 41 are inert radius-zero hard surfaces and Oak Timber/Thatch reuse bounded combustion.
- **Current**: Water uses conserved 8-bit mass, viscosity-scaled pairwise transfers, stable rest, and render-only dithering.
- **Current**: the native runtime includes density exchange, coherent Water emission delay, adhesion, Paste/Slush, and interest-window filtering without reducing the active material tick rate.
- **Current**: primary transport remains full rate while secondary lifecycle, chemistry, thermal, growth, capture, and ignition work uses spatially staggered 2/4/8/120-tick lanes.
- **Current**: Smoke has an exact native lifetime, crowd-sensitive slow collapse, and explicit Fire exclusion.
- **Current** Godot source: three RigidBody2D rectangles project a separate obstacle mask and receive bounded impact/pressure/displacement results.
- **Current**: chunk and work capacities are explicit, regions can be preallocated, and tick-owned allocations are reported.
- **Current**: bounded explosions commit at tick boundaries and can convert static Wall into granular falling Stone.
- **Current**: reusable native snapshot slots publish immutable dirty material/condition patches; the Godot adapter consumes them and unchanged-size GPU LUTs derive condition response, stable texture, bounded procedural flair, and HDR appearance.
- **Current**: the renderer spends GPU headroom on four-neighbour relief and wider bloom while retaining the same RG8 publication, palette dimensions, four-texel program rows, and one glow render texture.
- **Current**: Rapier2D v0.35.2 is the sole rigid-body backend; it is vendored, selected, manually stepped, and validated by focused Godot 4.7 Linux x86_64 fixtures.
- **Planned**: implement the active-only buffered comparison only if a field or benchmark still justifies it.

## Search anchors

what exists now, next implementation phase, rollback point, known defect, bridge missing, worker pool missing, documentation status

## Current implementation baseline

Build identity: m9-gpu-flair42-relief-bloom-fhd-win64-2026-08-28.

| Area | Status | Evidence |
|---|---|---|
| Godot cell simulation | **Current** | CyberNativeCellWorld wraps native World for bundled Linux and Windows x86_64 builds; CyberCellWorld remains a compact serial fallback for unsupported architectures |
| Godot worker | **Current** | CyberSimulationWorker owns either backend on one pacing Thread; native World internally dispatches phased jobs to a persistent pool |
| Character/jetpack/camera proof | **Current** | sampled_character.gd and main.gd |
| Godot rigid-body proof | **Current** | Three red 8×14 Rapier-backed RigidBody2D nodes, packed sample/result bridge, native endpoint mask, bounded swept displacement, boundary pressure, and Rapier-owned static contacts |
| Rapier2D migration | **Current**, platform validation partial | Godot 4.7/Rapier v0.35.2 lock, official vendored 2D add-on, selected server, direct manual stepping, active-transform batch reads, and passing Linux x86_64 fixtures |
| Camera interest filtering | **Current** | independently selectable logical view and per-side simulation-margin presets inside the 1024² material lab |
| Godot overload policy | **Current** | full-rate transport plus staggered secondary native interactions, sleeping, interest filtering, and optional presentation smoothing |
| Godot render path | **Current** | dirty native RG8 material/condition patches, persistent CPU image, full RG8 GPU update, 64×256 palette, four-texel programs with 42 flair classes, four-neighbour relief, temporal smoothing, and dual-radius glow |
| Native cell simulation | **Current** | cybersand::World with sparse chunks, serial reference path, and phased in-place path |
| Native scheduler | **Current** | Four parity phases, 64×64 cores, declared radius-two writes, persistent worker pool |
| Native activity | **Current** | 32×32 activity blocks inside 128×128 storage chunks; sleep and local wake |
| Native material catalog | **Current** | Sandspiel-compatible/reactive IDs plus project construction IDs 38–80; 79 paintable valid materials, with zero-radius inert solids and two themed combustibles |
| Sandspiel interaction inventory | **Current** | attributed source ledger plus bounded deterministic adaptations |
| Compact native update epoch | **Current** | One-byte per-cell stamp with explicit wrap clear |
| Conserved Water | **Current** | 8-bit mass, normalized viscosity, exact pairwise conservation in closed fixtures, stable rest, render-only dither |
| Optional temperature | **Current** minimal storage | Per-chunk SoA allocated only when requested; no conduction yet |
| Native release LTO | **Current**, build configuration | GNU `-flto`; MSVC `/GL /LTCG` |
| Native tests/benchmark/C API | **Current** | 39 behavioral/catalogue tests; release benchmark; legacy and versioned C ABI including themed-material queries through ID 80 |
| Capacity/preallocation | **Current** | Maximum chunks, active chunk/core limits, region reservation, tick allocation metrics |
| Deferred explosion/collapse | **Current** | Bounded queue, tick-boundary commit, core removal, Fire centre, and tagged granular Stone shell |
| Native immutable render publication | **Current** | Preallocated slots, read-only leases, deterministic dirty patches, pressure/high-water metrics, and C API |
| Native/Godot integration | **Current**, platform partial | `CyberNativeCellWorld` GDExtension, copied dirty RG8 display patches, emissions, occupancy queries, transient body mask/results, and native metrics; Linux and Windows x86_64 binaries present |
| Active-only buffered backend | **Planned** comparison/fallback | enum reserved; ticking it fails explicitly |
| Serialization and safe live reconfiguration | **Planned** | no world format or drain/resize/publish protocol |

## Known Current contradictions and defects

- Unsupported extension architectures fall back to the older discrete GDScript world and therefore do not have native performance or identical Water behavior.
- Focused Rapier preflight, drop-in, manual-step, and full-scene smoke checks pass with the official Godot 4.7 Linux x86_64 editor. The Windows x86_64 CyberSand DLL is structurally validated but awaits an actual Windows Godot launch.
- The nine-group Godot interaction regression has one known failure unrelated to Rapier: the wide Water basin retains 9..22-pixel column heights after 360 ticks instead of the asserted two-pixel maximum difference.
- Native lazy mode may allocate chunks during a tick; preallocated regions prove zero owned chunk/optional-field allocations and expose any violation in TickStats.
- Changed Godot revisions copy only accumulated dirty RG8 patches across the native bridge, but the current `ImageTexture.update()` still uploads the full finite RG8 backing image.
- The pacing/command owner is one Godot Thread, but each native cellular tick dispatches eligible phase jobs across a persistent native worker pool.
- The current body proof is Rapier2D-only and manually stepped, but coupling remains rectangular and asynchronously sampled.
- Bounded translation sweep is implemented; generalized shape rasterization, torque, particle fallback, and a selective CCD/substep controller remain absent. Unresolved overlap is retained and counted.
- Current Wall pixels are merged into Rapier static rectangle shapes. Cellular wall correction/support impulses are disabled to avoid double-solving hard contacts.
- True GPU texture-subregion writes remain planned; the Current adapter already uses dirty native payloads and dirty CPU image reconstruction.
- Growth, combustion, rockets, and other imported rules are behaviorally adapted; exact Sandspiel stochastic constants and deferred wind/pressure effects are not claimed.

## Approved target baseline

- SimulationCore: native C++, authoritative, Godot-free.
- SimulationScheduler: fixed tick phases, persistent native worker pool, and Godot wall-clock pacing are **Current**.
- WorldStorage: 128×128 storage chunks, activation, optional fields, capacity, serialization.
- Activity block: leading 32×32 work-elimination and dirty granularity.
- Phased job: 64×64 scheduling cores, exclusive radius-two write domains, and four barriers are **Current**.
- Buffered job: retained active-only isolated output and deterministic transfer backend.
- MaterialRules: immutable descriptors and compact kernels are **Current**.
- RenderBridge: native dirty snapshots and copied Godot RG8 patch consumption are **Current**; renderer-specific GPU subregion writes remain **Planned**.
- GameplayBridge: queued tick-boundary commands and immutable results.
- Interest/capacity: bounded and observable preallocation is **Current**; serialization and safe live reconfiguration remain **Planned**.
- Water: phased conserved pairwise fixed point, stable rest, and render-only dither are **Current**; buffered flux remains an unimplemented fallback.
- GPU: deferred for suitable non-authoritative fields initially.
- Rigid-body coupling: separate stable occupancy mask, packed immutable samples/results, bounded overlap reconciliation, Rapier2D backend, and explicit manual step ownership after a drop-in baseline.
- Fidelity: strict replay remains a validation mode; gameplay may use explicit interest-prioritized temporal/probabilistic approximation while preserving local collision and conservation boundaries.

## Reversible implementation checkpoints

| Checkpoint | Status | Deliverable | Acceptance evidence before proceeding | Rollback point |
|---|---|---|---|---|
| 0. Documentation/design baseline | **Current** documentation | This set, evidence labels, ADRs, open decisions | Static link/status audit | Existing repository code unchanged |
| 1. Freeze scheduler contracts and fixtures | **Current** | Radius contract, parity geometry, edge fixtures, benchmark metrics | Geometry and shifted-boundary tests pass | Serial backend |
| 2. One-worker phased scheduler | **Current** | In-place phased path for the native material set | Deterministic behavior and release timing recorded | Serial backend |
| 3. Persistent multiworker phased scheduler | **Current** | Worker pool, four phases, barriers, exclusive write domains | TSan clean; one/four-worker exact hashes in complete-material fixture | One-worker phased path |
| 4. Scheduler decision gate | **Current** provisional selection | Phased backend is the default; buffered work is postponed | Dense/sparse results recorded; multicore wins only when enough jobs exist, while the best worker count remains hardware/fixture dependent | Serial backend; buffered enum remains reserved |
| 5. Conserved water reference | **Current** phased implementation | Pairwise 8-bit mass transfer | Per-tick conservation, stable rest, bounded column gradient, sleep, worker parity | Godot retains discrete CellularYield machinery for future non-Water materials |
| 6. Immutable native bridges | **Current**, partial | Native reusable snapshots/C leases plus a copied dirty-RG8 Godot adapter exist; a generalized bounded GameplayBridge remains **Planned** | Native lifetime tests and focused Godot load pass | Capacity-safe native copy/extraction primitives |
| 7. Material catalogue activation | **Current** adapted pack | Descriptors, reactions, bounded rules, compact state registers | Family tests and complete-material worker parity pass | Sand/Water/Smoke subset in older checkpoint |
| 8. Collapse, optional fields, and world generation | **Current**, partial | Bounded explosions and static-to-granular Stone conversion exist; bodies, heat/pressure behavior, and streamed generation remain **Planned** | Event capacity/bounds, replay hashing, actual fall, worker parity, and C API tests pass | Checkpoint 7 |
| 9. Rigid-body and bounded-fidelity proof | **Current**, runtime coverage partial | Separate rectangle body mask/results, bounded sweep, three test bodies, and fallback-only adaptive cadence | Rapier/body-mask/sweep fixtures pass; broad manual gameplay remains | Checkpoint 8 plus script fallback |
| 10. Rapier2D migration | **Current**, partial platform coverage | Pinned vendored dependency, activation/preflight, focused drop-in baseline, explicit stepping, direct state, batch transforms, and bounded swept cellular reconciliation | Linux x86_64 focused fixtures pass; export matrix and gameplay stress remain | Complete checkpoint 9 archive |
| 11. Runnable native Godot authority | **Current**, Linux and Windows x86_64; Windows runtime unexecuted | GDExtension wrapper, seven-worker measured Linux fixture, native body mask/results, full-rate Water/Sand, Paste/Slush, and script fallback | Latest Linux ~30k-cell shower mean 4.14 ms; scene/thin-floor fixture pass; Windows PE/export/import checks pass | Checkpoint 10 archive and serial script fallback |
| 12. Physics-driven material rendering | **Current**, visual tuning partial | Dirty RG8 bridge, material/condition projection, GPU palette and program LUTs, deterministic variation, temporal smoothing, and bounded HDR glow | Focused full/delta bridge regression and 180-frame Linux scene smoke pass; manual visual/GPU profiling remains | Checkpoint 11 archive and neutral palette rows |
| 13. GPU/coarse/hex experiments | **Deferred / experimental** | Isolated benchmarks for suitable fields/topologies | No authority leakage; total integration cost measured | CPU authoritative backend |

## Checkpoint record requirements

Every checkpoint document/change set records:

- changed ownership and lifetime;
- invariants;
- public interface/contract changes;
- configuration changes;
- current and 2× fixture results;
- per-stage timing and work observations;
- memory, allocation, transfer/snapshot high-water;
- deterministic replay and conservation results;
- known gaps;
- exact rollback point.

Unrelated gameplay/render refactoring is excluded.

## Decisions still required

1. Generalized bounded gameplay command/result queues beyond the Current emission/body-sample methods.
2. Whether any field needs the reserved active-only buffered backend.
3. Generalized deferred-event representation and canonical ordering beyond the Current bounded explosion queue.
4. Heat conduction, pressure/wind, phase-change quantities, and optional-field cadence.
5. Serialized configuration/world schema, versioning, migration, and I/O backpressure.
6. Safe pause/drain/reserve/publish live reconfiguration protocol.
7. Renderer-specific GPU subregion update path, production snapshot capacity defaults, and any compression/coalescing policy beyond Current dirty rectangles.
8. Appearance graph resource/schema/compiler, artist tooling, orientation/overlay representation, and production HDR/glow/flair quality controls.
9. Replay/hash format version compatibility and stored fixture format.
10. Numerical acceptance thresholds and named reference hardware.
11. Generalized shape representation, serialized sweep/CCD/substep policy, force/torque units, particle fallback, and high-count callback policy.
12. Native fidelity-policy controls, target-work/hysteresis rules, snapshot-age response, and which secondary fields may spatially coarsen.

## Status-update rule

A design item becomes **Current** only when:

- matching source exists;
- ownership and interface are inspectable;
- required validation has run;
- contradictions are resolved;
- status and related ADR validation sections are updated.

Reported intent or a partial prototype is insufficient.

## Related decisions

- [All ADRs](../decisions/)
- [Testing and replay](../operations/testing-validation-and-replay.md)
- [ADR-009: Rapier2D rigid-body backend](../decisions/ADR-009-rapier-2d-rigid-body-backend.md)
- [Retrieval index](retrieval-index.md)
