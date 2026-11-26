# Integer texel fetch — source-only follow-up assessment

Date: 26 November 2026. Reviewer: Specialist A. **Proposed; no shader candidate
implemented, no graphical qualification and no performance claim.** The lead
requested this bounded assessment while the separately qualified A1 experiment
was awaiting its Windows result. It does not change application `fd0830ab` or
the A1 shader/observer identities.

## Concrete opportunity

The frozen application shader
`b64c8fe105fb981b56aab38f44cfca2f875ea975792593c11dd9692892a0e8eb`
starts its material point at `floor(UV * surface_size) + 0.5`. Every dense-aperture
offset is an integer cell distance. `sample_surface` then checks bounds, floors
that already centred point, adds the half-cell again, divides by `surface_size`
and calls a nearest, non-repeating normalized texture lookup.

After the unchanged bounds guard, an integer coordinate fetch at mip level zero
can express the intended discrete cell directly. For a nonnegative finite
coordinate, integer truncation and floor select the same integer. The aperture
would retain its exact sample positions, positive weights and read-count bounds.
The intended simplification concerns coordinate arithmetic and sampling setup,
not the number of texture reads or the optical response.

The current [official Godot shader-function reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shader_functions.html#shader-func-texelfetch)
exposes `texelFetch` for a `sampler2D`, integer two-dimensional coordinates and
an integer mip level. Its entry does not carry a Compatibility exclusion. This
supports interface feasibility; the moving stable documentation is not an
actual pinned Godot4.7 graphical result or an audited compiler-disassembly
result. The existing hosted backends are the relevant execution targets for any
future implementation.

## Exactness constraints

The existing out-of-surface return must remain before coordinate conversion.
Truncation toward zero could otherwise turn a negative fractional position into
cell zero. This matters especially if the same change is considered for Play
occupancy reads, whose parallax and shadow offsets can be fractional. Explicit
bounds also avoid relying on implementation-specific out-of-range integer fetch
behavior or sampler edge clamping.

The source contract must continue to bind `surface_size` to the actual source
texture, preserve its format and colour interpretation, and select the existing
base image. A change must not accidentally introduce mip selection or alter
premultiplied RGBA handling. These are qualification obligations, not observed
failures of the current code.

The centre sample is shared with the literal Classic-wipe branch. Changing the
helper therefore changes that branch's sampling operation even though its haze
expression and fixed-function blend remain untouched. The prior one-channel
blend-rounding failure demonstrates why algebra alone cannot discharge the exact
Classic requirement. Any future implementation needs actual before/after RGBA
comparison at alpha boundaries, nontrivial haze and parent opacity, texture
edges, odd/different extents and representative camera zoom/parallax states.

## Cost uncertainty and disposition

No compiler IR, machine code, driver shader dump or equivalent optimization
receipt is present in the current artifacts. The compiler may already hoist the
uniform reciprocal, remove redundant floor operations, or otherwise transform
the normalized lookup. Conversely, integer fetches can map to a different
backend path. This assessment does not choose between those possibilities or
claim that one API spelling is universally faster.

The worst texture-read census would remain unchanged, including the bounded
cross filter and optional Play-mask reads. A future candidate would need an
independent source hash, the established exact-output fixture and native-world
comparisons, direct actual material attachment witnesses, and matched completed-
step timing with the original criteria. It cannot inherit A1's performance
result just because both are small shader edits.

Disposition: **source-feasible follow-up, deliberately unimplemented pending the
current two-host A1 decision**. The already demonstrated zero-coverage improvement
and its remaining Architectural rate miss are recorded separately in the
[A1 Linux v2 review](optical-a1-v2-linux-review-a.md).
