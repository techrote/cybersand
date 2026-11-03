# SCHEDUSWARM.md — CyberSand v2 dispatcher policy

```yaml
scheduswarm_version: 2
status: paused
hub: https://github.com/techrote/scheduswarm
queue_branch: scheduswarm/queue
coordination_ledger: https://github.com/techrote/cybersand/issues/305
max_active_lanes: 3
project_concurrency_budget: 2
successors_per_lane: 1
integration_writes_parallel: false
automatic_dispatch_allowed: false
```

## Authority

Scheduswarm does not override `AGENTS.md`, the development handover, documentation index, roadmap, canonical programme dependency graphs, ADRs, release policy, source/LFS provenance or manual qualification gates.

**CyberSand is paused.** Queue provisioning or free dispatcher capacity does not authorize restarting PLAY or any other programme.

## Queue and completion

When explicitly reactivated, the dispatcher watches `scheduswarm/queue:.scheduswarm/tasks/*.md`.

Workers write completions and successor task envelopes to the queue branch instead of creating scheduled tasks. A normal lane may create zero or one same-lane successor; extra parallel tasks require lane admission and capacity.

## Limits when active

Maximum active lanes: **3**. Project concurrency budget: **2**. Same-lane successor maximum: **1**.

| Lane | Purpose |
|---|---|
| critical-path | current epic/dependency-critical implementation |
| qualification | CI/runtime/evidence/manual-qualification preparation |
| independent | genuinely parallel subsystem/readiness work |
| integration | serialized roadmap/handover/release/status reconciliation |

Issue numbers are not execution order; canonical programme dependency documents determine readiness.

## Serialized surfaces

Only integration work should intentionally update shared project-wide authority while multiple lanes are active: development-handover current state, status/roadmap dependency state, release/validation ledgers, shared epic status consuming multiple lanes, and project-wide source/provenance checkpoints.

## Safety gates

- Preserve native C++ cell authority, Godot/main-thread boundaries, immutable snapshot ownership and Rapier/Water contracts.
- Draft green checks do not equal release qualification.
- Source/runtime/manual evidence classes remain distinct.
- Do not rewrite historical M11/audit hashes or promote stale runtime evidence.
- Physical-device/human-feel gates cannot be replaced by automation.
- Do not restart a paused programme merely because queued tasks exist.

## Dispatch commissioning

`status: paused` and `automatic_dispatch_allowed: false`. Explicit owner/project activation must change status before any task may dispatch.

## Live ownership

Use issue #305, branches/PRs and immutable queue records. Avoid a shared mutable current-state document.
