# Bounded preparation for large Conversation Apply

This isolated follow-up begins from source
`e536d128f85e948223b25e13931a7a801faf956d`.
It does not change that baseline's in-progress Linux/Windows qualification.

## Measured reason and scope

An instrumentation-only copy of the existing Apply callback, source
`8ea23b54`, passed the inherited complete-message/audit checks on the
same 16,769,024-byte fixture. Its local headless Apply took681.146ms:
347.725ms in first redaction,288.351ms in audit (164.287ms formatting and66.535ms
writing),36.601ms joining parts and7.762ms in the complete stale guard.
The second redaction inside audit was already a2.608ms proven-unchanged cache hit.
These local observations do not explain a causal Windows regression or justify
removing credential redaction. Original selected evidence remains separately
owned by the Provider lane.

The candidate moves pure redaction and encoding of conversations containing at
least262,144characters to the existing Provider's separately identified value
preparation. Short Apply retains its existing synchronous path. Main-thread
journal append remains authoritative. The inherited near-cap benchmark records
click-return latency, complete durable completion and frames across both;
asynchrony does not turn completion latency into a shorter callback metric.

## Owner controls and commit point

The editor keeps complete draft/original values and4096-character visible parts.
While preparing, mutating Note/Remove/Clear/text/paste and duplicate Apply are
locked; read-only navigation, Copy and Cancel remain available. Cancel, editor
close, Stop, superseding editor/conversation, changed World or credential
snapshot retires uncommitted work. New direct requests/drawing wait for Apply or
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
observers and a real unavailable append destination. It uses deterministic text
and zero HTTP/model requests.

The paired Provider mechanism test independently exercises private ownership,
task lifetime, forged capability refusal and teardown. Both join the exact-source
headless/displayed matrix; the predecessor near-cap test retains its full SHA,
audit, native-history and frame assertions with separate complete-latency
accounting. No new success or responsiveness result is asserted by this plan.
