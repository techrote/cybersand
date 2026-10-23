---
title: LCB physics mechanism report — Current liquid behaviour explained against source
status: Current
document-kind: evidence
scope: LCB physics prepass — source-qualified explanation of the PR #217 measured Current behaviour (deep release, communicating heads, rest/activity, reaction accounting, liquid specialization) with measured outcome, source explanation, rejected/unverified hypotheses, missing measurements and design impact for #200/#212
canonical-for: [lcb-physics-mechanism-report]
last-reviewed: 2026-10-23
related-documents: [../architecture/liquid-state-transition-matrix.md, ../architecture/lcb-pressure-inertial-handoff.md, ../architecture/liquid-solver-family-policy.md, ../operations/lcb-scenario-catalogue.md, 2026-10-23-lcb003-scenario-qualification.md]
---

# LCB physics mechanism report

## Identities and scope

- **Native source:** `world.cpp`, `material.hpp`, `material_rules.cpp` and
  `interaction_rules.hpp` at `9012425`, unchanged at main `4caa2c3`. Line
  numbers below refer to that source.
- **Runtime:**
  - Windows GDExtension `e6d9ec7d…6045f`, native-source-matched (PR #215
    record);
  - Godot `4.7.stable.official.5b4e0cb0f`;
  - local Windows 11 workstation, native-only headless.
- **Measurements:**
  - PR #217 controls (`lcb-scenario-controls-2026-10-23.json`, 27 scenarios,
    1/4-worker identical);
  - new diagnostics from `godot/tests/run_lcb_mechanism_diagnostics.gd`,
    retained as [mechanism-diagnostics.jsonl](lcb-physics-prepass-2026-10-23/mechanism-diagnostics.jsonl)
    (SHA-256 `d2d4fefd…8105`, 97 s);
  - `test_lcb_physics_contracts.gd`: 112 assertions, 0 failures at first
    publication. After the #226 review hardening it is 131/0: every tick is
    checked, there are state-hash pins, and the reseal v2 control is added.
  - The hardened diagnostics runner reproduces the retained output byte for
    byte.
- **Scope:** characterization of Current behaviour only. A conserving result
  is **not** treated as physically good behaviour. No candidate solver ran.

Labels used below:

| Label | Meaning |
|---|---|
| **M** | measured |
| **S** | source-supported explanation |
| **H** | hypothesis (tested and rejected where noted) |
| **G** | missing measurement |
| **I** | impact on solver design |

## A. Deep Water releases weakly, with a weak depth response

**M.**
- **Front distance** from the gate face (x=240) on the floor row, from
  `front-vs-time`:

  | Depth | t15 | t30 | t60 | t120 | t240 | t480 | t960 | t1800 |
  |---|---:|---:|---:|---:|---:|---:|---:|---:|
  | 48 | 6 | 20 | 34 | 48 | 67 | 92 | 128 | 175 |
  | 96 | 6 | 20 | 34 | 49 | 70 | 97 | 135 | 185 |
  | 160 | 6 | 20 | 34 | 49 | 71 | 100 | 140 | 191 |

- **Growth law:** between t120 and t1800 the front grows as t^0.478, t^0.491
  and t^0.502 for depths 48, 96 and 160. That is **approximately diffusive**
  (close to t^½) on these fixtures, not ballistic.
- **Released mass per reservoir row at t1800:** 7,870 (48), 7,801 (96) and
  7,306 (160). Release is roughly proportional to the number of rows, so the
  retained fraction has only a **weak depth response** (0.839, 0.841, 0.851) on
  these three fixtures. That is not exact depth independence; the retained
  fraction rises slightly with depth.
- **Surfaces:**
  - the reservoir surface at x=100 drops only 1 row (depth 48) to 9 rows
    (depth 160) in 1800 ticks;
  - at the gate column (x=236) a step persists, 65–70 rows below the depth-160
    reservoir surface: the "slow slope" the owner sees.
- **Bulk does not move:** the mass-weighted Water centroid at t240 is 138.35
  (depth 48) and 139.20 (depth 160), barely past the reservoir centre (136).

**S.**
- **Same-row diffusion.** Lateral motion in `update_water` is `level_with`
  (L2698–L2720): each cell moves ¾ of the positive mass difference to an
  Empty/Water neighbour **on the same row**, within `tolerance()`, one
  neighbour per side per update. That is a discrete diffusion step, and there
  is no pressure, head or velocity term anywhere.
- **Gravity only fills capacity below.** Gravity (L2663–L2682) moves mass
  down or diagonally only into capacity (`transfer_water` caps at
  `maximum()−destination`, L2516–L2519). A full column therefore cannot
  accelerate the cells beneath it.
- **Consequence** (inference from the source above and the three measured
  depths; not a general proof): each exposed row of the reservoir face leaks
  into the runout by row-local diffusion. Total discharge therefore grows
  roughly in proportion to depth, so the retained fraction responds only
  weakly to depth. The front grows approximately diffusively, with a weak depth
  response (t240 fronts 67/70/71), rather than the ~√h scaling of a ballistic
  dam-break front.

**H (tested, rejected).** The supported-film adhesion threshold
(L2689–L2695) was suspected of stalling the thin runout front. Turning
adhesion off changed reservoir mass at t1800 by +234 (depth 48) and 0 (depth
160), and band-2 mass at t1200 by +372 / +357 units. It is not the cause.

**H (unverified).** The ¾ rule's choice between the two lateral sides in a
fixed per-cell direction (`deterministic_direction`) slightly favours some
columns. Its effect on front shape is unmeasured.

**G.**
- No per-row face flux time series.
- No front-position metric inside the MicroScenario contract: the
  diagnostics use a native `material_at` scan.
- No comparison with a dam-break analytic profile.

**I.**
- The frozen screens test depth response and front distance, not mass alone
  (see `lcb-physics-contracts.json`).
- Mass conservation by itself is satisfied by the nearly immobile Current
  behaviour.

**H (not tested).**
- A head/pressure term (`pressure_flow_v1`) and retained velocity
  (`inertial_cellular_v1`) are the two mechanisms that LCB registers for
  turning column height into lateral motion.
- They are **not** shown to be the only ways to improve deep release. Other
  rule changes could also alter it, and none was ablated. Examples:
  - a different lateral relaxation fraction or tolerance;
  - lateral reach of more than one cell per update;
  - different gravity/diagonal capacity rules.

## B. Vented communicating limbs never move

**M.**
- In `lcb.head.vented-two-limb.v1`, `narrow-passage` and the roofed variant,
  zero cells move in 2,400 ticks. The content hash is constant from tick 0 and
  the limb difference stays 120.0 rows.
- 1/4-worker identical.
- Vented and roofed limbs are indistinguishable in Current, with the same limb
  masses (1,860,480 / 391,680).

**S.** Every Water cell in these fixtures is full (255), and every legal
Current move is blocked:

- **Down and diagonal:** the target is full Water (`transfer_water` capacity
  0) or Wall.
- **Lateral:** the neighbour is equal-mass full Water (`source ≤ target +
  tolerance`) or Wall.
- **Upward:** no rule moves Water up. The low limb's surface cells have only
  Empty above.

The passage is saturated, so no cell has destination capacity. The outcome is
therefore independent of gravity order, scheduling, worker count and passage
width. Fixture geometry (full cells only, a fully filled roofed passage) makes
this exact.

**H.** A partially filled passage would show transient lateral exchange but
still no head transmission. The small early movement in #49 v2's two-limb
fixture may come from such non-saturated setup cells. Both points are
unverified here.

**G.** No vented fixture with partial passage fill and no
sealed-gas-capable runtime.

**I.**
- Vented equalization needs transmission through saturated cells. That is a
  pressure-family responsibility, screened by the vented-head contract
  (≤12-row difference at t2400 for the 8-row passage).
- Non-pressure families (inertial, whole-cell) are not required to equalize.
- Sealed targets need gas state: Current results on roofed limbs are
  explicitly *not* sealed controls.

## C. A resting pool keeps "active" chunks without doing work

**M.**

| Interest region | Tick 4–20 visited cells | Scheduled cores | Retained active blocks / chunks |
|---|---:|---:|---|
| `[0,0,1024,1024]` (full frame) | 0 | 0 | 0 / 0 |
| `[16,16,992,272]` (PR #217 fixture) | 0 | 0 | 74 / 18 |
| `[40,96,944,160]` (pool only) | 0 | 0 | 144 / 32 |

- In every case the pool is visited only on ticks 1–3. That matches
  `sleep_after_quiet_ticks = 3`.

**S.**
- `active_blocks_after` and `active_chunks` count blocks still flagged active,
  not blocks scheduled.
- With full-frame interest all blocks sleep. Narrower interest leaves more
  boundary blocks flagged but **unscheduled**: material-bearing blocks that
  straddle the fixed interest edge, such as walls, floor and world bounds.
  This is interest-edge pause retention, not liquid work.
- The 18 chunks in PR #217 are therefore **conservative activity retention
  with zero simulation work**, not avoidable per-tick work.

**H.** These blocks are paused rather than asleep, and should wake on interest
re-entry without a lost update. This rests on the existing pause/re-entry
contract, not re-measured here.

**G.** Per-block reason codes are not exposed: `inspect_statistics` lists
per-cell sleeping status as unavailable.

**I.**
- Dormancy (#201) must measure **visited cells and scheduled cores**, not the
  active-chunk counters.
- Pressure caches must survive interest-edge pause without treating paused
  blocks as resting Water.
- Wake on interest re-entry is an invalidation trigger in the transition
  matrix.

## D. Reaction accounting: the Salt gap and the Steam gain

**M.**
- **Salt dissolution:** all 2,048 Salt cells are gone by t120, Brine is
  exactly 4,096 (= 2·2,048), and Water fell by **514,527** rather than
  2,048·255 = 522,240. The 7,713-unit gap is pinned in
  `test_lcb_physics_contracts.gd`.
- **Mixed M0:** 29 Salt consumed, Water −7,395 = −29·255 (all consumed cells
  full), Brine +58.
- **Sodium/Oil/Fire:** world Water **rises** by 6,547 by t900.

**S.**
- **Pair chemistry runs before the kernel switch.** In `update_rule_kernel`,
  L2797–L2826 writes both products at their descriptor defaults, using
  `maximum()` only when a product is Water. The consumed Water cell's
  `state_a` is discarded whatever its mass. Water+Salt→Brine+Brine is
  `int.pair.water-salt.dissolve.v1`.
- **Salt gap.** The reacting Water cells near the falling Salt were partially
  filled (mean 251.2), so the loss is the sum of their actual masses, not 255
  per reaction.
- **Steam gain.** Steam expiry writes Water at `maximum()` (L2849). A partial
  Water cell that becomes Steam through Water+Sodium or Fire+Water comes back
  full. That is exactly #160's amplification defect, still present on main.

**Reconciliation with #160 / PR #162.**
- PR #162 (head `19f7ff43`, based on `ec05d72`, CONFLICTING, unmerged) keeps
  Water quantity across Steam/Ice/charged-Metal phase conversions and scales
  Lava/Molten Glass quench.
- It explicitly leaves Brine/Salt/Sodium/Sludge as whole-cell chemical
  source/sink boundaries (`docs/audits/2026-10-18-mat002-phase-quantity.md`
  on that branch).
- The Salt gap is therefore **outside** #162's change and inside #160's
  declared boundary. The Sodium/Steam gain is the case #162 would change.
- Neither is a Current regression. LCB must book both as signed source/sink
  events and must not count on #162 until it lands on a reconciled base.

**G.**
- No per-reaction event log: the deficit is inferred from totals.
- No measurement of #162's behaviour on the current base.

**I.**
- Experimental families must emit per-reaction signed ledgers.
- Product cells start at their family default state.
- No test may claim cross-species conservation.
- If #162 lands first, regenerate affected goldens as new versions, never
  silently.

## E. Liquid specialization: what actually differs

**M.**
- **Runout fraction at t1200** (`viscous.lane-gallery`):

  | Brine | Water | Mercury | Oil | Slush | Paste |
  |---:|---:|---:|---:|---:|---:|
  | 0.486 | 0.414 (mass-weighted, not comparable with cell counts) | 0.395 | 0.354 | 0.253 | 0.204 |

- **Pour heaps:** only Paste retains a raised heap (61 cells in the high
  band).
- **Inverted column:** sorts by t600, with a persistent residual of 26 Oil
  and 5 Brine cells in the middle third.
- **Lock exchanges:** Water undercuts Oil, and Brine undercuts Water.

**S.**

| Mechanism | Liquids | Source |
|---|---|---|
| Fractional pairwise transfer, ¾ relaxation, coherence, adhesion | Water only | `update_water` L2650 |
| Generic whole-cell yielding with a **viscosity roll**: mobility `(256−viscosity)/256` per update, both lateral sides tried | Paste (240), Slush (192), Brine (32), Toxic Sludge (64), Mercury (96, diagnostic override) | `flow_as_yielding_liquid` L2779–L2795 |
| Same yielding motion after a lifecycle | Cement (176), Molten Glass (224) | L3062, L3114 |
| Whole-cell lateral move with **no viscosity roll**; the lateral probe is one-sided (`try_lateral` → `x + direction`, L2644–L2648). Order per kernel below | Oil, Lava, Acid | L3191–L3230, L3117–L3134, L3151–L3176 |
| Density exchange only with a vertical delta (no sideways swap); Oil never swaps with powders | all liquids | `MaterialRules::can_density_exchange` |

**Dispatch order for the specialized kernels (S).** Generic pair chemistry runs
for every liquid **before** the `RuleKernel` switch (`has_pair_reactions`
block, L2797–L2826). Inside the switch:

| Kernel | Order after the generic pair chemistry |
|---|---|
| Oil (L3191–L3230) | kernel ignition/burn, then extinguish/burn-down lifecycle; then down, both diagonals, one-sided lateral; never density-swaps (`swap = false`) |
| Lava (L3117–L3134) | kernel contact sample (Ice → Water, or ignite); then down, both diagonals, one-sided lateral (`swap = true`) |
| Acid (L3151–L3176) | **movement first**: down, a single diagonal (`x + direction`), one-sided lateral. The corrosion lifecycle runs only after every movement attempt has failed, because a successful move returns |

The earlier wording "kernel chemistry first" was wrong for Acid; it is
corrected here (re-review finding 5).

- The measured lane ordering among the yielding liquids is monotone in
  mobility: Brine 224 > Mercury 160 > Slush 64 > Paste 16.
- **S:** Oil's `viscosity_index` of 160 is **not consulted** by the Oil kernel.
- **H (no ablation run):** Oil spreads more slowly than Brine (0.354 vs 0.486
  runout). Its one-sided lateral attempt is the leading hypothesis. That was
  not isolated from the other differences:
  - Brine tries both sides with mobility 224/256;
  - Oil never density-swaps;
  - the two have different densities and different kernel lifecycles.

  An ablation, the same geometry with a two-sided Oil probe, is **missing**.
- Baseline transport's Mercury `permeability: 30` is a powder→liquid pair
  period, not Mercury's lateral cadence.

**H.**
- Initial runout for Paste is dominated by gravity/diagonal collapse, which no
  viscosity roll gates, rather than by lateral yield.
- The inverted-column residual comes from vertical-only density exchange
  trapping single cells.
- Neither is measured per mechanism.

**G.** No per-mechanism counters (gravity moves versus lateral moves versus
swaps) per material.

**I.**
- "Faster CellularYield" is not inertia: viscosity changes a per-update
  probability, not retained motion. `inertial_cellular_v1` must carry
  velocity between ticks (see the handoff).
- Oil, Lava and Acid keep their kernels: their lateral law is part of the
  specialization, and v1 does not admit them to other families.
- Mixed-family boundaries keep vertical-only density exchange unless a family
  registers a new, tested law.

## Summary for admission review

| Finding | Mechanism | Blocks LCB? |
|---|---|---|
| A | No head term; row-local diffusion; approximately diffusive front with a weak depth response on these fixtures | No. It motivates W-PF/W-IN screens. |
| B | Saturation removes all legal moves | No. Vented and sealed targets are pressure-family contracts. |
| C | Interest-edge retained flags, zero work | No. Dormancy must use work counters. |
| D | Whole-cell reaction products; #160 amplification still on main | No. Requires signed ledgers; #162 not assumed. |
| E | Motion law per kernel; viscosity only in yielding liquids | No. Specialized kernels stay on defaults. |

None of these findings is a Current regression, and none changes a frozen
PR #217 golden.

## Addendum — re-review corrections (2026-10-23)

Responds to the [independent re-review](https://github.com/techrote/cybersand/pull/226#issuecomment-6362824493)
of `31e4ef4`. The measurements above are unchanged. Only the claims and
contracts are corrected.

| Finding | Correction | Evidence class |
|---|---|---|
| 2 (P1) inertial ledger/order | One ordered update, `inertial-update-v1`, is defined in [transition matrix §5](../architecture/liquid-state-transition-matrix.md#5-velocity-and-momentum-in-pf-flow). It carries signed per-component impulses and a separate non-negative L1 speed-loss ledger. Support cancels this tick's gravity before deflection, so a supported cell at rest never drifts. One inelastic contact rule covers Wall, body mask and same family. | Standalone contract model (`tools/lcb/inertial_contract.py`; 13 tests at `efc5c12`; the sweep executes 787,320 updates, not the 393,660 first stated, which re-review N5 corrected). **No inertial World executed.** |
| 4 (P2) gas phases | `completed(N)` and `post_event(N)` phases are defined. Every expectation and `inspect_at_completed` value now uses completed ticks. Each event rectangle is checked at completed N and N+1 at 1 and 4 workers. Geometry and amounts are unchanged. | Current geometry control, executed locally (`test_lcb_physics_contracts.gd` 174/0). A mutation using the old `<=` reading fails 10 checks. |
| 5 (P3) qualifications | Section A now says "approximately diffusive" and "weak depth response". Pressure and retained velocity are no longer claimed to be the only possible deep-release fixes; that is a hypothesis with no ablation. The Oil-vs-Brine attribution is a hypothesis, and its missing ablation is named. The kernel dispatch order now covers Oil, Lava and Acid; for Acid, movement comes first and corrosion follows movement attempts (L3151–L3176). | Source reading at `e5baca0` (`world.cpp`) |

Gas-phase observations (Current geometry, completed ticks):
- compression fill indexed t1: Empty at t1, Water at t2;
- vent erase indexed t5: Wall at t5, Empty at t6;
- reseal fill indexed t9: Empty at t9, Water at t10;
- split fill indexed t3: Empty at t3, Water at t4;
- merge erase indexed t1: Wall at t1, Empty at t2.

These match the reviewer's independent probe for the first four.

## Addendum — inertial N1/N2/N5 corrections (2026-10-23)

This responds to the [second re-review](https://github.com/techrote/cybersand/pull/226#issuecomment-6364909265)
of `efc5c12`. The measurements above are unchanged.

| Finding | Correction | Evidence class |
|---|---|---|
| N1 (P2) | Eligibility is directional for support, re-aim, side selection and every travel move. A lighter foreign liquid is entered only by a `dy = +1` move: straight or diagonal down, which is Current's vertical density exchange. A horizontal move into it is a contact. A DDA sub-step needing both axes is first tried as one diagonal move. The reviewer's case `["#####", "#Wo.#", "#####"]` with `Cell(1,1,20,0)` now makes horizontal contact (vx 0, no drag, no move). | Contract model; 23 tests |
| N2 (P2) | The U3b loss is `|vx| + vy_in − |vx + s·d|`, booked separately from the signed impulses `(s·d, −vy_in)`. The reviewer's case `(40, 32)` deflecting left books 56. Aligned and opposing cases on both sides are registered and tested against independently computed values. "Never drifts" is qualified to the diagonally blocked case. | Contract model |
| N5 (P3) | The sweep count is 3⁸ × 5 × 4 × 3 × 2 = 787,320 updates; 393,660 was wrong. The sweep now also asserts swap direction. It is not offered as proof of the written formula; the analytic tests cover that. | Executed (Python) |

No inertial World has executed. The boundary law in §E is unchanged: vertical
density exchange only.

**R5 follow-up (2026-10-23).** This responds to the
[re-review](https://github.com/techrote/cybersand/pull/226#issuecomment-6366526752).
The generated #212 native registration in the `inertial-update` contract
still demanded zero velocity for "a supported cell with a free side". That
requirement is now split into three registrations:
- the mandatory static closed pool;
- a supported cell **initially at rest with both diagonals blocked**;
- a cell at rest with an eligible diagonal, which re-aims by design (U3a,
  `reaim-from-rest`).

The registry is regenerated. A regression (`test_native_rest_registration_is_qualified`)
pins the qualification and the reviewer's case
`["#####","#.W..","###.."]`, `Cell(2,1,0,0)` → `vx = vy = 2`. The deflection
formula is unchanged.
