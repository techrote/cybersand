---
title: PLAY-BUSY-001B real World-phase/Main shutdown qualification
status: Planned
document-kind: audit
canonical-for: []
last-reviewed: 2026-10-29
scope: Source-matched test-runtime qualification of real phase jobs and production host shutdown; no release promotion
related-documents: [2026-10-29-play-busy001a-pool-apparatus.md, ../architecture/simulation-tick-and-threading.md, ../architecture/data-ownership-and-lifetimes.md, ../systems/player-control-playground.md, ../operations/github-development-and-release.md]
---

# PLAY-BUSY-001B — real phased World host gate

## Why this successor exists

PLAY-BUSY-001A proved that the literal production `PersistentWorkerPool` can
hold multiple actually claimed callbacks and drain/join correctly under a
bounded test gate. It deliberately did **not** execute `World::simulation_tick`,
the desktop Main host, the production `CyberSimulationWorker.stop_worker()`
fence, or Main-owned Rapier.

001B moves the controlled hold into the actual `World::tick_phased()` pool
dispatch. It is a qualification branch, not a production feature. The hook is
compiled only when `CYBERSAND_PLAY_BUSY_TEST_HOOK=1`; ordinary builds do not
register the test gate or execute its worker-task calls. Because the authoritative
native source bytes nevertheless change, existing published native runtimes are
not reused as source-matched evidence for this branch.

## Ownership and synchronization boundary

The pool callback still performs the ordinary real scheduling-core
`scan_rect(...)`. Immediately after the real pool claims a task, a pure-C++
test gate may hold that callback. The gate:

- contains no Godot types and no `World*`;
- uses fixed storage for at most 4096 phase tasks and 64 observed worker
  identities;
- selects only a complete pool dispatch whose `begin_dispatch` occurs after
  arming, preventing an arm from retroactively capturing a partly claimed
  phase;
- records tick, phase, expected task count, actual arrivals, distinct threads,
  stop/release/drain/dispatch-return sequence numbers and timeout disposition;
- allows at most a 15-second bound and treats automatic release as negative
  evidence.

A separate test-only `CyberPlayBusyTestGate` GDExtension object exposes copied
status, arm, stop-marker and release operations. Main never receives or calls
the live native World while its worker owns it. Native pool callbacks call no
Godot APIs.

The GDScript worker gains one empty-by-default qualification observer. When
installed by the test it receives `requested` immediately after the real
`_running=false` plus request-revision fence and `joined` immediately after
`Thread.wait_to_finish()`. The ordinary path has an invalid Callable and no
observer action. The observer never receives the World.

## Actual-host protocol

The fixture uses the existing `main.tscn`, authored Player Playground course,
Jet Barrel SetP construction, exclusive `CyberSimulationWorker` and Main-owned
Rapier. It first requires an ordinary completed parallel native phase.

Then it arms the gate and requires at least two distinct real phase callbacks
to remain blocked before any selected task completes. While that exact dispatch
is held, the fixture requires all of the following without releasing the gate:

1. repeated actual Main `_process` callbacks;
2. actual Main `_physics_process` callbacks and Rapier manual steps;
3. a real Viewport D press/release reaching the existing input/session route;
4. the exact last committed immutable snapshot serial/tick/World generation to
   remain unchanged, proving no partial native publication.

For shutdown, a bounded helper is started before `queue_free()`. The actual
`stop_worker()` observer records the `requested` fence while the copied gate
still reports multiple jobs outstanding and Rapier remains initialized. Only
then may the helper release the native gate. All selected tasks must run their
real `scan_rect`, drain, and return from the production pool dispatch.
`wait_to_finish()` must then produce the `joined` observation while Rapier is
still initialized. Main subsequently executes its existing
`rapier_bridge.shutdown()`; the retained bridge must report uninitialized.
Only after join is the test permitted to inspect the worker-owned adapter, and
dropping retained owner references must destroy that adapter.

The expected sequence is therefore:

`dispatch start < first actual claim < production stop request < manual release
< all selected tasks drained < pool dispatch return < worker joined < Rapier
shutdown < retained native adapter destruction`.

The retained worker reference deliberately delays the last object destruction
so premature destruction is observable; it does not change the production stop
or Rapier shutdown calls.

## Exact-source hosted execution

`.github/workflows/play-busy001b-host.yml` is read-only and GitHub-hosted.
It builds special source-matched Linux and Windows GDExtension binaries from the
exact commit using the repository's pinned godot-cpp/toolchains and only adds
the test macro through compiler wrappers. It materializes the already pinned
Rapier runtime for each platform, verifies Godot 4.7 archive identity, runs only
this real-host fixture, reduces its machine-readable output, and retains source,
compiler, runtime, Rapier and raw-log hashes.

The dedicated runtime is **not published** to LFS or reused as a release
runtime. The branch must also retain ordinary project validation separately;
draft-skipped ordinary workflows are not passes.

At publication time this protocol/source is **unexecuted**. No Windows/Linux
host result is assumed in advance. Any compile, import, test, deadline or
readback failure is retained and is a blocker for this candidate.

## Explicit non-claims

Even a two-platform pass here does not measure rendered FPS, physical controller
focus, sustained play performance or human feel. It does not qualify unrelated
solver laws/defaults or authorize runtime publication. It does not close
#263/#269/#270 on its own. The source-sensitive render-copy/publication work in
#290/#295/#298 is not rebased, edited, armed or published by this branch.
