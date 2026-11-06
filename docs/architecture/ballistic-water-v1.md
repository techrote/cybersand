---
title: Ballistic Water and hybrid spray (experimental)
status: Current
document-kind: reference
scope: Experimental-branch BW-001 ballistic_water_v1 parcel owner, IN-B1 signed-vertical inertial law and the WCX workbench impact-spray/jet adapter law; ownership, transfer lifecycle, conservation and momentum accounting, persistence/identity versions, capacity, cost and controls; not on main, no default changed
canonical-for: [ballistic-water-v1, inertial-b1-signed-vertical, water-impact-spray]
last-reviewed: 2026-11-05
related-documents: [inertial-cellular-v1.md, pressure-flow-v1.md, liquid-solver-family-policy.md, rigid-body-and-cellular-coupling.md, ../audits/2026-11-05-wcx-ballistic-water.md]
---

# Ballistic Water and hybrid spray (experimental)

**Status:** implemented on the experimental branch `claude/water-ballistic-hybrid`
(Draft PR), **not on main**. Every feature here is opt-in; a World that does
not enable it keeps its Current hashes, persistence format, quantity schema,
run receipt and behaviour. Owner decisions on #362/#20/#45 remain open, and no
default or production carrier is migrated. Evidence lives in the
[dated WCX record](../audits/2026-11-05-wcx-ballistic-water.md).

## Why a separate owner

[#362 Phase A (draft PR #376)](https://github.com/techrote/cybersand/pull/376) showed that
Current splash is collision-driven relocation only, never upward momentum, and
that a submerged body leaves its overlap Water masked under it. Re-working every
bulk kernel to carry upward momentum (architecture A) would touch four families
and their scheduling. A bounded native parcel owner (architecture B) gives every
family ballistic Water at the cost of one serial pass, and a cellular
signed-vertical law (IN-B1) covers the IN family's own representation.

## BW-001 `ballistic_water_v1`: native parcel owner

Source: `native/include/cybersand/ballistic_water.hpp`, `native/src/world_ballistic.inc`;
hooks in `world.cpp` (`begin_tick`, `clear`, render copies, snapshot publication),
`world_quantity.inc`, `world_pressure.inc` (hash/CYPS4/inheritance).

- **Enable:** `WorldConfig::ballistic_water.enabled` at construction. Capacity
  (default 4,096, maximum 65,536 parcels) is reserved then; launches beyond it
  are refused with `CapacityFull`. No tick-time allocation.
- **State:** `BallisticParcel` = q256 position and signed velocity (negative `vy`
  rises), exact `quantity` in the World's Water mass quantum, age, launching body,
  contact and deferral counts.
- **Launch** (`launch_ballistic_water`, serialized owner between ticks): moves the
  exact quantity of one Water source cell (FreeMass/PressureFlow may take part of a
  cell; CellularYield/IN take the whole cell) into one parcel spawned at an
  unmasked Empty or gas cell. A masked source is admitted because the body
  overlap is the usual reason to launch. A pressurized PressureFlow source
  (`overfill != 0`) is refused. Refusals never mutate authority.
- **Inject** (`inject_ballistic_water`): a parcel from a booked `ExternalEdit`
  source (jets and Water nozzles).
- **Advance:** once per tick at tick entry, after deferred events and before
  pressure preparation, serially in slot order (identical for any worker count).
  Gravity, drag and per-axis saturation, then a swept move of at most one cell
  per axis per substep. Terrain, other liquids, non-resident chunks and bodies
  rebound with restitution and tangential Coulomb friction (a fraction of the
  normal impulse), so a grazing sheet skims and runs out while a hard impact
  stops it; only real impacts count toward forced deposition. The axis-separated
  neighbours pick the contact normal, so diagonal corners cannot tunnel. The launching body is
  ignored for four ticks. Body contacts deliver the parcel's momentum change to a
  per-body counter (`transient_ballistic_impulse_x/y`).
- **Deposition:** on entering Water, after a slow contact, after too many rebounds
  or at maximum age. The parcel merges into the entered Water (FreeMass/PressureFlow
  capacity), then a bounded deterministic neighbourhood preferring upward cells.
  If bulk Water has flowed into the parcel's cell, it rises through its own unmasked
  Water column (≤64 rows) to the first free cell, so the surface rises by its
  volume. A deposit into IN Water creates a carrier that keeps the parcel's momentum
  (q256 → q16), booked as external IN velocity. Remaining quantity stays in the
  parcel (deferred) rather than being discarded.
- **Presentation:** in-flight parcels are drawn as Water in `copy_material_cells`,
  `copy_render_cells` and `RenderSnapshotExchange::publish` patches. Parcels extend
  only the render dirty rectangle (no activity, wake or pressure input). Authority
  is untouched.

### Conservation and momentum

The quantity ledger uses **schema 2** only in ballistic Worlds and adds
`water_ballistic` (exact in-flight quantity):

`baseline + Σproduced = visible + overfill + ballistic + Σconsumed`

Launch and deposition are pure transfers, never sources or sinks; injection is
an `ExternalEdit` source. `BallisticLedger` closes exactly:

- quantity: `in_flight = launched + injected - deposited`;
- momentum per component: `Σ q·v = launch + gravity + drag + contact + clamp - deposit`,
  with the body share of contact booked separately.

The complete validators run on save, restore and the authority-scan ledger check.

### Identity, persistence and lifecycle

| Surface | Disabled World | Ballistic World |
|---|---|---|
| Physical-state hash version | 2 (3 with IN) | 4; binds the configuration identity, every parcel and the ledger |
| Persistence | CYPS2/CYPS3 unchanged | CYPS4 with extension flags (bit0 IN, bit1 parcels, bit2 IN-B1) |
| Quantity schema | 1 | 2 (`water_ballistic`) |
| Run receipt | unchanged bytes | schema-2 quantity term and an explicit ballistic section |

`clear()` resets parcels and ledgers. A failed tick quarantines the World as
before. Workbench retained rebuilds (reset/replace body) carry parcels into a
ballistic owner (booked like inherited overfill) or report
`discarded_in_flight_water`; the host conversion balance includes in-flight Water
on both sides.

### WCX-FR face release (off by default)

`face_release` sheds Water cells from tall vertical faces (open beside the cell
and the cell above, with at least `face_min_height` Water rows above) as parcels
moving away from the face at `face_speed`/256 × √(2gh), bounded by `face_budget`
per tick and `face_period` per column. It runs serially at tick entry over sorted
active chunks and blocks, so results are worker-count independent, and every
release is an exact launch transfer (`face_releases` counter). Measured on a
48-row dam break after 36 ticks, the front moves FreeMass 38 → 42,
CellularYield 42 → 44 and PressureFlow 35 → 41 cells, but IN 50 → 42 (IN already
carries momentum). Released parcels mostly land on the spreading film and merge,
losing momentum. It is an experimental option ("Face release" construction
toggle), not a recommended default. The workbench passes explicit integer tuning
alongside it (`workbench_face_budget`, `workbench_face_speed`,
`workbench_face_period`, `workbench_face_min_height`). The adapter admits these only
with the workbench and face release, and only inside the native bounds. The panel
seeds stronger values than the native defaults (320 / 288 / 1 / 4 against
48 / 192 / 3 / 6). Native defaults and the ballistic identity are unchanged.

`film_skim` (on): a fast parcel descending at a grazing angle onto a one-cell Water
film slides over it with Coulomb friction (counted as `film_skims`) and merges once
slow; horizontal entry into Water still merges at once.

## Solver combinations: gas-free PressureFlow surface

A native dam-break assessment (`native/bench/wcx_surge_assessment.cpp`, 1024×192,
4 workers) shows that in open or vented scenes PressureFlow's gas topology costs
≈22–33 % of the tick and changes nothing: gas on and off give identical surface
motion. Gas-free `cached_dormant` PressureFlow costs about the same as FreeMass
(8.1 vs 8.0 ms p50) while moving the surface ≈2× as much and keeping its surge
(late motion 91 vs 34 rows per tick). The admitted `pressure_flow_v1` block
(`gas_enabled = 0`) already provides it; the bridge helper
`liquid_policy_with_pressure_gas` and the workbench "PF gas" toggle stage it.
Sealed rooms still need gas. A true per-region "top layer" hybrid (PressureFlow
only near the free surface, FreeMass below) was not implemented: dormant
certificates already skip resting deep cells, so its expected saving is small.

## IN-B1: signed-vertical inertial law

Opt-in `WorldConfig::inertial_signed_vertical` (requires an applied IN
assignment). It has its own extension identity domain and CYPS4 bit; v1 Worlds are
unchanged and still refuse `vy < 0` everywhere.

- U1/U3: support applies only to a cell that is not rising (`carried >= 0`), so an
  obstacle beneath never destroys upward motion; gravity alone turns it.
- U2: flight gravity is half of v1 (`kSignedGravity = 2` q16/tick²), so the
  radius-bounded 2-cell/tick launch reaches a visible ≈16-row apex before damping.
- U6: an upward-blocked move (ceiling or overhead body) reverses a quarter of the
  rise; a body overhead receives an upward contact.
- Ledger: `gravity_speed` books gravity's exact signed L1 effect, separate from
  dissipative `loss` (`Σ|v| = gravity_speed - loss + external - retired`); in v1
  it equals `gravity_y`. `impart_inertial_velocity` adds a bounded external impulse.

## WCX adapter launch law and workbench controls

Source: `godot/native_extension/water_spray_coupling.inc` (CyberNativeCellWorld),
`godot/scripts/workbench_water_spray_panel.gd`; options pass through `main.gd`,
`microscenario_host.gd` and `cyber_prepared_liquid_world.hpp`.

- When a body overlap cell holds Water and the body surface pushes it faster than
  the **threshold** (cells/tick along the overlap normal), the Water leaves the body
  sideways, rises through the body mask and Water to the free surface, and launches
  up-and-out (**upward bias**, lateral **spread**, deterministic **jitter**, speed =
  **launch scale** × push). Slow submerged overlap optionally lifts its Water to the
  surface (`submerged_lift`), closing the #376 masked-overlay gap as a level rise.
- Per-body **budget** per coupling cycle; excess overlap uses ordinary relocation.
- The body receives the same displacement reaction as a relocation; an extra
  stylized **reaction** gain defaults to 0 so the accepted LA/RFT feel is unchanged.
  Droplets that strike bodies deliver momentum (`droplet_gain`).
- A fixed **jet** (origin, angle, speed, rate, quantity, spread) and flyer Water
  nozzles inject booked parcels.
- Construction toggles "Ballistic Water" and "IN signed" apply on the next
  workbench build; runtime settings are queued to the owner and read back with
  native applied values, refusals and live/ledger telemetry.

This law is intentionally stylized: the injected momentum is real native state
and is booked as launch momentum, but its magnitude is a tuning choice, not a
fluid-dynamic derivation.

## Granular response interaction

LA-Selective, LA, events-off and RFT differ only in powder-gated terms (granular
arrivals/events and passive bins for `supports_granular_load` materials). In pure
Water their body trajectories are bit-identical; differences appear only through
contact with powder (a Sand bed or bank). The spray launch point is therefore the
overlap relocation, independent of the granular mode
([WCX-001 evidence](../audits/2026-11-05-wcx-ballistic-water.md#wcx-001-la-mode--water-discrimination)).

## Cost

The serial parcel pass costs ≈85–110 ns per parcel-tick (≤0.07 ms p95 with ≈590
live parcels, native). The dominant cost of a splash is the receiving bulk
waking: FreeMass and CellularYield pools keep re-levelling for more than a
hundred ticks after the parcels land. See the dated record for host and native
numbers and their advisory limits.

## Limits and open decisions

- Experimental only: no default, production carrier or #45 decision changes.
- PressureFlow overfill cells are refused as launch sources; parcels do not carry
  pressure, gas or temperature (deposits use ambient defaults).
- Parcels treat non-resident chunks as hard boundaries and are not simulated per
  region; an excluded region still receives deposits.
- Human gameplay acceptance, Windows/Linux CI, source-matched runtime publication
  and independent review remain open.
