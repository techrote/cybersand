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
