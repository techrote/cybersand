---
title: Atlas agent runner (credit-aware Responses API workflow, MAP-AUTO-02)
status: Current
document-kind: runbook
scope: How to run, budget, secure and audit the bounded OpenAI Responses API agent that critiques and edits one Atlas collection; what is verified offline and what is not yet verified against the live API
canonical-for: [atlas-agent-runner]
last-reviewed: 2026-11-24
related-documents: [github-development-and-release.md, documentation-maintenance.md, ../reference/status-and-roadmap.md, ../reference/retrieval-index.md, ../audits/2026-11-07-issue-499-live-responses-smoke.md]
---

# Atlas agent runner (MAP-AUTO-02, [#499](https://github.com/techrote/cybersand/issues/499))

**Current implementation:** the bounded runner, gates, receipts and manual
workflows are present in accepted source. This tooling edits a separate Atlas
collection in a disposable workspace; it is not the ordinary Art Workbench,
Batch Lab, Gremlin or an accepted autonomous art-quality pipeline.

**Dated qualification:** the [7 November record](../audits/2026-11-07-issue-499-live-responses-smoke.md)
retains synthetic and real-art live attempts, genuine Godot capture cycles,
failures and reported usage estimates. Those attempts do not qualify a later
source, model, pricing table or hosted run. The real-art edit failed artistic
acceptance; optional Costs API and billing-dashboard reconciliation were not
established by that record. No schedule is activated. Earlier spending or task
authorization does not authorize a new paid request or cross-repository write.

## What it is, in plain words

One command (or one manual GitHub Actions run) starts a small robot that works on **one** Atlas collection.
It can read the approved files, run that collection's own validator, look at rendered PNGs, write a critique
against the seven-point rubric and make **one small, checked edit** inside a throw-away copy. It hands back a
**patch and a receipt**; it never pushes, merges or edits the real checkout. Every model call is priced
**before** it is sent, and the whole run stops the moment any limit would be crossed.

## Quick start

No key, no cost (works anywhere with Python 3.10+; the SDK is **not** needed):

~~~bash
python3 tools/atlas_agent_runner.py run --mode dry-run --fixture --collection mini-vault \
  --dry-run-plan tools/atlas_agent/fixtures/mini-vault-plan.json --output-dir /tmp/atlas-run
python3 tools/atlas_agent_runner.py verify-receipt /tmp/atlas-run/receipt.json
~~~

For an **offline dry run** against a separately obtained, read-only art checkout
(never run inside it; `--expected-source-sha` pins exactly the reviewed HEAD):

~~~bash
python3 tools/atlas_agent_runner.py run --mode dry-run --atlas-root /abs/art-checkout --collection lumen-fault \
  --expected-source-sha <40-hex HEAD> --capture-bundle /abs/captures/lumen-fault-before --output-dir /abs/out
~~~

Output directory contents: `receipt.json` (sealed), `patch.diff` (only if edits were made), `tool-log.jsonl`,
`transcript.jsonl`. The last stdout line is `ATLAS_AGENT_RESULT {json}`.

### Live execution security boundary (2026-11-07 qualification)

The hosted `workflow_dispatch` path permits **manual live runs against the synthetic fixture only**, with the existing explicit spending authorisation/credit-attestation gates. A live GitHub Actions run with `source=atlas-ref` fails input validation **before any API credentials are read or chargeable calls are made**: source-supplied Python/Node scripts are pinned by Git blob SHA to reviewed Atlas executables, but a sanitized subprocess environment and script pinning are not an operating-system sandbox. Running these validators under a secret-bearing hosted live process is deliberately withheld until #500 provides separately isolated, no-credentials validation with tested filesystem/network restrictions. The earlier local owner-controlled real-art Responses API smoke remains recorded evidence; no hosted or automatic art-source paid execution is authorised by this document.

### Manual GitHub Actions run

[`atlas-agent-runner.yml`](../../.github/workflows/atlas-agent-runner.yml) is the one documented entry point
(`workflow_dispatch`; no schedule). Inputs: source (`fixture` or `atlas-ref`), collection, lane, Atlas ref and
expected SHA, mode, model, per-run USD ceiling, authorised ceiling, authorisation reference, credit attestation,
max iterations, optional capture-bundle run id/artifact, artifact name. Inputs reach code only as environment
variables and are validated with strict patterns by `tools/atlas_agent/workflow_run.py`. Permissions are
`contents: read` and `actions: read`. The secret `OPENAI_API_KEY` is visible to the live step only. A refused,
failed or rejected run is a **red job** and still uploads its diagnostics.
[`atlas-agent-ci.yml`](../../.github/workflows/atlas-agent-ci.yml) runs the deterministic tests and the complete
dry-run workflow on every relevant pull request, with no key. The accepted source contains both workflows. The earlier pre-merge
`workflow_call`/manual-button limitation belongs to the dated qualification; it
is not evidence that today's runner is unmerged. A new manual live run still
requires its own explicit spending authorization and current gates.

## Live runs: what must be true first

Charged Responses execution is refused (exit 3, no Responses request) unless
**all** of these hold. Gate evaluation can perform model-discovery and optional
Costs API requests; it is not an offline command. They are evaluated together,
so a refusal lists every failing check:

| Check | Meaning |
|---|---|
| `api_key_present` | `OPENAI_API_KEY` is set (never printed; sent only to `api.openai.com` or a loopback test server). |
| `spend_authorised` | `authorised_ceiling_usd` >= `max_usd_per_run` > 0 and an authorisation reference is given. |
| `pricing_known` | The model is in [`pricing.json`](../../tools/atlas_agent/pricing.json) and its rates are younger than `max_age_days`. Unknown models are never priced by guess, substituted or silently downgraded. |
| `credit_attestation` … `model_attested_eligible` | A fresh owner attestation (below): unexpired with margin, enough remaining for one run, API-only grant, auto-recharge disabled, model on the eligible list. |
| `source_clean` | By default the Atlas checkout must be clean. An explicitly configured `task.allow_dirty_source` diagnostic run may pass this gate with local changes; this does not waive source identity, publication custody or owner authorization. |
| `model_retrievable` | `models.retrieve` must return the accepted discovery response; optional `expected_project` must match. Discovery alone does not prove a successful Responses call or artistic result. |
| `costs_crosscheck` | If an organisation admin key is supplied (`OPENAI_ADMIN_KEY`), spend since the attestation is read from the Costs API and the measured headroom must still cover a run. Required when `require_costs_crosscheck` is true. |

**Why an attestation?** This implementation does not obtain credit-grant
balance, expiry or auto-recharge settings from an API. It requires the owner
to check those facts and supply a dated attestation. This describes the current
runner contract, not a claim about every present or future provider endpoint. Codex API-key usage is **not** assumed to be
covered by any promotional credit, and API charges are separate from GitHub Actions compute.

~~~json
{"checked_utc": "2026-11-07T10:00:00Z", "remaining_usd": 5.0, "expires_utc": "2026-12-31",
 "auto_recharge_disabled": true, "api_only": true, "eligible_models": ["gpt-5.4-mini"],
 "source": "platform billing overview, owner check", "attested_by": "owner"}
~~~

Pass it with `--credit-attestation-file` or the `credit_attestation_json` workflow
input. `credit-check --config run.json` checks the live gate without invoking
Responses, but may use configured credentials for network discovery and the
optional Costs API. Use the explicit fixture dry run above for a keyless offline
documentation check. The sample date and amounts are illustrative, not a fresh
attestation or spending authorization.

## Budget and limits

Every attempt (including each retry) first **reserves** a conservative worst case: the estimated input tokens
(pessimistic bytes-per-token plus the published worst-case image tokens) at the uncached rate plus
`max_output_tokens` at the output rate. The reservation must fit the per-call ceiling, the per-run ceiling and
(live) the authorised ceiling. After the response the reported usage (including cached and reasoning tokens) is
priced and reconciled; reported usage above the reservation stops the run. Timeouts, 5xx and dropped connections
keep their reservation as **possibly charged**; 429s and rejected requests are released. A 429 that mentions
quota, billing, credit or a hard spend limit is treated as exhausted credit and is not retried.

The runner accounts for HTTP 429 rate-limit rejections separately: they do **not** consume `max_api_calls`; they are bounded
by `max_retries` per call, `max_total_retries` per run (default 30) and the run time, and are reported separately as
`usage.rate_limited_attempts` (`api_attempts` counts every request). Prompts above the runner's configured 272K-token short-context threshold are refused (`long_context_pricing_not_modelled`)
because long-context rates are not modelled.

Each `render_capture` writes a fresh bundle (`captures/after`, `after-2`, ...) and clears the previous comparison, so a
model may refine and re-render several times; only a comparison of the latest render can support a cycle claim. A run
stopped by a limit or an API failure keeps its unfinished edits as `partial-patch.diff` (`publishable: false`,
`validated: false`) so that raising a limit and retrying need not discard the work.

The local runner defaults and hard caps live in [`config.schema.json`](../../tools/atlas_agent/schemas/config.schema.json) (unknown keys
are rejected; each limit has a maximum, raised on 2026-11-07 at the owner's request for long supervised runs: up to 120
iterations, 200 calls, 600 tool calls, 4 hours, 50M input tokens; the money ceilings and the 272K short-context guard are unchanged). The hosted workflow input is separately limited to 30 iterations and a 30-minute job; local maxima do not enlarge that hosted envelope. Limits: iterations, API calls, retries and exponential backoff, run
seconds, input/output tokens per call and per run, USD per call and per run, tool calls, per-tool and total tool
seconds, tool output bytes, malformed tool calls, sandbox violations, images, image bytes and edge, image resend
window, read/edit bytes, files edited. The SDK's own retries are disabled so none is unbudgeted. `store` is
`false`, `truncation` is `disabled`, and there is no fallback model. The runner
requires an owner attestation that auto-recharge is disabled; it does not control
account billing or independently prove that setting. If the API serves a model
outside the accepted requested-name/version match, the run fails.

**Cost words.** `reserved_worst_case_*` is an estimate made before calls. `computed_from_reported_usage_usd` is
reported tokens times published rates. **Neither is a bill**; `billing_reconciliation` is `not-performed`.

## Security model

Enforced in code, not only in the prompt:

- **Disposable workspace.** Only the approved read set is copied (the collection, the instruction files, the
  pinned support files its validators read). The source checkout is never written; changes leave as a patch.
- **Path custody.** Model-supplied paths are normalised and rejected for traversal, absolute or drive paths,
  backslashes, NULs, ADS/reserved names, symlinks/junctions in any component, hard-linked write targets and a deny
  list; reads/writes must match explicit globs. Writable files are `pack.json` and `README.md` of the lane's own
  collection only; validators, render scripts and instructions are read-only. `preview.svg` changes only by the
  collection's own render script.
- **No shell.** Processes run only through fixed argument vectors for three kinds (`validate`, `render_check`,
  `render_write`), with an allowlisted interpreter, a scrubbed environment (no API key), working-directory
  pinning, time limits with process-tree kill and output caps. A run that changes any unassigned file is a
  violation.
- **Lane ownership.** Terrain Art = 001-005, Ruin Detail = 006-010, Art Curation = 011-015. A lane may write only
  its own collections; any other collection is read-only critique and the edit tool is not offered.
- **Secrets.** Credentials never enter model context, tool output, logs or receipts (pattern and exact-value
  redaction; a receipt containing credential-shaped text is withheld).
- **Source identity.** `expected_source_sha` must be a full SHA and equal HEAD; the source hashes and HEAD are
  re-checked after the run and a competing change blocks the patch. Receipts record the repository HEAD and the
  SHA-256 of every file read.
- **Publication** is separate and off by default. `atlas_agent_runner.py publish` re-checks that upstream HEAD
  still equals the SHA the patch was made from, that only the lane's own files change and only as modifications,
  and that the branch name is a **new** `atlas-agent/*` name (local and remote); then it commits to that branch.
  It never changes the base branch or merges. An optional `--push` uses a
  create-only lease and refuses an existing remote branch. Publication is a
  separate operator-authorized action; the Actions workflow has no write access.

## Atlas tools and the capture hand-off

Tools offered to the model: `list_files`, `read_file`, `inspect_pack`, `run_validator`, `list_captures`,
`view_image`, `render_capture`, `compare_captures`, `replace_text` and `pack_add_rectangles` (both only with write
custody) and `submit_report`. `pack_remove_rectangles` removes exact rectangles (the last matching entry of each,
never emptying a feature) by the same layout-preserving, parse-verified splice. Both accept `feature_id` `@scene` for the
combined scene's own foundation rectangles, and `list_rectangles` pages through either as compact
`[array_index, x, y, width, height, material_id]` rows (the expanded pack is about 19,000 lines, far too costly to page
through with `read_file`). Editable file size is capped at 2 MB independently of the read cap. `pack_add_rectangles` appends up to 60 validated `[x, y, width, height, material_id]`
rectangles to one feature while preserving the file's own layout; it refuses out-of-bounds rectangles, unknown
palette materials and movable materials in static features, and the spliced file must parse to exactly the old pack
plus the new rectangles. After any edit the runner itself re-runs the collection's validator and `--check` render and
refuses a patch that fails either.

By default the agent makes one small edit. `task.directive` (up to 4,000 characters) carries a trusted operator
instruction, for example to make several sweeping and detail edits; it overrides that default but never the hard
rules, and its text and SHA-256 are recorded in the receipt (`policy.task_directive`). Instruction text is versioned
(`atlas-agent-instructions/2`, hashed in every receipt).

An optional `task.reference_bundle` supplies a second verified bundle of an *earlier* state (for example the art
before a previous agent's edit) that the model can list and view as bundle `reference`; the `input` bundle must have been
rendered from the exact pack being edited, otherwise the run is refused as `capture_bundle_stale`.

Capture bundles use the documented #498 layout (sealed `batch-manifest.json`, job manifests, PNG hashes); the
runner re-verifies the seal, hashes and PNG structure itself, and invokes the #498 launcher only through the
documented CLI and its exit codes (`render_capture`, needing `task.godot`). **Evidence class** is recorded for
every image: `godot-capture` (engine identity present) or `fixture` (flat raster). The receipt's
`visual_cycle.claimed` becomes true only when before **and** after bundles are both `godot-capture`, framing is
equivalent, the pack and PNG changed and the patched pack re-validated. Fixtures never support that claim. The dated November 7 local run did exercise
a genuine Godot before/after cycle, as recorded below; that establishes execution
for its source, not artistic acceptance or a qualified hosted pipeline.

## Receipts

`receipt.json` follows [`receipt.schema.json`](../../tools/atlas_agent/schemas/receipt.schema.json)
(`cybersand.atlas-agent.receipt/1`, sealed by `receipt_sha256`): source HEAD and file hashes; collection, lane,
instruction/tool/pricing revisions; model and API configuration; applied limits and remaining allowance; every
call (tokens, retries, reserved and computed cost); every tool call (argument and output hashes); validation
results with real exit codes; image hashes and evidence classes; edits with before/after hashes; patch hash; the
credit-gate checks; the model's structured report; the final status and reason code. `verify-receipt` checks
schema, seal and absence of credentials.

Exit codes: 0 success; 2 usage/config; 3 live gate refused; 4 stopped (a limit, or the agent reported blocked);
5 API failure; 6 sandbox violation; 7 validation failed; 8 source/publication refused; 9 internal.

## Qualification record

| Date | Item | Result |
|---|---|---|
| 2026-11-07 | Deterministic suite (`python3 -m unittest discover -s tools/atlas_agent -p "test_*.py"`): config, pricing/budget, sandbox, malformed tool calls, validators, captures, real Git custody, the real SDK against a loopback API double, workflow entry | Exact-head results are recorded in the pull request. |
| 2026-11-07 | Live Responses API smoke test, `gpt-6-luna`, synthetic fixture, owner-supplied key and attestation | **Passed** ([evidence](../audits/2026-11-07-issue-499-live-responses-smoke.md)). Run 1 was stopped by `max_iterations` (fail-closed limit); run 2 succeeded with a verifiable receipt: 9 real responses, 13 tool calls, one image, one bounded edit re-validated, about USD 0.0012 against a USD 0.25 ceiling. Fixture evidence only; no Godot visual claim. |
| 2026-11-07 | Live run on real Atlas art (`lumen-fault`, art head `c4aab63e`) with a genuine #498 Godot capture bundle | **Passed as critique-only** ([evidence](../audits/2026-11-07-issue-499-live-responses-smoke.md#run-3-real-atlas-art-genuine-godot-captures-critique-only)): 7 real responses, 3 images viewed, baseline validator passed, about USD 0.003; the model made no edit, so no cycle is claimed. |
| 2026-11-07 | Owner-directed editing run on real art (`lumen-fault`, art head `c4aab63e`): model edits, real validators, real Godot after-capture and comparison | **Passed** ([evidence](../audits/2026-11-07-issue-499-live-responses-smoke.md#run-4-owner-directed-editing-cycle-on-real-art)): `success`, `visual_cycle.claimed` true, 15 responses (5 rate-limit retries accounted separately), 7 `pack_add_rectangles` batches, about USD 0.004. Execution is verified; the artistic result is **not** accepted: a measured review found 49% of the new mass floating unattached and cistern edits that breach that module's placement rule. |
| open | Human lane review and reference-gallery comparison of the run-4 patch, Costs API cross-check, dashboard reconciliation, Actions-hosted live run for the separately admitted fixture path (needs current credentials and explicit spending gates) | **Not yet run.** |

The loopback double (`testing_stub_api.py`) speaks HTTP to the real SDK; it proves request shape, retries,
error mapping and accounting logic. The live smoke test above is what showed the live service accepts these
requests for one model; the published rates in `pricing.json` still need re-checking when they age (45 days). The Costs API response shape used by the optional cross-check was written
from documentation that could not be read in full and is tested only against the double; it fails closed on any
parse problem.
