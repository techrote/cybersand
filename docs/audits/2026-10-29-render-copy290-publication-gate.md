---
title: Render-copy #290 owner authorization and atomic runtime staging gate — UNARMED
status: Current
document-kind: evidence
scope: Refusal-only controls for a future owner-requested Linux/Windows LFS publication; no producer, writer or publish action
canonical-for: []
last-reviewed: 2026-10-29
related-documents: [2026-10-29-render-copy290-publisher-preflight.md, 2026-10-28-render-copy-per-run.md, ../operations/github-development-and-release.md, ../operations/current-and-historical-validation.md]
---

# Render-copy #290 — owner and four-path publisher refusal gate

**29 October 2026; draft, unarmed, not a runtime release.** This safety-only, five-path
stack sits above [draft #298](https://github.com/techrote/cybersand/pull/298)
(producer source `c6accb68370405a4b0f30302e0f9d18a911b090b`, tree
`1131600fe9c84ba3b9876784e9ab119bd6ee6b50`), which itself consumes
[#295](https://github.com/techrote/cybersand/pull/295) and integrated
[#290](https://github.com/techrote/cybersand/pull/290). Current
`main aac0feb65e2268b74975892ce1df81e04e1a7e40` is included beneath.
No owner publication request exists. No workflow in this change holds
`contents: write`, downloads a runtime for publication, stages/pushes
a new Git LFS object, edits a runtime manifest or changes the original source.

## Exact read-only run and original evidence boundaries

The frozen executable code remains corrected source
`60915dc86631271ea8661377a3458149adda9361` with native
`world.cpp` blob `a6afd8cad4264ac2eca0362d14711158e3606760`,
oracle `test_world.cpp` blob `5613d2166c71fa49fd2b8f65e8caa93857b5d65f`.
[#298 source-matched hosted producer 40945893162](https://github.com/techrote/cybersand/actions/runs/40945893162)
is completed SUCCESS: Linux GDExtension and Windows cross-built/Windows-host
DLL both completed actual Godot 4.7 import, 23/23 render-world and patch-handoff
tests. The independently authenticated read-only
[custody reducer 40947701426](https://github.com/techrote/cybersand/actions/runs/40947701426)
completed SUCCESS and compared all original four Actions ZIP SHA/CRC and
six raw case logs; both 1,723-entry committed Git maps and 86 selected
materialized build-input maps matched, with post-build host checks.

Original producer artifact IDs/SHA-256:
- Linux host `12928489443`: `83ceb7c56260e732f3e6a5021caede7636ad9909836060048751ba9e11d5e60a`.
- Windows host `12928933019`: `374f58056ba3e31516bda9c8f7ba8e2816f1bfefbb3abdd44be9f8309ad7ac4b`.
- Linux build `12928514222`: `926f788dda17fbc35a0758141b9a657fe77690fab8a71ff8803087326c0f2772`.
- Windows build `12929921671`: `eed0ba6f8dd3121a7c01c56b5680d2eaa5a6b58c767b44789753d7f0e9adb009`.

Source-matched but **unpublished** original tested binaries are Linux
SHA-256 `0f60213c7fc3f9a1b1d7ad5143fdb22d453a452cddefd3fe4d7a7cb4d7b6cf45`
and Windows
`5d07229f0b0bd3008f413cba71a90de540b919dc5a178ba1da649c438bc8b909`.
The original source-matched one-process 165/165 ASan+UBSan proof
[40844936801](https://github.com/techrote/cybersand/actions/runs/40844936801)
has retained ZIP SHA-256
`d8856d6c8d69d76dc2706d91dd3d0cdadf3646fcf05fdacc1759b057cc16ca3f`.
Older original-source 18-minute sanitizer timeout
[40792599185](https://github.com/techrote/cybersand/actions/runs/40792599185)
remains FAILED. None of this is a new execution by the gate.

## Two pure fail-closed contracts, no runtime mutation

`tools/ci/render_copy290_publication_gate.py` contains:

1. `verify_owner_authorization` rejects any prospective request without exact
   schema/source tree/producer run ID+attempt, original Linux/Windows Actions
   ZIP IDs/digests, chosen destination and previously reviewed **writer** SHA.
   It requires an unedited, exact-text, author-association OWNER
   `techrote` issue comment **on #290**, with the same fields.
   A GitHub REST caller must fetch the comment independently and again
   immediately before any final write, verify the exact unmodified request
   came from the source commit, and enforce an exact remote-head lease.
   This pure helper has no API client or authority to publish.
2. `verify_four_path_stage` rejects any fifth file, missing platform pointer,
   symlink or executable mode, noncanonical Git LFS pointer, wrong runtime
   binary digest, mismatching original source/tree, old manifest reuse,
   incomplete/unequal source or build ledgers, widened release claims,
   missing exact original host case receipts or incorrectly keyed source/run.
   It invokes #295's paired-host byte/report verifier and binds strict
   source/test/host run, three render cases, bounded acceptance and 80 native
   inputs plus at least 549 qualified build inputs. The hypothetical
   `staged` mapping is input data, not the Git index. It does **not** attest
   the original ZIP itself or authenticate GitHub/REST/independent input
   ledgers; a future caller must invoke #295's full archive/Actions gates
   and the #298 readback methodology before staging.
3. `check-unarmed` only confirms this branch is the five-path
   workflow/checker/test/live-custody/audit delta over #298; its exact native/test Git
   blobs and **historical** manifest/pointer bytes are unchanged and the
   publisher request file is neither committed nor present.

The synthetic positive in the Python tests does **not** represent real
owner authorization, a Git LFS upload, or full external dependency custody.

## Required subsequent gates — explicitly not completed

A future write-capable publisher needs its own reviewed implementation and
registered source-sensitive native/build manifests, a fresh GitHub Actions REST
fetch and original ZIP recheck, exact source/current branch lease and
pre/post-commit index membership controls, verified LFS upload/receipt and
atomic four-path source-head-protected push. Only **after** that reviewed
implementation exists may the owner explicitly authorize a source-bound
request in a new, committed file and unedited #290 owner comment; neither
exists here. This change has no write token, request trigger, LFS stage,
publication commit, final release authorization or release pass.

Current historical native published manifests remain SHA-1 Git blobs
`6908dec74dfda8e95ed83326d321637efdd3bb28` (Linux) and
`0b8eb7213a83cb22f1169579412f3f4fb4aa87b9` (Windows), and their
retained original LFS runtime bytes remain unchanged and source-stale.

After actual publication, #290 additionally requires complete exact-final-head
ready PR Native, Linux/Windows GDExtension/Godot, applicable scoped, TSan and
sanitizer qualification, strict runtime-provenance checks and bounded review,
plus separate interactive GPU/Web performance assessment. The 86 source-selected
files do not cover every external toolchain/materialized dependency; raw Git
maps contain LFS pointers, not all payloads. Preserve older failures. Issue
[#281](https://github.com/techrote/cybersand/issues/281) and draft
[#283](https://github.com/techrote/cybersand/pull/283) remain separate;
physical ejection policy B=289 is NO-GO.

## Validation to run at this exact implementation head

- `python3 tools/ci/test_render_copy290_publication_gate.py`
- `python3 tools/ci/render_copy290_publication_gate.py check-unarmed` (in
  GitHub Actions' exact authorized branch context)
- `python3 tools/ci/render_copy290_live_custody.py --output build/render-copy290-gate-custody/receipt.json` (authenticated read-only GitHub Actions token in the exact gate workflow; re-fetch the same 4 original ZIPs and fresh REST run/jobs/artifact records)
- `python3 tools/ci/check_ci_provider_policy.py`
- `python3 tools/ci/check_docs.py`
- `python3 tools/ci/check_repository.py` is **expected to fail source-sensitive
  current-runtime provenance** until publication; never waive it to get a green.
- Exact-head documentation workflow + separate unarmed gate push workflow,
  original output and any negative failures, before reviewing further.

## Integrated live custody at the unarmed gate head

This gate also imports the read-only, previously source-qualified
`render_copy290_live_custody.py` into the actual #290/#295/#298 **stack**.
The helper is pinned to the original source `c6accb68` and four original
artifact IDs/SHA-256 digests; it requires authenticated GitHub REST run,
3 hosted jobs and 4 artifacts, original ZIP SHA/CRC/strict memberships,
6 raw case logs and both original tested ELF/PE bytes. Its independent
raw Git object scan expects exactly 1,723 source objects, and the 86
selected actual on-disk build inputs must match Git and both build hosts
including their post-build and Linux post-host receipts. An Actions
`actions: read` token is supplied only to the verification step, with
cross-host blob redirects stripping authorization headers.

This re-execution is read-only and does not install or upload a release
runtime. Treat the original custody success at [40947701426](https://github.com/techrote/cybersand/actions/runs/40947701426)
as historical; accept **new** exact-head results and retained receipt
only after the live gate run actually completes successfully. Failure
is a new evidence-custody failure, not proof of native simulation
regression. This extra verifier has no LFS or repository write token.

## Follow-up: authorization must name the actual request commit

The pure owner-consent checker now requires an explicit exact 40-hex `request_commit_sha` in the unedited owner comment on #290, in addition to the original source, Actions run/ZIPs, reviewed writer and destination branch. Consent for one committed request cannot be replayed on a later commit with identical JSON. Adversarial cases reject substituted, malformed, wrong-case, writer-equal and edited-comment values.

**Not an authorization or release:** a future separately reviewed publisher must independently authenticate the GitHub request commit, prove it is a single request-only child of the reviewed writer, verify the same commit is still the remote destination head at admission and immediately before an atomic four-path append, and check the actual Git index, Git LFS payloads and post-push commit. The pure helper cannot authenticate REST, Git refs or payloads by itself. The request file is absent and the workflow remains read-only.

## Fix impossible owner-comment/request SHA dependency

The preceding exact-request-SHA hardening uncovered an ordering deadlock: GitHub assigns an owner-comment ID only **after** that comment is created, but the comment must contain the SHA of the already-committed request. Storing `owner_comment_id` inside that request would require creating and then editing the owner comment, which the unedited-comment safeguard forbids. The request schema now **excludes** the comment ID. Instead, the future publisher must independently fetch a genuine unedited `techrote`/OWNER #290 comment **after** a source-frozen request-only commit exists, and the pure checker validates the externally returned positive integer comment ID against its canonical #290 comment URL, exact SHA-containing body, timestamps and author. The GitHub-assigned ID is a REST lookup parameter, never a field in the committed request.

Synthetic tests prove that distinct valid external comment IDs can validate the same exact committed request while malformed, swapped or embedded comment IDs fail. This restores a feasible ordering without bypassing owner consent. This branch remains **UNARMED**; no request exists and no comment authorizing LFS publication was created. Future writer source, external GitHub commit/REST authentication, index/lease checks, LFS pushes and full validation remain separate mandatory gates.
