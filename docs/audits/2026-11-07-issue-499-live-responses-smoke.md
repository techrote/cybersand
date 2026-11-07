---
title: "MAP-AUTO-02 #499 live Responses API smoke tests (2026-11-07)"
status: Current
document-kind: evidence
scope: Dated record of three real, charged gpt-6-luna runs of the Atlas agent runner (two on the bundled synthetic fixture, one critique-only run on real Atlas art with genuine Godot captures), with retained receipts, hashes and explicit gaps
canonical-for: [issue-499-live-smoke-2026-11-07]
last-reviewed: 2026-11-07
related-documents: [../operations/atlas-agent-runner.md, ../operations/github-development-and-release.md]
---

# MAP-AUTO-02 #499 live Responses API smoke tests

**Result.** Three genuine runs through the official `openai` SDK (3.46.0) against the live Responses API with model
`gpt-6-luna`: run 1 was cleanly **stopped** by its own iteration limit; run 2 **succeeded** with a verifiable receipt,
at about **USD 0.0012** computed from reported usage (ceiling USD 0.25). This proves the live request shape, the
credit gate, stateless (`store: false`) reasoning replay, strict function tools, image input, the bounded edit and
the receipt on this fixture. It does **not** prove a Godot-rendered improvement, a model-made edit on real Atlas art, the
optional Costs API cross-check, or a reconciliation with the billing dashboard. Run 3 (below) additionally shows a
critique of genuine Godot captures of the real `lumen-fault` collection.

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

## Run 3: real Atlas art, genuine Godot captures (critique only)

| Item | Value |
|---|---|
| Source | art branch head `c4aab63eed538a25687c66d368b0801d2d2e04d0` (read-only sparse worktree, clean, pinned with `expected_source_sha`); collection `lumen-fault` (Terrain Art, writable) |
| Runner code | `c9eb5b485d1aa697b77f8e2f1be1136419e67204`, tree clean (recorded in the receipt) |
| Input evidence | genuine #498 capture bundle (PR #506 head `7b960b5e`, Godot 4.7 console build, `opengl3_angle`): `full` 1280x512, `viewport` 1920x1080, `detail` 1920x768; bundle seal `a81f9954ca61ab221db08cb8853f893a88a81644b743a7d59d75b9af65cde564`, evidence class `godot-capture`, verified independently by the runner |
| Limits | 18 iterations, 20 calls, USD 0.25 ceiling; same attestation and authorisation as runs 1-2 |
| Outcome | `success`, exit 0: 7 real responses, 11 tool calls (inspect, baseline `validate_pack.py` pass, 3 `view_image`), no retries/violations; 53,603 input (31,116 cached) / 1,249 output (240 reasoning) tokens; computed cost USD 0.003184 |
| Model report | `critique_only`: seven-dimension critique of the real Godot images (scores 4-5, with concrete observations such as a visually busy central collapse and near-continuous orange deck-edge marks) and two revision proposals; it **made no edit**, judging the tightly authored geometry safer untouched |
| Claims | `visual_cycle.claimed` is **false** (no edit, no after-capture); no improvement is claimed |

A separate no-cost dry run on the same real collection exercised the whole pipeline with a scripted edit: real
Python and Node validators, an after-capture rendered by the real launcher (class `godot-capture`), and a
before/after comparison showing the pack and all three images changed. It is not a model result and claims nothing.

## Retained evidence

Directory `docs/audits/issue-499-live-smoke-2026-11-07/` (credential-scan clean, sealed receipts verify with
`verify-receipt`):

| File | SHA-256 of file | Sealed `receipt_sha256` |
|---|---|---|
| `run1-stopped-receipt.json` | `e92bf134665f24a766e359128d06523f56729eea25f518d5c1510bba9e1e90e0` | `273eafb7e3e1eb61665323be97542ab10343c98efc70723146d3f8968d3dbed7` |
| `run2-success-receipt.json` | `5da47c7cd4359fcc9d2a401e1f3377648d489499e9b8f5eda490600d3001c3ed` | `1db066498047f7d7142d56eaa5b1a96be456e59d82b9f8e030bee6b343b11bd7` |
| `run2-patch.diff` | `bc0724037e26523014c07bd2e3195ae99ec950d3a3f8798c885b64109f78dc55` | patch hash recorded in the receipt |
| `run3-real-art-critique-receipt.json` | `f524ca6b2bff45cf63f73805175b286f18d1cd1a6840a435e734896577529f25` | `fd59274c63f2c5074e2ab24a59cd326a25ad854cca56390b3e2feb85102de322` |

Command shape (key only in the environment): `python tools/atlas_agent_runner.py run --config <live config> --output-dir <new dir>`.

## Gaps

- Cost is token counts times published rates, **not a bill**; compare the dashboard's usage for the day to confirm.
- `x-ratelimit-*` and organisation/project headers were not returned by the model probe, so no project identity was recorded.
- The live Costs API cross-check was not exercised (no admin key); `expected_project` was not set.
- Runs 1-2 used a flat fixture raster. Run 3 used genuine Godot captures but the model made no edit, so no model-driven before/after Godot cycle has been demonstrated; the #498 PR (#506) is still an unmerged Draft that the runner reads only through its documented CLI.
- One model, one machine: not a quality, performance or Linux-hosted run. Real art was read with the pack formatted one number per line (about 19,000 lines).
