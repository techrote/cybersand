# WB-ART-SLM-001 — Blind model-gallery pixel morphology audit

Date: 2026-11-13. Owner: Independent Evaluation. Branch: `codex/wb-art-slm-evaluation`. This is executed **development-gallery** evaluation, not new model inference or native execution.

## What ran

Implemented `measure_native_stimulus_pixels.py`, an offline, standard-library PNG pixel decoder/auditor. It reads the **actual frozen HTML** `blind_model_review.html`, refuses a different HTML SHA-256, verifies all card/seed IDs, decodes each PNG IDAT under a strict size bound, checks chunk CRC, RGB8 dimensions, PNG filters and the two measured native material-display colours, then analyzes foreground-cell sets. No theme labels, prompts, answer key, corpus final data or native/teacher gallery are read. Source PNGs remain unchanged.

Input: `blind_model_review.html`, 128,461 bytes; SHA-256 `5f554c67c928d6f940126d07c529df89694a42d6cdeb7a65c7b9c4413f354877`. This is the existing frozen 34-card/68-image **model-output gallery**, based on the historical Linux headless native-material pilot at `90719c72b9fcf90593fb7878354051ad601b47fd`. The source is not a current-main, Windows or graphical acceptance build. The original 36 request denominator and 2 malformed coral completions are unchanged.

Ran `python -m unittest -v test_measure_native_stimulus_pixels.py` locally on Linux: **6/6 passed**. Tests reject incorrect HTML hashes, duplicate IDs, mismatched seeds, external images, PNG CRC/payload corruption, unexpected palettes/filters, empty artwork and truncated pairs. Ran the exact frozen HTML through the auditor and saved `pixel_stimulus_morphology_audit.json`. This is an independent material-*display*-pixel measurement, not a substitute for original numeric native material receipts. The separately qualified source receipts and original evidence remain binding.

## Results — blind cards only

| Metric | Measured |
| --- | ---: |
| Native-admitted original requests / model-output cards | 34 / 34 |
| Actual displayed PNG images | 68 |
| Foreground occupied fraction, min / median / max | 1.27% / 11.56% / 36.50% |
| Within-request seed-17-versus-73 foreground Jaccard min / median / mean / max | 0.0447 / 0.3206 / 0.3848 / 0.8543 |
| Seed-pair Jaccard below 0.20 | 14 / 34 requests |
| Seed-pair Jaccard at least 0.80 | 4 / 34 requests |
| Exact duplicate two-seed PNG pairs | q004 ↔ q007 (prior result confirmed) |
| **Exploratory near-duplicate two-seed pixel pairs**, BOTH aligned seed Jaccards ≥0.85 | **3 pairs** |
| Distinct clusters under that exploratory near-duplicate rule | **31 / 34** |

New near-duplicate groups **q003/q032** (Jaccard 0.879/0.967) and **q020/q029** (0.995/0.991) are not byte-identical, so the prior PNG-hash audit missed them. The third pair, **q004/q007**, is exactly identical at both seeds (1.000/1.000). All are blind card identifiers, not theme claims. The 0.85 cutoff is an **exploratory morphology diagnostic**, not an agreed recognition threshold or a new acceptance gate. No clustering of host seeds as independent structural templates is allowed.

## Decision and follow-up

**GO for the source-bound historical-model PNG morphology diagnostic only. HOLD for WB-ART-SLM production promotion.** This proves additional low-variation/repeated visual exposure, not aesthetic quality or blind theme recognition. The fixed raw-schema 95%, constrained-schema 99% when actually executed, positive-request native-yield 98%, blind group-aware theme target 80%, and zero observed host-invariant violations are unchanged. Raw and native request yield remain 34/36 (94.4%), below their targets. Distinct model-semantic `ribs` and `veins` failures remain. No training, final evaluation, source-compatible native rerun, Windows campaign or human review took place.

For independent reproduction, use the frozen HTML and run:

```sh
python evaluation/test_measure_native_stimulus_pixels.py
python evaluation/measure_native_stimulus_pixels.py \
  --html evaluation/blind_model_review.html \
  --expected-html-sha256 5f554c67c928d6f940126d07c529df89694a42d6cdeb7a65c7b9c4413f354877 \
  --output /tmp/new-pixel-audit.json
```

Preserve the existing 34-card blind review unchanged. Before visual acceptance, assess whether repeated and near-repeated pairs distort a rater's exposure, and freeze the rater responses before opening the separate key. Integration may consume these Evaluation-only files after checking source hashes. Current main preserves accepted #563; #564/#565 successors must independently provide source-compatible actual native, Stop, protection, mask, history and Windows qualification. No combined Draft #567, physics, materials, model or unrelated schedule was modified by this role.
