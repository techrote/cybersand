---
title: pressure_flow_v1 reference — corrected Water pressure family
status: Current
document-kind: design
scope: LCB-001 (#200) implemented opt-in Water family pressure_flow_v1/reference — admission, solver-owned state, gas-compartment topology and identity, head snapshot, kernel laws, declared parameters and bounds, lifecycle per mutation path, physical-state hash, CYPS persistence, inspection APIs and known limits; cached/dormant variants (#201) and the comparison host (#202) are not here
canonical-for: [pressure-flow-v1, gas-compartments, physical-state-hash, physical-state-persistence]
last-reviewed: 2026-10-24
related-documents: [lcb-pressure-inertial-handoff.md, liquid-state-transition-matrix.md, liquid-solver-family-policy.md, ../audits/2026-10-24-lcb001-pressure-reference-publication.md, ../audits/2026-10-23-lcb-physics-mechanism-report.md]
---

# pressure_flow_v1 reference — corrected Water pressure family

## Status

**Current** in source on branch `claude/lcb001-pressure-reference` (LCB-001
[#200](https://github.com/techrote/cybersand/issues/200)). It is **opt-in**: only
a World whose applied liquid policy assigns Water to `pressure_flow_v1/reference`
runs it. The production default stays `freemass_v1` and every Current golden is
unchanged. The owner lifted the hold on the pressure reference and the inertial
family on 2026-10-24 (LCB continuous-execution instruction). Evidence, including
failed attempts and runtime identities, is in the
[publication record](../audits/2026-10-24-lcb001-pressure-reference-publication.md).

What this page does **not** claim:
- `cached` and `cached_dormant` (#201) are refused (`family_unavailable`);
- whole-cell Water `cellular_yield_v1` (W-CY), `water-normalize-v1` and
  `normalization_required` are not implemented yet (remaining #200 scope);
- the comparison host and the other #202 constructors still run defaults;
- Web/WASM execution has not been run.

## Source map

| Piece | Location |
|---|---|
| Admission (running build), optional family block | `LiquidPolicyBuild::running()` in [`liquid_solver_policy.hpp`](../../native/include/cybersand/liquid_solver_policy.hpp): Water × family 3 qualified for variant `reference` only (`qualified_variants`); schema `pressure_flow_v1` v1 `{gas_enabled 0..1, atmospheric_head_rows 16..4096}`, optional |
| Public value types and declared constants | [`pressure_flow.hpp`](../../native/include/cybersand/pressure_flow.hpp): `PressureFlowParameters`, `PressureCellState`, `GasCompartmentSnapshot`, `GasHistoryRecord`, `GasLedger`, `PressureFlowLedger`, `PressureFlowDiagnostics`, `kAtmosphereLabel`, `kVacuumLabel` |
| World-owned state and scratch | [`world_pressure_state.inc`](../../native/src/world_pressure_state.inc): `World::PressureState` |
| Gas resolution, heads, kernel, hash, persistence | [`world_pressure.inc`](../../native/src/world_pressure.inc) |
| Hooks into Current paths | [`world.cpp`](../../native/src/world.cpp): `World::PressureChunk`, `ensure_chunk`, `write_cell(..., external)`, `set`, `move_cell`, `transfer_water` guard, `RuleKernel::Water` dispatch, `begin_tick`, `merge_job_effects`, `clear` |
| GDExtension | `CyberNativeCellWorld.get_physical_state_hash()`, `get_physical_state_hash_version()`, `inspect_gas_compartments()`, `inspect_pressure_cell()`, `get_pressure_flow_ledger()`, `get_liquid_run_receipt(setup)`; `water_experiment_observation` adds `water_visible`/`water_overfill`; `CyberDemoBridge.export_physical_state()`/`import_physical_state()`; `inspect_cell` adds `family_state` |
| Regressions | [`test_lcb_pressure.cpp`](../../native/tests/test_lcb_pressure.cpp) (13 native cases), [`test_lcb_pressure_reference.gd`](../../godot/tests/test_lcb_pressure_reference.gd) (publisher candidate regression) |
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
64-entry retirement history, exact ledgers and fixed-capacity scratch reserved
at construction. A default World allocates none of this.

Invariants (checked on restore, asserted by the lifecycle test):
- overfill only on a saturated Water cell (`state_a == maximum()`), ≤ `maximum()`;
- flow only on Water, `|flow| ≤ kFlowScale`;
- a gas label only on an Empty cell: `0` unresolved, `kVacuumLabel`,
  `kAtmosphereLabel`, or a live compartment id.

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

## Physical-state hash v1

`World::physical_state_hash()` (`kPhysicalStateHashVersion = 1`, 64-bit FNV-1a,
16 hex digits through GDExtension) covers the tick clock, epoch, interest/core
regions, physics configuration (chunk/scheduler geometry, interaction, Water,
transport, adhesion, powder-exchange suppression and Mercury-viscosity override),
the policy hash, pressure parameters, pending events,
body-mask occupancy, every non-default cell (coordinates, material, states,
epoch for non-Empty, temperature, overfill, flow, gas label), every active or
deadline-bearing activity block, and the full gas table. Only non-default content
is hashed, so an allocated all-Empty inactive chunk equals an unallocated one.
`content_hash()` and `state_hash()` keep their historical definitions.

## Persistence (CYPS v1)

`World::save_physical_state()` / `World::restore_physical_state(execution, bytes)`:
little-endian "CYPS" v1 — physics configuration and policy envelope, clock and
regions, pending events, every chunk (blocks, cells with epochs, temperatures,
sidecars), the gas table, history and ledgers — followed by a SHA-256 of the body.
Restore checks the digest first, decodes the policy with the running build, then
range-checks every value and invariant before returning a new World; any failure
throws `std::invalid_argument` (or `LiquidPolicyRefused`) and the caller's World
is untouched. Execution settings (workers, capacities) come from the caller;
physics settings from the payload, including physics-changing diagnostic
overrides. Restore checks the complete gas conservation equation with checked
sums as well as agreement between the table and `amount_live`; a valid digest
does not admit a contradictory ledger. Transient body masks are host-owned and not
saved; settled discovery must be disabled. A restored World continues
bit-identically (physical and state hash, including at a different worker count).

## Characterization (screens, not admission criteria)

Native harness at repaired source `349d593`, registered geometries, 1 worker,
2026-10-24 (identities and retained earlier results in the evidence record):

| Screen | Threshold | Current | pressure_flow_v1/reference |
|---|---|---|---|
| depth response t240 | ≥ 1.5 | 1.06 | **1.69** |
| depth-160 front t240 | ≥ 213 | 71 | **220** |
| depth-160 retained t1800 | ≤ 0.50 | 0.851 | **0.371** |
| vented two-limb \|difference\| t2400 | ≤ 12 rows | 120 | **9** (≤ 12 from t1026; subsequent maximum 12) |
| narrow passage t2400 | ≤ 60 rows | 120 | **43** |
| sealed two-limb | ±2 rows of the isothermal law; differs from vented | 120 | differs; levels 152/175, gap 23 at t2400; still settling, no sealed-law acceptance |

Quantity (visible + overfill) was exact in every run.

## Known limits

- **Cost.** Preparation scans every resident chunk each tick (gas seeds, relabel,
  column and row passes): the reference is O(resident cells). A 1024² dam runs at
  roughly 1.5× Current single-threaded in the harness. Incremental caches and
  dormancy are #201.
- Vented two-limb sloshes (no proportional damping): it stays within the screen
  but overshoots (−9 rows at t2400).
- Hidden overfill remains in long lidded passages until diffusion drains it to a
  free surface.
- Gravity ignores gas pressure: falling Water can fill a sealed pocket and
  collapse it (booked, never silent).
- A component that vents and seals in the same tick recreates its sealed part at
  atmospheric amount (declared simplification).
