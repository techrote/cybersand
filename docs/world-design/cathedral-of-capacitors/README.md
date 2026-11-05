# Cathedral of Capacitors — world-feature collection 009

**DRAFT / DESIGN ONLY / DO NOT MERGE.** Eight reusable architectural remnants of an unpowered electrical sanctuary: twin capacitor organs, an insulator buttress, a rose circuit, a bus portal, a cable nave, a ransacked cell-bank altar and two explicitly experimental active cabinets. No production map, generator, gameplay, physics, engine, editor or canonical catalogue changes.

![Eight features and a combined dry cathedral scene](preview.svg)

## Exact current source / staging contract

Main `ba9cbc89029be88b812af59b19e5c59829bbcd90`, tree `3af18f50e6094776263119623b64a1b2f4ca0ab2`. Native enum `dcf05895da3015a2e999e3d1cbbae0fdc7fe32b3`, shadow catalogue `d7a47d60721598a16589daf177a6ff4401b84b43`, interaction rules `b70fc9dc2599f648e5374f06e4cc0ae9cb868d79`. All 28 referenced material IDs and source properties checked against catalogue and enum; shadow metadata does **not** supersede actual native runtime authority.

`pack.json` is a provisional design-resource schema **not** a map save, engine importer, prefab or physics qualification. All positions are integer native cells, origin upper-left, +x right, +y down; rectangles are half-open `[x,y,w,h,material_id]`. Paint order is sequential and later rectangles replace prior cells. There are **no engine layers** or alpha compositing semantics. All pieces anchor bottom centre, 0° / 1×; no rotation or mirroring validated. Combined scene 1240×278, shared ground y=248. Gaps and glass apertures are **not host erasers**: a future importer must own/clear terrain explicitly.

## Design identity

Treat obsolete electricity as *ceremonial architecture*, rather than working machines. 65% dark basalt/slate/iron, 20% steel/ceramic, 10% cyan-magenta phosphor diagnostics and 5% brass/oxidised contacts. Large paired vertical vessels interrupt long low horizontal conductor lines, with one circular rosette and one open portal. Draw attention with sparse fluorescent marks; do not blanket-fill cyan. Source RGBA is used in the preview; no glow, power, circuit behavior or lighting is asserted.

**Assembly:** preserve an 18–32 cell transition around primary silhouettes. Default sequence: Bus Narthex → Conductor Nave → Accumulator Plinth → Insulator Buttress → Capacitor Organ → Rose Indicator → Arc Reliquary (silent) → Coolant Transept (glass). The combined preview uses exactly one of each with source-colour, dry replacements. Reusable patterns in `pack.json`: `nave-spine`, `signal-choir`, `quiet-test-pavilion`. Do not stamp over gameplay-critical collision or existing content without a bounded importer.

## Eight modules

| Module | Cells | Status | Purpose / constraint |
|---|---:|---|---|
| Bus Narthex / broken current gateway | 144×112 | inert-static | processional entry with a visibly isolated central opening; actor clearance not tested |
| Capacitor Organ / twin dielectric towers | 136×124 | inert-static | monumental twin charge vessels framing a delicate central gap; actor clearance not tested |
| Insulator Buttress / stepped support arch | 132×108 | inert-static | asymmetric flying staircase and dielectric studs; actor clearance not tested |
| Rose Indicator / fractured circuit mandala | 120×122 | inert-static | circular-ish segmented electronic stained-glass shrine; actor clearance not tested |
| Conductor Nave / side-chapel cable run | 140×96 | inert-static | long restrained horizontal processional cable and insulated arches; actor clearance not tested |
| Accumulator Plinth / plundered cell bank | 130×102 | inert-static | asymmetric stripped storage-battery altar with missing cells; actor clearance not tested |
| Arc Reliquary / sealed lightning cabinet | 112×118 | dynamic-ephemeral | test-only sparkling vessel inside fixed ribs; actor clearance not tested |
| Coolant Transept / paired baptismal baths | 132×108 | dynamic-liquid | test-only double coolant basin with stained-glass drip fall; actor clearance not tested |

Each includes local bounds, ordered material stamps, two independent palette substitution variants, anchor, neighbor rules and clearance flag. All six original fixed features exclusively use kernel=0, nonmoving source materials. These are **source-classified inert candidates**, not native-tested collision or stability proofs. Concrete/metal appearance does not imply functioning electronic or structural constraints.

### Active experiments — intentionally excluded from dry composition

- **Arc Reliquary:** Spark **34** has `movable=true`, kernel **24**, initial state A **12**. Its original dispersed lightning marks can expire, propagate or interact; behavior was *not run*. Combined scene selects `silent-arc` (Spark→NeonCyan **77**, fixed kernel 0), a design stand-in, not energisation.
- **Coolant Transept:** Water **3** is mobile, kernel **2**, initial state A **255**, and may reconfigure or escape the depicted bowls. Nothing proves containment or FreeMass behavior. Combined scene selects `frozen-mirrors` (Water→GlassBlock **120**, fixed kernel 0). Never co-locate both original active pieces as a tested gameplay system without separate simulation fixtures.

No temperature, curing, erosion, fluid pressure, combustion or energy consumption behavior is supplied by the rectangular prototype. Native interaction rules remain authoritative if later active fixtures are constructed. Active test sequence should be t=0/60/600 on current-main native with mass/state, leaks, cell counts and CPU measurements, then shader-correct Godot capture and actor clearance; authoring integration only after a reviewed owner-clearing and collision contract.

## Reproduction

From this directory:

```sh
node validate_pack.mjs
node validate_pack.mjs ../../../materials/catalogue/catalogue.json ../../../native/include/cybersand/material.hpp
node render_pack.mjs preview.regenerated.svg
cmp preview.svg preview.regenerated.svg
```

The scripts and preview are staging aids, not a production toolchain. Generation-side structural validation, enum+catalogue comparisons and 13 deliberately invalid mutation rejects completed. **Not executed:** checked-in Node scripts in checkout; native solver ticks; Godot capture; import/host clearing; physical support; actor/Rapier clearance; hosted CI; performance measurements. Preview is static SVG.

## Dependencies and outstanding admission questions

1. Is a reviewed world-feature import schema accepted, including overwrite/clear rules, scaling and terrain ownership?
2. Which authoring palette uses these modules: manual brushes, bundled maps or procedural placement recipes?
3. How should power/thermal cues be represented without misleading authors into treating cyan/amber fixed materials as powered circuits?
4. Does simulation at exact current source keep active Spark/Water variants viable, or should those two stay visual-only fixtures?

This PR is **independent from PLAY, SOL, MAT-AUTH, IN-TOOLS and all solver work**. Do not merge without separate admission and validation.
