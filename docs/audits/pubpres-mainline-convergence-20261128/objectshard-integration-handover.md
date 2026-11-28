# PUBPRES → ObjectShard M4 integration handover

**Disposition: source review and read-only merge preview; combined execution is unqualified.**

The next ObjectShard integration should start from the completed PUBPRES candidate and preserve its one native World, actual Rapier completion and accepted presentation identities. This mission has not merged ObjectShard, changed its branch or introduced its unfinished features into the PUBPRES evaluator.

## Source and evidence custody

The live #754 refresh on 28 November 2026 identified qualified application **`ba6d8de45bd4d38717d92bdece7153bff115c0f0`**, tree **`33fa2aab1433fc1fece80cb38a413816cc845603`**. Its later evidence/documentation HEAD is **`7dc6d53b5e92157e5bfa2e0f52042bbcc2fc0390`**. The PR remains open Draft and explicitly holds physical owner acceptance and mainline admission. Its independent Windows evaluator is now delivered; this is no longer merely an in-progress package campaign. [Live implementation and delivered qualification](https://github.com/techrote/cybersand/pull/754).

The investigation froze the qualified application, rather than consuming a moving implementation branch. The PUBPRES review checkpoint is **`5758c637140fc3ea749c7511797f4087a3eef481`**, tree **`2b0af4b74a15910b6e14a367061f1d83fc240c0b`**. Both descend from accepted RAMCACHE merge **`9920e7a7369f24e2818313c007cc33616c1a6a83`**; PUBPRES also includes accepted main **`50e3bcb839211eac2abe1e065750cbcba4d36f8c`**, including Strata Theatre and complete portable Materials Lab source custody. Later PUBPRES publication/qualification identities are in the main mission ledger and must be refreshed before starting the next integration.

`git merge-tree --write-tree --name-only --messages` returned **1**, with **15 conflicted paths**. It produced only an object-database preview tree, `b083836498c9a23ce6a434f798c5b2a76ed933d3`; no checkout, branch or index was changed. That tree contains conflict markers and is not runnable. The exact command, sources, common ancestor and complete conflict list are in [objectshard-merge-preview.json](objectshard-merge-preview.json).

## Shared files and required reconciliation

| Boundary | Actual overlap and required treatment |
|---|---|
| `simulation_worker.gd` | Three conflicts inside `_worker_loop`: coupling preparation, post-native-tick work, and final publication. Combine ObjectShard's exact motion lease and pinned completed-interval packet with PUBPRES coupling-only responses. A completed M4 interval must receive exactly its one real native tick; an auxiliary coupling response must not claim that tick or retire its pending completion. |
| `main.gd` | Conflicts span `_ready`, `_exit_tree`, `_process`, `_physics_process`, `_complete_physics_callback`, snapshot consumption, material upload and terrain synchronization. ObjectShard interval admission must enter the existing Main/Rapier owner path. Maintain one physical completion authority; preserve PUBPRES camera, full two-slot material history and accepted-frame actor picking. |
| `shared_workbench.gd` | Conflicts include installation, authored saving, stroke cancellation, paint, input routing and process polling. Preserve Strata's retained layers and ordinary authoring while adding M4's visible-owner witnesses, swept brush continuation, cancellation and precise edit acknowledgement. Never resolve a gesture against a newer unpublished body pose. |
| `cyber_native_cell_world.cpp` | The reset conflict joins PUBPRES's missing-render-exchange preparation with `retire_shard_for_world_replacement()`. Allocate fallible replacement resources before the commit point; retire the old shard owner immediately before swapping the admitted World. Retain both protections rather than choosing one branch's complete reset implementation. |
| `material_palette.gdshader` | Two conflicts join PUBPRES/Strata's exact physical-pixel sample mapping with `CYBER_OBJECT_SHARD` capture-coordinate material finishing. Keep the terrain screen-to-cell calculation that agrees with picking. Apply the shard-specific material texture origin only in its conditional variant; test fractional zoom and the first/last fitted viewport pixel. |
| `feature_launcher.gd` | Preserve accepted-main feature admission and the separate persistent-area host. ObjectShard remains an explicit admitted route; a merge must not turn it on by default. |
| Native/Rapier adapters and World | `physical_actor_session.gd`, `rapier_physics_bridge.gd`, `workbench_physics_bridge.gd`, `cyber_native_cell_world.hpp`, `world.hpp` and `world.cpp` merge textually but require semantic review. A clean text merge does not prove interval, geometry, COM/inertia, residency or lifetime compatibility. |
| Runtime custody and compatibility | Both platform binaries and both native manifests conflict. Build new combined-source runtimes and publish through a new guarded exact-source request. Neither parent's binary represents the combined source. `tools/material_catalogue/compatibility.py` needs an audited combined World/shader transition; its restrictions must not be bypassed to obtain a passing Lab comparison. |
| Evidence and attributes | `.gitattributes`, development handover, retrieval index and roadmap also conflict. Preserve both evidence populations, generated-source rules and the correct current disposition. These files do not establish executable compatibility. |

## Contracts that must remain authoritative

The M4 worker declares `_m4_owner_busy`, `_m4_motion_lease`, `_m4_interval_tick_due` and an immutable `_m4_interval_sample`. `object_shard_acquire_motion` refuses conflicting ownership and an already completed interval awaiting its native tick. `object_shard_submit_owner_control` validates the exact lease and actor sample. These are fences around the same native World; they are not an alternative simulation scheduler. [Frozen worker source](https://github.com/techrote/cybersand/blob/ba6d8de45bd4d38717d92bdece7153bff115c0f0/godot/scripts/simulation_worker.gd).

PUBPRES may publish a fresh actor-coupling response without advancing semantic material time. The merge must distinguish that response from M4's required post-physical native turn. In particular, choosing PUBPRES's final `_publish_coupling_completion` block wholesale would lose M4's inventory-service and owner-busy cleanup; choosing M4's block wholesale would discard PUBPRES's bounded coupling response path. Implement one explicit end-of-owner-turn sequence that publishes the correct packet, services legitimate structural requests, clears only the completed lease's pending interval and releases owner-busy state under its mutex. A live edit must have a bounded opportunity between legitimate motion intervals.

M4 presentation independently requires actual Main geometry installation, acknowledged native pose echoes, no active partial interval, and matching native World generation/revision before `can_upload_world` permits the ordinary material publication. `present_uploaded_world` then establishes the same-owner shard publication before drawing. The combined contract must retain this acknowledgement together with PUBPRES material content/history identities; simply showing the latest shard bridge transform would be stale or ahead of the accepted terrain. [Frozen presentation/runtime source](https://github.com/techrote/cybersand/blob/ba6d8de45bd4d38717d92bdece7153bff115c0f0/godot/scripts/object_shard_m4_runtime.gd).

`object_shard_m4_workbench_port.gd` validates worker/native identity, World generation, session, owner epoch, shard session, incarnation and transport generation. `latest_edit_presented` requires a subsequent same-owner transaction publication and the caller's actual physics readiness. Its `visible_error` binds the already uploaded material World/revision/render serial. Keep Applied native work distinct from coherent presented completion. Scene retirement can censor a previously Applied operation; cancellation is not proof that no native mutation occurred. [Frozen Workbench port](https://github.com/techrote/cybersand/blob/ba6d8de45bd4d38717d92bdece7153bff115c0f0/godot/scripts/object_shard_m4_workbench_port.gd).

The PUBPRES retained Water fallback applies to a previously submitted ordinary actor endpoint. Its current-owner/body/geometry/World checks and original hold deadline do not authorize retaining changed ObjectShard geometry. A structural geometry revision must receive its own installed and acknowledged publication. Source review found no need to remove these PUBPRES fences for M4.

RAMCACHE restoration changes native World ownership/generation. Retire M4 transport, visible witnesses, pending input and presentation state before admitting the restored owner. Do not assume detached inventory is durably represented by the ordinary persistent-area format: preserve M4's existing `can_preserve_world` refusal until actual combined save/restore qualification establishes the supported policy.

## Reusable qualification and remaining uncertainty

The PUBPRES convergence tooling provides exact native/dependency build receipts, unchanged-input reuse checks, three-source matched comparisons, bounded spawn timing, original five-minute owner workloads and complete Windows package extraction with portable authoring tools. `tools/pubpres_mainline/qualification.py` invokes the accepted RAMCACHE/Strata/shared/Lab semantic readers at the current application source; it does not import old application results. `extracted.py` independently executes the shipped launcher, normal persistent shutdown/reopen, extracted feature cases, native Lab compilation and actual DLL loading.

M4 retains its own native transactions, lifetime/sanitizer/budget witnesses, native-renderer camera/brush/preview cases and package-only qualification under `tools/objectshard/`. Reuse those original assertions and adversarial fixtures at the combined source. The PR's successful original counts apply to its frozen source, not automatically to this new combination.

The live #754 description retains unresolved moving-tower performance decreases and a censored edit presentation sample. Preserve both in the combined comparison population. Likewise, PUBPRES's hosted render callbacks and physical completion measurements do not establish physical TITAN RTX presentation. Neither a text merge nor this handover qualifies combined feature performance or physical owner acceptance.

## Recommended integration order

1. Freeze the final PUBPRES application and the owner-admitted M4 application; record their exact trees, accepted main and original native/publication receipts. Use an isolated integration branch without modifying either implementation branch.
2. Reconcile worker/Main interval ownership and the post-native completion path before editing UI/presentation. Add a focused production-path witness proving one completed Rapier interval, one required native turn, bounded edit admission and no false completion credits.
3. Reconcile native reset/retirement, structural mutation and geometry installation. Rebuild both native platforms from the combined complete input closure; retain ordinary World, Water, publication, lifetime and sanitizer gates.
4. Reconcile accepted-frame terrain/actor/shard composition, viewport mapping and actual mouse witness acquisition. Exercise fractional zoom, overlapping owners, material occlusion, changed sleeping geometry, Fire, Water, manual stepping and a missing/delayed native response.
5. Reconcile ordinary authoring, retained Strata layers and persistent-area admission. Exercise real edit/save/fresh reopen and scene replacement while an edit is queued or Applied; establish explicit detached-inventory persistence limits.
6. Run both original programme qualification populations and balanced comparisons on exact-source native runtimes. Do not waive failed arms, physical-gap objectives or unresolved M4 performance decreases.
7. Produce and independently execute a complete Windows evaluator with current guarded native provenance. Keep promotion and physical acceptance separate until explicitly authorized and satisfied.

M5 impact/repair/welding work remains outside this handover and outside PUBPRES convergence.

## Concurrent ObjectShard accepted-main integration update

A second live refresh at **10:45 UTC on 28 November 2026** found accepted main unchanged at `50e3bcb839211eac2abe1e065750cbcba4d36f8c`. PR #754 remained open Draft, but its active implementation had advanced to **`c4e10e3ca629c491f7340c6f383adcc347200fa5`**, tree **`e88fd1a1d89d10bf4482cb619174325390ced44d`**, on `integration/objectshard-m4-mainline-20261122`. Its two parents are the previously recorded `7dc6d53b5e92157e5bfa2e0f52042bbcc2fc0390` and that accepted-main commit. The PR description still records `ba6d8de45bd4d38717d92bdece7153bff115c0f0` as its qualified application; it does not establish resulting-source qualification of this new integration. [Exact separate integration commit](https://github.com/techrote/cybersand/commit/c4e10e3ca629c491f7340c6f383adcc347200fa5).

The commit message explicitly preserves ObjectShard opt-in ownership, introduces an explicit mutual-exclusion boundary with accepted Strata semantics, and excludes PUBPRES and M5. Treat those as the separate implementation's stated intent; this read-only inspection does not independently qualify its combined behavior.

A second frozen preview joins that exact source with PUBPRES checkpoint `7ec95a34bd6229286e158b7500093b7c5140882a`. It returns 1 with **11 conflicted paths** and conflict-marked preview tree `45058529364ec14ecd94d5d85f484204d9e3f911`. The common ancestor is now the accepted-main commit. The previous three documentation conflicts and `feature_launcher.gd` conflict disappear textually; `.gitattributes`, both platform native pointers and manifests, `cyber_native_cell_world.cpp`, `main.gd`, `shared_workbench.gd`, `simulation_worker.gd`, `material_palette.gdshader` and material compatibility still require reconciliation. The original 15-path preview is retained as historical evidence. [Full refreshed command, output and source identities](objectshard-current-main-preview.json).

The contract-level handover above remains applicable. The subsequent joint integration must explicitly reconcile the separate Strata/ObjectShard admission boundary with PUBPRES's accepted Strata and coherent publication paths; a text merge must not silently activate unsupported combined modes. Refresh both final application identities before that mission. This update neither merges ObjectShard into PUBPRES nor modifies its active branch, and it does not justify restarting PUBPRES qualification against unrelated concurrent work.

## Remotely consumable PUBPRES candidate

The current source to consume for this handover is the exact remote PUBPRES candidate **`0670733eb0a418c8580458a9c5dd9aff24f342c6`**, tree **`3df9cc4f11b0ef0a3009830a78720bf41bb9f1a9`**. [Candidate source](https://github.com/techrote/cybersand/tree/0670733eb0a418c8580458a9c5dd9aff24f342c6). Its Q2 campaign is run [46136935975](https://github.com/techrote/cybersand/actions/runs/46136935975), attempt 1. This candidate is not accepted: both shared-feature arms subsequently failed in the Ambient default-off integration case, and diagnosis is in progress. Later repaired application, guarded publication and final delivery identities must be obtained from the definitive mission ledger before actual joint implementation.

Earlier PUBPRES SHAs `5758c637140fc3ea749c7511797f4087a3eef481` and `7ec95a34bd6229286e158b7500093b7c5140882a` identify local review commits. The Git Data publication process preserves reviewed integrated content through separately identified remote commits; do not assume those local review commit objects are fetchable from GitHub or are ancestors of the remote candidate. Their original preview receipts remain local investigation records and are not relabeled as remote application qualification.

Before the executor became unavailable, a fresh read-only preview used the remotely available PUBPRES commit and the separately frozen ObjectShard integration `c4e10e3ca629c491f7340c6f383adcc347200fa5`. It again had **11 conflicted paths** against common ancestor `50e3bcb839211eac2abe1e065750cbcba4d36f8c`. Its command, observed conflict list and conflict-marked preview tree `15c385b675235af0bef65f748a03a64ae6414845` are recovered in [objectshard-remote-candidate-preview.json](objectshard-remote-candidate-preview.json). The original local stdout file was not recovered after the executor failure; this metadata record does not claim to reproduce its complete bytes. The earlier frozen previews remain unchanged. No application branch, index or production source was changed; no combined application was built or executed.

For input adaptation, preserve the candidate's repaired continuous accepted-frame Select coordinates: use the submitted camera mapping and existing owner/material clip checks, while retaining material-cell bounds for material authoring. Do not reinstate integer truncation for actor geometry or substitute a newer unpublished camera. The retained ordinary Water endpoint helper still requires its original physical owner, World and geometry and its original 100 ms deadline; contact-clipped retained endpoints need a distinct proof before support is extended. No new detached-body transaction or physical authority was introduced.

## Native completion versus material consumers after reconciliation

The Ambient integration repair additionally makes the early packet contract
explicit: a material-free native/physical completion carries genuine
`physics_world_generation`, native tick/revision, backend and failure metadata,
while `render_world_generation` is `-1` and the established absent
`render_snapshot_serial` is `0`.
Combined publication continues to carry its genuine material identity.

ObjectShard integration must preserve that distinction when adapting structural
edit acknowledgements and detached-material presentation. An early physical
completion may advance native freshness or retire an old World; it cannot
certify a render upload, material history, material cache or presented detached
geometry. A later same-World material envelope can carry a newer genuine
material publication even after a newer physical envelope has been observed.
Its older native metadata must not roll the consumer's current native
freshness backward. Material baseline/patch validation and owner refusal remain
separate.

The Ambient consumer is an example of this reconciliation, not a new physical
transaction owner. See
[the Ambient publication audit](ambient-publication-reconciliation.md).
The 067 merge preview above predates this narrow subsequent repair; resulting
source runtime qualification and any later ObjectShard merge must use the final
mission source identity, not inherit acceptance from this preview.

## Later live ObjectShard branch movement — 28 November, 11:45 UTC

The integration owner refreshed PR #754 and observed live HEAD
`8064c73270dee2ce1a0d53316aae334136335483`, still open and Draft against the
accepted main baseline `50e3bcb839211eac2abe1e065750cbcba4d36f8c`.
The read-only comparison from frozen
`c4e10e3ca629c491f7340c6f383adcc347200fa5` showed three commits ahead and
zero behind, changing exactly these six paths:

- `docs/audits/objectshard-m4-live-edit-20261128/integration-handover.md`
- `docs/audits/objectshard-m4-reliability-20261128/m5-handover.md`
- `godot/.godot/global_script_class_cache.cfg`
- `godot/tests/test_object_shard_m4_capacity_recovery.gd`
- `tools/ci/run_godot_regressions.py`
- `tools/objectshard/qualify_workbench.py`

That inspected delta contains no shared production runtime changes. It does
not extend the frozen c4e merge preview into a claim of current-HEAD runtime
compatibility. No part of this later development, including the M5 handover,
was absorbed into PUBPRES. The final M4 integration mission must refresh the
then-current **qualified** ObjectShard source and its physical acceptance
before using the shared-contract guidance above. Both original branches and
all frozen preview evidence remain intact; no combined source was built or
executed by this mission.

The final PUBPRES application and native publication identities are supplied
by the mission delivery ledger and PR #767. The preview source `0670733`
is an explicitly narrower historical source-review scope.
