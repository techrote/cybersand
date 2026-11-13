---
title: GEN-008 native material Flatten qualification
status: Current
document-kind: evidence
scope: Dated source boundaries, preimplementation failure, local native and persistence evidence, and exact-source Windows/Linux acceptance routing for issue 548
canonical-for: []
last-reviewed: 2026-11-13
related-documents: [../architecture/shared-workbench-authoring-data.md, ../operations/gen008-flatten-qualification.md, ../reference/level-saves-and-replay.md]
---

# GEN-008 native material Flatten qualification

## Ownership and authoritative scope

The task begins on accepted main `ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742`
(tree `05d2960d569719cdc85b44228950eb14fa0d4c66`), including merged #564/#565.
[Issue #548](https://github.com/techrote/cybersand/issues/548)'s 11 November revised
specification is authoritative. The old World-replacement, actor-respawn,
tick-zero, 8-bit and Undo-Flatten proposal is withdrawn. The implementation
branch is `feat/gen008-flatten-material-baseline`; keep its sole PR Draft/HOLD.
No merge or Ready promotion is authorized. Independent #566 camera and #569
experimental training sources are not imported.

The [canonical authoring contract](../architecture/shared-workbench-authoring-data.md#flatten-and-storage-compatibility)
owns current semantics, native ownership, generation fencing, format and limits.
The [qualification runbook](../operations/gen008-flatten-qualification.md)
owns reproducible commands and the Windows Owner acceptance procedure. Original
Actions artifacts and the PR ledger identify each executed source, tree, runtime,
platform result, checksum, measured cost and any failed campaign. A dispatch or a
Draft-skipped check is never a completed test.

## Initial failing controls

Before implementation, `test_workbench_flatten.gd` reflected the unchanged
Shared Workbench at `ac0d9fb944cb` and failed all three checks for missing
`request_flatten`, `is_flatten_pending`, `get_flatten_status`. The final red run
used official Godot 4.7 and materialized accepted native/Rapier dependencies,
exited 1, and had no unrelated script errors. An earlier unmounted-UI version
emitted cleanup leaks; that original failed log was retained and the reflection
fixture corrected before recording the clean negative.

The new native regression also failed against that starting implementation:
`native/tests/test_material_baseline.cpp` could not include the absent
`cybersand/material_baseline.hpp`. The standalone format test first refused the
absent module, then the absent native validation method after the script was
introduced. The initial LFS-pointer warning attempt is retained separately from
the hydrated native control.

## Local native and format checkpoint

Local iteration uses official Godot `4.7.stable.official.5b4e0cb0f`, exact
`godot-cpp` revision `101ae38034304346a46ea9ea84ae156d3e860496` and SCons 4.10.1
with wheel SHA-256
`bd9d1c52f908d874eba92a8c0c0a8dcf2ed9f3b88ab956d0fce1da479c4e7126`.
Local GCC 14.2 is an explicitly labeled toolchain drift from pinned hosted
GCC 13; these results do not replace final Linux/Windows release qualification.
The local O3 extension SHA-256 is
`b9cd7267159d635b697d5752267801ebeaa233b1d5839b016f55d7ebf40d789c`
(4,478,648 bytes). The checkpoint native source/build input hashes are retained
in the local original `native-local-identity.json`.

Native tests cover every supported ID, Empty, row/final-cell boundaries, masked
fractional Water, temperature and state lanes, detached buffer ownership, bad
lengths/dimensions/capacity, reserved/wide IDs, in-progress ticks and failed World
refusal. A real Water-to-Ice transformation is captured; capture preserves full
physical-state hash, tick, masks and quantities, and the same World ticks again.
`native/src/world.cpp`, material laws, catalogue, live cell storage, camera and
shader sources are unchanged.

| Full resident native plane | Exact bytes | Native copy | Native validation |
|---|---:|---:|---:|
| 512² | 524,288 | 1.259 ms | 0.206 ms |
| 1024² | 2,097,152 | 8.124 ms | 0.826 ms |
| 2048² | 8,388,608 | 21.225 ms | 3.499 ms |

Native test process peak RSS was 86,164 KiB. These are fixture measurements,
not complete Workbench memory or graphical response claims. An earlier sparse
resident measurement remains a separate historical log.

The native-backed standalone format suite passed **87 checks**, including exact
bytes, unsupported versions, checksum-valid bad metadata/IDs, truncation,
corruption, incomplete staging, atomic replacement failure, old-reader routing,
ordered Empty overlays and packed-array alias mutation. Full script time was
1.100 seconds, peak RSS 157,216 KiB.

| Plane | Detached staging | Save | Read/validate | Complete file bytes |
|---|---:|---:|---:|---:|
| 512² | 2.848 ms | 4.846 ms | 5.215 ms | 525,042 |
| 1024² | 11.615 ms | 21.262 ms | 25.560 ms | 2,097,911 |
| 2048² | 49.200 ms | 93.605 ms | 97.585 ms | 8,389,367 |

ASan/UBSan passed locally with only LeakSanitizer disabled. The original enabled
LeakSanitizer run failed at shutdown because this executor uses ptrace; the
failure is retained, not relabeled. Hosted sanitizer execution retains leak
detection. Full Workbench capture, adoption, future edits, actor identity,
fresh-process loading and graphical responsiveness are separately measured by
the source-matched qualification runner, including process RSS per phase.

## Review findings and repairs

GDScript packed-array assignment can share a mutable array. Staging now uses an
explicit detached copy, and the prepared packet separately detaches its payload;
regressions mutate old receipt/packet aliases and require the baseline to remain
unchanged. No native World memory is ever borrowed.

Paused Flatten intentionally leaves native generation, revision and tick intact.
A separate authoring generation therefore fences old PAINT requests, while
existing agent epochs fence late chunks/model responses. Successful adoption
also retires the provider's pending-run UI state. Old construction/Undo history
is discarded only after complete staging and final lease validation; refusal or
Cancel retains the existing authored state and saved starts.

Independent integration review found that failed-owner **Reset / R** still
carried only the Setup-v2 recipe through the old recovery envelope. After
Flatten that would lose the baseline. Reset now refuses this unsupported
recipe-only recovery path for generated/material starts, as Restore already
does; the original authored state remains intact. Native owner failure still
requires application restart and loading a saved authored start.

The first complete fresh-process oracle found a real integration defect:
`microscenario_host.gd` forwarded generated terrain but omitted the standalone
material-baseline packet. The saved file plus its three ordered edits exactly
matched the independent expected plane, while the installed native plane was
entirely Empty. The missing forwarding seam is repaired and included in source
custody. The corrected 512-square run passed **193 author checks and 42
fresh-process checks**, including complete native-array equality, subsequent
editing, Restore and actual owner-thread shutdown before adoption. Failed
iterations and the observed/expected raw planes are retained separately.

The accepted legacy history fixture also passed in separate author/reopen
processes: **1,884 author checks and 1,920 reopen checks** for Setup-v2 and
generated-start-v1, including detailed history beyond 4,096 rectangles. PAINT
executor validation passed 21 checks after the added authoring-generation fence.

A local graphical diagnostic used the actual Workbench buttons in official
Godot 4.7: generated a 1024-square GEN-007 map, painted Sand, ran simulation,
confirmed Flatten while playing, observed the 2,097,152-byte success status,
paused and painted another 197-cell stroke, then explicitly saved. After fully
terminating that Godot process, a new process loaded the baseline directly
without the generator dialog. The settled pre-Flatten Sand and subsequent mark
returned; another 197-cell brush edit, Undo and Redo succeeded visibly. This
development-machine interaction is separate from the source-frozen hosted
graphical receipts and from Owner acceptance on the physical Windows PC.

Real local Save-fault controls target an existing valid named start. A 65,536-byte
Linux file-size limit causes a partial write and explicit refusal while the old
file remains byte-identical. A separate process is actually killed by SIGXFSZ
during writing; the observed partial temporary is ignored, the previous named
file remains intact and a normal retry succeeds. Hosted Windows must separately
prove refusal/recovery when the existing target is locked against replacement.

The capture receipt distinguishes native copying, native capture including
hashing, the complete GDScript/native call boundary, and the main-thread
worker-result handoff. The last measurement alone is not cross-language capture
cost. Full-plane scans stay bounded; no borrowed World buffer is exposed.

## Hosted acceptance and remaining authority

The dedicated qualification workflow reuses the accepted MAT-AUTH/Workbench
publisher, complete source/installed regressions and package custody checks.
Both actual target OS runs must pass the complete native-backed Flatten matrix
at 512², 1024², 2048² and a separate four-worker case; all required phases,
checksums, native array witnesses, fresh-process identities, graphical images,
performance and process-memory records are independently read back. An exact
four-path, leased runtime/provenance publication precedes the final independent
Documentation, Native, GDExtension/Godot and relevant Palette gates.

The original artifacts and sole PR's live ledger are the completion authority.
This file records the initial source-local evidence and tested design decisions;
it does not claim a hosted campaign has passed merely because it was configured.
Owner graphical acceptance on the physical Windows PC remains distinct from
all automated and hosted graphical tests. A technical GO never authorizes merge.
