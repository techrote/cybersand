---
title: Agent workbench design and communication review packet
status: Current
document-kind: evidence
scope: Independent-review supplement for desktop and provider-runner integration, tool semantics and measured overhead
canonical-for: []
last-reviewed: 2026-11-08
related-documents: [../systems/shared-workbench-agent-authoring.md, ../operations/workbench-api-agent.md]
---

# Agent workbench: design philosophy and tool semantics

## Purpose and source

This is a critical review packet, not a defense of the current wire format. The
owner requested scrutiny of inefficient, sparse communications while connecting
the compact desktop UI to the provider-neutral runner. Canonical contracts remain
[shared workbench](../systems/shared-workbench-agent-authoring.md) and
[runner](../operations/workbench-api-agent.md); this supplement defines no
competing executable contract.

Inputs are #531 `29988b7f776957990cff5a38f8284a678c3b3e3e`, #552
`be7b5d472333a43b47d95cce43158c3948a17ccd` and its #547 foundation
`2b6b8f4ae7da631a81d7393ed01c7940f54bfe93`. Source import is checkpoint
`c2ea6084c17ade707c7edc89c09f18109cc0ae74`. Final integration qualification must
bind the later resulting head/tree, original artifacts, platform and runtimes.
An isolated source composition is not a Main merge, Ready transition or accepted
live model trial. The original MAT checkout and running apps remain untouched.

## Product and ownership philosophy

A person and an agent operate one visible physical canvas. A person paints,
chooses scope/protection/material permissions, watches proposals and can revoke
agent authority. A model inspects, proposes, applies and requests bounded ticks.
It cannot authorize itself, spawn another World, broaden permissions, execute
arbitrary code or declare its prose equivalent to native evidence.

Native owns authoritative cells and physics. Godot owns input/presentation and
the main-thread native/render join. The Python Runner owns inference, context,
provider adapters and budget accounting. The desktop bridge carries copied
values; it does not become a second controller or native owner. The same Runner
must drive both the deterministic fixture and genuine providers. MCP is excluded
from this integration path. An HTTP backend still consumes the existing remote
service; the desktop backend must operate the existing mounted World.

## Three representations

| Representation | Purpose | Information policy |
| --- | --- | --- |
| Native/audit receipt | Verification, recovery and independent evidence | Keep complete readback, identities, original PNGs and explicit failures within bounds |
| Model-facing result | Choose the next action | Exact relevant status/counts/IDs/identity plus image; disclose projections, retain originals locally |
| Conversation view | Human understanding of intent and failures | Actual prose/readable exchanges, filters and separate raw Content/Event/export |

A sparse Conversation view does not prove a short model context. A verbose local
JSONL audit does not prove every field went to inference. Small continuation HTTP
bodies can still reference large server-retained history. Cache hits remain in
context; image base64 byte length is not an image-token count.

The desktop predecessor forwarded full footprints and readback rows as model
text. Those are valuable audit facts, often poor decision context. The Python
Runner already selects native fields for model results. The integrated UI should
retain raw diagnostics without accidentally sending every audit row back to the
model. Review this separation by measuring actual rendered provider requests.

## Tool intent versus effect

| Operation | Authority/evidence | Must not be confused with |
| --- | --- | --- |
| Human Start | Frozen grant and native authorization ACK | Model-chosen permission, another World or successful provider validation |
| observe | Copied facts and original post-draw image with matched identities | Material IDs inferred from pixels, or local counts covering the whole canvas |
| prepare_edit | Revision-fenced opaque proposal and native-prepared footprint; zero mutation | Applied cells or a proposal remaining valid after human intervention |
| apply_edit | Consumed proposal, verified native readback and authored-start outcome | A queued command or unverified model statement |
| step | Exact completed native ticks, paused state and matched observation | Render frames or elapsed wall-clock time |
| Human Stop | Dispatch revocation plus independent native retirement ACK | HTTP cancellation, process death or a model tool |

Observation IDs identify inspected revisions; proposal IDs identify prepared
changes; provider call IDs correlate model calls/results; native request IDs
support uncertain-outcome recovery without a new mutation. Session, generation,
revision and tick identities distinguish continued state, replacement, human
intervention and simulation progress. Provider continuation IDs replace none of
these native identities.

## Observed communication costs

A retained owner-supplied desktop log from the earlier OpenAI-only path has 36
events and 317,040 file bytes. Only aggregate sizes/counts are reproduced; no task
text, project/organization IDs, credentials or private log is committed. Usage is
provider-reported data, not a bill. Body sizes reserialize recorded bodies as
compact UTF-8 JSON; image values are descriptors rather than original base64,
so these sizes MUST NOT be called exact wire sizes.

| Request | Recorded body bytes | Tool-result text bytes | Outcome | Reported input/output tokens |
| --- | ---: | ---: | --- | --- |
| 1 | 3673 | 0 | observe | 574 / 61 |
| 2 | 5315 | 1333 | prepare 46 primitives, refused | 1254 / 2288 |
| 3 | 3337 | 114 | corrected observe | 3580 / 242 |
| 4 | 5320 | 1338 | prepare 1 rectangle,990 cells | 4441 / 118 |
| 5 | 49329 | 38164 | apply | 20487 / 79 |
| 6 | 63495 | 50318 | HTTP429 | unavailable |

Five successful responses reported 30,336 input / 2,788 output tokens. The invalid
proposal contained 42 rectangles, 3 lines and 1 disc (4,440 argument bytes), beyond
the eight-primitive contract. One bounded correction was returned. The accepted
proposal used 148 argument bytes; its 990-cell footprint contributed 38,164 result
text bytes. After 990 verified writes, the receipt contributed 50,318 bytes to the
next continuation. The jump from 4,441 to 20,487 input tokens is concrete evidence of
per-cell proposal overhead, not economical model communication. The 429 reported
50,000 TPM, 19,260 used and 40,617 requested, suggesting 11.852 seconds. Requested
reservation is not completed/billed output.

### Necessary evidence versus avoidable inference payload

Readbacks/images establish effects independently of prose/previews. IDs and
revisions protect against stale observations and retries. Strict finite grants
make refusal deterministic. Prepare/apply supports preview and intervention.
Local audit data explains failures without another paid run.

None of these reasons justifies transmitting every repeated cell row to the
model. Local authoritative evidence can coexist with exact selected-field
projections: status, counts, IDs, relevant identity and an image. A projection
needs a label/hash/reference to retained originals. A checksum alone is not
sufficient for the human diagnostics window.

### Waste and design questions

- Per-cell JSON repeats coordinates/keys for geometry already expressed by a
  small primitive, and prepare/apply can repeat much of the same information.
- Full material arrays are expensive when image plus counts would suffice.
- Stateless history repeats context on the wire; server-side chaining hides
  that growth from body sizes without necessarily reducing context cost.
- A fresh observe after every apply adds a round trip. Returning a genuinely
  matched fresh observation from apply might help, but needs native lifecycle
  qualification; renaming a receipt/reusing an old observation ID is unsafe.
- Tool-only responses can communicate almost no intent. Preserve actual short
  assistant plans/status when returned. Do not invent prose or unavailable
  reasoning to make a conversation look fuller.
- Output allowance, actual output, hidden reasoning-token accounting and visible
  characters are different. Large allowances can consume rate reservations.

This integration removes duplicate controller loops and carries deliberate
selected-field projections. It does not claim to complete protocol compression,
a new bulk-image language or an optimal art-authoring abstraction.

The new desktop bridge advertises finite nonnegative installed-canvas coordinates.
The separate frozen signed Sand-hopper remains a regression of the legacy mounted
adapter, including the owner-approved +512 translation and recorded trajectory
difference. A green hopper control does not establish that signed fixture execution
has passed through the new Python desktop Runner. Its new real-native gate is the
nine-then-eight edit/readback/Step sequence plus human Stop during a second run.

## Integration contracts and deliberate limits

The desktop contract supports 8 disc/line/rectangle primitives, replace-only
filters, null/counts observations, and a frozen cell limit up to 65,536. The
imported HTTP runner began with 96 rectangles, explicit cells observations and
4,096 cells. Similarly its original 64-call / 95-tool / 4,096-token hard caps do not
match desktop 128 / 256 / 32,768 opening controls. Review backend-specific advertised
schemas and enforced limits; silent clamping is not a valid compatibility fix.

This is not a general image generator. Current agent output is Hard Wall/Empty,
with source-cell restrictions and protected areas. A prompt for a colorful city
or arbitrary textured robot exceeds that material interface. Sparse art may
reflect the capability contract, tool pressure or missing intent communication,
not only model capability. Higher-level semantic shapes or bounded masks might
improve expressiveness, but require separately reviewed native semantics.

The stdio desktop channel uses an agreed versioned envelope and per-session
bounded files/hash references for large receipts/images. It must serialize
writes, assemble partial reads, reject unknown/stale identities and drain stderr
without blocking rendering. Paths are host-created under a session root, not
model-selected filesystem capabilities. A broken process/pipe or preflight
failure must retire any already-acquired native authority. Python provider waits
must not hold the lock needed for human Stop. Native ACK and transport completion
must remain distinct, including races between UI retirement and Runner.finish.

Live startup retains the runner's existing provider funding/pricing/credential
and source-provenance checks. A copied Godot-only folder cannot prove Python
source identity or supply Atlas assets. Delivery should be a real clean source
checkout or genuinely verified immutable package, never an unverified caller's
source_dirty:false. NVIDIA key entry cannot silently reuse an OpenAI key.
Profiles/caps/credentials/endpoint references are host-controlled; model output
cannot switch them. No paid inference is part of keyless/source qualification.

Local TPM pacing is an approximation. Reserve max(estimated input,output cap)
before dispatch, settle completed requests to reported usage, retain uncertain
charges, preserve history across tasks and show waits explicitly. A local field
cannot raise provider capacity or account for unrelated clients. Rate-only
retries must honor Retry-After without shortening its minimum, charge attempts,
keep the same pending input and never replay a native mutation. Provider backoff,
TPM wait, network timeout, native deadline and task deadline are different clocks.

The integration's first 22-check native run exposed an acceptance hole: edits,
frames, ticks and Stop passed, but the controller stopped at its input-token gate
before the fixture's final response. Its text estimate included audit-only native
fields that the provider serializer omitted. The corrected estimator shares the
actual provider request projection, including tool schemas/envelope, and prices
original image dimensions separately. A regression adds 3 MiB of local native
evidence without changing model-byte/reservation totals, while genuinely large
model text still triggers the input limit. The mounted gate now additionally
requires successful controller status, the exact scripted final and nine model
decisions. Retain the failed checkpoint; native success alone was insufficient.

## Questions for the independent reviewer

1. Can you trace one visible Start through exactly one Runner to the existing
   native World, including original image/readback and final native Stop ACK?
2. Does the UI show actual provider, selected profile, task grant, reported versus
   unknown usage and pending native work, with no legacy live-controller fallback?
3. Do advertised schemas match backend enforcement, especially8/96 primitives,
   shape types, null/counts observations, cell grants and token ceilings?
4. Which complete facts remain on disk, which are sent to inference, and which
   are merely filtered for people? Are projection labels/hashes reproducible?
5. Can a late model response, stale IPC frame, duplicate request, provider retry
   or human edit cause an extra mutation or an old Stop ACK to authorize a new run?
6. Does Stop remain independent during provider wait, rate wait, native polling,
   process failure and scene teardown? Does uncertain retirement block restart?
7. Are all provider attempts counted, including failed/retried calls? Are model
   probes, token reservations, actual usage, cash budgets and physical ticks kept
   separate? Are unknown costs reported rather than fabricated as zero?
8. Can you reproduce the overhead table and the integrated selected-field payload
   sizes? Do compact results still let the model choose a useful next action?
9. Do normal real-native results support only engineering gates, while actual
   OpenAI/NVIDIA/Ollama inference and Windows human acceptance stay separate?

## Reproducible measurements and acceptance

`tools/wb_agent/analyse_communication_overhead.py` produces aggregate-only
measurements from a diagnostic log, never copying prompt text or private IDs.
The 990-cell receipt projection measured 38,164 to 394 bytes for preparation
and 50,318 to 327 for application using the integrated desktop Runner projection
(2026-11-08 replay of the owner's retained log). These are selected-result bytes,
not a new live trial, exact wire compression ratio or proof of unchanged model
quality. Full receipts remain local, with their SHA-256 and a projection label
included in the model-facing result. Observation results retain useful region,
view and identity metadata; their selected text grew from 1,333/1,338 to 1,385
bytes in this replay. This is selective reduction of large cell lists, not a
claim that every response becomes smaller.

Required final evidence includes provider request/response bytes and usage,
raw-versus-projected receipt sizes, model calls/retries, native writes/ticks,
image hashes and source/runtime identity. Measure provider latency, native ACK
and render-join latency separately where available; record unsupported metrics
explicitly. Stop-click to native ACK and ignored late callbacks matter more than
an attractive terminal screenshot. Preserve failed checkpoints.

Run the existing provider/controller and remote transport suites, new desktop
bridge tests, real Godot/native child-process execution, human-intervention/Stop
races, graphical input isolation and ordinary agent-disabled painting/save.
Windows qualification must run the real child process from the delivered folder.
Compare the same frozen fixture before/after projection, retaining full local
receipts/PNGs and labeling deterministic provider decisions as scripted. A passing
fixture does not prove genuine model competence or provider billing correctness.

This packet is supplementary reviewer material. Final source/command/artifact
results belong in the existing integration PR record; no merge is authorized.
