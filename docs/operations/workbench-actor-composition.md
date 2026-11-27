---
title: Workbench actor sandbox owner procedure
status: Current
document-kind: guide
scope: WB-ACTOR-COMPOSE-002R ordinary Workbench configuration, physical interaction, expanded capacity and source-matched qualification procedure
canonical-for: [workbench-actor-composition-owner-procedure]
last-reviewed: 2026-11-22
related-documents: [../systems/workbench-actor-composition.md, local-build-and-validation.md, source-checkpoint-and-recovery.md, github-development-and-release.md]
---

# Workbench actor sandbox owner procedure

This is the owner workflow for the **WB-ACTOR-COMPOSE-002R Draft/HOLD candidate**
for [#737](https://github.com/techrote/cybersand/issues/737), building on accepted
[PR #683](https://github.com/techrote/cybersand/pull/683). The November 22 owner
follow-up authorizes live individual-part grabbing, paused whole-actor placement
and numeric experimental capacity. It opens the ordinary Shared Workbench.
F5, Thunderbowl and Flight Lab are not required. The
[system contract](../systems/workbench-actor-composition.md) owns the precise
capability, producer, persistence and capacity boundaries.

## Open the example

For the portable Windows evaluation, extract the entire ZIP into a writable
directory and double-click **Open Workbench.cmd** at its top level. Keep the
supplied `godot/` directory, Godot executable, runtime files and licenses together.
The launcher imports the project first, then opens interactive Shared Workbench;
no separate development checkout is required. Retain
`source-built-candidate-provenance.json` and `candidate-manifest.json` with the
package when reporting its source/runtime identity.

In a normal development launch, choose **Shared Workbench**. Open
**Configuration…** from the top toolbar. In **Actors**, choose **Living Mixed
Workshop**, then **Load playground**. The example prepares a 1024 × 512
material-cell scene and starts paused. Wait for preparation to finish, close the
window, and press **Play / Pause [P]**. Opening Configuration itself does not
pause a running world. Loading a playground replaces the authored start, so save
work you intend to retain before loading one.

The same authored recipe is retained as
[`mixed-actor-workshop.json`](../../godot/examples/workbench/mixed-actor-workshop.json)
and provided by the ordinary named start `mixed-actor-workshop`. Saving a user
start of that name takes precedence over the built-in named recipe. The panel's
explicit **Living Mixed Workshop** action prepares an extended version of that
recipe, with an additional high shelf and a lower catch basin for construction.
The original named start remains available unchanged.

| ID | Actor and source | What to observe |
|---|---|---|
| #1 | Midge — Human / Pilot | The retained Workbench flyer, independently piloted while NPCs run |
| #2 | Runner — Scripted NPC | Articulated local ground movement, support/obstacle reactions and a Brick Stamper |
| #3 | Crawler — Scripted NPC | A slower articulated mechanism starts on the solid approach to the sand patch, with recovery attempts and a Powder Vacuum |
| #4 | Skimmer — Scripted NPC | Flight near the suspended shelf and Water Lance material emission |
| #5 | Stuntbuggy / Loose Cannon — External Policy, deterministic test producer | Independent physical motion driven by fresh issued observations and leased policy commands |
| #6 | Reference barrel — Passive | Ordinary unpowered Rapier contact with the same material world |

The cast uses 24 prepared physical parts including equipment. Color-coded labels
show each authored ID, model and source; **PILOT** identifies the active human
actor. The terrain provides a floor, low steps, sand to excavate and a suspended
flight shelf. NPC reactions are local feedback and can stall against unsuitable
terrain; they do not promise global route planning.

## One configuration window

The six sections share one inspected actor and the existing physical owner:

| Section | Purpose |
|---|---|
| Actors | Choose a playground, browse the catalogue, inspect/place/replace/reset/remove, or enter precise authored coordinates and orientation |
| Controllers | Explicit pilot handoff, Human/Scripted/Policy/Passive sources, decision cadence, and collapsible policy observations/submission |
| Equipment | Supported starting mount and explicit Apply equipment / restart |
| Physics | Bounded live-grab stiffness/damping/force, paused placement grid/rotation/fine settings, and compatible per-actor mass/inertia/flyer tuning |
| Capacity | Numeric logical/body/proxy budgets, convenience presets and actual resource usage |
| Diagnostics | Applied pointer mode, selected physical part, preparation state, identities and resource receipts |

The **Pointer** selector distinguishes **Paint**, **Grab physical part** and
**Place whole actor (paused)**. The mode/status text reports the current operation;
**Preparing owner…** means a requested authoring transaction is still pending.
Editing settings stages them until the corresponding Apply button. Diagnostic
refreshes do not overwrite a focused numeric field or staged edits.

## Paused whole-actor placement

Pause, choose **Place whole actor (paused)**, close Configuration, and drag an
actor on the canvas. Its whole assembled pose previews together. **Q/E** rotates
in the configured increment; hold **Shift** for fine adjustment. **Escape**
cancels. Release the mouse to commit once. The preview does not rebuild the
native world on every mouse movement. A refused edge placement leaves the actor
and applied authored composition intact.

**Physics → Snap to grid** is optional and starts off. Grid size, rotation step
and fine movement are adjustable; defaults are 8 cells, 15 degrees and 1 cell.
Shift with Q/E always uses one-degree rotation.
**Arrow keys** nudge the active preview by the grid size when snapping is on,
or by 4 cells when it is off; **Shift + Arrow** uses **Fine move cells** (default
1 cell) in either mode. Hold Shift while dragging and releasing to retain an
off-grid placement, or press **Enter** to commit the displayed preview directly.
For exact authored values, inspect the actor in **Actors**, edit **Spawn X**, **Y**
and **Angle °**, and press **Apply authored placement (paused)**. **Read current
pose** copies the current rigid pose into those staged fields; it does not itself
move or save the actor. A committed relocation updates its authored spawn.

Save/reopen restores the authored spawn position and optional
`spawn_rotation_degrees`. Old starts without the extension retain zero rotation.
Ordinary Save does not promise the evolved joint pose or momentum. Placement
uses the retained-pose mechanism where supported; it does not introduce a full
simulation checkpoint.

## Live physical grabbing

Play, select **Grab physical part**, close Configuration, then press and drag a
wheel, chassis, limb or barrel. The clicked part is pulled through a bounded
damped physical force; connected parts follow through their actual joints.
Release or Escape ends the temporary grab. This is physical motion, so collisions,
rotation, swinging and imperfect recovery are expected. It does not write a new
saved spawn or transfer the pilot.

The grabbed actor's drive is temporarily neutralized so its motors do not fight
the pointer. Other NPCs continue. Release resumes the compatible previous source
without resetting pose, equipment or resources. Pause, focus loss, opening
Configuration and world/session teardown cancel the interaction. The next grab
must resolve a currently valid physical body again.

**Physics** exposes stiffness 5–2400, damping 0–160 and maximum force 10–1,000,000.
Defaults are 160, 24 and 24,000. These tune the bounded force; they do not disable
collisions or teleport bodies. The pointer cannot simultaneously paint, fire human
equipment, pan the camera and grab a part.

## Capacity and playgrounds

**Capacity** separates logical actors, response bodies and native masks. The
ordinary legacy defaults remain 8 / 64 / 64. Numeric controls permit other values
and convenience presets stage 16, 32, 64, 128 or 256 logical actors. **Apply
capacity** performs validation before adopting the change. A simple barrel uses
one actual body and one native proxy; multipart rigs and compound flyer masks
are counted separately. Equipment reserves its existing physical part even after
release.

The current representable allocation bound is 4096 for each configured resource,
not an FPS target. Larger compositions can be extremely slow. The sandbox does
not delete actors, disable controllers/equipment or reduce fidelity to recover
frame rate. A saved composition carries a versioned capacity envelope, so loading
64 actors cannot silently truncate it to eight. Qualification of a count is a
separate evidence claim: a selectable 4096 limit does not certify practical
4096-actor playability.

| Playground | Start and exploration |
|---|---|
| Living Mixed Workshop | Six retained actors, a human flyer, moving scripted NPCs, a policy fixture, compatible equipment and material terrain. Paint a barrier ahead of Runner, inspect without taking control, then grab an articulated part and observe recovery. |
| Barrel Crowd | Set Crowd count to 16, 32 or 64 and load. Every barrel is a real passive actor, initially separated above opposing stepped ramps and a central granular patch. Play, pull barrels out of the crowd, pause and stack/rotate them. Optional larger counts expand the staging grid and canvas within existing world bounds. |
| Mechanical Chaos | Six articulated mechanisms: stuntbuggy, trialsbike, inchworm, rocker policy actor, heavylift and pendulum. Pull a wheel or pod, watch forces propagate through joints, then use paused placement to arrange machines around steps and a suspended shelf. |

The playgrounds use [`workbench_actor_sandbox.gd`](../../godot/scripts/workbench_actor_sandbox.gd)
to produce ordinary Setup-v2 data. They are available from the configuration
window; no laboratory-only launcher or separate physics authority is used.

## Inspect, pilot and hand back

**Inspect** in Configuration → Actors or **Select body** chooses an actor for details.
It does not take control. The panel separately reports **Pilot** and **Inspecting**.
The toolbar pilot picker explicitly changes the human pilot. A source of Human
does not mean that an unpiloted actor receives keys intended for another body.

Select Runner #2 and press **Pilot inspected**. Its live body should remain where
it was, with the same pose, momentum and item. Use **A/D** to move and **Space**
for its primary action. Press **Hand back** to restore its prior scripted source.
Then explicitly pilot Midge #1 again. The script resumes without restoring the
canvas or respawning the runner.
If the actor began with Human control, Hand back uses its model's scripted
default and keeps its current compatible equipment. A remembered previous source
belongs to the current authored start; loading another start does not carry that
temporary hand-back history across reused IDs.

**Controller** switches an inspected actor among its admitted modes. **Decisions
enabled** stops or starts only that actor's decisions; the body remains physical.
**Decision interval** selects 1–12 physical ticks between local decisions. The
status shows source, paused/stopped/faulted/waiting/expired state, lease ticks,
accepted/refused counts and the latest error. **Advanced observations and policy…**
expands copied diagnostics and the external-input controls.

Place models through the panel's family/model picker and **Place at Workbench
X/Y**, or the ordinary placement tool. **Replace inspected**, **Reset** and
**Remove** are explicit authoring operations. Replacement gets a new authored
identity. Unsupported sources, mounts, body capacity or positions produce a
refusal rather than dropping another actor. **Physics → Apply actor tuning /
restart** changes the inspected actor's response budget, mass, inertia and flyer
options through prepared adoption; incompatible knobs are disabled. These controls
reuse the limits of the retained **Details** interface. They do not change the
shared material response algorithm. The shared response remains a separate
Workbench setting and applies to the entire cast.

Opening a panel or losing focus cancels human input. Release held controls after
returning to gameplay before pressing them again. NPC schedules do not depend on
whether the panel is visible. Pausing stops native and Rapier gameplay; **Step
[.]** advances the ordinary acknowledged single step and returns paused.

## Controls and equipment

Use each model's displayed controls: the existing flyer and SetP controls remain
model-specific. Ordinary movement accepts keyboard and the existing gamepad
sampler. **W/A/S/D**, **Space**, **Shift**, **C**, **Q/E** and mouse aim map only to
actions supported by the selected human model. **Z/X** are rope reel controls
where supported. The ACT-005 tool controls are:

| Input | Action |
|---|---|
| M / right trigger | Use the currently mounted item |
| Alt / left trigger | Alternate item action |
| N | Release item |
| U | Attach compatible nearby item through the existing equipment path |
| Mouse position over canvas | Aim for human equipment where supported |

Human PAINT remains available; **Brush**, **Eraser** and right-button erasing work
while actors run. Pause for precise shapes, selection, Fill, copy/paste and
Undo/Redo. Running brush gestures are recorded as authored stamps; they do not
claim the atomic cell snapshot used for paused edit history. NPC equipment never
takes the pointer, including when an equipped NPC occupies the first actor slot. The
example's brick, vacuum and Water effects use existing physical equipment and
native material admission. The script cannot bypass cooldown/charge, hit masks
or material accounting.

**Mounted equipment → Apply equipment / restart** edits the authored starting
item through a prepared transaction. This operation explicitly restarts control
and resource state while retaining the live material scene and compatible body
poses. A live **Controller** handoff instead preserves the actual current item
and resource state. Flyers, 4LY profiles and the passive barrel have no ACT-005
mount and refuse an item selection.

## Practical acceptance sequence

Run this sequence in a graphical Windows build as well as any available Linux
evaluation. Record the package/source identity and failures; a headless result
does not replace this owner test.

1. Open Living Mixed Workshop, press Play and fly Midge. Watch Runner and Skimmer
   move independently and Buggy consume policy commands. Inspect each actor's
   status and observe real material changes from the equipped scripts.
2. Inspect Runner while Midge remains the pilot. Open and close the panel. Runner
   must continue its script; inspection must not select it as the human pilot.
3. Pilot Runner during motion. Check that it does not jump to its authored spawn.
   Move/jump, hand control back, and pilot Midge again. Watch the other NPCs through
   the handoff. Disable Crawler decisions, then re-enable them; its body should
   remain in the world throughout.
4. In Paint mode, select **Brush** and paint a small obstruction ahead of Runner while inspecting a
   different NPC. Watch contact/recovery reactions and continuing flight/policy
   motion. Try **Eraser** while running. Pause, make an editor stroke or precise
   shape, Undo and Redo it, Step once, then resume.
   Check that no held human input fires on resume or after focus returns.
5. Select Buggy, choose **External submissions**, and expand policy details.
   Issue an observation and submit immediately, or use **Send fresh test action**
   for a local bounded demonstration. Wait and try the old envelope: it should
   refuse. Leave it without new input: its lease should expire while other
   actors continue. Restore **Deterministic test producer**.
6. Pause and use Place whole actor to drag and rotate Buggy, toggle snapping,
   cancel one preview, then commit another. Try an out-of-bounds placement and
   confirm the applied actor remains intact. Resume, grab a wheel and swing it;
   release, pause, lose focus and reopen Configuration during separate grabs.
   Each path must end the temporary grab without leaking paint or equipment input.
7. Load Barrel Crowd at 16, 32 and 64. Check the distinct actor/body/proxy counts,
   actual physical progression and release behavior. Try a nonpreset numeric
   capacity and a deliberately insufficient body budget; refusal must preserve
   the applied world. Load Mechanical Chaos and repeat a wheel/appendage grab.
8. Pause, give the map a new name and **Save start [Ctrl+S]**. Close the application,
   reopen Shared Workbench and Load that name. Confirm models, authored spawns and orientation,
   capacity, controller modes, equipment and accepted paint edits. Actors reconstruct at
   authored spawns; live momentum, evolved material, leases and private policy
   memory are not restored. Use the established Flatten operation when a new
   material baseline is desired.
9. Select a flyer and confirm that its unsupported mounted-item selector is
   disabled. Try an over-capacity placement and confirm a useful refusal with
   the applied map/cast intact. Remove or replace an actor normally and check
   that it no longer responds to old policy data. Automated API/schema cases
   separately verify that forged incompatible item requests refuse.

## External policy integration

Use `actor_observation(instance_id, true)` and
`submit_actor_policy(instance_id, command)` on the existing Workbench, with
`CyberPhysicalActorSession.make_command()` to form the physical version-2 envelope.
The [system contract](../systems/workbench-actor-composition.md#producer-and-policy-interface)
contains the API example and freshness rules. A future service can work from
copied values outside the simulation owner and submit the result when ready;
no inference call belongs in the native tick.

The supplied fixture is deterministic, not learned. The manual panel is a
practical in-process adapter, not an HTTP server. The full sampled Thunderbowl
arena, oracle, virtual tag combat, direct metal actuation, message bus, NCA and
smart-link service are outside this release. No unsupported research mode is
silently translated into physical abilities.

## Automated qualification apparatus

Use the repository-pinned Godot/Rapier and matching native extension. The new
multi-part response-owner capacity requires rebuilt matching Windows and Linux
runtimes; a baseline DLL/SO must not be relabeled as this candidate. Follow
[local build and validation](local-build-and-validation.md) and retain source,
runtime hashes, exact commands, logs and the platform alongside results.

From the repository root, with `GODOT` naming the pinned executable:

```sh
"$GODOT" --headless --path godot --script tests/test_workbench_actor_configuration.gd
"$GODOT" --headless --path godot --script tests/test_workbench_actor_sandbox.gd
"$GODOT" --headless --path godot --script tests/test_workbench_actor_catalog.gd -- --save actor-compose-schema
"$GODOT" --headless --path godot --script tests/test_workbench_actor_catalog.gd -- --reopen actor-compose-schema
"$GODOT" --headless --path godot --script tests/test_workbench_actor_composition_session.gd
"$GODOT" --headless --path godot --script tests/test_workbench_actor_composition_native.gd
"$GODOT" --headless --path godot --script tests/test_workbench_actor_equipment_extent.gd
CYBERSAND_ACTOR_COMPOSITION_REPORT=/absolute/path/author.json "$GODOT" --headless --path godot --script tests/test_workbench_actor_composition.gd
CYBERSAND_ACTOR_COMPOSITION_REOPEN=1 CYBERSAND_ACTOR_COMPOSITION_REPORT=/absolute/path/reopen.json "$GODOT" --headless --path godot --script tests/test_workbench_actor_composition.gd
```

The integration writer uses named start `actor-compose-589-evaluation`; set
`CYBERSAND_ACTOR_COMPOSITION_NAME` in both processes to isolate another run. The
second invocation is a new process with a fresh native World and physical owner.
Its completion marker is `WB_ACTOR_COMPOSE` followed by JSON checks, failures,
per-actor movement/support, equipment receipts, native/Rapier progression and
elapsed/cost observations. A nonzero exit or any failure means it did not pass.
Retain failed logs, not only the final result.

For actual framebuffer evidence, remove `--headless` in an available graphical
display and set `CYBERSAND_ACTOR_COMPOSITION_CAPTURE` to an absolute output
directory. PNGs come from the real application framebuffer after presentation;
the capture refuses the headless driver. Captions in the JSON identify human,
scripted, policy and passive roles, phase and tick. A software-rendered Linux
capture proves the displayed application state, not Windows playfeel or hardware
frame pacing.

Run the relevant existing Workbench input, canvas, combined-authoring,
generated-start, material-baseline, Flatten, PAINT and physical actor/equipment
regressions too. The dedicated qualification runner records their outcomes.
Catalogue, controller and gameplay results are separate from performance: compare
no NPC, one script, heterogeneous scripts, mixed producers and equipment on both
small and 2048 × 1024 canvases, retaining actual tick progression, decision cost,
frame/publication timing and memory. Do not infer performance from slot limits.

Windows graphical execution and owner acceptance remain explicit requirements
when the build environment cannot run a Windows desktop. A portable package
must contain the source-matched native/Rapier runtimes, pinned Godot, project
resources and this example; its launcher must open interactive Shared Workbench.


## ACTOR-COMPOSE-FINAL-001 corrected pilot acceptance and local diagnostics

**Use the latest exact-source integrated evaluator, not the superseded #742
archive.** Its manifest names the exact commit, native runtime and packaged
files. Old binaries cannot qualify the updated pilot or stack-footprint code.

Load **Living Mixed Workshop**, start progression with **Play / Pause [P]**,
and in Configuration → Actors select **Runner #2** and **Inspect**. Under
Controllers press **Pilot inspected**, close Configuration with **Close** or
the window X, allow one neutral keyboard sample, then use **A / D** to run
and **Space** to jump. The Workbench window needs keyboard focus; a focused
editable field intentionally blocks movement. Selecting Grab/Place while
idle must not block pilot input; an active gesture owns it exclusively.
A paused simulation is not a broken pilot.

Use **Hand back** to restore Runner's scripted controller without replacing
its Rapier body or resetting other NPCs; exercise the explicit pilot picker,
focus loss/recovery and pause/resume. Owner Windows 11/NVIDIA focus and
playfeel remain separate from hosted CI acceptance.

The extracted Actor evaluator also contains **Collect Actor Results.cmd**.
Run it after closing Workbench to verify the manifest, native/Rapier hashes,
and exercise the actual graphical Godot Workbench keyboard-to-Rapier test.
The local **Actor-Acceptance-Results** folder contains JSON pass/fail,
original logs, elapsed time, GPU/CPU data and a fillable owner observations
template, with a ZIP attempted automatically. Nothing is uploaded.
Run this on a disposable extracted evaluator: it imports the project and
creates temporary actor worlds. Synthetic keyboard tests are not a substitute
for manual piloting, manipulation or measuring NVIDIA frame pacing.

The full source-qualified campaign rebuilds both native candidates. Git LFS
publication accepts unchanged pointers only after runtime-byte hashes/sizes
agree with new provenance; the Windows package is independently extracted,
launched and re-opened. Keep Draft/HOLD without merging or changing defaults.
