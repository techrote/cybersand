---
title: ADR-005 — Conserved fixed-point water semantics
document-kind: decision
canonical-for: [decision-conserved-pairwise-water]
status: Current
scope: Accepted Water invariants and phased implementation choice; buffered comparison and wider accounting remain unimplemented
keywords: [ADR, Water, mass conservation, fixed point, stable rest, pairwise, buffered flux]
related-documents: [../systems/water-design.md, ADR-002-double-buffered-tile-jobs.md, ../architecture/determinism-and-boundary-transfers.md]
last-reviewed: 2026-09-08
---

# ADR-005: Conserved fixed-point water semantics

## Decision and implementation status

**Approved:** free Water shares material-grid authority, uses deterministic
fixed-point quantity and conserves exact integer mass in closed operations.
Equivalent resting states must stop exchanging mass. Viscosity/flow rate,
pressure yield and adhesion are distinct concepts. Visual dither cannot alter
mass, material identity, activity or authoritative hashes.

**Current native implementation:** phased pairwise 8-bit mass transfers inside
exclusive write domains. **Planned:** active-only buffered flux if demonstrated
behavior/field needs justify it; generalized reaction accounting and complete
replay. The [Water contract](../systems/water-design.md) owns current transfer
rules, constants, fallback differences and fixture limits. Source:
[World Water rules](../../native/src/world.cpp),
[material descriptors](../../native/include/cybersand/material.hpp).

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

**Rejected:** finite travel history as free Water's equilibrium rule, equivalent
full-cell swaps at rest, aggressive lateral freezing and an independent liquid
world. Explicit yielding Paste/Slush may retain a finite travel/resting-slope
model. The desktop fallback's long-range discrete Water rules are Current
alternate semantics, not native radius or bit-equivalence claims.

**Deferred:** a general fluid solver. Buffered flux remains a retained design
candidate, not an available rollback. Existing serial/one-worker paths provide
executable comparison, subject to their documented semantics.

## What must a later change preserve?

Test exact closed Water totals, stable content after settling, boundary movement,
wake behavior and worker parity for declared configuration. Keep partial-cell
appearance render-only. A new reaction or particle conversion needs explicit
source/sink accounting; pure Water conservation cannot prove that accounting.
CYSD1 preserves compact Water level state but does not restore future tick
behavior: use [level saves versus replay](../reference/level-saves-and-replay.md).
Changing representation or identity requires versioned migration rather than
silently reinterpreting existing saves.
