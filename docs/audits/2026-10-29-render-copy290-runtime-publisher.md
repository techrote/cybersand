---
title: Render-copy #290 request-gated LFS runtime writer preparation
status: Current
document-kind: evidence
scope: Separately stacked write-capable publisher implementation, unarmed until an exact request commit and owner authorization exist
canonical-for: []
last-reviewed: 2026-10-29
related-documents: [2026-10-29-render-copy290-publication-gate.md, 2026-10-29-render-copy290-publisher-preflight.md, 2026-10-28-render-copy-per-run.md, ../operations/github-development-and-release.md]
---

# RENDER-COPY-290 request-gated runtime writer — UNARMED preparation

**29 October 2026. DRAFT / no request / no publication.** This separate writer
preparation is stacked directly on the reviewed read-only gate at
`d249435d041fd27e0508701e69fd6e7a29a8610a`. It intentionally does not modify
`native/src/world.cpp`, the native oracle, either runtime, either provenance
manifest, PR #290, or the producer evidence. Its source delta is exactly this
workflow, helper, adversarial test and audit.

The producer remains exact source `c6accb68370405a4b0f30302e0f9d18a911b090b`
(tree `1131600fe9c84ba3b9876784e9ab119bd6ee6b50`) and corrected executable
`60915dc86631271ea8661377a3458149adda9361`, with frozen world/test blobs
`a6afd8cad4264ac2eca0362d14711158e3606760` and
`5613d2166c71fa49fd2b8f65e8caa93857b5d65f`.

## Trigger and authority ordering

The writer branch reacts only to changes in its four preparation files or the
future request file. There is no `workflow_dispatch`. A writer-only source runs
guards and admission with repository permissions read-only. The absent request
makes `armed=false`, so both the reconstruction and write job are skipped.

A future request must be a **one-file direct child** of the reviewed writer SHA,
must bind the original producer source/tree/run/attempt/artifact IDs+ZIP hashes,
and must name this exact destination branch. Its first push cannot manufacture
owner consent. The owner can then post an unedited #290 OWNER comment whose exact
body names that already-existing request commit SHA, original producer identities,
reviewed writer SHA and destination branch. Re-running the **same request SHA**
after that comment is the normal arming route; no comment edit or second request
commit is accepted implicitly.

The helper fetches #290 comments through authenticated GitHub REST, requires zero
or one exact owner authorization and fails closed on duplicates. Before build-byte
reconstruction and again immediately before staging it verifies the remote branch
still equals the authorized request commit.

## Original artifact and provenance reconstruction

An armed run does not rebuild or substitute the tested binaries. It freshly
authenticates producer Actions run `40945893162`, its three successful hosted
jobs, and the four original artifact IDs/digests:

- Linux host `12928489443`, ZIP SHA-256
  `83ceb7c56260e732f3e6a5021caede7636ad9909836060048751ba9e11d5e60a`.
- Windows host `12928933019`, ZIP SHA-256
  `374f58056ba3e31516bda9c8f7ba8e2816f1bfefbb3abdd44be9f8309ad7ac4b`.
- Linux build `12928514222`, ZIP SHA-256
  `926f788dda17fbc35a0758141b9a657fe77690fab8a71ff8803087326c0f2772`.
- Windows build `12929921671`, ZIP SHA-256
  `eed0ba6f8dd3121a7c01c56b5680d2eaa5a6b58c767b44789753d7f0e9adb009`.

It rechecks strict ZIP membership/CRC, six raw host logs, exact ELF/PE tested
bytes, 1,723 committed Git-object SHA-256 values, both original tracked-source
maps, all 86 selected materialized build inputs and post-build/post-host checks.
The prospective manifests use the exact 80 native inputs plus the conservative
full tracked-Git remainder as build/source custody; the original source-selected
86-file materialized set and external Godot/Rapier/godot-cpp/SCons/LLVM-MinGW
pins are separately retained in the publication receipt.

Source-matched tested runtime SHA-256 values remain:

- Linux `0f60213c7fc3f9a1b1d7ad5143fdb22d453a452cddefd3fe4d7a7cb4d7b6cf45`.
- Windows `5d07229f0b0bd3008f413cba71a90de540b919dc5a178ba1da649c438bc8b909`.

## Write boundary

Only the final job has `contents: write`. It independently reconstructs the
original bundle again rather than trusting the preceding retained artifact,
copies the two tested binaries into the canonical paths, lets Git LFS clean them
to canonical pointers, stages the two provenance manifests, and then runs the
read-only gate's actual four-path verifier against the real Git index.

The final commit must be the single direct child of the authorized request SHA.
The push uses an exact `--force-with-lease=refs/heads/...:<request SHA>`; it
cannot overwrite a later branch update. The existing Git-LFS pre-push hook is the
LFS object upload boundary. A post-push check requires the remote ref to equal the
new commit and the commit diff to contain exactly the four runtime/provenance
paths. A final receipt is retained only after that verification.

## Current limits and required later gates

This preparation does **not** create `tools/ci/render_copy290_publish_request.json`,
does not create an owner authorization comment, and cannot currently enter its
prepare/publish jobs. No LFS pointer/object or provenance manifest changes in this
checkpoint.

If a future source-bound request is explicitly authorized and publication
succeeds, PR #290 still requires the complete exact-final-head ready-for-review
Native, applicable TSan/ASan/UBSan, Linux/Windows Godot/GDExtension, documentation,
scoped/release provenance gates and bounded review. Target-PC interactive GPU/Web
performance remains manual. The original 18-minute sanitizer timeout
`40792599185` stays FAILED; the later one-process 165/165 sanitizer pass retains
its own exact-source scope. Issue #292's sibling material/RGBA INT64 defect is
separate. Issue #281 / draft #283 B=289 physical ejection remains NO-GO.
