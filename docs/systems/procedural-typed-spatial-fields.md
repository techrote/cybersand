---
title: Typed spatial fields, transforms and reusable generation graphs
status: Current
document-kind: contract
scope: GEN-003 schema-2 immutable typed spatial computation, explicit mask conversion, bounded resampling, structured seeds and finite region assignment; platform acceptance remains separately evidenced
canonical-for: [generation-typed-values, generation-spatial-transforms, generation-derived-geometry, generation-reusable-subgraphs, generation-structured-mappings, generation-multiresolution-cache]
keywords: [GEN-003, typed fields, signed distance, vector, category, transform, gradient, curvature, Peano, Voronoi, Delaunay, Poisson, subgraph, multiresolution, cache]
last-reviewed: 2026-10-21
related-documents: [procedural-world-generation.md, procedural-generation-fields-and-modifiers.md, ../reference/procedural-spatial-operators.md, ../reference/configuration-reference.md, ../reference/interfaces-and-message-contracts.md, ../architecture/data-ownership-and-lifetimes.md, ../operations/local-build-and-validation.md]
---

# Typed spatial fields, transforms and reusable generation graphs

## How does GEN-003 preserve existing scalar recipes?

**Current source, GEN-003 / [#190](https://github.com/techrote/cybersand/issues/190):**
schema-2 recipes add a separate `spatial` graph of immutable world-coordinate
functions. The retained schema-1 `fields` graph still implements its original
normalized scalar operators, initial proposal context, masks and sidechains.
`SpatialGraph` cannot read that per-cell context, a live World, resident neighbors,
Godot objects or a callback. Consequently a derivative or transformed sample
always samples the same declared mathematical function at its new coordinate.

Schema 1 keeps generator algorithm 2 and field algorithm 1. Schema 2 uses generator
algorithm 3 and spatial algorithm 1. Selecting schema 2 is explicit; merely
opening a legacy recipe does not reinterpret its normalized addition, noise or
material guidance. The twelve frozen GEN-001 material hashes in
[`test_generation_modifiers.cpp`](../../native/tests/test_generation_modifiers.cpp)
remain independent compatibility controls. The unchanged GEN-002 field/modifier
suite also remains applicable. Receipt identity and material equality are
separate properties.

Migration starts by changing `schema` from 1 to 2 and retaining the existing
module, `fields`, modifiers and authored guides. With an empty spatial graph,
the material result remains equal to the schema-1 proposal, but the recipe
fingerprint and receipt change because the schema/algorithm identity changed.
Schema 1 rejects `spatial` and `spatial_limits` keys, even empty ones. Add typed
nodes under schema 2 and opt individual consumers into normalized `spatial:`
references; retained field operators keep their schema-1 meanings.

The native [typed API](../../native/include/cybersand/generation_typed_fields.hpp)
and [implementation](../../native/src/generation_typed_fields.cpp) own graph
compilation/evaluation. The [spatial primitives](../../native/include/cybersand/generation_spatial.hpp)
own finite traversals, lattice seeds, immutable geometry and the bounded region
solver. The [operator inventory](../reference/procedural-spatial-operators.md)
lists exact input families, parameters and work rules. These are generation
controls, separate from simulation temperature, pressure, material rules and
streamed World ownership.

## Which values and units are preserved?

Every output has a declared type, cell-unit exponent, component bounds, natural
sampling scale, identity and conservative work cost. Unit exponents range from
−8 through 8. Coordinates and geometric distances have `cells^1`; gradients
reduce the input exponent by one; products add exponents. Angles are radians
with exponent zero. All numeric values are finite and bounded by the declared
component range within ±`1e100`.

| Type | Meaning | Conversion and comparison |
|---|---|---|
| `normalized` | Dimensionless scalar in `[0,1]` | May drive a material mask directly through a `spatial:<id>` reference |
| `scalar` | General scalar, including signed values, with a declared unit exponent | No implicit clamping; `to_mask` explicitly maps its `low..high` interval into `[0,1]` |
| `signed_distance` | Negative inside, zero at the boundary, positive outside, measured in cells | Only supported exact constructions retain this qualification; arbitrary arithmetic loses it |
| `distance` | Nonnegative distance to a declared feature, with the operator's stated search scope | Bounded Poisson distance is a capped local search result; it is not an infinite-world nearest-seed guarantee |
| `vector2` | Two continuous components sharing one unit exponent | Vector arithmetic, components, length, dot and normalization are explicit |
| `category` | Exact tuple of signed integer x/y identity plus a 64-bit domain | Equality compares the full tuple; IDs are never numerically blended or converted to a mask |
| `boolean` | Exact false/true, represented by zero/one | `equal`, `less` and local extrema produce it; explicit `to_mask` yields exact zero/one |

Addition/subtraction and ordered scalar comparison require compatible units.
Vector components require equal units. `equal` requires matching types and
units, including exact categorical tuples. `select` consumes
`[boolean, true_value, false_value]` with matching branch types/units. `mix`
requires matching continuous inputs and a normalized weight. No categorical
ordering or arithmetic is inferred from its payload.

`category_is` compares a categorical input with an exact authored tuple. Its
explicit literal domain zero selects the signed x/y ID within the input's own
domain; a nonzero literal also requires exact domain equality. This supplies a
declarative selector for generated district identities without requiring an
author to reproduce the compiler's domain fingerprint. Ordinary `equal` still
compares complete tuples.

`constant` accepts normalized, general scalar, vector, category or boolean
values. A constant with cell units is not automatically a distance to a shape.
Distance types come from declared geometric operators. In JSON, categorical
integers use exact text representations: signed decimal strings for x/y and
exactly 16 lowercase hexadecimal digits for the unsigned domain. Numeric JSON
integers are also accepted within the adapter's exact signed-integer range;
strings preserve identities beyond JSON's 53-bit integer precision. The
adapter's diagnostic protocol preserves categories through packed strings
rather than floating-point colours.

## How are coordinate transforms composed?

`transform` samples its source in local coordinates. For local point `q`, world
point `p`, origin `o`, translation `t`, rotation `R`, shear `H` and anisotropic
scale `S`, the convention is:

```text
p = o + t + R H S (q − o)
q = o + (R H S)^−1 (p − o − t)
H = [[1, shear_x], [shear_y, 1]]
S = diag(sx, sy)
```

Positive angles use the ordinary coordinate rotation matrix. World y is the
generator's downward-positive axis, so the on-screen visual interpretation
follows that axis convention. Translation and origin are positions in cells;
angles are radians. Nested transforms compose through explicit source inputs
and are bounded by graph depth and recursive sampling work.

`transform_vector` samples its vector source at the original point and applies
the **forward linear part** `R H S`. It does not add translation or origin.
Coordinate deformation of a vector field and transformation of its vector
values are therefore separate operations an author may compose deliberately.
The compiler rejects zero/tiny scales, singular shears, nonfinite parameters
and excessive declared bounds.

Translation, rotation/reflection and uniform scale preserve an exact SDF. A
uniform scale multiplies the sampled distance by the absolute scale. Anisotropic
scaling or shear preserves the zero set but changes the result to a general
implicit scalar. Its reported minimum/maximum distance factors are the affine
matrix's singular-value bounds: multiplying the absolute local distance by
those factors bounds the world distance to the transformed boundary. General
warps, polar maps and coarse interpolation discard an exact-distance claim.
Do not use a warped scalar as an exact clearance radius.

`repeat` subtracts its phase origin and maps each axis into local `[0,period)`
using floor-equivalent remainder. `mirror` folds the phase-shifted,
period-doubled axis into local `[0,period]`. Negative inputs and exact seams obey the same rules
as positive inputs. These coordinate maps repeat a function; they do not imply
that material routes connect across the repeated boundary.

`polar` samples its source at `(radius/radial_scale, angle/angular_scale)`;
`log_polar` replaces the first component with
`log(max(radius,min_radius)/radial_scale)`. Both measure radius/angle relative
to an explicit origin. Angle uses `atan2`, with angle zero at the origin; the
negative-x, zero-y branch is positive pi. Radial/angular scales map physical
radius/radians into the source's sampling coordinates. The logarithm's
minimum-radius clamp and angle branch seam are explicit numerical conventions,
independent of resident chunks.
`warp` takes `[source, displacement_vector]`; the displacement is sampled at the
original point and radially capped to `max_displacement` cells before resampling
the source. Repeated composition is bounded; no neighbor-generation recursion
is introduced.

Public samples use integer world coordinates in `[-2^40,2^40)`. Internal
transformed, coarse and derivative samples use doubles inside the bounded
±`2^44` sampling footprint. An invalid footprint rejects the sample and prevents
publication of its chunk. This larger internal envelope supports ordinary
derivative halos at the public coordinate limits without querying storage.

## Which derivatives and geometric detectors are defined?

Spacing `h` is explicitly `1..64` cells. The first derivative uses centered
differences, for example `(f(x+h,y)−f(x−h,y))/(2h)`. Second derivatives use
the centered three-point form. The mixed derivative uses four diagonal samples.
All positions are absolute-world coordinates of immutable functions. A chunk
boundary is not a stencil boundary; it cannot substitute missing neighbor data
or change the answer.

| Operator | Numerical meaning |
|---|---|
| `gradient` | `(fx, fy)` with input unit exponent minus one |
| `slope` | `hypot(fx,fy)`; nonnegative, same units as gradient |
| `aspect` | `atan2(fy,fx)`, in signed radians; zero gradient has a finite zero convention |
| `divergence` | `dVx/dx + dVy/dy` |
| `curl` | Scalar `dVy/dx − dVx/dy`; positive sign is fixed by this formula |
| `ridge`, `valley` | `max(0,−laplacian)` and `max(0,laplacian)`; input exponent minus two |
| `local_minimum`, `local_maximum` | Strict comparison to the four axial samples, producing an exact boolean; a plateau is not a strict extremum |
| `curvature` | Level-set curvature `(fxx*fy²−2*fxy*fx*fy+fyy*fx²)/hypot(fx,fy)^3`; zero at zero gradient, units `cells^-1` |

Finite differences approximate nonlinear functions and discontinuities. The
analytical regression uses quadratic scalar fields, radial circle distance and
linear vector fields to establish values, signs and units independently. These
operators detect properties of the authored function; they are not a fluid
solver, a proof of physical traversability or exact geometry reconstruction.

## What do Peano, Voronoi, Delaunay and Poisson guarantee?

The Peano operator extends the retained finite Hilbert/Morton controls with a
ternary square traversal. Side length is `3^order`, `order=1..12`; each local
cell spans `cell_size=1..4096` world cells. Rank and inverse are bijections.
Consecutive Peano ranks share an edge **inside one finite tile**. Signed tile
addressing uses floor division. No infinite path or physical route is promised
between independently repeated tiles; authored routes and the generator's
shared-network controls retain that separate role.

Voronoi seeds use one deterministically jittered point in each world-aligned
lattice tile. `spacing` is `1..1,048,576` cells and `jitter` is `[0,1]`.
A fixed 5×5 candidate search suffices for the nearest point because the
containing tile always supplies a seed within `sqrt(2)*spacing`. Equal distances
choose the lexicographically smaller signed seed coordinate. Region identity
retains both seed coordinates and a stable graph domain; it does not pack an
unbounded address into a floating-point number.

`voronoi_distance` returns nearest-seed distance. `voronoi_boundary` measures
distance to the nearest competing Voronoi boundary under its bounded 7×7
competitor search. `delaunay_degree` exposes the size of the positive-length
Voronoi-face dual. The lower-level neighborhood API additionally returns
incident neighbors/positions and distance to the owner's incident segments.
Co-circular zero-length diagonal edges are deliberately omitted; a square
lattice therefore has four face neighbors rather than an arbitrary triangulation
diagonal. This is the documented Delaunay-derived structure.

Poisson-style seeds use deterministic Matérn-II priority rejection. Each lattice
tile owns one candidate. It survives only if no candidate within the authored
radius has a lower `(priority, signed ID)` ordering. Rejected candidates still
compete; acceptance never recursively asks whether a neighbor survived. Radius
must be positive and no greater than twice the lattice spacing. Candidate
ownership is half-open and independent of requested chunks.

The query radius is `R=search_cells*spacing`, with `search_cells=1..4`.
`poisson_found` reports whether an accepted seed lies strictly inside R.
`poisson_distance` returns the nearest accepted distance capped at R. A
`poisson_region` identity must be interpreted together with `poisson_found`
when no candidate is found. This bounded selection gives hard minimum
separation, not a guaranteed globally nearest seed, maximal packing or a
measured blue-noise spectral guarantee.

## How do immutable routes and finite region assignments work?

Geometry inputs contain an ID, 1..256 finite points and a `closed` flag; a
closed boundary requires at least three points.
`geometry_distance` names one immutable input and returns Euclidean distance
to its point, open polyline segments or closed boundary. Closed geometry measures
the boundary; it does not silently become an inside/outside classifier. A
single point and repeated points have bounded explicit segment handling.
Geometry is copied/prepared before publication, and its actual coordinates
enter the consuming node's identity. GEN-004 can supply routes and feature
boundaries through this value interface without a dependency from fields into
the future grammar implementation.

An assignment input declares a finite tile of at most 16×16 cells, up to 16
exact categories, four directional adjacency masks and optional per-cell domain
masks. Opposite adjacency relations must be reciprocal. Deterministic propagation
and bounded backtracking prepare the entire solution before a field can sample
it. Unsatisfiable constraints and exhausted work are distinct explicit failures;
neither exposes a partial assignment.

`assigned_region` returns one exact category from the prepared tile. The tile
repeats using floor addressing. `wrap_x`/`wrap_y` enable constraints across those
tile edges; without a wrap constraint, adjacency is guaranteed only inside the
finite tile. GEN-004 owns hierarchical layout use of this contract and should
reuse this solver rather than introducing a conflicting field solver.

## How are named subgraphs and parameters expanded?

A `spatial` definition contains `nodes`, `subgraphs`, `instances`, `geometries`
and `assignments`. A named subgraph declares typed parameters with optional
defaults, local nodes, nested instances and named outputs. Instances supply
typed literal `bindings`; nested instances may bind parameters from their
enclosing subgraph. Numeric operator parameters can explicitly refer to a typed
scalar parameter through `parameter_bindings`. The declared cell exponent must
match the operator parameter: lengths, positions and sampling spacing use one;
angles, affine scale factors, shears, jitter, salt and traversal order use zero.
`to_mask` low/high bounds inherit the input field's exponent. Numeric bindings
are not an escape from unit checking. A `parameter` node names its declaration
with `reference` and may select a sampling scale; its type, units and value
come from the declaration/binding, so ignored node-level overrides reject.

Local IDs allow letters, digits, hyphen and underscore. Dot is reserved for
expanded namespaces. An output named `mask` in instance `decay` is
`decay.mask`; a nested instance adds another namespace component. The compiler
rejects duplicate IDs, node/instance/output collisions, unknown bindings,
missing required inputs, wrong types, dependency cycles and recursive expansion.
Unused declarations are validated too. Root graph nodes may consume an expanded
output by its full name.

The definition admits at most 16 subgraphs, root instances, geometry inputs and
assignments per family. Each subgraph admits at most 16 parameters, nested
instances and named outputs; nesting depth is at most eight. Expansion shares
a hard 1,024-instance-call ledger across actual and unused-template validation,
so even a tree of empty subgraphs has bounded work. Every expansion call costs
512 preparation units and every expanded node costs 8,192, in addition to
declaration validation and geometry/solver preparation.

Stable instance paths derive deterministic seed domains from the recipe seed.
Reordering declaration arrays does not alter meaning. A parameter edit changes
the consuming node and its transitive consumers; unrelated instance/node
identities remain reusable. Compiled inputs are immutable owned values, so
editing the author's definition cannot mutate a retained graph or pending job.

## How do multiresolution evaluation, caches and budgets behave?

Every node declares `sampling_scale` of 1, 4, 16 or 64 cells. The lattice is
anchored at absolute world zero using mathematical floor, including negative
positions. Continuous outputs use deterministic bilinear interpolation between
the four coarse anchors. Categorical and boolean outputs select the nearest
anchor exactly; an exact half tie selects the lower anchor on each axis. IDs
and booleans are never numerically interpolated. Coarse distance interpolation
loses exact-distance qualification.

The caller-owned `SpatialScratch` contains 256 bounded cache entries. Keys bind
the transitive node identity, exact double coordinate bits and sampling mode;
the graph contains no mutable cache. Identity includes algorithm, operator,
parameters, instance path/seed, inputs, referenced geometry/assignment and
sampling scale. Warm, cold or evicted entries change work reuse, not results.
Separate workers use separate scratch. In particular, no cache key needs a live
World revision because the typed API has no World or per-cell context access.
Numeric negative zero is canonicalized to positive zero in both identity and
returned components, so sharing cached results between equivalent definitions
cannot change their component bits.

The numerical implementation uses ordinary C++ double arithmetic and standard
transcendental functions. Exact equality is the supported deterministic guarantee
for the same compiled numerical implementation under different request order,
partitions, worker scratches, budget slices and cache states. Cross-platform
bitwise equivalence of trigonometry/logarithms is not promised by this contract;
Linux and Windows execution remain individually source-bound acceptance gates.

The compiler accounts for recursive source sampling, derivative fan-out, coarse
four-anchor sampling, every expanded declaration, seed neighborhoods, geometry
segments and solver preparation. Declared work is conservative logical work,
not wall-clock time or exact machine instructions; cache hits do not reduce the
admission charge. Bounds and defaults are in the
[configuration reference](../reference/configuration-reference.md#opt-in-procedural-generation-configuration).

Successful evaluation uses fixed caller/stack scratch without per-cell heap
growth. `evaluate` fills a private result before replacing the caller's output.
Generation retains its private pending material/diagnostic arrays; cancellation
or failure discards both payloads and their receipt hashes. A ready chunk is
one complete result. Compilation, preparation and per-chunk rejection are not
permission to expose a partially generated map.

## How are typed authoring controls and diagnostics used?

The Workbench's **Typed spatial graphs** page edits the `spatial` JSON section,
inserts operator drafts from the native catalogue and selects complete executable
examples. It shows accepted output type, units, scale, bounds, distance
qualification, identity and work. `spatial:<expanded.id>` selects a copied typed
diagnostic. The display may map a signed scalar or category to colour, while the
inspector preserves the raw typed value. Presentation colour is never the stored
categorical identity or a material mask.

GEN-004 schema-3 recipes may populate selected `spatial` geometry inputs from
[immutable semantic route/feature exports](procedural-hierarchical-generation.md).
The planner resolves those names before the typed compiler runs. Each export
is one actual polyline or feature boundary; separate routes are never joined by
invented segments. Fields retain no dependency on grammar types, live World
state or partially rasterized neighboring cells. GEN-004 also reuses this finite
assignment solver for declared district themes.

The Workbench writes JSON with full floating-point precision. External GDScript
authors should use `JSON.stringify(recipe, "  ", true, true)` so the
`full_precision` argument preserves accepted double values and the compiled
`spatial_fingerprint`; default JSON formatting can round them. Category strings
remain exact independently of that numeric formatting. Reapplying an accepted
recipe intentionally advances the adapter revision and recipe fingerprint;
unchanged spatial content retains its separate graph fingerprint.

Only `normalized` spatial outputs may feed existing application/exclusion,
aggregate variation and parameter-mapping controls. Authors must add an explicit
`to_mask` conversion for signed scalars or booleans. A category can first be
compared with `equal`, then explicitly converted. The initial proposal context,
modifier order, restored route skeleton and final hard-material authority remain
owned by the retained [field/modifier contract](procedural-generation-fields-and-modifiers.md).

Executable profiles under [`examples/worldgen`](../../examples/worldgen) cover
transformed industrial structure, vector-guided utilities, exact categorical
districts, reusable decay masks and multiscale feature seeds. This is minimal
authoring/inspection support for the native implementation; GEN-007 owns the
full visual editor and content-quality tools. GEN-004 owns hierarchical places,
GEN-005 semantic depth and GEN-006 persistent runtime streaming/reconciliation.
