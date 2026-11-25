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

## Step-to-Save timing hypothesis: bounded negative result

Read-only review of the retained Linux metamorphic observations found a legal
cached-context transition: the capture following 16 exact Steps started with
`source_before.paused=false` and completed with `source_after.paused=true`, at
unchanged generation/revision/tick. `simulation_worker.gd:paint_state` returns the
last paint context; a single-step turn temporarily sets `local_paused=false`,
while capture admission separately checks the actual mutex-owned `_paused` flag
and consumption rechecks the owner context. The next ordinary worker turn
refreshes that cache; Workbench is excluded from the unrelated lockstep hold.
This observation suggested, but did not establish, a false persistence-oracle
failure if Save immediately follows Step.

One bounded Controller diagnostic at clean source
`d849be8ef99cd9226cfc3ca0925752e42b691515` plus its explicitly hashed diagnostic
overlay exercised two prescribed campaigns at pacing zero: Pause→Save as the
control, then a fresh `history_edges` Single Step→Save. The ordinary Controller's
proposal/admission checkpoints and source/fixture identity fences remained
active. Both two-action tapes finished `budget_complete`; all four actions and
39 action assertions passed, as did all 10 diagnostic checks. The candidate Save
started and finished with `paused=true`. The suspected oracle failure did **not**
reproduce, so neither the GDScript nor Python persistence oracle was changed.
No automatic anomaly bundle was expected or created.

The process completed in 12.595 seconds, sampled 649,310,208 bytes peak owned-tree
RSS, and left no owned process. Its bounds were 90 seconds and 3072 MiB, with no
editor import. The complete raw evidence ZIP is Git blob
`ab80f56c991535351cd53fd2292975d37f2547f9`, SHA256
`744156247e66d90f4c3302e401f4519b8a58da8bcf48f8bc5cd17cc2ce316104`.
The diagnostic and fixed runner are blobs
`85b81481c6796ffc148ce24dd5651dc87cf57bb2` and
`05dd7a1b44d5b4968c05fcd7716252dfc9d354da`.

The first diagnostic attempt is also retained. Its newly constructed action
fixture omitted `fixture_sha256` and `initial_scene_identity`; the Controller
correctly rejected it before dispatching any gameplay actions. This was a
diagnostic setup error, not a deliberate negative control or gameplay defect.
The corrected replacement used the exact retained installation identity without
relaxing the guard. Original setup-error ZIP: Git blob
`9d71415ed443be8dea8f27de988a8eab84da3401`, SHA256
`8beea0981ab37b00781a7421eed5e19bc57eda184156a6befdd2383e88c0c9f7`.

## Ownership and next handoff

The lead owns controller/UI/anomaly classification and final integration.
Exploration owns policies, state abstraction, coverage and bounded corpus.
Replay/delivery owns strict tape/schema/Python validation, campaigns and package
custody. Gameplay owns the adapter, actions/oracles/capability helpers, fixtures,
expanded native test and metamorphic test. All source changes are additive to the
opt-in developer laboratory; no default activation or Ready/merge promotion.
# Request-4 monowheel finding: confirmed test-oracle defect

The extracted Windows `COVERAGE_HUNTER` / initial `alchemy` / seed 13 / budget 64
campaign on clean `a6abb07aa8374dc2a870c2a6c9d0aca4f1981402` stopped after 61
completed actions because action index 60 failed `actor_place_position`. The
ordinary operation itself was accepted and completed. Its authored spawn was
`[256,96]`; its physical root was `[256,97.5]`, its rim was `[256,96]`, and its
equipment part was `[260.5,97.5]`. Native tick and physical tick were both zero,
and velocities were zero. Original tape: 817,872 bytes, SHA256
`9476a8bcf39c188a811eed6f9dc05dc8056515362af27a4bf473cf5905a0e302` in request-4
Windows artifact `14989104342`. The original failed assertion and automatic
candidate remain intact; this is **not a production gameplay defect**.

Independent product authority, pinned to that source:

- `physical_actor_catalog.gd:498–504` authors monowheel's first `weighted_cab`
  part at `(0,1.5)` and its `tumbling_rim` at `(0,0)`.
- `physical_actor_rig.gd:408` constructs each body at authored origin plus its
  part offset. `physical_actor_session.gd:389–404` exposes the position of body
  zero as `workbench_actor_state.position`.
- `shared_workbench.gd:1045,1067,1119,1127` routes placement, Move and Reset
  through ordinary owner transactions. `apply:735–744` excludes the selected
  reset identity from retained transforms, so Move and Reset reconstruct that
  assembly at the authored origin. Replacement likewise uses the preceding
  actor's saved authored spawn.
- `physical_usable_equipment.gd:53–87` appends equipment geometry without
  replacing the first two monowheel parts. B independently matched these five
  product files in the actual packaged ZIP to pinned Git source, accounting for
  Windows CRLF serialization only.

The inherited oracle incorrectly treated assembly origin and first-body origin
as interchangeable. The narrow correction uses an independently transcribed
finite six-model root-offset map: monowheel `(0,1.5)`, the other five admitted
models `(0,0)`. It preserves separate authored-spawn, live-root and retained
part-zero checks, and also checks monowheel's rim at the assembly origin. It
covers placement, Move, Reset and replacement. Unknown models fail closed.
Legacy v1 observations do not acquire invented authored/part evidence; current
v2 observations require those fields. Existing Capture/Save Spawn semantics are
unchanged. Capture reads the physical root; a later Reset interprets that saved
coordinate as an authored assembly origin. No multipart capture/reset
idempotence contract or associated production defect is claimed.

C's independent review caught a Python serialization pitfall in the proposed
repair before qualification: default Godot JSON spelling can round a float64
representation of a native float32 coordinate. The Python reader therefore
compares exact finite float32 encodings for physical points. The retained actual
Capture spelling `[95.8000030517578,224.130004882813]` and the immediately adjacent
representable float32 negative control are covered. This is a representation
comparison, not a geometric tolerance. Root's malformed huge-integer concern is
also rejected by the pure helper.

The exact a6 Python reader independently reproduced the retained Windows tape's
single wrong position failure; the corrected product-contract reader finds no
physical violation in that unchanged tape. This is a new interpretation of old
observations, **not new gameplay and not a pass under an unchanged invariant**.
The original expected value remains preserved, and the generic regression reader
continues to reject a purported corrective case that changes its acceptance
rule. Independent review report SHA256:
`b67b47d5c7de807a8a825e7b532f9fd2f5fe772fc70e90e79fbb5df7b4de9467`.

A separately authorized Linux before diagnostic was attempted once with exact
a6 plus one explicitly hashed test script, a fresh marked profile, no importer,
90-second wall bound and 3072 MiB owned-tree bound. It was killed with exit `-9`
after 4.224 seconds, sampled peak 328,073,216 bytes, no surviving owned process,
no diagnostics and **no gameplay report or candidate**. Its 252-byte startup log
does not establish a reproduction or reduction. This remains unattributed
infrastructure, with no OOM or game-failure inference. Raw ZIP: 61,060 bytes,
SHA256 `459aa8b6a9a84cc9b59a42be5848f9a10e022ff20f87928b3be2f2f4ef231eb0`,
immutable blob `40a9d807947753a9653bd143cb718cadb02ea8eb`. No equivalent local
native retry was launched.

Validation before the next hosted candidate: exact Godot 4.7 isolated pure
oracle controls **218/218 passed** in 0.606 seconds, sampled peak 113,963,008
bytes, with no World, native extension or import; Python **6/6** focused origin
controls passed. These are artificial hostile oracle controls, not gameplay
coverage. The committed expanded native gate adds six-model placement → Move →
Reset → replacement coverage, plus one ordinary paused monowheel Capture/Reset
observation. **Native corrected-source qualification is pending hosted request
5**; the earlier interrupted local process does not supply it.

## Subsequent native qualification and retained-clock oracle finding

Request 8 qualified the corrected actor-origin contract on Windows at
`5ee5dffc78d59a721f62be49fd51d24b870556c7`. The added six-model gate first
required two test-only corrections: its own coordinate comparison had compared
integer and floating-point Arrays, and it attempted replacement into a model
absent from the ordinary compact picker. Neither failure justified changing the
runtime oracle or picker authority. The repaired gate compares exact finite
coordinates and uses same-model replacement for each model; the existing
Runner-to-Kestrel case retains cross-model coverage. B's independent request-8
native audit passed 248 checks: expanded 1,729 checks/86 attempts/83 completions,
metamorphic 473 checks/36 attempts/33 completions, and the extracted Alchemy
campaign's 64 completions. The five refusals and one published finite-edge partial
remain distinct from completed actions. Review blob:
`8088b38271d1238455fb5871406b125b684266b5`.

A separate source review then identified an incorrect applicability assumption:
a replacement owner's local tick zero does not establish that its material plane
is still the authored start. `shared_workbench.gd:apply` (686, 694–697, 732–744)
retains current native cells during ordinary settings and actor transactions.
`save_setup` (1217–1236) saves the authored document and explicitly does not read
the live World; `load_setup` (1242–1268) constructs that saved authored start.
The old goblin comparison nevertheless treated every Save at current tick zero
as eligible for exact equality with Reopen. Selected actor Reset is also a
retaining transaction; it is not Restore start.

The first two dedicated diagnostic attempts are preserved with their original
dispositions. Request 1 dispatched zero actions because an initial source queue
count of one was insufficient to prove its command was inert. Request 2 completed
all nine actions, but one callback observed the queue only after an unobserved
command had drained. Its material relationship was suggestive; the required
actor/source absence proof remained unresolved. Neither attempt is relabelled as
a qualified reproduction. A bounded read-only observation addition then copied
queue contents, owner generation/pause and current source receipt inside the
adapter's existing worker mutex, giving each actual recorded observation its own
atomic proof. This changed instrumentation identity, not gameplay behavior.

Request 3, source `070addb0fdae2240f22e663a2299cef739f83c05`, run
`45556434887`, artifact `14995732784`, qualified all preconditions and reproduced
the wrong oracle. Artifact SHA256:
`2f2dc54b6c8af392364e915776cdae4f384e3dacc8f8209dc97c2a7beef25fd8`.
The raw report SHA256 is
`138e320b6bc8d4477e7a702abb1994c25f5357b523f27d47cda28f89e3d49221`.
All nine ordinary actions completed. The four-action control played, paused,
saved and reopened. The five-action variant inserted ordinary response-mode
replacement before Save. All 20 recorded source proofs were coherent: 19 empty
queues and one actually copied inert Stop, no actors or authored sources, and
disarmed zero-emission receipts. The native process completed in 17.928 seconds,
sampled 648,253,440 bytes peak owned-tree RSS, and left no owned process.

The variant preserved its actually simulated cells across generation 3/tick 16
to generation 4/tick zero. Its saved material SHA256 was
`70fc348668c692888d972870afbae2ae349ec303375b12cdb29d06271627cdb1`.
Reopen correctly reconstructed the authored plane, independently rendered from
the finite rectangle recipe with SHA256
`acea5f8e573d757af5c560778bbd2222f96065c298e62fcfb8996817486da14a`.
The isolated 48-by-48 enclosure retained 64 Sand and 368 wall cells; the Sand
vertical-coordinate sum changed from the authored 736 to the variant's 1,730,
then returned to 736 on Reopen. No equality of asynchronous trajectories was
assumed. The sole failed assertion was `authored_reopen_materials` at variant
index 4. Its automatic original candidate remains intact, SHA256
`ff835fb875d2764345f6cc28e52af74aa8b7048b2b5b35522b02394e04364d62`.
B's independent 78-check adjudication is blob
`00cf2ff7900e72c7df38cf6db6945c3929014ac2`; its repeatable audit is blob
`ba8441d311516cf7995d1e2cc8ce494bd5e907de`.

This is a **confirmed goblin test-oracle applicability defect**. The product
performed its authored-persistence contract correctly. The original candidate's
automatic unresolved classification and old expected hash are preserved; the
reviewed classification is additive. No production gameplay issue or correction
is claimed, and the repair is not a pass under an unchanged acceptance rule.

## Material-lineage correction awaiting request-9 native qualification

Adapter observation contract 3 adds bounded material-history evidence with three
states: `authored_compatible`, `simulation_exposed`, and `unknown`. Positive
native progress establishes simulation exposure, not necessarily cell movement.
Fresh fixture construction, Restore start and Reopen can establish authored
compatibility only with an actual acknowledged construction receipt. Ordinary
retaining settings/actor transactions preserve prior exposure; unseen running
intervals, unacknowledged replacement and partial effects cannot manufacture an
authored-compatible claim. Selected actor Reset never clears material history.

The adapter tracker, runtime assertions and external Python reader independently
reconstruct these obligations. Construction receipts bind their full canonical
SHA256 and their hashed header's domain/schema, little-endian generation and zero
construction tick to the actual native observation. This follows
`native/include/cybersand/liquid_run_receipt.hpp:build_applied_run_receipt`
(310–337); changing only an old receipt's outer generation is rejected. The
exposure witness means the latest actual positive observation: it exactly matches
each recorded positive endpoint and is carried unchanged through a retained
tick-zero replacement. Save copies its lineage immutably into Reopen evidence.
An invented or stale witness cannot support a new claim.

Fresh authored Save/Reopen still requires exact native material equality.
Independently established exposure uses the explicit reason
`simulation_exposed_lineage`; uncertain history uses `unknown_material_lineage`.
Both retain actual capture/source custody requirements. Native body-protection
refusal remains its separate exact justification. Original observation contracts
1/2 keep their original interpretation, including the old wrong assertion in the
retained request-3 tape. A read-only comparison of 23 unique retained tapes/1,187
records found identical complete reader results before and after the versioned
change; this is compatibility analysis, not new gameplay or retroactive success.
State projection contract 3 labels its current generation's phase `zero_tick`;
legacy projections retain their historical label. Lineage adds no nominal
material-interaction coverage.

The new fixed `test_authored_lineage.gd` gate runs four disposable ordinary
Controller campaigns, with 20 literal admitted action requests in total:

| Native case | Actions | Required independent relation |
|---|---:|---|
| Fresh authored | 2 | Save/Reopen equality is applicable and passes. |
| Simulated, retained response change | 5 | Retained tick zero stays exposed; authored Reopen differs from the saved live plane and equality is explicitly inapplicable. |
| Simulated, retained, Restore start | 6 | Actual Restore establishes a fresh authored lineage and mandatory equality passes again. |
| Simulated actor, selected Reset, Remove | 7 | Reset and removal retain exposure; removal permits full-plane capture, with correctly inapplicable equality. |

The report retains exact source-bound tapes, complete Save/Reopen capture
receipts, independent whole-plane rectangle reconstruction and all runtime
assertions. Its internal bound is 270 seconds and its external source/extracted
runner bound is 300 seconds. A failed or incomplete gate cannot qualify from its
summary alone. A and C independently reviewed the literal action path, report
schema, source fences and relationships. Eleven targeted artificial lineage
controls cover positive equality, stale canonical receipts, invented witnesses,
missing initial proof, partial replacement, running gaps, version dispatch and
Save/Reopen custody. The combined lineage/origin/package/evidence Python subset
passed 47 tests in 0.403 monitored seconds, sampled 22,650,880 bytes peak RSS,
and left no owned process. These controls ran no Godot or gameplay. Actual
corrected-source GDScript parsing, native behavior, long-horizon campaigns and
extracted Windows execution remain request-9 qualification obligations.

## Request-9/10 native gate defects and preserved after observations

Request 9 at `6afae9c149b48e6bbcd4a92a50c98d057c0e8067` passed the preceding
source groups but the new standalone gate failed to parse before dispatching an
action. Its local `all_cases` declaration attempted inferred typing from an
untyped Dictionary property. The narrow correction declared that Boolean
explicitly; no runtime adapter/oracle changed. Windows retained the actual
0.313-second failure, 108,281,856-byte sampled peak RSS, no surviving process and
no report/completion marker. B's strict read-only source audit passed 837 custody
checks and retained four unsuccessful completion obligations; compressed review
blob `be3d33ec8e029a52a03f991f6d78b7a49d7b5deb`. An earlier source-only review had
missed this GDScript inference restriction. It was not native qualification.

Request 10 at `4050bc31526558cb99024251d29ec1183c086d6a` executed all four
cases and all 20 ordinary actions on Windows. Every tape ended `budget_complete`
with no runtime assertion failure. The gate nevertheless failed its four
test-local `exact_source` checks: `Transcript.create` canonicalizes finite
integral JSON floats to integers, while the launch Dictionary retains its parsed
float types. The raw report proves precisely three representation differences:
native input count `105`/`105.0`, Rapier count `4`/`4.0`, and nested game-source
count `956`/`956.0`. All other fields, values and types match. Direct GDScript
Dictionary equality was therefore the wrong test comparator.

The actual request-10 Windows process completed in 38.141 seconds, sampled
553,431,040 bytes peak owned-tree RSS, and left no owned process. Raw report
SHA256: `c2809f0f01269f54c60164095340de302a461bbebb2d74df546be70a96af1cb6`.
B's independently implemented auditor checked 1,094 source, capture, receipt,
lineage and terminal obligations. Its 1,087 passing checks establish all four
material relationships, actual canonical replacement receipts, latest observed
progress witnesses, full-plane capture custody and immutable Save proof. The
seven failing obligations preserve the original process/report/four-case
failure statuses and diagnostic-error log. They are not silently converted to
a qualified run. Fresh and Restore captures equal the independently rendered
authored `acea5f8e…` plane; both retained captures differ and Reopen reconstructs
that authored plane. Selected actor Reset and removal preserve exposure.

The further test-only correction compares every provenance field through the
existing full sorted transcript JSON normalization. It does not use the smaller
portable replay identity subset. Fourteen separately recorded artificial
controls preserve rejection of changed source/runtime/project hashes,
incidental fields, fractional/nested counts, Boolean substitution and missing or
extra fields. Those controls add no gameplay-action credit. Gate blob
`4bdd1f625d84dc6a0095b76768cfe861ef07014c` is reviewed for the next qualification;
the request-9 and request-10 original failures remain intact. The production
game, lineage tracker, runtime assertions and independent Python reader have no
further changes from the request-9 correction.

## Request-11 Windows actual after evidence

Exact source `6f359ce2b24291ee219810773c641d53802fd31d`, tree
`a4f389cd3cc1a21dfe3d5566703eb946b66734ed`, now passes the independently
registered native lineage audit both in the Windows source gate (1,094/1,094
checks) and in the actual extracted evaluator (273/273). Each execution contains
four distinct campaigns and 20 completed ordinary actions. Fresh construction
and Restore require and satisfy exact authored Save/Reopen material equality;
retaining response replacement and selected actor Reset retain observed
simulation exposure and correctly make that equality inapplicable. Their saved
material planes differ from the authored plane that Reopen reconstructs. Full
native capture identities, canonical construction receipts, latest observed
progress witnesses and immutable saved proof are independently checked. This
qualifies the corrected oracle applicability; it is not a production-game fix
or an unchanged-invariant regression pass. The original 070 observation and the
request-9/request-10 gate failures remain unchanged.

The final Windows ZIP has 95,816,253 bytes and SHA256
`daca112474286798950977909b1be000cd5b75657b231c028d366515836cdc4e`.
B's extracted review read only 12 exact source/provenance files plus the actual
manifest, lineage report and log; no engine payload was extracted or executed
locally. C separately owns the complete package and wrapper custody audit.
The sealed B packet is Git blob
`621448b4456b77c0acab8a7eeb88b627a9561f12`; it links full review outputs, exact
reader/pins, package selection custody and the bounded data-only process receipts.

A separate retrospective read-only audit of the current Windows source reports
and six representative source tapes passes 731 checks and finds completed
instances of all 55 supported action IDs. The expanded gate reports 2,030 checks,
86 attempted rows, 83 completed actions and three expected refusals. Its stored
row assertions comprise 1,591 passes and three inapplicable checks; the gate
check count is not an action count. All 29 added IDs complete, including an
accepted equipment use with five changed cells and ordinary cancellation of an
observed preview. Six supported model-origin contracts are independently checked
through Place, Move, Reset and Replace, with the extra Monowheel Capture/Reset
observation retained separately from any idempotence claim. Deliberate invalid
and preadmission refused inputs receive no completion credit. The comparative
5ee matrix still has its own 53-ID union and source-specific metrics. Linux
request-11 qualification remains separate and pending this Windows handover.


## Request-11 Linux native evidence and bounded long episodes

The original Linux job at source `6f359ce2b24291ee219810773c641d53802fd31d` / tree `a4f389cd3cc1a21dfe3d5566703eb946b66734ed` remains a failed qualification job: four long episodes did not finish their requested budgets. Its actual focused native evidence is now independently adjudicated. No further game process was launched to obtain this review.

The fixed, previously reviewed lineage auditor `d50a77d52969008b8a0c090070c9e7665f013c7e` ran unchanged against the retained Linux source report in passive workflow run [45579669046](https://github.com/techrote/cybersand/actions/runs/45579669046). All 1,094 checks pass, with four distinct native cases and 20 admitted completed ordinary actions. The checks bind the exact source archive and snapshot, native/runtime provenance, canonical construction receipts, capture sources, latest positive progression witnesses and immutable saved lineage.

| Native case | Actions | Expected full-plane relation | Actual disposition |
|---|---:|---|---|
| Fresh authored construction | 2 | Save and Reopen equal the independently rendered authored plane | Equality passes |
| Retaining response change after progression | 5 | Save contains exposed live materials; Reopen restores authored materials | Equality is correctly inapplicable |
| Authored Restore after progression | 6 | Restore re-establishes authored compatibility; Save and Reopen equal authored materials | Equality passes |
| Selected actor Reset after progression | 7 | Reset retains material exposure; ordinary actor removal permits the full capture | Equality is correctly inapplicable |

Every reopened plane, and both positive saved planes, has SHA256 `acea5f8e573d757af5c560778bbd2222f96065c298e62fcfb8996817486da14a`. The Linux retained-response Save is `85d140519fd85283c20d8d92692585a667d4a51a93ae6dfb30450eec53b3e5e8`; the selected-Reset Save is `70fc348668c692888d972870afbae2ae349ec303375b12cdb29d06271627cdb1`. The first differs from the corresponding earlier Windows/before trajectory. That is permitted: the relation concerns actual source-fenced material state, not equal asynchronous trajectories across runs or platforms.

The original native gate took 32.862 seconds, sampled 649,768,960 bytes of owned-tree RSS, exited zero and retained no surviving owned process. Its separate import took 6.661 seconds. The later passive Python audit took 0.313 seconds and sampled 30,326,784 bytes; those are review costs and contribute zero new gameplay actions.

The frozen A and C readers agree on all eight registered long episodes: 2,858 attempted actions, 2,847 admitted completed actions, 11 refusals, no partial rows and no recorded failing assertions. All eight tapes validate. The exact independent verifier also rejects unreported raw-invariant failures, so valid tapes with no recorded failures do not conceal a known independent failure. Both policies complete their 128- and 256-attempt budgets. Neither completes its 512- or 1,024-attempt budget.

| Original episode | Attempted / completed | Original controller terminal | Process wall / cap (seconds) | Sampled peak RSS (bytes) |
|---|---:|---|---:|---:|
| RANDOM, 512 | 436 / 434 | campaign_timeout | 622.892 / 674 | 802,693,120 |
| COVERAGE_HUNTER, 512 | 501 / 499 | campaign_timeout | 622.547 / 674 | 778,534,912 |
| RANDOM, 1,024 | 537 / 535 | campaign_timeout | 909.588 / 960 | 881,831,936 |
| COVERAGE_HUNTER, 1,024 | 616 / 614 | campaign_timeout | 909.762 / 960 | 825,188,352 |

Each incomplete episode retains two refused rows, zero failed assertions, no pending action and an ordinary exit code 1 with no surviving owned process. Their original `test_failure` / `unresolved_observation` labels are preserved. Controller elapsed times are respectively 616,294, 616,186, 901,520 and 902,471 milliseconds. The registered source bounds are 614,400 active milliseconds for a 512 budget and 900,000 for a 1,024 budget, with separate outer caps of 674 and 960 seconds.

These are source-bound recorded campaign deadlines under the independently checked outer process limits. The transported frozen reports do not include `decision_pause_msec`, `pacing_msec` or the final native pause publication. This review therefore does not claim a new independent exact active-time subtraction or a fresh final native-pause proof. The optional prepared terminal reader was not executed. The authoritative source branch remains `goblin_controller.gd` at this exact source: bounds at lines 198-209, timeout admission at 281-284, and retained clock/terminal evidence at 368-378. No production gameplay defect or unbounded resource escape is established by these incomplete budgets. There is one episode per policy/budget; this is not a completion-rate estimate. No supplemental CONTROL run was activated.

Custody anchors:

- Original Linux artifact: `15003384515`, 50,241,858 bytes, SHA256 `c5ab54aa45062bf12912e29743058019bc1db38ae59c0a4b234172d6b371fe6e`.
- Original native lineage report: 647,026 bytes, SHA256 `55339e4cf1c1b5cf8bc593b1083367a276ee1653675fd17641c6d8143d6a3d60`.
- Full unchanged B reader output: 125,105 bytes, SHA256 `d84834fa7aaa34bcbb365b0bd4ef4c6947498fa567a69918d172dff0534f1c5e`.
- Full A primary output: 1,040,902 bytes, SHA256 `c32ab2dcbd84f969a8dff36c9e0b31122a0e7664e70516d7fc0334d9046306dd`.
- Full C custody output: 66,553 bytes, SHA256 `37b91339a5cf53b5dd0c8df0ebedda8d33fc1df717d947fe2065e54c61ce1c95`.
- Passive job log with the complete transported B report and bounded A/C summaries: Git blob `7e99bc3d49a24ee31c9c87872063d664de2d5b33`.
- Passive stage artifact: `15005776720`, 942,877,571 bytes, SHA256 `8621cf2811e14fdda3e98749f84b7d0887228f0c64b91967ae67485627552da9`.

The passive driver is commit `2a627a3131be72fcb876acec0d0b848a7e42c3e3`, not the executed game source. This handover reads the exact transported report object; the frozen driver hashed and retained the original report file. The full raw results, reader bytes, pins and owned receipts remain in the stage for final passive sealing. Original failed and unresolved diagnostic attempts, the two established oracle defects, and the earlier Windows qualification retain their separate identities and dispositions.


## Final delivery and late recovery addendum

The main evidence archive sealed successfully at driver f3324f462091d1778b9472ebcafbab35372e6411,
embedding the exact e8df89b48757096428ee6a9d12e55c7e417c10d5 RESULTS snapshot.
Its 666,742,658-byte inner ZIP is available through GitHub artifact 15008615196;
a second direct copy was blocked before local download by the connector size
limit and available workspace space. The qualified Windows evaluator remains
saved and unchanged at game source 6f359ce2b24291ee219810773c641d53802fd31d.

After sealing, all six selected predecessor native tape bodies were recovered
at their original byte/hash identities. A's new 960,187-byte supplement has
SHA-256 c34a9f0e1d520c6a45f6bff7073cd2c54e11ea28425ef755ce8f2b2ce6840f74
and was saved successfully. Eleven compact paths were checked in total: six
selected bodies and five identical aliases. The pretty serializations were not
reverified. Five historical completions, two unattributed -9 interruptions,
988 observed completed actions and Random a01's missing tape/count remain
unchanged. The old assembled 75b4 ZIP was not located in the two scoped roots;
this new supplement is not a reconstruction claim.

A recovery record ba46c0d4fcde350923ee796aa9bd691e1b58e75c, B's thirteen-check
review a7273bfcdd601940e273ee094317052d594afd58 and C's actual delivery record
86e1dc88d8863e5d69fa2d73bf1addf7a9e5f31e retain the distinct verification scopes.
The [final delivery record](../../tools/gip014/evidence/passive/final-delivery.json)
and [owner decision packet](gip014-goblin-002-decision.md) record the actual final
status. The sealed archive and historical incomplete outcomes are unchanged.
This final passive work adds no gameplay, analysis cohort, native qualification
or production defect. Draft/HOLD remains in force.
