---
title: Proposal-only Art owner seam
status: Current
document-kind: contract
scope: Unmerged Art and Architecture integration candidate; proposal-only host mount with separate runtime and owner gates
canonical-for: [architecture-proposal-owner-seam]
last-reviewed: 2026-11-25
related-documents: [architecture-planning-and-composition.md, architecture-staged-construction.md]
---

# Proposal-only Art owner seam

The mergedown candidate mounts this correlation adapter in the ordinary Architecture window through the existing Art provider. **Prepare Art proposal…** captures a bounded native inspection and shows the exact outgoing request; a separate **Send this proposal request** authorizes one transport request. The ordinary Art panel owns its provider, credentials, conversation, transport, traffic logging and painting lifecycle. The Architecture bridge never attaches another listener to that provider's `finished` signal. This unmerged integration still requires its resulting-source platform qualification and physical/creative owner acceptance; a deterministic fixture is not a model-quality result.

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

The current Art provider retains ordinary `send(..., pre_dispatch_guard)` and adds the exclusive `send_owned(parameters, completion, guard)` route described in the [Art-owned transport contract](art-owned-proposal-transport.md). The bridge does not import Provider or call either send method. The host binds Art's existing adapter; a response enters exactly one owned Architecture callback and never the ordinary Art auto-paint signal. Earlier compatibility fixtures below exercised the ten-argument predecessor and then its optional eleventh guard argument.

## Ordinary Workbench mount

`art_architecture_mount.gd` is created only by the explicit Prepare action.
Opening Architecture alone constructs neither this mount nor Art. Configure Art
opens the existing Art panel; its provider/model/endpoint, limits and in-memory
credential remain authoritative. The configuration snapshot is acquired only at
Send. No earlier Art conversation, rendered image or complete material plane is
silently added to the Architecture request.

The native region, intent, bounded retrieved references, destination, model and
limits are disclosed before any request or provider audit begins. The disclosure
is bound to the current World generation/tick, authoring history, StageSession,
Workflow, provider instance, Art settings/credential revision and visible intent.
Send checks those identities again. Provider serial and the live guard continue
to fence actual dispatch, asynchronous preparation and response admission. Stop,
Architecture close, owner replacement or changed context retires only the owned
proposal; ordinary Art Hide retains its established continue-in-background rule.

`bridge.dispatch_pending_request(request)` allows the host to submit the same
already-current pending request after disclosure. It enters the unchanged guarded
signal-consumer path and enforces the same finite budgets and lifetime checks.
It cannot select a plan, preview, approve, restart a retired request or write cells.
The mounted bridge reports `owner-transport-unqualified`; genuine model count is
unknown, never inferred from an HTTP response.

The generic regression runner discovers `test_art_architecture_workbench.gd`.
It exercises the production disclosure/Send controls, real deterministic loopback,
three separately approved native stages, exact ordinary Undo, stale identities,
ordinary Hide, Stop and a busy shared provider. Frozen predecessor probes and
feature-specific evaluators retain their original source identities.

## Finite lifecycle and evidence

A random per-dispatch lifetime token binds the callback to its Architecture request and eventual positive provider ID. Reused numeric IDs, late completions, duplicate completions and responses for other provider IDs cannot acquire a current proposal. An early synchronous response is held until dispatch admission and live guard checks complete. Multiple early responses refuse. Stop, replacement, detach and a changed host context retire the request before any owner cancellation callback runs. Bind/detach holds a seam-mutation guard across owner callbacks, and cancellation retains the exact earlier Workflow object; a replacement host with an identical request ID cannot be refused on the earlier host’s behalf. Each completion retains its own evidence mode. A request signal also captures its original host and seam serial; if cancellation synchronously creates a replacement dispatch, the outer signal cannot overwrite it.

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

The first local draft exposed the JSON numeric-array mismatch. After the shared execution environment recovered, the final bridge and adapter fixes at `3f0f146e8052cfa8f20af5da6cc1cf89cc662d31` passed all 41 fixture checks with zero failures under pinned Godot `4.7.stable.official.5b4e0cb0f`. The retained log is `proposal-bridge-3f0f.log`, SHA-256 `a73644ffa407bde927369798c6df8f2f6497eda4b3e00d2b9f2b23d648c8241b`; the engine SHA-256 is `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`. This is local boundary-fixture execution with zero HTTP/model calls. The final integrated source still requires its own hosted campaign.

The separate Art successor at `fa22d386b802b686c371bb6e12996c7a93c18588` has a successful [qualified evaluator campaign](https://github.com/techrote/cybersand/actions/runs/45497650568). Its Windows installed-launcher job passed; the separate Linux job and fresh application matrix were skipped under the recorded application-reuse proof. Earlier failed package campaigns remain historical evidence, not the latest delivery status.

At that historical checkpoint, the qualified successor did not provide the explicit proposal-only owner hook and integration handoff. Its ordinary panel continues to route provider completion directly to drawing submission. Its Provider adds an optional eleventh `pre_dispatch_guard: Callable` argument to `send`; a future owner adapter must forward the supplied Architecture guard there so asynchronous request preparation cannot dispatch after the observation becomes stale. A disposable fixture adapted only its inherited send override and passed 43 checks against those exact qualified Provider dependencies; see [the isolated compatibility review](../audits/2026-11-24-world-steer-m6-m7/qualified-art-bridge-review-b.md). Production Art files and the production bridge were unchanged. Neither that probe nor the qualified Art evaluator establishes integrated Architecture transport or physical owner acceptance. The later mergedown mount above supplies the production handoff in its own unmerged source. These historical compatibility results do not qualify that changed application or replace its remaining owner gates.
