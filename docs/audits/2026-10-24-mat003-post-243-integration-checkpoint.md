---
title: MAT-003 reconciliation after the completed timeout-diagnostic record
status: Current
document-kind: audit
scope: Import the documentation-only PR243 main advance, preserve earlier evidence, and require fresh integration checks
canonical-for: []
last-reviewed: 2026-10-24
related-documents: [2026-10-24-mat003-post-242-integration-checkpoint.md, 2026-10-24-issue-233-physical-regression-timeouts.md, ../reference/status-and-roadmap.md]
---

# Post-#243 integration checkpoint — 2026-10-24

Main is now `3e9f0e6dcbfdb9c122c8c555dac43e7b4d926e5f`, the documentation-only
merge of [PR #243](https://github.com/techrote/cybersand/pull/243), after
`fd97367acc5bcf5757b9ca69ae594279f0ad96bf`. Its **669 protected blobs and 765
non-documentation paths are identical** to that earlier main. No Native, Godot,
runner, workflow, harness or runtime input changes in this advance. The
[post-#242 checkpoint](2026-10-24-mat003-post-242-integration-checkpoint.md)
retains the preceding source, publication-retirement policy and evidence bounds.

The separately landed [#233 diagnostic record](2026-10-24-issue-233-physical-regression-timeouts.md)
completes that deliverable: the admitted campaign observed **11 timeouts in 600
physical attempts**. This is diagnostic evidence, not zero-timeout qualification;
the causal mechanism remains unknown. #234 owns the next repair/watchdog and
qualification, and parent #232 remains open. The main-approved audit update,
original tables and fifteen new CSV/JSON evidence files are imported exactly.
This MAT task did not dispatch that campaign and starts no #234 repair.

The fifth reconciliation completed all five ready-state Documentation/materialized
provenance checks, with actual **15/81/24** Python suites and five historical
v2–v6 replays passing: [#208](https://github.com/techrote/cybersand/actions/runs/40086135894),
[#211](https://github.com/techrote/cybersand/actions/runs/40086268075),
[#221](https://github.com/techrote/cybersand/actions/runs/40086270140),
[#235](https://github.com/techrote/cybersand/actions/runs/40086271554) and
[#238](https://github.com/techrote/cybersand/actions/runs/40086272835).
Its seven scoped checks also passed under their historical/current-contract
boundaries. These results belong to old heads `069a5cf` / `b7e7580` / `898f84d` /
`897690d` / `ce17a9a`, not new integration heads. Native/Godot execution remained
partial at the main advance; no full Native/Godot or physical-timing PASS is
claimed. Supersession/cancellation is separate from a test failure or success.

The **56 runtime source inputs** remain unchanged. The **394 historical build
inputs** still validate at `c8f14c7bc18d6ed8349d568cb00e47a826313cf9`; comparison
with current source remains **384 unchanged / seven present changed / three
retired missing**, as qualified in the previous checkpoint. No publisher is
restored and no historical hash is rewritten. MAT records, controls, v4 seal,
nine revised readers and frozen 32-question bytes remain unchanged. The full
supplementary union remains expected at 147 after propagation, retaining the
main-approved diagnostic question update; this bottom stage is not a claim of
top-stage retrieval execution.

Fresh exact-head provenance, Native, Godot, ordinary physical-timing reduction
and applicable scoped checks remain pending. **94 Native per mode and 139 total /
127 Windows Godot cases** are expected until actual new logs confirm them.
Earlier complete 15-current/seven-scoped PASS evidence retains its recorded
source scope through the previous checkpoints. #204 and independent scientific
acceptance remain open; #213's closed Gates A–E PASS is preserved. No PR is merged,
issue closed, #212 started, solver port selected, manual campaign dispatched,
new timing admitted, defaults changed, schema frozen or Rapier integration begun.
