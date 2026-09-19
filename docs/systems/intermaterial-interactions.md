---
title: Intermaterial interaction substrate
status: Current
document-kind: system
scope: Versioned sparse authoring, resolution, provenance, coverage and migration contract for non-kinetic intermaterial semantics
canonical-for: [intermaterial-interactions, interaction-schema, interaction-provenance, interaction-coverage]
last-reviewed: 2026-09-19
related-documents: [../operations/microscenarios-programme.md, materials-and-rule-kernels.md, ../operations/microscenario-reference-pack.md, ../reference/status-and-roadmap.md]
---

# Intermaterial interaction substrate

## Current boundary

INT-000 owns non-kinetic material/material semantics: conversions and products,
combustion/ignition/extinguishing, thermal/phase consequences, dissolution and
corrosion, cure/growth/special state, electrical consequences and authoritative
emissions/byproducts.

It does **not** own Water transport/head/leveling, density exchange, granular
support/bridging/bracing, erosion/entrainment, collision/ballistics, Rapier,
soliding, or scheduler semantics. Those systems may change whether contact occurs;
their identities are provenance/revalidation inputs rather than interaction rules.

Current source still has four distinct semantic classes: compact pair-contact
reactions; source-driven neighbourhood/context kernels; intrinsic/lifecycle state
transitions; and kinetic/contact physics outside INT-000 ownership. The permanent
substrate represents and inspects the first three without pretending the fourth is
an interaction rule.

## Schema and profile identity

The native authored source is native/include/cybersand/interaction_rules.hpp.

Current schema/profile:

- schema ID cybersand.interactions, version 1;
- profile ID int.current-behaviour, version 1;
- tuning-pass root int.pass.current-oracle, version 1.

The source is sparse constexpr data plus a deterministic resolver. It is
human-reviewable and diffable. A generated dense cache is not currently used and
must not become the authored source of truth merely for convenience.

Stable independent channel IDs are thermal_phase, dissolution_corrosion,
chemical_conversion_products, combustion, electrical,
curing_growth_special_state, and authoritative_emissions_byproducts. A rule can
participate in more than one channel without replacing unrelated channels.

## Participant semantics and precedence

Current compact rules use **unordered matching with role-preserving effects**.
Reversing source/target therefore reverses role-specific products; it does not make
the effects symmetric.

The Current resolver order is intentionally simple: explicit sparse pair match,
stored probability boundary, then role-preserving products plus stable
rule/channel provenance. Specialized neighbourhood/lifecycle entries are
represented in the same profile catalogue but remain authoritative in their
existing world.cpp kernels unless a later bounded migration proves exact separation
from movement/contact code. This is an explicit limitation, not a second authority.

Future family defaults, material adjustments or context modifiers require explicit
precedence/conflict tests before becoming authoritative.

## Explicit semantic families

Family membership is explicit and versioned. It is never inferred from material
name, MaterialState, density, appearance or themed construction naming.

The initial families make Current distinctions inspectable: bounded Combustible
kernel members; base Metal as the only conductive-base-metal member; base Glass as
the only reactive-base-glass member; and explicit hot-source, aqueous-contact,
biological-growth and special-agent sets.

Consequently Wrought Iron, Bronze, Copper, Steel variants, Copper Pipe and other
themed materials do not inherit base-Metal electrical or Acid+Metal pair semantics.
Stained/Chemical/Dark Glass do not inherit base-Glass pair semantics. Any later
expansion is a versioned tuning decision with fixtures/evidence.

## Compact pair migration

The frozen Current oracle contains 14 sparse compact reactions. Stable rule IDs,
products and probabilities are defined by kPairInteractionRules.

Migration is behavior-preserving. Native regression compares the sparse shadow
resolver against the pre-migration MaterialRules::pair_reaction oracle across all
material IDs, both orientations and probability-boundary samples before authority
is switched. After a bounded switch, the public MaterialRules API remains available
to World but delegates to the versioned resolver.

The four-tick contact cadence, neighbour order/random salts, Water-state
initialization, worker ownership and writes remain World-owned; the resolver
selects semantics only.

## Specialized Current mechanisms

kSpecializedInteractionRules gives stable IDs/provenance for Steam condensation,
Fire/Combustible, Gunpowder/Coal, Metal/Spark consequences, Cement cure, Molten
Glass cooling, Lava/Ice thermal contact, Acid broad corrosion, Cloner,
Plant/Fungus/Seed, Mite, Rocket state and Foam lifecycle.

These records identify current world.cpp authority and the non-kinetic semantics
represented. They do not duplicate runtime execution and do not absorb movement,
Water flow, granular motion or ballistics.

## Coverage ledger

Coverage is not an N-squared percentage. Authored status is separate from evidence
status and distinguishes inherited/default, explicitly non-interacting,
characterized/accepted, accepted with limitation, rejected, superseded, explicit
override and untested.

The initial ledger records the 14 compact overrides, represented specialized
mechanisms, Water+Sand as a non-INT transport control, themed metal/glass
non-inheritance and future tuning as untested. Later passes add sparse subjects
rather than meaningless Cartesian entries.

## Provenance and revalidation

Stable rule IDs carry channel membership, accounting notes and subsystem
revalidation tags. Dated evidence additionally pins source/runtime/material
catalogue/MicroScenario/transport/Water/platform/worker identities.

A later Water, granular-contact, scheduler, thermal, biological or ballistic
change can identify affected evidence for re-screening. Old evidence remains under
its original identities.

## Materials Laboratory and generated fixtures

Schema-2 MicroScenarios remain the sole scenario/workbench apparatus. INT-000 does
not add scenario-specific physics callbacks.

Generated fixtures use complete definitions and therefore run unchanged through
the native-only runner, Materials Laboratory, fresh-reset A/B comparison and batch
evidence tooling. The first proof family uses Water+Salt -> Brine plus a Water+Sand
non-interaction control, followed by representative Current thermal, combustion,
corrosion, electrical and cure/state fixtures.

## Change discipline

Before switching additional production authority: characterize Current; represent
it; prove shadow equivalence; resolve every mismatch as migration defect; switch
one bounded semantic boundary; retain reference regressions; then update evidence
and retrieval routes. Broad material retuning is outside INT-000, and world.cpp
must not be rewritten merely for architectural uniformity.
