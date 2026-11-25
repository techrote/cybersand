---
title: Collaborative Art native and evidence review
status: Planned
document-kind: audit
scope: Independent source review, retained findings and owner real-model protocol for ART-WORKBENCH-COLLABORATIVE-002
last-reviewed: 2026-11-25
---

# Native authority and creative evidence review

**Draft/HOLD. This is a source review and an evaluation protocol, not an
application, Windows, physical-hardware or genuine-model acceptance receipt.**

The native/context specialist reviewed the lead-owned integration at
[`7db8d1592642c7bd7298ba8f8fb008345de35e07`](https://github.com/techrote/cybersand/commit/7db8d1592642c7bd7298ba8f8fb008345de35e07),
tree `c9ba0ddc7e7ec5de1e62eed3f27123a20c52cd61`. This review is independent
of the lead's implementation of the session coordinator, PAINT capture adapter
and per-chunk native fence. The reviewer authored the context/compiler/preview
and creative fixtures, so this document does not call review of those modules
independent. Specialist C separately reviewed their native and evidence paths.

The reviewer's executor was unavailable. Runtime observations below are
explicitly identified as lead-reported; source inspection used the immutable
GitHub tree. Final source identities, original logs and any later qualification
must be recorded in the mission ledger. A later fix does not retroactively
change this reviewed source.

## Source findings

| Boundary | Finding at the reviewed source |
| --- | --- |
| World observation | `workbench_paint_editor_controller.gd` borrows the existing exclusive PAINT capture owner. It does not let Art drain the PAINT mailbox independently. The callback receives copied values and a complete generation/revision/tick/authoring-generation identity. |
| Capture cancellation | Cancellation requires the matching Art capture operation ID. Cancelled or replaced captures cannot publish completed materials. PAINT retains its existing retired-operation receipt handling. |
| Native admission | `art_batch_executor.gd::submit_guarded` uses the ordinary executor; each chunk carries a copied expected source. `simulation_worker.gd::art_queue` checks it at admission, and `_consume_art` compares it again with actual native state before writing. |
| Native source policy | The exclusive worker still permits ordinary Art changes only from Empty 0 or Hard Wall 58. Protected rectangles, native body masks and actual destination readback remain enforced. Destructive permission does not enlarge that source-material authority. |
| Manual interleave | The next guarded chunk advances its source from an actual completed native receipt. An intervening manual operation changes the live source and invalidates subsequent chunks instead of being silently accepted as part of the proposal. |
| Stage approval | The coordinator checks current policy, paused state, live source, earlier verified dependencies and the full material-plane hash before submitting one stage. Later stages need another owner action. |
| Preview and discussion | The preview evaluates copied materials through the existing rasterizer. Discuss/Review response branches retain prose and cannot submit native operations. Model-authored proposals are parsed/compiled and previewed, never treated as approvals. |
| Skipped or obsolete work | Skip retires the residual preview. Manual edits, changed constraints and source changes require fresh observation/replanning. Separate stage writes are not represented as an atomic transaction. |
| Model-visible context | The coordinator sends the bounded model context and disclosed session messages. The full private `_capture` plane is not copied into the provider payload. Optional appearance is a canvas crop, distinct from native material authority. |
| Native parts and Architecture | This isolated Art candidate implements finite native material primitives. It does not claim execution of Architecture-owned parts or a qualified combined StageSession candidate. The separately owned proposal-only handoff needs its own source-pinned evidence. |

The PAINT executor refuses a capture if a transient rigid-body mask covers a
selected cell. Consequently, the context/preview does not silently treat a
pre-existing covered Empty cell as available construction space. Later source
changes remain subject to the native fences.

Sources: [session coordinator](https://github.com/techrote/cybersand/blob/7db8d1592642c7bd7298ba8f8fb008345de35e07/godot/scripts/art_collaboration_session.gd),
[ordinary executor](https://github.com/techrote/cybersand/blob/7db8d1592642c7bd7298ba8f8fb008345de35e07/godot/scripts/art_batch_executor.gd),
[exclusive worker](https://github.com/techrote/cybersand/blob/7db8d1592642c7bd7298ba8f8fb008345de35e07/godot/scripts/simulation_worker.gd),
[PAINT capture owner](https://github.com/techrote/cybersand/blob/7db8d1592642c7bd7298ba8f8fb008345de35e07/godot/scripts/workbench_paint_editor_controller.gd)
and [PAINT native executor](https://github.com/techrote/cybersand/blob/7db8d1592642c7bd7298ba8f8fb008345de35e07/godot/scripts/workbench_paint_editor_executor.gd).

## Retained defects and disposition

**Completed work can lose its visible verification outcome at this source.**
The lead coordinator stores `pending_stage_receipt` after native completion,
then starts readback. Capture admission failure, failed capture/context
validation or Stop during that verification does not move the actual receipt
into recent acknowledged receipts and Conversation. A later stage can overwrite
the pending value. The original `collaboration_stage_result` audit event remains,
so this is a visible receipt/Review custody gap, not a claim that native work
vanished or that a write bypassed approval.

The review requested one helper that clears pending state before reentrant
callbacks, retains the real receipt exactly once as `verified=false`, marks
the proposal stale and names the verification failure. The lead acknowledged
the finding and is implementing the helper plus an actual-native Stop-during-
verification regression. **The fix and fresh passing source remain to be
recorded in the mission ledger.**

**Discuss/Review continuity can reuse an old message selection.** At the
reviewed source, `_publish_inspection` freezes the recent-message payload.
Discuss/Review `_response` adds the reply to Conversation but does not refresh
that snapshot, and `request` does not compare the conversation revision with
the inspected one. Consequently, the next follow-up can omit the preceding
exchange. Explicit Conversation edits can similarly leave superseded text in
the next disclosed request until a manual reinspection. Propose/Develop refresh
through proposal admission, so the issue is mode-specific.

The review requests refreshing the disclosed snapshot after Discuss/Review,
detecting Conversation edits before Send, preserving exact external-context
authorization and adding a two-discussion transport assertion. Refreshing
context must not itself dispatch HTTP. **Closure and the fresh source are
pending in the mission ledger.**

**The first native comparison used unequal timer scopes.** Specialist C found
that staged `elapsed_usec` included per-stage native readback, constraint checks,
PNG creation and displayed screenshot waits, while the direct arm timed only
submission through terminal executor state. Comparing those values as executor
speed would be invalid.

Native-lane correction
[`03421624e0efb4f43781b9f2939d1ca4a7fcca13`](https://github.com/techrote/cybersand/commit/03421624e0efb4f43781b9f2939d1ca4a7fcca13)
preserves the broad wall time and adds `native_execution_usec` to both arms,
with stage-level samples and an explicit summed staged interval. The artifacts
state both scopes. Fixed arm order and different stage boundaries still prevent
a randomized or causal speed claim. Fresh measurements must run the corrected
source; old unequal timings remain retained negative evidence.

## Interrupted local native campaign

The lead reported that the first actual-native campaign completed eight staged
scenes, eight matched direct controls, exact readbacks and ordinary Setup saves,
then received exit 137 after the ninth scene's baseline and before its complete
capture. That attempt has no successful nine-scene terminal marker and must not
be counted as a full pass. Partial original evidence remains useful.

A source retention review found no obvious accumulation of full material planes
in the cross-scenario `outcomes` or `originals` arrays: they retain metadata,
proposals/previews and region/hash pairs. Full captured planes and raw chunk
receipt arrays are current-case locals. Captures are bounded to 262,144 int32
cells each. The ordinary PAINT history is independently bounded to 32 entries
and 1,048,576 cells. Receipt Arrays and copies can still create substantial
transient memory; these bounds are not a measured process-RSS guarantee.

Exit 137 alone does not establish an application memory defect. The lead also
reported termination of unrelated small processes in the shared environment.
A final campaign needs the same coverage and source on a sufficient runner,
with original logs and resource observations. No reduced World or omitted
scenario is substituted as a successful equivalent.

## Creative evidence interpretation

The nine example recipes are deterministic host-authored construction fixtures.
They provide actual native geometry when executed through the ordinary
Workbench, while the separate 24-brief cohort uses copied native-shaped values
to exercise context, compiler, refusal and revision behavior. These are distinct
evidence layers.

The four held-out labels reserve texts for a future owner-operated model cohort.
The scripted fixture mapping already knows them, so the fixture pass does not
measure generalization. Knowledge-disabled and native-summary-disabled controls
freeze the proposal packet; identical results demonstrate deterministic compiler
behavior, not a retrieval benefit.

The interrupted-workshop recipe is designed to permit a substantial Stop
exercise. Merely executing that recipe to completion does not demonstrate Stop.
Actual prefix custody and fresh continuation require the separately recorded
Stop/manual-change regression. Likewise, a preserved Empty rectangle is a
static clearance observation. Actor traversal, physical structural stability,
functioning apparatus and subjective architectural quality need separate
evidence.

The owner guide should describe an interior with preserved clear passages,
rather than claim demonstrated actor traversal. Retained refusal cases remain
in the reported denominator.

## Owner-operated genuine-model cohort

Use the existing explicitly configured local provider only after the owner
chooses to run it. The protocol neither provisions a model nor authorizes paid
inference. Start with text/native context; add images only after inspecting and
authorizing the precise canvas crop.

Freeze a copy of the 24 briefs, the chosen initial Setup-v2 scenes, region,
palette and protected rectangles before model trials. Record the actual served
model identifier/build or digest when available, provider adapter, hardware,
supported generation parameters, context inclusion choices and source/runtime
manifest. Do not invent unavailable sampling controls or model capabilities.

For every run retain:

- Brief ID, cohort split, exact owner prompt and any later clarifications.
- Initial native region hash and fresh source identity; the source identity can
  differ after a legitimate reload even when the material hash is matched.
- Disclosed native/knowledge/image context, omissions and provenance.
- Original redacted response, parse/compile/preview result and refusal reason.
- Each explicit stage approval and actual native receipt, plus final material
  observations. Never infer successful work from the model's wording.
- Request count, returned usage when actually supplied, observed request latency,
  matched native execution intervals, full owner-interaction wall time and
  manual correction count. Missing provider cost/usage stays unknown.
- Owner ratings with a short reason and the original before/after images.

Restore the same saved native starting geometry between comparison arms. Keep
the owner brief, material policy and region constant. Compare direct painting,
a structured single-stage request, context-enriched proposals and finite stages
as complete workflows; different output contracts and approval effort are part
of those workflows. Record all refusals and incomplete constructions.

For a knowledge or native-context ablation, vary only that admitted information
and hold the prompt, model parameters and proposal instructions fixed. Counter-
balance arm order; repeat stochastic trials where practical. A model changing
its output still requires native qualification before aesthetics are judged.
Frozen identical fixture packets cannot answer this model-decision question.

Keep the four future held-out briefs unopened during prompt/schema tuning for
the real-model cohort. If tuning has already used a text, relabel it development
and choose a genuinely unseen replacement; do not silently preserve its
held-out claim.

## Anchored qualitative review

Safety and native correctness are gates before aesthetic scoring: a stale
write, unauthorized mutation, protected-region change or fabricated successful
receipt is a failure regardless of visual appeal. A truthful refusal of an
impossible brief is a useful successful control outcome, and remains a refusal
in the completion count.

Use a small anchored scale and retain individual ratings, rather than compress
all behavior into one unsupported creativity score.

| Criterion | 0 | 1 | 2 | 3 |
| --- | --- | --- | --- | --- |
| Structural legibility | Unreadable or conflicts with brief | Some recognizable parts; weak relationships | Clear main supports/openings/levels | Clear hierarchy and deliberate relationships that serve the brief |
| Composition and identity | Arbitrary geometry | Generic repetition with little hierarchy | Coherent palette and distinguishable spaces | Distinctive, coherent spatial character with restrained detail |
| Preservation and revision | Loses an explicit requirement | Needs repeated correction | Retains constraints and makes requested revision | Retains intent, explains tradeoffs and resolves the revision cleanly |
| Useful collaboration | Misleading or hard to control | Understandable but substantial manual repair | Proposal and controls help owner progress | Alternatives and explanations materially help owner decide |
| Scope discipline | Unbounded or unsupported action | Frequent overscope/refusal without useful repair | Finite feasible plan and honest limits | Good stage boundaries, economical operations and useful recovery |

Ratings must describe observable geometry or interaction. They do not establish
load-bearing behavior or traversal. Record actor-path tests separately when a
supported actor is actually used. Keep failed proposals and owner disagreement
alongside the successful results; do not retrospectively select only attractive
examples.

The final handover should state how many genuine model runs occurred. Until
such runs are actually authorized and observed, that count is **zero**.
