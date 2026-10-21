---
title: Procedural spatial operator inventory
status: Current
document-kind: reference
scope: GEN-003 typed spatial operator inputs, units, parameters, numerical conventions and conservative logical work
canonical-for: [generation-spatial-operator-inventory]
keywords: [GEN-003, operator, arity, units, bounds, finite difference, sampling cost]
last-reviewed: 2026-10-20
related-documents: [../systems/procedural-typed-spatial-fields.md, configuration-reference.md, interfaces-and-message-contracts.md]
---

# Procedural spatial operator inventory

## Reading the inventory

**Current source:** [`SpatialKind`](../../native/include/cybersand/generation_typed_fields.hpp),
[`spatial_kind_specs` and compiler/evaluator](../../native/src/generation_typed_fields.cpp)
are the exact native authority. The adapter copies parameter defaults/ranges and
compiled type/unit/bound/work metadata into its catalogue. The
[typed graph contract](../systems/procedural-typed-spatial-fields.md) owns spatial
coordinates, exact categories, transforms, distance qualification, subgraph
expansion and cache behavior.

In this table, `S` means a continuous scalar (normalized/general/distance), `V`
means vector2, `N` normalized, `B` boolean and `C` category. Equal-unit/type
requirements still apply. `W(i)` is the conservative recursive work of input i.
The table gives base work **before natural-scale sampling**. Nodes are all
charged, even if unused or behind a zero mask. Work counts are logical admission
units, not measured processor instructions.

| Operators | Ordered inputs → output | Parameters and numerical convention | Base work |
|---|---|---|---:|
| `constant` | none → declared N/S/V/C/B | Exact typed `value`; `unit_power` only for S/V; no implicit distance constant | 32 |
| `parameter` | none → parameter type | `reference` names a parameter inside a subgraph; resolved to an immutable constant during expansion; no node-level type/value/unit/input overrides | 32 after expansion |
| `identity` | any → same | Copies exact payload/units/qualification | `32 + W(0)` |
| `position` | none → V, cells | `(x,y)` | 32 |
| `coordinate_x`, `coordinate_y` | none → S, cells | Absolute world coordinate component | 32 |
| `circle_distance` | none → signed distance | Center `x,y`, positive `radius`; `hypot(p−center)−radius` | 64 |
| `box_distance` | none → signed distance | Center `x,y`, full `width,height`; exact axis-aligned rectangle distance with negative interior | 64 |
| `noise` | none → N | Smooth seeded lattice value noise; `scale`, integer `salt` | 256 |
| `add`, `subtract` | S,S or V,V → S/V | Equal units; signed arithmetic, no saturation | `32 + W(0)+W(1)` |
| `minimum`, `maximum` | S,S or V,V → S/V | Equal units, componentwise; two normalized inputs retain N | `32 + W(0)+W(1)` |
| `multiply` | S,S or S,V or V,S → S/V | Unit powers add; two N inputs retain N | `32 + W(0)+W(1)` |
| `mix` | matching continuous a,b; N weight → continuous | Linear interpolation, exact endpoint selection; distance qualification discarded | `32 + ΣW(i)` |
| `to_mask` | S/B → N | Explicit clamp of `(v−low)/(high−low)`; requires `low<high`; B maps to exact zero/one | `32 + W(0)` |
| `compose_vector` | S,S → V | Equal component units | `32 + W(0)+W(1)` |
| `component_x`, `component_y` | V → S | Retain vector unit exponent | `32 + W(0)` |
| `length` | V → S | Euclidean magnitude; nonnegative, vector units | `32 + W(0)` |
| `unit_vector` | V → V | Divide by magnitude; zero vector returns zero; dimensionless | `32 + W(0)` |
| `dot` | V,V → S | Sum of component products; unit powers add | `32 + W(0)+W(1)` |
| `equal` | matching type/unit a,b → B | Exact payload comparison, including all category identity components | `32 + W(0)+W(1)` |
| `category_is` | C → B | Exact category literal in `value`; domain zero explicitly means signed x/y within the input domain, otherwise complete tuple equality | `32 + W(0)` |
| `less` | S,S → B | Equal units; strict scalar comparison | `32 + W(0)+W(1)` |
| `select` | B,true,false → branch type | Branch types/units match; no category blending; exact-distance qualification discarded where conditional selection does not prove it | `32 + ΣW(i)` |
| `transform` | any field → sampled type | Inverse affine coordinate map; tx/ty, angle, sx/sy, shear_x/y, origin_x/y; uniform SDF magnitude correction | `128 + W(0)` |
| `transform_vector` | V → V | Forward affine linear part; translation/origin do not affect vectors | `128 + W(0)` |
| `polar`, `log_polar` | any field → sampled type | Source coordinates `(r/radial_scale, theta/angular_scale)` or `(log(max(r,min_radius)/radial_scale), theta/angular_scale)`; origin angle zero, signed atan2 seam; distance qualification discarded | `128 + W(0)` |
| `repeat`, `mirror` | any field → sampled type | period_x/y, origin_x/y; floor half-open repeat or closed triangular mirror; distance qualification discarded | `128 + W(0)` |
| `warp` | source, V displacement in cells → sampled source | Radial cap `max_displacement`; source evaluated at displaced coordinates; distance qualification discarded | `128 + W(0)+W(1)` |
| `gradient` | S → V | Four axial first-derivative samples, spacing h; unit exponent −1 | `96 + 4W(0)` |
| `slope` | S → S | Magnitude of centered gradient; nonnegative; exponent −1 | `96 + 4W(0)` |
| `aspect` | S → S | `atan2(fy,fx)` radians; finite zero at zero gradient | `96 + 4W(0)` |
| `divergence`, `curl` | V → S | Four axial samples; `dVx/dx+dVy/dy` or `dVy/dx−dVx/dy`; exponent −1 | `96 + 4W(0)` |
| `ridge`, `valley` | S → S | Center plus four axial samples; positive negative/positive Laplacian; exponent −2 | `96 + 5W(0)` |
| `local_minimum`, `local_maximum` | S → B | Strict center comparison to four axial samples | `96 + 5W(0)` |
| `curvature` | S → S | Nine-point level-set curvature; zero-gradient convention; reciprocal cells | `160 + 9W(0)` |
| `peano` | none → N | Finite ternary curve rank divided by rank maximum; order/cell_size/origin | `32 + 32*order` |
| `voronoi_region` | none → C | Nearest world-lattice seed with exact ID and deterministic signed-coordinate ties | 1664 |
| `voronoi_distance` | none → distance | Same bounded 5×5 search; Euclidean nearest-seed distance | 1664 |
| `voronoi_boundary` | none → distance | Nearest competitor-boundary distance after 7×7 competitor search | 6432 |
| `delaunay_degree` | none → S | Positive-length Voronoi-face dual degree, at most 48; zero-length co-circular diagonals omitted | 309248 |
| `poisson_distance`, `poisson_region`, `poisson_found` | none → distance/C/B | Deterministic priority-rejected seeds; spacing/jitter/salt/radius/search_cells; distance capped at finite query radius | `128 + Q²*(128 + J²*128)`; Q=`2*search_cells+1`, J=`2*(ceil(radius/spacing)+1)+1` |
| `geometry_distance` | none → distance | `reference` names copied point/polyline/closed boundary | `64 + 64*point_count` |
| `assigned_region` | none → C | `reference` names fully prepared finite adjacency assignment | 64 |

## Parameter bounds and invalid declarations

| Family | Defaults and admitted range |
|---|---|
| Shape | Circle center 0/0, radius 64; box position 0/0, width/height 128; positive extents `0.0001..1,000,000` |
| Coordinate origins | Default zero; finite coordinates within the internal ±`2^44` envelope |
| Noise/lattice | Scale/spacing 64, `1..1,048,576`; salt 0, integer `0..2^32−1`; lattice jitter 1, `[0,1]` |
| Explicit mask | low 0, high 1, both within ±`1e100` and low strictly below high |
| Affine | tx/ty 0 within ±1,000,000; angle 0 within ±1000 radians; sx/sy 1 within ±10,000 with absolute scale at least 0.0001; shear 0 within ±100; non-singular determinant required |
| Polar | Radial/angular scales 1 and min_radius 0.0001; each `0.0001..1,000,000` |
| Repeat/mirror | Periods 64; each `0.0001..1,000,000` |
| Warp | max_displacement 32; `0..4096` cells |
| Derivatives | spacing 1; `1..64` cells |
| Peano | order 4, integer `1..12`; cell_size 1, integer `1..4096` |
| Poisson | radius 32, positive and at most twice spacing; search_cells 2, integer `1..4` |

Typed numeric parameter bindings use exponent one for `x`, `y`, `radius`,
`width`, `height`, `scale`, `spacing`, `tx`, `ty`, `origin_x`, `origin_y`,
`radial_scale`, `min_radius`, `period_x`, `period_y`, `cell_size` and
`max_displacement`. `low`/`high` use their scalar input's exponent. The remaining
numeric parameters, including affine `sx`/`sy`, angle, angular_scale, shear,
salt, jitter, order and search_cells, are dimensionless. Literal numeric
parameters have the same operator-defined interpretation; a typed binding
must match it explicitly.

Unknown names, ignored payloads, wrong arity/types/units, nonfinite values,
singular transforms, out-of-domain parameters, invalid references and every
unused invalid declaration reject compilation. Operators do not guess a type,
truncate inputs, reinterpret a float as a category or silently read World state.
Compilation also checks conservative component bounds and recursive work before
publishing an immutable graph. Samples outside the public coordinate domain or
internal resampling envelope reject transactionally.

## Interpolation and complete work accounting

Scale 1 uses the operator directly. For scale 4/16/64, continuous values evaluate
four absolute-world coarse anchors and add interpolation work; conservative work
is `4*base_work + 64`. Categories and booleans select one exact nearest anchor,
with lower-anchor half ties, so work is `base_work + 64`. Recursive input costs
already include their own scales, transforms and derivative stencils. The total
graph charge is the sum for every published/declared expanded node; caching
never reduces the admission bound.

Geometry compilation records owned point bytes and segment query costs. Region
assignment records configured preparation work and fixed bounded solver scratch,
in addition to prepared solution storage. Subgraph validation/expansion and
immutable input preparation are bounded independently from per-cell sampling.
The compiler's `preparation_operations`, `preparation_bytes` and per-node/graph
sampling costs are inspectable through the native API. These are explicit
capacity contracts rather than performance claims.

The preparation-work ledger starts at 1,024 units, charges 256 per authored
node, 512 per subgraph declaration, `256+64*points` per geometry, and the full
configured work allowance for every assignment. Actual/validation expansion
additionally charges 512 per instance call and 8,192 per expanded node. The
compiler validates unused templates under the same shared ledger. The
1,024-instance-call ceiling prevents empty expansions from evading node limits.
The conservative memory ledger includes compiled node capacity, bounded
expansion/declaration storage, caller scratch, copied geometry and the fixed
256 KiB solver scratch per assignment. It is checked before graph expansion or
solver preparation; it is a conservative allowance, not measured heap residency.
