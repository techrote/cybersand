---
title: Cathedral Megaframe classic Gentek showcase
status: Current
document-kind: research
scope: One version-1 hierarchical sampler and source-matched native-material qualification, stacked on CLASSIC-001
canonical-for: [cathedral-megaframe-showcase]
last-reviewed: 2026-11-16
related-documents: [gentek-classic-001.md, ../systems/architectural-generator.md, ../systems/procedural-world-generation.md]
---

# GENTEK-SHOWCASE-CATHEDRAL-001 — Cathedral Megaframe

**Draft / HOLD research.** This independently owned showcase starts from parent
PR #624 at `615828b28337f85e4663e03ba479616db4ddf764`. Its branch is
`experiment/gentek-showcase-cathedral-001`, targeting
`experiment/gentek-classic-001-20261115`. The parent and the sibling showcases
remain independently reviewable. No merge or Ready promotion is authorized.

The hypothesis is that one immutable coordinate sampler can coordinate four
spatial scales into monumental, readable architecture. This is the existing
GEN-007 schema-4 contract: `cathedral_megaframe` **v1**, an ordinary
`cybersand.architectural-style` preset named **Cathedral Megaframe**, the existing
five-card generator, and ordinary preview/install/save/reopen. It introduces no
new renderer, material, physics, graph editor, neighbour access or assembly system.

## Architectural grammar

Let **B** be `room_size` (native `bay_width`), **L** be `floor_height`, and **w**
be `wall_thickness` (native `wall`). One supercell is **4B × 3L**. The source
names each coordinate level in `CathedralMegaframe` in
`native/src/generation_architecture_classic.inc`:

| Scale | Coordinates and extent | Architectural responsibility |
| --- | --- | --- |
| Superstructure | `cell_x`, `cell_y`, `mx`, `my`; 4B × 3L | A whole monumental frame, seed scope, shared boundaries |
| Primary bays | Centre 2B, half-span 3B/2; crown L/2, spring 7L/4 | Thick pointed arch, tall piers and a large protected nave |
| Secondary architecture | Side aisles B/2–3B/2 from each edge; pitch B/2 | Four subsidiary arcades, triforium at 2L, side gallery at 3L/2 |
| Tertiary detail | Clerestory pitch B/3 or B/4; balustrade pitch B/8 | Framed lancets, narrow inner ribs, ledges and short posts |

The nave occupies the central bay and remains open down to the bottom deck.
Secondary galleries stop at supported arcade piers; no ordinary deck fills the
central volume. The primary piers extend through the supercell ceiling to meet
the preceding supercell's floor. Side buttresses widen in steps toward the base;
curved flying members join their upper mass to the principal piers. These are
geometric load-path cues, not a structural-engineering simulation.

The pointed arch uses a bounded integer lens inequality, rather than a bitmap
or square-root lookup. For horizontal distance `dx`, half-span `r`, rise `h`,
and height `dy` above the spring, the inside condition is
`3*r*r*dy*dy + h*h*(dx+r)*(dx+r) <= 4*r*r*h*h`, with explicit lateral and
vertical bounds. The difference between two nested lenses makes a thick rib;
a smaller pair creates the intermediate order. The inner aperture contracts by
one raster column, ensuring adjacent columns overlap even at the admitted
22-cell-wide / 256-cell-tall limit. Curved flying members similarly cover the
interval through the next column. These are bounded analytic raster rules, not
neighbour-cell reads. All products remain within
signed 64-bit arithmetic for the admitted dimensions. There is no iteration,
allocation, mutable cache or World query inside `sample()`.

## Parameters and material roles

The starting preset uses **72 / 96 / 5** for B / L / w, door width 12, no
service shaft, the existing `ruins` theme, Marble (98), Brass Panel (119), and
Frosted Glass (121). The existing style compiler maps the
floor selection to both native deck and accent roles; this showcase preserves
that schema. Direct schema-4 recipes can still specify the existing separate
`accent_material` native parameter.

| Existing control | Cathedral response |
| --- | --- |
| Room size | Changes the four-bay span, side-arcade pitch, pier spacing, glazing and balustrade cadence |
| Floor height | Changes the three-storey period, arch rise, two side datums and high clerestory zone |
| Wall thickness | Changes primary mass, smaller ribs, frame widths and deck thickness |
| Automatic windows | Replaces clerestory glazing with shell when disabled; occupied/empty geometry is identical |
| Automatic doors | Opens or fills pointed portals in the lower boundary buttresses; main nave and primary piers remain intact |
| Service shaft | Retains the existing explicit straight shaft cutout; the showcase preset disables it |

Both B and L must be at least `6*w + 16` cells, within the existing maximum of
256. This protects secondary aperture clearance instead of silently collapsing
the design at small dimensions. The existing project validation reports the
same guard as native admission. The edge campaign exercises B=L=46, w=5,
exactly on this bound. Portal width is bounded by the available buttress mass;
the mandatory nave does not depend on the automatic-door switch.

## Seed scope and determinism

Lane 7301 hashes `(recipe seed, supercell X, supercell Y)` to select a grouped
clerestory rhythm and which side receives the longer upper gallery. Lane 7302
hashes `(recipe seed, boundary X, supercell Y)` to select tower height. Both
neighbours use the same boundary key, so independently sampled halves of a
shared tower agree. The frame's identity, central void, and major pier positions
are invariant under those choices. There is no per-cell random noise.

Signed floor division and positive modulo derive all local coordinates from the
module origin. A chunk merely asks for coordinates; it supplies no architectural
state. Sampling order, work slices and request order cannot influence any seed
choice. The existing compiler's global module anchor preserves the same phase
across style-mask chunks. Irregular style masks retain the existing clipping
behaviour; Cathedral does not negotiate joins between Genteks.

## Qualification and retained evidence

The native test extends the complete 72-member CLASSIC catalogue to **73**,
without lowering its occupied/void or distinctness gates. An independently
compiled parent snapshot supplies a frozen aggregate identity for all original
72 samplers and individual Viaduct v1/v2 hashes. Showcase checks cover chunk
seams, nested frequencies, major void, controls, at least four seeds, replay,
signed origins, reversed chunk order/receipts and work slicing.

`godot/tests/test_gentek_cathedral_showcase.gd` obtains actual material IDs from
`CyberWorldGenerator` and reuses the existing material LUT preview function.
It retains at least sixteen Cathedral maps, a 512 and 1024 hero, four seed
arms, dimensional/mass/aperture controls, an edge case, two literal detail crops,
and Arched Viaduct / Pointed Arcade / Basilica comparisons. Every full PNG has
its original material bytes, recipe, project and native receipts beside it.
The 1024 map remains available independently of the crops.

The source ledger snapshots build and execution inputs before compilation,
checks those bytes after capture, binds the executed extension SHA-256, and
hashes retained outputs. The isolated workflow
`.github/workflows/gentek-cathedral-showcase.yml` executes on the Cathedral
branch while it remains Draft; it cannot write to the parent branch.
Exact campaign counts, timings, visual findings and the independent final
verdict are recorded in the PR evidence comment and artifact manifest.

Reproduce the native checks with `make -j2 worldgen-test`. Run the source-built
extension with `CYBERSAND_ARCHITECTURE_OUTPUT` pointing to the evidence directory
and Godot's `--headless --path godot --script
res://tests/test_gentek_cathedral_showcase.gd`. The workflow records its complete
pinned toolchain commands. Local iteration does not substitute for final source
and runtime identity or owner aesthetic acceptance.

## Reusing the pattern

A future author should first name the supercell and reserve its major empty
volume. Derive primary axes from that cell; make each smaller rhythm subordinate
to a structural region. Use material precedence deliberately: portals, bearing
mass, primary ribs, framed glazing, secondary arcades, galleries, then small
attached details. Give every repeated boundary one owner/key. Bound each seed
decision to an architectural choice with known support and clearance.

Test the generated material topology and visual hierarchy as well as its hash.
A deterministic slab is still a slab. Separate occupied-mask preservation from
material replacement, compare dimensions independently, and inspect both close
details and complete maps. Keep the sampler comprehensible enough that its
coordinates teach the pattern directly.
