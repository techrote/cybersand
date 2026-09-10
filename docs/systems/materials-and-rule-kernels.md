---
title: Materials and rule kernels
document-kind: contract
canonical-for: [material-runtime-model, material-kernel-cadence, reactive-material-families]
status: Current
scope: Native material identity, descriptors, mutable state, kernel execution, current interactions, and extension boundaries
last-reviewed: 2026-09-10
related-documents: [themed-construction-materials.md, material-appearance-and-rendering.md, water-design.md, smoke-heat-pressure-roadmap.md, ../research/sandspiel-performance-and-material-port.md]
---

# Materials and rule kernels

**Current:** native materials use immutable compiled descriptors and bounded
kernel families inside World. They do not own per-material threads or objects.
Every valid catalogue ID has implemented behavior, including intentional inert
`RuleKernel::None`. A type-enforced standalone rule context and external pack
loader are **Planned**.

This is the runtime contract for the [secured source checkpoint](../operations/source-checkpoint-and-recovery.md).
Test executions are scoped in the [evidence ledger](../reference/validation-evidence.md).

## Identity, descriptors, and state

[material.hpp](../../native/include/cybersand/material.hpp) defines byte-sized
`Material`, `MaterialDefinition`, `RuleKernel`, and constexpr descriptor lookup.
IDs 0–19 preserve the attributed Sandspiel numbering; 10 is invalid and
`Gas` aliases `Smoke` at 4. Project IDs continue through 80. Excluding Empty
and invalid 10 leaves 79 paintable materials. UI slots are not serialized IDs.

Descriptors carry material state, density/direction, target-side exchange
permission, lateral-flow mode, viscosity, kernel, initial compact state, palette,
and maximum write radius. Numeric density and movability do not by themselves
permit exchange. Descriptor values are fixed during a tick.

World owns the four-byte Cell: material, `state_a`, `state_b`, update epoch.
The two generic bytes hold material-specific mass, lifetime, burn/growth,
capture, heading, or projectile state. Stone `state_b` distinguishes
brace-aware Stone from explosion-created granular falling Stone. Temperature
is a separate optional field; [its current uses](smoke-heat-pressure-roadmap.md)
do not constitute a heat solver.

## Kernel execution and cadence

[World::update_cell, update_rule_kernel, and rule_is_active](../../native/src/world.cpp)
dispatch compact families. Private methods still couple storage access,
traversal, movement, and wake/dirty handling; a public bounded `RuleContext`
does not yet enforce that separation by type.

Active descriptors declare at most radius two; inert descriptors declare zero.
Phased jobs must remain within exclusive write domains and use deterministic
coordinate/tick/rule streams. A material may not select behavior from worker
identity or completion timing.

| Work lane | Current period | Scope |
|---|---:|---|
| Eligible transport/density motion | Each selected tick, except Mercury/powder permeability | Empty movement and native Water transfer remain full rate; [granular policy](granular-interaction-policy.md) owns pair exclusions and deadlines |
| Selected burn/charge/lifecycle work | 2 ticks | Kernel-specific, not every lifetime; Fire/Foam have full-rate portions |
| Pair chemistry, thermal/growth/capture checks | 4 ticks | Persistent contacts can react; brief contacts can be missed |
| Smoke lifetime/crowding | 8 ticks | Coordinate-staggered decay |
| Ice freezing sample | 16 ticks | Specialized sub-lane after the four-tick thermal gate |
| Ambient Fire ignition sample | 120 ticks | One sampled neighbor on the due lane |

Some waiting rules keep blocks active without a false render write; not every
kernel does so. Ice, for example, returns between thermal samples without an
explicit keep-awake call. Activity and contact persistence therefore also affect
which samples actually execute.
This deterministic cadence is Current approximate runtime behavior; it is not
a selectable strict-every-contact mode or full replay capture.

## Current material families

The table summarizes compiled behavior, not a complete pair-interaction matrix.
Exact triggering and writes are in `update_rule_kernel` and
[material_rules.cpp](../../native/src/material_rules.cpp).

| Family | Representative behavior |
|---|---|
| Sand, Stone, Dust | Gravity/settling; brace-aware or granular Stone; ignitable Dust |
| Water | Conserved pairwise mass; [Water contract](water-design.md) owns numeric semantics |
| Smoke, Steam, Foam | Buoyancy and distinct decay/phase behavior |
| Fire, Wood, Oil, Coal | Ignition/burn state, emission and selected extinguishing reactions |
| Lava, Ice, Glass, Molten Glass | Material/compact-state melting, freezing, cooling and quenching |
| Acid, Metal, Rust, Spark | Finite corrosion, local charge propagation, reactions with Water |
| Plant, Fungus, Seed | Bounded energy/growth, substrate rules, germination, combustion |
| Cloner, Mite, Rocket | Capture/emission, feeding/movement, payload/launch/trail/impact |
| Salt, Brine, Sodium, Gunpowder | Dissolution and energetic contact reactions |
| Cement, Concrete | Flowing wet Cement and environment-dependent cure |
| Toxic Sludge, Mercury | Purification reaction and high-density liquid exchange |
| Paste, Slush | Viscous whole-cell yield that can retain heaps |

Water alone uses `FreeMass`; `CellularYield` liquids retain whole-cell movement.
Viscosity is dimensionless gameplay tuning, separate from yield and adhesion.

## Why does burning Coal leave a purple layer?

**Current:** Coal's burn countdown ends by converting the cell to **Dust (ID 14)**.
Dust uses the pale-purple base color `(218, 198, 238, 255)`. It is the existing
powder material reused as combustion residue, not a distinct Ash material.
Fire/Smoke emissions happen during burning; the persistent purple residue is
Dust. This explanation is source inspection, not a change to combustion cadence.
See the Coal kernel in [world.cpp](../../native/src/world.cpp) and the
[material descriptor](../../native/include/cybersand/material.hpp).

### Project reactive IDs

| ID | Material | ID | Material | ID | Material |
|---:|---|---:|---|---:|---|
| 20 | Paste | 26 | Gunpowder | 32 | Toxic Sludge |
| 21 | Slush | 27 | Coal | 33 | Mercury |
| 22 | Steam | 28 | Metal | 34 | Spark |
| 23 | Salt | 29 | Rust | 35 | Glass |
| 24 | Brine | 30 | Cement | 36 | Molten Glass |
| 25 | Sodium | 31 | Concrete | 37 | Foam |

The [port ledger](../research/sandspiel-performance-and-material-port.md) owns
IDs 0–19 and attribution. The [construction catalogue](themed-construction-materials.md)
owns IDs 38–80: 41 inert hard surfaces plus combustible Oak Timber/Thatch.

## Boundaries and extension obligations

**Approved:** retain immutable descriptor data, World-owned mutable state,
bounded kernels, and explicit wake/dirty/conservation behavior. Coordinator-owned
explosions may exceed kernel radius only at the serialized tick boundary; that
does not enlarge worker write permission.

**Rejected in hot kernels:** growing containers, per-cell allocation, material
threads, Godot calls, schema parsing, and unbounded event creation. Lazy World
preparation can still allocate outside individual kernels during a tick; measure
that separately from kernel policy.

**Current duplication risk:** [CyberCellWorld](../../godot/scripts/cell_world.gd)
mirrors IDs manually and implements a narrower fallback. It treats themed
surfaces as static but does not reproduce native Oak/Thatch combustion.
Native descriptors, fallback constants, and appearance tables are not generated
from one catalogue.

Before adding/changing a material, identify state-byte meaning, numeric units,
radii, conversion/source-sink accounting, cadence, wake/dirty, save/hash impact,
and fallback behavior. Add meaningful reference, edge, worker-parity, and
capacity tests; update controls only if the UI changes. Follow the
[documentation checklist](../../AGENTS.md#documentation-obligations).

**Planned:** validated/versioned external packs, schema migration, generated pair
tables, a bounded rule context, broader reaction accounting and complete
interaction coverage. The JSON attribution ledger is research/provenance input,
not a runtime modding format or proof that every pair has been tested.

## Which penetration explanations have been measured?

**Historical issue #9:** the [dated physics baseline](../audits/2026-09-09-physics-characterisation.md)
reproduces ordered powder density exchange in packed layers and Mercury's rapid
downward passage through Sand. Mercury viscosity 96/160/224/248 produces identical
states in the confined vertical controls; the gate affects lateral movement.
Oil's specialized path declines the otherwise density-eligible Dust exchange.
Lava/Dust and Water/Salt require reaction accounting, not a transport-only label.

The [bounded measurement API](../operations/physics-characterisation.md) records
actual stored pairs for swaps and kernel-visible sources for contact attempts.
Its immutable construction overrides leave the shared descriptor table and
production defaults unchanged. A diagnostic target-wide exchange veto proves
causality; issue #10 now implements the [versioned granular policy](granular-interaction-policy.md).
Barrel bearing and feedback correction remain **Planned** for #11.

## Sampled player support

**Current:** the [version 1 granular policy](granular-interaction-policy.md) separates
material support capability from density and hard terrain. All nine powders can
support the sampled player when locally packed and stable; side resistance uses
a separate neighbourhood. The separate exchange checkpoint rejects powder/powder density reordering and
schedules Mercury/powder eligibility independently of viscosity.


## Opt-in transport profiles

**Current:** the [profile contract](../systems/flow-transport-and-profiles.md)
owns schema, inheritance, units, immutable native tables and explicit owner restart.
The Tower applies validated profiles through restart. Actual powder falls and
lateral Water mass transport drive bounded optional mixing and grain pickup;
horizontal sampling and cadence are separate fixed experiments.
Ordinary gameplay keeps Baseline; chemistry cadence, compact cells and CYSD1
are unchanged. No unsynchronized live descriptor mutation is introduced.
