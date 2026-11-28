---
title: Independent review of live-edit Workbench transaction delivery
status: Historical
document-kind: audit
scope: Specialist A review of Specialist B interaction and owner-delivery changes
last-reviewed: 2026-11-28
---

# Independent Workbench contract review

Specialist A authored the native batch implementation and independently reviewed
Specialist B's worker, port, visible-target and pointer scheduling integration.
This is a code review of the recorded source inputs, not a substitute for
Specialist C's real Workbench input and extracted-package qualification.

## Reviewed invariants

The worker admits bounded dictionaries and at most 4,096 targets. Terrain and
structural containers are exclusive; a terrain target is empty, and the request
position identifies the first target. Every structural target carries the same
owner/revision envelope and the displayed publication identity. Expected payloads
contain only the four integer fields. Unused nested containers cannot evade the
size guard and then enter a deep copy.

The port compares the native source-target echo and every native/World/session/
transport identity. It checks requested, unique, eligible and changed counts in
order; erasure removes exactly the changed count; ignition removes none; a changed
structural erase reports one geometry rebuild, and no-op/ignition/terrain report
zero. Terrain changed coordinates must be unique members of the requested set.
Malformed, lost or uncertain completion cannot be displayed as applied success.
A native quarantined or partial commit enters the existing uncertainty hold.

The visible picker uses the same pixel-centre inverse transform and highest-owner
foreground order as the native facade. All occupied carried material occludes
underlying terrain/owners, even when its Cargo/Product role is ineligible for
structural edits. Each multi-owner stage reacquires current targets from an
acknowledged displayed publication; it does not replay old owner witnesses.

Pointer service is offered before the next physical interval. One command may
be outstanding, transactions are rate-bounded, and fresh presentation must catch
up before further admission. Pointer release, tool/camera changes and scene
replacement retire unadmitted stroke state. Slice release explicitly commits
one immutable line with a two-second admission deadline and cancellation.
Drill/slice placement intentionally selects one owner, reports remaining domains,
and asks the user to repeat for other material. A cross-owner brush gesture is a
sequence of owner transactions, not an atomic scene-wide edit.

## Findings resolved before candidate freeze

The first review found that an unused `terrain_cells` container and a nonempty
terrain `target` could bypass the intended bounded payload branch. Specialist B
added exclusive-domain guards, empty-target/first-position proof and moving
same-owner validation. The first receipt check only enforced count inequalities;
it now verifies operation-specific removal and rebuild semantics plus the moving
owner, cell, body generation and pose echo. Re-review found these changes present.

Specialist B independently reviewed the native boundary and identified direct
facade first-position/empty-target checks and World mutation-journal generation
headroom. Native fixes now validate these before debit and preserve existing
single-cell, fragmentation, material ownership and semantic clock policies.

## Reviewed file identities

These hashes identify the reviewed working-tree content. Later source changes
require review of their delta and final hosted/package tests bind the committed
candidate separately.

- `godot/scripts/simulation_worker.gd`: `e04f7d5012c98dc447a7a13332475e2422d893df9881a45c81ec18f2f156d66b`
- `godot/scripts/object_shard_m4_workbench_port.gd`: `0c6fc2f1d95f1fe05d44c7a61654b106c6aa73f6fa06104e2c796506552a430c`
- `godot/scripts/object_shard_m4_runtime.gd`: `7be803d36b784f71ffe7f122266b705e2a26aa63eeefc5aef1ea5b31a2083ae8`
- `godot/scripts/shared_workbench.gd`: `cd335bd8e8bcd8a6d0b56a2fba6ff46484bcdc046bee092d525e6f8b3d63b4d8`
