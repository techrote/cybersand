---
title: Procedural ambient actors in Shared Workbench
status: Current
document-kind: guide
scope: Opt-in AMBIENT-001 Draft/HOLD profile authoring, ordinary play, presets, examples and current limits
canonical-for: [ambient-workbench-owner-guide]
last-reviewed: 2026-11-24
related-documents: [../systems/workbench-actor-composition.md, ../systems/physical-actor-rigs.md, ../research/ambient-001/authoring-ledger.md, ../research/ambient-001/mission-ledger.md]
---

# Procedural ambient actors in Shared Workbench

**Procedural NPC / Ambient** is an opt-in controller for supported existing
physical actors. Give an actor a profile assembled from simple modules, then let
its own observations, timers and seeded preferences choose ordinary movement
commands. The actor still uses the existing physical rig, collisions and
resources. A preference to approach Oil is an intention; a wall, slope, depleted
resource or unsuitable rig can prevent travel.

AMBIENT-001 is a Draft/HOLD candidate pending owner acceptance. It does not
change the default controller of ordinary scenes. The existing Human, Scripted,
External Policy and Passive choices remain available. The accepted Workbench
capacity is eight logical actors; the examples do not rely on an unaccepted
larger population host.

## Start with an inhabited scene

Open **Shared Workbench**, then **Configuration…**. On the **Actors** tab, under **Ambient
examples**, choose a scene and press **Load scene**. The normal native and
physical owners prepare it before the Workbench acknowledges the replacement.
Press **Play / Pause [P]** to begin. All architecture, fluid and actors in these
examples are actual editable gameplay data.

| Scene | What to try |
| --- | --- |
| **Oil / Water preference garden** | Three different ground and wheel rigs start near Oil and Water basins. Paint more Oil on the other side of an actor, or Water near its current route, and watch its preference change when the sensor observes it. |
| **Ten-second retreat walkway** | Two ground actors roam a broken raised gantry. Inspect Shy Crawler's ledge rule to distinguish a physical drop from a wall or the outer canvas boundary. |
| **Living industrial yard** | Four ground inhabitants and one flyer share an industrial space with real draining material and editable obstacles. Change a route or add nearby material while they continue. |
| **Eight-inhabitant settlement** | Eight actors use six personalities across ground, wheeled and flight families. Compare their activity, rests and social spacing. |
| **Flight exploration hangar** | Two existing 4LY flight rigs use altitude, loose home return, separation and boundary steering in an open hangar. |

The examples are 1024 by 512 world cells. They are also readable ordinary
Workbench starts under `godot/examples/workbench/ambient-*.json`. Their recipe
source is `godot/scripts/ambient/ambient_examples.gd`.

## Build and assign a profile

In **Configuration…**, select an actor under **Actors → Inspect**. On the **Controllers** tab, open
**Behaviour profile…**. Inspecting an actor does not pilot it. The profile window
stays bound to the actor for which it opened even if another actor is selected
elsewhere.

Choose a preset and use **Duplicate to customize**. Give the profile a name,
description and seed. Select a module to edit its parameters. The module list
supports **Add**, **Remove**, **Up**, **Down** and an enabled checkbox. Parameters
show units and admitted ranges; material fields use actual native catalogue
names and IDs. Oil is material 16 and Water is material 3.

The profile is a staged edit until you press **Apply profile to this actor**.
Apply validates the complete configuration and reports the ordinary controller
owner's acknowledgement. It resets this actor's private procedural state and
assigns the **Procedural NPC / Ambient** controller. Invalid or unsupported data
leaves the previous valid controller usable. **Revert staged edits** reloads the
currently admitted configuration.

Apply refuses a stale draft if the actor's profile was changed elsewhere or the
World was replaced, including a replacement with the same actor ID. Revert
explicitly binds the editor to the current actor and profile. Pausing an
otherwise unchanged scene does not make a draft stale.

The controller dropdown also offers **Procedural NPC / Ambient** directly for
supported actors. A ground actor starts from Oil Moth; a 4LY flyer starts from
Drifting Flyer. An enabled ground ledge rule on a flyer is diagnosed and refused.
Disable or remove an inapplicable module before applying that profile.

Assignment is individual in this release. To reuse a personality, choose the
same preset for another compatible actor and apply it there. **Share identical
seed across actors** is off by default: each stable authored actor ID contributes
to its independent random stream. Turning it on deliberately gives the actors
the same seed, although differing observations can still produce different
decisions.

## The reusable vocabulary

A profile can contain up to sixteen module instances, including multiple
instances of the same type with different IDs and parameters. For example, seek
Oil and avoid Water use two material modules; neither is a special actor script.
Up to eight distinct material IDs can be requested by one profile.

| Module | Authored choice and observed effect |
| --- | --- |
| **Wander** | Pace, effort, heading persistence, variation and idle probability produce gradual seeded roaming with intentional pauses. |
| **Seek material** | Select material and radius, approach to a preferred distance, dwell, and wait through a declared reacquisition interval after losing it. |
| **Avoid material** | Enter and exit distances give hysteresis. Avoidance is a temporary higher-priority preference away from observed material, with no physical immunity. |
| **Avoid ledge** | Look ahead for actual support within the allowed drop. A grounded trigger latches its retreat direction for a finite duration, such as ten simulation seconds. Continuous safe support is required before it can rearm. |
| **Avoid boundary** | Steer inward at the configured canvas margin. This is separate from terrain support, a wall or a ledge. |
| **Escape obstruction** | Debounced movement without progress and actual nearby contact can trigger a short reversal. A supported ordinary jump may be requested explicitly; no actor is teleported. |
| **Return home** | Return toward the authored spawn/home outside one radius and release inside a smaller radius. |
| **Rest** | Alternate seeded active intervals and finite rest. Safety modules with higher priority can still win. |
| **Follow actor** | Approach a nearby compatible actor while keeping a preferred separation. |
| **Avoid crowding** | Add short-range separation from compatible nearby actors. |
| **Maintain altitude** | On supported flight rigs, steer toward an offset from home height within a tolerance. It uses the existing flight controller. |

Weight controls a module's contribution; zero disables that contribution,
including an override. Ordinary steering preferences combine. Temporary
overrides use priority, with authored list order breaking equal-priority ties.
This allows an urgent Water retreat to override ordinary Oil attraction and
wandering. It does not provide global routing around the Water.

Movement direction, requested pace and actuator effort are separate values.
Ground and wheel actors receive horizontal motion through their existing
motors. Flyers use the supported 4LY desired-velocity command. A module cannot
grant a rig a missing movement axis or equipment action.

The 4LY command exposes Pace but has no separate Effort action channel. Its
Effort field is visibly disabled with that explanation. The authored value is
retained so the same module configuration can be reused with a compatible
ground or wheel rig; it is not silently multiplied into flight pace.

## Six starting personalities

The readable preset catalogue is `godot/data/ambient/profiles.json`. Its names
describe combinations of shared modules, rather than a new species or physical
capability.

| Preset | Character of the authored configuration |
| --- | --- |
| **Oil Moth** | Wanders slowly, seeks Oil within 50 cells, keeps a modest standoff, avoids Water and uses a ten-second ground ledge retreat. |
| **Shy Crawler** | Moves more cautiously, reacts to Water earlier and accepts smaller drops before a persistent retreat. |
| **Curious Surveyor** | Wanders faster, investigates nearby Oil, rests briefly, returns toward home and recovers from observed stalls. |
| **Idle Mechanic** | Stays closer to home, alternates long rests and slow activity, and gently separates from neighbours. |
| **Drifting Flyer** | Uses irregular slow flight, preferred altitude, a loose home radius and canvas boundary retreat. |
| **Social Roamer** | Approaches nearby compatible inhabitants while avoiding crowding, with the ordinary Water and ground ledge protections. |

Compare Oil Moth and Curious Surveyor to see different weights and timers over
the same material, wander, boundary and recovery modules. The outcome remains
dependent on their actual surroundings and rigs.

## Paint, inspect and change a timer

In the main Workbench toolbar choose **Paint**, select Oil or Water and paint
within a few dozen world cells of an actor. Paint a patch several cells wide so
the sparse sensor can observe it. Erase or relocate it and watch the next
available observation change. There is no fixed demo route or prescribed edit
sequence.

The live profile inspector shows the chosen intent, contributing and inactive
modules, observed material target, active override and remaining duration. It
also reports decision cost and cadence. These are copied diagnostic values;
reading them does not change behaviour. The **Perception overlay** is off by
default and can show sampling radius, observed targets, steering and physical
ledge queries.

On the walkway, select **Avoid ledge**, change its duration, and press **Apply
profile to this actor**. Applying starts fresh private state. Once a subsequent
ledge trigger occurs, its original retreat direction is retained for that
duration. The timer does not renew on each observation. **Pause** freezes
simulation time; a long wall-clock pause consumes no retreat time. The inspector
reports intended movement even if geometry prevents the actor from travelling.

The Workbench decision interval is in completed physics ticks, with the existing
admitted range of 1–12 and a default of 6. Changing it changes when a local
decision is made. Timers advance from actual physical progression rather than
render frames or inspection refreshes.

## Human takeover, save and reopen

Use **Pilot inspected** to take control through the ordinary owner. **Hand back**
restores the retained procedural profile with fresh ephemeral intentions. It
does not promise exact continuation of the previous retreat or random stream.
Closing either inspector leaves the current producer active; merely selecting
an actor does not transfer control.

Enter a new scene name and use **Save start [Ctrl+S]**. **Load start** restores
the ordinary authored scene, the exact admitted profile and its actor assignment.
Names, module order, enabled flags, parameter values and seeds persist. A save
does not serialize current module timers, current RNG state, evolved native
material, velocity or live physical position. Reopening reconstructs the
authored start and resets private runtime state. Use the existing Workbench
authoring controls if you want to change an actor's authored spawn/home before
saving.

## Sensor and gameplay limits

Material sensing uses a shared copied native material-ID publication, never
displayed pixel colours. The radius is in world cells, not screen pixels. Its
admitted maximum is 96 cells. Sampling is an inclusive Euclidean circle on a
globally anchored four-cell grid at cell centres, clipped to the canvas. It
reports the **nearest observed** matching material; an unsampled cell can be
closer or entirely missed. Observed absence is not an exhaustive claim that no
matching material exists within the circle.

Missing baseline, stale publication, wrong World identity or no admitted sample
coverage is reported as unavailable. Dependent modules wait or use their
explicit behaviour-specific fallback; unavailable does not mean safe ground,
zero distance or absent material. Published native material IDs include
projected native ballistic material, so the sensor is not a stored-cell-only
occupancy query.

Physical ledges are owner-mediated support queries, distinct from canvas
boundaries and wall contact. Different ledge module instances receive their
own exact lookahead/depth queries. Spatial preferences use copied poses and
capabilities. Social compatibility groups ground/wheel inhabitants separately
from supported flight inhabitants; it does not establish a traversable route
between them.

There is no global pathfinding, arbitrary scripting, model inference or online
service. No movement motor, collision law or native material law is changed.
Unsupported rigs and modules are diagnosed. Seeded decision equality is tested
for identical observation streams; cross-platform bit-identical Rapier
trajectories and aesthetic believability are separate questions.

## Qualification and evaluator delivery

The [authoring ledger](../research/ambient-001/authoring-ledger.md) records strict
profile and persistence tests, actual mounted-editor transactions and independent
review findings. The [mission ledger](../research/ambient-001/mission-ledger.md)
is the source of final source identities, gameplay measurements, remaining gates
and delivery status. Module-level results, native material observations, physical
motion, graphical evidence and human judgement are recorded separately.

The Windows evaluator gate is pending until the lead records an exact-source
package, verified pristine extraction and launch receipts. Retained official
Godot executable hashes and source-matched native reuse eligibility are already
identified; those facts alone do not prove a new Windows launch. Linux headless
or software-rendered observations cannot establish physical Windows/NVIDIA
playfeel acceptance. Keep the feature opt-in and the implementation Draft/HOLD
until the owner reviews the candidate.
