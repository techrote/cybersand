---
title: GIP-014 goblin in-game gameplay QA
status: Current
document-kind: research
scope: Accepted opt-in Goblin001 foundation, guarded audit storage and source-bound developer qualification
canonical-for: [gip014-goblin-gameplay-qa]
last-reviewed: 2026-11-26
related-documents: [../operations/local-build-and-validation.md, ../operations/github-development-and-release.md]
---

# GIP-014 goblin gameplay QA

The Goblin001 foundation was accepted through
[PR #772](https://github.com/techrote/cybersand/pull/772) at main
`c8421a81b8f7f61516ed055f3200b49aee57bd65`. It owns an opt-in developer scene, bounded in-game action adapters, disposable
fixtures, policies, evidence readers and focused documentation. It does not change
ordinary Workbench startup or enable autonomous gameplay by default. Physical
owner acceptance remains separate. The foundation implements a real in-process Godot controller and has
passed native Linux campaigns, the actual hosted Windows developer UI test and
the separate extracted-package custody gate. The qualified Windows developer
evaluator is an unchanged source-matched artifact of commit
`3e3aa217b49036ac4a87dd57073ad2cbb5a314c8`; this final documentation update
does not change or relabel that runtime. The separate Goblin002 successor
[PR #781](https://github.com/techrote/cybersand/pull/781) retains its own qualification
and owner gates; its memory, corpus and expanded output paths are not part of this foundation.

## Verified audit storage

The four permitted output destinations remain the transcript, summary, replay
result and the controller's selected run archive. The actual isolated-profile
guard, existing document/campaign budgets and tab-indented JSON representation
are unchanged. No game action receives an arbitrary filesystem path.

The guarded writer now writes a unique sibling staging file, flushes and closes
it, then reopens and compares all bytes before using the already accepted
`CyberDemoBridge.replace_material_baseline_file` primitive. A failed write or
replacement reports failure and preserves the previous complete destination;
a successful retry on the same controller clears its earlier error. Unrelated
old staging files remain untouched. Each output file is a separate transaction;
this does not promise power-loss durability or a transaction across several files.

The 26 November closure reproduced the prior buffered-write defect on the accepted
foundation: a valid 1,699-byte audit was replaced by 128 bytes while returning
success. The corrected Linux source passed actual short-write, permission and
retry controls, 84 native/injected boundary checks, and the real five-case
controller test with 75 assertions. These local results do not establish Windows
sharing-lock behavior or final merge qualification. The
[mergedown ledger](https://github.com/techrote/cybersand/pull/784) records exact
source identities, original failures and later platform/merge receipts.

## Shared progress and ownership ledger

| Lane | Owned files | Current checkpoint |
| --- | --- | --- |
| Lead | Controller, interactive scene, fixed launcher, focused Windows lane, guide | Complete campaign ownership, atomic pending/terminal evidence, opt-in UI, bounded replay/reduction |
| A — game adapter | `godot/goblin/goblin_adapter.gd`, `godot/goblin/tests/test_adapter.gd` | 26 finite actions; native edits, genuine tick intervals, actor ownership/input and isolated persistence |
| B — behavior | Policy, fixtures, policy test and controller lifecycle test | Six persistent seeded policies, five authored fixtures; independent controller/replay review |
| C — independent regression | Assertions, transcript, contract tests, Python evidence reader and package builder | Independent native readback, replay projection, negative controls and extracted-package gate |

All lanes work in one isolated checkout with disjoint write ownership. The lead
serializes source checkpoints and execution; no lane rewrites another active
programme. Review rotates across adapter, policy, evidence and UI ownership.

## Recovered foundation

[PR #749](https://github.com/techrote/cybersand/pull/749) remains Draft/HOLD at
`a6fce059fa5620fcf4adb60cb9d2e7ed79050401`. The original
[run 45066785091](https://github.com/techrote/cybersand/actions/runs/45066785091)
has a successful `contract-model-only` job. Its retained artifact
`14771737423` has SHA-256
`6f631e299bc2bc0533ee13e6bfa7ca32913db7664320613826c26fce5d4417a0`.
The workflow head is `a6fce059…`; its executed merge-source identity in the
original transcripts is `dc7ce8d81dbb1f58b9d40b2fe75fb1009288b4fa`.
Those original identities are preserved, not rewritten as native qualification.

Original CONTROL completed 19 reference-model actions and CHAOS completed 96,
with 18 and 62 adjacent action pairs respectively, and no recorded model
violations. Synthetic tick fields and the absence of a native runtime hash mean
these are reference-model results only. GIP-014 reuses the bounded vocabulary,
seed, transcript, independent checker and replay concepts in actual in-process
Godot tests; it imports no model-service integration or synthetic game owner.

## Application and evidence boundaries

The launcher must create a fresh profile before Godot starts. The adapter verifies
that the actual Godot user directory is inside that marked profile before mounting
the ordinary application. Authored persistence uses only the normal Workbench
Save/Load APIs and the fixed `goblin-layout` name. Transcript/replay files live in
the fixed `user://goblin/` test directory. No game action accepts a path, command,
script or network destination.

Each action retains proposal, admission, native completion receipts and independent
before/after observations. Unsupported actions are not applicable. Crash, timeout,
assertion failure, refused operation and timing observation remain separate labels.
Unit fixtures with deliberately inconsistent data qualify assertions only; they
are never reported as discovered gameplay defects.

## Run and watch goblin

### Qualified Windows developer evaluator

Download the qualified evaluator artifact from
[run 45474099351](https://github.com/techrote/cybersand/actions/runs/45474099351).
GitHub's outer artifact ZIP contains the inner `CyberSand-goblin.zip`; unpack
that inner ZIP into a writable folder, and double-click `Open goblin.cmd`.
Godot and the required native libraries are included; Python
and a separately installed Godot are not needed. The launcher creates a new
disposable profile beneath the extracted package's `test-output` directory.

For a first watch session, select `Actor workshop` (fixture ID `actor_workshop`),
`WANDERER`, seed `13`, budget
`128`, and pacing `150` ms, then press Start. The fixture picker is inside the
developer panel; the launcher initially selects `material_playground`. Use Stop
to release pilot input and pause the game before changing experiments. The
package's PowerShell launcher can rerun its two fixed 64-action campaigns and
graphical controls test. Run this command from the extracted package folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Open goblin.ps1" -Mode SelfTest -GraphicalSmoke
```

### Source invocation

Use the repository's pinned Godot `4.7.stable.official.5b4e0cb0f` and materialized
native/Rapier libraries whose retained source-input manifests match this checkout.
The existing [local build guide](../operations/local-build-and-validation.md)
defines that reuse rule for GDScript-only changes. This mission does not rewrite
runtime manifests or claim a fresh native build.

From the source root, substitute the pinned executable and a new disposable output
directory for each command:

```sh
python tools/gip014/run_goblin.py --godot /path/to/pinned-godot --case interactive --out /path/to/new-watch-run --fixture actor_workshop --policy WANDERER --seed 13 --budget 128 --pacing-ms 150
python tools/gip014/run_goblin.py --godot /path/to/pinned-godot --out /path/to/new-headless-run --fixture construction --policy BUILDER --seed 605 --budget 64
python tools/gip014/run_goblin.py --godot /path/to/pinned-godot --case replay --out /path/to/new-replay-run --replay /path/to/original/transcript.json
python tools/gip014/verify_transcript.py /path/to/original/transcript.json
```

Replay requires the exact source commit recorded in the transcript's
`header.provenance.source_commit`, its source-input snapshot, fixture and runtime.
Use a separate checkout of that commit before replaying retained qualification
tapes. The retained Linux tapes pin `1649f086a5795d88d03d19fd161ad549365a3fc4`;
the Windows package pins `3e3aa217b49036ac4a87dd57073ad2cbb5a314c8`.
A later documentation-only commit is not silently substituted for either identity.

The interactive scene uses ordinary Godot controls for fixture, personality, signed
32-bit seed, action budget (1–256), pacing (0–3000 ms), Start, Pause and Stop. It
shows the current goal, proposed action, completed/attempted counts, actual native
revision/tick, actor tick and recent outcomes; generation is retained in the
transcript. The green goblin pointer
follows its tool target or the observed pilot position; it is a presentation
character, not an additional simulated physical actor. Where a policy pilots a
Kestrel, input and pose evidence comes from that actual supported game actor.

Pause holds policy decisions after the current action; a playing game can keep
simulating. Stop cancels pending authoring work, releases application-local input
and pauses the scene. The previous recorded campaign can be replayed from the UI.
Each run exports `user://goblin/transcript.json`, `summary.json` and a retained
`run-001.json` through `run-064.json` within that fresh profile. The ordinary
Workbench launcher never loads goblin. Directly launching the developer scene
without a valid dedicated profile is refused before mounting the Workbench.

The source launcher archives the exact executed game scripts and a file-hash map,
then removes its disposable staged project unless `--retain-project` is requested.
Native binaries remain identified by their retained manifests and hashes. The
profile, logs and all attempted results remain available. A campaign has a
150-second active deadline; intentional user decision pauses and action pacing
do not consume that deadline. Native waits use the project's existing operation
and acknowledgement limits, and the normal outer test timeout defaults to 180
seconds plus the explicitly requested pacing budget.

## Supported gameplay and independent observations

| Action family | Existing application seam | What independently establishes completion |
| --- | --- | --- |
| Pause, Play, wait, single step | Normal host pause/play/step and native worker state | Observed native/actor ticks across bounded frames; inactivity while paused; no synthetic counters |
| Material and bounded brush/erase | Workbench palette signal and deferred editor brush | Selected palette value, distinct native completion receipt and captured native cells |
| Rectangle, outline, line, selection | Existing authoring tools and application-local pointer gesture | Independent footprint geometry, native readback, selection bounds and edit accounting |
| Copy, paste, contained Fill | Existing editor copy/paste/fill methods | Actual clipboard/selection, native cells and requested/applied accounting |
| Undo and Redo | Existing supported authoring history | Captured cells restored/reapplied; history domain and replacement boundaries respected |
| Camera and Details panel | Existing Workbench view command and Details button signal | Actual camera origin/extent and current panel visibility |
| Actor selection, placement, pilot, drive, reset | Existing Workbench actor commands; finite W/A/S/D application-local input | Actual supported actor identity, physical epoch, body state, input lease, accepted command sequence, sampled ports and neutral release |
| Save, reopen, fixture reset | Existing Setup save/load and normal scene apply | Authored identity, native generation/adoption receipts and actual readback |

The 26 IDs are defined independently in the adapter and transcript validator.
Every action has explicit `id` and `args`; unknown IDs/keys, arbitrary strings,
out-of-range coordinates and malformed values are refused. Examples of bounds:
ordinary edit coordinates 8–503, radius 0–4, small shapes, predefined camera
extents, at most eight actor identities, only existing Kestrel/reference-barrel
models and native-supported members of the fixed material set. The policy receives
a concrete legal menu derived from the actual scene, history, clipboard and pilot.

Painting and history are exercised while paused. Fill additionally requires a
bounded selection and a native-readback preflight proving its component is
contained. A queued edit is recorded as admitted, never completed. An interrupted
planner can legitimately have no native receipt; its editor cancellation is
retained separately. Previous operations' receipts cannot satisfy a new action.

Save/reopen tests authored starting layouts. The normal save API does not serialize
an evolved physical simulation. Exact native-material equality on reopen is
asserted only when the saved native tick is zero and both native captures complete.
The normal authoring reader protects transient rigid-body-covered cells from
copying. When it returns that exact observed refusal, the optional full-material
comparison is explicitly not applicable while ordinary Save/Load and authored
identity are still checked. Native generation/revision/tick, receipt operation,
unchanged paused state and an actually observed actor must substantiate that
limitation; another capture failure cannot use it. An evolved saved tick also
makes full-material equality inapplicable, with a separate recorded reason.

Not currently supported by this adapter: grab/release, arbitrary configuration
switches, every Workbench panel, continuous painting during Play, deletion of
arbitrary actors, full physics-state persistence, or external/desktop automation.
These are coverage gaps, not reported product defects. The adapter deliberately
does not add production interfaces. Some existing control/observation seams have
private GDScript names; they are confined to this test adapter and guarded by
native readback tests rather than promoted to a new public game API.

## Personalities and committed scenes

| Policy | Recognizable continuing goal |
| --- | --- |
| CONTROL | Rehearse an authored edit/history/copy/save sequence, then pilot a supported actor and observe Play/step/reset |
| WANDERER | Visit cyclic waypoints, leave three-dab breadcrumbs, revisit earlier areas and pilot an observed Kestrel |
| BUILDER | Build Wall cups with Wood ledges and Sand, watch them, erase a central hole in a ledge and occasionally add a barrel |
| TINKERER | Keep a tool experiment together through Undo/Redo, copying, saving/reopening and occasional resets |
| CURIOSITY | Prefer under-observed valid action IDs, adjacent pairs and observed state-to-action transitions |
| RANDOM | Choose uniformly from the same concrete legal menu as a seeded baseline |

Policies preserve their local plan across actions, consume actual observations and
retain refused/partial outcomes. They do not adjudicate success. Reproducibility
requires seed, fixture and observations; asynchronous simulation does not imply
identical wall-clock timings or identical evolved material distributions.

The five version-1 fixtures are `material_playground` (Sand/Water/Wood),
`actor_workshop` (Kestrel, barrel and stepped route), `construction` (Wood frame and
editing room), `liquid_channel` (reservoir, channel and editable gate), and
`save_reopen` (asymmetric authored materials and barrel). They are bounded 512×512
ordinary Setup recipes, with a shared floor and contained Fill pocket. They are
not a second engine or expected-state simulator.

## Replay, reduction and findings discipline

`cybersand-goblin-transcript-v1` stores the exact fixture/version/identity, policy,
seed, source/runtime identities, bounded action arguments, admission, status,
classification, actual native/editor receipts, before/after observations and
independent assertions. It retains every attempt, including refusals and partial
work. A pending proposal is atomically saved before dispatch and updated with its
actual application admission before awaiting completion.

Replay validates source/runtime/snapshot and initial-scene identity before actions.
Semantic replay compares observable authored state, native material captures,
receipt accounting, input commands and assertion outcomes. Exact observation replay
also includes asynchronous timing/sequence evidence. These are reported separately;
timing variation is not hidden by calling both exact. A stopped initialization
transcript with no installed scene remains valid incomplete evidence and cannot
be replayed as a campaign.

For a verified ordinary gameplay assertion failure:

```sh
python tools/gip014/run_goblin.py --godot /path/to/pinned-godot --case reduce --out /path/to/new-reduction --replay /path/to/failure/transcript.json --max-probes 24 --confirmations 2
python tools/gip014/run_goblin.py --godot /path/to/pinned-godot --case reproduce --out /path/to/new-reproduction --fixture-file /path/to/reduction/reproduction-fixture.json
```

Reduction invokes only the fixed in-game entrypoint in a fresh profile per probe.
It first reconfirms the original and then removes action chunks while preserving
the same gameplay assertion, expected predicate, target action/arguments, initial
scene and runtime. All attempted probes and errors survive. A non-repeatable
original remains intact; a passing run returns `not_applicable`. Artificial unit
fixtures can test the reducer but cannot become real-game defect findings.

## Qualification and findings ledger

No ordinary production gameplay defect has yet been independently verified by
this candidate. Earlier failed attempts exposed harness mistakes or execution-host
limits, preserved below. Production owners' sources remain untouched.

| Evidence | Result and scope |
| --- | --- |
| Original #749 run45066785091 | Passing reference model only; original archive and identities retained |
| `adapter-profile-001` | 278 checks/33 operations; two camera int/float oracle failures, corrected in harness |
| `adapter-002`, `control-dev-001` | Staging/import blocked by shared-volume exhaustion; no game pass claimed |
| `control-dev-002` | Import process killed with signal 9; cause not established, no game defect claimed |
| `adapter-003` | Recovered summary:310 checks/35 records pass; genuine actor lease/input and pending native cancellation observed; local raw tape lost at host restart |
| `adapter-004` | Recovered summary:expanded adapter passes its exercised cases; actor placement/pilot/reset/single-step added, without implying26/26 ID coverage |
| `adapter-005` | Recovered summary:723 checks,49 records (46 completed/3 controlled cancelled refusals),25 completed IDs,50 real API admissions,23.040s; local raw tape lost |
| `control-dev-003` | Recovered summary:Linux CONTROL64 completed,17 feature IDs,381 assertion passes,1 N/A,22.521s; local raw tape lost |
| `controller-b001` | Recovered summary:two lifecycle-test failures concerning pre-native cancellation evidence; harness corrected; local raw tape lost |
| `controller-b002` | Recovered summary:lifecycle execution passes,17.353s; pause/resume, Stop, pending admission, profile isolation, fixed archives and mismatched replay refusal |
| Unit controls | Deliberately inconsistent fixtures test wrong cells, stale source, missing/queued receipts, missing input, malformed transcripts and reducer behavior; never reported as discovered defects |
| Local graphical display | Display-server sockets denied by this host; graphical test not run locally |
| Published `5199cd5806e72819bbe512c000aee8dcee6efca1` matched12 | Recovered summary:same construction scene, seeds13/605,64-action budgets;9 complete/3 interrupted capture-preflight cases,692 attempts/689 completions,26 IDs,6242 assertion passes/0 failures/10 N/A,221.174s; local raw tapes lost |
| Windows `45460161994` | Artificial Python fixture CRLF expected-hash mistake stopped the lane before gameplay; retained artifact14952576748 |
| Windows `45461118405` | Unit, adapter, controller and both ordinary Workbench baselines pass; CONTROL stops before Save on native body-copy protection; retained artifact14951654742, no evaluator uploaded |
| `adapter-006-diagnostic` | Recovered summary:784 checks/52 records pass; body-protection receipts and authored Save/Reopen observed. Later retained Windows adapter evidence independently covers this repair. |
| `replay-5199-*` | Recovered summary:two selected tapes refused before dispatch by a JSON integral-number enumeration bug; corrected in both validators and26-action roundtrip controls; no replay pass attributed |
| `material-motion-c001` | Recovered summary:native motion passes, but the test called material58 Wood; it was Wall. Fixture corrected; retained Windows evidence distinguishes these materials. |
| `material-motion-c002` | Recovered summary:corrected Wood7 cup,89 checks/10 operations pass in7.800s. Fresh retained1649 execution independently repeats the Sand/Wood regression. |
| Current negative/unit controls | 173 Godot assertion/transcript checks,153 policy checks and23 Python evidence/reducer/package checks; explicitly artificial controls |
| Published `89a90e34` matched12 and replay | All12 campaigns reached64 attempts;767/768 operations completed,26 IDs,7393 assertion passes/0 failures/10 not applicable. CONTROL and CURIOSITY semantic replays passed; raw timing observations differed. See evidence-retention qualification below. |
| Windows `45466167235` | Source unit/adapter/controller/gameplay/baseline, CONTROL64, BUILDER128 and CONTROL replay pass; extracted actor/save CONTROL64 cases pass. Graphical BUILDER24 completes, but UI replay identity, canvas-size fixture and hosted audio diagnostics block evaluator publication; artifact14953994370 preserves raw evidence. |
| UI repair lifecycle control | 53 actual Godot lifecycle checks pass with a positive in-memory replay and retained wrong-hash refusal; source89a90e34 plus recorded local delta. |
| Regenerated `1649f086` matched12 | All12 selected campaigns pass:768 attempts/767 completions,26 IDs,7393 assertion passes/0 failures/10 not applicable;247.233s plus10.912s shared import. One additional CURIOSITY605 attempt retained41 actions before shared-disk exhaustion stopped evidence export; its fresh-profile retry passes. |
| `1649f086` replay and positive controls | CONTROL64 and CURIOSITY64 replay semantically,25.330s/20.389s; exact asynchronous observations differ. Wood/Sand89-check regression,173 contract and153 policy controls,6-action positive reproduction and passing-tape reducer N/A all pass. |
| Windows `45469647752` | Source tests and extracted campaigns pass; actual graphical25-check test and 24-action UI replay pass at1600×900, with full panel containment. Final byte custody rejects a rewritten Rapier SVG import descriptor; artifact14958115957 retained, no evaluator uploaded. |
| Packaging repair controls | 23 Python tests pass. Only the four Rapier import descriptors named by the existing Windows runner are canonicalized CRLF→LF before package hashes; original/archive and packaged hashes are retained. Post-extraction and post-test hashes remain strict for every payload member. |
| Four retained128-action Linux cases | CONTROL/material_playground, WANDERER/actor_workshop, BUILDER/liquid_channel and TINKERER/save_reopen each complete128/128 with no assertion failures; details below |
| Retained256-action attempts | CURIOSITY a01 ends with unattributed SIGKILL after220 completed actions and a pending brush; RANDOM a01 ends with SIGKILL before a fixed tape. Separate CURIOSITY a02 completes256/256 with2888 assertion passes,3 N/A,139.336s. No matched256 comparison is qualified. |
| Goblin-disabled ordinary baselines | Existing Workbench deferred-paint49 checks and input26 checks pass on the frozen1649 application source |
| Final Windows `45474099351` | Source tests, source campaigns/replay, both extracted CONTROL64 cases, graphical25 checks and 24-action UI replay, and final strict payload verification pass. Qualified evaluator14958249728 and evidence14959436637 uploaded. |

### Matched behavior comparison on published game source

The retained replacement matrix uses clean application source
`1649f086a5795d88d03d19fd161ad549365a3fc4`, construction fixture version1,
seeds13/605,64 actions per seed, one native worker, zero intentional pacing and
fresh profiles. Its actual game-input snapshot is
`e5cea9cde499ad1995fc658fddac32e32a75586b30eb87146dbed22cb7b15196`.
The later package-only correction does not change these Godot/native sources;
its Windows package carries its own exact source and runtime identities.

| Policy | Completed/attempted | Distinct completed IDs | Native edit receipts | Actor drives | Reopens | Process seconds |
| --- | --- | --- | --- | --- | --- | --- |
| CONTROL |128/128|23|28|4|4|48.168|
| WANDERER |128/128|10|30|10|0|37.744|
| BUILDER |128/128|7|48|0|0|30.895|
| TINKERER |128/128|14|32|0|8|47.927|
| CURIOSITY |128/128|22|49|0|2|40.125|
| RANDOM |127/128|17|66|0|0|42.374|

These are observations from two seeds, not a defect-finding ranking. WANDERER
maintains visits and breadcrumbs while delivering actual pilot input. BUILDER
keeps several actions together to construct Wall cups with Wood ledges and Sand,
observe Play, and erase a central opening. TINKERER completes eight save/reopen
cycles across the two runs. CURIOSITY inspects an actually selected passive barrel
through Details without treating it as a pilotable actor. RANDOM produces more
edit receipts here but no actor-driving or sustained Play intervals. Its one
Fill refusal occurs before edit admission because the captured selection does
not wholly contain the component. That is recorded as not applicable.

Independent review links these interpretations to complete raw tapes, native
capture/receipt IDs, sampled actor commands and neutral release, actual panel
states, and native Undo/Redo readback. A selected passing matrix does not erase
the separately retained storage interruption or other failed attempts.

### Longer native campaigns and interruption accounting

These cases use the same frozen Linux source and runtime, seed 605, one native
worker, fresh isolated profiles and unchanged test deadlines.

| Policy and fixture | Completed actions | Distinct completed IDs | Assertion pass / N/A / fail | Process seconds |
| --- | --- | --- | --- | --- |
| CONTROL / material_playground |128/128|23|1660 / 3 / 0|50.148|
| WANDERER / actor_workshop |128/128|9|2999 / 0 / 0|58.379|
| BUILDER / liquid_channel |128/128|8|1457 / 0 / 0|31.895|
| TINKERER / save_reopen |128/128|15|1800 / 8 / 0|50.372|
| CURIOSITY / construction, separate a02 |256/256|25|2888 / 3 / 0|139.336|

WANDERER delivered ordinary Kestrel input and neutral release, with independently
observed torque/rotation response. This is not proof of horizontal traversal or
pathfinding. BUILDER's 128 actions include 48 native edit receipts and 288 native
ticks across its primary completed simulation intervals. TINKERER completes eight
authored Save/Reopen cycles; unavailable body-covered material captures remain N/A.

The original CURIOSITY 256 a01 ended with signal 9 after 95.695s, retaining 220
completed actions, 2518 passing assertions, 3 N/A and an admitted pending brush at
index 220. RANDOM 256 a01 ended with signal 9 after 22.021s and retained only startup
output, without a fixed transcript or completed gameplay count. Neither kill has
an established cause; they are not proven game crashes, timeouts or assertion
failures. Their original outputs remain unchanged.

The separate CURIOSITY 256 a02 uses the same fixture, seed, source and runtime.
All 220 retained action IDs/arguments and semantic fingerprints match its prefix;
the previously pending brush has a genuine completed native receipt. Its measured
child peak RSS is 576708 KiB, approximately 563.2 MiB. This is a process observation,
not a performance guarantee. RANDOM 256 remains incomplete, so the 256-action
matched policy comparison remains unqualified.

### Qualified Windows package and independent review

[Run45474099351](https://github.com/techrote/cybersand/actions/runs/45474099351)
qualifies exact source `3e3aa217b49036ac4a87dd57073ad2cbb5a314c8`, tree
`3ee2a02e13cde1a1a4ff67321cb7c3d6f9bd1e37`. There are no differences under
`godot/` or `native/` from the separately qualified Linux source 1649f086.
The successor changes only the focused package helpers, their unit fixture,
qualification request and this guide.

The immutable inner `CyberSand-goblin.zip` is 92958820 bytes, SHA-256
`4ced405c47f4c0493166728ccb692ba33e822f1e5c9f63dacf73db47664d5c79`.
The final Windows evidence ZIP is 53552174 bytes, SHA-256
`c7ff1cda1e08750cd884d5b33dc324b7329594394a8d1569d4527479ace51952`.
The extracted manifest hash is
`15577c842309446c304aa14751badb60dcf63d83e4ca84a5d029f8feb16d15b1`;
the successful extracted-package report hash is
`ef44883de844cca25cfa300a6adcf87d2c6c81b3b2e2f2b72836fc884765c2dd`.
The external qualification report binds those exact unchanged package bytes.
The manifest's build-time candidate wording is not edited after qualification.

Both extracted CONTROL64 campaigns complete 64 operations: actor_workshop in
25.396s and save_reopen in 24.985s. The actual hosted graphical test passes 25
checks, including full developer-panel containment in 1600×900. Its24-action
BUILDER campaign and 24-action UI replay each pass 180 assertions. Semantic fields
match; exact asynchronous observations differ. The recorded renderer is ANGLE
on Microsoft Basic Render Driver, using gl_compatibility.

The lead and a specialist independently hash all 1162 declared payload members,
check exact source/manifest/report bindings, verify all four permitted import
descriptor receipts, inspect raw campaign tapes and view the actual PNG. The
final raw hashes remain byte-exact after extraction and execution. The four
earlier failed Windows archives remain retained alongside the successful one.
The independent consolidated ledger classifies natural gameplay findings,
harness repairs, artificial controls and execution-host failures separately.
There are no verified ordinary production gameplay defects and no claimed
minimized failing gameplay fixture; the positive regression and reducer controls
are still useful, independently checked tests.

Windows Godot SHA-256:
`b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8`;
native `668f2dd094fca611a97c2b6aa38c4cd072179fe9cf591e53578ef57c7db1625e`;
Rapier `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.
The Windows project-input snapshot is
`bf68522aafcdcfc0c6f25669838970b15a22bc8b5bb8dbc34e4b748b185f3abe`.

### Execution-host restart and evidence retention

The execution host restarted during the first planned128-action Linux campaign.
Its temporary home-backed worktree, raw Linux campaigns and audit files did not
survive. Published commits, the original PR749 archive, earlier disk-backed
attempts, and all hosted Windows artifacts remain intact. Recovered tool-output
summaries retain the known previous outcomes, but are explicitly metadata-only;
they are not replacement raw transcripts. The earlier local entries above must
be read with this limitation, even where their contemporaneous notes said
originals were retained. The interrupted128-action case has no completion claim.
New qualification is written to the surviving conversation workspace, with fresh
profiles and distinct attempt identities. The Windows artifacts retain their
uploaded raw logs, transcripts, captures and qualification reports independently
of that host restart.

The Linux engine executable SHA-256 is
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`;
native `a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7`;
Rapier `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.
The retained native build source is `c53fd6f9d3d0f2b3f39396c7e605654f65c17299`;
105 native and4 Rapier source inputs match accepted main and this GDScript-only
candidate. Development runs above explicitly record dirty-source snapshots and
their full hash maps; they are not mislabeled as clean-commit qualification.

The focused Windows workflow runs only on an explicit branch qualification-request
change or manual dispatch. It uses the existing GitHub-hosted `windows-2022`,
pinned Godot archive, retained Windows libraries, official notices and the existing
licensed VC-runtime staging helper. Package creation is unqualified. Upload of a
developer evaluator requires source tests, replay, both extracted CONTROL64
actor/save cases, independent evidence readback and the actual ANGLE developer UI
test. A failure retains evidence and prevents evaluator upload. Hosted rendering
and process-frame timings cannot establish owner acceptance on physical NVIDIA
hardware. No Ready, merge, production enablement or general CI-policy change is
part of this lane.

Pure policy/contract tests join the existing automatic `godot/tests/test_*.gd`
discovery. Real adapter/controller/interactive tests live in `godot/goblin/tests`
and require the isolated launcher. The existing Workbench deferred-paint and input
tests form the focused goblin-disabled baseline. Documentation checks use the
recovered companion-workspace source checkpoint; the original missing-companion
failure remains in the attempted-results ledger.
