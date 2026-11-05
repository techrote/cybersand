# CARVED ICE CHOIR — world-feature collection 003

**Design-stage proposal only.** No production gameplay, native physics, canonical materials, map fixture or GEN integration edits. Pinned to main [`ba9cbc89029be88b812af59b19e5c59829bbcd90`](https://github.com/techrote/cybersand/commit/ba9cbc89029be88b812af59b19e5c59829bbcd90), native enum blob `dcf05895da3015a2e999e3d1cbbae0fdc7fe32b3`, shadow catalogue blob `d7a47d60721598a16589daf177a6ff4401b84b43`, interaction registry blob `b70fc9dc2599f648e5374f06e4cc0ae9cb868d79`. Distinct from Lumen Fault [#408](https://github.com/techrote/cybersand/pull/408) (industrial survey) and Chalkbone Coast [#410](https://github.com/techrote/cybersand/pull/410) (fossil coast).

![Source-colour initial-placement schematic](preview.svg)

**Preview is not a Godot screenshot.** It paints native palette colours at t=0 but depicts no tick, melting, sound, dynamic settlement, shaders, actor collisions or structural load. Dark cave air is **empty/unwritten**, not a filled Obsidian backdrop.

## Composition and palette

Imagine a glacial cavern as a giant silent instrument: **BasaltColumns 100** and **Slate 49** form a continuous musical staff, with **FrostedGlass 121** and **QuartzCrystal 122** forming pale suspended musical notes. **GlassBlock 120**, **PackedSnow 105** and **Ice 9** accent the strong structural forms. Only specially marked dynamic pieces introduce **Water 3**, **Slush 21**, **Dust 14** or **Stone 13**.

Assemble two different bands: hanging ceiling ribs and standing floor chimes. Alternate a dominant high note with two shorter forms and retain 24–48 cells of negative air; repeat a specific organ profile no more often than every 130 horizontal cells. Avoid a grid of identical prisms. Keep the material-mass ratio intentionally dark and airy. No decorative material makes a real light source or resonator. Use source RGBA faithfully (not stylised game shader claims).

## Eight authoring modules

| ID | Dimensions | Class | Structural and physical intent |
|---|---:|---|---|
| `ribbed-vault` | 128×100 | Reactive fixed | Five ribs, fixed translucent glass, heat/salt-reactive PackedSnow 105 |
| `pendant-organ` | 88×112 | Reactive fixed | Seven Ice 9 icicles, thermal phase risk; `inert-glass` alternative |
| `bellstone-triad` | 100×84 | Inert static | Three graduated vitreous standing bells |
| `fan-of-rime` | 80×84 | Reactive fixed | Asymmetric fan of PackedSnow 105 and quartz |
| `counterpoint-span` | 128×84 | Inert static; clearance unproven | Two-foot bridge/arch, visual void underneath |
| `sleet-reservoir` | 112×84 | Active dynamic | Water 3 / Slush 21 / Ice 9 in a proposed open catch bowl |
| `falling-notes` | 80×68 | Active dynamic | Dust 14 and Stone 13 moving powders over a mineral catch basin |
| `echo-stelae` | 96×84 | Inert static | Four irregular inert glass megaliths ending the rhythm |

There are 151 ordered rectangles and 16 controlled material-swap variants. Feature-local rectangles are `[x,y,width,height,native_id]` with **half-open bounds** and +x right/+y down. Local ground anchors are placed at y=height; ceiling anchors at y=0; the bridge has two ground feet. Anchor and clearance rules, substitution maps, neighbouring material exclusions and individual visual intent are machine-readable in `pack.json`. Last paint wins, but unwritten voids never clear pre-existing cells. No rotations/mirrors or true engine layers are admitted.

## Scene: ice-choir-cavern-01

A single **800×320** cavern, continuous cap at y=0–35 and floor beginning y=260. Exact module origins:

| Module | Scene origin (x,y) | Variant |
|---|---|---|
| ribbed-vault | (92,36) | default |
| pendant-organ | (430,36) | default |
| bellstone-triad | (14,176) | default |
| fan-of-rime | (131,176) | default |
| counterpoint-span | (235,176) | default |
| sleet-reservoir | (389,176) | mineral-dry |
| falling-notes | (535,192) | fossilized-notes |
| echo-stelae | (674,176) | default |

The exhibition composition deliberately uses two **dry/mineral alternatives** instead of claiming liquid/powder equilibrium. The dry reservoir still includes reactive PackedSnow; inspect Fire, Lava, Salt and Steam contacts if eventually placed in an active map. Do not apply any of the features to an old fixture without a separate **bounded clear-then-paint** transaction and source-matched material initialization; existing editor/GEN/socket and player spaces must retain their own ownership. Do not assume the arch is traversable until tested against native and Rapier geometry.

## Reality checks and risks

- **Static:** `bellstone-triad`, `counterpoint-span`, `echo-stelae` use default fixed kernel-none materials. Fixed cells do not automatically provide physical support or collision guarantees.
- **Reactive fixed:** `pendant-organ` contains Ice 9 with hot-neighbour melt and sampled Water freezing. `ribbed-vault` and `fan-of-rime` contain fixed PackedSnow 105; source interaction pairs include Fire/PackedSnow, Lava/PackedSnow, Salt/PackedSnow and Steam/PackedSnow.
- **Dynamic:** `sleet-reservoir` uses native Water 3 **FreeMass** and Slush 21 **CellularYield**, distinct physics and accounting. Its containment is **untested**. `falling-notes` has downward-moving Dust 14 and Stone 13; its default t=0 columns will change.
- **Performance:** flowing liquid, thermal revalidation and falling powders can cause region activation; limit replication until measured and inspect actual material accounting, cell wake costs, leaks, mutation and settled snapshots.
- **Not validated:** native ticks, conservation, visual persistence, Godot shader captures, Rapier or player clearance, load-bearing semantics, supported editor import, GEN exact-recipe behaviour or hosted CI.

## Files and reproduction

- `pack.json`: schema `cybersand.world-feature-pack.proposal`, **not** a native GEN module or CYSD1 save.
- `preview.svg`: native catalogue-colour source preview; no simulation.
- `validate_pack.mjs`: standalone Node structural checks, with optional exact-source Git blob comparison.
- `render_pack.mjs`: deterministic SVG regeneration and `--check` byte comparison.

```sh
cd docs/world-design/carved-ice-choir
node validate_pack.mjs
node render_pack.mjs --check
# If you have the exact pinned source tree:
node validate_pack.mjs --repo-root /path/to/cybersand
```

**Publication checks in tool-side JavaScript:** authoring schema, all rectangle bounds/ID references, variants and placement integrity PASS; 8 deliberately invalid mutations rejected; source IDs came from GitHub exact-head catalogue. Preview generated successfully. This is not a claim that the checked-in scripts were run via a Node CLI in a checkout; no engine or hosted CI was run.

**Future integration questions:** choose clearing/overwrite semantics and a trusted editor/GEN resource path, define scene-collision support semantics, qualify thermal transition and performance of optional dynamic compositions, and establish a dry-first palette trial. Keep the PR Draft until an owner chooses these contracts.
