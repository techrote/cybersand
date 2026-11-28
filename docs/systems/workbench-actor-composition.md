---
title: Shared Workbench actor composition
status: Current
document-kind: contract
scope: WB-ACTOR-COMPOSE-002R continuous-play manipulation, configurable physical capacity, independent producers and authored composition
canonical-for: [workbench-actor-composition, workbench-actor-control]
last-reviewed: 2026-11-22
related-documents: [physical-actor-rigs.md, actor-rigs.md, physical-free-flight.md, ../architecture/shared-workbench-authoring-data.md, ../architecture/data-ownership-and-lifetimes.md, ../operations/workbench-actor-composition.md]
---

# Shared Workbench actor composition

## Implementation and scope

**WB-ACTOR-COMPOSE-002R Draft/HOLD candidate for [#737](https://github.com/techrote/cybersand/issues/737).**
The accepted [#683](https://github.com/techrote/cybersand/pull/683) supplies the
59-model catalogue, independent controllers, existing live Brush/Eraser and
prepared composition owner. The owner's 22 November follow-up authorizes paused
whole-assembly placement, live physical grabbing and expanded configurable
capacity. This candidate extends those retained owners. It does not promote
ordinary defaults, certify owner-machine performance or replace the scientific
apparatus.

The [owner procedure](../operations/workbench-actor-composition.md) explains the
unified Configuration window and three sandbox examples. Source ownership is divided as
follows:

| Source | Responsibility |
|---|---|
| [`workbench_actor_catalog.gd`](../../godot/scripts/workbench_actor_catalog.gd) | Copied capability and prepared-topology catalogue; model, controller, equipment and aggregate-capacity admission |
| [`workbench_setup.gd`](../../godot/scripts/workbench_setup.gd) | Authored model identity, spawn, options, optional control extension and named example |
| [`shared_workbench.gd`](../../godot/scripts/shared_workbench.gd), [`workbench_actor_panel.gd`](../../godot/scripts/workbench_actor_panel.gd) | Separate inspected actor and human pilot, explicit handoff, lazy panel, authoring transactions and policy UI |
| [`physical_actor_session.gd`](../../godot/scripts/physical_actor_session.gd) | Existing actor ownership, per-actor sequence/generation, issued observations, leases, takeover and bounded scheduling |
| [`workbench_actor_control.gd`](../../godot/scripts/workbench_actor_control.gd) | Value-only deterministic decision adapter; no World, node, RID, paint pointer or physics ownership |
| [`workbench_reactive_policy.gd`](../../godot/scripts/workbench_reactive_policy.gd) | Narrow reuse of Thunderbowl's pure local steering helper for compatible physical policy-fixture actors |
| [`workbench_physics_bridge.gd`](../../godot/scripts/workbench_physics_bridge.gd) | Actor-to-part-to-native-mask mapping and copied coupling samples in the existing Rapier space |
| [`workbench_actor_manipulator.gd`](../../godot/scripts/workbench_actor_manipulator.gd) | Session-bound per-part picking, bounded point forces, copied whole-assembly transforms and safe release |
| [`workbench_actor_interaction.gd`](../../godot/scripts/workbench_actor_interaction.gd) | Exclusive canvas mode, global gesture release, preview, snapping and single prepared placement commit |
| [`workbench_sandbox_capacity.gd`](../../godot/scripts/workbench_sandbox_capacity.gd) | Versioned logical/body/proxy admission and finite engineering bounds |
| [`workbench_actor_sandbox.gd`](../../godot/scripts/workbench_actor_sandbox.gd) | Living Mixed Workshop, configurable Barrel Crowd and Mechanical Chaos authored examples |
| [`main.gd`](../../godot/scripts/main.gd), [`simulation_worker.gd`](../../godot/scripts/simulation_worker.gd) | Existing main-thread physics/native-worker boundary, atomic body/equipment samples, prepared adoption and lifecycle |

The catalogue has 59 model identities: eight existing authored flyers, the
passive barrel, 46 physical catalogue models including five SetP player rigs,
and four 4LY assisted-flight profiles. Definitions are returned as new copied
values. Equipment preparation occurs once; its permanent chassis participates
in bounds and capacity checks even when the starting item is None.

The [dated local capacity record](../audits/2026-11-22-workbench-actor-sandbox/capacity/README.md)
binds its exact component source, native binary, 13 real population cases,
original failures and platform limitations. Final integrated, graphical and
packaged Windows runs carry separate exact-source receipts; a component matrix
is not relabeled as execution of a later UI or packaging revision.

## Capabilities and composition limits

| Family | Examples | Controller admission | Equipment and physical limits |
|---|---|---|---|
| Existing Workbench flyers | The retained eight fleet definitions, including Midge and Kestrel | Human, scripted local feedback, policy, passive | Existing compound hulls, flyer controls and emitters; no ACT-005 mount |
| Ground, hover, survey and excavation | Runner, Crawler, Scout, Scrabbler, Ripper, Digger | Human, existing scripted feedback, policy, passive | Prepared articulated bodies and compatible ACT-005 equipment; actual movement remains model-specific |
| Flight, jumping and climbing | Skimmer, Copter, Pouncer, Walljumper, Clamberer, Swinger | Human, existing scripted feedback, policy, passive | Existing flight, contact, grip and rope mechanisms; local feedback does not promise a route through arbitrary terrain |
| Utility, hybrid and articulated machinery | Winchbug, Magpie, Monowheel, Inchworm, Tandem, Tricopter, Heavylift and the remaining physical models | Human, existing scripted feedback, policy, passive | Existing mechanisms, bounded actions and resource rules; no virtual Thunderbowl combat |
| SetP player movement | Stuntbuggy, Trialsbike, Acrobat, Arcadelander, Jetbarrel | Human, existing scripted player feedback, policy, passive | Reuses player controllers and real Rapier shapes; round wheels retain their documented conservative square native masks |
| 4LY assisted flight | Trainer, Hauler, Drifter, Dart | Human, goal-relative scripted teacher, policy, passive | Existing single-chassis velocity controller, two-axis movement action only; no equipment mount or mass/inertia overrides |
| Passive bodies | Reference barrel | Passive only | One physical body; no autonomous drive, policy or usable mount |

The registry reports each model's mechanisms and original limitations. Admission
does not add abilities to a model: a ground rig does not gain flight, a flyer
does not gain a usable mount, and a passive barrel does not acquire a motor.

Old starts and ordinary new-world defaults retain **eight logical actors** and
**64 actual response bodies / 64 native occupancy proxies**. The optional
versioned `sandbox_capacity` dictionary independently admits numeric
`logical_limit`, `body_limit` and `proxy_limit` values from 1 through **4096**.
The supported per-actor prepared topology remains **eight parts**. These are
separate budgets; a barrel costs its one actual body/proxy, while a multipart
machine costs all its prepared parts, joints and proxy shapes. A flyer can reserve several rectangular proxies for one
response body. Each physical part has its own response owner; several proxies
for a compound hull do not duplicate its inertia or impulse authority. Equipment
remains a reserved part after release. Dropping it never creates free capacity.

The 4096 ceiling bounds allocated native response/observation workspaces and
identity-indexed cancellation tables. Native occupancy identities remain within
their unsigned 16-bit representation; copied response IDs remain exactly
representable. It is an allocation/engineering ceiling, **not a qualification
claim for 4096 running actors**. The real native/Rapier matrix exercises 16/32/64
across passive, mixed and articulated populations, with higher-count experiments
reported separately. No FPS threshold deletes actors, disables controllers or
reduces fidelity. A capacity Apply is an explicit prepared-owner transaction and
cannot reduce a budget below the actual composition. Native registries and
response scratch admit the same bounded maximum, so UI admission is not a
cosmetic increase in logical slots.

Validation rejects an unknown or changed definition, unsupported source or item,
out-of-canvas prepared hull, malformed option, excess slot/part/proxy count or
invalid native policy before adoption. Failed preparation retains the old applied
authored document and coupled session, with a refusal in Workbench status. It
does not silently remove bad actors from a valued map.

## Ownership and lifecycle

The native simulation worker remains the exclusive owner of cellular materials.
The existing main-thread physical session and Rapier bridge own bodies and joints.
NPCs add no simulation world, polling thread or native worker. A provisional
physical space used during a fallible authoring transaction is the existing
prepared-owner mechanism: it is held frozen, verified and adopted only after
the matching native preparation succeeds. It is not a second running gameplay
authority.

The inspected actor is independent of the human pilot. Selecting a body, focusing
the camera on it, opening its observations or painting beside it does not change
its producer. Only the pilot receives ordinary human gameplay input. Other human
source actors have no active pilot and receive no fresh human drive. Scripted
and policy-fixture actors continue on their own schedules regardless of panel
visibility or inspection selection.

In ordinary Paint mode, **Brush**, **Eraser** and right-button erasing work while
the simulation runs through the existing bounded Workbench disc queue and
authored-stamp recorder. A live stroke is not an atomic paused before/after
snapshot and does not create paused Undo/Redo authority. Line/rectangle/outline,
selection, Fill, copy/paste and their native history transactions still require
Pause. The controller retains the same pending-operation, recovery, source and
capacity fences for live brushes.
Fast press/motion/release sequences retain each admitted disc sample, including a
distinct release endpoint, through that existing bounded queue. The overlay does
not preview a paused interpolated stroke across unsampled live cells.

`set_workbench_control()` uses the existing `takeover()` path. It cancels pending
input/edges, tools, issued observations and command leases; advances control
generation; then establishes the new source. It preserves the live actor slot,
authored identity, run, RIDs, joint graph, pose, momentum and existing resource
and equipment state. Handoff does not reinstall terrain or reconstruct bodies.
Private controller state is allowed to reset on cancellation; it is not a saved
simulation checkpoint.
Hand-back retains the actor's current authored equipment selection even when it
uses model defaults because no prior source was remembered. Remembered prior
sources belong to the current authored world: a new authored installation clears
them, and retained actor edits retire entries for deleted/replaced instances.

Disabling decisions applies the same cancellation semantics while leaving the
body physically present. Passive control leaves physical forces and contacts
active without autonomous drive. Lease expiry cancels held actions rather than
inventing a release edge for charged equipment. Per-actor fault and command
diagnostics remain separate. Missing external output simply expires that actor's
authority; the cellular owner never waits for inference.

Pause freezes gameplay progression and retires current input. Step uses the
ordinary acknowledged Workbench step. Both pause edges revoke session authority
synchronously with worker cancellation, including Pause followed by Play within
one process frame. Resume publishes a fresh neutral body/equipment frame before
further physical progression. A refused body frame stops both owners with an
explicit error; Play and Step remain unavailable until Reset, Restore or a
successful authored preparation installs a valid owner. Focus loss or entry into a control panel
cancels affected human input and requires controls to be released before they
rearm; it does not retire unrelated NPCs. Restore, world replacement, deletion,
replacement and application close retire the affected sessions and observations.
Reset/replacement/equipment Apply use explicit authored preparation and may
restart controller and resource state; they are distinct from live handoff.

## Paused placement and live physical grabbing

The existing toolbar tool selector has **Live grab** and **Place / rotate**
choices. The one Configuration window contains Actors, Controllers, Equipment,
Physics, Capacity and Diagnostics. Opening it revokes active pointer/human
commands without pausing independently scheduled actors. Inspection is distinct
from explicit piloting, and selecting either manipulation mode blocks human
drive/equipment input while leaving NPC authority local to each actor.

Paused placement captures copied current part transforms, model/instance/run
identity, assembly origin and geometry. The preview transforms every current
part around the same origin; it does not prepare native owners on mouse motion.
Q/E rotate, Shift Q/E use one degree, arrows nudge and Shift arrows use the
configured fine move distance. Optional grid snapping applies to the assembly
origin; Shift drag bypasses it. Release or Enter submits one prepared owner.
Escape, right-click, focus loss, opening Configuration or release outside the
canvas cancels the preview. All physical corners and conservative native masks
must remain in bounds. Existing developer hard-terrain overlap semantics remain
available; overlaps do not gain privileged collision or material deletion.

Commit retains the current articulation of a supported assembly, rotates real
colliders/joint frames, clears the moved actor's momentum, and updates its
authored spawn and orientation. Other supported poses and native cells transfer
through the existing prepared transaction. Controllers/resources may restart.
The old owner and authored document survive failed preparation. Retained
transactions explicitly refuse an actor whose equipment has been released,
fixed or reattached with changed anchors: reconstructing the authored topology
would change its live joint graph. Explicit Reset/Replace of that actor restores
the authored graph; removing it also removes the retention requirement. This is
not a general simulation checkpoint mechanism.

Live grab picks a real part collider and a local point on that body. The session
applies an implicit damped spring through bounded point forces, accounting for
translational and rotational response. It never teleports a running body,
disables collision, changes its producer or replaces the joint graph. Default
stiffness/damping/maximum force are 160/24/24000; configurable finite ranges are
5–2400, 0–160 and 10–1000000, with additional bounded acceleration/torque safety.
Only the grabbed actor's drive decisions/actuators are suppressed. Grab/release
revoke its old command leases and observations; release resumes its compatible
source. Other independently scheduled NPC/policy actors keep their own
generations and schedules. The exclusive Grab/Place input mode neutralizes the
human pilot's keyboard/equipment input even when another actor is selected;
returning to Paint/ordinary interaction requires released controls before rearm.

Temporary ownership stores a weak session reference, run/epoch/instance/part
identity and a local anchor. Each force application resolves and checks the
current real body. Release outside the canvas, Escape, focus loss, Pause,
configuration entry, Save/Flatten, actor/world replacement, worker failure and
session teardown end the force. Fixed/frozen equipment cannot be grabbed. No
temporary grab state enters the authored document. The preview and spring line
are presentation only and own no simulation body or native cells.

## Producer and policy interface

Authored sources are `human`, `scripted`, `policy` and `passive`. `scripted` maps
to the existing session's `demo` producer. The UI calls it **Scripted NPC**, not
AI. A policy source additionally chooses `fixture`, `external`, or the opt-in
AMBIENT-001 `ambient` adapter. The latter appears as **Procedural NPC / Ambient**
and composes validated modules over copied observations; see the
[ambient contract](ambient-actors.md) and [owner guide](../operations/ambient-workbench.md).
It uses the existing issued-observation and leased-command path. The fixture is
a deterministic local test producer that obtains actual issued observations and
submits the same leased command envelope as an external caller. Selecting
External Policy does not start an HTTP service, neural model, SLM or LLM.

| Workbench API | Meaning |
|---|---|
| `select_instance(instance_id)` | Inspect without changing producer |
| `pilot_id()` / `pilot_instance(instance_id)` | Inspect or explicitly change the human pilot; takeover is live |
| `hand_back_pilot()` | Restore the previous compatible source, or the model's scripted default |
| `set_actor_control(instance_id, control)` | Validate and switch source/enabled state/cadence/policy adapter; rejects starting-equipment changes |
| `actor_observation(instance_id, false)` | Copy current diagnostic observation; does not issue new command authority |
| `actor_observation(instance_id, true)` | Issue a fresh physical policy observation for an enabled, running policy actor |
| `submit_actor_policy(instance_id, command)` | Resolve stable authored identity to its current slot, then submit through session producer/freshness checks |
| `physical_actor_session.workbench_control(instance_id)` | Copy source, run/epoch/slot/generation/tick, lease, sequence, per-actor accepted/refused counts, decision costs and diagnostics |

An in-process integration uses the same adapter available in the panel:

```gdscript
var view := workbench.actor_observation(instance_id, true)
if not view.is_empty():
    var action := {"move": Vector2(0.5, 0.0)}
    var command := CyberPhysicalActorSession.make_command(
        view, int(view.last_sequence) + 1, action, 12)
    workbench.submit_actor_policy(instance_id, command)
```

`make_command()` copies the run, epoch, physical actor slot, issued observation
identity/tick and applicable equipment identity. The caller maintains monotonic
sequences and must use a fresh observation after cancellation, takeover, expiry
or replacement. A policy command uses version 2 and
`kind: physical_wire_action`; its bounded lease is 1–18 physical ticks. Local
decision intervals are 1–12 ticks. The script scheduler collects copied views
before submitting the independent decisions, at the existing physical tick
boundary. Decision time is recorded separately from native and Rapier progress.

Wrong actor, producer, run, epoch, generation-bound observation, repeated
sequence, expired lease, unissued observation and sampled command kinds refuse.
Knowing a reused physical slot is insufficient: a replaced actor has a new
authored identity and retired run/observation authority. No diagnostic view
exposes mutable native cell storage or PhysicsServer objects.

The panel's **Issue observation** prepares an editable JSON envelope. **Submit
command** keeps that envelope's original identity and therefore demonstrates
stale-output refusal when editing takes too long. **Send fresh test action** is
explicitly a local test producer: it issues a new observation and binds the edited
action values immediately. It does not relabel a delayed external reply as fresh.

## Reuse and research boundaries

Ordinary physical scripts reuse `physical_actor_script.gd`, including its local
contact/support, direction changes, stall recovery, resource, grip, rope and
player feedback. That script uses `physical_usable_script.gd` for suitable
equipment. The small Workbench adapter supplies copied observations and actions;
the existing rig/controller still applies every motor force.

4LY reuses `physical_flight_teacher.gd` for a goal-relative patrol between bounded
authored endpoints and `physical_flight_controller.gd` for the existing plant.
It reports local obstacle sensing as unavailable rather than importing Flight
Lab's evaluator or privileged arena queries. Existing Workbench flyers use a
small local pose/velocity feedback adapter that submits existing fleet action
values; their established fleet controller continues to own actuation.

ACT-001/002 sampled actors remain owned by `actor_prototype_session.gd` in the
native-worker scheduling lane. They are **not an alternative representation
inside this composition release**. A physical observation is never presented
as a sampled v1/v2 array. A caller wanting a learned policy should consume the
physical observation contract and return its supported bounded action values.

Thunderbowl's full controller contracts include sampled self-state layouts,
team/neighbor visibility, virtual tag readiness, messages and arena lifetime.
Physical Workbench has no implicit authority for those fields.
`workbench_reactive_policy.gd` reuses the actual
`examples/thunderbowl/controller_base.gd::_wire_toward` helper for policy-fixture
actors whose physical profile has ground/walk movement and an ordinary primary
jump. It excludes player-controller rigs, charged jumps and flight. The current
compatible models are Runner, Crawler, Scout and Rocker, selected by capabilities
rather than a model-name dispatch table. The adapter projects only copied self
motion/support and a bounded patrol goal into the pure
helper, uses local wall/stall feedback to change direction, then returns physical
move/aim/effort/jump values. Its diagnostics identify
`thunderbowl-wire-to-physical/v1`; it does not claim to run a sampled actor. The
Mixed Workshop's player Buggy continues to use its existing physical player
feedback through the same policy envelope.

Direct sampled metal actuation, oracle targets, virtual tag combat, NCA weights
and smart-link requests are not Workbench motor commands. The steering reuse
imports no arena, combat or messaging owner. Coordination and a slow
model-intention adapter require explicit future schemas and budgets. An untrained
NCA is not a trained NPC, and the smart-link contract is not an operational
model service.

## Physical equipment and material authority

Compatible physical rigs retain the existing ACT-005 32-item catalogue, mount,
hit/mask validation, cooldown, charge, release/attach and native material
accounting. The Workbench bridge maps each equipment part to its actual native
proxy ID, including offsets after a compound flyer. Main publishes the copied
body sample and equipment frame together through the existing worker boundary;
native receipts return to the matching session.

Physical ACT-004 effects and the ACT-005 engine receive the committed Workbench
canvas extent, so valid tools on a 2048 × 1024 landscape are not clipped to a
historical 1024-cell laboratory width. Coordinates outside the committed extent
still refuse. Sampled actor/usable contracts keep their own bounds. The worker
uses the existing cancellation mutex across the bounded physical effect apply,
so cancellation cannot overtake validation and leave a late material write.

The example gives Runner a Brick Stamper, Crawler a Powder Vacuum and Skimmer a
Water Lance. These demonstrate deposition, excavation and liquid emission with
native `physical_usables` receipts and `changed_cells`; they do not acquire human
paint permissions. Model/tool behavior remains local and resource-bounded.
Crawler starts at `(300, 350)` on the solid approach to the granular patch.
These ground mechanisms obtain traction from real Rapier hard-terrain or body
support. Native granular support alone does not become a grounded contact:
placing a rig on a thick loose-powder bed can strand it until legitimate
equipment clears enough material. The example preserves that boundary instead
of granting a controller artificial traction or material-edit privileges.
Autonomous tools never use or capture the human PAINT pointer. Human tools use
explicit tool keys/gamepad controls and the observed equipment identity.
Workbench also disables the legacy slot-zero mouse equipment adapter: an
equipped scripted actor in the first physical slot cannot consume pointer input
or have its generation cancelled by the old single-player path.

Live source switching preserves the current item. **Apply equipment / restart**
is a separate authored prepare operation that changes the starting loadout,
retains live material cells/body poses where supported, and explicitly restarts
controller/resource state. No item is silently attached to a model without a
mount. Native refusal retains the old applied arrangement.

## Authored data, options and compatibility

The root remains **Setup-v2**. An actor retains `id`, `model`, `hash`,
`spawn` and `options`, and may add this strictly validated extension:

The optional actor field `spawn_rotation_degrees` is a finite value in
`[-180, 180]`, defaulting to zero when absent. It rotates the starting physical
assembly, not merely its artwork. The optional root `sandbox_capacity` has
exactly `version: 1`, `logical_limit`, `body_limit` and `proxy_limit`; all limits
are finite integers in their supported ranges. Missing metadata preserves the
accepted 8/64/64 admission. Saved larger compositions retain their budget and
reopen without truncation. JSON numeric text round trips retain authored angle
precision; private leases, live articulation and momentum remain unsaved.

The existing optional controller object is:

```json
"control": {
  "version": 1,
  "source": "scripted",
  "enabled": true,
  "decision_ticks": 6,
  "policy": "fixture",
  "usable_index": 3
}
```

All six keys are required when the optional block is present. The ambient
candidate additionally permits `ambient`, an authored version-1 profile; the
`ambient` policy adapter requires it. A retained valid profile may remain attached
during human handoff. No ephemeral timers, RNG state or command authority enter
the saved profile. Other unknown keys,
versions, sources, adapters, nonintegral numeric fields, incompatible items and
out-of-range cadence refuse. `usable_index: -1` means no starting usable.
Absent control on valid legacy flyers/barrel uses the established human/passive
defaults, without adding fields during read. Existing fleet and barrel definition
hashes are retained. Added physical hashes are versioned hashes of the full
prepared catalogue definition, including the equipment topology.

Existing per-instance options retain their original numeric bounds: response
budget 5–80; mass/inertia multipliers 0.01–64; flyer thrust/torque 0–64; flyer
boost 1–8. RFT requires budget 20. Non-flyer models reject the flyer-only
thrust/torque/boost knobs unless they retain neutral values 1/1/2. 4LY's frozen
plant also requires mass/inertia 1/1. The UI disables irrelevant controls. Device
and key preferences are not part of the actor's authored control block.

Reusable model defaults are the existing catalogue/profile definitions and the
registry's copied `default_control(model)` values; independent placement starts
from those values, and **Defaults** restores the established neutral option
multipliers. Per-instance edits are saved with that actor. This release does not
add a separate owner-authored reusable preset library.

Setup, generated-start and material-baseline readers all canonicalize validated
actor/control integer fields after JSON decoding. The extension does not change
generated terrain fingerprints, material payloads, ordered PAINT history or
Flatten's material-only semantics. Older binaries can refuse a new extension;
they must not silently drop it. Invalid data never causes a partial save rewrite.

Save stores the authored composition and accepted environment edits. Load/Restore
reconstructs actors at authored spawns with their configured producers/equipment.
It does not restore momentum, joint state, evolved cells, controller memory,
outstanding leases or policy observations. Flatten remains the explicit material
baseline operation; it does not turn the save into a live-physics checkpoint.

## Qualification boundaries

The ordinary scene test
[`test_workbench_actor_composition.gd`](../../godot/tests/test_workbench_actor_composition.gd)
uses real Workbench preparation, native cells, Rapier actors, UI APIs, equipment
receipts and authoring history. It checks concurrent motion/contact, live handoff,
policy freshness and expiry, pause/focus, editor transactions, failed preparation,
slot reuse and fresh-process save/reopen. The running paint case sends actual
viewport mouse events through canvas `gui_input` and the PAINT controller,
checks material publication and continuing NPC actions, exercises live Eraser,
checks a complete same-frame press/motion/release gesture, and refuses a running
precise shape. Custom-item fallback hand-back and a new authored installation
exercise the lifetime of remembered prior sources. An equipped first-slot NPC
protects the pointer/legacy-input boundary. A same-frame pause/resume adversary
checks synchronous producer revocation and continued native/Rapier progression;
each gameplay phase requires the native owner to advance its requested interval,
allowing one completion still awaiting render publication. The human ground
pilot case checks an admitted and applied movement command. Its headless input
substitution is the unavailable OS focus predicate. Three explicit failure
phases send a negative readiness response through the real prepared-owner
protocol after native preparation exists. They check pending pilot/workshop
intent cleanup and a running cast's exact pose, momentum, resources and authority
at the rollback boundary. They do not substitute cells or physics. Optional PNG
capture refuses a headless display. A separate cancellation adversary retires a
real worker equipment generation, checks that its refused replacement frame
cannot permit further Rapier steps, and requires explicit Reset to recover.

The catalogue test covers old/new codecs and malformed data. Session and native
coupling tests cover more models/capacity/adversaries than the saved example.
Their source-backed procedures and exact commands are in the owner guide; dated
qualification evidence must identify the tested source and matching runtime.
The native response-owner capacity change requires rebuilt Windows and Linux
runtime candidates. A schema or headless pass does not constitute graphical
playfeel acceptance, a Windows execution, or a broad performance result.
