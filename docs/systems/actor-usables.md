---
title: Actor usables — 32-item catalogue and physical equipment
status: Current
document-kind: contract
scope: Experimental U01-U32 catalogue, physical equipment and deployed processors; retained sampled equipment compatibility, copied control and native material authority
canonical-for: [actor-usables-catalogue, actor-usable-behaviour, actor-usable-control]
last-reviewed: 2026-10-19
related-documents: [physical-actor-rigs.md, actor-rigs.md, actor-control-prototypes.md, materials-and-rule-kernels.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../operations/local-build-and-validation.md, ../reference/status-and-roadmap.md, ../audits/2026-10-19-act005-physical-usables.md]
---

# Actor usables — 32-item catalogue and physical equipment

## Current scope

**Current experimental source, USABLE-002 / ACT-005 / #182:** the **32 usables**
from USABLE-001 retain their identities and authored semantics: 12 material
deposition/destruction tools, 10 ballistic payloads and 10 processors. Physical
equipment uses the articulated actor session's command authority. Its aim and
power can differ from locomotion aim and effort, so firing a nozzle does not
silently retarget a thruster, rope or charged leap. The
[dated ACT-005 checkpoint](../audits/2026-10-19-act005-physical-usables.md) owns
implementation progress, actual validation and merge status.

The executable catalogue is
[`usable_catalog.gd`](../../godot/scripts/usable_catalog.gd), bounded gameplay is
owned by [`usable_runtime.gd`](../../godot/scripts/usable_runtime.gd). The physical
owner in [`physical_usable_equipment.gd`](../../godot/scripts/physical_usable_equipment.gd)
manages a real held part, joint aiming, lifecycle and recoil. The worker-owned
[`physical_usable_runtime.gd`](../../godot/scripts/physical_usable_runtime.gd)
reuses the authored effects while resolving source clearance and hits against
actual part occupancy. The simulation worker alone queries or mutates its
cellular World; policies receive copied observations.

The retained sampled actor route still uses
[`usable_session.gd`](../../godot/scripts/usable_session.gd) and its separate
epoch/sequence/lease stream. Its old axis-aligned actor hull and logical device
placement are compatibility behavior; physical equipment does not borrow those
spatial or ownership assumptions. Neither route exposes a Rapier RID or live body
reference to a producer.

## Desktop controls

Open **F5**, select the actor rig as usual, then choose equipment. **Equip only**
changes the current human actor through its admitted equipment action. A physical
item can be changed only while its chassis is held; a dropped or deployed object
must be recovered first. The same chassis and existing shared equipment charge
remain in use when its selected usable changes.

- pointer position supplies equipment aim;
- left mouse is primary activation;
- right mouse is a tool precision pulse or supported early payload activation;
- **N** drops the physical held item and **U** requests nearby pickup; processor
  primary starts physical placement, while sampled processors retain right-click
  logical retrieval;
- equipment power is independent from movement effort;
- tools repeat while held; projectiles and deployments consume a press edge;
- choosing **None** returns the pointer to painting only after the owner publishes
  the unequipped selection and all pointer buttons have been released.

While equipment is selected, ordinary world painting is suppressed. Focus loss,
blocking UI, pause, reset or stale input cancels held equipment input. Already
launched projectiles and deployed devices are owner state, not held input: they
continue after release/cancellation, freeze while simulation is paused and clear
on a fresh actor/World reset. Cancelled physical input retires pending requests
and late receipts without teleporting a released body or erasing actor momentum.
Changing equipment while a trigger is held requires release before rearming.

## U01–U12: material deposition and destruction tools

| Ref / ID | Usable | Primary behaviour |
|---|---|---|
| U01 `sand_scatter` | Sand Scatter | Broad deterministic Sand fan for loose fill and slopes. |
| U02 `water_lance` | Water Lance | Narrow aimed Water line. |
| U03 `cement_extruder` | Cement Extruder | Compact Cement bead, up to five authored slots per pulse. |
| U04 `brick_stamper` | Brick Stamper | Five-position Industrial Brick stamp. |
| U05 `seed_duster` | Seed Duster | Sparse wide Seed fan; native growth remains authoritative. |
| U06 `foam_sprayer` | Foam Sprayer | Broad Foam plume; current Foam is a rising transient gas, not structural sealant. |
| U07 `line_cutter` | Line Cutter | Thin direct excavation path through editable material. |
| U08 `rotary_borer` | Rotary Borer | Small near-contact circular excavation footprint. |
| U09 `powder_vacuum` | Powder Vacuum | Selective sink for declared loose powders. |
| U10 `liquid_drain` | Liquid Drain | Selective local sink for declared liquids. |
| U11 `glass_scorer` | Glass Scorer | Thin cut restricted to supported glass IDs. |
| U12 `acid_wash` | Acid Wash | Deposits Acid into reachable empty slots; later corrosion is native material behaviour. |

Right click gives a single tool pulse at 35% selected power. It does not reduce
the fixed stamp/bead pattern itself. Direct edits refuse Wall/composed body
occupancy; the sampled route additionally protects its sampled actor hulls.
Physical source and target checks use individual body IDs, including detached
parts, rather than an aggregate actor rectangle. Emitted materials subsequently follow native
interaction rules; usable code does not duplicate Acid, Fire, Water or growth
chemistry.

The vacuum and drain are explicit sinks. Removed slots are not hidden inventory.

## U13–U22: ballistic payloads

Projectiles are sparse bounded records with swept cell-space contact, gravity,
lifetime and explicit state transitions. They are separate from the native
pixel-material `Rocket`.

| Ref / ID | Usable | Activation |
|---|---|---|
| U13 `impact_slug` | Impact Slug | First editable contact chips a small footprint. |
| U14 `borer_round` | Borer Round | Up to three editable penetrations, losing speed after each. |
| U15 `ricochet_pellet` | Ricochet Pellet | Up to two damped terrain bounces. |
| U16 `sticky_delay_charge` | Sticky Delay Charge | First contact sticks; 0.55 s simulation-time fuse excavates locally. Right click activates the oldest eligible owned charge early. |
| U17 `timer_airburst` | Timer Airburst | 0.45 s flight fuse splits into five bounded child chip shots. Right click bursts the oldest live owned canister early. |
| U18 `water_capsule` | Water Capsule | Contact releases Water into nearby available cells. |
| U19 `oil_igniter` | Oil Igniter | Contact deposits Oil; 0.35 s later it attempts one Fire pulse. Right click activates the oldest primed owned payload early. |
| U20 `seed_pod` | Seed Pod | Contact disperses Seed locally. |
| U21 `cement_blob` | Cement Blob | Heavy short-range Cement payload. |
| U22 `water_contact_charge` | Water Contact Charge | Contact arms the carrier; nearby Water or Brine triggers one Fire pulse. |

A swept non-owner actor contact publishes a bounded hit receipt containing tick,
owner, target, projectile and usable identity. Physical hits also identify the
target body part. Accepted physical use applies bounded recoil through the
main-thread equipment owner. The catalogue does **not** add health, damage numbers
or a general damage/impact impulse system.

Fuse time is simulation time and still advances if the movement read budget is
exhausted; position remains at the last verified point. Collision sweep examines
the valid in-bounds segment before discarding an out-of-world endpoint.

Early activation of an eligible committed U16/U17/U19 payload is independent of
new-launch charge, cooldown, power and muzzle clearance. It still requires the
current held equipment identity and an active command lease, and adds no launch
recoil. A zero-power primary use is refused; processor placement rejects it
before releasing the physical chassis.

## U23–U32: fixed functional objects

**Physical placement:** primary releases the existing equipment body. After
supported low-speed settling, the owner fixes that same body at its current
pose and submits a deployment request. Only worker admission enables processing.
The copied object pose belongs to its actor, instance, equipment epoch and stable
body ID. Dropping a chassis alone does not automatically start a processor.

Physical ports follow the body's rotation and lie outside its collider. Their
local x distance is `ceil(half_extents.x + 2)` on the intake/output sides, with
local y offsets `-1` and `+1`; transformed locations round to cell coordinates.
Body occupancy and material conditions are checked under cellular ownership.
The retained sampled route instead requires an empty 5×5 workspace and uses
logical ports `(-2,-1)`, `(-2,+1)`, `(+2,-1)`, `(+2,+1)`.

| Ref / ID | Object | Recipe / response |
|---|---|---|
| U23 `stone_grinder` | Stone Grinder | Stone → Sand |
| U24 `glass_reclaimer` | Glass Reclaimer | base Glass → Sand |
| U25 `brine_splitter` | Brine Splitter | two Brine slots → Water + Salt |
| U26 `glass_kiln` | Glass Kiln | Sand → Molten Glass while Fire or Lava is nearby |
| U27 `steam_condenser` | Steam Condenser | Steam → Water while Ice is nearby |
| U28 `cement_finisher` | Cement Finisher | Cement → Concrete while Water is nearby |
| U29 `sludge_scrubber` | Sludge Scrubber | Toxic Sludge + Water → Water + Dust |
| U30 `metal_reclaimer` | Metal Reclaimer | Rust + Coal → Metal + Smoke |
| U31 `seed_incubator` | Seed Incubator | Seed + Water → Plant |
| U32 `firewarden` | Firewarden | nearby Fire → emit Water; twelve successful pulses |

Ordinary processors have 16 successful batches, a 45-second lifetime and a
0.35-second cadence; deployment costs 18 actor equipment charge. Firewarden has
12 successful pulses. Catalysts are sensed within a 7×7 square and are not
consumed. A complete batch checks every required input, catalyst, output and
owner-side work budget before consuming the recipe. Blocked output leaves inputs
untouched.

Physical **U** pickup requires the owning mount to be close enough with a clear
attachment path. It reuses the existing body and retires that deployment's active
processing authority. A bounded per-actor/per-processor history retains stock,
age, cycles and cooldown across pickup, redeployment and selection changes;
recovering a used device cannot refill it. Exhausted or expired devices remain
inert and visible until physical retirement. Remote right-click retrieval applies only to the sampled
compatibility route. Neither path refunds spent charge. Physical jam/exhaustion
readback and the released body's pose remain observable.

## Action and readback contract

### Physical actions and copied feedback

The physical version-2 `physical_wire_action` envelope carries an optional
`equipment` dictionary. The enclosing run, actor epoch, producer, issued
observation and lease remain authoritative; there is no second physical policy
mailbox with weaker freshness checks.

```gdscript
var command = CyberPhysicalActorSession.make_command(view, sequence, {
    "move": Vector2.RIGHT,
    "equipment": {
        "usable_index": view.equipment.usable_index,
        "instance_id": view.equipment.instance_id,
        "equipment_epoch": view.equipment.equipment_epoch,
        "aim": Vector2(1, -0.2), "power": 0.7,
        "trigger": true, "alternate": false, "drop": false, "attach": false
    }
}, 12)
```

Only the physical owner supplies source positions, mount/body IDs, material
effect requests and lifecycle changes. The helper fills missing equipment
identity from the copied view; raw external packets must carry it. The worker
validates the copied physical frame and request together. One pending request
per actor prevents repeated receipt consumption from applying recoil twice.
Selection/lifecycle transitions advance equipment epochs; cancellation advances
the actor control generation. Old observations cannot restore a retired state.

Copied `observation.equipment` includes identity/usable, owning part and held-body
pose, actual and requested aim, joint limits, clearance, release/pickup readiness,
charge/cooldown, pending/result/refusal state, recoil and bounded processor or
projectile readback. Exact fields and handoff timing belong to
[physical equipment interfaces](../reference/interfaces-and-message-contracts.md#physical-equipment-actions-and-results).

### Retained sampled actions

The sampled worker-facing admission seam remains:

```gdscript
submit_actor_usable_action(
    actor_id: int, epoch: int, sequence: int, observed_tick: int,
    usable_index: int, aim: Vector2, power: float,
    trigger: bool, alternate: bool,
    lease_ticks: int = 12, producer: StringName = &"policy"
) -> bool
```

`usable_index=-1` means no equipment. Aim is finite and normalized; power clamps
to 0–1. A producer must match the actor slot producer. Epoch, strictly increasing
sequence, observed tick and lease checks are independent from movement-action
sequence numbers. Press/release between two owner ticks is latched as one bounded
edge. Several rises before consumption coalesce rather than forming an action FIFO.

Published `actor_usables` contains copied values only:

- epoch/tick/suspension and producer identity;
- admitted sequences and lease remaining;
- equipped indices;
- per-actor charge, cooldown and last result;
- projectile, object, visual-effect and hit-receipt records;
- per-tick read/write/source/sink/refusal counters;
- capacities and the explicit accounting unit.

Earlier publications do not alias mutable runtime dictionaries.

## Bounded work and capacities

| Limit | Current value |
|---|---:|
| Actor equipment slots | 8 |
| Committed projectiles | 64 |
| Deployed devices | 16 globally |
| Deployed devices per actor | 4 |
| Short visual effects | 64 |
| Actor-hit receipts per tick | 64 |
| Material reads per usable owner step | 2,048 |
| Material writes per usable owner step | 128 |
| Projectile trace samples | 96 |
| Shared actor equipment charge | 100 |
| Charge regeneration | 6 per simulation second |
| Maximum accepted usable delta | 1/15 second |

Capacity exhaustion refuses/defer work; it does not silently replace another
projectile/device or run an unbounded catch-up queue.

## Ownership, accounting and exclusions

Native C++ remains authoritative for material cells. Usable code executes only on
the serialized simulation owner and calls the same composed material query and
radius-zero material emission boundary used by other bounded owner tools. Native
workers receive no Godot objects, and policy producers receive no World,
projectile/device object or edit-footprint authority.

Recipe accounting is **authored cell slots**. It is not conservation of Water
mass, heat, momentum or chemical stoichiometry. Native ID emission initializes
the native compact state for that material; later phase/reaction behaviour remains
owned by the material engine.

CYSD1 saves do not resume committed equipment state. Learned inference, general
inventory/economy, actor health/damage, programmable material-graph items,
exact thermodynamics/chemistry and target-PC feel acceptance remain outside this
increment. The physical chassis is a bounded equipment demonstration, not a
general inventory or arbitrary object-transfer system.

## Validation

Focused source tests are:

```bash
godot --headless --path godot -s res://tests/test_usables.gd
godot --headless --path godot -s res://tests/test_usable_session.gd
godot --headless --path godot -s res://tests/test_actor_usables_integration.gd
```

The [build guide](../operations/local-build-and-validation.md#physical-usable-validation)
adds physical equipment, lifecycle, native effects/admission and usable-course
fixtures. The current PR must also pass the existing actor-rig regressions and repository
documentation/provenance gates before merge. The earlier pre-publication local
USABLE-001 run was source-matched to the ACT-002-era tree and is retained only as
historical development evidence; it is not exact-head acceptance for the current
reconstruction.
