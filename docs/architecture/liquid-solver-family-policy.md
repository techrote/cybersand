---
title: Liquid solver family policy and API specification
status: Approved design
document-kind: design
scope: LCB-000 Gate C accepted design, Current main LCB-001 native contract and combined branch-Current LCB-002 pressure variants plus LCB-005 Brine IN — four-family identities, immutable per-World per-material policy, admission/readback, W-CY material block v2 and IN family block v2; subsystem mechanics and source/platform qualification remain separately owned
canonical-for: [liquid-solver-family-policy]
last-reviewed: 2026-10-25
related-documents: [pressure-flow-v1.md, liquid-prepared-setup-and-receipts.md, ../systems/water-design.md, ../systems/materials-and-rule-kernels.md, ../systems/flow-transport-and-profiles.md, ../decisions/ADR-005-water-model.md, ../operations/lcb-water-comparison-and-fixtures.md, ../operations/lcb-manual-comparison-ux.md, ../audits/2026-10-23-lcb000-gates-cde-design-evidence.md, pressure-optimization.md]
---

# Liquid solver family policy and API specification

## Status

**Approved design — Gate C PASS.** **LCB-000 Gates A–E PASS; #213 closed completed (2026-10-24).** See the [final admission checkpoint](../reference/status-and-roadmap.md#liquid-comparison-build-design-checkpoint--2026-10-23). The initial opt-in #200 start was separately scoped. On 2026-10-24 the owner lifted the hold for the bounded [#200 policy foundation](../reference/status-and-roadmap.md#lcb-001-policy-foundation--2026-10-24) and then authorized the bounded LCB implementation, including the previously held #200 pressure reference and #212 inertial work ([owner decision](../reference/status-and-roadmap.md#lcb-001-pressure-reference--2026-10-24)). The opt-in [`pressure_flow_v1/reference`](pressure-flow-v1.md) is Current on main since #245 merged at `03785c3`, with its recorded pressure evidence; Brine IN/reference is accepted on main through #250 (`dc915f2b`), and the isolated Water-IN successor has its separately qualified source/runtime checkpoint below. This does not admit production default changes, generic #12 Stage-4 cell↔Rapier ownership, a production Cell-carrier migration, full GEN-006 streaming, new pressure-to-Rapier forces or a global schema/ABI freeze.

The [native policy foundation](#native-policy-foundation-current-2026-10-24)
(object, wire decoding, validation, canonical identity, refusal, applied readback
and transactional construction) is **Current on main** for defaults and the
#245 pressure reference. Accepted [PR #246](../audits/2026-10-25-lcb001-shared-contract-acceptance.md)
at `ec58d919` also admits Water ×
`cellular_yield_v1/reference` (W-CY), alongside Water ×
[`pressure_flow_v1/reference`](pressure-flow-v1.md). It adds native setup
normalization, native-issued outcomes, typed native receipts and exact shared
quantity accounting, with complete physical hash/CYPS version **2**. The #245
hash-v1/CYPS1 source/artifact record remains historical; main now refuses CYPS1.
The older experimental GDExtension dictionary run hash remains distinct from
typed native-v1 receipts. The source-derived matrix and contract-model checks
remain Current apparatus. Their detailed
canonical contract is [native prepared setup and receipts](liquid-prepared-setup-and-receipts.md).
The owner requested a narrow freeze of those native versioned codecs; this
does not freeze the production Cell carrier, global ABI, physics calibration
or full host replay. The C64-E8 layout, defaults and historical content/state
hashes retain their separately recorded source identities. All three Water PF
variants are Current on main through #253 (`66051129`); Brine IN/reference is
accepted through #250 (`dc915f2b`) after corrected publication and its full
exact-head gates. Earlier union proofs keep their dated source scope. The
isolated [Water IN successor](inertial-cellular-v1.md#water-in-native-successor--2026-10-25)
adds Water admission and actual Windows/Linux sourceaa8af247 publication, bot
03cccd8f, with independent review and15 processes/642 policy assertions perOS.
Its final ready-PR gates, common-Water scientific and full-host/Web qualification
remain pending. Remaining #202 constructors and comparison UI keep their
separately qualified integration scope.

- Without an explicit request every material executes its **current default**
  in the [capability matrix](../reference/liquid-solver-capability-matrix.json).
  Main also executes opt-in Water × `pressure_flow_v1/reference` and Water ×
  `cellular_yield_v1/reference` under the accepted #246 contract.
- Implementation belongs to LCB-001
  [#200](https://github.com/techrote/cybersand/issues/200) (policy, state and
  pressure) and LCB-005 [#212](https://github.com/techrote/cybersand/issues/212)
  (inertial).
- State storage follows the **accepted bounded Gate B handoff**
  ([state handoff](../audits/2026-10-23-lcb000-gate-b-state-handoff.md),
  [refresh](../audits/2026-10-23-lcb000-admission-gatea-gateb-refresh.md)):
  - the C64-E8 Cell is unchanged;
  - family state goes in optional versioned solver-owned storage, plus a
    World-owned gas-compartment table;
  - numeric widths are frozen by #200/#212 before code.

  MAT-003PREPASS [#204](https://github.com/techrote/cybersand/issues/204)
  continues to own representation research. This page freezes no layout.

Claim labels used below:

| Label | Meaning |
|---|---|
| **Current** | Source fact, with a locator |
| **Owner-approved** | Recorded owner decision in #200/#213 |
| **Proposed** | This Gate C design; awaiting review |
| **Deferred to B** | Depends on the #204 storage handoff |

## LCB-005 branch admission and standalone adapter

The combined #212 source additionally admits Brine24 /
`inertial_cellular_v1/reference`, including its optional actual family block2
with damping numerator0..16 over16. The isolated Water successor additionally
admits Water3/reference with its own whole-cell/material/carrier proof; old
parent runtimes do not qualify it. Unsupported IN variants and materials retain typed refusal. Policy validation does not choose
execution geometry: the standalone Godot factory defaults to radius2 and IN
requires explicit3. Applied instance readback, physical hash3/CYPS3, the
non-IN2 control and local Windows evidence are owned by the
[Brine IN reference](inertial-cellular-v1.md#standalone-godot-readback-and-explicit-geometry).
This is branch source/adapter qualification, not accepted main or full #202.

## Current pressure-variant branch qualification

**Current on `codex/lcb002-pressure-variants` and integrated into the #212
branch, pending final acceptance:**
Water × `pressure_flow_v1/reference`, `cached` and `cached_dormant` are admitted
distinctly by `LiquidPolicyBuild::running()`. The [optimization contract](pressure-optimization.md)
owns the derived mechanisms and execution3 identity. No physical parameter,
default family or unsupported material mapping changes. Accepted #246 main
still describes its reference-only pressure checkpoint; source admission on
this branch does not reattest its retained runtimes as #201 execution.
Full host constructor, actual Rapier and Web qualification remain separate.

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
- **Effective readback exists for Water and, since the 2026-10-24 foundation,
  for the liquid policy.** `CyberNativeCellWorld::get_water_experiment_policy`
  returns the applied Water policy; `get_liquid_solver_policy` returns the applied
  per-material family receipt described below. Under the default policy every
  liquid executes its current default kernel; a World whose policy assigns Water
  to `pressure_flow_v1/reference` runs the [pressure reference](pressure-flow-v1.md)
  for Water instead (Current on main).
- **Liquids already meet in one World.** Density exchange (`DensityMotion`,
  `accepts_density_exchange`) and pair rules
  ([interaction_rules.hpp](../../native/include/cybersand/interaction_rules.hpp))
  act between liquids today. Examples: `int.pair.water-salt.dissolve.v1`, and
  Oil extinguished by Water inside the Oil kernel.

## Native policy foundation (Current, 2026-10-24)

LCB-001 [#200](https://github.com/techrote/cybersand/issues/200) foundation, under
the owner's bounded hold lift ([roadmap](../reference/status-and-roadmap.md#lcb-001-policy-foundation--2026-10-24),
[evidence](../audits/2026-10-24-issue-200-policy-foundation.md)). It reproduces
every registered [wire vector](../reference/liquid-policy-wire-vectors.json) bit for
bit: acceptance, refusal code, material and detail text, `policy_hash`, canonical
bytes and normalized envelope. Nothing here selects or runs another solver.

**Source.**

| Piece | Location |
|---|---|
| Policy object, decoder and precedence | [`liquid_solver_policy.hpp`](../../native/include/cybersand/liquid_solver_policy.hpp): `LiquidSolverPolicy`, `LiquidPolicyDecoder`, `LiquidPolicyBuild::running`, `LiquidPolicyRefused` |
| SHA-256 | [`sha256.hpp`](../../native/include/cybersand/sha256.hpp) |
| Embedded identity and matrix | generated [`liquid_policy_catalogue.hpp`](../../native/include/cybersand/liquid_policy_catalogue.hpp); `python tools/lcb/native_policy_artifacts.py --check` runs in Documentation CI |
| World admission | `WorldConfig::liquid_solver_policy`, `World::World` and `World::liquid_solver_policy()` in [`world.hpp`](../../native/include/cybersand/world.hpp)/[`world.cpp`](../../native/src/world.cpp) |
| Experimental C API | [`c_api.h`](../../native/include/cybersand/c_api.h): `cybersand_liquid_policy_default_v1`, `_validate_v1`, `cybersand_world_create_with_liquid_policy_v1`, `cybersand_world_liquid_policy_v1`, `_hash_v1` |
| GDExtension | `CyberNativeCellWorld.get_liquid_solver_policy()`/`get_liquid_policy_session_generation()`; `CyberDemoBridge.default_liquid_policy()`, `validate_liquid_policy()`, `build_liquid_policy_world()`, `get_last_liquid_policy_refusal()` |
| Hosts | `CyberMicroScenarioHost.install(..., liquid_policy)` and `liquid_solver_policy()`; desktop worker `scenario_reset.liquid_policy` and `lab_context.liquid_solver_policy` |

**Admission history and accepted main build.** At the foundation checkpoint (`1e032e4`) `freemass_v1` and
`cellular_yield_v1` are compiled (`available_families` 0x03), only each liquid's
**current-default cell** is qualified, and no parameter-block schema is
registered. With #245 on main,
`LiquidPolicyBuild::running()` also compiles `pressure_flow_v1`
(`available_families` 0x07) and qualifies exactly one more cell, Water ×
`pressure_flow_v1`, limited by `qualified_variants` to variant `reference`. It
registers one optional family block, `pressure_flow_v1` v1
`{gas_enabled 0..1, atmospheric_head_rows 16..4096}`; omitted, the defaults are 1
and 32 ([declared parameters](pressure-flow-v1.md#declared-parameters-v1)). The
two illustrative contract schemas remain historical contract-test schemas.
The accepted #246 main build additionally qualifies Water ×
`cellular_yield_v1/reference` and appends its actual optional Water material
block **v2**, `{viscosity_index 0..255}`, default 0. It does not reinterpret
the illustrative v1 `flow_rate_permille` block.

The original Brine-only #212 native checkpoint additionally compiles family4
(`available_families` 0x0F) and admits Brine/reference; the isolated Water
successor also admits Water/reference as qualified above. It binds fixed
parameters through native state-extension identity1, not the illustrative caller
damping schema. This admission updates the capability digest and policy/receipt
identities; it does not imply changed Current physics. The following table distinguishes accepted #246 main from the combined #201/#212 branch source:

| Request | Outcome |
|---|---|
| Water × `pressure_flow_v1/reference`, with or without its family block | **Accepted** on main; Water runs the [pressure reference](pressure-flow-v1.md) |
| Water × `pressure_flow_v1/cached` or `cached_dormant` (#201) | Accepted on main through #253 with distinct applied variant and [source-qualified optimization evidence](pressure-optimization.md); the earlier reference-only #246 record stays historical |
| Matrix `rejected` cell (e.g. Oil × `inertial_cellular_v1`, NC-1; any non-Water liquid × `pressure_flow_v1`) | `combination_rejected` |
| `proposed_alternate` cell (Toxic Sludge × inertial) | `not_selectable` |
| A variant the cell does not offer (e.g. Water FreeMass `cached`) | `variant_unsupported` |
| Water / `inertial_cellular_v1/reference` | Admitted only in the isolated native Water successor; [adapter and complete footprint](inertial-cellular-v1.md#water-in-native-successor--2026-10-25), actual sourceaa8af247 Windows/Linux publication passes; final ready-PR/scientific/full-host qualification pending |
| Water / `inertial_cellular_v1/cached` (successor NC-2) | `variant_unsupported`; admission never substitutes another law |
| Brine / `inertial_cellular_v1/reference` | **Accepted on main through #250**, with explicit execution radius3; [law, storage and evidence](inertial-cellular-v1.md) |
| Water × `cellular_yield_v1/reference`, with no Water block or its v2 viscosity block | **Accepted** on main through #246; whole-cell Water law below |
| Stale digests, malformed envelopes, any other parameter block, an out-of-range pressure block | as the precedence above |

On main, before the pressure reference, every `pressure_flow_v1` request was
refused `family_unavailable` (not compiled). At the #245 checkpoint, the 47 registered wire-vector cases
kept their acceptance, refusal code and detail; only identity words and hashes
were regenerated for the changed capability matrix.

`normalization_required` and `capacity_refused` are now exercised by native
prepared construction. Whole-cell fractional ingress without explicit
normalization refuses before installation; setup/allocation capacity has a
native-issued outcome. Godot has no typed normalization opt-in route yet, so
these native proofs do not close the #202 application acceptance campaign.

**Historical foundation reconciliation (2026-10-24).** The oracle's `today` build treated
availability per family, so it would have accepted Water × `cellular_yield_v1`
although no Water route through that family exists. The oracle now also
qualifies per material × family cell (`make_build(..., qualified=...)`), and an
appended vector `water_cellular_yield_today` registers the refusal. All earlier
vector cases, the transcript and the build identity are unchanged.

**Dispatch.** Kernels remain keyed by `RuleKernel`. `RuleKernel::Water` selects
`update_water_pressure`, `update_water_cellular_yield` or default `update_water`
from the admitted policy; it preserves generic chemistry before motion.
Other specialized kernels retain their defaults ([pressure kernel](pressure-flow-v1.md#kernel-update_water_pressure)). `World::World`
re-validates the policy's normalized envelope against the running build before
any World-owned storage (chunks, scratch, worker pool) is allocated, and throws
`LiquidPolicyRefused` otherwise. The validation itself allocates temporary policy
data, and a refused constructor releases it; no partially built World escapes. A policy accepted by a
hypothetical contract build can therefore never reach a kernel, and no fallback
path exists to be taken silently.

**Readback receipt (GDExtension).** Implemented fields: `version`,
`wire_version`, `envelope`, `session_generation`, `policy_hash`,
`catalogue_digest`, `capability_matrix_digest`, `platform`, `admission`
(`current_defaults_only` when the applied policy equals the default; on the
pressure reference `qualified_candidate` otherwise), `assignments` (`material`, `name`,
`requested_family`, `applied_family`, `applied_variant`), `family_blocks`,
`material_blocks`, `normalization` (null) and `refusal` (null; refusals are
returned by the constructing call). The #245 pressure adapter adds
`family_parameters` (empty, or `pressure_flow_v1`: `family_version`,
`gas_enabled`, `atmospheric_head_rows`, `flow_scale`, compartment limits,
acceleration, retain, friction, dead bands, `overfill_limit`, `adhesion_film`)
and `physical_state_hash_version` (2 on accepted main; 1 in the historical #245 record). `source_revision` and `native_binary_sha256`
are **not** in the native receipt; the host's runtime identity supplies them.

**Run receipt hash (experimental GDExtension dictionary, Current on main).**
`CyberNativeCellWorld.get_liquid_run_receipt(setup)` returns `receipt_hash`
(SHA-256 over the length-prefixed tag `lcb-run-receipt-v1` and key/value pairs),
`components` and `tick`. It binds the policy hash, Water policy, transport
profile, interaction policy, workers, backend, scheduler geometry, execution
settings (window, LOD, adhesion and actual simulation-region rectangle),
physics-changing diagnostic overrides and the physical-state hash version, plus the
caller-supplied `setup_hash`, `seed`, `normalization_receipt`, `source_revision`,
`native_binary_sha256` and `catalogue_digest` (`none` when absent). Its fields are
not the typed native-v1 receipt schema. That distinct native encoding binds
actual captured facts, prepared/normalization identities and shared accounting;
source/runtime claims remain unverified and full matched eligibility stays false
([contract](liquid-prepared-setup-and-receipts.md#native-issued-outcomes-and-typed-receipts)).
`session_generation` counts the World replacements committed by that adapter
(the constructor's demo, `reset_demo_world`, `diagnostic_reset` and every bridge
install). A refusal never advances it.

**Constructors.** Every World constructor takes the policy from its
`WorldConfig`. Only two paths accept a request: `build_liquid_policy_world` and
the C API's `create_with_liquid_policy_v1`. The #245 pressure adapter also
restores one: `CyberDemoBridge.import_physical_state` (CYPS2 on accepted main; CYPS1 is historical and refused) decodes the
saved policy envelope with the running build, so a refused or stale policy keeps
the running World ([persistence](pressure-flow-v1.md#persistence-cyps-v2)). The
native-only `PreparedWorldBuilder` additionally constructs and validates an
unexposed candidate; it is not a new Godot opt-in constructor. All
other paths reach a World as follows:

| Path | Policy |
|---|---|
| `reset_demo_world`, `build_world`, `build_tuned_world`, `build_water_feel_world` and CYSD1 `import_level` (NC-10) | Explicitly set to the default before construction |
| `diagnostic_reset`, the adapter constructor, and the C API's `cybersand_world_create`/`_create_v2` | A fresh `WorldConfig`, therefore the default |
| [`demo::construct`, `demo::reconstruct` and `demo::empty_level`](../../native/include/cybersand/demo_snapshot.hpp) | Build from the `WorldConfig` they are given; every current caller passes one of the configurations above |
| The other #202 constructors (generation previews, depth and exhibition planes, physical arenas, player material modes, the Web controller and Water reset) | No request; they run defaults. Wiring them is Planned |

A copied `WorldConfig` can carry only an admitted policy, and `World::World`
re-validates it in every case.

**Freeze boundary.** The C API and older GDExtension dictionary remain
experimental; CYSD1 still does not persist solver policy. The owner-requested
narrow native setup/normalization/run/attempt/accounting codec freeze and CYPS2
continuation are documented in the [shared contract](liquid-prepared-setup-and-receipts.md).
The accepted main build explicitly refuses historical CYPS1. This does not freeze production Cell
layout, a global ABI, source/runtime verification or complete application replay.

**Fallback hosts (deliberate host/oracle difference).** The oracle's
`gdscript_fallback` build models a host that can *decode* a request. It accepts a
default policy and refuses only non-default assignments as `platform_unsupported`.
No such GDScript decoder exists. `CyberMicroScenarioHost.install` therefore
refuses **every** explicit request, including the explicit default, as
`platform_unsupported` when the native handshake (`build_liquid_policy_world`,
`get_liquid_solver_policy`) is missing. Without the handshake it could neither
validate nor read back what it applied. Callers that want defaults on such a
host pass no request (`null`). The oracle vectors remain the contract for a
decoding host; adding a fallback decoder would have to reproduce them first.

### Regenerating identity after a material or rule edit

`catalogue_digest` hashes `material.hpp` and `interaction_rules.hpp`, and the
capability matrix embeds their digests. **Any edit to either file** must
therefore regenerate, in this order:

```sh
python tools/lcb/derive_capability_matrix.py   # matrix: source digests, liquid rows
python tools/lcb/policy_contract.py            # wire vectors: capability digest, hashes, current identity
python tools/lcb/native_policy_artifacts.py    # liquid_policy_catalogue.hpp and liquid_policy_vectors.inc
```

Then validate:

```sh
python tools/lcb/derive_capability_matrix.py --check
python tools/lcb/policy_contract.py --check
python -m unittest discover -s tools/lcb -p test_policy_contract.py
python tools/lcb/native_policy_artifacts.py --check
make build/tests && ./build/tests "LCB-001"   # or build_windows_msvc.bat
```

Review the vector diff before committing. A pure source edit should change only
digest words, `policy_hash`, canonical bytes and the identity block. If any
case's acceptance or refusal code changes, the edit has changed the policy
contract (for example a new liquid, or a `LateralFlowMode` change). That needs
review under this page, not silent regeneration. The generated header is a
native runtime input, so the published GDExtension runtimes need a
source-matched rebuild as for any native edit.

## Identities (owner-approved catalogue; Proposed encoding)

| Family ID | Physics | Owner | Executes today |
|---|---|---|---|
| `freemass_v1` | Current fractional conserved pairwise Water | existing source | Yes, Water only (default) |
| `cellular_yield_v1` | Whole-cell yielding motion plus material hooks | existing source; #200 W-CY | Ten liquids by default; Water opt-in on main through #246 with its own v2 viscosity block |
| `pressure_flow_v1` | Corrected pressure/overfill/flow/gas | #200 | Water opt-in; reference since #245 and all three variants accepted on main through #253, with source-matched publication and full exact-head gates ([optimization contract](pressure-optimization.md)) |
| `inertial_cellular_v1` | Non-pressure motion with retained velocity/accumulator | #212 | Brine/reference accepted on main through #250; isolated Water/reference sourceaa8af247 and Windows/Linux publication separately qualified; explicit radius3 and [actual readback/publication](inertial-cellular-v1.md); Water final ready-PR/scientific/full-application acceptance pending |

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
  catalogue_digest             : 32 bytes; see "Request envelope and canonical hash"
  capability_matrix_digest     : 32 bytes; binds source facts AND reviewed classifications
  assignments[material_id]     : { family_code, variant_code }   // only for liquid descriptors; others must be default
  family_parameters[family]    : versioned typed parameter block owned by that family (e.g. inertial damping)
  material_parameters[material]: versioned typed per-material block (Current W-CY Water v2 viscosity_index), or absent
  policy_hash                  : see canonical hashing below
```

**Canonical hashing.** `policy_hash` is SHA-256 over the canonical byte form
defined, with its wire envelope, in
[request envelope and canonical hash](#request-envelope-and-canonical-hash-gate-c-correction-2-2026-10-23).
That section supersedes the first-correction byte form and three-array
transport, which left both digests off the wire (re-review finding 1).

A separate **run receipt hash** binds everything that affects execution:
`policy_hash`, the `WaterExperimentPolicy` tuple, the transport profile hash,
the interaction policy hash, the canonical setup hash and seed, the normalization
receipt hash (or none), workers/scheduler, interest/execution settings and
source/binary/catalogue identity. A comparison is matched only when every
comparison component except the declared compared family/variant is equal and
the required provenance/execution proof is present. Native-v1 receipts preserve
qualifications and currently report full matched eligibility false; raw receipt
hash equality alone is not that proof ([canonical contract](liquid-prepared-setup-and-receipts.md)).

- **Default.** A default-constructed policy assigns every liquid its current
  default (`freemass_v1/reference` for Water, `cellular_yield_v1/reference`
  for the other ten). It **must be bit-identical in behaviour to today**:
  golden hashes, the #49 v2 control and the LCB Dam Break reference stay
  unchanged.
- **Packed transport.** One flat versioned `int32` envelope carries every
  hashed component, including both digests and the policy version, across the
  C API, GDExtension and Web. See
  [request envelope and canonical hash](#request-envelope-and-canonical-hash-gate-c-correction-2-2026-10-23).
- **Kernel dispatch.** The family owns **only motion and quantity transport**.
  Material identity, chemistry, lifecycle, temperature, density and coupling
  stay with the material. That split is defined against the real dispatch
  points in
  [material hooks versus motion](#material-hooks-versus-motion-gate-c-correction-2026-10-23).
  It is **not** a redirect of `RuleKernel::Water` into `RuleKernel::YieldingLiquid`.

## Material hooks versus motion (Gate C correction, 2026-10-23)

Correction requested by the [independent review](../audits/2026-10-23-lcb000-independent-admission-review.md).
Historical prepass anchors are `world.cpp` at `9012425`/`4caa2c3`; those line
numbers identify the baseline, not the merged pressure or residual-native files.

**Current dispatch, per cell.** The sequence is:

- `World::update_cell` (L3500) skips any position under a transient body mask;
- it calls `update_rule_kernel` (L2725 onward);
- that computes the temporal lanes (`contact_chemistry_due`,
  `lifecycle_due` and so on, L2753);
- then runs **generic pair chemistry before any kernel**
  (`has_pair_reactions` block, L2797–L2826);
- then the `RuleKernel` switch (L2829).

The Water kernel is `update_water` (L2650–L2723), which mixes material
behaviour with FreeMass motion. A family-aware implementation splits each cell
step into five stages:

| Stage | Owner | Water content today | Under W-CY / W-PF / W-IN |
|---|---|---|---|
| 1. Contact chemistry | material (generic, pre-switch) | Pair rules with Water as a participant: Lava quench, Fire extinguish, Salt dissolve, Sodium react, Toxic Sludge, Molten Glass, BareIron, building materials | **Preserved unchanged.** Products take their own descriptor default state and family default state. Quantity follows the [state-transition matrix](#state-and-quantity-boundaries-gate-c-correction-2026-10-23). |
| 2. Material pre-motion | material | Coherence countdown: `state_b` decremented each tick it is visited (L2654–L2658) | **Preserved.** The family must decrement it, and must suppress *lateral* motion while it is above zero (L2687). Gravity still runs. |
| 3. Motion and quantity | **family** | Gravity: merge into Water, relocate or swap (L2663–L2682). Then the adhesion film stop (≤`film()` on a non-Water/non-Empty support, L2691–L2695), `lateral_due` cadence, and the ¾-difference same-row relaxation with `tolerance()` (L2698–L2720). | **Replaced** by the family law. Adhesion is defined on fractional mass, so it is **not applicable** to whole-cell W-CY or whole-cell W-IN v1, which always hold `maximum()`. That is declared, not hidden. W-PF must state whether it keeps the film rule. |
| 4. Post-motion coupling | material + World | `mix_after_motion` with the *actually moved* quantity (transport carrying/erosion, L2564 / L2568); body-mask contact via `transient_obstacle_at` (`record_transient_contact` in `transfer_water`/`try_move`); density exchange through `try_move` → `can_density_exchange` | **Preserved.** Moved quantity is `maximum()` for a whole-cell move. A family must call the same hooks with its real moved quantity. |
| 5. Neighbour-observed identity | other kernels | Other kernels test for `Water` neighbours: Steam→Water product (L2849), Coal/Combustible extinguish (L2984), Cement cure (L3048), Ice/melt (L3026/L3142), Oil extinguish (L3205), Cloner (L3264), player payload (L3405) | **Preserved.** Identity stays `Material::Water` under every family. A product Water cell starts at `maximum()` and at that family's default state. |

**Deliberately different under the experimental Water families.** These are
declared in the run receipt:

- partial fills and fractional transfer (W-CY and whole-cell W-IN v1 hold
  exactly `maximum()` per cell);
- the ¾ relaxation and `tolerance()`;
- the adhesion film threshold (not applicable to whole cells);
- FreeMass merge-on-fall.

**Never different:**
- Water's material ID, density 1000, `DensityMotion::Down`,
  `accepts_density_exchange`, and the pair rules and their products;
- temperature, which moves with whole-cell moves;
- body-mask ownership, transport hooks, and render coverage derived from
  `state_a` (full for whole cells);
- the other kernels' Water tests.

**Specialized liquids.** Oil, Lava, Acid, Cement and Molten Glass keep their
source-matched kernels (stages 1–5 unchanged) under their default
`cellular_yield_v1`. The matrix rejects every other family for them in v1.

**Required tests** (owned by #200 for W-CY/W-PF, #212 for W-IN): a
material×family hook matrix. Each case runs the same fixture under the
default and the experimental family and asserts the stage 1/2/4/5 outcomes
are identical, apart from the declared stage-3 differences. Cases:

- Water+Salt products;
- Lava quench;
- Fire extinguish;
- Oil extinguish;
- Cement cure;
- Steam condensation product family;
- coherence lateral suppression;
- body-mask contact with no motion under the mask;
- transport carrying with whole-cell moved mass.

Each case also needs a negative control showing that a Water cell under W-CY
never runs `flow_as_yielding_liquid` with Paste/Slush descriptor parameters.

<a id="whole-cell-water-law-current-residual-native-source"></a>

### Whole-cell Water law (Current main)

`World::update_water_cellular_yield` keeps material identity, generic pair
chemistry, coherence countdown, density exchange, temperature, body contact and
actual-moved-mass coupling. Its stage 3 moves whole tuples only: gravity then
diagonals, followed by cadence-gated lateral yield into Empty. There is no
same-Water merge, FreeMass relaxation, fractional adhesion film or
Paste/Slush-descriptor fallback. Every Water cell contains `maximum()`.

[`WaterCellularYieldParameters`](../../native/include/cybersand/water_cellular_yield.hpp)
declares law version 1 and optional Water material block **version 2**:
`viscosity_index` 0..255, default 0. The deterministic lateral roll succeeds with
probability `(256 - viscosity_index) / 256`. Coherence suppresses lateral motion
for its full delay while gravity remains responsive. Configured Water cadence
and one-/two-side transport settings retain their own meanings.

A legal future side keeps an interaction deadline when cadence defers work, a
viscosity roll misses, or one-side sampling chooses the blocked side. Thus a
slow/stochastic lane cannot sleep permanently before its next opportunity;
permanently blocked pools can still reach ordinary block sleep. Regressions are
[`test_water_cellular_yield.cpp`](../../native/tests/test_water_cellular_yield.cpp),
including liveness, material hooks and 1/4-worker continuation. Fractional ingress,
explicit normalization and exact source/sink accounting are owned by
[native prepared setup](liquid-prepared-setup-and-receipts.md).

### Request envelope and canonical hash (Gate C correction 2, 2026-10-23)

Correction for [re-review finding 1](https://github.com/techrote/cybersand/pull/226#issuecomment-6362824493).
The executable specification is the standalone oracle
[`tools/lcb/policy_contract.py`](../../tools/lcb/policy_contract.py), its
generated vectors
[`liquid-policy-wire-vectors.json`](../reference/liquid-policy-wire-vectors.json)
and the regressions in
[`test_policy_contract.py`](../../tools/lcb/test_policy_contract.py), run in the
Documentation workflow. **The oracle is a contract model only.** It implements
no native policy, World or solver. #200/#212 must reproduce the vectors bit for
bit; disagreement is a contract defect to reconcile here, not a reason to
regenerate the vectors.

**Identity digests (Proposed).**

| Digest | Definition |
|---|---|
| `catalogue_digest` | SHA-256 of `"lcb-material-catalogue-v1\0"`, then for `material.hpp` and `interaction_rules.hpp` in that order: u32 LE path length, UTF-8 repository path, u32 LE byte length, LF-normalized bytes |
| `capability_matrix_digest` | SHA-256 of `"lcb-capability-matrix-v1\0"` followed by the LF-normalized bytes of the generated [capability matrix](../reference/liquid-solver-capability-matrix.json) |

The matrix file embeds the source-fact digests **and** every reviewed design
classification: status, variants, notes and specialization text. A
reclassification therefore changes `capability_matrix_digest` even when no
source file changes. A regression mutates one status, one specialization text
and one source digest, and requires a new digest each time. A native build
would embed both values as generated constants; the current values are recorded
in the vector file's `current_build_identity`.

**Wire envelope v1.** One flat sequence of signed 32-bit words. It is a
`PackedInt32Array` in GDExtension, `const int32_t* words, size_t word_count` in
the C API, and an `Int32Array` on Web; the desktop worker and Web bridge
forward it unchanged. JSON and strings are never the wire. In order:

| Words | Field | Valid range |
|---|---|---|
| 1 | magic `0x4C435057` ("LCPW") | exact |
| 1 | `envelope_version` | 1 |
| 1 | `policy_version` | 1 |
| 8 | `catalogue_digest` | any int32: word *i* = digest bytes 4*i*..4*i*+3, big-endian, two's complement |
| 8 | `capability_matrix_digest` | as above |
| 1 | assignment count *N* | 0..liquid count (11) |
| 3*N* | `(material_id, family_code, variant_code)` | `0..0xFFFF`, `0..0xFF`, `0..0xFF` |
| 1 | family block count *F* | 0..4 |
| per block | `(family_code, block_version, word_length L, L values)` | `0..0xFF`, `0..0xFFFF`, `0..64`, any int32 |
| 1 | material block count *M* | 0..liquid count |
| per block | `(material_id, block_version, word_length L, L values)` | `0..0xFFFF`, `0..0xFFFF`, `0..64`, any int32 |

The envelope must be consumed exactly: a short read or trailing words are
`malformed_policy`. `envelope_version` selects only the decoder and is not
hashed. `policy_version` is hashed.

**Request normalization.** In a *request*, family code 0 means "this
material's default family" and requires variant `reference`. Normalization
replaces it before the matrix cell is validated. Code 0 is never applied,
hashed or read back. A request with every code 0, one with only Water at 0, and
the explicit default therefore hash to the same `policy_hash`; these are
registered vectors.

**Canonical bytes.** These are hashed with SHA-256 to `policy_hash`. Integers
are little-endian:

```text
"lcb-liquid-policy\0"                        18 bytes
policy_version                               u16
catalogue_digest | capability_matrix_digest  32 + 32 raw bytes
N                                            u16
(material_id u16, family_code u8, variant_code u8) × N     normalized, ascending
F                                            u8
(family_code u8, block_version u16, byte_length u32 = 4·L, L × i32) × F
M                                            u16
(material_id u16, block_version u16, byte_length u32 = 4·L, L × i32) × M
```

- Wire lengths count words; canonical lengths count bytes (4·*L*).
- A wire word is narrowed to u8/u16 only after its range check above.
- Two envelopes are the same policy if and only if their normalized canonical
  bytes are equal.
- The normalized envelope re-encodes the applied policy, and decoding it
  reproduces the same policy.

**Validation precedence.** The first failure wins, so a given malformed input
has exactly one refusal:

1. every element is an int32 (`malformed_policy`);
2. length ≥ header + 3, then magic, `envelope_version` and `policy_version`
   (`malformed_policy`);
3. `catalogue_digest`, then `capability_matrix_digest`, each compared with the
   running build. Either mismatch is `stale_capability_matrix`, and `detail`
   names the digest. This check runs before any catalogue-dependent
   interpretation;
4. section structure: counts and block lengths in range, exact consumption
   (`malformed_policy`);
5. per assignment: `unknown_material` (outside the catalogue or reserved 10),
   `not_a_liquid`, `unknown_family`, `unknown_variant`; then strictly ascending
   IDs and completeness over all liquid descriptors (`malformed_policy`);
6. normalization of code 0 (a non-reference variant with code 0 is
   `malformed_policy`);
7. per assignment: `combination_rejected`, `not_selectable`,
   `variant_unsupported`, `platform_unsupported` (no native handshake, any
   non-default), `family_unavailable` (not compiled/qualified);
8. blocks, family then material:
   - strictly ascending owners (`malformed_policy`);
   - a known `(owner, block_version)` and a schema-matching length
     (`unknown_parameter`);
   - a family block only for an assigned family, and a material block only
     where the material's applied family declares it (`malformed_policy`);
   - every field in its schema range (`malformed_policy`);
   - then any missing mandatory block (`unknown_parameter`).

`water_semantics_incompatible`, `capacity_refused` and
`normalization_required` depend on the World setup. They remain native-only
checks after step 8. Each refusal returns `{code, material|null, detail}` and
leaves the live session, its readback and its `policy_hash` untouched.

**Historical oracle schemas are illustrative.** The original profiles register two
contract-test schemas only to exercise the rules:
- a mandatory `inertial_cellular_v1` v1 block (`damping_q16` 0..65536,
  `speed_cap_q8` 256..2048);
- an optional Water v1 block, valid only under `cellular_yield_v1`
  (`flow_rate_permille` 1..1000).

#200 appends the actual W-CY material block v2 described above; v1 is not
reinterpreted as viscosity. #212 appends optional native IN family owner4/blockv2,
with one `damping_numerator` field0..16 over fixed denominator16 and default1;
[the IN reference](inertial-cellular-v1.md) owns its actual execution/identity.
The inertial illustrative blockv1 remains only a contract-test schema and is
refused by the running build. The native successor vectors are separately
registered in [inertial-parameter-vectors.json](../reference/inertial-parameter-vectors.json);
existing illustrative profiles and outcomes are preserved. The owner-requested native shared-codec freeze does not
freeze an inertial law, pressure calibration or production ABI.

**Applied readback.** The readback is the normalized applied policy, never the
request:

- `CyberNativeCellWorld.get_liquid_solver_policy()` and the Web/worker forward
  return the dictionary under [effective readback](#effective-readback-proposed).
  It includes `envelope` (the normalized wire words) and `session_generation`.
- C API: `cybersand_world_liquid_policy_v1(world, out_words, capacity)` returns
  the required word count and writes the normalized envelope when it fits.
  `cybersand_world_liquid_policy_hash_v1(world, out_32_bytes)` writes the hash.

`policy_hash` is reported as 64 lowercase hex characters. After a refusal, the
readback, `policy_hash` and `session_generation` equal their prior values.

**Registered vectors.** All are in the vector file, and each is checked by
`--check` and by the unit tests:

| Group | Cases |
|---|---|
| Round trip | default; W-IN Water with a family block; W-CY Water with and without a material block; W-PF Water `cached_dormant`; W-IN Brine. Each decodes, re-encodes to its normalized envelope, and reads back the same hash |
| Equivalent normalized | all-code-0 and Water-code-0 requests equal the explicit default hash |
| Changed identity | changed `catalogue_digest` and changed `capability_matrix_digest`: a different hash, and refused `stale_capability_matrix` |
| Changed parameters | changed family (default vs W-IN vs W-CY vs W-PF), family-block value and material-block value: all hashes pairwise distinct |
| Malformed | empty, truncated header, bad magic, unknown envelope/policy version, trailing word, short/negative/oversize count, a word above int32, block past end, block over 64 words, schema length mismatch, unknown block version, missing mandatory block, extra family block, material block under the wrong family, field out of range, duplicate block, unsorted/duplicate/missing assignment, non-liquid, reserved, outside catalogue, unknown family/variant code, code 0 with a non-reference variant, unsupported variant, rejected and `proposed_alternate` combinations |
| Build profiles | the oracle's `today` build (the historical foundation build) refuses W-IN/W-PF as `family_unavailable`; the GDScript fallback refuses non-defaults as `platform_unsupported` and accepts defaults. The oracle has no profile for the pressure-reference running build; native tests check that build directly |
| Session | default → W-IN accepted (generation 1) → stale catalogue, stale capability and truncated envelope refused with the W-IN hash unchanged → W-CY accepted (generation 2) |

The "all families" build in the vectors is a **hypothetical contract build**, so
that non-default hashes can be computed. It is not evidence that W-PF or W-IN
exist; W-PF reference evidence is the native and Godot pressure regressions. Vector builds use a fixed synthetic catalogue digest so the vectors stay
stable when the headers change. The real matrix still supplies the statuses and
the capability digest.

### Validation and refusal (Proposed)

Validation runs **before** any World is built or replaced. Any failure returns
a typed refusal and leaves the live session untouched, as
`build_water_feel_world` does today.

| Code | Condition |
|---|---|
| `unknown_material` | ID outside the catalogue or reserved (10) |
| `not_a_liquid` | assignment to a non-liquid descriptor |
| `unknown_family` / `unknown_variant` | code not in this build's catalogue |
| `family_unavailable` | family, cell or variant not compiled/qualified; accepted #246 main refuses `inertial_cellular_v1` and pressure `cached`/`cached_dormant`; current #201 branch admits all three Water PF variants, while unsupported material/family combinations still refuse |
| `combination_rejected` | matrix status `rejected` for that material×family |
| `variant_unsupported` | variant not offered by that family |
| `water_semantics_incompatible` | family cannot honour the requested Water mass bits/coherence |
| `platform_unsupported` | family/variant not qualified on this platform (Web profile, GDScript fallback) |
| `capacity_refused` | family scratch/state budget cannot be prepared for this World size |
| `stale_capability_matrix` | the envelope's `catalogue_digest` or `capability_matrix_digest` differs from the running build; `detail` names which (checked at precedence step 3) |
| `malformed_policy` | duplicate, missing, unsorted or out-of-range material IDs; count above the catalogue; signed/overflowing integers; a non-liquid or reserved ID present |
| `unknown_parameter` | unknown block version, field or length; a missing mandatory parameter |
| `not_selectable` | the matrix lists the cell as `proposed_alternate` (e.g. Toxic Sludge inertial M1-alt), or the variant list is empty |
| `normalization_required` | the setup holds fractional Water and the selected Water family is whole-cell, with no explicit normalization opt-in |

Policy decoding/admission precedes World allocation. Setup/capacity checks can
discard an unexposed candidate; they never release or replace the previous
session. Native-issued policy/setup refusal and preparation-failure outcomes
remain distinct ([construction boundary](liquid-prepared-setup-and-receipts.md#native-issued-outcomes-and-typed-receipts)).

There is **no hidden fallback**. A refused or unavailable family is never
replaced by Current, another family or the GDScript fallback. The GDScript
fallback reports every non-default assignment as `platform_unsupported`.

### Effective readback (Proposed)

This is the **Planned #202 host requirement**, including constructor coverage
and dictionary projection below. Current adapter fields are listed in the native
foundation section; typed native-v1 receipts have their own
[canonical contract](liquid-prepared-setup-and-receipts.md). The existing Godot
dictionary does not obtain verified provenance or native normalization merely
by adopting this proposed shape.

`World::liquid_solver_policy()` returns the applied policy. It surfaces as:

- C API: `cybersand_world_liquid_policy_v1(world, out_words, capacity)` (normalized
  envelope) plus `cybersand_world_liquid_policy_hash_v1`;
- GDExtension: `CyberNativeCellWorld.get_liquid_solver_policy()` →
  `{version, wire_version, envelope, session_generation, policy_hash, catalogue_digest, capability_matrix_digest, source_revision, native_binary_sha256, platform, assignments:[{material, requested_family, applied_family, applied_variant}], family_blocks:[{family, block_version, values}], material_blocks:[{material, block_version, values}], normalization:{rule, receipt_hash, signed_delta}|null, refusal:null|{code, material, detail}}`;
- desktop worker and Web bridge, which forward the native dictionary
  unchanged.

The readback reports the **applied** family/variant and any setup
normalization, not merely the request. A host that cannot obtain this
handshake from native (for example the GDScript fallback) reports
`platform_unsupported` for every non-default assignment. It never silently
switches to GDScript.

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
refusal code.

**Reconstruction rules:**
- When the caller holds only a setup, reconstruction rebuilds a **tick-zero
  scenario** from that retained setup. It is not a resume of the live state.
- A CYSD1 level import is a finite-level reconstruction (all liquids on
  default families). It is never labelled exact continuation.
- A failed or unsupported import keeps the live session.

**No mid-flow hot switching:** converting live cells between families is not
supported. A later *qualified* converter would need its own
registration and lossless proof. #200 freezes the receipt fields: requested
policy, applied policy and hash, setup hash, refusal (if any) and tick 0.

## State ownership per family

Field-level needs, placed into optional storage by the accepted bounded Gate B
handoff. Widths, capacities and save fields are frozen by #200/#212 within that
handoff; no Cell layout change is implied.

| Family | Authoritative state beyond material/state_a/state_b | Current/Proposed |
|---|---|---|
| `freemass_v1` | none: `state_a` = Water mass (policy-scaled), `state_b` = coherence delay | Current |
| `cellular_yield_v1` | none beyond kernel use: Oil `state_b` burn, Cement/Molten Glass lifecycle, `initial_state_a` per descriptor | Current |
| `pressure_flow_v1` | overfill quantity, signed horizontal velocity, gas pocket identity/generation and amount, derived per-tick head (scratch, not state) | Current in source: a per-chunk solver-owned `PressureChunk` (`overfill u16`, `flow i16`, `gas u32`) plus the World gas table; no Cell bits ([storage](pressure-flow-v1.md#storage-gate-b-handoff-kept)). 7ef2aac's bits 40–55 are not used |
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
  wakes both sides. A rest certificate must also retain no-motion body-contact
  probes consumed by coupling, cadence/future-event obligations and exact
  analytical rest; it cannot freeze nonzero residual flow or reuse #12 discovery
  as Water skip authority.

## State and quantity boundaries (Gate C correction, 2026-10-23)

Normative summary. The operation-by-operation
[state-transition matrix](https://github.com/techrote/cybersand/pull/226) for
#200/#212 refines it in the LCB physics prepass and does not override it.

1. **Current transfer laws (source).**
   - FreeMass Water moves quantity only by `transfer_water` (L2481) into
     Empty/Water with capacity, or as a whole tuple by `try_move`/`move_cell`
     (L2446/L2323).
   - Every other liquid moves whole cells only.
   - Density exchange needs a nonzero vertical delta (`can_density_exchange`),
     so unlike liquids never swap sideways.
   - A swap carries material, `state_a`, `state_b` and temperature as one tuple.
2. **Experimental quantity laws.** Each family defines, before implementation,
   its transfer into Empty, its same-material merge, its displacement of a
   foreign liquid, and the quantity, velocity and remainder split.
   - Optional state (overfill, velocity, accumulators) moves with its owning
     cell and is retired, never left as a ghost, when the cell becomes Empty
     or another material.
   - Unit, range and rounding are frozen per Gate B before code.
3. **Foreign neighbours.** A different family's liquid is neither Empty nor
   Solid.
   - Current density exchange decides who moves.
   - Pressure treats it as a density-bearing boundary and does not propagate
     head through it.
   - Inertial momentum stops at it, and the lost impulse is booked as
     dissipation.
4. **Reactions and conversions carry signed ledgers.** The current
   Water+Salt→Brine+Brine rule consumes one Water cell **whatever its mass** and
   creates two whole Brine cells. Steam expiry writes Water at `maximum()`
   (L2849).
   - Both are explicit **source/sink** events, not conserved transfers. LCB
     accepted native accounting books actual consumed visible+overfill Water
     and initialized products separately per catalogue rule, including
     Water-to-Water products. Material populations are separate cell units
     ([shared ledger](liquid-prepared-setup-and-receipts.md#quantity-aggregates-producers-and-continuation)).
   - #160 owns the quantity rule change (PR #162 is unmerged and covers
     Steam/Ice/quench, not Salt).
   - No document may assert whole-cell mass conservation from a partial-Water
     source.
5. **Specialized liquids stay on their defaults.** Oil, Lava, Acid, Cement and
   Molten Glass keep their source-matched kernels under `cellular_yield_v1`.
6. **Not selectable.** `proposed_alternate` rows (Toxic Sludge inertial,
   M1-alt) have an empty variant list and are refused with `not_selectable`
   until #212 qualifies them and registers a new fixture version.
7. **Reset and wake.** A rebuilt World starts with all optional state at family
   defaults and all blocks active. Any cross-family write wakes both endpoint
   blocks, as `move_cell` does today.

## Capability matrix

**Provenance (corrected 2026-10-23).**
[`tools/lcb/derive_capability_matrix.py`](../../tools/lcb/derive_capability_matrix.py)
writes [liquid-solver-capability-matrix.json](../reference/liquid-solver-capability-matrix.json),
and `--check` (run in documentation CI) fails when that JSON is stale. The
JSON has two kinds of content:

- **Source facts:** parsed from `material.hpp` and `interaction_rules.hpp`.
  These are material IDs, densities, kernels, lateral-flow modes, flow-rate index,
  density motion and pair-rule participation.
- **Reviewed design classifications:** hand-authored in the tool (`PROPOSED`,
  `VARIANTS`, `KERNEL_SPECIALIZATION`). These are the proposed, alternate and
  rejected statuses and the variant lists.

Each row records which fields are which. **The matrix is not mechanically
derived executable solver coverage.** `current_default` cells execute. The
`EXECUTABLE_CANDIDATES` table also marks Water × `pressure_flow_v1/reference`
(Current on main) and Water × `cellular_yield_v1/reference` (Current on main through accepted #246) as `executable_today: true` with
`executable_variants: ["reference"]`. Other candidate mappings remain refused.
Unusual chemistry, temperature and flow-rate cases are validated by #200/#212
implementation tests, not by this table.

| Material (ID) | freemass_v1 | cellular_yield_v1 | pressure_flow_v1 | inertial_cellular_v1 |
|---|---|---|---|---|
| Water (3) | **current default** | proposed experimental (Gate D); `reference` executable on main through #246 | proposed experimental (#200); `reference` executable on main | proposed experimental (Gate D, #212) |
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
