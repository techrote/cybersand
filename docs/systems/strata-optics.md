---
title: Strata optical presentation and persistence
status: Current
document-kind: contract
scope: Owner-accepted optional Strata Theatre 003 optics, controls, ownership, presets, compatibility and integration boundaries
canonical-for: [strata-optical-rendering, strata-optical-configuration, strata-optical-persistence]
last-reviewed: 2026-11-28
related-documents: [strata-workbench.md, strata-authoring.md, strata-environments.md, ../operations/strata-optical-composition.md, ../operations/strata-optics-evaluation.md]
---

# Strata optical presentation

**STRATA-THEATRE-003**, [PR #785](https://github.com/techrote/cybersand/pull/785), extends the source-preserving Strata 002 lineage. It adds an integrated **Strata Optics Lab**, eleven editable profiles and presentation-only depth cues. It does not enable Strata or optics by default. The previous application `934cc0c0eef70dad528155e9a92eebe25e2757eb`, archive `410ac8e5e613b1454928699dbc9a68cd035f0894` and evaluator remain separate immutable evidence.

This is a stylised optical compositor, not a physically calibrated lens or light transport simulation. Exact graphical, native and performance results are bound to the [dated research record](../audits/2026-11-25-strata-theatre-003/README.md). Source describes implemented behaviour; compiling a shader does not prove visual clarity or responsive physical progression.

## Owner acceptance and integration policy — 28 November 2026

The owner physically evaluated the frozen Windows evaluator on Windows 11 with
an NVIDIA TITAN RTX and accepted its functionality, visual results and practical
usability for optional use. The owner authorized integration of the complete
Strata 002/003 lineage with accepted RAMCACHE and main. The
[combined integration and delivery guide](../operations/ramcache-strata-integration.md)
records the resulting source, qualification and package separately from that
owner-tested predecessor.

**Classic remains the default.** The owner specifically waived the historical
90% native/Rapier progression-retention acceptance target for optional enhanced
profiles. The measured ratios and `observed_*_target_met` flags remain unchanged;
a waived failed target is not a benchmark pass. Historical p95/admission misses,
readability limitations and original failures remain evidence. Correctness,
source/runtime provenance, ordinary Classic behavior and new integration
regressions remain qualification obligations. The waiver does not enable optics
automatically or authorize unrelated performance changes.

The owner's preferred artistic configuration is **Diorama**, with **Rear
architecture → Optical depth = 1.3**. It is reproducible through the existing
controls and named-preset mechanism; it is not installed as a global default.
The focused ordinary-host install/fresh-reopen regression exercises that exact
configuration, authored persistence, temporary inspection exclusion and separate
application quality.

RAMCACHE's persistent host intentionally refuses Strata admission before native
decorative allocation. Its exact single-area authoring/continuation envelope does
not contain the layered document. Leave the persistent profile through its
normal durable Launcher action, then open ordinary Workbench for Strata. No
parallel Play owner or unqualified combined save format is introduced.

## Ownership and rendering boundary

The existing four plane identities and native ownership remain unchanged. Play borrows the ordinary Workbench worker, material textures, shader, actor session, camera and input mapping. The three static decorative Worlds still publish their admitted RG8 material data into the existing material-rendering surfaces. Optical distance is an independent artistic coordinate; it never relocates cells or changes collision, layer ordering, authoring targets, actor authority or native history.

`workbench_strata_presentation.gd` owns one `StrataOpticalRenderer`. The renderer attaches at most three lazy `ShaderMaterial` instances to the existing decorative TextureRects. Those materials sample the existing RGBA SubViewport textures after native material shading. There is no additional World, viewport, render texture, material recapture, CPU image processing, simulation turn, custom engine build or new presentation clock.

The Play surface never receives this shader. Bypass always restores each existing haze material **by object identity**. Classic, master disablement and zero effect strength also restore it when temporary **Show physical Play** is released. That explicit assistance can override authored enablement and strength, but cannot override Bypass. A fresh Classic presentation with assistance off allocates no optical materials and writes no optical uniforms. Previously allocated materials may remain as a bounded cache while Classic is selected; retirement restores borrowed materials and frees their owner normally.

Optical settings update only the bounded configuration and scalar plane-depth metadata. They do not duplicate complete authored geometry or rebuild decoration. Identical values avoid repeated uniform writes. Dynamic focus uses the controller's existing process callback; changing an authored focus target changes only the shader state. No mouse or actor event causes automatic focus hunting.

## Selected shader vocabulary

| Treatment | Implementation and bound | Intent and qualification limit |
| --- | --- | --- |
| Pixel aperture | Native-cell-centred nearest sampling, dense positive binomial cross kernel, at most six source cells of support | Controlled defocus on decoration; thin structures and distant lights need visual review. |
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

Low quality caps the support radius at one native cell (five surface reads), Balanced at three cells (thirteen surface reads), and High at six cells (twenty-five surface reads). These counts describe the aperture filter; shadows and local clarity can require additional published-mask reads. The positive binomial cross kernel samples every admitted integer radius and smoothly interpolates weights, preventing fine checker detail from reappearing at alternating focus radii. The cross is anisotropic: one-dimensional alternating rails retain half their contrast at integer radii, while an alternating two-dimensional checker can be suppressed completely. Support radius is not Gaussian sigma or a calibrated bokeh width. Quality is an application preference, not a scene's authored artistic intent. The expensive Diorama/High performance case remains separately identified from balanced profiles.

## Published actor reveal

When clarity is active, the presenter asks existing visible actor overlays for already-published visual bounds. `actor_presentation_bounds.gd` examines at most 64 physical render parts and merges at most eight actor rectangles; prototype bounds use the already-published ordinary state/rig arrays. Rotated and compound parts contribute conservative visual AABBs. This path never queries a native World, actor session or Rapier state.

The shader receives eight fixed rectangles plus the existing sampled-player rectangle and locally subordinates rear content. It does not change physical opacity, collision or actor transforms. Empty/retired bounds clear the count. The ordinary Workbench retains default budgets of eight actors and 64 parts, while accepted Sandbox Capacity can explicitly admit larger populations. Optical local assistance retains its independently bounded scan of the first 64 published parts and at most eight actor rectangles; it does not promise local assistance for every actor in an enlarged population. The separate sampled-player rectangle belongs to the sampled-character presentation path; it is not a fallback for a selected Midge. Conservative rectangles can attenuate more background than the actual actor silhouette. Actual actor rendering, labels, collision and physics retain their existing capacity and authority. Expanded optical priority/coverage is deferred; local assistance cannot make a tiny actor readable at every overview scale. Explicit temporary Show physical Play covers even planes excluded from an authored profile; releasing it restores those participation settings unchanged.

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

The five Strata 002 recipes are unchanged. Three additional native scenes use the same validated authoring/compiler path: Sunward Freight Megastructure, Xeno Resonance Grotto and Lunar Terminator Observatory. A separate Optics Readability Challenge fixture deliberately aligns decorative stairs, ladders and false platforms with physical geometry and records native material probes.

Existing authored atmosphere gains bounded architectural light shafts and local light pools. These draw eight or four clipped bands per source inside the existing 12-region/384-motif limit. They are static by default; optional breathing is presentation time only. They do not discover physical light sources or solve shadow occlusion. Their existing CanvasItems receive bounded optical opacity and global clarity attenuation only when settings or inspection change; they do not pass through the architecture lens/tonal shader. Bypass restores their exact original modulation; Classic does so when temporary clarity assistance is released. An intermediate wipe leaves motifs Classic across the whole view while comparing the architectural pixels. Strong overlapping bands can expose rectangular regions and must remain an explicit artistic limitation.

## Qualification and integration seam

The optical coordinator requires actual pinned Godot graphical execution on Linux and Windows. It retains exact source/tree, loaded input hashes, original process commands/logs, raw PNGs, native readbacks, actual completed-step timestamps, process-tree CPU/RSS observations and fresh-process restoration. Headless diagnostics cannot pass the graphical gate. Pixel fixtures, whole scenes, native isolation and performance have separate evidence scopes.

The final renderer fixtures passed 109 assertions with zero failures on each actual hosted backend. Exact Classic comparison means each backend against its own reference at nontrivial haze and parent opacity. Of 18 Linux/Windows technical PNG pairs, 11 are identical and seven differ by at most one encoded u8 level per channel, affecting 5,524 of 884,736 channels. This is not whole-scene or cross-backend bit identity. The native environment corpus is predominantly dark; synthetic white/highlight checks do not establish bright-daylight gameplay readability.

The original **45-second** scene admission target remains unchanged. Its five final Strata 002 extracted Windows misses remain recorded failures. Functional scene admission and an attractive frame do not convert a missed target into performance acceptance. Hosted software rendering does not establish physical NVIDIA GPU performance or owner playfeel.

The frozen `fd0830ab` Linux campaign passed its functional/native and exact Classic predecessor controls, but every measured enabled profile failed the registered median native/Rapier rate and physical-p95 criteria. The ordinary balanced profiles retained approximately 75–82% of Classic's measured progression in that hosted challenge cohort. Both separately observed five-minute sessions retained native ownership and bounded node/resource counts; the Windows session still missed admission and had substantial draw/physical interval tails. The [dated independent performance review](../audits/2026-11-25-strata-theatre-003/c-performance-review-linux.md) and [sustained review](../audits/2026-11-25-strata-theatre-003/c-sustained-v2-review.md) own those exact source/platform observations. No allocation or native-isolation property implies a performance pass. The final Windows cohort also fails every measured enabled native/Rapier rate gate (approximately 76–84% of Classic); Architectural alone meets its p95 criterion. All nine initial Windows source-campaign admissions exceed 45 seconds. See the [complete Windows summary](../audits/2026-11-25-strata-theatre-003/profile-observations-windows.json). A separately observed exact-output optimisation improves both hosted cohorts, but is not adopted into the frozen application. Those historical enabled-optics performance failures remain preserved under the narrow owner-acceptance policy above.

The optical renderer shares existing published presentation textures with PUBPRES but imports none of that programme's unfinished engines or publication models. Native architecture authoring, conversational Art Workbench and documentation programmes retain their own authority. Owner artistic and physical acceptance now permits the bounded integration described above. The combined source and delivery require their own qualification; enhanced optics remains disabled by default.

The ordinary host exposes pan and zoom; a rotated-camera control is not present and camera rotation has not been graphically qualified by this mission. Actor rotation is separately covered by published visual bounds. Local material-mask assistance samples current published occupancy, while moving Play materials may interpolate snapshots; motion review must watch this difference rather than inventing another publication authority.

The final hosted Windows portable package completed all 31 extracted full-suite cases and the actual shipped command on unchanged payload bytes. A separate cold-first-command observer retains its own source and result; the main suite prepared imports before its command. See the [delivery provenance](../audits/2026-11-25-strata-theatre-003/delivery-provenance.json) and [decision packet](../audits/2026-11-25-strata-theatre-003/decision-packet.md). The original Windows paired Classic comparison also passed; a separately reviewed external command-path parser permits Linux re-reading without changing its acceptance gates.

The architectural counterpart's native-module v2 fixed-region/connection semantics remain unsupported by this candidate's frozen v1 adapter and are deliberately refused. Art Workbench proposals retain native Play-only authority and reject optical/layer actions. Neither counterpart currently implements this Strata v3 scene codec. Future reconciliation must preserve complete optical values, Play guards and existing save/load ownership; named presets can become read-only context only through an explicit separately qualified extension.
