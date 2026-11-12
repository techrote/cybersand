---
title: Integrated PAINT and agent Shared Workbench candidate
status: Current
document-kind: runbook
scope: Unmerged Draft candidate, generator packaging repair, native stored-material receipts, ordered human and agent authoring, reproducible qualification and owner acceptance
canonical-for: [integrated-paint-agent-workbench]
last-reviewed: 2026-11-12
related-documents: [../systems/paint-editor-bounded-shapes.md, ../systems/workbench-direct-art-batches.md, ../systems/workbench-art-providers.md, ../systems/explore001-generated-playable-maps.md, ../architecture/shared-workbench-authoring-data.md]
---

# Integrated PAINT and agent Shared Workbench

**Current unmerged candidate; keep Draft.** This work preserves both original
implementations and their Git ancestry. It does not authorize Ready, merging,
auto-merge, material-default changes or GEN-008 Flatten.

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

Confirmed changed agent cells invalidate manual Undo/Redo, preventing an old Undo
from overwriting an unrecorded change. A no-op agent receipt does not invalidate
valid history. A PAINT recovery hold also blocks agent drawing. Queue admission
is never displayed as native-applied success. Stop retains completed-prefix
accounting; stale provider replies cannot enter a replacement World.

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
Human Stop and recoverable errors. Native receipts now include actual stored
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

### Qualified application and Windows download

The immutable qualified application commit is
`0e73e926068a9ed2312303fec05ec8855797df79`, tree
`6418cd5f00b25a3cb4ddd1eb03e4de54e98a9d9d`.
[Hosted run 43129760301](https://github.com/techrote/cybersand/actions/runs/43129760301)
passed all three jobs: Linux build and execution, pinned Windows crossbuild, and
Windows graphical execution. These results belong to that commit. This final
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

| Final combined-source coverage | Windows and Linux result, each |
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
release workflows stay Draft-skipped; they are not counted as successful gates.

## Owner acceptance

1. Extract the complete standalone package into a new folder and run its launcher.
2. Open Shared Workbench and **New from generator…**; confirm actual recipes,
   select Deepworks, generate a native preview and install it.
3. Pause and use several materials, Brush, Eraser, Line, both Rectangle modes,
   Select/Copy/Paste, Fill and Undo/Redo.
4. Open Art batches, choose a small work area and protections, submit direct JSON
   or your configured model, then issue a further instruction. Check native counts
   and try Stop during a longer batch; continue with manual edits.
5. Save a named start, close Godot completely and relaunch. Load the name and
   confirm terrain, both interfaces' edits, actors and settings; continue drawing.

Report the candidate commit and package manifest with any failure. Keep the
candidate Draft until the owner independently accepts this combined application.
