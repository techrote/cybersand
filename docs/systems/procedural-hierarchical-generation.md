---
title: Hierarchical procedural places and structural routes
status: Current
document-kind: contract
scope: GEN-004 semantic hierarchy, canonical region ownership, bounded placement constraints and qualified final-raster routes
canonical-for: [procedural-semantic-hierarchy, generation-region-ownership, structural-route-qualification]
keywords: [GEN-004, hierarchy, grammar, district, room, apparatus, stable identity, boundary sockets, occupancy, constraints, traversal, semantic plan]
last-reviewed: 2026-10-21
related-documents: [../decisions/ADR-013-canonical-semantic-generation.md, procedural-world-generation.md, procedural-generation-fields-and-modifiers.md, procedural-typed-spatial-fields.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../reference/invariants.md, ../audits/2026-10-21-gen004-hierarchical-generation.md]
---

# Hierarchical procedural places and structural routes

## What is implemented, and what stays separate?

**Current source, GEN-004 / [#191](https://github.com/techrote/cybersand/issues/191):**
opt-in recipe schema **3**, generator algorithm **4**, adds a grammar with its own
schema **1** and algorithm **1**. The
[native semantic API](../../native/include/cybersand/generation_grammar.hpp) and
[planner](../../native/src/generation_grammar.cpp) compile complete immutable places
before the existing generator rasterizes material proposals. Schema-1/2 recipes
retain their previous algorithms and material behavior when grammar is absent.
Runtime acceptance remains separately recorded in the
[dated audit](../audits/2026-10-21-gen004-hierarchical-generation.md).

A hierarchy may contain region, district, complex, room, apparatus and detail
features. The authored namespace represents the world; kinds are descriptive,
while parent/child references define nesting. Recipes can skip levels or use
multiple district scopes for theme subdivisions. Each feature carries its exact
identity, parent/children, canonical owner, absolute half-open rectangle, selected
rule and candidate, tags, normalized theme blend, typed parameters, allowed
materials, sockets, constraints, seed, content revision and finite-curve order.
This version uses axis-aligned integer rectangles and explicit rectilinear routes.
It does not claim arbitrary implicit solids or a general-purpose architectural
packing solver.

Semantic planning has no World pointer, resident-neighbor read, shared mutable
random stream or Godot callback. GEN-003 fields consume explicitly exported
immutable geometry; they do not depend on grammar types or partially rasterized
neighbors. Material proposal publication, native World admission and presentation
remain separate owners. The planner does not evict chunks, reconcile player edits,
run simulation or complete persistent streaming. [GEN-005 semantic planes](procedural-semantic-planes.md) now compose this immutable
hierarchy for finite four-plane projection. GEN-007 owns the full authoring/quality
editor, and GEN-006 streaming and reconciliation.

## How do finite planning regions own cross-chunk places?

`region_size` anchors a square lattice at world zero. `region_window` is
`[region_x, region_y, width, height]` in **region addresses**, not cells. A window
is finite and explicit; each of its regions independently constructs the same
regional hierarchy. A feature belongs to its parent region and must fit that
region through recursively contained parent bounds. It may span many storage
chunks. A chunk samples that immutable plan even if the chunk containing the
feature origin has never been requested.

The planning window is not part of a regional identity. Compiling one region,
a larger window containing it, or disjoint neighboring windows therefore uses
the same local identities, geometry and ownership. Storage chunk size, request
order, worker completion and budget slicing cannot choose a feature owner.
Cross-region structures in this version are explicit route/service connections;
arbitrary building boxes crossing their canonical region are rejected. There is
no recursive expansion beyond the finite declared window and no hidden neighbor
publication requirement.

Each region has a center hub with four explicit orthogonal passage arms. A
shared boundary key is
`<world>/grid<size>/boundary/x/<boundary-x>/<region-y>` for a vertical edge, or
`<world>/grid<size>/boundary/y/<region-x>/<boundary-y>` for a horizontal edge. The world
seed and that key select a port within the middle third of the edge. Both
neighbors produce the same aperture position, width, type and canonical owner.
The west or north region owns the shared record; it may lie outside the requested
window. Regional local ports refer to that shared record, and duplicate shared
records are checked and deduplicated within a multi-region plan.

`secondary_loop` adds a rectangular loop at one-quarter/three-quarter region
coordinates and an explicit link to the hub. `service_trunk` places a horizontal
service route at `region_size/4 - 8`; `liquid_trunk` places a liquid route at
`3*region_size/4 + 8`. Their material and route type are declared. They are
semantic service access paths, not proofs of simulated flow or an unbroken
pressure network. Service/liquid ports use the same west-owner canonical boundary rule with
their route type in the key. Required empty passages retain raster precedence
over service material where the two intersect.

## Which edits preserve semantic identity?

A region ID is `<world>/grid<size>/region(<x>,<y>)`. Each authored feature extends its parent
with `/<rule-id>/<slot>`, where slots are stable integers from zero through
`count-1`. For example:

```text
four-foundries/grid128/region(0,0)/district/0/foundry/0/machinery/0/pump/0
```

The feature seed derives from the world seed and this exact string. Array position,
planning-window extent, recipe revision and receipt hash are excluded from identity.
Reordering rules, candidates, children, tags or theme entries does not rename
features. Adding an unrelated rule does not renumber existing slots. Competition
may legitimately change a surviving feature's chosen bounds or candidate while
its identity remains stable; its content revision records that change.

Renaming a world/rule, changing a parent path or reducing/removing its stable slot
intentionally removes or replaces identities. Changing `region_size` changes the
grid namespace and deliberately replaces regional identities;
existing resident content is never automatically reconciled. Material, parameters,
constraint and geometry edits affect revision/plan receipts rather than becoming
new semantic names. The whole compiled plan fingerprint also binds the selected
window and configuration. It is a different object from a feature ID.

## How are hard constraints and preferences resolved?

Rules under one parent run in descending priority, with lexical rule ID breaking
ties. A rule requests an exact `count`; each slot considers distinct authored
candidate rectangles relative to the parent. Candidates rank by weighted
preference score, then finite-curve rank, then candidate ID. Hard constraints
filter this ordered list. Candidate rejection reasons are retained. This is a
bounded, deterministic priority placement strategy: a feasible arrangement that
would require moving an earlier high-priority placement may be rejected. There
is no claim of complete search over all possible layouts.

| Declaration | Exact semantic check |
|---|---|
| `intersects_route` | Candidate intersects an explicit regional passage footprint. Curve succession does not satisfy it. |
| `minimum_separation` | Euclidean distance between sibling rectangle extents is at least the greater of their two requested separations. |
| `floor`, `ceiling`, `wall` | Candidate contacts the corresponding declared solid parent interior surface or a previously placed solid sibling surface. A separate final-cell report checks whether a solid contact survives rasterization; neither check models stability after simulation. |
| `open_volume` | Candidate fits inside a shelled parent's interior and does not overlap a sibling for which either side requires open volume. Ancestors are not competing siblings. |
| `service` | A declared `service` or `liquid` route lies within `neighbor_distance` of the candidate rectangle. This is bounded geometric access, not liquid dynamics. |
| `occupancy_min/max` | Sum of this rule's placed sibling rectangle areas divided by parent rectangle area falls in the inclusive range. It is a semantic area quota, distinct from aggregate material weights. |
| `count` | Exactly this many stable slots are placed per parent unless an authored omission fallback records an exception. Candidate IDs are not reused within the same rule instance. |
| `required_neighbors`, `forbidden_neighbors` | Named sibling tags are present/absent within `neighbor_distance`; final checks see all siblings, including later declarations. |
| `exclusive_family` | At most one placed sibling occupies the named family. |
| `minimum_sockets`, `maximum_sockets`, `connected` | Counts stay within the declared range; connected features have a compatible attached passage socket. Required socket matches are mechanically checked. |
| `allowed_materials` | Declared shell/interior and integrated aggregate contributions must obey the feature's declared material set; an empty set imposes no feature-local material filter. Final hard overrides retain their separate authority. |

Preferences are weighted, finite scores for closeness to a route, parent floor,
ceiling or wall, a boundary between two selected semantic sibling themes, or
progressive finite-curve density. Theme-boundary scoring uses already established
sibling feature geometry and theme records; use higher-priority material-free
scopes to declare the two theme areas. It does not infer themes from resident
cells or silently require a neighboring region to be compiled first.

The default `fallback: "reject"` fails the complete compilation when a required
placement or quota cannot be satisfied. `fallback: "omit"` is an explicit author
choice: an omitted slot/group and its unsatisfied requirement produce fallback
receipts. A later feature cannot count an omitted neighbor as satisfying a hard
requirement. Contradictory constraints, invalid references, hierarchy cycles,
bad socket geometry or exhausted limits are explicit errors; no partially
prepared plan is returned.

Optional `district_assignment` reuses GEN-003's `PreparedRegions` solver for
finite categorical theme assignment. The JSON object contains `specification`
and optional `limits`; `district_themes` maps exact 16-digit hexadecimal category
keys to theme arrays. Wrapped axes require explicit reciprocal adjacency, as in
the [typed contract](procedural-typed-spatial-fields.md). GEN-004 does not add a
second wave-function-like solver.

## How are sockets, routes and finite curves used structurally?

A socket has an authored ID, route type, outward direction, integer edge offset,
odd aperture width, required flag and attachment policy. Width and offset must
fit the selected feature edge. Automatic attachment selects the nearest
compatible predeclared regional route deterministically, checks passage width,
creates an opposite-facing matching socket and an explicit connector that first
exits along the authored normal. Shared boundary ports remain canonical records.
Unsupported or unmatched required connections reject the plan.

Hilbert, Morton and Peano are finite orderings of authored candidate addresses
`order_x/order_y`. Their ranks affect candidate placement, progressive density and
retained inspection/tour order. They can order declared district subdivisions or
apparatus positions without array-order dependence. With `curve_services`,
a bounded service tour visits finite curve sites in rank order and constructs
explicit orthogonal material trunk edges between them, joined to the straight
regional service. Hilbert/Morton use at most sixteen sites and Peano nine; a
Morton jump is an authored L-shaped route, not an inferred adjacent step.
Curve ranks never replace the
explicit edge geometry used by hub arms, loops, utility trunks and socket
connectors. Hilbert/Peano adjacency holds only inside their documented finite
domains; Morton may jump. A sorted list of features alone is not a physical route.

## How does a semantic plan become material cells?

The base Strata, Flow Network and District Grammar candidates, existing brush
controls, native modules, scalar/typed fields and aggregates remain available.
Semantic feature proposals supply bounded shell/interior material and optional
aggregate/application/exclusion references. Named field references use the
retained normalized mask contract; general scalar, vector and category values
must first convert explicitly. The final semantic route carve is applied before
final hard material overrides, which retain their existing authority.

`geometry_exports` maps at most sixteen aliases to exact semantic route or
feature IDs. A route export contains that route's actual ordered points; a
feature export contains its rectangular boundary. The alias is the immutable
geometry name consumed by a GEN-003 `geometry_distance` node. Separate routes
are never concatenated into fictitious joining segments. Exports are validated
before typed graph compilation; changing geometry changes graph identity.

Inspection exports complete ancestry, rule/candidate choice, constraint and
fallback receipts, socket matching, geometry inputs and material decisions.
Copied semantic/cell data belongs to the caller, with no borrowed World storage.
The [interface reference](../reference/interfaces-and-message-contracts.md)
owns the exact C++ and Godot method/packet names.

### What does floating-square route validation prove after a hard override?

`validate_routes()` checks **final rasterized cells**, after fields, modules,
aggregates and hard overrides, for an explicitly declared odd square clearance.
This is the `floating-square-v1` geometric profile with four-neighbor
connectivity. At the finite window edge, footprint checks are clipped to the
canonical shared aperture; the report explicitly sets `boundary_apertures`.
Independently planned opposite halves complete that aperture, and stitched
boundary controls are required to establish the full crossing. It does not
model gravity, jumps, a particular articulated actor, controllers or material
motion after simulation. An authored hard override can intentionally block a
required route: material output preserves the override and the route report
records failure. A blocked report must not be described as successful traversal.
No abstract graph result substitutes for this final-cell check.

For a semantic-plane recipe, additional projections can subsequently change
material. The [GEN-007 qualification oracle](../operations/procedural-qualification.md#how-are-routes-checked-after-all-material-decisions)
therefore checks the final projected play plane independently, with the same
distinction between geometric clearance and actor traversal.

The same report separately exposes `supports_passed` for the
`static-solid-contact-v1` profile. For each declared floor, ceiling or wall
constraint it inspects final material cells immediately outside the feature's
rectangle. A check passes when at least one inspected cell has `MaterialState::Solid`;
the wall check inspects both vertical sides. It retains checked/missing counts,
the first missing coordinate and the feature/constraint identity. Partial contact
can therefore pass, and `passed` still means the route profile alone. A consumer
requiring both qualifications must inspect both booleans.

This catches total removal of a required support by routes, modules, modifiers
or final overrides. It does not establish that the whole apparatus survived,
that its support spans the entire footprint, that the solid is itself grounded,
or that the resulting assembly remains stable after simulation. Cell provenance
and fixture-specific raster controls are needed for those stronger claims.

## What are the work, memory and failure bounds?

The [configuration reference](../reference/configuration-reference.md#hierarchical-generation-limits)
owns exact defaults and hard maxima. The planner bounds region count, rules,
hierarchy depth, children, candidates, feature/socket/route records, spatial
queries, solver work, prepared bytes and raster verification size/work, including
support-contact scans and retained reports. There is
no arbitrary-coordinate recursive neighbor query. Queries inspect only the
finite immutable plan. Successful per-cell proposal sampling performs no heap
allocation; generation jobs retain complete private output until Ready.

Logical work measures conservative declared work rather than wall-clock time or
machine instructions. Compiling a requested window and validating its final
raster are separate bounded operations. Low work/memory limits, malformed input,
failed attachment, solver exhaustion, cancellation and raster-budget rejection
must expose actionable errors and no partial published plan, cells or diagnostics.
Final blocked-route reports preserve the complete authored material proposal;
that is a reported content conflict rather than partial publication.

## How do I author and inspect the multi-district example?

Load [`hierarchy-multi-district.json`](../../examples/worldgen/hierarchy-multi-district.json)
through the Workbench hierarchy example control or `CyberWorldGenerator.configure`.
It covers `[-128,-128,256,256]` cells in four canonical 128-cell regions, using
64-cell storage chunks. Each region contains semantic theme subdivisions, one
104×72 foundry, a 64×66 gallery, a machinery bay, an inspection dais with floor
and wall constraints, a floor-mounted pump, a ceiling console and two embedded
dais lights. The machinery bay occupies
22.22% of its foundry. Neighbor, separation, service, exact multiplicity, socket
and occupancy constraints are authored data.

The profile uses the shared finite assignment solver for district theme blends,
order-1 Hilbert-ranked foundry candidates and detail placement, a real theme-boundary
preference for a marker, explicit primary routes and secondary loops, a four-site curve-ordered service
tour and straight service/liquid trunks, a prepared vault module, a weathered aggregate shell and a
typed distance mask around an exported tour loop. Its Strata base is composed
with Flow Network and District Grammar overrides. `get_semantic_plan()` exposes
the hierarchy and receipts; `inspect_cell()` reports contribution provenance;
`validate_routes()` reports the declared final-cell traversal and support-contact
qualifications separately. The example deliberately places its compact apparatus
away from both semantic passage footprints and the existing candidate macro
network for the authored seed. Its retained qualification and the footprint
inspection are recorded in the [dated audit](../audits/2026-10-21-gen004-hierarchical-generation.md).

For a new place, choose its canonical region/window and stable rule IDs first.
Declare parent-relative candidate rectangles and exact counts, then add hard
requirements and socket apertures. Give higher-priority scopes to required
supports or theme areas. Add preferences only after a valid hard layout exists.
Use explicit omission fallback only when absence is an acceptable authored
outcome. Inspect semantic receipts before tuning masks/materials, then recheck
final raster routes after any hard override. Save accepted JSON with full numeric
precision using the existing Workbench configuration path.

[`grammar-v1.schema.json`](../../examples/worldgen/schemas/grammar-v1.schema.json)
is the versioned JSON authoring schema for the `grammar` member of a schema-3
recipe. The native compiler additionally checks relational, geometric, type,
cycle, work and memory invariants that JSON Schema cannot establish. The
[build guide](../operations/local-build-and-validation.md#hierarchical-generation-example-and-acceptance)
routes executable tests. Human movement feel, Windows/browser behavior and
render throughput require their own dated execution evidence.
