---
title: ADR-003 — Godot bridge and immutable snapshots
document-kind: decision
canonical-for: [decision-immutable-godot-bridge]
status: Current
scope: Accepted immutable publication boundary and remaining generalized gameplay bridge work
keywords: [ADR, immutable snapshot, RenderBridge, GameplayBridge, render race, backpressure]
related-documents: [../architecture/rendering-and-gameplay-bridges.md, ../architecture/data-ownership-and-lifetimes.md, ADR-001-native-simulation-core.md]
last-reviewed: 2026-09-08
---

# ADR-003: Godot bridge and immutable snapshots

## Decision and implementation status

**Approved:** Godot receives immutable rendering/results and sends data-only
commands through adapters. Native workers never access live Godot objects or
expose mutable cellular storage. **Current:** native snapshot exchange/C leases,
copied Godot RG8 packets and desktop publication acknowledgement implement the
render boundary. **Planned:** a generalized bounded GameplayBridge.

The [bridge behavior contract](../architecture/rendering-and-gameplay-bridges.md)
owns publication outcomes and GPU-upload scope;
[data ownership](../architecture/data-ownership-and-lifetimes.md) owns slot,
lease and Godot payload retirement. Source:
[RenderSnapshotExchange](../../native/src/render_snapshot.cpp),
[desktop generation copy](../../godot/scripts/simulation_worker.gd) and
[consumer validation](../../godot/scripts/main.gd).

## Why require immutable copies?

Simulation and presentation progress at different rates and have different
object lifetimes. Borrowing mutable native storage makes consumer delay a race
or forces rendering to lock authoritative work. Independently owned immutable
publication permits delayed/repeated consumption without blocking native rules.

The historical render-patch race showed why a writable wrapper described as
immutable is insufficient: producer buffer reuse can invalidate payload bytes.
The Current desktop implementation deep-copies changed pending generations and
validates complete packets before image construction. The
[handoff regression](../../godot/tests/test_render_patch_handoff_regression.gd)
protects this boundary; historical results remain in the
[evidence ledger](../reference/validation-evidence.md).

## Consequences and alternatives

The choice enables concurrent desktop rendering, standalone data fixtures and
explicit pressure diagnostics. It costs copying/encoding, retained publication
storage, acknowledgement and a consumer-lag policy. Native publication pressure
is now non-blocking and retains dirty state; that decision does not define
future command/result queue overflow.

**Rejected:** mutable native render views, locking World during rendering and
full-state snapshots as the ordinary changed-tick path. Explicit bounded full
refresh remains Current for recovery; Godot's full GPU texture update also
remains Current despite dirty CPU patching.

Main-thread simulation is Rejected as the production-scale desktop target.
**Current Web exception:** synchronous native callbacks wait on the main thread;
separate publication cadence does not eliminate that wait. Fully asynchronous
Web ownership is **Deferred** under current scope.

## What must later changes preserve?

Retained payloads must stay unchanged, unsuccessful publication must retain
dirty state, malformed data must not be partially accepted and acknowledgement
must follow successful consumption. No optimization may substitute a mutable
fallback view. New queues require explicit schemas, capacities and retirement
rules. GPU subregion updates require their own implementation and validation.
These are obligations; only dated entries in the validation ledger establish
which lifetime, pressure and platform fixtures actually ran.

## Failed-tick publication decision

**Current/Approved for issue #1:** failure status may be published, but partial
tick cells, character and body results may not be reported as successful.
Retain the last valid immutable display. Desktop receives asynchronous status;
Web gates directly on its synchronous owner. [ADR-010](ADR-010-failed-tick-quarantine.md)
defines reset/replacement, distinct from snapshot pressure recovery.
