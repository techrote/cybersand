---
title: Collaborative Art execution-environment recovery
status: Planned
document-kind: audit
scope: Durable source custody, lost temporary evidence and fresh qualification requirements after the 25 November 2026 environment reset
last-reviewed: 2026-11-25
---

# Execution-environment recovery

**Draft/HOLD. Temporary loss does not create a passing qualification result.**

The lead reported that the shared execution environment restarted and removed
the mission's `/tmp` working area before the latest local integration changes
and original execution outputs had been persisted through the GitHub interface.
This report records that loss. It does not assign an unobserved product cause
to the restart or fabricate identities for unpersisted commits.

## Durable source checkpoints

The following source objects remain available remotely:

| Owner/lane | Durable commit | Scope |
| --- | --- | --- |
| Lead integration | `7db8d1592642c7bd7298ba8f8fb008345de35e07` | Integration baseline; tree `c9ba0ddc7e7ec5de1e62eed3f27123a20c52cd61` |
| Native/context lane | `fe1988df6ccfbcb2b0c2150aeac44cf1f3484ed6` | Context/compiler/preview, fixtures, matched timing correction and independent review; descendant of `daf7a194` and `03421624` |
| Experience/qualification lane | `036264507b1b7bc6a2dafec1e1268802090fb8f6` | UI/package lane, including complete bounded context JSON copy |

The lead retained the text of narrow integration patches in the orchestration
store and will replay them onto the durable source. That text is recovery input,
not an authenticated Git commit or a qualification receipt. The recovered
files must be reviewed and committed; their actual new commit and tree identities
must then be recorded.

This note deliberately supplies no guessed SHA for the lost local state.
The source reviewed by the native specialist remains the explicit `7db8d159`
baseline until a recovered remote pin is inspected.

## Evidence custody after the reset

The lead reported development execution up to a 169-check actual-native session
case while implementing the review fixes. Earlier messages recorded a
145-check source and then further checks. The latest local source, original
process logs and output artifacts had not been durably preserved before the
reset. Those reported counts remain historical development observations; they
cannot qualify the recovered source or replace fresh original logs.

The first nine-scene native campaign had completed eight staged scenes and eight
matched direct controls with native readbacks and ordinary Setup saves, then
received exit 137 after the ninth scene's baseline, before its complete capture.
It had no successful nine-scene terminal marker. It is an **interrupted
eight-of-nine attempt, not a pass**. Its originally local PNG, JSON, receipt and
Setup files are not asserted to remain available after the reset.

Earlier local Architecture probe and performance observations also need fresh
source-bound evidence. In particular, a reported 32-check source-pinned probe
and the 4 MiB transport comparison must be rerun where their original temporary
outputs are unavailable. Numeric summaries reported in conversation are not
substitutes for original process logs, fixture configuration, timing scope,
runtime identities and output hashes.

The earlier pure compiler/cohort, provider, UI and native authority observations
remain useful development history only to the extent their source and original
evidence are actually retained. No earlier success is silently promoted to a
pass of the recovered integration. No lost log is recreated and labelled an
original; reruns receive new campaign identities and output directories.

## Retained findings

The independent source review remains available at
[NATIVE-INDEPENDENT-REVIEW.md](NATIVE-INDEPENDENT-REVIEW.md). It retains:

- Completed native work could lose its visible unverified receipt when readback
  was cancelled or refused.
- The adjacent terminal-before-harvest Stop/World-replacement boundary also
  needs to retire the completed work before starting a new verification.
- Discuss/Review or applied Conversation edits could leave an old disclosed
  recent-message selection in the next request.
- The first staged/direct timer scopes differed; the durable native lane
  corrects this and retains explicit noncausal timing limits.
- A depth-limited readable context summary was also copied as if complete;
  C's durable `03626450` source now retains complete bounded JSON separately.

The lead reported local fixes and new checks for receipt custody and
conversation continuity before the reset. Their recovered implementation still
requires independent source review and fresh execution. These findings are not
removed because an unpersisted local test was reported passing.

Exit 137 and the subsequent environment loss remain separate observations.
Neither establishes an application memory leak, a physical Windows/NVIDIA
result or a successful recovery by itself.

## Predecessor custody is unchanged

The qualified Art predecessor remains untouched:

| Record | Preserved identity |
| --- | --- |
| Qualified evaluator source | `fa22d386b802b686c371bb6e12996c7a93c18588` |
| Qualified evaluator tree | `3245dfc9090a6f37a0e0824325b21e86b59d50a8` |
| Application-qualified source | `981a740828decbeac04d5a14511d0222095de0a9` |
| Original application campaign | [45482969231](https://github.com/techrote/cybersand/actions/runs/45482969231) |
| Original package campaign | [45497650568](https://github.com/techrote/cybersand/actions/runs/45497650568) |
| Original Windows artifact | [14968792395](https://github.com/techrote/cybersand/actions/runs/45497650568/artifacts/14968792395) |

The predecessor's actual non-Draft GitHub flag was recorded at intake and was
not changed by this mission. Its physical owner no-listener Windows/NVIDIA
acceptance remains pending. This reset does not change either programme's
independent evaluator or grant acceptance of the successor.

## Recovery and fresh qualification

The recovery sequence is finite and source-specific:

1. Recreate the integration from durable Git objects and the retained patch
   text. Preserve specialist ancestry and commit the recovered tracked source.
2. Inspect the recovered receipt-retirement paths, conversation disclosure
   revision handling, direct/collaborative admission fences and complete
   context copy against the reported findings.
3. Run the complete new deterministic suite at that committed source, including
   all nine native scenes, their nine direct controls, Save/reopen readbacks and
   all 24 retained brief outcomes. Keep native and copied-value evidence distinct.
4. Rerun the owned-response/Architecture loopback probe and any performance
   comparison used in the handover. Record actual arm scopes and runtime/hardware.
5. Complete the applicable predecessor regressions and fresh ordinary Linux and
   Windows displayed/headless gates. Retain failed attempts as separate outcomes.
6. Build the principal Windows ZIP only from the source qualified by its actual
   campaigns. Verify the pristine extracted launcher and immutable payload
   identities; record the real artifact and checksum.

Fresh campaign results will supersede missing temporary evidence for current
qualification, while this record preserves the loss and original failed or
interrupted observations. The successor remains Draft/HOLD throughout.
