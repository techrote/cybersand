# Specialist A — final dense-kernel assertion review

## Review status

The initial review below was recorded while the hosted graphical campaign was
still running. It checks whether the assertions express the intended rendering
contracts and whether their expected values follow from the actual shader.
It is not a substitute for the graphical results. **A later actual result
disproved the review's byte-exact blending assumption; the correction and
unchanged oracle are recorded below.**

The final dispatch identity supplied by the integration lead is application
`88d6a7c5194876c998ded0b6061429a11f3ac118`, tree
`4dd90196509fad85c94ffda9ac49a0a340c4ed01`, Actions run
[45718951534](https://github.com/techrote/cybersand/actions/runs/45718951534).
The review covers `godot/tests/test_strata_optical_renderer.gd`, including the
27 headless assertions and its graphical continuation, against the dense
binomial implementation in `godot/shaders/strata_optical_plane.gdshader` and
`godot/scripts/depth/strata_optical_renderer.gd`.

## Dense aperture and frequency witness

The centre weight plus twice the positive-offset sum is one for every retained
binomial row and for their linear interpolation. The shader's four axial taps
multiply each positive-offset weight by one half, so the CPU normalization
assertion represents the actual GPU sum. The sampled spatial-frequency check
uses the same cross transfer function, rather than asserting only that a list
of coefficients matches an implementation constant.

The one-cell checker occupies source coordinates `[8,24)` in both axes.
The two probes at `(14,14)` and `(15,14)` retain full source support at radius
six: their horizontal and vertical sample locations remain inside the checker.
Consequently, declining contrast cannot be explained by sampling transparent
texture outside the fixture. Radii 0, 1, 2, 3 and 6 challenge the old even/odd
contrast-return failure directly. The old sparse kernel's radius-two and
radius-six checker response would violate these assertions.

At radius six, the isolated white impulse at `(40,16)` contributes to its
immediate horizontal neighbour with coefficient
`0.193359375 × 0.5 = 0.0966796875`. The expected RGBA8 coverage is approximately
25/255. The assertion's absolute tolerance of 0.015 accommodates small output
quantization differences while still distinguishing the intended dense
near-neighbour contribution from no contribution or a materially different
kernel. The white-hue scan compares every colour channel to coverage around the
thin impulse, so a dark premultiplication fringe or coloured contamination
cannot pass merely by meeting this single alpha value.

The far-edge probe at `(63,44)` is separated from the source impulse at `(0,44)`
by the texture boundary. Explicit zero sampling outside the surface must leave
it empty at maximum radius. The Low probe distinguishes the actual one-cell
support from the radius-six configuration retained in the authored settings.

## Detail and diffusion witnesses

With a one-cell checker contrast of approximately 0.8, the symmetric radius-one
low pass has approximately zero checker contrast. A detail contribution of
0.75 should therefore retain approximately 0.2 contrast. The asserted range
requires substantial suppression while retaining nonzero fine variation.
Every source alpha value is compared exactly against the reference across the
64 × 64 plane; this addresses silhouette and partial-coverage preservation
independently of the contrast measurement.

For diffusion, the radius-two filter contributes `0.0625 × 0.5 = 0.03125`
coverage at the two-cell neighbour of the white impulse. The authored
illumination plus the diffusion lens contribution reaches the bounded halo
factor of 0.5. The resulting halo coverage is `0.015625`, approximately 4/255,
which lies above the 0.01 lower bound without depending on a sub-quantization
signal. White RGB must match that coverage, and the original centre must remain
opaque and white. This fixture distinguishes bounded luminous spread from
simply blurring the entire source image.

## Alpha, comparison and actor checks

The half-blue source is already rendered through an actual transparent
SubViewport. Applying parent alpha 0.5 to source alpha 0.5 should produce
approximately 0.25 premultiplied blue and 0.25 coverage. The check rejects an
extra multiplication by source or parent alpha.

The nonzero-haze comparison tests a complete 64 × 64 Classic-side region
against the original material. The initial source review reasoned that parent
opacity 0.5 preserved algebraic equivalence between the old straight-alpha
blend and the shader's premultiplied expression. That reasoning did not account
for fixed-function blend-factor precision in an integer framebuffer. It was
insufficient to establish exact bytes, as the actual negative below shows.
The all-Classic path separately restores the original material object and
compares complete rendered bytes.

The actor fixture uses an empty Play mask, so local attenuation cannot be
explained by nearby physical occupancy. Full local reveal predicts rear red
0.24; distant rear content predicts 0.42. Retiring the published rectangle must
restore the near probe to 0.42 and clear the reported rectangle count. These
checks exercise published presentation data and do not establish collision,
native actor progression or human recognition by themselves.

The six added procedural-motif assertions check bypass priority, temporary
clarity, authored plane exclusion, restoration and the declared partial-wipe
limitation. They verify the helper's modulation contract; the integrated
Workbench harness separately observes the real atmosphere node modulation.

## Initial disposition before hosted results

No concrete assertion blocker was found. The fixture regions, coefficients,
alpha relationships and tolerances are coherent with the intended shader.
Actual uniform-array upload, dynamic loop execution and compatibility-driver
behaviour still require the hosted graphical run. Passing headless checks
alone does not qualify the new aperture or its alpha behaviour.

The result remains narrower than human gameplay acceptance: these synthetic
fixtures cannot establish route comprehension, actor noticeability during
movement, preservation of a large environment's architectural character or
physical NVIDIA performance. They support the scene and movement evidence,
rather than replace it.

## Actual sequence-five result and focused correction

The sequence-three and sequence-four dispatches encountered coordinator or
download failures before the required Linux graphics. Sequence five reached
the actual renderer using unchanged Godot source, application
`146cead1ac41147efa993b0bf8b634da08695182`, run
[45720008446](https://github.com/techrote/cybersand/actions/runs/45720008446),
Linux artifact `15070878821`. It passed 107 of 108 checks. The exact Classic
wipe assertion failed; the new frequency, thin-white, detail, diffusion and
actor-retirement assertions passed.

Independent reads of the original PNGs found checker contrast 229−25 = 204
RGBA8 levels initially, 153−102 = 51 after detail treatment, and zero at
aperture radii 1, 2, 3 and 6. The radius-six near impulse was `(25,25,25,25)`;
the two-cell diffusion halo was `(4,4,4,4)`. Those observations support the
specific filter contracts, while the whole candidate remained failed.

The failed Classic wipe produced `(82,84,86,128)` on the bright checker and
`(91,93,95,128)` at the white impulse. The integration lead reproduced those
premultiplied results independently with EGL, while the legacy straight blend
produced `(83,84,86,128)` and `(92,94,95,128)`. The exact Godot Classic baseline
was not separately saved in that failed test, so these latter diagnostic values
are not mislabeled as original Godot capture measurements.

Correction `bdd7a6cf7c004b7b020d9ef2c95be4153a250013` preserves premultiplied
filtering and effect interpolation, switches the final boundary to the same
straight-alpha blend, and executes the literal legacy expression on the
Classic wipe side. It also saves the missing Classic baseline and prints the
changed-channel count and maximum byte delta. The byte oracle was retained.
The correction was published as `fd0830abcfadd9ae19162e5677943bb131223e59`, tree
`fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499`, for sequence-six run
[45721790366](https://github.com/techrote/cybersand/actions/runs/45721790366).
That fresh graphical result is required before the correction is qualified.
