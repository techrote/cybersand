---
title: Art owned discussion and proposal transport
status: Current
document-kind: contract
scope: ART-WORKBENCH-COLLABORATIVE-002 Draft/HOLD provider owner seam; no model or native execution acceptance implied
canonical-for: [art-owned-proposal-transport]
last-reviewed: 2026-11-25
related-documents: [workbench-art-providers.md, workbench-direct-art-batches.md]
---

# Art owned discussion and proposal transport

The Art Provider owns one active transport, the existing finite value preparation
slot, credentials, cancellation and the complete redacted session audit. Ordinary
direct painting retains its eleven-argument `send` interface and its `finished`
consumer. Owned discussion and proposal requests have one explicit completion
callable. They **never emit the ordinary `finished` signal** and therefore cannot
also enter the panel's completion-to-paint route.

This source is a Draft/HOLD successor of Art #773. It does not change that PR's
readiness, its frozen evaluator or the separate Architecture #777 evaluator.
Transport tests establish request and callback behavior, not model creativity,
successful construction or physical Windows/NVIDIA acceptance.

## Provider interface

```gdscript
provider.send_owned(parameters, completion, pre_dispatch_guard) -> Dictionary
provider.cancel_owned(provider_id, request_id, reason) -> bool
provider.owned_request() -> Dictionary
```

`parameters` is supplied by the **Art owner**, not copied from a model response.
Required fields are `request_id`, `mode`, `provider`, `endpoint`, `model`, `prompt`,
`instructions`, integer `tokens` and numeric `seconds`. Optional fields are
`key`, `png` and `context`. The modes are `discuss`, `propose`, `develop`, `review`
and `architecture-proposal`. Existing direct painting uses ordinary `send`.

The return value contains `ok`, `provider_id`, `request_id`, `mode` and `reason`.
A positive ID means one preparation/transport request was admitted; it is not a
response, model-quality finding, preview, approval or execution receipt. A
pre-admission refusal returns `ok=false` and `provider_id=-1`. A synchronous
guard/audit cancellation can report a terminal callback before dispatch returns.
The caller must retain its own lifetime identity, as the Architecture bridge does.

The completion shape is unchanged from the Architecture owner seam:

```gdscript
completion.call(id: int, text: String, response: Dictionary, error: String)
```

`text` and `error` are redacted. `response` is a small host-generated
`cybersand-art-owned-completion-v1` record with `provider_id`, `request_id`, `mode`,
`state` and, on normal transport completion, bounded provider-reported `usage`.
It contains no raw provider envelope, endpoint, credentials or model-authored
native receipt. The complete admitted redacted request and response remain in
Art's existing audit. Usage can be absent; it is never invented.

The provider does not add another conversation turn on the owner's behalf.
The existing `request_started(id, request_offset)` signal identifies actual
transport admission, including completion of asynchronous preparation. Art's
conversation owner stores that admitted user turn, then stores the complete
redacted completion through its existing session-only `remember_turn` path.
This keeps image offsets associated with the request actually sent and avoids
duplicating entries. No old audit is automatically restored.

## Exclusive completion and cancellation

The callback and mode are captured before preparation. The original direct and
owned interfaces share the same private transport implementation. The eleventh
`pre_dispatch_guard` position of ordinary `send` remains unchanged. The owned
interface forwards its guard to that same actual admission boundary; there is
no second provider or independent HTTP path.

The guard must return an actual Boolean. It runs before preparation, after the
owned audit event, before the eventual HTTP request, after the request audit and
again before an owned response is published. This covers asynchronous outgoing
and incoming preparation and synchronous audit observers. A request whose World
or permission context changed is cancelled rather than delivered as a current
proposal. The context guard is host-owned; a model Boolean grants no authority.

The completed serial is recorded separately from the callback. Clearing the
callback cannot cause a duplicate response to fall through into ordinary direct
painting. Cancellation clears ownership before the existing audit emits any
synchronous observer signal. The captured earlier consumer receives one
cancellation error; a successor opened during audit keeps its own callback and
timing. Late IDs and already-completed IDs cannot consume a current request.

`cancel_owned` requires the exact textual request ID and positive provider ID.
The special ID `-1` supports the Architecture bridge cancelling during
synchronous dispatch before it receives the numeric ID; it still requires the
exact textual identity. Other negative values, the wrong positive ID and the
wrong textual identity refuse. It cannot cancel ordinary direct Art or an
unrelated successor. Ordinary Stop and World replacement retain the existing
single Provider `cancel(reason)` authority.

## Architecture handoff

`art_proposal_transport.gd` is Art's small owner adapter. It owns no native World,
plan validator, stage, preview or approval. It accepts #777's injected contract:

```gdscript
transport.bind_owner(art.provider, art_configuration_snapshot, art_context_guard)
bridge.bind_owner_seam(workflow, transport.dispatch, transport.cancel, live_context_guard)
```

The configuration callback returns current Art-owned provider, endpoint, model,
key, token/time limits and optional image/context/guidance. The adapter does not
store credentials after dispatch. Binding does not call that callback. The Art
guard accepts a copied request dictionary; the bridge-supplied guard takes no
arguments. Both must remain true at transport admission and response publication.

`dispatch(request, completion, pre_dispatch_guard)` accepts only
`cybersand-architecture-proposal-request-v1` with `mode=proposal_transport` and a
bounded host request ID. It obtains transport settings exclusively from Art.
Top-level requests attempting to override `key`, `api_key`, `credentials`,
`provider`, `endpoint`, `model`, `png`, `context` or `authorization` refuse.
The complete copied request becomes explicitly labelled reference data in the
prompt. Retrieved examples are not instructions; strict structured output
support is not inferred from an ordinary text provider.

The bridge's `cancel(provider_id, request_id, reason)` reaches the scoped owner
after checking the captured request lifetime. No second listener is attached to
ordinary `Provider.finished`. `detach_owner()` retires the owned request and
releases the binding; reentrant rebinding during detach refuses. Architecture
retains plan/schema checks, dependencies, stage previews, fresh approvals and
native receipts. A model response alone selects and executes nothing.

The independently refreshed counterpart is #777 source
`17c6b5b35049b7b2541c2deeea23c02fd1e2fc5d`. Its public bridge consumes the same
four-argument callback and `{ok, provider_id}` dispatch result. No #777 production
branch is rewritten. Actual combined Workbench qualification is a separately
identified integration gate.

## Ordinary Architecture entry

The unmerged coherent Art/Architecture candidate mounts this adapter lazily from
**Architecture → Intent and tasks → Prepare Art proposal…**. Preparation captures
actual native material counts/source identity, intent and bounded architectural
references. A dialog shows the complete admitted request and current Art
provider/model/destination and limits. Only **Send this proposal request** binds
transport and dispatches. Opening either panel or preparing a disclosure makes
no request. No previous Art conversation or image enters that request.

Art supplies `proposal_configuration_identity()` without credentials and
`proposal_configuration_snapshot()` at dispatch. A credential revision prevents
an applied Key change from reusing an old disclosure. The same provider, archive,
nonblocking HTTP path and finite preparation worker remain authoritative. Its
ordinary `finished` listener count is unchanged. The mount polls small identity
values only while a disclosure or request is pending, and retires stale context.
Architecture retains option adoption, native preview, approval, stages and Undo.

The merged source preserves Batch Lab's separate traffic namespaces and moves
its decoded/JSON-escaped credential redaction into the current Art value worker.
Recognized missing/non-HTTP endpoint syntax returns the existing `start_failed`
receipt without calling an engine parser that emits an error diagnostic. Both
synchronous and asynchronous failure paths retain their original semantics.
The [Architecture seam](architecture-proposal-owner-seam.md) owns mount lifetimes;
full resulting-source platform and owner qualification remain separate gates.

## Capacities and truthful capability display

Owned context is bounded to two MiB of serialized JSON value content, 128
conversation messages, 32,768 traversed values and 24 nesting levels. Encoded
image text has a separate two MiB bound. Endpoint length is at most 2,048
characters, model ID 512 and request identity 256. Output allowance is
1–65,536 tokens; the existing finite timeout ceiling is 3,600 seconds. The
Architecture adapter has a one MiB host-request budget and 32 dispatches per
adapter lifetime. These bounds do not truncate the complete admitted audit.

Response transport retains the existing 16 MiB body limit, redirects off,
nonblocking polling and one value preparation worker. Original Art negative
findings and physical no-listener acceptance remain applicable.

`art_provider_capabilities.gd::summary(provider, endpoint)` describes implemented
wire adapters only. Text and image wire shapes exist for the three providers.
Image model support, strict schema support, model availability, entitlement and
model token context are unverified. Streaming is false. Address classification
does no network probe; `localhost` is separately labelled as an unverified
hostname. Userinfo such as `127.0.0.1@example.invalid` is never called loopback.

## Reproducible verification

`test_art_owned_transport.gd` runs actual deterministic TCP/HTTP fixtures through
the production Provider and adapter. It covers each owned mode, ordinary direct
compatibility, no dispatch on binding, credentials, bounds, wrong-ID cancellation,
an absent listener, accepted socket without headers, malformed/HTTP failure,
outgoing preparation invalidation, incoming stale preparation, duplicate/late
completion and reentrant response/cancellation audit observers. It also checks
captured configuration and request immutability. The normal native atomic-file
primitive writes the complete session audit. No model inference or native World
mutation is part of this transport test.

```text
Godot_v4.7-stable --headless --path godot --script res://tests/test_art_owned_transport.gd
```

`ART_OWNED_TRANSPORT_RESULT` contains actual platform, source hashes, per-mode
callback counts, complete audit hash and failures. Native zero-write,
preview/approval, Workbench UI and Windows package evidence belong to the combined
qualification and cannot be inferred from the isolated transport result.

### Source-pinned counterpart probe

`tools/ci/run_art_architecture_handoff_probe.py` builds a separate temporary
project from this Art owner and an explicitly pinned #777 checkout. It reads
counterpart scripts and data with `git show`, copies only their required
reader/fixture closure, and never changes either checkout. Every copied input,
the runner, engine and native atomic-file runtime are hashed in `inputs.json`.
The runtime must match Art's committed payload. The probe runs the unchanged
Architecture bridge, Workflow and strict typed response parser across real
local HTTP using Art's one provider and the adapter above.

```text
python tools/ci/run_art_architecture_handoff_probe.py --godot <pinned-Godot> --architecture-repository <readonly-Architecture-checkout> --output <new-evidence-directory>
```

The default counterpart pin is
`17c6b5b35049b7b2541c2deeea23c02fd1e2fc5d`. A different explicitly selected commit
is recorded, including its tree. Successful typed proposal delivery must leave
the plan, preview and approval authorities unused. Direct Art shape arrays are
refused by the actual Architecture schema. Asynchronous preparation with a
stale live context, scoped Workflow Stop and accepted-socket World replacement
are exercised separately. The result marker is
`ART_ARCHITECTURE_HANDOFF_RESULT`; original process output and a hash-linked
result receipt remain in the fresh evidence directory, including failures.

The source of inspection is explicitly a copied-value fixture from the
counterpart's existing Workflow test. The probe makes three actual HTTP
exchanges and no model calls; it makes no native World construction claim.
It qualifies the exclusive proposal transport and typed consumer seam only.
Ordinary combined Workbench execution and each programme's independent Windows
evaluator require their own source-matched evidence.
