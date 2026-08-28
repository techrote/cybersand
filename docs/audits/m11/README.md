---
title: Audited M11 baseline evidence
status: Current
scope: Immutable source identity, predecessor audit findings, M11 remediation record, and final validation summary retained for Git migration
keywords: [m11, audit, validation, checkpoint, source identity, migration]
related-documents: [../../BUILD_ID.md, ../../reference/status-and-roadmap.md, ../../operations/github-development-and-release.md]
last-reviewed: 2026-08-28
implementation-state: Checkpoint and completion records are retained directly; machine-specific paths in the predecessor audit and validation command display are replaced by portable variables while original hashes remain recorded.
---

# Audited M11 baseline evidence

This directory records the exact evidence associated with source commit
`05ea45fda7bdd7b0150eb86c4922c202e89e08f4` and build ID
`m11-audit-remediation-render-handoff-water-native-repro-2026-08-28`.

| File | Purpose | SHA-256 before migration |
|---|---|---|
| `checkpoint.json` | Final M11 archive/source identity | `1f21b01e1c7870ed3c297dd51accebe1418f81459bc2ec56d161001b06deac9b` |
| `migration-source.json` | Machine-readable authoritative archive, build, audit, and validation state used for migration | generated from the verified final records |
| `github-migration-validation.md` | Clean-checkout, LFS, functional, and build-path evidence recorded before the private push | generated during migration |
| `m10-independent-audit-report.redacted.md` | Independent findings that M11 remediated; only creator-machine paths and trailing Markdown whitespace were normalized | original: `87c7a3ee2f38713f9520221d929863d928f1499b79637db0839cdf3402de940c`; repository copy: `ac15871537c8ad9883d351fc7362cbbbcdb78ef1d6459df07d8bee27e09e8fc1` |
| `m11-completion-report.md` | Resolution and final artifact report | `8589a61fe8a6f4ddace96e4a4ad7126c686d08654e485bc5c22d73f9fa5bc138` |
| `validation-summary.json` | Machine-readable final clean-restore validation; interpreter path made portable | original: `6ab67a273644eda2fc4ae8e3de89818cc42fd32c905f37c7e8ba991b688ac0c7`; repository copy: `59235c6a3e18584182276847f5c2c63a5ce24830a9d99e9ae4aefeac8a1e9fe5` |

The original M11 workspace archive was 105,936,992 bytes with SHA-256
`6faa9c9020bb926088f76013f38c246026dc8e62aab7d33c1a10a1d411577b8b`.
The optional setup-cache v2 archive was 227,650,494 bytes with SHA-256
`b3824928ac59215a62211c19f4c5bef08e3eb4c79ca4e7c3839ac2dc3a49082c`.
Neither archive is stored in Git.

The retained result was 34 passed, 0 failed, 0 timed out, 0 skipped, and one
inconclusive LeakSanitizer run caused by the hosted environment. Windows runtime
execution and interactive GPU validation were not performed and remain explicit
platform gaps.
