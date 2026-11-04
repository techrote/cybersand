---
title: Lightweight flight fleet for granular owner review
status: Current
document-kind: contract
scope: Developer-only eight-flyer authoring and compound Scooper, repeatable spawn, compact controls, staged LA budget and actuators, bounded material sources and separate qualification limits
canonical-for: [granular-review-flight-fleet]
last-reviewed: 2026-11-04
related-documents: [../architecture/granular-contact-rest.md, ../architecture/compound-granular-coupling.md, player-control-playground.md, ../operations/gcr-rest-registration.md, ../operations/gcr-authored-compound-registration.md]
---

# Lightweight flight fleet for granular owner review

## How do I author or reload a flyer, including Scooper?

**Current experimental source:** eight bundled flyers use named definitions in
[godot/authoring/flyers/manifest.json](../../godot/authoring/flyers/manifest.json).
Each listed JSON file owns stable id/name/colour, a rectangle or rectangle union,
actual mass, controller mode, actuator settings and optional dispensers. The
existing seven keep their original physical scalars and controller arithmetic;
Scooper is the eighth entry. This review roster is separate from the ordinary
player presets and46-actor catalogue.

To make a comparison:

1. Edit one definition, or duplicate a JSON file with a unique id and add its
   filename to the manifest. The first seven stable ids keep their order.
2. Save a suitable **Reset spawn** or use **Use flyer**. Select a response and
   Apply the desired comparison multipliers.
3. Click **Reload + reset**. Validation reads the files once, then constructs
   the selected stable id at the saved spawn using the applied settings. Invalid
   authoring or construction refuses while retaining the old owner and admitted
   catalogue. Reload does not change a live motor or hull in place.
4. Compare landing, burial, off-centre Burst/Stream, powered contact and, for
   Scooper, lifting/carrying/tipping. Keep response, budget, mass and inertia
   settings equal when isolating one change.

The manifest admits at most16 flyers, each with at most8 nonoverlapping local
rectangles within128-cell overall dimensions. Files are bounded to16KiB each.
Unknown fields, nonfinite/range errors, overlapping rectangles and duplicate ids
refuse. File I/O occurs only at load/reload; physics consumes cached copied
definitions. The canonical content hash of each validated definition is copied
into the constructed profile and receipt; Details identifies the flyer and
registry hashes. **1–8** selects the bundled roster; Tab and roster buttons use
the current admitted count. The [configuration reference](../reference/configuration-reference.md#authored-flyer-and-compound-capacities)
owns field ranges, and the [registration](../operations/gcr-authored-compound-registration.md)
keeps implementation, mechanical gates and physical qualification separate.

Scooper follows Afterglow's world-axis W/S rise/descend, A/D strafe, Space lift,
Shift boost and Ctrl brake. Q/E commands a target of±1.2rad, about±69°, to allow
deliberate tipping/spilling; releasing Q/E requests level again. Its mass is0.18,
with uniform-area inertia approximately22.10 before developer overrides. Its
attitude gain40, angular damping12.5, angular-acceleration cap48 and torque
ceiling1200 are bounded authored motors. Afterglow retains10/4/12/36 and±0.4rad.
The linear acceleration125, speed95, slew4, drag0.55 and force ceiling23 retain
the Afterglow baseline. Stronger torque compensates for Scooper's actual larger
inertia; it does not strengthen the granular material law or grant a new budget.

One actual Rapier body carries six collider rectangles: thin deck, rear stop and
stepped leading penetrator. Graphics and native occupancy/contact/ejection use
that same COM-centred union. The cavity is open; no bounding rectangle is added
as solid material or another response. Mass, COM, inertia and response budget
belong to the body once. Carried material remains ordinary native cells that
can load the deck, move and spill, rather than an inventory or detached payload.
The [compound ownership contract](../architecture/compound-granular-coupling.md#authored-compound-review-bodies)
owns the new admission and the separate structural-detachment boundary.

The new native implementation requires source-matched Windows/Linux runtimes
with89 production inputs; the earlier88-input libraries cannot supply this API.
The current build cohort is native source
`3df1279f799230bafdc7a34766eb2995bf4ae69b`. It retains the no-catch receipt
accounting correction and adds bounded authored translation entry-side ejection;
the response law and bridge guards are unchanged.
The [dated Scooper record](../audits/2026-11-04-authored-compound-scooper.md)
keeps original failures, source-matched builds, mechanical controls and the
48-case Windows/Linux physical population separate from final-head execution
and owner gameplay acceptance. No sleep, material-law tuning, production
promotion or merge follows from adding the authoring workflow.

## Why can Scooper lose powder through its thin deck while moving?

The [carried-material diagnosis](../operations/gcr-scooper-leak-registration.md)
separates temporary native/current-pose overlap, open-rim spill and genuine
far-side relocation. When a2-cell deck moves across a grain, the current nearest
face can become its bottom; the old ejection then pushes carried material down
through the deck. Current experimental source preserves a unique translated
entry side in explicitly authored compounds, using valid consecutive samples,
unchanged orientation/size and the existing sweep bound. Previous-union overlap,
rotation, another crossed proxy or seam ambiguity retains the old rule.

The [source-bound qualification](../audits/2026-11-04-scooper-carried-material-leak.md)
reproduces the defect and eliminates persistent through-deck escape in selective
full/boost and event-off full level rises on Windows/Linux at unchanged peak
speeds. Independent-body controls retain their old outcomes. Diagonal/corner
and open-edge carrying remain distinct; this is not general rotational collision
detection or guaranteed load retention. Source-sensitive tests and owner review
remain separate. No friction, motor, sleep or production-default change follows.

## Saved spawn, Burst key and compact comparison controls

**Current source:** the normal painting room has **Reset spawn X/Y** fields and
**Use flyer** to capture the current authoritative Rapier centre, rounded to the
same0.01-cell authoring precision as the fields. Saving a point
does not move the live flyer. **R**, craft selection, **Apply + reset** and return
from a canned test construct a fresh upright, stationary flyer at that point.
The saved point survives response/budget/property changes and **Defaults**;
**Default spawn** separately restores(178,304) for the next construction.
This memory lasts for the room scene's lifetime; F2/new scene or process restart
does not load it from disk. Edited X/Y values take effect on the next reset or
selection. The live applied receipt identifies the saved construction centre.

Spawn admission requires finite coordinates and the complete upright selected
hull inside the inner walls(x22..1002, y22..475), clear of authored hard platforms.
An invalid point or a point unsuitable for a larger selected craft refuses the
new construction and keeps the current owner. Granular overlap remains available
for exploratory setup; the tool does not erase material, relocate an existing
body or guarantee a quiet initial contact. The ordinary actor arena keeps its
previous admission bounds. The fixed-Kestrel powder fixtures still start at
(512,256); they do not overwrite the saved normal-room point.

Press **B** for a live powder burst. It uses the placed source, or attempts to
place one above the flyer using the current granular palette if none is armed.
One non-repeated key press queues at most one burst; holding B does not repeat.
It may queue while paused, with material added only when simulation resumes.
B is suppressed while editing numbers, while the window is unfocused and in the
isolated powder fixtures. The **Burst [B]** button remains available. Non-text
review clicks preserve held flight input; numeric editing cancels input and
requires neutral rearm. Window focus loss, pause and reset retain cancellation
and source lifetime rules. The inherited mouse cancellation no longer makes a
Burst click force the pilot to release held thrust before continuing.

The room uses dense wrapping toolbars: count-driven small craft buttons, response and
six property fields, reset coordinates, Fire and live sources. Nominal text is
12px and buttons24px high; the canvas occupies the full width beneath them.
**Details** expands the craft description, controls, runtime/source identity and
fixture explanation; it starts collapsed. Palette/brush controls and concise
applied/source counters remain visible. This is a room-scoped arrangement, not a
global player UI or material-law change. Source is
[gcr_fleet_playground.gd](../../godot/scripts/gcr_fleet_playground.gd), especially
`_build_ui`, `_input`, `set_spawn_position`, `capture_spawn_position` and
`select_preset`; construction is
[configure_review_fleet](../../godot/scripts/player_playground_runtime.gd).
Source availability is separate from exact-head host execution and owner feel
acceptance. Sleep and all granular response/material laws remain unchanged.
The [dated qualification record](../audits/2026-11-04-repeatable-flight-spawn-ui.md)
keeps original preflight failures, source distinctions and final-head PR routing.

## Shift thrust multiplier, Ctrl brake and painting-room powder sources

**Current controls; earlier integrated Windows/Linux checkpoint passed:** the fleet
room moves its previous Shift brake to **Ctrl**. Hold **Shift** for the staged
**Shift thrust ×** multiplier, default2 and range1..8. Apply/reset commits that
setting with the existing base thrust/torque ceilings. The multiplier scales
requested main and side propulsion and the active force ceiling; it does not
multiply torque, hoverboard gravity compensation, passive drag or speed damping.
Ctrl/brake takes precedence. Releasing Shift restores base propulsion; gamepad B
retains braking. These bindings are scoped to the flyer review room, not every
player/controller preset.

Shift travels as an optional boolean beside the existing q/e/s review ports,
bound to the accepted command's epoch, generation, sequence and lease. The shared
actor action schema is unchanged. Cancellation, lease expiry, pause, focus loss
and replacement retire the modifier; controller/native workers do not poll Input.

For a live source in the normal painting room:

1. Choose any of the eight bundled flyers and one of the nine granular materials in the
   palette: Sand, Dust, Rust, Stone, Seed, Salt, Sodium, Gunpowder or Coal.
2. Enable **Powder source**, or click **Place above flyer**.
   Placement captures that palette material and places the source48 cells above
   the rotated hull's top. It stays fixed in world space as the flyer moves.
3. Press **B** or click **Burst [B]** for a four-column,24-row request, or toggle
   **Stream ≤10s** for four source-cell requests per simulation tick, for at most600ticks.
   Enabling another stream interval requires an explicit toggle after cutoff.

These live sources preserve normal gravity38, pilot control, the full flyer
roster and manual painting; they do not reset the room or force Kestrel. Changing
the palette alone does not silently change an already placed source: place it
again to capture the new material. Water, hard wall and erase are not admitted as
powder-source materials. Placement must fit the complete source within the room;
it refuses rather than clamping the source through a boundary.

Sources start off. Reset/Apply, craft selection, leaving the room or entering a
canned comparison disarms them. Pause freezes the source clock; focus loss
disarms it. Repeated Burst clicks coalesce into one pending request. Empty-cell,
current-hull, native-mask, hard-terrain and bounds checks prevent overwriting or
emitting through objects. Actual attempted/inserted/blocked counts remain exact;
a256-row ring retains recent diagnostic edits and reports dropped rows. Sources
are explicit external material authoring, with no new recoil or arrival authority.

The **Burst test** and **Stream test** buttons under **Isolated Kestrel fixtures**
remain separate fixed-Kestrel, zero-body-gravity comparisons (previously labelled
Powder burst / Continuous stream · reset paused).
Their no-pilot setup and prior qualification are not replaced by these live tools.

The edge-alignment repair makes overlay and painting coordinates use the actual
TextureRect texture footprint. The992×480 output differs in aspect from a512×256
follow sample; fitting the latter had compressed the overlay horizontally and
shifted both edge positions inward. Physics poses and native cells do not move.
The existing small terrain anisotropy/non-integer scaling remains; this is not
GPU, pixel-perfect presentation or general physics acceptance.

The owner's earlier4 November feedback explicitly concerns **LA/A1**: ordinary landing,
reactive contact torque and Dust burial feel improved; Sand/Rust/Coal burial still
starts sinking. Powered Afterglow tunnelling is considered potentially useful
gameplay. Relative material/flyer mass is a hypothesis, not a demonstrated cause.
The cropped images lack full selector/source receipts. Record this positive
qualitative judgement without asserting complete production-envelope acceptance
or acceptance of the separately failed selective candidate.

In the later three-response owner comparison, ordinary landing/resting is safe
in all three with minimal idle motion. LA/A1 sinks under burial and reacts too
strongly to falling material; events off avoids reported burial but gives weak
incoming loading. Selective arrivals also avoids reported burial and gives the
preferred loading/deflection: small flyers are torqued aside while larger ones
can resist a load and lift with boost. Powered resistance is satisfactory in
that review. These are qualitative owner observations without full new
source/settings/trajectory receipts; they do not erase the earlier registered
selective NO-GO or close the production envelope. The relative-loading cause
still requires measured attribution.

The [dated control/alignment record](../audits/2026-11-04-flight-review-controls.md)
records owner feedback, source identities, scoped checks and remaining limits.

## Repeatable powder burst and continuous-stream review

**Current source; Windows/Linux host controls passed:** the painting playground
provides two canned loading tests alongside the normal painting room.
The [dated UI record](../audits/2026-11-04-repeatable-powder-review.md) owns actual
source/runtime validation;6605 new Windows/Linux checks per platform now pass.
These controls do not repeat or supersede the earlier
scientific qualification or its registered NO-GO.

**Burst test** and **Stream test** reconstruct a fresh Kestrel
(craft3/index2) at position(512,256), angle0, with zero linear/angular velocity.
Both use an empty bounded test room and Sand2. The burst seeds four columns by24
rows at(514,224); the stream supplies a four-cell row at(514,224) before native
ticks0..599. The source stays fixed in world coordinates, so response-dependent
motion does not move the emitter to follow the craft. Emission counts actual
empty-cell additions and refused/blocked placements rather than assuming all
requested material was inserted. It cannot overwrite a foreign body or terrain.

The test starts paused. Press **P/Resume** to advance up to1800 fixed60Hz ticks,
then it pauses automatically. Body gravity is zero for these loading tests;
native material motion continues normally. Native construction and the one-shot
Rapier bridge context both receive zero body gravity before activation. Pilot
leases, Fire, Q/E/S dispensers and automatic control assistance are disabled;
neutral controller input is not used as a substitute for zero actuation.
Normal painting-room gravity remains38 and its manual controls remain available.

Select LA, events off or selective arrivals, then **Apply + reset** to repeat
the selected test using the same starting geometry and source schedule. **R**
also repeats it. Budget, mass and inertia multipliers stay at the applied values;
compare equal values across responses. The initial pose/material hash, actual
mass/inertia, selector and source-edit ledger are available in a test receipt.
This is a repeatable apparatus setup, not exact saved coupled replay.

Manual painting pauses and marks the run modified; reset the test before treating
it as a repeatable comparison. **Painting room** returns to ordinary editable
flight. Selecting another craft or restoring flyer defaults exits the canned test.
The retained RFT reference is available in free play; canned comparison admission
is limited to LA, events off and selective arrivals. No test outcome is labelled
as a scientific pass or owner acceptance. Sleep and material/response laws stay
unchanged, and all PRs remain unmerged.

The scene methods are `start_powder_test("burst"/"stream")`,
`return_to_painting()` and `powder_test_receipt()`. The receipt is copied diagnostic
value data for review, not another impulse or cell authority interface.

Current selective arrival result: [qualification](../audits/2026-11-04-gcr-selective-events.md)
records84 captures and a registered NO-GO: creep preservation, finite-batch recovery
and late edge rebound miss their gates. Continuous arrival/torque and excavation
release pass; no rest/default acceptance follows. The painting selector remains
experimental; source-lock compatibility and owner review remain open.

## Selective arrivals — implemented comparison with failed joint gates

The [selective event registration](../operations/gcr-selective-events-registration.md) owns the implemented fourth response **LA · selective arrivals** (LA-SELECTIVE; experimental). Use **Apply + reset** to construct fresh native authority; painted edits are discarded. LA remains initial/Defaults, RFT and event-off remain separate references, and the retained seven-flyer population, painting, physical/actuator controls, Fire and dispensers remain intact; Scooper has its own authored admission and qualification. The host requires native selective/arrival-witness acknowledgement; unsupported runtimes refuse. Test bank rest and powered contact separately from material falling onto one side of a craft. The84-capture qualification misses registered creep preservation, finite-batch loading/torque recovery and late operational edge-rebound gates. Continuous-stream response, excavation release and direct-paint exclusion pass. The candidate is retained for comparison under a registered NO-GO; no owner acceptance is claimed. Sleep, production-default promotion, latest-Astra compound acceptance and merges remain excluded.

## Granular-only event comparison — November4

The [registered event successor](../operations/gcr-granular-events-registration.md)
adds **LA · events OFF** (experimental) to the response selector. Select it and
use **Apply + reset**; this discards painted edits. It omits only granular
blocked-attempt impulses/torque/cost before passive recomputation. The legacy
contact gain and material laws remain. LA remains initial/Restore; RFT remains
the fixed20 reference. All existing physical and actuator controls are retained.

The [source-matched qualification](../audits/2026-11-04-gcr-granular-event-successor.md)
finds much less burial in Sand/Salt/Dust and the powered bank, with passing tested
barrel impact guards. Falling grains produce no measured translation/rotation
in the candidate control, and some late motion increases. The panel tooltip
flags this loading/torque gap, shows verified native source/binary and a room
script fingerprint, and refuses event-off construction on an old runtime that
cannot acknowledge the selector. Owner review remains pending. That dated physical cohort is an
independent-flyer comparison; the new authored Scooper route has separate gates,
and current Astra structural response remains separately owned.

The [dated host qualification](../audits/2026-11-02-flyer-budget-playground.md)
records the current tested application checkpoint, retained failures and native
SDK reuse separately from earlier physical qualification.
The [actuator/navigation follow-up](../audits/2026-11-02-flyer-actuator-limits-and-navigation.md)
records thrust/torque controls, F2 return routes and the cropped burrowing evidence.
The [November3 host record](../audits/2026-11-03-paired-material-plan-and-fleet-emissions.md)
binds side-thruster, dispenser and Fire controls to the tested application source.

## Which craft and materials are available?

**Current experimental desktop source:** `gcr_fleet_playground.tscn` provides the
seven retained flyers plus Scooper in an editable 992×480 room. The original fleet authoring
comes from `f7d611501c18425f7f06f0c874324113da78d8e7`; bringing that authoring
onto the current source does not inherit its old runtime qualification.

| Key | Craft | Intended handling |
| --- | --- | --- |
| 1 | Midge | Tiny nimble microscout |
| 2 | Needle | Fast narrow recon dart |
| 3 | Kestrel | Balanced agile explorer |
| 4 | Afterglow | Hoverboard with strafe and tilt |
| 5 | Surveyor | Broad scientific sampler |
| 6 | Cartographer | Slow-turning terrain scanner |
| 7 | Observatory | Lumbering sensor platform |
| 8 | Scooper | Open scoop; Afterglow movement, stronger stabilization and tipping |

Each craft has one actual Rapier body, no hidden equipment chassis and default
authored mass0.035..0.32. The original seven retain one rectangular collider;
Scooper uses six rectangles on its one body. The colliders match the hull outline;
sensor markings and lift lights add no physical mass. The room contains Sand,
Dust, Rust, Stone, Seed, Salt, Sodium, Gunpowder and Coal banks, stepped entries
and thin upper supports. The palette also offers Water, hard wall and erase.
These are native materials with their existing laws, not special treatment for
yellow Sand alone.

LMB paints, RMB erases and the wheel changes brush radius 2..24. F switches
overview/follow; P pauses. Space remains thrust/lift. Ordinary craft use W/Space
for body-axis thrust, A/D to rotate, S for reverse, Shift for the configured
thrust multiplier, Ctrl to brake and C for
upright assistance, with the Kestrel S exception below. Afterglow and Scooper use WASD to
strafe/rise/descend, Space for a lift burst and Q/E to tilt. Painting and
dispensers intentionally add/remove native material; this room is not a closed
conservation fixture.

## What do Q/E, Kestrel S and the Fire toggle do?

**Current experimental desktop source, 2026-11-03:** the room adds these
craft-specific controls. Left/right are relative to the craft's body axes, so
the ports rotate with the hull.

| Craft | Q | E | S |
|---|---|---|---|
| Midge | Left Acid dispenser | Right Lava dispenser | Reverse thrust |
| Needle | Left side thrust | Right side thrust | Reverse thrust |
| Kestrel | Left side thrust | Right side thrust | Gunpowder dispenser |
| Afterglow | Retained deck tilt | Retained deck tilt | Descend |
| Surveyor | Left side thrust | Right side thrust | Reverse thrust |
| Cartographer | Left Water dispenser | Right Water dispenser | Reverse thrust |
| Observatory | Left Lava dispenser | Right Lava dispenser | Reverse thrust |
| Scooper | Tilt deck toward−1.2rad | Tilt deck toward+1.2rad | Descend |

Needle, Kestrel and Surveyor request lateral acceleration at 0.65 of the selected
craft's authored acceleration. Main thrust, side thrust, drag and brake requests
share the existing combined force ceiling; side thrust does not add another
impulse budget. A/D still supplies yaw. Kestrel S no longer requests reverse
thrust; W+S can fly forward while dropping Gunpowder. Both Q and E dispenser
ports can be held together without cancellation by the signed steering axis.

**Thrusters emit real Fire** is a live developer checkbox, initially off. Its
selection survives room reset and craft selection. It adds ordinary native Fire
from active main/side thrusters when the controller has nonzero applied force,
positive effort and a nonzero thrust ceiling. It does not change force or torque,
create new chemistry, or enable Fire merely because brake/hover assistance is on.
Turning the option off stops new emission; existing Fire follows its normal law.

Dispensers are bounded native material sources without added recoil: at most
three one-cell, radius-zero emissions every six simulation ticks. Blocked or
missed opportunities do not accumulate into a later burst. A bounded direct ray
must be clear after leaving the source body's mask; foreign masks, occupied cells
and terrain block the nozzle. The target must still be Empty and unmasked at the
write boundary. There is no relocation search, overwrite or excavation to clear
a nozzle. These checks do not turn an actor emitter into a material-law owner.

Emission ports inherit the accepted actor command's epoch, sequence, generation
and lease. Cancellation, expiry, focus loss, numeric editing, pause and room
replacement stop emission through the existing input lifetime. Held dispenser
keys must be released before rearming after focus/edit/pause cancellation. This
room-only port path does not extend the ordinary actor action ABI or equipment
catalogue. Sources: [controller](../../godot/scripts/gcr_review_fleet_controller.gd),
[emitter](../../godot/scripts/gcr_review_fleet_emitter.gd),
[arena admission](../../godot/scripts/physical_actor_arena.gd) and
[room input](../../godot/scripts/gcr_fleet_playground.gd).

## How do I compare budgets and physical properties?

The developer panel defaults to **LA, budget 20, mass ×1 and inertia ×1**.
LA admits base budget 5..80, including the requested 20/40/80 comparisons.
The separate **RFT reference** retains the old GCR/R2 response and requires
budget 20. It does not reinterpret an arbitrary budget as the retained reference.

Both multiplier fields admit 0.01..64. For authored mass `m0`, width `w`, height
`h`, mass multiplier `M` and inertia multiplier `I`, construction uses actual mass
`m = m0*M` and actual inertia `m*(w*w+h*h)/12*I`. Inertia therefore scales with
the changed mass before the independent inertia multiplier is applied. These
are visibly experimental actor overrides; they do not rescale detached buildings
or rewrite their payload-derived properties.

Values remain staged until **Apply + reset**. Applying rebuilds both the
current craft and terrain, discarding painted edits. Keys 1–7, Tab and R also
rebuild the room at the saved spawn while retaining the applied comparison values.
**Defaults** selects LA/20, base multipliers1 and Shift multiplier2; it retains
the saved spawn. The applied receipt displays actual
mass, inertia, response, budget and controller caps. Numeric text editing suppresses craft-selection
shortcuts and leased flight input, so typing 40 or 64 cannot select another flyer.
Enter/Escape leaves text editing.

The **Thrust limit × authored** and **Torque limit × authored** fields independently
admit 0..64, default1. They multiply each selected craft's authored ceilings;
the original seven retain force8..28 and torque3..82, while Scooper starts at
force23/torque1200. Omitted options retain1 for API compatibility.
Zero thrust disables the controller's combined linear request, including braking
and hoverboard gravity compensation. Zero torque disables its turning/leveling
request. Gravity, material reactions and existing extreme-motion safeguards remain.
The controller uses actual mass/inertia to form requests before applying these
caps. Acceleration, angular acceleration, speed and effort targets stay authored;
raising a ceiling alone does not raise those targets. The rig's existing per-call
impulse guards remain `mass*100` and `inertia*4`, with separate extreme-motion
safety braking above speed300 or angular speed24. These are not material laws.
Increasing mass can prevent lift until sufficient propulsion is available. The
body-thrust craft without assistance permit passive contact rotation; Afterglow
and Scooper retain their bounded level/tilt motor. No collision-only effective mass,
velocity assignment, pose latch or sleeping policy is introduced.

## How do I return after F2?

In the updated desktop launcher, choose **GRANULAR OWNER REVIEW / experimental**
near the top, then **Granular barrel comparison**, **Structural cut / support
tests**, or **Flyer playground + painting**. Each replaces the old scene through
the existing owner teardown path. These source-matched developer routes are
hidden/refused in Web demo policy. Older running builds must be reopened to gain
the new menu entries.

## Who owns the response and reset?

The room retains its synchronous exclusive native owner. Native cells own
material; main-thread Rapier owns the flyer. The existing arena packs one17-value
sample for each original single-rectangle body. Authored compounds repeat the
one physical COM state in at most8 geometry records and apply one accumulated
version2 wrench through the same bridge. Painting occurs between owner steps. It does not
add a worker/main-thread ownership path or per-cell physics bodies.

`configure_review_fleet` admits one human arcadelander carrier and one validated
catalogue index, currently0..7. One authored body per review World is the current
bounded implementation, not a permanent prohibition on future actor composition.
The ordinary catalogue mass validator is unchanged. Only the
explicit fleet route can apply the validated developer multipliers, after checking
the exact authored fleet definition and before populating physical properties,
rig mass/inertia caches and the Rapier bridge. Invalid options preserve the
existing live owner. A reset strips copied receipt metadata from the authoring
request and retains the admitted response and options in a fresh owner/epoch.

The LA budget path uses the existing native **GCR-REST/control** token and budget
owner. It supplies no manufactured support/drive context and enables none of
P/R/C/PRC. The RFT reference keeps GCR/R2. A budget is not implemented by multiplying
the final applied impulse. Ordinary gameplay defaults, native material policy,
ejection/correction and sleep remain unchanged.

## What is qualified and what remains open?

The [focused creep investigation](../operations/gcr-creep-registration.md)
separates neutral controller input, zero actuator ceilings and powered movement.
Neutral input can still request drag. Controller force and rig impulse telemetry
describe bounded requests; `_apply_rig_impulse` can record a request before the
per-part tiny-impulse guard suppresses backend delivery. Do not infer actual
force delivery from exhaust, controller requests or that rig accumulator alone.
The investigation's single-hull same-phase velocity difference measures delivery
before the native wrench and Rapier integration, with rig safety participation
reported separately. Its dynamic-bank and quiet flat-bed results have distinct
scope; neither is a general sleep or friction acceptance result.

This is a playable developer comparison surface, not a new physical acceptance
population. The earlier [88-case qualification](../audits/2026-11-02-gcr-rest-contact-comparison.md)
retains its original source and failures: R/PRC is NO-GO as implemented, P/C never
admits physical quiet contact, and the sweep has no general production winner.
Those rest modes are not exposed here. Painting and varied propulsion do not
convert prior closed-fixture conservation or passive-energy results into claims
about this editable room.

The earlier2 November application-extension checkpoint reused native SDK source
`181a8257a93f82d64fbeb97e9c413ef52d44f13d`, with its 88 compiled inputs unchanged.
Native runtime SHA256 identities remain Windows
`65c1d2a35134c44aea539a0e8441d66b3b4db92cba7c5477d038b842fe7c889e` and Linux
`8bfe51214643c626dd5800f66ecff86f3348a166b55551e0674d1b4f762cfbf5`.
Later GDScript authoring/owner/UI routes require their own source-matched host
checks and runtime identity; these older hashes are not current-head proof. The focused
controls are `test_gcr_fleet_controls.gd`, `test_gcr_review_fleet.gd` and
`test_gcr_crash_playground.gd`, alongside relevant ordinary actor-host regressions.
Test definitions alone do not establish execution or human feel acceptance.
The new side-thrust/emitter/input paths likewise require their own dated
source-matched execution; the 2026-11-02 records do not attest the 2026-11-03
extension.

Launch a source-matched project with
`python tools/experiments/run_gcr_fleet_review.py --project <project>`.
`--identity-only` checks the launcher identity without opening the scene.
PR #351 remains draft and unmerged. Owner acceptance, broad physical qualification,
production/default promotion and sleep remain outside this extension.
