---
title: Player control playground
status: Current
document-kind: contract
scope: Experimental seven-preset human movement course, shared mechanical control, bounded native Sand and Water fields, input lifetime and qualified validation
canonical-for: [player-control-playground, player-movement-presets, player-material-field]
last-reviewed: 2026-10-27
related-documents: [physical-actor-rigs.md, ../architecture/data-ownership-and-lifetimes.md, ../architecture/rigid-body-and-cellular-coupling.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../operations/local-build-and-validation.md, ../audits/2026-10-20-player-control-playground.md]
---

# Player control playground

## PLAY composable existing-host route — mechanical composition qualified

[PLAY-COMP-001 #273](https://github.com/techrote/cybersand/issues/273) is
accepted through [merged PR #274](https://github.com/techrote/cybersand/pull/274).
The real Acrobat and original course ran through the **existing**
`CyberSimulationWorker` and main-thread Rapier; its
`fc5b2e4` head passed 117/117 focused assertions on Windows and Linux.
No dedicated second World owner is required.

[PLAY-COMP-002 / #267](https://github.com/techrote/cybersand/pull/275)
was merged as `6c5b8b45df151e39a026ae23075ae4611826387c`
on 2026-10-27. The reviewed PR's tested integration merge tree
`062ba113da8cbd5d944151e6d4c2b3396f95f3e3` combines the unchanged
`d005ef8` patch and preceding `7500c1c` main. Its actual Windows and
Linux `test_play_comp002_five_rig_course` executions each report
**73 assertions, zero failures**, with all five real SetP mechanical
actors, source-matched original spawn positions, native/physical tick
progress, keyboard movement, terrain readiness and reset. Native,
GDExtension/Godot and Documentation required workflows succeeded:
[Native](https://github.com/techrote/cybersand/actions/runs/40452089685),
[Godot](https://github.com/techrote/cybersand/actions/runs/40452089898),
[Documentation](https://github.com/techrote/cybersand/actions/runs/40452089638).

The selectable `playground/player-course` reuses the original
`CyberPlayerPlaygroundCourse.layout()` with F5 → SetP in the regular
asynchronous desktop MicroScenario host. Its first mechanical actor
origin is `(178, floor_y - equipment_clearance)` for ground rigs and
`(178, 304)` for the lander and barrel. Generic map constructors,
native ownership, protected science/NPC fixtures, material solver
defaults and construction-time liquid-policy validation are unchanged.
The separate original seven-preset scene remains available.

**PLAY-AUTO-001 / #266 is a candidate, not qualified by the above
runs.** [Focused source-backed test](../../godot/tests/test_play_auto001_shared_course.gd)
checks that desktop setting `cybersand/native_worker_threads=0`
resolves the existing native 2/4/6 Auto policy in the actual
shared-course/Acrobat session, using only copied
`CyberSimulationWorker` snapshot worker capacity and scheduler
metrics. Its source-head Windows/Linux execution is pending. It does
not retune a live native World, prove actual concurrent worker
utilization or speedup, measure rendered FPS or replace a benchmark.

The remaining [#268 controls/UI](https://github.com/techrote/cybersand/issues/268)
scope includes dedicated-scene quick-tap/gamepad parity, camera/overview,
checkpoint/lap presentation and profile selection. #266 also requires
native-pool utilization and fair measured controls; #269 requires
lifecycle/failure/soak verification, and #270 final desktop/manual
qualification. The five-rig test does **not** qualify those areas.
Per-material liquid families remain selectable through the validated
native construction/rebuild contract; no global family/default or live
hot-switch was introduced by PLAY-COMP-002. Material swarms #271 remain
deferred; the dedicated-worker alternative #265 remains closed.

Sources: [authored course](../../godot/scripts/player_playground_course.gd),
[MicroScenario catalogue](../../godot/scripts/microscenario_catalogue.gd),
[desktop actor session](../../godot/scripts/main.gd),
[initial existing-host test](../../godot/tests/test_play_comp001_existing_host_spike.gd),
[five-rig source regression](../../godot/tests/test_play_comp002_five_rig_course.gd)
and [native Auto readback candidate](../../godot/tests/test_play_auto001_shared_course.gd).

## Open the seven-preset movement course

**Current experimental source:** choose **Player playground** in the feature
launcher, open `res://player_playground.tscn`, or launch pinned Godot 4.7 with:

```text
godot --path godot -- --player-playground
godot --path godot -- --player-playground --player=acrobat
```

The optional player value is an ID from the table below. The course combines a
ramp, low tunnel, airborne slalom, landing decks and a material sieve in a
512 × 256 view of one native world. Four ordered checkpoints give each preset
a route and a simulation-time lap counter. The timer starts when active movement
or action input is admitted, including a quick press/release before the next
physics tick. Elapsed time advances only with simulation ticks and continues
while coasting with neutral input. Best times are kept only during this scene's
lifetime. Authored routes and
checkpoint detection do not establish that every route has been completed.

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
| 1–7 or preset buttons | Select a preset and construct a fresh course/session |
| Tab / Shift+Tab | Select next / previous preset |
| R or Restart | Reset the selected preset and course; keep this scene's best times |
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

The native call scans at most 4,225 candidate positions within a radius-32
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
