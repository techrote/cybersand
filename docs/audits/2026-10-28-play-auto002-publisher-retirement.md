---
title: PLAY-AUTO-002 temporary publisher retirement
status: Planned
document-kind: evidence
scope: Retirement of the accepted PLAY branch publisher while preserving native/runtime/campaign evidence and subsequent solver-stress source
canonical-for: []
last-reviewed: 2026-10-28
related-documents: [../operations/local-build-and-validation.md, 2026-10-27-play-auto002-worker-matrix-candidate.md, 2026-10-28-play-life002-solver-reconstruction.md]
---

# PLAY-AUTO-002 temporary publisher retirement — 2026-10-28

PR #285 is accepted as `1a7f9dd559215bfa66b53e3e029c2bcc641d3f3f`,
tree `f1506058cfbb5214ee48470703943969a239d9b7`, identical to the exact
reviewed/qualified candidate. The canonical build guide requires a scoped
publisher to retire after its feature branch merges. This bounded follow-up
removes only the PLAY workflow, profile, profile guard test and sequence-1
request; their source is retained at `d7e35aa3`.

The branch starts from solver-stress candidate `0a17fd97` to preserve its
eventual accepted source and avoid reintroducing any deleted publication path.
**PR #287 acceptance is a merge predecessor.** Its own runtime acceptance is
not supplied by this cleanup. No native, gameplay, solver, actor, input,
dependency, runtime/provenance or raw-campaign byte changes are made here.

The persistent standalone measurement runner, GDScript row runner, benchmark
regressions and 20 campaign adversarial tests remain. The inherited historical
LCB publication engines/requests are untouched. Removing the temporary
workflow also removes its branch-triggered write capability; a future native
publication requires a newly reviewed scope and request.

Local validation of the initial retirement delta passes provider policy,
documentation structure and all 20 persistent campaign tests. Final repository,
M11/retrieval, independent review and applicable exact-head hosted checks remain
required. This evidence record does not declare #266, #269 or #270 complete.
