---
title: Active work ledger maintenance
status: Planned
document-kind: navigation
scope: Single-steward coordination records, source-qualified handovers and deterministic ledger maintenance
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [cybersand-active-work-ledger.md, cybersand-codex-development-handover.md, source-checkpoint-and-recovery.md, github-development-and-release.md, documentation-maintenance.md]
---

# Active work ledger maintenance

The [dashboard](cybersand-active-work-ledger.md) answers what has been published,
what remains blocked, who claims a write branch, and which bounded action comes
next. Its only editable state is
[cybersand-active-work-ledger.yaml](cybersand-active-work-ledger.yaml).
The Markdown dashboard is generated. Read both the verification timestamp and
the limitations before selecting work.

This is a coordination record. Source, canonical subsystem contracts, immutable
scientific receipts, GitHub merge state and explicit owner decisions retain their
own authority. The ledger does not approve feature integration, close an issue,
refresh a source lock or certify a running chat. It remains a draft proposal for
operational adoption until independently reviewed and accepted by the owner.

## One steward

One designated steward edits the YAML. Initially this is the ACTIVE-LEDGER-001
coordinator on its dedicated branch. The repository owner designates the next
steward; GitHub account authorship alone is not an agent or worktree reservation.
Implementation and review agents supply source-qualified handovers in their own
workstreams. They read this ledger before selecting new work and preserve their
existing branch ownership.

If two agents claim a branch or overlapping exclusive source region, preserve
both claims and set `coordination_hold`. Record which worker stopped or released
its reservation. Ask the owner to identify the sole writer before the next
implementation assignment. A second lane may reference the same PR when its
scope and role are distinct; it must not silently become a second writer.

No automation or new CI requirement is installed by this change. Reconcile after
a published checkpoint, changed head, completed CI attempt, review, merge or
explicit owner decision. A daily read-only reconciliation may be useful, but it
requires a separate instruction before scheduling.

## Source-first update procedure

1. Read this ledger, the development handover, applicable contract and existing
   owner claims. Work in an isolated branch/worktree; preserve unrelated work.
2. Fetch accepted main, complete open-PR pagination and relevant PR/issue state
   read-only. With GitHub REST, request `pulls?state=open&per_page=100&page=1`,
   continue sequential pages and retain an empty terminal page. Record the
   observation window, exact query URLs and count. Search results are a useful
   cross-check but are not pagination proof.
3. For changed lanes, inspect head/tree, base/ref, merged state, substantive
   checkpoints, reviews, job attempts and actual executed checkouts. An API
   association to a PR head does not prove that a job checked out that head.
   Authenticate synthetic merge parents and complete tree equality explicitly.
4. Make one bounded YAML edit. Retain previous negative results at their tested
   identities, record the evidence and add a dated `change_log` entry. Treat stale
   issue prose and newer immutable receipts as distinct observations.
5. Run the offline commands and focused regressions below. Inspect the generated
   diff, source scope and retrieval evidence. Publish a small reviewed
   documentation/tooling PR, leaving merge approval separate.

```sh
# Use the repository's existing hash-pinned YAML dependency in a suitable venv.
python -m pip install --require-hashes -r tools/requirements-ci-audit.txt

python tools/operations/active_work_ledger.py validate
python tools/operations/active_work_ledger.py render
python tools/operations/active_work_ledger.py check
python -m unittest discover -s tools/operations/tests -p 'test_*.py'
python tools/operations/active_work_ledger.py summary

# Optional explicit observation time: warnings only, never a status rewrite.
python tools/operations/active_work_ledger.py validate --as-of 2026-11-06T15:30:00Z

python tools/ci/check_docs.py
python tools/ci/check_repository.py
python tools/ci/check_m11_consistency.py
python tools/docs/retrieval_eval.py --output /tmp/ledger-frozen.json
python tools/docs/retrieval_eval.py --queries docs/reference/retrieval-challenges.json --output /tmp/ledger-challenges.json
git diff --check
```

Dependency installation is explicit; the ledger CLI itself performs no network
operation. `validate`, `check` and `summary` do not write the input or dashboard.
`render` writes only the chosen output. All commands accept `--ledger PATH`;
`render` and `check` accept `--output PATH`. Defaults resolve relative to the
tool's repository root. Fixed YAML produces byte-identical Markdown regardless
of working directory, local timezone or wall-clock date.

Use the pinned companion workspace when evaluating cross-repository references.
The ordinary repository gate can verify LFS pointer identity; separately report
whether `--require-materialized` succeeded. A pointer is not a usable runtime.
Inspect retrieval results, including `USABLE02`, rather than calling evaluator
exit zero sufficient answer acceptance. This ledger and this guide are navigation
entries outside the default answer corpus, so they cannot become Current usable,
physics or material behavior owners.

## Schema v1

All timestamps use quoted `YYYY-MM-DDTHH:MM:SSZ`. Source and tree identities are
full lowercase 40-character Git SHAs. Unknown nullable values are `null`.
Duplicate YAML keys and malformed record shapes are errors. The validator checks
declared proof consistency offline; it does not authenticate an arbitrary URL or
substitute for the steward reading its source.

| Record | Required meaning |
|---|---|
| `snapshot` | Observation time; independently verified accepted main SHA/tree; exhausted PR pages/count; freshness threshold; retrieval limitations. Input hashes preserve the planning origin. |
| `seed_ids` | All 24 original stable IDs. Seed `stage` becomes `delivery_stage`; `evidence_confidence` becomes the narrower `source_confidence`. No stage-name migration is needed. |
| `evidence` | Unique ID, kind, URL, observation time, summary and authority. Optional exact source/tree, result, scope, platforms and owner/merge-equivalence fields. Issue state names its matching `subject_issue`, `issue_state` and issue URL; activity decisions distinguish `started`, `stopped` and `released`. |
| `pull_requests` | Verified PR number/title/state/draft/merged, head branch/SHA/tree, API base/ref, mergeability, observation time and evidence. A test-merge SHA is never recorded as an actual merge. |
| `open_pr_inventory` | Exactly one classification per observed open PR, with rationale, evidence, timestamp and detailed workstream links when available. Merged foundations are excluded from this index. |
| `workstreams` | Stable ID, programme/scope, priority, issues/PRs, all seven independent status axes, ownership, blockers, typed dependencies and a bounded next action. |
| `change_log` | Bounded dated updates naming changed workstreams and evidence. Git history preserves previous snapshots; old failed findings remain attributable. |

Delivery stages are `queued`, `implementation_draft`, `evidence_draft`,
`ready_owner_gate`, `blocked`, `no_go`, `investigation_complete`, `integrated`,
`deferred`, `historical`, `unknown` and `coordination_hold`.

Agent activity is limited to `explicitly_stopped`, `user_reported_started`,
`published_progress_session_unknown`, `unknown` and `not_started`. There is no
`running` value. `not_started` is a planning disposition within the recorded
assignment, not proof that no unobserved chat exists. An explicit stop describes
the identified worker only.

Review dispositions are `pass`, `fail`, `conditional`, `pending`, `unknown` and
`not_required`. Merge approval independently uses `not_recorded`, `granted`,
`withheld` or `not_required`. `granted` requires an explicit verified owner
decision by `techrote`, bound to the same PR head/tree. A recommendation, successful
check, Ready UI state, positive gameplay feedback or prior-source approval cannot
satisfy it. Verified `merged=true` can establish historical integration without
inventing an owner-approval record.

Qualification results are `pass`, `fail`, `skipped`, `not_run`, `inapplicable` and
`unknown`. Every PASS names tested source/tree, scope, platforms, runtime and a
matching evidence record. Authority distinguishes verified observations from
reported execution. A reported PASS cannot satisfy readiness's verified required
gates. `exact_head`, `historical`, `tree_equivalent` and `not_applicable` describe
the source binding. A synthetic merge needs its tested SHA/tree, current head
SHA/tree, ordered base/head parents and explicit verification; if the base later
changes, preserve the receipt as historical. `inapplicable` needs a sourced
rationale, rather than serving as a waiver for a failed or skipped required gate.

`ready_owner_gate` requires independent current-head review, verified required
current-source qualifications, no unresolved blockers, an actually mergeable
non-draft PR against recorded main and satisfied integration prerequisites.
Owner approval remains a separate decision. Any unresolved physical failure
prevents a CPU-only pass from promoting the lane. Successful diagnostic execution
can coexist with a negative scientific disposition.

Typed dependencies are `hard`, `hard_for_integration`, `hard_for_implementation`,
`stacked`, `coordination`, `source_conflict` and `informational`. Hard/stacked cycles,
self-edges and missing targets fail. A stack base must match its target's branch.
After a predecessor merges and the dependent targets main, change the edge to
`hard_for_integration` and retain the original stack in notes/change history.
Source conflicts describe required coordination; they do not grant permission to
change another branch.

PR classifications are `active_relevant`, `stacked`, `evidence_only`, `held_no_go`,
`historical` and `unknown`. Explicit frozen/superseded evidence takes precedence
over a mechanical stack label; the original base still remains visible. Unknown
is a valid conservative classification, never a reason to omit a PR. Metadata is
complete as of the inventory timestamp; deeper CI review has its own scope.

## Handover contract

Supply the following checkpoint in the implementation lane's own authorized
handover. The steward verifies and reconciles it; no other agent edits the ledger
concurrently.

```text
Workstream / issue / PR:
Exact branch and sole writer claim (or unknown / released / collision):
Published head SHA / full tree / base:
Tested source and actual checkout; any independently verified tree equivalence:
Runtime/build hashes, toolchain, OS and execution scope:
Executed PASS and FAIL gates; SKIPPED / NOT_RUN / UNKNOWN / INAPPLICABLE separately:
Changes since the previous checkpoint; retained negative evidence:
Independent review disposition and source:
Blocker and one bounded next action:
Owner approval state and explicit source-bound reference, or not_recorded:
Stop condition: Record progress and stop.
```

## Staleness and adoption

Freshness warnings ask for source revalidation. They never mark a chat stopped,
abandon a PR, remove a failure or change a stage. Recheck live head/base and owner
decisions before any integration. Preserve a dated pre-publication inventory when
creating the ledger PR itself; report that newly created PR separately rather
than trying to embed a self-referential commit SHA in its own contents.

Adoption requires independent review of the completed tooling/data and a separate
owner decision on the ledger PR. Feature PR acceptance remains outside that
decision. Read the [dated implementation audit](../audits/2026-11-04-active-ledger-001.md)
for the actual snapshot corrections, tests, limitations and review disposition.
