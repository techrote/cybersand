---
title: Living procedural inhabitants
status: Current
document-kind: contract
scope: AMBIENT-002 Draft/HOLD successor profile, memory, social perception and transactional authoring contracts; qualification is separately source-bound
canonical-for: [ambient-stateful-intelligence, ambient-profile-v2, ambient-population-authoring]
last-reviewed: 2026-11-25
related-documents: [ambient-actors.md, ../operations/ambient-living-workbench.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/interfaces-and-message-contracts.md, ../research/ambient-002/mission-ledger.md]
---

# Living procedural inhabitants

AMBIENT-002 is an opt-in **Draft/HOLD successor** to the qualified AMBIENT-001
foundation. It preserves the original version-1 profile vocabulary and physical
command contract while adding explicit version-2 configuration. Source exists
on the successor branch; [the mission ledger](../research/ambient-002/mission-ledger.md)
separately records actual execution, unresolved failures and delivery identity.
Neither this contract nor a passing pure-policy fixture establishes owner
Windows/NVIDIA playfeel or a generally successful route planner.

The [version-1 contract](ambient-actors.md) retains its original modules, material
sampling semantics, adapters, example identities and qualified evaluator. New
profiles are ordinary editable combinations of shared rules. No personality
instantiates a unique actor controller, model service or training loop.

## Authority and lifetime

The existing physical actor session is the only control authority. The decision
engine receives copied values and returns normalized intentions through the
existing actuator and issued-command admission path. Native material ownership,
Rapier stepping, movement motors and equipment laws remain with their physical owners. The ordinary Workbench defaults to eight logical actors. Its optional sandbox capacity may admit larger physical rosters. Each scene still admits at most eight assigned AMBIENT controllers, including paused and temporarily piloted inhabitants. The physical owner copies at most 32 peer candidates per decision tick, rotating through larger rosters. The nearest seven admitted peers reach the policy; partial coverage is explicit. Authored load, single handoff and atomic group assignment enforce the same policy budget.

World generation is captured from a valid immutable owner snapshot even when a
profile requests no material sensing. The copied generation must be nonnegative,
match the physical epoch, and come from a nonregressing snapshot serial. Missing
generation is unavailable knowledge, not a new World. Session replacement and
close clear that identity and copied peers. The stateful engine additionally
binds private knowledge to its actor/run/epoch and invalidates World-specific
memory on generation change.

Authored configuration is separate from ephemeral simulation state. Profiles,
regions, relationship tags and assignments survive authored Save/Reopen. Private
visited cells, remembered material targets, failed approaches, goals, timers,
drives and seeded random streams restart. A scene save is not an exact physical
continuation or a cross-platform deterministic replay.

## Composition and finite intentions

One profile contains at most 16 module instances selected from a catalogue of
29 types. Each instance has its own stable ID, enabled flag, priority, weight,
parameters and private seeded stream. Disabled and zero-weight modules do not
evaluate or request optional material/terrain sensing. The editor uses the same
schema as validation and runtime admission; unknown fields, nonfinite values,
unsupported capabilities and invalid parameter relations are refused.

The eleven original rules remain `wander`, `seek_material`, `avoid_material`,
`avoid_ledge`, `avoid_boundary`, `escape_obstruction`, `return_home`, `rest`,
`follow_actor`, `avoid_crowding` and `maintain_altitude`. The version-1 contract
defines their unchanged authored vocabulary. Eighteen version-2 primitives add
the following distinct mechanisms:

| Module | Mechanism and observable consequence |
| --- | --- |
| `investigate_material` | Latches a newly observed material patch, approaches, inspects briefly, then releases interest. Retained exposure reduces later novelty. |
| `explore_unfamiliar` | Chooses a nearby destination using remembered visits and failed approaches; exploration drive and curiosity affect utility. |
| `revisit_interest` | Returns to an old remembered material observation after a minimum age. The historical location is not a claim that the material remains there. |
| `patrol_route` | Advances through 2–16 home-relative waypoints with arrival dwell, finite leg deadlines and optional looping. Unreachable legs can expire. |
| `prefer_region` | Makes finite attempts to enter an authored home or activity region; territoriality changes its utility. |
| `avoid_region` | Selects the nearest supported exit direction while inside an authored avoidance region and its margin. |
| `search_last_seen` | Searches bounded offsets after an available query no longer observes a previously seen material. Unavailable or incomplete coverage does not prove that the material was destroyed. |
| `exploration_destination` | Chooses and pursues a finite seeded destination, rather than continually changing heading. It does not require visited-space novelty. |
| `withdraw_obstruction` | Uses accumulated, contact-supported failure records to retreat, pause and cool down after repeated unsuccessful approaches. |
| `rest_resource` | Requests neutral input when an actual normalized rig-energy observation crosses its threshold, releasing on recovery or timeout. It does not create an invented fatigue resource. |
| `seek_home_drive` | Starts a finite homeward journey when exploration drive declines, then requests a bounded home rest. |
| `observe_actor` | Temporarily approaches an admitted copied peer, watches from a preferred distance and releases attention. |
| `regroup` | Approaches the local centroid of admitted compatible peers when separated beyond preferred spacing. |
| `align_peers` | Adds a weak heading preference from observed moving-peer velocities. |
| `disperse` | Converts a sufficiently dense local congregation into a finite outward intention and cooldown. |
| `follow_material_boundary` | Uses a sampled material edge's local tangent plus standoff correction. It does not infer a continuous remote boundary. |
| `steer_obstacles` | Chooses an observed clearer supported direction, penalizes remembered failures and briefly retains the alternative heading. |
| `avoid_peer` | Uses authored dislike tags and entry/release hysteresis to move away from an observed peer. |

Arbitration has three layers. Active overrides choose the highest authored
priority, with list order breaking an exact tie. Otherwise one temporary goal
wins by `weight × utility`; priority breaks equal utility, then list order.
An existing goal retains a finite commitment when its utility multiplied by
`1.25 + 0.75 × persistence` still matches the challenger. Its commitment duration
is `commit_seconds × (0.5 + persistence)`, clamped to 0.05–45 seconds and renewed
only when the goal identity changes. This permits a much stronger interest or
reflex to interrupt without making ordinary preferences chatter every decision.

The selected goal contributes 2.5 times its utility-weighted steering alongside
continuous preferences. An inspection/rest phase may instead request neutral
input; reflex overrides still take precedence. Close vector cancellation uses a
stable dominant preference rather than numerical sign noise. Every active
candidate remains visible in diagnostics, including reasons for inactivity.
Candidate deadlines are simulation-time opportunities: eligibility is not proof
that the actor executed that goal, reached a waypoint or remained physically
still. Scientific intention occupancy counts the selected result, not all active
candidates. Only valid intervals credited to the previously selected module,
goal key and phase advance dwell. Suppressed or unsupported time adds none;
partial credited dwell may resume before the finite deadline. Interrupted
inspection does not accumulate contact or patrol/rest dwell in the background. An absolute
opportunity deadline still releases interrupted work, so low-priority candidates
cannot wait indefinitely and stale interests cannot sustain a permanent hold.

All time advances from admitted, completed physical progression. Repeated
inspection or a duplicate sampling tick cannot draw randomness or consume time.
A missed interval over 0.25 seconds ages deadlines but cannot establish
continuous contact or dwelling. Seeded variation is deterministic for the same
validated profile, authored actor identity and copied observation sequence.
Rapier outcomes are not claimed bit-identical across platforms.

## Personality, drives and memory

Traits affect explicit shared mechanisms; a personality has no unique controller.
The six predecessor profiles remain version 1 until an explicit copied upgrade.
Version-2 trait settings are independent and can be switched to their neutral
defaults for a matched ablation.

| Setting | Range | Mechanism |
| --- | --- | --- |
| Curiosity | 0–1 | Raises novel material and unfamiliar-destination utility. Retained habituation still reduces novelty. |
| Persistence | 0–1 | Scales approach deadlines and goal commitment, and strengthens remembered-target/search preference. |
| Caution | 0–1 | Scales material avoidance entry distance and required local obstacle clearance. It grants no immunity or extra observation. |
| Sociability | 0–1 | Scales peer observation, regrouping, alignment and legacy-follow utility, plus social-drive accumulation. |
| Activity | 0–1 | Scales non-reflex pace by 0.6–1.4, clamped to the legal actuator range; changes wander idle probability and exploration-drive depletion. |
| Territoriality | 0–1 | Raises authored-region utility and the exploration-drive threshold that initiates a homeward attempt. |
| Preferred distance | 4–64 cells | Sets a comfort distance for observation and regrouping, bounded by each module's sensing radius. |
| Failed-attempt tolerance | 1–10 | Sets the remembered obstruction-attempt count required by `withdraw_obstruction`. |

Exploration drive starts at 0.85 and social drive at 0.45. Both remain in [0, 1].
Exploration recovers by 0.09 per simulated second while near home with a restful
intention; otherwise it declines at `0.006 + 0.018 × activity` per second of
observed movement, or 35% of that rate without observed movement. During an
actually selected `seek_home_drive` / `home_rest` interval, the current copied
position must lie within that exact enabled, positive-weight instance's validated
`arrival_radius`. Other neutral or restful behavior keeps its existing 16-cell
recharge radius. An inactive, overridden, disabled or zero-weight home candidate
cannot enlarge another intention's recharge region. Ground/wheel containment
uses horizontal distance and flight uses Euclidean distance. Integration uses
the prior admitted intention and current position; it is a bounded procedural
preference, not proof of uninterrupted occupancy across missing observations.

Social drive
declines by 0.06 per second near an admitted compatible peer and accumulates by
`0.005 + 0.01 × sociability` per second otherwise. These are procedural drives,
separate from actual rig energy. Disabling drives fixes them at exploration 0.65
and social 0.5. No new physical resource or physics law is introduced.

The spatial memory holds 8–128 visited grid cells, 1–32 material interests and
1–32 failed approaches, independently bounded. Grid width is 8–96 native cells;
observation lifetime is 5–600 simulation seconds. Obstruction records expire no
later than 30 seconds. The least recently seen record is evicted at capacity,
with stable key ordering for timestamp ties. Records expose their identity,
capacity, admissions, reentries, failures, evictions and expiry counts.

A failed approach requires requested movement, less than one cell/second of
actual progress along that request, and observed nearby physical contact.
Continuous evidence must last at least 0.8 seconds, with at least one second
between recorded failures. Neutral intentions, gait alone and unobserved contact
do not establish obstruction. Memories of moving or vanished material patches
are historical observations and age out; nearest-sample sensing cannot prove
the continued contents of every remembered point.

Disabling spatial memory removes visited-space, material-interest and obstruction
learning/use. It does not remove finite module latches, patrol phase, cooldowns
or last-seen search state. Reports must name that ablation precisely. Every
ephemeral component is reset by an admitted new World identity, explicit profile
Apply, actor/session replacement or restart; none is serialized as authored data.

## Budgeted local perception

Version 1 retains the four-cell material lattice. Version 2 explicitly configures
requested coarse spacing, a small exact near-field disk and optional boundary
refinement. Sensing reads copied native material IDs, including the publication's
native ballistic projection. It never classifies framebuffer colours.

The adaptive query admits at most **4,096 unique cell reads**, at most eight
requested material IDs, and radius at most 96 world cells. Near-field radius is
0–16 cells and requested spacing is 1–4 cells. If a requested resolution does not
fit, the query reports the coarser effective spacing and incomplete coverage.
Refinement improves an already observed target; it cannot guarantee discovery
of every remote thin patch. Fresh, stale, unavailable, observed absence and
unobserved material in incomplete coverage remain distinct.

Navigation is a separate owner-mediated observation: two horizontal terrain
rays for ground/wheel actors or eight radial rays for flight, with at most 32
cells beyond the attached hull. A ray clipped by the canvas without a terrain
hit is unknown. These center-line samples are useful local evidence, not a
swept-volume collision certificate or global reachability result. There is no
teleportation or direct position/velocity mutation.

The owner copies eligible peer poses, velocities, capabilities and authored
affinity tags once per physical tick. The accepted eight-actor host bounds that
copy. The pure adapter has an explicit future seam admitting at most 32 supplied
candidate observations and retaining the nearest seven, with deterministic
distance/identity ordering and incomplete coverage reporting. Raising that seam
does not instantiate additional bodies or authorize a host-capacity change.
Private peer goals, drives and memories are not shared.

Avoid tags take precedence over preferred tags; untagged peers remain neutral.
For version-2 follow, observe, regroup and alignment, positively affiliated peers
are preferred whenever present; neutral peers remain a fallback. An explicit
peer identifier narrows targeted social modules, while personal space, crowd
dispersal and hostile-peer avoidance retain their local safety/crowd scope.
Version-1 follow keeps its original nearest-compatible-peer semantics.
Locomotion compatibility continues to separate flight from ground/wheel groups.
Every peer observation must match the current run, epoch and physical tick.

## Transactional authoring

The existing Behaviour profile window provides staged editing. Version-2 places
belong to their profile and use native cell coordinates. They are semantic home,
interest or avoidance regions; drawing a region does not edit native terrain or
grant traversability. The scene-local profile library is optional authored data
under `ambient_authoring: {version: 1, profiles: [...]}` and is bounded to 32
strictly validated profiles.

Selecting a library entry stages a copy. Applying it to an actor creates an
individual authored override. Editing or deleting the library entry does not
silently alter existing assignments. The ordinary authored file-size budget
still applies to the complete scene and its library.

Group Apply captures the current run, epoch and selected actor model, definition
hash and complete authored control configuration. The host preflights every
member, its capability and the full candidate save before asking the physical
session to commit. The session independently checks current configurations and
prepares every replacement adapter before revoking any producer. Cancellation
notices are emitted after all new controls are visible. A stale, disappeared,
duplicated or incompatible member refuses the whole group. A successful group
handoff retains actual bodies, poses and resources and restarts private policy
state, just as an explicit individual Apply does.

## Evidence and interpretation

The scoped iteration runner is a development tool, not a final evaluator gate.
The final qualifier must bind source, original project inputs, native/Rapier
libraries, official engine, process completion and extracted package execution.
The [predecessor](ambient-actors.md) remains independently inspectable.

Real displacement, visited area and successful arrival are separate quantities.
Gait and vertical bobbing are not exploration. Neutral commands can permit drift;
intentional rest is not proof of a physically motionless actor. A selected goal
is an intention rather than evidence that a destination was reached. Physical
episodes and negative outcomes belong in the mission's scientific packet.

Adaptive sensing trades additional CPU time for local coverage. Its fixed bound
does not imply zero overhead or an eight-actor FPS guarantee. Measure perception,
decision, native progression and graphical presentation separately on the actual
qualified host before making a performance claim.
