---
title: Programme G-L and G-C reconciliation
status: Current
document-kind: evidence
scope: Dated evidence identity and programme gate reconciliation; no new runtime acceptance or production migration
canonical-for: []
last-reviewed: 2026-09-11
related-documents: [../operations/architecture-programme.md, ../operations/architecture-programme-source-ledger.md]
---

# Programme gate reconciliation

## Intake and preservation

Recorded by Codex, 2026-09-11, under the owner's explicit reconciliation task;
no owner approval of a final architecture decision is asserted. Active source
started at `b16408c28de67e3b30ebb1f0172e78d594296052` on
`codex/architecture-programme`. Reconciliation uses
`codex/reconcile-architecture-gates`. Remote main remains
`ab4851e9e6a3ee182aba1a31a8f66d135e87df3a`, older than the local physics baseline.
The only source intake delta is the intentionally dirty Windows DLL:
`godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll`, SHA-256
`fc6cb4ee1096219f581bace3df04ee8138e996aaf4c1436f5b2c071ea62dd496`.
It is preserved, unstaged and uncommitted. Both experimental worktrees are clean.
The companion workspace's untracked `worktrees/` is preserved. No files in
`C:/cybersand`, runtime manifests or historical M11 records are changed.

## Verified L identities and evidence admission

The exact completed result is
[`4726f8d0fae72f959926a47ab37f7244e9399638`](https://github.com/techrote/cybersand/commit/4726f8d0fae72f959926a47ab37f7244e9399638),
subject **Complete issue16 Cell layout research and record G-L evidence**.
It is retained/published on `codex/issue-16-cell-layout`; no experimental code is
merged into the active source. The complete [audit](2026-09-10-issue-16-cell-layout.md)
and [registration](../operations/cell-layout-experiment.md) are copied byte-for-byte
from that result. Their original no-push/no-mutation statements describe that
historical run, superseded for publication only by this dated reconciliation.
Original audit SHA-256 is
`0b6d0838962dac45940adb983dceed61ec9331c4938c66b914ae525bc81443af`.

| Stage | Timing source | Processes | Reduced JSON SHA-256 |
|---|---|---:|---|
| L1 | `b2d8faffa86e472875ba74f7c6b1488bbdd06f8a` | 196 | `20777c88eb3749276dfc850117c4e9f6ccfa98ca0778cfd7ab1b29814bf14564` |
| L2 | `b97c7c19c6c50fe13c6730d8c4e4004000732801` | 448 | `9eed000e629cf30c9ab033b400b1429e90f06dca3393d0ba8d06e0e52045346c` |
| L3 | `6e89398dbfc776d9b93bfc9f94a37e0f07c83ac8` | 280 | `0615608359b2d41b362ae191be90fa7b3d1553c2e1ad069f15dab7d447d39819` |
| L4 | `d71c9342ccf37b0fda7d34d5b083d243091f7fde` | 1400 | `ed950977ba0aba06e39102fe6bd433fb3c9be650f0e49f5d43edc15b20fab648` |

Raw source/artifact manifests and full retained campaign outputs remain under
`C:/kybersand/worktrees/issue-16-cell-layout/validation/local/issue-16/`.
Read-only reconciliation verifies every native input hash in each timing manifest
against its timing commit (accounting explicitly for Git checkout line endings),
all named measured executables, the pinned compiler, result/completion metadata,
reduction hashes and campaign execution counts. This is identity verification,
not a fresh reduction of every raw semantic byte or a campaign rerun.
Verification scripts/results and commands are retained at
`C:/kybersand/validation/local/2026-09-11-gate-reconciliation/`.

The [G-L decision](../operations/architecture-programme.md#g-l-staged-decision-2026-09-11)
is COMPLETE / evidence admitted. Current 4-byte Cell is retained as the
experimental/production baseline pending G-final; this programme control decision
is not permanent architectural selection by #16. No production migration occurs.

## Documentation scope and validation

Programme/ledger own gate status and provenance; roadmap/validation/index/corpus
route to it. The two original L documents remain unchanged. Subsystem source,
ownership/lifetimes, ABI, configuration, saves, render, profiles, ADRs and controls
are unaffected because this checkpoint only reconciles documentation and GitHub.
No historical evidence is rewritten to make current validation pass.

Intake checks use pinned Python 3.12.14 on Windows, 180-second per-command limits:
`check_docs.py` passes; `check_m11_consistency.py` passes 28 historical source hashes
and 18 records; `check_repository.py` retains 16 published provenance/LFS errors.
Frozen, challenge and programme retrieval run separately; `git diff --check` passes.
Raw commands/results are under the reconciliation prefix's `intake/` directory.
Post-edit check outcomes and GitHub readback are recorded at their next checkpoint.
