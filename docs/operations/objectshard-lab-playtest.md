---
title: ObjectShard Lab owner evaluation
status: Planned
document-kind: guide
scope: Source-bound experimental M0–M2 ObjectShard evaluator; not ordinary Workbench defaults or production acceptance
canonical-for: [objectshard-owner-evaluation]
last-reviewed: 2026-11-22
related-documents: [github-development-and-release.md, local-build-and-validation.md]
---

# ObjectShard Lab owner evaluation

The ObjectShard Lab is a separate experimental scene. It leaves ordinary
CyberSand gameplay and Workbench defaults unchanged. Keep the implementation
**Draft / HOLD** until the recorded native/platform qualification and your
physical Windows acceptance are complete.

The source is delivered in executable stages. The native capability panel
identifies the implemented milestone, and unavailable scenarios stay disabled.
M0 supplies ownership transfer and motion; M1 adds continuing material chemistry;
M2 adds real product delivery, Sand lodging and external Water exposure. A
scenario's presence in this guide is not evidence that an earlier-stage binary
already implements it.

## Open the Windows evaluator

1. Extract the complete evaluation ZIP into a new directory.
2. Double-click **Open ObjectShard Lab.cmd**. It verifies the file manifest,
   imports the included source project and launches the bundled Godot runtime.
3. If verification or import fails, retain the console message and do not copy
   DLLs from another CyberSand build. **Verify ObjectShard Lab.cmd** repeats the
   package check without starting the Lab.

The package contains its exact source commit/tree, native build input ledger,
native DLL hash, selected Rapier provenance, pinned Godot archive identity and
file hashes. It is a bundled source-project evaluator, not an exported release.
No export-template installation or developer command reconstruction is needed.

## Controls

Choose a scenario, then **Resume**, **Pause**, **Single step**, or **Reset**.
The default view uses native material colours. Left-drag with **Erase**, **Wood**,
**Sand**, **Water**, or **Ignite**. Right-click, or select **Inspect**, to inspect
the exact owner, local identity, state and temperature of a material cell.

**Erase lower Wood band** finds the lowest current Wood row and removes the
lowest twelve rows through the same ordinary native edit operation used by the
brush. It is a convenience for making a readable fall; there is no special
cut-to-physics command or fixed component capture rectangle.

The optional **Shapes / centre of mass / pocket** overlay shows exact collision
rectangles in cyan, centre of mass in gold and the admitted pocket in green.
Empty holes remain empty. The side panel records structural inventory, products,
cargo, revisions, native events and measured frame/promotion costs.
The ownership and inspection panes scroll when their diagnostics exceed the
available window height. World brushes edit stationary material; moving Wood
has its own owner and supports inspection and ignition, with erosion supplied
by its native chemistry.

## Scenario A — ordinary detachment

Remove part of a Wood support or use the lower-band convenience action, then
resume. The component must lose support because its actual native cells changed.
After a short paused handoff, it should fall, rotate when contact produces torque,
and collide with terrain.

**PASS:** the removed source material has one moving owner; it neither remains
as a duplicate stationary structure nor disappears during the handoff. Pause and
single-step should remain responsive. Tiny resting drift or harmless settling is
not by itself a failure.

## Scenario B — burning Wood tree

The tree is genuinely Wood, with an existing native burn countdown. Resume for a
few ticks, then remove support. Inspect a burning cell before and after promotion.
Its burn state must continue rather than restart. Allow several seconds for Wood
consumption to change the structure and collision geometry.

**PASS:** native combustion continues after motion begins and while the body
sleeps. Wood produces actual Fire; delivered Fire enters World and follows the
native Fire-to-Smoke lifecycle. The side panel's product/output accounting must
advance. Bright cells are drawn from native material state, not decorative flames.

This first slice keeps disconnected structural islands in one compound. The
panel labels this **split_pending**. Independent fragment motion is not claimed.
Persistent, conspicuously floating branches should be reported as a gameplay
limitation; small transient disconnected regions are expected before fracture.

## Scenario C — external contact and lodging

Detach the pocket structure. The authored Sand is above an open channel; more
Sand can be placed over it. The capture must occur through the physical aperture,
not through a solid wall. Inspect carried Sand to see its material, state,
temperature and cargo identity.

Ignite Wood, then place Water against an exposed burning surface. Water remains
owned by World while the accepted contact extinguishes that Wood incarnation.
Pause, inspect and single-step to see the change. Contact and ingestion are
separate capabilities; Water is not silently copied into a private liquid solver.
The admitted opening is one to three cells wide. A suspicious sideways entry
holds ingestion until that local opening is clear again; it must not become a
valid capture merely because the body subsequently stops moving.

**PASS:** real Sand is removed from World exactly once and becomes inspectable
cargo; genuine Water contact changes burning Wood; failed delivery retains its
inventory and reports a blocked state. A vanished pocket or retired rigid body
must not silently delete remaining cargo or products.

## Scenario D — three moving owners

Remove supports from the three native Wood structures. Their identities,
inventory, material revisions and body revisions must remain distinct. Ignite
them and observe concurrent chemistry and motion.

**PASS:** all three remain usable without freezing the control loop, sharing a
singleton inventory, duplicating effects or accumulating an unbounded backlog.

## Export and acceptance

Use **Export result** to save a bounded JSON observation record and open its
directory. It includes the package-provided source revision, engine/platform,
scenario, session, accounting, metrics, recent events and frame samples. Include
that file with a short description of what you saw. A screenshot or short video
is particularly useful for visible stalls or contact problems.
The export includes separate owner identities, material populations, geometry
revisions and the last physical pose of a draining domain after its body retires.
Timing values are elapsed time on the owner thread and include operating-system
preemption; they are not process CPU utilization. Native memory counters are an
accounted lower bound, with separate allocator measurements in the qualification
report.

The export is an observation record, not a durable gameplay save. Reset explicitly
disposes the entire experimental session and invalidates its old handles.

Block acceptance for crashes, unexplained material loss/duplication, double
ownership, stale activation, stopped advertised chemistry, catastrophic terrain
penetration, runaway impulses, or indefinitely stale collision. Report minor
jitter separately from those failures. Automated Windows execution and rendered
captures are evidence, but they do not replace physical acceptance on your
Windows 11/NVIDIA machine.

## Deliberate limits

M0–M2 supports admitted structural cells, selected shared combustion/product
lifecycle, real bounded output, whole-cell baseline Sand lodging and selected
non-consuming Water contact. It does not provide general fracture, internal gas
or liquid transport, fractional liquid ingestion, solver-sidecar transfer,
durable save/restore or streaming. Wave, PressureFlow, inertial and ballistic
state remain with their existing World owner. Production Water defaults are
unchanged.

The initial motion envelope admits up to four cells of translation and 0.20
radians of rotation per semantic step. An unsupported motion interval holds the
Lab with exact inventory retained; arbitrary high-speed chemical collision
coverage is not claimed. The diagnostic native `transfer_budget` can be set to
0–64 during construction for resource-pressure tests; the owner launcher uses
the ordinary Lab default of 64 and provides no new Workbench control.
