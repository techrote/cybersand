---
title: Mixed Actor Workshop owner procedure
status: Current
document-kind: guide
scope: WB-ACTOR-COMPOSE-001 ordinary Workbench controls, authored example and source-matched qualification procedure
canonical-for: [workbench-actor-composition-owner-procedure]
last-reviewed: 2026-11-24
related-documents: [../systems/workbench-actor-composition.md, local-build-and-validation.md, source-checkpoint-and-recovery.md, github-development-and-release.md]
---

# Mixed Actor Workshop owner procedure

This is the ordinary Workbench workflow accepted in
[PR #683](https://github.com/techrote/cybersand/pull/683), from
[#589](https://github.com/techrote/cybersand/issues/589). The later actor-finisher
candidate does not supply additional accepted behavior here. F5, Thunderbowl and Flight Lab are not required. The
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

In a normal development launch, choose **Development workbench**. Open **Actor Composition…** from
the top toolbar, then press **Mixed Actor Workshop**. The example prepares a
1024 × 512 material-cell scene and starts paused. Wait for the preparation status
to finish, close the panel if desired, and press **Play / Pause [P]**.

The same authored recipe is retained as
[`mixed-actor-workshop.json`](../../godot/examples/workbench/mixed-actor-workshop.json)
and provided by the ordinary named start `mixed-actor-workshop`. Saving a user
start of that name takes precedence over the built-in named recipe. The panel's
explicit **Mixed Actor Workshop** action always prepares the supplied recipe.

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

## Inspect, pilot and hand back

**Inspect** in Actor Composition or **Select body** chooses an actor for details.
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
accepted/refused counts and the latest error. **Observations and policy adapter…**
expands copied diagnostics and the external-input controls.

Place models through the panel's family/model picker and **Place at Workbench
X/Y**, or the ordinary placement tool. **Replace inspected**, **Reset** and
**Remove** are explicit authoring operations. Replacement gets a new authored
identity. Unsupported sources, mounts, body capacity or positions produce a
refusal rather than dropping another actor. Use the existing **Details** controls
for relevant per-instance response budget, mass, inertia and flyer options;
irrelevant knobs are disabled. The response algorithm itself is a shared
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

1. Open Mixed Actor Workshop, press Play and fly Midge. Watch Runner and Skimmer
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
6. Pause, give the map a new name and **Save start [Ctrl+S]**. Close the application,
   reopen Shared Workbench and Load that name. Confirm models, authored spawns,
   controller modes, equipment and accepted paint edits. Actors reconstruct at
   authored spawns; live momentum, evolved material, leases and private policy
   memory are not restored. Use the established Flatten operation when a new
   material baseline is desired.
7. Select a flyer and confirm that its unsupported mounted-item selector is
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

Use the repository-pinned Godot/Rapier and matching native extension. The
accepted runtime includes the multi-part response-owner capacity. Rebuild when
its source inputs differ; never relabel an older DLL/SO as a matching runtime. Follow
[local build and validation](local-build-and-validation.md) and retain source,
runtime hashes, exact commands, logs and the platform alongside results.

From the repository root, with `GODOT` naming the pinned executable:

```sh
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

Select further Workbench input, combined-authoring, generated-start, Flatten
and equipment regressions according to the changed behavior and the dedicated
qualification runner. Documentation-only edits do not require an expensive full
runtime matrix. The commands above are reproduction procedures, not a claim
that this documentation mission reran them.
Catalogue, controller and gameplay results are separate from performance: compare
no NPC, one script, heterogeneous scripts, mixed producers and equipment on both
small and 2048 × 1024 canvases, retaining actual tick progression, decision cost,
frame/publication timing and memory. Do not infer performance from slot limits.

Windows graphical execution and owner acceptance remain explicit requirements
when the build environment cannot run a Windows desktop. A portable package
must contain the source-matched native/Rapier runtimes, pinned Godot, project
resources and this example; its launcher must open interactive Shared Workbench.
