---
title: Art native context and typed proposals
status: Current
document-kind: contract
scope: Draft collaborative Art value schema, bounded native context, no-write preview, source policy, knowledge and deterministic fixture evidence
canonical-for: [art-native-context-proposals]
last-reviewed: 2026-11-25
related-documents: [workbench-art-providers.md, workbench-direct-art-batches.md, ../operations/art-workbench-final-evaluation.md]
---

# Art native context and typed proposals

This contract describes the ART-WORKBENCH-COLLABORATIVE-002 successor candidate.
It remains Draft/HOLD. Source behavior and executable contracts below do not
establish physical owner acceptance or genuine model creativity. The mission
ledger owns actual application, platform and package qualification identities.

## Native observation and information boundaries

The ordinary PAINT controller remains the sole consumer of its native capture
receipts. Its Art capture callback supplies a copied completed material plane;
Art does not inspect a mutable World or independently take a PAINT result.
A capture requires an acknowledged paused source and a finite selected rectangle.
Transient body coverage, native failure or a source change can refuse capture.

`art_world_context.gd::build(capture, policy, decisions)` accepts only a
completed `capture` receipt identifying `CyberNativeCellWorld`, with its exact
region, material count, generation, revision, tick and authored-baseline
generation. The observed generation must equal the captured generation.
Rendered pixels cannot stand in for stored material identities.

The result contains a private copied `_capture`, a model-visible `model`, an
`inspector`, source and policy identities, and a context digest. Only `model`
is suitable for provider transmission. Private material arrays are retained
solely for host preview and comparison. The context builder has no network,
credential, filesystem, audit or SceneTree access.

| Value | Bound and interpretation |
| --- | --- |
| Selected capture | At most 262,144 native cells, wholly inside the installed World |
| Model context | At most 24,576 UTF-8 JSON bytes; excess refuses with an explanation |
| Occupancy | A 16 by 16 grid: observed, nonempty and source-policy-eligible counts |
| Exact transmitted samples | At most 32 deterministic spatial-bin-center samples, each with world x/y and native ID |
| Material distribution | Exact histogram of the selected captured region, not the entire World |
| Creative objective | 4,096 characters |
| Style | 128 characters |
| Pinned constraints | At most 16 strings of at most 512 characters |
| Current-session decisions | Last eight admitted string entries, each at most 256 characters |
| Protected regions | At most 32 finite native rectangles |
| Destination palette | Between one and 32 distinct native byte IDs |

Cell samples are stratified across both selected dimensions; short or narrow
regions adapt the grid, and selections of at most 32 cells expose every cell.
The `native_sampling` metadata records the deterministic method and grid shape.
A sample states only its actual captured cell value, without inferring unsampled
identities. Disabling native summaries also omits this sample metadata.

The inspector explains included and omitted information, context bytes, source,
material-plane SHA-256, selected knowledge provenance and the context digest.
It explicitly omits full desktop content, unrelated windows, private files,
credentials, old audits, unselected World regions and automatic cross-session
conversation restoration.

`include_native_summary=false` removes histogram, occupancy and native samples
from the transmitted envelope. The host still needs its private native capture
to validate a proposal. `include_knowledge=false` omits all knowledge cards.
Both choices are visible and included in the policy identity.

The occupancy grid describes stored materials. It makes no assertion about
load-bearing physics, actor intentions, reachable routes, equipment operation
or appearance. The tool-state description is separately supplied by the host;
unprovided state is explicitly unspecified.

## Host policy and creative constraints

The host supplies `extent: Vector2i`, `region: Rect2i`, `protected:
Array[Rect2i]`, `allowed: Array[int]` and `allow_destructive: bool`.
Optional objective, style, complexity, variation and pinned constraints are
copied into the admitted context. Complexity is sparse, balanced or dense;
variation is finite between zero and one.

A model cannot replace those host values. A proposal can narrow its region but
cannot enlarge it. A changed palette, protection or pinned brief requires a
new context. Model-provided host source identities, budgets, receipts, approval
flags, arbitrary executable instructions and unknown fields are refused.

Pinned natural-language intent guides a model but is not a geometric proof.
For enforcement, express passages and important structures as protected
rectangles. A future model may misunderstand prose; the host still checks its
actual raster against the explicit policy.

**The existing Art source policy remains Empty (0) or Hard Wall (58).** Other
stored materials remain protected. Destructive approval allows replacing or
erasing supported occupied source cells; it does not grant authority over Metal,
Glass, actor masks or other protected native materials. A model cannot promise
those changes through ordinary Art. The familiar manual PAINT authority remains
separate.

## Versioned proposal

`art_authoring_proposal.gd::parse_text(text)` accepts one complete JSON object
or one enclosing JSON code fence, with a 131,072-byte UTF-8 bound. It rejects
partial JSON, a bare operation array and arbitrary surrounding prose.
`model_instruction(mode)` describes the same finite schema to a configured
provider.

A minimal proposal is:

```json
{
  "schema": "cybersand-art-proposal-v1",
  "title": "Reviewed structural frame",
  "summary": "A bounded frame with an open interior.",
  "region": [16, 16, 128, 128],
  "assumptions": ["This is material geometry, not operating machinery."],
  "unresolved": [],
  "stages": [
    {
      "id": "frame",
      "title": "Outer frame",
      "depends_on": [],
      "operations": [
        {
          "shape": "outline",
          "x0": 24,
          "y0": 24,
          "x1": 120,
          "y1": 120,
          "width": 3,
          "material": 58
        }
      ]
    }
  ]
}
```

All coordinates are absolute native World integers. Rectangle endpoints are
inclusive. The example is not permission to use those coordinates in another
World; the actual host region and fresh native observation remain decisive.

Supported primitives are the established rectangle, disc, line, pixels,
polyline, polygon and seeded airbrush. Outline expands into at most four
nonoverlapping rectangles, with width 1 through 32. Repeat expands one
primitive item at a finite integer step, with count 1 through 16; nested
repetition is refused. Point primitives admit at most 256 points.

Each proposal has one through eight stages, at most 64 expanded native
primitive operations, at most 262,144 conservative raster candidates per stage
and at most 1,048,576 candidates overall. These are host-computed bounds.
Sparse shapes are charged for candidate traversal, not merely eventual hits.
The model cannot lower an estimate to escape admission.

Stage IDs are unique short identifiers. Dependencies may name distinct earlier
stages only. Unknown, cyclic or forward dependencies refuse. Native modules,
articulated machines and Architecture-specific stages are explicitly unavailable
through this isolated schema; their owning qualified authority is required.

Outstanding `unresolved` questions keep a proposal visible but prevent preview
from becoming execution-ready. An owner clarification must produce a revised
proposal. Assumptions and questions are each bounded to 16 strings of 512
characters.

## Compilation, revision and zero-write preview

`compile(raw, context, policy, previous={})` returns normalized geometry,
finite stages, source/policy/context identities, conservative budgets and an
understandable error or warnings. It does not own a World or invoke a provider.

A revision records its parent proposal digest and identifies added, changed
and removed stage IDs. The model cannot weaken the separate pinned policy.
The host retains previous proposals and must decide whether a new request is
a revision, a separate proposal or a replan after native work.

`art_authoring_preview.gd` uses the existing lazy `art_batch_plan.gd`
raster against a private copied material plane. `configure(compiled,context)`
binds the exact compiled source. Each `poll()` advances at most one ordinary
4,096-cell chunk; the existing raster also yields over sparse misses. Cancel
retires the preview without native mutation.

The preview checks actual emitted points, not only bounding rectangles.
It refuses any requested cell outside scope, in a protected rectangle,
outside the palette, on a source material other than 0/58, or requiring
destruction without permission. A conservative bounding overlap is shown
during compilation; only a real raster conflict causes the final refusal.

A successful preview supplies per-stage requested, predicted changed and
unchanged counts, introduced/removed material counts, and before/after
material-plane hashes. At most 32 conflict samples are displayed, with the
complete conflict count and explicit omitted count. Later stages use the
predicted result of earlier stages, so a later attempt to repaint newly
introduced protected Metal also refuses.

These values are predictions, never native receipts. `zero_native_writes`
describes this preview's authority; it does not claim that another system or
the owner could not change the World while the preview was being prepared.

## Execution remains under native ownership

The collaborative host requires fresh explicit approval and exact native
source validation before a stage. It submits through the existing Art batch
executor, which preserves native chunk ownership, source protection,
acknowledged before/after receipts and the shared PAINT history.

Each stage is a separate operation. There is no multi-stage atomicity,
automatic rollback or indefinite model loop. Manual drawing stays available.
A relevant source change invalidates the pending approval; the owner must
refresh/replan. A skipped stage cannot silently satisfy dependencies or
reuse a later prediction made from its geometry.

Stop retains only the actual acknowledged native prefix. A fresh continuation
must use the current observed World and obtain its own approval. Native
Undo/Redo and authored-start Save/Open remain the existing independent
authorities; saved history is not a cross-session execution approval.

## Bounded knowledge and provenance

`art_knowledge_context.gd` contains four small reviewed cards. They are
selected by explicit brief/style keyword relevance, with at most three cards
and 4,096 bytes of card content. The inspector records matching terms and
omission reasons. There is no automatic network retrieval, repository scan,
audit ingestion or executable example import.

| Source | Immutable authority | Use and limit |
| --- | --- | --- |
| Native Art contract | CyberSand accepted main `00cdb02f103265b6dc5224c68283e9a0c8cb449f`, `docs/systems/workbench-direct-art-batches.md` | Native source, geometry and receipt constraints |
| GOLDMAPS rubric | sandmapsreference `b9535405853a5cd16e4bba968ec7167222861c42`, blob `256b609b1f5c18cfee0f2f5f7b0435c517b52681` | Negative space, structural legibility, preservation and honest evaluation |
| GOLDMAPS prior-reference review | Same commit, blob `3c8e134b52e2bc46f399ee3173f15d9472c8957b` | Apparatus/workspace relationships and distinct structural expression |

The GOLDMAPS cards are source-pinned research interpretations. They do not
claim that any map has owner Gold adoption, that a visual mechanism functions
physically, or that the examples are native construction modules. External
text remains untrusted reference data and grants no execution permission.

## Creative fixtures and evidence claims

`art_creative_examples.gd` supplies nine explicitly deterministic examples:
industrial repair, structural facade, science-fiction interior, revised
arcology, preserved courtyard, palette foundry, interrupted workshop, staged
megaframe and alien vault. They require an admitted region of at least
128 by 128 and at most 262,144 cells and Hard Wall in the palette.
Selecting an example creates values only; application remains reviewed.

`godot/data/art_collaborative_briefs.json` retains 24 distinct owner-style
briefs, including ambiguity, contradiction, revision, Stop and stale-context
cases. Four are labelled held out for a future owner-operated genuine-model
cohort. The deterministic fixture policy knows their mappings; its outcomes
do not establish model generalization.

The pure `test_art_creative_cohort.gd` comparison retains every terminal
outcome and the failed precursor to a repaired proposal. Fixed identical
packets are compared as one stage, finite stages, knowledge-disabled context
and native-summary-disabled context. Identical geometry is a control, not a
causal retrieval or creativity result.

The separate `test_art_collaborative_native.gd` campaign uses the actual
ordinary Workbench, PAINT capture, existing native Art executor, original
chunk receipts, protected-region readback, complete material-plane hashes
and ordinary authored-start Save/reopen. It pairs staged constructions with
matched geometry through the original direct route in separate virgin
regions. Native before/after diagnostics and actual displayed Workbench
screenshots are labelled separately. Timings expose both scenario wall time
(including readback and image artifacts) and per-stage native submission to
terminal time, summed separately. Only the latter has a matching scope in
the direct control. Fixed arm order and differing stage boundaries mean these
are observed fixture costs, not a randomized performance or causal speed claim.

Static Empty rectangles are clearance diagnostics only. Actor traversal,
physical stability, playfeel and subjective usefulness need their own
observations. A successful fixture demonstrates compiler/context/native
behavior and source custody; no genuine model invocation or paid inference
is implied.
