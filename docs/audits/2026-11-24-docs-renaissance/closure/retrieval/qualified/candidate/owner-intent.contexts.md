# Retrieval contexts for independent answer review

Source-backed expected facts and the complete top-five contexts follow. A canonical route hit alone is not an answer pass.

## OI01: What does the owner want CyberSand and Workbench to become?

Canonical rank: None

Expected facts:

- Paint-and-play authoring system with accessible controls; integrate useful capabilities through Workbench.

### Rank 1: operations/workbench-first-session.md — Your first Workbench session > Save what you mean

Document: Your first Shared Workbench session
Path: operations/workbench-first-session.md
authority: current-documentation
document-kind: guide
status: Current
scope: A small paused material authoring tutorial with simulation, saving and fresh-session reconstruction
canonical-for: [workbench-first-session]
last-reviewed: 2026-11-24
Section: Your first Workbench session > Save what you mean
Choose the appropriate action: | You want to retain… | Action | | --- | --- | | The authored container and original material placement | **Save start**; later simulation is not folded into ordinary Save. | | The material arrangement you can see after simulation | **Flatten / Bake History…**, confirm the history discard, then **Save start**. | | Exact velocities, temperatures, tick and actor motion | Ordinary authored saving does not provide this. | Flatten preserves the live World while replacing the authored material baseline. It clears earlier construction and Undo/Redo history, and **does not save by itself**. See [Saving authored worlds](workbench-saving.md) before using it on valuable work.


### Rank 2: operations/architectural-generator-playtest.md — Architectural Generator walkthrough > Install, paint, save and reopen

Document: Architectural Generator walkthrough
Path: operations/architectural-generator-playtest.md
authority: current-documentation
document-kind: guide
status: Current
scope: Accepted native Architectural Generator, Gentek catalogue, preview, installation and authored save workflow
canonical-for: [architectural-generator-owner-evaluation]
last-reviewed: 2026-11-24
Section: Architectural Generator walkthrough > Install, paint, save and reopen
1. Save any current work you want to keep. After a complete preview, click **Install into workbench**. Installation explicitly replaces the material map. 2. Keep the scene paused. Paint a visible mark and erase an opening. Follow [painting and history](workbench-painting-and-history.md) for shapes and Undo. 3. Enter a unique name in the painting row and use **Save start [Ctrl+S]**. The control is visible in that row; it is not hidden under Details. 4. Exit completely, relaunch, enter that name and choose **Load start**. The **Verify and reopen saved starting map** dialog generates and verifies its saved recipe. Wait for the complete preview, then click **Install into workbench** to reconstruct it. Cancelling keeps the current map; a source identity mismatch refuses the proposal without replacing it. 5. Check the generated baseline and ordered paint/erase edits. Actors reconstruct from authored settings and spawns. Their exit-time momentum is not restored. Saved generated starts embed the resolved native recipe and do not require the original external style or project file. They preserve an authored result, not an arbitrary evolved simulation state. [Saving](workbench-saving.md) explains when explicit **Flatten / Bake History…** is appropriate.


### Rank 3: architecture/overview.md — Architecture overview > How does authoring become a running scene?

Document: Architecture overview
Path: architecture/overview.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current execution paths and authority map; routes to the contracts that govern changes
canonical-for: [architecture-entry-point]
last-reviewed: 2026-11-24
Section: Architecture overview > How does authoring become a running scene?
A setup, native generator proposal or material-only baseline supplies the starting terrain. Workbench validates the complete authored document, prepares native and physical candidates, and adopts them through the existing owner transaction. Refusal preserves the valid running session. Painting uses its own bounded owner requests and completion/history checks; an accepted queue entry does not prove that pixels changed or that Save contains them. [Ordinary Save start](../reference/level-saves-and-replay.md#workbench-starting-constructions) records reconstruction data. [Flatten](shared-workbench-authoring-data.md#flatten-and-storage-compatibility) captures stored material identities, replaces the authored baseline and discards previous construction/Undo history. It leaves the live World and Rapier state unchanged and does not save automatically. Neither operation is complete physical continuation. Wave Worlds explicitly refuse exact physical save/restore.


### Rank 4: reference/product-intent-and-priorities.md — Product intent and priorities > What the owner wants Workbench to become

Document: Product intent and priorities
Path: reference/product-intent-and-priorities.md
authority: owner-confirmed-intent
document-kind: reference
status: Approved design
scope: Source-linked owner direction and preserved preferences; implementation, qualification and execution permission remain separate
canonical-for: [owner-intent, product-priorities, preserved-material-feel]
last-reviewed: 2026-11-24
Section: Product intent and priorities > What the owner wants Workbench to become
**Approved:** combine painting, simulation, generation, material experimentation, actors and model-assisted creation through a coherent ordinary Workbench. Painting should grow toward the useful range between classic MSPaint and GIMP/Krita. Preserve simple paths for exploration while making advanced controls available. The engine should support varied experiments: a passive plasma chamber, a forest drone game, a digging game, industrial/urban exploration and future cyberpunk settings. Underground spaces, interiors, orbit or vacuum are possible settings, not claims of finished RPG systems, orbital mechanics or world streaming. **Game-facing scoring and consequential actor combat damage wait until the arrangements, materials and actors feel fun.** Internal diagnostics and training metrics are not prohibited by that preference. Useful convergence is already implemented in parts, including ordinary painting, Art drawing, native generation and actor composition. The current extent belongs to the [authoring contract](../architecture/shared-workbench-authoring-data.md). Do not revive the obsolete “#548 design only” or “Workbench unavailable” instructions from the original integration handovers.


### Rank 5: operations/materials-lab-authoring.md — Materials Lab v1 > First inspection and safe experiment

Document: Materials Lab v1 inspection, candidate authoring and native tests
Path: operations/materials-lab-authoring.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Accepted desktop native inspection, candidate authoring, isolated World comparisons and existing-material MicroScenarios; no runtime candidate activation
canonical-for: [materials-lab-v1-ui, materials-lab-candidate-presets, materials-lab-native-experiments]
last-reviewed: 2026-11-24
Section: Materials Lab v1 > First inspection and safe experiment
1. Open **Inspect**, search **Water**, and compare **Defined value** with **Value used**. Read the consumer/applicability explanation before treating a displayed property as an adjustable simulation input. 2. Open **Try originals** and choose an existing-material case. Run the isolated test and inspect its native result; it does not alter the Workbench canvas. 3. Return to **Inspect**, select **Sand**, and **Duplicate selected**. Change only a supported candidate field in **Edit copy**, then use **Build + check definition** when the compiler tools are configured. 4. Follow [Compare an edited candidate](#compare-an-edited-candidate-in-a-real-native-world) for a real candidate/reference World comparison. Save the material preset if you want to resume editing later. ![Materials Lab's native Water inspector with declared and effective property columns](../images/materials-lab-v1/01-inspector-water.png) *Retained application capture from the original accepted Lab qualification; its [dated record](../audits/2026-11-11-materials-lab-v1.md) retains the exact source/runtime scope. It is not a fresh capture of this documentation change.* The current Lab tests candidates in isolated worlds. A **live current-scene audition** is a separate unmerged programme; no button in this guide installs candidate definitions into the running Workbench. Closing the Lab returns to that same scene.

## OI02: Should saving a settled canvas flatten everything and destroy the session Undo history?

Canonical rank: 5

Expected facts:

- Save desired evolved layout without unexpected live Undo destruction.
- Explicit two-byte material Flatten differs from ordinary Save and a full checkpoint.

### Rank 1: reference/product-intent-and-priorities.md — Product intent and priorities > Save, Flatten and compatibility

Document: Product intent and priorities
Path: reference/product-intent-and-priorities.md
authority: owner-confirmed-intent
document-kind: reference
status: Approved design
scope: Source-linked owner direction and preserved preferences; implementation, qualification and execution permission remain separate
canonical-for: [owner-intent, product-priorities, preserved-material-feel]
last-reviewed: 2026-11-24
Section: Product intent and priorities > Save, Flatten and compatibility
**Approved desired behavior:** save the intended evolved material arrangement without unexpectedly destroying the live session's Undo history. Settled Oil should reopen where it was saved; original Acid strokes should not reappear after the user has damaged and cleaned up a scene. This is intent, not a claim that ordinary current Save already captures all evolved state. **Explicit Flatten:** capture material occupancy using two bytes per cell so burdensome construction history can be discarded. Flatten is not a physical checkpoint and does not require that normal saves always flatten. The accepted implementation leaves the live World and physical state in place while adopting a new authored material baseline and retiring old construction/history. Loading that material-only baseline later cannot restore omitted temperature, velocity, reaction energy, solver state or live body state. Consult [the actual save contracts](level-saves-and-replay.md) and [saving walkthrough](../operations/workbench-saving.md). The owner did not require serialization of the entire Undo stack or advanced cross-version compatibility for every old map. Flatten may recover useful material layouts across versions, subject to material identity and container compatibility. It does not guarantee interpretation of every future/old ID. Material Flatten is also distinct from merging Strata's visual/semantic layers.


### Rank 2: operations/workbench-first-session.md — Your first Workbench session > Save what you mean

Document: Your first Shared Workbench session
Path: operations/workbench-first-session.md
authority: current-documentation
document-kind: guide
status: Current
scope: A small paused material authoring tutorial with simulation, saving and fresh-session reconstruction
canonical-for: [workbench-first-session]
last-reviewed: 2026-11-24
Section: Your first Workbench session > Save what you mean
Choose the appropriate action: | You want to retain… | Action | | --- | --- | | The authored container and original material placement | **Save start**; later simulation is not folded into ordinary Save. | | The material arrangement you can see after simulation | **Flatten / Bake History…**, confirm the history discard, then **Save start**. | | Exact velocities, temperatures, tick and actor motion | Ordinary authored saving does not provide this. | Flatten preserves the live World while replacing the authored material baseline. It clears earlier construction and Undo/Redo history, and **does not save by itself**. See [Saving authored worlds](workbench-saving.md) before using it on valuable work.


### Rank 3: operations/workbench-saving.md — Saving authored worlds > What each action means

Document: Saving authored worlds and Flatten history
Path: operations/workbench-saving.md
authority: current-documentation
document-kind: guide
status: Current
scope: Ordinary Workbench Save and Load, generated starts, material-only Flatten, recovery and persistence limits
canonical-for: [workbench-saving-user-guide]
last-reviewed: 2026-11-24
Section: Saving authored worlds > What each action means
| Action | Preserved or changed | | --- | --- | | **Save start** | Saves the current authored recipe/baseline, acknowledged construction edits and supported actor/equipment configuration. | | **Load start** | Reconstructs that authored scene with initial material/physical state. A generated start first opens a verified preview; confirm **Install into workbench** to replace the current map. | | **Restore start** | Rebuilds the current authored start; later free simulation is discarded. Observe any refusal on generated/flattened failed owners. | | **Reset selected [R]** | Resets the selected actor through its current control path; this is not a global file load. | | **Flatten / Bake History…** | Captures the current native stored material plane as a new authored baseline and discards prior construction/Undo history. The live World continues. | | **Menu [F2] / exit** | Ends the session. Saving is explicit. |


### Rank 4: operations/workbench-art.md — Art Workbench > Stop, Hide and native results

Document: Art Workbench practical guide
Path: operations/workbench-art.md
authority: current-documentation
document-kind: guide
status: Current
scope: Direct drawing and configured provider use, native result handling, session lifetime and private traffic
canonical-for: [workbench-art-user-guide]
last-reviewed: 2026-11-24
Section: Art Workbench > Stop, Hide and native results
**Stop** cancels pending HTTP/capture and scheduled turns, invalidates the request generation and requests the native executor to stop. A native slice already executing can finish at its boundary. A reported **partial** result can therefore have changed the canvas. Read the confirmed count and use available Undo; do not assume cancellation rolled everything back. Closing the Art window **hides** it. It does not mean Stop, save, or end of the Workbench session. Reopen **Art batches** to inspect the same session. For Undo/Redo, Stop first and wait for model, capture, drawing, deferred manual strokes and receipt processing to settle. Both Art and manual controls use the same chronological history. ```mermaid flowchart TD A["Direct JSON or model response"] --> B["Parse and validate drawing"] B --> C["Queue native work"] C --> D["Native slice and stored-material readback"] D --> E["Completed or partial receipt"] E --> F["History and visible result"] S["Stop"] --> C S --> E ``` **Queued is admission, not applied success.** A result from before Reset, Load or World replacement is stale and must not draw into the new scene. Source failures, rejection and missing acknowledgements are not success receipts.


### Rank 5: decisions/2026-11-14-owner-authoring-intent.md — Owner authoring and world intent — 14 November 2026 > Save, Flatten and compatibility

Document: Owner authoring and world intent — 14 November 2026
Path: decisions/2026-11-14-owner-authoring-intent.md
authority: owner-confirmed-intent
document-kind: decision
status: Approved design
scope: Direct owner clarification of product intent; implementation, qualification and execution permissions remain separate
canonical-for: [owner-clarifications-2026-11-14]
last-reviewed: 2026-11-14
Section: Owner authoring and world intent — 14 November 2026 > Save, Flatten and compatibility
**Confirmed:** saving should preserve the desired evolved material layout without unexpectedly destroying the session's Undo history. Oil painted in mid-air and allowed to settle should restart in its saved location. Acid used to damage a wall, followed by water and fire cleanup, should not reappear merely because the original construction strokes were replayed. **Confirmed:** explicit Flatten is a material-occupancy snapshot using two bytes per cell, allowing burdensome or blocking construction history to be discarded. It is not a full physical checkpoint. Normal map saves need not always flatten; richer authoring data can remain useful. Neither this clarification nor the word “save” requires persisting the entire session's Undo stack. **Confirmed:** do not promise advanced cross-version compatibility of all old maps. Flatten may provide a fallback that recovers useful material layout in newer versions. Material identity mapping and container/version handling remain engineering details. This is not a guarantee that every old simulation state or every future material ID remains interpretable. Flatten is also distinct from merging the visual/semantic layers of Strata.

## OI03: Must physical simulation be scientifically consistent even when authored effects feel better?

Canonical rank: 2

Expected facts:

- Convincing over consistent; authored alternatives welcome.
- Correctness checks and failed evidence retain scoped meanings.

### Rank 1: reference/product-intent-and-priorities.md — Product intent and priorities > Convincing physical behavior and prepared destruction

Document: Product intent and priorities
Path: reference/product-intent-and-priorities.md
authority: owner-confirmed-intent
document-kind: reference
status: Approved design
scope: Source-linked owner direction and preserved preferences; implementation, qualification and execution permission remain separate
canonical-for: [owner-intent, product-priorities, preserved-material-feel]
last-reviewed: 2026-11-24
Section: Product intent and priorities > Convincing physical behavior and prepared destruction
**Approved principle:** “convincing>consistent.” Authored effects, bounded approximations, selectable behaviors, compliant joints and assistance can improve appearance, feel, performance and creative possibility. Representative scenes and continued owner evaluation matter. This preference does not turn failed measurements into passes or excuse data loss, unsafe ownership or false receipts. **Desired outcome:** cutting or blasting coherent pieces loose so that they move, roll or topple is useful without first solving automatic whole-building structural stability. “Prepare then declare,” with authored break conditions and piece sizes, is an exploratory suggestion. A fracture piece need not equal a storage chunk; no algorithm or universal fragment size was selected by that suggestion. The earlier cutter experiments retain their pauses and results within their own scope. The current ObjectShard successor is identified in the [candidate register](status-and-roadmap.md#active-candidates-and-integration-boundaries). The source of intent is the [physical-character clarification](../decisions/2026-11-14-owner-authoring-intent.md#physical-character-and-destructible-structures), not an obsolete requirement copied from an abandoned branch.


### Rank 2: decisions/2026-11-14-owner-authoring-intent.md — Owner authoring and world intent — 14 November 2026 > Physical character and destructible structures

Document: Owner authoring and world intent — 14 November 2026
Path: decisions/2026-11-14-owner-authoring-intent.md
authority: owner-confirmed-intent
document-kind: decision
status: Approved design
scope: Direct owner clarification of product intent; implementation, qualification and execution permissions remain separate
canonical-for: [owner-clarifications-2026-11-14]
last-reviewed: 2026-11-14
Section: Owner authoring and world intent — 14 November 2026 > Physical character and destructible structures
**Confirmed principle:** “convincing>consistent.” Deliberately authored effects, approximations and selectable behaviours are desirable for appearance, art, feel, feasibility, significant performance savings and interesting possibilities. The owner does not regard scientific parameter sweeps as the primary way to judge feel at this stage. Representative scenes and continued owner evaluation matter. This does not retroactively make a failed experiment pass. **Confirmed outcome:** cutting or blasting coherent pieces loose so that they move, roll or topple is valuable. Full building structural-integrity analysis is not a prerequisite; deliberately rigged collapses can be useful. **Exploratory owner suggestion:** “prepare then declare,” using authored chunk sizes and break conditions for predictable detachment. This is a promising mechanism to investigate, not a selected algorithm. A fracture piece need not equal a storage chunk. Native ownership/ACK preparation is a separate concern. **Engineering interpretation, not a new owner dictate:** correctness and targeted performance checks remain useful for data loss, ownership and specific technical claims. Historical scientific campaign thresholds should not silently become universal product-feel requirements.


### Rank 3: operations/water-hybrid-pressure-extension-programme.md — Water hybrid, saturated-head and compartment-pressure extension programme > Relationship to #49 and #45 > #45 is no longer treated as an inevitable pressure implementation

Document: Water hybrid, saturated-head and compartment-pressure extension programme
Path: operations/water-hybrid-pressure-extension-programme.md
authority: current-documentation
document-kind: design
status: Planned
scope: Parallel/extension research for deep-Water bulk response, generic Rapier↔cellular coupling, bounded solided-Water sheet proofs, saturated-head requirement reassessment, lumped gas regions and optional decompression events; no production architecture adoption
canonical-for: [water-hybrid-pressure-extension-programme]
last-reviewed: 2026-11-24
Section: Water hybrid, saturated-head and compartment-pressure extension programme > Relationship to #49 and #45 > #45 is no longer treated as an inevitable pressure implementation
#45 remains the existing owner of the saturated-head architecture question, but its implementation decision must consume the extension evidence before assuming a new head/pressure carrier is necessary. The corrected communicating-head fixture should be treated as an explicit physical control whose boundary assumptions are stated. In particular, equal free-surface levels are not a universal target when the gas volumes above the liquids are sealed at different pressures. With the corrected #49 control and the relevant hybrid evidence, the acceptable #45 dispositions include: - the hybrid mechanism supplies enough intended deep-release behavior and no additional saturated-head mechanism is justified; - #45 remains necessary, but only under explicit vented/open-head boundary assumptions; - a bounded Water head mechanism is still valuable while sealed-space behavior is deliberately outside scope; - compartment pressure must become an explicit optional boundary condition before a sealed-head fixture has a meaningful target; - the generic feature is not worth its complexity for the intended game domain, and rare set-piece effects such as a rising-water chase are better authored with explicit material sources/sinks/spawners. A no-go/defer is a legitimate architecture result. Do not implement #45 merely because the issue exists.


### Rank 4: reference/level-saves-and-replay.md — Level saves and exact replay > Authored Save and physical continuation

Document: Level saves and exact replay
Path: reference/level-saves-and-replay.md
authority: current-documentation
document-kind: contract
status: Current
scope: Authored Workbench starts and material-only Flatten, CYSD1 finite-level exchange, native CYPS2–5 continuation, Wave save refusal and remaining full-application replay gaps
canonical-for: [cysd1-level-format, save-import-export, replay-persistence]
last-reviewed: 2026-11-24
Section: Level saves and exact replay > Authored Save and physical continuation
Ordinary Workbench **Save start** writes the acknowledged authored setup, generated recipe or flattened material baseline, with its supported ordered edits and actor/equipment configuration. Loading reconstructs that starting scene. It does not restore the exact next simulation tick, live actor poses or momentum, solver queues, pending input, Undo/Redo stacks or the Art conversation. Pending native edits and owner transactions must settle before Save is admitted; the save file is not a queue checkpoint. Flatten captures stored material IDs from the evolved World, then changes the authored baseline without resetting that live World. A later Save persists the baseline; reopening initializes the materials and actors again. Complete physical continuation would additionally need the applicable native solver state and all host-owned future-affecting state. Even supported native CYPS exports omit Rapier and other host state, and Wave refuses exact physical save. See the [practical save guide](../operations/workbench-saving.md), [`shared_workbench.gd::save_setup`](../../godot/scripts/shared_workbench.gd) and the [current native versions](#current-native-physical-state-versions).


### Rank 5: reference/invariants.md — Architectural and simulation invariants > Physical actor invariants

Document: Architectural and simulation invariants
Path: reference/invariants.md
authority: current-documentation
document-kind: contract
status: Approved design
scope: Stable review IDs with current enforcement, known exceptions and approved requirements; this register is not a test-result ledger
canonical-for: [invariant-register]
last-reviewed: 2026-11-24
Section: Architectural and simulation invariants > Physical actor invariants
For the [Workbench composition candidate](../systems/workbench-actor-composition.md), inspection never grants human producer authority. Source switching uses existing takeover cancellation and generation fences without reconstructing the body. Eight logical slots, eight prepared parts per actor and 64 response bodies/mask proxies are separate bounds; equipment remains reserved after release. Complete validation and prepared adoption precede changing the applied authored map. Contract: [articulated actors](../systems/physical-actor-rigs.md), [physical commands](interfaces-and-message-contracts.md#physical-actor-control-and-effects). Sources: [session](../../godot/scripts/physical_actor_session.gd), [runtime](../../godot/scripts/physical_actor_rig.gd), [effects](../../godot/scripts/physical_actor_effects.gd), [equipment owner](../../godot/scripts/physical_usable_equipment.gd), [physical usable runtime](../../godot/scripts/physical_usable_runtime.gd). Focused catalogue, Rapier, session, effects and integration runners detect the listed boundaries; execution evidence remains separately dated. | ID | Status and narrow claim | |---|---| | RIG-001 | Current: main-thread Rapier owns every live part/joint; the cellular owner receives copied values and alone writes native materials | | RIG-002 | Current: physical actor graphics use actual declared rectangle/circle collider dimensions and published transforms; authored leg, rotor and held parts are physical bodies; SetP circles explicitly retain conservative square native masks | | RIG-003 | Current: installation checks at most eight actors, eight parts per actor including held objects, and 64 total coupled bodies before activation | | RIG-004 | Current: human, demo and policy producers use one normalized action path; run/actor/epoch/sequence/issued-observation leases prevent stale authority from controlling a replacement | | RIG-005 | Current: cancellation clears stored launch intent and pending effects without interpreting it as charged release or deleting physical velocity | | RIG-006 | Approved and Current authored policy: bounded gyro assistance, approximate slides and controlled flex/play are permitted; finite gyro momentum and exact mechanical joint emulation are not required | | RIG-007 | Current: physical command/environment version 2 is distinct from sampled actor rows and Thunderbowl v1; no tag, metal, neural-service or reward equivalence is implied | | RIG-008 | Current: new desktop assemblies wait for matching reset/epoch and installed initial terrain; a retired world's cached geometry cannot release the fence | | RIG-009 | Current: worker effect batches are admitted wholly within eight pending requests or explicitly refused; bounded copied admission diagnostics are separate from actual-cell receipts | | RIG-010 | Current: ACT-005 equipment is one real coupled part whose body ID survives held, released, fixed, deployed and nearby pickup transitions; selection/lifecycle epochs revoke superseded authority without teleporting the part or erasing momentum | | RIG-011 | Current: physical usable requests carry run, actor, generation, equipment epoch, instance, body and request identity; one pending request per actor includes extracted work, and a whole batch is admitted within eight slots or explicitly refused | | RIG-012 | Current: physical source clearance and target protection use actual

## OI04: Does prepared declared destruction require automatic whole-building stability and storage-sized chunks?

Canonical rank: None

Expected facts:

- Prepared declaration exploratory; blast/cut rolling pieces desired.
- Fracture pieces are not specified as storage chunks.

### Rank 1: reference/product-intent-and-priorities.md — Product intent and priorities > Convincing physical behavior and prepared destruction

Document: Product intent and priorities
Path: reference/product-intent-and-priorities.md
authority: owner-confirmed-intent
document-kind: reference
status: Approved design
scope: Source-linked owner direction and preserved preferences; implementation, qualification and execution permission remain separate
canonical-for: [owner-intent, product-priorities, preserved-material-feel]
last-reviewed: 2026-11-24
Section: Product intent and priorities > Convincing physical behavior and prepared destruction
**Approved principle:** “convincing>consistent.” Authored effects, bounded approximations, selectable behaviors, compliant joints and assistance can improve appearance, feel, performance and creative possibility. Representative scenes and continued owner evaluation matter. This preference does not turn failed measurements into passes or excuse data loss, unsafe ownership or false receipts. **Desired outcome:** cutting or blasting coherent pieces loose so that they move, roll or topple is useful without first solving automatic whole-building structural stability. “Prepare then declare,” with authored break conditions and piece sizes, is an exploratory suggestion. A fracture piece need not equal a storage chunk; no algorithm or universal fragment size was selected by that suggestion. The earlier cutter experiments retain their pauses and results within their own scope. The current ObjectShard successor is identified in the [candidate register](status-and-roadmap.md#active-candidates-and-integration-boundaries). The source of intent is the [physical-character clarification](../decisions/2026-11-14-owner-authoring-intent.md#physical-character-and-destructible-structures), not an obsolete requirement copied from an abandoned branch.


### Rank 2: reference/invariants.md — Architectural and simulation invariants > Hierarchical generation invariants

Document: Architectural and simulation invariants
Path: reference/invariants.md
authority: current-documentation
document-kind: contract
status: Approved design
scope: Stable review IDs with current enforcement, known exceptions and approved requirements; this register is not a test-result ledger
canonical-for: [invariant-register]
last-reviewed: 2026-11-24
Section: Architectural and simulation invariants > Hierarchical generation invariants
Contract: [hierarchical places and routes](../systems/procedural-hierarchical-generation.md). Source: [semantic API](../../native/include/cybersand/generation_grammar.hpp), [planner](../../native/src/generation_grammar.cpp), and [generator](../../native/src/world_generation.cpp). | ID | Status and narrow claim | |---|---| | GRAMMAR-001 | Current: semantic region/rule/slot identities exclude storage-chunk size, request order, recipe revision and finite window; a region-grid-size change explicitly changes identity | | GRAMMAR-002 | Current: region-contained features may cross storage chunks; canonical boundary/socket ownership and explicit routes do not require either owning chunk to have been generated | | GRAMMAR-003 | Current: hard layout requirements precede preferences; bounded priority search may reject a feasible alternative rather than silently relaxing a constraint | | GRAMMAR-004 | Current: omitted features require authored fallback receipts; required neighbors and support are rechecked after omission | | GRAMMAR-005 | Current: finite curve order controls placement/inspection but never substitutes for explicit route edges, matching sockets or final-cell clearance | | GRAMMAR-006 | Current: exported geometry is immutable declared context; semantic planning and typed fields do not read partial raster output or live World state | | GRAMMAR-007 | Current: final hard material overrides preserve authority and can fail a route report; geometric clearance is qualified for the declared floating square profile, not an actor/controller | | GRAMMAR-008 | Current: compile/budget failure publishes no partial plan, material or diagnostic packet; semantic inspection does not grant World admission or streaming authority | | GRAMMAR-009 | Current: final support qualification is separate from route success; each declared floor/ceiling/wall check needs at least one final Solid contact and reports partial missing contacts without claiming gravity stability or apparatus preservation |


### Rank 3: architecture/inertial-cellular-v1.md — Inertial cellular reference > Why does IN require radius three?

Document: Inertial cellular reference
Path: architecture/inertial-cellular-v1.md
authority: current-documentation
document-kind: reference
status: Current
scope: Current-main Water and Brine inertial reference, retained integer momentum, whole-cell admission, carrier ownership, radius and state costs; source-bound native/application evidence remains distinct from scientific comparison and human acceptance
canonical-for: [inertial-cellular-v1-brine, inertial-cellular-v1-water]
last-reviewed: 2026-11-24
Section: Inertial cellular reference > Why does IN require radius three?
Travel writes reach at most two cells per axis: after saturation and nonnegative damping |v|≤32 and |accumulator|≤15, so division by16 produces at most two unit moves. Eligibility is rechecked before each actual step. At most one extra neighborhood probe occurs after or alongside a final travel position. Starting vy32/ay15 reaches y+2 and U7 reads y+3; a contact-side query can similarly reach x±3. Shared powder-exchange Stone bracing inspects one further neighbor of a target within the same radius-three envelope. Brine does not execute the Water carrying stencil. Absent storage reads as Empty on the exclusive serial owner path, as in Current cellular motion. Eligibility queries allocate nothing; an actual serial move uses the shared destination allocator and its explicit capacity/failure contract. Phased jobs retain the prepared-domain guard and never allocate missing storage themselves. Reserving Empty chunks must not change the IN motion tuple at positive or negative chunk seams. An IN World therefore explicitly requires `maximum_rule_radius>=3`. The existing scheduler validates radius≤half an even core, prepares neighbor chunks, and separates same-phase expanded domains. Candidate/control comparisons must use identical admitted execution geometry; the protected exact Current preset retains radius2. Native boundary tests exercise signed coordinates, core8/core64, chunk seams, observed read3/write2 reach, no prepared tick allocation and actual four-worker execution. Configured workers and observed task participants are separate `TickStats` values. The Water successor above adds its own complete carrying/packing proof, actual `maximum()` quantity, coherence, direct-ingress refusal and existing normalization preparation. The historical radius3 Brine proof alone never qualified that mapping.


### Rank 4: systems/explore001-generated-playable-maps.md — EXPLORE-001 — GEN-007 → Playable Workbench > Ordinary workbench workflow > Explicit first-version limits

Document: EXPLORE-001 generated playable starting maps
Path: systems/explore001-generated-playable-maps.md
authority: current-documentation
document-kind: contract
status: Current
scope: GEN-007 final play plane to existing prepared finite shared-workbench World
canonical-for: [generated-playable-map-admission, generated-playable-map-persistence]
last-reviewed: 2026-11-24
Section: EXPLORE-001 — GEN-007 → Playable Workbench > Ordinary workbench workflow > Explicit first-version limits
- Finite dimension 512, 1024 or 2048 on each side (square maps in the dialog); nonnegative destination coordinates, bounded global source range. - Current Workbench setup allows up to **32,768** ordered starting stamps or construction rectangles, subject to the 1 MiB envelope and native capability readback. The ordinary non-Workbench MicroScenario bound remains 4096. Generated baseline detail is **not** converted into those records. Native replay work is separately bounded to the smaller of 64×canvas cells and 32,000,000 attempted cells. Refusal preserves the prior document. [Flatten / Bake History](../operations/workbench-saving.md) can explicitly replace construction history with a stored material baseline; it is not automatic compaction or exact physical-state capture. - Source recipe document ≤1 MiB; saved manifest ≤1 MiB. Neither manifest includes the original million-cell material array. - Native semantic planes other than `play` do not become physical materials. Routine generator creation requires no editing JSON; custom files can be selected with **Choose profile file…**. - Setup-v2 names without generated manifest `format` retain their old reader. Material-baseline-v1 has its own reader. Old #402/#409 branch-format proposals are not additional current readers merely because the issue numbers appear in earlier integration notes. - A 2048² chunk profile requires up to 1024 receipts at aligned 64-cell chunks; region/profile capacity still applies. Deepworks' declared semantic plan is 1024², so a 2048² request is refused while preserving the installed map. Chunked previews now preflight the *exact* global source-chunk count, including unaligned origins, against the saved-map provenance limit of 1024 receipts. For example, a 512² request at eight-cell chunks needs 4096 receipts and is refused before allocating preview bytes or generating any source chunks; the installed native World remains unchanged. A 2048² aligned region at 64-cell chunks fits exactly 1024 receipts, but still needs its normal native, memory and source admission checks. Source material storage is one byte per cell (4 MiB at 2048²) and the preview is four bytes per cell (16 MiB); prepared/old Worlds and other staging memory coexist. Those buffer bounds are not a total-memory or responsiveness claim. <a id="qualification-commands-run-against-a-source-matched-rebuilt-native-runtime"></a>


### Rank 5: architecture/data-ownership-and-lifetimes.md — Data ownership and lifetimes > Which transitions require exclusive ownership?

Document: Data ownership and lifetimes
Path: architecture/data-ownership-and-lifetimes.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current resource owners, mutation windows, publication retirement and allocation limits; proposed resources are explicitly separated
canonical-for: [resource-ownership-and-lifetimes]
last-reviewed: 2026-11-24
Section: Data ownership and lifetimes > Which transitions require exclusive ownership?
Setup, reset, reservation, rule/configuration replacement, level export/import and World destruction must not overlap job views or producer access. Jobs may not retain a view beyond their barrier. Native pool workers never call Godot; the desktop owner only calls its exclusive adapter/value APIs. `ParallelState` constructs its complete activity buffers before binding job spans and never resizes them afterward. Its pool retires before those spans and owners. A native pool constructor that fails after starting a worker must also stop, notify and join the started prefix before mutex/condition-variable member unwind; its destructor would not run for the failed constructor. The shared cleanup helper covers that exceptional path and ordinary destruction. C API construction publishes typed refusal only after this retirement, with no worker count fallback; the existing live World remains owned by its caller. The [dated reproduction and repair](../audits/2026-10-25-water-inertial-native.md#contiguous-activity-storage-and-constructor-retirement--2026-10-25) separates the original hang, packed-storage proof and final source proof. Level export clears transient obstacles; coupling must be rebuilt before the next cellular tick. Import builds a validated candidate before replacing World. See [level saves](../reference/level-saves-and-replay.md) for the exact scope. **Approved:** future reconfiguration drains affected work before replacing storage, then resumes on a whole tick. **Planned:** active-only next buffers, buffered halos/transfers, bounded general gameplay results and serialization staging. Their sizes, retirement/full-queue policy and live-resize failure API are not implemented. Do not infer them from Current snapshot backpressure. Lifetime fixtures are linked in the [validation ledger](../reference/validation-evidence.md); the rationale remains [ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md). Sampled [granular support queries](../systems/granular-interaction-policy.md) read current cells and copied body occupancy only under this exclusive owner, outside native jobs. Their bounded neighbourhood adds no job view, cache or Rapier object.

## OI05: Should persistent areas catch up with real offline time or game time, and can transitions pause briefly?

Canonical rank: 3

Expected facts:

- Game time, occasional few-second transition acceptable, optional simulate ahead.

### Rank 1: systems/world-storage-and-interest-region.md — World storage and interest region > Approved area intent and accepted behavior

Document: World storage and interest region
Path: systems/world-storage-and-interest-region.md
authority: current-documentation
document-kind: contract
status: Current
scope: Sparse native storage, finite adapters, interest pause/resume and fresh generated-chunk admission; general persistence/reconfiguration/streaming remain separate
canonical-for: [world-storage, camera-interest-region]
last-reviewed: 2026-11-24
Section: World storage and interest region > Approved area intent and accepted behavior
The [14 November owner record](../decisions/2026-11-14-owner-authoring-intent.md#world-extent-persistence-and-time) asks for one fixed canvas plus persistent areas, with useful approximation and bounded catch-up measured in **game time**, not real offline wall time. Existing interest-region re-entry only restores current eligibility; it does not implement that catch-up. Do not turn a source limitation into a permanent rejection of the owner's desired feature, or describe an unmerged RAMCACHE evaluator as accepted. The [roadmap](../reference/status-and-roadmap.md) is the current programme route.


### Rank 2: reference/product-intent-and-priorities.md — Product intent and priorities > World extent, persistence and time

Document: Product intent and priorities
Path: reference/product-intent-and-priorities.md
authority: owner-confirmed-intent
document-kind: reference
status: Approved design
scope: Source-linked owner direction and preserved preferences; implementation, qualification and execution permission remain separate
canonical-for: [owner-intent, product-priorities, preserved-material-feel]
last-reviewed: 2026-11-24
Section: Product intent and priorities > World extent, persistence and time
**Approved:** one fixed canvas plus persistent areas loaded while travelling should cover most intended uses. Broad continuous canvases should support biomes or small towns; presentation can later disguise boundaries. Non-square/broad maps do not imply a change to the display-pixel scale. A useful simulated border around the active view, potentially extended in the travel direction, is desirable. On returning to an area, approximate headless catch-up is preferred to a visibly frozen room. Use **game time**, not elapsed real-world offline time. Occasional transitions lasting a few seconds and an optional deliberate **simulate ahead** control are acceptable. Quantized or approximate catch-up can be useful. Retained state, cross-area exchanges, safe workload budgets, activity margins and policy evolution need their own contracts. Track last accounted simulation time when an area can continue running in a border. Headless work still costs compute. Persistent-area/RAMCACHE candidates are not accepted-main guarantees merely because this intent is approved.


### Rank 3: decisions/2026-11-14-owner-authoring-intent.md — Owner authoring and world intent — 14 November 2026 > World extent, persistence and time

Document: Owner authoring and world intent — 14 November 2026
Path: decisions/2026-11-14-owner-authoring-intent.md
authority: owner-confirmed-intent
document-kind: decision
status: Approved design
scope: Direct owner clarification of product intent; implementation, qualification and execution permissions remain separate
canonical-for: [owner-clarifications-2026-11-14]
last-reviewed: 2026-11-14
Section: Owner authoring and world intent — 14 November 2026 > World extent, persistence and time
**Confirmed:** one fixed canvas plus persistent areas loaded while travelling should cover most intended uses. Broad continuous canvases should accommodate biomes or small towns; later presentation can disguise boundaries. The prepared brief interprets moving beyond “1:1 canvases” as allowing non-square/broad maps, not changing display-pixel scale. Concrete dimensions await practical work. **Confirmed:** a useful simulated border around the viewport/activity, potentially extended in the travel direction, is desirable. On returning to an area, approximate headless catch-up is preferable to a conspicuously frozen room. Use **game time**, not real-world offline time. Occasional transitions lasting a few seconds are acceptable. An optional deliberate **simulate ahead** control is desired. Approximation and quantisation can be acceptable. **Engineering questions:** retained state, bounded catch-up algorithms, activity margins, cross-area exchanges and material-policy evolution remain unresolved. Track the last simulated/accounted-for time rather than merely last visit if an area can keep simulating in a border. Headless execution still consumes compute. These observations do not authorise implementation or a large benchmark campaign.


### Rank 4: reference/status-and-roadmap.md — Status and foundational roadmap > Approved direction and unresolved choices

Document: Status and foundational roadmap
Path: reference/status-and-roadmap.md
authority: current-documentation
document-kind: reference
status: Current
scope: Accepted-main implementation, separately identified candidates, approved direction and unresolved decisions
canonical-for: [implementation-status, foundational-priorities, open-decisions]
last-reviewed: 2026-11-24
Section: Status and foundational roadmap > Approved direction and unresolved choices
The [14 November owner record](../decisions/2026-11-14-owner-authoring-intent.md) establishes paint-and-play authoring, convincing physical behavior, useful prepared destruction, live material experimentation, four-layer presentation and fixed canvases connected by persistent areas. It also specifies **game-time** catch-up, not real-world offline elapsed time. These intentions remain separate from implementation and from permission to resume a held branch. | Question | Current disposition and owning route | |---|---| | Does ordinary Save capture all evolved materials and physical state? | Authored formats and material-baseline capture have distinct semantics. Desired evolved-layout Save must not be described as complete physical continuation. [Save contracts](level-saves-and-replay.md) and [owner intent](product-intent-and-priorities.md#save-flatten-and-compatibility) preserve the difference. | | Do large scenes and busy physics remain responsive? | This is an active owner-visible problem. PUBPRES, PAINT and actor successors own their repairs; counters and hosted graphical passes do not settle playfeel. | | Can every material property be edited live? | No such general accepted contract exists. Effective consumers, specialized kernels and safe audition scope must be identified separately. | | Are rigid-body motion, cutting and chemistry fully unified? | Accepted coupling and actor tools have bounded contracts. ObjectShard owns the unmerged successor; no automatic promotion from an isolated prototype. | | Is complete replay or cross-platform physical identity available? | No general authored-save promise supplies it. Use [determinism](../architecture/determinism-and-boundary-transfers.md) and the versioned native checkpoint contracts for exact supported scopes. | | Are wider persistent worlds complete? | Fixed authored canvases are current; general residency/streaming/catch-up remain separately scoped candidate or Planned work. | | May old material source locks be updated to make validation pass? | No. Preserve frozen evidence and use the existing reviewed transition process for authorized changes. Documentation does not grant a protected-source transition. | | Is the project publicly licensed or ready for public distribution? | No project license has been selected. [License status](../../LICENSE_STATUS.md) and [third-party notices](../../THIRD_PARTY_NOTICES.md) remain authoritative. |


### Rank 5: systems/world-storage-and-interest-region.md — World storage and interest region > World size, capacity and camera interest

Document: World storage and interest region
Path: systems/world-storage-and-interest-region.md
authority: current-documentation
document-kind: contract
status: Current
scope: Sparse native storage, finite adapters, interest pause/resume and fresh generated-chunk admission; general persistence/reconfiguration/streaming remain separate
canonical-for: [world-storage, camera-interest-region]
last-reviewed: 2026-11-24
Section: World storage and interest region > World size, capacity and camera interest
**Current:** native World supports sparse signed-coordinate storage and explicit capacity limits. Ordinary demo/Web level exchange uses a1024×1024 backing; Shared Workbench has its own finite512–2048-per-axis authoring schema and fresh 2048×2048 setup. These host bounds do not limit native signed sparse coordinates. See [`workbench_setup.gd`](../../godot/scripts/workbench_setup.gd). Camera-interest filtering in the phased backend pauses excluded work and wakes newly included resident activity blocks once at tick entry, without elapsed-time catch-up. Safe live capacity expansion is **Planned**. Persistent areas with bounded game-time catch-up are approved owner direction and have separate unmerged GEN-006 candidates; this accepted baseline does not include their residency/cache manager. General sparse-world persistence and continuous streaming remain separate. CYSD1 reconstructs a finite demo level; Workbench authored starts and native CYPS have their own narrower contracts in [save and replay](../reference/level-saves-and-replay.md). **Current GEN-001/GEN-002 source:** opt-in native procedural generators can prepare complete deterministic chunks on demand, and `World::install_generated_chunk` can admit one absent chunk through the exclusive owner. The workbench generates copied previews in its own bounded cache. These additions do not supply the Deferred manager for loading/evicting simulation residents or the Planned serializer for modified sparse worlds. See [procedural generation](procedural-world-generation.md) for that implemented candidate scope, [field/mask controls](procedural-generation-fields-and-modifiers.md) for the extension, and the dated [GEN-001](../audits/2026-10-18-gen001-procedural-generation.md)/[GEN-002](../audits/2026-10-18-gen002-fields-and-aggregates.md) evidence for validation limits. A world-size target described as “twice the camera” or “2×” is a validation workload whose dimensions must be stated. It does not impose a native World limit. Camera view, selected simulation interest, resident storage capacity and the host's finite canvas are separately owned bounds. Current finite demo dimensions and reserved capacities do not define the future stored-world limit or prove that storage streaming exists. Source identity is recorded in the [checkpoint](../operations/source-checkpoint-and-recovery.md); dated execution and artifact limits are in the [evidence ledger](../reference/validation-evidence.md).

## OI06: Are Materials Lab comparison tabs and a separate Strata Theatre enough for Workbench authoring?

Canonical rank: 1

Expected facts:

- Live Workbench material audition desired.
- Four-layer Strata should be available as a Workbench option.

### Rank 1: decisions/2026-11-14-owner-authoring-intent.md — Owner authoring and world intent — 14 November 2026 > Live materials and layered presentation

Document: Owner authoring and world intent — 14 November 2026
Path: decisions/2026-11-14-owner-authoring-intent.md
authority: owner-confirmed-intent
document-kind: decision
status: Approved design
scope: Direct owner clarification of product intent; implementation, qualification and execution permissions remain separate
canonical-for: [owner-clarifications-2026-11-14]
last-reviewed: 2026-11-14
Section: Owner authoring and world intent — 14 November 2026 > Live materials and layered presentation
**Confirmed:** Materials Lab should support easy material modification and audition, including changing values in a Workbench window for dynamic/custom trials. The existing comparison tabs are appreciated; isolated comparisons alone do not fulfil the desired current-scene interaction. Which properties can apply safely at runtime remains an engineering question. **Confirmed:** the four-layer Strata Theatre presentation should be an available Workbench option. Its visual impact is important. Historical integration exclusions are not a permanent rejection; the prototype's exact clocks and cross-layer event rules are not automatically the eventual product contract.


### Rank 2: reference/product-intent-and-priorities.md — Product intent and priorities > Live materials and layered presentation

Document: Product intent and priorities
Path: reference/product-intent-and-priorities.md
authority: owner-confirmed-intent
document-kind: reference
status: Approved design
scope: Source-linked owner direction and preserved preferences; implementation, qualification and execution permission remain separate
canonical-for: [owner-intent, product-priorities, preserved-material-feel]
last-reviewed: 2026-11-24
Section: Product intent and priorities > Live materials and layered presentation
**Approved:** Materials Lab should offer approachable material modification and audition in the Workbench scene. Existing isolated comparison tabs are valuable, but they do not alone satisfy the requested current-scene interaction. Which properties have real consumers and can be changed safely remains an engineering question. Never represent an ineffective specialized-kernel property as editable physics. [Materials Lab](../operations/materials-lab-authoring.md) owns current functionality; its audition successor remains separately identified. **Approved:** four-layer **Strata Theatre** should be an available Workbench option. Historical integration exclusions are not permanent rejection. The standalone prototype's exact clocks and event links are not automatically the future Workbench contract. The [depth contract](../systems/depth-layers-and-parallax.md) owns the existing demonstration and [the candidate register](status-and-roadmap.md#active-candidates-and-integration-boundaries) identifies ordinary Workbench integration work.


### Rank 3: systems/depth-layers-and-parallax.md — Depth layers and parallax prototypes > Purpose

Document: Depth layers and parallax prototypes
Path: systems/depth-layers-and-parallax.md
authority: current-documentation
document-kind: contract
status: Current
scope: Opt-in Strata Theatre and Deepworks material-world layering, authored dimensions, foreground-derived relief and explicit interlayer events; separate from production world ownership
canonical-for: [depth-layer-prototype, parallax-prototype, quantized-relief, interlayer-events]
last-reviewed: 2026-11-24
Section: Depth layers and parallax prototypes > Purpose
res://depth_lab.tscn is an opt-in comparison host for visual and figurative depth in CyberSand. It deliberately keeps several ideas visible side by side instead of making one of them production authority. The lab is called **Strata Theatre**. Choose **Strata Theatre — layering and parallax depth lab** in the feature launcher, open `res://depth_lab.tscn` directly, or pass `-- --depth-lab` to the pinned Godot launch. The ordinary desktop sandbox also opens it with **F4**; Shared Workbench returns before that shortcut handler. This page describes the existing standalone four-layer host. The separate Workbench integration candidate is not an accepted capability of this host; its status belongs in the [current-state register](../reference/status-and-roadmap.md). [Deepworks](../operations/deepworks-exhibition.md) reuses these four material planes in a separate 1024 × 1024 exhibition host, opened with `--deepworks` or `res://deepworks.tscn`. Its sixteen districts, source programme, independent clocks and camera/painting controls belong to that guide. Strata Theatre retains its original default dimensions and controls. | View | Meaning | |---|---| | Flat | Foreground-only control. | | Quantized relief | Bounded quantized samples of the foreground material image are offset/scaled behind the source silhouette to imply thickness. | | Four layers | Four independently authored material worlds are rendered together with different scale/parallax factors. | | Hybrid | Four layers plus foreground relief, distance haze and rear-scene reflection masked by foreground liquid IDs. | | Diorama | Hybrid plus a faster near-camera foreground-derived frame and pointer-centred cutaway. | None of the presentation-only modes creates authoritative Z coordinates, colliders, hidden material mass or a second owner of the play world.


### Rank 4: operations/showcase-guide.md — Explore the showcases

Document: Explore CyberSand showcases and laboratories
Path: operations/showcase-guide.md
authority: current-documentation
document-kind: guide
status: Current
scope: Launcher navigation, distinct standalone demonstrations, genuine retained images and their limits
canonical-for: [showcase-navigation]
last-reviewed: 2026-11-24
Section: Explore the showcases
The feature launcher is a collection of distinct scenes and laboratories. Each entry has its own controls and reset behavior. **F2 returns to the launcher and closes the current session.** Save authored Workbench work before leaving it. | Launcher entry | Why open it? | Guide and boundary | | --- | --- | --- | | Development workbench | Paint, generate, place actors, run material experiments and save starts. | [First session](workbench-first-session.md); ordinary authoring front door. | | Materials Lab | Inspect effective native properties and compare candidate definitions. | [Materials Lab](materials-lab-authoring.md); candidate Worlds remain isolated. | | Player playground | Try seven movement presets on a shared course. | [Controls](../systems/player-control-playground.md); experimental handling, not physical acceptance. | | Deepworks | Explore sixteen districts with foreground/rear material exhibits and four material planes. | [Exhibition](deepworks-exhibition.md); free-camera viewer, not the ordinary actor session. | | Blacksite Nine | Traverse a continuous 3×3 industrial complex in one native world. | [Blacksite guide](blacksite-nine-demo.md); district camera changes preserve the complex. | | Neon Reliquary | Visit the machine cathedral and three district tiles below it. | [Scene guide](neon-reliquary-demo.md); switching district reconstructs that tile, not seamless streaming. | | Actor sandbox | Compare the articulated Rapier catalogue through F5. | [Physical actors](../systems/physical-actor-rigs.md); distinct from Workbench Actor Composition. | | Materials sandbox / Experiment Tower | Inspect structured native material experiments. | [Experiment Tower](experiment-tower.md). | | Liquid comparison / Wave Flow | Compare law-specific Water behavior and apparatus. | [Liquid comparison](lcb-manual-comparison-ux.md), [Wave evaluation](wave-flow-evaluation.md). | | Thunderbowl / Physical Thunderbowl | Exercise controller contracts, scripted pilots and physical equipment. | [Control reference](../systems/thunderbowl-control-reference.md); sampled virtual-tag rewards and physical lab have different scopes. | | 4LY Flight Lab | Inspect the dedicated physical drone training plant. | [Flight contract](../systems/physical-free-flight.md); calibration and handling claims are qualified separately. | | World generation workbench | Inspect generation stages and semantic authoring previews. | [Generation Workbench 2](../systems/generation-workbench-2.md); separate from the Shared Workbench generator dialog. | | Semantic depth | Compare generated refinery and cavern projections. | [Depth authoring](semantic-depth-authoring.md); four-plane semantic scene. | | Strata Theatre | Explore standalone layering, parallax and depth modes. | [Layered world contract](../systems/depth-layers-and-parallax.md); ordinary Workbench integration is a separate candidate. | The [World Art viewer](../tools/world-art-preview.md) supplies another standalone viewer/capture workflow. Its artwork dimensions are not native playable World limits. It is not an automatic import of every reference image into simulation.


### Rank 5: operations/physical-actor-programme.md — Physical actors and combined feature trials > How do I try the integrated features?

Document: Physical actors and combined feature trials
Path: operations/physical-actor-programme.md
authority: current-documentation
document-kind: design
status: Approved design
scope: Owner-authorized ACT-004 integration, retained Blacksite hull comparison and preserved 2026-10-18 actor preferences; not broad physics acceptance
canonical-for: [physical-actor-programme, combined-feature-launcher, physical-blacksite-comparison]
last-reviewed: 2026-11-24
Section: Physical actors and combined feature trials > How do I try the integrated features?
**Current implementation:** the desktop project's default scene is [`feature_launcher.tscn`](../../godot/feature_launcher.tscn). Its current first entry is **Development workbench**; **Materials Lab**, **Play session**, **Liquid comparison**, **Wave Flow**, **4LY Flight Lab** and **Semantic depth** also have explicit routes. It opens Blacksite Nine, the four showcase districts, the ordinary actor/material sandbox, sampled or physical Thunderbowl, the separate generation workbench, Strata Theatre or the [Deepworks exhibition](deepworks-exhibition.md). F2 closes the current session and returns to the launcher; unsaved edits are discarded. Explicit `main.tscn`, `-- --blacksite-nine` and `-- --showcase` entry points remain available. The separate **World generation workbench** remains an isolated authoring preview. The ordinary **Development workbench** has its own accepted **New from generator…** path, which installs native final-play materials into the live shared owner after explicit preparation. These are distinct workflows; use the [generated-map contract](../systems/explore001-generated-playable-maps.md). Deepworks uses its own four-world native material owner and camera/painting controls; it has no ordinary physical actor session or F5 picker. **Player playground** or `-- --player-playground` opens the separate human movement course; optional `--player=ID` selects a preset. It reuses physical actors for five choices and exclusively owns a native material field for two. Its controls, lifecycle and qualification are in the [player guide](../systems/player-control-playground.md). The launcher also offers four complete, reset-scoped definitions: `experimental/blacksite/sampled-baseline`, `sampled-burial-safe`, `barrel` and `ripper` (each suffix uses the same prefix). They reuse the original Blacksite rectangles, material policy and player start. The original registered definition and historical hashes remain unchanged. Loading another arm or pressing R restores the complete complex; this is a matched geometry comparison, not a transfer of ongoing physical state between representations.
