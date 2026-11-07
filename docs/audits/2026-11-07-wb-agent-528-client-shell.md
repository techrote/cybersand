---
title: WB-AGENT #528 Responses client and independent panel checkpoint
status: Planned
document-kind: evidence
scope: WB-AGENT-003 isolated transport/UI shell; not native/tool integration
related-documents: [../operations/cybersand-codex-development-handover.md, ../reference/status-and-roadmap.md, ../architecture/data-ownership-and-lifetimes.md]
last-reviewed: 2026-11-07
---

# WB-AGENT #528 — isolated client implementation checkpoint (7 November 2026)

## Source and current claim

Accepted main at branch creation: `81bbd5ff5cf366159e2b8a630609359c13560080`.
Review target: existing workbench, parent #525, upstream #526/#527.
This checkpoint is **source implementation only until the exact-head Godot job passes**.
It does not alter `shared_workbench.gd`, `main.gd`, simulation worker,
native code, materials, GEN-006, or production behavior.

- `godot/scripts/workbench_agent_client.gd` owns nonblocking
  Responses HTTP and unique-request callback epochs, four strict function
  schemas, serial function dispatch, finite request/tool/token budgets,
  fake transport, local environment credentials, Stop, late-response
  rejection, and bounded response/error handling.
- `godot/scripts/workbench_agent_panel.gd` constructs task/model,
  signed X/Y/W/H scope, Hard Wall/Empty allowlist, Start/Stop, activity
  log, protected-region count and an exclusively host-bound dispatch port.
  It cannot authorize native edits by itself. It is **not yet mounted**
  inside the existing workbench; the #526/#527 shared-host owner must
  hand off the narrow hook and native receipt schema first.
- `godot/scripts/workbench_agent_proposal_overlay.gd` draws only
  exact prepared-cell coordinates supplied by the authoritative owner
  through an explicit world-to-screen projection. It does not infer
  footprint/material IDs from colours or authorize edits from cached
  images.
- `godot/tests/test_workbench_agent_client.gd` exercises strict
  API boundary, fake call/response continuation, malformed/duplicate/
  parallel requests, HTTP auth/rate/network/timeouts, finite budgets,
  wrong-ID receipt, unverified native application and Stop epoch fencing,
  and panel invalidation. Fake native receipts in this test are **not**
  evidence of real World application.
- `.github/workflows/wb-agent-528-client.yml` pins the repository's
  official Godot 4.7 editor hash and records exact source/tool identities.
  All protocol CI uses a fake provider and an empty API key.

## API contract, responsibilities and limits

Official documentation inspected 7 November 2026:
- [Responses function calling](https://developers.openai.com/api/docs/guides/function-calling):
  `strict: true`, each schema requires all properties, object
  `additionalProperties: false`, serial `parallel_tool_calls: false`,
  function-call continuation via `previous_response_id` and
  `function_call_output` keyed by `call_id`.
- [Images and vision](https://developers.openai.com/api/docs/guides/images-vision):
  actual copied PNG attached as `input_image` with data URL after
  the corresponding native observation. The client cannot create a
  source-matched image itself.

Default per-task API budgets: **12 HTTP turns, 32 native tool calls,
2048 output tokens per turn, 25-second HTTP timeout, 2 MiB maximum
response, 64 KiB maximum text native receipt and 800,000-character
copied PNG data URL**. These do not supersede #526's more restrictive
8-primitives / 4096-cell bounds or #527's 1–120 ticks per call / finite
total trial allowance. No automatic retries on ambiguous mutation
results.

API key: set `OPENAI_API_KEY` in the Godot process environment in the
user's local launch configuration; do not embed in repository, project
settings, scenes, saved setups, logs or CI. Model ID is a human-entered
configuration, not a hardcoded presumptive entitlement. HTTP messages
exclude mutable World/worker objects and any shell or filesystem tool.

**Outstanding schema handshake:** #526 has not yet published an
authoritatively qualified observe/prepare/apply receipt and raster
format; #527 has not yet published integrated step/Stop epoch contract.
The operation arguments in this source are an explicitly replaceable
strict *transport adapter*, not a competing native API. Before
integration, map exact material IDs, cell shape/filter keys,
observation image/render identity, task/World/revision tokens,
proposal footprint encoding and `readback` to #526, and treat
native Stop ACK as distinct from local cancellation. Do not invent
or downgrade a native applied receipt.

## Acceptance separation and next safe action

**Engineering:** test workflow outcome pending exact-head execution;
UI source is standalone, not yet visibly mounted in shared workbench.
**Live:** HOLD, no API key/model/service/paid trial supplied by this job;
there have been zero genuine API-driven Sand-hopper attempts.
**Human:** PENDING owner-visible shared-workbench assessment. No
headless test is desktop responsiveness or human approval.

After qualified #526 and #527 handoffs, connect this panel to the
*same* shared-workbench dispatcher, pass actual native image/count/receipt
and footprint projection, then execute the existing manual workbench,
Stop under held network and native operations, and frozen v1/v2
32-Sand reference tests before any three predeclared paid trials.
Retain failed reference controls unmodified. No live trials until the
reference controls and their total tick budgets are accepted.

This file deliberately does not edit the upstream-owned canonical
Stage-1 design, roadmap or retrieval manifest while #526 is changing
them. The integration owner must add a source-backed index/retrieval
route and re-run documentation/provenance/M11 once all three lanes
reconcile. Production defaults and native World authority remain
unchanged.
