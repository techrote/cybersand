---
title: ADR-005 — Conserved fixed-point water semantics
document-kind: decision
canonical-for: [decision-conserved-pairwise-water]
status: Current
scope: Original FreeMass Water decision, accepted quantity invariants and current applicability across later admitted solver laws
keywords: [ADR, Water, mass conservation, fixed point, stable rest, pairwise, buffered flux]
related-documents: [../systems/water-design.md, ADR-002-double-buffered-tile-jobs.md, ../architecture/determinism-and-boundary-transfers.md]
last-reviewed: 2026-11-24
---

# ADR-005: Conserved fixed-point water semantics

## Decision and implementation status

This decision records the original FreeMass law and why its phased pairwise
implementation replaced mandatory buffered flux. Its invariants remain relevant;
its original implementation description is not a complete inventory of current
Water. The [family policy](../architecture/liquid-solver-family-policy.md) and
[Water contract](../systems/water-design.md) own later admitted laws and defaults.

**Approved:** free Water shares material-grid authority, uses deterministic
fixed-point quantity and conserves exact integer mass in closed operations.
Equivalent resting states must stop exchanging mass. Viscosity/flow rate,
pressure yield and adhesion are distinct concepts. Visual dither cannot alter
mass, material identity, activity or authoritative hashes.

**Current FreeMass reference:** bounded pairwise transfers use the applied
Water precision/coherence policy. Its ordinary defaults retain eight mass bits.
Accepted source also admits CellularYield, PressureFlow and inertial Water;
Wave is a separate execution overlay selected for new ordinary player/Workbench
sessions. These laws do not share identical state, rest rules or persistence.
The current [configuration reference](../reference/configuration-reference.md)
separates native construction defaults from the player profile.

Active-only buffered FreeMass remains a design candidate if measured needs
justify it. Native signed quantity accounting and some tick-boundary physical
formats now exist; neither establishes complete application replay. Source:
[World Water rules](../../native/src/world.cpp),
[admitted policy cells](../../native/include/cybersand/liquid_solver_policy.hpp),
[player Wave selection](../../godot/native_extension/cyber_native_cell_world.cpp)
and [save coverage](../reference/level-saves-and-replay.md).

## Why was mandatory buffered flux dropped?

An earlier design tied conservation to immutable current/next flux output.
ADR-002's spatial exclusivity permits exact bounded pairwise transfer with less
copy traffic. Conservation and stable rest are behavioral requirements; they
do not require a particular buffering technique.

One-worker PhasedInPlace establishes the same traversal semantics used by its
multiworker version. A future buffered solver would be compared on conservation,
rest, leveling, bias, memory and total cost. Different backends need not produce
identical bytes unless intentionally implementing identical order/semantics.

## Consequences and alternatives

Pairwise flow fits the common scheduler and makes quantity locally testable.
Its risks are directional/phase bias, quantization chatter, premature sleep and
boundary artifacts. The provisional fixture gate includes closed-container,
leveling, stable-rest and worker parity; it is not an exhaustive mirrored/every-
boundary proof. Actual executed evidence is in the
[validation ledger](../reference/validation-evidence.md).

**Rejected for the original FreeMass law:** finite travel history as its
equilibrium rule, equivalent
full-cell swaps at rest, aggressive lateral freezing and an independent liquid
world. Explicit yielding Paste/Slush may retain a finite travel/resting-slope
model. The desktop fallback's long-range discrete Water rules are Current
alternate semantics, not native radius or bit-equivalence claims.

The original deferral of a general fluid solver is not a claim that later
bounded pressure, inertial or Wave work is absent or prohibited. Each accepted
law has its own contract and remaining limits. Buffered FreeMass remains a
retained design candidate, not an available rollback. Existing serial/one-worker
paths provide comparison subject to their documented semantics.

## What must a later change preserve?

Test exact closed Water totals, stable content after settling, boundary movement,
wake behavior and worker parity for declared configuration. Keep partial-cell
appearance render-only. A new reaction or particle conversion needs explicit
source/sink accounting; pure Water conservation cannot prove that accounting.
CYSD1 preserves compact Water level state but does not restore future tick
behavior: use [level saves versus replay](../reference/level-saves-and-replay.md).
Changing representation or identity requires versioned migration rather than
silently reinterpreting existing saves.

## Faster lateral relaxation, 2026-09-10

**Retained FreeMass change, 10 September:** the owner requested faster sideways leveling after the #13 Tower
walkthrough. That FreeMass change transfers three quarters rather than half of a lateral
mass imbalance. It retains bounded adjacent reads/writes, exact integer mass,
one-unit rest tolerance, gravity, 12-tick coherent emission and 48-unit adhesion.
The [dated comparison](../audits/2026-09-10-water-leveling.md) measures fronts,
leveling and cost independently of display pacing. No increased global tick rate,
extra sampling pass, pressure field, chemistry cadence or save-format change is
introduced. Optional transport strength follows the increased actual Water flux;
this is a deliberate behavioral delta requiring its own source/artifact record.
