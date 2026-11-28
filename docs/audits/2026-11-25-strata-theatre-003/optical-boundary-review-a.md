# Specialist A — final alpha, authority and timing interpretation

## Source and review boundary

This independent source review concerns application
`fd0830abcfadd9ae19162e5677943bb131223e59`, tree
`fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499`. It follows the real RGBA8 blend
precision failure and its focused correction, rather than treating the earlier
premultiplied output as qualified. The source-level conclusions below require
the separately retained graphical and native execution records.

## Final straight-alpha boundary

The shader retains premultiplied RGBA for filtering, halo coverage union and
effect-strength interpolation. Both the optical value and the premultiplied
representation of Classic are nonnegative and satisfy `RGB <= alpha` for the
validated parameter/source ranges. A convex strength interpolation preserves
that bound. Only the final processed value converts to straight colour;
`blend_mix` then applies coverage and parent opacity once. The Classic wipe
branch executes the original straight-colour expression directly.

| Boundary case | Intended source-level result | Qualification limit |
| --- | --- | --- |
| Effect strength 0 | Renderer restores the original material; the shader's own zero-strength branch is also literal Classic | Temporary explicit clarity can override authored strength; bypass still wins |
| Effect strength 1 | Fully processed premultiplied result is converted once at the framebuffer boundary | Actual RGBA8 output still depends on the qualified blend path |
| Source alpha 0, no neighbouring coverage | Filtered and mixed coverage is zero; guarded conversion returns zero RGB | No division by zero or retained RGB in an empty output |
| Source alpha 0, nearby opaque source | Pixel aperture or diffusion may contribute bounded neighbouring coverage | This is intentional spread, not colour leaking through a zero-alpha result |
| Partial source alpha | Colour transforms operate on straight colour recovered from premultiplied source, then restore coverage | The half-green/blue and pure-hue fixtures establish actual representative pixels |
| Plane opacity 0, strength 1 | Optical RGBA becomes transparent black | Material processing may still execute; no zero-cost claim |
| Plane opacity 0, intermediate strength | Classic premultiplied coverage fades toward transparent absence | The interpolation weights colour by coverage; it does not mix straight colours independently |
| Plane opacity 1 | Optical coverage is retained before clarity and parent modulation | Defocus/diffusion may intentionally change source coverage |
| Parent opacity 0 | Final alpha is zero and the framebuffer receives no colour contribution | Classic may have nonzero shader RGB before blending, as in the historical program |
| Parent opacity 1 | Source coverage is applied once by the framebuffer blend | No additional parent-alpha multiplication occurs in processed RGB |

For example, a half-opacity green source with historical Classic straight
green 0.5, processed straight green 1, optical plane opacity 0.5 and strength
0.5 mixes to premultiplied green 0.25 with coverage 0.375. Its final straight
green is two thirds, so the framebuffer reconstructs green 0.25. Parent opacity
0.5 produces premultiplied green 0.125 and coverage 0.1875. This analytic case
checks the mixed-alpha relationship; it is not mislabeled as a captured pixel.

The guarded conversion uses a positive-alpha threshold. Any coverage below
that threshold is also below one RGBA8 output level. The review found no NaN,
division-by-zero, negative coverage or over-unity straight-colour path for the
validated source and setting ranges. Future HDR source/output changes require
their own precision review.

The frozen graphical fixture has actual-pixel oracles for zero, half and full
source coverage; parent opacity one and one half; haze zero and 0.3; full
processing and bypass; half-width wipe; radius 0/1/2/3/6 and quality caps; detail
coverage; diffusion; and clarity one. It does not contain a dedicated pixel
oracle for intermediate effect strength combined with partial optical plane
opacity, nor the full Cartesian product of allowed tint/brightness extremes.
Those cases are supported by the source range and convex-alpha analysis above,
not represented as exhaustively measured graphical combinations.

## Remaining mask and directionality limits

Presentation shadows and local clarity reuse the current published Play RG8
texture. They do not reconstruct depth, request native occupancy scans or
create a collision authority. Reprojection is evaluated at rear material-cell
centres. Fractional parallax therefore retains a bounded pixel-grid
approximation; it is not continuous subpixel light transport. A future mode
that visually interpolates Play material between snapshots may show a
temporary difference between that presentation and the current occupancy mask.
No such mismatch is asserted from source alone as an observed current-scene
failure. Actual moving Sand/Water, camera and actor sequences remain the
relevant visual evidence.

The dense cross avoids the old even/odd contrast-return defect, but retains
one-dimensional Nyquist stripes at half contrast for integer radius one and
greater. A two-axis checker can reach zero while those axial stripes remain.
That directional structure may preserve architectural rails; it also limits
photographic plausibility. The radius is bounded support rather than an
isotropic optical blur width. The [source cost census](optical-source-cost-a.md)
and [actual failed-campaign pixel readings](renderer-campaign-05-review-a.json)
preserve the distinction between a filter property and a qualified whole build.

## Performance evidence interpretation

| Measurement | Actual authority and scope | Permitted interpretation | Does not establish |
| --- | --- | --- | --- |
| Per-fragment sample bounds | Shader branches and configured integer filter support | Upper bound on rear-surface and Play-mask reads for one processed fragment | GPU duration, CPU duration, presented FPS or native responsiveness |
| Completed Rapier intervals | Existing completion hook timestamps every actual step; the reader requires a contiguous tick population | Physical-step rate and interval p50/p95/p99/max, including real stalls | Native worker's individual completion intervals or input-to-photon latency |
| Native tick delta / wall time | Authoritative published native tick counters before and after a window | Aggregate native progression rate | A reconstruction of hidden per-tick timing |
| Native publication intervals | Already published immutable snapshots observed by the main thread | Observed publication cadence and coalescing | One observation per native tick; observations may skip intermediate publications |
| Display callback intervals | Actual process-frame callbacks retained in order | Callback pacing and stalls within the observer configuration | Physical progression or displayed GPU FPS |
| Godot `TIME_PROCESS` | Engine process-duration monitor sampled in each callback | Main-thread process-duration context | An independent thread CPU counter or isolated shader time |
| Process CPU seconds | OS user+kernel counters for the launched process and sampled descendants | Total observed CPU consumption, including setup, compilation and observer work | Per-profile CPU cost unless independently aligned window samples support it |
| Process RSS / working set | Periodic simultaneous process-tree resident-memory observations | Observed residency and its sampled peak | GPU memory, unique pages across descendants, exact allocation ownership or a memory-leak proof |
| Material/resource identities | Bounded renderer counts plus actual scene/node ownership observations | Retention and lifecycle behaviour for the tested switching/replacement population | Unbounded session stability or driver-side allocation accounting |
| Live slider authored response | Exactly one original callback plus the subsequent authored-state read | Synchronous callback-to-observed-state duration, including the observer's bounded read | Pure callback CPU or human input latency |
| Next `frame_post_draw` | First completed-draw notification after that callback | Callback-to-next-completed-draw observation | Physical scanout, input-to-photon delay or independently sampled visible pixel change |

The matched profile cohort uses three repeats in forward/reverse/forward order,
90 callbacks per sample, fresh native geometry between samples, and six paused
warm-up callbacks. The registered threshold compares median native and Rapier
rates against 90% of Classic and physical p95 against the larger of 1.2 times
Classic p95 or Classic p95 plus 10 ms. P99, maxima and long-stall counts remain
separate evidence. A low or unstable population is inconclusive, not a pass.

The integrated coordinator explicitly permits 3,603 resource samples at 0.5 s
spacing for the 1,800 s bounded progression process. Other phases retain the
helper's default 1,203 samples and 600 s ceiling. Reading the helper constant
alone would miss that call-site contract; independent review confirmed the
override rather than changing an already bounded implementation.

The separate five-minute observer uses adjacent live windows with evolving
material and actor state and with real tonal-slider edits. It addresses
continuity, interaction response and bounded resource behaviour. Those windows
are not stock-profile cost comparisons. Its retained evidence arrays and
instrumentation contribute to process memory and CPU and are explicitly part
of that observer scope.

The 45-second scene-admission criterion is unchanged. Neither the static sample
table nor any hosted software-rendered result can establish physical Windows
11/NVIDIA acceptance. The predecessor's failures and all new misses remain
negative results even when the corresponding scene admits successfully.
