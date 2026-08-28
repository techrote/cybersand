---
title: Legacy next-milestone plan
status: Ambiguous
scope: Historical native Godot integration work packages and performance gates
keywords: [legacy plan, native integration, GDExtension, activity mask, chunk jobs]
related-documents: [reference/status-and-roadmap.md, architecture/module-boundaries.md, decisions/ADR-002-double-buffered-tile-jobs.md]
last-reviewed: 2026-08-28
implementation-state: Historical plan; its Linux and Windows x86_64 GDExtension, native authority, emissions/queries, activity geometry, phased scheduler, and rectangle coupling items are now implemented, while generalized queues and dirty Godot uploads remain open.
---

# Next milestone: native Godot integration

## At a glance

- Purpose: retain the earlier native-integration plan for provenance.
- **Current**: the historical GDExtension/native-authority milestone is implemented for bundled Linux and Windows x86_64 builds through `CyberNativeCellWorld`.
- **Approved design**: backend-neutral fixtures and one-worker scheduler candidates now precede multicore integration.
- **Approved design**: leading spatial sizes are 128×128 storage chunks, 32×32 activity blocks, and 64×64 scheduling cores.
- Use status-and-roadmap for the current reversible checkpoint order.

## Search anchors

legacy next milestone, native bridge history, GDExtension implemented, historical work package, superseded scheduler plan

## Related decisions

- [ADR-001](decisions/ADR-001-native-simulation-core.md)
- [ADR-002](decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-005](decisions/ADR-005-water-model.md)

## Goal

Replace the GDScript reference cell update with the C++ kernel while retaining
the interactive sandbox, then establish trustworthy performance measurements.

## Work packages

1. Pin a supported Godot 4.x version and matching `godot-cpp` revision.
2. Add the GDExtension build without forking the Godot engine.
3. Wrap the world in a native `PixelWorld` class.
4. Preserve the proof's command/snapshot worker boundary while replacing its
   GDScript-owned world with the native `PixelWorld`.
5. Return dirty region image data in bulk.
6. Add material-emission and region-query methods; retain painting as one gameplay/tool producer rather than coupling it to material identity.
7. Display active chunks, dirty rectangles, worker overruns, snapshot-copy time,
   texture-upload time, and time-per-tick in the sandbox.
8. Benchmark chunk sizes 64, 128, and 256 under identical workloads.
9. Port the reference sandbox's 16×16 activity-block idea into compact native
   masks, preserve frozen wake flags outside the camera simulation window, carry
   per-cell quiet state or compact dormant masks, and compare a deduplicated
   active queue with full active-chunk scans.
10. Add deterministic staged chunk jobs: parallel interiors, buffered boundary
   transfers, and an ordered merge phase.
11. Return camera-sized R8 material-ID regions or per-chunk textures instead of
    uploading the complete finite proof world.
12. Expose bulk occupancy queries for the sampled character and later vehicles.
13. Replace the Current native/fallback rectangular occupancy proof with
    generalized collider rasterization and a stable body sample/result contract.

## Exit criteria

- Godot runs exactly the same native kernel as the command-line tests.
- A deterministic seed produces the same state hash in the test and Godot app.
- No per-cell language-boundary calls occur during stepping or rendering.
- Static chunks sleep and cease consuming measurable simulation time.
- A 1024×1024 dense benchmark and a large mostly-sleeping benchmark are recorded
  on the chosen minimum-spec machine.
- The profile overlay identifies simulation, upload, rendering, and main-thread
  frame time separately.
- Camera movement never shifts simulation storage or changes global entity
  coordinates.
- Activity masks can represent several separated moving regions without
  scanning the inactive space between them.
- Buried cells remain dormant while boundary changes wake only the affected
  neighbourhood and propagate deterministically.
- Simulation work is bounded to an interest rectangle while off-screen chunks
  retain resumable state and remain eligible for save/background policies.
