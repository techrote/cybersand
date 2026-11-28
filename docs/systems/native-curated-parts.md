---
title: Curated native architectural parts
status: Current
document-kind: contract
scope: WORLD-STEER-COLLABORATIVE-ARCHITECTURE-M6-M7-001
canonical-for: [native-curated-parts-catalogue]
last-reviewed: 2026-11-24
related-documents: [native-architectural-modules.md, native-module-connections-v2.md]
---

# Curated native architectural parts

**Draft / HOLD.** `native_module_catalogue.gd` defines forty genuinely distinct
orthographic source recipes. The original eight v1 definitions remain unchanged.
Thirty-two new v2 parts add different structural scales, asymmetric transitions,
explicit occupied-face connection spans and useful negative space. Palette or
mirror variants do not count as separate catalogue parts.

| Group | New source parts |
| --- | --- |
| Foundations and supports | Stepped bearing foundation; tapered monumental pier; offset side buttress; forked service column |
| Spans | Deep cellular box girder; alternating deep lattice truss; parabolic arch rib; triangulated cantilever bracket |
| Floors and transitions | Double-deck passage frame; ceiling service tray; shallow stepped access ramp; offset half landing |
| Envelopes | Paired window facade; tall open blast-door frame; louvered shutter bay; narrow pressure bulkhead |
| Access structures | Vaulted masonry viaduct; asymmetric cable gallery; service access ladder; diagonal transfer spine |
| Pipework | Square elbow; three-way tee; four-way crossing; valve chamber; offset three-branch manifold; raised expansion loop; triple vertical stack; twin parallel tray |
| Equipment and detail | Offset pump on plinth; open instrument rack; framed vent grille; fractured wall-to-deck transition |

New parts range from 16 to 96 cells wide and 16 to 80 cells tall. They are authored
at their native scale rather than rescaled at placement. Each complete source
part is intended to form one four-neighbor occupied-material component. That
geometric condition does not certify mechanical support, actor accessibility,
fluid flow, ladder climbing or active machine behavior.

## Source, templates and actual modules

`recipes(include_legacy=true)` returns finite source programs with the same shape
as the eight starter recipes: source extent, bounded operations, tight harvest
region and authored module metadata. New recipes use private 128 × 128 sources;
the original eight retain their existing 64 × 64 sources. `descriptions()` gives
compact authored intent, dimensions and interface declarations without claiming
native execution.

`template_library()` is an explicitly zero-write planning bootstrap. It projects
these code-owned rectangles into copied bytes, validates their module contracts
and returns a library whose native observation flags are all false. Its
provenance says `unexecuted-typed-recipe-projection`, retains the source program
and exact recipe hash, and never fabricates native receipts. The returned object
is useful for offline planning and fixtures; it does not replace native building.

The ordinary private Batch controller can construct the recipes, then
`Library.harvest_tile` extracts their exact material planes from actual completed
native readback. Only that current-session host path grants volatile native
observation. Saved/exported module documents retain historical provenance;
importing them does not restore a live qualification flag.

## Connections and variation

Each new part declares grounded optional v2 face contacts. A planner can bind
them explicitly or create a reviewed metadata revision that makes a contact
required. Common interfaces include four-cell deck edges, four-cell pipes,
specified bearing widths, wall courses and bounded mounting rails. Their names
describe authored fit and function, not physically interchangeable materials.
Larger multi-port junctions expose distinct physical ports; no single exclusive
socket is reused under several names.

Three infill/detail parts and the irregular wall transition explicitly separate
variable interior or edge fragments from fixed framing. Fixed regions and all
contact faces survive bounded thinning. Existing per-cell thinning can still
fragment noncritical decoration; it remains a visibly separate variation
control, never a claim of preserved structural coherence. Primary source
definitions remain complete, face-connected geometry.

## Qualification

`test_native_module_catalogue.gd` (`NATIVE_CATALOGUE_RESULT`) uses an independent
rectangle raster and explicit scalar transform matrix. It checks distinct
geometry, one face component, clearances, grounded contacts, all permitted
transforms, safe source-material operation ordering, unchanged original recipes
and unqualified template bootstrap. These are pure projections.

`test_native_module_catalogue_native.gd` (`NATIVE_CATALOGUE_NATIVE_RESULT`) runs
one actual native World at a time through the existing Batch controller. It
constructs all forty parts, harvests them, translates every identity replay, and
executes every additional permitted mirror/quarter-turn for four selected
asymmetric parts. Complete material planes are compared with independent scalar
oracles. A protected Stone marker and the native arena outside each footprint
must remain unchanged. All one hundred actual attempts are retained, including
any failures.

Set `NATIVE_CATALOGUE_EVIDENCE_DIR` and exact `CYBERSAND_SOURCE_REVISION`. Evidence
contains `curated-library-v2.json`, forty reusable module documents, exact u16le
planes, original source/replay receipt records and categorical native-material-ID
images. The images are labelled diagnostics; actual Godot graphical captures and
owner gameplay acceptance are separate gates. Reopening the saved library is
also checked to grant no current-session native authority.
## Declared wear example

The fractured-wall transition includes an authored expendable Hardwall shoulder
at local `[28,44,12,12]`, separate from its fixed wall backbone, deck base and
contact faces. `edge_wear` can remove a bounded set of boundary cells there while
preserving the registry's local connectivity guard. Its Metal edge fragments
remain ineligible for erasure. This is a metadata addition: the exact material
geometry and the original eight recipes are unchanged. Previously retained
native catalogue observations keep their earlier content identities; the revised
metadata requires fresh native placement evidence before the live UI grants wear.

`test_native_detail_catalogue_wear.gd` checks the complete source plane, practical
16-cell wear, fixed/contact preservation, protection override and one resulting
face component. These pure checks do not claim native execution or stability.

## Actual shader and contact gallery

`test_native_module_catalogue_render.gd` verifies each exported module against
its original completed native source record and every material cell in its crop.
It then renders forty clean part images through the existing Godot material
shader and a labelled overview with authored contact-span overlays. It creates
no World and performs no construction. Set `NATIVE_CATALOGUE_EVIDENCE_DIR`,
`NATIVE_CATALOGUE_RENDER_DIR` and the exact `CYBERSAND_SOURCE_REVISION`.
The native and renderer sources must match for the normal qualification path.

`NATIVE_CATALOGUE_RENDER_VALIDATE_ONLY=1` checks custody without a graphical
display; it is explicitly not a rendering pass. The optional archival-development
flag `NATIVE_CATALOGUE_RENDER_ALLOW_ARCHIVAL=1` allows inspection of earlier native
observations and records both source identities. Such captures do not qualify
new catalogue metadata. The overlay distinguishes authored connector semantics
from actual painted geometry and does not imply mechanical support.
