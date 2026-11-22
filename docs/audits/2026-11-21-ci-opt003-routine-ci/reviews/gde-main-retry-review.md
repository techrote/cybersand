# Independent GDExtension retry review

**Final verdict: GO.** Attempt 2 subsequently completed with all 54 applicable jobs successful, both exact-source platform coverage receipts independently checked, and only the two expected policy skips. The initial mechanism review and its in-progress observations are preserved below; the terminal qualification delta is at the end. No P1/P2 finding was identified.

Reviewed exact merged source `662df51cd8409a52332fa7ef15d06d8ab8945aed`, workflow `.github/workflows/gdextension.yml` SHA256 `f85126b7daa01f53deee591bcb9f8e1dc2271f192d41a1a515ab4694133ab516`, and live GitHub run `44967549040`. The exact source was read from Git rather than the older local checkout.

## Complete dependency closure

The transitive descendants of `ready_scope` are `execution-plan`, `linux-build`, `windows-build`, `windows-regression`, `windows-coverage`, `art-graphical-smoke`, `linux-regression`, `linux-regression-gate` and `physical-timing`. With the root, these are all ten job definitions applicable to this push. The sole outside job, `physical-actor-stress`, requires workflow_dispatch with its opt-in input and is correctly excluded. The saved `gde-main-retry-dag.json` records every exact predicate, dependency and artifact step.

`ready_scope` itself is skipped on push. Its three immediate production descendants use `always()` plus an ordinary-event predicate that permits this push; they do not require the root's success or outputs for a push. The downstream matrix jobs require successful current planner/build results, and the final reducers retain their failure checks.

GitHub's official REST documentation states that rerunning a job reruns its dependent jobs: <https://docs.github.com/en/rest/actions/workflow-runs#re-run-a-job-from-a-workflow-run>. The documentation does not separately guarantee the eligibility of a skipped root, but that uncertainty was resolved by the accepted retry and independent live readback.

## Actual retry and artifact isolation

Attempt 2 has new job IDs for the planner (`137043874747`), Linux build (`137043874559`) and Windows build (`137043874754`), all reporting the exact merged source, attempt 2 and start time `2026-11-22T00:53:40Z`. The root and physical stress jobs were freshly skipped under their original predicates. `gde-main-retry-attempt2.json` preserves this independent readback; these three production jobs were in progress when observed.

Every runtime/candidate download, platform-shard download pattern and final coverage input is bound to both `github.run_id` and `github.run_attempt`. The current reducers also receive the expected source/run/attempt. No attempt-1 runtime or test evidence is needed or accepted by the proposed retry. A planner-only or failed-jobs-only retry would omit its successful sibling builds, leaving current-attempt artifact names unsatisfied; rerunning this shared root avoids that gap.

Final admission still requires the complete attempt-2 matrix and both coverage reducers to finish successfully. Count the failed first attempt, second-attempt queueing and all retry runner-minutes in actual developer-turnaround/cost reporting. Do not splice successful attempt-1 jobs into the second attempt's qualification set.

## Bounded engineering-report check

The current working `ENGINEERING_REPORT.md` correctly distinguishes same-worker controlled family improvements from complete PR-cohort turnaround, retains unfavorable queueing, identifies the rejected experiment, and discloses single-pair and warm OS-cache limits. Its merged commit/tree identities were independently matched to Git. Its three cohort totals match the retained machine summaries (1799/1852/1809 seconds and 292.2833/290.8167/285.4167 runner-minutes). The corrected contract and both current worldgen-reader digests match the local evidence bytes. No material factual contradiction was found in this bounded check.

The report's explicit post-merge results, final critical-path and owner-status placeholders remain appropriate while the retry is running; they must be replaced with terminal, all-attempt accounting before final handoff. This review did not alter production or proof source, invoke a remote mutation or run additional scientific tests.

## Terminal qualification delta — 22 November 2026

Independent live readback of the attempt-specific GitHub endpoints confirms run `44967549040`, attempt `2`, event `push`, source `662df51cd8409a52332fa7ef15d06d8ab8945aed`, concluded **success** at `2026-11-22T01:14:49Z`. The original terminal API records are retained in `gde-main-coverage/gde-main-attempt2-terminal-run.json` and `gde-main-coverage/gde-main-attempt2-terminal-jobs.json`.

All **54 applicable jobs succeeded**: the planner, both new platform builds, all 24 Linux shards, all 23 Windows shards, graphical smoke, both coverage reducers and the retained timing job. The only skipped jobs are the original event-specific `ready validation scope` and opt-in `physical-actor-stress`. Every job record reports the exact source, run and attempt. There are no unexpected skips, cancelled jobs, failed jobs or missing matrix members. The Windows coverage job is `137048498256` (completed `01:12:46Z`); the Linux gate is `137048882697` (completed `01:14:22Z`).

The expected platform inventory was independently derived using canonical discovery and shard assignment code from a clean worktree whose complete tree is identical to the merged tree `39b658c5de9c5e541312b5190bd5d8ba797c6bed`. Exact code bytes were correlated to the merged Git source. The retained inventory SHA256 is `3c446d2758a2875548a44484e4cedc49f1867cb004ada38310f81d3723564109` (`gde-main-expected-inventory.json`).

| Original final artifact | Artifact ID | Inventory independently matched | Original ZIP SHA256 |
| --- | --- | --- | --- |
| `windows-coverage-44967549040-2` | `14733406653` | 315 cases, exact 23 shard assignments, 338 source-verified original log seals, 23 explicit graphical exclusions | `849c9ff66891fd70786795bc4c3fc2d9137c4cd530adf30ab28e02b3bb2b1758` |
| `linux-coverage-44967549040-2` | `14733112711` | 338 cases, exact 24 shard assignments and 24 original shard report seals | `8362b7053f1b37a20a926fc7a8cc82ba328c70c17624567cae5638f50382c3dd` |

Both downloaded ZIP lengths and SHA256 digests match GitHub's artifact metadata. Both receipts report the exact merged source/tree, run `44967549040`, attempt `2`, the expected execution-policy identity and passed coverage. Every original shard-report path in each receipt names attempt 2. The Windows receipt SHA256 is `47c46df1a52274ee3f627813fe76f618185aa214adbf600ddd5493e516116607`; the Linux receipt SHA256 is `7336f99cacd4191ce43e15afd841fd94758de0bb0dce40cbb545d691d8283e23`. The original archives, extracted files and artifact metadata are retained under `gde-main-coverage/`.

Each platform also retains 15 play-readback proofs. All 30 were checked for the current source, expected platform, complete passed execution and matching retained verification-output/log digests. This is a check of hosted evidence; it does not claim physical Windows/device acceptance or new local execution of the scientific tests.

The repeatable receipt/API/inventory readback is `check_gde_main_coverage.py` (SHA256 `a293375d15106ad2d7ceabf1bcac4e97174f68b273ef397072c26cf115a2bb96`), which completed with exit 0. Its machine result, `gde-main-attempt2-final-qualification.json`, records source identity, all-outcome checks, artifact and receipt digests, and a digest inventory of every extracted file. The production hosted reducers verified the original test logs against canonical source; this bounded independent readback did not download and rerun every raw shard artifact locally.

**Failure isolation is preserved.** This admission uses only fresh attempt-2 outcomes and artifacts. Attempt 1's checkout failure and failed reducers remain historical evidence and must remain included in developer-turnaround and runner-cost accounting, which is owned by the separate performance reviewer. No new CI run, production/proof edit or remote mutation was performed during this final check.
