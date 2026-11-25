---
title: Composing optical depth in Strata
status: Current
document-kind: guide
scope: Draft Strata Optics Lab artistic workflow, profile intent and physical readability guidance; graphical and owner acceptance remain source-bound
canonical-for: [strata-optical-composition]
last-reviewed: 2026-11-25
related-documents: [strata-workbench-evaluation.md, ../systems/strata-workbench.md, ../systems/strata-environments.md, ../systems/strata-authoring.md]
---

# Composing optical depth in Strata — Draft/HOLD

Strata's optical controls help the player distinguish the architecture they inhabit from the architecture surrounding them. Begin with a native layout whose physical route is understandable, then use several modest depth cues together. A lens cannot repair a rear staircase that is indistinguishable from a physical staircase at every useful camera scale.

This guide describes the implemented candidate's controls and artistic hypotheses. Source-bound graphical results, retained failures and owner acceptance belong to the Strata 003 decision packet. Profile names are suggestions for exploration, not a claim that a visual treatment has passed human perceptual testing.

## Start with physical authority

Open an ordinary native scene, then **Strata Theatre → Layers**. Inspect **Play** in Solo before selecting an optical treatment. The Play World owns collision, material simulation and ordinary actors. Rear architecture, atmospheric decoration and background are three separately authored decorative native Worlds. Their apparent roofs, ladders and walls have no Play collision merely because they look substantial.

The optics system keeps the existing ordering and camera. An optical depth is an artistic coordinate; it is not a native cell coordinate, a physical distance, a new World, an editing target or a command to reorder layers. A negative optical depth does not put a decorative layer in front of the player. Native geometry remains exactly where the original author placed it.

The Play material surface remains outside the new optical shader. A profile can change the visual context around a physical edge, but it does not blur or recolour the physical material itself. This is especially useful when comparing Water, Sand and detailed machinery against intricate rear construction.

## Build a hierarchy before adding a lens

A useful starting hierarchy is:

| Plane | Structural role | Useful optical role |
| --- | --- | --- |
| Play | Physical floors, walls, openings and actor context | Keep the existing crisp native palette and readable silhouettes. |
| Rear architecture | Nearby non-physical rooms, trusses, machinery and facades | Retain architectural detail while reducing competition from fine contrast. |
| Atmosphere / effects | Sparse native accents plus separately authored visual motifs | Provide local connections between layers without filling every gap. |
| Background | Large distant structures, landscape or environmental context | Preserve silhouette, scale and empty space; subordinate small detail. |

The built-in profiles generally place rear architecture near optical depth 0.36, effects near 0.20 and background near 0.95, with Play at zero. These are editable artistic values. A cramped interior may need less separation; an orbital horizon may need more. The effect plane's role remains flexible: sparse near steam and distant rain do not require identical treatments.

Start with **Architectural**, which disables defocus. Adjust **Tonal separation**, then the selected plane's contrast and brightness. Contrast compression can lift dark pixels while reducing bright-detail differences; it does not promise that every background pixel becomes darker. Some black-level lift can recover distant architecture that was already nearly invisible. Too much lift creates a pale flat panel. Too little separation allows rear framework to masquerade as physical support.

Check the smallest useful play zoom, not only an overview. Fine facade patterns that look excellent when magnified may compete with the player when reduced to a few screen pixels.

## Choose an initial profile by its purpose

All eleven profiles use one modular renderer and remain editable. They are complete parameter sets, not separate rendering systems.

| Profile | Intended starting use | First thing to challenge |
| --- | --- | --- |
| Classic | Exact Strata 002 compatibility and reference | Identify the original ambiguity before trying to correct it. |
| Architectural | Construction inspection and detailed industrial rooms | Are rear edges still too similar to physical edges? |
| Gameplay Clarity | Physical platforms, passages and actors take priority | Does suppression remove too much useful architecture? |
| Cinematic Deep Focus | Rich, detailed layered composition with no defocus | Do warm/cool relationships remain useful without colour? |
| Optical Lens | Manual focal-distance and aperture-like studies | Do small defocused structures still read as deliberate architecture? |
| Diorama | Deliberately shallow, miniature-like presentation | Does the strongest lens effect become distracting during movement? |
| Atmospheric Industrial | Warm mineral haze and local machine light | Are openings and near details becoming uniformly foggy? |
| Noir | Value hierarchy and restrained near-monochrome distance | Can the player and physical dark materials still be located? |
| Cold Orbital | Clear decks, cool graphite distance and quiet horizons | Is the cool treatment erasing distinctions between native materials? |
| Alien Bioluminescence | Organic silhouettes and sparse local luminous accents | Does colourful illumination compete with Play geometry? |
| Sunlit Megastructure | Broad warm scattering and large architectural silhouettes | Is distant contrast reduced enough without turning the whole image beige? |

Classic restores the unchanged presentation. **Bypass / before** temporarily shows Classic while retaining your authored values. The runtime **Processed share** wipe compares the optical treatment on one shared camera transform, with Classic parallax used for the split comparison. The offline Gallery also has a wipe, but it compares two original PNGs rather than rerendering the world.

## Focus should explain depth

**Fixed Play focus** is the stable gameplay starting point. It does not follow the mouse, selected actor or changing materials. **Manual optical distance** lets you move the focal region through the authored depth coordinates. **Selected focal plane** follows an explicit plane choice; it does not change the paint target. **Follow authoring plane** follows the existing edit selection, while the temporary **Inspection focus** override restores the authored focus when released.

**Sharp focus width** is the optical-depth interval that remains in focus. Widening it preserves more planes without requiring their depths to become equal. **Defocus amount** is an aperture-like artistic strength; the actual radius also depends on distance outside the focal region and per-plane response. The renderer caps its kernel at six source cells, or one in Low quality. These are artistic approximations, not calibrated physical lenses.

The three methods make different tradeoffs:

| Method | What changes | What to inspect |
| --- | --- | --- |
| Pixel kernel | Bounded nearest-centred, alpha-weighted neighbouring samples soften a decorative plane. | Thin braces, small light sources, transparent openings and reduced-zoom silhouettes. |
| Diffusion | Retains central architecture while spreading selected local highlights. | Bright machinery and apparent fog around openings; avoid treating every bright wall as a light. |
| Detail | Reduces fine interior contrast while retaining the source coverage. | Whether texture becomes quieter without losing the construction's major edges. |

A strong Diorama setting can be useful for a still or temporary inspection and still be a poor choice for movement. Keep that result as an explicit artistic limitation. Do not make Play less readable merely to imitate a photographic effect.

## Use atmosphere locally

**Atmospheric density** in Optics is an attenuation of plane colour toward a chosen scattering colour. The colour need not be blue. Warm amber or muted olive may suit machinery; violet may separate cave depth; a neutral grey can give strong non-colour separation. The useful amount depends on optical depth and each plane's atmosphere contribution.

Authored atmosphere regions remain separate. The **Atmosphere** tab controls haze, steam, rain, dust, warning signals, machinery lights, architectural light shafts and local light pools. Optics does not silently replace those regions or their authored seeds. Their motion is presentation time, not native gas, rain mass, physical illumination or a second simulation.

Place a light shaft near an authored opening, then inspect it against all four planes. The approximation uses eight clipped native-grid bands per source; it does not discover openings or calculate occlusion. Local light pools use four restrained diffusion bands behind Play. Both new kinds are static by default. Optional speed adds gentle breathing, rather than moving their source through the environment. Regions remain within the shared 12-region and 384-motif limits.

Strong overlapping bands can become visible rectangular panels. Reduce strength, count or region size before adding another layer of haze. Preserve large areas of negative space so atmosphere has somewhere to be perceived.

## Shadows, local contrast and actor visibility

Architectural shadows sample already published Play material data. They provide a bounded offset impression on decorative surfaces, not physical light transport. Offset, softness and optical distance determine the presentation. The material mask is an explicitly selected native Solid family; it is not a universal transparency or lighting model. Native collision and material kinds remain unchanged.

Use short offsets for close interior separation. Longer offsets can suggest strong directional illumination in an open megastructure, but they may also look detached from the source edge. Always compare after panning and zooming. A shadow that appears physically convincing in one static camera pose may be too conspicuous elsewhere.

**Play separation** and **Show physical Play** suppress competing rear content without reducing physical material opacity. They combine broad decorative attenuation with local treatment near available Play silhouette and selected-player presentation information. They do not create a new foreground World or guarantee visibility for every actor in a crowd. Existing actor labels, camera scale and composition remain important.

Use a colour-independent check: temporarily choose Noir or strongly reduce rear saturation, then ask whether real platforms, real gaps and decorative stairs are still distinguishable. An attractive hue contrast alone is not a sufficient gameplay cue.

## Work through the native comparison corpus

| Scene | Deliberate inspection task |
| --- | --- |
| Orbital Fabrication Terminal | Compare bright physical decks with suspended rear frames and long trusses. Preserve dark distant docking detail. |
| Rain over the Arcology | Check physical roof lips against rear facade borders, signs and skybridges at reduced zoom. |
| Underworks / Reactor Service | Inspect the lower orange rear truss, central pipe and large reactor frames. None becomes a physical platform through illumination. |
| Abyss Foundry | Challenge the central orange decorative gantry against the true basalt shelves. |
| Vertical Transfer Spine | Separate repeated rear trusses crossing the clear Play shaft; use a closer view before judging the small actor. |
| Sunward Freight Megastructure | Compare physical terraces, rear crane cages and warm shafts in a broad open hall. |
| Xeno Resonance Grotto | Preserve horizontal physical shelves around a clear void while mineral ribs and local bioluminescence convey depth. |
| Lunar Terminator Observatory | Keep physical observation decks distinct from rear solar lattices, distant ridges and the planetary rim. |
| Physical readability challenge | Use the recorded native material probes to identify deliberately misleading platforms, stairs and passages. |

The original five native layouts remain unchanged by these optical comparisons. New scene recipes have source-bound geometry and geometric clearance probes; those authoring checks do not prove complete actor traversal. Always pilot the actual ordinary Workbench before accepting a scene as playable.

## Save the artistic result, keep inspection temporary

Use **Save / duplicate as named preset** to retain a preferred complete optical configuration. Built-in profiles remain available. Per-scene authored settings and the named-preset store are different records: saving a preset does not replace ordinary scene Save. Use **Save start**, exit completely and **Load start** to assess fresh-process restoration of the authored environment and optics.

Temporary bypass, comparison wipe, inspection focus and quality preference are outside the authored optical configuration. A transient look at a rear plane should not replace the scene's intended gameplay presentation. Native material Undo/Redo remains owned by the ordinary authoring systems; optical edits are not fictitious cell mutations.

For owner feedback, record the scene, profile, any changed values, camera scale and package/source identity. Describe the exact platform, passage or actor that was misleading. Distinguish visual preference, physical responsiveness, startup delay and a reproducible rendering error. A matched still, a short movement sequence and the same location in Classic are more useful than a general statement that the image feels blurry.
