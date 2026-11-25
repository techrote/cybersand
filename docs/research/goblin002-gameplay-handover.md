---
title: GIP-014 goblin 002 gameplay and oracle handover
status: Planned
document-kind: research
scope: Branch-scoped developer-only gameplay discovery; Draft/HOLD
canonical-for: [goblin002-gameplay-handover]
last-reviewed: 2026-11-25
related-documents: [gip014-goblin-gameplay-qa.md, ../systems/paint-editor-bounded-shapes.md, ../systems/workbench-actor-composition.md]
---

# Gameplay and independent oracle handover — Draft/HOLD

## Foundation and authority

This successor preserves predecessor `d4484bd5b488cb419bfaa94f1e69be8128734405`
(including the ancestry of qualified feature source `66ee554a`). The original
26 operations and five fixture recipes remain; their previous evidence keeps its
original source/platform identities. This lane changes only the opt-in goblin
adapter, its helpers, authored fixture catalogue, assertions and tests.
Production Workbench/native sources remain untouched.

The local execution host was lost during intake while the shared workspace disk
was full. No gameplay execution had occurred. Source work continued through
GitHub read-only retrieval and unreferenced Git blob custody until the host was
recreated. Source-only blobs are not qualification evidence. The restored exact
Godot 4.7 runtime passes check-only parsing for all six gameplay modules; native
integration results must be added below after actual execution.

## Real gameplay additions

The declared vocabulary has 55 IDs: the predecessor's 26 plus 29 genuinely
separate ordinary operations. No material/direction aliases inflate this count.

| Group | New operations | Ordinary authority |
| --- | --- | --- |
| Editor | select_tool, brush_radius, stroke, live_stroke, preview_begin, preview_cancel, interrupt_stroke | Actual tool/radius controls, app-local mouse gestures and editor Cancel |
| Navigation | camera_pan, camera_zoom, camera_focus, camera_mode | Workbench camera functions and actual picker |
| Actor lifecycle | actor_remove, actor_move, actor_save_spawn, actor_capture_spawn, actor_replace | Existing authoring methods, native replacement acknowledgement and physical epoch |
| Actor controllers/equipment | actor_release, actor_hand_back, actor_control, actor_equipment, actor_actuate, actor_trigger | Existing controller handoff/equipment APIs and app-local input samples |
| Configuration | response_mode, actor_settings | Ordinary response picker and bounded editable actor fields |
| World lifecycle | restore_start, replace_fixture | Existing restore/apply and committed disposable fixtures |
| Material sources | source_place, source_burst, source_stream | Ordinary powder-source controls and actual immutable native snapshot receipts |

The palette expands to the ordinary bounded IDs
`0,2,3,7,8,9,12,13,14,16,19,23,25,26,27,28,29,58`.
Actor models are bounded to Kestrel, passive barrel, runner, crawler, monowheel and
stuntbuggy. Live capacity remains eight; monotonic authored instance IDs are
bounded to 64 before an explicit fixture replacement. Offered actions inspect the
actual current actor, controller, equipment, editor, camera and source state.
Unsupported optional AMBIENT, ObjectShard, Strata, Materials Lab, Gentek and Art
integrations stay disabled behind a versioned data-only negotiation seam.

The ordinary editor already supports live Brush/Eraser through `world_input` and
`bench.paint`. The successor's `live_stroke` therefore exercises that actual
route. It records authored endpoint stamps and observed native progression. It
does not invent an atomic before/after material plane while asynchronous physics
runs. Paused `stroke` uses actual editor planning and source-matched native
before/after captures, with an independently computed thick-line mask.

`interrupt_stroke` starts a bounded ordinary Rectangle planner and presses the
ordinary Cancel path before its next main-thread consumption. It records whether
an actual planner was pending, its terminal state and actual capture/receipt.
The cancellation action completing is distinct from a paint edit completing.

## Observable state

The adapter adds actual World size, response/fire configuration, current camera
mode, ordinary preview state, authored controller/options and catalogue-declared
capabilities for each actually observed actor. Source observations copy the
immutable published `workbench_source` receipt with its snapshot tick.

A material probe is a retained actual native capture histogram. Its generation,
revision, tick and `current` flag are explicit. A stale capture is not a current
World composition claim. Palette selection, declared action IDs and advertised
capabilities do not themselves establish gameplay coverage.

## Authored scenarios

Five original recipe data sets remain unchanged. Five additional recipes cover
history/translated edits, boundary navigation/replacement, separate material
pockets, a mixed actor/material yard and a sealed conservation cell. All use the
normal 512×512 Setup-v2 authoring contract and the mounted application's actual
liquid policy. Pressure-sensitive geometry does not assume a universal water law.

The closed conservation fixture contains exactly 64 Sand cells and a 368-cell
hard enclosure in a 48×48 region. The applicable conservation experiment has no
actors, emitters, open edges or reactive partners. Alchemy and other mixed
fixtures deliberately have no blanket cell-count conservation oracle.

## Independent expectations and experiments

`goblin_gameplay_oracles.gd` derives expected results from preceding observations,
action inputs and ordinary contracts. It checks native nonmutation for paused
control-only operations; actual camera bounds; source publication; actor
retirement/replacement and reset-spawn identities; controller pose retention;
actual input samples and release; new native/physical owner identities; and
powder-source bounded accounting. The isolated burst refuses an active stream so
its exact 96-cell work precondition cannot be silently violated.

`test_expanded.gd` exercises all 29 new operations through the actual ordinary
Workbench. `test_metamorphic.gd` tests translated paused outlines, native
Undo/Redo preimage/postimage restoration, rejected-action nonmutation,
authored tick-zero Save/Reopen and sealed Sand conservation with actual movement.
These are positive observer qualification and regression controls, not discovered
production defects. Neither a surprising legal material response nor a controller
input acknowledgement is reported as a discovered bug or successful route.

## Authoritative product contracts

The expectations below refer to unchanged production source. Goblin does not
silently modify the engine, another programme, or an owner save to satisfy them.

| Contract | Authoritative source and scope |
| --- | --- |
| Native edit source fencing | [`simulation_worker.gd:paint_queue`, line 2218](../../godot/scripts/simulation_worker.gd#L2218) admits bounded work against generation, revision and tick. Material-plane assertions compare actual captured cells and actual edit receipts. |
| Shape planning and cancellation | [`workbench_paint_editor_executor.gd:step`, line 133](../../godot/scripts/workbench_paint_editor_executor.gd#L133), `_finish`, line 212, and the ordinary editor's Cancel path distinguish pending planning, native application and partial completion. An interrupted operation is never called a completed edit. |
| Spawn capture and tuning precision | [`shared_workbench.gd`, line 264](../../godot/scripts/shared_workbench.gd#L264) uses 0.01-cell X/Y fields; `capture_spawn`, line 1112, passes them through `entered_position`/Vector2 before save. Line 294 defines integer budget steps and 0.01 mass/inertia steps. The oracle applies that quantization; it does not mistake legal UI rounding for a defect. |
| RFT configuration | [`workbench_setup.gd`, line 520](../../godot/scripts/workbench_setup.gd#L520) requires budget 20 on every body under RFT. Legal menus validate the actual pending ordinary form. An explicit budget 15/RFT request is an expected refusal. |
| Actor lifecycle and capacity | [`shared_workbench.gd:_change_actor`, line 1045](../../godot/scripts/shared_workbench.gd#L1045), `place`, line 1064, `remove_selected`, line 1092, and `restore_start`, line 1135, own ordinary transactions. [`workbench_actor_catalog.gd:capacity_error`, line 142](../../godot/scripts/workbench_actor_catalog.gd#L142) distinguishes eight logical slots, up to eight parts per actor and 64 proxies. Goblin separately caps monotonic actor IDs at 64 until explicit fixture replacement. |
| Physical adoption and empty retirement | [`main.gd:_adopt_prepared_physical_candidate`, line 3505](../../godot/scripts/main.gd#L3505) installs a new physical epoch for nonempty actor graphs. `_close_physical_actors`, line 3591, clears the session and bodies while retaining the historical epoch counter. Empty Worlds therefore require absence, not a fabricated new actor graph. |
| Native construction count | [`cyber_prepared_liquid_world.hpp`, line 1017](../../godot/native_extension/cyber_prepared_liquid_world.hpp#L1017) counts initial native proxy tuples. [`workbench_physics_bridge.gd:pack_sample`, line 119](../../godot/scripts/workbench_physics_bridge.gd#L119) packs each collision rectangle. The oracle checks this against catalogue-declared proxies and the actual adopted bridge count, in addition to canonical-byte hashing/source generation. |
| Controller handoff | [`shared_workbench.gd:set_actor_control`, line 472](../../godot/scripts/shared_workbench.gd#L472), `hand_back_pilot`, line 457, and [`physical_actor_session.gd:set_workbench_control`, line 347](../../godot/scripts/physical_actor_session.gd#L347) preserve current pose and live equipment during source switching. `scripted` maps to the actual `demo` producer. |
| Actual actuator delivery | [`main.gd:_publish_workbench_keyboard`, line 4188](../../godot/scripts/main.gd#L4188) maps ordinary app-local keys to actor commands. [`physical_actor_session.gd:workbench_control`, line 328](../../godot/scripts/physical_actor_session.gd#L328) exposes actual owner generation, epoch, accepted sequence and lease. New inputs must advance native/physical samples and return to neutral. Model profiles gate offered actuator ports. |
| Finite canvas boundary | [`simulation_worker.gd`, line 2707](../../godot/scripts/simulation_worker.gd#L2707) publishes a specific finite-edge refusal and pauses the owner; [`main.gd:consume_worker_snapshot`, line 3112](../../godot/scripts/main.gd#L3112) applies that pause to the ordinary Workbench. A partial tick interval may end on that exact healthy, paused, current-generation publication. Other body-sample refusals are unresolved, and native failures are never downgraded. |
| Equipment identity and resource limits | [`physical_usable_equipment.gd:accept_receipt`, line 400](../../godot/scripts/physical_usable_equipment.gd#L400) requires matching actor/controller/equipment identities, finite charge 0..100 and cooldown 0..60. Newly observed receipts are checked independently against copied actor/equipment observations. A key sample alone is not reported as a material effect. |
| Powder source acknowledgement and work | [`workbench_powder_source.gd:command`, line 29](../../godot/scripts/workbench_powder_source.gd#L29) configures origin/material, clears stream/burst and resets stream ticks while retaining lifetime inserted/blocked counters. Constants at lines 6–8 bound burst 96 cells and stream 4 cells/tick for at most 600 ticks. `receipt`, line 80, partitions attempted=inserted+blocked. [`simulation_worker.gd:_consume_workbench_emissions`, line 1414](../../godot/scripts/simulation_worker.gd#L1414) drains the bounded queue under its mutex. |
| Authored persistence | [`shared_workbench.gd:save_setup`, line 1217](../../godot/scripts/shared_workbench.gd#L1217) and `load_setup`, line 1242, persist authored starts. Exact native material equality is asserted only for tick-zero, fully captured, actor-unprotected starts. Evolved ticks and actual native body-protection refusal are explicit inapplicability reasons. |
| Closed Sand conservation | [`native/include/cybersand/material.hpp`, line 235](../../native/include/cybersand/material.hpp#L235) identifies Sand's downward powder kernel. [`World::try_move`, line 3329](../../native/src/world.cpp#L3329) moves/swaps actual tuples; `fall_as_powder`, line 3717, moves down/down-diagonal, and Sand's dispatch at line 3785 invokes that rule. The sealed fixture contains only Sand, Empty and Reinforced Concrete 58, no reacting partners, sources or actors. This narrow precondition supports count conservation and downward movement; it says nothing about Water mass or mixed reactive materials. |

## Recorded local qualification and custody

Actual Linux runs used Godot `4.7.stable.official.5b4e0cb0f` (SHA256
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`),
the retained native library SHA256
`a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7`
with 105 matching source inputs, and Rapier SHA256
`566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`
with 4 matching source inputs. Native build ancestry is `c53fd6f9...`; this lane
has not rebuilt or changed production/native code.

The results below were observed before the host replacement described in the
recovery section. Their reported outcomes and hashes survive in tool records.
The original local artifact directories must not be assumed available after
that replacement. Fresh exact-source hosted results are required for delivery.

| Recorded run | Outcome and cost | Scientific interpretation |
| --- | --- | --- |
| `gameplay-expanded-001` | Native test completed in 16.595 s with failures; peak sampled process-tree RSS 583,454,720 bytes; no surviving owned processes. | Harness/oracle/test-precondition failures: logical actor versus proxy count, legal RFT refusal after budget 15, additive camera fields, empty-roster physical retirement. None is a production defect. |
| `gameplay-expanded-002` | PASS 824 checks; 46 attempted actions, 45 actually admitted/completed and one expected RFT refusal; all 29 new operation IDs completed. 20.488 s, peak RSS 583,782,400 bytes, no diagnostics or surviving owned processes. | Positive native integration evidence for its exact earlier source snapshot, not qualification of later source. |
| `gameplay-metamorphic-001` | Import process externally terminated by signal 9 at 4.137 s; sampled peak RSS 665,964,544 bytes; no gameplay began and no engine diagnostics or surviving owned processes. | Infrastructure/incomplete. Cause is unestablished. A separate laboratory startup later died without an importer, so the importer is not an established cause. |
| `gameplay-contracts-001` | Pure observer controls PASS 44 checks in 0.507 s; peak RSS 107,438,080 bytes. | Deliberately constructed oracle/harness tests; no native World or gameplay coverage. |
| `gameplay-contracts-002` | Pure observer controls PASS 58 checks in 0.403 s; peak RSS 111,230,976 bytes. | Adds consumed source-queue/new-publication controls and actual native/physical input progression checks. |
| `gameplay-contracts-003` | Pure observer controls PASS 82 checks in 0.403 s; peak RSS 112,209,920 bytes; no surviving process. | Adds exact finite-edge refusal recognition, stale identity rejection, native-failure precedence and retained partial-interval proof. |
| Exploration `policies-legacy-002` | Existing policy/fixture unit gate PASS 333/333 for 16 personalities and 10 fixtures after Alchemy was simplified to 18 authored rectangles. | Synthetic boundedness/determinism validation. The old 20-rectangle bound remains intact. |
| `gameplay-boundary-native-test-parse-001` | Exact Godot 4.7 check-only PASS in 2.725 s; peak RSS 258,400,256 bytes; no diagnostics or surviving process. | The new native boundary experiment parsed. This is not successful boundary execution. |

`gameplay-expanded-002` used base commit
`06893e99980d4faf7e9923613e59c17b19133e01` plus recorded dirty sources. Its executed
game-source snapshot digest was
`eacc8e0bd47c09673fe232c77a7d18085919a4a1c976886c386627192af1bc3f`;
test log SHA256 was
`7db5c229ddf4235db3fab09e97181fb471fad99682e5272dc108f6bc368658bd`.
That successful run observed a real Brick Stamper effect: accepted uses 0→1 and
a consumed current-owner receipt with changed_cells=5, charge=97.8 and cooldown
0.2. Following held samples observed three legal cooldown refusals. These are
positive ordinary gameplay observations, not exact asynchronous trajectory
replay or a novel production defect.

Later source review added quantized-coordinate controls, actuator/equipment
owner checks, source consumption/publication fences, repeated reconfiguration
controls, stale native identity controls, and finite-edge recognition. The
earlier native pass does not retroactively qualify those changes.

No novel production gameplay defect has been independently established by this
lane. No speculative production issue has been filed. Windows, graphical,
extracted-package, long-horizon and matched-campaign results remain integration
obligations. No physical NVIDIA acceptance is implied.

## Long mixed-episode review

- The legal menu uses actual current capabilities. A runner's unused flyer ports
  or non-rope reel channel are refused; declared names alone do not establish
  useful actuator support. Current camera/controller/equipment selections are
  omitted from ordinary offers.
- Settings preflight copies actual pending UI fields and requested response.
  Values left pending after an expected refusal are included in subsequent
  admission choices instead of silently substituting last-applied settings.
- Re-enabling an active source stream is a precondition refusal. The remaining
  600-tick stream budget can otherwise expire during observation legally.
- Source lifetime counters survive configure; stream ticks reset. Reconfiguration
  must observe a stopped source before an isolated burst can justify exactly
  96 attempted cells. An active stream is a burst precondition refusal.
- Native-array Undo/Redo equality requires uninterrupted matching generation,
  revision and tick. Evolved Save/Reopen compares authored state and records
  native equality as inapplicable; it does not promise a physical checkpoint.
- IDs may reach 64 while live capacity remains eight. Place and replace enforce
  the identity budget at execution. Fixture replacement starts a new domain.
- Final-actor removal retires the physical session. Reusing a historical epoch
  scalar in an empty World is legal; a later placement must adopt a new graph.
- Protected-body capture refusal is retained. Render pixels, authored palette
  selections and invented material counts do not replace native readback.
- Finite-edge recognition requires the exact current-source published contract.
  A different body-sample refusal, stale publication or native failure remains
  unresolved. The new native metamorphic case places an ordinary Kestrel at
  `(256,32)` in open-upper `history_edges` and attempts at most eight 16-tick up
  pulses. Its independent 20-second/256-native-tick/160-physical-tick guard calls
  Stop on exhaustion. Qualification requires the actual partial refusal, healthy
  paused owner, upward movement, ordinary Reset, and resumed ticks from a new
  owner. Every pulse/refusal/reset is retained; exhaustion is
  `coverage_unqualified`, not a defect or successful boundary test.

## Independent regression acceptance review

Explicit synthetic `unit_fixture` controls challenged the lead's regression
reader and interactive reducer. `regression-review-001` demonstrated that a
generic failed invariant could appear repaired when an admitted operation was
merely refused: an `actor_place` with a native-health failure was followed by the
same request and a healthy World, but no completed actor placement. This was a
regression-harness acceptance defect, not a production gameplay observation.
Other controls substituted one- and two-action sequences for a retained
four-action setup.

The lead bound the prescribed sequence, original admission/disposition and
required regression completion. Reproduction may stop at a literal failing
prefix; a successful regression must execute the entire retained sequence.
`regression-review-002` rejected all three challenges at reader SHA256
`104eff96c7207e207c719541fd9b7c0d17260570b15a3a751492f0d77635e96d`.
These controls involved no native game execution. Their local directories are
subject to the recovery custody limitation above.

The review also prompted terminal-state gates for reduction/export, recorded
reproduction pacing, and reduced-tape seed/pacing/execution-mode checks. Replay
bound offline reduction to the original admission/disposition and required the
whole requested sequence for a successful semantic callback. An incomplete
process remains raw evidence and cannot establish a reproducible target.

After source recovery, an independent synthetic counterexample found a second
acceptance defect in the reconstructed reader. The retained sequence was
`panel(open=true)`, `select_material(58)`, `panel(open=true)`. The first panel
completed successfully; the final panel was the admitted partial operation with
the failing invariant. A candidate with the same literal sequence, an earlier
passing panel and a refused final panel incorrectly passed regression checking.
Both artificial tapes passed the transcript reader: the erroneous acceptance
came from matching any duplicate action, rather than the failing occurrence.

Before correction, reader SHA256
`98ab276de9e910d92a2d807956b99513da854efc2d7fd11b34199e584d8cb81f`
returned `ok=true`. The lead derived the target occurrence from the chosen
retained tape and required the candidate to satisfy that aligned step. This
allows a reduced tape to establish its own shifted target index before export.
The unchanged counterexample then failed the exact regression acceptance
contract at reader SHA256
`79e32c26234efe1381915b270bcfed20c90648cfff8a3f60607dc57e38ab221f`.
This is a confirmed regression-reader defect and repair, with no production
gameplay claim. Durable immutable Git blobs retain the artificial challenge
(`f49f3778629082be67e5ca0e67460d88fa6040e2`), before result
(`c3c8720586556583ef6fc218ae88e1820627ed3b`) and after result
(`1e2f60a5ab47e82994bceaef78f0ea00cf1a51b6`).

## Source recovery after the final local checkpoint

The execution environment disappeared after local commit
`eaf193eaca9330a4e49ed9a5430047e0c5f82f57`, tree
`a33744521d8b4b14183f4757b58163cf5f52a59c`, before its source upload completed.
Recovery used published `be64fa7896a37672c3e5d0652517789e469b9061` and retained
literal tool patches. Immutable Git blobs recovered byte-for-byte against the
recorded local target are:

| File under `godot/goblin/` | Recovered original blob |
| --- | --- |
| `goblin_adapter.gd` | `76b7454aad8c9c91297e9d1782dfe43f2b3dd088` |
| `goblin_fixtures.gd` | `d02b2ad0e1faadff27c5ae79e2410cb35d24e2b7` |
| `goblin_gameplay_oracles.gd` | `69534a549e731d1457424c354ec46ef157c0ed28` |
| `tests/test_expanded.gd` | `ec1d2e09fb960565467c2ba5453d698d3e2ada45` |
| `tests/test_metamorphic.gd` | `9a0276f3bffab6967939dd4a38f0ec008577af69` |
| `tests/test_gameplay_contracts.gd` | `3b31dd1f1e3da0c32c99f9f12a1b9459acfca848` |

The gameplay actions reconstruction has blob
`5a260b4b189a0c274df43762b5b30cbcfab61bd1`, distinct from the recorded lost target
`09b44acc40a241765f311813a06e5bf7917dd056`. Its retained source blocks were reviewed
against the original capabilities, admission, pending-form, source and actor
contracts; an unresolved byte discrepancy remains and exact identity is not
claimed. This handover is a reconstructed, updated account, also not a
byte-identical recovery of its lost predecessor. The integrated replacement
requires fresh qualification under its own source identity.

The predecessor's separate retained evidence directory did survive. Read-only
recovery of all seven `long-final-1649f086-*` qualifications and available raw
tapes is recorded in [the predecessor recovery manifest](../../tools/gip014/predecessor-recovery.json).
Five processes completed; two retained unattributed SIGKILL exits. Six available
tapes contain 988 completed observed actions. The first 256-action Curiosity
attempt retains 220 complete rows plus an accepted pending brush at index 220;
its separate retry completed all 256. The interrupted Random attempt has no
retained tape. Exact qualifier hashes, raw transcript byte hashes, complete
summaries and process bounds remain distinct from successor evidence. The
recovery document is metadata, not a replacement for its original raw tapes.

## Independent hosted Linux raw gameplay audit

Specialist B read the complete retained expanded and metamorphic reports from
run `45536048675`, Linux artifact `14987252426`, at clean source
`89c91ba5342d485e787d39e64103fc6c91c5f92b`. This audit checked source identities,
process completion, actual action dispositions, native capture operation/source
identities and SHA256 recomputed from the raw little-endian int32 material arrays.
All 107 independent review checks passed. The review record is immutable Git
blob `0d2604fca7460fa426bbb8ce0640784a5483cc5e`; it is a read-only analysis of
retained native evidence, not another gameplay execution.

| Actual focused gate | Expanded ordinary actions | Metamorphic relationships |
| --- | --- | --- |
| Reported assertions | 1,028 passed | 464 passed |
| Retained attempted actions | 54 | 35 |
| Completed actions | 51 | 33 |
| Other outcomes | RFT budget refusal, unsupported actuator refusal and already-active stream refusal | One deliberate invalid-action control and one actual finite-edge partial refusal |
| Observed completed IDs | 38, including all 29 added IDs | 14 |
| Process elapsed | 17.926 seconds | 13.423 seconds |
| Raw report SHA256 | `74ac45b750c7f199e76077f0b7a34c88c2bcc3598387fd11592f75d7228b00a1` | `b1eac00b2febc45d7342db247a21ef408d706a937697ee118b7269a160e33ea4` |

Both translated 24×24 readback regions began with 576 empty cells and ended with
the same relative 60-cell outline. Undo independently restored the actual empty
preimage; Redo restored all 60 painted cells. Authored Save/Reopen preserved the
same 576-cell material plane at tick zero while adopting a new native generation.
The isolated 48×48 conservation region retained exactly 64 Sand cells and 368
hard-wall cells after 16 native ticks. Recomputed Sand vertical-position sums
changed from 736 to 1,730, proving actual movement rather than an unchanged
paused construction. All three stale generation/revision/tick diagnostic requests
were refused, and the subsequent native material plane was unchanged. The
ordinary finite-edge experiment preserved a current published refusal and
recovered through Reset.

These gates qualify supported operations and specific preconditioned
relationships. They do not establish every parameter combination, asynchronous
cross-platform trajectory equality, or a novel production gameplay defect. The
whole hosted Linux qualification also retained an unrelated long synthetic-tape
unit-fixture failure, subsequently repaired by Specialist C; these focused passes
do not erase that failed group.

## Confirmed post-edge capture harness defect and repair

The Linux focused artifact from run `45536048675`, source
`89c91ba5342d485e787d39e64103fc6c91c5f92b`, independently qualified the ordinary
finite-edge setup: 464 metamorphic checks passed; four Kestrel up pulses reached
the edge in 981 ms, followed by healthy paused state and ordinary Reset recovery.
That gate reset immediately after the stop. Source review identified a separate
follow-up transition that it had not exercised.

The authoritative current contract is `simulation_worker.gd:paint_queue`
(lines 2218–2232 at that source): a retained Workbench refusal also blocks readonly
paint capture admission. The worker publishes the exact finite-edge reason at
line 2707; this is a legal pause, not a failed native World. Goblin's old capture
classifier recognized body-protection refusals but treated this prequeue refusal
as `adapter_failure`. The controller terminates a campaign on that classification
(`goblin_controller.gd`, line 352), preventing normal later recovery proposals.

A newly authorized, fixed diagnostic used only ordinary placement at `(256,32)`,
pilot selection, Play, four bounded 16-tick up inputs, one Brush at `(48,48)`,
ordinary Reset, Play and Pause. Both runs used fresh marked profiles, the same
diagnostic SHA256 `5cfa75af574c9ce3de7907d2fccc850fb048318ab7ae5b608d9feeeb9b191745`,
an immutable source snapshot, a 90-second wall bound and a sampled 3072 MiB owned
process-tree bound. The retained import resource cache was reused; neither run
qualifies a fresh editor import. No owned process remained after either run.

| Focused actual native result | Before | After narrow goblin fix |
| --- | --- | --- |
| Base source | `89c91ba5342d485e787d39e64103fc6c91c5f92b` plus diagnostic only | Same base plus four explicitly hashed goblin adapter/oracle/test files and the identical diagnostic |
| Checks | 194; exactly one classification failure | 195; all passed, including new refusal-proof oracle |
| Retained action records | 11 | 11 |
| Elapsed process time | 11.594 seconds | 10.658 seconds |
| Sampled peak process-tree RSS | 585,859,072 bytes | 585,789,440 bytes |
| Post-edge Brush | Refused before admission, incorrectly `adapter_failure` | Refused before admission, correctly `not_applicable` / expected refusal |
| Native source at Brush | Healthy and paused; generation 4, revision 4, tick 54, unchanged | Healthy and paused; generation 4, revision 4, tick 54, unchanged |
| Ordinary Reset and resumed ticks | Passed | Passed |
| Raw evidence ZIP Git blob | `fba08d82d24ad29913f269b9281b6a276d7b5249` | `1bd7617cc800be5076590c373df6ed739f07097e` |
| Raw evidence ZIP SHA256 | `178db00c11568d781c98ca5c2abee5fd68062c8915901dea0d385503b603a6dc` | `c328fd7e7fb734a4ceb5882aa7de0da67bccc3fe0d35923c47f9e4de268a71c5` |

The archives retain complete raw observations, original profile output, process
logs/results, source and runtime manifests, and the exact diagnostic and bounded
runner. Godot SHA256 is
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`;
native and Rapier bytes match the 105/4 recorded source inputs and the retained
`a15fc422…` / `566e68ae…` library identities. The diagnostic and runner themselves
are immutable blobs `3c070ebc707ff31325ba3db21a4365a7d67e89e6` and
`6a39bc52aa42fa95107af36c3827ef7d747892bb`.

The repair admits this classification only for an exact refused prequeue capture
with no admitted edit or completed receipt, unchanged healthy paused native
identity, the exact published finite-edge reason and a matching immutable current
publication. Timeout, cancellation, native failure, stale publication, other
body-sample refusals and other capture errors keep their prior classifications.
An independent oracle binds the capture proof to the action's final native
observation. The ordinary native metamorphic test now includes the follow-up
Brush before Reset. Pure positive and hostile controls passed 110 checks in
0.511 seconds; these synthetic controls establish validator behavior, not native
coverage. Their log SHA256 is
`280908b7bba8f523f44b5cb5a64197fefadd3146f6c636b23e21aa54f880b9bf`.

This is a confirmed and repaired **goblin harness defect**. No production gameplay
implementation changed, and no production gameplay defect is claimed. The new
integrated source still requires its own hosted platform qualification.

## Ownership and next handoff

The lead owns controller/UI/anomaly classification and final integration.
Exploration owns policies, state abstraction, coverage and bounded corpus.
Replay/delivery owns strict tape/schema/Python validation, campaigns and package
custody. Gameplay owns the adapter, actions/oracles/capability helpers, fixtures,
expanded native test and metamorphic test. All source changes are additive to the
opt-in developer laboratory; no default activation or Ready/merge promotion.
