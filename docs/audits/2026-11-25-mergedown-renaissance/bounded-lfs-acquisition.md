# Bounded LFS acquisition repair

Base: AMBIENT resulting source
`0c1152c21427125066df931cf06a53b7dda0075d`, tree
`114764b42f40bf7edd078171a85e5c043c71b137`.
This repair changes dependency acquisition and its custody only. No native,
Godot gameplay, runtime pointer, test oracle, case timeout, shard policy or
concurrency setting changes.

## Observed failure and decision

Original Palette run `45715343561`, attempt 1, failed Linux Main-cache
materialization before Godot. The Git LFS batch server returned its explicit
service-timeout message after 11.49 seconds; five other cohorts passed and the
reducer correctly refused incomplete coverage. Its complete second attempt
passed. The original failure remains a failure.

The same server response prevented five Windows shards of AMBIENT GDExtension
run `45715343854`, attempt 1, and two Windows shards of accepted Goblin main
run `45714897904`, attempt 1. These are acquisition failures before engine
execution; absent shard reports and reducer failures are downstream evidence,
not newly discovered gameplay assertions. Specialist C independently retained
all original logs and their hashes in the mergedown failure ledger.

Repeated new full platform campaigns would still encounter this unhandled
service condition. The selected repair retries that exact condition within the
existing dependency allowance. Permanent errors remain immediate failures.
Original attempts are preserved and the repaired source requires its own full
resulting-source qualification before merge.

## Acquisition contract

The small shared `tools/ci/materialize_lfs.py` helper is used by the existing
GDExtension Linux/Windows materialization steps and Palette preparation.

| Boundary | Preserved or added behavior |
| --- | --- |
| Source authority | Exact caller-provided Git commit, matching checkout before and after acquisition; canonical committed LFS pointer SHA-256 and size for each literal path. |
| Retry admission | Exit 2 with the observed Git LFS batch service-timeout message; authentication, permanent, mixed and unknown failures are not retried. |
| Attempt limit | At most three attempts, with two- and four-second backoff inside one shared monotonic allowance. |
| Windows GDE allowance | Existing 600-second dependency step, including metadata, setup, all attempts, backoff, exact-byte readback and cleanup reserve. |
| Linux GDE and Palette allowance | Existing policy's 1,200-second dependency allowance; no new parent budget or execution watchdog. |
| Cleanup | Reuse the established owned-process-tree cleanup. The current ten-second termination allowance is reserved inside the acquisition budget; a policy too small to contain that helper is refused. |
| Evidence | Full per-command stdout/stderr files, original exit/timing/timeout/join status, log SHA-256, original failed attempts, exact source and pointer/actual-byte receipt. Existing `always()` artifacts retain these paths even if acquisition fails. |
| Final admission | Materialized SHA-256 and size must equal the committed pointer. No alternative runtime, source, cache selection or success fallback is supplied. |

The Windows execution input inventory now binds the executable acquisition
helper. Its cleanup dependency was already bound. Palette explicitly binds both
through its source scopes and required-apparatus list. Existing source-built
native candidate, retained provenance, Rapier and coverage checks still execute.

## Local verification and scope

Fourteen focused adversarial tests pass. They exercise fail-once service
recovery, permanent/auth/unknown and mixed refusal, all three failed attempts,
shared-deadline exhaustion, timeout refusal, wrong bytes/size, source movement,
unsafe path inventory and preservation of earlier evidence. A genuine child
process fixture fails once and then writes the exact source-bound bytes; a
separate actually hung process and its owned descendant are stopped and joined.
The fake acquisition fixture is not described as a live LFS or native execution.

Existing affected local checks also pass: Palette qualification (35), Palette
checkout custody (14), Windows regression contracts (22), and Windows complete
shard readback (47). CI provider policy, actionlint 1.7.12 and the 97-workflow
scheduling inventory pass. These are focused source/contract checks. No hosted
campaign pass or physical acceptance follows from this local record.

The lead owns remote publication, the full repaired-source campaign and the
subsequent mainline merge decision. The mainline Windows evaluator may call the
same reviewed helper with a 600-second allowance inside its existing setup
budget, without changing its gameplay or package-proof watchdogs.
