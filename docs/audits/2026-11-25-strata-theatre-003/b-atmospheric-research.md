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

Twenty-six synthetic document-builder unit tests passed. They challenge changed source, copied receipts, modified image or non-image bytes, malformed PNG CRC/end, camera/actor mismatches, lost geometry invariance, missing fresh-process/supplemental views, configuration serialization changes, symlinks/path escape, wrong runtime identity and HTML injection. Synthetic one-pixel fixtures are labelled unit data and are not rendered-application evidence. Actual gallery build and browser inspection remain pending real campaign output.

## Independent source critique before graphical selection

The shader's initial tonal compression pivots around 0.5, so compressing already dark rear materials can brighten them even when the profile's brightness multiplier is below one. This may restore useful distant detail, but its effect on physical prominence must be judged from matched captures. Gameplay Clarity's description therefore says it reduces decorative emphasis rather than promising that every background pixel darkens.

Independent source review also identified missing basalt, obsidian and aluminium coverage in the first architectural shadow mask. Specialist A traced the mask to the authoritative native material-kind table and is correcting the explicit Solid family with negative liquid/gas/powder controls. The optical mask remains a declared artistic approximation, not collision or physical transparency authority.
