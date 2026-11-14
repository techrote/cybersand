---
title: Render-copy290 runtime publisher request/lease preparation
status: Current
document-kind: audit
scope: Unarmed four-path source-matched Linux/Windows LFS publisher, reviewed gate boundaries, refusal tests, and outstanding authorization
last-reviewed: 2026-10-29
related-documents: [../operations/local-build-and-validation.md, 2026-10-28-render-copy-per-run.md, 2026-10-29-render-copy-sanitizer-matrix-receipt.json]
---

# Render-copy290 four-path runtime publication — UNARMED

## Authoritative scope

Temporary publisher source is stacked on corrected source `60915dc86631271ea8661377a3458149adda9361`
through draft #290 `ddf812f34c533f654f1488b9115eb0256305a288`,
unarmed #295 `6f57b584fba3104287dcaa4ba96e3dded7a32b90`,
and reviewed read-only producer #298 `c6accb68370405a4b0f30302e0f9d18a911b090b`.
The native world/test Git blob pins remain `a6afd8cad4264ac2eca0362d14711158e3606760` /
`5613d2166c71fa49fd2b8f65e8caa93857b5d65f`.

This branch adds only `.github/workflows/render-copy290-runtime-publication.yml`,
`tools/ci/render_copy290_runtime_publication.py`, its adversarial unit tests,
and this audit. The request path `tools/ci/render_copy290_publish_request.json`
MUST BE ABSENT throughout preparation. Unarmed pushes may run read-only CI
guards, but the compiler, host tests and `contents: write` publisher
are skipped. No runtime/DLL/manifest/LFS pointer is changed by preparation.

## Explicit authorization, not a synthetic switch

The publication request, if explicitly approved later by the owner, must be a
**single-parent commit** on the dedicated publication branch, changing **ONLY**
the request JSON. It binds an `authorized_parent_sha` that equals its exact
reviewed pre-request parent, positive `request_sequence`, four exact allowed
runtime/provenance paths, and an actual GitHub issue #290 comment ID.
The owner comment must be authored by `techrote`, have
`author_association=OWNER`, and contain the exact source/sequence-bound text:

```text
AUTHORIZE render-copy290 four-path LFS publication
parent=<40-hex pre-request source SHA>
sequence=<positive integer>
scope=source-matched-linux-windows-development-runtimes
```

The request records SHA-256 of that exact comment body. The job fetches
the comment from authenticated GitHub REST and rejects a different
author, issue, body, hash, source parent or sequence. A file claiming
permission by itself is insufficient. The user has NOT authorized
any particular SHA/sequence or requested creation of this request
in this preparation checkpoint.

## Source and publication protocol

1. Require literal GitHub-hosted runners and the exact dedicated branch,
   repository, checkout/event source SHA, workflow and current remote lease.
   Refuse changes to native source/oracle blobs and unreviewed extra paths.
2. From the exact request commit, independently build the Linux GCC13 and
   Windows LLVM-MinGW Godot-cpp GDExtensions with pinned Godot 4.7,
   Rapier2D 0.35.2 and SCons 4.10.1; run actual target-OS import,
   render-world **23/0** and patch-handoff with no skips or errors.
   Preserve original raw host/build ZIPs, compiler logs and source ledgers.
3. Writer (the ONLY job with `contents:write`) verifies the same run's
   successful GitHub-hosted job metadata through authenticated REST,
   downloads the original host/build artifacts using GitHub's independently
   returned ZIP SHA-256, refuses duplicate/missing/corrupt members, checks
   both original three-case receipts and Windows build/host byte equality.
   Selected 86 on-disk build inputs, post-build/host snapshots, and both
   tracked Git-blob maps must agree; canonical runtime input ledgers are
   regenerated from the actual immutable source, not old manifests.
4. Stage exactly:
   - `godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so`
   - `godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll`
   - `godot/addons/cybersand_native/runtime-provenance.linux.json`
   - `godot/addons/cybersand_native/runtime-provenance.json`
   Check new binary SHA-256/size, actual ELF64 ET_DYN / PE32+ DLL, complete
   source/build-input ledgers, correct staged LFS pointer OIDs, regular
   stage-zero paths, exact index allowlist and no unrelated working delta.
5. Recheck request, branch lease and index immediately before the single-parent
   four-path commit. Use `git push --force-with-lease` against the *exact
   built-source SHA* so concurrent updates fail instead of being overwritten.
   The Git LFS pre-push hook must upload the actual new objects, not merely
   Git pointer records. Independent post-push object materialization, strict
   provenance and full final ready-PR Native/Godot/scoped CI are separate.

## Qualification limits

The request, complete builder and write job are not an authorization to publish.
Their adversarial unarmed tests qualify refusal semantics only; no actual
four-path publication, source-matched newly committed binaries or strict
ready-PR gate may be claimed without a real explicitly approved request,
full two-host execution, original artifact custody, exact-head Git LFS
upload, host replay and repository integrity verification.

The historical initial full-sanitizer 18-minute timeout remains failed;
the corrected-source [one-process ASan/UBSan 165/165 run](https://github.com/techrote/cybersand/actions/runs/40844936801)
is source-matched but leaves leak detection/TSan distinct.
No Web/browser, representative desktop GPU pacing or physical
SOL281 detachment/ejection admission is implied; #283 B=289 stays NO-GO.

## Unarmed implementation and original hosted qualification — 2026-10-29

**Current implementation checkpoint:** native executable and oracle remain
`60915dc86631271ea8661377a3458149adda9361` and their exact pinned
Git blobs. Temporary publisher is [draft PR #301](https://github.com/techrote/cybersand/pull/301),
stacked on read-only #298. The four preparation paths are the only delta
from producer `c6accb68370405a4b0f30302e0f9d18a911b090b`.
There is **no** tracked `tools/ci/render_copy290_publish_request.json`,
and none has been staged, committed or armed.

### Source, tests and branch-gate evidence

[Source-frozen unarmed Actions 40957125837](https://github.com/techrote/cybersand/actions/runs/40957125837)
at implementation source `61128ac61cbc2320baf5f21a100a3a27adbd046a`
**SUCCESS**. The original GitHub-hosted request-gate job log reports:

- `Ran 40 tests`, `OK`; direct positive and refusal cases exercise
  the owner request/comment/schema/hash, wrong request sequence/branch,
  unsafe/duplicate ZIP, original Windows PE32+ and Linux ELF64 ET_DYN,
  exact LFS pointer/index, a fully simulated two-platform manifest
  and four-path stage, nonmutating failure for missing/mismatched
  host evidence, in-progress GitHub Actions run/job/artifact custody,
  and rejection of fork/replay/failed host jobs.
- Provider policy reports `errors: []`. The actual current
  canonical source-input ledger is **80 native + 557 build inputs**.
  Each selected checkout file was compared byte-for-byte with its
  committed Git blob, not the previous stale runtime manifest.
- `RENDER_COPY290_PUBLISHER UNARMED PASS`; all **four downstream jobs**
  (`linux-host`, `windows-build`, `windows-host`, and the
  `contents:write` four-path LFS append) were **SKIPPED**.
  No compiler, host runtime, LFS write or request was invoked.
- The producer's previous [real integrated run 40945893162](https://github.com/techrote/cybersand/actions/runs/40945893162)
  and independently authenticated [run 40947701426](https://github.com/techrote/cybersand/actions/runs/40947701426)
  remain separate, original-byte evidence for source
  `c6accb68`. They do **not** execute this new write-capable
  source or authorize its request.

The write workflow is deliberately **not fully executed**:
its request gate requires a frozen single-parent, request-only
authorization commit and an owner-authored GitHub issue #290
comment, fetched with `issues:read`; build and host jobs then
recheck the source/branch lease before compiling. The only job with
`contents:write` must authenticate original current-run job/artifact
metadata, validate real Linux/Windows build-and-execution bytes,
regenerate complete runtime input manifests and stage exactly four
LFS paths. After a leased push it independently fetches both
new remote LFS payloads into a **fresh Git object store** and
checks SHA-256/size/new-world-source before claiming published-object
custody. This post-push validation is a release gate, not a promise
of publication.

### Retained preparation failures

The historical unarmed run [40954761887](https://github.com/techrote/cybersand/actions/runs/40954761887)
first **PASSED 26/26 tests**, but did not exercise the full build
input inventory. Source-ledger hardening subsequently revealed a
one-byte-off raw `git cat-file --batch` slice and produced failed
verification runs [40954960368](https://github.com/techrote/cybersand/actions/runs/40954960368)
and [40955102901](https://github.com/techrote/cybersand/actions/runs/40955102901).
The parser was repaired and [40955298520](https://github.com/techrote/cybersand/actions/runs/40955298520)
**PASSED** 80/557 source/build inventory.
Synthetic stage and pointer/index guards subsequently passed 29 and
32 tests; newly added test fixtures initially omitted two actual REST
fields, resulting in [40956188977](https://github.com/techrote/cybersand/actions/runs/40956188977)
**FAILED (synthetic fixture; zero runtime jobs)**. It was corrected
before the positive 40-test gate. A later
[40957063640](https://github.com/techrote/cybersand/actions/runs/40957063640)
fixture had stale mocked owner fields after the source-bound provenance
extension and also **FAILED before building**. Its successor
[40957125837](https://github.com/techrote/cybersand/actions/runs/40957125837)
is the 40-test source-bound green. None of these errors is relabeled
as a Cybersand native-engine regression or as positive release evidence.

### Unresolved acceptance boundaries

This staged write-capable implementation **has not demonstrated**
a real owner-authorized request, current-request source matched
Linux/Windows rebuilt runtime, complete actual publisher manifest,
remote LFS materialization, strict source-sensitive repository
checker pass or postpublication final-head native/Godot/TSan/Docs
matrix. The old published binaries and manifests are intentionally
unchanged and source-stale; no temporary verified producer DLL
is reinterpreted as a published object. The historical monolithic
ASan/UBSan timeout stays failed alongside the later corrected-source
165/165 positive run. Leak detection, TSan, real desktop/Web rendered
pacing and #281 structural-detachment/physical relocation remain
separate gates; #283's B=289 search stays **NO-GO**.
