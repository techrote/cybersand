# Independent decision-packet semantic review — specialist A

Reviewed the lead's final decision Markdown/JSON working drafts against frozen application `934cc0c0eef70dad528155e9a92eebe25e2757eb`, including owner, import, plan, history, provenance and save contracts. This is a documentation review; no application changes were requested or made.

## Corrections verified in the current draft

- Decorative history is a 32-entry window per plane. Each acknowledged native chunk is a separate history step. Approval warns about displacement, and an operation longer than the retained window cannot be completely undone through that window. Existing Play history semantics remain distinct.
- CYSSTRAT writes the validated document's declared version. New documents use v2; retained v1 documents preserve their original meaning and remain writable as v1 until the explicit extension-upgrade boundary. The JSON now distinguishes supported versions from the write version.
- Saves retain native authored geometry, source metadata and digests, not a copy of arbitrary supplied PNG bytes. Original artwork must be kept separately for remapping. The raster source remains unmodified.
- PNG selection-mask exclusions are no-write even in raster Replace mode. A native module's write mask is a separate contract; explicitly approved native clearing can request Empty subject to target bounds and protection. The real reference crops are opaque RGB artwork plus separately authored masks, not discovered source alpha or depth.
- Reference-source crop coordinates and the crop-local import coordinates are distinct. Real imported native readback is kept separate from source imagery and render-only effects.
- The graphical import exercise undoes its import before saving. Its fresh-process result proves exact saved authored markers/settings and historical import records, not a surviving imported footprint. A separate one-process local headless supplement now verifies the surviving redone Play import and completed native composition through ordinary loading, with its writer-binding limitation stated explicitly.

## Dated correction to the reviewer's earlier suggestion

On 25 November 2026 I corrected an earlier review suggestion about zero-change stages. That suggestion had conflated zero changed material cells with zero explicit requested writes. The source is unambiguous: `strata_construction_plan.gd` refuses an empty requested-write set, and `strata_construction_session.gd` submits every requested chunk even when its material values already match the target. Those chunks still need actual owner ACKs, history handling and readback; their changed-cell count can be zero. The retained writer's repeated composition provides concrete examples.

The lead removed the earlier no-ACK wording from the draft and canonical documents. This was a documentation-review error, not an application defect, gate relaxation or reason to alter the frozen source. The corrected contract is: **requested, applied and changed counts are separate; every requested chunk needs its real native acknowledgement and readback.** A hidden or skipped dependency does not become completed.

## Additional precise final wording

The bounded provenance policy should remain visible in owner-facing limitations: at most 64 terminal records and 256 KiB, preflighted before native writes, with no silent record eviction. Historical records survive Undo and describe past operations; they are not a current geometry inventory. A stale-pixels outcome must retain committed native status, while an unverified or failed readback must not claim verified geometry.

The existing ownership language is accurate when scoped to this candidate: one ordinary Workbench Play owner/worker/actor authority; three additional static decorative owners created only by composition preparation; no decorative Rapier/actors, transfer or new global scheduler. Loading a different authored scene is an explicit replacement operation; view-mode toggles and decorative/effect controls preserve the active Play identity. The ordinary model-assisted Art path in this candidate remains Play-only; other programmes retain their own source ownership and acceptance gates.

The save witness ordering should be explicit in the final performance/persistence discussion: graphical install hashes are captured for Save before the subsequent physical route probe. Equality on fresh reopening establishes authored-layout persistence, not continuation of evolved Play state. Callback windows, actual native/Rapier completion counts, whole-process CPU/RSS and owner GPU/display acceptance remain separately labelled.

No additional material semantic blocker remains after the recorded corrections. Final source-bound platform, extracted-package and independent payload admissions must populate the pending decision fields from actual original receipts. Prior source3 failures and earlier timing misses must remain original negative evidence.
