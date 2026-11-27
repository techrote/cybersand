---
title: ADR-015 — Opt-in persistent authored areas
document-kind: decision
status: Current
canonical-for: [persistent-authored-areas-architecture-decision]
scope: GEN-006 #591 first milestone; bounded whole-area native continuation and game-time debt
keywords: [GEN-006, whole-world checkpoint, persistent areas, game time, ownership]
related-documents: [../systems/persistent-authored-areas.md, ../reference/level-saves-and-replay.md]
last-reviewed: 2026-11-21
---

# ADR-015 — Opt-in persistent authored areas

## Subsequent extension

[ADR-016](ADR-016-persistent-area-native-residency.md) extends the inactive storage and
exclusive handoff decision with real HOT native ownership, bounded WARM caching,
asynchronous durable publication and predictive preparation. The native domain,
completed-time accounting, original-source identity and unsupported dependency
refusals below remain authoritative. The synchronous baseline remains available
with caching disabled. This historical decision does not imply all inactive areas
in the successor exist only as checkpoints.

## Context

The owner authorised implementation of the three-area milestone in
[#591](https://github.com/techrote/cybersand/issues/591), while retaining Draft/HOLD
and the wider [#194](https://github.com/techrote/cybersand/issues/194) programme.
Current CYPS continuation can retain the required native dynamic domain; a
material-only save cannot. Existing host and Rapier graphs are not CYPS state.

## Decision

Keep one active finite native Workbench and at most one private prepared target.
Inactive areas use validated, immutable whole-area checkpoints and one manifest
transaction for state and game-time frontiers. Reuse the current prepared-World
adoption and Main acknowledgement. Use editor/camera travel, explicit unsupported
dependency refusal, bounded actual native stepping and visible unpaid debt.
Keep authoring source provenance separate from edited starting-map metadata and
from the native continuation receipt. Add an opt-in scene and launcher entry;
ordinary production defaults remain unchanged.

## Alternatives examined

| Donor or alternative | Decision and reason |
| --- | --- |
| #486 / #502 independent shard Worlds and streaming controller | Reuse the ownership lesson, not its separate-world IPC topology or a claim of shared-World eviction. |
| #512 conservative static checkpoint/eviction | Its pinned dynamic domain is unsuitable for a fire/Water milestone; do not reduce the demonstration to static materials. |
| #523 whole-World private staging/native continuation | Reuse bounded staging and full-state restore; do not extrapolate it to arbitrary selective eviction. |
| #518 edit journal | Research primitive; no integrated native replay or crash-safe host ownership contract to substitute for checkpoints. |
| #513 Windows adapter response repairs | Retain response/failure evidence; no need to reintroduce an external process adapter for an in-process native owner. |
| #459 / #422 state-loss investigations | Dirty state is not persisted state; material-only restoration loses native quantities, clocks and events. |
| #514 stale ACK evidence | Use nonreusable operation/incarnation identity and fresh fences; hash/tick coincidence cannot grant new authority. |
| Static/idle coarse fast-forward | Refuse without a future-rest certificate; real deadline and epoch negative fixtures invalidate the proposed shortcut. |
| General moving-chunk residency | Outside this milestone and introduces dependency/recipe reconciliation that the current tests do not prove. |

## Consequences

The first slice has bounded, inspectable durability and progression but explicit
area transitions, debt and unsupported actor/solver domains. Checkpoint I/O and
full-state verification add latency and memory copies; these costs are measured
rather than hidden. The architecture leaves room for later residency selection
and narrowly qualified traveller transfer without claiming either capability.
No merge, Ready conversion or production adoption follows from this decision.
