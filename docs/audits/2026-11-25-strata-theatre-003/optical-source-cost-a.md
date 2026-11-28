# Specialist A — bounded optical sampling cost review

## Status and identity

This is a source-derived upper-bound census, **not a rendering benchmark or a
physical-progression result**. It explains why the matched progression campaign
must remain a delivery gate even though the implementation introduces no native
capture, native simulation turn, render target, duplicate plane texture or new
World. A fragment shader can consume meaningful rendering capacity while all of
those ownership and allocation properties remain correct.

The analysed source is `f69797a594ffae9d49a9ca1247987e260ce87dbf`, using Godot
`4.7.stable.official.5b4e0cb0f` to instantiate the actual profile catalogue and
renderer configuration for all 33 profile/quality combinations. Each analysed
file's committed bytes were independently checked against its SHA-256 in
[the machine-readable census](optical-source-cost-a.json). No graphical renderer
or hardware timing was used in this analysis. An unrelated uncommitted
qualification-coordinator change was present in the integration checkout; none
of the three analysed files differed from the named commit.

The later framebuffer correction `bdd7a6cf` changes arithmetic and blend mode
at the final output boundary, not the sampling support or number of texture
reads. The census remains an explanation of those unchanged sample bounds;
its original file hashes are retained and are not relabeled as the corrected
shader. Timing comparisons must use the newly qualified application source.

## What is counted

Counts below cover potential texture reads in one rear plane's final-composite
fragment. They include the frozen rear RGBA surface and optional existing Play
material mask. They exclude the existing native palette publication viewport,
ordinary Play rendering, procedural atmospheric drawing and actor overlay
draws. The table does not multiply by visible area, output resolution or the
number of overdrawn planes.

The profile uses its authored initial focal position, all effects retain their
profile values, the comparison wipe is fully processed, and the already
published Play mask is assumed available. An out-of-bounds sample returns zero
before fetching; a compiler may eliminate or combine work. These are therefore
source upper bounds rather than measured texture fetch counts.

The dense surface filter reads its shared centre once and four neighbours for
each positive integer support distance. The support is `ceil(radius)`, capped
at one, three or six cells for Low, Balanced or High. Detail suppression or
illumination requests the one-cell kernel even when defocus is disabled. Soft
architectural shadows add five Play-mask samples; Low uses one. Local clarity
adds five Play-mask samples. Up to eight actor rectangles plus the sampled
player rectangle add bounded geometric arithmetic, not texture reads.

## Profile census

Each cell lists **rear architecture / atmospheric material plane / distant
background** reads per fragment. Authored procedural atmospheric motifs are
separate CanvasItems and are not included in the atmospheric material plane's
count.

| Profile | Low | Balanced | High |
| --- | --- | --- | --- |
| Classic | 1 / 1 / 1 | 1 / 1 / 1 | 1 / 1 / 1 |
| Architectural | 6 / 6 / 6 | 10 / 10 / 10 | 10 / 10 / 10 |
| Gameplay Clarity | 11 / 11 / 11 | 15 / 15 / 15 | 15 / 15 / 15 |
| Cinematic Deep Focus | 6 / 6 / 6 | 10 / 10 / 10 | 10 / 10 / 10 |
| Optical Lens | 6 / 6 / 6 | 10 / 10 / 18 | 10 / 10 / 22 |
| Diorama | 6 / 6 / 6 | 14 / 10 / 18 | 14 / 10 / 30 |
| Atmospheric Industrial | 6 / 6 / 6 | 10 / 10 / 14 | 10 / 10 / 14 |
| Noir | 11 / 11 / 11 | 15 / 15 / 15 | 15 / 15 / 15 |
| Cold Orbital | 6 / 6 / 6 | 10 / 10 / 10 | 10 / 10 / 10 |
| Alien Bioluminescence | 6 / 6 / 6 | 10 / 10 / 10 | 10 / 10 / 10 |
| Sunlit Megastructure | 6 / 6 / 6 | 10 / 10 / 10 | 10 / 10 / 10 |

The apparent equality of several profiles is expected: different tonal,
chromatic and scattering settings share one shader and the same sample
support. Equal read counts do not establish equal rendering time. The shader
also evaluates tonal curves, an exponential atmospheric term, optional shadow
and silhouette logic, and coverage-correct diffusion. Branch behaviour,
texture cache locality, driver compilation and the visible composition matter.

## Practical implications and disposition

Classic, disabled, full bypass and zero-strength restore the original material
object. Their rendering path does not inherit the optical fragment work above.
The controller's focus callback also exits before querying Play publication or
actor bounds when optics are inactive. These are source contracts with
separate runtime checks; the zero native counters exposed in statistics are
not themselves execution measurements.

The six profiles with defocus disabled still request local detail or highlight
sampling. Describing these as "crisp" means that the Play material edges remain
untouched and the rear planes avoid lens coverage spread; rear highlights can
still receive bounded optical diffusion. It does not mean one texture fetch
or zero filtering work. Gameplay Clarity and Noir add local silhouette reads,
so visual clarity cannot be assumed to be the fastest processed mode.

Diorama High is the registered expensive optional case: its far plane uses up
to 25 surface reads and five shadow-mask reads. Dense sampling was selected to
remove the older sparse kernel's even/odd fine-detail contrast return during
focus changes. This correctness improvement increases maximum sample count;
no performance improvement is claimed for that replacement.

The cross also has a specific retained directional limitation. Its integer
transfer is the average of the horizontal and vertical binomial responses.
A one-cell checker varying in both axes reaches zero contrast at radius one,
but one-dimensional alternating vertical or horizontal stripes retain half
their contrast at every integer radius of one or greater. The perpendicular
branch preserves those stripes. This is monotone, yet it is not isotropic
Gaussian defocus. It can preserve useful architectural rails, while also
leaving some repetitive far-plane detail stronger than a photographic lens
would. The radius describes bounded support, not a circular aperture diameter
or a calibrated optical blur width. The checker witness establishes removal
of the prior contrast-return defect, not general photographic plausibility.

An early exit for empty centre alpha could save arithmetic in modes that never
spread coverage, but it cannot be applied indiscriminately to pixel defocus or
highlight diffusion because neighbouring opaque texels may legitimately
contribute. Such an optimisation remains deferred until an exact-source
graphical and physical-progression comparison can establish its value. No
unmeasured optimisation was added during the final application freeze.

The admission target remains 45 seconds. This analysis neither changes that
target nor reinterprets the predecessor's five recorded failures. Software
rendered hosted Linux/Windows observations must remain separate from the
owner's physical Windows 11/NVIDIA acceptance.
