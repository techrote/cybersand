---
title: Native architectural modules
status: Current
document-kind: contract
scope: WORLD-STEER M3 Draft/HOLD material-module codec, library, exact compilation and native harvesting; physical acceptance remains separate
canonical-for: [native-architectural-modules]
last-reviewed: 2026-11-24
related-documents: [../operations/world-steer-batch-lab.md, workbench-direct-art-batches.md, ../architecture/shared-workbench-authoring-data.md]
---

# Native architectural modules

The WORLD-STEER M3 successor adds reusable material geometry to the existing
Batch Lab. `native_module.gd` is a bounded value codec and zero-write compiler;
`native_module_library.gd` owns user-selected module documents. Native World
ownership, material laws, the ordinary PAINT/Art executor and shared history are
unchanged. This is Draft/HOLD implementation. Graphical, packaged Windows and
physical owner acceptance require separately identified evidence.

## Observation, declared meaning and qualification

A module preserves the exact uint16 little-endian material IDs from a copied
native readback. The crop includes Empty cells and records source extent, crop,
whole-plane hash and cropped-plane hash. It does not retain temperature,
fractions, velocity, active actors, physical masks or evolved simulation state.

Batch harvesting requires a completed tile, its exact material checksum and
retained `CyberNativeCellWorld` execution receipts. A queued, partial, refused or
uncaptured tile cannot be presented as a successful harvested module. The
Workbench region gateway uses the existing read-only capture adapter and never
adopts a Flatten baseline or clears ordinary authoring history.

Bounds and material identities are observed. Names, tags, roles, attachment
relationships and clearance declarations are explicitly authored metadata.
Inferred attachments must say `source: inferred` and cannot establish a required
construction contract. Unknown roles and attachments remain absent. A connector
named `support` is not a physical support certificate. The library does not
import the SWARM negotiation solver or certify any GOLDMAPS source map.

`native_readback_verified` is a **volatile host observation**, keyed to the exact
module content hash. Successful live harvesting can establish it. Plain document
addition, import and fresh-process library reopening cannot self-certify native
evidence from serialized flags; their summaries default to false. Fresh native
replay can qualify the exact original material plane again. Retrieval can thus
distinguish metadata-compatible parts from currently native-observed parts.
Neither status establishes physical Windows gameplay acceptance.

## Material document and limits

The JSON format is `cybersand-native-module-v1`.

| Field | Contract |
| --- | --- |
| `id`, `name`, `tags`, `part_type` | Stable safe identifier, human name, searchable tags and explicit structural vocabulary |
| `extent`, `anchor` | Local integer dimensions and an anchor within the bounds |
| `geometry` | Exact LE16 plane, canonical Base64 encoding and SHA-256 |
| `allowed_transforms` | Explicitly permitted exact orthogonal transformations |
| `attachments` | Vertex, axis-aligned line, socket or receptor with local point, facing, compatibility, required flag and semantic source |
| `clearances` | Authored local rectangles proven Empty in the captured geometry; placement must verify them against its actual World |
| `protected_regions` | Local no-write rectangles; occupied module geometry intersecting them refuses compilation |
| `roles` | Unambiguous authored source-material roles and an explicit compatible replacement palette |
| `variation_regions` | Local cells eligible for bounded seeded thinning; attachment cells remain fixed |
| `provenance`, `recipe`, `design_card_ids` | Original source/capture evidence, retained program and explicit reference links |
| `content_sha256` | Canonical complete manifest hash, excluding this hash field itself |

Each side is at most 512 cells; a module has at most 262,144 observed cells and a
2 MiB document envelope. Provenance and recipe together are limited to 256 KiB.
The library holds at most 128 modules and 64 MiB. Unknown fields, malformed
dimensions, duplicate identifiers, ambiguous roles, invalid clearances,
credential fields and mismatched hashes refuse before adoption. Very large
native instance IDs are retained as prefixed decimal text because JSON number
decoding cannot preserve all signed 64-bit values.

Unknown but observed uint16 IDs remain exact in the document. Placement refuses
IDs outside the actual host paint palette; it does not silently replace them or
expand normal material permissions. This distinction permits honest inspection
of captured geometry without inventing an admitted native reconstruction path.

## Exact placement and Empty semantics

`compile(module, placement, constraints)` takes an integer destination `origin`,
an allowed `transform`, optional role `palette` and bounded `variation`. Origin
is the transformed bounding box's top-left corner. The transformed anchor and
connectors are returned separately. Identity, horizontal/vertical mirror and
90/180/270-degree rotations preserve the integer grid. No rescaling, arbitrary
rotation, perspective or platform-top geometry is introduced.

The host supplies the authorized region, protected rectangles, allowed material
IDs and maximum native cell budget. The compiler calculates the exact footprint,
unique occupied count and deterministic row runs. It refuses any occupied
protected-cell intersection or out-of-region footprint rather than clipping.
Operations and proposed cells remain proposals until the native executor supplies
receipts and readback.

**Empty cells are transparent during placement.** They are preserved in the
module document and in exact replay onto an Empty destination, but they do not
erase existing World content. Explicit `clearances` declare which Empty spaces
must actually remain clear; the stage host must check the captured destination
and authoritative result. An undeclared Empty cavity is not silently called a
traversal corridor. Erasure requires a separately approved native drawing plan.

Palette substitution affects only materials assigned to the specified role,
only to the authored compatible list, and only within host permissions. It is
an authored material-choice policy, not a claim that the materials have equal
chemistry or physical properties. Seeded variation removes only cells inside
declared variable rectangles and preserves attachment vertices/lines. The
returned removal count is exact; no arbitrary new detail is synthesized.
Thinning can disconnect decorative material even while staying inside its
authorized rectangle. It does not preserve structural continuity. The three
primary module compositions use complete housing ribs; variation is exercised
as a separate bounded operation and never serves as evidence of architectural
quality.

## Library interaction and persistence

The default library document is `user://architecture/modules/library.json`,
separate from provider credentials, conversation history and ordinary saved
Workbench starts. The public API supports inspect, search by terms and structural
filters, name/tag annotation, explicit replacement, remove, import and export.
Callers receive detached dictionaries; editing a returned value cannot mutate the
retained library.

Save/export writes a complete temporary file and uses the accepted native atomic
replacement primitive. A failed write or invalid import retains the previous
document/library. Reopening validates every module and the complete library
checksum before adopting anything. Module placement itself uses the existing
native stage/PAINT executor and its receipt-based shared Undo/Redo contract;
library edits do not masquerade as World history.

The eight starter definitions in `native_module_examples.gd` are explicitly
unexecuted typed recipes. Their source programs construct columns, trusses,
floors, doorways, return pipes, galleries, housings and stepped transitions. A
starter library is populated only after those recipes actually execute in the
native Batch Lab and their tight local regions are harvested and replayed.

## Structural vocabulary and future composition

| Vocabulary | Meaning of the declaration |
| --- | --- |
| `column_support` | Vertical support or bearing part |
| `beam_truss` | Span, beam, braced or trussed assembly |
| `floor_ceiling` | Deck, floor or ceiling section |
| `viaduct_segment` | Repeated elevated passage or bridge section |
| `wall_facade` | Wall, envelope or façade section |
| `window_door` | Framed opening or door/window assembly |
| `passage_clearance` | Explicit negative-space requirement |
| `mechanical_housing` | Machine enclosure or mounted service assembly |
| `pipework` | Service pipe or conduit assembly |
| `service_gallery` | Deck/corridor and service infrastructure |
| `greeble_cluster` | Bounded local detailing |
| `irregular_transition` | Change of level, width, orientation or adjacency |
| `unclassified` | Observed geometry without an asserted architectural role |

Gentek interoperability is a value boundary: local geometry, declared connectors,
roles, bounds and provenance can feed a future composition adapter. This module
format neither implements SWARM negotiation nor consumes unfinished SWARM
branches. Larger plans can repeat modules with finite explicit placements and
stage dependencies while keeping authority in the existing native executor.

`architecture_module_compositions.gd` assembles a 480 × 320 hangar, a 384 × 256
service stack and a 480 × 320 transfer viaduct from 32, 41 and 37 explicit module
instances respectively. Each three-stage plan pins the caller's exact module
manifest hashes and declares empty passage bands. These are proposed typed
plans until ordinary Workbench approval, native receipts and complete material
readback establish execution.

## Qualification

`test_native_module.gd` checks exact asymmetric scalar transform oracles,
immutability, role palettes, bounded variation, protection, malformed documents,
unknown material refusal, real native harvest, fresh native replay, actual native
Undo/Redo and atomic save/import/export. Run it a second time with
`NATIVE_MODULE_MODE=reopen` and the same isolated `NATIVE_MODULE_LIBRARY_PATH` to
exercise fresh-process persistence and native reconstruction.

`test_native_module_examples.gd` constructs all eight starter parts through the
actual Batch Lab, harvests tight native readbacks, exports reusable documents,
then reconstructs them on fresh native tiles and compares exact material planes.
`NATIVE_MODULE_EVIDENCE_DIR` optionally retains reports, module documents and
clearly labelled native material-ID images. These images are material evidence,
not a substitute for actual graphical Workbench qualification.

Both tests require the source-compatible native runtime. Test result markers are
`NATIVE_MODULE_RESULT` and `NATIVE_PARTS_RESULT`; a passing marker is scoped to its
recorded source/runtime/platform. Physical playability and subjective design
preference remain separate owner gates.

`test_architecture_stage_modules.gd` independently checks required socket
grounding, transformed module protection, occupied clearances, palette/source
permissions and all nine sequential module-composition projections. Its marker
is `ARCHITECTURE_STAGE_MODULE_RESULT`.

`test_architecture_module_compositions.gd` first constructs and harvests all
eight source parts, then executes all nine composition stages in fresh ordinary
Workbench Worlds. It compares every stage cell with its approved projection,
verifies every outside-region cell is unchanged, and exports exact native
receipts, portable authored starts, reusable module documents and diagnostic
planes to `ARCHITECTURE_MODULE_COMPOSITIONS_DIR`. Its marker is
`ARCHITECTURE_MODULE_COMPOSITIONS_RESULT`. Every complete starter and final
primary composition is also required to form one four-neighbor material
component; that geometric contact test does not certify physical stability.

Development evidence is retained separately: exact native replay initially
passed while one-cell diagonal Warren braces touched only at corners, housing
ribs floated inside their frame, and thinning fragmented those ribs. The first
three native modular compositions had 251, 210 and 230 four-neighbor material
components respectively. The corrected recipes use two-cell staircase braces,
top-attached housing ribs and unthinned primary placements. This source-specific
repair addresses a real architectural defect that exact replay alone did not
detect; it does not rewrite the frozen five-arm comparison or its conclusions.
