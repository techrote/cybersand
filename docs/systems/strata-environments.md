---
title: Strata environments and visual atmosphere
status: Current
document-kind: contract
scope: Optional native layered environment library, reusable parts and bounded presentation-only atmosphere in ordinary Workbench
canonical-for: [strata-environment-library, strata-visual-atmosphere]
last-reviewed: 2026-11-28
related-documents: [strata-workbench.md, depth-layers-and-parallax.md, ../operations/strata-workbench-evaluation.md, ../architecture/shared-workbench-authoring-data.md]
---

# Strata environments and visual atmosphere

This document describes the successor's authored native environment library and bounded visual atmosphere. The ordinary Workbench owns Play, its actors, camera, worker and physical progression. The three decorative native planes remain independently owned, paused and static. The atmosphere renderer creates no World, native material, texture upload, collider or actor.

The implementation remains optional. The owner accepted Strata 003 on Windows 11 with an NVIDIA TITAN RTX and authorized adoption of its complete predecessor functionality on 28 November 2026. The [combined delivery guide](../operations/ramcache-strata-integration.md) records the resulting integration and its separate qualification. These source descriptions and deterministic recipe checks do not substitute for source-bound native, graphical or packaged evidence.

## Native environment library

The five recipes in `godot/data/strata2/` are original, exact native material-ID constructions. They do not import an archived SANDMAPS native canvas, Gold nomination, active architecture branch or raster screenshot. Their generator is `tools/strata2_build_showcases.py`. Existing #769 examples remain independently selectable.

| Scene ID | Native extent | Physical Play composition | Rear / effects / distant contribution |
| --- | --- | --- | --- |
| `orbital-terminal` | 2048 × 1024 | Suspended steel gantries, cargo landings, long lower flight corridor | Megatrusses and docking frames; sparse service panels and vents; connected distant dock arms, stepped towers and signal pixels |
| `neon-rain-arcology` | 2048 × 1024 | Uneven rooftops, inhabited platform faces and open lower route | Separate rear towers and skybridges; native signs plus visual rain; isolated far towers with large gaps |
| `industrial-underworks` | 1024 × 1024 | Alternating maintenance tiers and continuous central shaft | Hollow rear reactor windows and pipework; native vents plus visual steam; a static native annular turbine and pressure columns |
| `abyss-foundry` | 1024 × 1024 | Irregular basalt shelves and sparse industrial ledges around a large void | Rear maintenance structures; mineral details plus localized mist and motes; attached distant ceiling contours, cliffs and tapered formations |
| `vertical-transfer-spine` | 1024 × 1536 | Alternating side landings around a tall clear transfer shaft | Rear carriage cages, continuous cables and a pulley; signal panels and visual movement; separated distant habitation |

Each file includes the ordinary actor spawn, explicit geometric route proposals, two camera detail locations, individual plane roles, rectangle counts, write-cell bounds and ordered recipe digests. Play is never inferred from a composited screenshot. The large empty regions are deliberate: successive planes do not fill every opening with another opaque wall.

The generator checks a radius-34 swept square for each declared route: 69 × 69 cells when both edge coordinates are included. That is a useful authoring constraint, **not a movement result**. Actual Midge control, clearance during rotation, collision, continuous traversal and high-speed readability require ordinary Workbench execution. No static mask proves load bearing or structural stability.

Native scene source inspection is available through `strata_showcase_scenes.gd`. It checks fixed identities, exact known fields, admitted extents, native material validity, protected borders, recipe hashes, visual settings and metadata before producing the existing Setup/document candidate pair. It does not directly create or replace a live Play World.

## Reusable native parts and layered plans

`strata_authoring_library.gd` exposes eight fixed parts: rear truss bay, hollow reactor window, service pipe elbow, signal panel, paired vent stack, habitation light lattice, cargo cell and distant service spire. Their exact-grid material payloads and separate no-write masks use the strict `cybersand-strata-module-v1` codec. All part canvases are at most 128 × 128. The original part recipes can be rebuilt with `tools/strata2_build_part_recipes.py --package`; `--check` verifies the checked-in bytes.

Three layered presets reuse them:

| Preset | Explicit ordered stages | Target planes |
| --- | --- | --- |
| Factory service bay | Rear bay, cargo, vent, far spire | Scripted, effects, background |
| Reactor service arch | Reactor, pipe, signals, far bay | Scripted, effects, background |
| Inhabited skybridge | Rear lattice, two adjacent bridge bays, sign, far spire | Scripted, effects, background |

The owner chooses a shared anchor. The library resolves fixed module identities, binds current scene and plane revision observations, and asks the existing finite plan contract to compile a **zero-write proposal**. Stages retain explicit dependencies and native material permissions. A hidden or skipped dependency cannot be reported as completed. Native approval, ordered bounded execution, truthful partial outcomes and readback belong to the session and ordinary owner adapter.

Transparent module cells preserve the existing target. None of these eight parts requests Empty-cell clearing. The reactor window and vent stack declare small required clearances; an occupied target clearance must refuse placement. A part's metadata describes authored intentions, not a solved attachment or load-bearing connection.

Preset atmosphere and depth settings are included as a separate, anchor-relative proposal. Approval of native construction does not silently enable those effects or change visual settings. The explicit reviewed settings action becomes available after native completion; it replaces the current atmosphere configuration as stated in the UI. Existing native Undo history is per plane and per acknowledged bounded chunk, with no cross-plane rollback promise.

## Atmosphere controls and exact meaning

The atmosphere field belongs to the authored Strata v2 document. Its own version is `1`, with explicit enabled/paused flags, a deterministic global seed and at most twelve effect records. Effect targets are `scripted`, `effects` or `background`; Play is excluded. Each record contains identity, kind, integer native-coordinate region, seed, count, speed, strength, two direction components, RGBA colour and enabled state. Unknown fields, unsupported kinds, invalid IDs, fractional coordinates, nonfinite numbers, out-of-extent regions and excessive budgets are refused.

| Profile | Visual behavior | Meaning of speed and direction |
| --- | --- | --- |
| Drifting haze | Sparse layered pixel bands | Native cells per presentation second along the declared direction |
| Vent steam | Rising or falling widening puffs | Native cells per presentation second; vertical direction sets rise/fall, horizontal direction sets drift |
| Slant rain | Short directional pixel streaks | Native cells per presentation second along the direction; no native Water or mass |
| Suspended dust | Seeded one- or two-pixel motes | Native cells per presentation second along the direction; no native Dust |
| Warning beacons | Low-frequency colour pulse bars | Pulse multiplier: `0.2 × speed` cycles per presentation second; direction does not affect the pulse |
| Conveyor lights | Repeating moving signal bars | Native cells per presentation second along the declared direction; no moving physical machine |

Count is the actual seeded motif count, from 0 to 96 per effect and at most 384 across the complete scene. Speed is bounded to 0–64, strength to 0–1, direction components to −1–1 and each RGBA component to 0–1. Strength multiplies the authored alpha. Region and canvas clipping are explicit. Existing layer opacity is inherited once; effects do not introduce additive glow or physical light transport.

All settings are applied live after validation. Changing a seed regenerates its deterministic motif positions; Reset motion returns presentation phase to zero. Save/Reopen restores seeds and settings, then starts the visual phase anew. It does not restore exact evolved multi-World physical continuation.

Global Pause freezes all atmosphere. Hidden, Solo-excluded, Flat-excluded, zero-opacity or disabled Strata planes freeze their own visual clocks and stop recurring effect callbacks. A locked plane continues showing its existing atmosphere but refuses regional effect addition, removal or editing. Scene-wide Enable/Pause and Reset motion remain separate controls. Disabling one effect hides that effect; when other effects on the same plane continue, re-enabling it joins that plane's current phase. To freeze all motifs together, use Pause animation.

The visual clock is deliberately independent of native physical time. A callback contributes at most 0.1 seconds. Excess elapsed display time is measured and discarded; resuming after a stall or hidden interval does not issue catch-up work. Zero-speed effects retain a static visual image. A plane with no enabled, positive-alpha, positive-strength moving motifs has no recurring atmosphere processing.

## Presentation seam and cost boundaries

One lightweight native-coordinate CanvasItem renderer is a child of each existing decorative TextureRect. The existing presenter supplies scale from native extent to the current drawable size. Parent transforms supply the established camera/parallax relation, parent alpha supplies plane opacity, and the existing clipping ancestor supplies the Workbench content boundary. Drawing remains behind the ordinary Play image and actor presentation; nothing replaces the camera or public render scheduler.

The visual plane order is fixed: Play, scripted architecture, effects, then background. Relative depth controls the existing parallax and distance-haze relation; it does not reorder planes or move collision. Reset presentation restores the layer/view defaults while preserving authored atmosphere. Reset motion only returns transient motif phase to zero. Neither control changes native geometry or physical ownership.

Unchanged native decoration retains zero recurring native captures and uploads. Visual atmosphere queues CanvasItem redraws only for active moving motifs. It does not invalidate the baked native material surfaces. It can still consume presentation CPU and GPU work, and its actual cost must be measured alongside Play progression and frame callbacks. Constant zero-native counters in the renderer describe its code path; independent owner/publication witnesses establish the execution claim.

The maximum source extent remains 2048 per axis; independent decorative resolution and native decorative ticking are not introduced by this library. Larger authored placements use the separately bounded native import/plan contract. Atmosphere is not an excuse to run four dense cellular simulations.

## Reference artwork and alpha honesty

The real-source import inputs in `godot/data/strata2/reference-imports/` are exact pixel crops of the public asteroid service gallery and rocket assembly hangar originals at `techrote/sandmapsreference` commit `99a166e7fcae45eb22be1740e9f33f62faccbcc7`. Both inspected original PNGs are opaque RGB. Their separate masks are authored selections with large internal no-write areas. They are not recovered source alpha or inferred depth.

The fixture provenance preserves original URLs/digests/resolution, original crop coordinates, crop pixel digests, mask recipes/digests, explicit RGB-to-material choices, colour-distance limit, unknown-colour policy and predicted material/mask byte digests. Original images remain unmodified. The bundled small crops keep exact source pixels without resampling.

The synthetic alpha fixture in `data/strata2/imports/` exercises actual transparent and partly transparent pixels. It is clearly separate from these opaque reference sources. Neither a source image nor an import proposal-colour preview is a native output capture.

## Review and qualification boundaries

Focused source/value tests cover strict profiles, clocks, native scene admission contracts, part masks/transforms, finite preset compilation, real PNG decoding and independent proposal digests. The first integration check exposed a JSON integer/float palette-membership defect; canonical normalization was repaired in the library and the generic codec, with real JSON roundtrip coverage. That original failure remains part of the mission record.

Final graphical review must inspect actual full-stack, each isolated native plane, native-resolution details and matched atmosphere OFF/ON frames. It must check occlusion, readable collision-plane silhouettes, retained transparent openings, hidden/Solo/opacity behavior, route probes, imported material readback and saved settings in a fresh process. Software display captures and callback intervals cannot establish physical Windows/NVIDIA appearance, displayed GPU FPS or owner playfeel. Those remain separate owner gates.

The portable `Gallery.html` is generated from the final admitted Windows campaign and retains only relative references to its original PNG files. The generator checks exact source inputs, original scene reports, capture hashes and any nominal native-grid detail receipt (within the recorded 1% scale tolerance) before emitting the gallery and its input manifest. Full-stack and isolated reference views use the initial native showcase identities; matched atmosphere trial frames carry their own same-geometry identities because qualification edits can differ from the reference scene. The browser fits images by default; 100% image size means CSS pixels and does not override browser or OS display scaling. Gallery generation and Python tests do not themselves qualify browser appearance or Godot execution.
