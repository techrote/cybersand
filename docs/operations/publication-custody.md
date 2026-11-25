---
title: Runtime publication custody preflight
status: Current
document-kind: runbook
scope: Additive offline custody verifier on the CI-ENGINEERING-CLOSURE-001 Draft candidate; no existing publisher integration or product acceptance
canonical-for: [publication-custody-preflight]
last-reviewed: 2026-11-24
related-documents: [github-development-and-release.md, ci-execution-and-performance.md, ci-engineering-closure-001/FINAL-DECISION-PACKET.md]
---

# Runtime publication custody preflight

## Purpose and adoption boundary

[publication_custody.py](../../tools/ci/publication_custody.py) checks a prepared
two-platform Git/LFS publication stage, or replays the custody of an immutable
publication child. It reads Git, local binary/LFS bytes and retained artifact
archives. It does not stage, commit, upload, push, cancel, dispatch, promote or
merge anything. Its success means **custody verified within the supplied trusted
contract**. It always emits `publication_authorized: false`,
`qualification_semantics_verified: false` and
`remote_lfs_storage_verified: false`.

This helper is implemented only on the CI-ENGINEERING-CLOSURE-001 Draft candidate.
No active Actor, PUBPRES, ObjectShard, Equipment, Art, Batch Lab, SWARM or other
programme workflow consumes it. Existing source, execution, graphical,
installed-package and human acceptance gates remain in force. It is an additive
integrity check, not a replacement for the programme's semantic reducer.

## Recovered publication evidence

Accepted `main` inspected on 24 November is
`00cdb02f103265b6dc5224c68283e9a0c8cb449f`. Its Actor publisher does not contain
the later unchanged-pointer helper. The permanent Actor-specific implementation
belongs to [Draft #762](https://github.com/techrote/cybersand/pull/762), head
`47e87cb84cf302b4e283cfc7e8f884e01b7b4c73`. It is not accepted-main behaviour.

| Evidence | Exact identity | Observed disposition |
|---|---|---|
| Original [#748 qualification](https://github.com/techrote/cybersand/actions/runs/45068056417) | Run `45068056417`, attempt `1`; source `a85b3a5655e7f711ce27fbfc8fee7819332006f0`; tree `71abcb257f775db8ba4751b23d50d9428dd7c9ee` | Linux and Windows qualification jobs succeeded; publication job `137361496328` failed its fixed four-changed-path stage. The workflow remains **failure**. |
| Isolated [custody recovery](https://github.com/techrote/cybersand/actions/runs/45073351155) | Run `45073351155`, attempt `1`; verifier workflow source `66218ba9170939b6517b5452f837fb838c88cd72` | Reused the original immutable campaign for tested source `a85b3a…`; published its single child `30a4c3032fbbc0feb4b31b66bcfa64632ea3d84a`. The workflow source is not a new tested product source. |
| Later [#762 full campaign](https://github.com/techrote/cybersand/actions/runs/45112739808) | Run `45112739808`, attempt `1`; source `af13c6a3926da0749a32708a44a12b66ed5d0c7c`; tree `3ab33cfd661b2204d965803f0e9f8312e7e43aa0` | Three required jobs succeeded: Linux `137488547370`, Windows/package `137494640600`, publication `137502992790`. Published single child `47e87cb…`, with four changed paths. |

Actual downloaded artifact ZIPs were compared with their GitHub API SHA-256
digests before inspection; no historical record was changed. In the original
campaign the Linux SO is 5,253,840 bytes, SHA-256
`1aa42ed85b2fafa31d1c521224ed9d4f8199709b41cbe8b9c1299f9c2392fb4f`.
The rebuilt bytes equal the parent's retained LFS identity. The Windows DLL is
5,811,200 bytes, SHA-256
`db24ec1de3a259608a4a44ad7b8a46c7f87d1eb4758a99fd75ed62aa06ca9336`.
The actual publication child changes the Windows pointer and both provenance
files: **three** tracked changes. The original publisher's printed four-path
intent list is not proof of four changed Git paths.

The later #762 source campaign's retained Linux, Windows and extracted Windows
reports contain respectively **42, 42 and 18 unique process records**. Each
record has natural completion and exit code zero, and every original raw log
matches its recorded hash. Their report SHA-256 identities are respectively
`c98552bac765bf45c99b54cac482c7bd7d6587e65c97a553d4ad097db3273366`,
`ecffe70c3b4543dee9892cc978e1b99b2a15a9f1fe2710e69b30362d8f69d11b`, and
`eda699699bca4cc2acdf996597f8010611fb8c8e757a09942d8bfc771a5bd7ca`.
The retained provenance refers to these exact reports. The new closure helper's
local tests are not additional native or graphical execution of that source.

| Retained #762 artifact | API archive SHA-256 | Inspection scope |
|---|---|---|
| [Linux 14791386230](https://github.com/techrote/cybersand/actions/runs/45112739808/artifacts/14791386230) | `84795b2c9911164423a9649bed3a63a229398326a6827d5ea46352ab19f6e6eb` | Actual SO, candidate, report, all 42 log joins |
| [Windows runtime 14790766458](https://github.com/techrote/cybersand/actions/runs/45112739808/artifacts/14790766458) | `35b5fd89968aeebcdc40c57f1317b59d95938cad768005bdf14a60fbc716c8b4` | Actual DLL and candidate identities |
| [Windows evidence 14791814169](https://github.com/techrote/cybersand/actions/runs/45112739808/artifacts/14791814169) | `1fffbe456cad79b9db2b5ada3ddc5dc6b2d56cd37f33066a67169cb2981113ad` | Source/extracted reports and all 60 log joins |
| [Publication 14792097545](https://github.com/techrote/cybersand/actions/runs/45112739808/artifacts/14792097545) | `f9f23fc15e94bb9433d613f9f11ed481c45802054e946a955f8f0c4d223a1b09` | Source/run/attempt provenance, publication child, passed repository check |

The closure review did not redownload the 94 MB portable evaluator. Its prior
owner-package claim remains attributed to #762's own qualification and retained
installed-package records. No physical Windows/NVIDIA acceptance is claimed.
See [#761](https://github.com/techrote/cybersand/issues/761) for the original
follow-up contract and the closure decision packet for the final disposition.

### Actual immutable verifier replay on 24 November

The closure lane additionally replayed the real #762 immutable child through
the new helper: **custody verified**, with contract SHA-256
`172f77d2f56c6cece5c7ddebdd10abf3c4a2e800d76e859ee7b918e34958583c`.
The [complete pinned contract](ci-engineering-closure-001/actor-custody-replay-contract.json),
[acquisition and reducer pins](ci-engineering-closure-001/actor-custody-replay-pin.json),
[authenticated acquisition record](ci-engineering-closure-001/actor-custody-replay-acquisition.json),
[verifier receipt](ci-engineering-closure-001/actor-custody-replay-result.json) and
[publication evidence inventory](ci-engineering-closure-001/publication-evidence.json)
are retained together.

The isolated replay store recovered 57 initially absent blobs by their exact
Git object identities. It derived **105 native source inputs and 1,283 build
inputs** from the original source's selectors and compared them with the retained
ledgers; actual file hashes were verified from that source's Git blobs. Both
real candidate binaries and their local LFS object bytes were rehashed. The
original source's Actor semantic reducers also passed against the unchanged
42/42/18 report sets, including original assertions, readbacks and framebuffer
receipts. All nine imported reducer helpers and the execution policy matched
their original source hashes.

This is a verifier replay of the existing `af13c6a…` campaign and its
`47e87cb…` publication child. It launches no product process, changes no Actor
branch, establishes no new remote LFS availability and does not qualify the
closure candidate as new product source. The helper's own result remains
`qualification_semantics_verified: false`; the separate original-owner reducer
replay is recorded explicitly in the pin file.

## Trust boundary and contract

The CLI requires `--contract-sha256`, supplied by an independently retained
acquisition/review record. Generating this hash from an untrusted candidate's own
manifest at verification time does **not** authenticate evidence. A complete
fabricated report and fabricated logs can be internally consistent. They cannot
match independently pinned original artifact/report hashes without changing
that external authority.

The trusted producer or reviewer must obtain the original artifact ID, digest,
run, attempt, source and successful producer-job identity through approved
authenticated GitHub capabilities. Artifact names alone are not authority. An
attempt inferred from a name must agree with the actual job attempt. Preserve
original failed attempts. The caller must also derive the complete input and
case inventory from the exact qualified source and run the existing semantic
reducers before creating the contract.

The contract JSON has these mandatory fields:

| Field | Meaning and required provenance |
|---|---|
| `schema_version: 1`, `kind: publication-custody-v1` | Explicit helper schema; unknown schema is refused |
| `source_commit`, `source_tree`, `branch`, `run_id`, `attempt` | Exact original tested commit/tree and dedicated branch; positive decimal run/attempt strings |
| `slots.linux`, `slots.windows` | Distinct existing binary and provenance paths, exact binary SHA-256/size, exact provenance SHA-256, complete canonical-LF `source_inputs` and `build_inputs`, exact compiler text and dependency identities |
| `artifacts` | Map of local ZIP path, API/acquisition SHA-256/size, artifact and successful producer job IDs, original run/attempt/branch/source/tree |
| `reports` | Exactly one Linux, Windows and installed-Windows report; owning artifact key, exact member path and independently pinned report SHA-256, platform and complete `cases` map |
| `reports[].cases` | Each required case's exact command array and boolean `requires_display`, derived from the qualified source and executed launch context |

The original Actor reports do not contain top-level run or attempt fields.
Their run/attempt custody comes from the authenticated **artifact acquisition**,
the externally pinned ZIP/member bytes and the exact provenance report link.
The helper does not invent missing report fields or treat a candidate-supplied
run label as independent authentication.

The report/process format is the existing monitor-compatible shape:
`candidate`, `completed`, `status`, `platform`, `executed_cases`, `results`, and
`installed_package`. Each process must be an expected unique case, with its
exact command/display mode, positive PID, integer zero return code, natural
completion, no skip/diagnostic/timeout error, and a retained nonempty original
log whose SHA-256 agrees. The stage provenance must point to the verified report
through `qualification.report_sha256`; extracted Windows uses
`installed_package_qualification.gameplay_report_sha256`.

This verifies process/report/log **identity**, not every case's scientific
assertions, screenshot readbacks or package-module semantics. Those remain the
programme owner's mandatory independent reducer. A contract cannot grant their
exemption. The [synthetic fixture builder](../../tools/ci/test_publication_custody.py)
shows the complete executable schema; its generated data is explicitly not
product execution evidence.

## Stage inspection and immutable replay

After the existing owner publisher has validated its real campaign and staged
the permitted runtime/provenance files, a prospective integration may run:

```bash
python tools/ci/publication_custody.py \
  --root /path/to/exact-source-checkout \
  --contract /path/to/independently-reviewed-custody.json \
  --contract-sha256 EXTERNALLY_PINNED_SHA256 \
  --artifacts /path/to/immutable-downloaded-artifacts \
  --remote origin
```

The checker requires the checkout's exact source HEAD and dedicated branch,
reads the actual remote branch before and after inspection, and snapshots the
full Git index. Both provenance files must change. Each binary pointer may be
changed or byte-identical; all four combinations are admitted only when actual
binary bytes, pointer SHA-256/size, provenance, local LFS object bytes and the
qualified contract agree. Additional paths, deletions, symlinks, executable
pointer/provenance files, unresolved index entries, unstaged tracked changes and
index movement during inspection are refused. Source/build ledgers are hashed
from real committed regular Git blobs, using the repository's canonical-LF
convention. Compiler and dependency identities must agree exactly.

The checker does not modify the index or write a tree. Even its final observed
lease is not a transactional guarantee. The existing publisher must still use
an atomic exact expected-parent push, verify the single-parent publication
child, and verify successful LFS upload/remote availability. Local LFS presence
proves local storage only. Do not substitute it for remote object custody.
The configured remote name is also a caller trust boundary: the operator or
authenticated acquisition step must establish that `origin` is the intended
repository. The helper checks that remote's exact branch value; it does not
authenticate repository ownership merely from the name `origin`.

To replay a retained publication child, add
`--replay-child FULL_PUBLICATION_COMMIT`. The helper requires exactly one parent
equal to the original qualified source and only the allowed runtime/provenance
delta. Materialized binaries/local LFS objects must match that immutable child.
The result is labelled `immutable-replay`; it grants no qualification to a new
product source, another campaign, another branch or the verifier's own commit.
It does not need the historical branch still to point at its old parent.

ZIP input is captured once into a bounded buffer; the trusted digest, byte size
and decoded members all refer to those same bytes. A later filesystem path
replacement cannot substitute evidence after the archive pin check.
ZIP reads are bounded before decompression: 256 MiB per archive, 256 MiB total
expanded members per archive, 64 MiB per member and 4,096 members. Duplicated
members, traversal paths and archive symlinks are refused. These limits are for
receipt artifacts, not large evaluator ZIPs. A future genuine need for larger
receipt artifacts requires a reviewed bounded change, not silently skipped data.

## Migration contract and remaining gates

Integration remains **HOLD** while another team owns its active publisher.
The following work belongs to that owner, after its current campaign ends or an
explicit handoff establishes source ownership:

1. Keep all existing native, target-platform graphical, original process/log,
   installed-package and independent semantic reducers.
2. Acquire immutable artifact ZIPs through authenticated source/run/attempt/job
   metadata; retain the independent hashes. Derive complete source/build/case
   inventories and compiler/dependency identities from the qualified source.
3. Add the helper as an extra stage check. Preserve existing early source
   admission, dedicated branch lease and publication-only child checks.
4. Recheck the exact remote parent at publication, use the existing atomic
   expected-parent update, and verify actual LFS upload/storage. Do not create a
   second privileged workflow or reuse another programme's credentials.
5. Run the owner's minimum mandatory source-matched Linux, Windows, graphical
   and extracted-package suite for the changed publisher. A replay of an old
   artifact proves the verifier's handling of that artifact only.
6. Keep the candidate Draft/HOLD for independent review and the owner's separate
   acceptance/Ready/merge decisions. No default or provider changes follow.

Removing an unintegrated helper has no production effect. After a future
integration, rollback removes only the extra helper invocation and preserves
the previous strict owner validator and original failure records. An old fixed
four-changed-path assertion must not be presented as accepting byte-identical
libraries; it should fail explicitly until the owner chooses a qualified repair.

## Local qualification

```bash
python -m unittest discover -s tools/ci -p test_publication_custody.py -v
python tools/ci/check_ci_provider_policy.py
git diff --check
```

The suite creates temporary real Git/LFS repositories, a local bare Git remote,
synthetic bytes and original ZIPs. It exercises all four actual pointer-change
combinations and negative controls for altered bytes, wrong pointers, missing or
corrupt local objects, mandatory provenance, stale source/tree/inputs/compiler/
dependencies, wrong run/attempt/producer, missing/substituted reports/logs,
skipped/incomplete processes, source/installed identity, rogue paths, unsafe
archives, lease movement, index movement, extra child commits and merge parents.
The test remote is local and no hosted jobs run. Full resulting-source CI
required by repository policy is separate; local tests are not a Ready gate.

The complete local suite passed **38/38 tests in 103.081 seconds** before the
final archive-path race repair described below. Independent
review found and reproduced an index-movement race; lead review found a
same-commit local branch-switch race. Both were repaired with final identity
checks and actual-Git regressions. A prior independent complete run passed 36
tests in 59.468 seconds; independent review then passed all three focused
branch-switch, malformed-report and index-movement regressions in 2.806 seconds.
The review keeps these exact scopes separate from the complete 38-test run.

A later independent review reproduced substitution of a ZIP pathname after its
hash had been checked but before its members were decoded. The helper now hashes
and decodes one captured byte buffer. A real filesystem replacement regression
failed against the previous implementation and passes after the repair. The
39-test inventory includes that regression; five focused archive-integrity,
budget and path tests passed in 2.714 seconds after the repair. This final delta
did not require another product execution or broad qualification campaign.
