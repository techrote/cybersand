# CyberSand repository guide for coding agents

Required reading order

Before modifying this repository:

1. Read `docs/operations/codex-development-handover.md`.
2. Read the root `README.md` and the documentation index.
3. Read `docs/status-and-roadmap.md`.
4. Read the documentation and ADRs relevant to the requested subsystem.
5. Inspect the current Git status, commit identity, tags, dependency pins, and Git LFS state.

The handover records project intent and conversational decisions that may not appear elsewhere. It supplements the focused RAG documentation; it does not override executable source, newer approved ADRs, or current validation evidence.

Distinguish documentation claims consistently:

- **Current** — implemented or verified.
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
- Worker threads must not call Godot APIs.
- Rapier is a replaceable backend and must remain behind engine-owned interfaces.
- Render-patch payloads remain immutable and snapshot-owned until consumption completes.
- Runtime approximation may be bounded and explicit, but strict validation and replay remain exact.
- Rendering and simulation remain independently paced.
- Avoid hidden tick-time allocations, mutable rendering reads, per-cell locks, per-material threads, and full-world work when activity is sparse.


Do not commit Godot imports beyond the three portable bootstrap files, native
build output, package environments, editors, toolchains, caches, archives,
logs, crash dumps, credentials, tokens, or machine-specific paths. Required
runtime libraries are Git LFS files and third-party changes must preserve exact
versions, checksums, licenses, attribution, and provenance.

## Documentation obligations

When changing behavior or architecture:

1. Update the relevant focused RAG document.
2. Update any affected ADR.
3. Reconcile affected **Current**, **Approved**, **Planned**, **Deferred**, and **Rejected** claims.
4. Update `docs/status-and-roadmap.md` when implementation status changes.
5. Update `docs/operations/codex-development-handover.md` only when the cross-cutting operational guidance or owner intent changes.

Do not replace the existing RAG documentation hierarchy with a single consolidated document.
