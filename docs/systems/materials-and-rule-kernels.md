---
title: Materials and rule kernels
status: Current
scope: Current material catalogue, themed static solids, immutable descriptors, mutable per-cell state, compact kernels, allocation limits, interactions, and extension procedure
keywords: [MaterialRules, static solid, medieval, cyberpunk, material descriptor, rule kernel, per-cell state, reaction]
related-documents: [themed-construction-materials.md, material-appearance-and-rendering.md, ../architecture/module-boundaries.md, water-design.md]
last-reviewed: 2026-09-08
implementation-state: The byte catalogue contains the adapted reactive set plus 43 themed construction materials at IDs 38–80; 41 are inert zero-radius hard surfaces, Oak Timber/Thatch reuse the combustible kernel, and standalone RuleContext remains planned.
---

# Materials and rule kernels

Source anchors: [material descriptors](../../native/include/cybersand/material.hpp),
[World kernels](../../native/src/world.cpp),
[catalogue provenance](../../native/data/material-packs/sandspiel-mit-reference.json),
and [native family fixtures](../../native/tests/test_world.cpp). The
[2026-09-08 audit](../audits/2026-09-08-documentation-audit.md) identifies the
local snapshot and dated runs. Current describes source behavior in that scope;
fixture presence is not a new passing result or full pair-interaction proof.

## At a glance

- Purpose: add complex elements without a material-class hierarchy or scheduler coupling.
- **Current**: Material is a byte enum containing the full attributed Sandspiel material-ID catalogue plus project materials through ID 80; slot 10 remains invalid.
- **Current**: MaterialRules exposes immutable descriptors with density, directional density motion, target exchange permission, lateral-flow mode, normalized viscosity, state, palette, kernel, compact initial state, and maximum write radius.
- **Current**: every valid catalogue ID has an adapted executable bounded kernel.
- **Current**: two generic state bytes cover liquid mass, lifetime, burn/growth state, heading, germination, capture, and rocket payload/direction.
- **Current**: Stone `state_b` distinguishes brace-aware Stone from explosion-created granular falling Stone.
- **Current**: compact kernel families run through phased jobs; no material owns a class hierarchy or thread.
- **Current**: 43 construction materials add medieval and industrial vocabulary without changing the four-byte Cell or one-byte material identity.
- **Current**: inert construction cells select `RuleKernel::None`, radius zero, and leave the active scheduler; only Oak Timber and Thatch can activate the existing radius-one combustible kernel.
- **Explicitly rejected**: allocation, dynamic registration, or Godot calls inside a material hot path.
- Unresolved: final descriptor schema, kernel catalog, reaction representation, and modding format.

## Search anchors

where material rules allocate, add a material, MaterialDefinition, World update_cell, data-driven material, rule kernel, material inheritance

## Current native model

native/include/cybersand/material.hpp defines:

- byte-sized Material enum values for the reactive catalogue and stable themed construction IDs 38–80;
- MaterialState;
- MaterialDefinition;
- DensityMotion, LateralFlowMode, and a normalized viscosity index;
- constexpr material_definition lookup;
- a `current_rule_available` marker that prevents catalogue presence from being mistaken for executable behavior.

The complete source-behavior ledger is
`native/data/material-packs/sandspiel-mit-reference.json`. It is **Current**
provenance and adaptation data, while the compiled kernels live in
`native/src/world.cpp`. The runtime does not parse JSON in the hot path. See
[the source audit](../research/sandspiel-performance-and-material-port.md).

native/src/world.cpp dispatches `RuleKernel` families from World::update_cell.
Directional density swaps, pairwise Water transfer, reactions, compact state machines, and
dirty/wake observations currently remain private World methods.

Viscosity is a dimensionless gameplay value rather than a claim of physical
units: 0 is maximally mobile and 255 is slowest. Water is 0; Acid, Oil, and Lava
currently carry provisional values of 64, 160, and 224. Native fixed-mass flow
uses the index to scale local pairwise transfer without increasing write radius.
The serial GDScript reference maps the same scale to bounded multi-cell
dispersion; yield remains a separate property.

The current implementation has deterministic worker-parity fixtures,
but gameplay semantics no longer promise that every secondary contact is sampled
on every fixed tick. It still couples:

- material behavior;
- storage access;
- scan ordering;
- movement mutation;
- wake/dirty handling.

## Current Godot model

godot/scripts/cell_world.gd duplicates material constants and implements Sand,
Water, and Smoke behavior inside _simulate_block and helper functions. It mirrors
IDs 38–80 and treats them as static hard surfaces, but does not reproduce native
Oak/Thatch combustion on unsupported architectures. It is still not generated
from the native catalogue.

The native and Godot definitions are not generated from one catalog and may diverge.

## Approved separation

### Immutable descriptor data

MaterialRules owns immutable data that describes material identity and the rule/field capabilities required for a tick. Descriptor data is fixed for the duration of a tick.

The existing compiled descriptor fields are **Current**. External pack loading,
schema versioning, validation, and migration remain **Planned**.

### Mutable authoritative state

WorldStorage owns mutable committed cell and optional-field data. MaterialRules does not own per-cell containers.

Examples by status:

| State | Status |
|---|---|
| Material identity per loaded cell | **Current** concept; production representation undecided |
| Optional temperature SoA in native Chunk | **Current** storage only |
| Liquid fixed-point mass in Water `state_a` | **Current** |
| Granular-collapse marker in Stone `state_b` | **Current** |
| Pressure/composition fields | **Planned** |
| Render-only dither phase/pattern | **Current** stable coordinate/condition shader derivation; broader appearance-authoring schema remains Planned |

### Compact rule kernels

**Current**: the `RuleKernel` enum selects bounded data-oriented behavior without
subclasses. All active descriptors declare a maximum radius no greater than two.
The private dispatcher still accesses World directly; a type-enforced context
that makes out-of-radius access unrepresentable remains **Planned**.

## Allocation policy

### Forbidden in hot kernels

- growing containers;
- per-cell heap allocation;
- material-specific thread creation;
- runtime Godot object lookup;
- schema parsing;
- unbounded event creation;
- implicit optional-field allocation.

### Allowed outside hot kernels

Under an explicit loading or safe reconfiguration transition:

- descriptor catalog loading/validation;
- rule-table compilation;
- optional-field capacity preparation;
- bounded buffer resizing;
- migration between versioned definitions.

Exact allocator and catalog APIs are undecided.

## Rule execution constraints

A rule kernel is intended to:

- read only its supplied bounded neighbourhood;
- read immutable MaterialRules data;
- write only its phase-owned local domain;
- emit bounded local activity/dirty observations.

A rule kernel may not:

- exceed its declared write radius or overlap another same-phase write domain;
- select behavior based on worker identity or completion time;
- iterate unordered data where order changes authoritative output;
- access scene, render, audio, or gameplay objects;
- retain pointers beyond the job stage.

## Material interactions

Interactions must eventually support smoke, heat, pressure, phase changes, chemistry, electricity, corrosion, and complex cyberpunk materials without creating a second world model.

**Current**: common density, ignition, extinguishing, corrosion, phase-change,
growth, agent, cloning, and projectile interactions are compiled kernels.

### Temporal fidelity lanes

Transport, falling, buoyancy, and primary liquid motion remain full-rate. More
expensive or visually tolerant secondary work uses stable spatial phases so a
fixed tick does not present one large interaction burst:

| Work | Current cadence | Gameplay consequence |
|---|---:|---|
| Movement and density exchange | every tick | Contact and silhouette motion stay responsive |
| Burn/charge/basic lifecycle | every 2 ticks | Short-lived contacts may be missed |
| Pair chemistry, thermal checks, growth/capture | every 4 ticks | Eligible persistent contacts are sampled; no guarantee that every brief contact reacts |
| Smoke lifetime/crowding | every 8 ticks | Dissipation is gradual and spatially distributed |
| Ambient Fire ignition | every 120 ticks | Existing low-frequency fire interaction remains distributed |

Cells waiting for their lane keep their activity block awake without publishing
a false dirty render patch. The lane phase is currently coordinate-stable for
worker parity and regression repeatability, but exact replay is a validation
property of this build rather than a gameplay requirement. A contact that exists
only between samples is intentionally allowed to have no secondary reaction.
Density exchange is vertical, directional, and opt-in: falling materials may
replace lighter permitted media below, while rising gases may replace heavier
permitted media above. Static targets and the current movable Mite/Rocket agents
decline the exchange even when their numeric density would otherwise allow it,
demonstrating that movability and permeability are separate. FreeMass identifies
conserved self-leveling Water; CellularYield retains heap-capable whole-cell
liquid behavior for Oil, Acid, Lava, and the Current native Paste/Slush families.
The preferred native Godot proof has Current Paste/Slush at IDs 20/21 and a
second representative family set at IDs 22–37: Steam, Salt, Brine, Sodium,
Gunpowder, Coal, Metal, Rust, Cement, Concrete, Toxic Sludge, Mercury, Spark,
Glass, Molten Glass, and Foam.
Bounded explosion work is coordinator-owned rather than a material kernel: it
may touch a configured radius greater than two only at the serialized tick
boundary, converts eligible Wall to tagged granular Stone, and wakes/marks each
edited cell. This does not expand any worker RuleKernel's write radius.
**Current**: suitable symmetric adjacency chemistry is stored in a compact
orientation-independent pair table, while movement and longer state machines
remain bounded native kernels. **Planned**: generate that table from validated,
versioned external packs without runtime schema parsing.

The Sandspiel JSON file does not approve that final format. It is a provenance-preserving input and migration checklist; production code must not parse it in the hot path.

## Themed construction solids

IDs 38–80 are a project-authored palette rather than an attributed Sandspiel
port. All have immutable `MaterialState::Solid` descriptors, are immovable, valid,
and exposed through the C API. `MaterialRules::is_hard_surface` includes the
whole contiguous range so native character tests, hard-surface revisions,
chunk geometry extraction, and Rapier terrain agree.
This does not make cell identity immutable: Oak Timber/Thatch combustion and
explicit editing can change the cell.

The 41 inert descriptors use `RuleKernel::None`, initial state zero, and maximum
write radius zero. They do not receive scheduled updates merely because they
have different names or appearance programs. Oak Timber and Thatch select
`RuleKernel::Combustible`; zero burn state remains inactive, while ignition
uses the same deterministic radius-one writes as Wood. Fungus and Mite treat Oak
Timber as timber where their existing bounded rules previously recognized Wood.

This separation is intentional: architectural visual variety is cheap and does
not justify duplicating a physics kernel. A new chemical/mechanical distinction
should be added only when gameplay requires authoritative behavior, with tests
and an explicit descriptor/kernel change rather than inferred from colour.

The full ID table, collision/combustion behavior, GPU finish, and scene recipes
are in [Themed construction materials](themed-construction-materials.md).

## Adding a material safely

The extension workflow requires:

1. Define immutable descriptor data.
2. Identify every required mutable optional field.
3. Select an existing compact kernel family or justify a new general kernel.
4. Define boundary-transfer and conservation behavior.
5. Define wake, sleep, and dirty behavior.
6. Define deterministic conflict behavior.
7. Add single-thread reference tests.
8. Add tile/chunk edge and multithread replay tests.
9. Add profiling fixtures and observe capacity/allocation effects.
10. Update status documentation without claiming unimplemented coupling.

If a material appears to require its own scheduler or thread, the design must be reconsidered.

## Water as the reference material

Water established the first compact state and scheduler contract because it requires:

- conserved state;
- bounded cross-tile flux;
- stable rest;
- conversion between material occupancy and optional state;
- render-only dithering;
- deterministic single- and multithread behavior.

Sand, Smoke, and the imported catalogue now use the backend. Heat conduction,
pressure, and composition remain **Planned** optional-field systems.

## Related decisions

- [ADR-001](../decisions/ADR-001-native-simulation-core.md)
- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-005](../decisions/ADR-005-water-model.md)
- [Themed construction materials](themed-construction-materials.md)
