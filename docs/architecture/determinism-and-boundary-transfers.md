---
title: Determinism and boundary transfers
document-kind: contract
canonical-for: [native-determinism-and-hash-coverage]
status: Current
scope: Native scheduling and hash semantics for declared fixture inputs; explicitly excludes complete replay guarantees
keywords: [determinism, worker parity, state_hash, content_hash, explosion ordering, boundary transfers]
related-documents: [simulation-tick-and-threading.md, chunk-tile-and-buffer-model.md, ../reference/level-saves-and-replay.md, ../reference/validation-evidence.md]
last-reviewed: 2026-09-08
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
a full preallocated queue by returning false. Accepted events commit in enqueue
order during `begin_tick`, before active work gathering. The blast removes its
core, writes Fire at an available centre and converts eligible Wall in the
two-cell shell into granular Stone (`state_b = 1`). Event-written cells carry
the current epoch and start ordinary material execution next tick.

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
| `state_hash` | Tick/epoch; selected geometry, sleep/temperature/backend and capacity settings; ordered pending explosions; sorted chunk coordinates; chunk/block activity and quiet counts; cell material/state/epoch and resolved temperature | Same declared native fixture and scheduling state |
| `content_hash` | Chunk size and ambient temperature; coordinates, material, compact state and temperature of non-empty/non-ambient cells | Settled content while time and scheduler bookkeeping advance |

`state_hash` **omits** simulation region, liquid-surface-adhesion option,
transient obstacles/contact inputs, compiled rule identity and external
body/controller state. Worker count is intentionally omitted for parity tests.
A matching hash is therefore insufficient to prove that every future-affecting
input matches. Record these omitted inputs independently.

`content_hash` omits tick/epoch, activity, pending events and ordinary
empty/ambient storage. It intentionally cannot detect a change in scheduling
or pending behavior. Neither hash captures Rapier solver internals. Full replay
requirements and CYSD1 level-byte comparison belong in
[level saves versus replay](../reference/level-saves-and-replay.md).

## Which boundaries still limit the guarantee?

**Current known defect:** phased region exclusion can age movable blocks into
sleep without waking them when the region returns; SerialInPlace ignores the
region. See the [interest contract and probe](../systems/world-storage-and-interest-region.md).
This behavior must be included in fixture inputs and cannot be hidden by a
claim of interchangeable backend semantics.

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
