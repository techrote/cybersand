---
title: Art Workbench provider and session contract
status: Current
document-kind: contract
scope: Accepted provider adapters, request/native boundary, current-session conversation, cancellation and private traffic
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-24
related-documents: [workbench-direct-art-batches.md, ../operations/workbench-art.md, ../architecture/shared-workbench-authoring-data.md, ../reference/status-and-roadmap.md]
---

# Art Workbench provider and session contract

Art uses the ordinary Shared Workbench's native drawing executor. The provider
supplies structured drawing data; it does not own the World or bypass material,
area, protection, epoch or history rules. Start with the
[practical Art guide](../operations/workbench-art.md) for controls and a
model-free example. [Direct batches](workbench-direct-art-batches.md) owns
geometry, native receipts, source-material eligibility and authored Save.

## Current candidate and controls

The original Stage-1/Stage-2 integration is accepted implementation. The later
session-only change accepted in [#727](https://github.com/techrote/cybersand/pull/727)
is the current conversation lifecycle. Active Art responsiveness/repair work
remains separately tracked in the [roadmap](../reference/status-and-roadmap.md);
an unmerged repair is not a current guarantee.

Open **Art batches** and select **Model prompt** or **Scanline**. The request
captures the task, drawing instructions, selected context, work rectangle,
permitted materials, protection, tools and optional canvas image. Changes to
controls apply to later requests, not a silently rewritten in-flight request.

| Preset | Wire adapter | Initial base URL | Initial model field |
| --- | --- | --- | --- |
| LM Studio | Chat Completions | `http://127.0.0.1:1234/v1` | `wb-art-instruct` |
| OpenAI | Responses | `https://api.openai.com/v1` | `gpt-5.6-luna` |
| NVIDIA | Chat Completions | `https://integrate.api.nvidia.com/v1` | `qwen/qwen3-next-80b-a3b-instruct` |

These are editable source presets, not a current provider catalogue or promise
of service availability. LM Studio is the initial provider. Custom local/LAN
endpoints are permitted; supply a model actually loaded by that server. **Key…**
stores a key in process memory per provider. No fabricated local token is sent.
Preferences in `user://art-provider.cfg` retain nonsecret provider/model/endpoint
and control values, not a durable conversation or key.

**Toks** defaults to 8192 and **Secs** to 180. Responses uses
`max_output_tokens`; Chat Completions uses `max_tokens`. Truncated/incomplete
responses are errors, not completed programs. Native/tool admission still
bounds parsed output. Returned model names and usage are evidence, not identity
or credit gates. No source/Git, pricing or catalogue preflight is imported from
other agent research.

## Provider/native boundary and Stop

[`art_provider.gd`](../../godot/scripts/art_provider.gd) owns the cancellable
threaded Godot `HTTPRequest` and payload/response adapters.
[`art_batch_panel.gd`](../../godot/scripts/art_batch_panel.gd) owns request state
and the UI. Its accepted structured-text forms include a JSON array, operations
envelope, single shape, JSON fence and recognized final packet after reasoning
text. Alias normalization does not execute arbitrary prose or code.

The panel passes parsed operations to the existing
[`art_batch_executor.gd`](../../godot/scripts/art_batch_executor.gd). Native
worker epoch is captured before inference. Reset, Load or World replacement
invalidates old results. Admission means queued; only native stored-material
readback establishes changed/unchanged/excluded/refused outcomes. A network
response cannot substitute for that receipt.

**Stop** cancels pending HTTP/capture, invalidates the request generation,
stops scheduled turns and asks native queued work to retire. An executing native
chunk may finish at its normal boundary. Its actual prefix remains reportable;
there is no assumed rollback or uncertain replay. Closing the Art window only
hides it. It is not Stop and does not end the Workbench session.

Optional **Image** captures the actual post-draw canvas view, resizing to at most
768 pixels on the longest axis. **Full view** uses the visible canvas rather
than only the Focus intersection. Art/traffic windows hide for capture and are
restored afterward. A graphical runtime is required; headless native renders
are not evidence that this capture path ran. Image bytes can appear in raw
traffic and remain private content.

HTTP response-body capacity is 16 MiB. The visible timeout bounds requests;
automatic redirects are disabled so the configured endpoint remains the
credential destination. Errors, HTTP 429 and malformed output have visible
outcomes. This contract does not assert that every unmerged close/error repair
has been applied.

## Collaboration, scanline and pacing preview

The retained section name is a compatibility anchor. These current controls are
implemented, although separate Batch/agent programmes are not implied:

| Control | Accepted behavior |
| --- | --- |
| Full context | Current-session conversation. |
| Compacted | Most recent 12 turns plus latest-result summary. |
| Custom | Currently the same bounded selection as Compacted. |
| None | No previous conversation in the next request. |
| Turns | Default 1; zero continues until Stop, model completion or another limit. |
| Limits… | Minimum request interval, elapsed-run limit and estimated spending ceiling; zero disables the corresponding bound. |
| Conversation… | Edit future request context in this session; do not rewrite earlier native receipts. |
| Scanline | Admitted local-to-focus line/stencil output through the same native executor. |

Spending uses user-entered token rates and returned usage after a response. A
ceiling can be exceeded by one request; missing usage cannot become a known
cost. There is no live price lookup or prepaid-credit guarantee. Automatic paid
dispatch is not a documentation or qualification prerequisite.

## Diagnostics and retention

**Traffic…** shows readable messages or Raw JSONL, filtering, copy, the current
session file path and **Save full JSONL…**. Requests, responses, native admission,
terminal results and cancellation carry their actual timestamps and content.
The bounded live viewer and full file are different things; disk errors remain
visible and missing disk content is not recovered from a bounded tail.

The first log event creates one new root JSONL under `user://art-traffic/`.
Requests and results append to this file for the Workbench session. No older
file is linked or copied into it. The original source already has a redactor
for configured keys, bearer strings, common credential formats and URL secrets;
request Authorization headers are excluded from logged request objects.
Prompts, responses, images and arbitrary private strings can still be sensitive.
Inspect and redact an extract before publishing a bug report.

### Session-scoped, write-only Art traffic — 22 November 2026

Every new Workbench session starts with an empty in-memory conversation.
Hiding/reopening Art within that session retains it. Ending the session discards
it. Send and direct drawing do not restore earlier traffic. The obsolete
`traffic_path` preference is not read for session continuation and is removed on
a successful preferences save. An unavailable old log cannot block new Send.

Model requests record `request_parameters`, including the chosen work area,
materials, tools and limits. Direct drawing records `manual_program`,
`manual_admission` and terminal `manual_result`. These records support diagnosis
and manual re-entry; prompts do not capture the exact source World or reproduce
an evolving simulation by themselves.

Native PAINT Undo/Redo is authoritative independently of Art. If an Art window
exists, `history_edited()` appends `native_history_action` to this session log and
a human canvas-result turn. It does not initiate another model request. A logging
failure must not cause a native edit to repeat. Old pending-history journals
remain untouched and are not injected into a new session.

### Lazy reopening and traffic storage

The former automatic cross-session restore contract is retired by #727. This
anchor remains for incoming links. The legacy archive/parser code is available
for deliberate read-only diagnosis and historical tests, not ordinary new-session
startup. Old archives are preserved; this is not permission to migrate or delete
them. Authored World Save and native edit history have separate contracts.

### Explicit capacity outcomes

The current conversation admission limits are 16,384 turns and 16 MiB UTF-8 text.
Profile reads have a separate 1 MiB bound. These are explicit capacities, not
unbounded history or native World dimension limits. Source and tests retain
additional legacy archive, linked-segment and pending-journal bounds. Those
bounds belong to historical diagnostic paths and must not be cited as evidence
that the current UI automatically resumes an archive.

## Offset-area repair

Direct JSON uses canvas coordinates. LM Studio geometry and Scanline interpret
model output relative to Focus and transform it through the admitted plan. Work
rectangle and protection are captured for the request. The source tests cover
nonzero offsets and clipping; an old screenshot from a repaired checkpoint does
not prove another source/runtime has the same result.

## Reproducible qualification and local setup

Use a source-matched native runtime and the exact pinned Godot. Deterministic
provider fixtures can test payloads, parsing, offsets, cancellation and receipts
without sending a paid request. For the current session boundary, inspect/run
[`test_art_session_log.gd`](../../godot/tests/test_art_session_log.gd) through the
[focused test guidance](../operations/testing-validation-and-replay.md). Legacy
lazy-restore/durability suites retain their original scope; their existence does
not reinstate that behavior in the normal panel.

The [integrated authoring runbook](../operations/wb-art-paint-integrated-candidate.md)
provides a bounded Direct JSON/manual/Undo/Save walkthrough. Native compilation,
headless fixtures, graphical capture, real provider inference and physical owner
acceptance remain distinct evidence. No external model call was dispatched for
the documentation update.

<a id="2026-11-11-scanline-qualification"></a>
<a id="final-graphical-pipeline-qualification---2026-11-11"></a>
<a id="art-workbench-provider-connection--stage-2"></a>

## Historical qualification

The original local-provider commands, scanline cases, Windows inference and
11 November graphical pipeline are retained in the
[baseline provider contract](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/systems/workbench-art-providers.md).
The [21 November durability record](../audits/2026-11-21-gentek691-art-durability.md)
keeps the preceding cross-session implementation's evidence. These records do
not override the current session-only lifecycle or authorize running a costly
provider campaign during routine documentation work.
