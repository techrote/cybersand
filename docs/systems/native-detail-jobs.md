---
title: Bounded native detail job registry
status: Current
document-kind: contract
scope: WORLD-STEER-COLLABORATIVE-ARCHITECTURE-M6-M7-001
canonical-for: [native-detail-jobs]
last-reviewed: 2026-11-24
related-documents: [native-module-connections-v2.md, architecture-staged-construction.md]
---

# Bounded native detail job registry

**Draft / HOLD.** `native_detail_jobs.gd` supplies eight code-owned procedural
workers. They consume copied material bytes and typed parameters and return
finite native-stage proposals. They cannot call providers, execute generated
scripts, access arbitrary files, own a World or apply operations. Fixture and
procedural calls are explicitly recorded as zero model calls.

| Executor | Geometry and contextual contract | Independent controls |
| --- | --- | --- |
| `contextual_ribs` | Repeated connected bars project from observed supporting faces | Face, width, depth, spacing, density, seed |
| `surface_trim` | Thin tangent strips follow a complete occupied source face | Face, length, depth, spacing, density, seed |
| `anchored_clutter` | Small connected bosses remain attached to original source material | Face, width, depth, spacing, density, irregularity, seed |
| `service_panel` | A complete framed local panel with bounded cross ribs | Frame thickness, rib count |
| `mechanical_infill` | Thin fins occupy an explicit empty bay and meet its prior frame | Orientation, thickness, spacing, seed |
| `short_pipe` | One finite orthogonal route joins two observed source faces | Two to eight waypoints, width |
| `framed_opening` | A complete connected door/window frame preserves an explicit Empty interior | Opening type, frame thickness |
| `edge_wear` | Bounded removal from declared noncritical Hard wall edges | Amount, seed; explicit variable/fixed/attachment scopes |

Geometry dimensions, irregularity, clutter density and damage amount are separate
controls with different effects. No control rescales a harvested module or
silently changes its material role. A deterministic frame or fixed route can
produce identical geometry under different seeds; that is reported as apparatus
equivalence, not evidence of model quality or architectural diversity.

## Typed source and budget contract

`describe_jobs()` returns names, intent, fixed executor identities and UI control
descriptors. `compile_job(kind, params, context)` accepts only known parameter
fields. Common parameters are `region`, `material`, `seed` and `max_cells`.
Regions are integer `[x,y,width,height]`; each job is at most 128 × 128 cells and
16,384 proposed cells. Local pipe centerlines are at most 512 cells. A worker
emits at most 128 separately source-anchored components and inspects at most
1,048,576 candidate/clearance cells before returning an explicit exhaustion.

The host context contains a complete copied `source_cells` uint16 material plane,
its exact `source_sha256`, world-coordinate `region`, explicit allowed material
identities and a finite `max_cells`. Its region is at most 512 × 512 and must fit
the bounded World coordinate range. An optional positive `generation` is retained
as another input identity. Protection, clearance, fixed and variable rectangles
share an explicit combined 256-rectangle limit. At most 8,192 attachment cells can
be protected individually. A declared clearance must fit the actual inspected
source and already be Empty.

Every additive worker writes only Empty source cells. Each emitted component
must touch original observed support material; newly proposed detail cannot
invent its own support. The default support policy observes Hard wall, Metal,
Stone and Wood; a bounded explicit host list can narrow or change this authored
policy. The destination must belong to both the host palette and the accepted
Workbench material palette. No palette expands source overwrite permission.

`edge_wear` emits Empty only over existing Hard wall within explicit variable
regions. It preserves all protected/fixed/attachment cells. A sufficient local
topology check requires the removed cell's occupied cardinal neighbors to remain
connected through its surrounding 3 × 3 ring. This deliberately refuses some
globally safe removals needing a wider route. It cannot remove Metal or Wood
through the native Art executor's source restriction, and it does not claim
physical structural safety.

## Proposal and native handoff

A successful result has format `cybersand-native-detail-job-v1` and status
`proposed`, with exact native pixel operations, material identities, actual
footprint, source/parameter hashes, seed, bounded resource counts, preserved
guard scopes, geometric solid contacts and any generated clearances. Its full
typed value is checksum-pinned. Counts describe a zero-write proposal, not
completed native construction.

`stage_from_job(job, id, intent)` validates the unchanged worker result and returns
an ordinary finite stage. It preserves all operations, permissions, guard,
clearance and contact requirements; it sets `input_snapshot_sha256` and, when
supplied, `input_generation`. The stage compiler must compare these fields with
its fresh host capture. A stale worker result is regenerated rather than silently
reinterpreted against a different source.

The stage's required region is the inspected context region, which includes
supporting cells outside the smaller write footprint. The standard preview,
owner decision, executor, Stop, receipt and authoritative readback path remains
mandatory. Opening a tool or selecting a registry entry dispatches no inference
and performs no construction.

## Verification

`test_native_detail_jobs.gd` (`NATIVE_DETAIL_JOBS_RESULT`) independently checks
all eight source-grounded fixtures, material/region/protection/fixed/attachment
preservation, exact host-recomputed budgets, deterministic outputs, four distinct
variation controls, source tampering, unsupported route geometry, obstructed
openings, forbidden Metal erasure, topology-preserving damage and finite scan
exhaustion. These synthetic fixtures are not native qualification. Actual native
comparisons must retain their source/runtime identity, source and result planes,
raw receipts, refusals and explicit runtime configuration separately.
## Matched native detail controls

`godot/data/batch_lab/m67/detail-experiment.v1.json` freezes eight jobs and three
arms (deterministic, seeded and random-valid) before native observation. Its
SHA-256 is `4e69cbdbca9a908ed2062cfc60b7bf448c4a44a73c1a5cd90b8640daabb16852`.
The 24 cases share each job's source geometry, native budget, material permission,
protected/fixed/attachment scopes and clearances. Random-valid programs match the
seeded program's changed-cell count; they deliberately lack the tool's contextual
anchoring, frame, endpoint-route and local wear topology constraints.

`test_native_detail_jobs_native.gd` compiles every proposal before execution,
checks a changed-source refusal, then applies it with the existing private native
Batch owner. It retains all completed/refused/partial/unobserved cases, exact
before/after uint16 planes, original native records, approved stage JSON and
source identities. Use `NATIVE_DETAIL_EVIDENCE_DIR` and the exact
`CYBERSAND_SOURCE_REVISION`; `NATIVE_DETAIL_PREFLIGHT_ONLY=1` runs only pure
compilation and grants no native qualification. The optional
`ARCHITECTURE_DEVELOPMENT_CORE_CAPACITY=128` selects an explicitly recorded local
memory configuration; normal hosted qualification must leave it unset.

`tools/batch_lab/evaluate_detail_jobs.py` independently validates receipt counters,
plane/file hashes, source identity and accepted-edit replay, then measures scoped
writes, clearances, source anchoring and occupied face components. It retains the
fixed denominator and reports when deterministic and seeded output are identical.
Native history is corroborated against full planes; the reducer does not claim to
reconstruct unretained per-chunk readback rows or cryptographically attest a run.
These are tool capability and geometric constraint diagnostics, with zero model
calls. They establish neither aesthetic preference nor actor traversal or physics.

## Exact endpoint and attachment protection

Pipe width is transverse to each orthogonal segment. Terminal faces use butt
caps; only interior elbows receive square corner fills. Every transverse cell of
both terminal faces must meet observed source material in the outward axial
direction. Thus widths one through four can join existing pipe faces without
including an occupied anchor in the emitted Empty-only operations. Unrelated
occupied intersections and incomplete source faces refuse the entire route.

Attachment cells are preserved both by the worker and by the ordinary native
stage protection contract. The worker converts their exact coverage into row
runs, merges only identical adjacent runs, and keeps holes unprotected. It refuses
an envelope exceeding the stage's combined 64 protected-region bound rather than
using a larger bounding box. A live host can supply
`native_protected_region_count` for its complete retained protection inventory;
otherwise the supplied `protected` list count is reserved. Final StagePlan
validation always recomputes the actual combined host and stage envelope.

`test_native_detail_contracts.gd` independently checks both route directions and
orientations at widths one through four, a thick elbow, unrelated collisions,
incomplete terminal faces, exact sparse/dense guard coverage, host-level injected
connector erasure and explicit protection-capacity exhaustion. The earlier
`aa2dee5d4` native 24-case observations retain their exact original source identity;
these corrections preserve that registration's emitted programs and geometry.
