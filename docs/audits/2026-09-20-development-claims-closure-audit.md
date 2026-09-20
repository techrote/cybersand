---
title: Development claims and closure audit, 2026-09-20
status: Current
document-kind: evidence
scope: Immutable REM-001 audit of overclaimed completion, stale current routing and evidence-boundary defects at main e87ac544; no runtime or physics acceptance campaign
canonical-for: []
last-reviewed: 2026-09-20
related-documents: [../operations/development-claims-remediation-programme.md, ../reference/status-and-roadmap.md, ../reference/validation-evidence.md, ../operations/current-and-historical-validation.md]
---

# Development claims and closure audit — 2026-09-20

This is the dated intake audit for issue #80 / REM-001. It records what was true
at authoritative `main` commit
`e87ac54459a3a62350fa7aa3da6ce979c30a18b8` before the remediation programme
changed tracker state. It is historical evidence after publication: later work
must add new evidence or update the Current remediation programme rather than
rewrite this record.

The audit distinguishes a bounded implementation/test result from current-main
integration, broad gameplay acceptance and programme completion. No fresh physics
campaign, Water experiment, human preference study or Stage-3B performance
campaign was run for this audit.

## Audit method and source boundary

The review read parent issue #79, issue #80 and their referenced issue chain,
including #8-#12, #14, #18-#20, #26, #30, #45, #49 and #56-#70. It reconciled
their live GitHub state with the canonical roadmap, development handover,
architecture/MicroScenarios/soliding programmes, validation ledger and the
historical #9/#10/#11/#19/#26 evidence.

Relevant current source was inspected only where necessary to separate historical
acceptance from current-main truth. In particular, current
`godot/native_extension/cyber_native_cell_world.cpp` still contains the legacy
rectangle overlap/ejection/contact path and no #11 granular-bearing implementation.
Its current ejection target search checks an empty destination but not the
historical #11 repair's bounded intervening hard-surface/body-mask path.

The #11 completion audit is not present in the current-main documentation tree.
It remains available in Git history at evidence commit
`d5f0de687283ec366ed4ff33160a274e2a35ddc6`; the accepted implementation
checkpoint recorded there is `f8720d331e653ff40c12149dc1b7164724accd9f`.
That historical evidence was read rather than inferred from issue state.

At audit intake:

- #8, #12, #14, #18, #20, #30, #45, #49 and the unfinished Stage-3B children
  were open;
- #9, #10, #11, #19, #26, #27, #28, #29 and Stage-3B #56-#60/#69 were closed;
- PR #55 / #29 had already merged as
  `910717aac101363ec2b1b89e4041a22bc9a97b97`;
- current main already contained #60 / PR #78, so #61 was the next serialized
  central-World producer package and #64 was the separable graph/index lane.

## Claim-state model used by the audit

A work item can have several independent states:

| Dimension | Meaning |
|---|---|
| Implemented | The intended change exists in some identified source. |
| Integrated | The intended change exists in the authoritative current-main lineage. |
| Verified | Required automated/measurement gates pass for an identified source, artifact and scope. |
| Accepted | The relevant owner/human acceptance gate has passed for the intended behavioural envelope. |
| Dispositioned | Any remaining limitation, rejection or no-go is explicitly recorded and owned. |

A GitHub state of `closed/completed` cannot substitute for any missing dimension.
Likewise, a valid historical fixture result is not invalid merely because broad
acceptance later failed.

## Findings F01-F19

| ID | Intake classification | Evidence boundary and corrected interpretation | Governing owner after REM-001 |
|---|---|---|---|
| F01 | Current integration defect | #11's 2026-09-13 source-matched repair validly demonstrated masked-source correction, bounded barrier/body-mask-aware ejection and ordinary rectangle/load bearing in its stated envelope. That implementation is absent from audited current main. Do not erase the result or claim current integration. | #81 REM-002 reconstructs/reconciles the accepted bounded repair into current main. |
| F02 | Closure/acceptance mismatch | #10 has substantial bounded policy/fixture evidence and its player/exchange policy remains part of current lineage. #11 has substantial bounded historical evidence. Later owner evaluation nevertheless judged the broader player/granular and rigid-body/granular gameplay materially below acceptable. #8 therefore cannot be represented as waiting only on #12. | #82 owns broad player/granular acceptance; #81 then #83 own body/granular integration and broad acceptance; #8 remains the umbrella truth anchor. |
| F03 | Process defect / historical closure incident | Earlier administrative completion compressed implementation, verification and acceptance into one state. The historical comments remain evidence of what was believed at the time; they are not current acceptance authority. | #86 REM-007 makes multidimensional closure and validation premises explicit. |
| F04 | Current formal-H integrity defect | #19 validly built and tested the Water simulation/presentation apparatus. Its 2026-09-12 audit explicitly allowed reconstructible mapping in machine export and called the apparatus H-ready, but no human preference study ran. The later closure audit rejects treating that export path as formal blind-study capture because operator-accessible evidence can reveal the hidden arm. | #84 REM-005 owns formal blind separation while preserving #19 simulation/presentation evidence. |
| F05 | Current formal-H durability defect | The Water Feel Lab's formal observation path does not provide the required append-only, independently attributable study record; repeated use can overwrite the fixed output. This does not invalidate #19's engine/harness tests. | #84 REM-005. |
| F06 | Current successor-apparatus defect | #26 v1 equilibrium can false-pass dry-column concentration or an empty ROI. The exact two #26 candidate rejections remain valid because they failed independent primary gates. | Existing #49 corrective owner; #45 remains blocked on it. |
| F07 | Current successor-apparatus defect | #26 v1 sustained-pass latching and numeric zero for an unreached threshold can overstate/contaminate successor evidence. Historical #26 archives remain unchanged. | #49. |
| F08 | Historical labelling defect / current successor requirement | The historical "unequal-head-u-tube" is a three-compartment communicating geometry, not a clean two-limb U-tube. Preserve it under its old identity; add/version a real two-limb control only in successor apparatus. | #49. |
| F09 | Historical interpretation overreach | #26 whole-run p95 mixed active/startup/sleep populations. The horizon candidate still did extra useless work without head benefit, but a universal approximately-600x active-tick interpretation is not justified. | #49 separates active/startup/sleep/total evidence. |
| F10 | Evidence-strength mismatch | #26 surface-defect values are sampled diagnostic proxies, not full rendered/lifetime acceptance or high-frequency shimmer proof. | #49 qualifies and versions successor measurements. |
| F11 | Evidence durability defect | #26's v1 runner can reuse output directories and relies on evidence-critical assertions without guaranteeing a durable record for every failed attempt. No corruption of retained #26 archives was found. | #49. |
| F12 | Current platform-claim hygiene defect | Build, cross-build, native runtime, Godot runtime, browser execution and rendered/performance evidence have been conflated in some status prose. The #26 post-merge review already corrected the specific Windows cross-build-versus-runtime claim. | #85 REM-006 performs the remaining current-truth/platform sweep. |
| F13 | Corrected historical incident requiring guard | MS-001's post-merge review corrected Flood endpoint wording, made the Stress distinct-world assertion effective and reconciled stale compact definition hashes without reopening its implementation. Those corrections are the retained interpretation. | #85 verifies current routing does not regress to the pre-correction wording. |
| F14 | Corrected historical incident requiring guard | #12 was once described as effectively complete after a bounded prototype/Stage-3 checkpoint. It is now an open scalable-soliding programme. Stage 3A is only the bounded correctness/reference checkpoint; Stage 3B locality/scalability is active and Stage 4 is blocked. | #85 guards present-tense programme truth; #12 and #56-#70 remain the implementation authority. |
| F15 | Current source/documentation mismatch | Present-tense "four-byte hot cell" wording cannot be treated as current-main physical carrier truth after the #19 superset integration. This audit does not select a representation or rewrite experiment history. | #85 reconciles current storage commentary against source-qualified storage authority. |
| F16 | Current evidence-semantics risk | Compatibility/telemetry fields can make unsupported/unavailable measurements look like measured zero if provenance and support state are not explicit. This audit does not redesign counters. | #85 inventories and corrects current counter semantics/documentation. |
| F17 | Process/ownership defect | Multiple historical lanes exposed duplicate or overlapping implementation authority. A branch/PR existing is not by itself proof of ownership, and issue-number ordering is not authority. | #86 defines one active implementation owner/write set and collision checks. |
| F18 | Validation-premise defect | A worker-parity gate can become meaningless if the runner no longer provides enough CPUs for the requested parallel arm. A later CI repair restored the required parity-owning shard capacity; the incident remains process evidence. | #86 records machine-readable validation preconditions/receipts and stop conditions. |
| F19 | Current routing/staleness defect | Current parent/status text lagged merged #29, the promoted #12 programme, the Stage-3B sequence and the owner rejection of broad #10/#11 gameplay acceptance. Conversational summaries then amplified the stale "completed" state. | #80 corrects the central routes and tracker state; #85 owns the remaining current-truth sweep. |

## Issue #8/#9/#10/#11 interpretation

#9 remains a completed characterization checkpoint. Its measurements are scoped
historical evidence and are not a broad gameplay acceptance result.

#10's completion evidence is retained: versioned granular support/exchange policy,
the executed player and permeability matrices, deterministic scheduling behavior
and the explicitly recorded platform limits are not retracted. The defect is the
later use of that bounded completion as if it answered the broader player/granular
gameplay objective after owner evaluation said otherwise.

#11's historical repair evidence is likewise retained exactly in its tested
ordinary rectangle/load envelope. Two separate deficits now matter: the accepted
repair is not integrated in audited current main, and the broader body/granular
gameplay envelope was not accepted by the owner.

#8 therefore remains open for truthful umbrella tracking. #12 is an independent
soliding programme, not the sole remaining reason for #8 to stay open.

## #19 and #26 evidence preservation

The #19 result remains valid for its simulation/presentation implementation,
policy reset/owner boundaries, deterministic scenarios and the tested
desktop/browser/rendered surfaces. REM-001 only withdraws the present-tense
claim that the existing operator-facing export path is sufficient for a formal
blind human study. #84 must repair that study boundary without rewriting #19.

The #26 result remains valid Outcome B for the exact registered local candidates.
REM-001 adopts the later post-merge apparatus qualification: #49 must repair the
successor oracle before #45 freezes or judges a new head-transmission candidate.
Nothing in this audit changes production Water semantics.

## #12 and concurrent remediation boundary

Stage 3A remains the frozen correctness/reference checkpoint. By this audit,
#56-#60 and #69 were complete; #61 was the next serialized central-World producer
owner and #64 the separable graph/index package. Stage 4 remained blocked.

The remediation programme does not impose a global pause on #12. Before #81 or
any later remediation child edits native World/body coupling or shared tests, it
must inspect the live #61-#64 owner/write set and stop on a real collision rather
than creating duplicate implementation work.

## Audit limits

This audit did not:

- rerun #9/#10/#11 physics campaigns;
- perform new player or rigid-body gameplay acceptance;
- run a Water H preference study;
- rerun #26's candidate campaign;
- execute or admit Stage 3B;
- select a Cell layout, Water architecture or granular/body solver;
- certify platforms beyond the dated evidence cited by their original records.

Those absences are deliberate. REM-001 is an authority/evidence reconciliation,
not a vehicle for obtaining missing behavioural acceptance.

## Handoff

The Current interpretation and dependency graph live in
[development-claims-remediation-programme.md](../operations/development-claims-remediation-programme.md).
That programme may be updated as children land. This dated audit must remain
unchanged except for a separately documented integrity repair that preserves the
original record.
