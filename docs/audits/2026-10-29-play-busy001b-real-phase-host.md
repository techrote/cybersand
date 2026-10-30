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

No production worker observer is added. The fixture reuses the accepted
LIFE003 external stop-fence pattern: a bounded helper polls the existing
worker mutex until it observes the production `_running=false` state, then
records the native gate stop marker and releases the held phase. A test-only
Main subclass overrides `_close_physical_actors()`, calls the production
implementation first, and records that the tracked SetP Rapier bridge is
already shut down while the simulation worker is still running. Neither test
observer receives or calls the live World.

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

For shutdown, a bounded helper is started before `queue_free()`. The actual Main exit path first retires its accepted SetP session in
`_close_physical_actors()`. That session owns the live Rapier bridge and calls
`bridge.shutdown()`; only copied body state was ever supplied to the native
worker, so there is no cross-thread live-Rapier dependency to preserve. The
test-only Main subclass calls that production method and requires the tracked
bridge to be uninitialized while the worker's existing `_running` flag is
still true. The bounded helper then observes the later production
`_running=false` stop fence through the existing worker mutex while the copied
native gate still reports multiple jobs outstanding. It records the gate stop
marker and only then releases the native gate. All selected tasks must run
their real `scan_rect`, drain, and return from the production pool dispatch.
The real `Thread.wait_to_finish()` must complete before scene exit returns;
the retained SetP bridge must remain shut down. Main subsequently executes its
existing final `rapier_bridge.shutdown()` on the replacement bridge. Only
after join is the test permitted to inspect the worker-owned adapter, and
dropping retained owner references must destroy that adapter.

The expected sequence is therefore:

`dispatch start < first actual claim < accepted SetP/Rapier retirement
< production worker-stop request < manual release < all selected tasks drained
< pool dispatch return < worker joined < final Main bridge shutdown
< retained native adapter destruction`.

This ordering intentionally matches current ownership: the Main-owned SetP
Rapier graph can retire before worker join because the worker holds only copied
body packets; the worker-owned World cannot be destroyed until its thread has
joined.

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

At initial publication this protocol/source was unexecuted. The first corrected-
ownership exact-head attempt, run 40972930181 on source
`90e350b6e9889d476c0a480bbc5a8ee2aefa6204`, built the special Windows DLL
successfully but the Windows execution job stopped before Rapier/Godot setup:
`runtime.sha256` had been created from the build job with a path prefixed by
`build/play-busy001b/windows-build/`, while the artifact was intentionally
restored under `build/play-busy001b/windows/`. `sha256sum --check` therefore
reported the old path as missing. This is a provenance-harness path defect, not
a runtime/test pass or engine failure. The failed run and its six-file evidence
artifact remain retained; no execution result is transferred. The successor
writes the seal from inside the artifact root so it is location-independent.

No Windows/Linux host result is assumed in advance for the successor. Any
compile, import, test, deadline or readback failure is retained and is a blocker
for this candidate.

## Explicit non-claims

Even a two-platform pass here does not measure rendered FPS, physical controller
focus, sustained play performance or human feel. It does not qualify unrelated
solver laws/defaults or authorize runtime publication. It does not close
#263/#269/#270 on its own. The source-sensitive render-copy/publication work in
#290/#295/#298 is not rebased, edited, armed or published by this branch.


## Ready-matrix provenance refusal and test-only source-patch correction — 2026-10-30

After #299 merged, this branch consumed accepted main `b768fc8901e9a400e1075923ecf5b9be6e0ec036`
and transitioned ready at `dd3205685d77d85a739996469476a7c675c9d7fa`.
The ordinary Windows regression shards in run
[40986491203](https://github.com/techrote/cybersand/actions/runs/40986491203)
correctly **FAILED before executing any Godot case** with
`Runtime provenance must cover every current native source/header exactly`.
That is a real source-sensitive runtime gate, not a gameplay failure.

Cause: the first 001B integration placed dormant `#if CYBERSAND_PLAY_BUSY_TEST_HOOK`
code in `native/src/world.cpp`, changed `godot/native_extension/register_types.cpp`,
and added a header under `godot/native_extension`. Those paths are all in the
ordinary retained-runtime provenance domain. Even though normal release builds
did not define the test macro, changing those source bytes legitimately made the
accepted main DLL manifest stale. Publishing a competing PLAY runtime while the
separate #290/#295/#298/#301 render-copy publication stack is active would violate
the intended source/runtime ownership separation.

The successor therefore restores production `world.cpp` and
`register_types.cpp` **byte-for-byte to current main** and removes the test
adapter from `godot/native_extension`. The adapter lives only under
`native/tests/support`. The dedicated PLAY workflow records the exact Git
source inputs, verifies and applies versioned
`tools/ci/play_busy001b_instrumentation.patch` to those two production files
in the ephemeral Actions checkout, records the resulting instrumented hashes,
builds the special runtime with `CYBERSAND_PLAY_BUSY_TEST_HOOK=1`, then restores
both files and requires a clean diff before running Godot. The receipt retains
the patch, baseline-input and instrumented-source sidecar hashes.

This changes the evidence description from “dormant hook committed in production
build inputs” to **“exact production source plus a versioned, test-only temporary
instrumentation patch”**. The actual selected dispatch/task callbacks, Main host,
production `stop_worker()` fence and ownership oracle are unchanged. The
instrumented runtime remains qualification-only and is never written to LFS or
treated as a release artifact.

The original c0ecc13 Windows/Linux PASS and the dd320 Windows provenance failures
remain historical. Fresh scoped 001B execution is required after this correction;
then the branch must return to ready-for-review and pass the ordinary source-matched
Docs/Native/Godot gates using unchanged accepted main runtime provenance.


## Special-runtime fixture discovery boundary — 2026-10-30

The first provenance-safe draft still named the actual-host script
`test_play_busy001_real_phase_shutdown.gd`. Repository-wide Godot discovery
intentionally glob-matches every `godot/tests/test_*.gd`; therefore a future
ready run would execute that fixture against the **ordinary retained runtime**,
where `CyberPlayBusyTestGate` must not exist. That would be an invalid
qualification premise, not a native-host regression.

The script is renamed to `play_busy001_real_phase_shutdown.gd`. Its bytes and
assertions are unchanged. Only the dedicated PLAY-BUSY workflow invokes it
explicitly after building the source-pinned instrumented runtime. Standard
Godot discovery remains complete for normal-runtime cases without silently
skipping or xfail-ing an ordinary test: this file is a scoped apparatus input,
not an ordinary-runtime regression.
