---
title: Shared workbench authoring data and convergence
status: Approved design
document-kind: contract
scope: Common authored baseline, edits, live-session separation and incremental workbench integration; successor requirements are not implementation claims
canonical-for: [shared-workbench-authoring-data, workbench-convergence-plan]
last-reviewed: 2026-11-08
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

## Common authored document semantics

**Approved requirements for convergence:**

| Part | Meaning |
|---|---|
| Baseline | Starting terrain supplied by existing ordinary setup, verified procedural reconstruction, or a future standalone material snapshot |
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

**Approved convergence requirement:** generated install, Load, Restore and future
Flatten use the existing prepared-World transaction and one owner commit/adoption
boundary. Before replacement commits, retire/fence active agent tasks and pending
proposals. Results from an older session/World generation/revision must not
authorize edits in the replacement. Refused/cancelled preparation preserves the
installed World and valid authored configuration/files. Preview/cancel remains
non-mutating. Actor and collider lifetime follows the existing host/Rapier owner.

Generation integers are not globally unique across processes. Remote identity
must include its owner/session identity plus native generation/revision. A client
reconnect to a live World is distinct from a fresh process or service restart.
Persistent transport sessions do not imply persistence of evolved simulation.

## Flatten successor and storage compatibility

**Approved semantics, implementation Planned:** [#548](https://github.com/techrote/cybersand/issues/548)
owns intentional lossy Flatten. Capture complete native **stored material IDs**
at an acknowledged, fenced tick boundary, after accepted queued painting;
never derive authority from rendered/dithered Water or ballistic presentation.
After transactional installation, exact per-cell material IDs match the capture,
tick/runtime state resets to defaults and the discarded strokes do not replay.
Preserve supported actors with their observed positions as new spawns, reset
transient motion, and refuse invalid actor placement rather than dropping actors.

Flatten is an in-editor transformation and does not Save automatically. A later
Save must reconstruct the standalone baseline and subsequent edits without the
discarded recipe/history. Old recipe/seed may be descriptive provenance only.
Prefer one bounded pre-flatten authoring rollback; that restores authoring
baseline/history, not mid-tick physical state. If retention exceeds budget, offer
cancel or separately confirmed irreversible discard before commit. No hidden
indefinite history. General Undo/Redo remains a separate successor.

**Approved compatibility boundary:** retain Setup-v2 and generated-start v1
readers; version and validate a separate standalone material encoding before
implementing it. Current end-to-end IDs are 8-bit; do not truncate or implicitly
admit a 16-bit catalogue. A 2048-square raw 8-bit baseline alone is 4 MiB, unlike
the bounded 1 MiB recipe manifest. Codec/container layout, atomic multi-payload
save strategy, total staging/rollback budgets and measured latency/peak memory
remain **Planned decisions for #548**, not a new limit or API in #542. Reject
unknown/truncated/corrupt encodings and preserve valid prior saves on failure.

**Deferred:** sparse/content-addressed chunks, streamed-world Flatten, Deep export,
complete physical-state saves and a general operation journal. They are not
prerequisites for finite-World Flatten or #542 review.

## Incremental source convergence plan

**Approved direction; implementation joins remain Planned.** Reconcile/rebase as
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

#548 additionally requires its full per-cell stored-ID comparison, actor reset,
bounded rollback/discard, corruption/capacity/failure controls and fresh-process
standalone-baseline persistence. Human GUI acceptance is separate from hosted
graphics. No new numeric performance target is asserted by this contract.
