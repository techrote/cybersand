---
title: GENTEK 80 Windows evaluation
status: Current
document-kind: guide
scope: Accepted 80-Gentek selection and comparison, with separately qualified Windows evaluator and historical package evidence
canonical-for: [gentek80-selection-and-evaluation]
last-reviewed: 2026-11-25
related-documents: [../systems/architectural-generator.md, architectural-generator-playtest.md, ../research/gentek-80-integration-001.md]
---

# GENTEK 80 — Windows evaluation

The accepted Architectural Generator provides **72 compact CLASSIC Genteks and
eight advanced showcases**, alongside the thirteen earlier presets: 93 choices.
The catalogue and main integration were accepted through
[#684](https://github.com/techrote/cybersand/pull/684) and
[#691](https://github.com/techrote/cybersand/pull/691). A separate evaluator's
qualification and physical owner acceptance remain distinct from catalogue
availability.

Use [Getting started](getting-started.md) for the accepted-source launch and
[the Architectural Generator walkthrough](architectural-generator-playtest.md)
for a first composition. This page adds comparison suggestions and the complete
Gentek defaults table.

## Integration with accepted Workbench main

Current generation uses the ordinary Workbench's preview, installation, painting
and authored-save paths. An installed generated start is not an exact evolved
physical checkpoint; [saving](workbench-saving.md) explains that boundary.
Current Art conversation starts empty in each new Workbench session after
accepted #727. Old automatic traffic-restoration procedures are not current
startup instructions; use [the Art guide](workbench-art.md).

**Tooling acceptance, 25 November 2026:**
[#758](https://github.com/techrote/cybersand/pull/758) merged source-exact Windows
evaluation and owner-acceptance tooling at
[`be87b18b`](https://github.com/techrote/cybersand/commit/be87b18b30506ccead610c7035ae1ffa8e65a347).
The [physical owner-acceptance guide](gentek80-physical-owner-acceptance.md)
explains independent archive/manifest verification, isolated launch and local
evidence collection. This tooling merge does not qualify a new ZIP or establish
physical Windows/NVIDIA acceptance. Each package still needs its exact source,
runtime manifest and executed qualification; historical ZIPs retain their own
evidence and availability. Consult the [current-state register](../reference/status-and-roadmap.md#active-candidates-and-integration-boundaries)
before using a later package.

**Historical #691 qualification:** the original integration record reconciled
`69209acaffb34ebe18c45e19290b5976b7fb2c82` and documented a then-current Art
archive/durability path. Later #727 changed the session contract. The original
source, commands, fixtures, negative evidence and ZIP qualification remain in
[the source-pinned guide](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/operations/gentek80-evaluation.md#integration-with-accepted-workbench-main)
and [PR #691](https://github.com/techrote/cybersand/pull/691); they are not fresh
results for the current documentation head.

The retained supplemental runner
[`gentek80_main_integration.py`](../../tools/architecture/gentek80_main_integration.py)
checks the ordinary form, generated-start installation, independent-process
reopening and a pinned Graftloom fixture, with source/runtime checks and explicit
graphical mode. Its original receipts keep their original identities. A new run
needs its actual admitted source, fixtures, runtime and display; the existence of
the runner or old passing output does not qualify a new package. No integration
or Windows graphical campaign was rerun for this documentation correction. The
public gallery likewise retains its original render identity.

## Launch and select

From an accepted-source checkout, launch through [Getting started](getting-started.md)
and select **Development workbench**. If you instead have a complete, identified
Windows evaluator, extract its entire ZIP to a new directory and use its supplied
**Open Workbench.cmd**. A complete package supplies its pinned Godot and matching
native runtime; keep the project, dependencies and manifests together. Its
manifest, rather than this general procedure, identifies the candidate you run.

Open **New from generator → Architectural Generator**. Each of the five style
cards has a dropdown and a **Find style** field. Search by a name such as
`Interlaced`, a family such as `truss`, or a theme such as `industrial`. The current
selection remains available while filtering; clearing the field restores the
complete catalogue. Hover over a clipped name to read it in full.

For an individual Gentek, enable one card and give it **100%**. Leave the others
disabled. Use 512² for a quick study and 1024² for larger compositions. Start with
seed **605**, turn automatic tunnels off to inspect the uncut structure, and leave
doors/windows on. Click **Generate preview**, inspect the completed native map,
then **Install into workbench**. Installation replaces the current World only
after confirmation; save valued work before installing another map.

## Suggested first comparisons

| Selection | Look for |
| --- | --- |
| Arched Viaduct (accepted reference) | Clear arches, differentiated decks and centred solid pier inlays |
| Suspended Deck | Hangers meeting the underside of the upper carrier without a missing contact row |
| Rib Vault | Face-connected pointed ribs, including steep proportions such as bay 48 / floor 128 / wall 1 |
| Megatruss Station | Large primary truss, concrete transfer cores, smaller bracing and station decks |
| Cathedral Megaframe | A larger structural rhythm with nested ribs, towers and nave space |
| Seeded Typology Megablock | Distinct seeded building programmes within a coherent block |
| Metabolist Spine | Primary service spine with separately articulated attached volumes |
| Interlaced Viaduct | Heavy arch structure crossing a contrasting suspended frame |
| Rosework Gatehouse | Radial ribs around a legible rose opening above a retained main gateway |
| Interlock Brutalism | Recessed concrete cores and differently proportioned cantilevered fingers |
| Suspended Arcology | Dominant upper carrier, rooted hangers, attached districts and deliberate lower void |

The 72 compact patterns are intentionally easier to read and modify than the eight
showcases. Some patterns do not use the seed to vary their local lattice. Same-seed
replay remains deterministic; different geometry, aperture or material settings
provide variation even for a seed-independent pattern. A stable pattern should
not be mistaken for a broken reseed button.

## Geometry, materials and composition

**Room / bay**, **Floor** and **Wall** alter spacing, vertical rhythm and member
thickness. Admitted combinations differ between styles: a large frame needs enough
room for its members, windows and openings. Invalid combinations produce a refusal
before replacing the World. Return to valid values or restore the previous preview.

The global **Doors**, **Windows** and **Tunnels** switches are independent. A style's
explicit imported aperture override takes precedence over its global switch.
Automatic tunnels are later shared cuts and can remove supporting members; keep
them off when judging unmodified construction. Windows should occupy intended
openings and leave structural pillars intact. The existing Cellular Hive follows
its hexagonal web, while Arched Viaduct retains its accepted structural detailing.

Each style has native wall, floor/accent and window material roles. Current preset
choices are visible on hover. To change materials, use **Import style** with one
of the bundled `examples/worldgen/architectural/*.style.json` files, retaining
its format/version and selecting valid static material IDs. Import embeds the
complete style; saved projects and generated starts do not depend on that external
file remaining on disk. The catalogue below lists the shipped materials and
geometry. Numerical IDs and definitions remain owned by the accepted native
material catalogue; no new simulation law is introduced here.

For a composition, enable up to five cards and choose **Equal shares** or enter
shares totalling 100%. Zones are connected planning regions, including empty space.
Zone boundaries, map edges, explicit cuts and deterioration can clip structures.
They do not promise a globally connected walking route or physical structural
stability. Use the ordinary paint tools to finish joins and traversal spaces.

## Test It

1. Generate **Suspended Deck**, seed 605, default geometry at 512². Inspect both
   hanger-to-carrier contacts. Reseed to 1701 and return to 605; the original output
   should return exactly.
2. Generate **Rib Vault**, then try bay 48 / floor 128 / wall 1. Inspect the steep
   ribs at close zoom. Restore default geometry before comparing another style.
   Also inspect **Scalloped Vault** at bay 48 / floor 64 / wall 2: each of its
   three small arches should have a continuous rib. **Ring Pier** should retain
   an empty diamond centre with stems touching both decks. **Tripod Frame**
   should connect successive tiers through its transfer decks, and **Cascade
   Terrace** should join its staggered platforms to a continuous rear core.
   With windows enabled, **Suspended Deck** and **Buttress Wall** should have
   framed panes without glass replacing the structural piers.
3. Generate **Interlaced Viaduct**, then **Rosework Gatehouse**, then one of the
   other advanced showcases at 1024². Compare silhouettes and intended voids;
   use the window/door switches individually to identify their actual effects.
4. Install a chosen map. Keep it paused, paint a visible Reinforced Concrete
   stroke and erase through another wall. Use **Step** or briefly **Play** to
   confirm the ordinary material World runs, then pause again.
5. Save a distinct named start. Exit Godot completely, relaunch
   the same source launcher or **Open Workbench.cmd**, and load that name. Confirm the same generated start
   and ordered paint/erase edits return. The save describes the authored start,
   not an arbitrary evolved simulation snapshot.
6. Open a new proposal with different settings, then **Stop preview**. The
   currently installed World must remain usable. Try an invalid share total or
   an impossible dimension; refusal must retain the existing World.
7. Try a five-style composition and a sparse selection using cards 1, 3 and 5.
   Check the per-style zone colours, names and shares, then save/reopen it.

Record the package's source SHA, selected styles, seed, dimensions, Windows/display
settings and any observed fault. Automated Windows graphical checks and PNGs do
not replace the owner's physical NVIDIA/Firefox-machine assessment. No merge,
Ready promotion or auto-merge is authorized by this guide.

## Complete catalogue and defaults

All eighty entries below use module version 1 and recipe schema 4. Bay/floor/wall are
cell dimensions; the material columns show wall, floor/accent and window roles.
The thirteen earlier presets are retained separately and are not counted here.

| Gentek | Family | Bay / floor / wall | Wall · floor/accent · window |
| --- | --- | --- | --- |
| A-Frame Hall | CLASSIC | 96 / 96 / 3 | Reinforced Concrete (58) · Aluminium Panel (114) · Frosted Glass (121) |
| Barrel Arcade | CLASSIC | 96 / 88 / 3 | Marble (98) · Terrazzo (111) · Glass Block (120) |
| Basilica | CLASSIC | 112 / 96 / 3 | Marble (98) · Terrazzo (111) · Frosted Glass (121) |
| Bowstring Truss | CLASSIC | 96 / 72 / 3 | Steel Plate (62) · Aluminium Panel (114) · Frosted Glass (121) |
| Bridgehouse | CLASSIC | 96 / 80 / 3 | Marble (98) · Brass Panel (119) · Frosted Glass (121) |
| Butterfly Hall | CLASSIC | 96 / 88 / 3 | Zinc Sheet (113) · Aluminium Panel (114) · Frosted Glass (121) |
| Buttress Crown | CLASSIC | 96 / 96 / 4 | Firebrick (104) · Marble (98) · Glass Block (120) |
| Buttress Wall | CLASSIC | 96 / 80 / 4 | Firebrick (104) · Marble (98) · Glass Block (120) |
| Cable Gallery | CLASSIC | 112 / 72 / 2 | Carbon Fibre (130) · Aluminium Panel (114) · Frosted Glass (121) |
| Cantilever Spine | CLASSIC | 96 / 72 / 3 | Carbon Fibre (130) · Aluminium Panel (114) · Frosted Glass (121) |
| Cascade Terrace | CLASSIC | 96 / 96 / 3 | Firebrick (104) · Terrazzo (111) · Glass Block (120) |
| Chain Vault | CLASSIC | 96 / 88 / 3 | Basalt Columns (100) · Obsidian (101) · Uranium Glass (123) |
| Chevron Hall | CLASSIC | 96 / 80 / 3 | Reinforced Concrete (58) · Aluminium Panel (114) · Frosted Glass (121) |
| Clerestory Hall | CLASSIC | 96 / 80 / 3 | Reinforced Concrete (58) · Terrazzo (111) · Frosted Glass (121) |
| Colonnade | CLASSIC | 96 / 80 / 3 | Marble (98) · Terrazzo (111) · Glass Block (120) |
| Corbel Arcade | CLASSIC | 96 / 88 / 4 | Marble (98) · Terrazzo (111) · Glass Block (120) |
| Cranked Beam | CLASSIC | 96 / 80 / 3 | Zinc Sheet (113) · Aluminium Panel (114) · Frosted Glass (121) |
| Crenellated Bridge | CLASSIC | 96 / 80 / 3 | Firebrick (104) · Brass Panel (119) · Glass Block (120) |
| Crossbeam Stack | CLASSIC | 96 / 96 / 3 | Steel Plate (62) · Steel Grating (66) · Frosted Glass (121) |
| Crown Bridge | CLASSIC | 96 / 80 / 3 | Firebrick (104) · Brass Panel (119) · Glass Block (120) |
| Diamond Truss | CLASSIC | 96 / 72 / 3 | Carbon Fibre (130) · Aluminium Panel (114) · Frosted Glass (121) |
| Double Cantilever | CLASSIC | 96 / 88 / 3 | Steel Plate (62) · Steel Grating (66) · Frosted Glass (121) |
| Drum Vault | CLASSIC | 96 / 88 / 4 | Basalt Columns (100) · Obsidian (101) · Uranium Glass (123) |
| Fan Truss | CLASSIC | 96 / 80 / 3 | Carbon Fibre (130) · Aluminium Panel (114) · Frosted Glass (121) |
| Flying Buttress | CLASSIC | 96 / 80 / 3 | Firebrick (104) · Aluminium Panel (114) · Glass Block (120) |
| Folded Plate Hall | CLASSIC | 96 / 80 / 3 | Zinc Sheet (113) · Aluminium Panel (114) · Frosted Glass (121) |
| Forked Gantry | CLASSIC | 96 / 80 / 3 | Steel Plate (62) · Aluminium Panel (114) · Frosted Glass (121) |
| Hanging Arcade | CLASSIC | 96 / 80 / 3 | Marble (98) · Brass Panel (119) · Glass Block (120) |
| Harp Bridge | CLASSIC | 112 / 80 / 2 | Zinc Sheet (113) · Aluminium Panel (114) · Frosted Glass (121) |
| Hourglass Pier | CLASSIC | 96 / 88 / 4 | Firebrick (104) · Brass Panel (119) · Glass Block (120) |
| Inverted Arch | CLASSIC | 96 / 80 / 3 | Steel Plate (62) · Aluminium Panel (114) · Frosted Glass (121) |
| Inverted Trestle | CLASSIC | 96 / 88 / 3 | Steel Plate (62) · Aluminium Panel (114) · Frosted Glass (121) |
| Kingpost Frame | CLASSIC | 96 / 88 / 3 | Firebrick (104) · Brass Panel (119) · Glass Block (120) |
| Ladder Bridge | CLASSIC | 80 / 64 / 2 | Zinc Sheet (113) · Aluminium Panel (114) · Frosted Glass (121) |
| Lantern Tower | CLASSIC | 96 / 96 / 3 | Carbon Fibre (130) · Aluminium Panel (114) · Frosted Glass (121) |
| Lattice Tower | CLASSIC | 80 / 96 / 2 | Carbon Fibre (130) · Aluminium Panel (114) · Frosted Glass (121) |
| Lenticular Bridge | CLASSIC | 112 / 80 / 2 | Carbon Fibre (130) · Aluminium Panel (114) · Frosted Glass (121) |
| Monopod Tower | CLASSIC | 96 / 96 / 3 | Carbon Fibre (130) · Aluminium Panel (114) · Frosted Glass (121) |
| Mushroom Deck | CLASSIC | 96 / 80 / 4 | Reinforced Concrete (58) · Steel Grating (66) · Glass Block (120) |
| Nested Arcade | CLASSIC | 96 / 80 / 3 | Firebrick (104) · Brass Panel (119) · Glass Block (120) |
| Offset Arcade | CLASSIC | 96 / 80 / 3 | Firebrick (104) · Terrazzo (111) · Glass Block (120) |
| Pointed Arcade | CLASSIC | 96 / 88 / 3 | Marble (98) · Terrazzo (111) · Glass Block (120) |
| Portal Frame | CLASSIC | 80 / 72 / 3 | Reinforced Concrete (58) · Steel Grating (66) · Frosted Glass (121) |
| Pratt Truss | CLASSIC | 96 / 80 / 3 | Steel Plate (62) · Aluminium Panel (114) · Frosted Glass (121) |
| Pyramidal Frame | CLASSIC | 96 / 96 / 3 | Carbon Fibre (130) · Aluminium Panel (114) · Frosted Glass (121) |
| Queenpost Frame | CLASSIC | 96 / 88 / 3 | Marble (98) · Brass Panel (119) · Glass Block (120) |
| Radial Stay Bridge | CLASSIC | 112 / 88 / 2 | Zinc Sheet (113) · Aluminium Panel (114) · Frosted Glass (121) |
| Rib Vault | CLASSIC | 80 / 80 / 3 | Basalt Columns (100) · Obsidian (101) · Uranium Glass (123) |
| Ring Pier | CLASSIC | 96 / 88 / 3 | Carbon Fibre (130) · Aluminium Panel (114) · Frosted Glass (121) |
| Sawtooth Gallery | CLASSIC | 64 / 56 / 2 | Zinc Sheet (113) · Aluminium Panel (114) · Frosted Glass (121) |
| Scalloped Vault | CLASSIC | 96 / 80 / 3 | Marble (98) · Brass Panel (119) · Glass Block (120) |
| Shelf Stack | CLASSIC | 96 / 88 / 3 | Steel Plate (62) · Steel Grating (66) · Frosted Glass (121) |
| Space Frame | CLASSIC | 96 / 80 / 2 | Carbon Fibre (130) · Aluminium Panel (114) · Frosted Glass (121) |
| Spine Arcade | CLASSIC | 96 / 88 / 3 | Marble (98) · Brass Panel (119) · Glass Block (120) |
| Split Pier | CLASSIC | 80 / 80 / 3 | Firebrick (104) · Brass Panel (119) · Glass Block (120) |
| Stacked Arcade | CLASSIC | 96 / 96 / 3 | Marble (98) · Terrazzo (111) · Frosted Glass (121) |
| Staggered Balcony | CLASSIC | 96 / 96 / 3 | Reinforced Concrete (58) · Aluminium Panel (114) · Frosted Glass (121) |
| Steel Trestle | CLASSIC | 72 / 64 / 3 | Steel Plate (62) · Steel Grating (66) · Frosted Glass (121) |
| Stepped Aqueduct | CLASSIC | 96 / 80 / 3 | Marble (98) · Firebrick (104) · Glass Block (120) |
| Stepped Buttress | CLASSIC | 96 / 88 / 4 | Firebrick (104) · Marble (98) · Glass Block (120) |
| Suspended Deck | CLASSIC | 96 / 72 / 3 | Steel Plate (62) · Steel Grating (66) · Frosted Glass (121) |
| Suspension Pylon | CLASSIC | 112 / 88 / 3 | Carbon Fibre (130) · Aluminium Panel (114) · Frosted Glass (121) |
| Tripod Frame | CLASSIC | 96 / 88 / 3 | Carbon Fibre (130) · Aluminium Panel (114) · Frosted Glass (121) |
| Triptych Arcade | CLASSIC | 108 / 88 / 3 | Marble (98) · Brass Panel (119) · Glass Block (120) |
| Twin Mast Bridge | CLASSIC | 112 / 88 / 3 | Steel Plate (62) · Aluminium Panel (114) · Frosted Glass (121) |
| Vierendeel Frame | CLASSIC | 96 / 80 / 3 | Reinforced Concrete (58) · Steel Grating (66) · Frosted Glass (121) |
| Warren Truss | CLASSIC | 96 / 80 / 3 | Carbon Fibre (130) · Aluminium Panel (114) · Frosted Glass (121) |
| Wedge Gallery | CLASSIC | 96 / 80 / 3 | Zinc Sheet (113) · Aluminium Panel (114) · Frosted Glass (121) |
| Yoke Bridge | CLASSIC | 96 / 88 / 3 | Firebrick (104) · Brass Panel (119) · Glass Block (120) |
| Ziggurat Arcade | CLASSIC | 96 / 96 / 4 | Firebrick (104) · Marble (98) · Glass Block (120) |
| Zigzag Bridge | CLASSIC | 96 / 72 / 3 | Steel Plate (62) · Zinc Sheet (113) · Frosted Glass (121) |
| Zigzag Pier | CLASSIC | 96 / 88 / 3 | Steel Plate (62) · Aluminium Panel (114) · Frosted Glass (121) |
| Cathedral Megaframe | showcase | 72 / 96 / 5 | Marble (98) · Brass Panel (119) · Frosted Glass (121) |
| Interlaced Viaduct | showcase | 80 / 64 / 3 | Marble (98) · Rusted Steel (65) · Frosted Glass (121) |
| Interlock Brutalism | showcase | 80 / 72 / 3 | Steel Plate (62) · Aluminium Panel (114) · Frosted Glass (121) |
| Megatruss Station | showcase | 64 / 96 / 3 | Reinforced Concrete (58) · Rusted Steel (65) · Frosted Glass (121) |
| Metabolist Spine | showcase | 96 / 88 / 3 | Reinforced Concrete (58) · Rusted Steel (65) · Frosted Glass (121) |
| Rosework Gatehouse | showcase | 128 / 80 / 3 | Basalt Columns (100) · Brass Panel (119) · Stained Glass (55) |
| Seeded Typology Megablock | showcase | 96 / 64 / 4 | Reinforced Concrete (58) · Steel Plate (62) · Frosted Glass (121) |
| Suspended Arcology | showcase | 80 / 72 / 3 | Reinforced Concrete (58) · Rusted Steel (65) · Frosted Glass (121) |
