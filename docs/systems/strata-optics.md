---
title: Strata optical presentation and persistence
status: Current
document-kind: contract
scope: Draft Strata Theatre 003 decorative-plane shader, lens, controls, ownership, presets and compatibility; no physical owner acceptance
canonical-for: [strata-optical-rendering, strata-optical-configuration, strata-optical-persistence]
last-reviewed: 2026-11-25
related-documents: [strata-workbench.md, strata-authoring.md, strata-environments.md, ../operations/strata-optical-composition.md, ../operations/strata-optics-evaluation.md]
---

# Strata optical presentation — Draft/HOLD

**STRATA-THEATRE-003**, [Draft PR #785](https://github.com/techrote/cybersand/pull/785), extends the source-preserving Strata 002 branch. It adds an integrated **Strata Optics Lab**, eleven editable profiles and presentation-only depth cues. It does not enable Strata or optics by default. The previous application `934cc0c0eef70dad528155e9a92eebe25e2757eb`, archive `410ac8e5e613b1454928699dbc9a68cd035f0894` and evaluator remain separate immutable evidence.

This is a stylised optical compositor, not a physically calibrated lens or light transport simulation. Exact graphical, native and performance results are bound to the [dated research record](../audits/2026-11-25-strata-theatre-003/README.md). Source describes implemented behaviour; compiling a shader does not prove visual clarity or responsive physical progression.

## Ownership and rendering boundary

The existing four plane identities and native ownership remain unchanged. Play borrows the ordinary Workbench worker, material textures, shader, actor session, camera and input mapping. The three static decorative Worlds still publish their admitted RG8 material data into the existing material-rendering surfaces. Optical distance is an independent artistic coordinate; it never relocates cells or changes collision, layer ordering, authoring targets, actor authority or native history.

`workbench_strata_presentation.gd` owns one `StrataOpticalRenderer`. The renderer attaches at most three lazy `ShaderMaterial` instances to the existing decorative TextureRects. Those materials sample the existing RGBA SubViewport textures after native material shading. There is no additional World, viewport, render texture, material recapture, CPU image processing, simulation turn, custom engine build or new presentation clock.

The Play surface never receives this shader. Classic and bypass restore each existing haze material **by object identity**. A fresh Classic presentation allocates no optical materials and writes no optical uniforms. Previously allocated materials may remain as a bounded cache while Classic is selected; retirement restores borrowed materials and frees their owner normally.

Optical settings update only the bounded configuration and scalar plane-depth metadata. They do not duplicate complete authored geometry or rebuild decoration. Identical values avoid repeated uniform writes. Dynamic focus uses the controller's existing process callback; changing an authored focus target changes only the shader state. No mouse or actor event causes automatic focus hunting.

## Selected shader vocabulary

| Treatment | Implementation and bound | Intent and qualification limit |
| --- | --- | --- |
| Pixel aperture | Native-cell-centred nearest sampling, bounded small cross/diagonal kernel, at most six source cells of radius | Controlled defocus on decoration; thin structures and distant lights need visual review. |
| Detail suppression | Local colour-frequency filtering with original central alpha coverage | Quieter interior texture while retaining the source silhouette. Flat-colour fixtures alone cannot prove this effect. |
| Highlight diffusion | Restrained local highlight spread with central architecture retained | Machinery and distant illumination; no global screen bloom or physical emissive propagation. |
| Tonal hierarchy | Depth-weighted contrast compression and per-plane brightness | Reduce fine competing contrast while retaining larger construction. It may lift dark distant values. |
| Chromatic hierarchy | Depth-weighted saturation, RGB tint and environmental scattering colour | Warm, cool or neutral separation; colour is never the only clarity cue. |
| Atmospheric transmission | Bounded exponential attenuation toward the authored scattering colour | Artistic haze with correct coverage, not native gas or participating media simulation. |
| Architectural shadows | Offset/softened lookup into the already-published Play material texture | Presentation shadow on rear content; explicit native Solid-family mask, no occupancy scan. |
| Local clarity | Attenuate decoration near available physical silhouettes and published actor rectangles | Preserve physical material opacity and edges; no conspicuous terrain outline is required. |
| Optical parallax | Multiply existing decorative parallax within the reversible four-plane transform | Camera movement communicates distance without moving Play or changing picking. |

The shader uses premultiplied RGBA internally because the source is an actual transparent Godot SubViewport. Coverage and colour are filtered together; empty samples do not import arbitrary RGB into silhouettes. Sampling outside the surface returns transparent coverage rather than wrapping. At the final framebuffer boundary, processed colour is converted to straight alpha and uses the same blend operation as the historical material. The Classic side of a wipe executes the literal legacy haze and vertex-colour expression, avoiding a premultiply/unpremultiply roundtrip. This distinction matters: actual Mesa execution exposed one-level encoded-colour differences between algebraically equivalent blend arrangements at partial parent opacity. The historical material itself remains unchanged in full Classic, including its existing alpha behaviour; the processed and Classic paths must not be casually interchanged.

The one-draw comparison wipe chooses processed or historical output in screen space. It does not render the scene twice. An intermediate wipe temporarily uses Classic decorative parallax, so the divider compares one geometric alignment. Full processed view restores authored optical parallax. Changing bypass or wipe cancels an in-flight paint gesture and preview because the decorative screen transform can change; it never changes the authoritative editing plane.

## Lens and temporal behaviour

Each plane has an optical depth in `[-1, 2]`. The renderer computes distance outside the sharp focal region, then derives bounded defocus from the distance, global defocus amount and per-plane contribution. The focus controls use artistic depth units and source cells, not metres or photographic f-numbers.

| Mode | Focal authority |
| --- | --- |
| Play | Stable authored Play optical depth; ordinary gameplay starting point. |
| Manual | Explicit `focus_distance`. |
| Focal plane | Explicit `focal_plane`, independent of the edit target. |
| Authoring | Follows the already-selected authoring plane; does not select that plane. |

Transition speed is bounded exponential interpolation with a snap condition, avoiding overshoot and endless tiny changes. Zero transition speed applies immediately. An inspection focus override is temporary and does not overwrite the authored target. Switching native scenes resets inspection state. Play remains crisp even when rear architecture is the focal subject.

Low quality caps the support radius at one native cell (five reads), Balanced at three cells (thirteen reads), and High at six cells (twenty-five reads). The positive binomial cross kernel samples every admitted integer radius and smoothly interpolates weights, preventing fine checker detail from reappearing at alternating focus radii. Quality is an application preference, not a scene's authored artistic intent. The expensive Diorama/High performance case remains separately identified from balanced profiles.

## Published actor reveal

When clarity is active, the presenter asks existing visible actor overlays for already-published visual bounds. `actor_presentation_bounds.gd` examines at most 64 physical render parts and merges at most eight actor rectangles; prototype bounds use the already-published ordinary state/rig arrays. Rotated and compound parts contribute conservative visual AABBs. This path never queries a native World, actor session or Rapier state.

The shader receives eight fixed rectangles plus the existing sampled-player rectangle and locally subordinates rear content. It does not change physical opacity, collision or actor transforms. Empty/retired bounds clear the count. Conservative rectangles can attenuate more background than the actual actor silhouette, and actors beyond the existing eight-slot bound have no extra reveal guarantee. Local assistance cannot make a tiny actor readable at every overview scale. Explicit temporary Show physical Play covers even planes excluded from an authored profile; releasing it restores those participation settings unchanged.

## Configuration schema and control domains

`strata_optics_configuration.gd` is the strict authored model. Optical configuration version is **1**, independently of the containing Strata document version. Unknown keys, wrong types, nonfinite values and out-of-range values are refused; validation is not a silent clamp-and-discard conversion. Built-in definitions are versioned complete configurations in `strata_optical_profiles.gd`.

| Global value | Meaningful range or values |
| --- | --- |
| `enabled`, `strength` | Boolean opt-in and `0..1` overall effect strength. |
| `profile` | Built-in identity or bounded named custom identity; embedded values remain authoritative. |
| `focus_mode`, `focal_plane` | `play/manual/plane/authoring`; one of the four existing plane IDs. |
| `focus_distance`, `dof_width` | `-1..2` artistic distance, `0..2` sharp focal width. |
| `defocus`, `transition_speed` | `0..3` defocus strength, `0..12` transition response. |
| `atmosphere`, `illumination` | `0..2` global artistic response. |
| `tonal`, `chromatic`, `shadow`, `detail`, `clarity` | `0..1` independent treatment strengths. |
| `defocus_method` | `pixel`, `diffusion` or `detail`. |
| `scattering_color` | Three finite RGB components in `0..1`. |
| `shadow_offset`, `shadow_softness` | Two native-cell components in `-32..32`; softness `0..4`. |
| `effects` | Independent booleans for defocus, tonal, chromatic, atmosphere, illumination, shadows and detail. |

Every plane has `participates`, `depth`, `contrast`, `saturation`, `tint`, `brightness`, `defocus`, `atmosphere`, `glow`, `opacity` and `parallax`. Contrast and brightness are `0.25..1.5` and `0.25..2`; saturation is `0..1.5`; RGB tint and effect contributions are `0..2`; opacity is `0..1`. Play participation is always false. The controller exposes only optical depth for Play, preventing the UI from implying that the physical material surface is processed.

The lab presents comparison, lens, atmosphere/tonal controls, per-plane values and progressively disclosed advanced effects. Tooltips explain source-cell units, temporary inspection and authoring authority. An optical plane picker never silently selects the paint target. Setting decorative optical opacity to zero leaves its native edit authority intact and produces an explicit visibility warning.

## Persistence and restoration

`CYSSTRAT` versions 1 and 2 remain supported with their existing meaning. Documents without optics open in Classic; opening or saving an old document alone does not select a new treatment. The first explicit authored optical change upgrades that document to version **3**, retaining the original Setup, four plane layouts, provenance and authored atmosphere. Version 3 adds one complete validated `optics` object, with full numeric JSON precision. It does not store shader objects or introduce a separate project format.

| Domain | Stored state | Excluded state |
| --- | --- | --- |
| Scene document v3 | Complete optical configuration and four-plane authored source | Current focus interpolation, wipe, bypass, inspection focus, clarity-assistance toggle. |
| Named optical presets | Up to 32 named full configurations in `user://strata-optics/presets.json` | Native geometry, actor data and native Undo/Redo. |
| Application preferences | Optical quality tier in a separate preferences file | Scene-authored profile choice and temporary comparison state. |

Named presets accept 1–48 characters, reject control characters and use deterministic `custom-` identities. Atomic replacement writes a staged file, flushes, rereads and verifies exact bytes before replacement. A corrupt existing catalogue is reported and preserved, not silently overwritten. Deleting a custom preset cannot remove the configuration already embedded in a scene. There is no separate preset import/export format in this candidate; ordinary scene persistence carries complete editable values.

Optical edits do not enter material Undo/Redo as fictitious native changes. Native brush, eraser, import, composition, Stop and history retain their ordinary owners. Save means authored starting composition; it is not a continuation snapshot of evolved four-World simulation or history stacks.

## Atmosphere and environment corpus

The five Strata 002 recipes are unchanged. Three additional native scenes use the same validated authoring/compiler path: Sunward Freight Megastructure, Xeno Resonance Grotto and Lunar Terminator Observatory. A separate Physical Readability Challenge fixture deliberately aligns decorative stairs, ladders and false platforms with physical geometry and records native material probes.

Existing authored atmosphere gains bounded architectural light shafts and local light pools. These draw eight or four clipped bands per source inside the existing 12-region/384-motif limit. They are static by default; optional breathing is presentation time only. They do not discover physical light sources or solve shadow occlusion. Their existing CanvasItems receive bounded optical opacity and global clarity attenuation only when settings or inspection change; they do not pass through the architecture lens/tonal shader. Classic and bypass restore their exact original modulation. An intermediate wipe leaves motifs Classic across the whole view while comparing the architectural pixels. Strong overlapping bands can expose rectangular regions and must remain an explicit artistic limitation.

## Qualification and integration seam

The optical coordinator requires actual pinned Godot graphical execution on Linux and Windows. It retains exact source/tree, loaded input hashes, original process commands/logs, raw PNGs, native readbacks, actual completed-step timestamps, process-tree CPU/RSS observations and fresh-process restoration. Headless diagnostics cannot pass the graphical gate. Pixel fixtures, whole scenes, native isolation and performance have separate evidence scopes.

The original **45-second** scene admission target remains unchanged. Its five final Strata 002 extracted Windows misses remain recorded failures. Functional scene admission and an attractive frame do not convert a missed target into performance acceptance. Hosted software rendering does not establish physical NVIDIA GPU performance or owner playfeel.

The optical renderer shares existing published presentation textures with PUBPRES but imports none of that programme's unfinished engines or publication models. Native architecture authoring, conversational Art Workbench and documentation programmes retain their own authority. Draft/HOLD remains in force pending owner artistic and physical acceptance; this feature is not merged or enabled by default.

The ordinary host exposes pan and zoom; a rotated-camera control is not present and camera rotation has not been graphically qualified by this mission. Actor rotation is separately covered by published visual bounds. Local material-mask assistance samples current published occupancy, while moving Play materials may interpolate snapshots; motion review must watch this difference rather than inventing another publication authority.
