---
title: LCB Water comparison contract and reference fixtures
status: Planned
document-kind: design
scope: LCB-000 Gates D and E — four-model controlled Water comparison contract, quantity normalization, supported/refused combinations, the protected lcb.dam.water.freemass.reference.v1 Dam Break fixture and the one-World mixed-liquid fixture with arm overlays, negative controls and commands
canonical-for: [lcb-water-comparison-contract, lcb-reference-fixtures]
last-reviewed: 2026-10-23
related-documents: [../architecture/liquid-solver-family-policy.md, lcb-manual-comparison-ux.md, lcb-scenario-catalogue.md, ../systems/water-design.md, microscenarios.md, experiment-tower.md, ../audits/2026-10-23-lcb000-gates-cde-design-evidence.md]
---

# LCB Water comparison contract and reference fixtures

## Status

**Planned. Proposed for LCB-000 Gates D and E
([#213](https://github.com/techrote/cybersand/issues/213)).**

- **Owner-approved:** Water must be a common controlled test material for all
  four families (#213 Gate D; #200 amendment of 2026-10-22).
- **Current and measured:** both fixtures below. They are frozen MicroScenario
  schema-2 definitions run on unchanged native Current liquids. Their
  Current-default control observations were measured on 2026-10-23
  ([evidence](../audits/2026-10-23-lcb000-gates-cde-design-evidence.md)).
- **Proposed:** every non-default family arm. None of them can execute today.
  They are registered with the configuration they will need and the
  invariants they must meet.

Families, variants, refusal codes and receipts are defined in the
[solver-family policy](../architecture/liquid-solver-family-policy.md).

## Four controlled Water settings (Gate D)

| Arm ID | Water mapping | Regime | State today |
|---|---|---|---|
| `W-FM` | `freemass_v1/reference` | protected native Current: mass8, coherence12, fractional | **executes** |
| `W-CY` | `cellular_yield_v1/reference` | **experimental whole-cell**: every Water cell is one indivisible unit; motion through the generic yielding kernel with a Water-specific viscosity parameter registered by #200 | proposed; refused today (`family_unavailable`) |
| `W-PF` | `pressure_flow_v1/{reference,cached,cached_dormant}` | experimental pressure/overfill/gas candidate, Water-only v1 | proposed (#200/#201); refused today |
| `W-IN` | `inertial_cellular_v1/reference` | experimental inertial regime with retained velocity/accumulator | proposed (#212); refused today |

Rules:

- **Everyday Water does not change.** No scene, preset, save or default maps
  Water away from `W-FM` unless a comparison policy is explicitly selected. The
  experimental settings are separate, opt-in, versioned identities.
- **Precision and coherence (corrected 2026-10-23).** Water mass precision 3–8
  and coherence 0–12 (`WaterExperimentPolicy`) apply to every arm. No arm
  quietly changes a policy axis while still calling a run matched.
  - **Mass bits:** W-CY and whole-cell W-IN v1 store exactly `maximum()` per
    Water cell for the selected mass bits. W-PF scales overfill and thresholds
    from `maximum()`. No arm hides a 255-unit assumption.
  - **Coherence:** every arm **honours** it as the material pre-motion hook. The
    `state_b` countdown decrements per update and suppresses lateral motion
    while it is above zero (see
    [material hooks](../architecture/liquid-solver-family-policy.md#material-hooks-versus-motion-gate-c-correction-2026-10-23)).
    An implementation that cannot honour it refuses with
    `water_semantics_incompatible`; it never ignores it silently.
  - **Adhesion film:** defined on fractional mass. It is **not applicable** to
    whole-cell arms, and the receipt records that as a declared difference.
- **Other liquids are not required to support every family.** Only the matrix
  rows apply.

### Water quantity normalization

- **Common comparator.** The common initial comparator is **full-cell Water**:
  every Water cell at `maximum()` (255 at mass8). This is exactly representable
  in all four regimes, so both reference fixtures use only full Water cells.
- **Fractional cells.** For a whole-cell (`W-CY`) or any regime without
  fractional support, a setup containing fractional Water is **refused**
  (`normalization_required`) unless the caller explicitly opts in to a
  registered setup conversion. The only proposed rule is
  **`water-normalize-v1` (corrected 2026-10-23)**:
  - **Rounding.** A Water cell of mass `m` (1 ≤ m ≤ `maximum()`) becomes one
    full cell (`maximum()`) when `2·m ≥ maximum()`, evaluated in at least
    32-bit arithmetic. Otherwise it becomes Empty. `maximum()` is odd for mass
    bits 3–8, so the smallest up-rounding mass is `(maximum()+1)/2`: **128/255
    rounds up and 127/255 rounds down** at mass8, and 4/7 up, 3/7 down at
    mass3. The earlier wording "`maximum()/2`" wrongly rounded 127/255 up.
  - **Per-cell signed delta.** `δ = (maximum() − m)` for an up-round, `δ = −m`
    for a down-round. Cells are visited in deterministic row-major order
    (ascending y, then x).
  - **Receipt.** The receipt holds rule ID and version, mass bits, the
    canonical setup hash and seed before and after, cells up/down/unchanged, `Σδ⁺`,
    `Σδ⁻` and the net delta, and a receipt hash that is part of the run
    receipt.
  - **Ledger.** The net delta is booked as a **declared setup-only
    source/sink** at tick 0. It is not physical conservation, and it is not a
    live hot-swap. Matched comparisons that need a conversion compare
    post-normalization states and report the delta.

  Nothing rounds or deletes partial mass silently.
- **Reverse direction.** A whole-cell or inertial Water cell entering a
  FreeMass-valued observation counts as `maximum()`.

### Compare-family identity

A run's identity is `{setup_hash, policy_hash, water_semantics, transport_hash,
interaction_policy, workers, interest/execution, platform/runtime}`.

- Tuning, player mode, rendering and optimization variant are separate fields.
- A comparison is **matched** only when every field except `policy_hash` (and,
  for variant equivalence, the variant) is identical.

## Protected Dam Break: `lcb.dam.water.freemass.reference.v1` (Gate E)

**Definition (frozen):**
[`godot/tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json`](../../godot/tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json),
MicroScenario schema 2. Its canonical definition hash, which the contract
validator returns, is `494a017b0c7c9afed6923c84608f6fbd913b7040cf40e92fb18392f2d11119bf`.
[`test_lcb_fixture_manifests.gd`](../../godot/tests/test_lcb_fixture_manifests.gd)
pins that hash, so any edit fails until a new version is registered.

| Field | Value |
|---|---|
| Selection | material Water / `freemass_v1` / `reference` / Dam Break |
| World | 1024 × 1024 MicroScenario frame; one-cell Wall bounds |
| Container | floor `x 32..992, y 256..264`; full-height walls at `x 32..40` and `x 984..992`, `y 64..256` |
| Gate | full-height removable Wall `x 232..240, y 64..256` |
| Reservoir | Water fill `x 40..232, y 96..256` (192 × 160 = 30,720 cells), normalized mass 255, coherence 0 |
| Initial quantity | **7,833,600** integer Water units (30,720 × 255), measured at tick 0 |
| Runout | dry floor `x 240..984` (744 cells) |
| Release | `erase` of the whole gate at tick 0. Tick-0 observations precede tick-0 events |
| Policies | Water `[1,8,12,0]` (mass8, coherence12, rest v1); transport **Baseline**; interaction default; adhesion on |
| Execution | `fixed`; cadence LOD **off**; interest fixed `[16,16,992,272]`; simulation window off in the runner |
| Inputs | none after tick 0 in controlled runs; no player, bodies or tools |
| Seed | 0 (the definition has no stochastic setup) |
| Horizon | 1,800 ticks |
| Observations | total Water at 0/1800; near band at 30; downstream at 60; near/middle/far bands at 120/240; reservoir at 240/480/1800 (13 total, within the area budget) |
| Conditions | `complete` if total at 1800 = 7,833,600; `fail` if reservoir at 480 exceeds the initial total. **`complete` is an accounting criterion only.** Surge and front metrics that stop a conserving but immobile candidate from passing are registered separately for #200/#212. |
| Camera / presentation | origin `[0,0]`; regions: reservoir, gate, downstream and three bands; normal rendering, no smoothing claim |

**Measured Current-default control (2026-10-23, Windows):** outcome
`complete`; 1/4-worker identical.

| Observation | Value |
|---|---:|
| total, t0 / t1800 | 7,833,600 / 7,833,600 |
| near band, t30 | 197,287 |
| downstream, t60 | 387,600 |
| near band, t120 / t240 | 426,438 / 460,855 |
| middle and far bands, t120 / t240 | 0 / 0 |
| reservoir, t240 / t480 / t1800 | 7,181,169 / 7,093,923 / 6,664,680 |
| final content hash / state hash (t1800) | `163e4c93b98320a8` / `140af7ed71e7d2e5` |

This **characterizes** Current; it is not acceptance. About 85% of the
reservoir is still behind the gate line at tick 1800, and no Water reaches the
middle band by tick 240. That matches the deep-release deficit recorded by WEX
(see the [Water contract](../systems/water-design.md)). The preset is an
unmodified oracle and is never tuned to favour a candidate.

**Companion arms** (proposed; identical setup, `policy_hash` differs):

| ID | Water mapping |
|---|---|
| `lcb.dam.water.cellular_yield.experimental.v1` | `W-CY` |
| `lcb.dam.water.pressure_flow.{reference,cached,cached_dormant}.v1` | `W-PF` |
| `lcb.dam.water.inertial.experimental.v1` | `W-IN` |

All companions use the same full-cell start, so no normalization delta
applies.

**Depth ladder** (proposed, for #45 and LCB): `lcb.dam.water.freemass.depth-{48,96,160}.v1`.
These keep the same geometry with reservoir heights 48, 96 and 160, so release
behaviour can be compared against depth. They are separate from the #49 vented
communicating-head controls and from sealed-headspace stations. Not registered
until LCB-003 builds them.

**Manual variant.** `…reference.v1/manual` reuses the same definition with
`tools:["paint","erase","player"]`. Any human input, body or tool use marks
the session **exploratory**, and it is never reported as a controlled result.

## One-World mixed liquids: `lcb.mixed.water-oil-brine.v1` (Gate E)

**Definition (frozen):**
[`godot/tests/fixtures/lcb/lcb.mixed.water-oil-brine.v1.json`](../../godot/tests/fixtures/lcb/lcb.mixed.water-oil-brine.v1.json),
canonical hash `208d488fbc3a218d61ab4468bd6fb31ddcdfde4cc44d5b2f43061dcd6f2036cc`.

**Geometry.** A basin with floor `x 64..960, y 256..264`, outer walls and
three full-height removable gates at `x 296`, `528` and `760`.

| Compartment | Contents | Density | Current family |
|---|---|---:|---|
| `x 72..296` | **Brine** whole cells (26,880) | 1120 | `cellular_yield_v1` |
| `x 304..528` | **Water** full cells (26,816) around an 8 × 8 **Salt** strip at `x 400..408, y 248..256` | 1000 | `freemass_v1` |
| `x 536..760` | **Oil** whole cells (26,880) | 800 | `cellular_yield_v1`, with Oil kernel |
| `x 768..952` | dry runout | — | — |

**Real interactions** in one native World:

- **Density exchange:** Brine undercuts Water, and Oil rides over Water.
- **Contact blocking and swaps:** lateral spreading meets the other liquids.
- **Cross-family chemistry:** `int.pair.water-salt.dissolve.v1`
  (Water+Salt → Brine+Brine) from tick 0 converts FreeMass Water into Brine.
- **Release:** all gates are erased at tick 30, producing a lock exchange into
  the runout.

**Measured Current-default control M0 (2026-10-23, Windows):** outcome
`complete`; 1/4-worker identical.

| Observation | t0 | t30 | t240 | t900 |
|---|---:|---:|---:|---:|
| Water integer, basin | 6,838,080 | 6,830,685 | — | 6,830,685 |
| Salt cells, strip | 64 | 35 | — | — |
| Oil cells | 26,880 (compartment) | — | runout 355 | 26,880 (basin); runout 1,216 |
| Brine cells | 26,880 (compartment) | — | runout 0 | 26,938 (basin); runout 0 |
| Water integer, runout | — | — | 0 | 0 |

**Reaction ledger (exact for this run):** 29 Salt cells were consumed by tick
30. Water dropped by 29 × 255 = 7,395, Brine rose by 2 × 29 = 58, and Oil was
conserved.
- **Whole-cell conversion.** The conversion removes a whole Water cell
  regardless of its mass. That is exact here only because all Water cells are
  full; partial-cell quantity semantics belong to
  [#160](https://github.com/techrote/cybersand/issues/160).
- **Final hashes.** At t900 the content hash is `d43b52e8bbaf9176` and the
  state hash `7bdf182aa1cecd70`.

**Family arms over the same geometry:**

| Arm | Water | Oil | Brine | Families active | State |
|---|---|---|---|---:|---|
| **M0** current control | `freemass_v1` | `cellular_yield_v1` (Oil kernel) | `cellular_yield_v1` | **2** | **executes; measured** |
| **M1** three-family target | `freemass_v1` | `cellular_yield_v1` | `inertial_cellular_v1` | **3** | blocked on #212 (+#200 policy) |
| **M2** pressure substitution | `pressure_flow_v1/reference` | `cellular_yield_v1` | `inertial_cellular_v1` | 3 | blocked on #200 + #212 |
| **M2b** pressure, no inertial | `pressure_flow_v1/reference` | `cellular_yield_v1` | `cellular_yield_v1` | 2 | blocked on #200 |
| **M1-alt** substitute inertial | `freemass_v1` | `cellular_yield_v1` | Toxic Sludge (32) as `inertial_cellular_v1` | 3 | **not selectable** (`not_selectable`); only if Brine fails qualification, and then with a new geometry version (sludge converts to Water on contact) |

**M0 runs only two families.** The three-family requirement is met only when
M1 executes. That depends on #212, and nothing here claims it.

**Signed reaction ledger (corrected 2026-10-23).** The frozen M0 definition
keeps its original conditions and hash (`complete` on Oil conservation, `fail`
on Water gain). The stronger checks are applied **outside** the definition, by
the fixture regression and the campaign reducer, so the protected identity is
unchanged. With `s` = Salt cells consumed, they are:

- `Δbrine = +2·s` exactly (Water+Salt→Brine+Brine);
- `Δwater = −Σ m_i` over the consumed Water cells. That lies in `[−255·s, −s]`,
  and equals `−255·s` only when every consumed Water cell was full. That is
  true for M0 by construction: 29 consumed, Water −7,395.
- after the last dissolution, the Water integer is constant. Any further
  **gain or loss** is unexplained and fails.
- Oil cells are constant;
- quantities are booked **per species** (Water integer, Brine cells, Oil cells,
  Salt cells). No cross-species "total mass" is claimed. A partially filled
  consumed Water cell is a #160 boundary event, not conservation.

**Required invariants for M1/M2** (preregistered):

- exact Oil cell count;
- the signed reaction ledger above, with each consumed Water mass booked per
  reaction;
- no velocity or overfill state survives in non-owning families;
- each reaction product starts at its family default state;
- pressure summaries are invalidated after Brine/Oil contact (#201);
- 1/4-worker parity;
- refusal of M1/M2 on a build without the families, with the M0 session kept.

**Broader scenario library.** The [scenario catalogue v1](lcb-scenario-catalogue.md)
extends these two fixtures with 25 further controlled scenarios and a
source-derived registry. It leaves both protected fixtures unchanged.

## Negative controls (registered; owners in brackets)

| ID | Control | Expected |
|---|---|---|
| NC-1 | Request `inertial_cellular_v1` for Oil | `combination_rejected` before construction; prior session intact [#200] |
| NC-2 | Request `pressure_flow_v1` or `inertial_cellular_v1` on today's build | `family_unavailable`; no fallback to Current [#200] |
| NC-3 | Fractional-Water setup under `W-CY` without an explicit `water-normalize-v1` opt-in | `normalization_required` [#200] |
| NC-4 | Pressure Water at rest beside actively flowing Oil (M2b) | Oil motion and chemistry continue; Water dormancy never suppresses them [#201] |
| NC-5 | Salt dissolution under M1 | Products at inertial default state; ledger closes as above [#212/#160] |
| NC-6 | Copy, move or swap across families (density exchange in M1/M2) | Each cell keeps only its own family state; full physical-state hash changes exactly when authoritative state does [#200/#212] |
| NC-7 | Repeat a controlled run, and 1 vs 4 workers | Identical observations and hashes (M0 measured: identical) [#200/#212] |
| NC-8 | Render presentation toggles during a controlled run | Authority, observations and hashes unchanged [#202] |
| NC-9 | Any manual paint, erase, player or body input | Session flagged exploratory; never merged into controlled results [#202] |
| NC-10 | Load a CYSD1 level into a non-default policy | All liquids on defaults, or a declared refusal; no silent remap [#200] |

**Manual versus controlled runs.**
- *Controlled* runs use the frozen definition, `execution.policy = fixed`,
  scheduled events only, and isolated sequential timing (#203).
- *Manual exploratory* sessions reuse the same setup with tools, player,
  bodies and live painting, and record that they are exploratory.
- Side-by-side views are visual aids only, never timing evidence.

## Reproducible commands

Run from the repository root with the pinned Godot 4.7 and a source-matched
native runtime. The definition path must be absolute.

```bash
godot --headless --path godot --script res://tests/run_microscenario.gd -- --definition=<abs>/godot/tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json --ticks=1800 --workers=1 --output=<abs>/dam-w1.json --source-sha=<40-hex>
```

```bash
godot --headless --path godot --script res://tests/run_microscenario.gd -- --definition=<abs>/godot/tests/fixtures/lcb/lcb.mixed.water-oil-brine.v1.json --ticks=900 --workers=1 --output=<abs>/mix-w1.json --source-sha=<40-hex>
```

```bash
godot --headless --path godot --script res://tests/test_lcb_fixture_manifests.gd
```

```bash
python tools/lcb/derive_capability_matrix.py --check
```

Repeat the runner commands with `--workers=4` for parity. The runner is
native-only: it refuses player- or body-enabled definitions and does not
exercise Rapier or rendering. The full-host manual variant belongs to
[LCB-003 #202](https://github.com/techrote/cybersand/issues/202).
