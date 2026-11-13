# WB-ART-SLM-001 — native-gallery cross-theme collision qualification

Date: 13 November 2026. Role: Independent Evaluation. Owner branch: codex/wb-art-slm-evaluation. **Decision: HOLD.**

## Completed implementation and source-bound measurement

Published:
- [Executable cross-theme auditor](audit_cross_theme_collisions.py), with SHA-256-pinned input files and strict rejection of altered evidence, original denominators, missing native card/seed/crop hashes, altered AI labels, missing raw failures, invented aesthetic ratings, and similarity below the registered exploratory threshold.
- [Ten local adversarial/unit methods](test_audit_cross_theme_collisions.py): **10/10 PASS**, Python standard-library only. Both exact GitHub-published source blobs were read back and matched locally executed Git blob identities: auditor 70150c5f00f4bde31134d015af5db37f867f811f and tests 41b107709cb2d16b0b000d7386c886b57673654e.
- [Recorded independent measurement](cross_theme_collision_audit_2026-11-13.json), computed from the actual existing published frozen original answer key, AI review responses and native-image pixel morphology records. These source objects were fetched and programmatically joined by original qIDs and structural group IDs. No new classification was fabricated.

Exact original evidence inputs:
- blind_model_review_answer_key.json: SHA-256 1bcac225ca5d5674a042a750e3d6dae680c1ae6f26c4019569176f20d5ee90bf.
- assistant_blind_review_responses_2026-11-13.json: SHA-256 f0f688049cf077c25905049917272b6f06ad6db3ea5f770f5c2a7fa8191a0ed5.
- pixel_stimulus_morphology_audit.json: SHA-256 b87f804b48975746d5fb7aa9dcd2b937aa23607ce14e677011d3a248220d7f60. Locally verified byte-for-byte against published Git blob bae4328387b4cd2b198f972d426d71b2f66f15e4.
- Original review HTML: SHA-256 5f554c67c928d6f940126d07c529df89694a42d6cdeb7a65c7b9c4413f354877.

## New result: one cross-family visual collision

Of three previously detected pairs with **aligned-seed foreground Jaccard >=0.85 at both native seeds**, one crosses intended themes and structural groups:

| Pair | Expected themes | AI reviewer labels | Seed 17 / 73 Jaccard | Independent diagnosis |
| --- | --- | --- | --- | --- |
| **q003 / q032** | **veins / circuitry** | circuitry / circuitry | **0.879377 / 0.967470** | The veins keyword's compiled geometry already carries a recorded incorrect primary motif. The near-collision is therefore a specific semantic failure, not merely repeated seed variation |
| q004 / q007 | ribs / ribs | ribs / ribs | 1.000000 / 1.000000 | Exact same-theme native images at both seeds; two original requests, not independent structures |
| q020 / q029 | labyrinth / labyrinth | labyrinth / labyrinth | 0.995165 / 0.990787 | Same-theme near-repetition, not a separate semantic failure |

Across all admitted requests, the one frozen AI visual reviewer correctly classified **29/34**, or **29/36** including both original malformed coral refusals; group macro **20/23**. The five AI errors are q001 (dunes→ribs), q003 (veins→circuitry), q009/q011 (strata→dunes, same group) and q024 (dunes→strata). Group-macro scores for dunes, strata and veins are each 0.5 in this small admitted development/keyword sample. These figures are source-derived, not new model inference or new native replay.

**Training development targets:** preserve first-pass invalid coral requests as failures. For a new, separately identified candidate, test genuinely distinct veins/network versus circuitry/orthogonal programs and strata versus dunes motif/layout combinations. Use TRAIN and sealed DEVELOPMENT only, unchanged host seed/budgets/native compiler contract, no final-set leakage, and report matched first-pass results before promoting. Do not fix semantic outputs in postprocessing to claim model competence.

## Scope, qualification and handoff

The source branch preserves accepted main 63f8b1ba including #563. Upstream #564 is Draft 6319ab1d. #565 published newer head 11b809a5; its source-matched campaign [43402768596](https://github.com/techrote/cybersand/actions/runs/43402768596) was **still in progress when checked**. This is not a qualified successor package. The original native material-display pilot remains the separate Linux headless source 90719c72, not current-main/Windows/Godot graphical acceptance.

The **ten executed tests are local synthetic contract tests**, not a hosted exact-repository native run. The recorded measurement was independently recomputed from the three real source documents; the newly published Python CLI has **not yet been executed end-to-end against those files in a full local checkout**. Integration should import by exact role-file blobs and add the offline tests and a source-file CLI replay to its existing smoke workflow, without taking over any other role.

No weights, teacher/completion data, model/compiler code, native source, material laws, defaults, schedules, other role branches or shared PR #567 were changed. Only Evaluation-owned files were published. The frozen 400-step LoRA remains unchanged, and no current-source native protection/Stop/history/persistence, Windows, blind-human or final-assessment acceptance is claimed. Keep raw-schema **95%**, constrained **99% if actually executed**, positive-request native **98%**, group-aware human-recognition **80%** and zero observed host-invariant-violation targets unchanged.

**Next:** Integration imports the result and verifies a full exact-source CLI run; Training uses these development failures to justify one separately identified, guarded candidate when its private lease/model environment permits; Evaluation compares it under the same raw/native/visual denominators and qualifies a genuinely source-compatible upstream Workbench when available. **HOLD; no Ready, merge or production promotion.**
