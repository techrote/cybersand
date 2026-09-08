# CyberSand repository guide for coding agents

Required reading order

Before modifying this repository:

1. Read `docs/operations/cybersand-codex-development-handover.md`.
2. Read the root `README.md` and the documentation index.
3. Read `docs/reference/status-and-roadmap.md`.
4. Read the documentation and ADRs relevant to the requested subsystem.
5. Inspect the current Git status, commit identity, tags, dependency pins, and Git LFS state.

The handover records project intent and conversational decisions that may not appear elsewhere. It supplements the focused RAG documentation; it does not override executable source, newer approved ADRs, or current validation evidence.

Distinguish documentation claims consistently:

- **Current** — directly inspected in source/configuration; runtime claims additionally name dated platform, profile, inputs, and artifact evidence.
- **Approved** — accepted direction, possibly not fully implemented.
- **Planned** — intended future work.
- **Deferred** — deliberately postponed.
- **Rejected** — considered and intentionally declined.

If source, documentation, audit evidence, and the handover disagree, stop and identify the contradiction before changing implementation.
Preserve native simulation authority, immutable render handoff, bounded work
and capacity behavior, deterministic validation, and the Godot-thread boundary.
Do not expose mutable World storage or call Godot APIs from native workers.

Keep a change focused. Add or update regression tests for behavior, update
Current/Approved/Planned/Deferred/Rejected claims only when evidence changes,
and run `python3 tools/ci/check_m11_consistency.py` before committing. Use the
documented focused tests while iterating and the complete feasible suite before
a release.

Preserve these architectural constraints:

- Native C++ owns authoritative simulation state.
- Godot owns presentation, input, UI, and adapters.
- Native pool workers must not call Godot APIs. The desktop GDScript owner may call its exclusive adapter/value APIs but must not access live scene-tree or Rapier objects.
- Rapier is a replaceable backend and must remain behind engine-owned interfaces.
- Render-patch payloads remain immutable and snapshot-owned until consumption completes.
- Runtime approximation may be bounded and explicit. Preserve exact fixture comparison; a selectable strict runtime mode and complete serialized replay remain Planned requirements.
- Desktop rendering and simulation remain independently paced. Web currently separates publication cadence but synchronously waits for native ticks; do not claim asynchronous Web ownership.
- Avoid hidden tick-time allocations, mutable rendering reads, per-cell locks, per-material threads, and full-world work when activity is sparse.


Do not commit Godot imports beyond the three portable bootstrap files, native
build output, package environments, editors, toolchains, caches, archives,
logs, crash dumps, credentials, tokens, or machine-specific paths. Required
runtime libraries are Git LFS files and third-party changes must preserve exact
versions, checksums, licenses, attribution, and provenance.

## Documentation obligations

When changing behavior or architecture:

Use this as the canonical checkpoint checklist (the PR template and retrieval
index link here). Apply it even when a change leaves the high-level status unchanged.

1. Record actual source identity first: Git root/HEAD/branch/tag/status/remotes
   and LFS state, or their absence. Compare local deltas and verify the named
   backup/rollback point exists. A provenance base hash or export `source_commit`
   field is not proof that current changes are committed, backed up, or deployed.
2. Map affected claims before editing: focused subsystem page, ownership/lifetime,
   interfaces, invariants, configuration/budgets, ADR, roadmap, build/test guide,
   and user-visible controls. Search exact symbols, old values, aliases and reverse
   links across docs, README, handover, and retrieval short answers.
3. Update the relevant focused RAG documents and affected ADRs. Each independently
   retrieved page needs a scope, review date, claim status, native/desktop/Web
   distinctions where applicable, and traceable source path plus symbol. Keep the
   focused hierarchy; link shared contracts instead of duplicating their detail.
4. Reconcile **Current**, **Approved**, **Planned**, **Deferred**, and **Rejected**
   claim by claim. The checker-compatible frontmatter alias `Approved design`
   means Approved. `Ambiguous` records missing/conflicting evidence, not approval.
   Explain partial implementation and preserve explicit rejection/deferral scope.
5. Update `docs/reference/status-and-roadmap.md` for implementation status changes;
   update `docs/README.md` and `docs/reference/retrieval-index.md` for changed routes
   or short answers. Update the handover only for cross-cutting operational
   guidance or owner intent. Repair both Markdown links and inline path examples.
6. Attach validation to the exact claim: command, timeout, date, OS/architecture,
   tool/dependency versions, build profile, worker count, fixture/configuration,
   exit/result, and source plus artifact identity. Distinguish source inspection,
   checksum/HTTP checks, headless runtime, browser execution, and visual approval.
   State when a retained binary was tested without a fresh source rebuild.
7. Keep historical audit results, source hashes and failed/inconclusive records
   intact. Label their revision/platform/date and link new evidence separately.
   Never adopt historical totals or change release hashes to make a checker green.
   Distinguish exact level-byte restoration, cellular fixture hashes, full replay,
   and Rapier trajectory equivalence; none implies the others.
8. Record unresolved contradictions precisely: conflicting source/config/doc
   locations, observed behavior, missing evidence/decision, and the narrow next
   check. Do not silently choose a design or fix implementation in a docs audit.
9. Run `tools/ci/check_m11_consistency.py` and focused checks. Review Markdown
   links/frontmatter and index coverage independently if historical source hashes
   fail. Report actual remaining failures; never call a partially failed checker
   passing. Check diffs or before/after manifests for unintended source changes.
10. In the checkpoint report name updated documents, performed checks, remaining
    platform/visual/replay gaps, explicit deferred doc work, and verified rollback
    coverage. A missing checkout/backup is an operational gap, not a reason to
    fabricate a commit or overwrite existing local work.

Do not replace the existing RAG documentation hierarchy with a single consolidated document.
