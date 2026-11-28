# A011 — skip downstream work when sampled coverage is exactly zero

## Hypothesis and source boundary

The final Linux software-rendered campaign at application
`fd0830abcfadd9ae19162e5677943bb131223e59` found a repeatable cost in the
balanced optical profiles. The lead requested an isolated shader experiment;
the frozen application and its qualification/package remain unchanged.

Candidate A1 changes only `godot/shaders/strata_optical_plane.gdshader`.
Its SHA-256 is
`50518cda2c8b9635d4b15b71ade65752fa9f859f447624940c9705acf814995f`.
The original shader bytes are exactly the frozen application's bytes before
this edit. The candidate adds one conditional after the existing centre and
low-frequency samples. If both sampled alphas equal zero, it emits transparent
black and skips the downstream tone, atmospheric, shadow, silhouette and actor
calculations. Otherwise the original processing expressions execute unchanged.

## Exact-output argument

The condition is exact `centre.a == 0.0 && low.a == 0.0`, not an epsilon test.
It therefore retains every nonzero aperture or diffusion contribution,
including faint coverage below a final RGBA8 quantization step.

The legacy expression retains the centre alpha, so the Classic interpolation
endpoint has zero alpha and zero premultiplied RGB in this branch. Pixel
aperture selects or interpolates centre/low coverage, both zero. Detail
suppression, tonal/chromatic processing, atmosphere, shadow masks and actor
reveal change RGB without adding coverage. Diffusion's only new coverage is
`low.a * highlight * min(diffusion * 0.28, 0.5)`, also zero. The final plane
opacity and clarity multipliers cannot introduce coverage. Consequently both
premultiplied interpolation endpoints are exactly transparent black; final
unpremultiplication explicitly returns black at zero alpha. This holds for
every admitted effect strength and plane/parent opacity, under the renderer's
existing finite-value and premultiplied-source contracts.

The literal Classic fragment branch, its straight-alpha blend, and the wipe
selection expression remain unchanged. The candidate does not discard a
fragment or change blending/depth state; it produces the same `vec4(0.0)` that
the complete optical branch would produce.

## Cost expectation and limits

This is a bounded downstream-work optimization. It retains all existing
surface texture reads, including the complete kernel when a neighbour can
spread coverage. On zero-coverage regions it avoids up to five Play shadow
samples and five Play silhouette samples, as well as colour arithmetic,
exponential transmission and bounded actor-rectangle arithmetic. Maximum
reads on covered fragments do not change. No texture, shader uniform, native
capture, World, cache, viewport, publication or simulation work is added.

No speed improvement is claimed before an actual matched comparison. GPU
branch divergence, compiler flattening, decorative occupancy and the rendering
backend may reduce or erase the saving. The software-rendered Linux failure
does not establish a physical NVIDIA performance result.

## Qualification plan and current result

The isolated no-native headless fixture passed 21 checks with the exact pinned
Godot 4.7 runtime. It explicitly reported `graphical_required=true`; this is
state/ownership validation, not a shader execution or pixel-equivalence pass.

The external `tools/ci/experiments/strata3_optical_override_test.gd` wrapper
inherits the unchanged frozen test, verifies the original and candidate shader
digests, and changes only the already-preloaded shared Shader resource in its
own process. It accepts an explicit `--optical-shader-override` path. With the
complete final frozen test/renderer it passed 27 headless assertions; passing
the original file as the candidate was correctly refused with exit code 2.
It leaves the inherited graphical test and its 109 assertions intact. The
lead's separate runner is responsible for rejecting headless-only evidence.

The independent graphical gate is the unchanged frozen renderer fixture in
the same backend for baseline and override, including all original PNG pixel
buffers, 109 assertions, the zero-difference Classic haze/opacity region and
the dense checker/white-hue progression. A paired half-opacity/intermediate
strength witness would additionally exercise the analytically covered
interpolation case. Native performance must be measured with the registered
repeat populations and actual completed-step intervals. The lead owns the
external source-pinned override campaign; no candidate is silently substituted
into the frozen evaluator.

Disposition: **isolated candidate prepared; actual graphical equivalence and
performance evidence pending**. The original measured performance failure is
retained regardless of this experiment's outcome.


## Hosted evidence checkpoint — 26 November

This checkpoint supersedes the earlier pending graphical status, without
promoting the candidate into application `fd0830ab`. The isolated v1 observer
was commit `c1b13096da9dbbe1c3c45f9ee4c48fa009e6f14e`, run
[45730815481](https://github.com/techrote/cybersand/actions/runs/45730815481).
The [machine-readable independent review](optical-a1-v1-partial-evidence-a.json)
retains exact artifacts, every original/candidate PNG digest, process/log
identities and the narrower disposition.

| Hosted backend | Original assertions | A1 assertions | Paired PNGs | RGBA bytes compared | Native timing disposition |
| --- | ---: | ---: | ---: | ---: | --- |
| Linux llvmpipe | 109/109 | 109/109 | 18 exact | 884,736 | Rejected |
| Windows ANGLE, Microsoft Basic Render Driver | 109/109 | 109/109 | 18 exact | 884,736 | Rejected |

These are genuine graphical fixture observations. Every pair was decoded and
compared, including alpha; the Classic haze/partial-opacity region also remains
exact. They are original-versus-A1 comparisons within each backend. They do not
assert equality between different backends or physical NVIDIA execution.

The native driver retained 15 windows on each host and reported no driver
assertion failures (4,007 Linux checks; 4,010 Windows checks). Nevertheless the
strict annex reader rejected both runs: the driver's mutable Shader code hash
was the candidate, while the presenter's `statistics()` hash was the original.
V1 did not retain actual cached/drawable attachment identities, and it stopped
before the final application-after custody snapshot. These are incomplete
native qualification records. No native rate or speed improvement from v1 is
admitted, and passing driver checks do not override the outer rejection.

An early explanation that this proved a detached shader or original-versus-
original execution was too strong. A subsequent pinned Godot4.7 diagnostic
reproduced the same resource identity before and after mutation: runtime Shader
variables and an attached material see the candidate code, while the compiled
constant/property expression and `statistics()` preserve the original source
hash. This establishes the observed evaluation distinction. It does not audit
the compiler mechanism or retroactively supply missing v1 attachment evidence.

Observer v2, source `55951750466dc76e0482954f3d9e8bd9a9d1ada4`, requires that
short source-pinned diagnostic on each host before graphics, treats the
statistics hash explicitly as frozen-application source provenance, and requires
the live shader plus every rear-plane material attachment to report the chosen
shader before and after every timed window. It retains exact material counts,
resource restoration, all original pixel gates and application-after custody.
Its [run45733231981](https://github.com/techrote/cybersand/actions/runs/45733231981)
was still in progress at this checkpoint. Its future result must be reviewed
separately; v1 is not relabelled or retroactively accepted.

Updated disposition: **isolated graphical fixtures equivalent on both hosted
backends; v1 native cost evidence rejected; corrected v2 experiment pending**.
The frozen application's registered performance failure remains unchanged.
