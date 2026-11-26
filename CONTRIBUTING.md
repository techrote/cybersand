# Contributing to CyberSand

Start with [AGENTS.md](AGENTS.md), the
[development handover](docs/operations/cybersand-codex-development-handover.md)
and the [current-state register](docs/reference/status-and-roadmap.md). Read the
canonical subsystem/ADR for your task before editing. Accepted source describes
current behavior; approved direction can remain partly implemented, and Draft
candidates are separate.

## Set up and identify the checkout

Use [build and validation](docs/operations/local-build-and-validation.md) for the
exact Godot/compiler/dependency pins, a source-only launch and focused test entry
points. `dev.cmd` belongs to the separate companion workspace and is not required
to run this repository's Windows launcher. Materialize the committed Git LFS
runtime objects before claiming the application can run; verify the native
source/runtime input set rather than trusting a familiar DLL filename.

Work in a focused branch, inspect HEAD and dirty state, and preserve other work.
Use [source identity and recovery](docs/operations/source-checkpoint-and-recovery.md)
for the repository/workspace boundary. When several programmes are active, inspect
their changed paths and retain their implementation ownership.

## Make a reviewable change

Pair behavior changes with meaningful regressions and complete the
[documentation-update checklist](docs/operations/documentation-maintenance.md#documentation-update-checklist).
Update the canonical contract, user instructions, current-state register and
retrieval routes together when the behavior changes. Do not weaken ownership,
conservation, explicit capacity outcomes or qualification gates to obtain a
passing performance result.

Keep the PR Draft during iteration. Follow
[development and release policy](docs/operations/github-development-and-release.md)
for source leases, runtime publication, required exact-head evidence and owner
Ready/merge authority. Explain substantive design choices in plain language.
A complete local diff or passing subset does not authorize merge or release.

## Validate the claim you are making

Run applicable [focused tests](docs/operations/testing-validation-and-replay.md)
and [documentation/retrieval checks](docs/operations/documentation-maintenance.md#checks-and-evaluation-interpretation).
Separate source inspection, compile success, native/Godot/browser execution,
software-rendered output and physical owner acceptance. Record failures,
unavailable inputs and not-run cases alongside passes.

Use the [separate current and historical gates](docs/operations/current-and-historical-validation.md).
Retained M11 hashes belong to their audited source; do not update them for a new
runtime. Historical audits and archaeology are deliberately outside ordinary
current answers, even when their original prose says `Approved` or `Current`.

## Files, privacy and distribution

Keep generated imports beyond the supported bootstrap records, build products,
toolchains, logs, private prompts/traffic, credentials and local configuration out
of source commits. Use synthetic fixtures and isolated user profiles for tests
that can mutate saves or conversations. Documentation evidence belongs in its
proper dated audit scope, with source/platform identity and no private data.

The project has no selected public license for original work. Read
[license status](LICENSE_STATUS.md), [third-party notices](THIRD_PARTY_NOTICES.md)
and [release prerequisites](docs/operations/github-development-and-release.md#release-gates)
before external contribution or distribution. Preserve dependency versions,
notices, hashes and provenance.
