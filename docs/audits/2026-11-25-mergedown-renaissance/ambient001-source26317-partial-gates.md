# Independent current-source partial qualification and attempt custody

Specialist C, 26 November 2026. Candidate `26317ada6a1f40637e96d732ec28f55c70cd53a2`
has tree `984c94a6e312261120dffb4ad3625a6030d2f359`. The actual application
checkout is synthetic merge `a83b44dee96b6db382e8cd9def727c963a979eaf`, with
accepted main `c8421a81` and candidate `26317ada` as parents and the same tree.
**Merge remains HOLD until all remaining resulting-source gates pass.**

## Verified completed gates

| Scope | Original execution | Independent result |
| --- | --- | --- |
| GDE Linux | [45727973062 attempt 1](https://github.com/techrote/cybersand/actions/runs/45727973062/attempts/1), reducer job 139609596970 | PASS: 354 unique applicable cases, all 25 shards and 41 source inputs; exact synthetic source and candidate tree. |
| Art Linux | [45727972762 attempt 1](https://github.com/techrote/cybersand/actions/runs/45727972762/attempts/1), job 139602549257 | PASS: 9 test cases and 569 assertions. The shell repeats two terminal receipts; duplicate rows are counted once. |
| Art Windows | [45727972762 attempt 2](https://github.com/techrote/cybersand/actions/runs/45727972762/attempts/2), job 139606815128 | PASS: 7 test cases and 299 assertions, fresh Windows execution. |
| Palette | [45727972728 attempt 1](https://github.com/techrote/cybersand/actions/runs/45727972728/attempts/1), reducer job 139604558114 | PASS under the unchanged v3 predicate: all 6 cohorts and 19 process cases. |

C downloaded original Linux coverage artifact `15075308967`, verified its
83,122-byte ZIP against GitHub's SHA-256
`e46ecfc5caa92ff39eebb86b75202f4800616d339e0e60b3d23b75116d4cdeaf`, checked
archive CRC and all 46 member hashes, then read the complete reducer and its
15 retained play receipts. The receipts bind to exact source `a83b44de` and
retain their lack of physical-device or graphical qualification. This readback
does not claim an independent download of every original shard archive.

Palette retains the original v2 finished-image diagnostic as failed: 11 pixels
exceed its original threshold at blends 0.5 and 1.0. That diagnostic is expressly
outside the existing v3 acceptance predicate; no threshold or oracle changed
during this recovery. The original producer payload had already been separately
verified against all four exact committed runtime objects.

## Carried job records are not fresh executions

The latest Art attempt-2 API inventory gives Linux a new job ID
`139606817778` and `run_attempt: 2`, while carrying its original execution
timestamps, `00:20:04`–`00:21:06 UTC`. C fetched both that record's log and the
original attempt-1 job `139602549257`: both contain exactly 53,469 bytes and
have SHA-256 `f388d2c679df9b79e458f0fe4f653c6b6c68644fabd344e6559348edab1d17aa`.
They describe one Linux execution.

The actual fresh Windows job ran `00:30:40`–`00:31:50 UTC`; its 110,014-byte
decoded log has SHA-256
`c86c2577de55c57bf93990a6b77a2c56b15138d9abc7dcba4ec4b66fb125add2`.
The correct acceptance description is **original Linux execution attempt 1 /
fresh Windows execution attempt 2**, even though GitHub's latest API inventory
labels both records with attempt 2. Apply this same provenance check to the
admitted GDE Windows producer recovery. New job IDs alone do not establish new
test execution.

## Preserved failures and remaining gates

Original Art Windows job `139602549515` remains failed before Godot because
Git LFS acquisition timed out. Original GDE attempt 1 remains failed: 30 jobs
succeeded, two scoped sentinel/stress jobs skipped, the Windows shard matrix
was blocked, and the Windows producer plus strict coverage reducer failed.
The producer's timeout followed by HTTP 503 and absence of a usable payload
manifest are preserved in the narrow-retry review; Linux success does not turn
that original attempt into a successful campaign.

The lead registered and initiated the admitted complete Windows producer and
descendant recovery only after the original GDE run became terminal. Its fresh
runtime artifacts, all Windows shards and strict reducer must qualify together
at their actual new attempt. Remaining Native families and aggregate admission
also require terminal review. No source, test, runtime, watchdog, experimental
default or owner acceptance state was changed by C.

The companion JSON preserves exact reports, job identities and original log
hashes. Small original logs/API snapshots and the original Linux coverage ZIP
are committed under `raw/ambient001-source26317/`; all compressed originals
have both compressed and decoded identities recorded.
