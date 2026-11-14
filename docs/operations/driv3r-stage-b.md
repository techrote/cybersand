---
title: S1-2B-DRIV3R Stage B frozen decision-control evaluation
status: Current
document-kind: guide
scope: Owner-authorized opt-in Stage B experiments and conditional bounded Stage C; actual results require original source-qualified execution evidence
canonical-for: [driv3r-stage-b, driv3r-observation-compaction, driv3r-vector-modulation, driv3r-usefulness-gate]
last-reviewed: 2026-11-14
related-documents: [driv3r-stage-a.md, agent-painter-foundation.md, ../systems/workbench-direct-art-batches.md, current-and-historical-validation.md, ../reference/status-and-roadmap.md]
---

# S1-2B-DRIV3R Stage B

**Owner-authorized continuation, Draft/HOLD.** The Owner requested Stage B after
the qualified Stage A checkpoint, including a two-decision direction/distance
and path-modulation fixture. The same
[Draft PR #580](https://github.com/techrote/cybersand/pull/580) and independent
branch retain ownership. The accepted Stage A source is
`ee95f547f31fb1ac9cdd34536bf36dffe7af1d0c`; its original
[qualification run](https://github.com/techrote/cybersand/actions/runs/43537377045)
and [issue handoff](https://github.com/techrote/cybersand/issues/570#issuecomment-6869269541)
remain a frozen historical checkpoint. New source does not inherit those
execution passes merely by descending from that commit.

The Owner conditionally authorized modest Pipework, Architecture and Greebles
experiments plus graphical Workbench inspection if Stage B establishes useful
behavior. This guide defines the predeclared decision rule; an actual execution
report must say whether it passed. Training, scheduled workers, production
defaults, Ready promotion, merge and closing #570 remain outside the authority.
The four #568 painter branches and shared workflows remain separately owned.

## Frozen experiment and development separation

[protocol.json](../../experiments/driv3r/stage_b/protocol.json) owns the cohort,
budgets, seeds, comparisons and conditional expansion criterion. The dedicated
qualification request binds the exact protocol and all three scenario catalogs
by SHA-256. Those bytes must be committed before held-out model evaluation.
Development debugging can repair implementation defects; it cannot silently
change a held-out task, successful-action definition or poor model choice.

| Family | Development / held out | Actual native task and ordinary-code controls |
|---|---|---|
| Direct | 2 / 4 | Cardinal painted paths through a corner, offset recovery, blocked preferred move and already-complete target. Compare d1 with a local geometric search and three seeded random-legal controllers. |
| Fuzzy | 2 / 4 | Choose between legal Art programs with different connectivity, support, coverage and spill outcomes. Compare fixed-first-tool and three seeded random-legal controllers. |
| Vector modulation | 1 / 3 | First choose a cardinal direction and distance; then choose a finite path algorithm. Compare nearest-endpoint/straight, a geometry-aware coverage-and-cost selector, and three seeded random controllers. |

The three fixed held-out random seeds are recorded in the protocol. All random
comparisons include STOP; fuzzy sampling also includes SKIP. Candidate IDs are
sorted before random sampling so reversing presentation does not change the
seeded draw. They are explicitly non-model records, not model confidence.
Every primary and baseline episode executes through the actual native World
and is replayed from its original acknowledged actions.

The strong direct baseline reads the same local crop, target, history, task
constraints and candidate metrics as d1. It does not read the hidden fixture
catalog or retrospective shortest-path evaluator. Its bounded local search is
separate from the model policy and cannot repair a model choice. The vector
geometry-aware selector also reads only visible candidate metrics and preferences.
Beating a straight path on a coverage task does not establish an advantage over
that stronger selector.

## Task success comes from geometry

[direct.py](../../experiments/driv3r/stage_b/direct.py) requires a recorded policy
STOP at the target, within the case's movement, clearance and retrace bounds.
The direct provider intentionally never auto-completes at the target. Therefore
the generic controller's `task_complete` flag is false even for a successful
Stage B direct episode: use the separate `score.task_success` result. Native
materials must match the acknowledged cursor path, and protected cells must
remain unchanged.

[fuzzy.py](../../experiments/driv3r/stage_b/fuzzy.py) measures required-region
coverage, newly painted-cell precision, four-neighbor connections and continuous
support columns from original before/after material arrays. Full task success
also requires zero spill and consistent receipt/fixture identity. A completed
one-node graph after SKIP can score zero. Legitimate repainting of an anchor is
reported as overdraw rather than an invented new cell. The original shared
compiler expands host-authored programs; the model only selects neutral tool IDs.

All offered tool programs are legal, but their geometric usefulness differs.
Objectives expose the relevant target geometry beyond the local 9×9 crop.
Evaluation masks and expected winning IDs are kept out of model-visible effects.
Host-derived distances, planned footprints and coverage metrics are deliberately
available where specified; success on those choices is not evidence that d1
inferred geometry without host assistance.

## Direction, distance and path modulation

[vector.py](../../experiments/driv3r/stage_b/vector.py) uses the same controller
and authority contract for two genuinely sequential named decisions:

1. Choose from finite `INTENT_<DIRECTION>_<DISTANCE>` candidates. This is an
   explicit no-paint graph transition and does not move the host cursor.
2. From the new graph state containing that selected intent, choose a legal
   host-generated modulation. The native Art pixels operation paints its unique
   footprint. Only a consistent native acknowledgement advances the cursor.

The second decision uses the first selected intent; these are separate calls,
not two questions in one call whose answers are assumed to feed each other.
An incorrect but legal intent stays incorrect. Modulation preserves its endpoint
exactly instead of redirecting it toward the requested target.

| Host algorithm | Meaning |
|---|---|
| STRAIGHT | Cardinal path with minimum travelled length. |
| BOUNDED_SERPENTINE | Alternating finite U excursions with transverse radius at most two cells. |
| HILBERT_MOTIF | Stitched order-one Hilbert U motifs, explicitly a finite motif rather than a full space-filling Hilbert curve. |
| SEEDED_BRIDGE | Deterministic SHA-256-seeded transverse jitter returning to the chosen endpoint. |

The frozen lengths are six or ten cells. Paths contain at most 30 travelled
edges and 31 points, never exceed three times the selected direct distance and
stay cardinally contiguous. Exact displacement, target endpoint error, travelled
length, unique cells, region coverage and retraces are separate measurements.
The starting cell is part of the mask; all ordered path points, including any
revisits, remain in the original candidate record. Duplicate paint visits are
removed from the emitted mask, but not from the travel audit.

This fixture executes a bounded path-mask authoring tool. It does not claim a
physical vehicle moved continuously through a simulation. Actual native material
coverage and receipts qualify painting; path invariants qualify the host geometry.

## Information-preserving compaction and separate ablation

[representation.py](../../experiments/driv3r/stage_b/representation.py) first
separates opaque audit identifiers from decision semantics. Full original World
identity, source hashes, operations, compiler/program hashes, observations and
candidate arrays stay in the journal and remain bound to the decision. They are
not discarded from the experiment or used as model-controlled authority.

The canonical and compact prompts encode the **same semantic view**: objective,
subgoal, cursor, target, local materials, permissions, geometry, history, budgets,
previous action/cell acknowledgement and non-provenance candidate effects.
Compaction uses shared-key tables, run-length material arrays and cardinal path
start/move sequences. A decoder must reconstruct the exact semantic object,
including every path point, turn, revisit and numeric value. No geometry or
coordinate precision is sacrificed to reduce the measured token count.

Audit separation is not represented as a byte-for-byte lossless compression of
the whole episode. The development probes also execute the original Stage A
request representation, making that separate cost visible. Canonical versus
compact comparisons isolate reversible encoding on the same semantic input.

The `without-host-metrics` ablation is restricted to direct cases. It removes
the observation geometry and computed candidate clearance, target distance,
offset error, retrace and changed-cell metrics. It retains the raw material crop,
coordinates, target, history and task requirements. It is explicitly an
information ablation, not a compression result. Fuzzy/vector labels can contain
geometry summaries and are excluded from this particular ablation.

## Paired order, paraphrase and cost studies

[qualify.py](../../experiments/driv3r/stage_b/qualify.py) takes exact observations
and candidate objects from original native model episodes. It preserves the
first decision of each case and both vector phases when available. The paired
probes perform fresh resident inference without applying alternative choices.

Order reversal changes only candidate array and named-criteria insertion order.
The paraphrase changes only the objective to the case's precommitted equivalent.
Canonical/compact call order alternates by fixed state index; both use identical
audited state, budgets and geometry. The first-use episode cost remains separate
from these paired warm costs. Every original question, raw typed response,
distribution, confidence, entropy, probability margin, choice change, total
variation, input-token count, latency and failure is retained.

Probe agreement is not the same as episode success. A counterfactual choice that
was never applied must not be called native painting. Distributions and small
case counts are reported without a generalization or statistical-significance
claim. A matching geometric baseline at greater cost is not incremental direct
policy value.

## Runtime, native admission and bounds

Weights, license and runtime pins remain those of the
[Stage A backend](driv3r-stage-a.md#resident-d1-backend-and-question-semantics).
Stage B explicitly uses two CPU threads, context4096 and physical batch4096.
Tokenizer-only preflight found canonical vector comparison inputs above the
old physical batch2048 limit; this runtime resource change is recorded separately
from compaction and from model identity. No reference or Q4 inference is implied.

The native harness loads only the three hashed, source-owned fixture catalogs.
It validates finite edits, bounds and material IDs before Workbench admission.
The model cannot supply a new fixture or coordinates. Catalog hashes are retained
in native runtime custody and checked with harness/runtime bytes before each RPC.
The actual World, fixed 96×96 focus, material58, protected material, fixed guard,
native freshness, Stop and cancellation authority remain unchanged.

Host rectangle/pixels validation and replay share the same bounded existing Art
operation footprint. Candidate-visit budgets count duplicates; changed-cell
budgets count actual native changes. Full-World receipt reconstruction remains
independent of the model and the path interpretation.

The campaign permits at most 144 main resident decisions, 64 native action slots
per episode, and the stricter case limits in the protocol. Native sessions rotate
by split/family/policy, retaining their existing 256-RPC and 30-minute limits.
The 5,400-second campaign alarm includes inference, native execution, replay and
safety checks; shutdown has its existing separate bounded cleanup. Destructive
timeout/cancellation controls use separately identified inference instances,
outside the 144 main-study requests, so retirement cannot contaminate the primary
resident process.

## Explicit qualification and conditional continuation

The [Stage B workflow](../../.github/workflows/driv3r-stage-b.yml) enters heavy
work only through manual dispatch or a deliberate change to its exact committed
[qualification request](../../experiments/driv3r/stage_b/qualification-request.json).
Push admission requires the dedicated branch and exactly the next sequence.
Ordinary PR updates retain cheap offline tests and do not acquire model weights.
The shared #568 workflows and Stage A request sequence are unchanged.

The [bootstrap](../../experiments/driv3r/ci_stage_b.sh) rebuilds native source
with the pinned Godot/C++/Rapier dependencies, acquires the official pinned Q8
runtime, and invokes the frozen study. The separate
[provenance helper](../../experiments/driv3r/stage_b/provenance.py) binds source,
protocol, catalogs, raw outcomes and immutable archive bytes. Failed or partial
execution is packaged without becoming a successful publication. A completed,
safe study can publish a research artifact even when behavioral usefulness is
HOLD; publication itself never proves task quality.

The predeclared Stage C rule requires clean custody, safety, replay and cleanup.
At least one family must reach its task threshold (direct3/4, fuzzy3/4 or
vector2/3), exceed the pooled three-seed random success fraction, and retain at
least75% of primary choices under both order and paraphrase probes. At least one
pair of each kind must exist. Passing this exploratory rule authorizes at most
two new fixtures in each of Pipework, Architecture and Greebles, at most three
model actions per fixture, native replay and graphical Workbench inspection.
Actual results determine which mode is useful and where its limits lie.

The shared backend, native executor, custody and runner remain under one
integration owner. Scenario providers and independent read-only evaluation can
proceed in parallel through the explicit contracts. No schedules are created by
this architecture. Keep #570 open and PR #580 Draft/HOLD at the next checkpoint.

## Documentation and evidence ownership

| Obligation | Canonical location |
|---|---|
| Stage A checkpoint, backend and authority contracts | Existing Stage A guide and immutable run; no historical evidence rewritten. |
| Stage B protocol, vector semantics, compaction and gate | This guide, with executable bounds and exact case data in the linked sources. |
| Current navigation and retrieval | Documentation index, roadmap, handover, corpus/index and additive Stage B questions. |
| Real results, failures, resource costs and gate verdict | Source-qualified `execution/summary.json`, original archive, Draft PR and #570 ledger. Source text alone is not acceptance evidence. |
| Production authoring and material laws | Existing shared guides; no changes to production defaults or shared painter ownership. |
