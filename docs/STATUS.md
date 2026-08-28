---
title: Legacy milestone status — 2026-08-26
status: Ambiguous
scope: Historical completion claims, limitations, reported checks, and benchmark observations for the shipped milestone
keywords: [legacy status, milestone, current prototype, benchmark claim, limitation]
related-documents: [reference/status-and-roadmap.md, operations/testing-validation-and-replay.md, systems/water-design.md]
last-reviewed: 2026-08-27
implementation-state: Legacy status report; source evidence remains authoritative and later Water, adaptive activity, and rigid-body work supersede several claims below.
---

# Milestone status — 2026-08-26

## At a glance

- Purpose: preserve what the milestone previously reported as complete or limited.
- **Current**: native and Godot prototype components described here exist in source.
- **Ambiguous**: reported validations and benchmarks were not re-run for this documentation set.
- **Current** defect: water behavior observed later contradicts any claim of fully stable resting water.
- Use reference/status-and-roadmap.md for the audited current/approved distinction.

## Search anchors

legacy milestone status, prior benchmark, prior test claim, known limitations, water contradiction

## Related decisions

- [ADR-005](decisions/ADR-005-water-model.md)
- [Testing specification](operations/testing-validation-and-replay.md)
- [Audited status](reference/status-and-roadmap.md)

## Completed

- Deterministic C++20 cellular kernel.
- Sparse signed-coordinate chunks.
- Cross-chunk sand, water, and smoke movement.
- Density-based sand/water displacement.
- Chunk sleeping and wake propagation.
- Dirty rectangles and bulk RGBA extraction.
- Stable C ABI and shared-library build.
- Pure-C header compile check.
- Interactive Godot 4 reference sandbox.
- Strict-warning-safe GDScript types without `CanvasItem.material` shadowing.
- One-byte R8 material texture with GPU palette lookup and bulk texture updates.
- Sleeping active-row spans and a byte update epoch in the GDScript reference.
- Independent fixed 60 Hz worker stepping with bounded backlog and live
  simulation, snapshot-copy, upload, and overrun counters.
- 960×544 finite proof world behind a 320×180 shader-controlled camera.
- 16×16 activity blocks with movable counts and optional distant cadence LOD.
- Buffered camera-only simulation: 10% horizontal and 20% vertical margins,
  with preserved wake state outside the window.
- Per-cell eight-tick quiescence inside awake blocks, with a one-cell mutation
  wake ring for dormant buried material.
- Write-once movement destinations that prevent same-tick liquid cascades and
  reduce oscillating surface gaps.
- Six-cell water lateral budgets with local column-pressure comparison, allowing
  dithered water to reach a stable sleeping state.
- Dedicated simulation thread with exclusive mutable-world and sampled-character
  ownership, mutex-protected commands, and immutable typed snapshots.
- Separate simulation, worker-step, snapshot-copy, texture-upload, and worker
  overrun counters.
- Sampled-collision character with independent world position, velocity, and
  continuous held-key jetpack thrust.
- Follow/free camera modes and world-coordinate painting across the larger map; paint slots are now presentation-only mappings over a generic material-emission queue.
- Windows MSVC and GNU Make build entry points.

Nine native behaviour tests pass in debug and Address/Undefined Behaviour
Sanitizer builds. LeakSanitizer itself is unavailable in the build container,
so AddressSanitizer was run with leak detection disabled.

## Initial benchmark baseline

These measurements are regression baselines from the development container, not
claims about end-user hardware.

| Scenario | Region | Chunk | Mean native tick |
| --- | ---: | ---: | ---: |
| Dense mixed materials | 512×512 | 128 | 22.53 ms |
| Dense mixed materials | 1024×1024 | 128 | 71.72 ms |
| Sparse active area in loaded world | 2048×1024 | 128 | 1.09 ms |

Sparse 2048×1024 comparison:

| Chunk size | Allocated chunks | Final active chunks | Mean tick |
| ---: | ---: | ---: | ---: |
| 64 | 512 | 42 | 1.24 ms |
| 128 | 128 | 20 | 1.09 ms |
| 256 | 32 | 16 | 1.73 ms |

The results support 128×128 as the provisional default: 256 performs well in a
dense compact test but wastes work when only small regions of a large loaded
world are active.

The 1024² dense test is still roughly three to four times slower than the
eventual 20–25 ms stress-test gate. That is expected at this reference stage.
The next optimization work should target:

1. Pre-resolved neighbourhood access instead of repeated coordinate/hash lookup.
2. Active-row masks, followed by active-cell bitsets.
3. Staged chunk-boundary exchange suitable for deterministic parallel jobs.
4. Compact update epochs and optional cell arrays.
5. Profile-guided changes before SIMD or GPU experiments.

## Known limitations

- **Ambiguous** legacy limitation, superseded on bundled Linux and Windows x86_64 builds: the Godot
  coordination worker now advances native World, whose phased jobs use a
  persistent C++ pool; unsupported architectures retain the serial GDScript fallback.
- The camera simulation window rejects work at 16×16 block granularity, so edge
  blocks may extend up to 15 cells beyond the exact percentage buffer.
- Cell quiescence adds one byte per finite proof cell. The native version should
  compare byte ages with compact dormant bitmasks before committing its format.
- Water flow budget adds another byte per finite proof cell; native material-
  specific optional arrays should avoid paying this cost in chunks without water.
- Every changing world revision still duplicates and uploads the complete
  960×544 material array. Immutable dirty chunks or camera-region snapshots are
  the next worker/render boundary optimization.
- The finite proof uploads the complete 960×544 R8 texture after material
  changes; dirty chunk textures or camera-region extraction are still pending.
- Character coupling remains terrain-to-character only. Separately, three
  Current RigidBody2D rectangles now project a worker-owned entity occupancy
  mask and receive approximate cellular impulses/corrections; generalized/native
  body coupling remains **Planned**.
- **Ambiguous** legacy limitation, superseded by the 2026-08-27 native
  checkpoint: only five prototype rules executed in this historical milestone;
  all valid catalogue IDs now have adapted standalone-native kernels.
- No heat, full pressure solver, chemistry, save files, collision contours, or
  intra-simulation parallel chunk jobs.
- Dense liquid behaviour is deliberately simple and is not volume conserving
  beyond one full cell per material unit.
- This large-world proof has not been launched or benchmarked in this turn, in
  accordance with the requested local-validation workflow.
