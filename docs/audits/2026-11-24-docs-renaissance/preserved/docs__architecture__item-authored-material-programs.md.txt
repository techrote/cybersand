---
title: Item-authored material programs
document-kind: design
canonical-for: [item-authored-material-program-proposal]
status: Planned
scope: Proposed bounded material authoring and item recipes; current compiled substrate is identified separately
keywords: [visual material editor, item recipe, GUID, bounded IR, compiler, program registry]
related-documents: [../systems/materials-and-rule-kernels.md, rendering-and-gameplay-bridges.md, ../research/sandspiel-performance-and-material-port.md]
last-reviewed: 2026-09-08
---

# Item-authored material programs

## Does a visual material editor exist?

**Planned:** particle-recipe assets, a visual graph UI, compiler/validator,
runtime program registry and equipment/spawner editor are not implemented.
This page is a proposal, not a runtime API or an accepted serialized schema.
Its graph-language inspiration is recorded in the retained
[material research ledger](../research/sandspiel-performance-and-material-port.md).

**Current substrate:** [material descriptors](../../native/include/cybersand/material.hpp),
[MaterialRules](../../native/include/cybersand/material_rules.hpp) and
[World kernels](../../native/src/world.cpp) supply compact IDs/state,
bounded local rules, deterministic randomness and oriented pair reactions.
The existing [emission boundary](rendering-and-gameplay-bridges.md) can accept
material IDs independently of paint slots. Those ingredients make authoring
plausible; they do not prove a language/compiler design.

## What workflow is proposed?

A designer would attach a particle recipe to equipment, a projectile, enemy or
spawner. A recipe would select descriptor traits and local behavior, preview
it in the material lab, then compile before play into a small validated
intermediate representation. The runtime would emit its registered material
through a data-only command and execute bounded rules under existing spatial
ownership.

Stable content GUIDs would identify recipes across assets and saves; a session
registry would map them to compact runtime IDs. **Current CYSD1 uses numeric
material IDs**, not that proposed registry. Any introduction requires explicit
save/version migration, described in [level saves](../reference/level-saves-and-replay.md).
Hot reload also needs a safe rule/state transition; it is not implemented by
calling a replacement script while jobs run.

## What may an authored rule do?

The initial proposal covers neighborhood type/state tests, bounded neighbor
counts, finite boolean expressions, deterministic chance/direction, local
swap/change/state updates, fixed cadence and statically bounded repetition.
Descriptor and pair-table authoring could ship before a general interpreter.
Very hot/specialized behavior such as conserved Water can remain a native
kernel behind stable material identity.

The proposed validator must establish fixed bounds on radius, instructions,
reads/writes, emitted events and compact-state usage. Optional fields must be
declared before allocation/scheduling. Names and ranges should explain the
meaning of each state register. The current maximum rule radius is two cells;
an authored program must fit its selected geometry rather than silently
expanding worker write domains.

**Rejected within this proposal:** arbitrary scripts per cell, recursion,
unbounded loops, hot allocation, file/network access, Godot calls, thread
creation, retained pointers and unrestricted World access. Any non-local action
needs an explicit bounded event contract. The existing external explosion queue
does not yet provide generalized worker-produced event emission.

## How many custom materials would fit?

**Current:** material identity is one byte. IDs 0–80 except 10 are valid: Empty
plus 79 paintable materials. A proposed fixed resident catalogue has at most
255 non-empty values before further reservations; it must report exhaustion.
Silently widening every cell or hiding a program index in an undocumented
state byte would undermine the current compact-state contract.

**Deferred experiment:** optional per-chunk program/variant storage if real
content demonstrates that limit. Evaluate memory traffic, rule lookup, activity,
snapshot, streaming and save implications before selecting a representation.
No extra plane or dynamic GUID registry exists today.

## Which decisions and evidence are needed before implementation?

Freeze the minimum vocabulary and budget model, select a versioned recipe and
identity schema, then implement descriptor/pair authoring and native validation.
Only add an interpreter after measuring representative rules against compiled
kernels. A preview/editor needs useful bound/cost diagnostics; hot reload needs
an explicit drained transition and state migration.

Acceptance must include radius and instruction rejection, deterministic
one/multiworker execution, conservation where applicable, bounded event
pressure and safe failure of invalid programs. No authoring-specific acceptance
run exists. The [roadmap](../reference/status-and-roadmap.md) tracks priority;
[ownership](data-ownership-and-lifetimes.md) and
[ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md) constrain any
future runtime policy.
