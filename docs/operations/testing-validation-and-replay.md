---
title: Testing, validation, and replay
status: Current
scope: Current native coverage, strict replay, gameplay-approximation fixtures, rigid-body coupling, conservation, settling, capacity, bridge, profiling, and checkpoint evidence
keywords: [unit test, deterministic replay, gameplay approximation, rigid body mask, scanline, tile edge, chunk edge, liquid conservation, settled water]
related-documents: [../architecture/determinism-and-boundary-transfers.md, ../architecture/rigid-body-and-cellular-coupling.md, ../systems/water-design.md, profiling-observability-and-performance.md]
last-reviewed: 2026-08-28
implementation-state: Thirty-eight native behavioral/catalogue tests and a focused 81-row appearance-LUT regression pass; Rapier, dirty RG8, shader-loaded full-scene, and Linux native checks pass while Windows runtime, serialization, and target-GPU profiling remain absent.
---

# Testing, validation, and replay

## At a glance

- Purpose: make correctness and performance gates part of every reversible checkpoint.
- **Current**: 39 native tests cover scheduler geometry, materials, Water, Smoke displacement/lifetime/Fire exclusion, optional storage, bounded explosions, immutable snapshot leases, capacity, C ABI, themed solids/combustion, sleep/dirty behavior, and repeat determinism.
- **Current**: Godot presentation regressions compile all 42 flair mappings, verify representative specialized rows, assert 1920×1080 settings, and exercise F3 hide/restore on the actual main scene.
- **Current**: one- and four-worker phased runs produce identical state hashes in Water and complete-material fixtures.
- **Current**: a closed Water fixture checks exact mass every tick, settles without a heap, becomes hash-stable, and sleeps.
- **Current**: ASan+UBSan and TSan suites pass; LeakSanitizer is blocked by hosted `/proc` restrictions.
- **Current**, partial: scheduler-core and storage-chunk crossings are covered, but every direction/material/radius combination is not.
- **Current**, partial: native snapshot lifetime, pressure, C ownership, concurrent producer/consumer behavior, and Linux GDExtension dirty-patch consumption are tested; true GPU subregion writes and visual output profiling are absent.
- **Current**: the Godot appearance regression checks 81 palette/program rows, increased solid contrast, representative flair codes, unclamped HDR neon, fallback collision, native ID acceptance, and hard-surface invalidation.
- **Current**: Rapier preflight checks the pinned Godot version, vendored extension, registered server class, and selected engine; it passes on Linux x86_64.
- **Current**: focused fixtures confirm ordinary automatic RigidBody2D integration, explicit manual stepping, complete packed body samples, and pause ownership.
- **Current**, fallback-only known failure: the GDScript nine-fixture run passes Smoke, small Water, body mask/sweep, and scanline groups but its wide Water basin exceeds the two-pixel height bound; the same failure is reproduced in m7 and is not caused by m8 smoke culling.
- **Planned**: gameplay bridge, Godot integration, serialization, completion-order perturbation, mirrored bias, and 2× capacity fixtures.

## Search anchors

how deterministic replay tested, current tests, water conservation test, settled shimmer test, tile edge test, multithread equivalence, capacity overflow fixture

## Current test inventory

native/tests/test_world.cpp currently covers:

1. signed coordinates and four-phase scheduler geometry/non-overlap;
2. Sand falling across chunk and scheduling-core boundaries without double update;
3. 32×32 activity sleep/wake and dirty rectangle extraction;
4. serial/phased material-total parity and repeated deterministic runs;
5. one/four-worker exact state parity for Water, base scenes, and the complete material catalogue;
6. directional density displacement through Water/Sand, a multi-cell Smoke/Water sorting fixture, conserved Water leveling/stability/sleep, explicit column-mass tolerance, and Water/Oil behavior;
7. optional temperature allocation and cross-chunk movement;
8. Fire/Wood/Oil, Lava/Water/Ice, Dust, Acid, and Stone behavior;
9. Cloner, Plant, Fungus, Seed, Mite, and Rocket state machines;
10. preallocated zero-owned-allocation ticks and explicit chunk-capacity exhaustion;
11. legacy/versioned C ABI, RGBA, mass/query, config version, and material descriptor behavior;
12. bounded explosion validation/capacity, queued-event hash coverage, static-to-granular collapse, and one/four-worker parity;
13. reusable immutable snapshot publication, deterministic patch order, exact byte capacity, dirty retention, pressure recovery, high-water, concurrent leases, and C lifetime;
14. catalogue completeness, reserved ID, four-byte cells, and rule-radius metadata;
15. themed IDs 38–80, zero-radius inert solids, Oak/Thatch combustion reuse,
    visual-state projection, hard-surface classification, and C API lookup.

native/tests/test_c_header.c checks C ABI inclusion and basic use.
godot/tests/test_material_appearance_lut.gd checks the bounded appearance
compiler and verifies that the rebuilt native extension accepts themed IDs.
godot/tests/test_cell_world.gd provides nine runnable Godot regressions for
Water leveling, Smoke density exchange, body-mask blocking/sweep, and bottom-up
vertical-chain continuity. Its 2026-08-27 run had one failing group: wide Water
leveling. The new body-mask and swept-displacement assertions passed.

Current gaps:

- no Windows Godot runtime launch, non-x86_64 CyberSand GDExtension build, true GPU subregion write path, or formal bounded gameplay queue test;
- no non-Linux runtime fixture, generalized-shape/CCD fixture, high-count callback-disabled benchmark, or Rapier state save/load fixture;
- no completion-order perturbation harness beyond natural worker scheduling and TSan;
- no every-direction shifted/mirrored boundary matrix;
- no saved replay fixture/schema or hash compatibility version;
- no safe live reconfiguration test;
- no serialization test;
- no process-wide allocator interception or successful LeakSanitizer run in this hosted environment.

Normal, ASan+UBSan with leak detection disabled, and TSan test suites were
executed on 2026-08-28. LeakSanitizer remains blocked by hosted `/proc`
restrictions rather than a reported project leak.

## Test layers

| Layer | Status | Purpose |
|---|---|---|
| MaterialRules/reference tests | **Current**, partial | Deterministic material families, arithmetic, conversions, conservation |
| World storage tests | **Current**, partial | Chunk identity, optional fields, activation, capacity; serialization/reconfiguration missing |
| Phased job tests | **Current**, partial | Geometry, edges, bounded radius metadata, wake/dirty, worker equality |
| Transfer/merge tests | **Approved design** | Stable edge effects, conflicts, conservation, completion-order independence |
| Scheduler replay tests | **Current**, partial | Repeat and worker-count equivalence; overload/reconfiguration transitions missing |
| Bridge contract tests | **Current**, partial native render publication | Immutable snapshot lifetime/pressure/C ownership/concurrency; gameplay and Godot adapters missing |
| Godot interaction regression | **Current**, fallback-only known failure | Older GDScript nine-fixture run failed wide Water leveling; preferred native Water has separate passing native conservation/settling coverage |
| Rapier dependency preflight | **Current**, passing on Linux x86_64 | Godot 4.7.x, vendored GDExtension, registered RapierPhysicsServer2D class, and Rapier2D selection |
| Rapier drop-in fixture | **Current**, passing on Linux x86_64 | Ordinary RigidBody2D plus RectangleShape2D advances under automatic Rapier stepping |
| Rapier manual-step fixture | **Current**, passing on Linux x86_64 | Bridge initialization, falling transform, three packed samples, and pause stopping `space_step` |
| Full-scene smoke | **Current**, passing on Linux x86_64 | Main scene runs headlessly for 180 frames with the worker and manual Rapier bridge |
| Godot/native integration tests | **Current**, focused | Native fixture, manual Rapier coupling fixture, and complete-scene smoke pass on Linux x86_64; Windows x86_64 PE architecture/export/import checks pass, but runtime launch remains Planned |
| Benchmark fixtures | **Approved design** | Performance/memory/capacity observations after correctness passes |

## Deterministic replay inputs

A replay fixture must freeze every authoritative input, including:

- initial committed world state;
- simulation-affecting configuration;
- material/rule definition identity;
- ordered gameplay intent and its tick timing;
- interest-region and capacity transitions;
- worker-count variants used for comparison;
- number of fixed ticks.

Exact replay file schema and command representation are **Planned**.

Gameplay approximation fixtures do not require identical fine state unless run
under strict mode. They do require bounded snapshot age/work, eventual deferred
progress, local collision fidelity, required conservation, and absence of
systematic artifacts. The selected fidelity policy is part of the fixture.

## Replay hash requirements

World::state_hash covers cell material/state/epoch, optional temperatures,
chunk/activity sleep metadata, tick identity, and scheduling-relevant geometry.
It also covers active/core/chunk/event capacities, the pending external
explosion queue, and maximum explosion radius.
`content_hash` deliberately excludes timing/activity and empty preallocated chunks
for settled-content comparison. A stored hash format/version is still absent.

Validation must prove:

- repeated runs match;
- one-worker and multiworker runs match;
- artificial variation in worker completion timing does not change the hash;
- a deliberately changed future-affecting field changes the hash;
- render-only dithering and wall-clock timing do not change the hash.

Hash algorithm and compatibility version are undecided.

## Activity and scheduling-boundary fixtures

For 32×32 activity boundaries and leading 64×64 scheduling geometry:

- each cardinal crossing direction;
- diagonal/corner effects if supported by the rule;
- same-phase write-domain non-overlap;
- phase-edge eligibility and within-job scan-order determinism;
- multiple producers targeting related boundary state;
- wake and dirty propagation;
- conserved liquid transfer;
- buffered isolation/transfer behavior when that candidate is selected;
- identical behavior when the same geometry is shifted or mirrored.

## Chunk-edge fixtures

Repeat equivalent cases at the 128×128 storage-chunk boundary, including negative chunk coordinates. Tile-edge and chunk-edge semantics must match except for storage lifecycle effects explicitly defined by WorldStorage.

## Water validation

### Conservation

For every closed fixture, total fixed-point mass before and after every tick is exactly equal. Sources and sinks must be explicit fixture inputs.

### Settled stability

A pool or connected container is allowed to evolve until its reference settling condition. During an explicit observation window afterward:

- authoritative state does not oscillate;
- no equivalent cells repeatedly swap;
- active work falls to the expected boundary/minimum;
- replay hash stays stable;
- visual dither may remain visible without authoritative dirty changes.

### Heap prevention

A connected liquid fixture must not retain a sand-like slope solely due to exhausted travel history or premature sleep. The exact expected surface tolerance will be frozen with the reference flux model.

### Edge and wake

Mass crossing tile/chunk edges remains conserved, wakes required neighboring work, and yields the same final hash under all tested worker counts.

## Capacity and reconfiguration fixtures

- just below each capacity;
- exactly at each capacity;
- one unit beyond each capacity;
- current interest-region fixture;
- 2× target interest-region fixture;
- larger requested region requiring safe reconfiguration;
- reconfiguration success with state/hash preservation;
- reconfiguration failure with explicit diagnostics and no clipping;
- transfer high-water plus snapshot high-water reset behavior; native snapshot observation is Current but has no reset API;
- no allocation during normal tick stages after preparation.

## Stress fixtures

- dense moving water;
- dense current or migrated Smoke;
- sustained spawn/paint commands;
- mostly sleeping large stored world;
- rapid camera/interest-region panning;
- repeated wake/sleep around boundaries;
- snapshot consumer lag;
- mixed boundary transfers.

Performance results are valid only after correctness invariants pass.

## Bridge and thread-safety validation

- Godot cannot obtain a mutable simulation pointer/reference;
- snapshot bytes remain unchanged while consumed;
- retaining a snapshot cannot invalidate active simulation storage;
- commands apply only at allowed tick boundaries;
- worker code has no scene-tree, rendering, audio, or gameplay-object access;
- native snapshot capacity outcomes follow the Current non-blocking dirty-retention policy; gameplay queues remain Planned;
- main-thread presentation does not affect replay hash.

## Per-checkpoint evidence

Every implementation checkpoint records:

- scope and rollback point;
- data owner and lifetime changes;
- invariants;
- public interface changes;
- fixture/configuration identity;
- correctness result;
- benchmark observations;
- memory and allocation result;
- known gaps and next permitted step.

No later system is integrated while its prerequisite checkpoint has unresolved correctness failures.

## Related decisions

- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-005](../decisions/ADR-005-water-model.md)
- [Status and roadmap](../reference/status-and-roadmap.md)
- [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md)
- [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md)
- [ADR-009](../decisions/ADR-009-rapier-2d-rigid-body-backend.md)
