# Retrieval contexts for independent answer review

Source-backed expected facts and the complete top-five contexts follow. A canonical route hit alone is not an answer pass.

## Q01: Which exact local version do we have, and can I recover its uncommitted changes?

Canonical rank: 3

Expected facts:

- Distinguish the actual inspected local checkpoint and dirty tree from the reconstructed upstream base and historical M11 source.
- Name verified recovery coverage and limitations; a base hash or export identity does not prove current commit or backup coverage.

### Rank 1: systems/granular-interaction-policy.md — Granular interaction and sampled player policy > How does the sampled character move and recover? > REM-003 sampled-player landing response

Document: Granular interaction and sampled player policy
Path: systems/granular-interaction-policy.md
authority: current-documentation
document-kind: contract
status: Current
scope: Version 1 material capability, sampled player support, pair exchange and deterministic permeability wakes
canonical-for: [granular-support-policy, granular-pair-policy, sampled-player-collision]
last-reviewed: 2026-09-25
Section: Granular interaction and sampled player policy > How does the sampled character move and recover? > REM-003 sampled-player landing response
**Current candidate C1:** the version-1 8/9 downward and 9/9 side/upward support classification is unchanged. REM-003 source-matched characterization found that packed standing, flat traversal, representative powders and excavation release worked within their registered cases, while materially different Sand landing speeds resolved to nearly the same rigid support height with no granular response. C1 therefore changes the sampled-character response rather than retuning the shared support predicate used by REM-002 generic body bearing. On a downward sampled-player collision, impact speed below 24 cells/second causes no disturbance. From 24 through less than 72, at most one supported foot-edge grain may move; at 72 or above, at most two may move. Only the left/right contact edge is considered. A candidate grain must be a stored support-capable granular material that currently satisfies the existing packing/stability predicate. It may move exactly one cell diagonally outward/up only through the existing whole-cell conservative relocation path into real Empty storage not occupied by another transient body. Material state and temperature move with the cell and the normal wake/dirty machinery runs. Hard terrain anywhere in the sampled collision volume fails this disturbance path closed; liquids, loose/unsupported grains and ordinary resting contact likewise do not trigger it. The player still stops on the accepted support surface; C1 does not introduce character-owned material, a granular Rapier collider, a pressure/velocity field, per-cell character physics or a second body-bearing solver. The native adapter and fallback mirror the bounded operation under their existing serialized owners. The resulting grain may subsequently move under ordinary cellular rules, so the disturbance count is not a promise of permanent crater geometry. Broad generic body↔granular acceptance remains REM-004 / #83. Owner gameplay acceptance of C1 is a separate REM-003 gate and is not implied by automated tests.


### Rank 2: operations/testing-validation-and-replay.md — Testing, validation, and replay > Coupled lockstep measurement — 2026-11-06

Document: Testing, validation, and replay
Path: operations/testing-validation-and-replay.md
authority: current-documentation
document-kind: guide
status: Current
scope: Executable test selection and future gates; dated results and save format live in separate references
canonical-for: [test-inventory, test-selection, future-validation-gates]
last-reviewed: 2026-11-24
Section: Testing, validation, and replay > Coupled lockstep measurement — 2026-11-06
The [COUPLING-LOCKSTEP-001 fixture](../../godot/tests/test_coupling_lockstep.gd) compares lossless per-step body bits, consumed samples, native results and the per-tick `physical_state_hash` across fresh processes. Run without arguments, it is a short self-check: each step must apply the result of publication N−1. Run the registered measurement from a committed, clean source with materialized LFS runtimes. The runner uses a 300 s per-episode bound, the pinned Godot 4.7 paths named in the runner and WSL `Ubuntu-24.04` for Linux. ```text godot --headless --path godot --script res://tests/test_coupling_lockstep.gd python tools/lockstep/run_coupling_lockstep.py --run NEW [--hosts windows,linux] [--arms async,lockstep] [--ticks 600] [--delay-usec 0] python tools/lockstep/reduce_coupling_lockstep.py --run NEW python -m unittest discover -s tools/lockstep -p test_reduce_coupling_lockstep.py godot --headless --path godot --script res://tests/test_coupling_lockstep_semantics.gd godot --headless --path godot --script res://tests/test_coupling_lockstep_desktop.gd ``` The reducer validates the complete registered matrix and every artifact (source identity, result/log hashes, durations, tick and trace coverage, fence invariants) before deciding, and writes `reduction-v2.json`. Any validation error yields no decisions and exit 2. Its negative regressions run in Documentation CI. `test_coupling_lockstep_semantics.gd` checks pause, reset, failure and duplicate publications for the consumed-publication field. The opt-in desktop mode (amendment_002) adds two checks. `test_coupling_lockstep_desktop.gd` runs the real `main.tscn` worker and Rapier path. A default launch must leave lockstep and packing off. A child process launched with the real `--lockstep-coupling` argument must enable it. Through play, pause, a world reset and an articulated physical actor, every physics callback must publish at most one body sample. Every fenced Rapier step must apply the completion that consumed main's previous publication, and in steady play advance exactly one native tick, with no counted stale step. In the player-course MicroScenario and the Experiment Tower main must never hold while the worker reports its fence inactive, and a world reset out of the lab must restore the fence. A deliberately slow owner (600 ms per publication) must produce counted stale steps without freezing, and the fence must recover when the delay ends. Packed rotations must equal double `atan2` of the basis. Run `packed-001` with `--arms lockstep-packed --repeats 2 --ticks 1800`. Its reduction also validates `horizon-001` and requires repeat 0 of each host and worker count to equal that run's `lockstep-f64rot` arm. From amendment_002 on, the runner hashes committed blobs (not CRLF working-tree copies) and records the bridge identity. Evidence is written to uncommitted `build/coupling-lockstep/`. The sealed archive is published as the `evidence-coupling-lockstep-001-20261106` pre-release asset. Results, its hash and limits are in the [feasibility audit](../audits/2026-11-06-coupling-lockstep-feasibility.md).


### Rank 3: operations/source-checkpoint-and-recovery.md — Source checkpoint and recovery > Source, runtime and package custody

Document: Source checkpoint and recovery
Path: operations/source-checkpoint-and-recovery.md
authority: current-documentation
document-kind: guide
status: Current
scope: Actual checkout identity, recoverable source and runtime custody; historical workspace locations are evidence only
canonical-for: [source-identity, local-checkpoints, recovery-coverage]
last-reviewed: 2026-11-24
Section: Source checkpoint and recovery > Source, runtime and package custody
| Identity | Record | What it does not establish | |---|---|---| | Source | Commit, tree, branch, dirty paths and relevant file hashes | That a retained binary was built from these inputs. | | Native runtime | Artifact SHA-256/size, platform, build source and `source_inputs` in the selected provenance manifest | That current GDScript/UI or every platform was executed. | | LFS object | Committed pointer OID/size and materialized bytes | A pointer is not an executable; materialization is not runtime validation. | | Dependency | Exact Godot, godot-cpp, Rapier and toolchain locks | That an arbitrary nearby version is interchangeable. | | Test run | Executed source/local delta, command, fixture, artifact, platform, result and retained evidence | A pass for another source or for a skipped case. | | Evaluator | Package hash, full source/runtime identity and tested shipped launcher | Owner GPU playfeel or a public release license. | A runtime built at an earlier commit can remain valid after documentation changes when its recorded inputs remain exact. Do not rewrite its build-source identity. Native changes require the applicable source-matched build/publication path. Keep test-only overlays and publication-only commits distinct from the source actually compiled or executed. [Current provenance checks](current-and-historical-validation.md) and the [release guide](github-development-and-release.md) define the gates.


### Rank 4: operations/physics-characterisation-plan.md — Physics characterisation and soliding plan > Planning checkpoint validation, 2026-09-08

Document: Physics characterisation and soliding plan
Path: operations/physics-characterisation-plan.md
authority: current-documentation
document-kind: runbook
status: Planned
scope: Proposed experiments for material penetration, player support, barrel settling and reversible aggregate physics; inspection is not runtime acceptance
canonical-for: [physics-characterisation-plan, soliding-investigation]
last-reviewed: 2026-09-09
Section: Physics characterisation and soliding plan > Planning checkpoint validation, 2026-09-08
**Current documentation-only evidence:** Windows PowerShell, bundled Python 3.12 environment, source baseline and pre-existing DLL delta identified above. No physics runtime tests, rebuilds or visual acceptance were performed. The canonical owner-intent, roadmap, coupling route, indexes and corpus were updated; C05/C06 are new supplementary questions, separate from the frozen 32-question set. Ownership/API/configuration/save formats, dependencies, UI and solver implementation remain unchanged, so their implementation contracts need no edit. Executed from the source root with ordinary 10-second command timeouts: `tools/ci/check_docs.py` passed (49 documents, zero errors/warnings); `tools/ci/check_m11_consistency.py` reported 12 historical BUILD_ID hash mismatches; historical hashes were preserved. `tools/docs/retrieval_eval.py` found canonical pages in the top five for 32/32 frozen and 6/6 supplementary questions (top one: 23/32 and 5/6 respectively). C05 and C06 both route first to this plan. Manual source/answer review confirmed the player predicate and viscosity distinction; C06's first chunk alone does not explain the handoff, so its soliding subsections are needed for an adequate answer. These lexical hits are not semantic or runtime acceptance. `git diff --check` passed. Raw checker logs and retrieval JSON are retained under `C:/kybersand/validation/local/2026-09-08-physics-plan/`. This plan is a local, uncommitted documentation delta to the recoverable source baseline, not a new release or published checkpoint.


### Rank 5: reference/product-intent-and-priorities.md — Product intent and priorities > Save, Flatten and compatibility

Document: Product intent and priorities
Path: reference/product-intent-and-priorities.md
authority: current-documentation
document-kind: reference
status: Approved design
scope: Source-linked owner direction and preserved preferences; implementation, qualification and execution permission remain separate
canonical-for: [owner-intent, product-priorities, preserved-material-feel]
last-reviewed: 2026-11-24
Section: Product intent and priorities > Save, Flatten and compatibility
**Approved desired behavior:** save the intended evolved material arrangement without unexpectedly destroying the live session's Undo history. Settled Oil should reopen where it was saved; original Acid strokes should not reappear after the user has damaged and cleaned up a scene. This is intent, not a claim that ordinary current Save already captures all evolved state. **Explicit Flatten:** capture material occupancy using two bytes per cell so burdensome construction history can be discarded. Flatten is not a physical checkpoint and does not require that normal saves always flatten. The accepted implementation leaves the live World and physical state in place while adopting a new authored material baseline and retiring old construction/history. Loading that material-only baseline later cannot restore omitted temperature, velocity, reaction energy, solver state or live body state. Consult [the actual save contracts](level-saves-and-replay.md) and [saving walkthrough](../operations/workbench-saving.md). The owner did not require serialization of the entire Undo stack or advanced cross-version compatibility for every old map. Flatten may recover useful material layouts across versions, subject to material identity and container compatibility. It does not guarantee interpretation of every future/old ID. Material Flatten is also distinct from merging Strata's visual/semantic layers.

## Q02: Who is allowed to mutate the cells, and can a worker touch a Godot object?

Canonical rank: 2

Expected facts:

- Native World owns authoritative cellular state.
- Desktop Godot worker exclusively calls its adapter/value APIs; internal native workers call no Godot APIs; live scene-tree and Rapier objects remain on the allowed Godot thread.
- Web has synchronous main-thread ownership.

### Rank 1: architecture/chunk-tile-and-buffer-model.md — Chunk, tile, and buffer model > How are writes into a neighboring tile made safe?

Document: Chunk, tile, and buffer model
Path: architecture/chunk-tile-and-buffer-model.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native storage, activity, scheduling and write-domain geometry; explicit fallback and buffered distinctions
canonical-for: [spatial-scheduling-geometry]
last-reviewed: 2026-11-24
Section: Chunk, tile, and buffer model > How are writes into a neighboring tile made safe?
With the Current native defaults, each job scans a 64×64 core and may write within its core expanded by the catalogue maximum radius of two cells. `SchedulerGeometry::phase` uses global core-coordinate parity. Same-phase cores are separated enough that their expanded half-open write rectangles do not share cells; geometry rejects a radius greater than half a core. World also validates compatible chunk/core/activity alignment for its parallel path. See [geometry implementation](../../native/src/scheduler_geometry.cpp). `World::scan_rect` visits cells inside the core; an operation may touch the expanded domain only within the enforced rule radius. Every affected cell must be owned. Out-of-domain attempts are rejected by the operation's checks; they are not automatically enqueued into a transfer system. Later visits may make them eligible. General deferred boundary policies remain **Planned**. The coordinator prepares structural storage before phase dispatch. Jobs mutate cells in place and accumulate local effects; the barrier precedes deterministic metadata merge. No next-state cell array or ordinary movement-transfer record is needed for this backend. A storage or activity edge is not itself an extra physics rule. Boundary fixtures must verify that geometry changes do not introduce unintended seams; intended scan/phase order can still affect results.


### Rank 2: architecture/data-ownership-and-lifetimes.md — Data ownership and lifetimes > Who may mutate each resource?

Document: Data ownership and lifetimes
Path: architecture/data-ownership-and-lifetimes.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current resource owners, mutation windows, publication retirement and allocation limits; proposed resources are explicitly separated
canonical-for: [resource-ownership-and-lifetimes]
last-reviewed: 2026-11-24
Section: Data ownership and lifetimes > Who may mutate each resource?
**Current:** each selected cellular world has one external owner. In the ordinary desktop sandbox that is `CyberSimulationWorker`; on Web it is the main-thread controller. Native World coordinates its internal jobs. Queries, export, publication and mutation require serialization by that owner; calling a method through GDExtension does not make World generally thread-safe. Native pool workers call no Godot APIs. The desktop Godot owner may call exclusive adapter/value APIs, but must not touch live scene-tree or Rapier objects. | Resource | Owner and permitted mutation | Lifetime and pressure | |---|---|---| | `World::chunks_` and chunk cell arrays | World coordinator creates/reserves chunks; serial work or phase-exclusive jobs mutate cells | Until World/chunk destruction; construction capacity bounds growth | | Optional temperatures | Chunk owns optional SoA; owner prepares it, permitted rules/movement use it | Allocated on demand or reservation; counted tick allocations | | Activity/dirty metadata and job effects | Job-local observations, then coordinator merge after the phase barrier | Persistent chunk metadata and reusable bounded scratch; dirty bounds survive unsuccessful publication | | Delayed pair deadline | Workers report through fixed disjoint job spans into two preallocated `ParallelState` flag/deadline buffers; the coordinator reduces the earliest deadline into shared block metadata after the phase barrier and wakes it at healthy tick entry | One persistent scalar per block plus bounded scheduler scratch; buffers outlive job spans and pool, excluded blocks retain deadlines, clear/replacement discards them | | Native snapshot slots | One serialized producer writes only an unleased slot | Shared exchange state outlives its facade while leases exist; no-slot/capacity failure retains dirty state | | Desktop world, sampled character and optional actor prototypes | Godot pacing Thread after startup handoff | Worker lifetime; stopped/joined before destruction; actor session reset invalidates old input epochs | | Controlled liquid preparation candidate and token (experimental #202 source) | The exclusive native adapter owns one pending World, render exchange, final setup and copied native receipt | Final configuration precedes capture; one-use token commit checks retained state and the desktop queue-mutex request/reset/stop fence. Discard/supersession/refusal retain the applied session; [sampled owners](liquid-prepared-setup-and-receipts.md#staged-sampled-actors-and-exploratory-owners) and [desktop articulated physical owners](liquid-prepared-setup-and-receipts.md#staged-articulated-physical-owners) prepare before commit. Physical graph/space stays main-owned, frozen and permanent; copied readiness and actual initial masks bind its nonblocking continuation. Other constructors and full evidence stay open | | Live body nodes, RIDs and physics state | Main-thread Rapier bridge and PhysicsServer2D | Scene/bridge lifetime; never passed to cellular workers | | Physical actor rigs, joints and local controllers | Main-thread `CyberPhysicalActorSession`; at most eight rigs/eight total parts each | Run/actor/epoch-bound


### Rank 3: architecture/data-ownership-and-lifetimes.md — Data ownership and lifetimes > Current owner map

Document: Data ownership and lifetimes
Path: architecture/data-ownership-and-lifetimes.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current resource owners, mutation windows, publication retirement and allocation limits; proposed resources are explicitly separated
canonical-for: [resource-ownership-and-lifetimes]
last-reviewed: 2026-11-24
Section: Data ownership and lifetimes > Current owner map
Source inspection at accepted main `00cdb02f` distinguishes five kinds of ownership that are easy to conflate: | Owner | Mutable resources | Boundary rule | |---|---|---| | Native `World` | Cells, activity/deadlines, selected liquid state, native edit buffers | One serialized caller; its pool jobs mutate only admitted work domains | | `CyberSimulationWorker` | Installed native adapter, queued edits, reset state and copied publication | Adapter calls stay on this exclusive desktop owner | | Main-thread physical session | Rapier bodies/joints, controls and issued policy observations | Send copied samples/actions; accept only matching responses | | Workbench authoring controller | Applied starting document, confirmed edit ordering, Undo/Redo and material baseline | Update authored state at the operation's acknowledgement/adoption boundary | | Render consumer | CPU images, textures and presentation history | Consume immutable copied packets; rendering owns no mutable cells | Sources: [worker](../../godot/scripts/simulation_worker.gd), [Workbench](../../godot/scripts/shared_workbench.gd), [physical session](../../godot/scripts/physical_actor_session.gd), [native World](../../native/include/cybersand/world.hpp). A prepared candidate may exist privately while the installed owner remains valid. Only the explicit commit changes the active owner; a queued proposal, preview, provider answer or copied observation cannot perform that commit.


### Rank 4: reference/interfaces-and-message-contracts.md — Interfaces and message contracts > Workbench replay and genuine stage interfaces

Document: Interfaces and message contracts
Path: reference/interfaces-and-message-contracts.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current C ABI, procedural-generation C++/Godot surfaces and private packed layouts; proposed gameplay/reconfiguration contracts remain distinct
canonical-for: [public-and-adapter-interface-layouts]
last-reviewed: 2026-11-24
Section: Interfaces and message contracts > Workbench replay and genuine stage interfaces
[GEN-007](../systems/generation-workbench-2.md) adds `inspect_generation(position, plane, expected_revision, expected_fingerprint)` to `CyberWorldGenerator`. The method rejects stale caller identities and returns copied deterministic replay with native material, initial context, effective parameters, scalar/typed values, ordered masks/modifiers/aggregate decisions, semantic ancestry/constraints, plane projections, fixtures/links, precedence, proposal identity and explicit truncation/unavailable metadata. It does not read a live simulation World or imply a stored historical execution log. `stage:<name>` chunk diagnostics keep final `cells` and actual intermediate `stage_cells` separately and bind them in the native receipt. The six base names are `candidate`, `guided_candidate`, `grammar`, `modifiers`, `connectivity` and `final`. `begin_stage_region(bounds, plane, stage)`, `advance_stage_region(budget)` and `cancel_stage_region()` supply bounded private finite-region stage jobs. Plane stages also include `policy`, `base` and `projections`; a plane without the base generator rejects its unavailable source stages. Stages are sampled from the real pipeline, never from a modified final recipe. Adapter revision, native recipe/plane fingerprint, UI session/view token and owner World generation are distinct identities. Workbench comparison binds the same seed and coordinates for both recipes and rejects stale result serials. `adopt_configuration(prepared_owner, expected_revision)` transfers immutable plans only after the caller has joined the private preparation worker. It rejects null, self, unconfigured, pending or stale owners. The receiving adapter serial advances; the native recipe revision and its material/diagnostic receipt remain unchanged and are reported separately. Subsequent changes to the private owner cannot mutate the adopted plans. Neither explanation nor stage output supplies authority to install or mutate a World; existing material/semantic admission interfaces keep that responsibility.


### Rank 5: architecture/data-ownership-and-lifetimes.md — Data ownership and lifetimes > Who owns opt-in physics observations?

Document: Data ownership and lifetimes
Path: architecture/data-ownership-and-lifetimes.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current resource owners, mutation windows, publication retirement and allocation limits; proposed resources are explicitly separated
canonical-for: [resource-ownership-and-lifetimes]
last-reviewed: 2026-11-24
Section: Data ownership and lifetimes > Who owns opt-in physics observations?
**Current:** [physics diagnostics](../operations/physics-characterisation.md) allocate fixed per-job histograms when constructing the World. Each job writes its exclusive counter table; the coordinator merges after existing barriers. Counters cannot mutate authoritative cells or alter random streams. Adapter snapshots copy stored cells and aggregates at the serialized owner boundary; they expose no mutable World storage. Overflow drops observations, never work. The test-only asynchronous worker records a fixed trace from its exclusive adapter. The main thread reads that trace only after joining the worker, and continues to own Rapier. Diagnostic variants require fresh fixture construction; they are not live unsynchronized descriptor edits or representation handoffs.

## Q03: Does enabling browser threads let drawing continue while the simulation tick is still running?

Canonical rank: 4

Expected facts:

- No: Web waits synchronously for each native cellular tick.
- Pthreads parallelize native tick work; publication cadence is separate but asynchronous Web simulation/render ownership is unimplemented.
- Desktop has an asynchronous Godot worker.

### Rank 1: operations/gen008-flatten-qualification.md — Flatten / Bake History evaluation > Windows owner acceptance

Document: Flatten and Bake History qualification and owner evaluation
Path: operations/gen008-flatten-qualification.md
authority: current-documentation
document-kind: runbook
status: Current
scope: GEN-008-FLAT-001 native material-baseline qualification, source-bound Windows evaluation and separate owner graphical acceptance
canonical-for: [flatten-baseline-qualification]
last-reviewed: 2026-11-24
Section: Flatten / Bake History evaluation > Windows owner acceptance
Download the source-matched evaluation ZIP identified in the dated record or PR. Verify its SHA-256, extract the complete archive into a new writable folder with a short path, and run **Open Workbench.cmd**. Keep the included source, dependencies and qualification records together. The full package also includes the accepted Materials Lab authoring tools; its separate launcher remains available. 1. Open **New from generator…**, select a real profile and install a map. Paint several materials, erase some cells, and alternate a few manual and agent edits. 2. Run simulation long enough to move or transform material. Move an actor or let it fall, then click **Flatten / Bake History…** and confirm. Observe that the live simulation continues, actors retain their motion and no tick-zero restart occurs. The previous Undo history should now be empty. 3. Pause. Paint a distinctive new mark and erase part of the flattened map. Add a small agent mark. Undo and Redo the subsequent operations in chronological order. 4. Explicitly **Save start [Ctrl+S]** under a new name. Completely exit Godot. 5. Launch again and Load that name. The flattened material layout and subsequent acknowledged edits should return without regenerating the former profile. Actor spawns/settings reconstruct normally; transient physics from the earlier process is not expected to resume. 6. Continue painting and agent authoring, Undo/Redo those new edits, and try Restore start. Confirm ordinary input, Fill, Copy/Paste, generator preview and Materials Lab remain usable. 7. Start a longer drawing operation, attempt Flatten while it is pending, then Stop/wait for acknowledgement and retry. The refusal must explain why; no old history or existing save may disappear during a refused/cancelled preparation. Report the evaluation source SHA, ZIP SHA-256, saved name and exact steps for any failure. Automated graphical frames do not substitute for this owner interaction.


### Rank 2: reference/product-intent-and-priorities.md — Product intent and priorities > World extent, persistence and time

Document: Product intent and priorities
Path: reference/product-intent-and-priorities.md
authority: current-documentation
document-kind: reference
status: Approved design
scope: Source-linked owner direction and preserved preferences; implementation, qualification and execution permission remain separate
canonical-for: [owner-intent, product-priorities, preserved-material-feel]
last-reviewed: 2026-11-24
Section: Product intent and priorities > World extent, persistence and time
**Approved:** one fixed canvas plus persistent areas loaded while travelling should cover most intended uses. Broad continuous canvases should support biomes or small towns; presentation can later disguise boundaries. Non-square/broad maps do not imply a change to the display-pixel scale. A useful simulated border around the active view, potentially extended in the travel direction, is desirable. On returning to an area, approximate headless catch-up is preferred to a visibly frozen room. Use **game time**, not elapsed real-world offline time. Occasional transitions lasting a few seconds and an optional deliberate **simulate ahead** control are acceptable. Quantized or approximate catch-up can be useful. Retained state, cross-area exchanges, safe workload budgets, activity margins and policy evolution need their own contracts. Track last accounted simulation time when an area can continue running in a border. Headless work still costs compute. Persistent-area/RAMCACHE candidates are not accepted-main guarantees merely because this intent is approved.


### Rank 3: operations/troubleshooting.md — Troubleshooting simulation and integration > Establish the failing path first

Document: Troubleshooting simulation and integration
Path: operations/troubleshooting.md
authority: current-documentation
document-kind: guide
status: Current
scope: Symptom routing and discriminating checks; fixes require a separate implementation checkpoint
canonical-for: [symptom-routing]
last-reviewed: 2026-09-08
Section: Troubleshooting simulation and integration > Establish the failing path first
Record source/runtime identity, native versus GDScript fallback, desktop versus Web, profile, worker count and first failing tick. Use [build checks](local-build-and-validation.md) and the [evidence ledger](../reference/validation-evidence.md) to distinguish a new failure from an old result. Preserve a minimal fixture before changing behavior. A source diagnostic explains a defect; it does not approve a fix. | Symptom | Discriminating check and canonical contract | |---|---| | Web drawing stalls despite pthreads | The outer callback still waits for native work; [threading](../architecture/simulation-tick-and-threading.md) distinguishes desktop ownership | | One core dominates | Confirm backend/count, eligible jobs per phase, threshold and serial planning; [profiling](profiling-observability-and-performance.md) | | Simulation freezes after camera returns | Check failed-world status/capacity first; phased re-entry should wake new coverage once without catch-up; [storage/re-entry contract](../systems/world-storage-and-interest-region.md) | | Native tick fails or appears to continue | Both owners stop; World is quarantined and may contain partial mutations. Preserve diagnostics, then explicitly reset or replace; never retry the partial World; [tick failure](../architecture/simulation-tick-and-threading.md) | | Every other falling row is Empty | Inspect source/destination update stamps and bottom-up vacancies; [materials](../systems/materials-and-rule-kernels.md) | | Water changes while apparently settled | Compare exact mass, content hash and dirty/activity counts; full state hash advances with time; [Water](../systems/water-design.md) | | Stable cells look dithered or shimmer | Separate render animation from authority; [appearance](../systems/material-appearance-and-rendering.md) | | Water forms a heap | Identify native conserved mass versus discrete fallback, pressure bounds and sleep; preserve closed-basin fixture; [Water](../systems/water-design.md) | | Smoke fails to rise through a medium | Inspect directional exchange/target traits and activity; do not make all solids permeable; [materials](../systems/materials-and-rule-kernels.md) | | Boundary seam or worker-count divergence | Compare first divergent phase, write domain, stamps, merge effects and conserved totals in shifted/negative-coordinate fixtures; [determinism](../architecture/determinism-and-boundary-transfers.md) | | Body tunnels, traps or deletes cells | Separate stale samples, sweep limits, terrain backlog, displacement exhaustion and backend selection; [coupling](../architecture/rigid-body-and-cellular-coupling.md) | | Rapier class missing or body does not step | Run dependency preflight, then isolated automatic/manual fixtures; [Rapier runbook](rapier-2d-migration-runbook.md) | | Snapshot rejected or Image expects nonzero bytes | Record serial, rectangle, offset, stride and byte count; reject/retain until full-refresh recovery; [render handoff](../architecture/rendering-and-gameplay-bridges.md) | | Low FPS with small bridge payloads | Dirty bridge patches still end in a full RG8 GPU texture update; distinguish copy/upload/render time; [render handoff](../architecture/rendering-and-gameplay-bridges.md) | | Capacity exhausted or steady memory grows | Inspect category/use/capacity and lazy chunk/job storage; do not infer atomic rollback or zero allocations; [capacity](configuration-and-capacity-budgets.md) | | Identical saves diverge after load | CYSD1 restores level fields, not all future-affecting state; [save/replay contract](../reference/level-saves-and-replay.md) | | Unsafe Godot thread warning


### Rank 4: operations/web-threading.md — Web worker profiles and reference tests > Current profiles

Document: Web worker profiles and reference tests
Path: operations/web-threading.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Compatibility/threaded Web build and hosting, fixed worker policy, synchronous ownership, and reference-test interpretation
canonical-for: [web-worker-profiles, worker-reference-benchmark]
last-reviewed: 2026-09-08
Section: Web worker profiles and reference tests > Current profiles
[build_web.py](../../tools/build_web.py) stages the same native solver, assets, and Web controller with matching thread/no-thread Godot templates and Rapier WASM. [CyberNativeCellWorld::create_world](../../godot/native_extension/cyber_native_cell_world.cpp) resolves worker policy at world construction. | Profile | Cellular workers | Output | Ownership | |---|---|---|---| | Compatibility, default | Forced 1 | `source/build/web` | Synchronous Godot callback | | Threaded | Auto or explicit request | `source/build/web-threaded` | Same callback; phased jobs may run concurrently | Auto chooses 2/4/6 at reported logical-thread thresholds 4 and 12, including two when only one logical thread is reported. Exact settings, clamps, and the 32-prewarmed-pthread/two-Godot-worker distinction belong to [configuration](../reference/configuration-reference.md#adapter-worker-policy). Prewarmed spare threads support overlapping current/replacement/test worlds; they are not all simulation workers. Web diagnostics use `navigator.hardwareConcurrency` for the browser's reported logical count; the no-thread C runtime's fixed 1 is not physical-core detection. Neither Auto nor the reference benchmark tunes a running pool from timings.


### Rank 5: operations/testing-validation-and-replay.md — Testing, validation, and replay > Issue #2 and combined regressions

Document: Testing, validation, and replay
Path: operations/testing-validation-and-replay.md
authority: current-documentation
document-kind: guide
status: Current
scope: Executable test selection and future gates; dated results and save format live in separate references
canonical-for: [test-inventory, test-selection, future-validation-gates]
last-reviewed: 2026-11-24
Section: Testing, validation, and replay > Issue #2 and combined regressions
The same runner now also tests actual adapter re-entry at one/four workers, a desktop owner leave/re-entry sequence after drained ownership handoff, and Web controller resume. Browser `?test=1&tickfault=1` requires both `tick_failure_test.ok` and `interest_region_test.ok`; frame yields between probe world replacements let threaded browser workers recycle. Native source fixtures cover negative/core/chunk boundaries, previously sleeping blocks, overlap/disjoint moves, unchanged/equivalent/coalesced regions, neighbor wake, custom straddling geometry, conserved Water/Sand, retained temperature, 1/4/4 state-hash equality, and event/no-event capacity failure during re-entry followed by clear.

## Q04: What CPU counts does Auto choose in compatibility and threaded Web builds?

Canonical rank: 2

Expected facts:

- Compatibility forces one cellular worker.
- Auto chooses 2 for logical thread count below 4, 4 for counts from 4 through 11, and 6 from 12 upward in the threaded profile.
- Worker count does not imply concurrent Web presentation ownership.

### Rank 1: reference/configuration-reference.md — Configuration reference > Adapter worker policy

Document: Configuration reference
Path: reference/configuration-reference.md
authority: current-documentation
document-kind: reference
status: Current
scope: Exact native, adapter, fallback, presentation, and Web defaults; construction constraints and unimplemented production schema
canonical-for: [current-configuration-values, adapter-worker-policy]
last-reviewed: 2026-11-24
Section: Configuration reference > Adapter worker policy
The project setting is `cybersand/native_worker_threads=0`. `auto_worker_threads` implements the owner's 2026-09-08 policy: | Reported logical processors | Auto workers | |---|---:| | Below 4 | 2 | | 4–11 | 4 | | 12 or more | 6 | A positive explicit request is clamped to 1 through `min(32, reported logical processors)`; the adapter clamps its processor input to at least 1. Nonpositive requests take Auto. Auto can intentionally choose two on a one-processor report. Counts are resolved when constructing a world, not retuned during play. No-thread Web forces one cellular worker. Threaded Web keeps Auto and separately stages `threads/emscripten_pool_size=32` plus `threads/godot_pool_size=2` in [build_web.py](../../tools/build_web.py). Prewarmed slots are not all cellular workers. Browser UI reports `navigator.hardwareConcurrency`; it does not detect physical cores.


### Rank 2: operations/web-threading.md — Web worker profiles and reference tests > Current profiles

Document: Web worker profiles and reference tests
Path: operations/web-threading.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Compatibility/threaded Web build and hosting, fixed worker policy, synchronous ownership, and reference-test interpretation
canonical-for: [web-worker-profiles, worker-reference-benchmark]
last-reviewed: 2026-09-08
Section: Web worker profiles and reference tests > Current profiles
[build_web.py](../../tools/build_web.py) stages the same native solver, assets, and Web controller with matching thread/no-thread Godot templates and Rapier WASM. [CyberNativeCellWorld::create_world](../../godot/native_extension/cyber_native_cell_world.cpp) resolves worker policy at world construction. | Profile | Cellular workers | Output | Ownership | |---|---|---|---| | Compatibility, default | Forced 1 | `source/build/web` | Synchronous Godot callback | | Threaded | Auto or explicit request | `source/build/web-threaded` | Same callback; phased jobs may run concurrently | Auto chooses 2/4/6 at reported logical-thread thresholds 4 and 12, including two when only one logical thread is reported. Exact settings, clamps, and the 32-prewarmed-pthread/two-Godot-worker distinction belong to [configuration](../reference/configuration-reference.md#adapter-worker-policy). Prewarmed spare threads support overlapping current/replacement/test worlds; they are not all simulation workers. Web diagnostics use `navigator.hardwareConcurrency` for the browser's reported logical count; the no-thread C runtime's fixed 1 is not physical-core detection. Neither Auto nor the reference benchmark tunes a running pool from timings.


### Rank 3: operations/web-threading.md — Web worker profiles and reference tests > Build and preview

Document: Web worker profiles and reference tests
Path: operations/web-threading.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Compatibility/threaded Web build and hosting, fixed worker policy, synchronous ownership, and reference-test interpretation
canonical-for: [web-worker-profiles, worker-reference-benchmark]
last-reviewed: 2026-09-08
Section: Web worker profiles and reference tests > Build and preview
From `C:/kybersand`: ```powershell .\dev.cmd web --profile threaded .local/python/Scripts/python.exe source/tools/serve_web.py --directory source/build/web-threaded --port 8002 --open ``` While the preview server is running: ```powershell .\dev.cmd http-smoke --profile threaded --url http://127.0.0.1:8002/ ``` `dev.cmd web` builds compatibility. Use export-only only with a matching fresh side module; successful packaging does not prove source-to-binary freshness. The [build guide](github-development-and-release.md) owns exact dependency pins and unresolved CI/toolchain drift. Native/Web generated bindings stay separate. The supplied server sets COOP `same-origin`, COEP `require-corp`, appropriate WASM MIME and no-cache behavior. Threaded hosting needs a secure context (HTTPS or localhost) and cross-origin isolation. Serve the complete export, including worker JavaScript, PCK, WASM, notices and manifest. HTTP/checksum success is structural evidence; open the actual browser for execution. Local delivery is a separate explicit workflow after acceptance: `Deliver-Web.ps1 -Profile threaded` copies to `C:/cybersand/web-threaded`; compatibility uses `C:/cybersand/web`. Documenting this command does not execute delivery or remote publication.


### Rank 4: architecture/simulation-tick-and-threading.md — Simulation tick and threading > Who advances simulation on each platform?

Document: Simulation tick and threading
Path: architecture/simulation-tick-and-threading.md
authority: current-documentation
document-kind: contract
status: Current
scope: Desktop, Web and native stage ordering, fixed quanta, failure behavior and permitted thread access
canonical-for: [simulation-step-order-and-threading]
last-reviewed: 2026-11-24
Section: Simulation tick and threading > Who advances simulation on each platform?
**Current:** desktop has a dedicated Godot pacing Thread. Web advances native cells synchronously from the main-thread `_physics_process`. Native World's persistent pool is a separate layer: it parallelizes eligible cellular jobs inside either owner's tick, without calling Godot APIs. Compatibility Web forces one cellular worker; threaded Web and native Auto select 2/4/6 at reported logical-processor thresholds 4 and 12. This is startup selection, not a live adaptive policy. See [Web profiles](../operations/web-threading.md).


### Rank 5: operations/web-threading.md — Web worker profiles and reference tests > Reference benchmark and parity checks

Document: Web worker profiles and reference tests
Path: operations/web-threading.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Compatibility/threaded Web build and hosting, fixed worker policy, synchronous ownership, and reference-test interpretation
canonical-for: [web-worker-profiles, worker-reference-benchmark]
last-reviewed: 2026-09-08
Section: Web worker profiles and reference tests > Reference benchmark and parity checks
Open Web **Performance**: - **Benchmark:** supported actual worker counts from requested 1, 2, 4, 6; deterministic 480×480 and 960×960 Sand/Water worlds; ten warmup ticks then 120 measured ticks per case with deterministic replenishment. - **Stress test:** Auto at 960×960, ten warmup then 600 measured ticks. - **Cancel/Escape:** checked between ticks, with a two-minute case limit. A native tick already running must finish before cancellation. [worker_benchmark.gd](../../godot/scripts/worker_benchmark.gd) uses temporary worlds, restores the process worker setting, and compares final exported-level hashes. Reports include requested/actual workers, mean/p95/max native time, test frame intervals, moves, parallel phases, and level hash. Frame intervals include test/UI scheduling, not normal gameplay rendering. Copy results selects JSON and attempts clipboard copy; the last successful report is stored at `user://last_worker_benchmark.json`. Local commands use the same headless Godot fixture: ```powershell .\dev.cmd benchmark .\dev.cmd stress-test ``` Logs/reports go to `validation/local/<timestamp>/`. Compare native tick timings with browser tick timings, not headless versus browser frame intervals. The opt-in URL `?test=1&parity=1` additionally runs the one/four-worker four-demo probe: 30 ticks each, 120 exported-level hashes. It is also [test_web_worker_parity.gd](../../godot/tests/test_web_worker_parity.gd). Neither this nor the performance hash comparison proves complete replay state, Rapier trajectory equivalence, or all-platform equality.

## Q05: Are body physics, the player, and cellular updates ordered the same on desktop and Web?

Canonical rank: 1

Expected facts:

- No shared exact lockstep is established.
- Desktop character update precedes cells in the asynchronous owner; main-thread Rapier exchanges samples/results.
- Web applies previous results, steps Rapier, prepares the mask, ticks cells, then moves the character; pending terrain chunks gate Web advancement.

### Rank 1: architecture/simulation-tick-and-threading.md — Simulation tick and threading > Current Web owner: body, player and cellular update order

Document: Simulation tick and threading
Path: architecture/simulation-tick-and-threading.md
authority: current-documentation
document-kind: contract
status: Current
scope: Desktop, Web and native stage ordering, fixed quanta, failure behavior and permitted thread access
canonical-for: [simulation-step-order-and-threading]
last-reviewed: 2026-11-24
Section: Simulation tick and threading > Current Web owner: body, player and cellular update order
Source: [web_demo_controller `_physics_process`](../../godot/scripts/web_demo_controller.gd). 1. Return when unavailable, the menu is open or focus is lost. Set the current simulation window and allow armed painting before the pause guard. 2. Return if paused. If Rapier is active, also return while hard-terrain packets remain pending; this gates both solvers and the character. 3. Apply preceding cellular results, step Rapier, pack body state and prepare the native body mask. Without Rapier, prepare an empty mask. 4. Complete one native cellular tick. On success advance the sampled character by `1/60` second. On failure pause, open the menu and report the error. Web's callback waits for all native jobs. `_process` consumes terrain work and publishes display data at a separate cadence; a slow cellular tick can still block rendering. **Deferred:** fully asynchronous Web ownership. Desktop advances the character **before** cells; Web advances it **after** cells. Desktop does not share Web's continuous pending-terrain gate; its new articulated owners have the one-time installation fence described above. These schedules are not an equivalence guarantee; a common production order remains undecided.


### Rank 2: architecture/simulation-tick-and-threading.md — Simulation tick and threading > Current desktop worker loop

Document: Simulation tick and threading
Path: architecture/simulation-tick-and-threading.md
authority: current-documentation
document-kind: contract
status: Current
scope: Desktop, Web and native stage ordering, fixed quanta, failure behavior and permitted thread access
canonical-for: [simulation-step-order-and-threading]
last-reviewed: 2026-11-24
Section: Simulation tick and threading > Current desktop worker loop
Source: [CyberSimulationWorker `_worker_loop`](../../godot/scripts/simulation_worker.gd). 1. Latch frame state, copied body samples, reset and drained emissions under the mutex; apply selected window and Water options on the exclusive owner (`CyberSimulationWorker.apply_world_execution_settings`). While a fixed-interest MicroScenario is active, its `apply_interest()` alone writes the window flag and region. The camera window is not written first, because every selected-core change discards the derived pressure cache ([#201 region-flip record](../audits/2026-11-04-lcb201-region-flip.md)). 2. Reset if requested. Prepare body coupling, including overlap response when unpaused. Apply material emissions even while paused. 3. If unpaused, advance the sampled character by `1/60` second, then call the selected world's `simulation_tick`. 4. On success publish copied character/cellular results and eligible render updates. On failure publish stopped status with the previous valid payload; see below. 5. Advance the wall-clock deadline by `TICK_INTERVAL_USEC = 16667`. When lateness exceeds `MAX_BACKLOG_TICKS = 3` intervals, increment the overrun counter and reset the deadline to now. This discards wall-clock backlog, not World tick indices through an explicit skip operation. The main thread renders the newest immutable snapshot while this work runs. Separately, its physics callback applies the newest unapplied cellular response, steps Rapier once, batch-reads transforms/flushes queries and sends copied body state to the worker. Body and cellular timelines may lag by multiple samples; serial checks prevent duplicate application. See [main `_physics_process`](../../godot/scripts/main.gd) and [Rapier `step`](../../godot/scripts/rapier_physics_bridge.gd). **Opt-in prototype, default off (2026-11-06):** with `set_lockstep_coupling(true)` the ordinary coupling path ticks only after a body publication newer than its previous tick's. It does not wait on the wall-clock deadline. Holds poll every 100 µs and count a timeout once a hold exceeds 250 ms, but stale input is still refused. The [COUPLING-LOCKSTEP-001 fixture](../../godot/tests/test_coupling_lockstep.gd) pairs it with a main-side frame hold. Since the owner's opt-in decision (2026-11-06), `main.gd` does the same when launched with `--lockstep-coupling` on desktop: an ordinary physics frame is skipped (no Rapier step, no new publication) until the newest snapshot consumed main's last publication, and a hold over 500 ms of consecutive physics frames runs one counted stale step; a frame that skipped the decision (pause, reset) restarts the bound. Where the worker reports its fence inactive (`lockstep_fence_active` false: labs, MicroScenarios, prepared liquid), main does not hold and counts an unfenced step. The default launch keeps the asynchronous pacing above. See [coupled desktop determinism](determinism-and-boundary-transfers.md#coupled-desktop-determinism--2026-11-06).


### Rank 3: architecture/liquid-prepared-setup-and-receipts.md — Native liquid prepared setup, receipts and quantity accounting > Synchronous Physics Pit reference bodies

Document: Native liquid prepared setup, receipts and quantity accounting
Path: architecture/liquid-prepared-setup-and-receipts.md
authority: current-documentation
document-kind: design
status: Current
scope: Accepted main LCB-001 native construction contract — immutable final tuples, explicit Water normalization, prepared World ownership, typed native outcomes, native run and attempt receipts, exact quantity aggregates, physical hash/CYPS2 and source-matched Windows/Linux acceptance; application-host proof and downstream family work remain open
canonical-for: [liquid-prepared-setup, liquid-native-run-receipt, liquid-quantity-accounting]
last-reviewed: 2026-11-20
Section: Native liquid prepared setup, receipts and quantity accounting > Synchronous Physics Pit reference bodies
**Current bounded unmerged #202 source:**5d5c75ed adds explicit Exploratory **Apply & rebuild active** for the actual authored Physics Pit constructor. It uses the exact existing ordered rectangle recipe, sampled player(24,222) and three original8×14 scene templates at(124,90),(244,90),(384,90), all initially unrotated and at rest. This is a separate physical route from the four body-free demos above. Imported same-label physical saves cannot gain authored identity; other bodies/imports and generic physical MicroScenarios remain separate admission work. [Dated local evidence](../audits/2026-10-25-lcb003-synchronous-reference-body.md) records actual normal menu/panel callbacks and remaining platform limits. [`prepared_synchronous_reference_session.gd`](../../godot/scripts/prepared_synchronous_reference_session.gd) owns one copied definition/policy/options request, native token, privately frozen permanent body space and staged sampled player. Native preparation receives the actual packed initial bodies and final current view/cadence/adhesion. Its token-bound copied terrain drives bounded collider setup while at least two actual physics frames verify frozen poses. The retained World/player/body graph and presentation stay held during this preparation; no queued user edit or live graph is consumed to build the candidate. Readiness has an explicit20-second refusal bound. Construction spans main-thread frames; synchronous native runtime ownership and the Deferred asynchronous Web simulation policy do not change. Final owner serial/source/native generation, copied configuration and lifetime guards precede the same-request host observation and native retained-state commit fence. Body readiness is rechecked after the optional deterministic test barrier. Success adopts the same permanent graph/space and sampled player without fallible physics rebind; old bodies close only after native commit. Newer choices, settings, terrain/player refusal or readiness expiry discard the pending token and graph while retaining old World/player/receipt/cursors/record. Cancellation copies the actual native attempt readback; host-only refusal never invents one. Accepted Restart reconstructs the copied original recipe/selection and original poses. Current replacement or legacy import retires prepared physical identity; the source-generation tag is supplied only by actual authored construction. Known prepared Baseline retains the same actual native component/generation/ applied-receipt binding as other ordinary routes. Native-v1 qualifications15 and false native/host full matched eligibility remain. Same-policy quarantined Restart still requires shared lifecycle work; explicit Current recovery remains. Fresh local Windows proof includes32 actual held frames and three PF variants through240 synchronous native/Rapier ticks, reaching the original tank contents and consuming positive signed feedback with exact Water/gas accounting. The earlier96-tick apparatus premise is retained as failed: bodies had not reached the liquid. This is functional execution, not complete trace parity/performance, actual Wasm/visual or source-matched release qualification. Existing desktop Water Feel and IN motion/rest-contact qualifications remain separately scoped.


### Rank 4: operations/neon-reliquary-demo.md — Neon Reliquary and the city below > Presentation and ownership

Document: Neon Reliquary and the three district tiles below
Path: operations/neon-reliquary-demo.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Four authored district tiles, vertical ordering, desktop and Web selection, viewpoints, presentation and reproducible capture; no physics qualification
canonical-for: [neon-reliquary-demo, showcase-scene-authoring, showcase-presentation, showcase-district-stack]
last-reviewed: 2026-10-18
Section: Neon Reliquary and the city below > Presentation and ownership
[`CyberShowcasePresentation`](../../godot/scripts/showcase_presentation.gd) creates district/viewpoint controls and one backdrop for the accepted tile. It reads the existing accepted current/previous render textures and the existing player rectangle. It adds no native queries, mutable world image, simulation thread or cell fields. The normal material palette, emission and glow shaders remain the foreground renderer. The [backdrop shader](../../godot/shaders/neon_reliquary_backdrop.gdshader) draws a restrained distant skyline, coloured haze, shafts and sparse dust only in empty cells. Current material occupancy, unfinished previous-material transitions and the sampled player are excluded. Material paint/erase therefore updates its mask through the ordinary render publication. The atmosphere does not show through occupied glass, gas or partial Water cells; those continue using the existing material renderer. These lights and skyline silhouettes are decorative scenery, with no collision, heat or illumination authority. The backdrop is disabled for an edited definition that enables rigid bodies; the authored scene has none. The top tile keeps its original cyan atmosphere. Middle Cyberberbia adds warm rose/amber haze around the inhabited bridge; Sewertech Alley shifts toward utility teal; Industrial Underswamp uses muted green and rust-coloured haze. The selected palette derives from the accepted district identity, with the same material/player/transition mask for all four. New scene installation uses the established desktop worker acknowledgement or synchronous Web host. A pending reset or open experiment/definition modal blocks the showcase shortcut. On desktop, this also includes an open actor selector or an actor installation awaiting acknowledgement. Viewpoint popups block paint underneath them and require mouse release before paint resumes. F8 also hides the player/environment and actor launchers and dismisses their tuning panels, preserving the promised clean view. Accepted showcase installation clears ordinary sandbox actor prototypes through the existing MicroScenario transition.


### Rank 5: architecture/rigid-body-and-cellular-coupling.md — Rigid-body and cellular coupling > Development workbench physical ownership

Document: Rigid-body and cellular coupling
Path: architecture/rigid-body-and-cellular-coupling.md
authority: current-documentation
document-kind: contract
status: Current
scope: Rectangle occupancy, bounded displacement/impulses and Rapier hard contact; generalized physics and exact replay remain absent
canonical-for: [rigid-body-cellular-coupling]
last-reviewed: 2026-11-24
Section: Rigid-body and cellular coupling > Development workbench physical ownership
The accepted Shared Workbench host stages one bounded multi-body roster at a time. Each instance has one session/epoch, generation, actual mass/inertia/centre of mass, gravity, drive sample and response budget. Collision rectangles contribute to the same body's wrench. The worker owns the cellular state, checks the copied geometry and samples in the native adapter, and publishes value-only rows. The main-thread bridge rejects retired or duplicated results and checks sample age and corner travel before applying the wrench to that instance's Rapier RID. The finite canvas owns interest independently of presentation. The [workbench guide](../systems/player-control-playground.md#development-workbench-on-desktop) and [qualification record](../audits/2026-11-04-workbench-consolidation.md) distinguish authoring controls, observed behavior and unresolved review gates.

## Q06: What happens to play when a native simulation tick fails?

Canonical rank: 1

Expected facts:

- Failed ticks may advance attempted tick/epoch and mutate cells/events; there is no rollback.
- World latches failure and rejects further ticks/gameplay writes/publication; completed tick identity does not advance.
- Desktop publishes stopped status retaining its last valid payload; Web pauses/menu-reports and suppresses partial output; Rapier stays main-thread owned.
- Explicit reset/clear or validated replacement is required; accepted events are never automatically replayed and invalid replacement retains the fault.
- The Draft Waterwall adapter also contains unexpected native exceptions during edits, coupling and observations, preserves the first operation/error once, and rechecks health after assembling a publication; this does not identify the original surface-crest trigger.

### Rank 1: architecture/simulation-tick-and-threading.md — Simulation tick and threading > What happens when a tick fails or overloads?

Document: Simulation tick and threading
Path: architecture/simulation-tick-and-threading.md
authority: current-documentation
document-kind: contract
status: Current
scope: Desktop, Web and native stage ordering, fixed quanta, failure behavior and permitted thread access
canonical-for: [simulation-step-order-and-threading]
last-reviewed: 2026-11-24
Section: Simulation tick and threading > What happens when a tick fails or overloads?
fixed staggered secondary lanes, sleeping and interest rejection reduce work. Phased rejection retains activity; newly included blocks wake once without catch-up. SerialInPlace ignores the region. Transition, capacity and failed-world semantics are in [interest-region behavior](../systems/world-storage-and-interest-region.md). No general strict/gameplay switch, fidelity hysteresis or command-pressure policy exists. **Approved:** future adaptation must preserve explicit ownership, local collision and conservation, and report its policy. [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md) records that intent. Actual platform execution evidence is in the [validation ledger](../reference/validation-evidence.md).


### Rank 2: architecture/simulation-tick-and-threading.md — Simulation tick and threading > What happens when a tick fails or overloads? > Waterwall exceptions between ticks

Document: Simulation tick and threading
Path: architecture/simulation-tick-and-threading.md
authority: current-documentation
document-kind: contract
status: Current
scope: Desktop, Web and native stage ordering, fixed quanta, failure behavior and permitted thread access
canonical-for: [simulation-step-order-and-threading]
last-reviewed: 2026-11-24
Section: Simulation tick and threading > What happens when a tick fails or overloads? > Waterwall exceptions between ticks
**Current accepted Waterwall containment:** native exceptions can also arise between ticks while a Godot binding edits cells, prepares body occupancy or copies an observation. `CyberNativeCellWorld` contains standard and unknown exceptions at these public boundaries, quarantines the World and records the first operation/error once. Later getters and rejected edits cannot overwrite that cause or increment its count. Ordinary validated refusals remain refusals; they do not quarantine a healthy World. Candidate construction refusal preserves the old World, while an unexpected error after installation quarantines the new World. Successful explicit replacement clears the previous fault. The desktop owner checks native health before constructing a publication and again after copying its render, collider and status payloads. An observation that discovers a fault cannot publish a partially assembled healthy snapshot. It retains the last valid payload, pauses actors and withholds body results. Body-occupancy failures additionally record the current stage, body/proxy ID, source cell and target cell. This context is fixed-size owner state; no strings, logging or Godot calls are added to native pool workers or successful cell loops. This is provisional containment and diagnosis, not proof that the reported underwater surface-crest trigger has been identified. The Godot adapter refuses region, cadence, adhesion and spray setting changes while failed; a fresh explicit setup owns the new configuration. Extreme adapter brush centres and unrepresentable parcel coordinates refuse before arithmetic; region endpoints saturate before finite canvas clipping, preserving off-canvas viewport semantics.


### Rank 3: architecture/data-ownership-and-lifetimes.md — Data ownership and lifetimes > Failed-world ownership and recovery

Document: Data ownership and lifetimes
Path: architecture/data-ownership-and-lifetimes.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current resource owners, mutation windows, publication retirement and allocation limits; proposed resources are explicitly separated
canonical-for: [resource-ownership-and-lifetimes]
last-reviewed: 2026-11-24
Section: Data ownership and lifetimes > Failed-world ownership and recovery
**Current:** failure quarantines the existing World under its same exclusive owner. Workers drain before exception propagation; no background retry is spawned. Raw serialized queries see partial diagnostic state. Successful snapshot leases retain their bytes; failure cannot publish new cell/terrain/body payloads. Desktop retains the last valid snapshot in a new failure-status wrapper and keeps its owner thread available for reset. Web gates directly on its adapter fault. Main-thread Rapier stops on observed failure, without rewinding an earlier step. `clear()` or validated replacement abandons the failed world's events and state. Replacement candidates allocate/validate before ownership swap; see [failure contract](simulation-tick-and-threading.md#what-happens-when-a-tick-fails-or-overloads). Region setters are serialized owner operations that latch requested coverage, including while failed. Healthy tick entry applies transition wakes in the existing metadata pass; native pool jobs consume the resulting selection. No Godot or Rapier API is introduced in native workers. Failed ticks cannot apply a later region request; recovery abandons old activity before fresh setup.


### Rank 4: architecture/simulation-tick-and-threading.md — Simulation tick and threading > What happens when a tick fails or overloads?

Document: Simulation tick and threading
Path: architecture/simulation-tick-and-threading.md
authority: current-documentation
document-kind: contract
status: Current
scope: Desktop, Web and native stage ordering, fixed quanta, failure behavior and permitted thread access
canonical-for: [simulation-step-order-and-threading]
last-reviewed: 2026-11-24
Section: Simulation tick and threading > What happens when a tick fails or overloads?
**Current, chosen for issue #1:** a thrown tick latches `World::has_failed()`. There is no transactional rollback. Tick/epoch, accepted explosion edits, dirty metadata, chunk preparation and even earlier completed phases may already have changed. `tick_index()` identifies the attempted tick; `completed_tick_index()` advances only after successful execution and activity finalization. No partial `TickStats` is returned as success. See [ADR-010](../decisions/ADR-010-failed-tick-quarantine.md). Failure clears the in-progress guard after any dispatched phase has drained. Further ticks, gameplay writes, reservations and snapshot publication are rejected. Serialized reads remain diagnostic access to partial state, not a valid save or playable continuation. The last successful immutable lease remains usable. Accepted explosions apply in enqueue order at tick entry. A completed batch drains; if application itself throws, the retained batch may include applied or partial events. Neither batch is ever automatically replayed: the world cannot be retried. An explicit `clear()` discards cells, activity, pending events, masks and tick identity, retains construction options/latest requested region, and permits fresh setup. Destruction/reconstruction is the other native recovery path. No allocation failure, capacity change or camera move implicitly recovers a world. **Current desktop:** the exclusive GDScript owner checks native false, latches failure and publishes a fresh status wrapper around its previous valid publication. It withholds partial character, cell, terrain and body results, rejects new emissions and clears pending prototype emissions. The pacing thread stays alive to receive reset; main-thread Rapier stops when the failure status is observed. This is asynchronous notification, not rollback of Rapier or character work that preceded the fault. The fallback's void successful tick path is unchanged. **Current Web:** the synchronous owner pauses, opens the menu, reports restart/load recovery, and suppresses painting, ticks, terrain/render publication and further Rapier stepping while failed. Closing the menu or toggling pause cannot retry. Rapier's preceding step is not rolled back. Reset/restart or a validated saved-level replacement creates fresh activity and clears the fault; invalid import preserves it. The adapter returns `false` with first-error telemetry, zeroes unsuccessful tick statistics, exposes attempted/completed identity separately, and does not count rejected repeat calls as new failures. Its reset prepares a candidate before swap. Godot level export rejects failed state; CYSD1 replacement is level recovery, not exact replay. Region/configuration requests cannot wake or advance a failed World. Native region requests may be latched; the Waterwall adapter's stricter failed-setting admission is described below. **Rejected for this fix:** rollback, automatic retry, resuming partial state and silent event replay. **Planned separately:** state-preserving live capacity growth and complete replay. [Dated regression evidence](../audits/2026-09-08-issue-1-failed-ticks.md) separates source tests, Windows owners and browser coverage. Eligible native transport runs each tick;


### Rank 5: operations/microscenario-reference-pack.md — MS-001 reference MicroScenario pack > Flood-Control Puzzle

Document: MS-001 reference MicroScenario pack
Path: operations/microscenario-reference-pack.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Exploratory Materials Laboratory, Flood-Control Puzzle and Simulation Stress Test definitions on the shared host, with fresh-reset A/B, world-state objectives and bounded telemetry
canonical-for: [microscenario-reference-pack, materials-laboratory-readiness, flood-control-scenario, simulation-stress-test, microscenario-workbench-controls]
last-reviewed: 2026-11-11
Section: MS-001 reference MicroScenario pack > Flood-Control Puzzle
Catalogue ID `ms001/flood-control` is a compact hydraulic world with a finite reservoir, a scheduled ordinary gate removal at tick 20 and a protected generator zone. The only objective is the declared `protected-water` observation at tick 180: zero completes; any positive Water quantity fails. The untreated seed-0 control records **5,031 integer Water units** in that zone and therefore fails. Three retained acceptance witnesses preserve the exact same objective and change ordinary setup geometry only: | Witness | Physical intervention | Seed-0 protected Water at tick 180 | |---|---|---:| | `containment` | reinforce the reservoir aperture before scheduled release | 0 | | `berm` | freestanding upstream barrier across the main channel | 0 | | `diversion` | deflector plus bounded side sump routing flow away from the target | 0 | The three final native content hashes are distinct, so these are not three labels for one scripted solution state. The witnesses are test/evidence definitions, not runtime solution flags. The selectable puzzle admits ordinary paint/erase tools so a user can discover other solutions; organic edits are not silently treated as a matched benchmark input. Play, Inspect and Benchmark produce the same untreated seed-0 native content/Water state at tick 180. One-worker instrumented and four-worker observer-off runs also match. No pump, drain, flood-specific solver hook or scenario callback is added.

## Q07: Are we using Rapier or Godot physics, which version, and who advances it?

Canonical rank: 1

Expected facts:

- Rapier2D 0.35.2 single precision is the selected backend.
- The main Godot thread manually steps Rapier; workers receive values, not live physics objects.
- Both Web profiles include Rapier by default; separate dated platform evidence is required.

### Rank 1: operations/rapier-2d-migration-runbook.md — Rapier2D dependency and validation runbook > Web packaging and browser fixture

Document: Rapier2D dependency and validation runbook
Path: operations/rapier-2d-migration-runbook.md
authority: current-documentation
document-kind: guide
status: Current
scope: Current pinned backend verification and change procedure; migration history and coupling semantics are linked separately
canonical-for: [rapier-dependency-validation, rapier-packaging]
last-reviewed: 2026-10-24
Section: Rapier2D dependency and validation runbook > Web packaging and browser fixture
Both default compatibility and optional threaded exports include Rapier and Physics Pit after a real manual-step/CCD capability probe. The [builder](../../tools/build_web.py) verifies selected WASM hashes before staging and after export; the lock is their canonical home. Exported files include `godot_rapier.wasm`, `RAPIER_LICENSE.txt` and `RAPIER_THIRDPARTY.txt`. `--cellular-only` remains an explicit diagnostic path. Build/serve the selected profile using [Web threading](web-threading.md), then open a fresh URL with `?test=1&rapier=1`. Read `rapier_test` in the opt-in `cybersand-test-state` DOM node or the `WEB_RAPIER_TEST` console record. The fixture temporarily owns the test scene and returns to Neon Works; normal play URLs do not run it. Native headless execution of this scene does not establish Web WASM execution. Capture browser version, export hashes, profile/worker count and console.


### Rank 2: decisions/ADR-009-rapier-2d-rigid-body-backend.md — ADR-009: Rapier2D rigid-body backend > Why choose an explicit adapter owner?

Document: ADR-009 — Rapier2D rigid-body backend
Path: decisions/ADR-009-rapier-2d-rigid-body-backend.md
authority: current-documentation
document-kind: decision
status: Current
scope: Accepted Rapier backend/version selection, manual owner and remaining platform/physics/replay work
canonical-for: [decision-rapier2d-backend]
last-reviewed: 2026-10-24
Section: ADR-009: Rapier2D rigid-body backend > Why choose an explicit adapter owner?
The earlier proof applied delayed cellular results through scene properties. Direct PhysicsServer state avoids treating cached presentation transforms as physics truth. Manual stepping, batch active transforms and a controlled query flush make the integration order inspectable. Stable value samples preserve backend independence and keep live RIDs off cellular workers. The [threading contract](../architecture/simulation-tick-and-threading.md) owns exact desktop/Web order. Desktop coupling is asynchronous; Web sequences both solvers on the main thread. Fully asynchronous Web ownership is **Deferred**. Neither path proves complete coupled replay merely by using a dependency advertised as deterministic.


### Rank 3: architecture/simulation-tick-and-threading.md — Simulation tick and threading > Current Web owner: body, player and cellular update order

Document: Simulation tick and threading
Path: architecture/simulation-tick-and-threading.md
authority: current-documentation
document-kind: contract
status: Current
scope: Desktop, Web and native stage ordering, fixed quanta, failure behavior and permitted thread access
canonical-for: [simulation-step-order-and-threading]
last-reviewed: 2026-11-24
Section: Simulation tick and threading > Current Web owner: body, player and cellular update order
Source: [web_demo_controller `_physics_process`](../../godot/scripts/web_demo_controller.gd). 1. Return when unavailable, the menu is open or focus is lost. Set the current simulation window and allow armed painting before the pause guard. 2. Return if paused. If Rapier is active, also return while hard-terrain packets remain pending; this gates both solvers and the character. 3. Apply preceding cellular results, step Rapier, pack body state and prepare the native body mask. Without Rapier, prepare an empty mask. 4. Complete one native cellular tick. On success advance the sampled character by `1/60` second. On failure pause, open the menu and report the error. Web's callback waits for all native jobs. `_process` consumes terrain work and publishes display data at a separate cadence; a slow cellular tick can still block rendering. **Deferred:** fully asynchronous Web ownership. Desktop advances the character **before** cells; Web advances it **after** cells. Desktop does not share Web's continuous pending-terrain gate; its new articulated owners have the one-time installation fence described above. These schedules are not an equivalence guarantee; a common production order remains undecided.


### Rank 4: architecture/simulation-tick-and-threading.md — Simulation tick and threading > Physical actor scheduling

Document: Simulation tick and threading
Path: architecture/simulation-tick-and-threading.md
authority: current-documentation
document-kind: contract
status: Current
scope: Desktop, Web and native stage ordering, fixed quanta, failure behavior and permitted thread access
canonical-for: [simulation-step-order-and-threading]
last-reviewed: 2026-11-24
Section: Simulation tick and threading > Physical actor scheduling
**Current ACT-004/ACT-005 desktop:** live bodies, joints and [`CyberPhysicalActorSession`](../../godot/scripts/physical_actor_session.gd) stay on the main thread. The owner installs a complete physical assembly with a new epoch for the selected reset. The sandbox can create it while reset is pending; scenario installation waits for acknowledgement. Before its first step, the host requires the matching reset acknowledgement and actor epoch, the current hard-terrain revision and an empty collider-installation queue. An early Play request cannot release this initial terrain fence. Subsequent terrain changes keep the desktop's existing bounded asynchronous installation. The worker binds retained geometry to its physical epoch, refreshes full/reset publications and invalidates the cache when replacing a scenario. Equal revision numbers in different worlds do not authorize reuse of the previous geometry. The physics callback admits permitted input, applies matching cellular feedback, advances bounded actor actuation, manually steps Rapier, reads the resulting parts and publishes their copied states with drained usable requests. Equipment poses, muzzle directions, generations and body states enter the worker together through `set_physical_usable_state`; the worker never obtains a Rapier object. Demo decisions run every six physical ticks from copied actor views collected before any demo output is submitted. The internal [4LY flight profile](../systems/physical-free-flight.md) reuses this main-thread owner and requires a 1/60-second actuation step. Its pure controller produces bounded force/torque from own velocity/attitude before the shared Rapier step. The rig owns a constant-force/torque channel for that one integration; `Session.complete_step` calls `Rig.complete_step` to clear the channel after Rapier advances. Cancellation clears unconsumed force immediately. Copied post-step motion and completed-step history remain distinct from a prepared actuator request/receipt. A session containing 4LY binds preparation/completion to the bridge's actual manual-step counter: duplicate preparation or no-step completion is refused, and unexpected physical steps produce a sticky session fault requiring replacement. Cancellation after physics preserves the original completed receipt even if producer ownership changes before accounting. The initial 4LY demo emits neutral conformance requests at the existing six-tick decision cadence. Invalid cadence, cancellation or expiry removes actuation authority, rather than clamping a different step into the flight contract. No new cellular worker, body solver or independent world clock is introduced. The desktop worker prepares the native body mask before consuming copied usable effects under exclusive cellular ownership. ACT-005 validates the captured physical source against the current equipment identity, lease and native body mask, charges source/part-mask queries against the usable work budget, and applies tools, projectile sweeps or fixed processor work before the material tick. It then advances materials when unpaused and publishes usable readback, request receipts and body responses with the actor epoch. Matching accepted, consumed


### Rank 5: systems/actor-control-prototypes.md — SetA actor controls and legacy policy compatibility > Who owns actor state and collision?

Document: SetA actor controls and legacy policy compatibility
Path: systems/actor-control-prototypes.md
authority: current-documentation
document-kind: contract
status: Current
scope: Original SetA Runner, Skimmer and Crawler motors and version-1 policy compatibility; the actor-rigs contract owns additional sets and version-2 actions
canonical-for: [actor-control-prototypes, actor-policy-input-v1]
last-reviewed: 2026-10-18
Section: SetA actor controls and legacy policy compatibility > Who owns actor state and collision?
**Current:** the desktop simulation worker owns the prototype actors and advances their movement alongside the sampled-player stage, outside internal native jobs. The main thread owns keyboard/UI input and drawing. It sends copied value commands and consumes copied actor publications; it never reads a live worker actor or calls World queries for a policy. Each model uses the existing sampled character's **8 by 14 cell** rectangle. Movement checks bounded increments against current material-aware support and body occupancy under the same exclusive World owner. The prototype does not create a scene-tree physics node or native job per actor. Rapier objects stay on the main thread and retain their existing generic coupling contract. Runtime enclosure is distinct from spawn validation. A prototype may be immobilized by material entering its occupied space; movement rules must not silently relocate it through terrain. Explicit reset/spawn recovery is a separate bounded operation. The existing ordinary sampled-player recovery behavior still belongs to [PCHAR and the granular policy](granular-interaction-policy.md). Crawler clamber requires clearance throughout its admitted vertical path and a supported destination. A free endpoint alone is insufficient: a low ceiling or intervening obstruction must reject the traversal. The fixed maximum clamber height bounds the candidate search and preserves a clear limit to that mechanic.

## Q08: When a crate moves across sand, do we erase its old pixels and put them back?

Canonical rank: 2

Expected facts:

- No: the rectangle proof builds a separate sampled obstacle projection.
- Movable overlap cells use bounded ordered ejection; unresolved cells remain and are counted.
- General fracture and particle fallback are not Current.

### Rank 1: decisions/ADR-007-rigid-body-cellular-coupling.md — ADR-007: Separate rigid-body occupancy coupling > Why not remove and restore body pixels?

Document: ADR-007 — Separate rigid-body occupancy coupling
Path: decisions/ADR-007-rigid-body-cellular-coupling.md
authority: current-documentation
document-kind: decision
status: Current
scope: Accepted independent body representation and value-data coupling; rectangle proof is not generalized physics
canonical-for: [decision-separate-rigid-body-occupancy]
last-reviewed: 2026-09-09
Section: ADR-007: Separate rigid-body occupancy coupling > Why not remove and restore body pixels?
Temporarily erasing a crate's old pixels while simulating sand would expose false Empty space. Restoring its transformed pixels cannot undo all movement through that space and leaves overwriting ambiguous. Separate occupancy lets cellular rules see a stable body without transferring ownership of its material or physics state. A mask alone is insufficient for the complete interaction: material impacts, displacement and approximate pressure must also affect the body. Ordered observations make that feedback explicit and testable without workers calling PhysicsServer2D. Hard terrain contact is solved by Rapier rather than duplicated by delayed cellular correction.


### Rank 2: architecture/rigid-body-and-cellular-coupling.md — Rigid-body and cellular coupling > When a crate moves through sand, are its pixels erased and restored?

Document: Rigid-body and cellular coupling
Path: architecture/rigid-body-and-cellular-coupling.md
authority: current-documentation
document-kind: contract
status: Current
scope: Rectangle occupancy, bounded displacement/impulses and Rapier hard contact; generalized physics and exact replay remain absent
canonical-for: [rigid-body-cellular-coupling]
last-reviewed: 2026-11-24
Section: Rigid-body and cellular coupling > When a crate moves through sand, are its pixels erased and restored?
**Current:** native World owns cellular materials; Rapier2D owns independent rigid bodies. Bodies are never erased from/restored into the material array. `CyberNativeCellWorld` projects copied rectangles into a separate transient body-ID field. Sand, liquids, Smoke, painting and the sampled character read that endpoint field as occupied. The retained three 8×14 reference bodies are drawn through shader transforms. ACT-004 instead draws each articulated part from its actual collider and copied Rapier transform; body colour is not stored in the cell texture. Moved-body overlap is resolved by bounded material ejection; if no destination fits, the material stays in place and unresolved overlap is counted. The body receives bounded reaction observations instead of silently deleting trapped sand. [CyberRapierPhysicsBridge](../../godot/scripts/rapier_physics_bridge.gd) owns live Nodes/RIDs and manual stepping on the main thread. The native adapter receives values only. Desktop samples asynchronously; Web sequences both solvers and waits behind pending terrain colliders. Exact controller order belongs in [threading](simulation-tick-and-threading.md), not a universal coupling schedule.


### Rank 3: systems/player-control-playground.md — Player control playground > Native Sand cloud and Water blob ownership

Document: Player control playground
Path: systems/player-control-playground.md
authority: current-documentation
document-kind: contract
status: Current
scope: Experimental movement controls and shared asynchronous desktop composition, input and lap lifetime, lifecycle and bounded native failure validation; isolated Sand and Water player fields
canonical-for: [player-control-playground, player-movement-presets, player-material-field]
last-reviewed: 2026-11-05
Section: Player control playground > Native Sand cloud and Water blob ownership
The [playground runtime](../../godot/scripts/player_playground_runtime.gd) exclusively owns one synchronous native World for a material preset. Setup seeds 256 Sand or Water cells. Each admitted step applies the native field before the ordinary material tick; normal kernels still own gravity, Water flow and reactions. Mechanical presets instead use the existing synchronous physical arena and its main-thread Rapier session. Neither lane borrows the asynchronous sandbox worker's World. `World::apply_player_material_field` moves complete stored cells through `relocate_stored_cell`, preserving compact state, temperature and exact partial Water quantity within that call. It does not erase/repaint the cloud, create per-cell physics bodies, or introduce a Water pressure/flow rule. The next normal tick can redistribute Water and apply ordinary interactions. A field therefore does not promise conservation across unrelated chemistry or authoring actions. Selection is **matching material within a local radius**, not a persistent collection of owned particles. Nearby environmental Sand/Water can join; material that leaves the field is no longer controlled. The field follows the returned quantity-weighted material centroid with a bounded centre adjustment. WASD moves material rather than a remote selection cursor. The visible ring shows this local selection boundary. The native call scans at most 4,225 candidate positions within a radius-32 selection, captures at most 512 source parcels once, and attempts at most four axis-adjacent moves per parcel. Stable ordering and phase-based scan rotation prevent repeated source processing. Occupied cells, hard terrain, transient bodies, world bounds and unavailable destination storage stop a step. No occupied cell is overwritten. Invalid commands and failed/in-tick Worlds are refused before mutation. Exact API, receipt and limits are in [interfaces](../reference/interfaces-and-message-contracts.md#player-material-field-control) and [configuration](../reference/configuration-reference.md#player-playground-values).


### Rank 4: operations/architectural-generator-playtest.md — Architectural Generator walkthrough > Owner acceptance record

Document: Architectural Generator walkthrough
Path: operations/architectural-generator-playtest.md
authority: current-documentation
document-kind: guide
status: Current
scope: Accepted native Architectural Generator, Gentek catalogue, preview, installation and authored save workflow
canonical-for: [architectural-generator-owner-evaluation]
last-reviewed: 2026-11-24
Section: Architectural Generator walkthrough > Owner acceptance record
When reporting a problem, record the source/package SHA, pinned Godot version, renderer, display scale, seed and saved project. Include the smallest style and parameter combination that reproduces it. State whether the problem occurred while previewing, installing, painting, saving or reopening. This walkthrough was checked against `architectural_generator_dialog.gd`, `architectural_generator_project.gd` and `workbench_generator_dialog.gd`; its native illustrations were executed headlessly. Fresh pointer-driven GUI testing was blocked in the documentation environment. The original [Phase A/B qualification walkthrough](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/operations/architectural-generator-playtest.md) retains the earlier dated evaluation history. It does not put accepted #582, #684 or #691 back under an old candidate merge hold.


### Rank 5: research/sandspiel-performance-and-material-port.md — Sandspiel performance study and material port ledger > Historical upstream study

Document: Sandspiel performance study and material port ledger
Path: research/sandspiel-performance-and-material-port.md
authority: current-documentation
document-kind: reference
status: Current
scope: Current CyberSand adaptation inventory plus explicitly historical upstream study and hosted performance observations
canonical-for: [sandspiel-attribution-and-port-status, imported-material-ids]
last-reviewed: 2026-09-08
Section: Sandspiel performance study and material port ledger > Historical upstream study
The recorded study covered `crate/src/lib.rs`, `species.rs`, `utils.rs`, `Cargo.toml`, `js/render.js`, `js/fluid.js`, `js/glsl/sand.glsl`, license, and the development article. Retained primary references are [Making Sandspiel](https://maxbittker.com/making-sandspiel/), [pinned rules](https://github.com/MaxBittker/sandspiel/blob/dc77827b36adc5c04ea063515de4173ce28dbf2c/crate/src/species.rs), [pinned state/scan](https://github.com/MaxBittker/sandspiel/blob/dc77827b36adc5c04ea063515de4173ce28dbf2c/crate/src/lib.rs), and [pinned release settings](https://github.com/MaxBittker/sandspiel/blob/dc77827b36adc5c04ea063515de4173ce28dbf2c/crate/Cargo.toml). The study reported compact four-byte dense cells, native Rust/WASM rules with radius-two access, one-byte update clocks, optimization level 3/LTO/ `wasm-opt -O4`, and typed-array texture upload from WASM memory. It also described a 300×300 (90,000-cell) serial dense scan. These observations motivated compact native state and bulk rendering; they do not prove large sparse-world scalability. The recorded WebGL field pipeline used advection, curl/vorticity, divergence, pressure iterations and gradient subtraction, with cell/burn upload and velocity readback (pixel buffer/fence when available). CyberSand has not adopted this feedback as terrain authority. The supplied historical Noita comparison mentioned 64×64 dirty regions and a four-phase cross/checker pattern, but recorded no exact primary source. Treat that as design context, not independently verified Noita implementation evidence.

## Q09: What prevents terrain contacts and sand coupling from pushing a body twice?

Canonical rank: 2

Expected facts:

- Rapier owns hard-terrain contacts in the current adapter.
- The Rapier path suppresses duplicate cellular Wall correction/support; capped cellular impact, pressure and displacement contributions remain.
- Generalized backend-neutral coupling contracts are separate from this rectangle proof.

### Rank 1: systems/physical-free-flight.md — 4LY physical free-flight and assisted velocity control > Who owns the chassis, contacts and equipment?

Document: 4LY physical free-flight and assisted velocity control
Path: systems/physical-free-flight.md
authority: current-documentation
document-kind: contract
status: Current
scope: Shared single-chassis flight plant, strict two-output control, four 4LY-002 handling candidates and ordinary-game selection; measured calibration and downstream flight lab/policy qualification are separate
canonical-for: [physical-free-flight, 4ly-programme, 4ly-assisted-velocity-control]
last-reviewed: 2026-10-23
Section: 4LY physical free-flight and assisted velocity control > Who owns the chassis, contacts and equipment?
The shared [rig](../../godot/scripts/physical_actor_rig.gd) creates one actual rectangular `RigidBody2D` with authored mass/inertia, gravity, passive drag and real contacts. There are no rotor bodies, payload joints, mounts or mandatory equipment. The explicit empty loadout and no-equipment preparation path prevent ACT-005 from silently adding its usual held chassis. An empty usable selection on a legacy actor remains a different contract: it can still retain its physical equipment chassis. The existing main-thread [session](../../godot/scripts/physical_actor_session.gd) and [Rapier bridge](../../godot/scripts/rapier_physics_bridge.gd) retain live-body ownership, manual stepping, copied rectangular body publication and native material coupling. Graphics use the same collider dimensions and published physical transform. There are no per-cell physics bodies, transform-driven locomotion, position snaps, direct velocity assignments, erased contacts or ground-clearance forces. Free flight does not depend on a supporting surface. The [generic coupling contract](../architecture/rigid-body-and-cellular-coupling.md) still owns occupancy, hard-terrain contact, bounded native material response and their known limits. 4LY neither changes Water behavior nor closes generic-body, granular or soliding acceptance.


### Rank 2: architecture/rigid-body-and-cellular-coupling.md — Rigid-body and cellular coupling > When a crate moves through sand, are its pixels erased and restored?

Document: Rigid-body and cellular coupling
Path: architecture/rigid-body-and-cellular-coupling.md
authority: current-documentation
document-kind: contract
status: Current
scope: Rectangle occupancy, bounded displacement/impulses and Rapier hard contact; generalized physics and exact replay remain absent
canonical-for: [rigid-body-cellular-coupling]
last-reviewed: 2026-11-24
Section: Rigid-body and cellular coupling > When a crate moves through sand, are its pixels erased and restored?
**Current:** native World owns cellular materials; Rapier2D owns independent rigid bodies. Bodies are never erased from/restored into the material array. `CyberNativeCellWorld` projects copied rectangles into a separate transient body-ID field. Sand, liquids, Smoke, painting and the sampled character read that endpoint field as occupied. The retained three 8×14 reference bodies are drawn through shader transforms. ACT-004 instead draws each articulated part from its actual collider and copied Rapier transform; body colour is not stored in the cell texture. Moved-body overlap is resolved by bounded material ejection; if no destination fits, the material stays in place and unresolved overlap is counted. The body receives bounded reaction observations instead of silently deleting trapped sand. [CyberRapierPhysicsBridge](../../godot/scripts/rapier_physics_bridge.gd) owns live Nodes/RIDs and manual stepping on the main thread. The native adapter receives values only. Desktop samples asynchronously; Web sequences both solvers and waits behind pending terrain colliders. Exact controller order belongs in [threading](simulation-tick-and-threading.md), not a universal coupling schedule.


### Rank 3: architecture/rigid-body-and-cellular-coupling.md — Rigid-body and cellular coupling > Who resolves hard terrain and thin floors?

Document: Rigid-body and cellular coupling
Path: architecture/rigid-body-and-cellular-coupling.md
authority: current-documentation
document-kind: contract
status: Current
scope: Rectangle occupancy, bounded displacement/impulses and Rapier hard contact; generalized physics and exact replay remain absent
canonical-for: [rigid-body-cellular-coupling]
last-reviewed: 2026-11-24
Section: Rigid-body and cellular coupling > Who resolves hard terrain and thin floors?
**Current:** hard-surface pixels, including construction materials, are merged into static Rapier rectangle shapes. Cellular hard-contact correction/support is disabled to avoid double-solving delayed contacts. The demo bodies already have cast-shape CCD enabled and zero restitution; see [body configuration](../../godot/main.tscn). A future adaptive CCD/substep controller is a separate **Planned** feature. Hard-terrain extraction creates 64×64 packets: 256 units for the 1024² demo. The consumer checks a 32-chunk/750-microsecond soft rebuild budget between units. The preceding native `get_hard_surface_chunk_rectangles` extraction is outside that budget, and one indivisible changed chunk may exceed it. This is bounded consumer granularity, not an end-to-end frame-time guarantee. On the #406 branch, the extraction reads a one-bit hard-surface mask straight from stored cells (`World::copy_hard_surface_bits`). It rebuilds only the 64×64 packets whose mask changed since the previous revision, and reuses the others. The packet is byte-identical to a full rebuild from the display projection ([evidence](../audits/2026-11-06-pf-ballistic-tick-cost.md)). Source: [native extraction](../../godot/native_extension/cyber_native_cell_world.cpp), [Rapier `process_hard_surface_collider_budget`](../../godot/scripts/rapier_physics_bridge.gd).


### Rank 4: decisions/ADR-007-rigid-body-cellular-coupling.md — ADR-007: Separate rigid-body occupancy coupling > Why not remove and restore body pixels?

Document: ADR-007 — Separate rigid-body occupancy coupling
Path: decisions/ADR-007-rigid-body-cellular-coupling.md
authority: current-documentation
document-kind: decision
status: Current
scope: Accepted independent body representation and value-data coupling; rectangle proof is not generalized physics
canonical-for: [decision-separate-rigid-body-occupancy]
last-reviewed: 2026-09-09
Section: ADR-007: Separate rigid-body occupancy coupling > Why not remove and restore body pixels?
Temporarily erasing a crate's old pixels while simulating sand would expose false Empty space. Restoring its transformed pixels cannot undo all movement through that space and leaves overwriting ambiguous. Separate occupancy lets cellular rules see a stable body without transferring ownership of its material or physics state. A mask alone is insufficient for the complete interaction: material impacts, displacement and approximate pressure must also affect the body. Ordered observations make that feedback explicit and testable without workers calling PhysicsServer2D. Hard terrain contact is solved by Rapier rather than duplicated by delayed cellular correction.


### Rank 5: architecture/rigid-body-and-cellular-coupling.md — Rigid-body and cellular coupling > What does REM-002 establish on Current source?

Document: Rigid-body and cellular coupling
Path: architecture/rigid-body-and-cellular-coupling.md
authority: current-documentation
document-kind: contract
status: Current
scope: Rectangle occupancy, bounded displacement/impulses and Rapier hard contact; generalized physics and exact replay remain absent
canonical-for: [rigid-body-cellular-coupling]
last-reviewed: 2026-11-24
Section: Rigid-body and cellular coupling > What does REM-002 establish on Current source?
**Current bounded baseline, 2026-09-24:** [REM-002 evidence](../audits/2026-09-24-rem002-issue11-integration-forensics.md) reconciles the never-integrated historical #11 repair into current main without claiming broad body/granular gameplay acceptance. Current semantics are: - a stored cell beneath a transient body mask remains material authority and does not execute its normal cellular kernel as the body Wall proxy; - ejection endpoints and their bounded path reject hard terrain and foreign body masks; if no legal target exists, the complete payload stays at the source and unresolved overlap is reported; - an ordinary rectangle may receive a bounded cellular-owned granular-bearing contribution from current support-capable packed material; - bearing is recomputed from current cells every accepted sample and disappears after excavation/support loss; there is no support cache or granular Rapier collider; - hard terrain remains Rapier/static-terrain contact, and liquids do not become granular bearing; - the existing 11-float input / 9-float result ABI and sample-age policy remain unchanged. On frozen source `df54e927...`, the focused real-Rapier Linux regression measured one-height Sand peak/final depth **3.748/0.000 cells**, four-height **6.652/1.472 cells**, and explicit excavation released the body into substantial downward travel. The exact runtime/platform qualifications and retained hashes are in the dated REM-002 audit. This is still a bounded ordinary rectangle/load baseline. General shapes, high energy/thin beds, crowding, sustained publication delay, calibrated force/torque, fracture and broad body↔granular gameplay acceptance remain outside this contract and are owned by REM-004 / #83 where applicable.

## Q10: What exactly crosses the rigid body bridge, and how many bodies can it handle?

Canonical rank: 2

Expected facts:

- The prototype packed float32 input/result strides are 11 and 9, with at most 64 accepted bodies after ACT-004; every admitted field is finite and body IDs are exact integers 1 through 64.
- Values carry body/sample identity and numeric rectangle state/results; no Node, RID or live direct state crosses.
- This is a prototype layout, not the approved generalized native ABI.

### Rank 1: decisions/ADR-007-rigid-body-cellular-coupling.md — ADR-007: Separate rigid-body occupancy coupling > Decision and implementation status

Document: ADR-007 — Separate rigid-body occupancy coupling
Path: decisions/ADR-007-rigid-body-cellular-coupling.md
authority: current-documentation
document-kind: decision
status: Current
scope: Accepted independent body representation and value-data coupling; rectangle proof is not generalized physics
canonical-for: [decision-separate-rigid-body-occupancy]
last-reviewed: 2026-09-09
Section: ADR-007: Separate rigid-body occupancy coupling > Decision and implementation status
**Approved and Current for rectangles:** independent rigid bodies project a separate stable obstacle mask into cellular work. Materials remain in their own authoritative grid. Only packed value samples/results cross the worker boundary; live physics objects stay with the main-thread adapter. Moved-body overlap has an explicit bounded reconciliation outcome. Current implementation sources are [native coupling](../../godot/native_extension/cyber_native_cell_world.cpp) and [Rapier bridge](../../godot/scripts/rapier_physics_bridge.gd). Exact geometry, sweep/impulse bounds and numerical limits belong in the [coupling contract](../architecture/rigid-body-and-cellular-coupling.md). **Planned:** generalized shapes, torque, fracture membership and particle fallback.


### Rank 2: architecture/rigid-body-and-cellular-coupling.md — Rigid-body and cellular coupling > When a crate moves through sand, are its pixels erased and restored?

Document: Rigid-body and cellular coupling
Path: architecture/rigid-body-and-cellular-coupling.md
authority: current-documentation
document-kind: contract
status: Current
scope: Rectangle occupancy, bounded displacement/impulses and Rapier hard contact; generalized physics and exact replay remain absent
canonical-for: [rigid-body-cellular-coupling]
last-reviewed: 2026-11-24
Section: Rigid-body and cellular coupling > When a crate moves through sand, are its pixels erased and restored?
**Current:** native World owns cellular materials; Rapier2D owns independent rigid bodies. Bodies are never erased from/restored into the material array. `CyberNativeCellWorld` projects copied rectangles into a separate transient body-ID field. Sand, liquids, Smoke, painting and the sampled character read that endpoint field as occupied. The retained three 8×14 reference bodies are drawn through shader transforms. ACT-004 instead draws each articulated part from its actual collider and copied Rapier transform; body colour is not stored in the cell texture. Moved-body overlap is resolved by bounded material ejection; if no destination fits, the material stays in place and unresolved overlap is counted. The body receives bounded reaction observations instead of silently deleting trapped sand. [CyberRapierPhysicsBridge](../../godot/scripts/rapier_physics_bridge.gd) owns live Nodes/RIDs and manual stepping on the main thread. The native adapter receives values only. Desktop samples asynchronously; Web sequences both solvers and waits behind pending terrain colliders. Exact controller order belongs in [threading](simulation-tick-and-threading.md), not a universal coupling schedule.


### Rank 3: reference/interfaces-and-message-contracts.md — Interfaces and message contracts > What crosses the rigid-body bridge, and which limits apply?

Document: Interfaces and message contracts
Path: reference/interfaces-and-message-contracts.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current C ABI, procedural-generation C++/Godot surfaces and private packed layouts; proposed gameplay/reconfiguration contracts remain distinct
canonical-for: [public-and-adapter-interface-layouts]
last-reviewed: 2026-11-24
Section: Interfaces and message contracts > What crosses the rigid-body bridge, and which limits apply?
**Current private adapter format:** `PackedFloat32Array`, not a versioned C ABI. Source: [rigid_body_coupling.gd](../../godot/scripts/rigid_body_coupling.gd), [native parser/results](../../godot/native_extension/cyber_native_cell_world.cpp). Offsets below are float indices within each record. | Input stride 11 | Field | Result stride 9 | Field | |---|---|---|---| | 0 | Body ID | 0 | Body ID | | 1–2 | Centre x/y | 1–2 | Central impulse x/y | | 3 | Rotation | 3–4 | Positional correction x/y | | 4–5 | Full rectangle size x/y | 5 | Contact count | | 6–7 | Linear velocity x/y | 6 | Displaced-cell count | | 8 | Angular velocity | 7 | Unresolved-cell count | | 9 | Mass | 8 | Sample serial | | 10 | Sample serial | — | — | Positions/sizes/corrections use pixels/cells, rotation radians, velocities pixels/second and radians/second. Mass/impulse use the Godot adapter's quantities; production physical-unit calibration remains unresolved. IDs/counts/serials travel as floats. ACT-004 parsing considers at most 64 complete records, accepts integer IDs 1–64 and integer sample serials 0–16,777,215, rejects any nonfinite field or nonpositive size/mass, ignores trailing partial records and retains the first duplicate. Accepted full sizes clamp to at least one cell and mass to 0.001. The same finite-record predicate is used by the fallback and bridge. The physical session rejects a complete assembly beyond capacity before spawning. SetP circular wheels supply their diameter as a circumscribed square in this unchanged rectangle layout. Rapier hard contact and graphics use circles; native masks and displacement retain the explicit conservative approximation. General contours and cellular torque feedback remain Planned; these private packed records are not an unrestricted public network protocol. Numerical response and sample-age policy belong in [coupling](../architecture/rigid-body-and-cellular-coupling.md).


### Rank 4: architecture/rigid-body-and-cellular-coupling.md — Rigid-body and cellular coupling > Who resolves hard terrain and thin floors?

Document: Rigid-body and cellular coupling
Path: architecture/rigid-body-and-cellular-coupling.md
authority: current-documentation
document-kind: contract
status: Current
scope: Rectangle occupancy, bounded displacement/impulses and Rapier hard contact; generalized physics and exact replay remain absent
canonical-for: [rigid-body-cellular-coupling]
last-reviewed: 2026-11-24
Section: Rigid-body and cellular coupling > Who resolves hard terrain and thin floors?
**Current:** hard-surface pixels, including construction materials, are merged into static Rapier rectangle shapes. Cellular hard-contact correction/support is disabled to avoid double-solving delayed contacts. The demo bodies already have cast-shape CCD enabled and zero restitution; see [body configuration](../../godot/main.tscn). A future adaptive CCD/substep controller is a separate **Planned** feature. Hard-terrain extraction creates 64×64 packets: 256 units for the 1024² demo. The consumer checks a 32-chunk/750-microsecond soft rebuild budget between units. The preceding native `get_hard_surface_chunk_rectangles` extraction is outside that budget, and one indivisible changed chunk may exceed it. This is bounded consumer granularity, not an end-to-end frame-time guarantee. On the #406 branch, the extraction reads a one-bit hard-surface mask straight from stored cells (`World::copy_hard_surface_bits`). It rebuilds only the 64×64 packets whose mask changed since the previous revision, and reuses the others. The packet is byte-identical to a full rebuild from the display projection ([evidence](../audits/2026-11-06-pf-ballistic-tick-cost.md)). Source: [native extraction](../../godot/native_extension/cyber_native_cell_world.cpp), [Rapier `process_hard_surface_collider_budget`](../../godot/scripts/rapier_physics_bridge.gd).


### Rank 5: systems/physical-free-flight.md — 4LY physical free-flight and assisted velocity control > Who owns the chassis, contacts and equipment?

Document: 4LY physical free-flight and assisted velocity control
Path: systems/physical-free-flight.md
authority: current-documentation
document-kind: contract
status: Current
scope: Shared single-chassis flight plant, strict two-output control, four 4LY-002 handling candidates and ordinary-game selection; measured calibration and downstream flight lab/policy qualification are separate
canonical-for: [physical-free-flight, 4ly-programme, 4ly-assisted-velocity-control]
last-reviewed: 2026-10-23
Section: 4LY physical free-flight and assisted velocity control > Who owns the chassis, contacts and equipment?
The shared [rig](../../godot/scripts/physical_actor_rig.gd) creates one actual rectangular `RigidBody2D` with authored mass/inertia, gravity, passive drag and real contacts. There are no rotor bodies, payload joints, mounts or mandatory equipment. The explicit empty loadout and no-equipment preparation path prevent ACT-005 from silently adding its usual held chassis. An empty usable selection on a legacy actor remains a different contract: it can still retain its physical equipment chassis. The existing main-thread [session](../../godot/scripts/physical_actor_session.gd) and [Rapier bridge](../../godot/scripts/rapier_physics_bridge.gd) retain live-body ownership, manual stepping, copied rectangular body publication and native material coupling. Graphics use the same collider dimensions and published physical transform. There are no per-cell physics bodies, transform-driven locomotion, position snaps, direct velocity assignments, erased contacts or ground-clearance forces. Free flight does not depend on a supporting surface. The [generic coupling contract](../architecture/rigid-body-and-cellular-coupling.md) still owns occupancy, hard-terrain contact, bounded native material response and their known limits. 4LY neither changes Water behavior nor closes generic-body, granular or soliding acceptance.

## Q11: If importing a level gives the exact same save string, will the next tick replay exactly too?

Canonical rank: 1

Expected facts:

- No: CYSD1 reconstructs a finite level; identical re-export proves saved payload restoration only.
- Tick/epoch, scheduler activity, complete configuration, pending commands and Rapier internal solver state are omitted.
- A full durable exact-replay checkpoint and general strict mode remain Planned.

### Rank 1: reference/level-saves-and-replay.md — Level saves and exact replay > Does an identical save reproduce the next tick?

Document: Level saves and exact replay
Path: reference/level-saves-and-replay.md
authority: current-documentation
document-kind: contract
status: Current
scope: Authored Workbench starts and material-only Flatten, CYSD1 finite-level exchange, native CYPS2–5 continuation, Wave save refusal and remaining full-application replay gaps
canonical-for: [cysd1-level-format, save-import-export, replay-persistence]
last-reviewed: 2026-11-24
Section: Level saves and exact replay > Does an identical save reproduce the next tick?
**Current: no such guarantee.** CYSD1 restores a fixed demo level and selected metadata. Identical re-export proves equality of what the format stores. It does not prove that cells, characters or Rapier will follow the original future trajectory: tick/epoch/activity, complete simulation configuration, pending authoritative events/commands and Rapier contact caches are omitted. Complete durable replay and a selectable strict runtime policy are **Planned** implementations of the **Approved** exact-validation requirement. The native fixture hashes are also incomplete replay identities. Their precise coverage belongs to [determinism](../architecture/determinism-and-boundary-transfers.md#replay-state-coverage). A default-off desktop lockstep fence made one fixture's repeated same-host runs bit-identical, and the desktop game can opt into it with `--lockstep-coupling`. It does not add input capture or a replay format; see [coupled desktop determinism](../architecture/determinism-and-boundary-transfers.md#coupled-desktop-determinism--2026-11-06).


### Rank 2: reference/level-saves-and-replay.md — Level saves and exact replay > May saving run concurrently with a tick?

Document: Level saves and exact replay
Path: reference/level-saves-and-replay.md
authority: current-documentation
document-kind: contract
status: Current
scope: Authored Workbench starts and material-only Flatten, CYSD1 finite-level exchange, native CYPS2–5 continuation, Wave save refusal and remaining full-application replay gaps
canonical-for: [cysd1-level-format, save-import-export, replay-persistence]
last-reviewed: 2026-11-24
Section: Level saves and exact replay > May saving run concurrently with a tick?
**Current: no.** Call construction/export/import at a safe boundary with exclusive World ownership. `copy_level(World&, ...)` clears transient obstacles so temperature sampling reads stored cells. The caller must rebuild the body projection before the next cellular tick. Export is therefore not a concurrent const query, even though it does not change saved material bytes. The Web controller performs these operations on its synchronous owner. A future asynchronous save service needs an explicit capture/handoff contract; borrowing mutable World storage from a writer is **Rejected**.


### Rank 3: systems/water-design.md — Water design > Rendering and saves

Document: Water design
Path: systems/water-design.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current Water-family routing and player defaults; scoped FreeMass mechanics, quantity accounting, historical negative controls and fallback differences
canonical-for: [native-water-semantics, native-fallback-water-differences]
last-reviewed: 2026-11-24
Section: Water design > Rendering and saves
Wave exact physical save/restore is refused. A Workbench authored Save or material-only Flatten reconstructs a starting layout, not Wave flux, in-flight parcels, temperature or complete physical state. The [save contract](../reference/level-saves-and-replay.md) separates these formats and current CYPS versions. `World::copy_rgba` derives stable coverage from world coordinates and mass. The Godot native path instead publishes RG8 material/condition bytes and derives coverage in the palette shader. Both are presentation-only: dither cannot change mass, collision, dirty authority, or waking. Animated presentation does not imply moving Water. The [appearance contract](material-appearance-and-rendering.md) owns texture/upload details. CYSD1 preserves the encoded Water state bytes for a finite level. It omits scheduler and external-input state, so byte-identical re-export does not prove the same next tick. See [level saves and replay](../reference/level-saves-and-replay.md).


### Rank 4: reference/level-saves-and-replay.md — Level saves and exact replay > Can a failed world be saved or recovered?

Document: Level saves and exact replay
Path: reference/level-saves-and-replay.md
authority: current-documentation
document-kind: contract
status: Current
scope: Authored Workbench starts and material-only Flatten, CYSD1 finite-level exchange, native CYPS2–5 continuation, Wave save refusal and remaining full-application replay gaps
canonical-for: [cysd1-level-format, save-import-export, replay-persistence]
last-reviewed: 2026-11-24
Section: Level saves and exact replay > Can a failed world be saved or recovered?
**Current:** ordinary Godot level export rejects a quarantined World; it must not label partial tick state as a valid level. Raw serialized native reads remain diagnostic. A previously saved, validated level or explicit fresh level/reset can replace the failed World. Invalid replacement leaves the fault and partial state intact. Successful replacement clears pending events/failure/tick identity and uses the latest requested region; it does not resume the failed attempt or replay accepted events. See [failure policy](../decisions/ADR-010-failed-tick-quarantine.md).


### Rank 5: reference/level-saves-and-replay.md — Level saves and exact replay > What is stored in CYSD1?

Document: Level saves and exact replay
Path: reference/level-saves-and-replay.md
authority: current-documentation
document-kind: contract
status: Current
scope: Authored Workbench starts and material-only Flatten, CYSD1 finite-level exchange, native CYPS2–5 continuation, Wave save refusal and remaining full-application replay gaps
canonical-for: [cysd1-level-format, save-import-export, replay-persistence]
last-reviewed: 2026-11-24
Section: Level saves and exact replay > What is stored in CYSD1?
Source: [CyberDemoSaveCodec](../../godot/scripts/demo_save_codec.gd), [demo::copy_level/reconstruct](../../native/include/cybersand/demo_snapshot.hpp) and [CyberDemoBridge](../../godot/native_extension/cyber_demo_bridge.hpp). | Component | Current contract | |---|---| | World extent | Exactly 1024×1024, row-major; not arbitrary signed sparse storage | | Per-cell payload | Material ID, `state_a`, `state_b`, and signed temperature encoded as little-endian 16 bits: five bytes per cell, 5,242,880 bytes total | | Header | 56 bytes: magic `CYSD1`, format/compression flags, dimensions, metadata/raw/compressed lengths, SHA-256 digest | | Integrity | Digest covers the first 24 header bytes plus JSON metadata and compressed world bytes | | Compression/text | DEFLATE binary payload; Base64 portable text | | Limits | Metadata ≤16,384 bytes; binary ≤8 MiB; text ≤12 MiB | | Metadata | Demo ID, player position/velocity, selected material, quality, coherent emission, adhesion and glow options | | Body records | At most three Physics Pit bodies: position, angle, linear/angular velocity, sleeping flag | | Local slot | `user://web_demo_slot_1.cys`; browser storage is origin/profile dependent | The five save bytes encode logical material/state values and temperature from the optional field; they exclude the update epoch. Current authoritative cells use the [eight-byte storage carrier](../architecture/chunk-tile-and-buffer-model.md#what-is-stored-per-cell-and-per-chunk). CYSD1's five-byte save layout is separate from the in-memory `Cell` ABI.

## Q12: What is inside a CYSD1 file, and can it save an arbitrary sparse world?

Canonical rank: 1

Expected facts:

- Current encoding is fixed at 1024 by 1024 with five native bytes per cell: material, state_a, state_b and LE16 temperature.
- A 56-byte header, bounded JSON metadata, DEFLATE payload, SHA-256 integrity and Base64 text form the container.
- General sparse-world persistence is Planned.

### Rank 1: reference/level-saves-and-replay.md — Level saves and exact replay > Choose the right persistence contract

Document: Level saves and exact replay
Path: reference/level-saves-and-replay.md
authority: current-documentation
document-kind: contract
status: Current
scope: Authored Workbench starts and material-only Flatten, CYSD1 finite-level exchange, native CYPS2–5 continuation, Wave save refusal and remaining full-application replay gaps
canonical-for: [cysd1-level-format, save-import-export, replay-persistence]
last-reviewed: 2026-11-24
Section: Level saves and exact replay > Choose the right persistence contract
| Operation | Preserves | Does not promise | |---|---|---| | Workbench **Save start** | Applied authored setup, supported ordered edits, actors/options, and the existing generated or material baseline | The current evolved cellular layout unless explicitly captured; live actor momentum, leases or Undo-session continuation | | Workbench **Flatten / Bake History**, then Save | A uint16 stored-material plane plus later acknowledged authored edits | Temperature, fractional quantities, airborne parcels or exact evolved state; Flatten itself does not write a file | | CYSD1 level exchange | Fixed 1024-square logical cells and selected demo metadata | Full native/Rapier continuation or arbitrary Workbench canvas coverage | | Native CYPS2–5 | Supported non-Wave native tick-boundary state with version-specific authority | Full host, Rapier, provider or user-input replay | | Wave physical save | Explicit refusal, format version 0 | No exact Wave continuation format exists at this source | Source inspection at accepted main `00cdb02f` checks [`shared_workbench.gd`](../../godot/scripts/shared_workbench.gd), [`workbench_material_baseline.gd`](../../godot/scripts/workbench_material_baseline.gd), [`demo_save_codec.gd`](../../godot/scripts/demo_save_codec.gd) and [`World`](../../native/include/cybersand/world.hpp). Save, Flatten, Reset/Restore and native physical export are different actions. A successful round-trip of one format does not qualify another.


### Rank 2: reference/level-saves-and-replay.md — Level saves and exact replay > What is stored in CYSD1?

Document: Level saves and exact replay
Path: reference/level-saves-and-replay.md
authority: current-documentation
document-kind: contract
status: Current
scope: Authored Workbench starts and material-only Flatten, CYSD1 finite-level exchange, native CYPS2–5 continuation, Wave save refusal and remaining full-application replay gaps
canonical-for: [cysd1-level-format, save-import-export, replay-persistence]
last-reviewed: 2026-11-24
Section: Level saves and exact replay > What is stored in CYSD1?
Source: [CyberDemoSaveCodec](../../godot/scripts/demo_save_codec.gd), [demo::copy_level/reconstruct](../../native/include/cybersand/demo_snapshot.hpp) and [CyberDemoBridge](../../godot/native_extension/cyber_demo_bridge.hpp). | Component | Current contract | |---|---| | World extent | Exactly 1024×1024, row-major; not arbitrary signed sparse storage | | Per-cell payload | Material ID, `state_a`, `state_b`, and signed temperature encoded as little-endian 16 bits: five bytes per cell, 5,242,880 bytes total | | Header | 56 bytes: magic `CYSD1`, format/compression flags, dimensions, metadata/raw/compressed lengths, SHA-256 digest | | Integrity | Digest covers the first 24 header bytes plus JSON metadata and compressed world bytes | | Compression/text | DEFLATE binary payload; Base64 portable text | | Limits | Metadata ≤16,384 bytes; binary ≤8 MiB; text ≤12 MiB | | Metadata | Demo ID, player position/velocity, selected material, quality, coherent emission, adhesion and glow options | | Body records | At most three Physics Pit bodies: position, angle, linear/angular velocity, sleeping flag | | Local slot | `user://web_demo_slot_1.cys`; browser storage is origin/profile dependent | The five save bytes encode logical material/state values and temperature from the optional field; they exclude the update epoch. Current authoritative cells use the [eight-byte storage carrier](../architecture/chunk-tile-and-buffer-model.md#what-is-stored-per-cell-and-per-chunk). CYSD1's five-byte save layout is separate from the in-memory `Cell` ABI.


### Rank 3: reference/level-saves-and-replay.md — Level saves and exact replay > What continuation state is missing?

Document: Level saves and exact replay
Path: reference/level-saves-and-replay.md
authority: current-documentation
document-kind: contract
status: Current
scope: Authored Workbench starts and material-only Flatten, CYSD1 finite-level exchange, native CYPS2–5 continuation, Wave save refusal and remaining full-application replay gaps
canonical-for: [cysd1-level-format, save-import-export, replay-persistence]
last-reviewed: 2026-11-24
Section: Level saves and exact replay > What continuation state is missing?
CYSD1 omits tick/epoch, scheduler activity and sleep state, queued explosions and future input ordering, complete WorldConfig/interest state, render leases, transient body masks, and Rapier solver/contact caches. Import resets character grounded state and reconstructs physics bodies. Body metadata round-trips are checked with `1e-5` tolerance; exact floating-point trajectory replay is not claimed. **Planned:** versioned general sparse-world persistence, replay input capture, complete state/configuration identity, migration, I/O pressure policy and an explicit strict-mode implementation. Do not infer those contracts from CYSD1.


### Rank 4: reference/level-saves-and-replay.md — Level saves and exact replay > Workbench starting constructions

Document: Level saves and exact replay
Path: reference/level-saves-and-replay.md
authority: current-documentation
document-kind: contract
status: Current
scope: Authored Workbench starts and material-only Flatten, CYSD1 finite-level exchange, native CYPS2–5 continuation, Wave save refusal and remaining full-application replay gaps
canonical-for: [cysd1-level-format, save-import-export, replay-persistence]
last-reviewed: 2026-11-24
Section: Level saves and exact replay > Workbench starting constructions
The accepted desktop Workbench has a separate, bounded named JSON recipe for authored starts. It reconstructs native material placement and body settings through the worker and a prepared Rapier session. The file omits evolved physics state. CYSD1 and solver checkpoints keep their existing interfaces. The [workbench controls and schema scope](../systems/player-control-playground.md#development-workbench-on-desktop) describe the stored fields and explicit refusal behavior.


### Rank 5: systems/world-storage-and-interest-region.md — World storage and interest region > Persistence boundary

Document: World storage and interest region
Path: systems/world-storage-and-interest-region.md
authority: current-documentation
document-kind: contract
status: Current
scope: Sparse native storage, finite adapters, interest pause/resume and fresh generated-chunk admission; general persistence/reconfiguration/streaming remain separate
canonical-for: [world-storage, camera-interest-region]
last-reviewed: 2026-11-24
Section: World storage and interest region > Persistence boundary
**Current:** CYSD1 reconstructs a fixed demo level. It is neither a general WorldStorage format nor exact continuation. Its cell layout, validation, exclusive export ownership, state omissions, and body tolerance belong to the [level-save contract](../reference/level-saves-and-replay.md). **Planned:** sparse persistence, schema migration, general serialized configuration, replay capture and I/O backpressure. **Deferred implementation:** broad streamed loading/eviction until local material behavior is mature.

## Q13: Can saving the level alter anything, and does a bad import damage the running world?

Canonical rank: 1

Expected facts:

- Export requires exclusive safe-boundary ownership and clears the transient obstacle projection while copying stored-cell temperatures.
- Coupling must rebuild before the next cellular tick.
- Import validates and constructs a fresh World before swapping, preserving the old world on invalid input.

### Rank 1: reference/level-saves-and-replay.md — Level saves and exact replay > May saving run concurrently with a tick?

Document: Level saves and exact replay
Path: reference/level-saves-and-replay.md
authority: current-documentation
document-kind: contract
status: Current
scope: Authored Workbench starts and material-only Flatten, CYSD1 finite-level exchange, native CYPS2–5 continuation, Wave save refusal and remaining full-application replay gaps
canonical-for: [cysd1-level-format, save-import-export, replay-persistence]
last-reviewed: 2026-11-24
Section: Level saves and exact replay > May saving run concurrently with a tick?
**Current: no.** Call construction/export/import at a safe boundary with exclusive World ownership. `copy_level(World&, ...)` clears transient obstacles so temperature sampling reads stored cells. The caller must rebuild the body projection before the next cellular tick. Export is therefore not a concurrent const query, even though it does not change saved material bytes. The Web controller performs these operations on its synchronous owner. A future asynchronous save service needs an explicit capture/handoff contract; borrowing mutable World storage from a writer is **Rejected**.


### Rank 2: reference/level-saves-and-replay.md — Level saves and exact replay > How does CYPS2 differ from CYSD1?

Document: Level saves and exact replay
Path: reference/level-saves-and-replay.md
authority: current-documentation
document-kind: contract
status: Current
scope: Authored Workbench starts and material-only Flatten, CYSD1 finite-level exchange, native CYPS2–5 continuation, Wave save refusal and remaining full-application replay gaps
canonical-for: [cysd1-level-format, save-import-export, replay-persistence]
last-reviewed: 2026-11-24
Section: Level saves and exact replay > How does CYPS2 differ from CYSD1?
**Current on main through accepted PR #246 (`ec58d919`, 2026-10-25).** `World::save_physical_state()`/`restore_physical_state()` and the bridge's `export_physical_state`/`import_physical_state` write and read **CYPS2** (the base `kPhysicalStateFormatVersion` is 2), an exact tick-boundary continuation for LCB comparison Worlds. Its canonical description is the [pressure persistence contract](../architecture/pressure-flow-v1.md#persistence-cyps-v2) and [shared native setup/accounting contract](../architecture/liquid-prepared-setup-and-receipts.md). | | CYSD1 | CYPS2 | |---|---|---| | Purpose | finite level exchange | exact continuation of a comparison World | | Liquid policy | not stored; import always reconstructs on default families (NC-10) | policy envelope stored and re-admitted by the running build | | Clock, epochs, regions, pending events, activity blocks | omitted | stored | | Pressure sidecars and gas table | n/a (lossy; never a continuation) | stored | | Shared quantity accounting and construction binding | omitted | exact source/sink and rule totals, visible+overfill, separate material cell counts, prepared/normalization identities | | Integrity | codec checksum and native validation | SHA-256 of the body, then range and invariant checks | | Failure | live World intact | `invalid_argument`/`LiquidPolicyRefused`; live World intact ("running world preserved") | | Continuation | none claimed | bit-identical physical and state hash, including at another worker count | CYPS omits execution settings (workers, capacities come from the caller), host-owned transient body masks and Rapier state, and requires settled discovery to be disabled. It is not general sparse-world persistence, replay input capture or full application replay. The owner-requested native codec freeze does not freeze production Cell/global ABI or those missing host contracts; CYSD1 is unchanged. Historical CYPS1 belongs to the #245 source/artifact evidence and is explicitly refused by this decoder. A valid digest does not excuse inconsistent accounting: restore validates closure, roles, quanta and actual stored authority. The native prepared builder can normalize final setup tuples only with explicit opt-in and a bound receipt. It cannot normalize a live World. Godot's normal level import still reconstructs defaults; native candidate CYSD1 ingress preflights nonzero fractional W-CY Water and returns `normalization_required` rather than silently rounding. The old Godot dictionary run getter is not the typed native receipt and provides no full host-replay proof.


### Rank 3: architecture/data-ownership-and-lifetimes.md — Data ownership and lifetimes > Explicit imported-level ownership

Document: Data ownership and lifetimes
Path: architecture/data-ownership-and-lifetimes.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current resource owners, mutation windows, publication retirement and allocation limits; proposed resources are explicitly separated
canonical-for: [resource-ownership-and-lifetimes]
last-reviewed: 2026-11-24
Section: Data ownership and lifetimes > Explicit imported-level ownership
The current synchronous [normal import route](liquid-prepared-setup-and-receipts.md#explicit-ordinary-level-import-and-retained-restart) keeps the running World/player/receipt/record until native preparation, private sampled-player configuration, qualified observation and final serial guard all pass. Native exclusively owns the pending World; the private level session owns copied decoded payload/metadata/selection. Commit consumes the token once, then the controller adopts staged values. Restart reconstructs that retained input; ordinary default replacement retires it. Unsupported physical/tower/showcase owners refuse without detaching or rebinding their actual graph. No live scene object crosses a worker boundary, and this synchronous route adds no tick work.


### Rank 4: architecture/liquid-prepared-setup-and-receipts.md — Native liquid prepared setup, receipts and quantity accounting > Explicit ordinary level import and retained restart

Document: Native liquid prepared setup, receipts and quantity accounting
Path: architecture/liquid-prepared-setup-and-receipts.md
authority: current-documentation
document-kind: design
status: Current
scope: Accepted main LCB-001 native construction contract — immutable final tuples, explicit Water normalization, prepared World ownership, typed native outcomes, native run and attempt receipts, exact quantity aggregates, physical hash/CYPS2 and source-matched Windows/Linux acceptance; application-host proof and downstream family work remain open
canonical-for: [liquid-prepared-setup, liquid-native-run-receipt, liquid-quantity-accounting]
last-reviewed: 2026-11-20
Section: Native liquid prepared setup, receipts and quantity accounting > Explicit ordinary level import and retained restart
**Current bounded unmerged #202 source:** the synchronous normal application [`web_demo_controller.gd`](../../godot/scripts/web_demo_controller.gd) routes the existing Save/Load Import button through `prepare_liquid_level` only after the user selects **Exploratory** and **Use selection for next level import** in the liquid panel. Arming copies policy, normalization and explicit geometry; it does not mutate the running World. Unarmed imports keep the original Current constructor. **Use Current defaults for next import** clears the pending choice. The [dated Windows proof](../audits/2026-10-25-lcb003-level-import-host.md) exercises those actual menu/panel callbacks; it is not browser qualification. [`prepared_level_session.gd`](../../godot/scripts/prepared_level_session.gd) owns the copied accepted payload/metadata/selection and a private sampled player. Native owns the exclusive pending World and token. Saved position/velocity, current sampled profile/recovery policy, final quality/view buffers, clamped camera, interest region, cadence and adhesion are complete before receipt capture. The actual raw payload digest comes from native copied readback. Qualified host observation collection precedes the final owner serial/lifetime guard and native retained-state commit fence. Success adopts only staged values; refusal retains the old World, player, applied native bytes and owner record. The native-v1 qualifications and false native/host full matched eligibility stay unchanged; outer metadata/player claims remain explicitly unverified host values. This route supports ordinary body-free demos. Current Tower, showcase, Blacksite, physical owners and saved physical/tower/showcase/body routes refuse before replacement. Controlled/active apparatus retain their existing import guard. No body is detached or physics space rebound by an import attempt. These refusal boundaries are remaining constructor ownership, not implemented body conversion. The subsequent settings correction reads native run-component v1 before creating a token. Only production interaction8:9:30 and diagnostic law0:−1 are supported; other support/period/exchange/viscosity settings explicitly refuse instead of resetting. Independent configured transport also refuses. Production unconfigured Baseline is admitted; a private accepted level may retain its own configured Baseline only while actual transport component, native generation and copied applied receipt hash still match. A retained object alone grants no exemption. The builder's existing enabled observational telemetry remains explicit; this does not preserve arbitrary diagnostics/transport or convert another tuned run. The original44-assertion proof covers normal Baseline only. The later73 assertions add actual nondefault refusal and retired-generation controls. Accepted import starts paused. **R / Restart world** rebuilds its original copied payload with its accepted policy/normalization/geometry and metadata after edits, creating a new native generation and owner observation. Ordinary default import or demo construction retires that prepared identity. CYSD1 still stores no liquid policy or complete continuation state: exporting does not persist this private in-memory reconstruction request. Mixed PF Water/Oil/Brine IN runs through the ordinary synchronous owner with explicit radius3 and actual damping readback; Water IN remains unsupported. Physical imports, complete host identity, later


### Rank 5: operations/lcb-manual-comparison-ux.md — LCB manual liquid comparison UX flow > Current controls and ownership

Document: LCB manual liquid comparison UX flow
Path: operations/lcb-manual-comparison-ux.md
authority: current-documentation
document-kind: design
status: Current
scope: LCB-003 (#202) bounded experimental comparison UI, native availability, explicit normalization and constructor coverage, followed by remaining planned manual feel-testing flow
canonical-for: [lcb-manual-comparison-ux]
last-reviewed: 2026-11-03
Section: LCB manual liquid comparison UX flow > Current controls and ownership
The subsequent [synchronous Physics Pit route](../architecture/liquid-prepared-setup-and-receipts.md#synchronous-physics-pit-reference-bodies) enables explicit Exploratory active apply for its actual authored constructor. The original three bodies and sampled player stage privately; the existing UI shows a pending request while actual frozen frames and bounded terrain readiness complete. Old state stays held. Success starts paused with the original recipe, poses and current view/cadence; Restart retains the accepted selection. Imported same-label bodies and other physical maps remain outside this route; the later Water Feel route has its own checked owner. Native/host qualifications remain visible, and [local Windows proof](../audits/2026-10-25-lcb003-synchronous-reference-body.md) is not browser acceptance. The subsequent [ordinary synchronous demo route](../architecture/liquid-prepared-setup-and-receipts.md#explicit-ordinary-synchronous-demo-rebuilding) enables **Apply & rebuild active** for Material Lab, Waterworks, Foundry and Neon Works after choosing Exploratory. It retains the exact original recipe, sampled player, ordinary tools and actual quality/view/cadence; it starts paused. **R / Restart world** retains the accepted recipe/policy/normalization/geometry after edits. Choosing an original Current demo retires prepared identity and restores default radius2. A save sharing a demo label is not treated as its authored recipe. Physics Pit/showcase/body routes remain outside this allowlist. The [117-assertion local proof](../audits/2026-10-25-lcb003-ordinary-demo-host.md) includes actual native failure: prepared Restart requires a healthy retained World, so the stopped hint names explicit Current demo/unarmed-import recovery. Same-policy quarantine recovery and final browser/publication remain open. The subsequent [ordinary level-import route](../architecture/liquid-prepared-setup-and-receipts.md#explicit-ordinary-level-import-and-retained-restart) adds two controls in the synchronous normal application's liquid panel. Choose Exploratory, policy, normalization and geometry, then **Use selection for next level import**; the running World stays unchanged. The normal Save/Load Import button then stages an ordinary body-free level and sampled player. It starts paused, and **R / Restart world** reconstructs that accepted input after edits. **Use Current defaults for next import** clears the pending choice; default imports and ordinary demo choices retire prepared identity. Physical/Tower/ showcase imports explicitly refuse. The [local menu proof](../audits/2026-10-25-lcb003-level-import-host.md) is Windows headless execution, with full host and final platform gates open. Unsupported inherited interaction/diagnostic laws and independent transport profiles also refuse before preparation. A known accepted Baseline restart binds its actual native component, generation and applied receipt; existing optional diagnostic telemetry is observational, not an implicit physics-law selection. The subsequent [qualified host-observation foundation](../architecture/liquid-prepared-setup-and-receipts.md#qualified-host-observation-foundation) separates actual API path/current file observations from publication claims and unverified caller values. The [subsequent owner slice](../architecture/liquid-prepared-setup-and-receipts.md#owner-bound-construction-observation) stages it before commit, carries its compact record hash/native receipt identity through normal apply and restart, and retains the old record on refusal. It keeps native/host full matched eligibility false. A Windows editor shadow DLL makes the distinction between API path and mapped module observable. This does not complete another constructor row or qualify

## Q14: Do matching state hashes prove complete deterministic replay, including bodies and future inputs?

Canonical rank: 1

Expected facts:

- No: exact comparisons cover specified repeated or worker-parity cellular fixtures.
- state_hash includes tick/epoch, selected config, cell/activity state and queued explosions but omits relevant external/controller/body state and some settings.
- content_hash excludes scheduling/tick details and is the rest-stability check; neither is complete replay persistence.

### Rank 1: architecture/determinism-and-boundary-transfers.md — Determinism and boundary transfers > Replay state coverage

Document: Determinism and boundary transfers
Path: architecture/determinism-and-boundary-transfers.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native scheduling and hash semantics for declared fixture inputs; explicitly excludes complete replay guarantees
canonical-for: [native-determinism-and-hash-coverage]
last-reviewed: 2026-09-09
Section: Determinism and boundary transfers > Replay state coverage
**Current:** `World::state_hash` and `World::content_hash` use the FNV-style byte mixer in `world.cpp::hash_byte` (seed `1469598103934665603`, multiplier `1099511628211`). The name is not a versioned durable compatibility promise. | Hash | Included | Intended comparison | |---|---|---| | `state_hash` | Attempted/completed tick identity, failed latch and epoch; requested/applied core coverage; selected geometry, sleep/temperature/backend and capacity settings; ordered pending explosions; sorted chunk coordinates; chunk/block activity and quiet counts; cell material/state/epoch and resolved temperature | Same declared native fixture and scheduling state | | `content_hash` | Chunk size and ambient temperature; coordinates, material, compact state and temperature of non-empty/non-ambient cells | Settled content while time and scheduler bookkeeping advance | `state_hash` includes normalized requested/applied interest core coverage (not raw pixel bounds with identical coverage), granular policy version/settings and pending pair deadlines. Mercury opportunities share the global tick modulo lane; excluded ticks create no accumulated movement debt. See the [pair policy](../systems/granular-interaction-policy.md). The existing integer mixer uses native integer widths, including `size_t`. Windows and Wasm hashes are therefore not a cross-platform byte-identity oracle; compare worker counts within the declared platform and compare explicit observed values across those platforms. `state_hash` **omits** liquid-surface-adhesion option, transient obstacles/contact inputs, compiled rule identity and external body/controller state. Worker count is intentionally omitted for parity tests. A matching hash is therefore insufficient to prove that every future-affecting input matches. Record these omitted inputs independently. `content_hash` omits tick/epoch, activity, pending events and ordinary empty/ambient storage. It intentionally cannot detect a change in scheduling or pending behavior. Neither hash captures Rapier solver internals. Full replay requirements and CYSD1 level-byte comparison belong in [level saves versus replay](../reference/level-saves-and-replay.md).


### Rank 2: architecture/determinism-and-boundary-transfers.md — Determinism and boundary transfers > Which ordering is part of simulation semantics?

Document: Determinism and boundary transfers
Path: architecture/determinism-and-boundary-transfers.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native scheduling and hash semantics for declared fixture inputs; explicitly excludes complete replay guarantees
canonical-for: [native-determinism-and-hash-coverage]
last-reviewed: 2026-09-09
Section: Determinism and boundary transfers > Which ordering is part of simulation semantics?
- Global core-coordinate parity assigns four phases. First phase is `tick_index % 4`; a barrier completes every phase before the next. - Rows scan bottom-up with deterministic alternating horizontal direction. Job effects merge in sorted core order, not completion order. - `deterministic_random` hashes coordinates, tick and a rule stream identifier into a byte. It has no mutable global random generator or wall-clock input. - Fixed secondary-interaction lanes are part of the compiled policy. They are exercised by exact fixtures; no global switch disables all such sampling. - Ordinary bounded movement/reactions write directly inside exclusive domains. Their in-place traversal and pairwise arithmetic resolve local competition. Scheduler/storage edges do not create a general transfer queue. See [geometry](chunk-tile-and-buffer-model.md) for domain enforcement and [step order](simulation-tick-and-threading.md) for controller differences. The atomic job distributor may assign different workers without changing these ordering inputs. General completion-order perturbation coverage must be named by an actual test; repeat/worker-count fixtures alone do not prove every schedule.


### Rank 3: operations/testing-validation-and-replay.md — Testing, validation, and replay > What does equality establish?

Document: Testing, validation, and replay
Path: operations/testing-validation-and-replay.md
authority: current-documentation
document-kind: guide
status: Current
scope: Executable test selection and future gates; dated results and save format live in separate references
canonical-for: [test-inventory, test-selection, future-validation-gates]
last-reviewed: 2026-11-24
Section: Testing, validation, and replay > What does equality establish?
Native repeat and worker-count fixtures use `World::state_hash()` for their selected inputs; settled Water uses `content_hash()` plus exact mass checks. Neither hash covers the entire coupled game's future. Their omissions and timing semantics belong to [determinism](../architecture/determinism-and-boundary-transfers.md#replay-state-coverage). CYSD1 and browser benchmark hashes compare serialized level payloads; body restore uses a numeric tolerance. [Level saves and replay](../reference/level-saves-and-replay.md) owns the format and omitted continuation state. Complete replay persistence and a selectable strict runtime policy remain **Planned**.


### Rank 4: reference/level-saves-and-replay.md — Level saves and exact replay > Does an identical save reproduce the next tick?

Document: Level saves and exact replay
Path: reference/level-saves-and-replay.md
authority: current-documentation
document-kind: contract
status: Current
scope: Authored Workbench starts and material-only Flatten, CYSD1 finite-level exchange, native CYPS2–5 continuation, Wave save refusal and remaining full-application replay gaps
canonical-for: [cysd1-level-format, save-import-export, replay-persistence]
last-reviewed: 2026-11-24
Section: Level saves and exact replay > Does an identical save reproduce the next tick?
**Current: no such guarantee.** CYSD1 restores a fixed demo level and selected metadata. Identical re-export proves equality of what the format stores. It does not prove that cells, characters or Rapier will follow the original future trajectory: tick/epoch/activity, complete simulation configuration, pending authoritative events/commands and Rapier contact caches are omitted. Complete durable replay and a selectable strict runtime policy are **Planned** implementations of the **Approved** exact-validation requirement. The native fixture hashes are also incomplete replay identities. Their precise coverage belongs to [determinism](../architecture/determinism-and-boundary-transfers.md#replay-state-coverage). A default-off desktop lockstep fence made one fixture's repeated same-host runs bit-identical, and the desktop game can opt into it with `--lockstep-coupling`. It does not add input capture or a replay format; see [coupled desktop determinism](../architecture/determinism-and-boundary-transfers.md#coupled-desktop-determinism--2026-11-06).


### Rank 5: reference/validation-evidence.md — Validation evidence ledger > What do recording and save passes prove?

Document: Validation evidence ledger
Path: reference/validation-evidence.md
authority: current-documentation
document-kind: reference
status: Current
scope: How to locate and interpret source-bound validation; dated results do not certify a new runtime or every platform
canonical-for: [validation-results, platform-evidence, historical-evidence-boundaries]
last-reviewed: 2026-11-24
Section: Validation evidence ledger > What do recording and save passes prove?
REC-001 observes immutable publications. It can support inspection and comparison of delivered snapshots, but sampling can miss events between publications. It is not complete transient-event capture or a general exact coupled replay. [Recording guidance](../operations/gameplay-recording.md) owns its current modes. Authored starts and material-baseline files preserve the fields their formats actually encode. A Save/Load pass does not prove exact resumed cellular quantities, thermal state, solver history, worker state, body velocity or a complete input timeline. Native physical checkpoint formats have versioned support/refusal contracts of their own; [save/replay reference](level-saves-and-replay.md) owns those distinctions. A physical hash or receipt version is not a blanket claim of complete future-state identity. Configured workers do not prove actual parallel participation. Legacy compatibility getters can be fixed zero/one rather than measured work. A tick serial, a draw counter or a rapidly changing HUD can advance without demonstrating the physical behavior being investigated. Use the named source getter and a physical witness appropriate to the claim.

## Q15: Can the renderer read live cells or reuse a patch buffer before upload finishes?

Canonical rank: 4

Expected facts:

- No: published patches have immutable snapshot or lease-owned lifetime, and the Godot adapter copies values.
- Consumer validates metadata and bytes before Image construction/blit; acknowledgement follows successful consumption.
- Malformed/rejected patches request a full refresh rather than reading mutable World storage.

### Rank 1: systems/themed-construction-materials.md — Themed construction material palette > Appearance boundaries

Document: Themed construction material palette
Path: systems/themed-construction-materials.md
authority: current-documentation
document-kind: reference
status: Current
scope: Complete stable IDs 38–80, authored roles, native hard-surface and combustion behavior, and visual limitations
canonical-for: [construction-material-ids, construction-material-physics-and-finish]
last-reviewed: 2026-10-18
Section: Themed construction material palette > Appearance boundaries
The finishes in the tables are presentation-only programs, with world-anchored courses, seams, and grain. Timber/pipes currently read most clearly horizontally; corrugation is vertical. Rough/hammered metals stay matte; smooth manufactured surfaces can use restrained moving glints. Wet construction and glass finishes are fixed in time (2026-10-18); neon and LED effects use presentation time. Pipes, hazard stripes, insulation, cables, Oak Timber, corrugation, Stained Glass, neon, brick, tile and reinforced concrete adapt to the shape of the run they are painted in (orientation, cross-section, edges); see the [appearance contract](material-appearance-and-rendering.md). None changes physics or wakes cells. Selected finish arithmetic is separate from the common four-neighbor relief stage. Neither creates a second world image or per-cell light. Exact LUT, projection, shader, glow, and full GPU upload semantics belong to the [appearance contract](material-appearance-and-rendering.md).


### Rank 2: systems/material-appearance-and-rendering.md — Material appearance and rendering > Dirty bytes versus GPU upload

Document: Material appearance and rendering
Path: systems/material-appearance-and-rendering.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native RG8 presentation, palette/program LUTs, shader flair, temporal smoothing, glow, and current GPU upload limitation
canonical-for: [material-visual-projection, palette-program-appearance, render-upload-cost]
last-reviewed: 2026-10-19
Section: Material appearance and rendering > Dirty bytes versus GPU upload
[CyberNativeCellWorld](../../godot/native_extension/cyber_native_cell_world.cpp) copies published RG8 patches. [Desktop worker](../../godot/scripts/simulation_worker.gd) retention/acknowledgement prevents a slow consumer losing intermediate updates; bounded full refresh replaces excessive pending copies. The [Web controller](../../godot/scripts/web_demo_controller.gd) consumes synchronously and requests a full refresh after rejection. Pthreads do not create a mutable render read path. [main.gd](../../godot/scripts/main.gd) validates patches and updates a persistent CPU Image, then calls `ImageTexture.update(image)`. At 1024² RG8 this uploads 2,097,152 bytes for each changed publication, even for a small dirty patch. Patch count/copied KiB therefore measures bridge work, not GPU upload traffic. No second mutable world image is introduced by shader neighbor sampling.


### Rank 3: decisions/ADR-003-godot-bridge-and-immutable-snapshots.md — ADR-003: Godot bridge and immutable snapshots > Why require immutable copies?

Document: ADR-003 — Godot bridge and immutable snapshots
Path: decisions/ADR-003-godot-bridge-and-immutable-snapshots.md
authority: current-documentation
document-kind: decision
status: Current
scope: Accepted immutable publication boundary and remaining generalized gameplay bridge work
canonical-for: [decision-immutable-godot-bridge]
last-reviewed: 2026-09-08
Section: ADR-003: Godot bridge and immutable snapshots > Why require immutable copies?
Simulation and presentation progress at different rates and have different object lifetimes. Borrowing mutable native storage makes consumer delay a race or forces rendering to lock authoritative work. Independently owned immutable publication permits delayed/repeated consumption without blocking native rules. The historical render-patch race showed why a writable wrapper described as immutable is insufficient: producer buffer reuse can invalidate payload bytes. The Current desktop implementation deep-copies changed pending generations and validates complete packets before image construction. The [handoff regression](../../godot/tests/test_render_patch_handoff_regression.gd) protects this boundary; historical results remain in the [evidence ledger](../reference/validation-evidence.md).


### Rank 4: architecture/rendering-and-gameplay-bridges.md — Rendering and gameplay bridges > Does a small dirty patch mean a small GPU upload?

Document: Rendering and gameplay bridges
Path: architecture/rendering-and-gameplay-bridges.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native publication outcomes, Godot render consumption and current gameplay commands; resource lifetime and wire layouts are linked
canonical-for: [render-publication-and-gameplay-bridge-behavior]
last-reviewed: 2026-11-24
Section: Rendering and gameplay bridges > Does a small dirty patch mean a small GPU upload?
No. **Current:** [main `apply_render_patches_to_image`](../../godot/scripts/main.gd) validates dimensions, channel count, offsets and exact byte sizes for the full packet before constructing/blitting patches. It updates a persistent CPU Image. `upload_texture_patches` then calls `ImageTexture.update` on the **full** backing image. A 1024×1024 RG8 backing contains 2,097,152 bytes; 2048×2048 contains 8,388,608 bytes. A tiny CPU patch does not reduce the dimensions passed to the full-image update. These are payload sizes, not measured transfer times. Desktop acknowledges a render serial only after successful consumption. Malformed/empty/stale or unacceptable full-refresh data is rejected and requests resynchronization. The worker retains unacknowledged changes and substitutes an explicit full refresh when accumulation exceeds its patch/byte thresholds. The historical handoff race is guarded by [test_render_patch_handoff_regression](../../godot/tests/test_render_patch_handoff_regression.gd). Do not reuse pending buffers while a published generation remains observable. **Current desktop reset identity:** the exclusive GDScript owner advances a World generation only after an accepted World reset or scenario replacement. It retains `render_world_generation` with the exact render publication, forcing a complete replacement payload even when a new World reuses the old revision or paused tick index. The main thread invalidates vapour history only after it successfully uploads that generation. A newer physics/status snapshot carrying an older render publication cannot advance the displayed reset identity. `render_full_refresh` describes transport coverage, not World lifetime. Native resynchronization and ordinary R8 fallback publications can be full images of the same World; they preserve presentation history. Rejected reset requests do not advance the World generation. The [owner regression](../../godot/tests/test_render_world_generation.gd) checks native and fallback paints, resyncs, accepted/rejected resets and repeated identical paused scenario replacements; the [actual-pixel pipeline regression](../../godot/tests/test_material_vapour_pipeline_render.gd) checks the corresponding visible history behavior. Evidence is in the [2026-10-19 review](../audits/2026-10-19-mat002-review-and-validation.md). Temporal smoothing ping-pongs presentation textures. Palette/program LUTs, Water dither, liquid motion, material flair, relief and glow derive appearance without changing cell state. `K` controls presentation smoothing; `H` controls publication cadence. Neither is a strict simulation-accuracy switch. [Appearance](../systems/material-appearance-and-rendering.md) owns shader details. **Planned:** true GPU subregion submission, palette-change records, measured compression/coalescing and tuned production snapshot defaults. Lower native copy volume does not establish any of those features.


### Rank 5: operations/profiling-observability-and-performance.md — Profiling, observability, and performance > Current observations and their limits

Document: Profiling, observability, and performance
Path: operations/profiling-observability-and-performance.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Current native/Godot observations, benchmark procedure, metric boundaries, and unimplemented production telemetry
canonical-for: [performance-measurement, metric-interpretation]
last-reviewed: 2026-10-31
Section: Profiling, observability, and performance > Current observations and their limits
| Observation/source | What it measures | What it does not establish | |---|---|---| | [World::TickStats](../../native/include/cybersand/world.hpp) | Visited/moved cells, activity, scheduled cores, per-phase jobs, deferred events, owned chunk/temperature allocation counts | Per-worker utilization, barrier time, all process allocations | | [World::resident_cell_bytes](../../native/src/world.cpp) | Cell, optional-temperature, and activity capacity bytes | Hash-map/node overhead, all scheduler/snapshot buffers, total RSS | | [RenderSnapshotExchange](../../native/include/cybersand/render_snapshot.hpp) | Required/capacity/high-water patch and byte counts; pressure/failure counts | GPU upload bytes or renderer memory | | [Desktop worker](../../godot/scripts/simulation_worker.gd) | Worker/cellular/snapshot-copy timing, snapshot age, overruns | Synchronous Web timing semantics | | [Desktop controller](../../godot/scripts/main.gd) | FPS, texture update, dirty patch count/KiB, collider timing, body observations, Rapier step/flush | Stable telemetry schema, isolated GPU frame time | | [Web controller](../../godot/scripts/web_demo_controller.gd) | Native tick/upload and profile observations | Independent asynchronous simulation/render owner | “Moved cells” counts successful updates and can include reactions/state changes; it is not a conserved quantity or physical mass. Native facade counters with fallback-like names are not automatically equivalent to fallback activity metrics. The 2026-10-25 [worker activity repair](../audits/2026-10-25-water-inertial-native.md#worker-activity-publication-repair--2026-10-25) adds geometry-bounded per-job signal grids, flag clearing and serial reduction. Its [capacity accounting](../reference/configuration-reference.md) includes real setup storage and work even for jobs that emit no activity signal. Earlier pressure/cache/dormancy timings retain their original source and do not qualify this scheduler's total cost. The follow-up contiguous layout preserves the same payload and clear/reduction work while reducing grid ownership to two buffers per World; its constructor-allocation counts and failure-sweep timings are source-bound correctness evidence, not controlled speedup ratios. The earlier unpacked pressure campaign keeps its own source. The [fresh packed-source repeat](../audits/2026-10-25-water-inertial-native.md#fresh-packed-source-total-cost-repeat) has its own prospective registration, complete total-cost accounting and independent reduction; it retains faster awake warm medians and slower disturbed churn/forced-head intervals, rather than implying a universal improvement. `TickStats` chunk/temperature allocation counters also do not count all ordinary heap allocations; explicit probes and source inspection have their own recorded boundary.

## Q16: If all snapshot slots are still in use or a patch is too large, is dirty data lost?

Canonical rank: 1

Expected facts:

- No: native publish returns Backpressure or CapacityExceeded and preserves unacknowledged dirty state.
- Required patch/byte counts and high-water observations are explicit; no mutable fallback or hidden growth.
- Published slots stay immutable until the final lease releases.

### Rank 1: architecture/rendering-and-gameplay-bridges.md — Rendering and gameplay bridges > What does native publication return under pressure?

Document: Rendering and gameplay bridges
Path: architecture/rendering-and-gameplay-bridges.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native publication outcomes, Godot render consumption and current gameplay commands; resource lifetime and wire layouts are linked
canonical-for: [render-publication-and-gameplay-bridge-behavior]
last-reviewed: 2026-11-24
Section: Rendering and gameplay bridges > What does native publication return under pressure?
**Current:** the single producer serializes publication with World mutation. It copies dirty rectangles in deterministic chunk-coordinate order into preallocated slots, with tightly packed two-byte material/condition rows. The condition byte is a material-selected projection of compact state, not a second authoritative simulation field. | `RenderPublishStatus` | Meaning | Dirty state | |---|---|---| | `Published` | A complete payload fits an unleased slot | Acknowledged after successful capture | | `NoChanges` | Nothing dirty to publish | No lost pending changes | | `Backpressure` | All slots are leased | Retained for later publication | | `CapacityExceeded` | Required patch or byte capacity exceeds a slot | Retained; required counts reported | Slot selection reuses the oldest unleased slot. Publication does not block waiting for consumers. Required counts, high-water use and failure totals are observable. Snapshot capacities are explicit caller choices, not universal production defaults. Native ordinary dirty extraction likewise checks capacity before clearing dirty metadata.


### Rank 2: reference/interfaces-and-message-contracts.md — Interfaces and message contracts > Immutable dirty snapshot contract

Document: Interfaces and message contracts
Path: reference/interfaces-and-message-contracts.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current C ABI, procedural-generation C++/Godot surfaces and private packed layouts; proposed gameplay/reconfiguration contracts remain distinct
canonical-for: [public-and-adapter-interface-layouts]
last-reviewed: 2026-11-24
Section: Interfaces and message contracts > Immutable dirty snapshot contract
**Current native:** `cybersand_render_patch` stores `int64_t` x/y/width/height plus byte offset and row stride. Payload is two bytes/cell: material ID and read-only condition projection. `take_dirty_chunks` with null/insufficient output returns required count without clearing; failure uses `CYBERSAND_SIZE_ERROR`, not zero. `cybersand_world_publish_render_snapshot` returns call success (1/0), separately from its output status: NoChanges=0, Published=1, Backpressure=2, CapacityExceeded=3. Call success therefore does not mean a snapshot published. Result includes serial and required patch/byte counts. `acquire_latest(after_serial)` returns a lease or null; lease bytes remain valid until lease destruction even if the exchange handle is destroyed. Publication must serialize with World. **Current Godot:** six `PackedInt32Array` values per patch are x, y, width, height, byte offset, row stride. Snapshot also carries render serial, channels, full-refresh flag and copied byte array. Native is RG8; fallback is R8. The adapter selects three slots, 64 patches/slot and 2,097,152 bytes/slot for its finite world. These are prototype defaults, not universal production budgets. **Current desktop additive metadata:** `CyberSimulationSnapshot.render_world_generation` identifies the accepted World/reset incarnation represented by the retained render bytes. The exclusive owner increments its counter after successful reset/replacement, then copies it into the pending render generation only when those replacement bytes are published. It is independent of native revision numbers, actor/body epochs, render serials and `render_full_refresh`. Full-image transport resyncs and ordinary R8 fallback frames retain the same World generation. Consumers update their displayed generation only after successful upload of the corresponding render serial; main uses that transition to invalidate vapour history. This is private GDScript snapshot metadata and does not change the native C ABI. See [snapshot fields](../../godot/scripts/simulation_snapshot.gd), [lifetime](../architecture/data-ownership-and-lifetimes.md) and [consumption/failure](../architecture/rendering-and-gameplay-bridges.md).


### Rank 3: operations/configuration-and-capacity-budgets.md — Configuration and capacity budgets > Explosion queue rejection and exhausted simulation space

Document: Configuration and capacity budgets
Path: operations/configuration-and-capacity-budgets.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Existing construction/reservation and capacity outcomes; approved preparation discipline and unimplemented live resize
canonical-for: [capacity-preparation-and-failure, safe-reconfiguration-requirements]
last-reviewed: 2026-09-10
Section: Configuration and capacity budgets > Explosion queue rejection and exhausted simulation space
**Current:** enqueueing too many explosions returns false; accepted events apply at tick entry. Running out of resident or active simulation capacity throws and may leave a partially advanced tick. Such a World is latched failed: subsequent ticks, writes, reservation and publication are rejected until explicit clear or replacement. Accepted events are never automatically replayed. Reserved space reduces allocation pressure; lazy preparation may still allocate chunks or temperature fields. Adapter limits differ from standalone WorldConfig defaults, and live resizing is **Planned**. Avoiding hot tick allocation is an **Approved** requirement; the **Current** zero-allocation evidence is limited to prepared fixtures and their World-owned chunk/temperature counters, not every caller or allocation category. The API-specific outcomes are: | Boundary | Current outcome | Limitation | |---|---|---| | Invalid World construction | Throws before a usable World is returned | Constructor constraints are in `World::World` | | Resident/active chunk or core capacity | Explicit exception | Work may already have mutated this tick; no atomic rollback guarantee | | Explosion queue full/invalid request | Enqueue returns false | Caller must inspect acceptance | | Snapshot slots unavailable | `Backpressure` | Dirty state retained | | Snapshot patch/byte capacity insufficient | `CapacityExceeded`, exact requirements | Dirty state retained | | Native Godot tick exception | Adapter reports false/error once and latches failure | Desktop/Web stop and retain last valid publication; reset/replacement required | | Generalized command/transfer queue | **Planned** | No complete shared queue-pressure contract | Sources: [World](../../native/src/world.cpp), [snapshot publication](../../native/src/world.cpp), and [native adapter](../../godot/native_extension/cyber_native_cell_world.cpp). Core candidates are capacity-checked after deduplication within each chunk; cores spanning several chunks (core larger than chunk) can still count once per chunk before the final sort/unique, so the bound is not always exactly the number of unique output jobs. Before the 2026-11-06 #406 [stress-canvas correction](../audits/2026-11-06-stress-canvas.md) every active activity block counted. The [threading contract](../architecture/simulation-tick-and-threading.md) owns desktop/Web tick-failure handling. **Rejected as a future policy:** silently clipping requested regions, dropping accepted commands/dirty state, or hiding hot growth as safe expansion. These prohibitions are requirements, not a promise that every current failure preserves a pre-tick snapshot.


### Rank 4: operations/profiling-observability-and-performance.md — Profiling, observability, and performance > Avoid common misreadings

Document: Profiling, observability, and performance
Path: operations/profiling-observability-and-performance.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Current native/Godot observations, benchmark procedure, metric boundaries, and unimplemented production telemetry
canonical-for: [performance-measurement, metric-interpretation]
last-reviewed: 2026-10-31
Section: Profiling, observability, and performance > Avoid common misreadings
| Pattern | Next investigation | |---|---| | One core busy, others idle | Phase job count versus dispatch threshold; a persistent pool can intentionally run sparse phases serially | | Small dirty patch KiB but low FPS | Full GPU texture update, synchronization, palette/glow, or unrelated presentation work | | Large collider peak, small Rapier step | Separate geometry extraction, packet copy/validation, and indivisible collider rebuild | | High snapshot pressure/age | Consumer lag and retained dirty payload | | Material appears still after camera return | Check failure status and selected cores against the [pause/re-entry contract](../systems/world-storage-and-interest-region.md#interest-filtering-and-re-entry); retained offscreen activity is not selected work | | Active work never settles | Equivalent state changes, wake feedback, or genuine lifecycle work | | Persistent unresolved body pixels | Bounded ejection exhausted, stale samples, or dense surroundings | | Visually moving surface with stable content | Presentation-time shader motion; inspect authority before changing simulation | The collider consumer's 32-chunk/750 µs limits are checked between chunks and exclude extraction/packet handling; one chunk may exceed the time budget. Only rebuilt chunks count against the chunk limit. The workbench lock-step publishes every hard-surface revision and installs it with a 128-chunk/4 ms budget. The 2026-11-06 [whole-engine benchmark](../audits/2026-11-06-whole-engine-bench.md) shows why: with reacting terrain the 250 ms packet throttle capped a session at about 4 ticks/s. `ImageTexture.update` still uploads the full 2,097,152-byte RG8 image for a changed native publication. Dirty bridge bytes cannot substitute for that cost.


### Rank 5: systems/activity-dirty-regions-and-waking.md — Activity, dirty regions, and waking > Render-dirty lifecycle

Document: Activity, dirty regions, and waking
Path: systems/activity-dirty-regions-and-waking.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native activity and dirty-state lifecycle; separate fallback behavior and future wake requirements
canonical-for: [cell-activity-sleep-wake, simulation-render-dirty-state]
last-reviewed: 2026-11-04
Section: Activity, dirty regions, and waking > Render-dirty lifecycle
[RenderSnapshotExchange::publish](../../native/src/world.cpp) captures dirty rectangles in deterministic chunk order into an available preallocated snapshot slot. Capture clears native dirty state only after every patch is copied. `Backpressure` and `CapacityExceeded` preserve it. A published immutable lease, desktop copied-patch retention, and successful renderer acknowledgement are separate lifetimes. Desktop retains copied unacknowledged patches; Web consumes snapshots synchronously. Their exact ownership is defined by the [render bridge](../architecture/rendering-and-gameplay-bridges.md). An unconsumed snapshot must never be made safe by dropping dirtiness. | State | Meaning | |---|---| | Active block | Eligible for scheduling; it need not produce a write this tick | | Sleeping block | Stored cells remain authoritative and queryable; ordinary scheduling stops | | Render dirty | Committed presentation projection must be captured | | Serialization dirty | **Planned**; no general persistence acknowledgement exists |

## Q17: Dirty rectangles are small, so are we uploading only those pixels to the GPU?

Canonical rank: 3

Expected facts:

- Current RG8 CPU patches are sparse, but ImageTexture.update uploads the whole 1024-square two-byte texture (2,097,152 bytes).
- True GPU subregion upload is not implemented; patch work and GPU upload cost must be measured separately.

### Rank 1: operations/profiling-observability-and-performance.md — Profiling, observability, and performance > Avoid common misreadings

Document: Profiling, observability, and performance
Path: operations/profiling-observability-and-performance.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Current native/Godot observations, benchmark procedure, metric boundaries, and unimplemented production telemetry
canonical-for: [performance-measurement, metric-interpretation]
last-reviewed: 2026-10-31
Section: Profiling, observability, and performance > Avoid common misreadings
| Pattern | Next investigation | |---|---| | One core busy, others idle | Phase job count versus dispatch threshold; a persistent pool can intentionally run sparse phases serially | | Small dirty patch KiB but low FPS | Full GPU texture update, synchronization, palette/glow, or unrelated presentation work | | Large collider peak, small Rapier step | Separate geometry extraction, packet copy/validation, and indivisible collider rebuild | | High snapshot pressure/age | Consumer lag and retained dirty payload | | Material appears still after camera return | Check failure status and selected cores against the [pause/re-entry contract](../systems/world-storage-and-interest-region.md#interest-filtering-and-re-entry); retained offscreen activity is not selected work | | Active work never settles | Equivalent state changes, wake feedback, or genuine lifecycle work | | Persistent unresolved body pixels | Bounded ejection exhausted, stale samples, or dense surroundings | | Visually moving surface with stable content | Presentation-time shader motion; inspect authority before changing simulation | The collider consumer's 32-chunk/750 µs limits are checked between chunks and exclude extraction/packet handling; one chunk may exceed the time budget. Only rebuilt chunks count against the chunk limit. The workbench lock-step publishes every hard-surface revision and installs it with a 128-chunk/4 ms budget. The 2026-11-06 [whole-engine benchmark](../audits/2026-11-06-whole-engine-bench.md) shows why: with reacting terrain the 250 ms packet throttle capped a session at about 4 ticks/s. `ImageTexture.update` still uploads the full 2,097,152-byte RG8 image for a changed native publication. Dirty bridge bytes cannot substitute for that cost.


### Rank 2: reference/glossary.md — Glossary > Publication and physics

Document: Glossary
Path: reference/glossary.md
authority: current-documentation
document-kind: contract
status: Current
scope: Short definitions and canonical routes; implemented types, planned concepts and evidence terms are distinguished
canonical-for: [project-terminology]
last-reviewed: 2026-11-24
Section: Glossary > Publication and physics
| Term | Meaning and canonical route | |---|---| | Dirty | Pending render change bounds; distinct from activity and Planned serialization dirtiness | | Immutable snapshot / lease | Copied publication plus lifetime token; consumer delay cannot mutate bytes. [Lifetimes](../architecture/data-ownership-and-lifetimes.md) | | RenderBridge | Current native leases and copied Godot patches; GPU update remains full texture | | GameplayBridge | Current narrow commands/results; general bounded typed queues Planned | | Backpressure | Native publication finds every slot leased and retains dirty state | | Dirty bytes / upload bytes | CPU packet volume / GPU submission volume, currently different. [Bridges](../architecture/rendering-and-gameplay-bridges.md) | | Body occupancy mask | Separate endpoint body-ID field, not erased/restored material pixels | | Coupling sample / sweep / CCD | Copied pose identity / bounded sampled reconciliation / Rapier cast-shape contact safeguard; adaptive substeps remain Planned. [Coupling](../architecture/rigid-body-and-cellular-coupling.md) |


### Rank 3: systems/material-appearance-and-rendering.md — Material appearance and rendering > Dirty bytes versus GPU upload

Document: Material appearance and rendering
Path: systems/material-appearance-and-rendering.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native RG8 presentation, palette/program LUTs, shader flair, temporal smoothing, glow, and current GPU upload limitation
canonical-for: [material-visual-projection, palette-program-appearance, render-upload-cost]
last-reviewed: 2026-10-19
Section: Material appearance and rendering > Dirty bytes versus GPU upload
[CyberNativeCellWorld](../../godot/native_extension/cyber_native_cell_world.cpp) copies published RG8 patches. [Desktop worker](../../godot/scripts/simulation_worker.gd) retention/acknowledgement prevents a slow consumer losing intermediate updates; bounded full refresh replaces excessive pending copies. The [Web controller](../../godot/scripts/web_demo_controller.gd) consumes synchronously and requests a full refresh after rejection. Pthreads do not create a mutable render read path. [main.gd](../../godot/scripts/main.gd) validates patches and updates a persistent CPU Image, then calls `ImageTexture.update(image)`. At 1024² RG8 this uploads 2,097,152 bytes for each changed publication, even for a small dirty patch. Patch count/copied KiB therefore measures bridge work, not GPU upload traffic. No second mutable world image is introduced by shader neighbor sampling.


### Rank 4: systems/activity-dirty-regions-and-waking.md — Activity, dirty regions, and waking > Render-dirty lifecycle

Document: Activity, dirty regions, and waking
Path: systems/activity-dirty-regions-and-waking.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native activity and dirty-state lifecycle; separate fallback behavior and future wake requirements
canonical-for: [cell-activity-sleep-wake, simulation-render-dirty-state]
last-reviewed: 2026-11-04
Section: Activity, dirty regions, and waking > Render-dirty lifecycle
[RenderSnapshotExchange::publish](../../native/src/world.cpp) captures dirty rectangles in deterministic chunk order into an available preallocated snapshot slot. Capture clears native dirty state only after every patch is copied. `Backpressure` and `CapacityExceeded` preserve it. A published immutable lease, desktop copied-patch retention, and successful renderer acknowledgement are separate lifetimes. Desktop retains copied unacknowledged patches; Web consumes snapshots synchronously. Their exact ownership is defined by the [render bridge](../architecture/rendering-and-gameplay-bridges.md). An unconsumed snapshot must never be made safe by dropping dirtiness. | State | Meaning | |---|---| | Active block | Eligible for scheduling; it need not produce a write this tick | | Sleeping block | Stored cells remain authoritative and queryable; ordinary scheduling stops | | Render dirty | Committed presentation projection must be captured | | Serialization dirty | **Planned**; no general persistence acknowledgement exists |


### Rank 5: architecture/rendering-and-gameplay-bridges.md — Rendering and gameplay bridges > Does a small dirty patch mean a small GPU upload?

Document: Rendering and gameplay bridges
Path: architecture/rendering-and-gameplay-bridges.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native publication outcomes, Godot render consumption and current gameplay commands; resource lifetime and wire layouts are linked
canonical-for: [render-publication-and-gameplay-bridge-behavior]
last-reviewed: 2026-11-24
Section: Rendering and gameplay bridges > Does a small dirty patch mean a small GPU upload?
No. **Current:** [main `apply_render_patches_to_image`](../../godot/scripts/main.gd) validates dimensions, channel count, offsets and exact byte sizes for the full packet before constructing/blitting patches. It updates a persistent CPU Image. `upload_texture_patches` then calls `ImageTexture.update` on the **full** backing image. A 1024×1024 RG8 backing contains 2,097,152 bytes; 2048×2048 contains 8,388,608 bytes. A tiny CPU patch does not reduce the dimensions passed to the full-image update. These are payload sizes, not measured transfer times. Desktop acknowledges a render serial only after successful consumption. Malformed/empty/stale or unacceptable full-refresh data is rejected and requests resynchronization. The worker retains unacknowledged changes and substitutes an explicit full refresh when accumulation exceeds its patch/byte thresholds. The historical handoff race is guarded by [test_render_patch_handoff_regression](../../godot/tests/test_render_patch_handoff_regression.gd). Do not reuse pending buffers while a published generation remains observable. **Current desktop reset identity:** the exclusive GDScript owner advances a World generation only after an accepted World reset or scenario replacement. It retains `render_world_generation` with the exact render publication, forcing a complete replacement payload even when a new World reuses the old revision or paused tick index. The main thread invalidates vapour history only after it successfully uploads that generation. A newer physics/status snapshot carrying an older render publication cannot advance the displayed reset identity. `render_full_refresh` describes transport coverage, not World lifetime. Native resynchronization and ordinary R8 fallback publications can be full images of the same World; they preserve presentation history. Rejected reset requests do not advance the World generation. The [owner regression](../../godot/tests/test_render_world_generation.gd) checks native and fallback paints, resyncs, accepted/rejected resets and repeated identical paused scenario replacements; the [actual-pixel pipeline regression](../../godot/tests/test_material_vapour_pipeline_render.gd) checks the corresponding visible history behavior. Evidence is in the [2026-10-19 review](../audits/2026-10-19-mat002-review-and-validation.md). Temporal smoothing ping-pongs presentation textures. Palette/program LUTs, Water dither, liquid motion, material flair, relief and glow derive appearance without changing cell state. `K` controls presentation smoothing; `H` controls publication cadence. Neither is a strict simulation-accuracy switch. [Appearance](../systems/material-appearance-and-rendering.md) owns shader details. **Planned:** true GPU subregion submission, palette-change records, measured compression/coalescing and tuned production snapshot defaults. Lower native copy volume does not establish any of those features.

## Q18: Are simulation tiles double buffered, and how are writes into a neighboring tile made safe?

Canonical rank: 1

Expected facts:

- Current default is phased in-place: 64-square scheduling cores, four parity phases, bounded radius-two ownership.
- Workers write exclusively within their phase domains and effects merge deterministically.
- A buffered backend enum/name does not mean the planned buffered algorithm or transfer sort tuple exists.

### Rank 1: architecture/chunk-tile-and-buffer-model.md — Chunk, tile, and buffer model > Are simulation tiles double buffered?

Document: Chunk, tile, and buffer model
Path: architecture/chunk-tile-and-buffer-model.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native storage, activity, scheduling and write-domain geometry; explicit fallback and buffered distinctions
canonical-for: [spatial-scheduling-geometry]
last-reviewed: 2026-11-24
Section: Chunk, tile, and buffer model > Are simulation tiles double buffered?
**Planned:** `SimulationBackend::Buffered` reserves a candidate name; `World::tick` currently throws if selected. It is not a runnable rollback. Executable alternatives are SerialInPlace and one-worker PhasedInPlace. The retained design gives only active fields/regions isolated next/output storage, uses read-only neighborhood views, then resolves cross-output effects deterministically. Halo representation, transfer schema, conflict ordering and capacity-recovery behavior remain unspecified. It cannot share mutable ownership of a field with phased updates without a new explicit contract. **Rejected:** full-world double buffering as the ordinary model, per-cell locks, and a second competing liquid world. **Deferred:** alternative coarse-field or hexagonal work experiments; local occupancy coarsening remains Rejected. [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md) explains the selection.


### Rank 2: architecture/chunk-tile-and-buffer-model.md — Chunk, tile, and buffer model > How are writes into a neighboring tile made safe?

Document: Chunk, tile, and buffer model
Path: architecture/chunk-tile-and-buffer-model.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native storage, activity, scheduling and write-domain geometry; explicit fallback and buffered distinctions
canonical-for: [spatial-scheduling-geometry]
last-reviewed: 2026-11-24
Section: Chunk, tile, and buffer model > How are writes into a neighboring tile made safe?
With the Current native defaults, each job scans a 64×64 core and may write within its core expanded by the catalogue maximum radius of two cells. `SchedulerGeometry::phase` uses global core-coordinate parity. Same-phase cores are separated enough that their expanded half-open write rectangles do not share cells; geometry rejects a radius greater than half a core. World also validates compatible chunk/core/activity alignment for its parallel path. See [geometry implementation](../../native/src/scheduler_geometry.cpp). `World::scan_rect` visits cells inside the core; an operation may touch the expanded domain only within the enforced rule radius. Every affected cell must be owned. Out-of-domain attempts are rejected by the operation's checks; they are not automatically enqueued into a transfer system. Later visits may make them eligible. General deferred boundary policies remain **Planned**. The coordinator prepares structural storage before phase dispatch. Jobs mutate cells in place and accumulate local effects; the barrier precedes deterministic metadata merge. No next-state cell array or ordinary movement-transfer record is needed for this backend. A storage or activity edge is not itself an extra physics rule. Boundary fixtures must verify that geometry changes do not introduce unintended seams; intended scan/phase order can still affect results.


### Rank 3: decisions/ADR-002-double-buffered-tile-jobs.md — ADR-002: Benchmark-gated cellular scheduling backends > Why did phased work replace mandatory buffering?

Document: ADR-002 — Benchmark-gated cellular scheduling backends
Path: decisions/ADR-002-double-buffered-tile-jobs.md
authority: current-documentation
document-kind: decision
status: Current
scope: Accepted phased scheduler selection, retained buffered candidate and criteria for reconsideration
canonical-for: [decision-phased-in-place-scheduler]
last-reviewed: 2026-09-08
Section: ADR-002: Benchmark-gated cellular scheduling backends > Why did phased work replace mandatory buffering?
The earlier plan favored isolated next-state output because its concurrent ownership was straightforward. Noita-inspired spatial exclusivity made a lower-traffic option credible: direct bounded mutation avoids per-cell atomics, ordinary movement-transfer records and next-buffer copying. External inspiration did not prove an optimum for CyberSand; the executable phased implementation and measured fixtures supported its provisional selection. No instrumented Buffered comparison exists. Building it is not a prerequisite for further work; a demonstrated field need or unacceptable phased behavior can justify that cost. The historical measurements retain their original scope in the [validation ledger](../reference/validation-evidence.md).


### Rank 4: architecture/module-boundaries.md — Module boundaries > What remains undecided?

Document: Module boundaries
Path: architecture/module-boundaries.md
authority: current-documentation
document-kind: design
status: Approved design
scope: Approved responsibility boundaries mapped to current source; no claim that every named module is a class
canonical-for: [module-responsibilities-and-dependencies]
last-reviewed: 2026-10-21
Section: Module boundaries > What remains undecided?
**Planned:** final class/API extraction, production command/result schemas, stable generalized entity IDs, bounded public rule views, generalized serialization and safe live reconfiguration. Their names are architectural concepts; no signature or failure policy is approved by this page. The rationale is recorded in [ADR-001](../decisions/ADR-001-native-simulation-core.md), [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md) and [ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md). Runtime confidence must come from the [evidence ledger](../reference/validation-evidence.md).


### Rank 5: architecture/chunk-tile-and-buffer-model.md — Chunk, tile, and buffer model > How does a generation chunk relate to simulation geometry?

Document: Chunk, tile, and buffer model
Path: architecture/chunk-tile-and-buffer-model.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native storage, activity, scheduling and write-domain geometry; explicit fallback and buffered distinctions
canonical-for: [spatial-scheduling-geometry]
last-reviewed: 2026-11-24
Section: Chunk, tile, and buffer model > How does a generation chunk relate to simulation geometry?
**Current GEN-001/GEN-002 source:** an opt-in [`generation::Recipe`](../../native/include/cybersand/world_generation.hpp) chooses the square output partition for a procedural proposal. Sampling uses global coordinates, so requesting neighboring chunks in a different order or partitioning the same region does not change its material proposals. Generation neither runs the scheduler nor reads which neighbors happen to be resident. Flow Network and District Grammar derive shared macrocell ports from seed and global topology independently of output chunk size. Theme/brush changes cannot change that topology parameter locally; modules run before the connective skeleton is restored, while a final hard material override can intentionally close a route. These are generated layout relationships, not simulation write domains or new cellular transfer rules. The [generation contract](../systems/procedural-world-generation.md) owns their bounds/precedence; World admission separately requires its configured chunk size and a previously absent destination. Finite Hilbert/Morton tiles, aggregate grains, mask shapes and output chunks are separate spatial partitions. GEN-002 addresses each from absolute coordinates with signed floor division; changing output chunk size does not reset a field tile or grain. Consecutive Hilbert ranks connect only within one finite tile, while Morton ranks are not a continuous route. Neither substitutes for the generator's macrocell port network or the simulation scheduler's write domains. See the [field/curve contract](../systems/procedural-generation-fields-and-modifiers.md). GEN-004 adds a finite authored window of canonical world-zero region addresses. Its `region_size` defines semantic ownership independently of output chunks; changing that grid size intentionally changes the semantic identity namespace. A region-owned building can span many storage chunks. Neighboring regions derive the same shared boundary socket without observing chunk residency, and explicit passages and utility routes carry the cross-region connection. The [hierarchy contract](../systems/procedural-hierarchical-generation.md) distinguishes these finite plans from future persistent-world streaming.

## Q19: Is the world really limited to 1024 pixels or twice the camera size?

Canonical rank: None

Expected facts:

- Native World uses sparse chunks with signed coordinates and explicit capacities; 1024-square is the current demo/save adapter scope.
- The interest region and storage capacity differ; the 2x validation target is not a permanent world-size limit.
- General safe live capacity reconfiguration and sparse persistence remain Planned.

### Rank 1: tools/world-art-capture.md — World Art unattended capture — real Godot PNGs and manifests > Optional bounded streamed full PNG above 50 million pixels

Document: World Art unattended capture
Path: tools/world-art-capture.md
authority: current-documentation
document-kind: guide
status: Current
scope: Production Godot framebuffer capture, streamed PNG transport, provenance and publication safety
canonical-for: [world-art-unattended-capture]
last-reviewed: 2026-11-20
Section: World Art unattended capture — real Godot PNGs and manifests > Optional bounded streamed full PNG above 50 million pixels
The standard Godot `Image` full export is limited to 50,000,000 output pixels. **Explicitly** add `--stream-large` to `--capture` to allow an authored composition to export at up to **100,000,000 output pixels and 65,536 pixels per output axis** without allocating a world-sized output `Image`. The source art adapter still requires at most 16,777,216 native material cells and 16,384 cells per input side. For example, an authored 1024×4096 map at 4× requests a real 4096×16384 (67,108,864-pixel) PNG: ~~~bash python3 tools/world_art_preview_launcher.py --capture --godot=godot \ --pack=/absolute/your/pack.json --shots=full --scale=4 --stream-large \ --output-dir=/absolute/captures/streamed-001 ~~~ Godot renders the original RG8 production shaders into 512-native-cell tiles with a 32-cell halo, writes each exact cropped RGB8 framebuffer tile with SHA-256, then the trusted Python transport verifies and assembles those pixels by scanline with `zlib` into a final RGB PNG. The manifest is marked complete **only after** tile coverage, byte counts and SHA-256, PNG CRC/deflate, pixel length, output dimensions, source identity and source-immutability checks pass. Intermediate RGB files are deleted on success; failed evidence is retained with a failure status. This is streamed PNG *transport*, not a second material renderer. The CLI `--verify-bundle` also validates PNGs in bounded memory. Ordinary capture, viewer screenshots and all `--shots=viewport,detail` remain unchanged. The interactive **Save full** button retains its stricter 50M bound; use this CLI when a truly larger whole-map PNG is required. **No native playable World size, physics or save/load compatibility is inferred from art preview dimensions.**


### Rank 2: tools/world-art-capture.md — World Art unattended capture — real Godot PNGs and manifests > What gets rendered (shots)

Document: World Art unattended capture
Path: tools/world-art-capture.md
authority: current-documentation
document-kind: guide
status: Current
scope: Production Godot framebuffer capture, streamed PNG transport, provenance and publication safety
canonical-for: [world-art-unattended-capture]
last-reviewed: 2026-11-20
Section: World Art unattended capture — real Godot PNGs and manifests > What gets rendered (shots)
`--shots` is a comma list of `full,viewport,detail` (default all three) or `none`. If you pass `--feature`, `--all-features` or `--all-variants` without `--shots`, only the feature shots are produced. | Shot | Output | Controls | | --- | --- | --- | | `full` | Entire combined composition, tiled with a 32-cell halo (no right-edge cutoff), `native size × --scale` | `--scale 1..8` (default 2). Bounded to 50 M output pixels. | | `viewport` | A framed camera view | `--resolution WxH` (default 1920x1080); `--framing fit` (whole map, same as the viewer's Fit) or `native` (1 px/cell); `--zoom Z [--center X,Y]`; or `--view X,Y,W,H` (fit this native-cell rectangle). | | `detail` | A native-cell crop rendered at an exact zoom | `--crop X,Y,W,H` (default: centre half of the map), `--detail-zoom Z` (default: largest integer that fits `--resolution`). | | feature | One reusable feature at a chosen authored variant | `--feature ID[:VARIANT]` (repeatable), `--all-features` (base variants), `--all-variants` (every variant); `--feature-scale 1..8` (default 4). | Presentation settings apply to every shot: `--time SECONDS` (**fixed shader presentation time**, default `1.37`, the viewer's default — animated shaders are therefore repeatable), `--no-glow`, `--no-detail`, `--no-background`. Zoom is limited to 0.03–32 pixels per cell like the viewer. Out-of-range crops/zooms/resolutions fail instead of silently clamping. Feature IDs differ per collection, so use `--all-features` for batches.


### Rank 3: tools/art-pipeline-unification.md — ART-PIPELINE-UNIFICATION-001 — integrated World Art Preview and unattended capture > Compatibility contract (independent limits)

Document: Unified World Art pipeline
Path: tools/art-pipeline-unification.md
authority: current-documentation
document-kind: contract
status: Current
scope: Standalone World Art renderer ownership, art capacity, source provenance and native compatibility boundaries
canonical-for: [world-art-pipeline, world-art-capacity-and-compatibility]
last-reviewed: 2026-11-20
Section: ART-PIPELINE-UNIFICATION-001 — integrated World Art Preview and unattended capture > Compatibility contract (independent limits)
This tooling accepts any **positive, non-square or non-power-of-two** pack size provided `width <= 16384`, `height <= 16384` and `width × height <= 16,777,216`. That is the read-only **art adapter** contract, **not** a change in playable native World size. There is no native simulation allocation, native save-file compatibility claim, water/pressure solver, entity simulation or collision correctness claim. The normal full PNG path uses a bounded Godot output image with **at most 50,000,000 output pixels**, from a source image of at most 16,777,216 native cells. At a larger output scale, `--capture --stream-large` explicitly enables a second **bounded 100,000,000-output-pixel, 65,536-pixel-per-axis** path. Godot draws the **same RG8 production material shaders** in halo-overdrawn tiles and writes source-hashed RGB8 framebuffer bytes. Python only assembles those exact bytes into a standards-compliant RGB PNG using scanline compression; it does not recolour, rasterise or alter geometry. The final PNG is revalidated before any manifest is marked complete. Export scale is explicit. Exports above the selected budget **fail** with a diagnostic, retaining incomplete evidence but never a false completed capture. There is no silent clipping, source downsampling or unbounded full-image allocation. The interactive viewer retains its 50M `Save full` image bound and displays the pixel cost; to produce an over-50M whole-map PNG use the unattended CLI with `--stream-large`. Viewport/detail captures work independently of the full-image budget. | Native input | Native cells | Full 1× | Full 2× ordinary | Full 2× `--stream-large` | | --- | ---: | --- | --- | --- | | 512×512 | 262,144 | Yes | Yes | Yes | | 1024×1024 | 1,048,576 | Yes | Yes | Yes | | 2048×1024 | 2,097,152 | Yes | Yes | Yes | | 1024×2048 | 2,097,152 | Yes | Yes | Yes | | 4096×1024 | 4,194,304 | Yes | Yes | Yes | | 1024×4096 | 4,194,304 | Yes | Yes | Yes | | 512×8192 | 4,194,304 | Yes | Yes | Yes | | 8192×512 | 4,194,304 | Yes | Yes | Yes | | 2048×8192 | 16,777,216 | Yes | **Refused: 67,108,864 pixels** | **Yes: streamed** | | 16384×1024 | 16,777,216 | Yes | **Refused: 67,108,864 pixels** | **Yes: streamed** | The JSON evidence states `previewable`, `full_exportable`, `full_export_mode: framebuffer|streamed|refused`, `requested_output_pixels`, reason when rejected, and `native_playable: "not-qualified-by-art-pipeline"`. Requests above 100M output pixels or 65,536 pixels per streamed axis remain refused. **Art preview support does not grant native gameplay admission**.


### Rank 4: operations/deepworks-exhibition.md — Deepworks — the exhibition below > Four full-size worlds and independent clocks

Document: Deepworks exhibition
Path: operations/deepworks-exhibition.md
authority: current-documentation
document-kind: guide
status: Current
scope: The 1024 by 1024 Deepworks map, sixteen districts, native foreground and rear exhibits, four-plane coverage, controls and authored source programme
canonical-for: [deepworks-exhibition, deepworks-map-controls, deepworks-exhibition-programme]
last-reviewed: 2026-11-16
Section: Deepworks — the exhibition below > Four full-size worlds and independent clocks
Every plane owns a separate **1024 × 1024 native material world**. The displayed map remains 1024 × 1024 in total; the four overlapping planes do not form a 2048 × 2048 terrain or sixteen separately loaded scenes. | Internal plane | UI name | Running target | Authority and coverage | |---|---|---:|---| | `play` | Foreground | 30 Hz | Full map, cleared circulation and sixteen interactive foreground apparatuses. | | `scripted` | Rear reactions & machinery | 20 Hz | Full map, independent rear scenery and sixteen native apparatuses. | | `effects` | Atmosphere | 15 Hz | Authored atmospheric material and bounded local environmental sources across every district. | | `background` | Distant architecture | 0 Hz | Full authored distant map, never ticked; the first copied material publication is cached. | The **rear layer** is the interacting background set: it runs real native material drops, reactions and transport. The fourth plane, whose internal key is `background`, is deliberately frozen distant architecture. Its pixels are rendered through the same canonical material appearance system. Hiding a plane only changes visibility; it does not pause its native clock or source schedule. All districts run together, including those outside the camera. The host serializes adapter calls into its four isolated worlds. Rendering consumes copied RG8 packets, never mutable native storage. Failure of a native step or publication stops the exhibition and freezes presentation; it is not silently replaced with a successful frame. Layer visibility, parallax, relief, haze and liquid reflections do not transfer cells, charge, mass or collisions between worlds. The [depth contract](../systems/depth-layers-and-parallax.md) owns their rendering and publication rules. Source: [`CyberDeepworks.reset_exhibition()` and `_fault()`](../../godot/scripts/exhibition/deepworks.gd), [`CyberDeepworksRuntime`](../../godot/scripts/exhibition/deepworks_runtime.gd) and [`CyberDepthLayerRuntime`](../../godot/scripts/depth/depth_layer_runtime.gd).


### Rank 5: operations/explore001-desktop-playtest.md — Generated-map desktop playtest > Manual acceptance procedure

Document: Generated-map desktop playtest
Path: operations/explore001-desktop-playtest.md
authority: current-documentation
document-kind: guide
status: Current
scope: Accepted generated-map Workbench workflow and manual desktop validation, separate from hosted automation
canonical-for: [explore001-desktop-playtest]
last-reviewed: 2026-11-24
Section: Generated-map desktop playtest > Manual acceptance procedure
1. In Shared Workbench click **New from generator…**, select **gen007-deepworks**, seed **19337**, source origin **0,0**, size **1024**. Generate a preview, inspect its materials, and explicitly install it. On the very first opening, verify both bottom action buttons are on screen. Resize the window and scroll the contents; action buttons should stay visible. 2. Select an existing flyer such as **Midge**, place it in clear terrain, select it under **Pilot**, then press **Play**. Test the displayed movement controls (W/A/S/D for the flyer). Check contact with solid terrain and passage through open routes. Record any stuck actor, unexpected collision or movement issue. 3. Switch the existing free/follow/overview camera controls; pan and zoom. Check that input remains usable and the flyer stays observable. Hosted headless success does not establish camera or movement feel. 4. Pause and use the existing brush to add a solid wall and erase an opening. Resume and check the flyer contacts the new wall and passes through the erased opening. Paint Water; observe motion and flyer interaction without assuming pressure equivalence or a new Water law. 5. Preview another ordinary chunk profile twice, change size, and cancel a partial preview. Check that complete previews contain consistent terrain and cancellation keeps the installed map. Install a completed preview if desired. 6. In the painting row, enter a unique name and click **Save start [Ctrl+S]**. Record source/seed/region, spawn, selected flyer, paint marks and erased opening. Close Godot completely and relaunch through the same checked launcher. 7. Enter the same name and **Load start**. Let native regeneration finish; confirm authored terrain, ordered edits, actor spawn and selection, then continue painting and save again. Close/reopen once more if reporting a bug. 8. Repeat a bounded 512 test and, if resources permit, a 2048 test. Large preparation temporarily retains old and candidate Worlds plus copied grids; measure pauses/memory rather than inferring low cost from bounded size. Report candidate source commit, Windows/GPU, size/profile/seed/origin, exact steps, expected/observed behavior, saved start and original screenshot/log where useful. Report whether the steps were performed by a person, automation or source inspection. Accepted implementation and package qualification do not assert that a particular owner has performed this physical playtest. Original [8 November candidate evidence](../audits/2026-11-08-explore001-integration-qa.md) retains its dated source/runtime scope. <a id="windows-candidate-launch-and-acceptance"></a> The original launch heading remains a compatibility destination. Use the current procedure above; [baseline candidate text](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/operations/explore001-desktop-playtest.md) preserves the earlier package-specific instructions.

## Q20: What happens if I enqueue too many explosions or run out of reserved simulation space?

Canonical rank: 1

Expected facts:

- Explosion enqueue rejects invalid/full input explicitly; effects are tick-boundary bounded work.
- Capacity behavior is API-specific and must be reported. Avoiding hot tick allocation is an Approved target and Current only for preallocated fixture scope; lazy coordinator preparation may allocate chunks or temperature storage.
- WorldConfig capacity defaults are not universal runtime adapter defaults; live resize is not already implemented.

### Rank 1: operations/configuration-and-capacity-budgets.md — Configuration and capacity budgets > Explosion queue rejection and exhausted simulation space

Document: Configuration and capacity budgets
Path: operations/configuration-and-capacity-budgets.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Existing construction/reservation and capacity outcomes; approved preparation discipline and unimplemented live resize
canonical-for: [capacity-preparation-and-failure, safe-reconfiguration-requirements]
last-reviewed: 2026-09-10
Section: Configuration and capacity budgets > Explosion queue rejection and exhausted simulation space
**Current:** enqueueing too many explosions returns false; accepted events apply at tick entry. Running out of resident or active simulation capacity throws and may leave a partially advanced tick. Such a World is latched failed: subsequent ticks, writes, reservation and publication are rejected until explicit clear or replacement. Accepted events are never automatically replayed. Reserved space reduces allocation pressure; lazy preparation may still allocate chunks or temperature fields. Adapter limits differ from standalone WorldConfig defaults, and live resizing is **Planned**. Avoiding hot tick allocation is an **Approved** requirement; the **Current** zero-allocation evidence is limited to prepared fixtures and their World-owned chunk/temperature counters, not every caller or allocation category. The API-specific outcomes are: | Boundary | Current outcome | Limitation | |---|---|---| | Invalid World construction | Throws before a usable World is returned | Constructor constraints are in `World::World` | | Resident/active chunk or core capacity | Explicit exception | Work may already have mutated this tick; no atomic rollback guarantee | | Explosion queue full/invalid request | Enqueue returns false | Caller must inspect acceptance | | Snapshot slots unavailable | `Backpressure` | Dirty state retained | | Snapshot patch/byte capacity insufficient | `CapacityExceeded`, exact requirements | Dirty state retained | | Native Godot tick exception | Adapter reports false/error once and latches failure | Desktop/Web stop and retain last valid publication; reset/replacement required | | Generalized command/transfer queue | **Planned** | No complete shared queue-pressure contract | Sources: [World](../../native/src/world.cpp), [snapshot publication](../../native/src/world.cpp), and [native adapter](../../godot/native_extension/cyber_native_cell_world.cpp). Core candidates are capacity-checked after deduplication within each chunk; cores spanning several chunks (core larger than chunk) can still count once per chunk before the final sort/unique, so the bound is not always exactly the number of unique output jobs. Before the 2026-11-06 #406 [stress-canvas correction](../audits/2026-11-06-stress-canvas.md) every active activity block counted. The [threading contract](../architecture/simulation-tick-and-threading.md) owns desktop/Web tick-failure handling. **Rejected as a future policy:** silently clipping requested regions, dropping accepted commands/dirty state, or hiding hot growth as safe expansion. These prohibitions are requirements, not a promise that every current failure preserves a pre-tick snapshot.


### Rank 2: architecture/determinism-and-boundary-transfers.md — Determinism and boundary transfers > How are explosions and future transfers ordered?

Document: Determinism and boundary transfers
Path: architecture/determinism-and-boundary-transfers.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native scheduling and hash semantics for declared fixture inputs; explicitly excludes complete replay guarantees
canonical-for: [native-determinism-and-hash-coverage]
last-reviewed: 2026-09-09
Section: Determinism and boundary transfers > How are explosions and future transfers ordered?
**Current:** `ExplosionCommand` stores signed centre coordinates, bounded positive radius and byte collapse strength. Enqueue rejects invalid bounds or a full preallocated queue or failed world by returning false. Accepted events commit in enqueue order during `begin_tick`, before active work gathering. The blast removes its core, writes Fire at an available centre and converts eligible Wall in the two-cell shell into granular Stone (`state_b = 1`). Event-written cells carry the current epoch and start ordinary material execution next successful tick. If that attempt fails, the World is quarantined and cannot replay events; explicit reset/replacement discards the failed state and any retained pending batch. **Planned:** buffered transfers and generalized worker-produced fracture, structural or long-range events. Their schema, canonical sort tuple and conflict rules are not approved by the existing explosion queue. The reserved Buffered backend cannot run. Accepted future transfers must have explicit conservation, capacity and conflict semantics; worker timing is not a permissible resolver.


### Rank 3: architecture/simulation-tick-and-threading.md — Simulation tick and threading > What happens when a tick fails or overloads?

Document: Simulation tick and threading
Path: architecture/simulation-tick-and-threading.md
authority: current-documentation
document-kind: contract
status: Current
scope: Desktop, Web and native stage ordering, fixed quanta, failure behavior and permitted thread access
canonical-for: [simulation-step-order-and-threading]
last-reviewed: 2026-11-24
Section: Simulation tick and threading > What happens when a tick fails or overloads?
**Current, chosen for issue #1:** a thrown tick latches `World::has_failed()`. There is no transactional rollback. Tick/epoch, accepted explosion edits, dirty metadata, chunk preparation and even earlier completed phases may already have changed. `tick_index()` identifies the attempted tick; `completed_tick_index()` advances only after successful execution and activity finalization. No partial `TickStats` is returned as success. See [ADR-010](../decisions/ADR-010-failed-tick-quarantine.md). Failure clears the in-progress guard after any dispatched phase has drained. Further ticks, gameplay writes, reservations and snapshot publication are rejected. Serialized reads remain diagnostic access to partial state, not a valid save or playable continuation. The last successful immutable lease remains usable. Accepted explosions apply in enqueue order at tick entry. A completed batch drains; if application itself throws, the retained batch may include applied or partial events. Neither batch is ever automatically replayed: the world cannot be retried. An explicit `clear()` discards cells, activity, pending events, masks and tick identity, retains construction options/latest requested region, and permits fresh setup. Destruction/reconstruction is the other native recovery path. No allocation failure, capacity change or camera move implicitly recovers a world. **Current desktop:** the exclusive GDScript owner checks native false, latches failure and publishes a fresh status wrapper around its previous valid publication. It withholds partial character, cell, terrain and body results, rejects new emissions and clears pending prototype emissions. The pacing thread stays alive to receive reset; main-thread Rapier stops when the failure status is observed. This is asynchronous notification, not rollback of Rapier or character work that preceded the fault. The fallback's void successful tick path is unchanged. **Current Web:** the synchronous owner pauses, opens the menu, reports restart/load recovery, and suppresses painting, ticks, terrain/render publication and further Rapier stepping while failed. Closing the menu or toggling pause cannot retry. Rapier's preceding step is not rolled back. Reset/restart or a validated saved-level replacement creates fresh activity and clears the fault; invalid import preserves it. The adapter returns `false` with first-error telemetry, zeroes unsuccessful tick statistics, exposes attempted/completed identity separately, and does not count rejected repeat calls as new failures. Its reset prepares a candidate before swap. Godot level export rejects failed state; CYSD1 replacement is level recovery, not exact replay. Region/configuration requests cannot wake or advance a failed World. Native region requests may be latched; the Waterwall adapter's stricter failed-setting admission is described below. **Rejected for this fix:** rollback, automatic retry, resuming partial state and silent event replay. **Planned separately:** state-preserving live capacity growth and complete replay. [Dated regression evidence](../audits/2026-09-08-issue-1-failed-ticks.md) separates source tests, Windows owners and browser coverage. Eligible native transport runs each tick;


### Rank 4: architecture/simulation-tick-and-threading.md — Simulation tick and threading > Current native scheduler

Document: Simulation tick and threading
Path: architecture/simulation-tick-and-threading.md
authority: current-documentation
document-kind: contract
status: Current
scope: Desktop, Web and native stage ordering, fixed quanta, failure behavior and permitted thread access
canonical-for: [simulation-step-order-and-threading]
last-reviewed: 2026-11-24
Section: Simulation tick and threading > Current native scheduler
Source: [World `begin_tick`, `tick_phased`, `finish_tick`, `tick`](../../native/src/world.cpp). 1. Increment tick and compact update epoch; clear all cell epochs at wrap. Reset change observations and apply phased interest transitions in the same metadata pass, then apply queued external explosions in enqueue order before gathering active work. Event-written cells carry this epoch and begin ordinary material rules on the following tick. 2. Gather eligible cores. For each of four phases, starting at `tick_index % 4`, prepare write-domain storage and job-local results before dispatch. 3. Execute same-phase exclusive jobs, using the persistent pool only when the configured job threshold is met. Wait for completion, then merge local effects in deterministic core order before the next phase. 4. Finalize activity/sleep only for fully eligible blocks (retaining excluded activity), then statistics. Mark completed tick identity only on success. Render publication is an explicit caller operation after serialized mutation, outside `World::tick`; failed Worlds reject publication. Geometry and write restrictions are defined in [chunk/tile model](chunk-tile-and-buffer-model.md); scan/random/merge semantics and hash limits belong in [determinism](determinism-and-boundary-transfers.md). `SerialInPlace` is executable. `Buffered` throws as unimplemented.


### Rank 5: reference/invariants.md — Architectural and simulation invariants > Current baseline invariants

Document: Architectural and simulation invariants
Path: reference/invariants.md
authority: current-documentation
document-kind: contract
status: Approved design
scope: Stable review IDs with current enforcement, known exceptions and approved requirements; this register is not a test-result ledger
canonical-for: [invariant-register]
last-reviewed: 2026-11-24
Section: Architectural and simulation invariants > Current baseline invariants
| ID | Status and narrow claim | Authoritative contract | |---|---|---| | CUR-001 | Current: desktop owner and Web main-thread owner each coordinate one selected world/character | [Threading](../architecture/simulation-tick-and-threading.md) | | CUR-002 | Current: rendering consumes copied bytes, never mutable cells | [Lifetimes](../architecture/data-ownership-and-lifetimes.md) | | CUR-003 | Current: phased core/phase/effect order is deterministic | [Ordering](../architecture/determinism-and-boundary-transfers.md) | | CUR-004 | Current: native default chunk size is 128; compatible configured sizes are permitted | [Geometry](../architecture/chunk-tile-and-buffer-model.md) | | CUR-005 | Current: desktop may select fallback; Web requires native; no synchronized second authority | [Architecture](../architecture/overview.md) | | CUR-006 | Current default catalogue: every valid ID has descriptor/kernel selection and radius ≤2; inert entries use no rule. Opt-in Brine IN and isolated Water IN separately require radius3 | [Materials](../systems/materials-and-rule-kernels.md) | | CUR-007 | Current: accepted external explosions commit in enqueue order at tick entry and are hashed while pending | [Ordering](../architecture/determinism-and-boundary-transfers.md) | | CUR-008 | Current: native leased bytes stay immutable; publication pressure retains dirty state | [Lifetimes](../architecture/data-ownership-and-lifetimes.md) | | CUR-009 | Current: rectangle samples create separate endpoint occupancy and bounded observations | [Coupling](../architecture/rigid-body-and-cellular-coupling.md) | | CUR-010 | Current correction: fallback forces adaptive stride=1 and deferred count=0; old load-driven block deferral is absent; optional sparse flight remains | [Activity](../systems/activity-dirty-regions-and-waking.md) | | CUR-011 | Current fallback: downward Empty movement leaves the vacated source unstamped, enabling fill chains | [Fallback rules](../systems/materials-and-rule-kernels.md) | | CUR-012 | Current: themed 38–80 are hard surfaces; inert radius zero, Oak/Thatch radius-one combustible | [Construction](../systems/themed-construction-materials.md) | | CUR-013 | Current: flair uses immutable display inputs and cannot write Cell state | [Appearance](../systems/material-appearance-and-rendering.md) | | CUR-014 | Current: neighbor relief samples the existing uploaded texture without a second authoritative image/readback | [Appearance](../systems/material-appearance-and-rendering.md) | | SAVE-001 | Current: CYSD1 reconstructs a level and selected metadata; no exact continuation | [Saves/replay](level-saves-and-replay.md) | | REPLAY-001 | Approved, incomplete: replay must capture every future-affecting input; current hash coverage is partial | [Hash coverage](../architecture/determinism-and-boundary-transfers.md#replay-state-coverage) | | WEB-001 | Current: pthread jobs do not remove Web's synchronous main-thread tick wait | [Threading](../architecture/simulation-tick-and-threading.md) |

## Q21: Does native Water move twenty-four cells per update, and what does viscosity mean?

Canonical rank: 4

Expected facts:

- The 24-cell travel rule belongs to the discrete GDScript fallback, not native Water.
- Native Water stores 1-255 mass in state_a and performs conserved pairwise gravity/diagonal/lateral transfers.
- Viscosity scales native lateral transfer rate independently of yield and adhesion; Water viscosity is zero.

### Rank 1: architecture/lcb-pressure-inertial-handoff.md — LCB pressure and inertial implementation handoff > Inertial (`inertial_cellular_v1`, #212)

Document: LCB pressure and inertial implementation handoff
Path: architecture/lcb-pressure-inertial-handoff.md
authority: current-documentation
document-kind: design
status: Approved design
scope: LCB-001 pressure/W-CY and shared-native handoff plus Planned LCB-005 inertial requirements — material hooks, state, laws, boundaries, invalidating failures and campaign APIs; detailed setup/receipt/accounting codecs have their own canonical owner
canonical-for: [lcb-pressure-inertial-handoff]
last-reviewed: 2026-10-25
Section: LCB pressure and inertial implementation handoff > Inertial (`inertial_cellular_v1`, #212)
**What it must add.** Retained motion between ticks. "Faster CellularYield" is **not** inertia: `flow_as_yielding_liquid` (L2779) only changes a per-update lateral probability, `(256−viscosity)/256`, and keeps no velocity (mechanism report §E). **State** (optional, per owning cell): - signed vx/vy in fixed point (e.g. 1/16 cell per tick; width frozen per Gate B before code); - signed subcell accumulators; - saturation at a declared maximum (≤ the bounded write radius per tick); - default 0, and reset to 0 on product, paint or reconstruction. **Laws:** one ordered update, `inertial-update-v1` ([transition matrix §5](liquid-state-transition-matrix.md#5-velocity-and-momentum-in-pf-flow); executable contract model `tools/lcb/inertial_contract.py`). Per tick: 1. U1: the support test runs before any velocity change. 2. U2: exactly one gravity application. 3. U3: for a supported cell, either diagonal re-aim **(A)**, or support cancellation of this tick's gravity followed by blocked-fall deflection **(B)** of the velocity *carried in* from earlier ticks. 4. U4: saturation. 5. U5: damping, truncated toward zero. 6. U6: accumulator travel with a recheck of every target. The first contact ends travel. Wall, body mask and same-material cells block; same-material contact is inelastic in v1. Lighter foreign material may still exchange only on eligible downward moves, including when both materials select IN. Family equality alone does not make a foreign material an inelastic same-material contact. 7. U7: rest and sleep eligibility. Properties of this update: - **Horizontal momentum from rest comes only from (A) and (B).** There is no pressure or column-height term. - **A supported cell at rest whose diagonals are blocked carries no `vy`, so it never drifts sideways.** If a diagonal target is eligible, U3a re-aims from rest by design. The mandatory static closed-pool regression is unchanged. - **Eligibility is directional** (re-review N1). A lighter foreign liquid is entered only by a move with `dy = +1`, straight or diagonal down, which is the vertical density exchange of Current `can_density_exchange`. A horizontal move never swaps; a lighter neighbour is a horizontal contact. - **Deflection loss** (re-review N2) is `|vx| + vy_in − |vx + s·d|`. The signed impulses `(s·d, −vy_in)` are booked separately. - At a released dam, face cells whose diagonal target becomes Empty re-aim and gain vx. Cells that fall farther carry more speed into the turn or the landing, so depth dependence *can* emerge kinematically, but it is not guaranteed. Ledgers: - the **signed per-component momentum** ledger `v_after = v_before + g + Σ impulses` closes exactly; - a **separate non-negative L1 speed-loss** ledger books dissipation and the support constraint; - truncation remainders are audited. Also: - no velocity is written


### Rank 2: architecture/lcb-pressure-inertial-handoff.md — LCB pressure and inertial implementation handoff > Shared integration points (both families)

Document: LCB pressure and inertial implementation handoff
Path: architecture/lcb-pressure-inertial-handoff.md
authority: current-documentation
document-kind: design
status: Approved design
scope: LCB-001 pressure/W-CY and shared-native handoff plus Planned LCB-005 inertial requirements — material hooks, state, laws, boundaries, invalidating failures and campaign APIs; detailed setup/receipt/accounting codecs have their own canonical owner
canonical-for: [lcb-pressure-inertial-handoff]
last-reviewed: 2026-10-25
Section: LCB pressure and inertial implementation handoff > Shared integration points (both families)
| Need | Where today | Requirement | |---|---|---| | Per-World policy | `WorldConfig::liquid_solver_policy` beside `WaterExperimentPolicy` | **Current foundation (2026-10-24):** `LiquidSolverPolicy` with the [canonical hashing](liquid-solver-family-policy.md#native-policy-object-proposed), validated before allocation ([foundation](liquid-solver-family-policy.md#native-policy-foundation-current-2026-10-24)). **Current on main:** Water × `pressure_flow_v1/reference` with one optional family block. Accepted main also qualifies Water × `cellular_yield_v1/reference` with its v2 viscosity block. Further candidate families must extend the running build's qualified cells and schemas. | | Construction | Native `PreparedWorldBuilder`; bridge `build_liquid_policy_world`; other #202 constructors | Native explicit normalization and actual payload/quantity checks occur on an unexposed candidate. Native-issued outcome preserves retained World/generation. Godot typed normalization opt-in and remaining #202 constructors are Planned. | | Family dispatch | `update_rule_kernel` L2829 (`RuleKernel` switch), after generic pair chemistry L2797 | Dispatch motion by family only for liquids with a non-default assignment. Keep stages 1, 2, 4 and 5 from the [material hooks](liquid-solver-family-policy.md#material-hooks-versus-motion-gate-c-correction-2026-10-23) unchanged. **Current on main:** `RuleKernel::Water` calls `update_water_pressure` in a pressure World; accepted main also dispatches W-CY explicitly. | | Moves and swaps | `move_cell` L2323, `try_move` L2446, `transfer_water` L2481, `relocate_stored_cell` L1840 | Optional state moves atomically with its tuple; retired on Empty/conversion (R1). | | Writes and products | `write_cell`, `set_cell_state`, generic pair products | Current native: reset family state even for same-material products, retain family-only mutation witnesses, book gross visible+overfill Water and initialized output per catalogue rule; separate material populations. | | Transport coupling | `mix_after_motion` L2568 | Called with the real moved quantity (`maximum()` for a whole cell). | | Body masks | `transient_obstacle_at`, `update_cell` L3500 skip | Masks are solid for motion and head. No new Rapier force. | | Scheduling | `begin_tick` L3524+, block sleep after 3 quiet ticks | Sleep only when family state is at rest. Count work by visited cells and scheduled cores, not active-chunk flags (mechanism report §C). | | Hashing/persistence | `physical_state_hash`, `save_physical_state`, `restore_physical_state` | Current main native hash2/CYPS2 include shared accounting and construction bindings; historical content/state hashes unchanged; old CYPS1 explicitly refuses ([definition](pressure-flow-v1.md#physical-state-hash-v2)). | **APIs required to unblock the registered tests** (in `lcb-physics-contracts.json`): - policy readback (Current foundation; the #245 pressure adapter adds `family_parameters`); - versioned physical-state hash (`get_physical_state_hash()`, Current main version 2); - `inspect_cell` extended with family state (`family_state` in pressure Worlds, Current on main); - `inspect_gas_compartments()` returning id, generation, ancestry, amount, volume, vent state and topology revision (Current on main); - native bounded per-reaction quantity aggregates and separate material-cell counts (not ordered replay); #202 owns their complete host collection; - a front/centroid observation metric (optional; the tests currently scan with `material_at`).


### Rank 3: reference/configuration-reference.md — Configuration reference > Desktop fallback simulation constants

Document: Configuration reference
Path: reference/configuration-reference.md
authority: current-documentation
document-kind: reference
status: Current
scope: Exact native, adapter, fallback, presentation, and Web defaults; construction constraints and unimplemented production schema
canonical-for: [current-configuration-values, adapter-worker-policy]
last-reviewed: 2026-11-24
Section: Configuration reference > Desktop fallback simulation constants
Source: [cell_world.gd](../../godot/scripts/cell_world.gd). These are not native Water/activity semantics; the Web compatibility profile still uses native cells. | Exact name | Value | |---|---:| | `WORLD_WIDTH` / `WORLD_HEIGHT` | 1024 / 1024 | | `ACTIVITY_BLOCK_SIZE` / `CELL_SLEEP_TICKS` | 16 / 8 | | `SPARSE_FLIGHT_ACTIVE_BLOCK_THRESHOLD` / `SPARSE_FLIGHT_DISTANCE` | 12 / 2 | | `FREE_LIQUID_LATERAL_FLOW` | 255 (directed-flow sentinel, not native mass) | | `YIELDING_LIQUID_LATERAL_BUDGET` / `YIELDING_LIQUID_PRESSURE_YIELD` | 6 / 1 | | `PASTE_LIQUID_LATERAL_BUDGET` / `PASTE_LIQUID_PRESSURE_YIELD` | 3 / 3 | | `WATER_VISCOSITY` / `SLUSH_VISCOSITY` / `PASTE_VISCOSITY` | 0 / 192 / 240 | | `MAX_LIQUID_LATERAL_FLOW_RATE` | 24 cells per serial update | | `COHERENT_LIQUID_LATERAL_FLOW_RATE` | 1 | | `WATER_SURFACE_ADHESION` / `SLUSH_SURFACE_ADHESION` / `PASTE_SURFACE_ADHESION` | true / true / true | | `LIQUID_PRESSURE_SAMPLE_DEPTH` / `LIQUID_LEVEL_SEARCH_DISTANCE` | 32 / 256 | The threshold enables isolated-cell alternate-tick free flight, not the removed load-derived block stride. Current fallback reports stride one and zero deferred blocks; excluded blocks retain wake flags. Native Water's three-quarter lateral mass-difference relaxation, 12-tick coherence delay, 48-unit supported-film threshold and separate fallback mechanics belong to the [Water contract](../systems/water-design.md). Material cadence, including specialized Ice sampling, belongs to [material kernels](../systems/materials-and-rule-kernels.md#kernel-execution-and-cadence).


### Rank 4: systems/water-design.md — Water design > Current native representation and flow

Document: Water design
Path: systems/water-design.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current Water-family routing and player defaults; scoped FreeMass mechanics, quantity accounting, historical negative controls and fallback differences
canonical-for: [native-water-semantics, native-fallback-water-differences]
last-reviewed: 2026-11-24
Section: Water design > Current native representation and flow
**Scope: original `freemass_v1`, without Wave.** The following 255-unit capacity, local transfer and no-direction rules describe that path only. Wave can retain overfill and face flux; IN and ballistic parcels carry their own motion. [World::update_water and transfer_water](../../native/src/world.cpp) own the rules; [MaterialRules](../../native/include/cybersand/material.hpp) supplies immutable descriptors. | Value | Meaning | |---|---| | Material ID 3, `state_a` 1–255 | Water with that many fixed-point mass units | | Empty | Zero Water mass | | `state_b` | Remaining coherent-emission lateral delay | | Viscosity | Dimensionless gameplay rate; Water uses 0, the fastest setting | | Lateral rest tolerance | No lateral transfer when source mass is at most target mass + 1 | | Lateral relaxation | Request three quarters of the positive mass difference, rounded down | Painting ordinary Water initializes a full 255-unit cell. Gravity attempts down, then both diagonals in deterministic order. It merges into Water or moves/swaps whole cell state into a permitted destination; directional density exchange lets Water move through lighter accepting media. Lateral equalization requests three quarters of the positive mass difference, scaled by viscosity. This crosses the pair midpoint but contracts its imbalance; the one-unit rest tolerance remains. A transfer is capped by the requested amount, source mass, and destination capacity. Zero remaining source mass converts the source to Empty. Water has no persistent native lateral direction or travel budget. Transfers stay inside the phase-owned bounded write domain and mark source/destination activity and render dirtiness. Viscosity does not expand the kernel radius.


### Rank 5: architecture/liquid-solver-family-policy.md — Liquid solver family policy and API specification > Material hooks versus motion (Gate C correction, 2026-10-23) > Whole-cell Water law (Current main)

Document: Liquid solver family policy and API specification
Path: architecture/liquid-solver-family-policy.md
authority: current-documentation
document-kind: design
status: Approved design
scope: Current-main four-family identities, immutable per-World per-material policy, material/variant admission and readback, W-CY material block v2 and IN family block v2; historical design checkpoints and source/platform qualification remain separately scoped
canonical-for: [liquid-solver-family-policy]
last-reviewed: 2026-11-24
Section: Liquid solver family policy and API specification > Material hooks versus motion (Gate C correction, 2026-10-23) > Whole-cell Water law (Current main)
`World::update_water_cellular_yield` keeps material identity, generic pair chemistry, coherence countdown, density exchange, temperature, body contact and actual-moved-mass coupling. Its stage 3 moves whole tuples only: gravity then diagonals, followed by cadence-gated lateral yield into Empty. There is no same-Water merge, FreeMass relaxation, fractional adhesion film or Paste/Slush-descriptor fallback. Every Water cell contains `maximum()`. [`WaterCellularYieldParameters`](../../native/include/cybersand/water_cellular_yield.hpp) declares law version 1 and optional Water material block **version 2**: `viscosity_index` 0..255, default 0. The deterministic lateral roll succeeds with probability `(256 - viscosity_index) / 256`. Coherence suppresses lateral motion for its full delay while gravity remains responsive. Configured Water cadence and one-/two-side transport settings retain their own meanings. A legal future side keeps an interaction deadline when cadence defers work, a viscosity roll misses, or one-side sampling chooses the blocked side. Thus a slow/stochastic lane cannot sleep permanently before its next opportunity; permanently blocked pools can still reach ordinary block sleep. Regressions are [`test_water_cellular_yield.cpp`](../../native/tests/test_water_cellular_yield.cpp), including liveness, material hooks and 1/4-worker continuation. Fractional ingress, explicit normalization and exact source/sink accounting are owned by [native prepared setup](liquid-prepared-setup-and-receipts.md).

## Q22: How do calm water emission and the adhesion toggle differ?

Canonical rank: 1

Expected facts:

- Calm/coherent emission uses an explicit command flag and a 12-tick state_b delay on lateral spread, not a new material.
- The native adhesion toggle independently retains supported Water film at or below 48/255 when enabled.
- Viscosity, yield and adhesion are distinct; fallback rules differ.

### Rank 1: systems/water-design.md — Water design > Coherent emission and surface adhesion

Document: Water design
Path: systems/water-design.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current Water-family routing and player defaults; scoped FreeMass mechanics, quantity accounting, historical negative controls and fallback differences
canonical-for: [native-water-semantics, native-fallback-water-differences]
last-reviewed: 2026-11-24
Section: Water design > Coherent emission and surface adhesion
**Scope: the original FreeMass kernel.** Other families own their corresponding coherence, saturation and film rules; the Wave guide documents its derived film adhesion and spill behavior. Coherent/calm emission is a command flag on Water, not a second material ID. [CyberNativeCellWorld::emit_disc](../../godot/native_extension/cyber_native_cell_world.cpp) initializes a 12-tick countdown. It travels with mass; merging takes the larger delay. The current update decrements it but uses its pre-decrement value to suppress that update's lateral equalization. Gravity and density exchange still operate. Later edge falls regain ordinary spray after the delay expires. Adhesion is independent of viscosity and emission mode. When enabled, remaining Water mass at or below 48/255 skips lateral spreading if the cell below is neither Empty nor Water. Gravity was already attempted. Disabling adhesion removes that supported-film threshold; it does not select a different gravity solver. **Approved owner intent:** preserve fast fronts, airborne spray, and supported slope film as useful behavior. Paste/Slush intentionally retain heap-capable whole-cell yield. Per-material native adhesion traits remain **Planned**. <a id="conservation-stable-rest-and-the-correct-hash"></a>


### Rank 2: architecture/wave-flow-v1.md — Wave flow Water solver (experimental) > The law > Coming to rest

Document: Wave flow Water solver (experimental)
Path: architecture/wave-flow-v1.md
authority: current-documentation
document-kind: reference
status: Current
scope: Current Wave Flow law, player defaults, bulk strip-parallel execution, admission, state and memory
canonical-for: [wave-flow-v1]
last-reviewed: 2026-11-20
Section: Wave flow Water solver (experimental) > The law > Coming to rest
Law version 1 never came to rest once it had been disturbed. Each face rounded its sub-unit flux to whole units with an independent random threshold. Across the 32 responding rows that is about ±3 units of noise per face per round, and the solver's deliberately low damping (1/128) amplified it into a permanent slosh: adjacent columns traded about 25 units every few ticks, for ever. Only a level pool that nothing had ever touched stopped being solved. Version 2 makes rest reachable with four rules, none of which adds stored state: | Rule | Value | What it does | |---|---|---| | Additive rounding | sequence over rows and rounds, per-column offset | Spreads thresholds to reduce the observed sampling noise; a constant flux has the same average over 4096 round phases, and rows remain out of step | | Calm band (`kCalm`) | flux below ⅛ unit per round loses ⅛ per round | Absorbs what rounding leaves behind. A real wave is in this range only near its turning points, where its energy is in the heads | | Rest rule (`kRestHead`, `kStick`) | heads within 1 unit and flux in the calm band → flux is discarded | Removes small momentum that would only flip a one-unit step; larger flux still follows the inertial law | | Films | two partly filled cells on a solid floor exchange about ¼ of their difference with no momentum, while the donor exceeds the adhesion threshold and the difference exceeds 1 unit | Removes the long-lived creep of supported films; adhesion can leave an uneven residue | Rest is exact: no cell changes and every retained flux is zero. That state is a fixed point of the three passes, so a chunk at rest can stop being solved without changing any later result. Measured consequences are in the [completion record](../audits/2026-11-15-wave-mt-001-completion.md#2026-11-15-claude-review-rest-and-identity-repair). The costs are deliberate and bounded. The rested pool regressions allow neighbouring column totals to differ by one unit (1/255 of a cell). Supported adhesion residue can remain more uneven, as described below. Ripples whose flux never leaves the calm band (roughly 8 units of amplitude, 3% of a cell) die within tens of ticks instead of fading slowly. A film has no waves at all.


### Rank 3: MATERIAL_LAB.md — 1024² material lab > Desktop controls

Document: 1024² material lab
Path: MATERIAL_LAB.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Desktop and Web manual controls, repeatable interaction observations, construction recipes, and finite-demo limits
canonical-for: [material-lab-controls, manual-material-recipes]
last-reviewed: 2026-11-11
Section: 1024² material lab > Desktop controls
The detailed [Neon Reliquary demo](operations/neon-reliquary-demo.md) is available through **F11** or its launcher. It opens a paused machine-cathedral scene with five viewpoints; **F8** supplies a clean view and **P** resumes its materials. **Below / Above** and the district selector navigate its four-tile descent: Neon Reliquary, Middle Cyberberbia, Sewertech Alley and Industrial Underswamp. Changing district loads that tile's original paused layout; changing its camera view preserves edits. **Shift+F11** or **Blacksite Nine** opens the separate [connected 3×3 complex](operations/blacksite-nine-demo.md). Use its **3×3 tile map** to frame any district, **Whole complex** for the overview, and **F** to follow the player. A/D and held Space move through the twelve connecting galleries and shafts. Tile framing preserves edits everywhere; **R** restores the entire nine-tile world. Source: [main.gd::_unhandled_key_input, update_camera, update_worker_frame_state](../godot/scripts/main.gd). | Control | Effect | |---|---| | LMB / RMB | Emit selected material / erase | | A / D; Space | Move character left/right; jetpack | | Arrow keys; F | Pan camera (disables follow); toggle character follow | | 1–6 | Quick slots: Sand, Water, Wall, Smoke, Paste, Slush | | Q / E or Page Up / Page Down | Cycle all paintable materials | | Shift plus those cycling keys | Jump core/reactive, medieval, industrial, luminous, woods, stone/earth, metals and glass/chemical groups | | V / B | Cycle logical view / independent per-side simulation margins | | L | Toggle camera-interest / whole finite-world simulation | | C | Toggle ordinary Water emission / coherent lateral-delay emission | | T | Toggle native Water supported-film adhesion | | K | Toggle render smoothing; also forwards fallback sparse-flight sampling option | | H | Cycle render publication target through 30/45/60 Hz | | G | Toggle glow overlay and glow SubViewport updates (desktop and Web) | | F3 | Toggle statistics and periodic status-string construction | | P / R | Pause / reset | Paint slots map to stable material IDs; slot 5 is Paste ID 20 and slot 6 is Slush ID 21. The status line identifies the selected material. View/margin presets and defaults are owned by the [configuration reference](reference/configuration-reference.md). The 1920×1080 window aspect-fits the logical view, and mouse mapping uses the same fitted rectangle. Changing H or K does not change native fixed-tick semantics or enable a strict simulation mode. Target cadence is not guaranteed wall-clock progress.


### Rank 4: architecture/wave-flow-v1.md — Wave flow Water solver (experimental) > The law > Limits that keep it stable

Document: Wave flow Water solver (experimental)
Path: architecture/wave-flow-v1.md
authority: current-documentation
document-kind: reference
status: Current
scope: Current Wave Flow law, player defaults, bulk strip-parallel execution, admission, state and memory
canonical-for: [wave-flow-v1]
last-reviewed: 2026-11-20
Section: Wave flow Water solver (experimental) > The law > Limits that keep it stable
| Limit | Value | Reason | |---|---|---| | Responding rows per stack | 32 | Gravity can stay a true constant (wave speed ≤ ½ cell per round) instead of weakening with depth, which pumped energy | | Inertia per face (`kCoast`) | 16 units per round | Small flows keep their momentum and make waves; large flows relax without overshoot | | Downhill share | head difference ÷ (8 × responding rows) | The explicit-diffusion bound: two columns cannot swap places in one round | | Pour into an empty cell | ¼ of the source cell | A pair of columns cannot invert | | Adhesion threshold | 24 units with adhesion enabled; zero with it disabled | Stops continued thinning of a supported spill; the final residue can be below the threshold and can remain uneven | | Receiver capacity | At most half its remaining uint16 capacity from each adjacent face | Simultaneous arrivals cannot overflow a cell | | Sealed-stack inflow stop | Top mass at least 32,000 units | Stops additional inflow before the carrier limit | | Derived head | At most 2²⁶ units | Bounds arithmetic for extreme legal sealed columns | These are **bounded-approximation choices**, not physics. Their visible cost is that bulk surges are sedate at one round per tick; see [limits](#limits). The adhesion amount is a threshold for starting supported pouring or direct film levelling, not a hard minimum mass. Like the per-cell Water law, a cell that starts above the threshold can finish below it. Each film face uses the donor's mass before the apply pass; two-sided outflow can therefore leave a supported row `[1, 25, 1]` at `[2, 23, 2]`, or `[1, 32, 1]` at `[9, 16, 9]`. Quantity is unchanged. With adhesion enabled these residues stop moving even though neighbouring masses differ by more than one unit. Disabling adhesion wakes them and permits further levelling. The native threshold regression checks both examples across strip and chunk seams with one and four workers, including stable rest and region re-entry.


### Rank 5: operations/wave-flow-evaluation.md — Wave Flow evaluation > Tuning reference

Document: Wave Flow evaluation
Path: operations/wave-flow-evaluation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Experimental PR 631 Wave Flow desktop controls inherited from PR 618, comparative fixtures, actual native diagnostics and explicit unsupported physical persistence and material behavior
canonical-for: [wave-flow-evaluation]
last-reviewed: 2026-11-16
Section: Wave Flow evaluation > Tuning reference
Open the movable **Wave tuning…** dialog. Every field has a bounded numeric input, a description and a native readback beside the requested value. **Pool workers** accepts 1–32; this is configured capacity. Observed participants report workers that actually claimed tasks, not utilization or a guarantee that all configured workers ran. | Control | Default | Supported range | Effect | |---|---:|---:|---| | Rounds | 1 | 1–8 | Repeats the Wave solve per native tick; more transport and more work. | | Active rows | 32 | 1–32 | Stack depth that participates in the restoring response. | | Gain | 32 | 0–512 | Open-surface head-to-flux acceleration. | | Confined gain | 4 | 0–512 | Restoring response under confinement; does not add PressureFlow's pressure or gas model. | | Stiffness | 256 | 1–4096 | Sealed overfill response; must be at least Active rows. | | Damp shift | 7 | 0–16 | Momentum damping divisor; larger values mean less damping. | | Coast | 16 | 0–65535 | Flux allowed to coast against a small head difference. | | Level shift | 3 | 0–16 | Lateral levelling divisor; lower values level more strongly. | | Sleep after | 30 | 1–3600 | Quiet native ticks before sleeping. | | Wake move | 1 | 0–65535 | Movement threshold for activity; zero keeps activity awake. | | Rest head | 1 | 0–65535 | Head difference eligible for the small-step rest rule. | | Stick flux | 512 | 0–65535 | Small flux discarded within the rest rule. | | Calm flux | 512 | 0–65535 | Threshold for the stronger low-flux damping path. | | Calm damp | 3 | 0–16 | Low-flux damping divisor; larger values mean less damping. | | Sealed mass cap | 32000 | 255–65535 | Threshold above which a sealed stack refuses further lateral inflow. | | Empty pour | 2 | 1–8 | Donor fraction into Empty is 1 / 2^N. | | Wet share | 1 | 1–8 | Donor fraction between wet neighbors is 1 / 2^N. | | Adhesion shift | 1 | 0–8 | Surface-film scaling; larger values reduce adhesion. | The representational flux width, absolute head clamp and conservation bounds are fixed. Native validation also checks combinations; an in-range field alone does not guarantee a valid configuration. Invalid settings must leave the active World unchanged. Capacity refusals and solver-storage bytes are native readbacks, not proof that larger worlds will meet an interactive performance target. Native tick

## Q23: How should I tell whether a shimmering pool is a fluid bug or just its shader?

Canonical rank: 1

Expected facts:

- Inspect content changes/mass/dirty observations; state_hash advances with ticks and is not a stable-rest oracle.
- Stable coordinate/mass dithering is presentation-only and must not wake or mutate cells.
- Settling/conservation evidence applies to bounded named fixtures, not arbitrary mixtures.

### Rank 1: systems/water-design.md — Water design > How should I diagnose a shimmering pool?

Document: Water design
Path: systems/water-design.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current Water-family routing and player defaults; scoped FreeMass mechanics, quantity accounting, historical negative controls and fallback differences
canonical-for: [native-water-semantics, native-fallback-water-differences]
last-reviewed: 2026-11-24
Section: Water design > How should I diagnose a shimmering pool?
**Current diagnostic:** compare exact Water mass, `World::content_hash()`, and dirty/activity observations before treating shimmer as a fluid bug. If authority is stable while the pool visibly changes, inspect its shader, presentation-time animation, and render-only dither. If a closed pure-Water fixture loses mass or continues changing cell content after its rest criterion, investigate simulation transfers, conversions, or waking. Appearance alone cannot decide which path failed. Water coverage dither derives from stable world coordinates and mass; it cannot mutate authoritative cells or wake the simulation. `transfer_water` conserves exact integer mass for each Water pair. A closed pure-Water fixture must preserve the exact total every tick, including sleep, wake, and boundary crossings. Current native quantity ledgers additionally book explicit Water sources/sinks from edits, generation, events, kernels and registered reactions, with overfill and in-flight terms where enabled. That bookkeeping does not claim universal physical mass conservation across all species or change legacy chemistry. For the original FreeMass fixture, use `World::content_hash()` to observe rest: it includes material/state/ temperature at meaningful coordinates and excludes tick/epoch/activity. `state_hash()` includes advancing tick and update epoch plus additional scheduler state, so it is expected to change during otherwise resting ticks. Compare state hashes at matching ticks/configurations for supported fixture parity; neither hash is a complete replay checkpoint. [Native tests](../../native/tests/test_world.cpp) provide explicit bounds: - `test_conserved_water_levels_and_sleeps`: four-worker phased fixture, 48×255 initial mass, at most 2,000 ticks to reach 40 unchanged content hashes, then 40 further mass/rest checks and zero active chunks. - `test_water_surface_column_mass_is_level`: settled column-mass difference at most 8/255 of a cell. - `test_water_conserves_across_storage_boundaries`: exact boundary conservation. These are fixture bounds, not universal settling-time guarantees. Additional mirrored, shifted, mixed-material, and every-direction edge cases remain needed.


### Rank 2: operations/microscenarios-programme.md — CyberSand MicroScenarios and intermaterial-interactions programme > Discovery-to-regression loop

Document: CyberSand MicroScenarios and intermaterial-interactions programme
Path: operations/microscenarios-programme.md
authority: current-documentation
document-kind: design
status: Planned
scope: Canonical development-order graph for reusable exploratory MicroScenarios, anomaly triage, non-kinetic intermaterial-interaction authoring/tuning, and staged showcase work
canonical-for: [microscenarios-programme, microscenarios-development-order, intermaterial-interaction-programme]
last-reviewed: 2026-09-20
Section: CyberSand MicroScenarios and intermaterial-interactions programme > Discovery-to-regression loop
When an interesting world exposes odd behavior, use this loop: ```text play/explore a MicroScenario | v capture anomaly + exact identities | v reduce to the smallest reproducible scenario/fixture | v triage ownership +----+---------+-----------+-------------+ | | | | kinetic/ intermaterial state/phase cross-system contact interaction bug integration physics | | | | +--------------+-----------+-------------+ | v bounded fix/tuning issue | v retain regression + evidence | v return to the larger world ``` Do not classify first and force the symptom into that subsystem. Capture and reduce first. For example, "Lava sinks through the Stone it created" could be contact/support, permeability/density exchange, product-state initialization, update ordering, an intermaterial rule, or a cross-system defect. Every retained observation/fixture should identify at least: - scenario ID/schema/recipe version and deterministic seed; - source revision and tested runtime artifact/platform; - material catalogue/version identity; - kinetic/transport profile and relevant Water/material policy; - intermaterial-interaction profile/version/hash once INT-000 exists; - scheduled inputs and relevant user actions; - expected/observed outcome and whether it is exploratory, accepted, limited or awaiting revalidation.


### Rank 3: tools/world-art-capture.md — World Art unattended capture — real Godot PNGs and manifests > Output bundle

Document: World Art unattended capture
Path: tools/world-art-capture.md
authority: current-documentation
document-kind: guide
status: Current
scope: Production Godot framebuffer capture, streamed PNG transport, provenance and publication safety
canonical-for: [world-art-unattended-capture]
last-reviewed: 2026-11-20
Section: World Art unattended capture — real Godot PNGs and manifests > Output bundle
~~~text <output-dir>/ batch-manifest.json status, art/viewer/renderer identity, per-job hashes, seal (manifest_sha256) godot-run.json Godot runner report (display, driver, adapter, per-job status) godot-capture.log combined Godot output (diagnostics) 01-lumen-fault/ manifest.json per-job manifest: pack SHA-256, shots, camera, stats, renderer full.png viewport.png detail.png feature-<id>[--<variant>].png ~~~ The manifest records: exact **input pack SHA-256** (and the pack's Git blob and whether it equals `HEAD`), the **art source Git revision** detected from the checkout (a mismatching `--design-revision` is rejected), the viewer's Git revision and the SHA-256 of every copied shader/tool file, the Godot version, renderer method/driver/adapter, the palette shader identity (source/variant hashes, source binding) plus appearance LUT hashes, the selected collection/feature/variant, the full camera (zoom, origin, visible native rectangle, whether the whole map is visible and which edges clip), resolution/crop/scale/time/glow/detail/background, output dimensions, PNG byte size and **PNG SHA-256**, the RG8 source hash, image statistics, the synthetic-condition notice and limitations, and an explicit `completed`/`failed` status. Manifests retain actual source, engine and Git/workspace identities, so relocation or a different machine can change manifest bytes. Fixed presentation time supports repeatable PNG output on the same renderer and settings; hashes across operating systems or GPUs are not expected to match. The batch manifest is sealed: `manifest_sha256` covers its own content and lists every job manifest hash, which lists every PNG hash. A successful run requires: Godot exit 0, no shader/script errors in the log, every PNG decoded back from disk to the same pixels, independently validated PNG structure/CRC/dimensions/hash, the pack bytes unchanged since hashing, and the **art source unchanged** (a hash snapshot of the art directories plus `git status` before and after).


### Rank 4: operations/profiling-observability-and-performance.md — Profiling, observability, and performance > Run a useful comparison

Document: Profiling, observability, and performance
Path: operations/profiling-observability-and-performance.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Current native/Godot observations, benchmark procedure, metric boundaries, and unimplemented production telemetry
canonical-for: [performance-measurement, metric-interpretation]
last-reviewed: 2026-10-31
Section: Profiling, observability, and performance > Run a useful comparison
1. Record [source/artifact identity](source-checkpoint-and-recovery.md), platform, tool versions, profile, logical-thread report, actual worker count, and whether the tested binary was rebuilt. 2. Freeze the geometry, material/input sequence, tick count, warmup, cadence, view/margins, preallocation and presentation options. Define exactly what current and 2× fixtures mean. 3. Establish correctness first: the relevant hash at matching ticks, exact conserved quantities, and required collision/lifetime checks. 4. Repeat comparable runs, preferably interleaved with the known baseline. Keep mean, p95, maximum, work counts, memory/pressure, and environment caveats. 5. Profile simulation, bridge copies, collider extraction/processing, texture update, and shader/glow cost separately. Set acceptance thresholds from representative hardware and preserve raw failures/outliers. Timings are observations, not hidden authoritative inputs. Auto is a fixed policy; benchmark results do not retune it. No selectable strict runtime fidelity mode exists.


### Rank 5: operations/explore001-desktop-playtest.md — Generated-map desktop playtest > Manual acceptance procedure

Document: Generated-map desktop playtest
Path: operations/explore001-desktop-playtest.md
authority: current-documentation
document-kind: guide
status: Current
scope: Accepted generated-map Workbench workflow and manual desktop validation, separate from hosted automation
canonical-for: [explore001-desktop-playtest]
last-reviewed: 2026-11-24
Section: Generated-map desktop playtest > Manual acceptance procedure
1. In Shared Workbench click **New from generator…**, select **gen007-deepworks**, seed **19337**, source origin **0,0**, size **1024**. Generate a preview, inspect its materials, and explicitly install it. On the very first opening, verify both bottom action buttons are on screen. Resize the window and scroll the contents; action buttons should stay visible. 2. Select an existing flyer such as **Midge**, place it in clear terrain, select it under **Pilot**, then press **Play**. Test the displayed movement controls (W/A/S/D for the flyer). Check contact with solid terrain and passage through open routes. Record any stuck actor, unexpected collision or movement issue. 3. Switch the existing free/follow/overview camera controls; pan and zoom. Check that input remains usable and the flyer stays observable. Hosted headless success does not establish camera or movement feel. 4. Pause and use the existing brush to add a solid wall and erase an opening. Resume and check the flyer contacts the new wall and passes through the erased opening. Paint Water; observe motion and flyer interaction without assuming pressure equivalence or a new Water law. 5. Preview another ordinary chunk profile twice, change size, and cancel a partial preview. Check that complete previews contain consistent terrain and cancellation keeps the installed map. Install a completed preview if desired. 6. In the painting row, enter a unique name and click **Save start [Ctrl+S]**. Record source/seed/region, spawn, selected flyer, paint marks and erased opening. Close Godot completely and relaunch through the same checked launcher. 7. Enter the same name and **Load start**. Let native regeneration finish; confirm authored terrain, ordered edits, actor spawn and selection, then continue painting and save again. Close/reopen once more if reporting a bug. 8. Repeat a bounded 512 test and, if resources permit, a 2048 test. Large preparation temporarily retains old and candidate Worlds plus copied grids; measure pauses/memory rather than inferring low cost from bounded size. Report candidate source commit, Windows/GPU, size/profile/seed/origin, exact steps, expected/observed behavior, saved start and original screenshot/log where useful. Report whether the steps were performed by a person, automation or source inspection. Accepted implementation and package qualification do not assert that a particular owner has performed this physical playtest. Original [8 November candidate evidence](../audits/2026-11-08-explore001-integration-qa.md) retains its dated source/runtime scope. <a id="windows-candidate-launch-and-acceptance"></a> The original launch heading remains a compatibility destination. Use the current procedure above; [baseline candidate text](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/operations/explore001-desktop-playtest.md) preserves the earlier package-specific instructions.

## Q24: Can we approximate interactions to keep frame times stable, and is strict mode available now?

Canonical rank: 3

Expected facts:

- Bounded explicit approximation is Approved for runtime secondary work, preserving ownership, collision/occupancy and conservation constraints.
- Exact fixture validation remains required.
- A general selectable strict runtime mode and complete exact replay are Planned, not Current; local 2x2 occupancy coarsening is Rejected.

### Rank 1: reference/invariants.md — Architectural and simulation invariants > Fidelity invariants

Document: Architectural and simulation invariants
Path: reference/invariants.md
authority: current-documentation
document-kind: contract
status: Approved design
scope: Stable review IDs with current enforcement, known exceptions and approved requirements; this register is not a test-result ledger
canonical-for: [invariant-register]
last-reviewed: 2026-11-24
Section: Architectural and simulation invariants > Fidelity invariants
Contract: [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md). | ID | Status and requirement | |---|---| | FID-001 | Approved, incomplete: policies must be explicit, bounded, observable and reversible; current fixed lanes lack a universal disable switch | | FID-002 | Approved: local occupancy, ownership, closed conservation and capacity checks cannot be sampled away | | FID-003 | Current: fixed-policy native fixtures compare exact hashes; full strict/replay mode remains Planned | | FID-004 | Rejected: naive coarsening that alters local topology or creates checkerboard holes |


### Rank 2: systems/materials-and-rule-kernels.md — Materials and rule kernels > Kernel execution and cadence

Document: Materials and rule kernels
Path: systems/materials-and-rule-kernels.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native material identity, descriptors, mutable state, kernel execution, current interactions, and extension boundaries
canonical-for: [material-runtime-model, material-kernel-cadence, reactive-material-families]
last-reviewed: 2026-11-24
Section: Materials and rule kernels > Kernel execution and cadence
[World::update_cell, update_rule_kernel, and rule_is_active](../../native/src/world.cpp) dispatch compact families. Private methods still couple storage access, traversal, movement, and wake/dirty handling; a public bounded `RuleContext` does not yet enforce that separation by type. Active descriptors declare at most radius two; inert descriptors declare zero. Phased jobs must remain within exclusive write domains and use deterministic coordinate/tick/rule streams. A material may not select behavior from worker identity or completion timing. | Work lane | Current period | Scope | |---|---:|---| | Eligible transport/density motion | Each selected tick, except Mercury/powder permeability | Empty movement and native Water transfer remain full rate; [granular policy](granular-interaction-policy.md) owns pair exclusions and deadlines | | Selected burn/charge/lifecycle work | 2 ticks | Kernel-specific, not every lifetime; Fire/Foam have full-rate portions | | Pair chemistry, thermal/growth/capture checks | 4 ticks | Persistent contacts can react; brief contacts can be missed | | Smoke lifetime/crowding | 8 ticks | Coordinate-staggered decay | | Ice freezing sample | 16 ticks | Specialized sub-lane after the four-tick thermal gate | | Ambient Fire ignition sample | 120 ticks | One sampled neighbor on the due lane | Some waiting rules keep blocks active without a false render write. Persistent compact-pair and Ice contacts use a scheduled block wake instead; other specialized kernels retain their existing waiting behavior. Activity and contact persistence therefore still matter outside that repaired scope. This deterministic cadence is Current approximate runtime behavior; it is not a selectable strict-every-contact mode or full replay capture.


### Rank 3: decisions/ADR-008-bounded-approximate-fidelity.md — ADR-008: Bounded approximate fidelity under load > Decision and implementation status

Document: ADR-008 — Bounded approximate fidelity under load
Path: decisions/ADR-008-bounded-approximate-fidelity.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Accepted fidelity direction and constraints; fixed current cadence is separate from planned adaptive policy
canonical-for: [decision-bounded-approximate-fidelity]
last-reviewed: 2026-09-08
Section: ADR-008: Bounded approximate fidelity under load > Decision and implementation status
**Approved:** interactive frame pacing may take priority over calculating every secondary interaction each tick. Explicit bounded sampling/deferral is allowed; local collision, ownership, conservation and accepted authoritative commands must remain correct. Universal bit-identical gameplay across fidelity policies is not required. **Current:** native eligible transport, fixed staggered secondary lanes, activity sleeping and interest filtering. These are compiled policy, not an overload-triggered adaptive controller. **Planned:** selectable strict/runtime policies, hysteresis, work targets, coarser optional fields and distant aggregates. Exact native fixtures remain Current; complete replay is not implemented. Sources: [World rules](../../native/src/world.cpp), [hash coverage](../architecture/determinism-and-boundary-transfers.md).


### Rank 4: decisions/ADR-008-bounded-approximate-fidelity.md — ADR-008: Bounded approximate fidelity under load > Which fidelity tiers are intended?

Document: ADR-008 — Bounded approximate fidelity under load
Path: decisions/ADR-008-bounded-approximate-fidelity.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Accepted fidelity direction and constraints; fixed current cadence is separate from planned adaptive policy
canonical-for: [decision-bounded-approximate-fidelity]
last-reviewed: 2026-09-08
Section: ADR-008: Bounded approximate fidelity under load > Which fidelity tiers are intended?
| Approved scope | Intended constraint | |---|---| | Immediate interaction | Full local occupancy/collision and prompt known-contact resolution | | Active surroundings | Explicit interest-weighted cadence or sampled secondary searches | | Secondary fields | Lower cadence/resolution only with declared conservation/transfer boundaries | | Distant world | Sleep or future conserved summaries that expand before interaction | | Strict validation | Fixed declared policy, stable random/order inputs and exact fixture comparison | Policies must be bounded, observable and independently reversible. Good candidates include slow ignition, corrosion, growth and distant fields. Poor candidates include capacity checks, synchronization, accepted explosions, closed-boundary conservation or detected penetration. Stateless seeded choices are preferred; worker timing must never become a hidden random input.


### Rank 5: operations/microscenarios-programme.md — CyberSand MicroScenarios and intermaterial-interactions programme > Current dependency graph > Work-start table

Document: CyberSand MicroScenarios and intermaterial-interactions programme
Path: operations/microscenarios-programme.md
authority: current-documentation
document-kind: design
status: Planned
scope: Canonical development-order graph for reusable exploratory MicroScenarios, anomaly triage, non-kinetic intermaterial-interaction authoring/tuning, and staged showcase work
canonical-for: [microscenarios-programme, microscenarios-development-order, intermaterial-interaction-programme]
last-reviewed: 2026-09-20
Section: CyberSand MicroScenarios and intermaterial-interactions programme > Current dependency graph > Work-start table
| Work | May start when | Does **not** wait for | Hard boundary | |---|---|---|---| | #24 | Now / its own issue | #18, #27 | Keep it a focused input/launcher fix | | #27 MS-000 | Once the working base contains the #24 fix, or the fix is taken as an isolated prerequisite in the same branch | #18 completion, #14/G-final | Apparatus only; no new physics semantics | | #18 | Under its existing admission | #27/#28 | Preserve registered experiment contract | | #26 | **Complete Outcome B** (2026-09-19) | #27 | Retain source-matched negative evidence; apparatus v1 is historical/qualified | | #49 Water apparatus correction | After #26 review; before #45 implementation/acceptance | #27/#28/#29 | Version metrics/fixtures/evidence; preserve old results | | #45 Water head transmission | After #49 merges; under its own architecture/admission contract | #27/#28/#29 | Keep bulk scalar/head transmission distinct from #18 directional history | | #20 | Design/admission per its own issue; implementation only after its own gates | #28/#29 | Still blocked by #18/G-M plus G-B admission | | #28 MS-001 | When enough of #27 is stable to host real scenarios | #14/G-final | Pre-G-final scenario results are provisional/versioned | | #29 INT-000 planning/inventory | Now | #14/G-final | No broad retune merely because inventory exists | | #29 implementation | Stable #27 fixture contract + #28 Materials Laboratory readiness checkpoint | completion of Flood Control/Stress Test; blanket G-final | Preserve rolling baseline/provenance and subsystem ownership | | Interaction tuning pass | INT-000 infrastructure + named relevant physics/contact baseline | a mythical global physics freeze | Re-screen affected accepted fixtures after relevant physics changes | | #30 | Tracker/documentation only | everything | Never treat issue #30 itself as an execution gate | The #28 issue may remain one issue. Its **Materials Laboratory readiness checkpoint** can unlock INT-000 while Flood Control and Simulation Stress Test continue independently. Split #28 only if implementation/review size later justifies it; do not create artificial serial dependencies merely for issue hygiene.

## Q25: Can we move authoritative materials to GPU compute, or author their rules in arbitrary JavaScript?

Canonical rank: 1

Expected facts:

- Authoritative local occupancy remains native CPU; GPU compute is Deferred pending ownership/readback/replay evidence.
- An item-authored bounded native program is Planned; arbitrary per-cell JavaScript is Rejected.
- Presentation-only GPU effects do not confer authority.

### Rank 1: architecture/principles-and-non-goals.md — Architectural principles and non-goals > Can materials run on GPU compute or arbitrary JavaScript?

Document: Architectural principles and non-goals
Path: architecture/principles-and-non-goals.md
authority: current-documentation
document-kind: design
status: Approved design
scope: Accepted architectural constraints, explicit current exceptions, deferred scope and rejected approaches
canonical-for: [architectural-constraints-and-rejected-shortcuts]
last-reviewed: 2026-09-08
Section: Architectural principles and non-goals > Can materials run on GPU compute or arbitrary JavaScript?
**Current:** authoritative material rules execute in native CPU kernels. **Rejected at this stage:** GPU terrain authority and arbitrary JavaScript or other scripts in the per-cell hot loop. **Deferred:** GPU field experiments. **Planned:** a validated bounded material-program compiler; see [item-authored programs](item-authored-material-programs.md). Visual graphs would compile before play and obey the same radius/work bounds, rather than grant unrestricted scripting access.


### Rank 2: decisions/ADR-006-gpu-compute-deferral.md — ADR-006: GPU compute deferral > Why defer authority?

Document: ADR-006 — GPU compute deferral
Path: decisions/ADR-006-gpu-compute-deferral.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Accepted CPU authority, deferred GPU field experiments and conditions for reconsideration
canonical-for: [decision-gpu-compute-deferral]
last-reviewed: 2026-09-08
Section: ADR-006: GPU compute deferral > Why defer authority?
Terrain interacts with CPU collision queries, material rules, commands, saves and future streaming/replay. Moving those bytes to a GPU without a complete ownership design risks readback latency, stalls and competing CPU/GPU truths. A small fast kernel alone does not establish a faster integrated simulation. Native ownership and fixtures are the immediate foundation. The decision leaves room for resident derived fields whose consumers tolerate their latency and non-authoritative nature. It selects no API, shader language, field format, cadence or target hardware. That specificity belongs to a later proposal with measured end-to-end cost.


### Rank 3: decisions/ADR-006-gpu-compute-deferral.md — ADR-006: GPU compute deferral > Decision and implementation status

Document: ADR-006 — GPU compute deferral
Path: decisions/ADR-006-gpu-compute-deferral.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Accepted CPU authority, deferred GPU field experiments and conditions for reconsideration
canonical-for: [decision-gpu-compute-deferral]
last-reviewed: 2026-09-08
Section: ADR-006: GPU compute deferral > Decision and implementation status
**Approved:** keep native CPU authority for material occupancy and collision. **Rejected at this stage:** GPU-authoritative terrain. **Deferred:** isolated GPU experiments for suitable non-authoritative or separately designed fields. This is not a permanent ban on GPU compute. **Current:** Godot uses presentation shaders under GL Compatibility; no compute-simulation backend is implemented. Sources: [project renderer](../../godot/project.godot), [material shader](../../godot/shaders/material_palette.gdshader) and [native World](../../native/src/world.cpp). Rich shader motion/glow is visual derivation, not evidence of GPU simulation or GPU saturation.


### Rank 4: decisions/ADR-006-gpu-compute-deferral.md — ADR-006: GPU compute deferral > What would justify a new decision?

Document: ADR-006 — GPU compute deferral
Path: decisions/ADR-006-gpu-compute-deferral.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Accepted CPU authority, deferred GPU field experiments and conditions for reconsideration
canonical-for: [decision-gpu-compute-deferral]
last-reviewed: 2026-09-08
Section: ADR-006: GPU compute deferral > What would justify a new decision?
Name the field and authority level; define CPU/GPU ownership, synchronization, collision/query latency, save/replay behavior, device loss and fallback. Compare representative current/larger fixtures including compute, transfer, synchronization, readback and memory. A non-authoritative experiment must leave native fixture state unchanged; an authoritative field requires a new explicit ADR. No future experiment is considered validated merely because shaders compile or a headless scene runs. Use [validation evidence](../reference/validation-evidence.md) and [profiling guidance](../operations/profiling-observability-and-performance.md) to distinguish actual device measurements from source inspection.


### Rank 5: decisions/ADR-006-gpu-compute-deferral.md — ADR-006: GPU compute deferral > Consequences and alternatives

Document: ADR-006 — GPU compute deferral
Path: decisions/ADR-006-gpu-compute-deferral.md
authority: current-documentation
document-kind: decision
status: Approved design
scope: Accepted CPU authority, deferred GPU field experiments and conditions for reconsideration
canonical-for: [decision-gpu-compute-deferral]
last-reviewed: 2026-09-08
Section: ADR-006: GPU compute deferral > Consequences and alternatives
CPU authority simplifies collision access and independent tests, while initial scale depends on CPU memory bandwidth and scheduling. A future GPU path will need separate platform/fallback evidence. A derived visual field must not silently start deciding authoritative motion. **Rejected:** immediate GPU terrain authority and a permanent prohibition on all GPU compute. **Deferred:** wholesale PhysX-like material offload; no such compatible implementation is demonstrated here. **Current:** GPU rendering from immutable simulation publication. The [bridge contract](../architecture/rendering-and-gameplay-bridges.md) remains applicable regardless of visual sophistication.

## Q26: Do SimulationCore and GameplayBridge already exist as reusable implementation modules?

Canonical rank: 2

Expected facts:

- These are target semantic module names, not an assertion of implemented classes/APIs.
- Current native World, C ABI, GDExtension, GDScript worker and rectangle proof are concrete surfaces.
- Generalized interfaces need design review; map Approved/Planned names to actual source.

### Rank 1: architecture/overview.md — Architecture overview > Are the named production modules already separate classes?

Document: Architecture overview
Path: architecture/overview.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current execution paths and authority map; routes to the contracts that govern changes
canonical-for: [architecture-entry-point]
last-reviewed: 2026-11-24
Section: Architecture overview > Are the named production modules already separate classes?
**Approved:** SimulationCore, SimulationScheduler, WorldStorage, TileJob, MaterialRules, RenderBridge and GameplayBridge name intended responsibilities. **Current:** World still combines much of core, storage and scheduling. Material descriptors, prepared ownership and native snapshot exchange have separate interfaces; a universal gameplay command/replay service does not exist. The [module boundary map](module-boundaries.md) distinguishes actual symbols from future extraction. Naming a responsibility does not establish that extraction.


### Rank 2: architecture/module-boundaries.md — Module boundaries > Where should new code belong?

Document: Module boundaries
Path: architecture/module-boundaries.md
authority: current-documentation
document-kind: design
status: Approved design
scope: Approved responsibility boundaries mapped to current source; no claim that every named module is a class
canonical-for: [module-responsibilities-and-dependencies]
last-reviewed: 2026-10-21
Section: Module boundaries > Where should new code belong?
**Approved:** use the responsibility map below when extending or extracting the native engine. **Current:** `cybersand::World` combines storage, scheduling, rules, activity and dirty tracking; the table does not assert separate C++ classes. Sources are [World declarations](../../native/include/cybersand/world.hpp) and [implementation](../../native/src/world.cpp). | Boundary | Approved responsibility | Current implementation and remaining separation | |---|---|---| | SimulationCore | Authoritative cell/field semantics and invariants | World kernels and tick entry; extraction remains incomplete | | SimulationScheduler | Work planning, pool, barriers, deterministic coordination and overload metrics | `World::tick_phased`, `ParallelState`; desktop wall-clock pacing is still GDScript and Web owns synchronous callbacks | | WorldStorage | Chunk lifetime, optional fields, activity and capacity; future persistence | `World::Chunk`, `chunks_`, reservation/query methods and explicit fresh generated-chunk admission; general streaming and live resize are absent | | Procedural generator | Compile generation guidance and prepare complete deterministic material proposals | Opt-in `generation::Generator`/`GenerationJob`, immutable scalar/typed graphs, canonical semantic plans, aggregates and prepared modules; no mutable World access; [generation contract](../systems/procedural-world-generation.md) | | TileJob | Temporary bounded work assignment and local observations | Core indices, `JobEffects`, local `TickStats`; no public type-enforced bounded rule context | | MaterialRules | Immutable descriptors, traits and kernel selection | Descriptor/pair-reaction APIs are separate; executable kernels remain inside World | | RenderBridge | Consume immutable simulation publication and update presentation | Native `RenderSnapshotExchange`, copied Godot packets and CPU-image consumer; GPU subregion writes are absent | | GameplayBridge | Translate intent into tick-boundary data and immutable results | Narrow emission/input/body methods; generalized typed queues and pressure policy are absent | | Rigid-body adapter | Own backend calls and translate body value data | `CyberRapierPhysicsBridge` plus native rectangle projection; general shape and torque interfaces are absent | Adding a native class is justified when it establishes a usable responsibility or lifetime boundary. A cosmetic rename is not architectural progress.


### Rank 3: decisions/ADR-001-native-simulation-core.md — ADR-001: Native SimulationCore > Why place authority here?

Document: ADR-001 — Native SimulationCore
Path: decisions/ADR-001-native-simulation-core.md
authority: current-documentation
document-kind: decision
status: Current
scope: Accepted native authority decision, current integration and incomplete module extraction
canonical-for: [decision-native-cellular-authority]
last-reviewed: 2026-09-08
Section: ADR-001: Native SimulationCore > Why place authority here?
The engine needs dense cell-scale rules, shared spatial scheduling and native fixtures independent of a scene runtime. Godot is valuable for presentation, input and adapters, but its object lifetimes must not determine worker storage or update order. A reusable native core also supports standalone tools, benchmarks and alternative presentations. The chosen boundary keeps Godot/Rapier types outside core headers. Immutable render publication and data-only gameplay commands/results cross adapters. The exact resource contract is in [data ownership](../architecture/data-ownership-and-lifetimes.md).


### Rank 4: decisions/ADR-001-native-simulation-core.md — ADR-001: Native SimulationCore > Decision and implementation status

Document: ADR-001 — Native SimulationCore
Path: decisions/ADR-001-native-simulation-core.md
authority: current-documentation
document-kind: decision
status: Current
scope: Accepted native authority decision, current integration and incomplete module extraction
canonical-for: [decision-native-cellular-authority]
last-reviewed: 2026-09-08
Section: ADR-001: Native SimulationCore > Decision and implementation status
**Approved and Current:** authoritative cellular state and rules belong in native C++. `cybersand::World` supplies that authority through `CyberNativeCellWorld`. Desktop selects the GDScript fallback when the native class is absent; Web requires native support. The alternatives are not synchronized authorities and do not promise identical Water behavior. **Approved, incomplete:** separate SimulationCore, storage, scheduler and bridge responsibilities. World still combines several of them. A class called SimulationCore is not required to make native authority real, and renaming World would not complete the [module boundaries](../architecture/module-boundaries.md). Source: [World](../../native/include/cybersand/world.hpp), [desktop selector](../../godot/scripts/simulation_worker.gd), [Web owner](../../godot/scripts/web_demo_controller.gd). Actual platform evidence is separate in the [validation ledger](../reference/validation-evidence.md).


### Rank 5: operations/microscenarios-programme.md — CyberSand MicroScenarios and intermaterial-interactions programme > INT-000: intermaterial interactions, not kinetic physics > Sparse layered authoring

Document: CyberSand MicroScenarios and intermaterial-interactions programme
Path: operations/microscenarios-programme.md
authority: current-documentation
document-kind: design
status: Planned
scope: Canonical development-order graph for reusable exploratory MicroScenarios, anomaly triage, non-kinetic intermaterial-interaction authoring/tuning, and staged showcase work
canonical-for: [microscenarios-programme, microscenarios-development-order, intermaterial-interaction-programme]
last-reviewed: 2026-09-20
Section: CyberSand MicroScenarios and intermaterial-interactions programme > INT-000: intermaterial interactions, not kinetic physics > Sparse layered authoring
Do not make humans maintain a dense N×N table. With 64 materials there are 4096 ordered pairs; with 256 there are 65536. A dense resolved runtime lookup may be perfectly reasonable if measurement favors it; **dense manual authoring is not**. The landed INT-000 implementation from PR #55 extends the useful #13 profile precedent: ```text intrinsic material properties/state | family/default interaction rules | material-specific adjustments | sparse directed/symmetric pair overrides | context/state modifiers | validated resolver/compiler | compact runtime lookup representation ``` Explicit pair entries exist for genuine exceptions, not because every Cartesian cell needs bespoke content.

## Q27: What smoke, pressure and heat simulation actually runs today?

Canonical rank: 1

Expected facts:

- Current native Smoke has bounded lifetime/crowd collapse and cannot burn or host Fire.
- Current temperature storage/material reactions are not a complete generalized heat/pressure field solver.
- Future fields and visual tuning must remain separately marked Planned or Deferred.

### Rank 1: systems/smoke-heat-pressure-roadmap.md — Smoke, heat, and pressure roadmap

Document: Smoke, heat, and pressure roadmap
Path: systems/smoke-heat-pressure-roadmap.md
authority: current-documentation
document-kind: design
status: Current
scope: Implemented native and fallback Smoke, limited temperature use, and unimplemented heat/pressure/composition fields
canonical-for: [smoke-behavior, optional-heat-pressure-fields]
last-reviewed: 2026-09-08
Section: Smoke, heat, and pressure roadmap
**Current:** Smoke is a discrete material with buoyancy and intentional non-conserved decay. Optional temperature storage exists and Rocket reads it, but there is no heat-conduction solver. General pressure and gas-composition fields are **Planned**. Local body-pressure impulses and liquid comparisons do not establish such fields. These are source claims for the [secured checkpoint](../operations/source-checkpoint-and-recovery.md). Dated runs are in the [evidence ledger](../reference/validation-evidence.md).


### Rank 2: systems/smoke-heat-pressure-roadmap.md — Smoke, heat, and pressure roadmap > Desktop fallback Smoke

Document: Smoke, heat, and pressure roadmap
Path: systems/smoke-heat-pressure-roadmap.md
authority: current-documentation
document-kind: design
status: Current
scope: Implemented native and fallback Smoke, limited temperature use, and unimplemented heat/pressure/composition fields
canonical-for: [smoke-behavior, optional-heat-pressure-fields]
last-reviewed: 2026-09-08
Section: Smoke, heat, and pressure roadmap > Desktop fallback Smoke
[CyberCellWorld](../../godot/scripts/cell_world.gd) lacks the native authoritative lifetime byte. Its hazard is disabled for the first 64 world ticks, then uses a slower coordinate/tick sample. This is not a 64-tick grace period for every newly painted Smoke cell. It approximates the appearance intent but does not preserve native decay timing or state equality. Web requires the native cellular adapter; “compatibility Web” does not mean this GDScript fallback.


### Rank 3: systems/smoke-heat-pressure-roadmap.md — Smoke, heat, and pressure roadmap > Current native Smoke

Document: Smoke, heat, and pressure roadmap
Path: systems/smoke-heat-pressure-roadmap.md
authority: current-documentation
document-kind: design
status: Current
scope: Implemented native and fallback Smoke, limited temperature use, and unimplemented heat/pressure/composition fields
canonical-for: [smoke-behavior, optional-heat-pressure-fields]
last-reviewed: 2026-09-08
Section: Smoke, heat, and pressure roadmap > Current native Smoke
[MaterialRules](../../native/include/cybersand/material.hpp) names material ID 4 `Smoke`, with `Gas` as an alias. In [World::update_rule_kernel, RuleKernel::Gas](../../native/src/world.cpp), Smoke attempts up, both up-diagonals, then lateral movement. An Empty target permits a move; a denser movable target permits an exchange only when its descriptor accepts density exchange. Wall and the Mite/Rocket agents opt out. Numeric density alone does not imply permeability. Smoke starts with `state_a = 240`. On its coordinate-staggered eight-tick lane, it loses one lifetime unit, or two when at least five of the eight neighbors are Smoke. At the final decay sample it becomes Empty. Movement changes the coordinate-dependent phase, so this is not a universal lifetime in seconds. Trapped Smoke uses `keep_cell_active` between samples. The ignition helper excludes Smoke: ordinary heat-contact/Fire ignition does not turn it into Fire. The owner-approved visual intent is a lingering cloud with slow internal collapse, substantially slower than Foam, without an extra full-world age scan. Further artistic tuning is **Planned**.


### Rank 4: systems/smoke-heat-pressure-roadmap.md — Smoke, heat, and pressure roadmap > Planned field work

Document: Smoke, heat, and pressure roadmap
Path: systems/smoke-heat-pressure-roadmap.md
authority: current-documentation
document-kind: design
status: Current
scope: Implemented native and fallback Smoke, limited temperature use, and unimplemented heat/pressure/composition fields
canonical-for: [smoke-behavior, optional-heat-pressure-fields]
last-reviewed: 2026-09-08
Section: Smoke, heat, and pressure roadmap > Planned field work
| Field | Implemented boundary | Missing design | |---|---|---| | Heat | Optional temperature storage; Rocket threshold | Units, conduction, energy accounting, cadence, phase transitions | | Pressure | Local liquid/body coupling heuristics | General pressure storage, equation/update, room/breach semantics | | Gas composition | Discrete Smoke/Steam material occupants | Mixture representation, quantities, conservation, vacuum behavior | | Field-based Smoke | Current discrete Smoke reference | Whether to replace occupancy with an optional density/composition field | **Approved:** future fields share native world authority, scheduler ownership, activity, bounded capacity, and immutable publication. Optional data should be allocated where required. Existing Water/Sand/Smoke already use World; they do not need a new port before this design work. For each proposed field, define one stage and cadence, numeric representation, read/write reach, in-place or buffered ownership, conservation or explicit error bounds, wake/interest behavior, serialization/hash coverage, and failure behavior. Then add a reference fixture, edge/worker comparison, and current/2× load measurements. Production interaction ordering across fields is not approved.


### Rank 5: systems/smoke-heat-pressure-roadmap.md — Smoke, heat, and pressure roadmap > Planned field work > WEX-003 compartment-pressure research

Document: Smoke, heat, and pressure roadmap
Path: systems/smoke-heat-pressure-roadmap.md
authority: current-documentation
document-kind: design
status: Current
scope: Implemented native and fallback Smoke, limited temperature use, and unimplemented heat/pressure/composition fields
canonical-for: [smoke-behavior, optional-heat-pressure-fields]
last-reviewed: 2026-09-08
Section: Smoke, heat, and pressure roadmap > Planned field work > WEX-003 compartment-pressure research
The [WEX-003 feasibility result](../research/lumped-gas-region-pressure-bookkeeping.md) does **not** implement the general Pressure row above. It identifies a narrower optional architecture: resolved connected gas regions own amount/free-volume bookkeeping and derive a compartment boundary pressure, while closures use affected-component reconstruction and unresolved topology returns no authoritative pressure. The result admits only the bounded #94 decompression research proof. Per-cell gas pressure/velocity, composition, heat coupling and production field integration remain unimplemented. **Deferred:** GPU-resident derived fields may be benchmarked after their authority and synchronization are explicit. **Rejected for the current architecture:** GPU-only terrain/collision authority, unsynchronized gameplay reads, and routine GPU readback as a prerequisite for authoritative ticks. These dispositions are owned by [ADR-006](../decisions/ADR-006-gpu-compute-deferral.md), not a permanent ban on every GPU experiment.

## Q28: Which exact tools should I build with, and can I share the native and Web bindings checkout?

Canonical rank: 1

Expected facts:

- Use pinned Godot 4.7 official 5b4e0cb0f, godot-cpp 101ae38034304346a46ea9ea84ae156d3e860496 and Emscripten 4.0.20; local Windows LLVM-MinGW and SCons pins are explicit.
- Keep native and Web generated bindings separate.
- Use local dev wrappers and distinguish local override from historical release provenance.

### Rank 1: operations/local-build-and-validation.md — Local build and validation > Windows development commands

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > Windows development commands
From `C:/kybersand`, the companion workspace provides `dev.cmd` / `tools/dev.py`. Host paths, installation and environment overrides belong to `C:/kybersand/docs/LOCAL_DEVELOPMENT.md`. Source-only clones do not contain these wrappers; the repository-native scripts are listed below. ```powershell .\dev.cmd doctor .\dev.cmd native-bindings .\dev.cmd native-build .\dev.cmd native-test .\dev.cmd godot-test .\dev.cmd web # Optional internally parallel Web profile: .\dev.cmd web --profile threaded ``` The repository also contains `launch-desktop.cmd` / `tools/launch_desktop.ps1` for source-only Windows checkouts. It validates the pinned Godot/runtime inputs, prints checkout/runtime identity, exports the exact checkout SHA to the child Godot process as `CYBERSAND_SOURCE_REVISION` for recording provenance, and does **not** rebuild or replace retained runtimes. `native-bindings` builds pinned Windows godot-cpp; `native-build` builds the GDExtension. `native-test` compiles/runs the C header check and native tests; `godot-test` imports the project then runs all `test_*.gd` runners. Godot tests load the installed DLL: running them alone does **not** rebuild that DLL. Record its hash and source identity with the result. The wrapper allows 240 s for import, 180 s per Godot runner, and rejects Godot error output even with exit 0.


### Rank 2: operations/local-build-and-validation.md — Local build and validation > Choose the right development path

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > Choose the right development path
| Task | Inputs and procedure | Evidence it can establish | |---|---|---| | Explore accepted software | Source checkout, materialized retained runtime, exact Godot | Actual launch and exercised behavior on that machine | | Review a portable evaluator | Exact package manifest, bundled launcher and its matching source | Only that package/source; candidate does not become main | | Change documentation or retrieval | Python, Git and [structural/retrieval checks](documentation-maintenance.md#checks-and-evaluation-interpretation) | Documentation structure, containment and inspected claims | | Change native C++ | Pinned compiler/dependencies; [native commands](#repository-native-build-and-test-commands) | Focused or complete native tests actually executed | | Change Godot scripts or bindings | Source-matched extension, pinned Godot; [test-selection guide](testing-validation-and-replay.md) | Actual tested script/native integration; bindings may require rebuild | | Qualify Web | Separate Web godot-cpp, exact SDK/templates and actual browser execution | The named compat/threaded artifact, not desktop parity | Inspect the actual Git root, branch, HEAD, dirty files and required LFS state before work. The companion workspace contains optional host-specific wrappers; this source repository contains the application, tests and native build entry points. [Source identity](source-checkpoint-and-recovery.md) owns that boundary. A quick bounded interface probe is `make c-header-check`. `make -n test` displays the current native test build/run plan without compiling or running it. Neither command qualifies gameplay. Use the smallest meaningful subsystem test during iteration; a full matrix belongs to the applicable implementation gate.


### Rank 3: operations/github-development-and-release.md — Repository development and release > Unresolved CI contradictions

Document: Repository development and release
Path: operations/github-development-and-release.md
authority: current-documentation
document-kind: guide
status: Current
scope: Contribution boundaries, Draft qualification, source-matched runtime publication and release prerequisites
canonical-for: [repository-policy, ci-contradictions, release-prerequisites]
last-reviewed: 2026-11-24
Section: Repository development and release > Unresolved CI contradictions
These are source-inspected Web configuration gaps at the recorded accepted source, not inferred failures of every existing Web artifact: | Conflict | Source evidence | Separate required work | |---|---|---| | Web workflows select Emscripten 4.0.11; builder checks 4.0.20 | [Toolchain workflow](../../.github/workflows/web-toolchain.yml), [Web workflow](../../.github/workflows/web-demo.yml), [builder](../../tools/build_web.py) | Align accepted producer/consumer pins and execute the result | | Workflow requests `--native-tests` without a separate `--native-cpp` | Same builder argument validation and Web workflow | Supply the supported isolated native bindings | | `--compile-only` returns before runtime fixtures/export | [Builder control flow](../../tools/build_web.py) | Select and execute the intended runtime/export coverage | | Runtime lock records export templates as `absent-and-unpinned` | [Godot runtime lock](../../third_party/godot-runtime.lock.json) | Record exact template provenance and qualify reproducible exports | The companion wrapper's acquisition-base `source_commit` was a previously recorded identity limitation. Reinspect that separate workspace before treating it as a current fact; this source repository cannot attest an unseen local wrapper. Issue #3 and the canonical Web/build guides retain those release responsibilities. No native/Godot documentation pass resolves Web export or browser acceptance.


### Rank 4: operations/local-build-and-validation.md — Local build and validation > Which build inputs are required?

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > Which build inputs are required?
**Current:** build scripts and locks select the following inputs. A pin is a requirement, not evidence that every platform artifact was built or tested. | Input | Required identity and authoritative reference | |---|---| | Godot editor/runtime | `4.7.stable.official.5b4e0cb0f`; [runtime lock](../../third_party/godot-runtime.lock.json) | | godot-cpp / API | `101ae38034304346a46ea9ea84ae156d3e860496` / `4.7`; [native lock](../../third_party/native-toolchain.lock.json) | | SCons | `4.10.1`; [hash-pinned requirement](../../tools/requirements-build.txt) | | Windows compiler | LLVM-MinGW 20260826, Clang 23.1.0, UCRT; native lock pins the Linux-host archive; local Windows ZIP is a distinct input | | Linux compiler/linker | GCC/G++ 13.3.0 / binutils 2.42; native lock | | Web compiler | Emscripten **4.0.20**, checked by [build_web.py](../../tools/build_web.py) | | Rapier2D | Single-precision 2D **v0.35.2** base; qualified cooperative deferred-BVH join backport on Windows/Linux x86_64, official bytes on other targets; [Rapier lock](../../godot/third_party/rapier2d.lock.json) | | Web templates | Exact Godot 4.7 dlink templates: `web_dlink_nothreads_{debug,release}.zip` for compat, `web_dlink_{debug,release}.zip` for threaded | Keep native and Web godot-cpp checkouts separate: generated bindings and archives are target-specific. Python 3.12.14 was used locally; the workspace helper requires Python 3.10+. Do not silently update pins while debugging a simulation change. The runtime lock labels export templates `absent-and-unpinned`; the repository does not establish reproducible current exports merely because a local machine has templates installed. The configured Web CI also disagrees with the builder; see [release prerequisites](github-development-and-release.md#unresolved-ci-contradictions).


### Rank 5: operations/web-threading.md — Web worker profiles and reference tests > Build and preview

Document: Web worker profiles and reference tests
Path: operations/web-threading.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Compatibility/threaded Web build and hosting, fixed worker policy, synchronous ownership, and reference-test interpretation
canonical-for: [web-worker-profiles, worker-reference-benchmark]
last-reviewed: 2026-09-08
Section: Web worker profiles and reference tests > Build and preview
From `C:/kybersand`: ```powershell .\dev.cmd web --profile threaded .local/python/Scripts/python.exe source/tools/serve_web.py --directory source/build/web-threaded --port 8002 --open ``` While the preview server is running: ```powershell .\dev.cmd http-smoke --profile threaded --url http://127.0.0.1:8002/ ``` `dev.cmd web` builds compatibility. Use export-only only with a matching fresh side module; successful packaging does not prove source-to-binary freshness. The [build guide](github-development-and-release.md) owns exact dependency pins and unresolved CI/toolchain drift. Native/Web generated bindings stay separate. The supplied server sets COOP `same-origin`, COEP `require-corp`, appropriate WASM MIME and no-cache behavior. Threaded hosting needs a secure context (HTTPS or localhost) and cross-origin isolation. Serve the complete export, including worker JavaScript, PCK, WASM, notices and manifest. HTTP/checksum success is structural evidence; open the actual browser for execution. Local delivery is a separate explicit workflow after acceptance: `Deliver-Web.ps1 -Profile threaded` copies to `C:/cybersand/web-threaded`; compatibility uses `C:/cybersand/web`. Documenting this command does not execute delivery or remote publication.

## Q29: If an export checksum passes or build-info names the base commit, is the browser build proven current?

Canonical rank: 2

Expected facts:

- No: export-only structural validation/checksums do not prove fresh source-to-artifact build or browser execution.
- source_commit records a snapshot base, not full local changes; retain current source and binary identities with dated evidence.
- HTTP checks, headless fixtures, actual browser runtime and visual inspection are different validation scopes.

### Rank 1: operations/local-build-and-validation.md — Local build and validation > Web compile, export and execution are different checks

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > Web compile, export and execution are different checks
From source, with the SDK active and paths adapted to the host: ```text python tools/build_web.py --cpp <web-godot-cpp> --compile-only python tools/build_web.py --cpp <web-godot-cpp> --godot <godot> --templates <templates> ``` The default profile is compatibility. Add `--profile threaded` for pthreads. Both normal profiles package Rapier; `--cellular-only` is a diagnostic option. `--native-tests` requires a separate `--native-cpp` directory. `--compile-only` returns before runtime tests/export even if `--native-tests` is present. `--export-only` checks existing WASM structure, not freshness against source. The workspace wrapper still supplies the acquisition base as `--source-commit`; that export field is not current HEAD. Capture current source and artifact hashes separately until the producer is repaired in an implementation checkpoint. See [source identity](source-checkpoint-and-recovery.md). Preview generated output through HTTP with WASM MIME and profile headers, then run the actual browser fixture. Checksums/HTTP checks prove packaging; native headless Godot proves native execution; only browser execution tests Web behavior. The [Web guide](web-threading.md) owns hosting requirements, and the [validation ledger](../reference/validation-evidence.md) owns dated outcomes.


### Rank 2: operations/github-development-and-release.md — Repository development and release > Unresolved CI contradictions

Document: Repository development and release
Path: operations/github-development-and-release.md
authority: current-documentation
document-kind: guide
status: Current
scope: Contribution boundaries, Draft qualification, source-matched runtime publication and release prerequisites
canonical-for: [repository-policy, ci-contradictions, release-prerequisites]
last-reviewed: 2026-11-24
Section: Repository development and release > Unresolved CI contradictions
These are source-inspected Web configuration gaps at the recorded accepted source, not inferred failures of every existing Web artifact: | Conflict | Source evidence | Separate required work | |---|---|---| | Web workflows select Emscripten 4.0.11; builder checks 4.0.20 | [Toolchain workflow](../../.github/workflows/web-toolchain.yml), [Web workflow](../../.github/workflows/web-demo.yml), [builder](../../tools/build_web.py) | Align accepted producer/consumer pins and execute the result | | Workflow requests `--native-tests` without a separate `--native-cpp` | Same builder argument validation and Web workflow | Supply the supported isolated native bindings | | `--compile-only` returns before runtime fixtures/export | [Builder control flow](../../tools/build_web.py) | Select and execute the intended runtime/export coverage | | Runtime lock records export templates as `absent-and-unpinned` | [Godot runtime lock](../../third_party/godot-runtime.lock.json) | Record exact template provenance and qualify reproducible exports | The companion wrapper's acquisition-base `source_commit` was a previously recorded identity limitation. Reinspect that separate workspace before treating it as a current fact; this source repository cannot attest an unseen local wrapper. Issue #3 and the canonical Web/build guides retain those release responsibilities. No native/Godot documentation pass resolves Web export or browser acceptance.


### Rank 3: operations/web-threading.md — Web worker profiles and reference tests > Build and preview

Document: Web worker profiles and reference tests
Path: operations/web-threading.md
authority: current-documentation
document-kind: runbook
status: Current
scope: Compatibility/threaded Web build and hosting, fixed worker policy, synchronous ownership, and reference-test interpretation
canonical-for: [web-worker-profiles, worker-reference-benchmark]
last-reviewed: 2026-09-08
Section: Web worker profiles and reference tests > Build and preview
From `C:/kybersand`: ```powershell .\dev.cmd web --profile threaded .local/python/Scripts/python.exe source/tools/serve_web.py --directory source/build/web-threaded --port 8002 --open ``` While the preview server is running: ```powershell .\dev.cmd http-smoke --profile threaded --url http://127.0.0.1:8002/ ``` `dev.cmd web` builds compatibility. Use export-only only with a matching fresh side module; successful packaging does not prove source-to-binary freshness. The [build guide](github-development-and-release.md) owns exact dependency pins and unresolved CI/toolchain drift. Native/Web generated bindings stay separate. The supplied server sets COOP `same-origin`, COEP `require-corp`, appropriate WASM MIME and no-cache behavior. Threaded hosting needs a secure context (HTTPS or localhost) and cross-origin isolation. Serve the complete export, including worker JavaScript, PCK, WASM, notices and manifest. HTTP/checksum success is structural evidence; open the actual browser for execution. Local delivery is a separate explicit workflow after acceptance: `Deliver-Web.ps1 -Profile threaded` copies to `C:/cybersand/web-threaded`; compatibility uses `C:/cybersand/web`. Documenting this command does not execute delivery or remote publication.


### Rank 4: reference/interfaces-and-message-contracts.md — Interfaces and message contracts > Current public surfaces > Native C API

Document: Interfaces and message contracts
Path: reference/interfaces-and-message-contracts.md
authority: current-documentation
document-kind: contract
status: Current
scope: Current C ABI, procedural-generation C++/Godot surfaces and private packed layouts; proposed gameplay/reconfiguration contracts remain distinct
canonical-for: [public-and-adapter-interface-layouts]
last-reviewed: 2026-11-24
Section: Interfaces and message contracts > Current public surfaces > Native C API
**Current:** [c_api.h](../../native/include/cybersand/c_api.h) defines the exported `cybersand_` functions; [c_api.cpp](../../native/src/c_api.cpp) defines validation and failures. The header is the source of exact C types/alignment. These host-ABI structs are not a portable serialized file/network format. Signed `int64_t` positions and rectangle dimensions are cell coordinates; `size_t` capacity/stride/offset widths depend on the target ABI. Start v2 construction from `cybersand_default_config_v2()`. `create_v2` checks `struct_size >= sizeof(cybersand_config_v2)`, `abi_version == 2`, valid backend range and checked conversion of 64-bit capacities to host `size_t`, then World validates geometry/capacities. It returns null on invalid configuration or caught construction failure. Buffered is a representable backend value, but its tick implementation throws. | Versioned surface | Current additional fields/behavior | |---|---| | `cybersand_config_v2` | Size/version; chunk/activity/core/radius; sleep and ambient temperature; backend/workers; chunk reserve, job threshold, active-core/chunk/max-chunk/event capacities and maximum explosion radius | | `cybersand_tick_stats_v2` | Legacy tick/visited/moved/active/dirty counts plus scheduled cores, four phase-job counts, owned chunk/temperature allocations and committed deferred events | | `cybersand_material_info_v2` | Base material metadata plus kernel, initial state bytes and write radius | | `cybersand_material_info_v3` | v2 base plus density-motion direction, target exchange acceptance and lateral-flow mode | | `cybersand_material_info_v4` | v3 base plus dimensionless 0–255 viscosity index | Material-info v3/v4 are additive query layouts; they do not change the config ABI version from 2. Valid material queries return 1; invalid ID or null output returns 0. Density metadata is a gameplay scale, not a declared physical density unit. Native optional temperature is signed 16-bit storage; physical thermal calibration/conduction is not defined by this API. Checked set/tick/reservation/explosion/copy methods return 1/0; legacy set/tick surfaces provide weaker error reporting. `tick_v2` zeroes output after a caught exception, but **does not roll World back**. Null input/output also fails; no structured C error reason is returned. Additive `has_failed`, `completed_tick_index` and `clear` queries/operation expose quarantine and explicit reset without changing v2 struct layout. Native `tick_index` remains attempted identity; `completed_tick_index` is the last successful tick. Hash and resident-byte queries are [scoped diagnostics](../architecture/determinism-and-boundary-transfers.md), not complete replay capture or process-memory accounting.


### Rank 5: reference/invariants.md — Architectural and simulation invariants > Brine IN standalone adapter invariants

Document: Architectural and simulation invariants
Path: reference/invariants.md
authority: current-documentation
document-kind: contract
status: Approved design
scope: Stable review IDs with current enforcement, known exceptions and approved requirements; this register is not a test-result ledger
canonical-for: [invariant-register]
last-reviewed: 2026-11-24
Section: Architectural and simulation invariants > Brine IN standalone adapter invariants
remains open | | LCBH-009 | Current bounded Water Feel route: explicit unblinded sampled Exploratory rebuild retains original policy/recipe/player/actions/ledger, with exact serial/applied/definition success acknowledgement. The later desktop reference-body stage follows LCBH-012. Initial normalization never rewrites future sources; CY Water fractional scheduled sources, blind and unsupported body routes refuse before mutation. Original Current/blind defaults remain separate | | LCBH-010 | Current apparatus/export boundary: an exporter identifies an unqualified build; explicit Web terminal JSON, successful POST, earliest console/network and ordinary visual execution are separately evidenced. Native headless Web-scene passes never become actual Wasm/browser acceptance | | LCBH-011 | Current native adapter slice: decoded CYSD thermal tuples, including nonambient Empty, prepare under the existing one-use commit fence; actual source bytes bind payload-only identity, fractional whole-cell Water requires explicit normalization, and refusal retains old World/receipt/generation. Legacy Current import is unchanged; ordinary importer/host/platform qualification remains open | | LCBH-012 | Current desktop reference-body route: original three Water Feel bodies remain frozen with actual initial masks until terrain/readiness and final native/worker fences pass; success adopts the same permanent space. Optional helper poses are copied and require exactly three finite entries before private allocation; omitted arrays preserve exact Water defaults and do not admit another constructor. Refusal retains the old graph/World/receipt/record. Normal unpaused feedback obeys age rejection and exact Water accounting; actual Wasm/visual qualification and host-mask CYPS continuation remain open | | LCBH-013 | Current bounded synchronous import route: explicit Exploratory arming changes only the next-import selection. Unsupported inherited interaction/diagnostic laws and independent transport refuse before preparation; known private Baseline exemption binds actual component/generation/applied receipt. Native thermal preparation, private sampled player, final execution and qualified record precede final serial/native commit. Refusal retains old World/owners/receipt/record; restart retains accepted input. Physical/Tower/showcase imports refuse and unarmed Current remains available; no persisted policy/full-host/browser qualification follows | | LCBH-015 | Current native default-demo API: ordinary reset and prepared compilation consume one native ordered recipe. Water/transport settings inherit; production interaction/diagnostic/gain/editing lifecycle resets on success. Candidate masks and copied receipts precede the one-use fence. Native origin binds actual generation and retires on other World replacements; imports with equal tuples cannot acquire it. Later bounded owner/capacity proof is LCBH-019; complete host and final platforms remain Planned | | LCBH-014 | Current bounded synchronous ordinary-demo route: only four authored body-free recipes gain Exploratory rebuilding, with exact ordered tuples, privately staged sampled player and actual final quality/view/cadence before serial/native commit. Authored identity binds source ID and native generation, never an imported save label. Refusal retains World/owners/receipt/record; healthy Restart reconstructs accepted recipe/policy/geometry. Quarantined prepared Restart refuses, with truthful

## Q30: Do the old sanitizer results and current Windows fixtures prove Linux, Firefox and Safari work?

Canonical rank: 1

Expected facts:

- No: M11 sanitizer/results are historical with their recorded revision/platform scope; current Windows tests do not prove other platforms.
- Dated Chromium compatibility/threaded evidence is separate. Current Linux native, headless and rendered-fixture results have their own source/runtime records, including the MAT-002 review; old sanitizer or Windows results do not establish them. Firefox/Safari execution remains unestablished by these records.
- LFS pointer files are not usable runtime binaries and historical totals must not be relabelled as fresh passes.

### Rank 1: reference/validation-evidence.md — Validation evidence ledger > Platform limits and honest outcomes

Document: Validation evidence ledger
Path: reference/validation-evidence.md
authority: current-documentation
document-kind: reference
status: Current
scope: How to locate and interpret source-bound validation; dated results do not certify a new runtime or every platform
canonical-for: [validation-results, platform-evidence, historical-evidence-boundaries]
last-reviewed: 2026-11-24
Section: Validation evidence ledger > Platform limits and honest outcomes
Old sanitizer results and current Windows fixtures do **not** prove Linux, Firefox or Safari work. Historical M11, dated Chromium compatibility/threaded results, later Linux native/headless/rendered evidence and physical Windows observations retain separate scope. Browser support must be established on the actual source, profile and browser; a successful Web compile is insufficient. The existing records do not supply universal Firefox/Safari acceptance. Web toolchain/template/export-identity obligations remain separately tracked. Use explicit outcomes: **PASS** for executed criteria that passed; **FAIL** for an executed failure; **SKIP** for a deliberately suppressed gate; **NOT RUN** for no execution; **BLOCKED** for an unavailable prerequisite. Describe the reason and preserve failed attempts. A Draft-skipped expensive job is not a green runtime result. A documentation candidate can be qualified as documentation while runtime and physical acceptance remain outside its scope. Keep diagnostic evidence minimal and safe to share. Record source, version, short reproduction, actual result and relevant sanitized output. Art traffic and owner maps can contain private content; do not attach whole archives merely to report a UI defect. Never publish provider credentials.


### Rank 2: operations/local-build-and-validation.md — Local build and validation > Repository-native build and test commands

Document: Local build and validation
Path: operations/local-build-and-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-11-24
Section: Local build and validation > Repository-native build and test commands
From the source root on a configured Linux host: ```sh make c-header-check make -n test make -j2 test make sanitize make thread-sanitize ``` `make test` includes the current native World, soliding, worldgen and material baseline targets. The [Makefile](../../Makefile) is the executable inventory; `make sanitize` and `make thread-sanitize` have distinct target coverage, so do not claim that either alone executes every subsystem sanitizer. Focused generation and soliding sanitizer targets remain available. The default AddressSanitizer configuration enables leak detection; a historical hosted exception is not a new default. These commands may compile substantial native source. They are procedures, not pass claims. Set a budget appropriate to the selected target and host; do not reuse historical 120/300-second examples as current full-suite budgets. The accepted [CI execution policy](ci-execution-and-performance.md) derives hosted allowances without weakening scientific cases or sanitizer failures. A GDExtension rebuild additionally needs pinned godot-cpp and SCons: ```sh export GODOT_CPP_ROOT=/absolute/path/to/pinned-godot-cpp export SCONS_PYTHON=/absolute/path/to/build-venv/bin/python SCONS_JOBS=2 tools/build_pinned_godot_cpp.sh linux CYBERSAND_NATIVE_OUTPUT="$PWD/build/libcybersand_native.linux.x86_64.so" \ tools/build_native_extension.sh ``` The example writes the candidate extension under ignored `build/`, leaving the retained library alone. Inspect and qualify the candidate before installing it into a test project. Installing a locally built library does not create accepted runtime provenance: [guarded publication](github-development-and-release.md#source-matched-runtime-publication) requires its actual source, input hashes, target-platform execution and lease. The build scripts enforce pinned dependency revision and source checks; do not use `CYBERSAND_ALLOW_TOOLCHAIN_DRIFT` to report a reproducible release. For Windows GDExtension cross-builds, use `build_pinned_godot_cpp.sh windows` and [build_native_extension_windows.sh](../../tools/build_native_extension_windows.sh) with the pinned `LLVM_MINGW_ROOT`/`WINDOWS_CXX` inputs. A PE/import inspection is separate from execution on Windows. The root `build_windows_msvc.bat` is a native core build entry point with its explicit test list, not the complete Godot/native qualification matrix. The [Windows execution helper](../../tools/ci/run_windows_godot_regressions.py) and accepted workflow own source-bound Windows Godot execution.


### Rank 3: operations/gen008-flatten-qualification.md — Flatten / Bake History evaluation > Source-backed qualification

Document: Flatten and Bake History qualification and owner evaluation
Path: operations/gen008-flatten-qualification.md
authority: current-documentation
document-kind: runbook
status: Current
scope: GEN-008-FLAT-001 native material-baseline qualification, source-bound Windows evaluation and separate owner graphical acceptance
canonical-for: [flatten-baseline-qualification]
last-reviewed: 2026-11-24
Section: Flatten / Bake History evaluation > Source-backed qualification
The original `gen008-flatten-qualification.yml` campaign used the feature branch and an explicit source-bound request. Its results below are historical qualification, not a current branch launch direction. It reuses the accepted MAT-AUTH and integrated Workbench publisher, pinned Godot 4.7, godot-cpp, Linux compiler, LLVM-MinGW Windows cross-build and Rapier. Original catalogue, Lab, integrated Workbench, graphical and offline-package gates remain in place. Windows first runs a separate, bounded 512² platform diagnostic with the same pinned engine and candidate native library. Its original artifact checks the storage-denial fixtures, actual engine memory measurement and owner-fault Save/reopen path before the longer retained suites. This diagnostic does not replace any final gate: the complete twelve-record Flatten inventory, accepted regression families and delivered-copy smoke remain mandatory afterward. The added native contract covers complete stored IDs, masked/fractional Water, nonmutation of tick/thermal/physics state, actual simulation-derived material transformation, output ownership, invalid dimensions/IDs/length/capacity, owner failure and 512²/1024²/2048² planes. Normal and ASan/UBSan execution are separate. Leak detection is enabled by the sanitizer Make target unless an explicitly recorded local environment override is needed. Existing full Native and GDExtension/Godot, Documentation/provenance and Palette workflows are requested on the four-path runtime publication child; dispatch is not a PASS receipt. The real Workbench fixture generates a native map, paints and erases, uses manual and agent chronological history, simulates, captures the entire native plane and Flattens it. Complete before/after arrays and the adopted baseline must agree. It also checks the same native generation, actual Rapier session/body identities, paused actor motion state, running simulation, stale human/agent work, cancellation and failure atomicity. The subsequent Save is checked against an independent expected material plane in a completely new Godot process. Later simulation is explicitly excluded from the saved authored plane. The default qualification cases are 512², 1024² and 2048² with one native worker, plus 512² with four workers. Each author process must terminate before its paired reopen process starts. Windows uses actual ANGLE; Linux uses X11. Original framebuffers are retained with native material hashes and application/runtime input hashes. The format regression separately covers truncated, corrupt, unsupported, oversized and failed-write cases, plus legacy format routing; the retained native history regression provides real legacy fresh-process compatibility evidence. Two additional processes exercise a genuine native capacity failure after Flatten and acknowledged edits, rather than setting a test failure flag or injecting a synthetic completion. The fault must quarantine the real owner. Flatten and unsafe Reset/Restore must refuse; explicit Save must preserve the quarantined owner and its existing authored data without capturing, restarting or resetting that World. The author process then terminates. A new process loads the


### Rank 4: decisions/ADR-002-double-buffered-tile-jobs.md — ADR-002: Benchmark-gated cellular scheduling backends > When should this decision be revisited?

Document: ADR-002 — Benchmark-gated cellular scheduling backends
Path: decisions/ADR-002-double-buffered-tile-jobs.md
authority: current-documentation
document-kind: decision
status: Current
scope: Accepted phased scheduler selection, retained buffered candidate and criteria for reconsideration
canonical-for: [decision-phased-in-place-scheduler]
last-reviewed: 2026-09-08
Section: ADR-002: Benchmark-gated cellular scheduling backends > When should this decision be revisited?
Compare behavior, total/stage time, active-work scaling, memory/copy traffic, barrier imbalance, conservation and capacity behavior on representative current and larger fixtures. A faster backend that weakens ownership or accepted invariants fails the gate. A future Buffered design must specify halo/output ownership and canonical transfers before implementation. Maintain exact worker parity within the chosen phased semantics, shifted/edge fixtures and rule-radius checks. Historical sanitizer passes do not validate current Windows/Web artifacts. Region filtering also differs between serial and phased paths: phased pauses excluded work and wakes new coverage once; serial ignores interest. The [interest contract](../systems/world-storage-and-interest-region.md) records that intentional distinction. Any production selector must expose such differences rather than claim universal backend equivalence.


### Rank 5: reference/validation-evidence.md — Validation evidence ledger > Source and artifact custody

Document: Validation evidence ledger
Path: reference/validation-evidence.md
authority: current-documentation
document-kind: reference
status: Current
scope: How to locate and interpret source-bound validation; dated results do not certify a new runtime or every platform
canonical-for: [validation-results, platform-evidence, historical-evidence-boundaries]
last-reviewed: 2026-11-24
Section: Validation evidence ledger > Source and artifact custody
```mermaid flowchart TD S["Source commit and input hashes"] --> B["Runtime build and hash"] S --> T["Test source and commands"] B --> E["Executed artifact receipt"] T --> E E --> P["Package and shipped launcher"] P --> O["Physical owner evaluation"] ``` Each stage records its own identity and result; none is inferred from the previous stage. Documentation-only commits may preserve exact native input bytes while changing the overall Git tree. Keep the original native build commit and the actual tested script/source identity. Conversely, an old successful run cannot qualify changed native input merely because the DLL still loads. The selected [Windows native provenance](../../godot/addons/cybersand_native/runtime-provenance.json) and [Linux native provenance](../../godot/addons/cybersand_native/runtime-provenance.linux.json) contain source inputs, artifact hashes and original workflow evidence. Rapier has its own [Windows](../../godot/addons/godot-rapier2d/runtime-provenance.windows.json) and [Linux](../../godot/addons/godot-rapier2d/runtime-provenance.linux.json) records. Use [source custody](../operations/source-checkpoint-and-recovery.md) and [publication procedure](../operations/github-development-and-release.md) for verification and branch leases.

## Q31: Why is the old consistency check red, and should I update its hashes to make the release pass?

Canonical rank: 1

Expected facts:

- The old check compares current files to M11; strict comparison still reports drift, including unresolved payload pointers. Preserve previous failures.
- M11 integrity now checks all 28 original source hashes against the audited Git revision and 18 retained records. Never rewrite historical hashes.
- Current checks independently validate documentation, dependency versions and source-bound runtime/LFS identity; identity does not prove execution.
- Web CI/toolchain/template/export provenance contradictions remain separate issue #3 obligations.

### Rank 1: operations/current-and-historical-validation.md — Current validation and retained M11 integrity > Why did the old consistency check report hash mismatches?

Document: Current validation and retained M11 integrity
Path: operations/current-and-historical-validation.md
authority: current-documentation
document-kind: guide
status: Current
scope: Separate current source/runtime qualification from immutable historical M11 evidence and actual platform acceptance
canonical-for: [current-validation-gates, m11-retention-policy]
last-reviewed: 2026-11-24
Section: Current validation and retained M11 integrity > Why did the old consistency check report hash mismatches?
Later source and runtime bytes legitimately differ from M11. An unresolved LFS pointer also differs from a materialized library. Neither comparison alone proves corruption of the historical evidence. **Rejected:** rewriting M11 hashes or suppressing integrity errors to make current builds look accepted. [check_m11_consistency.py](../../tools/ci/check_m11_consistency.py) verifies the 28 original [BUILD_ID](../BUILD_ID.md) source hashes against Git blobs at audited commit `05ea45fda7bdd7b0150eb86c4922c202e89e08f4`, and the retained records against [their immutable manifest](../audits/m11-retention.json). Text comparison uses canonical Git LF bytes. Missing historical objects fail the check: a shallow checkout must obtain the required history before claiming historical integrity. The original tag and hashes remain unchanged. `--compare-working-tree` explicitly asks for the strict legacy comparison. Expected current-versus-M11 differences can produce a nonzero result; report it as diagnostic drift, separately from the historical-integrity and current-runtime gates. The [original reconciliation](../audits/2026-09-08-validation-reconciliation.md) preserves the failure and why those checks were separated.


### Rank 2: operations/documentation-maintenance.md — Documentation maintenance and retrieval contract > Documentation-update checklist

Document: Documentation maintenance and retrieval contract
Path: operations/documentation-maintenance.md
authority: current-documentation
document-kind: guide
status: Current
scope: Required documentation synchronization, canonical ownership, retrieval corpus and evidence workflow
canonical-for: [documentation-update-checklist, rag-schema, retrieval-policy]
last-reviewed: 2026-11-24
Section: Documentation maintenance and retrieval contract > Documentation-update checklist
Apply this at every implementation checkpoint, including tuning-only changes. 1. **Identify the actual inputs.** Record source Git root/HEAD/branch/status, relevant LFS objects and dirty paths; name a recoverable checkpoint. Preserve user work. Use [source checkpoint guidance](source-checkpoint-and-recovery.md). 2. **Map changed claims.** Search symbols, old values, aliases and reverse links. Review the affected subsystem, ownership/lifetime, interface layout, invariants, configuration/capacity, ADR, roadmap, build/test guide and user controls. A change matrix should name each affected page or explain why it is unaffected. 3. **Edit canonical homes first.** Attach source path plus symbol to important Current claims; use stable named sections for cross-links. Explain native, desktop, Web and fallback differences wherever they change the answer. 4. **Reconcile statuses and uncertainty.** Distinguish code from Approved intent. Record partial enforcement, failures, missing tests and decisions precisely. An observed defect must not become a promised invariant by omission. 5. **Synchronize routes and execution order.** Update the manifest, retrieval question destinations, documentation/retrieval indexes and roadmap. Update the handover for operational changes and owner-intent reference for new preferences. When a dependency/order/scope decision changes, update its canonical programme graph and all affected GitHub issue mirrors/comments in the same checkpoint; issue numbers and creation dates are never an ordering authority. Preserve old anchors that still have useful incoming links or update every caller. 6. **Record evidence separately.** Include date, command, timeout, OS/architecture, tool/dependency versions, fixture/configuration/profile/worker count, source revision plus dirty-file identity, artifact hashes and actual outcome. Identify whether evidence is inspection, compile, checksum, HTTP, native runtime, browser runtime or visual acceptance. Name exactly what was compared: level bytes, content/state hash, conservation, body tolerance or full replay. 7. **Preserve history.** Keep past results, failures, inconclusive runs and release hashes intact. Add a new evidence record and scope/link the old one. Never update historical hashes to make a new revision look validated. 8. **Check structure and retrieval.** Run the commands below. Inspect answers to affected natural questions for factual completeness and wrong-status/platform substitution, not only keyword hits. Add questions for newly discovered gaps; report them separately from a previously frozen evaluation set. 9. **Review the final diff and checkpoint.** Verify implementation scope, generated files and history preservation. Commit the authorized change locally with its validation report. State unresolved contradictions and readiness limits.


### Rank 3: reference/validation-evidence.md — Validation evidence ledger > Current and historical checks are separate

Document: Validation evidence ledger
Path: reference/validation-evidence.md
authority: current-documentation
document-kind: reference
status: Current
scope: How to locate and interpret source-bound validation; dated results do not certify a new runtime or every platform
canonical-for: [validation-results, platform-evidence, historical-evidence-boundaries]
last-reviewed: 2026-11-24
Section: Validation evidence ledger > Current and historical checks are separate
From the source root, use the commands in [current and historical validation](../operations/current-and-historical-validation.md). The principal checks have deliberately different meanings: | Check | Scope | |---|---| | `python3 tools/ci/check_docs.py` | Metadata, canonical ownership, corpus selection, local links/anchors and frozen source references; source semantics require review | | `python3 tools/ci/check_repository.py` | Current docs, dependency pins and recorded runtime/input/pointer identity; materialization is reported separately | | `python3 tools/ci/check_repository.py --require-materialized` | Also requires the repository's selected runtime payloads to be real bytes | | `python3 tools/ci/check_m11_consistency.py` | Retained historical records and all 28 original source hashes against audited Git revision `05ea45fda7bdd7b0150eb86c4922c202e89e08f4` | | `python3 tools/ci/check_m11_consistency.py --compare-working-tree` | Explicit comparison of today's implementation with M11; expected source evolution is reported as drift, not repaired by changing historical hashes | | `python3 tools/docs/retrieval_eval.py --output <path.json>` | Saved lexical retrieval contexts/ranks for the selected question set; answer correctness needs separate source-grounded review | The frozen questions retain some pinned companion-workspace source references. The Documentation workflow identifies that companion commit; a bare source clone can lack those inputs. Recover the pinned context or report the missing boundary, rather than altering frozen expectations to conceal it. Preserve original failures and M11's 18 retained records. Current source drift, an unavailable old Git object, a missing LFS payload and a corrupt historical record are different failures. A shallow clone may need the audited Git objects. Neither updating old hashes nor disabling the historical check is a legitimate repair.


### Rank 4: operations/cybersand-codex-development-handover.md — Development handover > Finish a checkpoint

Document: Development handover
Path: operations/cybersand-codex-development-handover.md
authority: current-documentation
document-kind: guide
status: Current
scope: Current task intake, ownership and handoff; implementation status, intent and qualification have separate canonical homes
canonical-for: [development-onboarding]
last-reviewed: 2026-11-24
Section: Development handover > Finish a checkpoint
Apply the [documentation checklist](documentation-maintenance.md#documentation-update-checklist). Update the owning contract, user controls, interface/default/limit references, current-state entry and retrieval routes together. Search for old values and incoming links; preserve dated failures and exact evidence identities. Record each validation command and its source, runtime, platform, exit result and scope. Distinguish PASS, FAIL, NOT RUN, SKIP and BLOCKED. A Draft-suppressed test is SKIP, not PASS. Run focused checks for the changed behavior, then satisfy the applicable release gates when the task actually authorizes that stage. Use the [current versus historical gates](current-and-historical-validation.md) instead of rewriting M11 hashes to match today's implementation. Prepare a reviewable commit/PR with the concrete problem, resulting behavior, validation, remaining limitations and any substantive design choice. Follow the current task's Draft/Ready boundary. Explicit owner actions such as merge, release, default promotion and deletion are not granted by an old handover. For documentation-only work, structural and retrieval qualification does not claim a new engine or physical-platform acceptance. A final response should link the candidate, identify source/head/tree, summarize the useful reader changes and state what remains unresolved.


### Rank 5: operations/source-checkpoint-and-recovery.md — Source checkpoint and recovery > How should the next checkpoint be verified?

Document: Source checkpoint and recovery
Path: operations/source-checkpoint-and-recovery.md
authority: current-documentation
document-kind: guide
status: Current
scope: Actual checkout identity, recoverable source and runtime custody; historical workspace locations are evidence only
canonical-for: [source-identity, local-checkpoints, recovery-coverage]
last-reviewed: 2026-11-24
Section: Source checkpoint and recovery > How should the next checkpoint be verified?
Preserve unrelated edits and make the task's own changes reviewable. Record the actual source/local delta, selected runtime hashes and the feasible validation results. Run `git diff --check` and inspect the intended write set before commit. Do not replace a dirty working tree with an old archive to make hashes agree. For an authorized recovery exercise, restore into a separate directory, materialize the required LFS payloads, authenticate the input manifest and test the restored project. `git fsck --full` checks Git object integrity; it is not an LFS materialization, complete toolchain or platform execution test. A shallow clone may need the relevant older Git objects before historical checks can run. For publication, use the established branch/source lease and exact permitted runtime/provenance write set. A newer branch tip invalidates an old lease; inspect and reconcile it instead of force-updating another writer's work. A local checkpoint is not owner merge approval. See [publication and review](github-development-and-release.md).

## Q32: After changing physics ownership, which documentation and evidence must I update before a checkpoint?

Canonical rank: None

Expected facts:

- Map affected canonical contracts, ownership/lifetimes, invariants, configuration, ADR, roadmap, build/test guide and retrieval routes.
- Record actual source/checkpoint identity and scoped validation; search aliases and reverse links for stale duplicate claims.
- Keep historical records intact and run structural/link/retrieval checks plus relevant behavioral checks.

### Rank 1: operations/microscenarios-programme.md — CyberSand MicroScenarios and intermaterial-interactions programme > Agent checkpoint protocol

Document: CyberSand MicroScenarios and intermaterial-interactions programme
Path: operations/microscenarios-programme.md
authority: current-documentation
document-kind: design
status: Planned
scope: Canonical development-order graph for reusable exploratory MicroScenarios, anomaly triage, non-kinetic intermaterial-interaction authoring/tuning, and staged showcase work
canonical-for: [microscenarios-programme, microscenarios-development-order, intermaterial-interaction-programme]
last-reviewed: 2026-09-20
Section: CyberSand MicroScenarios and intermaterial-interactions programme > Agent checkpoint protocol
Before starting any issue in or adjacent to this programme: 1. Read root `AGENTS.md`, the development handover, status/roadmap and this page. 2. Inspect actual branch/HEAD/status and active overlapping PRs. 3. Read the target issue plus its **named** dependencies; do not sort issue numbers. 4. State which hard prerequisites are satisfied and which lanes are merely parallel. 5. Preserve current source/ADR ownership. A scenario need is not permission to implement an engine feature inside scenario code. 6. When an exploratory anomaly appears, capture/reduce/triage before assigning it to a subsystem. 7. At every checkpoint, update this programme, roadmap, retrieval routes/corpus and affected issue mirrors together if dependency/order/scope changed. 8. Preserve dated/historical evidence; never rewrite old results to make them match the new scenario/profile/source. 9. Run documentation/retrieval/repository checks required by `documentation-maintenance.md` and report inherited failures separately. If an autonomous agent cannot reconcile the issue body with this programme and the architecture programme, it must treat that as a planning contradiction, record it, and resolve the documentation/issue mirror before changing physics.


### Rank 2: operations/soliding-stage3-freeze.md — Issue 12 Stage 3 execution freeze > Authority, checkpoint and purpose

Document: Issue 12 Stage 3 execution freeze
Path: operations/soliding-stage3-freeze.md
authority: current-documentation
document-kind: runbook
status: Approved design
scope: Frozen execution contract for completing scalable settled-region discovery after PR #43; read-only discovery only, no acceleration or material ownership transfer
canonical-for: [soliding-stage3-execution-freeze]
last-reviewed: 2026-11-24
Section: Issue 12 Stage 3 execution freeze > Authority, checkpoint and purpose
**Scope qualification, 2026-11-24:** this is the frozen September 19 execution contract, retained for its stage boundaries and evidence requirements. Its PR #43 foundation gaps and named task assignments describe that source checkpoint. They are not active branch instructions or an inventory of current missing features. Consult the [current discovery contract](../systems/settled-region-discovery.md), [Soliding programme](soliding-programme.md) and [current handover](cybersand-codex-development-handover.md) before new work. This page freezes the dependency-ready implementation contract for issue #12 Stage 3 after PR #43 head `90903355f5880e8f141ee6caea34840ad8b4990c`. PR #43 remains a foundation checkpoint: lifecycle, bounded tile journal, producer audit, ordinary-sleep control and synthetic journal-cost evidence exist, but production World notifications and cross-block connected-region discovery do not. Before executing this packet, re-read actual main, PR #43 CI/merge state and #12. If main or PR #43 has advanced, reconcile source identity without silently changing the architecture below. A runner/CI update alone does not invalidate the frozen native design, but implementation must still target the actual source being changed. This freeze exists so a supervising Sol parent can delegate bounded implementation to Spark workers without asking those workers to make architecture decisions. **Stage 3 remains read-only discovery. Cells are the sole material owner.** No scheduler skip, stationary proxy, compact payload, cohesion, Rapier aggregate, fracture, persistence migration or material-rule change is admitted here.


### Rank 3: architecture/inertial-cellular-v1.md — Inertial cellular reference > Standalone Godot readback and explicit geometry

Document: Inertial cellular reference
Path: architecture/inertial-cellular-v1.md
authority: current-documentation
document-kind: reference
status: Current
scope: Current-main Water and Brine inertial reference, retained integer momentum, whole-cell admission, carrier ownership, radius and state costs; source-bound native/application evidence remains distinct from scientific comparison and human acceptance
canonical-for: [inertial-cellular-v1-brine, inertial-cellular-v1-water]
last-reviewed: 2026-11-24
Section: Inertial cellular reference > Standalone Godot readback and explicit geometry
native schema. Water quantity remains visible+overfill, while whole-cell Oil/Brine populations use cell counts. That standalone checkpoint added no prepared token, UI, constructor coordinator, verified provenance, Web qualification or new physics. Its then-pending merge gates subsequently passed; later #256/#257/PLAY supply bounded application integration. Full scientific, graphical/manual and source-verified host acceptance remain separately qualified, as recorded in the current checkpoint above. The `lcb005-inertial-runtime-publication.yml` profile reuses the accepted shared-contract verifier in an isolated module. Its initial preparation left `tools/ci/lcb005_inertial_publish_request.json` absent. An explicit committed request, exact candidate branch/source/workflow lease and unchanged source are required before either target build. After the separately frozen #201 checkpoint is integrated, both actual Windows and Linux executions must pass all fourteen scoped cases plus import, including the twelve retained cases, all six pressure-optimization sections and all six standalone IN sections. The IN-only checkpoint cannot qualify that union. Only the two runtime LFS paths and their two manifests may append in one source-parent commit; the atomic branch lease refuses a changed remote tip. Local preparation does not publish, arm a request or replace ready-PR acceptance. The later explicit request and actual import-plus14-case execution on both OSes are recorded in the union publication ledger; no fresh publication is started by this documentation update.


### Rank 4: operations/physics-characterisation-plan.md — Physics characterisation and soliding plan > Delivery order and exit gates

Document: Physics characterisation and soliding plan
Path: operations/physics-characterisation-plan.md
authority: current-documentation
document-kind: runbook
status: Planned
scope: Proposed experiments for material penetration, player support, barrel settling and reversible aggregate physics; inspection is not runtime acceptance
canonical-for: [physics-characterisation-plan, soliding-investigation]
last-reviewed: 2026-09-09
Section: Physics characterisation and soliding plan > Delivery order and exit gates
1. **Baseline checkpoint:** scripted P1–P4 fixtures, bounded metrics and a dated report separating reproduction from hypotheses. Extend existing native `test_world.cpp`, Godot `test_cell_world.gd` and Rapier manual-step coverage where appropriate; do not claim the old floor fixture proves granular support. 2. **Interaction checkpoint:** implement powder/player support policy and pair exchange control separately; preserve counts, Water conservation, meaningful reactions, wake/progress and matching-worker determinism. 3. **Barrel checkpoint:** choose a support model from measurements, meet ordinary half-depth/no-creep and excavation gates, then validate tilted/multiple/fast bodies and platform latency. Report trajectory tolerances explicitly. 4. **Soliding checkpoint:** candidate diagnostics, then stationary proxies, then an ownership ADR and one dynamic aggregate. Promotion is optional under load; defer safely when capacity is unavailable. Set numeric per-frame extraction, shape, membership and memory budgets from measured target-platform headroom. Use `dev.cmd native-test`, a freshly rebuilt adapter and `dev.cmd godot-test`, then build and actually execute affected Web compatibility/threaded fixtures. Keep desktop async results distinct from headless Web-controller invocation and real browser execution. Preserve F01/F02 regressions. Each implemented increment must update canonical materials/coupling/ownership/interfaces/configuration, ADRs, roadmap, tests, evidence and retrieval as applicable; save/UI documentation changes only when those behaviours change. No production timing or generalized replay guarantee follows from this plan.


### Rank 5: systems/material-appearance-and-rendering.md — Material appearance and rendering

Document: Material appearance and rendering
Path: systems/material-appearance-and-rendering.md
authority: current-documentation
document-kind: contract
status: Current
scope: Native RG8 presentation, palette/program LUTs, shader flair, temporal smoothing, glow, and current GPU upload limitation
canonical-for: [material-visual-projection, palette-program-appearance, render-upload-cost]
last-reviewed: 2026-10-19
Section: Material appearance and rendering
**Current:** native material identity and one derived condition byte form an immutable RG8 presentation stream. GPU shaders create variation, animation, relief, and emission without changing physics. CPU patch copies are dirty-region proportional, but each changed GPU texture update still uploads the full 1024² RG8 image. True GPU subregion writes are **Planned**. This page owns appearance and cost semantics at the [secured checkpoint](../operations/source-checkpoint-and-recovery.md). The [render bridge](../architecture/rendering-and-gameplay-bridges.md) owns payload lifetimes; the [evidence ledger](../reference/validation-evidence.md) distinguishes headless checks, browser observations, and absent representative GPU profiling.
