---
title: MAT-003 parent-stack reconciliation with current main
status: Current
document-kind: audit
scope: Non-rewriting main integration into the experimental MAT003 stack, history preservation and fresh CI gate requirements; no merge or issue completion
canonical-for: []
last-reviewed: 2026-10-24
related-documents: [../operations/mat-003prepass-registration.md, ../operations/github-development-and-release.md, ../reference/status-and-roadmap.md, 2026-10-24-lcb000-landed-status-reconciliation.md]
---

# Parent-stack reconciliation — 2026-10-24

## Inputs and method

The owner requested reconciliation of #238 and its parents against current main,
followed by applicable Native, Godot and materialized provenance checks, with no
merge or #212 implementation. Main at intake is
`1002b9201006b572180a12cbc4c3b21fc234e8fa`. The original stack is:

| PR | Original head | Parent |
|---|---|---|
| #208 | `7b71fbb9e1b4286197fb948da3d34f3c3bd5f879` | main |
| #211 | `2b2a1dd64f16dc46d5e812b757de73f47df0fb2b` | #208 |
| #221 | `7648e94fd8954d235ffd2723dc67b290dfe2e9e3` | #211 |
| #235 | `145b22599f0667bf29a37303d7f3915c690b68b2` | #221 |
| #238 | `40f4060ad57d5c6d5b62fdc81cac20e77d4c42fe` | #235 |

Merge main into #208, then propagate each reconciled parent into its child.
Preserve all registered commits through merge ancestry; do not rebase or force
push. Resolve overlapping canonical documents by retaining both current-main
4LY/LCB/WEX content and the appropriate MAT-003 stage. Retrieval questions and
corpus entries are an object-preserving union. No production source or runtime
change is required by the MAT-003 stack.

The work uses an isolated managed checkout. The dirty primary material-fidelity
checkout and Claude's separate #200 foundation branch are untouched. The existing
#213 closure and landed Gate A–E PASS evidence remain intact. That closure admits
only a separately scoped initial opt-in #200 start; #212, pressure/inertial ports,
schema freeze, changed defaults and Rapier integration do not follow.

## Preservation and validation boundaries

All pre-reconciliation experimental source, registrations and dated audit records
retain their original bytes and Git identities. Preserve the nine revised R16
reader files, v4 registration seal, Windows comparison summaries and historical
raw archives. Do not rewrite the original failed readbacks or treat author
validation as independent acceptance. Main's LCB controls, v2–v7 ledger records,
90 blocked arms, runtime artifacts, dependency pins and ordinary CI gates remain
unchanged.

The retained Windows/Linux runtime manifests have source-matched inputs already
shared by main and the old stack. Materialize their LFS objects and execute the
provenance checker; do not hand-edit a manifest or rebuild merely to change a
commit label. A genuine source-input mismatch would require a new matched build.

Before any future merge, move the reconciled PRs to ready-for-review and record
their exact heads, bases, synthetic-merge trees and actual CI logs. Required
Native, GDExtension/Godot and Documentation/provenance jobs must execute; draft
skips are not passes. The ordinary Native workflow's hosted smoke benchmark is
routine integration characterization, not MAT-003 campaign timing acceptance.
Keep the existing reusable untimed apparatus qualifiers; preserve their fresh
outputs separately from original evidence. Do not dispatch any of the four
manually admitted MAT-003 timing workflows or repeat the spent overnight/R16
collection profiles.

At this initial reconciliation checkpoint, fresh CI remains pending. Final heads
and outcomes belong in the PR descriptions/Checks and a subsequent integrated
validation record. A green gate establishes source integration within its tested
platform scope; independent scientific acceptance and #204 completion remain
separate decisions.
