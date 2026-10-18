---
title: Physical actors and combined feature trials
status: Approved design
document-kind: design
scope: Owner-authorized integration sequence, Blacksite barrel/Ripper experiment and preserved 2026-10-18 actor preferences; not broad physics acceptance
canonical-for: [physical-actor-programme, combined-feature-launcher, physical-blacksite-comparison]
last-reviewed: 2026-10-18
related-documents: [blacksite-nine-demo.md, ../systems/actor-rigs.md, ../systems/thunderbowl-control-reference.md, ../architecture/rigid-body-and-cellular-coupling.md, ../reference/product-intent-and-priorities.md]
---

# Physical actors and combined feature trials

## What is the approved direction for the complete actor roster?

**Approved owner requirement, 2026-10-18; implementation Planned:** adapt or
reimplement all 29 actor rigs as physical Rapier actors by default. An actor may
retain a non-Rapier configuration only when a specific behaviour/configuration
cannot be realized through the physical representation; record the concrete
reason and comparison evidence. Implementation inconvenience is not an exception.
Sampled rigs remain explicit reference controls during migration, not the default
long-term actor representation. The current physical Ripper is still a single
rectangular hull and does not complete the Ripper conversion.

The migration must preserve each actor's recognizable control and energy while
using live bodies, bounded impulses/torques, collider-matched polygon graphics,
and main-thread-owned joints where appropriate. Ground propulsion, hinged parts,
gyros, thrusters, grips and usable recoil need explicit physical authority; do not
rename sampled motors or turn cosmetic joints into claims of articulation.

**Planned sequence:** establish reusable physical actor/body/joint lifecycle and
actions/observations behind the existing replaceable bridge; convert barrel and
Ripper into reference physical mechanisms; then convert ground/contact rigs,
flight/gyro rigs, rope/attachment rigs and the scripted-policy roster. Trial each
in Blacksite and the showcase districts against its sampled reference, including
focus/pause/reset, constrained traversal, Water/Sand contact and held-usables
attachment/release/recoil. Keep native cell ownership, bounded body capacity and
#83 granular ownership intact. Arbitrary colliders, articulated coupling and
policy control are work to implement and validate, not supplied by this picker.

## How do I switch actors without leaving an exploratory map?

**Current desktop implementation:** F5 is available in the ordinary sandbox,
Blacksite Nine and all four showcase districts (Neon Reliquary, Middle Cyberberbia,
Sewertech Alley and Industrial Underswamp). Each set lists **Sampled** baseline/rig
choices and **Rapier** physical barrel/Ripper choices. Applying restores the
selected map's starting layout and spawn, starts paused, and keeps the selected
map identity. Material edits and motion are reset; this is not an in-place
conversion. R retains the selected actor. Above/Below district navigation carries
the choice to the destination's own spawn. The ordinary actor sandbox supports the
same physical choices. The physical trials currently accept keyboard control only;
scripted/policy pilots and companion NPCs remain sampled-rig options.

The worker configures sampled sessions at the scenario-install boundary. The UI
waits for a matching per-request acknowledgement and definition hash; a previous
snapshot with the same map hash cannot acknowledge a new actor. Only the explicit
exploratory map allowlist admits this override. Benchmark mode, Tower, controlled
Water and registered apparatus remain protected. Depth's separate four-world host,
the generation authoring preview and Thunderbowl's control apparatus are not
members of this exploratory-map path. Desktop changes do not extend Web controls.

Sources: `main.gd` actor selection and scenario acknowledgement,
`microscenario_catalogue.gd` exploratory allowlist, `simulation_worker.gd`
scenario-install handling and `actor_prototype_panel.gd` physics labels.

## How do I try the integrated features?

**Current implementation:** the desktop project's default scene is
[`feature_launcher.tscn`](../../godot/feature_launcher.tscn). It opens Blacksite
Nine, the four showcase districts, the ordinary actor/material sandbox,
Thunderbowl, the separate generation workbench or Strata Theatre. F2 closes the current session
and returns to the launcher; unsaved edits are discarded. Explicit `main.tscn`,
`-- --blacksite-nine` and `-- --showcase` entry points remain available.
The native generation workbench remains an isolated authoring preview, without
live material simulation or attachment to the sandbox's World.

The launcher also offers four complete, reset-scoped definitions:
`experimental/blacksite/sampled-baseline`, `sampled-burial-safe`, `barrel` and
`ripper` (each suffix uses the same prefix). They reuse the original Blacksite
rectangles, material policy and player start. The original registered definition
and historical hashes remain unchanged. Loading another arm or pressing R
restores the complete complex; this is a matched geometry comparison, not a
transfer of ongoing physical state between representations.

## What is the first physical comparison?

**Current experimental implementation:** barrel and Ripper each use one live
Rapier rectangle, through the existing main-thread bridge and native cellular
coupling. The sampled owner is disabled. Barrel retains the reference 8 by 14
hull and horizontal drive. Ripper uses an 18 by 8 hull, a 70-cell/s horizontal
target and 260-cell/s² bounded drive, compared with barrel's 42 and 180. Both
retain the existing three-unit maximum horizontal impulse per control step.
The collision rectangle, native occupancy extent and rendered rectangle share
the same dimensions and physics transform. This is a first hull/control trial,
not articulated tracks or a migration of the sampled Ripper rig.

A/D drives, Q/E supplies signed angular impulse and Space's rising edge supplies
an upward thruster pulse. The latter is deliberately available airborne: it is
not a grounded jump detector. A pulse is capped at 24 impulse units with a
0.6-second simulation-time cooldown; holding Space does not repeat it. Torque
request is 12 times delta, capped at 0.2 angular impulse units per call. Existing
adapter units are provisional, not an SI-calibrated force or energy model.
Focus loss, modal controls, pause and replacement require control release before
rearming. No controller assigns velocity or teleports the body as propulsion.

The Blacksite camera map remains available. Existing backdrop/exposure effects
remain disabled for body-enabled definitions, preserving their established mask
restriction. These initial arms are **desktop only**; the synchronous Web
controller explicitly refuses them. They establish neither broad granular
acceptance nor a Water successor. Sand tunnelling remains a recorded limitation
under generic body/granular ownership, including REM-004 / #83.

Sources: [`physical_actor_trial.gd`](../../godot/scripts/physical_actor_trial.gd),
[`main.gd`](../../godot/scripts/main.gd) accepted installation and control,
[`rapier_physics_bridge.gd`](../../godot/scripts/rapier_physics_bridge.gd)
`apply_trial_impulses`, and the
[native coupling contract](../architecture/rigid-body-and-cellular-coupling.md).

## What did the owner observe and authorize on 2026-10-18?

**Owner observations, not independently established physics facts:** the
horizontal-impulse barrel felt physical and kinetic; its Water/barrel interaction
was particularly convincing, but some Sand interactions tunnel too freely.
Burial-safe sampled actors could become pinned by very small Sand/body overlaps.
The sampled baseline in the material-effects build avoided that sticking but
appeared more jittery. A matched policy/render comparison is required: PR #164
changes presentation, not movement semantics. Preserve these reports as separate
observations rather than claiming the shaders fixed collision.

The owner approved landing the existing presentation, generation and scene
features, a combined launcher, and starting the physical barrel/Ripper trial.
The following preferences are **Approved direction / Planned follow-up**, not
claims about mechanisms already implemented:

- Prefer experimental impulse/torque-driven Rapier machines; keep sampled
  reference arms for comparison. Add short high-power vertical pulses and torque
  to the physical player. Investigate granular interaction without inventing an
  actor-local displacement solver or duplicating #83 ownership.
- Some actors must consist of several hinged physical bodies. Internal motors
  torque parts against each other; grounded propulsion must arise from contact.
  Reaction wheels/gyros justify bounded attitude authority; do not turn internal
  joint torque into unexplained free-flight propulsion.
- Scrabbler: a Leaper-like articulated machine, using the supplied image as a
  stance/motion reference. Ripper: a fast low RC drift crawler; the written file
  also cites a Warframe Bursa. The short video emphasizes speed, slip and strong
  changes of direction. Pouncer: a cybernetic headcrab/flying or gliding squirrel.
  Digger: a rocket-powered mole that can screw into a burrow and travel along it
  horizontally or vertically, with explicit bounded excavation authority.
- Copter should remain demanding and unstable but recoverable. Trial multirotors
  with different shape, speed, centre of mass, inertia, stability and thrust
  tradeoffs. Lineshank should be katana-slim with its centre of mass near the grip;
  trial rocket propulsion alongside the retained bungee version.
- Rocketjumper should trial a Fire blob surrounded by a Gunpowder ring at the
  explosion, with bounded cell placement and explicit propulsion accounting.
- Preserve Gyrocrate's lively feel and Bellows' character (the owner's image is
  an underappreciated food-delivery bot). Vector and Jolt are the preferred
  scripted-bot energy references; give other scripts more purposeful vigour
  through the same action authority available to human control.
- Render actors using filled colour/texture polygons that exactly represent
  their actual collider parts, with optional outlines. Use the physical part
  definition and published transform as the shared source, including rotation.
- Test in constrained Blacksite/Neon spaces as well as reduced fixtures. Compare
  sampled recovery policies and render timing instead of assuming that the
  material-effects build supplies a movement fix.
- Define usable grip/mount points, aiming limits, action input, recoil transfer,
  attachment/release and wall clearance. First compare a mounted tool, a recoiling
  item and an articulated held item; do not require every usable to be a body.

The original local observation text is preserved in the
[dated owner-notes record](../audits/2026-10-18-owner-actor-observations.md).
The conversational additions above supplement that file; the attached video
and image were inspected locally and are not copied into the source repository.

## Follow-up order and ownership

1. Land the existing features with exact-head gates; retain prior audits.
2. Validate the combined launcher and single-body Blacksite experiment.
3. Establish one reusable articulated-body/joint substrate with Scrabbler.
   Explicitly budget actor count, part count and the current 16-body coupling
   limit; preserve main-thread Rapier and worker-owned native cell authority.
4. Reuse that substrate for other rigs and usable attachments. Keep generic
   granular response, shape coupling and cellular torque work with their canonical
   owners. Do not recharter #12/#45 or alter historical scientific fixtures.

No selection of a universal actor representation, acceptance of every rig,
articulated mechanism, learned controller or broad platform result follows from
this first experiment.

The [Strata Theatre depth prototype](../systems/depth-layers-and-parallax.md) is also available from the launcher and retains F4/direct entry. It owns its four synchronous material worlds independently of gameplay. The source-image conversation produced tool-art references; those are follow-up usable assets, not an implemented wielding system.
