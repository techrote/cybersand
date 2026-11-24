---
title: Development claims remediation programme
status: Current
document-kind: design
scope: Canonical F01-F19 remediation routing, claim-state rules, dependencies and exit criteria for issues #79-#87 plus existing #49
canonical-for: [development-claims-remediation-programme]
last-reviewed: 2026-11-24
related-documents: [../audits/2026-09-20-development-claims-closure-audit.md, ../reference/status-and-roadmap.md, cybersand-codex-development-handover.md, current-and-historical-validation.md, soliding-stage3b-production-plan.md]
---

# Development claims remediation programme

This is the canonical F01–F19 remediation contract created by #80 / REM-001
under parent #79. It preserves that programme's claim-state definitions, original
routing and exit criteria. For project-wide current work, start with the
[current state register](../reference/status-and-roadmap.md) and
[handover](cybersand-codex-development-handover.md), then use this page for the
specific remediation finding and its evidence.

The dated [2026-09-20 closure audit](../audits/2026-09-20-development-claims-closure-audit.md)
is the immutable intake record. Executable source and accepted ADR/contracts
remain runtime authority. Each remediation child owns only its stated repair
scope; this programme does not grant new implementation or issue-write authority.

**Live tracker snapshot, 24 November 2026:**
[#79](https://github.com/techrote/cybersand/issues/79), #80, #81, #84, #85 and
[#87](https://github.com/techrote/cybersand/issues/87) are closed; #82, #83 and #86
remain open. The parent body still contains its September “remains open” wording.
That mismatch is retained evidence, not an instruction to reopen the parent or
an independent certification that every repair passed. The original RAG below
has not been silently recoloured from issue state. A current F01–F19 certification
requires the exact-source exit evidence and explicit remaining limitations;
issue closure alone does not establish owner acceptance or fulfilled exit gates.
The [original page](../audits/2026-11-24-docs-renaissance/preserved/docs__operations__development-claims-remediation-programme.md.txt)
is preserved byte for byte.

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

This table records the **20–25 September 2026 remediation checkpoint**, not a
fresh rating of accepted main. “Current” and “pending” within its rows refer to
that checkpoint. In particular the F04/F05 formal-capture, F15 carrier and F19
routing rows must not override later source or the live tracker snapshot above.
RAG describes the registered remediation state, not subsystem severity.

| Finding | RAG after REM-001 routing | Interpretation at the September checkpoint | Original owner / prerequisite |
|---|---|---|---|
| F01 #11 repair missing from main | Amber pending #87 | REM-002 reconstructed the divergence as a never-integrated branch and reconciles the still-valid masked-source, barrier/foreign-mask ejection and bounded granular-bearing semantics on current source with source-matched runtimes. This is integration repair, not broad owner gameplay acceptance. | #81 satisfied on implementation/verification; #83 owns broader behaviour; #87 independently certifies |
| F02 broad #10/#11 acceptance overclaim | Amber | #82 has a source-matched bounded sampled-player C1 engineering candidate with native/fallback and real-Web evidence; explicit owner gameplay acceptance/disposition remains open. #81 supplies the bounded generic-body baseline and #83 still owns broad body/granular acceptance. | #82 player owner-review gate; #81 -> #83 body; #8 umbrella |
| F03 premature closure semantics | Amber | Historical incident retained; process control still missing. | #86 |
| F04 formal Water H blinding | Red | #19 simulation/presentation evidence valid; formal blind capture not ready. | #84 |
| F05 append-only H evidence | Red | Formal observation durability incomplete. | #84 |
| F06-F11 #26 successor apparatus | Amber | #49 v2 correction and source-matched Current-Water baseline are available; apparatus v1 remains historical and #26's exact candidate rejections stand. Independent #87 exit audit is still required before REM marks the finding Green. | #49 satisfied; #87 verifies |
| F12 platform evidence vocabulary | Amber | Specific #26 correction landed; repository-wide current truth still needs sweep. | #85 |
| F13 MS-001 corrected historical interpretation | Amber | Corrections are retained; guard against stale present-tense reversion. | #85 |
| F14 #12 Stage-3A overclosure | Amber | #12 is open; Stage 3B active; Stage 4 blocked. | #85 guard; #12/#56-#70 execute |
| F15 current Cell-size commentary | Red | Source-qualified current carrier and dated experiment claims must be separated. | #85 |
| F16 unsupported-vs-zero counters | Red | Availability must not masquerade as measured zero. | #85 |
| F17 implementation ownership collision | Red | One active owner/write set must be discoverable before edits. | #86 |
| F18 validation precondition loss | Amber | Historical parity-runner incident repaired; durable premise receipts still absent. | #86 |
| F19 stale current routing | Amber | REM-001 fixes central routes; #85 performs the remaining truth sweep. | #80 then #85 |

Nothing becomes Green solely because this table exists or an issue closes.
The registered #87 independent exit review required direct current evidence,
not inherited child self-ratings. Its closed tracker does not turn this retained
table into a fresh certification.

## Dependency graph

This is the original REM dependency graph. Live open/closed state is recorded above; an unfinished product acceptance issue may remain explicitly open after a bounded remediation disposition.

```text
#80 REM-001 authority/RAG
 ├─> #81 REM-002 #11 integration --------> #83 REM-004 broad body/granular
 ├─> #82 REM-003 broad player/granular
 ├─> #84 REM-005 formal Water H capture
 ├─> #49 existing Water apparatus v2 -----> #87 independent exit audit
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

As checked on 24 November 2026, #8 is open. The original REM reconciliation distinguished:

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

REM-001 recorded why #10 and #11 were reopened: `closed/completed` overstated
the original broad behavioural objectives after owner evaluation. Both trackers
are open in the 24 November snapshot. This is a retained reconciliation record,
not a fresh instruction to change issues; it does not retract bounded dated
evidence or establish duplicate implementation lanes.

#10 is now an evidence/objective anchor; active current-main player/granular work
belongs to #82.

#11 remains an evidence/objective anchor. REM-002 / #81 has now reconstructed
the historical divergence and reconciled the still-valid bounded generic
body↔cellular repair on current source; the
[REM-002 forensic/current evidence](../audits/2026-09-24-rem002-issue11-integration-forensics.md)
is the canonical record. #83 owns the broader body/granular gameplay envelope and
explicit owner acceptance. The barrel remains a generic Rapier reference body;
remediation must not create a barrel-specific support subsystem.

### #12 Stage 3B

#12 remains open and independent. The recovery programme has now completed the
producer/reconstruction chain through #65: #56-#65 and #69 are complete, and
#65 / PR #106 landed as
`cdf0a0874d4732c41273e10d921bcd5feaac3e3c` with exact-head and landed-main
validation plus source-matched retained runtimes. At that September checkpoint, #66 was the next dependency-ready package,
followed by #67, #68 and #70; Stage 4 was not admitted. For present ownership and
the later independent #12 tracks, use the [soliding programme](soliding-programme.md).
Do not resume an old branch or infer a current implementation order from this
remediation checkpoint.

### #30 / INT-000

#30 is closed in the 24 November 2026 live snapshot; its retained programme is not an execution prerequisite or proof every proposed showcase shipped. #27/MS-000,
#28/MS-001 and #29/INT-000 infrastructure are landed; #29/PR #55 merged as
`910717aac101363ec2b1b89e4041a22bc9a97b97`. Future interaction tuning is
bounded, versioned follow-on work, not unfinished #29 infrastructure.

## Historical evidence rules

Do not repair current truth by editing old evidence to match it.

- #9's measured baseline remains scoped to its original source/artifacts.
- #10's policy/evidence remains a valid bounded checkpoint.
- #11's `d5f0de6` evidence and `f8720d3` recorded code checkpoint remain
  historical proof of the bounded branch implementation/evidence; REM-002 shows
  that branch was never integrated rather than later regressed. Current source now
  has a reconciled bounded successor, but neither historical nor REM-002 evidence
  is owner acceptance of final body physics.
- #19's engine/presentation/harness evidence remains valid within its source scope. The September review withdrew formal blind-study readiness pending #84; that issue is now closed, which alone neither requalifies the apparatus nor supplies an owner preference result.
- #26's two rejected local candidates remain rejected under their frozen gates;
  #49 versions successor apparatus rather than altering the archive.
- MS-001 post-merge corrections and #12's later programme promotion qualify
  earlier claims without deleting the earlier record.

Current documents may link these records, but must state source/artifact/platform
and later qualification where it affects the answer.

## Concurrency and stop-on-collision

Do not freeze CyberSand globally for remediation work. Determine concurrency from
the live owner and actual write set.

The Stage-3B central-World producer sequence through #65 is landed. REM-002's
September inspection found no active owner collision in the then-planned
#66 -> #67 -> #68 -> #70 chain. That finding applies only to its recorded
write set and date, not to current ObjectShard or other engineering branches.
Use the [current soliding programme](soliding-programme.md) and actual open PR
write sets before selecting work. #82/#83 must still inspect
current player/body/native/test owners before editing rather than assuming the
REM-002 or historical branch write set remains free.

If an active implementation owner overlaps materially and the child issue does
not already define reconciliation, stop under the child's blocker rule. Do not
create a second implementation, silently rebase ownership away or pause an
unrelated programme by policy fiat.

## Child exit criteria

These are the original REM contracts. “Satisfied” below refers to the identified September source/evidence, not a re-run at current main. The live tracker snapshot and each issue's disposition are separate from these requirements.

| Work | Required exit from the remediation programme |
|---|---|
| #81 REM-002 | **Satisfied on this source:** historical #11 divergence reconstructed as never-integrated; bounded masked-source/ejection/bearing semantics reconciled; focused current-source tests plus Native/Godot/Water guards pass; source-matched retained runtimes published; broad gameplay acceptance explicitly remains #83. #87 still independently verifies the landed result. |
| #82 REM-003 | Current player/granular behaviour characterized/redesigned within its authority; relevant automated coverage and explicit owner gameplay acceptance or explicit rejected/no-go disposition. |
| #83 REM-004 | Starts after #81; current body/granular envelope tested beyond the historical ordinary rectangle case; explicit owner gameplay acceptance or explicit rejected/no-go disposition. |
| #84 REM-005 | Formal blind-study arm identity inaccessible to the operator during capture; observations retained append-only with reconstructible post-reveal provenance; #19 simulation/presentation semantics unchanged. |
| #49 existing | **Satisfied on the implementation side:** versioned corrected Water metrics/fixtures/runner, adversarial regressions, fresh source-matched Current-Water baseline and honest active/quiescent/censoring evidence; old #26 archive untouched. #87 still verifies the landed repair independently. |
| #85 REM-006 | Current docs/source/platform/counter truth reconciled, including current carrier size, unsupported-vs-zero semantics and stale programme summaries; corrected historical incidents preserved. |
| #86 REM-007 | Repository-native multidimensional closure state, one active implementation owner/write set convention, validation-precondition receipts and stop-on-blocked rules are enforceable/retrievable. |
| #87 REM-008 | Independent exact-head audit maps every F01-F19 item to Fixed, Historically qualified, or Remaining limitation with an explicit owner; checks current source/evidence rather than trusting child closure. |

A child may finish with an evidence-backed no-go if its issue allows that outcome.
It may not manufacture a pass by weakening its intended behavioural objective.

## Water boundary

#49 is the sole corrective owner for F06-F11. REM-001 does not reopen #26 and
does not copy its corrective scope into a new issue.

The remediation implementation requirement is now supplied by #49's corrected v2
apparatus and source-matched
[Current-Water baseline](../audits/2026-09-20-issue-49-water-apparatus-v2-baseline.md).
F06–F11 were retained Amber in the September table pending #87 independent verification; this preserved rating is not a current failure verdict or a new certification.
The original broader Water research routing was recorded in the independent
[WEX programme](water-hybrid-pressure-extension-programme.md):

`#49 apparatus || WEX evidence -> #95 synthesis -> #45 proceed/narrow/recharter/defer/no-go -> directional reassessment -> #18 G-M admission/no-go -> #20/G-B if justified -> #14 G-final`.

This retained sequence is historical research admission, not a prohibition on
accepted [Water families](../architecture/liquid-solver-family-policy.md) or
[ballistic Water](../architecture/ballistic-water-v1.md). #14/#18/#20/#49/#95 are closed
and #45 is open in the 24 November snapshot; current source and each accepted
contract establish implementation availability. Closing these trackers does not
retroactively change #26's negative results or select a new #45 design.

WEX #90-#95 are not new #79 closure prerequisites unless the remediation parent is
explicitly amended later; they are architecture research. #84 formal H-record
integrity is also separate from #49's head-transmission apparatus. None of these
lanes is permission to change Water semantics under remediation authority.

## Retrieval and evidence use

For project-wide current claim/closure questions, retrieve the
[current state register](../reference/status-and-roadmap.md) and current
[release/claim guidance](github-development-and-release.md) first. Retrieve this
programme for the F01–F19 contract and original remediation ownership. Consult
the frozen intake audit only deliberately; follow the current subsystem
contract and source-matched evidence for technical claims.

For runtime/platform claims, use
[validation-evidence.md](../reference/validation-evidence.md) and
[current-and-historical-validation.md](current-and-historical-validation.md).
A cross-build, native test, Godot runtime, browser execution, rendered-pixel test,
performance result and owner acceptance remain distinct evidence categories.

## Parent and REM-008 closure rule

The original closure rule required #87 to independently verify the required
child scopes (#81/#82/#83/#84/#49/#85/#86) and the exact repository state before
recommending parent closure. The live #79/#87 trackers are now closed while
#82/#83/#86 remain open. Do not infer that all product acceptance work completed,
or reopen/close issues from this old requirement. Resolve any disputed current
certification from the exit packet and explicit remaining-owner dispositions.

The registered #87 exit packet must:

- maps F01-F19 individually;
- names source/PR/issue/evidence identity for every fixed item;
- leaves real limitations open with an owner instead of converting them to prose
  "known limitations";
- confirms #8/#10/#11 tracker state still matches current evidence;
- confirms no historical evidence was rewritten to obtain consistency;
- confirms required documentation, repository, historical-integrity, retrieval
  and applicable runtime guards pass on the exact reviewed head;
- states whether #79 may close.

Only an independent review satisfying that evidence contract can support its closure recommendation; this documentation reconciliation supplies no new issue-action or merge authority.
