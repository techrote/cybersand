---
title: Player control playground
status: Current
document-kind: contract
scope: Experimental seven-preset human movement course, shared mechanical control, bounded native Sand and Water fields, input lifetime and qualified validation
canonical-for: [player-control-playground, player-movement-presets, player-material-field, playground-cyberpunk-maps]
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
1024 Ã— 768 districts combine ramps, low tunnels, flight routes, landing decks,
material apparatus and usable targets in one native world. The original
512 Ã— 256 course is retained only as an explicitly selected `legacy` test fixture.
Four ordered checkpoints give each map
a route and a simulation-time lap counter. The timer starts when active movement
or action input is admitted, including a quick press/release before the next
physics tick. Elapsed time advances only with simulation ticks and continues
while coasting with neutral input. Best times are kept only during this scene's
lifetime. Authored routes and
checkpoint detection do not establish that every route has been completed.

## Seven tailored maps, Water selection and painting

**Current branch implementation, local Windows qualification:** the independent
**Map** selector offers Flood Market plus these seven focused districts. Every
selectable map has six times the first sample's area, with multi-level
structures, alternate paths, editable targets and varied building/material
samples. Each has a distinct authored topology and skyline, a clear start
promenade, substantial liquid stores and three movable Rapier props. The old
shared blocking service bay is removed.
Every map is selectable with all seven players; the suggested player describes
the emphasis, not an admission restriction or proof of complete traversal.

| Map ID / displayed name | Suggested player | Exercise |
|---|---|---|
| `mixed` / Flood Market | All players | Covered bazaar, dry market street and courier rooftops |
| `cannon_run` / Quarry Rally | Loose Cannon buggy | Broad ascent/crest, suspended road, flooded excavation and ore conveyor |
| `rat_steps` / Terraced Aqueduct | Trials Rat bike | Incremental climb, timber balance shelves, arches and cistern plumbing |
| `afterimage_works` / Textile Mill | Afterimage acrobat | Optional slide vent, loading street, staggered roofs and cloth spools |
| `vector_port` / Crater Port | Vector Rush lander | Open launch volume, asymmetric gantries and ballast stores |
| `dust_foundry` / Inverted Foundry | Dust Devil Sand cloud | Breakable hopper throats, hanging combs and discharge terraces |
| `undertow_lab` / Filtration Cathedral | Undertow Water blob | Stone/glass arch, copper organ, filter gallery and three deep cisterns |
| `rocket_yard` / Silo Facility | Barrel Rocket | Nested launch wells, cantilever pads, coolant farm and bunker road |

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

Choose Sand, Water, Oil, Brine, Smoke, Fire, Lava, Acid or Wall and a **1â€“12 cell
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
disabled cadence LOD and copied initial player/NPC/prop body states. Public
material-player maps use the same private physics host for props and NPCs; the
hidden legacy material fixture remains the old body-free test owner. It records a tick-zero native setup receipt covering the map
and initial swarm seed. Receipts identify the initial setup, not later painting.
A failed candidate leaves the live owner and accepted selections in place.
This synchronous playground route does not close #202/#203 full-host acceptance.

Sources: [map definitions](../../godot/scripts/player_playground_course.gd),
[large district authoring](../../godot/scripts/player_playground_districts.gd),
[native setup](../../godot/scripts/player_playground_world.gd),
[exclusive authoring owner](../../godot/scripts/player_playground_runtime.gd),
[scene controls](../../godot/scripts/player_playground.gd) and
[dated qualification](../audits/2026-10-26-player-playground-maps.md).

## Cyberpunk Backchannels

**Current experimental branch source, PR #262:** seven additional cyberpunk maps
bring the public selection to 22. Each remains 1024×768 and is available to every
player. Suggested players identify a focus, without locking the map or solver.
The [dated cyberpunk checkpoint](../audits/2026-10-26-player-playground-cyberpunk.md)
records actual source/platform evidence and the remaining qualification limits.

| Map | Suggested player | Place and mechanical focus |
|---|---|---|
| Debtline Interchange | Loose Cannon | Connected repair halls, toll block, rising interchange, supported launch crest and braking court |
| Patchbay Tenements | Trials Rat | Linked apartments, washing galleries, repair terraces, shallow transfer court and communal bath |
| Afterhours Arcade | Afterimage | Aquarium frontage, cutaway arcade, compact service passages, standing repair bay and night street |
| Zero-Stamp Customs | Vector Rush | Inspection canyon, numbered bays, supported customs hall and broad recovery courts |
| Last Byte Reclamation | Dust Devil | Pawn/scrap rooms, scored side seal, lateral granular sorting arcade and catch |
| Rain Ledger Exchange | Undertow | Exchange halls, large separate Water/Brine stores, stepped channels and vented shared catch |
| Pirate Uplink | Barrel Rocket | Rooftop relay rooms, irregular dishes, open flue gaps, lateral hatch and recovery roofs |

Native-cell lettering, repair seams, glazed service bays, supported building
shells and actual cutaway air rooms provide denser environmental detail. There
are no new electrical, hacking, navigation-AI or simulation systems hidden behind
signs. Large liquid stores and three real Rapier props per map retain native
material behavior and the existing physical host. Glass Scorer opens marked
Water drain plates; Reclamation's glass side seal also uses Glass Scorer.
Foundry/Baths' plywood Sand stoppers use Line Cutter. Use tools while unpaused,
with Paint tool and Place NPC disabled; reset restores the authored setup.

The post-Expedition review also gives Market facades actual footings, Port's
suspended signs deliberate supports, restores Water displaced by the Cathedral
pier, and opens a real first-tray chute to Foundry's second comb and catch.
Shared road clearance, full wheel routes and body/receipt checks remain the
same acceptance criteria. Optional challenges are separately tested; a staged
feature proof does not establish a complete expert route from default spawn.
Afterhours' demonstrated ordinary-spawn expert route includes one ordinary hop
in the repair bay to unfold after sliding; neutral/brake alone did not restore
full physical height. That automatic recovery remains a known control limit.
The new7 comparison maps use already-rusted steel in place of bare iron: the
existing fractional Water/bare-iron rust reaction can replenish Water quantity.
Its retained reproduction and source explanation belong to the dated audit;
no native correction or universal material-contact conservation is claimed here.
Reclamation's lower Oil store is below the road and requires excavation access.
Source-palette composition review is distinct from rendered appearance and
human-feel acceptance. Web/browser/shader testing stays owner-deferred.

Sources: [collection router](../../godot/scripts/player_playground_cyberpunk.gd),
[street maps](../../godot/scripts/player_playground_neon_streets.gd),
[works maps](../../godot/scripts/player_playground_neon_works.gd),
[bounded signage and road helpers](../../godot/scripts/player_playground_neon_detail.gd).


## Expedition collection and second district review

The reviewed Expedition checkpoint at 1451e5a7 introduced these seven maps
alongside the original eight districts. The current 22-map picker also includes
Cyberpunk Backchannels below. Every player can select every map;
map/player/Water defaults and preparation contracts are unchanged. All are
1024×768. The [dated Expedition record](../audits/2026-10-26-player-playground-expeditions.md)
separates actual Windows physics, source-derived composition review and remaining
human/hosted qualification.

| Map | Suggested player | Structure and challenge |
|---|---|---|
| Stormbreak Viaduct | Loose Cannon | Coastal overpass, service yard and lighthouse road |
| Rootbound Conservatory | Trials Rat | Greenhouse nave, timber roots and graded irrigation bridge |
| Prism Archive | Afterimage | Descending gallery, open atrium, compact passage and excavation vault |
| Eventide Station | Vector Rush | Mountain saddle, inspection courts and asymmetric weather mast |
| Buried Baths | Dust Devil | Broken bathhouse, real cuttable Sand stopper, grille and catch trough |
| Saltglass Sinkhole | Undertow | Karst terraces, two deep stores and open side-cavern apertures |
| Starfall Amphitheatre | Barrel Rocket | Offset seating, open auditorium and irregular flight scenery |

Each adds three loose Rapier props, two clear NPC stages and large liquid stores.
Marked glass drain plates connect stored Water to a visible release channel.
Select **Glass Scorer**, aim at the glass and use **M** while unpaused. Reset
restores the store. The Baths' Sand stopper uses **Line Cutter**. These are real
material/tool interactions, not decorative completion switches. Props and NPCs
use the existing shared physics host and capacity/refusal semantics.

The second review also adds district-specific recovery shelves, receiving trays,
filter galleries, clear flight landing space and rooftop/service details to the
original eight. Optional upper routes have separately scoped tests; a staged
compact-passage proof does not prove an entire expert lap from default spawn.
Source-derived raster review uses the native palette but does not qualify the
rendered shader or interactive appearance. The subsequent cyberpunk collection follows this review and its separately
qualified 15-map checkpoint; its final source/evidence is described above.

Sources: [Expedition maps](../../godot/scripts/player_playground_expeditions.gd),
[district maps](../../godot/scripts/player_playground_districts.gd),
[shared selector](../../godot/scripts/player_playground_course.gd).

## Detailed districts, live NPCs and agile Afterimage

The [polish checkpoint](../audits/2026-10-26-player-playground-polish-and-npcs.md)
replaces the repeated map composition. The eight districts use 243–403 authored
rectangles and 33–43 materials each. Every map has a clear flat first promenade
with 112 cells of headroom, deep Water and other-liquid stores, clear prop stages
and NPC placement stages. Six retain a lower dry bypass; the quarry and aqueduct
instead use intentional broad grades and recovery ramps. Road-height baseline
checkpoints stay on the universal route; upper focus frames are optional. Glass
reservoir valves and the foundry throat/grates now support actual usable-driven
release and powder-flow challenges. Actual ordinary-throttle tests
prove both wheeled presets exit all eight starts; full routes and human feel
remain separate acceptance.

Enable **Start with an NPC** to rebuild with one demo actor. Choose **Runner**,
**Skimmer** or **Crawler**, then use **Spawn NPC at a clear starting stage** or
enable **Place NPC** and click the map. Placement also works while paused and
uses the current overview/follow coordinates. It refuses occupied terrain,
liquids, existing body bounds, out-of-map geometry and capacity exhaustion.
Spawning preserves the current player, World, edits and clocks; it marks a
practice lap. Reset clears appended actors and restores three loose props.
NPCs use the existing local feedback demo controls, not general pathfinding.

Player, NPCs and props share one native World, one private Rapier space and one
step of each per frame. The physical roster is append-only until reset, limited
to eight actors and 64 total bodies including props/equipment. Material players
do not consume a physical actor slot. Old body IDs, leases and equipment
identities survive append. The initial prepared receipt includes initial NPCs
and props and remains immutable; copied roster revisions and spawn receipts
identify later additions. Installing a new body mask can change wake/pressure
cache state even without a tick; spawning is not identical physical continuation.

Afterimage uses **Ctrl** for cancel/brake and held air glide. **Shift/S + Space**
still performs the bullet jump. The other six players retain **C**, and gamepad
X remains the auxiliary button. A higher jump, stronger finite ground/air drive,
opposed leg gait, counter-rotated feet and faster bounded joint commands improve
agility through real Rapier bodies. The local fixture measures a 1.45× apex
increase while preserving air inventory and actual low-tunnel passage.

Dust Devil and Undertow keep an exactly stationary field anchor under neutral
input. Their local circulation compensates repeated satellite loft instead of
raising the whole cloud. Only admitted directional input can follow observed
material by at most four cells per step; cancellation/lease expiry removes field
assistance. All six Water laws conserve the seeded 65,280 quantity and stay within
the static circle in the registered 360-tick neutral fixtures. Radius 60 describes
bounded influence, not an impermeable material-ownership boundary: arbitrary
painted, saturated, obstructed or reacting material has no universal containment
guarantee. Native chemistry and transport remain authoritative.

## Stronger player controls and usable testing

The [expanded checkpoint](../audits/2026-10-26-player-playground-expanded-and-usables.md)
records actual local Windows execution and retained first-pass failures. These
are authored player-control changes, including F5 SetP for mechanical players:

- Loose Cannon and Trials Rat lean using bounded tangential impulses around
  the actual rear wheel plus attached-part torque. No body transform is set or
  wheel pinned to a world position. Requested angular speeds are 11/12 rad/s,
  capped accelerations 90/95 rad/sÂ², with rider lean up to 0.86 rad. Rapier's
  contacts and joints still determine the resulting motion.
- Both vehicles multiply their former upward hop impulses by âˆš2, targeting
  approximately double ballistic height under unchanged gravity. Actual flat
  fixtures measure 1.91Ã— buggy and 1.95Ã— full-preload bike height. Bike charge,
  support, release and cancellation rules remain intact.
- Vector Rush uses gravity 96 cells/sÂ² in damped mode and 32 in drift; C still
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

Five mechanical presets also appear in **F5 â†’ Rapier â†’ SetP**, among the
46 retained physical actor IDs and original eight sets. The separate 4LY
free-flight family appends a ninth **F5 â†’ set4LY** selection group without
renumbering SetP or replacing this dedicated player playground. They reuse
the shared physical session, controls and optional equipment lifecycle in exploratory maps.
Dust Devil and Undertow are available only in this separate playground; they
control native material and have no Rapier actor definition.

Sources: [scene owner](../../godot/scripts/player_playground.gd),
[course and displayed controls](../../godot/scripts/player_playground_course.gd),
[mechanical catalogue](../../godot/scripts/player_actor_catalog.gd) and
[launcher](../../godot/scripts/feature_launcher.gd).

## Keyboard controls for all seven presets

In `--player-playground` (optionally `--player=ID`), use 1â€“7 or Tab/Shift+Tab
to select, R to restart, P/Escape to pause, F for overview/follow, and F2 for the
launcher. These scene controls accompany the movement actions below.

| Key / ID | Preset | Movement and actions |
|---|---|---|
| **1** / `stuntbuggy` | **Loose Cannon** â€” loose-jointed stunt buggy | W/S drive/reverse; A/D or Q/E lean and rotate in air; Space hops from support; Shift brakes; hold C for recovery assistance. Sprung wheels and a hinged rider carry the motion. |
| **2** / `trialsbike` | **Trials Rat** â€” trials bike | W/S throttle/reverse; A/D or Q/E lean; hold Space while supported to preload, then release to hop; Shift brakes; hold C for recovery assistance. The rear wheel drives and the front wheel rolls freely until braking. |
| **3** / `acrobat` | **Afterimage** â€” momentum acrobat | A/D run and steer in air; Space jumps, then double jumps; hold Shift or S to slide; tap Shift to roll; Shift+Space or S+Space bullet jumps; Ctrl cancels/brakes and, held in air, glides. Mouse position aims bullet jumps. |
| **4** / `arcadelander` | **Vector Rush** â€” arcade lander | W or Space fires the body-axis main engine; A/D or Q/E rotates; S gives reverse thrust; Shift applies a strong airbrake; tap C toggles damped flight/coast. |
| **5** / `dryswarm` | **Dust Devil** â€” Sand cloud | WASD guides actual Sand; Space surges in the movement direction, or upward from neutral; Shift spreads; C gathers. Neutral admitted input keeps the cohesion/loft field active. |
| **6** / `liquidswarm` | **Undertow** â€” Water blob | WASD guides actual Water; Space surges; Shift squeezes transverse to travel into a stream; C gathers. Neutral admitted input keeps the cohesion/loft field active. |
| **7** / `jetbarrel` | **Barrel Rocket** â€” barrel with jetpack | W or Space fires the body-axis jet; A/D or Q/E provides strong rotation; S gives reverse thrust; Shift brakes; hold C for upright assistance. |

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

- **Run â†’ slide â†’ bullet jump:** gain speed with A/D, hold Shift or S to tuck,
  aim with the mouse, then press Space. Grounded bullet jumps include an upward
  component; faster velocity already aligned with the launch is retained.
- **Jump â†’ double jump â†’ roll â†’ glide:** Space gives the ground jump and one
  airborne jump. Press Shift in air for the separate air roll. Hold Ctrl near the
  apex or while falling to reduce descent while steering with A/D.
- **Roll â†’ jump cancel:** press Space during a roll to leave it using an
  available jump. If Shift/S remains held, the same press requests a bullet
  jump first while that separate launch is available. Release crouch for an
  ordinary jump cancel.
- **Slide/roll â†’ brake cancel:** press Ctrl to end the slide or roll. On support,
  Ctrl brakes; slide stays suppressed until crouch is released. Releasing Space
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
| 1â€“7 or preset buttons | Select a preset and construct a fresh session, retaining map and Water selections |
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
reactions. All public presets share the existing synchronous physical arena and
its main-thread Rapier session for NPCs and props. Neither lane borrows the asynchronous
sandbox worker's World.

`World::apply_player_material_field` moves complete stored cells through
`relocate_stored_cell`, preserving compact state, temperature and exact partial
Water quantity within that call. It does not erase/repaint the cloud, create
per-cell physics bodies, or introduce a Water pressure/flow rule. The next normal
tick can redistribute Water and apply ordinary interactions. A field therefore
does not promise conservation across unrelated chemistry or authoring actions.

Selection is **matching material within a local radius**, not a persistent
collection of owned particles. Nearby environmental Sand/Water can join; material
that leaves the field is no longer controlled. With directional input only, the
field follows its sampled quantity-weighted centroid by at most four cells per
step. Neutral input keeps the anchor exactly fixed. WASD moves
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
