# Strata003 optical renderer: initial source and experiment record

Status: implemented candidate; actual graphical qualification pending. This file
records research evidence, not authority to merge or enable a default.

## Selected architecture

The existing three rear `TextureRect`s sample their existing frozen material
SubViewports through one modular CanvasItem shader. Each participating plane
owns one lazy cached `ShaderMaterial`. This adds no World, texture, SubViewport,
native publication, occupancy scan, render readback or physical clock. Uniform
values are cached; unchanged values are not resubmitted. The existing enabled
Strata controller calls `advance_optics(delta)` only to interpolate a changing
focus distance. The interpolation clamps each visual interval to 0.1 seconds
and does not catch up after stalls.

Play's material, glow, actor rendering and camera ownership are unchanged.
Classic, bypass, optical strength zero, disabled Strata and a nonparticipating
plane bind the exact preexisting HAZE material object. Temporary inspection and
quality do not modify the authored configuration. Bypass wins over clarity.

## Distinct implemented treatments

| Treatment | Mechanism | Qualification status |
| --- | --- | --- |
| Pixel aperture | Cross or diagonal integer-cell samples, continuous crossfade between adjacent integer radii, maximum six native cells | Source implemented; graphical gate pending |
| Detail preservation | Low-frequency interior colour replaces fine contrast while retaining original alpha silhouette | Source implemented; graphical gate pending |
| Highlight diffusion | Bounded local bright-pixel spreading with coverage union and retained centre detail | Source implemented; graphical gate pending |
| Tonal and chromatic depth | Plane contrast/saturation/tint/brightness, optical-depth-dependent black lift and highlight compression | Source implemented; graphical gate pending |
| Atmospheric perspective | Exponential artistic attenuation toward editable scattering colour, independent from geometry depth | Source implemented; graphical gate pending |
| Architectural shadow | Optional bounded samples of the existing Play RG8 texture; explicit architectural material family, directional offset and five-tap softness | Source implemented; graphical gate pending |
| Physical clarity | Rear-plane attenuation with local nonempty Play silhouette and published primary-player rectangle assistance | Source implemented; graphical gate pending |
| Parallax comparison | Per-plane presentation multiplier uses the existing reversible transform; exact Play mapping retained | Integrated source; graphical/input gate pending |

Shadows are stylised presentation projection, not physical light transport.
Illumination uses rendered brightness as a highlight proxy; it is not a native
emission/material classifier. Actor assistance uses the already published
primary-player rectangle, not a new actor authority or complete arbitrary-rig
visibility oracle. The real actor overlays remain untouched.

## Alpha and sampling contract

The transparent material SubViewport contains premultiplied RGBA. New processing
uses `blend_premul_alpha`; colour filtering sums premultiplied samples, divides
by positive coverage for colour transforms, then premultiplies the result once.
Every sample explicitly refuses coordinates outside the source extent and
addresses integer texel centres with nearest filtering. No material IDs are
interpolated. Parent opacity scales RGB and alpha together exactly once.

The original HAZE shader's historical blending is deliberately preserved in
Classic. The one-pass wipe emulates that exact historical algebra on its Classic
side. Its boundary uses viewport X. During a partial wipe, optical parallax
multipliers are temporarily suppressed so both sides use the Classic geometric
transform; the effect itself is not rendered a second time. This is an optical
treatment comparison, not two independently moving cameras.

Godot's official [SubViewport texture tutorial](https://docs.godotengine.org/en/stable/tutorials/shaders/using_viewport_as_texture.html)
and [CanvasItem shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html)
establish the intended premultiplied blend contract. Actual rendered pixels are
still required to establish this implementation's correctness.

## Initial execution and retained negative result

Pinned official Godot `4.7.stable.official.5b4e0cb0f`, Linux executable SHA-256
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`, ran an isolated
project containing the exact shader, renderer and focused test. The initial
compiler rejected a nested function use of the built-in `TEXTURE` sampler.
Replacing it with a named alias of the same existing surface texture removed
that error; no texture copy or allocation was introduced.

The repaired headless run passed 15 structural/lifecycle checks and explicitly
reported `graphical_required=true`. It does not qualify rendered pixels. The
focused graphical continuation includes original transparent-source captures,
half-opacity colour/coverage, no empty-region leakage, pure-hue defocus edges,
out-of-bounds sampling, detail silhouette retention, exact Classic restoration,
one-pass wipe, transient focus, quality bounds and 30 material reuse cycles.

Local Xvfb execution is blocked by the environment's denied socket creation.
No local graphical pass, physical NVIDIA performance or perceptual acceptance is
claimed. The integration lead owns the explicit hosted platform campaign.

The first source review found that caching an entire plane record would copy
authored rectangles on every live optical slider update. The renderer now caches
only each plane's geometric parallax depth. `apply_optics()` validates/copies the
bounded optical configuration alone and preserves existing geometry arrays.
This is a settings-only path; it does not weaken full scene admission. Three
focused structure checks and bypass-with-clarity precedence were added, bringing
the isolated headless population to 18 checks before graphical qualification.

Specialist B's source review identified missing MAT002 basalt, obsidian,
aluminium and brass in the first shadow mask. The corrected classifier covers
the complete currently admitted native Solid set (excluding reserved ID10),
including all building IDs38–131; gases, liquids and powders remain negative.
The focused graphical test now contains eleven material-mask witnesses. Glass
uses the same stylised solid mask; physical glass transmission is not modelled.
