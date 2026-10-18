---
title: Depth layers and parallax prototypes
status: Current
document-kind: contract
scope: Opt-in Strata Theatre prototypes for material-world layering, foreground-derived relief and explicit interlayer events; not production world ownership
canonical-for: [depth-layer-prototype, parallax-prototype, quantized-relief, interlayer-events]
last-reviewed: 2026-10-18
related-documents: [material-appearance-and-rendering.md, ../architecture/data-ownership-and-lifetimes.md, ../architecture/rendering-and-gameplay-bridges.md, ../audits/2026-10-18-depth-parallax-prototypes.md]
---

# Depth layers and parallax prototypes

## Purpose

res://depth_lab.tscn is an opt-in comparison host for visual and figurative
depth in CyberSand. It deliberately keeps several ideas visible side by side
instead of making one of them production authority.

The lab is called **Strata Theatre**. It can be opened directly, with
--depth-lab, or from the ordinary desktop sandbox with **F4**.

| View | Meaning |
|---|---|
| Flat | Foreground-only control. |
| Quantized relief | Bounded quantized samples of the foreground material image are offset/scaled behind the source silhouette to imply thickness. |
| Four layers | Four independently authored material worlds are rendered together with different scale/parallax factors. |
| Hybrid | Four layers plus foreground relief, distance haze and rear-scene reflection masked by foreground liquid IDs. |
| Diorama | Hybrid plus a faster near-camera foreground-derived frame and pointer-centred cutaway. |

None of the presentation-only modes creates authoritative Z coordinates,
colliders, hidden material mass or a second owner of the play world.

## Four material planes

The prototype owns four separate CyberNativeCellWorld objects through
CyberDepthLayerRuntime. Each world uses the existing native material IDs,
rules and RG8 RenderBridge projection. Godot owns only authoring,
presentation and explicit lab commands.

| Plane | Default rate | Intended use |
|---|---:|---|
| play | 60 Hz | Active foreground/play material. |
| scripted | 20 Hz | Rear set, destructible scenery and set-piece sequences that should not perturb foreground material. |
| effects | 30 Hz | Rain, snow-like Dust, Steam fog, Spark energy and other environmental material effects. |
| background | 0 Hz | Authored distant city. It is never ticked and its first copied RG8 publication is cached. |

The rates are independent. Dynamic planes may be reduced or paused without
changing the others. The background rejects non-zero rates.

The current host uses one native adapter owner and serializes calls into its
four worlds. Production adoption should integrate the play plane with the
existing asynchronous owner rather than introduce another mutable owner.

## Explicit interlayer routes

Interlayer mutation is not inferred from pixels or scene overlap. The prototype
admits only explicit routes:

- play -> scripted, kind blast: clear a bounded rear-set disc and seed Fire;
- scripted -> effects, kind burst: emit an admitted effects material.

scripted -> play, effects-to-play, writes into background, stale-generation
commands and unsupported route/kind combinations fail closed. Reset increments
a generation and retires queued commands from the previous theatre.

The **Rear reactor sequence / E** applies three bounded breaches to the rear
world, followed by a Spark burst in the effects world. The play world is not
modified. This is authored event projection; native explosions/reactions are
not automatically watched and forwarded between worlds.

## Quantized foreground relief

The relief prototype reads only the copied play RG8 texture and the already
rendered play material surface. It uses at most eight samples. Each sample:

1. derives a small scale/offset from camera displacement and relief direction;
2. snaps the source coordinate to a configurable pixel quantum;
3. reads the foreground material ID;
4. admits depth according to a small material-family depth table;
5. composites a darkened copy behind the foreground.

Hard/architectural material receives the deepest apparent extrusion, timber
and cobble a medium band, glass/ice/pipes a shallow band, while free liquids
and gases are not extruded. This is a visual approximation, not simulation
state.

## Parallax and authoring coordinates

The four worlds share a 640x360 authored ROI over the existing 1024x1024
native backing. Initial scale/parallax factors are:

- play 1.00 / 1.00;
- scripted 0.94 / 0.70;
- effects 0.88 / 0.44;
- background 0.78 / 0.18.

screen_to_layer() is the exact inverse of the rendered layer transform.
Painting therefore addresses the selected world's cell under the pointer.

## Additional visual experiments

Hybrid and Diorama add independently adjustable depth haze, rear-scene
reflection masked by foreground Water/Oil/Mercury, and a coarse near-camera
foreground-derived silhouette with a pointer-centred cutaway.

## Material-surface rendering and bounds

Each world is rendered by CyberDepthLayerSurface through the existing
material_palette.gdshader and CyberMaterialAppearanceLut. The private
compositing palette only changes Empty alpha to zero; material IDs and the
canonical appearance program remain unchanged.

Copied native packets are validated before changing an Image: RG8 only,
matching layer/reset identity, monotonic integer serial, at most 4096 patches
and 2 MiB packet bytes, in-bounds rectangle/stride data, cumulative staged
area no greater than one 1024x1024 backing, and exact full-refresh shape.
Every patch Image is constructed before the first blit.

ImageTexture.update currently uploads the whole 1024x1024 RG8 image after an
admitted changed packet: **2 MiB per changed layer upload**. Region texture
uploads or a smaller presentation backing are the clearest follow-up
optimizations.

## Controls

- **1-5** — Flat / Relief / Four layers / Hybrid / Diorama.
- **WASD / arrows** — camera pan.
- **Space** — pause dynamic planes; **Step** advances admitted dynamic planes once.
- **E** — rear reactor sequence.
- **R** — reset all four worlds.
- **Left mouse** — paint selected layer/material.
- **Right mouse** — erase selected layer.
- **Middle mouse** — toggle automatic camera motion.
- **Tab** — hide/show controls.
- **Esc** — return to a fresh ordinary sandbox.

Background remains immutable even if selected as a paint target, making the
failure visible rather than hiding it in UI policy.

## Integration boundary

The prototype changes no native C++, material semantics, save format,
dependency pins, actor physics, CI provider or ordinary renderer default.

Production adoption still needs decisions about persistence/streaming,
immutable cross-plane events, ROI/texture sizing and region uploads, actors on
non-play planes, replay semantics for independent clocks, and browser/lower-end
GPU cost.

## Reconstructed integration checkpoint

The [fresh integration audit](../audits/2026-10-18-depth-integration-validation.md) records new Windows/native and actual GPU checks, parsing/ROI/first-bake repairs and preserved failures. These qualify the reconstructed branch independently of the original local evidence. Frozen surfaces request a one-shot bake on publication or pause; each plane has its own render canvas.
