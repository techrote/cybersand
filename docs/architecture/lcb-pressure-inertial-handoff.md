---
title: LCB pressure and inertial implementation handoff
status: Approved design
document-kind: design
scope: LCB-001 pressure/W-CY and shared-native handoff plus Planned LCB-005 inertial requirements — material hooks, state, laws, boundaries, invalidating failures and campaign APIs; detailed setup/receipt/accounting codecs have their own canonical owner
canonical-for: [lcb-pressure-inertial-handoff]
last-reviewed: 2026-10-25
related-documents: [pressure-flow-v1.md, liquid-state-transition-matrix.md, liquid-solver-family-policy.md, liquid-prepared-setup-and-receipts.md, ../audits/2026-10-23-lcb-physics-mechanism-report.md, ../operations/lcb-scenario-catalogue.md]
---

# LCB pressure and inertial implementation handoff

## Status

**Approved requirements; pressure reference implemented, inertial Planned.** **LCB-000 Gates A–E PASS; #213 closed completed (2026-10-24).** See the [final admission checkpoint](../reference/status-and-roadmap.md#liquid-comparison-build-design-checkpoint--2026-10-23). The initial opt-in #200 start was separately scoped. On 2026-10-24 the owner lifted the hold for the bounded [#200 policy foundation](../reference/status-and-roadmap.md#lcb-001-policy-foundation--2026-10-24) and then authorized the bounded LCB implementation, including the previously held #200 pressure reference and #212 inertial work ([owner decision](../reference/status-and-roadmap.md#lcb-001-pressure-reference--2026-10-24)). The opt-in [`pressure_flow_v1/reference`](pressure-flow-v1.md) is Current on main since #245 merged at `03785c3`, with its recorded pressure evidence; #212 is no longer owner-held but remains outside this accepted main integration/qualification checkpoint. This does not admit production default changes, generic #12 Stage-4 cell↔Rapier ownership, a production Cell-carrier migration, full GEN-006 streaming, new pressure-to-Rapier forces or a global schema/ABI freeze.

Accepted main [PR #246](../audits/2026-10-25-lcb001-shared-contract-acceptance.md)
at `ec58d919` adds W-CY motion,
explicit normalization, native-issued refusal/failure values, typed native
receipts and shared exact quantity accounting. Their canonical ownership is
[native prepared setup and receipts](liquid-prepared-setup-and-receipts.md).
The owner requested a narrow freeze of those native codecs; this does not freeze
production Cell storage, the global ABI, pressure calibration or application
replay. #201/#212 successor integration/qualification and #202 application integration remain pending.

The pressure requirements below are now implemented by the
[`pressure_flow_v1` reference](pressure-flow-v1.md), which owns the Current
storage, laws, parameters and limits; this page keeps the requirements it was
built against. The inertial requirements remain **Planned** (#212). This
page converts the [mechanism report](../audits/2026-10-23-lcb-physics-mechanism-report.md)
and the [state-transition matrix](liquid-state-transition-matrix.md) into
requirements.

- Historical prepass source references are `9012425`, unchanged at checkpoint `4caa2c3`; the accepted main pressure/shared-native source is identified above.
- The archived pressure candidate is `7ef2aacf`
  (`tools/experiments/water_pressure_prototype/src/water_proto_b.inc`) on
  `620826f5`. It is unqualified, with known defects.
- Storage follows the Gate B handoff: C64-E8 unchanged, optional solver-owned
  storage, and a World gas table.

## Shared integration points (both families)

| Need | Where today | Requirement |
|---|---|---|
| Per-World policy | `WorldConfig::liquid_solver_policy` beside `WaterExperimentPolicy` | **Current foundation (2026-10-24):** `LiquidSolverPolicy` with the [canonical hashing](liquid-solver-family-policy.md#native-policy-object-proposed), validated before allocation ([foundation](liquid-solver-family-policy.md#native-policy-foundation-current-2026-10-24)). **Current on main:** Water × `pressure_flow_v1/reference` with one optional family block. Accepted main also qualifies Water × `cellular_yield_v1/reference` with its v2 viscosity block. Further candidate families must extend the running build's qualified cells and schemas. |
| Construction | Native `PreparedWorldBuilder`; bridge `build_liquid_policy_world`; other #202 constructors | Native explicit normalization and actual payload/quantity checks occur on an unexposed candidate. Native-issued outcome preserves retained World/generation. Godot typed normalization opt-in and remaining #202 constructors are Planned. |
| Family dispatch | `update_rule_kernel` L2829 (`RuleKernel` switch), after generic pair chemistry L2797 | Dispatch motion by family only for liquids with a non-default assignment. Keep stages 1, 2, 4 and 5 from the [material hooks](liquid-solver-family-policy.md#material-hooks-versus-motion-gate-c-correction-2026-10-23) unchanged. **Current on main:** `RuleKernel::Water` calls `update_water_pressure` in a pressure World; accepted main also dispatches W-CY explicitly. |
| Moves and swaps | `move_cell` L2323, `try_move` L2446, `transfer_water` L2481, `relocate_stored_cell` L1840 | Optional state moves atomically with its tuple; retired on Empty/conversion (R1). |
| Writes and products | `write_cell`, `set_cell_state`, generic pair products | Current native: reset family state even for same-material products, retain family-only mutation witnesses, book gross visible+overfill Water and initialized output per catalogue rule; separate material populations. |
| Transport coupling | `mix_after_motion` L2568 | Called with the real moved quantity (`maximum()` for a whole cell). |
| Body masks | `transient_obstacle_at`, `update_cell` L3500 skip | Masks are solid for motion and head. No new Rapier force. |
| Scheduling | `begin_tick` L3524+, block sleep after 3 quiet ticks | Sleep only when family state is at rest. Count work by visited cells and scheduled cores, not active-chunk flags (mechanism report §C). |
| Hashing/persistence | `physical_state_hash`, `save_physical_state`, `restore_physical_state` | Current main native hash2/CYPS2 include shared accounting and construction bindings; historical content/state hashes unchanged; old CYPS1 explicitly refuses ([definition](pressure-flow-v1.md#physical-state-hash-v2)). |

**APIs required to unblock the registered tests** (in
`lcb-physics-contracts.json`):
- policy readback (Current foundation; the #245 pressure adapter adds `family_parameters`);
- versioned physical-state hash (`get_physical_state_hash()`, Current main version 2);
- `inspect_cell` extended with family state (`family_state` in pressure Worlds, Current on main);
- `inspect_gas_compartments()` returning id, generation, ancestry, amount,
  volume, vent state and topology revision (Current on main);
- native bounded per-reaction quantity aggregates and separate material-cell
  counts (not ordered replay); #202 owns their complete host collection;
- a front/centroid observation metric (optional; the tests currently scan
  with `material_at`).

## Pressure (`pressure_flow_v1`, Water only, #200)

**Implementation status (2026-10-24).** `pressure_flow_v1/reference` is
**Current on main since #245, with the shared successor accepted in #246 at `ec58d919`**; the
[canonical design](pressure-flow-v1.md) owns its storage, gas identity, laws,
parameters and known limits. The native suite (13 `LCB-001 pressure` cases) and
the Godot candidate regression exercise the mandatory criteria below. The native
characterization harness at repaired source `349d593` recorded depth response
1.69, depth-48/96/160 fronts 130/221/220, depth-160 retained 0.371, vented
two-limb signed gap −9 rows (first within ±12 at t1026, subsequent maximum 12)
and narrow passage 43 rows at the screen ticks. The sealed two-limb differs
from vented (levels 152/175, gap 23 at t2400), remains unsettled and has no
sealed-law acceptance. These are screens, not admission criteria
([evidence](../audits/2026-10-24-lcb001-pressure-reference-publication.md));
earlier pre-repair metrics remain historical in that record.
This is retained #245 evidence, not a new full characterization of the residual
setup/receipt/accounting delta. Cached/dormant variants remain #201. A dormant
rest certificate must preserve failed-motion body-contact probes consumed by
coupling, material stages and future cadence/events, and prove zero future
motion rather than freeze nonzero residual flow. It must show extra Water work
savings while unrelated materials continue, beyond ordinary block sleep. No
#12 skip/promotion ownership or #45 selection follows.

**What it must change.** Current Water has no head term:

- deep release is row-local diffusion, with an approximately diffusive front
  (t^0.48–0.50) and only a weak depth response on the dam ladder;
- saturated connected Water has no legal move, so vented limbs never level
  (mechanism report §A, §B).

**Admission criteria versus characterization (both families).**

- **Mandatory admission criteria.** These are correctness invariants:
  - exact quantity, including overfill or whole-cell count;
  - closed ledgers;
  - 1/4-worker parity;
  - no fallback;
  - bounded writes and allocation;
  - complete physical-state hash;
  - unchanged default goldens;
  - the gas-topology expectations;
  - static-rest and momentum-ledger regressions.

  A candidate that fails any of them is invalid.
- **Characterization screens.** The physical screens below (surge, front,
  retained fraction, vented-head level difference) are recorded per arm as
  pass or fail. They are **not** admission criteria, and the owner's feel
  comparison decides preference.

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
fixtures.

**Phase convention (correction 2026-10-23, re-review finding 4).** The
MicroScenario host observes completed tick N *before* it applies the events
indexed N; those events run before native tick N+1. Every expected time below is
therefore either:
- `completed tN`: after native tick N, events indexed N not yet applied;
- `post-event tN`: after the events indexed N, before native tick N+1; not
  observable through MicroScenario observations.

An event indexed N is first observable at completed N+1. The host semantics are
unchanged. `test_lcb_physics_contracts.gd::event_boundaries` checks every event
rectangle at completed N (pre-event material) and completed N+1 (post-event
material) at 1 and 4 workers. A mutation using the old `event.tick <= tick`
reading fails 10 of those checks.


| Fixture | Requirement |
|---|---|
| `gas.single-pocket` | amount 100 constant |
| `gas.twin-pockets` | two ids, each 100, no 100,50,25… cycling |
| `gas.unequal-merge` | 100+120 at completed t0–t1; the wall erase indexed t1 merges once to 220 (post-event t1, first observed at completed t2) |
| `gas.compress-vent-reseal.v2` | volume 100 at completed t0–t1; amount 100 held at half volume (50 cells) at completed t2–t5; vented through a channel and dry U-trap with an exchange ledger at completed t6–t9; the supported trap Water plug indexed t9 reseals into a **new** 58-cell compartment at atmospheric amount, first observed at completed t10 and held to t30 (v1's unsupported roof plug is withdrawn) |
| `gas.split.v1` | one 222-cell compartment through two rooms and a dry U-trap at completed t0–t3; the supported trap fill indexed t3 splits it (post-event t3, first observed at completed t4) into two **new** ids with ancestry, volumes 108 and 111; volume-proportional floor shares 109/112, remainder 1 to the compartment holding the lowest (y, x) cell, giving 110/112; exact split ledger |
| empty-only-chunk survival | native test (Current: `LCB-001 pressure gas in Empty-only and unallocated chunks`) |
| hash change on gas-only change | Current main physical-state hash 2 (`LCB-001 pressure physical hash and exact persistence`); #245 historical source used version 1 |

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

**Laws:** one ordered update, `inertial-update-v1`
([transition matrix §5](liquid-state-transition-matrix.md#5-velocity-and-momentum-in-pf-flow);
executable contract model `tools/lcb/inertial_contract.py`). Per tick:
1. U1: the support test runs before any velocity change.
2. U2: exactly one gravity application.
3. U3: for a supported cell, either diagonal re-aim **(A)**, or support
   cancellation of this tick's gravity followed by blocked-fall deflection
   **(B)** of the velocity *carried in* from earlier ticks.
4. U4: saturation.
5. U5: damping, truncated toward zero.
6. U6: accumulator travel with a recheck of every target. The first contact
   ends travel. Wall, body mask and same-material cells block; same-material
   contact is inelastic in v1. Lighter foreign material may still exchange only
   on eligible downward moves, including when both materials select IN. Family
   equality alone does not make a foreign material an inelastic same-material
   contact.
7. U7: rest and sleep eligibility.

Properties of this update:
- **Horizontal momentum from rest comes only from (A) and (B).** There is no
  pressure or column-height term.
- **A supported cell at rest whose diagonals are blocked carries no `vy`, so
  it never drifts sideways.** If a diagonal target is eligible, U3a re-aims
  from rest by design. The mandatory static closed-pool regression is
  unchanged.
- **Eligibility is directional** (re-review N1). A lighter foreign liquid is
  entered only by a move with `dy = +1`, straight or diagonal down, which is
  the vertical density exchange of Current `can_density_exchange`. A
  horizontal move never swaps; a lighter neighbour is a horizontal contact.
- **Deflection loss** (re-review N2) is `|vx| + vy_in − |vx + s·d|`. The signed
  impulses `(s·d, −vy_in)` are booked separately.
- At a released dam, face cells whose diagonal target becomes Empty re-aim
  and gain vx. Cells that fall farther carry more speed into the turn or the
  landing, so depth dependence *can* emerge kinematically, but it is not
  guaranteed.

Ledgers:
- the **signed per-component momentum** ledger `v_after = v_before + g + Σ
  impulses` closes exactly;
- a **separate non-negative L1 speed-loss** ledger books dissipation and the
  support constraint;
- truncation remainders are audited.

Also:
- no velocity is written into foreign families;
- no Rapier force.

The worked examples (right/left deflection, negative-velocity damping,
supported rest with a free side, same-material contact, re-aim, saturation,
mid-travel contact, body-mask landing and drag) are #212's native
registrations. They are a contract model, not an executed inertial World.

**Distinguishing evidence** (must show what CellularYield cannot):

| Signature | Requirement |
|---|---|
| Residual motion after support removal | lateral travel continuing ≥ N ticks after the source stops, with N declared |
| Over-run past a step | travel beyond where the gravity-only path stops |
| Depth-dependent surge | **characterization screen, not an admission criterion**: depth response ≥ 1.25 at t240; depth-160 front ≥ 142; retained ≤ 0.70 at t1800. The result is recorded either way. |
| Static rest | **mandatory**: a fully supported closed pool keeps all velocity and accumulator components at exactly 0 and its explicit `lcb.quiescent-physical-content.v1` observation constant; complete continuation hashes retain clocks and are compared at the same completed tick ([projections](pressure-flow-v1.md#liquid-comparison-projections)) |
| Momentum ledger | **mandatory**: the per-tick identity closes exactly on the dam ladder and the lock exchanges |

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
  - isolated successor executes the [Water adapter and actual-carrier contract](inertial-cellular-v1.md#water-in-native-successor--2026-10-25) with qualified sourceaa8af247 Windows/Linux publication; final ready-PR/scientific/full-host qualification remains pending;
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

**Current on main.** The [family law](liquid-solver-family-policy.md#whole-cell-water-law-current-main)
owns executable motion and the Water material block v2 (`viscosity_index` 0..255,
default 0); the illustrative v1 flow-rate block is not its encoding.

- Water hooks (stages 1, 2, 4, 5) run with yielding motion using a **Water
  material parameter** for viscosity. It never uses `RuleKernel::YieldingLiquid`
  with Paste/Slush descriptors.
- Every Water cell holds `maximum()`. Fractional input is refused or
  normalized (`water-normalize-v1`).
- Adhesion is not applicable (declared). Coherence is honoured. Legal future
  cadence/viscosity/one-side opportunities retain deadlines; permanently blocked
  pools can sleep. Native normalization is explicit and setup-only; the Godot
  opt-in/host path remains #202. See [prepared setup](liquid-prepared-setup-and-receipts.md).

## Admission and review

Every item above is preregistered in `godot/tests/fixtures/lcb/lcb-physics-contracts.json`.
Current-family controls run in `test_lcb_physics_contracts.gd`; the registry
still records every candidate arm BLOCKED with its dependency. In the #245 pressure
reference, [`test_lcb_pressure_reference.gd`](../../godot/tests/test_lcb_pressure_reference.gd)
runs W-PF `reference` on the registered gas acceptance fixtures and scenario
geometries without changing those registry records; re-dispositioning arms
belongs to the #202 comparison host.

The pressure requirements are implemented as recorded in the
[pressure reference roadmap entry](../reference/status-and-roadmap.md#lcb-001-pressure-reference--2026-10-24);
the inertial requirements remain future work. The linked final admission
checkpoint and that entry own the accepted scope.
