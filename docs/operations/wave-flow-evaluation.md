---
title: Wave Flow evaluation
status: Current
document-kind: guide
scope: Experimental PR 631 Wave Flow desktop controls inherited from PR 618, comparative fixtures, actual native diagnostics and explicit unsupported physical persistence and material behavior
canonical-for: [wave-flow-evaluation]
last-reviewed: 2026-11-15
related-documents: [../architecture/wave-flow-v1.md, lcb-manual-comparison-ux.md, ../architecture/rigid-body-and-cellular-coupling.md]
---

# Wave Flow evaluation

Open **Wave Flow** from the desktop feature launcher, or start the supplied
Windows evaluation package with **Test It.cmd**. A source checkout with its
matching native runtime accepts `Godot --path godot -- --wave-flow`. The ordinary
sandbox and production Water default remain unchanged.

PR #631 owns the current source-qualified package. `Test It.cmd` opens the
dedicated Wave Flow evaluator directly, with the existing Workbench actor and
native coupling infrastructure. Wave is not added to the ordinary Shared
Workbench solver menu. Use the package linked in the final
[PR qualification ledger](https://github.com/techrote/cybersand/pull/631),
whose source commit and digest distinguish it from predecessor packages.

The ZIP's `candidate-manifest.json` records the source commit and SHA-256 of
every delivered file. `source-built-runtime-provenance.json` records the actual
native build toolchain and target-OS validation; `qualification/runtime/`
contains the corresponding execution report and original logs. The separate
retained runtime reference describes historical bytes, not the delivered DLL.

Choose a scene, solver, worker count, Wave substeps and size, then press **Reset
scene**. Every reset constructs a new native World from the same fixture.
Press **Run**, **Pause** or **Single tick**. Space toggles pause; **Disturb pool**
or D moves existing Water into a raised patch without adding quantity. In the
Needle scene, W applies thrust, A/D turn, and S reverses. F2 closes the evaluation
and returns to the launcher.

The four selections run actual native Wave Flow, FreeMass, Inertial and
PressureFlow-reference laws. Wave Flow is an experimental override of Water's
FreeMass carrier, not a newly registered production policy family. The applied
native readback names that override explicitly. Changing the selector takes
effect on **Reset**, so it never changes an existing World's law in place.

## Scenes

| Scene | What to inspect |
|---|---|
| Large dam break | Reservoir release, falling front, conservation and strip/chunk transitions |
| Deep pool / repeated disturbances | Conservative raised patches every 180 native ticks; propagation and damping |
| Two approaching crests | Two raised patches moving toward the middle |
| Crest meeting trough | Opposed height disturbances; compare with the two-crest scene |
| Many small basins | Disconnected active reservoirs and sparse-work cost |
| Waterfall and channel | Finite upper reservoir spilling past a ledge into a lower channel |
| Water against hard terrain | Obstacles inside a reservoir, narrow connections and settling |
| Moving Rapier barrel | Actual translating/rotating Rapier body, native masks and returned contact response |
| Pilot the real Needle | Existing authored Needle hull, mass and flight controller; no substitute test body or retuned thrust |
| Sparse sleep and wake | Separated pools; let them sleep, then disturb and observe reactivation |

The colours are deliberately plain. The display uses the native copied material
projection with no decorative shader waves. Fractional Water retains the native
display dithering; the quantity counter reads authoritative stored Water,
including cells temporarily hidden under body masks.

## Controls and measurements

Wave substeps accept **1–8**. Three rounds per tick run the same stable law three
times, increasing transport speed and Water cost. Worker counts accept **1–32**;
the HUD separately reports actual participants observed by the native scheduler.
A requested count is not a claim that every worker performed useful work.

Sizes are 256², 512², 1024² and 2048². Native rate accepts 1–120 ticks/s and
Rapier rate accepts 30–120 ticks/s. The evaluator uses the existing native pool
and manually stepped Rapier bridge; changing Rapier rate updates both cadence
and physical step length, and leaving restores the ordinary rate. The UI's native dispatch is synchronous
with a bounded catch-up budget (four ticks or 8 ms between dispatches); one
native tick is indivisible. Achieved native rate, complete native tick duration
and display FPS are reported separately. A slow comparison law may therefore
miss its requested rate. These UI readings do not substitute for the matched
complete-tick benchmark matrix.

The HUD also shows solved chunks, strip tasks, Wave side-storage bytes, resident
cell bytes, stored Water quantity/change and actual body contact counts. All
built-in disturbances conserve quantity; the closed-fixture quantity change
should remain zero. Native diagnostic APIs expose capacity refusals and the
full uint16 mass alongside retained face flux. The legacy C uint8 mass accessor
saturates at 255; `cybersand_world_liquid_mass_v2` returns the full value.

## Bounded experimental limitations

Physical-state saving and loading are explicitly refused for a Wave World.
The retained face flux affects the future and must not be silently dropped.
Its complete physical-state identity is version 6; physical save format 0 means
unsupported. CYSD1 state export/restore is also refused: its one-byte mass cannot
represent Wave overfill. Material-only authoring snapshots are a different
contract and never promise physical continuation. Existing legacy save formats
and the default-off behavior remain unchanged.

Wave Flow has no buoyancy or retained sideways momentum for falling Water.
Water-initiated pair chemistry, coherence and sinking through lighter liquids
are unavailable. Other materials retain their own initiating interactions.
Nonzero coherent Water writes and custom transport profiles are explicitly
refused. This evaluator uses Water and hard terrain, with real body coupling in
the two actor fixtures. It does not establish arbitrary mixed-material parity,
continuum mechanics, physical GPU performance or human acceptance.

## Automated execution

`Godot --headless --path godot --script res://tests/test_wave_flow.gd` exercises
native option validation, full mass readback with actual overfill, region
pause/reentry, state identity, save/load refusal, all four actual solver choices,
the ten fixtures, actual Rapier contact and the authored Needle. It prints one
strict `WAVE_FLOW` completion record containing each required section. A missing
section, failure or nonzero process exit is not a pass. Target OS/runtime/source
qualification and benchmark evidence belong to the PR's final qualification
record; the existence of this script is not execution evidence.

`Godot --path godot --script res://tests/test_wave_flow_render.gd` requires a real
rendering display. It drives the actual scene/solver menus, Reset/Run/Pause
controls and native fixtures, checks their layout and submitted Water pixels,
and retains four raw screenshots plus a JSON receipt. The captures cover a dam
break, interacting crests, the actual Rapier barrel and the actual Needle.
The output directory is `CYBERSAND_TEST_ARTIFACT_DIR`, or
`CYBERSAND_PRESENTATION_EVIDENCE`, or `user://wave-flow-render`. Hosted software
rendering proves this rendered route; it does not establish physical GPU or
human playtesting acceptance.

Implementation: [evaluation screen](../../godot/scripts/wave_flow_evaluation.gd),
[shared fixture owner](../../godot/scripts/wave_flow_session.gd),
[native adapter](../../godot/native_extension/cyber_native_cell_world.cpp), and
[source-built regression](../../godot/tests/test_wave_flow.gd).
