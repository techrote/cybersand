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

## A. Deep Water releases weakly, independent of depth

**M.**
- **Front distance** from the gate face (x=240) on the floor row, from
  `front-vs-time`:

  | Depth | t15 | t30 | t60 | t120 | t240 | t480 | t960 | t1800 |
  |---|---:|---:|---:|---:|---:|---:|---:|---:|
  | 48 | 6 | 20 | 34 | 48 | 67 | 92 | 128 | 175 |
  | 96 | 6 | 20 | 34 | 49 | 70 | 97 | 135 | 185 |
  | 160 | 6 | 20 | 34 | 49 | 71 | 100 | 140 | 191 |

- **Growth law:** between t120 and t1800 the front grows as t^0.478, t^0.491
  and t^0.502 for depths 48, 96 and 160. That is **diffusive** (t^½), not
  ballistic.
- **Released mass per reservoir row at t1800:** 7,870 (48), 7,801 (96) and
  7,306 (160). Release scales with the number of rows, so the retained fraction
  is depth-independent (0.839, 0.841, 0.851).
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
- **Consequence:** each exposed row of the reservoir face leaks into the
  runout by row-local diffusion. Total discharge grows linearly with depth, so
  the retained fraction stays constant, and the front speed carries no √h
  dependence.

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
- A candidate fixes deep release only by adding a head/pressure term
  (`pressure_flow_v1`) or retained velocity (`inertial_cellular_v1`) that
  converts column height into lateral acceleration.
- The frozen screens therefore test depth response and front distance, not
  mass alone (see `lcb-physics-contracts.json`).
- Mass conservation by itself is satisfied by the immobile Current behaviour.

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
| Whole-cell lateral move with **no viscosity roll**, one side only, kernel chemistry first | Oil (burn/extinguish), Lava, Acid | L3191–L3230, L3117–L3190 |
| Density exchange only with a vertical delta (no sideways swap); Oil never swaps with powders | all liquids | `MaterialRules::can_density_exchange` |

- The measured lane ordering among the yielding liquids is monotone in
  mobility: Brine 224 > Mercury 160 > Slush 64 > Paste 16.
- Oil's `viscosity_index` of 160 is **not consulted** by the Oil kernel. Its
  slower spread than Brine comes from its one-sided lateral attempt, not from
  viscosity.
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
| A | No head term; row-local diffusion | No. It motivates W-PF/W-IN screens. |
| B | Saturation removes all legal moves | No. Vented and sealed targets are pressure-family contracts. |
| C | Interest-edge retained flags, zero work | No. Dormancy must use work counters. |
| D | Whole-cell reaction products; #160 amplification still on main | No. Requires signed ledgers; #162 not assumed. |
| E | Motion law per kernel; viscosity only in yielding liquids | No. Specialized kernels stay on defaults. |

None of these findings is a Current regression, and none changes a frozen
PR #217 golden.
