---
title: Modular procedural ambient actors
status: Current
document-kind: contract
scope: AMBIENT-001 opt-in copied perception, pure procedural decisions, capability adapters and authored profiles
canonical-for: [ambient-actor-intelligence, ambient-behaviour-modules]
last-reviewed: 2026-11-24
related-documents: [workbench-actor-composition.md, physical-actor-rigs.md, physical-free-flight.md, ../operations/ambient-workbench.md, ../architecture/data-ownership-and-lifetimes.md, ../research/ambient-001/mission-ledger.md, ../research/ambient-001/behaviour-ledger.md]
---

# Modular procedural ambient actors

The [AMBIENT-002 successor contract](ambient-living-inhabitants.md) extends this
retained version-1 foundation with explicit version-2 stateful profiles and
transactional population authoring. The sections below document the original
AMBIENT-001 vocabulary and qualification scope; successor execution is separately
recorded in its [mission ledger](../research/ambient-002/mission-ledger.md).

## Status and ownership

**AMBIENT-001 is an opt-in Draft/HOLD implementation candidate.** It adds
**Procedural NPC / Ambient** to ordinary Workbench actor authoring through the
existing local `policy` producer. The authored selector is `source: "policy"`,
`policy: "ambient"`; Human, Scripted, external Policy and Passive keep their
existing meanings. Nothing promotes an ordinary scene to autonomous control.
The accepted composition limits remain eight logical actors, eight prepared
parts per actor and 64 response bodies/native occupancy proxies. The larger
unaccepted Actor Compose #762 candidate is not a dependency.

The [owner guide](../operations/ambient-workbench.md) covers the actual editor,
presets, example scenes, painting, handoff and save/reopen procedure. The
[mission ledger](../research/ambient-001/mission-ledger.md) owns exact source,
runtime, qualification and delivery dispositions. This contract explains the
candidate source and its bounds; controller admission does not certify every
eligible rig's playfeel.

| Source | Responsibility |
|---|---|
| [`ambient_perception.gd`](../../godot/scripts/ambient/ambient_perception.gd) | Bounded shared native-ID publication cache, local material queries and copied environment envelope |
| [`ambient_engine.gd`](../../godot/scripts/ambient/ambient_engine.gd) | Per-actor private state and RNG, observation identity, simulation clock, arbitration and diagnostic copies |
| [`ambient_modules.gd`](../../godot/scripts/ambient/ambient_modules.gd) | Typed module metadata and eleven pure rule implementations |
| [`ambient_profile.gd`](../../godot/scripts/ambient/ambient_profile.gd) | Strict authored schema, cross-parameter constraints, capability validation and canonicalization |
| [`ambient_actuator.gd`](../../godot/scripts/ambient/ambient_actuator.gd) | Value-only movement adapters for supported existing physical rigs |
| [`physical_actor_session.gd`](../../godot/scripts/physical_actor_session.gd), [`workbench_actor_control.gd`](../../godot/scripts/workbench_actor_control.gd) | Existing ownership, decision cadence, fresh issued observations, command admission, leases and lifecycle |
| [`physical_actor_rig.gd`](../../godot/scripts/physical_actor_rig.gd) | Bounded owner-mediated terrain probes that return copied values |
| [`ambient_profile_editor.gd`](../../godot/scripts/ambient/ambient_profile_editor.gd), [`ambient_debug_overlay.gd`](../../godot/scripts/ambient/ambient_debug_overlay.gd) | Staged per-actor editing and read-only inspection/optional overlays |
| [`profiles.json`](../../godot/data/ambient/profiles.json), [`ambient_examples.gd`](../../godot/scripts/ambient/ambient_examples.gd) | Readable reusable personalities and ordinary native-material/actor scene recipes |

## Three authority layers

Perception reads permitted owner-issued values. Decisions turn those values into
bounded preferences and temporary intentions. Actuation translates the selected
intention into supported normalized actions. Native C++ still owns cells; the
existing main-thread physical session and Rapier bridge still own bodies,
contacts and motors. The engine receives no mutable World reference, node, RID,
physics space or position/velocity setter.

The session issues its existing version-2 actor observation before computing a
local policy action. The ambient adapter receives that view plus a separately
versioned copied environment. Its result returns through the existing command
constructor and submission checks, including run, epoch, authored instance,
physical slot, sequence, control generation, observation freshness and lease.
The adapter cannot skip admission or retain an old command after takeover.

| Contract | Current version and purpose |
|---|---|
| Workbench authored document | Existing version 2, with an optional profile under the actor's control extension |
| Actor control extension | Existing version 1; optional `ambient` data is meaningful with the ambient policy selector |
| Authored profile | Integer `version: 1`; immutable configuration, no physical or runtime state |
| Environment | `ambient-observation/v1`; copied actor and permitted local surroundings |
| Intent | `ambient-intent/v1`; direction, pace, effort, optional supported primary pulse and explanations |
| Physical command | Existing version-2 issued-observation/command/lease contract, unchanged |

The public engine API is `configure(profile, context)`,
`step(environment, delta_seconds)`, `reset(reason)` and `diagnostics()`.
`configure` returns `{ok, error, ...}` and commits only after validation.
Context supplies the stable authored actor ID, original home position and
explicit locomotion capabilities. `step` returns a copied intent; `diagnostics`
returns copies and cannot consume randomness, advance timers or issue commands.

## Copied observations and unavailable measurements

Environment identity includes `run_id`, `epoch`, physical `actor_id`, authored
`instance_id`, `control_generation` and physical sampling `tick`. The first valid
decision binds the run, epoch and slot. Later mismatches require explicit reset;
a pause may change command generation while preserving the same actor's private
state. Pose and velocity must be finite copied vectors. Missing or regressing
identity, tick, pose or simulation time yields a neutral unavailable intent.

Each sensor group carries its own availability. A valid actor observation can
contain unavailable materials or ledges; independent modules may still run.
Unavailable coverage is never interpreted as empty material, zero distance or
safe support. A previously acquired finite retreat remains a temporary intention
until its timer ends, even if a later sensor becomes unavailable. This does not
grant it new physical information.

| Observation | Supported scope and limits |
|---|---|
| Pose, velocity and support | Existing physical observation; actual grounded state is required to acquire a ledge reflex |
| Material identity | Copied native material-ID publication: stored native cells plus native ballistic projection; RG8/L8 identity bytes, with no displayed-colour classification |
| Material query | At most eight IDs, radius 1–96 world cells, default example 50; each ID uses the largest requested radius in the profile and individual modules recheck their own radius |
| Material resolution | Fixed four-cell lattice. Samples use cell centres `(4k + 0.5, 4j + 0.5)`, inclusive Euclidean distance from actor centre, clipped to canvas. Maximum bounding lattice is 2,401 sites per query; only sites inside the circle are read |
| Material result | Per-ID availability, observed presence/count, nearest observed location, distance and direction, radius, coverage sample count, native sampling tick and material revision |
| Boundary | Copied rectangle. The ordinary Workbench adapter supplies the canvas; the pure contract can also accept an authored region rectangle. There is no separate region-painting UI in this candidate |
| Physical ledge/drop | Two downward terrain probes outside the current attached hull, one on each side, at that module's exact lookahead of 1–32 cells. Allowed drop is 0–64 cells; searched depth and no-hit lower-bound semantics are explicit |
| Obstacle | Existing local horizontal terrain distances with a 30-cell no-hit sentinel. Obstruction threshold is at most 29 cells; a no-hit value never establishes a wall |
| Nearby actors | At most seven others from the accepted eight-actor host, within 96 cells, with matching run, epoch and physical tick. Missing poses are omitted. Compatible means supported adapters with the same vertical-movement affordance; ground and wheel rigs can share a group |
| Home | Original authored spawn, copied at profile configuration. Ground home return measures horizontal displacement; flight uses both axes |
| Resources | Existing energy observation is copied with explicit availability. No resource-sensitive module is implemented in this catalogue |

Nearest means **nearest observed sample**, not nearest native cell. A narrow
feature between lattice sites can be missed; a radius containing no lattice
sites is unavailable. `present: false` means no matching admitted sample, not
that all unsampled cells are empty. Positions use world cells, positive x right,
positive y down; zoom and screen pixels do not enter the query. Native IDs are
validated against the accepted catalogue, including Oil 16 and Water 3; reserved
ID 10 and Empty 0 are not attraction targets.

The shared CPU cache admits a canvas of at most 2,048 cells per axis, at most
256 patches and 16 MiB of publication payload per ingestion. RG8 storage is at
most 8 MiB for that canvas, shared across actors. Queries are scheduled at policy
decisions, not every rendered frame. The session enables publication caching
only while an enabled ambient producer requests material sensing. A new cache
needs a full source-matched baseline; later patches retain the owner's identity
and revision checks. No simulation thread waits for a sensor result.

Material freshness uses the **native** publication clock. If material revision
is unchanged, retained bytes remain valid. Once revision changes, a publication
older than 12 native ticks is unavailable until refreshed. Native ticks are not
compared with actor ticks. Owner snapshot serial, epoch, world generation and
monotonic revision/tick checks prevent an older render callback from making a
newer stale observation appear fresh. Main-thread physics and render ingestion
consume the same immutable publication mechanism before its acknowledgement.

Ledge samples are separate from canvas and obstacle information. A ray clipped
by the canvas without a support hit, beginning in non-support geometry or lacking
sufficient searched depth is unavailable; it does not prove a cliff. A hit with an upward support
normal can establish a drop. An unclipped empty ray proves only that no support
was found through its inclusive searched depth. Requests with equal reach/depth
are shared; distinct modules retain their own results. The profile maximum
bounds this work to 32 additional terrain rays per actor decision, separate
from the motor's existing sensing allowance. No ledge probe runs merely because
an inspector is open.

## Profiles, seeds and validation

A profile has exactly `version`, `id`, `name`, `description`, `seed`,
`shared_seed` and `modules`. Each of at most sixteen modules has exactly `id`,
`type`, `enabled`, `priority`, `weight` and `params`. Stable IDs use 1–64 ASCII
letters, digits, underscores or hyphens. Instance IDs must be unique within a
profile. Priority is an integer from 0 to 1,000; weight is finite from 0 to 10.
Zero weight removes the module's contribution, including overrides.

The module metadata defines every parameter's type, default, units and range.
Validation rejects unknown fields/types/materials, missing fields, nonfinite
numbers, incompatible enabled modules and invalid relationships. For example,
avoidance requires entry distance ≤ exit distance ≤ sensed radius; a seek
standoff plus its hysteresis must fit within its radius. Disabled incompatible
modules may remain authored for later reuse. Defaults are used when creating a
module, never to silently repair a malformed imported profile.

`seed` is an integer from 0 to 2,147,483,647. Each module gets a stable bounded
integer stream derived from profile seed, authored actor ID and module instance
ID. With `shared_seed: false`, otherwise identical actors have independent
streams. With `shared_seed: true`, actor identity is excluded from seed mixing;
identical profiles and decision inputs can intentionally share choices. Shared
seeding does not make differently situated actors follow identical trajectories.
Neither global RNG state nor UI inspection order participates. Renaming an
instance ID deliberately changes that module's stream. Reordering preserves
streams but changes the authored tie order for equal-priority overrides.

The reproducibility claim is identical core decisions for the same admitted
profile, identity and copied observation stream. It is not a claim of bit-exact
cross-platform Rapier motion. Ordinary scene persistence stores authored profile
data and actor assignment, not RNG state, timers, physical momentum or an exact
continuation checkpoint.

## Composition and the implemented vocabulary

Every module returns an active/inactive result and a short reason. Active
results provide bounded direction, pace, effort, strength and either ordinary
steering or temporary override mode. The engine evaluates modules independently
on each admitted decision, including modules whose output is currently
overridden. Required-observation and capability metadata powers the editor and
validation; rule code checks actual sensor availability before using a value.

Highest priority wins among active overrides; authored order breaks ties. An
override replaces ordinary steering while active. Without an override, the
engine blends direction × pace × weight × strength, then bounds the resulting
pace and effort. Near cancellation selects a stable dominant candidate; a prior
winner within ten percent of the best score retains the preference. This avoids
small numerical sign changes choosing a different direction each decision.
An empty or wholly inapplicable profile produces neutral intent with no borrowed
scripted/policy state. Priority, steering weight and physical effort have
different meanings and are not interchangeable speed controls.

| Module | Default priority | Implemented behaviour and release |
|---|---:|---|
| `wander` | 10 | Seeded headings, bounded interval jitter, gradual direction changes, pace/effort and intentional idle probability/duration. Ground chooses horizontal headings; supported flight chooses two axes |
| `seek_material` | 30 | Approach nearest observed matching material, stop at standoff, dwell once for a finite duration, then release to other steering. Hysteresis prevents immediate re-entry; observed target loss starts reacquisition cooldown |
| `avoid_material` | 80 | Urgent override acquired at entry distance, retained through the exit band, released when observed absent or beyond exit distance. Coincident material gets a stable compatible escape side. No physical immunity |
| `avoid_ledge` | 100 | Actual grounded support loss ahead starts a fixed retreat, default ten simulation seconds. Direction is latched once; repeat danger never renews that timer. After expiry, both sides must remain supported/safe continuously for the rearm interval |
| `avoid_boundary` | 90 | Temporary inward retreat at canvas/region margin, with combined corner axes for flight. Reacquires only after the release margin; a region too narrow to give a consistent direction reports that limitation |
| `escape_obstruction` | 85 | Requested motion plus measured lack of progress and real local obstacle evidence must persist through debounce. Reverses for a bounded duration, then cools down. Optional jump is one admitted primary pulse on a compatible grounded rig |
| `return_home` | 40 | Ordinary steering activates outside home radius and releases inside a smaller radius. It combines with material preferences and wander |
| `rest` | 60 | Seeded active intervals alternate with finite neutral overrides. Higher-priority urgent reflexes can interrupt selection while its timer still progresses |
| `follow_actor` | 25 | Nearest copied compatible actor, bounded radius, comfortable separation and hysteresis band; exact distance ties use stable actor identity |
| `avoid_crowding` | 35 | Gentle weighted repulsion from compatible copied neighbors; coincident actor IDs choose consistent opposite horizontal sides |
| `maintain_altitude` | 25 | Home-relative y correction outside a tolerance band, admitted only on a legitimate two-axis adapter |

These are typed rules with explicit parameters, not an expression language or
arbitrary script evaluator. For example, a material directly above a ground
actor does not imply a route upward. A higher-priority Water avoidance can win
over Oil attraction while both candidate explanations remain visible. Rest and
material dwell affect selected intent; a body can continue moving under inertia
or external forces while its selected intention is neutral.

The six supplied personalities—Oil Moth, Shy Crawler, Curious Surveyor, Idle
Mechanic, Drifting Flyer and Social Roamer—reuse this vocabulary. Names confer
no new biological, locomotion or equipment capability. Ground and flight
presets differ where their actual affordances require it.

## Simulation time, cadence and lifecycle

The ordinary controller cadence remains 1–12 physical ticks, default six. The
session's ambient clock advances from the actual completed Rapier manual-step
count multiplied by the bridge's fixed step, not a caller's requested delta or
elapsed wall time. The adapter passes the difference since its last valid
decision and the explicit `simulation_time_seconds` to the engine. Their
agreement is checked. The first decision starts at elapsed zero.

Persistent deadlines expire against this completed simulation clock. Repeated
samples of the same tick cannot advance it, redraw random choices or consume
transitions. A long missed-decision interval can expire a retreat, but cannot
prove uninterrupted support or obstruction: gaps above 0.25 seconds reset that
continuity inference. Random choices and periodic rest are evaluated once on
the next admitted decision, without an unbounded catch-up loop.

| Event | Private behaviour state and physical ownership |
|---|---|
| Inspect/select/overlay | Read-only copies; no pilot change, reset, RNG draw or new probe |
| Pause/resume | Existing command cancellation and fresh generation/observation; ambient timers/RNG persist. Wall-clock pause consumes no gameplay duration |
| Single step | One actual completed physics step advances time; no claim that a requested but uncompleted step consumed a duration |
| Human takeover and handback | Existing takeover retires old command authority; physical body, momentum and resource state remain. Returning to ambient starts fresh module state at the current pose, with the authored home unchanged |
| Apply profile/disable/change producer | Valid transaction resets ephemeral behaviour. Invalid configuration preserves the previous producer and profile |
| Delete/replace/reset/new world/lease fault | Existing owner retirement applies; no old command or module state crosses into the new actor incarnation |
| Save/reopen | Exact admitted authored profile and assignment are retained. Private intentions and RNG restart; ordinary saves do not promise exact physical continuation |

The editor stages edits separately from runtime. Apply checks actor definition,
session run/epoch and baseline profile before invoking the existing owner
transaction. A replaced world reusing the same actor ID cannot accept a stale
draft; Revert explicitly binds to the current actor. Pause alone does not make
a draft stale. Group application is not implemented; assignment is deliberately
per actor in this candidate.

## Capability-aware actuation

The adapter eligibility rule is source-backed: ordinary articulated physical
profiles with movement family `ground`, `walk` or `roll`, without a separate
player controller, plus the four existing 4LY assisted-flight rigs. An eligible
rig keeps its own collisions, resource costs, propulsion, braking and action
normalization. Unsupported combinations are refused with a reason.

| Adapter | Actions and actual limits |
|---|---|
| Ground/walk | Horizontal desired motion with existing local velocity and attitude feedback; outputs supported `move`, `aim`, `effort`, `trim`, and optional ordinary `primary` jump. Vertical desire gives no vertical motor |
| Roll/wheel | Horizontal movement through the existing rolling mechanism and bounded trim feedback. A wheel's unrelated primary ability is not treated as jump |
| 4LY Trainer/Hauler/Drifter/Dart | Exactly one `move` key in world-frame desired velocity; pace scales the request. The existing controller owns hover, braking, gravity compensation and thrust/attitude. Its API has no separate effort channel; the editor disables Effort for these rigs while retaining the authored value for compatible profiles |
| Other rigs | Existing fleet flyers, other legacy flight/hover mechanisms, SetP player controllers and passive bodies have no ambient adapter in this candidate |

No adapter fires equipment, teleports a body, sets its velocity directly or
retunes its motor to improve a demonstration. Material distance is not a
passability map. A legitimate intention may be blocked by geometry or exhausted
resources; diagnostics distinguish intention from measured physical travel.

The independent matched native-material/physical fixture covers Runner,
Monowheel and 4LY Trainer. Other compatible models have capability admission
and available scene coverage as recorded in the mission ledger; they do not
inherit those three models' measured travel results.

## Adding a module through the same interface

Add a bounded type to `module_specs()`, dispatch it from `evaluate()`, and
implement a pure function over copied observation, private state and context.
The schema and editor obtain parameter fields, ranges, units and descriptions
from that metadata. A pure module using existing observations needs no special
case in the session owner or actuator.

For example, the following **illustrative, unimplemented** `stay_right_of_home`
rule would add a simple ordinary preference while the actor is too far left:

```gdscript
# Inside module_specs(), create metadata using the existing helpers:
var right_of_home := _motion(0.3, 0.6)
right_of_home["offset"] = _number(12.0, 0.0, 96.0, "cells", "Desired x beyond home.")
# Add to the returned catalogue:
"stay_right_of_home": _spec("Stay right of home", "Local horizontal preference.",
    20, 1.0, ["pose", "home"], ["horizontal"], right_of_home)

# Add one evaluate() dispatch arm, then a private pure implementation:
static func _stay_right(p: Dictionary, o: Dictionary, c: Dictionary) -> Dictionary:
    var home: Variant = c.get("home")
    if not home is Vector2 or not home.is_finite():
        return _inactive("authored home unavailable")
    if o.position.x >= home.x + float(p.offset):
        return _inactive("right-of-home preference satisfied")
    return _intent(Vector2.RIGHT, p, "moving toward preferred side of home")
```

Test the new type through `Profile.make_module()` and an engine configured with
explicit capabilities. Check both sides of its boundary, unavailable required
data, invalid numeric parameters, interaction with a higher-priority override,
and read-only diagnostics. If it needs randomness, use `random_unit(state)`;
if it persists an intention, define trigger, duration, release and rearm rules
and test pause/gaps. Do not call global randomness, system clocks, scene lookup,
material reads or body APIs from a rule. A new sensor requirement must first add
a separately bounded owner-mediated copied contract and evidence; a metadata
name alone does not create a sensor.

## Qualification and remaining scope

The [behaviour ledger](../research/ambient-001/behaviour-ledger.md) records exact
local source hashes, engine tests, clock tests and independent review findings.
The focused test inventory separates pure decisions, copied perception, actual
native/physical progression, ordinary Workbench lifecycle and editor persistence:

- [`test_ambient_engine.gd`](../../godot/tests/test_ambient_engine.gd): all eleven
  rules, arbitration, identity, thresholds, timer/rearm, seed independence and
  observational purity, with a bounded pure-decision benchmark.
- [`test_ambient_independent.gd`](../../godot/tests/test_ambient_independent.gd):
  independently authored perception→engine→actuator value-path regressions.
- [`test_ambient_clock.gd`](../../godot/tests/test_ambient_clock.gd): actual Rapier
  completion counting, pause, fresh authority, handback and invalid edits.
- [`test_ambient_perception.gd`](../../godot/tests/test_ambient_perception.gd) and
  [`test_ambient_native_motion.gd`](../../godot/tests/test_ambient_native_motion.gd):
  publication/geometry limits and source-matched native-material physical trials.
- [`test_ambient_authoring.gd`](../../godot/tests/test_ambient_authoring.gd): schema,
  profile persistence and genuine native/actor example data.

The mission ledger adds ordinary host and interactive evidence and the current
Windows delivery disposition. Synthetic decision outputs are not physical
motion; headless Linux/Rapier observations are not Windows/NVIDIA playfeel
acceptance. Human assessment of whether a scene feels inhabited remains separate
from automated correctness.

This implementation does not provide global route finding, terrain traversal
guarantees, resource-aware planning, arbitrary condition scripting, learned
policies, exact simulation saves or large-population host expansion. Its useful
scope is composable local preferences and finite intentions acting through real
existing physical mechanisms in editable material environments.
