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

## Windows package qualification and owner review

The following review separates the implemented packaging sequence from a result
actually observed in a particular campaign. Use the canonical final decision
packet to identify the completed run, source commit, archive SHA-256 and native
DLL hash. This worksheet cannot supply a missing run result or physical owner
acceptance.

### Required extracted-evaluator sequence

The existing `world-steer-batch-qualification.yml` workflow keeps four jobs:
source/experiment guards, Linux native and graphical qualification, the pinned
Windows cross-build, and Windows graphical execution plus extracted evaluation.
The Windows job performs the following dependent gates:

| Gate | Concrete authority and required observation |
| --- | --- |
| Native custody | Verify the downloaded candidate's source commit/tree and native build inputs before copying the DLL; verify the Rapier hash and official Godot 4.7 archive pin. A successful build alone is not an application qualification. |
| Windows source execution | Run `qualify.py --graphical --regressions --architecture` against the checked-out application. It requires real native modules, fresh-process reopen, stage contracts, six typed constructions, three modular constructions, the 30-case offline comparison, all nine rendered planes and interactive module controls. Existing ordinary Workbench/Art regressions remain in this source run. |
| Committed-source packaging | The accepted packager reads `git archive HEAD`, installs the verified candidate DLL, engine, Rapier, runtime dependencies and notices, and creates `candidate-manifest.json`. It does not package arbitrary working-tree code or editor caches. |
| Architecture evidence attachment | `bundle_architecture_evidence.py` accepts only a clean, passed, graphical Windows report with the same source and native hash. It first verifies every existing package payload hash, then adds bounded `architecture-evidence/` files and their provenance to the package manifest. Imported files still do not gain fresh native authority. |
| Archive and fresh extraction | Compress the complete evaluator, record the outer ZIP SHA-256, and extract it into a new directory under the runner's temporary path. The extracted application is distinct from the source checkout. |
| Extracted execution | Run `qualify.py --package <extracted-directory> --project <extracted-directory>/godot --godot <extracted-console-engine> --graphical --architecture`. Before execution, verify all packaged file hashes, runtime provenance, source/tree/input identities and runtime dependencies. Run the Batch and architecture suites with a separate user-data root; require an unchanged application identity afterward. This package run does not repeat the additional `--regressions` group already required by the source run. |
| Publish qualified candidate | Publish the owner ZIP and checksum only after extracted execution succeeds. Preserve the Windows logs and outcomes even on failure. The package remains Draft/HOLD. |

The archive contains the completed **source Windows** evidence and
`architecture-evidence/source-qualification.json`. The later **extracted
Windows** qualification report is retained in the campaign's
`evidence/extracted-evaluator/` output. These two reports describe different
executions and must not be conflated. Both should identify the same frozen
application source and native bytes; the extracted report must say
`packaged: true` and `graphical: true`.

Hosted Windows graphics use Godot's compatibility renderer with the
`opengl3_angle` driver. The shipped shortcut performs a headless project import,
then launches the packaged GUI engine through `--workbench` using the project's
normal compatibility settings. Qualification exercises that application route
through the console engine; it does not record a physical owner double-click or
certify the owner's default GPU driver. Record those observations separately.

### Concrete owner walkthrough

Use the [owner guide](../../operations/world-steer-architecture.md) for the full
controls. Start in a writable extracted directory and keep the complete package
together. The following checks use the offline authoring path and require no
model credentials. Record a pass, refusal, failure or untested result for each
row; a refusal can be the correct result for a deliberately invalid proposal.

| Review step | Owner action and evidence to retain |
| --- | --- |
| Confirm the candidate | Compare the ZIP SHA-256 with the published checksum. Record `candidate-manifest.json` source commit, native DLL hash, Godot version, Windows build, GPU and driver. Launch **Open Workbench.cmd**. Record whether import and the actual window open successfully on this machine. |
| Establish a known World | In ordinary Workbench, create a paused **512 × 512** Empty canvas. Open **Architecture…**. Inspect the live canvas and window layout at the intended display scale. Opening the panel should create no construction or provider request. |
| Construct a complete typed example | Select **Assembly hangar**, then **Load example**. Preview the structure stage and inspect its region, projection and exact host cost. The live native canvas should remain unchanged until approval. Approve, wait for **completed**, inspect the receipt/result, then repeat for services and detail. Retain the final session and a screenshot of the actual Workbench view. |
| Exercise real reusable parts | On another blank canvas, use **Build 8 starter parts**. Confirm the live World and existing Batch experiment remain intact. Search for **return pipe**, inspect its source/material identities, and propose repeated mirrored placements inside a declared region. Review the zero-write projection, then approve and inspect the native result. Use the ordinary Undo and Redo controls to verify the geometry reverses and returns. |
| Try a complete module composition | Load **Modular assembly hangar**, **Modular service stack** or **Modular transfer viaduct** after the starter library exists. Inspect the pinned module references and complete its three stages. Judge repetition, connections and useful open space in the actual material geometry. Optional seeded thinning is a separate detail experiment; it does not promise continued structural connectivity. |
| Harvest and roundtrip | Name/tag and harvest a supported region from the actual World, or select a completed non-blinded Batch tile and harvest it. Export its module, then import it in a fresh application session. Its retained provenance should be historical until fresh native observation. An identity placement with no palette or thinning can establish original-module authority only when the full observed crop, including Empty cells, matches exactly. Transformed variants retain their separate stage evidence. |
| Check refusal and revision | Preview a proposal, then make a small ordinary edit inside its inspected region before approving. Approval should refuse the stale source. Repreview or revise deliberately. Also try an out-of-region placement or a protected intersection: preview should refuse without construction. Restore a valid proposal and confirm **Skip** does not satisfy a dependent stage. |
| Check Stop and recovery | Start a sufficiently large proposal and request **Stop / cancel** while it is applying. If it already finished, record completion rather than manufacturing a partial result. Otherwise inspect the acknowledged prefix and partial/cancelled record; pending suffixes must not appear as completed geometry. Use ordinary Undo or a newly inspected recovery stage. Preserve the original stopped/refused record. |
| Retrieve useful context | Enter a concrete architectural intent in **References** and inspect the small returned context pack. Check whether topology, space, connections and module compatibility help the intended construction. Source observations and authored interpretations should remain distinguishable; a Gold recommendation is not owner acceptance or permission to import refused source geometry. |
| Save and reopen | Save the architecture session, modules and the ordinary Workbench **Save start** separately. Exit the application completely. Reopen the authored World and then the session. Inspect actual geometry and module identities. The session should resume no queued work and should require fresh inspection/approval for further construction. Imported historical receipts should remain identifiable. |
| Play and judge the architecture | After saving the authored start, use ordinary Workbench actor/inspection controls, choose the actor and spawn location explicitly, and test the intended routes with Play/Step. Record headroom, access, recovery routes, collisions, visibility and any material behavior that matters. Compare multiple scales and families in true side elevation. Static connected components and rectangular clearance tests do not replace this gameplay observation. |

For visual judgement, record the example, camera/view, stage and any changes
made. Useful questions are whether major supports appear believable, required
connections read clearly, rooms and passages have purpose, detail responds to
its host, and asymmetry remains coherent. The owner's named-example review is
valuable subjective evidence, but it is not a blinded experiment and should not
be reported as one.

For modular examples, **Load example** binds a new proposal to the modules
actually present in the current library. A bundled modular `*-plan.json` instead
pins the original harness's `source-part-library.json`; newly built starters or
the separately harvested `modules/*.module.json` can have the same geometry but
different provenance/content hashes. A mismatch is a correct refusal. Exact
programmatic replay can bind `Library.load_library` to the paired original
library. The shipped UI imports individual module documents and its example
picker supplies the straightforward local replay route; it does not provide a
bulk-library import control. Bundled whole-composition `stages/*-module.json`
(typed examples) and `stages/modular-*.module.json` (modular examples) remain
directly importable as individual modules.

### Acceptance record

Retain a short record with the package/source/runtime identities, device and
driver, completed steps, exact refusals or errors, saved sessions/World starts,
screenshots, chosen actor and tested routes. Keep at least these conclusions
separate:

- **Hosted qualification:** the named source Windows and extracted Windows
  reports passed or failed their required gates.
- **Physical interaction:** the owner actually launched and operated this
  package on the recorded machine and driver, with observed limitations.
- **Architectural preference:** the owner accepts, requests revision of, or has
  not reviewed each construction's visual and spatial qualities.
- **Gameplay acceptance:** the specified actor/routes and relevant dynamic
  behavior passed, failed, or remain untested.
- **Model/Art integration:** this remains an offline typed-plan prototype until
  the separately owned Art adapter and an authorized genuine-model campaign are
  completed. A successful manual session does not qualify inference quality.

Owner observations do not automatically merge the implementation, promote the
PR to Ready, alter physical defaults, authorize inference spending or establish
GOLDMAPS acceptance. Record an explicit disposition and unresolved gates in the
canonical decision packet.

### Independent comparison audit

`independent-native-comparison-review.py` is an evidence-only review tool in this
audit directory. It imports no application compiler or production evaluator.
Run it against an extracted `architecture/comparison` directory to independently
reconstruct every before/after plane and original native receipt readback hash,
check the matched realized detail budget and protection, and report declared
anchor contacts. It writes `independent-stage-audit-c.json` beside the original
unchanged evidence:

```text
python docs/audits/2026-11-24-world-steer-m3-m5/independent-native-comparison-review.py <comparison-evidence-directory>
```

Its current thirty-case controls deliberately give the four nonrandom strategies
the same geometry inside each matched block. Native equivalence and contextual
diagnostic separation from random placements are useful engineering results;
they establish no reference/retrieval superiority, aesthetic preference or
language-model optimization.
