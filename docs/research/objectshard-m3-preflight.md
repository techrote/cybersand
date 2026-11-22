---
title: ObjectShard continuous-play worker and Rapier preflight
status: Current
document-kind: contract
scope: Experimental M3 real-worker rehearsal and explicit ordinary Workbench integration boundary; Draft/HOLD
canonical-for: [objectshard-m3-worker-and-physics-contract]
last-reviewed: 2026-11-22
related-documents: [objectshard-001.md, ../operations/objectshard-m3-preflight-playtest.md, ../audits/2026-11-22-objectshard-m3-recovery.md]
---

# M3-PREFLIGHT-001 — executable Workbench preparation

## Executable candidate scope

The opt-in `object_shard_worker_rehearsal.tscn` executes one real native ObjectShard World on one exclusive worker thread and the real Rapier bridge on main. Ordinary material edits trigger actual discovery, transfer, collision switching and motion. Material/pose publication uses only the last applied native snapshot. This is an executable ownership and timing rehearsal, **not production Workbench integration**. It preserves the synchronous 001R Lab as a control and does not alter production input, Water, worker, renderer or physics-host defaults.

The separate developer launcher, source-bound report/capture and host-specific replay establish a practical play → export → reproduce → repair loop. Ordinary Workbench World attachment, persistence and fracture remain separate work; the programme label here describes Workbench preparation only.

## Exact source ownership and concrete blocker

[The source ownership ledger](objectshard-m3-source-ownership.json) records exact Git objects and SHA-256 identities. At the 2026-11-22 06:24 UTC refresh, main remained `662df51cd8409a52332fa7ef15d06d8ab8945aed`; #740 was `adedb2761bad6cce91002ffe50c50c39b5f63645`, #719 was `d316c281e0abb575eb6302afc12ec44f211460ba`, #682 was `4302ba2058c1bdac1c3fc54540c078dfc9147573`, and #734 was `34606231677d4287e3f1ae595b6e2ce93cc6fa75`. All remain Draft and unmerged. The newer #740 Wave invalidation optimization and #734 cache diagnostics leave the inspected GCR/physics bridge contract unchanged. These branches were inspected read-only, not incorporated or runtime-qualified by this mission. Recovered staging identities remain in the dated evidence.

| Existing boundary | Source finding | Integration consequence |
|---|---|---|
| Native Workbench GCR | `workbench_granular_coupling.inc` is the identical blob `c0c8a8f2f927471cc57bd238ba37f7d9137cda9f` in accepted main and all four inspected concurrent heads. It fixes owner roster, proxy count, shape geometry, mass and inertia for a prepared World; 8 shapes/owner and 64 proxies remain enforced. | Mutable ObjectShard geometry cannot enter by resubmitting a changed ordinary GCR roster. A separately versioned mutable adapter is required. |
| ObjectShard native facade | `CyberObjectShardLab.configure` privately constructs its coordinator/World. Its bound methods expose no `attach_world` or `set_world`. | Creating the facade beside Workbench would create a second authoritative World. This rehearsal explicitly avoids claiming such an attachment. |
| SimulationWorker | Copied samples carry session/epoch and the result captures the sample actually consumed, World generation, render and terrain revisions. | A future ObjectShard command must run under that existing native owner; an enqueue acknowledgement cannot authorize physics. |
| PUBPRES719/682 | Their rendezvous and presentation repairs preserve GCR admission. The same-frame continuation spends one genuinely scheduled callback, checks owner/worker/bridge/session/sample/terrain and is single-use; it creates no extra physical time. | Integrate the accepted successor's callback policy, retaining its temporal identity. Do not call the synchronous ObjectShard `step_motion` with an asynchronous queue callback. |
| GPU presentation programme | Coherence helpers assess presentation under bounded swept-mask scans; they do not mutate World or grant physics authority. | Publish one accepted material/pose revision pair through the accepted renderer; no independent newer RID transform override. |
| GEN-006 worker protocol | Bounded pure-value messages bind session/area/incarnation/source/runtime and operation identity. Background work uses explicit time/memory reservations; recovery retains a failed owner. The latest controller retains unresolved advancement and admits its exact completed interval against the original game-time plan before release. | An active shard needs an explicit residency/custody policy before area eviction or save. Current shard persistence is unsupported; silently resetting or detaching ownership is forbidden. |

The executable `test_object_shard_workbench_contract.gd` calls actual current native Workbench interfaces. It admits a legitimate initial roster and refuses changed geometry, mass, inertia, body identity, session, epoch and omissions without material mutation, then accepts the valid original roster. It also verifies the facade has no World-attachment API. This qualifies the inspected accepted native contract, **not execution of the competing PUBPRES/GEN branches**.

The later 07:51 UTC delivery refresh is retained in the source ledger and
[exact dependency receipt](../audits/objectshard-m3-20261122/final-qualification/delivery-interface-refresh.json).
Main and all inspected PUBPRES/ObjectShard heads remain unchanged. GEN #734 has
advanced to `a3b9ea9606900e3faed989ab0f1c33400cad3b95`; its delta changes CI and
evidence handling only. The complete native/Godot delta is empty, and the five
inspected Workbench/persistent-worker interfaces still match their prior blobs.
This refresh does not incorporate or qualify the concurrent programme's runtime.

## Thread and interface map

| Module | Authoritative owner | Public role |
|---|---|---|
| `object_shard_native_worker.gd` | One native Thread | Constructs/calls/disposes one `CyberObjectShardLab`; admits bounded copied data/control envelopes and returns immutable value receipts. No RIDs or scene resources cross this boundary. |
| `object_shard_worker_host.gd` | Main thread | Named actions, one outstanding host operation, real terrain/body installation, applied receipt validation, lifecycle and coherent publication. All public mutation/poll/control methods reject foreign threads. |
| `object_shard_physics_bridge.gd` | Main thread | Existing Rapier server/space, shapes, mass and poses. Incremental begin/advance/ack methods share the same code as synchronous `step_motion`. |
| `object_shard_worker_rehearsal.gd` | Main thread | Opt-in scene, pointer intents, buttons, last-applied texture and pose, diagnostics and report export. No production control bindings. |
| Native coordinator | Exclusive native owner | World/shard inventory, discovery, transaction sequencing, chemistry, masks, exposure and exact geometry/publication revisions. |

A transport envelope binds `transport_generation`, monotonic `sequence`, immutable `operation`, requested native `session` and copied parameters. Replies retain those fields plus the actual result, owner-thread identity and immutable native snapshot. Exact native acknowledgements still carry session/shard/generation/body generation/geometry/pose and transaction identities. The transport sequence is a delivery fence; it never replaces native material authority.

Data queues and replies each hold at most 32 entries; control queues/replies each hold 8 independently. Request copies admit only bounded scalar/string/vector/packed values, depth 8, 1024 nodes and 64 KiB logical payload. A dedicated stop flag and terminal receipt remain usable when material queues are full. No mutex is held while native code runs, waiting for a frame, installing shapes or joining a live worker. Main polls without joining or calling native directly. The optional bounded receipt pump yields briefly while the exclusive worker runs.

## Executed ordering

Each requested semantic interval executes native `step` exactly once. Discovery may prepare a complete component. Main reserves a real disabled body and shapes, then sends the exact reservation acknowledgement. Native commit leaves inventory in `CommittedInactive`. Main installs touched static terrain contents and returns actual installed digests; native applies the occupancy mask. Only then does main activate the body and native acknowledge `BodyActivated`.

Native geometry changes require main installation and the corresponding native geometry receipt before physical motion. One Rapier interval is divided into the same bounded real substeps as 001R. `advance_motion_segment` performs exactly one solver piece, publishes sampled poses and enters `AwaitingNative`. Main submits those poses to worker-owned `accept_motion`; only an exact applied receipt with unchanged semantic tick and full owner/pose inventory permits another solver piece. Maximum 16 segments and the original motion guards remain intact. Delayed replies leave both the UI and cancellation/reset controls live, without stepping physics again.

The bridge requires an explicit completed native tick and refuses duplicate/backward ticks or reused native sessions. The synchronous wrapper and asynchronous API share this state machine. A retained-action control matched all 3,599 before/after pose rows and accounting against the unchanged final001R bridge on the same pinned native runtime; extraction did not invent a second dynamics implementation.

A preparation cancellation retains World inventory and removes only uncommitted reservations. It then finishes the physical interval belonging to the native tick that already ran. An actual negative reproduced the old skipped interval (native2→3 while physics4→4); the maintained adverse case covers the repair. Reset retires pending transport sequences, requests explicit native whole-session disposal and reinitializes main RIDs only after the new session receipt. A late receipt during Closing/Closed is nonmutating; duplicate worker stop preserves its original terminal result. Stop refusal leaves the native owner/thread retained with a visible `ShutdownHeld` reason.

## Publication, capture and resource evidence

`publication` changes only after real geometry/terrain synchronization and completed applied motion. The scene passes no live-RID pose override to the material view. During a delayed acknowledgement or reset request, the previous coherent publication remains visible until the actual next session/revision is admitted.

Prospective JSONL uses the existing bounded capture carrier with a specific `standalone-exclusive-worker-rehearsal` host tag. `replay_object_shard_worker_trace.gd` reissues named edits/ignition and completed semantic ticks on that host. It rejects a wrong host and an incomplete asynchronous barrier. Receipt-arrival timing, OS scheduling, cross-platform pose bit identity and old owner JSON reconstruction are not claimed. The synchronous replayer refuses this host family. The recovered staging trace exercised 44 actions and 2 completed ticks; this preliminary result is separate from current expanded continuous-play qualification.

Resource tests deliberately filled 32 snapshot replies and then proved independent control progress, complete drain and shutdown. On the exploratory Linux pinned514 runtime, 192×128 produced a maximum 157,500-byte logical snapshot and 5,057,408 retained reply-value bytes; 512×512 produced 1,359,172 and 43,510,912respectively. Registered empty-canvas snapshot limit is 2 MiB. These are copied value payloads, not total allocator residency; native accounted bytes were 5,756,592 and 32,362,400. Godot process-static highwater was separately recorded. The intentionally saturated 512 canvas is a capacity stress case, not the default 192×128 owner scene or a claim of steady-state frame performance.

The resource suite also triggers the real native promotion-pause deadline by withholding acknowledgements, observes actual quarantine and verifies exclusive-owner reset/shutdown. Current-session host peaks include injected waits and reset separately; worker transport maxima are explicitly lifetime-scoped. Final exact-source hosted receipts supersede exploratory staging labels; no reused DLL is described as a rebuild.

## Ready next implementation step

1. Reconcile onto the owner's accepted PUBPRES successor without importing its experimental branches. Preserve the known immutable GCR contract and its existing actor/equipment clients.
2. Add a narrow native integration seam that gives the coordinator access to the **same existing Workbench World under its exclusive owner**, with explicit solver/capability admission. Do not construct another World or convert Wave/Pressure/Inertial sidecars into unsupported shard payloads.
3. Add a revisioned ObjectShard adapter beside GCR, with stable owner/cell/generation identity and independent exact-shape capacity. Reuse the tested asynchronous promotion and segment acknowledgement order, and the accepted host's callback permits.
4. Route established named authoring/player/equipment operations to that one native mutation pathway. Capture owner and generation when input is accepted; revalidate before mutation. Do not hardcode player keys or modify other missions' controls.
5. Publish material+pose+geometry together through the accepted snapshot/GPU publication route. Bind installed static terrain receipts to exact touched content. Extend the existing Workbench tests with mutable-roster and stale-publication negative cases; never weaken the GCR tests to accept ObjectShards.
6. Refuse unsupported save/area eviction while a shard remains owned until a GEN-006-compatible residency contract exists. Retain inventory on failure; no blind World restoration after motion. Treat whole-session reset as explicit disposal only.
7. Qualify exact combined source on Linux and Windows, retain all native/material/Water and host gates, perform the strict four-path native-runtime publication procedure only under future owner approval, and request physical Windows 11/NVIDIA evaluation before production acceptance.

The owner can already run, cut, observe, export and compare through the standalone executable. These source changes are Draft/HOLD and do not authorize production mergedown, release or physical acceptance.

## Continuous input and exact target identity

The current candidate preserves input-time session, transport generation, owner,
local cell, cell incarnation, material tuple and geometry/material/pose revisions.
A moving cut is refused as TargetChanged when any authoritative identity differs
at dispatch. A new hit-test cannot retarget the old command. World-location edits
retain their session and must still address World-owned material. Native owns the
final debit and exact geometry preflight. The UI retains bounded pending input;
capacity pressure and stale targets have explicit outcomes.

The host services at most four queued actions before a requested semantic tick.
Each admitted action receives a result or explicit retirement record. Queued actions retired by reset/stop never execute; a dispatched action with a lost receipt is marked outcome unknown and its old trace loses complete-replay status. Fixture preparation can apply up
to 32 ordered ordinary World edits per worker call with one copied snapshot and
per-edit results, only while paused with no shard owners. The eleven qualified
presets retain their definitions; 256x160 and 320x192 scenes report separate
memory costs. The default six-MiB native bound does not cover larger scenes.

Optional deferred worker notifications contain no payload or physics authority.
Main consumes copied receipts with a budget of sixteen callbacks and two
milliseconds of accumulated callback work per ordinary poll. The budget stops
before another callback; an individual native-receipt handler is not preempted.
Explicit receipt holds apply immediately. All scene and RID operations remain on
main, and notification arrival cannot mint a native tick or Rapier interval.

Source: [worker](../../godot/scripts/object_shard_native_worker.gd),
[host](../../godot/scripts/object_shard_worker_host.gd),
[bridge](../../godot/scripts/object_shard_physics_bridge.gd),
[interactive scene](../../godot/scripts/object_shard_worker_rehearsal.gd).
The [feature launcher](../../godot/scripts/feature_launcher.gd) provides one
explicit experimental entry and the --objectshard-m3 argument. It opens a
separate scene with one real World; it does not attach another World to Workbench.

## Measurement boundaries

Scene pointer timestamps survive the bounded UI queue and host admission.
Input-to-dispatch, input-to-result, input-to-publication and input-to-presented
therefore include UI waiting for scene-originated actions. Separate
host-admission-to-result/publication/presented observations expose that boundary;
programmatic callers without a pointer timestamp are labelled host_admission.
These enclosing latency observations must not be added. Worker queue, native
execution, snapshot construction, value accounting and delivery durations are
disjoint stages. Terrain/geometry installation and real Rapier segment costs are
separately sampled. The host retains the latest 2048 samples per stage with
p50/p95/p99, cumulative count and whole-session maximum. The UI has its own
bounded callback/upload observations. A rendered frame_post_draw receipt records
presentation completion; headless execution cannot report visible timing and
neither observation establishes monitor scanout or NVIDIA gameplay performance.

Fresh final-source platform and independent review evidence supersedes the
recovered staging descriptions above. See the dated recovery/acceptance ledger
for actual passed, failed and pending gates.

## Recovery barriers and input admission

A failed host stays Held until explicit native whole-session reset or stop.
Cancellation, promotion resume, idle scheduling and transport continuations cannot
resume chemistry, Rapier or queued edits while failed. A 15-second missing-receipt
deadline retains actual owners and exposes the pending operation. Expiry does not
authorize replay of an uncertain mutation.

A reset whose successful receipt was lost can leave worker and host sessions
different. Recovery reads the worker session solely to request another explicit
disposal. It cannot authorize edits, adopt an unseen snapshot or activate old RIDs.
The worker atomically refuses a second reset while one is queued or executing,
including when full control replies prevent its start. Only a fresh successful
reset receipt with a strictly newer native session reinitializes main physics.

Bounded terminal input records survive reset in `retired_action_results` and
incident exports. They distinguish exact queued cancellation from an in-flight
outcome that cannot be reconstructed. The old trace retains retirement events
before the next session starts its own trace; uncertain mutation traces cannot
claim a successful complete replay.

An in-place `Host.reset` intentionally retains native allocation generations and
the bridge pose serial. Its new trace declares `standalone_replay: false` and
`inherited-native-registry`; the standalone replayer refuses it before constructing
a new owner. Reproducing that history needs the preceding sessions, which this
driver does not reconstruct. The interactive scene's Reset/scenario path instead
disposes and recreates the worker/host. Those fresh-registry traces can replay even
when their process-global native session number is not one: only the header's
current session is mapped to the new session, preserving every body, generation,
pose, cell and material witness. Stale targets must still be refused.

Continuous pointer admission uses the publication actually presented to the view.
The scene offers input an admission opportunity before scheduling the next interval
from that displayed tick. This makes fresh moving cuts usable while preserving
exact pose/material/geometry refusal for stale commands and the native debit fence.

## Optional receipt pump and measured limits

The experimental scene exposes a 0 or 4000-microsecond receipt-loop budget.
Deferred notifications remain off by default. The loop consumes already requested
work, yields while the worker runs, and stops before another callback once its
budget or 16-callback bound is reached. An already-started callback can exceed the
budget; elapsed time is recorded. It creates no extra semantic or physical time
and respects explicit receipt holds.

One local same-source 240-publication comparison preserved every publication
digest, final accounting, 954 real physics segments and 60 in-flight inputs. The
0/4000 pair took 29.572/18.316 seconds; input-to-publication median was
116.707/66.641 ms and p99 was 179.039/116.735 ms. Candidate pump maximum was
10.297 ms: 4 ms is a soft loop budget, not a hard realtime guarantee. A separate
notification-only pair showed no benefit and is retained. These local results
are not a 60 FPS or target NVIDIA claim. Final platform profiles and rendered
input timings remain separate evidence.

## Controlled navigation and final delivery

The global feature-navigation dispatcher recognizes the optional
`request_feature_launcher_navigation()` hook. The M3 scene retains its live
owner while main polls shutdown; `feature_launcher_navigation_ready()` becomes
true only after native disposal, stopped-thread join and main-thread RID release
reach `Closed`. `complete_feature_launcher_navigation(expected_scene)` rejects
early or obsolete callers, and its deferred completion rechecks current scene
identity. Existing ordinary Workbench navigation keeps its previous ordering.
This does not provide universal cleanup for arbitrary external forced scene
replacement or freeing of a live owner.

F2 supersedes pending reset/scenario replacement. Repeated F2 is idempotent;
window close upgrades the destination to process exit. Quit priority survives
retry from ShutdownHeld, while an explicit Reset starts a new owner decision.
Input admission and both support/erosion shortcut controls refuse visibly while
closing, replacing or held. The prior `auto_accept_quit` policy is restored only
after disposal. The maintained regression executes eight real navigation cases,
135 parent assertions and an 18-assertion child that actually closes the process.

The [final qualification](../audits/2026-11-22-objectshard-m3-final-qualification.md)
binds Draft/HOLD #741 to runtime source
`e034f2294663e0485cfb9adcc8ada46a6e977cee`, tree
`246e7324ca618d98c43a0ed54fe19bc86a155877`. Fresh campaign 44999117090 passes
41 Linux source, 41 Windows source and 32 extracted-package cases, including the
navigation regression on each surface, plus complete native sanitizer/World
qualification. The repaired Windows ZIP is 93,168,827 bytes, SHA-256
`61678a8c8ae3ab8e3b05cbb624fe15b4b259710fd879aa209542583a78b74a0b`.
The old `68235b12` evaluator is a retained superseded candidate, not the delivery.

Final paired scheduling observations reach 17.1382 semantic ticks/s on hosted
Windows and 16.6068 on Linux with the 4 ms soft pump; these are slower than the
earlier candidate observations and do not establish a product-change cause.
The deliberate rendered input-burst maximum is 1.929452 seconds on Windows.
The final audit preserves the stage distributions, byte-identical core code,
baseline comparisons and measurement limits. Ordinary Workbench attachment,
production provenance and physical Windows 11/NVIDIA owner acceptance remain
unimplemented, unpassed and unrecorded respectively.


## Reviewed Fire consumer transition

The final ordinary documentation check exposed an inherited missing successor
in the material-catalogue guard for the finisher's two-line external Fire
opportunity condition. The [reviewed transition](../audits/2026-11-22-objectshard-external-fire-world-transition.md)
at `73018218092e79fbe935aa60890e33bd9f4859ac` appends the exact original
`c06550371` source bytes through the existing authenticated mechanism. Its
231-test catalogue workflow passes with the original lock and refusal logic
unchanged. This is a compatibility-tool completion; the native/Godot/package
source and Windows evaluator remain `e034f229`. The Draft workflow's production
provenance skip does not clear the six separately observed native-input errors.
Before a future #738 merge, carry this reviewed entry and committed audit onto
that earliest dependent head and retain the original source ancestry. The donor
branch remains untouched by this mission.

The final closeout refresh observes GEN #734 at
`41208bb1ec0f2d56a9a375983f5d5c7c5193b36a`. Its five-file delta from
`a3b9ea96` changes CI/evidence only; the complete native/Godot delta is empty,
and the same five inspected interfaces retain their hashes. Main, #740, #719,
#682 and the #738 donor remain at the recorded identities. This remains a
read-only compatibility assessment, not combined GEN/PUBPRES qualification.
