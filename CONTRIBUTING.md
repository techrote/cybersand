# Contributing to CyberSand

Read [AGENTS.md](AGENTS.md), the [source identity guide](docs/operations/source-checkpoint-and-recovery.md)
and governing subsystem/ADR before editing. Work in a focused branch, preserve
unrelated changes, and pair behavior changes with meaningful regressions and the
[documentation-update checklist](AGENTS.md#documentation-obligations).

Run current structural/retrieval checks and appropriate native/Godot/browser tests.
Report historical consistency failures separately; [BUILD_ID](docs/BUILD_ID.md)
retains M11 hashes. Do not weaken ownership, conservation or explicit capacity
failure behavior to obtain a passing performance result.

Required runtime libraries use Git LFS. Materialize and verify the intended
platform's objects before claiming it can run. Keep generated output, secrets,
local configuration, downloaded toolchains and logs out of source commits.

The project has no selected public license. See [license status](LICENSE_STATUS.md)
and [release prerequisites](docs/operations/github-development-and-release.md)
before external contributions or distribution.
