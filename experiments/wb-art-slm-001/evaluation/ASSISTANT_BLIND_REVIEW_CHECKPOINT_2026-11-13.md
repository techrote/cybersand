# WB-ART-SLM-001 — first key-blind AI visual recognition of real native model readbacks

Date: 2026-11-13. Owner: Evaluation. Role branch: `codex/wb-art-slm-evaluation`. This is **one AI-assistant visual review**, not a human or owner acceptance result and not final assessment. The source candidate, frozen model programs, compiler, native packets, labels and native Art harness are unchanged. **Production GO/HOLD: HOLD.**

## Frozen stimulus and review procedure

- Source: the existing 34-card / 68-PNG [blinded material-readback gallery](blind_model_review.html), checked against SHA-256 `5f554c67c928d6f940126d07c529df89694a42d6cdeb7a65c7b9c4413f354877`. These are historical Linux headless native **material** displays, two host seeds (17 and 73) per admitted request; not actual Windows/graphical screenshots.
- The AI reviewer inspected three contact sheets showing only `q001`…`q034` and the two real seed images. It chose **one** of twelve families for each request; no confidence, aesthetic or variety ratings were invented. The reviewer knew the vocabulary and prior audit concerns but **did not inspect the qID answer mapping before freezing labels**.
- The initial raw response bytes were saved and SHA-256 recorded **before opening the separate answer key**: `746c6b71b775f7be03c09a998dbf56dcbf5c06817f28c9a5a98c800359d73357`. See [byte-exact frozen label receipt](assistant_blind_review_frozen_labels_2026-11-13.json).
- After freezing, the separate answer key (SHA-256 `1bcac225ca5d5674a042a750e3d6dae680c1ae6f26c4019569176f20d5ee90bf`; Git blob `37bc697f7432bc90ba1a3174ae0e8ec58944f285`) was opened. The [scorer-compatible response](assistant_blind_review_responses_2026-11-13.json), SHA-256 `f0f688049cf077c25905049917272b6f06ad6db3ea5f770f5c2a7fa8191a0ed5`, adds only empty optional `quality`/`variety` fields and metadata; all 34 original qID→family choices are unchanged. Neither the initial prediction nor native evidence was repaired.

## Actual measurement

| Metric | Observed | Interpretation |
| --- | ---: | --- |
| Original model requests | 36 | Includes both refused malformed coral completions |
| First-pass native-admitted requests | 34/36 = **94.44%** | Below fixed raw-schema **95%** and native-request **98%** targets |
| Displayed native replays | 68/68 | Conditional on admission; historical Linux pilot only |
| AI visual classifications correct, admitted | **29/34 = 85.29%** | Single AI reviewer, **not human** |
| AI visual classifications correct, all original requests | **29/36 = 80.56%** | Two original malformed coral requests each count as failure |
| Structural-group macro accuracy (admitted) | **20/23 = 86.96%** | Groups, not host seeds, are units; 95% group bootstrap `[73.913%, 100.0%]` |
| Structural-group macro accuracy (all original) | **20/24 = 83.33%** | Adds rejected coral group as zero |
| Development cohort, admitted | 18/22 | Four visual failures |
| One-word keyword cohort | 11/12 | One visual failure |
| Quality / subjective variety | **not rated** | No numeric aesthetic result |

All five incorrect AI labels are retained, not repaired or discarded:

| Card | Expected | AI guessed | Diagnosis |
| --- | --- | --- | --- |
| `q001` | dunes | ribs | Development dunes group, visually ambiguous band-and-border composition |
| `q003` | veins | circuitry | Keyword case whose recorded **primary motif is wrong** despite native pass |
| `q009` | strata | dunes | First of two same-group strata development failures |
| `q011` | strata | dunes | Repeated same-group error, not a fresh independent template |
| `q024` | dunes | strata | Second error in the same development dunes group |

The known `keyword-ribs` semantic theme-field error is still present in the frozen model evidence, though its native image was visually classified as ribs. Correct visual classification does **not** retroactively repair symbolic metadata.

The exact identical pair `q004/q007` contributes two original requests to the 34 denominator but is not two independent visual stimuli. Collapsing one identical pair would give an **exploratory** 28/33 = 84.85% review-stimulus sensitivity (not a new model request-yield or revised acceptance denominator). The pixel-morphology audit separately identified three near-duplicate clusters; its 31/34 metric is not a human diversity score.

## Executed independent checks

- Opened the original gallery with a local parser and constructed all three qID-only, two-seed sheets; frozen the 34 raw labels before accessing the answer key. Verified gallery SHA-256 and original raw response SHA-256.
- Retrieved both published GitHub response files and the original answer key. Independently recomputed **29/34**, **29/36**, per-theme/cohort outcomes, 23/24 structural-group macro results and the five exact confusions.
- Six source-bound normalization/adversarial controls **PASS**: valid unchanged response, modified family, altered review token, duplicate qID, missing row, and fabricated optional rating. Both committed response files have the expected 34 labels; the scorer-compatible one has 34 empty optional ratings.
- The existing canonical [`blind_native_review.py score`](blind_native_review.py) remains the reproducible Python scorer. **Its exact module was not executed locally in this review**; the independent cross-check used the same declared denominators and group-macro formulas against GitHub's original key.

Reproduction from the Evaluation branch, using Python 3.12+ and no model/Godot job:

```sh
python3 experiments/wb-art-slm-001/evaluation/blind_native_review.py score \
  --key experiments/wb-art-slm-001/evaluation/blind_model_review_answer_key.json \
  --responses experiments/wb-art-slm-001/evaluation/assistant_blind_review_responses_2026-11-13.json
```

The normalized response contains `reviewer_type` for explicit non-human provenance. The current scorer correctly retains `go_no_go=HOLD`; a single AI review **does not establish** the human 80% theme-recognition gate. Inspect a source-compatible #565 successor and actual Windows/Linux Art execution separately. The accepted 400-step adapter, 15 historical native gates, first-pass errors, originally failed long-name fixture and corrected ID-only alias remain unchanged.

## Engineering diagnosis and handoff

This is the first executed **visual** classification of the admitted model gallery, distinct from symbolic labels, pixel hashes and native gate success. Four of the five errors cluster into only two development structural groups: dunes vs strata. The remaining failure (`q003`) is the known wrong-motif veins/circuitry model completion. Those are bounded **development** feedback targets for Training and Corpus; no FINAL set was read or retired. A new frozen candidate should demonstrate improvement against the same raw failure denominator, and any claimed model-family ranking must use matched tuned candidates, not tuned-versus-untuned.

**GO (limited):** inspectable, source-identified AI visual review record and 6/6 validation controls. **HOLD:** true human/owner recognition acceptance; new model improvement; fresh current-source Windows/Linux and native protection/Stop/interleaving/history/persistence qualification; full Draft #567 CI until Controls' owner fix is consumed. No training, paid compute, native rerun, main/source-owner changes, new PR, Ready or merge.
