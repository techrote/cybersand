---
title: SWARM-004 experimental reciprocal Workbench evaluation
status: Current
document-kind: guide
scope: Draft/HOLD FRAMEWEAVER and MOSAIC native composition authoring and Windows evaluation
canonical-for: [swarm004-workbench-owner-evaluation]
last-reviewed: 2026-11-20
related-documents: [../architecture/experimental-workbench-authoring-patch.md, architectural-generator-playtest.md]
---

# FRAMEWEAVER × MOSAIC — experimental Workbench evaluation

This candidate remains **Draft/HOLD**. It adds a separate experimental
composition panel; it does not become a production generator preset. Read the
package's `candidate-manifest.json` for the exact source and binary identities.
Automated Windows qualification requires matching graphical receipts from both
the source project and a pristine extraction of this ZIP. **Owner visual
acceptance remains pending** until the owner reviews the matching candidate and
records that decision. A cross-built DLL, headless test or screenshot from
another source does not establish Windows qualification.

## Open the candidate

Extract the complete Windows ZIP, then double-click **Open Workbench.cmd**.
Keep its Godot executable, native extension, reciprocal generator, runtime
licences and manifest together. The initial asset import is followed by ordinary
Shared Workbench. Open **Reciprocal assembly…** to reveal one inline dock.
Opening the dock does not generate a construction or start a child process.

Pause the World before authoring. The panel captures the real paused native
material cells and builds only in empty, unprotected space. Existing material
and physical body masks remain authoritative.

## Paint and generate

1. Select **Industrial**, **Viaduct-like** or **Irregular megastructure**.
   Expression selection loads five structural control presets. Decoration and
   destruction remain independent controls.
2. Leave **Paint territory** enabled and draw a short approximate stroke on the
   native canvas. The stroke supplies locations and distribution. It is not a
   building-outline or gesture recognizer.
3. Set the crop width and height, up to **256 × 128** cells. The default crop is
   **192 × 112**. Its blue outline follows the stroke's centre and stays inside
   the existing canvas. The native world's size limits are unchanged.
4. Choose **Ownership**: FRAME left / MOSAIC right, FRAME top / MOSAIC bottom,
   or FRAME centre / MOSAIC surround. The centred rectangle spans the middle
   half of each crop dimension. **Clear border** leaves zero to sixteen cells
   unclaimed around the crop. Set **Interface reach**, from zero to thirteen
   cardinal steps from the facing interface cells; zero removes interface hints
   and leaves no shared cells. With **Allow negotiated territory sharing** enabled, the green
   zone is the exact finite negotiated territory. Disable that checkbox for
   fixed ownership: the amber interface band still supplies negotiation hints,
   while each Gentek stays in its own territory. New experimental docks start
   with sharing disabled, following the selected fixed-territory native variant.
   Existing v1 requests and saved recipes retain their original sharing identity.
5. Optionally switch the brush to **Protect passage** and paint traversable
   space that must remain untouched. Protected cells appear cyan.
6. Set the seed, structural controls and zero to four negotiation rounds.
   Two rounds is the initial experimental default, not a success guarantee.
   Use the qualification receipt's exact recipe when reproducing its example.
7. Click **Generate**. The bounded native executable returns immutable
   provisional rounds, accepted material IDs, ownership and rule provenance.
   **Cancel**, closing the dock, timeout or exiting Workbench retires pending
   generation and leaves the installed World unchanged.

| Control | Native request field |
| --- | --- |
| Complexity / variation | `variation` |
| Branching | `branching` |
| Irregularity | `irregularity` |
| Environment affinity | `environment_affinity` |
| Cohesion | `cohesion` |
| Decoration | `clutter` |
| Destruction | `destruction`, a separate derivative after intact negotiation |
| Orientation | Balanced, horizontal or vertical preference |
| Optional negotiation | Enables or disables optional negotiation without relaxing required sockets |

Every normalized control ranges from zero to one. Gentek rules and components
remain authored outside Workbench. This interface contains no programming or
visual grammar editor.

The shared controls apply to both Genteks by default. Enable **Independent
FRAMEWEAVER controls** or **Independent MOSAIC controls** to expand that Gentek's
seven controls. First enable copies the current shared values; subsequent edits
affect only that Gentek. Disabling the override returns it to the shared controls.
Decoration and destruction remain separate controls in each profile, with
destruction initially off. The evidence receipt retains both actual profiles.

## Two fixed evaluation recipes

The qualification executes both examples below. Each uses **New blank** with a
**512 × 512** native canvas, a **128 × 96** crop, **Viaduct-like**,
**FRAME centre / MOSAIC surround**, clear border **4**, interface reach **13**,
balanced orientation, optional negotiation enabled, and **2** rounds. Place one
activation dab at native cell **64,48**; the resulting crop origin must be
**0,0**. Leave the independent Gentek overrides disabled for these two recipes.

| Setting | Reciprocal example | Retained transaction example |
| --- | --- | --- |
| Seed | **4099** | **605** |
| Allow negotiated territory sharing | **Disabled**: fixed ownership | **Enabled** |
| Decoration | **0** | **0.15** |
| Destruction | **0** | **0** |
| Required native evidence | Both occupied footprints revise; **8 joints** and **8 foreign-closed obligations** | **Zero joints**, **zero required foreign obligations** |
| Purpose | Reciprocal native construction exercised through authoring and persistence | Original Generate/Apply/Undo/Save/reopen regression |

Both Genteks use the authored Viaduct-like structural values: variation **0.65**,
branching **0.55**, irregularity **0.05**, environment affinity **0.25**, and
cohesion **0.35**. Preserve interface reach **13** for the fixed-ownership example:
disabling negotiated sharing keeps its transition hints, while setting reach to
zero changes those hints and therefore changes the experiment.

Seed4099 is a known-seed compatibility example, selected with independent native
offer controls. The UI test derives occupied/empty revisions from the native
round arrays and checks qualified joints and complete foreign closure. This
authoring example does not replace the programme's separate causal controls,
native corpus or held-out evaluation. Seed605 remains the original zero-joint
transaction example. It cannot satisfy the reciprocal example's witness gate.

The [UI test](../../godot/tests/swarm45_reciprocal_ui.gd) and
[qualification runner](../../tools/swarm004/qualify_workbench.py) keep these
recipes fixed. An inherited seed605 override cannot substitute for reciprocal
seed4099. Retain a failed result with its original recipe instead of tuning the
seed or controls until it passes. Both examples require Generate, Apply, Undo,
ordinary Save and a fresh-process reopen on the exact source and packaged build.

## Inspect the native proposals

The **Materials** preview uses actual native material IDs and the ordinary
material palette. Switch the view to **Owners**, **Parts**, **Revisions**,
**Changed cells**, **Joints**, **Clearance**, **Shared zone** or **Unresolved**.
Click a cell to inspect its native material, owner, structural instance, rule
and accepted revision history. **Sockets / receptors** adds red required,
gold optional and cyan locally terminable contracts, with short white facing
marks. Clicking nearby shows the owning Gentek, family, state and counterpart.
This shows native offers and socket contracts; only the qualified **Joints**
layer establishes accepted material paths. **Interface band** shows the retained
transition hints independently of the permitted **Shared zone**.

The round selector shows each independent provisional proposal. The inspector
reports whether each Gentek's proposal was accepted, its material-ID changes,
its occupied/empty footprint changes and accounted work. Magenta in provisional
ownership means competing claims. The final accepted revision ledger and
path-qualified joints belong to **Final composition**; they are not projected
onto an earlier rejected proposal.

Destruction is reported as a separate phase. It does not count as reciprocal
revision. Final material cells and obligations are validated again after that
phase. Stone keeps its existing native Powder behavior; neither a solver
assignment nor a rendered construction proves physical stability.

Blocked, incompatible, categorically UNSAT, bounded-exhaustion and invalid
results remain useful negative examples. **Apply construction** stays disabled
unless the native composition explicitly authorizes it. A local cap never
satisfies a foreign-required socket.

## Apply, Undo and Save

**Apply construction** prepares one native successor against the captured source
fences and exact original cells. Successful acknowledgement swaps it atomically
and adopts one staged authoring operation. Failed preparation cannot leave a
partial building in the live World.

**Undo construction** captures a fresh paused source and submits the exact inverse
native patch. It restores the prior authored history. If simulation or another
authoring operation changed the World after Apply, that construction Undo is
retired; it does not rewind arbitrary simulation or actor history.

Use ordinary **Save start [Ctrl+S]** to save the acknowledged construction as a
normal starting map. The optional `.swarm004.json` receipt and
`.swarm004-evidence.json` file retain the source, proposal rounds, ownership and
joints. They are evidence, not another World cell store. If authoring history
changed after the construction, an older receipt is not attached to the new map.

Close CyberSand completely, launch the candidate again and use **Load start**
with the same map name. The ordinary saved map reconstructs native cells in a
fresh process. Open the reciprocal dock and click **Inspect saved evidence** to
read its bounded, hash-bound historical receipt. Historical evidence cannot
authorize another Apply; regenerate against the current native World first.

## Qualification and reporting

The explicitly requested `swarm004-workbench-windows.yml` workflow has one pinned
cross-build job and one Windows graphical job. Fast request and evidence-gate
tests run before the native build. It builds the native adapter and reciprocal
executable from the exact integration commit. The Windows runner uses pinned
Godot 4.7 and real UI input. It runs both fixed recipes in separate fresh user
profiles, then repeats the complete sequence from a pristine owner ZIP. The
packaged launcher clears external reciprocal-generator overrides so ordinary
owner launch uses the bundled source-bound generator and manifest.

While the new workflow is held off main, the already registered
`architectural-generator-qualification.yml` provides a narrow manual route:
dispatch it on exactly `experiment/gentek-swarm-004-workbench`. Only that
workflow-dispatch/ref pair delegates to the SWARM-004 jobs and skips the unrelated
architectural-generator campaign. Other refs keep their existing behavior.
An additional execution route is restricted to that same exact branch and a
change to `.github/swarm004-windows-request.json`. Publish the frozen source
first, then make a separate request-only execution commit. The JSON request is
at most 4 KiB and has exactly `schema: 1`, `programme: "GENTEK-SWARM-004"`,
`action: "qualify-windows"`, the frozen commit in `source_sha`, and an explicit
`request_id` of at most eighty ASCII letters, digits, periods, underscores or
hyphens beginning with a letter or digit. The source must be a proper ancestor;
every intervening commit must change only that request file, with no merge or
hidden source-change/revert history. At most sixteen request-only commits may
follow the declared source. Both jobs validate the same receipt and build and
qualify the **current execution HEAD**, recording the frozen source, request
hash and execution identity. The helper tests use isolated temporary Git
repositories and never create an active request in the project.

Ordinary code pushes and pull requests do not start these Windows jobs. This
route retains read-only contents/actions permissions and the existing
GitHub-hosted provider. It contains no Ready promotion, merge or retained-runtime
publication job. The run request is created only for an explicitly authorized
bounded evaluation; its presence in older source does not trigger later code
pushes.

Automated qualification requires original graphical captures, complete native
plane comparisons after preview, Apply, Undo and regeneration, successful
ordinary Save, and distinct reopen processes with exact native material
readback. Actual child cleanup on Cancel, close, timeout and Workbench teardown
runs once per source/package evaluation. Native adapter, protocol, controller
and independent-Gentek control assertions run separately in headless mode.

Each source or pristine-package evidence directory contains:

| Path | Evidence |
| --- | --- |
| `source-runtime-identity.json` | Exact source, engine, adapter, generator and script identities; both fixed recipes |
| `headless/` | Native adapter, transport, controller and `SWARM004_CONTROLS` assertions |
| `transaction/` | Separate seed605 create/reopen reports, logs, profile, complete expected native plane, and five original PNGs |
| `reciprocal/` | Separate seed4099 create/reopen reports, logs, profile, complete expected native plane, and five original PNGs |
| `lifecycle/` | Actual child cancellation, close, timeout and teardown reports |
| `qualification.json` | Combined gates, per-example plane and screenshot hashes, and distinct process identities |

The five captures in each example are `native-preview.png`,
`native-applied.png`, `native-undone.png`, `native-saved.png` and
`native-reopened.png`. The runner checks complete PNG containers, matching native
recipes and receipts across processes, and full **512 × 512** material planes.
For reciprocal4099 it additionally requires two occupied-footprint changes,
qualified joints and complete foreign closure; counters alone cannot stand in
for those array-derived witnesses.

`windows_automated_authoring_qualification: true` records these automated checks.
It leaves `owner_visual_acceptance: "pending"` and
`reciprocal_programme_acceptance: false`: visual owner review and the wider native
research assessment require their own evidence. No result promotes Draft/HOLD
to Ready or authorizes a merge. Inspect the source and pristine-package receipts
and original captures together; an exit code or executable alone is insufficient.

When reporting a result, include the package source commit, seed, expression,
crop dimensions, interface reach, sharing policy, rounds, all seven controls for
each Gentek, whether optional negotiation was enabled, the native status and the
saved evidence receipt. Record whether the result is automated qualification or
an owner's visual assessment. Keep the original negative result if the
composition cannot be applied.
