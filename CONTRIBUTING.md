# Contributing to CyberSand

This repository imports the audited M11 baseline. Start with `docs/README.md`,
`docs/BUILD_ID.md`, and the ADR governing the subsystem you intend to change.

Use a focused branch and keep generated output out of commits. Every behavioral
change needs a regression test; every ownership, dependency, or status change
needs the corresponding documentation update. Run
`python3 tools/ci/check_m11_consistency.py` and the smallest relevant tests
during development, then the documented complete suite before release.

Do not weaken bounded work, immutable handoff, deterministic validation, or
capacity failure behavior merely to make a performance fixture green. Do not
run Godot APIs from simulation workers or expose mutable native storage.

Large runtime binaries are versioned with Git LFS. Install Git LFS before
cloning or run `git lfs install && git lfs pull` before opening the Godot
project. Never commit credentials, local editor state, build directories,
downloaded toolchains, caches, logs, crash dumps, or export artifacts.

The project has not selected a public license. Contributions and distribution
outside the private repository require an explicit owner decision first.
