# Ordinary Godot budget-test correction — 24 November 2026

This dated review records one ordinary CI test correction after the successful Q7 qualification and guarded runtime publication. It does not change the qualified application, original evidence or runtime identity. The [machine-readable record](ordinary-budget-test-correction.json) contains the exact input comparison, failure, test results and independent review hashes. The eventual final decision packet owns the complete ordinary-gate outcome.

## Original failure and cause

The full [GDExtension run 45459025464](https://github.com/techrote/cybersand/actions/runs/45459025464) at broad-request source `2cad3ae2d0fce0eda84701eebdf1ae7cf6c9fcae` failed in budget job `138676199669`. `test_original_linux_and_windows_inventory_is_complete_and_fits` asserted at most 24 shards; the unchanged planner produced 25 for all 344 Linux cases. The failure prevented the mandatory matrices from being emitted. Successful platform builds do not make that run pass. Its original failed log remains preserved, SHA-256 `f7dc2fa502b1b4352e4ddb72ce49f433c28f396b4ab9639a3e5049f91f705f45`.

Commit `9a01d782a6b93cb3878b12e50ee40ebfd502e31b` introduced the fixed 12–24 unit-test band when the intake was 246 Linux / 233 Windows cases and the dated projection was 20 / 19 shards. The [canonical scheduling policy](../../operations/ci-execution-and-performance.md) explicitly makes machine discovery authoritative as the game expands. Its actual guards remain 256 matrix entries, at most 16 cases per shard, complete unique case coverage, unchanged child watchdogs, and bounded hosted parents.

Accepted main's current inventory projects to 340 Linux cases in 24 shards and 317 applicable Windows cases in 23. The consolidated implementation adds four existing headless cases: native authoring patch, reciprocal controller, reciprocal protocol and reciprocal runtime. They add 60 estimated seconds, bringing Linux to 7,218.75 seconds against the unchanged 300-second shard target: 25 complete shards. Windows remains 23. This is an explained inventory change, not a scheduler or solver regression.

## Narrow correction and verification

Only `tools/ci/test_godot_job_plan.py` changes. Its live-inventory assertion now checks the existing case-capacity lower bound, `ceil(case_count / 16)`, and the existing matrix upper bound, `min(case_count, 256)`. Each shard also explicitly retains the 16-case cap. All original exact-inventory, nonempty-shard, complete-child-allowance, import/metadata, parent-budget and exceptional-watchdog checks remain.

One fixed positive regression supplies 400 distinct cases, each with the original 1,200-second child watchdog and weight 15. It requires exactly 25 nonempty 16-case shards, every original case exactly once, and every original watchdog unchanged. The existing 257-heavy-case matrix refusal remains, as do all other original refusal tests. No scheduler, policy, workflow, watchdog or application code changes.

The original local failure was reproduced before editing. All ten execution-budget helper groups then passed: **129 tests, zero failures, zero skips**. Both independent reviewers approved the exact new test hash `089b85c6424dfec48ccab235fced52007e9c17fcdfb9840672ed7084ef7797bd`. Their [source-impact review](ordinary-budget-test-source-impact.json), [policy review](ordinary-budget-test-policy-review.json) and [second independent review](ordinary-budget-test-independent-review.json) remain separate records.

## Qualified identities and legitimate reuse

Q7 run `45445188802`, attempt 1, remains successful at application source `5e34e0dd89c9d9f9511a2b6c2dca2550a5a56c9f`, tree `44a7f066a584d14a4069033e80ab58f3b2231d03`. Runtime publication remains `5323b837cdcaeab5da14f7ef92b0d3f059cf123d`. Its manifests and evaluator retain those original identities.

Exhaustive comparison finds exactly one changed entry in the historical 1,856-entry build ledger, with no added or removed build paths; the other 1,855 entries match. All 156 native inputs, 106 extension inputs, 52 native-definition inputs and 100 scientific compiler inputs remain exact. All 1,059 committed source files carried by the evaluator are unaffected. The Q7 fixture, producer, consumer and qualification workflow code and all eight published paths remain unchanged.

The repository already documents this treatment of postpublication test corrections in [local build and validation](../../operations/local-build-and-validation.md#published-and-development-identity-test-controls) and the [25 October publication audit](../2026-10-25-lcb003-runtime-publication.md#post-publication-identity-test-correction--2026-10-25). That precedent retains original runtime/manifests and their historical build ledger, explicitly records later test differences, and requires corrected-source full ordinary CI. It does not retag earlier execution or require a native rebuild for an unaffected test correction.

This decision applies to this single ordinary-CI test. It does not alter or bypass the strict prepublication source/request gate. No attempt is made to republish Q7 against a changed build inventory, and Q7 is not described as having executed the new test. The separate earlier native-receipt repair changed qualification observations and admission semantics and correctly required the complete fresh Q7 campaign.

## Remaining admission at this review

Fresh complete Documentation, Native C++ and GDExtension workflows must execute on the corrected checkpoint, with all mandatory inventory and coverage checks. Source identity, original failed GDE outcome, skipped mandatory matrices, and later successful evidence must remain distinct. The physical Windows 11/NVIDIA owner gate remains pending. Draft/HOLD, default-OFF controls and the prohibition on automatic Ready promotion or merging remain unchanged.
