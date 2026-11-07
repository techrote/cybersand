---
title: PressureFlow gas-cache admission diagnosis and selective bootstrap
status: Proposed
document-kind: audit
scope: PR #532 causal diagnosis, proof boundary and qualification record
last-reviewed: 2026-11-07
related-documents: [../architecture/pressure-optimization.md, 2026-11-07-pf-gas-selective-cache-transition.md]
---

# PressureFlow gas-cache admission diagnosis and selective bootstrap

## Source baseline

PR #532 branches from accepted main `81bbd5ff5cf366159e2b8a630609359c13560080`.
The implementation deliberately does not import the #504 BFS/seed fast paths or
rewrite the #505/#515/#522 evidence branches.

Prior production-facing evidence established the problem boundary:

- the native-only #504 source can reduce isolated gas discovery work;
- the actual application still executes one complete reference gas pass per
  gas-enabled tick and observed zero whole-gas or component cache reuses;
- the full 2048x1024 stress-canvas reduced the apparent native-only benefit to
  a low-single-digit tick improvement.

Those observations make cache admission, rather than another BFS micro-fastpath,
the bounded subject of this change.

## Causal diagnosis

The cache already contains a selective component mechanism:
`replay_pressure_gas_region()` can replay a recorded sealed component at its
actual reference seed, and `prepare_pressure_gas_cache()` can invalidate
individual summaries against owner-reduced dirty chunks.

The mechanism was nevertheless cold under sustained topology activity because
`rebuild_pressure_gas_cache()` constructed **all** component summaries only
when the complete gas operator reported a global fixed point:

`!topology_changed && !labels_changed && chunk_allocations == 0`.

That requirement is necessary for **whole-operator** reuse, but it is stronger
than the proof already available for an individual sealed component. A local
edit can legitimately make `topology_changed` or `labels_changed` true while
many unrelated compartments retain identical membership and identity. Before
PR #532, those unrelated compartments received no certificate at all.

## Selective proof admitted by PR #532

A component can bootstrap only from a gas pass that has just completed through
the authoritative reference reducer. It must satisfy the pre-existing strong
component proof:

1. sealed, positive-ID, bounded-volume region;
2. no fresh or atmosphere cells and no nonresident-node dependency;
3. exactly one prior-compartment overlap;
4. that overlap count equals the complete region volume;
5. the prior compartment ID equals the reducer-selected region label;
6. the live compartment still has identical ID, volume and anchor;
7. resident cache membership is complete and the gas pass allocated no chunks.

For the new active-churn bootstrap, the owner must additionally retain a
complete bounded dirty-chunk set. Any component whose one-chunk-expanded bounds
intersect that set is invalidated before it can be replayed. Dirty-set overflow,
pair-budget exhaustion, member-capacity exhaustion, incomplete resident
membership or other uncertainty declines the cache.

Replay remains optimistic only until validation. Before a single member is
stamped, every recorded member must still resolve to the same indexed chunk and
cell, remain Empty, retain the same gas label, be clear of transient obstacles
and not already belong to the current reference region. A stale proof requests
one complete uncached restart before authoritative identity reduction.

Whole-gas reuse remains unchanged and still requires the original global fixed
point.

## Cost bound

The selective bootstrap performs at most one extra component/member construction
between complete cache/index builds. It is not permitted to rescan the complete
resident World every active tick. Once admitted, existing valid summaries are
retained across unrelated churn and independently invalidated as owner-reduced
gas inputs arrive.

No new per-cell storage is introduced. Existing bounded gas-member,
gas-component and dirty-chunk reservations are reused; PR #532 adds only
owner-side proof state. The pressure-optimization execution identity advances
from v4 to v5 because derived work changes. Physical state, gas/save authority,
capacity identities and serialization do not.

## Qualification status

The exact-source deterministic replay and actual 2048x1024 eight-Rapier-barrel
B-C-C-B CPU qualification are branch-scoped evidence gates:

- deterministic replay: https://github.com/techrote/cybersand/actions/workflows/pf532-gas-cache-identical-replay.yml
- real workbench CPU/gameplay: https://github.com/techrote/cybersand/actions/workflows/pf532-fullsize-cpu-physics.yml

The deterministic gate requires exact per-tick physical/gas/Water parity across
accepted main and PR #532, one/four-worker parity, unchanged complete-reference
pass count, actual component-member validation/replay and reduced BFS cell work.

The workbench gate builds accepted main and PR #532 with one compiler and
temporary identical timing probes, then runs the original 2048x1024
`stress-canvas` with eight live Rapier barrels in B-C-C-B order. It records
native tick timing, gas wall/process/owner CPU windows, discovery/identity/
relabel CPU windows, cache work, memory observations, native worker
participation and native conservation checkpoints.

**No performance GO is asserted by this document.** The optimization remains
proposed until those exact-head measurements demonstrate worthwhile real
gameplay CPU savings. If they show negligible or negative benefit, the
implementation is a NO-GO rather than a reason to expand cache complexity.
