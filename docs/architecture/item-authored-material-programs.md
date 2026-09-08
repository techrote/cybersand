---
title: Item-authored material programs
status: Planned
scope: Visual material authoring, item-owned particle recipes, bounded compilation, runtime identity, validation, and staged delivery
keywords: [visual scripting, item particles, material program, Sandspiel Studio, bounded IR, particle recipe]
related-documents: [../MATERIAL_LAB.md, rendering-and-gameplay-bridges.md, ../systems/materials-and-rule-kernels.md, ../research/sandspiel-performance-and-material-port.md]
last-reviewed: 2026-09-08
implementation-state: Current native descriptors, pair reactions, compact state bytes, deterministic randomness, and bounded kernels provide the execution substrate; visual graph assets, a compiler, runtime program registry, and item editor are Planned.
---

# Item-authored material programs

Evidence scope (2026-09-08): **Current** below describes inspected source in the
reconstructed local snapshot, not a verified Git HEAD or an all-platform test pass.
See the [documentation audit](../audits/2026-09-08-documentation-audit.md) for
source identity and dated validation; [M11 audit records](../audits/m11/README.md)
retain historical scope. **Approved design** means Approved direction; Planned,
Deferred, and Rejected statements do not claim implementation.

## At a glance

- The idea is practical because Sandspiel Studio's useful primitives closely match CyberSand's bounded local rule model.
- **Current**: material descriptors, adjacency reactions, two generic state bytes, deterministic random streams, and radius-limited native kernels already exist.
- **Planned**: equipment and spawner items own particle-recipe assets; paint remains only one producer of the same emission command.
- **Planned**: a visual graph compiles ahead of play into a small validated intermediate representation rather than running JavaScript in the cell loop.
- **Planned**: stable content GUIDs are mapped to compact runtime material IDs; UI slots never enter saves, rules, or simulation identity.
- **Planned**: static validation caps reads, writes, radius, instructions, event output, and state use before a program can load.
- **Explicitly rejected**: arbitrary script calls, recursion, unbounded loops, allocation, Godot access, and unrestricted world pointers inside a cell rule.
- **Deferred / experimental**: an optional per-chunk variant/program field is considered only if the one-byte resident material catalogue becomes a demonstrated limit.

## Search anchors

Sandspiel Studio blocks, visual material editor, item particle recipe, custom wand particles, bounded bytecode, material GUID, runtime material ID, mod safety

## Why the model carries over

Sandspiel Studio exposes local observations and actions: inspect a neighboring
cell, test type or state, count/touch neighbors, choose a direction, use chance,
swap/copy/change a cell, and update a few data registers. CyberSand already has
the same underlying ingredients, although they are currently expressed as C++
kernels and a compact pair-reaction table.

The transferable part is the language model, not the browser runtime. Blockly
or another graph UI can be used for authoring, but generated JavaScript must not
execute once per active cell. A content compiler should lower the graph to a
bounded rule representation that the native scheduler can validate and run.

## Item-based workflow

1. A designer creates or edits a particle recipe attached to an equipment,
   enemy, projectile, or spawner asset.
2. The recipe selects a base descriptor—phase, density, palette, viscosity,
   hard-surface status, and required optional fields—and defines local behavior
   in a visual graph.
3. The editor previews the material in the finite material lab and reports its
   maximum neighborhood radius, write count, instruction count, optional-field
   cost, and emitted-event bound.
4. The content build compiles the graph to a versioned bounded intermediate
   representation and rejects programs outside engine limits.
5. In the Planned authoring system, a registry maps each stable material GUID to a compact
   runtime ID. Save data and item assets retain the GUID, never a paint slot or
   transient numeric ID.
6. When used, an item emits a tick-boundary command containing the registered
   material handle, initial compact state, geometry, and approved emission
   flags. Painting calls the same command path.
7. Active cells execute the compiled program inside the scheduler's exclusive
   write domain. Deferred explosions or other bounded long-range effects use
   the existing event stage rather than bypassing cell ownership.
8. Editing or hot reload pauses publication at a safe tick boundary, validates
   the replacement program, remaps affected content, and then resumes.

## Proposed visual vocabulary

| Group | Initial blocks | Bound enforced by compiler |
|---|---|---|
| Neighborhood | read type/state, touching, count, cardinal/Moore direction | Declared radius, initially no greater than two |
| Conditions | compare, boolean operators, phase/trait checks | Finite expression depth |
| Randomness | deterministic chance, choose direction, named random stream | No global or wall-clock randomness |
| Mutation | swap, copy initialized material, change self/neighbor, set state byte | Maximum writes per invocation |
| Timing | every-N-ticks cadence, compact lifetime/countdown | Fixed bounded cadence; no sleeping wall-clock timers |
| Events | bounded heat/impulse/explosion/emission request | Fixed event count, radius, and payload size |
| Control flow | if/else and a small fixed repeat | No recursion or data-dependent unbounded loop |

The compiler should expose state bytes by designer-defined names and ranges, so
`state_a` and `state_b` never become undocumented magic registers. Programs
that require temperature, body ownership, charge, or another optional field
must declare it so storage and scheduling costs are visible before play.

## Runtime tiers

Not every behavior needs the same executor:

| Tier | Suitable behavior | Current example |
|---|---|---|
| Descriptor | Passive identity, density, palette, viscosity | Salt, Mercury, Glass |
| Pair table | Symmetric local chemistry | Water + Salt, Water + Sodium |
| Bounded compiled program | Most item-authored local state machines | **Planned** |
| Native kernel | Very hot or unusually specialized behavior | Water mass solver, Rocket |
| Deferred event | Bounded non-local result | Explosion/collapse command |

The editor may begin with the descriptor and pair-table tiers before adding a
general bytecode interpreter. Frequently used compiled programs can later be
specialized or promoted to native kernels without changing their stable content
identity.

## Identity and capacity

The current cell has a one-byte material ID: 256 representable values, with
Empty using 0. The present valid catalogue is IDs 0–80 excluding 10 (80
valid identities, 79 paintable). A future registry has at most 255 non-empty
values before additional reservations; it is not yet implemented. The first authoring release should therefore build a fixed resident
catalogue at session start and fail clearly if its capacity is exceeded. This
is preferable to silently widening every cell or hiding a program index in an
undocumented state byte.

If real game content proves that limit insufficient, a later experiment may
allocate a variant/program plane only in chunks that contain custom particles.
That experiment must measure memory traffic and define save, wake, snapshot,
and streaming behavior before replacing the compact catalogue.

Current CYSD1 saves use fixed numeric material IDs, not the proposed GUID
registry. Source substrate: [material definitions](../../native/include/cybersand/material.hpp),
[rule descriptors](../../native/include/cybersand/material_rules.hpp),
[World kernels](../../native/src/world.cpp), and
[demo save payload](../../native/include/cybersand/demo_snapshot.hpp).
No graph compiler, registry or editor is evidenced in this snapshot.

## Safety and performance gates

A program is loadable only when validation can prove:

- every read and write is relative and within the declared radius;
- instruction, write, and event counts have fixed upper bounds;
- loops are statically bounded and recursion is absent;
- all random values come from deterministic simulation streams;
- optional fields and state-register meanings are declared;
- no allocation, file/network access, Godot call, pointer retention, or thread
  creation occurs in the rule;
- its write radius fits the selected scheduler geometry.

These restrictions still permit unusual item particles—seeking sparks,
catalysts, self-copying spores, programmable fuel, or temporary foams—while
keeping their worst-case cost and ownership behavior inspectable.

## Reference basis

- [Sandspiel Studio](https://github.com/MaxBittker/sandspiel-studio), inspected
  at commit `b78f89ec908192bb689af31ef83c3ec2ee46c74b`, demonstrates the visual local-rule vocabulary.
- [Sandspiel Studio block reference](https://github.com/MaxBittker/sandspiel-studio/blob/main/docs/blocks.md)
  documents neighbor, state, chance, mutation, and bounded-repeat concepts.
- [Noita materials](https://noita.wiki.gg/wiki/Materials) informed the choice
  of reaction families and the separation of fast motion from slower phenomena.
- [AuraLite Powder](https://github.com/AlexanderNyr/AuraLite-Powder), inspected
  at commit `34f889873765201d2912185a1f680aa75ed69b8a`, informed the explicit
  descriptor/reaction/pass separation. No AuraLite implementation code is included.

## Delivery sequence

1. Freeze the graph vocabulary and static budget model.
2. Add a versioned recipe schema with stable GUID identity.
3. Implement descriptor and pair-reaction authoring first.
4. Add a native validator and interpreter for bounded programs.
5. Connect equipment/spawner assets to the generic emission queue.
6. Add preview, diagnostics, safe tick-boundary reload, and save remapping.
7. Profile representative authored materials before adding optional variant
   storage or native specialization.

## Related decisions

- [Material rules](../systems/materials-and-rule-kernels.md)
- [Rendering and gameplay bridges](rendering-and-gameplay-bridges.md)
- [Data ownership](data-ownership-and-lifetimes.md)
- [Bounded approximate fidelity](../decisions/ADR-008-bounded-approximate-fidelity.md)
