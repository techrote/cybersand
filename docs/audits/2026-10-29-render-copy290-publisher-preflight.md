---
title: Render-copy #290 runtime publisher preparation — UNARMED
status: Current
document-kind: evidence
scope: Isolated read-only source and historical LFS identity preflight, not runtime publication
canonical-for: []
last-reviewed: 2026-10-29
related-documents: [2026-10-28-render-copy-per-run.md, ../operations/local-build-and-validation.md, ../operations/github-development-and-release.md]
---

# PR #290 — unarmed publisher preparation (29 October 2026)

This separate preparation branch is based on draft PR #290 head
`f551e8064a7d01ceb554774afb5c61e71e715c63`. The last
qualified native source is `60915dc86631271ea8661377a3458149adda9361`,
with `native/src/world.cpp` blob `a6afd8cad4264ac2eca0362d14711158e3606760`
and `native/tests/test_world.cpp` blob `5613d2166c71fa49fd2b8f65e8caa93857b5d65f`.

**No runtime publication occurs.** The preparation changes only one
read-only GitHub-hosted workflow, one preflight checker, its adversarial
unit tests and this dated record. It adds **no publication request** and
does not change any native source, Git LFS runtime, manifest, material
policy, snapshot/ACK path or Rapier/thread ownership.

## Exact preflight

The checker requires the authorized repository and preparation branch
(or a PR from that branch into `claude/render-copy-per-run`). It verifies
the frozen PR head is an ancestor, the only additions are these four
files, both corrected source/test Git blobs and SHA-256 match their
qualified bytes, and no tracked or untracked publication request exists.

For **each actual checked-in Windows/Linux manifest**, it authenticates
the manifest Git blob, original build source, runtime SHA-256/size and
canonical Git LFS pointer. All 80 historical native-source input
digests are compared to current Git blob bytes and must differ only at
`native/src/world.cpp`. All 549 historical build-input entries must have
the previously documented **six** specific changes/absences (two
modified retained files and four removed PLAY-AUTO publisher files).
This retains historical evidence without treating 79/80 as an accepted
source-matched release.

The unit tests challenge wrong repo/branch/base/event, unauthorized
file changes, missing preparation evidence, request presence, swapped,
sized-wrong or malformed pointers and extra/missing native/build drift.
The workflow uses `contents: read`, adds no write-capable jobs, and
runs the repository's GitHub-hosted provider-policy check.

## Still required before arming

This is **preparation only**, not the final branch-specific publisher.
A distinct reviewer must approve the future bounded profile, request
schema and sequence, exact-source/lease and adversarial bundle checks,
pinned dual-platform builder, complete source- and build-input manifests,
actual Linux and Windows Godot 4.7 import/render-generation/patch-handoff
and chosen retained controls, raw logs/hashes, four-path LFS append, and
atomic source-lease checks. The owner must separately authorize a
source-bound request *after* that review. No build or publication is
enabled by this checkpoint.

Final-head Documentation, Native including applicable sanitizer/TSan,
Linux/Windows GDExtension, scoped CI, independent acceptance review and
manual performance acceptance remain distinct. Earlier monolithic
sanitizer timeout is retained as a failed run; the successful 165-case
isolated sanitizer evidence is source-matched but not a same-process
lifetime test. PR #283's B=289 ejection search remains NO-GO.

## Reproduction

```sh
python3 tools/ci/test_render_copy290_publication_preflight.py
python3 tools/ci/check_ci_provider_policy.py
python3 tools/ci/render_copy290_publication_preflight.py check-unarmed
```

The third command is context-bound and requires a clean actual
GitHub-hosted checkout. Execution/CI results must be recorded only
after the run completes; this document does not predeclare success.


## Same-repository and source-event lease hardening — 2026-10-29

A new bounded safety review identified two provenance boundaries that were
implicit in the first read-only preparation: a same-named fork PR could satisfy
the branch-name predicate, and the checker did not independently compare the
checked-out Git HEAD with the triggering event's source SHA. Neither was an
observed production defect or a permission to publish. Both are now enforced:

- Workflow admission requires a **same-repository PR head** as well as its
  exact branch and base. The Python checker repeats the origin check using a
  workflow-provided repository identity. A fork with the authorized branch
  name is refused before the preflight job can execute.
- The event's source commit SHA is forwarded to the checker, which requires
  exact equality with `git rev-parse HEAD`; missing, malformed or different
  identities are refused. The checkout was already pinned to the source event
  SHA, but is now checked independently instead of relying on checkout alone.
- Push and PR workflow events have distinct concurrency groups. This removes
  cross-event cancellation while retaining same-event supersession.
- Six new negative/positive unit cases cover fork origin, missing origin, equal
  source SHA, divergent HEAD and missing/malformed event SHA. The full
  adversarial suite now contains **29 tests**.

**Source-locked execution before this documentation amendment:** feature
`f551e8064a7d01ceb554774afb5c61e71e715c63`; preparation
`bd2509ccf0fca624c5c6034abc877fb9f38faf2f`.
[Push preflight 40825298317](https://github.com/techrote/cybersand/actions/runs/40825298317)
and [PR preflight 40825301860](https://github.com/techrote/cybersand/actions/runs/40825301860)
both report success on that source. The downloaded PR job log states
`Ran 29 tests`, `OK`, provider-policy errors `[]` and
`RENDER_COPY290_PREFLIGHT PASS`. Read-only manifest/LFS identity and
the absent publication request remain mandatory.

The intermediate [40825277534](https://github.com/techrote/cybersand/actions/runs/40825277534)
failed while the checker and tests had been updated but the workflow had not yet
supplied its event variables. It is retained as a transient incomplete-checkpoint
failure, **not** a runtime, sanitizer, or render-cell regression. Earlier cancelled
intermediate workflow runs are also not counted as passing evidence.

**Review and admission limits:** the same authenticated account authored these
guards. This record does not supply an independent reviewer, a live dual-host
publisher, any owner-authorized publication request, final release CI, new LFS
objects, runtime provenance, or readiness to merge. All pre-existing #290,
#281 and #283 restrictions remain in effect.


## Pure paired-host acceptance contract — 29 October 2026

Implemented a side-effect-free future-publisher receipt verifier in the existing
Python preflight and synthetic adversarial unit tests. The verifier requires both
platforms, same immutable source/tree and Actions run/attempt, pinned Godot
4.7/godot-cpp/SCons identity, expected physical host runner and compiler,
Linux ELF64/Windows PE x86_64 bytes, matching SHA-256 and lengths, and original
logs for import, render-generation (23 assertions, 0 failures), and patch handoff.
It refuses missing/swapped host bundles, cross-run evidence, duplicate/invalid
JSON, changed logs, malformed case inventories, nonzero exits, timeouts, hidden
errors and skips.

These test fixtures contain synthetic binaries and logs ONLY. Passing their
tests does not establish a newly built or exercised runtime. This module is
not invoked by an armed workflow, adds no request, does not upload LFS and does
not grant publication authority. Its three cases are a proposed minimum; the
complete native/current-app controls and exact deadlines remain for independent
review before any request can be authorized. The subsequent publisher must also
verify original ZIP SHA-256/CRC, complete build/source input hashes, actual host
execution, atomic branch lease, four-path staging and materializable LFS objects.
Historical published manifests and binaries remain unchanged. Draft #290 and
separate #283 admission fences remain in force.


### Synthetic fixture argument-name correction — 2026-10-29

The first implementation of the 39-test contract at `7dc163d5a933f493a0f1d635322a07027251c806`
failed two source-matched hosted preflight runs: [push #40831213422](https://github.com/techrote/cybersand/actions/runs/40831213422)
and [PR #40831218359](https://github.com/techrote/cybersand/actions/runs/40831218359).
The raw job logs both show **39 tests, one failure**, specifically
`HostReceipts.test_false_report(change={'platform': 'windows'})`.
The synthetic test helper's argument `platform` accidentally selected a bundle
instead of changing that receipt's platform field; consequently the test made no
malformed receipt and expected a false-positive rejection. The helper's selector
is now named `target`, preserving a positional Windows selection while permitting
`platform` as an independently mutated receipt field. These earlier CI failures
remain historical test-harness failures, not engine regressions. Fresh exact-head
CI remains required; this amendment does not assert any unobserved pass.
