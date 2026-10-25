---
title: Liquid material and solver state-transition matrix
status: Approved design
document-kind: design
scope: Operation-by-operation rules for default liquids, accepted native W-CY/pressure variants/Brine IN and isolated published Water IN; historical Proposed requirements retain their source qualification — ownership, state movement, exact quantity/source-sink, invalidation and family applicability; no production Cell layout choice
canonical-for: [liquid-state-transition-matrix]
last-reviewed: 2026-10-25
related-documents: [pressure-flow-v1.md, liquid-solver-family-policy.md, liquid-prepared-setup-and-receipts.md, lcb-pressure-inertial-handoff.md, data-ownership-and-lifetimes.md, ../audits/2026-10-23-lcb-physics-mechanism-report.md, ../systems/water-design.md, pressure-optimization.md]
---

# Liquid material and solver state-transition matrix

**Unmerged application integration:** the [final source union](liquid-prepared-setup-and-receipts.md#final-application-source-union)
applies the existing WholeCell ingress rule to scheduled Water actions for both
CY and IN before any owner swap. Setup normalization cannot authorize future
fractional ingress. Actual desktop and synchronous refusal controls retain the
old owner/receipt/record. The integration adds no new state-transition law,
cell ABI or physical-save host-mask/body continuation claim.

**Current source and qualification:** the [Brine IN reference](inertial-cellular-v1.md) implements its declared ownership/law scope and is accepted on main through #250. The isolated [Water IN successor](inertial-cellular-v1.md#water-in-native-successor--2026-10-25) adds its material/carrier contract and actual sourceaa8af247 Windows/Linux publication. Final ready-PR and full application/scientific qualification remain pending. The standalone model and historical Proposed rows below retain their separate evidence meaning.

## Status and inputs

- **Default-family baseline rows** retain the historical prepass at `9012425`/`4caa2c3`. Current PF and W-CY refinements are identified separately below.
- **Proposed rows** are the contract that #200 (policy, `pressure_flow_v1`,
  whole-cell Water) and #212 (`inertial_cellular_v1`) must implement and
  test.
- **PF rows are implemented (2026-10-24)** by the opt-in
  [`pressure_flow_v1/reference`](pressure-flow-v1.md), Current on main since #245
  merged at `03785c3`. Its
  [lifecycle table](pressure-flow-v1.md#lifecycle-per-mutation-path) owns the
  Current per-path result. Refinements of the Proposed PF text: the overfill
  bound is `maximum()`; a kernel-vacated cell carries a vacuum label (volume, not
  amount); `transfer_water` throws in a pressure World; vented and collapsed gas
  amounts are booked in `GasLedger`. Accepted [PR #246](../audits/2026-10-25-lcb001-shared-contract-acceptance.md)
  advances main to exact hash/persistence version **2** with the shared quantity
  ledger and construction bindings. Main explicitly refuses historical CYPS1;
  its #245 evidence is retained. CYSD1 stays a default-family reconstruction.
- **W-CY rows are Current on main through #246** at merge `ec58d919`:
  whole-cell Water law version 1 and optional
  viscosity material block v2, with retained cadence/stochastic liveness.
  [Native prepared setup and receipts](liquid-prepared-setup-and-receipts.md)
  owns normalization, native-issued outcomes, typed receipt and accounting
  codecs. This owner-requested narrow native freeze is not a production Cell or
  global ABI freeze. Brine IN/reference and #201 caches/dormancy are Current
  in the combined #212 source, with [IN](inertial-cellular-v1.md) and
  [pressure](pressure-optimization.md) qualifications separately retained;
  fresh combined-source qualification remains required.
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
| Gravity/diagonal move of a whole cell into Empty | World kernel (`try_move` L2446 → `move_cell` L2323) | whole tuple + optional state | exact per cell | both endpoints' blocks woken; PF: column/run summaries dirty | Current (when not merging) | Current | Current PF: cell + overfill + velocity move together | Proposed: velocity and accumulator move with the cell |
| Lateral move into Empty | kernel | same | exact | same | via `transfer_water` partial (see §4) | Current: whole cell, viscosity roll only for yielding kernels | Current PF: flux law, quantity moves, remainder stays | Proposed: travel from the accumulator; one destination per tick within the bounded radius |
| Move refused by body mask | World (`transient_obstacle_at`) | none | exact | contact recorded (`record_transient_contact`) | Current | Current | must record the same contact and must not push state into the mask | same; impulse into a mask is dissipated and booked |

## 2. Same-liquid transfer and merge

| Operation | Owner | State | Conservation | Invalidation | FM | CY | PF | IN |
|---|---|---|---|---|---|---|---|---|
| Fall onto same-liquid with capacity | Water: `transfer_water` (L2481); others: no merge | quantity | exact integer (Water) | both endpoints | Current: merges up to capacity; `state_b` = max | Current: none (whole cells only) | Current PF: visible + overfill conserved; velocities mixed by a registered mass-weighted rule with deterministic rounding and a booked rounding remainder | Proposed (whole-cell): no merge; momentum transfer through §5 |
| Lateral relaxation between same-liquid neighbours | Water `level_with` (L2698) | quantity | exact | endpoints | Current ¾ rule, `tolerance()` | none | Current PF: head-gradient flux and resting surface skin | none (motion is velocity-driven) |

## 3. Different-liquid displacement and density exchange

| Operation | Owner | State | Conservation | Invalidation | FM | CY | PF | IN |
|---|---|---|---|---|---|---|---|---|
| Vertical density swap | `can_density_exchange` (vertical delta ≠ 0) + `move_cell(swap)` | **both** whole tuples + both cells' optional state | exact for both tuples (tested: `test_lcb_physics_contracts.gd::ownership`) | both endpoints; PF summaries of the affected run invalidated before reuse | Current | Current | Current PF: overfill stays with its Water cell; the foreign cell is a density boundary | Proposed: velocity stays with its cell; no velocity written into a foreign family |
| Sideways contact with a foreign liquid | none today (no sideways swap) | — | — | — | Current: blocked | Current: blocked | Current PF: foreign liquid = known-density boundary, no head propagation through it | Proposed: impulse stops; dissipation booked |

## 4. Partial versus whole-cell quantity

| Operation | Owner | Rule |
|---|---|---|
| FreeMass partial transfer | `transfer_water` | Current: `amount = min(requested, source, capacity)`. Zero source → Empty; Empty destination → Water. |
| Whole-cell Water (W-CY main; isolated Water IN successor) | family | Current native W-CY and isolated Water IN successor: every Water cell holds exactly `maximum()`. Fractional ingress refuses or uses explicit native `water-normalize-v1` preparation (up when `2·m ≥ maximum()`, exact setup-only source/sink); no Godot normalization opt-in yet. |
| Overfill (PF) | family | Current: Water can hold `maximum()` + overfill, with overfill ≤ `maximum()`. Overfill enters native quantity accounting and observations and is never rendered as an extra cell. |
| Observation of quantity | host | `water_integer` for FM/PF (visible + overfill for PF); `maximum()` per cell for whole-cell families |

## 5. Velocity and momentum (IN; PF flow)

**Inertial update `inertial-update-v1` (Proposed, #212; correction 2026-10-23).**
The earlier rows were inconsistent ([re-review finding 2](https://github.com/techrote/cybersand/pull/226#issuecomment-6362824493)):
- a per-component ledger with only non-negative losses could not represent a
  deflection that creates `vx > 0`, nor damping of a negative `vx`;
- gravity before deflection could push a supported cell at rest sideways;
- "blocked travel zeroes velocity" contradicted "same-family blocking
  preserves velocity".

They are replaced by one ordered update per inertial cell per tick. The
executable specification is the standalone oracle
[`inertial_contract.py`](../../tools/lcb/inertial_contract.py), with its
[tests](../../tools/lcb/test_inertial_contract.py). Its worked examples are
embedded in the [contract registry](../../godot/tests/fixtures/lcb/lcb-physics-contracts.json)
(contract `inertial-update`). It is a contract model on static neighbourhoods:
**the contract model itself executes no World, scheduler or inertial family.**

Units: velocity and accumulators are signed integers in `q` units per cell. The
illustrative values are `q = 16`, `g = 4` and `vmax = 64`. Fractions are
`turn 1/8`, `deflect 3/4`, `damping 1/16` and `drag 1/4`; the rest threshold is
`1`. These values are recorded in the receipt and are **not frozen**. `vy ≥ 0`
always, because v1 has no upward impulse source.

| Step | Rule |
|---|---|
| Eligibility (N1 correction) | One **directional** rule `eligible(dx, dy)` serves support, re-aim, side selection and every travel move. Empty: any move. A lighter foreign material admitted by Current density/exchange controls: **only a move with `dy = +1`**, straight or diagonal down. This is the vertical density exchange Current `can_density_exchange` admits (vertical delta ≠ 0). A horizontal move (`dy = 0`) never swaps; a lighter neighbour beside the cell is a horizontal contact. Wall, solid, transient body mask and an occupied same-material cell are never eligible and share one contact rule. Selecting IN for both materials does not remove a permitted foreign-material density exchange. No new foreign-liquid boundary law is introduced. |
| U1 support | `supported` := `not eligible(0, +1)`, evaluated before any velocity change. A lighter liquid below is therefore not support. |
| U2 gravity | `vy += g`, **exactly once per tick**, booked as the only speed-adding entry. |
| U3a diagonal re-aim (lateral source A) | If supported and `eligible(±1, +1)`: the `sign(vx)` side first, else `deterministic_direction` order. Then `S = |vx| + vy` (including this tick's `g`), `turn = trunc(S·1/8)`, `S' = S − turn`, `|vx| = S' // 2` toward the diagonal, `vy = S' − |vx|`. A cell at rest gains only `g` along the diagonal. |
| U3b support and deflection (lateral source B) | If supported and both diagonals are blocked, a **support** impulse `−g` first cancels this tick's gravity. It is a constraint, not dissipation. Only the velocity `vy_in` **carried in from earlier ticks** may deflect. With `d = trunc(vy_in·3/4)` and side `s = ±1`, the first `eligible(s, 0)` side is chosen (`sign(vx)` side first, else deterministic order). Then `vx += s·d` and `vy −= vy_in`. The **signed impulses** are `(s·d, −vy_in)`. The **L1 speed loss** is `|vx| + vy_in − |vx + s·d|`, which includes cancellation against an opposing `vx` (N2 correction). It equals `vy_in − d` only when `vx = 0` or `sign(vx) = s`. Example: `(40, 32)` deflecting left gives `(16, 0)`, loss 72 − 16 = **56**. With no eligible side, `vy −= vy_in` is a pure contact loss. **A supported cell at rest with both diagonals blocked has `vy_in = 0`, so it never gains `vx`.** With an eligible diagonal, U3a re-aims from rest by design. |
| U4 saturation | Clamp each component to `±vmax`. The clamped amount is a signed impulse with a non-negative loss. It is applied again after a travel landing. |
| U5 damping | `v_c −= trunc(v_c·1/16)` per component, truncated toward zero. For a negative `vx` the impulse is **positive**: `−40` becomes `−38`, with impulse `+2`. |
| U6 travel | `a += v`; whole steps `n = trunc(a / q)`, `a −= n·q`, so `|a| < q` and at most `vmax / q` = 4 cells per axis per tick. Moves follow a DDA. A sub-step that needs both axes is first tried as **one diagonal move** `(sx, +1)` when that move is eligible. Otherwise it becomes a vertical unit move, then a horizontal one. A permitted move with vertical displacement is therefore never split into a forbidden horizontal swap. **Every target is rechecked with `eligible`.** A lighter liquid swaps only on a `dy = +1` move, and the mover loses `trunc(v·1/4)` per component (drag). **The first contact ends travel.** A vertical contact applies the U3b landing rule (deflection of the remaining `vy`, then saturation). A horizontal contact zeroes `vx` and `ax` as a booked contact impulse. |
| U7 rest and sleep | If supported, `vy = 0` and `|vx| ≤ rest`, then `vx = 0`. Any accumulator residue is reset and recorded as a travel note; it is not momentum. The cell is **sleep-eligible** iff `v = 0`, `a = 0` and it is supported. |
| Momentum ledger | Per component, exactly: `v_after = v_before + gravity + Σ signed impulses`, where gravity is `(0, g)` and the impulses are support, re-aim, deflect, contact, saturate, damping, drag and rest. **Signed impulses are distinct from loss.** |
| Speed-loss ledger | Separate, with L1 speed `S = |vx| + |vy|`: `S_after = S_before + g − Σ loss`, and every non-gravity loss ≥ 0. `support` is booked as a constraint, the rest as dissipation. The quadratic energy is not claimed. |
| Rounding | Every rational product truncates toward zero. The signed remainder numerator is audited per entry and never stored. |
| Collision with Wall/solid/body mask/same material, or a lighter material entered horizontally | **One rule for every ineligible move**: vertical = the U3b landing, horizontal = zero `vx`. Same-material contact is **inelastic** in v1: no velocity exchange, and the occupied cell is unchanged. A lighter foreign material retains Current downward density exchange even when both select IN. This resolves the earlier "preserves velocity" row, which would have stored unbounded pending motion. No Rapier force is applied. |
| No other lateral source | There is no column-height scan, pressure or neighbour push; that is `pressure_flow_v1`'s role. |
| Displacing a lighter liquid (vertical swap, `dy = +1` only) | Drag is booked per U6. The displaced cell keeps its own (or zero) state, and no velocity is written into a foreign family. |
| Split/merge (PF partial flux) | Outgoing flux carries the source's updated velocity (the #200 defect fix); the receiver mass-weights it; rounding remainders are booked. |

**Worked examples** (exact, in the registry):

| Example | Start (x, y, vx, vy, ax, ay) | End | Ledger entries |
|---|---|---|---|
| deflect right (left side blocked) | (2,1, 0,32, 0,0) | (3,1, 23,0, 7,0) | gravity +4y; support −4y; deflect +24x −32y, loss 8; damping −1x, loss 1, remainder 8 |
| deflect left | (2,1, 0,32, 0,0) | (1,1, −23,0, −7,0) | mirror of the above |
| deflect right, aligned vx | (2,1, 10,32, 0,0) | (4,1, 32,0, 0,0) | deflect +24x −32y, loss 10+32−34 = 8; damping −2x |
| deflect right, opposing vx | (2,1, −10,32, 0,0) | (2,1, 14,0, 14,0) | deflect +24x −32y, loss 10+32−14 = **28** |
| deflect left, aligned vx | (2,1, −10,32, 0,0) | (0,1, −32,0, 0,0) | deflect −24x −32y, loss 8; damping +2x |
| deflect left, opposing vx (review N2) | (2,1, 40,32, 0,0) | (2,1, 15,0, 15,0) | deflect −24x −32y, loss 40+32−16 = **56**; damping −1x |
| damp negative vx | (2,1, −40,0, 0,0) | (0,1, −38,0, −6,0) | gravity +4y; support −4y; damping **+2x**, loss 2, remainder −8 |
| supported rest, free side | (2,1, 0,0, 0,0) | unchanged, sleep-eligible | gravity +4y; support −4y |
| blocked by same material | (2,1, 0,20, 0,0) | (2,1, 0,0, 0,0), sleep-eligible | gravity +4y; support −4y; contact −20y, loss 20 |
| re-aim from rest | (2,1, 0,0, 0,0) | (2,1, 2,2, 2,2) | gravity +4y; re-aim +2x −2y, loss 0, remainder 4 |
| re-aim carried | (2,1, 0,40, 0,0) | (3,2, 18,19, 2,3), one diagonal move | re-aim +19x −24y, loss 5 (44 → 39); damping −1x −1y |
| saturation and bounds | (2,1, 0,62, 0,15) | (2,5, 0,60, 0,11), 4 cells | saturate −2y; damping −4y |
| contact mid-travel | (0,1, 48,0, 0,0) | (1,1, 0,0, 0,0), sleep-eligible | damping −3x; horizontal contact −45x |
| body-mask landing | as deflect right, with a mask below | identical to deflect right | identical: one contact rule |
| density swap drag | (2,1, 0,20, 0,0) | (2,2, 0,18, 0,7) | damping −1y; drag −5y, loss 5, remainder 3; swap `(0,+1)` |
| re-aim diagonally into a lighter liquid | (2,1, 0,40, 0,0), lighter at (3,2) | (3,2, 14,15, 2,3) | re-aim +19x −24y; damping −1x −1y; drag −4x −4y; swap `(+1,+1)` |
| no horizontal swap (review N1) | (1,1, 20,0, 0,0), lighter at (2,1) | (1,1, 0,0, 0,0), sleep-eligible | damping −1x; horizontal contact −19x, loss 19; no drag, no move |
| no deflection into a lighter side | (2,1, 0,32, 0,0), lighter left, Wall right | (2,1, 0,0, 0,0) | support −4y; vertical contact −32y, loss 32 |

An exhaustive regression covers every 3×3 Empty/Wall/lighter neighbourhood
across a velocity and accumulator grid. That is 3⁸ × 5 × 4 × 3 × 2 =
**787,320 updates**; the earlier figure of 393,660 was wrong (re-review N5). It
asserts:
- both ledgers close;
- every non-gravity loss is ≥ 0;
- exactly one gravity entry;
- bounds `|v| ≤ vmax`, `|a| < q`, and ≤ 8 unit moves;
- `vx` leaves 0 only through a re-aim or deflect entry;
- a supported, diagonally blocked cell at rest stays exactly at rest and is
  sleep-eligible;
- every density-exchange move has `dy = +1`, and no move enters a lighter
  cell horizontally.

The sweep checks ledger closure, bounds and swap direction. It does **not**
by itself prove agreement with the written U3b formula. Separate analytic
tests do that: they compute impulses and loss independently for both sides,
for aligned and opposing `vx`, and for several `vy_in`. Further directional
tests cover Wall, body mask, same-material and lighter horizontal contacts,
corner travel, and lighter-below non-support.

## 6. Reactions and material conversion

| Operation | Owner | Rule |
|---|---|---|
| Pair reaction (any admitted family) | generic pre-kernel chemistry | **Current native:** products use descriptor defaults (Water at `maximum()`), with family state reset even for Water-to-Water products. Shared accounting books actual visible+overfill Water consumed and gross Water produced per rule; material cell counts are separate units. #160 chemistry is unchanged. |
| Phase change Water↔Steam/Ice | Steam/Ice kernels (L2846, L3142) | Current: Steam expiry → Water at `maximum()` (#160 amplification). PR #162 would preserve quantity; it is unmerged, so LCB books the delta and does not assume it. |
| Kernel lifecycle (Oil burn, Cement cure, Molten Glass cooling) | material kernel | unchanged under every admitted family; specialized liquids stay on their default family |

## 7. Painting, erasing, sources and sinks

| Operation | Owner | Rule |
|---|---|---|
| Paint/fill | host → `set_cell_state`/`water_experiment_fill_rect` | Current native: Water fill uses selected precision; painted family state resets. W-CY and isolated Water IN require `maximum()`; fractional bool ingress returns false before allocation/mutation. Family-only reset still emits mutation/wake witnesses. Native prepared construction is the explicit normalization path. |
| Erase | host | the cell becomes Empty; optional state is retired; a ledgered sink |
| Scheduled source/sink | MicroScenario/World owners | Native shared accounting books actual Water source/sink including PF overfill, independently of the host observation window; Brine IN and isolated Water IN retire optional motion through the shared writer. Host `water_ledger` is a separate apparatus projection. |
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
| Sleep | Current: ordinary quiet threshold 3; W-CY retains deadlines for legal future cadence/yield opportunities and blocked pools may sleep. Current #201 branch motion certificates prove a bounded no-op and preserve no-motion body contacts/material work; they cannot freeze nonzero flow or suppress other families. Execution3 warmup/backoff selects ordinary motion during deferred proofs; final qualification remains pending ([contract](pressure-optimization.md)). |
| Wake | any write, cross-family contact, topology change, gas change or remote head change affecting a dormant certificate |
| Reset/rebuild | a new World with fresh optional storage and gas table; no state carried from the old World; validate → reconstruct → commit |
| Save/readback | Current on main: typed-v1 prepared setup/receipts/accounting, complete physical hash2 and CYPS2 continuation; unknown schema/format and historical CYPS1 refuse. Qualified provenance is not full host replay proof. CYSD1 loads defaults and is never a continuation. |

## 10. Pressure gas compartments (PF, World-owned)

**Implemented in source** by the
[pressure reference gas pass](pressure-flow-v1.md#gas-compartments): label-overlap
identity, monotonic ids, exact `GasLedger`, phase convention unchanged. The
registered fixtures below pass in the native and Godot pressure regressions at
1 and 4 workers ([evidence](../audits/2026-10-24-lcb001-pressure-reference-publication.md)).
Declared simplification: a component that vents and seals in the same tick
recreates its sealed part at atmospheric amount.

Expected times use the phase convention in the
[handoff](lcb-pressure-inertial-handoff.md#pressure-pressure_flow_v1-water-only-200): an
event indexed N applies after completed tick N and is first observable at
completed N+1.

| Operation | Rule (Current PF; fixtures in `godot/tests/fixtures/lcb/acceptance/`) |
|---|---|
| Create | a sealed Empty region with no vented path forms a compartment with a new id and generation 0, amount = atmospheric amount for its free volume, and a ledger entry. Identity is never derived from amount. |
| Volume change (compression) | amount constant, volume recomputed, pressure derived (isothermal) |
| Connect / merge | distinct compartments merge **once**; amount = sum; one survivor id with ancestry of both; generation++ (`gas.unequal-merge`: 100+120 → 220) |
| Split | deterministic split by a recorded allocation rule: volume-proportional floor shares, with the integer remainder to the compartment holding the lowest (y, x) cell; parent id retired; new ids with ancestry; exact split ledger (`gas.split.v1`) |
| Vent | connection to the atmosphere sets pressure toward atmospheric, with an explicit exchange ledger (amount in/out) |
| Reseal | a new compartment from the current volume at atmospheric amount (`gas.compress-vent-reseal.v2`, supported U-trap seal); the stale id is never reused |
| Disappear | free volume → 0 (filled by liquid): the remaining amount is booked to a declared sink or refused; never silently dropped |
| Empty-only chunks | compartment state is independent of whether Empty chunks are allocated (native #200 test) |
| Cross-family boundary | gas abuts a non-pressure liquid: the liquid is an impermeable boundary; volume counts only Empty cells |

## Acceptance hooks

| Contract | Coverage |
|---|---|
| Executable now (Current) | `test_lcb_physics_contracts.gd` (ownership swap, ledgers, dormancy, deep-release characterization, heads) and `test_lcb_negative_contracts.gd` |
| Executable on main (PF reference, #245) | native `test_lcb_pressure.cpp` (13 cases: admission, gas fixtures, Empty-only chunks, quantity/worker parity, two-limb, barriers, static rest/wake, lifecycle ledgers, physical hash and CYPS persistence, default goldens) and `test_lcb_pressure_reference.gd` (12 sections) |
| Native residual #200 | `test_water_cellular_yield.cpp`, `test_water_normalization.cpp`, `test_liquid_construction_refusal.cpp`, `test_liquid_run_receipt.cpp`, `test_quantity_ledger.cpp`; qualified native evidence in the [canonical contract](liquid-prepared-setup-and-receipts.md#tests-and-qualified-evidence) |
| Remaining campaign dependencies | #201 cached/dormant source exists with separate runtime/final-CI gates; #202 host/normalization UI, #212 IN and registered integrated arms retain their own qualification. Native W-CY tests do not imply those gates passed |
