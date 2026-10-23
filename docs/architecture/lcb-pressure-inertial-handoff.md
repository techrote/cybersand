---
title: LCB pressure and inertial implementation handoff
status: Planned
document-kind: design
scope: Implementation-ready requirements for LCB-001 (#200, pressure_flow_v1 and solver policy) and LCB-005 (#212, inertial_cellular_v1) derived from the LCB physics prepass — exact source hooks, state, laws, boundary rules, invalidating failures, smallest experimental regimes and the APIs needed to unblock registered tests; no kernel is implemented and LCB-000 remains blocked
canonical-for: [lcb-pressure-inertial-handoff]
last-reviewed: 2026-10-23
related-documents: [liquid-state-transition-matrix.md, liquid-solver-family-policy.md, ../audits/2026-10-23-lcb-physics-mechanism-report.md, ../operations/lcb-scenario-catalogue.md]
---

# LCB pressure and inertial implementation handoff

## Status

**Planned. Do not start until LCB-000 (#213) passes all five gates.** This
page converts the [mechanism report](../audits/2026-10-23-lcb-physics-mechanism-report.md)
and the [state-transition matrix](liquid-state-transition-matrix.md) into
requirements.

- Source references are `9012425`, unchanged at main `4caa2c3`.
- The archived pressure candidate is `7ef2aacf`
  (`tools/experiments/water_pressure_prototype/src/water_proto_b.inc`) on
  `620826f5`. It is unqualified, with known defects.
- Storage follows the Gate B handoff: C64-E8 unchanged, optional solver-owned
  storage, and a World gas table.

## Shared integration points (both families)

| Need | Where today | Requirement |
|---|---|---|
| Per-World policy | `WorldConfig` (`world.hpp` L30), beside `WaterExperimentPolicy` | Add `LiquidSolverPolicy` with the [canonical hashing](liquid-solver-family-policy.md#native-policy-object-proposed), validated before allocation. The default must reproduce the PR #217 goldens bit for bit. |
| Construction bridge | `CyberDemoBridge::build_water_feel_world` (`cyber_demo_bridge.hpp` L411) and every World constructor listed in #202 | Take the packed policy and refuse before `install`. Readback via `get_liquid_solver_policy()` with the applied family and normalization. |
| Family dispatch | `update_rule_kernel` L2829 (`RuleKernel` switch), after generic pair chemistry L2797 | Dispatch motion by family only for liquids with a non-default assignment. Keep stages 1, 2, 4 and 5 from the [material hooks](liquid-solver-family-policy.md#material-hooks-versus-motion-gate-c-correction-2026-10-23) unchanged. |
| Moves and swaps | `move_cell` L2323, `try_move` L2446, `transfer_water` L2481, `relocate_stored_cell` L1840 | Optional state moves atomically with its tuple; retired on Empty/conversion (R1). |
| Writes and products | `write_cell` L1475, `set_cell_state` L1693, pair-product writes L2797–L2826 | Products start at their family default state; signed ledger hook. |
| Transport coupling | `mix_after_motion` L2568 | Called with the real moved quantity (`maximum()` for a whole cell). |
| Body masks | `transient_obstacle_at`, `update_cell` L3500 skip | Masks are solid for motion and head. No new Rapier force. |
| Scheduling | `begin_tick` L3524+, block sleep after 3 quiet ticks | Sleep only when family state is at rest. Count work by visited cells and scheduled cores, not active-chunk flags (mechanism report §C). |
| Hashing | `state_hash` L4187+ (unchanged) | New versioned complete physical-state hash covering optional state and gas tables. |

**APIs required to unblock the registered tests** (in
`lcb-physics-contracts.json`):
- policy readback;
- versioned physical-state hash;
- `inspect_cell` extended with family state;
- `inspect_gas_compartments()` returning id, generation, ancestry, amount,
  volume, vent state and topology revision;
- per-reaction ledger events;
- a front/centroid observation metric (optional; the tests currently scan
  with `material_at`).

## Pressure (`pressure_flow_v1`, Water only, #200)

**What it must change.** Current Water has no head term:

- deep release is row-local diffusion, with front ∝ t^½ and no depth
  dependence;
- saturated connected Water has no legal move, so vented limbs never level
  (mechanism report §A, §B).

**Two separate behaviours, screened separately:**

1. **Deep-release surge.** Column height must produce lateral acceleration at
   an exposed face. Screen it on the dam depth ladder:
   - depth response ≥ 1.5 at t240;
   - depth-160 front ≥ 213 cells at t240;
   - retained fraction ≤ 0.50 at t1800;
   - exact visible + overfill quantity;
   - identical 1/4-worker results.

   Current gives 1.06, 71 cells and 0.851.
2. **Saturated-head equalization (vented).** Head must cross saturated cells:
   - vented two-limb difference ≤ 12 rows at t2400;
   - narrow passage ≤ 60 rows;
   - no growth beyond 2 rows after first reaching the bound.

   This is the experimental LCB lane. #45's own production question stays
   vented-only and separate.

**State:**
- per Water cell: overfill quantity and signed flow/velocity;
- per tick, derived scratch: head per run, gradient and lid interpolation. This
  is scratch **only** if it is fully recomputable from authoritative state;
  smoothing or offsets that carry history are authoritative (Gate B);
- World gas table (see below).

**Laws, bounded and deterministic:**
- head from vertical runs, as in the snapshot-head family of `7ef2aac`;
- overfill relay is bounded;
- outgoing flux carries the source's **updated** velocity (#200 defect);
- mass-weighted velocity merge with booked rounding remainders;
- integer quantities only;
- pressure gradients never cross walls, body masks or foreign liquids
  (radius-2 sampling respects intervening walls; #200 defect).

**Gas** (World-owned; **independent of #45's vented scope**; required by #200).
The rules are §10 of the transition matrix. They must hold on the acceptance
fixtures:

| Fixture | Requirement |
|---|---|
| `gas.single-pocket` | amount 100 constant |
| `gas.twin-pockets` | two ids, each 100, no 100,50,25… cycling |
| `gas.unequal-merge` | 100+120 → 220 once |
| `gas.compress-vent-reseal` | 100 held at half volume; vent with ledger; reseal at 50 |
| empty-only-chunk survival | native test |
| hash change on gas-only change | needs the hash API |

**Sealed headspace.** The `head.sealed-two-limb` target is the isothermal
equilibrium `p_L + z_L = p_R + z_R`, with each limb's
`p_i·V_i = p_atm·V_i0` and `p_atm` (in rows) a declared family parameter.
Tolerance is ±2 rows, and the result must differ from the vented target.

**Boundary with other families:** a non-pressure liquid neighbour is a
density-bearing boundary. No head propagates through it, and pressure
summaries are invalidated on any contact, swap or reaction there.

**Invalidating failures.** Any one of these rejects a candidate, whatever its
look or speed:
- quantity drift, including overfill;
- gas amount drift without a ledger entry;
- amount-keyed or reused compartment ids;
- 1/4-worker divergence;
- through-wall or through-mask head;
- a pressure arm silently running Current;
- unhashed authoritative state;
- tick-time unbounded allocation;
- dormancy suppressing other-liquid motion (contract `dormant-water-active-oil`);
- any change to Current goldens under the default policy.

**Smallest experimental regime:**
- Water only;
- mass8 and coherence honoured;
- `reference` variant first (#201 adds `cached`/`cached_dormant` with
  equivalence);
- gas off/on as a family parameter recorded in the receipt;
- 1024² built-ins sized before admission.

## Inertial (`inertial_cellular_v1`, #212)

**What it must add.** Retained motion between ticks. "Faster CellularYield" is
**not** inertia: `flow_as_yielding_liquid` (L2779) only changes a per-update
lateral probability, `(256−viscosity)/256`, and keeps no velocity (mechanism
report §E).

**State** (optional, per owning cell):
- signed vx/vy in fixed point (e.g. 1/16 cell per tick; width frozen per
  Gate B before code);
- signed subcell accumulators;
- saturation at a declared maximum (≤ the bounded write radius per tick);
- default 0, and reset to 0 on product, paint or reconstruction.

**Laws** (transition matrix §5):
- gravity increment to vy;
- travel by accumulator, one step per whole unit, re-checking each target;
- blocked travel zeroes the normal component and books the impulse;
- damping is multiplicative per tick, with a rest threshold;
- vertical density swaps keep the mover's velocity minus registered drag;
- no velocity is written into foreign families;
- no Rapier force.

**Distinguishing evidence** (must show what CellularYield cannot):

| Signature | Requirement |
|---|---|
| Residual motion after support removal | lateral travel continuing ≥ N ticks after the source stops, with N declared |
| Over-run past a step | travel beyond where the gravity-only path stops |
| Depth-dependent surge | screen: depth response ≥ 1.25 at t240; depth-160 front ≥ 142; retained ≤ 0.70 at t1800 |

**Material specialization survives:** stages 1, 2, 4 and 5 of the material
hooks apply unchanged. For Brine that means:
- `water-salt` products (Brine created at inertial default velocity 0);
- `brine-sodium`, `fire-brine` and `brine-bareiron`;
- Coal/Cement contact tests;
- density 1120 vertical exchange.

Oil, Lava, Acid, Cement and Molten Glass are not admitted in v1.

**Smallest experimental regimes:**
- **Brine:**
  - whole cells, damping parameter in the receipt;
  - fixtures `viscous.lane-gallery` (Brine lane),
    `density.water-brine-lock-exchange` and the mixed M1 arm.
- **Water W-IN:**
  - whole cells at `maximum()`;
  - fractional setups refused or explicitly normalized;
  - coherence honoured; adhesion not applicable (declared);
  - fixtures: the dam ladder, `shallow.ledge-sheet-fall` and
    `shallow.obstacle-run`.

**Invalidating failures:**
- whole-cell count drift;
- velocity duplicated or left on a vacancy;
- through-wall or through-mask travel;
- unbounded writes;
- 1/4-worker divergence;
- a Brine reaction that keeps a stale velocity;
- any change to Current goldens under the default policy.

## Whole-cell Water (`cellular_yield_v1`, W-CY, #200)

- Water hooks (stages 1, 2, 4, 5) run with yielding motion using a **Water
  material parameter** for viscosity. It never uses `RuleKernel::YieldingLiquid`
  with Paste/Slush descriptors.
- Every Water cell holds `maximum()`. Fractional input is refused or
  normalized (`water-normalize-v1`).
- Adhesion is not applicable (declared). Coherence is honoured.

## Admission and review

Every item above is preregistered in `godot/tests/fixtures/lcb/lcb-physics-contracts.json`.
Current-family controls run in `test_lcb_physics_contracts.gd`; every candidate
arm is BLOCKED with its dependency.

This handoff is submitted for **independent review (Sol, #216 follow-up)**.
It is not an admission decision, and LCB-000 is not PASS.
