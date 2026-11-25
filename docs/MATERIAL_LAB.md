---
title: 1024² material lab
document-kind: runbook
canonical-for: [material-lab-controls, manual-material-recipes]
status: Current
scope: Ordinary Main materials sandbox and Web manual controls, repeatable interaction observations and construction recipes; distinct from Shared Workbench and Materials Lab v1
last-reviewed: 2026-11-24
related-documents: [systems/materials-and-rule-kernels.md, systems/themed-construction-materials.md, systems/water-design.md, reference/configuration-reference.md, reference/level-saves-and-replay.md, operations/microscenarios-programme.md]
---

# 1024² material lab

This page covers the **Materials sandbox / Experiment Tower** route and the
Web material demos. The ordinary sandbox uses a finite **1024 × 1024** native
world. Its material picker exposes **130 paintable materials**; the Web
controller inherits the same picker catalogue. Other hosts have their own scene
sizes, controls and capabilities.

| What you want to do | Current entry point |
|---|---|
| Paint materials, inspect interactions and run the manual recipes below | Desktop feature launcher → **Materials sandbox / Experiment Tower — F9**. F9 opens the Tower after entering that sandbox. |
| Author a scene with Paint history, generation, actors and explicit saves | **Development workbench**, then the [first-session guide](operations/workbench-first-session.md). Its fresh blank canvas and shortcuts are separate from this 1024² sandbox. |
| Browse effective native properties and compare isolated material candidates | **Materials Lab** in the feature launcher, or **Materials Lab** in Shared Workbench. Follow the [Lab authoring guide](operations/materials-lab-authoring.md). |

**Materials Lab v1 is available in accepted source.** It supplies native browsing,
structured source candidates, compiled candidate versus untouched-reference
Worlds, isolated endpoint effects, source-bound World recipes and bounded
existing-material experiments. Its [dated qualification](audits/2026-11-11-materials-lab-v1.md)
retains the original tested source and platform scope. This does not make shadow
definitions active in production or provide the separate, unmerged live
current-scene audition feature.

Open the desktop project through the [first-run guide](operations/getting-started.md)
and choose the named feature. For Web, use the built HTTP preview described in
the [Web guide](operations/web-threading.md). Native C++ supplies the material
behavior; the desktop fallback has a narrower, different implementation.
Physics Pit requires the [Rapier capability checks](operations/rapier-2d-migration-runbook.md).

This is a manual observation runbook, not evidence that every pairing, platform
or visual has passed acceptance. Bind a report to the actual source/runtime
identity using the [checkpoint guide](operations/source-checkpoint-and-recovery.md)
and [evidence ledger](reference/validation-evidence.md).

## Desktop controls

These are ordinary Main-scene controls. They do not apply to Shared Workbench,
which handles keys before these legacy bindings. A selected F5 physical actor
can also reserve movement/tool keys; use its displayed control instructions.

Choose **Neon Reliquary** in the feature launcher, or press **F11** from the
ordinary sandbox. The [demo guide](operations/neon-reliquary-demo.md) covers
a paused machine-cathedral scene with five viewpoints; **F8** supplies a clean view and **P** resumes its materials.
**Below / Above** and the district selector navigate its four-tile descent:
Neon Reliquary, Middle Cyberberbia, Sewertech Alley and Industrial Underswamp.
Changing district loads that tile's original paused layout; changing its camera
view preserves edits.

Choose **Blacksite Nine** in the feature launcher, or press **Shift+F11** from
the ordinary sandbox, to open the separate
[connected 3×3 complex](operations/blacksite-nine-demo.md). Use its **3×3 tile
map** to frame any district, **Whole complex** for the overview, and **F** to
follow the player. A/D and held Space move through the twelve connecting
galleries and shafts. Tile framing preserves edits everywhere; **R** restores
the entire nine-tile world.

Source: [main.gd::_unhandled_key_input, update_camera, update_worker_frame_state](../godot/scripts/main.gd).

| Control | Effect |
|---|---|
| LMB / RMB | Emit selected material / erase |
| A / D; Space | Move character left/right; jetpack |
| Arrow keys; F | Pan camera (disables follow); toggle character follow |
| 1–6 | Quick slots: Sand, Water, Wall, Smoke, Paste, Slush |
| Q / E or Page Up / Page Down | Cycle all paintable materials |
| Shift plus those cycling keys | Jump core/reactive, medieval, industrial, luminous, woods, stone/earth, metals and glass/chemical groups |
| V / B | Cycle logical view / independent per-side simulation margins |
| L | Toggle camera-interest / whole finite-world simulation |
| C | Toggle ordinary Water emission / coherent lateral-delay emission |
| T | Toggle native Water supported-film adhesion |
| K | Toggle render smoothing; also forwards fallback sparse-flight sampling option |
| H | Cycle render publication target through 30/45/60 Hz |
| G | Toggle glow overlay and glow SubViewport updates (desktop and Web) |
| F3 / Shift+F3 | Expand/collapse the desktop statistics; show/hide them entirely |
| J; − / =; comma / period; O | Cycle brush shape; change brush size; change rectangle ratio; rotate the rectangle |
| F2 | Close this session and return to the feature launcher |
| P / R | Pause / reset |

Paint slots map to stable material IDs; slot 5 is Paste ID 20 and slot 6 is
Slush ID 21. The status line identifies the selected material. View/margin
presets and defaults are owned by the [configuration reference](reference/configuration-reference.md).
The 1920×1080 window aspect-fits the logical view, and mouse mapping uses the
same fitted rectangle.

Changing H or K does not change native fixed-tick semantics or enable a strict
simulation mode. Target cadence is not guaranteed wall-clock progress. A locked
MicroScenario or controlled Water run can refuse a setting change; inspect the
active state instead of assuming a key press applied it. F2 closes the session;
these standalone controls do not provide Workbench Save start or its Undo history.

## Web controls and menu

Source: [web_demo_controller.gd](../godot/scripts/web_demo_controller.gd),
[web_demo_menu.gd](../godot/scripts/web_demo_menu.gd), and
[demo_worlds.gd](../godot/scripts/demo_worlds.gd).

Web offers Material Lab, Waterworks, Foundry, Neon Works, Physics Pit,
Experiment Tower, all four [Neon Reliquary district tiles](operations/neon-reliquary-demo.md),
and the [Blacksite Nine 3×3 complex](operations/blacksite-nine-demo.md).
Escape opens/closes the menu; during a reference benchmark it requests cancel.
Gameplay shortcuts are ignored while the menu is open. Shared shortcuts are
mouse paint/erase, A/D, Space, 1–6, Q/E, P, R, F, C, T, G, F3, F8, F11 and
Shift+F11. Web F3 toggles statistics visibility directly; it does not use the
desktop expand/hide pair. Web also supports J, − / =, comma / period and O for
the brush shape, size, rectangle ratio and orientation. X requests
a bounded radius-20 explosion at the valid world pointer. Desktop's V/B/L/K/H,
Page keys, and other Shift-group shortcuts are not a Web shortcut contract.

LOW/NORMAL/HIGH pair view, margins, and publication rate. The menu also exposes
level text export/import, a local save slot, and isolated performance/stress
fixtures. A saved level does not preserve exact future continuation; review
[level saves and replay](reference/level-saves-and-replay.md) before interpreting
round-trip results. Browser storage depends on the origin and profile.

Both compatibility and threaded Web use native cells; compatibility selects one
cellular worker. Neither profile makes Web rendering asynchronous with a native
tick. This matters when interpreting slow controls or frame timing.

## Repeatable interaction observations

Reset, select a known view and margin, note native/fallback and worker profile,
then create one pairing at a time. Record the effective Water law and its actual
options: a visible legacy C/T control does not establish that every Water law
supports coherence or adhesion. Use the [Water Lab](operations/workbench-water-lab.md)
for explicit solver comparisons. Hold inputs across actual physics callbacks.
Capture material IDs, geometry, relevant toggles, tick interval, and observed
outcome. Secondary reactions are sampled on
[kernel-specific lanes](systems/materials-and-rule-kernels.md#kernel-execution-and-cadence);
one brief contact with no reaction is not sufficient evidence of a defect.

| Setup | What to inspect |
|---|---|
| Water above Oil; Smoke trapped under Water/Sand | Directional density separation and target exchange permission |
| Water, Slush, Paste on matching stepped slopes | Selected Water law versus heap-capable yield; compare C/T only when that law admits those options |
| Fire beside Wood/Oil/Dust/plants, then Water | Ignition, burn progression, sampled extinguishing behavior |
| Lava against Water/Ice; Lava against Glass | Phase/reaction outcomes; compare quenching Molten Glass |
| Salt or Sodium in Water | Brine formation versus energetic Fire/Steam reaction |
| Ignite Gunpowder and Coal | Short flash versus slower burn/emission |
| Spark at one end of Metal, Water by another | Local charge propagation and nearby reaction |
| Cement cavities exposed to air versus Water | Cure progression under different neighbors |
| Mercury through Water/Oil/Brine/sludge | High-density exchange |
| Foam beneath a liquid pool | Upward movement followed by decay |
| Acid against several materials, Wall as control | Finite corrosion and exceptions |
| Plant/Fungus beside substrate; Seed on Sand | Growth, germination, and later ignition |
| Cloner beside one material with empty output space | Capture and initialized emission |
| Rocket beside payload, then Fire/Lava | Capture, launch trigger, trail, and impact; a flying Rocket blooms with sparks |
| Building woods (81–97) beside Fire/Lava, then Water | Bounded combustion and extinguishing, char/ember finish |
| Raw Clay or Adobe beside Fire/Lava; Packed Snow beside Fire/Salt/Steam | Kiln firing to Terracotta/Red Brick; melting, thawing and condensation |
| Quicklime, Gypsum, Rock Salt, Sugar Glass beside Water | Slaking to Steam+Cement, softening to Paste, dissolving to Brine/Salt |
| Spark onto Thermite or Magnesium; Fire onto Sulfur/Phosphor/Wax/Polymer | Ignition to Lava/Fire; melting to Oil; Smoke products |
| Acid against Marble, Chalk, Zinc, Bare Iron; Water/Brine against Bare Iron | Effervescence (Foam) or corrosion versus the broad Acid kernel; slow rusting |

For Water conservation/rest assertions use native fixture mass and
`content_hash()`, not apparent particle count or advancing `state_hash()`.
The [Water contract](systems/water-design.md) defines acceptance bounds.

## Construction recipes

These are authoring suggestions using the
[complete themed catalogue](systems/themed-construction-materials.md) and the
[building catalogue](systems/building-material-catalogue.md).

| Scene | Suggested composition |
|---|---|
| Castle wall/gate | Granite foundation; Limestone/Sandstone walls; Oak gate; Wrought Iron fittings; Slate/Lead roof details; Stained Glass; localized Mossy Cobblestone |
| Village house | Oak frame; Wattle and Daub/Lime Plaster infill; Thatch/Terracotta roof; Red Brick chimney; Packed Earth path |
| Chemical bay | Reinforced Concrete/Ceramic shell; Steel Plate tanks; Painted Steel panels; Steel/Copper Pipes; Cable/Rubber/Insulation; Chemical Glass inspection zones |
| Rainy alley | Industrial Brick; Wet Asphalt/Cobblestone; Rusted/Corrugated Steel; Chainlink; narrow cyan/magenta neon; Smoke/Steam/reactive liquids |
| Forest lodge | Rough Oak/Birch logs as posts; Pine Planks and Cedar Shingles; Moss Wall foundations; Paper Screen windows; Plant beds with flowers and vines |
| Pottery kiln yard | Firebrick kiln around Lava; Raw Clay and Adobe ware that fires to Terracotta/Red Brick; Sandbags; Rammed Earth walls |
| Alchemist lab | Marble/Terrazzo floor; Glass Block and Frosted Glass; Uranium Glass and Phosphor accents; Sulfur, Wax, Quicklime and Thermite stores |
| Spaceport | Heat-Shield Tile, Carbon Fibre, Aluminium and Solar Panel cladding; Polymer and Acrylic fittings; Gold Leaf trim |

Chainlink and grating collide as solid cells despite visual holes. Decorative
metal/glass names do not inherit every reaction of base Metal/Glass. Use Empty
cells for actual holes, and use the [appearance contract](systems/material-appearance-and-rendering.md)
when evaluating GPU finish, glow, and temporal motion.

## Interpretation limits

- Native phased camera re-entry [resumes paused work](systems/world-storage-and-interest-region.md#interest-filtering-and-re-entry)
  without catch-up; newly included blocks wake once. A stopped failed world still
  requires restart or valid level replacement before it can resume.
- The ordinary Main sandbox Rapier collider consumer processes at most 32 queued chunks per
  rendered frame, with a 750 µs check between chunks. One chunk can exceed that
  time. Native geometry extraction, packed validation/copy, and queueing are
  outside this consumer budget; it is not a total physics-frame guarantee. Shared
  Workbench has separate consumer defaults of 128 chunks / 4,000 µs; neither
  profile is a universal per-frame bound.
- Current dirty CPU patches still cause full RG8 GPU updates on changed
  publications. Patch KiB is not GPU transfer KiB.
- Manual scenes are finite fixtures, not streaming worlds, production physics
  acceptance, calibrated material science, or universal 1024² frame-time proof.

## Recovering from a simulation fault

**Current:** a native tick fault stops that world and preserves the last valid
display. The ordinary desktop Main host shows the error even with statistics
hidden; press R to reset. Workbench recovery follows its separate
[saved-start and fault guidance](operations/workbench-saving.md).
Web opens the menu and offers Restart world or loading a valid saved level.
Pause/unpause does not retry. Recovery discards the failed attempt and pending
events; no rollback or exact continuation is promised.


## Issue #13 experiment checkpoint

Enter **Materials sandbox / Experiment Tower — F9** from the desktop feature
launcher, then press **F9**; alternatively choose Experiment Tower in the native
Web demo menu. The [Tower guide](operations/experiment-tower.md) explains the controls. Its five floors start paused; the lab panel supplies floor selection, plugs, single-step and fresh resets.


The [transport profile editor](systems/flow-transport-and-profiles.md) shows effective
settings/origins, saves editable user copies and applies through an explicit restart.


## Planned MicroScenario Materials Laboratory

This heading retains the original programme name. The reusable MicroScenario
host, exploratory reference pack and INT-000 infrastructure are already in the
accepted source; they are not waiting for a new #27/#28 implementation. Use the
[current host guide](operations/microscenarios.md) and
[reference pack](operations/microscenario-reference-pack.md) for existing
Materials Laboratory, Flood-Control and Stress Test definitions.

The [canonical programme](operations/microscenarios-programme.md) retains the
original dependency graph and scientific limits. Its Materials Laboratory
readiness checkpoint admitted INT-000 independently of completion of Flood
Control, Stress Test or G-final. It does not turn an exploratory pairing into
accepted physics or grant a new tuning task. The manual observations above
remain useful for discovery and reduced reproducible reports.

INT-000 covers non-kinetic intermaterial interactions rather than chemistry
alone. Its accepted passes preserve versioned baseline/evidence, source/sink or
conversion accounting where applicable, and the exact kinetic/contact profile
that determined how materials met. If later physics changes that contact regime,
affected fixtures are re-screened instead of overwriting prior evidence.

