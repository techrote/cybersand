# CyberSand repository guide for coding agents

Read `docs/README.md`, `docs/BUILD_ID.md`,
`docs/reference/status-and-roadmap.md`, and the subsystem's ADR before editing.
M11 commit `05ea45fda7bdd7b0150eb86c4922c202e89e08f4` is the audited behavioral
baseline; do not copy implementation from older milestone archives.

Preserve native simulation authority, immutable render handoff, bounded work
and capacity behavior, deterministic validation, and the Godot-thread boundary.
Do not expose mutable World storage or call Godot APIs from native workers.

Keep a change focused. Add or update regression tests for behavior, update
Current/Approved/Planned/Deferred/Rejected claims only when evidence changes,
and run `python3 tools/ci/check_m11_consistency.py` before committing. Use the
documented focused tests while iterating and the complete feasible suite before
a release.

Do not commit Godot imports beyond the three portable bootstrap files, native
build output, package environments, editors, toolchains, caches, archives,
logs, crash dumps, credentials, tokens, or machine-specific paths. Required
runtime libraries are Git LFS files and third-party changes must preserve exact
versions, checksums, licenses, attribution, and provenance.
