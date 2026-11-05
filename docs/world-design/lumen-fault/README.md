# THE LUMEN FAULT — world-feature collection 001

**Status: draft / design only.** Source: [`main` at `ba9cbc89029be88b812af59b19e5c59829bbcd90`](https://github.com/techrote/cybersand/commit/ba9cbc89029be88b812af59b19e5c59829bbcd90), inspected 2026-11-05.

An abandoned deep subterranean survey station: sharp basalt formations, bright quartz needles, oxidised copper observatory instruments, and a specimen cistern isolated beneath a calibration terrace. The set is intended for later selection into map-editor palettes, scenario maps and generative resource bundles—not a production map or runtime engine change.

![Source-colour schematic, not a Godot screenshot](preview.svg)

The preview visualises the exact draft rectangle descriptions with flat RGBA from the **shadow** catalogue. There has been **no Godot capture, native tick, shader-material review, Rapier extraction, or fluid qualification**.

## Pieces

| Feature | Cells (w×h) | Dynamics | Reuse role |
|---|---:|---|---|
| `fault-strata` | 72×56 | static | Jagged mineral flank and seam grammar |
| `quartz-fan` | 56×56 | static | Asymmetric shard bloom and high-contrast focal landmark |
| `survey-tripod` | 64×64 | static | Oxidised measurement rig with optical hood |
| `seal-gate` | 80×64 | static | Basalt architectural portal with actual void opening |
| `sealed-cistern` | 88×64 | contained-dynamic | Enclosed Water specimen, inspector windows, corrosion |
| `signal-totem` | 48×64 | static | Vertical monument with opposed optical bands |
| `collapsed-gantry` | 88×56 | static | Frozen diagonal crash silhouette and loose cable motifs |
| `archive-console` | 72×56 | static | Unreadable but tactile instrument wall in glass and steel |

The [machine-readable draft pack](pack.json) contains each piece's ordered rectangle list, exact native material IDs, coordinates, floor-contact anchor, placement limits, variant material swaps and size. It also includes a **640×256** two-tier combined section with eight explicit feature placements, supports and service pipes. This is not a claims-bearing playable map.

## Design grammar

Keep the dark basalt/obsidian area dominant; use glass and quartz as carefully spaced highlights. Cyan **NeonCyan 77** is the ordinary instrumentation cue; **NeonAmber 79** is an exceptional alert. Oxidised **VerdigrisCopper 54** links rock to instruments; **RustedSteel 65** connects the broken mechanical lineage. Use one sharp vertical accent in roughly every 160–240 horizontal cells, flanked by lower, rough rock or damaged truss parts.

Modules are 48–88 cells wide and 56–64 high. All coordinates start from a top-left local origin, with +x right, +y down, half-open rectangles `[x,y,width,height,native_material_id]`. The mapping follows the *shape* of construction commands in [`CyberDemoWorlds._rect`](../../../godot/scripts/demo_worlds.gd), but **this new JSON format has no existing accepted importer**. Later rectangles overwrite earlier writes. Missing cells do not constitute a separate decorative layer or automatic erase. Host terrain must be explicitly cleared where actual openings and enclosures are needed.

### Evolution classes and contact limits

Seven pieces are made exclusively of `movable=false` materials, checked against the pinned source catalogue and [native enum](../../../native/include/cybersand/material.hpp); they are **static authored geometry**, not supported floating-body construction. The fallen gantry is immovable scenery, not a real collapsing structure. SteelGrating 66 is visually perforated but a solid collision surface; DarkGlass 72 and ChemicalGlass 71 remain solid despite translucent presentation. Emissive finishes are presentation effects, not light sources that affect simulation.

**Sealed witness cistern** is deliberately different: ID **3 Water** is an active native FreeMass liquid, within visually sealed immovable concrete/steel. A rectangular enclosure is only a **design hypothesis**, not proof of leak freedom, conservation, hydrodynamic stability, pressure limit or performant scheduling. The `dry` variant replaces Water with Empty ID 0. Any wet-map admission requires native execution with source-pinned geometry and fluid measurements.

The actual [material visual programs](../../systems/material-visual-pattern-library.md) add orientation, relief, neighbours and time effects absent in this flat preview. No per-cell cosmetic overlays are modelled. Variant definitions are **literal material ID swaps**, not shader variant state or in-game animation.

## Validation and prospective integration

A stdlib [validator](validate_pack.py) checks structure, exact native IDs against the actual enum, shadow palette consistency, rectangle bounds, static immovability, variant references, scene bounds, and expected unique contained Water rectangle. It does **not** perform an engine or gameplay test. Run on a checkout of the pinned commit plus these draft files:

```sh
python3 docs/world-design/lumen-fault/validate_pack.py
```

**Integration staging proposal:** separately approve the resource-bundle schema; devise explicit host-clearance and overwrite/priority rules; translate the rectangle cells into GDScript `PackedInt32Array` construction (or later native GEN semantic-plane override data) with source/material identity, before trying real maps. Never treat this pack as valid CYSD1 level content or a proven GEN recipe. Test silhouette, orientation-sensitive material shader, high-surface revision/collider cost, traversal clearance, and wet cistern native behaviour. Do not change production gameplay, PLAY, SOL, MAT-AUTH or IN-TOOLS on this design branch.

## Follow-on themes

- **Moon-salt terraces:** layered RockSaltBlock 106 and Brine 24 with separately qualified reaction/flow boundaries.
- **Root-flooded ossuary:** an organic analogue with deliberately tested combustible/biological rule interactions.
- **Celadon heat-sink chamber:** ceramic, refractory and quiescent laboratory surfaces; avoid fake thermal claims.
