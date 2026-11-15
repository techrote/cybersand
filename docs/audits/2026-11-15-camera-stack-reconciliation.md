---
title: Camera stack accepted-main reconciliation evidence
status: Current
document-kind: audit
scope: CAMERA-STACK-RECON-001 source audit, isolated implementation and source-bound platform qualification
canonical-for: []
last-reviewed: 2026-11-15
related-documents: [../operations/camera-stack-reconciliation.md, 2026-11-15-camera-stack-source-inventory.json, 2026-11-13-native-pixel-final-integration.md]
---

# CAMERA-STACK-RECON-001 — reconciliation evidence

**Conditional staging; no merge.** This record is specific to the independent
accepted-main reconciliation. Historical component passes are not resulting-source
qualification and the owner's Windows stuttering verdict remains unaccepted.

## Intake and source ownership

GitHub live inspection on 15 November 2026 found default branch `main` at
`018bd09503d7f079ddac52e225c2f7daf8d678bf`, tree
`dd4eed8f95cfe21197a98fdc7ef663bee873dc94`. Its parents are
`dea4e53dd71d6e0af71775593fdc9197a7633e3e` and
`9bcfde77b9ac4fc2e2fac225cc8873936d5579e5`. It is the owner-merged #582 result.
The camera stack's common main merge-base is
`ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742`.

The [machine-readable audit](2026-11-15-camera-stack-source-inventory.json)
records exact heads/trees/parents, all independent and cumulative paths,
intervening commits and overlap. None of the independent component changed paths
was already byte-identical to accepted main at intake.

| Independent layer | Files | Paths shared with #582 delta | Paths shared with all accepted-main changes since fork |
| --- | ---: | ---: | ---: |
| #566 camera | 65 | 6 | 9 |
| #593 receipt/guard | 15 | 0 | 1 |
| #606 Engine Lab | 8 | 0 | 3 |
| #609 diagnostics | 14 | 0 | 1 |

`git merge-tree --write-tree main 214de85a` identifies only five textual conflicts:
documentation index, development handover, configuration reference, retrieval
corpus and status/roadmap. The sixth shared documentation path (retrieval index)
auto-merges. Main/shared Workbench/PAINT camera hunks also auto-merge with Flatten;
this is not a semantic test. Review preserves full-canvas material capture,
authoring-generation fences, baseline installation and _poll_flatten ordering.

The native inputs and published libraries come from accepted #582, not from the
older camera package. They retain original build provenance `6d6e2cd6`; no runtime
is relabelled as newly compiled from the application integration SHA.

The isolated composition retains accepted main as its first parent and the
inspected #566 head as its second parent. Its selected tree excludes the obsolete
campaign orchestration; the parent preserves the original qualified camera and
palette-transition ancestry rather than rewriting a provenance gate. Neither
main nor any component branch is merged, reset or rewritten by this operation.
The [per-path source map](2026-11-15-camera-stack-source-map.json) binds every
retained application and qualification change to its origins and content hash.

## Design choices

| Choice | Technical reason | Reversal or future admission |
| --- | --- | --- |
| Retain #566 coordinate/shader/recording algorithms | Existing exact sampling, native picking and graphical evidence; no native cadence dependency in spatial mapping | Any algorithm change needs the same framebuffer/picking/effects/recording controls |
| Retain only strict #593 receipts; use uploaded-mask pose | Avoid importing owner-rejected guarded-live presentation, while preventing absent/stale receipts from leaking live RID geometry | Admit the worker's proven temporal selector through the one overlay submission function |
| Keep useful #606 rates/FPS/VSync, narrow telemetry | Independently useful experiment controls; requested cadence differs from completed work | Keep fixed-step/time-dilation warning and achieved-rate evidence |
| Keep ACK immediate | Original countdown can be repeatedly restarted by uploads; active worker owns fixed-deadline correction | Review worker's ACK/history transaction and its deadline/reset tests together |
| Replace old package/workflow pins | Old builders would require pre-#582 native inputs and guarded defaults | Reconciliation package retains accepted native identity and tests the extracted payload |
| Preserve #609 ownership | Its original PR is diagnostic-only and newer repair evidence still includes a real coherence failure | Refresh worker head, review root cause, then import the minimum proven delta |

## Qualification record

This section is updated only with actual resulting-source execution. The source
inventory and runbook alone are not a passing test receipt.

Local prerequisites: actual Godot `4.7.stable.official.5b4e0cb0f`, accepted Linux
native SO `0cbef228d1ce28772ac3f4d6f3dcc2cc7778775abe631bd39e71239eda404d7b`,
selected Rapier SO `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.
The environment's default `godot` points to 4.6.3 and was not used for qualification.
The ordinary documentation fixtures additionally require the exact pinned
companion `6a58311982941b75f46e22109a0829e5acb83c7e`, as in repository CI.

The first local Xvfb attempt failed to bind Unix sockets; elevated display
startup was rejected by environment approval policy. A subsequent supported
route used an already permitted loopback TCP display port, without changing the
policy. Actual Godot X11/GL compatibility execution on Mesa 25.0.7 llvmpipe then
passed the development Engine Lab graphical check (82 assertions). Headless
development checks passed the receipt fixture (27), independent clocks with
positive upload/ACK observations (59), Engine Lab (80), native recording (59)
and recorder unit/negative controls (178). These are development-tree findings,
not final-commit acceptance; resulting-source receipts follow separately.

The actual recording fixture exposed a retained startup defect: after Main ACKs
a publication, an owner status snapshot retains its render serial without patch
bytes. A new recorder mistook that receipt for a new publication and aborted
before its requested full refresh arrived. The original `ingest_snapshot`
function is identical on main and all four historical heads (SHA-256
`b4d804c3f0c0f426d6449b91da696059e6c7935d6110ec437b621a3562b7cbf4`). The candidate
adds seven lines that wait only for an unprimed, non-full, completely empty
status receipt. Malformed full refreshes and genuinely newer empty publications
after priming still fail. The original failed manifest is retained. The native
positive test writes three BMP/IDs/JSON frames, checks all 12,513 ROI cells against
native readback and independently decodes BMPs; it does not claim exact physics
replay. No worker, publication or ACK logic changed to fix this defect.

## Independent worker evidence

Original #609 remains at `01a8416761ba3477a2587d7b07a854945b0f0286`.
Its separate published repair continuation was
`fix/render-cadence-001-20261115` at
`d5397a7d2a1285bf6d2ade5f76e0e89e00e85c70` at audit.
[Run 43691622727](https://github.com/techrote/cybersand/actions/runs/43691622727)
retains the 2-Hz fixed-camera negative control: 1.9963 native ticks/s,
120.811 completed Rapier steps/s, identical motion at 995 common completed steps,
yet 364.009 ms displayed hold followed by 88.2936 px catch-up. Conservative swept
padding can reject endpoint-clear poses after texture crossfade expiry.

Those are worker-source results, not this candidate's measurements. They support
excluding the disputed selector; they do not demonstrate a complete repair. The
worker's complete presentation disposition remained FAIL/HOLD. Newer evidence
must be refreshed at final handoff.

## Remaining admission

The [operational handoff](../operations/camera-stack-reconciliation.md#downstream-609-handoff)
defines the future selector/receipt/ACK/trace boundaries. The original stack must
not be merged wholesale after this selective reconciliation. The shortest safe
composition is accepted main plus this candidate plus one reviewed final #609
delta, then affected source/runtime/graphical/physical gates and owner approval.

Physical Windows NVIDIA motion, actual OS DPI, VSync and representative long
moving-contact workloads remain distinct from hosted software rendering. No
merge, Ready promotion, auto-merge or native runtime publication is authorized.
