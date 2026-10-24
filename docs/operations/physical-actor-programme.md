---
title: Physical actors and combined feature trials
status: Approved design
document-kind: design
scope: Owner-authorized ACT-004 integration, retained Blacksite hull comparison and preserved 2026-10-18 actor preferences; not broad physics acceptance
canonical-for: [physical-actor-programme, combined-feature-launcher, physical-blacksite-comparison]
last-reviewed: 2026-10-22
related-documents: [blacksite-nine-demo.md, ../systems/actor-rigs.md, ../systems/thunderbowl-control-reference.md, ../architecture/rigid-body-and-cellular-coupling.md, ../reference/product-intent-and-priorities.md]
---

# Physical actors and combined feature trials

## Shared free-flight training family

The [4LY contract and dependency chain](../systems/physical-free-flight.md)
owns the single-chassis Trainer/Hauler/Drifter/Dart lane under long-lived parent
#132. 4LY-001 reuses the physical session and native coupling, with strict
two-output desired-velocity input and bounded goal-blind assistance.
**4LY-002 candidate source** supplies four distinct physical parameter sets
and the additive F5 `set4LY` family. The 46 pre-existing actor IDs and SetP
indices remain unchanged. The [measured 4LY-002 audit](../audits/2026-10-23-4ly002-measured-handling-qualification.md)
records a real-Rapier pass of prospective motion/distinguishability thresholds
on Linux and Windows plus exact-source native and documentation gates. The
source calibration marker stays `candidate_4ly002` because its exact bytes
participate in the passing profile hashes. Owner handling/visual review,
final-head validation and the #207 host/teacher gate remain separate; a
selectable name or passing manoeuvre metric is not an accepted learning plant.

4LY-003 (#207) now has the [playable Flight Lab and physical episode owner](../systems/physical-flight-lab.md).
Its [frozen-teacher final-score audit](../audits/2026-10-24-4ly003-final-qualification.md)
records a passing per-profile/per-family physical score, three retained Hauler
obstacle failures, exact tested hashes and Linux runtime readback. External
holdout custody and human review are not attested by that CI score alone.
Trainer learning and subsequent family learning remain controlled by the
companion repository's separate 4LY-004/005 gates. None of these stages closes #132, generic granular/soliding acceptance or
the separate Jolt/morphology programme by implication.

## What is the approved direction for the complete actor roster?

**Approved owner requirement, implemented in ACT-004 source:** all 29 existing
actor identities now have articulated Rapier definitions, with twelve additional
SetX examples. The [physical actor contract](../systems/physical-actor-rigs.md)
owns their mechanisms, scripted examples and shared human/demo/policy interface.
Physical choices are the default actor route. Sampled motors remain explicit
references; no existing rig required a nonphysical exception in this catalogue.
The retained single-hull Ripper arm below is distinct from the new five-part rig.

**Approved fidelity:** preserve recognizable control and energy with real bodies,
bounded impulses/torques and collider-matched graphics. The owner explicitly
permits authored gyro assistance without finite momentum accounting, approximate
connections and modest flex/play to avoid twitchiness. Exact mechanical replicas
are not an acceptance requirement. Physical ground propulsion still requires
contact, and joints, thrust, grip and recoil have explicit runtime authority.

The reusable main-thread body/joint/session substrate, command leases, mounted
tools and separate physical Thunderbowl v2 are now implemented. Current bounds
are eight actors, eight parts per actor including held objects, and 64 coupled
bodies; the supplied rigs use two through seven parts. Further feel and
constrained-map trials remain useful, especially Sand contact and difficult
recovery. Neither this conversion nor a headless fixture pass closes generic
granular #83, soliding #12 or the Water successor gates. Dated execution and
remaining limits are in the [ACT-004 record](../audits/2026-10-18-act004-articulated-actors.md).

## How do I switch actors without leaving an exploratory map?

**Current desktop implementation:** F5 is available in the ordinary sandbox,
Blacksite Nine and all four showcase districts (Neon Reliquary, Middle Cyberberbia,
Sewertech Alley and Industrial Underswamp). F5 lists all 46 **Rapier** rigs, plus
the **Sampled** baseline/rig references and original barrel/Ripper hull trials.
Keyboard, scripted-demo and external-policy producers use the same physical
session and action vocabulary. Applying restores the
selected map's starting layout and spawn, starts paused, and keeps the selected
map identity. Material edits and motion are reset; this is not an in-place
conversion. R retains the selected actor. Above/Below district navigation carries
the choice to the destination's own spawn. The ordinary actor sandbox supports the
same physical choices. Only the retained single-body hull arms remain
keyboard-only. Physical comparisons admit up to eight actors from the selected
set; SetX's twelve entries therefore require more than one simultaneous view.

The later [player playground](../systems/player-control-playground.md) adds five
human movement presets as SetP. Its separate seven-preset course also supplies
native Sand/Water player fields, which are not F5 physical rigs. ACT-004's dated
41-definition evidence retains its original scope.

The worker configures sampled sessions at the scenario-install boundary. The
main thread installs physical sessions for the selected reset and keeps them
suspended until the matching reset acknowledgement, actor epoch and terrain are ready.
Physical picker IDs are `rapier/<model>`; the retained hull IDs are
`physical/barrel` and `physical/ripper`. The UI
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
sampled or physical Thunderbowl, the separate generation workbench, Strata
Theatre or the [Deepworks exhibition](deepworks-exhibition.md). F2 closes the current session
and returns to the launcher; unsaved edits are discarded. Explicit `main.tscn`,
`-- --blacksite-nine` and `-- --showcase` entry points remain available.
The native generation workbench remains an isolated authoring preview, without
live material simulation or attachment to the sandbox's World.
Deepworks uses its own four-world native material owner and camera/painting
controls; it has no ordinary physical actor session or F5 picker.

**Player playground** or `-- --player-playground` opens the separate human
movement course; optional `--player=ID` selects a preset. It reuses physical
actors for five choices and exclusively owns a native material field for two.
Its controls, lifecycle and qualification are in the
[player guide](../systems/player-control-playground.md).

The launcher also offers four complete, reset-scoped definitions:
`experimental/blacksite/sampled-baseline`, `sampled-burial-safe`, `barrel` and
`ripper` (each suffix uses the same prefix). They reuse the original Blacksite
rectangles, material policy and player start. The original registered definition
and historical hashes remain unchanged. Loading another arm or pressing R
restores the complete complex; this is a matched geometry comparison, not a
transfer of ongoing physical state between representations.

## What is the first physical comparison?

**Retained initial comparison:** barrel and Ripper each use one live
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
The following preferences were **Approved direction / Planned follow-up at
intake**. They remain the owner-intent record; current implementation and its
qualification are separately described above and in the physical actor contract:

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

The initial sequence was feature integration, the matched single-body trial,
then a reusable articulated substrate and roster migration. ACT-004 implements
that substrate and all 41 definitions. Its shared capacity was deliberately
raised from the former 16-body bound to 64 with finite-record admission and
capacity tests. The packed body/result strides are unchanged.

Further training, model-service orchestration and broad feel/platform acceptance
require their own evidence. Generic granular response, arbitrary shape coupling
and cellular torque remain with their canonical owners. Keep #83, #12 and the
Water programme scopes intact; historical scientific fixtures remain references.

The [Strata Theatre depth prototype](../systems/depth-layers-and-parallax.md)
retains its independent four-world host. The source-image conversation produced
32 usable-art references. ACT-004 implemented the initial mount/recoil/held-item
substrate. **Current ACT-005 source / #182** reconciles the functional
[U01-U32 catalogue](../systems/actor-usables.md) with that physical owner, adds
all-roster loadouts and supports deployed processors. The
[ACT-005 checkpoint](../audits/2026-10-19-act005-physical-usables.md) records actual
integration and acceptance; no general inventory/economy or health system is
implied by equipment selection.
