---
title: WEX-004 bounded decompression impulse-event preregistration
document-kind: reference
canonical-for: [wex-004-bounded-decompression-proof]
status: Planned
scope: Frozen preregistration for the bounded non-production WEX-004 decompression-event proof; no production atmosphere, gas CFD, Water pressure solver or generic field adoption
last-reviewed: 2026-09-20
related-documents: [lumped-gas-region-pressure-bookkeeping.md, ../operations/water-hybrid-pressure-extension-programme.md, ../systems/smoke-heat-pressure-roadmap.md, ../architecture/rigid-body-and-cellular-coupling.md, ../architecture/data-ownership-and-lifetimes.md, ../architecture/simulation-tick-and-threading.md, ../decisions/ADR-007-rigid-body-cellular-coupling.md, ../decisions/ADR-008-bounded-approximate-fidelity.md, ../decisions/ADR-009-rapier-2d-rigid-body-backend.md]
---

# WEX-004 bounded decompression impulse-event preregistration

## Status and source identity

This document freezes the WEX-004 experimental contract **before candidate implementation**.
A negative, narrowed or no-go result is valid completion. This proof must not be
treated as production atmosphere architecture.

Branch point and authoritative source at registration:

- repository: `techrote/cybersand`;
- authoritative `main`: `195a7ce1de3c891a1650e593896fb74ee46a74df`;
- WEX-003 / #93: complete through PR #103 and explicitly admits #94 only as a
  bounded non-production proof;
- WEX-003 canonical research:
  `docs/research/lumped-gas-region-pressure-bookkeeping.md`;
- #49 is active separately in PR #104;
- Stage-3B sparse coverage work is active separately in PR #101;
- no #94 implementation branch/PR existed at the ownership check before this branch.

The WEX-004 branch deliberately does **not** edit `native/src/world.cpp`,
`native/include/cybersand/world.hpp`, or the WEX programme document while PRs
#101/#104 own those write sets. The proof is isolated in the existing diagnostic
GDExtension owner, dedicated test/evidence surfaces, and the already-authorized
main-thread Rapier result bridge.

## Pre-execution adapter amendment: Arm B

No WEX-004 physical result had been produced when this amendment was registered.
The first implementation arm placed the frozen model directly in the native
GDExtension diagnostic class. That unnecessarily widened the experiment's ABI and
forced republishing retained native runtimes even though #94 does not require a
new production/native owner.

**Arm B therefore supersedes only the adapter/ownership placement of Arm A.**
All pressure mapping, source/event budgets, thresholds, horizon, lifetime,
occlusion rule, target classes, deterministic ordering and acceptance/no-go
criteria below remain unchanged.

Arm B is implemented as an isolated, non-production GDScript diagnostic model
that:

- consumes the existing packed rigid-body value snapshot from
  `CyberRapierPhysicsBridge.pack_body_states()`;
- returns ordinary `CyberRigidBodyCoupling` result rows, which are applied only
  through the existing main-thread
  `CyberRapierPhysicsBridge.apply_cellular_results()` path;
- reads cellular state only through the existing diagnostic/native value API;
- relocates eligible loose diagnostic cells through the diagnostic-only
  `diagnostic_relocate_cell` adapter, which delegates to the existing native
  `World::relocate_stored_cell` ownership/mutation path;
- treats the existing diagnostic world's general revision as a **conservative
  authority/topology revision**. Any external cell mutation invalidates the event
  registration, not merely a hard-surface edit. Revisions caused by Arm B's own
  successful loose-cell transaction are adopted only after that serialized step;
- computes transient body occupancy from the already-packed body value snapshots,
  so no RID, Node or PhysicsServer object crosses into the model;
- adds no native source, ABI, retained runtime, permanent field or production
  ownership change.

This adapter amendment is intentionally more conservative than Arm A about stale
authority and less invasive in runtime ownership. It is **not** a force-law tuning
arm and was registered before executing Arm B scenarios.

The Arm-A native placement language retained later in this document is historical
preregistration context where it conflicts with this amendment; Arm B owns the
executed proof.

## Pre-rerun semantic correction: payload-preserving relocation

The first Arm-B execution exposed an acceptance defect in the adapter rather than
in the frozen decompression model: loose cells were moved by writing the material
ID at the destination and clearing the source through `diagnostic_fill_rect`.
That demonstrated position/material motion but did not prove preservation of the
authoritative cell payload or optional temperature, and therefore cannot satisfy
D4's ownership/conservation acceptance by itself.

Before rerunning the proof, Arm B is corrected as follows:

- `CyberNativeCellWorld` exposes one diagnostic-only
  `diagnostic_relocate_cell(from, to)` method;
- that method delegates directly to existing
  `World::relocate_stored_cell()`, so the existing native `move_cell` path owns
  the material/state/temperature transfer as one serialized operation;
- hard-surface sources are rejected by the diagnostic adapter so the helper cannot
  bypass hard-surface/Rapier collider ownership;
- the GDScript event model no longer recreates a destination cell from a material
  ID and additionally rejects source cells currently covered by the packed body
  snapshot;
- a native regression directly verifies relocation preserves `state_a`,
  `state_b` and optional temperature and refuses an occupied destination without
  mutation.

This correction changes **only the mutation adapter/acceptance evidence**. It does
not change pressure mapping, opening weights, budgets, thresholds, horizon,
lifetime, target eligibility, occlusion, force direction or work caps. The earlier
Arm-B D4 result is superseded and must not be used as final acceptance evidence;
the corrected exact-head scenarios must be rerun.

## Research question

Can a pressure difference between resolved gas-region snapshots drive plausible,
local motion of loose cellular debris and generic Rapier bodies with a finite
source budget, obstacle awareness and stale-topology cancellation, without adding
cellular gas CFD, a whole-room flow field, or a production atmosphere system?

The pressure interpretation is fixed:

- all authoritative pressure inputs are absolute pressure in pascals;
- destination pressure may approach zero absolute pressure;
- negative absolute pressure is invalid;
- the source is higher pressure and motion is an **outflow along the opening
  normal from source to destination**, never an attraction toward the breach.

## Experimental owner and event schema

The proof lives only in a fresh-world diagnostic API owned by
`CyberNativeCellWorld`. It consumes resolved value snapshots supplied by the
serialized owner; it does not create or maintain gas-region topology.

A registered source record carries:

- source region ID;
- source generation;
- initial absolute pressure;
- initial gas-amount proxy;
- registration hard-surface/topology revision;
- finite initial and remaining shared work budget.

Each opening event carries:

- opening ID and generation;
- destination region ID and generation;
- opening cell-space position;
- normalized source-to-destination normal;
- bounded effective opening area;
- destination absolute pressure;
- finite initial and remaining event work share;
- registration tick and 12-step maximum lifetime;
- 10-cell local effect horizon;
- the required topology revision.

Capacity is **four events per source registration**. Source absolute pressure is
accepted only in `(0, 10,000,000]` Pa, destination absolute pressure in
`[0, 10,000,000]` Pa, and source amount proxy only in `(0, 1,000,000]`.
Effective opening area is accepted only in `(0, 64]` square-cell proxy units. Duplicate opening IDs, malformed/non-finite inputs, negative
destination pressure, invalid normals, out-of-world openings or excess events are
explicit registration refusals; they are not silently truncated.

## Frozen pressure-to-budget mapping

This proof uses a unitless **work proxy**, not joules and not a calibrated gas model.

For all valid openings, define an area-weighted effective destination pressure:

`P_dest_eff = sum(area_i * min(P_dest_i, P_source)) / sum(area_i)`.

At fixed source volume, the isothermal amount proxy that could be discharged before
that conservative effective equilibrium is:

`A_extractable = A_source * clamp(1 - P_dest_eff / P_source, 0, 1)`.

The finite shared source work budget is:

`B_source = min(12.0, A_extractable * 1.0)`.

If every opening has less than **250 Pa** positive differential, registration is
valid but creates no effective work. The threshold is frozen to prevent tiny
near-equal differences from becoming persistent jitter.

Initial opening weights are:

`w_i = area_i * max(P_source - P_dest_i, 0)`.

Each event receives once, at registration:

`B_i = B_source * w_i / sum(w)`.

Thus event budgets sum to the one source budget: adding openings cannot multiply
available work.

After actual work `W` is consumed, source amount decreases by `W / 1.0`,
clamped at zero. Current source pressure is always derived from the original
snapshot by the fixed-volume ratio:

`P_current = P_source_initial * A_remaining / A_source_initial`.

An event stops producing work whenever `P_current - P_dest_i < 250 Pa`, its
budget reaches zero, topology/generation becomes stale, or its lifetime expires.

No coefficient may be tuned after observing D0-D8 without registering a new
experimental arm.

## Frozen per-step work limits and decay

Per diagnostic step:

- global applied-work cap: **2.5** proxy units;
- per-event applied-work cap: **1.25** proxy units;
- each event grant is also capped by its remaining event budget and the remaining
  shared source budget;
- the event grant is multiplied by the linear lifetime envelope
  `(12 - age) / 12`;
- a maximum of **32 successful cellular relocations globally per step** is allowed;
- one successful cellular relocation costs **0.04** work units;
- when both target classes are present, at most half the event grant is reserved
  for cellular relocation and half for Rapier impulse;
- if only one target class is present, that class may use the full event grant;
- unused class allocation is not reallocated later in the same event step;
- a single Rapier body receives at most **0.75** impulse proxy units from one
  event in one step.

These limits bound capacity and work even at vacuum stress. Metrics retain budget
offered, actually consumed, refused and remaining separately.

## Frozen local field and occlusion policy

The candidate is a **local normal-directed outflow proxy**, not a radial field.

For an opening at `O` with source-to-destination unit normal `N`, a target at
`X` is eligible only when:

- Euclidean distance `|X-O| <= 10` cells;
- `dot(X-O, N) <= 0.5`, so the target is on or just inside the source side;
- a bounded integer line traversal from target to opening finds no intervening
  hard-surface cell.

The line traversal checks at most the local horizon plus one cells and excludes
the target and opening endpoints. It does not pathfind around corners. A wall that
blocks the direct path therefore suppresses the event rather than allowing
through-wall "suction".

Rapier impulse direction is exactly `N`. Eligible body weights use the frozen
linear distance falloff `max(0, 1 - distance / 10)`; the Rapier class allocation
is divided proportionally across eligible bodies in ascending body-ID order.

Loose-cell movement uses the same `N`, quantized once per event to the nearest
8-neighbour cell step. It is **not** a vector toward the opening. Eligible cellular
materials are exactly `Sand`, `Dust`, `Salt` and `Gunpowder`. Candidate
cells are collected before mutation in deterministic y-major/x-major order and
relocated through the existing serialized `World::relocate_stored_cell` path only
when the destination is empty and not a transient body obstacle. A cell already
relocated by an earlier event in the same diagnostic step cannot be moved again.

The proof adds no permanent per-cell velocity, gas velocity, pressure or ownership
field.

## Deterministic ordering and stale cancellation

Events are sorted by opening ID at registration. Duplicate IDs are refused.
Within each event:

1. validate source/opening/destination generation snapshots;
2. validate the captured hard-surface topology revision;
3. compute current differential and bounded grant;
4. collect body targets in ascending body ID;
5. collect cellular targets y-major then x-major;
6. apply the frozen class split and work caps.

Every step supplies the current source generation plus the current opening and
destination generations in registered event order. A mismatch cancels the affected
event; a source-generation mismatch cancels all events. Any hard-surface revision
change cancels the registration conservatively. Cancellation applies no stale work.

## Required scenarios and fixed horizons

The retained proof must cover:

- **D0 simple breach:** high-pressure source to lower-pressure exterior; nearby
  loose matter moves along the outward normal and effect decays;
- **D1 obstacle:** an intervening hard wall blocks direct influence;
- **D2 offset target:** offset targets still move along the opening normal rather
  than toward the opening point;
- **D3 generic Rapier body:** an ordinary small rectangular body receives bounded
  impulse through `CyberRapierPhysicsBridge` on the main thread;
- **D4 cellular debris:** eligible loose cells move only through the legal
  serialized relocation path;
- **D5 multiple openings:** two openings consume shares of one finite source budget;
- **D6 stale topology:** a hard-surface revision or generation change cancels
  deterministically before further work;
- **D7 low differential:** a differential below 250 Pa produces no persistent
  response;
- **D8 vacuum stress:** destination pressure 0 Pa remains finite and respects all
  caps.

D0, D1/D2 and D5 must include shifted or mirrored repetitions sufficient to expose
coordinate/order bias. Deterministic repeated runs must match their retained
metrics.

The primary horizon is 12 event steps. No scenario may increase the 10-cell spatial
horizon or 12-step lifetime to obtain a positive result.

## Retained metrics

The diagnostic report must expose, at minimum:

- source/destination absolute pressure and source amount;
- source initial/remaining work budget;
- opening area and each event initial/remaining budget;
- event age/lifetime;
- cellular relocation attempts/successes and work consumed;
- Rapier targets/impulse proxy and work consumed;
- occlusion rejections and local field/line cells visited;
- stale cancellations;
- registration/capacity refusals;
- per-step offered/applied/refused work;
- exact current topology revision and expected revision.

The final evidence must also record exact Git source, runtime/profile/platform,
worker identity and applicable p50/p95/p99/max cost populations.

## Success, narrowing and no-go criteria

A result may be recorded as **promising** only if the candidate:

- demonstrates bounded outward response in D0;
- rejects D1 through-wall influence;
- remains normal-directed in D2;
- moves both D3 and D4 targets through existing legal ownership paths;
- proves D5 does not duplicate the source budget;
- cancels D6 before stale work;
- remains negligible/stable in D7 and bounded in D8;
- stays within the declared local traversal, capacity and work ceilings.

Record **narrow-use** if the local straight-line abstraction is useful only for
simple/open breaches, requires conservative cancellation, or cannot plausibly
represent routed/corner flow without a broader field.

Record **no-go** if credible required behavior needs whole-room traversal, a
persistent gas-velocity field, generalized gas CFD, duplicated source energy,
through-wall attraction, unsafe ownership, or unacceptable cell/body disagreement.

Do not weaken a control, change a constant, extend the horizon, or add a production
field to manufacture a positive result.
