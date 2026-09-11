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

## Completed C review and dependency outcome

The [Issue15 matrix](2026-09-11-issue-15-coverage.md) verifies completed result
`cdb4c2a6df0248c76e7957fd09cae77655ec974f`,352 behavior and224 timing processes,
18 input hashes per executable and all576 raw outputs. Both research branches
are published at their original result commits; their code remains isolated.
No new physics measurements or production changes were needed. Missing broader
model, visual, motion and platform evidence is explicitly classified and limits
admission rather than being hidden as a passed measurement.

G-C is COMPLETE / evidence reviewed. P remains justified by active residual/film
precision and threshold sensitivity; no lower-bit win is inferred. C+L unblock
#17, which is not started. #19 has C and may run frozen-authority presentation
research without a production layout selection. #18 still waits on #17/G-P and a
concrete target/no-go review; #20 still waits on #18/G-M and separate admission.
G-final/#14 remains open. General liquid unification and production history,
sidecar, widened IDs, shortened epoch, layout migration and permanent width
selection are not authorized.

## GitHub G-L checkpoint

Documentation commit `0aa641bf4972192ad94dd7d60d6f5a6557bfe110` was pushed before
the [G-L comment](https://github.com/techrote/cybersand/issues/14#issuecomment-5632025699)
and #14 current-status update. #16's [completion comment](https://github.com/techrote/cybersand/issues/16#issuecomment-5632026260)
precedes closure as completed. Readback confirms #16 closed/completed, #14 open,
and #17 open with C as the only then-unresolved prerequisite. Original #17
scope is preserved; its dependency status is updated after C closure.

G-L documentation/M11 checks pass. Repository errors exactly match all16 intake
errors. Frozen22/32 top1,32/32 top5,MRR0.8229; challenges12/16,16/16,0.8594;
programme3/5,5/5,0.7500. First-hit/rank limitations are retained. A metadata display
helper failed on Windows default encoding after checks; explicit UTF-8 fixed
display, with no evidence/checker alteration. Initial Git commit lacked author
configuration; the successful commit used the repository's established Codex
identity via command-scoped configuration, with no global configuration change.
