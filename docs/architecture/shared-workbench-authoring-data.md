---
title: Shared workbench authoring data and convergence
status: Current
document-kind: contract
scope: Shared authored baseline, acknowledged edits, material-only Flatten, standalone persistence and live-session separation
canonical-for: [shared-workbench-authoring-data, workbench-convergence-plan]
last-reviewed: 2026-11-13
related-documents: [../systems/explore001-generated-playable-maps.md, ../reference/product-intent-and-priorities.md, ../reference/status-and-roadmap.md, data-ownership-and-lifetimes.md, ../operations/github-development-and-release.md]
---

# Shared workbench authoring data and convergence

## Approval and current boundary

**Approved, 2026-11-08:** the owner directs incremental convergence of exploratory
authoring implementations into the ordinary main Shared Workbench. Desktop,
local-agent and remote-client interfaces share native authority, reconstruction,
authoring and persistence semantics; their permissions and budgets may differ.
This is a common semantic contract, not a newly implemented schema or permission
to promote every experimental feature. Preserve each feature's acceptance gates.

**Current candidate:** EXPLORE-001 PR #542 at `9319e689` reconstructs generated
terrain using generated-start v1 around unchanged Setup-v2. Its baseline comes
from the exact GEN-007 recipe/global region and material/source receipts; ordered
edits and actor spawns reconstruct the authored start. It does not save evolved
simulation state. Source: `godot/scripts/workbench_generated_map.gd`,
`workbench_setup.gd`, `shared_workbench.gd` and `workbench_generator_dialog.gd`.
The [generated-map contract](../systems/explore001-generated-playable-maps.md)
owns current formats, capacity and user controls. Accepted main remains distinct
from a reviewed or runtime-qualified PR.

**Unmerged successor candidate, 2026-11-10:** #559 Stage 1 adds direct batch drawing and worker completion in the existing owner; see the [direct art batch contract](../systems/workbench-direct-art-batches.md). It records confirmed edits in unchanged Setup-v2, without importing #531 runtime admission rules.

**Integrated candidate, 2026-11-11:** the
[PAINT + agent runbook](../operations/wb-art-paint-integrated-candidate.md) identifies
the current heads and their history-preserving reconciliation. It implements
native stored-material readback, reciprocal mutation/result exclusion, deferred
human completion and shared authored-history ordering. It retains both original
interfaces and uses the existing Setup/generated-start formats. It remains Draft;
its combined source-built acceptance is separate from either PR's earlier results.

**GEN-008 implementation candidate, 2026-11-13:** issue [#548](https://github.com/techrote/cybersand/issues/548)'s
**11 November revised specification** supersedes the earlier expanded Flatten
proposal. Accepted foundation `ac0d9fb944cb` includes #564/#565; this dedicated
Draft adds a native-backed authoring transaction on that foundation. The
[qualification and Owner workflow](../operations/gen008-flatten-qualification.md)
separates source-matched tests, retained-runtime publication and human acceptance.
Keep Draft/HOLD. The dated candidate paragraphs above retain their original scope.

## Common authored document semantics

**Approved requirements for convergence:**

| Part | Meaning |
|---|---|
| Baseline | Starting terrain supplied by existing ordinary setup, verified procedural reconstruction, or a versioned standalone material baseline |
| Authored changes | Ordered accepted edits after the baseline, including erase/replacement semantics; both human and agent changes must survive Save/reopen |
| Actors and configuration | Supported authored spawns, selection and applicable response/liquid/material policy; view metadata is separate from material content |
| Live session | Evolving native cells, tick, motion, active tasks and transient physics; not implicitly serialized by a starting-map Save |
| Provenance | Reconstruction-critical identity where required; descriptive origin/history must be distinguishable from required inputs |

These are semantic components, not mandated JSON keys or an unbounded operation
journal. Existing bounds remain enforced. Exhaustion must be explicit and must
not silently omit an accepted edit from the saved start. Ordinary Save persists
the authored start; Restore reconstructs it. Neither implicitly captures evolved
materials or promises deterministic coupled simulation replay.

**Approved:** use shared reconstruction/validation, native preparation/adoption
and authored-state recording services rather than interface-specific copies.
Native C++ remains authoritative; the existing worker owns installed cells.
Godot owns UI/input and main-thread scene/Rapier objects. Immutable copied
snapshots retain their existing lifetime. Remote adapters do not simulate cells.
An accepted queue entry is not proof of native application or durable recording;
future exact-cell authoring seams need acknowledged application and a defined
capacity/failure outcome for the authored record. This requirement is not a claim
that today's ordinary brush already has the agent bridge's durable receipts.

## World replacement and stale work

**Current/Approved convergence requirement:** generated install, Load and Restore
use the existing prepared-World transaction and one owner commit/adoption boundary.
Flatten has a separate authoring-data adoption boundary and never replaces a World. Before replacement commits, retire/fence active agent tasks and pending
proposals. Results from an older session/World generation/revision must not
authorize edits in the replacement. Refused/cancelled preparation preserves the
installed World and valid authored configuration/files. Preview/cancel remains
non-mutating. Actor and collider lifetime follows the existing host/Rapier owner.

Generation integers are not globally unique across processes. Remote identity
must include its owner/session identity plus native generation/revision. A client
reconnect to a live World is distinct from a fresh process or service restart.
Persistent transport sessions do not imply persistence of evolved simulation.

## Flatten and storage compatibility

**Current on the GEN-008 implementation branch; approved 11 November 2026:**
Flatten copies the complete current native **stored material IDs**, including
Empty and identities produced by material motion or reactions. It captures at a
completed tick boundary on the existing exclusive worker. It does not read RG8,
palette colours, fractional Water dithering, body masks or ballistic presentation.
The captured plane becomes the new authored baseline and earlier construction,
procedural reconstruction and manual/agent Undo/Redo history are discarded.
Subsequent supported edits use the same chronological history relative to it.

**The installed live World is unchanged.** There is no prepared-World call during
Flatten, no tick restart, cell-state initialization, actor respawn, Rapier rebuild,
velocity reset or change to simulation options/material laws. Simulation resumes
its ordinary owner loop after copying and may advance while the UI validates the
snapshot. Such later simulation changes are deliberately outside the captured
baseline. Actors retain live positions and velocities; their existing authored
spawns/configuration remain the normal Save/Load reconstruction inputs.

Flatten does not Save. Explicit **Save start** writes the standalone baseline,
supported acknowledged post-Flatten edits and unchanged Setup-v2 actor/configuration
metadata. **Load start** and **Restore start** construct a normal fresh World from
that data through the existing prepared native/Rapier transaction. Full saved
material identity is checked before publication. Old generator recipes, source
files and pre-Flatten painting instructions are unnecessary. Temperature,
velocity, fractional fluid quantity, airborne parcels, tick and other transient
physical state are not persisted by this material-only format.

### Native readback, edit fencing and failure atomicity

`CyberDemoBridge.capture_material_baseline` returns privately allocated, complete
LE16 bytes, extent, SHA-256 and source generation/revision/tick. It is invoked
only by `CyberSimulationWorker._consume_material_capture`, outside a native tick,
and reads `World::stored_material` without mutating the World. No pointer to live
cell storage crosses the boundary. A single finite copy and value handoff replace
per-cell cross-language reads. `validate_material_baseline` checks complete length
and the real native catalogue before any narrowing. Staging explicitly detaches
the PackedByteArray so an old readback cannot alter the retained authored plane.

The request refuses queued/executing PAINT, agent chunks, legacy brush commands,
unconsumed receipts and prepared replacements. A native queue admission is not
an acknowledged edit. While capture/staging owns its slot, new construction edits
are refused; ordinary simulation is not paused. The request carries worker/session
World generation, owner request revision, authoring generation and a **15-second
bounded deadline**. UI polling and Cancel never wait for a thread join. A cancelled
in-flight copy can finish on the existing owner, but its retired token cannot
publish a new baseline. A failed capture, allocation, validation, stale token or
owner fault retains the old authored baseline/history and existing saved files.

Once the whole baseline is staged, `material_capture_finish(token,true)` checks
the lease again and advances the authoring generation and editor epochs. Main
then swaps authoring references in the same callback, without yield or a native
write. The independent authoring generation is necessary because paused Flatten
does not change native World generation/revision/tick. Old PAINT requests are
refused even if those native values still match. Legacy requests without the new
field are admitted only in initial authoring generation one. Old provider replies,
agent chunks and deferred turns are retired on successful adoption. Failure does
not retire unrelated history or cancel a pending model request.

No Undo Flatten, previous-World rollback or special simulated-world capture mode
exists. Ordinary subsequent Undo/Redo and explicit Restore retain their existing
bounded semantics. A native owner that has already failed cannot be captured;
restart and Load a previously saved start. Process death before explicit Save
cannot change an existing named file.

### Standalone material-baseline v1 container

Canonical decoded storage is **unsigned 16-bit material IDs, little-endian,
row-major**: cell `(x,y)` starts at `2*(y*width+x)`. The live material catalogue
remains IDs **0–131 except reserved 10**. A 16-bit file does not widen `Material`,
change the eight-byte `PrecisionStorage` carrier or admit unsupported IDs.

| Extent | Exact raw material bytes | Raw size |
|---|---:|---:|
| 512 × 512 | 524,288 | 0.5 MiB |
| 1024 × 1024 | 2,097,152 | 2 MiB |
| 2048 × 2048 | 8,388,608 | 8 MiB |

Each dimension is 512–2048 in multiples of 64. The file keeps existing named-start
path discovery (`user://workbench/setup-<name>.json`); its contents are explicitly
sniffed for the binary magic before legacy JSON readers. No existing file is
migrated merely by loading it.

| Byte offset | Encoding | Meaning |
|---:|---|---|
| 0 | 8 bytes | `CYSFLAT` followed by zero |
| 8 | uint32 LE | Container version 1 |
| 12 | uint32 LE | Manifest length, at most 1 MiB |
| 16 | uint32 LE | Plane length, exactly `2*width*height`, at most 8 MiB |
| 20 | 32 bytes | SHA-256 over manifest bytes followed by plane bytes |
| 52 | UTF-8 JSON | Bounded manifest |
| 52 + manifest length | uint16 LE array | Complete row-major stored material plane |

The manifest contains exactly `format`, `version`, `encoding`, `width`, `height`,
`byte_count`, `sha256`, `starting_setup`. Format is
`cybersand-material-baseline-v1`; encoding is `uint16-le-row-major`; `sha256`
identifies the plane. The header checksum also protects actor/configuration/edit
metadata. `starting_setup` retains the existing Setup-v2 schema. Post-Flatten
edits are ordered overlays including Empty; they must not be compacted as a blank
canvas. Existing 32,768-record, native reconstruction-work and 1 MiB metadata
bounds remain; the dense plane is not disguised as rectangle edits. Maximum
container size is **9 MiB + 52 bytes**.

Read validates version, exact keys, dimensions, lengths, complete checksum,
current supported material IDs and the Setup metadata before preparation.
Unknown/truncated/corrupt encodings and excessive capacity are refused.
Write prevalidates, writes/flushes one unique temporary file, checks its complete
length and atomically renames the whole file over the named start. Failure removes
only that temporary file and preserves the prior valid save. Save does not sample
live cells. The two existing **Setup-v2 and generated-start-v1 readers remain
operational**; CYSD1 and CYPS2 are unchanged.

**Historical superseded proposal:** the 8 November document at
[`5ae183cf`](https://github.com/techrote/cybersand/blob/5ae183cf2bce98fe667801a7b609a586bfc274be/docs/architecture/shared-workbench-authoring-data.md)
and the early issue comment describe an 8-bit baseline, World replacement,
actor respawn, tick-zero reset and bounded Undo/discard framework. The owner
withdrew those requirements on 11 November. They are provenance only, not a
second active specification or an alternative mode.

**Deferred:** sparse/content-addressed chunks, streaming persistence, Deep export,
complete physical-state saves and a general operation journal. They are not
prerequisites for finite-World Flatten.

## Incremental source convergence plan

**Historical 8 November convergence register; later joins need current-source inspection.** Reconcile/rebase as
main advances and land qualified foundations promptly. Branch isolation protects
active work and evidence; it is not a permanent product split. Do not blindly
import unfinished branches or overwrite another owner's active files.

| Source/dependency at this checkpoint | Next bounded transition |
|---|---|
| #542 `9319e689`, based on main `1f82dac1` | Record this contract, promote only #542 to Ready under owner authorization, run resulting-head gates; no merge authorized |
| #529/#530 foundations consumed by #531 `3cb6792a` | Reconcile generated install/load/restore, task retirement and shared authored edits onto the admitted main source; preserve agent acceptance requirements |
| #545 `b7c62046`, stacked on #531; #547 `08e79b7b`, stacked on #545 | Restack transports after the shared foundation; keep one World/owner and common reconstruction. #545 currently starts ordinary Setup plus host stamps, not a qualified generated-manifest load path. Actual Codespaces acceptance remains separate |
| #543/#544 `e4bfd989` bounded shape planner | Admit one acknowledged exact-cell edit/recording seam before UI mounting; planning or queue admission alone is not persistence qualification |
| #402 `80bae884` and #409 `6bdab8ef` (stacked on #402) | Reconcile flyer options/Setup-v3/v4, actor configuration and explicit compatibility/migration tests; no competing save authority |
| #548 after the shared source/ownership handoff | Implement finite material-only Flatten and standalone save support on the common foundation; no implementation in #542 |

These heads identify the inspected checkpoint, not permission to force-update an
active branch. Re-read current heads/ownership before each join. Required order
follows dependencies and admitted source, not issue numbering. #542 need not wait
for the whole agent/transport stack to finish; no downstream gate is waived.

## Required integration evidence

**Planned join gate:** generate/install terrain in ordinary Workbench; authorize
an agent against that same World; apply/revise an edit; add human paint/erase;
Save; fully exit; reopen in another process; verify regenerated baseline, human
and agent edits and actor configuration; continue authoring. Assert native
application and authored-record outcomes, not just queue or UI success.

Replace/load/restore while a proposal is outstanding and verify stale refusal,
correct task retirement and unchanged state on failed preparation. Preserve
source-global versus local/agent coordinate frames. Run existing Workbench,
GEN-007/EXPLORE, painting and relevant agent/transport controls on the resulting
source with source-matched native libraries and Windows/Linux runtime evidence.
No combined pass is inferred from individually green branches.

#548 additionally requires full per-cell stored-ID comparison, unchanged live
World/tick/actor/transient state, stale-authoring refusal, corruption/capacity/failure
controls and fresh-process standalone-baseline persistence. Human GUI acceptance is separate from hosted
graphics. No new numeric performance target is asserted by this contract.
