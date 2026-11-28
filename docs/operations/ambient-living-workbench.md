---
title: Living inhabitants in the Workbench
status: Current
document-kind: guide
scope: AMBIENT-002 candidate authoring, reusable profiles and native environments; runtime qualification is recorded separately
canonical-for: [ambient-living-owner-controls]
last-reviewed: 2026-11-25
related-documents: [ambient-workbench.md, ../systems/ambient-actors.md, ../research/ambient-002/authoring-ledger.md]
---

# Living inhabitants in the Workbench

AMBIENT-002 is an opt-in **Draft/HOLD** successor to the original procedural actor
experiment. It adds authored personalities, temporary intentions, bounded memory,
relationships and reusable profiles to the ordinary Workbench. The blank start
and unrelated controllers keep their existing defaults.

The [AMBIENT-001 walkthrough](ambient-workbench.md) remains useful for placing
actors, human pilot handoff, native materials and the original five examples.
This page describes the additional controls and six living environments. Source
describes available controls; the [authoring ledger](../research/ambient-002/authoring-ledger.md)
identifies what has actually been executed and what remains unqualified.

## Open a living environment

Extract the complete portable evaluator ZIP into a writable folder. Start
**Open Workbench.cmd**, allow its first import to complete, and open
**Configuration…**. On the **Actors** tab, choose a living environment under **Ambient examples**, select **Load scene**, wait
for acknowledged native and actor replacement, then press **Play**.

Every platform, wall, fluid pocket and obstacle is native editable material.
Every inhabitant is an existing Runner, Crawler, Monowheel or 4LY rig. They use
the ordinary simulation, physical session and real actuators. The example loader
supplies a construction recipe; it does not run another simulation or script a story.

| Environment | Native extent | Inhabitants | What to watch or change |
| --- | --- | --- | --- |
| Foundry Row | 1280 × 640 | 8 | A service street, individual homes, common places and contrasting scavenger, patrol, social and territorial profiles. |
| Pipe Orchard | 1280 × 640 | 6 | Real Oil/Water basins, low obstructions and a sealed Oil cabinet beside a scavenger. Inspect whether an unsuccessful approach gives way to another interest. |
| Echo Galleries | 1280 × 768 | 6 | Rock chambers, dead ends and aerial alternatives. Ground and flying inhabitants face different physical routes. |
| Common Ground | 1024 × 640 | 8 | Two affinity groups, personal homes and a common square. Compare congregation, personal space and withdrawal. |
| Rain Exchange | 1280 × 640 | 6 | Real Water drains from an overhead tank and changes the yard. Paint or erase a gate and inspect changing observations. |
| Lantern Hangar | 1536 × 768 | 6 | Independent 4LY inhabitants explore suspended gardens, open bays and docking homes. |

The eight-inhabitant host limit remains authoritative. These scenes do not
import the separate capacity candidate or substitute abstract agents for
physical actors. Larger canvases extend beyond one camera view; use ordinary
Workbench pan and zoom to inspect them.

## Edit an inhabitant

Inspect a supported actor and open **Behaviour profile**. The window binds to
that actor's definition and current World/session identity. Selecting a different
actor in the Workbench does not retarget an unfinished draft.

The name, ID, seed and description are authored configuration. **Duplicate to
customize** stages an independent copy. Unless **Share identical seed across
actors** is enabled, the seed is mixed with the authored actor identity. Equal
seeds give repeatable procedural choices for equal copied inputs; they do not
promise bit-identical Rapier trajectories between platforms.

**Apply profile to this actor** validates the full configuration and requests an
acknowledged controller change. Old private intentions and memory retire with
the old controller. **Revert staged edits** reads the admitted profile without
changing the actor. A stale World, replaced actor or newer external edit refuses
Apply and requires an explicit Revert.

Apply while Play advances to audition a profile. Saving the Workbench scene is
a separate action: it retains authored configuration, not a continuation of
the inhabitant's private live mind.

## Modules and semantic parameters

The **Modules** tab contains the profile's ordered modules and a searchable
catalogue. Search labels, descriptions, requirements or stable module IDs.
Clearing search restores the catalogue.

Each module displays its purpose, copied observation requirements, locomotion
requirements, parameter units and ranges. Material selection uses the actual
compiled catalogue; it never infers a material from rendered colour.

Add, remove, enable, disable and reorder modules in the draft. Continuous
preferences combine through weights; interrupting or committed decisions use
documented priorities and tie order. Zero weight removes a contribution.
Disabled incompatible modules can remain authored, while enabled modules must
match the selected rig's capabilities.

Region pickers show authored places and a first-applicable-region option.
A missing explicit ID stays visibly missing. Patrol waypoints have a coordinate
table, with offsets relative to home. Routes steer ordinary actuators and do
not guarantee traversability through native obstacles.

## Personality, drives and memory

**Personality** exposes traits through metadata shared with the policy schema.
Descriptions explain the affected mechanism: curiosity, persistence, caution,
sociability, activity, territoriality, preferred distance and failure tolerance.

An original version-1 profile stays unchanged until **Enable living settings in
this draft** is chosen. This explicit copied upgrade adds version-2 settings
without silently editing the six predecessor personalities.

Memory controls bound visited tiles, remembered interests and failed approaches,
their tile size and lifetime. Memory uses physical simulation time. Pausing,
opening the inspector or changing rendering pace does not intentionally age it.
A replacement World, Reset or newly reopened scene starts with fresh knowledge.

Memory, personality and drives each have an enable switch. For a matched audition,
duplicate a profile, change one switch, preserve placement and seed, Reset the
same authored scene and compare physical trajectories. One visual difference is
an observation, not proof of a universal improvement.

Perception controls request spacing and bounded near-field refinement. The owner
may coarsen requested resolution to stay within its sample budget. Read actual
coverage before interpreting a missing material. Stale, unavailable or incomplete
information is different from evidence that material is absent.

## Places and relationships

**Places and peers** authors native-cell rectangles for home, interesting areas
and avoided areas. Each has a stable ID, name, position and size. A profile holds
at most twelve places and one home. Add buttons begin near the inspected actor's
authored spawn; edit the rectangle to suit the scene.

These places express preferences. They do not create invisible walls, teleport
actors, add material or provide global navigation. Moving a reusable profile to
a different scene may require adjusting its coordinates.

Tags describe affinities. Preferred tags favour compatible peers, with neutral
peers as a fallback; avoided tags exclude peers from ordinary approach modules
and can drive explicit avoidance. These rules use actual copied peer observations. An optional peer ID focuses relevant modules on that observed
inhabitant; it does not provide hidden access to absent actors. Peer-directed
goals release when their target is no longer admitted; other modules resume.
The material search module searches around a remembered material observation.

## Shared profiles and group assignment

**Library and group** holds up to thirty-two reusable scene profiles.
**Store this draft** validates and stores a new ID or replaces the same ID.
Choosing an entry stages a copy. Removing an entry does not change actors already
using copied values.

Use Ctrl or Shift to select inhabitants and choose **Apply draft to selected
group**. The host validates all selected definitions, capabilities and copied
control identities before changing any. A missing member, stale World,
incompatible module or independently changed control refuses the entire group.

Successful assignment creates independent editable overrides. Later edits to
one actor or the library do not propagate implicitly. **Refresh group and
library** explicitly reads current identities after another authoring action.

Normal **Save/Reopen** retains the library, profile copies, regions, relationships,
module ordering and seeds. It omits private visited memory, current intentions,
drive accumulators, observation caches, RNG continuation, command leases and
physical replay state.

## Inspect decisions and physical motion

The inspector shows current intent, accepted direction, pace, policy/sensor cost
and copied observation coverage. Module explanations separate an inactive
condition from an active proposal that lost arbitration. Optional overlays draw
copied intent, observations, authored places and bounded memory. Inspection
issues no new observation or actuator command.

Intentional inactivity is not guaranteed physical stillness. Ground rigs can
continue moving through inertia, gait or contact, and neutral flight can actively
hover. Repeated motion commands with little copied displacement may indicate
obstruction. Compare position, intention, remembered failures and progression.

## Personality catalogue

These are ordinary editable compositions in the
[shared profile catalogue](../../godot/data/ambient/profiles.json). The rows
describe configured mechanisms. Compare their actual motion and decision history
under matched placement, materials and seeds; contact and observation changes
can interrupt any routine. The original six keep their version-1 behaviour until
explicitly upgraded in a draft.

| Personality | Configured tendency | Useful observation or edit |
| --- | --- | --- |
| **Oil Moth** · original | Ground wandering with attraction to observed Oil; Water and actual ledges can interrupt it. | Move an Oil patch inside and outside its fifty-cell scope. The name does not give the rig flight. |
| **Shy Crawler** · original | Slow ground movement, early Water retreat and a latched ten-second ledge retreat. | Compare one committed retreat with an actor that rapidly changes direction. |
| **Curious Surveyor** · original | More active wandering, Oil attraction, short timed rests and a home radius. | Use this preserved profile as a comparison for the new memory-based explorer. |
| **Idle Mechanic** · original | Short activity bouts, longer timed rests, local return and modest peer spacing. | Separate intended rest from a blocked command and residual physical movement. |
| **Drifting Flyer** · original | Two-axis seeded drift with home-relative altitude, boundary retreat and crowd spacing. | Compare it with Cautious Flyer in the same open bay. |
| **Social Roamer** · original | Approaches compatible copied peers while keeping a gap; otherwise wanders locally. | Contrast its simple following with the newer regroup, observation and dispersal sequence. |
| **Restless Explorer** | High curiosity selects unfamiliar local tiles and new Oil interests. Activity depletes its exploration drive and makes homeward periods relevant. | Turn memory off in a duplicate and compare revisits, stalled approaches and homeward intentions. |
| **Territorial Watcher** | Strong home/region preference, finite peer observation and retreat from disliked tags. | Assign a home and a nearby interest region, then change the tags of an observed visitor. |
| **Social Drifter** | High sociability supports peer observation, regrouping, alignment with copied movement and finite dispersal. | Start compatible peers within observation range and inspect when they attract, separate or lose sight of one another. |
| **Timid Follower** | High caution, broad preferred spacing and low activity moderate following; Water and disliked peers encourage withdrawal. | Assign a visible peer ID, then remove that actor or move it outside the copied observation scope. |
| **Persistent Scavenger** | Oil investigation, bounded remembered interests, delayed revisits and material search; higher failure tolerance permits longer attempts before withdrawal. | Inspect the sealed Oil cabinet in Pipe Orchard and compare a lower failure tolerance. |
| **Routine Patrol** | Four editable home-relative waypoints, dwell periods and finite failed-leg timeouts create a repeatable route intention. | Move a waypoint behind a real wall and inspect whether the leg times out. The route is not a pathfinding guarantee. |
| **Independent Wanderer** | Finite seeded exploration destinations with personal space and little social attraction; occasional drive-based homeward goals. | Compare its destination commitments with the original continuously wandering profiles. |
| **Cautious Flyer** | Slow two-axis unfamiliar-space exploration, Oil investigation, sampled clearance, homeward cycles and eligible resource-based rest. | Inspect the eight-direction clearance fan near a dock; distinguish supported resource observations from absent ones. |
| **Boundary Grazer** | Follows the tangent of an actually sampled Oil edge, remembers patches and sometimes selects a separate excursion. | Reshape or drain an Oil pocket and inspect whether boundary observations and remembered interests expire. |
| **Homebody Keeper** | Low activity, short excursions and finite homeward intervals; editable region preferences can define a workplace. | Move the home and interest rectangles independently and compare where it tries to spend time. |

## Qualification and limits

The successor runner retains predecessor coverage and adds living schema,
Save/Reopen, the mounted editor, group transactions, spatial perception and all
six new native scenes. A graphical pass covers original and new scenes with
actual native and physical progression. The Windows package builder requires
actual Windows qualification; the release workflow independently extracts and
executes the shipped project and launcher.

Source, original process receipts, native provenance, image identities and
package hashes are separate evidence. Hosted qualification does not establish
the owner's physical NVIDIA playfeel or whether each personality is entertaining.
Observe sustained episodes and retain failed approaches and surprising outcomes.
Richer decision traces alone do not prove better embodied exploration.

This system provides bounded local awareness and recovery. It does not promise
global pathfinding, semantic architectural understanding, resource economies,
exact simulation replay or populations above the authoritative physical limit.
