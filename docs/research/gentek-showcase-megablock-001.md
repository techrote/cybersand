---
title: Seeded Typology Megablock classic Gentek showcase
status: Current
document-kind: research
scope: Isolated Draft GENTEK-SHOWCASE-MEGABLOCK-001 source, deterministic local programme, interfaces and qualification; not accepted main
canonical-for: [seeded-typology-megablock]
last-reviewed: 2026-11-16
related-documents: [../systems/architectural-generator.md, gentek-classic-001.md, ../systems/procedural-world-generation.md]
---

# Seeded Typology Megablock

**Branch Current, Draft / HOLD.** This owner-authorized showcase stacks on
`experiment/gentek-classic-001-20261115` at exact parent
`615828b28337f85e4663e03ba479616db4ddf764` (PR #624). It adds
`seeded_typology_megablock` **v1** and the **Seeded Typology Megablock** preset.
It does not change the parent branch, import the Cathedral/Megatruss experiments,
merge, promote Ready, or claim accepted-main/physical Windows qualification.

## Research claim and architecture

An immutable classic sampler can select a **local architectural programme**,
not merely perturb a repeated motif. A 4-column × 4-band supercell is selected
from seed and module-local supercell coordinates. Every lot belongs to one of
nine cooperating families. One hash is evaluated for the supercell identity;
fixed bit choices select legal programme alternatives, and all finer rhythm
comes from local coordinates. There is no per-pixel random decision, heap
allocation in `sample()`, mutable preparation/layout cache, World query,
neighbouring chunk query, WFC, search or runtime negotiation.

The implementation has three visible scales: a 4-bay megablock, one bay per
architectural lot, and regular local mullions/ribs/knee members. Y increases
downward: band 0 is the crown, bands 1–2 are the middle architecture, and band 3
is the lower support band. This is a bounded deterministic grammar within the
existing GEN-007 schema-4 sampler boundary; it is not GENTEK-SWARM self-assembly.

## Programme and typology vocabulary

| Family | Programme placement | Native material expression |
| --- | --- | --- |
| Core | One full-height column chosen from four | Two substantial continuous rails, regular ribs and landing decks |
| Atrium | Interior column 1 or 2, always adjacent to core | Deliberately empty lot, with no generic floor through it |
| Bridge | One middle band of the atrium column | Mid-height deck, connected rail and supporting knee members |
| Buttress | Lower support opposite the core; optionally spare lower lot | Stepped side masses growing toward the base |
| Arcade | Always under the atrium; optionally spare lower lot | Quadratic masonry gateway and credible side piers |
| Open frame | Selected middle support/spare lots | Sparse edge piers, upper knees and common floor |
| Cantilever | Optional outer spare lot at bridge band | Partial deck and brace anchored toward a known inner support |
| Habitation | Guaranteed opposite the core in the other middle band | Continuous shell/floor, controlled glazing and regular mullions |
| Crown | Only top-band non-core/non-atrium lots | Asymmetric roof ridge, connected side legs and base deck |

For each supercell, the seed selects `core ∈ {0,1,2,3}`. Its interior atrium is
column 1 for core 0/2 and column 2 for core 1/3. The support is on the atrium's
other side (`2*atrium-core`), leaving one outer spare column. The seed then
chooses bridge band 1/2, support/spare alternatives, lower spare mass and roof
handedness. This guarantees the bridge has an actual core and a supported lot
on its two sides; it cannot randomly end in another atrium.

The private programme helper is shared with qualification tools solely to
report the actual chosen identities. Output-level tests independently check
material cells at the declared interfaces and protected void. It is not a new
production-facing API, recipe schema or diagnostic runtime format.

## Compatibility contract and guarantees

| Interface | Rule |
| --- | --- |
| Lower transfer slab | Every lower lot supplies the last `wall` rows of its band; slabs meet across horizontal supercells |
| Ordinary floor | Core/frame/habitation/support/crown floor at `floor_height-wall`; atrium and bridge omit it |
| Bridge attachment | Bridge deck and both adjacent landings share `band*floor_height+floor_height/2`, with `±wall` thickness |
| Cantilever attachment | Spare-column arm faces inward; its known neighbour exposes the same mid-height landing |
| Void termination | Adjacent frame/habitation/arcade/buttress pier doubles its wall thickness against an Atrium/Bridge identity |
| Glazing | Only habitation panels may become glass; windows off restores wall material |
| Lower gateway | Doors on opens the full arcade aperture; doors off restores masonry without removing piers or floors |
| Vertical supercell transfer | Full lower slab meets the next programme's continuous core; roof shapes remain local terminations |

For a **complete, unmasked supercell with `shaft_width=0`, no deterioration and
no later tunnel/path carving**, construction guarantees one continuous core,
one entire bay × floor-height empty middle lot, one bridge with real landings
on both sides, a full lower transfer slab, a habitation lot, lower support mass
and multiple typology families. These are geometry guarantees, not a structural
engineering or player-traversability certification.

Neighbour-aware treatment is deliberately **intra-supercell**. An outer logical
neighbour is a terminated interface; it is not falsely reported as a sampled
adjacent supercell. The universal lower slab is the cross-supercell contract.
There is no generic solver or arbitrary cross-Gentek seam negotiation.

Clipping at finite map/style boundaries, the existing optional service shaft,
deterioration and explicit late carving can remove guaranteed parts. A partial
crop is legal and deterministic, but cannot promise a whole core or atrium.
Qualification checks complete-supercell connectivity and separately rejects interior one-cell fragments in finite crops.

## Existing controls and preset

The builtin and standalone
[style JSON](../../examples/worldgen/architectural/seeded-typology-megablock.style.json)
use industrial materials: Reinforced Concrete 58, Steel Plate 62, Frosted Glass
121; room size 96, floor height 64, wall thickness 4, door width 12 and shaft 0.
Thus each complete macrocell is **384 × 256 cells**. Use one style at 100% and
turn automatic tunnels off to inspect the intact grammar in the existing
Architectural Generator. The normal preview/install/save pipeline is reused.
No UI, material catalogue, renderer or saved-map format is added.

| Existing control | Response |
| --- | --- |
| `room_size` | Lot width; supercell width is four times this value |
| `floor_height` | Lot band height; supercell height is four times this value |
| `wall_thickness` | Shared member width, piers, ribs, glazing frame and support mass |
| `automatic_windows` | Glass-to-wall substitution inside habitation only |
| `automatic_doors` | Opens/closes the substantial lower arcade gateway |
| `shaft_width` | Existing independent vertical carving; disables complete-support guarantees where it intersects |
| `door_width` | Retained/validated common style field; this family's major arch width derives from the bay, with no independent width response |

Native and project validation both require room size and floor height at least
`6*wall_thickness+12`, in addition to the common ArchitectureForm bounds. This
preserves protected clearances instead of silently collapsing them. No new
schema fields or controls are introduced. Crown/internal detail choices derive
from the programme rather than independent small-scale noise.

## Implementation map

| Path | Responsibility |
| --- | --- |
| `native/src/generation_megablock_programme.hpp` | Private finite programme and typology names |
| `native/src/generation_architecture_megablock.inc` | Immutable material sampler and shared interface geometry |
| `native/src/world_generation.cpp` | Schema-4 registry/admission and v1 builtin identity |
| `godot/scripts/architectural_generator_project.gd` | Existing preset list, validation and compiler mapping |
| `godot/native_extension/cyber_world_generator.cpp` | Advertises the new module's existing schema-4 requirement in the native catalogue |
| `godot/tests/test_architectural_project_contract.gd` | All 73 CLASSIC entries, accurate schema metadata and preserved legacy variants |
| `godot/tests/test_megablock_project.gd` | Standalone/builtin parity, controls, partial crops and clearance refusal |
| `native/tests/test_seeded_typology_megablock.cpp` | Determinism, parent-output oracles, geometry/interface checks |
| `native/tools/gentek_megablock_capture.cpp` | Actual native material capture, programme reporting and bounded timings |
| `tools/worldgen/gentek_megablock_campaign.py` | Fixed survey, PNG colour mapping, independent measurements and source ledger |
| `.github/workflows/gentek-megablock-draft-gallery.yml` | Branch-scoped Linux native/Godot and Windows material parity evidence |

The parent `generation_architecture_classic.inc` and
`generation_architecture_modules.inc` stay byte-identical. Their outputs are
also compared against an independently built exact-parent executable, not
inferred from the absence of edits.

## Qualification and visual campaign

The survey is predeclared as seeds **0–31**; the eight principal seed examples
are **0–7** and both heroes use seed **0**. The campaign writes real native
uint16 little-endian material maps, SHA-256 hashes, occupancy/connectivity/
protected-void statistics, typology programmes, timings and source-input hashes.
Python only measures cells and maps the existing material colour LUT to PNGs.
It does not invent or repair geometry. Every retained image has a matching
native material map and source ledger.

The campaign includes 512²/1024² heroes, eight seed examples, compact/large lots,
short/tall bands, thin/heavy structure, both aperture toggles, negative origin,
a landscape crop and four matched CLASSIC comparisons. Contact sheets make all
32 seeds available for visual inspection. The final evidence record and PR
comment bind actual results and retained PNGs to a source commit; figures are
not accepted until that matching execution exists.

Reproduce from the source root:

```text
make -j2 worldgen-test
make -j2 megablock-sanitize
python3 tools/worldgen/gentek_megablock_campaign.py --output build/gentek-megablock-gallery
Godot_v4.7-stable_linux.x86_64 --headless --path godot --script res://tests/test_megablock_project.gd
```

The PNG campaign needs NumPy and Pillow. Headless native/Godot tests do not
establish physical Windows display, gameplay feel or owner visual acceptance.
The inherited retained native libraries predate this showcase; this branch's
new module needs a source-matched rebuilt extension. CI produces that extension
for integration qualification, without silently rewriting parent runtime assets.

## Comparison and known limits

Cantilever Spine varies alternating platform direction; Staggered Balcony
varies balcony rhythm; Bridgehouse repeats gabled rooms over one bridge; Stacked
Arcade repeats arch tiers. Megablock changes which lots are cores, atria,
bridges, habitation and supports while retaining their shared datums and family
language. The matched images and material hashes separate that compositional
claim from a change of material palette.

The programme is finite and deliberately recognizable. The four-by-four scale,
one core/atrium pair and recurring floor rhythms remain visible; this is not an
unbounded urban planner. Adjacent supercells have transfer slabs rather than
negotiated roof/core alignments. Arbitrary zone clips and later carving may
break support. Direct native benchmark ratios are host-specific, and full
Generator timing includes the common pipeline. No physical simulation stability,
traversable-world connectivity or fresh Windows owner package is asserted.

## Documentation change map

The architectural subsystem contract, documentation index, roadmap and retrieval
index route to this branch-scoped source contract. One additive retrieval
question set covers programme guarantees, parameter limits and the classic/SWARM
boundary without changing frozen queries. Ownership/lifetime, material schema,
renderer, physics, replay formats and UI layout are unchanged; their canonical
contracts need no new behaviour claims. Evidence/results belong in the separate
source-matched campaign record and PR ledger.
