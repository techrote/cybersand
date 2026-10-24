---
title: LCB-000 Gate B independent authoritative-state and storage handoff
status: Current
document-kind: evidence
scope: Bounded architecture/state contract for issue 213 from MAT-003PREPASS 204; not a Cell ABI migration, pressure implementation, solver selection, full MAT-003 acceptance or GEN-006 continuation codec
canonical-for: [lcb000-gate-b-bounded-storage-handoff]
last-reviewed: 2026-10-23
related-documents: [../research/mat-003prepass-state-inventory.md, ../research/mat-003prepass-gen006-handoff.md, ../research/mat-003prepass-epoch-consumers.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/level-saves-and-replay.md]
---

# LCB-000 / Gate B: independently bounded authoritative-state handoff

> **Later qualified evidence, 2026-10-23:** [Gate A acceptance and complete S2A performance reassessment](2026-10-23-lcb000-admission-gatea-gateb-refresh.md) records the separately successful 224/224 run 39876455400 (16 paired contrasts). The no-performance-data text below describes the **earlier failed first run** and is not current evidence status. The selected **bounded C64-E8 + optional solver-owned storage + authoritative gas-compartment table** recommendation is unchanged; no ABI/epoch/production selection follows.

**Decision, 2026-10-23: PASS for the minimum reversible LCB-001 storage architecture only.** Retain the exact current 64-bit, eight-byte, eight-aligned production Cell and its existing state semantics. New experimental liquid families receive **optional, versioned, bounded, solver-owned storage** plus a World-owned gas-compartment table as required. Do not assign production spare bits or change the cell ABI. This acceptance means an architecture contract is available for integrating a validated policy and preparing a candidate; it does **not** admit pressure implementation while other LCB-000 gates are blocked, freeze numeric payload widths or persistence, accept pressure solver physics, finish MAT-003PREPASS, or authorize GEN-006 continuation.

If the actual family implementation requires a representation that cannot be admitted through the proposed optional storage, stop and separately register a representation/migration decision with memory, correctness, platform, rollback and ABI evidence. Refusal is preferable to a silently lossy fallback.

## Reviewed source and evidence

- Main observed on 2026-10-23: **4caa2c3561f50d91a92ebab645db1bfcb3856d9c**; direct native source audit at **9012425e3bba62aa1fefb15ea5d7306f196b8da2**. [precision_storage.hpp](https://github.com/techrote/cybersand/blob/9012425e3bba62aa1fefb15ea5d7306f196b8da2/native/include/cybersand/precision_storage.hpp), [world.cpp](https://github.com/techrote/cybersand/blob/9012425e3bba62aa1fefb15ea5d7306f196b8da2/native/src/world.cpp), [world.hpp](https://github.com/techrote/cybersand/blob/9012425e3bba62aa1fefb15ea5d7306f196b8da2/native/include/cybersand/world.hpp); record the implementation-head source match again before candidate code.
- [#204](https://github.com/techrote/cybersand/issues/204), draft [PR #208](https://github.com/techrote/cybersand/pull/208), head **7b71fbb9e1b4286197fb948da3d34f3c3bd5f879**: registered S0 source/storage correctness, and S1 actual-native-World correctness at [run 39854839256](https://github.com/techrote/cybersand/actions/runs/39854839256). S1 reports 17/17 normal and 17/17 sanitized arms plus independent traces, natural E16 rollover in the bounded one-worker fixture, and distinct forced larger clears. This proves only those controls, not representation speed or continuation.
- Draft [PR #211](https://github.com/techrote/cybersand/pull/211), head **2b2a1dd64f16dc46d5e812b757de73f47df0fb2b**: full source S2F 24/24 contexts and 34 sealed observed/observer-off candidate builds with 68 untimed anchor executions at [run 39870102635](https://github.com/techrote/cybersand/actions/runs/39870102635). The **224-process S2A** schedule is *admitted for timing execution* by [run 39872073828](https://github.com/techrote/cybersand/actions/runs/39872073828) and registration commit **e40cc0d060f4a26ead664ad5c6787a7aafd53cfe**, not completed.
- First S2A [run 39875052969](https://github.com/techrote/cybersand/actions/runs/39875052969) failed launching process 1 because Actions extraction dropped executable mode. **0/16 contrasts and zero valid timing samples**; preserved failed artifact digest **fe25368f702485c03a4b0bd5298cc301681704ced804abf9cbdd6084e3578d67**. The workflow-only permission correction is present at the reviewed PR head; #204's latest recorded checkpoint says no successful fresh campaign has been reported. There is no timing-based storage winner. Do not run, modify or retry Codex's campaign in this review.
- [State inventory](https://github.com/techrote/cybersand/blob/7b71fbb9e1b4286197fb948da3d34f3c3bd5f879/docs/research/mat-003prepass-state-inventory.md), [epoch audit](https://github.com/techrote/cybersand/blob/7b71fbb9e1b4286197fb948da3d34f3c3bd5f879/docs/research/mat-003prepass-epoch-consumers.md) and [proposed GEN-006 handoff](https://github.com/techrote/cybersand/blob/7b71fbb9e1b4286197fb948da3d34f3c3bd5f879/docs/research/mat-003prepass-gen006-handoff.md) are intake facts plus proposals, not an implemented serializer. Pressure v5 source **7ef2aacfef3aef1fe9f26b6b85b4a5a083ba3a09** is an archived unqualified prototype, not native main.

## Existing Cell and field domains

| Field | Bits in production carrier | Supported source semantics |
|---|---:|---|
| material | 0–15 (16-bit storage) | Material enum is byte-underlying; current valid IDs 0–131 except 10. Catalogue version required. |
| state_a | 16–31 (16-bit storage) | Water integer quantity in 1..WaterPolicy.maximum() (mass bits 3–8); other public non-Water states currently bounded to a byte. Meaning is kernel-specific (e.g. cure, lifetime, corrosion, growth). |
| state_b | 32–39 (8-bit storage) | Water coherence countdown (policy 0–12); other kernel-specific burn, flag or state-carried material ID. |
| unassigned | 40–55 | No checked-in production semantics. Pressure v5 experimented with flow/overfill for Water or gas amount on Empty; this does not authorize reserving these bits. |
| update epoch | 56–63 | uint8 scheduling/support stamp, paired with World uint8 counter. Wrap clears all resident stamps; **not** durable mutation, incarnation or save identity. |

Required current behavior is preserved by default. Temperature is optional chunk-owned signed 16-bit state (missing means World ambient); it moves with whole-cell swaps but is not mass-mixed by partial Water transfer. Relevant source functions: World::write_cell / set / set_cell_state, move_cell (lines 2323–2416), transfer_water (2482–2565), update_water (2650–2723), update_rule_kernel, begin_tick (3524+), state_hash (4187+). Historical content_hash and state_hash must not be redefined to claim they include the optional payloads.

## LCB-001 authoritative field/owner matrix

**A** = authoritative for future results. **D** = derivable scratch only after exact dependency/phase qualification. **U** = numeric bounds/continuation not yet qualified; must refuse unknown configuration rather than silently dropping state.

| Class | Field and owner/lifetime | Status, units and operation |
|---|---|---|
| Common material | Per-cell material ID, state_a, state_b; per-chunk optional temperature; World catalogue/kernel/policy versions | **A, current.** Material/state units are per descriptor; temperature is signed game-unit integer, not a calibrated universal heat field. Copy/move/swap retain own tuple; converting material initializes product-specific state; source/sink reactions use declared rule ledger. |
| FreeMass Water | Per-cell integer fill state_a and coherence state_b; WaterPolicy mass bits, coherence, rest | **A, current.** Exact closed-system integer conservation across partial transfers, positive Water fill; reset Empty on zero. Transfer splits quantity and max-merges coherence. Water-specific adhesion, entrainment and reaction behavior remain material-owned. |
| Whole-cell Water experiment | Per-cell presence at maximum full-cell quantity, explicit alternate family policy and normalization receipt | **A, proposed.** No hidden fractional fill: refuse partial source or explicit setup-only conversion with per-cell signed deltas and separate before/after/source/sink ledger. Must still execute Water material chemistry and coupling. |
| Pressure/overfill | Per Water-cell visible fill plus overfill, signed directional flow/velocity, optional persistent wake/history | **A, proposed/U precision.** Overfill and velocity are future-affecting and follow Water on whole-cell moves; partial flows use a registered quantity, velocity and remainder split/merge law. Source v5 signed8 flow plus unsigned8 overfill is *illustrative only*. |
| Pressure gas | World-owned compartment ID/generation, ancestry, gas amount, vent/seal, free volume/topology; boundary-to-region index, including Empty-only chunks | **A, proposed/U schema.** Gas amount and stable identity are different fields. Distinct components merge amounts once, split deterministically with remainder, reseal/vent with explicit exchange ledger, invalidate stale topology. Do not key identity by equal amount or require resident nonempty liquid cells. |
| Pressure-derived head/cache | Per-tick solver scratch: head, pressure, acceleration and route cache | **D if fully reproducible from authoritative snapshot.** Previous offsets, smoothing volume, wake deadlines and history become **A** whenever they affect future results; either persist/version them or prove restart equality. Cache/dormancy must not suppress other families. |
| Inertial | Per owning material cell signed vx/vy or signed momentum, subcell remainders, damping/rounding parameters | **A, proposed/U widths.** No generic velocity imposed on all materials. Moves/swaps transfer cell-owned state, partial quantity changes momentum with a defined rule, cross-family displacement books intentionally dissipated impulse. Zero/reset on new product unless versioned conversion says otherwise. |
| Density and mixing | Material density, exchange rules and mask, interaction/transport precedence | **A, current config.** Swapping heterogeneous cells must atomically swap corresponding solver state and temperature. Foreign pressure-liquid neighbor is not automatically Empty/wall; boundaries, contact, momentum/quantity exchange and wake need family-aware law. |
| Reactions/phase | Product descriptor state, source/input quantity, temperature, owner rule, conversion/source-sink accounting | **A current, extension needed.** Existing Water+Salt to two Brine cells consumes one whole Water cell even if partially filled; #160 owns future quantity semantics. Declare each experimental reaction product default and signed delta; do not falsely report pure Water conservation across chemistry. |
| Scheduler | World attempted/completed tick, failed latch, per-cell epoch predicate, active/quiet blocks, interaction deadlines, pending ordered events and interest/pause state | **A for exact continuation** (some reconstruction possible only after proof). E8 wraps first at tick 256 and every 255 ticks; S1 E16 correctness is not a save-rebase proof. |
| Boundary/host | Native body masks, separate Rapier/actor owners, Depth layer clocks/links, generator/fixture execution state | **A but externally owned.** No automatic pressure-to-Rapier forces, body-state serialization or interlayer mass transport. Pin/refuse unqualified mixed-owner continuation. |
| Rendering | Snapshot/coverage/dither, cached derived pressure head, published visual state | **D only when isolated from future state;** reconstruct from authority; never store coverage as fluid quantity. |

## Required operation and failure semantics

1. **Before allocating a solver World:** validate catalogue and rule identities, signed ranges, per-material family/variant/parameter compatibility, required pressure gas/tail capacities and platform support. Prepare sidecar chunks, gas table, scratch and worker-domain bounds before ticking. On failure return typed refusal and leave the previous session unchanged.
2. **Move/swap/body displacement/density:** treat the material cell, its per-material quantity/momentum, temperature and sidecar as one logical ownership unit. Check both endpoints and preallocate destination capacity; update epoch, activity, mutation and dirty/wake witnesses. Do not leave ghost sidecars on an Empty vacancy.
3. **Partial Water split/merge:** conserve visible fill **plus** overfill and record transfer identity. Specify signed flow/momentum allocation and deterministic remainder behavior. A copied 16-bit extension on both source and destination duplicates state; do not do that. Temperature semantics must be explicitly current or newly versioned, not inferred from swap.
4. **Material conversion/reaction:** evaluate source and product material-specific rules, initialize product state and allowed sidecar defaults exactly, retire displaced gas/velocity, adjust source/sink ledger. The open #160 partial-cell case must be refused/limited or receive its own qualified converter.
5. **Gas topology:** stable pocket identity/generation survives amount changes, and amount survives independent of resident Empty chunk count. Merge unequal amounts once; split conservatively by a recorded allocation rule; disconnect/reseal does not recover stale IDs. Preserve trapped pockets and sealed gas testability inside LCB despite #45's **production vented-head** scope.
6. **Reset/rebuild:** destroy stale sidecars and compartments only when old World is retired; a new World has fresh identity and verified setup. Do not hot-switch a running liquid to another family or treat old CYSD1 as a live continuation image.
7. **Readback and hash:** provide applied per-material policy and parameters, source/binary/fixture identity, a new **versioned complete physical-state hash** for every future-affecting field (including Empty gas amount and compartment generations) and a separate scheduler/continuation digest. Retain historical content_hash/state_hash unchanged. Enforce identical registered observations under 1/4-worker execution.
8. **Capture/refusal:** experiment save may be setup/recipe + complete tick-boundary physical state + effective policy and explicitly reject unsupported continuation. Refuse unknown mandatory fields before installing a new World. No partially completed or failed-tick capture; gas/topology writes require quiescent committed preparation.

## Representation and memory comparison

| Candidate | Theoretical raw cell bytes | 1024 x 1024 full resident cell payload | 2048 x 2048 payload | Evidence status |
|---|---:|---:|---:|---|
| C64-E8 production | 8 | 8 MiB | 32 MiB | **Retained baseline**; real 8-byte/8-aligned. |
| Packed logical 72-bit | 9 | 9 MiB | 36 MiB | S0/S1 representation correctness, not selected for production; physical padding/alignment/access costs variant-dependent. |
| Packed logical 80-bit | 10 | 10 MiB | 40 MiB | Same evidence limit. |
| Naturally aligned word+tail | often 16-byte stride | 16 MiB | 64 MiB | Actual type/array stride must be recorded; 16 bytes is an arm-specific possibility, not universal. |
| C64 + eager 1B or 2B/cell tail | 8 + 1 or 2 logical bytes | 9 or 10 MiB | 36 or 40 MiB | S1 split correctness only; eager dense tails **do not** demonstrate sparse allocation savings. |
| C64 + optional solver-owned SoA | 8 + optional only when needed | **Unqualified actual occupancy** | **Unqualified** | **Recommended reversible architecture**, subject to memory ceiling/capacity and lifecycle proofs. |

These are cell/tail payload numbers, not whole-process peak RSS, not a proof that a pressure/inertial solver needs only 1 or 2 bytes per cell, and not performance rankings. Per 128 x 128 fully resident chunk, the C64 Cell array alone is 131,072 bytes; a dense 1B/2B tail adds 16,384/32,768 bytes. Temperature, optional gas/region index, metadata, allocator fragmentation, scheduler scratch, dormant caches and multi-depth-plane Worlds add to peak cost. A genuinely optional sidecar may consume less when sparsely active but incurs indexing/allocation costs that have **not** been measured. Admission requires budgets for 1024 x 1024 built-ins and all needed simultaneous Worlds; allocate before worker ticks, measure peak whole-process memory separately.

Changing C64 to E16 uses bits 48–63 and leaves eight unassigned bits; it overlaps saved prototype overfill/air bits 48–55. Preserving 40 base field bits + 16 prototype bits + epoch16 requires **72 logical bits or separate storage**, and *even that* says nothing about gas identity/topology. E16 does not automatically improve fluid behavior or settle epoch-clear latency; S2A's 256-tick sample contains the E8 clear but no natural E16 clear. Wider epochs need a separate clear-latency and long-horizon analysis.

## Experimental save/readback versus GEN-006

**LCB-001 minimum:** immutable exact setup ID/version + effective material-family/variant/WATER/transport/interaction policy; initial-state normalization/source-sink receipts; solver-owned complete state/quantity and gas topology; deterministic tick-boundary observations/full physical hash; capability/source/runtime IDs; typed refusal for unknown mandatory fields; safe new-World construction. A future LCB capture may be *rebuild-from-zero*, as labelled, rather than a claim of seamless continuation.

**GEN-006 durable continuation (separate #194 owner):** independently versioned semantic records for material-u16/state_a-u16/state_b-u8/nondefault temperature and approved optional field schemas; attempted/completed global and depth-plane ticks, activity/wake/deadline support, epoch rebase or stored equivalent, pending events, owner identity, chunk incarnation/mutation, generator old baseline/recipe, user same-value edits and Empty tombstones, finite fixture/emitter counters, interlayer exactly-once delivery, body-owner handoff or pin/refusal. Native Cell struct bytes, CYSD1 finite-level records and render snapshots are **not** this format. Unknown authoritative state pins or refuses eviction, never silently resets. #204/#194 must independently qualify restoration, reconciliation and streaming.

## Gate B acceptance and deferred register

**Accepted for the bounded admission:** unchanged C64-E8 production control; clear per-field material/solver/world owners; optional per-solver storage and World gas topology as the **minimal reversible design**; lifecycle/refusal/hash/save-readback requirements; no production/ABI winner inferred.

**Deferred to #200/#212 before implementation:** exact numeric widths/ranges/error bounds for overfill, signed velocity/momentum, subcell remainder, gas amount/volume/pressure and history; pressure pocket merge/split allocator budgets; Water/CellularYield interaction hooks; full-state hash implementation; capacity and worker-parity proofs; platform support. Any ambiguity is fail-closed, not permission to narrow or omit a required field.

**Deferred to full #204 and separate migration decision:** valid S2A paired data (none in the latest recorded run), S2B, wide-epoch cost, optional vs eager memory/peak RSS, wider representation selection, Windows/Wasm/Godot performance and production E16/E24/E32/cell stride migrations.

**Deferred to GEN-006 #194 and other owners:** exact paused-world continuation and epoch rebase; cross-boundary and same-value edit/tombstone semantics; procedural generation/chunk incarnation; Rapier/body and interlayer continuity. #160 owns phase-conversion quantity rules; #12 owns soliding; #45 owns *production* vented saturated head; #93/#94 production atmosphere/decompression remain unadmitted.

This Gate B handoff is **not** an all-gates LCB-000 PASS. LCB-001 pressure porting and irreversible state/schema freeze remain blocked under [#213](https://github.com/techrote/cybersand/issues/213).
