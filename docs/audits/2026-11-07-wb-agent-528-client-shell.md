---
title: WB-AGENT #528 existing-workbench mounting and Responses native-owner integration
status: Planned
document-kind: evidence
scope: WB-AGENT-003 opt-in mounted UI, real #526 native tool integration, #527 step pending
related-documents: [../operations/cybersand-codex-development-handover.md, ../reference/status-and-roadmap.md, ../architecture/data-ownership-and-lifetimes.md]
last-reviewed: 2026-11-07
---

# WB-AGENT #528 — mounted shared-workbench panel checkpoint (7 November 2026)

## Source and current claim

Accepted main at branch creation: `81bbd5ff5cf366159e2b8a630609359c13560080`.
Review target: existing workbench, parent #525, upstream #526/#527.
This checkpoint contains the first **actual opt-in mount** into `shared_workbench.gd` on the existing #531 Draft. It stacks the real #526 implementation Draft as a source ancestor for isolated execution, without changing the #526 branch or accepted main. It changes no native physics, material law, GEN-006, production default or upstream branch. Mounted, real native acceptance is distinct from standalone fake-provider qualification.

- `godot/scripts/workbench_agent_client.gd` owns nonblocking
  Responses HTTP and unique-request callback epochs, four strict function
  schemas, serial function dispatch, finite request/tool/token budgets,
  fake transport, local environment credentials, Stop, late-response
  rejection, and bounded response/error handling.
- `godot/scripts/workbench_agent_panel.gd` constructs task/model,
  finite nonnegative X/Y/W/H scope, Hard Wall/Empty allowlist, Start/Stop,
  protected-region count and a strictly host-bound dispatch port.
  It waits for actual #526 host-only authorization before API dispatch,
  and refuses new tasks until an old task has been retired.
- `godot/scripts/workbench_agent_proposal_overlay.gd` draws only
  actual native-prepared cell coordinates supplied by the authoritative owner
  through the existing workbench camera, viewport content rect and scale. It does not infer
  footprint/material IDs from colours or authorize edits from cached
  images.
- `godot/tests/test_workbench_agent_client.gd` exercises strict
  API boundary, fake call/response continuation, malformed/duplicate/
  parallel requests, HTTP auth/rate/network/timeouts, finite budgets,
  wrong-ID receipt, unverified native application and Stop epoch fencing,
  and panel invalidation. Fake native receipts in this test are **not**
  evidence of real World application.
- `godot/scripts/workbench_agent_mount.gd` binds the existing shared-workbench
  `main` and #526 `workbench_authoring_host.gd`; only that native-authoritative
  bridge may observe, preflight, or apply. The host-only task scope/protection
  authorization and retirement are never exposed as model tools. Actual
  post-draw PNG bytes are copied to an input_image data URL (never rendered
  from synthetic cell values); native IDs, revisions, world generation and
  verified apply/readback are preserved in the function result.
- `godot/scripts/shared_workbench.gd` adds an opt-in, default-hidden panel
  toggle and synchronous human-intent fences for painting, Play/Pause,
  canvas/load/start restore and settings. Ordinary manual controls remain
  available when the agent is disabled.
- `godot/tests/test_workbench_agent_mounted.gd` launches the existing
  `res://main.tscn` in shared-workbench mode, uses the real native owner and
  original GL framebuffer under Xvfb, drives fake HTTP observe/preflight/apply,
  then tests preserved human painting and late-model refusal. Synthetic
  provider input is NOT evidence of a real model-driven trial.
- `.github/workflows/wb-agent-528-integrated.yml` executes Godot 4.7
  and source-pinned native/Rapier LFS runtimes with real graphical Xvfb,
  retaining copied original PNG/native receipts and test logs.
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

**Source-specific handshake:** the #526 Draft contract is now implemented
and explicitly consumed in this isolated #531 stacked source: native
material IDs 0 (Empty) and 58 (Hard Wall), shape-specific integer disc/
line/rectangle, null replacement filter removed rather than rewritten
as Empty, source-joined PNG and verified native readback. The #527 bounded
native stepping and Stop acknowledgement are **not yet** integrated;
`step` explicitly refuses until an independently qualified #527 handoff.
Local HTTP cancellation is not native Stop ACK. No physics, owner worker
loop or scheduler is implemented by #528.

## Acceptance separation and next safe action

**Engineering:** mounted UI and actual #526 owner integration are now
code-bearing on #531; the [72/72 fake-provider Godot 4.7 run](https://github.com/techrote/cybersand/actions/runs/42383086609)
passed after preserving the first [RED 51-check run](https://github.com/techrote/cybersand/actions/runs/42382896235).
The [mounted real-native Godot/Xvfb run](https://github.com/techrote/cybersand/actions/runs/42383086585)
was launched at source `914aee31684d2cb419e6f1b888a405b739594972`;
its result must be verified before asserting end-to-end PASS. #527 Step/Stop
is missing and engineering overall remains HOLD for the full four-tool task.
**Live:** HOLD, no API key/model/service/paid trial supplied by this job;
there have been zero genuine API-driven Sand-hopper attempts.
**Human:** PENDING owner-visible shared-workbench assessment. No
headless test is desktop responsiveness or human approval.

After #527 publishes and independently qualifies its bounded step/Stop
contract, reconcile it onto this existing Draft #531; run the same native
owner path with all four tools, native Stop at an acknowledged boundary,
manual workbench regressions and the immutable v2 32-Sand control before
any three predeclared paid trials.
Retain failed reference controls unmodified. No live trials until the
reference controls and their total tick budgets are accepted.

This file deliberately does not edit the upstream-owned canonical
Stage-1 design, roadmap or retrieval manifest while #526 is changing
them. The integration owner must add a source-backed index/retrieval
route and re-run documentation/provenance/M11 once all three lanes
reconcile. Production defaults and native World authority remain
unchanged.
