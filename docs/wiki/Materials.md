# Materials — source-exact CyberSand catalogue

> **Snapshot:** [`a8f08a67fea3c58f6df7473cbae1831334fcc04e`](https://github.com/techrote/cybersand/commit/a8f08a67fea3c58f6df7473cbae1831334fcc04e) (`main` on 2026-11-02). **Status:** source-derived reference; regenerate after any descriptor, interaction, or appearance change. The numeric values below are **implemented gameplay constants**, not measured physical constants. 
> **132 allocated IDs** (0–131); **131 valid**, including Empty; **130 paintable** (excluding Empty and invalid/reserved ID 10). `Material::Gas` is an alias of Smoke (ID 4), **not** a separate cell type.

This page separates immutable material descriptors, semantic-family membership, actual physics/contact predicates, rendered appearance, and opt-in transport/profile settings. A material can simultaneously belong to multiple sets. A named visual material does **not** automatically inherit another material's behavior.

## Contents
1. [Identity and category lattice](#1-identity-and-category-lattice) — ID ranges, phase counts, orthogonal collision/transport groups.
2. [Explicit semantic families](#2-explicit-semantic-families) — versioned members, not name-inferred inheritance.
3. [Exact native descriptor table](#3-exact-native-descriptor-table) — **all 132 slots** with density, mobility, flow, kernel, state and collision flags.
4. [Exact rendering and initial visual state](#4-exact-rendering-and-initial-visual-state) — every slot's 8-bit RGBA, variation, hue, flair and condition projection.
5. [All authored pair interactions](#5-all-authored-pair-interactions) — 56 rules, both products, raw thresholds, exact conditional probabilities and channels.
6. [Intrinsic and neighbourhood kernels](#6-intrinsic-and-neighbourhood-kernels) — 19 registered special mechanisms, numeric outcomes and cadence.
7. [Physics, transport and liquid parameters](#7-physics-transport-and-liquid-parameters) — Water mass, granular support, exclusions and profile defaults.
8. [Appearance programme and implementation boundaries](#8-appearance-programme-and-implementation-boundaries) — exact palette-program overrides, display pipeline and caveats.
9. [Source map and maintenance](#9-source-map-and-maintenance) — canonical files, mirrors, limitations and update procedure.

## 1. Identity and category lattice

| Set / relation | IDs / members | Cardinality | Relation / meaning |
|---|---|---:|---|
| `Material` / byte namespace | 0–131 | 132 slots | Stored ID is an unsigned byte; upper 132–255 not catalogued |
| `valid` | 0–9, 11–131 | 131 | Includes Empty; invalid 10 is a reserved magenta sentinel |
| Paintable / non-empty valid | 1–9, 11–131 | 130 | Excludes Empty 0 and invalid 10 |
| Legacy Sandspiel-numbered | 0–19 | 20 slots / 19 valid | Historical numbering preserved; Smoke/Gas = 4 |
| Native reactive additions | 20–37 | 18 | Paste through Foam |
| Themed construction | 38–80 | 43 | 41 `None` kernels + 2 `Combustible` |
| MAT-002 building | 81–131 | 51 | 17 `Combustible`, 25 with pair rules, 9 inert |
| `Empty` phase | 0 | 1 | Empty 0 |
| `MaterialState::Solid` | 1, 5, 7, 9, 10, 11, 18, 28, 31, 35, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131 | 104 | Broad phase; includes invalid 10 if Solid |
| `MaterialState::Powder` | 2, 13, 14, 19, 23, 25, 26, 27, 29 | 9 | Broad phase; includes invalid 10 if Solid |
| `MaterialState::Liquid` | 3, 8, 12, 16, 20, 21, 24, 30, 32, 33, 36 | 11 | Broad phase; includes invalid 10 if Solid |
| `MaterialState::Gas` | 4, 6, 22, 37 | 4 | Broad phase; includes invalid 10 if Solid |
| `MaterialState::Agent` | 15, 17, 34 | 3 | Broad phase; includes invalid 10 if Solid |
| Hard-surface collision predicate | 1, 5, 7, 9, 28, 31, 35; **38–131** | 101 | Rapier/character terrain inclusion; **not** equivalent to `Solid` |
| Granular load capability | 2, 13, 14, 19, 23, 25, 26, 27, 29 | 9 | Stable/packed granular bearing; **not** hard terrain |
| Moving descriptors | See `M=Y` below | 27 | Independent of hard surface and exchange target permission |
| `FreeMass` liquid | 3 Water | 1 | Conserved subcell Water transfer |
| `CellularYield` liquids | 8 lava, 12 acid, 16 oil, 20 paste, 21 slush, 24 brine, 30 cement, 32 toxic-sludge, 33 mercury, 36 molten-glass | 10 | Whole-cell yield family with lateral viscosity |
| Pair-rule participants | See `Pairs` counts below | 41 | Only explicit sparse compact pair matches |

The hard-surface predicate is **all IDs 38–131 plus seven named base materials**; it is not derived solely from density, color, `Solid` phase or `RuleKernel::None`. Powders support sampled actors only when the separate packing/stability test succeeds. Families are intersections/overlaps, not a single inheritance tree. [Predicate source](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/src/material_rules.cpp).

## 2. Explicit semantic families

`interaction_rules.hpp` explicitly registers seven version-1 families and 33 membership records; no superclass behavior is inferred from similar names or appearances. The five layer-precedence levels are schema facilities, not active inherited defaults.
| Versioned semantic family | Members (stable numeric IDs and names) | Count |
|---|---|---:|
| `int.family.combustible-kernel` | 7 wood, 46 oak-timber, 47 thatch, 81 pine-planks, 82 birch-log, 83 oak-log, 84 walnut-panel, 85 mahogany-panel, 86 bamboo, 87 plywood, 88 driftwood, 89 cedar-shingles, 90 charred-timber, 91 cork, 92 wicker, 93 cardboard, 94 paper-screen, 95 tar-block, 96 acrylic-sheet, 97 moss-wall | 20 |
| `int.family.conductive-base-metal` | 28 metal | 1 |
| `int.family.reactive-base-glass` | 35 glass | 1 |
| `int.family.hot-source` | 6 fire, 8 lava, 36 molten-glass | 3 |
| `int.family.aqueous-contact` | 3 water, 24 brine | 2 |
| `int.family.biological-growth` | 11 plant, 18 fungus, 19 seed | 3 |
| `int.family.special-agent` | 5 cloner, 15 mite, 17 rocket | 3 |

**Critical non-inheritance:** Wrought Iron, Copper, Bronze, steel variants and pipes are **not** base `Metal` for electrical conduction; decorative glasses are **not** base `Glass` for base-glass pair quenching. Broad Acid neighbourhood corrosion can still affect decorative materials independently of pair-rule inheritance. The 17 building combustibles are also **not** Fungus/Mite timber substrates (those use Wood/Oak Timber).
**Interaction authoring:** schema `cybersand.interactions` v1; profile `int.current-behaviour` v2; 14 `int.pass.current-oracle` rules + 42 `int.pass.mat002-building-materials` rules. Declared layer precedence: channel=100, family=200, material=300, pair=400, context=500; **0 current implicit layers**. [Authored membership and profile](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp).

## 3. Exact native descriptor table

**Column key:** `ρ` = `uint16` density *ordering parameter*, not calibrated kg/m³; `M` movable; `D` density direction (`↓`, `↑`, `—`); `X` accepts exchange as target; `L` flow (`FM` FreeMass, `CY` CellularYield, `—` none); `ν` dimensionless viscosity index **0–255** (0 most mobile, 255 least); `R` maximum **kernel write radius in cells** (not locomotion range); `A₀/B₀` descriptor initial state bytes; `H` collision-hard; `G` granular-load capable; `Pairs` authored compact rules mentioning that ID. `Y/N` are booleans; `–` is no mode, not a missing value. Invalid ID 10 is retained for correctness but cannot be painted.

### Sandspiel-numbered slots (0–19)
| ID | Stable name | Phase | ρ | M | D | X | L | ν | Kernel | R | A₀/B₀ | H | G | Pairs |
|---:|---|---|---:|:---:|:---:|:---:|:---:|---:|---|---:|---|:---:|:---:|---:|
| 0 | [`empty`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L231) | Empty | 0 | N | — | N | — | 0 | `None` | 0 | 0/0 | N | N | 0 |
| 1 | [`wall`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L233) | Solid | 65,535 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 2 | [`sand`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L235) | Powder | 1,600 | Y | ↓ | Y | — | 0 | `Sand` | 1 | 0/0 | N | Y | 0 |
| 3 | [`water`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L237) | Liquid | 1,000 | Y | ↓ | Y | FM | 0 | `Water` | 1 | 255/0 | N | N | 15 |
| 4 | [`smoke`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L239) | Gas | 20 | Y | ↑ | Y | — | 0 | `Gas` | 1 | 240/0 | N | N | 0 |
| 5 | [`cloner`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L241) | Solid | 65,535 | N | — | N | — | 0 | `Cloner` | 1 | 0/0 | Y | N | 0 |
| 6 | [`fire`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L243) | Gas | 5 | Y | ↑ | Y | — | 0 | `Fire` | 1 | 240/0 | N | N | 14 |
| 7 | [`wood`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L245) | Solid | 720 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 8 | [`lava`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L247) | Liquid | 2,600 | Y | ↓ | Y | CY | 224 | `Lava` | 1 | 0/0 | N | N | 14 |
| 9 | [`ice`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L250) | Solid | 920 | N | — | N | — | 0 | `Ice` | 1 | 0/0 | Y | N | 1 |
| 10 | [`invalid`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L252) **INVALID** | Solid | 65,535 | N | — | N | — | 0 | `None` | 0 | 0/0 | N | N | 0 |
| 11 | [`plant`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L254) | Solid | 540 | N | — | N | — | 0 | `Plant` | 1 | 32/0 | N | N | 0 |
| 12 | [`acid`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L256) | Liquid | 1,050 | Y | ↓ | Y | CY | 64 | `Acid` | 1 | 255/0 | N | N | 5 |
| 13 | [`stone`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L259) | Powder | 2,400 | Y | ↓ | Y | — | 0 | `Stone` | 1 | 0/0 | N | Y | 0 |
| 14 | [`dust`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L261) | Powder | 420 | Y | ↓ | Y | — | 0 | `Dust` | 1 | 0/0 | N | Y | 0 |
| 15 | [`mite`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L263) | Agent | 620 | Y | — | N | — | 0 | `Mite` | 1 | 1/0 | N | N | 0 |
| 16 | [`oil`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L265) | Liquid | 800 | Y | ↓ | Y | CY | 160 | `Oil` | 1 | 0/0 | N | N | 1 |
| 17 | [`rocket`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L268) | Agent | 1,300 | Y | ↓ | N | — | 0 | `Rocket` | 2 | 0/2 | N | N | 0 |
| 18 | [`fungus`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L271) | Solid | 510 | N | — | N | — | 0 | `Fungus` | 1 | 32/0 | N | N | 0 |
| 19 | [`seed`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L273) | Powder | 680 | Y | ↓ | Y | — | 0 | `Seed` | 1 | 0/0 | N | Y | 0 |

### Native reactive additions (20–37)
| ID | Stable name | Phase | ρ | M | D | X | L | ν | Kernel | R | A₀/B₀ | H | G | Pairs |
|---:|---|---|---:|:---:|:---:|:---:|:---:|---:|---|---:|---|:---:|:---:|---:|
| 20 | [`paste`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L275) | Liquid | 1,300 | Y | ↓ | Y | CY | 240 | `YieldingLiquid` | 1 | 0/0 | N | N | 0 |
| 21 | [`slush`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L278) | Liquid | 1,080 | Y | ↓ | Y | CY | 192 | `YieldingLiquid` | 1 | 0/0 | N | N | 0 |
| 22 | [`steam`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L281) | Gas | 12 | Y | ↑ | Y | — | 0 | `Steam` | 1 | 180/0 | N | N | 2 |
| 23 | [`salt`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L283) | Powder | 2,160 | Y | ↓ | Y | — | 0 | `Sand` | 1 | 0/0 | N | Y | 2 |
| 24 | [`brine`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L285) | Liquid | 1,120 | Y | ↓ | Y | CY | 32 | `YieldingLiquid` | 1 | 0/0 | N | N | 3 |
| 25 | [`sodium`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L288) | Powder | 970 | Y | ↓ | Y | — | 0 | `Sand` | 1 | 0/0 | N | Y | 2 |
| 26 | [`gunpowder`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L290) | Powder | 1,700 | Y | ↓ | Y | — | 0 | `Gunpowder` | 1 | 0/0 | N | Y | 2 |
| 27 | [`coal`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L292) | Powder | 1,300 | Y | ↓ | Y | — | 0 | `Coal` | 1 | 0/0 | N | Y | 0 |
| 28 | [`metal`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L294) | Solid | 7,800 | N | — | N | — | 0 | `Metal` | 1 | 0/0 | Y | N | 1 |
| 29 | [`rust`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L296) | Powder | 5,250 | Y | ↓ | Y | — | 0 | `Sand` | 1 | 0/0 | N | Y | 0 |
| 30 | [`cement`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L298) | Liquid | 2,600 | Y | ↓ | Y | CY | 176 | `Cement` | 1 | 180/0 | N | N | 0 |
| 31 | [`concrete`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L301) | Solid | 2,400 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 32 | [`toxic-sludge`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L303) | Liquid | 1,050 | Y | ↓ | Y | CY | 64 | `YieldingLiquid` | 1 | 0/0 | N | N | 1 |
| 33 | [`mercury`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L306) | Liquid | 13,500 | Y | ↓ | Y | CY | 96 | `YieldingLiquid` | 1 | 0/0 | N | N | 0 |
| 34 | [`spark`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L309) | Agent | 2 | Y | ↑ | N | — | 0 | `Spark` | 1 | 12/0 | N | N | 4 |
| 35 | [`glass`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L311) | Solid | 2,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 1 |
| 36 | [`molten-glass`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L313) | Liquid | 2,500 | Y | ↓ | Y | CY | 224 | `MoltenGlass` | 1 | 180/0 | N | N | 2 |
| 37 | [`foam`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L316) | Gas | 6 | Y | ↑ | Y | — | 0 | `Foam` | 1 | 120/0 | N | N | 0 |

### Themed construction (38–80)
| ID | Stable name | Phase | ρ | M | D | X | L | ν | Kernel | R | A₀/B₀ | H | G | Pairs |
|---:|---|---|---:|:---:|:---:|:---:|:---:|---:|---|---:|---|:---:|:---:|---:|
| 38 | [`limestone-block`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L318) | Solid | 2,350 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 39 | [`sandstone-block`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L320) | Solid | 2,200 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 40 | [`granite-block`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L322) | Solid | 2,700 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 41 | [`cobblestone`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L324) | Solid | 2,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 42 | [`mossy-cobblestone`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L326) | Solid | 2,400 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 43 | [`red-brick`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L328) | Solid | 1,900 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 44 | [`lime-plaster`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L330) | Solid | 1,650 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 45 | [`wattle-and-daub`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L332) | Solid | 1,200 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 46 | [`oak-timber`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L334) | Solid | 720 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 47 | [`thatch`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L336) | Solid | 120 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 48 | [`terracotta-tile`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L338) | Solid | 2,000 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 49 | [`slate`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L340) | Solid | 2,750 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 50 | [`wrought-iron`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L342) | Solid | 7,800 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 51 | [`lead-sheet`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L344) | Solid | 11,340 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 52 | [`bronze`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L346) | Solid | 8,800 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 53 | [`copper`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L348) | Solid | 8,960 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 54 | [`verdigris-copper`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L350) | Solid | 8,600 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 55 | [`stained-glass`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L352) | Solid | 2,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 56 | [`packed-earth`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L354) | Solid | 1,800 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 57 | [`industrial-brick`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L356) | Solid | 1,950 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 58 | [`reinforced-concrete`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L358) | Solid | 2,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 59 | [`asphalt`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L360) | Solid | 2,300 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 60 | [`wet-asphalt`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L362) | Solid | 2,300 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 61 | [`wet-cobblestone`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L364) | Solid | 2,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 62 | [`steel-plate`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L366) | Solid | 7,850 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 63 | [`painted-steel`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L368) | Solid | 7,850 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 64 | [`corrugated-steel`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L370) | Solid | 7,850 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 65 | [`rusted-steel`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L372) | Solid | 7,200 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 66 | [`steel-grating`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L374) | Solid | 7,850 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 67 | [`chainlink`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L376) | Solid | 7,850 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 68 | [`steel-pipe`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L378) | Solid | 7,850 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 69 | [`copper-pipe`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L380) | Solid | 8,960 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 70 | [`ceramic-tile`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L382) | Solid | 2,300 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 71 | [`chemical-glass`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L384) | Solid | 2,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 72 | [`dark-glass`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L386) | Solid | 2,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 73 | [`rubber`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L388) | Solid | 1,100 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 74 | [`cable-bundle`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L390) | Solid | 1,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 75 | [`insulation`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L392) | Solid | 120 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 76 | [`hazard-stripe`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L394) | Solid | 7,850 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 77 | [`neon-cyan`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L396) | Solid | 2,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 78 | [`neon-magenta`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L398) | Solid | 2,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 79 | [`neon-amber`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L400) | Solid | 2,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 80 | [`led-white`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L402) | Solid | 2,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |

### MAT-002 building (81–131)
| ID | Stable name | Phase | ρ | M | D | X | L | ν | Kernel | R | A₀/B₀ | H | G | Pairs |
|---:|---|---|---:|:---:|:---:|:---:|:---:|---:|---|---:|---|:---:|:---:|---:|
| 81 | [`pine-planks`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L403) | Solid | 520 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 82 | [`birch-log`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L405) | Solid | 640 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 83 | [`oak-log`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L407) | Solid | 750 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 84 | [`walnut-panel`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L409) | Solid | 640 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 85 | [`mahogany-panel`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L411) | Solid | 700 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 86 | [`bamboo`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L413) | Solid | 400 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 87 | [`plywood`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L415) | Solid | 600 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 88 | [`driftwood`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L417) | Solid | 450 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 89 | [`cedar-shingles`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L419) | Solid | 380 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 90 | [`charred-timber`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L421) | Solid | 600 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 91 | [`cork`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L423) | Solid | 240 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 92 | [`wicker`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L425) | Solid | 300 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 93 | [`cardboard`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L427) | Solid | 690 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 94 | [`paper-screen`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L429) | Solid | 300 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 95 | [`tar-block`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L431) | Solid | 1,150 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 96 | [`acrylic-sheet`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L433) | Solid | 1,180 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 97 | [`moss-wall`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L435) | Solid | 900 | N | — | N | — | 0 | `Combustible` | 1 | 0/0 | Y | N | 0 |
| 98 | [`marble`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L437) | Solid | 2,700 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 1 |
| 99 | [`chalk-block`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L439) | Solid | 1,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 2 |
| 100 | [`basalt-columns`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L441) | Solid | 3,000 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 1 |
| 101 | [`obsidian`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L443) | Solid | 2,400 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 1 |
| 102 | [`adobe-brick`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L445) | Solid | 1,700 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 2 |
| 103 | [`raw-clay`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L447) | Solid | 1,800 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 3 |
| 104 | [`firebrick`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L449) | Solid | 2,100 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 105 | [`packed-snow`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L451) | Solid | 500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 5 |
| 106 | [`rock-salt-block`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L453) | Solid | 2,160 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 1 |
| 107 | [`gypsum-board`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L455) | Solid | 800 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 2 |
| 108 | [`quicklime-block`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L457) | Solid | 3,300 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 1 |
| 109 | [`rammed-earth`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L459) | Solid | 2,000 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 1 |
| 110 | [`sandbag`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L461) | Solid | 1,600 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 1 |
| 111 | [`terrazzo`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L463) | Solid | 2,400 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 112 | [`gabion`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L465) | Solid | 1,700 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 113 | [`zinc-sheet`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L467) | Solid | 7,140 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 1 |
| 114 | [`aluminium-panel`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L469) | Solid | 2,700 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 115 | [`magnesium-plate`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L471) | Solid | 1,740 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 2 |
| 116 | [`thermite-brick`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L473) | Solid | 4,000 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 2 |
| 117 | [`bare-iron`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L475) | Solid | 7,870 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 3 |
| 118 | [`gold-leaf`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L477) | Solid | 19,300 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 119 | [`brass-panel`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L479) | Solid | 8,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 120 | [`glass-block`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L481) | Solid | 2,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 1 |
| 121 | [`frosted-glass`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L483) | Solid | 2,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 1 |
| 122 | [`quartz-crystal`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L485) | Solid | 2,650 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 1 |
| 123 | [`uranium-glass`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L487) | Solid | 2,600 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 1 |
| 124 | [`sugar-glass`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L489) | Solid | 1,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 2 |
| 125 | [`wax-block`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L491) | Solid | 900 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 2 |
| 126 | [`sulfur-block`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L493) | Solid | 2,070 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 2 |
| 127 | [`phosphor-panel`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L495) | Solid | 1,820 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 1 |
| 128 | [`polymer-panel`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L497) | Solid | 950 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 2 |
| 129 | [`solar-panel`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L499) | Solid | 2,500 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 130 | [`carbon-fibre`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L501) | Solid | 1,600 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |
| 131 | [`heat-shield-tile`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp#L503) | Solid | 300 | N | — | N | — | 0 | `None` | 0 | 0/0 | Y | N | 0 |

`current_rule_available` is true for **all 131 valid** descriptors (including deliberately inert `None` kernels); invalid 10 has `valid=false` and `current_rule_available=false`. `Material::Gas` aliases Smoke (4). A stored Rocket B₀=2 means its default payload is Sand, not an arbitrary charge. Runtime `state_a` can be wider than the descriptor's initial byte (e.g. Water mass); sources set actual state during painting and conversion.

## 4. Exact rendering and initial visual state

`RGBA` is the **canonical byte** value `#RRGGBBAA`, not a claim about post-shader pixel color or HDR output. `ΔV` is the signed palette value-variation magnitude **before ×1.18 adjustment** at atlas build. `ΔHue` is the preset fractional hue excursion; `Flair` is its exact numeric LUT selector; `G` is projected native `RG8` condition: `A`, `B`, or literal `0`. Water uses normalized `state_a` (mass). The fallback emits only R8 IDs.

### Sandspiel-numbered slots
| ID | Material | RGBA8 `#RRGGBBAA` | ΔV | ΔHue | Flair ID/name | G projection |
|---:|---|---|---:|---:|---|---|
| 0 | empty | `#080B12FF` | 0.000 | 0.000 | 0 `NONE` | 0 |
| 1 | wall | `#525B6AFF` | 0.025 | 0.000 | 1 `MASONRY` | 0 |
| 2 | sand | `#DEAE4CFF` | 0.055 | 0.012 | 33 `POWDER` | 0 |
| 3 | water | `#2F7FD2FF` | 0.045 | 0.000 | 29 `WATER` | A |
| 4 | smoke | `#7A828FD2` | 0.060 | 0.000 | 34 `SMOKE` | A |
| 5 | cloner | `#B975ABFF` | 0.025 | 0.000 | 42 `CLONER` | 0 |
| 6 | fire | `#F6722AFF` | 0.140 | 0.006 | 30 `FLAME` | A |
| 7 | wood | `#744E30FF` | 0.055 | 0.012 | 4 `TIMBER` | B |
| 8 | lava | `#F14E1FFF` | 0.100 | 0.006 | 31 `MOLTEN` | 0 |
| 9 | ice | `#96DAEFFF` | 0.045 | 0.000 | 38 `ICE` | 0 |
| 10 | invalid | `#FF00FFFF` | 0.000 | 0.000 | 0 `NONE` | 0 |
| 11 | plant | `#47A64FFF` | 0.070 | 0.012 | 47 `PLANT` | A |
| 12 | acid | `#C8E430FF` | 0.080 | 0.006 | 39 `REACTIVE_LIQUID` | A |
| 13 | stone | `#7E7E84FF` | 0.045 | 0.012 | 2 `COBBLE` | B |
| 14 | dust | `#DAC6EEFF` | 0.075 | 0.000 | 33 `POWDER` | 0 |
| 15 | mite | `#CF4CDDFF` | 0.090 | 0.000 | 49 `MITE` | A |
| 16 | oil | `#4B4348FF` | 0.050 | 0.000 | 13 `OIL` | B |
| 17 | rocket | `#F4DCD7FF` | 0.040 | 0.000 | 50 `ROCKET` | A |
| 18 | fungus | `#C06AB1FF` | 0.080 | 0.012 | 48 `FUNGUS` | A |
| 19 | seed | `#E790BFFF` | 0.065 | 0.012 | 37 `ORGANIC` | A |

### Native reactive additions
| ID | Material | RGBA8 `#RRGGBBAA` | ΔV | ΔHue | Flair ID/name | G projection |
|---:|---|---|---:|---:|---|---|
| 20 | paste | `#9B8256FF` | 0.060 | 0.000 | 43 `PASTE` | 0 |
| 21 | slush | `#73BACFFF` | 0.060 | 0.000 | 44 `SLUSH` | 0 |
| 22 | steam | `#E6EEF2D8` | 0.075 | 0.000 | 35 `STEAM` | A |
| 23 | salt | `#ECE8DAFF` | 0.035 | 0.012 | 33 `POWDER` | 0 |
| 24 | brine | `#5CA6C2FF` | 0.050 | 0.000 | 29 `WATER` | 0 |
| 25 | sodium | `#E2DFC0FF` | 0.045 | 0.000 | 33 `POWDER` | 0 |
| 26 | gunpowder | `#453D39FF` | 0.060 | 0.000 | 33 `POWDER` | 0 |
| 27 | coal | `#2B292DFF` | 0.080 | 0.012 | 0 `NONE` | B |
| 28 | metal | `#97A1ABFF` | 0.045 | 0.000 | 41 `CHARGED_METAL` | B |
| 29 | rust | `#A64A2AFF` | 0.060 | 0.012 | 17 `RUSTED_METAL` | 0 |
| 30 | cement | `#8F8F84FF` | 0.035 | 0.000 | 43 `PASTE` | A |
| 31 | concrete | `#696C70FF` | 0.025 | 0.000 | 11 `CONCRETE` | 0 |
| 32 | toxic-sludge | `#2B6A22FF` | 0.040 | 0.006 | 39 `REACTIVE_LIQUID` | 0 |
| 33 | mercury | `#B8C0CBFF` | 0.060 | 0.000 | 40 `MERCURY` | 0 |
| 34 | spark | `#FFE85BFF` | 0.160 | 0.006 | 32 `SPARK` | A |
| 35 | glass | `#80CDDCD2` | 0.035 | 0.000 | 22 `GLASS` | 0 |
| 36 | molten-glass | `#FF9240FF` | 0.120 | 0.006 | 31 `MOLTEN` | A |
| 37 | foam | `#E8F3E1DC` | 0.055 | 0.000 | 36 `FOAM` | A |

### Themed construction
| ID | Material | RGBA8 `#RRGGBBAA` | ΔV | ΔHue | Flair ID/name | G projection |
|---:|---|---|---:|---:|---|---|
| 38 | limestone-block | `#C5BFAFFF` | 0.090 | 0.012 | 1 `MASONRY` | 0 |
| 39 | sandstone-block | `#C79C62FF` | 0.110 | 0.012 | 1 `MASONRY` | 0 |
| 40 | granite-block | `#777782FF` | 0.120 | 0.000 | 1 `MASONRY` | 0 |
| 41 | cobblestone | `#77746CFF` | 0.140 | 0.012 | 2 `COBBLE` | 0 |
| 42 | mossy-cobblestone | `#65705AFF` | 0.160 | 0.012 | 2 `COBBLE` | 0 |
| 43 | red-brick | `#A3503BFF` | 0.110 | 0.012 | 1 `MASONRY` | 0 |
| 44 | lime-plaster | `#D2CDB9FF` | 0.080 | 0.012 | 3 `PLASTER` | 0 |
| 45 | wattle-and-daub | `#BA9B72FF` | 0.120 | 0.012 | 3 `PLASTER` | 0 |
| 46 | oak-timber | `#6F4528FF` | 0.140 | 0.012 | 4 `TIMBER` | B |
| 47 | thatch | `#B49349FF` | 0.130 | 0.012 | 5 `THATCH` | B |
| 48 | terracotta-tile | `#B95B3CFF` | 0.120 | 0.012 | 6 `ROOF_TILE` | 0 |
| 49 | slate | `#465363FF` | 0.110 | 0.000 | 7 `SLATE` | 0 |
| 50 | wrought-iron | `#323A40FF` | 0.140 | 0.000 | 8 `HAMMERED_METAL` | 0 |
| 51 | lead-sheet | `#69737DFF` | 0.080 | 0.000 | 14 `METAL_PLATE` | 0 |
| 52 | bronze | `#A27138FF` | 0.130 | 0.000 | 8 `HAMMERED_METAL` | 0 |
| 53 | copper | `#B86C40FF` | 0.120 | 0.000 | 8 `HAMMERED_METAL` | 0 |
| 54 | verdigris-copper | `#4F8C79FF` | 0.140 | 0.012 | 8 `HAMMERED_METAL` | 0 |
| 55 | stained-glass | `#477FA8D8` | 0.100 | 0.000 | 9 `STAINED_GLASS` | 0 |
| 56 | packed-earth | `#7C5B3BFF` | 0.160 | 0.012 | 10 `EARTH` | 0 |
| 57 | industrial-brick | `#743F36FF` | 0.130 | 0.012 | 1 `MASONRY` | 0 |
| 58 | reinforced-concrete | `#777B80FF` | 0.120 | 0.000 | 11 `CONCRETE` | 0 |
| 59 | asphalt | `#292D32FF` | 0.100 | 0.000 | 12 `ASPHALT` | 0 |
| 60 | wet-asphalt | `#151C24FF` | 0.120 | 0.000 | 45 `WET_SURFACE` | 0 |
| 61 | wet-cobblestone | `#414A4EFF` | 0.150 | 0.012 | 45 `WET_SURFACE` | 0 |
| 62 | steel-plate | `#7E8D99FF` | 0.090 | 0.000 | 14 `METAL_PLATE` | 0 |
| 63 | painted-steel | `#316477FF` | 0.100 | 0.000 | 15 `PAINTED_METAL` | 0 |
| 64 | corrugated-steel | `#6D7D86FF` | 0.120 | 0.000 | 16 `CORRUGATED` | 0 |
| 65 | rusted-steel | `#7C3F2BFF` | 0.150 | 0.012 | 17 `RUSTED_METAL` | 0 |
| 66 | steel-grating | `#4A555DFF` | 0.180 | 0.000 | 18 `GRATING` | 0 |
| 67 | chainlink | `#65747BD0` | 0.100 | 0.000 | 19 `CHAINLINK` | 0 |
| 68 | steel-pipe | `#667781FF` | 0.110 | 0.000 | 20 `PIPE` | 0 |
| 69 | copper-pipe | `#A55C36FF` | 0.130 | 0.012 | 20 `PIPE` | 0 |
| 70 | ceramic-tile | `#C8D2CBFF` | 0.070 | 0.000 | 21 `CERAMIC` | 0 |
| 71 | chemical-glass | `#6BC4B5B8` | 0.080 | 0.000 | 22 `GLASS` | 0 |
| 72 | dark-glass | `#253C4CC0` | 0.080 | 0.000 | 22 `GLASS` | 0 |
| 73 | rubber | `#242529FF` | 0.090 | 0.000 | 23 `RUBBER` | 0 |
| 74 | cable-bundle | `#3C3544FF` | 0.130 | 0.000 | 24 `CABLES` | 0 |
| 75 | insulation | `#D6C55CFF` | 0.150 | 0.012 | 25 `INSULATION` | 0 |
| 76 | hazard-stripe | `#E3B62FFF` | 0.050 | 0.000 | 26 `HAZARD` | 0 |
| 77 | neon-cyan | `#37F3E4FF` | 0.035 | 0.006 | 27 `NEON` | 0 |
| 78 | neon-magenta | `#FF3DB8FF` | 0.035 | 0.006 | 27 `NEON` | 0 |
| 79 | neon-amber | `#FFB52EFF` | 0.040 | 0.006 | 27 `NEON` | 0 |
| 80 | led-white | `#ECF8FFFF` | 0.025 | 0.000 | 28 `LED` | 0 |

### MAT-002 building
| ID | Material | RGBA8 `#RRGGBBAA` | ΔV | ΔHue | Flair ID/name | G projection |
|---:|---|---|---:|---:|---|---|
| 81 | pine-planks | `#C4985CFF` | 0.110 | 0.012 | 46 `BUILDING` | B |
| 82 | birch-log | `#D6CEBEFF` | 0.090 | 0.006 | 46 `BUILDING` | B |
| 83 | oak-log | `#5C402CFF` | 0.140 | 0.012 | 46 `BUILDING` | B |
| 84 | walnut-panel | `#4E3221FF` | 0.110 | 0.012 | 46 `BUILDING` | B |
| 85 | mahogany-panel | `#7C3624FF` | 0.110 | 0.012 | 46 `BUILDING` | B |
| 86 | bamboo | `#B6A656FF` | 0.100 | 0.012 | 46 `BUILDING` | B |
| 87 | plywood | `#BE9866FF` | 0.090 | 0.012 | 46 `BUILDING` | B |
| 88 | driftwood | `#968F83FF` | 0.120 | 0.006 | 46 `BUILDING` | B |
| 89 | cedar-shingles | `#985638FF` | 0.130 | 0.012 | 46 `BUILDING` | B |
| 90 | charred-timber | `#262121FF` | 0.120 | 0.000 | 46 `BUILDING` | B |
| 91 | cork | `#A2724AFF` | 0.140 | 0.012 | 46 `BUILDING` | B |
| 92 | wicker | `#B48C54FF` | 0.120 | 0.012 | 46 `BUILDING` | B |
| 93 | cardboard | `#B28C5EFF` | 0.080 | 0.006 | 46 `BUILDING` | B |
| 94 | paper-screen | `#E4DAC0EC` | 0.050 | 0.000 | 46 `BUILDING` | B |
| 95 | tar-block | `#1A181BFF` | 0.080 | 0.000 | 46 `BUILDING` | B |
| 96 | acrylic-sheet | `#C4E2ECB0` | 0.040 | 0.000 | 46 `BUILDING` | B |
| 97 | moss-wall | `#466834FF` | 0.150 | 0.012 | 46 `BUILDING` | B |
| 98 | marble | `#E2DFD8FF` | 0.060 | 0.000 | 46 `BUILDING` | 0 |
| 99 | chalk-block | `#EAE7DCFF` | 0.050 | 0.000 | 46 `BUILDING` | 0 |
| 100 | basalt-columns | `#36383DFF` | 0.120 | 0.000 | 46 `BUILDING` | 0 |
| 101 | obsidian | `#181320FF` | 0.080 | 0.006 | 46 `BUILDING` | 0 |
| 102 | adobe-brick | `#B27C54FF` | 0.110 | 0.012 | 46 `BUILDING` | 0 |
| 103 | raw-clay | `#9E6A50FF` | 0.080 | 0.006 | 46 `BUILDING` | 0 |
| 104 | firebrick | `#C89862FF` | 0.100 | 0.012 | 46 `BUILDING` | 0 |
| 105 | packed-snow | `#E8F0F8FF` | 0.040 | 0.000 | 46 `BUILDING` | 0 |
| 106 | rock-salt-block | `#DEC4BEFF` | 0.080 | 0.006 | 46 `BUILDING` | 0 |
| 107 | gypsum-board | `#DEDCD4FF` | 0.035 | 0.000 | 46 `BUILDING` | 0 |
| 108 | quicklime-block | `#ECEADEFF` | 0.050 | 0.000 | 46 `BUILDING` | 0 |
| 109 | rammed-earth | `#AC724AFF` | 0.120 | 0.012 | 46 `BUILDING` | 0 |
| 110 | sandbag | `#AA9264FF` | 0.100 | 0.006 | 46 `BUILDING` | 0 |
| 111 | terrazzo | `#C8C4BAFF` | 0.050 | 0.000 | 46 `BUILDING` | 0 |
| 112 | gabion | `#7A7870FF` | 0.150 | 0.006 | 46 `BUILDING` | 0 |
| 113 | zinc-sheet | `#98A2A8FF` | 0.080 | 0.000 | 46 `BUILDING` | 0 |
| 114 | aluminium-panel | `#B8C0C8FF` | 0.050 | 0.000 | 46 `BUILDING` | 0 |
| 115 | magnesium-plate | `#C6C8CAFF` | 0.060 | 0.000 | 46 `BUILDING` | 0 |
| 116 | thermite-brick | `#7C4A3EFF` | 0.120 | 0.006 | 46 `BUILDING` | 0 |
| 117 | bare-iron | `#5A5E64FF` | 0.090 | 0.000 | 46 `BUILDING` | 0 |
| 118 | gold-leaf | `#DEB23EFF` | 0.080 | 0.006 | 46 `BUILDING` | 0 |
| 119 | brass-panel | `#C4A048FF` | 0.070 | 0.006 | 46 `BUILDING` | 0 |
| 120 | glass-block | `#9CD2DCCC` | 0.040 | 0.000 | 46 `BUILDING` | 0 |
| 121 | frosted-glass | `#CEE2E8D6` | 0.040 | 0.000 | 46 `BUILDING` | 0 |
| 122 | quartz-crystal | `#E2ECF4E0` | 0.060 | 0.000 | 46 `BUILDING` | 0 |
| 123 | uranium-glass | `#98E85ED2` | 0.040 | 0.000 | 46 `BUILDING` | 0 |
| 124 | sugar-glass | `#ECD49EC4` | 0.050 | 0.000 | 46 `BUILDING` | 0 |
| 125 | wax-block | `#EEE2B8FF` | 0.040 | 0.000 | 46 `BUILDING` | 0 |
| 126 | sulfur-block | `#E2CE3AFF` | 0.090 | 0.006 | 46 `BUILDING` | 0 |
| 127 | phosphor-panel | `#B0DCACFF` | 0.040 | 0.000 | 46 `BUILDING` | 0 |
| 128 | polymer-panel | `#3E7AB4FF` | 0.050 | 0.000 | 46 `BUILDING` | 0 |
| 129 | solar-panel | `#1A2E5EFF` | 0.040 | 0.000 | 46 `BUILDING` | 0 |
| 130 | carbon-fibre | `#222429FF` | 0.050 | 0.000 | 46 `BUILDING` | 0 |
| 131 | heat-shield-tile | `#1A1A1DFF` | 0.060 | 0.000 | 46 `BUILDING` | 0 |

`G` is a **render-only projection** of authoritative state. Important examples: Water mass (`A`), Smoke/Fire/Steam/Foam lifetime (`A`), Plant/Fungus energy (`A`), Stone collapsed flag (`B`), Wood/Oil/Coal/building burn (`B`), base Metal charge (`B`), Cement cure (`A`), Rocket flight (`A`). A `0` projection does not mean the simulation has no internal state or kinetics.

## 5. All authored pair interactions

All **56** rules are unordered in input matching but **role-preserving** in products. `A+B → A′+B′` respects the order shown; swapping the input cells swaps their output roles. Probability is conditional on a kernel reaching an eligible contact and drawing a uniform byte `roll ∈ [0,255]`; a rule fires on `roll ≤ T`, so **exact per-opportunity selection = `(T+1)/256`**, not a per-second chance. The native chemistry lane is normally 4 ticks. Some contacts can be missed; MAT-001 adds persistent-contact wake scheduling.
Channel legend: `TH` thermal phase, `DC` dissolution/corrosion, `CV` conversion/products, `CB` combustion, `EL` electrical, `CG` cure/growth/state, `EM` authoritative emissions/byproducts.

### Frozen Current oracle (14 rules)
| # | Rule ID | Input pair (A + B) | Products (A′ + B′) | T / 255 | Exact chance | Channels |
|---:|---|---|---|---:|---:|---|
| 0 | [ `int.pair.lava-water.quench.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L155) | lava + water | **stone + steam** | 255 | 256/256 | TH,CV,EM |
| 1 | [ `int.pair.fire-water.extinguish.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L164) | fire + water | **smoke + steam** | 255 | 256/256 | TH,CB,EM |
| 2 | [ `int.pair.water-salt.dissolve.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L173) | water + salt | **brine + brine** | 255 | 256/256 | DC,CV |
| 3 | [ `int.pair.water-sodium.react.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L181) | water + sodium | **steam + fire** | 255 | 256/256 | CV,CB,EM |
| 4 | [ `int.pair.brine-sodium.react.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L190) | brine + sodium | **steam + fire** | 255 | 256/256 | CV,CB,EM |
| 5 | [ `int.pair.water-toxic-sludge.purify.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L199) | water + toxic-sludge | **water + water** | 255 | 256/256 | DC,CV |
| 6 | [ `int.pair.steam-ice.condense.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L206) | steam + ice | **water + ice** | 32 | 33/256 | TH |
| 7 | [ `int.pair.water-molten-glass.quench.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L213) | water + molten-glass | **steam + glass** | 255 | 256/256 | TH,CV,EM |
| 8 | [ `int.pair.lava-glass.melt.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L222) | lava + glass | **lava + molten-glass** | 255 | 256/256 | TH,CV |
| 9 | [ `int.pair.acid-metal.corrosion.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L229) | acid + metal | **smoke + rust** | 96 | 97/256 | DC,CV,EM |
| 10 | [ `int.pair.fire-gunpowder.ignite.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L237) | fire + gunpowder | **fire + fire** | 255 | 256/256 | CB,CV |
| 11 | [ `int.pair.spark-gunpowder.ignite.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L244) | spark + gunpowder | **empty + fire** | 255 | 256/256 | EL,CB,CV |
| 12 | [ `int.pair.spark-oil.ignite.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L252) | spark + oil | **empty + fire** | 255 | 256/256 | EL,CB,CV |
| 13 | [ `int.pair.fire-brine.evaporate.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L260) | fire + brine | **steam + salt** | 64 | 65/256 | TH,CB,CV |

### MAT-002 building addition (42 rules)
| # | Rule ID | Input pair (A + B) | Products (A′ + B′) | T / 255 | Exact chance | Channels |
|---:|---|---|---|---:|---:|---|
| 14 | [ `int.pair.acid-marble.effervesce.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L269) | acid + marble | **foam + salt** | 192 | 193/256 | DC,CV,EM |
| 15 | [ `int.pair.acid-chalk.effervesce.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L278) | acid + chalk-block | **foam + dust** | 224 | 225/256 | DC,CV,EM |
| 16 | [ `int.pair.water-chalk.soften.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L287) | water + chalk-block | **water + paste** | 6 | 7/256 | DC,CV |
| 17 | [ `int.pair.lava-basalt.remelt.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L295) | lava + basalt-columns | **lava + lava** | 6 | 7/256 | TH,CV |
| 18 | [ `int.pair.lava-obsidian.remelt.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L303) | lava + obsidian | **lava + molten-glass** | 24 | 25/256 | TH,CV |
| 19 | [ `int.pair.water-adobe.erode.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L311) | water + adobe-brick | **water + paste** | 24 | 25/256 | DC,CV |
| 20 | [ `int.pair.lava-adobe.fire.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L319) | lava + adobe-brick | **lava + red-brick** | 64 | 65/256 | TH,CV |
| 21 | [ `int.pair.fire-raw-clay.fire.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L327) | fire + raw-clay | **fire + terracotta-tile** | 48 | 49/256 | TH,CV |
| 22 | [ `int.pair.lava-raw-clay.fire.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L336) | lava + raw-clay | **lava + terracotta-tile** | 128 | 129/256 | TH,CV |
| 23 | [ `int.pair.water-raw-clay.slake.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L344) | water + raw-clay | **water + paste** | 10 | 11/256 | DC,CV |
| 24 | [ `int.pair.fire-packed-snow.melt.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L352) | fire + packed-snow | **steam + water** | 255 | 256/256 | TH,CB,EM |
| 25 | [ `int.pair.lava-packed-snow.quench.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L362) | lava + packed-snow | **stone + steam** | 255 | 256/256 | TH,CV,EM |
| 26 | [ `int.pair.steam-packed-snow.condense.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L372) | steam + packed-snow | **water + packed-snow** | 32 | 33/256 | TH |
| 27 | [ `int.pair.salt-packed-snow.thaw.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L380) | salt + packed-snow | **brine + slush** | 64 | 65/256 | TH,DC,CV |
| 28 | [ `int.pair.molten-glass-packed-snow.quench.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L390) | molten-glass + packed-snow | **glass + steam** | 255 | 256/256 | TH,CV,EM |
| 29 | [ `int.pair.water-rock-salt.dissolve.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L400) | water + rock-salt-block | **brine + salt** | 48 | 49/256 | DC,CV |
| 30 | [ `int.pair.water-gypsum.soak.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L408) | water + gypsum-board | **water + paste** | 16 | 17/256 | DC,CV |
| 31 | [ `int.pair.fire-gypsum.calcine.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L416) | fire + gypsum-board | **fire + dust** | 6 | 7/256 | TH,CV |
| 32 | [ `int.pair.water-quicklime.slake.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L424) | water + quicklime-block | **steam + cement** | 128 | 129/256 | TH,CV,EM |
| 33 | [ `int.pair.water-rammed-earth.erode.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L434) | water + rammed-earth | **water + sand** | 6 | 7/256 | DC,CV |
| 34 | [ `int.pair.fire-sandbag.burn.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L442) | fire + sandbag | **fire + sand** | 40 | 41/256 | CB,CV |
| 35 | [ `int.pair.acid-zinc.dissolve.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L450) | acid + zinc-sheet | **smoke + salt** | 192 | 193/256 | DC,CV,EM |
| 36 | [ `int.pair.fire-magnesium.ignite.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L459) | fire + magnesium-plate | **fire + fire** | 96 | 97/256 | CB,CV |
| 37 | [ `int.pair.spark-magnesium.ignite.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L467) | spark + magnesium-plate | **empty + fire** | 255 | 256/256 | EL,CB,CV |
| 38 | [ `int.pair.spark-thermite.ignite.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L476) | spark + thermite-brick | **empty + lava** | 255 | 256/256 | EL,CB,TH,CV |
| 39 | [ `int.pair.fire-thermite.ignite.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L486) | fire + thermite-brick | **lava + lava** | 64 | 65/256 | CB,TH,CV |
| 40 | [ `int.pair.water-bare-iron.rust.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L496) | water + bare-iron | **water + rusted-steel** | 3 | 4/256 | DC,CV |
| 41 | [ `int.pair.brine-bare-iron.rust.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L504) | brine + bare-iron | **brine + rusted-steel** | 12 | 13/256 | DC,CV |
| 42 | [ `int.pair.acid-bare-iron.corrode.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L512) | acid + bare-iron | **smoke + rust** | 160 | 161/256 | DC,CV,EM |
| 43 | [ `int.pair.lava-glass-block.melt.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L521) | lava + glass-block | **lava + molten-glass** | 255 | 256/256 | TH,CV |
| 44 | [ `int.pair.lava-frosted-glass.melt.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L529) | lava + frosted-glass | **lava + molten-glass** | 255 | 256/256 | TH,CV |
| 45 | [ `int.pair.lava-quartz.fuse.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L537) | lava + quartz-crystal | **lava + molten-glass** | 8 | 9/256 | TH,CV |
| 46 | [ `int.pair.lava-uranium-glass.melt.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L545) | lava + uranium-glass | **lava + molten-glass** | 255 | 256/256 | TH,CV |
| 47 | [ `int.pair.water-sugar-glass.dissolve.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L553) | water + sugar-glass | **water + paste** | 48 | 49/256 | DC,CV |
| 48 | [ `int.pair.fire-sugar-glass.caramelise.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L561) | fire + sugar-glass | **smoke + coal** | 64 | 65/256 | TH,CB,CV,EM |
| 49 | [ `int.pair.fire-wax.melt.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L571) | fire + wax-block | **fire + oil** | 64 | 65/256 | TH,CV |
| 50 | [ `int.pair.lava-wax.melt.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L579) | lava + wax-block | **lava + oil** | 255 | 256/256 | TH,CV |
| 51 | [ `int.pair.fire-sulfur.burn.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L587) | fire + sulfur-block | **smoke + fire** | 96 | 97/256 | CB,CV,EM |
| 52 | [ `int.pair.lava-sulfur.ignite.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L596) | lava + sulfur-block | **lava + fire** | 64 | 65/256 | CB,CV |
| 53 | [ `int.pair.fire-phosphor.ignite.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L604) | fire + phosphor-panel | **fire + fire** | 128 | 129/256 | CB,CV |
| 54 | [ `int.pair.lava-polymer.melt.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L612) | lava + polymer-panel | **lava + oil** | 255 | 256/256 | TH,CV |
| 55 | [ `int.pair.fire-polymer.melt.v1` ](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L620) | fire + polymer-panel | **smoke + oil** | 32 | 33/256 | TH,CB,CV,EM |

**Pair rules are not exhaustive chemistry.** Non-pair kernels can ignite, dissolve, freeze, grow, charge, emit or cure without any listed authored pair. Conversely, `Pairs=0` in the descriptor table does not imply acid immunity or absence of intrinsic lifecycle. MAT-002 pair-reactive surfaces use `RuleKernel::None` and rely on their reactive neighbours' kernel lane; Acid's broad neighbourhood reaction may compete with an Acid pair rule.

## 6. Intrinsic and neighbourhood kernels

The INT substrate also registers **19 specialized mechanisms** for documentation/provenance while **`World` keeps execution authority**. Kinetic movement and collision are not INT chemistry.
| Rule | Material | Trigger | Kernel | Registered current semantics |
|---|---|---|---|---|
| [`int.kernel.steam.condense.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L759) | steam | IntrinsicState | `Steam` | lifetime expiry converts Steam to Water |
| [`int.kernel.fire.ignite-smoke.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L763) | fire | NeighbourhoodContext | `Fire` | sampled ignition and Fire lifetime ending as Smoke |
| [`int.kernel.combustible.burn.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L769) | wood | NeighbourhoodContext | `Combustible` | active burn, Water extinguishing, consumption and Fire emission |
| [`int.kernel.gunpowder.hot-ignite.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L776) | gunpowder | NeighbourhoodContext | `Gunpowder` | hot-neighbour ignition |
| [`int.kernel.coal.burn.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L780) | coal | NeighbourhoodContext | `Coal` | hot ignition, Water/Brine extinguishing, Dust/Fire/Smoke products |
| [`int.kernel.spark.charge-ignite.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L788) | spark | NeighbourhoodContext | `Spark` | adjacent base-Metal charging or sampled combustible ignition; Spark locomotion excluded |
| [`int.kernel.metal.charge.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L795) | metal | NeighbourhoodContext | `Metal` | base-Metal charge propagation and charged-Metal Water-to-Steam consequence |
| [`int.kernel.cement.cure.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L802) | cement | NeighbourhoodContext | `Cement` | air/Water/Brine/Concrete-context cure ending as Concrete |
| [`int.kernel.molten-glass.cool.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L807) | molten-glass | NeighbourhoodContext | `MoltenGlass` | hot-neighbour cooling reset and eventual conversion to Glass |
| [`int.kernel.lava.contact.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L812) | lava | NeighbourhoodContext | `Lava` | sampled Ice-to-Water conversion or neighbour ignition; movement excluded |
| [`int.kernel.ice.phase.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L820) | ice | NeighbourhoodContext | `Ice` | hot-neighbour melt and sampled Water freeze |
| [`int.kernel.acid.corrosion.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L825) | acid | NeighbourhoodContext | `Acid` | sampled broad corrosion of non-Empty/non-Wall/non-Acid targets; movement excluded |
| [`int.kernel.cloner.capture-emit.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L832) | cloner | NeighbourhoodContext | `Cloner` | capture neighbour identity and emit initialized copies |
| [`int.kernel.plant.growth.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L838) | plant | NeighbourhoodContext | `Plant` | growth plus hot-neighbour ignition |
| [`int.kernel.fungus.growth.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L844) | fungus | NeighbourhoodContext | `Fungus` | growth plus hot-neighbour ignition |
| [`int.kernel.seed.germinate.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L850) | seed | NeighbourhoodContext | `Seed` | substrate/context germination plus hot-neighbour ignition |
| [`int.kernel.mite.environment.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L857) | mite | NeighbourhoodContext | `Mite` | environmental death/consumption semantics; locomotion excluded |
| [`int.kernel.rocket.trigger.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L862) | rocket | NeighbourhoodContext | `Rocket` | payload validation/capture and hot trigger state; ballistic motion excluded |
| [`int.kernel.foam.lifecycle.v1`](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp#L867) | foam | IntrinsicState | `Foam` | bounded intrinsic lifetime/disappearance |

### Exact high-impact kernel constants (native `World`)
| Mechanism | Implemented value / condition | Interpretation |
|---|---|---|
| Cadence | transport eligible each tick; lifecycle typically every **2**; chemistry/contact every **4**; Smoke decay every **8**; Ice Water-freezing sample every **16**; ambient Fire ignition sample every **120** | Deterministic lanes, not guaranteed wall-clock deadlines |
| Smoke | initial `A=240`; Moore-neighbour Smoke count `≥5` → decrement **2**, else **1** per due decay; expires to Empty | Crowding-dependent thinning |
| Fire | initial `A=240`; ambient sampled ignition `240`; lifetime decrement **1** per active update; expiry → Smoke | One sampled neighbour on slow ambient lane |
| Combustible | burn `B>0`; decrement **1** on due lifecycle; `B≤1` → Empty; when `(B & 7)==0`, emit Fire with `A=32` into sampled Empty; adjacent Water resets burn to **0** | Includes Wood, Oak Timber, Thatch, 81–97; ignition trigger elsewhere |
| Gunpowder / Dust | Gunpowder hot contact → Fire `A=64`; Dust hot contact → Fire `A=40` | Source kernel transitions |
| Coal | ignition burn `B=160`; Water/Brine extinguish `B→0`; final residue Dust ID **14**; every `(B & 7)==0` emit Fire or Smoke; `(B & 15)==0` selects Fire | Dust's light-purple color is not a separate Ash material |
| Oil | ignition `B=64`; extinction on Water; each due burn `B−1`; `(B & 3)==0` emits Fire `A=32`; expiry → Empty | Oil is allowed to burn, even though it is a liquid |
| Base Metal + Spark | Spark writes base Metal `B=24`; charged Metal neighbours receive `floor(charge/2)`; when `(charge & 3)==0`, sampled Water → Steam `A=90` | Decorative metal IDs do not inherit the charge kernel |
| Cement | initial cure `A=180`; due cure decrement: air **1**, Concrete **2**, Water/Brine **4** (priority Water > Concrete > air); zero cure → Concrete | Curing depends on neighbour context |
| Molten Glass | initial cooling `A=180`; hot neighbour resets to **180**, otherwise due cooling `−1`; zero → Glass | Thermal contact only at due lane |
| Lava | sampled Ice → full Water; otherwise sampled ignition `64` | Separate from authored Lava+Water compact pair |
| Ice | hot neighbour → Water; Water-freezing sample on **16-tick** lane | No global temperature-based Ice thermodynamics |
| Acid | initial `A=255`; eligible sampled corrosion reduces source strength by **24**; target → Empty, source disappears at strength 0 | Broad corrosion excludes Empty/Wall/Acid and competes with compact Acid rules |
| Plant / Fungus | initial energy `A=32`; newly ignited burn `B=48`; growth child energy `floor((energy−1)/2)` | Fungus timber substrates limited to base Wood/Oak Timber |
| Mite | heading `A=1` or `255`; `≥5` neighbouring Mites → Empty; Fire/Lava/Water/Oil contact kills | Agent with gravity, feeding and lateral preference |
| Rocket | payload `B=2` Sand default; trigger heat `> ambient + 400` or hot neighbour; launch direction `A=1..8`; flight target **2** cells away; blocked impact → Fire `A=24` | Temperature is a local predicate, not full thermal material simulation |
| Seed | supported (Sand/Plant/Fungus) germination `A=8,B=1`; stage 0 → Plant `A=16`; hot neighbour → Fire `A=24` | Kinetic seed until germination |
| Foam / Steam | Foam initial `A=120` expires → Empty; Steam initial `A=180` expires → full Water | Actual expiry depends on scheduled processing |

These are exact values for the **default native kernels at this source commit**, not a claim that every candidate/opt-in liquid law uses them. A kernel may run only after a successful motion/contact opportunity and may be suspended by block activity. Refer to [World implementation](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/src/world.cpp) for ordering, `ignite` and `is_hot` helper semantics.

## 7. Physics, transport and liquid parameters

### Density / permeability / hard terrain
| Property | Default / exact rule | Scope |
|---|---|---|
| Downward density exchange | source `D=Down`, `ρ(source)>ρ(target)`, target `X=true`, both valid; nonzero downward displacement | Source initiates; descriptor values alone are insufficient |
| Upward density exchange | source `D=Up`, `ρ(source)<ρ(target)`, target `X=true`, both valid; upward displacement | Gases/foams may displace accepting denser targets |
| Powder ↔ powder | **Always reject** density-driven exchange, regardless of ρ | Grains move into real Empty cells |
| Oil → powder | **Reject** Oil-initiated penetration of powder; heavier powder may sink into Oil | Asymmetric exception |
| Mercury ↔ powder | **1 opportunity per 30 ticks** for eligible density exchange; viscosity independent | Empty-cell fall remains full-speed |
| Other native liquid ↔ powder | **1 opportunity per tick** after density eligibility (Oil special-case above) | Separate from Water free-mass transport |
| Intact Stone | `state_b=0` braced Stone is protected from density displacement; granular Stone `state_b=1` can yield | State-dependent override |
| Granular support, down | contact grain supported **and at least 8/9** samples stable within local 3×3 at x−1..x+1, y..y+2 | Hard/qualifying grains count |
| Granular resistance, side/up | **9/9** stable in centred 3×3 | Separate from downward bearing |
| Physical hard surface | IDs **1,5,7,9,28,31,35,38–131** | Rapier/character occlusion; chainlink/grating remain solid unless Empty holes are authored |

### Water and viscous-liquid numerical law
| Value | Current default | Meaning |
|---|---|---|
| Water material ID | **3** | Only default `FreeMass` material |
| Water quantity carrier | `state_a=1..255` mass; Empty=0 | 8-bit default, full painted cell **255** |
| Water experiment policy | v**1**; `mass_bits=8`, permitted **3..8**; `coherence_ticks=12`, permitted **0..12** | Opt-in normalized policy configuration |
| Mass max / film / tolerance | **255 / 48 / 1** at 8 bits | `maximum=2^bits−1`; quantized film `48/255` and tolerance `1/255` |
| Water lateral transfer | `floor(3×positive_mass_difference/4)`, capped by source amount and destination capacity, no move if `source≤target+1` | Before further per-mode/policy restrictions |
| Reference discrete lateral rate | `1 + floor(((255−ν)×(max_rate−1)+127)/255)`; default `max_rate=24`; none→0 | Not a native kernel radius or pressure law |
| Lateral viscosity transfer | `max(1, floor((requested×(256−ν)+255)/256))` for positive requested transfer and active lateral mode | Viscosity affects lateral transfer, not gravity |
| FreeMass vs CellularYield | Water=`FM`; all **10** other liquids (including Brine)=`CY` | No universal unified liquid model |

### Construction-time transport profile schema v1 (ordinary Baseline)
| Control | Baseline | Permitted range / constraint |
|---|---:|---|
| `mixing` | **0** | 0..255 |
| `carrying` | **0** | 0..255, only Water→Sand/Dust/Rust screened in v1 |
| `pickup` | **64** | 0..255 disturbance units |
| `packing` | **8** | 0..32 units per occupied neighbour |
| `erosion` | **0** | 0/1 |
| `permeability` | **1** tick (Mercury/powder **30**) | 1..60 ticks |
| `horizontal` | **2** candidates | 1..2 |
| `cadence` | **1** tick | 1..60 ticks |
| Serialized transport scope | **81** material IDs: 0–80 | ID≥81 uses safe default (`pair`, `cadence_for`, `horizontal_for`) |
| Packed profile integers | **39,529** | `1 + 81×2 + 81×81×6` |

Opt-in tuned profiles resolve **schema → family → material → pair** and require a copied World/restart, not live shared descriptor mutation. The transport profile **is not** the same as seven INT semantic families or source material categorization. Default gameplay mixing/erosion carrying remain disabled. See [transport_policy.hpp](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/transport_policy.hpp), [water_experiment_policy.hpp](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/water_experiment_policy.hpp) and [Transport contract](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/docs/systems/flow-transport-and-profiles.md).

## 8. Appearance programme and implementation boundaries

### Palette LUT and flair
The startup palette atlas is **64×256 RGBA8** (64 stable variations per material row); the condition/program texture is **4×256 RGBA16F**. All **50 non-neutral flair classes** (IDs 1–50) plus neutral 0 are defined in `CyberMaterialAppearanceLut`. The 51 MAT-002 materials all select `FLAIR_BUILDING=46`, but the shader branches on their ID to choose distinct procedural finishes. The variation curve applies factor **1.18** and exponent **0.82**; inverse saturation adjustment multiplier **0.24**. Procedural structures anchor to world pixels, not camera coordinates.
| Flair code | Name |
|---:|---|
| 0 | `NONE` |
| 1 | `MASONRY` |
| 2 | `COBBLE` |
| 3 | `PLASTER` |
| 4 | `TIMBER` |
| 5 | `THATCH` |
| 6 | `ROOF_TILE` |
| 7 | `SLATE` |
| 8 | `HAMMERED_METAL` |
| 9 | `STAINED_GLASS` |
| 10 | `EARTH` |
| 11 | `CONCRETE` |
| 12 | `ASPHALT` |
| 13 | `OIL` |
| 14 | `METAL_PLATE` |
| 15 | `PAINTED_METAL` |
| 16 | `CORRUGATED` |
| 17 | `RUSTED_METAL` |
| 18 | `GRATING` |
| 19 | `CHAINLINK` |
| 20 | `PIPE` |
| 21 | `CERAMIC` |
| 22 | `GLASS` |
| 23 | `RUBBER` |
| 24 | `CABLES` |
| 25 | `INSULATION` |
| 26 | `HAZARD` |
| 27 | `NEON` |
| 28 | `LED` |
| 29 | `WATER` |
| 30 | `FLAME` |
| 31 | `MOLTEN` |
| 32 | `SPARK` |
| 33 | `POWDER` |
| 34 | `SMOKE` |
| 35 | `STEAM` |
| 36 | `FOAM` |
| 37 | `ORGANIC` |
| 38 | `ICE` |
| 39 | `REACTIVE_LIQUID` |
| 40 | `MERCURY` |
| 41 | `CHARGED_METAL` |
| 42 | `CLONER` |
| 43 | `PASTE` |
| 44 | `SLUSH` |
| 45 | `WET_SURFACE` |
| 46 | `BUILDING` |
| 47 | `PLANT` |
| 48 | `FUNGUS` |
| 49 | `MITE` |
| 50 | `ROCKET` |

### Exact condition-program overrides
Each row below is the verbatim parameter tuple passed to `_set_program_row` for one or more IDs. Fields are `tint RGBA`, `condition min,max`, `value low,high`, `alpha low,high`, `emission low,high`, `emission RGB(A)`. All unlisted IDs use the **default** programme: tint `(0,0,0,0)`, condition `(0,1)`, value `(1,1)`, alpha `(1,1)`, emission `(0,0)`, color `(0,0,0,0)`; flair is assigned separately. Stored values are intended for RGBA16F/HDR; do not truncate them to byte RGB.
| IDs sharing one parameter tuple | Tint RGBA | Condition | Value | Alpha | Emission | Emission colour |
|---|---|---|---|---|---|---|
| 4 | `(0.0,0.0,0.0,0.0)` | `(0.08,0.94)` | `(0.72,1.04)` | `(0.10,1.0)` | `(0.0,0.0)` | `(0.0,0.0,0.0,0.0)` |
| 5 | `(0.0,0.0,0.0,0.0)` | `(0.0,1.0)` | `(1.06,1.06)` | `(1.0,1.0)` | `(0.18,0.18)` | `(0.48,0.10,0.72,0.0)` |
| 6 | `(1.0,0.72,0.18,1.0)` | `(0.02,0.95)` | `(0.72,1.30)` | `(1.0,1.0)` | `(0.10,1.00)` | `(1.8,0.55,0.06,0.0)` |
| 7 | `(1.0,0.25,0.025,0.72)` | `(0.02,0.65)` | `(1.0,1.08)` | `(1.0,1.0)` | `(0.0,0.16)` | `(1.2,0.22,0.015,0.0)` |
| 8 | `(0.0,0.0,0.0,0.0)` | `(0.0,1.0)` | `(1.28,1.28)` | `(1.0,1.0)` | `(0.90,0.90)` | `(2.2,0.42,0.045,0.0)` |
| 16 | `(1.0,0.20,0.02,0.55)` | `(0.02,0.65)` | `(1.0,1.04)` | `(1.0,1.0)` | `(0.0,0.10)` | `(1.0,0.15,0.01,0.0)` |
| 22 | `(0.0,0.0,0.0,0.0)` | `(0.0,0.75)` | `(0.72,1.06)` | `(0.42,1.0)` | `(0.0,0.0)` | `(0.0,0.0,0.0,0.0)` |
| 27 | `(1.0,0.25,0.025,0.68)` | `(0.02,0.65)` | `(1.0,1.10)` | `(1.0,1.0)` | `(0.0,0.20)` | `(1.25,0.20,0.012,0.0)` |
| 28 | `(0.55,0.86,1.0,0.90)` | `(0.01,0.35)` | `(1.0,1.15)` | `(1.0,1.0)` | `(0.0,0.42)` | `(0.35,0.85,1.7,0.0)` |
| 30 | `(0.0,0.0,0.0,0.0)` | `(0.0,0.75)` | `(0.74,1.04)` | `(1.0,1.0)` | `(0.0,0.0)` | `(0.0,0.0,0.0,0.0)` |
| 34 | `(1.0,0.96,0.72,0.35)` | `(0.0,0.05)` | `(1.0,1.40)` | `(1.0,1.0)` | `(0.20,1.20)` | `(2.6,1.9,0.25,0.0)` |
| 36 | `(1.0,0.91,0.48,1.0)` | `(0.05,0.70)` | `(0.72,1.32)` | `(1.0,1.0)` | `(0.08,1.0)` | `(2.1,0.72,0.08,0.0)` |
| 37 | `(0.0,0.0,0.0,0.0)` | `(0.0,0.50)` | `(0.90,1.05)` | `(0.36,1.0)` | `(0.0,0.0)` | `(0.0,0.0,0.0,0.0)` |
| 46,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97 | `(1.0,0.28,0.025,0.74)` | `(0.02,0.65)` | `(1.0,1.10)` | `(1.0,1.0)` | `(0.0,0.18)` | `(1.25,0.24,0.016,0.0)` |
| 47 | `(1.0,0.38,0.035,0.82)` | `(0.02,0.62)` | `(1.0,1.14)` | `(1.0,1.0)` | `(0.0,0.26)` | `(1.45,0.30,0.018,0.0)` |
| 71 | `(0.0,0.0,0.0,0.0)` | `(0.0,1.0)` | `(1.04,1.04)` | `(1.0,1.0)` | `(0.055,0.055)` | `(0.08,0.42,0.30,0.0)` |
| 77 | `(0.0,0.0,0.0,0.0)` | `(0.0,1.0)` | `(1.18,1.18)` | `(1.0,1.0)` | `(0.92,0.92)` | `(0.08,2.10,1.72,0.0)` |
| 78 | `(0.0,0.0,0.0,0.0)` | `(0.0,1.0)` | `(1.16,1.16)` | `(1.0,1.0)` | `(0.92,0.92)` | `(2.25,0.06,1.20,0.0)` |
| 79 | `(0.0,0.0,0.0,0.0)` | `(0.0,1.0)` | `(1.16,1.16)` | `(1.0,1.0)` | `(0.90,0.90)` | `(2.20,0.82,0.04,0.0)` |
| 80 | `(0.0,0.0,0.0,0.0)` | `(0.0,1.0)` | `(1.12,1.12)` | `(1.0,1.0)` | `(0.36,0.36)` | `(1.45,1.72,2.05,0.0)` |
| 17 | `(1.0,0.92,0.62,0.55)` | `(0.0,0.004)` | `(1.0,1.30)` | `(1.0,1.0)` | `(0.0,1.60)` | `(4.6,2.9,1.0,0.0)` |
| 123 | `(0.0,0.0,0.0,0.0)` | `(0.0,1.0)` | `(0.92,0.92)` | `(1.0,1.0)` | `(0.16,0.16)` | `(0.16,1.10,0.10,0.0)` |
| 127 | `(0.0,0.0,0.0,0.0)` | `(0.0,1.0)` | `(0.78,0.78)` | `(1.0,1.0)` | `(0.20,0.20)` | `(0.18,1.05,0.70,0.0)` |

**Native visual bridge:** `RG8.R` is the material ID and `RG8.G` is a material-selected projected byte; GDScript fallback uses R8 and lacks full native chemistry/combustion. Procedural display is not authoritative state, and visually perforated grating/chainlink still blocks physics. Emission/glow, shape-aware building finishes, crossfade, and water coverage do not imply temperature, reflection, porosity or dynamic liquid wetness in the cellular rules.
**Rendering is not a calibrated physical material model:** no universal elastic modulus, thermal conductivity, physical viscosity in Pa·s, friction coefficient, boiling/melting-point database, pressure equation for each material, true mass density units, or independent paint/decal layers are defined by these descriptors. Such values must **not** be invented. Separate Rapier/player/soliding and optional liquid solver policies may add body/experiment parameters but do not silently modify this catalogue.

## 9. Source map and maintenance
| Authority | Source at pinned revision | Contents / priority |
|---|---|---|
| Native identity/descriptors | [native/include/cybersand/material.hpp](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material.hpp) | All IDs, names, phase, ρ, color, moves, state, kernels, radii, viscosity |
| Hard/grain/exchange predicates | [native/src/material_rules.cpp](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/src/material_rules.cpp) | Collision, granular capabilities, density exclusions, viscosity formula |
| Pair/family contract | [native/include/cybersand/interaction_rules.hpp](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/interaction_rules.hpp) | 56 rules, 7 explicit families, 33 memberships, 19 specialized semantics |
| Native kernel implementation | [native/src/world.cpp](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/src/world.cpp) | Actual tick ordering, reactions, conversion, movement and lifecycle |
| Visual state byte selection | [native/include/cybersand/material_appearance.hpp](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/native/include/cybersand/material_appearance.hpp) | One RG8 condition source per ID |
| Godot LUT/programs | [godot/scripts/material_appearance_lut.gd](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/godot/scripts/material_appearance_lut.gd) | RGBA8, variations, hue, 0–50 flair, exact program overrides |
| Shader appearance | [godot/shaders/material_palette.gdshader](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/godot/shaders/material_palette.gdshader) | Procedural appearance detail and costs |
| Building behavior reference | [docs/systems/building-material-catalogue.md](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/docs/systems/building-material-catalogue.md) | ID 81–131 functional and visual intent |
| Themed behavior reference | [docs/systems/themed-construction-materials.md](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/docs/systems/themed-construction-materials.md) | ID 38–80 functional and visual intent |
| Materials contract | [docs/systems/materials-and-rule-kernels.md](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/docs/systems/materials-and-rule-kernels.md) | Runtime constraints, cadence and fallback divergence |
| Interaction substrate | [docs/systems/intermaterial-interactions.md](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/docs/systems/intermaterial-interactions.md) | Schema, roles, provenance and limitations |
| Water contract | [docs/systems/water-design.md](https://github.com/techrote/cybersand/blob/a8f08a67fea3c58f6df7473cbae1831334fcc04e/docs/systems/water-design.md) | Current Water conservation, pressure limitations and experimental alternatives |

**Regeneration checklist:** if native descriptors or pair rules change, re-extract all rows, verify 132-row capacity/mirror changes, update the source SHA and date, and run the repository's LCB policy-identity regeneration sequence. Also reconcile the fallback `godot/scripts/cell_world.gd`, LUT, picker and source-matched native desktop/Web artefacts. A changed `main` does not retroactively change this pinned snapshot. Source docs themselves may lag experiments and unmerged candidate branches; this page intentionally describes only the pinned committed native default.
**Validation of this page:** automated extraction in this documentation pass found 132 descriptors, 132 visual projection entries, 132 palette-variation values, 56 authored pairs, 33 semantic membership records, 19 specialized registered semantics, and 40 explicit per-material appearance-program row assignments (collapsed above into 23 distinct tuples). The extraction does not substitute for physical gameplay/graphical acceptance.

