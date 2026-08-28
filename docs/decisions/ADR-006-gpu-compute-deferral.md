---
title: ADR-006 — GPU compute deferral
status: Approved design
scope: Deferral of GPU authority, acceptable future non-authoritative fields, synchronization constraints, experiment gate, and migration path
keywords: [ADR, GPU compute, deferred, terrain authority, collision, readback, non-authoritative field]
related-documents: [../systems/smoke-heat-pressure-roadmap.md, ADR-001-native-simulation-core.md, ADR-003-godot-bridge-and-immutable-snapshots.md]
last-reviewed: 2026-08-26
implementation-state: The decision to defer is approved; the project uses a rendering shader but contains no compute-shader simulation backend.
---

# ADR-006: GPU compute deferral

## At a glance

- Decision: do not make GPU compute authoritative for terrain or collision at this stage.
- **Current**: the Godot project uses GL Compatibility rendering and a palette fragment shader.
- **Deferred / experimental**: suitable GPU-resident non-authoritative fields may be benchmarked later.
- CPU-native SimulationCore remains authoritative for current planned cell state.
- Any GPU experiment must define synchronization, readback, determinism, and fallback.
- **Explicitly rejected**: premature GPU authority that requires gameplay to read unsynchronized state.
- Non-goal: prohibit GPU acceleration forever.

## Search anchors

why GPU compute deferred, can physics run on GPU, PhysX comparison, GPU terrain collision authority, readback cost, derived field

## Status

**Approved design** decision to defer.

GPU compute simulation itself is **Deferred / experimental**. No compute implementation exists.

## Context

Cell simulation appears parallel, but authoritative terrain interacts with gameplay collision, material queries, saves, deterministic replay, commands, and chunk streaming. Moving authority to the GPU can introduce readback latency, synchronization stalls, platform variation, and duplicate CPU/GPU state.

The first priority is a maintainable deterministic native CPU backend whose ownership and transfers are independently testable.

## Decision

- Keep authoritative terrain/material state in native SimulationCore/WorldStorage for the first production backend.
- Do not require GPU readback for ordinary authoritative gameplay ticks.
- Permit later isolated experiments for fields that can remain GPU-resident or tolerate clearly non-authoritative/derived behavior.
- Require an ADR before any GPU field becomes authoritative.
- Preserve RenderBridge as an immutable publication boundary rather than exposing simulation storage.
- Benchmark GPU work against CPU TileJob fixtures including transfer, synchronization, readback, memory, and determinism costs.

No GPU API, shader language, field format, cadence, or target hardware is selected.

## Consequences

### Positive

- One authoritative state is available for collision, replay, saves, and tests.
- CPU worker behavior is easier to make deterministic across machines.
- Godot presentation does not force per-tick synchronization with compute state.
- GPU experiments can target fields where residency provides real benefit.

### Negative

- Initial simulation scaling depends on CPU architecture and memory bandwidth.
- Some massively parallel visual/field work is postponed.
- A future GPU path may require separate platform and validation work.

### Risks

- Deferral could become permanent without explicit experiment criteria.
- A derived GPU field may accidentally influence authoritative decisions.
- Maintaining CPU and GPU implementations can create divergence if both become authorities.
- Readback costs can erase theoretical compute speed.

## Alternatives considered

### GPU-authoritative terrain immediately

**Explicitly rejected** for the current architecture. Collision, streaming, commands, replay, and saves are not ready for that authority boundary.

### Offload all material rules as a PhysX-like subsystem

**Deferred / experimental**. PhysX is not a direct architecture template for a custom deterministic cellular material world, and no compatible implementation evidence exists in this repository.

### Never use GPU compute

**Explicitly rejected** as a permanent prohibition. GPU-resident derived fields remain a valid future experiment.

### GPU rendering only

**Current**. The palette shader is presentation-only and does not simulate authority.

## Reversal/migration path

A future proposal can supersede this decision for a specific field if it:

1. names the field and authority level;
2. defines CPU/GPU ownership and synchronization;
3. avoids hidden duplicate authority;
4. defines deterministic or accepted bounded-error behavior;
5. defines collision/query/readback semantics;
6. supplies fallback and save/replay behavior;
7. outperforms the CPU reference under representative fixtures.

Migration should begin with non-authoritative derived output. Terrain authority requires a separate explicit decision.

## Validation

For any future experiment:

- measure compute, transfer, synchronization, and readback separately;
- compare current and 2× fixtures;
- verify authoritative CPU hashes remain unchanged for non-authoritative fields;
- prove rendering can consume results without mutable simulation reads;
- test device loss/fallback;
- document hardware/API constraints;
- reject the experiment if its integration requires hidden CPU/GPU duplication or gameplay stalls.

## Related decisions

- [ADR-001](ADR-001-native-simulation-core.md)
- [ADR-002](ADR-002-double-buffered-tile-jobs.md)
- [ADR-003](ADR-003-godot-bridge-and-immutable-snapshots.md)
