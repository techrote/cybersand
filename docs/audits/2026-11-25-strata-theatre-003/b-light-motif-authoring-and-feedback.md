# Light motifs, strong haze and useful owner feedback

**Implementation-derived authoring guidance · Specialist B · Draft/HOLD.** The ranges and placement examples below explain the implemented controls. They are proposed starting points, not a claim that the three new showcases have already passed graphical or human perceptual review. Their actual findings belong in the [final corpus review](b-final-corpus-review.json), with the source and capture identities preserved.

The goal is a detailed world with readable physical space. A shaft can connect a ceiling opening to machinery, a pool can locate a distant instrument, and haze can make a large silhouette recede. Those effects become counterproductive when they resemble platforms, obscure the actor or remove the very construction that makes the environment interesting.

## Choose the control that changes the intended thing

The **Optics** tab treats the material appearance of decorative architecture. Focus, tonal separation, tint and optical scattering operate on those architectural surfaces. The **Atmosphere** tab authors separate local motifs: steam, haze bands, rain, dust, signals, shafts and pools. A larger Optics atmospheric-density value does not create more steam puffs or discover a new light opening.

In a full processed view, optical plane opacity and Play separation also apply a bounded fade to that participating plane's motifs. Their own region, colour, seed, count and animation remain unchanged. Classic and temporary bypass restore ordinary authored motif strength. During an intermediate runtime wipe the motifs intentionally retain Classic strength across the entire image; compare full Classic and full processed views when evaluating their fade. This avoids pretending the procedural motif drawing has received two separate optical treatments. A plane excluded from optical processing retains its ordinary motif strength; temporary clarity assistance deliberately includes the decorative planes.

Both control domains remain presentation only. They do not add native gas, water, light transport, collision, actors or physical Worlds. The [atmosphere schema](../../../godot/scripts/depth/strata_atmosphere_profiles.gd) admits only the existing three decorative plane IDs, at most twelve regions, at most ninety-six motifs per region and at most 384 motifs overall. Those limits are budgets, not density recommendations.

## Place one shaft before arranging a field of light

Start with a real authored opening that already makes spatial sense. Inspect Play alone to establish which part of that opening is physical. Then choose the decorative plane on which the atmosphere belongs and add **Architectural light shafts** in a region extending from the opening into the visible space beneath it. A shaft does not search the native scene for apertures or wall occlusion.

The preset uses three sources, strength 0.55, warm RGBA `[1.0,0.82,0.51,0.45]`, direction `[0.18,1.0]` and speed zero. For a single opening, reduce Count to one first. This makes placement easier to understand than adjusting several overlapping visual ideas at once. Resize and move the region before increasing strength.

The renderer draws eight horizontal bands for each shaft. The bands widen and fade down its length. They are clipped to the authored rectangle and remain aligned with the native cell grid. This construction explains several useful control relationships:

| Control | What it changes for a shaft | Practical implication |
| --- | --- | --- |
| Region position | The top or bottom boundary and horizontal placement | Align it with an architectural opening or lamp position; an unexplained source looks like a translucent pillar. |
| Region height | Shaft length and the height of each of its eight bands | Very tall regions make individual steps more visible. Shorten the region if band boundaries dominate the scene. |
| Region width and Count | Source spacing and the bounded source width | Count adds regularly spaced sources. It does not simply brighten one existing beam. |
| Direction X | Horizontal lean with depth along the region | Begin with a small magnitude. A strong lean may cross unrelated rooms or appear to imply a physical diagonal surface. |
| Direction Y sign | Downward versus upward widening | Its sign chooses direction; its magnitude does not independently set beam length. Region height sets that length. |
| Strength and colour alpha | The contribution of each translucent band | Change one first. Increasing both together can hide the boundary between lighting and geometry. |
| Speed | Optional breathing at a fixed source | Zero is static. Positive values breathe gently; they do not move the shaft through the room. |
| Seed | Optional breathing phase | Static shaft positions are regularly spaced; changing their seed is not a substitute for placing their region. |

Do not try to hide conspicuous banding by adding many more shafts. That can create a curtain of similar vertical forms. First shorten the region, lower strength, reduce Count, or align the band changes with existing architectural divisions. A visible stepped construction may be acceptable for a deliberate pixel-light style, but it should look intentional at ordinary play zoom.

The proposed Sunward scene uses four shafts in the native region `[330,155,900,680]`, while Lunar uses only two subtle background shafts in `[320,100,940,530]`. These are concrete authored comparisons, not universal templates. Their final rendered appearance still needs review.

## Use pools to locate machinery without washing a whole plane

**Local light pools** draw four nested rectangular bands around fixed source positions. The default is three sources, strength 0.65, cyan RGBA `[0.35,0.82,0.95,0.45]` and speed zero. Their contribution is deliberately restrained. The preset is not a physical lamp and does not discover emissive native materials.

Place a pool region close to a piece of rear machinery, a display cluster or a luminous growth. Keep enough unlit space around it that the local change is visible. A full-width region with many sources tends to become a general tonal wash; use the optical atmosphere controls if that is actually the intended effect.

Pool centres are evenly spaced across the region, with their vertical placement derived from the authored seed. Count and region width affect their width; the shape is also bounded by the region height and the renderer's size cap. Changing the seed can alter their vertical distribution. Direction is not a pool-position control. Move or resize the region to relocate the composition.

Look at the outer rectangle before looking at the bright centre. If the rectangle is what attracts attention, reduce strength or alpha and place it against a more suitable architectural mass. Increasing apparent softness by stacking many regions is expensive in visual complexity even when it remains inside the implementation budget. The result can make machinery look like a tinted signboard rather than a distant object.

For Xeno, the proposed six green-cyan pools occupy `[118,212,800,580]`; the intent is a few local luminous areas around a large clear void. For Lunar, three quieter instrument pools occupy `[510,360,640,155]`. The intended compositions differ substantially, so copying the same global haze and palette settings between them should be an experiment, not an assumption.

## Diagnose strong haze by what the player can still read

Begin with atmosphere disabled, identify the physical floor and opening, then add one region at a time. Watch the actual useful play zoom as well as Overview. A broad volume that appears gentle when the entire scene is visible may consume most of the actor's local background when zoomed in.

| What appears in the image | A useful first adjustment | What to verify afterwards |
| --- | --- | --- |
| Large pale rectangles replace distant material texture | Lower optical atmospheric density or scattering brightness; inspect the relevant plane contribution | Are the distant silhouette and internal construction both still visible? |
| Steam or a shaft resembles a wall across an opening | Move or shorten the authored region, then reduce its strength | Does the actual passage remain visually continuous during movement? |
| Rear horizontal bands look like usable floors | Reduce their emphasis and inspect their placement relative to Play | Can the player still tell which edge supports them without relying on a colour difference alone? |
| A bright pool makes the actor hard to locate | Reduce that pool locally, use clarity assistance and check the actor at a useful zoom | Does the actor body become readable, rather than only its selection label? |
| The scene becomes uniformly dim or empty | Restore some rear brightness, contrast or motif strength instead of increasing foreground effects | Is enough architectural information retained to perceive a place rather than a silhouette chart? |
| Focus changes make fine patterns seem to return and disappear | Compare the actual source-bound lens revision and quality tier; retain a reproducible capture sequence | Is this expected detail loss or an alias pattern that requires engineering review? |

These are diagnostic hypotheses. A single attractive still cannot establish that one adjustment improves play. Neither a colour histogram nor a whole-image contrast number proves route understanding. Use native authority, ordinary interaction and independent judgement together.

The dense pixel aperture's displayed radius describes bounded sampling support. It is not Gaussian sigma or a measured photographic circle of confusion. Its cross-shaped sampling can preserve single-axis rails more strongly than two-axis checker detail. When judging a lens setting, inspect horizontal beams, vertical ribs, diagonal wheel spokes and repeated grids separately. Do not assume that a profile which suppresses one fine pattern will suppress all orientations equally. Earlier sparse-kernel lens observations remain tied to their own implementation and cannot qualify this revised filter.

Use an opaque physical material edge when checking that the Play presentation is unchanged. Transparent materials can legitimately show a different rear composition through their existing transparency, and neighbouring colours can also alter perceived colour. That is different from changing the native material data or applying the decorative optical shader to Play.

## Evaluate first-glance interpretation before teaching the answer

For an informal owner check, choose an unfamiliar view and pause before using Solo or clarity assistance. Identify one apparent platform, one apparent passage and one apparent ladder or stair. Record what you think is physical and how certain you are. Then use Play Solo and ordinary interaction to establish the actual interpretation.

The same view can then be compared in Classic and several optical profiles. Keep camera, zoom and paused actor state consistent for still comparisons. If you already know the geometry, say so: learned route knowledge makes later interpretation easier. Profile names can also influence preference, so retain a short description of the visible result rather than recording only a favourite name.

In the authored readability challenge, `[160,214]` is a physical platform, while the apparent continuation at `[350,214]` is decoration. The passage at `[560,360]` looks blocked by rear material but is empty in Play. The step at `[798,260]` and ladder at `[890,180]` are also decorative. Once those facts are known, use a different local view for an honest first-glance check. These probes establish native material truth; they are not a validated human comprehension test.

## Separate the artistic decisions

Record at least these three preferences independently:

- **Ordinary play:** which view lets you locate physical support, open space and actor motion quickly?
- **Architectural inspection:** which view preserves the construction you want to study or edit?
- **Atmospheric composition:** which view gives the place the desired scale, mood and optical character?

One profile need not win all three. A detailed Classic view may be valuable for authoring while a clarity profile is easier to inhabit. A pronounced lens may make a convincing small diorama while obscuring texture during movement. Preserve that disagreement rather than forcing one winner.

Use five short ratings only if they help compare several views: physical-route distinction, actor localization, retained rear detail, perceived depth, and absence of distracting artifacts. Add a concrete location or feature to every low score. A numerical average alone hides useful tradeoffs: losing wheel spokes to gain foreground separation is a different result from preserving both.

## Give feedback that can be acted on

An actionable report identifies the exact package/source, scene, profile, quality, edited values, camera scale, desktop scaling, GPU/driver and whether the application was paused. Name the object or opening that was confusing. Add a matched Classic/processed pair and, where useful, an ordinary movement recording. The offline gallery's arbitrary review cadence is not an actual runtime recording and cannot establish playfeel or FPS.

A useful short report can follow this form:

> Scene and view: …  Profile and changes: …  Quality: …
>
> I interpreted this edge/opening as …; Play Solo or interaction showed …
>
> The treatment made this physical feature easier/harder to locate because …
>
> The rear detail I would preserve is …; the effect I would reduce is …
>
> During ordinary movement I observed …  With Classic at the same location I observed …
>
> Package/source and hardware: …  Attached original captures or recording: …

Separate an artistic dislike from a reproducible correctness fault and from a physical-progress slowdown. A visible seam, changing alias pattern, wrong edit position, stale effect or altered physical-material appearance deserves an exact reproduction. A preferred warm or cool palette is an artistic decision. A pause in Water/Sand evolution or actor response needs actual physical observations, not only a displayed FPS number.

The registered profile-cost gate covers the 1024 × 768 challenge; the original-002 versus candidate-Classic comparison covers 1024 × 1024 Underworks. Neither establishes every scene's cost on a physical NVIDIA GPU. Preserve the unchanged 45-second admission target and its recorded predecessor failures. Owner artistic and physical Windows 11/NVIDIA acceptance remain separate from the hosted engineering evidence.

## Source and evidence boundaries

Implementation details are defined by [the atmosphere drawing code](../../../godot/scripts/depth/strata_atmosphere.gd), [its versioned schema and presets](../../../godot/scripts/depth/strata_atmosphere_profiles.gd), the three [native showcase recipes](../../../godot/data/strata3), and the [physical readability fixture](../../../godot/scripts/depth/strata_optics_fixtures.gd). Optical ownership and persistence are specified in [the system contract](../../systems/strata-optics.md). The ordinary owner sequence remains in [the evaluation walkthrough](../../operations/strata-optics-evaluation.md).

This guidance does not promote a profile, qualify the pending light-motif captures, or hide the dense-kernel/wipe-alpha investigation. Actual source-bound findings and rejected experiments remain separate entries in [the experiment register](b-optical-experiments.json).
