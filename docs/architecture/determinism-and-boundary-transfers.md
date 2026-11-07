---
title: Determinism and boundary transfers
document-kind: contract
canonical-for: [native-determinism-and-hash-coverage]
status: Current
scope: Native scheduling and hash semantics for declared fixture inputs; explicitly excludes complete replay guarantees
keywords: [determinism, worker parity, state_hash, content_hash, explosion ordering, boundary transfers]
related-documents: [simulation-tick-and-threading.md, chunk-tile-and-buffer-model.md, ../reference/level-saves-and-replay.md, ../reference/validation-evidence.md]
last-reviewed: 2026-09-09
---

# Determinism and boundary transfers

## What does native worker parity guarantee?

**Current:** one-worker and multiworker PhasedInPlace runs use the same
coordinate/tick-derived phase, scan, random and merge semantics. Exact fixture
comparisons test that worker execution changes throughput without changing
those specified results. They do not establish equivalence with SerialInPlace,
the GDScript fallback, a different controller order or the coupled Rapier world.
Executed cases and platforms belong in the
[validation ledger](../reference/validation-evidence.md).

Source: [World `tick_phased`, `scan_rect`, `deterministic_random`, `merge_job_effects`](../../native/src/world.cpp),
[SchedulerGeometry](../../native/src/scheduler_geometry.cpp) and
[native fixtures](../../native/tests/test_world.cpp).

## Which ordering is part of simulation semantics?

- Global core-coordinate parity assigns four phases. First phase is
  `tick_index % 4`; a barrier completes every phase before the next.
- Rows scan bottom-up with deterministic alternating horizontal direction.
  Job effects merge in sorted core order, not completion order.
- `deterministic_random` hashes coordinates, tick and a rule stream identifier
  into a byte. It has no mutable global random generator or wall-clock input.
- Fixed secondary-interaction lanes are part of the compiled policy. They are
  exercised by exact fixtures; no global switch disables all such sampling.
- Ordinary bounded movement/reactions write directly inside exclusive domains.
  Their in-place traversal and pairwise arithmetic resolve local competition.
  Scheduler/storage edges do not create a general transfer queue.

See [geometry](chunk-tile-and-buffer-model.md) for domain enforcement and
[step order](simulation-tick-and-threading.md) for controller differences.
The atomic job distributor may assign different workers without changing these
ordering inputs. General completion-order perturbation coverage must be named
by an actual test; repeat/worker-count fixtures alone do not prove every schedule.

## How are explosions and future transfers ordered?

**Current:** `ExplosionCommand` stores signed centre coordinates, bounded
positive radius and byte collapse strength. Enqueue rejects invalid bounds or
a full preallocated queue or failed world by returning false. Accepted events commit in enqueue
order during `begin_tick`, before active work gathering. The blast removes its
core, writes Fire at an available centre and converts eligible Wall in the
two-cell shell into granular Stone (`state_b = 1`). Event-written cells carry
the current epoch and start ordinary material execution next successful tick.
If that attempt fails, the World is quarantined and cannot replay events; explicit
reset/replacement discards the failed state and any retained pending batch.

**Planned:** buffered transfers and generalized worker-produced fracture,
structural or long-range events. Their schema, canonical sort tuple and conflict
rules are not approved by the existing explosion queue. The reserved Buffered
backend cannot run. Accepted future transfers must have explicit conservation,
capacity and conflict semantics; worker timing is not a permissible resolver.

## Replay state coverage

**Current:** `World::state_hash` and `World::content_hash` use the FNV-style byte
mixer in `world.cpp::hash_byte` (seed `1469598103934665603`, multiplier
`1099511628211`). The name is not a versioned durable compatibility promise.

| Hash | Included | Intended comparison |
|---|---|---|
| `state_hash` | Attempted/completed tick identity, failed latch and epoch; requested/applied core coverage; selected geometry, sleep/temperature/backend and capacity settings; ordered pending explosions; sorted chunk coordinates; chunk/block activity and quiet counts; cell material/state/epoch and resolved temperature | Same declared native fixture and scheduling state |
| `content_hash` | Chunk size and ambient temperature; coordinates, material, compact state and temperature of non-empty/non-ambient cells | Settled content while time and scheduler bookkeeping advance |

`state_hash` includes normalized requested/applied interest core coverage (not
raw pixel bounds with identical coverage), granular policy version/settings and
pending pair deadlines. Mercury opportunities share the global tick modulo lane;
excluded ticks create no accumulated movement debt. See the
[pair policy](../systems/granular-interaction-policy.md).

The existing integer mixer uses native integer widths, including `size_t`. Windows
and Wasm hashes are therefore not a cross-platform byte-identity oracle; compare
worker counts within the declared platform and compare explicit observed values
across those platforms. `state_hash` **omits** liquid-surface-adhesion option,
transient obstacles/contact inputs, compiled rule identity and external
body/controller state. Worker count is intentionally omitted for parity tests.
A matching hash is therefore insufficient to prove that every future-affecting
input matches. Record these omitted inputs independently.

`content_hash` omits tick/epoch, activity, pending events and ordinary
empty/ambient storage. It intentionally cannot detect a change in scheduling
or pending behavior. Neither hash captures Rapier solver internals. Full replay
requirements and CYSD1 level-byte comparison belong in
[level saves versus replay](../reference/level-saves-and-replay.md).

## Coupled desktop determinism — 2026-11-06

**Current default (unchanged):** desktop native cells and main-thread Rapier are
independently paced. The worker prepares whichever body sample main last
published (`CyberSimulationWorker._worker_loop` → `prepare_rigid_body_coupling`).
The two timelines therefore race, and the [COUPLING-LOCKSTEP-001 measurement](../audits/2026-11-06-coupling-lockstep-feasibility.md)
found that every pair of repeated asynchronous runs diverged by that race, on
Windows and on WSL Linux.

**Current, opt-in only:** `CyberSimulationWorker.set_lockstep_coupling(true)`
is default off and refused after start. It makes native tick N wait, without
blocking main, for the body publication made after Rapier step N−1. A main-side
hold skips a physics frame until the newest snapshot consumed main's last
publication. The [fixture](../../godot/tests/test_coupling_lockstep.gd) and,
since the owner chose lockstep as an **opt-in mode** on 2026-11-06, the desktop
game launched with `--lockstep-coupling` use this pair. In the game the hold is
bounded: past 500 ms of consecutive held frames one counted stale step runs
instead of a freeze; a frame that skipped the decision (pause, reset, actor
install) restarts that bound. Main
follows the worker's reported applicability (`lockstep_fence_active`): labs and
MicroScenarios step asynchronously and are counted as unfenced, not held, as is
a step after a refused publication or with another body owner's result. The
default launch keeps asynchronous pacing; lockstep everywhere was not chosen.
[`test_coupling_lockstep_desktop.gd`](../../godot/tests/test_coupling_lockstep_desktop.gd)
checks the real host through play, pause and a world reset. Under the fixture's
fences, repeated runs were
bit-identical on each host, and 1 and 4 native workers gave identical results.
The comparison covered per-step lossless body bits, consumed samples, native
results and the per-tick `physical_state_hash`. The fixture's steps per second
stayed within 1.3% of the asynchronous control at nominal load. When native
work approached the 16.7 ms frame, lockstep slowed simulated time instead of
letting results go stale.
After an independent review, the reducer was repaired to compare the applied
snapshot serial and to validate every artifact and the complete registered
matrix before deciding, and the snapshot field now reports only the publication
consumed by a successfully completed tick. Re-reducing the retained traces
changed no decision.

**Not established:** cross-platform identity in production. Windows and Linux
lockstep runs diverged. Rapier transforms were still bit-equal when the packed
float32 rotation from `Transform2D.get_rotation()` (platform `atan2f`) differed
by one ulp. A fixture-only repack with a double `atan2` then matched Windows and
WSL Linux on every recorded field for 1,800 ticks on x86-64. The opt-in mode
now packs rotation that way in production code
(`CyberRapierPhysicsBridge.deterministic_rotation_packing`, on only in the mode).
Registered run `packed-001` (amendment_002) matched Windows and Linux and
equalled the earlier repack bit for bit. That shows the remaining gap can be
closed for this fixture; it does not guarantee it on other platforms. The [audit](../audits/2026-11-06-coupling-lockstep-feasibility.md) lists
the remaining sources. They include platform transcendental math in packing
and native rasterization, a Rapier build without `enhanced-determinism`, the
coverage of hashes and saves, and the omission of input capture.

The workbench host has a narrower Current fence: `_workbench_wait_sample` is
matched against `workbench_completed_sample`. Its pacing is recorded in the
[workbench audit](../audits/2026-11-04-workbench-boundary-and-pacing.md); its
repeatability has not been measured. **Planned:** input capture, a fenced or
tick-counted terrain collider installation for the opt-in mode, and complete
replay identity. Exact multiplayer lockstep across
platforms is not admitted.

## Which boundaries still limit the guarantee?

**Current:** phased exclusion retains activity and re-entry wakes newly included
blocks once without catch-up; SerialInPlace ignores the region. The
[interest contract](../systems/world-storage-and-interest-region.md) defines this
intentional mode difference. Declared region sequences must match for within-mode
worker/repeat comparisons; interchangeable backend semantics are not promised.

A failed native tick also lacks transactional rollback; time/events can change
before failure. The [failure contract](simulation-tick-and-threading.md)
describes the desktop/Web response. Deterministic failure reporting is not
proof that the pre-tick state survives intact.

**Approved:** exact comparison remains the engineering oracle for declared
fixtures. **Planned:** complete hash/replay versioning, complete future-state
coverage, selectable strict policy, general boundary-conflict schemas and the
remaining mirrored/shifted boundary matrix. Closed pure-Water conservation is
a separate invariant; generalized reaction source/sink accounting remains
Planned. Rationale: [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md),
[ADR-005](../decisions/ADR-005-water-model.md),
[ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md).
