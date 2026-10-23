---
title: Liquid material and solver state-transition matrix
status: Planned
document-kind: design
scope: Authoritative operation-by-operation transition rules for Current liquids and the proposed LCB families (FreeMass, whole-cell CellularYield Water, pressure_flow_v1, inertial_cellular_v1) — owner, state moved, conservation/source-sink, invalidation and family applicability; consumes the bounded Gate B storage handoff; no Cell layout choice
canonical-for: [liquid-state-transition-matrix]
last-reviewed: 2026-10-23
related-documents: [liquid-solver-family-policy.md, lcb-pressure-inertial-handoff.md, data-ownership-and-lifetimes.md, ../audits/2026-10-23-lcb-physics-mechanism-report.md, ../systems/water-design.md]
---

# Liquid material and solver state-transition matrix

## Status and inputs

- **Current rows** describe source at `9012425`, unchanged at main `4caa2c3`.
- **Proposed rows** are the contract that #200 (policy, `pressure_flow_v1`,
  whole-cell Water) and #212 (`inertial_cellular_v1`) must implement and
  test.
- **Storage** follows the [Gate B bounded handoff](../audits/2026-10-23-lcb000-gate-b-state-handoff.md) (accepted; [refresh](../audits/2026-10-23-lcb000-admission-gatea-gateb-refresh.md)):
  - the C64-E8 Cell is unchanged;
  - family state lives in **optional, versioned, solver-owned storage**, plus
    a **World-owned gas-compartment table**;
  - no spare-bit allocation;
  - numeric widths are frozen by #200/#212 before code.
- **Not a schema or layout decision.**

**Family columns:**

| Column | Meaning |
|---|---|
| FM | `freemass_v1` (Current Water) |
| CY | `cellular_yield_v1` (Current other liquids; experimental whole-cell Water in W-CY) |
| PF | `pressure_flow_v1` (Water only, v1) |
| IN | `inertial_cellular_v1` (Water whole-cell v1; Brine) |

**Common state tuple** (Current, moves as one unit): material, `state_a`,
`state_b`, and optional chunk temperature. Optional family state is:

| Family | Optional state |
|---|---|
| PF | overfill quantity, signed flow/velocity, optional wake/history |
| IN | signed vx/vy (or momentum), subcell accumulators |
| World gas table | per compartment: id, generation, ancestry, amount, free volume, vent/seal state, topology revision |

**Cross-cutting rules** applying to every row:
- **R1** Optional family state belongs to exactly one cell. It moves with that
  cell and is **retired** (never left behind or duplicated) when the cell
  becomes Empty or another material.
- **R2** A product or newly painted cell starts at its own family's default
  state.
- **R3** Every write updates epoch, activity/wake, dirty and mutation
  witnesses as `move_cell`/`write_cell` do today.
- **R4** Every future-affecting field enters the versioned complete
  physical-state hash. Historical `content_hash`/`state_hash` stay as they are.

## 1. Motion into Empty

| Operation | Owner | State moved | Conservation | Invalidation / wake | FM | CY | PF | IN |
|---|---|---|---|---|---|---|---|---|
| Gravity/diagonal move of a whole cell into Empty | World kernel (`try_move` L2446 → `move_cell` L2323) | whole tuple + optional state | exact per cell | both endpoints' blocks woken; PF: column/run summaries dirty | Current (when not merging) | Current | Proposed: cell + overfill + velocity move together | Proposed: velocity and accumulator move with the cell |
| Lateral move into Empty | kernel | same | exact | same | via `transfer_water` partial (see §4) | Current: whole cell, viscosity roll only for yielding kernels | Proposed: flux law, quantity moves, remainder stays | Proposed: travel from the accumulator; one destination per tick within the bounded radius |
| Move refused by body mask | World (`transient_obstacle_at`) | none | exact | contact recorded (`record_transient_contact`) | Current | Current | must record the same contact and must not push state into the mask | same; impulse into a mask is dissipated and booked |

## 2. Same-liquid transfer and merge

| Operation | Owner | State | Conservation | Invalidation | FM | CY | PF | IN |
|---|---|---|---|---|---|---|---|---|
| Fall onto same-liquid with capacity | Water: `transfer_water` (L2481); others: no merge | quantity | exact integer (Water) | both endpoints | Current: merges up to capacity; `state_b` = max | Current: none (whole cells only) | Proposed: visible + overfill conserved; velocities mixed by a registered mass-weighted rule with deterministic rounding and a booked rounding remainder | Proposed (whole-cell): no merge; momentum transfer through §5 |
| Lateral relaxation between same-liquid neighbours | Water `level_with` (L2698) | quantity | exact | endpoints | Current ¾ rule, `tolerance()` | none | Proposed: head-gradient flux replaces it | none (motion is velocity-driven) |

## 3. Different-liquid displacement and density exchange

| Operation | Owner | State | Conservation | Invalidation | FM | CY | PF | IN |
|---|---|---|---|---|---|---|---|---|
| Vertical density swap | `can_density_exchange` (vertical delta ≠ 0) + `move_cell(swap)` | **both** whole tuples + both cells' optional state | exact for both tuples (tested: `test_lcb_physics_contracts.gd::ownership`) | both endpoints; PF summaries of the affected run invalidated before reuse | Current | Current | Proposed: overfill stays with its Water cell; the foreign cell is a density boundary | Proposed: velocity stays with its cell; no velocity written into a foreign family |
| Sideways contact with a foreign liquid | none today (no sideways swap) | — | — | — | Current: blocked | Current: blocked | Proposed: foreign liquid = known-density boundary, no head propagation through it | Proposed: impulse stops; dissipation booked |

## 4. Partial versus whole-cell quantity

| Operation | Owner | Rule |
|---|---|---|
| FreeMass partial transfer | `transfer_water` | Current: `amount = min(requested, source, capacity)`. Zero source → Empty; Empty destination → Water. |
| Whole-cell Water (W-CY, IN v1) | family | Proposed: every Water cell holds exactly `maximum()`. Fractional setup input is refused or explicitly normalized (`water-normalize-v1`: up when `2·m ≥ maximum()`, signed per-cell delta, setup-only ledger). |
| Overfill (PF) | family | Proposed: Water can hold `maximum()` + overfill. Overfill counts in every quantity observation and in the ledger, is never rendered as an extra cell, and never exceeds the frozen bound. Refusal is preferred to clamping. |
| Observation of quantity | host | `water_integer` for FM/PF (visible + overfill for PF); `maximum()` per cell for whole-cell families |

## 5. Velocity and momentum (IN; PF flow)

| Operation | Rule (Proposed) |
|---|---|
| Gravity | adds a fixed-point increment to vy each tick, saturating at the frozen bound |
| Travel | accumulator += velocity; the cell moves one step per whole unit, re-checking each target. A blocked target leaves the cell in place, zeroes that velocity component and books the lost impulse. |
| Collision with Wall/solid/body mask | the normal component is zeroed (no bounce in v1) and the impulse is booked as dissipation; no Rapier force is applied |
| Same-family collision | each cell's velocity is preserved (no exchange in v1). A blocked cell waits. |
| Displacing a lighter liquid (vertical swap) | the mover keeps its velocity minus a registered drag fraction, booked; the displaced cell keeps its own (or zero) state |
| Damping | per-tick multiplicative fixed-point damping (family parameter) plus a rest threshold that zeroes residual velocity |
| Split/merge (PF partial flux) | outgoing flux carries the source's updated velocity (#200 defect fix); the receiver mass-weights it; rounding remainders are booked |
| Rest | zero velocity and an empty accumulator ⇒ the cell is eligible to sleep under the ordinary block rules |

## 6. Reactions and material conversion

| Operation | Owner | Rule |
|---|---|---|
| Pair reaction (any family) | generic pre-kernel chemistry (L2797) | **Current:** both products written at descriptor defaults (Water products at `maximum()`). **Proposed:** unchanged chemistry; optional state of both consumed cells is retired; products start at their family defaults (R2); a signed per-species ledger entry is booked (consumed Water mass, created cells). |
| Phase change Water↔Steam/Ice | Steam/Ice kernels (L2846, L3142) | Current: Steam expiry → Water at `maximum()` (#160 amplification). PR #162 would preserve quantity; it is unmerged, so LCB books the delta and does not assume it. |
| Kernel lifecycle (Oil burn, Cement cure, Molten Glass cooling) | material kernel | unchanged under every admitted family; specialized liquids stay on their default family |

## 7. Painting, erasing, sources and sinks

| Operation | Owner | Rule |
|---|---|---|
| Paint/fill | host → `set_cell_state`/`water_experiment_fill_rect` | Current: Water fill writes the policy-scaled mass; rectangles write descriptor defaults. Proposed: the painted cell gets its material's applied family default state; whole-cell Water families paint `maximum()` only. |
| Erase | host | the cell becomes Empty; optional state is retired; a ledgered sink |
| Scheduled source/sink | MicroScenario events | ledgered exactly (`water_ledger`, regression `_ledger_closure`); PF overfill and IN state are included in the Water sink |
| Explosions / tools | native queue | material removal is a sink; family state is retired; ledgers attribute the source |

## 8. Body displacement and boundary changes

| Operation | Owner | Rule |
|---|---|---|
| Body mask covers a liquid cell | World/body coupling (masked stored material stays authoritative, REM-002) | Current: the kernel skips masked cells (`update_cell` L3500); ejection paths never cross hard terrain. Proposed: family state stays with the stored cell under the mask; PF treats the mask as a solid boundary for head; no new pressure-to-Rapier force. |
| Hard-surface / topology edit | World | invalidates PF column/run summaries and gas topology (revision++); wakes both sides |
| Interest pause / re-entry | host + World | paused blocks keep their state; re-entry invalidates PF caches and dormant certificates before reuse (see mechanism report §C) |

## 9. Sleep, wake, reset, save and reconstruction

| Operation | Rule |
|---|---|
| Sleep | Current: a block sleeps after `sleep_after_quiet_ticks` (3) quiet ticks. Proposed: a family may sleep a block only when its future-affecting state is at rest (zero velocity, settled overfill, no pending gas change). PF dormancy (#201) must not suppress other families (contract `dormant-water-active-oil`). |
| Wake | any write, cross-family contact, topology change, gas change or remote head change affecting a dormant certificate |
| Reset/rebuild | a new World with fresh optional storage and gas table; no state carried from the old World; validate → reconstruct → commit |
| Save/readback | the experiment capture holds setup + effective policy + complete tick-boundary physical state + receipt hash; unknown mandatory fields are refused; CYSD1 loads with all liquids on defaults and is never a continuation |

## 10. Pressure gas compartments (PF, World-owned)

| Operation | Rule (Proposed; fixtures in `godot/tests/fixtures/lcb/acceptance/`) |
|---|---|
| Create | a sealed Empty region with no vented path forms a compartment with a new id and generation 0, amount = atmospheric amount for its free volume, and a ledger entry. Identity is never derived from amount. |
| Volume change (compression) | amount constant, volume recomputed, pressure derived (isothermal) |
| Connect / merge | distinct compartments merge **once**; amount = sum; one survivor id with ancestry of both; generation++ (`gas.unequal-merge`: 100+120 → 220) |
| Split | conservative deterministic split by a recorded allocation rule (volume-proportional with a remainder to the lowest new id); new ids; ancestry |
| Vent | connection to the atmosphere sets pressure toward atmospheric, with an explicit exchange ledger (amount in/out) |
| Reseal | a new compartment from the current volume at atmospheric amount (`gas.compress-vent-reseal`); the stale id is never reused |
| Disappear | free volume → 0 (filled by liquid): the remaining amount is booked to a declared sink or refused; never silently dropped |
| Empty-only chunks | compartment state is independent of whether Empty chunks are allocated (native #200 test) |
| Cross-family boundary | gas abuts a non-pressure liquid: the liquid is an impermeable boundary; volume counts only Empty cells |

## Acceptance hooks

| Contract | Coverage |
|---|---|
| Executable now (Current) | `test_lcb_physics_contracts.gd` (ownership swap, ledgers, dormancy, deep-release characterization, heads) and `test_lcb_negative_contracts.gd` |
| Blocked until #200/#212/#201 | registered in `godot/tests/fixtures/lcb/lcb-physics-contracts.json` with dependencies and frozen screens |
