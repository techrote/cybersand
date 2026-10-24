---
title: Building material catalogue
document-kind: reference
canonical-for: [building-material-ids, building-material-reactions-and-finish]
status: Current
scope: Stable IDs 81–131 (MAT-002), their kernels, versioned pair reactions, shader finishes and limitations
last-reviewed: 2026-10-19
related-documents: [themed-construction-materials.md, materials-and-rule-kernels.md, intermaterial-interactions.md, material-appearance-and-rendering.md, ../reference/material-effects-register.md, ../audits/2026-10-18-material-fidelity-pass-2.md]
---

# Building material catalogue

**Current (source, 2026-10-18):** IDs 81–131 add 51 immovable hard-surface
building materials. Seventeen woods, fibres and combustible polymers reuse the
bounded `Combustible` kernel. Twenty-five take part in at least one of 42
versioned pair reactions owned by `int.pass.mat002-building-materials`. The
remaining nine are inert apart from the existing broad Acid neighbourhood
corrosion. Names and finishes are gameplay presentation, not calibrated
chemistry or thermodynamics.

The authoritative sources are the
[descriptor table](../../native/include/cybersand/material.hpp) (`kMaterialDefinitions`,
`kFirstBuildingMaterial`, `kLastMaterial`), the
[interaction catalogue](../../native/include/cybersand/interaction_rules.hpp)
(`kPairInteractionRules` entries after `kCurrentOraclePairRuleCount`) and the
`apply_building_finish` branch of the
[palette shader](../../godot/shaders/material_palette.gdshader). IDs 38–80 stay
owned by the [themed construction catalogue](themed-construction-materials.md).
Editing either native source also changes the LCB liquid-policy identity: follow the [regeneration sequence](../architecture/liquid-solver-family-policy.md#regenerating-identity-after-a-material-or-rule-edit) before committing.

## Catalogue

"Reactions" lists the partner, the stored inclusive probability threshold in
0–255, then the partner's product followed by this material's product. The
resolver accepts `roll <= threshold`; for a uniform byte roll, the selection
probability per eligible contact opportunity is `(threshold + 1) / 256`.
Contacts use the four-tick chemistry lane and MAT-001 persistence described in the
[material contract](materials-and-rule-kernels.md#how-do-persistent-reactions-survive-sleep).

| ID | Stable name | Native behaviour | Reactions | Finish |
|---:|---|---|---|---|
| 81 | pine-planks | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Staggered boards, flowing grain, resin knots |
| 82 | birch-log | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Papery white bark, black lenticel dashes, peeling curls |
| 83 | oak-log | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Deep furrowed bark plates, cylinder shading, lichen |
| 84 | walnut-panel | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Dark figured grain, satin lustre band |
| 85 | mahogany-panel | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Ribbon-stripe grain, satin lustre band |
| 86 | bamboo | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Rounded culms with nodes and per-culm tint |
| 87 | plywood | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Cathedral face veneer; ply laminations on exposed edges |
| 88 | driftwood | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Silvered weathered grain, worm holes |
| 89 | cedar-shingles | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Staggered shingle courses weathering red to silver |
| 90 | charred-timber | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Shou sugi ban alligator crackle with silver sheen |
| 91 | cork | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Compressed granules and dark pores |
| 92 | wicker | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Over/under basket weave |
| 93 | cardboard | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Fibre mottle, creases, tape; fluting on exposed edges |
| 94 | paper-screen | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Backlit paper in a kumiko lattice |
| 95 | tar-block | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Wrinkled glossy pitch, fixed specular band |
| 96 | acrylic-sheet | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Clear sheet, polished bright edges |
| 97 | moss-wall | Combustible (burns; Water extinguishes) | Fire/Lava ignition via the kernel | Stone courses smothered in moss; hosts flowers and vines |
| 98 | marble | Pair rules | Acid (192/255): Foam + Salt | Warped grey and gold veins, polished slabs |
| 99 | chalk-block | Pair rules | Acid (224/255): Foam + Dust; Water (6/255): Water + Paste | Soft powdery blocks and smudges |
| 100 | basalt-columns | Pair rules | Lava (6/255): Lava + Lava | Vertical faceted prisms with cross-fractures |
| 101 | obsidian | Pair rules | Lava (24/255): Lava + Molten Glass | Glassy conchoidal ripples and glints |
| 102 | adobe-brick | Pair rules | Water (24/255): Water + Paste; Lava (64/255): Lava + Red Brick | Large mud bricks with straw flecks |
| 103 | raw-clay | Pair rules | Fire (48/255): Fire + Terracotta Tile; Lava (128/255): Lava + Terracotta Tile; Water (10/255): Water + Paste | Smooth damp body with finger smears |
| 104 | firebrick | Inert | None beyond broad Acid corrosion | Pale buff bricks, iron spots |
| 105 | packed-snow | Pair rules | Fire (255/255): Steam + Water; Lava (255/255): Stone + Steam; Steam (32/255): Water + packed snow; Salt (64/255): Brine + Slush; Molten Glass (255/255): Glass + Steam | Compression layers, blue shadow, white top, glitter |
| 106 | rock-salt-block | Pair rules | Water (48/255): Brine + Salt | Translucent pink/white halite crystals |
| 107 | gypsum-board | Pair rules | Water (16/255): Water + Paste; Fire (6/255): Fire + Dust | Taped joints and screw rows |
| 108 | quicklime-block | Pair rules | Water (128/255): Steam + Cement | Chalky grain with crazed cracks |
| 109 | rammed-earth | Pair rules | Water (6/255): Water + Sand | Wavering ochre/red/umber strata |
| 110 | sandbag | Pair rules | Fire (40/255): Fire + Sand | Stacked burlap pillows |
| 111 | terrazzo | Inert | None beyond broad Acid corrosion | Polished matrix with multicoloured chips |
| 112 | gabion | Inert | None beyond broad Acid corrosion | Fieldstones behind a wire grid |
| 113 | zinc-sheet | Pair rules | Acid (192/255): Smoke + Salt | Galvanised spangle crystals |
| 114 | aluminium-panel | Inert | None beyond broad Acid corrosion | Brushed panels, rivets, moving glint |
| 115 | magnesium-plate | Pair rules | Fire (96/255): Fire + Fire; Spark (255/255): Empty + Fire | Bright sheet with white oxide bloom |
| 116 | thermite-brick | Pair rules | Spark (255/255): Empty + Lava; Fire (64/255): Lava + Lava | Red oxide grain with silver flecks |
| 117 | bare-iron | Pair rules | Water (3/255): Water + Rusted Steel; Brine (12/255): Brine + Rusted Steel; Acid (160/255): Smoke + Rust | Mill-scale mottle, heat tint, early flash rust |
| 118 | gold-leaf | Inert | None beyond broad Acid corrosion | Overlapping gilded squares, crinkles, sparkle |
| 119 | brass-panel | Inert | None beyond broad Acid corrosion | Brushed brass, tarnish, moving glint |
| 120 | glass-block | Pair rules | Lava (255/255): Lava + Molten Glass | Rippled lenses in mortar joints |
| 121 | frosted-glass | Pair rules | Lava (255/255): Lava + Molten Glass | Diffuse frost with clear borders |
| 122 | quartz-crystal | Pair rules | Lava (8/255): Lava + Molten Glass | Prismatic facets with rainbow edges |
| 123 | uranium-glass | Pair rules | Lava (255/255): Lava + Molten Glass | Fluorescent green body, bright edges, low glow |
| 124 | sugar-glass | Pair rules | Water (48/255): Water + Paste; Fire (64/255): Smoke + Coal | Amber with bubbles and stress cracks |
| 125 | wax-block | Pair rules | Fire (64/255): Fire + Oil; Lava (255/255): Lava + Oil | Soft translucent body, under-edge drips |
| 126 | sulfur-block | Pair rules | Fire (96/255): Smoke + Fire; Lava (64/255): Lava + Fire | Needle-crystal clusters |
| 127 | phosphor-panel | Pair rules | Fire (128/255): Fire + Fire | Hex dots with slow breathing afterglow |
| 128 | polymer-panel | Pair rules | Lava (255/255): Lava + Oil; Fire (32/255): Smoke + Oil | Moulded ribs, sprue marks, gloss band |
| 129 | solar-panel | Inert | None beyond broad Acid corrosion | Blue cells, silver busbars, frame, reflection |
| 130 | carbon-fibre | Inert | None beyond broad Acid corrosion | 2x2 twill weave with alternating sheen |
| 131 | heat-shield-tile | Inert | None beyond broad Acid corrosion | Black tiles, pale gap filler |

## How do these materials behave natively?

All 51 rows are `MaterialState::Solid`, immovable, decline density exchange and
use `LateralFlowMode::None`. `MaterialRules::is_hard_surface` covers the whole
range 38–`kLastMaterial`, so collision, character queries, geometry extraction
and Rapier terrain treat them exactly like the themed catalogue.

- **Combustible (81–97):** radius-one `RuleKernel::Combustible`, explicit
  `int.family.combustible-kernel` members, burn progress in `state_b` and
  projected to the renderer. Fire/Lava ignite them; Water extinguishes. They do
  not count as timber for the Fungus substrate or Mite feeding rules (those stay
  Wood/Oak Timber only).
- **Pair-reactive:** radius-zero `RuleKernel::None`. Their partner (Fire, Lava,
  Water, Brine, Acid, Spark, Steam, Salt or Molten Glass) already had compact
  pair rules, so the partner's existing contact lane finds them. No pre-existing
  material gained a pair-participant flag.
- **Inert:** firebrick, terrazzo, gabion, aluminium panel, gold leaf, brass panel,
  solar panel, carbon fibre and heat-shield tile. Acid's broad kernel still
  dissolves them; that is the existing Acid authority, not a new rule.
- Acid pair rules compete with Acid's broad corrosion on the same cell; a contact
  can end either way. The native regression accepts both and requires the pair
  products to appear.

Transport profile schema v1 stays at 81 entries (IDs 0–80); later IDs use the
documented defaults through `TransportPolicy::pair/cadence_for/horizontal_for`.
The [transport contract](flow-transport-and-profiles.md) owns that schema.

## Fallback, UI and appearance

The desktop GDScript fallback ([CyberCellWorld](../../godot/scripts/cell_world.gd))
mirrors the IDs (`FIRST_BUILDING_MATERIAL`, `LAST_MATERIAL`,
`BUILDING_MATERIAL_NAMES`) and treats them as static hard surfaces; it has no
combustion or pair reactions. All IDs are paintable; the material picker gains
four group starts (Pine Planks, Marble, Zinc Sheet, Glass Block).

Every row compiles to `FLAIR_BUILDING` in the
[appearance LUT](../../godot/scripts/material_appearance_lut.gd); combustibles
reuse the Oak burn curve. Finishes read the shape-aware run probe (orientation,
cross-section, exposed edges) and fall back to a fixed large-panel geometry when
`structured_detail` is 0. They are time-independent except aluminium/brass/gold
glints, snow glitter and phosphor breathing. Uranium Glass and Phosphor Panel
carry low HDR emission. The
[appearance contract](material-appearance-and-rendering.md) owns cost semantics.

## Which integration boundaries use the expanded catalogue?

Native level constructors, CYSD1 import/export, selected-material metadata,
diagnostic fills, material histograms and MicroScenario runtime identity use the
132-slot catalogue (reserved ID 10 remains invalid). Boundary-pressure diagnostics
use four faces of 132 slots each. Sampled-rig movement queries and existing
`CyberActorRigEffects` digging treat new hard surfaces as occluders, preserving
cells behind uneditable barriers. USABLE-001 equipment retains its separate
[authored eligibility and occlusion contract](actor-usables.md). These boundaries
are exercised across all 51 additions in
[`test_building_material_integration.gd`](../../godot/tests/test_building_material_integration.gd).
The [save contract](../reference/level-saves-and-replay.md) owns compatibility and
failure atomicity; the [review record](../audits/2026-10-19-mat002-review-and-validation.md)
owns dated results and runtime publication evidence.

## Limits

- Probabilities and products are authored gameplay tuning. They are not measured
  reaction rates, enthalpies or melting points.
- Thermite, Magnesium and Sulfur reactions convert cells to Fire/Lava/Smoke; there
  is no heat field, explosion or temperature threshold.
- Each native source change requires matching runtime publication. The original
  [material-pass record](../audits/2026-10-18-material-fidelity-pass-2.md) describes
  its then-stale runtime; the [review record](../audits/2026-10-19-mat002-review-and-validation.md)
  distinguishes later Linux/Windows publication from separately unvalidated Web
  exports and target-GPU performance.
