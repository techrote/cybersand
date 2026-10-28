---
title: Player control playground
status: Current
document-kind: contract
scope: Experimental seven-preset human movement course, shared mechanical control, bounded native Sand and Water fields, input lifetime and qualified validation
canonical-for: [player-control-playground, player-movement-presets, player-material-field]
last-reviewed: 2026-10-28
related-documents: [physical-actor-rigs.md, ../architecture/data-ownership-and-lifetimes.md, ../architecture/rigid-body-and-cellular-coupling.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../operations/local-build-and-validation.md, ../audits/2026-10-20-player-control-playground.md]
---

# Player control playground

## PLAY composable existing-host route — accepted course and five-rig slice

[PLAY-COMP-001 #273](https://github.com/techrote/cybersand/issues/273) was
completed by [PR #274](https://github.com/techrote/cybersand/pull/274),
merged on 2026-10-27 as `7500c1cc`. Its focused existing-host
Player Playground/SetP Acrobat integration passed 117 assertions and zero
failures on **each** of Linux and Windows, through the existing
`CyberSimulationWorker` plus **main-thread Rapier**. This proved the
feasibility of reusing the owner, not five-rig parity or frame pacing.

**Accepted five-rig #267 slice:** [PR #275](https://github.com/techrote/cybersand/pull/275)
merged on 2026-10-27 as `6c5b8b45df151e39a026ae23075ae4611826387c`.
The normal MicroScenario selector now admits the exact authored
`playground/player-course` layout in **Play** mode; **F5 → SetP** separately
chooses the stunt buggy, trials bike, acrobat, arcade lander or jet barrel.
The first actor's physical origin is source-faithful at
`(178, FLOOR_Y - equipment_clearance)` for the three ground rigs and
`(178, 304)` for the flight rigs. Normal MicroScenarios and all other
rig constructors retain their former spawn rules. Source-tree-identical
[Windows/Linux actual-host tests](https://github.com/techrote/cybersand/pull/275#issuecomment-6436394299)
passed **73/73 assertions on each OS**, moving each real mechanical rig
with native/physical ticks, actual Rapier terrain and copied worker state,
and preserving map identity across actor changes and reset.
[Native](https://github.com/techrote/cybersand/actions/runs/40452089685),
[Godot/GDExtension](https://github.com/techrote/cybersand/actions/runs/40452089898)
and [Docs](https://github.com/techrote/cybersand/actions/runs/40452089638)
CI succeeded for the tested tree. A passing headless test is **not**
interactive camera/lap/gamepad parity, worker parallel-speedup or subjective feel.

**Accepted #267 solver-policy slice:** [PR #276](https://github.com/techrote/cybersand/pull/276)
merged on 2026-10-27 as `e936489d5b731665bf3cbc102be986ca8d67b6cf`
with Git tree `506f7bf42eae5ddadad925feb686f74392a69a23`
identical to its qualified source head. Both [Windows and Linux actual-host
Godot/GDExtension jobs](https://github.com/techrote/cybersand/actions/runs/40469479950)
returned **87 assertions / 0 failures**, retaining the original course
rectangles, material IDs and recipe digest `9aa78894...`; the prepared
World applied Water `pressure_flow_v1` at construction with policy hash
`f67a65e8...` and immutable native receipt `f01864b2...`. The focused
regression checks generation 8 → 9 → 10, atomic controlled-route refusal,
reset and F5 Acrobat retention. Exact-source
[Native](https://github.com/techrote/cybersand/actions/runs/40469480069)
and [Docs](https://github.com/techrote/cybersand/actions/runs/40469479883)
also succeeded. This is a prepared rebuild option, **not** a hot solver swap
or exhaustive fluid-family validation. The subsequently triggered main
merge-CI remains a distinct execution record.

**Accepted #268 initial input/camera slice:** [PR #278](https://github.com/techrote/cybersand/pull/278)
merged on 2026-10-27 at `3dd28213231e434369356f4040445856faad69d4`.
The existing async desktop course reuses `CyberPlayerPlaygroundInput` for
keyboard/arrows and standard gamepad mapping, optional logical-key input,
neutral rearm and camera following the actual main-thread Rapier actor.
Both [Windows and Linux actual-host jobs](https://github.com/techrote/cybersand/actions/runs/40492528449)
passed **99 assertions / 0 failures** each, including quick arrow edges and
unchanged construction-time Water `pressure_flow_v1` policy receipts.
[Native](https://github.com/techrote/cybersand/actions/runs/40492528431)
and [Docs](https://github.com/techrote/cybersand/actions/runs/40492528439)
succeeded on the same reviewed integration tree. This does not establish
physical gamepad or manual gameplay feel.

**Accepted PLAY-UI-002 / #268 camera slice:** [PR #279](https://github.com/techrote/cybersand/pull/279)
merged on 2026-10-27 at `fc397c6f7ff9807610171a69e340af47f3e04f37`.
The mechanical course now uses its authored 256x128 close-follow viewport;
F toggles the exact `Rect2i(128,128,512,256)` panorama and back without
rebuilding the World. Other scientific/default camera controls retain their
original behavior. The [Windows/Linux Godot jobs](https://github.com/techrote/cybersand/actions/runs/40515691731)
each passed 115/115 actual-host five-rig assertions, with
[Native](https://github.com/techrote/cybersand/actions/runs/40515691552)
and [Docs](https://github.com/techrote/cybersand/actions/runs/40515691616)
green at exact reviewed head. No manual camera/feel claim follows.

**Accepted PLAY-UI-003 / #268 lap/HUD slice:** [PR #280](https://github.com/techrote/cybersand/pull/280)
merged on 2026-10-28 as `69e340d390e3e563833e80659aa97fddc2922310`.
Its accepted tree `63c6612fcaecdacad26452f7d15dfb118d410d9d` matches
reviewed head `8533876b` and tested checkout `eb84f71c`.
[Godot/GDExtension](https://github.com/techrote/cybersand/actions/runs/40600760606),
[Native](https://github.com/techrote/cybersand/actions/runs/40600760721),
[Documentation](https://github.com/techrote/cybersand/actions/runs/40600760603)
and [independent source review](https://github.com/techrote/cybersand/pull/280#issuecomment-6453690179)
completed successfully for that source. The prior parse failures remain in the
[retained audit](../audits/2026-10-27-play-ui003-exact-head-parse-failure.md).
The composable course's lap/HUD uses completed **native snapshot tick deltas**
for elapsed time and **completed main-thread Rapier steps** for the four ordered
checkpoint visits. The same host's `_physics_process` observes actual SetP
poses only after `physical_actor_session.complete_step()` advances its tick.
Its independently paced `_process` updates the visible HUD and native clock
without replacing or repeating physics-step gate credit. The native World is
never stepped or inspected directly from the UI. Timing begins on admitted
human input, pauses without catch-up and resets its visible session after
actor/World generation replacement. The tracker retains monotonic lifetime
fences to reject retired actor/World publications; per-rig bests survive
ordinary scene resets.

[Real-host cadence regression](../../godot/tests/test_play_ui003_physics_cadence.gd)
disables both automatic render/physics callbacks, then performs explicitly
completed **real Rapier** steps through entry and exit of an authored gate. It
uses bridge-based **test-only whole-assembly repositioning** to force that
short visit; this is an instrumentation fixture, not natural game travel.
A separate identical-host negative arm overrides only the new completed-step
sampling hook, proving the render-only path loses the transient visit. The
existing [five-rig integration fixture](../../godot/tests/test_play_comp002_five_rig_course.gd)
and [50-cycle model-only lifetime fixture](../../godot/tests/test_play_ui003_lap_clock.gd)
passed on both Windows and Linux: **41/0** real-cadence assertions, including
one matched render-only negative control; **126/0** five-rig assertions; and
**1,373/0** lap-model assertions covering 50 **model-only** lifetime cycles.
These are parent-source results, not qualification of a later combined branch.
They do not establish hardware gamepad behavior, interactive FPS, subjectively
acceptable camera/controls, or #269's fifty-real-host lifecycle campaign.
The remaining [#268](https://github.com/techrote/cybersand/issues/268)
scope includes an integrated playable selector, gameplay-rule options, complete
focus and physical-gamepad qualification and real frame-pacing/feel validation.
The accepted four-checkpoint lap/HUD slice does not close those requirements.
Native Auto measurements, lifecycle/stress and final desktop feel remain
#266/#269/#270. Material swarms (#271) remain deferred in the standalone
seven-preset experimental scene. Specialist scientific and NPC-training
fixtures retain independent deterministic admission/execution.
No second native World owner is introduced; redundant #265 remains closed.

Sources: [course geometry and mechanical origins](../../godot/scripts/player_playground_course.gd),
[versioned MicroScenario catalogue](../../godot/scripts/microscenario_catalogue.gd),
[existing desktop admission](../../godot/scripts/main.gd),
[existing-host feasibility test](../../godot/tests/test_play_comp001_existing_host_spike.gd),
and [current five-rig/solver test](../../godot/tests/test_play_comp002_five_rig_course.gd).

## Accepted normal desktop lifecycle qualification

[PLAY-LIFE-001 PR #284](https://github.com/techrote/cybersand/pull/284) merged
on 2026-10-28 as `8288e580df90620640bd1f0b6aa774802f055d61`. Its accepted
tree `aa44de54df44a2640a437a5a10359615c50c28fe` exactly matches reviewed
head `d191dca5` and tested checkout `33babe9e`.
[Godot/GDExtension](https://github.com/techrote/cybersand/actions/runs/40634055217),
[Native](https://github.com/techrote/cybersand/actions/runs/40634055249),
[Documentation/provenance](https://github.com/techrote/cybersand/actions/runs/40634055172)
and a distinct [source/artifact review](https://github.com/techrote/cybersand/pull/284#pullrequestreview-5679054535)
passed. Both Windows and Linux completed **50 real host lifetimes and
1,165 assertions, zero failures**: ten lifetimes per SetP rig, with every
exclusive worker joined and final main-thread Rapier session retired.

The [actual-host helper](../../godot/tests/play_life001_shared_host_case.gd)
checks course/actor/terrain acknowledgment, native and Rapier clocks, real
keyboard button edges, focus cancellation/rearm, pause/resume, fresh reset
identities, immutable earlier snapshots and final retirement. Earlier
`294122c0` results retain their historical source identity; this combined
source received its own execution. This is bounded normal-lifecycle evidence,
with zero solver-reconstruction cycles and no slow-native injection.

**Open qualification:** #266 has accepted source-bound native participation and
repeated reference measurements through [PR #285](https://github.com/techrote/cybersand/pull/285),
as defined by the [threading contract](../architecture/simulation-tick-and-threading.md#play-native-worker-observation-and-reference-measurements).
The actual course control still reports max jobs one and zero parallel phases;
reference timing does not supply gameplay pacing or concurrent-execution proof.
#268 retains integrated selection and
complete device/focus/pacing requirements; #269 retains adversarial pending
work, delayed completion, failure recovery and populated stale-command stress.
#270 joins those gates with actual desktop frame/snapshot timing and human
gameplay feel. Headless lifecycle success does not establish any of those
remaining outcomes. Main-thread Rapier, per-material construction-time solver
selection/refusal and specialist-fixture isolation remain unchanged.

## Actual-host solver reconstruction regression

**PLAY-LIFE-002 / #269 bounded regression:** the
[actual-host helper](../../godot/tests/play_life002_solver_case.gd) extends
the accepted lifecycle apparatus with five separate real SetP/main-host cases.
Each rebuilds Water to `pressure_flow_v1/reference`, resets that policy,
rebuilds to Current defaults (`freemass_v1` Water), then resets again.
Requested/applied native envelopes, policy and construction receipts, authored
recipe, newer actor/World/session identities and terrain acknowledgment are
checked, together with old Rapier retirement and retained immutable snapshots.

Each policy cohort also refuses the controlled actor-free route and submits an
unsupported Oil/pressure request through the public host API to the actual
worker/native transaction. Refusal closes the separately staged graph and
retains the accepted actor/World/receipt; the native and physical clocks and
primary input work afterward. These checks do not seed an outstanding old
command/lap immediately before replacement, inject delayed native work or test
failure recovery.

The [dated source/evidence audit](../audits/2026-10-28-play-life002-solver-reconstruction.md)
preserves the earlier local Windows proof and initial LFS pointer/import failure.
Fresh [Windows/Linux Godot execution 40751990374](https://github.com/techrote/cybersand/actions/runs/40751990374)
at source `0a17fd97`, tree `6fa58f168e93a64712f36706369e1f30f31232cb`,
passes **335 assertions / zero failures per OS** in five real processes:
ten policy changes, ten retaining resets, twenty explicit refusals and five
exclusive GDScript owner joins/final Rapier retirements per OS. The retained
worker reference means this join assertion does not independently observe native
pool destruction. Source review, final Native/Docs results, artifact readback and
the accepted-tree merge receipt are recorded on [PR #287](https://github.com/techrote/cybersand/pull/287).
Those gates remain distinct from this Godot execution result. No solver default,
live hot-swap, broader lifecycle or release acceptance is implied.

## Actual-host prepared-construction teardown regression

**Current PLAY-LIFE-003 / #269 test implementation:** the
[actual-host helper](../../godot/tests/play_life003_prepared_shutdown_case.gd)
holds a supported reconstruction at the existing native-prepared/physical-ready
precommit barrier. At least seven completed Main callbacks must progress before scene
exit; a bounded synchronization-only helper releases after the owner stop fence.
The actual accepted/staged Rapier graphs retire, the exclusive GDScript owner
joins, and only then may the test inspect the unchanged applied native receipt
and retired preparation token. Dropping retained references must destroy both
worker and native adapter objects, extending earlier joined-thread assertions.
The helper uses nonblocking Boolean `Mutex.try_lock()` so contention cannot
prevent deadline checks. A separate post-join arm holds the real worker mutex
on main, requires safety release without acquiring it, then always unlocks
before joining. Only this adversarial arm uses a 25 ms helper budget; actual
pending-construction shutdown retains 15,000 ms.

The [dated audit](../audits/2026-10-28-play-life003-prepared-shutdown.md) preserves
the original `22900486` local 135/0 proof, the later boundedness finding and
corrected-source `cd5f2ce5` 150/0 proof separately. Clean non-forced integration
`9782693c` consumes accepted #287/#288 main and receives its own local Windows
**150 assertions / zero failures**: five real hosts, five stop fences/joins,
ten Rapier graph retirements and five worker/adapter destructions, plus five
contended safety releases. Earlier results are not relabeled as this source.
Track final exact-head Windows/Linux, Native/Docs, independent review and
accepted-tree receipts on [PR #289](https://github.com/techrote/cybersand/pull/289).
Those gates are distinct from local proof. This covers pending construction
cancellation; it does not hold native simulation jobs, inject a slow native
tick, observe an OS native-thread join trace, measure rendered pacing or supply
human feel. #269/#270 stay open.

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

**Accepted PLAY-UI-004 shared-course event slice:**
The normal desktop scene attaches a small main-thread
[gamepad event bridge](../../godot/scripts/playable_course_gamepad_events.gd).
When the existing course/human SetP capability gate is active, unhandled A/B/X
press and release events from the first connected pad invoke the existing
`publish_actor_keyboard_input` path immediately. This lets its existing bounded
physical-session FIFO retain a short tap between physical callbacks, rather
than relying only on the next polled state. Controls receive events first;
other devices, unmapped buttons and non-course/specialist configurations are
not intercepted. Focus, pause, reset, rearm, equipment and epoch authority stay
in the original host; the bridge never steps or owns any simulation object.
Analog stick/trim polling and standalone scene behavior are unchanged.

The [focused fixture](../../godot/tests/test_play_ui004_gamepad_events.gd)
uses genuine Viewport events and physical-session/Rapier steps, with a disclosed
synthetic selected-device index and test host publisher. It verifies ordered
button pairs and a matched no-event/poll-only negative control, not a physical
controller, the complete desktop focus path or interactive feel.
[PR #286](https://github.com/techrote/cybersand/pull/286) merged as
`e076819e086abb762796303b830314e330f87234`; its source-matched Windows/Linux
fixture passed **32 assertions per OS**. The later combined #284 suite
preserves that fixture. The
[dated candidate audit](../audits/2026-10-28-play-ui004-gamepad-events.md)
records the gap, test boundaries and integration obligations.

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
