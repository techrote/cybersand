# Proposal-only Art owner seam

This is an executable correlation adapter for an explicit owner-controlled transport hook. It is **not a completed Art integration or a model performance result**. The ordinary Art panel owns its provider, credentials, conversation, transport, traffic logging and automatic painting lifecycle. The Architecture bridge never attaches another listener to that provider's `finished` signal.

## Integration contract

`architecture_proposal_bridge.gd` binds the existing Architecture Workflow through:

```gdscript
bridge.bind_owner_seam(workflow, owner_dispatch, owner_cancel, live_context_guard)
```

The required host callbacks have these shapes:

| Callback | Shape | Responsibility |
| --- | --- | --- |
| Dispatch | `dispatch(request: Dictionary, completion: Callable, guard: Callable) -> Dictionary` | Establish exclusive proposal ownership, call `guard.call()` immediately before the owner's normal send, then return `{"ok":true,"provider_id":positive_int}` or a refusal. |
| Completion | `completion.call(id:int,text:String,response:Dictionary,error:String)` | Route only the owner's matching, already redacted proposal response through the supplied lifetime-bound callback. |
| Cancellation | `cancel(provider_id:int,request_id:String,reason:String)` | Cancel only that owned proposal. An ID of -1 means dispatch has not returned its positive identity; use the correlated Architecture request identity. |
| Context guard | `guard(request:Dictionary) -> bool` | Check live host inspection and interaction authority. A model-provided Boolean is not a host guard. |

The bridge subscribes only to `Workflow.proposal_transport_requested` and `Workflow.proposal_cancel_requested`. It calls only the public `Workflow.accept_response` admission method; it does not select an alternative, load a plan, preview, approve or invoke native execution. The Workflow separately checks its exact live observation fence, and the planning adapter validates the finite campaign, inspected region, palette, dependencies and resource ceilings.

The accepted Provider interface exercised by the fixture is the existing ten-argument `send(provider,endpoint,model,key,prompt,instructions,tokens,seconds,png,context) -> String`, its `finished(id,text,response,error)` signal and `cancel(reason)`. The owner keeps those interfaces unchanged. This bridge does not import Provider in production or call its send method. The owner must not send a response through both the normal Art auto-paint path and this proposal path.

## Finite lifecycle and evidence

A random per-dispatch lifetime token binds the callback to its Architecture request and eventual positive provider ID. Reused numeric IDs, late completions, duplicate completions and responses for other provider IDs cannot acquire a current proposal. An early synchronous response is held until dispatch admission and live guard checks complete. Multiple early responses refuse. Stop, replacement, detach and a changed host context retire the request before any owner cancellation callback runs. Bind/detach holds a seam-mutation guard across owner callbacks, and cancellation retains the exact earlier Workflow object; a replacement host with an identical request ID cannot be refused on the earlier host’s behalf. Each completion retains its own evidence mode.

The bridge admits at most 32 requests and retains at most 128 events. It reserves terminal history space while a request is active. Request text is bounded at two MiB and response text at four MiB. Each retained event contains at most a 4,096-character text prefix, truncation status, a retained-prefix digest and a complete-text digest only when the complete response is within the bound. The full provider response dictionary, credentials, images and provider traffic are not copied. Ordinary text and unparseable JSON remain explicitly historical, with no executable interpretation.

Transport errors take precedence over valid-looking proposal text. An ordinary Art operation array is not a typed architecture response and cannot bypass stage review. Reopening exported history has no transport resumption API and grants no selection, approval or completion authority.

`fixture` mode reports zero real model calls. `owner-transport-unqualified` reports that genuine call count as unknown; a caller cannot assert a certified mode. Any future genuine inference conclusion still needs the owner's exact endpoint/model/request evidence and authorization. Neither successful parser fixtures nor deterministic offline proposals establish model quality.

## JSON numerical admission

JSON numbers may reach GDScript as integral floating-point values. The planning adapter checks exact integral bounds before normalizing proposed material identities and compares validated regions as `Rect2i`. It continues to refuse fractional materials, altered regions and an expanded palette. Synchronous owner refusals are returned as refusals, rather than leaving the caller with a false awaiting-response status.

## Qualification and handoff

Run the pure fixture with:

```sh
godot --headless --path godot --script res://tests/test_architecture_proposal_bridge.gd
```

Completion marker: `ARCHITECTURE_PROPOSAL_BRIDGE: N checks, 0 failures`.

The test uses the inherited accepted Provider signal and an exact-signature send override that creates no HTTPRequest. The actual accepted Provider is also exercised on its empty-model refusal path, before any transport can start. A real Workflow with explicitly synthetic inspection values checks proposal/plan separation. These are boundary and lifecycle fixtures, not native execution or real-model qualification.

The first local draft exposed the JSON numeric-array mismatch. Its final edits could not be rerun when the shared execution environment became unavailable. The reconstructed bridge, adapter fixes and complete fixtures therefore require parsing and execution in the next source-specific hosted campaign; no passing count is claimed for this checkpoint.

The separate Art successor still needs to provide the explicit proposal-only owner hook and its independently qualified delivery. A successful source job does not imply a qualified extracted evaluator or owner acceptance. Until that handoff exists, the existing offline typed proposal and native stage pathway remain the independently executable authoring route.
