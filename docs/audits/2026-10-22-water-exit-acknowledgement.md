---
title: Water exit acknowledgement correction after GEN-007 acceptance
status: Current
document-kind: audit
scope: Preserved post-merge Windows failure, desktop Water exit receipt correction and separately scoped validation
canonical-for: []
last-reviewed: 2026-10-22
related-documents: [../operations/experiment-tower.md, ../reference/interfaces-and-message-contracts.md, ../architecture/data-ownership-and-lifetimes.md, ../operations/testing-validation-and-replay.md, 2026-10-21-gen007-workbench-qualification.md]
---

# Water exit acknowledgement correction after GEN-007 acceptance

## Accepted tree and subsequent failure

GEN-007 [PR #198](https://github.com/techrote/cybersand/pull/198) passed its
applicable pre-merge Documentation/provenance, Native, GDExtension/Godot and
Water apparatus gates at head `19662abbddf1f7d96461e8f783b080cb7e5f7d48`.
The [acceptance receipt](https://github.com/techrote/cybersand/pull/198#issuecomment-6335086612)
retains those results. Merge `90a5bfc9a0664ca6eb78c00a18619aa4409619b1`
has the identical tree `77be051d99d29521369ac552de01527aad3ff735`.
The pre-merge Windows receipt from
[run 39735331292](https://github.com/techrote/cybersand/actions/runs/39735331292)
records all **116/116** applicable cases passing on GitHub's temporary merge
commit `d64d646f6f5afcd0417dad32c1bf33698e8e4dd6`, also with that same tree.

The subsequent [post-merge Godot run 39739371184](https://github.com/techrote/cybersand/actions/runs/39739371184)
exposed a scheduling-dependent desktop control defect in its actual
[Windows execution job 119692601708](https://github.com/techrote/cybersand/actions/runs/39739371184/job/119692601708).
All 116 applicable cases executed; **115 passed and one failed**. The failed
`test_water_feel_controller` returned 3 after 19.238 seconds, within its
180-second timeout, and reported these three cascading failures:

- The ordinary Tower profile reset retained blind-session state.
- A second desktop blind run could not start.
- The second blind candidate was not acknowledged.

This failed run has no source drift and uses the same final tree. It remains
a failure; the earlier green run does not erase it. The
[supplemental PR receipt](https://github.com/techrote/cybersand/pull/198#issuecomment-6347425055)
discloses this post-merge finding separately from the original qualification.

The retained [failure readback](water-exit-2026-10-22/failure-readback.json)
was extracted from artifact **12409266418**. Archive SHA-256 is
`3d442809ba7618e10830a56b9f678a14b63a21b72328db2b88731384317a8b6d`;
the execution-report SHA-256 is
`a3c3afe83b0b11275e201fb649fd676a0ebbbfd83753d46f8cc812c8a08ffdc7`;
the failing log SHA-256 is
`61be8a547f7bf775b118afb668773627c33a05d02d9724475b93f6cb7355a090`.
The archive was read and hashed independently. Raw logs and binary archives
are not added to the source repository.

The failed execution used Windows Server 2022, Python 3.12.10 and Godot
`4.7.stable.official.5b4e0cb0f`. Its 3,945,472-byte Windows CyberSand runtime
has SHA-256 `e6d9ec7d0847287c4c6b1acaffd52dc2807fe43e9dccfc36123ffa117fb6045f`,
published from frozen native source `2f7f65bf6e80c7258f2bdda19f949760d211b59e`.
These identities belong to the failed run, not a prospective correction test.

## Failure mechanism and bounded correction

The old controller accepted a generic `rejected` status string as the outcome
of any pending Water exit. A copied snapshot from a previous rejected profile
reset could therefore clear a newer pending exit. When the worker later installed
the ordinary Tower successfully, the controller had no pending exit left to end
the blind session. This explains the retained blind mapping and subsequent
session-start failures without a physics or recipe change.

The correction keeps the existing latest-command slot and snapshot ownership.
Fresh tower and profile resets allocate a monotonic per-controller request
serial. The worker echoes that identity with an explicit applied flag initialized
false before early rejection paths and set true only after successful native
installation. Controller `_reconcile_water_exit` ignores stale or incomplete
receipts. Matching rejection retires the pending exit while preserving blind
state; matching success also requires inactive Water and a profile before ending
the session and restoring its pre-blind policy. Status text no longer decides
acknowledgement. The [canonical receipt contract](../reference/interfaces-and-message-contracts.md#desktop-water-exit-receipts)
owns the exact fields.

Production changes are confined to [main.gd](../../godot/scripts/main.gd) and
[simulation_worker.gd](../../godot/scripts/simulation_worker.gd). The existing
[Water Feel controller regression](../../godot/tests/test_water_feel_controller.gd)
owns the deterministic ordering controls and retained live desktop/Web checks.
The correction does not change native source, runtime payloads, Water kernels,
material rules, recipe data, dependency pins or CI provider policy.

## Validation boundary at this checkpoint

Source inspection and the focused local results below establish the bounded
request/outcome correction. Applicable final-head hosted results remain a
separate gate. The correction's follow-up PR receipt is the external join for
the exact tested head and merge; neither the original PR's green checks nor the
failed post-merge run certify a later patch. No hosted correction pass is
inferred here.

Local repository preflight verifies all 18 materialized runtime payloads and
unchanged current native/provenance inputs. `check_m11_consistency.py` passes
18 retained records and 28 source hashes against audited historical commit
`05ea45fda7bdd7b0150eb86c4922c202e89e08f4`, with no errors. This is historical
integrity evidence only. `git lfs fsck` and `git diff --check` also pass; those
checks do not execute the controller correction.

Final documentation preflight passes **103 current documents, 203 canonical
claims, 2,266 local links and 183 heading anchors**, with no errors. The
materialized repository check again passes all 18 payloads. Frozen retrieval
retains **32/32 within the top five**; the supplemental set reaches **110/110
within the top five**. The new `WATER-EXIT-01` question and all four `GEN007-*`
questions rank first. All 109 prior supplemental question objects and the
frozen fixture remain unchanged. These checks establish documentation integrity
and lexical routing; they do not establish controller execution or correctness
of an unseen generated answer.

## Focused correction execution and failure control

The [fixed-source receipt](water-exit-2026-10-22/fixed-validation.json) records
Linux x86-64 headless execution on base
`90a5bfc9a0664ca6eb78c00a18619aa4409619b1` plus these local file identities:

| Changed input | SHA-256 |
|---|---|
| `godot/scripts/main.gd` | `b119f569f684fe79a1ef06f17f1593f02d9d5dc8a76dc6eee42916b7bbc3c663` |
| `godot/scripts/simulation_worker.gd` | `a65b063a01a40ebd7d05a84b9af3e8716acb02972f818ee0a7310f0fd4e88b3a` |
| `godot/tests/test_water_feel_controller.gd` | `554edbbafdaf2c801d29bf34b7991dab6b2bdee77978b355c6335fdfb232834c` |

The [runtime verification](water-exit-2026-10-22/runtime-verification.json)
binds the pinned Godot `4.7.stable.official.5b4e0cb0f` executable to its checked
archive and records both materialized native libraries against their LFS
pointers. Godot binary SHA-256 is
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`;
the unchanged Linux CyberSand library is
`28f99172da4256acc34bcd932b113dacabe52bdb459fd0ee4883f741e41bd8e5`.
The commands below use that executable and the identified checkout's `godot`
directory; the receipts preserve full arguments, writable XDG paths and log hashes.

| Execution | Godot arguments after executable | Timeout | Observed result |
|---|---|---:|---|
| Fixed import | `--headless --path <checkout>/godot --editor --quit` | 240 seconds | Exit 0 in 4.983 seconds; no errors |
| Fixed controller regression | `--headless --path <checkout>/godot --script res://tests/test_water_feel_controller.gd` | 180 seconds | Exit 0 in 6.537 seconds; no errors |
| Reverted-reconciler mutation control | Same controller command against the isolated control project | 180 seconds | Expected exit 7 in 7.043 seconds; seven semantic failures |

The corrected runner passes all **10 deterministic receipt cases**, including
older rejection/success, missing identity/outcome, different request identity,
incomplete success and matching rejection/success. It also completes the retained
live desktop/Web-controller lifecycle checks and explicit worker receipt checks
for rejected, successful profile and Fresh tower exits. This is local headless
controller execution, not an actual browser or Windows correction run.

The [mutation-control receipt](water-exit-2026-10-22/reverted-reconciler-control.json)
preserves the original consumer conditional transplanted verbatim into the new
reconciliation helper, preceded only by `tower_context=context`. This is a
**reverted-reconciler mutation control**, not an unmodified-baseline test.
Its seven semantic failures include older rejection/success and a missing
receipt; there are no parser or helper errors. Its initial import exited zero
but logged sandbox XDG/config/cache and local-socket diagnostics, so that import
is not a clean gate. The separately executed fixed import passed cleanly with
writable XDG directories and permitted local loopback. Neither qualification is
silently attributed to the other run.

All three retained reports are exact copies of the observed records. Their
source-file and raw-log hashes were independently checked before retention;
raw logs remain outside the repository. Final hosted validation and merge
verification must still bind the committed correction head.

The original [GEN-007 evidence](2026-10-21-gen007-workbench-qualification.md)
retains its qualified visual pass, original failed 2 GiB graphical bound and
explicit revised 4 GiB bound, observed 136.857 ms UI service call and 170.958 ms
frame gap, and 0.80% worst-seed logical-work headroom. This control correction
does not improve those measured limits or establish target-PC performance,
Windows graphical acceptance or formal blind-study readiness.

## Documentation change map

| Affected contract | Disposition |
|---|---|
| Tower controls and ownership | Document exact-request exit acknowledgement and rejected-session preservation in the Tower runbook and ownership contract. |
| Message fields | Add the command serial and copied serial/applied outcome at the existing lab-message boundary. |
| Testing and evidence | Route deterministic receipt-ordering and existing live controller tests; preserve the failed Windows artifact and separate later outcomes. |
| Retrieval and handover | Add a supplemental stale-exit question and direct routes; retain the frozen 32 questions and all 109 prior supplemental objects. |
| Native Water invariants, schema, configuration and ADRs | No physics, native ABI, save format, Water policy, user option or architectural decision changes. The controller invariant belongs to the updated Tower/message contracts. |
| Roadmap and programme order | No new programme work or reprioritization; GEN-007 qualification limits remain, and GEN-006 retains streaming/persistence ownership. |
