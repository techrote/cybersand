# Native supersession queue observation — pre-existing condition

At23:48UTC, final PR723 Native run44963101962 (source19023b4016facfda2b13b9a1503742e4a9fe1982; event23:42:31) remained workflow-pending with zero jobs. Superseded source28ec075afab840cf6fbb35190a7b1915808904f3 run44961867617 (event23:27:16) still held the same native-pull_request-723 concurrency group. Its worldgen job137022396292 had been executing since23:28:00. A separate old-source Native run44962021727 was cancelled; that did not stop44961867617. At23:49:36 the old worldgen had completed and its final reducer was running.

The existing native-shards job condition in .github/workflows/native.yml:155 begins always(). This is unchanged by PR723 except its diagnostic artifact path. GitHub documents that cancellation reevaluates each running job condition; if it remains true, the job keeps running. This is consistent with the observed stale-source continuation. The exact cancellation-request event log was not retrieved, so the causal attribution is explicit inference, not a fully reproduced policy experiment.

Primary sources: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-cancellation and https://docs.github.com/en/actions/how-tos/troubleshoot-workflows . The latter documents force cancellation and the inverse cancelled() condition for jobs which should stop on cancellation.

The integration owner was immediately notified. This reviewer made no remote mutation. A force-cancel of the specific superseded run can unblock current source without changing source; a permanent condition change should be a separately reviewed CI increment preserving per-step receipt retention and final non-green cancellation semantics.

For performance reporting, count actual event-to-completion including this queue. Separately show source-qualified execution time and the controlled pair, so a queue artifact is neither hidden nor mistaken for compiler/test regression. Superseded/cancelled/skipped runs are never qualification evidence.
