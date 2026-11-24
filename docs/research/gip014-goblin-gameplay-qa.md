---
title: GIP-014 goblin in-game gameplay QA
status: Planned
document-kind: research
scope: Branch-scoped developer-only real Godot gameplay tests; Draft/HOLD
canonical-for: [gip014-goblin-gameplay-qa]
last-reviewed: 2026-11-24
related-documents: [../operations/local-build-and-validation.md, ../operations/github-development-and-release.md]
---

# GIP-014 goblin gameplay QA — Draft/HOLD

This candidate starts from accepted main `00cdb02f103265b6dc5224c68283e9a0c8cb449f`.
It owns only an opt-in developer scene, bounded in-game action adapters, disposable
fixtures, policies, evidence readers and focused documentation. It does not change
ordinary Workbench startup or production gameplay. No Ready promotion or merge is
authorized. The branch now implements a real in-process Godot controller and has
passed native Linux development runs. The matched campaign and Windows evaluator
qualification below remain explicit, separate gates.

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

The interactive scene uses ordinary Godot controls for fixture, personality, signed
32-bit seed, action budget (1–256), pacing (0–3000 ms), Start, Pause and Stop. It
shows the current goal, proposed action, completed/attempted counts, actual native
generation/revision/tick, actor tick and recent outcomes. The green goblin pointer
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
asserted only when the saved native tick is zero; otherwise that particular check
is explicitly not applicable while authored identity is still checked.

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
| BUILDER | Build small Wood-supported Sand cups, watch them, remove a ledge and occasionally add a barrel |
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
| `control-dev-002` | Import process killed with signal9; cause not established, no game defect claimed |
| `adapter-003` | 310 checks/35 records pass; genuine actor lease/input and pending native cancellation observed |
| `adapter-004` | 26-action implementation passes; actor placement/pilot/reset/single-step added |
| `adapter-005` | 723 checks,49 retained action records,50 real API admissions,23.040s; native and pre-native cancellations distinguished |
| `control-dev-003` | Actual Linux CONTROL64:64 completed,17 feature IDs,381 passing assertions,1 not applicable,22.521s; independent Python readback agrees |
| `controller-b001` | Two lifecycle-test failures concerning pre-native cancellation evidence; harness corrected, originals retained |
| `controller-b002` | Lifecycle execution passes,17.353s; pause/resume, Stop, pending admission, profile isolation, fixed archives and mismatched replay refusal |
| Unit controls | Deliberately inconsistent fixtures test wrong cells, stale source, missing/queued receipts, missing input, malformed transcripts and reducer behavior; never reported as discovered defects |
| Local graphical display | Display-server sockets denied by this host; graphical test not run locally |
| Matched policy, longer campaigns, final replay, Windows evaluator | Pending the following committed qualification checkpoint |

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
