# SCHEDUSWARM.md — CyberSand task-lane policy

```yaml
scheduswarm_version: 1
status: configured-paused
hub: https://github.com/techrote/scheduswarm
coordination_ledger: https://github.com/techrote/cybersand/issues/305
max_active_lanes: 3
project_concurrency_budget: 2
successors_per_lane: 1
integration_writes_parallel: false
```

## Authority

Scheduswarm does not override `AGENTS.md`, the development handover, documentation index, roadmap, programme dependency graphs, ADRs, release policy, source/LFS provenance or manual qualification gates.

The project is **configured but paused**. Scheduler capacity alone does not authorize restarting PLAY or any other CyberSand programme.

## Limits

**Maximum active lanes = 3.** Up to three logical chains may exist if the owner/project explicitly activates Scheduswarm work.

**Project concurrency budget = 2.** At most two CyberSand lanes should intentionally execute or be launched in the same coordination window; a third is staggered/waiting.

## Lane classes

| Lane class | Purpose | Typical ownership |
|---|---|---|
| critical-path | current epic/dependency-critical implementation | one issue/subsystem/PR |
| qualification | CI/runtime/evidence/manual-qualification preparation | distinct harness/evidence surfaces |
| independent | genuinely parallel subsystem/readiness work | non-overlapping source/docs/tests |
| integration | serialized roadmap/handover/release/status reconciliation | shared authority surfaces |

Issue numbers are not execution order; canonical programme dependency documents determine readiness.

## Serialized surfaces

Only the integration owner should intentionally update shared project-wide authority while multiple lanes are active, including:

- development handover current-state integration;
- status/roadmap dependency state;
- release/validation ledgers;
- shared epic status that consumes multiple lane results;
- project-wide source/provenance checkpoint records.

Parallel lanes use isolated branches/PRs and may prepare proposed integration changes.

## Safety gates

- Preserve native C++ cell authority, Godot/main-thread boundaries, immutable snapshot ownership and existing Rapier/Water contracts.
- Draft PR state intentionally suppresses expensive CI; do not treat draft green checks as release qualification.
- Source/runtime/manual evidence classes remain distinct.
- Do not rewrite historical M11/audit hashes or promote stale runtime evidence.
- Physical-device/human-feel and other manual gates cannot be replaced by source-only automation.
- Do not restart a paused programme just because free Scheduswarm capacity exists.

## Live ownership and handoff

Use issue #305 comments plus branches/PRs as append-only lane ownership. Each claim states lane/class, target issue/acceptance criterion, branch/PR/write set, dependencies/non-goals, successor task ID and stop/throttle reason.

Every run must freshly inspect actual HEAD/branches/PRs, source/runtime/LFS provenance, review threads and exact-head CI before writing. One successor per lane; new parallel lanes require dependency independence, non-overlap and capacity.
