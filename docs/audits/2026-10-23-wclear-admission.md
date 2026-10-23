---
title: WCLEAR-001 independent timing admission and execution boundary
status: Current
document-kind: audit
scope: Independent admission of the exact qualified prepared-resident clear-event protocol; owner execution authority remains pending
canonical-for: [wclear001-timing-admission-2026-10-23]
last-reviewed: 2026-10-23
related-documents: [2026-10-23-mat003-continuation.md, ../research/mat003-continuation.md, ../operations/mat-003prepass-registration.md, ../operations/github-development-and-release.md]
---

# WCLEAR-001 independent timing admission â€” 2026-10-23

## Decision and stop boundary

**Approved, narrowly scoped timing admission; execution is not authorized.** The
independent Codex reviewer `/root/independent_review`, separate from continuation
implementation owner `/root`, admits the exact 672-process paired protocol in
[the admitted registration](../../tools/experiments/mat003_continuation/wclear-admitted-registration.json).
This is an independent agent review, not an owner approval or a claim of human
peer review. The user requested independent admission and workflow preparation,
with a stop before dispatch until the owner authorizes the exact registration.

The registration has `formal_timing_admitted=true`,
`execution_authorized=false`, and `performance_accepted=false`. The
[new workflow](../../.github/workflows/mat003-wclear-timing.yml) is manual-only.
No authority receipt was fabricated, no workflow was dispatched, and no timing
binary was executed during this admission. Accepted S2A evidence, its 224-process
campaign and draft PR #211 remain unchanged. Packed and C128 timing, S2B,
production migration and GEN-006 remain outside this admission.

## Immutable evidence and independent verification

The evidence is [untimed run 39885505290](https://github.com/techrote/cybersand/actions/runs/39885505290),
artifact `12472344560`, archive size **17,442,801 bytes**, SHA-256
`fd3e269812bfadd737f38c2cabafd906efb15ea407cb2d4c70a820279179b0c5`.
Its exact hosted checkout is `f7c80a47da8bd1c87ac84b2f7281120a4fcc0796`;
the corresponding reviewed branch source is
`c7d7bf6f3c085f68332c30384c9742dd0ca55f93`. The new admission/workflow files
were prepared from branch `codex/mat003-continuation` at recoverable source
checkpoint `73fd80acf7f581e93939b3a48b7cb7a0ce1c5af7`. They do not rebuild or
change the admitted binaries.

The independent reviewer verified exact ZIP/extraction equality for all 3,114
files, no duplicate members, clean ZIP integrity, and identical before/after
file-hash inventories with no new files. Fresh readers exited zero with empty
stderr and no errors: S2P 5 cases/762 files; WCLEAR 208 cases/1,984 files; C128
4 cases/360 files. The three reports all returned
`qualification-readback-passed-timing-held`. The command for each track was:

```text
python -B tools/experiments/mat003_continuation/verify.py build/mat003-continuation/hosted-39885505290/<track> --source-commit f7c80a47da8bd1c87ac84b2f7281120a4fcc0796
```

This was readback of retained semantic evidence on the Windows review host, with
no simulation or timing invocation. The source-bound native runtime evidence
was collected on GitHub-hosted Ubuntu 24.04, GCC
`13.3.0-6ubuntu2~24.04.1`, using the frozen S2A flags. Failed and superseded
qualification attempts remain in the [continuation audit](2026-10-23-mat003-continuation.md).
They were not rewritten or selectively accepted.

| Sealed item | SHA-256 |
|---|---|
| WCLEAR inventory | `aec240e7f4f01dceba518d91394287c13da70efc439e328b15d0fd661b1c1f2f` |
| Embedded independent WCLEAR readback | `73654d6b5cca7c8facf9c8990db6e0db78562544767c595c98ae981ac237709c` |
| WCLEAR source seal | `4d9f21136fe8c6d043fd61939922186680cb888a68d6c01346fb05eda93c7f58` |
| WCLEAR binary seal | `72a2b5ce449f905e26b1e28a3d0b464b56eec989e1d66bd94653c4cd04ad4d17` |
| Frozen qualification reader | `38f05365daf8314a77bf7efc8d6be3dc798fe79bfd7a4bf2506cbee900c209ce` |
| Frozen timing collector | `52ee2ae651e9cc67ec74bed301f1cb0d34f8341ad4dfc66207376e4d5566f236` |
| Frozen timing reader | `ad3a53c856662408e931437cc14db6309b56add7192ad8928a02304396d069d2` |
| Admitted registration | `844dc51bd6c83f96b8827285d50be95d6612a048539ce3a480f6082486ac48b3` |
| Manual-only workflow | `92b953d00c12e1e8d45144ad35263623d7b507d8421b90565ca5d521acfe968f` |

## Why this protocol is admissible

The qualified matrix contains 192 resident cases and 16 small natural controls,
across eight observer-off/observed binaries. It verifies all pre/post/re-entry
semantic bytes, state and temperature, Water/Sand ledgers, scheduling and support,
raw epoch transitions, and actual all-resident clear witnesses in observed twins.
The four-worker active event witnesses recorded 12/24/48 background tasks at
resident sides 512/1024/2048 for every epoch width. Observer-off twins match.
All cases are explicitly untimed, with no latency observation fields.

The admission fixes 48 contexts: E8/E16/E24/E32 Ã— three resident sides Ã— two
scenes Ã— one/four configured workers. Each context has seven fresh-process pairs
in `AB, BA, AB, BA, AB, BA, AB` order. A is the matched ordinary tick; B is
the natural E8 or prepared wide clear tick. Exactly one primary tick is observed
per process, for 672 processes overall. The primary result is observer-off
`World::tick()` nanoseconds, with startup/setup/input costs and whole-process
peak RSS retained separately. There is no new compilation during timing.

The same real clear loop is exercised for every width. Correctness witnesses
are excluded at compilation from timed binaries. Timing-mode semantic streams
must match the qualified observer-off streams exactly. Every registered process,
spike and failure is retained. An incomplete matrix fails; a successful reader
still leaves performance acceptance held for separate review.

## Scientific limits and permitted interpretation

**Approved only for the frozen prepared-resident protocol.** Complete semantic
pre-scans, stamp preparation and pre-record output condition memory immediately
before the measured tick. Natural E8 preserves its stamps; matched ordinary and
wider prepared arms rewrite stamps. These store/cache histories are part of the
registered contrast. The paired excess is consequently a conditional protocol
contrast, not an instrumented isolated clear-loop cost. Direct event-inclusive
latencies can be reported with these conditions attached. The data cannot by
itself attribute a cross-width difference exclusively to the clear instruction
sequence or infer general cold-gameplay behavior.

The primary E8 event is natural at tick 256. Primary E16/E24/E32 events are
prepared. Natural E8/E16 controls at tick 65,536 validate the preparation
semantics; they do not supply measured wide-epoch natural-rollover latency.
Preparation preserves current predicates and qualified consumers while
deliberately collapsing stale labels, so it does not reconstruct the full raw
epoch history.

The 16-byte C80-aligned stride is common to all four widths. The resident carrier
address spans are 4/16/64 MiB at 512Â²/1024Â²/2048Â². These are cell-array spans,
not measured cache/bus traffic; process RSS includes other World allocations,
semantic buffers and re-entry. Four configured workers are qualified through
observed twins; timed processes do not directly count background participation.
4096Â², other carriers, other platforms and a direct clear-loop timer are excluded.

Statistics use seven independent process pairs per context. Minimum, median,
maximum and MAD preserve all values, including negative paired excess. Nearest
rank p95/p99 equal the observed maximum for N=7 and are descriptive, without a
population-tail or worst-gameplay guarantee. Any amortized calculation remains
conditional on the measured ordinary cost, paired event contrast, resident size
and first/subsequent rollover intervals. E24/E32 projections are modelled long-run
behavior, not directly observed natural timing.

## Manual execution gate and next action

**STOP: owner execution authority is pending.** The new workflow validates the
exact registration hash and its own source hash before downloading apparatus or
running a collector. It accepts only an owner-established JSON receipt supplied
through `workflow_dispatch` input. The authenticated actor must be the repository
owner; the receipt must identify that actor and authorize this exact registration,
campaign, scientific scope and dispatched commit. Duplicate JSON keys, absent or
mismatched receipts, changed inputs and workflow reruns fail closed. All input
values enter Python through environment variables, without shell interpolation.

After the owner explicitly authorizes the exact registration and execution
commit, the receipt must contain these fields with actual owner-approved values:
`execution_authorized` (boolean true), `approver`, `registration_sha256`,
`decision` (`authorize-exact-registered-campaign`), `campaign_id`
(`WCLEAR-001-672-001`), `scope_acknowledged`
(`prepared-resident-protocol-v1`), and `execution_commit`. No such receipt is
created by this admission. Store the genuine receipt in
`OWNER-APPROVED-WCLEAR-AUTHORITY.json` only after that authorization.

The following PowerShell command is the future manual action, **not an instruction
to run it now**. Its branch tip must equal the owner-approved `execution_commit`;
any intervening change makes the receipt fail validation.

**Planned workflow publication prerequisite:** GitHub documents that
`workflow_dispatch` requires the workflow on the default branch; an already run
workflow can subsequently be dispatched on another ref. See the official
[manual-run guide](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
and [dispatch reference](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch).
This newly prepared manual-only workflow has not been published or run. Its
approved publication/registration must precede the command below. Admission
does not authorize a default-branch merge, an automatic trigger workaround or
merging the stacked PRs. Until publication and owner authority are complete,
there is no executable dispatch action.

```powershell
gh workflow run mat003-wclear-timing.yml --repo techrote/cybersand --ref codex/mat003-continuation --field "registration_sha256=844dc51bd6c83f96b8827285d50be95d6612a048539ce3a480f6082486ac48b3" --field "owner_authority_json=$(Get-Content -Raw -LiteralPath 'OWNER-APPROVED-WCLEAR-AUTHORITY.json')"
```

The workflow uses pinned actions and GitHub-hosted Ubuntu 24.04. A second checkout
of the exact qualified source supplies frozen readers and collector, avoiding any
current admission/test-file drift. It verifies the immutable artifact, reruns the
208-case independent readback, and retains all raw observations and failure
evidence for 90 days. The collector has a 7,200-second wall budget and 120-second
process timeout; the job allows 210 minutes for validation, collection, independent
readback and upload. A failed campaign remains failed. Any replacement needs a
separate recorded review disposition; no selective rerun or outlier removal is
admitted.

The implementation owner integrates documentation routes, runs repository/docs/
retrieval checks, and records the recoverable workflow commit before requesting
owner authority. No merge or ready-for-review action for PR #211 is authorized.

## Admission-source validation

On 2026-10-23 the workflow parsed with isolated PyYAML 6.0.3 `BaseLoader`:
the sole trigger is `workflow_dispatch`, the runner is literal GitHub-hosted
Ubuntu 24.04, the job budget is 210 minutes, and final upload uses `always()`
with 90-day retention. All three embedded Python blocks compiled. Six isolated
negative preflight cases rejected missing authority JSON, an empty receipt,
an explicitly false decision, duplicate JSON keys, a mismatched registration
hash and a non-owner actor. None created an accepted authority file or timing
output directory. The tests supplied no affirmative owner authority and invoked
no collector or timing binary.

The CI-provider policy check, all ten continuation contracts and the documentation
checker passed. `git diff --check` passed. These are source/configuration checks;
they do not establish that the new workflow has been published or executed.
