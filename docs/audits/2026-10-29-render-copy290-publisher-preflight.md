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


## Original Actions ZIP and independently pinned run-identity admission — 2026-10-29

A further read-only hardening checkpoint adds a proposed paired original ZIP
verifier, not a publisher. The previous synthetic receipt checker compared the
Linux/Windows run IDs with each other but did not require an independently
observed Actions run/attempt. It also did not read original ZIP bytes or validate
their externally published SHA-256 digests and internal CRCs.

The updated verify_host_receipts now REQUIRES a separately pinned positive
integer Actions run ID and attempt, rejecting both mixed and consistently
replayed receipts. New verify_host_artifact_archives requires exactly one original
ZIP and independently authenticated sha256 digest per platform. It refuses
missing, extra, duplicate or unsafe entries; oversized/encrypted/unsupported
members; invalid ZIP structures; CRC failures and swapped host payloads.
The proposed fixed archive layout contains one JSON receipt, one OS-specific
runtime and three bounded raw host logs, all submitted to the existing
strict runtime/host-case verifier under the external run/attempt identity.

TRUST LIMIT: The future caller must independently authenticate the expected
digests, source/tree, run ID and attempt from GitHub Actions and verified Git.
Passing self-asserted metadata is not evidence custody. The fixed ZIP layout
is a proposed producer contract, not a deployed producer. All new tests use
synthetic archives and do not establish real Linux/Windows execution, LFS
publication, or production acceptance. The workflow remains read-only and
without a publication request. Historical LFS payloads/manifests remain intact.
Ready-head Native/Godot/documentation/scoped CI, separate review and explicit
source-bound owner authorization are still required.


## Adversarial log-prefix refusal — 2026-10-29

A fresh bounded review of the **read-only, synthetic** host-receipt verifier
identified a fail-open case: the previous negative-diagnostic expression was
anchored at column zero, so a log containing a valid pass marker **followed by**
`  ERROR:`, a timestamp-prefixed `ERROR:`, or an indented `SKIPPED:`
could pass if the self-reported log hash and receipt were recomputed. This is
a checker admission defect, not a reproduced engine/Godot defect and not new
runtime evidence.

The checker now searches the **whole original log** for explicit error/skip,
timeout, watchdog, fatal and Python traceback diagnostics, including indented
or prefixed lines. A new adversarial unit test recomputes the forged receipt
hash for six such suffixes and requires refusal in every case. This changes
only the two preflight Python files and this addendum, not any runtime,
publisher authority, source/oracle or historical receipt. The prior 51-test
checkpoint remains historical; **52-test exact-head CI is pending** until
the new workflow runs complete.

Publication is still **UNARMED**. The future live publisher still needs
independent Actions artifact/run/job custody, genuine Linux+Windows builds,
actual Godot host execution, full source/build manifests, explicit
source-bound owner authority, atomic four-path LFS publication and final
acceptance gates. No old ZIP, failed job, manifest or binary was replaced.

## Native shared-library kind refusal — 2026-10-29

Independent read-only preflight review found that the proposed paired-host
receipt verifier accepted a same-architecture **executable** as a purported
GDExtension runtime if its bytes and receipt hash were recomputed: the original
Linux header guard checked ELF class/endian/machine but not `ET_DYN`, while
the Windows guard checked PE x86_64 without requiring `PE32+` or
`IMAGE_FILE_DLL`. These are *publication-verifier admission gaps*, not
observed faults in existing native binaries or Godot tests.

The pure verifier now also requires Linux ELF64 `ET_DYN` and Windows PE32+
with the DLL characteristic. A new adversarial test probes Linux `ET_EXEC`,
Windows non-DLL PE and PE32 by recomputing the forged payload's receipt
SHA-256; all must be rejected while the positive synthetic pair stays valid.
This is one additional test method (three negative subcases), increasing the
adversarial suite from 52 to **53 tests** if confirmed by hosted execution.
This guards binary *type*, not linker correctness, loadability, actual
provenance, trusted Actions job custody or real host execution.

No production/native source, frozen #290 oracle, GDExtension runtime,
manifest, original artifact or publication authority changed. PRs #290/#295
stay draft; #283 B=289 stays NO-GO. The earlier historical runs remain
unchanged. Exact-head preflight CI must qualify this edit before its
53-test result can be claimed.

## Noncolon host-failure marker refusal — 2026-10-29

A new source-bounded, read-only admission review found that the proposed
paired-host verifier could accept a host log with a valid success marker
followed by `[fail]`, `FAILED:`, `Failure:`, `Segmentation fault`,
`Aborted (core dumped)`, or `PANIC:` if its self-reported log hash
was recomputed. The old forbidden-diagnostic expression covered `ERROR:`,
`FATAL:`, skips, and timeouts, but none of those noncolon forms.
This is a synthetic evidence-verifier gap; **no Cybersand production crash
or host test failure is inferred**.

The updated expression refuses those six forms anywhere in the original log,
including after positive markers, without rejecting the normal
`23 assertions, 0 failures` success line. A new six-arm adversarial test
rehashes the forged bytes and requires refusal, raising the expected test
method count from **53 to 54**, subject to fresh exact-head CI. The previous
53-test [push run 40867724298](https://github.com/techrote/cybersand/actions/runs/40867724298)
and [PR run 40867733597](https://github.com/techrote/cybersand/actions/runs/40867733597)
were independently rechecked as successful on exact source
`3d469a0fdfb9b1c5c099c3f79aa006cb7de1fc81`.

This change is limited to the existing checker, synthetic tests, and dated
audit. The preparation workflow remains **read-only and unarmed**, with no
runtime or manifest publication and no source/ACK/material/Rapier change.
A clean synthetic verifier cannot attest to authentic GitHub runner/job
custody, real dual-platform builds, Godot extension loadability, full
source/build provenance, owner authorization, an atomic four-path LFS
append or final ready-head acceptance. PR #290 remains draft; #283's
B=289 ejection policy remains NO-GO. The original sanitizer timeout and
older negative CI evidence are preserved.


## Independent GitHub Actions custody preflight — 2026-10-29

A further **pure, nonpublishing** guard models the trust boundary missing
between two self-reported host ZIPs and GitHub's authoritative Actions run,
job and artifact records. The new \`verify_actions_custody\` function requires
the fixed repository ID and same-repository head; exact externally pinned
source SHA, run ID/attempt, authorized branch/workflow, successful completed
**push** run; three distinct successful Linux-build/host, Windows-build and
real-Windows-host jobs; their named build/host steps without skipped or failed
steps; and two distinct unexpired artifacts with trusted Actions
\`sha256:\` digests, names, size and matching run/source/repository metadata.
It returns the externally supplied paired artifact digests to feed the
already-existing byte/CRC/receipt verifier, **not a publication decision**.

The six synthetic test methods include negative source, fork, replayed
run/attempt, workflow/event, job/step failure, artifact substitution,
duplicate, expiry, forged size/digest and boolean-ID cases. Their success
would validate this narrow metadata shape only. **No live future producer
exists yet** and synthetic REST-like objects are not authenticated.
The eventual publisher must retrieve metadata independently from GitHub's
Actions API, authenticate its API transport and checked-out source, lock
the actual producer job/step vocabulary through separate review, download
and verify the original ZIP bytes, prove full source/build-input integrity,
and obtain a separately approved source-bound write request. A green
read-only preflight cannot supply these steps.

This change preserves the existing read-only workflow, historical
LFS binaries and manifests, the original failed sanitizer timeout, and
draft separation from #283 (B=289 remains NO-GO). It is not a source-matched
runtime publication or an independent human release approval.


### Actual REST job identity/host-label refinement

Read back the original GitHub Actions REST run/job envelope for
[source-matched host run 40796772252](https://github.com/techrote/cybersand/actions/runs/40796772252).
The raw jobs endpoint provides explicit run_attempt, head_sha, head_branch,
labels, runner_group_name, runner_id and runner_name. Unlike the truncated
normalized connector view, those are directly available to an authenticated
future consumer. The proposed custody guard now **requires** matching
attempt/source/branch, GitHub Actions hosted runner group/name and the exact
approved ubuntu-24.04 or windows-2022 label for all three jobs. It refuses
missing identity fields, self-hosted runners or swapped OS labels. Original
successful host history is schema reference only; those older ZIPs are not
the new five-member publication artifacts, nor current runtime provenance.
