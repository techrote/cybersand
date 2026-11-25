---
title: Architectural Generator Phase A and B
status: Current
document-kind: contract
scope: Opt-in schema-4 architectural controls, versioned native geometry and bounded one-to-five-style project compilation
canonical-for: [architectural-generator-controls, architectural-style-projects, architectural-zone-coverage]
keywords: [architecture, GEN-007, styles, zones, coverage, tunnels, doors, windows, Hilbert, Arcology, Vault]
last-reviewed: 2026-11-24
related-documents: [procedural-world-generation.md, procedural-typed-spatial-fields.md, procedural-hierarchical-generation.md, generation-workbench-2.md, explore001-generated-playable-maps.md, ../operations/architectural-generator-playtest.md]
---

# Architectural Generator — Phase A and bounded Phase B

**Current accepted source, 24 November 2026 (`00cdb02f`).** The schema-4
Architectural Generator foundation (#582) and the 80-Gentek integration (#691)
are merged. Earlier Draft/HOLD instructions below describe their original
qualification checkpoints, not today's implementation availability. The separate
[Gentek-80 evaluator](../operations/gentek80-evaluation.md) remains a
source-qualified evaluation workflow; its PR and physical owner acceptance are
not implied by the catalogue's presence on main.

The normal route is **Shared Workbench → New from generator → Architectural
Generator**. A bounded declarative project compiler plans one to five style
zones; native GEN-007 produces the material geometry. Preview is separate from
the live World. Explicit installation uses the prepared World transaction;
The form’s **Save…** stores the generation recipe, while **Save start** saves the
installed authored start and supported edits. The
[practical guide](../operations/architectural-generator-playtest.md) covers those
distinct operations.

| Term | Meaning in the current authoring path |
|---|---|
| Gentek | A named native architectural generator/sampler, such as Cathedral Megaframe. |
| Variant | A variation of a Gentek's geometry or parameters; it is not necessarily a separately versioned native module. |
| Preset | A saved parameter/material configuration. The menu has 93 built-in presets: 13 earlier presets plus 72 CLASSIC and eight advanced Genteks. |
| Composition | A bounded project combining up to five configured styles and their assigned zones into one native recipe and World. |

These author-facing terms do not rename serialized fields: the project still
stores `styles`, and native modules retain their explicit `module_version`.
SWARM negotiation and self-assembly are separate pending work. Native geometry
alone does not establish structural load capacity or physical playfeel.

Source owners are
[`architectural_generator_project.gd`](../../godot/scripts/architectural_generator_project.gd),
[`architectural_generator_dialog.gd`](../../godot/scripts/architectural_generator_dialog.gd),
[`world_generation.cpp`](../../native/src/world_generation.cpp) and
[`CyberWorldGenerator::get_catalogue`](../../godot/native_extension/cyber_world_generator.cpp).
The [80-style integration research](../operations/gentek-showcase-integration-001.md)
retains exact source and image provenance from the original qualification.

The [dated local qualification record](../audits/2026-11-14-architectural-generator-local.md)
retains source identities, numerical comparisons and original native previews.
The [15 November runtime completion record](../audits/2026-11-15-gen007-runtime-completion.md)
separately binds the integrated source, actual Windows/Linux execution,
retained libraries and independently verified Windows owner package.

## 80-Gentek integration candidate — 20 November 2026

**Historical integration checkpoint, subsequently accepted through #691.**
The `integration/gentek-80-001` candidate started from accepted main `de109d01`
and reconciles repaired CLASSIC `e27ff757` with the eight-showcase aggregation
`eb786d97`. It added **80 Genteks (72 CLASSIC and eight advanced showcases)**
without removing the thirteen accepted presets: the ordinary form has **93
selectable presets**, while native metadata has **91 module/version entries**.
All additions use the existing schema-4 native project path and single World.
The [evaluation guide](../operations/gentek80-evaluation.md) describes selection,
controls, source-bound packaging and the manual Test It procedure.

Each of the five style cards has a **Find style** filter matching name, family
and theme. Filtering keeps the current selection available, changes no project
parameters, and uses stable catalogue identities when a filtered item is chosen.
Clearing it restores the full list. The existing geometry, global apertures,
material-role imports, preview/Stop, explicit install and authored-start saving
retain their ordinary ownership.

Suspended Deck carrier contacts and steep Rib Vault cardinal continuity use
the repaired CLASSIC definitions. Showcase imports cannot replace these with
older equivalents. Catalogue/schema contracts enumerate the expected identities
independently; repaired-parent material oracles are measured from isolated
`e27ff757` source. Arched Viaduct v1/v2 and the other accepted geometry versions
remain unchanged. Generator inputs use the accepted material catalogue.

The integration's visual review additionally found four inherited support
defects. Ring Pier now joins its open diamond to both decks; Tripod Frame has
continuous transfer support between tiers; Cascade Terrace has a rear core
behind its staggered platforms; Scalloped Vault uses a local slope-aware stroke
to keep thin quadratic ribs connected. Suspended Deck and Buttress Wall keep
their complete existing glass panes and add frames connected to their structure.
These six deliberate refinements have explicit before/after references; the
remaining 66 CLASSIC definitions retain their authoritative material output.
None of these checks asserts engineering load capacity.

Gallery exporters compile every translation unit afresh in private directories
keyed by source and compiler identity. `--no-build` validates driver, frontend,
assembler/linker, version, target, environment, source/flags and executable hash.
A compiler switch or missing/mismatched record is refused rather than relabelled.
The separate compiler-switch regression uses real GCC 13 and GCC 14.
This enforcement covers the gallery exporters and qualification runners; it
does not change the repository's general Make cache behavior.

The candidate's dedicated qualification runs native and sanitized suites,
520 native-material captures, eighty independent process replays and 240 invalid
input cases. Real Workbench author/reopen exercises each of the eighty styles,
normal paint/erase, a native simulation tick and saved-start reconstruction.
Windows also repeats the Workbench campaign from an independently extracted
self-contained package. Exact execution outcomes, timings, source identities and
remaining failures belong to the [integration record](../research/gentek-80-integration-001.md)
and retained artifacts. These are requirements until their recorded run passes;
this paragraph does not assert an unexecuted gate.

The integration branch was **Draft / HOLD** at this checkpoint; #691 later
merged its catalogue into accepted main. SWARM, negotiated boundaries and
self-assembly remain excluded from this accepted contract. No shared Workbench, actor/Rapier, simulation,
material-publication or camera implementation is changed by this integration.

## Compatibility and native identity

Recipe schemas 1, 2 and 3 retain generator algorithms 2, 3 and 4 respectively.
Their defaults and Arcology/Vault module-v1 sampling are retained. The new
**recipe schema 4 / generator algorithm 5** explicitly admits architectural
controls and **Arcology v2 / Vault v2**. Both native fingerprints and generation
receipts distinguish these versions and resolved controls. Selecting schema 4
does not claim that its different identity is interchangeable with a saved
legacy fingerprint, even where the resulting material cells happen to agree.

The existing typed-spatial fingerprint includes its conservative preparation
memory ledger, which uses C++ structure sizes. Consequently libstdc++ Linux and
libc++ Windows can have different native fingerprints/receipts for the same
canonical recipe and identical material output. This implementation preserves
that legacy identity rule. Qualification compares complete receipts against an
independently built accepted base on the **same platform**, and compares canonical
recipes/materials separately across platforms. Generated-start v1 checks those
receipts on reopen; moving a saved typed map between differing runtime ABIs is
not a supported portability claim. A future identity correction would require
an explicit version and migration policy.

```json
{
  "schema": 4,
  "seed": 161803,
  "candidate": "district_grammar",
  "architecture": {
    "version": 1,
    "automatic_tunnels": false,
    "automatic_doors": true,
    "door_width": 0
  }
}
```

`door_width: 0` retains the District candidate's derived opening size. Explicit
positive widths are 2–64 cells and must fit the room. Module geometry has its own
fixed aperture width. Module-v2 `automatic_doors` can override or inherit the
recipe control; the native compiled identity records the resolved value.
Module-v2 windows are independent numeric 0/1 parameters. JSON architectural
booleans themselves are strict booleans, not numeric aliases.

| Control | Native mechanism | Off behavior |
| --- | --- | --- |
| Automatic tunnels | Non-Strata candidate macro-network and its route context | Suppresses only the automatic late network carving. Explicit `paths`, hard material overrides and semantic passages retain their precedence. No connected-network claim is made. |
| Automatic doors | District room lattice and Arcology/Vault v2 openings | Keeps wall material at automatic door apertures. Explicit semantic routes remain explicit; final material blockers still report conflicts. |
| Automatic windows | Arcology v2 façades and repeated bay partitions | Replaces both glass and window apertures with structural wall material. Floors, independent doors and service shafts retain their controls. |
| Corridor width | One globally owned macro-network | Changes the automatic route width; it does not size Vault maze openings. |

A doorway is a material aperture. No interactive door actor, hinge, lock or
simulation behavior is introduced. Strata's unrelated cave generation is not
controlled by Automatic tunnels.

## Fixed geometry and material parameters

Dimensions are integer cells. Geometry is fixed globally for the District
candidate or per prepared module instance, never varied independently at every
cell. Schema 4 rejects spatial changes to the District room/wall lattice; the
existing global-only `district_size` rule remains. Style composition uses
different module instances instead.

| Project control | Vault v2 | Arcology v2 |
| --- | --- | --- |
| `room_size` | `cell_size`, 12–128; must divide the prepared map dimensions, at most 64 rooms per axis | `bay_width`, 16–256 |
| `floor_height` | Inactive; recorded for interchange | 16–256 |
| `wall_thickness` | `wall`, 1–4 | `wall`, 1–5 |
| `door_width` | Exact opening width, 2–64 and within room clearance | Exact opening width, 2–64 and within bay/floor clearance |
| `shaft_width` | Inactive; recorded for interchange | 0 disables the shaft; otherwise 4–64, within the module shell |
| Material roles | Static wall and accent material | Static wall, floor, partition, accent, window and shaft material |

Native validation remains authoritative for material existence, solid capability,
geometry fit, module versions and preparation/raster limits. A configuration
which is syntactically valid as a project can still fail native admission with a
specific error. The installed World is untouched by that refusal.

### Owner-reviewed structural refinements (14 November 2026)

The Windows owner playtest accepted the three algorithms' visual contrast and the
five-column form. The following small refinements use new **native module v2**
identities. The original v1 samplers remain registered so saved v1 recipes
can reproduce their exact material outputs.

- **Skyline Terraces v2** uses Reinforced Concrete (58) in load-bearing walls
  instead of Rammed Earth (109). Frosted Glass (121) replaces the regular
  Glass Block (120), with glazing extended through the two-cell interior
  facade lip while retaining structural floor bands.
- **Cellular Hive v2** replaces straight modulo-X accent bars with Rusted Steel
  (65) reinforcement that follows the staggered six-sided chamber envelope.
  The builtin no longer exposes Ceramic Tile (70) in broad structural trim;
  Frosted Glass (121) appears only in defined window strips.
- **Arched Viaduct v2** replaces misaligned empty pier-foot cutouts with
  centred solid Steel Plate (62) load-bearing inlays. Arch profiles, original
  material contrasts and supporting decks are otherwise unchanged.

The owner accepted **Arched Viaduct v2** at source
`2ef35d46d7506b58f05a963c6ab3d650c1876da5` as the fixed visual reference.
Runtime publication and qualification repairs preserve that geometry and its
version identity; further architectural refinement requires separate scope.

**Material texture policy:** the shader renders material textures using
absolute world coordinates. Painting and pasting the same material therefore
exposes the same periodic pattern phase, but not an invisible simulation
layer. Prefer subtly textured or irregular materials for broad architecture
surfaces; reserve conspicuously periodic ones for small deliberate accents.
This change neither retimes world textures nor modifies material simulation
or copy/paste behavior.

## Three new native architectural geometry algorithms

The three additions are independently registered schema-4 native samplers,
not additional material skins on Arcology/Vault:

| Module | Preset | Geometry |
|---|---|---|
| `terraced` v1/v2 | Skyline Terraces | Stepped, receding floors, exposed ledges, staggered partitions and an optional service shaft |
| `hex_hive` v1/v2 | Cellular Hive | Staggered six-sided chamber cutouts within a solid web, with optional vertical connecting ports |
| `arcade` v1/v2 | Arched Viaduct | Repeated quadratic arch soffits, piers, elevated decks and optional pier apertures |

All sample from immutable prepared parameters in module-local coordinates,
without live World access, neighbor-chunk dependencies or mutable RNG state.
Door/window switches affect geometry independently; disabling automatic tunnels
suppresses the separate candidate macro-network but not each style's own voids.

The three built-in presets and a combined
`examples/worldgen/architectural/three-algorithms.project.json` showcase
the algorithms. A new native material gallery captures individual 512-square
renders and measures pairwise structural differences. The three original
styles and their resolved recipes are unchanged.

For four/five active styles, the project compiler explicitly raises its
maximum charged operations to 160 million per 128-cell chunk, within the
native 1-billion hard bound. One-to-three-style recipe identities retain
the existing default budget.

## Project and preset format

The compiler is
[`architectural_generator_project.gd`](../../godot/scripts/architectural_generator_project.gd).
Projects use `format: "cybersand.architectural-project"`, `version: 1` and
`planner: "connected-hilbert-v1"`. Their complete example is
[`three-style.project.json`](../../examples/worldgen/architectural/three-style.project.json).
It embeds a seed, signed source origin, square extent, zone scale, three global
aperture switches, corridor width and one to five style slots. Each slot holds
selection, requested percentage and a full preset definition.

Style presets use `format: "cybersand.architectural-style"`, `version: 1`, a stable
lowercase `id`, display `name`, `module`, explicit `module_version: 2`, a native
theme, geometry, material roles, optional aperture overrides and a bounded
`deterioration` fraction. The schema rejects unknown fields, unsupported versions,
non-finite values and executable content. No arbitrary scripts, dynamic native
libraries or external inheritance are loaded.

The default built-in examples are:

| Preset | Geometry | Material treatment |
| --- | --- | --- |
| Industrial Service | Vault maze, 32-cell rooms, 2-cell walls, 8-cell apertures | Steel Plate and Steel Grating |
| Habitation / Arcology | 64-cell bays, 48-cell floors, 3-cell walls, 12-cell doors, 16-cell shaft | Reinforced Concrete, Ceramic Tile, Frosted Glass |
| Overgrown / Ruined Construction | 96-cell bays, 64-cell floors, 3-cell walls, 14-cell doors, 10-cell shaft; coherent interrupted regions | Mossy Cobblestone, Moss Wall, Stained Glass |

The ruined style compiles an existing native value-noise field and band mask
into an Empty material modifier restricted to that style. Its deterioration
fraction controls a noise threshold, **not a promised percentage of removed
wall cells**. It can break traversal, support and windows by design. Automated
network routes, when enabled, are carved after these modifiers as before.

Additional selectable built-in styles are Civic Atrium, Transit Spine, Basalt Archive,
Solar Conservatory, Thermal Foundry, Earthen Terraces and Orbital Observatory.
They combine existing native module families with contrasting room dimensions,
solid materials, glazing, shafts and bounded deterioration. The original ten built-ins
have matching declarative JSON files under `examples/worldgen/architectural/`.
The existing three-style default and legacy native recipes are unchanged.

The authoring dialog now shows **five compact horizontal style columns**, no tabs.
The last two start disabled; enable them and use **Equal shares** to allocate 100%.
At typical desktop widths all five fit in a row; smaller windows can scroll.
Extended materials and aperture metadata are available on hover.

[`custom-masonry-court.style.json`](../../examples/worldgen/architectural/custom-masonry-court.style.json)
is a separate user-authored example: different bay/floor dimensions, masonry
materials, no shaft and an explicit window override. **Import style JSON** places
the complete validated definition into a selected slot. **Save…** writes the
complete validated authoring configuration to a temporary file and then uses
Godot's rename operation; **Load…** validates and restores the configuration.
This project writer does not establish preservation of an existing destination
for every I/O failure, despite the current failure message's broader wording.
Save to a new filename when the previous project must remain available.
The generated map itself stores the resolved recipe, so reopening never needs
the original project or external preset file.

## Zone allocation, quotas and guarantees

The prototype supports square 256, 512 and 1024-cell compiler regions; ordinary
Shared Workbench authoring uses 512 and 1024. The selected zone scale must divide
the extent and give a square 2, 4, 8 or 16-block grid per axis. Native GEN-003's
existing 256-block finite assignment bound is retained.

The preprocessor converts requested percentages to integer block quotas using
largest remainders; exact remainder ties use slot order. It refuses empty selected
quotas and deviations above **2 percentage points**. Selected shares must total
100%; percentages are never silently normalized. The 1024² / 64-cell example
contains 256 blocks:

| Style | Requested | Blocks | Assigned zone area |
| --- | ---: | ---: | ---: |
| Industrial Service | 45% | 115 | 44.921875% |
| Habitation / Arcology | 30% | 77 | 30.078125% |
| Overgrown / Ruined Construction | 25% | 64 | 25.000000% |

SHA-256 seed lanes determine a Hilbert traversal's reflection/transposition,
direction and style ordering. Consecutive intervals of this face-connected
traversal receive the quotas. Each selected style therefore has **exactly one
four-connected component on the finite allocated grid**. This guarantees neither
convexity nor minimum width, doorway connectivity, player clearance or a connected
material floor plan. The finite family of transformed interval layouts is an
intentional prototype limit, not a general shape/contiguity optimizer.

The result compiles into the existing native `assigned_region` declaration with
singleton category domains and all-category reciprocal adjacency. Native
preparation still validates and budgets this plan. Category masks select prepared
modules; there is no second rasterizer, per-cell room-size modulation or material
rectangle repair pass. Arcology instances use their zone's bounding rectangle;
Vault prepares one finite full-map maze and is clipped by the zone mask. Cropped
maze connectivity is not asserted with tunnels off. Boundaries can leave partial
rooms and are intended for further owner painting.

The same seed, project and source coordinates produce identical masks and native
materials regardless of chunk request order or work slicing. All counters refer
to **assigned zone blocks**, including Empty space, and never occupied-material
area. The optional colored overlay is diagnostic; the native material preview
remains the installed play-plane authority. Spatial assignment repetition outside
the tile does not expand the finite authoring project: module/modifier bounds
restrict style application to the selected source region.

## Transactional preview and persistence

Every regeneration has a fresh attempt/revision. Changing a seed, preset,
dimension or share invalidates installation until a new complete preview is
accepted. Failed or cancelled proposals retain one prior verified proposal with
its settings; **Restore previous preview** explicitly recovers it. A dirty form
cannot silently install old bytes. Incremental native jobs do not publish partial
terrain into the live Workbench.

Installation remains the explicit owner-confirmed World replacement boundary.
Native preparation, copied cells, materials, receipt/source checks and the
existing actor/physics ownership remain unchanged. The `cybersand-generated-start-v1`
manifest and its nested Setup format are unchanged. The canonical resolved native
recipe and source material hash are retained and checked again in a fresh
process, then ordered paint/erase edits are applied. No regeneration is rebased
under existing painted content, and no Flatten/Bake behavior is added.

## Qualification and limits

The focused native regressions extend `make worldgen-test`; the separate
[`tools/architecture/`](../../tools/architecture) harness exercises actual native
materials, legacy identities, compiler validation, three seeded 1024² outcomes,
toggle deltas, independent component counting, geometry-only comparisons,
negative coordinates, cancellation, stale state and separate-process authoring
reconstruction. Actual timings and original captured material PNGs are retained
with runtime/source identities. They are native-material captures; headless PNGs
are not graphical Windows acceptance.

The [architectural qualification workflow](../../.github/workflows/architectural-generator-qualification.yml)
builds source-matched Linux and Windows extensions and uses the existing
standalone Workbench packaging path. Its graphical campaign covers all five
style cards, sparse enabled slots 1/3/5, native preview/install, normal and
multistyle author/reopen, edit ordering, legacy material equivalence, and GEN-008
Flatten author/reopen with native-owner failure recovery. The Windows owner ZIP
is independently extracted and replayed; Flatten uses a separate pristine
extraction. These checks preserve the accepted Flatten contract rather than
adding a second Flatten implementation to the generator.

Routine coverage survives the feature branch: the broad
[GDExtension workflow](../../.github/workflows/gdextension.yml) discovers the
architectural native-material, project-contract and UI test scripts on Linux
and Windows, while [Native CI](../../.github/workflows/native.yml) runs the
native generation suites. The architectural workflow also runs its bounded
publisher-guard tests on pull requests and `main` pushes. The expensive full
graphical/package campaign remains restricted to feature-branch pushes or an
explicit workflow dispatch. Headless regression coverage and publisher unit
tests do not replace the full graphical publication campaign.

### Retained runtime publication

**Published on the PR branch, 15 November 2026:** qualified source `6d6e2cd6`
produced four-file publication `99d7bd2b`. Both retained libraries were downloaded
from Git LFS and verified against their committed pointers, manifests and
validated artifact bytes. Their manifests carry matching 93-native-input and
814-build-input ledgers. The completion record above owns the exact identities
and target-OS results; final-head broad CI remains in the PR evidence ledger.

The owner-authorized repair publishes the source-matched Linux SO, Windows DLL
and their two provenance records **on the existing PR branch**. It supersedes
the earlier source-only merge proposal. The
[publisher](../../tools/ci/gen007_architectural_runtime_publication.py) admits both
platforms only after the graphical, native, persistence, legacy and package
checks above pass. Each acceptance report carries the native source-input
ledger and source tree from its verified build manifest, and the independent
bundle verifier checks them against the execution identity and retained
receipt hashes. Missing or mismatched source evidence fails publication.

The write is limited to the four runtime/provenance paths and requires an
unchanged branch tip. A successful build or downloadable evaluation ZIP alone
does not establish retained-runtime publication. After the four-file commit,
the new PR head still needs fresh Documentation/provenance, palette backend and
all applicable broad repository checks. No source-provenance exception, merge
or automatic approval is part of this path.

Windows owner evaluation must independently inspect actual layout, interactive
controls, paint/erase and save/reopen. No general architectural solver,
variable-size room packing, semantic route generator, automatic edit rebase,
streaming World, camera optimization or agent authoring is included.
