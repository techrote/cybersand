---
title: Runtime publication custody preflight
status: Current
document-kind: runbook
scope: Accepted read-only custody verifier and owner-controlled publisher migration; trusted artifact contracts and branch leases grant no publication or semantic acceptance
canonical-for: [publication-custody-preflight]
last-reviewed: 2026-11-25
related-documents: [github-development-and-release.md, ci-execution-and-performance.md, ci-engineering-closure-001/FINAL-DECISION-PACKET.md]
---

# Runtime publication custody preflight

## Purpose and adoption boundary

[publication_custody.py](../../tools/ci/publication_custody.py) checks a prepared
two-platform Git/LFS publication stage, or replays the custody of an immutable
publication child. It reads Git, local binary/LFS bytes and retained artifact
archives. Stage inspection additionally reads the configured remote branch to
check its lease; immutable replay needs the original Git, LFS and artifact inputs
available. It does not stage, commit, upload, push, cancel, dispatch, promote or
merge anything. Its success means **custody verified within the supplied trusted
contract**. It always emits `publication_authorized: false`,
`qualification_semantics_verified: false` and
`remote_lfs_storage_verified: false`.

The standalone helper entered accepted main through [the CI closure merge](https://github.com/techrote/cybersand/commit/5e29b111be6202a76c0042976f74de98bd8ead78)
on 25 November 2026. That merge did not add a call to it in an active programme
publisher. Existing source, execution, graphical, installed-package and human
acceptance gates remain in force. An owning programme must qualify any future
publisher integration; the helper does not replace its semantic reducer.

## Recovered publication evidence

<a id="actual-immutable-verifier-replay-on-24-november"></a>

The [immutable 24 November recovery record](https://github.com/techrote/cybersand/blob/5e29b111be6202a76c0042976f74de98bd8ead78/docs/operations/publication-custody.md#recovered-publication-evidence)
retains the failed Actor publication, isolated recovery, later #762 campaign,
artifact digests, process counts and exact replay inputs. Its complete original
bytes remain in accepted Git history. The [dated closure packet](ci-engineering-closure-001/FINAL-DECISION-PACKET.md)
links the associated evidence. Those records qualify only their named historical
sources and artifacts. They do not attest this checkout's runtime, a new package,
remote LFS availability or physical owner acceptance.

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

Acceptance of the standalone helper does not integrate it into another
programme's publisher. The following work belongs to that owner, after its current
campaign ends or an explicit handoff establishes source ownership:

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

The [original local qualification and repaired race evidence](https://github.com/techrote/cybersand/blob/5e29b111be6202a76c0042976f74de98bd8ead78/docs/operations/publication-custody.md#local-qualification)
retain their exact test counts, timings and source scope. Run the commands above
against the intended integration source; historical unit results and immutable
verifier replay do not establish new product execution or publisher acceptance.
