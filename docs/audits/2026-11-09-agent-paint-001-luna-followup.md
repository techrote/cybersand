---
title: AGENT-PAINT-001 Luna follow-up — persistent editing and erasure
status: Current
document-kind: evidence
scope: 9 November 2026 owner-supplied Luna workbench follow-up traffic, native receipts, PNG integrity and rate pacing
canonical-for: []
last-reviewed: 2026-11-09
related-documents: [2026-11-09-agent-paint-001-exploratory-model-authoring.md, ../architecture/shared-workbench-authoring-data.md, ../operations/atlas-agent-runner.md]
---

# AGENT-PAINT-001 — Luna continuation, erase and rate-pacing follow-up

**Observational follow-up only.** This retains a new owner-supplied source alongside, but does not alter the counts, original SHA hashes or scope of, the [initial exploratory comparison](2026-11-09-agent-paint-001-exploratory-model-authoring.md). No model leaderboard, shared-source acceptance, or native replay qualification is implied.

## Original evidence and provenance

- Owner-uploaded `luna.zip` SHA-256: `02e2c56bd80607197625e97083f8ebf625c53dcdf98a272dcc97de70bb81a539`.
- `events.jsonl` SHA-256: `2884a0bd287b65c070f5fa0ed40c9b04a910f9eb2aff5399ff35511d11bb4522`. Parsed **470 JSONL records** spanning 23:07:09–23:12:16 UTC on 9 November 2026, one visible top-level traffic session. Two distinct Luna runner terminations are present.
- Twenty PNG captures, each 2519×1417 pixels, all content SHA-256 hashes identical to their archive filenames. Owner's separate four-figure comparison screenshot SHA-256: `12af79847930479977b0e3413ffd4d7ce4a59b58e293ce2f8bbf0c7c2f525229`.
- Original full ZIP and PNG captures are owner-retained. **No raw HTTP bodies, payloads, provider IDs, image binaries, machine-local paths, or unfiltered logs are committed to Git.** Selected derived metrics are in [luna-followup-runs.csv](agent-paint-001/luna-followup-runs.csv).

**Important capture boundary:** The first runner was already in progress when the retained JSONL starts; its first 11 model calls are not included as HTTP response events. The second runner has 19 visible HTTP responses and a visible `runner.started` record. Both identifiable native authorization regions were **64×128**, at (192, 0) and (256, 0). The owner's reported unsuccessful **128×128** attempt cannot be independently identified from this ZIP.

## Two recovered runs

| Metric | Run A — visible tail only | Run B — full captured runner |
| --- | --- | --- |
| Model | `gpt-5.6-luna` | `gpt-5.6-luna` |
| Time | Finished 23:08:42 UTC; 163.021 seconds reported | Started 23:09:02 UTC; finished 23:12:16 UTC; 193.657 seconds reported |
| Native region | x=192, y=0, 64×128 | x=256, y=0, 64×128 |
| Model calls / tool calls (final receipt) | 18 / 18 | 19 / 18 |
| Applied edit batches (final receipt) | **5** | **5** |
| Usage, input / output tokens | 48,641 / 3,701 | 55,533 / 3,226 |
| Completion reason | **`host_stop_requested`**; native Stop ACK recorded | **`model_final_not_native_proof`**, `unverified_native_acceptance` |
| Native receipt scope | Captured tail contains 2 applied batches and 1 later unapplied prepared proposal; early applications are outside captured HTTP tail | All five applied batches visible; final signed-source readback is not an independently rerun test |
| Tool-validation refusals | None in captured tail | Two `invalid_or_stale_observation_id` client refusals (23:09:25, 23:10:29 UTC), followed by further observation/editing |
| Rate-pacing events | 9 recorded waits totalling 95.92 seconds **in captured tail** | 16 recorded waits totalling 143.80 seconds |

### Confirmed erasure, and its limits

Run A's visible HTTP response at **23:07:15** submits **eight `prepare_edit` primitives with material `0`** (Empty/Erase), followed by `apply_edit` at **23:07:16**. The stored native receipt reports **301 confirmed writes**, with before=58 (Hard Wall), actual=0 (Empty), and authored-start recording. A subsequent wall repair/refinement at **23:08:11** recorded 158 confirmed writes. The last **23:08:33** prepared proposal was not applied before human Stop at 23:08:42.

Run B performs a complete **observe → prepare → apply → observe** multi-step authoring sequence and uses five applied batches comprising **38 material-58 wall primitives** (8+8+8+8+6). It contains **no captured erase primitive**; negative spaces in the final screenshot or native empty-cell tally cannot establish deletion by that runner. The final five native apply receipts report a combined **3,649 confirmed changed-cell writes**; the model's final text cites 3,649 wall and 4,543 empty cells in the region, totalling 8,192. This is a captured native receipt/report, **not** a successful independent test or a proof of visual quality. The first run's cumulative five applied edits are supported by the runner final summary, but only the last two were in the traffic tail.

Both finish records explicitly mark the relevant native acceptance gate **not passed** (completed_ticks 0, with no expected tick target). Run B's own textual assertion that the drawing succeeded must therefore not be promoted to product-level acceptance.

## Why it appeared to stall

The traffic exposes **rate scheduler pacing**, not just model deliberation. The policy was configured to **50,000 tokens/minute** with a maximum per-response output cap of 32,768 tokens. Run B reports 16 `rate.wait` events summing to **143.8 seconds** of its 193.7-second elapsed time; significant single waits include about 31.2, 33.1 and 42.6 seconds. These local estimates should not be treated as authoritative external provider service-time metrics, but they explain long apparent no-action intervals. Run A was manually stopped while the scheduler had recorded a 36.7-second wait request. Investigate whether the reservation strategy and response-token ceiling can be tightened safely for concise structured tool calls without starving legitimately long responses.

**Current lesson:** Luna did continue through multiple edit batches, used erase successfully in one runner, and later terminated another 64×128 run with its own final response. A bounded revision/cancellation/progress UX remains worthwhile. Do not claim the unsuccessful 128×128 attempt is reproduced from this archive or that the second run employed erase.

## Validation and omissions

Performed: static ZIP/file enumeration, all 20 PNG hash checks, JSONL parse, extraction of provider function arguments, native apply/readback receipt inspection, runner-completion and refusal review, numeric token and wait accounting. **Not performed:** replaying native operations, reconstructing original source HEAD, verifying every screenshot against actual World cell state, or running Windows/Godot/CI checks. As in the parent audit, this registration is not Ready/merge authority for #531, #542, #543 or this draft documentation PR.
