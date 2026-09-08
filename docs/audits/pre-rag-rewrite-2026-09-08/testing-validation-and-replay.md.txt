---
title: Testing, validation, and replay
status: Current
scope: Executable test inventory, dated platform evidence, level-save versus replay guarantees, and future validation gates
keywords: [unit test, deterministic replay, gameplay approximation, rigid body mask, scanline, tile edge, chunk edge, liquid conservation, settled water]
related-documents: [../architecture/determinism-and-boundary-transfers.md, ../architecture/rigid-body-and-cellular-coupling.md, ../systems/water-design.md, profiling-observability-and-performance.md]
last-reviewed: 2026-09-08
implementation-state: Native and Godot fixtures exist, including CYSD1 level saves, Web worker parity, Auto policy and Rapier Web coupling. Passing runs are dated below; exact replay persistence, exhaustive hash coverage and current Linux sanitizer evidence remain unavailable.
---

# Testing, validation, and replay

## At a glance

- Purpose: make correctness and performance gates part of every reversible checkpoint.
- Scope rule: **Current** describes inspected implementation, not an undated test pass. See [the 2026-09-08 audit](../audits/2026-09-08-documentation-audit.md) for source identity and checks against this local snapshot; source is reconstructed from `e2892c54d4bd91aac60971e81c748bd49fbe2adb` plus local edits, without a source Git checkout.
- **Current**: 39 native tests cover scheduler geometry, materials, Water, Smoke displacement/lifetime/Fire exclusion, optional storage, bounded explosions, immutable snapshot leases, capacity, C ABI, themed solids/combustion, sleep/dirty behavior, and repeat determinism.
- **Current**: Godot presentation regressions compile all 42 flair mappings, verify representative specialized rows, assert 1920×1080 settings, and exercise F3 hide/restore on the actual main scene.
- **Current**: one- and four-worker phased runs produce identical state hashes in Water and complete-material fixtures.
- **Current**: a closed Water fixture checks exact mass every tick, settles without a heap, becomes content-hash-stable, and sleeps (`state_hash` still changes with time).
- **Historical validation**: the 2026-08-28 Linux M11 audit records ASan+UBSan with leak detection disabled and TSan passes; LeakSanitizer was blocked by hosted `/proc` restrictions. This is not sanitizer evidence for the current Windows/Web snapshot.
- **Current**, partial: scheduler-core and storage-chunk crossings are covered, but every direction/material/radius combination is not.
- **Current**, partial: native snapshot lifetime, pressure, C ownership, concurrent producer/consumer behavior, and GDExtension dirty-patch consumption have fixtures with dated platform results; true GPU subregion writes and visual output profiling are absent.
- **Current**: the Godot appearance regression checks 81 palette/program rows, increased solid contrast, representative flair codes, unclamped HDR neon, fallback collision, native ID acceptance, and hard-surface invalidation.
- **Current**: Rapier preflight checks the pinned Godot version, vendored extension, registered server class, and selected engine; dated Linux and Windows evidence is distinguished below.
- **Current**: focused fixtures confirm ordinary automatic RigidBody2D integration, explicit manual stepping, complete packed body samples, and pause ownership.
- **Current**: `test_cell_world.gd` covers nine Smoke, small/wide Water, body mask/sweep, and scanline groups; platform/date results are below. The wide basin uses bounded contiguous pressure look-ahead; native Water remains authoritative when the native adapter is selected.
- **Current**: CYSD1 level restoration, Web worker parity, Auto boundaries, benchmark cancellation/statistics, and the three-body Rapier Web fixture have runnable regressions.
- **Planned**: generalized gameplay queues, exact replay persistence, completion-order perturbation, mirrored bias, and safe 2× capacity/reconfiguration fixtures.

## Evidence scope and platform matrix

Historical reports remain unchanged in [audits/m11](../audits/m11/README.md).
Retained local runs below are dated observations; their manifests do not bind
every source/dependency byte to a clean commit. The current audit records fresh
checks separately, so none of these rows implicitly certifies later local edits.

| Evidence | Recorded result and scope | Retained location |
|---|---|---|
| 2026-09-08 documentation audit | Fresh doctor checks, native 39/39 and Godot 15/15 on Windows; retained Windows GDExtension used, not rebuilt; existing Web checksum sets verified, no fresh browser run | [Audit identity and exact logs](../audits/2026-09-08-documentation-audit.md); `C:/kybersand/validation/local/20260908-201010/native-test.json`, `C:/kybersand/validation/local/20260908-201106/godot-fixtures.json` |
| 2026-08-28 audited M11 | Native normal/sanitizer and Linux Godot checks; Windows cross-build structure was not a runtime launch | [M11 completion report](../audits/m11/m11-completion-report.md) |
| 2026-09-07 Windows setup | 39 native tests and 11 Godot fixtures; Chromium compatibility demo/save checks | `C:/kybersand/LOCAL-DEV-SETUP-REPORT.md`, `validation/local/20260907-213621/`, `validation/local/20260907-213405/` |
| 2026-09-08 Windows Rapier checkpoint | 15/15 Godot `test_*.gd` runners, including the Web scene fixture running under native Godot | `C:/kybersand/validation/local/20260908-152453/godot-fixtures.json` |
| 2026-09-08 Chromium 152 on Windows | Compatibility/1 worker and threaded/6 workers: 600 Rapier coupled ticks; 308,087 contacts, 151 displaced cells, no recorded console errors/warnings | `C:/kybersand/validation/local/rapier-web-20260908/browser-results.json`; [runbook limits](rapier-2d-migration-runbook.md) |
| 2026-09-08 reference benchmark | Native/Chromium final **level-payload** hashes match across tested counts; 600-tick stress parity | `C:/kybersand/validation/local/auto-workers-20260908/browser-reference.json`; [Web threading](web-threading.md) |

The nine groups in `test_cell_world.gd` are one Godot runner, not nine additional
`test_*.gd` files. Older 11/12/14 fixture totals refer to earlier inventories.
HTTP payload checks prove packaging/MIME/headers; headless Godot tests prove
native execution; browser evidence requires the actual exported Web scene.

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
compiler and verifies that the loaded native extension accepts themed IDs; it does not rebuild or prove binary provenance.
godot/tests/test_cell_world.gd provides nine runnable Godot regressions for
Water leveling, Smoke density exchange, body-mask blocking/sweep, and bottom-up
vertical-chain continuity. The m11 run passes all nine groups, including the
5,192-cell wide-Water leveling fixture.

Current gaps:

- no current Linux/macOS/WSL runtime validation or non-x86_64 CyberSand GDExtension build; no Firefox/Safari acceptance, true GPU subregion write path, or formal bounded gameplay queue test;
- no generalized-shape/exhaustive CCD fixture or high-count callback-disabled benchmark; the existing thin-floor/three-rectangle fixture and body level restoration are bounded proofs;
- no completion-order perturbation harness beyond natural worker scheduling and TSan;
- no every-direction shifted/mirrored boundary matrix;
- no saved replay fixture/schema or hash compatibility version;
- no safe live reconfiguration test;
- no complete world/configuration/replay serialization test beyond fixed-size CYSD1 levels;
- no process-wide allocator interception or successful LeakSanitizer run in this hosted environment.

Normal, ASan+UBSan with leak detection disabled, and TSan test suites were
historically executed on 2026-08-28. A successful current-platform sanitizer
run remains unavailable; the old LeakSanitizer outcome is an environment limitation.

## Test layers

| Layer | Status | Purpose |
|---|---|---|
| MaterialRules/reference tests | **Current**, partial | Deterministic material families, arithmetic, conversions, conservation |
| World storage tests | **Current**, partial | Chunk identity, optional fields, activation, capacity; full persistence/reconfiguration missing |
| Phased job tests | **Current**, partial | Geometry, edges, bounded radius metadata, wake/dirty, worker equality |
| Transfer/merge tests | **Approved design** | Stable edge effects, conflicts, conservation, completion-order independence |
| Scheduler replay tests | **Current**, partial | Repeat and worker-count equivalence; overload/reconfiguration transitions missing |
| Bridge contract tests | **Current**, partial | Native snapshot lifetime/pressure/C ownership/concurrency plus focused Godot malformed patch and lifetime regressions; generalized gameplay queues missing |
| Godot interaction regression | **Current** runner; dated passes above | Nine GDScript groups, including wide Water; native Water retains separate conservation/settling coverage |
| Rapier dependency preflight | **Current** fixture; dated platform passes above | Godot 4.7.x, vendored GDExtension, registered RapierPhysicsServer2D class, and Rapier2D selection |
| Rapier drop-in fixture | **Current** fixture; dated platform passes above | Ordinary RigidBody2D plus RectangleShape2D advances under automatic Rapier stepping |
| Rapier manual-step fixture | **Current** fixture; dated platform passes above | Bridge initialization, falling transform, three packed samples, and pause stopping `space_step` |
| Full-scene smoke | Historical Linux validation | Main scene ran headlessly for 180 frames with the worker and manual Rapier bridge in M11 |
| Godot/native integration tests | **Current**, focused | Dated Linux M11 and Windows local runs; current revision coverage requires the audit evidence above |
| CYSD1 and Web fixture runners | **Current**, focused | Native payload round trip/rejection, worker level parity, Auto and benchmark regressions, Rapier coupling/body level restoration |
| Benchmark fixtures | **Current**, partial | Native CLI and Web menu reference fixtures; production capacity/memory acceptance remains **Planned** |

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

## Level saves are not exact replay checkpoints

**Current:** [demo_save_codec.gd](../../godot/scripts/demo_save_codec.gd)
implements CYSD1 version 1 with a fixed 1024×1024 native payload, bounded JSON
metadata, DEFLATE, SHA-256 integrity and canonical Base64. The
[Web controller](../../godot/scripts/web_demo_controller.gd) restores player,
demo/options and up to three Physics Pit bodies. Native import validates the
payload before replacing the native world. Body transforms/velocities/sleep
restoration is tested within `1e-5`, not bitwise Rapier state identity.

Matching exported level bytes proves only the serialized cells/temperature and
selected metadata. CYSD1 does not capture tick/epoch/activity/scheduler state,
pending authoritative events, all configuration, or Rapier contact caches.
Import constructs a new simulation state; it cannot promise identical subsequent
trajectories. Browser parity and benchmark hashes are SHA-256 of level payloads,
not `World::state_hash()`. Exact resume/replay persistence remains **Planned**.

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

The current in-memory algorithm is implemented in
[World::state_hash/content_hash](../../native/src/world.cpp), not undecided.
A stable externally stored hash schema and compatibility version are **Planned**.
Coverage is incomplete: for example, `liquid_surface_adhesion_enabled_` and
transient body obstacle/contact inputs are not hashed; Rapier state is outside
World entirely. Do not describe either hash as complete replay attestation.

## Activity and scheduling-boundary fixtures

**Planned coverage expansion:** the current inventory covers selected cases;
the full matrix below is a validation requirement, not an executed pass list.

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
- `content_hash` stays stable (the full state hash includes the advancing tick);
- visual dither may remain visible without authoritative dirty changes.

### Heap prevention

A connected liquid fixture must not retain a sand-like slope solely due to exhausted travel history or premature sleep. Use the executable fixture's exact surface tolerance when reporting a pass; broader reference-model/mirrored coverage remains **Planned**.

### Edge and wake

Mass crossing tile/chunk edges remains conserved, wakes required neighboring work, and yields the same final hash under all tested worker counts.

## Capacity and reconfiguration fixtures

**Planned complete matrix**; existing capacity/snapshot cases are identified in
the inventory above. Live reconfiguration is unimplemented.

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

Also record actual Git HEAD/dirty state or snapshot provenance plus a changed-file
hash manifest; command, timeout, date, compiler/runtime/dependency identity,
platform/browser/profile/worker count, and passed/failed/timed-out/skipped results.
Identify the exact comparison (cells, level bytes, content hash, state hash or
body tolerance). Link each changed Current claim to source and applicable run;
update focused docs, interfaces/invariants, ADR/status, build guidance and the
retrieval index as affected. Preserve old results and label their earlier scope.

No later system is integrated while its prerequisite checkpoint has unresolved correctness failures.

## Related decisions

- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-005](../decisions/ADR-005-water-model.md)
- [Status and roadmap](../reference/status-and-roadmap.md)
- [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md)
- [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md)
- [ADR-009](../decisions/ADR-009-rapier-2d-rigid-body-backend.md)
