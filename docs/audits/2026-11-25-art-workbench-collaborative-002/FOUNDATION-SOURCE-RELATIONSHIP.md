---
title: Art session and Batch foundation source relationships
status: Planned
document-kind: audit
scope: Read-only GitHub state, complete Git ancestry and native ownership check
last-reviewed: 2026-11-25
---

# Session and Batch foundation relationships

**Art inherits the accepted #727 session contract through #773. The #720/#770
Batch construction lineage remains separately owned by Architecture #777.**
The final Art delivery does not claim Batch ancestry or ship its StageSession
and native module library. The exclusive proposal transport handoff connects
those owners without importing their active branches.

This check refreshed actual GitHub PR metadata and used complete local Git
objects for read-only ancestry/tree comparisons. It performed no branch import,
checkout change or native execution. The exact observations are in
[foundation-source-review.json](foundation-source-review.json).

The later strict-repeat source d503d824aac4128968f7dfba5dccd540c3c07b59 is a
canonical direct child of 3a, with exactly one append-only mission-ledger change.
That source/negative review is [recorded separately](DELIVERY-NEGATIVE-INDEPENDENT-REVIEW.md).
It preserves these foundation and native ownership relationships, without
claiming a successful Windows outcome from ancestry alone.

| Foundation | Refreshed state and exact source | Relationship to Art |
| --- | --- | --- |
| [#727 session logging](https://github.com/techrote/cybersand/pull/727) | Merged, closed; source 64a9ff4cfc5758998e315c250d1c443f83385331, accepted merge 00cdb02f103265b6dc5224c68283e9a0c8cb449f | Both are actual ancestors of #773 and the Art successor. Their trees are identical: 06b62d73138028d1f7615b83edc9810491bf6287. |
| [#720 original Batch Lab](https://github.com/techrote/cybersand/pull/720) | Open, actual Draft, unmerged; source 76fcf209e0cda5820aa64e104bfae732075ae7c3, tree 7413eec0f05f0176dcd7104b187f80c920470894 | Actual ancestor of #770 and #777; not an Art/#773 ancestor. Its original source/evaluator and negative findings stay intact. |
| [#770 qualified Batch architecture](https://github.com/techrote/cybersand/pull/770) | Open, actual Draft, unmerged; tested application fe2395c7060dae736dc2e5dc8d1e4e050b2d2e52, tree ce012a8c6b616ab038d4dc65f4ac1896a6388795; archival head f5f6e9f35727d81868bcced4da8b913b470ea635, tree 5067c3c293331042235a90a3f6a992e7b48d000a | Actual successor of #720 and ancestor of qualified #777; neither application nor archival commit is claimed as an Art ancestor. |
| [#773 qualified Art predecessor](https://github.com/techrote/cybersand/pull/773) | Open, actual draft=false, unmerged; current head 1c2d084cba2e44e455f6ffe7d269007519829102 | Actual ancestor of Art delivery 3a0ec3659f23d8e997e6721aa754d5a8ebe48512. Its flag is not interpreted as owner acceptance or changed by this review. |

## Preserved session behavior

The accepted #727 source is a real parent of merge 00cdb02f, followed by the
ancestry-preserving Art #773 successor. Current Art retains an empty in-memory
conversation at new Workbench session creation, lazy independent session audit,
no historical transcript import/linking, current-session Hide/reopen continuity,
redacted admitted records and independent native history.

The current source's test_art_session_log.gd still explicitly checks missing
historical pointers, no idle file creation, no old model context, one live audit,
credential redaction, distinct new-session audits and exact preservation of old
files. This is a source review of those requirements; its actual regression
execution belongs to the named Art campaigns. The PR body's historical HOLD
language is not substituted for GitHub's observed merged state or the owner's
accepted session decision.

## Batch and Architecture retain their native authority

Complete Git ancestry establishes the original Batch source, qualified #770
application, its archival commit and #777 tested application
17c6b5b35049b7b2541c2deeea23c02fd1e2fc5d as one preserved lineage. #777's current
archival head is 4cc400cea6be7cb338f15bc6a6a2b28b44143b71; it remains open,
Draft and unmerged. None of those Batch/Architecture application commits is
made an Art ancestor by this integration.

The qualified Batch/Architecture trees contain batch_lab/architecture_stage_session.gd,
batch_lab/native_module_library.gd and batch_lab/batch_lab_controller.gd. All three
are absent from the principal Art source. Architecture therefore continues to
own its modules, stage plans, dependencies, approvals and native construction.
Art's retained art_batch_executor.gd predates Batch Lab; that filename does not
imply the #720 implementation has been absorbed. The Art successor adds guarded
finite submissions to that existing executor and preserves its native owner.

Across the inspected #727, accepted main, #720, #770, #777, #773 and Art sources,
the entire native tree is e6946f5c5d47eddd6118696b124470737cdd385e and the materials
tree is 0402173c387905f1a3a910750edb62f3fb3613a6. This establishes unchanged
native/material source trees, not identical separately rebuilt binaries.

The [isolated tested handoff](https://github.com/techrote/cybersand/blob/765afb7c33e593eee3e83c957a0af7ec05278023/docs/audits/2026-11-25-art-architecture-native-handoff/final-provider-closure-result.md)
mounts the exclusive Art provider closure over the qualified #777 source and
exercises the existing Architecture native owner. It preserves both independent
evaluators. No production Architecture UI/configuration factory or combined
Windows acceptance is inferred for the principal Art package.

The [#720 original campaign](https://github.com/techrote/cybersand/actions/runs/44962406023),
[#770 qualified campaign and evaluator](https://github.com/techrote/cybersand/actions/runs/45454711939/artifacts/14951042272)
and [#777 evaluator](https://github.com/techrote/cybersand/actions/runs/45520561849/artifacts/14983516321)
remain their owners' source-specific qualifications. This note does not rerun
them, relabel their archival heads as application-tested sources, or erase their
fixture/genuine-model, geometric/physical and owner-acceptance limits.
