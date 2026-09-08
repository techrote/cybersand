---
title: Status and roadmap
status: Current
scope: Inspected implementation baseline, approved architecture, known contradictions, reversible checkpoints, deliverables, rollback points, and open decisions
keywords: [status, roadmap, current implementation, approved design, checkpoint, rollback, technical debt]
related-documents: [../README.md, ../architecture/overview.md, ../operations/testing-validation-and-replay.md]
last-reviewed: 2026-09-08
implementation-state: Source inspected 2026-09-08; Windows runtime and prior Chromium evidence are scoped in the current documentation audit. M11 history is retained separately.
---

# Status and roadmap

## At a glance

- Purpose: prevent planned architecture from being mistaken for present code.
- **Current**: desktop uses an asynchronous Godot Thread owning native World; Web callbacks synchronously invoke the same native core, with one compatibility worker or optional Auto 2/4/6 pthread workers. Desktop has a discrete fallback; Web requires the native extension.
- **Current**: the phased backend uses a persistent worker pool and matches exactly at one and four workers in tested fixtures.
- **Current**: all valid Sandspiel catalogue IDs have adapted executable bounded kernels.
- **Current**: 43 project construction materials occupy IDs 38–80; 41 are inert radius-zero hard surfaces and Oak Timber/Thatch reuse bounded combustion.
- **Current**: Water uses conserved 8-bit mass, viscosity-scaled pairwise transfers, stable rest, and render-only dithering.
- **Current**: density exchange, coherent Water emission delay, adhesion, Paste/Slush, and interest filtering exist. Transport runs at selected-job tick rate; secondary interactions follow the lanes below.
- **Current**: primary transport remains full rate while secondary lifecycle, chemistry, thermal, growth, capture, and ignition work uses spatially staggered 2/4/8/120-tick lanes.
- **Current**: Smoke has an exact native lifetime, crowd-sensitive slow collapse, and explicit Fire exclusion.
- **Current** Godot source: three RigidBody2D rectangles project a separate obstacle mask and receive bounded impact/pressure/displacement results.
- **Current**: chunk and work capacities are explicit, regions can be preallocated, and tick-owned allocations are reported.
- **Current**: bounded explosions commit at tick boundaries and can convert static Wall into granular falling Stone.
- **Current**: reusable native snapshot slots publish immutable dirty material/condition patches; the Godot adapter consumes them and unchanged-size GPU LUTs derive condition response, stable texture, bounded procedural flair, and HDR appearance.
- **Current**: the renderer spends GPU headroom on four-neighbour relief and wider bloom while retaining the same RG8 publication, palette dimensions, four-texel program rows, and one glow render texture.
- **Current**: Rapier2D v0.35.2 is selected and manually stepped. Windows native fixtures pass; dated Chromium compat/threaded evidence exists. Local Linux libraries remain pointers despite historical Linux results.
- **Planned**: implement the active-only buffered comparison only if a field or benchmark still justifies it.

## Search anchors

what exists now, next implementation phase, rollback point, known defect, bridge missing, worker pool missing, documentation status

## Current implementation baseline

Scope: local reconstructed `web-demo-m11` base
`e2892c54d4bd91aac60971e81c748bd49fbe2adb` plus adapter/Web changes; no Git HEAD
exists here. [Current audit](../audits/2026-09-08-documentation-audit.md) records
backup coverage, exact checks and source references.
`m11-audit-remediation-render-handoff-water-native-repro-2026-08-28` is a
historical build identity, not a current clean-checkout attestation.

Evidence cells below identify source behavior; historical test statements are
qualified by the checkpoint table and current audit.

| Area | Status | Evidence |
|---|---|---|
| Godot cell simulation | **Current** | CyberNativeCellWorld wraps native World on Windows native/Web; CyberCellWorld is the desktop fallback. Linux binaries are unresolved local pointers |
| Godot worker | **Current** | Desktop CyberSimulationWorker owns one pacing Thread; Web owns synchronous callbacks; native World dispatches phased jobs internally |
| Character/jetpack/camera proof | **Current** | sampled_character.gd and main.gd |
| Godot rigid-body proof | **Current** | Three red 8×14 Rapier-backed RigidBody2D nodes, packed sample/result bridge, native endpoint mask, bounded swept displacement, boundary pressure, and Rapier-owned static contacts |
| Rapier2D migration | **Current**, platform validation partial | Godot 4.7/Rapier v0.35.2 lock, official vendored 2D add-on, selected server, direct manual stepping, active-transform batch reads, and dated Windows native and Chromium fixtures; historical Linux fixtures |
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
| Native tests/benchmark/C API | **Current** | 39 native regressions (2026-09-08 rerun); release benchmark; legacy and versioned C ABI including themed-material queries through ID 80 |
| Capacity/preallocation | **Current** | Maximum chunks, active chunk/core limits, region reservation, tick allocation metrics |
| Deferred explosion/collapse | **Current** | Bounded queue, tick-boundary commit, core removal, Fire centre, and tagged granular Stone shell |
| Native immutable render publication | **Current** | Preallocated slots, read-only leases, deterministic dirty patches, pressure/high-water metrics, and C API |
| Native/Godot integration | **Current**, platform partial | `CyberNativeCellWorld` GDExtension, copied dirty RG8 display patches, emissions, occupancy queries, transient body mask/results, and native metrics; Windows native and Web payloads present; Linux pointers unresolved |
| Active-only buffered backend | **Planned** comparison/fallback | enum reserved; ticking it fails explicitly |
| Level save/load | **Current**, fixed demo scope | CYSD1 1024² cell payload and player/options/up to three body records; see [contracts](interfaces-and-message-contracts.md) |
| Exact replay, general persistence and safe live reconfiguration | **Planned** | no complete replay/configuration/streaming schema or drain/resize/publish protocol |

## Current platform evidence and limits

- Rapier Web update (2026-09-08): both Web profiles package the exact v0.35.2
  official binaries and enable Physics Pit after its behavioural capability
  probe. A shared 600-tick fixture passes on Windows native and Chromium Web
  with one/six cellular workers, including thin-floor contact, material
  displacement, pause, menu, reset, and level/body save restoration. See the
  [Rapier runbook](../operations/rapier-2d-migration-runbook.md).

- Auto policy update (2026-09-08): native and threaded Web now select 2 workers
  below 4 reported logical threads, 4 below 12, and 6 otherwise. Compatibility
  Web stays serial. The Web Performance menu and native CLI expose isolated
  benchmark/stress fixtures; see [Web worker profile](../operations/web-threading.md).

- Earlier 2026-09-08 Web evidence (before Auto policy): four-worker pthread profile built and
  validated in Chromium 152, alongside default one-worker compatibility. The
  120-tick four-demo exported-level parity fixture passes with 480 parallel
  phases. Godot still synchronously waits for each tick; full asynchronous Web
  ownership remains unimplemented. Rapier Web was subsequently enabled above. See
  [local Web threading guide](../operations/web-threading.md).

- Unsupported extension architectures fall back to the older discrete GDScript world and therefore do not have native performance or identical Water behavior.
- Windows Godot import and all 15 current fixtures passed on 2026-09-08; see the audit for commands/artifact hashes. Historical Linux preflight and scene results do not validate current local Linux pointer files.
- The nine-group GDScript interaction regression passes in m11, including the wide-Water basin. The fallback still uses a different discrete liquid model and is not a performance or bit-equivalence claim for native Water.
- Native lazy mode may allocate chunks during a tick; preallocated regions prove zero owned chunk/optional-field allocations and expose any violation in TickStats.
- Changed Godot revisions copy only accumulated dirty RG8 patches across the native bridge, but the current `ImageTexture.update()` still uploads the full finite RG8 backing image.
- Desktop pacing/commands belong to one Godot Thread; Web main-thread callbacks wait for the cellular tick. Both native paths dispatch eligible phase jobs; sparse jobs may remain serial.
- Body coupling is rectangular. Desktop samples asynchronously; Web sequentially applies results, steps Rapier, masks bodies, and ticks cells, pausing that chain while terrain colliders drain.
- Bounded translation sweep is implemented; generalized shape rasterization, torque, particle fallback, and a selective CCD/substep controller remain absent. Unresolved overlap is retained and counted.
- Current Wall pixels are merged into Rapier static rectangle shapes. Cellular wall correction/support impulses are disabled to avoid double-solving hard contacts.
- True GPU texture-subregion writes remain planned; the Current adapter already uses dirty native payloads and dirty CPU image reconstruction.
- Growth, combustion, rockets, and other imported rules are behaviorally adapted; exact Sandspiel stochastic constants and deferred wind/pressure effects are not claimed.

## Approved target baseline

- SimulationCore: native C++, authoritative, Godot-free.
- SimulationScheduler: fixed phases and a persistent native worker pool are **Current**; desktop wall-clock pacing and synchronous Web callbacks are distinct owners.
- WorldStorage: chunks, activation, optional fields, and capacity are **Current**; fixed-demo level encoding exists. General persistence remains **Planned**.
- Activity block: leading 32×32 work-elimination and dirty granularity.
- Phased job: 64×64 scheduling cores, exclusive radius-two write domains, and four barriers are **Current**.
- Buffered job: retained active-only isolated output and deterministic transfer backend.
- MaterialRules: immutable descriptors and compact kernels are **Current**.
- RenderBridge: native dirty snapshots and copied Godot RG8 patch consumption are **Current**; renderer-specific GPU subregion writes remain **Planned**.
- GameplayBridge: queued tick-boundary commands and immutable results.
- Interest/capacity: bounded preallocation is **Current**; general configuration persistence and safe live reconfiguration remain **Planned**.
- Water: phased conserved pairwise fixed point, stable rest, and render-only dither are **Current**; buffered flux remains an unimplemented fallback.
- GPU: deferred for suitable non-authoritative fields initially.
- Rigid-body coupling: separate stable occupancy mask, packed immutable samples/results, bounded overlap reconciliation, Rapier2D backend, and explicit manual step ownership after a drop-in baseline.
- Fidelity: exact repeated/worker-parity fixtures are **Current**; a selectable strict runtime policy and complete replay capture are **Planned**. Bounded runtime approximation is **Approved**, subject to explicit collision/conservation constraints.

## Reversible implementation checkpoints

This is the historical M11 checkpoint sequence, not a fresh set of acceptance
runs or guaranteed local rollback archives. Status describes source features;
Linux timing/sanitizer/scene entries record that historical scope. Current
Windows/Web checks and backup gaps are in the [audit](../audits/2026-09-08-documentation-audit.md).

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
| 8. Collapse, optional fields, and world generation | **Current**, partial | Bounded explosions and static-to-granular Stone conversion exist; general fracture bodies, field solvers, and streamed generation remain **Planned** | Event capacity/bounds, replay hashing, actual fall, worker parity, and C API tests pass | Checkpoint 7 |
| 9. Rigid-body and bounded-fidelity proof | **Current**, runtime coverage partial | Separate rectangle body mask/results, bounded sweep, three test bodies, and fallback-only adaptive cadence | Rapier/body-mask/sweep fixtures pass; broad manual gameplay remains | Checkpoint 8 plus script fallback |
| 10. Rapier2D migration | **Current**, partial platform coverage | Pinned vendored dependency, activation/preflight, focused drop-in baseline, explicit stepping, direct state, batch transforms, and bounded swept cellular reconciliation | Linux x86_64 focused fixtures pass; export matrix and gameplay stress remain | Complete checkpoint 9 archive |
| 11. Runnable native Godot authority | **Current** source; historical Linux evidence; later Windows/Web evidence in audit | GDExtension wrapper, seven-worker measured Linux fixture, native body mask/results, full-rate Water/Sand, Paste/Slush, and script fallback | Historical Linux ~30k-cell shower mean 4.14 ms; scene/thin-floor fixture pass; Windows PE/export/import checks pass | Checkpoint 10 archive and serial script fallback |
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
- exact rollback point (verify it exists; do not name an unavailable archive as a usable backup);
- the [documentation-update checklist](../../AGENTS.md#documentation-obligations), including affected consumers, source/evidence links, independent retrieval scope, and declared deferred updates.

Unrelated gameplay/render refactoring is excluded.

## Decisions still required

1. Generalized bounded gameplay command/result queues beyond the Current emission/body-sample methods.
2. Whether any field needs the reserved active-only buffered backend.
3. Generalized deferred-event representation and canonical ordering beyond the Current bounded explosion queue.
4. Heat conduction, pressure/wind, phase-change quantities, and optional-field cadence.
5. General configuration/world/replay schema, versioning, migration, and I/O backpressure beyond the Current CYSD1 fixed-demo level format.
6. Safe pause/drain/reserve/publish live reconfiguration protocol.
7. Renderer-specific GPU subregion update path, production snapshot capacity defaults, and any compression/coalescing policy beyond Current dirty rectangles.
8. Appearance graph resource/schema/compiler, artist tooling, orientation/overlay representation, and production HDR/glow/flair quality controls.
9. Replay/hash version compatibility and stored fixture format; include external inputs/configuration and Rapier state. World::state_hash currently omits the simulation region, adhesion option, and transient body inputs.
10. Numerical acceptance thresholds and named reference hardware.
11. Generalized shape representation, serialized sweep/CCD/substep policy, force/torque units, particle fallback, and high-count callback policy.
12. Native fidelity-policy controls, target-work/hysteresis rules, snapshot-age response, and which secondary fields may spatially coarsen.
13. Desktop/Web common tick order and failure behavior: desktop character precedes cells and ignores the tick return; Web character follows cells and pauses on failure.
14. Source checkout/backup establishment and Web CI/toolchain/template-lock reconciliation described in the audit; no implementation/configuration changes were made in the documentation audit.

## Status-update rule

A source behavior is **Current** only when matching source/configuration and
its ownership/interface are inspected. Describe a partial prototype as partial.
Name the dated platform/artifact evidence separately for runtime claims, and
record absent validation or contradictory requirements explicitly. **Approved**
intent alone is insufficient. Acceptance/completion claims additionally require
the applicable checks and resolution of relevant contradictions. Update status
and ADR evidence sections whenever this scope changes.

## Related decisions

- [All ADRs](../decisions/)
- [Testing and replay](../operations/testing-validation-and-replay.md)
- [ADR-009: Rapier2D rigid-body backend](../decisions/ADR-009-rapier-2d-rigid-body-backend.md)
- [Retrieval index](retrieval-index.md)
