# Final independent ownership and navigation review

**No remaining finding was found in the reviewed ownership, navigation, recovery and scoped replay behavior at published commit `e034f2294663e0485cfb9adcc8ada46a6e977cee`, tree `246e7324ca618d98c43a0ed54fe19bc86a155877`.** This is an independent source and actual native runtime review for Draft/HOLD PR #741, stacked on #738. It grants no merge, Ready, default-change, package or human hardware acceptance.

## Exact source and runtime

I extracted 70 committed project, scene and script files directly with `git show`; all 70 still matched after execution. The production changes relative to the independently reviewed682 baseline are the optional asynchronous FeatureNavigation hook and rehearsal UI lifetime/input handling. The worker, host, bridge and worker replayer bytes remain unchanged; their previous recovery and replay controls were rerun against the final extraction.

The actual executable was Godot 4.7 stable (`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`) with Rapier2D 0.35.2 (`566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`). The reused native Linux library was `64e67fc021a202f245fb5bdd49a21eb5394ea557147b68cf21053aa3432040dd`, 5,573,096 bytes, sealed at source 514d76fb. I independently compared all 116 native source inputs and 5 build-contract inputs against e034; none differed. The actual artifact matches its retained seal. This provides actual native script-level evidence, not a newly built e034 platform package qualification.

## Executed checks

| Actual native suite | Checks | Failures | Result |
| --- | ---: | ---: | --- |
| Maintained navigation |135|0|All 8 lifecycle scenarios completed. |
| Recovery |63|0|Lost cancellation/reset receipts, queued reset admission fence, action retirement and rejected-start retry. |
| Scoped replay admission |57|0|Real unknown mutation, inherited-history refusal and fresh-process moving-cell replay. |
| Native worker |31|0|Exclusive native owner and transport controls. |
| Worker commands |29|0|Value commands and host input controls. |
| Independent post-exit input negative |17|0|Original 44-intent loss no longer reproduces. |
| Independent held quit-priority negative |9|0|Original quit-to-launcher downgrade no longer reproduces. |
| **Top-level total** |**341**|**0**|Every process exited 0; no unexpected script/error/warning/leak lines. |

The maintained navigation suite additionally launched a separate real Godot process. Its 18 checks passed, the source-bound child receipt was written, and the process actually exited 0 through the production window-close path. The exact committed qualifier accepted the raw navigation JSON with all 8 required cases,135 parent checks and18 child checks.

The scoped replay suite also launched real independent processes. Fresh-registry replay executed 19 actions and 2 semantic ticks with 47 checks/0 failures, mapping recorded session 4 onto fresh session 1. The uncertain-mutation and inherited-registry traces both refused before a replacement World or action. Their structured `failures:1` and exit 1 are the expected refusal controls, not failed top-level assertions.

## Original operator findings and final disposition

**OPERATOR-01, P1: F2 destroyed the scene before its native owner and main physics were disposed.** The original 682 physics review recorded 22 checks/8 failures: the old worker still owned 526 structural cells; active and sleeping RIDs persisted; prior automatic quit policy stayed false; launcher re-entry overlapped old and new owners. I independently inspected that original negative and the full repair. The final maintained suite verifies actual F2/autoload handoff with an awake body and pending native receipt, natural sleep, unconsumed opening receipt, reset overlap, a held interval, stop-delivery faults, an already Closed owner and false prior quit policy, and window close. Native stop/join, empty RID registries, released physics space and closed trace are checked before scene replacement. The global completion checks both current scene identity and scene readiness, then checks instance identity again at the deferred handoff. Resolved at e034.

**OPERATOR-02, P2: a button could enqueue new material intent after exit had cancelled the queue.** My actual-native first-repair probe sent real F2 input, cancelled 1 preexisting pointer intent, then emitted the actual support-cut button signal while host Closing. It admitted 44 new intents and displayed their admission; scene destruction silently discarded them. The retained valid negative is `navigation-repair1/reentry-v2.log` with 17 checks/2 failures. The central play-input gate and support/erosion button gates now refuse before admission. The same independent probe passes 17 checks at e034, and the maintained suite tests both actual button signals. Resolved at e034.

**OPERATOR-03, P2: F2 retry after ShutdownHeld downgraded a previous window-close request.** My first-repair probe admitted a real native tick, requested F2, then delivered the production window-close notification. Quit took precedence until only main's elapsed deadline was advanced past 15 seconds. The actual worker was still inflight and not stopped; host entered ShutdownHeld. The UI cleared its closing flag, and F2 retry replaced quit with launcher. The retained valid negative is `navigation-repair1/held-v2.log` with 9 checks/1failure. The final code preserves quit through ShutdownHeld retry, records the effective destination, and allows explicit Reset to clear the old exit decision. The same independent probe passes 9 checks at e034, reaching the real-inflight deadline on its first attempt. The maintained subprocess also verifies final process exit. Resolved at e034.

The original probe scripts and product-delta patch are retained independently of the repaired source. The earlier unflushed-input harness run and unqualified-notification parse error are explicitly excluded as finding evidence.

## Earlier ownership findings remain repaired

The exact final extraction reran all 180 prior ownership assertions:63 recovery,57 replay admission,31 worker and29 command checks. This includes OWN-01 lost-cancel hold escape; OWN-02 lost-completed-reset recovery; OWN-03 terminal action dispositions; OWN-04 queued-reset race; OWN-05 false successful replay of uncertain mutation; OWN-06 noninitial session replay; and OWN-07 invalid startup consuming an unrecoverable generation. Their original negative observations, source hashes and minimal reproducers remain in the earlier review and are carried forward in `final-review.json`.

OWN-06 retains an explicit supported scope. A trace from a fresh native registry can alias its current session namespace; stale source sessions still refuse, and owner/cell/incarnation/material/geometry/pose witnesses are never re-hit-tested or remapped. An in-place Host.reset retains allocator history, so its isolated trace remains observation-only and refuses before native startup. The UI's close/recreate route supplies a fresh registry for standalone replay.

## Evidence and limits

`source-binding.json` binds every extracted source file, both independent probes, the engine/native/Rapier artifacts, and all 121 native/build inputs. `execution-summary.json`, per-suite execution records/logs/receipts, the source-bound navigation parent and child JSON, `navigation-qualifier-validation.json`, and replay traces/results retain the actual commands and observations. `final-review.json` binds their SHA256 hashes and provides exact source-line references for every finding.

The maintained stop-delivery fault case modifies delivered status after actual native thread exit; it does not claim to reproduce a natural native material-disposal refusal. The independent held probe instead changes only main's elapsed observation deadline while real native work is still inflight. Reviewer-only cleanup in that probe changes the destination after the tested assertion so the evidence can be written; the maintained child supplies actual process-exit evidence.

This remains a separate real-World/exclusive-GDScript-worker and main-thread Rapier rehearsal. It does not adopt the ordinary CyberSimulationWorker or resolve the ordinary GCR immutable geometry/World attachment seam. The reviewed operator routes are F2, UI reset and window close. Forced process termination or arbitrary external scene destruction is outside that explicit asynchronous navigation protocol. The preserved 682 platform matrix is historical baseline evidence; fresh e034 Linux/Windows qualification and owner-package custody are separate results, not asserted by this local-runtime review.
