---
title: Development handover
status: Current
document-kind: guide
scope: Short onboarding sequence and checkpoint protocol; product intent, source identity and contracts have canonical homes
canonical-for: [development-onboarding]
last-reviewed: 2026-09-08
related-documents: [source-checkpoint-and-recovery.md, ../reference/product-intent-and-priorities.md, ../reference/status-and-roadmap.md]
---

# Development handover

## Start here for the next task

Work in `C:/kybersand`, with executable source in `source/`. The companion workspace
and source now have separate Git histories. Read [source identity](source-checkpoint-and-recovery.md)
and inspect both relevant working trees before changing anything. Godot is in
`C:/Godot47`; `C:/cybersand` is for functional deliverables. The original rewrite
was local; the owner subsequently authorized a [GitHub checkpoint](../audits/2026-09-08-github-milestone.md)
of both histories. User-confirmed USB backup is recorded; no further backup search is needed.

Read [AGENTS.md](../../AGENTS.md), the [documentation index](../README.md),
[roadmap](../reference/status-and-roadmap.md), then the canonical subsystem and ADR
for the requested change. Use the [retrieval index](../reference/retrieval-index.md)
for a focused question. The [owner-intent reference](../reference/product-intent-and-priorities.md)
preserves product goals, liked material behavior and deliberate deferrals.

## Foundational work boundary

**Current:** native C++ owns cells. Desktop uses an asynchronous GDScript owner
Thread; Web completes ticks synchronously on the Godot main thread with optional
internal native pthreads. Rapier objects stay on the main thread. Follow
[ownership](../architecture/data-ownership-and-lifetimes.md) and
[coupling](../architecture/rigid-body-and-cellular-coupling.md) before changing either.

The first foundational checkpoint should resolve the bounded correctness/ownership
issues in the roadmap before broad physics additions. In particular, tick failure
is not a transaction: issue #1 now quarantines failures until explicit reset or
validated replacement, with no retry/rollback. Issue #2 retains excluded phased
activity and wakes newly included resident blocks once, without catch-up; serial
keeps its distinct behavior. The [combined evidence](../audits/2026-09-08-issue-2-interest-regions.md)
separates regressions and runtime artifacts from remaining platform gaps.

Use [build/test instructions](local-build-and-validation.md) for commands and
[validation evidence](../reference/validation-evidence.md) for actual dated passes.
Historical Linux and retained Windows/browser results do not certify every current
artifact. Level saves do not provide exact replay continuation.

## Finish a checkpoint

Keep implementation changes focused, run relevant tests, and apply the
[documentation-update checklist](documentation-maintenance.md#documentation-update-checklist).
Update canonical facts and retrieval routes together; record failed/unavailable
checks and the tested source/runtime identities. Commit locally when authorized.
Preserve existing historical audit records. The former long handover and checkpoint
tables are retained in the [historical record](../audits/pre-rag-rewrite-2026-09-08/README.md),
excluded from ordinary current retrieval.

## Publication and legacy validation follow-up

The owner authorized finalising issues #1/#2 in PR #6. Preserve their separate
commits and contracts. [Current validation and M11 retention](current-and-historical-validation.md)
now have independent gates; original historical hashes stay unchanged.
[Publication evidence](../audits/2026-09-08-validation-reconciliation.md) records
Linux native/sanitizer results and the rebuilt-runtime CI transition. Remaining
Web CI/export identity work remains issue #3.
