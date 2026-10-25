---
title: pressure_flow_v1 reference — corrected Water pressure family
status: Current
document-kind: design
scope: LCB-001 (#200) accepted main opt-in Water pressure_flow_v1/reference and hash v2/CYPS2 accounting — admission, solver-owned state, gas-compartment topology and identity, head snapshot, kernel laws, declared parameters and bounds, lifecycle per mutation path, physical-state hash, CYPS persistence, inspection APIs and known limits; branch-Current cached/dormant mechanisms (#201) and the comparison host (#202) have separate canonical owners
canonical-for: [pressure-flow-v1, gas-compartments, physical-state-hash, physical-state-persistence]
last-reviewed: 2026-10-25
related-documents: [lcb-pressure-inertial-handoff.md, liquid-state-transition-matrix.md, liquid-solver-family-policy.md, liquid-prepared-setup-and-receipts.md, ../audits/2026-10-24-lcb001-pressure-reference-publication.md, ../audits/2026-10-23-lcb-physics-mechanism-report.md, pressure-optimization.md]
---

# pressure_flow_v1 reference — corrected Water pressure family

## Implementation status and admission

**Current on main** since [PR #245](https://github.com/techrote/cybersand/pull/245)
merged at `03785c3`, with the shared native successor accepted through
[PR #246](../audits/2026-10-25-lcb001-shared-contract-acceptance.md) at
`ec58d919` on 2026-10-25. It is **opt-in**: only
a World whose applied liquid policy assigns Water to `pressure_flow_v1/reference`
runs it. The production default stays `freemass_v1` and every Current golden is
unchanged. The owner lifted the hold on the pressure reference and the inertial
family on 2026-10-24 (LCB continuous-execution instruction). Evidence, including
failed attempts and runtime identities, is in the
[publication record](../audits/2026-10-24-lcb001-pressure-reference-publication.md).

Accepted #246 main admits Water with variant `reference`. Current source on
`codex/lcb002-pressure-variants` also admits `cached` and `cached_dormant` with
the same pressure law. Its [optimization contract](pressure-optimization.md)
owns derived head/component caches, motion certificates, execution identity and
cost admission. Source-matched Windows/Linux scoped publication passed at
`8354e3a6` through bot append `d726bf34`; the full ready-PR matrix remains pending
([publication evidence](../audits/2026-10-25-lcb002-pressure-variants.md#source-matched-windowslinux-publication--2026-10-25)).
These variants are implementations of one family, not new physics.
All retain the optional overfill/flow/gas sidecar and World compartment table.
Other materials keep their kernels and default Water remains FreeMass.

Accepted main also supplies W-CY, explicit normalization, typed native
receipts and exact shared quantity accounting. Their construction, ownership,
codec freeze and qualification rules belong to
[native prepared setup and receipts](liquid-prepared-setup-and-receipts.md).
The hash v2 and CYPS2 sections describe **Current main after #246**. Hash v1
and CYPS1 belong to the historical #245 source/artifact contract; the current
decoder refuses CYPS1. The [original pressure publication record](../audits/2026-10-24-lcb001-pressure-reference-publication.md)
retains the exact #245 gates and runtime identities, and the
[shared acceptance audit](../audits/2026-10-25-lcb001-shared-contract-acceptance.md)
records the later accepted source, published bytes and complete final matrix.

This page retains the pressure laws; its characterization remains the recorded
`349d593` #245 evidence, not a rerun of that campaign on the residual delta.

What this page does **not** claim:
- #201's recorded target-OS headless publication is separate from full ready-PR acceptance and full-host qualification;
  see the [dated optimization evidence](../audits/2026-10-25-lcb002-pressure-variants.md);
- native W-CY and normalization do not supply a Godot normalization opt-in or
  complete #202 comparison host; the other host constructors still run defaults;
- Web/WASM execution has not been run.

## Source map

| Piece | Location |
|---|---|
| Admission (running build), optional family block | `LiquidPolicyBuild::running()` in [`liquid_solver_policy.hpp`](../../native/include/cybersand/liquid_solver_policy.hpp): Water × family 3 qualified for `reference` on accepted #246 main and for all three variants in current #201 branch source (`qualified_variants`); schema `pressure_flow_v1` v1 `{gas_enabled 0..1, atmospheric_head_rows 16..4096}`, optional |
| Public value types and declared constants | [`pressure_flow.hpp`](../../native/include/cybersand/pressure_flow.hpp): `PressureFlowParameters`, `PressureCellState`, `GasCompartmentSnapshot`, `GasHistoryRecord`, `GasLedger`, `PressureFlowLedger`, `PressureFlowDiagnostics`, `kAtmosphereLabel`, `kVacuumLabel` |
| World-owned state and scratch | [`world_pressure_state.inc`](../../native/src/world_pressure_state.inc): `World::PressureState` |
| Gas resolution, heads, kernel, hash, persistence | [`world_pressure.inc`](../../native/src/world_pressure.inc) |
| Shared quantity accounting, typed setup and receipts | [`world_quantity.inc`](../../native/src/world_quantity.inc); [canonical native contract](liquid-prepared-setup-and-receipts.md) |
| Hooks into Current paths | [`world.cpp`](../../native/src/world.cpp): `World::PressureChunk`, `ensure_chunk`, `write_cell(..., external)`, `set`, `move_cell`, `transfer_water` guard, `RuleKernel::Water` dispatch, `begin_tick`, `merge_job_effects`, `clear` |
| GDExtension | `CyberNativeCellWorld.get_physical_state_hash()`, `get_physical_state_hash_version()`, `inspect_gas_compartments()`, `inspect_pressure_cell()`, `get_pressure_flow_ledger()`, `get_liquid_run_receipt(setup)`; `water_experiment_observation` adds `water_visible`/`water_overfill`; `CyberDemoBridge.export_physical_state()`/`import_physical_state()`; `inspect_cell` adds `family_state` |
| Regressions | [`test_lcb_pressure.cpp`](../../native/tests/test_lcb_pressure.cpp) (18 native cases on accepted #246 main; 13 at accepted #245), [`test_lcb_pressure_reference.gd`](../../godot/tests/test_lcb_pressure_reference.gd) (publisher candidate regression) |
| Characterization harness | [`lcb_pressure_characterisation.cpp`](../../native/bench/lcb_pressure_characterisation.cpp) |

## Storage (Gate B handoff kept)

The C64-E8 cell is unchanged. A pressure World allocates, **per chunk, with the
chunk**, a `PressureChunk`:

| Array | Per cell | Kind |
|---|---|---|
| `cells` | `overfill u16`, `flow i16`, `gas u32` | **authoritative** |
| `head` | `i32` | derived scratch, rebuilt before every tick's kernels |
| `visit` | `u32` (pass stamp, region) | derived scratch of the gas pass |

The World owns the gas-compartment table (`PressureState`: id, generation,
ancestry ≤ 8, amount, volume, anchor, created tick, revision, gauge), a
64-entry retirement history, pressure/gas ledgers and fixed-capacity scratch
reserved at construction. A default World allocates no pressure state. The
shared quantity ledger exists in every native World; its fixed worker
scratch and measured storage cost are recorded in the
[accounting contract](liquid-prepared-setup-and-receipts.md#quantity-aggregates-producers-and-continuation).

Invariants (checked on restore, asserted by the lifecycle test):
- overfill only on a saturated Water cell (`state_a == maximum()`), ≤ `maximum()`;
- flow only on Water, `|flow| ≤ kFlowScale`;
- a gas label only on an Empty cell: `0` unresolved, `kVacuumLabel`,
  `kAtmosphereLabel`, or a live compartment id.

Residual source also bounds the monotonic gas-ID allocator: allocated identities
are `1..kVacuumLabel-1`; `next_id == kVacuumLabel` is an exhausted sentinel.
Creation and split share the checked allocator. They report capacity exhaustion
and quarantine the failed tick before assigning an unresolved/vacuum/atmosphere
label as a compartment ID. Restore accepts only the valid next-ID domain,
including the exhausted sentinel, even when the live table is empty. No ID wraps
or is reused; the sentinel is not an allocatable identity.

## Tick structure

```text
begin_tick → explosions → prepare_pressure_tick()      (serial, deterministic)
               1. resolve_gas_topology()   (gas_enabled only)
               2. compute_pressure_heads() (+ state-only wake of sleeping blocks)
          → active-chunk list → unchanged phased kernels → update_water_pressure()
```

Preparation runs before the active-chunk list, so its wakes take effect in the
same tick. Kernels read the immutable head snapshot plus their own rule radius
(x±2 reads, ±1 writes), exactly like the Current kernels, so 1 and 4 workers
produce identical physical states.

## Gas compartments

**Topology.** Every Empty region reachable from an unmasked Water cell's
4-neighbourhood, or carrying a live compartment label, is labelled with a
4-connected breadth-first fill. Body-masked cells and every non-Empty material
(walls, solids, foreign liquids) are impermeable; volume counts only Empty cells.
Before the fill, serial preparation materializes any unallocated chunks that
contain transient body-mask cells, using the ordinary bounded chunk-capacity
and failed-tick quarantine path. Only a mask-free **unallocated chunk is one
uniformly Empty node** of `chunk_size²` cells, so
topology never depends on allocation; a sealed region that includes one makes
it resident so every cell can carry its label. A region larger than
`kCompartmentVolumeLimit` (16 384 cells), or connected to a region that was, is
the vented atmosphere.

**Identity by label overlap, never by amount.** Old compartments are unioned with
the new regions their labelled cells fall in; each connected component then
resolves deterministically (components by smallest root, regions by lowest
`(y, x)` anchor):

| Component | Result |
|---|---|
| no old compartment, region holds unresolved/atmosphere cells | **create**: new id, generation 0, amount = unresolved + atmosphere cells (atmospheric for its free volume) |
| no old compartment, vacuum cells only | stays `kVacuumLabel`; no compartment |
| one old → one region | **continue**: same id/generation; volume recomputed; amount += atmosphere cells absorbed |
| many old → one region | **merge once**: survivor = lowest id; amount = sum; generation = max+1; ancestry = all parents; others retired `merged` |
| old → several regions | **split**: parents retired; new ids in anchor order; generation = max+1; volume-proportional floor shares, the integer remainder to the region holding the lowest `(y, x)` cell |
| any region is atmosphere | **vent**: every old compartment retired `vented`, its amount booked to `GasLedger.vented`; atmosphere cells relabelled `kAtmosphereLabel`; a later seal creates a **new** id |
| old compartment, no region | **collapse**: amount booked to `GasLedger.collapsed` |

Ids are monotonic and never reused. `GasLedger` closes exactly:
`amount_live + vented + collapsed == created + absorbed` (inspection reports
`closes`). Pressure is isothermal: gauge (mass units) =
`atmospheric_head_rows × maximum() × (amount − volume) / volume`, saturating at
±2³⁰. Suction (negative gauge) is allowed.

**Labels move with the gas.** `move_cell` swaps sidecars, so a vacated cell
inherits the displaced cell's label (a rising bubble keeps its identity). A
kernel-vacated cell (Water drained by a transfer, a kernel conversion to Empty)
is `kVacuumLabel`: it adds volume, never amount. A host paint/erase leaves
`0` (unresolved). This distinction prevents water-born voids from being created
as atmospheric gas (a defect found during development; see evidence).

**Masked labels at retirement (Current repair branch, acceptance pending).**
A transient body excludes an Empty cell from gas volume and overlap; it does
not replace the stored cell. After the identity reducer installs the next live
table, the existing resident relabel pass changes any unvisited positive label
absent from that table to `kVacuumLabel`. Still-live labels retain their
identity beneath the mask. The retired amount has already gone to successors
or the vent/collapse sink: clearing to unresolved would invent atmospheric
gas, and remapping to a successor would invent overlap. This sanitation
contributes to `labels_changed`, so a changed label prevents a gas fixed point.
The strict CYPS live-label check remains in force. The
[moving-body failure and repair record](../audits/2026-10-25-pressure-moving-mask-gas-retirement.md) qualifies the source, tests
and publication boundary.

**Phase convention.** Topology resolves at tick entry: inspection at completed
tick N reports the compartments resolved at the entry of tick N, i.e. after the
events indexed N−1. That matches the registered gas fixtures (merge first
observable at completed t2, split at t4, reseal at t10).

## Heads (immutable snapshot)

Per vertical Water run (unmasked; unallocated chunks break runs):
- top boundary: Empty → its compartment gauge (0 for atmosphere/vacuum/unresolved);
  a foreign liquid column → its known-density weight (`density × maximum / 1000`
  per cell; Water above adds its quantity) plus whatever bounds it; anything else
  is a **lid**;
- supported run (non-Empty below the floor): `P(y) = top + max(0, total − (floor − y) × maximum)`
  — transit-proof, from the run total and floor;
- unsupported (falling) run: `P = own quantity + top`;
- lidded runs: resolved per row by linear interpolation between the nearest known
  heads of the same contiguous Water row segment (one side copies; no side keeps
  the compacted column value).

Heads saturate at ±2²⁸ mass units. The row pass also wakes any sleeping block
holding a Water cell whose kernel stencil gradient exceeds the start band, or a
cell with nonzero flow/overfill. This rule depends only on the current state, so
it survives persistence exactly.

## Kernel (`update_water_pressure`)

Stages 1, 2, 4, 5 of the [material hooks](liquid-solver-family-policy.md#material-hooks-versus-motion-gate-c-correction-2026-10-23)
are unchanged: pair chemistry runs before dispatch, the coherence countdown is
kept and suppresses lateral motion, `mix_after_motion` receives the real moved
quantity, body-mask contact uses `record_transient_contact`, and identity stays
`Material::Water`. Stage 3 is replaced:

1. **Gravity:** down, then the two diagonals; into Water only to visible capacity
   (never overfill), otherwise `try_move` (whole tuple and sidecar).
2. **Overfill relief/relay:** overfill rises into unsaturated Water or creates
   Water in Empty above; a saturated column relays it whole (receiver not
   epoch-marked, so a bottom-up scan reaches the surface in one tick); under a lid
   it spreads sideways toward less overfill when the difference is ≥ 2.
3. **Adhesion film:** kept only for a **resting** thin cell (flow 0).
4. **Velocity:** `flow += gradient × kAccelNumerator / maximum` (deterministic
   dither), where `gradient = (h(x−2)+h(x−1)−h(x+1)−h(x+2))/2`. A sample at x±2 is
   used **only** if both faces toward it are open (Water or Empty); a wall,
   foreign liquid or body mask is a closed face that reflects the cell's own head.
   Overfill adds `kOverfillStiffnessRows × maximum` per unit (v1: 0).
   Start dead band 128/255 of a row (static friction above integer-gas gauge
   noise), moving band 10/255; `kRetain` 256/256 and `kFriction` 0 (momentum is
   lost only through mass-weighted merges and contacts).
5. **Surface skin:** a resting top-of-run cell relaxes sub-row steps with the
   FreeMass ¾ rule and `tolerance()`; saturated cells and overfill never move here.
6. **Flux:** `|flow| × quantity / kFlowScale` (dither) toward `sign(flow)`;
   Empty receives a new cell carrying this tick's **updated** velocity (front ≤ 1
   cell/tick, receiver epoch-marked); Water receives visible then overfill
   capacity with a mass-weighted velocity merge whose truncation remainder is
   booked (`PressureFlowLedger.flow_remainder`). A source with Water directly above
   never empties laterally (no interior voids). A closed face zeroes flow and books
   `contact_loss`.

Every direct authoritative write is witnessed like `transfer_water` (job effects
or serial dirty/wake/discovery). Per-job ledgers merge after the phase barrier;
there are no shared counters.

Partial transfers propagate the maximum source/receiver coherence, capturing
source coherence before an emptied tuple is retired. Every successful quantity
transfer calls the unchanged material post-motion hook with its actual moved
quantity, including surface skin and overfill relief/relay; the hook itself
determines whether that motion qualifies for grain carrying. Reaction products
start at family defaults even when a product retains Water identity. Same-material
coherence countdowns retain family state. Repainting an identical visible tuple
still publishes dirty/wake/discovery witnesses if its pressure state changed.

## Declared parameters (v1)

| Parameter | Value | Kind |
|---|---|---|
| `gas_enabled` | 1 | request block (0..1) |
| `atmospheric_head_rows` (p_atm) | 32 | request block (16..4096) |
| `kFlowScale` | 1024 | fixed |
| `kAccelNumerator` / `kAccelDenominator` | 3 / 1 | fixed |
| `kRetain` / `kFriction` | 256 / 0 | fixed |
| start / moving dead band | 128 / 10 (per 255 of a row) | fixed, scaled by `maximum()` |
| overfill limit | `maximum()` | fixed |
| `kOverfillStiffnessRows` | 0 | fixed |
| compartment volume limit / capacity / history | 16 384 / 1024 / 64 | fixed |

These are **Proposed** values chosen with the characterization harness, not
owner-frozen. p_atm = 32 keeps the gauge noise of one integer amount unit in a
≥ 108-cell pocket (≈ 0.3 rows) below the start band, so the registered split
U-trap stays exactly at rest. The receipt (`family_parameters.pressure_flow_v1`)
records them.

## Lifecycle per mutation path

| Path | Result |
|---|---|
| gravity whole move, density swap, `relocate_stored_cell`, player Water field | `move_cell` swaps sidecars atomically; overfill/flow follow Water; vacated cell inherits the gas label |
| gravity into Water, lateral flux, relief, skin | direct writes with explicit quantity accounting (overfill first out, visible first in) |
| kernel material change (reaction, Steam/Ice, product) | `write_cell` resets the sidecar; overfill booked `overfill_converted`; a kernel-made Empty is vacuum |
| host paint/fill/erase (`set`, `set_cell_state`, MicroScenario events, explosions) | external reset; overfill booked `overfill_external`; erasing Empty keeps its gas label |
| `transfer_water` (FreeMass) | throws `logic_error` in a pressure World: no silent fallback |
| `clear()` / reset | gas table, ids, ledgers cleared with the chunks |
| CYSD1 export/import | lossy level format; import always reconstructs on default families (never a continuation) |
| CYPS save/restore | exact continuation (below) |

## Physical-state hash v2

`World::physical_state_hash()` (`kPhysicalStateHashVersion = 2`, 64-bit FNV-1a,
16 hex digits through GDExtension) covers the tick clock, epoch, interest/core
regions, physics configuration (chunk/scheduler geometry, interaction, Water,
transport, adhesion, powder-exchange suppression and Mercury-viscosity override),
the policy hash, pressure parameters, pending events,
body-mask occupancy, every non-default cell (coordinates, material, states,
epoch for non-Empty, temperature, overfill, flow, gas label), every active or
deadline-bearing activity block, the full gas table and the exact shared quantity
ledger, including its construction binding and material cell counts. Only non-default cell content
is hashed, so an allocated all-Empty inactive chunk equals an unallocated one.
`content_hash()` and `state_hash()` keep their historical definitions.
Version 1 belongs to the source-matched #245 record; that historical hash is not
silently reinterpreted. The hash includes policy/variant and clock, so #201
equivalence must define its comparison projection rather than demand equal raw
hashes across variants or across ticks.

### Liquid comparison projections

**Current in unmerged `codex/lcb002-pressure-variants` source:**
`World::liquid_comparison_hash(LiquidStateProjection)` supplies two explicitly
named diagnostic observations. Each prefixes its own domain, then binds the
underlying physical-hash version and its declared field stream. The original
physical-hash v2 stream and CYPS2 bytes are unchanged by this extraction.

| Domain | Included state and explicit exclusions | Intended comparison |
|---|---|---|
| `lcb.pressure-variant-equivalence.v1` | Complete physical-hash fields, with only each `pressure_flow_v1` implementation variant normalized to `reference` in the canonical policy. Other assignments, catalogue/capability digests, all parameter blocks, clocks, epochs, activity, deadlines, construction bindings, quantity accounting and all authority remain significant. Derived caches and their diagnostics have no authority in this stream. | Reference/cached/dormant at the **same completed tick**, with separately compared gas and momentum ledgers/history where outside the complete hash. |
| `lcb.quiescent-physical-content.v1` | The same physical authority/configuration and normalized policy, excluding tick/completed-tick clocks, update/cell epochs, activity/quiet aging and cumulative quantity source/sink/event counters. Retains failure state, selected/applied regions, future event/deadline obligations, original construction bindings/baselines, current quantities/populations, exact material/state/temperature tuples, overfill/flow/gas labels and the full gas table. | A cross-tick static-content diagnostic. It is **not a future rest certificate** and cannot authorize skipped work. |

Unknown projection identities refuse. Observations allocate only on the caller's
inspection path, never in worker kernels; no World state changes during capture.
The comparison policy is built from the canonical encoder, not a policy-hash
mask: changing family, material or parameter remains visible. Future authoritative
family extensions must enter each applicable projection or remain unsupported.
The quiescent diagnostic does not prove the absence of future chemistry,
stochastic, cadence, body-contact or remote pressure work. Dormancy needs its
separate positive proof and invalidation before every reuse.

The initial 2026-10-24 local LLVM-MinGW 20260826/Clang 23.1.0 C++20 `-O1`
projection checkpoint passes **128/128** native cases in 27.297 s, including
two new groups. A supported static pool remains constant through 300 ticks and
epoch rollover only in the quiescent observation; complete/same-tick hashes
change. Tests retain thermal, mask, future-event and adhesion distinctions,
exact restore, variant-only canonical normalization and family/parameter
distinctions. All 120 Python LCB tests and generated-contract checks pass.
Separately compiled source `9e91a9f7` and the projection delta produce identical
original physical hashes and SHA-256 digests of CYPS bytes at all eight
registered default/pressure fixture observations, including masked and thermal
state. Commands, complete input fences, executables and logs are retained under
`C:/Users/_/.codex/tmp/lcb201-projections/validation.json`. This is local source
proof for the projection extraction; caching, dormancy, new runtime publication
and platform/full-PR acceptance are not credited by it.

## Persistence (CYPS v2)

`World::save_physical_state()` / `World::restore_physical_state(execution, bytes)`:
little-endian "CYPS" v2 — physics configuration and policy envelope, clock and
regions, pending events, every chunk (blocks, cells with epochs, temperatures,
sidecars), the exact shared quantity ledger/construction binding, gas table,
history and pressure ledgers — followed by a SHA-256 of the body.
Restore checks the digest first, decodes the policy with the running build, then
checks the documented state ranges and invariants before returning a new World; any failure
throws `std::invalid_argument` (or `LiquidPolicyRefused`) and the caller's World
is untouched. Execution settings (workers, capacities) come from the caller;
physics settings from the payload, including physics-changing diagnostic
overrides. Restore checks the complete gas conservation equation with checked
sums as well as agreement between the table and `amount_live`; a valid digest
does not admit a contradictory ledger. Transient body masks are host-owned and not
saved; settled discovery must be disabled. Mask-free fixtures continue
bit-identically (physical and state hash, including at a different worker count).
A host using bodies must separately restore the same transient-mask region and
sampled masks before claiming exact continuation. Native CYPS alone does not
restore a Rapier owner or its future inputs; complete adapter body restoration
remains #202/#203 work.
Restore also checks native quantity schema, source/sink roles and quanta,
aggregate closure, prepared Water count/mass consistency and restored authority.
Pending events reuse ordinary queue admission, including radius, capacity and
the radius-plus-two coordinate margin. Direct rectangle quantity readback
rejects negative dimensions and overflowing inclusive endpoints; zero-area
reads remain zero, and valid final cells at `INT64_MAX` need no overflowing
exclusive endpoint. These accepted #246 fixes retain ordinary event continuation,
worker parity and quantity accounting; their earlier failures and validation
are in the [residual audit](../audits/2026-10-24-lcb001-residual-shared-contract.md#publication-attempt-1-stopped-for-coordinate-boundary-defects).
On accepted main, historical CYPS1 explicitly refuses as an unknown format; #245's saved format-1
evidence remains historical. The owner-requested narrow native codec freeze is
described in the [shared contract](liquid-prepared-setup-and-receipts.md); it is
not a production Cell/global ABI or full application replay freeze.

## Characterization (screens, not admission criteria)

Native harness at repaired source `349d593`, registered geometries, 1 worker,
2026-10-24 (identities and retained earlier results in the #245 evidence record;
not rerun for the residual native setup/accounting delta):

| Screen | Threshold | Current | pressure_flow_v1/reference |
|---|---|---|---|
| depth response t240 | ≥ 1.5 | 1.06 | **1.69** |
| depth-48/96/160 front t240 | depth-160 ≥ 213 | 67/70/71 | **130/221/220** |
| depth-48/96/160 retained t1800 | depth-160 ≤ 0.50 | 0.839/0.841/0.851 | **0.619/0.437/0.371** |
| vented two-limb \|difference\| t2400 | ≤ 12 rows | 120 | **9** (signed gap −9; first within ±12 at t1026, subsequent maximum 12) |
| narrow passage t2400 | ≤ 60 rows | 120 | **43** |
| sealed two-limb | ±2 rows of the isothermal law; differs from vented | 120 | differs; levels 152/175, gap 23 at t2400; unsettled, no sealed-law acceptance |

Quantity (visible + overfill) was exact in all twelve runs. Earlier pre-repair
values, including the 4.9-row sealed-law residual, remain historical in the
[evidence record](../audits/2026-10-24-lcb001-pressure-reference-publication.md);
they do not describe source `349d593`.

## Known limits

- **Reference cost.** Preparation scans every resident chunk each tick (gas seeds, relabel,
  column and row passes): the reference is O(resident cells). A 1024² dam runs at
  roughly 1.5× Current single-threaded in the source-qualified harness above.
  The [#201 branch contract](pressure-optimization.md) separately owns derived
  caches, retained global gas work and complete-tick cost evidence.
- **Dormancy is Current in #201 branch source; acceptance is pending.** Its
  [motion certificate](pressure-optimization.md#motion-certificates-preserve-ordinary-obligations) preserves body
  contact reports even when a failed gravity/diagonal probe moves no Water:
  those reports feed actual body coupling. It must preserve material stages,
  prove future motion is a no-op rather than freeze nonzero flow, and demonstrate
  savings beyond ordinary block sleep while unrelated material work continues.
  This grants no #12 discovery or cell↔Rapier skip authority.
- Vented two-limb sloshes (no proportional damping): it stays within the screen
  but overshoots (−9 rows at t2400).
- Hidden overfill remains in long lidded passages until diffusion drains it to a
  free surface.
- Gravity ignores gas pressure: falling Water can fill a sealed pocket and
  collapse it (booked, never silent).
- A component that vents and seals in the same tick recreates its sealed part at
  atmospheric amount (declared simplification).
