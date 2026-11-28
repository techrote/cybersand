---
title: Independent review of bounded Conversation Apply preparation
status: Planned
document-kind: audit
scope: Cross-lane provider, editor, World and teardown ownership review
last-reviewed: 2026-11-25
---

# Independent Conversation Apply review

The native/context specialist independently reviewed the Provider lane's
implementation, the experience lane's editor integration and the lead's narrow
coordinator fence. **No remaining source blocker was found at
`8a015efbeb7926a3c835303d3b163c01d353aca3`, tree
`ad991f1fe8e2c8945120526377d85392d0a3212a`.** Runtime and package
qualification remain separate from that source conclusion.

The reviewer did not implement these Provider/editor changes. The reviewed
sequence is explicit: A's initial `1ac6da6a`, the projection fix at
`05c274b2`, queued-owner fixes at `f9099628`, retired-child cleanup at
`f6054aaf`, and the final fixture-order correction at `8a015efb`.
Production panel and Provider bytes at the final pin are identical to the
reviewed f605 source; the later UI test reopens its editor after an acknowledged
proposal legitimately advances the live conversation revision.

## Admission, copied values and worker lifetime

The [Provider source](https://github.com/techrote/cybersand/blob/8a015efbeb7926a3c835303d3b163c01d353aca3/godot/scripts/art_provider.gd)
uses a separate conversation-edit handle and owner identity. It does not create
another Provider, HTTP route or ordinary paint completion. Opening the editor
does not start preparation; explicit Apply admits it.

Inputs are reconstructed through the existing typed conversation validator:
user/assistant roles, text and admitted structural image/history references.
Unknown live objects are not copied into the worker. Turn/text admission and
actual UTF-8 replay/record limits remain bounded. Current credentials are copied
into an immutable redaction snapshot and compared again before publication.

The [preparation worker](https://github.com/techrote/cybersand/blob/8a015efbeb7926a3c835303d3b163c01d353aca3/godot/scripts/art_response_preparation.gd)
only redacts, counts and encodes copied values. It owns no World, native
executor, GUI state or journal writer. The existing pending registry retains
the finite value job after owner destruction, and the deferred main-thread
reaper waits only after the pool reports completion. Cancelling an unfinished
job does not synchronously join it on the UI thread. The same Provider refuses
another request/edit while its cancelled value job is still being reaped.

A caller receives copied prepared turns, not the private encoded audit value.
Only the exact registered job can activate the prepared-value append path.
An arbitrary job object, replacement payload, wrong handle or wrong identity
cannot authorize that path.

## Exact commit and observation order

The Provider captures its serial, journal path and event index alongside the
host identity. Readiness and the final actual append recheck that identity,
current secrets and the live host guard after callback reentrancy. A guard that
admits a newer journal event invalidates the older prepared snapshot.

The first journal is established before worker admission with small preparation
metadata, excluding the unpublished draft. This avoids a first-segment pointer
callback occurring between an edited snapshot's durable write and adoption.
The large edited record uses the existing complete, ordered, flushed journal
append and error protocol.

The verified order is:

1. Final prepared-job and live-owner checks.
2. Complete durable edited snapshot append.
3. Live conversation adoption and revision advancement.
4. Traffic observers.

Later observers can Stop or admit a successor without the retired commit
clearing that successor. Failure leaves the draft available and does not adopt
an uncommitted live conversation. This source review does not treat a queued
job or completed encoding as a committed edit.

## Host state and owner control

The [panel/editor integration](https://github.com/techrote/cybersand/blob/8a015efbeb7926a3c835303d3b163c01d353aca3/godot/scripts/art_batch_panel.gd)
binds preparation to its own generation, the live conversation revision, the
editor baseline revision, actual World epoch, Provider serial and existing
native-result text. It retains a copied draft and repeats full baseline/draft
comparison before commit. Cheap per-frame guards avoid comparing the complete
large conversation on every frame.

Pending Apply makes mutating editor actions read-only, including direct signal
and paste handlers, while retaining navigation, complete 4096-character parts
and Cancel. Stop, editor Hide and reopened conversation retire the UI identity
before scoped Provider cancellation. A previously queued ready notification
cannot restore that retired identity.

The final guards reject queued, detached or invalid owner hierarchies before
the deletion flush: panel, editor, Provider, Workbench and host. Cleanup paths
also avoid calling retired editor/Provider children. The Provider independently
rejects its own queued or detached state at admission, prepared-value access
and commit, including after reentrant owner guards.

The [coordinator fence](https://github.com/techrote/cybersand/blob/8a015efbeb7926a3c835303d3b163c01d353aca3/godot/scripts/art_collaboration_session.gd)
treats pending Apply as existing direct-work ownership. Ordinary collaborative
Send, Inspect and Approve therefore cannot dispatch, start a new capture or
consume an already valid native preview while the conversation edit is pending.
Native history and execution remain under their existing owners.

## Findings retained and closed

**Prepared Traffic publication preceded its final guard.** Specialist C found
that the first implementation assigned live Traffic/readable projections before
the last credential/owner check. A credential rotated in that guard could leave
old-secret unpublished draft content visible even though the archive append
was refused. The reviewer independently inspected the corrected source:
prepared projections now remain local until the final guard and durable append
succeed. Ordinary log-event failure-preview semantics are preserved. The added
regression checks unchanged archive bytes and both unchanged live projections
after a final credential rotation/refusal.

**Queued owner deletion was not yet a live-guard boundary.** This reviewer found
that the initial UI guard checked inside-tree/visibility but not queued deletion.
A parent can remain in-tree until deletion flush while its child Provider reaps
a completed job. The correction adds the queued hierarchy checks above. Its
focused test holds only delivery of an actual completed worker, queues the Art
owner, then delivers readiness before deletion flush and checks no edited
append/adoption. A separate Provider test covers its own ready-then-queued state.
Retired-child cleanup was subsequently tightened without weakening the guards.

**Two attempted tests did not qualify the feature.** The first f909 UI test
failed to parse because its helper `seed()` collided with Godot's global
function. The f605 attempt reported 154 checks with 11 failures because loading
the offline example admitted a newer proposal turn while the test kept an older
editor baseline. The test now explicitly reopens against that acknowledged
revision before preparing the edit. These failures are retained; the stale
guard was not relaxed to make the fixture pass.

## Runtime evidence boundary

The Provider lane reports 66 successful actual worker/audit mechanism checks at
`7e0a1e26e487117c9e652f07b33496cb71acf422`. The reviewer independently fetched
both relevant files and confirmed they are byte-identical to the final source:

- Provider SHA-256:
  `c9c24d8aac45e09f5ee291699d09ed34eadc5945b28545c098eb30b500821891`.
- Mechanism-test SHA-256:
  `09d16bb492f7018c3f6b24b1e7bac0cc9bf096b93c38dfbec862ad84dd9069ad`.

The implementation owners also report an actual ordinary Workbench lifecycle
run at the final 8a015 source: 154 checks, zero failures, 12.83 s, with clean tracked
source and original log SHA-256
`79efe35050fe215372ceadcf9c319705a8ce2e0c4d1e94a103a3d57e649c34ec`.
At this reviewer checkpoint its durable original execution bundle is still
being published; the reviewer has not independently fetched that original log.
This paragraph attributes the runtime report and does not present it as
reviewer-executed or as a graphical/Windows pass.

The final lifecycle test uses an ordinary native Workbench, actual value
workers, complete archive replay, real append-destination failure, World
replacement and valid-preview cross-mode controls. Deterministic text fixtures
make no HTTP/model request. Its lifecycle pass does not establish a 16.8 MB
performance improvement; that requires the separate matched large-value
experiment and fresh graphical/package gates.

Draft/HOLD remains in force. The review adds no automatic restoration of
cross-session conversation, paid inference, new native execution authority or
acceptance claim for physical owner hardware.
