---
title: Art workbench provider connection, WB-ART-002 Stage 2
status: Current
document-kind: contract
scope: Art providers, same-session collaboration, failure lifecycle, consolidated Draft UI and qualification
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-26
related-documents: [workbench-direct-art-batches.md, ../architecture/shared-workbench-authoring-data.md, ../reference/status-and-roadmap.md]
---

# Art workbench provider connection — Stage 2

## Collaborative owned consumers — 25 November 2026

The Draft/HOLD collaborative successor preserves direct painting and adds
Discuss, Propose, Develop and Review through the same Provider. The
[owned transport contract](art-owned-proposal-transport.md) defines `send_owned`
and the injected Architecture dispatch/cancel interface. Owned replies never
emit ordinary completion-to-paint. World and applied-policy guards protect the
actual eventual transport admission, including asynchronous preparation.
Opening Art or a catalogue makes no request.

The [native contract](art-native-context-proposals.md) defines bounded observations,
palette/protection and zero-write preview. The [owner guide](../operations/art-workbench-collaborative-evaluation.md)
explains exact-context authorization for remote/custom endpoints. Optional images
are cropped from the Workbench canvas, with mapping/bytes disclosed; no desktop
is captured. Admitted images retain their current-session audit references.
Recent request memory is at most eight turns, 4096 characters each and 16384
total including omission markers. Complete originals remain in Conversation
and the redacted audit. Develop's proposal and Review's actual host receipts
are disclosed. Replies refresh bounded memory; edited conversations require
updated disclosure before Send. New sessions restore no old conversation or approval.

## Current candidate and controls

The original #559/#560 Art and PAINT integration is present in accepted main.
Accepted #727 defines the current session-only logging contract below. The
[Art finisher](../operations/art-workbench-final-evaluation.md) consolidates
#763/#756/#765/#766 and subsequent responsiveness/lifecycle repairs in a new
Draft/HOLD candidate based on `00cdb02f`. Its evidence does not qualify unrelated
pending feature branches. The [direct art contract](workbench-direct-art-batches.md)
owns geometry, native protection, completion and authored-start Save.

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
| LM Studio | Chat Completions | `http://127.0.0.1:1234/v1` | `kat-coder-v2.5-dev-reap-50@q6_k`, editable |

**Curated model menu — WB-ART-MODEL-ROSTER-001 (#750):**

- **NVIDIA Build:** `moonshotai/kimi-k3_1-pro` (Kimi K3.1 Pro),
  `mistralai/mistral-large-4-1t-a52b` (Mistral Large 4),
  `nvidia/nemotron-3.5-super-vl-120b-a12b` (Nemotron 3.5 Super VL).
- **LM Studio:** `kat-coder-v2.5-dev-reap-50@q6_k`,
  `daisyrose-27b`,
  `lfm2.5-24b-a2b-turbo-brilliance-50x-neo-max-imatrix`.

The selector displays these presets above saved/custom model IDs; the model
field and base URL remain editable and do not enforce a fixed allowlist.
Previously saved custom IDs remain in configuration even after a preset changes.
The nonexistent legacy ID `astra5-6` is not presented as a choice; if it was
the active saved ID, the default is displayed instead. Historical records are
not silently deleted. Locally served LM Studio IDs must match the active
server's model identifiers.

**Availability is unverified by a preset.** The selector makes no promise of
API access, image support or a running local model. Confirm capabilities with
the configured service when you use it. No availability probe or paid request
runs on selection. The editable model ID, custom endpoint and saved history
remain authoritative user configuration.

Use **Key…** for each cloud provider. Keys stay in process memory, separately per
provider; reopening Key always permits replacement. The button indicates a key
is present. The dialog captures the provider when it opens, so switching the
underlying selector cannot assign a key to a different provider. Closing or
cancelling clears its text. Profiles/history persist in `user://art-provider.cfg`
without keys; unchanged preferences are not rewritten on each Send.

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
the optional pacing and user-priced budget controls are described below.

## Responsive conversation editor and Apply/Cancel

The long Art conversation editor keeps its standard **Apply/Cancel** footer
outside a scrolling body. Note text and unusually long conversation entries
cannot grow the dialog beyond its parent. Art-owned window minimum sizes and
bounds account for their content scaling; 720p/1080p and 100/125/150 percent
geometry are checked separately from physical Windows display acceptance.

The message list fills in slices of at most 128 entries or 2 ms per frame.
Cancel/reopen invalidates outstanding slices. Apply uses the complete draft even
while its list is loading. Draft entries copy on edit; cancelling cannot mutate
the live conversation. Per-frame stale-edit detection checks a revision and
count, and Apply checks the full baseline again before committing, including
out-of-band changes. Long captions read a bounded prefix while typing.

Individual messages longer than 4,096 characters use **Previous/Next** parts,
with a part-number field for direct navigation.
Only the current part is assigned to the visible text widget. Changing parts
retains pending edits; Apply joins all parts and preserves the original image
reference. Cancel/reopen restores the live conversation. Normal-sized notes
keep the ordinary single editor. This is a display/editing bound, not truncation
of the stored conversation or an increased replay capacity.

Large clipboard insertions are divided before the visible widget shapes them;
ordinary Copy/Cut/Paste retain the pinned native editing rules. Part navigation
and paste spanning parts reset this text editor's local Undo history, as the
page-control tooltip explains. Cancel still discards the complete draft. Native
World Undo/Redo remains an independent, unchanged operation.

Conversations with at least 262,144 characters prepare their complete redacted
value and audit encoding in a bounded Provider-owned worker. The editor shows
preparation progress and keeps Cancel available; text-changing actions and
another Apply wait. Small edits retain the immediate path. Cancel, Stop, closing
the editor, changed conversation/World/credentials, or a retiring owner refuses
uncommitted work. Read-only navigation and Copy remain available. A queued
panel, editor, Workbench or host is already retiring before deferred deletion.

The owner thread still performs the complete durable journal append. Only a
successful append adopts the redacted live conversation, before traffic
observers run. Failed or cancelled preparation never adopts a partial draft.
Native World history remains separate. Direct and collaborative requests,
context refresh and stage approval wait for this pending Apply or its Cancel.

Conversation remains available for persistent collaboration within the current
Workbench session. Hiding and reopening Art preserves it. A new game session
starts empty under accepted #727; World Save/Open is a separate native contract.

## Provider/native boundary and Stop

`art_provider.gd` owns one nonblocking Godot HTTPRequest with a 256 KiB
download chunk and static payload/response adapters. `art_batch_panel.gd` supplies compact controls and dispatches parsed
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

The timeout must be finite and greater than zero, with a 3600-second maximum.
Connection refusal, DNS/connect failure, timeout, HTTP failure, malformed JSON
and response-capacity refusal are distinct failures. A transport or HTTP failure
does not become an assistant turn or invented token usage. The UI shows a bounded
redacted error while the admitted complete redacted response remains in JSONL.

Responses of at least 256 KiB prepare their UTF-8 text, redaction, JSON envelope
and reusable assistant encoding on a bounded value-only worker. It owns copied
body/header buffers and a credential snapshot, with no SceneTree, World, native
adapter or filesystem access. A changed credential set requires preparation
again before publication. There is at most one retained preparation job per
provider; repeated Send while a cancelled job drains asks the user to retry
shortly. The main thread reaps completed tasks and owns durable append and
assistant/native ordering.

Large conversation edits have a separate finite pure-value preparation slot.
`begin_conversation_edit` snapshots typed turns, a bounded host identity and the
current credentials; its worker redacts and encodes without accessing the scene,
native World or filesystem. HTTP `active` remains false. No model request is
created. New provider dispatch refuses while this slot is preparing or ready.

The deferred completion supplies only the handle, host identity and error. A
guarded copied preview permits the owner to recognize a no-op. The one-shot
`commit_conversation_edit` consumes the private prepared value only while the
same credential set, provider serial, journal identity and owner guards remain
applicable. Current image/history authority is checked on the main owner.
After the complete durable append, the owner adopts the redacted turns before
traffic observers run. Thus an observer's later Stop or new conversation does
not retroactively undo the already committed edit. No caller-provided sanitized
flag or replacement encoding grants this authority. Stop, scoped Cancel,
owner destruction and stale credentials retire unpublished preparation; worker
completion alone never writes an edited conversation.

Large outgoing bodies also prepare their wire JSON and redacted request encoding
on that single value-worker slot, starting at a 65,536-character payload weight.
The request captures its configuration and context once. A main-thread dispatch
guard checks the current UI/World generation before and after the request audit;
cancelled or obsolete preparation cannot send HTTP. The user turn is added only
after HTTP starts, with that request's image offset. Changing visible controls
while preparation is pending affects a future request, not the captured one.

Stop during response preparation invalidates the generation and records the
received byte count, request identity and `response_receipt_committed=false`.
Stop during outgoing request preparation records the request identity and
`request_receipt_committed=false`; no request has been dispatched. Neither path
invents an assistant reply or claims that an unpublished body was archived. A
completed, admitted response retains its complete redacted body in the session
log; the live/readable views remain bounded. Large-response CPU preparation and
main-thread publication/write costs are measured separately. A response worker
does not make synchronous durable filesystem writes instantaneous.

Ordinary **X** hides Art and keeps an active model/native run alive. **Stop**
explicitly cancels it. Hidden windows skip visible control/layout work, while
World-epoch invalidation, native result polling, deadlines and durable receipts
still run. Request-generation checks also fence synchronous audit observers:
Stop during request/response/conversation logging cannot dispatch a later
request or admit a stale native drawing batch.

The nonblocking HTTP path fixes the separately reproduced accepted-connection,
no-response teardown hang. It does not establish the cause of the owner's
original **no listening LM Studio server → Send → immediate X** freeze. The
[evaluator](../operations/art-workbench-final-evaluation.md) records transport,
callback, JSON, audit, UI and native timing without exporting provider settings.

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

### Verified closed storage in the mergedown candidate

The unmerged Art/Architecture integration verifies closed output before
acknowledging a stored event, completed export, preference update or retained
private history receipt. `art_provider.gd::_store_event` verifies the exact new
record region against the submitted buffers, without rereading the previous
archive. An interrupted append leaves prior complete records readable and makes
that session writer read-only; it does not claim to roll back an incomplete tail
or repeat an already completed native edit.

Export closes its staging file and cooperatively verifies its exact length and
SHA-256 before the existing native atomic replacement. Traffic displays the
verification phase; Stop and Cancel still interrupt it. Refusal or cancellation
does not publish that export. The destination/source alias guard is checked
again at commit. This remains a bounded streaming export, independent of model
context and native painting authority.

`art_batch_panel.gd::_save_settings` uses the shared bounded-text
`workbench_file_transaction.gd` helper: complete closed-byte verification followed
by the accepted native sibling-file replacement. Existing unchanged preferences
keep their no-write cache. A failed write retains the earlier cache and file;
only verified success updates the cache. Successful retry or reversion to the
committed settings clears only the save-owned error. The profile's 1 MiB bound
and prior-profile admission refusal remain authoritative.

The retained private `_persist_history_receipt` method similarly verifies the
closed payload before publication and before advancing receipt identity/order.
Its existing schema, frozen projection, epoch and capacity checks remain. This
does not activate old-journal restoration in ordinary Art sessions. Neither
helper promises `fsync`, power-loss recovery, a multi-file transaction, or a
cross-process editing lock; complete concurrent replacements remain
last-writer-wins.

The direct `test_workbench_file_transaction.gd` and
`test_art_storage_integrity.gd` regressions exercise verification and refusal.
`tools/ci/run_art_storage_qualification.py` runs disposable actual OS faults and
retry, with a shared Windows sharing-lock fixture in `windows_file_lock.py`.
The [registered mergedown campaign](../audits/2026-11-25-mergedown-renaissance/art-storage-integration-registration.md)
separates inherited failure evidence, resulting-source execution and pending
Windows/owner acceptance. These source changes do not establish physical
acceptance or change native runtime inputs.

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

The 2026-11-11 Stage-2/integration qualification below is historical execution
evidence for its own source and native runtime. The current Art finisher reuses
accepted main's source-matched native libraries without rebuilding them.
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
limits requests per Send, including refusals and rate retries. Zero requires a
positive Run s limit. Send refuses when both are zero, even if an estimated
spending ceiling is set. A positive Turns limit still permits Run s to be zero;
Stop remains available in either finite mode. Run s adds an
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

Hiding and reopening Art preserves its in-memory conversation within the same
Workbench session. New game sessions start empty; no prior audit is restored.
Full context can include images retained in the current session when Image
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

The NVIDIA and LM Studio curated model identifiers are listed above. Manual
model IDs remain unrestricted. Existing Nemotron request-template compatibility
is retained; this is not a guarantee of service availability.


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
