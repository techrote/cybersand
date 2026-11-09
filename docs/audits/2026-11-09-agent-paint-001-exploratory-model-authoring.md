---
title: AGENT-PAINT-001 exploratory agent painting evidence
status: Current
document-kind: evidence
scope: Owner-supplied 8–9 November 2026 workbench agent-authoring sessions and comparative tool-use data
canonical-for: []
last-reviewed: 2026-11-09
related-documents: [../architecture/shared-workbench-authoring-data.md, ../operations/atlas-agent-runner.md, ../systems/explore001-generated-playable-maps.md]
---

# AGENT-PAINT-001 — exploratory model-driven painting

**Disposition: observational evidence, not a controlled model benchmark, native acceptance test, source admission, or release qualification.** No simulation, native worker, Godot controls, permissions, or material behavior are changed.

## Original evidence and integrity

The owner supplied workbench.zip, a separate setup-model-canvas.json, and annotated comparison screenshots. ZIP inspection parsed the JSONL without executing its content and hash-checked all 32 PNG members against their SHA-256 filenames.

| Item | Observed data |
| --- | --- |
| Original ZIP SHA-256 | 941698f8db8c6e01a878070a35b519b92305bfd278a34820e3fec38d3adb5526 |
| Embedded events.jsonl SHA-256 | f5b7d1423e1d58b21248f65632da3eacb66e633b0b53873fc9df62bece57068f |
| Traffic extent | 5,442 events, 35 session IDs (some startup/refusal-only), 59 runner.started and 52 runner.finished events |
| Image evidence | 32 content-hash-verified 1920×1080 PNG captures |
| Canvas SHA-256 | 8f1b276aac5a13d5cef55e143ee45e6a5bab0afabee7b1b888ef671cc5660b3c |
| Canvas format | Setup-v2, extent 2048×2048, zero actors, 1,277 edits (1,274 hard-wall rectangle records of material 58, three four-field sand stamps of material 2) |
| Runtime source SHA | Not recovered/independently established from this export; do not infer identity from the contemporary accepted-main revision |

The checked-in [Setup-v2 canvas](agent-paint-001/setup-model-canvas.json) is a **combined authored result**, not a common blank starting fixture or an independent output for any one model. It records authored starting materials, **not** evolved simulation state.

Raw traffic has full HTTP request and response bodies, identifiers and image payloads. Repository policy prohibits raw logs, secrets, and machine-local configuration. Therefore only the curated observations, selected numeric metrics and composite canvas fixture are committed. The original traffic ZIP and screenshots remain owner-retained; the SHA-256 identifiers above permit later reconciliation.

## Evidence from selected runs (UTC 9 November 2026)

The [selected-runs CSV](agent-paint-001/selected-runs.csv) records model, task, authorised region dimensions, calls, tool proposals, applied edit batches and token usage. Primitive totals are **proposed** tool operations (some proposals were rejected or left unapplied), not changed cells or verified net new material.

| Start UTC | Model | Task | Calls | Applied edit batches | Proposed primitives | Wall / erase |
| --- | --- | --- | ---: | ---: | ---: | --- |
| 21:52:30 | GPT-5.6 Terra | add robot (64×128) | 5 | 1 | 8 | 8 / 0 |
| 21:52:56 | GPT-5.6 Luna | add robot (64×128) | 5 | 1 | 7 | 7 / 0 |
| 21:53:29 | GPT-6 Astra | add robot (64×128) | 11 | 3 | 24 | 24 / 0 |
| 21:57:52 | GPT-5.6 Terra | add robot (128×256) | 15 | 4 | 33 | 32 / 1 |
| 21:59:49 | GPT-6 Astra | add robot (128×256) | 8 | 2 | 16 | 11 / 5 |
| 22:01:35 | GPT-6 Astra | detailed Gundam cyberpunk graphic (128×256) | 30 | 10 | 80 | 50 / 30 |
| 22:13:10 | GPT-6 Astra | Gundam cyberpunk statue tower (256×512) | 27 | 8 | 64 | 38 / 26 |

The Terra 33 includes one prepared proposal beyond the four applied batches; 33 proposed primitives must not be reported as 33 successfully applied primitives.

The statue tower recorded 92,255 input and 3,427 output tokens, 27 model calls and eight applied edit batches. The earlier Gundam graphic recorded 111,896 input and 4,155 output tokens, 30 model calls and ten applied edit batches. Both sessions ended with human host_stop_requested rather than model-declared finished status. Billing was marked unknown-unpriced-model; do not infer a verified USD cost.

### Tool-use behavior supported by the trace

- Repeated loops are observe → prepare_edit → apply_edit → observe. Astra frequently saturates the eight-primitive-per-proposal capacity, consistent with the eight-primitives/4096-cell baseline of [WB-AGENT #525](https://github.com/techrote/cybersand/issues/525).
- The tool schema **already has rectangles, lines and discs**. A future macro planner should decompose complex geometry into existing bounded, independently validated native proposals; simply raising the existing admission cap would bypass a separate safety/performance design decision.
- Material 58 is hard wall; 0 is erase. The two longer Astra tasks mixed wall and erase in five and three individual proposals respectively. This supports a build-and-carve/revision strategy.
- Terra also mixed wall and erase in one proposed edit in its longer robot attempt; this capability is **not exclusive to Astra**.
- Runs concluding with model_final_not_native_proof / unverified_native_acceptance must not be counted as product-level native acceptance; real material receipts and independent source-scoped tests are distinct.

### Benchmark limitations

The tasks, authorised regions, sizes, inherited composite scene, earlier edits, permitted materials, number of calls, feedback history and usage budgets varied. Some sessions ended on human Stop; others on model final, refusals or cancellation. Artistic quality comparisons in screenshots are owner observations. This study **does not establish a fair cross-model ranking**, and its returned PNG images alone do not prove native material correctness.

## Next controlled experiment (Planned; no implementation authorised)

Clone an identical blank or specified Setup-v2 fixture for every run, isolating native World, prompts, permission scopes, material palette, tool schema, protected areas, starting image and call/token/wall-clock budgets. Preserve before/after native receipts and cell hashes, rejected proposals, actual applied primitives and matched viewport captures. Score task quality, geometric fidelity, repair actions, material correctness, tool calls and tokens separately; use model-blind human visual review.

For authoring throughput, investigate scene-level macro decomposition **above** the existing eight-primitive / 4096-cell proposal boundary, retaining scope and protection checks and real native apply receipts. Any production contract change belongs to the separate #525/#531 agent lane and [PAINT-001 #543](https://github.com/techrote/cybersand/issues/543).

## Additional Luna continuation evidence — 9 November 2026

The owner subsequently supplied [a separately captured Luna 64×128 follow-up](2026-11-09-agent-paint-001-luna-followup.md), recording 18- and 19-call executions with five applied edit batches each, one confirmed 301-cell erase, and measurable rate pacing. Its ZIP and screenshot identities are preserved independently; it does **not** change the earlier exploratory comparison's source scope or make the model trials controlled.

## Validation record

Performed: source ZIP enumeration, complete event parse and category counts, SHA-256 hashes, verification of 32 PNG content-addressed filenames, extraction of tool proposals and provider-reported tokens, and structural inspection of the Setup-v2 fixture.

Not performed: source HEAD reconstruction, native replay, Windows/Godot acceptance, screenshot-to-cell reconciliation, controlled equal-budget rerun, documentation CI or an independent benchmark-quality verdict. This registration is documentation and fixture only. It conveys no Ready or merge authority for #531, #542 or #543.
