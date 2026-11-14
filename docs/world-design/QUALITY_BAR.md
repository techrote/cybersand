# World-design refinement contract — outperform reference galleries

**Design objective:** turn 15 useful but mostly flat, isolated world-feature atlases into distinctive, deeply authored, reusable and visually cohesive environmental compositions. The requested target is *higher artistic detail and quality* than the five existing CyberSand gallery references below. That is an aspiration and an admission gate, **not** a current achievement claim. Evaluate the actual reference pixels, not filenames or subjective assumptions.

## Source-gallery visual benchmarks

1. [Deepworks atlas](https://github.com/techrote/cybersand/blob/main/docs/images/deepworks/deepworks-atlas.png?raw=true) — macro-scale environmental ambition and spatial layering.
2. [GEN-007 gallery view 4](https://github.com/techrote/cybersand/blob/main/docs/images/gen007/gen007-gallery-4.png?raw=true) — compositional richness in a finished engine presentation.
3. [Neon Reliquary Descent frame 04](https://github.com/techrote/cybersand/blob/main/docs/images/neon-reliquary-descent/neon_reliquary/neon-reliquary-04.png?raw=true) — legible focal accents, colour hierarchy and narrative space.
4. [Blacksite Nine full view](https://github.com/techrote/cybersand/blob/main/docs/images/blacksite-nine/blacksite-nine.png?raw=true) — structural density, architectural repetition with variation and world-scale readability.
5. [GEN-007 atlas](https://github.com/techrote/cybersand/blob/main/docs/images/gen007/gen007-atlas.png?raw=true) — large-region composition, transitions and continuity.

**Do not substitute unrelated web images.** Reference captures are not equivalent to flat source-colour SVGs. If actual rendered CyberSand capture cannot be produced, mark the *engine-comparison gate untested*; continue source-bound visual development without claiming reference superiority.

## Required artistic improvements

**Macro / 100% atlas scale:** Give every combined scene a strong, readable sequence of foreground landmarks, supporting terrain, bridges/voids and secondary visual motifs. Replace an eight-items-in-a-row catalogue feeling with an *authored place*: elevation changes, transitions, subordinate structures, believable access/negative spaces and controlled focal hierarchy. Retain usable stand-alone modules and documented spacing/anchors. Make themes unmistakable in silhouette alone.

**Meso / 1× native-cell detail:** Add meaningful environmental storytelling (maintenance scars, erosion, broken spans, infill, pipes/cables, rooted seams, layered geological strata, masonry joints, signage, relic groupings, vegetation or deposition as appropriate), varied scales and structural depth. Small motifs must support architecture and explain how a place came to look this way. Do not clutter every gap.

**Micro / close crop:** Introduce non-repeating fine-grain workmanship, edge wear, fractures, seams, residue, embedded specimens, subtly irregular repeated features and deliberate material transitions where supported by actual native material types. Avoid straight rectangles or single-width line spam that only increase stamp count. Use limited bright accents against a designed value hierarchy.

**Colour / physical truth:** Verify exact runtime native material IDs and shadow-palette identity; native header governs runtime. Use source-defined shader/pattern behavior when an actual capture is available. Do not invent light emission, dynamic specular reflections, functioning signals, fluid seals, electrical circuits, sound, real mechanics or collision-clearance. Separate physically active original modules from dry, fixed composition variants and native-tested outputs.

**Narrative / reuse:** Each pack retains eight individually reusable features, meaningful variants, at least three viable motif combinations, reliable anchors and explicit risks. Develop at least one flagship integrated diorama per collection and one alternate arrangement that materially changes the storytelling, rather than just recolouring a line of modules. Ensure intentional visual distinctiveness among all 15 themes.

**Portfolio curation:** Select and prioritise the greatest quality gaps, including one flagship sample per worker each cycle. Compare side-by-side at similar presentation scale. Record both wins and regressions; reject changes that trade readability for noise, erase a distinctive motif, fabricate engine behaviour or break repeatability.

## Review gates (evidence required)

- **Visual rubric (score 0–5 each, per collection):** silhouette/scale hierarchy; architectural/geologic richness; authentic micro-detail; value/colour discipline; environmental narrative; coherent integrated composition; cross-theme distinctiveness. Target at least 4/5 in all seven dimensions, with written evidence and actual before/after images. This is a reviewer judgement, not an automatic count-based pass.
- **Reference comparison:** For each flagship, preserve original SVG, improved deterministic preview and, when technically available, a separately labelled real Godot/native material render; produce equivalent-scale closeups and a short critique against **all five** benchmarks. Any statement that quality exceeds a benchmark needs specific visual evidence and human review. Until then state "target not yet independently accepted."
- **Source/geometry:** Each updated pack passes its real parser/bounds/material-identity/variant/overlap/source controls. Regenerate its deterministic preview; verify preview matches changed geometry and `render_pack --check` or equivalent. Preserve explicit `[x,y,width,height,material_id]`, overwrite order, correct scene coordinates, source hashes and type/flow categories. Add focused negative mutations when introducing new schema behavior.
- **Simulation segregation:** Any Water/Brine/Sand/Salt or reactive/wear/thermal logic must remain proposal-only unless actual native tests report source identity, runtime platform, t=0/60/600+ as relevant, measured leakage/quantity/performance and process exit. **Draft CI skips are not green native evidence.**
- **No production integration:** No engine/material catalogue/physics/workbench/PLAY/GEN code, default maps, release claims or implicit merge. Keep design resources under `docs/world-design/` unless independently scoped and authorised.
- **Handover:** Each hourly change must be a finished, bounded visual improvement with exact paths, before/after PNG/SVG evidence when available, validation output, unmet gates, a reviewable commit and one concise PR comment. Record progress and stop; do not claim completion from plans.

## Hourly cooperative custody (separate directories, one canonical PR)

**Worker A — collections 001–005** (Lumen Fault, Chalkbone Coast, Carved Ice Choir, Ashroot Nursery, Emberglass Fumaroles): terrain architecture, macro composition and first five flagship vistas. Writes only those five directories and optional review comments.

**Worker B — collections 006–010** (Silt Clockworks, Signal Orchard, Dust Meridian, Cathedral of Capacitors, Mirror Marsh): mechanism/ruin fidelity, intricate craft details and integrated middle-five landscapes. Writes only those five directories and optional review comments.

**Worker C — collections 011–015** (Drowned Observatory, Ironroot Necropolis, Tectonic Archive, Coral Telegraph, Fallow Carnival): distinctive late-five flagship dioramas, detailed finish and reference-backed independent cross-pack review. Writes only those five directories plus this root index/quality rubric when needed; never silently revise A/B files.

**Single branch:** The PR head is the sole canonical integration branch. No worker may merge or close it, modify other workers' owned files, rewrite history or force-push. Start each session by refreshing the live PR head and reading `AGENTS.md`, `SCHEDUSWARM.md`, this file, active PR comments and relevant material source. Before every push use a fast-forward-only update from the latest head (or Git data API compare-and-swap using `expected_sha`). If head advanced, rebase own disjoint changes, re-run checks and retry. If source/ownership conflicts arise, **stop and comment**, not overwrite. Do not create a duplicate active consolidation PR. Staggered schedules reduce concurrency but do not replace SHA/lease checks.

Keep each run self-contained and creative: choose ONE collection/flagship needing greatest visible improvement, implement geometry and preview revisions, run its real checks and return comparison evidence. Workers may critique other lanes in comments but must not edit their files. Cross-collection conclusions are reviewer advice, not acceptance by fiat. Never claim to have inspected or rendered reference pixels that were inaccessible.

**Concurrency:** These three standalone user-requested creative workers do not reactivate the currently paused SCHEDUSWARM dispatcher. Respect the repository's documented no-parallel-integration-writes principle and project concurrency budget; defer if conflicting shared-source activity is in progress.
