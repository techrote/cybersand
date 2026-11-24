# Retrieval contexts for independent answer review

Source-backed expected facts and the complete top-five contexts follow. A canonical route hit alone is not an answer pass.

## OI01: What does the owner want CyberSand and Workbench to become?

Canonical rank: None

Expected facts:

- Paint-and-play authoring system with accessible controls; integrate useful capabilities through Workbench.

### Rank 1: operations/workbench-water-lab.md — Workbench Water Lab

Document: Workbench Water Lab — consolidated controls
Path: operations/workbench-water-lab.md
authority: current-documentation
document-kind: guide
status: Current
scope: Water Lab controls and Waterwall-stack review repairs above PR 631; experimental, merge held
canonical-for: [workbench-water-lab-controls]
last-reviewed: 2026-11-20
Section: Workbench Water Lab
The owner's evaluation found the top Workbench toolbar had become a stack of Water solver, comparison, live status, equipment and apparatus rows. Wave Flow was also absent from the older liquid-policy presets menu, making the correct selection hard to discover. This change consolidates those *existing* controls; it deliberately does **not** add another Water solver or native authority.


### Rank 2: architecture/liquid-solver-family-policy.md — Liquid solver family policy and API specification > Native policy foundation (Current, 2026-10-24)

Document: Liquid solver family policy and API specification
Path: architecture/liquid-solver-family-policy.md
authority: current-documentation
document-kind: design
status: Approved design
scope: Current-main four-family identities, immutable per-World per-material policy, material/variant admission and readback, W-CY material block v2 and IN family block v2; historical design checkpoints and source/platform qualification remain separately scoped
canonical-for: [liquid-solver-family-policy]
last-reviewed: 2026-11-03
Section: Liquid solver family policy and API specification > Native policy foundation (Current, 2026-10-24)
hosts (deliberate host/oracle difference).** The oracle's `gdscript_fallback` build models a host that can *decode* a request. It accepts a default policy and refuses only non-default assignments as `platform_unsupported`. No such GDScript decoder exists. `CyberMicroScenarioHost.install` therefore refuses **every** explicit request, including the explicit default, as `platform_unsupported` when the native handshake (`build_liquid_policy_world`, `get_liquid_solver_policy`) is missing. Without the handshake it could neither validate nor read back what it applied. Callers that want defaults on such a host pass no request (`null`). The oracle vectors remain the contract for a decoding host; adding a fallback decoder would have to reproduce them first.


### Rank 3: operations/architecture-programme.md — CyberSand architecture experimental programme > K. Baseline, rollback and comparison strategy

Document: CyberSand architecture synthesis and experimental programme
Path: operations/architecture-programme.md
authority: current-documentation
document-kind: design
status: Planned
scope: Evidence gates for Cell representation, liquid state and transport, presentation, and conditional sparse motion; no production architecture selection
canonical-for: [architecture-experimental-programme]
last-reviewed: 2026-10-24
Section: CyberSand architecture experimental programme > K. Baseline, rollback and comparison strategy
Keep intake source and each experiment as recoverable commits/branches, with reference fixtures and full registered input identity. Build candidates separately; never overwrite the only reference executable or the owner's loaded DLL. Preserve the intentional dirty DLL and all unrelated work. Raw outputs stay in the active workspace; `C:/cybersand` remains the functional-deliverables directory. Use fresh-world A/B selection or distinct binaries, not unsafe live state-layout switching. Normalize layout-specific state into semantic records for comparison; epoch-shortening variants intentionally differ in raw bookkeeping but must retain equivalent material behavior. Keep observer-off controls so instrumentation cannot silently become the improvement. Preserve failed and ambiguous runs. If a candidate loses, retain the control and close its experiment with the evidence; do not generate a migration by momentum. Serial, fallback and unavailable Buffered are not interchangeable exact rollback implementations.


### Rank 4: operations/workbench-actor-composition.md — Mixed Actor Workshop owner procedure > Automated qualification apparatus

Document: Mixed Actor Workshop owner procedure
Path: operations/workbench-actor-composition.md
authority: current-documentation
document-kind: guide
status: Current
scope: WB-ACTOR-COMPOSE-001 ordinary Workbench controls, authored example and source-matched qualification procedure
canonical-for: [workbench-actor-composition-owner-procedure]
last-reviewed: 2026-11-20
Section: Mixed Actor Workshop owner procedure > Automated qualification apparatus
Use the repository-pinned Godot/Rapier and matching native extension. The new multi-part response-owner capacity requires rebuilt matching Windows and Linux runtimes; a baseline DLL/SO must not be relabeled as this candidate. Follow [local build and validation](local-build-and-validation.md) and retain source, runtime hashes, exact commands, logs and the platform alongside results. From the repository root, with `GODOT` naming the pinned executable: ```sh "$GODOT" --headless --path godot --script tests/test_workbench_actor_catalog.gd -- --save actor-compose-schema "$GODOT" --headless --path godot --script tests/test_workbench_actor_catalog.gd -- --reopen actor-compose-schema "$GODOT" --headless --path godot --script tests/test_workbench_actor_composition_session.gd "$GODOT" --headless --path godot --script tests/test_workbench_actor_composition_native.gd "$GODOT" --headless --path godot --script tests/test_workbench_actor_equipment_extent.gd CYBERSAND_ACTOR_COMPOSITION_REPORT=/absolute/path/author.json "$GODOT" --headless --path godot --script tests/test_workbench_actor_composition.gd CYBERSAND_ACTOR_COMPOSITION_REOPEN=1 CYBERSAND_ACTOR_COMPOSITION_REPORT=/absolute/path/reopen.json "$GODOT" --headless --path godot --script tests/test_workbench_actor_composition.gd ``` The integration writer uses named start `actor-compose-589-evaluation`; set `CYBERSAND_ACTOR_COMPOSITION_NAME` in both processes to isolate another run. The second invocation is a new process with a fresh native World and physical owner. Its completion marker is `WB_ACTOR_COMPOSE` followed by JSON checks, failures, per-actor movement/support, equipment receipts, native/Rapier progression and elapsed/cost observations. A nonzero exit or any failure means it did not pass. Retain failed logs, not only the final result. For actual framebuffer evidence, remove `--headless` in an available graphical display and set `CYBERSAND_ACTOR_COMPOSITION_CAPTURE` to an absolute output directory. PNGs come from the real application framebuffer after presentation; the capture refuses the headless driver. Captions in the JSON identify human, scripted, policy and passive roles, phase and tick. A software-rendered Linux capture proves the displayed application state, not Windows playfeel or hardware frame pacing. Run the relevant existing Workbench input, canvas, combined-authoring, generated-start, material-baseline, Flatten, PAINT and physical actor/equipment regressions too. The dedicated qualification runner records their outcomes. Catalogue, controller and gameplay results are separate from performance: compare no NPC, one script, heterogeneous scripts, mixed producers and equipment on both small and 2048 × 1024 canvases, retaining actual tick progression, decision cost, frame/publication timing and memory. Do not infer performance from slot limits. Windows graphical execution and owner acceptance remain explicit requirements when the build environment cannot run a Windows desktop. A portable package must contain the source-matched native/Rapier runtimes, pinned Godot, project resources and this example; its launcher must open interactive Shared Workbench.


### Rank 5: operations/workbench-actor-composition.md — Mixed Actor Workshop owner procedure

Document: Mixed Actor Workshop owner procedure
Path: operations/workbench-actor-composition.md
authority: current-documentation
document-kind: guide
status: Current
scope: WB-ACTOR-COMPOSE-001 ordinary Workbench controls, authored example and source-matched qualification procedure
canonical-for: [workbench-actor-composition-owner-procedure]
last-reviewed: 2026-11-20
Section: Mixed Actor Workshop owner procedure
This is the owner workflow for the Draft/HOLD actor-composition candidate linked to [#589](https://github.com/techrote/cybersand/issues/589). It opens the ordinary Shared Workbench. F5, Thunderbowl and Flight Lab are not required. The [system contract](../systems/workbench-actor-composition.md) owns the precise capability, producer, persistence and capacity boundaries.

## OI02: Should saving a settled canvas flatten everything and destroy the session Undo history?

Canonical rank: 1

Expected facts:

- Save desired evolved layout without unexpected live Undo destruction.
- Explicit two-byte material Flatten differs from ordinary Save and a full checkpoint.

### Rank 1: decisions/2026-11-14-owner-authoring-intent.md — Owner authoring and world intent — 14 November 2026 > Save, Flatten and compatibility

Document: Owner authoring and world intent — 14 November 2026
Path: decisions/2026-11-14-owner-authoring-intent.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Direct owner clarification of product intent; implementation, qualification and execution permissions remain separate
canonical-for: [owner-clarifications-2026-11-14]
last-reviewed: 2026-11-14
Section: Owner authoring and world intent — 14 November 2026 > Save, Flatten and compatibility
**Confirmed:** saving should preserve the desired evolved material layout without unexpectedly destroying the session's Undo history. Oil painted in mid-air and allowed to settle should restart in its saved location. Acid used to damage a wall, followed by water and fire cleanup, should not reappear merely because the original construction strokes were replayed. **Confirmed:** explicit Flatten is a material-occupancy snapshot using two bytes per cell, allowing burdensome or blocking construction history to be discarded. It is not a full physical checkpoint. Normal map saves need not always flatten; richer authoring data can remain useful. Neither this clarification nor the word “save” requires persisting the entire session's Undo stack. **Confirmed:** do not promise advanced cross-version compatibility of all old maps. Flatten may provide a fallback that recovers useful material layout in newer versions. Material identity mapping and container/version handling remain engineering details. This is not a guarantee that every old simulation state or every future material ID remains interpretable. Flatten is also distinct from merging the visual/semantic layers of Strata.


### Rank 2: systems/paint-editor-bounded-shapes.md — PAINT-001 — bounded painting editor > Undo and authored-start persistence

Document: PAINT-001 native-backed Workbench painting editor
Path: systems/paint-editor-bounded-shapes.md
authority: current-documentation
document-kind: design
status: Current
scope: Mounted Draft PAINT-001 candidate on the shared Workbench; bounded native painting and reconstructible authored starts, not evolved simulation checkpoints
canonical-for: []
last-reviewed: 2026-11-12
Section: PAINT-001 — bounded painting editor > Undo and authored-start persistence
Only native-confirmed edits enter the shared chronological history. A manual gesture remains one record, including its native chunks. Agent receipts retain the first stored material before a cell changes and its latest stored material afterward. A direct batch or one model drawing submission can span bounded history parts of at most 262,144 cells; one Undo or Redo traverses adjacent retained parts of that submission in order. A human edit between agent chunks closes the preceding agent group and remains a separate history entry. Undo therefore reaches the most recent edit first and cannot skip later human work to reverse an earlier agent drawing. Up to 32 parts and 1,048,576 retained edit cells are kept. If those limits evict an older part of an agent drawing, the surviving entry is labelled **Agent drawing (retained tail)** and the UI reports that the older part is no longer undoable. A no-change agent receipt preserves existing Undo and Redo. A captured part that returns every cell to its original material contributes no history record and removes its redundant authored stamps. Undo/Redo preflights expected stored source IDs and uses PAINT's existing native mutation and acknowledgement path. Both interfaces share the generation, revision and tick fence. Confirmed agent edits recorded through this seam advance the fence instead of invalidating manual history. An outside edit not recorded in this timeline, a simulation tick or World replacement still invalidates unsafe history. Undo is paused construction editing; it does not restore temperature, velocity or evolved physics state. Its trusted human inverse does not expand the agent's ordinary material, source or scope policy. History completion appends a new human canvas result to the agent conversation and a durable `history_result` traffic event. It preserves historical model receipts and does not automatically issue another model request. The existing context-mode rules still govern later requests. Undo/Redo stacks remain session-local; saving persists the resulting authored start, not those stacks. Before native writes, `workbench_paint_editor_history.gd` checks that the complete operation can be reconstructed through existing Setup-v2 or GEN-007 start formats. It coalesces exact material row runs into boxes, preserving Empty. The Workbench-only constructor now admits **32,768** authored rectangles/ stamps (previously 4,096), subject to the unchanged **1 MiB** save envelope and native construction-area checks. Generated-map replay also has a conservative maximum of 64 world areas, capped at 32 million touched cells, validated before save and in the native prepared constructor. Other MicroScenario recipes retain their 4,096-record limit. This source change requires a rebuilt GDExtension before Windows qualification. The editor queries a native capability handshake and retains the


### Rank 3: operations/gen008-flatten-qualification.md — Flatten / Bake History evaluation > Windows owner acceptance

Document: Flatten and Bake History qualification and owner evaluation
Path: operations/gen008-flatten-qualification.md
authority: current-documentation
document-kind: runbook
status: Current
scope: GEN-008-FLAT-001 native material-baseline qualification, source-bound Windows evaluation and separate owner graphical acceptance
canonical-for: [flatten-baseline-qualification]
last-reviewed: 2026-11-13
Section: Flatten / Bake History evaluation > Windows owner acceptance
Download the source-matched evaluation ZIP identified in the dated record or PR. Verify its SHA-256, extract the complete archive into a new writable folder with a short path, and run **Open Workbench.cmd**. Keep the included source, dependencies and qualification records together. The full package also includes the accepted Materials Lab authoring tools; its separate launcher remains available. 1. Open **New from generator…**, select a real profile and install a map. Paint several materials, erase some cells, and alternate a few manual and agent edits. 2. Run simulation long enough to move or transform material. Move an actor or let it fall, then click **Flatten / Bake History…** and confirm. Observe that the live simulation continues, actors retain their motion and no tick-zero restart occurs. The previous Undo history should now be empty. 3. Pause. Paint a distinctive new mark and erase part of the flattened map. Add a small agent mark. Undo and Redo the subsequent operations in chronological order. 4. Explicitly **Save named start** under a new name. Completely exit Godot. 5. Launch again and Load that name. The flattened material layout and subsequent acknowledged edits should return without regenerating the former profile. Actor spawns/settings reconstruct normally; transient physics from the earlier process is not expected to resume. 6. Continue painting and agent authoring, Undo/Redo those new edits, and try Restore start. Confirm ordinary input, Fill, Copy/Paste, generator preview and Materials Lab remain usable. 7. Start a longer drawing operation, attempt Flatten while it is pending, then Stop/wait for acknowledgement and retry. The refusal must explain why; no old history or existing save may disappear during a refused/cancelled preparation. Report the evaluation source SHA, ZIP SHA-256, saved name and exact steps for any failure. Automated graphical frames do not substitute for this owner interaction.


### Rank 4: architecture/shared-workbench-authoring-data.md — Shared workbench authoring data and convergence > Flatten and storage compatibility > Native readback, edit fencing and failure atomicity

Document: Shared workbench authoring data and convergence
Path: architecture/shared-workbench-authoring-data.md
authority: current-documentation
document-kind: contract
status: Current
scope: Shared authored baseline, acknowledged edits, material-only Flatten, standalone persistence and live-session separation
canonical-for: [shared-workbench-authoring-data, workbench-convergence-plan]
last-reviewed: 2026-11-20
Section: Shared workbench authoring data and convergence > Flatten and storage compatibility > Native readback, edit fencing and failure atomicity
`CyberDemoBridge.capture_material_baseline` returns privately allocated, complete LE16 bytes, extent, SHA-256 and source generation/revision/tick. It is invoked only by `CyberSimulationWorker._consume_material_capture`, outside a native tick, and reads `World::stored_material` without mutating the World. No pointer to live cell storage crosses the boundary. A single finite copy and value handoff replace per-cell cross-language reads. `validate_material_baseline` checks complete length and the real native catalogue before any narrowing. Staging explicitly detaches the PackedByteArray so an old readback cannot alter the retained authored plane. The request refuses queued/executing PAINT, agent chunks, legacy brush commands, unconsumed receipts and prepared replacements. A native queue admission is not an acknowledged edit. While capture/staging owns its slot, new construction edits are refused; ordinary simulation is not paused. The request carries worker/session World generation, owner request revision, authoring generation and a **15-second bounded deadline**. UI polling and Cancel never wait for a thread join. A cancelled in-flight copy can finish on the existing owner, but its retired token cannot publish a new baseline. A failed capture, allocation, validation, stale token or owner fault retains the old authored baseline/history and existing saved files. Once the whole baseline is staged, `material_capture_finish(token,true)` checks the lease again and advances the authoring generation and editor epochs. Main then swaps authoring references in the same callback, without yield or a native write. The independent authoring generation is necessary because paused Flatten does not change native World generation/revision/tick. Old PAINT requests are refused even if those native values still match. Legacy requests without the new field are admitted only in initial authoring generation one. Old provider replies, agent chunks and deferred turns are retired on successful adoption. Failure does not retire unrelated history or cancel a pending model request. No Undo Flatten, previous-World rollback or special simulated-world capture mode exists. Ordinary subsequent Undo/Redo and explicit Restore retain their existing bounded semantics. Process death before explicit Save cannot change an existing named file.


### Rank 5: architecture/shared-workbench-authoring-data.md — Shared workbench authoring data and convergence > Flatten and storage compatibility

Document: Shared workbench authoring data and convergence
Path: architecture/shared-workbench-authoring-data.md
authority: current-documentation
document-kind: contract
status: Current
scope: Shared authored baseline, acknowledged edits, material-only Flatten, standalone persistence and live-session separation
canonical-for: [shared-workbench-authoring-data, workbench-convergence-plan]
last-reviewed: 2026-11-20
Section: Shared workbench authoring data and convergence > Flatten and storage compatibility
**Current on the GEN-008 implementation branch; approved 11 November 2026:** Flatten copies the complete current native **stored material IDs**, including Empty and identities produced by material motion or reactions. It captures at a completed tick boundary on the existing exclusive worker. It does not read RG8, palette colours, fractional Water dithering, body masks or ballistic presentation. The captured plane becomes the new authored baseline and earlier construction, procedural reconstruction and manual/agent Undo/Redo history are discarded. Subsequent supported edits use the same chronological history relative to it. **The installed live World is unchanged.** There is no prepared-World call during Flatten, no tick restart, cell-state initialization, actor respawn, Rapier rebuild, velocity reset or change to simulation options/material laws. Simulation resumes its ordinary owner loop after copying and may advance while the UI validates the snapshot. Such later simulation changes are deliberately outside the captured baseline. Actors retain live positions and velocities; their existing authored spawns/configuration remain the normal Save/Load reconstruction inputs. Flatten does not Save. Explicit **Save start** writes the standalone baseline, supported acknowledged post-Flatten edits and unchanged Setup-v2 actor/configuration metadata. **Load start** and **Restore start** construct a normal fresh World from that data through the existing prepared native/Rapier transaction. Full saved material identity is checked before publication. Old generator recipes, source files and pre-Flatten painting instructions are unnecessary. Temperature, velocity, fractional fluid quantity, airborne parcels, tick and other transient physical state are not persisted by this material-only format.

## OI03: Must physical simulation be scientifically consistent even when authored effects feel better?

Canonical rank: 1

Expected facts:

- Convincing over consistent; authored alternatives welcome.
- Correctness checks and failed evidence retain scoped meanings.

### Rank 1: decisions/2026-11-14-owner-authoring-intent.md — Owner authoring and world intent — 14 November 2026 > Physical character and destructible structures

Document: Owner authoring and world intent — 14 November 2026
Path: decisions/2026-11-14-owner-authoring-intent.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Direct owner clarification of product intent; implementation, qualification and execution permissions remain separate
canonical-for: [owner-clarifications-2026-11-14]
last-reviewed: 2026-11-14
Section: Owner authoring and world intent — 14 November 2026 > Physical character and destructible structures
**Confirmed principle:** “convincing>consistent.” Deliberately authored effects, approximations and selectable behaviours are desirable for appearance, art, feel, feasibility, significant performance savings and interesting possibilities. The owner does not regard scientific parameter sweeps as the primary way to judge feel at this stage. Representative scenes and continued owner evaluation matter. This does not retroactively make a failed experiment pass. **Confirmed outcome:** cutting or blasting coherent pieces loose so that they move, roll or topple is valuable. Full building structural-integrity analysis is not a prerequisite; deliberately rigged collapses can be useful. **Exploratory owner suggestion:** “prepare then declare,” using authored chunk sizes and break conditions for predictable detachment. This is a promising mechanism to investigate, not a selected algorithm. A fracture piece need not equal a storage chunk. Native ownership/ACK preparation is a separate concern. **Engineering interpretation, not a new owner dictate:** correctness and targeted performance checks remain useful for data loss, ownership and specific technical claims. Historical scientific campaign thresholds should not silently become universal product-feel requirements.


### Rank 2: operations/water-hybrid-pressure-extension-programme.md — Water hybrid, saturated-head and compartment-pressure extension programme > Relationship to #49 and #45 > #45 is no longer treated as an inevitable pressure implementation

Document: Water hybrid, saturated-head and compartment-pressure extension programme
Path: operations/water-hybrid-pressure-extension-programme.md
authority: current-documentation
document-kind: design
status: Planned
scope: Parallel/extension research for deep-Water bulk response, generic Rapier↔cellular coupling, bounded solided-Water sheet proofs, saturated-head requirement reassessment, lumped gas regions and optional decompression events; no production architecture adoption
canonical-for: [water-hybrid-pressure-extension-programme]
last-reviewed: 2026-10-24
Section: Water hybrid, saturated-head and compartment-pressure extension programme > Relationship to #49 and #45 > #45 is no longer treated as an inevitable pressure implementation
#45 remains the existing owner of the saturated-head architecture question, but its implementation decision must consume the extension evidence before assuming a new head/pressure carrier is necessary. The corrected communicating-head fixture should be treated as an explicit physical control whose boundary assumptions are stated. In particular, equal free-surface levels are not a universal target when the gas volumes above the liquids are sealed at different pressures. With the corrected #49 control and the relevant hybrid evidence, the acceptable #45 dispositions include: - the hybrid mechanism supplies enough intended deep-release behavior and no additional saturated-head mechanism is justified; - #45 remains necessary, but only under explicit vented/open-head boundary assumptions; - a bounded Water head mechanism is still valuable while sealed-space behavior is deliberately outside scope; - compartment pressure must become an explicit optional boundary condition before a sealed-head fixture has a meaningful target; - the generic feature is not worth its complexity for the intended game domain, and rare set-piece effects such as a rising-water chase are better authored with explicit material sources/sinks/spawners. A no-go/defer is a legitimate architecture result. Do not implement #45 merely because the issue exists.


### Rank 3: reference/invariants.md — Architectural and simulation invariants > Physical actor invariants

Document: Architectural and simulation invariants
Path: reference/invariants.md
authority: current-documentation
document-kind: contract
status: Approved design
scope: Stable review IDs with current enforcement, known exceptions and approved requirements; this register is not a test-result ledger
canonical-for: [invariant-register]
last-reviewed: 2026-11-20
Section: Architectural and simulation invariants > Physical actor invariants
For the [Workbench composition candidate](../systems/workbench-actor-composition.md), inspection never grants human producer authority. Source switching uses existing takeover cancellation and generation fences without reconstructing the body. Eight logical slots, eight prepared parts per actor and 64 response bodies/mask proxies are separate bounds; equipment remains reserved after release. Complete validation and prepared adoption precede changing the applied authored map. Contract: [articulated actors](../systems/physical-actor-rigs.md), [physical commands](interfaces-and-message-contracts.md#physical-actor-control-and-effects). Sources: [session](../../godot/scripts/physical_actor_session.gd), [runtime](../../godot/scripts/physical_actor_rig.gd), [effects](../../godot/scripts/physical_actor_effects.gd), [equipment owner](../../godot/scripts/physical_usable_equipment.gd), [physical usable runtime](../../godot/scripts/physical_usable_runtime.gd). Focused catalogue, Rapier, session, effects and integration runners detect the listed boundaries; execution evidence remains separately dated. | ID | Status and narrow claim | |---|---| | RIG-001 | Current: main-thread Rapier owns every live part/joint; the cellular owner receives copied values and alone writes native materials | | RIG-002 | Current: physical actor graphics use actual declared rectangle/circle collider dimensions and published transforms; authored leg, rotor and held parts are physical bodies; SetP circles explicitly retain conservative square native masks | | RIG-003 | Current: installation checks at most eight actors, eight parts per actor including held objects, and 64 total coupled bodies before activation | | RIG-004 | Current: human, demo and policy producers use one normalized action path; run/actor/epoch/sequence/issued-observation leases prevent stale authority from controlling a replacement | | RIG-005 | Current: cancellation clears stored launch intent and pending effects without interpreting it as charged release or deleting physical velocity | | RIG-006 | Approved and Current authored policy: bounded gyro assistance, approximate slides and controlled flex/play are permitted; finite gyro momentum and exact mechanical joint emulation are not required | | RIG-007 | Current: physical command/environment version 2 is distinct from sampled actor rows and Thunderbowl v1; no tag, metal, neural-service or reward equivalence is implied | | RIG-008 | Current: new desktop assemblies wait for matching reset/epoch and installed initial terrain; a retired world's cached geometry cannot release the fence | | RIG-009 | Current: worker effect batches are admitted wholly within eight pending requests or explicitly refused; bounded copied admission diagnostics are separate from actual-cell receipts | | RIG-010 | Current: ACT-005 equipment is one real coupled part whose body ID survives held, released, fixed, deployed and nearby pickup transitions; selection/lifecycle epochs revoke superseded authority without teleporting the part or erasing momentum | | RIG-011 | Current: physical usable requests carry run, actor, generation, equipment epoch, instance, body and request identity; one pending request per actor includes extracted work, and a whole batch is admitted within eight slots or explicitly refused | | RIG-012 | Current: physical source clearance and target protection use actual


### Rank 4: architecture/material-authoring-catalogue-plan.md — Canonical material catalogue and interaction authoring — adopted Planned baseline > 3. Orthogonal material classification

Document: Canonical material catalogue and interaction authoring — adopted Planned baseline
Path: architecture/material-authoring-catalogue-plan.md
authority: current-documentation
document-kind: design
status: Planned
scope: Owner-adopted Planned production baseline; section 15 records bounded Materials Lab v1 implementation authorization and review candidate, section 14 records liveness investigation, and sections 1–13 preserve historical boundaries
canonical-for: [material-authoring-v1-programme-proposal]
last-reviewed: 2026-11-11
Section: Canonical material catalogue and interaction authoring — adopted Planned baseline > 3. Orthogonal material classification
**Decision proposed:** no single inheritance hierarchy should control all simulation fields. Use six independent dimensions. | Dimension | Example | Effects | |---|---|---| | Stable identity | `cybersand:wood` ↔ frozen byte 7 | Save/content references and compatibility | | Browse category and tags | `Organics / Wood`, `construction`, `timber` | Search/picker only; can belong to many filtered collections | | Physical capabilities | `hard_surface`, `granular_support`, density target exchange | Native collision/transport predicates; explicit flags | | Behaviour preset and state contract | `legacy.wood.v1`, current `Combustible` kernel | Only tested native mechanism and valid parameter consumers | | Semantic interaction membership | `int.family.combustible-kernel`, `aqueous-contact` | Rule selectors, not inferred from colour/name/category | | Appearance programme | RGBA, flair, projection, procedural finish | Godot shader/display only; never physics or per-cell extra paint by implication | **Proposed browse taxonomy:** Natural media (powders, liquids, vapours, ice), Organics/life (woods/fibres, plants/fungi, agents), Construction (masonry, earth/clay, concrete, roofing), Metals (base, alloys, fabricated, weathered), Glass/ceramic/crystal, Polymers/composites, Reactive/energetic, Devices/special. Browsing taxonomy is deliberately **not** mechanical inheritance. Wrought Iron and Copper do not automatically gain base-Metal charge; Chemical Glass does not automatically gain base-Glass phase reactions; building woods do not automatically become Fungus/Mite timber substrates. Even two visually identical materials may have different native capabilities. Overlapping semantic families are allowed. If a future authored family sets an effective parameter that overlaps another, compilation must require a unique explicit override or fail with the conflicting source locations—not rely on array insertion order.


### Rank 5: systems/physical-actor-rigs.md — Articulated Rapier actors and shared physical control > Which usable examples exist?

Document: Articulated Rapier actors and shared physical control
Path: systems/physical-actor-rigs.md
authority: current-documentation
document-kind: contract
status: Current
scope: Articulated desktop roster with ACT-005 physical equipment and SetP human movement presets, authored mechanics, local scripted control and leased input; sampled references and scientific material acceptance remain separate
canonical-for: [physical-actor-rigs, physical-actor-control-v2, physical-actor-usables]
last-reviewed: 2026-10-22
Section: Articulated Rapier actors and shared physical control > Which usable examples exist?
**Current experimental ACT-005 source:** the entire [U01-U32 catalogue](actor-usables.md) is selectable on physical equipment. Every rig has a defined default loadout in [`physical_usable_loadouts.gd`](../../godot/scripts/physical_usable_loadouts.gd). Each loadout names its usable, power, strategy and purpose; no physical actor is left with an unspecified equipment policy. SetP explicitly starts with an empty mount and human movement strategy; F5 can still select ordinary equipment. Mount definitions bind a specific host/held part, grip, joint, aiming limits and clearance. The equipment owner aims the actual configured joint when it supports aiming. The shot direction comes from the current held body's pose; a limited joint cannot acquire an unlimited virtual muzzle. The suspended payload, hammer and blade preserve their authored mechanical roles. A selection change retools the existing held chassis without allocating another body. Release clears the held connection and retains the same object, pose, velocity and body ID. A short collision grace ages with physical time even after input cancellation. Pickup checks the owning grip's proximity and terrain clearance; it does not teleport the object or reset its velocity. An already held, remote, occluded or ambiguously owned item is refused. A released chassis must return before it can select another usable. Processors are deployed by dropping that real body, waiting for supported settling, and fixing it at its current pose. A worker receipt admits processing; blocked output leaves recipe inputs and stock unchanged. The body and its rotated intake/output ports remain visible while it works, jams or exhausts. Physical pickup retires processing authority. See the [processor contract](actor-usables.md#u23u32-fixed-functional-objects). The main-thread owner applies recoil once for the matching admitted use. Native material effects use copied physical source/part information under worker ownership. Protected cells, foreign part occupancy, bounds and source clearance remain checked. The physical command, worker admission and changed-cell receipt are separate results; a valid command does not guarantee an unobstructed effect. Late receipts are fenced by run, actor, control generation, equipment epoch and request identity. The older ACT-004 direct mount/effect fixtures retain their bounded deposit/cut/rocket-charge substrate for regression; it is not a second unleased policy API for the full catalogue.

## OI04: Does prepared declared destruction require automatic whole-building stability and storage-sized chunks?

Canonical rank: None

Expected facts:

- Prepared declaration exploratory; blast/cut rolling pieces desired.
- Fracture pieces are not specified as storage chunks.

### Rank 1: reference/invariants.md — Architectural and simulation invariants > Hierarchical generation invariants

Document: Architectural and simulation invariants
Path: reference/invariants.md
authority: current-documentation
document-kind: contract
status: Approved design
scope: Stable review IDs with current enforcement, known exceptions and approved requirements; this register is not a test-result ledger
canonical-for: [invariant-register]
last-reviewed: 2026-11-20
Section: Architectural and simulation invariants > Hierarchical generation invariants
Contract: [hierarchical places and routes](../systems/procedural-hierarchical-generation.md). Source: [semantic API](../../native/include/cybersand/generation_grammar.hpp), [planner](../../native/src/generation_grammar.cpp), and [generator](../../native/src/world_generation.cpp). | ID | Status and narrow claim | |---|---| | GRAMMAR-001 | Current: semantic region/rule/slot identities exclude storage-chunk size, request order, recipe revision and finite window; a region-grid-size change explicitly changes identity | | GRAMMAR-002 | Current: region-contained features may cross storage chunks; canonical boundary/socket ownership and explicit routes do not require either owning chunk to have been generated | | GRAMMAR-003 | Current: hard layout requirements precede preferences; bounded priority search may reject a feasible alternative rather than silently relaxing a constraint | | GRAMMAR-004 | Current: omitted features require authored fallback receipts; required neighbors and support are rechecked after omission | | GRAMMAR-005 | Current: finite curve order controls placement/inspection but never substitutes for explicit route edges, matching sockets or final-cell clearance | | GRAMMAR-006 | Current: exported geometry is immutable declared context; semantic planning and typed fields do not read partial raster output or live World state | | GRAMMAR-007 | Current: final hard material overrides preserve authority and can fail a route report; geometric clearance is qualified for the declared floating square profile, not an actor/controller | | GRAMMAR-008 | Current: compile/budget failure publishes no partial plan, material or diagnostic packet; semantic inspection does not grant World admission or streaming authority | | GRAMMAR-009 | Current: final support qualification is separate from route success; each declared floor/ceiling/wall check needs at least one final Solid contact and reports partial missing contacts without claiming gravity stability or apparatus preservation |


### Rank 2: architecture/inertial-cellular-v1.md — Inertial cellular reference > Why does IN require radius three?

Document: Inertial cellular reference
Path: architecture/inertial-cellular-v1.md
authority: current-documentation
document-kind: reference
status: Current
scope: Current-main Water and Brine inertial reference, retained integer momentum, whole-cell admission, carrier ownership, radius and state costs; source-bound native/application evidence remains distinct from scientific comparison and human acceptance
canonical-for: [inertial-cellular-v1-brine, inertial-cellular-v1-water]
last-reviewed: 2026-11-03
Section: Inertial cellular reference > Why does IN require radius three?
Travel writes reach at most two cells per axis: after saturation and nonnegative damping |v|≤32 and |accumulator|≤15, so division by16 produces at most two unit moves. Eligibility is rechecked before each actual step. At most one extra neighborhood probe occurs after or alongside a final travel position. Starting vy32/ay15 reaches y+2 and U7 reads y+3; a contact-side query can similarly reach x±3. Shared powder-exchange Stone bracing inspects one further neighbor of a target within the same radius-three envelope. Brine does not execute the Water carrying stencil. Absent storage reads as Empty on the exclusive serial owner path, as in Current cellular motion. Eligibility queries allocate nothing; an actual serial move uses the shared destination allocator and its explicit capacity/failure contract. Phased jobs retain the prepared-domain guard and never allocate missing storage themselves. Reserving Empty chunks must not change the IN motion tuple at positive or negative chunk seams. An IN World therefore explicitly requires `maximum_rule_radius>=3`. The existing scheduler validates radius≤half an even core, prepares neighbor chunks, and separates same-phase expanded domains. Candidate/control comparisons must use identical admitted execution geometry; the protected exact Current preset retains radius2. Native boundary tests exercise signed coordinates, core8/core64, chunk seams, observed read3/write2 reach, no prepared tick allocation and actual four-worker execution. Configured workers and observed task participants are separate `TickStats` values. The Water successor above adds its own complete carrying/packing proof, actual `maximum()` quantity, coherence, direct-ingress refusal and existing normalization preparation. The historical radius3 Brine proof alone never qualified that mapping.


### Rank 3: architecture/data-ownership-and-lifetimes.md — Data ownership and lifetimes > Which transitions require exclusive ownership?

Document: Data ownership and lifetimes
Path: architecture/data-ownership-and-lifetimes.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current resource owners, mutation windows, publication retirement and allocation limits; proposed resources are explicitly separated
canonical-for: [resource-ownership-and-lifetimes]
last-reviewed: 2026-11-20
Section: Data ownership and lifetimes > Which transitions require exclusive ownership?
Setup, reset, reservation, rule/configuration replacement, level export/import and World destruction must not overlap job views or producer access. Jobs may not retain a view beyond their barrier. Native pool workers never call Godot; the desktop owner only calls its exclusive adapter/value APIs. `ParallelState` constructs its complete activity buffers before binding job spans and never resizes them afterward. Its pool retires before those spans and owners. A native pool constructor that fails after starting a worker must also stop, notify and join the started prefix before mutex/condition-variable member unwind; its destructor would not run for the failed constructor. The shared cleanup helper covers that exceptional path and ordinary destruction. C API construction publishes typed refusal only after this retirement, with no worker count fallback; the existing live World remains owned by its caller. The [dated reproduction and repair](../audits/2026-10-25-water-inertial-native.md#contiguous-activity-storage-and-constructor-retirement--2026-10-25) separates the original hang, packed-storage proof and final source proof. Level export clears transient obstacles; coupling must be rebuilt before the next cellular tick. Import builds a validated candidate before replacing World. See [level saves](../reference/level-saves-and-replay.md) for the exact scope. **Approved:** future reconfiguration drains affected work before replacing storage, then resumes on a whole tick. **Planned:** active-only next buffers, buffered halos/transfers, bounded general gameplay results and serialization staging. Their sizes, retirement/full-queue policy and live-resize failure API are not implemented. Do not infer them from Current snapshot backpressure. Lifetime fixtures are linked in the [validation ledger](../reference/validation-evidence.md); the rationale remains [ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md). Sampled [granular support queries](../systems/granular-interaction-policy.md) read current cells and copied body occupancy only under this exclusive owner, outside native jobs. Their bounded neighbourhood adds no job view, cache or Rapier object.


### Rank 4: architecture/data-ownership-and-lifetimes.md — Data ownership and lifetimes > Who may mutate each resource?

Document: Data ownership and lifetimes
Path: architecture/data-ownership-and-lifetimes.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current resource owners, mutation windows, publication retirement and allocation limits; proposed resources are explicitly separated
canonical-for: [resource-ownership-and-lifetimes]
last-reviewed: 2026-11-20
Section: Data ownership and lifetimes > Who may mutate each resource?
**Current:** each selected cellular world has one external owner. In the ordinary desktop sandbox that is `CyberSimulationWorker`; on Web it is the main-thread controller. Native World coordinates its internal jobs. Queries, export, publication and mutation require serialization by that owner; calling a method through GDExtension does not make World generally thread-safe. Native pool workers call no Godot APIs. The desktop Godot owner may call exclusive adapter/value APIs, but must not touch live scene-tree or Rapier objects. | Resource | Owner and permitted mutation | Lifetime and pressure | |---|---|---| | `World::chunks_` and chunk cell arrays | World coordinator creates/reserves chunks; serial work or phase-exclusive jobs mutate cells | Until World/chunk destruction; construction capacity bounds growth | | Optional temperatures | Chunk owns optional SoA; owner prepares it, permitted rules/movement use it | Allocated on demand or reservation; counted tick allocations | | Activity/dirty metadata and job effects | Job-local observations, then coordinator merge after the phase barrier | Persistent chunk metadata and reusable bounded scratch; dirty bounds survive unsuccessful publication | | Delayed pair deadline | Workers report through fixed disjoint job spans into two preallocated `ParallelState` flag/deadline buffers; the coordinator reduces the earliest deadline into shared block metadata after the phase barrier and wakes it at healthy tick entry | One persistent scalar per block plus bounded scheduler scratch; buffers outlive job spans and pool, excluded blocks retain deadlines, clear/replacement discards them | | Native snapshot slots | One serialized producer writes only an unleased slot | Shared exchange state outlives its facade while leases exist; no-slot/capacity failure retains dirty state | | Desktop world, sampled character and optional actor prototypes | Godot pacing Thread after startup handoff | Worker lifetime; stopped/joined before destruction; actor session reset invalidates old input epochs | | Controlled liquid preparation candidate and token (experimental #202 source) | The exclusive native adapter owns one pending World, render exchange, final setup and copied native receipt | Final configuration precedes capture; one-use token commit checks retained state and the desktop queue-mutex request/reset/stop fence. Discard/supersession/refusal retain the applied session; [sampled owners](liquid-prepared-setup-and-receipts.md#staged-sampled-actors-and-exploratory-owners) and [desktop articulated physical owners](liquid-prepared-setup-and-receipts.md#staged-articulated-physical-owners) prepare before commit. Physical graph/space stays main-owned, frozen and permanent; copied readiness and actual initial masks bind its nonblocking continuation. Other constructors and full evidence stay open | | Live body nodes, RIDs and physics state | Main-thread Rapier bridge and PhysicsServer2D | Scene/bridge lifetime; never passed to cellular workers | | Physical actor rigs, joints and local controllers | Main-thread `CyberPhysicalActorSession`; at most eight rigs/eight total parts each | Run/actor/epoch-bound


### Rank 5: reference/status-and-roadmap.md — Status and foundational roadmap > Current implementation map

Document: Status and foundational roadmap
Path: reference/status-and-roadmap.md
authority: current-documentation
document-kind: reference
status: Current
scope: Current implementation map, unresolved correctness and policy decisions, and bounded next checkpoints
canonical-for: [implementation-status, foundational-priorities, open-decisions]
last-reviewed: 2026-11-21
Section: Status and foundational roadmap > Current implementation map
**Layered exhibition source, 2026-10-20:** [Deepworks](../operations/deepworks-exhibition.md) adds one 1024 × 1024 composition with sixteen districts, 32 foreground/rear native exhibits and all 51 MAT-002 building materials. Four independent full-size worlds run at 30/20/15/0 Hz; the true distant background is frozen. Finite reaction sources preserve products, while the camera/painting viewer supports whole-map reset, apparatus focus and a guided tour. It does not install an ordinary actor session. The shared [depth APIs](../systems/depth-layers-and-parallax.md) now admit each axis from 8 through 1024, including non-square worlds, while preserving Strata Theatre's 640 × 360 default. Native ABI and material rules are unchanged. Runtime and actual rendered acceptance remain separately scoped by the [dated exhibition audit](../audits/2026-10-20-deepworks-exhibition.md). **Connected scene content, 2026-10-18:** [Blacksite Nine](../operations/blacksite-nine-demo.md) composes nine 320 × 320 districts into one 960 × 960 native region: a surface laboratory between two wastelands, above six dense underground industrial districts. Twelve reciprocal ports and a common final passage carve connect the whole map. Shift+F11 and the Web demo menu install the complex; the 3×3 map, atlas and following views change only the camera, while R resets all nine districts together. Its fixed interest region and world-coordinate presentation preserve continuity without introducing a streaming subsystem. The [dated scene audit](../audits/2026-10-18-blacksite-nine.md) owns recipe, runtime and visual evidence; physics programmes retain their gates. **Scene content, 2026-10-18:** [Neon Reliquary](../operations/neon-reliquary-demo.md) adds an ornate machine-cathedral demo and the three tiles beneath it: Middle Cyberberbia, Sewertech Alley and Industrial Underswamp. They use the shared native MicroScenario host, with desktop/Web entry points, five views per tile, Above/Below navigation and themed distant scenery. District changes load original layouts. It is an aesthetic showcase; existing physics programmes retain their own gates. | Area | Implemented scope and canonical contract | |---|---| | Cellular authority and platform owners | Native World; asynchronous desktop GDScript owner, synchronous Web callbacks with optional internal pool; [threading](../architecture/simulation-tick-and-threading.md) | | Scheduler and storage | Sparse chunks, phased in-place jobs, explicit capacities and activity sleep; [chunk/tile model](../architecture/chunk-tile-and-buffer-model.md), [storage](../systems/world-storage-and-interest-region.md) | | Procedural generation candidates | Opt-in Strata, Flow Network and District Grammar; theme/brush/override/module recipes plus bounded scalar fields, masked context guidance and aggregate materials; copied chunk proposals and explicit fresh-chunk admission; [generation contract](../systems/procedural-world-generation.md), [field/modifier contract](../systems/procedural-generation-fields-and-modifiers.md) | | Materials | Bounded adapted kernels, mass-conserving native Water, discrete fallback, secondary interaction lanes; 51 MAT-002 building materials (IDs 81–131) with combustion and 42 versioned pair reactions; [materials](../systems/materials-and-rule-kernels.md), [building catalogue](../systems/building-material-catalogue.md), [Water](../systems/water-design.md). Source/runtime publication and completed-test scope are recorded in the [MAT-002 review](../audits/2026-10-19-mat002-review-and-validation.md). | | Field storage and events | Optional temperature storage and bounded explosions; no general heat/pressure/wind solver; [field roadmap](../systems/smoke-heat-pressure-roadmap.md) | | Bodies and

## OI05: Should persistent areas catch up with real offline time or game time, and can transitions pause briefly?

Canonical rank: 1

Expected facts:

- Game time, occasional few-second transition acceptable, optional simulate ahead.

### Rank 1: decisions/2026-11-14-owner-authoring-intent.md — Owner authoring and world intent — 14 November 2026 > World extent, persistence and time

Document: Owner authoring and world intent — 14 November 2026
Path: decisions/2026-11-14-owner-authoring-intent.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Direct owner clarification of product intent; implementation, qualification and execution permissions remain separate
canonical-for: [owner-clarifications-2026-11-14]
last-reviewed: 2026-11-14
Section: Owner authoring and world intent — 14 November 2026 > World extent, persistence and time
**Confirmed:** one fixed canvas plus persistent areas loaded while travelling should cover most intended uses. Broad continuous canvases should accommodate biomes or small towns; later presentation can disguise boundaries. The prepared brief interprets moving beyond “1:1 canvases” as allowing non-square/broad maps, not changing display-pixel scale. Concrete dimensions await practical work. **Confirmed:** a useful simulated border around the viewport/activity, potentially extended in the travel direction, is desirable. On returning to an area, approximate headless catch-up is preferable to a conspicuously frozen room. Use **game time**, not real-world offline time. Occasional transitions lasting a few seconds are acceptable. An optional deliberate **simulate ahead** control is desired. Approximation and quantisation can be acceptable. **Engineering questions:** retained state, bounded catch-up algorithms, activity margins, cross-area exchanges and material-policy evolution remain unresolved. Track the last simulated/accounted-for time rather than merely last visit if an area can keep simulating in a border. Headless execution still consumes compute. These observations do not authorise implementation or a large benchmark campaign.


### Rank 2: decisions/ADR-004-interest-region-and-reconfiguration.md — ADR-004: Interest region and safe reconfiguration > Which alternatives are rejected?

Document: ADR-004 — Interest region and safe reconfiguration
Path: decisions/ADR-004-interest-region-and-reconfiguration.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Accepted scalable interest/capacity direction, current construction limits and unresolved margin/reconfiguration semantics
canonical-for: [decision-interest-capacity-reconfiguration]
last-reviewed: 2026-09-08
Section: ADR-004: Interest region and safe reconfiguration > Which alternatives are rejected?
**Rejected:** silently clipping requests, fixed current-size windows forever, reserving the largest imaginable world and growing containers during worker execution. These restrictions are production direction, not proof that every prototype path is compliant: lazy coordinator preparation can still allocate inside a tick, and current failure can follow partial progress. **Approved choice, Current (issue #2, 2026-09-08):** pause excluded phased work, retain its activity/quiet state, wake newly included resident blocks once at tick entry (including sleepers), and resume without elapsed-time catch-up. The owner authorized engineering judgement for this separate policy. Serial keeps its whole-active-chunk behavior and ignores the filter; no new cross-mode equality. The [interest contract](../systems/world-storage-and-interest-region.md) owns exact core selection, custom geometry, coalescing and bounded-work semantics. Rechecking sleeping blocks costs bounded work on real transitions and can expose capacity exhaustion; retaining only existing wake flags would be cheaper but could leave stale sleepers frozen. That alternative is **Rejected for this fix**, as are automatic catch-up, periodic full-cell wake scans and repeated unchanged-region wake. General field/streaming catch-up remains **Planned separately**. Failed Worlds accept only a latched region request; reset/replacement is still required.


### Rank 3: reference/product-intent-and-priorities.md — Product intent and priorities > Owner clarification — 2026-11-14

Document: Product intent and priorities
Path: reference/product-intent-and-priorities.md
authority: current-documentation
document-kind: reference
status: Current
scope: Approved owner direction and deliberately preserved behavior; not current implementation or performance evidence
canonical-for: [owner-intent, product-priorities, preserved-material-feel]
last-reviewed: 2026-11-08
Section: Product intent and priorities > Owner clarification — 2026-11-14
The [dated owner clarification](../decisions/2026-11-14-owner-authoring-intent.md) records the current paint-and-play Workbench direction, convincing behaviour, prepared-destruction exploration, Save/Flatten intent, live material audition, Strata presentation, broad canvases and game-time catch-up. Use that scoped record for these questions. Earlier dated passages below preserve their original scope; neither this clarification nor historical execution wording grants new work or merge permission.


### Rank 4: systems/activity-dirty-regions-and-waking.md — Activity, dirty regions, and waking > Approved requirements and open work

Document: Activity, dirty regions, and waking
Path: systems/activity-dirty-regions-and-waking.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native activity and dirty-state lifecycle; separate fallback behavior and future wake requirements
canonical-for: [cell-activity-sleep-wake, simulation-render-dirty-state]
last-reviewed: 2026-11-04
Section: Activity, dirty regions, and waking > Approved requirements and open work
**Approved:** new fields/events must declare wake reach, quiet eligibility, delayed work, conservation, and interaction with interest filtering. Sleeping interiors should not require a periodic full-cell scan to discover outside change. **Current:** native re-entry follows the explicit pause/wake policy. **Planned:** future field/streaming time semantics and separate persistence dirtiness once storage serialization exists. No generalized field catch-up API is implemented. [Native fixtures](../../native/tests/test_world.cpp) cover quiet sleep, local edge wake, Water rest, capacity, and snapshot pressure. Their presence does not prove every field/boundary combination. Extend shifted/mirrored edge tests when rule reach changes. Issue #2 regressions cover exclusion, sleep, overlapping/disjoint re-entry, core/chunk boundaries, unchanged/coalesced regions, neighbors, retained temperature, conservation, worker parity and failed-world recovery. These are bounded fixtures, not every future field or material combination.


### Rank 5: systems/player-control-playground.md — Player control playground > Immediate shared-course pause transitions

Document: Player control playground
Path: systems/player-control-playground.md
authority: current-documentation
document-kind: contract
status: Current
scope: Experimental movement controls and shared asynchronous desktop composition, input and lap lifetime, lifecycle and bounded native failure validation; isolated Sand and Water player fields
canonical-for: [player-control-playground, player-movement-presets, player-material-field]
last-reviewed: 2026-11-05
Section: Player control playground > Immediate shared-course pause transitions
**Current source behavior; final hosted acceptance is recorded separately:** P, Escape and the selected gamepad's Start route through the same shared-course pause setter. Every actual pause/resume transition immediately cancels input authority and queued button/equipment edges, before the next physics callback. A pause then resume within one callback interval therefore cannot retain an old press or lease. The existing native worker, World, actor session and Rapier bridge remain the owners; release controls to neutral before fresh input rearms. The pause toggle respects window/UI ownership. Unselected controllers and keyboard-only sessions cannot use Start; modal/unfocused input cannot resume. The panel's explicit Play / resume button uses the same cancellation path. Resume refuses failed native work, pending reconstruction/reset or unready terrain. Controls outside the composed course retain their previous behavior. Ordinary actor-picker and environment-tuning opening, GUI focus acquisition and window-focus-loss notification also revoke course authority immediately. The visible MicroScenario Pause / resume button calls the central pause setter as an explicit UI action, including while its Seed field retains text focus. The keyboard/gamepad toggle remains context-gated. Every successful transition still requires neutral controls before fresh physical input can rearm. The [INPUT010 audit](../audits/2026-10-31-play-input010-pause-transitions.md) records an actual failing-before callback-gap reproduction, all-five-rig automatic Main/native/Rapier regressions, original local environmental failures and required exact-head hosted results. Injected focus/device enumeration is explicitly synthetic; this is not physical-controller or OS-focus acceptance. The [INPUT011 audit](../audits/2026-10-31-play-input011-authority-transitions.md) preserves the rapid modal/focus failure and the separately reproduced focused button refusal. Its v2 five-rig cases include both explicit-button success and keyboard-toggle refusal with retained text focus, actual later neutral/fresh Rapier steps, and the matched stale-input negative. The ordinary parent runner requires source-bound raw-evidence readback before accepting each rig case; synthetic window notifications do not establish real OS-focus delivery.

## OI06: Are Materials Lab comparison tabs and a separate Strata Theatre enough for Workbench authoring?

Canonical rank: 1

Expected facts:

- Live Workbench material audition desired.
- Four-layer Strata should be available as a Workbench option.

### Rank 1: decisions/2026-11-14-owner-authoring-intent.md — Owner authoring and world intent — 14 November 2026 > Live materials and layered presentation

Document: Owner authoring and world intent — 14 November 2026
Path: decisions/2026-11-14-owner-authoring-intent.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Direct owner clarification of product intent; implementation, qualification and execution permissions remain separate
canonical-for: [owner-clarifications-2026-11-14]
last-reviewed: 2026-11-14
Section: Owner authoring and world intent — 14 November 2026 > Live materials and layered presentation
**Confirmed:** Materials Lab should support easy material modification and audition, including changing values in a Workbench window for dynamic/custom trials. The existing comparison tabs are appreciated; isolated comparisons alone do not fulfil the desired current-scene interaction. Which properties can apply safely at runtime remains an engineering question. **Confirmed:** the four-layer Strata Theatre presentation should be an available Workbench option. Its visual impact is important. Historical integration exclusions are not a permanent rejection; the prototype's exact clocks and cross-layer event rules are not automatically the eventual product contract.


### Rank 2: systems/depth-layers-and-parallax.md — Depth layers and parallax prototypes > Purpose

Document: Depth layers and parallax prototypes
Path: systems/depth-layers-and-parallax.md
authority: current-documentation
document-kind: contract
status: Current
scope: Opt-in Strata Theatre and Deepworks material-world layering, authored dimensions, foreground-derived relief and explicit interlayer events; separate from production world ownership
canonical-for: [depth-layer-prototype, parallax-prototype, quantized-relief, interlayer-events]
last-reviewed: 2026-10-20
Section: Depth layers and parallax prototypes > Purpose
res://depth_lab.tscn is an opt-in comparison host for visual and figurative depth in CyberSand. It deliberately keeps several ideas visible side by side instead of making one of them production authority. The lab is called **Strata Theatre**. It can be opened directly, with --depth-lab, or from the ordinary desktop sandbox with **F4**. [Deepworks](../operations/deepworks-exhibition.md) reuses these four material planes in a separate 1024 × 1024 exhibition host, opened with `--deepworks` or `res://deepworks.tscn`. Its sixteen districts, source programme, independent clocks and camera/painting controls belong to that guide. Strata Theatre retains its original default dimensions and controls. | View | Meaning | |---|---| | Flat | Foreground-only control. | | Quantized relief | Bounded quantized samples of the foreground material image are offset/scaled behind the source silhouette to imply thickness. | | Four layers | Four independently authored material worlds are rendered together with different scale/parallax factors. | | Hybrid | Four layers plus foreground relief, distance haze and rear-scene reflection masked by foreground liquid IDs. | | Diorama | Hybrid plus a faster near-camera foreground-derived frame and pointer-centred cutaway. | None of the presentation-only modes creates authoritative Z coordinates, colliders, hidden material mass or a second owner of the play world.


### Rank 3: operations/materials-lab-authoring.md — Materials Lab v1

Document: Materials Lab v1 inspection, candidate authoring and native tests
Path: operations/materials-lab-authoring.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Implemented desktop review candidate; native inspection, source candidates, isolated compiled World comparisons and existing-material MicroScenarios; no production material migration or runtime candidate activation
canonical-for: [materials-lab-v1-ui, materials-lab-candidate-presets, materials-lab-native-experiments]
last-reviewed: 2026-11-12
Section: Materials Lab v1
**Current implementation merged in [PR #562](https://github.com/techrote/cybersand/pull/562); production activation remains unimplemented.** The desktop **Materials Lab** opens from the feature launcher, the ordinary Shared Workbench's **Materials Lab…** button, or `--materials-lab`. It combines native material inspection, structured candidate editing, compiled candidate tests, a compiled candidate/reference World comparison and an isolated native MicroScenario. The [dated qualification record](../audits/2026-11-11-materials-lab-v1.md) distinguishes the preceding implementation's evidence. The [completion record](../audits/2026-11-11-materials-lab-completion.md) owns the subsequent native contact diagnostics, runtime publication and Windows package qualification. On supported desktop displays, the Workbench opens the Lab in its own native window, preserving physical-pixel text and local input while the game retains its canvas scaling. Headless/Web displays retain the embedded fallback. Closing the Lab returns to the same Workbench session; its owner policy is refreshed when reopened. Native placement fits the client, title bar and borders within the usable desktop work area on the owning screen. A desktop too small for the existing 1000x650 client plus its borders receives an explicit capacity refusal. The Lab uses the accepted [catalogue compiler](material-catalogue-shadow.md). It does not replace native production definitions, the simulation worker, the Workbench or World. Production still has 132 slots, including invalid reserved ID 10. The synthetic powder at 132 exists only inside an external candidate build. The five tabs are **Inspect**, **Edit copy**, **Reactions**, **Try originals** (unchanged built-in materials) and **Compare edits** (your copy against the original). In Inspect, drag the edge between column titles to set widths; double-click a divider to restore its width. The table scrolls sideways if it gets wider than the window. **Defined value** is the saved definition; **Value used** includes engine overrides. Hover any cell to read the whole explanation and its technical name. **Show technical details and reaction data** reveals the full reference information.


### Rank 4: operations/materials-lab-authoring.md — Materials Lab v1 > Launch and prerequisites

Document: Materials Lab v1 inspection, candidate authoring and native tests
Path: operations/materials-lab-authoring.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Implemented desktop review candidate; native inspection, source candidates, isolated compiled World comparisons and existing-material MicroScenarios; no production material migration or runtime candidate activation
canonical-for: [materials-lab-v1-ui, materials-lab-candidate-presets, materials-lab-native-experiments]
last-reviewed: 2026-11-12
Section: Materials Lab v1 > Launch and prerequisites
Use a complete checkout of the implementation branch and its history. Git LFS and the ordinary [desktop dependencies](local-build-and-validation.md) remain required. Godot is pinned to **4.7.stable.official.5b4e0cb0f** and godot-cpp to `101ae38034304346a46ea9ea84ae156d3e860496`. Rebuild the matching GDExtension: an older retained production binary predates the new read-only inspector methods. An older library causes an explicit rebuild message, not a metadata fallback. Use a freshly qualified branch runtime only when its provenance matches the checkout's native inputs; the completion publisher provides that explicit path. ```sh # Use the existing pinned build environment; see the local-build guide for setup. tools/build_pinned_godot_cpp.sh linux tools/build_native_extension.sh godot --path godot -- --materials-lab ``` Read-only inspection and native experiments require the matching engine library. Candidate authoring additionally requires Python 3, Git history and a C++20 compiler for **Build + check definition**. The Edit copy tab accepts Python and compiler executable paths without shell arguments. A compiler override is also available through `CYBERSAND_LAB_CXX`. Source tools must remain next to the Godot project; this is a desktop source workflow, not an exported/Web authoring service. No install operation writes production sources. The standalone Lab uses window pixels for readable controls instead of shrinking the game's 1920×1080 canvas. Tabs scroll when their contents exceed the available space, including the 1000×650 Workbench window minimum. Inspection columns keep their useful widths and can scroll horizontally. Closing the standalone Lab restores the launcher's original scaling. These presentation changes do not alter the simulation viewport or the shared Workbench's controls.


### Rank 5: systems/depth-layers-and-parallax.md — Depth layers and parallax prototypes > Four material planes

Document: Depth layers and parallax prototypes
Path: systems/depth-layers-and-parallax.md
authority: current-documentation
document-kind: contract
status: Current
scope: Opt-in Strata Theatre and Deepworks material-world layering, authored dimensions, foreground-derived relief and explicit interlayer events; separate from production world ownership
canonical-for: [depth-layer-prototype, parallax-prototype, quantized-relief, interlayer-events]
last-reviewed: 2026-10-20
Section: Depth layers and parallax prototypes > Four material planes
The prototype owns four separate CyberNativeCellWorld objects through CyberDepthLayerRuntime. Each world uses the existing native material IDs, rules and RG8 RenderBridge projection. Godot owns only authoring, presentation and explicit lab commands. | Plane | Strata default rate | Intended use | |---|---:|---| | play | 60 Hz | Active foreground/play material. | | scripted | 20 Hz | Rear set, destructible scenery and set-piece sequences that should not perturb foreground material. | | effects | 30 Hz | Rain, snow-like Dust, Steam fog, Spark energy and other environmental material effects. | | background | 0 Hz | Authored distant city. It is never ticked and its first copied RG8 publication is cached. | The rates are independent. Dynamic planes may be reduced or paused without changing the others. The background rejects non-zero rates. Deepworks selects 30/20/15/0 Hz for play/scripted/effects/background. Every Deepworks plane spans the full 1024 × 1024 authored map; the rear `scripted` world runs native reactions while the true `background` world remains frozen. Each plane has its own render canvas and a material surface covering the accepted authored ROI, defaulting to 640 × 360 in Strata Theatre. Frozen surfaces request a one-shot bake when a copied publication arrives or updates are paused, so pausing before the first draw still renders the admitted state. See [`CyberDepthLayerSurface.apply_packet()` and `set_render_enabled()`](../../godot/scripts/depth/depth_layer_surface.gd). The current host uses one native adapter owner and serializes calls into its four worlds. Production adoption should integrate the play plane with the existing asynchronous owner rather than introduce another mutable owner.
