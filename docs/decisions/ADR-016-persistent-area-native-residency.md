---
title: ADR-016 — Persistent area native residency
document-kind: decision
status: Current
canonical-for: [persistent-area-native-residency-decision]
scope: Isolated Draft GEN-006 successor to ADR-015; native ownership transfer, RAM tiers and explicit deferred durability
keywords: [GEN-006, native ownership, RAM cache, write-behind, prefetch]
related-documents: [ADR-015-persistent-authored-areas.md, ../systems/persistent-area-residency.md]
last-reviewed: 2026-11-22
---

# ADR-016 — Persistent area native residency

## Context

The owner authorised all three GEN-006-RAMCACHE-001 stages on qualified #725, retaining Draft/HOLD and ordinary
defaults. Full restoration and synchronous publication are valid conservative boundaries but unnecessary on
every resident return. Measured donor latency motivates instrumentation; it does not prove disk thrashing.

## Decision

Extend the existing native adapter with typed unique ownership of inactive complete World bundles. Transfer
ownership through native fences and a one-use Main/worker ticket. Keep one active gameplay World; inactive HOT
Worlds do not receive active gameplay mutation. WARM means validated checkpoint bytes; COLD means durable storage.
HOT hits must not reconstruct or deserialize native state.

Use a value-only cache ledger with explicit budget, pins, growth/transient reservations and conservative LRU.
Keep residency, durability, readiness and eviction independent. Preserve full native continuation and the
current/previous manifest transaction. Deferred travel is an explicit experimental session option; Save all
and normal exit retain acknowledged durability semantics.

A fully validated, budgeted WARM candidate and its verified accounted clock become retained RAM authority
together. Publication failure preserves that completed work and the active source HOT World. Strict mode
still requires a durable ACK before destination activation. Lost-ACK Retry reconciles exact publication
identities against those retained authorities, rather than reconstructing an older checkpoint. Native discard
and lease acknowledgement precede retirement of the associated preparation reservation.

Use one immutable I/O batch plus bounded metadata coalescing. Capture stays at the exclusive owner boundary;
expensive publication runs on the I/O owner. An older Save ACK advances durable metadata only, never newer RAM.
Predict the A/B/C graph from destination intent and editor/camera signals. One private preparation thread owns
its adapter and returns unique ownership only after joining. Inactive HOT slices use the existing owner.
Area-local fences allow useful work to commit while unrelated global time advances. No skipped-time credit is added.

Retain the original clock/plan and exact pending request across resident-advancement timeouts. Admit each proven
native prefix together with its receipt, and keep the recovery record through lease release. Debt and future
time keep their original meanings after Retry. A known failed active result can retire that request after
acknowledged release without resuming the failed World or crediting its failing tick; healthy-area rescue
remains a separate explicit operation. Unknown or contradictory outcomes stay pinned.

## Alternatives and reversibility

| Alternative | Decision |
| --- | --- |
| CYPS buffers labelled HOT | Rejected: useful WARM caching, but native reconstruction remains. |
| Copy Worlds on travel | Rejected: transfer unique ownership and preserve exact state. |
| Flush every departure | Retained as strict mode; explicit deferred mode admits RAM-only departure. |
| Background mutation of active adapter | Rejected: separate private preparation owner; exclusive active authority. |
| Invalidate prefetch on every global tick | Rejected: area-local fences admit actual completed legitimate work. |
| Arbitrary chunks or actor transfer | Deferred: outside this three-area admitted state domain. |

Disabling caching restores the conservative path after safe publication/eviction. Disabling prediction removes
speculative work. Disabling deferred mode restores the durability barrier. Source-matched qualification is
required for adoption; this decision grants no merge or Ready conversion.
