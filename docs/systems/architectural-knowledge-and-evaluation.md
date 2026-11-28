---
title: Architectural knowledge and native context evaluation
status: Current
document-kind: reference
scope: WORLD-STEER-BATCH-M3-M5-001 Draft design-card retrieval, source authority and geometric evaluation
canonical-for: [architectural-design-retrieval, contextual-native-detail-evaluation]
last-reviewed: 2026-11-24
related-documents: [../operations/world-steer-batch-lab.md, workbench-direct-art-batches.md, workbench-art-providers.md]
---

# Architectural knowledge and native context evaluation

**Draft / HOLD.** This scoped successor supplies compact design knowledge and
independent native geometry diagnostics for the existing Batch Lab. It does not
change native physics, provider transport, model selection or GOLDMAPS records.
The stage host remains the only authority for permissions, footprints, budgets,
protection, native execution and recovery.

## Source authority and design cards

The [frozen card corpus](../../godot/data/batch_lab/architectural_design_cards.v1.json)
derives **25** detailed cards from the existing GOLDMAPS recommendation. Its
source is `techrote/sandmapsreference`, archival commit
`b9535405853a5cd16e4bba968ec7167222861c42`, and scientific/native evidence commit
`40f196f792e4d9e19bbd57fdafd6a90420fadf32`. The definitive
[decision packet](https://github.com/techrote/sandmapsreference/blob/b9535405853a5cd16e4bba968ec7167222861c42/docs/corpus/goldmaps-finalisation-001/FINAL-DECISION-PACKET.md)
and its JSON govern those historical results.

The corpus authority retains the distinct **70 recovered maps**, **67-source
primary schema/policy scan**, **25 Gold recommendations**, **27 current protected
features**, **76 feature states**, **12 comparative families**, **five negative
interventions**, eight intervention decisions and **zero owner-accepted maps**.
The compact cards do not copy source artwork or native Setup geometry. They carry
exact source commit, Setup SHA-256 and Git blob, material-plane SHA-256 and source
links. The full frozen corpus remains in its own repository.

Every card separates:

- **Observed geometry:** imported exact-source material counts, extent, empty
  fraction and source-static replay status. These are not a new native run.
- **Cited interpretation:** macro form, support relationships, entered spaces,
  traversal intentions, density, motifs and preservation reasoning from existing
  reviews and source-authored metadata. A proposed structural role is explicitly
  interpreted; it is not an inferred native socket or stress measurement.
- **Construction strategy:** a short authored sequence using the M3 vocabulary,
  with protected voids, support interfaces and service access established before
  bounded detail.
- **Qualification:** schema, original native policy, exact-source hosted headless
  result, graphical scope and owner acceptance recorded separately.

The final hosted Windows receipt overlay marks the **original #155 refused**.
Its separately qualified policy descendant does not replace the source identity.
Original #183 remains in the refusal ledger although it is outside the Gold25
card set. Headless qualification is never relabelled as graphical or physical
owner acceptance. Reference crop windows remain evidence windows, never edit
masks. Exact matching feature-state identities are retained where available;
absence of a measured feature box stays unknown.

The [derivation tool](../../tools/batch_lab/build_architectural_knowledge.py)
requires the exact archival checkout, verifies the corpus lock, checks the Gold
roster and source identities, and overlays per-source native receipts. It has no
network or inference function:

```sh
python tools/batch_lab/build_architectural_knowledge.py --reference-root PATH_TO_FROZEN_REFERENCE --check
```

## Retrieval and module compatibility

[`architectural_retrieval.gd`](../../godot/scripts/batch_lab/architectural_retrieval.gd)
provides `load_default_corpus()` and `retrieve(query, module_catalog, corpus)`.
Default loading verifies the frozen file SHA-256. Returned data also identifies
its actual canonical JSON content, so a caller-supplied corpus cannot borrow the
frozen file identity. Each context pack carries reference-only authority and the
source evidence commit. It grants no World write permission.

Queries accept text plus structural parts, architectural families, topology,
connection intent, material roles, observed palette material IDs, visual
character, scale and minimum observed negative-space fraction. The available
region constrains candidate **modules**, not the size of an inspirational map.
The deterministic ranker uses declared facet overlap plus bounded lexical
matching; it performs no embeddings, remote calls or model inference. Each result
explains matched facets and their authority. At most five cards are returned,
with three by default, and the compact context is bounded to 12,000 characters.
Duplicate source geometry and repeated ancestry groups cannot occupy extra seats.

Host-provided library summaries carry two distinct results. A module with matching
declared part/roles, size and connection tags but no current native verification
appears in `metadata_only_modules`. Only a current-session exact native-verified
summary with a content digest appears in `compatible_modules`. A standalone JSON
qualification flag is not imported by the module library. Even these matches are
**candidate roles**, not proof that a transformed placement fits, that sockets
mate or that physical support is stable. The native stage compiler must decide
those questions against the actual World.

No GOLDMAPS card automatically becomes a reusable module. Native module geometry
must first be harvested or replayed and admitted through the M3 pathway. The
existing provider lifecycle remains behind the staged planner adapter; retrieval
can run entirely offline with typed plans.

## Family-excluded retrieval qualification

The [frozen retrieval cases](../../godot/data/batch_lab/architectural_retrieval_evaluation.v1.json)
were committed with ranking source before their first execution. Three
architectural families (`bioindustrial`, `civic`, `vessel_dock`) are excluded from
retrieval candidates for all registered tests. Three development cases and six
transfer briefs ask for structural analogies from the remaining families. The
transfer briefs specify new construction constraints rather than using source
map names. Relevance sets are explicit and preserved.

The initial executed source returned a predeclared relevant structural analogy
at rank one for all three development and six family-excluded cases. This is a
small deterministic contract result. The curator had access to every card;
family-excluded indexing is **not** unfamiliarity to the annotator, a blind human
study, a learned generalization result or proof of aesthetic quality. No ranking
weights or relevance labels were changed after this result. Source-bound JSON
results are emitted by the qualification harness, separate from this contract.

```sh
godot --headless --path godot --script res://tests/test_architectural_retrieval.gd -- --output=ABSOLUTE_RESULTS_JSON
```

## Contextual detail diagnostics

The original Batch Lab random greeble controls passed its simple structural
proxies. The [independent architectural reducer](../../tools/batch_lab/evaluate_architecture.py)
therefore measures explicit relations to a declared context instead of treating
painted-cell count as quality.

A matched case supplies actual before/after native uint16 material planes, raw
native acknowledgements, exact source/runtime identities, compiled recipe digest
and predeclared context. Before calculating diagnostics, the reducer reuses the
existing Batch Lab custody checks: full plane lengths and hashes, completed
`CyberNativeCellWorld` acknowledgements, bounded counter identities and observed
changes no greater than acknowledged writes. Queued or visual-only results are
unevaluable. Failed, partial, stopped, duplicate and missing cases remain visible.

Context contains disjoint structural/detail material IDs, allowed attachment
regions, required clear regions, local detail-density envelopes, protection and
an optional square-clearance route. The reducer independently calculates:

- Detail components touching an actual structural host by a shared cell face.
- Detail components touching an actual host within the declared anchor regions.
  An empty rectangle named “anchor” supplies no supporting material.
- Detached and unanchored detail cells, and detail outside declared zones.
- Local density against the explicit envelope; dense anchor painting cannot
  automatically pass.
- Initial, final and newly introduced corridor intrusions and protected changes.
- Geometric square-clearance connectivity, structural components and empty space.

Empty detail or absent context produces an **unassessed** suitability result,
not a perfect score. Each diagnostic remains separate. Adjacency does not prove
structural strength, functional pipe flow, gravity-aware traversal or aesthetics.
Eighteen adversarial synthetic tests include equal-cell attached/scattered
controls, bogus anchors, wrong faces, overfilling, protected changes, hash/counter
corruption, queued results, partial prefixes and missing registered cases. These
fixture tests are separate from actual native construction evidence.

## Matched native experiment contract

The [native registration](../../godot/data/batch_lab/architecture_experiment_registration.v1.json)
contains three diagnostic families, five offline construction arms and two seeds:
**30 intended attempts**, each with a 256 × 192 native region and 65,536-cell
execution budget. Arms are hand-typed, procedural modules, random-valid,
reference-guided and retrieval-guided. The three grounded references are Nadirspan
#146, Keelbone Covered Spine #159 and Quoin #125. Six larger visual constructions
are separate demonstrations, not additional independent comparative samples.

Same family/seed pairs must retain the same initial plane and context. The
reducer reports realized new detail counts; unequal realized areas prevent an
equal-cell quality interpretation even where proposed budgets match. Hand-typed
and module replay equivalence is expected. Reference/retrieval guidance denotes
offline typed/procedural construction, never a language-model response.

```sh
python tools/batch_lab/evaluate_architecture.py cases.json --registration godot/data/batch_lab/architecture_experiment_registration.v1.json --output analysis.json
python -m unittest discover -s tools/batch_lab -p test_architecture_evaluation.py
```

The native campaign's executed receipts, rendered evidence and source/runtime
identities must be checked in the final decision packet. The existence of the
registration or reducer does not assert that all cases executed. Genuine model
plan quality, independently blinded/human preference and physical owner Windows
acceptance remain separate gates.
