---
title: Art workbench provider connection, WB-ART-002 Stage 2
status: Current
document-kind: contract
scope: Unmerged OpenAI Responses, NVIDIA and LM Studio art UI, collaboration preview, cancellation, traffic and qualification
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-22
related-documents: [workbench-direct-art-batches.md, ../architecture/shared-workbench-authoring-data.md, ../reference/status-and-roadmap.md]
---

# Art workbench provider connection — Stage 2

## Current candidate and controls

**Unmerged candidate:** #559 Stage 2 extends `codex/agent-art-workbench-v2` and
Draft PR #560. The [Stage-1 contract](workbench-direct-art-batches.md) owns direct
geometry, execution-time protection, native completion and authored-start Save.
No #531 controller, native defaults, prices, catalogs, credit gates or MCP are
imported. Model prompt and Scanline send the current task, selected conversation
context, drawing instructions, work area and optional canvas observation. Stored
traffic remains separate from model context.

The [integrated Draft candidate](../operations/wb-art-paint-integrated-candidate.md)
preserves this complete interface and adds PAINT alongside it. Native authoring
uses the repaired stored-material API and shared ordering; the provider protocol,
model choices, conversation, diagnostics and image-observation controls remain
owned here. The integrated workflow uses deterministic HTTP/provider fixtures;
earlier genuine inference evidence below belongs to its original checkpoint.

Open **Art batches**, choose **Model prompt**, provider, editable model ID and base
URL. Endpoint/model, output allowance and timeout occupy two shared rows. Enter a
prompt in the main text area and click Send; Stop remains beside Send. Direct JSON
remains selectable independently. Model history is convenience, not admission.
Controls affect the next request; an in-flight request keeps its captured work
area/material/protection selections. Idle/completed, waiting for model, capture,
native queued/executing/partial and errors are visibly distinct.

| Preset | Protocol | Default base URL | Model field |
|---|---|---|---|
| OpenAI | Responses | `https://api.openai.com/v1` | `gpt-5.6-luna`, editable |
| NVIDIA | Chat Completions | `https://integrate.api.nvidia.com/v1` | `nvidia/nemotron-3.5-super-vl-120b-a12b`, editable |
| LM Studio | Chat Completions | `http://127.0.0.1:1234/v1` | `wb-art-instruct`, local tested alias, editable |

Use **Key…** for each cloud provider. Keys stay in process memory, separately per
provider; reopening Key always permits replacement. The button indicates a key
is present. Profiles/history persist in `user://art-provider.cfg` without keys.

LM Studio sends no fabricated key; a configured local server token is accepted
through the same Key control. Local/LAN/manual endpoints are allowed. The numeric
loopback default avoids the long `localhost` connection delays observed on this
Windows installation; `localhost` remains usable as an editable endpoint.

Output allowance defaults to 8192; Toks and Secs control the actual request cap
and HTTP timeout. Tests exercise 4096/8192/16384 separately. Responses uses
`max_output_tokens` (including reasoning where applicable); Chat Completions uses
`max_tokens`. Truncated/incomplete responses report the reason and draw nothing;
there is no automatic expensive retry or hidden context truncation. Returned
model/deployment names are informational. Reported input/output usage is shown;
missing usage/cost remains `?`. Provider rate headers and errors are in Traffic;
Stage-5 automatic pacing/advanced budgets are not claimed here.

## Provider/native boundary and Stop

`art_provider.gd` owns one threaded Godot HTTPRequest and static payload/response
adapters. `art_batch_panel.gd` supplies compact controls and dispatches parsed
operations to the existing Stage-1 executor. No second simulation or controller
is introduced. Plain JSON arrays, an operations envelope, a single shape, JSON
fences and a recognized final packet after `</think>` are accepted. `type`/`operation` alias
`shape`; draw_ prefixes and pixel/circle/rect spellings normalize to the same
primitives. Omitted material defaults to the selected paint material. Hard Wall is the initial selection. A complete JSON array followed by a stray closing wrapper is
accepted; a truncated array is not. Native geometry/material validation still applies. Arbitrary prose is
not executed. Refused/malformed packets leave Send available for correction and
retain the complete provider response. This is structured-text drawing, not a
claim that every local model supports native tool calling.

Stop cancels capture/HTTP, invalidates the request generation and stops native
queued work. Native worker epoch is captured before inference; Reset/Load/Restore
invalidate old model results. An executing native chunk may finish at its normal
boundary. No uncertain mutation is replayed. Network failure, HTTP 429, bad model
output and logger failure leave the UI available. No credential/catalog preflight
is used beyond requiring a cloud key/model field for a cloud request.

Optional **Image** sends a PNG crop from the actual post-draw canvas view, resized
to at most 768 pixels on its longest axis. Floating art/traffic windows are hidden
for the capture frame and restored; their contents do not cover the canvas image.
Camera/view remain unchanged. Image capture requires a graphical runtime; text
inference works headlessly. Image bytes remain inspectable in raw traffic.

HTTP response body capacity is 16 MiB to bound response allocation; timeout is
visible/configurable. Automatic HTTP redirects are disabled so a configured base
URL is the actual credential destination; HTTP redirect/error details remain
inspectable. These are transport mechanics, not source/pricing authorization.

## Diagnostics and retention

**Traffic…** is a separate hideable window with readable messages/instructions,
a Raw JSONL switch, copy and full-session export. Both formats show actual content;
raw contains request bodies, response bodies/headers, usage, native admission and
completion, cancellation, wall-clock timestamps and monotonic times. Requested
and returned model names are recorded without comparing them as a gate.

Full redacted JSONL appends under `user://art-traffic/`; its absolute path is shown
in Traffic. On this Windows installation that normally resolves below
`%APPDATA%/Godot/app_userdata/Cyber Sand Reference Sandbox/art-traffic/`.
The live text buffer is bounded separately (about 2 million characters), with an
explicit earlier-on-disk marker. Full export streams the linked disk segments, not the
live tail; there is no 256-event export ceiling. Disk failure is surfaced without
stopping inference/drawing. When disk logging fails, missing historical content
is not magically recoverable from the bounded viewer.

Entered keys, bearer strings, common key formats, credential URL parameters and
URL userinfo are redacted before display/disk/export. Authorization request
headers are never added to the logged request object. No log can identify every
arbitrary secret the user invents; do not put unrelated credentials in prompts.

### Lazy reopening and traffic storage

**Retired on 22 November 2026.** This anchor is retained for historical
documentation links only. The former cross-session transcript-restoration
contract has been replaced by the session-scoped design immediately below.

### Session-scoped, write-only Art traffic — 22 November 2026

Each **new Workbench game session begins with an empty in-memory Art conversation**.
The Send, Conversation and direct drawing controls never reopen, link, scan or
copy traffic from a previous process or Workbench scene. The user can maintain
multi-turn context *within the current session*; closing the session discards
the in-memory conversation. Model/provider/endpoint/control preferences may
still persist in `user://art-provider.cfg`, but no `traffic_path` is read or
published. The obsolete profile pointer is removed on the next successful
preferences save.

On the first Art log event, the existing bounded writer creates **one new root
JSONL** under `user://art-traffic/`. All following requests, provider responses,
native results and in-session conversation changes append to that same file
until the Workbench session ends. Hiding and reopening the Art window within
the same Workbench does not create a second log. There is no automatic replay,
linked predecessor, history-resume gate or full-history duplication. An
unavailable, corrupt or deleted older log cannot prevent Send.

Each model request writes a redacted `request_parameters` event containing the
provider/model/endpoint, prompt, guidance, requested work rectangle, allowed
materials, protected areas, enabled tools, token/time/turn limits and relevant
image/context settings. The normal request/response/native receipt events
follow. Direct JSON painting records `manual_program`, `manual_admission`
and terminal `manual_result`. This provides the values needed for manual
re-entry later; it does **not** promise to reproduce an evolving World from
prompts alone or retain exact unlogged source World state.

`Traffic…` displays the current session file path and can explicitly export
it. Existing legacy and linked archives remain **unchanged** on disk, but are
never attached to a new game session. The legacy archive parser remains
available for standalone read-only diagnostics and old evidence tests; it is
not part of the normal UI lifecycle. No automatic migration, deletion or
cleanup is performed.

PAINT's native authoritative Undo/Redo is independent of Art. When an Art
window exists, confirmed Undo/Redo events may be appended to its current
session log. Without an Art session, native editing does not force the Art
panel or create a cross-session receipt journal. Old `user://art-pending-history`
records are preserved as historical data and never injected into a new
session. Disk logging failures remain visible, but must not retroactively
repeat a native edit.

**Scope boundary:** This is session-local authoring history, not a durable
conversation database. Save/Open for the authored World and PAINT's own
material history retain their existing independent contracts. New model
requests must never trust a stale previous-session continuation pointer.

### Explicit capacity outcomes

`art_traffic_archive.gd` reads 64 KiB chunks; interactive restore/export polls
admit at most 1 MiB of archive or image-record input. A record is limited to
32 MiB, a chain to 4096 segments, and legacy explicit event-ID tracking to 65536
identifiers per chain. Legacy ID validation retains fixed-size SHA-256
fingerprints rather than arbitrary-length ID strings, so that metadata cannot
grow in proportion to historical ID text. Link metadata is bounded to 2 MiB per header and
64 MiB across a chain. Image-reference validation caches at most 4096 small
identities, with actual image bytes released after validation. PNG decoding
checks a 16,777,216-pixel capacity before allocating the decoded image.

The editable transcript is bounded to 16384 turns and 16 MiB of UTF-8 text.
The same admission rules apply before new turns or edited snapshots are stored,
so a successful write cannot create a transcript the replay path rejects for
capacity. Existing content exceeding a bound is preserved with a visible
refusal; full audit export does not accumulate the transcript in memory.
These are safety capacities, not changes to native World dimensions.

The native-history journal admits at most 4096 committed records, 64 MiB in
total and 256 KiB per record. Only the corresponding pending receipt IDs and
fixed-size content digests enter the provider's commit tracker. Filename, source,
epoch, UTF-8, complete-record and capacity failures refuse replay while keeping
original data. Unpublished temporary files do not count as committed receipts.
An unavailable journal may retain at most 64 receipts / 4 MiB in process for
explicit retry while Workbench stays open; reaching either limit is a visible
persistence failure, never an unbounded or silently dropping queue. The profile
reader has a separate 1 MiB bound.

`test_art_lazy_traffic.gd` covers deferred replay and linked append.
`test_art_traffic_panel_safety.gd` exercises the actual mounted controls for
unavailable-history refusal/retry, model selection, failed-append pointer
retention, cancellable export and explicit conversation clearing.
`test_art_history_durability.gd` and its process runner exercise real filesystem
failures, repair, restart and the raw-event/conversation crash boundary.
`test_art_history_receipt_identity.gd` covers pending-ID capacity, exact
source/content/epoch matching, provisional replay state, legacy result identity,
credential redaction and clear/edit deduplication. Runtime
measurements and platform qualifications belong to the
[durability qualification record](../audits/2026-11-21-gentek691-art-durability.md);
passing source checks alone does not establish Windows acceptance.

## Reproducible qualification and local setup

The original Stage-2 checkpoint used unchanged main native libraries. The
integrated repair requires its newly built source-matched GDExtension.
Real-native and cloud-adapter fixture tests are separate from genuine inference.

```powershell
lms server start --port 1234
lms load liquid/lfm2.5-1.2b --gpu max --context-length 16384 --identifier wb-art-instruct --ttl 7200 -y
# Optional already-installed vision model used in this qualification:
lms load lfm3-omni-2b --gpu max --context-length 16384 --identifier wb-art-vision --ttl 7200 -y
C:/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path godot --script res://tests/test_art_provider.gd
python tools/test_art_provider_transport.py --godot C:/Godot47/Godot_v4.7-stable_win64_console.exe --output build/art-provider-http
```

`run_art_provider_local.gd` is an explicit genuine-local UI/native test, not an
automatically discovered CI test. Set `WB_ART_TEST_ENDPOINT`, `WB_ART_TEST_MODEL`
and `WB_ART_EVIDENCE_DIR` as needed. The transport tool supplies synthetic HTTP
responses and separately runs real native drawing; it tests OpenAI/NVIDIA/local
wire shapes, aliases, errors, timeout, Stop and replacement. Its
`--graphical` option exercises actual UI image capture and retains PNGs on Linux
X11 and Windows ANGLE.
Only `test_art_provider.gd` is a normal keyless auto-discovered provider test.

Genuine text qualification used LM Studio 0.4.26+4, selected llama.cpp NVIDIA CUDA
runtime 2.73.0 and TITAN RTX (24576 MiB). `liquid/lfm2.5-1.2b` Q4_K_M with 16384
context and `--gpu max` passed drawing at all three output allowances. GPU process
and VRAM evidence are retained. An installed experimental 8B IQ4_XS model emitted
reasoning/prose and an unsupported shape on one trial; it is not labelled a
perfect structured-command model. No model download was needed.

Genuine LFM3-Omni-2B Q4_K_M image inference through the new adapter described an
original native-workbench post-draw PNG. Its vision projector reported unsupported
CUDA flash-attention operators and CPU fallback: this is **mixed GPU/CPU vision**,
not proof of an entirely GPU-resident visual path or a visual revision loop.
Model art quality and Stage-3 persistent visual iteration remain separate.

The owner-requested benchmark uses the exact prompt
`draw a detailed gundam mech style cyberpunk statue`, three fresh 64x128 attempts
per installed model, 8192 output allowance. `tools/bench_art_provider.py` retains
original rendered canvas/workbench PNGs, raw traffic and measured native results.
Its optional WSL-to-Windows loopback relay is test-only, not a product dependency.
No external port exposure or MCP is introduced.

Cloud request shaping is keylessly qualified; genuine OpenAI/NVIDIA calls require
owner key entry and remain separately reported. The first nine statue trials copied literal numeric examples or used near-miss
field names, and applied zero cells. Their failures are retained. The generic
instructions were clarified to describe parameter fields without numeric drawing
examples; equivalent spellings were normalized and the comparison repeated.
No paid calls or merge/Ready
promotion are implied by this implementation.

## Collaboration, scanline and pacing preview

Model prompt and Scanline keep a conversation for the mounted workbench. Turns
limits requests per Send, including refusals and rate retries. Zero continues
until Stop, completion or another limit. Run s adds an
optional elapsed-time ceiling. After native completion, the next request can
use the actual changed count and world epoch. An empty array ends the run.
Stop cancels pending inference, pacing and queued native work. Clear starts
a new conversation while the durable traffic retains earlier events.

Full includes all text turns and saved images when Image is enabled. Compacted includes the latest twelve entries and
discloses omissions. It omits reasoning prefixes from model context while
retaining the original replies in traffic. Custom initially uses the same window. None sends no
earlier turns. Historical image bytes remain in durable traffic. Image sends the
visible intersection of the work area, or the whole visible canvas with Full view.
The request includes pixel dimensions and the world rectangle. Identical captures
are skipped within a run. Native chunk receipts remain in local traffic. Guidance
opens the editable instructions for the selected mode.

Scanline takes rows with local y, optional repeat and scale, and spans in
[x,length,material] order or named objects with those fields. Omitted spans preserve cells. An explicit zero
material erases. The normal executor applies the resulting ordered rectangles. Consecutive
shapes of the same material share native chunks up to the existing cell
limit. Material changes preserve the original draw and erase order.

Gap s sets an optional request interval. HTTP 429 with numeric Retry-After
paces subsequent requests to that endpoint. OpenAI request, token and project
token reset durations also pace requests when their bucket reports exhaustion.
Known billing and spending quota failures require user action. Traffic supports visible filtering
and full disk export. Unknown cost remains unknown.

On 2026-11-10 the Windows preview passed 113 native checks and 43 checks with
LM Studio LFM2.5 1.2B, including a human follow-up and Stop during pacing.
The Linux graphical transport fixtures passed for all three providers. The
graphical run_art_scanline_vision.gd probe used the loaded LM Studio LFM3 Omni
model through a loopback relay. It applied a four-cell wall, then erased its
first cell after a second rendered observation. The earlier LFM2.5 text
scanline trial returned malformed JSON. The vision test is a constrained
placement test. In a separate graphical 64×128 statue trial, wb-art-local
sent three requests over 50.5 seconds. The first two changed 226 and 132
native cells. The last returned an empty array. Reported input and output
totals were 11,900 and 6,707 tokens. This was text-only and predates the
compacted reasoning-prefix omission. The rendered PNG and traffic retain
the result for owner review.

The workbench restores the last conversation from saved traffic into a
separate log file on reopen. Full resends historical image bytes when Image
is enabled and identifies omitted images otherwise. Spend optionally stops
subsequent requests at a user-priced
estimate from reported tokens. One response can exceed the ceiling. Rate waits use reported provider timing.

## Offset-area repair

LM Studio receives coordinates relative to the selected work area. The panel
validates individual shapes in that local frame and offsets usable geometry
before handing it to the native executor. Malformed shapes are skipped;
point-pair polylines and single pixel x/y forms are accepted. Traffic records
the number of usable primitives. OpenAI retains its existing world-coordinate
protocol. Native scope, protection and cancellation remain authoritative.

The NVIDIA model dropdown includes Qwen3 Next Instruct, Qwen2.5 Coder,
Nemotron Lightning and Nemotron Super VL. The two Nemotron presets disable
thinking for direct drawing to leave output tokens for the drawing packet.
These presets do not restrict manual model IDs.


### 2026-11-11 scanline qualification

The Windows native session probe, run with the local wb-art-vision model,
completed twelve 480-cell scanline turns on one canvas in 58.4 seconds. Native
readback confirmed 5,760 changed cells across twelve chunks. The export kept
all twelve native receipts and the initial inference cancellation. The first
attempt exposed a model reply using named span fields, now supported alongside
the array form. A separate inference continued through injected log I/O failure.

The same probe stopped an admitted large stencil after the first 4,096-cell
receipt and confirmed that the next row was untouched. It also stopped during
inference and a pacing wait. The graphical Linux probe stopped during canvas
capture before dispatch, then drew and revised a stencil with the live local
vision model. The OpenAI HTTP fixture verified a successful response with zero
remaining requests and a 62.5-second reset, and verified that a billing quota
error does not retry. These provider header cases use keyless fixtures.


The art material picker offers every non-empty material from the ordinary
Workbench paint palette. Erase remains a separate toggle. The selected ID
applies to Direct JSON, Model prompt and Scanline. Existing non-Empty,
non-Hard-Wall cells remain protected from art writes, including erase.


Tools controls which shapes Direct JSON and Model prompt may submit. A
nonzero Pixels per operation setting limits the length of each point list.
Zero adds no point limit. The worker still streams large operations in native
chunks. Lines accept an optional integer width in cells. Width one preserves
the original raster. Wider strokes use rounded ends and clip to canvas bounds
before the worker applies the selected area and protection checks. Scanline
keeps its own span format.

The Tools picker also enables rounded polylines (ordered `points` and optional
`width` in cells), filled polygons (three or more `points`, closed automatically),
and airbrush stamps (`x`, `y`, `radius`, optional `density` and `hardness` from
0 to 1, and an integer `seed`). Airbrushes stipple real material cells; hardness
controls edge falloff, and repeating a seed repeats the pattern relative to the
stamp center. All three use the same native edit batching and protection as the
existing shapes.

Desktop rasterization yields between frames even when a sparse shape produces no native chunk yet. Partial chunks are submitted periodically so sparse shapes can appear before rasterization finishes. Stop discards buffered cells that have not been submitted to the native owner.

Traffic stays on disk while hidden. The open inspector refreshes at most twice per second during drawing and shows a bounded tail; Save JSONL exports the full session.

On 2026-11-11, Windows/TITAN RTX local tests at source `e5bf2916` ran
the mech-statue prompt twice per installed model on fresh 64×128 native canvases.
LFM3 1.7B exhausted 8192 output tokens on reasoning twice; LFM2.5 1.2B
returned unusable geometry twice. The installed LFM2.5 8B-A1B variant applied
2344 and 1727 Hard Wall cells in 11.7 and 23.6 seconds, respectively, but
rendered inspection did not establish the requested subject. A test-only
reasoning-disabled LFM3 request on 256×512 applied 26741 cells in 3.8 seconds,
but also failed visual subject assessment. These establish connection and native
application outcomes, not artistic acceptance. No production provider settings
were changed. The graphical benchmark accepts `WB_ART_BENCH_WIDTH` and
`WB_ART_BENCH_HEIGHT`; defaults remain 64×128. Local original replies, native
readback images, rendered PNGs and hashes are retained under
`build/local-models-20261111/` (not committed).


## Final graphical pipeline qualification - 2026-11-11

The final smoke uses the actual panel Send/Stop signals, asynchronous HTTP, native
World and post-draw framebuffer. A recorded deterministic local HTTP provider
returns a substantial polygon/airbrush packet. Two intermediate canvas captures
show growing native output. Stop retires a partial prefix; after completed
snapshots drain, native-image and canvas hashes remain unchanged across a
half-second late-write observation. A protected rectangle lies inside the
attempted prefix and must produce at least 128 excluded cells.

Without clearing the conversation, follow-ups change to local bounds at world
(1200,200) and hosted world bounds at (1200,750). The fixture independently checks
that outgoing requests retain earlier user/assistant turns and native Canvas
results alongside current bounds. Native readback confirms translated local and
direct world writes. An intentionally stale hosted reply is entirely skipped and
must display No pixels applied. Traffic is visible during the initial draw.

Reproduce with `python tools/test_art_final_graphical.py --godot PATH --output build/art-final-graphical`
in a graphical Windows session, or wrap that command with `xvfb-run -a` on Linux.
The test isolates settings using APPDATA/XDG_DATA_HOME, records source/runtime
hashes and preserves full requests, original full/cropped PNGs, native material
readback, receipts and assertions. It makes no paid calls and does not test art
quality. The GDExtension workflow runs it separately against its source-built
Linux native runtime and uploads an artifact; its result is required by the Linux
aggregate. Manual full Native and GDExtension workflows can run while the PR stays
Draft. Draft-skipped runs do not qualify this source.

Initial Windows driver attempts remain in local evidence: a type annotation error
prevented startup; a full-window comparison included independent UI changes,
corrected to native/canvas identity after snapshot drain. Independent review also
moved the protected rectangle into the attempted prefix so its assertion is not
vacuous. No production drawing behavior changed during this final qualification
checkpoint. Live model trials remain separately dated above.
