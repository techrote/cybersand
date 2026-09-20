# CyberSand repository guide for coding agents

Before changes, read the [handover](docs/operations/cybersand-codex-development-handover.md),
[README](README.md), [documentation index](docs/README.md), [roadmap](docs/reference/status-and-roadmap.md),
and relevant subsystem/ADRs. Inspect actual Git root, HEAD, branch, status, tags,
remotes, dependency pins and required LFS state. The companion workspace repository
is separate from this source repository; [identity](docs/operations/source-checkpoint-and-recovery.md)
explains the established checkpoints. Preserve unrelated work.

## Development-order safety

GitHub issue numbers are identifiers, **not a serial execution order**. Before
selecting work in or adjacent to #24/#27-#30, read the canonical
[MicroScenarios and intermaterial-interactions programme](docs/operations/microscenarios-programme.md)
as well as the roadmap. It owns that programme's dependency graph; the
[architecture programme](docs/operations/architecture-programme.md) separately
owns the scientific gates/semantics of #14/#18/#20. Do not reconstruct order from
issue numbers, creation dates or stale issue comments. If an issue mirror conflicts
with either canonical programme, reconcile the planning documents and issue text
before changing implementation.

Source defines Current behavior; Approved requirements may be partly implemented.
Use Current, Approved, Planned, Deferred and Rejected claim by claim. Frontmatter
`Approved design` is the checker-compatible alias; `Ambiguous` means unresolved.
Runtime results need dated source/artifact/platform evidence. Investigate and
record contradictions before changing implementation; do not silently choose a
design from conflicting source, ADR or historical claims.

## Water successor safety

Issue #26 remains closed as a valid negative experiment for its two exact tested
local candidates, but its retained apparatus v1 is historical/qualified evidence.
Before any #45 Water head-transmission implementation or acceptance work, read the
[post-merge #26 review](docs/audits/2026-09-19-issue-26-post-merge-review.md),
the [#49 v2 correction registration](docs/audits/2026-09-20-issue-49-water-apparatus-v2-registration.md)
and the [source-matched #49 v2 Current-Water baseline](docs/audits/2026-09-20-issue-49-water-apparatus-v2-baseline.md).
The corrected #49 apparatus is the successor control; #95 remains the decision
join before #45 may proceed, narrow, recharter, defer or no-go.

The 2026-09-20 [Water hybrid/pressure extension](docs/operations/water-hybrid-pressure-extension-programme.md)
adds a parallel evidence lane. Current generic Rapier↔Water behavior is first
captured in #91; #92 may test at most roughly 3-5 segmented upper-volume Water
sheet tiers only by reusing a suitable generic #12 hybrid substrate. #93 is an
independent research-only lumped gas-region feasibility lane; #94 is conditional.

**Do not treat #45 as an inevitable pressure implementation.** Architecture/read-only
analysis may continue, but selecting or accepting a #45 implementation must consume
the corrected #49 apparatus and the #95 WEX synthesis (or its explicit
blocked/no-go disposition). Equal liquid levels are a vented/shared-pressure
control, not a universal sealed-room target.

Do not freeze #45 numeric thresholds from apparatus-v1 settling/U-tube metrics,
rewrite old #26 artifacts, duplicate #49/#12 ownership, silently unify Water
FreeMass with other-liquid CellularYield, or start #18 compact history merely to
preserve the old dependency ladder.

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
  preserve the failed-world quarantine and region pause/re-entry contracts; inspect
  the roadmap for remaining allocation and physics gaps.

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
   `python tools/ci/check_repository.py`, the retrieval evaluation and appropriate
   focused tests. M11 checks retained records against the audited historical Git
   revision; `--compare-working-tree` explicitly reports current-versus-M11 drift.
   Never rewrite historical hashes. Follow the [separate validation gates](docs/operations/current-and-historical-validation.md)
   and review `git diff --check` and unintended source changes.

Keep the focused RAG hierarchy. Canonical ownership and the explicit retrieval
manifest prevent duplicate answers; do not replace the hierarchy with one large document.
