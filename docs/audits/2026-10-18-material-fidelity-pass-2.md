---
title: Material fidelity pass 2 and MAT-002 building materials
status: Current
document-kind: evidence
scope: 2026-10-18 second presentation-fidelity pass (living finishes, swirling liquids, organic rust, vapour afterimage, firework bloom) and 51 MAT-002 building materials with versioned pair reactions; tests, captures, cost and explicit gaps
canonical-for: []
last-reviewed: 2026-10-18
related-documents: [../systems/building-material-catalogue.md, ../systems/material-appearance-and-rendering.md, ../systems/intermaterial-interactions.md, ../systems/materials-and-rule-kernels.md, ../reference/material-effects-register.md, ../reference/product-intent-and-priorities.md, 2026-10-18-material-readability-pass.md]
---

# Material fidelity pass 2 and MAT-002 building materials — 2026-10-18

**Status:** implemented source with native, Godot and actual-pixel evidence on
one Windows/NVIDIA desktop. **The retained Windows/Linux GDExtension runtimes
are not rebuilt by this checkpoint**: until a source-matched runtime publication
runs, desktop and Web keep the previous native catalogue (IDs 0–80, 14 pair
rules) and cannot paint or simulate IDs 81+. Owner visual acceptance is not
claimed.

## Request

Owner request (2026-10-18, after PR #164 merged): another fidelity pass — vines
and flowers for Plant, mycelium and mushrooms for Fungus, iridescent glistening
Mites, glow/bloom on activated fireworks, whiter Steam with a fading afterimage,
a less sudden Smoke disappearance (visual only preferred), organic rather than
chequerboard Rust, deeper/darker Toxic Sludge, swirling rather than hatched
Mercury/Oil bulk, several woods with grain and bark, and several dozen more
building materials including many chemically and thermally reactive ones. The
preferences are recorded in [product intent](../reference/product-intent-and-priorities.md).

## Identities

| Item | Value |
|---|---|
| Base (`origin/main`) | `b31a897b485a1913a67a02a39fb271495bacf027` (includes PR #164) |
| Candidate | branch `mat/material-fidelity-pass-2`; exact head recorded by the commit/PR |
| Retained Windows runtime (unchanged, stale for this source) | `cybersand_native.windows.x86_64.dll` SHA-256 `29140e5c8449ddf4a2013bfd2b2caeb92114421fb7ddbeda169e90b166f88c35` |
| Local native compiler | MSVC Build Tools 2022 (`cl`, x64), `/std:c++20 /EHsc /W4 /O1` |
| Godot | `4.7.stable.official.5b4e0cb0f` Windows x86_64 |
| Renderer / GPU | `gl_compatibility`, OpenGL 3.3.0 NVIDIA 581.80, NVIDIA TITAN RTX, Windows 11 Pro 10.0.26300 |

## What changed

- **Native (MAT-002):** IDs 81–131 in `kMaterialDefinitions` with
  `kFirstBuildingMaterial`/`kLastMaterial`; 17 Combustible members; 42 pair rules
  in `int.pass.mat002-building-materials` (profile `int.current-behaviour` v2);
  derived partner-set prefilter; `TransportPolicy` schema v1 kept at 81 entries
  with bounds-safe accessors; mirrored Steam/Toxic Sludge colours. See the
  [building catalogue](../systems/building-material-catalogue.md) and
  [interaction substrate](../systems/intermaterial-interactions.md#mat-002-building-material-pass).
- **Presentation:** flair classes 46–50, `swirl_field`/`field_contours`/
  `corrosion_field`/`cell_field`, growth decor, firework sparks, 2×2 emission
  maximum, vapour afterimage viewports, building finishes. See the
  [appearance contract](../systems/material-appearance-and-rendering.md#second-fidelity-pass-mat-002).
- **Mirrors:** fallback constants/names/hard-surface range, picker groups, labels,
  worldgen labels, MicroScenario `MATERIAL_COUNT` 132, depth-layer and Rapier
  range checks. They were generated from one authoring script but remain
  separate source.

## Native evidence

Command (local, Windows, MSVC; Makefile-equivalent core sources plus
generation sources; timeout 600 s):
`cl /std:c++20 /EHsc /W4 /O1 /I native\include native\src\*.cpp native\tests\test_world.cpp`
then `tests.exe`.

Result: **74 tests passed** (70 before this change). New/changed:

- *INT-000 sparse schema shadow equivalence*: the 14-rule oracle is still compared
  exactly over every pair of IDs 0–80 at twelve probability rolls; every MAT-002
  rule involves a building material, is role-preserving in reverse and has an
  inclusive probability boundary; the derived partner prefilter agrees with the
  authored scan for all 132×132 pairs.
- *building material catalog*: solid, immovable, hard surface, kernel/family
  agreement and condition projection for IDs 81–131.
- *building combustibles ignite*: all 17 ignite next to Lava.
- *building pair reactions execute*: each of the 42 rules runs in a real `World`
  persistent two-cell contact and produces its declared products (Acid trials may
  also end by the competing broad Acid kernel; at least one trial must show the
  pair products).
- *building inert controls stay inert*: twelve inert/Acid-only materials beside
  Water for 400 ticks are unchanged.

Not run locally: the Linux g++ build with `-Wall -Wextra -Wpedantic -Wconversion
-Wshadow`, sanitizers and benchmarks.

## Godot evidence

- `test_material_appearance_lut` (headless): passed — 132 IDs, 50 flair classes,
  building/living flair assignments, firework emission curve, burn curves,
  sludge/steam colour intent.
- `test_material_presentation_render` (graphical, actual framebuffer pixels):
  passed. New checks: every static building finish is time-independent and
  non-black; growth decor appears above Plant/Fungus and beneath a Moss Wall
  overhang and never changes material cells; `growth_decor` 0 removes it; zero
  vapour strength is an exact no-op and a remembered vapour only brightens Empty
  cells; the trail shader records current vapour, decays (Smoke outlasting
  Steam), clears on a zero delta and stays world-anchored under a camera pan; a
  flying Rocket is brighter than an idle one and is a glow source while an idle
  one is not; Mites animate; Sludge is darker than Acid; Steam is near-white.
  Pre-existing checks still pass (Oil still animates under the swirl).
- Full Godot regression run (`tools/ci/run_godot_regressions.py`, headless,
  180 s per runner) against the **retained, stale** runtime: every test passed
  except `test_microscenarios`, whose 15 failures are all the expected
  catalogue-size mismatch (`pair_rules` 56 in source versus 14 in the installed
  runtime: "INT-000 profile catalogue is incomplete" and "capture lost full INT
  profile"). The runner stops at its first failure, so the remaining runners
  were executed individually with the same flags (`--headless`, 300 s timeout): all
  34 exited 0 with no `ERROR:`/`SCRIPT ERROR` lines, so all 77 runners are accounted
  for. Graphical-only runners skip under headless and were run graphically above.
- `capture_material_review.gd` (graphical) renders the new `building` and
  `growth` plates; baseline plates use the `origin/main` shaders and LUT through
  the same fixture.

## Captures

Raw framebuffer readbacks (320×180 logical, 1920×1080, glow on,
`presentation_time_override` 1.37) are retained in
[material-fidelity-pass-2-2026-10-18](material-fidelity-pass-2-2026-10-18):

| Plate | Candidate | Baseline |
|---|---|---|
| Growth, fireworks, vapour, rust, sludge, oil, mercury, woods | [growth](material-fidelity-pass-2-2026-10-18/growth_t1.37_glow.png) | [growth baseline](material-fidelity-pass-2-2026-10-18/growth_baseline_t1.37_glow.png) (IDs 81+ magenta: absent) |
| Liquid trays | [liquids](material-fidelity-pass-2-2026-10-18/liquids_t1.37_glow.png) | [liquids baseline](material-fidelity-pass-2-2026-10-18/liquids_baseline_t1.37_glow.png) |
| Building catalogue 81–131 | [building](material-fidelity-pass-2-2026-10-18/building_t1.37_glow.png) | — |
| All 132 rows | [inventory](material-fidelity-pass-2-2026-10-18/inventory_t1.37_glow.png) | — |

The vapour afterimage is a frame-to-frame effect and does not appear in still
plates; its evidence is the feedback regression above.

## Cost

[`measure_material_presentation_cost.gd`](../../godot/tests/measure_material_presentation_cost.gd)
(graphical, 1920×1080 HDR world viewport, 320×180 view, 4 interleaved blocks of
200 frames, A = `origin/main` shaders/LUT, B = candidate) gained a `living`
scene (Plant/Fungus/Moss hosts, building panels, Rust, Sludge, Oil, Mercury,
vapour, Mites, flying Rockets). Measured world-pass GPU medians (ms, glow off):

| Scene | Baseline | Candidate | p95 candidate |
|---|---:|---:|---:|
| mixed street | 0.397 | 0.740 | 1.084 |
| effects | 0.827 | 1.196 | 1.667 |
| living (baseline renders IDs 81+ as flat magenta) | 0.276 | 0.778 | 1.230 |

The glow source stays below 0.05 ms. An isolation run with `growth_decor` 0
attributes about 0.09 ms of the mixed-scene increase to the growth-decor scans
(already trimmed to ≤ 6 + ≤ 5 reads for 45%/32% of Empty pixels); the rest is the
richer liquid swirl, corrosion and building finishes. The vapour viewports are
not in this rig; they are one 320×180 half-float pass per frame plus one read per
Empty pixel. Raw results: [cost.json](material-fidelity-pass-2-2026-10-18/cost.json).
One GPU only; the Planned quality tier and weaker-GPU/browser measurement in the
[effects register](../reference/material-effects-register.md#planned) remain open.

## Gaps and follow-up

- **Runtime publication pending.** The source-matched Windows/Linux GDExtension
  publication (the established temporary-workflow route used by MAT-001/GEN-002)
  must run before Godot can use IDs 81+ or the 56-rule catalogue; afterwards the
  full Godot suite including `test_microscenarios` must be re-run on that runtime.
- No browser/WebAssembly, Linux, weaker-GPU or target-PC measurement.
- No owner visual acceptance; probabilities and products are gameplay tuning.
- The vapour afterimage and growth decor are not exposed in a user-facing quality
  setting yet (`vapour_trail_strength`, `growth_decor`, `structured_detail`).
