# CyberSand repository guide for coding agents

Before changes, read the [handover](docs/operations/cybersand-codex-development-handover.md),
[README](README.md), [documentation index](docs/README.md), [roadmap](docs/reference/status-and-roadmap.md),
and relevant subsystem/ADRs. Inspect actual Git root, HEAD, branch, status, tags,
remotes, dependency pins and required LFS state. The companion workspace repository
is separate from this source repository; [identity](docs/operations/source-checkpoint-and-recovery.md)
explains the established checkpoints. Preserve unrelated work.

Source defines Current behavior; Approved requirements may be partly implemented.
Use Current, Approved, Planned, Deferred and Rejected claim by claim. Frontmatter
`Approved design` is the checker-compatible alias; `Ambiguous` means unresolved.
Runtime results need dated source/artifact/platform evidence. Investigate and
record contradictions before changing implementation; do not silently choose a
design from conflicting source, ADR or historical claims.

## Architectural constraints

- Native C++ owns authoritative cells; Godot owns presentation/input/UI/adapters.
- Native pool workers call no Godot APIs. The desktop GDScript owner may call its
  exclusive adapter/value APIs; live scene-tree and Rapier objects stay main-thread owned.
- Rapier is replaceable behind engine-owned interfaces. Do not erase/restore bodies
  into cell authority or introduce per-cell physics objects.
- Snapshot payloads remain immutable and owned until consumption ends. Expose no
  mutable World storage to rendering or gameplay consumers.
- Preserve exact fixture comparison and explicit bounded approximation. Strict
  runtime controls and complete serialized replay are Planned; level saves do not supply them.
- Desktop rendering/simulation are independently paced; Web currently waits for
  native ticks. Asynchronous Web ownership is Deferred.
- Preserve bounded work and explicit capacity outcomes. Avoid hidden tick-time
  allocation, per-cell locks, per-material threads and full-world sparse work.
  These are requirements, not proof that every prototype path already meets them;
  inspect the roadmap's partial-failure, allocation and region-sleep gaps.

Keep changes focused and add meaningful regressions for changed behavior. During
iteration run the relevant tests; before release complete the feasible intended
platform matrix. Do not commit generated imports beyond the three portable Godot
bootstrap files, native build output, toolchains, environments, caches, archives,
logs, crash dumps, credentials or machine-local configuration. Required runtime
libraries use Git LFS; preserve dependency versions, hashes, licenses and provenance.

## Documentation obligations

Complete the canonical [documentation-update checklist](docs/operations/documentation-maintenance.md#documentation-update-checklist)
at every implementation checkpoint. In particular:

1. Record actual source/local-delta and tested runtime identities plus the recoverable checkpoint.
2. Map changes to canonical subsystem, ownership/lifetime, interfaces, invariants,
   configuration/capacity, ADR, roadmap, build/tests and user controls.
3. Update source-backed claims, status/platform qualifiers, corpus/index routes and
   affected retrieval questions together. Search old values, aliases and reverse links.
4. Preserve historical records and failures; add dated evidence with command,
   timeout, tools, fixture/profile/workers, hashes and explicit gaps.
5. Run `python tools/ci/check_docs.py`, `python tools/ci/check_m11_consistency.py`,
   the retrieval evaluation and appropriate focused tests. The M11 checker still
   reports historical source hashes: disclose remaining failures; never rewrite
   history to make it green. Review `git diff --check` and unintended source changes.

Keep the focused RAG hierarchy. Canonical ownership and the explicit retrieval
manifest prevent duplicate answers; do not replace the hierarchy with one large document.
