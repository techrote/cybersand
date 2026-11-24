# Art successor integration handoff

**The independently executable construction boundary is implemented.** The existing Architecture panel can load typed plans, inspect the actual Workbench World, retrieve compact references, compile a zero-write preview, accept an owner decision and execute through the accepted native Art executor and ordinary authoring history. The remaining Art successor work is a thin mapping between its conversation/request lifecycle and this session API.

This handoff describes the implemented interfaces in `godot/scripts/batch_lab/architecture_stage_session.gd`, `architecture_stage_plan.gd`, `architecture_stage_panel.gd` and `architectural_retrieval.gd`. The canonical final decision packet supplies the exact integrated source and qualification identities. A method described here is an interface, not evidence that a particular construction or model request has completed.

## Ownership and connection point

| Responsibility | Owner and existing boundary |
| --- | --- |
| Provider reliability, credentials, model selection, request transport and retry | Existing Art provider interfaces and the separate Art Workbench completion mission |
| Conversation UI and shared session logging | Art successor; route bounded architectural proposals into the adapter |
| Current World ownership, installed materials, authoring history | Ordinary Workbench and its native worker |
| Module geometry, transforms, semantic declarations and current native qualification | `native_module.gd` and the host-owned `native_module_library.gd` instance |
| Design references and compact context | `architectural_retrieval.gd`; historical source, interpretation and qualification remain separate |
| Stage validation, preview cost/geometry and construction permissions | `architecture_stage_plan.gd`, supplied with a fresh host inspection |
| Owner decisions, native submission, verified completion and recovery | `architecture_stage_session.gd` |

The existing integration entry is `wb.open_architecture_lab()`. After its panel is ready, `wb.architecture_lab.session` and `.library` provide the host-owned session and module library. The separate Art successor can use that instance or construct a `Session` node with the same `wb` and `library` bindings. A single live session is the preferred coordination point for one authoring workflow.

The session uses `wb._ensure_art_batches().executor` for native writes. The accepted executor, native ownership checks, provider namespace and ordinary PAINT/Undo path remain the execution authority. Opening Architecture and using offline typed plans do not dispatch provider inference or create conversation turns. Native tests cover that isolation. Provider settings, conversation state and transport behavior remain with the Art owner.

## Planner request and proposal mapping

The Art successor should attach its own request identity to a bounded architectural planning request. That identity belongs to the conversation layer; it is not a native receipt. Keep a mapping from that request to the proposed plan id, stage id and subsequently returned preview hash. No new request transport is required by this interface.

A useful planning input contains the owner's intent, a host-inspected region and its source identity, the available native module summaries, a compact retrieved context pack and the permitted stage limits. Inspection uses the existing `wb.capture_batch_source(region)` path. The host chooses the authorized region and supplies actual source geometry; planner estimates of occupancy, permissions, module validity or material counts carry no authority.

Retrieve references with:

```gdscript
const Retriever = preload("res://scripts/batch_lab/architectural_retrieval.gd")
var answer: Dictionary = Retriever.retrieve(query, session.library.summaries())
if answer.ok:
    var context: Dictionary = answer.context_pack
```

The query can contain structural intent, topology, desired parts, scale, available region, material roles, palette, connection intent and family exclusions. The context remains bounded to a few references and exposes omitted references or a no-fit refusal. Module candidates count as freshly native-qualified only when the host library supplies its volatile qualification flag and content identity. Serialized claims supplied by a model or imported file cannot establish that qualification. Required module socket tags and semantic reference connection intent are distinct fields.

The model-facing response schema is the existing finite plan object:

```json
{
  "format": "cybersand-architecture-plan-v1",
  "id": "owner-room-proposal-1",
  "intent": "A small supported industrial floor section",
  "stages": [{
    "id": "floor-section",
    "intent": "Place a bounded floor strip inside the inspected region",
    "region": [16, 16, 64, 64],
    "depends_on": [],
    "modules": [],
    "operations": [{
      "shape": "rectangle", "material": 58,
      "x0": 24, "y0": 56, "x1": 55, "y1": 59
    }],
    "materials": [58],
    "protected": [],
    "clearances": [],
    "connections": [],
    "budget": {"max_checked_cells": 128},
    "expected_effects": "A horizontal floor strip; host preview determines exact changes",
    "uncertainty": ["Static occupancy does not prove physical stability"],
    "refusal_conditions": ["Changed source, unavailable region or protected cells"]
  }]
}
```

This is an offline schema example, not an executed model result. The budget is an upper limit. The host calculates the actual unique final writes, footprint and material effects, including whether the existing source permits replacement. The adapter unwraps a provider response into this typed object and calls `session.load_plan(plan)`. A text response that cannot be parsed and validated remains conversation text or a rejected proposal.

Plan loading and previewing are distinct. A received plan is proposed work. It acquires no native completion status from the provider response, parser success or preview image.

## Executable session calls and events

| Call or event | Implemented meaning and adapter handling |
| --- | --- |
| `load_plan(value)` | Validates a finite typed plan and loads proposed stages. Returns `{ok, reason}`. No World write. |
| `select(index)` | Selects one stage and discards the old preview. Refuses while an action is active. |
| `revise(stage_object)` | Replaces the selected uncompleted stage while preserving its id. Retains the revision decision and requires a new preview. |
| `await preview_selected()` | Inspects current native material geometry, verifies declared dependencies and compiles the selected stage. Success returns `{ok: true, preview}` with `zero_writes: true`; failure returns a reason. |
| `await approve()` | Represents an explicit owner approval action. Rechecks the current source and module/stage identities, then returns success only for admitted queuing. Successful return is **queued**, not completed. |
| `skip()` | Records a proposal decision without native construction. Dependent stages remain blocked until their dependency contract is revised or satisfied. |
| `cancel()` | Cancels inspection/preview or requests a stop of the admitted native stage. A native prefix can already exist; the adapter waits for retirement and retained evidence. Completed geometry remains completed and is changed through ordinary authoring history. |
| `changed` | A UI refresh notification with no payload. Read `busy()`, `stage_state()`, `message`, `preview` and the retained records. This is not a native completion event. |
| `terminal(record)` | A retired native-stage outcome. Inspect `record.status`; only `completed` has the session's full projection/readback agreement. Partial/refused/cancelled outcomes remain explicit evidence. |
| `save_session(path)` / `open_session(path)` | Store or review plan decisions and native evidence. Reopen imports historical claims and requires fresh native inspection and approval. |

The adapter handles synchronous/awaited refusals from `load_plan`, `preview_selected` and `approve` directly. A refused submission never became queued work, so it does not require a subsequent terminal event. A queued stage must retire through the session's terminal outcome; the exceptional shared-executor replacement path is a partial outcome with no implied final readback. The final integrated source must preserve that event invariant.

A minimal integration listener is:

```gdscript
session.changed.connect(refresh_architectural_status)
session.terminal.connect(on_architectural_native_terminal)

func on_architectural_native_terminal(record: Dictionary) -> void:
    # Forward a copied summary through the existing Art lifecycle.
    # The original detailed evidence remains in the architecture session.
    var outcome: Dictionary = record.duplicate(true)
    if outcome.status == "completed":
        show_verified_native_result(outcome)
    else:
        show_native_recovery_decision(outcome)
```

The two `show_*` functions above are the Art successor's UI callbacks, not new methods supplied by this patch. Connect listeners before submitting work and correlate the existing Art request with `stage_id`, `preview_sha256` and the final receipt/result hashes. Avoid treating every `changed` emission as a new conversation turn. The existing Art owner determines log placement and transport cancellation behavior.

The owner actions remain separate from model output: a model can propose or revise a stage, while the existing review controls supply Approve, Revise, Skip or Cancel. A previous approval does not authorize an automatically changed stage or source snapshot.

## Host authority and result evidence

A plan has at most 32 stages, and the encoded plan input is bounded to 2 MiB. A stage region is at most 512 × 512 cells, with at most 64 selected modules and 2,048 drawing operations. The stage's native checked-cell ceiling is at most 262,144. The compiler independently bounds raster scanning, including rejected sparse-shape samples, to 1,048,576 candidates. Module and clearance processing also has host-side bounds. These are current implementation limits, not model promises.

The compiler resolves actual module bytes and legal transforms, computes final native material assignments, checks footprint and region containment, enforces stage/host/module protection and required empty clearances, checks supported connection contracts and calculates native resource use. Actual execution permissions follow the accepted native Art source rule: changing occupied source material outside its allowed Empty/Hard wall replacement domain is refused. Arbitrary palette ids or a model's declaration of compatibility cannot expand that permission.

The preview contains a stage hash, source material hash, World generation, resolved module content hashes, host-calculated budget, actual footprint, exact static material projection and a preview identity. Its projected plane is a compilation result. It is neither native construction nor a speculative physics simulation.

Immediately before submission the session reinspects the source, validates dependency evidence and checks source generation/hash, stage identity and module identities. It then submits normalized native operations through the existing executor. Ordinary editing or a replaced World invalidates a stale proposal. Native receipts and final authoritative readback, not queued operations, determine completion.

A completed record retains the stage, preview/source/projected identities, native receipts and their hash, actual checked/changed counts, elapsed time and final native material readback. It is scoped to paused material identities. The result does not establish stability, actor access or functional service behavior. A stopped or failed stage retains its acknowledged native prefix and available readback; a later plan begins from a fresh inspection of that actual state. Ordinary Undo/Redo remains available.

Session evidence and authored World geometry have separate persistence paths. `save_session` records decisions/evidence; ordinary Workbench **Save start** retains the constructed geometry. Reopening a session does not resume a queue or claim that saved native receipts describe the current World. Imported module metadata similarly remains distinct from a fresh native replay observation.

## Completion gates for the Art owner and owner review

The Art successor's remaining integration work is to route validated typed proposals into the host session, show its current native inspection and compact references, connect the existing owner decision controls, correlate request and stage identities, and present verified terminal outcomes or recovery choices through its existing conversation lifecycle. Provider reliability, model selection, credential isolation, request logging and transport failures stay within that mission's existing interfaces.

A model-assisted evaluation requires an actually available, authorized endpoint, retained model/request identity, frozen source/corpus/seeds/budgets and real native execution of its returned plans. This mission's comparative manifest records zero model calls. Offline typed/reference/retrieval controls cannot qualify language-model inference or prompt quality. Training, paid inference and frozen training split changes have not been authorized.

Final source-bound hosted Linux, Windows and extracted Windows evaluator results belong in the canonical decision packet. They are separate from physical owner acceptance. Owner review still covers installed interactive use, visual architectural preference and actual gameplay. The independent specialist reviews are technical and architectural reviews with knowledge of the implementations; they are not a blinded human preference study.

GOLDMAPS recommendations remain recommendations. Source artwork, native geometry, schema/policy admission, graphical qualification and owner acceptance retain their original identities. A reference card, including one for an originally refused native map, can inform an authored strategy without admitting its artwork as a native module.

Future powerful planners or compact detail workers can produce the same bounded typed stages. Each delegated result still passes through host inspection, compilation, owner decision and exact native receipts. Model training or a new hierarchical solver is not required to use the implemented independent authoring pathway.
