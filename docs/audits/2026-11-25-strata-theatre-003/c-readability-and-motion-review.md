# Specialist C — final challenge readability and movement review

**Disposition: useful selective improvement, with important artistic and gameplay limits.** Gameplay Clarity and Noir give the strongest ownership cues in the deliberately difficult equal-material challenge. The other profiles preserve useful visual character, but several do not resolve the false-platform or apparent blocked-passage problem in this fixture. Close movement captures resolve actor bodies that were not readable in the whole-scene overview. This is an independent agent assessment, not a human player study or owner acceptance.

The application is immutable `fd0830abcfadd9ae19162e5677943bb131223e59`, tree `fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499`. Actual captures came from the Linux job in [run 45721790366](https://github.com/techrote/cybersand/actions/runs/45721790366), artifact `15075800269`, ZIP SHA256 `d9ebf833c049af25280fc1af142e6eea59bb5de0f88a7e1a959d055ba4657011`. The renderer was llvmpipe, LLVM 20.1.2. No physical NVIDIA result is inferred.

## Blind assessment and its limits

The [six-axis registration](c-blind-review-registration.json) preceded inspection. Specialist B made eleven byte-identical opaque copies of the actual matched challenge captures and withheld the profile key. All original hashes were checked. Every image was inspected individually at the same full-frame display scale, without cropping, recolouring or re-encoding. No profile name appeared in the common toolbar. Artistic appearance could still suggest a likely treatment.

The [initial score record](c-blind-review-initial.json) was frozen in commit `76df950a` before key disclosure. Its SHA256 is `8af0549e54137f78e387446fd4f424ce2ef2660b5da45e5a6c9ae64f4127043f`. The packet SHA256 is `f53d456db95884adfd443150f8a842023a3ece7557622fd3d984fc6caee78f0e`. Specialist B independently checked the saved blob before revealing the key. No initial score or note was changed after disclosure. The [revealed record](c-blind-review-revealed.json) binds every sample to its original image, configuration and profile.

Each axis uses an integer from 1 to 5, with higher values better. They are not summed. The assessor knew the authoritative native fixture geometry, so these results describe informed visual judgement rather than an unprimed player's comprehension.

| Profile | Opaque sample | Physical platform | Real passage | Actor body | Detail retained | Depth hierarchy | Visual balance |
|---|---:|---:|---:|---:|---:|---:|---:|
| Classic |11|1|1|2|5|1|2|
| Architectural |04|1|1|2|5|1|2|
| Gameplay Clarity |05|5|4|2|4|4|4|
| Cinematic Deep Focus |08|1|1|2|5|2|2|
| Optical Lens |06|2|1|2|4|2|3|
| Diorama |10|3|2|2|3|3|3|
| Atmospheric Industrial |09|2|2|2|5|2|3|
| Noir |03|4|3|2|5|4|4|
| Cold Orbital |01|1|1|2|5|1|2|
| Alien Bioluminescence |02|2|2|2|5|2|3|
| Sunlit Megastructure |07|1|1|2|5|2|3|

Gameplay Clarity makes the actual platform and its support dominate the aligned rear continuation. Its subdued rear panel also reveals distant uprights through it, which helps the central opening read as a physical frame in front of a separate surface. The cost is reduced prominence of fine rear texture. Noir retains more fine line contrast while still making the physical beam stronger; its rear panel remains more plausibly obstructive than Clarity's.

Architectural and Cinematic Deep Focus preserve fine grids and material detail, but gentle colour and tonal changes are inadequate for this deliberately adversarial equal-material arrangement. Earlier positive Underworks observations remain valid within that authored composition; they are not a universal readability result. Cold Orbital and Sunlit similarly provide atmosphere without a dependable ownership cue here. Alien Bioluminescence and Atmospheric Industrial provide a modest colour distinction, but the apparent traversable extension survives.

Optical Lens makes the distant uprights visibly softer while leaving the confusing nearer rear platform too similar to the actual platform. Diorama provides a stronger sharp-versus-soft cue, at a clearer fine-detail cost. Both show why focus alone is insufficient: a soft beam can still look like a traversable continuation, and a blurred filled panel can still look like a blocking wall.

All overview actor scores are 2. The annotation and ring locate the Midge, but its body is unresolved at the 1024×768-cell overview. These scores were retained after the key was revealed. They must not be presented as a successful actor-visibility result.

## Native-bound pixel observations

[The measurement register](c-readability-measurements-linux.json) contains raw nine-pixel RGBA patches, original image and configuration hashes, camera mapping, native material witnesses, and the exact procedure identity. The install report SHA256 is `70f66d128ef314967bba8289419b7876712a8a25b794d29c2a4a05715c728059`; its geometry group is `2968262dd2f6ff37e6ca9ce53b23bef6630e478209a37d0d8e42e56b33bc1a50`.

The two physical probes are the actual Play material 58 platform at native `(160,214)` and ground at `(420,694)`. The false extension at `(350,214)` is native Play 0 / rear 58. Every profile's two opaque Play patches exactly matches Classic in all RGBA8 channels: maximum difference 0. This is a precise local preservation witness, not a whole-image proof for all material types. Water, Sand, and transparent physical content were excluded.

The following values use encoded RGB coefficients `(0.2126,0.7152,0.0722)`. They are supporting image observations, not linear-light photometry or a perceptual acceptance threshold. The physical platform patch has constant mean 0.4912.

| Profile | Rear false-platform mean | Physical minus rear | Rear local edge contrast | Rear grid adjacent-pixel contrast |
|---|---:|---:|---:|---:|
| Classic |0.3921|0.0991|0.3660|0.04821|
| Architectural |0.4039|0.0873|0.3779|0.04249|
| Gameplay Clarity |0.2450|0.2462|0.2189|0.02233|
| Cinematic Deep Focus |0.3963|0.0949|0.3703|0.04176|
| Optical Lens |0.4031|0.0882|0.3770|0.03561|
| Diorama |0.4164|0.0748|0.3891|0.03179|
| Atmospheric Industrial |0.3886|0.1026|0.3625|0.03866|
| Noir |0.2762|0.2151|0.2501|0.03066|
| Cold Orbital |0.3748|0.1164|0.3488|0.04000|
| Alien Bioluminescence |0.3607|0.1305|0.3346|0.03653|
| Sunlit Megastructure |0.4073|0.0839|0.3812|0.04264|

The numerical observations support the strongest qualitative result: Clarity and Noir produce much greater separation at the false extension. They also retain the negative result that several nominally attenuated profiles brighten this dark rear patch slightly relative to Classic. A contrast-compression parameter does not imply that every dark pixel becomes darker.

The rear grid measurement is the mean horizontal difference of neighbouring encoded-luminance pixels in the declared native rectangle `[70,90,610,88]`. It combines tone, colour, opacity and blur. It must not be called a pure measure of spatial-frequency retention or architectural fidelity. Native material 58 can also have different local procedural colour across positions; the Classic physical/rear values were not assumed identical merely because their material IDs match.

The portable analysis procedure is `tools/ci/analyze_strata3_readability.py`. It consumes unchanged original PNGs, verifies source/report/image/configuration custody, uses the campaign's bounded standard-library PNG decoder, and records its own hash. Its numerical rows exactly reproduce the earlier local analysis procedure. Reproduction requires the verified campaign artifact and the immutable application checkout:

```sh
python3 tools/ci/analyze_strata3_readability.py \
  /path/to/linux/optics-readability-challenge/install \
  /path/to/measurements.json \
  --application-root /path/to/fd0830ab-checkout \
  --expected-report-sha256 70f66d128ef314967bba8289419b7876712a8a25b794d29c2a4a05715c728059
```

## Three-actor movement, camera and zoom

The [independent movement review](c-motion-review-linux.json) records inspection of all forty original1600×900 PNGs: ten each for Classic, Gameplay Clarity, Cinematic Deep Focus and Diorama. Diorama uses High quality; the others use Balanced. This is the explicit three-Midge challenge variant, with ordinary actors and source-authored presentation parallax. The material recipe is unchanged, while Play physics evolves normally.

At 240-cell width, all three mint rectangular actor bodies are visible directly in the early frames, including their orientation and dark interior mark. At 480-cell width they remain recognizable but small; annotations still help tracking. The closer views therefore resolve the overview limitation without implying that an effect can make a subpixel actor readable at arbitrary zoom.

Gameplay Clarity reduces the competing grid most. Its bounded local dimming remains useful where a rear upright passes near an actor. Classic and Deep Focus retain stronger material texture and busier equal-value patterns. Diorama's defocus becomes conspicuous at close zoom: major frames and grids survive, but material texture and beam edges soften. It is a useful optional optical treatment, with a significant detail tradeoff.

The pilot progresses from approximately `(410.06,599.36)` to `(434.32,476.99)` across each captured sequence through ordinary action submission. Every sequence records actual native/Rapier ticks 9 through 90, zero native capture and decorative upload deltas, unchanged static decorative material hashes, no injected pose, and no additional native World. The Clarity renderer reports three actor reveal rectangles in every captured frame. All forty Play picking-inverse witnesses are exactly 0.0 error.

Camera zoom changes at frames 4 and 8 are deliberate framing changes. The two nonpiloted actors leave the final close view because the camera follows the ascending pilot; this is not a visibility-effect failure. Rear structures move at their presentation parallax and can occupy different screen positions under different profile multipliers. Play edges remain crisp in the visible basin, ground and wall-stub regions. Water and Sand visibly evolve, with no claim of opaque RGB invariance for those materials.

No obvious alpha fringe, stale captured frame, missing actor body, or destructive colour clipping was seen. These are sparse readback-instrumented frames, not real-time observation. Their arbitrary gallery playback cadence cannot establish smoothness, temporal comfort, between-frame flicker, input latency or physical frame rate. The separately registered performance cohort and sustained-session annex govern those engineering observations.

## Practical implications

Use Gameplay Clarity as the principal ownership-assistance candidate and retain the accessible temporary physical-plane inspection. Consider Noir when stronger silhouette hierarchy suits the scene. Preserve Architectural and Deep Focus for detailed artistic inspection, with explicit warnings in guidance that their subtle settings cannot disambiguate every deliberately aligned rear structure.

Future authoring should combine tonal hierarchy with geometric composition: avoid placing a rear beam as a seamless continuation of a critical physical platform, and preserve an identifiable edge or gap at real passage openings. Profile controls provide useful tools, but they do not remove the author's responsibility for deliberate misleading alignments. Further human review should include unprimed passage/platform choices and actual owner hardware movement before claiming that gameplay clarity is solved.
