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

The transparent material SubViewport contains premultiplied RGBA. Colour
filtering sums premultiplied samples, divides by positive coverage for colour
transforms, then premultiplies the result once. Effect-strength interpolation
also remains premultiplied. At the final framebuffer boundary only, the
processed result converts to straight colour for `blend_mix`, which applies
source coverage and parent opacity once. Every sample explicitly refuses
coordinates outside the source extent and addresses integer texel centres with
nearest filtering. No material IDs are interpolated.

The original HAZE shader's historical blending is deliberately preserved in
Classic. The one-pass wipe executes the literal historical straight-colour
expression and the same fixed-function blend on its Classic side, with no
premultiply/unpremultiply roundtrip. Its boundary uses viewport X. During a partial wipe, optical parallax
multipliers are temporarily suppressed so both sides use the Classic geometric
transform; the effect itself is not rendered a second time. This is an optical
treatment comparison, not two independently moving cameras.

Godot's official [SubViewport texture tutorial](https://docs.godotengine.org/en/stable/tutorials/shaders/using_viewport_as_texture.html)
and [CanvasItem shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html)
describe the premultiplied source and blend choices. Actual rendered pixels are
required to establish this implementation's correctness, including integer
framebuffer rounding rather than floating-point algebra alone.

### Retained framebuffer-precision failure

The initial implementation used `blend_premul_alpha` for the final output and
an algebraically equivalent premultiplied expression for the Classic wipe.
Source `146cead1ac41147efa993b0bf8b634da08695182`, hosted Linux run
[45720008446](https://github.com/techrote/cybersand/actions/runs/45720008446),
artifact `15070878821`, failed exactly one of 108 renderer checks: byte-exact
Classic wipe under haze 0.3 and parent opacity 0.5. The actual backend was
Godot 4.7 Compatibility, OpenGL 4.5 Mesa 25.2.8 llvmpipe LLVM 20.1.2. Dense
checker progression and every tested thin-white hue/alpha relationship passed.

The integration lead independently reproduced the mismatch in a separate
surfaceless EGL blend probe. Fixed-function straight blending and shader-side
premultiplication can round differently in an RGBA8 target even when their real
number algebra is identical. That auxiliary probe is diagnostic evidence, not
Godot qualification. The earlier source-only assertion review incorrectly
treated algebraic equivalence as sufficient for exact bytes; this graphical
negative supersedes that assumption.

The focused correction preserves premultiplied filtering and interpolation,
uses `blend_mix` at the final boundary, and gives Classic a direct legacy
expression. The test's exact byte oracle is unchanged. It now saves both the
Classic haze/opacity baseline and its wipe companion and reports changed
channel count, maximum byte delta and compared byte count. The correction
requires a fresh graphical campaign before qualification can be claimed.

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

## Published actor reveal extension

The initial primary sampled-player rectangle did not cover the ordinary Midge
and other physical Workbench actors. The extension reads only the data already
held by `physical_actor_overlay` and `actor_prototype_overlay`. A pure
`actor_presentation_bounds.gd` helper merges the displayed transforms into at
most eight axis-aligned actor bounds. It inspects at most 64 physical render
parts, matching the current admitted native mask/part budget, or eight copied
prototype records. Existing rotated and interpolated display poses are reused;
the helper does not call the actor session, Rapier, World, worker or input.

The presenter asks for those bounds only while clarity assistance is active.
The same three plane shaders receive eight fixed rectangle slots and a live
count. A retired/empty publication clears that count immediately. The original
sampled-player path remains available. No actor colour, transform, collision,
edit target or physical opacity changes. This is local attenuation of rear
content; it creates no front-of-Play plane and adds no texture or render pass.

The conservative union can include empty space between articulated parts. That
is a presentation limitation, not collision information. The scope is eight
published actors plus the primary sampled player, without claiming visibility
for arbitrary unregistered overlays. Multiple rectangles add bounded scalar
shader work only in the explicit clarity path, requiring comparative timing.

The pure helper's pinned-engine headless test passes 26 checks covering rotated
compound bounds, legacy and extended prototype records, nonfinite/malformed
inputs, source immutability, eight-actor and 64-part limits, and empty retirement.
The focused renderer still passes its 18 headless checks. New actual-renderer
assertions and an `actor-reveal.png` capture check local attenuation and removal
of stale reveal; these need a subsequent hosted graphical source identity.

Specialist C's integrated diagnostic caught a real adapter error after this
extension: a ternary expression produced an untyped empty `Array` when clarity
was off, while the dynamically called renderer required `Array[Rect2]`. Its
positive assertion count did not override repeated runtime errors. The fix
(`41adff8d`) uses an explicitly typed local array before the call. This is
retained as a failed integration attempt; the pure helper and renderer tests
alone had not exercised that presenter boundary.

### Actor-capacity and selection clarification

An independent source review after the high-ID helper repair checked whether
a selected ninth actor could be omitted while eight earlier actors remained
alive. Ordinary Workbench admission rejects this population: `WorkbenchSetup`
limits authored actors to eight, `WorkbenchActorCatalog.capacity_error` also
enforces eight logical actors and 64 combined parts/proxies, and
`PhysicalActorSession.valid_definitions` repeats those limits. The current
`render_parts` publisher uses slot indices 0–7 for `actor_id`; persistent
Workbench instance IDs such as 9 or 100 map separately to those slots. The
helper's acceptance of arbitrary nonnegative IDs is defensive capacity
handling, not evidence that the ordinary publisher emits a ninth active slot.

The `player_origin_px` path is the separate sampled-character position. It is
hidden offscreen when the ordinary Workbench disables that sampled player or
when sampled prototypes replace it. It is not a fallback rectangle for the
selected Rapier/Midge actor. All currently admitted ordinary physical actors
fit the eight-rectangle and 64-part bounds. If a future programme admits more
actors or combines both overlay families concurrently, selection priority must
be revisited: the helper currently has no priority guarantee for a ninth
published actor. No authority or admission limit was changed by this review.

## Frequency and quality witness extension

The first hosted 59-check source (`12b6beed`, campaign `45711742479`) passed its
actual alpha checks on both ANGLE/Microsoft Basic and llvmpipe. All six PNGs were
byte-identical. Independent A/B inspection also found an evidence limitation:
flat rectangles cannot establish frequency-selective detail suppression.

The focused test now includes an actual one-cell checkerboard, isolated white
impulse, texture-edge impulse and partial-alpha blue patch. It checks reduced
interior checker contrast with exact retained alpha; bounded white diffusion;
high-quality diagonal sampling at the six-cell maximum; low-quality one-cell
sampling; parent opacity applied once; and pixel-exact Classic wipe algebra
under nonzero legacy haze and parent opacity. Six additional original captures
record these distinct paths. The extension parses/runs its 18 headless checks
locally but its new pixel assertions require the next hosted graphical run.
