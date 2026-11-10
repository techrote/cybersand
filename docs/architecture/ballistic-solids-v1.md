---
title: Ballistic solids (BS-001, experimental)
status: Current
document-kind: reference
scope: Draft-branch BS-001 ballistic_solids_v1 native owner for flying solid/powder cells; admission, ownership, landing, body impulse, accounting, identity/persistence, capacity, workbench options and equipment; not on main, no default changed
canonical-for: [ballistic-solids-v1]
last-reviewed: 2026-11-10
related-documents: [ballistic-water-v1.md, rigid-body-and-cellular-coupling.md, ../systems/workbench-liquid-equipment.md, ../audits/2026-11-10-bs001-ballistic-solids.md]
---

# Ballistic solids (BS-001, experimental)

**Status:** implemented on Draft branch `feat/ballistic-solids-20261110`, stacked
on the #361 equipment branch; **not on main**. Opt-in per World. A World that does
not enable it keeps its hash, persistence bytes, ledger and behaviour. Evidence:
the [dated BS-001 record](../audits/2026-11-10-bs001-ballistic-solids.md).

## Why

[Ballistic Water](ballistic-water-v1.md) gave Water real flight. Sand, gravel and
rubble had none: any "thrown" powder was painted in place at rest. BS-001 is the
granular counterpart: a bounded native owner for whole cells in flight, reusing
the BW-001 tick slot, swept-contact rules, per-body impulse channel and render
overlay, so launchers, hoppers and debris can throw material that lands and hits
bodies.

## Owner

Source: [`ballistic_solids.hpp`](../../native/include/cybersand/ballistic_solids.hpp),
[`world_ballistic_solids.inc`](../../native/src/world_ballistic_solids.inc); hooks in
`world.cpp` (construction, `clear`, tick entry, render copies),
`world_quantity.inc` (validation) and `world_pressure.inc` (hash, CYPS, retained
rebuild).

- **Enable:** `WorldConfig::ballistic_solids.enabled`; **requires ballistic Water**
  in the same World (construction refuses otherwise). Capacity defaults to 4096,
  maximum 65,536 slots, reserved at construction; launches beyond it refuse with
  `CapacityFull`.
- **State:** `BallisticSolid` holds a q256 position and signed velocity, the cell's
  material and state bytes, age, contacts, deferrals and the launching body.
- **Admission:** powders always; other solids unless they are structural walls
  (`Wall`, `ReinforcedConcrete`, or wall density 65535); and every **non-Water
  liquid** (Oil, Lava, Acid, Brine, Mercury, Slush, Paste, Toxic Sludge, Molten
  Glass), which are whole-cell materials and fly as their own cell. Water flies as
  BW-001 parcels. Gases, agents and Empty never fly (`NotAdmitted`).
- **Launch** (`launch_ballistic_solid`, serialized between ticks) moves one grid
  cell (material and state) into a flying solid spawned at an unmasked Empty/gas
  cell. **Inject** (`inject_ballistic_solid`) creates one of an admitted
  material from an external stock (counted as `injected`). Refusals never mutate.
- **Advance:** once per tick at tick entry, immediately after ballistic Water,
  serially in slot order, so results are identical for any worker count.
  Gravity 22/256, drag 1/256, per-axis cap 6 cells per tick. Terrain, solids,
  non-resident chunks and bodies cause rebounds with restitution and Coulomb
  friction.
- **Landing:** after a slow contact, too many rebounds or at maximum age, in the
  free cell itself or the BW-001 ring order (radius 2). A solid that **enters a
  liquid** climbs that liquid column (at most 64 rows) and lands on its free
  surface; the material's ordinary native density exchange then sinks it. A
  solid **buried** by moving powder climbs through powders and liquids to the
  first free cell. If nothing is free, landing is deferred (counted) and retried;
  nothing is deleted.
- **Bodies:** a body contact adds the solid's momentum change (density-scaled
  mass: a Water-density cell equals one 255-unit Water parcel) to the same per-body
  counters as ballistic Water, so the existing coupling delivers it to Rapier
  through the workbench droplet gain (**Hit force ×**).
- **Presentation:** flying solids are drawn as their material in
  `copy_material_cells`, `copy_render_cells` and render-snapshot patches, only
  over Empty cells. Authority is untouched.

## Accounting, identity and lifecycle

Cell ledger: `in_flight == launched + injected − landed`, validated on save,
restore and the authority scan. Grid writes use one exact transfer between Empty
and the admitted material, updating the native population counts, pressure
topology, IN storage, activity and discovery like any serialized external edit.

| Surface | Solids off | Solids on |
|---|---|---|
| Physical-state hash | unchanged | ballistic version 4 plus a solids section (identity, every solid, counters outside quiescent content) |
| Persistence | unchanged CYPS4/5 | CYPS extension bit 16 (requires bit 2): configuration, identity, every solid and the ledger |
| Retained workbench rebuild | — | flying solids carried into a solids owner (counted as injected) or reported as `discarded_in_flight_solids` |

`clear()` resets solids and their ledger. A failed tick quarantines the World as
before. Thermal state is not carried in flight (the landing cell keeps its own).

## Workbench options and equipment

Construction options (shared workbench only): `workbench_ballistic_solids`
(bool, needs `workbench_ballistic`), `workbench_ballistic_capacity` and
`workbench_solids_capacity` (1–65536; the spray panel's **Drop cap** / **Solid cap**,
default 4096). Runtime: **Hit force ×** multiplies the droplet gain for both Water
and solids. Adapter calls: `inject_solid_parcel`, `launch_solid_parcel`,
`get_ballistic_solids`, `inspect_ballistic_solids` and the read-only
`get_material_population`.

Equipment (see [workbench liquid equipment](../systems/workbench-liquid-equipment.md)):
a **launcher** fires one solid material from a stock, a **collector** gathers
powders/solids into stock and the **conveyor** links them. A sand **hopper** is a
valve in the floor of a powder bin. The built-in **solids-lab** start shows all of
them against a stack of Rapier barrels.

## Launch in place and kinetic masks

A launch may spawn in its **own source cell** (BW-001 Water and BS-001 solids):
that cell is vacated by the same launch, so the interior of a pool or pile can
fly even with no free neighbour. A spawn in any other occupied cell still refuses.
`launch_water_parcel(cell, position, velocity)` exposes the existing BW-001 grid
launch to the workbench.

The [kinetic mask core](../../godot/scripts/workbench_kinetic_mask.gd) builds
tools from this: a bounded **shape** (disc, ring, cone, column, box), a
**pattern** (all, checker, random fraction, edge) and a **field** (radial,
inward, vortex, direction, jitter, plus lift and deterministic noise). It plans
on the worker, orders cells so those further along their own motion leave first,
and hands each selected Water or admitted solid cell to the native owners (at
most 640 per application, 6 000 reads). It never sets grid velocities or creates
material. Presets: Blast, Implode, Vortex, Geyser, Shovel, Shockwave, Gust,
Shaker, Pepper, Lattice lift and Skin peel.

A BW-001 Water parcel engulfed beneath a lighter liquid (Oil over Water) now
rises through that liquid layer to the free surface instead of deferring
indefinitely; density exchange then settles it.

## Limits

- Opt-in and experimental; no default World uses it.
- Bounded serial pass; cost grows with live solids (measured in the dated record).
- Flying solids do not collide with each other or with flying Water drops.
- Structural solids such as Stone land where they stop and do not slump, so
  flung Stone can stack into spires.
