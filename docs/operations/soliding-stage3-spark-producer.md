---
title: Issue 12 Stage 3 Spark packet A - World producer integration
status: Planned
document-kind: runbook
scope: Bounded GPT-5.3-Codex-Spark implementation package for complete World-to-discovery notifications; no connectivity or acceleration
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [soliding-stage3-freeze.md, ../audits/issue-12-2026-09-19/producer-hook-review.md, ../systems/settled-region-discovery.md]
---

# Spark packet A: World producer and witness integration

## Frozen objective

Implement the complete opt-in World-side producer required by
[the Stage-3 freeze](soliding-stage3-freeze.md).

The result supplies canonical bounded discovery tiles, independent mutation/signal
witnesses and owner-serialized journal service. It does **not** build connected
regions, skip simulation, change material semantics or transfer material ownership.

Read repository `AGENTS.md`, issue #12, PR #43 evidence and the freeze before editing.
If they conflict, stop and return the conflict to the parent.

## Ownership

You may own/change, subject to actual-source review:

- `native/include/cybersand/world.hpp`
- `native/src/world.cpp`
- a new focused native producer/coordinator header/source if useful, e.g.
  `settled_world_discovery.*`
- `native/include/cybersand/settled_discovery.hpp` only for narrowly required
  bounded producer/registration API extensions
- focused producer integration tests
- focused producer documentation/evidence assigned by the parent

Avoid editing:

- future cross-tile region/connectivity implementation files;
- Rapier/Godot ownership code unless the parent explicitly reassigns scope;
- material rules, Water solver, reaction tables or granular policy;
- #26 experiment files;
- benchmark/reducer files owned by packet D except tiny compile seams agreed first.

## Frozen design requirements

Implement the canonical subtile rule from the freeze. Discovery remains opt-in and
cells-owned.

Cover the complete producer matrix. Prefer one central direct-mutation hook plus
post-barrier JobEffects invalidation rather than duplicating logic across every
kernel.

Workers may write only their existing job-local effects. The serialized owner feeds
discovery after barriers.

Implement or prove:

- direct material/state/temperature ABA;
- movement/transfer source+destination invalidation;
- worker effect rectangles after barriers;
- no-write activity and interaction-deadline signals;
- transient mask add/remove/reconfigure ABA;
- accepted pending explosion coverage before execution;
- requested/applied simulation-region fences;
- new-chunk/reservation tile registration;
- live semantic-policy fence where relevant;
- clear/replacement/move incarnation behavior;
- immediate failed-world discovery halt;
- render-dirty independence;
- epoch wrap excluded from payload invalidation.

Use exact stored material/state/temperature plus separate occupancy. Do not derive
exact tuples from public masked getters.

If canonical registration needs an API extension to avoid the journal's measured
quadratic duplicate-bound setup path, keep it bounded and prove caller uniqueness
from canonical tile keys. Do not simply delete duplicate safety from public setup.

## Capacity behavior

Tracking setup/queue/mapping saturation:

- never fails or truncates authoritative World simulation;
- leaves refused coverage explicit unknown/witness-incomplete;
- cannot yield a complete region/candidate later;
- records metrics/refusal reason;
- contains no hidden unbounded overflow structure.

If a pending event cannot be mapped locally under bounded discovery scratch, make
discovery conservatively nonconsumable until safe reconstruction/drain; do not reject
the World event.

## Required tests

At minimum add source-matched tests for:

- set -> restore ABA before tick;
- state_a/state_b-only ABA;
- Empty nonambient heat ABA;
- move/swap source+destination;
- Water transfer/coherence;
- workers1/4 JobEffects parity;
- no-write keep-active;
- scheduled deadline while otherwise sleeping;
- mask add/remove and configure/clear ABA;
- far mask locality;
- accepted explosion pending before execution;
- exclusion request before apply, re-entry and no quiet-age carryover;
- new chunk/reservation tile registration;
- capacity refusal leaves World unchanged;
- clear/new incarnation, World move/replacement contract;
- injected failed tick immediately suppresses snapshots;
- render dirty consumption does not acknowledge discovery;
- repeated epoch wraps do not create payload invalidations;
- custom activity/chunk geometries covered or explicitly/refusably unsupported;
- negative coordinates and endpoint preflight.

Feature-disabled paired controls must retain content/state/work behavior with workers1/4.
Run sanitizers/TSan where feasible.

## Metrics to return

Report:

- producer notifications by reason;
- tiles invalidated/mapped per reason;
- activity blocks/subtiles inspected;
- registration work and refusal;
- effect-rectangle false invalidation;
- event/mask fanout;
- global fence counts;
- queue high-water;
- per-tick producer CPU time if instrumented;
- additional fixed/dynamic memory.

Do not claim a speedup.

## Acceptance

Return to the parent only when:

- every frozen producer row is covered or explicitly leaves affected coverage
  witness-incomplete;
- no worker touches shared discovery state;
- no simulation behavior depends on tracking capacity;
- exact tuple/mask/event ABA tests pass;
- failed/excluded/reset identities cannot publish stale observations;
- feature-disabled parity passes;
- documentation states remaining gaps honestly.

## Escalate instead of improvising

Stop if correctness appears to require a new material semantic, global rollback,
worker-shared discovery mutation, unbounded mapping, changes to Stage-3 tile geometry,
or any acceleration/Rapier behavior.

Your final report must list changed files, exact tests/commands, pass/fail results,
remaining incomplete producer rows, measured overhead and parent-level decisions
still required.
