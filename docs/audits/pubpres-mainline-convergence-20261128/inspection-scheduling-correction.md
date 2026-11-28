# Read-only inspector scheduling correction — 28 November 2026

## Original failure and scope

The standard Documentation and provenance run [46140941585](https://github.com/techrote/cybersand/actions/runs/46140941585), job 140966511016, failed on application qualification source `ff7a9e87b5d37fde66d4d932c9fa84cc0b3a4dae`. Its original scheduling-policy log records ten tests and one failure: `pubpres-mainline-inspect.yml/inspect-original: matrix requires an explicit max-parallel`. The original failed run is retained. It is not a skipped or passing documentation gate.

The affected workflow only authenticates and reads the original Q2 artifacts. It does not execute or change application source. The repair adds exactly `max-parallel: 2` beneath its existing `strategy.fail-fast: false`. Its five role definitions, source/run/attempt identities, archive hashes, bounded readers and read-only permissions remain byte-identical.

| Inspector Git blob | Identity |
| --- | --- |
| Qualified original | `45a52c76d35bbe5395d296eebae46ae76c82aebe` |
| Single-line scheduling repair | `ee280abbd5726ccd98504379b61437b8304906f3` |

## Publication-source contract

The Q4 application campaign remains tied to its original source and unchanged production and qualification bytes. The publisher accepts this one subsequent inspector edit only when Git reports the exact registered original and repaired blob identities, each with mode `100644` and type `blob`. The path is not a general workflow exception. Foreign, reversed, identical, executable, symbolic-link or tree entries refuse the transition. Any accompanying unqualified application, original reader, qualification adapter or unrelated workflow edit still refuses publication.

The proof records both inspector blob identities in `reviewed_inspector_scheduling_transition`. The original qualification archive readers, native-build verification, four-path runtime publication, remote branch lease and fresh remote LFS verification are unchanged.

Three additional unit tests check the actual single-line file transition, adverse blob/type/mode substitutions and accompanying unqualified edits. These tests must execute successfully in the hosted admission gate before the guarded publication job can run. Source review alone is not an executed test result.

## Independent review and resulting-source disposition

Specialist C authored the repair. The principal independently fetched the original and repaired blobs, verified the exact one-line difference and confirmed that the publisher's original archive replay and writer code is unchanged. The repository explicitly enforces LF for YAML, so the canonical Git-blob test is portable across its Linux and Windows checkouts. A second specialist reviews the repair before integration.

The final delivery source reruns standard Documentation and provenance, the publication admission tests and the complete application qualification population. The final mission ledger records their actual outcomes. This correction neither grants physical owner acceptance nor changes the Draft/HOLD or merge-authorization requirements.
