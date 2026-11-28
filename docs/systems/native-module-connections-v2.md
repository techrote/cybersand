---
title: Native module v2 connection contracts
status: Current
document-kind: contract
scope: WORLD-STEER-COLLABORATIVE-ARCHITECTURE-M6-M7-001
canonical-for: [native-module-v2-connections, native-module-snap]
last-reviewed: 2026-11-24
related-documents: [native-architectural-modules.md, architecture-staged-construction.md]
---

# Native module v2 connection contracts

**Draft / HOLD.** This successor adds explicit contact and reservation semantics
to the material-only native module codec. V1 documents keep their exact serialized
fields, content identities, placement behavior and explicit required-line refusal.
No import silently upgrades a document. No connection check establishes physical
load capacity, structural stability or actor traversal.

## Versioned authored metadata

`cybersand-native-module-v2` adds a `fixed_regions` rectangle list to the existing
root fields. A fixed rectangle cannot overlap a variable rectangle. All geometry
outside the declared variable rectangles remains fixed as before. Clearances
retain their separate meaning: observed Empty cells which must remain Empty in
the host projection. Protected regions remain no-write masks. Empty material is
transparent during placement; fixed metadata does not silently authorize erasure.

Every v2 attachment retains the v1 fields and adds:

| Field | Contract |
| --- | --- |
| `role` | Explicit authored functional identifier, such as `support` or `pipe` |
| `approach` | `face`; no diagonal or tolerance-based approach |
| `polarity` | `neutral`, `socket` or `receptor`; socket/receptor point kind must agree |
| `capacity` | 1–16 distinct placed-instance/connector partners; point connectors always have capacity 1 |
| `contact.policy` | `full` or `overlap`; points use `full` |
| `contact.minimum_cells` | Positive inclusive span length for full contact, or explicit minimum overlap |
| `contact.tolerance` | Exactly zero |

Lines have distinct integer axis-aligned `point` and `end`, inclusive of both
endpoints. Their cardinal `facing` is perpendicular to the line. Every declared
contact cell must be occupied in the module's own observed material plane, with
an Empty outward neighboring cell or an outward face beyond the local bounds.
Inferred metadata can remain optional; it cannot become a required contract.
The module admits at most 8,192 declared contact cells.

Endpoint ordering is retained in the source document and its hash. Matching
derives an ordered tangent span without rewriting the stored document. All six
existing orthogonal transformations transform endpoints and facing together.
No scale, arbitrary-angle rotation or geometric tolerance is introduced.

## Contact and reservations

`native_module_connections.gd.resolve(connectors, bindings, context)` consumes
transformed descriptors returned by `Module.compile`, with host-supplied stable
`module_instance` identities. Each v2 descriptor retains its own derived occupied
contact cells. The host supplies `region` and a complete `projected_cells` plane;
the resolver does not read or write a World.

V2 contact requires different placed instances, equal functional roles, at least
one shared compatibility tag, opposite facing, compatible polarity, and exactly
one-cell face adjacency. Neutral mates with neutral; socket mates with receptor.
Point-to-line contact and mixed v1/v2 contracts require an explicit authored
adapter part. Coincident v2 contact cells do not count as adjacent contact.

When either side requests `full`, the actual contact covers both complete spans.
When both sides request `overlap`, contact covers at least the larger declared
minimum. Actual material occupation is checked against the final projection;
metadata or a neighboring module cannot substitute for a missing own-geometry
contact declaration.

An explicit binding has this value shape:

```json
{"a":{"instance":"pier-1","connector":"head"},
 "b":{"instance":"span-1","connector":"bearing"}}
```

The resolver derives contact intervals itself. It counts distinct instance and
connector partners and refuses any overlapping booked contact cell, even when
unused logical partner capacity remains. Templates in the library never consume
capacity. Different connector identifiers or overlapping placed instances cannot
alias the same occupied world-coordinate outward face; use a single connector
with several compatibility tags. Perpendicular
faces meeting at a corner remain distinct. A required v2 connector with several eligible partners refuses until
the proposal names the binding. One unique eligible required partner can be
resolved deterministically. Optional connectors consume no reservation unless
explicitly bound or selected by a required partner.

`context.existing_bindings` uses the same reference shape. All referenced
connectors must belong to the inspected graph and remain grounded in the supplied
projection. Historical declarations alone are not live reservations. The host is
responsible for refreshing the complete relevant native scope before approval.
At most 512 connectors, 512 total bindings and 65,536 declared contact cells fit
one inspection. Results retain actual contact spans, counts, occupancy and
unmatched optional connectors. V1 retains legacy point mating and no inferred
capacity semantics.

`check_reserved_contacts(current, connectors, retained)` is the shared stage/snap
reservation guard. It counts the union of retained and **all** newly proposed
partners, deduplicates exact reinspection, and reserves physical world-coordinate
faces regardless of connector or placed-instance naming. A retained pair cannot
silently move its booked interval. Retained endpoints can lie outside the current
inspection; their conservative reservation remains until the host explicitly
retires its live workflow or World. This does not claim their old material has
been freshly observed. Imported history must never enter this host-only argument.
At most 2,048 retained contacts and 262,144 paired face cells are inspected.

## Finite zero-write snapping

`snap_candidates(module, source_connector_id, target_descriptor, controls)`
returns proposed `origin` and `transform` placements. Controls include the exact
bounded projected plane and region, material permission, protection, clearances,
existing connectors, bindings and host-only `reserved_contacts`, preferred origin, allowed transforms, result
limit and search budget. Optional palette and bounded variation pass through the
normal module compiler.

The search enumerates exact full-span alignments or inclusive integer overlap
offsets. It sorts by distance from the preferred origin, declared transform
order, then y/x. It considers at most 2,048 poses and 1,048,576 candidate module
cells, returning at most 64 poses. The default is 256 considered poses and 24
results. Results report considered poses, scanned cells, truncation and refusal
reasons. No fit after complete enumeration is `refused`; an incomplete search
with no candidate is `exhausted`. Finding candidates can still report truncation.

A snapped candidate's occupied material must fit Empty target cells. It cannot
hide overlap behind ordinary Hard wall replacement permission. Its local
clearances and the host's protection/clearances are checked, and the exact chosen
connection is resolved with existing reservations. These are proposals against
supplied bytes. Only the ordinary stage host's fresh native inspection, approval,
execution receipts and authoritative readback establish construction.

## Metadata editing and compact inspection

`Library.draft_metadata(id, expected_content_sha256, patch)` validates a detached
authored draft without mutating the retained module. `commit_metadata` checks the
same expected hash and validates the candidate again. Editable fields are name,
tags, structural kind, anchor, transforms, roles, attachment declarations,
clearance/protection/fixed/variable rectangles and design-card identifiers.
An explicit `format` change can upgrade v1 to v2; downgrading v2 silently is
refused. Geometry, module identifier, extent, retained recipe and provenance are
not editable through this boundary.

A changed manifest receives a new content hash and retires volatile current
session native observation, even when the material plane is unchanged. Imported
or self-declared qualification flags still confer no live native authority.
Summaries are cached on validated adoption and returned as detached values;
ordinary browser search/refresh does not decode every module plane repeatedly.

## Verification boundary

`test_native_module_v2.gd`, marker `NATIVE_MODULE_V2_RESULT`, checks independent
scalar transforms, asymmetric/reversed spans, negative origins, odd/even contact,
capacity and interval conflicts, ambiguity, empty/buried contact, stale metadata,
v1 compatibility and deterministic finite snap refusal/exhaustion. Its material
planes are explicitly synthetic pure-compiler fixtures. Native transformed replay,
graphical inspection and physical owner acceptance remain separate evidence.
