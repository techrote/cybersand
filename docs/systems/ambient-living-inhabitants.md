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
Rapier stepping, movement motors, equipment laws and the accepted capacity of
**eight logical actors** remain unchanged. Unaccepted capacity PR #762 is not a
dependency.

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
