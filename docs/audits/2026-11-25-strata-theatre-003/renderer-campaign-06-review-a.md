# Independent final Linux rendering review — Specialist A

The actual final Linux renderer fixture passed **109 checks with zero
failures** at application `fd0830abcfadd9ae19162e5677943bb131223e59`, tree
`fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499`, in
[run 45721790366](https://github.com/techrote/cybersand/actions/runs/45721790366).
This review independently reads the original PNG pixels and process receipt.
It is a rendering-correctness result, not overall performance acceptance.

Exact source, runtime, process, capture, configuration and geometry identities
are retained in [the machine-readable review](renderer-campaign-06-review-a.json).
The original [Linux artifact 15075800269](https://github.com/techrote/cybersand/actions/runs/45721790366/artifacts/15075800269) is 180,041,492 bytes; its ZIP SHA-256 is
`d9ebf833c049af25280fc1af142e6eea59bb5de0f88a7e1a959d055ba4657011`.
The engine was the pinned Godot `4.7.stable.official.5b4e0cb0f`; its actual
renderer was OpenGL 4.5, Mesa 25.2.8, llvmpipe LLVM 20.1.2. This is hosted
software rendering, not a physical NVIDIA observation.

## Review checklist and observed result

| Requirement | Independent observation | Scope |
| --- | --- | --- |
| Correct actual application and engine | Campaign source/tree, engine hash and original process/log digests checked | Exact Linux campaign |
| Exact Classic comparison under haze and parent opacity | All 16,384 bytes of the right-hand 64×64 RGBA region match; zero changed channels and zero maximum delta | Actual saved Classic baseline versus actual wipe |
| Partial-alpha colour | Half-green is `(0,128,0,128)` processed and the historical `(0,64,0,128)` in Classic | Premultiplied source, final straight-alpha framebuffer boundary |
| Dense aperture frequency progression | Checker contrast is 204/255 at radius zero, zero at radii 1, 2, 3 and 6 | The two-axis one-cell checker witness |
| Thin bright structure | Every inspected white impulse/halo pixel has equal RGB and alpha through all five radius captures | No coloured or dark halo in this witness |
| Detail without silhouette loss | All 12,288 output alpha pixels match the reference; checker contrast is reduced to 51/255 | Three copies of the frequency fixture |
| Highlight diffusion | A bounded halo at `(38,16)` is `(4,4,4,4)`; the white centre remains `(255,255,255,255)` | One isolated white impulse |
| Sampling boundary | The opposite-edge probe remains `(0,0,0,0)` at maximum radius | No texture wrapping in this fixture |
| Actor-reveal lifecycle | Original run passes local reveal and retired-actor clearing assertions | Published conservative bound, not collision silhouette |
| Resource and Classic restoration | Original run passes bounded material reuse, bypass and retirement assertions | Rendering fixture; native Workbench receipts remain separate |

The exact frozen test saves **18 original PNGs**, not 19. The complete name/hash
inventory is in the JSON review. The test's 109 assertions include its saved
Classic haze/opacity baseline and all existing alpha/frequency controls.

## What the blend repair established

The preceding candidate actually failed exact Classic comparison under haze
0.3 and parent opacity 0.5. Premultiplied output was algebraically equivalent
but produced different RGBA8 rounding from the legacy straight-alpha blend.
The failure and original images remain retained; this successful run does not
retroactively qualify that candidate.

The final shader keeps source filtering and effect interpolation premultiplied,
uses the literal old HAZE expression on the Classic wipe side, and converts
processed colour once at the final straight-alpha blend boundary. The new
actual Classic baseline and actual wipe agree at the formerly failing probes:

| Probe | Actual Classic baseline RGBA8 | Actual wipe RGBA8 |
| --- | --- | --- |
| Bright checker `(142,14)` | 83,84,86,128 | 83,84,86,128 |
| Dark checker `(143,14)` | 11,13,15,128 | 11,13,15,128 |
| White impulse `(168,16)` | 92,94,95,128 | 92,94,95,128 |
| Half-blue `(172,44)` | 1,2,25,64 | 1,2,25,64 |

The lead's independent EGL archive is internally consistent: all five archived
file digests match, its three PNG copies equal the original failed-campaign
files, and the original campaign/process/log digests match. Its 16 uniform-source
blend cases remain an auxiliary arithmetic experiment on a different Mesa
build. The direct-straight branch is a control using the same expression as
its legacy branch; it was not itself execution of the final Godot shader.
The final real Godot captures above now provide the missing graphical witness.

Intermediate effect strength combined with arbitrary source/plane/parent
opacity has source-level coverage in
[the boundary review](optical-boundary-review-a.md). The actual fixture tests
specific partial-alpha and parent-opacity cases; it is not an exhaustive
Cartesian graphical sweep of all admitted values.

## Whole-scene check: dark basalt and false bridges in Abyss Foundry

At Specialist B's request, I separately inspected the final Classic, Gameplay
Clarity and Cinematic Deep Focus overviews of Abyss Foundry. They share the
recorded camera, actor pose, geometry identity and original native material
hashes. All four native plane hashes remain unchanged across the campaign.
The source and all three image/configuration hashes are in the JSON review.

The central rear gantry occupies approximately screen rectangle
`[622,630,343,37]`. The source places it in the Scripted plane: its upper
material-65 beam begins at native rectangle `[270,674,466,5]`. The physical
lower-left basalt shelf begins at Play rectangle `[90,762,332,28]`, with its
own brighter cap above. Those are different authored planes, despite their
similar horizontal architectural language.

Gameplay Clarity substantially subordinates the rear gantry and the tall rear
chamber/column frames. The source-bound sample below shows that this does not
require changing the physical basalt or physical orange pipe:

| Screen probe and interpretation | Classic RGB8 | Gameplay Clarity RGB8 | Cinematic Deep Focus RGB8 |
| --- | --- | --- | --- |
| Rear gantry `(630,632)` | 97,45,23 | 52,41,37 | 98,56,38 |
| Rear column cap `(670,420)` | 74,85,94 | 50,54,57 | 84,91,95 |
| Physical basalt `(500,700)` | 48,49,53 | 48,49,53 | 48,49,53 |
| Physical orange pipe `(1064,365)` | 216,124,72 | 216,124,72 | 216,124,72 |

This supports the visual judgement that Clarity gives the physical capped
shelves more prominence. It does not make the false gantry cease to resemble
a traversable bridge: its coherent horizontal silhouette still spans the
middle gap. Colour-independent shape and alignment ambiguity remains.

Cinematic Deep Focus retains the intricate rear texture but lifts the sampled
gantry and column pixels while the physical basalt stays unchanged. It serves
an atmospheric, detailed composition; it should not be described as equivalent
to Gameplay Clarity for immediate physical-route interpretation. The selected
actor is too small in this overview to establish practical body visibility.
Its readable pilot label is not a substitute for that judgement. This was an
identified-profile expert review of paused captures, not a blind user study or
movement acceptance.

## Remaining limits and performance disposition

The binomial cross's checker improvement is real, but its one-dimensional
Nyquist stripe response remains 50 percent at every positive integer radius.
The filter is anisotropic and is not an isotropic Gaussian or photographic
bokeh. The bounded shadow mask and conservative actor rectangles remain
presentation approximations. This review does not establish moving
mask/interpolated-surface alignment for every future publication treatment.

The final Linux matched profile campaign reports a repeatable physical-rate
regression: Architectural is approximately 80 percent of Classic, Cinematic
Deep Focus 82 percent, and Gameplay Clarity 75 percent, with narrow repeat
spreads. Those are material negative results against the registered 90 percent
target. They are separate from the successful rendering checks and cannot be
cancelled by attractive captures, zero additional native capture counters or a
nominal frame-rate number.

The lead therefore requested the separately pinned
[A1 zero-coverage experiment](optical-empty-coverage-experiment-a.md). Its
in-process shader override and external strict reader preserve the frozen
application. At this review checkpoint its actual equivalence/performance
campaign is pending; no benefit or adoption is claimed. The original negative
performance result remains part of the decision packet regardless of A1's
outcome.

Disposition: **final fd0830ab Linux rendering fixture qualified; real-scene
ambiguities and measured performance failures retained; overall engineering,
owner artistic and physical-device acceptance remain separate decisions.**
