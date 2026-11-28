# Bounded preparation for large Conversation Apply

This isolated follow-up begins from source
`e536d128f85e948223b25e13931a7a801faf956d`.
It does not change that baseline's in-progress Linux/Windows qualification.

## Measured reason and scope

An instrumentation-only copy of the existing Apply callback, source
`8ea23b54`, passed the inherited complete-message/audit checks on the
same 16,769,024-byte fixture. Its local headless Apply took 681.146 ms:
347.725 ms in first redaction,288.351 ms in audit (164.287 ms formatting and 66.535 ms
writing), 36.601 ms joining parts and 7.762 ms in the complete stale guard.
The second redaction inside audit was already a 2.608 ms proven-unchanged cache hit.
These local observations do not explain a causal Windows regression or justify
removing credential redaction. Original selected evidence remains separately
owned by the Provider lane.

The candidate moves pure redaction and encoding of conversations containing at
least 262,144 characters to the existing Provider's separately identified value
preparation. Short Apply retains its existing synchronous path. Main-thread
journal append remains authoritative. The inherited near-cap benchmark records
click-return latency, complete durable completion and frames across both;
asynchrony does not turn completion latency into a shorter callback metric.

## Owner controls and commit point

The editor keeps complete draft/original values and 4,096-character visible parts.
While preparing, mutating Note/Remove/Clear/text/paste and duplicate Apply are
locked; read-only navigation, Copy and Cancel remain available. Cancel, editor
close, Stop, superseding editor/conversation, changed World or credential
snapshot retires uncommitted work. Queued deletion of the panel, editor,
Workbench or host is already a lifetime boundary before the deletion flush. New direct requests/drawing wait for Apply or
Cancel; ordinary native history remains separately owned.

The host binds a monotonic apply generation, live conversation/editor revisions,
World epoch and provider request serial. Cheap liveness checks run per frame;
full baseline/draft comparison runs only at admission/final commitment. The
Provider independently checks the exact credential snapshot and retains its
private prepared value. A copied ready value supports the existing no-op check
without granting a sanitized/encoded-input bypass.

Immediately after a complete successful append, the Provider calls the host's
adoption callback before notifying traffic observers. This is the commit point:
later observer actions see the new revision and cannot be overwritten by stale
post-append assignment. Failed append never adopts live changes. No preparation
worker owns a live Control, native World or journal writer.

## Qualification required before integration

The new actual Workbench regression exercises real value workers, complete
archive replay, Cancel/Hide/Stop, injected late completion, duplicate Apply,
locked draft actions, actual World replacement, newer acknowledged turns,
credential rotation, complete redacted success, no-op behavior, reentrant audit
observers, a real unavailable append destination, and a ready callback delivered
after its owner is queued for deletion but before the deletion flush. Actual
collaborative Send, Inspect and Approve are exercised while a valid native
preview exists and Apply is pending; they preserve the draft and do not dispatch,
start another capture or consume approval. It uses deterministic text
and zero HTTP/model requests.

The paired Provider mechanism test independently exercises private ownership,
task lifetime, forged capability refusal and teardown. Both join the exact-source
headless/displayed matrix; the predecessor near-cap test retains its full SHA,
audit, native-history and frame assertions with separate complete-latency
accounting. No new success or responsiveness result is asserted by this plan.

## Retained first integrated test failure

The first actual Workbench lifecycle attempt at isolated integration source
`f90996287a4f2f91d1d7158c261a7a5d3f479a08` exited before initialization:
11 parser errors resolved the fixture helper `seed()` as Godot's global
`seed(number)`. It produced no final result marker and establishes no UI or
native acceptance. The original log SHA-256 is
`a448a7b12ce9067e337cdfeb8c11a5da38876f861e4409648ea6ebc37689b431`.
The fixture helper is renamed `seed_conversation_fixture()`; production
semantics and assertions are unchanged. The Provider lane retains the original
log and will rerun the corrected committed integration.

The corrected parser source `f6054aaf4a66d22135b7f673437970d3e8c61a73`
then executed the actual native lifecycle: 154 checks with 11 failures in
13.0 seconds. The first failing fixture opened the editor before loading an
offline example; the example correctly admitted a newer acknowledged proposal
turn, making that draft stale. Apply correctly refused it. Later fixture actions
then attempted inspection without a pending Apply and caused dependent failures.
The original log SHA-256 is
`b7db38ec25195b1091be5af4ce1e0afe28355625ef6198868120e7ae67ff6171`.
The test now explicitly reopens the editor against the acknowledged revision
after the preview finishes, edits that current draft, and retires any failed
fixture capture before continuing. Its production stale-context refusal is
preserved; these failures are not presented as an acceptance result.
