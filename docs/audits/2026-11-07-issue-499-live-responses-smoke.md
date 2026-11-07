---
title: "MAP-AUTO-02 #499 live Responses API smoke test (2026-11-07)"
status: Current
document-kind: evidence
scope: Dated record of two real, charged gpt-6-luna runs of the Atlas agent runner on the bundled synthetic fixture, with retained receipts, hashes and explicit gaps
canonical-for: [issue-499-live-smoke-2026-11-07]
last-reviewed: 2026-11-07
related-documents: [../operations/atlas-agent-runner.md, ../operations/github-development-and-release.md]
---

# MAP-AUTO-02 #499 live Responses API smoke test

**Result.** Two genuine runs through the official `openai` SDK (3.46.0) against the live Responses API with model
`gpt-6-luna`: run 1 was cleanly **stopped** by its own iteration limit; run 2 **succeeded** with a verifiable receipt,
at about **USD 0.0012** computed from reported usage (ceiling USD 0.25). This proves the live request shape, the
credit gate, stateless (`store: false`) reasoning replay, strict function tools, image input, the bounded edit and
the receipt on this fixture. It does **not** prove a Godot-rendered improvement, behaviour on the real Atlas
art, the optional Costs API cross-check, or a reconciliation with the billing dashboard.

## Identity and authorisation

| Item | Value |
|---|---|
| Date / host | 2026-11-07, owner's Windows 11 machine, Python 3.13, `openai==3.46.0`, key supplied only through the owner's own terminal environment |
| Source head | `a14ff2caf83b41bbc0dda65388cc40cc3d63f9fd` (PR [#516](https://github.com/techrote/cybersand/pull/516)), working tree clean |
| Collection | bundled synthetic fixture `mini-vault` (lane Terrain Art, writable), one fixture capture bundle (evidence class `fixture`, **not** Godot) |
| Model | `gpt-6-luna`, `reasoning.effort` low, image detail high, `store: false`; the API reported the same model id |
| Rates used | USD 0.10 input / 0.01 cached input / 0.50 output per 1M tokens, read on 2026-11-07 from the published pricing and model pages (no image rule is published for this model; a conservative bound was used) |
| Spending authorisation | Owner go-ahead in the session chat; ceiling USD 0.25 per run, USD 0.05 per call |
| Credit attestation (owner, from the billing overview) | Free-trial API credit USD 88.00, next expiration USD 88.00 on 2026-11-27, no payment method on file, auto-recharge off; the dashboard lists no model restriction. The runner cannot verify these itself (`headroom_basis: owner-attestation-only`). |
| Gate | every check passed, including an uncharged `models.retrieve` for `gpt-6-luna` |

## Runs

| Run | Config difference | Outcome | Calls / tool calls | Tokens in (cached) / out (reasoning) | Computed cost |
|---|---|---|---|---|---|
| 1 | defaults (8 iterations) | `stopped` / `max_iterations`, exit 4, no report, no patch | 8 / 12 | 23,220 (18,102) / 559 (191) | USD 0.000972 |
| 2 | `max_iterations` 14, `max_api_calls` 16 | `success`, exit 0 | 9 / 13 | 28,931 (25,327) / 1,165 (158) | USD 0.001196 |

Run 1 shows the fail-closed limit working: the model issued about one tool call per response, so it ran out of
iterations before `submit_report`. Run 2 inspected the pack, ran the validator, viewed the fixture image, made one
bounded `replace_text` edit (a 2x2 rusted-steel accent on the copper rail), saw its own `render_check` fail because
the preview was stale, regenerated it with `render_write`, re-validated, and submitted a seven-dimension critique
with proposals. The runner's own final `validate` and `render_check` passed; the exported patch
(`run2-patch.diff`, two files) applies cleanly with `git apply --check` and the patched fixture re-validates
(9 rectangles) and matches its regenerated preview. Reserved worst-case total USD 0.026; no retries; no
possibly-charged attempts; `visual_cycle.claimed` is **false** (fixture evidence, no after-capture).

## Retained evidence

Directory `docs/audits/issue-499-live-smoke-2026-11-07/` (credential-scan clean, sealed receipts verify with
`verify-receipt`):

| File | SHA-256 of file | Sealed `receipt_sha256` |
|---|---|---|
| `run1-stopped-receipt.json` | `e92bf134665f24a766e359128d06523f56729eea25f518d5c1510bba9e1e90e0` | `273eafb7e3e1eb61665323be97542ab10343c98efc70723146d3f8968d3dbed7` |
| `run2-success-receipt.json` | `5da47c7cd4359fcc9d2a401e1f3377648d489499e9b8f5eda490600d3001c3ed` | `1db066498047f7d7142d56eaa5b1a96be456e59d82b9f8e030bee6b343b11bd7` |
| `run2-patch.diff` | `bc0724037e26523014c07bd2e3195ae99ec950d3a3f8798c885b64109f78dc55` | patch hash recorded in the receipt |

Command shape (key only in the environment): `python tools/atlas_agent_runner.py run --config <live config> --output-dir <new dir>`.

## Gaps

- Cost is token counts times published rates, **not a bill**; compare the dashboard's usage for the day to confirm.
- `x-ratelimit-*` and organisation/project headers were not returned by the model probe, so no project identity was recorded.
- The live Costs API cross-check was not exercised (no admin key); `expected_project` was not set.
- The image was a flat fixture raster; no Godot capture exists yet (#498 integration remains contract-tested only).
- One model, one small fixture, one machine: not a performance, quality or Linux-hosted run.
