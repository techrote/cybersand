---
title: PLAY-BUSY-001C rendered framebuffer during real native phase hold
status: Planned
document-kind: audit
canonical-for: []
last-reviewed: 2026-10-29
scope: Graphical source-matched qualification stacked on PLAY-BUSY-001B; no release promotion
related-documents: [2026-10-29-play-busy001b-real-phase-host.md, ../systems/player-control-playground.md, ../architecture/simulation-tick-and-threading.md, ../operations/github-development-and-release.md]
---

# PLAY-BUSY-001C — rendered UI progress under real native phase hold

## Purpose

PLAY-BUSY-001B proves real `World::tick_phased()` jobs can remain outstanding
while Main process/physics/input callbacks continue and that the actual worker
stop fence drains and joins in legal ownership order. That host test is
headless. #270 separately requires UI rendering/response under genuinely slow
native work.

001C is stacked on the exact 001B source hook but leaves the 001B branch
unchanged. It requires actual submitted framebuffer pixels while the **same
selected real native phase dispatch** remains held.

## Protocol

The test uses the ordinary `main.tscn`, authored Player Playground course,
Jet Barrel SetP rig, exclusive `CyberSimulationWorker`, real main-thread
Rapier and the 001B source-matched test runtime.

After ordinary parallel gameplay is established:

1. arm the 001B copied-value gate for the next complete eligible production
   pool dispatch;
2. require at least two distinct real phase callback threads held with zero
   selected task completion;
3. await `RenderingServer.frame_post_draw` and capture the real viewport;
4. submit a D press through `Input.parse_input_event`, run 30 real physics
   frames while the native dispatch stays held, release D, then capture a second
   submitted frame;
5. require Main process/physics/input counters, Rapier manual-step count and the
   actual SetP actor position to advance while the exact retained immutable
   native snapshot object/serial/tick/World generation does not change;
6. require both framebuffers to be nonblank, same-sized and visibly different
   on a fixed four-pixel sampling grid;
7. persist both unaltered PNGs, manually release the native gate before its
   safety deadline, require every selected task to complete and the actual pool
   dispatch to return, then perform ordinary scene shutdown/join.

The pixel-difference threshold is only a liveness/refusal floor. It is not a
quality metric, FPS target or visual-comparison benchmark.

## Execution environments

The stacked workflow reuses the exact special runtime build already required by
001B at the same commit.

- Linux uses Xvfb plus Mesa software OpenGL and Godot
  `gl_compatibility`; the test explicitly refuses a headless DisplayServer.
- Windows invokes the official console binary **without `--headless`**, with
  the compatibility renderer and dummy audio. If the hosted Windows session
  cannot provide a real framebuffer, the test must fail and that limitation is
  retained rather than reclassified.

The reducer uses only Python standard library. It verifies the machine result,
raw log, runtime/Rapier identities, PNG magic/IHDR dimensions and raw PNG
SHA-256 values. Before/after PNG bytes must differ.

## Boundaries

This is actual graphical framebuffer evidence, but it is still scripted CI. It
does not qualify a physical controller, focus-loss behavior on a human desktop,
sustained rendered FPS, subjective feel or release readiness. It does not
modify native solver defaults, Rapier ownership, the production worker script,
or #290/#295/#298 publication work.

The 001C branch is separate so failures or later graphical refinements do not
invalidate 001B's exact-head shutdown evidence.


## Retained first hosted failure and source-only correction — 2026-10-30

Exact-head scoped run
[40975126632](https://github.com/techrote/cybersand/actions/runs/40975126632)
is **FAILED** on both target OS render steps. The preceding 001B real-phase
shutdown fixture passed on both OSes at the same source and special runtime.
The new 001C script did not execute: Godot rejected it at parse time because
the subclass redeclared `assertions` and `failures`, which already exist in
`play_life001_shared_host_case.gd`.

Original Linux artifact `12943030911` (ZIP SHA-256
`efbc8f028aa1cbad64ec42f251821669b9ea89694de6fb7eadd2682b92365b78`)
and Windows artifact `12942850859` (ZIP SHA-256
`af1536114ca74d233e08d48cc152aaf686849f8ea7ffe58c02b58a0f67d67202`)
retain the raw parse logs. Linux reached Xvfb/Mesa llvmpipe compatibility
render setup before parse; Windows reached ANGLE/Microsoft Basic Render Driver
before the same parse refusal. No framebuffer, Main-under-hold, Rapier-under-hold
or PNG result exists for this failed source.

The successor removes only those two redundant member declarations. It does
not change the hold duration, gate, rendering method, input route, pixel
thresholds, native runtime, Rapier ownership, timeout, retry policy or reducer.
Fresh exact-head Linux/Windows 001B+001C execution and artifact review are
required; the failed run is not reclassified as partial 001C success.
