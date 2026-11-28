# Independent triage of resulting-source LFS acquisition failures

Specialist C read the actual failed job logs in both the accepted Goblin 001
post-merge campaign and the AMBIENT 001 candidate campaign. The listed Windows
shards fail while materializing the pinned Rapier runtime: the Git LFS batch
service reports that it could not respond in time and exits with code 2.
Godot and the regression runner have not executed. Missing test-output uploads
are consequences, not application failures or test passes.

| Source and campaign | Failed original jobs | Independent classification |
| --- | --- | --- |
| Accepted main `c8421a81b8f7f61516ed055f3200b49aee57bd65`; push GDE run `45714897904`, attempt 1 | Windows shard 6: `139560378897`; shard 8: `139560379052` | Dependency-service acquisition failure before Godot |
| Same accepted-main campaign | Windows reducer `139565758264` | Correctly refuses 21 of 23 required original reports; failed artifact `15069788557` retained |
| Candidate `0c1152c21427125066df931cf06a53b7dda0075d`; PR GDE run `45715343854`, attempt 1 | Windows shards 0, 8, 10, 11, 22: `139563141658`, `139563141675`, `139563141620`, `139563141698`, `139563143540` | Same observed pre-Godot LFS batch-service failure |
| Same candidate; Palette run `45715343561`, attempt 1 | Linux main-cache `139560080793` | LFS acquisition failed after 11.495 seconds; other five cohorts passed, incomplete reduction correctly failed |

The complete pre-merge Goblin 001 Ready campaign remains independently qualified
at the same product tree as accepted `c8421a81`. That earlier result does not turn
the post-merge infrastructure failures into passes. Recovery must retain the
exact source/runtime and applicable artifact-attempt contracts.

## Distinct successful Palette recovery

The lead reran the Palette plan and all dependents, preserving one complete
attempt as required by its reducer. C independently read all eight attempt-2
jobs and reducer `139565783138`: **six cohorts / nineteen process cases passed**
at exact source `0c1152c2`. The reducer artifact is `15070122562`. Its v3
bounded-semantics acceptance passes; its retained v2 finished-image diagnostic
still reports its original cross-backend differences and is explicitly not
the v3 acceptance predicate. No comparison threshold or source changed in this
retry.

The completed AMBIENT GDE attempt has 58 jobs: 50 successful, two scoped skips,
the five failed LFS-dependent Windows shards and their failed reducer
`139568180496`. That reducer correctly refuses 19 of 24 reports; original failed
artifact `15070147945` remains. Linux reducer `139569066199` independently passes
all 354 cases across 25 shards, verifies 41 source inputs and binds synthetic
merge `b36cb92d0ab908a9303cb3f21f52e88412970f73` to exact candidate tree
`114764b42f40bf7edd078171a85e5c043c71b137`. Its artifact is `15070996178`.

This register makes no complete GDE recovery claim. B owns the bounded
acquisition repair; the current/final source needs its own independently
inspected campaign. All
original decoded failed logs and the successful Palette reducer log are retained
with SHA-256 receipts in the companion JSON. Newline normalization to LF is
declared for these decoded text copies; GitHub retains the original attempts.

## Repaired-source attempt 2: dependency failures remain, HOLD preserved

At exact candidate `120f0d0825e1fcdf9ea1ea9d8d50a0d5b32735d6`, the complete
GDE recovery attempt 2 (`45719650698`) finished with 50 successful jobs, two
scoped skips and six failures. Five Windows shards (4, 7, 17, 18, 19) failed
while acquiring Rapier before Godot. Windows reducer `139596780410` correctly
refused 19 of 24 required reports; original artifact `15073619935` remains
failed. Linux reducer `139598038042` independently passed **354 cases across
25 shards**, checked 41 source inputs and retained artifact `15075295117`.
Ready-scope and unrequested physical stress remain explicitly skipped.

C checked the actual synthetic merge `247d290a5bcbb6cc72c93b66e8b65530860e879a`:
its parents are accepted `c8421a81` and candidate `120f0d08`, and its tree
`c905324fd96214e88a1a7d3327b4cd7cdff693db` exactly matches the candidate.
Native run `45719650512` passed all eight applicable jobs, with its Ready-scope
sentinel skipped. Palette run `45719650316` attempt 2 failed in its Linux
visual acquisition cohort (`139590124790`); the readback (`139591675128`)
correctly rejected the missing cohort. Six of eight jobs succeeded.

C downloaded and hash-verified original Windows shard 17/18/19 artifacts
`15072914857`, `15074656029` and `15074241972`. Every retained command log
matched its receipt SHA-256 and length. Each contains three joined Git LFS
pulls returning the observed batch-service timeout, bounded to 42.375,
41.359 and 41.453 seconds respectively within the unchanged 600-second
allowance. There were no surviving commands or application executions to
relabel. The reducer ZIP also matched its published SHA-256. B's separate
original receipt for shard 7 (`15073624078`) records two batch timeouts and
then HTTP 503; the helper correctly stopped at that non-admitted error.

**Merge disposition: HOLD.** The completed Linux and Native results cannot
replace missing Windows or graphical-cohort evidence. Parent and B are
preparing a separately reviewed same-attempt producer/consumer dependency
transport to reduce repeated acquisition. This record neither approves that
new source nor authorizes a reduced test inventory. C performed no rerun or
source mutation while preserving these original failures.
