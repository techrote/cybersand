---
title: 1024² material lab
status: Current
scope: Manual controls, executable material families, representative interactions, and finite-fixture boundaries
keywords: [material lab, Sandspiel, controls, medieval, castle, cyberpunk, factory, static solid, neon, 1024]
related-documents: [research/sandspiel-performance-and-material-port.md, systems/materials-and-rule-kernels.md, systems/themed-construction-materials.md, systems/material-appearance-and-rendering.md]
last-reviewed: 2026-09-08
implementation-state: The 1024² finite native fixture exposes 79 paintable materials, including IDs 38–80 for themed construction; native Linux/Windows builds, grouped selection, GPU flair programs, and bounded rule kernels are Current.
---

# 1024² material lab

Scope: the desktop manual scene selected by [project.godot](../godot/project.godot),
its [main.gd](../godot/scripts/main.gd) controller, and the
[native adapter](../godot/native_extension/cyber_native_cell_world.cpp). Web uses
a separate [controller](../godot/scripts/web_demo_controller.gd), five demo
choices, quality/menu controls, and CYSD1 level saves; desktop shortcuts below
are not a Web-control contract. See the
[2026-09-08 audit](audits/2026-09-08-documentation-audit.md) for local source
identity and dated runtime evidence.

## At a glance

- **Current**: the manual fixture is 1024×1024, aligned to 64 native 128×128 storage chunks.
- **Current**: logical render size and simulation margin are independently selectable.
- **Current**: 79 materials can be selected without treating paint slots as material IDs.
- **Current**: Shift+Q/E jumps between the core/reactive, medieval, industrial, and luminous groups.
- **Current**: 43 themed construction materials add castle/village and chemical-factory/alley vocabulary; 41 are inert radius-zero hard surfaces and Oak Timber/Thatch are combustible.
- **Current**: representative density, combustion, phase, corrosion, growth, replication, and agent interactions execute in native bounded kernels.
- **Current**: the 1920×1080 window aspect-fits every logical view and uses the same fitted rectangle for shader sampling and mouse-to-world mapping.
- **Current**: reactive hard-surface changes publish offset-indexed native chunk geometry; Rapier processes at most 32 queued chunks per rendered frame with a 750 µs budget checked between chunks. One rebuild can exceed that time budget.
- **Current**: eligible Fire motion targets 60 Hz, rendering defaults to interpolated 45 Hz snapshots with live 30/45/60 Hz comparison, and destructive ignition checks are distributed every 120 simulation ticks.
- **Current**: material colour and condition response come from GPU palette/program LUTs; native dirty RG8 patches update a persistent CPU image and a half-resolution HDR glow pass is optional.
- Sandspiel's MIT notice and provenance are retained; CyberSand Water deliberately uses its own conserved-mass solver.
- Streaming and production tuning remain Planned. Isolated benchmark/stress fixtures now exist; their dated coverage is in [Web threading](operations/web-threading.md), not a universal 1024² frame-time guarantee.

## Search anchors

material selector, Q E Page Up Page Down, aspect ratio, mouse mapping, view size, simulation margin, steam brine sodium, gunpowder coal, cement concrete, metal spark, mercury glass foam

The current sandbox is a finite 1024×1024 manual interaction fixture. It keeps
the 128×128 native storage chunks, 32×32 native activity blocks, and 64×64
phased scheduling cores used by the larger-world architecture. It does not add
streaming or choose a future maximum world size.

## Controls

| Control | Effect |
|---|---|
| Left/right mouse | Emit selected material / erase |
| `1`–`6` | Quick slots: Sand, Water, Wall, Smoke, Paste, Slush |
| `Q`/`E` or Page Up/Page Down | Cycle every paintable material |
| `Shift+Q`/`Shift+E` | Jump between core/reactive, medieval, industrial, and luminous groups |
| `V` | Cycle logical render view: 320×180, 480×270, 640×360, 960×540 |
| `B` | Cycle per-side simulation margin: 0×0, 32×36, 128×128, 256×256 |
| `L` | Toggle selected interest window / whole-world simulation |
| `C` | Toggle normal Water spray / 12-tick coherent emission |
| `T` | Toggle the current native Water surface-film comparison |
| `K` | Toggle temporal render smoothing |
| `H` | Cycle render publication at 30, 45, or 60 Hz; simulation remains 60 Hz |
| `F3` | Hide/show the debug statistics readout; hidden mode also skips periodic string construction |
| `G` | Toggle the downsampled material-emission glow pass and its render updates |
| `P` / `R` | Pause / reset |

Paint slots are UI shortcuts and never become material IDs. Material cycling changes
the selected material directly and reports its stable ID in the status line.

## Executable material families

| Family | Materials | Representative current behavior |
|---|---|---|
| Powder and density | Sand, Stone, Dust | Gravity, diagonal settling, opt-in density exchange; Stone can retain supported structures; Dust ignites |
| Conserved liquid | Water | Fixed-point mass, fast self-leveling, stable rest, render-only dithering, density displacement |
| Yielding liquid | Paste, Slush | Whole-cell viscosity, heap-capable flow, and presentation-only moving bands for gels/slurries |
| Buoyant gas | Smoke | Rises through accepting denser materials, slowly thins/culls, and cannot host Fire |
| Combustion | Fire, Wood, Oil | Fire drifts at full rate but samples destructive ignition at a distributed 0.5 Hz; Wood burns down gradually; Oil propagates fire; Water extinguishes immediately |
| Thermal/phase | Lava, Ice, Water, Steam | Lava ignites and melts Ice; Ice freezes adjacent Water slowly; Water hit by Fire/Lava becomes Steam; Steam later condenses |
| Corrosion | Acid | Mobile corrosive liquid consumes eligible neighboring material and expends finite strength; Wall resists it |
| Growth | Plant, Fungus, Seed | Energy-bounded local growth; Fungus colonizes Wood; supported Seed germinates; growth materials burn |
| Replication | Cloner | Captures a valid adjacent material and emits initialized copies into empty neighbors |
| Agents | Mite, Rocket | Mite moves and consumes biological/powder targets; Rocket captures a payload, launches when heated, deposits a trail, and burns on impact |
| Dissolution/reactive powder | Salt, Brine, Sodium | Salt and Water form heavier Brine; Sodium reacts with Water or Brine into Fire and Steam |
| Energetic solids | Gunpowder, Coal | Gunpowder flashes into Fire; Coal falls, burns slowly, emits Fire/Smoke, and leaves Dust |
| Conductive/structural | Metal, Rust, Spark | Spark charges adjacent Metal; charge propagates locally and can boil Water; Acid turns Metal into Rust and Smoke |
| Curing material | Cement, Concrete | Wet Cement flows slowly and cures when exposed to air, Water/Brine, or existing Concrete; water accelerates curing |
| Dense/scientific liquids | Toxic Sludge, Mercury | Water purifies adjacent sludge; Mercury's high density makes it displace ordinary liquids downward |
| Glass family | Glass, Molten Glass | Lava remelts Glass; Molten Glass flows slowly, cools into a hard surface, and quenches against Water |
| Light cellular fluid | Foam | Short-lived Foam rises through accepting liquids and disperses laterally |
| Medieval construction | Limestone, Sandstone, Granite, Cobblestone, Brick, Plaster, timber, roofing, historic metals/glass, Packed Earth | Static collision palette; Oak Timber and Thatch reuse bounded combustion |
| Industrial construction | Industrial Brick, Reinforced Concrete, asphalt, plates, corrugation, grating, chainlink, pipes, tile, glass, rubber, cables, insulation | Static hard surfaces with zero active-rule cost after settling |
| Luminous construction | Hazard Stripe, three Neon colours, LED White | Analytic pattern/HDR programs; bounded glow and render-only animation |

These are bounded CyberSand adaptations of Sandspiel's material vocabulary and
interaction ideas, not a byte-for-byte port. Water deliberately retains the
CyberSand conserved-mass solver instead of Sandspiel's mutable lateral-polarity
rule. Random choices use deterministic coordinate/tick streams and ordinary
rule writes stay within their declared scheduler radius.

## Useful manual pairings

- Place Water above Oil to observe density separation.
- Trap Smoke below Water or Sand to verify upward density exchange.
- Paint Fire beside Wood, Oil, Dust, Plant, Fungus, Seed, Water, and Ice.
- Put Lava against Water and Ice.
- Put Salt or Sodium into Water; compare the resulting Brine and Steam/Fire reactions.
- Ignite Gunpowder and Coal, then compare their short flash and slow-burn behavior.
- Draw a Metal wire, touch one end with Spark, and place Water near another section.
- Pour Cement into a cavity and compare air curing with Water-accelerated curing.
- Drop Mercury through Water, Oil, Brine, or sludge to compare density exchange.
- Put Lava against Glass, or quench Molten Glass with Water.
- Paint Foam below a liquid pool and watch it exchange upward before decaying.
- Enclose Acid with Sand, Wood, Stone, or biological material, leaving Wall as a control.
- Put Plant or Fungus beside compatible substrate, then introduce Fire.
- Place Seed on Sand and allow vertical room for growth.
- Put a Cloner beside one chosen material, then clear empty output space around it.
- Place Rocket beside a desired payload before adding Fire or Lava.
- Compare Water, Slush, and Paste on the same stepped slope.

Sandspiel provenance and the full port ledger remain in
`docs/research/sandspiel-performance-and-material-port.md`, with its MIT notice
retained in `THIRD_PARTY_NOTICES.md`.

Appearance is intentionally separate from behavior. The native bridge projects
one material-specific condition byte alongside each material ID; the GPU derives
variation, condition response, alpha, emission, and a bounded procedural flair
class from the existing LUT reads. A separate common relief stage then samples
four neighbours from the already-uploaded RG8 texture; it adds no CPU payload or
world image. See
`docs/systems/material-appearance-and-rendering.md` for the exact Current path
and the remaining full-GPU-upload limitation.

The exact themed IDs, construction roles, performance implications, and example
castle/village/factory/alley recipes are in
`docs/systems/themed-construction-materials.md`.

## Related decisions

- [Material rules](systems/materials-and-rule-kernels.md)
- [Themed construction materials](systems/themed-construction-materials.md)
- [Water model](decisions/ADR-005-water-model.md)
- [Bounded approximate fidelity](decisions/ADR-008-bounded-approximate-fidelity.md)
- [Item-authored material programs](architecture/item-authored-material-programs.md)
