---
title: Designing and validating native map exhibitions
status: Current
document-kind: guide
scope: Recommended native exhibit design and validation; Current material behavior from main fc015a77d3b851fef4ea7734923bcdb3762a19a5; Deepworks worked example pinned to unmerged 7590316e01f0b6efbcc11598fc454656f38f8558
canonical-for: [map-exhibition-design, map-reaction-validation]
last-reviewed: 2026-10-20
related-documents: [map-production-workflow.md, map-layer-polish-and-validation.md, ../systems/building-material-catalogue.md, ../systems/materials-and-rule-kernels.md, ../systems/intermaterial-interactions.md, testing-validation-and-replay.md]
---

# Designing and validating native map exhibitions

## Scope and source authority

**Current guide, reviewed 2026-10-20:** this page explains how an agent turns an
attractive material display into an observable native physics or chemical exhibit.
It owns the exhibit-design and reaction-validation process. Start with
[map production](map-production-workflow.md) for the complete project sequence;
use [layer polish and validation](map-layer-polish-and-validation.md) for cameras,
compositing, visible depth contributions and rendered acceptance.

**Source-established behavior** below refers to inspected main
`fc015a77d3b851fef4ea7734923bcdb3762a19a5`; local links lead to its canonical
contracts and executable source. **Worked example** refers to Deepworks at
[`7590316e01f0b6efbcc11598fc454656f38f8558`](https://github.com/techrote/cybersand/commit/7590316e01f0b6efbcc11598fc454656f38f8558), published in PR #185
and unmerged when this guide was written. Deepworks-only links are immutable.
Its scheduler, map definitions and tests are examples to inspect, not APIs
already supplied by this documentation-only change. **Recommended** steps and
acceptance criteria are reusable authoring practice, not new engine contracts.

The [material contract](../systems/materials-and-rule-kernels.md) owns behavior;
the [interaction contract](../systems/intermaterial-interactions.md) owns rule
identity and provenance. This guide does not authorize retuning either to rescue
an apparatus. An unexpected outcome is first an observation to reduce and triage.

**Recommended exhibit workflow:**

1. [Research the native rule, actual substrate and contact cadence](#1-discover-mechanisms-before-choosing-apparatus),
   then define the expected input, change and observation.
2. First test a [minimal native apparatus with settled contact and collection space](#3-make-contact-geometry-work-after-settling).
   Schedule [finite reactant feeds](#4-programme-reactants-preserve-native-products);
   let native kernels produce the results and retain products for inspection.
3. Run the real host and source scheduler through the exclusive native owner;
   keep feeds and cleanup inside their declared layer and bounded source/sink regions.
   [Observe copied native state](#5-prove-each-mechanism-with-native-observations).
   Exclude direct inputs and initial decoration as novel-product proof. Use
   consumption, transport or growth witnesses and [matched controls](#6-use-negative-controls-that-could-actually-fail)
   where those establish the mechanism.
4. [Replay through a fresh reset](#4-programme-reactants-preserve-native-products):
   reconstruct cells, ticks and source counts; retire old generations and queued
   edits. A camera-only view change preserves state and does not replay an exhibit.
5. [Validate the fully composed map](#7-validate-the-final-composed-map-and-retain-evidence),
   then retain recipe, source/runtime, clock, platform and outcome evidence with
   explicit acceptance limits.

## 1. Discover mechanisms before choosing apparatus

**Recommended:** build a small material ledger before drawing tanks. For each
candidate, answer the following from source rather than its name or shader.

| Question | Canonical starting point and executable symbol |
|---|---|
| Which exact ID, motion type and kernel does it use? | [Materials](../systems/materials-and-rule-kernels.md#identity-descriptors-and-state); [`material.hpp`](../../native/include/cybersand/material.hpp), `kMaterialDefinitions` |
| Is the proposed pair authored, and which participant becomes which product? | [Interactions](../systems/intermaterial-interactions.md#participant-semantics-and-precedence); [`interaction_rules.hpp`](../../native/include/cybersand/interaction_rules.hpp), `kPairInteractionRules` |
| Is it a neighborhood, charge, growth or lifecycle mechanism instead? | [Specialized mechanisms](../systems/intermaterial-interactions.md#specialized-current-mechanisms); [`world.cpp`](../../native/src/world.cpp), `World::update_rule_kernel()` |
| What cadence, substrate, lifetime and wake behavior permit it? | [Kernel cadence](../systems/materials-and-rule-kernels.md#kernel-execution-and-cadence); `World::rule_is_active()` and `World::schedule_pending_reaction_wake()` |
| Will the reagents actually meet and remain together? | [Transport profiles](../systems/flow-transport-and-profiles.md), [Water](../systems/water-design.md), and the selected native movement path |
| Does the installed runtime implement it? | [Build and validation](local-build-and-validation.md), [current versus historical provenance](current-and-historical-validation.md) |

**Source-established:** MAT-002 adds IDs 81–131. They are immovable hard
surfaces; some burn, some participate in pair reactions, and some are inert apart
from broad Acid corrosion. The
[building catalogue](../systems/building-material-catalogue.md) gives the full
matrix. Reserved ID 10 is invalid. Use named constants from
[`CyberCellWorld`](../../godot/scripts/cell_world.gd) in authoring, but run native
worlds for validation: the GDScript fallback does not implement these combustion
or pair reactions.

Useful source-established distinctions for selecting a demonstration:

| Mechanism | Supported material choice | Consequence for design |
|---|---|---|
| Electrical consequence | Spark 34 charges actual Metal 28; charged Metal can convert neighboring Water 3 to Steam 22 | A Brass Panel 119 or Copper 53 enclosure is decoration; provide a real Metal electrode. |
| Lime casting | Water 3 + Quicklime Block 108 becomes Steam 22 + Cement 30; Cement can subsequently cure to Concrete 31 | Retain liquid Cement below the contact zone and observe both the intermediate and cured product. |
| Snow thaw | Fire 6 + Packed Snow 105 becomes Steam 22 + Water 3; Salt 23 + Packed Snow becomes Brine 24 + Slush 21 | Separate thermal and salt-thaw arms; their advertised products differ. |
| Glass quench | Molten Glass 36 + Packed Snow 105 becomes Glass 35 + Steam 22 | Use a real quench contact; a contiguous molten batch is not guaranteed to cool by waiting. |
| Acid effervescence | Acid 12 + Marble 98 can produce Foam 37 + Salt 23 | Broad Acid corrosion competes; allow repeated contact opportunities and retain transient Foam observations. |
| Biological growth | Fungus 18 grows into Empty, Wood 7 or Oak Timber 46; Seed 19 germinates on Sand 2, Plant 11 or Fungus 18 | New Oak Log 83 and Moss Wall 97 are not substitute timber substrates. |

Sources: [building catalogue](../systems/building-material-catalogue.md#how-do-these-materials-behave-natively),
[explicit semantic families](../systems/intermaterial-interactions.md#explicit-semantic-families),
and `RuleKernel::Metal`, `Spark`, `Cement`, `MoltenGlass`, `Fungus`, `Seed` in
[`World::update_rule_kernel()`](../../native/src/world.cpp).
These are authored game rules; names do not establish calibrated chemistry,
temperature fields, pressure, explosion energy or real-world material performance.

**Acceptance before layout:** every advertised mechanism has an exact source
path/symbol or stable rule ID, native inputs, observable output or state change,
and a stated limitation. Classify transport separately from chemical conversion;
a liquid moving into a tray does not by itself demonstrate a reaction.

## 2. Write an exhibit card and define the observation

**Recommended planning template:** fill this before implementing the apparatus.
It is a design record, not a new runtime schema.

```yaml
id: lime-casting-foreground
title: Lime slaking cascade
plane: play
mechanism: pair conversion followed by environment-dependent cure
authority:
  pair_rule: int.pair.water-quicklime.slake.v1
  follow_on: native/src/world.cpp, RuleKernel::Cement
initial_specimens: [QUICKLIME_BLOCK]
scheduled_reactants: [WATER]
native_products: [STEAM, CEMENT, CONCRETE]
contact: water lands against the coupon, then drains to exposed mould pockets
geometry: record absolute vessel, nozzle, coupon and observation rectangles
observation: include contact zone and collection pockets; exclude scenic specimens
oracle: products absent initially and from all feeds, then present in native data
timing: record target-plane ticks, sample interval and completion deadline
control: remove Water feed and repeat from a fresh reset
replay: reconstruct original specimens, clocks and programme; invalidate old edits
visual: show coupon loss, falling Cement and cured pockets from the inspect camera
limits: native game chemistry; no measured heat release or casting-strength claim
```

Give each room a distinct causal action: a drop, dissolution front, quench,
charge consequence, collapsing specimen, growing substrate or curing pocket.
Pair a readable main apparatus with a complementary rear mechanism rather than
repeating the same recipe behind every window. Add trim after the mechanism has
space to operate. The [Deepworks exhibit builder](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/exhibition/deepworks_exhibits.gd), `_exhibit()`,
shows how identity, title, plane, focus, observation bounds, expected products
and mechanism can travel together as data.

**Acceptance before scripting:** observation coordinates are explicit, all source
materials are listed, and the test can distinguish native change from initial
decoration or material written directly by a source. For a claimed comparison
such as faster wet curing, define separate arm measurements; merely finding
Concrete somewhere does not establish the relative rate.

## 3. Make contact geometry work after settling

**Source-established:** compact pair checks use the eight neighboring cells on
a coordinate-staggered four-tick lane. The resolver uses unordered matching with
role-preserving products and an inclusive probability threshold. A threshold
`p` corresponds to `(p + 1) / 256` per eligible byte-roll opportunity, not a
probability per rendered frame. Neighbor order, competing contacts, movement and
sleep still affect the outcome. Persistent-pair wakes preserve later opportunities;
they do not promise completion by a universal deadline. See
[persistent reactions](../systems/materials-and-rule-kernels.md#how-do-persistent-reactions-survive-sleep)
and [`World::update_rule_kernel()`](../../native/src/world.cpp).

**Recommended construction sequence:**

1. Reserve room, circulation and rear-view apertures in absolute world cells.
2. Draw a shell, carve its interior, and install the actual native contact liner.
   Acid's broad kernel excludes Empty, Wall and Acid; an inert-looking decorative
   panel can still dissolve. Use Wall where the experiment requires Acid containment.
3. Place coupons and baffles with space for the expected liquid, gas or powder
   products. Inspect corners as well as faces because contact is diagonal too.
4. Place the feed against the *settled* reagent surface, or provide a short path
   that demonstrably reaches it. Hold brief reagents near the target long enough
   to receive a native opportunity. A picturesque nozzle is not contact evidence.
5. Put collection pockets outside routine feed and cleanup rectangles. Verify
   decorative plinths, rails and instrument bezels do not overwrite the liner.
6. Step a small native version, inspect the actual settled geometry, then retest
   after moving it to its final coordinates. Coordinate-dependent streams make
   relocation a relevant fixture change.

**Worked example:** the rear Halite evaporator originally missed its Brine after
settling. Moving the Fire source below the settled surface restored native Steam
and Salt production. Its final local source is `Rect2i(158, 166, 44, 3)` inside
the district; that rectangle is a Deepworks choice, not a general evaporator size.
See [`_salt()`](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/exhibition/deepworks_exhibits.gd) and the [recorded review finding](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/audits/2026-10-20-deepworks-exhibition.md).

**Source-derived timing traps:** ambient Fire ignition samples slowly, while
Lava samples ignition on its four-tick contact lane. A passing Fire cell is a poor
unverified pilot for a wood display. Molten Glass adjacent to Fire, Lava or more
Molten Glass resets its cooling state; isolate droplets or supply an authored
quench. Cement's cure rate depends on air, Water/Brine and Concrete contact.
Inspect those kernel branches rather than increasing the test timeout blindly.

**Acceptance before composition:** the contact occurs, the containment survives
the intended programme, products have visible destinations, and a closed
observation region or explicit source/sink accounting explains material leaving it.

## 4. Programme reactants, preserve native products

**Recommended:** scripts should supply the experiment's causes. Native rules
should produce its claimed results. Admit material writes through the exclusive
owner at a defined tick boundary; observations only read copied native state.
Keep foreground and rear worlds independent unless an explicitly admitted route
is part of the design. The [depth contract](../systems/depth-layers-and-parallax.md#four-material-planes)
and [ownership contract](../architecture/data-ownership-and-lifetimes.md#who-may-mutate-each-resource)
own those boundaries.

**Worked-example API:** [`CyberDeepworksRuntime._step_layer()`](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/exhibition/deepworks_runtime.gd)
applies validated events immediately before their target world's next native
tick. This illustrative record uses that API; it is not a current-main generic
event format or a complete working vessel:

```gdscript
{
    "id": "example-lime-water", "district": 0, "layer": "play",
    "rect": Rect2i(70, 106, 4, 3), "material": Cell.WATER,
    "first_tick": 12, "period": 24, "repeat": 10,
}
```

Here `first_tick=12` means twelve native ticks have completed before the first
write, which precedes the thirteenth advance. With sources enabled throughout,
ten pulses occur at pre-step tick values 12, 36, …, 228. `repeat=0` means unlimited
pulses in this example runtime.
Normal independent layer rates and dropped catch-up work mean these are neither
render-frame numbers nor guaranteed wall-clock deadlines. Its `step_once()`
advances each enabled dynamic plane once; it does not reproduce one ordinary
frame of differently paced worlds. See the [worked-example layer owner](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/depth/depth_layer_runtime.gd).

Use finite feeds for specimen conversion, corrosion, growth seeding and casting.
Leave native products available to inspect after the final pulse. Use repeating
sources for ambient rain or vapor only when containment and sinks keep the
intended occupied region bounded. Steam can condense to Water, so a top gas sink
alone may leave a filling bottom reservoir; [`_atmosphere()`](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/exhibition/deepworks_exhibits.gd) includes
separate condensate drains. Cleanup is an explicit Empty write, with its area,
phase and accounting visible in the programme.

[`CyberNativeCellWorld::diagnostic_fill_rect()`](../../godot/native_extension/cyber_native_cell_world.cpp)
requires a diagnostic fixture and replaces occupants; valid bounds do not make
a source non-destructive. A repeated source over a collection pocket can erase products
and reset compact material state. Choose small feed zones, finite stock and
separate sinks. Do not reset the entire specimen each cycle while claiming that
the accumulated result arose continuously from the native rules.

**Worked-example admission:** Deepworks validates required fields, integer IDs,
unique event IDs, valid district/plane, material eligibility, positive rectangles,
timing and conservative per-plane write totals before replacing the worlds.
Its limits are 192 records, 512 cells per event and 8192 candidate cell writes
per layer per tick, assuming every event is due together. These are example-host
limits, not universal budgets. Inspect [`_validate_programme()`](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/exhibition/deepworks_runtime.gd)
before reuse, including widened scalar bounds before `Rect2i` end arithmetic.

**Acceptance before replay:** finite pulse counts terminate; pause stops their
target clocks and emissions; disabling sources still permits native evolution;
rear-only stepping cannot mutate foreground; rejected programmes preserve the
installed worlds. A true reset reconstructs original cells and clocks, clears
fired counts and queued edits, and retires old generation receipts. Repainting
visible products away is not an equivalent reset. Level files still do not
provide [complete resumed replay](../reference/level-saves-and-replay.md).

## 5. Prove each mechanism with native observations

**Recommended:** give every exhibit its own result. A global material histogram
or a single successful room can conceal broken rooms elsewhere. Observe tick
zero, retain early samples for brief products, and include later samples for
cure or growth. Bound sampling and copying cost; choose intervals from the
mechanism rather than dumping the full map every frame.

| Claim | Required observation pattern | False positive to exclude |
|---|---|---|
| Novel-product claim for pair conversion or phase change | Each product used as the witness is absent initially and from every applicable feed, then appears in copied native cells | A scripted product, decorative product specimen or unrelated neighboring reaction |
| Charge consequence | Actual Metal and a native charge/consequence witness; remove the electrode or excitation in a matched control when causality is claimed | Glowing Brass, a Spark sprite, or Steam supplied directly |
| Powder or liquid transport | Tracked material reaches a region separated from every source; measure displacement or interface positions appropriate to the claim | Material counted only inside the nozzle |
| Combustion | Native ignition/burn consequence plus loss of the intended fuel; account for directly supplied Fire separately | A Fire emitter running next to unchanged wood |
| Cure or rate comparison | Unsupplied Concrete appears; compare separately measured arms if claiming wet/dry speed | Prepainted Concrete, or a pooled count that never distinguishes arms |
| Purification | Original Toxic Sludge decreases in a contained/accounted region while the resulting reservoir is observed | Injected Water counted as proof, or sludge merely escaping the observation window |
| Fungus growth | Growth exceeds initial Fungus plus an upper bound on all injected Fungus, and a substrate-consumption claim has its own witness | Repeated inoculation counted as growth, or nonexistent substrate inheritance |

The absent-product rule applies to a *novel-product witness*. When Water or another
result is also an initial material or feed, its presence cannot prove conversion.
Use substrate consumption, native state changes or another mechanism-specific
witness with source/sink accounting and a matched control, as in purification.

For direct writes of material `m`, a conservative cell-count allowance is
`sum(fired_pulses * rectangle_area)` over its sources. This deliberately
overcounts overlaps; exceeding it demonstrates growth beyond direct painting.
It is not a mass conservation equation. Water's partial mass, whole-cell liquids,
conversion rules and explicit sinks require their actual native accounting for
any conservation claim. See [Water](../systems/water-design.md) and
[equality limits](testing-validation-and-replay.md#what-does-equality-establish).

**Worked example:** [`test_deepworks_reactions.gd`](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/tests/test_deepworks_reactions.gd) installs
`CyberDeepworksMap.build()` through the production runtime and observes all 32
foreground/rear apparatus. `_check_products()` rejects initially present or
injected products; `_check_flow()` observes transport below the nozzles;
`_verify_exhibit()` distinguishes combustion, purification and growth.
It scans copied RG8 packets, never rendering colors or mutable World storage.
Its report's `first_new` is the first *sampled* appearance, not the exact native
conversion tick. Its charge witness is native Steam production; it does not
measure electrical current or prove every possible conductor topology.

The retained test samples every 12 ticks through 120, then every 24 through 360.
The [dated Linux result](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/audits/2026-10-20-deepworks-exhibition-evidence.json) records 32 verified exhibits, 626 simulation
assertions plus one optional evidence-write assertion, zero failures and 51.019116
seconds. These counts and intervals belong to that recipe/runtime/platform, not
a minimum quality score, all-programme lifetime test or target-PC performance claim.

## 6. Use negative controls that could actually fail

**Recommended:** select small controls for concrete remaining risks, with the
same native runtime, geometry and sampling policy as the positive case.

| Control | What it establishes |
|---|---|
| Fresh reset with the sole reactive feed removed | Products are not initially present or produced by another unnoticed source. Use a mechanism whose initial state cannot already react. |
| Wall spacer preventing contact, or correct substrate replaced by a documented ineligible one | The claimed contact/substrate dependence, provided other conditions remain comparable. |
| Actual Metal replaced by decorative Brass in a charge apparatus | The difference is native electrical eligibility, if the observation and other reaction paths are controlled. |
| Feed allowed but downstream path blocked | A transport oracle does not pass from source occupancy alone. |
| Sources disabled after a pulse | Already admitted material evolves natively; the test is not merely reading a script's timeline. |
| Rear advances while foreground is paused | Layer identity and independent-clock isolation are respected. |
| Duplicate/invalid/oversized/out-of-district event, then compare generation and probe cells | Validation refusal does not partially replace the installed world. |
| Reset with pending edits, then submit an old-generation command | Reset retires prior work and restores the initial programme phase. |

For a Fungus substrate control, measure entry into or consumption of the replaced
specimen. Growth into neighboring Empty remains eligible, so absence of timber
does not imply that all Fungus growth must stop.

Deepworks's [map/programme regression](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/tests/test_deepworks.gd) implements admission, source
termination, pause, layer isolation, copied-programme and reset controls. The
chemical ablations and matched conductor/rate comparisons above are recommendations;
do not report them as completed merely because that retained test passed.

## 7. Validate the final composed map and retain evidence

**Recommended staged acceptance:**

1. Run the smallest native apparatus that resolves uncertain contact, substrate
   or timing. Record a failed hypothesis before correcting the geometry.
2. Install the final composition through its real host and source scheduler.
   Verify authored dimensions, surviving materials, liners, all source windows,
   observation windows, clear passages and per-plane capacities after every
   architecture, trim and final-carve pass. An apparatus-only pass is insufficient.
3. Execute the intended programme to a declared native-tick horizon with every
   exhibit participating. Stop on native failure; retain per-exhibit results,
   source firing counts, product/consumption/transport observations and omissions.
4. Run the selected controls and real controller reset/pause/source-toggle path.
   If claiming indefinite atmosphere, include a suitably long bounded-occupancy
   check; a short reaction run alone does not establish indefinite stability.
5. Inspect actual composite renders at normal and inspect views. Verify moving
   material is visible in each requested plane and district, not just authored
   behind opaque scenery. Use the [layer-polish gate](map-layer-polish-and-validation.md).
6. Retain exact source/runtime identities, recipe identity, command/environment,
   timeout, platform, worker count, layer rates, tick mode, output hashes and
   failed attempts. Revalidate the final recipe after a late geometry change.

**Worked example:** [`CyberDeepworksMap.build()`](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/exhibition/deepworks_map.gd) appends architecture,
then apparatus, then a final foreground passage carve. The full-map test caught
the final installed behavior; static recipe counts alone could not. Its
`recipe_hash()` covers ordered layer rectangles and explicit event fields,
not all metadata, runtime configuration, compiled kernels or running state.
Record source and runtime hashes alongside it.

The [Deepworks audit](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/audits/2026-10-20-deepworks-exhibition.md) records two particularly reusable failures:
the settled-Brine contact miss and atmosphere hidden behind foreground dividers.
The latter required moving emitters into visible galleries and testing actual
pixels. Chemical correctness and visual visibility are separate acceptance axes.
The density-well baffle is another limit to preserve in labeling: the test proves
Mercury descends below its feed and Water is below Oil on average; it does not
claim Mercury becomes the bottommost material throughout the vessel.

For reproducing the worked example, use the pinned executable and setup described
in its [build section](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/operations/local-build-and-validation.md#deepworks-and-depth-dimensions). The optional reaction report is selected by an
environment variable, not a command-line output flag:

```sh
CYBERSAND_DEEPWORKS_REACTION_REPORT=/absolute/output/reactions.json \
  godot --headless --path godot --script res://tests/test_deepworks_reactions.gd
```

Run that only in a checkout containing the worked-example implementation; create
the output directory and provide writable Godot user-data paths for the environment.
The [retained evidence manifest](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/audits/2026-10-20-deepworks-exhibition-evidence.json) owns the actual historical command,
timeout and artifact identities. Follow [documentation maintenance](documentation-maintenance.md)
and [test selection](testing-validation-and-replay.md) for the next checkpoint.
Native success, rendered Linux software-backend success, Windows execution,
browser execution and owner visual acceptance must retain their separate scopes.
