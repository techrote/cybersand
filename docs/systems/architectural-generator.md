---
title: Architectural Generator Phase A and B
status: Current
document-kind: contract
scope: Opt-in schema-4 architectural controls, module-v2 apertures and bounded three-style project compilation
canonical-for: [architectural-generator-controls, architectural-style-projects, architectural-zone-coverage]
keywords: [architecture, GEN-007, styles, zones, coverage, tunnels, doors, windows, Hilbert, Arcology, Vault]
last-reviewed: 2026-11-14
related-documents: [procedural-world-generation.md, procedural-typed-spatial-fields.md, procedural-hierarchical-generation.md, generation-workbench-2.md, explore001-generated-playable-maps.md, ../operations/architectural-generator-playtest.md]
---

# Architectural Generator — Phase A and bounded Phase B

The implementation is an opt-in initial-map authoring capability in **Shared
Workbench → New from generator → Architectural Generator**. A small declarative
project compiler plans finite style zones; native GEN-007 produces every terrain
cell. The ordinary generated-start preview, confirmed World replacement, painting
and recipe-based save/reopen remain the authority. This source contract describes
the candidate; platform execution and owner acceptance belong to its dated
qualification report and Draft PR.

The [dated local qualification record](../audits/2026-11-14-architectural-generator-local.md)
retains source identities, numerical comparisons and original native previews.

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

## Project and preset format

The compiler is
[`architectural_generator_project.gd`](../../godot/scripts/architectural_generator_project.gd).
Projects use `format: "cybersand.architectural-project"`, `version: 1` and
`planner: "connected-hilbert-v1"`. Their complete example is
[`three-style.project.json`](../../examples/worldgen/architectural/three-style.project.json).
It embeds a seed, signed source origin, square extent, zone scale, three global
aperture switches, corridor width and one to three style slots. Each slot holds
selection, requested percentage and a full preset definition.

Style presets use `format: "cybersand.architectural-style"`, `version: 1`, a stable
lowercase `id`, display `name`, `module`, explicit `module_version: 2`, a native
theme, geometry, material roles, optional aperture overrides and a bounded
`deterioration` fraction. The schema rejects unknown fields, unsupported versions,
non-finite values and executable content. No arbitrary scripts, dynamic native
libraries or external inheritance are loaded.

The built-in examples are:

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

[`custom-masonry-court.style.json`](../../examples/worldgen/architectural/custom-masonry-court.style.json)
is a separate user-authored example: different bay/floor dimensions, masonry
materials, no shaft and an explicit window override. **Import style JSON** places
the complete validated definition into a selected slot. **Save project** and
**Load project** atomically save/reload the embedded authoring configuration.
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

The opt-in qualification workflow builds source-matched Linux and Windows
extensions and uses the existing standalone Workbench packaging path. Draft/HOLD
remains in force. Windows owner evaluation must independently inspect actual
layout, interactive controls, paint/erase and save/reopen. No general architectural
solver, variable-size room packing, semantic route generator, automatic edit
rebase, streaming World, camera optimization or agent authoring is included.
