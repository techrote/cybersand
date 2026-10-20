---
title: Map authoring with native layers and programmes
status: Current
document-kind: guide
scope: Integrating an authored exhibition map with existing native depth worlds, bounded material schedules, camera transforms, controls and scene-specific regression discovery
canonical-for: [map-authoring-native-integration, map-authoring-programme-workflow]
last-reviewed: 2026-10-20
related-documents: [map-authoring-walkthrough.md, map-authoring-design-and-materials.md, map-authoring-validation-and-acceptance.md, deepworks-exhibition.md, ../systems/depth-layers-and-parallax.md, ../reference/configuration-reference.md, local-build-and-validation.md]
---

# Map authoring with native layers and programmes

Use this chapter after defining the map's composition, circulation and material
mechanisms in [design and materials](map-authoring-design-and-materials.md).
It turns that design into an isolated scene using existing CyberSand components.
Return to the [walkthrough](map-authoring-walkthrough.md) for the complete
sequence; hand the resulting candidate to
[validation and acceptance](map-authoring-validation-and-acceptance.md).

**Source baseline:** `4f3685b71366218e82e7c2188e4ecdf27553f4cf`.
The APIs below are Current source. Instructions to create another map describe
future authoring work; they do not establish that such a map already exists or
has passed tests. The [depth contract](../systems/depth-layers-and-parallax.md)
continues to own runtime and publication semantics.

## Contents

- [Choose the existing integration seams](#choose-the-existing-integration-seams) — Give the new map explicit builders, scene ownership and launcher routing.
- [Assemble deterministic layer definitions](#assemble-deterministic-layer-definitions) — Combine scenery and apparatus without closing passages or hiding rear views.
- [Install the worlds through their owner](#install-the-worlds-through-their-owner) — Configure dimensions, clocks, reset behavior and copied publications.
- [Author bounded source and drain programmes](#author-bounded-source-and-drain-programmes) — Schedule actual material edits with explicit limits and native-tick timing.
- [Separate mechanism from decorative purpose](#separate-mechanism-from-decorative-purpose) — Choose actual reactants, substrates and containment from their native rules.
- [Align the camera, surfaces and input](#align-the-camera-surfaces-and-input) — Keep full-map coverage, layer transforms and pointer targeting coherent.
- [Make the controls part of the finished map](#make-the-controls-part-of-the-finished-map) — Preserve focus ownership and leave useful space for the scene.
- [Register independent checks and hand off](#register-independent-checks-and-hand-off) — Give the new map its own tests, evidence identity and acceptance scope.

## Choose the existing integration seams

Deepworks divides its implementation into several directly connected modules:

| Existing component | Authoring responsibility |
|---|---|
| [`deepworks_architecture.gd`](../../godot/scripts/exhibition/deepworks_architecture.gd) | Builds scenic rectangles for all four planes; its room-local `Canvas` clips geometry before appending world coordinates. |
| [`deepworks_exhibits.gd`](../../godot/scripts/exhibition/deepworks_exhibits.gd) | Builds apparatus, reactant feeds, local atmosphere and exhibit descriptions/observation regions. |
| [`deepworks_map.gd`](../../godot/scripts/exhibition/deepworks_map.gd) | Combines those builders, carves circulation last, and identifies the resulting recipe. |
| [`deepworks_runtime.gd`](../../godot/scripts/exhibition/deepworks_runtime.gd) | Validates and executes Deepworks source programmes around native ticks. |
| [`deepworks.gd`](../../godot/scripts/exhibition/deepworks.gd) | Owns scene controls, camera, runtime lifetime, publication and failure presentation. |
| [`deepworks.tscn`](../../godot/deepworks.tscn) | Creates the full-rect `Control` hosting that script. |

A separate map needs its own content and host identities. Reuse the shared depth
runtime/compositor where their contracts fit; copy or extract narrowly scoped
authoring helpers where appropriate. Retain Deepworks as a working reference.
Avoid duplicate `class_name` declarations when adapting its scripts.

The Deepworks scheduler is scene-specific: its installation fixes the world at
1024 × 1024, and its validator assumes sixteen 256-square districts. Changing a
constant in another builder does not change those admission rules. A different
layout needs an explicitly adapted programme owner and matching tests.

Launcher integration is also explicit. Add the new destination button and scene
mapping in [`feature_launcher.gd`](../../godot/scripts/feature_launcher.gd).
For a direct-launch argument, follow its first-launch
`cybersand_launch_args_consumed` guard. Otherwise returning to the launcher can
reapply the argument and trap the user in the map. Keep the shared
[`FeatureNavigation`](../../godot/scripts/feature_navigation.gd) F2 return path.
The project still opens the feature launcher by default.

This exhibition integration does not create the ordinary actor session. Actor
traversal or an F5 picker requires its own applicable integration work.

## Assemble deterministic layer definitions

The native depth owner accepts a dictionary with exactly `play`, `scripted`,
`effects` and `background`. Each value is a `PackedInt32Array` containing repeated
five-integer rectangles:

```gdscript
# x, y, width, height, material ID
var wall_strip := PackedInt32Array([
    40, 160, 80, 3, Cell.WALL,
])
```

`Cell` here is the existing preload of `res://scripts/cell_world.gd`.
Use its named material constants. Every rectangle must have positive dimensions,
fit the authored extent and use a current material ID other than reserved ID 10.
The [configuration reference](../reference/configuration-reference.md#depth-host-and-deepworks-configuration)
owns the limits: currently 4,096 rectangles and 4,194,304 counted construction
cell writes per plane. Overlapping writes count repeatedly.

Build coarse architecture first, then apparatus and smaller detail. Rectangle
order matters because later authoring can replace earlier cells.
`CyberDeepworksMap.build()` duplicates each architecture array before appending
apparatus, then appends Empty rectangles for the circulation network. Its
apparatus is deliberately outside those reserved galleries and shafts.

Make that ordering intentional in a new map. Preserve explicit passage
rectangles and keep exhibit footprints away from them; a final clearing pass
must not silently cut a containment wall or delete a specimen. Conversely,
late decorative trim must not close the passage.

Author foreground apertures around rear apparatus. All four planes can contain
complete scenery while the final composite hides most of it behind opaque
foreground cells. Inspect both isolated layers and their combined view before
adding more detail. Empty space is authored coverage when it gives a route,
silhouette or viewing aperture a clear purpose.

## Install the worlds through their owner

[`CyberDepthLayerRuntime`](../../godot/scripts/depth/depth_layer_runtime.gd)
creates four separate native adapters, sets their simulation windows, authors
their cells and installs guards around dynamic planes. It serializes calls into
those worlds and uses one worker per plane. Keep mutable world access inside
that owner; builders produce definitions and presentation consumes copied
packets.

For the existing Deepworks recipe, these are the initialization calls used by
the host. This fragment belongs inside its boolean reset method, where `Map`,
`runtime`, `definition` and `_fault()` already exist:

```gdscript
definition = Map.build()
if not runtime.install(definition["layers"], definition["events"]):
    _fault(runtime.last_error)
    return false
if not runtime.configure_rates({
    "play": 30.0,
    "scripted": 20.0,
    "effects": 15.0,
    "background": 0.0,
}):
    _fault(runtime.last_error)
    return false
```

For another authored size, the shared API is
`runtime.reset(definitions, authored_size)`. Pass the size explicitly: omission
uses Strata's 640 × 360 default. Each axis accepts 8–1024 independently.
Deepworks programme installation instead uses its fixed 1024-square size.

| Plane | Deepworks target | Authoring consequence |
|---|---:|---|
| `play` | 30 Hz | Foreground material and apparatus evolve together across the complete map. |
| `scripted` | 20 Hz | Rear machinery and reactions have independent native state. |
| `effects` | 15 Hz | Local atmospheric materials evolve without changing foreground cells. |
| `background` | 0 Hz | Distant material scenery remains frozen and its first publication is cached. |

Call `advance(delta, paused)` during normal operation and check its `ok` result.
At most two ticks per plane execute in one advance; excess due time is recorded
as dropped work. Target rates are not a guarantee under overload.
`step_once()` advances each eligible dynamic plane once, independent of their
relative rates.

A valid reset replaces worlds, clears old queued commands and advances the
generation. Rejected definitions preserve the live state. The shared reset
retains existing layer rate/pause preferences; reconcile those deliberately if
a new host exposes per-layer controls. Deepworks `install()` also clears and
reinstalls its programme. Calling only `reset()` on that subclass clears the
programme without reinstalling it.

After reset, force a complete publication for every plane. During ordinary
updates, forward changed packets, reject failed publications and stop visibly
if compositor admission fails. Preserve the existing `_publish_layers()` and
`_fault()` behavior when adapting the host.

## Author bounded source and drain programmes

A Deepworks programme record contains exactly these fields:

```gdscript
{
    "id": "deepworks-00-scripted-stone-ration",
    "district": 0,
    "layer": "scripted",
    "rect": Rect2i(170, 88, 3, 3),
    "material": Cell.STONE,
    "first_tick": 20,
    "period": 31,
    "repeat": 40,
}
```

This is the repaired A1 rear Stone feed. `_step_layer()` tests the target
plane's current tick before advancing it. The first write occurs while that
counter is 20, immediately before its next native step; later opportunities
occur at 51, 82 and subsequent increments of 31. Schedule against native ticks,
then evaluate the presentation at the intended running rates.

[`_validate_programme()`](../../godot/scripts/exhibition/deepworks_runtime.gd)
requires unique nonempty IDs, integer schedule fields, supported materials and
rectangles entirely within their declared district and the outer guard.
Unknown fields are rejected. Current bounds include:

| Programme property | Bound |
|---|---|
| Event count | 192 |
| Event rectangle area | 512 cells |
| Sum of event areas for one target plane | 8,192 cells, conservatively assuming every event is due together |
| `first_tick` | 0–36,000 |
| `period` | 1–36,000 |
| `repeat` | 0–10,000; zero permits indefinite repetition |
| Target | `play`, `scripted` or `effects`; never `background` |

The scheduler applies `diagnostic_fill_rect()` to due rectangles, then runs
native simulation. This replaces cells in the source footprint; it is not an
“add only into Empty” operation. Place nozzles where repeated writes will not
erase the evidence being observed. Same-tick events execute in programme order,
so overlapping edits require an intentional ordering.

A drain is an ordinary programme event whose material is `Cell.EMPTY`.
Deepworks pairs repeating atmospheric sources with contained effects-plane
drains, including condensate cleanup where needed. The admitted effects
materials are Empty, Water, Dust, Steam, Spark and Smoke.

Prefer finite chemical supplies so products remain inspectable. The validator
permits `repeat: 0` on dynamic targets, but Deepworks uses indefinite schedules
for contained environmental activity. Turning `scripts_enabled` off stops
future source writes while existing cells continue simulating; re-enabling it
does not replay missed opportunities.

Emit reactants and let native rules produce the result. Keep observation regions
away from source footprints and drains, and identify a measurable mechanism
before scaling the apparatus across the map.

## Separate mechanism from decorative purpose

Read the [building catalogue](../systems/building-material-catalogue.md) and
[material kernels](../systems/materials-and-rule-kernels.md) for the chosen
interaction. Appearance and a familiar name do not establish conductivity,
reaction compatibility or a particular transport rule.

Deepworks illustrates useful distinctions. Its charged exhibits use actual
Metal rails; Brass is casing. Fungus receives old Wood and Oak Timber as tested
substrates, while other woods provide scenery. Its vessel helper builds an
inner Wall containment boundary beneath the decorative shell. Those decorative
cells remain real native materials in dynamic planes and may react if exposed.

The repaired Stone chute is a practical authoring lesson: Stone above a shelf
did not spread sideways like Sand. Moving its nozzle into the open passage
restored the intended falling demonstration without changing the native kernel
or weakening the below-shelf transport check. The
[completion audit](../audits/2026-10-20-deepworks-pr185-completion.md)
records the failure and correction.

Layer overlap also grants no physical connection. Parallax, relief, haze and
reflection move or shade presentation only. The shared runtime's explicit
`route_event()` permits defined play-to-scripted blasts and scripted-to-effects
bursts; it does not automatically detect and forward native explosions.
A new cross-plane sequence needs an explicit admitted route and a test proving
which world changes.

## Align the camera, surfaces and input

Configure the compositor with the same authored dimensions before adding it to
the scene tree. Deepworks sets its layer parameters first:

```gdscript
compositor.layer_scale = Vector4.ONE
compositor.layer_parallax = Vector4(1.0, 0.98, 0.965, 0.94)
if not compositor.configure(Map.SIZE):
    return
add_child(compositor)
compositor.set_view(Vector2.ZERO, Vector2(Map.SIZE))
```

Handle configuration failure visibly in the surrounding host. Configured
surfaces cannot change authored dimensions in place. Use `set_view(origin,
extent)` to change the camera; it validates the candidate, synchronizes uniforms
and clamps the origin. Deepworks uses square overview, district and apparatus
views; the shared compositor also accepts nonsquare extents.

[`CyberDepthLayerSurface`](../../godot/scripts/depth/depth_layer_surface.gd)
renders the authored ROI over its fixed 1024-square RG8 backing. Each plane needs
its own `World2D`; sharing the canvas would mix sibling content into each
surface. Preserve nearest filtering, transparent Empty and one-shot baking of
frozen surfaces. A paused first frame must still draw the installed map.

For painting, pass compositor-local coordinates through
`screen_to_layer(local_position, layer_index)`, floor the accepted result and
call `paint_disc()` on that same plane. Check its admission receipt. Deepworks
then uses `advance(0.0, true)` to flush accepted painting without advancing
native clocks, followed by publication. Use `get_layer_screen_position()` for
world-anchored labels and focus checks.

Exercise the corners, close zooms and rear-plane targets. The compositor's
content rectangle can be letterboxed inside its control; control dimensions
alone do not locate a native cell.

Retain generation and serial validation. An old-generation packet must not
alter the newly reset surface even if its serial is larger. Four allocated
worlds, successful uploads and plausible colours are not sufficient evidence
of correct final pixels.

## Make the controls part of the finished map

Adapt the production host's complete input ownership boundary. Keyboard movement
must stop while a descendant UI control owns focus. Subscribe to
`gui_focus_changed` as well as checking focus during movement polling: focus
can enter and leave between frames. Release held painting and middle-drag state
at UI, modal and application-focus boundaries, and require release before
rearming held world input.

A brush slider must still respond to arrow keys without panning the map.
A fresh map click can relinquish UI focus, but an arrow held from the slider
must remain disarmed until released. Test both blocked movement and subsequent
fresh movement; a permanently disabled camera would otherwise look like a pass.

Retain useful inspection controls: pause, step, whole-map reset, overview,
district/apparatus focus, layer visibility, source enablement and HUD hiding.
Describe their scope accurately. Hiding a layer does not stop its clock.
Deepworks reset affects the complete installation while preserving the camera.
Its guided tour changes views while all districts continue evolving.

Polish the map with the HUD visible and hidden at supported window sizes.
Constrain header wrapping and minimum sizes, give long guidance a scrolling
panel, and verify the header/sidebar leave a substantial visible map.
Use consistent accents and readable labels, while keeping small furnishings and
material detail subordinate to apparatus silhouettes.

Compare matched frozen views with individual layers hidden. Each district
should have visible rear and distant contributions; an atmospheric check should
witness actual non-Wall material, not merely its static containment box.

## Register independent checks and hand off

Give the new map its own top-level `godot/tests/test_*.gd` files and unique
evidence identity. Adapt fixture, controller, reaction and rendered-scene tests
to its actual district roster, bounds and mechanisms. Deepworks's 32-exhibit
expectation and fixed observation rectangles belong to Deepworks.

[`discover_cases()`](../../tools/ci/run_godot_regressions.py) automatically
discovers those files; there is no separate map registry to invent.
A `test_<map>_render.gd` suffix marks a graphical case. The
[Windows harness](../../tools/ci/run_windows_godot_regressions.py) executes
applicable headless cases and explicitly excludes display-dependent cases.
Keep tests within the current 180-second case deadline or address a measured
need through the established validation workflow.

Add the new destination to launcher/navigation coverage. Direct-launch argument
coverage also needs an explicit run with that argument; ordinary automatic
discovery of `test_feature_launch_arguments.gd` does not exercise every flag.

A reaction test should retain each expected apparatus identity, completed
mechanism receipt, positive mechanism assertion count and verification result.
Require the whole expected roster and inspect complete logs as well as exit
status. PR #185 demonstrated why an aborted helper can otherwise leave an
apparently successful summary.

Adapt [`capture_deepworks.gd`](../../godot/tools/capture_deepworks.gd) into a
separate capture helper with the new scene, view roster and output identity.
Keep atlas crops traceable to the actual rendered atlas. Record whether
post-tick images used normal pacing or manual per-plane steps.

Hand off the authored recipe, host/runtime changes, launcher route, tests,
controls and intended pixel witnesses together. Deepworks `recipe_hash()`
covers layer rectangles and explicit event fields; it is not a hash of running
state, descriptions, controller code or rendering parameters. Pair the recipe
identity with the tested source and runtime identities, then complete
[validation and acceptance](map-authoring-validation-and-acceptance.md).
