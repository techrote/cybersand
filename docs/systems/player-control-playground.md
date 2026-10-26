---
title: Player control playground
status: Current
document-kind: contract
scope: Experimental seven-preset human movement course, shared mechanical control, bounded native Sand and Water fields, input lifetime and qualified validation
canonical-for: [player-control-playground, player-movement-presets, player-material-field]
last-reviewed: 2026-10-26
related-documents: [physical-actor-rigs.md, ../architecture/data-ownership-and-lifetimes.md, ../architecture/rigid-body-and-cellular-coupling.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../operations/local-build-and-validation.md, ../audits/2026-10-20-player-control-playground.md]
---

# Player control playground

## Open the seven-preset movement course

**Current experimental source:** choose **Player playground** in the feature
launcher, open `res://player_playground.tscn`, or launch pinned Godot 4.7 with:

```text
godot --path godot -- --player-playground
godot --path godot -- --player-playground --player=acrobat
```

The optional player value is an ID from the table below. Eight selectable
1024 × 768 districts combine ramps, low tunnels, flight routes, landing decks,
material apparatus and usable targets in one native world. The original
512 × 256 course is retained only as an explicitly selected `legacy` test fixture.
Four ordered checkpoints give each map
a route and a simulation-time lap counter. The timer starts when active movement
or action input is admitted, including a quick press/release before the next
physics tick. Elapsed time advances only with simulation ticks and continues
while coasting with neutral input. Best times are kept only during this scene's
lifetime. Authored routes and
checkpoint detection do not establish that every route has been completed.

## Seven tailored maps, Water selection and painting

**Current branch implementation, local Windows qualification:** the independent
**Map** selector offers Mixed Works plus these seven focused districts. Every
selectable map has six times the first sample's area, with multi-level
structures, alternate paths, editable targets and varied building/material
samples. All include a service bay, catch basins, upper bridges and salvage racks.
Every map is selectable with all seven players; the suggested player describes
the emphasis, not an admission restriction or proof of complete traversal.

| Map ID / displayed name | Suggested player | Exercise |
|---|---|---|
| `cannon_run` / Cannon Run | Loose Cannon buggy | Long rideable ramp, landing straight and braking bumps |
| `rat_steps` / Rat Steps | Trials Rat bike | Low stepped ascent, narrow balance spine and stepped descent |
| `afterimage_works` / Afterimage Works | Afterimage acrobat | Low slide tunnel and upper decks for bullet jumps and gliding |
| `vector_port` / Vector Port | Vector Rush lander | Alternating broad flight slots, braking and landing decks |
| `dust_foundry` / Dust Foundry | Dust Devil Sand cloud | Four ten-tooth combs with seven-cell gaps, granular beds, catch basins and overhead foundries |
| `undertow_lab` / Undertow Lab | Undertow Water blob | Four lower Water/Brine/Oil basins, upper reservoirs, scooping shelves, glass channels and an ice specimen |
| `rocket_yard` / Rocket Yard | Barrel Rocket | Eight staggered heat-shield landing pads, offset baffles, fuel/Water targets and an upper gantry |

`mixed` remains the initial map and Current FreeMass remains the initial Water
solver. `--playground-map=undertow_lab` optionally selects a map at launch.
Changing player keeps map and Water selections. Changing either map or solver
constructs a fresh setup and clears edits/timing; R retains all three selections.
Best times are separated by player, map and solver; any successful material
edit or admitted usable operation marks the run **PRACTICE** and prevents that lap updating a clean best time.
Best times remain scene-local; solver names do not imply comparable difficulty.

The **Water** picker offers Current FreeMass, whole-cell CellularYield,
pressure reference, pressure cached, pressure cached-dormant and retained-momentum
inertial Water. The applied family/variant and execution radius come from native
readback. All other liquids retain Current assignments. IN explicitly uses
radius three; the other choices retain radius two, so this is exploratory play,
not a matched-geometry scientific comparison. All authored and painted Water
starts as whole cells. Selection rebuilds from authored rectangles, never
rounds a live fractional FreeMass World and never silently falls back on refusal.
These are the existing native solvers; no new law, defaults or C64/E8 ABI change.

Choose Sand, Water, Oil, Brine, Smoke, Fire, Lava, Acid or Wall and a **1–12 cell
brush radius**. **Spawn a burst above player** adds one disc 32 cells right and
32 cells above the player, clamped inside the course. Enable **Paint tool** to
draw with left mouse or erase with right mouse in the actual fitted play view;
overview and follow camera coordinates both apply. Disable it to resume player
control. Open selectors and focused numeric fields also hold movement input.
Click the play view to release numeric focus. Ordinary mouse aiming remains
available when the tool is off.

Default spawning fills Empty cells only; **Replace existing material / terrain**
explicitly enables replacement. Erase clears occupied cells independently of
that checkbox. Discs are clipped to the course interior and skip the current
mechanical body mask, including when paused. Up to 625 candidate positions and
441 disc cells are visited per radius-12 stamp. Continuous painting issues one
stamp per physics callback; the initial click can add another stamp. No brush
command enters native pool threads or borrows an asynchronous owner's World.
Painted hard terrain is synchronized to the existing private Rapier space.
Changes are authoring operations, not conserved-material field movement or a
scientific continuation guarantee. Water painting creates full quantity; it does
not replenish an occupied cell unless that cell is first explicitly erased.

`CyberPlayerPlaygroundWorld.build` uses the existing prepared-native constructor
with Baseline transport, exploratory/host-paced intent, full finite region,
disabled cadence LOD and a copied initial mechanical body state (or empty for
material players). It records a tick-zero native setup receipt covering the map
and initial swarm seed. Receipts identify the initial setup, not later painting.
A failed candidate leaves the live owner and accepted selections in place.
This synchronous playground route does not close #202/#203 full-host acceptance.

Sources: [map definitions](../../godot/scripts/player_playground_course.gd),
[large district authoring](../../godot/scripts/player_playground_districts.gd),
[native setup](../../godot/scripts/player_playground_world.gd),
[exclusive authoring owner](../../godot/scripts/player_playground_runtime.gd),
[scene controls](../../godot/scripts/player_playground.gd) and
[dated qualification](../audits/2026-10-26-player-playground-maps.md).

## Stronger player controls and usable testing

The [expanded checkpoint](../audits/2026-10-26-player-playground-expanded-and-usables.md)
records actual local Windows execution and retained first-pass failures. These
are authored player-control changes, including F5 SetP for mechanical players:

- Loose Cannon and Trials Rat lean using bounded tangential impulses around
  the actual rear wheel plus attached-part torque. No body transform is set or
  wheel pinned to a world position. Requested angular speeds are 11/12 rad/s,
  capped accelerations 90/95 rad/s², with rider lean up to 0.86 rad. Rapier's
  contacts and joints still determine the resulting motion.
- Both vehicles multiply their former upward hop impulses by √2, targeting
  approximately double ballistic height under unchanged gravity. Actual flat
  fixtures measure 1.91× buggy and 1.95× full-preload bike height. Bike charge,
  support, release and cancellation rules remain intact.
- Vector Rush uses gravity 96 cells/s² in damped mode and 32 in drift; C still
  toggles mode, and forces/damping remain finite. Detached equipment is not
  retuned when the owner changes gravity mode.
- Barrel Rocket scales physical rotational inertia by 0.85 without reducing
  mass and raises its soft speed target from 155 to 175 cells/s. Thrust remains
  finite; the measured unladen sustained-thrust speed is about 182 because the
  limiter is a bounded braking impulse, not an exact velocity clamp.
- Sand and Water players use a radius-60 composite field: five existing native
  radius-32 calls at centre and four offsets of 28 cells. Centres are clamped
  to native bounds. Admitted idle commands add bounded, periodic swirling and
  inward flow instead of static hovering. Lease loss still stops field calls;
  it does not start an autonomous player controller. Subreceipts are retained;
  summed sample/move counts can count a parcel more than once.

The **Usables** picker exposes the existing 32-item catalogue: tools,
projectiles and processors. Select an item, release action keys, aim with the
mouse and hold/press **M** to use it. **B** invokes its alternate action.
Mechanical players use the existing physical mount, charge/cooldown, exact
equipment identity and native-effect feedback. **N** drops/deploys a held body;
**U** reattaches a nearby compatible body. Selection while released/deployed can
refuse until the equipment is recovered. A newly selected item applies on the
next admitted unpaused tick; selection does not refill charge or cooldown.

Material players use the existing bounded material-only usable runtime at a
visible emitter 68 cells from their centre in the aiming direction, clamped
inside the map. This keeps projectiles/nozzles outside the player's own cloud.
They can use tools, launch projectiles and deploy/retrieve catalogue processors;
they have no physical held body, so N/U applies only to mechanical players.
Use B for catalogue alternate actions, including retrieval of a material-only
processor or early activation of an eligible payload. Obstacles and unavailable
space still refuse placement; a blocked use is not replaced with a fallback.

Painting and usable operation are separate controls. Pausing refuses usable
commands and stops cooldown/projectile/device time; painting remains available.
Focus/GUI/selection cancellation revokes player/trigger input, while previously
launched projectiles and deployed devices retain their normal autonomous
continuation when unpaused. Quick press/release edges before a tick are retained.
Reset destroys the old devices/projectiles and starts a fresh selected map;
the selected usable is retained as a requested loadout. Copied projectiles,
processors, effects and actual result/charge state are presented in the view.

Five mechanical presets also appear in **F5 → Rapier → SetP**, among the
46 retained physical actor IDs and original eight sets. The separate 4LY
free-flight family appends a ninth **F5 → set4LY** selection group without
renumbering SetP or replacing this dedicated player playground. They reuse
the shared physical session, controls and optional equipment lifecycle in exploratory maps.
Dust Devil and Undertow are available only in this separate playground; they
control native material and have no Rapier actor definition.

Sources: [scene owner](../../godot/scripts/player_playground.gd),
[course and displayed controls](../../godot/scripts/player_playground_course.gd),
[mechanical catalogue](../../godot/scripts/player_actor_catalog.gd) and
[launcher](../../godot/scripts/feature_launcher.gd).

## Keyboard controls for all seven presets

In `--player-playground` (optionally `--player=ID`), use 1–7 or Tab/Shift+Tab
to select, R to restart, P/Escape to pause, F for overview/follow, and F2 for the
launcher. These scene controls accompany the movement actions below.

| Key / ID | Preset | Movement and actions |
|---|---|---|
| **1** / `stuntbuggy` | **Loose Cannon** — loose-jointed stunt buggy | W/S drive/reverse; A/D or Q/E lean and rotate in air; Space hops from support; Shift brakes; hold C for recovery assistance. Sprung wheels and a hinged rider carry the motion. |
| **2** / `trialsbike` | **Trials Rat** — trials bike | W/S throttle/reverse; A/D or Q/E lean; hold Space while supported to preload, then release to hop; Shift brakes; hold C for recovery assistance. The rear wheel drives and the front wheel rolls freely until braking. |
| **3** / `acrobat` | **Afterimage** — momentum acrobat | A/D run and steer in air; Space jumps, then double jumps; hold Shift or S to slide; tap Shift to roll; Shift+Space or S+Space bullet jumps; C cancels/brakes and, held in air, glides. Mouse position aims bullet jumps. |
| **4** / `arcadelander` | **Vector Rush** — arcade lander | W or Space fires the body-axis main engine; A/D or Q/E rotates; S gives reverse thrust; Shift applies a strong airbrake; tap C toggles damped flight/coast. |
| **5** / `dryswarm` | **Dust Devil** — Sand cloud | WASD guides actual Sand; Space surges in the movement direction, or upward from neutral; Shift spreads; C gathers. Neutral admitted input keeps the cohesion/loft field active. |
| **6** / `liquidswarm` | **Undertow** — Water blob | WASD guides actual Water; Space surges; Shift squeezes transverse to travel into a stream; C gathers. Neutral admitted input keeps the cohesion/loft field active. |
| **7** / `jetbarrel` | **Barrel Rocket** — barrel with jetpack | W or Space fires the body-axis jet; A/D or Q/E provides strong rotation; S gives reverse thrust; Shift brakes; hold C for upright assistance. |

Arrow keys duplicate WASD in the dedicated scene. The lander and barrel thrust
along their current orientation, so rotation changes the direction of the next
burst. Damping and recovery are authored game assistance with bounded forces;
contacts and rigid-body motion remain Rapier's responsibility. A cancelled bike
preload is discarded without firing a hop.

## Acrobat movement chains and cancels

Afterimage preserves momentum through a low-drag slide and uses actual folding
hip/ankle joints for its tucked posture. Steering during slides and rolls is
weaker than running; reversing input changes momentum gradually. A held crouch
can keep the tuck during a brief loss of support. The controller does not
teleport the body or replace its velocity with a character trajectory.

- **Run → slide → bullet jump:** gain speed with A/D, hold Shift or S to tuck,
  aim with the mouse, then press Space. Grounded bullet jumps include an upward
  component; faster velocity already aligned with the launch is retained.
- **Jump → double jump → roll → glide:** Space gives the ground jump and one
  airborne jump. Press Shift in air for the separate air roll. Hold C near the
  apex or while falling to reduce descent while steering with A/D.
- **Roll → jump cancel:** press Space during a roll to leave it using an
  available jump. If Shift/S remains held, the same press requests a bullet
  jump first while that separate launch is available. Release crouch for an
  ordinary jump cancel.
- **Slide/roll → brake cancel:** press C to end the slide or roll. On support,
  C brakes; slide stays suppressed until crouch is released. Releasing Space
  early shortens an ordinary jump. Q/E adds airborne attitude trim.

The controller supplies a short coyote window and input buffer. One airborne
jump, one bullet jump, one air roll and a finite glide reserve recharge after
confirmed support, not after focus changes or cancellation. Glide retains
positive gravity and has a finite duration; it is not hover. Exact timing and
actuation limits belong to the
[configuration reference](../reference/configuration-reference.md#player-playground-values).
Sources: [acrobat controller](../../godot/scripts/player_acrobat_controller.gd)
and [physical rig actuator](../../godot/scripts/physical_actor_rig.gd).

## Gamepad and quick scene controls

The dedicated scene samples the first connected standard gamepad. Its left
stick supplies WASD, A supplies Space/primary, B supplies Shift/secondary, X
supplies C/auxiliary, and the shoulder buttons supply Q/E trim. Start pauses.
The stick has a radial deadzone and is combined with keyboard input before
unit-length clamping. The mouse supplies aim while inside the play view;
otherwise movement supplies aim, with a diagonal fallback at neutral.
Gamepad mapping is implemented; physical controller qualification is separate.

| Control | Scene operation |
|---|---|
| Map picker / Water picker | Rebuild with the selected map / native Water law; every player remains available |
| 1–7 or preset buttons | Select a preset and construct a fresh session, retaining map and Water selections |
| Tab / Shift+Tab | Select next / previous preset |
| R or Restart | Reset selected preset/map/Water and discard edits; keep this scene's best times |
| P, Escape or gamepad Start | Pause/resume; pause revokes current input |
| F or camera button | Toggle course overview and player-follow view |
| F2 or Menu | Close the current owner and return to the feature launcher |

Selection, restart, pause and focus changes require movement/action controls to
be released before input rearms. Window focus loss, GUI focus or a mouse-button
press cancels pending control. Focus loss alone does not pause the physics;
uncontrolled material settles and mechanical momentum continues. Use pause to
stop stepping. The scene begins running after successful setup, unlike the
ordinary F5 map replacement, which begins paused.

Source: [local sampler](../../godot/scripts/player_playground_input.gd) and
[scene admission/rearm](../../godot/scripts/player_playground.gd).

## Native Sand cloud and Water blob ownership

The [playground runtime](../../godot/scripts/player_playground_runtime.gd)
exclusively owns one synchronous native World for a material preset. Setup seeds
256 Sand or Water cells. Each admitted step applies the native field before the
ordinary material tick; normal kernels still own gravity, Water flow and
reactions. Mechanical presets instead use the existing synchronous physical
arena and its main-thread Rapier session. Neither lane borrows the asynchronous
sandbox worker's World.

`World::apply_player_material_field` moves complete stored cells through
`relocate_stored_cell`, preserving compact state, temperature and exact partial
Water quantity within that call. It does not erase/repaint the cloud, create
per-cell physics bodies, or introduce a Water pressure/flow rule. The next normal
tick can redistribute Water and apply ordinary interactions. A field therefore
does not promise conservation across unrelated chemistry or authoring actions.

Selection is **matching material within a local radius**, not a persistent
collection of owned particles. Nearby environmental Sand/Water can join; material
that leaves the field is no longer controlled. The field follows the returned
quantity-weighted material centroid with a bounded centre adjustment. WASD moves
material rather than a remote selection cursor. The visible ring shows this
local selection boundary.

Each native call scans at most 4,225 candidate positions within a radius-32
selection, captures at most 512 source parcels once, and attempts at most four
axis-adjacent moves per parcel. Stable ordering and phase-based scan rotation
prevent repeated source processing. Occupied cells, hard terrain, transient
bodies, world bounds and unavailable destination storage stop a step. No
occupied cell is overwritten. Invalid commands and failed/in-tick Worlds are
refused before mutation. Exact API, receipt and limits are in
[interfaces](../reference/interfaces-and-message-contracts.md#player-material-field-control)
and [configuration](../reference/configuration-reference.md#player-playground-values).

## Leases, reset and bounded authority

Mechanical input uses the shared version-2 physical action envelope. The
material lane uses version-1 `player_material_field_action`: run, epoch, actor,
sequence, actually issued observation and expiry all must match. Both receive
six-tick observation-relative human leases in the scene. The material lane
accepts one through six ticks; the shared physical API retains its own larger
admitted bound. A late response cannot extend a lease;
pause, cancel, reset, replacement or close revokes the old authority. The swarm
mode priority is C gather, then Shift spread/squeeze, then Space surge, then
normal cohesion/loft.

Neutral input is still an admitted, renewed command. If focus or the lease is
lost, the runtime stops calling the field entirely and the material follows its
ordinary native simulation. No field state persists in World. Copied receipts
and render packets carry the current reset generation; no mutable World storage
or Rapier object is exposed to the UI. Input cancellation clears future intent
without deleting momentum, replenishing airborne actions or releasing a bike's
stored preload. The [ownership contract](../architecture/data-ownership-and-lifetimes.md)
and [physical contract](physical-actor-rigs.md) own the shared boundaries.

## Circular wheels and qualification limits

The buggy and bike use real Rapier circles for hard contact and round visuals.
The existing native body ABI remains oriented rectangles: each circle is coupled
to materials through a conservative circumscribed square. That square can
occupy corner cells outside the drawn wheel, especially as it rotates. This is
an explicit approximation, not circular native rasterization or a generalized
shape-coupling change. See the
[coupling contract](../architecture/rigid-body-and-cellular-coupling.md).

The [original playground record](../audits/2026-10-20-player-control-playground.md)
preserves source/artifact identities, local Linux native/Godot checks and
failures. The [PR #189 completion record](../audits/2026-10-21-player-playground-pr189-completion.md)
adds original-head hosted Linux and actual Windows headless results and tracks
combined-source runtime and final-head gates after integration with GEN-003 main,
with the final exact-head outcomes recorded in PR #189's description and Checks. The
[build guide](../operations/local-build-and-validation.md#player-playground-checks)
routes focused regressions. Human feel on the target PC, complete checkpoint
routes, real gamepad/window-focus behavior and browser execution are not
established by headless tests. Actual Windows headless execution does not
establish interactive Windows feel. Generic body/granular, soliding and Water successor acceptance
retain their existing programme owners.
