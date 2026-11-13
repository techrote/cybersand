# WB-ART-SLM-001 — Blinded native model review packet

Date: **2026-11-13**. Independent Evaluation role, `codex/wb-art-slm-evaluation`. Development/keyword predictions only; **no final assessment, training, new inference or native execution**. The underlying runtime is the historical **Linux headless native-material pilot**, not current main, Windows, a graphical screenshot or human acceptance.

## Completed, executable deliverable

- [`blind_native_review.py`](blind_native_review.py): reconstructs all actual frozen step-400 requests from the original raw prediction records; requires all **15 native global gates**, source and adapter identity, each exact replay alias, corresponding operations hashes, two host seeds and successful independent receipts; verifies each original native PNG and 96×96 material readback against its SHA-256 before emitting images. Refuses any missing, duplicate or mismatched request/image/seed. It does not turn raw failure, repair or omitted cases into success.
- [`blind_model_review.html`](blind_model_review.html): **self-contained 34-card / 68-image** blind stimulus with two actual native seed images per accepted model request. Each pair receives **one** family classification; separately optional 1–5 quality and variety ratings. The HTML exposes **no expected family, raw prompt, source ID or source group per card**, and exports an entirely local JSON response. Javascript/browser rendering has *not* been qualified on Windows; structural HTML inspection verified 34 cards, 68 images and 102 selects.
- [`blind_model_review_answer_key.json`](blind_model_review_answer_key.json): separate custody-bound answer key; **do not open before a blind review**. Holds original prediction/group/cohort IDs, exact native image/readback hashes, expected themes, two semantic-failure flags and two refused coral model requests. A published key prevents claims of enforced secrecy against a reviewer who inspects it.
- `score` refuses a different candidate review token, duplicate, missing, unknown or mislabelled response rows. Incomplete responses remain **HOLD**. A completed session reports raw-request recognition including both rejected coral prompts, recognition conditional on native admission, macro accuracy over structural groups (including the rejected group for end-to-end accuracy), a **structural-group bootstrap interval**, cohort/theme confusion, and separate subjective quality/variety. It explicitly labels a single review as *provisional*, not independent owner acceptance.

## Frozen custody and executed checks

| Item | Value |
| --- | --- |
| Saved original evidence archive | `wb_art_slm_001_native_and_model_evidence.zip`; SHA-256 `d2f8b16f081b7c371afd2eadf1468bc6941cb2a7a83ee349a11d667257f9cfa9` |
| Actual native runtime source | `90719c72b9fcf90593fb7878354051ad601b47fd` |
| Model/adapter | LiquidAI/LFM2.5-350M, step 400; adapter `02b9263e543eb464e6b58f1f74960c98d5aec4ec117baddfcf22b4d5dd4c84b2` |
| Independent native receipts SHA-256 | `63c4d319583d40f404d3e2289cb3941963efe8d8cdce45240a6bba1444315b4b` |
| Executed native input SHA-256 | `266aa3b6e8e6e8b94bb4c11d39e94dca60021f1ab967e04fdc9b3ffff23068ad` |
| Original prediction/provenance sources | development `485bac2bebfbde7712f52726da55a64df8ed3e122452e8260aafa388424c3498`; keyword `72f3d9449b8a4642c2791fad31294ff188bc770e30fd6b833fbbe690b90399ea`; alias `49d0a58726919f807327836f9b9cdee6471cc4aed65d35765f8296b233dc0567` |
| Real review stimulus | 36 original requests; 34 admitted (22 development / 12 keyword); 2 malformed **coral** rejected; 68 / 68 native images and readbacks verified; 23 admitted structural groups, 24 original groups |
| Generated review identities | HTML SHA-256 `5f554c67c928d6f940126d07c529df89694a42d6cdeb7a65c7b9c4413f354877`; answer key SHA-256 `1bcac225ca5d5674a042a750e3d6dae680c1ae6f26c4019569176f20d5ee90bf`; review token `0f07aa1f7cab425b8b11f274f2f7724d4bab06550292ea547c7d010f12911a70` |
| Code SHA-256 | generator `e9ed2f5e15a86f270104ea8b3f48002d1d88c119cac2924cfc6431c82b65b153`; tests `5d8debe1d77bd9dbdfe9895cfffb0c7104524171a1229e510f55ed40eb59631c` |
| Local run | Python 3.13.5; compilation PASS; **3/3** synthetic score/control methods PASS; actual archived 34-pair review generation PASS. No browser screenshot success (headless Chromium attempt timed out). |

These are existing, reverified native **images** and receipt hashes; the new operation is source inspection, review-packet construction and offline scoring. The pair-level visual review has **not yet been completed**, so **no numeric visual theme-recognition or aesthetic acceptance result exists**. Known symbolic failures remain the `ribs` theme-field error and `veins` primary-motif error despite successful native execution; both remain in the answer key and appear in post-score failure summaries. Raw 34/36 (94.4%) first-pass schema and native request yield remain below the fixed 95% and 98% targets.

## Reproduce and assess without leaking final data

Extract the named owner Library archive and its nested `native/model-evidence.zip` to a private directory. Use the unmodified `native_model_lfm400_attempt2` folder:

```sh
python evaluation/test_blind_native_review.py --packet /private/model/native_model_lfm400_attempt2
python evaluation/blind_native_review.py build --packet /private/model/native_model_lfm400_attempt2 --output /private/new-review
# Open /private/new-review/review.html, assign each pair one family, export JSON.
python evaluation/blind_native_review.py score --key /private/new-review/answer_key.json --responses /private/review-responses.json
```

The output directory must not exist before `build`. The generated review HTML has no network dependencies. Keep the answer key separate from the person classifying images until their responses are frozen. Do not treat repeated seeds or paraphrases of one structural family as independent heldouts. Do not use final-assessment records here.

## Source status and decision

Accepted main remains `63f8b1ba6559906fe85f3ad0269aa296e4141d67` including #563. #564 is Draft at `6319ab1d94d85d01c9cdb44d973a92d224bfa9aa`; #565 is Draft at `d66499ec3409fb657875fca7dbd0f234cf28ca49`. Its [source-matched request-4 run 43358127824](https://github.com/techrote/cybersand/actions/runs/43358127824) completed **failure** at 2026-11-13 04:00 UTC, so there is no independently qualified successor Windows release to consume. A new source-compatible native qualification and real blind owner review remain the next gates.

**HOLD.** The fixed raw-schema 95%, constrained-schema 99% (only if actually exercised), 98% positive native request yield, 80% group-aware visual theme recognition, and zero observed host-invariant-violation targets are unchanged. No training, source-owner changes, repository defaults, Ready or merge.
