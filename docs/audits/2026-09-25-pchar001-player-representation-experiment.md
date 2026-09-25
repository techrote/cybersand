---
title: PCHAR-001 switchable player representation and burial-safe experiment
status: Current
document-kind: evidence
scope: Issue #137 mechanism attribution, implementation boundary and retained fixture plan/results; parent #132 remains open
canonical-for: []
last-reviewed: 2026-09-25
related-documents: [../systems/granular-interaction-policy.md, ../architecture/rigid-body-and-cellular-coupling.md, ../reference/status-and-roadmap.md, 2026-09-25-rem003-player-granular-acceptance.md]
---

# PCHAR-001 switchable player representation experiment — 2026-09-25

## Frozen starting point and ownership boundary

Issue #137 starts from current-main merge
`eac6caff06d9d7f87c2e0a9598b96eb51520d4a0` (REM-003 / PR #129).
No pre-existing #137 branch existed when work began. The contemporaneous #135
branch was still identical to main and #136 had no branch, so this checkpoint
took an isolated PCHAR write set.

PCHAR-001 does not change native material authority, generic body occupancy,
granular bearing, ejection, result ABI, sample-age policy, hard-terrain ownership,
Water behavior or #12 soliding. Any need to change those semantics stops here and
routes to #83 / REM-004. The red rectangle remains a generic reference body.

## Mechanism attribution: why the sampled player surfaces

The pre-PCHAR sampled character called enclosure recovery at the start of every
simulation step. If its complete body box collided, that path searched distance
1..32 and tested directions **up, left, right, down** at every distance. The first
clear candidate replaced the sampled actor position and zeroed its velocity.

That is the direct upward-surfacing mechanism observed when incoming material
eventually becomes support-capable inside the sampled actor volume. The operation
moves the actor rather than material, so it does not delete cells, but the
upward-first positional relocation is a runtime anti-enclosure policy rather than
a physical reaction to pressure.

PCHAR-001 retains that exact behavior as the explicit
`sampled-baseline` control and publishes counters for runtime attempts,
successes, cumulative upward cells, last recovery kind and last offset.

## Sampled burial-safe arm

The `sampled-burial-safe` arm disables runtime enclosure search. When the
sampled actor is overlapped at runtime it remains at the same position, velocity
is zeroed and `runtime_enclosed/recovery_blocked` is exposed. No material is
deleted, displaced or teleported by this response.

Invalid-spawn/reset repair remains a separately callable bounded search, so bad
fixture/spawn placement is not conflated with runtime burial. The mode is
experimental and may immobilize the actor until material changes or a later
explicit escape mechanic is introduced.

## Barrel/Rapier arm

The `barrel-rapier` arm reuses body 0, the existing 8x14 red reference
rectangle. Switching occurs only through a fresh world/body reset: there is no
in-place conversion between sampled and Rapier ownership.

Ordinary A/D input produces a bounded horizontal central impulse after the latest
cellular results have been applied. The controller:

- targets 42 px/s horizontally;
- permits at most 180 px/s² horizontal acceleration;
- caps one control impulse at 3 units;
- applies no control impulse with zero horizontal input;
- reads live PhysicsServer velocity after cellular reaction;
- never assigns linear velocity;
- never changes the vertical component.

Gravity, angular motion, hard-terrain contact, body masks and all cellular
displacement/contact/bearing feedback therefore remain the current generic-body
path.

## Retained fresh-reset fixtures

`test_pchar001_player_representations.gd` keeps two mechanism controls plus the
requested seven barrel scenarios:

| Fixture | Purpose |
|---|---|
| sampled runtime enclosure | Reproduce and count upward-first baseline relocation without changing Sand count |
| sampled burial-safe + invalid spawn | Prove runtime non-reordering while explicit reset repair remains separate |
| falling-onto-player | Settled support plus incoming granular curtain |
| walking-into-loose-falling | Same incoming material with bounded horizontal barrel control |
| adjacent-pile-support-erased | Remove support beneath an adjacent pile at a registered tick |
| progressive-burial | Longer incoming-granular exposure without any player teleport mechanism |
| lateral-pressure | Controlled body moving into a one-sided packed granular column |
| ordinary-packed-support | Retain current generic granular-bearing control |
| hard-terrain-control | Keep Rapier hard contact distinct from granular response |

The controller also has a direct real-Rapier check: a cellular x/y impulse is
applied first, then horizontal control is applied. The test requires the incoming
reaction to remain observable, the control impulse to stay within its cap and the
vertical velocity to remain unchanged.

The `side_erase` fixture has an explicit material sink by construction: the
registered erase operation is the experimental input and is not interpreted as
spontaneous conservation failure. Other retained granular arms require unchanged
Sand cell count inside the complete fixture crop.

## Exact-head validation and observed result

Frozen executable-source head is
`5cf644588af1ed8e6936862ba1419e82f2c198d5`.

GitHub Actions on that exact head passed:

- GDExtension/Godot run `36146011393`: Linux source-matched extension build,
  Windows x86_64 cross-build, four isolated Linux Godot regression shards and
  the aggregate Linux gate all succeeded.
- Native C++ run `36146011480`: the full native validation workflow succeeded.
- Documentation/provenance run `36146011195`: documentation, dependency/runtime
  provenance, retained M11 integrity, retrieval, LFS and whitespace checks
  succeeded.

The PCHAR test executed on Linux Godot 4.7 against the exact source-matched
runtime in shard 0 and passed. Its retained summary reproduced the intended
mechanism separation:

- sampled baseline runtime enclosure moved exactly **14 px upward**;
- sampled burial-safe remained at **(100,100)**;
- explicit invalid-spawn recovery separately moved **14 px upward**;
- a synthetic cellular body reaction produced live velocity approximately
  **(1.248,-0.499)**;
- zero player input applied **0.0** control impulse and preserved that live
  velocity exactly at the control boundary;
- positive horizontal control applied the registered **3.0** impulse cap,
  increasing x velocity while leaving y unchanged at application.

All seven requested barrel fixtures executed successfully. Lateral pressure
produced cumulative cellular x reaction opposite the positive locomotion direction
(about **-66.76** applied x impulse), while the hard-terrain control produced zero
cellular reaction. This demonstrates that material reaction remains able to move
the player rather than being overwritten by locomotion.

The stress fixtures also retain an important generic-body limit rather than
silently treating the experiment as production acceptance: unresolved-overlap
counts were high under sustained burial/pressure (for example **9,345** for
walking into loose/falling material and **7,552** for lateral pressure). Current
generic coupling preserves the stored material when no bounded ejection target
exists, so these counts are not material loss, but they confirm that broad
high-pressure body/granular behavior remains #83 / REM-004 work. PCHAR-001 does
not change that generic mechanism.

## Disposition

The bounded PCHAR-001 experiment satisfies its engineering purpose: the sampled
upward-ejection mechanism is identified and directly reproduced; a burial-safe
sampled arm keeps runtime enclosure in place while preserving separate spawn
repair; and a controllable barrel/Rapier arm reuses existing coupling while
retaining incoming reactions.

This result does **not** select the barrel representation as the production player,
nor does it close the durable representation programme. Parent #132 remains open
after #137. The retained high-pressure generic-body limitations are routed to
#83 rather than absorbed here.
