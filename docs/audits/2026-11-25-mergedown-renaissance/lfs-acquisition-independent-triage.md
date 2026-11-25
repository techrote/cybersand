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

This register makes no GDE recovery claim. B owns the bounded acquisition repair;
the current/final source needs its own independently inspected campaign. All
original decoded failed logs and the successful Palette reducer log are retained
with SHA-256 receipts in the companion JSON. Newline normalization to LF is
declared for these decoded text copies; GitHub retains the original attempts.
