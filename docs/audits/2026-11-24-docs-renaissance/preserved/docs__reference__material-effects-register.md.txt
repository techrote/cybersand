---
title: Material effects register
status: Current
document-kind: reference
scope: Register of presentation effects — implemented (Current), planned, potential and rejected — with stage, materials, inputs, motion, cost class and evidence
canonical-for: [material-effects-register]
last-reviewed: 2026-10-18
related-documents: [../systems/material-visual-pattern-library.md, ../systems/material-appearance-and-rendering.md, ../systems/building-material-catalogue.md, status-and-roadmap.md, ../audits/2026-10-18-material-readability-pass.md, ../audits/2026-10-18-material-fidelity-pass-2.md]
---

# Material effects register

The single list of material presentation effects and their status. Recipes and
design guidance live in the
[pattern library](../systems/material-visual-pattern-library.md); semantics and
cost live in the [appearance contract](../systems/material-appearance-and-rendering.md);
dated evidence is in the
[2026-10-18 review](../audits/2026-10-18-material-readability-pass.md).

Statuses follow the [documentation contract](../operations/documentation-maintenance.md):

- **Current:** implemented in source.
- **Planned:** intended future work.
- **Potential:** considered but not scheduled.
- **Rejected:** declined, with a reason.

Cost class is relative per-pixel work: **A** means arithmetic only; **R*n*** means
up to *n* extra texture reads. "Since" names the pass that introduced or last
reshaped the effect:

- **base:** before 2026-10-18.
- **P1:** readability pass.
- **P2:** detail pass.
- **P3:** volume and contact pass.
- **P4:** shape-aware pass.
- **P5:** every static material.
- **P6:** second fidelity pass (MAT-002, [record](../audits/2026-10-18-material-fidelity-pass-2.md)).

## Implemented (Current)

### Pipeline and infrastructure

| Effect | Stage | Notes | Cost | Since |
|---|---|---|---|---|
| Palette atlas plus condition program LUT | LUT | 64 variants per row; tint, value, alpha and emission curves | 3 reads | base |
| `presentation_time_override` on palette and emission | all | Fixed-phase captures; default keeps `TIME` | A | P1 |
| Snapshot-coherent relief and crossfade | relief | Each side uses its own neighbourhood | 4 reads, shared | P1 |
| Shared neighbour gather | colour | One gather feeds finishes, volume/contact and relief | 4 reads | P3 |
| Run-length extent (`region_extent`) | structured | Probes 1, 2, 3, 5, 8 per direction | R16 | P4 |
| `structured_detail` quality hook | structured | Uniform; 0 disables shape-aware fills. Not yet exposed in UI | — | P5 |
| Shared glow setter (`set_glow_enabled`) | controller | Desktop/Web `G`, initialization, restore | — | P1 |
| Half-resolution emission plus additive composite | glow | 13 source samples (centre takes the brightest of its 2×2 cells since P6) and 13 composite taps | fixed | base/P6 |
| Vapour afterimage buffer | trail | Two half-float view-sized viewports ping-pong once per frame; `vapour_trail_strength` | 1 read per Empty pixel | P6 |
| `growth_decor` quality hook | Empty | Uniform; 0 disables growth decor | — | P6 |

### Liquids

| Effect | Materials | Inputs | Motion | Cost | Since |
|---|---|---|---|---|---|
| Swirled ripple and micro-glints | Water, Brine | — | yes | A | base/P6 |
| Caustic net | Water, Brine | — | yes | A | P2 |
| Rising micro-bubbles | Water, Brine | — | yes | A | P2 |
| Fixed salt motes | Brine | — | — | A | P1 |
| Water coverage modes (#19) | Water | mass | — | R4 (oriented) | base |
| Depth shading | liquids | depth | — | R3 | P3 |
| Exposed-surface froth | liquids | neighbours | yes | A | P3 |
| Boiling beside heat | Water, Brine, Slush, Ice | neighbours | yes | A | P3 |
| Swirling marbled slick, contour iridescence (replaces the wave/streak bands) | Oil | — | yes | A | P6 |
| Burning flames | Oil | burn | yes | A | P2 |
| Heavy clumps and slow swirled swell | Paste, Cement | Cement cure | slow | A | P1/P6 |
| Icy granules, twinkling crystals | Slush | — | slow | A | P1/P2 |
| Swirling chemical eddies, bubbles, fizz, froth; darker sludge with filaments | Acid, Toxic Sludge | — | yes | A | base/P6 |
| Etching fizz on solids | Acid, Toxic Sludge | neighbours | yes | A | P3 |
| Swirling liquid-metal reflections and pin highlights (replaces bands) | Mercury | — | yes | A | P6 |
| Crust plates, seams, pops | Lava, Molten Glass | heat | yes | A | P2 |
| Depth heat, molten skin, water flashes | Lava, Molten Glass | depth, neighbours | yes | R3 | P3 |

### Fire, gases and atmosphere

| Effect | Materials | Inputs | Motion | Cost | Since |
|---|---|---|---|---|---|
| Heat-ramp flame tongues | Fire | lifetime | yes | A | P2 |
| Edge cooling; flare on fuel | Fire | neighbours | yes | A | P3 |
| Flicking sparks | Fire | — | yes | A | P2 |
| Crackling white core | Spark | lifetime | yes | A | P2 |
| Advected billows, rims, soot; last lifetime thins from the wisps | Smoke | lifetime | yes | A | P2/P6 |
| Near-white rising plumes, condensation glints | Steam | lifetime | yes | A | P2/P6 |
| Fading afterimage of moved or vanished vapour | Empty | vapour buffer | yes | 1 read | P6 |
| Coloured sparks beside a flying firework | Empty | Rocket flight | yes | R4 for candidates | P6 |
| Grass, flowers, leaves, mushrooms, hanging vines and hyphae | Empty | Plant, Moss Wall, Fungus nearby | sway, glow | R7 + R6 | P6 |
| Bubble rims, small bubbles, speculars, pops | Foam | lifetime | yes | A | base/P2 |
| Soft gas and foam boundaries | Smoke, Steam, Foam | neighbours | — | A | P3 |
| Embers above hot or burning cells | Empty | sources below | yes | R3 for candidates | P2 |
| Fumes above Acid and Sludge | Empty | sources below | yes | R2 for candidates | P2 |
| Steam leaks above pipe runs | Empty | pipes below | yes | R2 for candidates | P4 |
| Ambient occlusion beside solids | Empty | neighbours | — | shared | P3 |

### Emissive and manufactured

| Effect | Materials | Motion | Cost | Since |
|---|---|---|---|---|
| Hue-rebuilt striations, centred core, plasma, ballast fault | Neon cyan, magenta, amber | yes | R16 | P2/P4 |
| Bezel and generative scrolling display (LUT emission halved) | LED White | yes | R16 | P5 |
| Truchet circuit traces and pulses | Cloner | yes | R16 | P5 |
| Charged arcs and arc sparks | Metal | when charged | A | base/P2 |
| Restrained travelling glints | Steel Plate, Painted Steel, Corrugated, Pipes | sparse | A | base |
| Emitter rim light on adjacent solids and powders | solids, powders | no (follows emitters) | shared | P3 |
| Mycelium web, fruiting knots, bioluminescent pulses | Fungus | yes | A | P2/P6 |
| Jittered leaf clusters, midribs, sway | Plant | yes | A (cell field, 9 cells) | P6 |
| Iridescent glistening chitin | Mite | yes | A | P6 |
| White-gold flickering core with HDR bloom | Rocket (flight state ≥ 1) | yes | A | P6 |
| Fluorescent glow / breathing afterglow | Uranium Glass, Phosphor Panel | phosphor | R16 | P6 |
| Fibre-optic data pulses | Cable Bundle | yes | R16 | P4 |
| Moving conveyor with rollers | Rubber (thin runs) | yes | R16 | P5 |
| Tank fill line and rising bubbles | Chemical Glass | yes | R16 | P5 |

### Static construction (shape-aware unless noted)

| Effect | Materials | Since |
|---|---|---|
| World-anchored wet film over a solid substrate; puddle sheen on top | Wet Asphalt, Wet Cobblestone | P1/P5 |
| Time-independent sheens, fractures, frozen bubbles (flair) | Glass, Chemical/Dark Glass, Ice | P1/P2 |
| Frames, mullions, reflected lit windows | Glass, Dark Glass | P5 |
| Frosted top, icicles carved into undersides | Ice | P5 |
| Brick chips and grime; soldier course and quoins | Wall/masonry; Red, Industrial Brick | P2/P4 |
| Block seams, caps, drips, machined edges | Wall, Concrete, Metal | P5 |
| Ashlar caps, quoins, drips, bedding, flecks | Limestone, Sandstone, Granite | P5 |
| Polished tops, moss on tops and joints | Cobblestone, Mossy Cobblestone | P5 |
| Spalling that reveals brick | Lime Plaster | P5 |
| Half-timbered posts, rails, braces | Wattle and Daub | P5 |
| Ridge binding, ragged eave fringe | Thatch | P5 |
| Ridge cap, eave shadow, lichen | Terracotta Tile, Slate | P5 |
| Balusters with collars and finials; riveted plate | Wrought Iron | P5 |
| Standing seams, bloom | Lead Sheet | P5 |
| Patina runs, polished/rubbed edges | Bronze, Copper, Verdigris | P5 |
| Strata, grassy top | Packed Earth | P5 |
| Tar-sealed cracks | Asphalt | P5 |
| Rivet rows, grime gradient, scratches, paint chips, rust runs | Steel Plate, Painted Steel | P2/P5 |
| Organic corrosion spills from edges and seams, perforation only inside corrosion | Rusted Steel | P5/P6 |
| Organic blotches, flaking scale, spill runs, clustered pits | Rust, Rusted Steel | P6 |
| 51 building finishes (woods, bark, stone, metals, glass, chemical/industrial) | IDs 81–131, see the [building catalogue](../systems/building-material-catalogue.md) | P6 |
| Frames, posts | Grating, Chainlink | P5 |
| Cylinder shading, flanges and bolts, couplings, patina | Steel Pipe, Copper Pipe | P4 |
| Diagonal stripes with trim; chevrons on strips; worn paint | Hazard Stripe | P4 |
| Quilted batts, stitches, foil faces | Insulation | P4 |
| Round cables with ties | Cable Bundle | P4 |
| Planks with staggered joints and nails | Oak Timber, Wood | P4/P5 |
| Ridges following the sheet run | Corrugated Steel | P4 |
| Voronoi leaded panes | Stained Glass | P4 |
| Bullnose trim | Ceramic Tile | P4 |
| Tie holes, exposed rebar | Reinforced Concrete | P4 |
| Tread plate (wide runs) | Rubber | P5 |
| Char with ember veins (burn progress) | Wood, Oak, Thatch | P2/P3 |

## Planned

| Effect or work | Why | Notes |
|---|---|---|
| User-facing quality tier | Cumulative world-pass GPU cost is about 6× the original in the effect scene (p95 ≈ 1.9 ms on a TITAN RTX) | Wire `structured_detail` and a reduced-noise path into desktop/Web settings; measure weaker GPUs and browser |
| Target-GPU and browser/WebAssembly measurement | Only one Windows/NVIDIA Compatibility profile is measured | Use the existing cost script; record per profile |
| Owner acceptance of the new finishes | Visual acceptance is the author's, not the owner's | Review the pattern-library plates in game |
| True GPU subregion uploads | Pre-existing Planned item in the appearance contract | Independent of these effects |

## Potential (considered, not scheduled)

| Idea | Value | Constraint or cost |
|---|---|---|
| Logical-resolution prepass (shade once per cell, upscale) | Cuts the 36× per-cell redundancy at 1080p; would pay for much richer fills | New render target and architecture change; needs a design decision |
| Region-anchored patterns beyond 8 cells | Panel-anchored stripes and signage | Needs longer probes or a prepass; capped extents today |
| Heat haze and refraction above fire and lava | Strong atmosphere | Needs sampling the rendered colour of other pixels (a second pass) |
| Coloured light spill over several cells | Neon and fire lighting walls further away | Glow halo partly covers it; true spill needs a light buffer |
| Water surface spray and droplets in Empty | Livelier water | No velocity input exists; must not invent motion state |
| Emission crossfade | Halo matches palette crossfade on disappearance | Would double emission sampling |
| Smoke lit by nearby fire | Volumetric feel | Neighbour classification over a wider radius |
| Rain and wetness overlays | Mood | Scene-level state, not a material property |
| Signage, stencils and decals | Readable environments | Needs per-region identity, or the Planned paint/decal layers in the [construction catalogue](../systems/themed-construction-materials.md#limits-and-authoring) |
| New construction materials (pipe elbows, vents, screens, rebar mesh) | More vocabulary | New native material IDs and a native runtime rebuild; P6 added 51 building materials (IDs 81–131) but not these |
| Orientation and variant channel | Authored direction per cell | Explicitly Planned elsewhere; changes the RG8 contract |

## Rejected

| Idea | Reason |
|---|---|
| Godot particle nodes or per-cell lights for effects | Violates the bounded, no-per-cell-object rendering rule; lattice pixel particles cover the need |
| ID-derived animation speeds | Arbitrary and misleading; named presentation constants instead |
| Time-varying sheens on still glazing, ice and wet construction | Sub-pixel crawl reads as noise on still scenery |
| Rare valve wheels on pipes | Read as rendering glitches |
| Using the condition byte as velocity, temperature or age for materials that project something else or zero | Breaks the material-selected projection contract |
