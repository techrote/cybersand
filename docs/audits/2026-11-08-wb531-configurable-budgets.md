---
title: Workbench configurable request, tool and output-token budgets
status: Current
document-kind: evidence
scope: Owner-requested isolated panel/client follow-up, source and qualification boundaries
canonical-for: []
last-reviewed: 2026-11-08
related-documents: [../systems/shared-workbench-agent-authoring.md, ../operations/cybersand-codex-development-handover.md]
---

# Workbench configurable budgets

## Source and ownership

The owner explicitly requested configurable request/tool/output-token allowances
and clarification of the4096-cell bound. Isolated source starts at #531
`3cb6792abb904f912790ef077affa12570804250`, tree
`74f4ce463c21f6dbb7917e2dde489727506d199c`, on branch
`codex/wb531-configurable-budgets-20261108`. Ownership was recorded in the
[existing PR thread](https://github.com/techrote/cybersand/pull/531#issuecomment-6726812997).
The original dirty MAT checkout and owner branches are preserved. No native
implementation, physics/default, material, provider, worker or CI file is edited.

## Implemented scope

The existing scrollable side dock adds three numeric controls, a Collaboration
preset128 requests/256 tools/32768 tokens per response, and Reset limits12/32/2048.
Client validation and frozen active copies enforce all three ceilings. The
ranges4096 requests/8192 tools/131072 tokens are finite host-selected maxima,
not a claim that any particular model supports the entire range. No USD budget
or provider capability discovery is implied. Changing controls retires the task.

The panel explains4096 is per operation, not per task. A new real-native
regression prepares/applies/readback-verifies two disjoint4096-cell batches in
one2048-square authorization. It also preserves oversized-edit refusal,
protection, duplicate original receipt replay, native Step and Stop. The native
64-receipt capacity and8-primitives/4096-cell operation caps remain unchanged.

## Qualification and reproducibility

Required focused gates are client/panel budget validation and freezing,
exhaustion/no-extra-dispatch, actual large-scope8192-cell readback, dock/input,
and the mounted hopper with its original explicit24-request test allowance.
Native/runtime values must be retained separately from fake-provider assertions.
No real API requests are needed for these checks. The existing shared CI runner
must discover every changed test; no skipped workflow counts as a pass.

The unchanged source-matched native runtimes are retained Windows DLL SHA256
`64ec1a6b7b208136d02b302b952a9a1d48884d600cb009d4e4929952e365534e`
and Linux SO`c848253ea7a249fb745ee6b439337940a4067d5cb08d9cf0cf460d837cf207b2`.
Godot4.7 official`5b4e0cb0f` is the test engine. Actual resulting commit/tree,
commands, original logs/PNGs/native receipts and failures are recorded in the
existing #531 handoff and ignored build evidence. Do not relabel older head
results as this candidate's execution. A new Windows review folder should carry
its own source/runtime manifest; do not replace the owner's running folder.

## Documentation checklist

Canonical tool/ownership invariants and per-operation limits are unchanged.
User controls/configuration are updated in the shared-workbench contract;
roadmap and onboarding link this increment. Existing retrieval routes already
select that canonical contract; no competing canonical topic is introduced.
Historical2048-token/12-or24-request evidence remains historical. Runtime and
live/human acceptance stay separate. Run docs, M11, repository/retrieval and
focused Godot checks, then record the recoverable source checkpoint.
