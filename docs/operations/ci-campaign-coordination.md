---
title: Read-only CI campaign coordination
status: Current
document-kind: runbook
scope: Bounded repository job observations and explicit source/run/attempt request ledgers; no execution, acceptance, cancellation or publication authority
canonical-for: [ci-campaign-coordination]
last-reviewed: 2026-11-24
related-documents: [ci-execution-and-performance.md, github-development-and-release.md, publication-custody.md, ci-engineering-closure-001/FINAL-DECISION-PACKET.md]
---

# Read-only CI campaign coordination

Use [ci_campaign_status.py](../../tools/ci/ci_campaign_status.py) before requesting
an expensive campaign. It collects a bounded snapshot of one repository through
an already authenticated `gh`, or reduces saved responses from the approved
GitHub connector. Every online request is an explicit GET. It cannot dispatch,
cancel, rerun, reprioritize, publish, promote or merge work.

This additive helper belongs to the CI-ENGINEERING-CLOSURE-001 Draft candidate.
Existing concurrency, filters, source admission, required reducers and owner gates
remain authoritative. Its output is coordination information, never an acceptance
status.

## Collection and offline use

```bash
python3 tools/ci/ci_campaign_status.py --collect \
  --repository techrote/cybersand --max-runs 20 --max-pages 2 \
  --raw-output build/ci-coordination/snapshot.json \
  --output build/ci-coordination/status.json \
  --markdown build/ci-coordination/status.md

python3 tools/ci/ci_campaign_status.py \
  --snapshot build/ci-coordination/snapshot.json \
  --ledger build/ci-coordination/campaign-ledger.json \
  --output build/ci-coordination/status.json \
  --markdown build/ci-coordination/status.md
```

The tool does not obtain or print credentials. If existing `gh` authentication
or a query is unavailable, it records partial observations. The approved connector
can provide the same GET resources; do not transfer credentials between tools.

The default collector queries `in_progress`, `queued`, `waiting`, `pending` and
`requested` separately, at most two pages each, then at most twenty run/attempt
pairs. Explicit ledger requests take precedence. Jobs use the specific attempt
endpoint; the run is read before and after its jobs. Maximum configurable bounds
are one hundred run/attempts and five pages per query. There is no polling loop,
automatic retry or mutation.

Exit `0` means the bounded observations passed consistency checks, not that tests
passed. Exit `2` retains a useful partial report. Exit `1` refuses malformed or
contradictory identity input. Preserve original snapshots; the report records the
SHA-256 of the exact input bytes parsed, including an optional ledger. It does not
reopen an input to compute its pin after summarizing. A later collection is a new
observation.

## Connector snapshot and campaign ledger

Snapshot schema `cybersand-ci-status-snapshot-v1` contains `repository`, UTC
`collection_started_at`/`collection_finished_at`, `run_queries`, `runs` and `errors`.
Each query has `status` and ordered original `total_count`/`workflow_runs` pages.
Each run record has `run`, attempt-specific `job_pages` and `run_after`. Optional
`artifact_pages` are metadata only. The
[tests](../../tools/ci/test_ci_campaign_status.py) provide executable synthetic
examples; the decision packet retains a separately labelled real observation.

Page totals, duplicate identities, API head SHA and run/attempt joins are checked.
Changing runs, contradictory status queries, missing jobs/rechecks, incomplete
query coverage and inconsistent timestamps prevent a complete observation.
Unknown data never becomes verified evidence.

Optional ledger schema `cybersand-ci-campaign-ledger-v1` requires a matching
`repository` and a `campaigns` array:

| Field | Purpose |
|---|---|
| `key`, `programme`, `owner`, `branch` | Explicit identity and ownership, not guessed from job names. |
| `kind` | `ordinary_pr`, `frozen_source`, `manual` or `unknown`. |
| `trigger_sha` | Exact API head expected for the run. |
| `source_sha`, `source_tree` | Independently recovered tested checkout, or null. A synthetic merge may differ from API head. |
| `current_head_sha` | Observed current PR head for ordinary supersession. |
| `runs` | Positive `run_id` and `attempt`, with unique exact `required_jobs` names. |
| `human_gate`, `publication_gate` | Supplied owner status, including unknown or pending; never machine approval. |

A run/attempt cannot be claimed twice. Missing, ambiguous or skipped required jobs,
stale trigger, wrong branch, incomplete inventory or non-successful workflow block
the request. Unregistered required inventories cannot turn green. `reported-success`
is accompanied by `qualification: not-established-by-metadata` and a requirement
to use the source-bound programme verifier.

For an ordinary PR, a supplied newer head marks the old request superseded; its
historical successful jobs retain their original outcome. Frozen/manual campaigns
are not automatically superseded by branch movement. Cancellation, failure,
timeout, action-required, skipped and neutral remain distinct.

## Capacity, timing and evidence limits

Running jobs with valid starts and positive runner IDs contribute to distinct
assigned-runner observations. Others remain unassigned/unknown. Waiting states
are reported separately. IDs are observations during the collection interval,
not a simultaneous count: jobs can transition even when a workflow remains in
progress. The bounded repository sample does not establish account utilisation
or billed minutes. Runner names and arbitrary/signed URLs are omitted from compact
output.

The owner's stated forty standard hosted slots remains an owner-reported claim.
Repository metadata identifies personal owner `techrote`; approved repository and
profile reads do not expose its current plan or a support-adjusted ceiling.
[GitHub's current limits](https://docs.github.com/en/actions/reference/limits)
list forty standard concurrent jobs for Pro and sixty for Team; neither proves
this account's entitlement. Other organisations, runner types and budgets must
not be pooled with this account. The administrator can check applicable capacity
in the [hosted-runner usage view](https://docs.github.com/en/actions/how-tos/manage-runners/github-hosted-runners/view-current-jobs).

Creation-to-start includes matrix admission, dispatch and possible capacity delay;
it does not isolate the cause. The ten longest active jobs are critical-path
**candidates**, pending a verified dependency graph and future durations. Use
[ci_run_metrics.py](../../tools/ci/ci_run_metrics.py) for completed single-attempt
accounting, preserving retries and failures and separating runner time from wall
time.

Artifact names and workflow badges establish no custody. Reuse requires original
complete source/input/compiler/platform/run/attempt and actual process/report/log
checks. The separate [custody helper](publication-custody.md) adds integrity checks
under an independently pinned contract; it grants no semantic qualification or
publication permission. Verifier replay only applies to its original immutable
source and evidence.

## Request discipline

The lead owns the [CI request ledger](ci-engineering-closure-001/CI_REQUEST_LEDGER.json).
Before heavy execution, refresh ownership, source, required inventory, prior cost,
capacity observations and valid evidence. Stagger optional requests when required
work is waiting. No observed queue is not permission to occupy the whole account.

This helper changes no active publisher or frozen campaign. Ordinary supersession
remains in established workflows. `SCHEDUSWARM.md` remains paused; dispatcher lane
counts do not determine physical runner capacity. The owner retains capacity,
Ready, merge and human acceptance decisions.

## Focused verification

```bash
python3 tools/ci/test_ci_campaign_status.py
python3 tools/ci/test_ci_run_metrics.py
python3 tools/ci/check_ci_provider_policy.py
python3 tools/ci/check_ci_scheduling_policy.py --output build/ci-inventory.json
```

Controls cover mixed identity, truncated/duplicate pages, mutable observations,
misleading successes, ordinary supersession, frozen-source preservation, malformed
clocks/JSON, authentication failure and GET-only bounded collection. These tests
do not exempt new CI tools from mandatory final-source hosted qualification.
