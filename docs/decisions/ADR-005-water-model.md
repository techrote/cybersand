---
title: ADR-005 — Conserved fixed-point water semantics
status: Current
scope: Stable conserved liquid invariants, phased pairwise candidate, buffered flux fallback, shared-grid authority, rendering-only dithering, and benchmark gate
keywords: [ADR, water, fixed-point mass, pairwise transfer, flux, conservation, phased in-place, stable rest]
related-documents: [../systems/water-design.md, ADR-002-double-buffered-tile-jobs.md, ../operations/testing-validation-and-replay.md]
last-reviewed: 2026-08-27
implementation-state: Preferred Godot runtime uses native World's phased conserved 8-bit pairwise Water, normalized viscosity, coherent emission delay, optional adhesion, and stable render-only dithering; discrete Water remains only in the GDScript platform fallback.
---

# ADR-005: Conserved fixed-point water semantics

## At a glance

- Decision revision: conservation and stable-rest behavior are fixed requirements; double-buffered flux is no longer a predetermined implementation.
- The Current native implementation uses exact pairwise 8-bit transfers inside phased exclusive write domains.
- A buffered flux solver remains **Planned** only as a fallback for demonstrated future field needs.
- Both candidates share the material grid and explicit conversion semantics.
- Equivalent resting states do not repeatedly exchange mass.
- Visual dither is derived outside authoritative simulation state.
- The solver choice is made from common conservation, stability, behavior, memory, and timing fixtures.

## Search anchors

in-place conserved water, pairwise fixed point transfer, buffered liquid fallback, stable water scheduler, liquid benchmark gate, water shimmer

## Status

**Current** for native phased Water and corrected discrete Godot leveling;
**Planned** for generalized reaction accounting, native/Godot bridge
integration, serialization, and the optional buffered fallback.

## Context

Current Godot Water remains a discrete full-cell reference, but Water now uses
persistent directed flow, zero normalized viscosity, 24-cell bounded
dispersion, and a bounded stopped-edge pressure look-ahead. Its earlier finite
travel limit is retained only as a yielding-liquid extension mode. Native Water
uses compact mass and viscosity-scaled exact pairwise transfers.

The earlier decision coupled conserved water to an immutable-current/next-state flux calculation. The scheduler revision in ADR-002 makes a lower-traffic option credible: exact pairwise transfers performed only where a phase grants exclusive ownership. Conservation and rest are behavioral invariants, not reasons to double-buffer the entire liquid field by default.

## Decision

### Shared requirements

- Represent liquid quantity in deterministic fixed-point arithmetic.
- Attach liquid state to the common material-grid authority rather than create a competing world.
- Define explicit Empty/Water-bearing conversion rules.
- Conserve the exact integer total for every closed authoritative operation.
- Do not exchange mass between equivalent resting states merely to remain active.
- Keep viscosity/flow rate independent from pressure yield/resting-slope behavior.
- Keep visual dither outside authoritative mass, material identity, activity, and replay state.
- Validate single-thread semantics before parallel execution.

### Leading candidate: phased pairwise transfers

- A one-worker reference executes the same fixed phase and traversal order intended for the parallel phased scheduler.
- Each operation transfers an exact bounded amount between a pair of cells wholly inside the job's owned write domain.
- The source cannot emit more mass than it holds and the destination cannot exceed its approved capacity.
- No atomic operation or inter-worker write is permitted.
- A pair that crosses the current ownership boundary is processed only under a later eligible phase or an explicitly specified deferred mechanism.
- Material identity changes occur only through defined mass thresholds.

Current numeric choices are an 8-bit unsigned mass, 255-unit capacity, exact
Empty transitions at zero/nonzero, downward/diagonal fill, lateral half-difference
transfer only above a one-unit rest tolerance, deterministic scan order, and
phase-owned boundary writes.

### Retained candidate: buffered flux

- Read one immutable liquid state, compute bounded flux, resolve conflicts deterministically, and commit a next liquid state.
- Use this as a behavior comparison, rollback path, and option if pairwise order bias or phase restrictions fail acceptance.
- Buffer only active liquid state; never double-buffer the entire stored world.

### Decision gate

The phased implementation is accepted provisionally by closed-container,
lateral-leveling, sleep/stability, heap prevention, and worker-parity fixtures.
Mirrored bias and a full every-boundary matrix remain **Planned**. A future
buffered candidate must use the same invariants.

Cross-backend byte-identical states are not required unless both intentionally implement identical update semantics. Determinism is required within each backend for a fixed configuration.

## Consequences

### Positive

- Water can share the leading phased scheduler without forcing grid-wide copy traffic.
- Conservation remains locally and globally testable.
- Buffered flux remains available if pairwise traversal creates unacceptable artifacts.
- Stable rest supports activity sleeping and dirty-work elimination.

### Negative

- Pairwise in-place flow can introduce directional or phase-order bias.
- The two candidates require behavior-level comparisons rather than assuming byte equality.
- Conversion thresholds and partial-cell rendering require explicit design.
- A liquid-only buffered field adds coordination if selected alongside in-place materials.

### Risks

- Quantization or minimum-flow choices can leak, chatter, or prevent leveling.
- Ownership-edge deferral can create visible seams or slower flow.
- Premature sleep can recreate heaps.
- Render-only variation can accidentally re-enter authoritative dirty state.

## Alternatives considered

### Mandatory double-buffered flux for all liquids

Previously **Approved design**; now an approved retained candidate rather than a predetermined requirement.

### Finite travel budget assigned to free Water

**Explicitly rejected**. Equilibrium for Water must not depend on exhausted
movement history. A finite budget remains valid for an explicitly yielding
paste/slush descriptor whose intended behavior includes a stable slope.

### Equivalent full-cell swaps at rest

**Explicitly rejected**. They prevent stable sleep.

### Aggressive lateral freezing

**Explicitly rejected**. It produces sand-like liquid heaps.

### General fluid solver immediately

**Deferred / experimental**. It is unnecessary before the minimal invariants are proven.

### Independent liquid world

**Explicitly rejected**. Liquid quantity may use an optional field, but material/collision authority remains shared.

## Reversal/migration path

- Preserve the finite Godot budget as a selectable yielding-liquid behavior,
  not as Water's equilibrium rule or the native semantic oracle.
- Preserve normalized viscosity as material tuning without expanding phased
  kernel write ownership; long serial dispersion is not a native radius claim.
- Keep the phased native implementation behind the selectable backend; add buffered liquid only if required.
- Do not migrate saves until representation and versioning are approved.
- If the pairwise candidate fails behavior or performance acceptance, retain buffered liquid without reverting the broader phased cellular scheduler.
- If buffering fails cost acceptance, keep the validated one-worker pairwise semantics while scheduler work continues.

## Validation

- exact fixed-point conservation in every closed fixture;
- stable settled hash over a specified observation window;
- no equivalent-state transfers at rest;
- no sand-like heap in approved leveling fixtures;
- discrete Water reaches the two-cell wide-basin height bound within 360 ticks;
- mirrored and shifted fixtures expose directional or phase bias;
- ownership, activity, and storage boundaries introduce no mass loss or seam;
- one-worker and multiworker results match within the selected backend;
- render dithering produces no authoritative dirty state;
- active work declines after settling;
- candidate comparison records time, memory, copied/staged bytes, and known artifacts.

## Related decisions

- [ADR-002](ADR-002-double-buffered-tile-jobs.md)
- [ADR-003](ADR-003-godot-bridge-and-immutable-snapshots.md)
- [ADR-006](ADR-006-gpu-compute-deferral.md)
