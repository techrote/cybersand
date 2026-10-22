---
title: Liquid solver family policy and API specification
status: Planned
document-kind: design
scope: LCB-000 Gate C proposal — versioned four-family liquid solver identities, immutable per-World per-material policy, construction/readback/refusal contracts, source-derived capability matrix and cross-issue mapping for LCB-001..005; nothing here is implemented
canonical-for: [liquid-solver-family-policy]
last-reviewed: 2026-10-23
related-documents: [../systems/water-design.md, ../systems/materials-and-rule-kernels.md, ../systems/flow-transport-and-profiles.md, ../decisions/ADR-005-water-model.md, ../operations/lcb-water-comparison-and-fixtures.md, ../operations/lcb-manual-comparison-ux.md, ../audits/2026-10-23-lcb000-gates-cde-design-evidence.md]
---

# Liquid solver family policy and API specification

## Status

**Planned design, proposed for LCB-000 Gate C
([#213](https://github.com/techrote/cybersand/issues/213)).** Nothing below
is implemented. No API, enum, packed array or UI control named here exists in
source today.

- The only liquid behaviour that executes today is each material's
  **current default** in the
  [capability matrix](../reference/liquid-solver-capability-matrix.json).
- Implementation belongs to LCB-001
  [#200](https://github.com/techrote/cybersand/issues/200) (policy, state and
  pressure) and LCB-005 [#212](https://github.com/techrote/cybersand/issues/212)
  (inertial).
- Durable state width, sidecars and save schema are **Gate B**, owned by the
  active MAT-003PREPASS work [#204](https://github.com/techrote/cybersand/issues/204).
  This page only lists what each family would need. It freezes nothing.

Claim labels used below:

| Label | Meaning |
|---|---|
| **Current** | Source fact, with a locator |
| **Owner-approved** | Recorded owner decision in #200/#213 |
| **Proposed** | This Gate C design; awaiting review |
| **Deferred to B** | Depends on the #204 storage handoff |

## What exists today (Current)

- **Two motion families, one per descriptor.** `LateralFlowMode` in
  [material.hpp](../../native/include/cybersand/material.hpp) has `None`,
  `FreeMass` and `CellularYield`. Each `MaterialDefinition.lateral_flow` is fixed
  at compile time.
  - Water (ID 3) is the only `FreeMass` material, run by `World::update_water`.
  - Ten liquids are `CellularYield`: Lava 8, Acid 12, Oil 16, Paste 20, Slush 21,
    Brine 24, Cement 30, Toxic Sludge 32, Mercury 33, Molten Glass 36.
  - Their kernels add specializations ([world.cpp](../../native/src/world.cpp)
    `World::update_cell` → `RuleKernel` switch): Oil burn/extinguish, Lava, Acid,
    Cement cure and Molten Glass cooling. Paste, Slush, Brine, Toxic Sludge and
    Mercury use the generic `flow_as_yielding_liquid`; Mercury also has a
    diagnostic viscosity override.
- **Construction-time policies follow one pattern.** `WorldConfig` in
  [world.hpp](../../native/include/cybersand/world.hpp) carries
  `WaterExperimentPolicy` (versioned, validated, immutable; 3–8 mass bits, 0–12
  coherence) and `TransportPolicy` (packed, construction-only). Both reach
  Godot through `CyberDemoBridge::build_water_feel_world`
  ([cyber_demo_bridge.hpp](../../godot/native_extension/cyber_demo_bridge.hpp)).
  Invalid values throw before `install`, so the previous World survives.
- **Effective readback exists for Water only.**
  `CyberNativeCellWorld::get_water_experiment_policy` returns the applied Water
  policy. Nothing reports a per-material motion family.
- **Liquids already meet in one World.** Density exchange (`DensityMotion`,
  `accepts_density_exchange`) and pair rules
  ([interaction_rules.hpp](../../native/include/cybersand/interaction_rules.hpp))
  act between liquids today. Examples: `int.pair.water-salt.dissolve.v1`, and
  Oil extinguished by Water inside the Oil kernel.

## Identities (owner-approved catalogue; Proposed encoding)

| Family ID | Physics | Owner | Executes today |
|---|---|---|---|
| `freemass_v1` | Current fractional conserved pairwise Water | existing source | Yes, Water only (default) |
| `cellular_yield_v1` | Current whole-cell yielding motion plus kernel specializations | existing source | Yes, 10 liquids (default) |
| `pressure_flow_v1` | Corrected pressure/overfill/flow/gas | #200 | No |
| `inertial_cellular_v1` | Non-pressure motion with retained velocity/accumulator | #212 | No |

**Implementation variants** (an axis independent of family):

- `reference` for every family;
- `cached` and `cached_dormant` for `pressure_flow_v1` only (#201).

Variants must produce identical physics or a registered bounded tolerance. They
never count as families.

**Legacy arm aliases** resolve to one Water assignment and nothing else:

| Alias | Water mapping |
|---|---|
| `current` | `freemass_v1/reference` |
| `pressure` | `pressure_flow_v1/reference` |
| `pressure_cached` | `pressure_flow_v1/cached` |
| `pressure_dormant` | `pressure_flow_v1/cached_dormant` |

All other materials keep their defaults under every alias.

**Proposed wire encoding** (numeric codes are append-only; the string IDs are
canonical):

| Family | Code | Variant | Code |
|---|---|---|---|
| `freemass_v1` | 1 | `reference` | 0 |
| `cellular_yield_v1` | 2 | `cached` | 1 |
| `pressure_flow_v1` | 3 | `cached_dormant` | 2 |
| `inertial_cellular_v1` | 4 | | |

Code 0 is reserved for "material default" and is never stored as an
effective value.

## Separate axes (Proposed contract)

A comparison setup is the tuple below. **No axis implies another.**

| Axis | Owner today | Changes physics? |
|---|---|---|
| material assignment / scenario recipe | MicroScenario contract | yes (setup) |
| **solver family per material** | *new* `LiquidSolverPolicy` | yes |
| **implementation variant per material** | *new* `LiquidSolverPolicy` | no (equivalence required) |
| Water semantics (mass bits, coherence) | `WaterExperimentPolicy` | yes, Water only |
| transport/viscosity/cadence/pair tuning | `TransportPolicy` | yes |
| interaction policy | `InteractionPolicy` | yes |
| scheduler/workers/interest/cadence LOD | `WorldConfig`, host execution | determinism-relevant |
| player/actor/environment/depth | Godot owners | via coupling only |
| presentation (coverage, overlays, smoothing) | Godot | **never** |

## Native policy object (Proposed)

`LiquidSolverPolicy` sits beside `WaterExperimentPolicy` in `WorldConfig`. It
copies that type's discipline: validate on construction, immutable once inside
a World, equality-comparable and versioned.

```text
LiquidSolverPolicy v1
  version                      = 1
  catalogue_digest             : sha256 of the material descriptor table it was validated against
  capability_matrix_digest     : sha256 of the capability-matrix sources (derivation tool output)
  assignments[material_id]     : { family_code, variant_code }   // only for liquid descriptors; others must be default
  family_parameters[family]    : opaque versioned blob owned by that family (e.g. inertial damping); hashed
  policy_hash                  : sha256 over canonical (version, catalogue_digest, assignments, family_parameters)
```

- **Default.** A default-constructed policy assigns every liquid its current
  default (`freemass_v1/reference` for Water, `cellular_yield_v1/reference`
  for the other ten). It **must be bit-identical in behaviour to today**:
  golden hashes, the #49 v2 control and the LCB Dam Break reference stay
  unchanged.
- **Packed transport.** The policy crosses the C API, GDExtension and Web as a
  `PackedInt32Array` header plus triples:
  `[version, count, (material_id, family_code, variant_code) × count]`, with the
  family-parameter blobs as a separate packed array. This mirrors
  `water_semantics`/`TransportPolicy::unpack`. No strings, parsing or allocation
  happen in native jobs.
- **Kernel dispatch.** Family dispatch happens where `update_cell` now switches
  on `RuleKernel`. Material identity, `RuleKernel` chemistry, temperature,
  lifecycle and density stay with the material. The family owns **only motion
  and quantity transport**: gravity order, lateral transfer and the family's
  extra state. Each kernel keeps its non-motion behaviour, for example Oil
  burn/extinguish, under every admitted family.

### Validation and refusal (Proposed)

Validation runs **before** any World is built or replaced. Any failure returns
a typed refusal and leaves the live session untouched, as
`build_water_feel_world` does today.

| Code | Condition |
|---|---|
| `unknown_material` | ID outside the catalogue or reserved (10) |
| `not_a_liquid` | assignment to a non-liquid descriptor |
| `unknown_family` / `unknown_variant` | code not in this build's catalogue |
| `family_unavailable` | family not compiled/qualified in this build (true today for `pressure_flow_v1` and `inertial_cellular_v1`) |
| `combination_rejected` | matrix status `rejected` for that material×family |
| `variant_unsupported` | variant not offered by that family |
| `water_semantics_incompatible` | family cannot honour the requested Water mass bits/coherence |
| `platform_unsupported` | family/variant not qualified on this platform (Web profile, GDScript fallback) |
| `capacity_refused` | family scratch/state budget cannot be prepared for this World size |
| `stale_capability_matrix` | `catalogue_digest` differs from the running catalogue |

There is **no hidden fallback**. A refused or unavailable family is never
replaced by Current, another family or the GDScript fallback. The GDScript
fallback reports every non-default assignment as `platform_unsupported`.

### Effective readback (Proposed)

`World::liquid_solver_policy()` returns the applied policy. It surfaces as:

- C API: `cybersand_world_liquid_policy_v1(world, out_packed, capacity)` plus
  `policy_hash`;
- GDExtension: `CyberNativeCellWorld.get_liquid_solver_policy()` →
  `{version, policy_hash, catalogue_digest, assignments:[{material, family, variant}], refusals:[]}`;
- desktop worker and Web bridge.

Every World constructor named in #202 reports the same receipt: desktop async
worker, Web bridge, MicroScenario replacement, player material modes, physical
arenas, generation previews, depth/exhibition/semantic planes and save/load
rebuilds. A frozen depth plane reports `configured_inactive`. A UI label is
never the source of truth; the receipt is.

### Construction, restart and transaction (Proposed)

1. **Validate** the requested policy against the matrix and this build. No
   side effects.
2. **Reconstruct** the same retained setup (recipe, seed, edits or imported
   level, schedule, actor/loadout, Water/transport/interaction policy, interest,
   plane clocks) into a *new* World with the new policy.
3. **Commit** at the owner boundary: desktop worker, Web main thread, or the
   MicroScenario `install`. Only then is the old World released.

Refusal or cancellation at any step keeps the old session and returns the
refusal code. **No mid-flow hot switching:** converting live cells between
families is not supported. A later *qualified* converter would need its own
registration and lossless proof. #200 freezes the receipt fields: requested
policy, applied policy and hash, setup hash, refusal (if any) and tick 0.

## State ownership per family

Field-level needs only, as input to Gate B. Width, sidecar and save decisions
are **Deferred to B (#204)**.

| Family | Authoritative state beyond material/state_a/state_b | Current/Proposed |
|---|---|---|
| `freemass_v1` | none: `state_a` = Water mass (policy-scaled), `state_b` = coherence delay | Current |
| `cellular_yield_v1` | none beyond kernel use: Oil `state_b` burn, Cement/Molten Glass lifecycle, `initial_state_a` per descriptor | Current |
| `pressure_flow_v1` | overfill quantity, signed horizontal velocity, gas pocket identity/generation and amount, derived per-tick head (scratch, not state) | Proposed (#200); 7ef2aac used bits 40–55, which #204 has not assigned |
| `inertial_cellular_v1` | signed vx/vy (or momentum), subcell accumulator, saturation/rounding rules | Proposed (#212) |

Rules every family must meet, which become Gate B and #200 acceptance:

- every authoritative field is covered by a **versioned complete physical-state
  hash**; historical `content_hash`/`state_hash` are not redefined;
- move, swap, density exchange, paint, erase, reaction product and phase
  conversion each define the family-state result. A product cell always starts
  with **its** family's default state (velocity 0, no overfill), and no state is
  silently copied across materials;
- conversions between families never truncate quantity without a declared,
  versioned rule (see the Water normalization in the
  [comparison contract](../operations/lcb-water-comparison-and-fixtures.md#water-quantity-normalization));
- saves reject unknown or incompatible family state before replacing the World.
  CYSD1 levels load with every liquid on its default family.

## Mixed-family boundary contract (Proposed)

When two liquids on different families meet, the **existing material-level
rules remain authoritative**: density exchange order, `accepts_density_exchange`,
pair reactions and kernel contact tests. Neither neighbour is treated as Empty
or Solid by default. Family-specific rules:

- **Density exchange or swap across families.** Each cell moves with its own
  material and family state. Inertial velocity travels with the moving inertial
  cell. A pressure cell swapped out of a pressure-connected run invalidates
  pressure summaries before reuse (#201).
- **Pressure boundary.** A `pressure_flow_v1` run treats a non-pressure liquid
  neighbour as a boundary of *known density*, not as open sky or wall. Head does
  not propagate through the foreign liquid. The exact rule and its regression
  are #200's.
- **Inertial into a foreign liquid.** Momentum transfer into a non-inertial
  liquid is bounded to the existing swap/displacement path. No velocity is
  written into the foreign family's state. Lost momentum is accounted, not
  created (#212).
- **Reactions.** Each product takes its own descriptor's default family and
  state. For example, under `inertial` Brine, Water+Salt→Brine+Brine creates
  inertial cells at zero velocity, and the Water mass of the consumed cell
  follows the declared #160 quantity rule.
- **Sleep and wake.** Pressure caching and dormancy never suppress
  non-pressure motion, chemistry or lifecycle work (#201). Cross-family contact
  wakes both sides.

## Capability matrix

The matrix is **source-derived**:
[`tools/lcb/derive_capability_matrix.py`](../../tools/lcb/derive_capability_matrix.py)
reads `material.hpp` and `interaction_rules.hpp` and writes
[liquid-solver-capability-matrix.json](../reference/liquid-solver-capability-matrix.json).
`--check` fails when the JSON is stale, and documentation CI runs it.

| Material (ID) | freemass_v1 | cellular_yield_v1 | pressure_flow_v1 | inertial_cellular_v1 |
|---|---|---|---|---|
| Water (3) | **current default** | proposed experimental (Gate D) | proposed experimental (#200) | proposed experimental (Gate D, #212) |
| Brine (24) | rejected | **current default** | rejected | **proposed experimental** (first non-Water candidate) |
| Toxic Sludge (32) | rejected | **current default** | rejected | proposed alternate |
| Oil (16) | rejected | **current default** (Oil kernel kept) | rejected | rejected (v1) |
| Lava 8, Acid 12, Paste 20, Slush 21, Cement 30, Mercury 33, Molten Glass 36 | rejected | **current default** | rejected | rejected (v1) |
| 120 non-liquid descriptors | rejected | rejected | rejected | rejected |

Why these choices:

- **FreeMass stays Water-only.** #15 selected no FreeMass conversion for other
  liquids.
- **Pressure v1 is Water-only.** The corrected `7ef2aac` candidate is a Water
  kernel.
- **Brine** is the first inertial candidate. It runs on the generic
  `YieldingLiquid` kernel (viscosity 32) with no kernel-only state. Its
  chemistry (`water-salt`, `brine-sodium`, `fire-brine`, `brine-bareiron`, the
  aqueous contact family) still needs #212 qualification.
- **Toxic Sludge** is the documented substitute. Its `water-toxic-sludge` rule
  turns it into Water on contact, which weakens a layering fixture.
- **Kernel-specialized liquids are rejected for inertial v1.** Admitting them
  would require #212 to re-qualify Oil burn, Lava/Acid chemistry, Cement and
  Molten Glass lifecycles, and the Mercury diagnostic override under a new
  motion law.

A rejected cell can be promoted only by changing the derivation tool's design
table **and** landing the owning implementation with evidence.

## Cross-issue acceptance mapping

| Owner | Takes from this spec | Must not claim |
|---|---|---|
| LCB-001 [#200](https://github.com/techrote/cybersand/issues/200) | `LiquidSolverPolicy` type, packing, validation/refusal codes, readback on every constructor, transaction, default-equals-Current proof, `pressure_flow_v1` state and boundary rule, versioned physical-state hash | inertial support; 72/80-bit carrier |
| LCB-002 [#201](https://github.com/techrote/cybersand/issues/201) | `cached`/`cached_dormant` variant equivalence; cross-family invalidation and wake | that variants are families |
| LCB-003 [#202](https://github.com/techrote/cybersand/issues/202) | per-material picker driven by the matrix, receipts in UI, reconstruct-to-apply ([UX flow](../operations/lcb-manual-comparison-ux.md)) | support the receipt does not report |
| LCB-005 [#212](https://github.com/techrote/cybersand/issues/212) | `inertial_cellular_v1` state, Brine (or Toxic Sludge) qualification, inertial boundary rules | Oil/kernel-specialized inertial support |
| LCB-004 [#203](https://github.com/techrote/cybersand/issues/203) | the matrix as coverage oracle; receipts in packaged builds | default changes |
| MAT-003PREPASS [#204](https://github.com/techrote/cybersand/issues/204) (Gate B) | the per-family field list above | n/a — owns width/sidecar/save |
