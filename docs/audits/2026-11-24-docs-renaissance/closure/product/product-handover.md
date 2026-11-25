---
title: Documentation closure product and visual qualification handover
status: Current
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Recovered product work, fresh manual/source review, bounded corrections and visual integrity; no physical acceptance
last-reviewed: 2026-11-25
---

# Product documentation and visual qualification

**Recommendation: OWNER-READY WITH EXPLICIT LIMITATIONS for this lane.** The
README, documentation portal and all six new practical guides form a coherent
first-launch, authoring, simulation and reopening route. Closure found and
corrected five documentation findings: generated-map reopening, launcher provenance,
named-save replacement, Art message counting and format-specific save-failure
guarantees. The flagship README and existing visual design were preserved.

Reviewer and author: Specialist B (`/root/product_docs`). The accepted source is
`00cdb02f103265b6dc5224c68283e9a0c8cb449f`; the inspected recovery anchor is
`ddd7c88fd97d8b85056dd7910896ec3a897ecb87`. Document/source hashes and scope are in
[the product source review](product-source-review.json). This report records new
closure work; the original reports remain unmodified in the parent audit folder.

## What was recovered

The original workspace retained the complete original B workstream, including
the [reader walkthrough](../../reader-walkthrough-b.md), its freeze receipt,
43 B consequential claims, A's original review of those claims, late manual and
standalone-host readbacks, 12-asset provenance, 26 B preservation entries, bounded
execution receipts and final retrieval-answer reviews. These are original files
recovered from the prior execution, not reconstructions of missing participation.
The lead's [recovery manifest](../recovery/original-recovery-manifest.json) owns
byte custody and publication of the complete original audit set.

The prior B report distinguishes 54 keyless provider checks, 32 World Art Python
checks, three native material renders and a blocked graphical display attempt.
Those dated executions remain original evidence. This closure did not rerun them
or substitute a new source identity for their original runtime/build receipts.

## Reader journey and corrections

B read README, portal and all six new practical guides end to end. The reviewed
route begins with source/evaluator choice and exact Godot/runtime identity,
continues through a fresh paused Workbench, Observer selection, small Hard Wall
and Sand construction, native-confirmed Undo/Redo and authored Save, then Play,
Water readback, explicit Flatten and a fresh session load. It proceeds into
architectural preview/install, direct Art drawing, actor/Water/Materials routes
and clearly separate standalone showcases.

| Closure finding | Correction and evidence |
|---|---|
| **B-CLOSE-01 — P1:** generated reopening stopped at Load start | The practical save guide, architectural and generated-map desktop walkthroughs, integrated Art exercise and EXPLORE-001 contract now explain that loading a generated start opens **Verify and reopen saved starting map**, generates/verifies its recipe, then requires **Install into workbench**. Cancellation or source mismatch preserves the current map. Source: `shared_workbench.load_setup`; generator dialog `open_saved`, `_complete`, `_install`. |
| **B-CLOSE-02 — P1:** launcher versus full provenance could be conflated | Getting started states the wrapper's actual pinned-Godot/materialized-library/native-DLL-hash checks. The separate `check_repository.py --require-materialized` comparison owns checkout source-input equivalence. The launcher does not rebuild libraries. |
| **B-CLOSE-03 — P1:** named-save replacement was implicit | Saving now specifies the 1–48-character ASCII name grammar, same-name replacement and absence of an extra overwrite confirmation. Unique names preserve earlier variants. All three authored formats use the same named path. |
| **B-CLOSE-04 — P2:** Compacted “12 turns” was ambiguous | The practical Art guide and A's canonical provider page now say 12 individual conversation messages, including native feedback. A latest-result summary is added only when older entries are omitted. |
| **B-CLOSE-05 — P1:** ordinary/generated/project saves inherited a universal preservation guarantee | The integrated Art runbook, EXPLORE-001 steps and architectural generator contract now distinguish admission refusal, ordinary Godot rename and the material-baseline writer's native atomic replacement. Unique names preserve older variants. The existing architectural project failure message still overstates prior-file preservation; the documentation explicitly records that bounded implementation limitation. |

The [source review](product-source-review.json) records the actual source file
hashes, classifications and final reviewed document identities. [Independent A
readback](../technical/product-cross-review-by-a.md) verifies all four corrected
themes at their actual document hashes. Its P1 consequence assessment is retained
for source provenance and named-save replacement as well as generated reopening.
The fifth finding arose from B's review of actual retrieved contexts: A corrected
the three affected canonical routes, and B independently rechecked all writers and
[the final correction deltas](review-technical-delta-by-b.md). A final generated-route sweep found and corrected the same reopening omission in
the desktop playtest procedure; it remains part of B-CLOSE-01. All five
generated-specific practical procedures now state the explicit installation. The
Water Lab comparison includes the same qualifier when its starting scene is
generated, preventing a trial from continuing on the old canvas.
A's [separate final amendment](../technical/review-product-final-delta-by-a.json)
binds both late corrections to source and reviewed hashes. No runtime code was
modified for these corrections.

The existing important boundaries remain visible: ordinary Save is authored
reconstruction; Flatten changes a material-only baseline and discards prior
construction history without saving by itself; cancellation can retain a
confirmed partial prefix; queued work is not applied success; ordinary Art
protects source materials other than Empty/Hard Wall; Hide and Stop differ;
Materials Lab candidate comparisons are isolated; Wave and Pressure remain
separate; and standalone Strata does not establish integrated Workbench layers.

## Images and presentation

[Fresh visual verification](visual-qualification.json) independently checked all
12 documented images against the recovered SHA-256, size and dimensions. All
12 matched; the nine reused images are also byte-identical to the accepted
baseline. The three original-mission native renders retain their recipe,
material and PNG provenance: 1024×512 upper crops of 1024-square native projects,
seed 271828. They are material visualizations and were not relabelled application
screenshots.

B independently viewed the four recovered desktop/narrow top/gallery excerpts
and all three new native architectural images. The README SHA-256 matches the
preview manifest, and both PDFs plus four PNGs match their recorded hashes.
The inspected excerpts have clear hierarchy, captions and navigation. Narrow
images remain recognizable; fine text inside the retained Materials Lab image
requires opening it at full size, with practical instructions supplied in the
linked text guide. The original previews were preserved unchanged.

Actual GitHub rendering remains **BLOCKED before page load**. The fresh supported
Browser attempt returned that originating browser context was unavailable; no
page or screenshot was observed. This specialist had no callable CUA fallback.
[The fresh receipt](browser-inspection.json) records that limit. The lead separately
attempted the supported cloud Browser fallback; it returned “Browser runtime
unavailable” before page load, as recorded in [the lead receipt](browser-fallback-attempt-by-lead.json).
The lead also independently viewed the unchanged desktop and narrow static top
previews. Neither attempt produced a browser rendering or live application capture. The available
previews are explicitly Pandoc/PyMuPDF static layout approximations, not a claim
about actual GitHub responsive layout or a live application.

The retained Blacksite capture's original lack of a full checkout revision
remains explicit. Its original script-set/native hashes were not promoted into
current runtime qualification. No retained image was altered or recompressed.

## Independent technical review

B also reviewed A's actual nine-document technical changes and their source
basis. [The independent review](review-technical-by-b.md) and
[machine-readable receipt](review-technical-by-b.json) cover accepted LCB
constructor labels, source-versus-runtime qualification, authored continuation,
Water quantity families, world-size/camera distinctions and Art message limits.
The reviewed merge commits for #256/#257 are ancestors of the accepted baseline.
No new P0/P1 contradiction remained in that change set. The subsequent
[four-document delta review](review-technical-delta-by-b.md) checks the generated
reopen counterpart, save-failure guarantees and local historical machine-path
qualifications against their final bytes.

This was semantic/usability cross-review of changed text with targeted source
checks, not a claim to have freshly reviewed every unchanged historical paragraph.
It preserves the native owner/main-thread Rapier boundary and refuses to turn
old qualification labels into either current restrictions or new runtime passes.

## Fresh retrieval answer review

B independently read all 75 supplied passages for 15 additive questions
(DR01–05 and DR21–30), wrote bounded answers and checked consequential details
against exact source. The [complete answer audit](../retrieval/answer-b-review.md)
and [machine-readable review](../retrieval/answer-b-review.json) retain every answer,
missing fact, authority/scope assessment, source locator and packet/report digest.
The result is **13 sufficient, 2 partial, 0 wrong-context answers**.

DR02 retrieves the exact Godot executable pin but omits the godot-cpp commit/API.
DR04 retrieves preliminary launch/provenance checks but omits the bounded C-header
probe and focused engineering-test menu. Those answers explicitly stop at the
available context. Canonical-page hits were not treated as full answer quality.
The audit also found B-CLOSE-05 in a retrieved adjacent passage and verified the
corrected final context. B independently compared both packet deltas and freshly
read every changed position. No external model, embedding index or agent integration
was qualified by this reviewer-authored applicability audit.

## Validation and remaining limits

[Product validation](product-validation.json) records a fresh documentation
checker PASS: 151 current documents, 280 canonical claims, 3,521 local links and 491
heading anchors, with no errors or warnings at that working-tree checkpoint.
The B current-document whitespace check passed. A [final B identity receipt](final-document-identity-by-b.json) binds
all 27 reviewed entries across 24 unique document hashes to the published source checkpoint
`700c89c451903fac07188196a2f94b5c8997cb53`; the lead owns the final evidence commit,
integrated-head matrix and separate exact-original whitespace disposition.

No fresh graphical first-session, save/Flatten or Direct JSON walkthrough was
performed. This is a documented execution limit, not a concealed PASS. The
instructions are source-qualified and independently reviewed. No physical
Windows/NVIDIA acceptance, GPU performance, paid provider dispatch or current
cloud-model availability claim is made. Existing provider presets describe the
accepted source only.

The existing architectural project error message still says a failed rename
preserves the prior file, a stronger guarantee than this path establishes. The
current documentation now warns about it and recommends a new filename; source
behavior was not changed. This is an explicit bounded implementation issue for
the owning runtime programme, not an unrecorded documentation contradiction.

The remaining useful follow-up is a small first-session/Direct JSON/save/Flatten
walkthrough and a current Workbench UI capture on a permitted qualified graphical
host. That follow-up can strengthen runtime usability evidence without blocking
meaningful review of the completed documentation and its explicit limits. The
principal PR remains Draft/HOLD pending the owner's adjudication.
