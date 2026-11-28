---
title: Composing optical depth in Strata
status: Current
document-kind: guide
scope: Optional Strata Optics Lab artistic workflow, profile intent and physical readability guidance; graphical and owner acceptance remain source-bound
canonical-for: [strata-optical-composition]
last-reviewed: 2026-11-28
related-documents: [strata-workbench-evaluation.md, ../systems/strata-workbench.md, ../systems/strata-environments.md, ../systems/strata-authoring.md]
---

# Composing optical depth in Strata

Strata's optical controls can make physical structures more prominent while retaining intricate surroundings. Their success depends on the authored geometry, camera scale and purpose of the view. Several gentle depth cues are not a universal readability solution: final matched captures retain false bridges and floors in otherwise attractive detailed profiles. Begin with a native layout whose physical route is understandable. A lens cannot reliably repair a rear staircase that looks and aligns like a physical staircase at every useful camera scale.

This guide combines implemented controls with observations from application `fd0830abcfadd9ae19162e5677943bb131223e59`. The [final artistic recommendations](../audits/2026-11-25-strata-theatre-003/b-final-artistic-recommendations.md) and [capture ledger](../audits/2026-11-25-strata-theatre-003/b-final-corpus-review.json) bind those observations to original Linux images and exact configuration/geometry identities. They are agent assessments. The [independent performance review](../audits/2026-11-25-strata-theatre-003/c-performance-review-linux.md) retains the original hosted progression regression and failed 90% retention target without alteration.

The owner subsequently accepted the optical results on Windows 11 with an NVIDIA TITAN RTX on 28 November 2026 and waived that specific retention target for optional optical profiles. Classic remains the default. The [combined delivery guide](ramcache-strata-integration.md) records integration qualification separately. The preferred **Diorama** profile with **Rear architecture → Optical depth = 1.3** is reproducible through the panel and named presets; it is artistic feedback, not a new global default or proof of every scene's physical readability.

## Start with physical authority

Open an ordinary native scene, then **Strata Theatre → Layers**. Inspect **Play** in Solo, then **uncheck Solo** and select **Stack · all visible planes** before comparing optical treatments. Stack does not clear Solo automatically. The Play World owns collision, material simulation and ordinary actors. Rear architecture, atmospheric decoration and background are three separately authored decorative native Worlds. Their apparent roofs, ladders and walls have no Play collision merely because they look substantial.

The optics system keeps the existing plane order and Play camera mapping. Decorative parallax can move a plane's presented image without moving its native cells. An optical depth is an artistic coordinate; it is not a native cell coordinate, a physical distance, a new World, an editing target or a command to reorder layers. A negative optical depth does not put a decorative layer in front of the player. Native geometry remains exactly where the original author placed it.

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

Compare **Classic** with **Gameplay Clarity** first when physical ownership is the question. Use **Architectural**, which disables defocus, or **Cinematic Deep Focus** when detailed construction is the question. The independent equal-material challenge found that both detailed profiles preserved grids while leaving false-platform and passage ambiguity. Their names do not make them clarity settings.

Adjust **Tonal separation**, then the selected plane's contrast and brightness. Contrast compression can lift dark pixels while reducing bright-detail differences; it does not promise that every background pixel becomes darker. Some black-level lift can recover distant architecture that was already nearly invisible. Too much lift creates a pale flat panel. Too little separation allows rear framework to masquerade as physical support. Compare a dark rear beam with the actual physical surface beside it, rather than judging the overall palette alone.

Check the smallest useful play zoom, not only an overview. Fine facade patterns that look excellent when magnified may compete with the player when reduced to a few screen pixels.

## Author physical affordances before optical style

A player reads the shape and continuity of a support before discovering which native World owns it. Avoid a rear beam that appears to continue seamlessly from a real platform across an open Play gap. The final Abyss comparison retained a coherent apparent bridge even after Gameplay Clarity strongly attenuated it. If a new composition uses that arrangement, move the rear structure to a clearly different height, give it an evident termination or break, or frame it as an interior detail whose boundary does not meet the traversable edge. These are authoring choices for a new scene; an optical preset must not change native geometry to achieve them.

Use negative space to communicate a real opening. Keep enough of the corridor or gap visually quiet for its clearance to be understood at ordinary play zoom. Rear doorway frames, horizontal bands, opaque-looking mist and light pools can make an open passage appear closed. Compare Play Solo with the full stack at that exact position. If the passage reads only in Solo, reducing rear opacity may help, but the arrangement still needs scrutiny. A decorative rectangle centred inside the opening can overpower subtle depth cues.

Ladders, stairs, railings and regularly spaced floor bars carry strong gameplay meanings. A dim decorative ladder may still invite climbing; the Arcology inspection showed that bright rear ladders remained particularly convincing in rich neon profiles. Avoid placing them as the obvious continuation of a physical route. Use them within visibly bounded rear rooms, at a different structural rhythm or away from the route's immediate decision points. Colour alone is insufficient when foreground and background use the same material family or when colour discrimination is limited.

A distant horizon can also become a false floor. A long straight bright line near the player's feet is likely to read as support even when it belongs to Background. Preserve the scale of far infrastructure through large masses and clear silhouette changes; avoid matching the thickness, elevation and continuous lip of a nearby real deck. Tall repeated environments require particular care: the Vertical Transfer Spine's rear cross-trusses remain plausible floors at repeated heights even after attenuation.

For human or model-assisted authors, make each proposed route claim testable. Identify the actual Play cells or existing native probes for its floor and opening, inspect that place in Play Solo, then compare the full stack in Classic and Clarity at the same camera. Record any rear structure that still suggests an unsupported continuation. Do not infer collision, climbability or edit authority from a screenshot, optical depth, profile name or a successful contrast measurement.

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

Classic restores the unchanged presentation when temporary **Show physical Play** is off. Bypass takes precedence over assistance and immediately restores the reference while retaining the edited profile. **Bypass / before** temporarily shows Classic while retaining your authored values. The runtime **Processed share** wipe compares the architectural optical treatment on one shared camera transform, with Classic parallax used for the split comparison. During a partial wipe, separately authored steam, shafts and other atmosphere motifs keep their Classic strength across the whole image. Compare full Classic and full processed views to judge their opacity and clarity fade. The offline Gallery also has a wipe, but it compares two original PNGs rather than rerendering the world. Full profiles can have different decorative parallax multipliers, so a shared camera does not guarantee that every rear beam aligns across that image wipe. Compare the complete views as well; do not mistake the expected presentation shift for moved Play geometry.

## Focus should explain depth

**Fixed Play focus** is the stable gameplay starting point. It does not follow the mouse, selected actor or changing materials. **Manual optical distance** lets you move the focal region through the authored depth coordinates. **Selected focal plane** follows an explicit plane choice; it does not change the paint target. **Follow authoring plane** follows the existing edit selection, while the temporary **Inspection focus** override restores the authored focus when released.

**Sharp focus width** is the optical-depth interval that remains in focus. Widening it preserves more planes without requiring their depths to become equal. **Defocus amount** is an aperture-like artistic strength; the actual radius also depends on distance outside the focal region and per-plane response. The renderer caps kernel support at one source cell in Low, three in Balanced and six in High quality. These are artistic approximations, not calibrated physical lenses.

The pixel radius describes bounded sampling support, not Gaussian sigma or a photographic circle of confusion. The dense cross-shaped aperture can preserve single-axis rails more strongly than two-axis checker detail. Compare horizontal beams, vertical ribs, diagonal spokes and repeated grids separately when judging the lens, especially during camera movement.

The three methods make different tradeoffs:

| Method | What changes | What to inspect |
| --- | --- | --- |
| Pixel kernel | Bounded nearest-centred, alpha-weighted neighbouring samples soften a decorative plane. | Thin braces, small light sources, transparent openings and reduced-zoom silhouettes. |
| Diffusion | Retains central architecture while spreading selected local highlights. | Bright machinery and apparent fog around openings; avoid treating every bright wall as a light. |
| Detail | Reduces fine interior contrast while retaining the source coverage. | Whether texture becomes quieter without losing the construction's major edges. |

A strong Diorama setting can be useful for a still or temporary inspection and still be a poor choice for movement. The final Lunar Overview retained identifiable rear instruments while their softened grids and circular rim produced useful miniature-like depth. The same profile removed more fine mineral construction in Xeno and became much softer in the close challenge camera. Underworks retained its full wheel rim and spokes, but the softened lower rear bridge still looked like a possible support. Keep these scene- and scale-dependent results as explicit limits. Do not make Play less readable merely to imitate a photographic effect.

## Use atmosphere locally

**Atmospheric density** in Optics is an attenuation of architectural material colour toward a chosen scattering colour. The colour need not be blue. Warm amber or muted olive may suit machinery; violet may separate cave depth; a neutral grey can give strong non-colour separation. The useful amount depends on optical depth and each plane's atmosphere contribution.

Authored atmosphere regions remain separate. The **Atmosphere** tab controls haze, steam, rain, dust, warning signals, machinery lights, architectural light shafts and local light pools. Optics does not silently replace those regions or their authored seeds. Their motion is presentation time, not native gas, rain mass, physical illumination or a second simulation.

In the full processed view, a plane's optical opacity and Play-separation strength also fade its atmosphere motifs. This keeps strong steam or shafts subordinate during clarity inspection. Their colours, lens softness and scattering remain controlled separately: changing optical tint, focus or density treats architecture, while the Atmosphere tab still determines each motif's own appearance. Temporary bypass always restores their ordinary authored strength; Classic does so when temporary clarity assistance is off. The fade changes presentation only and does not rewrite the authored atmosphere settings.

Place a light shaft near an authored opening, then inspect it against all four planes. The approximation uses eight clipped native-grid bands per source; it does not discover openings or calculate occlusion. Local light pools use four restrained diffusion bands behind Play. Both new kinds are static by default. Optional speed adds gentle breathing, rather than moving their source through the environment. Regions remain within the shared 12-region and 384-motif limits.

Strong overlapping bands can become visible rectangular panels. Reduce strength, count or region size before adding another layer of haze. Preserve large areas of negative space so atmosphere has somewhere to be perceived.

The new Sunward, Xeno and Lunar overviews showed no conspicuous stepped light-panel artifact, but the individual shafts and pools were too understated to establish convincing volumetric light. Broad optical tint and bright native accents also contribute to those images; do not credit them to the procedural lights. Judge a new local-light arrangement with an on/off comparison of that region, then inspect it close enough to reveal the eight-band shaft or four-band pool construction. The [source-bound motif guide](../audits/2026-11-25-strata-theatre-003/b-light-motif-authoring-and-feedback.md) lists exact regions and known limits. A successful atmosphere leaves the physical opening understandable after the glow is removed as well as while it is enabled.

## Shadows, local contrast and actor visibility

Architectural shadows sample already published Play material data. They provide a bounded offset impression on decorative surfaces, not physical light transport. Offset, softness and optical distance determine the presentation. The material mask is an explicitly selected native Solid family; it is not a universal transparency or lighting model. Native collision and material kinds remain unchanged.

Use short offsets for close interior separation. Longer offsets can suggest strong directional illumination in an open megastructure, but they may also look detached from the source edge. Always compare after panning and zooming. A shadow that appears physically convincing in one static camera pose may be too conspicuous elsewhere.

**Play separation** and **Show physical Play** suppress competing rear content without reducing physical material opacity. They combine broad decorative attenuation with local treatment near available Play silhouettes and actor presentation bounds, plus a bounded fade of authored atmospheric motifs. They do not create a new foreground World or guarantee visibility for every actor in a crowd. Existing actor labels, camera scale and composition remain important.

Separate actor-body visibility from actor-label visibility. In the final eleven-profile challenge Overview, the body was unresolved and the independent reviewer capped every actor score at 2 despite visible markers. At the closer 240 × 135 and 480 × 270 native view sizes, the actual mint actor rectangles were visible in the sampled movement frames across all four profiles. Clarity reduced competing rear detail most; it did not make Overview-scale bodies larger. Choose an ordinary camera scale that reveals the body and its movement before treating a label as evidence that the optical system solved visibility. Keep the background quieter around likely actor routes without filling the scene with permanent outlines.

Probe the value hierarchy by temporarily choosing Noir or strongly reducing rear saturation, then ask whether real platforms, real gaps and decorative stairs are still distinguishable. Play keeps its original palette, so this is not a colour-vision simulation or a complete grayscale test. An attractive hue contrast alone is not a sufficient gameplay cue; inspect edge strength, continuity and negative space as well.

## Work through the native comparison corpus

| Scene | Source-bound starting choice | Deliberate inspection task |
| --- | --- | --- |
| Orbital Fabrication Terminal | Clarity for route hierarchy; Deep Focus for docking construction. | Compare bright physical decks with suspended rear frames and the long middle truss. Preserve dark distant detail without turning that truss into an apparent continuation. |
| Rain over the Arcology | Clarity for play; Classic/Deep Focus for the richer neon view. | Check roof lips against the orange rear bridge, decorative ladders and facade borders. Reduced neon strength helps, but a ladder remains an affordance. |
| Underworks / Reactor Service | Clarity for ownership; Deep Focus for machinery; optional Diorama. | Inspect the lower orange rear truss and the wheel. Final Diorama retains the rim/spokes but smooths useful fine grids and does not remove the false bridge. |
| Abyss Foundry | Clarity with explicit Play inspection available. | Challenge the central decorative gantry against true basalt shelves. Its coherent silhouette remains a false-route risk after attenuation; gentle tone changes are insufficient. |
| Vertical Transfer Spine | Clarity for the alternating physical route. | Separate repeated rear trusses from real shelves; use a closer view for the actor. Deep Focus retains construction but also the repeated false-floor cue. |
| Sunward Freight Megastructure | Clarity for physical terraces; Deep Focus for detail; Sunlit/Industrial for warm palette study. | Preserve the open central shaft. Sunlit and Industrial differ modestly at Overview, and subtle new shafts alone do not establish a volumetric-light result. |
| Xeno Resonance Grotto | Clarity for shelves; Alien or Deep Focus for organic depth. | Preserve the clear void, large mineral rings and horizontal physical lips. Strong Diorama removes more fine mineral construction here. |
| Lunar Terminator Observatory | Clarity for play; Cold Orbital/Deep Focus for instruments; optional Diorama for miniature-like stills. | Keep decks separate from solar lattices and preserve negative sky. Recheck the attractive Overview lens at ordinary play zoom before adopting it. |
| Optics Readability Challenge | Independent opaque-order review favours Clarity, then Noir. | Use native probes for false platforms, stairs and passages. Architectural/Deep Focus retain grids but scored poorly on ownership. Actor Overview scores remain marker limited. |

The native corpus is predominantly dark. Sunward/Sunlit is a warm industrial palette study, not demonstrated bright-daylight readability. A future native fixture should combine a bright sky or pale distant masses with dark physical silhouettes and both light and dark actors at ordinary play scale. Synthetic white/highlight tests establish numerical handling, not that perceptual outcome. B's [six-image final Windows confirmation](../audits/2026-11-25-strata-theatre-003/b-delivery-recovery-2026-11-26.md) preserves the named-profile observations and this gap.

The original five native layouts remain unchanged by these optical comparisons. New scene recipes have source-bound geometry and geometric clearance probes; those authoring checks do not prove complete actor traversal. Always pilot the actual ordinary Workbench before accepting a scene as playable.

The [independent challenge and motion review](../audits/2026-11-25-strata-theatre-003/c-readability-and-motion-review.md) preserves the first opaque scores, subsequent profile mapping, native-bound measurements and limitations. The [independent renderer review](../audits/2026-11-25-strata-theatre-003/renderer-campaign-06-review-a.md) records the exact alpha/Classic checks and residual Abyss bridge ambiguity. Keep architectural enjoyment, physical-route understanding and performance as separate conclusions. The present profile-cost regression prevents treating this table as a default-activation recommendation.

## Save the artistic result, keep inspection temporary

Scroll to **Named custom presets** in the Optics tab, enter a name and use **Save / duplicate as named preset** to retain a preferred complete optical configuration. Built-in profiles remain available. Per-scene authored settings and the named-preset store are different records: saving a preset does not replace ordinary scene Save. Enter a scene name in the ordinary Workbench's map-name field beside **Save start [Ctrl+S]**, then save. After a complete exit and relaunch, re-enter the same scene name before clicking **Load start**; this is a named-load action, not a file-selection dialog. The [owner walkthrough](strata-optics-evaluation.md#save-and-reopen-your-work) gives the full sequence.

Temporary bypass, comparison wipe, clarity assistance, inspection focus and quality preference are outside the authored optical configuration. A transient look at a rear plane should not replace the scene's intended gameplay presentation. Native material Undo/Redo remains owned by the ordinary authoring systems; optical edits are not fictitious cell mutations.

For owner feedback, record the scene, profile, any changed values, camera scale and package/source identity. Describe the exact platform, passage or actor that was misleading. Distinguish visual preference, physical responsiveness, startup delay and a reproducible rendering error. A matched still, a short movement sequence and the same location in Classic are more useful than a general statement that the image feels blurry.
