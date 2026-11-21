# CI-OPT-002 Stage A — independently audited paired admission result

## Finding and scope

The first optimisation moves the existing Documentation and native provenance
admission checks before expensive material/LCB compilation. On the actual paired
hosted stale-source proof, time from the unchanged postinventory boundary to the
same genuine canonical refusal fell from **593.895s
to 2.767s**: **591.128s
(99.53%) less time to this rejection**.

This is a measured improvement in negative-admission turnaround. It is not a
claim that successful routine CI, Native, GDExtension or full release qualification
is that much faster. A successful candidate continues through every original
Documentation step. The latest accepted-main routine baseline remains the
observed **30m37s elapsed / 298.70 unweighted runner-minutes** across seven
workflows, with Native worldgen determining the slowest path; see
[the baseline report](baseline-report.md).

Both proof jobs succeeded because they proved the expected refusal. The actual
under-test canonical checker **failed with exit 1 in both arms** and retained
`failed-as-expected-stale-source`. Neither proof claims application qualification.
The independent, complete positive Documentation run is reported separately below.

## Paired hosted measurements

Proof run [44946486076](https://github.com/techrote/cybersand/actions/runs/44946486076), attempt 1, contains exactly two executed
jobs with no skipped, failed, cancelled, or omitted worker. Both used the same
immutable proof commit, separate GitHub-hosted Ubuntu 24.04 workers, and the same
checkout/LFS, parser installation and control sequence. The original-order arm
actually ran its original expensive predecessors; the reordered arm reached
the original failing check before those commands became applicable.

| Metric | Original order | Reordered admission |
| --- | ---: | ---: |
| Postinventory interval to genuine refusal | 593.895 s | 2.767 s |
| Job wall time: actual start to completion | 642.000 s | 50.000 s |
| Event to job completion | 645.000 s | 53.000 s |
| Event to actual canonical refusal | 639.672 s | 47.445 s |
| Initial job queue: created to started | 3.000 s | 3.000 s |
| Unweighted runner-minutes | 10.700 min | 0.833 min |

The paired campaign itself cost **11.533
unweighted runner-minutes** and completed in **10m45.000s**
from event creation. Its two arms are measurement work, not redundant routine
jobs introduced by the optimisation. Job times include setup, checkout/LFS,
controls, artifact publication and post-job cleanup. Runner-minutes are summed
job start-to-completion intervals; they are not billed platform-weighted minutes.
Initial queue is recorded separately. No `updated_at` timestamp is used as an
execution endpoint.

| Original measured command | Before seconds / original exit | After seconds / original exit |
| --- | ---: | --- |
| Check LCB capability matrix is source-derived | 0.115 / exit 0 | Not reached after the earlier refusal |
| Check LCB policy wire/hash contract vectors | 0.365 / exit 0 | Not reached after the earlier refusal |
| Check native LCB setup and run receipt canonical vectors | 0.165 / exit 0 | Not reached after the earlier refusal |
| Check material catalogue shadow compatibility | 534.923 / exit 0 | Not reached after the earlier refusal |
| Check LCB scenario definitions and registry are source-derived | 55.036 / exit 0 | Not reached after the earlier refusal |
| Validate current documentation | 1.367 / exit 0 | 1.198 / exit 0 |
| Validate dependency pins and published runtime provenance | 1.919 / exit 1 | 1.568 / exit 1 |

The primary interval is measured with the monotonic clock and includes small
harness bookkeeping between the original command blocks. It starts immediately
after the original inventory boundary and ends when the canonical stale-source
check actually exits. Command sums and the complete API step inventory remain
available in `stage-a-paired-summary.json`.

## Common controls, setup and fixed overhead

Each arm first proves that the clean source passes the existing
`check_repository.py --require-materialized` command. It then makes and restores
four actual adverse mutations: a changed manifested native input, a missing
Linux runtime, corrupted Linux runtime bytes, and an invalid documentation link.
Every mutation produces its specific canonical nonzero refusal. A second clean
check passes after these controls, and a final clean check passes after the
timed stale-source mutation is restored byte-for-byte.

All three positive checks in each arm report all **18** declared runtime files
materialized, no unmaterialized files and no admission errors. This is custody
and source identity evidence, not execution of every platform's runtime tests.
These checks are outside the headline timing interval and identically present
in both arms.

| Harness component, seconds | Before | After |
| --- | ---: | ---: |
| Three positive canonical admission checks | 5.756 | 4.703 |
| Four real adverse-control checks | 7.223 | 5.972 |
| All harness time outside the measured interval | 13.658 | 11.240 |
| Complete proof harness | 607.554 | 14.007 |

| Hosted job component, API seconds | Before | After |
| --- | ---: | ---: |
| Set up job | 0 | 1 |
| Check out the original pinned companion documentation | 2 | 1 |
| Check out the same immutable proof source in both arms | 24 | 25 |
| Install the existing hash-pinned workflow parser | 3 | 3 |
| Run original commands and require genuine canonical refusal | 608 | 14 |
| Retain complete or partial proof evidence | 1 | 1 |

The common controls warm filesystem reads before either interval. No compiler
cache is restored by the proof workflow. Separate hosted workers can differ in
CPU speed, storage and queue behavior; one pair does not establish a distribution
or percentile. API step timestamps have one-second resolution. Full-job
reductions are descriptive observations for this pair, while the command ledger
identifies which expensive predecessors the earlier admission avoids.

## Source, runtime and command equivalence

- Accepted-main baseline: `0f0161af337d6d0cee8fa961a9667aff570a75b0`.
- Merge candidate, PR [#714](https://github.com/techrote/cybersand/pull/714): `68e0261466fc275a095360c63ed6f67311ecc0f6`.
- Proof-only head: `726e442334cd73db87dac69ac6510b3c6c57f159`; tree `dae3f3451301341b2634f8ac50b3d0063e770c00`.
- Exact 22-step definition inventory SHA-256: `3da6cf6de71eb606d493851a44338abcab189c02791d8dab9c1e3762d6849ff0`.
- Proof harness SHA-256: `cf4a87c0a72cdd6093fd9db0e5b76a4f46a30ed6b2dd6ea03e0a316ae19d8305`.

Independent verification compared the complete original workflow/job metadata
and every step definition, including commands, action pins, conditions and
timeouts. They match exactly by step name. The order of all steps except the
two moved admission checks is unchanged. Each timed shell block in both artifacts
equals the corresponding block in its immutable Git workflow revision. The
original non-Draft provenance condition is retained; this proof runs a dedicated
push event on which that condition is true.

Both artifact source/runtime ledgers match byte-for-byte. All **105 unique
manifested native source inputs** were independently hashed from Git at baseline,
candidate and proof commits and match their published manifests. Both platform
manifest files are unchanged, and both materialized native runtime hashes match
their committed Git LFS object identities at all three revisions.

| Native runtime | Manifested inputs | Materialized runtime SHA-256 |
| --- | ---: | --- |
| Windows x86_64 | 105 | `668f2dd094fca611a97c2b6aa38c4cd072179fe9cf591e53578ef57c7db1625e` |
| Linux x86_64 | 105 | `a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7` |

Baseline-to-candidate changes are confined to
`.github/workflows/documentation.yml` and
`docs/operations/ci-execution-and-performance.md`. Candidate-to-proof changes add
only the dedicated proof workflow and its CI harness. No production source or
native binary changes are present. The proof branch is separate from the merge
candidate; its deliberately stale input exists only during reversible job-local
controls and is restored exactly.

## Complete positive candidate qualification

The candidate's ordinary
[Documentation run 44945708005](https://github.com/techrote/cybersand/actions/runs/44945708005)
passed at exact head `68e0261466fc275a095360c63ed6f67311ecc0f6`. Its one complete job executed every
reported step successfully, including material catalogue, LCB, historical
integrity, failure contracts, retrieval, Git LFS and evidence retention.

The checkout log identifies the executed pull-request merge commit as
`6263af276946aa3f08b7ae5436c45b360aa1e10e` with accepted main and the candidate as
its two parents. Its tree `1232a6e825561ce8b5cd125e1bad7fa6aa7e1590` is identical to the
candidate tree; the API head and actual checked-out source identity are both
retained explicitly.

- Job wall time: **7m05.000s**.
- Event to completion: **7m08.000s**.
- Initial queue: **3s**.
- Unweighted runner-minutes: **7.083**.
- Current documentation admission completed **35s** after event creation.
- Published runtime provenance admission completed **37s** after event creation.

Its full green-run duration is not a controlled speed comparison with the earlier
main Documentation run. Compiler and host variability can change total duration,
and reordering does not remove those commands from successful execution. This
positive result establishes complete candidate qualification, while the paired
negative proof establishes the measured earlier-refusal benefit.

## Retained evidence and reproduction

- **After artifact:** [14724086691](https://github.com/techrote/cybersand/actions/runs/44946486076/artifacts/14724086691); ZIP SHA-256 `6650b7ad4af881089210bd243c9f7d8afc90771f052fbdb8b793ff9c6fc649c1`; 12 retained file hashes verified. Report SHA-256 `b9e3df1badb6a75524830c7f5a5698fcdae2926b3d25b07cdfb6e0664adecc20`.
- **Before artifact:** [14724023560](https://github.com/techrote/cybersand/actions/runs/44946486076/artifacts/14724023560); ZIP SHA-256 `5ebc389304dae798583aa33a78cddba5385c570c853e31be1e538fd968ddfcc0`; 17 retained file hashes verified. Report SHA-256 `e50242921804a064ddf52eb9da50308587ad898461c00877a6e3ac69abd0daa3`.

The downloaded ZIP hashes match the GitHub artifact digests. The independent
audit verified every ZIP entry against its retained extraction, every artifact
file ledger and command-log hash, command completion/exit status, monotonic
duration, source/run/attempt identity, the exact mutation/restoration bytes,
canonical positive/adverse outputs, runtime LFS identities, and the full
single-attempt two-job inventory. Both raw GitHub job/step pages, artifact metadata
and positive candidate run metadata are retained with hashes in the machine report.

Reproduce the independent validation from the repository root with:

```bash
python3 build/ci-opt-002/audit/audit_stage_a_pair.py
python3 build/ci-opt-002/audit/write_stage_a_report.py
```

The complete machine record is `stage-a-paired-summary.json`; raw downloaded
artifacts are `stage-a-proof-before.zip` and `stage-a-proof-after.zip`. These
audit helpers and evidence remain under ignored build output and do not alter
production code, workflow behavior or source branches.
