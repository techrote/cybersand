---
title: SetA actor controls and legacy policy compatibility
status: Current
document-kind: contract
scope: Original SetA Runner, Skimmer and Crawler motors and version-1 policy compatibility; the actor-rigs contract owns additional sets and version-2 actions
canonical-for: [actor-control-prototypes, actor-policy-input-v1]
last-reviewed: 2026-10-18
related-documents: [actor-rigs.md, granular-interaction-policy.md, player-environment-profiles-and-traversal.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/configuration-reference.md, ../operations/local-build-and-validation.md, ../reference/status-and-roadmap.md]
---

# SetA actor controls and legacy policy compatibility

## What is being prototyped?

**Current, experimental:** Runner, Skimmer and Crawler are the three original
ACT-001 / #161 movement rule sets, now grouped as **SetA**. Each receives human input or a
policy-produced command through the same value interface. A controller's source
does not grant different collision rules, movement authority or capabilities.

The [actor-rigs contract](actor-rigs.md) owns ACT-002's additional SetB/F/Y/U/V
rigs, independent aim and effort/trim/reel channels, auxiliary action and additive
40-value observations. This page preserves the SetA motor and version-1 seam;
its three-model and fixed-body claims apply to SetA.

The models reuse the sampled character's fixed rectangular body and current
material-aware support/collision queries. They remain separate from PCHAR's
barrel/Rapier representation experiment and PENV's sampled-player tuning profile.
These prototypes do not select the final player representation or close the
broader player/granular acceptance work.

Source: [`actor_prototype.gd`](../../godot/scripts/actor_prototype.gd), with shared
sampled movement in [`sampled_character.gd`](../../godot/scripts/sampled_character.gd)
and bounded session ownership in
[`actor_prototype_session.gd`](../../godot/scripts/actor_prototype_session.gd).
Exact movement constants and limits belong to the
[configuration reference](../reference/configuration-reference.md#actor-control-prototype-values).

## Which capabilities distinguish the three models?

| Model | Movement and actions | Intended comparison |
|---|---|---|
| **Runner** | Accelerated ground movement, limited air steering, buffered jump with brief coyote time, jump-release height control and an edge-triggered horizontal dash | Responsive platform traversal with deliberate jumps and bursts of horizontal movement |
| **Skimmer** | Normalized two-axis thrust, held boost, held unpowered airbrake and finite rechargeable energy; depleted power restores gravity | Direct steering through open space, with a cost for sustained thrust and fast bursts |
| **Crawler** | Strong ground traction, a short hop, supported obstacle clamber and held brace | Slower, controlled movement over uneven material surfaces |

These are gameplay rules in the current cell/pixel coordinate system, not
calibrated physical models. In particular, Skimmer movement does not implement
Water buoyancy or pressure, and Crawler traversal does not confer wall/ceiling
adhesion or a general grappling capability. Native cells continue to own material
state; the actor cannot paint away an obstacle to make its movement succeed.

Runner coyote time accepts a recent departure from supported ground; its input
buffer permits a jump press shortly before landing to be used when support
arrives. Releasing primary while rising cuts the jump. Holding primary does not
automatically retrigger a jump, and holding secondary does not repeatedly request
new dashes. Crawler's brace is a movement rule, not a physical anchor that makes
an unsupported material structure load-bearing.

## How are the prototypes selected and controlled?

**Current desktop controls:** open the actor selector with **F5** in the ordinary
sandbox or exploratory showcase map and choose **SetA**. Select the **Sampled** baseline, **Runner**,
**Skimmer** or **Crawler**; choose **Pilot: keyboard**, **Pilot: scripted demonstration** or
**Pilot: external policy input**. Two optional demonstration NPCs allow a
small simultaneous comparison. Applying restores the selected map
or sandbox at the owner boundary. The [physical actor programme](../operations/physical-actor-programme.md)
describes the separate Rapier choices, protected apparatus and per-request map
installation acknowledgements.

The worker's `queue_actor_prototype_reset(definitions, spawn_position)` returns
zero for immediate refusal or a positive request receipt for queued admission.
Admission alone does not mean the model has changed. The owner rechecks actual
scenario state and publishes `actor_prototype_reset_serial`,
`actor_prototype_reset_applied` and `actor_prototype_status`. The desktop waits
for that outcome before admitting human commands and reconciles a refused
selection to the published actor identity. A scenario transition may take
priority over an actor reset requested against an older ordinary-world snapshot.
An ordinary reset that replaces a pending actor reset publishes a refused
disposition for its receipt. This is a single replaceable reset mailbox: only the
latest disposition is retained. A later published serial means an older receipt
has been superseded; `actor_prototype_reset_applied` describes that published
serial, not every earlier request.

| Input | Runner | Skimmer | Crawler |
|---|---|---|---|
| A / D | Move left/right | Horizontal thrust | Move left/right |
| W / S | No vertical steering | Vertical thrust | No vertical steering |
| Space, primary action | Jump; release controls height | Hold boost | Hop |
| Shift, secondary action | Press for dash | Hold unpowered airbrake | Hold brace |

Keyboard is one producer of the same bounded movement/buttons used by a
policy. Key events publish press/release state as well as the regular physics
sample, so a submitted short tap can survive between motor ticks. Scripted demo
is a small hand-authored action producer. **External policy**
selects the command seam; it does not start an inference process or connect a
network service. An external controller must submit fresh valid commands for its
assigned actor or the control input becomes neutral. Neutral Skimmer input holds
a powered hover while energy remains; it is not an emergency power-off command.
Its explicit airbrake is unpowered and permits gravity to act.

Focus loss and entry into gameplay-blocking UI cancel human input. Controls rearm
only after all gameplay keys are released, preventing a held menu key from
becoming a jump/dash on return. Controlled Tower, Water and MicroScenario runs
retain their existing fixture identity and do not acquire these optional actors.
PENV edits are refused while a prototype is selected because the model owns its
fixed movement values. F7's sampled-baseline recovery toggle is unavailable for
prototypes; F6 leaves the prototype session for the existing PCHAR representation
experiment through a reset.

## Who owns actor state and collision?

**Current:** the desktop simulation worker owns the prototype actors and advances
their movement alongside the sampled-player stage, outside internal native jobs.
The main thread owns keyboard/UI input and drawing. It sends copied value
commands and consumes copied actor publications; it never reads a live worker
actor or calls World queries for a policy.

Each model uses the existing sampled character's **8 by 14 cell** rectangle.
Movement checks bounded increments against current material-aware support and
body occupancy under the same exclusive World owner. The prototype does not
create a scene-tree physics node or native job per actor. Rapier objects stay on
the main thread and retain their existing generic coupling contract.

Runtime enclosure is distinct from spawn validation. A prototype may be
immobilized by material entering its occupied space; movement rules must not
silently relocate it through terrain. Explicit reset/spawn recovery is a separate
bounded operation. The existing ordinary sampled-player recovery behavior still
belongs to [PCHAR and the granular policy](granular-interaction-policy.md).

Crawler clamber requires clearance throughout its admitted vertical path and a
supported destination. A free endpoint alone is insufficient: a low ceiling or
intervening obstruction must reject the traversal. The fixed maximum clamber
height bounds the candidate search and preserves a clear limit to that mechanic.

## How can a neural policy control the same actor?

**Current interface, future policy consumer:** the movement model consumes a
small value command and exposes a bounded observation. Keyboard adaptation and a
future neural-network controller must use that same command contract. Their
responsibility is to select actions; the actor model remains responsible for
admission, acceleration, action timing, energy and collision.

The owner-local core methods are `configure_model(StringName) -> bool`,
`reset(Vector2)`, `simulate_action(delta, movement, primary, secondary, world)`,
`capabilities() -> Dictionary` and `observation() -> PackedFloat32Array`.
`movement` is a finite `Vector2` with each component clamped to -1..1. Runner and
Crawler ignore y without slowing x; Skimmer additionally limits the vector's
magnitude to one so diagonals gain no extra thrust speed. `primary` and
`secondary` are held button states interpreted by the selected rule set, with
edges retained by the session. These methods are called by the serialized
simulation owner; a main-thread or inference worker must use the copied session
bridge rather than directly invoking the live actor or passing itself World.

Version 1 observations have a fixed 16-float order:

| Index | Value |
|---:|---|
| 0–1 | Position x, y in world cells |
| 2–3 | Velocity x, y in cells/second |
| 4 | Grounded flag |
| 5 | Runtime-enclosed flag |
| 6 | Energy fraction |
| 7–8 | Primary-ready, secondary-ready flags |
| 9 | Remaining action cooldown in seconds |
| 10–11 | Primary-active, secondary-active flags |
| 12 | Horizontal facing direction |
| 13 | Model index: 0 Runner, 1 Skimmer, 2 Crawler |
| 14 | Occupancy query count for the last actor update |
| 15 | Movement-limited flag |

Flag values use 0/1. The entire vector is **not normalized**: absolute position,
velocity, timing and query-count fields retain the units above. A training
adapter must version its own feature scaling. The session publication pairs each
observation row with epoch, simulation tick, model, producer and accepted
sequence. The zero-based row index is its actor ID; the vector alone is
insufficient to identify a response target. `sequences` reports the latest
**admitted** command, which may arrive after the motor last stepped; it is not an
applied-action or exact-replay receipt. ACT-002 additionally publishes consumed
actions, sequences and edge flags through the [v2 observation contract](actor-rigs.md#identity-freshness-and-consumed-edges);
these additive fields do not change the original observation order.

### Command admission and expiry

`CyberActorPrototypeSession.configure(definitions, world)` admits at most eight
actors. Each definition provides `model`, `position` and one producer identity:
`human`, `policy` or `demo`. Session state stays with the same simulation owner.

The session submission contract is below. Producers reach it through the
thread-safe `CyberSimulationWorker.submit_actor_action` forwarding method with
the same fields; they do not obtain the owner-local session or motor itself.

```gdscript
submit_action(actor_id: int, epoch: int, sequence: int, observed_tick: int,
    movement: Vector2, primary: bool, secondary: bool,
    lease_ticks: int = 12, producer: StringName = &"policy") -> bool
```

Admission checks actor/producer identity, the current epoch, strictly increasing
sequence, finite movement and the observation tick. Future observations are
rejected. A lease is at most 18 simulation ticks; its deadline is calculated from
the **observation tick**, so a delayed inference result cannot gain a fresh full
lease merely by arriving late. At the 60 Hz desktop actor cadence the default
lease is 200 ms and the maximum is 300 ms of simulation time.

Each actor slot has one replaceable held-state command and latched rising edges.
Several submissions before a tick replace continuous movement with the latest
accepted value while preserving a brief press/release; multiple rises of the
same button before consumption coalesce to one edge. There is no action FIFO to
drain later. Rejection returns `false` and does not create a command for another
actor or bypass the active producer's authority.

Pause invalidates command identity and clears held inputs/edges while preserving
actor cooldown state. Reset or scenario replacement also invalidates the old
epoch. An input producer must read the current published epoch and observation
tick after those transitions; late output for the previous actor incarnation is
rejected. The complete controller state is not serialized for replay.

### Neural work remaining

**Planned:** an inference runner, trained weights, rewards, training environments,
policy scheduling and model deployment. A hand-authored demonstration policy is
not a neural network and must be labelled accordingly. No model training or
neural performance result follows from the shared interface existing.

Future inference must consume published values and return actions without waiting
inside the simulation owner. A slow or absent policy must not stall cell ticks.
Observations are a compact local control input, not a full world-state view or
an exact-replay record. Adding richer perception needs its own explicit query,
copying, capacity and staleness budget. The current vector contains actor state;
it does not provide a terrain sensor grid or neighboring-actor perception.

## How are actor observations retained with gameplay recordings?

**Current:** `CyberSimulationSnapshot.actor_prototypes` publishes the current
actor sample with its own epoch and actor tick. When a new material render
generation is produced, the worker also freezes that generation's actor context
inside `render_context`. Those two values may describe different simulation
ticks when actor motion continues without changed material bytes.

The gameplay recorder writes current actor state under
`actor_sample.actor_prototypes` and the generation-bound copy under
`material_generation.actor_prototypes`. `player.actor_prototype` describes the
current actor sample. `player.environment_profile_applied` is false for these
prototypes, so retained PENV configuration is not mistaken for their active motor
tuning. Recorder copying and I/O retain the existing
[recording ownership](../architecture/data-ownership-and-lifetimes.md#desktop-gameplay-recording-ownership).

The observation/capability values identify this experiment; they are not a
complete saved controller state, exact action replay or a trained policy dataset.

## What bounds the cost and response time?

The [fixed limits](../reference/configuration-reference.md#actor-control-prototype-values)
admit at most eight actors, each with the same 8 by 14 sampled body. Updates
accept at most 1/30 second and limit speed to 120 cells/second, bounding ordinary
movement to four increments per axis. A Crawler tries at most one ledge search
per update and at most four cells of rise with intervening clearance. Runtime
burial immobilizes the prototype, so it does not repeat a relocation search.

Local observations contain 16 floats plus bounded session metadata and do not
scan the world. One replaceable held command and coalesced rising edges per
actor bound retained input work. The general desktop gameplay/emission queues
retain their separately documented limitations; this actor session does not
claim to replace every command path in the engine.

Holding an action does not authorize an unbounded action queue. Transient actions
must be consumed by the actor's timing rules, and stale policy outputs must not
silently become input for a replacement actor after reset. Ordinary presentation
can remain independently paced while the worker services admitted actor state.

**Not yet established:** production many-NPC throughput, target-PC frame-time
acceptance, maximum acceptable inference latency or zero-allocation simulation.
The implementation uses GDScript value containers and copied publications;
bounded actor counts and local queries are not a claim that every operation is
allocation-free. Any timing report must name the source, runtime, actor count,
world/fixture, platform and worker configuration actually tested.

## What remains experimental?

These three SetA models are candidates for play and comparison. Owner evaluation still
decides whether their acceleration, timing and special actions are useful.
Combat, tools, inventory, animation, arbitrary actor shapes, actor-to-actor rigid
collisions, broad material-response calibration and learned policies are outside
the original SetA increment. The [additional rig sets](actor-rigs.md) separately
introduce authored shapes, torque, attachments and selected bounded tools.
The sampled body does not become a cellular material or a
generic Rapier body merely because a policy controls it.

The desktop experiment and controller-level tests do not establish a Web/browser
integration. Registered Tower, Water and MicroScenario controls retain their
existing representation identities. Prototype observations do not extend CYSD1
into exact replay or turn a gameplay recording into a complete training dataset.

Use the [build and validation guide](../operations/local-build-and-validation.md#actor-control-prototype-checks)
for focused checks, and the [ACT-001 dated audit](../audits/2026-10-18-act001-actor-control-prototypes.md)
and [validation ledger](../reference/validation-evidence.md) for actual execution
outcomes. Passing a headless movement fixture is
separate from visual/feel acceptance or a measured NPC scaling result.
