---
title: PLAY-ASYNC-001 implementation handoff and independent architecture challenge
status: Approved design
document-kind: guide
scope: Independent #265/#266 work boundaries, technical acceptance gates, adversarial review and open baseline evidence
canonical-for: [play-async-001-implementation-handoff]
keywords: [PLAY-ASYNC-001, #265, #266, thread-safety, handoff, independent review]
last-reviewed: 2026-10-26
related-documents: [../decisions/ADR-015-player-playground-asynchronous-owner.md, ../architecture/player-playground-asynchronous-contract.md, ../audits/2026-10-26-play-async-001-baseline.md, ../architecture/simulation-tick-and-threading.md, local-build-and-validation.md]
---

# PLAY-ASYNC-001: parallel implementation handoff and critical review

## Source checkpoint, scope and no-go boundaries

Start from current `main`, not from this planning branch's old input without
rebase. Architecture inspection source:
`9e53a5b1b501e0667037b8502d3c1d15089211f5`. Mandatory:
[ADR-015](../decisions/ADR-015-player-playground-asynchronous-owner.md),
[exact protocol](../architecture/player-playground-asynchronous-contract.md)
and [baseline limits](../audits/2026-10-26-play-async-001-baseline.md).
Use isolated branches/worktrees. Scope: five mechanical Player Playground
actors on Linux/Windows only. Leave native material laws, unrelated LCB
changes, ordinary desktop sandbox, physical evaluation lab schedule,
Web and two swarms unchanged. The swarms are #271, **not blockers** for the
mechanical migration. Do not bypass normal native/Godot tests or provenance.

## Agent A — issue #265, asynchronous player owner

Own a new bounded non-Node player World owner, immutable packet/message
values, worker lifecycle/60-Hz pacing, native World exclusive handoff,
initial/reset layout, terrain revision barrier and publication ACK. Call
existing native coupling/effects/usable methods; do **not** build a generic
threading framework or port Rapier/scene objects to the Thread.

Implement typed/refused capacity bounds and event accounting directly from
the [contract](../architecture/player-playground-asynchronous-contract.md#concrete-owner-protocol-and-bounded-queues).
No worker read/write to main Nodes; no mutex held over native calls, GPU
uploads, collider installation, scene callbacks or thread joins. Keep current
main-thread physical Session and actor API unchanged; integration of full
playable controls is #267. #265 may exercise a thin test-only main-thread
harness with synthetic copied poses and one native World.

Define injected immutable `requested_workers` and `resolved_workers`
parameters for worker-side `diagnostic_reset`, initially explicit 1 in
test fixtures **only**. The production resolver belongs to #266; no
hard-coded one-worker migration default. At Stage/Ready:
1. Build seeded World, publish complete initial terrain packet; require exact
   main ACK before first physical step.
2. Prove copy/ownership, successful tick, new immutable publication, skipped
   packet/ACK recovery, FIFO events and lossless receipts.
3. Inject full eight-frame + eight-effect/usable pressure, stale pose and
   epoch-cancel race; verify typed refusals and no late effects.
4. Inject failed native tick, replacement while pending terrain and stop
   while an old packet is retained. Never join a running Thread on main.

Send Agent B the **schema** and native reset entry points, not a private
mailbox implementation to depend on.

## Agent B — issue #266, multicore policy and evidence

Independently implement or factor a **per-World count resolver**, without
moving any World or scene ownership:
`resolve(requested: int, logical_processors: int, platform: String)
  -> {admitted, requested, resolved, reason}`.
`requested=0` uses existing
`CyberNativeCellWorld.auto_worker_threads(logical_processors)` policy
(`2/4/6` thresholds); positive explicit counts remain bounded/clamped
according to the existing native adapter, with Web out of scope. Do not
silently pass `0` to `diagnostic_reset`: that method defaults to one
and explicitly rejects zero.

Expose true readback from `get_worker_threads()`, native scheduled jobs,
parallel phase execution and requested/actual difference. Test 1 vs Auto
and available 2/4/6 on an *identical constructed World, seed, fixture,
pose/event trace and requested camera/LOD options*; also test one-core
and low-core negative admission, without changing the native scheduler's
policy or backend. Record platform, source/runner/CPU identity, actual worker
threads, per-tick timing distributions and deterministic final native state
hash; 2/4/6 eligibility does not guarantee speedup. Standalone harness
can use existing `CyberWorkerBenchmark` only as a supplementary reference;
measure the **actual player course** before claiming its performance.

Own no `CyberPlayerCellOwner` mailbox or UI files; provide the small
resolution helper/counter contract as a separate PR to minimize conflicts.
Before #270 chooses the default, resolve Auto on all eligible desktop CPUs,
including the existing low-core policy rather than substituting
`min(cores, 2)` or disabling multithreading silently.

## Join, acceptance and downstream boundaries

**#265 and #266 are specified to begin in parallel** after this architecture
PR's review/merge. #267 integrates the main-thread physical Session,
terrain/lease/equipment/recoil receipts and both clocks. #268 separately
integrates render snapshot consumption/camera, timing and visible diagnostics.
#269 verifies lifecycle, failures and observed overload. #270 owns Windows/
Linux promotion, manual human feel and source-matched mandatory CI.
If a private prototype diverges from packet identity, queue limits or
terrain/physics ordering, revise this canonical contract through review;
do not let independent agents silently invent incompatible semantics.

The current #264 performance admission gap is explicit: baseline native
and Windows/Linux current-source functional tests exist, but **new
interactive frame-pacing measurements do not**; see evidence ledger.
A docs-only architectural PR cannot be represented as runtime acceptance.

## Independent adversarial architecture review — 2026-10-26

This is a **separate skeptical reasoning pass**, not a second agent's
independent executed test or GitHub approval. Findings and dispositions:

| Failure attempt | Architectural correction or mandatory verification |
|---|---|
| Main synchronously joins while native/Rapier hangs (#232–#234) | Bounded cooperative retire/ACK. Join only an already-exited worker; quarantine uninterruptible native ownership and preserve host watchdog. No unsafe free/kill |
| New World uses same numeric hard revision, old ACK enables Rapier | Compare full `run_id + epoch + terrain_revision`; require fresh initial terrain even when numbers coincide |
| Terrain snapshot overwrites in-progress collider rebuild | One outstanding terrain packet and pending-chunk drain ACK; worker stops new ticks until installed |
| Button tap lost when latest frame is coalesced | Main Session retains ordered quick-tap edges; event-bearing `FrameEvents` is FIFO and never coalesced |
| Canceled request already popped from queue edits new World | Repeat actor generation/epoch check at point of native effect application; consumed old edits are not replayed/undone |
| Latest render snapshot overwrites unconsumed equipment result | Independent bounded receipt ledger/ACK, backpressure and immutable render delta accumulation |
| 4LY actor receives two physical advances or no Rapier integration | Strict one `Session.advance` → one `bridge.step` → one `complete_step` per ready physical tick, with step counter verification |
| Worker owns a scene object and calls PhysicsServer from background | Thread owns only adapter/value processing; all live Rapier/physics and colliders stay main-bound |
| World tick changes terrain after main's already-started Rapier step | Initial strict fence; dynamic fence before *next* step after barrier becomes visible, bounded one already-in-flight step recorded as skew—not claimed lockstep |
| UI shows 60 FPS but cell owner runs 15 Hz / overload hidden | Separate actual tick Hz, worker overrun, snapshot wall age, sample age, native jobs and main frame p95/p99 counters |
| Synchronous fixture accidentally becomes production default | Explicit diagnostics-only opt-in; fail if ordinary desktop selection does not route to Auto+async after #270 |

**Residual risks requiring running proof:** whether GDExtension adapter and
native `diagnostic_reset` are safe after handoff on both Godot platforms;
the native/Rapier re-entrancy stress path under concurrent threads;
event-frame capacity pressure vs. equipment inventory and full-receipt
accounting; hard-terrain changes arriving during physical integration;
render-ACK and full-resync memory peaks; resource quarantine if a truly
blocked native tick never returns. These are concrete #265/#267/#269
qualification cases, not permission to relax protocol invariants.
