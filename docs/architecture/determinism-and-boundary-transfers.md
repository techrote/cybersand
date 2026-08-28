---
title: Determinism and boundary transfers
status: Current
scope: Current strict deterministic behavior, phased ownership invariants, gameplay approximation boundary, buffered transfers, deferred events, replay state, random choices, and overflow
keywords: [determinism, phased ownership, phase order, boundary transfer, deferred event, replay hash, worker completion]
related-documents: [simulation-tick-and-threading.md, chunk-tile-and-buffer-model.md, ../operations/testing-validation-and-replay.md]
last-reviewed: 2026-08-27
implementation-state: Native phased ownership, deterministic random streams, job-local effects, sorted merge, worker-count replay, and a bounded tick-boundary explosion queue are Current; buffered transfers and generalized worker-produced deferred events remain unimplemented.
---

# Determinism and boundary transfers

## At a glance

- Purpose: ensure multicore execution changes performance, not world outcomes.
- **Current**: native World has deterministic serial and four-phase in-place paths.
- **Current**: phase membership, phase rotation, row scan, random streams, and job-effect merge are coordinate/tick derived.
- **Current**: phased jobs directly mutate only geometrically exclusive write domains.
- **Current**: ordinary radius-one/two movement and reactions do not use transfer records.
- **Current**: state_hash includes scheduling-relevant cell/activity metadata; content_hash isolates settled content.
- **Current**: queued explosions are hashed in enqueue order, commit before work gathering, and match across worker counts.
- **Planned**: buffered transfers and generalized worker-produced deferred events require canonical schemas/order.
- **Approved design**: strict replay remains a validation mode; gameplay fidelity may sample non-critical work without making thread timing an ownership input.

## Search anchors

cross-tile ordering, cross-chunk seam, deterministic replay, state hash coverage, transfer conflict, random direction, single versus multithread

## Current determinism evidence

native/src/world.cpp currently:

- gathers active chunk coordinates;
- sorts those coordinates before scanning;
- uses a tick-dependent deterministic_direction helper;
- assigns 64×64 cores to four coordinate-parity phases;
- executes each phase through a persistent pool when its job count reaches the configured threshold;
- records job-local dirty/activity/non-empty effects and merges them by sorted core index after the barrier;
- derives every rule random byte from world coordinates, tick, and stream ID;
- hashes queued explosion coordinates/radius/strength in enqueue order and commits them at the next tick boundary;
- provides World::state_hash and World::content_hash.

native/tests/test_world.cpp includes repeat-run determinism, core/chunk crossings,
Water, complete-material, and explosion/collapse one/four-worker exact replay,
geometry non-overlap, and TSan-clean worker execution.

Limitations:

- serial and phased traversal are separate semantics, so only behavioral totals—not byte-identical states—are compared across those backends;
- no deliberate completion-delay injection exists beyond natural scheduling and TSan;
- the every-direction/material mirrored boundary matrix is incomplete;
- only the external bounded ExplosionCommand event exists; worker-produced fracture/event schemas and buffered transfers do not;
- state/content hash compatibility is not versioned for files or network replay.

## Strict-mode deterministic requirements

For identical initial state, configuration, material definitions, command stream, interest-region transitions, and tick count:

- job membership is identical;
- each phased job has the same ownership, phase, scan semantics, and inputs;
- buffered transfer or deferred-event production is identical where applicable;
- merge and conflict outcomes are identical where applicable;
- committed authoritative state is identical;
- wake and sleep decisions are identical;
- replay hashes are identical;
- worker count and completion order do not change these results.

Wall-clock timings and per-worker utilization are not authoritative and may differ.

## Gameplay approximation boundary

Exact native replay remains **Current** and should not be weakened accidentally.
It is no longer a universal requirement for every production fidelity policy.
Gameplay mode may use explicit temporal cadence, sparse broad probes, lower-rate
slow rules, and lower-resolution optional/distant fields as described by
[ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md).

Approximation does not permit:

- worker completion order to claim a cell or resolve a conflict;
- data races or concurrent writes outside the selected ownership model;
- silent loss at a conserved or closed boundary;
- cells passing through a known solid occupancy mask;
- hidden capacity overflow;
- systematic scan artifacts such as alternating empty rows.

Approximation policies, seeds/rates, and fidelity tier must be observable. A
strict run must remain available for regression localization even when gameplay
acceptance allows statistically or visually equivalent outcomes.

## Boundary ownership and deferred effects

Status: **Current** for bounded phased effects and external explosion commands;
**Planned** for buffered transfers and generalized worker-produced/structural events.

For the primary phased backend, an activity or storage boundary is not automatically a transfer boundary. A local operation executes directly only when all touched cells fall inside one job's current owned write domain. Otherwise it waits for an eligible phase or follows a future explicitly approved boundary policy.

For the retained buffered backend, a transfer represents an effect outside an isolated output region. Its contract must support:

- tile-edge and chunk-edge effects;
- conserved quantities such as liquid mass;
- material movement or state change where applicable;
- deterministic identification of origin and destination;
- validation against bounded capacity;
- canonical merge and conflict resolution.

Current explosion commands have signed centre coordinates, bounded positive radius,
and byte collapse strength. Queue capacity and maximum radius are explicit.
They commit in enqueue order before active work is gathered. The core is removed,
the centre becomes Fire when its chunk exists, and eligible Wall in a two-cell
shell becomes `state_b=1` granular Stone. Event-written cells carry the current
update epoch and first run material rules on the following tick.

Generalized worker-produced fracture, impulse, and structural events remain
**Planned**; their fields, canonical sort order, and conflict rules are not
inferred from the Current explosion queue.

## Production sequence

1. Increment the tick/epoch and reset per-tick change observations.
2. Commit Current queued external explosions in enqueue order and gather the resulting active work.
3. For the phased backend, execute phases 0–3 with non-overlapping ownership and a barrier after each.
4. For the buffered backend, execute isolated outputs and merge their transfers canonically when implemented.
5. Resolve future worker-produced long-range/structural events canonically when implemented.
6. Finalize authoritative activity, sleep, dirty, conservation, and allocation observations.
7. Publish immutable native render data through a separately invoked post-tick snapshot exchange.

## Ordering rules

### Current phased guarantees

- Ordering is derived only from authoritative tick inputs, backend configuration, coordinates, rule semantics, and transfer/event contents.
- Phased backend order includes phase and within-job scan order.
- Worker identity, queue position after dispatch, completion timestamp, memory address, unordered-container iteration, and OS scheduling are not ordering inputs.
- The same rule applies at a worker-tile boundary and a storage-chunk boundary.
- Any pseudo-random choice is derived deterministically from stable authoritative inputs.

### Current ordering and remaining ambiguity

Phase is `(core_x parity, core_y parity)` and the first phase rotates by tick.
Rows scan bottom-up and horizontal order alternates deterministically. JobEffects
merge in sorted core order. Current external explosions retain enqueue order.
Buffered transfer and generalized worker-produced event sort tuples remain
**Ambiguous** because those systems are absent.

## Conflict resolution

Potential conflicts include:

- several sources targeting one destination;
- two conserved flows competing for limited destination capacity;
- a gameplay command and material rule affecting related state;
- phase/material conversion coinciding with movement;
- a wake or dirty observation arriving through multiple paths.

The approved architecture requires one deterministic policy for each conflict family. No priority table or numerical policy is currently approved, so implementations must not infer one from worker timing or current GDScript behavior.

## Conservation

For a closed liquid fixture:

- total fixed-point liquid mass before and after a tick must match;
- pairwise phased transfers or buffered edge transfers contribute exactly once;
- rejected or clamped flux cannot disappear;
- conversion between material-grid occupancy and liquid state must conserve mass;
- serialization and interest-region sleep/wake cannot alter total mass.

Current pure Water uses unsigned 8-bit mass, 255 capacity, and exact bounded
integer transfer. Generalized reaction source/sink accounting remains **Planned**.

## Replay state coverage

An authoritative replay hash must include every value that can alter future authoritative state, including as applicable:

- committed material and optional-field state;
- tick number;
- material/rule definition identity;
- configuration values that affect simulation;
- activity, wake, and sleep state if they affect whether work runs;
- deterministic random state or derivation inputs;
- pending authoritative commands or deferred transfers if they survive a tick boundary.

Current `state_hash` includes active/core/chunk/event capacities, the pending
explosion queue, maximum explosion radius, and every command field in enqueue
order. `content_hash` intentionally
excludes pending events and scheduling metadata because it compares committed
material/optional-field content only.

Snapshot serials, wall-clock metrics, render-only dithering, and worker utilization should not affect authoritative hashes.

The exact hash algorithm and compatibility/version policy are **Planned**.

## Overflow and determinism

Capacity pressure is part of deterministic behavior:

- no transfer or deferred event may be dropped silently;
- no worker may allocate an unbounded fallback;
- every overflow is asserted or reported with required and available capacity;
- any approved recovery/reconfiguration occurs at a deterministic safe boundary;
- replay records enough configuration/transition information to reproduce the outcome.

Current external explosion enqueue rejects invalid radius/coordinate bounds and
returns false when its preallocated queue is full; it never drops an accepted
event. General tick/event overflow recovery remains **Planned**.

## Required validation

- same replay under one worker and multiple worker counts;
- deliberately permuted worker completion timing with identical hash;
- every direction across 32×32 activity boundaries;
- every direction across 64×64 scheduling and 128×128 storage boundaries;
- mechanical proof/checks that same-phase write domains do not overlap;
- corner crossings;
- liquid conservation at edges;
- wake propagation across edges;
- buffer capacity at, below, and beyond configured reservations;
- hash-sensitivity tests proving scheduling-relevant state is covered.

## Related decisions

- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-005](../decisions/ADR-005-water-model.md)
- [Testing and replay](../operations/testing-validation-and-replay.md)
- [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md)
