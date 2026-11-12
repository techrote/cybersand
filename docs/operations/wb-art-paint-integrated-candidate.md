---
title: Integrated PAINT and agent Shared Workbench candidate
status: Current
document-kind: runbook
scope: Unmerged Draft candidate, generator packaging repair, native stored-material receipts, ordered human and agent authoring with shared Undo/Redo, reproducible qualification and owner acceptance
canonical-for: [integrated-paint-agent-workbench]
last-reviewed: 2026-11-12
related-documents: [../systems/paint-editor-bounded-shapes.md, ../systems/workbench-direct-art-batches.md, ../systems/workbench-art-providers.md, ../systems/explore001-generated-playable-maps.md, ../architecture/shared-workbench-authoring-data.md]
---

# Integrated PAINT and agent Shared Workbench

**Current unmerged candidate; keep Draft.** This work preserves both original
implementations and their Git ancestry. It does not authorize Ready, merging,
auto-merge, material-default changes or GEN-008 Flatten.

## Shared agent and manual Undo/Redo — current implementation

The current local integration adds native-confirmed agent edits to PAINT's
chronological Undo/Redo timeline. **These new history changes are not yet
qualified by the previous hosted campaigns or Windows package.** Keep their
source and results separate from the completed `d33c10e4` checkpoint below.

Both the PAINT controls and the new **Art batches** Undo/Redo buttons act on the
most recent edit. Adjacent bounded parts of one direct batch or model drawing
submission form one history action. A human edit between agent chunks closes
that group and remains a separate entry; Undo cannot skip later human work.
After Stop, wait for the executor, deferred human edits, native result recording,
image capture, provider and scheduled turns to settle. Undo then targets the
confirmed prefix; the cancelled suffix has no history entry. Redo follows the
same serialized native path.

Native stored before/after materials and generation/revision/tick fences govern
history. Recorded agent changes advance that fence; no-change agent receipts
preserve Undo and Redo. Simulation, World replacement and mutations outside this
recorded timeline still invalidate unsafe history. Undo uses the trusted human
PAINT path and expected-source preflight; ordinary agent material, source,
scope and protected-region policies remain unchanged. History completion adds
a human conversation result and durable traffic event without rewriting old
model receipts or automatically sending a new model request.

The existing history limits remain **32 parts / 1,048,576 cells**, with at most
262,144 cells per part. If eviction removes an older part of a drawing, its
retained tail is visibly labelled and the lost undo coverage is reported.
Undo/Redo also retains the existing **32,768-stamp / 1 MiB** authored-start
limits. An agent can stream a highly fragmented result that Save refuses;
history replay can refuse an intermediate target recipe before that part writes,
even if the eventual group baseline would fit. Confirmed progress and refusal
remain explicit. This is bounded construction history, not an unlimited or
atomic rollback, physics rewind or a new persistence format. Saved starts
retain the resulting authored layout; the Undo/Redo stacks are session-local.

The [local history regression record](../audits/wb-art-paint-2026-11-12/agent-undo-local-tests.json)
contains **1,002 passing checks**: 260 focused native history checks, 192 combined
512² authoring checks and 49 fresh-process reopen checks at each of one and four
workers. The focused test includes a 262,656-cell drawing on a 1024² World,
same-batch grouping, Stop during planning and between confirmed history parts,
no delayed writes, no-op/Redo preservation and exact native material comparisons.
The [related local regressions](../audits/wb-art-paint-2026-11-12/agent-undo-local-related.json)
passed 4,707 directly counted checks plus 105 headless HTTP provider checks.
These are Linux headless diagnostic results with the documented GCC 14.2 /
binutils 2.44 runtime, not Windows or pinned hosted qualification. Original
fixture failures remain beside the records; subsequent hosted results must name
their own exact source and source-built runtime.

## Previous qualified package — d33c10e4, before agent Undo

Source `d33c10e41cafcaa809ef410d0760e2c15bd02247`, tree
`edac38d80744aa87a516966309c1fc8116848588`, completed the packaging repair and
its source-matched qualification. It **does not contain the new agent Undo/Redo**.

[Download that previous Windows x64 candidate](https://github.com/techrote/cybersand/actions/runs/43310701318/artifacts/13989111394):
run **43310701318**, attempt **1**, artifact **13989111394**, **92,904,178 bytes**.
ZIP SHA-256:
`04955d872997cf50edfbe1fb7de3ca4d21a6fa5302eb99627dd72ebd8239e7eb`.
Actions retains it until **2027-02-10**. Independent inspection verified all
886 manifest-listed payload files, all 87 native source input hashes, both sets
of 16 generator profiles and the previously missing Rapier lock and patch.

The [dedicated campaign](https://github.com/techrote/cybersand/actions/runs/43310701318)
passed all three jobs and 7,358 directly counted assertions on each platform,
plus five package contract tests on each. The Windows process-module receipt
confirmed that the copied Godot GUI loaded the bundled VC runtime, CyberSand
extension and Rapier from the same copied installation with manifest-matching
hashes. The Microsoft runtime was version 14.44.35211.0 with valid Authenticode;
both licence documents and its redistribution provenance are included.
[Windows evidence](https://github.com/techrote/cybersand/actions/runs/43310701318/artifacts/13988831813)
and [Linux evidence](https://github.com/techrote/cybersand/actions/runs/43310701318/artifacts/13988615289)
retain the native author/reopen digests, receipts, original logs and frames.

The [Native campaign](https://github.com/techrote/cybersand/actions/runs/43310701227)
passed all eight executing jobs, including all six runtime families and their
aggregate. The [Godot campaign](https://github.com/techrote/cybersand/actions/runs/43310701720)
passed all 50 executing jobs, with 298 Linux and 277 applicable Windows headless
cases. All three campaigns completed on attempt 1. Administrative Ready checks
and the optional physical-actor stress job were skipped, not passed. These
results close the earlier standalone packaging defect; retained-runtime
publication, materialized provenance, the separate Palette gate and owner
acceptance remain separate merge requirements.

## Earlier application checkpoint and standalone packaging defect — 0025bd94

The earlier qualified application checkpoint is
`0025bd942850e6e75e77d4beb9c4885d7dc1b2f4`, tree
`6fff8a8c833eb65f4297d6fd07ef9f5edf336c0d`. A subsequent packaging repair preserves the application implementation. The complete #544 and #560 heads and accepted main
`d8588716becb0dc42019faf23f721378d8adc84a` remain ancestors. Neither original PR
has been closed, and no Ready, auto-merge or merge action has been taken.

**Historical package HOLD, resolved by the d33c10e4 replacement above.** Independent
inspection of the 0025bd94 Windows archive found that Rapier imports
`VCRUNTIME140.dll`, but the archive omitted it; the hosted machine supplied it.
The referenced Rapier build lock and cooperative-BVH patch were also omitted.
Artifact 13984970914 is retained as failure evidence and must not be treated as
the final standalone candidate. Its ZIP SHA-256 is
`87503652ced5b83aa106b7377f13e0b4130b776dc7d960d9612601223eca3ffe`.

The targeted repair stages the unmodified, signed x64 Visual Studio 2022 release
redistributable beside Godot, with Microsoft runtime and redistribution licences,
file version/hash, signer and build-host provenance. Both referenced Rapier files
are included. The installed suite runs the executable in each copied installation;
a separate Windows process-module check requires the actual Godot process to load
the bundled runtime, native extension and Rapier from that copied installation.
Publication is gated on those checks and the complete dedicated campaign. They
passed for the d33c10e4 package above. Consult
[PR #564](https://github.com/techrote/cybersand/pull/564) for the current source
and the separate qualification of subsequent history changes.

The package's `candidate-manifest.json` and `source-built-candidate-provenance.json`
identify its exact source and native inputs; `vc-runtime-provenance.json` identifies
the Microsoft bytes and licences. To reproduce a recorded package, retain that
runtime stage (the three named payload files plus its provenance) and pass it as
`--vc-runtime` to the packager, alongside the pinned Godot and source-built native
inputs. Staging from a newer hosted VS image may deliberately select a newer
signed release runtime and produces a different recorded runtime hash.

The [0025bd94 dedicated campaign](https://github.com/techrote/cybersand/actions/runs/43301146659)
passed all three jobs: pinned Windows build, actual Linux X11 execution and
actual Windows ANGLE execution in fresh standalone layouts. **Each platform
passed 7,358 directly counted assertions:** 521 installed, 6,729 regression and
108 provider HTTP assertions. Imports, duplicate completion markers and the
HTTP wrapper do not inflate that total. HTTP error/cancel/timeout controls also
passed but expose no numeric assertion count and are not added to it.

| Combined workflow, on each platform | Native workers | Author / fresh-reopen checks |
| --- | --- | --- |
| Installed 1024² map, including a 147,456-cell Fill | 1 and 4 | 170 / 41 at each setting |
| Source-layout 512² map | 1 and 4 | 151 / 38 at each setting |

All eight author/reopen pairs across both platforms reproduced the complete
authored stored-material digest, actor/equipment configuration and settings,
then continued editing. Equipment and real simulation were exercised before
Save. Windows installed Stop prefixes were **3,840** and **3,584** cells;
Linux recorded **4,096** at each worker setting. Each receipt and saved/reopened
pair matches its actual prefix; identical time-budget cutoffs across hosts are
not assumed. Each platform retains **57 original PNGs**, alongside native
receipts, saved fixtures and source identities. The agent HTTP fixtures use
OpenAI, NVIDIA and LM Studio transports with deterministic loopback responses,
including real canvas images. No live-model inference is claimed.

[Windows detailed results](../audits/wb-art-paint-2026-11-12/final-windows-installed-qualification.json)
and [Linux detailed results](../audits/wb-art-paint-2026-11-12/final-linux-installed-qualification.json)
retain the exact digests, runtime hashes, phase checks, observed worker samples,
nozzle emissions and provider counts. Original artifact evidence is available
for [Windows](https://github.com/techrote/cybersand/actions/runs/43301146659/artifacts/13984337537)
and [Linux](https://github.com/techrote/cybersand/actions/runs/43301146659/artifacts/13982483474).

The [0025bd94 Native campaign](https://github.com/techrote/cybersand/actions/runs/43301146658)
passed all six runtime families and the aggregate on this exact source: 192
cases in each of normal, ASan/UBSan and TSan, plus the generator and soliding
normal/sanitized families. The eight executing jobs passed; the administrative
Ready classifier was skipped. Existing ASan settings disable leak detection;
this is not a LeakSanitizer qualification. The [retained Native record](../audits/wb-art-paint-2026-11-12/final-native-qualification.json)
keeps case, binary-invocation and assertion measures separate.

The [0025bd94 Godot campaign](https://github.com/techrote/cybersand/actions/runs/43301147487)
passed all 50 executing jobs without retries: **298/298 Linux cases** across 22
shards and **277/277 applicable Windows headless cases** across 21 shards.
All 21 rendered-pixel cases excluded from that Windows headless matrix passed
on Linux. Dedicated Windows graphical Workbench qualification is a separate
campaign. The Ready classifier and optional physical-actor stress campaign were
skipped, not passed. Both platforms passed the unchanged 179-assertion pilot UI
fixture, the unchanged live-liquid fixture and the repaired 112-check liquid-edge
fixture at 512²/2048². The [retained Godot record](../audits/wb-art-paint-2026-11-12/final-godot-qualification.json)
includes exact coverage receipts, source inputs, artifact hashes and exclusions.

The original full Godot attempt on `dc3aaac3` failed and remains preserved. It
exposed the overwritten acknowledgement and obsolete liquid-edge fixture; one
Linux shard also failed on a TLS download before running any tests. The final
campaign executes those cases successfully. Superseded and Draft-skipped runs
are never substituted for the final-source results.

## Final hardening and evaluation — 2026-11-12

The final review continues the existing #564 candidate, with #544, #560 and
accepted main `d8588716` preserved in ancestry. The earlier `0e73e926` package
and its passing campaign below remain historical evidence; they do not contain
these additional repairs:

- Save refuses queued/executing ordinary brush, PAINT and agent operations,
  unconsumed native receipts and an extracted World transition. A refusal leaves
  the previous named file unchanged and does not consume an agent receipt.
  Ordinary brush input also respects PAINT's partial-edit recovery hold.
- Cancel retires a Fill continuation even when its native capture has already
  completed. Confirmed edit prefixes still follow the existing recovery path.
- Adaptive Fill retains the observed connected component and its known boundary
  when expanding a capture. Disconnected margins no longer exhaust the capture
  budget before a large watertight pocket is enclosed. The 262,144-cell limits,
  source fences and refusal of incomplete fills remain unchanged.
- A requested World replacement stops old agent work immediately, but retires
  its authored record only when the new World is installed. Native preparation
  refusal therefore leaves the old confirmed prefix available for Save.
- The installation refresh updates PAINT before publishing the final shared
  acknowledgement. Actor placement/reset and liquid-conversion accounting now
  remain visible instead of being overwritten by PAINT's brush status. The full
  Godot campaign exposed this defect; the unchanged pilot and live-liquid
  fixtures reproduce it and pass after the ordering correction.

The installed qualification now uses a real **1024²** generated map at one and
four native workers, while source-layout cases retain the smaller **512²**
map. The larger case includes a **147,456-cell** watertight Fill and complete
stored-material comparison of the authored baseline. The combined session then
exercises physical equipment and simulation before Save, exits Godot, reopens
the authored start in a fresh process and continues editing. Evolved simulation
state is intentionally not the saved object. Fragmented-save negative cases
check the exact previous file bytes after refusal.

The existing Native and GDExtension workflows also run on source pushes to this
integration branch, without changing Draft state or weakening their gates. The
dedicated installed campaign supports manual reruns and keeps their evidence
separate. [PR #564](https://github.com/techrote/cybersand/pull/564) records the
actual final source, completed runs and remaining gates; a configured test is
not a claimed pass.

[Retained local qualification and original failures](../audits/wb-art-paint-2026-11-12/local-qualification.json)
record the demonstrated defects, exact source/runtime hashes and focused Linux
results. The local 1024² author/reopen pair passed 165/39 checks with an identical
authored native digest. These headless results do not replace hosted graphics,
Windows, four-worker or complete release-suite evidence.

The subsequent full Godot suite found the installation-status overwrite and an
obsolete liquid-edge UI fixture. [Acknowledgement regression evidence](../audits/wb-art-paint-2026-11-12/status-acknowledgement-local-results.json)
retains the unmodified pilot and live-liquid tests after the production fix.
The liquid-edge fixture now supplies global pointer events, chooses materials
by native ID and waits for PAINT receipts while comparing exact native brush
cells. Its original halo, conversion and physical-owner assertions remain.

### Evaluate the delivered package

Extract the complete standalone Windows archive into a fresh folder, then
double-click **Open Workbench.cmd**. No Git checkout or development-machine
paths are required. The first launch imports the packaged project. Its
`candidate-manifest.json` identifies the exact application commit/tree and
payload hashes; the delivered native DLL has its own candidate provenance.
This runbook is included as `READ-ME.md`.

- Open **New from generator…**, choose a populated profile and install a map.
- Pause; use Brush/Eraser, Line, Rectangle/Outline and several native materials.
- Fill a closed pocket; Select, Copy/Paste, then Undo/Redo.
- Open **Art batches**, draw inside a bounded area, alternate with human edits,
  and Stop a longer operation. Confirm that further editing still works.
- Run and pause simulation; interact with the existing physical equipment.
- Save a named start, exit Godot completely, launch again and Load that name.
  Check both editors' authored materials, actor/equipment configuration and
  settings, then continue editing. Expect the authored start, not a physics
  checkpoint of the evolved world.

The retained repository runtimes still have four native-source mismatches per
platform: `cyber_demo_bridge.hpp`, `cyber_native_cell_world.cpp/.hpp` and
`cyber_prepared_liquid_world.hpp`. The separate source-built evaluation package
does not promote those tracked binaries or rewrite their historical manifests.
Tracked-runtime publication and the full materialized-provenance gate remain
explicit merge requirements, alongside owner desktop acceptance. Keep Draft.

## Source and ownership

The live sources inspected before editing were:

| Source | Exact inspected commit |
| --- | --- |
| Accepted main at initial inspection, including #542 | `d4b18e7f06839b35c8f6a66195206da0f33c5fa3` |
| Accepted main advanced during qualification, including #553 | `d8588716becb0dc42019faf23f721378d8adc84a` |
| Agent PR #560, initial repair baseline | `e5bf2916ccdbb331690e5f5eef0cdef9cc734089` |
| Agent PR #560, final live reread and preserved merge | `381307eb988dc25f36716d8308d47e210fdd3b4e` |
| PAINT PR #544 | `c9b5084e0276f0b5036d02db835973f04bb6f51f` |

PAINT advanced beyond the older `7c2f3d55` inspection checkpoint. The current
head includes its large-Fill and authored-capacity corrections. Those commits,
editor modules, overlays, tests and evidence are preserved. During qualification,
#560 advanced by three documentation, benchmark and graphical-test commits. The
latest head `381307eb` was incorporated through another ordinary merge. Its
application and native implementation bytes are unchanged; its graphical
multi-turn, Stop and protected-area regression is also run on the combined tree.

The [repair branch](https://github.com/techrote/cybersand/tree/codex/wb-art-repair-20261111)
first isolates generator packaging and native/deferred-stroke repairs on #560.
Its published generator checkpoint is `19563be7d206dbe59a3d32dc613f6464ae6c898d`;
the readback checkpoint is `df1649a11e77bfdf95946f5c997a35b74af358bf`.
The [integration branch](https://github.com/techrote/cybersand/tree/codex/wb-art-paint-integrated-20261111)
starts from accepted main and incorporates the complete PAINT and repaired agent
histories. Accepted main then advanced to `d8588716` through #553. A further
ordinary merge preserves its liquid-equipment owner, Setup-v2 equipment block,
reservoir starts, overlays and capped Details panel. The current candidate must
qualify that combined source; earlier application-test passes remain attributed
to their earlier checkpoints. Neither original PR is replaced or closed.

## Generator discovery and standalone installation

The original dialog enumerated only the checkout-relative sibling
`res://../examples/worldgen`. A standalone folder without that sibling produced
an empty dropdown without a useful recovery explanation. The owner's original
installed folder was unavailable for inspection, so that exact folder diagnosis
is not asserted. The failure is reproduced by a fresh non-Git missing-directory
fixture and covered independently from dialog construction.

The accepted packager now copies every canonical `examples/worldgen/*.json`
byte-for-byte into `godot/authoring/worldgen`, retaining the original sibling too.
It requires the supported GEN-007 recipes and records the inventory and hashes.
The existing dialog prefers the packaged resource directory, falls back to the
checkout sibling, checks readability and deduplicates names. Missing profiles
disable Preview and explain searched paths, complete-package reinstall and
**Choose profile file…**. The chooser and saved embedded recipes remain usable.

The installed test checks the actual recipe count against the package manifest,
selects Deepworks, runs native generation, installs the map, paints, saves, exits
Godot and reconstructs the result in a new process. Resource-only and missing-both
layouts are separate fixtures. No Git working directory supplies hidden recipes.

## Native authority and shared ordering

There is one native World and one simulation worker. Native C++ exposes the small
read-only `stored_material_at(x,y)` binding to existing `World::stored_material`.
`World::get`, physics, material IDs and defaults are unchanged. Both authoring
executors require this source-matched API; an old library fails before mutation.

Stored identity does not grant access through a transient body. Both interfaces
check `rigid_body_id_at` explicitly. Agent source eligibility remains Empty/Hard
Wall; destination materials remain bounded by the human's existing allowed
palette, scope and protected rectangles. Human PAINT retains the native supported
material palette and its complete operation preflight, selection, Fill and
history policy. Agent drawing never inherits PAINT's wider permissions.

The worker's mutation slot remains occupied while either interface has a pending
command, executing work or an unconsumed native result. Extracted legacy brush
commands also retain an in-flight marker until native execution and source-fence
publication finish. Reset/replacement/settings fences remain in both interfaces.
Art completion atomically publishes the current PAINT generation/revision/tick.
The accepted equipment owner remains on that same worker; its cell writes run
only before unpaused simulation ticks. Equipment command admission rejects
requests during extracted World transitions and pending resets, closing that
admission gap. Commands associated with the previous World retain #553's existing
replacement/reset semantics. No equipment command is exposed to the agent interface.

At the controller boundary, agent work waits while PAINT plans, consumes its
receipt and records history. If transient contention follows rasterization, the
same agent chunk is retained until admission; advancing the cursor cannot discard
the chunk. Deferred human brush gestures retain their original radius and use
PAINT's existing planner/native/history path. Every accepted gesture receives
confirmed completion, a partial native prefix or explicit refusal/cancellation.
Only after its authored record is settled can the next agent chunk proceed.

In the current history implementation, confirmed agent changes enter the same
timeline as manual edits and advance its source fence. Outside changes still
invalidate unsafe history; an agent no-op preserves valid Undo and Redo. One
history action traverses adjacent retained parts of a submission, and human
interleaving remains a separate entry. A PAINT recovery hold also blocks agent
drawing. Queue admission is never displayed as native-applied success. Stop
retains completed-prefix accounting; stale provider replies cannot enter a
replacement World. Both panels require the agent/provider run to settle before
history replay, and no new drawing is admitted while replay owns the edit path.

## Preserved interfaces and persistence

PAINT keeps freehand Brush/Eraser, Line, filled/outline Rectangle, all supported
materials, native Copy/Paste, bounded connected Fill, material-aware previews,
selection overlay, paused Undo/Redo, cancellation and partial-result recovery.
Its current 32,768 authored-rectangle/stamp capacity is retained; the ordinary
MicroScenario limit remains separate. Source geometry and execution budgets are
unchanged by reconciliation.

The agent panel keeps ordered direct batches, OpenAI Responses, NVIDIA and
LM Studio, configurable endpoints/models, conversation/context modes, scanlines,
raw/readable traffic, image observations, multiple turns, revision instructions,
Human Stop and recoverable errors. Its Undo/Redo buttons use the shared editor
timeline described above. Native receipts include actual stored
before/after identities and changed/unchanged/excluded/refused counts.

Both interfaces append to the same existing Setup-v2/generated-start document.
Save waits for outstanding authoring receipts. Generated terrain, ordered mixed
materials, actor spawns and supported settings reconstruct through existing
facilities. The optional equipment block accepted in #553 is retained through
the same Setup-v2 validation and persistence path. Equipment buttons coexist with
PAINT; paused Paint mode retains its G/V/bracket shortcuts, while the main Select
body tool makes the equipment shortcuts available. This saves the authored start;
it does not checkpoint evolved physics or provide a new agent save format or
Flatten implementation.

## Qualification and reproducibility

The branch workflow `wb-art-paint-qualification.yml` builds the exact selected
source on hosted Ubuntu 24.04, builds Windows through pinned LLVM-MinGW, and runs
the resulting Windows package graphically on Windows 2022. Both use official
Godot 4.7 and pinned godot-cpp/Rapier. The package manifest binds the source commit,
tree, native inputs, DLL hash and recipe inventory. Retained provenance describing
an older committed library is not presented as the rebuilt library's identity.

The generator-only repair checkpoint passed [hosted run 43115786475](https://github.com/techrote/cybersand/actions/runs/43115786475)
on both Linux X11 and Windows ANGLE. Its installed graphical author/reopen runs
completed 20/21 checks, alongside actual-profile, resource-only and missing-layout
checks. These results qualify that repair checkpoint, not the later combined tree.

Local combined focused tests use official Godot `4.7.stable.official.5b4e0cb0f`
and a new library containing all 87 recorded native input hashes, including PAINT
capacity and stored readback. Its Linux SHA-256 is
`16ffc0ce8190c2e8ca2e31fc59f10c55148adc6e7f16727dc96c094d8a96696a`.
This local development build uses GCC 14.2/binutils 2.44 with the explicit
toolchain-drift switch; it is separate from hosted pinned-release qualification.
Before the subsequent accepted-main equipment merge, focused results were:
shared ordering 86/0, stored-material/body-mask 88/0, direct
PAINT executor 21/0, mounted PAINT native 109/0 at each of one and four workers.
The remaining 15 original affected native/application runs completed 4,653
checks with zero failures. Combined author/reopen completed 122/32 checks at
each worker count, discovering 16 real profiles and reproducing the same saved
stored-material digest in each fresh process. The six-path deferred-human
completion test completed 37 checks with zero failures. These are local Linux
headless results; graphical execution is recorded separately by the workflow.
The [local qualification record](../audits/wb-art-paint-2026-11-11/qualification.json)
binds the original logs, source-input manifest, final results and retained fixture
failures by SHA-256. It contains no model credentials or genuine inference claim.

The combined workflow also runs both accepted regression families and
`test_workbench_combined_authoring.gd` in installed and checkout layouts. Each
one/four-worker author run is followed by a new-process reopen. The test covers
native generation, multiple materials, every core PAINT tool, reciprocal queue
leases, agent restrictions/readback, a second deterministic provider turn, late
response fencing, Stop prefix, deferred human erase, actors/settings, a complete
saved material digest and continued authoring. Graphical runs require real
framebuffer PNGs and reject a headless display. Original failing logs are retained.

Loopback provider fixtures test HTTP wire formats, errors, timeout, Stop and image
payloads without paid calls. The retained `run_art_final_graphical.gd` also drives
the actual Send/Stop controls, checks incrementally rendered native results,
protection, retained conversations, local/world coordinate follow-ups and a
rejected stale-area response. It runs graphically on both target operating
systems with a deterministic loopback provider and an isolated settings folder. A deterministic provider fixture proves control and
editor behavior; it is not genuine local/cloud model inference. Earlier PR #560
inference evidence remains attributable to its own source/runtime.

For a manual rerun, use the source-built package's included launcher. For source
qualification, first build the extension with the repository's pinned build
scripts; do not use the old committed DLL after adding the new API. The workflow
is the exact executable build/packaging recipe. On an imported source checkout:

```powershell
python tools/ci/run_workbench_qualification.py regressions --godot C:/Godot47/Godot_v4.7-stable_win64_console.exe --project godot --evidence build/wb-integrated-regressions --paint
```

The integrated PR and its exact-head Actions artifacts are the final qualification
ledger. A pending, failed or Draft-skipped gate is not a pass. No Ready promotion
or merge is authorized by this runbook or a successful candidate workflow.

### Previous qualified checkpoint and download — historical 0e73e926

The immutable qualified application commit is
`0e73e926068a9ed2312303fec05ec8855797df79`, tree
`6418cd5f00b25a3cb4ddd1eb03e4de54e98a9d9d`.
[Hosted run 43129760301](https://github.com/techrote/cybersand/actions/runs/43129760301)
passed all three jobs: Linux build and execution, pinned Windows crossbuild, and
Windows graphical execution. These results belong to that commit. That earlier
handover record and the equipment-policy wording correction change documentation
only; they do not imply another execution on a later Git commit.

[Download the standalone Windows candidate](https://github.com/techrote/cybersand/actions/runs/43129760301/artifacts/13906272080),
extract the complete ZIP into a fresh folder and run **Open Workbench.cmd**. Godot
4.7, the source-built extension, pinned Rapier and all recipes are included. The
launcher imports the project and opens the Shared Workbench. The archive is
92,718,300 bytes; its SHA-256 is
`a2d8f414a737538d7de0d5fa9fa1fd0e42ab53408029804da77ca87bf981502e`.
It is retained by Actions until 2027-02-10. The pinned workflow is the reproducible
build and packaging recipe after that retention period.

After download, all 880 manifest-listed payload files were verified, along with
all 87 native source inputs and the 16 recipes in both packaged directories.
The actual Windows generator, combined editor and reopened-map screenshots were
also inspected. Both platforms retained 53 original PNGs.

| Previous combined-source coverage | Windows and Linux result, each |
| --- | --- |
| Actual discovery / resource-only / missing-both fixtures | 24 / 24 / 6 checks; zero failures |
| Generator native author / new-process reopen | 22 / 23 checks; zero failures |
| Combined installed and source author / reopen | 134 / 34 at each of 1 and 4 workers; zero failures |
| Stored material/body masks / shared ordering | 88 / 94 checks; zero failures |
| Original deferred strokes / integrated human completion | 14 / 37 checks; zero failures |
| Original native / rendered agent | 145 / 148 checks; zero failures |
| Each provider graphical HTTP fixture / final four-request graphical flow | 36 each / 38 checks; zero failures |
| PAINT shapes / executor / recovery | 159 / 21 / 5 checks; zero failures |
| Native PAINT | 109 at each of 1 and 4 workers; zero failures |
| PAINT history author / reopen | 1,880 / 1,920 checks; zero failures |
| Accepted equipment / reservoir | 103 / 81 at each of 1 and 4 workers; zero failures |

The exact runtime SHA-256 values are:

- Windows DLL: `8449902e411588f5449a5fb8e647269858d272718f03107bda83790dc48c5350`.
- Linux SO: `1de86fb8950113162be26796806f4e1aa7d17e443d428a7fa9bbf660afdb38ff`.

Windows installed Stop prefixes were 3,072 and 3,776 cells; each saved start
reopened with its own identical native material digest. Linux recorded 4,096.
Different time-budgeted prefixes are valid; the checks compare exact receipts,
stored cells and the corresponding saved/reopened pair, not an assumed ceiling.
The retained graphical flow completed all four HTTP requests on each platform.
Its large local follow-up took 36.810 seconds on Linux and 66.303 on Windows before
the next Send; the fixture retains the full drawing workload and bounded waits.
Those are hosted software-rendering measurements, not owner hardware promises.

The [machine-readable hosted record](../audits/wb-art-paint-2026-11-11/hosted-qualification-0e73e926.json)
contains every suite result, runtime and archive identity, provider outcomes,
Stop/reopen digests and inspected screenshot hashes. Original logs and images are
in the [Windows evidence](https://github.com/techrote/cybersand/actions/runs/43129760301/artifacts/13906042417)
and [Linux evidence](https://github.com/techrote/cybersand/actions/runs/43129760301/artifacts/13906320847).
Genuine model inference and independent owner acceptance remain separate. General
release workflows were Draft-skipped at that checkpoint; they were not successful
gates. The later 0025bd94 and d33c10e4 Native and Godot campaigns above exercised
those gates for their respective sources; they do not qualify the new history
implementation.

## Owner acceptance

1. Extract the complete standalone package into a new folder and run its launcher.
2. Open Shared Workbench and **New from generator…**; confirm actual recipes,
   select Deepworks, generate a native preview and install it.
3. Pause and use several materials, Brush, Eraser, Line, both Rectangle modes,
   Select/Copy/Paste, Fill and Undo/Redo.
4. Open Art batches, choose a small work area and protections, submit direct JSON
   or your configured model, then issue a further instruction. Check native counts
   and try Stop during a longer batch. Wait for retirement, then Undo/Redo its
   confirmed prefix. Alternate agent and manual edits and verify chronological
   history from both panels; continue with manual edits. Use a newly qualified
   package containing this history implementation for these Undo checks.
5. Run and pause simulation, interact with the supported physical actors and
   existing liquid equipment, then continue authoring while paused.
6. Save a named start, close Godot completely and relaunch. Load the name and
   confirm terrain, both interfaces' edits, actor spawns, equipment configuration
   and settings; continue drawing. The saved object is the authored start.

Report the candidate commit and package manifest with any failure. Keep the
candidate Draft until the owner independently accepts this combined application.
