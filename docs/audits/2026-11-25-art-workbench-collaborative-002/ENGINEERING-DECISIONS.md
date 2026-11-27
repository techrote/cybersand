---
title: Collaborative Art engineering decisions
status: Current
document-kind: audit
scope: ART-WORKBENCH-COLLABORATIVE-002 design and authority boundaries; Draft/HOLD
last-reviewed: 2026-11-25
---

# Collaborative Art engineering decisions

Art is a conversation and approval surface over CyberSand's existing provider,
material editor and native history. The owner chooses the subject, admits the
context and approves finite native work. Application and package acceptance
belong to the exact source receipts in the mission ledger; design statements
alone are not qualification evidence.

## One workspace and explicit intent

The existing Art window contains direct painting and the collaborative workspace.
Conversation, Creative brief, Proposal and Context pages share one provider,
current-session conversation, redacted audit and native history owner. Opening
a window or selecting a mode does not call a model.

| Owner intent | Behavior | Authority boundary |
| --- | --- | --- |
| Discuss | Sends admitted context and retains the complete redacted reply as prose. | Cannot submit native drawing. |
| Direct authoring | Keeps the convenient model-to-shape route with explicit scope and a positive turn count or run duration. | Uses the established Art executor and native source policy. |
| Propose | Validates a versioned proposal and computes a zero-write material preview. | A model packet is a suggestion, never approval or a receipt. |
| Develop | Includes the current normalized proposal, applied brief and admitted recent conversation, retaining lineage and differences. | Owner constraints remain host inputs; a revision has no inherited approval. |
| Execute | Approve next stage admits one finite stage after fresh source, policy, dependency and material-plane checks. | Each later stage needs a separate applicable approval. |
| Review | Supplies acknowledged work summaries and current observations for discussion. | An improvement needs its own proposal and approval cycle. |

The first Collaborate action expands an inherited compact window when the
viewport has room. Later owner resizing remains effective. Complete messages
and structured context use bounded readers; the visible message part remains
at most 4,096 characters. Conversation search scans complete admitted text in
small slices and labels its newest-128-match result bound.

Implementation: [workspace](../../../godot/scripts/art_collaboration_workspace.gd),
[coordinator](../../../godot/scripts/art_collaboration_session.gd) and the
[existing Art panel](../../../godot/scripts/art_batch_panel.gd).

## One provider and one response consumer

Art owns transport, credentials, preparation, request identity, cancellation and
complete redacted auditing. Owned Discuss, Propose, Develop, Review and
Architecture requests capture one completion consumer. They do not also emit
the ordinary completion-to-paint signal. Direct painting keeps its established
interface and consumer.

The injected Architecture adapter uses:

~~~gdscript
transport.bind_owner(existing_art_provider, configuration_snapshot, owner_guard)
transport.dispatch(request, completion_callback, pre_dispatch_guard)
transport.cancel(provider_id, request_id, reason)
~~~

Configuration comes from the trusted Art owner. Model data cannot choose a
credential, endpoint or hidden transport. Guards cover actual eventual HTTP
admission, including asynchronous preparation and reentrant audit observers.
Scoped cancellation cannot consume an unrelated successor. The
[integration contract](../../systems/art-owned-proposal-transport.md) defines
exact packet/callback shapes, capacities and lifetime fences.

Architecture retains plan validation, dependencies, StageSession and execution.
Its separately identified native handoff mounts the provider closure over a
qualified Architecture source without changing Architecture production files.
A fixture host mount does not establish a production Architecture configuration
factory in the principal Art panel or combined Windows qualification.

## Context is an admitted native observation

Art obtains a bounded material plane through the existing PAINT capture owner;
it does not independently drain the native mailbox. Source identity includes
generation, revision, tick and authoring generation. The model receives World
dimensions, selected region, observed material names/counts, coarse occupancy,
at most 32 spatially distributed observed cells, tool state and applied creative
constraints. The private full plane is available to validation without
automatically entering the provider payload.

Native capture is limited to 262,144 cells; native/creative model context is
limited to 24,576 UTF-8 bytes. Recent conversational context has separate limits:
eight messages, at most 4,096 characters each and 16,384 characters in total,
including omission markers. Complete originals and the redacted audit remain.
The inspector identifies the actual source, provenance, omissions and limits.

Knowledge uses a small frozen set of approved reference cards with source
provenance. It does not import active documentation branches or automatically
read historical audits. Retrieved examples are untrusted reference data, never
executable instructions or permission. Unsupported actor, structural-stability
and body-state claims are not inferred from stored materials. The
[native context contract](../../systems/art-native-context-proposals.md) records
the exact observation and compilation rules.

Optional images are explicit bounded Workbench canvas captures, with dimensions,
native-coordinate mapping and hashes. Appearance is distinct from material
authority. External transmission requires authorization of the inspected
context; changed context invalidates that authorization. No desktop, private
file, credential or unrelated historical audit is silently included.

Conversation and brief belong to the current game session. Hide retains the
session; a new game session begins a new conversation. Old World references and
execution approvals are never silently restored.

## Native construction stays bounded and reversible

The versioned compiler accepts finite material primitives and stage dependencies.
It computes geometry and resource bounds itself, rejects forged host receipts
or budgets, and refuses unsupported part ownership. Preview operates on copied
materials without native writes.

Approval checks current source, applied policy, protected rectangles, palette,
destructive permission, dependencies and complete material-plane hash. Chunks
pass through the existing Art executor and exclusive simulation worker. Both
admission and eventual consumption validate source identity. Only an actual
completed native acknowledgement advances the expected source for the next
chunk, so manual interleaving invalidates obsolete work.

The existing native source policy permits changes from Empty (0) and Hard Wall
(58). Destructive permission does not authorize replacement of occupied Metal,
Stone or other protected materials. A revision before execution can change
proposed material choices; replacement of already installed protected material
requires its ordinary owning editor. This is an explicit authority limit.

Stop retains actual acknowledged work. Failed or cancelled readback retains
completed work as unverified rather than losing its receipt or inventing
success. Continuation needs fresh observation and approval. Undo/Redo uses the
existing history owner. Multiple native stages are not one atomic transaction.

## Responsiveness preserves complete records

Provider pumping increased within the existing finite response bound. Controlled
loopback comparisons retain full body/audit checks. Transfer improvement does
not imply every frame improved; adverse maximum-frame measurements remain.

Large Conversation Apply uses one finite copied-value job in the existing
WorkerThreadPool preparation/reaper mechanism. The job receives text and a
credential snapshot, with no native World or filesystem mutation. Small edits
keep their direct Apply path.

A private handle, editor/conversation revision, World lifetime, provider serial,
journal identity and current credentials fence publication. Cancel, Stop, editor
closure, stale context and retiring owners discard pending edits. The complete
audit append stays on the owner thread; live adoption follows durable append and
precedes traffic observers. Refused values reach neither audit nor live Traffic.
Pending Apply also fences collaborative Send, Inspect and Approve. Native history
remains separate.

The context scan uses packed material counts and precomputed coarse bins. Forty
counterbalanced pairs over five authenticated original native planes produced
identical model bytes, digests and non-timing context values. The completed
maximum-size scene declined from a 110.728 ms median to 32.593 ms in that
pure-value comparison. Its observed 35.451 ms tail can still exceed one 60 Hz
frame interval. This is not a rendering or native-capture benchmark. The result
supports the smaller synchronous optimization; this candidate does not add
another asynchronous context lifecycle.

See [context measurements](CONTEXT-SCAN-PERFORMANCE.md),
[provider measurements and retained negatives](provider-recovery.md),
[Apply decisions](conversation-apply-preparation-plan.md) and the
[independent ownership review](CONVERSATION-PREPARATION-INDEPENDENT-REVIEW.md).

## Creative evidence and acceptance limits

Nine substantial recipes run through the actual native Workbench with material
before/after observations, displayed screenshots, original receipts, matched
direct controls and editable starts. The 24-brief copied-value cohort retains
ready, refused, contradictory, incomplete, stale and repaired cases. The
[creative synthesis](NATIVE-CREATIVE-EVIDENCE-SYNTHESIS.md) gives exact counts,
intended character and the scope of each experiment.

Every automated model response is a deterministic fixture. These experiments
establish transport, context, compilation, authoring, revision custody and owner
control. They do not establish genuine LLM creativity, semantic interpretation
of an artistic request or a causal retrieval benefit. Empty material rectangles
do not establish actor traversal or structural stability.

Delivery needs fresh complete Linux/Windows application campaigns, exact native
and Rapier runtimes, pinned Godot, immutable package identities and actual
pristine extracted launcher execution. The original physical Windows/NVIDIA
absent-listener Send→ordinary Art X/Hide acceptance remains owner-pending. A live
HTTP 404 is a different case. Draft/HOLD, no merge, no Ready promotion, no default
activation and no paid inference remain in force.
