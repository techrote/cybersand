# CyberSand world-design atlas — consolidated collections 001–015

**Status: DRAFT / design-only authoring resources (5 November 2026).** This directory consolidates 15 originally independent world-design draft PRs. It does **not** admit the pack schema into the engine, publish gameplay maps, authorize production integration or establish physics/visual qualification.

Each collection contains eight original modular proposals, a machine-readable `pack.json`, a `README.md`, a deterministic source-colour `preview.svg` and local validation/rendering tools as supplied by its source PR. The collection directories below are included at their original Git tree identities, without replacing their art or validation claims.

| Collection | Theme | Original PR |
| --- | --- | --- |
| [001 — Lumen Fault](lumen-fault/) | Subterranean survey relics | [#408](https://github.com/techrote/cybersand/pull/408) |
| [002 — Chalkbone Coast](chalkbone-coast/) | Fossil coastal structures | [#410](https://github.com/techrote/cybersand/pull/410) |
| [003 — Carved Ice Choir](carved-ice-choir/) | Glacial cathedral caverns | [#412](https://github.com/techrote/cybersand/pull/412) |
| [004 — Ashroot Nursery](ashroot-nursery/) | Biological sanctuary ruins | [#414](https://github.com/techrote/cybersand/pull/414) |
| [005 — Emberglass Fumaroles](emberglass-fumaroles/) | Volcanic vents and glass | [#420](https://github.com/techrote/cybersand/pull/420) |
| [006 — Silt Clockworks](silt-clockworks/) | Tidal regulator mechanisms | [#425](https://github.com/techrote/cybersand/pull/425) |
| [007 — Signal Orchard](signal-orchard/) | Mechanical signal groves | [#430](https://github.com/techrote/cybersand/pull/430) |
| [008 — Dust Meridian](dust-meridian/) | Desert survey ruins | [#434](https://github.com/techrote/cybersand/pull/434) |
| [009 — Cathedral of Capacitors](cathedral-of-capacitors/) | Electrical cathedral architecture | [#437](https://github.com/techrote/cybersand/pull/437) |
| [010 — Mirror Marsh](mirror-marsh/) | Reflective wetland archaeology | [#439](https://github.com/techrote/cybersand/pull/439) |
| [011 — Drowned Observatory](drowned-observatory/) | Submerged celestial instruments | [#443](https://github.com/techrote/cybersand/pull/443) |
| [012 — Ironroot Necropolis](ironroot-necropolis/) | Funerary ironworks | [#445](https://github.com/techrote/cybersand/pull/445) |
| [013 — Tectonic Archive](tectonic-archive/) | Stratigraphic stone archives | [#447](https://github.com/techrote/cybersand/pull/447) |
| [014 — Coral Telegraph](coral-telegraph/) | Submarine communication ruins | [#451](https://github.com/techrote/cybersand/pull/451) |
| [015 — Fallow Carnival](fallow-carnival/) | Abandoned carnival districts | [#453](https://github.com/techrote/cybersand/pull/453) |

**Source baseline shared by all original PRs:** accepted `main` commit `ba9cbc89029be88b812af59b19e5c59829bbcd90` / tree `3af18f50e6094776263119623b64a1b2f4ca0ab2`. Original source claims, caveats and validation reports survive inside each collection's README. Do not recharacterize any schematic preview as a Godot screenshot.

See **[QUALITY_BAR.md](QUALITY_BAR.md)** for the iterative art-direction brief, acceptance rubric, reference gallery, worker ownership matrix and source/validation safeguards. Improvement work should add creative depth rather than churn new collections or increase rectangle counts for their own sake.

## Important limitations

- Provisional `cybersand.world-feature-pack.proposal` schemas are **not** an accepted editor/importer/save format. No production World, materials, PLAY, GEN, SOL, physics or Godot code is altered.
- Ordered rectangles use source-defined material IDs and later-stamp-overwrites-earlier semantics; negative space does not erase existing terrain. Static-looking illustrations do not establish runtime stability, traversal, lighting, reflections or colliders.
- Water, Brine, Sand, Salt and other active materials require independent native execution before any simulation-facing admission. Treat a dry substitute as an authored preview choice, never as experimental proof.
- Qualification must record actual source SHA, script command, process exit, rendering method, platform, any native tick ranges and the corresponding retained artifacts. A generated SVG is a flat-material visualization, not a real engine capture.
- This is a **draft review resource**; all 120 initial module proposals remain visible. No merging until explicit owner and independent review authorization.

## Local development and checks

Each subdirectory documents its own `validate_pack.py`/`validate_pack.mjs` and `render_pack.py`/`render_pack.mjs` invocation. The scripts were authored separately; run each actual script and inspect exit codes. Use `--source` checks against the recorded baseline only when checkout material source blobs match the original pins. Any later material-source drift must be investigated and recorded rather than bypassing or weakening checks. Use `git diff --check`; do not alter original proof records or generated-asset identities without documenting the change.
