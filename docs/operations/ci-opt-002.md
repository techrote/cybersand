---
title: CI-OPT-002 qualification finisher and runner cost accounting
status: Planned
document-kind: guide
scope: Isolated Draft/HOLD CI changes, source admission and actual runner measurements
last-reviewed: 2026-11-21
related-documents: [github-development-and-release.md, ci-execution-and-performance.md]
---

# CI-OPT-002 — qualification finisher

This is an isolated Draft/HOLD implementation of issue #706, stacked on GENTEK-80-WATER PR #691. No change to the active #691 branch or its current source-locked publication has been authorised by this follow-on.

## Implemented in this candidate

- Full Gentek native, graphical and owner-package publication starts only after an explicitly committed change to tools/ci/gentek80_water_publish_request.json on the integration branch. Ordinary Art edits and Gentek source fixes cannot trigger new multi-hour qualification runs. A new publish request must increment request_sequence on the final source commit. The existing publisher strictly verifies request schema, exact source, remote-branch lease and all runtime identities.
- A branch-scoped concurrency group permits one executing campaign and the latest pending request without cancelling a running publisher mid-write. Remote-source lease checks recur before major Linux and Windows test, build, 80-style Workbench, package and publication phases. Superseded old jobs may stop at the next boundary; old results remain immutable. The final publisher still commits exactly four source-matched runtime/provenance files through a force-with-lease.
- ci_opt_runtime_preflight.py checks actual native source hashes, platform labels, manifest status, and LFS-pointer or materialized DLL/SO identities before running a six-cohort graphics qualification or full documentation/historical validation. A stale source-only candidate is a RED blocked_unpublished_runtime; it cannot masquerade as a pass.
- Documentation CI continues to materialise all required LFS objects after successful preflight and retains every original check. Palette CI retains every actual native GL and Windows ANGLE cohort after admission. Native and GDExtension matrix/shard counts remain unchanged.
- ci_opt_run_audit.py is offline, consumes complete preserved Actions job records, distinguishes summed runner-minutes from wall span, and refuses source-incompatible, missing-job or failed/skipped before/after comparisons.

## Evidence and scope

The observed historical baseline is in docs/audits/2026-11-21-ci-opt-002-baseline.json:
- Full Gentek campaign run 44855726801: approximately 245 runner-minutes; Windows owner/package approximately 149 minutes, Linux approximately 89.
- Standard GDExtension run 44889085978: approximately 167 runner-minutes, including 47 platform shards consuming around 149.
- Native C++ run 44889085997: approximately 98 runner-minutes, six families; worldgen approximately 36.
- Three superseded historical Gentek Linux attempts ran approximately 76 minutes apiece before their remote source-lease rejection.

These are historical exact-run measurements, not proof of the current candidate or a measured CI-OPT speedup. The objective of avoiding more than one expensive run per admitted source is an architectural safeguard; >=30% savings is a target requiring a later controlled same-coverage comparison.

## Acceptance and rollback

Run the quick CI-OPT-002 workflow tests, CI provider policy and pinned actionlint. Then independently review a staged pair of rapid source/request updates, a pending supersession, remote branch changes at every phase, and no mid-publication cancellation. The ordinary final-head Native, GDExtension, Documentation, Wave and Palette checks still need successful source-matched runtime evidence. A real Gentek request still requires all 80 generator defaults, 520 captures, 240 refusal cases, 80 independent replays, graphical Workbench author/save/reopen, and independently extracted Windows package.

Do not change default gameplay, experiment baselines, historical evidence, owner NVIDIA acceptance or branch protection requirements. No Ready promotion or merge without owner approval. If qualification or measured performance regresses, revert the CI-specific commit on its own branch; no game/runtime files have been modified here.

Design choice: explicit source-request admission and non-cancelling branch-scoped concurrency were selected over automatic full validation on every push or unverified cancellation of mid-publication work. Reversing the choice reintroduces redundant multi-hour jobs; the safer future alternative is independently tested phase-aware cancellation.
