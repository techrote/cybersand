---
title: Issue 29 INT-000 bounded preflight
status: Current
document-kind: audit
scope: Source-inspected inventory and implementation design for INT-000 before the Materials Laboratory readiness gate; no runtime/framework implementation or material retuning
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [../operations/microscenarios-programme.md, ../operations/microscenarios.md, ../systems/materials-and-rule-kernels.md, ../MATERIAL_LAB.md, ../reference/status-and-roadmap.md]
---

# Issue 29 INT-000 bounded preflight

This record is deliberately bounded to the work that issue #29 permits before
the #28 **Materials Laboratory readiness checkpoint**. It inventories current
source semantics, defines a candidate logical model and coverage/provenance
contract, maps fixture families and implementation touchpoints, and leaves an
explicit handoff for the post-gate implementation agent.

**It does not implement INT-000, alter production semantics, add an interaction
profile, generate executable interaction fixtures, retune any material, or claim
Materials Laboratory readiness.**

## Contents

1. [Gate and source scope](#1-gate-and-source-scope) — establishes the closed implementation gate and inspected baseline.
2. [Current interaction inventory](#2-current-interaction-inventory) — separates pair data, specialized kernels, lifecycle rules and kinetic exclusions.
3. [Candidate authoring, coverage and provenance model](#3-candidate-authoring-coverage-and-provenance-model) — defines the preflight design without freezing an implementation schema.
4. [Generated fixture-family plan](#4-generated-fixture-family-plan) — maps representative mechanisms to useful topologies and observations.
5. [Post-gate touchpoints and stop condition](#5-post-gate-touchpoints-and-stop-condition) — identifies likely implementation surfaces and the exact boundary this preflight must not cross.

## 1. Gate and source scope

### Source identity inspected

- repository: `techrote/cybersand`
- inspected `main`: `de332eaf8f4e70b25b097bed0c2e2a7b2aac0173`
- that revision contains the selected MS-000 merge from PR #40;
- no existing #29 implementation branch or PR was found before this preflight;
- issue #27's stable common fixture contract is therefore present in the inspected
  baseline.

The second implementation prerequisite is **not** present. Issue #28's active
execution comments on `codex/issue-28-ms001` repeatedly state that Materials
Laboratory readiness has not yet been established and that #29 remains gated.
Its implementation plan intends to publish readiness as a separate evidence
checkpoint after one generated definition has passed the required
interactive/headless, reset, identity, observation, A/B and ownership checks.

Therefore, at this checkpoint:

| Prerequisite | Status | Consequence |
|---|---|---|
| Stable #27 fixture contract | Satisfied on inspected `main` | Preflight may use the actual v1 contract as design evidence |
| #28 Materials Laboratory readiness | **Not satisfied** | **No #29 framework/runtime implementation is permitted** |
| #14/G-final | Not required for this preflight or later #29 implementation | Interaction evidence must instead pin rolling kinetic/contact baselines |

### Evidence type and limitations

This is source inspection and design work. No new runtime artifact was built and
no current-head execution is claimed by this audit. Existing tests are cited only
as inspected coverage, not rerun evidence.

The inspected authoritative surfaces were:

- `native/include/cybersand/material.hpp`
- `native/include/cybersand/material_rules.hpp`
- `native/src/material_rules.cpp`
- `native/src/world.cpp`
- `native/tests/test_world.cpp`
- `godot/scripts/microscenario_contract.gd`
- `godot/scripts/microscenario_host.gd`
- `godot/scripts/microscenario_catalogue.gd`
- `godot/scripts/microscenario_panel.gd`
- `godot/scripts/microscenario_identity.gd`
- `godot/tests/run_microscenario.gd`

## 2. Current interaction inventory

### Catalogue shape

The native catalogue has IDs 0..80 with ID 10 reserved/invalid and Smoke/Gas
sharing ID 4. Excluding Empty and invalid 10 leaves **79 paintable materials**.
IDs 38..80 are themed construction materials. Most are intentionally inert
`RuleKernel::None` hard surfaces; Oak Timber (46) and Thatch (47) deliberately
reuse the bounded `Combustible` kernel.

This already demonstrates why the authored INT-000 source of truth must be
sparse and family-aware. A Cartesian authored table would mostly encode absence
or inheritance rather than useful bespoke behavior.

### Four current semantic classes

The current non-kinetic interaction surface is not one pair matrix. It falls into
four materially different classes which a later resolver/provenance system must
distinguish.

1. **Compact pair-table reactions.** `material_rules.cpp` contains 14
   orientation-independent pair definitions with role-preserving products and a
   probability threshold.
2. **Source-driven neighbourhood kernels.** `world.cpp` contains contact,
   neighbourhood and context rules whose behavior cannot be reconstructed from
   the pair table alone: burning/extinguishing, broad Acid corrosion, Metal
   charge propagation, Cement cure, growth/germination, and agent-specific state
   interactions.
3. **Intrinsic/lifecycle state transitions.** Some conversions are primarily
   state/lifetime driven rather than pair driven, for example Steam condensing to
   Water, Foam disappearing, Fire becoming Smoke, Coal becoming Dust, and
   Molten Glass cooling to Glass.
4. **Kinetic/contact physics.** Density exchange, Water transport, yielding
   liquid motion, granular support/bridging/bracing, erosion/entrainment,
   collision/ballistics and Rapier coupling determine whether materials meet but
   are **not INT-000-owned interaction semantics**.

A post-gate implementation must preserve this separation. Migrating the 14-entry
pair table alone would not constitute INT-000, while absorbing kinetic behavior
into interaction rules would violate its scope.

### Current compact pair reactions

`kPairReactions` currently contains:

| Participants | Current products | Stored threshold | Preflight channel classification |
|---|---|---:|---|
| Lava + Water | Stone + Steam | 255 | thermal/phase + conversion |
| Fire + Water | Smoke + Steam | 255 | combustion/extinguishing + phase |
| Water + Salt | Brine + Brine | 255 | dissolution/conversion |
| Water + Sodium | Steam + Fire | 255 | reactive conversion |
| Brine + Sodium | Steam + Fire | 255 | reactive conversion |
| Water + Toxic Sludge | Water + Water | 255 | purification/conversion |
| Steam + Ice | Water + Ice | 32 | thermal/phase |
| Water + Molten Glass | Steam + Glass | 255 | thermal/phase |
| Lava + Glass | Lava + Molten Glass | 255 | thermal/phase |
| Acid + Metal | Smoke + Rust | 96 | corrosion/conversion |
| Fire + Gunpowder | Fire + Fire | 255 | combustion |
| Spark + Gunpowder | Empty + Fire | 255 | ignition/electrical trigger |
| Spark + Oil | Empty + Fire | 255 | ignition/electrical trigger |
| Fire + Brine | Steam + Salt | 64 | extinguishing/phase/conversion |

The pair table is sampled by the current deterministic four-tick contact-chemistry
lane. The table itself is symmetric in participant matching, while preserving
which product belongs to each participant role. A future authored model therefore
needs an explicit distinction between unordered matching and identical effects;
"symmetry" cannot mean "both sides receive the same product."

### Current specialized non-kinetic semantics

The following source-driven rules are relevant to INT-000 inventory even though
some kernels also contain motion that remains outside INT-000:

| Source/kernel | Current non-kinetic semantics to preserve/provenance-track | INT-000 treatment |
|---|---|---|
| Fire / Combustible | sampled ignition; Water extinguishes active burn; burn emits Fire and consumes material | combustion channel |
| Gunpowder / Coal | hot-neighbour ignition; Coal burn can be extinguished by Water/Brine; Coal ends as Dust with Fire/Smoke emissions | combustion + products |
| Lava / Ice | Lava samples Ice into Water or ignites neighbours; Ice melts near hot materials and can freeze neighbouring Water | thermal/phase; exclude their movement |
| Acid | sampled broad corrosion deletes most non-Wall/non-Acid neighbours and consumes Acid strength; Acid+Metal has a more specific pair reaction | corrosion family/default plus sparse exception candidate |
| Metal / Spark | Spark charges adjacent Metal; charge propagates through Metal and may convert adjacent Water to Steam | electrical + thermal consequence |
| Cement | cure depends on neighbouring air, Water/Brine or Concrete and ends as Concrete | curing/environment channel |
| Molten Glass | hot neighbours reset cooling; otherwise cooling eventually produces Glass | thermal/state channel |
| Plant / Fungus / Seed | substrate/context growth, germination, ignition and state changes | growth/biological/special-state channel |
| Cloner | captures a neighbour identity and emits initialized copies into Empty | special-state/capture; requires careful source/sink accounting |
| Mite | consumes selected biological/timber/Dust targets and dies under selected environmental contacts | special biological interaction; exclude locomotion |
| Rocket | captures payload and uses hot/temperature state to trigger; payload/emission semantics cross interaction and ballistic ownership | split state/contact semantics from ballistic motion |

The inspected native tests already contain focused examples for many of these
families: Water/Salt, Water/Sodium, Spark/Metal, Cement cure, combustion and
extinguishing, Lava/Water/Ice behavior, Acid corrosion, Cloner, growth/Seed,
Mite/Rocket, themed combustibles and one/four-worker parity. Those tests are
valuable migration oracles after the gate; they are not a complete interaction
coverage ledger.

### Explicit kinetic exclusions

The following existing behavior may appear in the same scenario but must remain
read-only provenance from INT-000's perspective:

- Water conserved mass transfer, leveling and supported-film policy;
- density exchange including Water/Oil and Mercury/material displacement;
- yielding-liquid viscosity/mobility and liquid transport;
- powder movement, granular support, bridging/bracing and permeability;
- transport-profile mixing/pickup/erosion;
- rigid-body/cellular collision, Rapier coupling, ballistic movement and torque;
- scheduler/activity behavior except where its identity is needed to explain
  contact opportunity or evidence validity.

An anomaly is not reclassified as an interaction rule merely because two
materials were present. Capture/reduce first, then triage ownership.

## 3. Candidate authoring, coverage and provenance model

Everything in this section is a **logical preflight design**, not a frozen file
format or runtime API.

### Authoring layers

Resolution should preserve the issue's intended order:

```text
intrinsic material/state semantics
        |
family/channel defaults
        |
material-specific adjustments
        |
sparse directed or unordered pair overrides
        |
context/state modifiers
        |
validated resolver/compiler
        |
compact effective runtime representation if measurement justifies it
```

A resolved dense lookup may later be a performance optimization. It must not
become the human-authored source of truth.

### Family-selector safety

A future `family/default` layer must use **explicit, versioned semantic
membership**, not names, broad `MaterialState`, density ranges or visual
similarity. The current catalogue is a direct counterexample to heuristic
inheritance: Wrought Iron, Bronze, Copper, Steel variants and pipe materials are
themed hard surfaces and do not automatically inherit base `Metal` charge or
Acid+Metal behavior; Stained/Chemical/Dark Glass likewise do not automatically
inherit base `Glass` reactions. Oak Timber and Thatch are explicit themed
exceptions because their descriptors deliberately select `Combustible`.

Introducing a family selector must therefore preserve current non-inheritance by
default. Any later expansion such as "conductive metals" or "reactive glasses"
is a separately versioned interaction/tuning decision with fixtures and evidence,
not an inference performed by the resolver.

### Rule identity and trigger shape

A rule needs a stable ID independent of its storage location. The minimum logical
record should be capable of expressing:

- stable rule ID and schema version;
- independent **channel**;
- selector origin: intrinsic, family/default, material, pair override or context;
- trigger kind: pair contact, source-driven neighbourhood/context, or
  intrinsic/state transition;
- participant roles and whether matching is ordered, unordered-with-role-effects,
  or genuinely symmetric;
- applicable material/family selectors;
- state/context predicates;
- cadence/probability/effective parameters where the mechanism owns them;
- bounded authoritative effects: conversion, state mutation, consume/source,
  product/byproduct/emission;
- explicit accounting requirements;
- provenance/origin and supersession history.

A conceptual resolved record might therefore describe
`aqueous.water-salt.dissolution` as an unordered participant match with
role-specific conversion effects, while Acid's generic corrosion can be a
source-driven family/default rule and Acid+Metal a more specific override.
This is a model for later validation, not permission to rewrite either behavior
before the gate.

### Independent channels

The initial channel vocabulary should remain independent rather than encoding a
single monolithic A-vs-B record:

- `thermal_phase`
- `dissolution_corrosion`
- `chemical_conversion_products`
- `combustion`
- `electrical`
- `curing_growth_special_state`
- `authoritative_emissions_byproducts`

A rule may contribute to more than one observable consequence, but changing one
channel must not silently replace unrelated values. If later source inspection
shows a channel needs splitting, version the vocabulary rather than forcing the
mechanism into a poor fit.

### Coverage ledger

Coverage is about **resolved intent and evidence**, not a percentage of N²
ordered material pairs. Each applicable subject/channel/context should resolve to
one of at least:

- inherited/default;
- explicitly non-interacting;
- characterized and accepted;
- accepted with known limitation;
- rejected candidate;
- superseded choice with retained evidence;
- explicit material/pair override;
- untested/not yet characterized.

The ledger should separately retain:

- authored resolution status;
- evidence status;
- effective rule/provenance chain;
- latest accepted tuning pass;
- known revalidation triggers.

This permits an inert construction family to be covered by an explicit inherited
non-interaction policy without manufacturing thousands of meaningless bespoke
pair records.

### Versioned pass and rolling-baseline provenance

An accepted interaction evidence record should eventually pin, at minimum:

- interaction schema/profile ID, version and hash;
- complete resolved rule/provenance chain relevant to the fixture;
- tuning-pass ID and parent accepted pass;
- exact changed rules/parameters;
- source revision and native artifact identity;
- material catalogue identity;
- MicroScenario definition/hash, recipe version and seed;
- runtime/platform/worker identity;
- transport profile/hash;
- Water semantic/presentation policy where contact can be affected;
- granular/contact/soliding or other kinetic policy identities that materially
  affect contact opportunity;
- observation/accounting outputs and retained artifact identity;
- accept / accept-with-limitation / reject / defer disposition;
- subsystem tags that determine targeted future re-screening.

A later #12/#18/#20/#26 change must invalidate only evidence whose declared
contact baseline or affected subsystem actually changed. Historical evidence is
retained rather than relabelled.

## 4. Generated fixture-family plan

Fixture generation should be mechanism-led. Every emitted topology must state
why it is applicable, and inapplicable Cartesian combinations should not be
generated merely to increase a coverage percentage.

| Initial family | Representative current seeds | Useful generated topologies | Important observations/controls |
|---|---|---|---|
| Aqueous dissolution/reactive | Water/Salt/Brine, Water/Sodium, Water/Toxic Sludge | horizontal contact; A-above-B/B-above-A where motion matters; droplet into bulk; separated-then-release; inert barrier/control | exact species start/end, products, Water accounting, first reaction, contact horizon |
| Thermal/phase | Lava/Water/Ice/Steam, Water/Molten Glass, Lava/Glass | horizontal contact; hot/cold start; small/bulk; barrier control; short/long horizon | phase/products, temperature/state where exposed, Water accounting, steady/quiescent state |
| Combustion | Fire/Wood/Oil/Coal/Dust, Gunpowder, Oak/Thatch, Water/Brine extinguishing | igniter beside target; small/bulk fuel; extinguishing contact; isolated no-ignition control | burn state/lifetime, consumed material, Fire/Smoke/products, time to ignition/extinguish |
| Corrosion | Acid/Metal/Rust plus generic Acid targets | horizontal contact; droplet/finite Acid; material family screen; Wall control | target removal/products, Acid strength/source-sink, specific-override provenance |
| Electrical | Spark/Metal and charged Metal near Water | line/branch conductor; Spark injection; Water-near-conductor; non-conductor control | charge propagation/state, Spark consumption, Steam/product creation |
| Cure/growth | Cement/Concrete/air/Water/Brine; Seed/Plant/Fungus | environment cells around fixed sample; substrate variants; positive/negative control | cure/growth state, conversion time, product count, source/state accounting |
| Special state/capture | Cloner; selected Mite/Rocket semantics | capture target + empty output; edible/non-edible controls; trigger/no-trigger | captured identity/state, products/sources, explicit separation from locomotion/ballistics |

The first post-gate proving fixtures should prefer already-tested, compact
semantics such as Water+Salt->Brine and a matched non-reacting control. They
validate the apparatus before any broad tuning campaign.

### Current MS-000 constraint relevant to fixture design

The inspected schema-v1 apparatus is intentionally narrow:

- bounded rectangle setup and partial Water fills;
- at most 24 scheduled `fill`/ `erase`/ `sample` events;
- at most 24 observations;
- current observation metrics are `water_integer`, `material_cells` and
  `tick`;
- headless uses the same validated definition/host but refuses live
  player/body-enabled definitions.

Issue #28 is actively extending the Materials Laboratory path and is responsible
for proving the same generated interaction definition can be operated
headlessly/interactively with identities, observations and fresh-reset A/B.

**INT-000 must not pre-empt that contract.** The logical fixture families above
remain design input until #28 publishes readiness and the resulting actual
definition/observation contract can be inspected.

## 5. Post-gate touchpoints and stop condition

### Likely implementation touchpoints after readiness

These are a map for a later agent, not files to modify during this preflight.

| Surface | Post-gate responsibility |
|---|---|
| `native/include/cybersand/material.hpp` | stable material IDs/descriptors remain catalogue authority; avoid turning descriptors into a giant interaction table |
| `native/include/cybersand/material_rules.hpp` / `native/src/material_rules.cpp` | current 14-pair oracle and likely migration/adapter boundary |
| `native/src/world.cpp` | source-driven rule oracle; migrate mechanisms incrementally without absorbing kinetic code or changing semantics merely to prove infrastructure |
| `native/tests/test_world.cpp` | preserve existing focused semantics and worker-parity tests as migration regressions |
| new bounded interaction module/data, path to be chosen post-gate | validated sparse authored model, stable IDs, resolver/compiler, effective values + provenance |
| `godot/scripts/microscenario_contract.gd` and #28 successor contract | generated-fixture declaration only after the readiness contract is known |
| `microscenario_host.gd`, catalogue/panel/identity and headless runner | effective profile identity, observations, A/B comparison and workbench integration without a second physics authority |
| tooling under `tools/` | fixture generation, coverage ledger, pass comparison and batch reporting |
| canonical docs/evidence | profile/pass semantics, coverage meaning, source/contact baseline and retained candidate history |

### Recommended post-gate implementation order

Once, and only once, the #28 readiness evidence exists:

1. rebase this preflight against the accepted #28 checkpoint and inspect the
   actual generated-fixture/observation contract;
2. freeze a minimal INT schema/version and stable rule/channel IDs without
   changing production outcomes;
3. import or mirror the current 14 pair reactions and selected specialized rules
   into a resolver whose effective output is provenance-visible;
4. prove semantic identity against existing native regressions before switching
   any production callsite;
5. add generated representative fixtures and coverage/pass records using the
   accepted Materials Laboratory/headless contract;
6. migrate specialized families incrementally, retaining source-matched tests and
   separating their kinetic portions;
7. only after apparatus identity is established, create separate bounded tuning
   passes. INT-000 itself does not authorize a broad retune.

### Explicit STOP condition for this preflight

**STOP HERE while #28 has not published a source-identified Materials Laboratory
readiness checkpoint satisfying all five issue criteria.**

Before that checkpoint, do **not**:

- create or wire a runtime interaction resolver/compiler;
- modify `material_rules.cpp`, `world.cpp`, material descriptors or production
  callsites for INT-000;
- add an interaction profile to World configuration;
- extend MicroScenario schema/runtime on behalf of #29;
- generate executable #29 fixtures that assume unlanded #28 fields;
- retune probability, cadence, products, burn/cure/growth parameters or any
  current material behavior;
- reinterpret #12/#18/#20/#26 kinetic behavior as an interaction rule;
- mark any interaction family accepted based on this source inspection.

The next #29 implementation agent must first verify the readiness evidence and
accepted source revision, reconcile this preflight against the landed #28
contract, and only then cross from design into implementation.
