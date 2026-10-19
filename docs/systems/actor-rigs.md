---
title: Provisional actor rigs and shared control interface
status: Current
document-kind: contract
scope: Six sets of 29 optional desktop sampled actor rigs, their shared player/policy actions, observations and bounded gameplay mechanics; excludes learned inference and generalized rigid-body or pressure physics
canonical-for: [actor-rig-sets, actor-policy-input, actor-rig-observations-v2]
last-reviewed: 2026-10-19
related-documents: [actor-control-prototypes.md, actor-usables.md, granular-interaction-policy.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../operations/local-build-and-validation.md, ../reference/status-and-roadmap.md]
---

# Provisional actor rigs and shared control interface

This page owns the **retained sampled ACT-002 reference**. The default desktop
physical counterparts for all 29 IDs and twelve new SetX examples are documented
in [Articulated Rapier actors](physical-actor-rigs.md). Physical v2 envelopes,
part/joint observations and mechanics do not reinterpret the sampled fields below.

## Which actor rigs are available?

**Current, experimental (ACT-002 / #168):** the desktop sandbox and exploratory showcase maps have six
sets containing 29 movement rigs. Every rig can be assigned to keyboard input,
an external policy producer or the built-in scripted demonstration. Producer
identity changes who may submit an action; it does not grant different movement,
collision or tool authority.

SetA preserves the original Runner, Skimmer and Crawler motors. Its
[version-1 contract](actor-control-prototypes.md) remains the compatibility route.
The additional sets share a sampled motor with authored rotation, surface
attachment, ropes, resource limits and selected local tools. These are provisional
gameplay rules for comparison, not a selection of the final player representation.

| Set ID | Theme | Stable rig IDs, in catalog order |
|---|---|---|
| `setA` | Reference controls | `runner`, `skimmer`, `crawler` |
| `setB` | Ground and near-ground machines | `scout`, `scrabbler`, `ripper`, `groundeffect`, `digger` |
| `setF` | Unusual flight and descent | `copter`, `pouncer`, `dropbot`, `lineshank` |
| `setY` | Contact, rope and impulse traversal | `walljumper`, `clamberer`, `swinger`, `rocketjumper` |
| `setU` | Self-propelled salvage tools | `springjack`, `gyrocrate`, `bellows`, `winchbug`, `magpie`, `skatesail` |
| `setV` | Speculative interface personas | `astra`, `claude`, `luna`, `qwen`, `bonsai`, `jev`, `gemini` |

`groundeffect` has no underscore; its display name is **GroundEffect**. The first
three global rig indices remain 0 Runner, 1 Skimmer and 2 Crawler. A catalog entry
is copied metadata, not a live controller. Its `parameters` extension dictionary
is currently empty; movement tuning belongs to the motor, while effort is an
input action rather than a replacement PENV profile.

Source: [`actor_rig_catalog.gd`](../../godot/scripts/actor_rig_catalog.gd)
(`RIG_IDS`, `entry`, `controls_text`),
[`actor_rig_motor.gd`](../../godot/scripts/actor_rig_motor.gd)
(`simulate_rig_action`, `_advance_rig`) and
[`actor_prototype_session.gd`](../../godot/scripts/actor_prototype_session.gd).

USABLE-001 adds an independent [actor equipment layer](actor-usables.md) for the
sampled rig session. Equipment has its own epoch/sequence/lease stream and does
not reuse movement buttons or grant policies direct World-edit authority. The
[physical ACT-005 equipment](physical-actor-rigs.md#which-usable-examples-exist)
uses articulated body/mount authority and the physical issued-observation envelope.

## How does each rig move?

In the tables, **move** means the shared movement vector; **aim**, **effort**,
**trim** and **reel** name additional continuous input channels. Every listed
button is available to both human and policy producers. An unlisted channel does
not acquire a new capability merely because the shared packet contains it.

### SetA: unchanged reference controls

| Rig | Continuous channels | Primary | Secondary |
|---|---|---|---|
| Runner | Horizontal move | Buffered jump; release cuts rise | Press for horizontal dash |
| Skimmer | Two-axis move | Hold powered boost | Hold unpowered airbrake |
| Crawler | Horizontal move | Short hop | Hold brace |

Runner retains coyote time and an input buffer. Crawler automatically attempts
its existing supported clamber. SetA ignores the new aim, effort, trim, reel and
auxiliary channels and continues to instantiate `CyberActorPrototype`, so its
existing tuning and 16-value observations retain their meaning.

### SetB: ground and near-ground machines

| Rig | Continuous channels | Primary | Secondary / auxiliary | Distinguishing movement |
|---|---|---|---|---|
| Scout | Move, effort | Jump and second air jump | Hold glide / none | Fast response and automatic supported vaults |
| Scrabbler | Move, aim, effort, trim | Committed lunge away from support | Hold grip / hold self-right | Broad, slow three-legged robospider with uneven traction and body torque |
| Ripper | Move, effort, trim | Hold cutting tool; press for traction burst | Hold track brake / hold self-right | Tracked microtank with separate drive direction and tilt/torque |
| GroundEffect | Move, effort, trim | Lift burst | Hold settling brake / none | Soft, slower ground-distance cushion; vertical movement biases clearance |
| Digger | Move, aim, effort | Hold downward drill | Hold drill brake / none | Slow lateral motion, fast downward drive and a narrow downward steering cone |

Scout vaulting still needs support and a clear intervening volume. Scrabbler's
three-foot rhythm modifies traction and presentation; it does not add three
articulated rigid bodies. Ripper's tilt affects track traction. GroundEffect
reads a bounded distance below the hull and applies a spring/damping rule;
its cushion is not a pressure or Water-buoyancy solver. Digger's compact boring
head and finite tool footprint make downward passages possible without granting
arbitrary sideways tunnelling or permission to erase protected construction.

### SetF: unusual flight and descent

| Rig | Continuous channels | Primary | Secondary / auxiliary | Distinguishing movement |
|---|---|---|---|---|
| Copter | Move, effort, trim | Hold rotor boost | Hold stabilizer / toggle rotor power | Body-oriented thrust and deterministic actor-local wobble |
| Pouncer | Move, aim, effort, trim | Hold to coil; release to leap | Hold glide / tumble-dive | Slow crawl changes into a charged athletic leap and controlled or tumbling descent |
| Dropbot | Move, aim, effort, trim | Aimed push-off | Hold grip/airbrake / commit divebomb | Wall climb, acrobatic departure and a bounded impact action |
| Lineshank | Move, aim, effort, reel | Fire bungee harpoon | Hold aimed blade; press adds lift pulse / release line | Knife rig with elastic horizontal slingshots and speed-dependent blade lift/drag |

A normal Pouncer release may launch a charged leap. Cancellation or lease expiry
clears the charge before neutral input is advanced, so loss of input authority is
not interpreted as a deliberate release. Lineshank retains existing momentum and
adds a bounded horizontal kick from stored line tension when releasing its bungee;
the attachment is then consumed. Its line and blade use sampled collision.
Holding the blade steers its attitude toward aim and derives lift/drag from
existing airspeed; the held blade does not produce lift at rest. Its initial
press has a separate short lift pulse and bounded cutting action.
Copter wobble is local deterministic state, not inference or unbounded random work.

### SetY: contact, rope and impulse traversal

| Rig | Continuous channels | Primary | Secondary / auxiliary | Distinguishing movement |
|---|---|---|---|---|
| Walljumper | Move, aim, effort | Precision leap | Hold brief grab / release grab | Wall and ceiling contact, deliberately short stamina and effort-controlled reach |
| Clamberer | Move, aim, effort | Short push-off | Hold long adhesion / hold tuck | Patient surface crawl and a smaller hull for sheltered gaps |
| Swinger | Move, aim, reel | Cast rope | Release rope / none | Worms-style pendulum pumping, reel control and momentum-preserving release |
| Rocketjumper | Move, aim, effort, trim | Blast against a nearby surface | Hold brace / none | Aim chooses a nearby contact; distance and effort scale the opposite authored impulse |

Walljumper effort sets launch strength; it is not a guarantee that an exact
requested distance is reachable through collision or gravity. Clamberer has a
longer attachment resource window and may hold its smaller hull in a gap. Releasing
tuck restores the full body only when the new occupied volume is clear.
Rocketjumper requires terrain close to its current collision envelope; an empty-air
press spends no energy and creates no recoil or effect. A protected Wall can
support authored recoil while remaining intact and blocking edits beyond it.
Ropes are bounded straight segments to one terrain anchor, with no wrapping,
rope-to-rope collision or rope attached to a live Rapier object.

### SetU: self-propelled salvage tools

| Rig | Continuous channels | Primary | Secondary / auxiliary | Distinguishing movement |
|---|---|---|---|---|
| Springjack | Move, effort, trim | Hold rhythmic pogo | Hold brace/preload / none | Supported piston bounces with stored preload; bracing takes precedence |
| Gyrocrate | Move, effort, trim | Hold flywheel spin-up | Spend spin on a hop / hold self-right | Ground rolling derives from stored angular motion |
| Bellows | Move, aim, effort | Aimed pneumatic pulse | Hold inhale/brake / vent without thrust | Alternate charging breaths and discrete momentum pulses |
| Winchbug | Move, aim, effort, reel | Fire hook | Hold clutch/damping / detach | Slow hauling motion and a controlled winch |
| Magpie | Move, aim, effort | Capacitor lunge | Hold contact clamp / release clamp | Charge on a perch and lunge toward the first bounded visible surface |
| Skatesail | Move, effort, trim | Pop hop | Hold deployed sail / fold and brake | Build horizontal speed and trim it into lift |

The common theme is machinery repurposed to move itself: piston, flywheel, air
bag, winch, clamp and sail. Bellows pressure is an actor resource, not simulated
gas. Magpie charges quickly while clamped and slowly while free; it does not
teleport to its target. Skatesail needs existing horizontal
speed; deploying the sail while stationary does not create powered hover.

### SetV: fictional interface personas

These are **speculative designs created for this experiment**. The names Astra,
Claude, Luna, Qwen, Bonsai, Jev and Gemini do not assert any real model's
preferences, personality, performance or capabilities. No named model is called
or connected by selecting a rig.

| Rig / design persona | Continuous channels | Primary | Secondary / auxiliary | Interface idea |
|---|---|---|---|---|
| Astra / Vector | Move, aim, effort | Aimed vector burst | Hold counterthrust / toggle assist-coast | Separate desired movement, burst direction and momentum cancellation |
| Claude / Contour | Move, aim, effort | Controlled vault | Hold adhesion / hold soft landing | Measured surface movement and forgiving transitions |
| Luna / Pulse | Move, aim, effort | Short pulse | Hold strong damping / none | A small action vocabulary with quick impulses and immediate correction |
| Qwen / Switchboard | Move, aim, effort, trim | Ground jump or flight boost | Hold brake / switch ground-flight mode | Explicit mode selection with the active mode observed |
| Bonsai / Root | Move, aim, effort | Stored spring leap | Hold long adhesion / hold tuck | Compact contact motion, accumulated spring charge and gap shelter |
| Jev / Jolt | Move, aim, effort, trim | Burst | Hold rebound response / hold self-right | Committed motion and energy-losing detected-contact ricochets |
| Gemini / Duet | Move, aim, effort, trim | Hold left thruster | Hold right thruster / paired burst | Two actuators with opposite torque and independent differential trim |

## How are rigs selected and controlled on desktop?

**F5** opens the actor selector. Choose a set and rig, then keyboard, scripted
demonstration or external policy input. The comparison option adds the other rigs
in the selected set as scripted NPCs, for at most seven actors in that UI selection.
The session itself retains its separate eight-slot capacity. Applying a selection
restores the current exploratory map (or ordinary sandbox) and waits for the
owner acknowledgement before human input is admitted. The picker labels these
rigs Sampled and separately offers Rapier barrel/Ripper keyboard trials. R retains
the choice; authored-map geometry is retained but live edits reset. Controlled
apparatus and Benchmark mode remain protected. Choosing the sampled baseline
leaves the rig session. See the [physical actor programme](../operations/physical-actor-programme.md)
for current scope and the approved full-roster Rapier migration.

| Desktop input | Shared channel |
|---|---|
| WASD | Movement; a ground rig usually uses only A/D, while contact/flight rigs may use both axes |
| Mouse position | Independent aim direction in world coordinates |
| Space / Shift / C | Primary / secondary / auxiliary |
| Q / E | Negative / positive trim |
| Z / X | Negative / positive reel: shorten / extend the line |
| Left / right bracket, or selector Keyboard power slider | Decrease / increase human effort |

The selected rig's control text names the channels it uses. The extended keys
belong to human-controlled new rigs while gameplay has focus. Focus loss or entry
into blocking UI cancels human input; it rearms only after the relevant gameplay
keys are released. Paused, failed or replaced worlds cannot acquire a stale held
action merely by returning to gameplay. SetA retains its original keyboard mapping.
The slider is enabled for keyboard control only when the rig uses effort. Demo
and policy HUD power comes from the action actually consumed, not the idle human
slider; those producers supply their own effort through the shared seam.

The separate [Thunderbowl control laboratory](thunderbowl-control-reference.md)
uses these same rigs for bounded battle/training experiments. Its configuration
may select a direct `metal` actuation lane for Ripper, Copter or Gemini; ordinary
actor definitions default to `wire`. Direct force/torque commands and their
32-value readback are an additive contract, separate from the v2 intent channels.
The Thunderbowl reference owns controller topologies, local/oracle perception,
messages, model-plan adapters and arena-only tag combat.

Tower, Water and registered MicroScenario controls preserve their fixture identity.
PENV changes remain refused while rigs own the motor settings. F7 remains the
sampled-baseline recovery control, and F6 leaves rigs through the existing PCHAR
reset path. The selected experimental rigs do not rewrite controlled scenario
definitions. Sources: [`main.gd`](../../godot/scripts/main.gd),
[`actor_prototype_panel.gd`](../../godot/scripts/actor_prototype_panel.gd) and
[`simulation_worker.gd`](../../godot/scripts/simulation_worker.gd).

## What action does a player or neural policy submit?

The v2 worker seam accepts scalar and vector values only:

```gdscript
submit_actor_rig_action(actor_id: int, epoch: int, sequence: int,
    observed_tick: int, movement: Vector2, aim: Vector2, effort: float,
    trim: float, reel: float, primary: bool, secondary: bool, auxiliary: bool,
    lease_ticks: int = 12, producer: StringName = &"policy") -> bool
```

The owner-local session method is `submit_rig_action` with the same fields.
Movement components clamp to -1..1. Aim components clamp before normalization;
nonzero aim is normalized and zero remains zero in the mailbox/readback. A motor
may select its own facing-based default for zero aim. Effort clamps to 0..1;
trim and reel clamp to -1..1. Nonfinite values are refused rather than passed to
the live actor. Finite clamping occurs before vector normalization to avoid
overflow from large finite policy outputs.

The original `submit_actor_action` / `submit_action` remains available. It passes
movement as the minimal adapter's aim, effort 0.7, zero trim/reel and no auxiliary;
SetA still consumes only its original movement and two buttons. Independent aim
and the extra actuators require the v2 seam for new rigs.

### Identity, freshness and consumed edges

Admission checks actor slot, assigned producer, current epoch, strictly increasing
sequence and an observation tick that is not in the future. The lease deadline
is derived from that observation tick, so an old inference result does not get
a fresh full lease on arrival. Bounds and 60 Hz simulation-time equivalents live
in the [configuration reference](../reference/configuration-reference.md#actor-rig-values).

Each slot retains one latest held command plus one latched rise per button.
Several submissions before an owner tick replace continuous values with the
latest admitted values; a short press/release survives as a pressed flag. Multiple
rises of the same button before consumption coalesce to one. This is not an action
FIFO, and it cannot reproduce every intermediate command of a high-rate producer.

`sequences` reports the latest **admitted** command, possibly newer than the last
motor step. `applied_sequences` reports the live command actually consumed by
that step, or -1 for expired/neutral input. The ten-float `applied_actions` rows
contain movement x/y, aim x/y, effort, trim, reel, primary-held, secondary-held,
auxiliary-held, in that order. Held values alone cannot explain an action caused
by a press/release between ticks. Per-actor `applied_flags` therefore retains:

| Flag | Bit value |
|---|---:|
| Primary held | 1 |
| Secondary held | 2 |
| Primary pressed | 4 |
| Secondary pressed | 8 |
| Cancel previous action state | 16 |
| Auxiliary held | 32 |
| Auxiliary pressed | 64 |

Cancellation clears held input, pending rises, armed charge, attachment and
pending tool effects. Pause/reset/scenario transitions invalidate the old epoch.
Pause preserves cooldowns and physical state rather than granting a fresh actor.
Expiry emits cancellation when a live command becomes stale; subsequent neutral
input is not an automatic emergency stop of momentum or gravity. Policy scheduling
must consume copied observations and return actions without blocking the owner.

## What does the version-2 observation contain?

The session retains `version: 1`, `observation_stride: 16` and `states` for old
consumers. Its additive `rig_version: 2`, `rig_observation_stride: 40` and
`rig_states` describe the extended layout below. `rig_sets`, `models`, `producers`,
epoch and actor tick identify each row; its zero-based row number is the actor ID.

| Float indices | Meaning and units |
|---|---|
| 0–15 | Common position, velocity, support, energy, readiness, activity, facing, model index and query/limit fields in the [legacy order](actor-control-prototypes.md#how-can-a-neural-policy-control-the-same-actor); new rigs use their global catalog index at 13 |
| 16–17 | Rotation in radians; angular velocity in radians/second |
| 18–19 | Contact-normal x/y |
| 20 | Attachment mode: 0 none, 1 adhesion, 2 rope, 3 bungee; 4 reserved for dual anchor |
| 21–23 | Anchor x/y in cells; rope length in cells |
| 24–25 | Tension fraction; stored charge fraction |
| 26–28 | Auxiliary-active flag; rig-specific locomotion mode; remaining air jumps |
| 29–31 | Ray query count; edited-cell count; effect kind 0 none, 1 dig, 2 blast |
| 32–34 | Effect-origin x/y in cells; authored effect-strength fraction |
| 35–37 | Current unrotated body width/height in cells; effect radius in cells |
| 38–39 | Effect material-read count; gait-phase fraction |

Locomotion mode 27 uses 0 ground, 1 air, 2 adhesion, 3 rope, 4 bungee, 5 drill,
6 charge, 7 glide, 8 rotary drive, 9 ground hover, 10 thrust and 13 dive.
Qwen deliberately reports its selected control mode instead: 0 ground mode or
1 flight mode, independent of immediate contact. Consumers must interpret mode
together with the rig ID. Attachment mode and locomotion mode are separate enums.

Boolean fields use 0/1. Position, speed, angles, distances, counts and times retain
their units; this vector is not wholly normalized. SetA's extended rows copy the
original 16 values, retain its body dimensions, and zero unsupported new fields.
The compact vector is actor state, not a terrain grid, route plan, nearby-actor
sensor or complete future-affecting state for exact replay. Any training adapter
must version its feature scaling and supply separately budgeted perception.

For a new rig, position fields 0–1 are the unrotated rectangle origin; its center
is that position plus half the current dimensions at 35–36. Rotation does not
redefine the origin as the conservative envelope's upper-left corner. Readiness
flags describe resource, cooldown and local support state. Target geometry is
checked on action, so a ready flag does not guarantee a valid rope anchor or a
nearby Rocketjumper surface.

Catalog metadata uses `Vector2`/`Color` internally. Session `rig_capabilities`
publishes numeric arrays for body size and color, and copied motor capabilities,
so gameplay-recording JSON retains structured values rather than stringified
engine types. Current actor samples and material-generation actor context remain
separately identified in the [recording contract](../operations/gameplay-recording.md).

## Who owns collision, tools and bounded work?

The desktop simulation owner configures and advances all motors, performs their
World queries and applies admitted local effects. Input, UI, scene-tree drawing
and Rapier remain main-thread responsibilities. A producer does not receive a
live actor, World, collision callback or arbitrary effect footprint. Catalog data
and observations cross the boundary as copied values.

New rigs use conservative axis-aligned occupancy envelopes around their rotated
rectangles. Translation and angular changes are checked in bounded increments;
visible legs, tracks, blades, sails and rotors do not become separate collision
bodies. A narrower tucked shape may change only through a clear-volume resize.
Runtime enclosure stops the actor rather than relocating it through terrain;
explicit bounded invalid-spawn recovery remains a separate setup operation.

Adhesion requires a sampled current surface and available resource. A rope has a
bounded cast, length and obstruction check; losing valid anchor geometry releases
the attachment. Neither attachment creates a new native material or makes an
unstable cellular structure load-bearing. Rope release, leaps, blasts and ricochets
still pass through the motor's collision and final speed bounds.

Ripper/Digger excavation and selected blast/blade effects use
[`actor_rig_effects.gd`](../../godot/scripts/actor_rig_effects.gd). Its explicit
material whitelist and bounded cached footprint protect Wall, composed body masks,
out-of-bounds cells and other noneditable materials. The motor checks the path
from its center to the requested tool origin, so a muzzle offset cannot start an
effect beyond a protected thin wall. Protected cells also occlude the footprint.
A changed cell is submitted through the existing
owner-local `emit_disc` adapter with radius zero, preserving native cell authority
and wake/revision semantics. Blast presentation may place Fire at the admitted
center and apply a separate authored actor recoil. This is not native explosion
pressure, a conservation-preserving excavation model or a generic Rapier impulse.

The [configuration reference](../reference/configuration-reference.md#actor-rig-values)
owns exact query, sweep, angular, ray and effect budgets. Exhausting a collision
quota refuses further movement; no unbounded catch-up, terrain search, deferred
tool queue or inference task is created. Those controller caps do not measure the
subsequent native material reactions or the complete desktop frame.

## What remains provisional and how is it validated?

Learned inference, rewards/training, a network service, production many-NPC
throughput, target-PC feel acceptance and a Web/browser rig UI remain separate
work. No selector label, copied action interface or scripted demonstration proves
that those features exist. GDScript containers and copied publications remain
bounded allocations; the implementation does not claim zero heap work per tick.

The [focused build/test route](../operations/local-build-and-validation.md#actor-rig-checks)
covers catalog/control mechanics, stale action handling, SetA parity and desktop
integration. Use the [validation ledger](../reference/validation-evidence.md) for
dated commands, source/runtime identities and actual outcomes. The
[ACT-002 audit](../audits/2026-10-18-act002-actor-rigs.md) records the new rigs'
scoped Linux passes, preserved failures and remaining acceptance boundaries. The original
[ACT-001 audit](../audits/2026-10-18-act001-actor-control-prototypes.md) remains
evidence for its recorded SetA checkpoint, not automatic acceptance of all 29 rigs.
