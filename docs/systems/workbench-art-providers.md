---
title: Art workbench provider connection, WB-ART-002 Stage 2
status: Current
document-kind: contract
scope: Unmerged one-shot OpenAI Responses, NVIDIA and LM Studio UI, cancellation, raw traffic and local qualification; persistent collaboration remains Planned
canonical-for: [workbench-art-providers]
last-reviewed: 2026-11-10
related-documents: [workbench-direct-art-batches.md, ../architecture/shared-workbench-authoring-data.md, ../reference/status-and-roadmap.md]
---

# Art workbench provider connection — Stage 2

## Current candidate and controls

**Unmerged candidate:** #559 Stage 2 extends `codex/agent-art-workbench-v2` and
Draft PR #560. The [Stage-1 contract](workbench-direct-art-batches.md) owns direct
geometry, execution-time protection, native completion and authored-start Save.
No #531 controller, native defaults, prices, catalogs, credit gates or MCP are
imported. Stage 2 sends one prompt and directly draws a returned packet; persistent
conversation/follow-up and context modes are **Planned** for Stage 3. Repeated
Send currently sends only that request, the drawing instructions/work area and
an optional current-view image. Stored traffic is not model context.

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
primitives. Omitted material explicitly defaults to Hard Wall (still refused if
not enabled). A complete JSON array followed by a stray closing wrapper is
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
explicit earlier-on-disk marker. Full export copies the disk session, not the
live tail; there is no 256-event export ceiling. Disk failure is surfaced without
stopping inference/drawing. When disk logging fails, missing historical content
is not magically recoverable from the bounded viewer.

Entered keys, bearer strings, common key formats, credential URL parameters and
URL userinfo are redacted before display/disk/export. Authorization request
headers are never added to the logged request object. No log can identify every
arbitrary secret the user invents; do not put unrelated credentials in prompts.

## Reproducible qualification and local setup

Stage 2 uses unchanged current-main native libraries, not a fresh C++ rebuild.
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
wire shapes, aliases, errors, timeout, Stop and replacement. Its Linux
`--graphical` option also exercises actual UI image capture and retains PNGs.
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
