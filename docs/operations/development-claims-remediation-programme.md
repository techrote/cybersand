---
title: Development claims remediation programme
status: Current
document-kind: design
scope: Canonical F01-F19 remediation routing, claim-state rules, dependencies and exit criteria for issues #79-#87 plus existing #49
canonical-for: [development-claims-remediation-programme]
last-reviewed: 2026-09-20
related-documents: [../audits/2026-09-20-development-claims-closure-audit.md, ../reference/status-and-roadmap.md, cybersand-codex-development-handover.md, current-and-historical-validation.md, soliding-stage3b-production-plan.md]
---

# Development claims remediation programme

This is the Current programme authority created by #80 / REM-001 under parent
#79. Use it to answer "what is actually complete?", "which result is historical
but still valid?", "who owns the repair?" and "what may run concurrently?".

The dated [2026-09-20 closure audit](../audits/2026-09-20-development-claims-closure-audit.md)
is the immutable intake record. Executable source and accepted ADR/contracts
remain runtime authority. Each remediation child owns only its stated repair
scope; this programme owns orchestration and claim-state truth.

## State vocabulary

Do not collapse work into a single completed/not-completed bit.

| State | Required meaning |
|---|---|
| Implemented | The intended implementation exists in an identified source. |
| Integrated | It exists in authoritative current main, not only a historical branch/commit. |
| Verified | Required automated/measurement gates passed against identified source/artifacts and their actual preconditions. |
| Accepted | Required owner/human behavioural or usability acceptance passed for the intended envelope. |
| Dispositioned | Remaining limitations, rejection/no-go branches and downstream owners are explicit. |

A bounded historical pass can remain valid while Integrated or Accepted is false.
Closing a GitHub issue is not independent evidence for any of these states.

## Initial RAG and ownership

RAG describes remediation state, not severity of the original subsystem.

| Finding | RAG after REM-001 routing | Current interpretation | Owner / prerequisite |
|---|---|---|---|
| F01 #11 repair missing from main | Red | Historical bounded repair valid; audited main lacks it. | #81, then #83 for broader behaviour |
| F02 broad #10/#11 acceptance overclaim | Red | Bounded evidence retained; later owner gameplay acceptance failed. | #82 player; #81 -> #83 body; #8 umbrella |
| F03 premature closure semantics | Amber | Historical incident retained; process control still missing. | #86 |
| F04 formal Water H blinding | Red | #19 simulation/presentation evidence valid; formal blind capture not ready. | #84 |
| F05 append-only H evidence | Red | Formal observation durability incomplete. | #84 |
| F06-F11 #26 successor apparatus | Red | Exact candidate rejections stand; apparatus v1 cannot govern #45 acceptance. | existing #49 -> #45 |
| F12 platform evidence vocabulary | Amber | Specific #26 correction landed; repository-wide current truth still needs sweep. | #85 |
| F13 MS-001 corrected historical interpretation | Amber | Corrections are retained; guard against stale present-tense reversion. | #85 |
| F14 #12 Stage-3A overclosure | Amber | #12 is open; Stage 3B active; Stage 4 blocked. | #85 guard; #12/#56-#70 execute |
| F15 current Cell-size commentary | Red | Source-qualified current carrier and dated experiment claims must be separated. | #85 |
| F16 unsupported-vs-zero counters | Red | Availability must not masquerade as measured zero. | #85 |
| F17 implementation ownership collision | Red | One active owner/write set must be discoverable before edits. | #86 |
| F18 validation precondition loss | Amber | Historical parity-runner incident repaired; durable premise receipts still absent. | #86 |
| F19 stale current routing | Amber | REM-001 fixes central routes; #85 performs the remaining truth sweep. | #80 then #85 |

Nothing becomes Green solely because this table exists. #87 is the independent
exit audit and must inspect current evidence rather than inherit child self-ratings.

## Dependency graph

```text
#80 REM-001 authority/RAG
 ├─> #81 REM-002 #11 integration --------> #83 REM-004 broad body/granular
 ├─> #82 REM-003 broad player/granular
 ├─> #84 REM-005 formal Water H capture
 ├─> #49 existing Water apparatus --------> #45 Water head successor
 ├─> #85 REM-006 current-truth/platform/counter sweep
 └─> #86 REM-007 closure/ownership/validation controls

#81 + #82 + #83 + #84 + #49 + #85 + #86
                         |
                         v
                    #87 REM-008
                         |
                         v
                    parent #79
```

#45 is downstream of #49 but is not itself a prerequisite for closing #79 unless
a later parent decision explicitly changes that rule. The remediation programme
must not absorb #45's Water architecture work.

## Tracker reconciliation

### #8 umbrella

Keep #8 open. Its Current meaning is:

- #9 completed a scoped characterization campaign whose measurements remain valid
  at their recorded identity;
- #10 completed a bounded policy/fixture checkpoint, but broad player/granular
  gameplay acceptance is open and owned by #82;
- #11 completed a bounded historical repair checkpoint, but current-main
  integration is owned by #81 and broad body/granular gameplay acceptance by
  #83;
- #12 is a separately promoted scalable-soliding programme and is not the sole
  remaining reason #8 is open.

Old comments that describe #8 as waiting only on #12 are retained as historical
records, not current routing.

### #10 and #11 issue state

REM-001 reopens #10 and #11 because `closed/completed` is misleading for their
original broad behavioural objectives after the later owner evaluation. Reopening
does not retract their bounded dated evidence and does not create duplicate
implementation lanes.

#10 is now an evidence/objective anchor; active current-main player/granular work
belongs to #82.

#11 is now an evidence/objective anchor; #81 owns reconstruction/integration of
the accepted bounded repair into current main, and #83 owns the broader
body/granular gameplay envelope after #81.

### #12 Stage 3B

#12 remains open and independent. At REM-001 publication, #56-#60 and #69 are
complete, #61 is the serialized central World producer owner, #62/#63 follow it,
and #64 is the separable graph/index lane after #60/#59. #65 is the join. Stage 4
remains blocked until the parent admits Stage 3B after #70.

### #30 / INT-000

#30 remains an open tracker, not an execution prerequisite. #27/MS-000,
#28/MS-001 and #29/INT-000 infrastructure are landed; #29/PR #55 merged as
`910717aac101363ec2b1b89e4041a22bc9a97b97`. Future interaction tuning is
bounded, versioned follow-on work, not unfinished #29 infrastructure.

## Historical evidence rules

Do not repair current truth by editing old evidence to match it.

- #9's measured baseline remains scoped to its original source/artifacts.
- #10's policy/evidence remains a valid bounded checkpoint.
- #11's `d5f0de6` evidence and `f8720d3` accepted code checkpoint remain
  historical proof even though audited current main lacks the repair.
- #19's engine/presentation/harness evidence remains valid; only formal blind
  study readiness is withdrawn pending #84.
- #26's two rejected local candidates remain rejected under their frozen gates;
  #49 versions successor apparatus rather than altering the archive.
- MS-001 post-merge corrections and #12's later programme promotion qualify
  earlier claims without deleting the earlier record.

Current documents may link these records, but must state source/artifact/platform
and later qualification where it affects the answer.

## Concurrency and stop-on-collision

Do not freeze CyberSand globally for remediation work. Determine concurrency from
the live owner and actual write set.

The Stage-3B production plan serializes #61-#63 because they touch central World
mutation/activity/event paths. #64 is primarily graph/index work and may run in
parallel when its real write set remains disjoint. #81 is expected to touch body
coupling and may touch native World tests or helper semantics; it must inspect the
live #61/#62/#63 branch/PR before editing. #82/#83 similarly inspect current
player/body/native/test owners instead of assuming a historical branch is safe.

If an active implementation owner overlaps materially and the child issue does
not already define reconciliation, stop under the child's blocker rule. Do not
create a second implementation, silently rebase ownership away or pause an
unrelated programme by policy fiat.

## Child exit criteria

| Work | Required exit from the remediation programme |
|---|---|
| #81 REM-002 | Historical #11 repair reconstructed/reconciled against current main; no silent semantic drift; source-matched tests/evidence; exact integration identity; no broad gameplay acceptance claim. |
| #82 REM-003 | Current player/granular behaviour characterized/redesigned within its authority; relevant automated coverage and explicit owner gameplay acceptance or explicit rejected/no-go disposition. |
| #83 REM-004 | Starts after #81; current body/granular envelope tested beyond the historical ordinary rectangle case; explicit owner gameplay acceptance or explicit rejected/no-go disposition. |
| #84 REM-005 | Formal blind-study arm identity inaccessible to the operator during capture; observations retained append-only with reconstructible post-reveal provenance; #19 simulation/presentation semantics unchanged. |
| #49 existing | Versioned corrected Water metrics/fixtures/runner, adversarial regressions, fresh Current-Water baseline and honest active/sleep/censoring evidence; old #26 archive untouched. |
| #85 REM-006 | Current docs/source/platform/counter truth reconciled, including current carrier size, unsupported-vs-zero semantics and stale programme summaries; corrected historical incidents preserved. |
| #86 REM-007 | Repository-native multidimensional closure state, one active implementation owner/write set convention, validation-precondition receipts and stop-on-blocked rules are enforceable/retrievable. |
| #87 REM-008 | Independent exact-head audit maps every F01-F19 item to Fixed, Historically qualified, or Remaining limitation with an explicit owner; checks current source/evidence rather than trusting child closure. |

A child may finish with an evidence-backed no-go if its issue allows that outcome.
It may not manufacture a pass by weakening its intended behavioural objective.

## Water boundary

#49 is the sole corrective owner for F06-F11. REM-001 does not reopen #26 and
does not copy its corrective scope into a new issue.

The affected Water architecture path remains:

`#49 -> #45 -> directional-reference reassessment -> #18 G-M admission/no-go -> #20/G-B if justified -> #14 G-final`.

#84 formal H-record integrity is separate from #49's head-transmission apparatus.
Neither is permission to change Water semantics under REM-001.

## Retrieval and evidence use

For current claim/closure questions, retrieve this programme first. For the
frozen intake finding details, retrieve the dated audit explicitly. Then follow
the subsystem contract and dated evidence for technical claims.

For runtime/platform claims, use
[validation-evidence.md](../reference/validation-evidence.md) and
[current-and-historical-validation.md](current-and-historical-validation.md).
A cross-build, native test, Godot runtime, browser execution, rendered-pixel test,
performance result and owner acceptance remain distinct evidence categories.

## Parent and REM-008 closure rule

Parent #79 must remain open until #87 has independently verified all required
children (#81/#82/#83/#84/#49/#85/#86) and current repository state.

#87 must produce an exact-head exit packet that:

- maps F01-F19 individually;
- names source/PR/issue/evidence identity for every fixed item;
- leaves real limitations open with an owner instead of converting them to prose
  "known limitations";
- confirms #8/#10/#11 tracker state still matches current evidence;
- confirms no historical evidence was rewritten to obtain consistency;
- confirms required documentation, repository, historical-integrity, retrieval
  and applicable runtime guards pass on the exact reviewed head;
- states whether #79 may close.

Only that independent review may recommend parent closure.
