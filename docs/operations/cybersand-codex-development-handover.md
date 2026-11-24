---
title: Development handover
status: Current
document-kind: guide
scope: Current task intake, ownership and handoff; implementation status, intent and qualification have separate canonical homes
canonical-for: [development-onboarding]
last-reviewed: 2026-11-24
related-documents: [source-checkpoint-and-recovery.md, local-build-and-validation.md, github-development-and-release.md, documentation-maintenance.md, ../reference/status-and-roadmap.md, ../reference/product-intent-and-priorities.md, ../architecture/data-ownership-and-lifetimes.md]
---

# Development handover

CyberSand is a native material simulation and paint-and-play authoring system
hosted by Godot. Begin with the user's current task and the actual checkout. This
page routes work; it does not assign an old branch, authorize a merge or replace
the owning subsystem contract.

**Reviewed against accepted main `00cdb02f103265b6dc5224c68283e9a0c8cb449f`
on 24 November 2026.** The [current-state register](../reference/status-and-roadmap.md)
owns accepted features, active candidates and unresolved choices. Refresh those
records before acting. The [documentation portal](../README.md) is the audience
index; [build and validation](local-build-and-validation.md) owns commands.

## Start here for the next task

1. Read [AGENTS.md](../../AGENTS.md), the user's current authorization and this
   handover. Use the [README](../../README.md) to understand the application and
   the [roadmap](../reference/status-and-roadmap.md) to distinguish accepted source
   from candidate work.
2. Inspect the actual Git root, branch, HEAD/tree, local changes, upstream and LFS
   state. Preserve unrelated work. A path in a September handover is a historical
   machine location, not the required location of today's checkout.
3. Read the canonical subsystem/ADR for the change and its referenced source.
   Use the [retrieval index](../reference/retrieval-index.md) for a focused
   question. Read specific historical evidence only when the question needs it.
4. Inspect the relevant live issue/PR, exact head and changed-file set. Confirm
   who owns overlapping implementation. A feature's original PR may be merged
   while a repair or evaluator remains unmerged.
5. Agree or record a narrow write set and the evidence needed for the task.
   Reuse source-matched evidence where valid; do not start an expensive native
   or graphical campaign merely to validate prose.

The source repository is `techrote/cybersand`. Companion workspaces and reference
art repositories have their own histories and purposes. They are not alternate
source roots. [Source checkpoints](source-checkpoint-and-recovery.md) explains
identity and recovery; [product intent](../reference/product-intent-and-priorities.md)
explains the intended paint-and-play direction.

## Establish source and runtime identity

From the intended source checkout:

```bash
git rev-parse --show-toplevel
git status --short
git branch --show-current
git rev-parse HEAD 'HEAD^{tree}'
git log -1 --format='%H %cI %s'
git lfs ls-files
```

Review remote configuration locally if needed; do not paste credential-bearing
URLs into an issue or report. `git lfs ls-files` identifies tracked objects; it
does not prove every required object is materialized or that the runtime matches
changed native source. Run the appropriate
[repository/provenance check](current-and-historical-validation.md) and compare
the selected runtime's input ledger before launch or packaging.

The pinned executable version is `4.7.stable.official.5b4e0cb0f` in
[the Godot lock](../../third_party/godot-runtime.lock.json). A nearby patch release
is not the same qualification target. The native locks, per-platform runtime
provenance and Rapier provenance are separate records. A documentation-only head
can legitimately retain a runtime built at an earlier commit when all recorded
source inputs still match; do not relabel its build commit as the documentation
head. Conversely, matching a DLL filename does not establish source identity.

Use an isolated test profile for application procedures. Do not overwrite owner
maps, Art archives, provider settings or ordinary user data to make a test pass.
Portable evaluators, source checkouts, rebuilt runtimes and Web/fallback paths
have different prerequisites; [getting started](getting-started.md) and
[local builds](local-build-and-validation.md) explain them.

## Choose the correct owning contract

| Task | Read first | Preserve |
|---|---|---|
| Painting, generator application, Art drawing or history | [Shared authoring](../architecture/shared-workbench-authoring-data.md), [direct batches](../systems/workbench-direct-art-batches.md) | Baseline/revision identity, one edit ordering, native completion receipts, bounded cancellation and history semantics. |
| Save, Flatten or persistent-area work | [Save formats](../reference/level-saves-and-replay.md), [owner Save intent](../reference/product-intent-and-priorities.md#save-flatten-and-compatibility) | Authored layout versus live physical state; Flatten is a two-byte material plane and does not reset the live World. Persistent-area candidates have separate owners. |
| Materials, Water, reactions or Lab | [Materials](../systems/materials-and-rule-kernels.md), [Water families](../architecture/liquid-solver-family-policy.md), [Lab](materials-lab-authoring.md) | Material identity, effective consumers, family-specific quantity/physics, immutable compatibility evidence and reviewed source transitions. |
| Actors, equipment or destruction | [Actor composition](../systems/workbench-actor-composition.md), [coupling](../architecture/rigid-body-and-cellular-coupling.md) | Main-thread Rapier, native material authority, producer leases and actual accepted capabilities. ObjectShard/actor/equipment successors remain separate candidates. |
| Rendering, scheduling or physical progression | [Threading](../architecture/simulation-tick-and-threading.md), [rendering](../architecture/rendering-and-gameplay-bridges.md) | Snapshot lifetime, accepted worker ownership, physical progression evidence and public receipt identity. PUBPRES findings do not silently select a new architecture. |
| Strata or scene depth | [Depth layers](../systems/depth-layers-and-parallax.md), [semantic planes](../systems/procedural-semantic-planes.md) | Standalone layered owners versus ordinary Workbench integration; Strata Theatre names the four-layer feature only. |
| Provider integration | [Art providers](../systems/workbench-art-providers.md), [Art guide](workbench-art.md) | Current session-only lifetime, actual transport/receipt states, credentials and private traffic boundaries. No paid dispatch from a documentation test. |
| Build, qualification or publication | [Build](local-build-and-validation.md), [release](github-development-and-release.md), [validation](testing-validation-and-replay.md) | Exact source/artifact/platform evidence, mandatory tests, guarded publication leases and explicit owner merge authority. |

## Concurrent implementation and documentation

The [active-candidate register](../reference/status-and-roadmap.md#active-candidates-and-integration-boundaries)
routes PUBPRES, ObjectShard, Actor Compose, Equipment, RAMCACHE, SWARM, Batch Lab,
Gremlin, Materials Lab audition, Strata Theatre, Art, PAINT and CI work. Their
principal records own changing heads, blockers and qualification details. Do not
copy their entire live ledgers into this handover.

Use an isolated branch/worktree based on a freshly inspected main. Keep another
mission's uncommitted work and source branch intact. Reconcile mechanical main
deltas without waiting for a policy decision; when a substantive design choice
is necessary, follow the existing
[design-choice procedure](github-development-and-release.md#reconciliation-and-design-choices).
Document accepted-main facts in the cross-project guides. Leave candidate-specific
instructions in the candidate's owning guide until its source is accepted.

Before final delivery, refresh main and inspect any accepted delta affecting the
claims or inputs. A later merge may need a focused status/guide correction. It
does not justify importing all active candidates or waiting indefinitely for
every concurrent programme.

## Current execution-order rule

**GitHub issue numbers are not a serial task order.** The
[MicroScenarios programme](microscenarios-programme.md) owns #24/#27–#30 routing;
the [architecture programme](architecture-programme.md) owns the separate
#14/#18/#20 gates. The landed INT-000 infrastructure is not permission to restart
its old preflight branch. A scenario can expose a defect without hiding a new
material law inside scenario code.

The [development-claims remediation programme](development-claims-remediation-programme.md)
separates implementation, integration, verification, acceptance and disposition.
Historical #10/#11 evidence does not certify broad player/body-granular feel.
Likewise the [Water programme](water-hybrid-pressure-extension-programme.md)
preserves #26's exact negative results, #49's corrected successor apparatus and
#45's NARROW decision. Accepted Wave/ballistic paths and Liquid Comparison Build
have distinct scopes; do not turn old unsigned-policy restrictions into a blanket
prohibition on current Water behavior.

## Foundational work boundary

Native C++ owns authoritative cells. Desktop uses an asynchronous GDScript owner;
Web completes native ticks synchronously on the main thread with its supported
internal native pool. Rapier scene objects stay main-thread owned. Native pool
workers call no Godot APIs. Immutable snapshots retain ownership until consumption
ends; rendering does not read mutable World storage. See
[ownership](../architecture/data-ownership-and-lifetimes.md).

Failed ticks quarantine a partially mutated World until explicit reset or
validated replacement; no automatic retry or rollback is implied. Interest-region
re-entry wakes paused resident work within the accepted contract; it is not
persistent-area time catch-up. Preserve bounded work, explicit capacity outcomes
and current/proposed distinctions in [invariants](../reference/invariants.md).

Source-defined controls, exact native fixtures, graphical rendering, packaged
startup and physical owner acceptance are different claims. A progress counter,
render FPS or a compile pass does not establish playable physics. The existing
recording tools also do not supply a general serialized coupled replay format.

## Finish a checkpoint

Apply the [documentation checklist](documentation-maintenance.md#documentation-update-checklist).
Update the owning contract, user controls, interface/default/limit references,
current-state entry and retrieval routes together. Search for old values and
incoming links; preserve dated failures and exact evidence identities.

Record each validation command and its source, runtime, platform, exit result and
scope. Distinguish PASS, FAIL, NOT RUN, SKIP and BLOCKED. A Draft-suppressed test is
SKIP, not PASS. Run focused checks for the changed behavior, then satisfy the
applicable release gates when the task actually authorizes that stage. Use the
[current versus historical gates](current-and-historical-validation.md) instead
of rewriting M11 hashes to match today's implementation.

Prepare a reviewable commit/PR with the concrete problem, resulting behavior,
validation, remaining limitations and any substantive design choice. Follow the
current task's Draft/Ready boundary. Explicit owner actions such as merge,
release, default promotion and deletion are not granted by an old handover.

For documentation-only work, structural and retrieval qualification does not
claim a new engine or physical-platform acceptance. A final response should link
the candidate, identify source/head/tree, summarize the useful reader changes and
state what remains unresolved.

## Earlier checkpoints and recovery evidence

The complete previous handover remains at
[its immutable accepted-source revision](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/operations/cybersand-codex-development-handover.md)
and in the [documentation preservation record](../audits/2026-11-24-docs-renaissance/README.md).
It retains former branch assignments, Windows paths, source hashes, failures and
qualification instructions in their original dated scope. Use it deliberately
for evidence recovery, not as an automatic task queue.
