---
title: 1024² material lab
document-kind: runbook
canonical-for: [material-lab-controls, manual-material-recipes]
status: Current
scope: Desktop and Web manual controls, repeatable interaction observations, construction recipes, and finite-demo limits
last-reviewed: 2026-10-18
related-documents: [systems/materials-and-rule-kernels.md, systems/themed-construction-materials.md, systems/water-design.md, reference/configuration-reference.md, reference/level-saves-and-replay.md, operations/microscenarios-programme.md]
---

# 1024² material lab

**Current:** CyberSand exposes 79 paintable materials in a finite 1024×1024 native
world. Desktop and Web have different controllers and controls. This page is a
manual observation runbook, not proof that every pairing or visual has passed
acceptance. Source/runtime identity and dated checks are in the
[checkpoint](operations/source-checkpoint-and-recovery.md) and
[evidence ledger](reference/validation-evidence.md).

Open the desktop project through the [local workflow](operations/local-build-and-validation.md).
For Web, use the built HTTP preview described in the
[Web guide](operations/web-threading.md). Native C++ supplies current cellular
behavior; the desktop fallback is a narrower, different implementation.
Physics Pit requires the [Rapier capability checks](operations/rapier-2d-migration-runbook.md).

## Desktop controls

The detailed [Neon Reliquary demo](operations/neon-reliquary-demo.md) is available
through **F11** or its launcher. It opens a paused machine-cathedral scene with
five viewpoints; **F8** supplies a clean view and **P** resumes its materials.
**Below / Above** and the district selector navigate its four-tile descent:
Neon Reliquary, Middle Cyberberbia, Sewertech Alley and Industrial Underswamp.
Changing district loads that tile's original paused layout; changing its camera
view preserves edits.

**Shift+F11** or **Blacksite Nine** opens the separate
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
| F3 | Toggle statistics and periodic status-string construction |
| P / R | Pause / reset |

Paint slots map to stable material IDs; slot 5 is Paste ID 20 and slot 6 is
Slush ID 21. The status line identifies the selected material. View/margin
presets and defaults are owned by the [configuration reference](reference/configuration-reference.md).
The 1920×1080 window aspect-fits the logical view, and mouse mapping uses the
same fitted rectangle.

Changing H or K does not change native fixed-tick semantics or enable a strict
simulation mode. Target cadence is not guaranteed wall-clock progress.

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
Shift+F11. X requests
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
then create one pairing at a time. Hold inputs across actual physics callbacks.
Capture material IDs, geometry, relevant toggles, tick interval, and observed
outcome. Secondary reactions are sampled on
[kernel-specific lanes](systems/materials-and-rule-kernels.md#kernel-execution-and-cadence);
one brief contact with no reaction is not sufficient evidence of a defect.

| Setup | What to inspect |
|---|---|
| Water above Oil; Smoke trapped under Water/Sand | Directional density separation and target exchange permission |
| Water, Slush, Paste on matching stepped slopes | Free mass versus heap-capable yield; C/T Water comparisons |
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
- The desktop Rapier collider consumer processes at most 32 queued chunks per
  rendered frame, with a 750 µs check between chunks. One chunk can exceed that
  time. Native geometry extraction, packed validation/copy, and queueing are
  outside this consumer budget; it is not a total physics-frame guarantee.
- Current dirty CPU patches still cause full RG8 GPU updates on changed
  publications. Patch KiB is not GPU transfer KiB.
- Manual scenes are finite fixtures, not streaming worlds, production physics
  acceptance, calibrated material science, or universal 1024² frame-time proof.

## Recovering from a simulation fault

**Current:** a native tick fault stops that world and preserves the last valid
display. Desktop shows the error even with F3 statistics hidden; press R to reset.
Web opens the menu and offers Restart world or loading a valid saved level.
Pause/unpause does not retry. Recovery discards the failed attempt and pending
events; no rollback or exact continuation is promised.


## Issue #13 experiment checkpoint

Open the [Experiment Tower](operations/experiment-tower.md) with desktop F9 or its native Web demo menu entry. Its five floors start paused; the lab panel supplies floor selection, plugs, single-step and fresh resets.


The [transport profile editor](systems/flow-transport-and-profiles.md) shows effective
settings/origins, saves editable user copies and applies through an explicit restart.


## Planned MicroScenario Materials Laboratory

The current 1024² lab remains the manual Current runbook. The planned
[MicroScenarios programme](operations/microscenarios-programme.md) does not
replace its evidence.

Issue #28 may build an **exploratory/provisional Materials Laboratory** once
#27 provides a stable-enough common host; it does not have to wait for
#14/G-final. A readiness checkpoint inside #28 requires one generic generated
interaction definition to run both headlessly and interactively with the same
setup/identity/observation contract. That checkpoint, not completion of Flood
Control or Simulation Stress Test, unblocks #29/INT-000 implementation.

INT-000 covers non-kinetic intermaterial interactions rather than chemistry
alone. Its accepted passes preserve versioned baseline/evidence, source/sink or
conversion accounting where applicable, and the exact kinetic/contact profile
that determined how materials met. If later physics changes that contact regime,
affected fixtures are re-screened instead of overwriting prior evidence.

