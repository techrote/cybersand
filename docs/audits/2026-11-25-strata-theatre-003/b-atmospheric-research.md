# Atmospheric and artistic workstream — initial implementation checkpoint

**Draft/HOLD.** Specialist B, 25 November 2026. Parent application `934cc0c0eef70dad528155e9a92eebe25e2757eb`; archival ancestor `410ac8e5e613b1454928699dbc9a68cd035f0894`. This checkpoint implements editable artistic proposals, not a claim that their integrated appearance or physical performance has passed.

## Baseline observations

The five actual Windows reference composites were inspected from the verified predecessor evaluator. Their exact capture hashes and individual assessments are in [the machine-readable intake](b-artistic-intake.json). The physical decks already have a strong bright lip. Ambiguity is concentrated in rear horizontal trusses, the Underworks lower orange beam, the Abyss central gantry, and repeated cross-shaft forms in Vertical Spine. These structures share the Play plane's edge language despite belonging to different native owners.

Distant architecture is already dim. Uniform opacity reduction would hide valuable details without teaching the player which surviving edge is physical. The initial balanced hypotheses therefore combine modest contrast compression, subtle scattering, selective high-frequency suppression and restrained shadow separation. Gameplay Clarity adds non-colour suppression near the physical silhouette; Classic is the unchanged disabled control.

## Editable catalogue

`strata_optical_profiles.gd` provides eleven complete versioned configurations through the root-owned strict optics schema. Classic, Architectural, Gameplay Clarity, Cinematic Deep Focus, Optical Lens, Diorama, Atmospheric Industrial, Noir, Cold Orbital, Alien Bioluminescence and Sunlit Megastructure vary tonal hierarchy, chromatic relationships, scattering colour, depth distribution, detail suppression, light response, shadow geometry and lens method. Several deliberately disable defocus. The catalogue is data for one renderer, not eleven independent rendering systems.

The Play plane never participates in optical processing. Its configuration fields are the unchanged default focus anchor. The catalogue returns deep independent copies, so adjusting a preset cannot mutate future defaults. Each description states intended use; graphical comparison is still required before selecting a recommended balanced treatment.

## Two bounded atmospheric experiments

The existing presentation-only atmosphere vocabulary gains **architectural light shafts** and **local light pools**. They reuse the same three existing decorative CanvasItems, native-coordinate transform, region clipping, authored seeds and shared 12-region/384-motif cap. They create no World, native capture, upload, physical material or light transport.

Light shafts use eight clipped pixel bands per source. Direction selects tilt and upward/downward spread. Light pools use four concentric clipped rectangular diffusion bands per source. Both are static by default, with zero recurring presentation callback. Optional speed enables a gentle ten-percent smooth breathing envelope, independent of native time and subject to the existing 0.1-second no-catch-up clock. There is no full-screen blur or bloom pass.

The twelve effect fields remain unchanged. The strict supported-kind list is extended within the existing version-1 atmosphere document. Older documents and all original six presets retain their exact values. Older software will safely refuse the new kinds; it does not silently substitute another effect. These additions are optical drawing approximations, not physically accurate volumetric scattering. At excessive strength, overlapping bands can look like translucent blocks; this is an explicit graphical-review risk.

## Executed checks and limits

The exact pinned official Godot `4.7.stable.official.5b4e0cb0f`, source-compatible materialized native and Rapier libraries executed 72 atmosphere schema/lifecycle checks and 97 optical-catalogue value checks without failures. Tests cover static no-callback behavior, optional breathing, hidden-plane stop, complete strict schema, Play protection, JSON precision and deep-copy independence. An earlier convenience-engine probe at 4.7.2 with LFS pointers produced extension-load errors and is not native qualification; the pinned-runtime rerun supersedes that local setup probe.

Headless value/lifecycle checks do not prove rendered alpha correctness, composition quality, native isolation in the live Workbench, Windows commands or owner GPU performance. Integrated graphical captures and independent comparisons remain outstanding at this checkpoint.


## Three new native compositions

The original five Strata 002 source JSON files are unchanged. The separate `strata_optical_showcase_scenes.gd` registry admits three additional original native recipes from `tools/strata3_build_showcases.py`, using the existing strict recipe and Setup/document construction contract. The shared validator now accepts explicit registry/generator/version parameters while preserving the original five-scene defaults. A new catalogue cannot impersonate the original identities or inherit their qualification.

| Composition | Native extent | Architectural and optical intent |
| --- | --- | --- |
| Sunward Freight Megastructure | 1536 × 1024 | Physical terraces around a clear central shaft; rear crane cages, distant logistics blocks, warm clipped light shafts and localized cool machine pools. |
| Xeno Resonance Grotto | 1024 × 1024 | Exact horizontal physical cave shelves; rooted rear mineral rings and industrial relics; large central negative space, sparse local bioluminescence and violet mist. |
| Lunar Terminator Observatory | 1536 × 768 | Sparse physical observation decks; rear instruments and solar lattices, distant stepped ridges and a planar planetary rim; low haze and large sky gaps. |

The resulting native rectangle counts are 260/1957/28/459, 300/5177/608/1412 and 122/720/18/1083 in Play/rear/effects/background order. The 55/72/8 presentation motifs remain within the inherited shared cap. Every geometric route probe passes its radius-34 swept-square authoring check. None of those probes claims actual actor traversal. Profiles stay Classic on admission until the owner explicitly selects one in the Lab.

The pinned engine passed 41 new catalogue/native-candidate value checks and all 71 retained showcase checks; the deterministic generator reproduces all three JSON files byte-for-byte. Actual ordinary native installation, scene replacement, rendered appearance and owner usability are still separate campaign requirements. Source inspection does not promote these compositions to qualified graphical showcases.

## Offline comparison gallery and custody

`tools/build_strata3_gallery.py --campaign <folder> --output <package>/Gallery.html` consumes the new coordinator's `strata3-workbench-campaign-v1` evidence. It verifies a passing clean source, exact official Godot identity, native/Rapier byte identities, every ledger-listed original evidence file, all nine install/fresh-process pairs, and the source files defining the gallery, profiles, harness and native recipes. It refuses changed logs as well as changed pictures.

Each scene must contain eleven original profile PNGs with the same recorded camera, paused actor state, native four-plane material hashes and framebuffer dimensions. Each configuration is bound to its exact Godot canonical JSON string and digest. The original native hashes must remain unchanged through the comparison and fresh-process reopening; authored optical configuration must reopen exactly. Eight supplemental captures identify Classic return, runtime wipe, temporary assistance, four focal planes and the actual Lab. Their scopes remain explicit because they are not automatically members of the matched profile cohort.

The gallery provides an offline Classic/processed wipe, profile and scene selection, original PNG links, native/camera/actor witnesses, editable-preset values, supplemental focus/UI images and original report links. It does not edit or duplicate PNG bytes and makes no one-cell-per-CSS-pixel or physical GPU claim. The gallery's own input manifest is separate from the package manifest that covers the generated HTML bytes.

Forty-five synthetic document-builder unit tests passed. They challenge changed source, copied receipts, modified image or non-image bytes, malformed PNG CRC/end, camera/actor mismatches, lost geometry invariance, missing fresh-process/supplemental views, configuration serialization changes, symlinks/path escape, wrong runtime identity and HTML injection. The gallery now also retains actual install/reopen admission observations against the unchanged 45-second target and links source-bound physical progression reports, keeping their registration, repeat identity and observer scope. Missing progression or optical cost observations remain explicitly unrecorded, never zero. A functionally passing campaign cannot conceal a scene-admission miss or weaken that target. Synthetic one-pixel fixtures are labelled unit data and are not rendered-application evidence. Actual full gallery build and browser inspection remain pending the final campaign output.

The gallery's motion inspector consumes forty original challenge frames: ten each for Classic, Gameplay Clarity, Cinematic Deep Focus and Diorama. It verifies actual PNG hashes and dimensions, configuration serialization, per-frame camera and actor state, and strictly advancing native ticks, completed Rapier ticks and capture timestamps. It deliberately does not require invariant Play material hashes while native simulation evolves. The owner can step frames or play them at a labelled arbitrary three-frame-per-second review cadence. Those readback-instrumented sequences do not establish actual rendering FPS or performance; their original report remains directly linked. Scene, profile and supplemental-view changes stop playback. These controls use the original PNGs and produce no GIF, video, resampling or new rendering path.

## Independent source critique before graphical selection

The shader's initial tonal compression pivots around 0.5, so compressing already dark rear materials can brighten them even when the profile's brightness multiplier is below one. This may restore useful distant detail, but its effect on physical prominence must be judged from matched captures. Gameplay Clarity's description therefore says it reduces decorative emphasis rather than promising that every background pixel darkens.

Independent source review also identified missing basalt, obsidian and aluminium coverage in the first architectural shadow mask. Specialist A traced the mask to the authoritative native material-kind table and is correcting the explicit Solid family with negative liquid/gas/powder controls. The optical mask remains a declared artistic approximation, not collision or physical transparency authority.

## First independent actual shader witness

The original six Windows shader fixture captures from [run 45711742479](https://github.com/techrote/cybersand/actions/runs/45711742479), source `12b6beedf5db0caba326266b577b6c9c4f7e597d`, were visually inspected. Their encoded pixels were independently read alongside the corresponding Linux originals; every PNG matched its campaign ledger and every Windows/Linux pair was byte-identical. The [structured review](b-shader-witness-review.json) retains all capture hashes, measured pixels and the narrow disposition.

The processed half-opacity green retains premultiplied colour/coverage, the pixel aperture spreads a bounded pure-red fringe without sampled texture-edge wrap, and the detail treatment retains silhouette coverage. The flat-bar detail capture is exactly identical to the neutral processed capture: it cannot demonstrate frequency-selective detail reduction. The diffusion capture adds restrained coverage as well as colour, which is an explicit stylised treatment. Specialist A is extending the technical witness with high-frequency content and a bright impulse.

These 192 × 64 fixtures support alpha and sampling correctness on hosted ANGLE/Microsoft Basic Render Driver and llvmpipe. They contain no architectural routes or actors. They establish no artistic profile ranking, gameplay understanding, native simulation isolation, moving-camera quality or physical Windows/NVIDIA acceptance. Actual integrated scene critique remains open.

## Matched Underworks composition review

The first integrated scene review used eleven actual Linux Underworks captures from source `a57aaeeabfb5bde47276a6e2981ea80823759730`. The lead randomized filenames and withheld profile identities. B's [initial five-axis scores](b-underworks-blind-review.json) were committed in `203e566e` before opening the key. The later [reveal and custody review](b-underworks-reveal-review.json) leaves those scores unchanged, records the mapping and verifies both 64-file Linux/Windows evidence ledgers, seven relevant source inputs against frozen Git, the actual captured configuration hashes and native/reopen receipts. This is an AI critique by the catalogue author, who can infer some styles; it is not a blinded human perceptual study.

| Observed purpose | Strongest candidates in this scene | Remaining tradeoff |
| --- | --- | --- |
| Balanced architecture and depth | Cold Orbital; Cinematic Deep Focus | Their differences are subtle at overview; neither has yet established an advantage in ordinary motion. |
| Physical structure priority | Gameplay Clarity; Noir | The Play shelves dominate, while some rear trim and environmental richness are subdued. |
| Distinctive atmospheric identity | Alien Bioluminescence | Violet machinery/rock mass and cyan accents are attractive, but large lifted background shapes become more prominent. |
| Deliberate simulated lens | Diorama; Optical Lens | Wheel shape and spokes survive, while material texture softens. Retain as optional artistic choices. |
| Maximum original detail | Classic | Sharp orange rear rails and trusses remain strong false-platform cues. |

All eleven images keep the Play shelves visibly crisp. The selected Midge at this overview is located largely through its existing label and ring; these pictures do not establish an optical actor-visibility improvement. The lower rear bridge and top truss remain possible sources of confusion in every treatment. Atmospheric Industrial and Sunlit Megastructure need a second environment to assess their distinct benefits. No numerical profile tuning or automatic default activation follows from one paused scene.

The actual Windows Lab image is 817 × 607 pixels and shows readable labels, a clear native edit-target boundary, a visible vertical scrollbar and disabled focal controls for Fixed Play mode. Its top panel has no horizontal truncation. This image does not qualify every scrolled advanced control or keyboard interaction. The first-screen Classic and temporary Bypass operations have explanatory tooltips, independently confirmed by C.

The ordinary profile PNGs are 1600 × 900; recorded `window.size` is separately 1600 × 1000. The harness retains both rather than pretending the framebuffer matches the requested window extent. Classic return is exact within each platform's 564,001-pixel world crop. Cross-platform whole-scene pixels are not exact: most differences are one encoded channel level, with sparse larger differences on thin raster/material edges also present in Classic. The source-bound review retains those measurements without attributing them to new optics or claiming physical GPU equivalence. Actual scene admission was 19.925/17.443 seconds for Linux install/reopen and 44.472/7.149 seconds for hosted Windows. These single-scene results do not replace the predecessor's five recorded 45-second misses or establish a matched physical-performance improvement.

## Procedural atmosphere composition boundary

A's integration review identified that the optical shader treats the existing architectural material TextureRects, while their existing procedural Atmosphere children draw separately. Tone, focus, scattering and colour treatment therefore remain architectural controls; the Atmosphere tab owns motif colours, regions, seeds and animation. Applying optical opacity only to the parent shader would leave strong steam or shafts visible when the architecture faded.

The lead selected a bounded correction through the existing atmosphere node's `self_modulate.a`, with no new shader, viewport or simulation owner. Full processed presentation uses `lerp(1, opacity * (1 - 0.65 * clarity), strength)`; Classic and bypass use factor one. During an intermediate runtime wipe, motifs retain Classic strength throughout so the application does not falsely imply two different procedural treatments within one draw. Full-view switching remains available to compare this fade. Native geometry and authored motif settings are unchanged. The lead owns implementation and actual modulation readback checks; final graphical motif judgement remains tied to the new showcase campaign, not the earlier Underworks stills.
