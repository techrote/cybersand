---
title: Render publication investigation on frozen main
status: Current
document-kind: audit
scope: Instrumented desktop reproduction and opt-in E and R experiments; draft investigation, no production selection
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../architecture/rendering-and-gameplay-bridges.md, ../reference/status-and-roadmap.md, ../operations/local-build-and-validation.md]
---

# Render publication investigation on frozen main

## Source and concurrent ownership

The starting source is `adaaa37ae35ffcdaa961b80353be3a23b805c0cc`, tree
`ad800ebd5c876f6d1ecd080a6dc3f02918b21870`, fetched from `origin/main` on
2026-10-31. Branch `codex/render-publication-abc-20261031` uses the separate
worktree `C:/Users/_/.codex/worktrees/render-publication-abc/khybersand`.
The dirty `C:/khybersand` material branch was preserved. No subsequent main or
other investigation commits are consumed. Resolve A/B/C checkpoints from this
branch's commit history; no merge is authorized.

The open-PR audit found production render-copy ownership in #290 (head
`ddf812f34c533f654f1488b9115eb0256305a288`) and publisher/host successors
#295/#298/#301, plus integration prepass #333 (head `21d44e43`). PLAY shader
#310/#326/#331 and recovery #308/#332 also affect the wider host. Their metadata
was inspected; their commits and implementations were not imported. R here is
an independent test-only differential experiment. Cross-branch integration
belongs to a subsequent pass.

All 18 required LFS objects were materialized. Each graphical campaign verifies
all 80 canonical native source inputs against the inherited runtime manifest,
the actual runtime hash, and before/after script identities. Generated imports,
UIDs, builds, logs, archives and local runtime replacements are excluded from
commits. The separate historical companion inputs were materialized outside
source from workspace checkpoint `a15e06ca6f37750b66b89936424e0d018b203f7b`.

## Historical evidence, not current performance

Frozen #283 remains untouched at `254235ec4c3d58782bba44b478caca86bf57c856`.
Read-only archaeology verified these frozen receipts under
`docs/audits/sol281-2026-10-28/` in that commit:

| Receipt | Git blob | Qualified historical scope |
|---|---|---|
| render-ack-control-receipt.json | `08c10cce7008c75c3df5cfb227c90794a97b24bf` | Full 2,097,152-byte RG8 baseline plus dirty caused byte-only retries; CPU ACK Linux93/93, Windows101/124; 23 Windows clears |
| render-coalescing-candidate-receipt.json | `6ce5c72279b6333fb7989c6d8c9af603229a5419` | Original latest-only qualification failed and remains failed |
| render-coalescing-gate-correction-receipt.json | `f83e16ed788b3c0080e5479183c7777ae6a0ff39` | Monotonic owner counters corrected causal counting |
| render-root-cause-comparison-receipt.json | `5286fe02660e7c16e0887d50fcc005fae266ee5c` | R extraction win; whole-run retry gate failed with intentionally unacknowledged startup |
| render-followup-comparison-receipt.json | `77349143dbcfa77574ac95c320baa0624497655a` | E qualified headless CPU-ACK median p95 .037ms Linux/.048ms Windows, no baseline drops |

Frozen E's predicate was less strict than this task's complete-frame/generation/
channel contract. Frozen R also formed an overflowing exclusive endpoint at
INT64_MAX. Neither implementation is imported. None of these historical timings
qualifies current graphical upload, GPU completion or frame pacing.

## Stage A apparatus and interpretation

The real `main.tscn` retains ordinary `_process`, validation, patch application,
two ImageTextures, shader/presentation setup, texture update and upload-dependent
ACK. Only test subclasses record events or withhold ACK. The workload is paused
to exclude physical/simulation-policy changes: 120 radius-zero alternating
Sand/Water emissions over 240 process frames, with ordinary accepted reset at
frame120. Fresh processes run N (normal ACK) and W (withheld after successful
upload); ordering alternates by repeat. Emissions can be batched by owner pacing,
so counts and trajectories must be interpreted through event identities rather
than assumed equal refresh denominators.

Windows uses pinned Godot4.7 `5b4e0cb0f`, native OpenGL/NVIDIA TITAN RTX. Linux
uses the same pinned version under WSLg/X11 with Mesa llvmpipe; this is a real
graphical software renderer, not a discrete Linux GPU. The retained Linux engine
archive matches lock SHA256 `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`.
The direct official download returned HTTP403; the already cached exact pinned
archive was verified instead. Audio is explicitly Dummy in qualified campaigns.

The first campaigns (`A-Windows`, `A-Linux`) retain useful mechanism evidence but
have qualified timeline precision: ACK clear reread shared ACK, native duration
included post-call diagnostic getters, and retrieval was timestamped too late.
Independent AI review identified these issues. A2 preserves the exact latched
ACK, timestamps native return before getters and logs retrieval separately from
later consumption. Its reader checks owner event/counter agreement, every retry
cause, paired operation identities, post-upload ACK, W suppression and full
replacement at both generations. AI review is not independent human approval.

Raw receipts, original logs and PNG frame witnesses are retained under
`C:/Users/_/.codex/tmp/render-publication-abc/`; curated JSON receipts below bind
their hashes and exact source/local delta. Original A Linux logs include audio
fallback errors; those runs are not promoted to clean qualification.

Commands (1200s per graphical process, plus bounded terminate/kill cleanup):

```text
python tools/experiments/render_publication_campaign.py --engine C:/Godot47/Godot_v4.7-stable_win64_console.exe --output <fresh-directory>
wsl --cd <worktree-linux-path> python3 tools/experiments/render_publication_campaign.py --engine /home/i/cybersand-play-auto004-tools/Godot_v4.7-stable_linux.x86_64 --output <fresh-directory>
```

Normal-consumer retry incidence is an instrumented-fixture observation; the
trace mutex and shared host load perturb scheduling. The old full+dirty overflow
mechanism is reproduced; Stage B is therefore admitted as an opt-in experiment.
The precise qualified A2 values and example timelines are retained in the
machine receipt. Neither a paused narrow fixture nor `frame_post_draw` is human
PLAY acceptance or GPU-fence timing.

Corrected [Stage-A receipt](render-publication-2026-10-31/stage-a.json), three
fresh processes per arm/platform:

| Platform | N retries/refreshes | W retries/refreshes |
|---|---:|---:|
| Windows native OpenGL/NVIDIA | 10/363 (2.75%) | 357/363 (98.35%) |
| Linux WSLg/X11 llvmpipe | 83/253 (32.81%) | 162/168 (96.43%) |

Every characterised retry is a Published dirty first packet behind a retained
full frame, followed by byte-only overflow and a forced full second call.
Rectangle overflow and native backpressure are absent in these retry causes.
The two complete baseline publications per run are startup and accepted reset.
N clears often prevent the loop; W retains the baseline deliberately. The
Linux/Windows rate difference cannot be assigned to OS alone: renderer and
scheduling differ. A2 Windows and Linux campaigns partly overlapped on the same
machine; subsequent same-platform comparisons must be read with that caveat.

## Documentation change matrix

The bridge contract owns diagnostic/current-policy qualifiers; this audit owns
dated results/failures. Documentation index, roadmap, validation ledger and
retrieval routes point there. Ownership/lifetimes, interfaces, invariants,
configuration budgets and ADR003 were inspected: no mutable World access,
wire-layout, default budget, user control or production policy changes are
selected. Local build instructions retain pinned tools; experimental standalone
commands are recorded with each stage here. The frozen retrieval evaluation is
preserved; supplemental investigation questions are separate.

## Validation and remaining gates

At intake, documentation/repository checks failed on the five absent companion
paths (six question references), while historical M11 passed18 records/28 hashes.
Restoring the historical companion files outside source made documentation pass.
Baseline lexical evaluation: hit@1 19/32, hit@5 32/32, MRR .7536; semantic answer
sufficiency still needs source review. The bounded trace control passed5 checks.
Stage-specific and final-head evidence are recorded separately as work proceeds.

Stage B, Stage C and final draft handover are pending at the Stage-A checkpoint.
