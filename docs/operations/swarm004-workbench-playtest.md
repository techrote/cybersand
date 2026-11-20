---
title: SWARM-004 experimental reciprocal Workbench evaluation
status: Planned
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
Windows acceptance requires the matching graphical qualification receipt from
both the source project and a pristine extraction of this ZIP. A cross-built
DLL, headless test or screenshot from another source is insufficient.

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
   unclaimed around the crop. Set **Shared reach**, from zero to thirteen
   cardinal steps from the facing interface cells; zero disables shared
   ownership. The green zone is the exact finite negotiated territory.
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

The fixed transaction example uses seed **605**, **Viaduct-like**, **128 × 96**,
**FRAME centre / MOSAIC surround**, clear border **4**, shared reach **13**,
balanced orientation, optional negotiation enabled, **2** rounds and decoration
**0.15** with destruction **0**. Other structural controls use the expression's
authored preset. On a blank canvas, place one activation dab at native cell
**64,48**. This recipe came from the preregistered known-seed layout matrix. Its
native result has **zero joints** and **zero required foreign obligations**; it
is an authoring transaction example, not evidence of reciprocal joint success.
The graphical qualification must still demonstrate Generate, Apply, Undo, Save
and a new-process reopen on the exact packaged source.

## Inspect the native proposals

The **Materials** preview uses actual native material IDs and the ordinary
material palette. Switch the view to **Owners**, **Parts**, **Revisions**,
**Changed cells**, **Joints**, **Clearance**, **Shared zone** or **Unresolved**.
Click a cell to inspect its native material, owner, structural instance, rule
and accepted revision history.

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
cross-build job and one Windows graphical job. It builds the native adapter and
reciprocal executable from the exact integration commit. The Windows runner
uses Godot 4.7 and real UI input, then separately repeats authoring and reopening
from the pristine owner ZIP.

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

Acceptance requires original graphical captures, a complete full-plane native
comparison after preview, Apply and Undo, successful ordinary Save, a distinct
reopen process with exact native material readback, and actual child cleanup on
Cancel, close, timeout and Workbench teardown. The repository also retains
separate native adapter and transport tests. Inspect `qualification.json`,
`source-runtime-identity.json` and their logs; do not infer acceptance merely
from a process exit code or a packaged executable.

When reporting a result, include the package source commit, seed, expression,
crop dimensions, shared reach, rounds, all seven controls, whether optional
negotiation was enabled, the native status and the saved evidence receipt. Keep
the original negative result if the composition cannot be applied.
