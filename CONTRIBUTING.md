# Contributing to CyberSand

This source is M11-derived; inspect actual Git/backup identity before editing.
The local snapshot currently has no Git metadata. Start with
[AGENTS.md](AGENTS.md), the [documentation index](docs/README.md), the
[current audit](docs/audits/2026-09-08-documentation-audit.md), and the governing ADR.
[BUILD_ID](docs/BUILD_ID.md) retains historical M11 hashes.

Use a focused branch and keep generated output out of commits. Every behavioral
change needs a regression test; every ownership, dependency, or status change
needs the [documentation-update checklist](AGENTS.md#documentation-obligations). Run
`python3 tools/ci/check_m11_consistency.py` and the smallest relevant tests
during development, then the documented complete suite before release.

Do not weaken bounded work, immutable handoff, deterministic validation, or
capacity failure behavior merely to make a performance fixture green. Native pool workers must not
run Godot APIs or expose mutable storage; the desktop GDScript owner invokes
its exclusive adapter/value APIs without live scene-tree or Rapier access.

Large runtime binaries are versioned with Git LFS. Install Git LFS before
cloning or run `git lfs install && git lfs pull` before opening the Godot
project. Never commit credentials, local editor state, build directories,
downloaded toolchains, caches, logs, crash dumps, or export artifacts.

The project has not selected a public license. Contributions and distribution
outside the private repository require an explicit owner decision first.
