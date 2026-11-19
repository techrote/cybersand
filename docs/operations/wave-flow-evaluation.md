---
title: Wave Flow evaluation
status: Current
document-kind: guide
scope: Experimental PR 631 Wave Flow desktop controls inherited from PR 618, comparative fixtures, actual native diagnostics and explicit unsupported physical persistence and material behavior
canonical-for: [wave-flow-evaluation]
last-reviewed: 2026-11-16
related-documents: [../architecture/wave-flow-v1.md, lcb-manual-comparison-ux.md, ../architecture/rigid-body-and-cellular-coupling.md]
---

# Wave Flow evaluation

## Water Lab (consolidated Workbench UI)

On the Water Lab UI branch, open **Water Lab…** from the main Workbench toolbar.
All Water-specific settings share one non-modal window. **Solvers & scenes**
selects Wave/FreeMass/PressureFlow/Inertial, comparison canvases and workers;
**Wave tuning** exposes all 18 fields and presets; **Transport & spray**
contains ballistic, signed inertia, face release, PressureFlow gas, fine cores,
impact spray and jets; **Equipment** contains valves, drains, pumps and nozzles;
**Advanced policy** retains the full per-material liquid picker and normalization.
**Applied native** readback and **Apply solver / tuning** are always visible
beneath the tabs. The old separate Wave/spray popups and permanent Water toolbar
rows are not created. This is a UI composition change, not a solver/policy
modification; staged and refused requests still use the existing native receipts.

## Start the supplied Windows candidate

Extract the downloaded artifact ZIP, then extract its inner CyberSand ZIP into a
normal folder. Double-click **Open Workbench.cmd**. The candidate includes Godot,
native CyberSand, Rapier and the required VC runtime; no repository checkout,
Python installation or separate Godot installation is needed. First launch
imports the bundled project before opening the ordinary Shared Workbench.

Wave is experimental, opt-in and disabled by default. The ordinary Water default
is unchanged. The objective is to compare behavior interactively; Wave is not
claimed to match or improve PressureFlow's appearance or kinetics.

## Select, apply and verify Wave

1. In **Water solver**, tick **Wave Flow**. This stages the required FreeMass
   carrier and the Wave profile. A staged selection has not yet changed native.
2. Choose **Two crests ·512²** in **Water comparison**, then press
   **Load / reset scene**. This installs an editable authored scene using the
   requested solver. It replaces the current scene, so retain any wanted work first.
3. Read **Active native** and the native column in **Wave tuning…**. Wave must
   report enabled, with the requested rounds, worker capacity and parameter values.
4. Use Workbench **Run/Pause** and **Single tick**. Native **ticks** and **rounds**
   must advance. At two rounds, each completed native tick contributes two Wave
   rounds. The visible simulation is native Water, not an animated overlay.
5. Change one or two controls, then press **Apply solver / tuning**. A successful
   replacement acknowledges the new native configuration; refused settings show
   the reason and preserve the old World. Tuning itself is staged until Apply.

**APPLIED · active settings match** compares the active solver, Wave values,
workers and relevant construction controls with authoritative native readback.
Ballistic Water, IN signed, Face release, Fine cores, active face tuning,
PressureFlow capacity and effective rule-radius changes remain **STAGED** until
they actually match the new World. The radius tooltip shows the picker request,
the effective value after the solver's minimum, and the native value.
**Round Water on this Apply only** stays staged until its native construction
receipt is acknowledged and the one-shot checkbox clears. Hover the status for
the named differences and requested/native values. Dormant settings remain
preferences for their own law; they do not
configure the currently selected alternative.

Apply preserves the live stored cellular inventory and actors when the requested
law can represent them. Rebuilding a Wave World resets its retained face flux,
sleep state and tick counters;
this is a new law state, not exact physical continuation. Pause/resume preserves
the current law state. A normal restart uses accepted construction settings,
not invalid or unsubmitted tuning edits.

**Reset Wave defaults** stages the original version-2 values; press Apply to use
them. **Revert to native** discards staged tuning and copies the active native
values back into the controls. **v2 defaults**, **Lively**, **Strong response**
and **Heavy** are starting points. Non-default presets are exploratory, not
recommendations or evidence that Wave is superior.

## Compare on editable Water scenes

Use **PF cached**, **PF dormant**, **Inertial** or **FreeMass** to stage the other
law. To compare an equal starting scene, press **Load / reset scene** after each
selection. All scenes remain ordinary Workbench canvases: paint, edit, move actors
and use the normal camera and simulation controls.

| Scene | Useful comparison |
|---|---|
| Two crests ·512² | Two raised Water patches approach and interact; inspect damping, level response and interference. |
| Repeated impacts ·512² | Four actual Rapier barrels hit Water at different times. Select an actor and use R to repeat its drop into the live pool. |
| Sparse basins ·1024² | Disconnected reservoirs expose settling, sleep/wake behavior and the cost of sparse active work. |
| Cascades and reservoirs ·2048×1024 | A larger active arrangement of reservoirs, ledges and channels for free painting and movement. |

Wave can retain more than 255 mass units in a cell. Another law may be unable to
represent that live state; an attempted live switch then refuses instead of
silently losing Water. The panel keeps the requested target law available.
**Load / reset scene** starts that target from the authored scene for comparison;
it intentionally replaces the live state. Use equivalent authored starts when
judging behavior. Wave settings are kept separate from the other laws' controls.

## Tuning reference

Open the movable **Wave tuning…** dialog. Every field has a bounded numeric input, a description
and a native readback beside the requested value. **Pool workers** accepts 1–32;
this is configured capacity. Observed participants report workers that actually
claimed tasks, not utilization or a guarantee that all configured workers ran.

| Control | Default | Supported range | Effect |
|---|---:|---:|---|
| Rounds | 1 | 1–8 | Repeats the Wave solve per native tick; more transport and more work. |
| Active rows | 32 | 1–32 | Stack depth that participates in the restoring response. |
| Gain | 32 | 0–512 | Open-surface head-to-flux acceleration. |
| Confined gain | 4 | 0–512 | Restoring response under confinement; does not add PressureFlow's pressure or gas model. |
| Stiffness | 256 | 1–4096 | Sealed overfill response; must be at least Active rows. |
| Damp shift | 7 | 0–16 | Momentum damping divisor; larger values mean less damping. |
| Coast | 16 | 0–65535 | Flux allowed to coast against a small head difference. |
| Level shift | 3 | 0–16 | Lateral levelling divisor; lower values level more strongly. |
| Sleep after | 30 | 1–3600 | Quiet native ticks before sleeping. |
| Wake move | 1 | 0–65535 | Movement threshold for activity; zero keeps activity awake. |
| Rest head | 1 | 0–65535 | Head difference eligible for the small-step rest rule. |
| Stick flux | 512 | 0–65535 | Small flux discarded within the rest rule. |
| Calm flux | 512 | 0–65535 | Threshold for the stronger low-flux damping path. |
| Calm damp | 3 | 0–16 | Low-flux damping divisor; larger values mean less damping. |
| Sealed mass cap | 32000 | 255–65535 | Threshold above which a sealed stack refuses further lateral inflow. |
| Empty pour | 2 | 1–8 | Donor fraction into Empty is 1 / 2^N. |
| Wet share | 1 | 1–8 | Donor fraction between wet neighbors is 1 / 2^N. |
| Adhesion shift | 1 | 0–8 | Surface-film scaling; larger values reduce adhesion. |

The representational flux width, absolute head clamp and conservation bounds are
fixed. Native validation also checks combinations; an in-range field alone does
not guarantee a valid configuration. Invalid settings must leave the active
World unchanged. Capacity refusals and solver-storage bytes are native readbacks,
not proof that larger worlds will meet an interactive performance target.

Native tick duration measures native simulation work. It is separate from display
FPS, achieved simulation rate and main-thread Rapier work. More rounds can make
Wave slower than an existing law in a particular scene. Compare the same scene,
size, worker setting and run length, and judge the appearance yourself.

## Package identity

The candidate's `candidate-manifest.json` records its complete source commit/tree
and every payload SHA-256. `source-built-runtime-provenance.json` identifies the
native build, source inputs and target-OS execution; `qualification/runtime/`
contains its original logs. The PR handoff supplies the artifact link, inner ZIP
SHA-256, final source/tree and any runtime-only publication append. Earlier Wave
packages do not qualify later Workbench source. The final acceptance ledger is
[PR #631](https://github.com/techrote/cybersand/pull/631).

## Standalone regression fixture

The old Wave screen remains available from the feature launcher or via
`Godot --path godot -- --wave-flow` for deterministic fixture/regression work.
It is no longer the primary human evaluation surface.

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

## Retained regression scenes

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

## Retained fixture controls and measurements

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

`Godot --headless --path godot --script res://tests/test_workbench_wave.gd`
executes the ordinary Shared Workbench path, all exposed parameters, real native
ticks, runtime replacement, regeneration, scene switching, pause/resume, invalid
settings, failed-owner recovery and comparison controls. Its unique
`WORKBENCH_WAVE_RESULT` must report all sections complete with no failures and
actual enabled native tick/round observations. The original
`test_workbench_canvas.gd` activation/readback checks also remain mandatory.
`test_workbench_wave_render.gd` requires a real display and retains actual
Workbench control, scene and native-pixel captures. These tests run on the
source-matched publication candidate; the extracted Windows package also runs
the headless Workbench suites and the delivered launcher.


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

